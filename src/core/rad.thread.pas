unit rad.thread;

{
  TRadTask — Fluent Async Task Engine (mORMot2 entegrasyonlu)

  Thread modeli:
    Before      → UI thread, senkron, background başlamadan önce
                  (form'dan bağlantı bilgisi, filtre değerleri gibi UI verisi alınır)
    Run/ThenBy  → Background thread (CreateAnonymousThread)
    OnSuccess/OnError/OnCancel/OnTimeout/After/OnFinally → UI thread, HER ZAMAN
                  senkron (Synchronize) — deterministik sıralama garantisi
    OnProgress  → UI thread, Throttle korumalı (Queue) — tek asenkron callback

  Timeout: cooperative (watchdog thread YOK) — InternalExecute'un checkpoint'lerinde
    CheckTimedOut ile kontrol edilir; süre dolunca OnCancel değil OnTimeout tetiklenir.

  IRadTaskContext: TRadTask'ın kendisi context; callback'ler TRadTask alır.
    .Data            — TDocVariantData (SetData/GetData, key-value), FDataLock ile thread-safe
    .StepResult      — TValue (ThenBy adımları arası tipli sonuç) — KİLİTLENMEZ,
                       pipeline disiplini içinde (tek seferde tek thread) kullanılmalı
    .ReportProgress  — Throttle korumalı progress tetikleyici
    .CheckCancelled  — İptal kontrolü (dahili + harici token)

  Örnek:
    TRadTask.Create(procedure(t) begin
      t.StepResult := TValue.From<TDataSet>(DB.Sorgu(t.GetData('q', '')));
    end)
    .Named('MusteriYukle')
    .Before(procedure(t) begin t.SetData('q', edtArama.Text) end)
    .ThenBy(procedure(t) begin
      var ds := t.StepResult.AsType<TDataSet>;
      t.StepResult := TValue.From<string>(ds.FieldByName('ADI').AsString);
    end)
    .OnSuccess(procedure(t) begin lbl.Caption := t.StepResult.AsType<string> end)
    .OnError(procedure(t) begin ShowMessage(t.ErrorMsg) end)
    .Retry(3, 500)
    .WithTimeout(10000)
    .Start;
}

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Variants,
  System.Rtti, System.Generics.Collections,
  Winapi.Windows, Winapi.Messages, Winapi.ActiveX,
  mormot.core.base,
  mormot.core.os,
  mormot.core.data,
  mormot.core.variants,
  mormot.core.json,
  mormot.core.log;

type
  TRadTask = class;

  TRadTaskProc = TProc<TRadTask>;

  TCOMThreadModel = (ctmNone, ctmApartment, ctmMultiThreaded);

  { ── Cancellation ─────────────────────────────────────────────────────────── }

  IRadCancelToken = interface
    ['{B1C2D3E4-F5A6-7890-BCDE-F12345678901}']
    function  IsCancelled: Boolean;
    procedure ThrowIfCancelled;
  end;

  IRadCancellationSource = interface
    ['{C2D3E4F5-A6B7-8901-CDEF-234567890123}']
    procedure Cancel;
    procedure Reset;
    function  Token: IRadCancelToken;
  end;

  { ── İstisnalar ───────────────────────────────────────────────────────────── }

  ERadTaskCancelled      = class(Exception);  // CheckCancelled(True) tarafından fırlatılır
  ERadTaskTimeout        = class(Exception);  // CheckTimedOut(True) tarafından fırlatılır
  ERadTaskAlreadyStarted = class(Exception);  // Aynı TRadTask ikinci kez Start/Wait edilirse fırlatılır
  ERadTaskInvalidArgument = class(Exception); // Create'e nil AProc geçilirse fırlatılır

  { ── TRadTask ─────────────────────────────────────────────────────────────── }

  TRadTask = class
  private
    // Kimlik ve veri
    FID          : TGUID;
    FTag         : Integer;
    FName        : string;
    FData        : TDocVariantData;  // FDataLock ile korunur (thread-safe)
    FDataLock    : TLightLock;
    // FStepResult KİLİTLENMEZ — ThenBy adımları arasında pipeline disiplini
    // içinde (tek seferde tek thread) kullanılmalıdır; aynı anda birden
    // fazla thread'den doğrudan okunup yazılmamalıdır.
    FStepResult  : TValue;

    // Zamanlama
    FPreDelay    : Integer;
    FPostDelay   : Integer;
    FRepeatCount : Integer;
    FRepeatDelay : Integer;
    FRetryCount  : Integer;
    FRetryDelay  : Integer;
    FTimeout     : Cardinal;

    // Throttle
    FThrottleMs       : Cardinal;
    FLastProgressTick : Cardinal;
    FProgressLock     : TCriticalSection;

    // Callback'ler
    FProc        : TRadTaskProc;
    FBefore      : TRadTaskProc;
    FAfter       : TRadTaskProc;
    FOnSuccess   : TRadTaskProc;
    FOnError     : TRadTaskProc;
    FOnProgress  : TRadTaskProc;
    FOnCancel    : TRadTaskProc;
    FOnFinally   : TRadTaskProc;
    FOnTimeout   : TRadTaskProc;
    FThenList    : TList<TRadTaskProc>;

    // Durum — TInterlocked ile erişilen bayraklar (0/1)
    FCancelledInt : Integer;
    FSuccessInt   : Integer;
    FRunningInt   : Integer;  // Aynı zamanda çift-başlatma korumasında kullanılır
    FDoneInt      : Integer;
    FTimedOutInt  : Integer;
    FProgress    : Integer;
    FProgressMsg : string;
    FErrorMsg    : string;
    FStartTime   : TDateTime;
    FEndTime     : TDateTime;
    FRunStartTick: Int64;      // RunBackground başlangıcı — cooperative timeout tabanı
    FStatusLock  : TLightLock; // Artık yalnızca FErrorMsg'i korur (string, atomik interlock edilemez)

    // Harici iptal
    FCancelToken : IRadCancelToken;

    // COM
    FCOMModel       : TCOMThreadModel;
    FCOMInitialized : Boolean;

    // Dahili kontrol
    FCancelEvent    : TEvent;  // İptal sinyali + kesilebilir bekleme (PreDelay/PostDelay/Retry/RepeatDelay)
    FCompletedEvent : TEvent;  // Tamamlanma sinyali — SADECE tüm callback'ler bittikten sonra set edilir

    procedure InternalExecute;
    procedure FireCallback(AProc: TRadTaskProc; UseQueue: Boolean = False);
    // WhenAll'un OnFinally zincirleme wrapper'ı — BİLİNÇLİ olarak ayrı, adlı
    // bir class function (döngü içine iç içe closure DEĞİL): bkz.
    // project_delphi_compiler_quirks.md — closure-içinde-closure'ın döngü-
    // lokal değişkeni (originalFinally) doğru yakalamadığı doğrulandı;
    // parametre-tabanlı closure capture bu sorunu yaşamıyor.
    class function MakeChainedFinally(const AOriginal: TRadTaskProc;
      ARemaining: PInteger; ADoneEvent: TEvent): TRadTaskProc; static;
    procedure InitCOM;
    procedure UninitCOM;
    procedure DoFree;
    procedure RunBackground(AWait: Boolean);
    function  GetProgress: Integer;
    function  GetProgressMsg: string;
    function  GetErrorMsg: string;
    function  GetSuccess: Boolean;
    function  GetCancelled: Boolean;
    function  GetRunning: Boolean;
    function  GetDone: Boolean;
    function  GetTimedOut: Boolean;
  public
    constructor Create(AProc: TRadTaskProc);
    destructor Destroy; override;

    //  deprecated 'Etkisi yok - lifecycle callback''leri artik her zaman senkron calisir';

    { ── Fluent: Zamanlama ── }
    function SetPreDelay (AMs: Integer): TRadTask;
    function SetPostDelay(AMs: Integer): TRadTask;
    function SetRepeat(N: Integer; DelayMs: Integer = 0): TRadTask;
    function SetRetry (N: Integer; DelayMs: Integer = 500): TRadTask;
    function Retry    (N: Integer; DelayMs: Integer = 500): TRadTask;  // alias
    function SetThrottle(AMs: Cardinal = 500): TRadTask;


    function WithTimeout(AMs: Cardinal): TRadTask;

    { ── Fluent: Kimlik ve COM ── }
    function SetName(const AName: string): TRadTask;
    function Named  (const AName: string): TRadTask;  // alias
    function SetTag(ATag: Integer): TRadTask;
    function SetCOM(AModel: TCOMThreadModel = ctmApartment): TRadTask;

    { ── Fluent: Callback'ler ── }
    function Before    (A: TRadTaskProc): TRadTask;
    function After     (A: TRadTaskProc): TRadTask;
    function OnSuccess (A: TRadTaskProc): TRadTask;
    function OnError   (A: TRadTaskProc): TRadTask;
    function OnProgress(A: TRadTaskProc): TRadTask;
    function OnCancel  (A: TRadTaskProc): TRadTask;
    function OnFinally (A: TRadTaskProc): TRadTask;
    function OnTimeout (A: TRadTaskProc): TRadTask;
    function ThenBy    (A: TRadTaskProc): TRadTask;

    { ── Fluent: İptal ve Veri ── }
    function WithCancel(const AToken: IRadCancelToken): TRadTask;
    function SetData(const AKey: string; const AValue: Variant): TRadTask; overload;

    { ── Kontrol ── }
    procedure Cancel;
    function  CheckCancelled(RaiseException: Boolean = False): Boolean;
    function  CheckTimedOut(RaiseException: Boolean = False): Boolean;
    procedure ReportProgress(APct: Integer; const AMsg: string = ''; UseQueue: Boolean = True);

    { ── Çalıştırma ── }
    procedure Start;     // Fire & Forget (Otomatik Free)
    procedure Wait;      // UI Donmadan Bekle (Otomatik Free)

    { ── Class Yardımcılar ── }
    class procedure InUI(AProc: TProc);
    class function WhenAll(const ATasks: array of TRadTask): TRadTask;

    { ── Veri Okuma ── }
    function GetData(const AKey: string; const ADefault: Variant): Variant;
    function ElapsedMs: Int64;

    { ── Salt Okunur Özellikler ── }
    property ID          : TGUID    read FID;
    property Name        : string   read FName;
    property Tag         : Integer  read FTag;
    property Cancelled   : Boolean  read GetCancelled;
    property Success     : Boolean  read GetSuccess;
    property Progress    : Integer  read GetProgress;
    property ProgressMsg : string   read GetProgressMsg;
    property ErrorMsg    : string   read GetErrorMsg;
    property StepResult  : TValue   read FStepResult write FStepResult;
    property IsRunning   : Boolean  read GetRunning;
    property IsDone      : Boolean  read GetDone;
    property TimedOut    : Boolean  read GetTimedOut;
  end;

function NewCancellationSource: IRadCancellationSource;

implementation

uses
  System.DateUtils,
  Vcl.Forms;

{ ── TRadCancellationImpl ─────────────────────────────────────────────────── }

type
  TRadCancellationImpl = class(TInterfacedObject, IRadCancelToken, IRadCancellationSource)
  private
    FLock     : TLightLock;
    FCancelled: Boolean;
  public
    function  IsCancelled: Boolean;
    procedure ThrowIfCancelled;
    procedure Cancel;
    procedure Reset;
    function  Token: IRadCancelToken;
  end;

function TRadCancellationImpl.IsCancelled: Boolean;
begin
  FLock.Lock;
  Result := FCancelled;
  FLock.UnLock;
end;

procedure TRadCancellationImpl.ThrowIfCancelled;
begin
  // ERadTaskCancelled fırlatılır — TRadTask motoru cancel akışı için bunu
  // yakalıyor; farklı bir tip (ör. RTL'in EOperationCancelled'ı) fırlatılırsa
  // generic Exception handler'a düşer, OnCancel yerine OnError/retry tetiklenir.
  if IsCancelled then
    raise ERadTaskCancelled.Create('Task cancelled');
end;

procedure TRadCancellationImpl.Cancel;
begin
  FLock.Lock;
  FCancelled := True;
  FLock.UnLock;
end;

procedure TRadCancellationImpl.Reset;
begin
  FLock.Lock;
  FCancelled := False;
  FLock.UnLock;
end;

function TRadCancellationImpl.Token: IRadCancelToken;
begin
  Result := Self;
end;



{ ── TRadTask ─────────────────────────────────────────────────────────────── }

constructor TRadTask.Create(AProc: TRadTaskProc);
begin
  inherited Create;
  if not Assigned(AProc) then
    raise ERadTaskInvalidArgument.Create('TRadTask.Create: AProc nil olamaz');
  CreateGUID(FID);
  FProc             := AProc;
  FRepeatCount      := 1;
  FRetryCount       := 0;
  FRetryDelay       := 500;
  FThrottleMs       := 500;
  FCOMModel         := ctmNone;
  FCancelEvent      := TEvent.Create(nil, True, False, '');  // manual-reset, başlangıçta sinyalsiz
  FCompletedEvent   := TEvent.Create(nil, True, True,  '');  // manual-reset, başlangıçta SİNYALLİ (idle durum)
  FProgressLock     := TCriticalSection.Create;
  FThenList         := TList<TRadTaskProc>.Create;
  FData.InitFast(dvObject);
  FName             := 'UnnamedTask';
end;

destructor TRadTask.Destroy;
begin
  FThenList.Free;
  FProgressLock.Free;
  FCancelEvent.Free;
  FCompletedEvent.Free;
  inherited;
end;

{ ── Dahili ───────────────────────────────────────────────────────────────── }

procedure TRadTask.InitCOM;
var HR: HRESULT;
begin
  if FCOMModel = ctmNone then Exit;
  case FCOMModel of
    ctmApartment:    HR := CoInitialize(nil);
    ctmMultiThreaded: HR := CoInitializeEx(nil, COINIT_MULTITHREADED);
  else Exit;
  end;
  FCOMInitialized := Succeeded(HR);
end;

procedure TRadTask.UninitCOM;
begin
  if FCOMInitialized then
  begin
    CoUninitialize;
    FCOMInitialized := False;
  end;
end;

procedure TRadTask.FireCallback(AProc: TRadTaskProc; UseQueue: Boolean);
var
  SafeInvoke: TThreadProcedure;
begin
  if not Assigned(AProc) then Exit;
  SafeInvoke := procedure
    begin
      try
        AProc(Self);
      except
        on E: Exception do
          TSynLog.Add.Log(sllError, 'Task [%] Callback Failed: %', [FName, E.Message]);
      end;
    end;
  if TThread.CurrentThread.ThreadID = MainThreadID then
  begin
    SafeInvoke;
    Exit;
  end;
  if UseQueue then
    TThread.ForceQueue(nil, SafeInvoke)
  else
    TThread.Synchronize(nil, SafeInvoke);
end;

procedure TRadTask.InternalExecute;
var
  I, Attempt: Integer;
begin
  for I := 1 to FRepeatCount do
  begin
    // Kısa-devre değerlendirmesi yüzünden ikisinin de yan etkisi (bayrak set
    // etme) kaçırılmasın diye ayrı değişkenlere atanıp `or` ile birleştirilir.
    var LCancelled := CheckCancelled;
    var LTimedOut  := CheckTimedOut;
    if LCancelled or LTimedOut then Break;
    Attempt := 0;

    repeat
      try
        FProc(Self);

        // ThenBy zinciri
        for var step in FThenList do
        begin
          var LStepCancelled := CheckCancelled;
          var LStepTimedOut  := CheckTimedOut;
          if LStepCancelled or LStepTimedOut then Break;
          step(Self);
        end;

        TInterlocked.Exchange(FSuccessInt, 1);
        Break;

      except
        on E: ERadTaskCancelled do
        begin
          TInterlocked.Exchange(FCancelledInt, 1);
          TSynLog.Add.Log(sllWarning, 'Task [%] Cancelled (checkpoint): %', [FName, E.Message]);
          Break;
        end;
        on E: ERadTaskTimeout do
        begin
          TInterlocked.Exchange(FTimedOutInt, 1);
          TSynLog.Add.Log(sllWarning, 'Task [%] Timed out (checkpoint): %', [FName, E.Message]);
          Break;
        end;
        on E: Exception do
        begin
          Inc(Attempt);
          TInterlocked.Exchange(FSuccessInt, 0);
          FStatusLock.Lock;
          FErrorMsg := E.Message;
          FStatusLock.UnLock;
          TSynLog.Add.Log(sllError, 'Task [%] Repeat % Attempt % Failed: %',
            [FName, I, Attempt, FErrorMsg]);

          if Attempt <= FRetryCount then
          begin
            if FRetryDelay > 0 then FCancelEvent.WaitFor(FRetryDelay);
            // Cancel()/timeout bekleme sırasında tetiklenmiş olabilir — tekrar denemeden önce kontrol et
            var LRetryCancelled := CheckCancelled;
            var LRetryTimedOut  := CheckTimedOut;
            if LRetryCancelled or LRetryTimedOut then Break;
          end
          else
          begin
            FireCallback(FOnError, False);
            Break;
          end;
        end;
      end;
    until Attempt > FRetryCount;

    // İptal/timeout retry sırasında geldiyse dış döngüyü de kır — aksi halde
    // bir sonraki repeat turunda FProc gereksiz yere bir kez daha çalışır.
    if (TInterlocked.CompareExchange(FCancelledInt, 0, 0) = 1)
       or (TInterlocked.CompareExchange(FTimedOutInt, 0, 0) = 1) then
      Break;

    if (I < FRepeatCount) and (FRepeatDelay > 0) then
      FCancelEvent.WaitFor(FRepeatDelay);
  end;
end;

procedure TRadTask.DoFree;
begin
  TThread.Queue(nil, procedure begin Self.Free end);
end;

procedure TRadTask.RunBackground(AWait: Boolean);
begin
  // Çift-başlatma koruması: aynı TRadTask'ı ikinci kez Start/Wait etmek
  // programlama hatasıdır — ilk çalışan görevin ownership'ini bozmamak için
  // burada Free ÇAĞRILMAZ, hata çağırana (ikinci, hatalı çağrıya) senkron
  // olarak yayılır.
  if TInterlocked.CompareExchange(FRunningInt, 1, 0) <> 0 then
    raise ERadTaskAlreadyStarted.CreateFmt('Task [%s] zaten çalışıyor veya başlatıldı', [FName]);

  TInterlocked.Exchange(FDoneInt, 0);
  FRunStartTick := Int64(GetTickCount64);  // cooperative timeout tabanı
  FCancelEvent.ResetEvent;
  FCompletedEvent.ResetEvent;

  // Timeout watchdog thread YOK — InternalExecute'un checkpoint'lerinde
  // cooperative CheckTimedOut ile kontrol edilir (dangling-Self riski yok).

  TThread.CreateAnonymousThread(procedure begin
    InitCOM;
    try
      try
        if FPreDelay > 0 then
          FCancelEvent.WaitFor(FPreDelay);

        InternalExecute;

        FireCallback(FAfter, False);

        if TInterlocked.CompareExchange(FTimedOutInt, 0, 0) = 1 then
        begin
          TSynLog.Add.Log(sllWarning, 'Task Timed Out: % (%dms)', [FName, FTimeout]);
          FireCallback(FOnTimeout, False);
        end
        else if TInterlocked.CompareExchange(FCancelledInt, 0, 0) = 1 then
        begin
          TSynLog.Add.Log(sllWarning, 'Task Cancelled: %', [FName]);
          FireCallback(FOnCancel, False);
        end
        else if TInterlocked.CompareExchange(FSuccessInt, 0, 0) = 1 then
        begin
          TSynLog.Add.Log(sllInfo, 'Task Success: % (%ms)', [FName, ElapsedMs]);
          FireCallback(FOnSuccess, False);
        end;

        if FPostDelay > 0 then
          FCancelEvent.WaitFor(FPostDelay);

      except
        on E: ERadTaskCancelled do
        begin
          TInterlocked.Exchange(FCancelledInt, 1);
          TSynLog.Add.Log(sllWarning, 'Task [%] Cancelled (outer): %', [FName, E.Message]);
        end;
        on E: ERadTaskTimeout do
        begin
          TInterlocked.Exchange(FTimedOutInt, 1);
          TSynLog.Add.Log(sllWarning, 'Task [%] Timed out (outer): %', [FName, E.Message]);
        end;
        on E: Exception do
        begin
          FStatusLock.Lock;
          FErrorMsg := E.Message;
          FStatusLock.UnLock;
          TSynLog.Add.Log(sllError, 'Task Fatal [%]: %', [FName, FErrorMsg]);
          FireCallback(FOnError, False);
        end;
      end;
    finally
      FEndTime := Now;
      TInterlocked.Exchange(FRunningInt, 0);
      TInterlocked.Exchange(FDoneInt, 1);
      // OnFinally artık her zaman senkron — bu satır dönene kadar callback
      // main thread'de kesin tamamlanmış olur; tamamlanma sinyali ancak
      // ONDAN SONRA set edilir (bkz. bug #4 düzeltmesi).
      FireCallback(FOnFinally, False);
      FCompletedEvent.SetEvent;
      UninitCOM;
      if not AWait then DoFree;
    end;
  end).Start;
end;

{ ── Çalıştırma ───────────────────────────────────────────────────────────── }

procedure TRadTask.Start;
var
  Msg: TMsg;
begin
  FStartTime := Now;

  // Before — UI thread'de senkron, background başlamadan önce
  if Assigned(FBefore) then
  begin
    if TThread.CurrentThread.ThreadID = MainThreadID then
      FBefore(Self)
    else
      TThread.Synchronize(nil, procedure begin FBefore(Self) end);
    if CheckCancelled then begin DoFree; Exit end;
  end;

  TSynLog.Add.Log(sllEnter, 'Task Start: %', [FName]);
  RunBackground(False);
end;

procedure TRadTask.Wait;
begin
  FStartTime := Now;

  // Before — UI thread'de senkron
  if Assigned(FBefore) then
  begin
    if TThread.CurrentThread.ThreadID = MainThreadID then
      FBefore(Self)
    else
      TThread.Synchronize(nil, procedure begin FBefore(Self) end);
    if CheckCancelled then begin Free; Exit end;
  end;

  TSynLog.Add.Log(sllEnter, 'Task Wait: %', [FName]);
  RunBackground(True);

  // SADECE FCompletedEvent beklenir (FCancelEvent değil) — bir Cancel() bu
  // döngüyü artık erken bitirmez, görev gerçekten tamamlanana kadar sürer.
  if TThread.CurrentThread.ThreadID = MainThreadID then
  begin
    // UI donmadan bekle — VCL'in kendi mesaj pompasını kullan.
    while FCompletedEvent.WaitFor(5) = wrTimeout do
    begin
      Application.ProcessMessages;
      CheckSynchronize(5);
    end;
  end
  else
    // Application.ProcessMessages main thread DIŞINDA güvensiz (VCL) — bir
    // arka plan thread'inden Wait çağrılırsa doğrudan bloklayarak bekle.
    FCompletedEvent.WaitFor(INFINITE);

  TSynLog.Add.Log(sllInfo, 'Task Wait Finished: % (%ms)', [FName, ElapsedMs]);
  Free;
end;

{ ── Kontrol ──────────────────────────────────────────────────────────────── }

procedure TRadTask.Cancel;
begin
  TInterlocked.Exchange(FCancelledInt, 1);
  FCancelEvent.SetEvent;  // Tamamlanma sinyaline (FCompletedEvent) hiç dokunmaz
end;

function TRadTask.CheckCancelled(RaiseException: Boolean): Boolean;
begin
  if (TInterlocked.CompareExchange(FCancelledInt, 0, 0) = 0)
     and Assigned(FCancelToken) and FCancelToken.IsCancelled then
    TInterlocked.Exchange(FCancelledInt, 1);
  Result := TInterlocked.CompareExchange(FCancelledInt, 0, 0) = 1;
  if Result and RaiseException then
    raise ERadTaskCancelled.CreateFmt('Task [%s] cancelled', [FName]);
end;

function TRadTask.CheckTimedOut(RaiseException: Boolean): Boolean;
begin
  // Görev henüz başlamadıysa (FRunStartTick=0 / FRunningInt=0) sistem çalışma
  // süresini (uptime) yanlışlıkla süre aşımı sanmamak için erken çık.
  if (FRunStartTick = 0) or (TInterlocked.CompareExchange(FRunningInt, 0, 0) = 0) then
    Exit(False);
  Result := (FTimeout > 0) and (Int64(GetTickCount64) - FRunStartTick >= Int64(FTimeout));
  if Result then
    TInterlocked.Exchange(FTimedOutInt, 1);
  if Result and RaiseException then
    raise ERadTaskTimeout.CreateFmt('Task [%s] %dms zaman aşımına uğradı', [FName, FTimeout]);
end;

procedure TRadTask.ReportProgress(APct: Integer; const AMsg: string; UseQueue: Boolean);
var
  NowTick: Cardinal;
  CanFire: Boolean;
begin
  if APct < 0 then APct := 0
  else if APct > 100 then APct := 100;
  FProgressLock.Enter;
  try
    FProgress    := APct;
    FProgressMsg := AMsg;
    if not Assigned(FOnProgress) then Exit;
    if FThrottleMs > 0 then
    begin
      if APct >= 100 then
        CanFire := True
      else
      begin
        NowTick := GetTickCount;
        CanFire := (NowTick - FLastProgressTick) >= FThrottleMs;
        if CanFire then FLastProgressTick := NowTick;
      end;
    end
    else
      CanFire := True;
  finally
    FProgressLock.Leave;
  end;
  if CanFire then
    FireCallback(FOnProgress, UseQueue);  // Artık gerçekten kullanılıyor (vars. True = Queue)
end;

{ ── Class Yardımcılar ────────────────────────────────────────────────────── }

class procedure TRadTask.InUI(AProc: TProc);
begin
  if TThread.CurrentThread.ThreadID = MainThreadID then
    AProc()
  else
    TThread.ForceQueue(nil, procedure begin AProc() end);
end;

class function TRadTask.MakeChainedFinally(const AOriginal: TRadTaskProc;
  ARemaining: PInteger; ADoneEvent: TEvent): TRadTaskProc;
begin
  Result := procedure(inner: TRadTask) begin
    if Assigned(AOriginal) then
      AOriginal(inner);
    if TInterlocked.Decrement(ARemaining^) = 0 then
      ADoneEvent.SetEvent;
  end;
end;

class function TRadTask.WhenAll(const ATasks: array of TRadTask): TRadTask;
var
  tasks: TArray<TRadTask>;
  i    : Integer;
begin
  SetLength(tasks, Length(ATasks));
  for i := 0 to High(ATasks) do
    tasks[i] := ATasks[i];

  Result := TRadTask.Create(procedure(t: TRadTask) begin
    if Length(tasks) = 0 then Exit;

    var remaining   : Integer := Length(tasks);
    var doneEvent   := TEvent.Create(nil, True, False, '');
    try
      for var idx := 0 to High(tasks) do
      begin
        var task := tasks[idx];
        // Görevin ÖNCEDEN tanımlanmış bir OnFinally'si varsa EZİLMEZ, zincirlenir.
        // MakeChainedFinally'nin parametre-tabanlı closure'ı kullanılır (bkz.
        // yukarıdaki tanım ve project_delphi_compiler_quirks.md).
        task.OnFinally(MakeChainedFinally(task.FOnFinally, @remaining, doneEvent)).Start;
      end;

      // Background'dan tüm görevlerin bitmesini olay tabanlı bekle (busy-wait yok)
      doneEvent.WaitFor(INFINITE);
    finally
      doneEvent.Free;
    end;
  end);
end;

{ ── Veri ─────────────────────────────────────────────────────────────────── }

function TRadTask.SetData(const AKey: string; const AValue: Variant): TRadTask;
begin
  FDataLock.Lock;
  try
    FData.AddOrUpdateValue(AKey, AValue);
  finally
    FDataLock.UnLock;
  end;
  Result := Self;
end;

function TRadTask.GetData(const AKey: string; const ADefault: Variant): Variant;
begin
  FDataLock.Lock;
  try
    Result := FData.GetValueOrDefault(AKey, ADefault);
  finally
    FDataLock.UnLock;
  end;
end;

function TRadTask.ElapsedMs: Int64;
begin
  if FStartTime = 0 then
    Exit(0);  // Görev henüz Start/Wait edilmedi
  if FEndTime > 0 then
    Result := MilliSecondsBetween(FEndTime, FStartTime)
  else
    Result := MilliSecondsBetween(Now, FStartTime);
end;

{ ── Thread-safe Getter'lar ───────────────────────────────────────────────── }

function TRadTask.GetProgress: Integer;
begin
  FProgressLock.Enter;
  try
    Result := FProgress;
  finally
    FProgressLock.Leave;
  end;
end;

function TRadTask.GetProgressMsg: string;
begin
  FProgressLock.Enter;
  try
    Result := FProgressMsg;
  finally
    FProgressLock.Leave;
  end;
end;

function TRadTask.GetErrorMsg: string;
begin
  FStatusLock.Lock;
  try
    Result := FErrorMsg;
  finally
    FStatusLock.UnLock;
  end;
end;

function TRadTask.GetSuccess: Boolean;
begin
  Result := TInterlocked.CompareExchange(FSuccessInt, 0, 0) = 1;
end;

function TRadTask.GetCancelled: Boolean;
begin
  Result := TInterlocked.CompareExchange(FCancelledInt, 0, 0) = 1;
end;

function TRadTask.GetRunning: Boolean;
begin
  Result := TInterlocked.CompareExchange(FRunningInt, 0, 0) = 1;
end;

function TRadTask.GetDone: Boolean;
begin
  Result := TInterlocked.CompareExchange(FDoneInt, 0, 0) = 1;
end;

function TRadTask.GetTimedOut: Boolean;
begin
  Result := TInterlocked.CompareExchange(FTimedOutInt, 0, 0) = 1;
end;

{ ── Fluent ───────────────────────────────────────────────────────────────── }

function TRadTask.SetPreDelay (AMs: Integer): TRadTask; begin FPreDelay    := AMs;     Result := Self end;
function TRadTask.SetPostDelay(AMs: Integer): TRadTask; begin FPostDelay   := AMs;     Result := Self end;
function TRadTask.SetThrottle (AMs: Cardinal): TRadTask; begin FThrottleMs := AMs;     Result := Self end;
function TRadTask.SetTag      (ATag: Integer): TRadTask; begin FTag        := ATag;    Result := Self end;

function TRadTask.SetCOM      (AModel: TCOMThreadModel): TRadTask; begin FCOMModel := AModel; Result := Self end;
function TRadTask.WithTimeout (AMs: Cardinal): TRadTask; begin FTimeout    := AMs;     Result := Self end;
function TRadTask.WithCancel  (const AToken: IRadCancelToken): TRadTask; begin FCancelToken := AToken; Result := Self end;

function TRadTask.SetRepeat(N, DelayMs: Integer): TRadTask;
begin
  FRepeatCount := N;
  FRepeatDelay := DelayMs;
  Result := Self;
end;

function TRadTask.SetRetry(N, DelayMs: Integer): TRadTask;
begin
  FRetryCount := N;
  FRetryDelay := DelayMs;
  Result := Self;
end;

function TRadTask.Retry(N, DelayMs: Integer): TRadTask; begin Result := SetRetry(N, DelayMs) end;

function TRadTask.SetName(const AName: string): TRadTask; begin FName := AName; Result := Self end;
function TRadTask.Named  (const AName: string): TRadTask; begin FName := AName; Result := Self end;


function TRadTask.Before    (A: TRadTaskProc): TRadTask; begin FBefore     := A; Result := Self end;
function TRadTask.After     (A: TRadTaskProc): TRadTask; begin FAfter      := A; Result := Self end;
function TRadTask.OnSuccess (A: TRadTaskProc): TRadTask; begin FOnSuccess  := A; Result := Self end;
function TRadTask.OnError   (A: TRadTaskProc): TRadTask; begin FOnError    := A; Result := Self end;
function TRadTask.OnProgress(A: TRadTaskProc): TRadTask; begin FOnProgress := A; Result := Self end;
function TRadTask.OnCancel  (A: TRadTaskProc): TRadTask; begin FOnCancel   := A; Result := Self end;
function TRadTask.OnFinally (A: TRadTaskProc): TRadTask; begin FOnFinally  := A; Result := Self end;
function TRadTask.OnTimeout (A: TRadTaskProc): TRadTask; begin FOnTimeout  := A; Result := Self end;

function TRadTask.ThenBy(A: TRadTaskProc): TRadTask;
begin
  FThenList.Add(A);
  Result := Self;
end;

{ ── Factory ──────────────────────────────────────────────────────────────── }

function NewCancellationSource: IRadCancellationSource;
begin
  Result := TRadCancellationImpl.Create;
end;

end.
