unit rad.json;

{
  IJson      — JSON nesne (key:value) contract'ı.  IDocDict'in framework karşılığı.
  IJsonArray — JSON dizi contract'ı.               IDocList'in framework karşılığı.

  Bu birim yalnızca interface tanımlar; implementasyon provider katmanında yapılır.
  Provider örneği: prov.mormot.json.pas (mORMot2 IDocDict/IDocList kullanır).

  Factory kullanımı:
    uses rad.json, prov.mormot.json;   // provider kayıt için yeterli
    var obj := NewJson;
    obj.S['name'] := 'Ahmet';
    obj.I['age']  := 30;
    ShowMessage(obj.ToJson);           // {"name":"Ahmet","age":30}
}

interface

type
  IJson      = interface;
  IJsonArray = interface;

  // ── Temel JSON nesnesi ─────────────────────────────────────────────────────
  IJson = interface
    ['{4A2F1D6B-8C3E-4F7A-B5D9-1E0C7A3F2B8D}']

    // Sorgu
    function  Len: Integer;
    function  IsEmpty: Boolean;
    function  Exists(const AKey: string): Boolean;
    function  Keys: TArray<string>;

    // Okuma (tip-güvenli)
    function GetStr  (const AKey: string): string;
    function GetInt  (const AKey: string): Int64;
    function GetFloat(const AKey: string): Double;
    function GetBool (const AKey: string): Boolean;
    function GetCurr (const AKey: string): Currency;
    function GetObj  (const AKey: string): IJson;
    function GetArr  (const AKey: string): IJsonArray;

    // Yazma
    procedure SetStr  (const AKey: string; const AValue: string);
    procedure SetInt  (const AKey: string; AValue: Int64);
    procedure SetFloat(const AKey: string; AValue: Double);
    procedure SetBool (const AKey: string; AValue: Boolean);
    procedure SetCurr (const AKey: string; AValue: Currency);
    procedure SetObj  (const AKey: string; const AValue: IJson);
    procedure SetArr  (const AKey: string; const AValue: IJsonArray);

    // Dönüşüm
    function  ToJson: string;
    procedure FromJson(const AJson: string);

    // Varsayılan değer okuma (key yoksa default döner, exception yok)
    function GetDef(const AKey: string; const ADefault: string): string;   overload;
    function GetDef(const AKey: string; ADefault: Int64): Int64;            overload;
    function GetDef(const AKey: string; ADefault: Double): Double;          overload;
    function GetDef(const AKey: string; ADefault: Boolean): Boolean;        overload;

    // Mutasyon
    procedure Clear;
    function  Del(const AKey: string): Boolean;

    // Property kısayolları
    property S[const AKey: string]: string   read GetStr   write SetStr;
    property I[const AKey: string]: Int64    read GetInt   write SetInt;
    property F[const AKey: string]: Double   read GetFloat write SetFloat;
    property B[const AKey: string]: Boolean  read GetBool  write SetBool;
    property C[const AKey: string]: Currency read GetCurr  write SetCurr;
    property O[const AKey: string]: IJson      read GetObj   write SetObj;
    property A[const AKey: string]: IJsonArray read GetArr   write SetArr;
  end;

  // ── JSON dizisi ────────────────────────────────────────────────────────────
  IJsonArray = interface
    ['{7B3D2E9A-1F4C-4A8B-C6E0-3D5F8A1B4C7E}']

    // Sorgu
    function Len: Integer;
    function IsEmpty: Boolean;

    // Index bazlı okuma
    function GetStr  (AIdx: Integer): string;
    function GetInt  (AIdx: Integer): Int64;
    function GetFloat(AIdx: Integer): Double;
    function GetBool (AIdx: Integer): Boolean;
    function GetCurr (AIdx: Integer): Currency;
    function GetObj  (AIdx: Integer): IJson;
    function GetArr  (AIdx: Integer): IJsonArray;

    // Eleman ekleme (sona)
    procedure Add(const AValue: string);   overload;
    procedure Add(AValue: Int64);          overload;
    procedure Add(AValue: Double);         overload;
    procedure Add(AValue: Boolean);        overload;
    procedure Add(AValue: Currency);       overload;
    procedure AddObj(const AValue: IJson);
    procedure AddArr(const AValue: IJsonArray);

    // Arama
    function  IndexOf(const AValue: string;  ACaseInsensitive: Boolean = False): Integer; overload;
    function  IndexOf(AValue: Int64): Integer;                                             overload;
    function  Exists (const AValue: string;  ACaseInsensitive: Boolean = False): Boolean;

    // Mutasyon
    procedure Clear;
    function  Del(AIdx: Integer): Boolean;
    function  Pop(AIdx: Integer = -1): string;

    // Dönüşüm
    function  ToJson: string;
    procedure FromJson(const AJson: string);

    // Property kısayolları (sadece okuma — dizi index'leri değiştirmek yerine Add kullanılır)
    property S[AIdx: Integer]: string    read GetStr;
    property I[AIdx: Integer]: Int64     read GetInt;
    property F[AIdx: Integer]: Double    read GetFloat;
    property B[AIdx: Integer]: Boolean   read GetBool;
    property C[AIdx: Integer]: Currency  read GetCurr;
    property O[AIdx: Integer]: IJson       read GetObj;
    property A[AIdx: Integer]: IJsonArray  read GetArr;
  end;

  // ── Factory tip tanımları ──────────────────────────────────────────────────
  // Provider birimi bu değişkenleri kendi Create fonksiyonlarıyla doldurur.
  TJsonFactory      = function(const AJson: string): IJson;
  TJsonArrayFactory = function(const AJson: string): IJsonArray;

var
  // Provider tarafından atanır; atanmadan önce çağrılırsa exception fırlar.
  JsonFactory     : TJsonFactory      = nil;
  JsonArrayFactory: TJsonArrayFactory = nil;

// Fabrika fonksiyonları — provider atamadan önce çağrılırsa EJsonFactoryNotSet
function NewJson(const AJson: string = '{}'): IJson;
function NewJsonArray(const AJson: string = '[]'): IJsonArray;

type
  EJsonFactoryNotSet = class(Exception);

implementation

function NewJson(const AJson: string): IJson;
begin
  if not Assigned(JsonFactory) then
    raise EJsonFactoryNotSet.Create(
      'JsonFactory atanmadı — bir provider birimi uses listesine ekleyin ' +
      '(örn: prov.mormot.json)');
  Result := JsonFactory(AJson);
end;

function NewJsonArray(const AJson: string): IJsonArray;
begin
  if not Assigned(JsonArrayFactory) then
    raise EJsonFactoryNotSet.Create(
      'JsonArrayFactory atanmadı — bir provider birimi uses listesine ekleyin ' +
      '(örn: prov.mormot.json)');
  Result := JsonArrayFactory(AJson);
end;

end.
