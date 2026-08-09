unit rad.eventbus.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Rtti,
  mormot.core.variants,
  rad.eventbus;

type
  TDenemeOlayi = record
    Deger: Integer;
    Metin: string;
  end;

  TDigerOlay = record
    Bayrak: Boolean;
  end;

  [TestFixture]
  TChannelBusTestleri = class
  private
    function GorevBekle(AOlay: TEvent; AZamanAsimiMs: Integer): Boolean;
  public
    [Test]
    procedure SenkronYayinAboneyeHemenUlasir;

    [Test]
    [TestCase('Kanal Adi Buyuk Harf', 'SIPARIS.ISLEM')]
    [TestCase('Kanal Adi Bosluklu', ' siparis.islem ')]
    [TestCase('Kanal Adi Karisik Harf', 'Siparis.Islem')]
    procedure KanalAdiBuyukKucukHarfVeBoslukDuyarsiz(const AYayinKanali: string);

    [Test]
    procedure FarkliKanallarBirbirineKarismaz;

    [Test]
    procedure AyniKanaldaFarkliTipteAbonelikBirbirineKarismaz;

    [Test]
    procedure DinamikTValueDizisiIleYayinAboneyeUlasir;

    [Test]
    procedure JsonIDocDictIleYayinAboneyeUlasir;

    [Test]
    procedure DinamikVeJsonVeGenericAyniKanaldaKarismaz;

    [Test]
    procedure AsenkronYayinSonundaBaskaThreaddeUlasir;

    [Test]
    procedure AnaThreadtanMainSyncYayinKendiKendiniKilitlemez;

    [Test]
    procedure BaskaThreadtanMainSyncYayinAnaThreadePompalanarakUlasir;

    [Test]
    procedure MainAsyncYayinHemenCalismazSonraPompalaninceCalisir;

    [Test]
    procedure DispatchSirasindaUnsubscribeCakismaOlusturmaz;

    [Test]
    procedure WaitAndUnsubscribeDevamEdenIsiBekler;

    [Test]
    procedure AboneSayisiVeKanalSilmeCalisir;

    [Test]
    procedure KanallarVeToplamAboneSayisiDogruDoner;

    [Test]
    [Category('Hata Yonetimi')]
    procedure BirAboneninHatasiDigerAboneleriEngellemez;

    [Test]
    [Category('Hata Yonetimi')]
    procedure OnErrorAtanmamissaHataSessizceYutulur;

    [Test]
    [Category('Hata Yonetimi')]
    procedure OnErrorAtanmissaKanalVeVeriDogruBildirilir;

    [Test]
    [Category('Hata Yonetimi')]
    procedure OnErrorAsenkronAbonedeDeCalisir;

    [Test]
    [Category('Wildcard')]
    procedure WildcardAbonelikBirdenFazlaKanaliKarsilar;

    [Test]
    [Category('Wildcard')]
    procedure WildcardDesenUyusmayanKanaliTetiklemez;

    [Test]
    [Category('Wildcard')]
    procedure WildcardPatternsVeToplamSayiDogruDoner;

    [Test]
    [Category('Wildcard')]
    procedure WildcardYokkenDavranisDegismez;

    [Test]
    [Category('Geri Basinc')]
    procedure OpBlockPublisherHicVeriKaybetmez;

    [Test]
    [Category('Geri Basinc')]
    procedure OpGrowSinirsizKabulEderVeKaybetmez;

    [Test]
    [Category('Geri Basinc')]
    procedure OpDropOldestKuyrukDolunceVeriAtar;

    [Test]
    [Category('Interceptor')]
    procedure InterceptorOncesindeVeSonrasindaDogruSirayla;

    [Test]
    [Category('Interceptor')]
    procedure InterceptorHatasiDispatchiEngellemez;

    [Test]
    [Category('Debounce')]
    procedure DebounceArdisikOlaylardaSonDegerleBirKezCalisir;

    [Test]
    [Category('Debounce')]
    procedure DebounceSifirsaHerOlaydaCalisir;

    [Test]
    [Category('MainSync Timeout')]
    procedure MainSyncTimeoutSuresindeGeriDoner;

    [Test]
    [Category('MainSync Timeout')]
    procedure MainSyncTimeoutsuzEskiDavranisDegismez;

    [Test]
    [Category('Geri Basinc')]
    procedure OpBlockPublisherAnaThreaddenCagrilirsaDebugtaHataVerir;
  end;

implementation

function TChannelBusTestleri.GorevBekle(AOlay: TEvent; AZamanAsimiMs: Integer): Boolean;
var
  BaslangicTick: UInt64;
begin
  BaslangicTick := TThread.GetTickCount64;
  repeat
    if AOlay.WaitFor(5) = wrSignaled then Exit(True);
    CheckSynchronize(5);
  until TThread.GetTickCount64 - BaslangicTick >= UInt64(AZamanAsimiMs);
  Result := AOlay.WaitFor(0) = wrSignaled;
end;

procedure TChannelBusTestleri.SenkronYayinAboneyeHemenUlasir;
var
  Bus      : TChannelBus;
  Yakalanan: TDenemeOlayi;
  Cagrildi : Boolean;
  Olay     : TDenemeOlayi;
begin
  Bus := CreateChannelBus;
  try
    Cagrildi := False;
    Bus.Subscribe<TDenemeOlayi>('test.kanal', dmSync,
      procedure(const AEvent: TDenemeOlayi)
      begin
        Cagrildi := True;
        Yakalanan := AEvent;
      end);

    Olay.Deger := 99;
    Olay.Metin := 'merhaba';
    Bus.Publish<TDenemeOlayi>('test.kanal', Olay);

    Assert.IsTrue(Cagrildi, 'dmSync handler Publish dönmeden önce senkron çalışmalıydı');
    Assert.AreEqual(99, Yakalanan.Deger);
    Assert.AreEqual('merhaba', Yakalanan.Metin);
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.KanalAdiBuyukKucukHarfVeBoslukDuyarsiz(const AYayinKanali: string);
var
  Bus     : TChannelBus;
  Cagrildi: Boolean;
  Olay    : TDenemeOlayi;
begin
  Bus := CreateChannelBus;
  try
    Cagrildi := False;
    Bus.Subscribe<TDenemeOlayi>('siparis.islem', dmSync,
      procedure(const AEvent: TDenemeOlayi) begin Cagrildi := True; end);

    Olay.Deger := 1;
    Olay.Metin := 'x';
    Bus.Publish<TDenemeOlayi>(AYayinKanali, Olay);

    Assert.IsTrue(Cagrildi, Format('Kanal ''%s'' normalize edilip eşleşmeliydi', [AYayinKanali]));
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.FarkliKanallarBirbirineKarismaz;
var
  Bus       : TChannelBus;
  ACagrildi, BCagrildi: Boolean;
  Olay      : TDenemeOlayi;
begin
  Bus := CreateChannelBus;
  try
    ACagrildi := False;
    BCagrildi := False;
    Bus.Subscribe<TDenemeOlayi>('kanal.a', dmSync,
      procedure(const AEvent: TDenemeOlayi) begin ACagrildi := True; end);
    Bus.Subscribe<TDenemeOlayi>('kanal.b', dmSync,
      procedure(const AEvent: TDenemeOlayi) begin BCagrildi := True; end);

    Olay.Deger := 1;
    Bus.Publish<TDenemeOlayi>('kanal.a', Olay);

    Assert.IsTrue(ACagrildi, 'kanal.a aboneliği tetiklenmeliydi');
    Assert.IsFalse(BCagrildi, 'kanal.b aboneliği tetiklenmemeliydi');
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.AyniKanaldaFarkliTipteAbonelikBirbirineKarismaz;
var
  Bus         : TChannelBus;
  DenemeCagrildi, DigerCagrildi: Boolean;
  Olay        : TDenemeOlayi;
begin
  Bus := CreateChannelBus;
  try
    DenemeCagrildi := False;
    DigerCagrildi  := False;
    Bus.Subscribe<TDenemeOlayi>('ortak.kanal', dmSync,
      procedure(const AEvent: TDenemeOlayi) begin DenemeCagrildi := True; end);
    Bus.Subscribe<TDigerOlay>('ortak.kanal', dmSync,
      procedure(const AEvent: TDigerOlay) begin DigerCagrildi := True; end);

    Olay.Deger := 1;
    Bus.Publish<TDenemeOlayi>('ortak.kanal', Olay);

    Assert.IsTrue(DenemeCagrildi, 'TDenemeOlayi aboneliği tetiklenmeliydi');
    Assert.IsFalse(DigerCagrildi, 'TDigerOlay aboneliği (farklı tip) tetiklenmemeliydi');
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.DinamikTValueDizisiIleYayinAboneyeUlasir;
var
  Bus       : TChannelBus;
  Yakalanan : TArray<TValue>;
  Cagrildi  : Boolean;
begin
  Bus := CreateChannelBus;
  try
    Cagrildi := False;
    Bus.Subscribe('dinamik.kanal', dmSync,
      procedure(const AArgs: TArray<TValue>)
      begin
        Cagrildi := True;
        Yakalanan := AArgs;
      end);

    Bus.Publish('dinamik.kanal', ['siparis', 15, 99.78]);

    Assert.IsTrue(Cagrildi, 'TArray<TValue> tabanlı handler tetiklenmeliydi');
    Assert.AreEqual(3, Length(Yakalanan));
    Assert.AreEqual('siparis', Yakalanan[0].AsString);
    Assert.AreEqual(15, Yakalanan[1].AsInteger);
    Assert.AreEqual(99.78, Yakalanan[2].AsExtended, 0.0001);
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.JsonIDocDictIleYayinAboneyeUlasir;
var
  Bus      : TChannelBus;
  Json     : IDocDict;
  Cagrildi : Boolean;
  Yakalanan: IDocDict;
begin
  Bus := CreateChannelBus;
  try
    Cagrildi := False;
    Bus.Subscribe('json.kanal', dmSync,
      procedure(const AJson: IDocDict)
      begin
        Cagrildi := True;
        Yakalanan := AJson;
      end);

    Json := DocDict(mFastFloat);
    Json.I['SiparisNo'] := 1001;
    Json.F['Tutar'] := 249.90;

    Bus.Publish('json.kanal', Json);

    Assert.IsTrue(Cagrildi, 'IDocDict tabanlı handler tetiklenmeliydi');
    Assert.AreEqual(Int64(1001), Yakalanan.I['SiparisNo']);
    Assert.AreEqual(249.90, Yakalanan.F['Tutar'], 0.0001);
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.DinamikVeJsonVeGenericAyniKanaldaKarismaz;
var
  Bus                : TChannelBus;
  GenericCagrildi, DinamikCagrildi, JsonCagrildi: Boolean;
  Olay               : TDenemeOlayi;
begin
  // Aynı kanala üç farklı "tür" (T:record, TArray<TValue>, IDocDict) abone olabilir;
  // her Publish çağrısı yalnızca KENDİ türündeki aboneye ulaşmalı.
  Bus := CreateChannelBus;
  try
    GenericCagrildi := False;
    DinamikCagrildi := False;
    JsonCagrildi    := False;

    Bus.Subscribe<TDenemeOlayi>('karma.kanal', dmSync,
      procedure(const AEvent: TDenemeOlayi) begin GenericCagrildi := True; end);
    Bus.Subscribe('karma.kanal', dmSync,
      procedure(const AArgs: TArray<TValue>) begin DinamikCagrildi := True; end);
    Bus.Subscribe('karma.kanal', dmSync,
      procedure(const AJson: IDocDict) begin JsonCagrildi := True; end);

    Olay.Deger := 1;
    Bus.Publish<TDenemeOlayi>('karma.kanal', Olay);

    Assert.IsTrue(GenericCagrildi, 'Publish<T> yalnızca Subscribe<T> aboneliğine ulaşmalıydı');
    Assert.IsFalse(DinamikCagrildi, 'Publish<T>, TArray<TValue> aboneliğini tetiklememeliydi');
    Assert.IsFalse(JsonCagrildi, 'Publish<T>, IDocDict aboneliğini tetiklememeliydi');
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.AsenkronYayinSonundaBaskaThreaddeUlasir;
var
  Bus        : TChannelBus;
  BittiOlay  : TEvent;
  YakalananThreadID: TThreadID;
  AnaThreadID: TThreadID;
  Olay       : TDenemeOlayi;
begin
  Bus := CreateChannelBus;
  BittiOlay := TEvent.Create(nil, True, False, '');
  try
    AnaThreadID := TThread.CurrentThread.ThreadID;
    Bus.Subscribe<TDenemeOlayi>('async.kanal', dmAsync,
      procedure(const AEvent: TDenemeOlayi)
      begin
        YakalananThreadID := TThread.CurrentThread.ThreadID;
        BittiOlay.SetEvent;
      end);

    Olay.Deger := 42;
    Bus.Publish<TDenemeOlayi>('async.kanal', Olay);

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'dmAsync teslimatı zamanında gerçekleşmedi');
    Assert.AreNotEqual(AnaThreadID, YakalananThreadID, 'dmAsync handler ana thread dışında çalışmalıydı');
  finally
    BittiOlay.Free;
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.AnaThreadtanMainSyncYayinKendiKendiniKilitlemez;
var
  Bus     : TChannelBus;
  Cagrildi: Boolean;
  Olay    : TDenemeOlayi;
begin
  // Bu test, dmMainSync'in ana thread'den (test şu an ana thread'de çalışıyor) çağrıldığında
  // TThread.Synchronize kullanmayıp DOĞRUDAN çağırdığını doğrular. Eğer DispatchOne bu
  // özel durumu ele almasaydı, TThread.Synchronize kendi kendini bekleyip sonsuza kadar
  // bloklardı (self-deadlock) ve bu test asla dönmezdi.
  Bus := CreateChannelBus;
  try
    Cagrildi := False;
    Bus.Subscribe<TDenemeOlayi>('mainsync.kanal', dmMainSync,
      procedure(const AEvent: TDenemeOlayi) begin Cagrildi := True; end);

    Olay.Deger := 7;
    Bus.Publish<TDenemeOlayi>('mainsync.kanal', Olay);

    Assert.IsTrue(Cagrildi, 'dmMainSync, ana thread''den çağrıldığında hemen çalışmalıydı');
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.BaskaThreadtanMainSyncYayinAnaThreadePompalanarakUlasir;
var
  Bus        : TChannelBus;
  YakalananThreadID: TThreadID;
  AnaThreadID: TThreadID;
  BittiOlay  : TEvent;
begin
  Bus := CreateChannelBus;
  BittiOlay := TEvent.Create(nil, True, False, '');
  try
    AnaThreadID := TThread.CurrentThread.ThreadID;
    Bus.Subscribe<TDenemeOlayi>('mainsync.baska', dmMainSync,
      procedure(const AEvent: TDenemeOlayi)
      begin
        YakalananThreadID := TThread.CurrentThread.ThreadID;
        BittiOlay.SetEvent;
      end);

    TThread.CreateAnonymousThread(
      procedure
      var
        LOlay: TDenemeOlayi;
      begin
        LOlay.Deger := 1;
        Bus.Publish<TDenemeOlayi>('mainsync.baska', LOlay);
      end).Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'dmMainSync, ana thread''e pompalanarak ulaşmalıydı');
    Assert.AreEqual(AnaThreadID, YakalananThreadID, 'dmMainSync handler ana thread''de çalışmalıydı');
  finally
    BittiOlay.Free;
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.MainAsyncYayinHemenCalismazSonraPompalaninceCalisir;
var
  Bus     : TChannelBus;
  Cagrildi: Boolean;
  Olay    : TDenemeOlayi;
begin
  Bus := CreateChannelBus;
  try
    Cagrildi := False;
    Bus.Subscribe<TDenemeOlayi>('mainasync.kanal', dmMainAsync,
      procedure(const AEvent: TDenemeOlayi) begin Cagrildi := True; end);

    Olay.Deger := 1;
    Bus.Publish<TDenemeOlayi>('mainasync.kanal', Olay);

    Assert.IsFalse(Cagrildi, 'dmMainAsync, Publish dönmeden ÖNCE senkron çalışmamalıydı');

    CheckSynchronize(2000);
    Assert.IsTrue(Cagrildi, 'dmMainAsync, CheckSynchronize pompalandıktan sonra çalışmalıydı');
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.DispatchSirasindaUnsubscribeCakismaOlusturmaz;
var
  Bus       : TChannelBus;
  Sub       : IChannelSubscription;
  CagriSayaci: Integer;
  Olay      : TDenemeOlayi;
begin
  Bus := CreateChannelBus;
  try
    CagriSayaci := 0;
    Sub := Bus.Subscribe<TDenemeOlayi>('unsub.kanal', dmSync,
      procedure(const AEvent: TDenemeOlayi)
      begin
        Inc(CagriSayaci);
        Sub.Unsubscribe; // dispatch sırasında kendi kendini iptal ediyor
      end);

    Olay.Deger := 1;
    Bus.Publish<TDenemeOlayi>('unsub.kanal', Olay); // AV/exception oluşmamalı
    Bus.Publish<TDenemeOlayi>('unsub.kanal', Olay); // artık tetiklenmemeli

    Assert.AreEqual(1, CagriSayaci, 'Unsubscribe sonrası handler tekrar çağrılmamalıydı');
    Assert.IsFalse(Sub.IsActive);
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.WaitAndUnsubscribeDevamEdenIsiBekler;
var
  Bus       : TChannelBus;
  Sub       : IChannelSubscription;
  IsBittiBayragi: Integer; // 0/1, TInterlocked ile
  Olay      : TDenemeOlayi;
begin
  Bus := CreateChannelBus;
  try
    IsBittiBayragi := 0;
    Sub := Bus.Subscribe<TDenemeOlayi>('waitunsub.kanal', dmAsync,
      procedure(const AEvent: TDenemeOlayi)
      begin
        Sleep(200);
        TInterlocked.Exchange(IsBittiBayragi, 1);
      end);

    Olay.Deger := 1;
    Bus.Publish<TDenemeOlayi>('waitunsub.kanal', Olay);
    Sleep(20); // handler'ın dispatch kuyruğuna alınıp başlaması için kısa pay

    Sub.WaitAndUnsubscribe(5000);

    Assert.AreEqual(1, TInterlocked.CompareExchange(IsBittiBayragi, 0, 0),
      'WaitAndUnsubscribe, devam eden dispatch tamamlanmadan dönmemeliydi');
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.AboneSayisiVeKanalSilmeCalisir;
var
  Bus: TChannelBus;
  Sub1, Sub2: IChannelSubscription;
begin
  Bus := CreateChannelBus;
  try
    Assert.AreEqual(0, Bus.SubscriberCount('sayac.kanal'));

    Sub1 := Bus.Subscribe<TDenemeOlayi>('sayac.kanal', dmSync, procedure(const AEvent: TDenemeOlayi) begin end);
    Sub2 := Bus.Subscribe<TDenemeOlayi>('sayac.kanal', dmSync, procedure(const AEvent: TDenemeOlayi) begin end);
    Assert.AreEqual(2, Bus.SubscriberCount('sayac.kanal'));

    Sub1.Unsubscribe;
    Assert.AreEqual(1, Bus.SubscriberCount('sayac.kanal'),
      'SubscriberCount, Unsubscribe sonrası hemen (bir dispatch beklemeden) güncel olmalı');

    Bus.UnsubscribeChannel('sayac.kanal');
    Assert.AreEqual(0, Bus.SubscriberCount('sayac.kanal'));
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.KanallarVeToplamAboneSayisiDogruDoner;
var
  Bus     : TChannelBus;
  Kanallar: TArray<string>;
begin
  Bus := CreateChannelBus;
  try
    Bus.Subscribe<TDenemeOlayi>('kanal.bir', dmSync, procedure(const AEvent: TDenemeOlayi) begin end);
    Bus.Subscribe<TDenemeOlayi>('kanal.bir', dmSync, procedure(const AEvent: TDenemeOlayi) begin end);
    Bus.Subscribe<TDenemeOlayi>('kanal.iki', dmSync, procedure(const AEvent: TDenemeOlayi) begin end);

    Kanallar := Bus.Channels;
    Assert.AreEqual(2, Length(Kanallar));
    Assert.AreEqual(3, Bus.TotalSubscriberCount);
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.BirAboneninHatasiDigerAboneleriEngellemez;
var
  Bus            : TChannelBus;
  IkinciCagrildi : Boolean;
begin
  // Regresyon: eskiden dmSync/dmMainSync'te bir abonenin exception'ı, aynı Publish
  // çağrısındaki DİĞER abonelerin çağrılmasını engelliyordu (for döngüsü kesiliyordu).
  Bus := CreateChannelBus;
  try
    IkinciCagrildi := False;
    Bus.Subscribe<TDenemeOlayi>('hatali.kanal', dmSync,
      procedure(const AEvent: TDenemeOlayi) begin raise Exception.Create('kasıtlı hata'); end);
    Bus.Subscribe<TDenemeOlayi>('hatali.kanal', dmSync,
      procedure(const AEvent: TDenemeOlayi) begin IkinciCagrildi := True; end);

    var Olay: TDenemeOlayi;
    Olay.Deger := 1;
    Bus.Publish<TDenemeOlayi>('hatali.kanal', Olay); // exception dışarı sızmamalı

    Assert.IsTrue(IkinciCagrildi, 'İlk abone hata fırlatsa bile ikinci abone çağrılmalıydı (izolasyon)');
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.OnErrorAtanmamissaHataSessizceYutulur;
var
  Bus: TChannelBus;
begin
  Bus := CreateChannelBus;
  try
    Bus.Subscribe<TDenemeOlayi>('sessiz.hata.kanal', dmSync,
      procedure(const AEvent: TDenemeOlayi) begin raise Exception.Create('kasıtlı hata'); end);

    var Olay: TDenemeOlayi;
    Olay.Deger := 1;
    // OnError atanmadı — Publish'in exception fırlatmadan dönmesi bekleniyor.
    Bus.Publish<TDenemeOlayi>('sessiz.hata.kanal', Olay);

    Assert.Pass('OnError atanmamışken Publish exception fırlatmadan tamamlandı');
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.OnErrorAtanmissaKanalVeVeriDogruBildirilir;
var
  Bus            : TChannelBus;
  YakalananKanal : string;
  YakalananHata  : string;
  YakalananDeger : Integer;
  OnErrorCagrildi: Boolean;
begin
  Bus := CreateChannelBus;
  try
    OnErrorCagrildi := False;
    Bus.OnError :=
      procedure(const AChannel: string; const AData: TValue; E: Exception)
      begin
        OnErrorCagrildi := True;
        YakalananKanal := AChannel;
        YakalananHata  := E.Message;
        YakalananDeger := AData.AsType<TDenemeOlayi>.Deger;
      end;

    Bus.Subscribe<TDenemeOlayi>('onerror.kanal', dmSync,
      procedure(const AEvent: TDenemeOlayi) begin raise Exception.Create('özel hata mesajı'); end);

    var Olay: TDenemeOlayi;
    Olay.Deger := 77;
    Bus.Publish<TDenemeOlayi>('onerror.kanal', Olay);

    Assert.IsTrue(OnErrorCagrildi, 'OnError tetiklenmeliydi');
    Assert.AreEqual('onerror.kanal', YakalananKanal);
    Assert.AreEqual('özel hata mesajı', YakalananHata);
    Assert.AreEqual(77, YakalananDeger, 'AData üzerinden orijinal olay verisine erişilebilmeliydi');
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.OnErrorAsenkronAbonedeDeCalisir;
var
  Bus       : TChannelBus;
  BittiOlay : TEvent;
  YakalananKanal: string;
begin
  Bus := CreateChannelBus;
  BittiOlay := TEvent.Create(nil, True, False, '');
  try
    Bus.OnError :=
      procedure(const AChannel: string; const AData: TValue; E: Exception)
      begin
        YakalananKanal := AChannel;
        BittiOlay.SetEvent;
      end;

    Bus.Subscribe<TDenemeOlayi>('onerror.async.kanal', dmAsync,
      procedure(const AEvent: TDenemeOlayi) begin raise Exception.Create('asenkron hata'); end);

    var Olay: TDenemeOlayi;
    Olay.Deger := 1;
    Bus.Publish<TDenemeOlayi>('onerror.async.kanal', Olay);

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'dmAsync''teki hata OnError''a zamanında bildirilmedi');
    Assert.AreEqual('onerror.async.kanal', YakalananKanal);
  finally
    BittiOlay.Free;
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.WildcardAbonelikBirdenFazlaKanaliKarsilar;
var
  Bus            : TChannelBus;
  YakalananKanallar: TArray<string>;
  Olay           : TDenemeOlayi;
begin
  Bus := CreateChannelBus;
  try
    Bus.Subscribe<TDenemeOlayi>('siparis.*', dmSync,
      procedure(const AEvent: TDenemeOlayi)
      begin
        SetLength(YakalananKanallar, Length(YakalananKanallar) + 1);
      end);

    Olay.Deger := 1;
    Bus.Publish<TDenemeOlayi>('siparis.tamamlandi', Olay);
    Bus.Publish<TDenemeOlayi>('siparis.iptal', Olay);

    Assert.AreEqual(2, Length(YakalananKanallar),
      'siparis.* deseni, siparis.tamamlandi VE siparis.iptal''i de karşılamalıydı');
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.WildcardDesenUyusmayanKanaliTetiklemez;
var
  Bus     : TChannelBus;
  Cagrildi: Boolean;
  Olay    : TDenemeOlayi;
begin
  Bus := CreateChannelBus;
  try
    Cagrildi := False;
    Bus.Subscribe<TDenemeOlayi>('siparis.*', dmSync,
      procedure(const AEvent: TDenemeOlayi) begin Cagrildi := True; end);

    Olay.Deger := 1;
    Bus.Publish<TDenemeOlayi>('baska.kanal', Olay);

    Assert.IsFalse(Cagrildi, 'siparis.* deseni baska.kanal''ı karşılamamalıydı');
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.WildcardPatternsVeToplamSayiDogruDoner;
var
  Bus     : TChannelBus;
begin
  Bus := CreateChannelBus;
  try
    Bus.Subscribe<TDenemeOlayi>('kanal.tam', dmSync, procedure(const AEvent: TDenemeOlayi) begin end);
    Bus.Subscribe<TDenemeOlayi>('siparis.*', dmSync, procedure(const AEvent: TDenemeOlayi) begin end);
    Bus.Subscribe<TDenemeOlayi>('log.*', dmSync, procedure(const AEvent: TDenemeOlayi) begin end);

    Assert.AreEqual(2, Length(Bus.WildcardPatterns));
    Assert.AreEqual(1, Length(Bus.Channels), 'Channels wildcard desenlerini içermemeli');
    Assert.AreEqual(3, Bus.TotalSubscriberCount, 'TotalSubscriberCount wildcard''ları da saymalı');
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.WildcardYokkenDavranisDegismez;
var
  Bus            : TChannelBus;
  ACagrildi, BCagrildi: Boolean;
  Olay           : TDenemeOlayi;
begin
  // Hiç wildcard abonelik yokken (FHasWildcards=False) GetMatchingSubscriptions'ın
  // tam-eşleşme-öncesi davranışı hiç bozmadığını doğrular.
  Bus := CreateChannelBus;
  try
    ACagrildi := False;
    BCagrildi := False;
    Bus.Subscribe<TDenemeOlayi>('kanal.a', dmSync, procedure(const AEvent: TDenemeOlayi) begin ACagrildi := True; end);
    Bus.Subscribe<TDenemeOlayi>('kanal.b', dmSync, procedure(const AEvent: TDenemeOlayi) begin BCagrildi := True; end);

    Olay.Deger := 1;
    Bus.Publish<TDenemeOlayi>('kanal.a', Olay);

    Assert.IsTrue(ACagrildi);
    Assert.IsFalse(BCagrildi);
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.OpBlockPublisherHicVeriKaybetmez;
const
  ToplamOlay = 200;
var
  Bus       : TChannelBus;
  IslenenSayac: Integer;
  BittiOlay : TEvent;
begin
  // opBlockPublisher tanım gereği veri ATAMAZ: kuyrukta yer yoksa Publish çağıran
  // thread'i (gerekirse) bekletir ama olayı asla düşürmez. Yayın BİLEREK bir arka plan
  // thread'inden yapılıyor — ana thread'den opBlockPublisher ile Publish çağırmak DEBUG
  // derlemede kasıtlı bir guard'ı tetikler (bkz. "opBlockPublisher + Ana Thread Riski").
  Bus := CreateChannelBus(opBlockPublisher, 4);
  IslenenSayac := 0;
  BittiOlay := TEvent.Create(nil, True, False, '');
  try
    Bus.Subscribe<TDenemeOlayi>('block.kanal', dmAsync,
      procedure(const AEvent: TDenemeOlayi)
      begin
        if TInterlocked.Increment(IslenenSayac) = ToplamOlay then
          BittiOlay.SetEvent;
      end);

    TThread.CreateAnonymousThread(
      procedure
      var
        j: Integer;
        LOlay: TDenemeOlayi;
      begin
        for j := 1 to ToplamOlay do
        begin
          LOlay.Deger := j;
          Bus.Publish<TDenemeOlayi>('block.kanal', LOlay);
        end;
      end).Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 10000), 'Tüm olaylar zamanında işlenmedi');
    Assert.AreEqual(ToplamOlay, IslenenSayac);
    Assert.AreEqual(0, Bus.DroppedCount, 'opBlockPublisher hiçbir olayı düşürmemeliydi');
  finally
    BittiOlay.Free;
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.OpGrowSinirsizKabulEderVeKaybetmez;
const
  ToplamOlay = 500;
var
  Bus       : TChannelBus;
  IslenenSayac: Integer;
  BittiOlay : TEvent;
  i         : Integer;
  Olay      : TDenemeOlayi;
begin
  Bus := CreateChannelBus(opGrow, 4);
  IslenenSayac := 0;
  BittiOlay := TEvent.Create(nil, True, False, '');
  try
    Bus.Subscribe<TDenemeOlayi>('grow.kanal', dmAsync,
      procedure(const AEvent: TDenemeOlayi)
      begin
        if TInterlocked.Increment(IslenenSayac) = ToplamOlay then
          BittiOlay.SetEvent;
      end);

    for i := 1 to ToplamOlay do
    begin
      Olay.Deger := i;
      Bus.Publish<TDenemeOlayi>('grow.kanal', Olay);
    end;

    Assert.IsTrue(GorevBekle(BittiOlay, 10000), 'Tüm olaylar zamanında işlenmedi');
    Assert.AreEqual(ToplamOlay, IslenenSayac);
    Assert.AreEqual(0, Bus.DroppedCount, 'opGrow hiçbir olayı düşürmemeliydi');
  finally
    BittiOlay.Free;
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.OpDropOldestKuyrukDolunceVeriAtar;
const
  ToplamOlay = 4000;
var
  Bus  : TChannelBus;
  i    : Integer;
  Olay : TDenemeOlayi;
begin
  // Not: Bu test doğası gereği yayıncı (publisher) thread'i ile arka plandaki pompa
  // thread'i arasında bir yarışa (race) dayanır — kuyruk derinliği 1 iken çok sayıda
  // olay sıkı bir döngüde art arda yayınlanır. Amaç kesin bir sayı değil, opDropOldest
  // politikasının en az bir olayı gerçekten atabildiğini göstermektir.
  Bus := CreateChannelBus(opDropOldest, 1);
  try
    Bus.Subscribe<TDenemeOlayi>('drop.kanal', dmAsync,
      procedure(const AEvent: TDenemeOlayi) begin end);

    for i := 1 to ToplamOlay do
    begin
      Olay.Deger := i;
      Bus.Publish<TDenemeOlayi>('drop.kanal', Olay);
    end;

    Assert.IsTrue(Bus.DroppedCount > 0,
      'opDropOldest, dolu kuyrukla karşılaşınca en az bir olayı atmalıydı');
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.InterceptorOncesindeVeSonrasindaDogruSirayla;
var
  Bus  : TChannelBus;
  Sira : string;
  Olay : TDenemeOlayi;
begin
  Bus := CreateChannelBus;
  try
    Sira := '';
    Bus.AddBeforePublish(procedure(const AChannel: string; const AData: TValue) begin Sira := Sira + 'B'; end);
    Bus.AddAfterPublish(procedure(const AChannel: string; const AData: TValue) begin Sira := Sira + 'A'; end);
    Bus.Subscribe<TDenemeOlayi>('interceptor.kanal', dmSync,
      procedure(const AEvent: TDenemeOlayi) begin Sira := Sira + 'H'; end);

    Olay.Deger := 1;
    Bus.Publish<TDenemeOlayi>('interceptor.kanal', Olay);

    Assert.AreEqual('BHA', Sira, 'Sıra Before -> Handler -> After olmalıydı');
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.InterceptorHatasiDispatchiEngellemez;
var
  Bus         : TChannelBus;
  HandlerCagrildi, AfterCagrildi: Boolean;
  Olay        : TDenemeOlayi;
begin
  Bus := CreateChannelBus;
  try
    HandlerCagrildi := False;
    AfterCagrildi := False;
    Bus.AddBeforePublish(procedure(const AChannel: string; const AData: TValue)
      begin raise Exception.Create('kasıtlı interceptor hatası'); end);
    Bus.AddAfterPublish(procedure(const AChannel: string; const AData: TValue) begin AfterCagrildi := True; end);
    Bus.Subscribe<TDenemeOlayi>('interceptor.hata.kanal', dmSync,
      procedure(const AEvent: TDenemeOlayi) begin HandlerCagrildi := True; end);

    Olay.Deger := 1;
    Bus.Publish<TDenemeOlayi>('interceptor.hata.kanal', Olay); // exception dışarı sızmamalı

    Assert.IsTrue(HandlerCagrildi, 'Before interceptor hatası, asıl handler''ı engellememeliydi');
    Assert.IsTrue(AfterCagrildi, 'Before interceptor hatası, After interceptor''ı engellememeliydi');
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.DebounceArdisikOlaylardaSonDegerleBirKezCalisir;
var
  Bus      : TChannelBus;
  BittiOlay: TEvent;
  CagriSayaci: Integer;
  SonDeger : Integer;
  i        : Integer;
  Olay     : TDenemeOlayi;
begin
  Bus := CreateChannelBus;
  BittiOlay := TEvent.Create(nil, True, False, '');
  try
    CagriSayaci := 0;
    Bus.Subscribe<TDenemeOlayi>('debounce.kanal', dmAsync,
      procedure(const AEvent: TDenemeOlayi)
      begin
        TInterlocked.Increment(CagriSayaci);
        SonDeger := AEvent.Deger;
        BittiOlay.SetEvent;
      end, INFINITE, 200); // ADebounceMs=200

    for i := 1 to 5 do
    begin
      Olay.Deger := i;
      Bus.Publish<TDenemeOlayi>('debounce.kanal', Olay);
      Sleep(30); // her biri 200ms'lik sessizlik penceresini biriktiremeyecek kadar hızlı
    end;

    Assert.AreEqual(0, CagriSayaci, 'Ardışık olaylar sürerken handler henüz çalışmamalıydı');
    Assert.IsTrue(GorevBekle(BittiOlay, 3000), 'Sessizlik sonunda handler çalışmadı');
    Sleep(300); // geç bir ikinci tetiklenme olursa yakalamak için ekstra bekleme
    Assert.AreEqual(1, CagriSayaci, 'Handler tam olarak BİR kez çalışmalıydı');
    Assert.AreEqual(5, SonDeger, 'Çalışan değer EN SON gönderilen olmalıydı');
  finally
    BittiOlay.Free;
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.DebounceSifirsaHerOlaydaCalisir;
var
  Bus  : TChannelBus;
  CagriSayaci: Integer;
  i    : Integer;
  Olay : TDenemeOlayi;
begin
  // ADebounceMs verilmezse (varsayılan 0) debounce devre dışıdır — her Publish handler'ı
  // tetiklemelidir (eski davranış, backward-compatible).
  Bus := CreateChannelBus;
  try
    CagriSayaci := 0;
    Bus.Subscribe<TDenemeOlayi>('nodebounce.kanal', dmSync,
      procedure(const AEvent: TDenemeOlayi) begin Inc(CagriSayaci); end);

    for i := 1 to 5 do
    begin
      Olay.Deger := i;
      Bus.Publish<TDenemeOlayi>('nodebounce.kanal', Olay);
    end;

    Assert.AreEqual(5, CagriSayaci, 'Debounce olmadan her Publish handler''ı tetiklemeliydi');
  finally
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.MainSyncTimeoutSuresindeGeriDoner;
var
  Bus       : TChannelBus;
  PublishBitti: TEvent;
  HandlerCagrildi: Boolean;
  BaslangicTick: UInt64;
  GecenMs   : UInt64;
begin
  Bus := CreateChannelBus;
  PublishBitti := TEvent.Create(nil, True, False, '');
  try
    HandlerCagrildi := False;
    Bus.Subscribe<TDenemeOlayi>('mainsync.timeout.kanal', dmMainSync,
      procedure(const AEvent: TDenemeOlayi) begin HandlerCagrildi := True; end,
      200); // AMainSyncTimeoutMs=200

    BaslangicTick := TThread.GetTickCount64;
    TThread.CreateAnonymousThread(
      procedure
      var
        LOlay: TDenemeOlayi;
      begin
        LOlay.Deger := 1;
        Bus.Publish<TDenemeOlayi>('mainsync.timeout.kanal', LOlay); // ana thread BİLEREK pompalanmıyor
        PublishBitti.SetEvent;
      end).Start;

    Assert.IsTrue(PublishBitti.WaitFor(3000) = wrSignaled, 'Publish zaman aşımı olmadan hiç dönmedi');
    GecenMs := TThread.GetTickCount64 - BaslangicTick;
    Assert.IsTrue(GecenMs < 1500, Format('Publish çok uzun sürdü (%d ms) — timeout çalışmamış olabilir', [GecenMs]));
    Assert.IsFalse(HandlerCagrildi, 'Bu noktada (CheckSynchronize çağrılmadan) handler henüz çalışmamalıydı');

    CheckSynchronize(2000); // ana thread artık "müsait" oluyor, kuyruklanmış iş kaybolmamıştı
    Assert.IsTrue(HandlerCagrildi, 'Zaman aşımı sonrası bile kuyruklanmış iş sonunda çalışmalıydı');
  finally
    PublishBitti.Free;
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.MainSyncTimeoutsuzEskiDavranisDegismez;
var
  Bus       : TChannelBus;
  BittiOlay : TEvent;
begin
  // AMainSyncTimeoutMs verilmezse (varsayılan INFINITE) eski davranış (TThread.Synchronize,
  // süresiz bekler) korunmalı — GorevBekle'nin kendisi CheckSynchronize'i pompaladığı için
  // burada iş kaybolmadan tamamlanmalı.
  Bus := CreateChannelBus;
  BittiOlay := TEvent.Create(nil, True, False, '');
  try
    Bus.Subscribe<TDenemeOlayi>('mainsync.notimeout.kanal', dmMainSync,
      procedure(const AEvent: TDenemeOlayi) begin BittiOlay.SetEvent; end,
      INFINITE); // AMainSyncTimeoutMs açıkça INFINITE

    TThread.CreateAnonymousThread(
      procedure
      var
        LOlay: TDenemeOlayi;
      begin
        LOlay.Deger := 1;
        Bus.Publish<TDenemeOlayi>('mainsync.notimeout.kanal', LOlay);
      end).Start;

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'INFINITE timeout ile eski davranış (iş tamamlanmalı) bozulmuş olabilir');
  finally
    BittiOlay.Free;
    Bus.Free;
  end;
end;

procedure TChannelBusTestleri.OpBlockPublisherAnaThreaddenCagrilirsaDebugtaHataVerir;
const
  ToplamOlay = 20000;
var
  Bus : TChannelBus;
  {$IFNDEF DEBUG}
  i   : Integer;
  Olay: TDenemeOlayi;
  {$ENDIF}
begin
  // DUnitX test thread'i ana thread'dir — bu yüzden BİLEREK burada (arka plan thread'ine
  // taşımadan) doğrudan Publish çağırıyoruz: DEBUG derlemede guard'ın gerçekten
  // tetiklendiğini kanıtlamanın tek yolu bu. RELEASE derlemede guard devre dışı
  // olduğundan aynı kod sessizce (yavaşça) tamamlanır.
  Bus := CreateChannelBus(opBlockPublisher, 1);
  try
    Bus.Subscribe<TDenemeOlayi>('debugguard.kanal', dmAsync,
      procedure(const AEvent: TDenemeOlayi) begin Sleep(10); end);

    {$IFDEF DEBUG}
    Assert.WillRaise(
      procedure
      var
        j: Integer;
        LOlay: TDenemeOlayi;
      begin
        for j := 1 to ToplamOlay do
        begin
          LOlay.Deger := j;
          Bus.Publish<TDenemeOlayi>('debugguard.kanal', LOlay);
        end;
      end, Exception, 'DEBUG derlemede ana thread''den opBlockPublisher ile Publish exception fırlatmalıydı');
    {$ELSE}
    for i := 1 to 100 do // RELEASE'te guard yok; sadece kısa bir burst'ün sorunsuz çalıştığını doğrula
    begin
      Olay.Deger := i;
      Bus.Publish<TDenemeOlayi>('debugguard.kanal', Olay);
    end;
    Assert.Pass('RELEASE derlemede guard devre dışı, exception olmadan tamamlandı');
    {$ENDIF}
  finally
    Bus.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TChannelBusTestleri);

end.
