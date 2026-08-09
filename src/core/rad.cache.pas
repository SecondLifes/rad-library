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
  Generics.Collections;

type
  // AOld: önceki değer (anahtar yoksa TValue.Empty), ANew: yazılmak istenen değer.
  // False dönerse yazma iptal edilir.
  TParamChangeEvent     = TFunc<string, TValue, TValue, Boolean>;
  TSmartCacheErrorEvent = procedure(const AKey: string; const AError: Exception) of object;

  { ISmartCache — cache'in soyutlaması (DI/test için constructor'a bunu geçin).

    Delphi interface'leri generic metot taşıyamadığından Get<T>/TryGet<T>/
    GetIntf<T> burada YOKTUR; interface üzerinden generic erişim için
    TSmartCacheView kullanılır (aşağıda):

      var Cache: ISmartCache := NewSmartCache;   // ARC — Free yok
      Liste := TSmartCacheView(Cache).Get<TStringList>('k', nil);

    YAŞAM SÜRESİ KURALI: Bir örneği YA ISmartCache olarak tutun (ARC serbest
    bırakır) YA DA TSmartCache sınıf referansı olarak tutup Free edin —
    ikisini AYNI örnek üzerinde KARIŞTIRMAYIN (çifte serbest bırakma riski). }
  ISmartCache = interface
    ['{E46AC9F0-DEC5-4478-9464-3B800DE90F5C}']
    function GetGlobalEvent: TParamChangeEvent;
    procedure SetGlobalEvent(const AValue: TParamChangeEvent);
    function GetOnError: TSmartCacheErrorEvent;
    procedure SetOnError(const AValue: TSmartCacheErrorEvent);

    function AddOrSet(const AKey: string; const V: TValue): Boolean; overload;
    function AddOrSet(const AKey: string; const V: IInterface): Boolean; overload;

    function Get(const AKey: string; const ADefault: Integer):   Integer;   overload;
    function Get(const AKey: string; const ADefault: Double):    Double;    overload;
    function Get(const AKey: string; const ADefault: string):    string;    overload;
    function Get(const AKey: string; const ADefault: Boolean):   Boolean;   overload;
    function Get(const AKey: string; const ADefault: TDateTime): TDateTime; overload;

    function GetValue(const AKey: string; const ADefault: TValue): TValue;
    function TryGetValue(const AKey: string; out AValue: TValue): Boolean;

    function GetOrAdd(const AKey: string; const AValue: TValue): TValue; overload;
    function GetOrAdd(const AKey: string; const AFactory: TFunc<TValue>): TValue; overload;

    function ContainsKey(const AKey: string): Boolean;
    function Remove(const AKey: string): Boolean;
    procedure Clear;
    function Count: Integer;
    function Keys: TArray<string>;

    procedure RegisterEvent   (const AKey: string; const AEvent: TParamChangeEvent);
    function  UnregisterEvent (const AKey: string; const AEvent: TParamChangeEvent): Boolean;
    procedure UnregisterEvents(const AKey: string);
    procedure ForEach(const AProc: TProc<string, TValue>);

    property OnGlobalChange: TParamChangeEvent     read GetGlobalEvent write SetGlobalEvent;
    property OnError       : TSmartCacheErrorEvent read GetOnError     write SetOnError;
  end;

  // NOT: TObject değerleri cache tarafından SAHİPLENİLMEZ. Çağıran, nesnenin
  // ömrünü cache'ten bağımsız yönetmelidir (mimari karar — bkz. rad.cache.md).
  // Interface değerleri ise TValue içinde referans sayımıyla canlı tutulur.
  TSmartCache = class(TInterfacedObject, ISmartCache)
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
    FLock       : TLightweightMREW;
    FThreadSafe : Boolean;
    FOnError    : TSmartCacheErrorEvent;

    procedure BeginRead;  inline;
    procedure EndRead;    inline;
    procedure BeginWrite; inline;
    procedure EndWrite;   inline;

    function GetGlobalEvent: TParamChangeEvent;
    procedure SetGlobalEvent(const AValue: TParamChangeEvent);
    function GetOnError: TSmartCacheErrorEvent;
    procedure SetOnError(const AValue: TSmartCacheErrorEvent);

    class function ValuesEqual(const A, B: TValue): Boolean; static;
    function FireEvents(const AKey: string; const AOld, ANew: TValue): Boolean;
  public
    constructor Create(const AThreadSafe: Boolean = True);
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

    procedure RegisterEvent   (const AKey: string; const AEvent: TParamChangeEvent);
    function  UnregisterEvent (const AKey: string; const AEvent: TParamChangeEvent): Boolean;
    procedure UnregisterEvents(const AKey: string);
    procedure ForEach(const AProc: TProc<string, TValue>);

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

implementation

uses
  Variants; // ValuesEqual'daki tkVariant dalı için

function NewSmartCache(const AThreadSafe: Boolean): ISmartCache;
begin
  Result := TSmartCache.Create(AThreadSafe);
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
  inherited Create;
  FThreadSafe := AThreadSafe;
  FDic := TDictionary<string, TValue>.Create;
  FDicEvents := TObjectDictionary<string, TList<TParamChangeEvent>>.Create([doOwnsValues]);
end;

destructor TSmartCache.Destroy;
begin
  FreeAndNil(FDicEvents);
  FreeAndNil(FDic);
  // FLock (TLightweightMREW) record — Free gerekmez
  inherited Destroy;
end;

procedure TSmartCache.BeginRead;
begin
  if FThreadSafe then FLock.BeginRead;
end;

procedure TSmartCache.EndRead;
begin
  if FThreadSafe then FLock.EndRead;
end;

procedure TSmartCache.BeginWrite;
begin
  if FThreadSafe then FLock.BeginWrite;
end;

procedure TSmartCache.EndWrite;
begin
  if FThreadSafe then FLock.EndWrite;
end;

function TSmartCache.GetGlobalEvent: TParamChangeEvent;
begin
  BeginRead;
  try
    Result := FGlobalEvent;
  finally
    EndRead;
  end;
end;

procedure TSmartCache.SetGlobalEvent(const AValue: TParamChangeEvent);
begin
  BeginWrite;
  try
    FGlobalEvent := AValue;
  finally
    EndWrite;
  end;
end;

function TSmartCache.GetOnError: TSmartCacheErrorEvent;
begin
  BeginRead;
  try
    Result := FOnError;
  finally
    EndRead;
  end;
end;

procedure TSmartCache.SetOnError(const AValue: TSmartCacheErrorEvent);
begin
  BeginWrite;
  try
    FOnError := AValue;
  finally
    EndWrite;
  end;
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

  BeginRead;
  try
    LGlobalEvent := FGlobalEvent;
    LOnError     := FOnError; // yarış durumu olmasın diye kilit altında kopyala

    if FDicEvents.TryGetValue(AKey, EventList) then
      LocalEvents := EventList.ToArray;
  finally
    EndRead;
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
begin
  // İyimser eşzamanlılık (CAS): callback'ler kilit dışında çalışır; yazım
  // öncesi anlık görüntünün hâlâ geçerli olduğu doğrulanır, değilse tekrar
  // dener. Bu yüzden callback'ler yan etkisiz/idempotent olmalıdır.
  repeat
    BeginRead;
    try
      HasOldValue := FDic.TryGetValue(AKey, OldValue);
    finally
      EndRead;
    end;

    if HasOldValue and ValuesEqual(OldValue, V) then
      Exit(True);

    if not HasOldValue then
      OldValue := TValue.Empty; // "önceki değer yok" işareti — event'e Empty gider

    if not FireEvents(AKey, OldValue, V) then
      Exit(False);

    BeginWrite;
    try
      HasCurrentValue := FDic.TryGetValue(AKey, CurrentValue);

      if HasCurrentValue and ValuesEqual(CurrentValue, V) then
        Exit(True);

      if (HasCurrentValue = HasOldValue) and
         ((not HasCurrentValue) or ValuesEqual(CurrentValue, OldValue)) then
      begin
        FDic.AddOrSetValue(AKey, V);
        Exit(True);
      end;
    finally
      EndWrite;
    end;
  until False;
end;

function TSmartCache.AddOrSet(const AKey: string; const V: IInterface): Boolean;
begin
  Result := AddOrSet(AKey, TValue.From<IInterface>(V));
end;

function TSmartCache.GetValue(const AKey: string; const ADefault: TValue): TValue;
begin
  BeginRead;
  try
    if not FDic.TryGetValue(AKey, Result) then
      Result := ADefault;
  finally
    EndRead;
  end;
end;

function TSmartCache.Get<T>(const AKey: string; const ADefault: T): T;
var
  LVal: TValue;
  LHas: Boolean;
begin
  BeginRead;
  try
    LHas := FDic.TryGetValue(AKey, LVal);
  finally
    EndRead;
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
  BeginRead;
  try
    LHas := FDic.TryGetValue(AKey, LVal);
  finally
    EndRead;
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
  BeginRead;
  try
    LHas := FDic.TryGetValue(AKey, LVal);
  finally
    EndRead;
  end;
  Result := LHas and (not LVal.IsEmpty) and LVal.TryAsType<T>(AValue);
  if not Result then
    AValue := Default(T);
end;

function TSmartCache.TryGetValue(const AKey: string; out AValue: TValue): Boolean;
begin
  BeginRead;
  try
    Result := FDic.TryGetValue(AKey, AValue);
  finally
    EndRead;
  end;
end;

function TSmartCache.GetOrAdd(const AKey: string; const AValue: TValue): TValue;
begin
  BeginWrite;
  try
    if not FDic.TryGetValue(AKey, Result) then
    begin
      FDic.Add(AKey, AValue);
      Result := AValue;
    end;
  finally
    EndWrite;
  end;
end;

function TSmartCache.GetOrAdd(const AKey: string; const AFactory: TFunc<TValue>): TValue;
begin
  if not Assigned(AFactory) then
    Exit(TValue.Empty);
  BeginWrite;
  try
    if not FDic.TryGetValue(AKey, Result) then
    begin
      // Factory yazma kilidi altında çalışır — bilinçli tercih: aynı anahtar
      // için "yalnız bir kez üret" garantisi verir. Bedeli: factory hafif
      // olmalı ve içinden bu cache'e erişmemelidir.
      Result := AFactory();
      FDic.Add(AKey, Result);
    end;
  finally
    EndWrite;
  end;
end;

function TSmartCache.ContainsKey(const AKey: string): Boolean;
begin
  BeginRead;
  try
    Result := FDic.ContainsKey(AKey);
  finally
    EndRead;
  end;
end;

function TSmartCache.Remove(const AKey: string): Boolean;
begin
  BeginWrite;
  try
    Result := FDic.ContainsKey(AKey);
    if Result then
    begin
      FDic.Remove(AKey);
      FDicEvents.Remove(AKey);
    end;
  finally
    EndWrite;
  end;
end;

procedure TSmartCache.Clear;
begin
  BeginWrite;
  try
    FDic.Clear;
    FDicEvents.Clear;
  finally
    EndWrite;
  end;
end;

function TSmartCache.Count: Integer;
begin
  BeginRead;
  try
    Result := FDic.Count;
  finally
    EndRead;
  end;
end;

function TSmartCache.Keys: TArray<string>;
begin
  BeginRead;
  try
    Result := FDic.Keys.ToArray;
  finally
    EndRead;
  end;
end;

procedure TSmartCache.RegisterEvent(const AKey: string; const AEvent: TParamChangeEvent);
var
  EventList: TList<TParamChangeEvent>;
begin
  if not Assigned(AEvent) then Exit;
  BeginWrite;
  try
    if not FDicEvents.TryGetValue(AKey, EventList) then
    begin
      EventList := TList<TParamChangeEvent>.Create;
      FDicEvents.Add(AKey, EventList);
    end;
    EventList.Add(AEvent);
  finally
    EndWrite;
  end;
end;

function TSmartCache.UnregisterEvent(const AKey: string; const AEvent: TParamChangeEvent): Boolean;
var
  EventList: TList<TParamChangeEvent>;
  Idx      : Integer;
begin
  Result := False;
  if not Assigned(AEvent) then Exit;
  BeginWrite;
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
    EndWrite;
  end;
end;

procedure TSmartCache.UnregisterEvents(const AKey: string);
begin
  BeginWrite;
  try
    FDicEvents.Remove(AKey);
  finally
    EndWrite;
  end;
end;

procedure TSmartCache.ForEach(const AProc: TProc<string, TValue>);
var
  LocalCopy: TArray<TPair<string, TValue>>;
  Pair     : TPair<string, TValue>;
begin
  if not Assigned(AProc) then Exit;
  BeginRead;
  try
    LocalCopy := FDic.ToArray;
  finally
    EndRead;
  end;
  for Pair in LocalCopy do
    AProc(Pair.Key, Pair.Value);
end;

end.
