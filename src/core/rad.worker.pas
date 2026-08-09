unit rad.worker;

{
  TRadWorkers — Havuz tabanlı, yüksek-hacim, zamanlanmış iş (job) motoru
  (mORMot2 entegrasyonlu). Bkz. docs\rad.worker-plan.md (Faz 1 onaylı tasarım).

  Neden mORMot2 (OmniThreadLibrary değil): Çekirdek zaten mORMot2 tip
  evreninde (RawUtf8, IDocDict, TSynLog, TLightLock — bkz. rad.thread.pas).
  OTL projede hiç tüketilmiyor; yeni bağımlılık zinciri açmadan mevcut
  vendor'ı derinleştirmek tercih edildi (vendor-first).

  Motor eşlemesi (plan doküman madde 2.2/2.3):
    Post/Delay/Every/Plan/LongJob → TLoggedWorker.Run(..., ForcedThread=True)
      KRİTİK: ForcedThread=True zorunlu. TLoggedWorker.Run'ın varsayılanı
      (ForcedThread=False) havuz doluyken OnTask'ı ÇAĞIRAN THREAD'DE (ana UI
      thread'i olabilir!) senkron çalıştırır (mormot.core.threads.pas'taki
      TLoggedWorker.Run yorumu: "would just block and execute OnTask(Sender)
      in the current (main) thread"). Fire-and-forget bir Post() için bu kabul
      edilemez — havuz doluyken bile ForcedThread=True ile iş dahili kuyruğa
      alınır, çağıran thread asla bloklanmaz/kullanılmaz. Bu davranış test
      programında bizzat doğrulandı (TestPostDoesNotBlock).
    Zamanlayıcı (Delay/Every/Plan) → tek bir TSynBackgroundThreadProcess
      (50ms tick). NOT TSynBackgroundTimer — o sınıfın Enable/EnQueue'su
      sadece SANİYE hassasiyetinde; TSynBackgroundThreadProcess ilkel/temel
      sınıf olduğu için ms hassasiyetinde Delay/Every'ye izin veriyor. Tick
      thread'i işin GÖVDESİNİ asla çalıştırmaz — sadece "süresi geldi mi"
      kontrolü yapıp DispatchJob ile havuza dispatch eder; böylece yavaş bir
      iş zamanlayıcıyı asla bloklayamaz.
    ForEach → TSynParallelProcess.ParallelRunAndWait; mORMot'un
      TOnSynParallelProcess(IndexStart,IndexStop) imzası thread-başına bir
      [start..stop] aralığı verir (per-index değil) — rad.worker bunu
      ABody: TProc<Integer> (tek-index) API'sine adapte eder (plan dokümanı
      TProc<Integer,Integer> öneriyordu, ama Delphi çağıran için asıl
      ergonomik olan tek-index callback'tir — ADAPTÖR üzerinden
      IndexStart..IndexStop aralığında ABody(i) döngüsü kurulur).
    WaitJob → TBlockingProcessPool (NewProcess/FromCall/NotifyFinished);
      AMsgWait=True ise rad.thread.pas'ın TRadTask.Wait metodundaki (satır
      526-530) VCL mesaj-pompası deseni BİREBİR kopyalanır (Application.
      ProcessMessages + CheckSynchronize döngüsü), tutarlılık için.

  Payload: IDocDict (TDocVariantData DEĞİL — plan dokümanı madde 2.1/5.1).
  Post() payload'ı OTOMATİK KOPYALAMAZ (.Copy çağırmaz) — çağıranın Post'tan
  sonra aynı IDocDict'i mutasyona uğratması job'un GÖRDÜĞÜ veriyi de
  değiştirir (IDocDict referans sayılı bir interface, TJob.Data alanı aynı
  nesneyi paylaşır). Bilinçli tercih: varsayılan davranış "sıfır kopya, sıfır
  sürpriz maliyet" — kopya isteyen çağıran DocDict.Copy'yi kendisi çağırıp
  Post'a onu verir. Bu davranış test programında (TestIDocDictMutasyonu)
  gözlemlenmiş/doğrulanmıştır.

  COM apartment (Faz 1, plan madde 2.6): ComInitPerWorker=True ise her worker
  thread'i iş almadan önce CoInitializeEx(APARTMENTTHREADED), iş bitince
  CoUninitialize çağırır (TLoggedWorker.OnBeforeEachTask/OnAfterEachTask
  hook'ları üstünden). rad.thread.pas'taki TRadTask.InitCOM/UninitCOM ile
  aynı Winapi.ActiveX kullanım deseni izlendi.

  TASARIMDAN SAPMA (plan dokümanına göre, gerçek mORMot2 kaynağı okunduktan
  sonra düzeltildi):
  1. ForEach imzası TProc<Integer,Integer> (aralık) değil TProc<Integer>
     (tek-index) — plan dokümanının kendi notu zaten bunu QWorker-benzeri
     ergonomi için öneriyordu, burada uygulandı.
  2. TLoggedWorker.MaxRunning SALT-OKUNUR bir property (yalnızca `read
     fMaxRunning`, yazma erişimi/setter'ı yok) — mormot.core.threads.pas'ta
     doğrulandı. Bu yüzden MaxWorkers.Write, motoru runtime'da BÜYÜTEMEZ;
     bunun yerine yeni bir TLoggedWorker örneği ile mevcut motoru DEĞİŞTİRİR
     (eskisi Terminate(true) ile bekleyip serbest bırakılır, hook'lar yeni
     örneğe yeniden bağlanır). Bu, halen çalışan işleri etkilemez (onlar
     zaten kendi TLoggedWorkThread'lerinde ilerliyor) ama MaxWorkers'ı sık
     sık değiştirmek ucuz bir işlem DEĞİLDİR — test/deterministik kurulum
     senaryosu için yeterli, üretimde runtime'da sık resize beklenmiyor.
  2b. MinWorkers Faz 1'de yalnızca bilgi amaçlı bir alan olarak tutuluyor;
     TLoggedWorker taban/alt sınır kavramı sunmuyor (ihtiyaç kadar thread
     yaratıp bırakıyor) — bu yüzden MinWorkers'ın havuz davranışına doğrudan
     bir etkisi yok, sadece "hedef" olarak saklanıp okunuyor.

  Faz 2'ye ERTELENEN (bu dosyada YOK): Signal/pub-sub (rad.eventbus'a delege
  edilecek), TRadWorkerGroup/WaitGroup, frozen-job watchdog, genel per-worker
  extension nesnesi (COM apartment'ın DIŞINDA), dinamik havuz auto-resize.

  Job durumu (Faz 1'e sonradan eklendi, kullanıcı talebiyle): GetJobStatus(Id)
  ile sorgulanan TRadWorkerJobStatus (jsUnknown/jsPending/jsRunning/jsDone/
  jsCancelled/jsFailed), FStatusMap (TDictionary<Id, Status>, FLock ile
  korunur) üzerinden tutulur. Tek-atış işlerde (Post/Delay/LongJob) jsDone/
  jsFailed TERMİNAL'dir; tekrarlayan işlerde (Every/Plan/wjRepeat) her koşu
  sonunda jsPending'e döner (bir sonraki tetikleme bekleniyor anlamında).
  BİLİNÇLİ SINIRLAMA: FStatusMap'te Faz 1'de retention/temizleme politikası
  YOK — yüksek hacimli tek-seferlik Post() üretiminde girişler Clear()
  çağrılana kadar bellekte kalır (bkz. plan dok. İstatistik/introspection,
  Faz 2'de ele alınabilir).
}

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections,
  System.DateUtils,
  Winapi.Windows, Winapi.Messages, Winapi.ActiveX,
  Vcl.Forms,
  mormot.core.base,
  mormot.core.os,
  mormot.core.variants,
  mormot.core.log,
  mormot.core.threads,
  rad.date;

type
  TRadWorkerJobId = type Int64;

  TRadWorkerProc     = reference to procedure;
  TRadWorkerDataProc = reference to procedure(const AData: IDocDict);

  TRadWorkerJobFlag  = (wjRunOnce, wjMainThread, wjLongRunning,
                        wjByPlan, wjRepeat, wjTerminated);
  TRadWorkerJobFlags = set of TRadWorkerJobFlag;

  /// bir job'un yaşam döngüsü durumu (bkz. dosya başlığı "Job durumu").
  /// jsUnknown: GetJobStatus'a bilinmeyen/hiç var olmamış bir Id verildiğinde.
  /// jsPending: oluşturuldu ama henüz çalışmadı (veya tekrarlayan bir iş,
  ///   bir sonraki tetiklemeyi bekliyor).
  /// jsRunning: şu an ExecuteJobBody içinde çalışıyor.
  /// jsDone/jsFailed: tek-atış bir işin TERMİNAL durumu (Failed: gövde
  ///   exception fırlattı, hata TSynLog'a yazıldı).
  /// jsCancelled: Cancel() ile FPending'den düşürüldü (yalnızca henüz
  ///   dispatch edilmemiş Delay/Every/Plan işleri için mümkündür).
  TRadWorkerJobStatus = (jsUnknown, jsPending, jsRunning, jsDone,
                         jsCancelled, jsFailed);

  /// tek bir zamanlanmış/kuyruklanmış iş kaydı
  /// record (class değil): TDtElapsed/TDtInterval hattıyla tutarlı, yüksek
  /// hacimli kısa işlerde heap/GC baskısı yaratmaz (bkz. plan madde 2.1).
  TJob = record
    Id         : TRadWorkerJobId;
    Name       : RawUtf8;
    Proc       : TRadWorkerProc;
    DataProc   : TRadWorkerDataProc;
    Data       : IDocDict;
    Flags      : TRadWorkerJobFlags;
    PushTixMs, StartTixMs, DoneTixMs : Int64;
    IntervalMs : Int64;   // wjRepeat: tekrar aralığı, 0 = tek atış
    DelayMs    : Int64;   // ilk tetiklemeden önceki gecikme
    NextDueMs  : Int64;   // GetTickCount64 tabanlı, bir sonraki tetik anı
    Schedule   : TDtSchedule; // wjByPlan ise dolu
    Runs       : Integer;
    MinUsedMs, MaxUsedMs, TotalUsedMs : Int64;
  end;
  PJob = ^TJob;

  { TRadWorkers }

  /// havuz tabanlı, tekil (singleton, global `Workers` değişkeni) worker
  /// yöneticisi. Faz 1 kapsamı: Post/Delay/Every/Plan/LongJob/ForEach/
  /// Cancel/Clear/WaitJob/Disable/Enable + Min/Max/Busy/IdleWorkers +
  /// ComInitPerWorker. Signal/JobGroup/watchdog/genel per-worker extension
  /// Faz 2'dedir (bkz. bu dosyanın başlık yorumu).
  TRadWorkers = class
  strict private
    FEngine        : TLoggedWorker;             // yürütme motoru (havuz)
    FEngineLock    : TLightLock;                 // SADECE FEngine değişimini korur
                                                  // (FLock'tan AYRI: SchedulerTick FLock
                                                  // tutarken DispatchJob->FEngine okur,
                                                  // aynı kilidi kullansaydı TLightLock
                                                  // non-reentrant olduğu için kilitlenirdi
                                                  // — GERÇEK BULGU, test programında
                                                  // standalone çalıştırırken hang olarak
                                                  // yakalandı, bkz. rapor)
    FScheduler     : TSynBackgroundThreadProcess; // Delay/Every/Plan tick'i
    FWaitPool      : TBlockingProcessPool;       // WaitJob köprüsü
    FLock          : TLightLock;                 // FPending/FWaitMap korur
    FPending       : TList<PJob>;                // zamanlayıcının izlediği job'lar (Delay/Every/Plan)
    FWaitMap       : TDictionary<TRadWorkerJobId, TBlockingProcessPoolCall>; // WaitJob eşlemesi
    FStatusMap     : TDictionary<TRadWorkerJobId, TRadWorkerJobStatus>; // GetJobStatus eşlemesi (FLock korur)
    FNextId        : Int64;                      // atomic job-id üreteci
    FEnabled       : Boolean;
    FComInitPerWorker: Boolean;
    FMinWorkersValue : Integer; // bkz. dosya başlığı madde 2b — bilgi amaçlı

    procedure SchedulerTick(Sender: TSynBackgroundThreadProcess);
    function  NewId: TRadWorkerJobId;
    procedure DispatchJob(AJob: PJob);
    procedure ExecuteJobBody(AJob: PJob);
    procedure SetStatus(AId: TRadWorkerJobId; AStatus: TRadWorkerJobStatus);
    procedure OnBeforeTask(Sender: TObject);
    procedure OnAfterTask(Sender: TObject);
    function  GetMinWorkers: Integer;
    procedure SetMinWorkers(AValue: Integer);
    function  GetMaxWorkers: Integer;
    procedure SetMaxWorkers(AValue: Integer);
    function  GetBusyWorkers: Integer;
    function  GetIdleWorkers: Integer;
    function  FindPending(AId: TRadWorkerJobId): Integer;
  public
    constructor Create(AMinWorkers: Integer = 0; AMaxWorkers: Integer = 0);
    destructor Destroy; override;

    function Post(const AProc: TRadWorkerProc): TRadWorkerJobId; overload;
    function Post(const AProc: TRadWorkerDataProc; const AData: IDocDict): TRadWorkerJobId; overload;
    function PostMainThread(const AProc: TRadWorkerProc): TRadWorkerJobId;

    function Delay(const AProc: TRadWorkerProc; ADelayMs: Int64): TRadWorkerJobId;
    function Every(const AProc: TRadWorkerProc; AIntervalMs: Int64; AFirstDelayMs: Int64 = 0): TRadWorkerJobId;

    function Plan(const AProc: TRadWorkerProc; const AMask: string): TRadWorkerJobId; overload;
    function Plan(const AProc: TRadWorkerProc; const ASchedule: TDtSchedule): TRadWorkerJobId; overload;

    function LongJob(const AProc: TRadWorkerProc): TRadWorkerJobId;

    /// ALow..AHigh (dahil) aralığını paralel işler; ABody her indeks için BİR
    /// KEZ çağrılır (mORMot'un ham TOnSynParallelProcess'i thread-başına bir
    /// [IndexStart..IndexStop] aralığı verir — burada adapte edilip
    /// döngüleniyor, bkz. dosya başlığı).
    procedure ForEach(ALow, AHigh: Integer; const ABody: TProc<Integer>; AMsgWait: Boolean = False);

    function  Cancel(AId: TRadWorkerJobId): Boolean;
    procedure Clear;
    function  WaitJob(AId: TRadWorkerJobId; ATimeoutMs: Integer; AMsgWait: Boolean = False): Boolean;

    /// Id'nin şu anki yaşam döngüsü durumunu döndürür (bkz. dosya başlığı
    /// "Job durumu" ve TRadWorkerJobStatus). Bilinmeyen bir Id -> jsUnknown.
    function GetJobStatus(AId: TRadWorkerJobId): TRadWorkerJobStatus;

    procedure Disable;
    procedure Enable;

    property MinWorkers : Integer read GetMinWorkers write SetMinWorkers;
    property MaxWorkers : Integer read GetMaxWorkers write SetMaxWorkers;
    property BusyWorkers: Integer read GetBusyWorkers;
    property IdleWorkers: Integer read GetIdleWorkers;
    /// True ise her worker thread'i iş almadan CoInitializeEx(APARTMENTTHREADED),
    /// iş bitince CoUninitialize çağırır (UniDAC/ADO gibi COM tabanlı
    /// sürücüler worker içinde kullanılacaksa gerekir). Varsayılan False.
    property ComInitPerWorker: Boolean read FComInitPerWorker write FComInitPerWorker;
  end;

var
  Workers: TRadWorkers;

implementation

const
  DefaultMinWorkers = 2;
  DefaultMaxWorkers = 8;
  SchedulerTickMs   = 50;

type
  /// TNotifyEvent (procedure-of-object), mORMot'un TLoggedWorker.Run ve
  /// TThread.ForceQueue gibi API'lerinin beklediği "method pointer" tipidir
  /// — anonim yordam (closure/reference to procedure) doğrudan atanamaz.
  /// Bu köprü sınıfı, bir closure'ı yakalayıp TNotifyEvent uyumlu bir
  /// nesne metoduna dönüştürür; tek kullanımlık olduğu için işi bitince
  /// kendini serbest bırakır (Free çağrısı iş bitiminde ExecuteJobBody/
  /// DispatchJob tarafında değil, doğrudan bu sınıfın kendi metodunda).
  TRadWorkerClosureRunner = class
  private
    FProc: TProc;
  public
    constructor Create(const AProc: TProc);
    procedure Run(Sender: TObject);
  end;

constructor TRadWorkerClosureRunner.Create(const AProc: TProc);
begin
  inherited Create;
  FProc := AProc;
end;

procedure TRadWorkerClosureRunner.Run(Sender: TObject);
begin
  try
    FProc();
  finally
    Free;
  end;
end;

type
  /// TOnSynParallelProcess (procedure(IndexStart,IndexStop:integer) of object)
  /// bir method-pointer olduğu için ForEach'in ABody: TProc<Integer> (tek-
  /// index) closure'ını doğrudan ParallelRunAndWait'e veremeyiz — bu köprü
  /// sınıfı ALow ofsetini ve ABody closure'ını yakalayıp gerçek bir nesne
  /// metoduna dönüştürür (bkz. dosya başlığındaki ForEach adaptör notu).
  TRadWorkerForEachRunner = class
  private
    FLow: Integer;
    FBody: TProc<Integer>;
  public
    constructor Create(ALow: Integer; const ABody: TProc<Integer>);
    procedure Run(IndexStart, IndexStop: Integer);
  end;

constructor TRadWorkerForEachRunner.Create(ALow: Integer; const ABody: TProc<Integer>);
begin
  inherited Create;
  FLow := ALow;
  FBody := ABody;
end;

procedure TRadWorkerForEachRunner.Run(IndexStart, IndexStop: Integer);
var
  I: Integer;
begin
  for I := IndexStart to IndexStop do
    FBody(FLow + I);
end;

{ TRadWorkers }

constructor TRadWorkers.Create(AMinWorkers, AMaxWorkers: Integer);
begin
  inherited Create;
  if AMaxWorkers <= 0 then AMaxWorkers := DefaultMaxWorkers;
  if AMinWorkers <= 0 then AMinWorkers := DefaultMinWorkers;
  FEnabled := True;
  FNextId  := 0;
  FMinWorkersValue := AMinWorkers;
  FPending := TList<PJob>.Create;
  FWaitMap := TDictionary<TRadWorkerJobId, TBlockingProcessPoolCall>.Create;
  FStatusMap := TDictionary<TRadWorkerJobId, TRadWorkerJobStatus>.Create;
  FWaitPool := TBlockingProcessPool.Create;
  FEngine  := TLoggedWorker.Create(TSynLog, AMaxWorkers);
  FEngine.OnBeforeEachTask := OnBeforeTask;
  FEngine.OnAfterEachTask  := OnAfterTask;
  FScheduler := TSynBackgroundThreadProcess.Create('RadWorkerScheduler',
    SchedulerTick, SchedulerTickMs);
end;

destructor TRadWorkers.Destroy;
var
  I: Integer;
begin
  FScheduler.Free; // ExecuteLoop'u durdurup thread'i bekleyerek kapatır
  FEngine.Free;    // Terminate(true) ile bekleyen işleri sonlandırır
  FWaitPool.Free;
  for I := 0 to FPending.Count - 1 do
    Dispose(FPending[I]);
  FPending.Free;
  FWaitMap.Free;
  FStatusMap.Free;
  inherited;
end;

function TRadWorkers.NewId: TRadWorkerJobId;
begin
  Result := TInterlocked.Increment(FNextId);
end;

procedure TRadWorkers.SetStatus(AId: TRadWorkerJobId; AStatus: TRadWorkerJobStatus);
begin
  FLock.Lock;
  try
    FStatusMap.AddOrSetValue(AId, AStatus);
  finally
    FLock.UnLock;
  end;
end;

function TRadWorkers.GetJobStatus(AId: TRadWorkerJobId): TRadWorkerJobStatus;
begin
  FLock.Lock;
  try
    if not FStatusMap.TryGetValue(AId, Result) then
      Result := jsUnknown;
  finally
    FLock.UnLock;
  end;
end;

function TRadWorkers.FindPending(AId: TRadWorkerJobId): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FPending.Count - 1 do
    if FPending[I]^.Id = AId then
      Exit(I);
end;

procedure TRadWorkers.OnBeforeTask(Sender: TObject);
begin
  if FComInitPerWorker then
    CoInitializeEx(nil, COINIT_APARTMENTTHREADED);
end;

procedure TRadWorkers.OnAfterTask(Sender: TObject);
begin
  if FComInitPerWorker then
    CoUninitialize;
end;

procedure TRadWorkers.ExecuteJobBody(AJob: PJob);
var
  LStart, LUsed: Int64;
  LCall: TBlockingProcessPoolCall;
  LHasWait: Boolean;
  LItem: TBlockingProcessPoolItem;
  LFailed: Boolean;
begin
  LStart := GetTickCount64;
  AJob^.StartTixMs := LStart;
  SetStatus(AJob^.Id, jsRunning);
  LFailed := False;
  try
    try
      if Assigned(AJob^.DataProc) then
        AJob^.DataProc(AJob^.Data)
      else if Assigned(AJob^.Proc) then
        AJob^.Proc();
    except
      on E: Exception do
      begin
        LFailed := True;
        TSynLog.Add.Log(sllError, 'RadWorker Job [%] Failed: %', [AJob^.Name, E.Message]);
      end;
    end;
  finally
    AJob^.DoneTixMs := GetTickCount64;
    LUsed := AJob^.DoneTixMs - LStart;
    Inc(AJob^.Runs);
    if (AJob^.MinUsedMs = 0) or (LUsed < AJob^.MinUsedMs) then AJob^.MinUsedMs := LUsed;
    if LUsed > AJob^.MaxUsedMs then AJob^.MaxUsedMs := LUsed;
    Inc(AJob^.TotalUsedMs, LUsed);

    // tekrarlayan işler (Every/Plan) Done/Failed'de KALMAZ — bir sonraki
    // tetiklemeyi bekleyen jsPending'e döner; tek-atış işlerde bu TERMİNAL.
    if LFailed then
      SetStatus(AJob^.Id, jsFailed)
    else if ([wjRepeat, wjByPlan] * AJob^.Flags) <> [] then
      SetStatus(AJob^.Id, jsPending)
    else
      SetStatus(AJob^.Id, jsDone);

    FLock.Lock;
    try
      LHasWait := FWaitMap.TryGetValue(AJob^.Id, LCall);
      if LHasWait then
        FWaitMap.Remove(AJob^.Id);
    finally
      FLock.UnLock;
    end;
    if LHasWait then
    begin
      LItem := FWaitPool.FromCall(LCall);
      if Assigned(LItem) then
        LItem.NotifyFinished;
    end;
  end;
end;

procedure TRadWorkers.DispatchJob(AJob: PJob);
var
  LJobCopy: TJob;
  LRunner: TRadWorkerClosureRunner;
  LEngine: TLoggedWorker;
begin
  if not FEnabled then Exit;
  LJobCopy := AJob^; // değer kopyası: closure'a job verisinin kendi kopyası taşınır
  LRunner := TRadWorkerClosureRunner.Create(
    procedure
    var
      LLocal: TJob;
    begin
      LLocal := LJobCopy;
      ExecuteJobBody(@LLocal);
    end);
  FEngineLock.Lock;
  try
    LEngine := FEngine; // SetMaxWorkers ile eşzamanlı motor değişimine karşı
  finally
    FEngineLock.UnLock;
  end;
  LEngine.Run(LRunner.Run, nil, AJob^.Name, {ForcedThread=}True);
end;

procedure TRadWorkers.SchedulerTick(Sender: TSynBackgroundThreadProcess);
var
  LNow: Int64;
  LNowDt: TDateTime;
  LNowSec: Int64;
  I: Integer;
  LJob: PJob;
  LToRemove: TList<PJob>;
begin
  if not FEnabled then Exit;
  LNow := GetTickCount64;
  LNowDt := System.SysUtils.Now;
  LToRemove := TList<PJob>.Create;
  try
    FLock.Lock;
    try
      for I := 0 to FPending.Count - 1 do
      begin
        LJob := FPending[I];
        if wjTerminated in LJob^.Flags then
        begin
          LToRemove.Add(LJob);
          Continue;
        end;
        if wjByPlan in LJob^.Flags then
        begin
          // NextDueMs, Plan işlerinde "son tetiklenen takvim saniyesi"
          // (SecondsSince1970 benzeri, DateTimeToUnix ile tam saniyeye
          // yuvarlanmış epoch damgası) olarak YENİDEN KULLANILIYOR
          // (Delay/Every'deki "bir sonraki tetik anı" anlamından farklı) —
          // 50ms'lik tick periyodu bir takvim saniyesini birden fazla kez
          // örnekleyebiliyor (Accept() saniye çözünürlüklü olduğu için aynı
          // saniye içinde defalarca True dönebilir); bu dedup alanı olmadan
          // tek bir "* * * * * *" maskesi saniyede ~20 kez ateşlenirdi
          // (GERÇEK BULGU: standalone test programında ilk halde 3.2sn'de
          // 63 kez ateşlendiği gözlemlendi — bu düzeltmeyle beklenen ~3
          // kereye indi).
          LNowSec := DateTimeToUnix(LNowDt);
          if (LNowSec <> LJob^.NextDueMs) and LJob^.Schedule.Accept(LNowDt) then
          begin
            LJob^.NextDueMs := LNowSec;
            DispatchJob(LJob);
            Inc(LJob^.Runs); // Plan işlerinde de gözlemlenebilir sayaç
          end;
        end
        else if LNow >= LJob^.NextDueMs then
        begin
          DispatchJob(LJob);
          if wjRepeat in LJob^.Flags then
            LJob^.NextDueMs := LNow + LJob^.IntervalMs
          else
            LToRemove.Add(LJob); // tek atış (Delay): dispatch sonrası düş
        end;
      end;
      for I := 0 to LToRemove.Count - 1 do
      begin
        FPending.Remove(LToRemove[I]);
        Dispose(LToRemove[I]);
      end;
    finally
      FLock.UnLock;
    end;
  finally
    LToRemove.Free;
  end;
end;

function TRadWorkers.Post(const AProc: TRadWorkerProc): TRadWorkerJobId;
var
  LJob: TJob;
begin
  FillChar(LJob, SizeOf(LJob), 0);
  LJob.Id := NewId;
  LJob.Name := RawUtf8(Format('Post_%d', [LJob.Id]));
  LJob.Proc := AProc;
  LJob.Flags := [wjRunOnce];
  LJob.PushTixMs := GetTickCount64;
  Result := LJob.Id;
  SetStatus(Result, jsPending);
  if not FEnabled then Exit;
  DispatchJob(@LJob);
end;

function TRadWorkers.Post(const AProc: TRadWorkerDataProc; const AData: IDocDict): TRadWorkerJobId;
var
  LJob: TJob;
begin
  FillChar(LJob, SizeOf(LJob), 0);
  LJob.Id := NewId;
  LJob.Name := RawUtf8(Format('PostData_%d', [LJob.Id]));
  LJob.DataProc := AProc;
  LJob.Data := AData; // BİLİNÇLİ: kopyalanmıyor — çağıran isterse .Copy versin
  LJob.Flags := [wjRunOnce];
  LJob.PushTixMs := GetTickCount64;
  Result := LJob.Id;
  SetStatus(Result, jsPending);
  if not FEnabled then Exit;
  DispatchJob(@LJob);
end;

function TRadWorkers.PostMainThread(const AProc: TRadWorkerProc): TRadWorkerJobId;
var
  LId: TRadWorkerJobId;
begin
  Result := NewId;
  LId := Result;
  SetStatus(LId, jsPending);
  if not FEnabled then Exit;
  TThread.ForceQueue(nil,
    procedure
    begin
      SetStatus(LId, jsRunning);
      try
        AProc();
        SetStatus(LId, jsDone);
      except
        on E: Exception do
        begin
          SetStatus(LId, jsFailed);
          TSynLog.Add.Log(sllError, 'RadWorker PostMainThread [%] Failed: %', [LId, E.Message]);
        end;
      end;
    end);
end;

function TRadWorkers.Delay(const AProc: TRadWorkerProc; ADelayMs: Int64): TRadWorkerJobId;
var
  LJob: PJob;
begin
  New(LJob);
  FillChar(LJob^, SizeOf(LJob^), 0);
  LJob^.Id := NewId;
  LJob^.Name := RawUtf8(Format('Delay_%d', [LJob^.Id]));
  LJob^.Proc := AProc;
  LJob^.DelayMs := ADelayMs;
  LJob^.NextDueMs := GetTickCount64 + ADelayMs;
  LJob^.Flags := [wjRunOnce];
  LJob^.PushTixMs := GetTickCount64;
  Result := LJob^.Id;
  SetStatus(Result, jsPending); // FLock'un DIŞINDA — FLock non-reentrant, nested lock hang riski
  FLock.Lock;
  try
    FPending.Add(LJob);
  finally
    FLock.UnLock;
  end;
end;

function TRadWorkers.Every(const AProc: TRadWorkerProc; AIntervalMs: Int64; AFirstDelayMs: Int64): TRadWorkerJobId;
var
  LJob: PJob;
begin
  New(LJob);
  FillChar(LJob^, SizeOf(LJob^), 0);
  LJob^.Id := NewId;
  LJob^.Name := RawUtf8(Format('Every_%d', [LJob^.Id]));
  LJob^.Proc := AProc;
  LJob^.IntervalMs := AIntervalMs;
  LJob^.DelayMs := AFirstDelayMs;
  LJob^.NextDueMs := GetTickCount64 + AFirstDelayMs;
  LJob^.Flags := [wjRepeat];
  LJob^.PushTixMs := GetTickCount64;
  Result := LJob^.Id;
  SetStatus(Result, jsPending);
  FLock.Lock;
  try
    FPending.Add(LJob);
  finally
    FLock.UnLock;
  end;
end;

function TRadWorkers.Plan(const AProc: TRadWorkerProc; const AMask: string): TRadWorkerJobId;
begin
  Result := Plan(AProc, TDtSchedule.Create(AMask));
end;

function TRadWorkers.Plan(const AProc: TRadWorkerProc; const ASchedule: TDtSchedule): TRadWorkerJobId;
var
  LJob: PJob;
begin
  New(LJob);
  FillChar(LJob^, SizeOf(LJob^), 0);
  LJob^.Id := NewId;
  LJob^.Name := RawUtf8(Format('Plan_%d', [LJob^.Id]));
  LJob^.Proc := AProc;
  LJob^.Schedule := ASchedule; // by-value kopya: TDtSchedule.SetAsString her
                               // seferinde FLimits'i baştan kurar, partial-
                               // mutation riski yok (plan madde 5.6 doğrulandı)
  LJob^.Flags := [wjByPlan];
  LJob^.PushTixMs := GetTickCount64;
  Result := LJob^.Id;
  SetStatus(Result, jsPending);
  FLock.Lock;
  try
    FPending.Add(LJob);
  finally
    FLock.UnLock;
  end;
end;

function TRadWorkers.LongJob(const AProc: TRadWorkerProc): TRadWorkerJobId;
var
  LJob: TJob;
begin
  FillChar(LJob, SizeOf(LJob), 0);
  LJob.Id := NewId;
  LJob.Name := RawUtf8(Format('LongJob_%d', [LJob.Id]));
  LJob.Proc := AProc;
  LJob.Flags := [wjLongRunning];
  LJob.PushTixMs := GetTickCount64;
  Result := LJob.Id;
  SetStatus(Result, jsPending);
  if not FEnabled then Exit;
  DispatchJob(@LJob);
end;

procedure TRadWorkers.ForEach(ALow, AHigh: Integer; const ABody: TProc<Integer>; AMsgWait: Boolean);
var
  LParallel: TSynParallelProcess;
  LCount: Integer;
  LForEachRunner: TRadWorkerForEachRunner;
  LBgThread: TThread;
  LBgError: string;
begin
  if ALow > AHigh then Exit;
  LCount := AHigh - ALow + 1;
  if not Assigned(ABody) then Exit;

  // GERÇEK BULGU (standalone test programında ve izole mORMot2 repro'sunda
  // doğrulandı — bkz. rapor): TSynParallelProcess.ParallelRunAndWait'e
  // OnMainThreadIdle (TNotifyEvent) PARAMETRESİ VERİLDİĞİNDE, "son/kuyruk"
  // parça (fPool[use-1]'e Start ile atanan, inc(use) sonrası artık son kez
  // beklenen parça) OLUŞTURULUYOR ama HİÇBİR ZAMAN ÇALIŞTIRILMIYOR — mORMot2
  // kaynağında (mormot.core.threads.pas ParallelRunAndWait) izole edilmiş,
  // vendor kütüphanesine ait bir bulgu (rad.worker.pas'ın kendi mantığında
  // DEĞİL). 1000 elemanlı bir ForEach'te 39 indeksin hiç çağrılmadığı, 20
  // elemanlı izole bir repro'da son [15..19] parçasının hiç loglanmadığı
  // gözlemlendi. Bu yüzden AMsgWait=True olsa BİLE ParallelRunAndWait'e
  // OnMainThreadIdle ASLA verilmiyor (nil geçiliyor, tam/doğru paralellik
  // korunuyor); bunun yerine tüm ParallelRunAndWait çağrısı ayrı bir arka
  // plan thread'inde çalıştırılıp, çağıran thread (muhtemelen UI/main)
  // rad.thread.pas'taki TRadTask.Wait deseniyle (satır 526-530) mesaj
  // pompalayarak bekliyor — UI donmuyor, vendor bug'ı da tetiklenmiyor.
  LForEachRunner := TRadWorkerForEachRunner.Create(ALow, ABody);
  try
    if not AMsgWait then
    begin
      LParallel := TSynParallelProcess.Create(CpuThreads, 'RadWorkerForEach');
      try
        LParallel.ParallelRunAndWait(LForEachRunner.Run, LCount, nil);
      finally
        LParallel.Free;
      end;
    end
    else
    begin
      LBgError := '';
      LBgThread := TThread.CreateAnonymousThread(
        procedure
        var
          LInnerParallel: TSynParallelProcess;
        begin
          LInnerParallel := TSynParallelProcess.Create(CpuThreads, 'RadWorkerForEach');
          try
            try
              LInnerParallel.ParallelRunAndWait(LForEachRunner.Run, LCount, nil);
            except
              on E: Exception do
                LBgError := E.ClassName + ': ' + E.Message;
            end;
          finally
            LInnerParallel.Free;
          end;
        end);
      LBgThread.FreeOnTerminate := False;
      LBgThread.Start;
      while not LBgThread.Finished do
      begin
        Application.ProcessMessages;
        CheckSynchronize(5);
      end;
      LBgThread.Free;
      if LBgError <> '' then
        raise Exception.Create(LBgError);
    end;
  finally
    LForEachRunner.Free;
  end;
end;

function TRadWorkers.Cancel(AId: TRadWorkerJobId): Boolean;
var
  LIdx: Integer;
begin
  FLock.Lock;
  try
    LIdx := FindPending(AId);
    Result := LIdx >= 0;
    if Result then
      FPending[LIdx]^.Flags := FPending[LIdx]^.Flags + [wjTerminated];
  finally
    FLock.UnLock;
  end;
  if Result then
    SetStatus(AId, jsCancelled); // FLock'un DIŞINDA — nested lock hang riski yok
end;

procedure TRadWorkers.Clear;
var
  I: Integer;
begin
  FLock.Lock;
  try
    for I := 0 to FPending.Count - 1 do
      Dispose(FPending[I]);
    FPending.Clear;
    FWaitMap.Clear;
    FStatusMap.Clear; // doğrudan (SetStatus üzerinden değil) — zaten FLock altındayız
  finally
    FLock.UnLock;
  end;
end;

function TRadWorkers.WaitJob(AId: TRadWorkerJobId; ATimeoutMs: Integer; AMsgWait: Boolean): Boolean;
var
  LItem: TBlockingProcessPoolItem;
  LEvent: TBlockingEvent;
  LBgThread: TThread;
begin
  LItem := FWaitPool.NewProcess(ATimeoutMs);
  if not Assigned(LItem) then Exit(False);
  FLock.Lock;
  try
    FWaitMap.AddOrSetValue(AId, LItem.Call);
  finally
    FLock.UnLock;
  end;

  if not AMsgWait then
    LEvent := LItem.WaitFor(ATimeoutMs)
  else
  begin
    // GERÇEK BULGU: TBlockingProcess.WaitFor(TimeOutMS), zaman aşımına
    // uğradığında dahili fEvent alanını KALICI OLARAK evTimeOut'a çeker
    // (mormot.core.threads.pas TBlockingProcess.WaitFor: "if fEvent in
    // [evRaised, evTimeOut] then exit" — bu kontrol YENİ bir WaitFor
    // çağrısının BAŞINDA yapılıyor). Yani rad.thread.pas'taki TRadTask.Wait
    // deseninde olduğu gibi kısa aralıklarla (WaitFor(5)) TEKRAR TEKRAR
    // çağırmak burada YANLIŞ sonuç verir: ilk 5ms'lik dilim zaman aşımına
    // uğrar uğramaz fEvent evTimeOut'a kilitlenir ve sonraki TÜM WaitFor
    // çağrıları -- iş gerçekten daha sonra NotifyFinished çağırsa bile --
    // anında (ve yanlış şekilde) evTimeOut döner. Standalone test programında
    // bu yüzden WaitJob(AMsgWait=True) her zaman False dönüyordu (gerçek
    // gözlemlenen bug). Çözüm: WaitFor'u TEK SEFER ve TAM ATimeoutMs ile
    // ayrı bir arka plan thread'inde çağırıp, çağıran thread'i (muhtemelen
    // UI/main) rad.thread.pas TRadTask.Wait (satır 526-530) deseniyle mesaj
    // pompalayarak beklet — WaitFor'un kendisi asla parçalı çağrılmıyor.
    LEvent := evTimeOut;
    LBgThread := TThread.CreateAnonymousThread(
      procedure
      begin
        LEvent := LItem.WaitFor(ATimeoutMs);
      end);
    LBgThread.FreeOnTerminate := False;
    LBgThread.Start;
    while not LBgThread.Finished do
    begin
      Application.ProcessMessages;
      CheckSynchronize(5);
    end;
    LBgThread.Free;
  end;

  Result := LEvent = evRaised;
  LItem.Reset;
end;

procedure TRadWorkers.Disable;
begin
  FEnabled := False;
end;

procedure TRadWorkers.Enable;
begin
  FEnabled := True;
end;

function TRadWorkers.GetMinWorkers: Integer;
begin
  Result := FMinWorkersValue;
end;

procedure TRadWorkers.SetMinWorkers(AValue: Integer);
begin
  FMinWorkersValue := AValue;
end;

function TRadWorkers.GetMaxWorkers: Integer;
begin
  FEngineLock.Lock;
  try
    Result := FEngine.MaxRunning;
  finally
    FEngineLock.UnLock;
  end;
end;

procedure TRadWorkers.SetMaxWorkers(AValue: Integer);
var
  LOld: TLoggedWorker;
  LNew: TLoggedWorker;
begin
  // NOT: FEngine değişimi kendi ÖZEL kilidiyle (FEngineLock) korunuyor —
  // FLock KULLANILMIYOR çünkü SchedulerTick, FLock tutarken DispatchJob'ı
  // çağırıyor ve DispatchJob da FEngine'e erişiyor; aynı kilit kullanılsaydı
  // TLightLock non-reentrant olduğu için SchedulerTick kendi kendini
  // kilitlerdi (GERÇEK BULGU: standalone test programında ilk halde bu
  // yüzden program tamamen askıda kaldı/hang oldu — bkz. rapor). FEngineLock
  // ile FLock'un koruduğu veri (FPending/FWaitMap) tamamen ayrı olduğundan
  // iki farklı kilit kullanmak güvenli ve deadlock'suz.
  FEngineLock.Lock;
  try
    if AValue = FEngine.MaxRunning then Exit;
    LOld := FEngine;
    LNew := TLoggedWorker.Create(TSynLog, AValue);
    LNew.OnBeforeEachTask := OnBeforeTask;
    LNew.OnAfterEachTask  := OnAfterTask;
    FEngine := LNew;
  finally
    FEngineLock.UnLock;
  end;
  LOld.Free; // Terminate(true): bekleyen/çalışan işlerin bitmesini bekler
end;

function TRadWorkers.GetBusyWorkers: Integer;
begin
  FEngineLock.Lock;
  try
    Result := FEngine.Running;
  finally
    FEngineLock.UnLock;
  end;
end;

function TRadWorkers.GetIdleWorkers: Integer;
begin
  FEngineLock.Lock;
  try
    Result := FEngine.MaxRunning - FEngine.Running;
  finally
    FEngineLock.UnLock;
  end;
  if Result < 0 then Result := 0;
end;

initialization
  Workers := TRadWorkers.Create;

finalization
  FreeAndNil(Workers);

end.
