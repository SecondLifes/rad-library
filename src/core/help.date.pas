unit help.date;

{
  TDateTimeHelper — TDateTime için genel amaçlı record helper.

  Kaynaklar (delphi-helper-builder skill ile analiz edildi, bkz. docs\vendor\...):
    - mormot.core.datetime.pas (mORMot2)      — ISO8601/Unix/TimeLog, temel dönüşümler
    - mormot.core.search.pas (mORMot2)        — TSynTimeZone (keyfi isimli timezone)
    - GpTimestamp.pas / GpTimezone.pas        — DateEQ ailesi, FixDT
    - JclDateTime.pas (JEDI JCL)              — ISO hafta numarası, bileşen erişimi, FormatDateTime (ISO hafta token'ları: w/ww/i/ii/e/f — RTL'in FormatDateTime'ı bunları desteklemez)
    - JvDateUtil.pas (JEDI JVCL)              — göreli ay navigasyonu, Inc-ailesi
    - Quick.Commons.pas                       — ChangeDate/ChangeTime, Is-karşılaştırma
    - MiTeC_Datetime.pas                      — iş günü ailesi, işaretli-fark fonksiyonları
    - ESBPCSDateTime.pas                      — yaş hesabı, Today/Tomorrow/Yesterday
    - kbmMWDateTime.pas                       — göreli zaman metni fikri

  Büyük/karmaşık işler statik core fonksiyon + ince helper wrapper modeliyle
  yazıldı; performans için `inline` kullanıldı. RawUtf8/mORMot2 tipleri sadece
  implementation içinde kalır, public API standart `string` kullanır (bu
  proje henüz her yerde RawUtf8'e geçmediği için ergonomi önceliklendirildi).

  RİSKLİ: `_SetOperatingSystemDateTime` ve `_SetOperatingSystemTimeZone`
  GERÇEK sistem saatini/saat dilimini DEĞİŞTİRİR — dikkatli kullanılmalı.
}

interface

uses
  System.SysUtils, System.DateUtils, System.Classes,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  mormot.core.base, mormot.core.datetime, mormot.core.search;

type
  TDateTimeHelper = record helper for TDateTime
  public
    { ===== ISO-8601 ===== }
    // TDateTime değerini ISO-8601 metnine çevirir (ör. '2026-07-04T12:00:00').
    function _ToISO8601: string;
    // ISO-8601 metnine milisaniye hassasiyetiyle çevirir.
    function _ToISO8601MS: string;
    // ISO-8601'in tahsissiz (allocation-free), kompakt varyantını üretir.
    function _ToISO8601Short: string;
    // Sadece tarih kısmını ISO-8601 metnine çevirir (ör. '2026-07-04').
    function _ToISO8601Date: string;
    // Sadece saat kısmını ISO-8601 metnine çevirir (ör. 'T12:00:00').
    function _ToISO8601Time: string;
    // ISO-8601 metnini TDateTime'a çevirir (ters yön).
    class function _FromISO8601(const AText: string): TDateTime; static;
    // ISO-8601 tarih metnini TDate'e çevirir (ters yön).
    class function _FromISO8601Date(const AText: string): TDate; static;
    // ISO-8601 saat metnini TTime'a çevirir (ters yön).
    class function _FromISO8601Time(const AText: string): TTime; static;

    { ===== Unix / TTimeLog ===== }
    // Unix epoch'tan (1970-01-01 UTC) itibaren saniye cinsinden zaman damgasına çevirir.
    function _ToUnix: TUnixTime;
    // Unix epoch'tan itibaren milisaniye cinsinden zaman damgasına çevirir.
    function _ToUnixMS: TUnixMSTime;
    // mORMot2'nin bit-paketli TTimeLog (64-bit Int64) formatına çevirir.
    function _ToLog: TTimeLog;
    // Unix saniye zaman damgasından TDateTime üretir (ters yön).
    class function _FromUnix(const AUnix: TUnixTime): TDateTime; static;
    // Unix milisaniye zaman damgasından TDateTime üretir (ters yön).
    class function _FromUnixMS(const AUnixMS: TUnixMSTime): TDateTime; static;
    // TTimeLog değerinden TDateTime üretir (ters yön).
    class function _FromLog(const ALog: TTimeLog): TDateTime; static;
    // ISO-8601 metnini ara TDateTime adımı olmadan doğrudan TTimeLog'a çevirir.
    class function _LogFromISO8601Text(const AText: string): TTimeLog; static;

    { ===== Bileşen erişimi ===== }
    // Ayın günü (1-31).
    function _Day: Word; inline;
    // Yılın ayı (1-12).
    function _Month: Word; inline;
    // Yıl.
    function _Year: Word; inline;
    // Saat (0-23).
    function _Hour: Word; inline;
    // Dakika (0-59).
    function _Minute: Word; inline;
    // Saniye (0-59).
    function _Second: Word; inline;
    // Haftanın günü (1=Pazar..7=Cumartesi).
    function _DayOfWeek: Word; inline;
    // Yılın kaçıncı günü olduğu (1-366).
    function _DayOfYear: Word;
    // Yılın çeyreği (1-4).
    function _Quarter: Integer;
    // Yılın yarıyılı (1: Ocak-Haziran, 2: Temmuz-Aralık).
    function _Semester: Integer;
    // Yılın artık yıl olup olmadığı.
    function _IsLeapYear: Boolean; inline;
    // Ayın kaç gün çektiği.
    function _DaysInMonth: Word;
    // Ay bitimine kaç gün kaldığı.
    function _DaysLeftInMonth: Word;
    // Yıl bitimine (31 Aralık) kaç gün kaldığı.
    function _DaysLeftInYear: Word;

    { ===== Dönem sınırları ===== }
    // Günün başlangıcı (00:00:00.000).
    function _StartOfDay: TDateTime; inline;
    // Günün sonu (23:59:59.999).
    function _EndOfDay: TDateTime; inline;
    // İçinde bulunulan ISO haftasının Pazartesi günü (saat 00:00:00).
    function _StartOfWeek: TDateTime;
    // İçinde bulunulan ISO haftasının Pazar günü sonu.
    function _EndOfWeek: TDateTime;
    // Ayın ilk günü.
    function _StartOfMonth: TDateTime;
    // Ayın son günü sonu.
    function _EndOfMonth: TDateTime;
    // Çeyreğin ilk günü.
    function _StartOfQuarter: TDateTime;
    // Çeyreğin son günü sonu.
    function _EndOfQuarter: TDateTime;
    // Yılın ilk günü (1 Ocak).
    function _StartOfYear: TDateTime;
    // Yılın son günü sonu (31 Aralık).
    function _EndOfYear: TDateTime;
    // Cumartesi veya Pazar olup olmadığı.
    function _IsWeekend: Boolean; inline;

    { ===== ISO-8601 hafta numarası ===== }
    // ISO-8601 hafta numarası (1-53, "en yakın Perşembe" kuralına göre hesaplanır).
    function _ISOWeekNumber: Word;
    // Yılın ISO'ya göre 53 haftalı ("uzun") yıl olup olmadığı.
    function _IsISOLongYear: Boolean;
    // Verilen ISO yıl/hafta/gün bilgisinden TDateTime üretir (ters yön; ADayOfWeek: 1=Pazartesi).
    class function _FromISOWeek(AYear, AWeek: Word; ADayOfWeek: Word = 1): TDateTime; static;

    { ===== Karşılaştırma (1/10ms toleranslı — GpTimezone kaynaklı) ===== }
    // İki tarihi ~0.1ms toleransla eşit sayar (float yuvarlama hatalarına karşı).
    function _DateEQ(const AOther: TDateTime): Boolean;
    // Self, AOther'dan (toleranslı) küçük mü.
    function _DateLT(const AOther: TDateTime): Boolean;
    // Self, AOther'dan (toleranslı) küçük veya eşit mi.
    function _DateLE(const AOther: TDateTime): Boolean;
    // Self, AOther'dan (toleranslı) büyük mü.
    function _DateGT(const AOther: TDateTime): Boolean;
    // Self, AOther'dan (toleranslı) büyük veya eşit mi.
    function _DateGE(const AOther: TDateTime): Boolean;
    // Float yuvarlama hatalarını düzeltir (en yakın milisaniyeye yuvarlar).
    function _FixDT: TDateTime;
    // İki tarih arasındaki tam gün sayısı (mutlak değer).
    function _DaysBetween(const AOther: TDateTime): Integer; inline;
    // İki tarih arasındaki tam ay sayısı.
    function _MonthsBetween(const AOther: TDateTime): Integer; inline;
    // İki tarih arasındaki tam yıl sayısı.
    function _YearsBetween(const AOther: TDateTime): Integer; inline;

    { ===== Ekleme/çıkarma (varsayılan=1) ===== }
    // Gün ekler/çıkarır (varsayılan +1).
    function _IncDay(AValue: Integer = 1): TDateTime; inline;
    // Ay ekler/çıkarır; hedef ayda o gün yoksa ayın son gününe sabitler (RTL IncMonth davranışı).
    function _IncMonth(AValue: Integer = 1): TDateTime; inline;
    // Yıl ekler/çıkarır.
    function _IncYear(AValue: Integer = 1): TDateTime; inline;
    // Saat ekler/çıkarır.
    function _IncHour(AValue: Integer = 1): TDateTime; inline;
    // Dakika ekler/çıkarır.
    function _IncMinute(AValue: Integer = 1): TDateTime; inline;
    // Saniye ekler/çıkarır.
    function _IncSecond(AValue: Integer = 1): TDateTime; inline;
    // Saati koruyarak tarihi değiştirir.
    function _ChangeDate(AYear, AMonth, ADay: Word): TDateTime;
    // Tarihi koruyarak saati değiştirir.
    function _ChangeTime(AHour, AMinute, ASecond: Word; AMilliSecond: Word = 0): TDateTime;

    { ===== Timezone (ATzId boşsa yerel makine, doluysa mORMot2 TSynTimeZone) ===== }
    // Yerel zamanı UTC'ye çevirir (ATzId boşsa yerel makine, doluysa keyfi isimli TZ).
    function _ToUtc(const ATzId: string = ''): TDateTime;
    // Belirtilen timezone için dakika cinsinden UTC offset'i döner.
    function _GetTZBias(const ATzId: string): Integer;
    // Belirtilen timezone için yaz saati (DST) durumunu ve offset'i okunabilir metin olarak döner.
    function _DaylightSavingInfo(const ATzId: string): string;
    // UTC zamanını yerel/belirtilen timezone'a çevirir (ters yön).
    class function _FromUtc(const AUtc: TDateTime; const ATzId: string = ''): TDateTime; static;
    // Belirtilen timezone'a göre şu anki zamanı döner.
    class function _NowInZone(const ATzId: string): TDateTime; static;
    // Şu anki UTC tarih+saat.
    class function _NowUtc: TDateTime; static;
    // Şu anki UTC zamanının sadece saat kısmı.
    class function _TimeUtc: TDateTime; static;
    // Şu anki UTC zamanının sadece tarih kısmı.
    class function _DateUtc: TDateTime; static;
    // Sistemde tanımlı tüm timezone ID'lerinin listesi (UI'da seçim listesi doldurmak için).
    class function _TzList: TStrings; static;
    {$IFDEF MSWINDOWS}
    // RİSKLİ: işletim sisteminin timezone ayarını GERÇEKTEN değiştirir.
    class procedure _SetOperatingSystemTimeZone(const ATzId: string); static;
    {$ENDIF}

    { ===== Format / metin ===== }
    // FormatDateTime biçim string'ine göre metne çevirir (JclDateTime.FormatDateTime kullanır —
    // RTL'in FormatDateTime'ından farklı olarak ISO hafta token'larını da destekler: w/ww/i/ii/e/f).
    function _Format(const AFormatStr: string): string;
    // RFC 7231 HTTP-date formatına çevirir (ör. 'Tue, 15 Nov 1994 12:45:26 GMT').
    function _ToHttpDate: string;
    // Apache/NCSA log formatına yakın bir metin üretir.
    function _ToNcsaText: string;
    // Dosya adına uygun kısa tarih metni üretir.
    function _ToFileShort: string;
    // İnsan tarafından okunabilir bir tarih/saat metni üretir.
    function _ToHuman: string;
    // Göreli zaman metni üretir (ör. '3 saat önce', '2 gün sonra').
    function _ToRelativeString: string;
    // HTTP-date metnini TDateTime'a çevirir (ters yön).
    class function _FromHttpDate(const AText: string): TDateTime; static;
    // Bir Variant değerini TDateTime'a çevirir.
    class function _FromVariant(const AValue: Variant): TDateTime; static;
    // Bugünün tarihi (saat kısmı sıfır).
    class function _Today: TDateTime; static;
    // Yarının tarihi.
    class function _Tomorrow: TDateTime; static;
    // Dünün tarihi.
    class function _Yesterday: TDateTime; static;

    { ===== İş günü ===== }
    // Hafta içi (Pazartesi-Cuma) olup olmadığı.
    function _IsWorkingDay: Boolean; inline;
    // Bir sonraki iş gününü döner (hafta sonlarını atlar).
    function _NextWorkingDay: TDateTime;
    // Bir önceki iş gününü döner (hafta sonlarını atlar).
    function _PrevWorkingDay: TDateTime;
    // N iş günü ileri/geri gider (hafta sonlarını saymaz).
    function _IncWorkDays(ADays: Integer): TDateTime;
    // İki tarih arasındaki iş günü sayısını döner (işaretli, AOther Self'ten önceyse negatif).
    function _CountWorkingDays(const AOther: TDateTime): Integer;

    { ===== Yaş (Self = doğum tarihi) ===== }
    // Self'i doğum tarihi kabul edip bugüne göre tam yıl cinsinden yaş hesaplar.
    function _Age: Integer;
    // Self'i doğum tarihi kabul edip bugüne göre tam ay cinsinden yaş hesaplar.
    function _AgeInMonths: Integer; inline;
    // Self'i doğum tarihi kabul edip bugüne göre tam hafta cinsinden yaş hesaplar.
    function _AgeInWeeks: Integer; inline;

    { ===== "Ayın N'inci X günü" (rad.utils.pas'a referans) ===== }
    // Ayın N'inci X günü tarihini hesaplar (ör. "ayın son Pazarı") — rad.utils.pas'a ince sarmalayıcı.
    class function _DayOfMonth2Date(AYear, AMonth, AWeekInMonth, ADayInWeek: Word): TDateTime; static;
    // Ayın N'inci iş (hafta içi) gününü döner; AIndex negatifse sondan sayar.
    class function _IndexedWeekDay(AYear, AMonth: Word; AIndex: Integer): TDateTime; static;
    // Ayın N'inci hafta sonu gününü döner; AIndex negatifse sondan sayar.
    class function _IndexedWeekendDay(AYear, AMonth: Word; AIndex: Integer): TDateTime; static;

    {$IFDEF MSWINDOWS}
    { ===== Win32 interop ===== }
    // Windows FILETIME yapısına çevirir (Self yerel zaman kabul edilir, sonuç
    // gerçek UTC FILETIME'dır — LocalFileTimeToFileTime ile TZ dönüşümü yapılır).
    function _ToFileTime: TFileTime;
    // Windows SYSTEMTIME yapısına çevirir.
    function _ToSystemTime: TSystemTime; inline;
    // DOS tarih/saat (32-bit packed) formatına çevirir.
    function _ToDosDateTime: Integer; inline;
    // Windows FILETIME'dan TDateTime üretir (ters yön); AFileTime UTC kabul
    // edilir, sonuç FileTimeToLocalFileTime ile yerel zamana çevrilmiş olur.
    class function _FromFileTime(const AFileTime: TFileTime): TDateTime; static;
    // Windows SYSTEMTIME'dan TDateTime üretir (ters yön).
    class function _FromSystemTime(const ASystemTime: TSystemTime): TDateTime; static; inline;
    // DOS tarih/saat formatından TDateTime üretir (ters yön).
    class function _FromDosDateTime(ADosDateTime: Integer): TDateTime; static; inline;
    { ===== RİSKLİ: gerçek sistem saatini değiştirir ===== }
    // RİSKLİ: işletim sisteminin yerel saatini GERÇEKTEN değiştirir.
    procedure _SetOperatingSystemDateTime;
    {$ENDIF}

    { ===== Delphi TTimeStamp köprüsü ===== }
    // Delphi'nin klasik TTimeStamp yapısına çevirir.
    function _ToTimeStamp: TTimeStamp; inline;
    // TTimeStamp'tan TDateTime üretir (ters yön).
    class function _FromTimeStamp(const AStamp: TTimeStamp): TDateTime; static; inline;
    // İki TTimeStamp'ı karşılaştırır (milisaniye cinsinden fark döner).
    class function _CompareTimeStamps(const A, B: TTimeStamp): Int64; static;
    // İki TTimeStamp'ın eşit olup olmadığını kontrol eder.
    class function _EqualTimeStamps(const A, B: TTimeStamp): Boolean; static;
    // TTimeStamp'ın sıfır/boş değer olup olmadığını kontrol eder.
    class function _IsNullTimeStamp(const AStamp: TTimeStamp): Boolean; static;
    // TTimeStamp'ın haftanın hangi gününe denk geldiğini döner (1=Pazar..7=Cumartesi).
    class function _TimeStampDOW(const AStamp: TTimeStamp): Integer; static;
  end;

implementation

uses
  rad.utils, JclDateTime;

const
  CDateTolerance: Double = 1.157407407407407E-9; // ~0.1 ms (rad.utils.pas ile aynı tolerans)

{ ISO-8601 }

function TDateTimeHelper._ToISO8601: string;
begin
  Result := string(DateTimeToIso8601Text(Self));
end;

function TDateTimeHelper._ToISO8601MS: string;
begin
  Result := string(DateTimeToIso8601Text(Self, 'T', true));
end;

function TDateTimeHelper._ToISO8601Short: string;
begin
  Result := string(DateTimeToIso8601Short(Self));
end;

function TDateTimeHelper._ToISO8601Date: string;
begin
  Result := string(DateToIso8601Text(Self));
end;

function TDateTimeHelper._ToISO8601Time: string;
begin
  Result := string(TimeToIso8601(Self, true));
end;

class function TDateTimeHelper._FromISO8601(const AText: string): TDateTime;
begin
  Result := Iso8601ToDateTime(RawByteString(AText));
end;

class function TDateTimeHelper._FromISO8601Date(const AText: string): TDate;
begin
  Result := Trunc(Iso8601ToDateTime(RawByteString(AText)));
end;

class function TDateTimeHelper._FromISO8601Time(const AText: string): TTime;
begin
  Result := Iso8601ToTime(RawByteString(AText));
end;

{ Unix / TTimeLog }

function TDateTimeHelper._ToUnix: TUnixTime;
begin
  Result := DateTimeToUnixTime(Self);
end;

function TDateTimeHelper._ToUnixMS: TUnixMSTime;
begin
  Result := DateTimeToUnixMSTime(Self);
end;

function TDateTimeHelper._ToLog: TTimeLog;
begin
  Result := TimeLogFromDateTime(Self);
end;

class function TDateTimeHelper._FromUnix(const AUnix: TUnixTime): TDateTime;
begin
  Result := UnixTimeToDateTime(AUnix);
end;

class function TDateTimeHelper._FromUnixMS(const AUnixMS: TUnixMSTime): TDateTime;
begin
  Result := UnixMSTimeToDateTime(AUnixMS);
end;

class function TDateTimeHelper._FromLog(const ALog: TTimeLog): TDateTime;
begin
  Result := TimeLogToDateTime(ALog);
end;

class function TDateTimeHelper._LogFromISO8601Text(const AText: string): TTimeLog;
begin
  Result := Iso8601ToTimeLog(RawByteString(AText));
end;

{ Bileşen erişimi }

function TDateTimeHelper._Day: Word;
var LY, LM, LD: Word;
begin
  DecodeDate(Self, LY, LM, LD);
  Result := LD;
end;

function TDateTimeHelper._Month: Word;
var LY, LM, LD: Word;
begin
  DecodeDate(Self, LY, LM, LD);
  Result := LM;
end;

function TDateTimeHelper._Year: Word;
var LY, LM, LD: Word;
begin
  DecodeDate(Self, LY, LM, LD);
  Result := LY;
end;

function TDateTimeHelper._Hour: Word;
var LH, LN, LS, LMs: Word;
begin
  DecodeTime(Self, LH, LN, LS, LMs);
  Result := LH;
end;

function TDateTimeHelper._Minute: Word;
var LH, LN, LS, LMs: Word;
begin
  DecodeTime(Self, LH, LN, LS, LMs);
  Result := LN;
end;

function TDateTimeHelper._Second: Word;
var LH, LN, LS, LMs: Word;
begin
  DecodeTime(Self, LH, LN, LS, LMs);
  Result := LS;
end;

function TDateTimeHelper._DayOfWeek: Word;
begin
  Result := System.SysUtils.DayOfWeek(Self); // 1=Pazar..7=Cumartesi
end;

function TDateTimeHelper._DayOfYear: Word;
begin
  Result := System.DateUtils.DayOfTheYear(Self);
end;

function TDateTimeHelper._Quarter: Integer;
begin
  Result := (Self._Month - 1) div 3 + 1;
end;

function TDateTimeHelper._Semester: Integer;
begin
  if Self._Month <= 6 then Result := 1 else Result := 2;
end;

function TDateTimeHelper._IsLeapYear: Boolean;
begin
  Result := System.SysUtils.IsLeapYear(Self._Year);
end;

function TDateTimeHelper._DaysInMonth: Word;
begin
  Result := mormot.core.datetime.DaysInMonth(Self._Year, Self._Month);
end;

function TDateTimeHelper._DaysLeftInMonth: Word;
begin
  Result := Self._DaysInMonth - Self._Day;
end;

function TDateTimeHelper._DaysLeftInYear: Word;
begin
  Result := Trunc(EncodeDate(Self._Year, 12, 31)) - Trunc(Self);
end;

{ Dönem sınırları }

function TDateTimeHelper._StartOfDay: TDateTime;
begin
  Result := Trunc(Self);
end;

function TDateTimeHelper._EndOfDay: TDateTime;
begin
  Result := Trunc(Self) + (1 - 1 / MSecsPerDay);
end;

function TDateTimeHelper._StartOfWeek: TDateTime;
var LDow: Integer;
begin
  LDow := ((Self._DayOfWeek + 5) mod 7); // ISO dow - 1 (0=Pazartesi..6=Pazar)
  Result := Trunc(Self) - LDow;
end;

function TDateTimeHelper._EndOfWeek: TDateTime;
begin
  Result := Self._StartOfWeek._IncDay(6)._EndOfDay;
end;

function TDateTimeHelper._StartOfMonth: TDateTime;
begin
  Result := EncodeDate(Self._Year, Self._Month, 1);
end;

function TDateTimeHelper._EndOfMonth: TDateTime;
begin
  Result := EncodeDate(Self._Year, Self._Month, Self._DaysInMonth)._EndOfDay;
end;

function TDateTimeHelper._StartOfQuarter: TDateTime;
begin
  Result := EncodeDate(Self._Year, (Self._Quarter - 1) * 3 + 1, 1);
end;

function TDateTimeHelper._EndOfQuarter: TDateTime;
var LLastMonth: Word;
begin
  LLastMonth := Self._Quarter * 3;
  Result := EncodeDate(Self._Year, LLastMonth, mormot.core.datetime.DaysInMonth(Self._Year, LLastMonth))._EndOfDay;
end;

function TDateTimeHelper._StartOfYear: TDateTime;
begin
  Result := EncodeDate(Self._Year, 1, 1);
end;

function TDateTimeHelper._EndOfYear: TDateTime;
begin
  Result := EncodeDate(Self._Year, 12, 31)._EndOfDay;
end;

function TDateTimeHelper._IsWeekend: Boolean;
var LDow: Word;
begin
  LDow := Self._DayOfWeek;
  Result := (LDow = 1) or (LDow = 7);
end;

{ ISO-8601 hafta numarası }

function TDateTimeHelper._ISOWeekNumber: Word;
var LThursday: TDateTime;
begin
  // en yakın Perşembe'ye kaydır, o Perşembe'nin yılına göre hafta no hesapla
  LThursday := Trunc(Self) - ((Self._DayOfWeek + 5) mod 7) + 3;
  Result := (Trunc(LThursday) - Trunc(EncodeDate(TDateTime(LThursday)._Year, 1, 1))) div 7 + 1;
end;

function TDateTimeHelper._IsISOLongYear: Boolean;
begin
  Result := TDateTime(EncodeDate(Self._Year, 12, 31))._ISOWeekNumber = 53;
end;

class function TDateTimeHelper._FromISOWeek(AYear, AWeek: Word; ADayOfWeek: Word): TDateTime;
var LJan4: TDateTime;
    LJan4IsoDow: Integer;
    LWeek1Monday: TDateTime;
begin
  LJan4 := EncodeDate(AYear, 1, 4); // ISO: 4 Ocak her zaman 1. haftadadır
  LJan4IsoDow := (TDateTime(LJan4)._DayOfWeek + 5) mod 7; // 0=Pazartesi..6=Pazar
  LWeek1Monday := Trunc(LJan4) - LJan4IsoDow;
  Result := LWeek1Monday + (AWeek - 1) * 7 + (ADayOfWeek - 1);
end;

{ Karşılaştırma }

function TDateTimeHelper._DateEQ(const AOther: TDateTime): Boolean;
begin
  Result := Abs(Self - AOther) < CDateTolerance;
end;

function TDateTimeHelper._DateLT(const AOther: TDateTime): Boolean;
begin
  Result := (AOther - Self) >= CDateTolerance;
end;

function TDateTimeHelper._DateLE(const AOther: TDateTime): Boolean;
begin
  Result := not Self._DateGT(AOther);
end;

function TDateTimeHelper._DateGT(const AOther: TDateTime): Boolean;
begin
  Result := (Self - AOther) >= CDateTolerance;
end;

function TDateTimeHelper._DateGE(const AOther: TDateTime): Boolean;
begin
  Result := not Self._DateLT(AOther);
end;

function TDateTimeHelper._FixDT: TDateTime;
begin
  Result := Round(Self * MSecsPerDay) / MSecsPerDay;
end;

function TDateTimeHelper._DaysBetween(const AOther: TDateTime): Integer;
begin
  Result := System.DateUtils.DaysBetween(Self, AOther);
end;

function TDateTimeHelper._MonthsBetween(const AOther: TDateTime): Integer;
begin
  Result := Trunc(System.DateUtils.MonthsBetween(Self, AOther));
end;

function TDateTimeHelper._YearsBetween(const AOther: TDateTime): Integer;
begin
  Result := Trunc(System.DateUtils.YearsBetween(Self, AOther));
end;

{ Ekleme/çıkarma }

function TDateTimeHelper._IncDay(AValue: Integer): TDateTime;
begin
  Result := System.DateUtils.IncDay(Self, AValue);
end;

function TDateTimeHelper._IncMonth(AValue: Integer): TDateTime;
begin
  Result := System.SysUtils.IncMonth(Self, AValue);
end;

function TDateTimeHelper._IncYear(AValue: Integer): TDateTime;
begin
  Result := System.DateUtils.IncYear(Self, AValue);
end;

function TDateTimeHelper._IncHour(AValue: Integer): TDateTime;
begin
  Result := System.DateUtils.IncHour(Self, AValue);
end;

function TDateTimeHelper._IncMinute(AValue: Integer): TDateTime;
begin
  Result := System.DateUtils.IncMinute(Self, AValue);
end;

function TDateTimeHelper._IncSecond(AValue: Integer): TDateTime;
begin
  Result := System.DateUtils.IncSecond(Self, AValue);
end;

function TDateTimeHelper._ChangeDate(AYear, AMonth, ADay: Word): TDateTime;
begin
  Result := EncodeDate(AYear, AMonth, ADay) + Frac(Self);
end;

function TDateTimeHelper._ChangeTime(AHour, AMinute, ASecond: Word; AMilliSecond: Word): TDateTime;
begin
  Result := Trunc(Self) + EncodeTime(AHour, AMinute, ASecond, AMilliSecond);
end;

{ Timezone }

function TDateTimeHelper._ToUtc(const ATzId: string): TDateTime;
begin
  if ATzId = '' then
    Result := TTimeZone.Local.ToUniversalTime(Self)
  else
    Result := TSynTimeZone.Default.LocalToUtc(Self, ATzId);
end;

function TDateTimeHelper._GetTZBias(const ATzId: string): Integer;
var LHaveDaylight: Boolean;
begin
  TSynTimeZone.Default.GetBiasForDateTime(Self, ATzId, Result, LHaveDaylight);
end;

function TDateTimeHelper._DaylightSavingInfo(const ATzId: string): string;
var LBias: Integer;
    LHaveDaylight: Boolean;
begin
  TSynTimeZone.Default.GetBiasForDateTime(Self, ATzId, LBias, LHaveDaylight);
  if LHaveDaylight then
    Result := Format('Yaz saati aktif, UTC offset: %d dakika', [LBias])
  else
    Result := Format('Yaz saati aktif değil, UTC offset: %d dakika', [LBias]);
end;

class function TDateTimeHelper._FromUtc(const AUtc: TDateTime; const ATzId: string): TDateTime;
begin
  if ATzId = '' then
    Result := TTimeZone.Local.ToLocalTime(AUtc)
  else
    Result := TSynTimeZone.Default.UtcToLocal(AUtc, ATzId);
end;

class function TDateTimeHelper._NowInZone(const ATzId: string): TDateTime;
begin
  if ATzId = '' then
    Result := System.SysUtils.Now
  else
    Result := TSynTimeZone.Default.NowToLocal(ATzId);
end;

class function TDateTimeHelper._NowUtc: TDateTime;
begin
  Result := TTimeZone.Local.ToUniversalTime(System.SysUtils.Now);
end;

class function TDateTimeHelper._TimeUtc: TDateTime;
begin
  Result := Frac(_NowUtc);
end;

class function TDateTimeHelper._DateUtc: TDateTime;
begin
  Result := Trunc(_NowUtc);
end;

class function TDateTimeHelper._TzList: TStrings;
begin
  Result := TSynTimeZone.Default.Ids;
end;

{$IFDEF MSWINDOWS}
class procedure TDateTimeHelper._SetOperatingSystemTimeZone(const ATzId: string);
begin
  TSynTimeZone.Default.ChangeOperatingSystemTimeZone(ATzId);
end;
{$ENDIF}

{ Format / metin }

function TDateTimeHelper._Format(const AFormatStr: string): string;
begin
  Result := JclDateTime.FormatDateTime(AFormatStr, Self);
end;

function TDateTimeHelper._ToHttpDate: string;
begin
  Result := string(DateTimeToHttpDate(Self));
end;

function TDateTimeHelper._ToNcsaText: string;
var LSystemTime: TSynSystemTime;
begin
  LSystemTime.FromDateTime(Self);
  Result := string(LSystemTime.ToText(true)); // basit fallback; tam NCSA formatı için TTextDateWriter gerekir
end;

function TDateTimeHelper._ToFileShort: string;
begin
  Result := string(DateTimeToFileShort(Self));
end;

function TDateTimeHelper._ToHuman: string;
var LSystemTime: TSynSystemTime;
    LText: RawUtf8;
begin
  LSystemTime.FromDateTime(Self);
  LSystemTime.ToHuman(LText);
  Result := string(LText);
end;

function TDateTimeHelper._ToRelativeString: string;
var LSeconds: Int64;
    LFuture: Boolean;
    LSuffix: string;
begin
  LFuture := Self > System.SysUtils.Now;
  if LFuture then
  begin
    LSeconds := SecondsBetween(Self, System.SysUtils.Now);
    LSuffix := 'sonra';
  end
  else
  begin
    LSeconds := SecondsBetween(System.SysUtils.Now, Self);
    LSuffix := 'önce';
  end;

  if LSeconds < 60 then
    Result := 'az önce'
  else if LSeconds < 3600 then
    Result := Format('%d dakika %s', [LSeconds div 60, LSuffix])
  else if LSeconds < 86400 then
    Result := Format('%d saat %s', [LSeconds div 3600, LSuffix])
  else if LSeconds < 86400 * 30 then
    Result := Format('%d gün %s', [LSeconds div 86400, LSuffix])
  else if LSeconds < 86400 * 365 then
    Result := Format('%d ay %s', [LSeconds div (86400 * 30), LSuffix])
  else
    Result := Format('%d yıl %s', [LSeconds div (86400 * 365), LSuffix]);
end;

class function TDateTimeHelper._FromHttpDate(const AText: string): TDateTime;
begin
  if not HttpDateToDateTime(RawUtf8(AText), Result) then
    raise EConvertError.CreateFmt('Geçersiz HTTP-date metni: %s', [AText]);
end;

class function TDateTimeHelper._FromVariant(const AValue: Variant): TDateTime;
begin
  if not VariantToDateTime(AValue, Result) then
    raise EConvertError.Create('Variant, TDateTime''a çevrilemedi');
end;

class function TDateTimeHelper._Today: TDateTime;
begin
  Result := Trunc(System.SysUtils.Now);
end;

class function TDateTimeHelper._Tomorrow: TDateTime;
begin
  Result := Trunc(System.SysUtils.Now) + 1;
end;

class function TDateTimeHelper._Yesterday: TDateTime;
begin
  Result := Trunc(System.SysUtils.Now) - 1;
end;

{ İş günü }

function TDateTimeHelper._IsWorkingDay: Boolean;
begin
  Result := not Self._IsWeekend;
end;

function TDateTimeHelper._NextWorkingDay: TDateTime;
begin
  Result := Self._IncDay(1);
  while not Result._IsWorkingDay do
    Result := Result._IncDay(1);
end;

function TDateTimeHelper._PrevWorkingDay: TDateTime;
begin
  Result := Self._IncDay(-1);
  while not Result._IsWorkingDay do
    Result := Result._IncDay(-1);
end;

function TDateTimeHelper._IncWorkDays(ADays: Integer): TDateTime;
var i: Integer;
begin
  Result := Self;
  if ADays >= 0 then
    for i := 1 to ADays do
      Result := Result._NextWorkingDay
  else
    for i := 1 to -ADays do
      Result := Result._PrevWorkingDay;
end;

function TDateTimeHelper._CountWorkingDays(const AOther: TDateTime): Integer;
var LStart, LEnd, D: TDateTime;
    LSign: Integer;
begin
  Result := 0;
  if Self <= AOther then
  begin
    LStart := Self;
    LEnd := AOther;
    LSign := 1;
  end
  else
  begin
    LStart := AOther;
    LEnd := Self;
    LSign := -1;
  end;
  D := LStart;
  while D < LEnd do
  begin
    D := TDateTime(D)._IncDay(1);
    if TDateTime(D)._IsWorkingDay then
      Inc(Result);
  end;
  Result := Result * LSign;
end;

{ Yaş }

function TDateTimeHelper._Age: Integer;
var LNow: TDateTime;
begin
  LNow := System.SysUtils.Now;
  Result := LNow._Year - Self._Year;
  if (LNow._Month < Self._Month) or ((LNow._Month = Self._Month) and (LNow._Day < Self._Day)) then
    Dec(Result);
end;

function TDateTimeHelper._AgeInMonths: Integer;
begin
  Result := Trunc(System.DateUtils.MonthsBetween(Self, System.SysUtils.Now));
end;

function TDateTimeHelper._AgeInWeeks: Integer;
begin
  Result := Trunc(System.DateUtils.WeeksBetween(Self, System.SysUtils.Now));
end;

{ "Ayın N'inci X günü" }

class function TDateTimeHelper._DayOfMonth2Date(AYear, AMonth, AWeekInMonth, ADayInWeek: Word): TDateTime;
begin
  Result := rad.utils.DayOfMonth2Date(AYear, AMonth, AWeekInMonth, ADayInWeek);
end;

class function TDateTimeHelper._IndexedWeekDay(AYear, AMonth: Word; AIndex: Integer): TDateTime;
var LFirst, LLast: Integer;
    D, LCount: Integer;
begin
  Result := 0;
  LFirst := Trunc(EncodeDate(AYear, AMonth, 1));
  LLast := Trunc(EncodeDate(AYear, AMonth, mormot.core.datetime.DaysInMonth(AYear, AMonth)));
  LCount := 0;
  if AIndex > 0 then
  begin
    for D := LFirst to LLast do
      if TDateTime(D)._IsWorkingDay then
      begin
        Inc(LCount);
        if LCount = AIndex then Exit(D);
      end;
  end
  else
  begin
    for D := LLast downto LFirst do
      if TDateTime(D)._IsWorkingDay then
      begin
        Inc(LCount);
        if LCount = -AIndex then Exit(D);
      end;
  end;
end;

class function TDateTimeHelper._IndexedWeekendDay(AYear, AMonth: Word; AIndex: Integer): TDateTime;
var LFirst, LLast: Integer;
    D, LCount: Integer;
begin
  Result := 0;
  LFirst := Trunc(EncodeDate(AYear, AMonth, 1));
  LLast := Trunc(EncodeDate(AYear, AMonth, mormot.core.datetime.DaysInMonth(AYear, AMonth)));
  LCount := 0;
  if AIndex > 0 then
  begin
    for D := LFirst to LLast do
      if TDateTime(D)._IsWeekend then
      begin
        Inc(LCount);
        if LCount = AIndex then Exit(D);
      end;
  end
  else
  begin
    for D := LLast downto LFirst do
      if TDateTime(D)._IsWeekend then
      begin
        Inc(LCount);
        if LCount = -AIndex then Exit(D);
      end;
  end;
end;

{$IFDEF MSWINDOWS}
{ Win32 interop }

function TDateTimeHelper._ToFileTime: TFileTime;
var
  LSystemTime: TSystemTime;
  LLocalFileTime: TFileTime;
begin
  // Self yerel (wall-clock) zaman kabul edilir; Windows FILETIME'ı UTC istediği
  // için SystemTimeToFileTime'ın ürettiği "yerel" FILETIME, LocalFileTimeToFileTime
  // ile gerçek UTC FILETIME'a çevrilir (MSDN önerilen yöntem).
  // NOT: FileTimeToSystemTime/SystemTimeToFileTime, implementation uses'taki
  // JclDateTime tarafından FARKLI (BOOL dönmeyen) imzalarla gölgeleniyor — bu
  // yüzden gerçek Win32 API'ye ulaşmak için Winapi.Windows. ile nitelendirildi.
  System.SysUtils.DateTimeToSystemTime(Self, LSystemTime);
  if not Winapi.Windows.SystemTimeToFileTime(LSystemTime, LLocalFileTime) then
    RaiseLastOSError;
  if not Winapi.Windows.LocalFileTimeToFileTime(LLocalFileTime, Result) then
    RaiseLastOSError;
end;

function TDateTimeHelper._ToSystemTime: TSystemTime;
begin
  System.SysUtils.DateTimeToSystemTime(Self, Result);
end;

function TDateTimeHelper._ToDosDateTime: Integer;
begin
  Result := Integer(DateTimeToFileDate(Self));
end;

class function TDateTimeHelper._FromFileTime(const AFileTime: TFileTime): TDateTime;
var
  LLocalFileTime: TFileTime;
  LSystemTime: TSystemTime;
begin
  // AFileTime (ör. bir dosyanın LastWriteTime'ı) UTC'dir; FileTimeToLocalFileTime
  // ile önce yerel FILETIME'a çevrilmeden doğrudan FileTimeToSystemTime yapılırsa
  // sonuç UTC saat olarak kalır (Türkiye'de 3 saat kayık) — bu yüzden önce
  // FileTimeToLocalFileTime çağrılır (MSDN önerilen yöntem).
  // NOT: FileTimeToLocalFileTime/FileTimeToSystemTime, implementation uses'taki
  // JclDateTime tarafından FARKLI (BOOL dönmeyen) imzalarla gölgeleniyor — bu
  // yüzden gerçek Win32 API'ye ulaşmak için Winapi.Windows. ile nitelendirildi.
  if not Winapi.Windows.FileTimeToLocalFileTime(AFileTime, LLocalFileTime) then
    RaiseLastOSError;
  if not Winapi.Windows.FileTimeToSystemTime(LLocalFileTime, LSystemTime) then
    RaiseLastOSError;
  Result := System.SysUtils.SystemTimeToDateTime(LSystemTime);
end;

class function TDateTimeHelper._FromSystemTime(const ASystemTime: TSystemTime): TDateTime;
begin
  Result := SystemTimeToDateTime(ASystemTime);
end;

class function TDateTimeHelper._FromDosDateTime(ADosDateTime: Integer): TDateTime;
begin
  Result := FileDateToDateTime(ADosDateTime);
end;

procedure TDateTimeHelper._SetOperatingSystemDateTime;
var LSystemTime: TSystemTime;
begin
  DateTimeToSystemTime(Self, LSystemTime);
  if not SetLocalTime(LSystemTime) then
    RaiseLastOSError;
end;
{$ENDIF}

{ Delphi TTimeStamp köprüsü }

function TDateTimeHelper._ToTimeStamp: TTimeStamp;
begin
  Result := DateTimeToTimeStamp(Self);
end;

class function TDateTimeHelper._FromTimeStamp(const AStamp: TTimeStamp): TDateTime;
begin
  Result := TimeStampToDateTime(AStamp);
end;

class function TDateTimeHelper._CompareTimeStamps(const A, B: TTimeStamp): Int64;
begin
  Result := (Int64(A.Date) * MSecsPerDay + A.Time) - (Int64(B.Date) * MSecsPerDay + B.Time);
end;

class function TDateTimeHelper._EqualTimeStamps(const A, B: TTimeStamp): Boolean;
begin
  Result := (A.Date = B.Date) and (A.Time = B.Time);
end;

class function TDateTimeHelper._IsNullTimeStamp(const AStamp: TTimeStamp): Boolean;
begin
  Result := (AStamp.Date = 0) and (AStamp.Time = 0);
end;

class function TDateTimeHelper._TimeStampDOW(const AStamp: TTimeStamp): Integer;
begin
  Result := System.SysUtils.DayOfWeek(TimeStampToDateTime(AStamp));
end;

end.
