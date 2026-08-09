unit rad.utils.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Rtti,
  rad.utils;

type
  // GenerateFluentCode'u sınamak için kullanılan basit test sınıfı. Kullanıcının
  // orijinal örneğiyle (TBilinmeyenClass/IBilinmeyenClass) aynı desende: basit property
  // (Adi), accessor'lı property (Yasi), event property (OnTikla), pass-through metod
  // (Calistir/DegerAl) ve overload (Coklu).
  TDenemeSinifi = class
  private
    FAdi: string;
    FOnTikla: TNotifyEvent;
    function GetYasi: Integer;
    procedure SetYasi(const Value: Integer);
  public
    property Adi: string read FAdi write FAdi;
    property Yasi: Integer read GetYasi write SetYasi;
    property OnTikla: TNotifyEvent read FOnTikla write FOnTikla;

    procedure Calistir(const aParam: string);
    function DegerAl(const arg: Integer): Integer;
    // Kullanıcının orijinal örneğindeki imzayla birebir aynı — TArray<TValue>/TValue
    // gibi generic bir parametre/dönüş tipinin RTTI'de nasıl adlandırıldığını (ve
    // üretilen kodun derlenip derlenmediğini) sınamak için.
    function DegerAlGenerik(const arg: TArray<TValue>): TValue;

    procedure Coklu(const aDeger: Integer); overload;
    procedure Coklu(const aDeger: string); overload;
  end;

  // İndeksli (array) property'yi sınamak için ayrı bir test sınıfı.
  TSalYaziciSinifi = class
  private
    function GetOge(Index: Integer): string;
    procedure SetOge(Index: Integer; const Value: string);
  public
    property Oge[Index: Integer]: string read GetOge write SetOge;
  end;

  [TestFixture]
  TGenerateFluentCodeTestleri = class
  public
    [Test]
    procedure NilClassVerilirseExceptionFirlatir;

    [Test]
    procedure InterfaceAdiTOnekiDusurulupIEklenerekUretilir;

    [Test]
    procedure ImplementasyonClassAdiFluentEkiyleUretilir;

    [Test]
    procedure BasitPropertyIcinSetVeGetFluentImzasiUretilir;

    [Test]
    procedure AccessorMetoduIleYazilmisPropertyDeUretilir;

    [Test]
    procedure EventPropertyIcinDeSetVeGetUretilir;

    [Test]
    procedure PublicMetodAyniImzaIlePassThroughUretilir;

    [Test]
    procedure GenerikArrayParametreliMetodDaUretilir;

    [Test]
    procedure AyniIsimliOverloadMetodlaraOverloadEklenir;

    [Test]
    procedure AsInstanceHerZamanUretilir;

    [Test]
    [Category('AutoFree')]
    procedure AutoFreeParametresiVeDestructorUretilir;

    [Test]
    [Category('Indeksli Property')]
    procedure IndeksliPropertyIcinIndexParametreliSetGetUretilir;
  end;

implementation

{ TDenemeSinifi }

function TDenemeSinifi.GetYasi: Integer;
begin
  Result := 0;
end;

procedure TDenemeSinifi.SetYasi(const Value: Integer);
begin
  // test amaçlı boş
end;

procedure TDenemeSinifi.Calistir(const aParam: string);
begin
  // test amaçlı boş
end;

function TDenemeSinifi.DegerAl(const arg: Integer): Integer;
begin
  Result := arg;
end;

function TDenemeSinifi.DegerAlGenerik(const arg: TArray<TValue>): TValue;
begin
  if Length(arg) > 0 then
    Result := arg[0]
  else
    Result := TValue.Empty;
end;

procedure TDenemeSinifi.Coklu(const aDeger: Integer);
begin
  // test amaçlı boş
end;

procedure TDenemeSinifi.Coklu(const aDeger: string);
begin
  // test amaçlı boş
end;

{ TSalYaziciSinifi }

function TSalYaziciSinifi.GetOge(Index: Integer): string;
begin
  Result := '';
end;

procedure TSalYaziciSinifi.SetOge(Index: Integer; const Value: string);
begin
  // test amaçlı boş
end;

{ TGenerateFluentCodeTestleri }

procedure TGenerateFluentCodeTestleri.NilClassVerilirseExceptionFirlatir;
begin
  Assert.WillRaise(
    procedure begin GenerateFluentCode(TClass(nil)); end,
    Exception,
    'AClass=nil için anlamlı bir exception bekleniyordu');
end;

procedure TGenerateFluentCodeTestleri.InterfaceAdiTOnekiDusurulupIEklenerekUretilir;
var
  Kod: string;
begin
  Kod := GenerateFluentCode(TDenemeSinifi);
  Assert.IsTrue(Kod.Contains('IDenemeSinifi = interface'),
    'Interface adı "T"siz + "I" önekiyle üretilmemiş: ' + Kod);
end;

procedure TGenerateFluentCodeTestleri.ImplementasyonClassAdiFluentEkiyleUretilir;
var
  Kod: string;
begin
  Kod := GenerateFluentCode(TDenemeSinifi);
  Assert.IsTrue(Kod.Contains('TDenemeSinifiFluent = class(TInterfacedObject, IDenemeSinifi)'),
    'İmplementasyon class adı ClassName+Fluent olarak üretilmemiş: ' + Kod);
end;

procedure TGenerateFluentCodeTestleri.BasitPropertyIcinSetVeGetFluentImzasiUretilir;
var
  Kod: string;
begin
  Kod := GenerateFluentCode(TDenemeSinifi);
  Assert.IsTrue(Kod.Contains('function SetAdi(const aAdi: string): IDenemeSinifi;'),
    'SetAdi fluent imzası beklenen şekilde üretilmemiş: ' + Kod);
  Assert.IsTrue(Kod.Contains('function GetAdi: string;'),
    'GetAdi imzası üretilmemiş: ' + Kod);
  Assert.IsTrue(Kod.Contains('FInstance.Adi := aAdi;'),
    'SetAdi gövdesi FInstance.Adi''ye yazmıyor: ' + Kod);
  Assert.IsTrue(Kod.Contains('Result := FInstance.Adi;'),
    'GetAdi gövdesi FInstance.Adi''den okumuyor: ' + Kod);
end;

procedure TGenerateFluentCodeTestleri.AccessorMetoduIleYazilmisPropertyDeUretilir;
var
  Kod: string;
begin
  // Yasi: private GetYasi/SetYasi accessor'ları ile yazılmış (Adi gibi doğrudan field'a
  // bağlı DEĞİL).
  Kod := GenerateFluentCode(TDenemeSinifi);
  Assert.IsTrue(Kod.Contains('function SetYasi(const aYasi: Integer): IDenemeSinifi;'),
    'Accessor metodlu (Yasi) property için Set üretilmemiş: ' + Kod);
  Assert.IsTrue(Kod.Contains('function GetYasi: Integer;'),
    'Accessor metodlu (Yasi) property için Get üretilmemiş: ' + Kod);
end;

procedure TGenerateFluentCodeTestleri.EventPropertyIcinDeSetVeGetUretilir;
var
  Kod: string;
begin
  Kod := GenerateFluentCode(TDenemeSinifi);
  Assert.IsTrue(Kod.Contains('function SetOnTikla(const aOnTikla: TNotifyEvent): IDenemeSinifi;'),
    'Event property (OnTikla) için Set üretilmemiş: ' + Kod);
  Assert.IsTrue(Kod.Contains('function GetOnTikla: TNotifyEvent;'),
    'Event property (OnTikla) için Get üretilmemiş: ' + Kod);
end;

procedure TGenerateFluentCodeTestleri.PublicMetodAyniImzaIlePassThroughUretilir;
var
  Kod: string;
begin
  Kod := GenerateFluentCode(TDenemeSinifi);
  Assert.IsTrue(Kod.Contains('procedure Calistir(const aParam: string);'),
    'Calistir pass-through imzası üretilmemiş: ' + Kod);
  Assert.IsTrue(Kod.Contains('FInstance.Calistir(aParam);'),
    'Calistir gövdesi FInstance''a yönlendirmiyor: ' + Kod);
  Assert.IsTrue(Kod.Contains('function DegerAl(const arg: Integer): Integer;'),
    'DegerAl pass-through imzası üretilmemiş: ' + Kod);
  Assert.IsTrue(Kod.Contains('Result := FInstance.DegerAl(arg);'),
    'DegerAl gövdesi FInstance''a yönlendirmiyor: ' + Kod);
end;

procedure TGenerateFluentCodeTestleri.GenerikArrayParametreliMetodDaUretilir;
var
  Kod: string;
begin
  // Kullanıcının orijinal DegerAl(arg:TArray<TValue>):Tvalue örneğiyle aynı desen —
  // RTTI'nin TArray<TValue>/TValue için ürettiği tip adının gerçekten DERLENEBİLİR
  // olup olmadığını (bu testin kendisinin derlenmiş/geçmiş olması) doğrular.
  Kod := GenerateFluentCode(TDenemeSinifi);
  Assert.IsTrue(Kod.Contains('DegerAlGenerik'),
    'DegerAlGenerik hiç üretilmemiş: ' + Kod);
  // RTTI, TArray<TValue> için TAM NİTELİKLİ adı üretiyor (System.Rtti.TValue) — bu hâlâ
  // geçerli/derlenebilir Pascal'dır, sadece kısaltılmamış.
  Assert.IsTrue(Kod.Contains('function DegerAlGenerik(const arg: TArray<System.Rtti.TValue>): TValue;'),
    'DegerAlGenerik imzası beklenen metinle üretilmemiş: ' + Kod);
  Assert.IsTrue(Kod.Contains('Result := FInstance.DegerAlGenerik(arg);'),
    'DegerAlGenerik gövdesi FInstance''a yönlendirmiyor: ' + Kod);
end;

procedure TGenerateFluentCodeTestleri.AyniIsimliOverloadMetodlaraOverloadEklenir;
var
  Kod: string;
  SayimIndex, Bulunan: Integer;
begin
  Kod := GenerateFluentCode(TDenemeSinifi);

  Bulunan := 0;
  SayimIndex := Kod.IndexOf('procedure Coklu(');
  while SayimIndex >= 0 do
  begin
    Inc(Bulunan);
    SayimIndex := Kod.IndexOf('procedure Coklu(', SayimIndex + 1);
  end;
  // Interface + impl class tanımında (gövdeler hariç, çünkü gövdede 'overload;' yazılmaz)
  // ikişer kez, yani en az 4 kez 'procedure Coklu(' geçmeli.
  Assert.IsTrue(Bulunan >= 4, Format('Coklu overload''ları beklenen sıklıkta üretilmemiş (%d bulundu): %s', [Bulunan, Kod]));
  Assert.IsTrue(Kod.Contains('procedure Coklu(const aDeger: Integer); overload;'),
    'Coklu(Integer) overload'' işaretiyle üretilmemiş: ' + Kod);
  Assert.IsTrue(Kod.Contains('procedure Coklu(const aDeger: string); overload;'),
    'Coklu(string) overload'' işaretiyle üretilmemiş: ' + Kod);
end;

procedure TGenerateFluentCodeTestleri.AsInstanceHerZamanUretilir;
var
  Kod: string;
begin
  Kod := GenerateFluentCode(TDenemeSinifi);
  Assert.IsTrue(Kod.Contains('function AsInstance: TDenemeSinifi;'),
    'AsInstance imzası üretilmemiş: ' + Kod);
  Assert.IsTrue(Kod.Contains('Result := FInstance;'),
    'AsInstance gövdesi FInstance''ı döndürmüyor: ' + Kod);
end;

procedure TGenerateFluentCodeTestleri.AutoFreeParametresiVeDestructorUretilir;
var
  Kod: string;
begin
  Kod := GenerateFluentCode(TDenemeSinifi);
  Assert.IsTrue(Kod.Contains('constructor Create(AInstance: TDenemeSinifi; AAutoFree: Boolean = False);'),
    'Constructor''a AAutoFree parametresi eklenmemiş: ' + Kod);
  Assert.IsTrue(Kod.Contains('destructor Destroy; override;'),
    'Destructor tanımı üretilmemiş: ' + Kod);
  Assert.IsTrue(Kod.Contains('if FAutoFree then') and Kod.Contains('FInstance.Free;'),
    'Destructor gövdesi AutoFree kontrolüyle FInstance.Free çağırmıyor: ' + Kod);
end;

procedure TGenerateFluentCodeTestleri.IndeksliPropertyIcinIndexParametreliSetGetUretilir;
var
  Kod: string;
begin
  Kod := GenerateFluentCode(TSalYaziciSinifi);
  Assert.IsTrue(Kod.Contains('function SetOge(Index: Integer; const aValue: string): ISalYaziciSinifi;'),
    'İndeksli property (Oge) için index parametreli Set üretilmemiş: ' + Kod);
  Assert.IsTrue(Kod.Contains('function GetOge(Index: Integer): string;'),
    'İndeksli property (Oge) için index parametreli Get üretilmemiş: ' + Kod);
  Assert.IsTrue(Kod.Contains('FInstance.Oge[Index] := aValue;'),
    'SetOge gövdesi FInstance.Oge[Index]''e yazmıyor: ' + Kod);
  Assert.IsTrue(Kod.Contains('Result := FInstance.Oge[Index];'),
    'GetOge gövdesi FInstance.Oge[Index]''den okumuyor: ' + Kod);
end;

initialization
  TDUnitX.RegisterTestFixture(TGenerateFluentCodeTestleri);

end.
