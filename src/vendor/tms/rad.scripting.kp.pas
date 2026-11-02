unit rad.scripting.kp;

(* Script sisteminin kontrol paneli (KP) giriş birimi (share/rules/single-entry-facade.md): KP yalnız bunu
   `uses` eder. Kullanım:  uses rad.scripting.kp;  TRadScriptingKp.Kur(LSetup, Bus, Workers);
   Alt katman: motor + `olay`/`zaman` görevleri + facade; tasarımcı/IDE yok (RadScriptTms paketi). *)

interface

uses
  System.SysUtils, System.Classes,
  Uni, Help.uni,
  rad.eventbus, rad.worker,
  rad.script, rad.script.engine, rad.script.jobs, rad.script.facade, rad.script.uni;

type
  TRadScriptKind = rad.script.TRadScriptKind;
  TRadScript = rad.script.TRadScript;
  TRadScriptPackage = rad.script.TRadScriptPackage;
  TRadScriptPackages = rad.script.TRadScriptPackages;
  IRadScriptStore = rad.script.IRadScriptStore;
  TRadScriptPackageFile = rad.script.TRadScriptPackageFile;
  ERadScript = rad.script.ERadScript;
  TRadScriptEngine = rad.script.engine.TRadScriptEngine;
  TRadScriptJobs = rad.script.jobs.TRadScriptJobs;
  TRadScriptEvent = rad.script.jobs.TRadScriptEvent;
  TRadScriptJobEvent = rad.script.jobs.TRadScriptJobEvent;
  TRadScriptJobErrorEvent = rad.script.jobs.TRadScriptJobErrorEvent;
  TRadScriptContext = rad.script.facade.TRadScriptContext;
  IRadScriptMailer = rad.script.facade.IRadScriptMailer;

const
  // enum değerleri takma adla gelmez; host `skForm` yazabilsin diye
  skForm = rad.script.skForm;
  skEvent = rad.script.skEvent;
  skSchedule = rad.script.skSchedule;
  skCommand = rad.script.skCommand;
  skLibrary = rad.script.skLibrary;
  skWindow = rad.script.skWindow;

type
  TRadScriptingKpSetup = record
    Connection: TUniConnection;
    UserId: Integer;
    UserName: string;
    UserCode: string;
    CompanyCode: string;
    CompanyName: string;
    Mailer: IRadScriptMailer;
    OnLog: TProc<string>;
    /// Her Calistir için süre sınırı (ms); 0 = yok.
    DeadlineMs: Cardinal;
    OnError: TRadScriptJobErrorEvent;
  end;

  TRadScriptingKp = class
  private
    class var FContext: TRadScriptContext;
    class var FJobs: TRadScriptJobs;
    class var FClassesRegistered: Boolean;
  public
    /// Store, tanım tabloları, bağlam (Msg.Soru KP'de her zaman False), UniDAC sınıf kayıtları, görevler (Start).
    class function Kur(const ASetup: TRadScriptingKpSetup; ABus: TChannelBus; AWorkers: TRadWorkers): TRadScriptJobs;
    /// Paketler değişince abonelik ve planları yeniler.
    class procedure Yenile;
    class procedure Kapat;
    class function Kurulu: Boolean;
    class property Jobs: TRadScriptJobs read FJobs;
    class property Context: TRadScriptContext read FContext;
  end;

implementation

{ TRadScriptingKp }

class function TRadScriptingKp.Kur(const ASetup: TRadScriptingKpSetup; ABus: TChannelBus;
  AWorkers: TRadWorkers): TRadScriptJobs;
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
  FContext.OnConfirm := function(const AText: string): Boolean begin Result := False; end;   // KP'de soru yok
  if not FClassesRegistered then
  begin
    RegisterUniClasses;
    FClassesRegistered := True;
  end;
  FJobs := TRadScriptJobs.Create(LStore, ABus, AWorkers, ASetup.DeadlineMs);
  FJobs.OnPrepare := TRadScriptFacade.PrepareProc(FContext);
  FJobs.OnError := ASetup.OnError;
  FJobs.Start;
  Result := FJobs;
end;

class procedure TRadScriptingKp.Yenile;
begin
  if FJobs <> nil then FJobs.Refresh;
end;

class procedure TRadScriptingKp.Kapat;
begin
  if FJobs <> nil then
  begin
    FJobs.Stop;
    FreeAndNil(FJobs);
  end;
  FreeAndNil(FContext);
end;

class function TRadScriptingKp.Kurulu: Boolean;
begin
  Result := FJobs <> nil;
end;

end.
