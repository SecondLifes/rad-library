unit help.str.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Diagnostics,
  help.str;

type
  [TestFixture]
  THelperStringTestleri = class
  public
    [Test]
    [TestCase('Turkce Buyuk Harf 1','istanbul,İSTANBUL')]
    [TestCase('Turkce Buyuk Harf 2','izmir,İZMİR')]
    [TestCase('Turkce Buyuk Harf 3','ankara,ANKARA')]
    procedure TurkceBuyukHarfTesti(const AMetin, ABeklenen: string);

    [Test]
    [TestCase('Turkce Kucuk Harf 1','İSTANBUL,istanbul')]
    [TestCase('Turkce Kucuk Harf 2','IZMIR,ızmır')]
    procedure TurkceKucukHarfTesti(const AMetin, ABeklenen: string);

    [Test]
    procedure BaslikDurumuTesti;

    [Test]
    [TestCase('CamelCase 1','kullanici_adi,kullaniciAdi')]
    [TestCase('CamelCase 2','Kullanici Soyadi,kullaniciSoyadi')]
    procedure CamelCaseTesti(const AMetin, ABeklenen: string);

    [Test]
    [TestCase('PascalCase 1','kullanici_adi,KullaniciAdi')]
    procedure PascalCaseTesti(const AMetin, ABeklenen: string);

    [Test]
    [TestCase('SnakeCase 1','KullaniciAdi,kullanici_adi')]
    procedure SnakeCaseTesti(const AMetin, ABeklenen: string);

    [Test]
    procedure OrtalamaTesti;

    [Test]
    procedure KisaltmaEllipsisTesti;

    [Test]
    procedure MaskelemeTesti;

    [Test]
    procedure TekrarVeTersCevirmeTesti;

    [Test]
    [TestCase('Ensure Suffix Eksikse Ekler','help,.pas,help.pas')]
    [TestCase('Ensure Suffix Zaten Varsa Dokunmaz','help.pas,.pas,help.pas')]
    procedure EnsureSuffixTesti(const AMetin, AEk, ABeklenen: string);

    [Test]
    [TestCase('Ensure NoPrefix Varsa Cikarir','TFoo,T,Foo')]
    [TestCase('Ensure NoPrefix Yoksa Dokunmaz','Foo,T,Foo')]
    procedure EnsureNoPrefixTesti(const AMetin, AOnek, ABeklenen: string);

    [Test]
    procedure BosSeVarsayilanTesti;

    [Test]
    procedure SayisalGuvenliDonusumTesti;

    [Test]
    [TestCase('Alfa Testi 1','Ahmet,True')]
    [TestCase('Alfa Testi 2','Ahmet1,False')]
    [TestCase('Alfa Testi 3',',False')]
    procedure IsAlphaTesti(const AMetin: string; const ABeklenenSonuc: Boolean);

    [Test]
    [TestCase('Sadece Rakam Testi 1','12345,True')]
    [TestCase('Sadece Rakam Testi 2','123a5,False')]
    procedure IsDigitsOnlyTesti(const AMetin: string; const ABeklenenSonuc: Boolean);

    [Test]
    procedure IsOneOfVeEsitlikTesti;

    [Test]
    procedure OnekSonekListesiTesti;

    [Test]
    procedure IcerirListesiTesti;

    [Test]
    [TestCase('Dogal Siralama 1','dosya2,dosya10,-1')]
    [TestCase('Dogal Siralama 2','dosya10,dosya2,1')]
    [TestCase('Dogal Siralama 3','dosya5,dosya5,0')]
    procedure DogalSiralamaTesti(const AMetin1, AMetin2: string; const ABeklenenIsaret: Integer);

    [Test]
    procedure LevenshteinMesafeTesti;

    [Test]
    procedure BenzerlikOraniTesti;

    [Test]
    procedure JokerKarakterEslesmeTesti;

    [Test]
    procedure SolSagAlmaTesti;

    [Test]
    procedure OnceSonraArasiTesti;

    [Test]
    procedure BoslukKirpilmisBolmeTesti;

    [Test]
    procedure BirlestirmeTesti;

    [Test]
    procedure RawUtf8GidisDonusTesti;

    { 2026-07-09 incelemesi (1.md/2.md, help.str.pas) sonrası eklenen testler }

    [Test]
    [TestCase('Dogal Siralama Buyuk Sayi 1','dosya999999999999999999999999,dosya2,1')]
    [TestCase('Dogal Siralama Buyuk Sayi 2','dosya0002,dosya2,0')]
    procedure DogalSiralamaBuyukSayiTesti(const AMetin1, AMetin2: string; const ABeklenenIsaret: Integer);

    [Test]
    [TestCase('Snake Case Acronym Rakam 1','HTTPServer,http_server')]
    [TestCase('Snake Case Acronym Rakam 2','SHA256Hash,sha256_hash')]
    procedure SnakeCaseAcronymRakamTesti(const AMetin, ABeklenen: string);

    [Test]
    [TestCase('Camel Case Acronym 1','HTTPServer,httpServer')]
    procedure CamelCaseAcronymTesti(const AMetin, ABeklenen: string);

    [Test]
    [TestCase('Baslik Durumu Genisletilmis Sinir 1','merhaba-dunya,Merhaba-Dunya')]
    [TestCase('Baslik Durumu Genisletilmis Sinir 2','foo.bar,Foo.Bar')]
    procedure BaslikDurumuGenisletilmisSinirTesti(const AMetin, ABeklenen: string);

    [Test]
    procedure TekrarMetinSinirDegerleriTesti;

    [Test]
    procedure MaskelemeNegatifClampTesti;

    [Test]
    procedure SagAlmaNegatifClampTesti;
  end;

  // help.str.pas için TStopwatch tabanlı performans ölçümleri — ayrı bir
  // dosya DEĞİL, doğruluk testleriyle AYNI unit'te; sadece [Category('Benchmark')]
  // ile gruplanır (bkz. delphi-helper-builder skill, "Üretim" adımı).
  [TestFixture]
  THelperStringBenchmarkleri = class
  const
    CIterations = 100000;
    CSample = 'Merhaba Dünya, İstanbul''dan Kısa Bir Örnek Metin 123';
  public
    [Test]
    [Category('Benchmark')]
    procedure TurkceCaseBenchmarkTesti;

    [Test]
    [Category('Benchmark')]
    procedure CaseDonusumleriBenchmarkTesti;

    [Test]
    [Category('Benchmark')]
    procedure DogalSiralamaBenchmarkTesti;

    [Test]
    [Category('Benchmark')]
    procedure LevenshteinBenchmarkTesti;

    [Test]
    [Category('Benchmark')]
    procedure CikarmaBenchmarkTesti;

    [Test]
    [Category('Benchmark')]
    procedure RawUtf8KoprusuBenchmarkTesti;
  end;

implementation
  uses mormot.core.base, mormot.core.text;
{ THelperStringTestleri }

procedure THelperStringTestleri.TurkceBuyukHarfTesti(const AMetin, ABeklenen: string);
begin
  Assert.AreEqual(ABeklenen, AMetin._ToUpperTR, '_ToUpperTR yanlış');
end;

procedure THelperStringTestleri.TurkceKucukHarfTesti(const AMetin, ABeklenen: string);
begin
  Assert.AreEqual(ABeklenen, AMetin._ToLowerTR, '_ToLowerTR yanlış');
end;

procedure THelperStringTestleri.BaslikDurumuTesti;
begin
  Assert.AreEqual('Merhaba Dünya', 'merhaba dünya'._ToTitleCase, '_ToTitleCase yanlış');
end;

procedure THelperStringTestleri.CamelCaseTesti(const AMetin, ABeklenen: string);
begin
  Assert.AreEqual(ABeklenen, AMetin._ToCamelCase, '_ToCamelCase yanlış');
end;

procedure THelperStringTestleri.PascalCaseTesti(const AMetin, ABeklenen: string);
begin
  Assert.AreEqual(ABeklenen, AMetin._ToPascalCase, '_ToPascalCase yanlış');
end;

procedure THelperStringTestleri.SnakeCaseTesti(const AMetin, ABeklenen: string);
begin
  Assert.AreEqual(ABeklenen, AMetin._ToSnakeCase, '_ToSnakeCase yanlış');
end;

procedure THelperStringTestleri.OrtalamaTesti;
begin
  Assert.AreEqual('   abc   ', 'abc'._Center(9), '_Center yanlış');
  Assert.AreEqual('abcdefgh', 'abcdefgh'._Center(5), '_Center zaten uzun stringi kısaltmamalı');
end;

procedure THelperStringTestleri.KisaltmaEllipsisTesti;
begin
  Assert.AreEqual('1234567890', '1234567890'._Truncate(20), '_Truncate kısa stringe dokunmamalı');
  Assert.AreEqual('1234567...', '12345678901234'._Truncate(10), '_Truncate uzun stringi doğru kesmedi');
end;

procedure THelperStringTestleri.MaskelemeTesti;
begin
  Assert.AreEqual('1234********3456', '1234567890123456'._Mask(4, 4), '_Mask yanlış');
end;

procedure THelperStringTestleri.TekrarVeTersCevirmeTesti;
begin
  Assert.AreEqual('ababab', 'ab'._RepeatText(3), '_RepeatText yanlış');
  Assert.AreEqual('cba', 'abc'._Reverse, '_Reverse yanlış');
end;

procedure THelperStringTestleri.EnsureSuffixTesti(const AMetin, AEk, ABeklenen: string);
begin
  Assert.AreEqual(ABeklenen, AMetin._EnsureSuffix(AEk), '_EnsureSuffix yanlış');
end;

procedure THelperStringTestleri.EnsureNoPrefixTesti(const AMetin, AOnek, ABeklenen: string);
begin
  Assert.AreEqual(ABeklenen, AMetin._EnsureNoPrefix(AOnek), '_EnsureNoPrefix yanlış');
end;

procedure THelperStringTestleri.BosSeVarsayilanTesti;
begin
  Assert.AreEqual('(boş)', ''._DefaultIfEmpty('(boş)'), '_DefaultIfEmpty yanlış');
  Assert.AreEqual('dolu', 'dolu'._DefaultIfEmpty('(boş)'), '_DefaultIfEmpty dolu stringe dokunmamalı');
  Assert.AreEqual('(boş)', '   '._DefaultIfWhiteSpace('(boş)'), '_DefaultIfWhiteSpace yanlış');
end;

procedure THelperStringTestleri.SayisalGuvenliDonusumTesti;
var
  LDeger: Integer;
begin
  Assert.AreEqual(-1, 'abc'._ToIntOrDefault(-1), '_ToIntOrDefault geçersiz girdide varsayılanı dönmedi');
  Assert.AreEqual(42, '42'._ToIntOrDefault(-1), '_ToIntOrDefault geçerli girdiyi doğru çevirmedi');
  Assert.IsTrue('42'._TryToInt(LDeger), '_TryToInt geçerli girdide False döndü');
  Assert.AreEqual(42, LDeger, '_TryToInt yanlış değer üretti');
  Assert.IsFalse('abc'._TryToInt(LDeger), '_TryToInt geçersiz girdide True döndü');
end;

procedure THelperStringTestleri.IsAlphaTesti(const AMetin: string; const ABeklenenSonuc: Boolean);
begin
  Assert.AreEqual(ABeklenenSonuc, AMetin._IsAlpha, '_IsAlpha yanlış');
end;

procedure THelperStringTestleri.IsDigitsOnlyTesti(const AMetin: string; const ABeklenenSonuc: Boolean);
begin
  Assert.AreEqual(ABeklenenSonuc, AMetin._IsDigitsOnly, '_IsDigitsOnly yanlış');
end;

procedure THelperStringTestleri.IsOneOfVeEsitlikTesti;
begin
  Assert.IsTrue('Ahmet'._IsOneOf(['Ahmet', 'Mehmet']), '_IsOneOf bulunması gerekeni bulamadı');
  Assert.IsFalse('Ali'._IsOneOf(['Ahmet', 'Mehmet']), '_IsOneOf olmayanı buldu');
  Assert.IsTrue('Merhaba'._EqualsIgnoreCase('MERHABA'), '_EqualsIgnoreCase büyük/küçük harf duyarsız olmalı');
end;

procedure THelperStringTestleri.OnekSonekListesiTesti;
begin
  Assert.IsTrue('help.pas'._HasSuffixOf(['.pas', '.dpr']), '_HasSuffixOf bulunması gerekeni bulamadı');
  Assert.IsFalse('help.txt'._HasSuffixOf(['.pas', '.dpr']), '_HasSuffixOf olmayanı buldu');
  Assert.IsTrue('THelperString'._HasPrefixOf(['T', 'I']), '_HasPrefixOf bulunması gerekeni bulamadı');
end;

procedure THelperStringTestleri.IcerirListesiTesti;
begin
  Assert.IsTrue('merhaba dünya'._ContainsAny(['xyz', 'dünya']), '_ContainsAny bulunması gerekeni bulamadı');
  Assert.IsFalse('merhaba dünya'._ContainsAny(['xyz', 'abc']), '_ContainsAny olmayanı buldu');
  Assert.IsTrue('merhaba dünya'._ContainsAll(['merhaba', 'dünya']), '_ContainsAll ikisi de varken False döndü');
  Assert.IsFalse('merhaba dünya'._ContainsAll(['merhaba', 'xyz']), '_ContainsAll biri yokken True döndü');
end;

procedure THelperStringTestleri.DogalSiralamaTesti(const AMetin1, AMetin2: string; const ABeklenenIsaret: Integer);
var
  LSonuc: Integer;
begin
  LSonuc := AMetin1._CompareNatural(AMetin2);
  case ABeklenenIsaret of
    -1: Assert.IsTrue(LSonuc < 0, Format('_CompareNatural(%s,%s) negatif olmalıydı, %d döndü', [AMetin1, AMetin2, LSonuc]));
    1: Assert.IsTrue(LSonuc > 0, Format('_CompareNatural(%s,%s) pozitif olmalıydı, %d döndü', [AMetin1, AMetin2, LSonuc]));
    0: Assert.AreEqual(0, LSonuc, Format('_CompareNatural(%s,%s) sıfır olmalıydı', [AMetin1, AMetin2]));
  end;
end;

procedure THelperStringTestleri.LevenshteinMesafeTesti;
begin
  Assert.AreEqual(3, 'kitten'._LevenshteinDistance('sitting'), '_LevenshteinDistance klasik örnekte yanlış sonuç verdi');
  Assert.AreEqual(0, 'ayni'._LevenshteinDistance('ayni'), '_LevenshteinDistance aynı stringlerde 0 dönmeli');
end;

procedure THelperStringTestleri.BenzerlikOraniTesti;
begin
  Assert.AreEqual(1.0, 'ayni'._SimilarityRatio('ayni'), 0.0001, '_SimilarityRatio aynı stringlerde 1.0 olmalı');
  Assert.IsTrue('kitten'._SimilarityRatio('sitting') > 0, '_SimilarityRatio negatif/sıfır olmamalı');
end;

procedure THelperStringTestleri.JokerKarakterEslesmeTesti;
begin
  Assert.IsTrue('help.pas'._IsWildcardMatch('*.pas'), '_IsWildcardMatch basit joker eşleşmesini bulamadı');
  Assert.IsFalse('help.txt'._IsWildcardMatch('*.pas'), '_IsWildcardMatch olmayan eşleşmeyi buldu');
end;

procedure THelperStringTestleri.SolSagAlmaTesti;
begin
  Assert.AreEqual('Mer', 'Merhaba'._Left(3), '_Left yanlış');
  Assert.AreEqual('aba', 'Merhaba'._Right(3), '_Right yanlış');
  Assert.AreEqual('Merhaba', 'Merhaba'._Left(100), '_Left sınırın dışına taşınca tüm stringi dönmeli');
end;

procedure THelperStringTestleri.OnceSonraArasiTesti;
begin
  Assert.AreEqual('a=1', 'a=1;b=2'._Before(';'), '_Before yanlış');
  Assert.AreEqual('b=2', 'a=1;b=2'._After(';'), '_After yanlış');
  Assert.AreEqual('42', '<v>42</v>'._Between('<v>', '</v>'), '_Between yanlış');
end;

procedure THelperStringTestleri.BoslukKirpilmisBolmeTesti;
var
  LParcalar: TArray<string>;
begin
  LParcalar := 'a, b , ,c'._SplitTrimmed(',');
  Assert.AreEqual(3, Length(LParcalar), '_SplitTrimmed boş elemanları elemedi');
  Assert.AreEqual('a', LParcalar[0], '_SplitTrimmed ilk eleman yanlış');
  Assert.AreEqual('b', LParcalar[1], '_SplitTrimmed ikinci eleman kırpılmamış');
  Assert.AreEqual('c', LParcalar[2], '_SplitTrimmed üçüncü eleman yanlış');
end;

procedure THelperStringTestleri.BirlestirmeTesti;
begin

  Assert.AreEqual('2026-07-04', string._Join('-', ['2026', '07', '04']), '_Join yanlış');
end;

procedure THelperStringTestleri.RawUtf8GidisDonusTesti;
var
  LOrijinal: string;
  LUtf8: RawUtf8;
begin
  LOrijinal := 'Türkçe karakterler: ığüşöç İĞÜŞÖÇ';
  LUtf8 := LOrijinal._ToUtf8;
  Assert.AreEqual(LOrijinal, string._FromUtf8(LUtf8), '_ToUtf8/_FromUtf8 gidiş-dönüşü Türkçe karakterleri bozdu');
end;

procedure THelperStringTestleri.DogalSiralamaBuyukSayiTesti(const AMetin1, AMetin2: string; const ABeklenenIsaret: Integer);
var
  LSonuc: Integer;
begin
  LSonuc := AMetin1._CompareNatural(AMetin2);
  case ABeklenenIsaret of
    1: Assert.IsTrue(LSonuc > 0, Format('_CompareNatural(%s,%s) pozitif olmalıydı (StrToInt64 overflow olmadan), %d döndü', [AMetin1, AMetin2, LSonuc]));
    0: Assert.AreEqual(0, LSonuc, Format('_CompareNatural(%s,%s) sıfır olmalıydı (baştaki sıfırlar yok sayılmalı)', [AMetin1, AMetin2]));
  end;
end;

procedure THelperStringTestleri.SnakeCaseAcronymRakamTesti(const AMetin, ABeklenen: string);
begin
  Assert.AreEqual(ABeklenen, AMetin._ToSnakeCase, '_ToSnakeCase acronym/rakam sınırını yakalamadı');
end;

procedure THelperStringTestleri.CamelCaseAcronymTesti(const AMetin, ABeklenen: string);
begin
  Assert.AreEqual(ABeklenen, AMetin._ToCamelCase, '_ToCamelCase acronym sınırını yakalamadı');
end;

procedure THelperStringTestleri.BaslikDurumuGenisletilmisSinirTesti(const AMetin, ABeklenen: string);
begin
  Assert.AreEqual(ABeklenen, AMetin._ToTitleCase, '_ToTitleCase boşluk-dışı sınırı yakalamadı');
end;

procedure THelperStringTestleri.TekrarMetinSinirDegerleriTesti;
begin
  Assert.AreEqual('', 'ab'._RepeatText(0), '_RepeatText sıfır tekrarda boş dönmeli');
  Assert.AreEqual('', 'ab'._RepeatText(-3), '_RepeatText negatif tekrarda boş dönmeli');
  Assert.AreEqual('', ''._RepeatText(5), '_RepeatText boş kaynakta boş dönmeli');
  Assert.AreEqual('ababab', 'ab'._RepeatText(3), '_RepeatText (Move tabanlı) normal tekrarda yanlış sonuç verdi');
end;

procedure THelperStringTestleri.MaskelemeNegatifClampTesti;
begin
  Assert.AreEqual('******', '123456'._Mask(-1, -1, '*'), '_Mask negatif parametrelerde 0''a clamp etmedi');
end;

procedure THelperStringTestleri.SagAlmaNegatifClampTesti;
begin
  Assert.AreEqual('', '123456'._Right(-1), '_Right negatif ACount''ta boş dönmeli');
  Assert.AreEqual('', '123456'._Right(0), '_Right sıfır ACount''ta boş dönmeli');
end;

{ THelperStringBenchmarkleri }

procedure THelperStringBenchmarkleri.TurkceCaseBenchmarkTesti;
var
  LSw: TStopwatch;
  i: Integer;
  LSonuc: string;
begin
  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations do
    LSonuc := CSample._ToUpperTR;
  LSw.Stop;
  Status(Format('_ToUpperTR            x%d : %d ms', [CIterations, LSw.ElapsedMilliseconds]));

  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations do
    LSonuc := CSample._ToLowerTR;
  LSw.Stop;
  Status(Format('_ToLowerTR            x%d : %d ms', [CIterations, LSw.ElapsedMilliseconds]));

  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations do
    LSonuc := string(CSample)._ToUpperTR; // RTL native karşılaştırma (Türkçe-duyarsız)
  LSw.Stop;
  Status(Format('RTL ToUpper (karşılaştırma) x%d : %d ms', [CIterations, LSw.ElapsedMilliseconds]));

  // Sağlık kontrolü: ölçüm sırasında sonuç hâlâ tutarlı mı (DUnitX assertion'sız testi hata sayıyor).
  Assert.IsTrue(LSonuc <> '', 'ToUpper boş sonuç üretti');
end;

procedure THelperStringBenchmarkleri.CaseDonusumleriBenchmarkTesti;
var
  LSw: TStopwatch;
  i: Integer;
  LSonuc: string;
begin
  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations do
    LSonuc := CSample._ToCamelCase;
  LSw.Stop;
  Status(Format('_ToCamelCase          x%d : %d ms', [CIterations, LSw.ElapsedMilliseconds]));

  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations do
    LSonuc := CSample._ToSnakeCase;
  LSw.Stop;
  Status(Format('_ToSnakeCase          x%d : %d ms', [CIterations, LSw.ElapsedMilliseconds]));

  Assert.IsTrue(LSonuc <> '', '_ToSnakeCase boş sonuç üretti');
end;

procedure THelperStringBenchmarkleri.DogalSiralamaBenchmarkTesti;
var
  LSw: TStopwatch;
  i: Integer;
  LFark: Integer;
begin
  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations do
    LFark := 'dosya2'._CompareNatural('dosya10');
  LSw.Stop;
  Status(Format('_CompareNatural       x%d : %d ms', [CIterations, LSw.ElapsedMilliseconds]));

  Assert.IsTrue(LFark < 0, '_CompareNatural doğal sıralamayı yanlış hesapladı');
end;

procedure THelperStringBenchmarkleri.LevenshteinBenchmarkTesti;
var
  LSw: TStopwatch;
  i: Integer;
  LMesafe: Integer;
begin
  // O(n*m) karmaşıklık — döngü sayısı düşük tutuldu.
  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations div 100 do
    LMesafe := 'kitten'._LevenshteinDistance('sitting');
  LSw.Stop;
  Status(Format('_LevenshteinDistance  x%d : %d ms', [CIterations div 100, LSw.ElapsedMilliseconds]));

  Assert.AreEqual(3, LMesafe, '_LevenshteinDistance klasik örnekte yanlış sonuç verdi');
end;

procedure THelperStringBenchmarkleri.CikarmaBenchmarkTesti;
var
  LSw: TStopwatch;
  i: Integer;
  LSonuc: string;
begin
  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations do
    LSonuc := CSample._Between('Merhaba ', ',');
  LSw.Stop;
  Status(Format('_Between              x%d : %d ms', [CIterations, LSw.ElapsedMilliseconds]));

  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations do
    LSonuc := CSample._Truncate(20);
  LSw.Stop;
  Status(Format('_Truncate             x%d : %d ms', [CIterations, LSw.ElapsedMilliseconds]));

  Assert.IsTrue(Length(LSonuc) <= 20, '_Truncate belirtilen uzunluğu aştı');
end;

procedure THelperStringBenchmarkleri.RawUtf8KoprusuBenchmarkTesti;
var
  LSw: TStopwatch;
  i: Integer;
  LUtf8: RawUtf8;
  LSonuc: string;
begin
  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations do
    LUtf8 := CSample._ToUtf8;
  LSw.Stop;
  Status(Format('_ToUtf8               x%d : %d ms', [CIterations, LSw.ElapsedMilliseconds]));

  LUtf8 := CSample._ToUtf8;
  LSw := TStopwatch.StartNew;
  for i := 1 to CIterations do
    LSonuc := string._FromUtf8(LUtf8);
  LSw.Stop;
  Status(Format('_FromUtf8             x%d : %d ms', [CIterations, LSw.ElapsedMilliseconds]));

  Assert.AreEqual(CSample, LSonuc, '_ToUtf8/_FromUtf8 gidiş-dönüşü metni bozdu');
end;

initialization
  TDUnitX.RegisterTestFixture(THelperStringTestleri);
  TDUnitX.RegisterTestFixture(THelperStringBenchmarkleri);

end.
