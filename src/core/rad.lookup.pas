(*
  rad.lookup — lookup TANIMLARININ kayit defteri.

  NE ISE YARAR
    Bir ERP'de "marka", "musteri tipi", "birim", "doviz" gibi onlarca kucuk
    liste vardir ve hepsi ayni sekilde davranir: bir sorgu, bir anahtar alan,
    bir gosterilen alan, bazen bir ust seviyeye bagimlilik. Bunlari her formda
    tek tek kablolamak, yeni bir tanim turu eklemeyi FORM DEGISIKLIGI yapar.

    Bu birim tanimi VERIYE tasir. Formda `LookupCode := 'MARKA'` yazarsiniz;
    sorgunun ne oldugu, hangi alanin anahtar oldugu, hangi ust tanima bagli
    oldugu kayit defterinden gelir. Yeni bir tanim turu eklemek bir SATIR
    eklemektir.

  NE YAPMAZ - ve bu bilincli
    Kayit defteri sorgu CALISTIRMAZ, dataset acmaz, hicbir vendor'a bagli
    degildir. Yalnizca "ne" sorusunu cevaplar; "nasil" uygulamanindir. Boylece
    ayni tanimlar UniDAC, FireDAC ya da bellek ici bir kaynakla da kullanilir
    ve bu birim src/core'da vendor'suz kalir.

  ONERILEN TABLO (zorunlu degil - LoadFromDataSet alan adlarini parametre alir)
    create table rad_lookup (
      kod            varchar(40)  primary key,
      baslik         varchar(80),
      sql_metni      text         not null,
      anahtar_alan   varchar(40)  not null,
      liste_alan     varchar(40)  not null,
      arama_param    varchar(40),      -- OnSearch metnini alacak parametre
      ust_kod        varchar(40),      -- kaskad kaynagi (baska bir kod)
      ust_param      varchar(40),      -- ust degeri alacak parametre
      tekil_param    varchar(40),      -- tek anahtar cozumleyen parametre
      min_arama      integer default 0,
      arama_gecikme  integer default 0
    );

  DOGRULAMA
    Validate, yapilandirmayi ISLETMEDEN once denetler: dongusel ust zinciri,
    var olmayan ust kod, ve SQL'de bildirilmeyen/bulunmayan parametreler.
    Bir yapilandirma tablosunun en buyuk riski sessizce yanlis olmasidir;
    burada yanlislik calisma zamanina birakilmaz.
*)
unit rad.lookup;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Data.DB;

type
  ERadLookup = class(Exception);

  TRadLookupDefs = class;

  /// <summary>Tek bir lookup tanimi. Sorgu calistirmaz - yalnizca tarif eder.</summary>
  TRadLookupDef = class(TCollectionItem)
  private
    FCode: string;
    FCaption: string;
    FSQL: string;
    FKeyField: string;
    FListField: string;
    FSearchParam: string;
    FParentCode: string;
    FParentParam: string;
    FLocateParam: string;
    FMinSearchLength: Integer;
    FSearchDelay: Cardinal;
    procedure SetCode(const AValue: string);
  public
    procedure Assign(Source: TPersistent); override;
    /// <summary>SQL icinde gecen parametre adlari (":" ile baslayanlar).</summary>
    function SqlParams: TArray<string>;
    /// <summary>Bu tanim bir ust tanima bagli mi?</summary>
    function HasParent: Boolean;
  published
    /// <summary>Kimlik. Formda LookupCode olarak bu yazilir. Buyuk/kucuk
    /// harf duyarsiz saklanir - 'marka' ve 'MARKA' ayni tanimdir.</summary>
    property Code: string read FCode write SetCode;
    property Caption: string read FCaption write FCaption;
    /// <summary>Liste sorgusu. Parametreleri asagidaki *Param alanlari adlandirir.</summary>
    property SQL: string read FSQL write FSQL;
    property KeyField: string read FKeyField write FKeyField;
    property ListField: string read FListField write FListField;
    /// <summary>Kullanicinin yazdigi metni alacak parametre adi.</summary>
    property SearchParam: string read FSearchParam write FSearchParam;
    /// <summary>Kaskad kaynagi olan tanimin Code'u. Bos ise zincirin kokudur.</summary>
    property ParentCode: string read FParentCode write FParentCode;
    /// <summary>Ust tanimin secili degerini alacak parametre adi.</summary>
    property ParentParam: string read FParentParam write FParentParam;
    /// <summary>Listede olmayan tek bir anahtari cozmek icin kullanilan
    /// parametre adi (OnLocate yolu).</summary>
    property LocateParam: string read FLocateParam write FLocateParam;
    property MinSearchLength: Integer read FMinSearchLength write FMinSearchLength default 0;
    property SearchDelay: Cardinal read FSearchDelay write FSearchDelay default 0;
  end;

  TRadLookupDefs = class(TCollection)
  private
    function GetItem(AIndex: Integer): TRadLookupDef;
  public
    constructor Create;
    function Add: TRadLookupDef;
    function Find(const ACode: string): TRadLookupDef;
    property Items[AIndex: Integer]: TRadLookupDef read GetItem; default;
  end;

  /// <summary>Uygulama genelinde tek kayit defteri.</summary>
  TRadLookupRegistry = class
  private
    FDefs: TRadLookupDefs;
    class var FInstance: TRadLookupRegistry;
    class destructor ClassDestroy;
  public
    constructor Create;
    destructor Destroy; override;
    class function Instance: TRadLookupRegistry;

    function Find(const ACode: string): TRadLookupDef;
    /// <summary>Find'in istisna atan hali - kod yoksa ERadLookup.</summary>
    function Get(const ACode: string): TRadLookupDef;
    procedure Clear;

    /// <summary>Bir dataset'ten yukler. Alan adlari parametre oldugu icin
    /// tablonun semasi bu birime dayatilmaz.</summary>
    procedure LoadFromDataSet(ADataSet: TDataSet;
      const AFldCode: string = 'kod';
      const AFldCaption: string = 'baslik';
      const AFldSQL: string = 'sql_metni';
      const AFldKey: string = 'anahtar_alan';
      const AFldList: string = 'liste_alan';
      const AFldSearchParam: string = 'arama_param';
      const AFldParentCode: string = 'ust_kod';
      const AFldParentParam: string = 'ust_param';
      const AFldLocateParam: string = 'tekil_param';
      const AFldMinSearch: string = 'min_arama';
      const AFldDelay: string = 'arama_gecikme');

    /// <summary>Koktan bu tanima kadar olan zincir: ['ULKE','SEHIR','ILCE'].
    /// Dongu varsa ERadLookup.</summary>
    function Chain(const ACode: string): TArray<string>;
    /// <summary>ParentCode'u ACode olan tanimlar - yani dogrudan cocuklari.</summary>
    function ChildrenOf(const ACode: string): TArray<string>;

    (* Yapilandirmayi isletmeden once denetler. Bos string = sorun yok.
       Yakaladiklari:
         - ayni Code'un iki kez tanimlanmasi
         - var olmayan bir ParentCode
         - dongusel ust zinciri (A->B->A)
         - ust tanimi olup ParentParam'i bos olan tanim
         - SQL'de KARSILIGI OLMAYAN parametre bildirimi
         - SQL'de gecip hicbir alanda bildirilmemis parametre
       Son iki madde onemli: yanlis parametre adi calisma zamaninda
       "parametre bulunamadi" olarak degil, cogu zaman SESSIZ bir bos liste
       olarak gorunur. *)
    function Validate: string;

    property Defs: TRadLookupDefs read FDefs;
  end;

/// <summary>TRadLookupRegistry.Instance icin kisayol.</summary>
function LookupRegistry: TRadLookupRegistry;

implementation

const
  CMaxChain = 32;   { Makul bir zincir derinligi ustu - dongu koruyucusu }

function LookupRegistry: TRadLookupRegistry;
begin
  Result := TRadLookupRegistry.Instance;
end;

{ ─────────────────────────────────────────────────────────────────────────
  SQL parametre ayristirma

  ':' ile baslayan sozcukleri toplar. PostgreSQL'de '::' bir TIP DONUSUMUDUR
  (`deger::text`), parametre degildir - atlanmazsa her cast sahte bir parametre
  uretir ve Validate yanlis alarm verir. Tirnak icindeki metinler de atlanir:
  `where ad = ':marka'` bir parametre degildir.
  ───────────────────────────────────────────────────────────────────────── }
function ParseSqlParams(const ASql: string): TArray<string>;
var
  i, n: Integer;
  LAd: string;
  LList: TList<string>;
  LTirnakta: Boolean;
begin
  LList := TList<string>.Create;
  try
    i := 1;
    n := Length(ASql);
    LTirnakta := False;
    while i <= n do
    begin
      if ASql[i] = '''' then
      begin
        LTirnakta := not LTirnakta;
        Inc(i);
        Continue;
      end;
      if LTirnakta then
      begin
        Inc(i);
        Continue;
      end;
      if ASql[i] = ':' then
      begin
        { '::' -> tip donusumu, parametre degil }
        if (i < n) and (ASql[i + 1] = ':') then
        begin
          Inc(i, 2);
          Continue;
        end;
        Inc(i);
        LAd := '';
        while (i <= n) and (CharInSet(ASql[i], ['A'..'Z', 'a'..'z', '0'..'9', '_'])) do
        begin
          LAd := LAd + ASql[i];
          Inc(i);
        end;
        if (LAd <> '') and (LList.IndexOf(LowerCase(LAd)) < 0) then
          LList.Add(LowerCase(LAd));
        Continue;
      end;
      Inc(i);
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

{ TRadLookupDef }

procedure TRadLookupDef.SetCode(const AValue: string);
begin
  FCode := UpperCase(Trim(AValue));
end;

procedure TRadLookupDef.Assign(Source: TPersistent);
var
  S: TRadLookupDef;
begin
  if not (Source is TRadLookupDef) then
  begin
    inherited Assign(Source);
    Exit;
  end;
  S := TRadLookupDef(Source);
  FCode := S.FCode;
  FCaption := S.FCaption;
  FSQL := S.FSQL;
  FKeyField := S.FKeyField;
  FListField := S.FListField;
  FSearchParam := S.FSearchParam;
  FParentCode := S.FParentCode;
  FParentParam := S.FParentParam;
  FLocateParam := S.FLocateParam;
  FMinSearchLength := S.FMinSearchLength;
  FSearchDelay := S.FSearchDelay;
end;

function TRadLookupDef.SqlParams: TArray<string>;
begin
  Result := ParseSqlParams(FSQL);
end;

function TRadLookupDef.HasParent: Boolean;
begin
  Result := Trim(FParentCode) <> '';
end;

{ TRadLookupDefs }

constructor TRadLookupDefs.Create;
begin
  inherited Create(TRadLookupDef);
end;

function TRadLookupDefs.GetItem(AIndex: Integer): TRadLookupDef;
begin
  Result := TRadLookupDef(inherited Items[AIndex]);
end;

function TRadLookupDefs.Add: TRadLookupDef;
begin
  Result := TRadLookupDef(inherited Add);
end;

function TRadLookupDefs.Find(const ACode: string): TRadLookupDef;
var
  i: Integer;
  LAra: string;
begin
  Result := nil;
  LAra := UpperCase(Trim(ACode));
  if LAra = '' then
    Exit;
  for i := 0 to Count - 1 do
    if Items[i].Code = LAra then
      Exit(Items[i]);
end;

{ TRadLookupRegistry }

constructor TRadLookupRegistry.Create;
begin
  inherited Create;
  FDefs := TRadLookupDefs.Create;
end;

destructor TRadLookupRegistry.Destroy;
begin
  FDefs.Free;
  inherited Destroy;
end;

class destructor TRadLookupRegistry.ClassDestroy;
begin
  FInstance.Free;
end;

class function TRadLookupRegistry.Instance: TRadLookupRegistry;
begin
  if FInstance = nil then
    FInstance := TRadLookupRegistry.Create;
  Result := FInstance;
end;

procedure TRadLookupRegistry.Clear;
begin
  FDefs.Clear;
end;

function TRadLookupRegistry.Find(const ACode: string): TRadLookupDef;
begin
  Result := FDefs.Find(ACode);
end;

function TRadLookupRegistry.Get(const ACode: string): TRadLookupDef;
begin
  Result := Find(ACode);
  if Result = nil then
    raise ERadLookup.CreateFmt('Lookup tanimi bulunamadi: "%s"', [ACode]);
end;

procedure TRadLookupRegistry.LoadFromDataSet(ADataSet: TDataSet;
  const AFldCode, AFldCaption, AFldSQL, AFldKey, AFldList, AFldSearchParam,
  AFldParentCode, AFldParentParam, AFldLocateParam, AFldMinSearch,
  AFldDelay: string);

  function Metin(const AFieldName: string): string;
  var
    F: TField;
  begin
    Result := '';
    if AFieldName = '' then
      Exit;
    F := ADataSet.FindField(AFieldName);
    if F <> nil then
      Result := F.AsString;
  end;

  function Sayi(const AFieldName: string): Integer;
  var
    F: TField;
  begin
    Result := 0;
    if AFieldName = '' then
      Exit;
    F := ADataSet.FindField(AFieldName);
    if F <> nil then
      Result := F.AsInteger;
  end;

var
  LDef: TRadLookupDef;
begin
  if ADataSet = nil then
    raise ERadLookup.Create('LoadFromDataSet: dataset nil');
  if not ADataSet.Active then
    raise ERadLookup.Create('LoadFromDataSet: dataset kapali');

  { Zorunlu alan yoksa sessizce bos tanim uretmek yerine hemen soyluyoruz -
    yanlis alan adi en sik yapilan hata. }
  if ADataSet.FindField(AFldCode) = nil then
    raise ERadLookup.CreateFmt(
      'LoadFromDataSet: "%s" alani dataset''te yok. Alan adlarini parametreyle verin.',
      [AFldCode]);

  ADataSet.First;
  while not ADataSet.Eof do
  begin
    LDef := FDefs.Add;
    LDef.Code := Metin(AFldCode);
    LDef.Caption := Metin(AFldCaption);
    LDef.SQL := Metin(AFldSQL);
    LDef.KeyField := Metin(AFldKey);
    LDef.ListField := Metin(AFldList);
    LDef.SearchParam := Metin(AFldSearchParam);
    LDef.ParentCode := UpperCase(Trim(Metin(AFldParentCode)));
    LDef.ParentParam := Metin(AFldParentParam);
    LDef.LocateParam := Metin(AFldLocateParam);
    LDef.MinSearchLength := Sayi(AFldMinSearch);
    LDef.SearchDelay := Sayi(AFldDelay);
    ADataSet.Next;
  end;
end;

function TRadLookupRegistry.Chain(const ACode: string): TArray<string>;
var
  LDef: TRadLookupDef;
  LTers: TList<string>;
  i: Integer;
begin
  LTers := TList<string>.Create;
  try
    LDef := Get(ACode);
    while LDef <> nil do
    begin
      if LTers.IndexOf(LDef.Code) >= 0 then
        raise ERadLookup.CreateFmt(
          'Lookup zincirinde dongu: "%s" kendi ustlerinden biri.', [LDef.Code]);
      LTers.Add(LDef.Code);
      if LTers.Count > CMaxChain then
        raise ERadLookup.CreateFmt(
          'Lookup zinciri %d seviyeyi asti ("%s") - yapilandirma hatasi olmali.',
          [CMaxChain, ACode]);
      if not LDef.HasParent then
        Break;
      LDef := Find(LDef.ParentCode);
    end;

    { Koku basa al }
    SetLength(Result, LTers.Count);
    for i := 0 to LTers.Count - 1 do
      Result[LTers.Count - 1 - i] := LTers[i];
  finally
    LTers.Free;
  end;
end;

function TRadLookupRegistry.ChildrenOf(const ACode: string): TArray<string>;
var
  i: Integer;
  LAra: string;
  LList: TList<string>;
begin
  LAra := UpperCase(Trim(ACode));
  LList := TList<string>.Create;
  try
    for i := 0 to FDefs.Count - 1 do
      if FDefs[i].ParentCode = LAra then
        LList.Add(FDefs[i].Code);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TRadLookupRegistry.Validate: string;
var
  i, j, LDerinlik: Integer;
  LDef, LGezen: TRadLookupDef;
  LHatalar: TStringList;
  LParams: TArray<string>;

  function ParamVarMi(const AAd: string): Boolean;
  var
    p: string;
  begin
    Result := False;
    if Trim(AAd) = '' then
      Exit;
    for p in LParams do
      if p = LowerCase(Trim(AAd)) then
        Exit(True);
  end;

  function BildirilmisMi(ADef: TRadLookupDef; const AParam: string): Boolean;
  begin
    Result := SameText(AParam, ADef.SearchParam) or
              SameText(AParam, ADef.ParentParam) or
              SameText(AParam, ADef.LocateParam);
  end;

var
  p: string;
begin
  LHatalar := TStringList.Create;
  try
    for i := 0 to FDefs.Count - 1 do
    begin
      LDef := FDefs[i];

      if LDef.Code = '' then
      begin
        LHatalar.Add(Format('[%d] Code bos.', [i]));
        Continue;
      end;

      { Ayni kod iki kez }
      for j := 0 to i - 1 do
        if FDefs[j].Code = LDef.Code then
          LHatalar.Add(Format('"%s" iki kez tanimlanmis (%d ve %d).',
            [LDef.Code, j, i]));

      if Trim(LDef.SQL) = '' then
        LHatalar.Add(Format('"%s": SQL bos.', [LDef.Code]));
      if Trim(LDef.KeyField) = '' then
        LHatalar.Add(Format('"%s": KeyField bos.', [LDef.Code]));
      if Trim(LDef.ListField) = '' then
        LHatalar.Add(Format('"%s": ListField bos.', [LDef.Code]));

      { Ust tanim }
      if LDef.HasParent then
      begin
        if Find(LDef.ParentCode) = nil then
          LHatalar.Add(Format('"%s": ParentCode "%s" diye bir tanim yok.',
            [LDef.Code, LDef.ParentCode]))
        else
        begin
          { Dongu: ust zincirini yuru }
          LGezen := Find(LDef.ParentCode);
          LDerinlik := 0;
          while (LGezen <> nil) and (LDerinlik <= CMaxChain) do
          begin
            if LGezen.Code = LDef.Code then
            begin
              LHatalar.Add(Format('"%s": ust zincirinde DONGU var.', [LDef.Code]));
              Break;
            end;
            if not LGezen.HasParent then
              Break;
            LGezen := Find(LGezen.ParentCode);
            Inc(LDerinlik);
          end;
        end;

        if Trim(LDef.ParentParam) = '' then
          LHatalar.Add(Format(
            '"%s": ParentCode dolu ama ParentParam bos - ust deger sorguya nasil gececek?',
            [LDef.Code]));
      end;

      { Parametre tutarliligi }
      LParams := LDef.SqlParams;

      if (Trim(LDef.SearchParam) <> '') and not ParamVarMi(LDef.SearchParam) then
        LHatalar.Add(Format('"%s": SearchParam ":%s" SQL''de gecmiyor.',
          [LDef.Code, LDef.SearchParam]));
      if (Trim(LDef.ParentParam) <> '') and not ParamVarMi(LDef.ParentParam) then
        LHatalar.Add(Format('"%s": ParentParam ":%s" SQL''de gecmiyor.',
          [LDef.Code, LDef.ParentParam]));
      if (Trim(LDef.LocateParam) <> '') and not ParamVarMi(LDef.LocateParam) then
        LHatalar.Add(Format('"%s": LocateParam ":%s" SQL''de gecmiyor.',
          [LDef.Code, LDef.LocateParam]));

      for p in LParams do
        if not BildirilmisMi(LDef, p) then
          LHatalar.Add(Format(
            '"%s": SQL''deki ":%s" parametresi hicbir alanda bildirilmemis - ' +
            'kimse dolduramaz.', [LDef.Code, p]));
    end;

    Result := LHatalar.Text;
  finally
    LHatalar.Free;
  end;
end;

end.
