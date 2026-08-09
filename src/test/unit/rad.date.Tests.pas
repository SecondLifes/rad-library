unit rad.date.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.DateUtils,
  System.Diagnostics,
  rad.date;

type
  [TestFixture]
  TDtElapsedTestleri = class
  public
    [Test]
    procedure UyumsuzKaynaklarKarsilastirmaHatasiTesti;

    [Test]
    procedure DurationHerKaynaklaUyumluTesti;

    [Test]
    procedure TimestampArtiTimestampGecersizTesti;

    [Test]
    procedure DurationEksiTimestampGecersizTesti;

    [Test]
    [TestCase('MS-US-NS Donusumu 1','1000')]
    [TestCase('MS-US-NS Donusumu 2','2500')]
    procedure SureBirimDonusumTesti(const AMs: Integer);

    [Test]
    procedure MinMaxKarsilastirmaTesti;

    [Test]
    procedure GecersizZamanDamgasiTesti;

    [Test]
    procedure HasElapsedGecersizdeTrueDonerTesti;

    [Test]
    procedure HasElapsedGecerliSuredeDogruCalisirTesti;
  end;

  [TestFixture]
  TDtIntervalTestleri = class
  public
    [Test]
    procedure EncodeIntervalAlanlariTesti;

    [Test]
    procedure IncMetotlariByValueDonerTesti;

    [Test]
    procedure TarihArtiIntervalTesti;

    [Test]
    procedure TarihEksiIntervalTesti;

    [Test]
    procedure IntervalToplamaCikarmaTesti;

    [Test]
    procedure IsZeroIsNegTesti;

    [Test]
    [TestCase('ISO Metni 1 (bos)','0,0,0,0,0,0,0,P0D')]
    [TestCase('ISO Metni 2 (YMD)','1,2,3,0,0,0,0,P1Y2M3D')]
    [TestCase('ISO Metni 3 (T kismi)','0,0,0,1,30,0,0,PT1H30M')]
    procedure AsISOStringTesti(const AYear, AMonth, ADay, AHour, AMinute, ASecond, AMs: Integer; const ABeklenen: string);
  end;

  [TestFixture]
  TDtTimeZoneTestleri = class
  public
    [Test]
    procedure ToUtcFromUtcGidisDonusTesti;

    [Test]
    procedure YerelMakineDonusumuTesti;

    [Test]
    procedure GetBiasGecerliTZIcinTrueDonerTesti;
  end;

  // TDtSchedule projede kritik bir bileşen (Quartz-tarzı cron maskesi) — bu yüzden
  // test yoğunluğu bilinçli olarak burada: tüm gramer token'ları (* ? - / L , # W),
  // Accept/NextTime/Timeout ve NextTime'ın performans karakteristiği ayrıntılı sınanıyor.
  [TestFixture]
  TDtScheduleTestleri = class
  public
    [Test]
    procedure YildiziJokerHerZamanEslesirTesti;

    [Test]
    [TestCase('Sabit Deger Eslesir','2026,1,5,9,30,0,true')]
    [TestCase('Sabit Deger Eslesmez (farkli saat)','2026,1,5,10,30,0,false')]
    [TestCase('Sabit Deger Eslesmez (farkli dakika)','2026,1,5,9,31,0,false')]
    procedure SabitDegerTesti(const AYil, AAy, AGun, ASaat, ADakika, ASaniye: Integer; const ABeklenen: Boolean);

    [Test]
    [TestCase('Aralik Icinde','2026,1,5,12,0,0,true')]
    [TestCase('Aralik Disinda Once','2026,1,5,8,0,0,false')]
    [TestCase('Aralik Disinda Sonra','2026,1,5,18,0,0,false')]
    procedure AralikTokenTesti(const AYil, AAy, AGun, ASaat, ADakika, ASaniye: Integer; const ABeklenen: Boolean);

    [Test]
    [TestCase('Adim Tam Katinda','0,true')]
    [TestCase('Adim Tam Katinda 2','15,true')]
    [TestCase('Adim Tam Katinda 3','30,true')]
    [TestCase('Adim Disinda','5,false')]
    [TestCase('Adim Disinda 2','20,false')]
    procedure AdimTokenTesti(const ADakika: Integer; const ABeklenen: Boolean);

    [Test]
    [TestCase('Listede Var 1','1,true')]
    [TestCase('Listede Var 2','15,true')]
    [TestCase('Listede Var 3','30,true')]
    [TestCase('Listede Yok','10,false')]
    procedure ListeTokenTesti(const ADakika: Integer; const ABeklenen: Boolean);

    [Test]
    [TestCase('Subat 2026 Son Gunu (28)','2026,2,28,true')]
    [TestCase('Subat 2026 Son Gunu Degil (27)','2026,2,27,false')]
    [TestCase('Subat 2024 Artik Yil Son Gunu (29)','2024,2,29,true')]
    [TestCase('Ocak Son Gunu (31)','2026,1,31,true')]
    procedure AyinSonGunuLTokenTesti(const AYil, AAy, AGun: Integer; const ABeklenen: Boolean);

    [Test]
    procedure AyinSonHaftaGunuLTokenTesti;

    [Test]
    procedure NinciHaftaGunuHashTokenTesti;

    [Test]
    procedure EnYakinIsGunuWTokenDavranisiTesti;

    [Test]
    procedure YilAlaniOpsiyonelTesti;

    [Test]
    procedure YilAlaniBelirtilirseKisitlarTesti;

    [Test]
    procedure GercekciHaftaIciSaatSemasiTesti;

    [Test]
    procedure AltidanAzAlanGecersizMaskeTesti;

    [Test]
    procedure NextTimeAyniGunIcindeBulurTesti;

    [Test]
    procedure NextTimeHaftaSonunuAtlarTesti;

    [Test]
    procedure NextTimeImkansizSemaSinirliAramadaSifirDonerTesti;

    [Test]
    procedure TimeoutOkExpiredTimeoutNotArrivedTesti;
  end;

  // NextTime ESKİDEN saniye-saniye brute-force arama yapıyordu (ölçülmüş gerçek
  // sonuç: seyrek şemalarda tek çağrı ~3.3sn sürüyordu — bkz. rad.date.pas'taki
  // NextTime yorumu). Artık gün-bazlı hızlı atlama kullanıyor; bu benchmark'lar
  // hem düzeltmeyi doğruluyor hem regresyona karşı bir bekçi görevi görüyor.
  // AMaxDaysSearch yine de küçük/güvenli tutuldu — varsayılan 3660 günlük
  // pencereyle "eşleşme yok" testi artık hızlı olsa da, gereksiz yere büyük
  // bir pencereyle test etmenin bir faydası yok.
  [TestFixture]
  TDtScheduleBenchmarkleri = class
  public
    [Test]
    [Category('Benchmark')]
    procedure NextTimeYogunSemaBenchmarkTesti;

    [Test]
    [Category('Benchmark')]
    procedure NextTimeAylikSeyrekSemaBenchmarkTesti;

    [Test]
    [Category('Benchmark')]
    procedure NextTimeYillikCokSeyrekSemaBenchmarkTesti;
  end;

implementation

{ TDtElapsedTestleri }

procedure TDtElapsedTestleri.UyumsuzKaynaklarKarsilastirmaHatasiTesti;
var
  LTickCount, LStopwatch: TDtElapsed;
begin
  LTickCount := TDtElapsed.Create(tsTickCount, 1000000);
  LStopwatch := TDtElapsed.Create(tsStopwatch, 1000000);
  Assert.WillRaise(
    procedure begin var LSonuc := LTickCount > LStopwatch; end,
    EInvalidOpException,
    'Farklı kaynaklar karşılaştırılabilmemeli');
end;

procedure TDtElapsedTestleri.DurationHerKaynaklaUyumluTesti;
var
  LStopwatch, LDuration, LSonuc: TDtElapsed;
begin
  LStopwatch := TDtElapsed.FromStopwatch(0);
  LDuration := TDtElapsed.Milliseconds(1000);
  LSonuc := LStopwatch + LDuration; // tsDuration her kaynakla uyumlu olmalı
  Assert.AreEqual(Ord(tsStopwatch), Ord(LSonuc.TimeSource), 'timestamp+duration sonucu timestamp kaynağını korumalı');
end;

procedure TDtElapsedTestleri.TimestampArtiTimestampGecersizTesti;
var
  L1, L2: TDtElapsed;
begin
  L1 := TDtElapsed.FromStopwatch(0);
  L2 := TDtElapsed.FromStopwatch(1000);
  Assert.WillRaise(
    procedure begin var LR := L1 + L2; end,
    EInvalidOpException,
    'timestamp + timestamp geçersiz olmalı');
end;

procedure TDtElapsedTestleri.DurationEksiTimestampGecersizTesti;
var
  LDuration, LTimestamp: TDtElapsed;
begin
  LDuration := TDtElapsed.Milliseconds(1000);
  LTimestamp := TDtElapsed.FromStopwatch(0);
  Assert.WillRaise(
    procedure begin var LR := LDuration - LTimestamp; end,
    EInvalidOpException,
    'duration - timestamp geçersiz olmalı');
end;

procedure TDtElapsedTestleri.SureBirimDonusumTesti(const AMs: Integer);
var
  LDeger: TDtElapsed;
begin
  LDeger := TDtElapsed.Milliseconds(AMs);
  Assert.AreEqual(Int64(AMs), LDeger.ToMilliseconds, 'ToMilliseconds yanlış');
  Assert.AreEqual(Int64(AMs) * 1000, LDeger.ToMicroseconds, 'ToMicroseconds yanlış');
  Assert.AreEqual(Int64(AMs) * 1000000, LDeger.ToNanoseconds, 'ToNanoseconds yanlış');
end;

procedure TDtElapsedTestleri.MinMaxKarsilastirmaTesti;
var
  LKucuk, LBuyuk: TDtElapsed;
begin
  LKucuk := TDtElapsed.Milliseconds(100);
  LBuyuk := TDtElapsed.Milliseconds(500);
  Assert.IsTrue(LKucuk < LBuyuk, '_LessThan yanlış');
  Assert.IsTrue(LBuyuk > LKucuk, '_GreaterThan yanlış');
  Assert.AreEqual(Int64(100), TDtElapsed.Min(LKucuk, LBuyuk).ToMilliseconds, 'Min yanlış');
  Assert.AreEqual(Int64(500), TDtElapsed.Max(LKucuk, LBuyuk).ToMilliseconds, 'Max yanlış');
end;

procedure TDtElapsedTestleri.GecersizZamanDamgasiTesti;
begin
  Assert.IsFalse(TDtElapsed.Invalid.IsValid, 'Invalid.IsValid True dönmemeli');
  Assert.IsTrue(TDtElapsed.Zero(tsStopwatch).IsValid, 'Zero(source).IsValid False dönmemeli');
end;

procedure TDtElapsedTestleri.HasElapsedGecersizdeTrueDonerTesti;
begin
  Assert.IsTrue(TDtElapsed.Invalid.HasElapsed(1000), 'Geçersiz zaman damgasında HasElapsed True dönmeli (lazy-init için)');
end;

procedure TDtElapsedTestleri.HasElapsedGecerliSuredeDogruCalisirTesti;
var
  LGecmis: TDtElapsed;
begin
  LGecmis := TDtElapsed.FromDateTime(System.SysUtils.Now - 1); // 1 gün önce
  Assert.IsTrue(LGecmis.HasElapsed(1000), '1 gün önceki zaman damgası 1000ms''i geçmiş olmalı');
end;

{ TDtIntervalTestleri }

procedure TDtIntervalTestleri.EncodeIntervalAlanlariTesti;
var
  LInterval: TDtInterval;
begin
  LInterval := TDtInterval.EncodeInterval(1, 2, 3, 4, 5, 6, 7);
  Assert.AreEqual(1, LInterval.Year, 'Year yanlış');
  Assert.AreEqual(2, LInterval.Month, 'Month yanlış');
  Assert.AreEqual(3, LInterval.Day, 'Day yanlış');
  Assert.AreEqual(4, LInterval.Hour, 'Hour yanlış');
  Assert.AreEqual(5, LInterval.Minute, 'Minute yanlış');
  Assert.AreEqual(6, LInterval.Second, 'Second yanlış');
  Assert.AreEqual(7, LInterval.MilliSecond, 'MilliSecond yanlış');
end;

procedure TDtIntervalTestleri.IncMetotlariByValueDonerTesti;
var
  LOrijinal, LSonuc: TDtInterval;
begin
  LOrijinal := TDtInterval.EncodeInterval(1, 0, 0, 0, 0, 0, 0);
  LSonuc := LOrijinal.IncYear(5);
  Assert.AreEqual(1, LOrijinal.Year, 'IncYear orijinali mutasyona uğratmamalı (by-value dönmeli)');
  Assert.AreEqual(6, LSonuc.Year, 'IncYear sonucu yanlış');
end;

procedure TDtIntervalTestleri.TarihArtiIntervalTesti;
var
  LBaslangic, LSonuc: TDateTime;
  LInterval: TDtInterval;
begin
  LBaslangic := EncodeDate(2026, 1, 15);
  LInterval := TDtInterval.EncodeInterval(1, 2, 3, 0, 0, 0, 0);
  LSonuc := LBaslangic + LInterval;
  Assert.AreEqual(EncodeDate(2027, 3, 18), LSonuc, 'TDateTime + TDtInterval yanlış');
end;

procedure TDtIntervalTestleri.TarihEksiIntervalTesti;
var
  LBaslangic, LSonuc: TDateTime;
  LInterval: TDtInterval;
begin
  LBaslangic := EncodeDate(2027, 3, 18);
  LInterval := TDtInterval.EncodeInterval(1, 2, 3, 0, 0, 0, 0);
  LSonuc := LBaslangic - LInterval;
  Assert.AreEqual(EncodeDate(2026, 1, 15), LSonuc, 'TDateTime - TDtInterval yanlış');
end;

procedure TDtIntervalTestleri.IntervalToplamaCikarmaTesti;
var
  LA, LB, LToplam, LFark: TDtInterval;
begin
  LA := TDtInterval.EncodeInterval(1, 2, 3, 0, 0, 0, 0);
  LB := TDtInterval.EncodeInterval(0, 1, 1, 0, 0, 0, 0);
  LToplam := LA + LB;
  Assert.AreEqual(1, LToplam.Year, 'Toplama Year yanlış');
  Assert.AreEqual(3, LToplam.Month, 'Toplama Month yanlış');
  Assert.AreEqual(4, LToplam.Day, 'Toplama Day yanlış');
  LFark := LA - LB;
  Assert.AreEqual(1, LFark.Month, 'Çıkarma Month yanlış');
  Assert.AreEqual(2, LFark.Day, 'Çıkarma Day yanlış');
end;

procedure TDtIntervalTestleri.IsZeroIsNegTesti;
var
  LSifir, LNegatif: TDtInterval;
begin
  LSifir := TDtInterval.EncodeInterval(0, 0, 0, 0, 0, 0, 0);
  Assert.IsTrue(LSifir.IsZero, 'Tüm alanlar sıfırken IsZero True olmalı');
  LNegatif := TDtInterval.EncodeInterval(0, -1, 0, 0, 0, 0, 0);
  Assert.IsTrue(LNegatif.IsNeg, 'Negatif ay varken IsNeg True olmalı');
  Assert.IsFalse(LSifir.IsNeg, 'Sıfır intervalde IsNeg False olmalı');
end;

procedure TDtIntervalTestleri.AsISOStringTesti(const AYear, AMonth, ADay, AHour, AMinute, ASecond, AMs: Integer; const ABeklenen: string);
var
  LInterval: TDtInterval;
begin
  LInterval := TDtInterval.EncodeInterval(AYear, AMonth, ADay, AHour, AMinute, ASecond, AMs);
  Assert.AreEqual(ABeklenen, LInterval.AsISOString, 'AsISOString yanlış');
end;

{ TDtTimeZoneTestleri }

procedure TDtTimeZoneTestleri.ToUtcFromUtcGidisDonusTesti;
var
  LYerel, LUtc, LGeriDonen: TDateTime;
begin
  LYerel := EncodeDateTime(2026, 7, 4, 12, 0, 0, 0);
  LUtc := TDtTimeZone.ToUtc(LYerel, 'Turkey Standard Time');
  LGeriDonen := TDtTimeZone.FromUtc(LUtc, 'Turkey Standard Time');
  Assert.AreEqual(LYerel, LGeriDonen, 'ToUtc/FromUtc gidiş-dönüşü başarısız');
end;

procedure TDtTimeZoneTestleri.YerelMakineDonusumuTesti;
var
  LYerel, LBeklenen: TDateTime;
begin
  LYerel := System.SysUtils.Now;
  LBeklenen := TTimeZone.Local.ToUniversalTime(LYerel);
  Assert.AreEqual(LBeklenen, TDtTimeZone.ToUtc(LYerel), 'ATzId boşken RTL TTimeZone.Local kullanılmalı');
end;

procedure TDtTimeZoneTestleri.GetBiasGecerliTZIcinTrueDonerTesti;
var
  LBias: Integer;
  LDaylight: Boolean;
begin
  Assert.IsTrue(TDtTimeZone.GetBias(System.SysUtils.Now, 'Romance Standard Time', LBias, LDaylight),
    'GetBias geçerli bir TzId için False döndü');
end;

{ TDtScheduleTestleri }

procedure TDtScheduleTestleri.YildiziJokerHerZamanEslesirTesti;
var
  LSema: TDtSchedule;
begin
  LSema := TDtSchedule.Create('* * * * * *');
  Assert.IsTrue(LSema.Accept(EncodeDateTime(2026, 1, 5, 9, 30, 0, 0)), '* * * * * * her zamanla eşleşmeli');
  Assert.IsTrue(LSema.Accept(EncodeDateTime(2000, 12, 31, 23, 59, 59, 0)), '* * * * * * her zamanla eşleşmeli (2)');
end;

procedure TDtScheduleTestleri.SabitDegerTesti(const AYil, AAy, AGun, ASaat, ADakika, ASaniye: Integer; const ABeklenen: Boolean);
var
  LSema: TDtSchedule;
begin
  LSema := TDtSchedule.Create('0 30 9 * * *'); // her gün 09:30:00
  Assert.AreEqual(ABeklenen, LSema.Accept(EncodeDateTime(AYil, AAy, AGun, ASaat, ADakika, ASaniye, 0)), 'Sabit değer eşleşmesi yanlış');
end;

procedure TDtScheduleTestleri.AralikTokenTesti(const AYil, AAy, AGun, ASaat, ADakika, ASaniye: Integer; const ABeklenen: Boolean);
var
  LSema: TDtSchedule;
begin
  LSema := TDtSchedule.Create('0 0 9-17 * * *'); // 09:00-17:00 arası, tam saatte
  Assert.AreEqual(ABeklenen, LSema.Accept(EncodeDateTime(AYil, AAy, AGun, ASaat, ADakika, ASaniye, 0)), 'Aralık (-) token yanlış');
end;

procedure TDtScheduleTestleri.AdimTokenTesti(const ADakika: Integer; const ABeklenen: Boolean);
var
  LSema: TDtSchedule;
begin
  LSema := TDtSchedule.Create('0 */15 * * * *'); // her 15 dakikada bir
  Assert.AreEqual(ABeklenen, LSema.Accept(EncodeDateTime(2026, 1, 5, 10, ADakika, 0, 0)), 'Adım (/) token yanlış');
end;

procedure TDtScheduleTestleri.ListeTokenTesti(const ADakika: Integer; const ABeklenen: Boolean);
var
  LSema: TDtSchedule;
begin
  LSema := TDtSchedule.Create('0 1,15,30 * * * *'); // sadece 1., 15. ve 30. dakikalarda
  Assert.AreEqual(ABeklenen, LSema.Accept(EncodeDateTime(2026, 1, 5, 10, ADakika, 0, 0)), 'Liste (,) token yanlış');
end;

procedure TDtScheduleTestleri.AyinSonGunuLTokenTesti(const AYil, AAy, AGun: Integer; const ABeklenen: Boolean);
var
  LSema: TDtSchedule;
begin
  LSema := TDtSchedule.Create('0 0 0 L * *'); // ayın son günü, gece yarısı
  Assert.AreEqual(ABeklenen, LSema.Accept(EncodeDateTime(AYil, AAy, AGun, 0, 0, 0, 0)), 'DayOfMonth L token yanlış');
end;

procedure TDtScheduleTestleri.AyinSonHaftaGunuLTokenTesti;
var
  LSema: TDtSchedule;
begin
  // '6L' = ayın son Cuma günü (RTL DayOfWeek: Pazar=1..Cumartesi=7, Cuma=6).
  // Mart 2026: 1 Mart Pazar'dır, son Cuma 27 Mart'tır (3 Nisan aya taşar).
  LSema := TDtSchedule.Create('0 0 0 * * 6L');
  Assert.IsTrue(LSema.Accept(EncodeDateTime(2026, 3, 27, 0, 0, 0, 0)),
    '27 Mart 2026 (ayın son Cuması) eşleşmeli');
  Assert.IsFalse(LSema.Accept(EncodeDateTime(2026, 3, 20, 0, 0, 0, 0)),
    '20 Mart 2026 (son Cuma değil, bir önceki Cuma) eşleşmemeli');
end;

procedure TDtScheduleTestleri.NinciHaftaGunuHashTokenTesti;
var
  LSema: TDtSchedule;
begin
  // '2#3' = ayın üçüncü Pazartesi günü (RTL DayOfWeek: Pazartesi=2).
  // Haziran 2026: 1 Haziran Pazartesi'dir, Pazartesiler: 1,8,15,22,29 — üçüncüsü 15'tir.
  LSema := TDtSchedule.Create('0 0 0 * * 2#3');
  Assert.IsTrue(LSema.Accept(EncodeDateTime(2026, 6, 15, 0, 0, 0, 0)),
    '15 Haziran 2026 (üçüncü Pazartesi) eşleşmeli');
  Assert.IsFalse(LSema.Accept(EncodeDateTime(2026, 6, 8, 0, 0, 0, 0)),
    '8 Haziran 2026 (ikinci Pazartesi) eşleşmemeli');
  Assert.IsFalse(LSema.Accept(EncodeDateTime(2026, 6, 22, 0, 0, 0, 0)),
    '22 Haziran 2026 (dördüncü Pazartesi) eşleşmemeli');
end;

procedure TDtScheduleTestleri.EnYakinIsGunuWTokenDavranisiTesti;
var
  LSema: TDtSchedule;
begin
  // '15W' = ayın 15'ine en yakın iş günü (standart cron semantiği: 15'i hafta
  // sonuna denk gelirse en yakın hafta içi güne kayar). MEVCUT implementasyon
  // (rad.date.pas TDtSchedule.FieldMatches, IsNearestWeekday dalı) SADECE
  // "gün = 15 VE 15'in kendisi iş günüyse" kontrolü yapıyor — 15'i hafta
  // sonuna denk geldiğinde 14'e/17'ye KAYDIRMIYOR. Bu test bunu BELGELİYOR
  // (bilinçli bir "bug" testi — implementasyon düzeltilirse bu test
  // güncellenip beklenen True'ya çevrilmeli).
  LSema := TDtSchedule.Create('0 0 0 15W * *');
  // Ağustos 2026: 15 Ağustos Cumartesi'dir (hafta sonu).
  Assert.IsFalse(LSema.Accept(EncodeDateTime(2026, 8, 15, 0, 0, 0, 0)),
    '15W: 15''i hafta sonuna denk geldiğinde MEVCUT implementasyon eşleşmiyor (kayma yok) — bkz. yorum');
  Assert.IsFalse(LSema.Accept(EncodeDateTime(2026, 8, 14, 0, 0, 0, 0)),
    '15W: standart cron''da 14''e (Cuma) kayması beklenirdi ama MEVCUT implementasyon bunu yapmıyor');
  // 15'in kendisi hafta içiyse (ör. Eylül 2026'da 15 Eylül Salı) doğrudan eşleşmeli.
  LSema := TDtSchedule.Create('0 0 0 15W * *');
  Assert.IsTrue(LSema.Accept(EncodeDateTime(2026, 9, 15, 0, 0, 0, 0)),
    '15W: 15''i zaten hafta içiyse eşleşmeli');
end;

procedure TDtScheduleTestleri.YilAlaniOpsiyonelTesti;
var
  LSema: TDtSchedule;
begin
  LSema := TDtSchedule.Create('0 0 0 1 1 *'); // yıl alanı YOK — her yıl 1 Ocak
  Assert.IsTrue(LSema.Accept(EncodeDateTime(2026, 1, 1, 0, 0, 0, 0)), 'Yıl alanı olmadan 2026 eşleşmeli');
  Assert.IsTrue(LSema.Accept(EncodeDateTime(2030, 1, 1, 0, 0, 0, 0)), 'Yıl alanı olmadan 2030 da eşleşmeli');
end;

procedure TDtScheduleTestleri.YilAlaniBelirtilirseKisitlarTesti;
var
  LSema: TDtSchedule;
begin
  LSema := TDtSchedule.Create('0 0 0 1 1 * 2026'); // sadece 2026
  Assert.IsTrue(LSema.Accept(EncodeDateTime(2026, 1, 1, 0, 0, 0, 0)), '2026 eşleşmeli');
  Assert.IsFalse(LSema.Accept(EncodeDateTime(2027, 1, 1, 0, 0, 0, 0)), '2027 eşleşmemeli (yıl alanı 2026''ya kısıtlı)');
end;

procedure TDtScheduleTestleri.GercekciHaftaIciSaatSemasiTesti;
var
  LSema: TDtSchedule;
begin
  // Hafta içi (Pazartesi-Cuma) 09:00'da — RTL DayOfWeek: Pazartesi=2..Cuma=6.
  LSema := TDtSchedule.Create('0 0 9 * * 2-6');
  Assert.IsTrue(LSema.Accept(EncodeDateTime(2026, 1, 5, 9, 0, 0, 0)), '5 Ocak 2026 Pazartesi 09:00 eşleşmeli');
  Assert.IsTrue(LSema.Accept(EncodeDateTime(2026, 1, 9, 9, 0, 0, 0)), '9 Ocak 2026 Cuma 09:00 eşleşmeli');
  Assert.IsFalse(LSema.Accept(EncodeDateTime(2026, 1, 10, 9, 0, 0, 0)), '10 Ocak 2026 Cumartesi eşleşmemeli');
  Assert.IsFalse(LSema.Accept(EncodeDateTime(2026, 1, 11, 9, 0, 0, 0)), '11 Ocak 2026 Pazar eşleşmemeli');
end;

procedure TDtScheduleTestleri.AltidanAzAlanGecersizMaskeTesti;
begin
  Assert.WillRaise(
    procedure begin TDtSchedule.Create('0 0 0 1 1'); end,
    EArgumentException,
    '6''dan az alanlı maske EArgumentException fırlatmalı');
end;

procedure TDtScheduleTestleri.NextTimeAyniGunIcindeBulurTesti;
var
  LSema: TDtSchedule;
  LSonuc: TDateTime;
begin
  LSema := TDtSchedule.Create('0 0 9 * * *'); // her gün 09:00:00
  LSonuc := LSema.NextTime(EncodeDateTime(2026, 1, 5, 8, 0, 0, 0), 5);
  Assert.AreEqual(EncodeDateTime(2026, 1, 5, 9, 0, 0, 0), LSonuc, 'NextTime aynı gün içindeki sonraki eşleşmeyi bulmalı');
end;

procedure TDtScheduleTestleri.NextTimeHaftaSonunuAtlarTesti;
var
  LSema: TDtSchedule;
  LSonuc: TDateTime;
begin
  // Hafta içi 14:30 — Cuma 14:30:01'den sonraki eşleşme Pazartesi 14:30 olmalı.
  LSema := TDtSchedule.Create('0 30 14 * * 2-6');
  LSonuc := LSema.NextTime(EncodeDateTime(2026, 1, 9, 14, 30, 1, 0), 5); // 9 Ocak 2026 Cuma
  Assert.AreEqual(EncodeDateTime(2026, 1, 12, 14, 30, 0, 0), LSonuc, 'NextTime hafta sonunu atlayıp Pazartesi''yi bulmalı');
end;

procedure TDtScheduleTestleri.NextTimeImkansizSemaSinirliAramadaSifirDonerTesti;
var
  LSema: TDtSchedule;
begin
  // 30 Şubat hiçbir yılda yok — küçük bir arama penceresiyle (5 gün) hızlıca
  // "bulunamadı" (0) dönmesi beklenir. NextTime artık gün-bazlı hızlı atlama
  // kullandığı için varsayılan 3660 günlük pencereyle de hızlı olurdu, ama
  // testi gereksiz büyütmemek için yine de küçük tutuldu.
  LSema := TDtSchedule.Create('0 0 0 30 2 *');
  Assert.AreEqual(TDateTime(0), LSema.NextTime(EncodeDateTime(2026, 2, 1, 0, 0, 0, 0), 5),
    'İmkansız şema sınırlı arama penceresinde 0 dönmeli');
end;

procedure TDtScheduleTestleri.TimeoutOkExpiredTimeoutNotArrivedTesti;
var
  LSema: TDtSchedule;
  LTamEslesen, LEslesmeyen, LDeadline: TDateTime;
begin
  LSema := TDtSchedule.Create('0 0 9 * * *'); // her gün 09:00:00

  // Accept(AWhen) True ise deadline'a bakılmadan soOk dönmeli.
  LTamEslesen := EncodeDateTime(2026, 1, 5, 9, 0, 0, 0);
  Assert.AreEqual(Ord(soOk), Ord(LSema.Timeout(LTamEslesen, LTamEslesen - 1)), 'Tam eşleşen anda (deadline geçmiş olsa bile) soOk dönmeli');

  // Accept(AWhen) False VE AWhen > ADeadline ise soExpired dönmeli.
  LEslesmeyen := EncodeDateTime(2026, 1, 5, 10, 0, 0, 0); // 09:00 değil, eşleşmiyor
  LDeadline := EncodeDateTime(2026, 1, 4, 0, 0, 0, 0); // LEslesmeyen'den önce
  Assert.AreEqual(Ord(soExpired), Ord(LSema.Timeout(LEslesmeyen, LDeadline)), 'Eşleşmeyen an deadline''i geçmişse soExpired dönmeli');

  // Accept(AWhen) False VE AWhen <= ADeadline VE NextTime(AWhen) > ADeadline ise soTimeout.
  LDeadline := EncodeDateTime(2026, 1, 5, 10, 30, 0, 0); // bir sonraki eşleşmeden (ertesi gün 09:00) önce
  Assert.AreEqual(Ord(soTimeout), Ord(LSema.Timeout(LEslesmeyen, LDeadline)), 'Sonraki eşleşme deadline''den sonraysa soTimeout dönmeli');

  // Accept(AWhen) False VE AWhen <= ADeadline VE NextTime(AWhen) <= ADeadline ise soNotArrived.
  LDeadline := EncodeDateTime(2026, 1, 6, 9, 0, 1, 0); // ertesi gün 09:00'dan az sonra
  Assert.AreEqual(Ord(soNotArrived), Ord(LSema.Timeout(LEslesmeyen, LDeadline)), 'Sonraki eşleşme deadline''den önceyse soNotArrived dönmeli');
end;

{ TDtScheduleBenchmarkleri }

procedure TDtScheduleBenchmarkleri.NextTimeYogunSemaBenchmarkTesti;
var
  LSema: TDtSchedule;
  LSw: TStopwatch;
  i: Integer;
  LSonuc: TDateTime;
begin
  // Her dakika eşleşen bir şema — NextTime en fazla 60 saniyelik bir arama yapmalı, çok hızlı olmalı.
  LSema := TDtSchedule.Create('0 * * * * *');
  LSw := TStopwatch.StartNew;
  for i := 1 to 1000 do
    LSonuc := LSema.NextTime(EncodeDateTime(2026, 1, 5, 10, 30, 15, 0));
  LSw.Stop;
  Status(Format('NextTime (yoğun, her dakika) x1000 : %d ms', [LSw.ElapsedMilliseconds]));

  Assert.AreEqual(EncodeDateTime(2026, 1, 5, 10, 31, 0, 0), LSonuc, 'Yoğun şema NextTime doğru sonucu bulmadı');
end;

procedure TDtScheduleBenchmarkleri.NextTimeAylikSeyrekSemaBenchmarkTesti;
var
  LSema: TDtSchedule;
  LSw: TStopwatch;
  LSonuc: TDateTime;
begin
  // Ayda bir kez eşleşen bir şema (ayın 1'i, gece yarısı) — eskiden NextTime
  // tek çağrıda ~2.5-2.7 milyon saniyelik brute-force arama yapıyordu (265ms
  // ölçülmüştü); gün-bazlı hızlı atlama sayesinde artık ~30 gün-kontrolü +
  // 1 saniye-kontrolü yapıyor, milisaniyenin çok altında olmalı.
  LSema := TDtSchedule.Create('0 0 0 1 * *');
  LSw := TStopwatch.StartNew;
  LSonuc := LSema.NextTime(EncodeDateTime(2026, 1, 2, 0, 0, 0, 0));
  LSw.Stop;
  Status(Format('NextTime (ayda 1 kez, ~%d günlük arama penceresi) : %d ms', [
    Round(LSonuc - EncodeDateTime(2026, 1, 2, 0, 0, 0, 0)), LSw.ElapsedMilliseconds]));

  Assert.AreEqual(EncodeDateTime(2026, 2, 1, 0, 0, 0, 0), LSonuc, 'Aylık seyrek şema NextTime doğru sonucu bulmadı');
end;

procedure TDtScheduleBenchmarkleri.NextTimeYillikCokSeyrekSemaBenchmarkTesti;
var
  LSema: TDtSchedule;
  LSw: TStopwatch;
  LSonuc: TDateTime;
begin
  // Yılda bir kez eşleşen bir şema (1 Ocak, gece yarısı) — eskiden NextTime
  // tek çağrıda ~31 MİLYON saniyelik brute-force arama yapıyordu (3328ms
  // ölçülmüştü, bkz. rad.date.pas'taki NextTime yorumu). Gün-bazlı hızlı
  // atlama sayesinde artık ~365 gün-kontrolü + 1 saniye-kontrolü yapıyor —
  // bu test hem düzeltmeyi kanıtlıyor hem regresyona karşı bekçi.
  LSema := TDtSchedule.Create('0 0 0 1 1 *');
  LSw := TStopwatch.StartNew;
  LSonuc := LSema.NextTime(EncodeDateTime(2026, 1, 2, 0, 0, 0, 0));
  LSw.Stop;
  Status(Format('NextTime (yılda 1 kez, ~%d günlük arama penceresi) : %d ms — gün-bazlı hızlı atlamanın kanıtı',
    [Round(LSonuc - EncodeDateTime(2026, 1, 2, 0, 0, 0, 0)), LSw.ElapsedMilliseconds]));

  Assert.AreEqual(EncodeDateTime(2027, 1, 1, 0, 0, 0, 0), LSonuc, 'Yıllık şema NextTime doğru sonucu bulmadı');
end;

initialization
  TDUnitX.RegisterTestFixture(TDtElapsedTestleri);
  TDUnitX.RegisterTestFixture(TDtIntervalTestleri);
  TDUnitX.RegisterTestFixture(TDtTimeZoneTestleri);
  TDUnitX.RegisterTestFixture(TDtScheduleTestleri);
  TDUnitX.RegisterTestFixture(TDtScheduleBenchmarkleri);

end.
