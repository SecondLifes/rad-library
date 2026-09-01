unit rad.utils;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes
  ,System.TypInfo
  ,mormot.core.base, mormot.core.os,mormot.core.variants ,mormot.core.fmt
  , mormot.ui.controls
  ;

type
  TOptionsFileSettings = mormot.core.fmt.TSynJsonFileSettings;
  { TResult<T>: Operasyon sonuularını yönetmek için optimize edilmiş record.
    Bellek ayırma (allocation) maliyeti yoktur, stack üzerinde �al���r. }


  TUtils = class
    //const
     //Hash32      : function (const Text: RawByteString): cardinal = mormot.core.base.Hash32;
     //Join        : function (const Args: array of RawByteString): RawUtf8 = mormot.core.base.Join;
    private
    public

    class procedure InUI(AProc: TProc); static;
  end;

  /// GenerateFluentCode'un kendi hata tipi — generic Exception yerine.
  EFluentCodeGen = class(Exception);

  /// GenerateFluentCode üretim seçenekleri.
  ///   fgoInterfaceGuid       — üretilen interface'e gerçek bir ['{...}'] GUID koyar
  ///                            (Supports()/as çalışsın diye). Her çağrıda YENİ GUID
  ///                            üretilir; kodu yeniden üretirsen GUID değişir.
  ///   fgoPascalCaseAccessors — accessor adlarının ilk harfini büyütür
  ///                            (keyLength -> SetKeyLength). Gövdedeki üye referansı
  ///                            orijinal yazımıyla kalır.
  ///   fgoCollisionMarkers    — aynı ada iki farklı üye üretilecekse üretilen koda
  ///                            "// ÇAKIŞMA" yorumu düşer ve raporda listelenir.
  ///   fgoHeaderReport        — üretilen kodun başına kapsam/atlama raporu ekler.
  ///   fgoNewFactory          — implementasyon class'ına bir
  ///                            "class function New(AInstance; AAutoFree): I<Isim>"
  ///                            ekler. Tek satırda zincirlemeyi sağlar:
  ///                              TAESEncryptionFluent.New(LAes).SetKeyLength(kl256)...
  ///                            Interface'ler class metodu taşıyamadığı için yalnızca
  ///                            implementasyon class'ında bulunur.
  ///   fgoQualifiedTypeNames  — tip adlarını TAM NİTELİKLİ üretir
  ///                            (CryptoConst.TAESKeyLength). Kısa ad, hedef unit'te
  ///                            aynı adı taşıyan başka bir tiple çakışırsa üretilen
  ///                            kod SESSİZCE yanlış tipe bağlanır; bu seçenek onu
  ///                            önler. Varsayılan KAPALI: çıktı belirgin biçimde
  ///                            uzar ve nitelenmiş ad yalnızca bir unit'in interface
  ///                            bölümünde bildirilmiş tipler için elde edilebilir
  ///                            (diğerlerinde kısa ada düşülür).
  TFluentGenOption = (
    fgoInterfaceGuid,
    fgoPascalCaseAccessors,
    fgoCollisionMarkers,
    fgoHeaderReport,
    fgoNewFactory,
    fgoQualifiedTypeNames);

  TFluentGenOptions = set of TFluentGenOption;

  /// GenerateFluentUnit'in hedef dosya ZATEN VARKEN ne yapacağı.
  ///   fumFailIfExists — dosya varsa hiçbir şey yazmaz, EFluentCodeGen fırlatır.
  ///                     Varsayılan: diske yazan bir fonksiyonda kayıp riski
  ///                     taşıyan her davranış açık istek olmalıdır.
  ///   fumMergeRegions — dosyanın ÜSTÜNE YAZMAZ. Yalnızca bu sınıfa ait
  ///                     {$REGION ...} bloklarını günceller; blok yoksa uygun
  ///                     yerlere ekler. Dosyadaki diğer her şey (başka
  ///                     sınıfların blokları, elle yazılmış kod, uses'taki
  ///                     fazladan unit'ler) OLDUĞU GİBİ KALIR. Böylece tek bir
  ///                     unit birden çok sınıfın sarmalayıcısını taşıyabilir.
  ///   fumReplaceFile  — dosyayı bütünüyle yeniden yazar (içindekiler gider).
  TFluentUnitWriteMode = (fumFailIfExists, fumMergeRegions, fumReplaceFile);

const
  /// GenerateFluentCode'un varsayılan seçenekleri (hepsi açık).
  CFluentGenDefaultOptions = [fgoInterfaceGuid, fgoPascalCaseAccessors,
    fgoCollisionMarkers, fgoHeaderReport, fgoNewFactory];




/// Verilen bir class'ı RTTI ile inceleyip, onu fluent/interface tabanlı bir sisteme
/// çevirecek HAZIR PASCAL KAYNAK KODUNU (string olarak) üretir. Üretilen kod
/// ÇALIŞTIRILMAZ/derlenmez — yalnızca metindir; gözden geçirip projeye elle eklemen gerekir.
///
/// Kurallar:
///   - Interface adı: class adı 'T' ile başlıyorsa 'I' + (T'siz hali), değilse 'I' + ad.
///   - İmplementasyon class adı: class adı + 'Fluent'.
///   - Her zaman bir "AsInstance: <ClassName>" eklenir — sarmalanan ham örneğe kaçış kapısı.
///   - Class'ta DOĞRUDAN tanımlı (kalıtılmamış), public/published her BASİT property için:
///       function Set<Prop>(const a<Prop>: <Tip>): I<Isim>;  (fluent, zincire devam eder)
///       function Get<Prop>: <Tip>;
///     Event property'ler (TNotifyEvent gibi method-type) de aynı kurala tabidir.
///   - İNDEKSLİ (array) property'ler (ör. property Items[Index: Integer]: T) için:
///       function Set<Prop>(<index parametreleri>; const aValue: <Tip>): I<Isim>;
///       function Get<Prop>(<index parametreleri>): <Tip>;
///   - DOĞRUDAN tanımlı her public method (property accessor'ları hariç, onlar zaten
///     private/protected olduğu için otomatik elenir) AYNI isim ve imzayla pass-through
///     olarak eklenir (fluent DEĞİLDİR, orijinal dönüş tipini korur). Aynı isimde birden
///     fazla (overload) metod varsa üretilen kodda 'overload;' otomatik eklenir.
///   - Constructor'a AAutoFree: Boolean = False parametresi eklenir; True verilirse
///     wrapper'ın destructor'ı FInstance.Free çağırır (varsayılan False — sarmalanan
///     örneğin ömrü hâlâ çağıranın sorumluluğundadır).
///
/// DİKKAT — Parametre/dönüş tipi adları: RTTI (TRttiType.Name) tabanlıdır ve TEST EDİLDİ
/// (bkz. rad.utils.Tests.pas → GenerikArrayParametreliMetodDaUretilir): ör. TArray<TValue>
/// gibi generic bir tip TAM NİTELİKLİ olarak üretilir (TArray<System.Rtti.TValue>) — bu
/// hâlâ geçerli/derlenebilir Pascal'dır, sadece kısaltılmamıştır.
///
/// DİKKAT — Class helper sızıntısı (RTTI seviyesinde DÜZELTİLEMEZ): AClass'ın DECLARE
/// EDİLDİĞİ unit'te o an AKTİF olan bir class helper (ör. "TObjectHelper = class helper
/// for TObject") varsa, derleyici o helper'ın metodlarını AClass'ın RTTI'sine SANKİ
/// DOĞRUDAN TANIMLIYMIŞ GİBİ gömer — Meth.Parent bile AClass'ı gösterir, ayırt edilemez
/// (gerçek derleme/testte doğrulandı: DUnitX.Utils.TObjectHelper.Log/Status/WriteLn,
/// TDenemeSinifi hiç tanımlamadığı hâlde üretilen koda karıştı). Bu, üretici fonksiyonun
/// bir kusuru değil, Delphi'nin derleme zamanında RTTI'ye "o anki görünür" tüm üyeleri
/// gömmesinin doğal sonucu — çalışma zamanı RTTI'sinden ayıklanamaz. ÜRETİLEN KODU HER
/// ZAMAN GÖZDEN GEÇİR; beklenmeyen fazladan metod görürsen elle çıkar.
///
/// NOT: Record desteği (GenerateFluentCode(ATypeInfo: PTypeInfo)) denendi ve KALDIRILDI —
/// gerçek derleme/testte (bkz. rad.utils.Tests.pas geçmişi) Delphi 13.1 Athens'in
/// System.Rtti'sinde record property'lerinin TRttiProperty olarak HİÇ yansıtılmadığı
/// (GetDeclaredProperties boş döndüğü) tespit edildi — en geniş {$RTTI} direktifiyle bile
/// değişmedi. Yalnızca class destekleniyor.
///
/// ===========================================================================
/// DİKKAT — RTTI KÖRLÜĞÜ: enumeratorlarına AÇIK DEĞER atanmış enum tipleri
/// ===========================================================================
/// Delphi, şu şekildeki bir enum için HİÇ RTTI üretmez:
///
///   TAESKeyLength = (kl128 = 128, kl192 = 192, kl256 = 256);
///
/// Derleyici bu tipte bir published property'yi KABUL EDER, ama o property için
/// RTTI kaydı EMIT ETMEZ. Sonuç: property çalışma zamanında tamamen görünmezdir —
/// ne GetDeclaredProperties, ne GetProperties, ne de TypInfo.GetPropList onu döndürür.
/// Delphi 37.0 (Athens) ile derlenip ÇALIŞTIRILARAK doğrulanmıştır.
///
/// Aynı kör nokta metodları da vurur:
///   - RTTI'siz tipte PARAMETRE alan metodun parametre listesi boş görünür
///     (üretilen kod derlenmez);
///   - RTTI'siz tip DÖNDÜREN fonksiyon mkProcedure + ReturnType=nil olarak görünür
///     (üretilen kod dönüş değerini sessizce düşürür).
///
/// ÇÖZÜM: AUnitSourcePath ver — sınıfın bildirildiği .pas dosyasının yolu. O zaman
/// üretici, RTTI'nin gördüğüyle kaynaktaki bildirimleri karşılaştırır, RTTI'nin
/// göremediği public/published property'leri kaynaktan okuyup üretir ve üretilen
/// koda "// [KAYNAK]" işaretiyle koyar. Parametre listesi şüpheli metodları da
/// başlık raporunda listeler. Kaynak tarayıcı basit bir metin tarayıcıdır: iç içe
/// tip bildirimi barındıran sınıflarda eksik/fazla okuyabilir — raporu oku.
///
/// Parametreler:
///   AClass          — sarmalanacak sınıf (nil verilemez).
///   AUnitSourcePath — opsiyonel; sınıfın bildirildiği .pas dosyası. Boş bırakılırsa
///                     yalnızca RTTI kullanılır (eski davranış birebir korunur).
///   AOptions        — üretim seçenekleri; bkz. TFluentGenOption.
function GenerateFluentCode(AClass: TClass; const AUnitSourcePath: string = '';
  AOptions: TFluentGenOptions = CFluentGenDefaultOptions): string;

/// GenerateFluentCode ile AYNI üretimi yapar, ama sonucu elle yapıştırılacak bir
/// parça olarak değil, DERLENMEYE HAZIR TAM BİR UNIT olarak AOutputPath'e yazar
/// (UTF-8 + BOM — kitin delphi-encoding kuralı). Yazılan dosyanın yolunu döndürür.
///
/// Unit adı DOSYA ADINDAN türetilir (Delphi'de ikisi aynı olmak zorundadır):
/// "...\MyLib.AES.Fluent.pas" -> "unit MyLib.AES.Fluent;".
///
/// BAĞIMLILIKLAR (uses) nasıl çözülür:
///   1. Sarmalanan sınıfın kendi unit'i — RTTI'nin QualifiedName'inden.
///   2. Üretilen her property/parametre/dönüş tipinin unit'i — aynı yoldan.
///      Generic tiplerin İÇİNDEKİ nitelenmiş adlar da taranır
///      (TArray<System.Rtti.TValue> -> System.Rtti).
///   3. RTTI'nin GÖREMEDİĞİ tipler (açık değer atanmış enum'lar) için unit bilgisi
///      RTTI'de YOKTUR. Bu durumda AUnitSourcePath verilmişse, sarmalanan sınıfın
///      kendi interface uses listesi olduğu gibi eklenir ve üretilen dosyaya bunun
///      neden yapıldığı yorum olarak yazılır. Bir kısmı gereksiz olabilir; derleyip
///      kullanılmayanları silmek çağırana kalır.
///   'System' örtük olduğu için hiçbir zaman listeye yazılmaz.
///
/// ÜRETİLEN İÇERİK HER ZAMAN {$REGION} İÇİNDEDİR — taze dosyada da, birleştirmede
/// de. İki blok üretilir ve sınıf adıyla anahtarlanır:
///   {$REGION 'RAD-FLUENT:<Sinif>:TYPES ...'}   -> interface, tip bildirimleri
///   {$REGION 'RAD-FLUENT:<Sinif>:IMPL ...'}    -> implementation, gövdeler
/// fumMergeRegions modunda bu anahtarlar aranır: varsa İÇERİĞİ DEĞİŞTİRİLİR, yoksa
/// TYPES bloğu 'implementation' satırından hemen önce, IMPL bloğu son 'end.'
/// satırından hemen önce eklenir. Eksik uses girdileri mevcut uses cümlesinin
/// sonuna eklenir; hiçbir şey silinmez.
///
/// DİKKAT: bir bloğun İÇİNE elle yazdığın kod, yeniden üretimde KAYBOLUR — blok
/// bütünüyle değiştirilir. Elle eklemelerini blokların DIŞINA yaz.
///
/// Birleştirmede mevcut bloktaki GUID YENİDEN KULLANILIR; yeni GUID üretilmez.
/// Aksi hâlde her çalıştırma GUID'i değiştirir (idempotent olmaz) ve o interface'i
/// Supports()/as ile kullanan kod sessizce bozulur.
///
/// Parametreler:
///   AOutputPath — yazılacak .pas dosyasının tam yolu. Klasör yoksa oluşturulur.
///   AWriteMode  — dosya zaten varsa ne yapılacağı; bkz. TFluentUnitWriteMode.
function GenerateFluentUnit(AClass: TClass; const AOutputPath: string;
  const AUnitSourcePath: string = '';
  AOptions: TFluentGenOptions = CFluentGenDefaultOptions;
  AWriteMode: TFluentUnitWriteMode = fumFailIfExists): string;

/// Bir unit dosyasındaki TÜM RAD-FLUENT bölgelerinin ait olduğu sınıf adlarını
/// döndürür (her sınıf bir kez, dosyadaki sırayla). Dosyaya dokunmaz.
function ListFluentRegions(const AUnitPath: string): TArray<string>;

/// ÖKSÜZ BÖLGE TEMİZLİĞİ: AKeepClassNames listesinde OLMAYAN her RAD-FLUENT
/// bölgesini (TYPES + IMPL) siler. Kaynaktan kaldırılmış bir sınıfın sarmalayıcısı
/// dosyada sonsuza kadar kalmasın diye; GenerateFluentUnit tek seferde yalnızca
/// KENDİ sınıfının bölgesine baktığı için bunu fark edemez.
///
/// ADryRun VARSAYILAN True — dosyaya HİÇBİR ŞEY yazılmaz, yalnızca silinecek sınıf
/// adları döner. Gerçekten silmek için açıkça False ver: bu işlem geri alınamaz.
///
/// uses cümlesine DOKUNULMAZ: silinen bölgenin getirdiği unit'ler listede kalır
/// (hangi unit'in yalnızca o bölge için eklendiği güvenilir biçimde bilinemez).
/// Derleyicinin "unit gereksiz" ipuçlarına bakıp elle temizle.
function PruneFluentRegions(const AUnitPath: string;
  const AKeepClassNames: array of string; ADryRun: Boolean = True): TArray<string>;

/// 1/10 ms toleranslı TDateTime karşılaştırma (float yuvarlama hatalarına karşı)
/// Kaynak: vendor\gabr42\GpDelphiUnits\src\GpTimezone.pas (DateEQ/DateLT/.../DateGE)
function DateEQ(const ADate1, ADate2: TDateTime): Boolean;
function DateLT(const ADate1, ADate2: TDateTime): Boolean;
function DateLE(const ADate1, ADate2: TDateTime): Boolean;
function DateGT(const ADate1, ADate2: TDateTime): Boolean;
function DateGE(const ADate1, ADate2: TDateTime): Boolean;

/// float yuvarlama hatalarını düzeltir (Trunc/Frac öncesi çağrılır)
/// ör. FixDT(36463.99999999999) = 36464
function FixDT(const ADate: TDateTime): TDateTime;

/// "ayın N'inci X günü" tarihini hesaplar (ör. DayOfMonth2Date(2026,12,5,1) = Aralık'ın son Pazarı)
/// AWeekInMonth: 1-4 (o ayın kaçıncı haftası) veya 5 (son hafta); ADayInWeek: 1=Pazar..7=Cumartesi
function DayOfMonth2Date(AYear, AMonth, AWeekInMonth, ADayInWeek: Word): TDateTime;


implementation
uses
System.Rtti, System.Generics.Collections,
System.DateUtils
,mormot.core.text, mormot.core.unicode , mormot.core.datetime, mormot.core.json
;

// DİKKAT — mormot.core.base, interface uses'unda System.SysUtils'ten SONRA geldiği
// için Pos/PosEx gibi isimler için bildirdiği RawUtf8 (= type UTF8String) aşırı
// yüklemeleri RTL sürümlerini gölgeliyor: niteliksiz her Pos() çağrısı sessizce
// string -> UTF8String dönüşümüne giriyor (W1057; Türkçe karakterlerde veri kaybı
// + gereksiz kopya). Bu yüzden aşağıdaki üretici kodunda Pos DAİMA System.Pos
// olarak nitelenmiş çağrılır. Uses sırasını değiştirmek unit'in geri kalanını
// etkileyeceğinden bilinçli olarak dokunulmadı.

{ ============================================================================
  GenerateFluentCode — uygulama
  ============================================================================ }

type
  { Kaynak (.pas) taramasından çıkan property bilgisi. }
  TSourceProperty = record
    Name: string;
    TypeName: string;
    IndexParams: string;
    IsReadable: Boolean;
    IsWritable: Boolean;
  end;

  { Üretimin tamamını yapan sınıf. Public API tek bir fonksiyon olarak kalır;
    bu sınıf yalnızca implementation bölümünde görünür. Üretici, tek bir 300
    satırlık fonksiyondan buraya taşındı — kitin "Methods > 20 lines" kuralı
    ve imza/gövde ikilisinin tek kaynaktan üretilmesi için. }
  TFluentCodeGenerator = class
  strict private
    FClass: TClass;
    FOptions: TFluentGenOptions;
    FSourcePath: string;
    FCtx: TRttiContext;
    FType: TRttiInstanceType;
    FInstanceTypeName: string;
    FInterfaceName: string;
    FImplName: string;
    FDecls: TStringBuilder;
    FBodies: TStringBuilder;
    FOverloads: TDictionary<string, Integer>;
    FEmitted: TDictionary<string, string>;
    FRttiProps: TDictionary<string, Byte>;
    FRttiMethods: TDictionary<string, Integer>;
    FRttiFunctions: TDictionary<string, Byte>;
    FNotes: TStringList;
    FUsedUnits: TStringList;
    FUnresolvedTypes: TStringList;
    FSuspectMethods: TStringList;
    FGuidText: string;
    FUsesFromSource: Boolean;
    FCanAutoCreate: Boolean;
    FCreateExpr: string;
    FPropCount: Integer;
    FIdxCount: Integer;
    FMethCount: Integer;
    FSourceCount: Integer;
    FSkipCount: Integer;

    procedure Note(const AText: string);
    function AccessorName(const AName: string): string;
    function ClaimName(const AName, AKind: string): string;
    function TypeNameOf(AType: TRttiType): string;
    function IsEligibleMethod(const AMeth: TRttiMethod): Boolean;
    function TryParamList(const AParams: TArray<TRttiParameter>;
      out AText: string; out AReason: string): Boolean;
    function ArgListFor(const AParams: TArray<TRttiParameter>): string;
    function IndexParamsOf(const AIdxProp: TRttiIndexedProperty): TArray<TRttiParameter>;

    procedure ResolveNames;
    procedure DetectConstructor;
    procedure CollectRttiInventory;
    procedure EmitPrologue;
    procedure EmitAccessorPair(const AName, ATypeName, AIndexParams, AIndexArgs,
      AValueIdent, ATag: string; AReadable, AWritable: Boolean);
    procedure EmitProperties;
    procedure EmitIndexedProperties;
    procedure EmitMethod(const AMeth: TRttiMethod);
    procedure EmitMethods;

    function ReadSourceLines: string;
    function ExtractClassBody(const ASource: string): string;
    function ParseSourceProperties(const ABody: string): TArray<TSourceProperty>;
    procedure CheckSourceMethods(const ABody: string);
    procedure ScanSource;

    procedure AddUsedUnit(const AUnitName: string);
    procedure RegisterUnitOf(AType: TRttiType);
    procedure RegisterUnitsInTypeName(const ATypeText: string);
    function ParseSourceUses(const ASource: string): TArray<string>;

    function BuildHeaderReport: string;
    procedure AppendTypeDecls(ASb: TStringBuilder);
    function Assemble: string;
    function AssembleUnit(const AUnitName: string): string;
    procedure Build;
    procedure ResolveSourceUses;
  public
    constructor Create(AClass: TClass; const ASourcePath: string;
      AOptions: TFluentGenOptions);
    destructor Destroy; override;
    /// Yalnizca tip bildirimleri + govdeler (elle yapistirmak icin) uretir.
    function Execute: string;
    /// Derlenmeye hazir, bagimliliklari cozulmus TAM bir unit metni uretir.
    function ExecuteUnit(const AUnitName: string): string;

    { --- Birlestirme (fumMergeRegions) icin --- }
    /// Build'i calistirir; blok metinleri ve UsedUnits bundan SONRA okunabilir.
    procedure Prepare;
    /// Bir sinifin REGION anahtari: 'RAD-FLUENT:<Sinif>:TYPES' / ':IMPL'.
    class function RegionKeyFor(const AClassName, AKind: string): string; static;
    /// interface'e girecek, {$REGION}/{$ENDREGION} ile sarilmis tip bildirimleri.
    function TypesRegionText: string;
    /// implementation'a girecek, {$REGION}/{$ENDREGION} ile sarilmis govdeler.
    function ImplRegionText: string;
    /// Uretimin gerektirdigi unit'ler (Prepare sonrasi dolar).
    property UsedUnits: TStringList read FUsedUnits;
    /// Bos degilse yeni GUID uretilmez, bu deger kullanilir (idempotent birlestirme).
    property PresetGuid: string read FGuidText write FGuidText;
  end;

{ --------------------------------------------------------------------------
  Kaynak tarayıcı yardımcıları (birim-yerel, sınıftan bağımsız)
  -------------------------------------------------------------------------- }

/// Pascal yorumlarını (// ... , { ... }, (* ... *)) siler; satır yapısını korur.
function StripPascalComments(const ASource: string): string;
var
  LSb: TStringBuilder;
  I, LLen: Integer;
begin
  LSb := TStringBuilder.Create(Length(ASource));
  try
    I := 1;
    LLen := Length(ASource);
    while I <= LLen do
    begin
      if (ASource[I] = '/') and (I < LLen) and (ASource[I + 1] = '/') then
        while (I <= LLen) and not CharInSet(ASource[I], [#10, #13]) do Inc(I)
      else if ASource[I] = '{' then
      begin
        while (I <= LLen) and (ASource[I] <> '}') do
        begin
          if CharInSet(ASource[I], [#10, #13]) then LSb.Append(ASource[I]);
          Inc(I);
        end;
        Inc(I);
      end
      else if (ASource[I] = '(') and (I < LLen) and (ASource[I + 1] = '*') then
      begin
        Inc(I, 2);
        while (I < LLen) and not ((ASource[I] = '*') and (ASource[I + 1] = ')')) do
        begin
          if CharInSet(ASource[I], [#10, #13]) then LSb.Append(ASource[I]);
          Inc(I);
        end;
        Inc(I, 2);
      end
      else
      begin
        LSb.Append(ASource[I]);
        Inc(I);
      end;
    end;
    Result := LSb.ToString;
  finally
    LSb.Free;
  end;
end;

/// Parantez/köşeli parantez derinliği — çok satırlı bildirimin bittiğini anlamak için.
function BracketDepth(const AText: string): Integer;
var
  C: Char;
begin
  Result := 0;
  for C in AText do
    if CharInSet(C, ['(', '[']) then
      Inc(Result)
    else if CharInSet(C, [')', ']']) then
      Dec(Result);
end;

/// "Index: Integer; const aValue: string" -> "Index, aValue"
function ArgsFromParamText(const AParams: string): string;
var
  LGroup, LName, LDecl, LOne: string;
begin
  Result := '';
  if AParams = '' then Exit;
  for LGroup in AParams.Split([';']) do
  begin
    LDecl := LGroup;
    if LDecl.Contains(':') then
      LDecl := Copy(LDecl, 1, System.Pos(':', LDecl) - 1);
    for LName in LDecl.Trim.Split([',']) do
    begin
      LOne := LName.Trim;
      while System.Pos(' ', LOne) > 0 do // const/var/out önekini at
        LOne := Copy(LOne, System.Pos(' ', LOne) + 1, MaxInt);
      if LOne = '' then Continue;
      if Result <> '' then Result := Result + ', ';
      Result := Result + LOne;
    end;
  end;
end;

/// Bir unit adı RTL/VCL namespace'li mi (System.Classes, Vcl.Forms, ...) ve öyleyse
/// niteliksiz ikizi ne (Classes, Forms)?
///
/// Bu ayrım ŞART: Delphi'de "Classes" ile "System.Classes" AYNI unit'tir (unit scope
/// names). İkisini birden uses'a yazmak E2004 "Identifier redeclared" verir ve
/// üretilen dosya DERLENMEZ. RTTI nitelenmiş adı ("System.Classes"), eski kaynakların
/// kendi uses'u ise niteliksizini ("Classes") verdiği için bu çakışma pratikte
/// legacy/vendor kaynak taranan HER durumda oluşur (gerçek TMS AESObj.pas'ta oluştu).
/// Sadeleştirme yalnızca BİLİNEN RTL kökleri için yapılır; "Foo.Bar" ile "Bar" gibi
/// gerçekten farklı olabilecek proje unit'lerine dokunulmaz.
function IsRtlNamespaced(const AUnitName: string; out ABareName: string): Boolean;
const
  CRoots: array [0 .. 11] of string = ('system', 'winapi', 'vcl', 'data', 'xml',
    'web', 'soap', 'fmx', 'rest', 'datasnap', 'ibx', 'bde');
var
  I, LLastDot, LFirstDot: Integer;
  LRoot: string;
begin
  Result := False;
  ABareName := '';
  LLastDot := 0;
  for I := 1 to Length(AUnitName) do
    if AUnitName[I] = '.' then LLastDot := I;
  if LLastDot = 0 then Exit;

  ABareName := Copy(AUnitName, LLastDot + 1, MaxInt);
  LFirstDot := System.Pos('.', AUnitName);
  LRoot := LowerCase(Copy(AUnitName, 1, LFirstDot - 1));
  for I := Low(CRoots) to High(CRoots) do
    if LRoot = CRoots[I] then Exit(True);
end;

/// AUnitName listede var mı — nitelenmiş/niteliksiz ikizler AYNI sayılır.
function UnitListHas(AList: TStrings; const AUnitName: string): Boolean;
var
  I: Integer;
  LBare, LOtherBare: string;
  LIsNs: Boolean;
begin
  if AList.IndexOf(AUnitName) >= 0 then Exit(True);
  LIsNs := IsRtlNamespaced(AUnitName, LBare);
  for I := 0 to AList.Count - 1 do
  begin
    if LIsNs and SameText(AList[I], LBare) then Exit(True);
    if IsRtlNamespaced(AList[I], LOtherBare) and SameText(LOtherBare, AUnitName) then Exit(True);
  end;
  Result := False;
end;

/// Kaynak metinde "<SinifAdi> = class" başlığının konumunu bulur (0 = yok).
function FindClassHeaderPos(const ALowerSource, ALowerClassName: string): Integer;
var
  LIdx, LScan, LLen: Integer;
begin
  Result := 0;
  LLen := Length(ALowerSource);
  LIdx := 1;
  while True do
  begin
    LIdx := System.Pos(ALowerClassName, ALowerSource, LIdx);
    if LIdx = 0 then Exit;
    if (LIdx = 1) or not CharInSet(ALowerSource[LIdx - 1], ['a'..'z', '0'..'9', '_']) then
    begin
      LScan := LIdx + Length(ALowerClassName);
      while (LScan <= LLen) and CharInSet(ALowerSource[LScan], [' ', #9, #13, #10]) do Inc(LScan);
      if (LScan <= LLen) and (ALowerSource[LScan] = '=') then
      begin
        Inc(LScan);
        while (LScan <= LLen) and CharInSet(ALowerSource[LScan], [' ', #9, #13, #10]) do Inc(LScan);
        if Copy(ALowerSource, LScan, 5) = 'class' then
          Exit(LIdx);
      end;
    end;
    Inc(LIdx, Length(ALowerClassName));
  end;
end;

{ TFluentCodeGenerator }

constructor TFluentCodeGenerator.Create(AClass: TClass; const ASourcePath: string;
  AOptions: TFluentGenOptions);
begin
  inherited Create;
  FClass := AClass;
  FSourcePath := ASourcePath;
  FOptions := AOptions;
  FCtx := TRttiContext.Create;
  FDecls := TStringBuilder.Create;
  FBodies := TStringBuilder.Create;
  FNotes := TStringList.Create;
  FOverloads := TDictionary<string, Integer>.Create;
  FEmitted := TDictionary<string, string>.Create;
  FRttiProps := TDictionary<string, Byte>.Create;
  FRttiMethods := TDictionary<string, Integer>.Create;
  FRttiFunctions := TDictionary<string, Byte>.Create;
  FUsedUnits := TStringList.Create;
  FUsedUnits.CaseSensitive := False;   // IndexOf ile büyük/küçük harf duyarsız tekilleştirme
  FUnresolvedTypes := TStringList.Create;
  FUnresolvedTypes.CaseSensitive := False;
  FSuspectMethods := TStringList.Create;
  FSuspectMethods.CaseSensitive := False;
end;

destructor TFluentCodeGenerator.Destroy;
begin
  FSuspectMethods.Free;
  FUnresolvedTypes.Free;
  FUsedUnits.Free;
  FRttiFunctions.Free;
  FRttiMethods.Free;
  FRttiProps.Free;
  FEmitted.Free;
  FOverloads.Free;
  FNotes.Free;
  FBodies.Free;
  FDecls.Free;
  FCtx.Free;
  inherited;
end;

procedure TFluentCodeGenerator.Note(const AText: string);
begin
  FNotes.Add(AText);
end;

/// Accessor adı: fgoPascalCaseAccessors açıksa ilk harfi büyütür (keyLength -> KeyLength).
/// Gövdedeki üye referansı DAİMA orijinal yazımıyla kalır.
function TFluentCodeGenerator.AccessorName(const AName: string): string;
begin
  Result := AName;
  if (fgoPascalCaseAccessors in FOptions) and (Result <> '') then
    Result[1] := UpCase(Result[1]);
end;

/// Ad sahiplenme + çakışma tespiti. Aynı ad aynı türle tekrar gelirse (overload)
/// çakışma değildir. Çakışma varsa üretilen koda düşecek yorum satırını döndürür.
function TFluentCodeGenerator.ClaimName(const AName, AKind: string): string;
var
  LPrev: string;
begin
  Result := '';
  if FEmitted.TryGetValue(UpperCase(AName), LPrev) then
  begin
    if LPrev = AKind then Exit;
    Result := Format('    // ÇAKIŞMA: "%s" hem %s hem %s olarak üretiliyor — birini elle yeniden adlandır.',
      [AName, LPrev, AKind]);
    Note(Format('ÇAKIŞMA: %s (%s <-> %s)', [AName, LPrev, AKind]));
  end
  else
    FEmitted.Add(UpperCase(AName), AKind);
end;

/// nil-güvenli tip adı. RTTI'si olmayan tip için '' döner (çağıran atlar).
/// fgoQualifiedTypeNames açıksa tam nitelikli ad denenir; tip bir unit'in interface
/// bölümünde bildirilmemişse QualifiedName ENonPublicType fırlatır — o durumda
/// sessizce kısa ada düşülür (nitelenmiş ad zaten mümkün değildir).
function TFluentCodeGenerator.TypeNameOf(AType: TRttiType): string;
var
  LQualified: string;
begin
  if AType = nil then Exit('');
  Result := AType.Name;
  if not (fgoQualifiedTypeNames in FOptions) then Exit;
  try
    LQualified := AType.QualifiedName;
    if LQualified <> '' then Result := LQualified;
  except
    on ENonPublicType do ; // nitelenmiş ad elde edilemez; kısa adla devam
  end;
end;

function TFluentCodeGenerator.IsEligibleMethod(const AMeth: TRttiMethod): Boolean;
begin
  Result := (AMeth.Parent = FType) and (AMeth.Visibility >= mvPublic) and
    (AMeth.MethodKind in [mkProcedure, mkFunction]);
end;

/// Parametre listesini üretir. Üretilemiyorsa False döner ve AReason'ı doldurur —
/// eskiden burada P.ParamType.Name doğrudan çağrılıyordu ve tipsiz (untyped)
/// parametrede Access Violation veriyordu.
function TFluentCodeGenerator.TryParamList(const AParams: TArray<TRttiParameter>;
  out AText: string; out AReason: string): Boolean;
var
  P: TRttiParameter;
  LPrefix, LTypeText: string;
begin
  AText := '';
  AReason := '';
  for P in AParams do
  begin
    if P.ParamType = nil then
    begin
      AReason := Format('"%s" parametresi tipsiz (untyped) — RTTI''de tip bilgisi yok', [P.Name]);
      Exit(False);
    end;
    if P.Name = '' then
    begin
      AReason := 'parametre adı RTTI''de boş';
      Exit(False);
    end;
    if pfConst in P.Flags then LPrefix := 'const '
    else if pfOut in P.Flags then LPrefix := 'out '
    else if pfVar in P.Flags then LPrefix := 'var '
    else LPrefix := '';
    // pfArray = AÇIK DİZİ (open array). ParamType.Name ELEMAN tipini verir; başına
    // "array of" konmazsa imza sessizce yanlış üretilir. Dinamik dizide pfArray YOKTUR.
    if pfArray in P.Flags then
      LTypeText := 'array of ' + TypeNameOf(P.ParamType)
    else
      LTypeText := TypeNameOf(P.ParamType);
    if AText <> '' then AText := AText + '; ';
    AText := AText + LPrefix + P.Name + ': ' + LTypeText;
  end;
  Result := True;
end;

function TFluentCodeGenerator.ArgListFor(const AParams: TArray<TRttiParameter>): string;
var
  P: TRttiParameter;
begin
  Result := '';
  for P in AParams do
  begin
    if Result <> '' then Result := Result + ', ';
    Result := Result + P.Name;
  end;
end;

/// İndeksli property'nin index parametrelerini (value HARİÇ) çıkarır.
function TFluentCodeGenerator.IndexParamsOf(const AIdxProp: TRttiIndexedProperty): TArray<TRttiParameter>;
begin
  if Assigned(AIdxProp.ReadMethod) then
    Result := AIdxProp.ReadMethod.GetParameters
  else if Assigned(AIdxProp.WriteMethod) then
  begin
    Result := AIdxProp.WriteMethod.GetParameters;
    if Length(Result) > 0 then
      SetLength(Result, Length(Result) - 1); // son parametre value'dur, index değil
  end
  else
    SetLength(Result, 0);
end;

procedure TFluentCodeGenerator.ResolveNames;
var
  LRtti: TRttiType;
begin
  LRtti := FCtx.GetType(FClass);
  if not (LRtti is TRttiInstanceType) then
    raise EFluentCodeGen.CreateFmt(
      'GenerateFluentCode: "%s" için kullanılabilir RTTI bulunamadı.', [FClass.ClassName]);
  FType := TRttiInstanceType(LRtti);
  FInstanceTypeName := FType.Name;
  if (Length(FInstanceTypeName) > 1) and (FInstanceTypeName[1] = 'T') then
    FInterfaceName := 'I' + Copy(FInstanceTypeName, 2, MaxInt)
  else
    FInterfaceName := 'I' + FInstanceTypeName;
  FImplName := FInstanceTypeName + 'Fluent';
  // PresetGuid verilmişse (birleştirme: dosyadaki mevcut GUID) onu KORU — yeniden
  // üretimde GUID değişirse Supports()/as kullanan kod sessizce bozulur.
  if FGuidText = '' then
    FGuidText := TGUID.NewGuid.ToString;
  RegisterUnitOf(FType);               // sarmalanan sınıfın kendi unit'i her zaman gerekli
end;

procedure TFluentCodeGenerator.AddUsedUnit(const AUnitName: string);
var
  LName, LBare, LOtherBare: string;
  I: Integer;
begin
  LName := System.SysUtils.Trim(AUnitName);
  // 'System' örtük olarak her unit'te vardır; uses'a yazmak gereksiz (ve hatalı görünür).
  if (LName = '') or SameText(LName, 'System') then Exit;

  if IsRtlNamespaced(LName, LBare) then
  begin
    // Nitelenmiş ad geldi: niteliksiz ikizi listedeyse onu ÇIKAR (nitelenmiş olan
    // namespace ayarlarından bağımsız çözülür, o yüzden daha güvenli olanı odur).
    I := FUsedUnits.IndexOf(LBare);
    if I >= 0 then FUsedUnits.Delete(I);
  end
  else
  begin
    // Niteliksiz ad geldi: nitelenmiş ikizi zaten listedeyse HİÇ EKLEME.
    for I := 0 to FUsedUnits.Count - 1 do
      if IsRtlNamespaced(FUsedUnits[I], LOtherBare) and SameText(LOtherBare, LName) then
        Exit;
  end;

  if FUsedUnits.IndexOf(LName) < 0 then
    FUsedUnits.Add(LName);
end;

/// Tipin bildirildiği unit'i QualifiedName'den ('AESObj.TAESEncryption') çıkarır.
procedure TFluentCodeGenerator.RegisterUnitOf(AType: TRttiType);
var
  LQualified, LUnit: string;
begin
  if AType = nil then Exit;
  // QualifiedName, bir unit'in INTERFACE bölümünde bildirilmemiş tipler için
  // ENonPublicType fırlatır (bir .dpr içinde ya da implementation bölümünde
  // tanımlı sınıf). Bu bir üretim hatası değil: yalnızca o tipin unit'i
  // bilinemez, uses'a elle eklenmesi gerekir.
  LQualified := '';
  try
    LQualified := AType.QualifiedName;
  except
    on ENonPublicType do
    begin
      if FUnresolvedTypes.IndexOf(AType.Name) < 0 then
        FUnresolvedTypes.Add(AType.Name);
      Note(Format('UNIT ÇÖZÜLEMEDİ: "%s" bir unit''in interface bölümünde bildirilmemiş — ' +
        'uses''a elle ekle.', [AType.Name]));
    end;
  end;
  if (LQualified <> '') and LQualified.EndsWith(AType.Name) then
  begin
    LUnit := Copy(LQualified, 1, Length(LQualified) - Length(AType.Name));
    while (LUnit <> '') and (LUnit[Length(LUnit)] = '.') do
      SetLength(LUnit, Length(LUnit) - 1);
    AddUsedUnit(LUnit);
  end;
  // Generic tiplerde iç tipler yalnızca ADIN İÇİNDE geçer
  // (ör. TArray<System.Rtti.TValue> -> System.Rtti da gerekir).
  RegisterUnitsInTypeName(AType.Name);
end;

/// Tip adı METNİNDEKİ nitelenmiş adlardan unit'leri toplar.
procedure TFluentCodeGenerator.RegisterUnitsInTypeName(const ATypeText: string);
var
  I, LStart, LDot, K: Integer;
  LRun: string;
begin
  I := 1;
  while I <= Length(ATypeText) do
  begin
    if CharInSet(ATypeText[I], ['A'..'Z', 'a'..'z', '_']) then
    begin
      LStart := I;
      while (I <= Length(ATypeText)) and
            CharInSet(ATypeText[I], ['A'..'Z', 'a'..'z', '0'..'9', '_', '.']) do Inc(I);
      LRun := Copy(ATypeText, LStart, I - LStart);
      LDot := 0;
      for K := 1 to Length(LRun) do
        if LRun[K] = '.' then LDot := K;
      if LDot > 1 then
        AddUsedUnit(Copy(LRun, 1, LDot - 1));
    end
    else
      Inc(I);
  end;
end;

/// Kaynak unit'in interface bölümündeki uses listesini okur. RTTI'nin göremediği
/// tipler (açık değer atanmış enum'lar) için TEK çözüm bu: tipin hangi unit'te
/// bildirildiğini RTTI'den öğrenmek mümkün olmadığından, sarmalanan sınıfın kendi
/// gördüğü unit'lerin tamamı alınır. Bazıları gereksiz olabilir; üretilen unit'te
/// bu durum yorumla belirtilir.
function TFluentCodeGenerator.ParseSourceUses(const ASource: string): TArray<string>;
var
  LClean, LLow, LBlock, LItem, LOne: string;
  LIface, LUses, LSemi, LImpl: Integer;
  LList: TStringList;
begin
  Result := nil;
  LClean := StripPascalComments(ASource);
  LLow := LowerCase(LClean);
  LIface := System.Pos('interface', LLow);
  if LIface = 0 then LIface := 1;
  LImpl := System.Pos('implementation', LLow);
  LUses := System.Pos('uses', LLow, LIface);
  if (LUses = 0) or ((LImpl > 0) and (LUses > LImpl)) then Exit;
  LSemi := System.Pos(';', LClean, LUses);
  if LSemi = 0 then Exit;

  LBlock := Copy(LClean, LUses + Length('uses'), LSemi - LUses - Length('uses'));
  LList := TStringList.Create;
  try
    for LItem in LBlock.Split([',']) do
    begin
      LOne := System.SysUtils.Trim(LItem.Replace(#13, ' ').Replace(#10, ' ').Replace(#9, ' '));
      // "UnitAdi in 'dosya.pas'" biçimini sadeleştir
      if System.Pos(' ', LOne) > 0 then
        LOne := System.SysUtils.Trim(Copy(LOne, 1, System.Pos(' ', LOne) - 1));
      if LOne <> '' then LList.Add(LOne);
    end;
    Result := LList.ToStringArray;
  finally
    LList.Free;
  end;
end;

/// Parametresiz New() üretilebilir mi — yani sarmalanan sınıf, argümansız
/// yaratılabilir mi?
///
/// DİKKAT (ölçüldü): GetMethods, HER sınıf için atadaki `TObject.Create()`i de
/// listeler. "Parametresiz bir Create var mı" diye bakmak, türetilmiş sınıf Create'i
/// KENDİ imzasıyla gizlediğinde (ör. `Create(ADep: Integer)`) derlenmeyen kod üretir.
/// GetMethods en türemişten başladığı için yalnızca İLK Create'e bakılır — çağrı
/// yerinde gerçekten görünen odur.
procedure TFluentCodeGenerator.DetectConstructor;
var
  LMeth: TRttiMethod;
  LParams: TArray<TRttiParameter>;
begin
  FCanAutoCreate := False;
  FCreateExpr := '';
  for LMeth in FType.GetMethods do
  begin
    if LMeth.MethodKind <> mkConstructor then Continue;
    if not SameText(LMeth.Name, 'Create') then Continue;
    if LMeth.Visibility < mvPublic then Continue;

    LParams := LMeth.GetParameters;
    if Length(LParams) = 0 then
    begin
      FCanAutoCreate := True;
      FCreateExpr := FInstanceTypeName + '.Create';
    end
    else if (Length(LParams) = 1) and (LParams[0].ParamType <> nil) and
            SameText(LParams[0].ParamType.Name, 'TComponent') then
    begin
      // TComponent sahiplik sözleşmesi bilinen bir kalıp: Owner=nil vermek güvenli,
      // sahiplik tamamen sarmalayıcıya geçer.
      FCanAutoCreate := True;
      FCreateExpr := FInstanceTypeName + '.Create(nil)';
    end
    else
      Note(Format('New() (parametresiz) ÜRETİLMEDİ: %s.Create %d parametre istiyor; ' +
        'ne verileceği tahmin edilemez — örneği kendin yaratıp New(AInstance) kullan.',
        [FInstanceTypeName, Length(LParams)]));
    Break; // yalnızca EN TÜREMİŞ Create belirleyicidir
  end;
end;

/// Overload sayımı + kaynak taramasıyla karşılaştırmak için RTTI envanteri.
procedure TFluentCodeGenerator.CollectRttiInventory;
var
  LMeth: TRttiMethod;
  LProp: TRttiProperty;
  LIdx: TRttiIndexedProperty;
  LCount: Integer;
begin
  for LProp in FType.GetDeclaredProperties do
    if (LProp.Parent = FType) and (LProp.Visibility >= mvPublic) then
      FRttiProps.AddOrSetValue(UpperCase(LProp.Name), 0);
  for LIdx in FType.GetIndexedProperties do
    if (LIdx.Parent = FType) and (LIdx.Visibility >= mvPublic) then
      FRttiProps.AddOrSetValue(UpperCase(LIdx.Name), 1);

  for LMeth in FType.GetDeclaredMethods do
  begin
    if not IsEligibleMethod(LMeth) then Continue;
    if FOverloads.TryGetValue(UpperCase(LMeth.Name), LCount) then
      FOverloads[UpperCase(LMeth.Name)] := LCount + 1
    else
      FOverloads.Add(UpperCase(LMeth.Name), 1);
    FRttiMethods.AddOrSetValue(UpperCase(LMeth.Name), Length(LMeth.GetParameters));
    if LMeth.MethodKind = mkFunction then
      FRttiFunctions.AddOrSetValue(UpperCase(LMeth.Name), 0);
  end;
end;

procedure TFluentCodeGenerator.EmitPrologue;
begin
  FDecls.AppendLine('    function AsInstance: ' + FInstanceTypeName + ';');
  FDecls.AppendLine('');
  FEmitted.Add(UpperCase('AsInstance'), 'kaçış kapısı');

  FBodies.AppendLine(Format('constructor %s.Create(AInstance: %s; AAutoFree: Boolean = False);',
    [FImplName, FInstanceTypeName]));
  FBodies.AppendLine('begin');
  FBodies.AppendLine('  inherited Create;');
  FBodies.AppendLine('  FInstance := AInstance;');
  FBodies.AppendLine('  FAutoFree := AAutoFree;');
  FBodies.AppendLine('end;');
  FBodies.AppendLine('');
  FBodies.AppendLine(Format('destructor %s.Destroy;', [FImplName]));
  FBodies.AppendLine('begin');
  FBodies.AppendLine('  if FAutoFree then');
  FBodies.AppendLine('    FInstance.Free;');
  FBodies.AppendLine('  inherited;');
  FBodies.AppendLine('end;');
  FBodies.AppendLine('');
  if fgoNewFactory in FOptions then
  begin
    FEmitted.AddOrSetValue(UpperCase('New'), 'fabrika');
    FBodies.AppendLine(Format('class function %s.New(AInstance: %s; AAutoFree: Boolean = False): %s;',
      [FImplName, FInstanceTypeName, FInterfaceName]));
    FBodies.AppendLine('begin');
    FBodies.AppendLine(Format('  Result := %s.Create(AInstance, AAutoFree);', [FImplName]));
    FBodies.AppendLine('end;');
    FBodies.AppendLine('');
    if FCanAutoCreate then
    begin
      FBodies.AppendLine(Format('class function %s.New: %s;', [FImplName, FInterfaceName]));
      FBodies.AppendLine('begin');
      FBodies.AppendLine(Format('  Result := %s.Create(%s, True);', [FImplName, FCreateExpr]));
      FBodies.AppendLine('end;');
      FBodies.AppendLine('');
    end;
  end;

  FBodies.AppendLine(Format('function %s.AsInstance: %s;', [FImplName, FInstanceTypeName]));
  FBodies.AppendLine('begin');
  FBodies.AppendLine('  Result := FInstance;');
  FBodies.AppendLine('end;');
  FBodies.AppendLine('');
end;

/// Set/Get çiftinin TEK üreticisi — basit property, indeksli property ve kaynaktan
/// gelen (RTTI'nin görmediği) property aynı çekirdeği kullanır. İmza ve gövde tek
/// yerde üretilir, böylece ikisi asla birbirinden sapamaz.
procedure TFluentCodeGenerator.EmitAccessorPair(const AName, ATypeName, AIndexParams,
  AIndexArgs, AValueIdent, ATag: string; AReadable, AWritable: Boolean);
var
  LAcc, LSetParams, LGetParams, LTarget, LClash: string;
begin
  if ATypeName = '' then
  begin
    Inc(FSkipCount);
    Note(Format('ATLANDI: property %s — tip adı RTTI''de yok.', [AName]));
    Exit;
  end;
  LAcc := AccessorName(AName);
  if AIndexArgs <> '' then
    LTarget := Format('FInstance.%s[%s]', [AName, AIndexArgs])
  else
    LTarget := 'FInstance.' + AName;

  if AWritable then
  begin
    LSetParams := Format('const %s: %s', [AValueIdent, ATypeName]);
    if AIndexParams <> '' then
      LSetParams := AIndexParams + '; ' + LSetParams;
    LClash := ClaimName('Set' + LAcc, 'property accessor');
    if (LClash <> '') and (fgoCollisionMarkers in FOptions) then FDecls.AppendLine(LClash);
    if ATag <> '' then FDecls.AppendLine('    ' + ATag);
    FDecls.AppendLine(Format('    function Set%s(%s): %s;', [LAcc, LSetParams, FInterfaceName]));

    FBodies.AppendLine(Format('function %s.Set%s(%s): %s;',
      [FImplName, LAcc, LSetParams, FInterfaceName]));
    FBodies.AppendLine('begin');
    FBodies.AppendLine(Format('  %s := %s;', [LTarget, AValueIdent]));
    FBodies.AppendLine('  Result := Self;');
    FBodies.AppendLine('end;');
    FBodies.AppendLine('');
  end;

  if AReadable then
  begin
    if AIndexParams <> '' then LGetParams := '(' + AIndexParams + ')' else LGetParams := '';
    LClash := ClaimName('Get' + LAcc, 'property accessor');
    if (LClash <> '') and (fgoCollisionMarkers in FOptions) then FDecls.AppendLine(LClash);
    if ATag <> '' then FDecls.AppendLine('    ' + ATag);
    FDecls.AppendLine(Format('    function Get%s%s: %s;', [LAcc, LGetParams, ATypeName]));

    FBodies.AppendLine(Format('function %s.Get%s%s: %s;',
      [FImplName, LAcc, LGetParams, ATypeName]));
    FBodies.AppendLine('begin');
    FBodies.AppendLine(Format('  Result := %s;', [LTarget]));
    FBodies.AppendLine('end;');
    FBodies.AppendLine('');
  end;
end;

procedure TFluentCodeGenerator.EmitProperties;
var
  LProp: TRttiProperty;
begin
  for LProp in FType.GetDeclaredProperties do
  begin
    if LProp.Parent <> FType then Continue; // class helper property'lerini dışarıda bırak
    if LProp.Visibility < mvPublic then Continue;
    Inc(FPropCount);
    RegisterUnitOf(LProp.PropertyType);
    EmitAccessorPair(LProp.Name, TypeNameOf(LProp.PropertyType), '', '',
      'a' + AccessorName(LProp.Name), '', LProp.IsReadable, LProp.IsWritable);
  end;
end;

procedure TFluentCodeGenerator.EmitIndexedProperties;
var
  LIdx: TRttiIndexedProperty;
  LArr: TArray<TRttiParameter>;
  LPar: TRttiParameter;
  LParams, LReason: string;
begin
  for LIdx in FType.GetIndexedProperties do
  begin
    if LIdx.Parent <> FType then Continue;
    if LIdx.Visibility < mvPublic then Continue;
    LArr := IndexParamsOf(LIdx);
    if not TryParamList(LArr, LParams, LReason) then
    begin
      Inc(FSkipCount);
      Note(Format('ATLANDI: indeksli property %s — %s', [LIdx.Name, LReason]));
      Continue;
    end;
    Inc(FIdxCount);
    RegisterUnitOf(LIdx.PropertyType);
    for LPar in LArr do
      RegisterUnitOf(LPar.ParamType);
    EmitAccessorPair(LIdx.Name, TypeNameOf(LIdx.PropertyType), LParams,
      ArgListFor(LArr), 'aValue', '', LIdx.IsReadable, LIdx.IsWritable);
  end;
end;

procedure TFluentCodeGenerator.EmitMethod(const AMeth: TRttiMethod);
var
  LParams, LArgs, LReason, LRet, LSig, LClash: string;
  LPar: TRttiParameter;
  LCount: Integer;
  LIsFunc: Boolean;
begin
  if not TryParamList(AMeth.GetParameters, LParams, LReason) then
  begin
    Inc(FSkipCount);
    Note(Format('ATLANDI: metod %s — %s', [AMeth.Name, LReason]));
    Exit;
  end;
  LIsFunc := AMeth.MethodKind = mkFunction;
  LRet := '';
  if LIsFunc then
  begin
    LRet := TypeNameOf(AMeth.ReturnType);
    if LRet = '' then
    begin
      Inc(FSkipCount);
      Note(Format('ATLANDI: fonksiyon %s — dönüş tipi RTTI''de yok.', [AMeth.Name]));
      Exit;
    end;
  end;

  Inc(FMethCount);
  RegisterUnitOf(AMeth.ReturnType);
  for LPar in AMeth.GetParameters do
    RegisterUnitOf(LPar.ParamType);
  LArgs := ArgListFor(AMeth.GetParameters);
  if LParams <> '' then LParams := '(' + LParams + ')';
  if LArgs <> '' then LArgs := '(' + LArgs + ')';

  if LIsFunc then
    LSig := Format('function %s%s: %s;', [AMeth.Name, LParams, LRet])
  else
    LSig := Format('procedure %s%s;', [AMeth.Name, LParams]);

  LClash := ClaimName(AMeth.Name, 'metod');
  if (LClash <> '') and (fgoCollisionMarkers in FOptions) then FDecls.AppendLine(LClash);
  if FOverloads.TryGetValue(UpperCase(AMeth.Name), LCount) and (LCount > 1) then
    FDecls.AppendLine('    ' + LSig + ' overload;')
  else
    FDecls.AppendLine('    ' + LSig);

  if LIsFunc then
    FBodies.AppendLine(Format('function %s.%s%s: %s;', [FImplName, AMeth.Name, LParams, LRet]))
  else
    FBodies.AppendLine(Format('procedure %s.%s%s;', [FImplName, AMeth.Name, LParams]));
  FBodies.AppendLine('begin');
  if LIsFunc then
    FBodies.AppendLine(Format('  Result := FInstance.%s%s;', [AMeth.Name, LArgs]))
  else
    FBodies.AppendLine(Format('  FInstance.%s%s;', [AMeth.Name, LArgs]));
  FBodies.AppendLine('end;');
  FBodies.AppendLine('');
end;

procedure TFluentCodeGenerator.EmitMethods;
var
  LMeth: TRttiMethod;
begin
  FDecls.AppendLine('');
  for LMeth in FType.GetDeclaredMethods do
  begin
    if not IsEligibleMethod(LMeth) then Continue;
    // Kaynak taraması bu metodun RTTI imzasının YANLIŞ olduğunu kanıtladıysa üretme:
    // yanlış imza ya derlenmez ya da sessizce dönüş değeri düşürür. Rapora yazıldı.
    if FSuspectMethods.IndexOf(LMeth.Name) >= 0 then
    begin
      Inc(FSkipCount);
      Continue;
    end;
    EmitMethod(LMeth);
  end;
end;

function TFluentCodeGenerator.ReadSourceLines: string;
var
  LSl: TStringList;
begin
  Result := '';
  LSl := TStringList.Create;
  try
    try
      LSl.LoadFromFile(FSourcePath);
      Result := LSl.Text;
    except
      on E: Exception do
        Note(Format('KAYNAK TARAMA: "%s" okunamadı — %s: %s',
          [FSourcePath, E.ClassName, E.Message]));
    end;
  finally
    LSl.Free;
  end;
end;

function TFluentCodeGenerator.ExtractClassBody(const ASource: string): string;
var
  LClean: string;
  LPos, I: Integer;
  LSl: TStringList;
  LSb: TStringBuilder;
begin
  Result := '';
  LClean := StripPascalComments(ASource);
  LPos := FindClassHeaderPos(LowerCase(LClean), LowerCase(FInstanceTypeName));
  if LPos = 0 then Exit;

  LSl := TStringList.Create;
  LSb := TStringBuilder.Create;
  try
    LSl.Text := Copy(LClean, LPos, MaxInt);
    for I := 0 to LSl.Count - 1 do
    begin
      if LowerCase(System.SysUtils.Trim(LSl[I])) = 'end;' then Break;
      LSb.AppendLine(LSl[I]);
    end;
    Result := LSb.ToString;
  finally
    LSb.Free;
    LSl.Free;
  end;
end;

/// Sınıf gövdesindeki public/published property bildirimlerini metinden okur.
/// Basit bir tarayıcıdır: iç içe tip bildirimi olan sınıflarda eksik/fazla okuyabilir.
function TFluentCodeGenerator.ParseSourceProperties(const ABody: string): TArray<TSourceProperty>;
const
  CTail: array [0 .. 8] of string = (' read ', ' write ', ' index ', ' default ',
    ' stored ', ' implements ', ' nodefault', ' readonly', ' writeonly');
var
  LSl: TStringList;
  LTrim, LLow, LStmt, LRest, LLowStmt, LAfter, LLowAfter: string;
  LVisible: Boolean;
  I, J, LCut, LK, LBr: Integer;
  LProp: TSourceProperty;
  LList: TList<TSourceProperty>;
begin
  LList := TList<TSourceProperty>.Create;
  LSl := TStringList.Create;
  try
    LSl.Text := ABody;
    LVisible := False;
    LStmt := '';
    for I := 0 to LSl.Count - 1 do
    begin
      LTrim := System.SysUtils.Trim(LSl[I]);
      if LTrim = '' then Continue;
      LLow := LowerCase(LTrim);
      if (LLow = 'private') or (LLow = 'strict private') or (LLow = 'protected') or
         (LLow = 'strict protected') then
      begin
        LVisible := False; LStmt := ''; Continue;
      end;
      if (LLow = 'public') or (LLow = 'published') then
      begin
        LVisible := True; LStmt := ''; Continue;
      end;
      if not LVisible then Continue;

      if LStmt = '' then LStmt := LTrim else LStmt := LStmt + ' ' + LTrim;
      if (LStmt[Length(LStmt)] <> ';') or (BracketDepth(LStmt) <> 0) then Continue;

      LLowStmt := LowerCase(LStmt);
      if LLowStmt.StartsWith('property ') then
      begin
        LProp := Default(TSourceProperty);
        LRest := System.SysUtils.Trim(Copy(LStmt, Length('property ') + 1, MaxInt));
        J := 1;
        while (J <= Length(LRest)) and
              CharInSet(LRest[J], ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(J);
        LProp.Name := Copy(LRest, 1, J - 1);
        LRest := System.SysUtils.Trim(Copy(LRest, J, MaxInt));
        if LRest.StartsWith('[') then
        begin
          LBr := System.Pos(']', LRest);
          if LBr > 0 then
          begin
            LProp.IndexParams := System.SysUtils.Trim(Copy(LRest, 2, LBr - 2));
            LRest := System.SysUtils.Trim(Copy(LRest, LBr + 1, MaxInt));
          end;
        end;
        if LRest.StartsWith(':') then
        begin
          LAfter := System.SysUtils.Trim(Copy(LRest, 2, MaxInt));
          LLowAfter := LowerCase(LAfter);
          LCut := Length(LAfter) + 1;
          for J := Low(CTail) to High(CTail) do
          begin
            LK := System.Pos(CTail[J], LLowAfter);
            if (LK > 0) and (LK < LCut) then LCut := LK;
          end;
          LProp.TypeName := System.SysUtils.Trim(Copy(LAfter, 1, LCut - 1));
          while (LProp.TypeName <> '') and (LProp.TypeName[Length(LProp.TypeName)] = ';') do
            SetLength(LProp.TypeName, Length(LProp.TypeName) - 1);
          LProp.TypeName := System.SysUtils.Trim(LProp.TypeName);
          LProp.IsReadable := System.Pos(' read ', ' ' + LLowStmt + ' ') > 0;
          LProp.IsWritable := System.Pos(' write ', ' ' + LLowStmt + ' ') > 0;
          if (LProp.Name <> '') and (LProp.TypeName <> '') then
            LList.Add(LProp);
        end;
      end;
      LStmt := '';
    end;
    Result := LList.ToArray;
  finally
    LSl.Free;
    LList.Free;
  end;
end;

/// Kaynakta bildirilen ama RTTI'de hiç/eksik görünen metodları rapora yazar.
procedure TFluentCodeGenerator.CheckSourceMethods(const ABody: string);
var
  LSl: TStringList;
  LTrim, LLow, LName: string;
  LVisible, LIsFunc: Boolean;
  I, J, LParamCount: Integer;
begin
  LSl := TStringList.Create;
  try
    LSl.Text := ABody;
    LVisible := False;
    for I := 0 to LSl.Count - 1 do
    begin
      LTrim := System.SysUtils.Trim(LSl[I]);
      LLow := LowerCase(LTrim);
      if (LLow = 'private') or (LLow = 'strict private') or (LLow = 'protected') or
         (LLow = 'strict protected') then LVisible := False
      else if (LLow = 'public') or (LLow = 'published') then LVisible := True;
      if not LVisible then Continue;
      if not (LLow.StartsWith('procedure ') or LLow.StartsWith('function ')) then Continue;
      LIsFunc := LLow.StartsWith('function ');

      // DİKKAT: Trim şart — "function  Encrypt(...)" gibi ÇİFT BOŞLUKLU bildirimler
      // (TMS kaynaklarında yaygın) aksi hâlde sessizce atlanıyordu.
      LTrim := System.SysUtils.Trim(Copy(LTrim, System.Pos(' ', LTrim) + 1, MaxInt));
      J := 1;
      while (J <= Length(LTrim)) and
            CharInSet(LTrim[J], ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(J);
      LName := Copy(LTrim, 1, J - 1);
      if LName = '' then Continue;

      if not FRttiMethods.TryGetValue(UpperCase(LName), LParamCount) then
        Note(Format('RTTI GÖREMEDİ: metod %s kaynakta var ama RTTI''de yok — elle ekle.', [LName]))
      else
      begin
        if (System.Pos('(', LTrim) > 0) and (LParamCount = 0) then
        begin
          Note(Format('ÜRETİLMEDİ: metod %s kaynakta parametreli, RTTI''de parametresiz görünüyor ' +
            '(bir parametre tipinin RTTI''si yok) — doğru imza RTTI''den kurulamaz, elle ekle.', [LName]));
          if FSuspectMethods.IndexOf(LName) < 0 then FSuspectMethods.Add(LName);
        end;
        // Kaynakta function, RTTI'de procedure => dönüş tipinin RTTI'si yok; üretilen
        // pass-through dönüş değerini SESSİZCE düşürür. Bu, AV'den daha sinsi bir hata.
        if LIsFunc and not FRttiFunctions.ContainsKey(UpperCase(LName)) then
        begin
          Note(Format('ÜRETİLMEDİ: %s kaynakta function, RTTI''de procedure görünüyor ' +
            '(dönüş tipinin RTTI''si yok) — üretilseydi dönüş değeri sessizce düşerdi, elle ekle.', [LName]));
          if FSuspectMethods.IndexOf(LName) < 0 then FSuspectMethods.Add(LName);
        end;
      end;
    end;
  finally
    LSl.Free;
  end;
end;

procedure TFluentCodeGenerator.ScanSource;
var
  LBody: string;
  LProps: TArray<TSourceProperty>;
  LP: TSourceProperty;
  LArgs: string;
begin
  if FSourcePath = '' then Exit;
  LBody := ExtractClassBody(ReadSourceLines);
  if LBody = '' then
  begin
    Note(Format('KAYNAK TARAMA: "%s" içinde "%s" sınıf bildirimi bulunamadı.',
      [FSourcePath, FInstanceTypeName]));
    Exit;
  end;

  LProps := ParseSourceProperties(LBody);
  for LP in LProps do
  begin
    if FRttiProps.ContainsKey(UpperCase(LP.Name)) then Continue;
    Inc(FSourceCount);
    Note(Format('RTTI GÖREMEDİ, kaynaktan üretildi: property %s: %s', [LP.Name, LP.TypeName]));
    // Bu tipin unit'i RTTI'den ÖĞRENİLEMEZ (RTTI'si yok). Nitelenmiş yazılmışsa
    // oradan çıkar; değilse unit çözümü kaynak uses'una devredilir (AssembleUnit).
    RegisterUnitsInTypeName(LP.TypeName);
    if FUnresolvedTypes.IndexOf(LP.TypeName) < 0 then
      FUnresolvedTypes.Add(LP.TypeName);
    LArgs := ArgsFromParamText(LP.IndexParams);
    if LP.IndexParams <> '' then
      EmitAccessorPair(LP.Name, LP.TypeName, LP.IndexParams, LArgs, 'aValue',
        '// [KAYNAK] RTTI bu üyeyi görmedi (tipinin RTTI''si yok); kaynaktan alındı.',
        LP.IsReadable, LP.IsWritable)
    else
      EmitAccessorPair(LP.Name, LP.TypeName, '', '', 'a' + AccessorName(LP.Name),
        '// [KAYNAK] RTTI bu üyeyi görmedi (tipinin RTTI''si yok); kaynaktan alındı.',
        LP.IsReadable, LP.IsWritable);
  end;

  CheckSourceMethods(LBody);
end;

function TFluentCodeGenerator.BuildHeaderReport: string;
var
  LSb: TStringBuilder;
  I: Integer;
begin
  LSb := TStringBuilder.Create;
  try
    LSb.AppendLine('// ===========================================================================');
    LSb.AppendLine(Format('// GenerateFluentCode raporu — %s', [FInstanceTypeName]));
    LSb.AppendLine('// ===========================================================================');
    LSb.AppendLine(Format('// Üretilen: %d property, %d indeksli property, %d metod, %d kaynaktan.',
      [FPropCount, FIdxCount, FMethCount, FSourceCount]));
    if FSourcePath = '' then
      LSb.AppendLine('// Kaynak taraması YAPILMADI (AUnitSourcePath verilmedi). Açık değer atanmış')
    else
      LSb.AppendLine(Format('// Kaynak taraması: %s', [FSourcePath]));
    if FSourcePath = '' then
      LSb.AppendLine('// enum tipindeki (ör. TX = (a = 128)) property''ler RTTI''de GÖRÜNMEZ ve burada');
    if FSourcePath = '' then
      LSb.AppendLine('// EKSİK KALIR. Tam liste için .pas yolunu ver.');
    if FNotes.Count = 0 then
      LSb.AppendLine('// Not yok — RTTI ile kaynak arasında fark bulunmadı.')
    else
      for I := 0 to FNotes.Count - 1 do
        LSb.AppendLine('// * ' + FNotes[I]);
    LSb.AppendLine('// Üretilen kodu her zaman gözden geçir (class helper sızıntısı, çakışmalar).');
    LSb.AppendLine('// ===========================================================================');
    LSb.AppendLine('');
    Result := LSb.ToString;
  finally
    LSb.Free;
  end;
end;

/// Interface + implementasyon class TANIMLARI — Assemble ve AssembleUnit'in
/// ortak çekirdeği (iki çıktı biçimi asla birbirinden sapmasın diye tek yerde).
procedure TFluentCodeGenerator.AppendTypeDecls(ASb: TStringBuilder);
begin
  ASb.AppendLine('  ' + FInterfaceName + ' = interface');
  if fgoInterfaceGuid in FOptions then
    ASb.AppendLine('    [' + QuotedStr(FGuidText) + ']');
  ASb.Append(FDecls.ToString);
  ASb.AppendLine('  end;');
  ASb.AppendLine('');

  ASb.AppendLine('  ' + FImplName + ' = class(TInterfacedObject, ' + FInterfaceName + ')');
  ASb.AppendLine('  strict private');
  ASb.AppendLine('    FInstance: ' + FInstanceTypeName + ';');
  ASb.AppendLine('    FAutoFree: Boolean;');
  ASb.AppendLine('  public');
  ASb.AppendLine(Format('    constructor Create(AInstance: %s; AAutoFree: Boolean = False);',
    [FInstanceTypeName]));
  ASb.AppendLine('    destructor Destroy; override;');
  // New yalnızca BURADA — interface'ler class metodu taşıyamaz, o yüzden
  // FDecls'e (iki tarafta da tekrarlanan ortak listeye) konulamaz.
  if fgoNewFactory in FOptions then
  begin
    ASb.AppendLine('    /// Var olan bir örneği sarar. Ömür ÇAĞIRANIN sorumluluğundadır.');
    if FCanAutoCreate then
    begin
      ASb.AppendLine(Format('    class function New(AInstance: %s; AAutoFree: Boolean = False): %s; overload;',
        [FInstanceTypeName, FInterfaceName]));
      ASb.AppendLine('    /// Örneği KENDİSİ yaratır ve SAHİPLENİR — arayüz serbest kalınca free eder.');
      ASb.AppendLine(Format('    class function New: %s; overload;', [FInterfaceName]));
    end
    else
      ASb.AppendLine(Format('    class function New(AInstance: %s; AAutoFree: Boolean = False): %s;',
        [FInstanceTypeName, FInterfaceName]));
  end;
  ASb.Append(FDecls.ToString);
  ASb.AppendLine('  end;');
end;

function TFluentCodeGenerator.Assemble: string;
var
  LSb: TStringBuilder;
begin
  LSb := TStringBuilder.Create;
  try
    if fgoHeaderReport in FOptions then
      LSb.Append(BuildHeaderReport);
    AppendTypeDecls(LSb);
    LSb.AppendLine('');
    LSb.AppendLine('// ---------------------------------------------------------------------------');
    LSb.AppendLine('// Implementasyon gövdeleri (unit''in implementation bölümüne eklenecek)');
    LSb.AppendLine('// ---------------------------------------------------------------------------');
    LSb.Append(FBodies.ToString);
    Result := LSb.ToString;
  finally
    LSb.Free;
  end;
end;

/// Derlenmeye hazır TAM unit metni: unit başlığı + çözülmüş uses + tipler + gövdeler.
/// RTTI'nin göremediği tipler varsa, tiplerinin hangi unit'te bildirildiği
/// RTTI'den öğrenilemez — sarmalanan sınıfın kendi interface uses'u devreye girer.
procedure TFluentCodeGenerator.ResolveSourceUses;
var
  LOne: string;
begin
  FUsesFromSource := False;
  if (FUnresolvedTypes.Count = 0) or (FSourcePath = '') then Exit;
  for LOne in ParseSourceUses(ReadSourceLines) do
  begin
    if FUsedUnits.IndexOf(LOne) < 0 then FUsesFromSource := True;
    AddUsedUnit(LOne);
  end;
end;

class function TFluentCodeGenerator.RegionKeyFor(const AClassName, AKind: string): string;
begin
  // Anahtar SABİT tutulur; etiketin okunabilir kısmı değişse bile bulunabilsin.
  Result := Format('RAD-FLUENT:%s:%s', [AClassName, AKind]);
end;

function TFluentCodeGenerator.TypesRegionText: string;
var
  LSb: TStringBuilder;
begin
  LSb := TStringBuilder.Create;
  try
    LSb.AppendLine(Format('{$REGION ''%s — ÜRETİLMİŞTİR; bu bloğu elle düzenleme, yeniden üretimde kaybolur''}',
      [RegionKeyFor(FInstanceTypeName, 'TYPES')]));
    if fgoHeaderReport in FOptions then
      LSb.Append(BuildHeaderReport);
    // Kendi 'type' anahtarını taşır: böylece interface'in HERHANGİ bir yerine
    // eklenebilir, mevcut bir type bloğunun içine sızdırmaya gerek kalmaz.
    LSb.AppendLine('type');
    AppendTypeDecls(LSb);
    LSb.AppendLine('{$ENDREGION}');
    Result := LSb.ToString;
  finally
    LSb.Free;
  end;
end;

function TFluentCodeGenerator.ImplRegionText: string;
var
  LSb: TStringBuilder;
begin
  LSb := TStringBuilder.Create;
  try
    LSb.AppendLine(Format('{$REGION ''%s — ÜRETİLMİŞTİR; bu bloğu elle düzenleme, yeniden üretimde kaybolur''}',
      [RegionKeyFor(FInstanceTypeName, 'IMPL')]));
    LSb.Append(FBodies.ToString);
    LSb.AppendLine('{$ENDREGION}');
    Result := LSb.ToString;
  finally
    LSb.Free;
  end;
end;

function TFluentCodeGenerator.AssembleUnit(const AUnitName: string): string;
var
  LSb: TStringBuilder;
  LLine: string;
  I: Integer;
begin
  LSb := TStringBuilder.Create;
  try
    LSb.AppendLine('unit ' + AUnitName + ';');
    LSb.AppendLine('');
    LSb.AppendLine('interface');
    LSb.AppendLine('');

    if FUsedUnits.Count = 0 then
      LSb.AppendLine('// uses gerekmedi — hiçbir dış tipe başvurulmadı.')
    else
    begin
      if FUsesFromSource then
      begin
        LSb.AppendLine('// NOT: aşağıdaki uses listesinin bir bölümü, RTTI''nin göremediği tipler');
        LSb.AppendLine('// yüzünden kaynak unit''in kendi uses''undan alındı; bir kısmı gereksiz');
        LSb.AppendLine('// olabilir. Derledikten sonra kullanılmayanları silebilirsin.');
      end;
      LSb.AppendLine('uses');
      LLine := '';
      for I := 0 to FUsedUnits.Count - 1 do
      begin
        if LLine = '' then
          LLine := '  ' + FUsedUnits[I]
        else if Length(LLine) + Length(FUsedUnits[I]) + 2 > 100 then
        begin
          LSb.AppendLine(LLine + ',');
          LLine := '  ' + FUsedUnits[I];
        end
        else
          LLine := LLine + ', ' + FUsedUnits[I];
      end;
      LSb.AppendLine(LLine + ';');
    end;

    LSb.AppendLine('');
    LSb.Append(TypesRegionText);
    LSb.AppendLine('');
    LSb.AppendLine('implementation');
    LSb.AppendLine('');
    LSb.Append(ImplRegionText);
    LSb.AppendLine('');
    LSb.AppendLine('end.');
    Result := LSb.ToString;
  finally
    LSb.Free;
  end;
end;

procedure TFluentCodeGenerator.Build;
begin
  ResolveNames;
  DetectConstructor;
  CollectRttiInventory;
  EmitPrologue;
  EmitProperties;
  EmitIndexedProperties;
  ScanSource;
  EmitMethods;
  ResolveSourceUses;
end;

procedure TFluentCodeGenerator.Prepare;
begin
  Build;
end;

function TFluentCodeGenerator.Execute: string;
begin
  Build;
  Result := Assemble;
end;

function TFluentCodeGenerator.ExecuteUnit(const AUnitName: string): string;
begin
  Build;
  Result := AssembleUnit(AUnitName);
end;

{ GenerateFluentCode — public API (ince sarmalayıcı) }

function GenerateFluentCode(AClass: TClass; const AUnitSourcePath: string;
  AOptions: TFluentGenOptions): string;
var
  LGen: TFluentCodeGenerator;
begin
  if AClass = nil then
    raise EFluentCodeGen.Create('GenerateFluentCode: AClass nil olamaz.');

  LGen := TFluentCodeGenerator.Create(AClass, AUnitSourcePath, AOptions);
  try
    Result := LGen.Execute;
  finally
    LGen.Free;
  end;
end;

{ GenerateFluentUnit — public API }

/// Pascal unit adı olarak geçerli mi (harf/alt çizgi ile başlar, noktalı namespace
/// adlarına izin verir, ardışık/sonda nokta olamaz).
function IsValidUnitName(const AName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if AName = '' then Exit;
  if not CharInSet(AName[1], ['A'..'Z', 'a'..'z', '_']) then Exit;
  if AName[Length(AName)] = '.' then Exit;
  for I := 2 to Length(AName) do
  begin
    if not CharInSet(AName[I], ['A'..'Z', 'a'..'z', '0'..'9', '_', '.']) then Exit;
    if (AName[I] = '.') and (AName[I - 1] = '.') then Exit;
  end;
  Result := True;
end;

type
  { Mevcut bir unit dosyasına REGION bloklarını ekler/günceller. Dosyanın geri
    kalanına DOKUNMAZ — başka sınıfların blokları, elle yazılmış kod ve uses'taki
    fazladan unit'ler olduğu gibi kalır. }
  TFluentUnitMerger = class
  strict private
    FLines: TStringList;
    function LowerAt(AIndex: Integer): string;
    function FindStandalone(const AWord: string): Integer;
    function FindLast(const AWord: string): Integer;
    function FindRegion(const AKey: string; out AStart, AEnd: Integer): Boolean;
    procedure PutBlock(AIndex: Integer; const ABlock: string);
  public
    constructor Create(const AFileName: string);
    destructor Destroy; override;
    function ExistingGuid(const AKey: string): string;
    procedure MergeRegion(const AKey, ABlock: string; AIsImpl: Boolean);
    procedure MergeUses(AUnits: TStrings);
    function RegionClassNames: TArray<string>;
    function RemoveClassRegions(const AClassName: string): Boolean;
    procedure Save(const AFileName: string);
  end;

constructor TFluentUnitMerger.Create(const AFileName: string);
begin
  inherited Create;
  FLines := TStringList.Create;
  FLines.LoadFromFile(AFileName);
  if FindStandalone('interface') < 0 then
    raise EFluentCodeGen.CreateFmt(
      'GenerateFluentUnit: "%s" bir Pascal unit''i gibi görünmüyor (tek başına "interface" satırı yok).',
      [AFileName]);
  if FindLast('end.') < 0 then
    raise EFluentCodeGen.CreateFmt(
      'GenerateFluentUnit: "%s" içinde kapanış "end." satırı bulunamadı.', [AFileName]);
end;

destructor TFluentUnitMerger.Destroy;
begin
  FLines.Free;
  inherited;
end;

function TFluentUnitMerger.LowerAt(AIndex: Integer): string;
begin
  Result := LowerCase(System.SysUtils.Trim(FLines[AIndex]));
end;

function TFluentUnitMerger.FindStandalone(const AWord: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FLines.Count - 1 do
    if LowerAt(I) = AWord then Exit(I);
  Result := -1;
end;

function TFluentUnitMerger.FindLast(const AWord: string): Integer;
var
  I: Integer;
begin
  for I := FLines.Count - 1 downto 0 do
    if LowerAt(I) = AWord then Exit(I);
  Result := -1;
end;

/// Anahtarı taşıyan {$REGION} satırını ve EŞLEŞEN {$ENDREGION}'ı bulur (iç içe
/// bölgeleri sayarak — üretilen içerikte olmaz ama elle eklenmişse bozulmasın).
function TFluentUnitMerger.FindRegion(const AKey: string; out AStart, AEnd: Integer): Boolean;
var
  I, LDepth: Integer;
  LLow: string;
begin
  AStart := -1;
  AEnd := -1;
  for I := 0 to FLines.Count - 1 do
  begin
    LLow := LowerAt(I);
    if LLow.StartsWith('{$region') and FLines[I].Contains(AKey) then
    begin
      AStart := I;
      Break;
    end;
  end;
  if AStart < 0 then Exit(False);

  LDepth := 1;
  for I := AStart + 1 to FLines.Count - 1 do
  begin
    LLow := LowerAt(I);
    if LLow.StartsWith('{$region') then Inc(LDepth)
    else if LLow.StartsWith('{$endregion') then
    begin
      Dec(LDepth);
      if LDepth = 0 then
      begin
        AEnd := I;
        Exit(True);
      end;
    end;
  end;
  raise EFluentCodeGen.CreateFmt(
    'GenerateFluentUnit: "%s" bölgesinin {$ENDREGION} karşılığı bulunamadı.', [AKey]);
end;

function TFluentUnitMerger.ExistingGuid(const AKey: string): string;
var
  LStart, LEnd, I, LOpen, LClose: Integer;
  LText: string;
begin
  Result := '';
  if not FindRegion(AKey, LStart, LEnd) then Exit;
  for I := LStart to LEnd do
  begin
    LText := FLines[I];
    LOpen := System.Pos('[''', LText);
    LClose := System.Pos(''']', LText);
    if (LOpen > 0) and (LClose > LOpen) then
      Exit(Copy(LText, LOpen + 2, LClose - LOpen - 2));
  end;
end;

procedure TFluentUnitMerger.PutBlock(AIndex: Integer; const ABlock: string);
var
  LSl: TStringList;
  I: Integer;
begin
  LSl := TStringList.Create;
  try
    LSl.Text := ABlock;
    // TStringList.Text sondaki bos satiri yutar/ekler; blok satirlarini oldugu gibi al.
    for I := LSl.Count - 1 downto 0 do
      FLines.Insert(AIndex, LSl[I]);
  finally
    LSl.Free;
  end;
end;

procedure TFluentUnitMerger.MergeRegion(const AKey, ABlock: string; AIsImpl: Boolean);
var
  LStart, LEnd, LAt, I: Integer;
begin
  if FindRegion(AKey, LStart, LEnd) then
  begin
    for I := LEnd downto LStart do
      FLines.Delete(I);
    PutBlock(LStart, ABlock);
    Exit;
  end;

  // Bölge yok: TYPES 'implementation'dan hemen önce, IMPL son 'end.'dan hemen önce.
  if AIsImpl then
    LAt := FindLast('end.')
  else
    LAt := FindStandalone('implementation');
  if LAt < 0 then
    raise EFluentCodeGen.CreateFmt(
      'GenerateFluentUnit: "%s" bloğu için ekleme noktası bulunamadı.', [AKey]);
  FLines.Insert(LAt, '');
  PutBlock(LAt, ABlock);
end;

/// Eksik unit'leri MEVCUT interface uses cümlesinin sonuna ekler. Hiçbir şey silinmez,
/// mevcut biçimlendirme bozulmaz. uses yoksa 'interface'ten sonra yeni bir tane açar.
procedure TFluentUnitMerger.MergeUses(AUnits: TStrings);
var
  LIface, LImpl, LStart, LTerm, I, LSemi: Integer;
  LJoined, LOne, LAdd: string;
  LHave: TStringList;
begin
  if AUnits.Count = 0 then Exit;
  LIface := FindStandalone('interface');
  LImpl := FindStandalone('implementation');
  if LImpl < 0 then LImpl := FLines.Count;

  LStart := -1;
  for I := LIface + 1 to LImpl - 1 do
    if LowerAt(I).StartsWith('uses') then
    begin
      LStart := I;
      Break;
    end;

  LHave := TStringList.Create;
  try
    LHave.CaseSensitive := False;
    if LStart >= 0 then
    begin
      LTerm := -1;
      LJoined := '';
      for I := LStart to LImpl - 1 do
      begin
        LJoined := LJoined + ' ' + FLines[I];
        if System.Pos(';', FLines[I]) > 0 then
        begin
          LTerm := I;
          Break;
        end;
      end;
      if LTerm < 0 then
        raise EFluentCodeGen.Create(
          'GenerateFluentUnit: interface uses cümlesi '';'' ile kapanmıyor, birleştirilemedi.');

      LJoined := System.SysUtils.Trim(Copy(LJoined, System.Pos('uses', LowerCase(LJoined)) + 4, MaxInt));
      LSemi := System.Pos(';', LJoined);
      if LSemi > 0 then LJoined := Copy(LJoined, 1, LSemi - 1);
      for LOne in LJoined.Split([',']) do
        if System.SysUtils.Trim(LOne) <> '' then
          LHave.Add(System.SysUtils.Trim(LOne));

      LAdd := '';
      for I := 0 to AUnits.Count - 1 do
        // Nitelenmiş/niteliksiz ikizler aynı unit'tir; ikisini birden yazmak E2004 verir.
        if not UnitListHas(LHave, AUnits[I]) then
          LAdd := LAdd + ', ' + AUnits[I];
      if LAdd = '' then Exit;

      // Kapanış ';' yerine ", Yeni1, Yeni2;" yaz — biçimlendirmenin gerisi bozulmaz.
      LSemi := System.Pos(';', FLines[LTerm]);
      FLines[LTerm] := Copy(FLines[LTerm], 1, LSemi - 1) + LAdd + ';' +
        Copy(FLines[LTerm], LSemi + 1, MaxInt);
    end
    else
    begin
      LAdd := '';
      for I := 0 to AUnits.Count - 1 do
        if LAdd = '' then LAdd := AUnits[I] else LAdd := LAdd + ', ' + AUnits[I];
      FLines.Insert(LIface + 1, '');
      FLines.Insert(LIface + 2, 'uses');
      FLines.Insert(LIface + 3, '  ' + LAdd + ';');
    end;
  finally
    LHave.Free;
  end;
end;

/// Dosyadaki her RAD-FLUENT bölgesinin sınıf adını (tekilleştirilmiş) döndürür.
/// Anahtar biçimi: RAD-FLUENT:<Sinif>:<TURU>
function TFluentUnitMerger.RegionClassNames: TArray<string>;
const
  CPrefix = 'RAD-FLUENT:';
var
  I, LAt, LColon: Integer;
  LText, LRest, LName: string;
  LList: TStringList;
begin
  LList := TStringList.Create;
  try
    LList.CaseSensitive := False;
    for I := 0 to FLines.Count - 1 do
    begin
      if not LowerAt(I).StartsWith('{$region') then Continue;
      LText := FLines[I];
      LAt := System.Pos(CPrefix, LText);
      if LAt = 0 then Continue;
      LRest := Copy(LText, LAt + Length(CPrefix), MaxInt);
      LColon := System.Pos(':', LRest);
      if LColon <= 1 then Continue;
      LName := System.SysUtils.Trim(Copy(LRest, 1, LColon - 1));
      if (LName <> '') and (LList.IndexOf(LName) < 0) then
        LList.Add(LName);
    end;
    Result := LList.ToStringArray;
  finally
    LList.Free;
  end;
end;

/// Bir sınıfın TYPES ve IMPL bölgelerini siler. Bölge bulunup silindiyse True.
function TFluentUnitMerger.RemoveClassRegions(const AClassName: string): Boolean;
var
  LKind, LKey: string;
  LStart, LEnd, I: Integer;
begin
  Result := False;
  for LKind in TArray<string>.Create('TYPES', 'IMPL') do
  begin
    LKey := TFluentCodeGenerator.RegionKeyFor(AClassName, LKind);
    if FindRegion(LKey, LStart, LEnd) then
    begin
      for I := LEnd downto LStart do
        FLines.Delete(I);
      Result := True;
    end;
  end;
end;

procedure TFluentUnitMerger.Save(const AFileName: string);
begin
  // UTF-8 + BOM: kitin delphi-encoding kuralı. Üretilen içerik Türkçe karakter
  // taşıdığı için ANSI olarak yazmak veri kaybı olurdu.
  FLines.SaveToFile(AFileName, TEncoding.UTF8);
end;

function ListFluentRegions(const AUnitPath: string): TArray<string>;
var
  LMerger: TFluentUnitMerger;
begin
  if not FileExists(AUnitPath) then
    raise EFluentCodeGen.CreateFmt('ListFluentRegions: "%s" bulunamadı.', [AUnitPath]);
  LMerger := TFluentUnitMerger.Create(AUnitPath);
  try
    Result := LMerger.RegionClassNames;
  finally
    LMerger.Free;
  end;
end;

function PruneFluentRegions(const AUnitPath: string;
  const AKeepClassNames: array of string; ADryRun: Boolean): TArray<string>;
var
  LMerger: TFluentUnitMerger;
  LName, LKeep: string;
  LKeepList, LRemoved: TStringList;
  LChanged: Boolean;
begin
  if not FileExists(AUnitPath) then
    raise EFluentCodeGen.CreateFmt('PruneFluentRegions: "%s" bulunamadı.', [AUnitPath]);

  LMerger := TFluentUnitMerger.Create(AUnitPath);
  LKeepList := TStringList.Create;
  LRemoved := TStringList.Create;
  try
    LKeepList.CaseSensitive := False;
    for LKeep in AKeepClassNames do
      if System.SysUtils.Trim(LKeep) <> '' then
        LKeepList.Add(System.SysUtils.Trim(LKeep));

    LChanged := False;
    for LName in LMerger.RegionClassNames do
    begin
      if LKeepList.IndexOf(LName) >= 0 then Continue;
      LRemoved.Add(LName);
      // Kuru koşuda diske hiç dokunmuyoruz; yine de neyin silineceğini
      // gerçekten bulup bulamadığımızı bilmek için silme YAPMIYORUZ.
      if not ADryRun then
        if LMerger.RemoveClassRegions(LName) then
          LChanged := True;
    end;

    if (not ADryRun) and LChanged then
      LMerger.Save(AUnitPath);

    Result := LRemoved.ToStringArray;
  finally
    LRemoved.Free;
    LKeepList.Free;
    LMerger.Free;
  end;
end;

function GenerateFluentUnit(AClass: TClass; const AOutputPath: string;
  const AUnitSourcePath: string; AOptions: TFluentGenOptions;
  AWriteMode: TFluentUnitWriteMode): string;
var
  LGen: TFluentCodeGenerator;
  LMerger: TFluentUnitMerger;
  LUnitName, LContent, LDir, LTypesKey, LImplKey: string;
  LSl: TStringList;
begin
  if AClass = nil then
    raise EFluentCodeGen.Create('GenerateFluentUnit: AClass nil olamaz.');
  if System.SysUtils.Trim(AOutputPath) = '' then
    raise EFluentCodeGen.Create('GenerateFluentUnit: AOutputPath boş olamaz.');

  // Delphi'de unit adı DOSYA ADIYLA aynı olmak ZORUNDA — adı yoldan türetiyoruz.
  LUnitName := ChangeFileExt(ExtractFileName(AOutputPath), '');
  if not IsValidUnitName(LUnitName) then
    raise EFluentCodeGen.CreateFmt(
      'GenerateFluentUnit: "%s" geçerli bir Pascal unit adı değil (dosya adından türetildi).',
      [LUnitName]);

  if FileExists(AOutputPath) then
  begin
    if AWriteMode = fumFailIfExists then
      raise EFluentCodeGen.CreateFmt(
        'GenerateFluentUnit: "%s" zaten var. İçine eklemek için fumMergeRegions, ' +
        'baştan yazmak için fumReplaceFile ver.', [AOutputPath]);

    if AWriteMode = fumMergeRegions then
    begin
      LTypesKey := TFluentCodeGenerator.RegionKeyFor(AClass.ClassName, 'TYPES');
      LImplKey := TFluentCodeGenerator.RegionKeyFor(AClass.ClassName, 'IMPL');
      LMerger := TFluentUnitMerger.Create(AOutputPath);
      try
        LGen := TFluentCodeGenerator.Create(AClass, AUnitSourcePath, AOptions);
        try
          // Dosyada bu sınıfın GUID'i varsa AYNISINI kullan (idempotent birleştirme).
          LGen.PresetGuid := LMerger.ExistingGuid(LTypesKey);
          LGen.Prepare;
          LMerger.MergeUses(LGen.UsedUnits);
          LMerger.MergeRegion(LTypesKey, LGen.TypesRegionText, False);
          LMerger.MergeRegion(LImplKey, LGen.ImplRegionText, True);
        finally
          LGen.Free;
        end;
        LMerger.Save(AOutputPath);
      finally
        LMerger.Free;
      end;
      Exit(AOutputPath);
    end;
  end;

  // Dosya yok, ya da fumReplaceFile: tam unit üret.
  LGen := TFluentCodeGenerator.Create(AClass, AUnitSourcePath, AOptions);
  try
    LContent := LGen.ExecuteUnit(LUnitName);
  finally
    LGen.Free;
  end;

  LDir := ExtractFilePath(AOutputPath);
  if (LDir <> '') and not DirectoryExists(LDir) then
    if not ForceDirectories(LDir) then
      raise EFluentCodeGen.CreateFmt('GenerateFluentUnit: "%s" klasörü oluşturulamadı.', [LDir]);

  LSl := TStringList.Create;
  try
    LSl.Text := LContent;
    LSl.SaveToFile(AOutputPath, TEncoding.UTF8);
  finally
    LSl.Free;
  end;

  Result := AOutputPath;
end;



const
  CDateTolerance: Double = 1.157407407407407E-9; // ~0.1 ms, TDateTime gün biriminde

function DateEQ(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := Abs(ADate1 - ADate2) < CDateTolerance;
end;

function DateLT(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := (ADate2 - ADate1) >= CDateTolerance;
end;

function DateLE(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := not DateGT(ADate1, ADate2);
end;

function DateGT(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := (ADate1 - ADate2) >= CDateTolerance;
end;

function DateGE(const ADate1, ADate2: TDateTime): Boolean;
begin
  Result := not DateLT(ADate1, ADate2);
end;

function FixDT(const ADate: TDateTime): TDateTime;
begin
  Result := Round(ADate * MSecsPerDay) / MSecsPerDay;
end;

function DayOfMonth2Date(AYear, AMonth, AWeekInMonth, ADayInWeek: Word): TDateTime;
var
  LFirstOfMonth, LLastOfMonth, LResult: TDateTime;
  LFirstDow: Word;
  LOffset: Integer;
begin
  LFirstOfMonth := EncodeDate(AYear, AMonth, 1);
  LFirstDow := DayOfWeek(LFirstOfMonth); // 1=Pazar..7=Cumartesi
  LOffset := ADayInWeek - LFirstDow;
  if LOffset < 0 then
    Inc(LOffset, 7);
  LResult := LFirstOfMonth + LOffset; // ayın ilk ADayInWeek günü

  if AWeekInMonth = 5 then
  begin
    LLastOfMonth := EncodeDate(AYear, AMonth, DaysInAMonth(AYear, AMonth));
    while LResult + 7 <= LLastOfMonth do
      LResult := LResult + 7;
  end
  else
    LResult := LResult + 7 * (AWeekInMonth - 1);

  Result := LResult;
end;


{ TUtils }

class procedure TUtils.InUI(AProc: TProc);
begin
  if TThread.CurrentThread.ThreadID = MainThreadID then
    AProc()
  else
    TThread.ForceQueue(nil, procedure begin AProc() end);
end;




Initialization


finalization


end.







