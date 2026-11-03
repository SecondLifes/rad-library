program FacadeTest;

(* rad.script.facade / commands / uni: docs/specs/rad.script.facade.md EARS 1-7, 10-12.
   Db icin PG testdb canli (%LOCALAPPDATA%\rad\test-db.env); gerisi bellek ici. Win32 + Win64.
   docs/script-api.md bu testten uretilir (ExportReference). *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, System.Generics.Collections, System.IOUtils, System.UITypes,
  Data.DB, Vcl.Forms, Vcl.StdCtrls,
  Uni, UniProvider, PostgreSQLUniProvider,
  rad.sqlfilter, rad.script, rad.script.engine, rad.script.hooks, rad.script.jobs, rad.script.facade,
  rad.script.commands, rad.script.uni, Help.uni;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;
  GEnv: TStringList;
  GMessages: TStringList;
  GLogs: TStringList;
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

procedure EnvYukle;
var
  LPath: string;
begin
  GEnv := TStringList.Create;
  LPath := TPath.Combine(TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'), 'rad'), 'test-db.env');
  if TFile.Exists(LPath) then
    GEnv.LoadFromFile(LPath, TEncoding.UTF8);
end;

function Env(const AKey: string; const ADefault: string = ''): string;
var
  i: Integer;
  LLine: string;
begin
  Result := GetEnvironmentVariable(AKey);
  if Result <> '' then Exit;
  for i := 0 to GEnv.Count - 1 do
  begin
    LLine := GEnv[i];
    if LLine.StartsWith(AKey + '=') then
      Exit(System.SysUtils.Trim(LLine.Substring(Length(AKey) + 1)));
  end;
  Result := ADefault;
end;

type
  TFakeMailer = class(TInterfacedObject, IRadScriptMailer)
  public
    Sent: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure Send(const ATo, ASubject, ABody: string);
  end;

  TKasaModul = class(TComponent)
  end;

constructor TFakeMailer.Create;
begin
  inherited Create;
  Sent := TStringList.Create;
end;

destructor TFakeMailer.Destroy;
begin
  Sent.Free;
  inherited;
end;

procedure TFakeMailer.Send(const ATo, ASubject, ABody: string);
begin
  Sent.Add(ATo + '|' + ASubject + '|' + ABody);
end;

function Baglan: TUniConnection;
begin
  Result := TUniConnection.Create(nil);
  try
    Result.ProviderName := 'PostgreSQL';
    Result.Server := Env('RAD_PG_HOST', '127.0.0.1');
    Result.Port := StrToIntDef(Env('RAD_PG_PORT', '5432'), 5432);
    Result.Database := Env('RAD_PG_DB', 'testdb');
    Result.Username := Env('RAD_PG_USER', 'postgres');
    Result.Password := Env('RAD_PG_PASS');
    Result.LoginPrompt := False;
    Result.Connect;
    Writeln('Baglandi: PG -> ', Result.Server, '/', Result.Database);
  except
    on E: Exception do
    begin
      Writeln('  [BAGLANAMADI] PG: ', E.Message);
      Result.Free;
      Result := nil;
    end;
  end;
end;

function Sayi(ACon: TUniConnection; const ASql: string): Integer;
var
  Q: TUniQuery;
begin
  Q := TUniQuery.Create(nil);
  try
    Q.Connection := ACon;
    Q.SQL.Text := ASql;
    Q.Open;
    Result := Q.Fields[0].AsInteger;
  finally
    Q.Free;
  end;
end;

procedure SessizSil(ACon: TUniConnection; const ATable: string);
begin
  try
    ACon.ExecSQL('drop table ' + ATable);
  except
  end;
end;

function Calistir(AContext: TRadScriptContext; const ACode, ASource, ARoutine: string; const APkgIds: TArray<Integer>): Variant;
var
  E: TRadScriptEngine;
  S: TRadScript;
begin
  E := TRadScriptEngine.Create;
  S := TRadScript.Create;
  try
    S.Code := ACode;
    S.Source := ASource;
    E.AddScript(S);
    E.PackageIds := APkgIds;
    TRadScriptFacade.Install(E, AContext);
    E.Compile;
    Result := E.Call(ACode, ARoutine, []);
  finally
    S.Free;
    E.Free;
  end;
end;

procedure Firlatir(const AAd: string; AProc: TProc; const ABeklenen: string = '');
begin
  try
    AProc;
    Kontrol(AAd, False, 'istisna firlatilmadi');
  except
    on E: Exception do Kontrol(AAd, (ABeklenen = '') or (Pos(ABeklenen, E.Message) > 0), E.ClassName + ': ' + E.Message);
  end;
end;

procedure FacadeTestleri(ACon: TUniConnection);
var
  Ctx: TRadScriptContext;
  LStore: IRadScriptStore;
  P: TRadScriptPackage;
  Mailer: TFakeMailer;
  MailerIntf: IRadScriptMailer;
  V: Variant;
  LRef: string;
begin
  Writeln('--- F: facade (PG)');
  SessizSil(ACon, 'rad_test_fc');
  ACon.ExecSQL('create table rad_test_fc (id integer primary key, ad varchar(50))');
  ACon.ExecSQL('insert into rad_test_fc values (1, ''bir''), (2, ''iki''), (3, ''üç'')');
  LStore := ACon._Scripts;
  LStore.EnsureDefinitionTables;
  LStore.DeletePackage('test.facade');
  P := TRadScriptPackage.Create;
  Mailer := TFakeMailer.Create;
  MailerIntf := Mailer;
  Ctx := TRadScriptContext.Create;
  try
    P.Code := 'test.facade';
    P.Name := 'facade';
    P.AddParam('MailAdresi', 'a@b.com');
    P.AddScript('Bos', skLibrary, '', 'function X: Integer; begin Result := 1; end;');
    LStore.SavePackage(P);
    Ctx.Connection := ACon;
    Ctx.Store := LStore;
    Ctx.UserId := 7;
    Ctx.UserName := 'Ali';
    Ctx.UserCode := 'ali';
    Ctx.CompanyCode := 'FIRMA';
    Ctx.CompanyName := 'Firma AŞ';
    Ctx.Mailer := nil;
    Ctx.OnLog := procedure(S: string) begin GLogs.Add(S); end;
    Ctx.OnMessage := procedure(const S: string; K: TMsgDlgType) begin GMessages.Add(IntToStr(Ord(K)) + ':' + S); end;
    Ctx.OnConfirm := nil;

    // EARS 1: parametreli sorgu zinciri
    V := Calistir(Ctx, 'T1', 'function Dene: string; begin Result := Db.Sorgu(''select ad from rad_test_fc where id = :id'').Param(''id'', 3).Deger; end;', 'Dene', [P.Id]);
    Kontrol('F01 Db.Sorgu.Param.Deger', V = 'üç', VarToStr(V));
    Firlatir('F01b Param adi yok', procedure begin
      Calistir(Ctx, 'T1b', 'function Dene: string; begin Result := Db.Sorgu(''select 1'').Param(''yok'', 1).Deger; end;', 'Dene', [P.Id]); end, 'yok');
    V := Calistir(Ctx, 'T1c', 'function Dene: Integer; begin Result := Db.Sayi(''select count(*) from rad_test_fc''); end;', 'Dene', [P.Id]);
    Kontrol('F01c Db.Sayi', V = 3, VarToStr(V));
    V := Calistir(Ctx, 'T1d', 'function Dene: Variant; begin Result := Db.Deger(''select ad from rad_test_fc where id = 99''); end;', 'Dene', [P.Id]);
    Kontrol('F01d Db.Deger bos = Null', VarIsNull(V));

    // EARS 2: Ac + Kapat demeden bitir -> sizinti yok (ReportMemoryLeaksOnShutdown), dataset gezilebilir
    V := Calistir(Ctx, 'T2', 'function Dene: string; var D: TDataSet; begin D := Db.Sorgu(''select ad from rad_test_fc order by id'').Ac; Result := ''''; ' +
      'while not D.Eof do begin Result := Result + D.FieldByName(''ad'').AsString + '',''; D.Next; end; end;', 'Dene', [P.Id]);
    Kontrol('F02 Ac + TDataSet gezme', V = 'bir,iki,üç,', VarToStr(V));

    // EARS 3: transaction
    Calistir(Ctx, 'T3', 'procedure Dene; begin Db.BaslaIslem; Db.Calistir(''insert into rad_test_fc values (4, ''''dört'''')''); Db.GeriAl; end;', 'Dene', [P.Id]);
    Kontrol('F03 GeriAl', Sayi(ACon, 'select count(*) from rad_test_fc') = 3);
    Calistir(Ctx, 'T3b', 'procedure Dene; begin Db.BaslaIslem; Db.Calistir(''insert into rad_test_fc values (4, ''''dört'''')''); Db.Onayla; end;', 'Dene', [P.Id]);
    Kontrol('F03b Onayla', Sayi(ACon, 'select count(*) from rad_test_fc') = 4);
    Firlatir('F03c ic ice BaslaIslem', procedure begin
      Calistir(Ctx, 'T3c', 'procedure Dene; begin Db.BaslaIslem; Db.BaslaIslem; end;', 'Dene', [P.Id]); end, 'Zaten');
    Kontrol('F03d yarim kalan islem geri alindi', not ACon.InTransaction and (Sayi(ACon, 'select count(*) from rad_test_fc') = 4));

    // EARS 4: Soru KP'de False
    V := Calistir(Ctx, 'T4', 'function Dene: Boolean; begin Result := Msg.Soru(''Devam?''); end;', 'Dene', [P.Id]);
    Kontrol('F04 Msg.Soru OnConfirm nil -> False', V = False);
    Ctx.OnConfirm := function(const S: string): Boolean begin Result := S = 'Devam?'; end;
    V := Calistir(Ctx, 'T4b', 'function Dene: Boolean; begin Result := Msg.Soru(''Devam?''); end;', 'Dene', [P.Id]);
    Kontrol('F04b Msg.Soru OnConfirm', V = True);
    Calistir(Ctx, 'T4c', 'procedure Dene; begin Msg.Bilgi(''b''); Msg.Uyari(''u''); Msg.Hata(''h''); end;', 'Dene', [P.Id]);
    Kontrol('F04c Msg.Bilgi/Uyari/Hata OnMessage', (GMessages.Count = 3) and (GMessages[0] = '2:b') and (GMessages[1] = '0:u') and (GMessages[2] = '1:h'),
      GMessages.Text);

    // EARS 5: Param
    V := Calistir(Ctx, 'T5', 'function Dene: string; begin Result := Param.Deger(''MailAdresi'') + ''|'' + Param.Deger(''yok'') + ''|'' + Param.DegerVarsayilan(''yok'', ''v''); end;', 'Dene', [P.Id]);
    Kontrol('F05 Param.Deger/DegerVarsayilan', V = 'a@b.com||v', VarToStr(V));
    V := Calistir(Ctx, 'T5b', 'function Dene: string; begin Result := Param.Deger(''MailAdresi''); end;', 'Dene', []);
    Kontrol('F05b paket yok -> bos', V = '');

    // EARS 6: Mail
    Firlatir('F06 Mailer nil', procedure begin
      Calistir(Ctx, 'T6', 'procedure Dene; begin Mail.Gonder(''a@b.com'', ''konu'', ''govde''); end;', 'Dene', [P.Id]); end, 'Posta');
    Ctx.Mailer := MailerIntf;
    Calistir(Ctx, 'T6b', 'procedure Dene; begin Mail.Gonder(''a@b.com'', ''konu'', ''govde''); end;', 'Dene', [P.Id]);
    Kontrol('F06b sahte mailer', (Mailer.Sent.Count = 1) and (Mailer.Sent[0] = 'a@b.com|konu|govde'));

    // Kullanici / Sirket / Log
    V := Calistir(Ctx, 'T7', 'function Dene: string; begin Log.Yaz(''merhaba''); Log.Hata(''kotu''); Result := IntToStr(Kullanici.Id) + Kullanici.Ad + Kullanici.Kod + Sirket.Kod + Sirket.Ad; end;', 'Dene', [P.Id]);
    Kontrol('F07 Kullanici/Sirket/Log', (V = '7AlialiFIRMAFirma AŞ') and (GLogs.Count = 2) and (GLogs[1] = 'HATA: kotu'), VarToStr(V) + ' ' + GLogs.Text);

    // EARS 10: gizli uyeler
    TRadScriptUni.RegisterAll;
    Firlatir('F10 TUniConnection.Password gizli', procedure begin
      Calistir(Ctx, 'T10', 'function Dene: string; var C: TUniConnection; begin Result := ''''; end;'#13#10 +
        'function Dene2(C: TUniConnection): string; begin Result := C.Password; end;', 'Dene', [P.Id]); end, 'Password');
    V := Calistir(Ctx, 'T10b', 'function Dene: string; var C: TUniConnection; begin Result := ''ok''; end;'#13#10 +
      'function Dene2(C: TUniConnection): Boolean; begin Result := C.Connected; end;', 'Dene', [P.Id]);
    Kontrol('F10b TUniConnection.Connected gorunur (derlendi)', V = 'ok');

    // EARS 11/12: referans
    LRef := Calistir(Ctx, 'T11', 'function Dene: Integer; begin Result := 0; end;', 'Dene', [P.Id]);
    // referans icin motoru dogrudan kur
    begin
      var E := TRadScriptEngine.Create;
      try
        E.PackageIds := [P.Id];
        TRadScriptFacade.Install(E, Ctx);
        LRef := E.ExportReference;
      finally
        E.Free;
      end;
    end;
    Kontrol('F11 ExportReference icerik', (Pos('## TRadScriptDb', LRef) > 0) and (Pos('`Sorgu(', LRef) > 0) and (Pos('`Soru(', LRef) > 0) and
      (Pos('- `Db`: TRadScriptDb', LRef) > 0) and (Pos('Password', LRef) = 0) and (Pos('## TUniConnection', LRef) > 0), LRef.Substring(0, 200));
    TFile.WriteAllText(TPath.Combine(ExtractFilePath(ParamStr(0)), 'script-api.md'), LRef, TEncoding.UTF8);
    Writeln('  [OLCUM] script-api.md ', Length(LRef), ' karakter -> ', TPath.Combine(ExtractFilePath(ParamStr(0)), 'script-api.md'));
    Kontrol('F12 Db metot sayisi = bildirilen (overload yok)', (Pos('`BaslaIslem()`', LRef) > 0) and (Pos('`Deger(ASql: string)', LRef) > 0));
  finally
    Ctx.Free;
    MailerIntf := nil;
    P.Free;
    LStore.DeletePackage('test.facade');
    SessizSil(ACon, 'rad_test_fc');
  end;
end;

type
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

procedure KomutTestleri;
var
  LStore: TFakeStore;
  LStoreIntf: IRadScriptStore;
  LModul: TKasaModul;
  A: TRadScriptAttachment;
  LAdded: TStringList;
  LHandler: TNotifyEvent;
  Ctx: TRadScriptContext;
begin
  Writeln('--- K: komut');
  LStore := TFakeStore.Create;
  LStoreIntf := LStore;
  LStore.Pkg := TRadScriptPackage.Create;
  LAdded := TStringList.Create;
  Ctx := TRadScriptContext.Create;
  LModul := TKasaModul.Create(nil);
  try
    LStore.Pkg.Id := 1;
    LStore.Pkg.Code := 'test.komut';
    LStore.Pkg.Name := 'komut';
    LStore.Pkg.AddScript('KurGuncelle', skCommand, 'TKasaModul',
      'procedure KurGuncelle_Execute(Sender: TObject); begin Log.Yaz(''kur guncellendi ''+ Kullanici.Kod); end;').Name := 'Kurları güncelle';
    LStore.Pkg.AddScript('Eksik', skCommand, 'TKasaModul', 'procedure Baska; begin end;');
    TRadScriptBinder.Store := LStoreIntf;
    TRadScriptBinder.OnError := procedure(AForm: TCustomForm; E: Exception) begin GErrors.Add(E.Message); end;
    TRadScriptBinder.OnWarning := procedure(const S: string) begin GErrors.Add('UYARI ' + S); end;
    Ctx.UserCode := 'ali';
    Ctx.OnLog := procedure(S: string) begin GLogs.Add(S); end;
    TRadScriptFacade.Bind(Ctx);
    GLogs.Clear;
    GErrors.Clear;
    LHandler := nil;
    A := TRadScriptCommands.Attach(LModul,
      procedure(const ACode, ACaption: string; AOnExecute: TNotifyEvent)
      begin
        LAdded.Add(ACode + '=' + ACaption);
        LHandler := AOnExecute;
      end);
    Kontrol('K07 Attach: 1 komut eklendi, eksik olan uyari', (A <> nil) and (LAdded.Count = 1) and (LAdded[0] = 'KurGuncelle=Kurları güncelle') and
      (GErrors.Count = 1) and GErrors[0].StartsWith('UYARI'), LAdded.Text + string.Join('|', GErrors.ToArray));
    if Assigned(LHandler) then
    begin
      LHandler(LModul);
      Kontrol('K07b handler script''i calistirdi (facade dahil)', (GLogs.Count = 1) and (GLogs[0] = 'kur guncellendi ali'), GLogs.Text);
    end;
    Kontrol('K07c AttachmentOf', TRadScriptBinder.AttachmentOf(LModul) = A);
  finally
    LModul.Free;   // attachment + motor + komut nesneleri birlikte
    Ctx.Free;
    LAdded.Free;
    LStore.Pkg.Free;
    TRadScriptBinder.Store := nil;
    TRadScriptBinder.OnInstallFacade := nil;
    LStoreIntf := nil;
  end;
end;

var
  LCon: TUniConnection;
begin
  ReportMemoryLeaksOnShutdown := True;
  EnvYukle;
  GMessages := TStringList.Create;
  GLogs := TStringList.Create;
  GErrors := TList<string>.Create;
  try
    try
      LCon := Baglan;
      if LCon = nil then Inc(GHata)
      else
        try
          FacadeTestleri(LCon);
        finally
          LCon.Free;
        end;
      KomutTestleri;
    except
      on E: Exception do
      begin
        Inc(GHata);
        Writeln('  [PATLADI] ', E.ClassName, ': ', E.Message);
      end;
    end;
  finally
    GErrors.Free;
    GLogs.Free;
    GMessages.Free;
    GEnv.Free;
  end;
  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    Halt(1);
end.
