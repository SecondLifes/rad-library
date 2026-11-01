unit rad.script.jobs;

(* KP görevleri: `olay` script'leri rad.eventbus kanalına abone olur, `zaman` script'leri rad.worker
   planıyla çalışır. Her tetiklemede yeni motor (thread başına scripter), süre sınırı OnExecHook ile.
   Aynı script'in önceki çalışması sürüyorsa yeni tetikleme atlanır (yeniden giriş yok). *)

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.SyncObjs,
  mormot.core.variants, mormot.core.unicode,
  rad.script, rad.script.engine, rad.eventbus, rad.worker, rad.date;

type
  /// Script'e `Olay` adıyla açılan tetikleme bilgisi.
  TRadScriptEvent = class
  private
    FChannel: string;
    FJson: string;
    FTime: TDateTime;
    FPackageCode: string;
    FScriptCode: string;
  public
    property Channel: string read FChannel;
    property Json: string read FJson;
    property Time: TDateTime read FTime;
    property PackageCode: string read FPackageCode;
    property ScriptCode: string read FScriptCode;
  end;

  TRadScriptJobEvent = reference to procedure(AScript: TRadScript);
  TRadScriptJobErrorEvent = reference to procedure(AScript: TRadScript; E: Exception);
  TRadScriptPrepareEvent = reference to procedure(AEngine: TRadScriptEngine);

  TRadScriptJobs = class
  private
    FStore: IRadScriptStore;
    FBus: TChannelBus;
    FWorkers: TRadWorkers;
    FDeadlineMs: Cardinal;
    FPackages: TRadScriptPackages;
    FSubs: TList<IChannelSubscription>;
    FJobs: TList<TRadWorkerJobId>;
    FRunning: TDictionary<Integer, Boolean>;
    FLock: TCriticalSection;
    FOnError: TRadScriptJobErrorEvent;
    FOnSkipped: TRadScriptJobEvent;
    FOnRun: TRadScriptJobEvent;
    FOnPrepare: TRadScriptPrepareEvent;
    function TryBegin(AScript: TRadScript): Boolean;
    procedure EndRun(AScript: TRadScript);
    procedure Run(APkg: TRadScriptPackage; AScript: TRadScript; const AChannel, AJson: string);
    function MakeJsonHandler(APkg: TRadScriptPackage; AScript: TRadScript): TChannelHandlerJson;
    function MakePlanProc(APkg: TRadScriptPackage; AScript: TRadScript): TRadWorkerProc;
  public
    constructor Create(const AStore: IRadScriptStore; ABus: TChannelBus; AWorkers: TRadWorkers; ADeadlineMs: Cardinal);
    destructor Destroy; override;
    /// Aktif paketlerin `olay`/`zaman` script'lerini bağlar.
    procedure Start;
    /// Stop + Start: paket değişince çağrılır.
    procedure Refresh;
    procedure Stop;
    function ScriptCount: Integer;
    /// Çalışma hatası/zaman aşımı; nil → yutulur (KP durmaz).
    property OnError: TRadScriptJobErrorEvent read FOnError write FOnError;
    /// Önceki çalışma bitmeden gelen tetikleme.
    property OnSkipped: TRadScriptJobEvent read FOnSkipped write FOnSkipped;
    property OnRun: TRadScriptJobEvent read FOnRun write FOnRun;
    /// Her çalıştırma öncesi motora nesne açmak için (facade, 4. aşama).
    property OnPrepare: TRadScriptPrepareEvent read FOnPrepare write FOnPrepare;
  end;

implementation

const
  ROUTINE_RUN = 'Calistir';

{ TRadScriptJobs }

constructor TRadScriptJobs.Create(const AStore: IRadScriptStore; ABus: TChannelBus; AWorkers: TRadWorkers;
  ADeadlineMs: Cardinal);
begin
  inherited Create;
  FStore := AStore;
  FBus := ABus;
  FWorkers := AWorkers;
  FDeadlineMs := ADeadlineMs;
  FSubs := TList<IChannelSubscription>.Create;
  FJobs := TList<TRadWorkerJobId>.Create;
  FRunning := TDictionary<Integer, Boolean>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TRadScriptJobs.Destroy;
begin
  Stop;
  FLock.Free;
  FRunning.Free;
  FJobs.Free;
  FSubs.Free;
  inherited;
end;

function TRadScriptJobs.TryBegin(AScript: TRadScript): Boolean;
begin
  FLock.Enter;
  try
    Result := not FRunning.ContainsKey(AScript.Id);
    if Result then FRunning.Add(AScript.Id, True);
  finally
    FLock.Leave;
  end;
end;

procedure TRadScriptJobs.EndRun(AScript: TRadScript);
begin
  FLock.Enter;
  try
    FRunning.Remove(AScript.Id);
  finally
    FLock.Leave;
  end;
end;

procedure TRadScriptJobs.Run(APkg: TRadScriptPackage; AScript: TRadScript; const AChannel, AJson: string);
var
  LEngine: TRadScriptEngine;
  LEvent: TRadScriptEvent;
  L: TRadScript;
  LRes: TRadScriptResource;
begin
  if not TryBegin(AScript) then
  begin
    if Assigned(FOnSkipped) then FOnSkipped(AScript);
    Exit;
  end;
  try
    LEvent := TRadScriptEvent.Create;
    LEngine := TRadScriptEngine.Create;
    try
      LEvent.FChannel := AChannel;
      LEvent.FJson := AJson;
      LEvent.FTime := Now;
      LEvent.FScriptCode := AScript.Code;
      LEvent.FPackageCode := APkg.Code;
      for L in APkg.Scripts do
        if L.Active and (L.Kind in [skLibrary, skWindow]) then
        begin
          LEngine.AddScript(L);
          if L.Kind = skWindow then
          begin
            LRes := APkg.ResourceByName(L.DfmFileName);
            if LRes <> nil then LEngine.SetFormResource(L.Code, TEncoding.UTF8.GetString(LRes.Content));
          end;
        end;
      LEngine.AddScript(AScript);
      LEngine.PackageIds := [APkg.Id];
      LEngine.Expose('Olay', LEvent);
      if Assigned(FOnPrepare) then FOnPrepare(LEngine);
      try
        LEngine.Compile;
        LEngine.SetDeadline(FDeadlineMs);
        if Assigned(FOnRun) then FOnRun(AScript);
        LEngine.Call(AScript.Code, ROUTINE_RUN, [LEvent]);
      except
        on E: Exception do
          if Assigned(FOnError) then FOnError(AScript, E);
      end;
    finally
      LEngine.Free;
      LEvent.Free;
    end;
  finally
    EndRun(AScript);
  end;
end;

// Döngü içinde closure: değişken değil değer yakalansın diye fabrika (threading-patterns kuralı).
function TRadScriptJobs.MakeJsonHandler(APkg: TRadScriptPackage; AScript: TRadScript): TChannelHandlerJson;
begin
  Result := procedure(const AJson: IDocDict)
    var
      LJson: string;
    begin
      if AJson <> nil then LJson := Utf8ToString(AJson.Json) else LJson := '';
      Run(APkg, AScript, AScript.Target, LJson);
    end;
end;

function TRadScriptJobs.MakePlanProc(APkg: TRadScriptPackage; AScript: TRadScript): TRadWorkerProc;
begin
  Result := procedure
    begin
      Run(APkg, AScript, '', '');
    end;
end;

procedure TRadScriptJobs.Start;
var
  P: TRadScriptPackage;
  S: TRadScript;
begin
  Stop;
  FPackages := FStore.LoadPackages(False);
  for P in FPackages do
    for S in P.Scripts do
    begin
      if not S.Active then Continue;
      case S.Kind of
        skEvent:
          FSubs.Add(FBus.Subscribe(S.Target, dmAsync, MakeJsonHandler(P, S)));
        skSchedule:
          FJobs.Add(FWorkers.Plan(MakePlanProc(P, S), TDtSchedule.Create(S.Target)));
      end;
    end;
end;

procedure TRadScriptJobs.Refresh;
begin
  Start;
end;

procedure TRadScriptJobs.Stop;
var
  LSub: IChannelSubscription;
  LId: TRadWorkerJobId;
begin
  for LSub in FSubs do
    LSub.Unsubscribe;
  FSubs.Clear;
  for LId in FJobs do
    FWorkers.Cancel(LId);
  FJobs.Clear;
  FreeAndNil(FPackages);
end;

function TRadScriptJobs.ScriptCount: Integer;
begin
  Result := FSubs.Count + FJobs.Count;
end;

initialization
  TRadScriptEngine.RegisterClass(TRadScriptEvent);

end.
