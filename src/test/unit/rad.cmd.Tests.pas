unit rad.cmd.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Rtti,
  rad.cmd;

type
  [TestFixture]
  TCmdsTestleri = class
  private
    function GorevBekle(AOlay: TEvent; AZamanAsimiMs: Integer): Boolean;
  public
    [Test]
    procedure KomutKaydiVeSayisi;

    [Test]
    procedure CalistirVeGuvenliCalistir;

    [Test]
    [TestCase('Buyuk Kucuk Harf Duyarsizlik 1 - Kucuk Harf', 'getid')]
    [TestCase('Buyuk Kucuk Harf Duyarsizlik 2 - Buyuk Harf', 'GETID')]
    [TestCase('Buyuk Kucuk Harf Duyarsizlik 3 - Karisik Harf', 'GetId')]
    procedure AnahtarBuyukKucukHarfDuyarsiz(const ASorguIsmi: string);

    [Test]
    procedure KomutKaydiniSil;

    [Test]
    [Category('Asenkron')]
    procedure AsenkronCalistirBasariDurumu;

    [Test]
    [Category('Asenkron')]
    procedure AsenkronCalistirHataDurumu;

    [Test]
    [Category('Eşzamanlılık')]
    procedure EszamanliKayitCalistirSil;

    { 2026-07-09 incelemesi (1.md/2.md, rad.cmd.pas) sonrası eklenen testler }

    [Test]
    procedure IsimBaslangicBitisBosluklariTrimlenir;

    [Test]
    procedure BosIsimKaydiReddedilir;

    [Test]
    procedure NilFonksiyonKaydiReddedilir;

    [Test]
    [Category('Asenkron')]
    procedure ExecuteAsyncDisReferansBirakilincaNesneYasar;

    [Test]
    [Category('Asenkron')]
    procedure ExecuteAsyncHataMesajiBozulmadanUlasir;

    [Test]
    [Category('Asenkron')]
    procedure OnDoneKendiExceptionAtsaProgramCokmez;
  end;

implementation

function TCmdsTestleri.GorevBekle(AOlay: TEvent; AZamanAsimiMs: Integer): Boolean;
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

procedure TCmdsTestleri.KomutKaydiVeSayisi;
var
  Komutlar: ICmds;
begin
  Komutlar := CreateCmds;
  Assert.AreEqual(0, Komutlar.CommandCount);
  Assert.IsFalse(Komutlar.Exists('topla'));

  Komutlar.RegisterCommand('topla', function(Sender: TObject; const Args: TArray<TValue>): TValue
    begin Result := Args[0].AsInteger + Args[1].AsInteger; end);

  Assert.IsTrue(Komutlar.Exists('topla'));
  Assert.AreEqual(1, Komutlar.CommandCount);
end;

procedure TCmdsTestleri.CalistirVeGuvenliCalistir;
var
  Komutlar: ICmds;
  Sonuc   : TValue;
begin
  Komutlar := CreateCmds;
  Komutlar.RegisterCommand('carp', function(Sender: TObject; const Args: TArray<TValue>): TValue
    begin Result := Args[0].AsInteger * Args[1].AsInteger; end);

  Sonuc := Komutlar.Execute('carp', nil, [TValue.From<Integer>(3), TValue.From<Integer>(4)]);
  Assert.AreEqual(12, Sonuc.AsInteger);

  Assert.WillRaise(procedure begin Komutlar.Execute('yokBoyleKomut'); end, Exception);

  Assert.IsTrue(Komutlar.TryExecute('carp', nil, [TValue.From<Integer>(2), TValue.From<Integer>(5)], Sonuc));
  Assert.AreEqual(10, Sonuc.AsInteger);

  Assert.IsFalse(Komutlar.TryExecute('yokBoyleKomut', nil, [], Sonuc));
end;

procedure TCmdsTestleri.AnahtarBuyukKucukHarfDuyarsiz(const ASorguIsmi: string);
var
  Komutlar: ICmds;
begin
  // Regresyon: eskiden Name.ToLower (locale bağımlı) kullanılıyordu — Türkçe
  // locale'de 'I'.ToLower <> 'i' olabiliyordu ("Turkish I" sorunu). Artık
  // ToLowerInvariant kullanılıyor, bu yüzden büyük/küçük harf içeren isimler
  // her locale'de tutarlı eşleşmeli.
  Komutlar := CreateCmds;
  Komutlar.RegisterCommand('GetID', function(Sender: TObject; const Args: TArray<TValue>): TValue
    begin Result := 99; end);

  Assert.IsTrue(Komutlar.Exists(ASorguIsmi), Format('''%s'' bulunmalıydı', [ASorguIsmi]));
  Assert.AreEqual(99, Komutlar.Execute(ASorguIsmi).AsInteger);
end;

procedure TCmdsTestleri.KomutKaydiniSil;
var
  Komutlar: ICmds;
begin
  Komutlar := CreateCmds;
  Komutlar.RegisterCommand('sil', function(Sender: TObject; const Args: TArray<TValue>): TValue
    begin Result := 1; end);
  Assert.IsTrue(Komutlar.Exists('sil'));

  Komutlar.UnregisterCommand('sil');
  Assert.IsFalse(Komutlar.Exists('sil'));
  Assert.AreEqual(0, Komutlar.CommandCount);
end;

procedure TCmdsTestleri.AsenkronCalistirBasariDurumu;
var
  Komutlar : ICmds;
  BittiOlay: TEvent;
  Basarili : Boolean;
  SonucDeger: Integer;
begin
  Komutlar := CreateCmds;
  Komutlar.RegisterCommand('asenkron', function(Sender: TObject; const Args: TArray<TValue>): TValue
    begin
      Sleep(20);
      Result := 55;
    end);

  BittiOlay := TEvent.Create(nil, True, False, '');
  try
    Basarili   := False;
    SonucDeger := -1;
    Komutlar.ExecuteAsync('asenkron', nil, [],
      procedure(V: TValue) begin
        Basarili   := True;
        SonucDeger := V.AsInteger;
        BittiOlay.SetEvent;
      end,
      procedure(E: Exception) begin
        BittiOlay.SetEvent;
      end);

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'ExecuteAsync OnDone zamanında tetiklenmedi');
    Assert.IsTrue(Basarili);
    Assert.AreEqual(55, SonucDeger);
  finally
    BittiOlay.Free;
  end;
end;

procedure TCmdsTestleri.AsenkronCalistirHataDurumu;
var
  Komutlar : ICmds;
  BittiOlay: TEvent;
  HataYakalandi: Boolean;
begin
  Komutlar := CreateCmds;

  BittiOlay := TEvent.Create(nil, True, False, '');
  try
    HataYakalandi := False;
    Komutlar.ExecuteAsync('yokBoyleKomut', nil, [],
      procedure(V: TValue) begin BittiOlay.SetEvent; end,
      procedure(E: Exception) begin
        HataYakalandi := True;
        BittiOlay.SetEvent;
      end);

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'ExecuteAsync OnError zamanında tetiklenmedi');
    Assert.IsTrue(HataYakalandi, 'OnError tetiklenmedi');
  finally
    BittiOlay.Free;
  end;
end;

procedure KomutIsciBaslat(AKomutlar: ICmds; AThreadNo: Integer; AHatalar: PInteger; AOlay: TEvent);
begin
  TThread.CreateAnonymousThread(procedure begin
    try
      var LIsim := 'cmd' + IntToStr(AThreadNo);
      AKomutlar.RegisterCommand(LIsim, function(Sender: TObject; const Args: TArray<TValue>): TValue
        begin Result := AThreadNo; end);
      for var j := 1 to 100 do
      begin
        AKomutlar.Exists(LIsim);
        if AKomutlar.Exists(LIsim) then
          AKomutlar.Execute(LIsim);
      end;
      AKomutlar.UnregisterCommand(LIsim);
    except
      on E: Exception do
        TInterlocked.Increment(AHatalar^);
    end;
    AOlay.SetEvent;
  end).Start;
end;

procedure TCmdsTestleri.EszamanliKayitCalistirSil;
const
  ThreadSayisi = 6;
var
  Komutlar  : ICmds;
  BittiOlaylar: array[0 .. ThreadSayisi - 1] of TEvent;
  Hatalar   : Integer;
  i         : Integer;
begin
  Komutlar := CreateCmds;
  Hatalar  := 0;
  for i := 0 to ThreadSayisi - 1 do
    BittiOlaylar[i] := TEvent.Create(nil, True, False, '');
  try
    for i := 0 to ThreadSayisi - 1 do
      KomutIsciBaslat(Komutlar, i, @Hatalar, BittiOlaylar[i]);

    for i := 0 to ThreadSayisi - 1 do
      Assert.IsTrue(BittiOlaylar[i].WaitFor(20000) = wrSignaled, 'Thread zamanında bitmedi');

    Assert.AreEqual(0, Hatalar, 'Eşzamanlı erişimde exception/AV oluştu');
  finally
    for i := 0 to ThreadSayisi - 1 do
      BittiOlaylar[i].Free;
  end;
end;

procedure TCmdsTestleri.IsimBaslangicBitisBosluklariTrimlenir;
var
  Komutlar: ICmds;
begin
  Komutlar := CreateCmds;
  Komutlar.RegisterCommand('Kaydet', function(Sender: TObject; const Args: TArray<TValue>): TValue
    begin Result := 1; end);
  Assert.IsTrue(Komutlar.Exists(' kaydet '), 'Trim uygulanmadığı için boşluklu ad bulunamadı');
  Assert.AreEqual(1, Komutlar.Execute(' Kaydet ').AsInteger, 'Trim uygulanmadığı için boşluklu adla Execute başarısız');
end;

procedure TCmdsTestleri.BosIsimKaydiReddedilir;
var
  Komutlar: ICmds;
begin
  Komutlar := CreateCmds;
  Assert.WillRaise(procedure
    begin
      Komutlar.RegisterCommand('   ', function(Sender: TObject; const Args: TArray<TValue>): TValue
        begin Result := 1; end);
    end, EArgumentException, 'Boş/boşluk isimli komut kaydı EArgumentException fırlatmalı');
end;

procedure TCmdsTestleri.NilFonksiyonKaydiReddedilir;
var
  Komutlar: ICmds;
  LNilFunc: TCmd;
begin
  Komutlar := CreateCmds;
  LNilFunc := nil;
  Assert.WillRaise(procedure
    begin
      Komutlar.RegisterCommand('test', LNilFunc);
    end, EArgumentException, 'Nil fonksiyon kaydı EArgumentException fırlatmalı');
end;

procedure TCmdsTestleri.ExecuteAsyncDisReferansBirakilincaNesneYasar;
var
  Komutlar : ICmds;
  BittiOlay: TEvent;
  Basarili : Boolean;
  SonucDeger: Integer;
begin
  // Regresyon: ExecuteAsync artık Self'i ICmds interface'i üzerinden yakalayıp
  // (LKeepAlive) task bitene kadar hayatta tutuyor - dış referans hemen
  // bırakılsa bile AV oluşmamalı (2026-07-09 incelemesi #2).
  Komutlar := CreateCmds;
  Komutlar.RegisterCommand('omur', function(Sender: TObject; const Args: TArray<TValue>): TValue
    begin
      Sleep(100);
      Result := 77;
    end);

  BittiOlay := TEvent.Create(nil, True, False, '');
  try
    Basarili   := False;
    SonucDeger := -1;
    Komutlar.ExecuteAsync('omur', nil, [],
      procedure(V: TValue) begin
        Basarili   := True;
        SonucDeger := V.AsInteger;
        BittiOlay.SetEvent;
      end,
      procedure(E: Exception) begin
        BittiOlay.SetEvent;
      end);

    Komutlar := nil; // dış referans hemen bırakılıyor

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'ExecuteAsync nesne erken serbest kalınca zamanında tamamlanmadı');
    Assert.IsTrue(Basarili);
    Assert.AreEqual(77, SonucDeger);
  finally
    BittiOlay.Free;
  end;
end;

procedure TCmdsTestleri.ExecuteAsyncHataMesajiBozulmadanUlasir;
const
  CBeklenenMesaj = 'ozel-hata-mesaji-testi';
var
  Komutlar   : ICmds;
  BittiOlay  : TEvent;
  AlinanMesaj: string;
begin
  // Regresyon: AcquireExceptionObject olmadan E, ForceQueue callback'i
  // çalışmadan önce RTL tarafından Free edilebiliyordu (2026-07-09 incelemesi #1).
  Komutlar := CreateCmds;
  Komutlar.RegisterCommand('patlar', function(Sender: TObject; const Args: TArray<TValue>): TValue
    begin raise Exception.Create(CBeklenenMesaj); end);

  BittiOlay := TEvent.Create(nil, True, False, '');
  try
    AlinanMesaj := '';
    Komutlar.ExecuteAsync('patlar', nil, [],
      procedure(V: TValue) begin BittiOlay.SetEvent; end,
      procedure(E: Exception) begin
        AlinanMesaj := E.Message;
        BittiOlay.SetEvent;
      end);

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'ExecuteAsync OnError zamanında tetiklenmedi');
    Assert.AreEqual(CBeklenenMesaj, AlinanMesaj, 'E.Message use-after-free nedeniyle bozulmuş olabilir');
  finally
    BittiOlay.Free;
  end;
end;

procedure TCmdsTestleri.OnDoneKendiExceptionAtsaProgramCokmez;
var
  Komutlar     : ICmds;
  BittiOlay    : TEvent;
  OnDoneCalisti: Boolean;
begin
  // Regresyon: OnDone/OnError callback'inin KENDİSİ exception atarsa artık
  // sarmalanıp loglanıyor, sarmalanmamış exception yayılmıyor (2026-07-09
  // incelemesi #6).
  Komutlar := CreateCmds;
  Komutlar.RegisterCommand('basarili', function(Sender: TObject; const Args: TArray<TValue>): TValue
    begin Result := 1; end);

  BittiOlay := TEvent.Create(nil, True, False, '');
  try
    OnDoneCalisti := False;
    Komutlar.ExecuteAsync('basarili', nil, [],
      procedure(V: TValue)
      begin
        OnDoneCalisti := True;
        BittiOlay.SetEvent;
        raise Exception.Create('OnDone kasıtlı hata - programı çökertmemeli');
      end,
      nil);

    Assert.IsTrue(GorevBekle(BittiOlay, 5000), 'OnDone zamanında tetiklenmedi');
    CheckSynchronize(200); // OnDone'un kasıtlı exception'ını işleyip yutması için
    Assert.IsTrue(OnDoneCalisti, 'OnDone hiç çalışmadı');
  finally
    BittiOlay.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCmdsTestleri);

end.
