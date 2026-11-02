program ScriptingTest;

(* Giris birimleri (share/rules/single-entry-facade.md): rad.scripting (ERP) ve rad.scripting.kp (KP).
   Host yalniz bu birimleri uses eder; test de oyle yapar. PG canli (testdb), Win32. *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, System.Generics.Collections, System.IOUtils,
  Vcl.Forms, Vcl.StdCtrls,
  Uni, UniProvider, PostgreSQLUniProvider,
  rad.eventbus, rad.worker,
  rad.scripting, rad.scripting.kp;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;
  GEnv: TStringList;
  GLog: TList<string>;

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

type
  TLogger = class(TComponent)
  public
    procedure Add(const S: string);
  end;

  TKasaK = class(TForm)
  public
    btnKaydet: TButton;
    Kayit: TLogger;
    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
  end;

procedure TLogger.Add(const S: string);
begin
  GLog.Add(S);
end;

constructor TKasaK.CreateNew(AOwner: TComponent; Dummy: Integer);
begin
  inherited CreateNew(AOwner, Dummy);
  btnKaydet := TButton.Create(Self);
  btnKaydet.Name := 'btnKaydet';
  btnKaydet.Parent := Self;
  Kayit := TLogger.Create(Self);
  Kayit.Name := 'Kayit';
end;

procedure Testler(ACon: TUniConnection);
var
  LSetup: TRadScriptingSetup;
  LKp: TRadScriptingKpSetup;
  F: TKasaK;
  LAtt: TRadScriptAttachment;
  P: TRadScriptPackage;
  LPkgForm: TRadScriptPackagesForm;
  LMod: TComponent;
  LBus: TChannelBus;
  LWorkers: TRadWorkers;
  LJobs: TRadScriptJobs;
  LWarn: TList<string>;
  LCmds: TList<string>;
begin
  LWarn := TList<string>.Create;
  LCmds := TList<string>.Create;
  try
    // ---- ERP girisi: tek Kur ----
    LSetup := Default(TRadScriptingSetup);
    LSetup.Connection := ACon;
    LSetup.UserId := 1;
    LSetup.UserName := 'test';
    LSetup.UserCode := 'T';
    LSetup.CompanyCode := 'S1';
    LSetup.CompanyName := 'Test Sirketi';
    LSetup.OnWarning := procedure(const S: string) begin LWarn.Add(S); end;
    TRadScripting.Kur(LSetup);
    Kontrol('E01 Kur: store, baglam, tablolar', TRadScripting.Kurulu and (TRadScripting.Store <> nil) and
      (TRadScripting.Context.CompanyName = 'Test Sirketi') and (TRadScriptBinder.Store = TRadScripting.Store) and
      (TRadScripting.Store.LoadPackages(True) <> nil));
    TRadScripting.Store.DeletePackage('test.scripting');

    // paket yaz, formu bagla: Form_AfterCreate + facade (Kullanici) calisir
    P := TRadScriptPackage.Create;
    try
      P.Code := 'test.scripting';
      P.Name := 'Scripting testi';
      P.Version := '1';
      P.Active := True;
      P.AddScript('KasaForm', skForm, 'TKasaK',
        'procedure Form_AfterCreate(Sender: TObject); begin btnKaydet.Caption := Kullanici.Kod + ''/'' + Sirket.Kod; Kayit.Add(''ok''); end;');
      P.AddScript('KurGuncelle', skCommand, 'TKasaModul', 'procedure KurGuncelle_Execute(Sender: TObject); begin Kayit.Add(''kur''); end;');
      TRadScripting.Store.SavePackage(P);
    finally
      P.Free;
    end;
    F := TKasaK.CreateNew(nil);
    try
      LAtt := TRadScripting.Bagla(F);
      Kontrol('E02 Bagla: script + facade (Kullanici/Sirket) tek Kur ile', (LAtt <> nil) and (F.btnKaydet.Caption = 'T/S1') and
        (GLog.IndexOf('ok') >= 0) and (LWarn.Count = 0), F.btnKaydet.Caption + ' ' + string.Join(';', LWarn.ToArray));
    finally
      F.Free;
    end;

    // modul komutlari
    LMod := TComponent.Create(nil);
    try
      TRadScripting.KomutlariBagla(LMod,
        procedure(const ACode, ACaption: string; AOnExecute: TNotifyEvent) begin LCmds.Add(ACode); end);
      Kontrol('E03 KomutlariBagla: TComponent hedefi (TKasaModul degil) -> komut yok, hata yok', LCmds.Count = 0, string.Join(';', LCmds.ToArray));
    finally
      LMod.Free;
    end;

    // paket yoneticisi
    LPkgForm := TRadScripting.PaketYoneticisi(nil);
    try
      Kontrol('E04 PaketYoneticisi: store ve baglamla acildi, paket listede', (LPkgForm.vwPaket.DataController.RecordCount >= 1) and
        (LPkgForm.Context = TRadScripting.Context));
    finally
      LPkgForm.Free;
    end;

    TRadScripting.Store.DeletePackage('test.scripting');
    TRadScripting.Kapat;
    Kontrol('E05 Kapat', not TRadScripting.Kurulu and (TRadScriptBinder.Store = nil) and (TRadScripting.Store = nil));

    // ---- KP girisi ----
    LBus := TChannelBus.Create;
    LWorkers := TRadWorkers.Create(1, 2);
    try
      LKp := Default(TRadScriptingKpSetup);
      LKp.Connection := ACon;
      LKp.CompanyCode := 'S1';
      LKp.DeadlineMs := 2000;
      LJobs := TRadScriptingKp.Kur(LKp, LBus, LWorkers);
      Kontrol('K01 KP Kur: gorevler basladi', TRadScriptingKp.Kurulu and (LJobs = TRadScriptingKp.Jobs) and (LJobs.ScriptCount = 0) and
        (TRadScriptingKp.Context <> nil) and not TRadScriptingKp.Context.OnConfirm('soru?'));
      TRadScriptingKp.Yenile;
      TRadScriptingKp.Kapat;
      Kontrol('K02 KP Kapat', not TRadScriptingKp.Kurulu and (TRadScriptingKp.Jobs = nil));
    finally
      LWorkers.Free;
      LBus.Free;
    end;
  finally
    LCmds.Free;
    LWarn.Free;
  end;
end;

var
  LCon: TUniConnection;
  LPath: string;
begin
  ReportMemoryLeaksOnShutdown := True;
  GEnv := TStringList.Create;
  GLog := TList<string>.Create;
  try
    LPath := TPath.Combine(TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'), 'rad'), 'test-db.env');
    if TFile.Exists(LPath) then GEnv.LoadFromFile(LPath, TEncoding.UTF8);
    try
      System.Classes.RegisterClass(TButton);
      TRadScriptEngine.RegisterClasses([TLogger, TButton, TForm]);
      LCon := Baglan;
      if LCon = nil then Inc(GHata)
      else
        try
          Testler(LCon);
        finally
          LCon.Free;
        end;
    except
      on E: Exception do
      begin
        Inc(GHata);
        Writeln('[ISTISNA] ', E.ClassName, ': ', E.Message);
      end;
    end;
  finally
    GLog.Free;
    GEnv.Free;
  end;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then ExitCode := 1;
end.
