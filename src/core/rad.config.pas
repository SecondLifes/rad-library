unit rad.config;

(*
  RAD Library — AYAR BİRİMİ.

  Yığındaki yeri: rad.core (taban tipler, kilit) ve rad.cipher (şifreleme)
  ÜSTÜNDE durur. Ortak istisna atası ERadCore rad.core'dan gelir — burada
  ikinci bir tanımı YOKTUR, olsaydı tek `except on E: ERadCore` bloğu iki
  ayrı ağacı yakalayamazdı.

  Bağımlılıklar: RTL + mORMot2 + rad.core + rad.cipher. mORMot bu kütüphanenin
  TEMEL bağımlılığıdır (opsiyonel bir vendor değil) — src/core'daki diğer
  birimler de öyle kullanır.

  ---------------------------------------------------------------------------
  ŞİFRELEME (isteğe bağlı)
  ---------------------------------------------------------------------------
  Kurucu bir IRadCipher (anahtar malzemesi) ve bir TRadCryptMode (nasıl
  uygulanacağı) alır. Anahtar verilmezse mod zorla rcmNone'a düşer.

  rcmFile (VARSAYILAN) — bütün dosya tek zarfa sarılır:

    { "data": { "enc": "<base64url>", "alg": "aes-gcm-256", "v": 1 } }

  Bölüm adları bile görünmez.

  rcmSection — yalnızca Encrypted = True dönen bölümler. Dosya okunabilir
  kalır, bölüm adları görünür, o bölümlerin İÇERİĞİ gizlenir:

    {
      "Log":        { "Path": "D:\\loglar" },
      "Veritabani": "RADSEC1:aes-gcm-256:<base64url>"
    }

  Şifreli bölümün değeri nesne değil METİNDİR. INI'de aynı şey tek anahtarlı
  bir blok olur ([Veritabani] altında enc=...). Yük her üç biçimde de bölümün
  JSON'udur, böylece tek bir çözme yolu vardır.

  Hangisi ne zaman: sırlar dosyanın küçük bir kısmındaysa ve dosyanın geri
  kalanının elle okunabilir/düzenlenebilir kalması isteniyorsa rcmSection;
  dosyanın tamamı hassassa ya da hangi bölümlerin var olduğu bile bilgi
  sızdırıyorsa rcmFile.

  Dosya her iki modda da kendi biçiminde (JSON/INI/YAML) geçerli kalır ve
  uzantı değişmez. base64url seçilmesi tesadüf değil: JSON'da kaçış, INI'de
  değer ayrıştırma sorunu çıkarmayan bir alfabe kullanır.

  İKİ İNCE NOKTA:

  1) "Değişmediyse yazma" karşılaştırması DÜZ METİN üzerinden yapılır.
     Şifreleme her kayıtta rastgele IV kullandığı için şifreli çıktı hep
     farklıdır; hash'i onun üzerinden alsaydık optimizasyon tamamen ölürdü.

  2) Şifreleme, serileştirmeden SONRA ve ayrı bir adımdır. Bölüm kilitleri
     ileride Serialize'i sarmalarsa, crypto o kilidin DIŞINDA kalmalıdır —
     yavaş bir işlemi kilit altında tutmak okurları gereksiz bekletir.

  Şifrelemenin ne olduğu ve ne OLMADIĞI için rad.cipher birim başlığını oku:
  anahtar uygulamada gömülü olduğunda bu bir at-rest gizlemedir, tam anlamıyla
  şifreleme değil.

  ---------------------------------------------------------------------------
  AYAR SİSTEMİ (TRadOptions / TRadOptionsFile)
  ---------------------------------------------------------------------------
  Tek dosyada N adet ADLANDIRILMIŞ ayar bölümü. Her bölüm kendi sınıfıdır;
  dosyada kendi adıyla bir düğüm olarak durur:

    {
      "Logging":       { "Path": "C:\\", "Verbose": true },
      "GlobalOptions": { "StartMinimized": true }
    }

  Kullanım:

    LCfg := TRadOptionsFile.Create('.\ayarlar.json');
    try
      LCfg.Section<TLoggingOptions>('Logging');

      LCfg.Configure<TGlobalOptions>(
        procedure(o: TGlobalOptions)
        begin
          o.StartMinimized := True;
          o.Servers := ['Bir', 'Iki'];
        end, 'GlobalOptions');

      LCfg.Section<TUIOptions>;              // ad sınıftan: UIOptions

      LCfg.Load;                             // dosya yoksa oluşturur
      LLog := LCfg.Get<TLoggingOptions>;
      LLog.Path := 'D:\loglar';
      LCfg.Save;                             // değişmediyse diske DOKUNMAZ
    finally
      LCfg.Free;
    end;

  DEĞER ÖNCELİĞİ (soldan sağa, sağdaki kazanır):

      DefaultValues   ->   Configure   ->   dosyadaki değer

  DefaultValues bölüm YARATILIRKEN bir kez uygulanır, Load sırasında değil —
  aksi hâlde Configure ile verdiğin değerleri ezerdi. Dosyada bölüm yoksa
  bellekteki hâl (DefaultValues + Configure) korunur ve dosyaya yazılır.

  BİÇİM: uzantıdan seçilir — .json / .ini / .yaml|.yml. Üçü de mORMot'un kendi
  dönüştürücüleriyle yapılır (ObjectToJson/JsonToObject, ObjectToIni/IniToObject,
  YamlToJson/JsonToYaml), yani ini ve yaml desteği ek kod istemez.

  TSynJsonFileSettings'ten TÜRETİLMEDİ — BİLİNÇLİ: o sınıf TEK bir nesnenin
  published property'lerini dosyaya bağlar, bölümler ise çalışma zamanında
  eklenir; published property olarak ifade edilemezler. Onun sağladığı asıl
  değerler (biçim tespiti, "değişmediyse yazma") burada doğrudan mORMot
  fonksiyonlarıyla ve bir crc32c karşılaştırmasıyla yeniden kuruldu.
*)

interface

uses
  System.SysUtils,
  System.Classes,
  System.TypInfo,
  System.Generics.Collections,
  System.IOUtils,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,        // MoveFileEx — atomik, üzerine yazan taşıma
  {$ENDIF}
  mormot.core.base,      // RawUtf8, crc32c
  mormot.core.unicode,   // StringToUtf8 / Utf8ToString
  mormot.core.text,      // ObjectToJson
  mormot.core.buffers,   // BinToBase64uri / Base64uriToBin
  mormot.core.json,      // JsonToObject, IsValidJson, JsonReformat, JsonEncode
  mormot.core.rtti,
  mormot.core.variants,  // IDocDict / DocDict / _ObjFast
  mormot.core.fmt,       // ObjectToIni / IniToObject / YamlToJson / FindIniEntry
  rad.core,              // ERadCore
  rad.cipher;            // IRadCipher

type
  { ========================================================================
    Hata hiyerarşisi — tek except bloğuyla hepsi yakalanabilsin diye ortak ata
    ======================================================================== }
  // ERadCore rad.core'dan gelir — burada YENİDEN TANIMLANMAZ. İki ayrı
  // ERadCore olsaydı tek bir `except on E: ERadCore` bloğu ikisini birden
  // yakalayamaz, hangisinin yakalandığı uses sırasına kalırdı.
  ERadOptions           = class(ERadCore);
  /// İstenen bölüm kayıtlı değil / iki kez farklı sınıfla eklenmiş.
  ERadOptionsSection    = class(ERadOptions);
  /// Dosya okunamadı, biçim tanınmadı, ayrıştırılamadı.
  ERadOptionsLoad       = class(ERadOptions);
  /// Şifreli dosya çözülemedi: anahtar yok/yanlış, zarf sürümü ya da
  /// algoritması uyuşmuyor, veri kurcalanmış.
  ERadOptionsDecrypt    = class(ERadOptionsLoad);
  /// Dosya yazılamadı.
  ERadOptionsSave       = class(ERadOptions);
  /// Bölümün kendi Validate'i reddetti.
  ERadOptionsValidation = class(ERadOptions);

const
  { Şifreleme zarfının sabit anahtarları. Değiştirmek DOSYA BİÇİMİNİ bozar —
    eski dosyalar okunamaz hale gelir. }
  CRadEnvSection = 'data';
  CRadEnvEnc     = 'enc';
  CRadEnvAlg     = 'alg';
  CRadEnvVer     = 'v';
  /// Zarf sürümü. Algoritma veya düzen değişirse ARTIRILIR; çözerken
  /// kontrol edilir, böylece ileride yapılacak bir göç sessiz bozulma
  /// yerine net bir hata verir.
  CRadEnvVersion = 1;

  { Bölüm bazlı şifrelemenin işaretçisi. Bölümün değeri, nesne yerine
    şu biçimde TEK BİR METİN olur:

      RADSEC1:aes-gcm-256:<base64url>

    Üç parça bilerek: sürüm (göç için), algoritma (yanlış anahtarı erken
    yakalamak için) ve veri. base64url alfabesi ':' içermez, o yüzden
    ayrıştırma belirsizliğe düşmez. }
  CRadSecPrefix = 'RADSEC';
  CRadSecVersion = 1;
  CRadSecEnc = 'enc';   // INI'de şifreli bölümün tek anahtarı

type
  /// <summary>Dosyanın nasıl şifreleneceği.</summary>
  TRadCryptMode = (
    /// Şifreleme yok. IRadCipher verilmemişse zorunlu olarak budur.
    rcmNone,
    /// Yalnızca TRadOptions.Encrypted = True olan bölümler şifrelenir.
    /// Dosya okunabilir kalır, bölüm adları görünür, sadece o bölümlerin
    /// İÇERİĞİ gizlenir.
    rcmSection,
    /// Bütün dosya tek zarfa sarılır; bölüm adları da gizlenir.
    /// VARSAYILAN — bölüm bayrakları bu modda dikkate ALINMAZ, çünkü zaten
    /// her şey şifreli; ikisini üst üste uygulamak bedava değil, faydası yok.
    rcmFile);

  { ========================================================================
    Dosya biçimi
    ======================================================================== }
  TRadOptionsFormat = (
    /// Uzantıdan tespit et (.json / .ini / .yaml / .yml). Tanınmazsa JSON.
    rofAuto,
    rofJson,
    rofIni,
    rofYaml);

  { ========================================================================
    TRadOptions — bir ayar bölümünün tabanı

    TSynAutoCreateFields'tan türer: iç içe `published` nesne alanları
    OTOMATİK yaratılır ve yok edilir, elle Create/Free yazılmaz. Bu, JSON
    yüklemesi için de şarttır — ayrıştırıcı alt nesnenin ZATEN var olmasını
    bekler.

    Yalnızca `published` property'ler dosyaya yazılır/okunur.
    ======================================================================== }
  TRadOptions = class(TSynAutoCreateFieldsLocked)
  private
    FSectionName: string;
  public
    /// Bölüm KAYDEDİLİRKEN (Section<T>) bir kez çağrılır — Load sırasında
    /// DEĞİL. Değer önceliği: DefaultValues -> Configure -> dosya.
    /// Varsayılanları constructor yerine burada vermek, sınıfı elle
    /// yaratıp sıfırlamak isteyene de aynı noktayı sunar.
    procedure DefaultValues; virtual;

    /// Yükledikten ve kaydetmeden ÖNCE çağrılır. Geçersizse
    /// ERadOptionsValidation fırlat. Varsayılan: hiçbir şey yapmaz.
    procedure Validate; virtual;

    /// <summary>
    ///   Bu bölüm diske ŞİFRELİ yazılsın mı. Varsayılan: hayır.
    /// </summary>
    /// <remarks>
    ///   Yalnızca dosya rcmSection modundayken dikkate alınır. rcmFile'da
    ///   zaten her şey şifreli, rcmNone'da hiçbir şey.
    ///
    ///   Sınıf düzeyinde (class function) bilerek: "bu sınıf sır taşır"
    ///   bilgisi örneğin değil, TİPİN özelliğidir — sırrı hangi dosyaya
    ///   yazdığına göre değişmez. Bir bölümü şifreli yapmak için:
    ///
    ///     TVeritabaniAyar = class(TRadOptions)
    ///     public
    ///       class function Encrypted: Boolean; override;
    ///     end;
    ///
    ///     class function TVeritabaniAyar.Encrypted: Boolean;
    ///     begin
    ///       Result := True;
    ///     end;
    /// </remarks>
    class function Encrypted: Boolean; virtual;

    /// Dosyadaki düğüm adı. Boş bırakılırsa sınıf adından türetilir
    /// (TLoggingOptions -> LoggingOptions).
    property SectionName: string read FSectionName write FSectionName;
  end;

  TRadOptionsClass = class of TRadOptions;

  TRadConfigureProc<T: TRadOptions> = reference to procedure(AOptions: T);

  { ========================================================================
    TRadOptionsFile — N bölümü tek dosyada tutan kap

    SAHİPLİK: eklenen her bölüm bu nesneye aittir ve Destroy'da yok edilir.
    Dışarıya verilen referansları kap yaşadığı sürece kullan.
    ======================================================================== }
  TRadOptionsFile = class
  strict private
    FSections: TObjectList<TRadOptions>;
    FFileName: string;
    FFormat: TRadOptionsFormat;
    FLastSavedHash: cardinal;
    FLoaded: Boolean;
    FCipher: IRadCipher;
    FCryptMode: TRadCryptMode;
    /// ChangeCipher/RemoveCipher sonrası bir sonraki Save'i MUTLAKA yazdırır.
    /// Ayrı bir bayrak, çünkü FLastSavedHash'i 0'lamak yetmez: 0 geçerli bir
    /// crc32c değeridir ve tesadüfen eşleşebilir.
    FForceNextSave: Boolean;

    function  ResolveFormat: TRadOptionsFormat;
    function  GetEncrypted: Boolean;
    function  WrapEnvelope(const APlain: RawUtf8): RawUtf8;
    function  TryUnwrapEnvelope(const AText: RawUtf8; out APlain: RawUtf8): Boolean;
    /// rcmSection modunda bu bölümün içeriği şifrelenecek mi.
    function  SectionIsEncrypted(ASec: TRadOptions): Boolean;
    /// Bölümün JSON gövdesini "RADSEC1:alg:base64url" işaretine çevirir.
    function  SealSection(const ASectionJson: RawUtf8): RawUtf8;
    /// İşareti tanır ve çözer. İşaret değilse False (düz bölüm).
    function  TryUnsealSection(const AMarker: RawUtf8;
      const ASectionName: string; out ASectionJson: RawUtf8): Boolean;
    function  DefaultNameOf(AClass: TClass): string;
    function  IndexOfSection(const AName: string): Integer;
    function  FindByClass(AClass: TRadOptionsClass; const AName: string): TRadOptions;
    procedure ValidateAll;
    /// AEncryptSections = False iken sifreli bolumler de DUZ yazilir.
    /// "Degismediyse yazma" hash'i bu hâl uzerinden alinir: sifreli cikti
    /// her kayitta rastgele IV yuzunden farklidir, hash'lenemez.
    function  BuildJson(AEncryptSections: Boolean): RawUtf8;
    function  BuildIni(AEncryptSections: Boolean): RawUtf8;
    function  Serialize(AEncryptSections: Boolean): RawUtf8;
    procedure ApplyJson(const AJson: RawUtf8; AFailOnMissing: Boolean);
    procedure ApplyIni(const AIni: RawUtf8; AFailOnMissing: Boolean);
    procedure WriteAtomic(const AText: RawUtf8);
  public
    /// AFileName'in uzantısı biçimi belirler (AFormat = rofAuto iken).
    /// ACipher verilirse dosya bütün olarak şifrelenir; nil ise düz yazılır.
    /// Kurucuda verilir ki kazara ortada değişmesin (ChangeCipher ile açık
    /// ve bilinçli olarak değiştirilebilir).
    /// AMode ile şifrelemenin NASIL uygulanacağı seçilir; ACipher yalnızca
    /// anahtar malzemesidir. ACipher = nil ise mod zorla rcmNone olur.
    constructor Create(const AFileName: string;
      AFormat: TRadOptionsFormat = rofAuto;
      const ACipher: IRadCipher = nil;
      AMode: TRadCryptMode = rcmFile);
    destructor Destroy; override;

    { ---- Bölüm tanımlama ---- }

    /// Bölümü ekler; ZATEN VARSA mevcut olanı döndürür (yeniden yaratmaz).
    /// AName boşsa sınıf adından türetilir (TLoggingOptions -> LoggingOptions).
    function Section<T: TRadOptions, constructor>(const AName: string = ''): T;

    /// Section<T> + hemen ardından AConfigure ile yapılandırır.
    ///
    /// AYRI AD taşır, Section'ın overload'ı DEĞİL: Delphi, açık tip argümanlı
    /// jenerik bir metodun aşırı yüklemelerini satır içi anonim metotla
    /// çözemiyor (E2250 ile doğrulandı). İki ad, derleyiciyle güreşmekten iyi.
    ///
    /// Öncelik: DefaultValues -> Configure -> dosya. Yani buradaki değerler
    /// DefaultValues'ı ezer, dosyadaki değerler de bunları ezer. Dosyada bölüm
    /// yoksa buradaki değerler korunur ve dosyaya yazılır.
    function Configure<T: TRadOptions, constructor>(
      const AConfigure: TRadConfigureProc<T>;
      const AName: string = ''): T;

    { ---- Erişim ---- }

    /// Kayıtlı bölümü döndürür; yoksa ERadOptionsSection.
    function Get<T: TRadOptions>(const AName: string = ''): T;
    /// Exception'sız erişim.
    function TryGet<T: TRadOptions>(out ASection: T;
      const AName: string = ''): Boolean;
    function Has<T: TRadOptions>(const AName: string = ''): Boolean;

    function Count: Integer;
    function SectionNames: TArray<string>;

    { ---- Kalıcılık ---- }

    /// Dosyayı okur ve bölümlere uygular.
    /// - Dosya YOKSA: her bölüme DefaultValues uygulanır ve dosya yazılır.
    /// - Bölüm dosyada yoksa: AFailOnMissing ise ERadOptionsLoad, değilse
    ///   o bölüme DefaultValues uygulanır.
    /// - Yükleme sonrası her bölümün Validate'i çağrılır.
    procedure Load(AFailOnMissing: Boolean = False);

    /// İçerik son yazımdan beri DEĞİŞMEDİYSE diske dokunmaz ve False döner.
    /// Yazım ATOMİKTİR (önce .tmp, sonra üzerine taşıma).
    function Save: Boolean;
    /// Değişmemiş olsa bile yazar.
    function SaveForce: Boolean;

    { ---- Şifreleme ---- }

    /// Şifreleyiciyi değiştirir (anahtar rotasyonu). Bir sonraki Save
    /// içeriği YENİ anahtarla yeniden yazar — değişmemiş olsa bile.
    /// nil KABUL ETMEZ; şifrelemeyi kaldırmak için RemoveCipher kullanın.
    procedure ChangeCipher(const ANew: IRadCipher);

    /// <summary>Şifrelemeyi kapatır.</summary>
    /// <remarks>
    ///   DİKKAT — bu çağrı bir sonraki Save'de dosyayı DÜZ METNE çevirir.
    ///   İçerideki sırlar diskte okunabilir hale gelir. Bilerek ayrı bir
    ///   metot: ChangeCipher(nil) yazımı yanlışlıkla çağrıldığında sessizce
    ///   aynı sonucu doğururdu.
    /// </remarks>
    procedure RemoveCipher;

    property FileName: string read FFileName;
    property Format: TRadOptionsFormat read FFormat;
    property IsLoaded: Boolean read FLoaded;
    /// Herhangi bir şifreleme etkin mi (CryptMode <> rcmNone).
    property Encrypted: Boolean read GetEncrypted;
    /// Şifrelemenin nasıl uygulandığı. Kurucuda belirlenir; ACipher = nil
    /// verilmişse rcmNone'a düşürülmüştür.
    property CryptMode: TRadCryptMode read FCryptMode;
  end;

implementation

{ ============================================================================
  TRadOptions
  ============================================================================ }

procedure TRadOptions.DefaultValues;
begin
  // taban: hiçbir şey
  safe.Init
end;

procedure TRadOptions.Validate;
begin
  // taban: hiçbir şey
end;

{ ============================================================================
  TRadOptionsFile
  ============================================================================ }

constructor TRadOptionsFile.Create(const AFileName: string;
  AFormat: TRadOptionsFormat; const ACipher: IRadCipher; AMode: TRadCryptMode);
begin
  inherited Create;
  if System.SysUtils.Trim(AFileName) = '' then
    raise ERadOptions.Create('TRadOptionsFile: dosya adı boş olamaz.');
  FFileName := AFileName;
  FFormat := AFormat;
  FCipher := ACipher;
  // Anahtar yoksa mod ne istenirse istensin rcmNone'dur. Sessizce düşürüyoruz
  // çünkü alternatifi "şifreleyeceğim" deyip düz yazmak olurdu — Encrypted
  // property'si gerçeği söyler, çağıran isterse kontrol eder.
  if Assigned(ACipher) then
    FCryptMode := AMode
  else
    FCryptMode := rcmNone;
  FSections := TObjectList<TRadOptions>.Create({AOwnsObjects=}True);
end;

class function TRadOptions.Encrypted: Boolean;
begin
  Result := False;   // taban: bölüm düz yazılır
end;

destructor TRadOptionsFile.Destroy;
begin
  FSections.Free;
  inherited;
end;

function TRadOptionsFile.ResolveFormat: TRadOptionsFormat;
var
  LExt: string;
begin
  if FFormat <> rofAuto then
    Exit(FFormat);
  // NİTELENMİŞ: mormot.core.base LowerCase(RawUtf8) aşırı yüklemesi bildiriyor
  // ve niteliksiz çağrı ona gidip sessiz string<->UTF8String dönüşümü yapıyor.
  LExt := System.SysUtils.LowerCase(TPath.GetExtension(FFileName));
  if LExt = '.ini' then
    Result := rofIni
  else if (LExt = '.yaml') or (LExt = '.yml') then
    Result := rofYaml
  else
    Result := rofJson;   // .json ve tanınmayan her şey
end;

/// TLoggingOptions -> LoggingOptions  (baştaki 'T' atılır)
function TRadOptionsFile.DefaultNameOf(AClass: TClass): string;
begin
  Result := AClass.ClassName;
  if (Length(Result) > 1) and (Result[1] = 'T') then
    Delete(Result, 1, 1);
end;

function TRadOptionsFile.IndexOfSection(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FSections.Count - 1 do
    if SameText(FSections[I].SectionName, AName) then
      Exit(I);
  Result := -1;
end;

function TRadOptionsFile.FindByClass(AClass: TRadOptionsClass;
  const AName: string): TRadOptions;
var
  LSec: TRadOptions;
begin
  for LSec in FSections do
    if LSec is AClass then
      // Ad verilmişse ad DA eşleşmeli — aynı sınıftan birden fazla bölüm
      // farklı adlarla yan yana durabilsin diye.
      if (AName = '') or SameText(LSec.SectionName, AName) then
        Exit(LSec);
  Result := nil;
end;

function TRadOptionsFile.Section<T>(const AName: string): T;
var
  LName: string;
  LFound: TRadOptions;
  LNew: T;
begin
  LName := AName;
  if LName = '' then
    LName := DefaultNameOf(T);

  LFound := FindByClass(TRadOptionsClass(T), LName);
  if LFound <> nil then
    Exit(T(LFound));

  // Aynı ad başka bir sınıfla kayıtlıysa sessizce üzerine yazma — bu bir hata.
  if IndexOfSection(LName) >= 0 then
    raise ERadOptionsSection.CreateFmt(
      '"%s" bölüm adı zaten BAŞKA bir sınıfa (%s) ait.',
      [LName, FSections[IndexOfSection(LName)].ClassName]);

  LNew := T.Create;
  LNew.SectionName := LName;
  // Varsayılanlar YARATILIRKEN uygulanır, Load sırasında DEĞİL. Sırası:
  //   DefaultValues  ->  Configure  ->  dosyadaki değerler
  // Load'da uygulansaydı Configure ile verilen değerleri EZERDİ (testle
  // yakalandı: Configure'da StartMinimized:=True denip DefaultValues'ta
  // False'a dönüyordu).
  LNew.DefaultValues;
  FSections.Add(LNew);
  Result := LNew;
end;

function TRadOptionsFile.Configure<T>(const AConfigure: TRadConfigureProc<T>;
  const AName: string): T;
begin
  Result := Section<T>(AName);
  if Assigned(AConfigure) then
    AConfigure(Result);
end;

function TRadOptionsFile.Get<T>(const AName: string): T;
begin
  if not TryGet<T>(Result, AName) then
    raise ERadOptionsSection.CreateFmt(
      '"%s" bölümü kayıtlı değil — önce Section<%s> ile ekle.',
      [AName, T.ClassName]);
end;

function TRadOptionsFile.TryGet<T>(out ASection: T; const AName: string): Boolean;
var
  LFound: TRadOptions;
begin
  LFound := FindByClass(TRadOptionsClass(T), AName);
  Result := LFound <> nil;
  if Result then
    ASection := T(LFound)
  else
    ASection := nil;
end;

function TRadOptionsFile.Has<T>(const AName: string): Boolean;
var
  LDummy: T;
begin
  Result := TryGet<T>(LDummy, AName);
end;

function TRadOptionsFile.Count: Integer;
begin
  Result := FSections.Count;
end;

function TRadOptionsFile.SectionNames: TArray<string>;
var
  I: Integer;
begin
  SetLength(Result, FSections.Count);
  for I := 0 to FSections.Count - 1 do
    Result[I] := FSections[I].SectionName;
end;

procedure TRadOptionsFile.ValidateAll;
var
  LSec: TRadOptions;
begin
  for LSec in FSections do
    try
      LSec.Validate;
    except
      on E: ERadOptionsValidation do
        raise;   // zaten doğru tip — sarmalayıp mesajı kaybetme
      on E: Exception do
        raise ERadOptionsValidation.CreateFmt('"%s" bölümü doğrulanamadı: %s: %s',
          [LSec.SectionName, E.ClassName, E.Message]);
    end;
end;

{ ---- Serileştirme ---- }

function TRadOptionsFile.BuildJson(AEncryptSections: Boolean): RawUtf8;
var
  LRoot: IDocDict;
  LSec: TRadOptions;
begin
  LRoot := DocDict;
  for LSec in FSections do
    if AEncryptSections and SectionIsEncrypted(LSec) then
      // Şifreli bölüm: nesne yerine TEK BİR METİN. Dosya geçerli JSON
      // kalır, bölüm adı görünür, içeriği görünmez.
      LRoot.SetU(StringToUtf8(LSec.SectionName),
                 SealSection(ObjectToJson(LSec)))
    else
      // Her bölüm kök nesnede kendi adıyla bir düğüm.
      LRoot.SetD(StringToUtf8(LSec.SectionName),
                 DocDict(ObjectToJson(LSec)));
  Result := LRoot.Json;
end;

function TRadOptionsFile.BuildIni(AEncryptSections: Boolean): RawUtf8;
var
  LSec: TRadOptions;
begin
  // ObjectToIni bölüm adını ZATEN parametre alıyor — bölüm başına bir [Ad]
  // bloğu üretip arka arkaya eklemek yeterli.
  Result := '';
  for LSec in FSections do
    if AEncryptSections and SectionIsEncrypted(LSec) then
      // Şifreli bölüm INI'de tek anahtarlı bir blok olur. Yük yine bölümün
      // JSON'udur — böylece üç biçim de aynı çözme yolunu kullanır.
      Result := Result + RawUtf8('[' + LSec.SectionName + ']'#13#10) +
                RawUtf8(CRadSecEnc + '=') + SealSection(ObjectToJson(LSec)) +
                RawUtf8(#13#10#13#10)
    else
      Result := Result + ObjectToIni(LSec, StringToUtf8(LSec.SectionName)) + #13#10;
end;

function TRadOptionsFile.Serialize(AEncryptSections: Boolean): RawUtf8;
begin
  case ResolveFormat of
    rofIni:
      Result := BuildIni(AEncryptSections);
    rofYaml:
      Result := JsonToYaml(BuildJson(AEncryptSections));
    else
      Result := JsonReformat(BuildJson(AEncryptSections), jsonHumanReadable);
  end;
end;

{ ---- Şifreleme zarfı ---- }

function TRadOptionsFile.GetEncrypted: Boolean;
begin
  Result := FCryptMode <> rcmNone;
end;

function TRadOptionsFile.SectionIsEncrypted(ASec: TRadOptions): Boolean;
begin
  Result := (FCryptMode = rcmSection) and
            TRadOptionsClass(ASec.ClassType).Encrypted;
end;

function TRadOptionsFile.SealSection(const ASectionJson: RawUtf8): RawUtf8;
begin
  Result := RawUtf8(CRadSecPrefix) + ToUtf8(CRadSecVersion) + RawUtf8(':') +
            FCipher.AlgorithmId + RawUtf8(':') +
            BinToBase64uri(FCipher.Encrypt(ASectionJson));
end;

function TRadOptionsFile.TryUnsealSection(const AMarker: RawUtf8;
  const ASectionName: string; out ASectionJson: RawUtf8): Boolean;
var
  LParts: TRawUtf8DynArray;
  LVer: Integer;
begin
  Result := False;
  ASectionJson := '';
  if not IdemPChar(pointer(AMarker), CRadSecPrefix) then
    Exit;   // düz bölüm, işaret değil

  // "RADSEC1:alg:veri" -> base64url alfabesinde ':' YOK, bölme güvenli.
  CsvToRawUtf8DynArray(pointer(AMarker), LParts, ':');
  if Length(LParts) <> 3 then
    raise ERadOptionsDecrypt.CreateFmt(
      '"%s" bölümünün şifreleme işareti bozuk.', [ASectionName]);

  LVer := GetInteger(pointer(@LParts[0][Length(CRadSecPrefix) + 1]));
  if LVer <> CRadSecVersion then
    raise ERadOptionsDecrypt.CreateFmt(
      '"%s": bölüm işaret sürümü %d, bu sürüm yalnızca %d okuyabiliyor.',
      [ASectionName, LVer, CRadSecVersion]);

  if not Assigned(FCipher) then
    raise ERadOptionsDecrypt.CreateFmt(
      '"%s" bölümü şifreli ama bir IRadCipher verilmedi.', [ASectionName]);

  if LParts[1] <> FCipher.AlgorithmId then
    raise ERadOptionsDecrypt.CreateFmt(
      '"%s" bölümü "%s" ile şifrelenmiş, verilen şifreleyici "%s".',
      [ASectionName, Utf8ToString(LParts[1]),
       Utf8ToString(FCipher.AlgorithmId)]);

  try
    ASectionJson := FCipher.Decrypt(Base64uriToBin(LParts[2]));
  except
    on E: ERadCipher do
      raise ERadOptionsDecrypt.CreateFmt('"%s" bölümü çözülemedi: %s',
        [ASectionName, E.Message]);
  end;
  Result := True;
end;

procedure TRadOptionsFile.ChangeCipher(const ANew: IRadCipher);
begin
  if not Assigned(ANew) then
    raise ERadOptions.Create(
      'ChangeCipher: nil kabul edilmez. Şifrelemeyi kaldırmak için ' +
      'RemoveCipher kullanın — o çağrı dosyayı DÜZ METNE çevirir.');
  FCipher := ANew;
  // MOD KORUNUR. rcmSection'da açılmış bir dosyanın anahtarını değiştirmek,
  // onu sessizce rcmFile'a çevirmemeli. Tek istisna: daha önce hiç anahtar
  // yoktu (rcmNone) — o zaman varsayılan moda geçilir, yoksa anahtar verilip
  // hiçbir şeyin şifrelenmemesi gibi bir sonuç doğardı.
  if FCryptMode = rcmNone then
    FCryptMode := rcmFile;
  FForceNextSave := True;   // yeni anahtarla yeniden yazılmalı
end;

procedure TRadOptionsFile.RemoveCipher;
begin
  FCipher := nil;
  FCryptMode := rcmNone;    // Encrypted artık False dönmeli
  FForceNextSave := True;   // düz metne dönüş diske yansımalı
end;

function TRadOptionsFile.WrapEnvelope(const APlain: RawUtf8): RawUtf8;
var
  LEnc, LJson: RawUtf8;
begin
  // base64url: A-Z a-z 0-9 - _ ; JSON'da kaçış, INI'de ayrıştırma sorunu yok.
  LEnc := BinToBase64uri(FCipher.Encrypt(APlain));

  if ResolveFormat = rofIni then
  begin
    Result := RawUtf8('[' + CRadEnvSection + ']'#13#10) +
              RawUtf8(CRadEnvEnc + '=') + LEnc + RawUtf8(#13#10) +
              RawUtf8(CRadEnvAlg + '=') + FCipher.AlgorithmId + RawUtf8(#13#10) +
              RawUtf8(CRadEnvVer + '=') + ToUtf8(CRadEnvVersion) + RawUtf8(#13#10);
    Exit;
  end;

  LJson := JsonEncode([CRadEnvSection,
    _ObjFast([CRadEnvEnc, LEnc,
              CRadEnvAlg, FCipher.AlgorithmId,
              CRadEnvVer, CRadEnvVersion])]);

  if ResolveFormat = rofYaml then
    Result := JsonToYaml(LJson)
  else
    Result := JsonReformat(LJson, jsonHumanReadable);
end;

function TRadOptionsFile.TryUnwrapEnvelope(const AText: RawUtf8;
  out APlain: RawUtf8): Boolean;
var
  LRoot, LData: IDocDict;
  LEnc, LAlg, LJson: RawUtf8;
  LVer: Integer;
begin
  Result := False;
  APlain := '';
  LEnc := '';
  LAlg := '';
  LVer := 0;

  case ResolveFormat of
    rofIni:
      begin
        LEnc := FindIniEntry(AText, CRadEnvSection, CRadEnvEnc, '');
        if LEnc = '' then
          Exit;   // zarf yok -> düz dosya
        LAlg := FindIniEntry(AText, CRadEnvSection, CRadEnvAlg, '');
        LVer := FindIniEntryInteger(AText, CRadEnvSection, CRadEnvVer);
      end;
  else
    begin
      if ResolveFormat = rofYaml then
      begin
        if not TryYamlToJson(AText, LJson) then
          Exit;   // geçersiz YAML: zarf tespiti değil, asıl yükleyici hata versin
      end
      else
        LJson := AText;

      if not IsValidJson(LJson) then
        Exit;
      LRoot := DocDict(LJson);
      if (LRoot = nil) or (LRoot.Kind <> dvObject) then
        Exit;
      if not LRoot.Get(CRadEnvSection, LData) or (LData = nil) then
        Exit;   // "data" düğümü yok -> düz dosya
      if not LData.Get(CRadEnvEnc, LEnc) or (LEnc = '') then
        Exit;   // "data" var ama "enc" yok -> zarf değil, normal bir bölüm
      LData.Get(CRadEnvAlg, LAlg);
      LData.Get(CRadEnvVer, LVer);
    end;
  end;

  // Buradan sonrası: bu KESİNLİKLE bir zarf. Artık her sorun HATADIR —
  // sessizce "düz dosya" muamelesi yapmak, şifreli içeriği ayrıştırmaya
  // çalışıp anlamsız bir ayrıştırma hatası vermek demek olurdu.
  if not Assigned(FCipher) then
    raise ERadOptionsDecrypt.CreateFmt(
      '"%s" şifreli ama bir IRadCipher verilmedi.', [FFileName]);

  if LVer <> CRadEnvVersion then
    raise ERadOptionsDecrypt.CreateFmt(
      '"%s": zarf sürümü %d, bu sürüm yalnızca %d okuyabiliyor.',
      [FFileName, LVer, CRadEnvVersion]);

  if (LAlg <> '') and (LAlg <> FCipher.AlgorithmId) then
    raise ERadOptionsDecrypt.CreateFmt(
      '"%s": dosya "%s" ile şifrelenmiş, verilen şifreleyici "%s".',
      [FFileName, Utf8ToString(LAlg), Utf8ToString(FCipher.AlgorithmId)]);

  try
    APlain := FCipher.Decrypt(Base64uriToBin(LEnc));
  except
    on E: ERadCipher do
      // Anahtar mı yanlış, veri mi kurcalanmış — AYIRMIYORUZ. GCM ikisini
      // aynı şekilde reddediyor, ve hangisi olduğunu söylemek saldırgana
      // bilgi verirdi.
      raise ERadOptionsDecrypt.CreateFmt('"%s" çözülemedi: %s',
        [FFileName, E.Message]);
  end;

  Result := True;
end;

{ ---- Uygulama (yükleme) ---- }

procedure TRadOptionsFile.ApplyJson(const AJson: RawUtf8; AFailOnMissing: Boolean);
var
  LRoot: IDocDict;
  LSec: TRadOptions;
  LChild: IDocDict;
  LChildJson, LMarker: RawUtf8;
  LValid: Boolean;
  I: Integer;
begin
  if not IsValidJson(AJson) then
    raise ERadOptionsLoad.CreateFmt('"%s": geçersiz JSON.', [FFileName]);
  LRoot := DocDict(AJson);
  if LRoot.Kind <> dvObject then
    raise ERadOptionsLoad.CreateFmt('"%s": kök bir JSON nesnesi olmalı.', [FFileName]);

  // DİKKAT — indeksli döngü ŞART: for..in değişkeni SALT OKUNURDUR ve
  // JsonToObject'in ilk parametresi untyped `var` (E2197).
  for I := 0 to FSections.Count - 1 do
  begin
    LSec := FSections[I];

    // Bölüm bazlı şifreli mi? O zaman değeri nesne değil METİNDİR, ve
    // LRoot.Get(...,IDocDict) onu bulamaz — önce metin olarak deneriz.
    if LRoot.Get(StringToUtf8(LSec.SectionName), LMarker) and
       TryUnsealSection(LMarker, LSec.SectionName, LChildJson) then
    begin
      UniqueRawUtf8(LChildJson);
      JsonToObject(LSec, PUtf8Char(LChildJson), LValid);
      if not LValid then
        raise ERadOptionsLoad.CreateFmt(
          '"%s" bölümü çözüldü ama çözümlenemedi.', [LSec.SectionName]);
      Continue;
    end;

    if not LRoot.Get(StringToUtf8(LSec.SectionName), LChild) or (LChild = nil) then
    begin
      if AFailOnMissing then
        raise ERadOptionsLoad.CreateFmt('"%s" bölümü dosyada yok.', [LSec.SectionName]);
      // Bölüm dosyada yok: bellekteki değerler (DefaultValues + Configure)
      // OLDUĞU GİBİ kalır. DefaultValues'i burada çağırmak Configure'u ezerdi.
      Continue;
    end;
    LChildJson := LChild.Json;
    // JsonToObject tamponu YERİNDE değiştirir — benzersiz kopya şart.
    UniqueRawUtf8(LChildJson);
    JsonToObject(LSec, PUtf8Char(LChildJson), LValid);
    if not LValid then
      raise ERadOptionsLoad.CreateFmt('"%s" bölümü çözümlenemedi.', [LSec.SectionName]);
  end;
end;

procedure TRadOptionsFile.ApplyIni(const AIni: RawUtf8; AFailOnMissing: Boolean);
var
  LSec: TRadOptions;
  LMarker, LChildJson: RawUtf8;
  LValid: Boolean;
  I: Integer;
begin
  // DIKKAT - indeksli dongu SART: for..in degiskeni SALT OKUNURDUR ve
  // JsonToObject'in ilk parametresi untyped `var` (E2197). Ayni tuzak
  // ApplyJson'da da var, orada da ayni sekilde cozuldu.
  for I := 0 to FSections.Count - 1 do
  begin
    LSec := FSections[I];
    // Şifreli bölüm INI'de tek "enc=" anahtarı taşır.
    LMarker := FindIniEntry(AIni, StringToUtf8(LSec.SectionName),
                            CRadSecEnc, '');
    if (LMarker <> '') and
       TryUnsealSection(LMarker, LSec.SectionName, LChildJson) then
    begin
      UniqueRawUtf8(LChildJson);
      JsonToObject(LSec, PUtf8Char(LChildJson), LValid);
      if not LValid then
        raise ERadOptionsLoad.CreateFmt(
          '"%s" bölümü çözüldü ama çözümlenemedi.', [LSec.SectionName]);
      Continue;
    end;

    if not IniToObject(AIni, LSec, StringToUtf8(LSec.SectionName)) then
    begin
      if AFailOnMissing then
        raise ERadOptionsLoad.CreateFmt('"%s" bölümü INI dosyasında yok.',
          [LSec.SectionName]);
      // Bölüm yok: bellekteki değerler korunur (bkz. ApplyJson'daki not).
    end;
  end;
end;

procedure TRadOptionsFile.Load(AFailOnMissing: Boolean);
var
  LText, LJson, LPlain: RawUtf8;
  LDosyaSifreliydi: Boolean;
begin
  if not TFile.Exists(FFileName) then
  begin
    // Dosya yok: bellekteki hâli (DefaultValues + Configure) dosyaya YAZ.
    // DefaultValues burada TEKRAR çağrılmaz — Section<T> yaratılırken zaten
    // uygulandı; burada çağırmak Configure'u ezerdi.
    ValidateAll;
    SaveForce;
    FLoaded := True;
    Exit;
  end;

  try
    LText := StringToUtf8(TFile.ReadAllText(FFileName, TEncoding.UTF8));
  except
    on E: Exception do
      raise ERadOptionsLoad.CreateFmt('"%s" okunamadı: %s: %s',
        [FFileName, E.ClassName, E.Message]);
  end;

  // Şifreli zarf mı? Öyleyse çöz ve bundan sonrasına DÜZ METİN olarak devam
  // et — ayrıştırma, doğrulama ve hash'in tamamı düz metin üzerinden döner.
  LDosyaSifreliydi := TryUnwrapEnvelope(LText, LPlain);
  if LDosyaSifreliydi then
    LText := LPlain;

  case ResolveFormat of
    rofIni:
      ApplyIni(LText, AFailOnMissing);
    rofYaml:
      begin
        if not TryYamlToJson(LText, LJson) then
          raise ERadOptionsLoad.CreateFmt('"%s": geçersiz YAML.', [FFileName]);
        ApplyJson(LJson, AFailOnMissing);
      end;
    else
      ApplyJson(LText, AFailOnMissing);
  end;

  ValidateAll;
  // Yüklenen içeriğin imzasını al: hemen ardından Save çağrılırsa gereksiz
  // yazma yapılmasın. LText burada DÜZ METİNDİR (zarf varsa çözülmüş hâli) —
  // Save da düz metin üzerinden hash aldığı için iki taraf aynı şeyi ölçer.
  // Hash'i dosya METNINDEN degil, KENDI sifresiz serilestirmemizden
  // aliyoruz. Iki sebep: (1) rcmSection'da dosya metni her kayitta
  // degisen bir isaret tasir, hash'lenemez; (2) diskteki bicimlendirme
  // bizimkinden farkliysa her Load sonrasi gereksiz yazma tetiklenirdi.
  // Save da ayni sifresiz hali hash'ledigi icin iki taraf ayni seyi olcer.
  LPlain := Serialize({AEncryptSections=}False);
  FLastSavedHash := crc32c(0, pointer(LPlain), Length(LPlain));

  // DİSKTEKİ DURUM İLE İSTENEN DURUM UYUŞMUYORSA bir sonraki Save yazmalı.
  // Aksi hâlde şu sessiz hata olurdu: düz bir dosya cipher verilerek açılır,
  // içerik değişmediği için hash aynı çıkar, Save "değişmedi" deyip atlar ve
  // dosya DÜZ KALIR — kullanıcı şifrelediğini sanır. Ters yön (şifreli dosya
  // + cipher yok) zaten TryUnwrapEnvelope'ta hata veriyor.
  FForceNextSave := LDosyaSifreliydi <> (FCryptMode = rcmFile);

  FLoaded := True;
end;

{ ---- Yazma ---- }

procedure TRadOptionsFile.WriteAtomic(const AText: RawUtf8);
var
  LDir, LTmp: string;
begin
  LDir := TPath.GetDirectoryName(FFileName);
  if (LDir <> '') and not TDirectory.Exists(LDir) then
    TDirectory.CreateDirectory(LDir);

  // Önce geçici dosya, sonra hedefin ÜZERİNE taşıma: süreç yazma ortasında
  // ölürse hem yeni hem ESKİ ayarlar kaybolurdu.
  LTmp := FFileName + '.tmp';
  try
    // BOM YOK — katı JSON/YAML ayrıştırıcıları BOM'a takılabiliyor.
    TFile.WriteAllBytes(LTmp, BytesOf(RawByteString(AText)));
    {$IFDEF MSWINDOWS}
    if not MoveFileEx(PChar(LTmp), PChar(FFileName), MOVEFILE_REPLACE_EXISTING) then
      RaiseLastOSError;
    {$ELSE}
    TFile.Move(LTmp, FFileName);
    {$ENDIF}
  except
    on E: Exception do
    begin
      if TFile.Exists(LTmp) then
        try TFile.Delete(LTmp); except end;
      raise ERadOptionsSave.CreateFmt('"%s" yazılamadı: %s: %s',
        [FFileName, E.ClassName, E.Message]);
    end;
  end;
end;

function TRadOptionsFile.Save: Boolean;
var
  LPlain: RawUtf8;
  LHash: cardinal;
begin
  ValidateAll;
  LPlain := Serialize({AEncryptSections=}False);
  // HASH DÜZ METİN ÜZERİNDEN. Şifreleme her kayıtta rastgele IV kullanır,
  // yani şifreli çıktı içerik hiç değişmese bile her seferinde farklıdır;
  // hash'i onun üzerinden alsaydık "değişmediyse yazma" tamamen ölürdü.
  LHash := crc32c(0, pointer(LPlain), Length(LPlain));
  // "Değişmediyse yazma" — TSynJsonFileSettings.SaveIfNeeded ile aynı sözleşme.
  Result := FForceNextSave or (LHash <> FLastSavedHash) or
            not TFile.Exists(FFileName);
  if not Result then
    Exit;
  // Şifreleme serileştirmeden AYRI ve SONRAKİ adım. Bölüm kilitleri ileride
  // Serialize'i sarmalarsa, crypto o kilidin dışında kalsın diye böyle.
  if FCryptMode = rcmFile then
    WriteAtomic(WrapEnvelope(LPlain))
  else if FCryptMode = rcmSection then
    WriteAtomic(Serialize({AEncryptSections=}True))
  else
    WriteAtomic(LPlain);
  FLastSavedHash := LHash;
  FForceNextSave := False;
end;

function TRadOptionsFile.SaveForce: Boolean;
var
  LPlain: RawUtf8;
begin
  ValidateAll;
  LPlain := Serialize({AEncryptSections=}False);
  if FCryptMode = rcmFile then
    WriteAtomic(WrapEnvelope(LPlain))
  else if FCryptMode = rcmSection then
    WriteAtomic(Serialize({AEncryptSections=}True))
  else
    WriteAtomic(LPlain);
  FLastSavedHash := crc32c(0, pointer(LPlain), Length(LPlain));
  FForceNextSave := False;
  Result := True;
end;

end.
