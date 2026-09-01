unit rad.AESObj;

interface

// NOT: aşağıdaki uses listesinin bir bölümü, RTTI'nin göremediği tipler
// yüzünden kaynak unit'in kendi uses'undan alındı; bir kısmı gereksiz
// olabilir. Derledikten sonra kullanılmayanları silebilirsin.
uses
  AESObj, CryptoConst, MiscObj, System.Classes, System.IOUtils, CryptBase, ErrorList, RandomCore,
  AESModes, SalsaObj, SPECKObj;


{$REGION 'RAD-FLUENT:TConvert:TYPES — ÜRETİLMİŞTİR; bu bloğu elle düzenleme, yeniden üretimde kaybolur'}
// ===========================================================================
// GenerateFluentCode raporu — TConvert
// ===========================================================================
// Üretilen: 1 property, 0 indeksli property, 64 metod, 0 kaynaktan.
// Kaynak taraması: E:\system\dev\Delphi\component\TMS\tms.vcl.Cryptography\MiscObj.pas
// Not yok — RTTI ile kaynak arasında fark bulunmadı.
// Üretilen kodu her zaman gözden geçir (class helper sızıntısı, çakışmalar).
// ===========================================================================

type
  IConvert = interface
    ['{2E14B7F6-9909-4015-8434-3ED332E88AB3}']
    function AsInstance: TConvert;

    function SetAType(const aAType: TConvertType): IConvert;
    function GetAType: TConvertType;

    function CharToFormat(charstring: string): string;
    function FormatToChar(str: string): string;
    function UnicodeToPAnsiChar(str: string): PAnsiChar;
    function PAnsiCharFromUnicodeLength(str: string): Integer;
    function StringToBuffer(str: string; u: TUnicode; var msgLen: Integer): PAnsiChar;
    function StringToBufferA(str: string; u: TUnicode): PAnsiChar;
    function StringToPAnsiChar(str: string): PAnsiChar;
    function UnicodeStringToFormat(str: string): string;
    function FormatToUnicodeString(str: string): string;
    function StringToByteArray(str: string): TArray<System.Byte>; overload;
    function ByteArrayToString(aob: array of Byte): string;
    function TestUnicode(str: string): Integer;
    function StringToUnicode(str: string): string;
    function BMPStringToUnicode(const S: string): string;
    function StringToFormat(charstring: string): string;
    function FormatToString(str: string): string;
    function OutputFormatLength(charlen: Integer): Integer;
    function CharLength(charstring: string): Integer;
    function Base64ToHexa(base64String: string): string;
    function HexaToBase64(hexaString: string): string;
    function Base64ToBase64url(inString: string): string;
    function Base64urlToBase64(inString: string): string;
    function Base64urlToHexa(inString: string): string;
    function HexaToBase64url(inString: string): string;
    function Base32ToHexa(base32String: string): string;
    function HexaToBase32(hexaString: string): string;
    function Base32ToBase64url(inString: string): string;
    function Base64urlToBase32(inString: string): string;
    function Base32ToBase64(inString: string): string;
    function Base64ToBase32(inString: string): string;
    function KeyRSAOpenSSLToKeyTRSAEncSign(strKey: string): string;
    function KeyTRSAEncSignToKeyRSAOpenSSL(strKey: string): string;
    function Base58Encode(const value: UInt64): string;
    function Base58Decode(const encoded: string): UInt64;
    function TBytesToString(const t: TArray<System.Byte>): string;
    function StringToTBytes(const str: string): TArray<System.Byte>;
    function RandomString(len: Integer): string;
    procedure ToCharString(InHexString: string; var OutCharString: string); overload;
    procedure ToCharString(InHexString: string; var OutCharArray: TArray<System.Byte>); overload;
    function ToCharString(InHexString: string): string; overload;
    procedure ToHexString(InCharString: string; var OutHexString: string); overload;
    procedure ToHexString(InCharString: string; var OutHexArray: TArray<System.Byte>); overload;
    function ToHexString(InCharString: string): string; overload;
    function StringToCodePoints(const s: string): TArray<System.Integer>;
    function CodePointsToString(const Codes: TArray<System.Integer>): string;
    function StringToCHexList(const S: string): string;
    function TBytesToHexString(const Bytes: TArray<System.Byte>): string;
    function TBytesToBase64(const Bytes: TArray<System.Byte>): string;
    procedure ToBase32String(InCharString: string; var Base32String: string);
    procedure ToBase64String(InCharString: string; var Base64String: string);
    procedure ToBase64urlString(InCharString: string; var Base64String: string);
    procedure ToStrictBase64urlString(InCharString: string; var Base64String: string);
    procedure Base32ToChar(Base32String: string; var OutCharString: string);
    procedure Base64ToChar(Base64String: string; var OutCharString: string);
    procedure Base64urlToChar(Base64UrlString: string; var OutCharString: string);
    procedure FormatBeforeConvert(InCharString: string; var OutCharStringString: string); overload;
    function FormatBeforeConvert(InCharString: string; aType: TConvertType): string; overload;
    function StringToByteArray(str: string; u: TUnicode): TArray<System.Byte>; overload;
    function UnicodeToByteArray(str: string): TArray<System.Byte>;
    function BigHexToBigInt(s: string): string;
    function Add(x: string; y: string): string;
    function HexToInt(a: Char): Integer;
    function Reverse(inString: string): string;
    function ToUtf8(s: string): string;
  end;

  TConvertFluent = class(TInterfacedObject, IConvert)
  strict private
    FInstance: TConvert;
    FAutoFree: Boolean;
  public
    constructor Create(AInstance: TConvert; AAutoFree: Boolean = False);
    destructor Destroy; override;
    /// Var olan bir örneği sarar. Ömür ÇAĞIRANIN sorumluluğundadır.
    class function New(AInstance: TConvert; AAutoFree: Boolean = False): IConvert; overload;
    /// Örneği KENDİSİ yaratır ve SAHİPLENİR — arayüz serbest kalınca free eder.
    class function New: IConvert; overload;
    function AsInstance: TConvert;

    function SetAType(const aAType: TConvertType): IConvert;
    function GetAType: TConvertType;

    function CharToFormat(charstring: string): string;
    function FormatToChar(str: string): string;
    function UnicodeToPAnsiChar(str: string): PAnsiChar;
    function PAnsiCharFromUnicodeLength(str: string): Integer;
    function StringToBuffer(str: string; u: TUnicode; var msgLen: Integer): PAnsiChar;
    function StringToBufferA(str: string; u: TUnicode): PAnsiChar;
    function StringToPAnsiChar(str: string): PAnsiChar;
    function UnicodeStringToFormat(str: string): string;
    function FormatToUnicodeString(str: string): string;
    function StringToByteArray(str: string): TArray<System.Byte>; overload;
    function ByteArrayToString(aob: array of Byte): string;
    function TestUnicode(str: string): Integer;
    function StringToUnicode(str: string): string;
    function BMPStringToUnicode(const S: string): string;
    function StringToFormat(charstring: string): string;
    function FormatToString(str: string): string;
    function OutputFormatLength(charlen: Integer): Integer;
    function CharLength(charstring: string): Integer;
    function Base64ToHexa(base64String: string): string;
    function HexaToBase64(hexaString: string): string;
    function Base64ToBase64url(inString: string): string;
    function Base64urlToBase64(inString: string): string;
    function Base64urlToHexa(inString: string): string;
    function HexaToBase64url(inString: string): string;
    function Base32ToHexa(base32String: string): string;
    function HexaToBase32(hexaString: string): string;
    function Base32ToBase64url(inString: string): string;
    function Base64urlToBase32(inString: string): string;
    function Base32ToBase64(inString: string): string;
    function Base64ToBase32(inString: string): string;
    function KeyRSAOpenSSLToKeyTRSAEncSign(strKey: string): string;
    function KeyTRSAEncSignToKeyRSAOpenSSL(strKey: string): string;
    function Base58Encode(const value: UInt64): string;
    function Base58Decode(const encoded: string): UInt64;
    function TBytesToString(const t: TArray<System.Byte>): string;
    function StringToTBytes(const str: string): TArray<System.Byte>;
    function RandomString(len: Integer): string;
    procedure ToCharString(InHexString: string; var OutCharString: string); overload;
    procedure ToCharString(InHexString: string; var OutCharArray: TArray<System.Byte>); overload;
    function ToCharString(InHexString: string): string; overload;
    procedure ToHexString(InCharString: string; var OutHexString: string); overload;
    procedure ToHexString(InCharString: string; var OutHexArray: TArray<System.Byte>); overload;
    function ToHexString(InCharString: string): string; overload;
    function StringToCodePoints(const s: string): TArray<System.Integer>;
    function CodePointsToString(const Codes: TArray<System.Integer>): string;
    function StringToCHexList(const S: string): string;
    function TBytesToHexString(const Bytes: TArray<System.Byte>): string;
    function TBytesToBase64(const Bytes: TArray<System.Byte>): string;
    procedure ToBase32String(InCharString: string; var Base32String: string);
    procedure ToBase64String(InCharString: string; var Base64String: string);
    procedure ToBase64urlString(InCharString: string; var Base64String: string);
    procedure ToStrictBase64urlString(InCharString: string; var Base64String: string);
    procedure Base32ToChar(Base32String: string; var OutCharString: string);
    procedure Base64ToChar(Base64String: string; var OutCharString: string);
    procedure Base64urlToChar(Base64UrlString: string; var OutCharString: string);
    procedure FormatBeforeConvert(InCharString: string; var OutCharStringString: string); overload;
    function FormatBeforeConvert(InCharString: string; aType: TConvertType): string; overload;
    function StringToByteArray(str: string; u: TUnicode): TArray<System.Byte>; overload;
    function UnicodeToByteArray(str: string): TArray<System.Byte>;
    function BigHexToBigInt(s: string): string;
    function Add(x: string; y: string): string;
    function HexToInt(a: Char): Integer;
    function Reverse(inString: string): string;
    function ToUtf8(s: string): string;
  end;
{$ENDREGION}

{$REGION 'RAD-FLUENT:TAESEncryption:TYPES — ÜRETİLMİŞTİR; bu bloğu elle düzenleme, yeniden üretimde kaybolur'}
// ===========================================================================
// GenerateFluentCode raporu — TAESEncryption
// ===========================================================================
// Üretilen: 11 property, 0 indeksli property, 8 metod, 1 kaynaktan.
// Kaynak taraması: E:\system\dev\Delphi\component\TMS\tms.vcl.Cryptography\AESObj.pas
// * RTTI GÖREMEDİ, kaynaktan üretildi: property keyLength: TAESKeyLength
// Üretilen kodu her zaman gözden geçir (class helper sızıntısı, çakışmalar).
// ===========================================================================

type
  IAESEncryption = interface
    ['{7452DE53-58A3-434C-A1E4-2BF6102AC044}']
    function AsInstance: TAESEncryption;

    function SetKey(const aKey: string): IAESEncryption;
    function GetKey: string;
    function SetAType(const aAType: TAESType): IAESEncryption;
    function GetAType: TAESType;
    function SetInputFormat(const aInputFormat: TConvertType): IAESEncryption;
    function GetInputFormat: TConvertType;
    function SetOutputFormat(const aOutputFormat: TConvertType): IAESEncryption;
    function GetOutputFormat: TConvertType;
    function SetIVMode(const aIVMode: TIVMode): IAESEncryption;
    function GetIVMode: TIVMode;
    function SetIV(const aIV: string): IAESEncryption;
    function GetIV: string;
    function SetPaddingMode(const aPaddingMode: TPaddingMode): IAESEncryption;
    function GetPaddingMode: TPaddingMode;
    function SetUnicode(const aUnicode: TUnicode): IAESEncryption;
    function GetUnicode: TUnicode;
    function SetEndian(const aEndian: TEndian): IAESEncryption;
    function GetEndian: TEndian;
    function SetProgress(const aProgress: Integer): IAESEncryption;
    function GetProgress: Integer;
    function SetOnChange(const aOnChange: TNotifyEvent): IAESEncryption;
    function GetOnChange: TNotifyEvent;
    // [KAYNAK] RTTI bu üyeyi görmedi (tipinin RTTI'si yok); kaynaktan alındı.
    function SetKeyLength(const aKeyLength: TAESKeyLength): IAESEncryption;
    // [KAYNAK] RTTI bu üyeyi görmedi (tipinin RTTI'si yok); kaynaktan alındı.
    function GetKeyLength: TAESKeyLength;

    function Encrypt(s: string): string;
    function Decrypt(s: string): string; overload;
    function Decrypt(s: string; var o: string): Integer; overload;
    procedure EncryptFileW(s: string; o: string);
    function DecryptFileW(s: string; o: string): Integer;
    procedure EncryptStream(s: TStream; o: TStream);
    procedure DecryptStream(s: TStream; o: TStream);
    function DecryptStream2(s: TStream; o: TStream): Integer;
  end;

  TAESEncryptionFluent = class(TInterfacedObject, IAESEncryption)
  strict private
    FInstance: TAESEncryption;
    FAutoFree: Boolean;
  public
    constructor Create(AInstance: TAESEncryption; AAutoFree: Boolean = False);
    destructor Destroy; override;
    /// Var olan bir örneği sarar. Ömür ÇAĞIRANIN sorumluluğundadır.
    class function New(AInstance: TAESEncryption; AAutoFree: Boolean = False): IAESEncryption; overload;
    /// Örneği KENDİSİ yaratır ve SAHİPLENİR — arayüz serbest kalınca free eder.
    class function New: IAESEncryption; overload;
    function AsInstance: TAESEncryption;

    function SetKey(const aKey: string): IAESEncryption;
    function GetKey: string;
    function SetAType(const aAType: TAESType): IAESEncryption;
    function GetAType: TAESType;
    function SetInputFormat(const aInputFormat: TConvertType): IAESEncryption;
    function GetInputFormat: TConvertType;
    function SetOutputFormat(const aOutputFormat: TConvertType): IAESEncryption;
    function GetOutputFormat: TConvertType;
    function SetIVMode(const aIVMode: TIVMode): IAESEncryption;
    function GetIVMode: TIVMode;
    function SetIV(const aIV: string): IAESEncryption;
    function GetIV: string;
    function SetPaddingMode(const aPaddingMode: TPaddingMode): IAESEncryption;
    function GetPaddingMode: TPaddingMode;
    function SetUnicode(const aUnicode: TUnicode): IAESEncryption;
    function GetUnicode: TUnicode;
    function SetEndian(const aEndian: TEndian): IAESEncryption;
    function GetEndian: TEndian;
    function SetProgress(const aProgress: Integer): IAESEncryption;
    function GetProgress: Integer;
    function SetOnChange(const aOnChange: TNotifyEvent): IAESEncryption;
    function GetOnChange: TNotifyEvent;
    // [KAYNAK] RTTI bu üyeyi görmedi (tipinin RTTI'si yok); kaynaktan alındı.
    function SetKeyLength(const aKeyLength: TAESKeyLength): IAESEncryption;
    // [KAYNAK] RTTI bu üyeyi görmedi (tipinin RTTI'si yok); kaynaktan alındı.
    function GetKeyLength: TAESKeyLength;

    function Encrypt(s: string): string;
    function Decrypt(s: string): string; overload;
    function Decrypt(s: string; var o: string): Integer; overload;
    procedure EncryptFileW(s: string; o: string);
    function DecryptFileW(s: string; o: string): Integer;
    procedure EncryptStream(s: TStream; o: TStream);
    procedure DecryptStream(s: TStream; o: TStream);
    function DecryptStream2(s: TStream; o: TStream): Integer;
  end;
{$ENDREGION}

{$REGION 'RAD-FLUENT:TSalsaEncryption:TYPES — ÜRETİLMİŞTİR; bu bloğu elle düzenleme, yeniden üretimde kaybolur'}
// ===========================================================================
// GenerateFluentCode raporu — TSalsaEncryption
// ===========================================================================
// Üretilen: 8 property, 0 indeksli property, 6 metod, 0 kaynaktan.
// Kaynak taraması: E:\system\dev\Delphi\component\TMS\tms.vcl.Cryptography\SalsaObj.pas
// Not yok — RTTI ile kaynak arasında fark bulunmadı.
// Üretilen kodu her zaman gözden geçir (class helper sızıntısı, çakışmalar).
// ===========================================================================

type
  ISalsaEncryption = interface
    ['{CA109364-2E95-4B58-A21F-1D7172A4099D}']
    function AsInstance: TSalsaEncryption;

    function SetKeyLength(const aKeyLength: TSalsaKeyLength): ISalsaEncryption;
    function GetKeyLength: TSalsaKeyLength;
    function SetKey(const aKey: string): ISalsaEncryption;
    function GetKey: string;
    function SetInputFormat(const aInputFormat: TConvertType): ISalsaEncryption;
    function GetInputFormat: TConvertType;
    function SetOutputFormat(const aOutputFormat: TConvertType): ISalsaEncryption;
    function GetOutputFormat: TConvertType;
    function SetUnicode(const aUnicode: TUnicode): ISalsaEncryption;
    function GetUnicode: TUnicode;
    function SetIV(const aIV: string): ISalsaEncryption;
    function GetIV: string;
    function SetProgress(const aProgress: Integer): ISalsaEncryption;
    function GetProgress: Integer;
    function SetOnChange(const aOnChange: TNotifyEvent): ISalsaEncryption;
    function GetOnChange: TNotifyEvent;

    function Encrypt(s: string): string;
    function Decrypt(s: string): string;
    procedure EncryptFile(s: string; o: string);
    procedure DecryptFile(s: string; o: string);
    procedure EncryptStream(s: TStream; o: TStream);
    procedure DecryptStream(s: TStream; o: TStream);
  end;

  TSalsaEncryptionFluent = class(TInterfacedObject, ISalsaEncryption)
  strict private
    FInstance: TSalsaEncryption;
    FAutoFree: Boolean;
  public
    constructor Create(AInstance: TSalsaEncryption; AAutoFree: Boolean = False);
    destructor Destroy; override;
    /// Var olan bir örneği sarar. Ömür ÇAĞIRANIN sorumluluğundadır.
    class function New(AInstance: TSalsaEncryption; AAutoFree: Boolean = False): ISalsaEncryption; overload;
    /// Örneği KENDİSİ yaratır ve SAHİPLENİR — arayüz serbest kalınca free eder.
    class function New: ISalsaEncryption; overload;
    function AsInstance: TSalsaEncryption;

    function SetKeyLength(const aKeyLength: TSalsaKeyLength): ISalsaEncryption;
    function GetKeyLength: TSalsaKeyLength;
    function SetKey(const aKey: string): ISalsaEncryption;
    function GetKey: string;
    function SetInputFormat(const aInputFormat: TConvertType): ISalsaEncryption;
    function GetInputFormat: TConvertType;
    function SetOutputFormat(const aOutputFormat: TConvertType): ISalsaEncryption;
    function GetOutputFormat: TConvertType;
    function SetUnicode(const aUnicode: TUnicode): ISalsaEncryption;
    function GetUnicode: TUnicode;
    function SetIV(const aIV: string): ISalsaEncryption;
    function GetIV: string;
    function SetProgress(const aProgress: Integer): ISalsaEncryption;
    function GetProgress: Integer;
    function SetOnChange(const aOnChange: TNotifyEvent): ISalsaEncryption;
    function GetOnChange: TNotifyEvent;

    function Encrypt(s: string): string;
    function Decrypt(s: string): string;
    procedure EncryptFile(s: string; o: string);
    procedure DecryptFile(s: string; o: string);
    procedure EncryptStream(s: TStream; o: TStream);
    procedure DecryptStream(s: TStream; o: TStream);
  end;
{$ENDREGION}

{$REGION 'RAD-FLUENT:TSPECKEncryption:TYPES — ÜRETİLMİŞTİR; bu bloğu elle düzenleme, yeniden üretimde kaybolur'}
// ===========================================================================
// GenerateFluentCode raporu — TSPECKEncryption
// ===========================================================================
// Üretilen: 11 property, 0 indeksli property, 6 metod, 0 kaynaktan.
// Kaynak taraması: E:\system\dev\Delphi\component\TMS\tms.vcl.Cryptography\SPECKObj.pas
// Not yok — RTTI ile kaynak arasında fark bulunmadı.
// Üretilen kodu her zaman gözden geçir (class helper sızıntısı, çakışmalar).
// ===========================================================================

type
  ISPECKEncryption = interface
    ['{29A12E24-D46A-4BBF-B32F-169E3AD775B4}']
    function AsInstance: TSPECKEncryption;

    function SetComp(const aComp: Boolean): ISPECKEncryption;
    function GetComp: Boolean;
    function SetAType(const aAType: TSPECKType): ISPECKEncryption;
    function GetAType: TSPECKType;
    function SetKey(const aKey: string): ISPECKEncryption;
    function GetKey: string;
    function SetIV(const aIV: string): ISPECKEncryption;
    function GetIV: string;
    function SetPaddingMode(const aPaddingMode: TPaddingMode): ISPECKEncryption;
    function GetPaddingMode: TPaddingMode;
    function SetIVMode(const aIVMode: TIVMode): ISPECKEncryption;
    function GetIVMode: TIVMode;
    function SetInputFormat(const aInputFormat: TConvertType): ISPECKEncryption;
    function GetInputFormat: TConvertType;
    function SetOutputFormat(const aOutputFormat: TConvertType): ISPECKEncryption;
    function GetOutputFormat: TConvertType;
    function SetUnicode(const aUnicode: TUnicode): ISPECKEncryption;
    function GetUnicode: TUnicode;
    function SetProgress(const aProgress: Integer): ISPECKEncryption;
    function GetProgress: Integer;
    function SetOnChange(const aOnChange: TNotifyEvent): ISPECKEncryption;
    function GetOnChange: TNotifyEvent;

    function Encrypt(s: string): string;
    function Decrypt(s: string): string;
    procedure EncryptFileW(s: string; o: string);
    procedure DecryptFileW(s: string; o: string);
    procedure EncryptStream(s: TStream; var o: TStream);
    procedure DecryptStream(s: TStream; var o: TStream);
  end;

  TSPECKEncryptionFluent = class(TInterfacedObject, ISPECKEncryption)
  strict private
    FInstance: TSPECKEncryption;
    FAutoFree: Boolean;
  public
    constructor Create(AInstance: TSPECKEncryption; AAutoFree: Boolean = False);
    destructor Destroy; override;
    /// Var olan bir örneği sarar. Ömür ÇAĞIRANIN sorumluluğundadır.
    class function New(AInstance: TSPECKEncryption; AAutoFree: Boolean = False): ISPECKEncryption; overload;
    /// Örneği KENDİSİ yaratır ve SAHİPLENİR — arayüz serbest kalınca free eder.
    class function New: ISPECKEncryption; overload;
    function AsInstance: TSPECKEncryption;

    function SetComp(const aComp: Boolean): ISPECKEncryption;
    function GetComp: Boolean;
    function SetAType(const aAType: TSPECKType): ISPECKEncryption;
    function GetAType: TSPECKType;
    function SetKey(const aKey: string): ISPECKEncryption;
    function GetKey: string;
    function SetIV(const aIV: string): ISPECKEncryption;
    function GetIV: string;
    function SetPaddingMode(const aPaddingMode: TPaddingMode): ISPECKEncryption;
    function GetPaddingMode: TPaddingMode;
    function SetIVMode(const aIVMode: TIVMode): ISPECKEncryption;
    function GetIVMode: TIVMode;
    function SetInputFormat(const aInputFormat: TConvertType): ISPECKEncryption;
    function GetInputFormat: TConvertType;
    function SetOutputFormat(const aOutputFormat: TConvertType): ISPECKEncryption;
    function GetOutputFormat: TConvertType;
    function SetUnicode(const aUnicode: TUnicode): ISPECKEncryption;
    function GetUnicode: TUnicode;
    function SetProgress(const aProgress: Integer): ISPECKEncryption;
    function GetProgress: Integer;
    function SetOnChange(const aOnChange: TNotifyEvent): ISPECKEncryption;
    function GetOnChange: TNotifyEvent;

    function Encrypt(s: string): string;
    function Decrypt(s: string): string;
    procedure EncryptFileW(s: string; o: string);
    procedure DecryptFileW(s: string; o: string);
    procedure EncryptStream(s: TStream; var o: TStream);
    procedure DecryptStream(s: TStream; var o: TStream);
  end;
{$ENDREGION}

implementation


{$REGION 'RAD-FLUENT:TConvert:IMPL — ÜRETİLMİŞTİR; bu bloğu elle düzenleme, yeniden üretimde kaybolur'}
constructor TConvertFluent.Create(AInstance: TConvert; AAutoFree: Boolean = False);
begin
  inherited Create;
  FInstance := AInstance;
  FAutoFree := AAutoFree;
end;

destructor TConvertFluent.Destroy;
begin
  if FAutoFree then
    FInstance.Free;
  inherited;
end;

class function TConvertFluent.New(AInstance: TConvert; AAutoFree: Boolean = False): IConvert;
begin
  Result := TConvertFluent.Create(AInstance, AAutoFree);
end;

class function TConvertFluent.New: IConvert;
begin
  Result := TConvertFluent.Create(TConvert.Create(nil), True);
end;

function TConvertFluent.AsInstance: TConvert;
begin
  Result := FInstance;
end;

function TConvertFluent.SetAType(const aAType: TConvertType): IConvert;
begin
  FInstance.AType := aAType;
  Result := Self;
end;

function TConvertFluent.GetAType: TConvertType;
begin
  Result := FInstance.AType;
end;

function TConvertFluent.CharToFormat(charstring: string): string;
begin
  Result := FInstance.CharToFormat(charstring);
end;

function TConvertFluent.FormatToChar(str: string): string;
begin
  Result := FInstance.FormatToChar(str);
end;

function TConvertFluent.UnicodeToPAnsiChar(str: string): PAnsiChar;
begin
  Result := FInstance.UnicodeToPAnsiChar(str);
end;

function TConvertFluent.PAnsiCharFromUnicodeLength(str: string): Integer;
begin
  Result := FInstance.PAnsiCharFromUnicodeLength(str);
end;

function TConvertFluent.StringToBuffer(str: string; u: TUnicode; var msgLen: Integer): PAnsiChar;
begin
  Result := FInstance.StringToBuffer(str, u, msgLen);
end;

function TConvertFluent.StringToBufferA(str: string; u: TUnicode): PAnsiChar;
begin
  Result := FInstance.StringToBufferA(str, u);
end;

function TConvertFluent.StringToPAnsiChar(str: string): PAnsiChar;
begin
  Result := FInstance.StringToPAnsiChar(str);
end;

function TConvertFluent.UnicodeStringToFormat(str: string): string;
begin
  Result := FInstance.UnicodeStringToFormat(str);
end;

function TConvertFluent.FormatToUnicodeString(str: string): string;
begin
  Result := FInstance.FormatToUnicodeString(str);
end;

function TConvertFluent.StringToByteArray(str: string): TArray<System.Byte>;
begin
  Result := FInstance.StringToByteArray(str);
end;

function TConvertFluent.ByteArrayToString(aob: array of Byte): string;
begin
  Result := FInstance.ByteArrayToString(aob);
end;

function TConvertFluent.TestUnicode(str: string): Integer;
begin
  Result := FInstance.TestUnicode(str);
end;

function TConvertFluent.StringToUnicode(str: string): string;
begin
  Result := FInstance.StringToUnicode(str);
end;

function TConvertFluent.BMPStringToUnicode(const S: string): string;
begin
  Result := FInstance.BMPStringToUnicode(S);
end;

function TConvertFluent.StringToFormat(charstring: string): string;
begin
  Result := FInstance.StringToFormat(charstring);
end;

function TConvertFluent.FormatToString(str: string): string;
begin
  Result := FInstance.FormatToString(str);
end;

function TConvertFluent.OutputFormatLength(charlen: Integer): Integer;
begin
  Result := FInstance.OutputFormatLength(charlen);
end;

function TConvertFluent.CharLength(charstring: string): Integer;
begin
  Result := FInstance.CharLength(charstring);
end;

function TConvertFluent.Base64ToHexa(base64String: string): string;
begin
  Result := FInstance.Base64ToHexa(base64String);
end;

function TConvertFluent.HexaToBase64(hexaString: string): string;
begin
  Result := FInstance.HexaToBase64(hexaString);
end;

function TConvertFluent.Base64ToBase64url(inString: string): string;
begin
  Result := FInstance.Base64ToBase64url(inString);
end;

function TConvertFluent.Base64urlToBase64(inString: string): string;
begin
  Result := FInstance.Base64urlToBase64(inString);
end;

function TConvertFluent.Base64urlToHexa(inString: string): string;
begin
  Result := FInstance.Base64urlToHexa(inString);
end;

function TConvertFluent.HexaToBase64url(inString: string): string;
begin
  Result := FInstance.HexaToBase64url(inString);
end;

function TConvertFluent.Base32ToHexa(base32String: string): string;
begin
  Result := FInstance.Base32ToHexa(base32String);
end;

function TConvertFluent.HexaToBase32(hexaString: string): string;
begin
  Result := FInstance.HexaToBase32(hexaString);
end;

function TConvertFluent.Base32ToBase64url(inString: string): string;
begin
  Result := FInstance.Base32ToBase64url(inString);
end;

function TConvertFluent.Base64urlToBase32(inString: string): string;
begin
  Result := FInstance.Base64urlToBase32(inString);
end;

function TConvertFluent.Base32ToBase64(inString: string): string;
begin
  Result := FInstance.Base32ToBase64(inString);
end;

function TConvertFluent.Base64ToBase32(inString: string): string;
begin
  Result := FInstance.Base64ToBase32(inString);
end;

function TConvertFluent.KeyRSAOpenSSLToKeyTRSAEncSign(strKey: string): string;
begin
  Result := FInstance.KeyRSAOpenSSLToKeyTRSAEncSign(strKey);
end;

function TConvertFluent.KeyTRSAEncSignToKeyRSAOpenSSL(strKey: string): string;
begin
  Result := FInstance.KeyTRSAEncSignToKeyRSAOpenSSL(strKey);
end;

function TConvertFluent.Base58Encode(const value: UInt64): string;
begin
  Result := FInstance.Base58Encode(value);
end;

function TConvertFluent.Base58Decode(const encoded: string): UInt64;
begin
  Result := FInstance.Base58Decode(encoded);
end;

function TConvertFluent.TBytesToString(const t: TArray<System.Byte>): string;
begin
  Result := FInstance.TBytesToString(t);
end;

function TConvertFluent.StringToTBytes(const str: string): TArray<System.Byte>;
begin
  Result := FInstance.StringToTBytes(str);
end;

function TConvertFluent.RandomString(len: Integer): string;
begin
  Result := FInstance.RandomString(len);
end;

procedure TConvertFluent.ToCharString(InHexString: string; var OutCharString: string);
begin
  FInstance.ToCharString(InHexString, OutCharString);
end;

procedure TConvertFluent.ToCharString(InHexString: string; var OutCharArray: TArray<System.Byte>);
begin
  FInstance.ToCharString(InHexString, OutCharArray);
end;

function TConvertFluent.ToCharString(InHexString: string): string;
begin
  Result := FInstance.ToCharString(InHexString);
end;

procedure TConvertFluent.ToHexString(InCharString: string; var OutHexString: string);
begin
  FInstance.ToHexString(InCharString, OutHexString);
end;

procedure TConvertFluent.ToHexString(InCharString: string; var OutHexArray: TArray<System.Byte>);
begin
  FInstance.ToHexString(InCharString, OutHexArray);
end;

function TConvertFluent.ToHexString(InCharString: string): string;
begin
  Result := FInstance.ToHexString(InCharString);
end;

function TConvertFluent.StringToCodePoints(const s: string): TArray<System.Integer>;
begin
  Result := FInstance.StringToCodePoints(s);
end;

function TConvertFluent.CodePointsToString(const Codes: TArray<System.Integer>): string;
begin
  Result := FInstance.CodePointsToString(Codes);
end;

function TConvertFluent.StringToCHexList(const S: string): string;
begin
  Result := FInstance.StringToCHexList(S);
end;

function TConvertFluent.TBytesToHexString(const Bytes: TArray<System.Byte>): string;
begin
  Result := FInstance.TBytesToHexString(Bytes);
end;

function TConvertFluent.TBytesToBase64(const Bytes: TArray<System.Byte>): string;
begin
  Result := FInstance.TBytesToBase64(Bytes);
end;

procedure TConvertFluent.ToBase32String(InCharString: string; var Base32String: string);
begin
  FInstance.ToBase32String(InCharString, Base32String);
end;

procedure TConvertFluent.ToBase64String(InCharString: string; var Base64String: string);
begin
  FInstance.ToBase64String(InCharString, Base64String);
end;

procedure TConvertFluent.ToBase64urlString(InCharString: string; var Base64String: string);
begin
  FInstance.ToBase64urlString(InCharString, Base64String);
end;

procedure TConvertFluent.ToStrictBase64urlString(InCharString: string; var Base64String: string);
begin
  FInstance.ToStrictBase64urlString(InCharString, Base64String);
end;

procedure TConvertFluent.Base32ToChar(Base32String: string; var OutCharString: string);
begin
  FInstance.Base32ToChar(Base32String, OutCharString);
end;

procedure TConvertFluent.Base64ToChar(Base64String: string; var OutCharString: string);
begin
  FInstance.Base64ToChar(Base64String, OutCharString);
end;

procedure TConvertFluent.Base64urlToChar(Base64UrlString: string; var OutCharString: string);
begin
  FInstance.Base64urlToChar(Base64UrlString, OutCharString);
end;

procedure TConvertFluent.FormatBeforeConvert(InCharString: string; var OutCharStringString: string);
begin
  FInstance.FormatBeforeConvert(InCharString, OutCharStringString);
end;

function TConvertFluent.FormatBeforeConvert(InCharString: string; aType: TConvertType): string;
begin
  Result := FInstance.FormatBeforeConvert(InCharString, aType);
end;

function TConvertFluent.StringToByteArray(str: string; u: TUnicode): TArray<System.Byte>;
begin
  Result := FInstance.StringToByteArray(str, u);
end;

function TConvertFluent.UnicodeToByteArray(str: string): TArray<System.Byte>;
begin
  Result := FInstance.UnicodeToByteArray(str);
end;

function TConvertFluent.BigHexToBigInt(s: string): string;
begin
  Result := FInstance.BigHexToBigInt(s);
end;

function TConvertFluent.Add(x: string; y: string): string;
begin
  Result := FInstance.Add(x, y);
end;

function TConvertFluent.HexToInt(a: Char): Integer;
begin
  Result := FInstance.HexToInt(a);
end;

function TConvertFluent.Reverse(inString: string): string;
begin
  Result := FInstance.Reverse(inString);
end;

function TConvertFluent.ToUtf8(s: string): string;
begin
  Result := FInstance.ToUtf8(s);
end;

{$ENDREGION}

{$REGION 'RAD-FLUENT:TAESEncryption:IMPL — ÜRETİLMİŞTİR; bu bloğu elle düzenleme, yeniden üretimde kaybolur'}
constructor TAESEncryptionFluent.Create(AInstance: TAESEncryption; AAutoFree: Boolean = False);
begin
  inherited Create;
  FInstance := AInstance;
  FAutoFree := AAutoFree;
end;

destructor TAESEncryptionFluent.Destroy;
begin
  if FAutoFree then
    FInstance.Free;
  inherited;
end;

class function TAESEncryptionFluent.New(AInstance: TAESEncryption; AAutoFree: Boolean = False): IAESEncryption;
begin
  Result := TAESEncryptionFluent.Create(AInstance, AAutoFree);
end;

class function TAESEncryptionFluent.New: IAESEncryption;
begin
  Result := TAESEncryptionFluent.Create(TAESEncryption.Create(nil), True);
end;

function TAESEncryptionFluent.AsInstance: TAESEncryption;
begin
  Result := FInstance;
end;

function TAESEncryptionFluent.SetKey(const aKey: string): IAESEncryption;
begin
  FInstance.key := aKey;
  Result := Self;
end;

function TAESEncryptionFluent.GetKey: string;
begin
  Result := FInstance.key;
end;

function TAESEncryptionFluent.SetAType(const aAType: TAESType): IAESEncryption;
begin
  FInstance.AType := aAType;
  Result := Self;
end;

function TAESEncryptionFluent.GetAType: TAESType;
begin
  Result := FInstance.AType;
end;

function TAESEncryptionFluent.SetInputFormat(const aInputFormat: TConvertType): IAESEncryption;
begin
  FInstance.inputFormat := aInputFormat;
  Result := Self;
end;

function TAESEncryptionFluent.GetInputFormat: TConvertType;
begin
  Result := FInstance.inputFormat;
end;

function TAESEncryptionFluent.SetOutputFormat(const aOutputFormat: TConvertType): IAESEncryption;
begin
  FInstance.outputFormat := aOutputFormat;
  Result := Self;
end;

function TAESEncryptionFluent.GetOutputFormat: TConvertType;
begin
  Result := FInstance.outputFormat;
end;

function TAESEncryptionFluent.SetIVMode(const aIVMode: TIVMode): IAESEncryption;
begin
  FInstance.IVMode := aIVMode;
  Result := Self;
end;

function TAESEncryptionFluent.GetIVMode: TIVMode;
begin
  Result := FInstance.IVMode;
end;

function TAESEncryptionFluent.SetIV(const aIV: string): IAESEncryption;
begin
  FInstance.IV := aIV;
  Result := Self;
end;

function TAESEncryptionFluent.GetIV: string;
begin
  Result := FInstance.IV;
end;

function TAESEncryptionFluent.SetPaddingMode(const aPaddingMode: TPaddingMode): IAESEncryption;
begin
  FInstance.paddingMode := aPaddingMode;
  Result := Self;
end;

function TAESEncryptionFluent.GetPaddingMode: TPaddingMode;
begin
  Result := FInstance.paddingMode;
end;

function TAESEncryptionFluent.SetUnicode(const aUnicode: TUnicode): IAESEncryption;
begin
  FInstance.Unicode := aUnicode;
  Result := Self;
end;

function TAESEncryptionFluent.GetUnicode: TUnicode;
begin
  Result := FInstance.Unicode;
end;

function TAESEncryptionFluent.SetEndian(const aEndian: TEndian): IAESEncryption;
begin
  FInstance.Endian := aEndian;
  Result := Self;
end;

function TAESEncryptionFluent.GetEndian: TEndian;
begin
  Result := FInstance.Endian;
end;

function TAESEncryptionFluent.SetProgress(const aProgress: Integer): IAESEncryption;
begin
  FInstance.Progress := aProgress;
  Result := Self;
end;

function TAESEncryptionFluent.GetProgress: Integer;
begin
  Result := FInstance.Progress;
end;

function TAESEncryptionFluent.SetOnChange(const aOnChange: TNotifyEvent): IAESEncryption;
begin
  FInstance.OnChange := aOnChange;
  Result := Self;
end;

function TAESEncryptionFluent.GetOnChange: TNotifyEvent;
begin
  Result := FInstance.OnChange;
end;

function TAESEncryptionFluent.SetKeyLength(const aKeyLength: TAESKeyLength): IAESEncryption;
begin
  FInstance.keyLength := aKeyLength;
  Result := Self;
end;

function TAESEncryptionFluent.GetKeyLength: TAESKeyLength;
begin
  Result := FInstance.keyLength;
end;

function TAESEncryptionFluent.Encrypt(s: string): string;
begin
  Result := FInstance.Encrypt(s);
end;

function TAESEncryptionFluent.Decrypt(s: string): string;
begin
  Result := FInstance.Decrypt(s);
end;

function TAESEncryptionFluent.Decrypt(s: string; var o: string): Integer;
begin
  Result := FInstance.Decrypt(s, o);
end;

procedure TAESEncryptionFluent.EncryptFileW(s: string; o: string);
begin
  FInstance.EncryptFileW(s, o);
end;

function TAESEncryptionFluent.DecryptFileW(s: string; o: string): Integer;
begin
  Result := FInstance.DecryptFileW(s, o);
end;

procedure TAESEncryptionFluent.EncryptStream(s: TStream; o: TStream);
begin
  FInstance.EncryptStream(s, o);
end;

procedure TAESEncryptionFluent.DecryptStream(s: TStream; o: TStream);
begin
  FInstance.DecryptStream(s, o);
end;

function TAESEncryptionFluent.DecryptStream2(s: TStream; o: TStream): Integer;
begin
  Result := FInstance.DecryptStream2(s, o);
end;

{$ENDREGION}

{$REGION 'RAD-FLUENT:TSalsaEncryption:IMPL — ÜRETİLMİŞTİR; bu bloğu elle düzenleme, yeniden üretimde kaybolur'}
constructor TSalsaEncryptionFluent.Create(AInstance: TSalsaEncryption; AAutoFree: Boolean = False);
begin
  inherited Create;
  FInstance := AInstance;
  FAutoFree := AAutoFree;
end;

destructor TSalsaEncryptionFluent.Destroy;
begin
  if FAutoFree then
    FInstance.Free;
  inherited;
end;

class function TSalsaEncryptionFluent.New(AInstance: TSalsaEncryption; AAutoFree: Boolean = False): ISalsaEncryption;
begin
  Result := TSalsaEncryptionFluent.Create(AInstance, AAutoFree);
end;

class function TSalsaEncryptionFluent.New: ISalsaEncryption;
begin
  Result := TSalsaEncryptionFluent.Create(TSalsaEncryption.Create(nil), True);
end;

function TSalsaEncryptionFluent.AsInstance: TSalsaEncryption;
begin
  Result := FInstance;
end;

function TSalsaEncryptionFluent.SetKeyLength(const aKeyLength: TSalsaKeyLength): ISalsaEncryption;
begin
  FInstance.keyLength := aKeyLength;
  Result := Self;
end;

function TSalsaEncryptionFluent.GetKeyLength: TSalsaKeyLength;
begin
  Result := FInstance.keyLength;
end;

function TSalsaEncryptionFluent.SetKey(const aKey: string): ISalsaEncryption;
begin
  FInstance.key := aKey;
  Result := Self;
end;

function TSalsaEncryptionFluent.GetKey: string;
begin
  Result := FInstance.key;
end;

function TSalsaEncryptionFluent.SetInputFormat(const aInputFormat: TConvertType): ISalsaEncryption;
begin
  FInstance.inputFormat := aInputFormat;
  Result := Self;
end;

function TSalsaEncryptionFluent.GetInputFormat: TConvertType;
begin
  Result := FInstance.inputFormat;
end;

function TSalsaEncryptionFluent.SetOutputFormat(const aOutputFormat: TConvertType): ISalsaEncryption;
begin
  FInstance.outputFormat := aOutputFormat;
  Result := Self;
end;

function TSalsaEncryptionFluent.GetOutputFormat: TConvertType;
begin
  Result := FInstance.outputFormat;
end;

function TSalsaEncryptionFluent.SetUnicode(const aUnicode: TUnicode): ISalsaEncryption;
begin
  FInstance.Unicode := aUnicode;
  Result := Self;
end;

function TSalsaEncryptionFluent.GetUnicode: TUnicode;
begin
  Result := FInstance.Unicode;
end;

function TSalsaEncryptionFluent.SetIV(const aIV: string): ISalsaEncryption;
begin
  FInstance.IV := aIV;
  Result := Self;
end;

function TSalsaEncryptionFluent.GetIV: string;
begin
  Result := FInstance.IV;
end;

function TSalsaEncryptionFluent.SetProgress(const aProgress: Integer): ISalsaEncryption;
begin
  FInstance.Progress := aProgress;
  Result := Self;
end;

function TSalsaEncryptionFluent.GetProgress: Integer;
begin
  Result := FInstance.Progress;
end;

function TSalsaEncryptionFluent.SetOnChange(const aOnChange: TNotifyEvent): ISalsaEncryption;
begin
  FInstance.OnChange := aOnChange;
  Result := Self;
end;

function TSalsaEncryptionFluent.GetOnChange: TNotifyEvent;
begin
  Result := FInstance.OnChange;
end;

function TSalsaEncryptionFluent.Encrypt(s: string): string;
begin
  Result := FInstance.Encrypt(s);
end;

function TSalsaEncryptionFluent.Decrypt(s: string): string;
begin
  Result := FInstance.Decrypt(s);
end;

procedure TSalsaEncryptionFluent.EncryptFile(s: string; o: string);
begin
  FInstance.EncryptFile(s, o);
end;

procedure TSalsaEncryptionFluent.DecryptFile(s: string; o: string);
begin
  FInstance.DecryptFile(s, o);
end;

procedure TSalsaEncryptionFluent.EncryptStream(s: TStream; o: TStream);
begin
  FInstance.EncryptStream(s, o);
end;

procedure TSalsaEncryptionFluent.DecryptStream(s: TStream; o: TStream);
begin
  FInstance.DecryptStream(s, o);
end;

{$ENDREGION}

{$REGION 'RAD-FLUENT:TSPECKEncryption:IMPL — ÜRETİLMİŞTİR; bu bloğu elle düzenleme, yeniden üretimde kaybolur'}
constructor TSPECKEncryptionFluent.Create(AInstance: TSPECKEncryption; AAutoFree: Boolean = False);
begin
  inherited Create;
  FInstance := AInstance;
  FAutoFree := AAutoFree;
end;

destructor TSPECKEncryptionFluent.Destroy;
begin
  if FAutoFree then
    FInstance.Free;
  inherited;
end;

class function TSPECKEncryptionFluent.New(AInstance: TSPECKEncryption; AAutoFree: Boolean = False): ISPECKEncryption;
begin
  Result := TSPECKEncryptionFluent.Create(AInstance, AAutoFree);
end;

class function TSPECKEncryptionFluent.New: ISPECKEncryption;
begin
  Result := TSPECKEncryptionFluent.Create(TSPECKEncryption.Create(nil), True);
end;

function TSPECKEncryptionFluent.AsInstance: TSPECKEncryption;
begin
  Result := FInstance;
end;

function TSPECKEncryptionFluent.SetComp(const aComp: Boolean): ISPECKEncryption;
begin
  FInstance.Comp := aComp;
  Result := Self;
end;

function TSPECKEncryptionFluent.GetComp: Boolean;
begin
  Result := FInstance.Comp;
end;

function TSPECKEncryptionFluent.SetAType(const aAType: TSPECKType): ISPECKEncryption;
begin
  FInstance.AType := aAType;
  Result := Self;
end;

function TSPECKEncryptionFluent.GetAType: TSPECKType;
begin
  Result := FInstance.AType;
end;

function TSPECKEncryptionFluent.SetKey(const aKey: string): ISPECKEncryption;
begin
  FInstance.Key := aKey;
  Result := Self;
end;

function TSPECKEncryptionFluent.GetKey: string;
begin
  Result := FInstance.Key;
end;

function TSPECKEncryptionFluent.SetIV(const aIV: string): ISPECKEncryption;
begin
  FInstance.IV := aIV;
  Result := Self;
end;

function TSPECKEncryptionFluent.GetIV: string;
begin
  Result := FInstance.IV;
end;

function TSPECKEncryptionFluent.SetPaddingMode(const aPaddingMode: TPaddingMode): ISPECKEncryption;
begin
  FInstance.PaddingMode := aPaddingMode;
  Result := Self;
end;

function TSPECKEncryptionFluent.GetPaddingMode: TPaddingMode;
begin
  Result := FInstance.PaddingMode;
end;

function TSPECKEncryptionFluent.SetIVMode(const aIVMode: TIVMode): ISPECKEncryption;
begin
  FInstance.IVMode := aIVMode;
  Result := Self;
end;

function TSPECKEncryptionFluent.GetIVMode: TIVMode;
begin
  Result := FInstance.IVMode;
end;

function TSPECKEncryptionFluent.SetInputFormat(const aInputFormat: TConvertType): ISPECKEncryption;
begin
  FInstance.InputFormat := aInputFormat;
  Result := Self;
end;

function TSPECKEncryptionFluent.GetInputFormat: TConvertType;
begin
  Result := FInstance.InputFormat;
end;

function TSPECKEncryptionFluent.SetOutputFormat(const aOutputFormat: TConvertType): ISPECKEncryption;
begin
  FInstance.OutputFormat := aOutputFormat;
  Result := Self;
end;

function TSPECKEncryptionFluent.GetOutputFormat: TConvertType;
begin
  Result := FInstance.OutputFormat;
end;

function TSPECKEncryptionFluent.SetUnicode(const aUnicode: TUnicode): ISPECKEncryption;
begin
  FInstance.Unicode := aUnicode;
  Result := Self;
end;

function TSPECKEncryptionFluent.GetUnicode: TUnicode;
begin
  Result := FInstance.Unicode;
end;

function TSPECKEncryptionFluent.SetProgress(const aProgress: Integer): ISPECKEncryption;
begin
  FInstance.Progress := aProgress;
  Result := Self;
end;

function TSPECKEncryptionFluent.GetProgress: Integer;
begin
  Result := FInstance.Progress;
end;

function TSPECKEncryptionFluent.SetOnChange(const aOnChange: TNotifyEvent): ISPECKEncryption;
begin
  FInstance.OnChange := aOnChange;
  Result := Self;
end;

function TSPECKEncryptionFluent.GetOnChange: TNotifyEvent;
begin
  Result := FInstance.OnChange;
end;

function TSPECKEncryptionFluent.Encrypt(s: string): string;
begin
  Result := FInstance.Encrypt(s);
end;

function TSPECKEncryptionFluent.Decrypt(s: string): string;
begin
  Result := FInstance.Decrypt(s);
end;

procedure TSPECKEncryptionFluent.EncryptFileW(s: string; o: string);
begin
  FInstance.EncryptFileW(s, o);
end;

procedure TSPECKEncryptionFluent.DecryptFileW(s: string; o: string);
begin
  FInstance.DecryptFileW(s, o);
end;

procedure TSPECKEncryptionFluent.EncryptStream(s: TStream; var o: TStream);
begin
  FInstance.EncryptStream(s, o);
end;

procedure TSPECKEncryptionFluent.DecryptStream(s: TStream; var o: TStream);
begin
  FInstance.DecryptStream(s, o);
end;

{$ENDREGION}

end.
