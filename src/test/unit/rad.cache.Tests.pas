unit rad.cache.Tests;

{ TValue geçişi (2026-07-22): TSmartParam kaldırıldığı için TSmartParamTestleri
  fixture'ı da kaldırıldı — davranış-eşdeğeri senaryolar cache seviyesinde
  TValueOnbellekTestleri fixture'ında yeniden kuruldu. TSmartCacheTestleri'nin
  hâlâ geçerli testleri korunmuş, yalnız event imzaları yeni
  TParamChangeEvent'e (TValue tabanlı) uyarlanmıştır. }

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.SyncObjs,
  System.Rtti,
  Winapi.Windows,
  rad.cache;

type
  {$M+}
  TCacheJsonClass = class
  private
    FName: string;
    FValue: Integer;
  published
    property Name: string read FName write FName;
    property Value: Integer read FValue write FValue;
  end;
  {$M-}

  {$RTTI EXPLICIT FIELDS([vcPublic])}
  TCacheJsonRecord = record
  public
    Name: string;
    Value: Integer;
  end;
  {$RTTI INHERIT METHODS([]) PROPERTIES([]) FIELDS([])}

  ISmartCacheTestArayuzu = interface
    ['{7E6C6C5A-9B3E-4B0A-9A3E-4C1E6F2D8A11}']
    function DegerAl: Integer;
  end;

  TSmartCacheTestArayuzuImpl = class(TInterfacedObject, ISmartCacheTestArayuzu)
  public
    function DegerAl: Integer;
  end;

  // Yönetilen değer (interface) sızıntısı regresyon testi için destructor'ı
  // sayan arayüz/sınıf (2026-07-09 incelemesinden devralındı).
  ISizintiTestArayuzu = interface
    ['{4C2E7A1D-3F9B-4A2C-8E7D-2A1B3C4D5E6F}']
    procedure Ping;
  end;

  TSizintiTestNesnesi = class(TInterfacedObject, ISizintiTestArayuzu)
  public
    class var YokEdilmeSayisi: Integer;
    destructor Destroy; override;
    procedure Ping;
  end;

  [TestFixture]
  TValueOnbellekTestleri = class
  public
    [Test]
    procedure TemelTiplerinGidisDonusu;

    [Test]
    procedure KatiTipSozlesmesi;

    [Test]
    procedure NesneSaklamaVeYanlisSinifIcinNil;

    [Test]
    procedure ArayuzSaklamaVeGetIntf;

    [Test]
    procedure UzerineYazmaEskiArayuzuSizdirmaz;

    [Test]
    procedure EskiDegerYoksaOlayaEmptyGelir;

    [Test]
    procedure FactoryGetOrAddYalnizBirKezUretir;

    [Test]
    procedure KeysAnlikGoruntuDoner;
  end;

  [TestFixture]
  TSmartCacheTestleri = class
  public
    [Test]
    procedure EkleVeOku;

    [Test]
    procedure SilmeIslemiDogruSonucDoner;

    [Test]
    procedure GenelOlayEkleIslemiIptalEdebilir;

    [Test]
    procedure GetOrAddSessizAddOrSetOlayTetikler;

    [Test]
    procedure TekHandlerKaldirma;

    [Test]
    procedure LoadJson_GecerliNesneyiKilitlenmedenYukler;

    [Test]
    procedure LoadJson_BozukGirdideMevcutVeriyiKorur;

    [Test]
    procedure FileLoad_AClearFirstFalse_MevcutVeriyiKorur;

    [Test]
    procedure FileSaveLoad_JsonGidisDonusu;

    [Test]
    procedure FileSave_SifreIstegiDuzMetinYazmaz;

    [Test]
    procedure FileSave_DesteklenmeyenDegerdeMevcutDosyayiKorur;

    [Test]
    procedure FileSave_ClassRecordVariant_MormotJsonKullanir;

    [Test]
    procedure FileSave_YamlMormotDonusumunuKullanir;

    [Test]
    procedure AutoSave_DegisikliktenSonraArkaPlandaKaydeder;

    [Test]
    procedure AutoSave_KapanistaBekleyenDegisikligiKaydeder;

    [Test]
    procedure AutoSave_DosyaGeciciKilitliykenYenidenDener;

    [Test]
    procedure AutoSave_ThreadSafeOlmayanCacheIcinReddedilir;

    [Test]
    procedure IkiCacheOrnegi_BirbirininDurumunuPaylasmaz;

    [Test]
    [Category('Eşzamanlılık')]
    procedure EszamanliErisimdeCokmeOlmaz;

    [Test]
    [Category('Eşzamanlılık')]
    procedure GenelOlayEszamanliDegistirmedeYarisOlmaz;
  end;

implementation

{ TSmartCacheTestArayuzuImpl }

function TSmartCacheTestArayuzuImpl.DegerAl: Integer;
begin
  Result := 42;
end;

{ TSizintiTestNesnesi }

destructor TSizintiTestNesnesi.Destroy;
begin
  Inc(YokEdilmeSayisi);
  inherited;
end;

procedure TSizintiTestNesnesi.Ping;
begin
end;

{ TValueOnbellekTestleri }

procedure TValueOnbellekTestleri.TemelTiplerinGidisDonusu;
var
  Cache: TSmartCache;
  OndalikVarsayilan: Double;
  TarihVarsayilan: TDateTime;
begin
  Cache := TSmartCache.Create;
  try
    Cache.AddOrSet('tam', 123);
    Assert.AreEqual(123, Cache.Get('tam', 0), 'Integer gidiş-dönüşü başarısız');

    Cache.AddOrSet('ondalik', TValue.From<Double>(3.14));
    OndalikVarsayilan := 0;
    Assert.IsTrue(Abs(Cache.Get('ondalik', OndalikVarsayilan) - 3.14) < 0.0001,
      'Double gidiş-dönüşü başarısız');

    Cache.AddOrSet('metin', 'Merhaba Dünya');
    Assert.AreEqual('Merhaba Dünya', Cache.Get('metin', ''), 'String gidiş-dönüşü başarısız');

    Cache.AddOrSet('bayrak', True);
    Assert.IsTrue(Cache.Get('bayrak', False), 'Boolean gidiş-dönüşü başarısız');

    var SimdikiZaman := Now;
    Cache.AddOrSet('tarih', SimdikiZaman); // Extended olarak saklanır; Get<TDateTime> float dönüşümüyle okur
    TarihVarsayilan := 0;
    Assert.IsTrue(Abs(Cache.Get('tarih', TarihVarsayilan) - SimdikiZaman) < 1 / (24 * 60 * 60),
      'DateTime gidiş-dönüşü başarısız');
  finally
    Cache.Free;
  end;
end;

procedure TValueOnbellekTestleri.KatiTipSozlesmesi;
var
  Cache: TSmartCache;
  Tam: Integer;
begin
  // TValue geçişinin bilinçli davranış değişikliği: Variant'ın hoşgörülü
  // dönüşümleri yok — string '42', Integer olarak OKUNMAZ; default döner.
  Cache := TSmartCache.Create;
  try
    Cache.AddOrSet('metinselSayi', '42');
    Assert.AreEqual(-1, Cache.Get('metinselSayi', -1),
      'Katı tip sözleşmesi: string kayıt Integer okunuşunda default dönmeliydi');
    Assert.IsFalse(Cache.TryGet<Integer>('metinselSayi', Tam),
      'TryGet<Integer> string kayıtta False dönmeliydi');
    Assert.AreEqual(0, Tam, 'TryGet başarısızken out parametre Default(T) olmalıydı');

    Cache.AddOrSet('gercekSayi', 42);
    Assert.IsTrue(Cache.TryGet<Integer>('gercekSayi', Tam), 'TryGet<Integer> gerçek Integer''da başarılı olmalıydı');
    Assert.AreEqual(42, Tam, 'TryGet doğru değeri vermedi');

    Assert.IsFalse(Cache.TryGet<Integer>('hicYok', Tam), 'Olmayan anahtar için TryGet False dönmeliydi');
  finally
    Cache.Free;
  end;
end;

procedure TValueOnbellekTestleri.NesneSaklamaVeYanlisSinifIcinNil;
var
  Cache: TSmartCache;
  Liste: TStringList;
begin
  // Eski AsObj<T> sözleşmesinin TValue karşılığı: doğru sınıf aynı referansı,
  // yanlış sınıf (nesne canlıyken) nil/default döndürür. Eski varInt64-adres
  // hilesinin aksine tip kontrolü TValue'nun kendi sınıf uyum kuralıyla yapılır.
  Cache := TSmartCache.Create;
  try
    Liste := TStringList.Create;
    try
      Liste.Add('Satır 1');
      Liste.Add('Satır 2');
      Cache.AddOrSet('liste', Liste); // TObject: sahiplenilmez (sözleşme değişmedi)

      var Bulunan := Cache.Get<TStringList>('liste', nil);
      Assert.IsTrue(Bulunan = Liste, 'Get<TStringList> orijinal nesne referansını döndürmedi');
      Assert.AreEqual(2, Bulunan.Count, 'Dönen nesnenin içeriği yanlış');

      Assert.IsTrue(Cache.Get<TStringStream>('liste', nil) = nil,
        'Yanlış sınıf istenince nil dönmeliydi (nesne canlıyken)');
    finally
      Liste.Free;
    end;

    Assert.IsTrue(Cache.Get<TStringList>('hicYok', nil) = nil,
      'Olmayan anahtar için nesne okuması nil dönmeliydi');
  finally
    Cache.Free;
  end;
end;

procedure TValueOnbellekTestleri.ArayuzSaklamaVeGetIntf;
var
  Cache: TSmartCache;
  Impl: ISmartCacheTestArayuzu;
  Bulunan: ISmartCacheTestArayuzu;
begin
  Cache := TSmartCache.Create;
  try
    Impl := TSmartCacheTestArayuzuImpl.Create;
    Cache.AddOrSet('arayuz', IInterface(Impl));

    Bulunan := Cache.GetIntf<ISmartCacheTestArayuzu>('arayuz');
    Assert.IsTrue(Assigned(Bulunan), 'GetIntf<T> arayüzü bulamadı');
    Assert.AreEqual(42, Bulunan.DegerAl, 'GetIntf<T> yanlış nesneye işaret ediyor');

    Assert.IsFalse(Assigned(Cache.GetIntf<ISizintiTestArayuzu>('arayuz')),
      'Desteklenmeyen arayüz GUID''i için nil dönmeliydi');
  finally
    Cache.Free;
  end;
end;

procedure TValueOnbellekTestleri.UzerineYazmaEskiArayuzuSizdirmaz;
var
  Cache: TSmartCache;
  Intf: ISizintiTestArayuzu;
begin
  // Regresyon (eski #1'in TValue karşılığı): interface taşıyan kayıt üzerine
  // başka tipte değer yazılınca eski referans bırakılmalı (TValue'nun yönetilen
  // yaşam döngüsü) — sayaç 1 olmalı, sızıntı olmamalı.
  Cache := TSmartCache.Create;
  try
    TSizintiTestNesnesi.YokEdilmeSayisi := 0;
    Intf := TSizintiTestNesnesi.Create;
    Cache.AddOrSet('k', IInterface(Intf));
    Intf := nil;
    Assert.AreEqual(0, TSizintiTestNesnesi.YokEdilmeSayisi, 'Cache''teki referans nesneyi canlı tutmalıydı');

    Cache.AddOrSet('k', 123); // üzerine yaz — eski interface referansı düşmeli
    Assert.AreEqual(1, TSizintiTestNesnesi.YokEdilmeSayisi, 'Üzerine yazma eski interface''i sızdırdı');
    Assert.AreEqual(123, Cache.Get('k', 0), 'Üzerine yazılan yeni değer okunamadı');
  finally
    Cache.Free;
  end;
end;

procedure TValueOnbellekTestleri.EskiDegerYoksaOlayaEmptyGelir;
var
  Cache: TSmartCache;
  IlkEklemedeEmptyGeldi: Boolean;
  IkinciDegisimdeEskiDeger: Integer;
begin
  Cache := TSmartCache.Create;
  try
    IlkEklemedeEmptyGeldi := False;
    IkinciDegisimdeEskiDeger := -1;

    Cache.OnGlobalChange := function(AKey: string; AOld, ANew: TValue): Boolean
      begin
        if AOld.IsEmpty then
          IlkEklemedeEmptyGeldi := True
        else
          IkinciDegisimdeEskiDeger := AOld.AsInteger;
        Result := True;
      end;

    Cache.AddOrSet('x', 10);
    Assert.IsTrue(IlkEklemedeEmptyGeldi, 'İlk eklemede AOld=TValue.Empty gelmeliydi');

    Cache.AddOrSet('x', 20);
    Assert.AreEqual(10, IkinciDegisimdeEskiDeger, 'İkinci değişimde AOld önceki değeri taşımalıydı');
  finally
    Cache.Free;
  end;
end;

procedure TValueOnbellekTestleri.FactoryGetOrAddYalnizBirKezUretir;
var
  Cache: TSmartCache;
  UretimSayisi: Integer;
  Deger: TValue;
begin
  Cache := TSmartCache.Create;
  try
    UretimSayisi := 0;

    Deger := Cache.GetOrAdd('tembel', function: TValue
      begin
        Inc(UretimSayisi);
        Result := 77;
      end);
    Assert.AreEqual(77, Deger.AsInteger, 'Factory''nin ürettiği değer dönmeliydi');
    Assert.AreEqual(1, UretimSayisi, 'Factory ilk çağrıda tam bir kez üretmeliydi');

    Deger := Cache.GetOrAdd('tembel', function: TValue
      begin
        Inc(UretimSayisi);
        Result := 99;
      end);
    Assert.AreEqual(77, Deger.AsInteger, 'İkinci çağrı mevcut değeri dönmeliydi');
    Assert.AreEqual(1, UretimSayisi, 'Anahtar varken factory çalışmamalıydı');
  finally
    Cache.Free;
  end;
end;

procedure TValueOnbellekTestleri.KeysAnlikGoruntuDoner;
var
  Cache: TSmartCache;
  Anahtarlar: TArray<string>;
begin
  Cache := TSmartCache.Create;
  try
    Cache.AddOrSet('a', 1);
    Cache.AddOrSet('b', 2);
    Cache.AddOrSet('c', 3);

    Anahtarlar := Cache.Keys;
    Assert.AreEqual<Integer>(3, Length(Anahtarlar), 'Keys üç anahtar dönmeliydi');

    // Anlık kopya: sonradan yapılan ekleme, alınmış diziyi etkilemez.
    Cache.AddOrSet('d', 4);
    Assert.AreEqual<Integer>(3, Length(Anahtarlar), 'Keys anlık görüntü olmalıydı (canlı görünüm değil)');
    Assert.AreEqual(4, Cache.Count, 'Cache''in kendisi 4 kayıt içermeliydi');
  finally
    Cache.Free;
  end;
end;

{ TSmartCacheTestleri }

procedure TSmartCacheTestleri.EkleVeOku;
var
  Cache: TSmartCache;
begin
  Cache := TSmartCache.Create;
  try
    Assert.IsTrue(Cache.AddOrSet('sayi', 10));
    Assert.AreEqual(10, Cache.Get('sayi', 0));

    Assert.IsTrue(Cache.AddOrSet('metin', 'abc'));
    Assert.AreEqual('abc', Cache.Get('metin', ''));

    Assert.IsFalse(Cache.ContainsKey('yok'), 'Var olmayan anahtar ContainsKey=True dönmemeliydi');
    Assert.AreEqual(99, Cache.Get('yok', 99), 'Var olmayan anahtar için varsayılan değer dönmeliydi');
  finally
    Cache.Free;
  end;
end;

procedure TSmartCacheTestleri.SilmeIslemiDogruSonucDoner;
var
  Cache: TSmartCache;
begin
  // Regresyon: Remove anahtar gerçekten bulunup silindiyse True,
  // bulunamadıysa False döner.
  Cache := TSmartCache.Create;
  try
    Cache.AddOrSet('k1', 1);
    Assert.IsTrue(Cache.Remove('k1'), 'Var olan anahtar silinirken True dönmeliydi');
    Assert.IsFalse(Cache.Remove('k1'), 'Zaten silinmiş anahtar tekrar silinirken False dönmeliydi');
    Assert.IsFalse(Cache.Remove('hicYokBu'), 'Hiç var olmamış anahtar için False dönmeliydi');
  finally
    Cache.Free;
  end;
end;

procedure TSmartCacheTestleri.GenelOlayEkleIslemiIptalEdebilir;
var
  Cache: TSmartCache;
begin
  Cache := TSmartCache.Create;
  try
    Cache.OnGlobalChange := function(AKey: string; AOld, ANew: TValue): Boolean
      begin
        Result := False; // her değişikliği reddet
      end;

    Assert.IsFalse(Cache.AddOrSet('x', 10), 'Event False dönünce AddOrSet False dönmeliydi');
    Assert.IsFalse(Cache.ContainsKey('x'), 'Event iptal ettiği halde değer eklenmiş');
  finally
    Cache.Free;
  end;
end;

procedure TSmartCacheTestleri.GetOrAddSessizAddOrSetOlayTetikler;
var
  Cache: TSmartCache;
  TetiklenmeSayisi: Integer;
begin
  Cache := TSmartCache.Create;
  try
    TetiklenmeSayisi := 0;
    Cache.OnGlobalChange := function(AKey: string; AOld, ANew: TValue): Boolean
      begin
        Inc(TetiklenmeSayisi);
        Result := True;
      end;

    Cache.GetOrAdd('yeniAnahtar', 42);
    Assert.AreEqual(0, TetiklenmeSayisi, 'GetOrAdd yeni kayıt eklerken event tetiklememeliydi');

    Cache.AddOrSet('yeniAnahtar', 99);
    Assert.AreEqual(1, TetiklenmeSayisi, 'AddOrSet değeri değiştirirken event tetiklemeliydi');
  finally
    Cache.Free;
  end;
end;

procedure TSmartCacheTestleri.TekHandlerKaldirma;
var
  Cache: TSmartCache;
  Tetik1, Tetik2: Integer;
  H1, H2: TParamChangeEvent;
begin
  Cache := TSmartCache.Create;
  try
    Tetik1 := 0;
    Tetik2 := 0;
    // Aynı closure referansı hem RegisterEvent'e hem UnregisterEvent'e verilmeli
    // (karşılaştırma referans eşitliğiyle yapılıyor).
    H1 := function(AKey: string; AOld, ANew: TValue): Boolean
      begin
        Inc(Tetik1);
        Result := True;
      end;
    H2 := function(AKey: string; AOld, ANew: TValue): Boolean
      begin
        Inc(Tetik2);
        Result := True;
      end;

    Cache.RegisterEvent('k', H1);
    Cache.RegisterEvent('k', H2);

    Cache.AddOrSet('k', 1);
    Assert.AreEqual(1, Tetik1, 'H1 ilk AddOrSet''ta tetiklenmeliydi');
    Assert.AreEqual(1, Tetik2, 'H2 ilk AddOrSet''ta tetiklenmeliydi');

    Assert.IsTrue(Cache.UnregisterEvent('k', H1), 'H1 kaldırılırken True dönmeliydi');
    Assert.IsFalse(Cache.UnregisterEvent('k', H1), 'Zaten kaldırılmış handler tekrar kaldırılırken False dönmeliydi');
    Assert.IsFalse(Cache.UnregisterEvent('baskaAnahtar', H2), 'Kayıtlı olmadığı anahtarda False dönmeliydi');

    Cache.AddOrSet('k', 2);
    Assert.AreEqual(1, Tetik1, 'H1 kaldırıldıktan sonra artık tetiklenmemeliydi');
    Assert.AreEqual(2, Tetik2, 'H2 hâlâ kayıtlı olduğu için tetiklenmeye devam etmeliydi');
  finally
    Cache.Free;
  end;
end;

function GeciciCacheDosyasi(const AUzanti: string): string;
begin
  Result := TPath.Combine(TPath.GetTempPath,
    ChangeFileExt(TPath.GetRandomFileName, AUzanti));
end;

procedure TSmartCacheTestleri.LoadJson_GecerliNesneyiKilitlenmedenYukler;
var
  Cache: TSmartCache;
begin
  Cache := TSmartCache.Create;
  try
    Assert.AreEqual(0, Cache.LoadJson('{"aile":{"baba":42},"aktif":true}'));
    Assert.AreEqual<Int64>(42, Cache.Get<Int64>('aile.baba', -1));
    Assert.IsTrue(Cache.Get('aktif', False));
  finally
    Cache.Free;
  end;
end;

procedure TSmartCacheTestleri.LoadJson_BozukGirdideMevcutVeriyiKorur;
var
  Cache: TSmartCache;
  HataOlustu: Boolean;
begin
  Cache := TSmartCache.Create;
  try
    Cache.AddOrSet('korunacak', 7);
    HataOlustu := False;
    try
      Cache.LoadJson('{bozuk json');
    except
      on ESmartCacheJson do
        HataOlustu := True;
    end;
    Assert.IsTrue(HataOlustu);
    Assert.AreEqual(7, Cache.Get('korunacak', -1));
  finally
    Cache.Free;
  end;
end;

procedure TSmartCacheTestleri.FileLoad_AClearFirstFalse_MevcutVeriyiKorur;
var
  Cache: TSmartCache;
  Dosya: string;
begin
  Dosya := GeciciCacheDosyasi('.json');
  TFile.WriteAllText(Dosya, '{"yeni":2}', TEncoding.UTF8);
  Cache := TSmartCache.Create;
  try
    Cache.AddOrSet('eski', 1);
    Assert.IsTrue(Cache.FileLoad(Dosya, False));
    Assert.AreEqual(1, Cache.Get('eski', -1));
    Assert.AreEqual<Int64>(2, Cache.Get<Int64>('yeni', -1));
  finally
    Cache.Free;
    if TFile.Exists(Dosya) then
      TFile.Delete(Dosya);
  end;
end;

procedure TSmartCacheTestleri.FileSaveLoad_JsonGidisDonusu;
var
  Kaynak: TSmartCache;
  Hedef: TSmartCache;
  Dosya: string;
begin
  Dosya := GeciciCacheDosyasi('.json');
  Kaynak := TSmartCache.Create;
  try
    Kaynak.AddOrSet('sayi', 42);
    Kaynak.AddOrSet('metin', 'Merhaba Dünya');
    Kaynak.AddOrSet('bayrak', True);
    Kaynak.FileSave(Dosya);

    Hedef := TSmartCache.Create;
    try
      Assert.IsTrue(Hedef.FileLoad(Dosya));
      Assert.AreEqual<Int64>(42, Hedef.Get<Int64>('sayi', -1));
      Assert.AreEqual('Merhaba Dünya', Hedef.Get('metin', ''));
      Assert.IsTrue(Hedef.Get('bayrak', False));
    finally
      Hedef.Free;
    end;
  finally
    Kaynak.Free;
    if TFile.Exists(Dosya) then
      TFile.Delete(Dosya);
  end;
end;

procedure TSmartCacheTestleri.FileSave_SifreIstegiDuzMetinYazmaz;
var
  Cache: TSmartCache;
  Dosya: string;
  HataOlustu: Boolean;
begin
  Dosya := GeciciCacheDosyasi('.json');
  Cache := TSmartCache.Create;
  try
    Cache.AddOrSet('gizli', 'deger');
    HataOlustu := False;
    try
      Cache.FileSave(Dosya, True);
    except
      on ESmartCacheJson do
        HataOlustu := True;
    end;
    Assert.IsTrue(HataOlustu);
    Assert.IsFalse(TFile.Exists(Dosya),
      'ACipher=True iken düz metin dosyası yazılmamalıydı');
  finally
    Cache.Free;
    if TFile.Exists(Dosya) then
      TFile.Delete(Dosya);
  end;
end;

procedure TSmartCacheTestleri.FileSave_DesteklenmeyenDegerdeMevcutDosyayiKorur;
const
  ONCEKI_ICERIK = 'önceki içerik';
var
  Cache: TSmartCache;
  Arayuz: IInterface;
  Dosya: string;
  HataOlustu: Boolean;
begin
  Dosya := GeciciCacheDosyasi('.json');
  TFile.WriteAllText(Dosya, ONCEKI_ICERIK, TEncoding.UTF8);
  Cache := TSmartCache.Create;
  try
    Arayuz := TInterfacedObject.Create;
    Cache.AddOrSet('arayuz', Arayuz);
    HataOlustu := False;
    try
      Cache.FileSave(Dosya);
    except
      on ESmartCacheJson do
        HataOlustu := True;
    end;
    Assert.IsTrue(HataOlustu);
    Assert.AreEqual(ONCEKI_ICERIK, TFile.ReadAllText(Dosya, TEncoding.UTF8));
  finally
    Cache.Free;
    if TFile.Exists(Dosya) then
      TFile.Delete(Dosya);
  end;
end;

procedure TSmartCacheTestleri.FileSave_ClassRecordVariant_MormotJsonKullanir;
var
  Cache: TSmartCache;
  Dosya: string;
  Icerik: string;
  Kayit: TCacheJsonRecord;
  Nesne: TCacheJsonClass;
  Varyant: Variant;
begin
  Dosya := GeciciCacheDosyasi('.json');
  Cache := TSmartCache.Create;
  try
    Nesne := TCacheJsonClass.Create;
    try
      Nesne.Name := 'sinif';
      Nesne.Value := 11;
      Kayit.Name := 'kayit';
      Kayit.Value := 22;
      Varyant := 'varyant';

      Cache.AddOrSet('class', Nesne);
      Cache.AddOrSet('record', TValue.From<TCacheJsonRecord>(Kayit));
      Cache.AddOrSet('variant', TValue.FromVariant(Varyant));
      Cache.FileSave(Dosya);

      Icerik := TFile.ReadAllText(Dosya, TEncoding.UTF8);
      Assert.Contains(Icerik, '"sinif"');
      Assert.Contains(Icerik, '"kayit"');
      Assert.Contains(Icerik, '"variant":"varyant"');
    finally
      Nesne.Free;
    end;
  finally
    Cache.Free;
    if TFile.Exists(Dosya) then
      TFile.Delete(Dosya);
  end;
end;

procedure TSmartCacheTestleri.FileSave_YamlMormotDonusumunuKullanir;
var
  Cache: TSmartCache;
  Dosya: string;
  Icerik: string;
begin
  Dosya := GeciciCacheDosyasi('.yaml');
  Cache := TSmartCache.Create;
  try
    Cache.AddOrSet('ad', 'RAD');
    Cache.AddOrSet('sayi', 42);
    Cache.FileSave(Dosya);
    Icerik := TFile.ReadAllText(Dosya, TEncoding.UTF8);
    Assert.IsFalse(Icerik.TrimLeft.StartsWith('{'),
      'YAML dosyası kanonik JSON yerine JsonToYaml çıktısı olmalıydı.');
    Cache.Clear;
    Assert.IsTrue(Cache.FileLoad(Dosya));
    Assert.AreEqual('RAD', Cache.Get('ad', ''));
  finally
    Cache.Free;
    if TFile.Exists(Dosya) then
      TFile.Delete(Dosya);
  end;
end;

procedure TSmartCacheTestleri.AutoSave_DegisikliktenSonraArkaPlandaKaydeder;
var
  Cache: TSmartCache;
  Dosya: string;
  SonTick: UInt64;
begin
  Dosya := GeciciCacheDosyasi('.json');
  if TFile.Exists(Dosya) then
    TFile.Delete(Dosya);
  Cache := TSmartCache.Create(True);
  try
    Cache.SaveFileName := Dosya;
    Cache.AutoSaveDelaySeconds := 5;
    Cache.AutoSave := True;
    Cache.AddOrSet('arkaPlan', 42);

    SonTick := GetTickCount64 + 8000;
    while (not TFile.Exists(Dosya)) and (GetTickCount64 < SonTick) do
      TThread.Sleep(25);

    Assert.IsTrue(TFile.Exists(Dosya));
    Assert.Contains(TFile.ReadAllText(Dosya, TEncoding.UTF8), '"arkaPlan":42');
  finally
    Cache.Free;
    if TFile.Exists(Dosya) then
      TFile.Delete(Dosya);
  end;
end;

procedure TSmartCacheTestleri.AutoSave_KapanistaBekleyenDegisikligiKaydeder;
var
  Cache: TSmartCache;
  Dosya: string;
begin
  Dosya := GeciciCacheDosyasi('.json');
  if TFile.Exists(Dosya) then
    TFile.Delete(Dosya);
  Cache := TSmartCache.Create(True);
  Cache.SaveFileName := Dosya;
  Cache.AutoSave := True;
  Cache.AddOrSet('kapanis', True);
  Cache.Free;
  try
    Assert.IsTrue(TFile.Exists(Dosya));
    Assert.Contains(TFile.ReadAllText(Dosya, TEncoding.UTF8), '"kapanis":true');
  finally
    if TFile.Exists(Dosya) then
      TFile.Delete(Dosya);
  end;
end;

procedure TSmartCacheTestleri.AutoSave_DosyaGeciciKilitliykenYenidenDener;
var
  Cache: TSmartCache;
  Dosya: string;
  Kilit: TFileStream;
  SonTick: UInt64;
begin
  Dosya := GeciciCacheDosyasi('.json');
  TFile.WriteAllText(Dosya, '{}', TEncoding.UTF8);
  Cache := TSmartCache.Create(True);
  try
    Cache.SaveFileName := Dosya;
    Cache.AutoSave := True;
    Kilit := TFileStream.Create(Dosya, fmOpenReadWrite or fmShareExclusive);
    try
      Cache.AddOrSet('kilitSonrasi', 7);
      TThread.Sleep(5500);
    finally
      Kilit.Free;
    end;

    SonTick := GetTickCount64 + 4000;
    while (not TFile.ReadAllText(Dosya, TEncoding.UTF8).Contains('kilitSonrasi')) and
          (GetTickCount64 < SonTick) do
      TThread.Sleep(25);
    Assert.Contains(TFile.ReadAllText(Dosya, TEncoding.UTF8), '"kilitSonrasi":7');
  finally
    Cache.Free;
    if TFile.Exists(Dosya) then
      TFile.Delete(Dosya);
  end;
end;

procedure TSmartCacheTestleri.AutoSave_ThreadSafeOlmayanCacheIcinReddedilir;
var
  Cache: TSmartCache;
  HataOlustu: Boolean;
begin
  Cache := TSmartCache.Create(False);
  try
    HataOlustu := False;
    try
      Cache.AutoSave := True;
    except
      on ESmartCacheAutoSave do
        HataOlustu := True;
    end;
    Assert.IsTrue(HataOlustu);
  finally
    Cache.Free;
  end;
end;

procedure TSmartCacheTestleri.IkiCacheOrnegi_BirbirininDurumunuPaylasmaz;
var
  Birinci: TSmartCache;
  Ikinci: TSmartCache;
begin
  Birinci := TSmartCache.Create;
  try
    Birinci.AddOrSet('birinci', 1);
    Ikinci := TSmartCache.Create;
    try
      Ikinci.AddOrSet('ikinci', 2);
      Assert.AreEqual(1, Birinci.Count);
      Assert.AreEqual(1, Ikinci.Count);
    finally
      Ikinci.Free;
    end;
    Assert.AreEqual(1, Birinci.Get('birinci', -1));
  finally
    Birinci.Free;
  end;
end;

procedure OnbellekYukIsciBaslat(ACache: TSmartCache; AThreadNo, AIslemSayisi: Integer;
  AHatalar: PInteger; AOlay: TEvent);
begin
  // Tüm değişkenler parametre — closure'ın döngü değişkenine güvenmiyoruz.
  TThread.CreateAnonymousThread(procedure begin
    try
      for var j := 1 to AIslemSayisi do
      begin
        var LAnahtar := 'key' + IntToStr(AThreadNo) + '_' + IntToStr(j mod 10);
        ACache.AddOrSet(LAnahtar, j);
        ACache.Get(LAnahtar, 0);
        ACache.ContainsKey(LAnahtar);
      end;
    except
      on E: Exception do
        TInterlocked.Increment(AHatalar^);
    end;
    AOlay.SetEvent;
  end).Start;
end;

procedure TSmartCacheTestleri.EszamanliErisimdeCokmeOlmaz;
const
  ThreadSayisi = 4;
  IslemSayisi  = 200;
var
  Cache: TSmartCache;
  BittiOlaylar: array[0 .. ThreadSayisi - 1] of TEvent;
  Hatalar: Integer;
  i: Integer;
begin
  // Her thread kendi anahtar alanında çalışır — kilitlerin thread-safety'sini
  // test ediyoruz.
  Cache   := TSmartCache.Create(True);
  Hatalar := 0;
  try
    for i := 0 to ThreadSayisi - 1 do
      BittiOlaylar[i] := TEvent.Create(nil, True, False, '');
    try
      for i := 0 to ThreadSayisi - 1 do
        OnbellekYukIsciBaslat(Cache, i, IslemSayisi, @Hatalar, BittiOlaylar[i]);

      for i := 0 to ThreadSayisi - 1 do
        Assert.IsTrue(BittiOlaylar[i].WaitFor(20000) = wrSignaled, 'Thread zamanında bitmedi');
    finally
      for i := 0 to ThreadSayisi - 1 do
        BittiOlaylar[i].Free;
    end;

    Assert.AreEqual(0, Hatalar, 'Eşzamanlı erişimde exception/AV oluştu');
  finally
    Cache.Free;
  end;
end;

procedure GenelOlayYazariBaslat(ACache: TSmartCache; ABitisTick: UInt64; AHatalar: PInteger; AOlay: TEvent);
begin
  TThread.CreateAnonymousThread(procedure begin
    try
      while GetTickCount64 < ABitisTick do
        ACache.OnGlobalChange := function(AKey: string; AOld, ANew: TValue): Boolean
          begin Result := True; end;
    except
      on E: Exception do
        TInterlocked.Increment(AHatalar^);
    end;
    AOlay.SetEvent;
  end).Start;
end;

procedure EkleVeAyarlaCekiciBaslat(ACache: TSmartCache; ABitisTick: UInt64; AHatalar: PInteger; AOlay: TEvent);
begin
  TThread.CreateAnonymousThread(procedure begin
    try
      var n := 0;
      while GetTickCount64 < ABitisTick do
      begin
        Inc(n);
        ACache.AddOrSet('gkey', n);
      end;
    except
      on E: Exception do
        TInterlocked.Increment(AHatalar^);
    end;
    AOlay.SetEvent;
  end).Start;
end;

procedure TSmartCacheTestleri.GenelOlayEszamanliDegistirmedeYarisOlmaz;
const
  YazarThreadSayisi = 2;
  SureMs            = 200;
var
  Cache: TSmartCache;
  BittiOlaylar: array[0 .. YazarThreadSayisi] of TEvent; // 0 = OnGlobalChange değiştiren, 1..N = AddOrSet çağıran
  Hatalar: Integer;
  BitisTick: UInt64;
  i: Integer;
begin
  // Regresyon: FireEvents FGlobalEvent'i kilit altında yerel değişkene kopyalar,
  // OnGlobalChange property'si kilitli getter/setter kullanır.
  Cache     := TSmartCache.Create(True);
  Hatalar   := 0;
  BitisTick := GetTickCount64 + SureMs;
  try
    for i := 0 to YazarThreadSayisi do
      BittiOlaylar[i] := TEvent.Create(nil, True, False, '');
    try
      GenelOlayYazariBaslat(Cache, BitisTick, @Hatalar, BittiOlaylar[0]);

      for i := 1 to YazarThreadSayisi do
        EkleVeAyarlaCekiciBaslat(Cache, BitisTick, @Hatalar, BittiOlaylar[i]);

      for i := 0 to YazarThreadSayisi do
        Assert.IsTrue(BittiOlaylar[i].WaitFor(20000) = wrSignaled, 'Thread zamanında bitmedi');
    finally
      for i := 0 to YazarThreadSayisi do
        BittiOlaylar[i].Free;
    end;

    Assert.AreEqual(0, Hatalar, 'OnGlobalChange eşzamanlı değiştirilirken exception/AV oluştu');
  finally
    Cache.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TValueOnbellekTestleri);
  TDUnitX.RegisterTestFixture(TSmartCacheTestleri);

end.
