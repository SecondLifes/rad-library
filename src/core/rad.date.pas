unit rad.date;

{
  Rad Core DateTime bileşeni — dört bağımsız "sütun" (pillar) birleştirir:

    A. TDtElapsed  — tip-güvenli, çoklu saat kaynaklı geçen-süre ölçümü.
       Kaynak: vendor\gabr42\GpDelphiUnits\src\GpTimestamp.pas (neredeyse birebir).
       DSiWin32 bağımlılığı kaldırıldı; Windows-only fabrika metodları doğrudan
       Winapi.Windows/Winapi.MMSystem kullanıyor.

    B. TDtInterval  — takvimsel süre (yıl/ay/gün/saat/dakika/saniye/ms).
       Kaynak: vendor\qdac\3.0\Source\qtimetypes.pas TQInterval (QStringW arındırıldı,
       Inc* metodları pointer-mutate yerine by-value dönüyor).

    C. TDtTimeZone  — Local↔UTC + keyfi isimli (Windows TzId) timezone dönüşümü.
       Kaynak: mormot.core.search.pas TSynTimeZone (bkz. docs\vendor\synopse\mORMot2\
       src\core\mormot.core.search.md). GpTimezone.pas'ın registry portu BİLİNÇLİ
       OLARAK atlandı — TSynTimeZone aynı problemi zaten cross-platform + thread-safe
       çözüyor (vendor-first: "mORMot2 bir özelliği sağlıyorsa onu kullan").
       ATzId boş bırakılırsa RTL TTimeZone.Local (yerel makine) kullanılır.

    D. TDtSchedule  — Quartz-tarzı, 7 alanlı (Second Minute Hour DayOfMonth Month
       DayOfWeek Year) tekrarlayan zaman planı maskesi.
       Kaynak: vendor\qdac\3.0\Source\qtimetypes.pas TQPlanMask (grameri aynen
       korundu: * ? - / L , # W token'ları — bkz. qtimetypes.pas satır 4825+
       SetAsString implementasyonu), ama standart string ile YENİDEN yazıldı
       (QDAC'ın QStringW'sine bağımlılık yok).

  Bu dört sütun kasıtlı olarak birleştirilmedi: TDtElapsed sabit-nanosaniye fiziksel
  süre (ölçüm kaynağına bağlı), TDtInterval değişken-uzunluklu takvimsel süredir —
  ortak taban zorlamak ikisini de anlamsızlaştırır.

  mORMot2 tabanlı Unix/TimeLog/ISO8601/iş-günü fonksiyonları BU dosyada DEĞİL,
  ayrı help.date.pas'ta (bkz. docs\help.date.md) — bu dosya sadece RTL +
  Winapi + mormot.core.search (TSynTimeZone) kullanır.
}

interface

uses
  System.SysUtils, System.DateUtils, System.Classes, System.TimeSpan,
  System.Diagnostics,
  {$IFDEF MSWINDOWS}
  Winapi.Windows, Winapi.MMSystem,
  {$ENDIF}
  mormot.core.search;

type
  { ===================== A. TDtElapsed ===================== }

  /// hangi saat kaynağından ölçüldüğünü belirtir
  TDtTimeSource = (
    tsNone,                    // başlatılmamış
    tsTickCount,               // GetTickCount64 - milisaniye çözünürlük (Windows)
    tsQueryPerformanceCounter, // QueryPerformanceCounter - yüksek hassasiyet (Windows)
    tsTimeGetTime,             // timeGetTime - milisaniye çözünürlük (Windows)
    tsStopwatch,               // TStopwatch - cross-platform yüksek hassasiyet
    tsDateTime,                // TDateTime tabanlı
    tsDuration                 // saf süre/fark, her kaynakla uyumlu
  );

  /// tip-güvenli geçen-süre ölçümü: farklı saat kaynaklarını birbirine karıştırma
  /// hatasını (ör. TickCount - QPC) çalışma zamanında EInvalidOpException ile yakalar
  TDtElapsed = record
  strict private
    FValue: Int64;         // nanosaniye
    FTimeSource: TDtTimeSource;
    procedure CheckCompatible(const AOther: TDtElapsed);
    {$IFDEF MSWINDOWS}
    class function GetPerformanceFrequency: Int64; static; inline;
    {$ENDIF}
  public
    class function Now: TDtElapsed; static;
    class function FromStopwatch: TDtElapsed; overload; static;
    class function FromStopwatch(AValue: Int64): TDtElapsed; overload; static;
    class function FromDateTime: TDtElapsed; overload; static;
    class function FromDateTime(ADt: TDateTime): TDtElapsed; overload; static;
    {$IFDEF MSWINDOWS}
    class function FromTickCount: TDtElapsed; overload; static;
    class function FromTickCount(AValueMs: Int64): TDtElapsed; overload; static;
    class function FromQueryPerformanceCounter: TDtElapsed; overload; static;
    class function FromQueryPerformanceCounter(AValue: Int64): TDtElapsed; overload; static;
    class function FromTimeGetTime: TDtElapsed; overload; static;
    class function FromTimeGetTime(AValueMs: Int64): TDtElapsed; overload; static;
    {$ENDIF}
    class function Create(ATimeSource: TDtTimeSource; AValueNs: Int64): TDtElapsed; static;
    class function Nanoseconds(ANs: Int64): TDtElapsed; static;
    class function Microseconds(AUs: Int64): TDtElapsed; static;
    class function Milliseconds(AMs: Int64): TDtElapsed; static;
    class function Seconds(ASec: Double): TDtElapsed; static;
    class function Minutes(AMin: Int64): TDtElapsed; static;
    class function Hours(AHour: Int64): TDtElapsed; static;
    class function Zero(ASource: TDtTimeSource): TDtElapsed; static;
    class function Invalid: TDtElapsed; static;

    function ToMilliseconds: Int64; inline;
    function ToMicroseconds: Int64; inline;
    function ToNanoseconds: Int64; inline;
    function ToSeconds: Double; inline;
    function ToDateTime: TDateTime;
    function ToString: string;
    function IsValid: Boolean; inline;
    function IsDuration: Boolean; inline;

    /// timeout_ms doldu mu? (geçersiz zaman damgasında True döner — lazy-init için)
    function HasElapsed(ATimeoutMs: Int64): Boolean; overload;
    function HasElapsed(const ADuration: TDtElapsed): Boolean; overload;
    /// deadline'a kadar süre var mı? (geçersizse False döner)
    function HasRemaining(ATimeoutMs: Int64): Boolean; overload;
    function HasRemaining(const ADuration: TDtElapsed): Boolean; overload;
    /// bu zaman damgasından bu yana geçen süreyi (tsDuration) döner
    function Elapsed: TDtElapsed;

    class operator Add(const A, B: TDtElapsed): TDtElapsed;
    class operator Subtract(const A, B: TDtElapsed): TDtElapsed;
    class function Min(const A, B: TDtElapsed): TDtElapsed; static;
    class function Max(const A, B: TDtElapsed): TDtElapsed; static;
    class operator GreaterThan(const A, B: TDtElapsed): Boolean;
    class operator LessThan(const A, B: TDtElapsed): Boolean;
    class operator GreaterThanOrEqual(const A, B: TDtElapsed): Boolean;
    class operator LessThanOrEqual(const A, B: TDtElapsed): Boolean;
    class operator Equal(const A, B: TDtElapsed): Boolean;
    class operator NotEqual(const A, B: TDtElapsed): Boolean;

    property TimeSource: TDtTimeSource read FTimeSource;
    property ValueNs: Int64 read FValue;
  end;

  { ===================== B. TDtInterval ===================== }

  /// takvimsel süre (yıl/ay değişken uzunluklu, TDtElapsed'in aksine)
  TDtInterval = record
  strict private
    FYear, FMonth, FDay: Integer;
    FHour, FMinute, FSecond, FMilliSecond: Integer;
    function GetIsZero: Boolean;
    function GetIsNeg: Boolean;
  public
    class function EncodeInterval(AYear, AMonth, ADay, AHour, AMinute, ASecond,
      AMilliSecond: Integer): TDtInterval; overload; static;
    class function EncodeInterval(AYear, AMonth: Integer): TDtInterval; overload; static;
    class function EncodeInterval(ADay, AHour, AMinute, ASecond: Integer): TDtInterval; overload; static;

    procedure Clear;
    function IncYear(AYear: Integer = 1): TDtInterval;
    function IncMonth(AMonth: Integer = 1): TDtInterval;
    function IncDay(ADay: Integer = 1): TDtInterval;
    function IncHour(AHour: Integer = 1): TDtInterval;
    function IncMinute(AMinute: Integer = 1): TDtInterval;
    function IncSecond(ASecond: Integer = 1): TDtInterval;
    function IncMilliSecond(AMilliSecond: Integer = 1): TDtInterval;

    function AsISOString: string;

    class operator Add(const ADate: TDateTime; const AInterval: TDtInterval): TDateTime;
    class operator Add(const AInterval: TDtInterval; const ADate: TDateTime): TDateTime;
    class operator Add(const A, B: TDtInterval): TDtInterval;
    class operator Subtract(const ADate: TDateTime; const AInterval: TDtInterval): TDateTime;
    class operator Subtract(const A, B: TDtInterval): TDtInterval;
    class operator Equal(const A, B: TDtInterval): Boolean;
    class operator NotEqual(const A, B: TDtInterval): Boolean;

    property Year: Integer read FYear write FYear;
    property Month: Integer read FMonth write FMonth;
    property Day: Integer read FDay write FDay;
    property Hour: Integer read FHour write FHour;
    property Minute: Integer read FMinute write FMinute;
    property Second: Integer read FSecond write FSecond;
    property MilliSecond: Integer read FMilliSecond write FMilliSecond;
    property IsZero: Boolean read GetIsZero;
    property IsNeg: Boolean read GetIsNeg;
  end;

  { ===================== C. TDtTimeZone ===================== }

  /// Local<->UTC dönüşümü: ATzId boşsa yerel makine (RTL TTimeZone.Local),
  /// doluysa mORMot2 TSynTimeZone (keyfi isimli Windows TzId, ör. 'Turkey Standard Time')
  TDtTimeZone = class
  public
    class function ToUtc(const ALocal: TDateTime; const ATzId: string = ''): TDateTime; static;
    class function FromUtc(const AUtc: TDateTime; const ATzId: string = ''): TDateTime; static;
    class function NowInZone(const ATzId: string): TDateTime; static;
    class function GetBias(const AValue: TDateTime; const ATzId: string;
      out ABias: Integer; out AHaveDaylight: Boolean): Boolean; static;
    class function GetDisplay(const ATzId: string): string; static;
    class function Zones: TStrings; static;
    class function ZoneDisplays: TStrings; static;
    {$IFDEF MSWINDOWS}
    class procedure ChangeOperatingSystemTimeZone(const ATzId: string); static;
    {$ENDIF}
  end;

  { ===================== D. TDtSchedule ===================== }

  TDtScheduleField = (sfSecond, sfMinute, sfHour, sfDayOfMonth, sfMonth, sfDayOfWeek, sfYear);

  TDtScheduleTimeoutResult = (soOk, soNotArrived, soTimeout, soExpired);

  /// tek bir maske parçası: sabit değer, aralık, interval veya özel (L/W/#) durum
  TDtScheduleLimit = record
    IsAny: Boolean;           // '*'
    Start, Stop: Integer;     // aralık (Start=Stop ise tek değer)
    Step: Integer;            // 0 = adım yok, >0 = '/N'
    IsLast: Boolean;          // 'L' (ayın son günü, ya da DayOfWeek ile son X günü)
    NthOccurrence: Integer;   // '#' (ayın N'inci X günü); 0 = kullanılmıyor
    IsNearestWeekday: Boolean;// 'W' (en yakın iş günü)
  end;
  TDtScheduleLimitArray = array of TDtScheduleLimit;

  /// Quartz-tarzı cron maskesi: "Second Minute Hour DayOfMonth Month DayOfWeek [Year]"
  /// Token'lar: * (any) ? (ignore) - (range) / (interval) L (last) , (list)
  ///            # (Nth weekday-of-month, sadece DayOfWeek) W (nearest workday, sadece DayOfMonth)
  TDtSchedule = record
  strict private
    FLimits: array[TDtScheduleField] of TDtScheduleLimitArray;
    FAsString: string;
    function FieldMatches(AField: TDtScheduleField; AValue: Word; const AWhen: TDateTime): Boolean;
    procedure ParseField(AField: TDtScheduleField; const AToken: string);
    /// sadece TARİH alanlarını (AyınGünü/Ay/HaftaGünü/Yıl) kontrol eder — saat/dakika/
    /// saniyeye bakmaz. NextTime'ın gün-bazlı hızlı atlaması için kullanılır.
    function DateFieldsMatch(const ADate: TDateTime): Boolean;
  public
    class function Create(const AMask: string): TDtSchedule; static;
    procedure SetAsString(const AMask: string);
    function GetAsString: string;
    property AsString: string read GetAsString write SetAsString;

    function Accept(const AWhen: TDateTime): Boolean;
    function NextTime(const AAfter: TDateTime; AMaxDaysSearch: Integer = 3660): TDateTime;
    function Timeout(const AWhen, ADeadline: TDateTime): TDtScheduleTimeoutResult;
  end;

  /// varsayılan iş-günü kontrolü (Cumartesi/Pazar hariç); TDtSchedule 'W' token'ında kullanılır
  TDtWorkDayFunction = reference to function(ADate: TDateTime): Boolean;

function DtDefaultIsWorkDay(ADate: TDateTime): Boolean;

var
  DtIsWorkDay: TDtWorkDayFunction = nil; // nil ise DtDefaultIsWorkDay kullanılır

implementation

{ TDtElapsed }

const
  NsPerMicrosecond = 1000;
  NsPerMillisecond = 1000000;
  NsPerSecond      = 1000000000;
  NsPerDay: Int64  = Int64(86400) * 1000000000;
  DtElapsedEpoch: TDateTime = 45638.0; // 2025-12-12, GpTimestamp ile aynı epoch mantığı

procedure TDtElapsed.CheckCompatible(const AOther: TDtElapsed);
begin
  if (FTimeSource = tsDuration) or (AOther.FTimeSource = tsDuration) then
    Exit;
  if (FTimeSource <> tsNone) and (FTimeSource = AOther.FTimeSource) then
    Exit;
  raise EInvalidOpException.CreateFmt(
    'Uyumsuz zaman ölçümleri karıştırılamaz: [Source=%d] vs [Source=%d]',
    [Ord(FTimeSource), Ord(AOther.FTimeSource)]);
end;

{$IFDEF MSWINDOWS}
class function TDtElapsed.GetPerformanceFrequency: Int64;
begin
  QueryPerformanceFrequency(Result);
end;

class function TDtElapsed.FromTickCount: TDtElapsed;
begin
  Result := FromTickCount(GetTickCount64);
end;

class function TDtElapsed.FromTickCount(AValueMs: Int64): TDtElapsed;
begin
  Result.FTimeSource := tsTickCount;
  Result.FValue := AValueMs * NsPerMillisecond;
end;

class function TDtElapsed.FromQueryPerformanceCounter: TDtElapsed;
var
  LCounter: Int64;
begin
  QueryPerformanceCounter(LCounter);
  Result := FromQueryPerformanceCounter(LCounter);
end;

class function TDtElapsed.FromQueryPerformanceCounter(AValue: Int64): TDtElapsed;
begin
  Result.FTimeSource := tsQueryPerformanceCounter;
  Result.FValue := Round(AValue / GetPerformanceFrequency * NsPerSecond);
end;

class function TDtElapsed.FromTimeGetTime: TDtElapsed;
begin
  Result := FromTimeGetTime(timeGetTime);
end;

class function TDtElapsed.FromTimeGetTime(AValueMs: Int64): TDtElapsed;
begin
  Result.FTimeSource := tsTimeGetTime;
  Result.FValue := AValueMs * NsPerMillisecond;
end;
{$ENDIF}

class function TDtElapsed.FromStopwatch: TDtElapsed;
begin
  Result := FromStopwatch(TStopwatch.GetTimeStamp);
end;

class function TDtElapsed.FromStopwatch(AValue: Int64): TDtElapsed;
begin
  Result.FTimeSource := tsStopwatch;
  Result.FValue := Round(AValue / TStopwatch.Frequency * NsPerSecond);
end;

class function TDtElapsed.FromDateTime: TDtElapsed;
begin
  Result := FromDateTime(TTimeZone.Local.ToUniversalTime(System.SysUtils.Now));
end;

class function TDtElapsed.FromDateTime(ADt: TDateTime): TDtElapsed;
begin
  Result.FTimeSource := tsDateTime;
  Result.FValue := Round((ADt - DtElapsedEpoch) * NsPerDay);
end;

class function TDtElapsed.Now: TDtElapsed;
begin
  Result := FromStopwatch;
end;

class function TDtElapsed.Create(ATimeSource: TDtTimeSource; AValueNs: Int64): TDtElapsed;
begin
  Result.FTimeSource := ATimeSource;
  Result.FValue := AValueNs;
end;

class function TDtElapsed.Nanoseconds(ANs: Int64): TDtElapsed;
begin
  Result.FTimeSource := tsDuration;
  Result.FValue := ANs;
end;

class function TDtElapsed.Microseconds(AUs: Int64): TDtElapsed;
begin
  Result.FTimeSource := tsDuration;
  Result.FValue := AUs * NsPerMicrosecond;
end;

class function TDtElapsed.Milliseconds(AMs: Int64): TDtElapsed;
begin
  Result.FTimeSource := tsDuration;
  Result.FValue := AMs * NsPerMillisecond;
end;

class function TDtElapsed.Seconds(ASec: Double): TDtElapsed;
begin
  Result.FTimeSource := tsDuration;
  Result.FValue := Round(ASec * NsPerSecond);
end;

class function TDtElapsed.Minutes(AMin: Int64): TDtElapsed;
begin
  Result.FTimeSource := tsDuration;
  Result.FValue := AMin * 60 * NsPerSecond;
end;

class function TDtElapsed.Hours(AHour: Int64): TDtElapsed;
begin
  Result.FTimeSource := tsDuration;
  Result.FValue := AHour * 3600 * NsPerSecond;
end;

class function TDtElapsed.Zero(ASource: TDtTimeSource): TDtElapsed;
begin
  Result.FTimeSource := ASource;
  Result.FValue := 0;
end;

class function TDtElapsed.Invalid: TDtElapsed;
begin
  Result.FTimeSource := tsNone;
  Result.FValue := 0;
end;

function TDtElapsed.ToMilliseconds: Int64;
begin
  Result := FValue div NsPerMillisecond;
end;

function TDtElapsed.ToMicroseconds: Int64;
begin
  Result := FValue div NsPerMicrosecond;
end;

function TDtElapsed.ToNanoseconds: Int64;
begin
  Result := FValue;
end;

function TDtElapsed.ToSeconds: Double;
begin
  Result := FValue / NsPerSecond;
end;

function TDtElapsed.ToDateTime: TDateTime;
begin
  Result := (FValue / NsPerDay) + DtElapsedEpoch;
end;

function TDtElapsed.ToString: string;
begin
  if FTimeSource = tsNone then
    Exit('Invalid');
  if Abs(FValue) >= NsPerSecond then
    Result := Format('%.6fs', [FValue / NsPerSecond])
  else
    Result := Format('%.3fms', [FValue / NsPerMillisecond]);
end;

function TDtElapsed.IsValid: Boolean;
begin
  Result := FTimeSource <> tsNone;
end;

function TDtElapsed.IsDuration: Boolean;
begin
  Result := FTimeSource = tsDuration;
end;

function TDtElapsed.HasElapsed(ATimeoutMs: Int64): Boolean;
begin
  Result := HasElapsed(TDtElapsed.Milliseconds(ATimeoutMs));
end;

function TDtElapsed.HasElapsed(const ADuration: TDtElapsed): Boolean;
begin
  if ADuration.FTimeSource <> tsDuration then
    raise EInvalidOpException.Create('HasElapsed: ADuration.TimeSource = tsDuration olmalı');
  if FTimeSource = tsNone then
    Exit(True);
  Result := Elapsed.FValue >= ADuration.FValue;
end;

function TDtElapsed.HasRemaining(ATimeoutMs: Int64): Boolean;
begin
  Result := HasRemaining(TDtElapsed.Milliseconds(ATimeoutMs));
end;

function TDtElapsed.HasRemaining(const ADuration: TDtElapsed): Boolean;
begin
  if ADuration.FTimeSource <> tsDuration then
    raise EInvalidOpException.Create('HasRemaining: ADuration.TimeSource = tsDuration olmalı');
  if FTimeSource = tsNone then
    Exit(False);
  Result := -Elapsed.FValue >= ADuration.FValue;
end;

function TDtElapsed.Elapsed: TDtElapsed;
var
  LNow: TDtElapsed;
begin
  case FTimeSource of
    {$IFDEF MSWINDOWS}
    tsTickCount: LNow := FromTickCount;
    tsQueryPerformanceCounter: LNow := FromQueryPerformanceCounter;
    tsTimeGetTime: LNow := FromTimeGetTime;
    {$ENDIF}
    tsStopwatch: LNow := FromStopwatch;
    tsDateTime: LNow := FromDateTime;
  else
    raise EInvalidOpException.CreateFmt('Elapsed bu kaynak için desteklenmiyor: %d', [Ord(FTimeSource)]);
  end;
  Result := LNow - Self;
end;

class operator TDtElapsed.Subtract(const A, B: TDtElapsed): TDtElapsed;
begin
  A.CheckCompatible(B);
  // duration - timestamp geçersiz
  if (A.FTimeSource = tsDuration) and (B.FTimeSource <> tsDuration) then
    raise EInvalidOpException.Create('duration - timestamp geçersiz işlem');
  // timestamp - timestamp = duration, duration - duration = duration
  if (A.FTimeSource = tsDuration) = (B.FTimeSource = tsDuration) then
    Result.FTimeSource := tsDuration
  else
    // timestamp - duration = timestamp (A'nın kaynağı korunur)
    Result.FTimeSource := A.FTimeSource;
  Result.FValue := A.FValue - B.FValue;
end;

class operator TDtElapsed.Add(const A, B: TDtElapsed): TDtElapsed;
begin
  A.CheckCompatible(B);
  if (A.FTimeSource <> tsDuration) and (B.FTimeSource <> tsDuration) then
    raise EInvalidOpException.Create('timestamp + timestamp geçersiz işlem; sadece timestamp + duration');
  if (A.FTimeSource = tsDuration) and (B.FTimeSource = tsDuration) then
    Result.FTimeSource := tsDuration
  else if A.FTimeSource <> tsDuration then
    Result.FTimeSource := A.FTimeSource
  else
    Result.FTimeSource := B.FTimeSource;
  Result.FValue := A.FValue + B.FValue;
end;

class function TDtElapsed.Min(const A, B: TDtElapsed): TDtElapsed;
begin
  A.CheckCompatible(B);
  if A.FValue <= B.FValue then Result := A else Result := B;
end;

class function TDtElapsed.Max(const A, B: TDtElapsed): TDtElapsed;
begin
  A.CheckCompatible(B);
  if A.FValue >= B.FValue then Result := A else Result := B;
end;

class operator TDtElapsed.GreaterThan(const A, B: TDtElapsed): Boolean;
begin
  A.CheckCompatible(B);
  Result := A.FValue > B.FValue;
end;

class operator TDtElapsed.LessThan(const A, B: TDtElapsed): Boolean;
begin
  A.CheckCompatible(B);
  Result := A.FValue < B.FValue;
end;

class operator TDtElapsed.GreaterThanOrEqual(const A, B: TDtElapsed): Boolean;
begin
  A.CheckCompatible(B);
  Result := A.FValue >= B.FValue;
end;

class operator TDtElapsed.LessThanOrEqual(const A, B: TDtElapsed): Boolean;
begin
  A.CheckCompatible(B);
  Result := A.FValue <= B.FValue;
end;

class operator TDtElapsed.Equal(const A, B: TDtElapsed): Boolean;
begin
  A.CheckCompatible(B);
  Result := A.FValue = B.FValue;
end;

class operator TDtElapsed.NotEqual(const A, B: TDtElapsed): Boolean;
begin
  A.CheckCompatible(B);
  Result := A.FValue <> B.FValue;
end;

{ TDtInterval }

class function TDtInterval.EncodeInterval(AYear, AMonth, ADay, AHour, AMinute,
  ASecond, AMilliSecond: Integer): TDtInterval;
begin
  Result.FYear := AYear;
  Result.FMonth := AMonth;
  Result.FDay := ADay;
  Result.FHour := AHour;
  Result.FMinute := AMinute;
  Result.FSecond := ASecond;
  Result.FMilliSecond := AMilliSecond;
end;

class function TDtInterval.EncodeInterval(AYear, AMonth: Integer): TDtInterval;
begin
  Result := EncodeInterval(AYear, AMonth, 0, 0, 0, 0, 0);
end;

class function TDtInterval.EncodeInterval(ADay, AHour, AMinute, ASecond: Integer): TDtInterval;
begin
  Result := EncodeInterval(0, 0, ADay, AHour, AMinute, ASecond, 0);
end;

procedure TDtInterval.Clear;
begin
  Self := EncodeInterval(0, 0, 0, 0, 0, 0, 0);
end;

function TDtInterval.IncYear(AYear: Integer): TDtInterval;
begin
  Result := Self;
  Inc(Result.FYear, AYear);
end;

function TDtInterval.IncMonth(AMonth: Integer): TDtInterval;
begin
  Result := Self;
  Inc(Result.FMonth, AMonth);
end;

function TDtInterval.IncDay(ADay: Integer): TDtInterval;
begin
  Result := Self;
  Inc(Result.FDay, ADay);
end;

function TDtInterval.IncHour(AHour: Integer): TDtInterval;
begin
  Result := Self;
  Inc(Result.FHour, AHour);
end;

function TDtInterval.IncMinute(AMinute: Integer): TDtInterval;
begin
  Result := Self;
  Inc(Result.FMinute, AMinute);
end;

function TDtInterval.IncSecond(ASecond: Integer): TDtInterval;
begin
  Result := Self;
  Inc(Result.FSecond, ASecond);
end;

function TDtInterval.IncMilliSecond(AMilliSecond: Integer): TDtInterval;
begin
  Result := Self;
  Inc(Result.FMilliSecond, AMilliSecond);
end;

function TDtInterval.GetIsZero: Boolean;
begin
  Result := (FYear = 0) and (FMonth = 0) and (FDay = 0) and (FHour = 0)
    and (FMinute = 0) and (FSecond = 0) and (FMilliSecond = 0);
end;

function TDtInterval.GetIsNeg: Boolean;
begin
  Result := (FYear < 0) or (FMonth < 0) or (FDay < 0) or (FHour < 0)
    or (FMinute < 0) or (FSecond < 0) or (FMilliSecond < 0);
end;

function TDtInterval.AsISOString: string;
begin
  Result := 'P';
  if FYear <> 0 then Result := Result + Format('%dY', [FYear]);
  if FMonth <> 0 then Result := Result + Format('%dM', [FMonth]);
  if FDay <> 0 then Result := Result + Format('%dD', [FDay]);
  if (FHour <> 0) or (FMinute <> 0) or (FSecond <> 0) or (FMilliSecond <> 0) then
  begin
    Result := Result + 'T';
    if FHour <> 0 then Result := Result + Format('%dH', [FHour]);
    if FMinute <> 0 then Result := Result + Format('%dM', [FMinute]);
    if (FSecond <> 0) or (FMilliSecond <> 0) then
    begin
      if FMilliSecond <> 0 then
        Result := Result + Format('%d.%3.3dS', [FSecond, Abs(FMilliSecond)])
      else
        Result := Result + Format('%dS', [FSecond]);
    end;
  end;
  if Result = 'P' then
    Result := 'P0D';
end;

class operator TDtInterval.Add(const ADate: TDateTime; const AInterval: TDtInterval): TDateTime;
begin
  Result := ADate;
  if AInterval.FYear <> 0 then Result := System.DateUtils.IncYear(Result, AInterval.FYear);
  if AInterval.FMonth <> 0 then Result := System.SysUtils.IncMonth(Result, AInterval.FMonth);
  if AInterval.FDay <> 0 then Result := System.DateUtils.IncDay(Result, AInterval.FDay);
  if AInterval.FHour <> 0 then Result := System.DateUtils.IncHour(Result, AInterval.FHour);
  if AInterval.FMinute <> 0 then Result := System.DateUtils.IncMinute(Result, AInterval.FMinute);
  if AInterval.FSecond <> 0 then Result := System.DateUtils.IncSecond(Result, AInterval.FSecond);
  if AInterval.FMilliSecond <> 0 then Result := System.DateUtils.IncMilliSecond(Result, AInterval.FMilliSecond);
end;

class operator TDtInterval.Add(const AInterval: TDtInterval; const ADate: TDateTime): TDateTime;
begin
  Result := ADate + AInterval;
end;

class operator TDtInterval.Add(const A, B: TDtInterval): TDtInterval;
begin
  Result := TDtInterval.EncodeInterval(A.FYear + B.FYear, A.FMonth + B.FMonth,
    A.FDay + B.FDay, A.FHour + B.FHour, A.FMinute + B.FMinute,
    A.FSecond + B.FSecond, A.FMilliSecond + B.FMilliSecond);
end;

class operator TDtInterval.Subtract(const ADate: TDateTime; const AInterval: TDtInterval): TDateTime;
begin
  Result := ADate + TDtInterval.EncodeInterval(-AInterval.FYear, -AInterval.FMonth,
    -AInterval.FDay, -AInterval.FHour, -AInterval.FMinute, -AInterval.FSecond, -AInterval.FMilliSecond);
end;

class operator TDtInterval.Subtract(const A, B: TDtInterval): TDtInterval;
begin
  Result := TDtInterval.EncodeInterval(A.FYear - B.FYear, A.FMonth - B.FMonth,
    A.FDay - B.FDay, A.FHour - B.FHour, A.FMinute - B.FMinute,
    A.FSecond - B.FSecond, A.FMilliSecond - B.FMilliSecond);
end;

class operator TDtInterval.Equal(const A, B: TDtInterval): Boolean;
begin
  Result := (A.FYear = B.FYear) and (A.FMonth = B.FMonth) and (A.FDay = B.FDay)
    and (A.FHour = B.FHour) and (A.FMinute = B.FMinute) and (A.FSecond = B.FSecond)
    and (A.FMilliSecond = B.FMilliSecond);
end;

class operator TDtInterval.NotEqual(const A, B: TDtInterval): Boolean;
begin
  Result := not (A = B);
end;

{ TDtTimeZone }

class function TDtTimeZone.ToUtc(const ALocal: TDateTime; const ATzId: string): TDateTime;
begin
  if ATzId = '' then
    Result := TTimeZone.Local.ToUniversalTime(ALocal)
  else
    Result := TSynTimeZone.Default.LocalToUtc(ALocal, ATzId);
end;

class function TDtTimeZone.FromUtc(const AUtc: TDateTime; const ATzId: string): TDateTime;
begin
  if ATzId = '' then
    Result := TTimeZone.Local.ToLocalTime(AUtc)
  else
    Result := TSynTimeZone.Default.UtcToLocal(AUtc, ATzId);
end;

class function TDtTimeZone.NowInZone(const ATzId: string): TDateTime;
begin
  if ATzId = '' then
    Result := System.SysUtils.Now
  else
    Result := TSynTimeZone.Default.NowToLocal(ATzId);
end;

class function TDtTimeZone.GetBias(const AValue: TDateTime; const ATzId: string;
  out ABias: Integer; out AHaveDaylight: Boolean): Boolean;
begin
  Result := TSynTimeZone.Default.GetBiasForDateTime(AValue, ATzId, ABias, AHaveDaylight);
end;

class function TDtTimeZone.GetDisplay(const ATzId: string): string;
begin
  Result := string(TSynTimeZone.Default.GetDisplay(ATzId));
end;

class function TDtTimeZone.Zones: TStrings;
begin
  Result := TSynTimeZone.Default.Ids;
end;

class function TDtTimeZone.ZoneDisplays: TStrings;
begin
  Result := TSynTimeZone.Default.Displays;
end;

{$IFDEF MSWINDOWS}
class procedure TDtTimeZone.ChangeOperatingSystemTimeZone(const ATzId: string);
begin
  TSynTimeZone.Default.ChangeOperatingSystemTimeZone(ATzId);
end;
{$ENDIF}

{ TDtSchedule }

function DtDefaultIsWorkDay(ADate: TDateTime): Boolean;
var
  LDow: Word;
begin
  LDow := System.SysUtils.DayOfWeek(ADate); // RTL: Pazar=1 .. Cumartesi=7
  Result := (LDow <> 1) and (LDow <> 7);
end;

function DtIsWorkDayCheck(ADate: TDateTime): Boolean;
begin
  if Assigned(DtIsWorkDay) then
    Result := DtIsWorkDay(ADate)
  else
    Result := DtDefaultIsWorkDay(ADate);
end;

const
  FieldMin: array[TDtScheduleField] of Integer = (0, 0, 0, 1, 1, 1, 1970);
  FieldMax: array[TDtScheduleField] of Integer = (59, 59, 23, 31, 12, 7, 2099);

procedure TDtSchedule.ParseField(AField: TDtScheduleField; const AToken: string);
var
  LParts: TArray<string>;
  LPart, LRangePart, LStepPart: string;
  LLimit: TDtScheduleLimit;
  LDashPos, LSlashPos, LHashPos: Integer;
begin
  SetLength(FLimits[AField], 0);
  LParts := AToken.Split([',']);
  for LPart in LParts do
  begin
    FillChar(LLimit, SizeOf(LLimit), 0);
    LRangePart := LPart;
    LSlashPos := Pos('/', LRangePart);
    if LSlashPos > 0 then
    begin
      LStepPart := Copy(LRangePart, LSlashPos + 1, MaxInt);
      LLimit.Step := StrToIntDef(LStepPart, 0);
      LRangePart := Copy(LRangePart, 1, LSlashPos - 1);
    end;

    if LRangePart = '*' then
    begin
      LLimit.IsAny := True;
      LLimit.Start := FieldMin[AField];
      LLimit.Stop := FieldMax[AField];
    end
    else if LRangePart = '?' then
    begin
      LLimit.IsAny := True;
      LLimit.Start := FieldMin[AField];
      LLimit.Stop := FieldMax[AField];
    end
    else if (LRangePart = 'L') and (AField = sfDayOfMonth) then
    begin
      LLimit.IsLast := True;
    end
    else
    begin
      LHashPos := Pos('#', LRangePart);
      if (LHashPos > 0) and (AField = sfDayOfWeek) then
      begin
        LLimit.Start := StrToIntDef(Copy(LRangePart, 1, LHashPos - 1), FieldMin[AField]);
        LLimit.Stop := LLimit.Start;
        LLimit.NthOccurrence := StrToIntDef(Copy(LRangePart, LHashPos + 1, MaxInt), 1);
      end
      else if (LRangePart.EndsWith('L')) and (AField = sfDayOfWeek) then
      begin
        LLimit.Start := StrToIntDef(Copy(LRangePart, 1, Length(LRangePart) - 1), FieldMin[AField]);
        LLimit.Stop := LLimit.Start;
        LLimit.IsLast := True;
      end
      else if (LRangePart.EndsWith('W')) and (AField = sfDayOfMonth) then
      begin
        LLimit.Start := StrToIntDef(Copy(LRangePart, 1, Length(LRangePart) - 1), FieldMin[AField]);
        LLimit.Stop := LLimit.Start;
        LLimit.IsNearestWeekday := True;
      end
      else
      begin
        LDashPos := Pos('-', LRangePart);
        if LDashPos > 1 then // >1: eksi işaretiyle karışmasın
        begin
          LLimit.Start := StrToIntDef(Copy(LRangePart, 1, LDashPos - 1), FieldMin[AField]);
          LLimit.Stop := StrToIntDef(Copy(LRangePart, LDashPos + 1, MaxInt), FieldMax[AField]);
        end
        else
        begin
          LLimit.Start := StrToIntDef(LRangePart, FieldMin[AField]);
          LLimit.Stop := LLimit.Start;
        end;
      end;
    end;
    SetLength(FLimits[AField], Length(FLimits[AField]) + 1);
    FLimits[AField][High(FLimits[AField])] := LLimit;
  end;
end;

procedure TDtSchedule.SetAsString(const AMask: string);
var
  LFields: TArray<string>;
  LField: TDtScheduleField;
begin
  FAsString := AMask;
  LFields := AMask.Trim.Split([' '], TStringSplitOptions.ExcludeEmpty);
  if Length(LFields) < 6 then
    raise EArgumentException.CreateFmt(
      'Geçersiz TDtSchedule maskesi: "%s" (en az 6 alan gerekli: Sn Dk Sa Gün Ay HaftaGünü [Yıl])', [AMask]);
  for LField := Low(TDtScheduleField) to High(TDtScheduleField) do
    ParseField(LField, '*');
  ParseField(sfSecond, LFields[0]);
  ParseField(sfMinute, LFields[1]);
  ParseField(sfHour, LFields[2]);
  ParseField(sfDayOfMonth, LFields[3]);
  ParseField(sfMonth, LFields[4]);
  ParseField(sfDayOfWeek, LFields[5]);
  if Length(LFields) >= 7 then
    ParseField(sfYear, LFields[6]);
end;

function TDtSchedule.GetAsString: string;
begin
  Result := FAsString;
end;

class function TDtSchedule.Create(const AMask: string): TDtSchedule;
begin
  Result.SetAsString(AMask);
end;

function TDtSchedule.FieldMatches(AField: TDtScheduleField; AValue: Word;
  const AWhen: TDateTime): Boolean;
var
  LLimit: TDtScheduleLimit;
  LDay, LMonth, LYear: Word;
  LLastDom: Word;
  LTargetDow, LCount: Integer;
  D: Word;
begin
  Result := False;
  for LLimit in FLimits[AField] do
  begin
    if LLimit.IsLast then
    begin
      if AField = sfDayOfMonth then
      begin
        DecodeDate(AWhen, LYear, LMonth, LDay);
        LLastDom := DaysInAMonth(LYear, LMonth);
        if AValue = LLastDom then Exit(True);
      end
      else if AField = sfDayOfWeek then
      begin
        // 'X L' = ayın son X günü (X: RTL DayOfWeek, Pazar=1..Cumartesi=7)
        if AValue <> LLimit.Start then Continue;
        DecodeDate(AWhen, LYear, LMonth, LDay);
        LLastDom := DaysInAMonth(LYear, LMonth);
        if (LDay + 7) > LLastDom then Exit(True);
      end;
      Continue;
    end;
    if LLimit.IsNearestWeekday and (AField = sfDayOfMonth) then
    begin
      DecodeDate(AWhen, LYear, LMonth, LDay);
      if (LDay = LLimit.Start) and DtIsWorkDayCheck(AWhen) then Exit(True);
      Continue;
    end;
    if (LLimit.NthOccurrence > 0) and (AField = sfDayOfWeek) then
    begin
      if AValue <> LLimit.Start then Continue;
      DecodeDate(AWhen, LYear, LMonth, LDay);
      LTargetDow := LLimit.Start;
      LCount := 0;
      for D := 1 to LDay do
      begin
        if System.SysUtils.DayOfWeek(EncodeDate(LYear, LMonth, D)) = LTargetDow then
          Inc(LCount);
      end;
      if LCount = LLimit.NthOccurrence then Exit(True);
      Continue;
    end;
    if (AValue >= LLimit.Start) and (AValue <= LLimit.Stop) then
    begin
      if LLimit.Step > 0 then
      begin
        if ((AValue - LLimit.Start) mod LLimit.Step) = 0 then
          Exit(True);
      end
      else
        Exit(True);
    end;
  end;
end;

function TDtSchedule.Accept(const AWhen: TDateTime): Boolean;
var
  LYear, LMonth, LDay, LHour, LMinute, LSecond, LMs: Word;
begin
  DecodeDate(AWhen, LYear, LMonth, LDay);
  DecodeTime(AWhen, LHour, LMinute, LSecond, LMs);
  Result :=
    FieldMatches(sfSecond, LSecond, AWhen) and
    FieldMatches(sfMinute, LMinute, AWhen) and
    FieldMatches(sfHour, LHour, AWhen) and
    FieldMatches(sfDayOfMonth, LDay, AWhen) and
    FieldMatches(sfMonth, LMonth, AWhen) and
    FieldMatches(sfDayOfWeek, System.SysUtils.DayOfWeek(AWhen), AWhen) and
    ((Length(FLimits[sfYear]) = 0) or FieldMatches(sfYear, LYear, AWhen));
end;

function TDtSchedule.DateFieldsMatch(const ADate: TDateTime): Boolean;
var
  LYear, LMonth, LDay: Word;
begin
  DecodeDate(ADate, LYear, LMonth, LDay);
  Result :=
    FieldMatches(sfDayOfMonth, LDay, ADate) and
    FieldMatches(sfMonth, LMonth, ADate) and
    FieldMatches(sfDayOfWeek, System.SysUtils.DayOfWeek(ADate), ADate) and
    ((Length(FLimits[sfYear]) = 0) or FieldMatches(sfYear, LYear, ADate));
end;

function TDtSchedule.NextTime(const AAfter: TDateTime; AMaxDaysSearch: Integer): TDateTime;
var
  LToday, LEndDate, LCandidateDay, LDayEnd, LSecondCandidate: TDateTime;
begin
  // PERFORMANS: eskiden burada saniye-saniye (86400 x AMaxDaysSearch potansiyel
  // iterasyon) brute-force arama yapılıyordu — seyrek eşleşen şemalarda (ör.
  // yılda bir kez) tek bir NextTime çağrısı onlarca milyon iterasyona, saniyeler
  // sürebiliyordu (bkz. rad.date.Tests.pas TDtScheduleBenchmarkleri, ölçülmüş
  // gerçek sonuç: ~31.4M saniyelik arama ~3.3sn sürdü). Artık dış döngü GÜN
  // bazında ilerliyor: bir gün Ay/AyınGünü/HaftaGünü/Yıl alanlarına uymuyorsa
  // o gün için hiç saniye taraması yapılmadan atlanıyor; saniye-saniye tarama
  // SADECE tarih alanları zaten eşleşen tek bir gün içinde (en fazla 86400
  // iterasyon) çalışıyor. Bu, QDAC'ın orijinal TQPlanMask.GetNextTime'ının
  // (source\vendor\qdac\3.0\Source\qtimetypes.pas) yıl/ay atlama fikrinden
  // ilham aldı, ama daha basit/güvenli (yıl/ay için ayrı taşıma mantığı
  // gerektirmeyen) bir uygulama — sonuç aynı, sadece "gün" en küçük atlama
  // birimi.
  Result := 0;
  LToday := Trunc(AAfter);
  LEndDate := AAfter + AMaxDaysSearch;
  LCandidateDay := LToday;
  while LCandidateDay <= LEndDate do
  begin
    if DateFieldsMatch(LCandidateDay) then
    begin
      if LCandidateDay = LToday then
        LSecondCandidate := IncSecond(AAfter, 1)
      else
        LSecondCandidate := LCandidateDay;
      LDayEnd := LCandidateDay + 1;
      while (LSecondCandidate < LDayEnd) and (LSecondCandidate <= LEndDate) do
      begin
        if Accept(LSecondCandidate) then
          Exit(LSecondCandidate);
        LSecondCandidate := IncSecond(LSecondCandidate, 1);
      end;
    end;
    LCandidateDay := LCandidateDay + 1;
  end;
end;

function TDtSchedule.Timeout(const AWhen, ADeadline: TDateTime): TDtScheduleTimeoutResult;
begin
  if Accept(AWhen) then
    Exit(soOk);
  if AWhen > ADeadline then
    Exit(soExpired);
  if NextTime(AWhen) > ADeadline then
    Exit(soTimeout);
  Result := soNotArrived;
end;

end.
