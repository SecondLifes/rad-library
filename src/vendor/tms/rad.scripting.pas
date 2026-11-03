unit rad.scripting;

(* Script sisteminin giriş birimi (share/rules/single-entry-facade.md): ERP host'u yalnız bunu `uses` eder.
   Kullanım:  uses rad.scripting;  TRadScripting.Kur(LSetup);  TBaseForm.DoCreate → TRadScripting.Bagla(Self)
   Burada mantık yok: alt birimlerin türleri takma adla dışa verilir, kurulum tek çağrıdır. KP için rad.scripting.kp. *)

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Forms,
  Uni, Help.uni,
  rad.script, rad.script.override, rad.script.engine, rad.script.hooks, rad.script.jobs, rad.script.facade,
  rad.script.commands, rad.script.typedhooks, rad.script.dev, rad.script.uni, rad.script.design, rad.script.ide,
  rad.script.packages, rad.script.newscript,
  rad.formstate.customize.session; // registers the TRadFormCustomizer session on load

type
  // ---- model (rad.script) ----
  TRadScriptKind = rad.script.TRadScriptKind;
  TRadScript = rad.script.TRadScript;
  TRadScripts = rad.script.TRadScripts;
  TRadScriptPackage = rad.script.TRadScriptPackage;
  TRadScriptPackages = rad.script.TRadScriptPackages;
  TRadScriptParam = rad.script.TRadScriptParam;
  TRadScriptDbStep = rad.script.TRadScriptDbStep;
  TRadScriptResource = rad.script.TRadScriptResource;
  IRadScriptStore = rad.script.IRadScriptStore;
  TRadScriptPackageFile = rad.script.TRadScriptPackageFile;
  TRadScriptDdl = rad.script.TRadScriptDdl;
  ERadScript = rad.script.ERadScript;
  ERadScriptFormat = rad.script.ERadScriptFormat;
  ERadScriptExec = rad.script.ERadScriptExec;
  ERadScriptCompile = rad.script.ERadScriptCompile;
  ERadScriptRuntime = rad.script.ERadScriptRuntime;
  ERadScriptTimeout = rad.script.ERadScriptTimeout;
  TRadPropSnapshot = rad.script.override.TRadPropSnapshot;
  // ---- çalışma zamanı ----
  TRadScriptEngine = rad.script.engine.TRadScriptEngine;
  TRadScriptForm = rad.script.engine.TRadScriptForm;
  TRadScriptBinder = rad.script.hooks.TRadScriptBinder;
  TRadScriptAttachment = rad.script.hooks.TRadScriptAttachment;
  TRadScriptErrorEvent = rad.script.hooks.TRadScriptErrorEvent;
  TRadScriptWarningEvent = rad.script.hooks.TRadScriptWarningEvent;
  TRadScriptContext = rad.script.facade.TRadScriptContext;
  IRadScriptMailer = rad.script.facade.IRadScriptMailer;
  TRadScriptMessageEvent = rad.script.facade.TRadScriptMessageEvent;
  TRadScriptConfirmEvent = rad.script.facade.TRadScriptConfirmEvent;
  TRadScriptFacade = rad.script.facade.TRadScriptFacade;
  TRadScriptCommands = rad.script.commands.TRadScriptCommands;
  TRadScriptAddCommand = rad.script.commands.TRadScriptAddCommand;
  TRadScriptJobs = rad.script.jobs.TRadScriptJobs;
  TRadScriptEvent = rad.script.jobs.TRadScriptEvent;
  // ---- tasarım / IDE ----
  TRadScriptDesigner = rad.script.design.TRadScriptDesigner;
  TRadScriptDesignMode = rad.script.design.TRadScriptDesignMode;
  TRadScriptIde = rad.script.ide.TRadScriptIde;
  TRadScriptPackagesForm = rad.script.packages.TRadScriptPackagesForm;
  TRadScriptOpenFormEvent = rad.script.packages.TRadScriptOpenFormEvent;
  TRadScriptNewScriptForm = rad.script.newscript.TRadScriptNewScriptForm;
  TRadFormCustomizeSession = rad.formstate.customize.session.TRadFormCustomizeSession;

const
  // enum değerleri takma adla gelmez; host `skForm` yazabilsin diye
  skForm = rad.script.skForm;
  skEvent = rad.script.skEvent;
  skSchedule = rad.script.skSchedule;
  skCommand = rad.script.skCommand;
  skLibrary = rad.script.skLibrary;
  skWindow = rad.script.skWindow;

type
  /// Kurulum bilgisi; host bağlantı kurulunca bir kez doldurur.
  TRadScriptingSetup = record
    Connection: TUniConnection;
    UserId: Integer;
    UserName: string;
    UserCode: string;
    CompanyCode: string;
    CompanyName: string;
    Mailer: IRadScriptMailer;
    OnLog: TProc<string>;
    OnMessage: TRadScriptMessageEvent;
    OnConfirm: TRadScriptConfirmEvent;
    OnWarning: TRadScriptWarningEvent;
    OnError: TRadScriptErrorEvent;
  end;

  /// Tek kurulum noktası. Alt birimlerin hiçbiri host'ta doğrudan kullanılmaz.
  TRadScripting = class
  private
    class var FContext: TRadScriptContext;
    class var FClassesRegistered: Boolean;
  public
    /// Store (bağlantının _Scripts'i), tanım tabloları, bağlam, facade, UniDAC/DevExpress sınıf kayıtları,
    /// uyarı/hata kancaları. Yeniden çağrı önceki kurulumu kapatır.
    class procedure Kur(const ASetup: TRadScriptingSetup);
    class procedure Kapat;
    class function Kurulu: Boolean;
    /// Host'un taban formundan (TBaseForm.DoCreate, inherited'dan sonra): düzen + kancalar + Form_AfterCreate.
    /// Kur yapılmadıysa ya da script yoksa nil.
    class function Bagla(AForm: TCustomForm): TRadScriptAttachment;
    /// Modül başlangıcından: paketin `komut` script'leri AAdd ile menü komutu olur.
    class procedure KomutlariBagla(AModule: TComponent; const AAdd: TRadScriptAddCommand);
    /// Sistem → Script paketleri.
    class function PaketYoneticisi(AOwner: TComponent): TRadScriptPackagesForm;
    /// Açık formda tasarım kipi (yetki host'ta).
    class function Tasarla(AForm: TCustomForm; const APackageCode: string): TRadScriptDesigner;
    class function Store: IRadScriptStore;
    class property Context: TRadScriptContext read FContext;
  end;

implementation

{ TRadScripting }

class procedure TRadScripting.Kur(const ASetup: TRadScriptingSetup);
var
  LStore: IRadScriptStore;
begin
  if ASetup.Connection = nil then raise ERadScript.Create('Kur: bağlantı verilmedi.');
  Kapat;
  LStore := ASetup.Connection._Scripts;
  LStore.EnsureDefinitionTables;
  FContext := TRadScriptContext.Create;
  FContext.Connection := ASetup.Connection;
  FContext.Store := LStore;
  FContext.UserId := ASetup.UserId;
  FContext.UserName := ASetup.UserName;
  FContext.UserCode := ASetup.UserCode;
  FContext.CompanyCode := ASetup.CompanyCode;
  FContext.CompanyName := ASetup.CompanyName;
  FContext.Mailer := ASetup.Mailer;
  FContext.OnLog := ASetup.OnLog;
  FContext.OnMessage := ASetup.OnMessage;
  FContext.OnConfirm := ASetup.OnConfirm;
  TRadScriptBinder.Store := LStore;
  TRadScriptBinder.OnWarning := ASetup.OnWarning;
  TRadScriptBinder.OnError := ASetup.OnError;
  TRadScriptFacade.Bind(FContext);
  if not FClassesRegistered then
  begin
    TRadScriptUni.RegisterAll;
    TRadScriptDev.RegisterAll;   // tipli kancalar (typedhooks) kendi initialization'ında kayıtlı
    FClassesRegistered := True;
  end;
end;

class procedure TRadScripting.Kapat;
begin
  if TRadScriptIde.Active <> nil then TRadScriptIde.Active.Close;
  if TRadScriptDesigner.Active <> nil then TRadScriptDesigner.Active.Close;
  TRadScriptBinder.Store := nil;
  TRadScriptBinder.OnInstallFacade := nil;
  TRadScriptBinder.OnWarning := nil;
  TRadScriptBinder.OnError := nil;
  FreeAndNil(FContext);
end;

class function TRadScripting.Kurulu: Boolean;
begin
  Result := FContext <> nil;
end;

class function TRadScripting.Store: IRadScriptStore;
begin
  Result := TRadScriptBinder.Store;
end;

class function TRadScripting.Bagla(AForm: TCustomForm): TRadScriptAttachment;
begin
  Result := TRadScriptBinder.Attach(AForm);
end;

class procedure TRadScripting.KomutlariBagla(AModule: TComponent; const AAdd: TRadScriptAddCommand);
begin
  TRadScriptCommands.Attach(AModule, AAdd);
end;

class function TRadScripting.PaketYoneticisi(AOwner: TComponent): TRadScriptPackagesForm;
begin
  Result := TRadScriptPackagesForm.Open(AOwner, Store, FContext);
end;

class function TRadScripting.Tasarla(AForm: TCustomForm; const APackageCode: string): TRadScriptDesigner;
begin
  Result := TRadScriptDesigner.Start(AForm, APackageCode);
end;

end.
