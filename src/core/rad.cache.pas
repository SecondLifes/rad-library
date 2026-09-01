unit rad.cache;

{ TValue geçişi (2026-07-22): TSmartParam ve TSmartParamKind KALDIRILDI.
  Değerler artık doğrudan System.Rtti.TValue olarak saklanıyor — tip bilgisi
  TValue'nun kendi içinde (Kind + TypeInfo), ayrı bir tip alanı yok.

  Kaldırılanların karşılıkları:
    TSmartParam.New(x)        -> doğrudan değer (TValue implicit) veya TValue.From<T>(x)
    TSmartParam.AsObj<T>      -> Cache.Get<T>('k', nil)        (yanlış sınıfta nil döner)
    TSmartParam.AsIntf<T>     -> Cache.GetIntf<T>('k')         (GUID/Supports tabanlı)
    TSmartParam.TryAsXxx      -> Cache.TryGet<T>('k', out V)   (exception'sız, tip-katı)
    Kind/vType                -> TValue.Kind / TValue.TypeInfo
    Variant overload'ları     -> TValue.FromVariant(V)

  DAVRANIŞ DEĞİŞİKLİĞİ (bilinçli): Variant'ın hoşgörülü dönüşümleri yok —
  '42' string'i Get('k', 0) ile 42 OKUNMAZ; tip uyuşmazlığı = bulunamadı
  sayılır ve default döner. Bir cache için katı tip sözleşmesi tercih edildi. }

interface

uses
  SysUtils, Classes,
  System.Rtti, System.TypInfo,
  System.SyncObjs, // TLightweightMREW için (RTL; eski mormot TRWLock bağımlılığı kaldırıldı)
  Generics.Collections
  ,mormot.core.json
  ,rad.core;

type



  // AOld: önceki değer (anahtar yoksa TValue.Empty), ANew: yazılmak istenen değer.
  // False dönerse yazma iptal edilir.
  //TParamChangeEvent     = TFunc<string, TValue, TValue, Boolean>;
  //TSmartCacheErrorEvent = procedure(const AKey: string; const AError: Exception) of object;

  // AOld: önceki değer (anahtar yoksa TValue.Empty), ANew: yazılmak istenen değer.
  // False dönerse yazma iptal edilir.
  TParamChangeEvent     = TFunc<string, TValue, TValue, Boolean>;
  TSmartCacheErrorEvent = procedure(const AKey: string; const AError: Exception) of object;

  /// SaveJson/LoadJson hataları (geçersiz JSON, tanınmayan tip etiketi, sürüm
  /// uyuşmazlığı, dosya okuma/yazma).
  ESmartCacheJson = class(Exception);
  ESmartCacheAutoSave = class(ESmartCacheJson);

    { ISmartCache — cache'in soyutlaması (DI/test için constructor'a bunu geçin).

    Delphi interface'leri generic metot taşıyamadığından Get<T>/TryGet<T>/
    GetIntf<T> burada YOKTUR; interface üzerinden generic erişim için
    TSmartCacheView kullanılır (aşağıda):

      var Cache: ISmartCache := NewSmartCache;   // ARC — Free yok
      Liste := TSmartCacheView(Cache).Get<TStringList>('k', nil);

    YAŞAM SÜRESİ KURALI: Bir örneği YA ISmartCache olarak tutun (ARC serbest
    bırakır) YA DA TSmartCache sınıf referansı olarak tutup Free edin —
    ikisini AYNI örnek üzerinde KARIŞTIRMAYIN (çifte serbest bırakma riski). }

  IValueGetSet = interface
    ['{19448353-49B7-4C61-95C3-CB943CAE83EA}']

    function Get(const AKey: string; const ADefault: Integer)   : Integer;   overload;
    function Get(const AKey: string; const ADefault: Double)    : Double;    overload;
    function Get(const AKey: string; const ADefault: string)    : string;    overload;
    function Get(const AKey: string; const ADefault: Boolean)   : Boolean;   overload;
    function Get(const AKey: string; const ADefault: TDateTime) : TDateTime; overload;

  end;

  ISmartCache = interface(IValueGetSet)
    ['{E46AC9F0-DEC5-4478-9464-3B800DE90F5C}']
    function GetGlobalEvent: TParamChangeEvent;
    procedure SetGlobalEvent(const AValue: TParamChangeEvent);
    function GetOnError: TSmartCacheErrorEvent;
    procedure SetOnError(const AValue: TSmartCacheErrorEvent);
    function GetAutoSave: Boolean;
    procedure SetAutoSave(const AValue: Boolean);
    function GetAutoSaveDelaySeconds: Cardinal;
    procedure SetAutoSaveDelaySeconds(const AValue: Cardinal);
    function GetSaveFileName: string;
    procedure SetSaveFileName(const AValue: string);

    function AddOrSet(const AKey: string; const V: TValue): Boolean; overload;
    function AddOrSet(const AKey: string; const V: IInterface): Boolean; overload;



    function GetValue(const AKey: string; const ADefault: TValue): TValue;
    function TryGetValue(const AKey: string; out AValue: TValue): Boolean;

    function GetOrAdd(const AKey: string; const AValue: TValue): TValue; overload;
    function GetOrAdd(const AKey: string; const AFactory: TFunc<TValue>): TValue; overload;

    function ContainsKey(const AKey: string): Boolean;
    function Remove(const AKey: string): Boolean;
    procedure Clear;
    function Count: Integer;
    function Keys: TArray<string>;

    /// <summary>
    ///   Bir bolumun anahtarlarini ONEK SOYULMUS hâlde dondurur.
    ///   Section='aile' -> 'aile.baba' anahtari 'baba' olarak doner.
    /// </summary>
    /// <remarks>
    ///   Duzlestirme yol erisimini yok eder (olculdu: help.mormot testi
    ///   32-34; GetValueByPath duzlestirmeden sonra bos doner). Bu metot
    ///   "bana su bolumu ver"i duz sozlukte geri kazandirir - belgeyi
    ///   yeniden ic ice yapmaya gerek kalmadan.
    /// </remarks>
    function SectionKeys(const ASection: string): TArray<string>;

    /// <summary>
    ///   Bir JSON belgesini (DocVariant) TEK anahtar altinda saklar.
    ///   KOPYA olarak saklanir: cagiranin elindeki belgeyi sonradan
    ///   degistirmek cache'i etkilemez.
    /// </summary>
    function SetDoc(const AKey: string; const ADoc: Variant): Boolean;
    /// <summary>
    ///   Saklanan belgenin KOPYASINI dondurur. Anahtar yoksa ya da deger bir
    ///   belge degilse False.
    /// </summary>
    function GetDoc(const AKey: string; out ADoc: Variant): Boolean;

    procedure RegisterEvent   (const AKey: string; const AEvent: TParamChangeEvent);
    function  UnregisterEvent (const AKey: string; const AEvent: TParamChangeEvent): Boolean;
    procedure UnregisterEvents(const AKey: string);
    procedure ForEach(const AProc: TProc<string, TValue>);

    /// <summary>Cache değerlerini uzantıya göre atomik olarak kaydeder.</summary>
    /// <exception cref="ESmartCacheJson">Biçim/değer desteklenmiyorsa veya ACipher=True ise.</exception>
    procedure FileSave(AFileName: string = ''; const ACipher: Boolean = False);
    /// <summary>JSON/YAML/XML dosyasını yükler; hatada OnError çağırıp False döner.</summary>
    function FileLoad(const AFileName: string = '';  AClearFirst: Boolean = True): Boolean;

    property OnGlobalChange: TParamChangeEvent     read GetGlobalEvent write SetGlobalEvent;
    property OnError       : TSmartCacheErrorEvent read GetOnError     write SetOnError;
    property AutoSave: Boolean read GetAutoSave write SetAutoSave;
    property AutoSaveDelaySeconds: Cardinal read GetAutoSaveDelaySeconds  write SetAutoSaveDelaySeconds;
    property SaveFileName: string read GetSaveFileName write SetSaveFileName;
  end;


  // NOT: TObject değerleri cache tarafından SAHİPLENİLMEZ. Çağıran, nesnenin
  // ömrünü cache'ten bağımsız yönetmelidir (mimari karar — bkz. rad.cache.md).
  // Interface değerleri ise TValue içinde referans sayımıyla canlı tutulur.
  TSmartCache = class(TAbstractLockable, ISmartCache)
  const
   FileTypes: array [0..3] of string = ('.json', '.yml', '.yaml', '.xml');
   FileVersion = 1;
   MinAutoSaveDelaySeconds = 5;
   MaxAutoSaveDelaySeconds = 10;
   DefaultAutoSaveDelaySeconds = 5;

  private
    FDic        : TDictionary<string, TValue>;
    FDicEvents  : TObjectDictionary<string, TList<TParamChangeEvent>>;
    FGlobalEvent: TParamChangeEvent;
    // TLightweightMREW: RTL'nin hafif okuyucu-yazıcı kilidi (OS SRW tabanlı,
    // record — Free gerekmez). mormot.core.os.TRWLock'ın yerine geçti: bu
    // makinede mormot kaynağı bulunmadığından ve RTL karşılığı birebir aynı
    // işi gördüğünden dış bağımlılık bilinçli olarak kaldırıldı (2026-07-22).
    // DİKKAT: yeniden-girişli (reentrant) DEĞİLDİR — kilit altındaki kod aynı
    // cache'e geri çağrı yapmamalıdır (FireEvents zaten kilit DIŞINDA çalışır).


    FOnError      : TSmartCacheErrorEvent;
    FSaveFileName: string;
    FAutoSaveLock: TCriticalSection;
    FFileSaveLock: TCriticalSection;
    FAutoSaveThread: TThread;
    FAutoSaveEnabled: Boolean;
    FAutoSaveDelaySeconds: Cardinal;
    FAutoSavePending: Integer;
    class var FCache: ISmartCache;


    function GetGlobalEvent: TParamChangeEvent;
    procedure SetGlobalEvent(const AValue: TParamChangeEvent);
    function GetOnError: TSmartCacheErrorEvent;
    procedure SetOnError(const AValue: TSmartCacheErrorEvent);
    function GetAutoSave: Boolean;
    procedure SetAutoSave(const AValue: Boolean);
    function GetAutoSaveDelaySeconds: Cardinal;
    procedure SetAutoSaveDelaySeconds(const AValue: Cardinal);
    function GetSaveFileName: string;
    procedure SetSaveFileName(const AValue: string);
    procedure ScheduleAutoSave;
    function PerformAutoSave: Boolean;
    procedure StopAutoSave(const AFlushPending: Boolean);

    class function ValuesEqual(const A, B: TValue): Boolean; static;
    function FireEvents(const AKey: string; const AOld, ANew: TValue): Boolean;

    /// FileLoad yardimcisi. (ApplyFlatDoc BILEREK burada DEGIL: imzasi
    /// IDocDict isterdi ve bu, mORMot'u bu birimin ARAYUZ bagimliligi
    /// yapardi. Implementation bolumunde birim-yerel bir fonksiyon olarak
    /// duruyor - Delphi'de ayni birimin kodu private uyelere erisebilir.)
    procedure ReportError(const AKey: string; const AError: Exception);
  public
    constructor Create(const AThreadSafe: Boolean = True); override;
    destructor Destroy; override;

    // Çekirdek yazma. Integer/string/Double/Boolean/Int64/TObject/TDateTime
    // argümanları TValue'nun kendi Implicit operatörleriyle otomatik sarılır
    // (TDateTime, Extended olarak saklanır; Get<TDateTime> float-ailesi
    // dönüşümüyle sorunsuz okur).
    // NOT: Ayrı bir AddOrSet(TDateTime) overload'ı BİLİNÇLİ olarak yok —
    // derleyici, yerleşik Integer→TDateTime dönüşümünü kullanıcı-tanımlı
    // Integer→TValue implicit'ine tercih ettiğinden böyle bir overload tüm
    // Integer yazımlarını kaçırıyordu (testle yakalandı, 2026-07-22).
    function AddOrSet(const AKey: string; const V: TValue): Boolean; overload;
    // IInterface için Implicit operatör yok; From<IInterface> ile sarılır.
    // Somut arayüz tipini korumak isteyen çağıran TValue.From<IMyIntf>(x) geçebilir.
    function AddOrSet(const AKey: string; const V: IInterface): Boolean; overload;

    // Tip-katı generic okuma: anahtar yoksa VEYA saklanan değer T'ye
    // dönüştürülemiyorsa ADefault döner. Nesnelerde sınıf uyumu kontrol edilir —
    // yanlış sınıf istenirse default (tipik olarak nil) döner.
    function Get<T>(const AKey: string; const ADefault: T): T; overload;

    // Eski Get overload yüzeyi (çağıran kodun değişmeden derlenmesi için).
    function Get(const AKey: string; const ADefault: Integer):   Integer;   overload;
    function Get(const AKey: string; const ADefault: Double):    Double;    overload;
    function Get(const AKey: string; const ADefault: string):    string;    overload;
    function Get(const AKey: string; const ADefault: Boolean):   Boolean;   overload;
    function Get(const AKey: string; const ADefault: TDateTime): TDateTime; overload;

    // Ham TValue okuma (dönüşümsüz).
    function GetValue(const AKey: string; const ADefault: TValue): TValue;

    // Arayüz okuma: saklanan interface'ten T'nin GUID'i Supports ile sorgulanır
    // (TValue'nun arayüz-arası dönüşüm davranışına bağımlı kalınmaz).
    function GetIntf<T: IInterface>(const AKey: string): T;

    // Exception'sız, tip-katı okuma: yoksa/uymazsa False, AValue Default(T) kalır.
    function TryGet<T>(const AKey: string; out AValue: T): Boolean;
    function TryGetValue(const AKey: string; out AValue: TValue): Boolean;

    function GetOrAdd(const AKey: string; const AValue: TValue): TValue; overload;
    // YENİ: tembel üretim — değer yalnız anahtar yoksa üretilir.
    // DİKKAT: factory yazma kilidi ALTINDA çalışır; hafif olmalı ve içinden
    // aynı cache'e ERİŞMEMELİDİR (kilit yeniden-girişine güvenilmez).
    function GetOrAdd(const AKey: string; const AFactory: TFunc<TValue>): TValue; overload;

    function ContainsKey(const AKey: string): Boolean;
    function Remove(const AKey: string): Boolean;
    procedure Clear;
    function Count: Integer;
    // YENİ: anahtarların anlık kopyası (kilit altında alınır, sonra serbest gezilir).
    function Keys: TArray<string>;
    function SectionKeys(const ASection: string): TArray<string>;
    function SetDoc(const AKey: string; const ADoc: Variant): Boolean;
    function GetDoc(const AKey: string; out ADoc: Variant): Boolean;

    procedure RegisterEvent   (const AKey: string; const AEvent: TParamChangeEvent);
    function  UnregisterEvent (const AKey: string; const AEvent: TParamChangeEvent): Boolean;
    procedure UnregisterEvents(const AKey: string);
    procedure ForEach(const AProc: TProc<string, TValue>);


    /// <summary>Cache değerlerini uzantıya göre atomik olarak kaydeder.</summary>
    /// <exception cref="ESmartCacheJson">Biçim/değer desteklenmiyorsa veya ACipher=True ise.</exception>
    procedure FileSave(AFileName: string = ''; const ACipher: Boolean = False);

    /// <summary>JSON nesnesini noktalı cache anahtarlarına dönüştürür.</summary>
    /// <returns>Olay dinleyicilerinin reddettiği değer sayısı.</returns>
    /// <exception cref="ESmartCacheJson">JSON bozuksa, kök nesne değilse veya değer desteklenmiyorsa.</exception>
    function LoadJson(const AJson: string;
      const AClearFirst: Boolean = True): Integer;
    /// <summary>JSON/YAML/XML dosyasını yükler; hatada OnError çağırıp False döner.</summary>
    function FileLoad(const AFileName: string = '';
      AClearFirst: Boolean = True): Boolean;


    property AutoSave: Boolean read GetAutoSave write SetAutoSave;
    property AutoSaveDelaySeconds: Cardinal read GetAutoSaveDelaySeconds
      write SetAutoSaveDelaySeconds;
    property SaveFileName: string read GetSaveFileName write SetSaveFileName;
    property OnGlobalChange: TParamChangeEvent     read GetGlobalEvent write SetGlobalEvent;
    property OnError       : TSmartCacheErrorEvent read GetOnError     write SetOnError;
  end;

  // ISmartCache üzerinden generic erişim görünümü. Record olduğu için generic
  // metot taşıyabilir; cache'e yalnız interface referansıyla dokunur.
  // Kullanım: TSmartCacheView(Cache).Get<TStringList>('k', nil)
  TSmartCacheView = record
  private
    FCache: ISmartCache;
  public
    class operator Implicit(const ACache: ISmartCache): TSmartCacheView; inline;

    function Get<T>(const AKey: string; const ADefault: T): T;
    function TryGet<T>(const AKey: string; out AValue: T): Boolean;
    function GetIntf<T: IInterface>(const AKey: string): T;

    property Cache: ISmartCache read FCache;
  end;




// Fabrika: ARC yaşam süresiyle kullanım için önerilen kuruluş yolu.
function NewSmartCache(const AThreadSafe: Boolean = True): ISmartCache;
function Cache    : ISmartCache;


implementation

uses
  StrUtils,
  Variants,
  help.mormot,          // TMormot.Flatten - ic ice belgeyi noktali anahtarlara indirger
  mormot.core.data,     // TDocVariantKind (dvObject)
  mormot.core.base,
  mormot.core.unicode,
  mormot.core.text,
  mormot.core.rtti,
  mormot.core.variants, // TDocVariantData ve JSON ayrıştırma seçenekleri
  mormot.core.os,
  mormot.core.fmt,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,       // MoveFileEx — atomik, üzerine yazan dosya taşıma
  {$ENDIF}
  System.IOUtils;       // SaveToFile/LoadFromFile

type
  TSmartCacheAutoSaveThread = class(TThread)
  private
    FCache: TSmartCache;
    FDelayMilliseconds: Integer;
    FGeneration: Integer;
    FWakeEvent: TEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(ACache: TSmartCache);
    destructor Destroy; override;
    procedure Schedule(ADelayMilliseconds: Cardinal);
    procedure Stop;
  end;


{ TSmartCacheAutoSaveThread }

constructor TSmartCacheAutoSaveThread.Create(ACache: TSmartCache);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FCache := ACache;
  FWakeEvent := TEvent.Create(nil, False, False, '');
end;

destructor TSmartCacheAutoSaveThread.Destroy;
begin
  inherited Destroy;
  FreeAndNil(FWakeEvent);
end;

procedure TSmartCacheAutoSaveThread.Execute;
const
  CMaxRetryCount = 3;
  CRetryDelayMilliseconds = 1000;
var
  LGeneration: Integer;
  LRetryCount: Integer;
  LWaitResult: TWaitResult;
begin
  TThread.NameThreadForDebugging('RAD SmartCache AutoSave');
  while not Terminated do
  begin
    if FWakeEvent.WaitFor(INFINITE) <> wrSignaled then
      Continue;
    if Terminated then
      Break;

    repeat
      LGeneration := TInterlocked.CompareExchange(FGeneration, 0, 0);
      LWaitResult := FWakeEvent.WaitFor(
        Cardinal(TInterlocked.CompareExchange(FDelayMilliseconds, 0, 0)));
      if Terminated then
        Exit;
    until (LWaitResult = wrTimeout) and
      (LGeneration = TInterlocked.CompareExchange(FGeneration, 0, 0));

    LRetryCount := 0;
    while not Terminated do
    begin
      if FCache.PerformAutoSave then
        Break;
      Inc(LRetryCount);
      if LRetryCount >= CMaxRetryCount then
        Break;
      if FWakeEvent.WaitFor(CRetryDelayMilliseconds) = wrSignaled then
      begin
        FWakeEvent.SetEvent;
        Break;
      end;
    end;
  end;
end;

procedure TSmartCacheAutoSaveThread.Schedule(ADelayMilliseconds: Cardinal);
begin
  TInterlocked.Exchange(FDelayMilliseconds, Integer(ADelayMilliseconds));
  TInterlocked.Increment(FGeneration);
  FWakeEvent.SetEvent;
end;

procedure TSmartCacheAutoSaveThread.Stop;
begin
  Terminate;
  FWakeEvent.SetEvent;
end;


function NewSmartCache(const AThreadSafe: Boolean): ISmartCache;
begin
  Result := TSmartCache.Create(AThreadSafe);
end;

function Cache  :ISmartCache;
 begin
  if TSmartCache.FCache = nil then
   TSmartCache.FCache := rad.Cache.NewSmartCache(True);
  Result:=TSmartCache.FCache;
 end;



{ TSmartCacheView }

class operator TSmartCacheView.Implicit(const ACache: ISmartCache): TSmartCacheView;
begin
  Result.FCache := ACache;
end;

function TSmartCacheView.Get<T>(const AKey: string; const ADefault: T): T;
var
  LVal: TValue;
begin
  // Sınıftaki Get<T> ile aynı sözleşme: yoksa/boşsa/uymuyorsa default.
  if not (Assigned(FCache) and FCache.TryGetValue(AKey, LVal) and
          (not LVal.IsEmpty) and LVal.TryAsType<T>(Result)) then
    Result := ADefault;
end;

function TSmartCacheView.TryGet<T>(const AKey: string; out AValue: T): Boolean;
var
  LVal: TValue;
begin
  Result := Assigned(FCache) and FCache.TryGetValue(AKey, LVal) and
            (not LVal.IsEmpty) and LVal.TryAsType<T>(AValue);
  if not Result then
    AValue := Default(T);
end;

function TSmartCacheView.GetIntf<T>(const AKey: string): T;
var
  LVal     : TValue;
  LTypeInfo: PTypeInfo;
  LTypeData: PTypeData;
begin
  Result := Default(T);
  if not (Assigned(FCache) and FCache.TryGetValue(AKey, LVal) and
          (LVal.Kind = tkInterface)) then
    Exit;

  LTypeInfo := System.TypeInfo(T);
  if (LTypeInfo <> nil) and (LTypeInfo.Kind = tkInterface) then
  begin
    LTypeData := GetTypeData(LTypeInfo);
    if LTypeData <> nil then
      Supports(LVal.AsInterface, LTypeData.Guid, Result);
  end;
end;

{ TSmartCache }

constructor TSmartCache.Create(const AThreadSafe: Boolean);
begin
  inherited Create(AThreadSafe);
  FAutoSaveLock := TCriticalSection.Create;
  try
    FFileSaveLock := TCriticalSection.Create;
    try
      FDic := TDictionary<string, TValue>.Create;
      try
        FDicEvents := TObjectDictionary<string, TList<TParamChangeEvent>>.Create(
          [doOwnsValues]);
      except
        FreeAndNil(FDic);
        raise;
      end;
    except
      FreeAndNil(FFileSaveLock);
      raise;
    end;
  except
    FreeAndNil(FAutoSaveLock);
    raise;
  end;
  FAutoSaveDelaySeconds := DefaultAutoSaveDelaySeconds;
  {$IFDEF MSWINDOWS}
   FSaveFileName  := ChangeFileExt(ParamStr(0),'.json');  //TPath.GetAppPath+
  {$ENDIF}
  {$IFDEF POSIX}

  {$ENDIF}
end;

destructor TSmartCache.Destroy;
begin
  if Assigned(FAutoSaveLock) then
    StopAutoSave(True);
  FreeAndNil(FDicEvents);
  FreeAndNil(FDic);
  FreeAndNil(FFileSaveLock);
  FreeAndNil(FAutoSaveLock);
  // FLock (TLightweightMREW) record — Free gerekmez

  inherited Destroy;
end;

function TSmartCache.GetGlobalEvent: TParamChangeEvent;
begin
  ReadLock;
  try
    Result := FGlobalEvent;
  finally
    ReadUnlock;
  end;
end;

procedure TSmartCache.SetGlobalEvent(const AValue: TParamChangeEvent);
begin
  WriteLock;
  try
    FGlobalEvent := AValue;
  finally
    WriteUnlock;
  end;
end;

function TSmartCache.GetOnError: TSmartCacheErrorEvent;
begin
  ReadLock;
  try
    Result := FOnError;
  finally
    ReadUnlock;
  end;
end;

procedure TSmartCache.SetOnError(const AValue: TSmartCacheErrorEvent);
begin
  WriteLock;
  try
    FOnError := AValue;
  finally
    WriteUnlock;
  end;
end;

function TSmartCache.GetAutoSave: Boolean;
begin
  FAutoSaveLock.Enter;
  try
    Result := FAutoSaveEnabled;
  finally
    FAutoSaveLock.Leave;
  end;
end;

procedure TSmartCache.SetAutoSave(const AValue: Boolean);
var
  LThread: TSmartCacheAutoSaveThread;
begin
  if not AValue then
  begin
    StopAutoSave(True);
    Exit;
  end;

  if not IsThreadSafe then
    raise ESmartCacheAutoSave.Create(
      'AutoSave yalnız thread-safe oluşturulan TSmartCache üzerinde etkinleştirilebilir.');

  FAutoSaveLock.Enter;
  try
    if FAutoSaveEnabled then
      Exit;
    LThread := TSmartCacheAutoSaveThread.Create(Self);
    try
      FAutoSaveThread := LThread;
      FAutoSaveEnabled := True;
      LThread.Start;
      LThread := nil;
    finally
      if Assigned(LThread) then
      begin
        FAutoSaveThread := nil;
        FAutoSaveEnabled := False;
        LThread.Free;
      end;
    end;
  finally
    FAutoSaveLock.Leave;
  end;
end;

function TSmartCache.GetAutoSaveDelaySeconds: Cardinal;
begin
  FAutoSaveLock.Enter;
  try
    Result := FAutoSaveDelaySeconds;
  finally
    FAutoSaveLock.Leave;
  end;
end;

procedure TSmartCache.SetAutoSaveDelaySeconds(const AValue: Cardinal);
begin
  if (AValue < MinAutoSaveDelaySeconds) or
     (AValue > MaxAutoSaveDelaySeconds) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'AutoSaveDelaySeconds %d ile %d arasında olmalıdır.',
      [MinAutoSaveDelaySeconds, MaxAutoSaveDelaySeconds]);

  FAutoSaveLock.Enter;
  try
    FAutoSaveDelaySeconds := AValue;
    if FAutoSaveEnabled and Assigned(FAutoSaveThread) and
       (TInterlocked.CompareExchange(FAutoSavePending, 0, 0) <> 0) then
      TSmartCacheAutoSaveThread(FAutoSaveThread).Schedule(AValue * 1000);
  finally
    FAutoSaveLock.Leave;
  end;
end;

function TSmartCache.GetSaveFileName: string;
begin
  ReadLock;
  try
    Result := FSaveFileName;
  finally
    ReadUnlock;
  end;
end;

procedure TSmartCache.SetSaveFileName(const AValue: string);
begin
  WriteLock;
  try
    FSaveFileName := AValue;
  finally
    WriteUnlock;
  end;
end;

procedure TSmartCache.ScheduleAutoSave;
var
  LDelayMilliseconds: Cardinal;
begin
  FAutoSaveLock.Enter;
  try
    if not FAutoSaveEnabled or not Assigned(FAutoSaveThread) then
      Exit;
    TInterlocked.Exchange(FAutoSavePending, 1);
    LDelayMilliseconds := FAutoSaveDelaySeconds * 1000;
    TSmartCacheAutoSaveThread(FAutoSaveThread).Schedule(LDelayMilliseconds);
  finally
    FAutoSaveLock.Leave;
  end;
end;

function TSmartCache.PerformAutoSave: Boolean;
begin
  if TInterlocked.Exchange(FAutoSavePending, 0) = 0 then
    Exit(True);
  try
    FileSave(GetSaveFileName);
    Result := True;
  except
    TInterlocked.Exchange(FAutoSavePending, 1);
    Result := False;
  end;
end;

procedure TSmartCache.StopAutoSave(const AFlushPending: Boolean);
var
  LMayFlush: Boolean;
  LThread: TSmartCacheAutoSaveThread;
begin
  LThread := nil;
  FAutoSaveLock.Enter;
  try
    FAutoSaveEnabled := False;
    if Assigned(FAutoSaveThread) then
    begin
      LThread := TSmartCacheAutoSaveThread(FAutoSaveThread);
      FAutoSaveThread := nil;
    end;
  finally
    FAutoSaveLock.Leave;
  end;

  if Assigned(LThread) then
  begin
    LThread.Stop;
    LThread.WaitFor;
    FreeAndNil(LThread);
  end;

  FAutoSaveLock.Enter;
  try
    LMayFlush := not FAutoSaveEnabled;
  finally
    FAutoSaveLock.Leave;
  end;
  if AFlushPending and LMayFlush and
     (TInterlocked.CompareExchange(FAutoSavePending, 0, 0) <> 0) then
    PerformAutoSave;
end;

class function TSmartCache.ValuesEqual(const A, B: TValue): Boolean;
begin
  // Tip-farkındalıklı, exception'sız karşılaştırma. TValue'nun hazır eşitlik
  // operatörü olmadığı için kind bazında elle yazıldı.
  if A.IsEmpty or B.IsEmpty then
    Exit(A.IsEmpty and B.IsEmpty);

  if A.TypeInfo <> B.TypeInfo then
    Exit(False);

  case A.Kind of
    tkInteger, tkInt64, tkEnumeration, tkChar, tkWChar:
      Result := A.AsOrdinal = B.AsOrdinal;                     // Boolean da tkEnumeration'dır
    tkFloat:
      Result := A.AsExtended = B.AsExtended;                    // TDateTime dahil (aynı TypeInfo şartı yukarıda)
    tkUString, tkLString, tkWString, tkString:
      Result := A.AsString = B.AsString;
    tkClass:
      Result := A.AsObject = B.AsObject;                        // referans eşitliği (sahiplenmeme sözleşmesiyle tutarlı)
    tkInterface:
      Result := A.AsInterface = B.AsInterface;                  // referans eşitliği
    tkVariant:
      try
        Result := VarSameValue(A.AsVariant, B.AsVariant);
      except
        on EVariantError do
          Result := False;
      end;
  else
    // record/array/set vb.: içerik kıyası maliyetli ve bu cache'in kullanım
    // alanı dışında — farklı kabul edilir (yazma her zaman gerçekleşir).
    Result := False;
  end;
end;

function TSmartCache.FireEvents(const AKey: string;
  const AOld, ANew: TValue): Boolean;
var
  EventList   : TList<TParamChangeEvent>;
  LocalEvents : TArray<TParamChangeEvent>;
  LGlobalEvent: TParamChangeEvent;
  LOnError    : TSmartCacheErrorEvent;
  LEvent      : TParamChangeEvent;

  procedure ReportError(const AError: Exception);
  begin
    if Assigned(LOnError) then
      LOnError(AKey, AError);
  end;

begin
  Result      := True;
  LocalEvents := nil;

  ReadLock;
  try
    LGlobalEvent := FGlobalEvent;
    LOnError     := FOnError; // yarış durumu olmasın diye kilit altında kopyala

    if FDicEvents.TryGetValue(AKey, EventList) then
      LocalEvents := EventList.ToArray;
  finally
    ReadUnlock;
  end;

  if Assigned(LGlobalEvent) then
  begin
    try
      if not LGlobalEvent(AKey, AOld, ANew) then
        Exit(False);
    except
      on E: Exception do
      begin
        ReportError(E);
        Exit(False);
      end;
    end;
  end;

  for LEvent in LocalEvents do
  begin
    if not Assigned(LEvent) then
      Continue;

    try
      if not LEvent(AKey, AOld, ANew) then
        Exit(False);
    except
      on E: Exception do
      begin
        ReportError(E);
        Exit(False);
      end;
    end;
  end;
end;

function TSmartCache.AddOrSet(const AKey: string; const V: TValue): Boolean;
var
  OldValue       : TValue;
  CurrentValue   : TValue;
  HasOldValue    : Boolean;
  HasCurrentValue: Boolean;
  LChanged       : Boolean;
begin
  // İyimser eşzamanlılık (CAS): callback'ler kilit dışında çalışır; yazım
  // öncesi anlık görüntünün hâlâ geçerli olduğu doğrulanır, değilse tekrar
  // dener. Bu yüzden callback'ler yan etkisiz/idempotent olmalıdır.
  LChanged := False;
  repeat
    ReadLock;
    try
      HasOldValue := FDic.TryGetValue(AKey, OldValue);
    finally
      ReadUnlock;
    end;

    if HasOldValue and ValuesEqual(OldValue, V) then
      Exit(True);

    if not HasOldValue then
      OldValue := TValue.Empty; // "önceki değer yok" işareti — event'e Empty gider

    if not FireEvents(AKey, OldValue, V) then
      Exit(False);

    WriteLock;
    try
      HasCurrentValue := FDic.TryGetValue(AKey, CurrentValue);

      if HasCurrentValue and ValuesEqual(CurrentValue, V) then
      begin
        Result := True;
        Break;
      end;

      if (HasCurrentValue = HasOldValue) and
         ((not HasCurrentValue) or ValuesEqual(CurrentValue, OldValue)) then
      begin
        FDic.AddOrSetValue(AKey, V);
        LChanged := True;
        Result := True;
        Break;
      end;
    finally
      WriteUnlock;
    end;
  until False;
  if LChanged then
    ScheduleAutoSave;
end;

function TSmartCache.AddOrSet(const AKey: string; const V: IInterface): Boolean;
begin
  Result := AddOrSet(AKey, TValue.From<IInterface>(V));
end;

function TSmartCache.GetValue(const AKey: string; const ADefault: TValue): TValue;
begin
  ReadLock;
  try
    if not FDic.TryGetValue(AKey, Result) then
      Result := ADefault;
  finally
    ReadUnlock;
  end;
end;


function TSmartCache.Get<T>(const AKey: string; const ADefault: T): T;
var
  LVal: TValue;
  LHas: Boolean;
begin
  ReadLock;
  try
    LHas := FDic.TryGetValue(AKey, LVal);
  finally
    ReadUnlock;
  end;
  // IsEmpty koruması: TryAsType, Empty'yi "her tipe uyar" sayabilir (Delphi 11+
  // EmptyAsAnyType davranışı) — boş kayıt default'a düşmeli.
  if not (LHas and (not LVal.IsEmpty) and LVal.TryAsType<T>(Result)) then
    Result := ADefault;
end;

function TSmartCache.Get(const AKey: string; const ADefault: Integer): Integer;
begin
  Result := Get<Integer>(AKey, ADefault);
end;

function TSmartCache.Get(const AKey: string; const ADefault: Double): Double;
begin
  Result := Get<Double>(AKey, ADefault);
end;

function TSmartCache.Get(const AKey, ADefault: string): string;
begin
  Result := Get<string>(AKey, ADefault);
end;

function TSmartCache.Get(const AKey: string; const ADefault: Boolean): Boolean;
begin
  Result := Get<Boolean>(AKey, ADefault);
end;

function TSmartCache.Get(const AKey: string; const ADefault: TDateTime): TDateTime;
begin
  Result := Get<TDateTime>(AKey, ADefault);
end;

function TSmartCache.GetIntf<T>(const AKey: string): T;
var
  LVal     : TValue;
  LHas     : Boolean;
  LTypeInfo: PTypeInfo;
  LTypeData: PTypeData;
begin
  Result := Default(T);
  ReadLock;
  try
    LHas := FDic.TryGetValue(AKey, LVal);
  finally
    ReadUnlock;
  end;
  if not (LHas and (LVal.Kind = tkInterface)) then
    Exit;

  // GUID doğrudan derleme-zamanı meta verisinden okunur (TRttiContext yükü yok);
  // Supports, saklanan arayüzden T'yi QueryInterface ile sorgular.
  LTypeInfo := System.TypeInfo(T);
  if (LTypeInfo <> nil) and (LTypeInfo.Kind = tkInterface) then
  begin
    LTypeData := GetTypeData(LTypeInfo);
    if LTypeData <> nil then
      Supports(LVal.AsInterface, LTypeData.Guid, Result);
  end;
end;

function TSmartCache.TryGet<T>(const AKey: string; out AValue: T): Boolean;
var
  LVal: TValue;
  LHas: Boolean;
begin
  ReadLock;
  try
    LHas := FDic.TryGetValue(AKey, LVal);
  finally
    ReadUnlock;
  end;
  Result := LHas and (not LVal.IsEmpty) and LVal.TryAsType<T>(AValue);
  if not Result then
    AValue := Default(T);
end;

function TSmartCache.TryGetValue(const AKey: string; out AValue: TValue): Boolean;
begin
  ReadLock;
  try
    Result := FDic.TryGetValue(AKey, AValue);
  finally
    ReadUnlock;
  end;
end;

function TSmartCache.GetOrAdd(const AKey: string; const AValue: TValue): TValue;
var
  LChanged: Boolean;
begin
  LChanged := False;
  WriteLock;
  try
    if not FDic.TryGetValue(AKey, Result) then
    begin
      FDic.Add(AKey, AValue);
      Result := AValue;
      LChanged := True;
    end;
  finally
    WriteUnlock;
  end;
  if LChanged then
    ScheduleAutoSave;
end;

function TSmartCache.GetOrAdd(const AKey: string; const AFactory: TFunc<TValue>): TValue;
var
  LChanged: Boolean;
begin
  if not Assigned(AFactory) then
    Exit(TValue.Empty);
  LChanged := False;
  WriteLock;
  try
    if not FDic.TryGetValue(AKey, Result) then
    begin
      // Factory yazma kilidi altında çalışır — bilinçli tercih: aynı anahtar
      // için "yalnız bir kez üret" garantisi verir. Bedeli: factory hafif
      // olmalı ve içinden bu cache'e erişmemelidir.
      Result := AFactory();
      FDic.Add(AKey, Result);
      LChanged := True;
    end;
  finally
    WriteUnlock;
  end;
  if LChanged then
    ScheduleAutoSave;
end;

function TSmartCache.ContainsKey(const AKey: string): Boolean;
begin
  ReadLock;
  try
    Result := FDic.ContainsKey(AKey);
  finally
    ReadUnlock;
  end;
end;

function TSmartCache.Remove(const AKey: string): Boolean;
begin
  WriteLock;
  try
    Result := FDic.ContainsKey(AKey);
    if Result then
    begin
      FDic.Remove(AKey);
      FDicEvents.Remove(AKey);
    end;
  finally
    WriteUnlock;
  end;
  if Result then
    ScheduleAutoSave;
end;

procedure TSmartCache.Clear;
var
  LChanged: Boolean;
begin
  WriteLock;
  try
    LChanged := FDic.Count > 0;
    FDic.Clear;
    FDicEvents.Clear;
  finally
    WriteUnlock;
  end;
  if LChanged then
    ScheduleAutoSave;
end;

procedure ValidateDocVariantValue(const AValue: Variant);
var
  LVariantType: TVarType;
begin
  LVariantType := VarType(AValue);
  if LVariantType = DocVariantVType then
    raise ESmartCacheJson.Create(
      'LoadJson: Düzleştirilemeyen iç içe belge değeri bulundu.');

  case LVariantType of
    varEmpty, varNull,
    varSmallint, varInteger, varShortInt, varByte, varWord, varLongWord,
    varInt64, varUInt64, varSingle, varDouble, varCurrency, varDate,
    varBoolean, varString, varOleStr, varUString:
      Exit;
  else
    raise ESmartCacheJson.CreateFmt(
      'LoadJson: Variant türü %d cache değeri olarak desteklenmiyor.',
      [LVariantType]);
  end;
end;

function TSmartCache.Count: Integer;
begin
  ReadLock;
  try
    Result := FDic.Count;
  finally
    ReadUnlock;
  end;
end;

function TSmartCache.Keys: TArray<string>;
begin
  ReadLock;
  try
    Result := FDic.Keys.ToArray;
  finally
    ReadUnlock;
  end;
end;

function TSmartCache.SectionKeys(const ASection: string): TArray<string>;
var
  LOnek: string;
  LKey : string;
  LLen : Integer;
  n    : Integer;
begin
  Result := nil;
  if ASection.Trim.IsEmpty then
    Exit(Keys);          { bolum verilmediyse tum anahtarlar }

  LOnek := ASection + '.';
  LLen  := Length(LOnek);
  n     := 0;

  { Kilit altinda YALNIZCA anlik kopya alinir; suzme disarida yapilir.
    Keys zaten kendi kilidini aldigi icin burada tekrar kilitlemiyoruz -
    bu sinifin kilidi yeniden girisli DEGIL. }
  for LKey in Keys do
    if LKey.StartsWith(LOnek) then
    begin
      SetLength(Result, n + 1);
      Result[n] := LKey.Substring(LLen);   { onek SOYULUR }
      Inc(n);
    end;
end;

function TSmartCache.SetDoc(const AKey: string; const ADoc: Variant): Boolean;
begin
  { TValue.FromVariant KULLANILMAZ - OLCULDU (rad_cachedoc A0a): ozel variant
    tiplerinde EVariantTypeCastError atiyor, cunku RTL DocVariant'i tanimiyor.
    TValue.From<Variant> ise tkVariant olarak sorunsuz tasiyor (A0b-A4).

    Semantik KOPYADIR (A6): cagiranin elindeki belgeye sonradan alan eklemek
    cache'tekini etkilemez. Ayrica AddOrSet uzerinden gectigi icin degisiklik
    olaylari da tetiklenir. }
  Result := AddOrSet(AKey, TValue.From<Variant>(ADoc));
end;

function TSmartCache.GetDoc(const AKey: string; out ADoc: Variant): Boolean;
var
  LV: TValue;
begin
  VarClear(ADoc);
  Result := TryGetValue(AKey, LV) and (LV.Kind = tkVariant);
  if Result then
    ADoc := LV.AsVariant;

  { Ic belgeye ISARETCI verilmez, deger kopyalanir. mORMot'un kendi
    ILockedDocVariant'i da ayni uyariyi tasir: "Data: PDocVariantData -
    warning: the returned result is not thread-safe" (mormot.core.threads.pas,
    ILockedDocVariant bildirimi). Isaretci vermek kilidi delerdi.

    AYRIM: AddOrSet(AKey, IDocDict) yolu PAYLASIMLIDIR (olculdu B4) - geri
    alinan arayuz uzerinden yazmak cache'i degistirir, üstelik AddOrSet'i
    atladigi icin olaylar da tetiklenmez. Paylasim isteniyorsa o yol bilincli
    secilmelidir; SetDoc/GetDoc her zaman kopyadir. }
end;

function TSmartCache.LoadJson(const AJson: string;
  const AClearFirst: Boolean = True): Integer;
var
  LDoc       : TDocVariantData;
  LWasCleared: Boolean;
  LUtf8      : RawUtf8;
  LOncekiler : TArray<TPair<string, TValue>>;   // AClearFirst ile silinenler
  LPair      : TPair<string, TValue>;
  i          : Integer;

  { Variant -> TValue donusumu. Duzlestirmenin degil, TIP SADAKATININ isi;
    o yuzden Flatten'a devredilmedi. JSON tam sayilari Int64, ondaliklar
    Double gelir ve boyle saklanir (olculdu: Get('sayi',0) = 42). }
  function ApplyScalar(const AKey: string; const AValue: Variant): Boolean;
  var
    LVariantType: TVarType;
  begin
    LVariantType := VarType(AValue);
    case LVariantType of
      varEmpty, varNull:
        Result := AddOrSet(AKey, TValue.Empty);
      varSmallint, varInteger, varShortInt, varByte, varWord, varLongWord,
      varInt64:
        Result := AddOrSet(AKey, Int64(AValue));
      varUInt64:
        Result := AddOrSet(AKey, TValue.From<UInt64>(UInt64(AValue)));
      varSingle, varDouble:
        Result := AddOrSet(AKey, Double(AValue));
      varCurrency:
        Result := AddOrSet(AKey, TValue.From<Currency>(Currency(AValue)));
      varDate:
        Result := AddOrSet(AKey, TValue.From<TDateTime>(TDateTime(AValue)));
      varBoolean:
        Result := AddOrSet(AKey, Boolean(AValue));
      varString:
        Result := AddOrSet(AKey, Utf8ToString(VariantToUtf8(AValue)));
      varOleStr, varUString:
        Result := AddOrSet(AKey, VarToStr(AValue));
    else
      { Buraya DUSULMEZ: 1. gecisteki ValidateDocVariantValue desteklenmeyen
        her turu zaten istisnaya cevirir. Yine de sessiz basari uretmemek
        icin False. }
      Result := False;
    end;
  end;

  (* Duzlestirme sonrasi geriye kalan TEK ic ice yapi BOS nesnedir - yani
     bir bolum adi verilmis ama icine hicbir ayar yazilmamis olmasi. Bunlar
     ayar tasimaz; hata degil, atlanir.

     Olculdu: help.mormot testi 09-10, Flatten bos ic nesneyi oldugu gibi
     birakir ve sonsuz donguye de girmez.

     NOT: bu yorum yildiz-parantez bicimindedir. Ilk hâli suslu parantezliydi
     ve icinde bos bir JSON nesnesi ORNEGI vardi; ornekteki kapanis susu
     yorumu erken kapatip E2038 uretti - kitin delphi-conventions.md kuralinin
     tarif ettigi tuzagin aynisi. Ayraclar artik kelimeyle anlatiliyor. *)
  function BosBelge(const AValue: Variant): Boolean;
  var
    LChild: PDocVariantData;
  begin
    Result := _Safe(AValue, LChild) and (LChild^.Count = 0);
  end;

begin
  Result := 0;

  LUtf8 := StringToUtf8(AJson);
  if not IsValidJson(LUtf8) then
    raise ESmartCacheJson.Create(
      'LoadJson: gecerli JSON uretilemedi (bozuk dosya veya donusum hatasi).');

  LDoc.InitJson(LUtf8, JSON_FAST_FLOAT);
  if LDoc.Kind <> dvObject then
    raise ESmartCacheJson.Create(
      'LoadJson: Kok deger bir JSON NESNESI olmalidir.');

  { DUZLESTIRME - tek cagri. Onceki hâlde burada ~90 satirlik elle yazilmis
    bir ozyineleme vardi (ProcessDocument); ayni isi help.mormot yapiyor ve
    kendi testleriyle (rad_jsonflatten, 34 iddia) dogrulanmis durumda.
    fcOverwrite: ayni yol iki kez olusursa son deger kazanir.
    AArrayStartIndex=0: diziler arr.0, arr.1 ... olur. }
  TMormot.Flatten(LDoc, fcOverwrite, '.', 0);

  { 1. GECIS - DOGRULAMA. Cache'e DOKUNULMAZ, boylece bozuk/desteklenmeyen
    bir deger AClearFirst=True olsa bile mevcut veriyi silemez. }
  for i := 0 to LDoc.Count - 1 do
    if not BosBelge(LDoc.Values[i]) then
      ValidateDocVariantValue(LDoc.Values[i]);

  { 2. TEMIZLIK - yalnizca DEGERLER. Clear metodu FDicEvents'i de bosaltip
    tum abonelikleri koparirdi; dosya yeniden yuklemek dinleyicileri
    dusurmemeli.

    Silinecekler ONCE fotograflanir: 3. gecisten sonra hangi anahtarlarin
    GERCEKTEN kaybolduguna bakip abonelerini haberdar edecegiz. }
  LWasCleared := False;
  LOncekiler  := nil;
  if AClearFirst then
  begin
    WriteLock;
    try
      LWasCleared := FDic.Count > 0;
      if LWasCleared then
        LOncekiler := FDic.ToArray;
      FDic.Clear;
    finally
      WriteUnlock;
    end;
  end;

  { 3. GECIS - UYGULAMA. KILIT DISINDA: AddOrSet kendi ReadLock/WriteLock'unu
    alir ve bu sinifin kilidi yeniden girisli DEGILDIR. Ayrica degisiklik
    olaylarini tetikler, yani aboneler yuklemeden haberdar olur. }
  for i := 0 to LDoc.Count - 1 do
  begin
    if BosBelge(LDoc.Values[i]) then
      Continue;
    if not ApplyScalar(Utf8ToString(LDoc.Names[i]), LDoc.Values[i]) then
      Inc(Result);   // bir dinleyici VETO etti
  end;

  { 4. SILINENLERI BILDIR.

    Onceki hâlde AClearFirst ile kaybolan anahtarlar icin HICBIR olay
    tetiklenmiyordu; yalnizca yeni yazilanlar bildiriliyordu. Yani bir
    abonenin izledigi ayar dosyadan kaldirildiginda o abone anahtarin
    kayboldugunu ASLA ogrenmiyor, elindeki son degeri gecerli sanmaya devam
    ediyordu.

    ANew = TValue.Empty "anahtar artik yok" demektir - sinifin kendi
    kullandigi isaretin aynisi (AddOrSet'te AOld icin de boyle kullaniliyor).

    FireEvents'in VETO sonucu bilincli olarak YOK SAYILIR: silme zaten
    gerceklesti, geri alinacak bir sey yok. Burasi bir izin sorusu degil,
    bir bildirim. }
  for LPair in LOncekiler do
    if not ContainsKey(LPair.Key) then
      FireEvents(LPair.Key, LPair.Value, TValue.Empty);

  if LWasCleared then
    ScheduleAutoSave;
end;

procedure TSmartCache.RegisterEvent(const AKey: string; const AEvent: TParamChangeEvent);
var
  EventList: TList<TParamChangeEvent>;
begin
  if not Assigned(AEvent) then Exit;
  WriteLock;
  try
    if not FDicEvents.TryGetValue(AKey, EventList) then
    begin
      EventList := TList<TParamChangeEvent>.Create;
      try
        FDicEvents.Add(AKey, EventList);
        EventList := nil;
      finally
        EventList.Free;
      end;
      EventList := FDicEvents[AKey];
    end;
    EventList.Add(AEvent);
  finally
    WriteUnlock;
  end;
end;

function TSmartCache.UnregisterEvent(const AKey: string; const AEvent: TParamChangeEvent): Boolean;
var
  EventList: TList<TParamChangeEvent>;
  Idx      : Integer;
begin
  Result := False;
  if not Assigned(AEvent) then Exit;
  WriteLock;
  try
    if FDicEvents.TryGetValue(AKey, EventList) then
    begin
      Idx := EventList.IndexOf(AEvent);
      if Idx >= 0 then
      begin
        EventList.Delete(Idx);
        Result := True;
        if EventList.Count = 0 then
          FDicEvents.Remove(AKey); // liste boşaldı; doOwnsValues onu Free eder
      end;
    end;
  finally
    WriteUnlock;
  end;
end;

procedure TSmartCache.UnregisterEvents(const AKey: string);
begin
  WriteLock;
  try
    FDicEvents.Remove(AKey);
  finally
    WriteUnlock;
  end;
end;

procedure TSmartCache.ForEach(const AProc: TProc<string, TValue>);
var
  LocalCopy: TArray<TPair<string, TValue>>;
  Pair: TPair<string, TValue>;
begin
  if not Assigned(AProc) then Exit;
  ReadLock;
  try
    LocalCopy := FDic.ToArray;
  finally
    ReadUnlock;
  end;
  for Pair in LocalCopy do
    AProc(Pair.Key, Pair.Value);
end;




procedure WriteCacheValue(AWriter: TJsonWriter; const AKey: string;
  const AValue: TValue);
var
  LJson: RawUtf8;

  procedure AddSerializedJson;
  begin
    if (LJson = '') or not IsValidJson(LJson) then
      raise ESmartCacheJson.CreateFmt(
        'FileSave: "%s" anahtarı geçerli JSON olarak serileştirilemedi.',
        [AKey]);
    AWriter.AddNoJsonEscape(Pointer(LJson), Length(LJson));
  end;

begin
  if AValue.IsEmpty then
  begin
    AWriter.AddNull;
    Exit;
  end;

  case AValue.Kind of
    tkInteger:
      AWriter.Add(AValue.AsInteger);
    tkInt64:
      if AValue.TypeInfo = System.TypeInfo(UInt64) then
      begin
        if AValue.AsUInt64 > UInt64(High(Int64)) then
          raise ESmartCacheJson.CreateFmt(
            'FileSave: "%s" anahtarındaki UInt64 değeri JSON Int64 sınırını aşıyor.',
            [AKey]);
        AWriter.Add(Int64(AValue.AsUInt64));
      end
      else
        AWriter.Add(AValue.AsInt64);
    tkEnumeration:
      if AValue.TypeInfo = System.TypeInfo(Boolean) then
        AWriter.Add(AValue.AsBoolean)
      else
        AWriter.Add(AValue.AsOrdinal);
    tkFloat:
      AWriter.Add(AValue.AsExtended, 17);
    tkChar, tkWChar, tkString, tkLString, tkWString, tkUString:
      AWriter.AddJsonString(StringToUtf8(AValue.AsString));
    tkClass:
      if AValue.AsObject = nil then
        AWriter.AddNull
      else
      begin
        LJson := ObjectToJson(AValue.AsObject);
        AddSerializedJson;
      end;
    tkRecord:
      begin
        LJson := RecordSaveJson(AValue.GetReferenceToRawData^,
          PRttiInfo(AValue.TypeInfo), True);
        AddSerializedJson;
      end;
    tkVariant:
      begin
        LJson := VariantSaveJson(AValue.AsVariant);
        AddSerializedJson;
      end;
  else
    raise ESmartCacheJson.CreateFmt(
      'FileSave: "%s" anahtarındaki %s türü desteklenmiyor.',
      [AKey, System.TypInfo.GetEnumName(
        System.TypeInfo(TTypeKind), Ord(AValue.Kind))]);
  end;
end;

function SiblingTemporaryFileName(const AFileName: string): string;
begin
  Result := TPath.Combine(ExtractFilePath(ExpandFileName(AFileName)),
    '.' + ExtractFileName(AFileName) + '.' + TPath.GetRandomFileName + '.tmp');
end;

procedure ReplaceFileAtomically(const ATemporaryFileName,
  ADestinationFileName: string);
begin
  {$IFDEF MSWINDOWS}
  if not MoveFileEx(PChar(ATemporaryFileName), PChar(ADestinationFileName),
    MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
    RaiseLastOSError;
  {$ELSE}
  if TFile.Exists(ADestinationFileName) then
    TFile.Delete(ADestinationFileName);
  TFile.Move(ATemporaryFileName, ADestinationFileName);
  {$ENDIF}
end;

function CacheJsonToXml(const AJson: RawUtf8): RawUtf8;
const
  COpenTag: RawUtf8 = '<rad-cache-json>';
  CCloseTag: RawUtf8 = '</rad-cache-json>';
  CAmp: RawUtf8 = '&amp;';
  CLessThan: RawUtf8 = '&lt;';
  CGreaterThan: RawUtf8 = '&gt;';
var
  i: Integer;
  LAppendLength: Integer;
  LLength: Integer;

  procedure Append(const AText: RawUtf8);
  begin
    LAppendLength := Length(AText);
    if LAppendLength = 0 then
      Exit;
    Move(Pointer(AText)^, PAnsiChar(Pointer(Result))[LLength], LAppendLength);
    Inc(LLength, LAppendLength);
  end;

begin
  { Genel JsonToXml düz anahtar sözlüğünde kök/isim anlamını değiştirebilir.
    Cache'e özgü zarf, kanonik JSON'u XML içinde kayıpsız taşır. }
  SetLength(Result, Length(XMLUTF8_HEADER) + Length(COpenTag) +
    (Length(AJson) * 5) + Length(CCloseTag));
  LLength := 0;
  Append(XMLUTF8_HEADER);
  Append(COpenTag);
  for i := 1 to Length(AJson) do
    case AJson[i] of
      '&': Append(CAmp);
      '<': Append(CLessThan);
      '>': Append(CGreaterThan);
    else
      PAnsiChar(Pointer(Result))[LLength] := AJson[i];
      Inc(LLength);
    end;
  Append(CCloseTag);
  SetLength(Result, LLength);
end;

function CacheXmlToJson(const AXml: RawUtf8): RawUtf8;
const
  COpenTag: RawUtf8 = '<rad-cache-json>';
  CCloseTag: RawUtf8 = '</rad-cache-json>';
var
  LClosePosition: Integer;
  LInner: RawUtf8;
  LOpenPosition: Integer;
begin
  LOpenPosition := Pos(COpenTag, AXml);
  LClosePosition := Pos(CCloseTag, AXml);
  if (LOpenPosition > 0) and (LClosePosition > LOpenPosition) then
  begin
    LOpenPosition := LOpenPosition + Length(COpenTag);
    LInner := Copy(AXml, LOpenPosition, LClosePosition - LOpenPosition);
    if not XmlUnescape(Pointer(LInner), Length(LInner), Result) then
      raise ESmartCacheJson.Create(
        'FileLoad: Cache XML zarfındaki JSON çözülemedi.');
    Exit;
  end;

  { Eski veya dışarıdan gelen genel XML dosyaları için uyumluluk yolu. }
  Result := XmlToJson(AXml);
end;

procedure TSmartCache.FileSave(AFileName: string = '';
  const ACipher: Boolean = False);
var
  LJson: RawUtf8;
  LFileType: Integer;
  LKey: string;
  LKeys: TArray<string>;
  LTemporaryFileName: string;
  LValue: TValue;
  LWriter: TJsonWriter;
  LWrittenCount: Integer;
begin
  if AFileName.IsEmpty then
    AFileName := GetSaveFileName;

  FFileSaveLock.Enter;
  try
    try
      if AFileName.IsEmpty then
        raise ESmartCacheJson.Create('FileSave: Dosya adı boş olamaz.');
    if ACipher then
      raise ESmartCacheJson.Create(
        'FileSave: ACipher=True için anahtar/cipher sağlanamadığından düz metin yazılmadı.');

    LFileType := IndexText(ExtractFileExt(AFileName), FileTypes);
    if not (LFileType in [0, 1, 2, 3]) then
      raise ESmartCacheJson.CreateFmt(
        'FileSave: "%s" uzantısı desteklenmiyor. Desteklenenler: .json .yml .yaml .xml',
        [ExtractFileExt(AFileName)]);

    { Belgeyi read-lock altında kur; disk I/O kilit dışında kalır. }
    ReadLock;
    try
      if FDic.Count = 0 then
        LJson := '{}'
      else
      begin
        LKeys := FDic.Keys.ToArray;
        LWriter := TJsonWriter.CreateOwnedStream(512);
        try
          LWriter.Add('{');
          LWrittenCount := 0;
          for LKey in LKeys do
          begin
            if not FDic.TryGetValue(LKey, LValue) then
              Continue;
            if LWrittenCount > 0 then
              LWriter.AddComma;
            LWriter.AddJsonString(StringToUtf8(LKey));
            LWriter.Add(':');
            WriteCacheValue(LWriter, LKey, LValue);
            Inc(LWrittenCount);
          end;
          LWriter.Add('}');
          LWriter.SetText(LJson);
        finally
          LWriter.Free;
        end;
      end;
    finally
      ReadUnlock;
    end;
    { Önce aynı klasörde geçici dosya oluştur, ancak tam yazım başarıyla
      bittikten sonra hedefi tek atomik taşıma ile değiştir. }
    LTemporaryFileName := SiblingTemporaryFileName(AFileName);
    try
      case LFileType of
        0:
          FileFromString(LJson, LTemporaryFileName);
        1, 2:
          FileFromString(JsonToYaml(LJson), LTemporaryFileName);
        3:
          FileFromString(CacheJsonToXml(LJson), LTemporaryFileName);
      end;
      ReplaceFileAtomically(LTemporaryFileName, AFileName);
      LTemporaryFileName := '';
    finally
      if (LTemporaryFileName <> '') and TFile.Exists(LTemporaryFileName) then
        TFile.Delete(LTemporaryFileName);
    end;
    except
      on E: Exception do
      begin
        ReportError(AFileName, E);
        raise;
      end;
    end;
  finally
    FFileSaveLock.Leave;
  end;
end;

procedure TSmartCache.ReportError(const AKey: string; const AError: Exception);
var
  LOnError: TSmartCacheErrorEvent;
begin
  ReadLock;
  try
    LOnError := FOnError;
  finally
    ReadUnlock;
  end;
  if Assigned(LOnError) then
    LOnError(AKey, AError);
end;


{ Dosya icerigini JSON'a cevirir. Desteklenmeyen uzanti sessiz gecilmez. }
function FileContentAsJson(const AFileName: string; AFileType: Integer): RawUtf8;
var
  LHam: RawByteString;
begin
  LHam := StringFromFile(AFileName);

  { UTF-8 BOM ATILIR - olculdu, atilmazsa SESSIZ BOS YUKLEME oluyor.

    Editorlerin cogu (ve TFile.WriteAllText'in TEncoding.UTF8 hâli) dosyanin
    basina EF BB BF yazar. StringFromFile ham bayt dondurdugu icin BOM
    ayristiriciya gidiyordu: JSON yolunda DocDict bunu ayristiramayip BOS bir
    nesne donuyor, YAML yolunda ise BOM anahtarin ADINA yapisiyordu
    (olcumde "?aile.baba" diye bir anahtar olustu). }
  if (Length(LHam) >= 3) and (LHam[1] = #$EF) and
     (LHam[2] = #$BB) and (LHam[3] = #$BF) then
    Delete(LHam, 1, 3);

  case AFileType of
    0    : Result := LHam;               // .json
    1, 2 :
      if IsValidJson(RawUtf8(LHam)) then
        Result := LHam                    // JSON, YAML 1.2 alt kümesidir
      else
        Result := YamlToJson(LHam);       // klasik blok YAML
    3    : Result := CacheXmlToJson(LHam); // .xml
  else
    { Bilinmeyen uzantı sessizce False dönmemeli; çağıran "dosya boş" ile
      "biçimi desteklemiyorum" durumlarını ayırt edebilmeli. }
    raise ESmartCacheJson.CreateFmt(
      'FileLoad: "%s" uzantisi yuklenemiyor. Desteklenenler: .json .yml .yaml .xml',
      [ExtractFileExt(AFileName)]);
  end;
end;

function TSmartCache.FileLoad(const AFileName: string;  AClearFirst: Boolean): Boolean;
var
  LFileName: string;
  LSkippedCount: Integer;
  LError: ESmartCacheJson;
begin
  Result := False;
  LFileName := AFileName;
  if LFileName.IsEmpty then
    LFileName := GetSaveFileName;

  if LFileName.IsEmpty or (not FileExists(LFileName)) then
  begin
    LError := ESmartCacheJson.CreateFmt(
      'FileLoad: Dosya bulunamadı: "%s"', [LFileName]);
    try
      ReportError(LFileName, LError);
    finally
      LError.Free;
    end;
    Exit;
  end;

  try
    LSkippedCount := LoadJson(
      Utf8ToString(FileContentAsJson(LFileName,
        IndexText(ExtractFileExt(LFileName), FileTypes))), AClearFirst);

    if LSkippedCount > 0 then
    begin
      LError := ESmartCacheJson.CreateFmt(
        'FileLoad: %d anahtar olay dinleyicileri tarafindan reddedildi.',
        [LSkippedCount]);
      try
        ReportError(LFileName, LError);
      finally
        LError.Free;
      end;
    end;
    Result := True;
  except
    on E: Exception do
    begin
      Result := False;
      ReportError(LFileName, E);
    end;
  end;
end;



end.

