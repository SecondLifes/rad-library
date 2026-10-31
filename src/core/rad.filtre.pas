unit rad.filtre;

{ Liste ekranları için GÖRSELSİZ filtre modeli ve parametreli WHERE üretici.

  Neden ayrı bir birim: filtre mantığı (hangi alan, hangi işleç, SQL'e nasıl
  çevrilir) arayüzden bağımsızdır; DevExpress, TMS ya da başka bir arayüz aynı
  modele yazabilir. Bu birim ne VCL ne de UniDAC'a bağlıdır.

  GÜVENLİK KURALI: Değerler ASLA SQL metnine gömülmez; her değer adlandırılmış
  bir parametredir (:f1, :f2 ...). SQL'e giren tek şey TFiltreAlan.Sql'dir ve
  onu geliştirici koddan verir (kullanıcı girdisi değildir). }

interface

uses
  System.SysUtils, System.Classes, System.Variants, System.Generics.Collections;

type
  TFiltreTur = (
    ftMetin,      // içerir / ile başlar
    ftSayi,       // en az - en çok
    ftTarih,      // başlangıç - bitiş (gün dahil)
    ftMantiksal,  // Hepsi / Evet / Hayır
    ftSecim       // sabit seçenek listesi, eşittir
  );

  TFiltreMetinIslemi = (fmIcerir, fmIleBaslar, fmEsit);

  TFiltreSecenek = record
    Deger: Variant;
    Baslik: string;
    class function Yeni(const ADeger: Variant; const ABaslik: string): TFiltreSecenek; static;
  end;

  /// <summary>Filtrelenebilir tek bir alan. Arayüz bu tanımdan editör üretir.</summary>
  TFiltreAlan = class
  strict private
    FAd: string;
    FBaslik: string;
    FSql: string;
    FTur: TFiltreTur;
    FMetinIslemi: TFiltreMetinIslemi;
    FEvetBaslik: string;
    FHayirBaslik: string;
    FSecenekler: TArray<TFiltreSecenek>;
  public
    constructor Create(const AAd, ABaslik, ASql: string; ATur: TFiltreTur);
    /// <summary>Alanın kod içindeki benzersiz adı (kaydetme/yükleme anahtarı).</summary>
    property Ad: string read FAd;
    property Baslik: string read FBaslik;
    /// <summary>WHERE içinde kullanılacak SQL ifadesi (örn. "k.aktif_mi"). Koddan gelir, kullanıcıdan değil.</summary>
    property Sql: string read FSql;
    property Tur: TFiltreTur read FTur;
    property MetinIslemi: TFiltreMetinIslemi read FMetinIslemi write FMetinIslemi;
    property EvetBaslik: string read FEvetBaslik write FEvetBaslik;
    property HayirBaslik: string read FHayirBaslik write FHayirBaslik;
    property Secenekler: TArray<TFiltreSecenek> read FSecenekler write FSecenekler;
  end;

  /// <summary>Bir alanın kullanıcı tarafından girilmiş değeri. Boş (Null) = o alan filtrede değil.</summary>
  TFiltreDeger = record
    Deger1: Variant;
    Deger2: Variant;
    function Bos: Boolean;
    class function Yeni: TFiltreDeger; static;
  end;

  /// <summary>WHERE parçası ve parametre değerleri. Parametre adları "f1", "f2" ...</summary>
  TFiltreSonuc = record
    Where: string;
    Adlar: TArray<string>;
    Degerler: TArray<Variant>;
  end;

  TFiltreModel = class
  strict private
    FAlanlar: TObjectList<TFiltreAlan>;
    FDegerler: TDictionary<string, TFiltreDeger>;
    FAramaSql: TArray<string>;
    FAramaMetni: string;
    function Kosul(AAlan: TFiltreAlan; const ADeger: TFiltreDeger; var ASayac: Integer;
      var ASonuc: TFiltreSonuc): string;
    class procedure Ekle(var ASonuc: TFiltreSonuc; const AAd: string; const ADeger: Variant); static;
    class function LikeKacis(const AMetin: string): string; static;
  public
    constructor Create;
    destructor Destroy; override;

    function AlanEkle(const AAd, ABaslik, ASql: string; ATur: TFiltreTur): TFiltreAlan;
    function AlanBul(const AAd: string): TFiltreAlan;

    /// <summary>Alana değer yazar. İki değer de Null ise alan filtreden çıkar.</summary>
    procedure DegerYaz(const AAd: string; const ADeger1: Variant; const ADeger2: Variant);
    function DegerOku(const AAd: string): TFiltreDeger;
    procedure Temizle;
    /// <summary>Kaç alanda (arama kutusu hariç) koşul var.</summary>
    function KosulSayisi: Integer;

    /// <summary>Hızlı arama kutusunun aranacağı SQL ifadeleri (OR ile birleşir, içerir mantığı).</summary>
    procedure AramaAlanlari(const ASqlIfadeleri: array of string);
    property AramaMetni: string read FAramaMetni write FAramaMetni;

    /// <summary>Tüm koşulları VE ile birleştirip parametreli WHERE gövdesi üretir (başına "WHERE" yazmaz).</summary>
    function Olustur: TFiltreSonuc;

    property Alanlar: TObjectList<TFiltreAlan> read FAlanlar;
  end;

implementation

{ TFiltreSecenek }

class function TFiltreSecenek.Yeni(const ADeger: Variant; const ABaslik: string): TFiltreSecenek;
begin
  Result.Deger := ADeger;
  Result.Baslik := ABaslik;
end;

{ TFiltreAlan }

constructor TFiltreAlan.Create(const AAd, ABaslik, ASql: string; ATur: TFiltreTur);
begin
  inherited Create;
  FAd := AAd;
  FBaslik := ABaslik;
  FSql := ASql;
  FTur := ATur;
  FMetinIslemi := fmIcerir;
  FEvetBaslik := 'Evet';
  FHayirBaslik := 'Hayır';
end;

{ TFiltreDeger }

class function TFiltreDeger.Yeni: TFiltreDeger;
begin
  Result.Deger1 := Null;
  Result.Deger2 := Null;
end;

function TFiltreDeger.Bos: Boolean;
begin
  Result := VarIsNull(Deger1) and VarIsNull(Deger2);
end;

{ TFiltreModel }

constructor TFiltreModel.Create;
begin
  inherited Create;
  FAlanlar := TObjectList<TFiltreAlan>.Create(True);
  FDegerler := TDictionary<string, TFiltreDeger>.Create;
end;

destructor TFiltreModel.Destroy;
begin
  FDegerler.Free;
  FAlanlar.Free;
  inherited;
end;

function TFiltreModel.AlanEkle(const AAd, ABaslik, ASql: string; ATur: TFiltreTur): TFiltreAlan;
begin
  Result := TFiltreAlan.Create(AAd, ABaslik, ASql, ATur);
  FAlanlar.Add(Result);
end;

function TFiltreModel.AlanBul(const AAd: string): TFiltreAlan;
var
  LAlan: TFiltreAlan;
begin
  for LAlan in FAlanlar do
    if SameText(LAlan.Ad, AAd) then
      Exit(LAlan);
  Result := nil;
end;

procedure TFiltreModel.DegerYaz(const AAd: string; const ADeger1, ADeger2: Variant);
var
  LDeger: TFiltreDeger;
begin
  LDeger.Deger1 := ADeger1;
  LDeger.Deger2 := ADeger2;
  if LDeger.Bos then
    FDegerler.Remove(LowerCase(AAd))
  else
    FDegerler.AddOrSetValue(LowerCase(AAd), LDeger);
end;

function TFiltreModel.DegerOku(const AAd: string): TFiltreDeger;
begin
  if not FDegerler.TryGetValue(LowerCase(AAd), Result) then
    Result := TFiltreDeger.Yeni;
end;

procedure TFiltreModel.Temizle;
begin
  FDegerler.Clear;
  FAramaMetni := '';
end;

function TFiltreModel.KosulSayisi: Integer;
begin
  Result := FDegerler.Count;
end;

procedure TFiltreModel.AramaAlanlari(const ASqlIfadeleri: array of string);
var
  i: Integer;
begin
  SetLength(FAramaSql, Length(ASqlIfadeleri));
  for i := 0 to High(ASqlIfadeleri) do
    FAramaSql[i] := ASqlIfadeleri[i];
end;

class procedure TFiltreModel.Ekle(var ASonuc: TFiltreSonuc; const AAd: string; const ADeger: Variant);
begin
  SetLength(ASonuc.Adlar, Length(ASonuc.Adlar) + 1);
  SetLength(ASonuc.Degerler, Length(ASonuc.Degerler) + 1);
  ASonuc.Adlar[High(ASonuc.Adlar)] := AAd;
  ASonuc.Degerler[High(ASonuc.Degerler)] := ADeger;
end;

class function TFiltreModel.LikeKacis(const AMetin: string): string;
begin
  // LIKE özel karakterleri kullanıcı yazdığında düz metin sayılsın.
  Result := AMetin.Replace('\', '\\').Replace('%', '\%').Replace('_', '\_');
end;

function TFiltreModel.Kosul(AAlan: TFiltreAlan; const ADeger: TFiltreDeger; var ASayac: Integer;
  var ASonuc: TFiltreSonuc): string;

  function YeniParam(const ADegerP: Variant): string;
  begin
    Inc(ASayac);
    Result := 'f' + IntToStr(ASayac);
    Ekle(ASonuc, Result, ADegerP);
  end;

var
  LMetin: string;
begin
  Result := '';
  case AAlan.Tur of
    ftMetin:
      begin
        LMetin := Trim(VarToStr(ADeger.Deger1));
        if LMetin = '' then
          Exit;
        case AAlan.MetinIslemi of
          fmEsit:
            Result := Format('lower(%s) = lower(:%s)', [AAlan.Sql, YeniParam(LMetin)]);
          fmIleBaslar:
            Result := Format('%s ILIKE :%s ESCAPE ''\''', [AAlan.Sql, YeniParam(LikeKacis(LMetin) + '%')]);
        else
          Result := Format('%s ILIKE :%s ESCAPE ''\''', [AAlan.Sql, YeniParam('%' + LikeKacis(LMetin) + '%')]);
        end;
      end;
    ftSayi, ftTarih:
      begin
        if not VarIsNull(ADeger.Deger1) then
          Result := Format('%s >= :%s', [AAlan.Sql, YeniParam(ADeger.Deger1)]);
        if not VarIsNull(ADeger.Deger2) then
        begin
          if Result <> '' then
            Result := Result + ' AND ';
          Result := Result + Format('%s <= :%s', [AAlan.Sql, YeniParam(ADeger.Deger2)]);
        end;
        if Result <> '' then
          Result := '(' + Result + ')';
      end;
    ftMantiksal, ftSecim:
      if not VarIsNull(ADeger.Deger1) then
        Result := Format('%s = :%s', [AAlan.Sql, YeniParam(ADeger.Deger1)]);
  end;
end;

function TFiltreModel.Olustur: TFiltreSonuc;
var
  LAlan: TFiltreAlan;
  LDeger: TFiltreDeger;
  LKosul, LArama, LIfade: string;
  LParcalar: TStringList;
  LSayac: Integer;
begin
  Result.Where := '';
  Result.Adlar := nil;
  Result.Degerler := nil;
  LSayac := 0;
  LParcalar := TStringList.Create;
  try
    for LAlan in FAlanlar do
      if FDegerler.TryGetValue(LowerCase(LAlan.Ad), LDeger) then
      begin
        LKosul := Kosul(LAlan, LDeger, LSayac, Result);
        if LKosul <> '' then
          LParcalar.Add(LKosul);
      end;

    if (Trim(FAramaMetni) <> '') and (Length(FAramaSql) > 0) then
    begin
      Inc(LSayac);
      Ekle(Result, 'f' + IntToStr(LSayac), '%' + LikeKacis(Trim(FAramaMetni)) + '%');
      LArama := '';
      for LIfade in FAramaSql do
      begin
        if LArama <> '' then
          LArama := LArama + ' OR ';
        LArama := LArama + Format('%s ILIKE :f%d ESCAPE ''\''', [LIfade, LSayac]);
      end;
      LParcalar.Add('(' + LArama + ')');
    end;

    for LKosul in LParcalar do
    begin
      if Result.Where <> '' then
        Result.Where := Result.Where + ' AND ';
      Result.Where := Result.Where + LKosul;
    end;
  finally
    LParcalar.Free;
  end;
end;

end.
