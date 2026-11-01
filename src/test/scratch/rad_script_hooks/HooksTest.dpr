program HooksTest;

(* rad.script.engine / hooks / jobs: docs/specs/rad.script.hooks.md EARS 1-15.
   Gercek TForm + TButton/TAction/TClientDataSet, bellek ici sahte IRadScriptStore, DB yok. *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, System.Generics.Collections, System.Generics.Defaults,
  System.Diagnostics, System.SyncObjs,
  Data.DB, Datasnap.DBClient, Vcl.Forms, Vcl.StdCtrls, Vcl.ActnList,
  mormot.core.variants,
  rad.sqlfilter, rad.script, rad.eventbus, rad.worker, rad.script.engine, rad.script.hooks, rad.script.jobs;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;
  GLog: TStringList;
  GLogLock: TCriticalSection;
  GWarnings: TStringList;
  GErrors: TList<string>;

procedure Kontrol(const AAd: string; ABasarili: Boolean; const ADetay: string = '');
begin
  if ABasarili then
  begin
    Inc(GBasari);
    Writeln('  [OK]   ', AAd);
  end
  else
  begin
    Inc(GHata);
    Writeln('  [HATA] ', AAd, '  ', ADetay);
  end;
end;

procedure Olcum(const AAd, ADeger: string);
begin
  Writeln('  [OLCUM] ', AAd, ' = ', ADeger);
end;

procedure LogEkle(const S: string);
begin
  GLogLock.Enter;
  try
    GLog.Add(S);
  finally
    GLogLock.Leave;
  end;
end;

function Logged: string;
begin
  GLogLock.Enter;
  try
    Result := string.Join(',', GLog.ToStringArray);
  finally
    GLogLock.Leave;
  end;
end;

procedure LogSil;
begin
  GLogLock.Enter;
  try
    GLog.Clear;
  finally
    GLogLock.Leave;
  end;
end;

type
  /// Script'in cagirdigi yardimci: formda 'Log' adli bilesen.
  TLogger = class(TComponent)
  private
    FGo: Boolean;
    FGo2: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Add(const S: string);
    procedure Fail(const S: string);
    procedure Wait(AMs: Integer);
    property Go: Boolean read FGo write FGo;
    property Go2: Boolean read FGo2 write FGo2;
  end;

  TBaseKayit = class(TForm)
  private
    procedure KaydetClick(Sender: TObject);
    procedure KaydetExecute(Sender: TObject);
    procedure QryBeforePost(DataSet: TDataSet);
  public
    btnKaydet: TButton;
    actKaydet: TAction;
    qry: TClientDataSet;
    Log: TLogger;
    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
  end;

  TKasaK = class(TBaseKayit)
  end;

  /// Bellek ici store: yalniz ScriptsFor/LibrariesOf/LoadPackages gercek.
  TFakeStore = class(TInterfacedObject, IRadScriptStore)
  public
    Packages: TRadScriptPackages;
    constructor Create;
    destructor Destroy; override;
    function Dialect: TRadSqlDialect;
    procedure EnsureDefinitionTables;
    function LoadPackages(AIncludeInactive: Boolean): TRadScriptPackages;
    function LoadPackage(const ACode: string): TRadScriptPackage;
    procedure SavePackage(APkg: TRadScriptPackage);
    procedure ImportPackage(APkg: TRadScriptPackage);
    procedure DeletePackage(const ACode: string);
    function ScriptsFor(AKind: TRadScriptKind; const ATarget: string): TRadScripts;
    procedure ApplyPendingDbSteps(APkg: TRadScriptPackage);
    function LoadResource(APackageId: Integer; const AFileName: string; AStream: TStream): Boolean;
    function LibrariesOf(const APackageIds: TArray<Integer>): TRadScripts;
    function ParamsOf(const APackageIds: TArray<Integer>): TObjectList<TRadScriptParam>;
    function AddPackage(const ACode: string; AOrder: Integer): TRadScriptPackage;
  end;

{ TLogger }

constructor TLogger.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FGo := True;
  FGo2 := True;
end;

procedure TLogger.Add(const S: string);
begin
  LogEkle(S);
end;

procedure TLogger.Fail(const S: string);
begin
  raise Exception.Create(S);
end;

procedure TLogger.Wait(AMs: Integer);
begin
  Sleep(AMs);
end;

{ TBaseKayit }

constructor TBaseKayit.CreateNew(AOwner: TComponent; Dummy: Integer);
begin
  inherited CreateNew(AOwner, Dummy);
  btnKaydet := TButton.Create(Self);
  btnKaydet.Name := 'btnKaydet';
  btnKaydet.Parent := Self;
  btnKaydet.OnClick := KaydetClick;
  actKaydet := TAction.Create(Self);
  actKaydet.Name := 'actKaydet';
  actKaydet.OnExecute := KaydetExecute;
  qry := TClientDataSet.Create(Self);
  qry.Name := 'qry';
  qry.FieldDefs.Add('ad', ftString, 20);
  qry.CreateDataSet;
  qry.BeforePost := QryBeforePost;
  Log := TLogger.Create(Self);
  Log.Name := 'Log';
end;

procedure TBaseKayit.KaydetClick(Sender: TObject);
begin
  LogEkle('orijinal');
end;

procedure TBaseKayit.KaydetExecute(Sender: TObject);
begin
  LogEkle('orijinal-exec');
end;

procedure TBaseKayit.QryBeforePost(DataSet: TDataSet);
begin
  LogEkle('orijinal-beforepost');
end;

{ TFakeStore }

constructor TFakeStore.Create;
begin
  inherited Create;
  Packages := TRadScriptPackages.Create(True);
end;

destructor TFakeStore.Destroy;
begin
  Packages.Free;
  inherited;
end;

function TFakeStore.AddPackage(const ACode: string; AOrder: Integer): TRadScriptPackage;
begin
  Result := TRadScriptPackage.Create;
  Result.Id := Packages.Count + 1;
  Result.Code := ACode;
  Result.Name := ACode;
  Result.Order := AOrder;
  Packages.Add(Result);
end;

function TFakeStore.Dialect: TRadSqlDialect;
begin
  Result := sdPostgreSQL;
end;

procedure TFakeStore.EnsureDefinitionTables;
begin
end;

function TFakeStore.LoadPackages(AIncludeInactive: Boolean): TRadScriptPackages;
var
  P, C: TRadScriptPackage;
  S, SC: TRadScript;
begin
  Result := TRadScriptPackages.Create(True);
  for P in Packages do
    if P.Active or AIncludeInactive then
    begin
      C := TRadScriptPackage.Create;
      C.Id := P.Id;
      C.Code := P.Code;
      C.Name := P.Name;
      C.Order := P.Order;
      C.Active := P.Active;
      for S in P.Scripts do
      begin
        SC := TRadScript.Create;
        SC.Assign(S);
        SC.PackageId := P.Id;
        C.Scripts.Add(SC);
      end;
      Result.Add(C);
    end;
end;

function TFakeStore.LoadPackage(const ACode: string): TRadScriptPackage;
begin
  Result := nil;
end;

procedure TFakeStore.SavePackage(APkg: TRadScriptPackage);
begin
end;

procedure TFakeStore.ImportPackage(APkg: TRadScriptPackage);
begin
end;

procedure TFakeStore.DeletePackage(const ACode: string);
begin
end;

procedure TFakeStore.ApplyPendingDbSteps(APkg: TRadScriptPackage);
begin
end;

function TFakeStore.LoadResource(APackageId: Integer; const AFileName: string; AStream: TStream): Boolean;
begin
  Result := False;
end;

function PaketSira(A, B: TRadScriptPackage): Integer;
begin
  Result := A.Order - B.Order;
  if Result = 0 then Result := A.Id - B.Id;
end;

function TFakeStore.ScriptsFor(AKind: TRadScriptKind; const ATarget: string): TRadScripts;
var
  LSorted: TList<TRadScriptPackage>;
  P: TRadScriptPackage;
  S, C: TRadScript;
begin
  Result := TRadScripts.Create(True);
  LSorted := TList<TRadScriptPackage>.Create;
  try
    for P in Packages do LSorted.Add(P);
    LSorted.Sort(TComparer<TRadScriptPackage>.Construct(
      function(const A, B: TRadScriptPackage): Integer begin Result := PaketSira(A, B); end));
    for P in LSorted do
      if P.Active then
        for S in P.Scripts do
          if S.Active and (S.Kind = AKind) and SameText(S.Target, ATarget) then
          begin
            C := TRadScript.Create;
            C.Assign(S);
            C.PackageId := P.Id;
            Result.Add(C);
          end;
  finally
    LSorted.Free;
  end;
end;

function TFakeStore.LibrariesOf(const APackageIds: TArray<Integer>): TRadScripts;
var
  P: TRadScriptPackage;
  S, C: TRadScript;
  LId: Integer;
begin
  Result := TRadScripts.Create(True);
  for LId in APackageIds do
    for P in Packages do
      if P.Id = LId then
        for S in P.Scripts do
          if S.Active and (S.Kind = skLibrary) then
          begin
            C := TRadScript.Create;
            C.Assign(S);
            C.PackageId := P.Id;
            Result.Add(C);
          end;
end;

function TFakeStore.ParamsOf(const APackageIds: TArray<Integer>): TObjectList<TRadScriptParam>;
var
  P: TRadScriptPackage;
  LId: Integer;
  Prm, C: TRadScriptParam;
begin
  Result := TObjectList<TRadScriptParam>.Create(True);
  for LId in APackageIds do
    for P in Packages do
      if P.Id = LId then
        for Prm in P.Params do
        begin
          C := TRadScriptParam.Create;
          C.Name := Prm.Name;
          C.Value := Prm.Value;
          Result.Add(C);
        end;
end;

const
  SRC_P1 =
    'function btnKaydet_Before(Sender: TObject): Boolean;'#13#10 +
    'begin Log.Add(''B1''); Result := Log.Go; end;'#13#10 +
    'procedure btnKaydet_After(Sender: TObject);'#13#10 +
    'begin Log.Add(''A1''); end;';
  SRC_P2 =
    'function btnKaydet_Before(Sender: TObject): Boolean;'#13#10 +
    'begin Log.Add(''B2''); Result := Log.Go2; end;'#13#10 +
    'procedure btnKaydet_After(Sender: TObject);'#13#10 +
    'begin Log.Add(''A2''); end;';

var
  GStore: TFakeStore;
  GStoreIntf: IRadScriptStore;

procedure Hazirla;
begin
  GStore := TFakeStore.Create;
  GStoreIntf := GStore;
  TRadScriptBinder.Store := GStoreIntf;
  TRadScriptBinder.OnWarning := procedure(const AMsg: string) begin GWarnings.Add(AMsg); end;
  TRadScriptBinder.OnError := procedure(AForm: TCustomForm; E: Exception)
    begin
      GErrors.Add(E.ClassName + ': ' + E.Message);
    end;
  GWarnings.Clear;
  GErrors.Clear;
  LogSil;
end;

procedure Temizle;
begin
  TRadScriptBinder.Store := nil;
  GStoreIntf := nil;
  GStore := nil;
end;

procedure Kanca(const ATarget, ACode, ASource: string; APkg: TRadScriptPackage);
begin
  APkg.AddScript(ACode, skForm, ATarget, ASource);
end;

procedure TestTemelKanca;
var
  F: TKasaK;
  A: TRadScriptAttachment;
begin
  Writeln('--- H: kanca');
  Hazirla;
  try
    Kanca('TKasaK', 'S1', SRC_P1, GStore.AddPackage('p1', 1));
    F := TKasaK.CreateNew(nil);
    try
      A := TRadScriptBinder.Attach(F);
      Kontrol('H01 Attach', (A <> nil) and (A.Hooks.Count = 1) and (TRadScriptBinder.AttachmentOf(F) = A),
        string.Join(' | ', GErrors.ToArray) + string.Join(' | ', GWarnings.ToStringArray));
      if A = nil then Exit;
      F.btnKaydet.Click;
      Kontrol('H01b Before,orijinal,After', Logged = 'B1,orijinal,A1', Logged);
      LogSil;
      F.Log.Go := False;
      F.btnKaydet.Click;
      Kontrol('H01c Before False -> iptal', Logged = 'B1', Logged);
      F.Log.Go := True;
      // EARS 10: Detach sonrasi orijinal dogrudan
      LogSil;
      A.Detach;
      F.btnKaydet.Click;
      Kontrol('H10 Detach sonrasi orijinal', Logged = 'orijinal', Logged);
    finally
      F.Free;
    end;
    Kontrol('H10b form Free: hata yok', GErrors.Count = 0);
  finally
    Temizle;
  end;
end;

procedure TestZincir;
var
  F: TKasaK;
  A: TRadScriptAttachment;
begin
  Hazirla;
  try
    Kanca('TKasaK', 'S1', SRC_P1, GStore.AddPackage('p1', 1));
    Kanca('TKasaK', 'S2', SRC_P2, GStore.AddPackage('p2', 2));
    F := TKasaK.CreateNew(nil);
    try
      A := TRadScriptBinder.Attach(F);
      Kontrol('H02 iki paket iki kanca', (A <> nil) and (A.Hooks.Count = 2), string.Join(' | ', GErrors.ToArray));
      if A = nil then Exit;
      F.btnKaydet.Click;
      Kontrol('H02b B1,B2,orijinal,A2,A1', Logged = 'B1,B2,orijinal,A2,A1', Logged);
      LogSil;
      F.Log.Go := False;
      F.btnKaydet.Click;
      Kontrol('H02c B1 False -> B2 yok', Logged = 'B1', Logged);
      LogSil;
      F.Log.Go := True;
      F.Log.Go2 := False;
      F.btnKaydet.Click;
      Kontrol('H02d B2 False -> orijinal/A yok', Logged = 'B1,B2', Logged);
    finally
      F.Free;
    end;
  finally
    Temizle;
  end;
end;

procedure TestActionDatasetForm;
var
  F: TKasaK;
  A: TRadScriptAttachment;
  P: TRadScriptPackage;
begin
  Hazirla;
  try
    P := GStore.AddPackage('p1', 1);
    Kanca('TKasaK', 'S1',
      'function actKaydet_Before(Sender: TObject): Boolean; begin Log.Add(''actB''); Result := Log.Go; end;'#13#10 +
      'function qry_BeforePost_Before(Sender: TObject): Boolean; begin Log.Add(''qryB''); Result := Log.Go; end;'#13#10 +
      'procedure qry_BeforePost_After(Sender: TObject); begin Log.Add(''qryA''); end;'#13#10 +
      'procedure Form_AfterCreate(Sender: TObject); begin Form.Caption := ''script''; btnKaydet.Caption := ''Kaydet*''; Log.Add(''created''); end;'#13#10 +
      'function btnYok_Before(Sender: TObject): Boolean; begin Result := True; end;'#13#10 +
      'function Form_OnCloseQuery_Before(Sender: TObject): Boolean; begin Result := True; end;', P);
    F := TKasaK.CreateNew(nil);
    try
      A := TRadScriptBinder.Attach(F);
      Kontrol('H03 Attach', (A <> nil) and (A.Hooks.Count = 2), string.Join(' | ', GErrors.ToArray));
      if A = nil then Exit;
      Kontrol('H05 Form_AfterCreate', (Logged = 'created') and (F.Caption = 'script') and (F.btnKaydet.Caption = 'Kaydet*'),
        Logged + ' ' + F.Caption);
      LogSil;
      F.actKaydet.Execute;
      Kontrol('H03b action Before,orijinal', Logged = 'actB,orijinal-exec', Logged);
      LogSil;
      F.Log.Go := False;
      F.actKaydet.Execute;
      Kontrol('H03c action iptal', Logged = 'actB', Logged);
      F.Log.Go := True;
      LogSil;
      F.qry.Append;
      F.qry.FieldByName('ad').AsString := 'x';
      F.qry.Post;
      Kontrol('H04 dataset BeforePost sarildi', Logged = 'qryB,orijinal-beforepost,qryA', Logged);
      LogSil;
      F.Log.Go := False;
      F.qry.Append;
      F.qry.FieldByName('ad').AsString := 'y';
      F.qry.Post;
      Kontrol('H04b BeforePost iptal (Post yine olur)', (Logged = 'qryB') and (F.qry.RecordCount = 2), Logged);
      Kontrol('H06 btnYok uyarisi', (GWarnings.Count >= 1) and (Pos('btnYok', GWarnings.Text) > 0), GWarnings.Text);
      Kontrol('H07 var parametreli olay reddi', Pos('OnCloseQuery', GWarnings.Text) > 0, GWarnings.Text);
    finally
      F.Free;
    end;
  finally
    Temizle;
  end;
end;

procedure TestHatalar;
var
  F: TKasaK;
  A: TRadScriptAttachment;
begin
  Hazirla;
  try
    Kanca('TKasaK', 'Bozuk', 'function btnKaydet_Before(Sender: TObject): Boolean;'#13#10'begin Result := ; end;',
      GStore.AddPackage('p1', 1));
    F := TKasaK.CreateNew(nil);
    try
      A := TRadScriptBinder.Attach(F);
      Kontrol('H08 derleme hatasi -> nil + OnError', (A = nil) and (GErrors.Count = 1) and GErrors[0].StartsWith('ERadScriptCompile') and
        (Pos('[Bozuk 2:', GErrors[0]) > 0), string.Join(' | ', GErrors.ToArray));
      F.btnKaydet.Click;
      Kontrol('H08b form olaysiz calisir', Logged = 'orijinal', Logged);
    finally
      F.Free;
    end;
  finally
    Temizle;
  end;
  Hazirla;
  try
    Kanca('TKasaK', 'S1',
      'function btnKaydet_Before(Sender: TObject): Boolean; begin if Log.Go then Result := True else Log.Fail(''before patladi''); end;'#13#10 +
      'procedure btnKaydet_After(Sender: TObject); begin Log.Fail(''after patladi''); end;', GStore.AddPackage('p1', 1));
    F := TKasaK.CreateNew(nil);
    try
      A := TRadScriptBinder.Attach(F);
      Kontrol('H09 Attach', A <> nil, string.Join(' | ', GErrors.ToArray));
      if A = nil then Exit;
      F.btnKaydet.Click;
      Kontrol('H09a After istisnasi OnError, yayilmaz', (Logged = 'orijinal') and (GErrors.Count = 1) and (Pos('after patladi', GErrors[0]) > 0),
        Logged + ' ' + string.Join(' | ', GErrors.ToArray));
      LogSil;
      GErrors.Clear;
      F.Log.Go := False;
      F.btnKaydet.Click;
      Kontrol('H09b Before istisnasi = iptal + OnError', (Logged = '') and (GErrors.Count = 1) and (Pos('before patladi', GErrors[0]) > 0),
        Logged + ' ' + string.Join(' | ', GErrors.ToArray));
    finally
      F.Free;
    end;
  finally
    Temizle;
  end;
end;

procedure TestAtaVeKutuphane;
var
  F: TKasaK;
  A: TRadScriptAttachment;
  P: TRadScriptPackage;
begin
  Hazirla;
  try
    P := GStore.AddPackage('p1', 1);
    P.AddScript('Lib', skLibrary, '', 'function Ek: string; begin Result := ''ek''; end;');
    Kanca('TBaseKayit', 'SBase', 'function btnKaydet_Before(Sender: TObject): Boolean; begin Log.Add(''Bbase''); Result := True; end;', P);
    Kanca('TKasaK', 'S1', 'uses Lib;'#13#10 + SRC_P1.Replace('Log.Add(''A1'')', 'Log.Add(''A1-'' + Ek)'), P);
    F := TKasaK.CreateNew(nil);
    try
      A := TRadScriptBinder.Attach(F);
      Kontrol('H11 ata + alt + kutuphane', (A <> nil) and (A.Scripts.Count = 2) and (A.Libraries.Count = 1) and
        (A.Scripts[0].Code = 'SBase'), string.Join(' | ', GErrors.ToArray));
      if A = nil then Exit;
      F.btnKaydet.Click;
      Kontrol('H11b Bbase,B1,orijinal,A1-ek', Logged = 'Bbase,B1,orijinal,A1-ek', Logged);
    finally
      F.Free;
    end;
  finally
    Temizle;
  end;
end;

procedure TestZamanAsimi;
var
  E: TRadScriptEngine;
  S: TRadScript;
  SW: TStopwatch;
  LOk: Boolean;
begin
  Writeln('--- E: motor');
  E := TRadScriptEngine.Create;
  S := TRadScript.Create;
  try
    S.Code := 'Donu';
    S.Source := 'procedure Sonsuz; var i: Integer; begin i := 0; while true do i := i + 1; end;'#13#10 +
      'function Topla(a, b: Integer): Integer; begin Result := a + b; end;';
    E.AddScript(S);
    E.Compile;
    E.SetDeadline(300);
    SW := TStopwatch.StartNew;
    LOk := False;
    try
      E.Call('Donu', 'Sonsuz', []);
    except
      on X: ERadScriptTimeout do LOk := True;
    end;
    Olcum('E14 zaman asimi', SW.ElapsedMilliseconds.ToString + ' ms');
    Kontrol('E14 ERadScriptTimeout <= 400 ms', LOk and (SW.ElapsedMilliseconds <= 400));
    E.SetDeadline(0);
    Kontrol('E14b VM saglam', E.Call('Donu', 'Topla', [2, 3]) = 5);
    Kontrol('E14c HasRoutine/RoutineNames', E.HasRoutine('Donu', 'topla') and not E.HasRoutine('Donu', 'yok') and
      (Length(E.RoutineNames('Donu')) = 2));
  finally
    S.Free;
    E.Free;
  end;
end;

procedure TestOlcum;
var
  F: TKasaK;
  A: TRadScriptAttachment;
  P: TRadScriptPackage;
  i: Integer;
  B: TButton;
  SW: TStopwatch;
begin
  Hazirla;
  try
    P := GStore.AddPackage('p1', 1);
    Kanca('TKasaK', 'S1', SRC_P1, P);
    Kanca('TKasaK', 'S2', 'procedure Form_AfterCreate(Sender: TObject); begin Log.Add(''c''); end;', P);
    Kanca('TBaseKayit', 'S3', 'function actKaydet_Before(Sender: TObject): Boolean; begin Result := True; end;', P);
    F := TKasaK.CreateNew(nil);
    try
      for i := 1 to 20 do
      begin
        B := TButton.Create(F);
        B.Name := 'btn' + IntToStr(i);
        B.Parent := F;
      end;
      SW := TStopwatch.StartNew;
      A := TRadScriptBinder.Attach(F);
      Olcum('H15 Attach (3 script, 24 bilesen)', SW.ElapsedMilliseconds.ToString + ' ms');
      Kontrol('H15 Attach olculdu', A <> nil, string.Join(' | ', GErrors.ToArray));
    finally
      F.Free;
    end;
  finally
    Temizle;
  end;
end;

procedure TestJobs;
var
  LBus: TChannelBus;
  LWorkers: TRadWorkers;
  LJobs: TRadScriptJobs;
  P: TRadScriptPackage;
  LSkipped, LErrors, LRuns: Integer;
  LLogger: TLogger;
  D: IDocDict;
  SW: TStopwatch;
  LErrText: string;
begin
  Writeln('--- J: KP gorevleri');
  Hazirla;
  LLogger := TLogger.Create(nil);
  LBus := TChannelBus.Create;
  LWorkers := TRadWorkers.Create(1, 4);
  try
    P := GStore.AddPackage('kp', 1);
    P.AddScript('Lib', skLibrary, '', 'function Onek: string; begin Result := ''olay:''; end;');
    P.AddScript('Gelen', skEvent, 'efatura.gelen',
      'uses Lib;'#13#10'procedure Calistir(Olay: TRadScriptEvent); begin Log.Add(Onek + Olay.Channel + ''|'' + Olay.Json); Log.Wait(400); end;');
    P.AddScript('Saniye', skSchedule, '* * * * * ?', 'procedure Calistir(Olay: TRadScriptEvent); begin Log.Add(''tik''); end;');
    P.AddScript('Bozuk', skEvent, 'bozuk.kanal', 'procedure Calistir(Olay: TRadScriptEvent); begin Log.Fail(''kp hata''); end;');
    LSkipped := 0;
    LErrors := 0;
    LRuns := 0;
    LJobs := TRadScriptJobs.Create(GStoreIntf, LBus, LWorkers, 2000);
    try
      LJobs.OnPrepare := procedure(AEngine: TRadScriptEngine) begin AEngine.Expose('Log', LLogger); end;
      LJobs.OnSkipped := procedure(AScript: TRadScript)
        begin
          if AScript.Code = 'Gelen' then TInterlocked.Increment(LSkipped);
          LogEkle('skip:' + AScript.Code);
        end;
      LJobs.OnRun := procedure(AScript: TRadScript) begin TInterlocked.Increment(LRuns); end;
      LJobs.OnError := procedure(AScript: TRadScript; E: Exception)
        begin
          TInterlocked.Increment(LErrors);
          LErrText := AScript.Code + ': ' + E.ClassName + ': ' + E.Message;
        end;
      LJobs.Start;
      Kontrol('J12 Start: 3 gorev', LJobs.ScriptCount = 3, LJobs.ScriptCount.ToString);
      D := DocDict('{"no":7}');
      LBus.Publish('efatura.gelen', D);
      LBus.Publish('efatura.gelen', D);   // ilki 400 ms calisiyor -> atlanir
      SW := TStopwatch.StartNew;
      while (SW.ElapsedMilliseconds < 1500) and (Pos('olay:', Logged) = 0) do Sleep(20);
      Sleep(700);
      Kontrol('J12b olay script calisti', Pos('olay:efatura.gelen|{"no":7}', Logged) > 0, Logged);
      Kontrol('J12c ikinci tetikleme atlandi', (LSkipped = 1), 'skipped=' + LSkipped.ToString + ' log=' + Logged);
      LBus.Publish('bozuk.kanal', D);
      SW := TStopwatch.StartNew;
      while (SW.ElapsedMilliseconds < 1500) and (LErrors = 0) do Sleep(20);
      Kontrol('J12d hata OnError''a gider, KP durmaz', (LErrors = 1) and (Pos('kp hata', LErrText) > 0), LErrText);
      Sleep(3200);
      Kontrol('J13 zaman: 3 s icinde >= 2 tik', GLog.Text.CountChar('k') >= 2, Logged);
      LJobs.Stop;
      Kontrol('J13b Stop', LJobs.ScriptCount = 0);
    finally
      LJobs.Free;
    end;
  finally
    LWorkers.Free;
    LBus.Free;
    LLogger.Free;
    Temizle;
  end;
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  GLog := TStringList.Create;
  GLogLock := TCriticalSection.Create;
  GWarnings := TStringList.Create;
  GErrors := TList<string>.Create;
  try
    TRadScriptEngine.RegisterClasses([TLogger, TButton, TAction, TClientDataSet, TForm]);
    try
      TestTemelKanca;
      TestZincir;
      TestActionDatasetForm;
      TestHatalar;
      TestAtaVeKutuphane;
      TestZamanAsimi;
      TestOlcum;
      TestJobs;
    except
      on E: Exception do
      begin
        Inc(GHata);
        Writeln('  [PATLADI] ', E.ClassName, ': ', E.Message);
      end;
    end;
  finally
    GErrors.Free;
    GWarnings.Free;
    GLogLock.Free;
    GLog.Free;
  end;
  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    Halt(1);
end.
