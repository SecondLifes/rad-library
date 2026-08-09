unit rad.cache;

interface

uses
  SysUtils, Classes, Variants, VarUtils,
  Generics.Collections,
  mormot.core.os; // TRWLock için

type
  // Object/Interface saklarken varInt64/varUnknown gibi Variant tiplerinin
  // anlamını netleştiren domain-odaklı sınıflandırma (bkz. rad.cache.md
  // 2026-07-09 incelemesi #8). vType (ham TVarType) geriye dönük uyumluluk
  // için korunuyor; Kind bunun üzerine FvType'tan hesaplanır.
  TSmartParamKind = (spEmpty, spNull, spInteger, spFloat, spString, spBoolean, spDateTime, spObject, spInterface, spVariant);

  TSmartParam = record
  private
    FvType: TVarType;
    FValue: Variant;
    function GetKind: TSmartParamKind;
  public
    property vType: TVarType read FvType;
    property Value: Variant  read FValue;
    property Kind: TSmartParamKind read GetKind;

    function AsInteger : Integer;   inline;
    function AsFloat   : Double;    inline;
    function AsString  : string;    inline;
    function AsBoolean : Boolean;   inline;
    function AsDateTime: TDateTime; inline;
    function AsDate    : TDate;     inline;
    function AsTime    : TTime;     inline;
    function AsObj<T: class>: T;
    function AsIntf<T> : T;
    function IsNull    : Boolean;   inline;
    function IsEmpty   : Boolean;   inline;

    // Exception firlatmayan okuma (bkz. rad.cache.md 2026-07-09 incelemesi #5):
    // tip uyusmazsa/donusum basarisizsa False doner, AValue degismez birakilmaz
    // (varsayilan tipin sifir degerine ayarlanir).
    function TryAsInteger (out AValue: Integer)  : Boolean;
    function TryAsFloat   (out AValue: Double)   : Boolean;
    function TryAsBoolean (out AValue: Boolean)  : Boolean;
    function TryAsDateTime(out AValue: TDateTime): Boolean;

    procedure SetValue(const V: Integer);    overload; inline;
    procedure SetValue(const V: Double);     overload; inline;
    procedure SetValue(const V: string);     overload; inline;
    procedure SetValue(const V: Boolean);    overload; inline;
    procedure SetValue(const V: TDateTime);  overload; inline;
    procedure SetValue(const V: Variant);    overload; inline;
    procedure SetValue(const V: TObject);    overload; inline;
    procedure SetValue(const V: IInterface); overload; inline;
    procedure SetNull; inline;

    class function New(const V: Integer)   : TSmartParam; overload; static; inline;
    class function New(const V: string)    : TSmartParam; overload; static; inline;
    class function New(const V: Double)    : TSmartParam; overload; static; inline;
    class function New(const V: Boolean)   : TSmartParam; overload; static; inline;
    class function New(const V: TDateTime) : TSmartParam; overload; static; inline;
    class function New(const V: Variant)   : TSmartParam; overload; static; inline;
    class function New(const V: TObject)   : TSmartParam; overload; static; inline;
    class function New(const V: IInterface): TSmartParam; overload; static; inline;

    class operator Implicit(const AParm: TSmartParam): Integer;   inline;
    class operator Implicit(const AParm: TSmartParam): Double;    inline;
    class operator Implicit(const AParm: TSmartParam): string;    inline;
    class operator Implicit(const AParm: TSmartParam): Boolean;   inline;
    class operator Implicit(const AParm: TSmartParam): TDateTime; inline;
  end;

  TParamChangeEvent    = TFunc<string, TVarType, Variant, Variant, Boolean>;
  TSmartCacheErrorEvent = procedure(const AKey: string; const AError: Exception) of object;

  // NOT: TObject değerleri cache tarafından SAHİPLENİLMEZ (ham işaretçi olarak
  // saklanır). Çağıran, nesnenin ömrünü cache'ten bağımsız yönetmelidir.
  TSmartCache = class
  private
    FDic        : TDictionary<string, TSmartParam>;
    FDicEvents  : TObjectDictionary<string, TList<TParamChangeEvent>>;
    FGlobalEvent: TParamChangeEvent;
    FLock       : TRWLock;
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

    class function ParamsEqual(const A, B: TSmartParam): Boolean; static;
    function FireEvents(const AKey: string;
                        const AOldParam, ANewParam: TSmartParam): Boolean;
  public
    constructor Create(const AThreadSafe: Boolean = True);
    destructor Destroy; override;

    function AddOrSet(const AKey: string; const V: TSmartParam):  Boolean; overload;
    function AddOrSet(const AKey: string; const V: Integer):       Boolean; overload;
    function AddOrSet(const AKey: string; const V: Double):        Boolean; overload;
    function AddOrSet(const AKey: string; const V: string):        Boolean; overload;
    function AddOrSet(const AKey: string; const V: Boolean):       Boolean; overload;
    function AddOrSet(const AKey: string; const V: TDateTime):     Boolean; overload;
    function AddOrSet(const AKey: string; const V: Variant):       Boolean; overload;
    function AddOrSet(const AKey: string; const V: TObject):       Boolean; overload;
    function AddOrSet(const AKey: string; const V: IInterface):    Boolean; overload;

    function Get(const AKey: string; const ADefault: TSmartParam): TSmartParam; overload;
    function Get(const AKey: string; const ADefault: Integer):     Integer;      overload;
    function Get(const AKey: string; const ADefault: Double):      Double;       overload;
    function Get(const AKey: string; const ADefault: string):      string;       overload;
    function Get(const AKey: string; const ADefault: Boolean):     Boolean;      overload;
    function Get(const AKey: string; const ADefault: TDateTime):   TDateTime;    overload;
    function Get(const AKey: string; const ADefault: Variant):     Variant;      overload;

    function GetOrAdd     (const AKey: string; const AParam: TSmartParam): TSmartParam;
    function TryGetValue  (const AKey: string; out AParam: TSmartParam): Boolean;
    function ContainsKey  (const AKey: string): Boolean;
    function Remove       (const AKey: string): Boolean;
    procedure Clear;
    function Count: Integer;

    procedure RegisterEvent   (const AKey: string; const AEvent: TParamChangeEvent);
    function  UnregisterEvent (const AKey: string; const AEvent: TParamChangeEvent): Boolean;
    procedure UnregisterEvents(const AKey: string);
    procedure ForEach(const AProc: TProc<string, TSmartParam>);

    property OnGlobalChange: TParamChangeEvent      read GetGlobalEvent write SetGlobalEvent;
    property OnError       : TSmartCacheErrorEvent  read GetOnError     write SetOnError;
  end;

implementation

uses
  TypInfo; // GetTypeData/PTypeInfo/PTypeData — AsIntf<T> icin (TRttiContext yerine)

{ TSmartParam }

procedure TSmartParam.SetValue(const V: Integer);
begin
  // Guvenli atama (2026-07-09 incelemesi #1, scratch testle dogrulandi):
  // FValue eskiden string/interface gibi yonetilen bir deger tasiyorsa,
  // derleyici bu atamadan ONCE eskisini VarClear ile temizler. Eski kod
  // TVarData alanlarina DOGRUDAN yaziyordu ve bu temizligi atlayip
  // referans sayimli eski degerleri (string/interface) sizdiriyordu.
  FValue := V;
  FvType := TVarData(FValue).VType;
end;

procedure TSmartParam.SetValue(const V: Double);
begin
  FValue := V;
  FvType := TVarData(FValue).VType;
end;

procedure TSmartParam.SetValue(const V: string);
begin
  FValue := V;
  FvType := TVarData(FValue).VType;
end;

procedure TSmartParam.SetValue(const V: Boolean);
begin
  FValue := V;
  FvType := TVarData(FValue).VType;
end;

procedure TSmartParam.SetValue(const V: TDateTime);
begin
  FValue := V;
  FvType := TVarData(FValue).VType;
end;

procedure TSmartParam.SetValue(const V: Variant);
begin
  FValue := V;
  FvType := TVarData(V).VType;
end;

procedure TSmartParam.SetNull;
begin
  FValue := Variants.Null;
  FvType := varNull;
end;

procedure TSmartParam.SetValue(const V: TObject);
var
  LAddr: Int64;
begin
  if V = nil then begin SetNull; Exit; end;
  // Guvenli atama (2026-07-09 incelemesi #1) + bilincli olarak HER platformda
  // (32/64-bit) varInt64 (LAddr: Int64, NativeInt DEGIL): NativeInt kullanilsaydi
  // 32-bit'te varInteger olurdu ve gercek Integer degerleriyle ayni FvType'i
  // paylasarak Kind/spObject ayrimini (incelemesi #8) belirsizlestirirdi.
  // Bir Variant'in toplam boyutu VType'tan bagimsiz sabit oldugu icin
  // varInt64'un 32-bit'te "yer israfi" iddiasinin da pratikte karsiligi yok.
  LAddr  := NativeInt(V);
  FValue := LAddr;
  FvType := TVarData(FValue).VType;
end;

procedure TSmartParam.SetValue(const V: IInterface);
begin
  if V = nil then begin SetNull; Exit; end;
  FValue := V;
  FvType := varUnknown;
end;

function TSmartParam.IsNull: Boolean;
begin
  Result := FvType = varNull;
end;

function TSmartParam.IsEmpty: Boolean;
begin
  Result := FvType = varEmpty;
end;

function TSmartParam.GetKind: TSmartParamKind;
begin
  case FvType of
    varEmpty  : Result := spEmpty;
    varNull   : Result := spNull;
    varInteger: Result := spInteger;
    // varCurrency dahil: SetValue(Variant)'a giden ondalikli sabitler (ör.
    // SetValue(3.14) literal'i overload cozumlemesinde SetValue(Double) yerine
    // SetValue(Variant)'a baglanip varCurrency olarak saklanabiliyor - scratch
    // testle dogrulandi, AsFloat zaten bunu genel Variant donusumuyle
    // sorunsuz okuyor, Kind da ayni float ailesini tanimali.
    varDouble, varSingle, varCurrency: Result := spFloat;
    varUString, varString, varOleStr: Result := spString;
    varBoolean: Result := spBoolean;
    varDate   : Result := spDateTime;
    // Bu API'de varInt64 SADECE SetValue(TObject) tarafindan uretilir
    // (SetValue(Integer) her zaman varInteger uretir) - bkz. SetValue(TObject)
    // yorumu, bilincli olarak platformdan bagimsiz varInt64 secildi.
    varInt64  : Result := spObject;
    varUnknown, varDispatch: Result := spInterface;
  else
    Result := spVariant;
  end;
end;

function TSmartParam.AsInteger: Integer;
begin
  if FvType = varInteger then Result := TVarData(FValue).VInteger
  else Result := Integer(FValue);
end;

function TSmartParam.TryAsInteger(out AValue: Integer): Boolean;
begin
  try
    AValue := AsInteger;
    Result := True;
  except
    AValue := 0;
    Result := False;
  end;
end;

function TSmartParam.AsFloat: Double;
begin
  if FvType = varDouble then Result := TVarData(FValue).VDouble
  else Result := Double(FValue);
end;

function TSmartParam.TryAsFloat(out AValue: Double): Boolean;
begin
  try
    AValue := AsFloat;
    Result := True;
  except
    AValue := 0;
    Result := False;
  end;
end;

function TSmartParam.AsString: string;
begin
  if (FvType = varUString) or (FvType = varString) or (FvType = varOleStr) then
    Result := string(FValue)
  else
    Result := VarToStr(FValue);
end;

function TSmartParam.AsBoolean: Boolean;
begin
  if FvType = varBoolean then Result := TVarData(FValue).VBoolean
  else Result := Boolean(FValue);
end;

function TSmartParam.TryAsBoolean(out AValue: Boolean): Boolean;
begin
  try
    AValue := AsBoolean;
    Result := True;
  except
    AValue := False;
    Result := False;
  end;
end;

function TSmartParam.AsDateTime: TDateTime;
begin
  if FvType = varDate then Result := TVarData(FValue).VDate
  else Result := TDateTime(FValue);
end;

function TSmartParam.TryAsDateTime(out AValue: TDateTime): Boolean;
begin
  try
    AValue := AsDateTime;
    Result := True;
  except
    AValue := 0;
    Result := False;
  end;
end;

function TSmartParam.AsDate: TDate;
begin
  Result := Trunc(AsDateTime);
end;

function TSmartParam.AsTime: TTime;
begin
  Result := Frac(AsDateTime);
end;

function TSmartParam.AsObj<T>: T;
var
  LObj: TObject;
begin
  if (FvType = varInteger) or (FvType = varInt64) then
  begin
    LObj := TObject(Pointer(NativeInt(FValue)));
    // 2026-07-09 incelemesi #3: nesne HALEN CANLIYSA yanlis tipte istenirse
    // artik nil doner (eskiden kontrolsuz cast ile yanlis tipte "basariyla"
    // donerdi). Freed-object/dangling-pointer riski bununla COZULMEZ - o zaten
    // rad.cache.md'de mimari karar olarak belgelenmis (SetValue(TObject)
    // nesneyi sahiplenmiyor).
    if LObj is T then
      Result := T(LObj)
    else
      Result := nil;
  end
  else
    Result := nil;
end;

function TSmartParam.AsIntf<T>: T;
var
  LUnk     : IInterface;
  LTypeInfo: PTypeInfo;
  LTypeData: PTypeData;
begin
  Result := Default(T);
  if (FvType = varUnknown) or (FvType = varDispatch) then
  begin
    LUnk := IInterface(FValue);
    if LUnk = nil then Exit;
    // 2026-07-09 incelemesi #4: TRttiContext olusturmak (tip agaci taramasi +
    // heap allocation) yerine GetTypeData ile GUID dogrudan derleme-zamani
    // meta verisinden okunuyor - GUID esitligi scratch testle dogrulandi,
    // davranis degismedi, sadece TRttiContext/TRttiInterfaceType yuku kalkti.
    LTypeInfo := System.TypeInfo(T);
    if (LTypeInfo <> nil) and (LTypeInfo.Kind = tkInterface) then
    begin
      LTypeData := GetTypeData(LTypeInfo);
      if LTypeData <> nil then
        Supports(LUnk, LTypeData.Guid, Result);
    end;
  end;
end;

class function TSmartParam.New(const V: Integer): TSmartParam;
begin Result.SetValue(V); end;

class function TSmartParam.New(const V: string): TSmartParam;
begin Result.SetValue(V); end;

class function TSmartParam.New(const V: Double): TSmartParam;
begin Result.SetValue(V); end;

class function TSmartParam.New(const V: Boolean): TSmartParam;
begin Result.SetValue(V); end;

class function TSmartParam.New(const V: TDateTime): TSmartParam;
begin Result.SetValue(V); end;

class function TSmartParam.New(const V: Variant): TSmartParam;
begin Result.SetValue(V); end;

class function TSmartParam.New(const V: TObject): TSmartParam;
begin Result.SetValue(V); end;

class function TSmartParam.New(const V: IInterface): TSmartParam;
begin Result.SetValue(V); end;

class operator TSmartParam.Implicit(const AParm: TSmartParam): Integer;
begin Result := AParm.AsInteger; end;

class operator TSmartParam.Implicit(const AParm: TSmartParam): Double;
begin Result := AParm.AsFloat; end;

class operator TSmartParam.Implicit(const AParm: TSmartParam): string;
begin Result := AParm.AsString; end;

class operator TSmartParam.Implicit(const AParm: TSmartParam): Boolean;
begin Result := AParm.AsBoolean; end;

class operator TSmartParam.Implicit(const AParm: TSmartParam): TDateTime;
begin Result := AParm.AsDateTime; end;

{ TSmartCache }

constructor TSmartCache.Create(const AThreadSafe: Boolean);
begin
  inherited Create;
  FThreadSafe := AThreadSafe;
  FDic := TDictionary<string, TSmartParam>.Create;
  FDicEvents := TObjectDictionary<string, TList<TParamChangeEvent>>.Create([doOwnsValues]);
end;

destructor TSmartCache.Destroy;
begin
  FreeAndNil(FDicEvents);
  FreeAndNil(FDic);
  // FLock (TRWLock) record — Free gerekmez
  inherited Destroy;
end;

procedure TSmartCache.BeginRead;
begin
  if FThreadSafe then FLock.ReadOnlyLock;
end;

procedure TSmartCache.EndRead;
begin
  if FThreadSafe then FLock.ReadOnlyUnLock;
end;

procedure TSmartCache.BeginWrite;
begin
  if FThreadSafe then FLock.WriteLock;
end;

procedure TSmartCache.EndWrite;
begin
  if FThreadSafe then FLock.WriteUnlock;
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

class function TSmartCache.ParamsEqual(const A, B: TSmartParam): Boolean;
begin
  // Naif `A.FValue = B.FValue` Variant karsilastirmasi tip donusumu deneyip
  // EVariantError firlatabilir; VarSameValue tip-farkindalikli ve guvenli.
  if A.FvType <> B.FvType then
    Exit(False);

  if (A.FvType = varEmpty) or (A.FvType = varNull) then
    Exit(True);

  try
    Result := VarSameValue(A.FValue, B.FValue);
  except
    on E: EVariantError do
      Result := False;
  end;
end;

function TSmartCache.FireEvents(const AKey: string;
  const AOldParam, ANewParam: TSmartParam): Boolean;
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
      if not LGlobalEvent(AKey, AOldParam.vType, AOldParam.Value, ANewParam.Value) then
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
      if not LEvent(AKey, AOldParam.vType, AOldParam.Value, ANewParam.Value) then
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

function TSmartCache.AddOrSet(const AKey: string; const V: TSmartParam): Boolean;
var
  OldParam       : TSmartParam;
  CurrentParam   : TSmartParam;
  HasOldParam    : Boolean;
  HasCurrentParam: Boolean;
begin
  // İyimser eşzamanlılık (CAS): callback'ler kilit dışında çalışır; yazım
  // öncesi anlık görüntünün hâlâ geçerli olduğu doğrulanır, değilse tekrar
  // dener. Bu yüzden callback'ler yan etkisiz/idempotent olmalıdır.
  repeat
    BeginRead;
    try
      HasOldParam := FDic.TryGetValue(AKey, OldParam);
    finally
      EndRead;
    end;

    if HasOldParam and ParamsEqual(OldParam, V) then
      Exit(True);

    if not HasOldParam then
      OldParam.SetNull;

    if not FireEvents(AKey, OldParam, V) then
      Exit(False);

    BeginWrite;
    try
      HasCurrentParam := FDic.TryGetValue(AKey, CurrentParam);

      if HasCurrentParam and ParamsEqual(CurrentParam, V) then
        Exit(True);

      if (HasCurrentParam = HasOldParam) and
         ((not HasCurrentParam) or ParamsEqual(CurrentParam, OldParam)) then
      begin
        FDic.AddOrSetValue(AKey, V);
        Exit(True);
      end;
    finally
      EndWrite;
    end;
  until False;
end;

function TSmartCache.Get(const AKey: string; const ADefault: TSmartParam): TSmartParam;
begin
  BeginRead;
  try
    if not FDic.TryGetValue(AKey, Result) then
      Result := ADefault;
  finally
    EndRead;
  end;
end;

function TSmartCache.Get(const AKey: string; const ADefault: Integer): Integer;
begin
  Result := Get(AKey, TSmartParam.New(ADefault)).AsInteger;
end;

function TSmartCache.Get(const AKey: string; const ADefault: Double): Double;
begin
  Result := Get(AKey, TSmartParam.New(ADefault)).AsFloat;
end;

function TSmartCache.Get(const AKey, ADefault: string): string;
begin
  Result := Get(AKey, TSmartParam.New(ADefault)).AsString;
end;

function TSmartCache.Get(const AKey: string; const ADefault: Boolean): Boolean;
begin
  Result := Get(AKey, TSmartParam.New(ADefault)).AsBoolean;
end;

function TSmartCache.Get(const AKey: string; const ADefault: TDateTime): TDateTime;
begin
  Result := Get(AKey, TSmartParam.New(ADefault)).AsDateTime;
end;

function TSmartCache.Get(const AKey: string; const ADefault: Variant): Variant;
begin
  Result := Get(AKey, TSmartParam.New(ADefault)).Value;
end;

function TSmartCache.GetOrAdd(const AKey: string; const AParam: TSmartParam): TSmartParam;
begin
  BeginWrite;
  try
    if not FDic.TryGetValue(AKey, Result) then
    begin
      FDic.Add(AKey, AParam);
      Result := AParam;
    end;
  finally
    EndWrite;
  end;
end;

function TSmartCache.TryGetValue(const AKey: string; out AParam: TSmartParam): Boolean;
begin
  BeginRead;
  try
    Result := FDic.TryGetValue(AKey, AParam);
  finally
    EndRead;
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

procedure TSmartCache.ForEach(const AProc: TProc<string, TSmartParam>);
var
  LocalCopy: TArray<TPair<string, TSmartParam>>;
  Pair     : TPair<string, TSmartParam>;
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

function TSmartCache.AddOrSet(const AKey: string; const V: Integer): Boolean;
begin Result := AddOrSet(AKey, TSmartParam.New(V)); end;

function TSmartCache.AddOrSet(const AKey: string; const V: Double): Boolean;
begin Result := AddOrSet(AKey, TSmartParam.New(V)); end;

function TSmartCache.AddOrSet(const AKey, V: string): Boolean;
begin Result := AddOrSet(AKey, TSmartParam.New(V)); end;

function TSmartCache.AddOrSet(const AKey: string; const V: Boolean): Boolean;
begin Result := AddOrSet(AKey, TSmartParam.New(V)); end;

function TSmartCache.AddOrSet(const AKey: string; const V: TDateTime): Boolean;
begin Result := AddOrSet(AKey, TSmartParam.New(V)); end;

function TSmartCache.AddOrSet(const AKey: string; const V: Variant): Boolean;
begin Result := AddOrSet(AKey, TSmartParam.New(V)); end;

function TSmartCache.AddOrSet(const AKey: string; const V: TObject): Boolean;
begin Result := AddOrSet(AKey, TSmartParam.New(V)); end;

function TSmartCache.AddOrSet(const AKey: string; const V: IInterface): Boolean;
begin Result := AddOrSet(AKey, TSmartParam.New(V)); end;

end.
