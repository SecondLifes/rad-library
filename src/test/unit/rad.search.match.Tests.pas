unit rad.search.match.Tests;

{ rad.search.match ve rad.search.core: katlama, baş harf, puan sırası, kullanım sayaçları.
  Web istemcisi aynı tabloyla test edilir; bir satır değişirse iki tarafta birlikte değişir. }

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TSearchMatchTests = class
  public
    [Test]
    [TestCase('BuyukI', 'ISIK,isik')]
    [TestCase('NoktaliI', 'İSTANBUL,istanbul')]
    [TestCase('NoktasizI', 'ışık,isik')]
    [TestCase('Tumu', 'ŞĞÜÖÇ şğüöç,sguoc sguoc')]
    [TestCase('Sapka', 'Hâl Îmâ Ûmit,hal ima umit')]
    [TestCase('Kisayol', '&Fatura,fatura')]
    procedure Fold(const AText, AExpected: string);
    [Test]
    [TestCase('Fatura', 'Yurt İçi Satış Faturası,yisf')]
    [TestCase('Parantez', 'Cari Hareketleri (Tahsilat / Ödeme),chto')]
    procedure Initials(const ACaption, AExpected: string);
    [Test]
    [TestCase('BaslikOnek', 'yurt,Yurt İçi Satış Faturası,,500')]
    [TestCase('BasHarf', 'yisf,Yurt İçi Satış Faturası,,400')]
    [TestCase('BasHarfOnek', 'yis,Yurt İçi Satış Faturası,,400')]
    [TestCase('KelimeBaslari', 'sat fat,Yurt İçi Satış Faturası,,300')]
    [TestCase('TurkceHarfsiz', 'satis,Yurt İçi Satış Faturası,,300')]
    [TestCase('Icerir', 'atış,Yurt İçi Satış Faturası,,200')]
    [TestCase('Yol', 'finans kasa,Kasa Kartı,Finans Yönetimi → Tanımlar,100')]
    [TestCase('Yok', 'stok,Yurt İçi Satış Faturası,,0')]
    [TestCase('TekHarfBasHarfDegil', 'i,Yurt İçi Satış Faturası,,300')]
    [TestCase('BosSorgu', ' ,Yurt İçi Satış Faturası,,0')]
    [TestCase('AtlamaliBasHarfYok', 'ysf,Yurt İçi Satış Faturası,,0')]
    procedure Score(const AQuery, ACaption, APath: string; AExpected: Integer);
    [Test]
    procedure Engine_SortsByScoreThenUsage;
    [Test]
    procedure Engine_FrequentSkipsUnresolved;
    [Test]
    procedure Usage_ItemsRoundTrip;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  rad.search.match,
  rad.search.core;

type
  /// <summary>Sabit listeden arayan sahte kaynak.</summary>
  TFakeProvider = class(TInterfacedObject, IRadSearchProvider)
  private
    FCaptions: TArray<string>;
    FExecuted: string;
  public
    constructor Create(const ACaptions: TArray<string>);
    function Key: string;
    function Caption: string;
    procedure Search(const AQuery: string; AMax: Integer; AHits: TList<TRadSearchHit>);
    function Find(const AId: string; out AHit: TRadSearchHit): Boolean;
    function Execute(const AId: string): Boolean;
    procedure Invalidate;
  end;

constructor TFakeProvider.Create(const ACaptions: TArray<string>);
begin
  inherited Create;
  FCaptions := ACaptions;
end;

function TFakeProvider.Key: string;
begin
  Result := 'fake';
end;

function TFakeProvider.Caption: string;
begin
  Result := 'Sahte';
end;

procedure TFakeProvider.Search(const AQuery: string; AMax: Integer; AHits: TList<TRadSearchHit>);
var
  LCaption: string;
  LHit: TRadSearchHit;
begin
  for LCaption in FCaptions do
  begin
    LHit := Default(TRadSearchHit);
    LHit.Provider := Key;
    LHit.Id := LCaption;
    LHit.Caption := LCaption;
    LHit.Score := TRadSearchMatch.Score(AQuery, TRadSearchMatch.Key(LCaption, ''));
    if LHit.Score > 0 then
      AHits.Add(LHit);
  end;
end;

function TFakeProvider.Find(const AId: string; out AHit: TRadSearchHit): Boolean;
begin
  Result := AId <> 'silindi';
  if Result then
  begin
    AHit := Default(TRadSearchHit);
    AHit.Provider := Key;
    AHit.Id := AId;
    AHit.Caption := AId;
  end;
end;

function TFakeProvider.Execute(const AId: string): Boolean;
begin
  FExecuted := AId;
  Result := True;
end;

procedure TFakeProvider.Invalidate;
begin
end;

{ TSearchMatchTests }

procedure TSearchMatchTests.Fold(const AText, AExpected: string);
begin
  Assert.AreEqual(AExpected, TRadSearchMatch.Fold(AText));
end;

procedure TSearchMatchTests.Initials(const ACaption, AExpected: string);
begin
  Assert.AreEqual(AExpected, TRadSearchMatch.Key(ACaption, '').Initials);
end;

procedure TSearchMatchTests.Score(const AQuery, ACaption, APath: string; AExpected: Integer);
begin
  Assert.AreEqual(AExpected,
    TRadSearchMatch.Score(TRadSearchMatch.Fold(AQuery), TRadSearchMatch.Key(ACaption, APath)));
end;

procedure TSearchMatchTests.Engine_SortsByScoreThenUsage;
var
  LEngine: TRadSearchEngine;
  LHits: TRadSearchHits;
begin
  LEngine := TRadSearchEngine.Create;
  try
    LEngine.Add(TFakeProvider.Create(['Kasa Hareket Raporu', 'Banka Kasa Virmanı', 'Kasa Kartı', 'Kasa Listesi']));
    LEngine.Usage.Add('fake|Kasa Listesi');
    LHits := LEngine.Search('KASA');
    Assert.AreEqual(4, Length(LHits));
    // Başlık öneki (500) kullanılan önce, sonra kısa olan; kelime başı (300) en sonda.
    Assert.AreEqual('Kasa Listesi', LHits[0].Caption);
    Assert.AreEqual('Kasa Kartı', LHits[1].Caption);
    Assert.AreEqual('Kasa Hareket Raporu', LHits[2].Caption);
    Assert.AreEqual('Banka Kasa Virmanı', LHits[3].Caption);
  finally
    LEngine.Free;
  end;
end;

procedure TSearchMatchTests.Engine_FrequentSkipsUnresolved;
var
  LEngine: TRadSearchEngine;
  LHits: TRadSearchHits;
begin
  LEngine := TRadSearchEngine.Create;
  try
    LEngine.Add(TFakeProvider.Create([]));
    LEngine.Usage.Add('fake|silindi');
    LEngine.Usage.Add('fake|silindi');
    LEngine.Usage.Add('fake|Cari');
    LEngine.Usage.Add('yok|Kasa');
    LHits := LEngine.Frequent(5);
    Assert.AreEqual(1, Length(LHits));
    Assert.AreEqual('Cari', LHits[0].Caption);
    Assert.AreEqual(1, LHits[0].UseCount);
    Assert.IsTrue(LEngine.Execute(LHits[0]));
    Assert.AreEqual(2, LEngine.Usage.Count('fake|Cari'));
    LEngine.CountOnExecute := False;
    LEngine.Execute(LHits[0]);
    Assert.AreEqual(2, LEngine.Usage.Count('fake|Cari'));
  finally
    LEngine.Free;
  end;
end;

procedure TSearchMatchTests.Usage_ItemsRoundTrip;
var
  LUsage, LCopy: TRadSearchUsage;
begin
  LUsage := TRadSearchUsage.Create;
  LCopy := TRadSearchUsage.Create;
  try
    LUsage.Add('a');
    LUsage.Add('b');
    LUsage.Add('b');
    LCopy.Assign(LUsage.Items);
    Assert.AreEqual(2, LCopy.Count('b'));
    Assert.AreEqual('b', LCopy.Top(1)[0]);
  finally
    LCopy.Free;
    LUsage.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSearchMatchTests);

end.
