program FacadeVclTest;

(* rad.script.typedhooks: EARS 8 (TCloseQueryEvent) ve 9 (TcxEditValidateEvent). DevExpress -> yalniz Win32.
   rad.script.dev kayit listesi de burada olculur. *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, System.Generics.Collections, System.Diagnostics,
  Vcl.Forms, Vcl.Controls,
  cxEdit, cxTextEdit, cxGraphics, cxControls, cxLookAndFeels, cxLookAndFeelPainters, cxContainer,
  rad.sqlfilter, rad.script, rad.script.engine, rad.script.hooks, rad.script.typedhooks, rad.script.dev, rad.script.facade;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;
  GLog: TStringList;
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

type
  TLogger = class(TComponent)
  public
    Go: Boolean;
    procedure Add(const S: string);
  end;

  TKasaK = class(TForm)
  private
    procedure DoCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure DoValidate(Sender: TObject; var DisplayValue: Variant; var ErrorText: TCaption; var Error: Boolean);
  public
    edt: TcxTextEdit;
    Log: TLogger;
    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
  end;

  TFakeStore = class(TInterfacedObject, IRadScriptStore)
  public
    Pkg: TRadScriptPackage;
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
    function ResourcesNamed(const AFileName: string): TObjectList<TRadScriptResource>;
    function LibrariesOf(const APackageIds: TArray<Integer>): TRadScripts;
    function ParamsOf(const APackageIds: TArray<Integer>): TObjectList<TRadScriptParam>;
  end;

procedure TLogger.Add(const S: string);
begin
  GLog.Add(S);
end;

constructor TKasaK.CreateNew(AOwner: TComponent; Dummy: Integer);
begin
  inherited CreateNew(AOwner, Dummy);
  OnCloseQuery := DoCloseQuery;
  edt := TcxTextEdit.Create(Self);
  edt.Name := 'edt';
  edt.Parent := Self;
  edt.Properties.OnValidate := DoValidate;
  Log := TLogger.Create(Self);
  Log.Name := 'Kayit';   // facade'in Log nesnesiyle cakismasin
  Log.Go := True;
end;

procedure TKasaK.DoCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  GLog.Add('orijinal-closequery');
end;

procedure TKasaK.DoValidate(Sender: TObject; var DisplayValue: Variant; var ErrorText: TCaption; var Error: Boolean);
begin
  GLog.Add('orijinal-validate:' + VarToStr(DisplayValue));
end;

function TFakeStore.Dialect: TRadSqlDialect; begin Result := sdPostgreSQL; end;
procedure TFakeStore.EnsureDefinitionTables; begin end;
function TFakeStore.LoadPackages(AIncludeInactive: Boolean): TRadScriptPackages; begin Result := TRadScriptPackages.Create(True); end;
function TFakeStore.LoadPackage(const ACode: string): TRadScriptPackage; begin Result := nil; end;
procedure TFakeStore.SavePackage(APkg: TRadScriptPackage); begin end;
procedure TFakeStore.ImportPackage(APkg: TRadScriptPackage); begin end;
procedure TFakeStore.DeletePackage(const ACode: string); begin end;
procedure TFakeStore.ApplyPendingDbSteps(APkg: TRadScriptPackage); begin end;
function TFakeStore.LoadResource(APackageId: Integer; const AFileName: string; AStream: TStream): Boolean; begin Result := False; end;
function TFakeStore.ResourcesNamed(const AFileName: string): TObjectList<TRadScriptResource>; begin Result := TObjectList<TRadScriptResource>.Create(True); end;
function TFakeStore.LibrariesOf(const APackageIds: TArray<Integer>): TRadScripts; begin Result := TRadScripts.Create(True); end;
function TFakeStore.ParamsOf(const APackageIds: TArray<Integer>): TObjectList<TRadScriptParam>; begin Result := TObjectList<TRadScriptParam>.Create(True); end;

function TFakeStore.ScriptsFor(AKind: TRadScriptKind; const ATarget: string): TRadScripts;
var
  S, C: TRadScript;
begin
  Result := TRadScripts.Create(True);
  for S in Pkg.Scripts do
    if (S.Kind = AKind) and SameText(S.Target, ATarget) then
    begin
      C := TRadScript.Create;
      C.Assign(S);
      C.PackageId := Pkg.Id;
      Result.Add(C);
    end;
end;

function Logged: string;
begin
  Result := string.Join(',', GLog.ToStringArray);
end;

procedure TipliKancaTestleri;
var
  LStore: TFakeStore;
  LStoreIntf: IRadScriptStore;
  F: TKasaK;
  A: TRadScriptAttachment;
  LCanClose: Boolean;
  LValue: Variant;
  LText: TCaption;
  LError: Boolean;
  Ctx: TRadScriptContext;
begin
  Writeln('--- T: tipli kancalar');
  LStore := TFakeStore.Create;
  LStoreIntf := LStore;
  LStore.Pkg := TRadScriptPackage.Create;
  Ctx := TRadScriptContext.Create;
  try
    LStore.Pkg.Id := 1;
    LStore.Pkg.Code := 'test.tipli';
    LStore.Pkg.Name := 'tipli';
    LStore.Pkg.AddScript('S1', skForm, 'TKasaK',
      'function Form_OnCloseQuery_Before(Sender: TObject; CanClose: Boolean): Boolean; begin if CanClose then Kayit.Add(''cqB:True'') else Kayit.Add(''cqB:False''); Result := Kayit.Go; end;'#13#10 +
      'procedure Form_OnCloseQuery_After(Sender: TObject; CanClose: Boolean); begin Kayit.Add(''cqA''); end;'#13#10 +
      'function edt_OnValidate_Before(Sender: TObject; DisplayValue: Variant; ErrorText: string): Boolean;'#13#10 +
      'begin Kayit.Add(''vB:'' + VarToStr(DisplayValue)); if DisplayValue = ''kotu'' then begin Msg.HataMetni(''Kötü değer''); Result := False; end else Result := True; end;'#13#10 +
      'procedure edt_OnValidate_After(Sender: TObject; DisplayValue: Variant; ErrorText: string); begin Kayit.Add(''vA''); end;');
    TRadScriptBinder.Store := LStoreIntf;
    TRadScriptBinder.OnError := procedure(AForm: TCustomForm; E: Exception) begin GErrors.Add(E.Message); end;
    TRadScriptBinder.OnWarning := procedure(const S: string) begin GErrors.Add('UYARI ' + S); end;
    TRadScriptFacade.Bind(Ctx);
    F := TKasaK.CreateNew(nil);
    try
      A := TRadScriptBinder.Attach(F);
      Kontrol('T08 Attach: 2 tipli kanca', (A <> nil) and (A.Hooks.Count = 2) and (GErrors.Count = 0), string.Join('|', GErrors.ToArray));
      if A = nil then Exit;
      // EARS 8
      LCanClose := True;
      F.OnCloseQuery(F, LCanClose);
      Kontrol('T08b CloseQuery Before,orijinal,After', (Logged = 'cqB:True,orijinal-closequery,cqA') and LCanClose, Logged);
      GLog.Clear;
      F.Log.Go := False;
      LCanClose := True;
      F.OnCloseQuery(F, LCanClose);
      Kontrol('T08c Before False -> CanClose False, orijinal yok', (Logged = 'cqB:True') and not LCanClose, Logged);
      F.Log.Go := True;
      // EARS 9
      GLog.Clear;
      LValue := 'iyi';
      LText := '';
      LError := False;
      F.edt.Properties.OnValidate(F.edt, LValue, LText, LError);
      Kontrol('T09 Validate gecer', (Logged = 'vB:iyi,orijinal-validate:iyi,vA') and not LError, Logged);
      GLog.Clear;
      LValue := 'kotu';
      LText := '';
      LError := False;
      F.edt.Properties.OnValidate(F.edt, LValue, LText, LError);
      Kontrol('T09b Validate False -> Error, ErrorText = Msg.HataMetni', (Logged = 'vB:kotu') and LError and (LText = 'Kötü değer'), Logged + ' ' + LText);
    finally
      F.Free;
    end;
    Kontrol('T09c form Free: hata yok', GErrors.Count = 0, string.Join('|', GErrors.ToArray));
  finally
    Ctx.Free;
    LStore.Pkg.Free;
    TRadScriptBinder.Store := nil;
    TRadScriptBinder.OnInstallFacade := nil;
    LStoreIntf := nil;
  end;
end;

procedure DevKayitOlcumu;
var
  SW: TStopwatch;
  E: TRadScriptEngine;
begin
  Writeln('--- D: DevExpress kayit');
  RegisterDevExpressClasses;
  SW := TStopwatch.StartNew;
  E := TRadScriptEngine.Create;
  try
    Writeln('  [OLCUM] motor kurulumu (24 DevExpress + facade + VCL siniflari) = ', SW.ElapsedMilliseconds, ' ms');
    Kontrol('D01 TcxGrid kayitli', E.Scripter.Classes.ClassByName('TcxGrid') <> nil);
  finally
    E.Free;
  end;
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  GLog := TStringList.Create;
  GErrors := TList<string>.Create;
  try
    try
      TRadScriptEngine.RegisterClasses([TLogger, TcxTextEdit, TForm]);
      TipliKancaTestleri;
      DevKayitOlcumu;
    except
      on E: Exception do
      begin
        Inc(GHata);
        Writeln('  [PATLADI] ', E.ClassName, ': ', E.Message);
      end;
    end;
  finally
    GErrors.Free;
    GLog.Free;
  end;
  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    Halt(1);
end.
