unit rad.eventbus;

{
  TChannelBus — Adlandırılmış kanallı (named channel) event bus.

  Bu ünite, iki açık kaynak kütüphaneden (vendor\gabr42\GpDelphiUnits\src\GpEventBus.pas ve
  vendor\dalijap\nx-horizon\source\NX.Horizon.pas) ilham alınarak, ama HER İKİSİNİN de string
  tabanlı kanal desteklemediği tespit edildiği için, doğrudan bir wrapper/adapter olarak DEĞİL,
  bu iki kütüphanenin KANITLANMIŞ tekniklerini yeniden kullanan yeni bir yapı olarak yazılmıştır.

  Neden "wrapper" değil (analiz):
    - GpEventBus.Subscribe<T>/Fire<T> SADECE T'nin PTypeInfo'suna göre anahtarlanıyor; kanal
      kavramı yok. Aynı T tipini birden fazla ada (ör. 'customer.record' ve 'order.process')
      bağlamak için bir "zarf" (envelope) tipiyle sarmalayıp filtrelemek gerekirdi — bu da
      GpEventBus'ın asıl dispatch mekanizmasını (thread-based APC dispatch, RegisterThread
      zorunluluğu, alertable-wait gerekliliği) tamamen bypass edip kendi dispatch katmanımızı
      yazmamızı gerektirirdi; yani "wrapper" görünümünde ama içeriği yeniden yazılmış bir kod
      ortaya çıkardı. Ayrıca GpEventBus'ın "No Synchronous Dispatch Option" kısıtı (bkz.
      GpEventBus.md) dmSync/dmMainSync gibi bloklayan modları desteklemesini imkansız kılıyor.
    - NX.Horizon da PTypeInfo ile anahtarlanıyor (TDictionary<PTypeInfo, ...>), string kanal yok.
    - Bu yüzden: kanal deposu (TDictionary<string, ...>, normalize edilmiş anahtar) YENİ yazıldı;
      ama şu KANITLANMIŞ teknikler doğrudan bu iki kütüphaneden alınıp uyarlandı:
        * GpEventBus'ın generic anonymous method'u IInterface olarak "boxing" ile tip silme
          (type erasure) tekniği (TSubscriptionRecord.Handler: IInterface deseni).
        * GpEventBus'ın TLightweightMREW + "kilit altında snapshot array al, kilidi bırak,
          snapshot üzerinde dispatch et" deseni (Fire<T> içindeki GetActiveSubscriptions).
        * GpEventBus'ın "TEventBus class, IEventBus interface DEĞİL" kararı — Delphi
          interface'leri generic method içeremediği için (Subscribe<T>/Fire<T>).
        * NX.Horizon'un TNxHorizonDelivery (Sync/Async/MainSync/MainAsync) enum'u ve
          DispatchEvent'teki MainSync/MainAsync dispatch mantığı (TThread.Synchronize /
          TThread.ForceQueue) — bu ünitede dmSync/dmAsync/dmMainSync/dmMainAsync olarak.
        * NX.Horizon'un TCountdownEvent tabanlı BeginWork/EndWork/WaitFor deseni — "dispatch
          sırasında güvenli unsubscribe" (ref-counting + lazy removal) için GpEventBus'ın basit
          atomik bayrağından daha güçlü olduğu için bu tercih edildi.

  MainSync deadlock önleme: DispatchOne, çağıran thread zaten ana thread ise handler'ı DOĞRUDAN
  çağırır (TThread.Synchronize kendi kendini bekletip kilitlenmesin diye); değilse
  TThread.Synchronize kullanır. TChannelSubscription.WaitAndUnsubscribe de aynı prensiple, ana
  thread'den çağrılıyorsa CheckSynchronize'i pompalayarak bekler (NX.Horizon'daki WaitFor deseni).

  Kanal adları: Trim + ToLowerInvariant ile normalize edilir (rad.cmd.pas'ta bulduğumuz "Turkish I"
  locale hatasından ders alınarak ToLower DEĞİL ToLowerInvariant kullanılıyor).

  Basit kullanım:
    var Sub := ChannelBus.Subscribe<TSiparisEvent>('order.process', dmMainAsync,
      procedure(const AEvent: TSiparisEvent) begin ListeyiGuncelle(AEvent) end);
    ChannelBus.Publish<TSiparisEvent>('order.process', Siparis);
    ...
    Sub.Unsubscribe;
}

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.SyncObjs, System.Threading,
  System.Generics.Collections, System.TypInfo, System.Rtti, System.Masks,
  mormot.core.variants;

const
  RAD_EVENTBUS_DEFAULT_QUEUE_DEPTH = 1024;

type
  /// Bir olayın nasıl teslim edileceği.
  TChannelDelivery = (
    dmSync,      // Publish çağıran thread'de, doğrudan ve senkron (bloklayan).
    dmAsync,     // Sınırlı/politikalı arka plan kuyruğu üzerinden, thread pool'da (TTask).
    dmMainSync,  // Ana thread'de senkron (bloklayan) — TThread.Synchronize, self-deadlock korumalı.
    dmMainAsync  // Ana thread'e kuyruklanır (TThread.ForceQueue), Publish'i bloklamaz.
  );

  /// dmAsync kuyruğu dolduğunda uygulanacak politika.
  TOverflowPolicy = (
    opDropOldest,     // Kuyruktaki en eski olayı at, yenisini ekle.
    opDropNewest,     // Yeni geleni sessizce reddet (kuyruk olduğu gibi kalır).
    opBlockPublisher, // Publish çağıran thread'i, kuyrukta yer açılana kadar bloklar.
    opGrow            // Sınır yok say, kuyruk büyümeye devam eder (bellek riski kullanıcı sorumluluğunda).
  );

  TChannelHandler<T: record> = reference to procedure(const AEvent: T);

  /// rad.cmd.pas'taki TCmd (TArray<TValue>) tasarımıyla tutarlı, esnek/dinamik imzalı
  /// handler — çalışma zamanında (RTTI ile) her tipi taşıyabilir, T:record kısıtı yok.
  TChannelHandlerDyn = reference to procedure(const AArgs: TArray<TValue>);

  /// mORMot IDocDict (JSON) tabanlı handler — dinamik/scriptable senaryolar için.
  TChannelHandlerJson = reference to procedure(const AJson: IDocDict);

  /// Bir abonenin handler'ı exception fırlattığında çağrılır. AData, dispatch edilmekte
  /// olan olayın TValue'ya kutulanmış hali (TValue.From<T>/From<TArray<TValue>>/From<IDocDict>) —
  /// AData.TypeInfo veya AData.AsType<T> ile içeriğine bakılabilir.
  TChannelErrorHandler = reference to procedure(const AChannel: string; const AData: TValue; E: Exception);

  /// Publish çağrısından ÖNCE/SONRA (her abone için değil, ÇAĞRI BAŞINA bir kez) araya
  /// giren middleware/interceptor imzası — loglama, metrik, denetim (audit) için.
  TChannelInterceptor = reference to procedure(const AChannel: string; const AData: TValue);

  /// Abonelik token'ı — güvenli unsubscribe için.
  IChannelSubscription = interface
    ['{9B2E6F1A-3C4D-4E7B-8A1F-2D5C6E9B0A3F}']
    function GetIsActive: Boolean;
    function GetChannel: string;
    /// Aboneliği iptal eder. Dispatch sırasında çağrılması güvenlidir (lazy removal).
    procedure Unsubscribe;
    /// O an çalışan dispatch'lerin bitmesini bekler, sonra Unsubscribe eder.
    procedure WaitAndUnsubscribe(ATimeoutMs: Cardinal = INFINITE);
    property IsActive: Boolean read GetIsActive;
    property Channel: string read GetChannel;
  end;

  // Not: TChannelBus BİLEREK bir interface değil, class olarak tasarlandı — Delphi
  // interface'leri generic method içeremez (GpEventBus.pas'ın kendi başlık yorumundaki
  // gerekçeyle aynı: "Core event bus class (not interface - Delphi interfaces cannot
  // have generic methods)"). TChannelBus ömrünü sen yönetirsin (Create/Free) —
  // CreateChannelBus ile ürettiğin örneği finally bloğunda Free etmeyi unutma; global
  // ChannelBus örneği ünite finalization'ında otomatik serbest bırakılır.
  TChannelBus = class
  strict private
    type
      // İç kullanım: OnError'a geçilecek AData:TValue, TValue.From<T> ile RTTI tabanlı
      // kutulama gerektirir — bunun HER Publish çağrısında (hata olsun olmasın) çalışması
      // ölçülebilir bir performans maliyetiydi (bkz. rad.eventbus.md, benchmark notu).
      // Bu yüzden AData artık EAGER değil, LAZY: yalnızca gerçekten bir exception
      // yakalandığında (except bloğunda) çağrılan bir fonksiyon olarak taşınıyor.
      TChannelDataProvider = reference to function: TValue;

      // İç kullanım: TSubscriberList'in abonelik nesnesinin gerçek verilerine güvenli
      // erişimi (interface-to-class ham cast yerine interface-to-interface — Delphi'de
      // her zaman güvenli olan tek yöntem).
      IChannelSubscriptionInternal = interface
        ['{2F6A9C3D-7B1E-4A5C-9D2F-6E8B1A4C7D9E}']
        function GetTypeInfoRef: PTypeInfo;
        function GetDelivery: TChannelDelivery;
        function GetHandler: IInterface;
        function BeginWork: Boolean;
        procedure EndWork;
        function GetMainSyncTimeoutMs: Cardinal;
        /// Debounce KAPALIYSA (DebounceMs=0) AFinalDispatch'i hemen çalıştırır. AÇIKSA
        /// AFinalDispatch'i "en son gelen" olarak kaydeder ve DebounceMs kadar sessizlik
        /// sonunda (bu arada daha yeni bir çağrı gelmediyse) bir thread pool thread'inde
        /// çalıştırır — GERÇEK debounce semantiği (arama kutusu, resize gibi).
        procedure ScheduleOrRun(const AFinalDispatch: TProc);
        /// AChannel, bu aboneliğin (wildcard) desenine uyuyor mu — önceden derlenmiş
        /// TMask ile (her Publish'te yeniden parse etmemek için, bkz. rad.eventbus.md).
        function Matches(const AChannel: string): Boolean;
      end;

      TChannelSubscription = class(TInterfacedObject, IChannelSubscription, IChannelSubscriptionInternal)
      strict private
        FChannel  : string;
        FTypeInfo : PTypeInfo;
        FDelivery : TChannelDelivery;
        FHandler  : IInterface; // boxed TChannelHandler<T> — GpEventBus'taki teknik
        FCountdown: TCountdownEvent;
        FCanceled : Integer;    // 0/1, TInterlocked ile okunur/yazılır
        FMainSyncTimeoutMs: Cardinal;
        // Debounce: FDebounceLock yalnızca ADebounceMs>0 iken Create'te ayrılır (çoğunluk
        // debounce KULLANMADIĞI için normal aboneliklere ekstra maliyet bindirilmez).
        FDebounceMs        : Cardinal;
        FDebounceLock      : TCriticalSection;
        FDebounceGeneration: Integer;
        FPendingProc       : TProc;
        // Wildcard ('*'/'?') kanal deseni için önceden derlenmiş maske — yalnızca
        // desenli kanallarda ayrılır (bkz. Create), her Publish'te MatchesMask ile
        // yeniden parse etmemek için.
        FMask              : TMask;
      public
        constructor Create(const AChannel: string; ATypeInfo: PTypeInfo; ADelivery: TChannelDelivery;
          const AHandler: IInterface; AMainSyncTimeoutMs: Cardinal; ADebounceMs: Cardinal);
        destructor Destroy; override;

        /// Dispatch başlamadan önce çağrılır; iptal edilmişse False döner (handler çağrılmaz).
        function BeginWork: Boolean;
        procedure EndWork;

        function GetIsActive: Boolean;
        function GetChannel: string;
        function GetTypeInfoRef: PTypeInfo;
        function GetDelivery: TChannelDelivery;
        function GetHandler: IInterface;
        function GetMainSyncTimeoutMs: Cardinal;
        procedure ScheduleOrRun(const AFinalDispatch: TProc);
        function Matches(const AChannel: string): Boolean;
        procedure Unsubscribe;
        procedure WaitAndUnsubscribe(ATimeoutMs: Cardinal);
      end;

      TSubscriberList = class
      strict private
        FLock      : TLightweightMREW;
        FItems     : TList<IChannelSubscription>;
        // Performans: eskiden SnapshotAndCompact HER Publish çağrısında FItems.ToArray
        // ile yeni bir dizi ayırıyordu (benchmark'ta dmMainAsync gecikme analizinde
        // tespit edilen darboğaz). Artık dizi yalnızca Add sonrası veya gerçekten ölü
        // bir kayıt bulunduğunda yeniden oluşturuluyor; aradaki çağrılar allocation'sız.
        FCache     : TArray<IChannelSubscription>;
        FCacheDirty: Boolean;
      public
        constructor Create;
        destructor Destroy; override;
        procedure Add(const ASub: IChannelSubscription);
        /// Aktif olmayanları listeden temizler (lazy removal) ve aktiflerin bir kopyasını döner.
        function SnapshotAndCompact: TArray<IChannelSubscription>;
        function Count: Integer;
      end;

      /// Sınırlı/politikalı asenkron olay kuyruğu (dmAsync backpressure için).
      TAsyncEventQueue = class
      strict private
        // Not: FItems TQueue<TProc> DEĞİL — TQueue<T>.Dequeue, T bir "reference to
        // procedure" (closure) tipiyken yanlış tip çıkarımı yapan bilinen bir dcc32
        // hatasına (E2010 "Incompatible types... Procedure of object") takılıyor;
        // bu izole edilip minimal bir .dpr ile doğrulandı. Çözüm: GpEventBus'ın kendi
        // type-erasure tekniğiyle aynı — TProc'u IInterface olarak kutula/aç.
        FLock          : TCriticalSection;
        FItems         : TQueue<IInterface>;
        FMaxDepth      : Integer;
        FPolicy        : TOverflowPolicy;
        FItemAvailable : TEvent; // manual-reset: kuyruk boş değilken sinyalli
        FSpaceAvailable: TEvent; // manual-reset: kuyrukta yer varken sinyalli
        FDroppedCount  : Integer;
        FStopped       : Boolean;
        procedure UpdateSignals;
        function GetDroppedCount: Integer;
      public
        constructor Create(AMaxDepth: Integer; APolicy: TOverflowPolicy);
        destructor Destroy; override;
        function TryEnqueue(const AProc: TProc; ATimeoutMs: Cardinal): Boolean;
        function TryDequeue(out AProc: TProc; ATimeoutMs: Cardinal): Boolean;
        procedure Stop;
        property DroppedCount: Integer read GetDroppedCount;
      end;

      /// dmAsync kuyruğunu boşaltıp TTask.Run ile paralel çalıştıran arka plan pompası.
      TPumpThread = class(TThread)
      strict private
        FQueue: TAsyncEventQueue;
      protected
        procedure Execute; override;
      public
        constructor Create(AQueue: TAsyncEventQueue);
      end;

    var
      FLock          : TLightweightMREW;
      FChannels      : TObjectDictionary<string, TSubscriberList>;
      // Wildcard ('*'/'?' içeren, ör. 'siparis.*') abonelikler normal FChannels
      // sözlüğünde DEĞİL, ayrı bir havuzda tutulur — bir kanal adı DEĞİL bir DESEN
      // olduğu için tekil bir TSubscriberList anahtarına oturmuyor. FHasWildcardsInt,
      // hiç wildcard abonelik yokken Publish'in ekstra kilit/tarama maliyetine hiç
      // girmemesi için ucuz bir kısayol bayrağıdır (aşağıda tanımlı).
      FWildcardSubs  : TSubscriberList;
      // TInterlocked ile erişilen bayraklar (0/1) — hiç wildcard/interceptor yokken
      // Publish'in ekstra kilit/tarama/hesaplama maliyetine hiç girmemesi için ucuz
      // kısayol bayraklarıdır; yazımlar TInterlocked olduğundan okumalar da öyle olmalı
      // (bkz. rad.thread.pas'taki IsRunning/IsDone tutarsızlığı ile aynı ders).
      FHasWildcardsInt  : Integer;
      FAsyncQueue    : TAsyncEventQueue;
      FPump          : TPumpThread;
      FPolicy        : TOverflowPolicy;
      FOnError       : TChannelErrorHandler;
      FErrorIsolation: Boolean;
      FInterceptorLock : TLightweightMREW;
      FBeforePublish   : TList<TChannelInterceptor>;
      FAfterPublish    : TList<TChannelInterceptor>;
      // Add-only listelerin (kaldırma desteklenmiyor) her Publish'te TList.ToArray
      // maliyetine girmemesi için — yalnızca AddBeforePublish/AddAfterPublish'te
      // yeniden oluşturulur, RunInterceptors bunu referans olarak okur.
      FBeforePublishCache: TArray<TChannelInterceptor>;
      FAfterPublishCache : TArray<TChannelInterceptor>;
      FHasBeforePublishInt: Integer;
      FHasAfterPublishInt : Integer;

    function NormalizeChannel(const AChannel: string): string; inline;
    function GetOrCreateList(const AChannel: string): TSubscriberList;
    /// AChannel için kayıtlı listeyi döner, YOKSA OLUŞTURMAZ (Publish/okuma yolunda
    /// kullanılır — abonesi hiç olmayan kanallar için kalıcı boş liste birikmesin diye).
    function TryGetList(const AChannel: string; out AList: TSubscriberList): Boolean;
    function GetHasWildcards: Boolean;
    function GetHasBeforePublish: Boolean;
    function GetHasAfterPublish: Boolean;
    /// AChannel'a tam eşleşen abonelikleri + AChannel'ı karşılayan wildcard desenli
    /// (ör. 'siparis.*') abonelikleri BİRLEŞTİRİP döner. Wildcard yoksa (yaygın durum)
    /// tek bir Count kontrolü dışında ekstra maliyeti yoktur. Tüm okuma (TryGetValue +
    /// SnapshotAndCompact) TEK bir FLock.BeginRead kapsamında yapılır — aksi halde
    /// GetOrCreateList kilidi bırakıp döndükten SONRA başka bir thread UnsubscribeChannel
    /// ile aynı listeyi (doOwnsValues nedeniyle) Free edebilir, use-after-free oluşurdu.
    function GetMatchingSubscriptions(const ANormalizedChannel: string): TArray<IChannelSubscription>;
    /// ACache'teki (Before veya After) interceptor'ları çalıştırır — interceptor'lardan biri
    /// exception fırlatırsa (ErrorIsolation açıksa) yutulur, diğer interceptor'lar yine de
    /// çalışır. AGetData yalnızca en az bir interceptor kayıtlıysa çağrılır (lazy).
    procedure RunInterceptors(const ACache: TArray<TChannelInterceptor>; const AChannel: string;
      const AGetData: TChannelDataProvider);
    /// AGetData: dispatch edilen olayı TValue'ya kutulayan TEMBEL (lazy) bir sağlayıcı —
    /// yalnızca bir handler GERÇEKTEN exception fırlatırsa (except bloğunda) çağrılır;
    /// normal (hatasız) akışta TValue.From<T>'nin RTTI maliyetine hiç girilmez.
    procedure DispatchOne(const AGetData: TChannelDataProvider; const ASub: IChannelSubscription;
      const AProc: TProc; ADelivery: TChannelDelivery);
    /// Subscribe<T>/Subscribe(Dyn)/Subscribe(Json)'ın ortak, kutulama sonrası adımı —
    /// ATypeInfo, Publish tarafında hangi payload "türüne" ait olduğunu filtrelemek için
    /// kullanılan etikettir (generic T için System.TypeInfo(T); dinamik/JSON overload'lar
    /// için sabit birer "tür etiketi": TypeInfo(TArray<TValue>) / TypeInfo(IDocDict)).
    /// AChannel '*' veya '?' içeriyorsa (ör. 'siparis.*') abonelik normal kanal
    /// sözlüğü yerine wildcard havuzuna kaydedilir.
    function SubscribeBoxed(const AChannel: string; ATypeInfo: PTypeInfo; ADelivery: TChannelDelivery;
      const ABoxedHandler: IInterface; AMainSyncTimeoutMs: Cardinal; ADebounceMs: Cardinal): IChannelSubscription;
  public
    /// AErrorIsolation=True (varsayılan): her abone dispatch'i kendi try/except'ine
    /// sarılır — bir abonenin hatası diğerlerini engellemez, OnError'a bildirilebilir
    /// (bkz. rad.eventbus.md "Hata Yönetimi"). AErrorIsolation=False: bu sarmalama hiç
    /// yapılmaz (eski/çıplak davranış) — izolasyon/OnError kaybedilir ama dmSync gibi
    /// çok sık çağrılan yollarda try/except'in getirdiği küçük ek maliyetten bile
    /// kaçınmak isteyen, üst düzeyde kendi hata yönetimini yapan ileri seviye senaryolar için.
    constructor Create(AOverflowPolicy: TOverflowPolicy = opBlockPublisher;
      AQueueDepth: Integer = RAD_EVENTBUS_DEFAULT_QUEUE_DEPTH; AErrorIsolation: Boolean = True);
    destructor Destroy; override;

    /// Bu bus için izolasyon/OnError sarmalamasının açık olup olmadığı (Create'te belirlenir).
    property ErrorIsolation: Boolean read FErrorIsolation;

    /// AChannel'a abone olur. Kanal adı büyük/küçük harf duyarsızdır (normalize edilir).
    /// AMainSyncTimeoutMs: yalnızca ADelivery=dmMainSync iken kullanılır — INFINITE
    /// (varsayılan) ise eski davranış (TThread.Synchronize, süresiz bekler); bir değer
    /// verilirse yayıncı thread en fazla bu kadar bekler (bkz. rad.eventbus.md).
    /// ADebounceMs>0 ise handler, ardışık olaylarda en son gelenle, ADebounceMs kadar
    /// sessizlik sonunda bir kez (bir thread pool thread'inde) çalışır — gerçek debounce.
    function Subscribe<T: record>(const AChannel: string; ADelivery: TChannelDelivery;
      const AHandler: TChannelHandler<T>; AMainSyncTimeoutMs: Cardinal = INFINITE;
      ADebounceMs: Cardinal = 0): IChannelSubscription; overload;

    /// AChannel'a, TArray<TValue> tabanlı esnek/dinamik imzayla abone olur (rad.cmd.pas'taki
    /// TCmd tasarımıyla tutarlı). Yalnızca AYNI şekilde (TArray<TValue> ile) yayınlanan
    /// olayları alır — Subscribe<T>/Subscribe(...IDocDict...) abonelikleriyle karışmaz.
    /// AMainSyncTimeoutMs/ADebounceMs: yukarıdaki Subscribe<T> ile aynı anlamda.
    function Subscribe(const AChannel: string; ADelivery: TChannelDelivery;
      const AHandler: TChannelHandlerDyn; AMainSyncTimeoutMs: Cardinal = INFINITE;
      ADebounceMs: Cardinal = 0): IChannelSubscription; overload;

    /// AChannel'a, mORMot IDocDict (JSON) tabanlı imzayla abone olur. Yalnızca IDocDict
    /// ile yayınlanan olayları alır. AMainSyncTimeoutMs/ADebounceMs: yukarıdaki gibi.
    function Subscribe(const AChannel: string; ADelivery: TChannelDelivery;
      const AHandler: TChannelHandlerJson; AMainSyncTimeoutMs: Cardinal = INFINITE;
      ADebounceMs: Cardinal = 0): IChannelSubscription; overload;

    /// AChannel'a, aboneliklerin KENDİ delivery modlarına göre yayınlar.
    procedure Publish<T: record>(const AChannel: string; const AEvent: T); overload;
    /// AChannel'a, ADelivery ile aboneliklerin delivery modunu GEÇERSİZ KILARAK yayınlar
    /// (NX.Horizon'un Send<T> deseni).
    procedure Publish<T: record>(const AChannel: string; const AEvent: T; ADelivery: TChannelDelivery); overload;

    /// AChannel'a TArray<TValue> ile yayınlar; yalnızca Subscribe(...TChannelHandlerDyn...)
    /// abonelerine ulaşır.
    procedure Publish(const AChannel: string; const AArgs: TArray<TValue>); overload;
    procedure Publish(const AChannel: string; const AArgs: TArray<TValue>; ADelivery: TChannelDelivery); overload;

    /// AChannel'a IDocDict (JSON) ile yayınlar; yalnızca Subscribe(...TChannelHandlerJson...)
    /// abonelerine ulaşır.
    procedure Publish(const AChannel: string; const AJson: IDocDict); overload;
    procedure Publish(const AChannel: string; const AJson: IDocDict; ADelivery: TChannelDelivery); overload;

    /// Bu kanala TAM eşleşen aktif abone sayısı — bu kanalı karşılayan wildcard
    /// desenli abonelikleri (ör. 'siparis.*') SAYMAZ; onlar için bkz. WildcardPatterns.
    function SubscriberCount(const AChannel: string): Integer;
    /// Şu an en az bir kayıtlı aboneliği olan tüm (wildcard OLMAYAN) kanal adlarını döner.
    function Channels: TArray<string>;
    /// Kayıtlı tüm wildcard desenlerini döner (ör. 'siparis.*').
    function WildcardPatterns: TArray<string>;
    /// Bus genelinde, tüm kanallar + wildcard havuzundaki toplam AKTİF abone sayısı.
    function TotalSubscriberCount: Integer;
    /// Yalnızca AChannel'a TAM eşleşen abonelikleri kaldırır — wildcard desenli
    /// abonelikleri (ör. 'siparis.*') KALDIRMAZ (sessizce no-op'tur), çünkü onlar ayrı
    /// bir havuzda (wildcard subs) tutulur. Wildcard bir aboneliği kaldırmak için o
    /// aboneliğin kendi IChannelSubscription.Unsubscribe'ını kullanın.
    procedure UnsubscribeChannel(const AChannel: string);
    /// dmAsync kuyruğunda (opDropOldest/opDropNewest nedeniyle) atılan olay sayısı.
    function DroppedCount: Integer;

    /// ErrorIsolation=True iken (varsayılan) bir abonenin handler'ı exception fırlattığında
    /// çağrılır (hangi delivery modu olursa olsun). ATANMAMIŞSA hata sessizce yutulur
    /// (rad.cmd.pas'taki ExecuteAsync/OnError deseniyle tutarlı) — ama ErrorIsolation=True
    /// olduğu sürece HER İKİ DURUMDA DA dispatch izole edilir: bir abonenin exception'ı,
    /// aynı Publish çağrısındaki DİĞER abonelerin çağrılmasını asla engellemez.
    /// ErrorIsolation=False ise bu property hiç kullanılmaz (bkz. Create).
    property OnError: TChannelErrorHandler read FOnError write FOnError;

    /// AInterceptor'ı, HER Publish çağrısından ÖNCE (abonelere dispatch başlamadan önce,
    /// çağrı başına bir kez) çalışacak şekilde kaydeder. Kaldırma desteklenmez (bus'ın
    /// ömrü boyunca kalıcı — tipik kullanım: uygulama ömrü boyunca sürecek bir loglama/
    /// denetim middleware'i). Bir interceptor exception fırlatırsa (ErrorIsolation=True
    /// iken) yutulur, diğer interceptor'lar ve dispatch etkilenmez.
    procedure AddBeforePublish(const AInterceptor: TChannelInterceptor);
    /// AInterceptor'ı, HER Publish çağrısından SONRA (tüm abonelere dispatch/enqueue
    /// edildikten sonra, çağrı başına bir kez) çalışacak şekilde kaydeder. Diğer notlar
    /// AddBeforePublish ile aynı.
    procedure AddAfterPublish(const AInterceptor: TChannelInterceptor);
  end;

/// Yeni, izole bir kanal veriyolu oluşturur (testler için idealdir). Çağıran sorumludur: Free et.
function CreateChannelBus(AOverflowPolicy: TOverflowPolicy = opBlockPublisher;
  AQueueDepth: Integer = RAD_EVENTBUS_DEFAULT_QUEUE_DEPTH; AErrorIsolation: Boolean = True): TChannelBus;

/// Global, tembel-başlatılan (lazy) paylaşılan kanal veriyolu. Free ETME — ünite kapanışında otomatik temizlenir.
function ChannelBus: TChannelBus;

implementation

{ TChannelBus.TChannelSubscription }

constructor TChannelBus.TChannelSubscription.Create(const AChannel: string; ATypeInfo: PTypeInfo;
  ADelivery: TChannelDelivery; const AHandler: IInterface; AMainSyncTimeoutMs: Cardinal; ADebounceMs: Cardinal);
begin
  inherited Create;
  FChannel   := AChannel;
  FTypeInfo  := ATypeInfo;
  FDelivery  := ADelivery;
  FHandler   := AHandler;
  FCountdown := TCountdownEvent.Create(1); // 1: "abonelik canlı" temel sayacı
  FMainSyncTimeoutMs := AMainSyncTimeoutMs;
  FDebounceMs := ADebounceMs;
  if FDebounceMs > 0 then
    FDebounceLock := TCriticalSection.Create;
  if (Pos('*', AChannel) > 0) or (Pos('?', AChannel) > 0) then
    FMask := TMask.Create(AChannel); // sadece wildcard desenliyse derle
end;

destructor TChannelBus.TChannelSubscription.Destroy;
begin
  FMask.Free;
  FDebounceLock.Free;
  FCountdown.Free;
  inherited;
end;

function TChannelBus.TChannelSubscription.Matches(const AChannel: string): Boolean;
begin
  if Assigned(FMask) then
    Result := FMask.Matches(AChannel)
  else
    Result := FChannel = AChannel;
end;

function TChannelBus.TChannelSubscription.BeginWork: Boolean;
begin
  Result := (TInterlocked.CompareExchange(FCanceled, 0, 0) = 0) and FCountdown.TryAddCount;
end;

procedure TChannelBus.TChannelSubscription.EndWork;
begin
  FCountdown.Signal;
end;

function TChannelBus.TChannelSubscription.GetIsActive: Boolean;
begin
  Result := TInterlocked.CompareExchange(FCanceled, 0, 0) = 0;
end;

function TChannelBus.TChannelSubscription.GetTypeInfoRef: PTypeInfo;
begin
  Result := FTypeInfo;
end;

function TChannelBus.TChannelSubscription.GetDelivery: TChannelDelivery;
begin
  Result := FDelivery;
end;

function TChannelBus.TChannelSubscription.GetHandler: IInterface;
begin
  Result := FHandler;
end;

function TChannelBus.TChannelSubscription.GetChannel: string;
begin
  Result := FChannel;
end;

function TChannelBus.TChannelSubscription.GetMainSyncTimeoutMs: Cardinal;
begin
  Result := FMainSyncTimeoutMs;
end;

procedure TChannelBus.TChannelSubscription.ScheduleOrRun(const AFinalDispatch: TProc);
var
  LGeneration: Integer;
begin
  if FDebounceMs = 0 then
  begin
    AFinalDispatch();
    Exit;
  end;

  // "En son gelen kazanır": FPendingProc + FDebounceGeneration'ı bir kilit altında
  // güncelleyip, DebounceMs kadar uyuyacak bir arka plan görevi başlatıyoruz. Uyandığında
  // kendi üretlildiği andaki nesil hâlâ GÜNCELse (aradan daha yeni bir çağrı gelmediyse)
  // AFinalDispatch'i çalıştırıyor; aksi halde sessizce hiçbir şey yapmıyor (daha yeni bir
  // görev zaten onun yerini almıştır). Bu sayede kalıcı bir thread tutmadan gerçek
  // "sessizlik sonunda bir kez çalış" (debounce) semantiği elde ediliyor.
  FDebounceLock.Enter;
  try
    FPendingProc := AFinalDispatch;
    Inc(FDebounceGeneration);
    LGeneration := FDebounceGeneration;
  finally
    FDebounceLock.Leave;
  end;

  TTask.Run(
    procedure
    var
      LProcToRun: TProc;
      LShouldRun: Boolean;
    begin
      Sleep(FDebounceMs);
      FDebounceLock.Enter;
      try
        LShouldRun := FDebounceGeneration = LGeneration;
        if LShouldRun then
        begin
          LProcToRun := FPendingProc;
          // FPendingProc, ScheduleOrRun'un kendi Self'ini (LSub üzerinden) yakalayan
          // closure'ı tutuyordu — burada TEMİZLENMEZSE kalıcı bir self-reference
          // döngüsü oluşur ve bu abonelik hiçbir zaman serbest kalmaz (memory leak).
          // Yalnızca GERÇEKTEN çalıştırılacaksa (bu nesil hâlâ güncelse) temizlenir;
          // daha yeni bir çağrı FPendingProc'u zaten kendi closure'ıyla değiştirmiştir.
          FPendingProc := nil;
        end;
      finally
        FDebounceLock.Leave;
      end;
      if LShouldRun then
        LProcToRun();
    end);
end;

procedure TChannelBus.TChannelSubscription.Unsubscribe;
begin
  // Sadece bir thread 0->1 geçişini başarır; birden fazla kez çağrılması güvenlidir.
  if TInterlocked.CompareExchange(FCanceled, 1, 0) = 0 then
  begin
    FCountdown.Signal; // temel (1) sayacı bırak; devam eden BeginWork'ler kendi sayaçlarını EndWork'te bırakır
    // Bekleyen bir debounce closure'ı varsa hemen temizle — self-reference döngüsünü
    // doğal debounce süresinin dolmasını beklemeden anında kırar (bkz. ScheduleOrRun).
    if Assigned(FDebounceLock) then
    begin
      FDebounceLock.Enter;
      try
        FPendingProc := nil;
      finally
        FDebounceLock.Leave;
      end;
    end;
  end;
end;

procedure TChannelBus.TChannelSubscription.WaitAndUnsubscribe(ATimeoutMs: Cardinal);
var
  StartTick: UInt64;
begin
  Unsubscribe;
  StartTick := TThread.GetTickCount64;
  // Ana thread'den çağrılıyorsa CheckSynchronize'i pompalayarak bekle — aksi halde
  // dmMainSync/dmMainAsync ile ana thread'e kuyruklanmış bekleyen dispatch'ler asla
  // çalışamaz ve burada sonsuza kadar bloklanırız (NX.Horizon'daki WaitFor deseni).
  if TThread.CurrentThread.ThreadID = MainThreadID then
  begin
    while FCountdown.WaitFor(50) <> wrSignaled do
    begin
      CheckSynchronize(20);
      if (ATimeoutMs <> INFINITE) and (TThread.GetTickCount64 - StartTick >= ATimeoutMs) then
        Exit;
    end;
  end
  else
    FCountdown.WaitFor(ATimeoutMs);
end;

{ TChannelBus.TSubscriberList }

constructor TChannelBus.TSubscriberList.Create;
begin
  inherited Create;
  FItems := TList<IChannelSubscription>.Create;
end;

destructor TChannelBus.TSubscriberList.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TChannelBus.TSubscriberList.Add(const ASub: IChannelSubscription);
begin
  FLock.BeginWrite;
  try
    FItems.Add(ASub);
    FCacheDirty := True;
  finally
    FLock.EndWrite;
  end;
end;

function TChannelBus.TSubscriberList.SnapshotAndCompact: TArray<IChannelSubscription>;
var
  i: Integer;
  NeedsRebuild: Boolean;
begin
  // Hızlı yol: Add sonrası değilsek (FCacheDirty=False), cache'i allocation'sız (sadece
  // ucuz IsActive taramasıyla) doğrula ve olduğu gibi döndür — benchmark'ta tespit edilen
  // "her Publish çağrısında yeni dizi ayrılıyor" darboğazını kapatır.
  FLock.BeginRead;
  try
    NeedsRebuild := FCacheDirty;
    if not NeedsRebuild then
      for i := 0 to High(FCache) do
        if not FCache[i].IsActive then
        begin
          NeedsRebuild := True;
          Break;
        end;
    if not NeedsRebuild then
    begin
      Result := FCache;
      Exit;
    end;
  finally
    FLock.EndRead;
  end;

  // Yavaş yol: yeni ekleme oldu VEYA ölü kayıt bulundu — kilit altında hem FItems'ı
  // sadeleştir (lazy removal) hem de cache dizisini yeniden oluştur.
  FLock.BeginWrite;
  try
    for i := FItems.Count - 1 downto 0 do
      if not FItems[i].IsActive then
        FItems.Delete(i);
    FCache := FItems.ToArray;
    FCacheDirty := False;
    Result := FCache;
  finally
    FLock.EndWrite;
  end;
end;

function TChannelBus.TSubscriberList.Count: Integer;
var
  i: Integer;
begin
  // Ham liste boyutu değil, aktif abonelik sayısı döner — Unsubscribe edilmiş ama
  // henüz bir dispatch tarafından süpürülmemiş (lazy removal) kayıtlar sayılmaz.
  FLock.BeginRead;
  try
    Result := 0;
    for i := 0 to FItems.Count - 1 do
      if FItems[i].IsActive then
        Inc(Result);
  finally
    FLock.EndRead;
  end;
end;

{ TChannelBus.TAsyncEventQueue }

constructor TChannelBus.TAsyncEventQueue.Create(AMaxDepth: Integer; APolicy: TOverflowPolicy);
begin
  inherited Create;
  FMaxDepth := AMaxDepth;
  FPolicy   := APolicy;
  FLock     := TCriticalSection.Create;
  FItems    := TQueue<IInterface>.Create;
  FItemAvailable  := TEvent.Create(nil, True, False, '');
  FSpaceAvailable := TEvent.Create(nil, True, True, '');
end;

destructor TChannelBus.TAsyncEventQueue.Destroy;
begin
  FItemAvailable.Free;
  FSpaceAvailable.Free;
  FItems.Free;
  FLock.Free;
  inherited;
end;

function TChannelBus.TAsyncEventQueue.GetDroppedCount: Integer;
begin
  Result := TInterlocked.CompareExchange(FDroppedCount, 0, 0);
end;

procedure TChannelBus.TAsyncEventQueue.UpdateSignals;
begin
  if FItems.Count = 0 then FItemAvailable.ResetEvent else FItemAvailable.SetEvent;
  if (FMaxDepth <= 0) or (FItems.Count < FMaxDepth) then FSpaceAvailable.SetEvent else FSpaceAvailable.ResetEvent;
end;

procedure TChannelBus.TAsyncEventQueue.Stop;
begin
  FLock.Enter;
  try
    FStopped := True;
  finally
    FLock.Leave;
  end;
  FItemAvailable.SetEvent;
  FSpaceAvailable.SetEvent;
end;

function TChannelBus.TAsyncEventQueue.TryEnqueue(const AProc: TProc; ATimeoutMs: Cardinal): Boolean;
var
  StartTick: UInt64;
  Remaining: Int64;
  LBoxed   : IInterface;
begin
  LBoxed := IInterface(Pointer(@AProc)^);
  StartTick := TThread.GetTickCount64;
  FLock.Enter;
  try
    if FPolicy = opGrow then
    begin
      FItems.Enqueue(LBoxed);
      UpdateSignals;
      Exit(True);
    end;

    while (not FStopped) and (FMaxDepth > 0) and (FItems.Count >= FMaxDepth) do
    begin
      case FPolicy of
        opDropOldest:
          begin
            FItems.Dequeue;
            TInterlocked.Increment(FDroppedCount);
            Break; // yer açıldı, döngüden çık ve ekle
          end;
        opDropNewest:
          begin
            TInterlocked.Increment(FDroppedCount);
            Exit(False);
          end;
      else // opBlockPublisher
        begin
          {$IFDEF DEBUG}
          // Ana thread'den opBlockPublisher ile dolu bir kuyruğa Publish (dmAsync) çağrılırsa
          // ana thread burada bloklanmak üzeredir — bu genellikle bir tasarım hatasıdır
          // (bkz. rad.eventbus.md "opBlockPublisher + Ana Thread Riski"). Yalnızca DEBUG
          // derlemede, GERÇEKTEN bloklanacağımız anda (kuyruk dolu) tespit edip bildiriyoruz;
          // RELEASE derlemede bu kontrol tamamen devre dışıdır (sıfır maliyet).
          if TThread.CurrentThread.ThreadID = MainThreadID then
            raise Exception.Create('rad.eventbus: opBlockPublisher kuyruğu doluyken ANA THREAD''den ' +
              '(dmAsync) Publish çağrıldı — ana thread kilitlenmek üzereydi. Çözüm: kuyruk derinliğini ' +
              '(AQueueDepth) artırın, ana thread yerine bir arka plan thread''inden yayınlayın, veya ' +
              'farklı bir taşma politikası (opDropOldest/opDropNewest/opGrow) kullanın. ' +
              '(Bu kontrol yalnızca DEBUG derlemede aktiftir.)');
          {$ENDIF}
          FLock.Leave;
          try
            if ATimeoutMs = INFINITE then
              Remaining := INFINITE
            else
            begin
              Remaining := ATimeoutMs - Int64(TThread.GetTickCount64 - StartTick);
              if Remaining <= 0 then Exit(False);
            end;
            if FSpaceAvailable.WaitFor(Cardinal(Remaining)) <> wrSignaled then
              Exit(False);
          finally
            FLock.Enter;
          end;
        end;
      end;
    end;

    if FStopped then Exit(False);

    FItems.Enqueue(LBoxed);
    UpdateSignals;
    Result := True;
  finally
    FLock.Leave;
  end;
end;

function TChannelBus.TAsyncEventQueue.TryDequeue(out AProc: TProc; ATimeoutMs: Cardinal): Boolean;
var
  LBoxed: IInterface;
begin
  Result := False;
  AProc := nil;
  if FItemAvailable.WaitFor(ATimeoutMs) <> wrSignaled then
    Exit(False);

  FLock.Enter;
  try
    if FItems.Count = 0 then
      Exit(False); // başka bir thread araya girip boşaltmış olabilir
    LBoxed := FItems.Dequeue;
    AProc := TProc(LBoxed);
    UpdateSignals;
    Result := True;
  finally
    FLock.Leave;
  end;
end;

{ TChannelBus.TPumpThread }

constructor TChannelBus.TPumpThread.Create(AQueue: TAsyncEventQueue);
begin
  inherited Create(False);
  FQueue := AQueue;
  FreeOnTerminate := False;
end;

procedure TChannelBus.TPumpThread.Execute;
var
  Proc: TProc;
begin
  while not Terminated do
    if FQueue.TryDequeue(Proc, 50) then
      TTask.Run(Proc);
end;

{ TChannelBus }

constructor TChannelBus.Create(AOverflowPolicy: TOverflowPolicy; AQueueDepth: Integer; AErrorIsolation: Boolean);
begin
  inherited Create;
  FPolicy         := AOverflowPolicy;
  FErrorIsolation := AErrorIsolation;
  FChannels       := TObjectDictionary<string, TSubscriberList>.Create([doOwnsValues]);
  FWildcardSubs   := TSubscriberList.Create;
  FBeforePublish  := TList<TChannelInterceptor>.Create;
  FAfterPublish   := TList<TChannelInterceptor>.Create;
  FAsyncQueue     := TAsyncEventQueue.Create(AQueueDepth, AOverflowPolicy);
  FPump           := TPumpThread.Create(FAsyncQueue);
end;

destructor TChannelBus.Destroy;
begin
  FAsyncQueue.Stop;
  FPump.Terminate;
  FPump.WaitFor;
  FPump.Free;
  FAsyncQueue.Free;
  FBeforePublish.Free;
  FAfterPublish.Free;
  FWildcardSubs.Free;
  FChannels.Free;
  inherited;
end;

function TChannelBus.NormalizeChannel(const AChannel: string): string;
begin
  // Turkish-I gibi locale sorunlarından kaçınmak için ToLower değil ToLowerInvariant.
  Result := AChannel.Trim.ToLowerInvariant;
  if Result = '' then
    raise EArgumentException.Create('rad.eventbus: kanal adı boş olamaz');
end;

function TChannelBus.GetOrCreateList(const AChannel: string): TSubscriberList;
begin
  FLock.BeginRead;
  try
    if FChannels.TryGetValue(AChannel, Result) then
      Exit;
  finally
    FLock.EndRead;
  end;

  FLock.BeginWrite;
  try
    if not FChannels.TryGetValue(AChannel, Result) then
    begin
      Result := TSubscriberList.Create;
      FChannels.Add(AChannel, Result);
    end;
  finally
    FLock.EndWrite;
  end;
end;

function TChannelBus.TryGetList(const AChannel: string; out AList: TSubscriberList): Boolean;
begin
  FLock.BeginRead;
  try
    Result := FChannels.TryGetValue(AChannel, AList);
  finally
    FLock.EndRead;
  end;
end;

function TChannelBus.GetHasWildcards: Boolean;
begin
  Result := TInterlocked.CompareExchange(FHasWildcardsInt, 0, 0) = 1;
end;

function TChannelBus.GetHasBeforePublish: Boolean;
begin
  Result := TInterlocked.CompareExchange(FHasBeforePublishInt, 0, 0) = 1;
end;

function TChannelBus.GetHasAfterPublish: Boolean;
begin
  Result := TInterlocked.CompareExchange(FHasAfterPublishInt, 0, 0) = 1;
end;

function TChannelBus.GetMatchingSubscriptions(const ANormalizedChannel: string): TArray<IChannelSubscription>;
var
  LExact  : TArray<IChannelSubscription>;
  LWildAll: TArray<IChannelSubscription>;
  LMatched: TList<IChannelSubscription>;
  LSub    : IChannelSubscription;
  LList   : TSubscriberList;
  LHasWildcards: Boolean;
begin
  // Tüm okuma (TryGetValue + SnapshotAndCompact) TEK bir FLock.BeginRead kapsamında
  // yapılır: aksi halde bir TSubscriberList referansı alıp kilidi bıraktıktan SONRA
  // başka bir thread UnsubscribeChannel ile aynı listeyi (FChannels doOwnsValues
  // olduğu için) Free edebilir — use-after-free. FLock.BeginWrite bu okuma sürerken
  // bloke olacağından (TLightweightMREW) bu senaryo artık mümkün değil. Ayrıca
  // GetOrCreateList YERİNE TryGetValue kullanılıyor — abonesi hiç olmayan bir kanal
  // için kalıcı boş liste artık oluşturulmuyor.
  FLock.BeginRead;
  try
    if FChannels.TryGetValue(ANormalizedChannel, LList) then
      LExact := LList.SnapshotAndCompact
    else
      LExact := nil;

    LHasWildcards := GetHasWildcards;
    if LHasWildcards then
      LWildAll := FWildcardSubs.SnapshotAndCompact
    else
      LWildAll := nil;
  finally
    FLock.EndRead;
  end;

  if (not LHasWildcards) or (Length(LWildAll) = 0) then
    Exit(LExact);

  LMatched := TList<IChannelSubscription>.Create;
  try
    LMatched.AddRange(LExact);
    for LSub in LWildAll do
      if (LSub as IChannelSubscriptionInternal).Matches(ANormalizedChannel) then
        LMatched.Add(LSub);
    Result := LMatched.ToArray;
  finally
    LMatched.Free;
  end;
end;

function TChannelBus.SubscribeBoxed(const AChannel: string; ATypeInfo: PTypeInfo; ADelivery: TChannelDelivery;
  const ABoxedHandler: IInterface; AMainSyncTimeoutMs: Cardinal; ADebounceMs: Cardinal): IChannelSubscription;
var
  LChannel: string;
begin
  // Nil kapatılmış (boxed) handler burada tespit edilir — Subscribe<T>/Subscribe(Dyn)/
  // Subscribe(Json)'ın hepsi bu ortak noktadan geçtiği için tek kontrol yeterli
  // (nil closure'ın pointer-tabanlı boxing'i de nil interface üretir).
  if not Assigned(ABoxedHandler) then
    raise EArgumentNilException.Create('rad.eventbus: Subscribe AHandler nil olamaz');
  LChannel := NormalizeChannel(AChannel);
  Result := TChannelSubscription.Create(LChannel, ATypeInfo, ADelivery, ABoxedHandler, AMainSyncTimeoutMs, ADebounceMs);
  if (Pos('*', LChannel) > 0) or (Pos('?', LChannel) > 0) then
  begin
    FWildcardSubs.Add(Result);
    TInterlocked.Exchange(FHasWildcardsInt, 1);
  end
  else
    GetOrCreateList(LChannel).Add(Result);
end;

function TChannelBus.Subscribe<T>(const AChannel: string; ADelivery: TChannelDelivery;
  const AHandler: TChannelHandler<T>; AMainSyncTimeoutMs: Cardinal; ADebounceMs: Cardinal): IChannelSubscription;
begin
  // GpEventBus'taki teknik: generic anonymous method'u IInterface olarak kutula (type erasure),
  // böylece heterojen T tipli abonelikler aynı listede saklanabilir.
  Result := SubscribeBoxed(AChannel, System.TypeInfo(T), ADelivery, IInterface(Pointer(@AHandler)^),
    AMainSyncTimeoutMs, ADebounceMs);
end;

function TChannelBus.Subscribe(const AChannel: string; ADelivery: TChannelDelivery;
  const AHandler: TChannelHandlerDyn; AMainSyncTimeoutMs: Cardinal; ADebounceMs: Cardinal): IChannelSubscription;
begin
  Result := SubscribeBoxed(AChannel, System.TypeInfo(TArray<TValue>), ADelivery,
    IInterface(Pointer(@AHandler)^), AMainSyncTimeoutMs, ADebounceMs);
end;

function TChannelBus.Subscribe(const AChannel: string; ADelivery: TChannelDelivery;
  const AHandler: TChannelHandlerJson; AMainSyncTimeoutMs: Cardinal; ADebounceMs: Cardinal): IChannelSubscription;
begin
  Result := SubscribeBoxed(AChannel, System.TypeInfo(IDocDict), ADelivery,
    IInterface(Pointer(@AHandler)^), AMainSyncTimeoutMs, ADebounceMs);
end;

type
  // İç kullanım (yalnızca bu implementation bölümünde): SynchronizeWithTimeout'un
  // ForceQueue'lanmış closure'ı ile onu bekleyen çağıran arasında GÜVENLİ paylaşılan
  // bir TEvent — ref-counted (interface) olduğu için WaitFor timeout ile dönse bile
  // closure daha sonra çalışıp SetEvent çağırdığında zaten-Free-edilmiş bir nesneye
  // erişme (AV) riski YOKTUR: nesne, HER İKİ tarafın da referansını bıraktığı anda
  // (hangisi son olursa) otomatik serbest kalır.
  IEventRef = interface
    ['{6C1E9F02-6F4E-4C0B-A123-9E8B7C6D5E4F}']
    function GetEvent: TEvent;
  end;

  TEventRef = class(TInterfacedObject, IEventRef)
  strict private
    FEvent: TEvent;
  public
    constructor Create;
    destructor Destroy; override;
    function GetEvent: TEvent;
  end;

constructor TEventRef.Create;
begin
  inherited Create;
  FEvent := TEvent.Create(nil, True, False, '');
end;

destructor TEventRef.Destroy;
begin
  FEvent.Free;
  inherited;
end;

function TEventRef.GetEvent: TEvent;
begin
  Result := FEvent;
end;

/// dmMainSync + zaman aşımı: TThread.Synchronize'ın timeout parametresi YOK — bu yüzden
/// ForceQueue (her zaman kuyruklar, ana thread meşgulse bile hemen döner) + kendi
/// ref-counted TEvent'imizle sınırlı süre bekliyoruz. Süre dolarsa yayıncı thread devam
/// eder; AWrapped kuyruklanmış olarak KALIR ve ana thread müsait olduğunda ÇALIŞACAKTIR
/// (geri alınamaz) — yalnızca yayıncı onu artık BEKLEMEZ.
procedure SynchronizeWithTimeout(const AWrapped: TProc; ATimeoutMs: Cardinal);
var
  LEventRef: IEventRef;
begin
  LEventRef := TEventRef.Create;
  TThread.ForceQueue(nil, TThreadProcedure(
    procedure
    begin
      // try/finally: AWrapped() hata fırlatırsa bile SetEvent GARANTİ çağrılır —
      // aksi halde yayıncı thread (ErrorIsolation=False + dmMainSync + timeout
      // kombinasyonunda) hatayı beklemeden gereksiz yere tam ATimeoutMs kadar bekliyordu.
      try
        AWrapped();
      finally
        LEventRef.GetEvent.SetEvent;
      end;
    end));
  LEventRef.GetEvent.WaitFor(ATimeoutMs);
end;

procedure TChannelBus.DispatchOne(const AGetData: TChannelDataProvider; const ASub: IChannelSubscription;
  const AProc: TProc; ADelivery: TChannelDelivery);
var
  LWrapped       : TProc;
  LSub           : IChannelSubscriptionInternal;
  LChannel       : string;
  LOnError       : TChannelErrorHandler;
  LErrorIsolation: Boolean;
begin
  LSub := ASub as IChannelSubscriptionInternal; // interface-to-interface: her zaman güvenli
  LErrorIsolation := FErrorIsolation;
  if LErrorIsolation then
  begin
    LChannel := ASub.Channel;
    LOnError := FOnError;
  end;
  LWrapped :=
    procedure
    begin
      if LSub.BeginWork then
        try
          if not LErrorIsolation then
            AProc() // eski/çıplak davranış: try/except yok, exception olduğu gibi yükselir
          else
            try
              AProc();
            except
              on E: Exception do
                // Bir abonenin exception'ı ASLA aynı Publish çağrısındaki diğer abonelere
                // ulaşmayı engellemez (izolasyon) — burada yutulur; OnError atanmışsa
                // bildirilir (AGetData yalnızca BURADA, gerçekten hata varsa çağrılır —
                // TValue.From<T>'nin RTTI maliyeti hatasız akışa hiç yansımaz), atanmamışsa
                // (rad.cmd.pas'taki ExecuteAsync/OnError deseniyle tutarlı olarak) sessizce yutulur.
                if Assigned(LOnError) then
                  LOnError(LChannel, AGetData(), E);
            end;
        finally
          LSub.EndWork;
        end;
    end;

  // LDoDispatch: ADelivery'ye göre GERÇEK teslimatı yapan adım (dmSync/dmMainSync/
  // dmMainAsync/dmAsync case-of'u). Debounce KAPALIYSA hemen çalışır; AÇIKSA
  // LSub.ScheduleOrRun bunu "en son gelen" olarak saklayıp sessizlik süresi dolunca
  // (varsa) bir kez çalıştırır — yani debounce, NE'nin (ADelivery) değil, NE ZAMAN
  // çalışacağının önüne geçer.
  var LDoDispatch: TProc :=
    procedure
    begin
      case ADelivery of
        dmSync:
          LWrapped();
        dmMainSync:
          if TThread.CurrentThread.ThreadID = MainThreadID then
            LWrapped()
          else if LSub.GetMainSyncTimeoutMs = INFINITE then
            TThread.Synchronize(nil, TThreadProcedure(LWrapped))
          else
            SynchronizeWithTimeout(LWrapped, LSub.GetMainSyncTimeoutMs);
        dmMainAsync:
          TThread.ForceQueue(nil, TThreadProcedure(LWrapped));
        dmAsync:
          begin
            var LTimeoutMs: Cardinal;
            if FPolicy = opBlockPublisher then
              LTimeoutMs := INFINITE
            else
              LTimeoutMs := 0;
            FAsyncQueue.TryEnqueue(LWrapped, LTimeoutMs);
          end;
      end;
    end;

  LSub.ScheduleOrRun(LDoDispatch);
end;

procedure TChannelBus.Publish<T>(const AChannel: string; const AEvent: T);
var
  LChannel : string;
  LSub     : IChannelSubscription;
  LInternal: IChannelSubscriptionInternal;
  LGetData : TChannelDataProvider;
begin
  LChannel := NormalizeChannel(AChannel);
  LGetData := function: TValue begin Result := TValue.From<T>(AEvent) end;
  if GetHasBeforePublish then RunInterceptors(FBeforePublishCache, LChannel, LGetData);
  for LSub in GetMatchingSubscriptions(LChannel) do
  begin
    LInternal := LSub as IChannelSubscriptionInternal;
    if LInternal.GetTypeInfoRef = System.TypeInfo(T) then
    begin
      var LHandler := TChannelHandler<T>(LInternal.GetHandler);
      var LDelivery := LInternal.GetDelivery;
      DispatchOne(LGetData, LSub,
        procedure begin LHandler(AEvent) end,
        LDelivery);
    end;
  end;
  if GetHasAfterPublish then RunInterceptors(FAfterPublishCache, LChannel, LGetData);
end;

procedure TChannelBus.Publish<T>(const AChannel: string; const AEvent: T; ADelivery: TChannelDelivery);
var
  LChannel : string;
  LSub     : IChannelSubscription;
  LInternal: IChannelSubscriptionInternal;
  LGetData : TChannelDataProvider;
begin
  LChannel := NormalizeChannel(AChannel);
  LGetData := function: TValue begin Result := TValue.From<T>(AEvent) end;
  if GetHasBeforePublish then RunInterceptors(FBeforePublishCache, LChannel, LGetData);
  for LSub in GetMatchingSubscriptions(LChannel) do
  begin
    LInternal := LSub as IChannelSubscriptionInternal;
    if LInternal.GetTypeInfoRef = System.TypeInfo(T) then
    begin
      var LHandler := TChannelHandler<T>(LInternal.GetHandler);
      DispatchOne(LGetData, LSub,
        procedure begin LHandler(AEvent) end,
        ADelivery); // abonenin kendi delivery'si yerine bu çağrının delivery'si geçerli (NX.Horizon Send<T> deseni)
    end;
  end;
  if GetHasAfterPublish then RunInterceptors(FAfterPublishCache, LChannel, LGetData);
end;

procedure TChannelBus.Publish(const AChannel: string; const AArgs: TArray<TValue>);
var
  LChannel : string;
  LSub     : IChannelSubscription;
  LInternal: IChannelSubscriptionInternal;
  LGetData : TChannelDataProvider;
begin
  LChannel := NormalizeChannel(AChannel);
  LGetData := function: TValue begin Result := TValue.From<TArray<TValue>>(AArgs) end;
  if GetHasBeforePublish then RunInterceptors(FBeforePublishCache, LChannel, LGetData);
  for LSub in GetMatchingSubscriptions(LChannel) do
  begin
    LInternal := LSub as IChannelSubscriptionInternal;
    if LInternal.GetTypeInfoRef = System.TypeInfo(TArray<TValue>) then
    begin
      var LHandler := TChannelHandlerDyn(LInternal.GetHandler);
      var LDelivery := LInternal.GetDelivery;
      DispatchOne(LGetData, LSub,
        procedure begin LHandler(AArgs) end,
        LDelivery);
    end;
  end;
  if GetHasAfterPublish then RunInterceptors(FAfterPublishCache, LChannel, LGetData);
end;

procedure TChannelBus.Publish(const AChannel: string; const AArgs: TArray<TValue>; ADelivery: TChannelDelivery);
var
  LChannel : string;
  LSub     : IChannelSubscription;
  LInternal: IChannelSubscriptionInternal;
  LGetData : TChannelDataProvider;
begin
  LChannel := NormalizeChannel(AChannel);
  LGetData := function: TValue begin Result := TValue.From<TArray<TValue>>(AArgs) end;
  if GetHasBeforePublish then RunInterceptors(FBeforePublishCache, LChannel, LGetData);
  for LSub in GetMatchingSubscriptions(LChannel) do
  begin
    LInternal := LSub as IChannelSubscriptionInternal;
    if LInternal.GetTypeInfoRef = System.TypeInfo(TArray<TValue>) then
    begin
      var LHandler := TChannelHandlerDyn(LInternal.GetHandler);
      DispatchOne(LGetData, LSub,
        procedure begin LHandler(AArgs) end,
        ADelivery);
    end;
  end;
  if GetHasAfterPublish then RunInterceptors(FAfterPublishCache, LChannel, LGetData);
end;

procedure TChannelBus.Publish(const AChannel: string; const AJson: IDocDict);
var
  LChannel : string;
  LSub     : IChannelSubscription;
  LInternal: IChannelSubscriptionInternal;
  LGetData : TChannelDataProvider;
begin
  LChannel := NormalizeChannel(AChannel);
  LGetData := function: TValue begin Result := TValue.From<IDocDict>(AJson) end;
  if GetHasBeforePublish then RunInterceptors(FBeforePublishCache, LChannel, LGetData);
  for LSub in GetMatchingSubscriptions(LChannel) do
  begin
    LInternal := LSub as IChannelSubscriptionInternal;
    if LInternal.GetTypeInfoRef = System.TypeInfo(IDocDict) then
    begin
      var LHandler := TChannelHandlerJson(LInternal.GetHandler);
      var LDelivery := LInternal.GetDelivery;
      DispatchOne(LGetData, LSub,
        procedure begin LHandler(AJson) end,
        LDelivery);
    end;
  end;
  if GetHasAfterPublish then RunInterceptors(FAfterPublishCache, LChannel, LGetData);
end;

procedure TChannelBus.Publish(const AChannel: string; const AJson: IDocDict; ADelivery: TChannelDelivery);
var
  LChannel : string;
  LSub     : IChannelSubscription;
  LInternal: IChannelSubscriptionInternal;
  LGetData : TChannelDataProvider;
begin
  LChannel := NormalizeChannel(AChannel);
  LGetData := function: TValue begin Result := TValue.From<IDocDict>(AJson) end;
  if GetHasBeforePublish then RunInterceptors(FBeforePublishCache, LChannel, LGetData);
  for LSub in GetMatchingSubscriptions(LChannel) do
  begin
    LInternal := LSub as IChannelSubscriptionInternal;
    if LInternal.GetTypeInfoRef = System.TypeInfo(IDocDict) then
    begin
      var LHandler := TChannelHandlerJson(LInternal.GetHandler);
      DispatchOne(LGetData, LSub,
        procedure begin LHandler(AJson) end,
        ADelivery);
    end;
  end;
  if GetHasAfterPublish then RunInterceptors(FAfterPublishCache, LChannel, LGetData);
end;

function TChannelBus.SubscriberCount(const AChannel: string): Integer;
var
  LList: TSubscriberList;
begin
  // TryGetList — GetOrCreateList DEĞİL: sadece sayıya bakmak için bile kalıcı boş
  // liste oluşturmaya gerek yok.
  if TryGetList(NormalizeChannel(AChannel), LList) then
    Result := LList.Count
  else
    Result := 0;
end;

function TChannelBus.Channels: TArray<string>;
begin
  FLock.BeginRead;
  try
    Result := FChannels.Keys.ToArray;
  finally
    FLock.EndRead;
  end;
end;

function TChannelBus.WildcardPatterns: TArray<string>;
var
  LSub  : IChannelSubscription;
  LList : TList<string>;
begin
  LList := TList<string>.Create;
  try
    for LSub in FWildcardSubs.SnapshotAndCompact do
      LList.Add(LSub.Channel);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TChannelBus.TotalSubscriberCount: Integer;
var
  LList: TSubscriberList;
begin
  Result := FWildcardSubs.Count;
  FLock.BeginRead;
  try
    for LList in FChannels.Values do
      Result := Result + LList.Count;
  finally
    FLock.EndRead;
  end;
end;

procedure TChannelBus.UnsubscribeChannel(const AChannel: string);
var
  LChannel: string;
begin
  LChannel := NormalizeChannel(AChannel);
  FLock.BeginWrite;
  try
    FChannels.Remove(LChannel); // TObjectDictionary([doOwnsValues]) TSubscriberList'i Free eder
  finally
    FLock.EndWrite;
  end;
end;

function TChannelBus.DroppedCount: Integer;
begin
  Result := FAsyncQueue.DroppedCount;
end;

procedure TChannelBus.AddBeforePublish(const AInterceptor: TChannelInterceptor);
begin
  FInterceptorLock.BeginWrite;
  try
    FBeforePublish.Add(AInterceptor);
    // Cache yalnızca burada (Add'de) yeniden oluşturulur — kaldırma desteklenmediği
    // için RunInterceptors'ın her Publish'te TList.ToArray ile yeni dizi ayırmasına
    // gerek yok, doğrudan bu diziyi referans olarak okuyabilir.
    FBeforePublishCache := FBeforePublish.ToArray;
  finally
    FInterceptorLock.EndWrite;
  end;
  TInterlocked.Exchange(FHasBeforePublishInt, 1);
end;

procedure TChannelBus.AddAfterPublish(const AInterceptor: TChannelInterceptor);
begin
  FInterceptorLock.BeginWrite;
  try
    FAfterPublish.Add(AInterceptor);
    FAfterPublishCache := FAfterPublish.ToArray;
  finally
    FInterceptorLock.EndWrite;
  end;
  TInterlocked.Exchange(FHasAfterPublishInt, 1);
end;

procedure TChannelBus.RunInterceptors(const ACache: TArray<TChannelInterceptor>; const AChannel: string;
  const AGetData: TChannelDataProvider);
var
  LSnapshot   : TArray<TChannelInterceptor>;
  LInterceptor: TChannelInterceptor;
  LData       : TValue;
begin
  FInterceptorLock.BeginRead;
  try
    LSnapshot := ACache; // TArray ataması referans/refcount kopyasıdır, allocation yok
  finally
    FInterceptorLock.EndRead;
  end;
  if Length(LSnapshot) = 0 then Exit;

  LData := AGetData(); // yalnızca burada, en az bir interceptor varken hesaplanıyor
  for LInterceptor in LSnapshot do
    if not FErrorIsolation then
      LInterceptor(AChannel, LData)
    else
      try
        LInterceptor(AChannel, LData);
      except
        // Bir interceptor'ın hatası ne dispatch'i ne de diğer interceptor'ları engeller —
        // OnError'a bildirilmez (interceptor'lar handler değil, gözlemci/middleware'dir);
        // isteyen interceptor kendi içinde loglama yapabilir.
      end;
end;

{ Fabrika fonksiyonları }

var
  GChannelBus    : TChannelBus;
  GChannelBusLock: TLightweightMREW;

function CreateChannelBus(AOverflowPolicy: TOverflowPolicy; AQueueDepth: Integer; AErrorIsolation: Boolean): TChannelBus;
begin
  Result := TChannelBus.Create(AOverflowPolicy, AQueueDepth, AErrorIsolation);
end;

function ChannelBus: TChannelBus;
begin
  GChannelBusLock.BeginRead;
  try
    if Assigned(GChannelBus) then
    begin
      Result := GChannelBus;
      Exit;
    end;
  finally
    GChannelBusLock.EndRead;
  end;

  GChannelBusLock.BeginWrite;
  try
    if not Assigned(GChannelBus) then
      GChannelBus := TChannelBus.Create;
    Result := GChannelBus;
  finally
    GChannelBusLock.EndWrite;
  end;
end;

initialization

finalization
  FreeAndNil(GChannelBus);
end.
