unit help.date.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.DateUtils,
  System.Diagnostics,
  help.date,
  rad.utils;

type
  [TestFixture]
  THelperDateTestleri = class
  public
    [Test]
    [TestCase('ISO8601 Gidis-Donus 1','2026,7,4,12,30,0')]
    [TestCase('ISO8601 Gidis-Donus 2','2000,1,1,0,0,0')]
    [TestCase('ISO8601 Gidis-Donus 3','2024,2,29,23,59,59')]
    procedure ISO8601GidisDonusTesti(const AYil, AAy, AGun, ASaat, ADakika, ASaniye: Integer);

    [Test]
    [TestCase('Bilesen Erisimi 1','15.03.2026,15,3,2026')]
    [TestCase('Bilesen Erisimi 2','01.01.2000,1,1,2000')]
    [TestCase('Bilesen Erisimi 3','31.12.2026,31,12,2026')]
    procedure BilesenErisimiTesti(const ATarihStr: string; const ABeklenenGun, ABeklenenAy, ABeklenenYil: Integer);

    [Test]
    [TestCase('Ceyrek Hesabi 1','15.01.2026,1')]
    [TestCase('Ceyrek Hesabi 2','15.05.2026,2')]
    [TestCase('Ceyrek Hesabi 3','15.08.2026,3')]
    [TestCase('Ceyrek Hesabi 4','15.11.2026,4')]
    procedure CeyrekHesabi(const ATarihStr: string; const ABeklenenCeyrek: Integer);

    [Test(true)]
    [AutoNameTestCase('20.06.2026,True')]
    [AutoNameTestCase('21.06.2026,True')]
    [AutoNameTestCase('22.06.2026,False')]
    [Category('Hafta Sonu Testi')]
    procedure HaftasonuTesti(const ATarihStr: string; const ABeklenenSonuc: Boolean);

    [Test(true)]
    [AutoNameTestCase('2024,True')]
    [AutoNameTestCase('2023,False')]
    [Category('Artik Yil Testi')]
    procedure ArtikYilTesti(const AYil: Integer; const ABeklenenSonuc: Boolean);

    [Test]
    [TestCase('ISO Hafta No 1 (2005-01-01)','2005,1,1,53')]
    [TestCase('ISO Hafta No 2 (2007-01-01)','2007,1,1,1')]
    [TestCase('ISO Hafta No 3 (2008-12-29)','2008,12,29,1')]
    [TestCase('ISO Hafta No 4 (2010-01-03)','2010,1,3,53')]
    [TestCase('ISO Hafta No 5 (2026-01-01)','2026,1,1,1')]
    [TestCase('ISO Hafta No 6 (2026-12-31)','2026,12,31,53')]
    procedure ISOHaftaNumarasiTesti(const AYil, AAy, AGun, ABeklenenHafta: Integer);

    [Test(true)]
    [AutoNameTestCase('2026,True')]
    [AutoNameTestCase('2023,False')]
    [Category('Uzun ISO Yili Testi')]
    procedure UzunISOYiliTesti(const AYil: Integer; const ABeklenenSonuc: Boolean);

    [Test]
    procedure ISOHaftadanTarihUretmeTesti;

    [Test]
    procedure KarsilastirmaToleransliEsitlikTesti;

    [Test]
    procedure KarsilastirmaBuyukKucukTesti;

    [Test]
    [TestCase('Ay Ekleme Tasma 1 (31 Ocak + 1 ay)','2026,1,31,2026,2,28')]
    [TestCase('Ay Ekleme Tasma 2 (31 Mart + 1 ay)','2026,3,31,2026,4,30')]
    procedure AyEklemeTesti(const AYil, AAy, AGun, ABeklenenYil, ABeklenenAy, ABeklenenGun: Integer);

    [Test]
    procedure DonemSinirlariAySinirlariTesti;

    [Test]
    procedure DonemSinirlariCeyrekSinirlariTesti;

    [Test]
    procedure DegistirTarihVeSaatTesti;

    [Test]
    procedure IsGunuIleriGeriTesti;

    [Test]
    procedure IsGunuNSayidaIlerletmeTesti;

    [Test]
    procedure YasTamYilDonumundeTesti;

    [Test]
    procedure YasDogumGunuHenuzGelmediysseTesti;

    [Test]
    procedure AyinNinciGunuRadUtilsIleTutarliTesti;

    [Test]
    procedure ZamanDamgasiGidisDonusTesti;

    [Test]
    procedure ZamanDamgasiKarsilastirmaTesti;
  end;

  // help.date.pas için TStopwatch tabanlı performans ölçümleri — ayrı bir dosya
  // DEĞİL, doğruluk testleriyle AYNI unit'te; sadece [Category('Benchmark')]
  // ile gruplanır (bkz. delphi-helper-builder skill, "Üretim" adımı).
  [TestFixture]
  //[name('Benchmark')]
  //[Category('Benchmark')]
  THelperDateBenchmarkleri = class
  const
    CIterations = 100000;
  public
    [Test]
    [Category('Benchmark')]
    procedure Iso8601BenchmarkTesti;

    [Test]
    [Category('Benchmark')]
    procedure BilesenErisimiBenchmarkTesti;

    [Test]
    [Category('Benchmark')]
    procedure DonemSinirlariBenchmarkTesti;

    [Test]
    [Category('Benchmark')]
    procedure IsoHaftaNoBenchmarkTesti;

    [Test]
    [Category('Benchmark')]
    procedure TimezoneBenchmarkTesti;

    [Test]
    [Category('Benchmark')]
    procedure IsGunuBenchmarkTesti;
  end;

implementation

function TarihDenemeDegeri(const ATarihStr: string): TDateTime;
var
  LParcalar: TArray<string>;
begin
  // "gg.aa.yyyy" biçimini sistem locale'ından bağımsız olarak ayrıştırır.
  LParcalar := ATarihStr.Split(['.']);
  Result := EncodeDate(StrToInt(LParcalar[2]), StrToInt(LParcalar[1]), StrToInt(LParcalar[0]));
end;

{ THelperDateTestleri }

procedure THelperDateTestleri.ISO8601GidisDonusTesti(const AYil, AAy, AGun, ASaat, ADakika, ASaniye: Integer);
var
  LOrijinal, LGeriDonen: TDateTime;
  LMetin: string;
begin
  LOrijinal := EncodeDateTime(AYil, AAy, AGun, ASaat, ADakika, ASaniye, 0);
  LMetin := LOrijinal._ToISO8601;
  LGeriDonen := TDateTime._FromISO8601(LMetin);
  Assert.IsTrue(LOrijinal._DateEQ(LGeriDonen),
    Format('ISO8601 gidiş-dönüş başarısız: %s -> %s -> beklenmeyen değer', [DateTimeToStr(LOrijinal), LMetin]));
end;

procedure THelperDateTestleri.BilesenErisimiTesti(const ATarihStr: string; const ABeklenenGun, ABeklenenAy, ABeklenenYil: Integer);
var
  LTarih: TDateTime;
begin
  LTarih := TarihDenemeDegeri(ATarihStr);
  Assert.AreEqual(ABeklenenGun, Integer(LTarih._Day), '_Day yanlış');
  Assert.AreEqual(ABeklenenAy, Integer(LTarih._Month), '_Month yanlış');
  Assert.AreEqual(ABeklenenYil, Integer(LTarih._Year), '_Year yanlış');
end;

procedure THelperDateTestleri.CeyrekHesabi(const ATarihStr: string; const ABeklenenCeyrek: Integer);
begin
  Assert.AreEqual(ABeklenenCeyrek, TarihDenemeDegeri(ATarihStr)._Quarter, '_Quarter yanlış');
end;

procedure THelperDateTestleri.HaftasonuTesti(const ATarihStr: string; const ABeklenenSonuc: Boolean);
begin
  Assert.AreEqual(ABeklenenSonuc, TarihDenemeDegeri(ATarihStr)._IsWeekend, '_IsWeekend yanlış');
end;

procedure THelperDateTestleri.ArtikYilTesti(const AYil: Integer; const ABeklenenSonuc: Boolean);
begin
  Assert.AreEqual(ABeklenenSonuc, EncodeDate(AYil, 1, 1)._IsLeapYear, '_IsLeapYear yanlış');
end;

procedure THelperDateTestleri.ISOHaftaNumarasiTesti(const AYil, AAy, AGun, ABeklenenHafta: Integer);
begin
  Assert.AreEqual(ABeklenenHafta, Integer(EncodeDate(AYil, AAy, AGun)._ISOWeekNumber),
    '_ISOWeekNumber yanlış');
end;

procedure THelperDateTestleri.UzunISOYiliTesti(const AYil: Integer; const ABeklenenSonuc: Boolean);
begin
  Assert.AreEqual(ABeklenenSonuc, EncodeDate(AYil, 1, 1)._IsISOLongYear, '_IsISOLongYear yanlış');
end;

procedure THelperDateTestleri.ISOHaftadanTarihUretmeTesti;
begin
  // 2026 Perşembe günü başlıyor; 4 Ocak Pazar'a denk gelir, o haftanın Pazartesi'si 29 Aralık 2025'tir.
  Assert.IsTrue(EncodeDate(2025, 12, 29)._DateEQ(TDateTime._FromISOWeek(2026, 1, 1)),
    '_FromISOWeek(2026,1,1) beklenen Pazartesi''yi üretmedi');
end;

procedure THelperDateTestleri.KarsilastirmaToleransliEsitlikTesti;
var
  LTarih1, LCokKucukFark, LBuyukFark: TDateTime;
begin
  // CDateTolerance ~0.1 ms'dir (help.date.pas'taki yorum) — 1 ms bunun 10 katı,
  // yani tolerans İÇİNDE değil. Burada gerçekten toleransın altında (0.01 ms)
  // bir fark ve toleransın üstünde (1 ms) bir fark ayrı ayrı sınanıyor.
  LTarih1 := EncodeDateTime(2026, 7, 4, 12, 0, 0, 0);
  LCokKucukFark := LTarih1 + (0.01 / (24 * 60 * 60 * 1000));
  LBuyukFark := LTarih1 + (1 / (24 * 60 * 60 * 1000));
  Assert.IsTrue(LTarih1._DateEQ(LCokKucukFark), '_DateEQ tolerans altındaki farkı eşit saymadı');
  Assert.IsFalse(LTarih1._DateEQ(LBuyukFark), '_DateEQ tolerans üstündeki farkı (1ms) yanlışlıkla eşit saydı');
end;

procedure THelperDateTestleri.KarsilastirmaBuyukKucukTesti;
var
  LOnce, LSonra: TDateTime;
begin
  LOnce := EncodeDate(2026, 1, 1);
  LSonra := EncodeDate(2026, 12, 31);
  Assert.IsTrue(LOnce._DateLT(LSonra), '_DateLT yanlış');
  Assert.IsTrue(LSonra._DateGT(LOnce), '_DateGT yanlış');
  Assert.IsTrue(LOnce._DateLE(LOnce), '_DateLE kendisiyle eşit olmalı');
  Assert.IsTrue(LSonra._DateGE(LSonra), '_DateGE kendisiyle eşit olmalı');
end;

procedure THelperDateTestleri.AyEklemeTesti(const AYil, AAy, AGun, ABeklenenYil, ABeklenenAy, ABeklenenGun: Integer);
var
  LSonuc, LBeklenen: TDateTime;
begin
  LSonuc := EncodeDate(AYil, AAy, AGun)._IncMonth(1);
  LBeklenen := EncodeDate(ABeklenenYil, ABeklenenAy, ABeklenenGun);
  Assert.IsTrue(LBeklenen._DateEQ(LSonuc),
    Format('_IncMonth taşma durumunu doğru yönetmedi: %s', [DateTimeToStr(LSonuc)]));
end;

procedure THelperDateTestleri.DonemSinirlariAySinirlariTesti;
var
  LTarih: TDateTime;
begin
  LTarih := EncodeDate(2026, 2, 15);
  Assert.IsTrue(EncodeDate(2026, 2, 1)._DateEQ(LTarih._StartOfMonth), '_StartOfMonth yanlış');
  Assert.IsTrue(EncodeDate(2026, 2, 28)._DateEQ(Trunc(LTarih._EndOfMonth)), '_EndOfMonth yanlış (Şubat 2026 = 28 gün)');
end;

procedure THelperDateTestleri.DonemSinirlariCeyrekSinirlariTesti;
var
  LTarih: TDateTime;
begin
  LTarih := EncodeDate(2026, 5, 10); // 2. çeyrek
  Assert.IsTrue(EncodeDate(2026, 4, 1)._DateEQ(LTarih._StartOfQuarter), '_StartOfQuarter yanlış');
  Assert.IsTrue(EncodeDate(2026, 6, 30)._DateEQ(Trunc(LTarih._EndOfQuarter)), '_EndOfQuarter yanlış');
end;

procedure THelperDateTestleri.DegistirTarihVeSaatTesti;
var
  LTarih, LSonuc: TDateTime;
begin
  LTarih := EncodeDateTime(2026, 7, 4, 8, 15, 30, 0);
  LSonuc := LTarih._ChangeTime(9, 0, 0);
  Assert.AreEqual(2026, Integer(LSonuc._Year), '_ChangeTime tarihi bozmamalı (yıl)');
  Assert.AreEqual(9, Integer(LSonuc._Hour), '_ChangeTime saati değiştirmedi');
  Assert.AreEqual(0, Integer(LSonuc._Minute), '_ChangeTime dakikayı değiştirmedi');

  LSonuc := LTarih._ChangeDate(2027, 1, 1);
  Assert.AreEqual(2027, Integer(LSonuc._Year), '_ChangeDate yılı değiştirmedi');
  Assert.AreEqual(8, Integer(LSonuc._Hour), '_ChangeDate saati bozmamalı');
end;

procedure THelperDateTestleri.IsGunuIleriGeriTesti;
var
  LCuma, LSonraki, LOnceki: TDateTime;
begin
  LCuma := EncodeDate(2026, 7, 3); // Cuma
  LSonraki := LCuma._NextWorkingDay;
  Assert.IsTrue(EncodeDate(2026, 7, 6)._DateEQ(LSonraki), '_NextWorkingDay hafta sonunu atlamadı (Pazartesi bekleniyor)');

  LOnceki := EncodeDate(2026, 7, 6)._PrevWorkingDay; // Pazartesi'den geriye
  Assert.IsTrue(LCuma._DateEQ(LOnceki), '_PrevWorkingDay hafta sonunu atlamadı (Cuma bekleniyor)');
end;

procedure THelperDateTestleri.IsGunuNSayidaIlerletmeTesti;
var
  LBaslangic, LSonuc: TDateTime;
begin
  LBaslangic := EncodeDate(2026, 7, 3); // Cuma
  LSonuc := LBaslangic._IncWorkDays(1);
  Assert.IsTrue(EncodeDate(2026, 7, 6)._DateEQ(LSonuc), '_IncWorkDays(1) hafta sonunu atlamadı');
end;

procedure THelperDateTestleri.YasTamYilDonumundeTesti;
var
  LDogum: TDateTime;
begin
  LDogum := IncYear(Date, -30); // bugünün ay/günüyle tam 30 yıl önce = doğum günü bugün
  Assert.AreEqual(30, LDogum._Age, 'Doğum günü tam bugünse yaş 30 olmalı');
end;

procedure THelperDateTestleri.YasDogumGunuHenuzGelmediysseTesti;
var
  LDogum: TDateTime;
begin
  LDogum := IncDay(IncYear(Date, -30), 1); // doğum günü yarın, henüz gelmedi
  Assert.AreEqual(29, LDogum._Age, 'Doğum günü henüz gelmediyse yaş bir eksik olmalı');
end;

procedure THelperDateTestleri.AyinNinciGunuRadUtilsIleTutarliTesti;
begin
  // help.date._DayOfMonth2Date, rad.utils.DayOfMonth2Date'e ince bir sarmalayıcıdır;
  // bu test o delegasyonun kırılmadığını doğrular (bkz. help.date.pas yorumu).
  Assert.IsTrue(rad.utils.DayOfMonth2Date(2026, 12, 5, 1)._DateEQ(TDateTime._DayOfMonth2Date(2026, 12, 5, 1)),
    '_DayOfMonth2Date, rad.utils.DayOfMonth2Date ile tutarsız sonuç üretti');
end;

procedure THelperDateTestleri.ZamanDamgasiGidisDonusTesti;
var
  LTarih, LGeriDonen: TDateTime;
  LStamp: TTimeStamp;
begin
  LTarih := EncodeDateTime(2026, 7, 4, 12, 30, 15, 0);
  LStamp := LTarih._ToTimeStamp;
  LGeriDonen := TDateTime._FromTimeStamp(LStamp);
  Assert.IsTrue(LTarih._DateEQ(LGeriDonen), '_ToTimeStamp/_FromTimeStamp gidiş-dönüşü başarısız');
end;

procedure THelperDateTestleri.ZamanDamgasiKarsilastirmaTesti;
var
  LStamp1, LStamp2: TTimeStamp;
begin
  LStamp1 := EncodeDate(2026, 1, 1)._ToTimeStamp;
  LStamp2 := EncodeDate(2026, 1, 2)._ToTimeStamp;
  Assert.IsTrue(TDateTime._CompareTimeStamps(LStamp1, LStamp2) < 0, '_CompareTimeStamps sıralamayı yanlış hesapladı');
  Assert.IsFalse(TDateTime._EqualTimeStamps(LStamp1, LStamp2), '_EqualTimeStamps farklı damgaları eşit saydı');
  Assert.IsTrue(TDateTime._IsNullTimeStamp(Default(TTimeStamp)), '_IsNullTimeStamp sıfır damgayı tanımadı');
end;

{ THelperDateBenchmarkleri }

procedure THelperDateBenchmarkleri.Iso8601BenchmarkTesti;
var
  LSw: TStopwatch;
  i: Integer;
  LNow: TDateTime;
  LText: string;
begin
  LNow := Now;
  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations do
    LText := LNow._ToISO8601;
  LSw.Stop;
  Status(Format('_ToISO8601            x%d : %d ms', [CIterations, LSw.ElapsedMilliseconds]));

  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations do
    LNow := TDateTime._FromISO8601(LText);
  LSw.Stop;
  Status(Format('_FromISO8601          x%d : %d ms', [CIterations, LSw.ElapsedMilliseconds]));

  // Sağlık kontrolü: ölçüm sırasında sonuçlar hâlâ tutarlı mı (DUnitX assertion'sız testi hata sayıyor).
  Assert.IsTrue(LText <> '', '_ToISO8601 boş sonuç üretti');
  Assert.IsTrue(LNow > 0, '_FromISO8601 geçersiz bir tarih döndürdü');
end;

procedure THelperDateBenchmarkleri.BilesenErisimiBenchmarkTesti;
var
  LSw: TStopwatch;
  i: Integer;
  LNow: TDateTime;
  LY, LM, LD: Word;
begin
  LNow := Now;

  // NOT: _Year/_Month/_Day zaten içeride System.SysUtils.DecodeDate'i
  // çağırıyor (help.date.pas) — yani RTL DecodeDate'e karşı bir "hız
  // kıyası" ANLAMSIZ olurdu, ikisi de aynı fonksiyonu çalıştırıyor (bu
  // ancak Decode algoritmasının kendisi değişseydi anlamlı olurdu). Burada
  // sadece _Year+_Month+_Day'i AYRI AYRI çağırmanın gerçek maliyeti bilgi
  // amaçlı raporlanıyor (üçü de kendi içinde bağımsız birer DecodeDate
  // yapıyor, yani bu 3 kat DecodeDate demek — hepsini istiyorsan doğrudan
  // DecodeDate kullanmak daha verimli).
  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations do
  begin
    LY := LNow._Year;
    LM := LNow._Month;
    LD := LNow._Day;
  end;
  LSw.Stop;
  Status(Format('_Year+_Month+_Day (3 AYRI çağrı, 3 DecodeDate) x%d : %d ms', [CIterations, LSw.ElapsedMilliseconds]));

  Assert.IsTrue((LM >= 1) and (LM <= 12) and (LD >= 1) and (LD <= 31), '_Year/_Month/_Day geçersiz bileşen üretti');
end;

procedure THelperDateBenchmarkleri.DonemSinirlariBenchmarkTesti;
var
  LSw: TStopwatch;
  i: Integer;
  LNow, LTmp: TDateTime;
begin
  LNow := Now;

  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations do
    LTmp := LNow._StartOfMonth;
  LSw.Stop;
  Status(Format('_StartOfMonth         x%d : %d ms', [CIterations, LSw.ElapsedMilliseconds]));

  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations do
    LTmp := LNow._EndOfQuarter;
  LSw.Stop;
  Status(Format('_EndOfQuarter         x%d : %d ms', [CIterations, LSw.ElapsedMilliseconds]));

  Assert.IsTrue(LTmp > 0, '_EndOfQuarter geçersiz bir tarih döndürdü');
end;

procedure THelperDateBenchmarkleri.IsoHaftaNoBenchmarkTesti;
var
  LSw: TStopwatch;
  i: Integer;
  LNow: TDateTime;
  LWeek: Word;
begin
  LNow := Now;
  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations do
    LWeek := LNow._ISOWeekNumber;
  LSw.Stop;
  Status(Format('_ISOWeekNumber        x%d : %d ms', [CIterations, LSw.ElapsedMilliseconds]));

  Assert.IsTrue((LWeek >= 1) and (LWeek <= 53), '_ISOWeekNumber geçersiz bir hafta no üretti');
end;

procedure THelperDateBenchmarkleri.TimezoneBenchmarkTesti;
var
  LSw: TStopwatch;
  i: Integer;
  LNow, LUtc: TDateTime;
begin
  LNow := Now;

  // Not: mORMot2 TSynTimeZone çağrıları RTL TTimeZone'a göre daha yavaş
  // olabilir (isim çözümleme maliyeti) — bu yüzden döngü sayısı düşük tutuldu.
  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations div 100 do
    LUtc := LNow._ToUtc('Turkey Standard Time');
  LSw.Stop;
  Status(Format('_ToUtc (named TZ)     x%d : %d ms', [CIterations div 100, LSw.ElapsedMilliseconds]));

  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations div 100 do
    LUtc := LNow._ToUtc; // yerel makine, RTL TTimeZone.Local
  LSw.Stop;
  Status(Format('_ToUtc (yerel)        x%d : %d ms', [CIterations div 100, LSw.ElapsedMilliseconds]));

  Assert.IsTrue(LUtc > 0, '_ToUtc geçersiz bir tarih döndürdü');
end;

procedure THelperDateBenchmarkleri.IsGunuBenchmarkTesti;
var
  LSw: TStopwatch;
  i: Integer;
  LNow, LTmp: TDateTime;
begin
  LNow := Now;

  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations div 10 do
    LTmp := LNow._NextWorkingDay;
  LSw.Stop;
  Status(Format('_NextWorkingDay       x%d : %d ms', [CIterations div 10, LSw.ElapsedMilliseconds]));

  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations div 1000 do
    LTmp := LNow._IncWorkDays(20); // döngü-içi döngü, en pahalı yol
  LSw.Stop;
  Status(Format('_IncWorkDays(20)      x%d : %d ms', [CIterations div 1000, LSw.ElapsedMilliseconds]));

  Assert.IsTrue(LTmp > 0, '_IncWorkDays geçersiz bir tarih döndürdü');
end;

initialization
  TDUnitX.RegisterTestFixture(THelperDateTestleri);
  TDUnitX.RegisterTestFixture(THelperDateBenchmarkleri);

end.
