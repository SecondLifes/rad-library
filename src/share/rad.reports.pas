unit rad.reports;

(* RadReports — FastReport VCL tabanlı rapor sistemi, bir bileşen gibi kullanılır. TEK çekirdek birim.

  Kullanım:
    Reports := TRadReports.New(dmERP.cnSirketDB, Oturum.UserName);          // bir kez, bağlantı başına
    Reports.Report('kasa.liste').Data(sql_arama, 'Kasalar').Data(sql_bakiye, 'Kasa Bakiye').Run;
    Reports.Report('kasa.liste').Data(qry).FileName('kasa-{Kasalar|kod}').Export(rfPdf, 'c:\cikti');
    Reports.Report('kasa.liste').AddToMenu(mnuRaporlar);

  İki arayüz, tek giriş noktası:
    IRadReports  servis  — bağlantı + kullanıcı adı; Report() ile iş nesnesi üretir. Formlar arasında paylaşılır.
    IRadReport   iş      — tek bir anahtar/tasarım için veri kümeleri, parametreler ve komutlar. Report() her
                           çağrıda YENİ bir iş nesnesi döndürür; çağıran onu kurmaz, parametre olarak vermez,
                           yalnız noktadan sonra devam eder. İş nesneleri birbirine karışmaz: her birinin kendi
                           FastReport motoru (TfrxReport) vardır; export filtreleri, bulut taşıyıcıları ve
                           tasarımcı ortaktır (durum taşımazlar).

  Kavramlar:
    anahtar (Key)    hangi ekran/komut ('kasa.liste'). Bir anahtarın birden çok TASARIMI olabilir.
    tasarım (Design) anahtar altındaki bir rapor; adıyla anılır ('Kasa Özeti'). İlk tasarım varsayılandır.
    sürüm            tasarımın her kaydı yeni sürüm; çakışma SHA-256 ile denetlenir.
  Yetki, sahiplik, paylaşım, tür YOKTUR (sahibin kararı). Silmeden önce yerel yedek alınır.
  Yalnız arayüz iş parçacığından çağrılır. Dataset'lerin sahibi çağırandır; kütüphane onları serbest bırakmaz,
  komut süresince okur.

  Tablolar şirket veritabanındadır (Rad-DB: rapor, rapor_surum). Kimlikler küçük harfli UUID metnidir.
  Posta/bulut ayarları ve parolaları SAKLANMAZ; host çalışma anında verir. Kapanış sırasını birim kendi çözer
  (FastReport birimleri Vcl.Forms'tan önce sonlanır; bu birimin finalization'ı canlı servislerin FastReport
  nesnelerini daha önce bırakır), host kapanırken bir şey çağırmaz. *)

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.Variants, Data.DB, Data.FMTBcd,
  Vcl.Menus, Vcl.ActnList, Uni,
  frLocalization, frLanguageTurkish, frxClass, frxDBSet, frxDesgn,
  frxChart, frxBarcode, frxOLE, frxRich, frxCross, frxGaugeView, frxTableObject, frxMap, frxCellularTextObject,
  frxZipCode, frxChBox, frxGradient, frxCrypt, frxGZip, frxHTML, frxPDFViewer,
  frxExportPDF, frxExportXLSX, frxExportDOCX, frxExportPPTX, frxExportHTML, frxExportCSV, frxExportRTF,
  frxExportODF, frxExportXML, frxExportText, frxExportImage, frxExportSVG, frxExportMail,
  frxIOTransportDropbox, frxIOTransportOneDrive, frxIOTransportBoxCom, frxIOTransportGoogleDrive,
  frxIOTransportGMail, frxIOTransportYandexDisk, frxIOTransportOutlook, frxIOTransportNextCloud,
  frxIOTransportS3, frxIOTransportFTP,
  fs_iinterpreter, fs_ipascal, fs_iclassesrtti, fs_igraphicsrtti, fs_idbrtti, fs_ichartrtti;

type
  /// <summary>Desteklenen export biçimleri. Liste bilerek dar (ZPL, DBF, EMF, BMP, GIF yok).</summary>
  TRadReportFormat = (rfPdf, rfXlsx, rfDocx, rfPptx, rfHtml, rfCsv, rfRtf, rfOds, rfOdt, rfXml, rfText, rfPng,
    rfJpeg, rfSvg);

  ERadReport = class(Exception);
  /// <summary>Kayıt sırasında veritabanındaki güncel içerik, açılan içerikten farklı çıktı.</summary>
  ERadReportConflict = class(ERadReport);
  /// <summary>Anahtarda birden çok tasarım var ve ekransız komut (Export/Mail/Upload) tasarım adı almadı.</summary>
  ERadReportDesignRequired = class(ERadReport);
  ERadReportNotFound = class(ERadReport);

  /// <summary>Bir tasarımın üst bilgisi (rapor tablosu). İçerik yoktur.</summary>
  TRadReportInfo = record
    Id: string;                 // küçük harfli uuid metni
    Key: string;
    Design: string;             // tasarım adı; (Key, Design) benzersiz
    Description: string;
    FileNameTemplate: string;   // export dosya adı şablonu: 'fis-{Kasalar|kod}-{tarih}'
    Version: Integer;           // güncel sürüm
    Sha: string;                // güncel sürümün SHA-256'sı
    IsDefault: Boolean;
    CreatedAt: TDateTime;
    CreatedBy: string;
    UpdatedAt: TDateTime;
    UpdatedBy: string;
  end;

  /// <summary>Bir sürümün üst bilgisi (rapor_surum). İçerik (bytea) bilerek yoktur.</summary>
  TRadReportVersion = record
    Id: string;
    Version: Integer;
    Sha: string;
    Size: Integer;
    Note: string;
    CreatedBy: string;
    CreatedAt: TDateTime;
  end;

  /// <summary>Export olaylarına geçen bilgi. Name değiştirilebilir, Cancel ile işlem durdurulur.</summary>
  TRadReportExportInfo = record
    Key: string;
    Design: string;
    FileFormat: TRadReportFormat;
    Folder: string;
    /// <summary>Uzantısız dosya adı (şablondan çözülmüş). OnFileName içinde değiştirilebilir.</summary>
    Name: string;
    /// <summary>OnAfterExport'ta dolu: yazılan tam yol (PNG/JPEG'de ilk sayfa).</summary>
    FilePath: string;
    Cancel: Boolean;
  end;

  TRadReportExportEvent = reference to procedure(var AInfo: TRadReportExportInfo);

  /// <summary>İş nesnesi: tek bir anahtar (ve isteğe bağlı tasarım) için veri, parametre ve komutlar.
  /// Zincir metotları Self döndürür. Komut bittiğinde veri köprüleri bırakılır; dataset'lere dokunulmaz.</summary>
  IRadReport = interface
    ['{3F6B2A9E-5C41-4D8A-9E27-1B8C6D4F0A52}']
    // ---------------------------------------------------------------- hazırlık (zincir)
    /// <summary>Rapora bir veri kümesi verir. AName boşsa ADataSet.Name; o da boşsa ERadReport.
    /// Aynı adla ikinci çağrı öncekinin yerine geçer; servisin Shared veri kümesini gölgeler.</summary>
    function Data(ADataSet: TDataSet; const AName: string = ''): IRadReport;
    /// <summary>Rapor değişkeni ([ad] olarak kullanılır). Metin tırnaklanır, sayı/mantıksal çıplak yazılır.</summary>
    function Param(const AName: string; const AValue: Variant): IRadReport;
    /// <summary>Export dosya adı şablonu; tasarımın kayıtlı şablonunu bu çağrı için geçersiz kılar.
    /// {veri|alan} ve {param}: tarih yyyy-mm-dd, tutar 2 ondalık nokta, geçersiz karakterler temizlenir.</summary>
    function FileName(const ATemplate: string): IRadReport;
    /// <summary>Bu iş için olay; servisteki varsayılan olayın önüne geçer.</summary>
    function OnFileName(AHandler: TRadReportExportEvent): IRadReport;
    function OnBeforeExport(AHandler: TRadReportExportEvent): IRadReport;
    function OnAfterExport(AHandler: TRadReportExportEvent): IRadReport;

    // ---------------------------------------------------------------- çalıştır
    /// <summary>Düğme davranışı: Ctrl basılıysa Manage; tasarım yoksa Design (yeni); tek tasarım → Preview;
    /// birden çok → fare konumunda menü (tasarımlar + "Yönet…").</summary>
    procedure Run;
    /// <summary>Hiçbir şey sormadan varsayılan tasarımı önizler.</summary>
    procedure RunDefault;
    /// <summary>Önizleme. Tasarım adı verilmediyse ve birden çok tasarım varsa menü.</summary>
    procedure Preview;
    /// <summary>Tasarımcı. Tasarım yoksa boş açılır, Kaydet ilk tasarımı yaratır. Kaydet = yeni sürüm.</summary>
    procedure Design;
    /// <summary>FastReport yazdırma diyaloğuyla yazdırır. Birden çok tasarımda menü.</summary>
    procedure Print;
    /// <summary>Sessiz export; yazılan dosyanın yolunu döndürür ('' = olay iptal etti). AFolder boşsa Belgeler.
    /// Birden çok tasarım var ve ad verilmediyse ERadReportDesignRequired (menü ÇIKMAZ).</summary>
    function Export(AFormat: TRadReportFormat; const AFolder: string = ''): string;
    /// <summary>Raporu AFormat'a çevirip e-postayla gönderir (SetupMail gerekir). Menü çıkmaz.</summary>
    procedure Mail(AFormat: TRadReportFormat; const ATo, ASubject, ABody: string);
    /// <summary>Export dosyasını bulut taşıyıcısıyla gönderir (SetupCloud gerekir). Menü çıkmaz.</summary>
    procedure Upload(AFormat: TRadReportFormat; const AProvider: string);
    /// <summary>Ribbon yönetim formu, bu anahtara süzülü.</summary>
    procedure Manage;

    // ---------------------------------------------------------------- menü ve eylemler
    /// <summary>Hazır eylemler: tasarım başına Önizle, Yazdır, Dışa aktar (biçim başına), E-posta, Tasarla,
    /// Yeni tasarım, Rapor Yöneticisi. Düğmeye/ribbon'a bağlanabilir. Sahibi iş nesnesidir.</summary>
    function Actions: TActionList;
    /// <summary>AMenu'nün altına rapor menüsünü ekler: ● varsayılan / tasarımlar → Önizle; Yazdır; Dışa aktar ▸;
    /// E-posta; Tasarla ▸; Yeni tasarım; Rapor Yöneticisi. Tasarım yoksa yalnız son ikisi. Liste, bağlı
    /// TPopupMenu'nün OnPopup'ında yenilenir (mevcut OnPopup korunur). Dataset'ler tıklama anında açık olmalı.</summary>
    procedure AddToMenu(AMenu: TMenuItem);

    // ---------------------------------------------------------------- yönetim
    /// <summary>Anahtarın tasarımları (varsayılan önce, sonra ada göre).</summary>
    function List: TArray<TRadReportInfo>;
    /// <summary>Seçili tasarımın sürümleri, en yeni önce.</summary>
    function Versions: TArray<TRadReportVersion>;
    /// <summary>Tasarımı aynı anahtar altında yeni adla çoğaltır (sürüm 1).</summary>
    procedure Copy(const ANewDesign: string);
    /// <summary>Tasarımı sürümleriyle KALICI siler; önce yerel yedek. Varsayılan silinirse en eski kalan varsayılan olur.</summary>
    procedure Delete;
    /// <summary>Bu tasarımı anahtarın varsayılanı yapar.</summary>
    procedure SetDefault;
    /// <summary>Eski sürümün içeriğini YENİ sürüm olarak yazar (geçmiş korunur).</summary>
    procedure Restore(AVersion: Integer);
    /// <summary>Güncel hariç tüm sürümleri siler; silinenler yerel yedeğe yazılır.</summary>
    procedure DeleteOldVersions;
    /// <summary>Eski sürümleri siler, güncel içerik 1. sürüm olur. Önce tüm sürümler yedeklenir.</summary>
    procedure ResetVersions;
    /// <summary>Güncel içeriği yerel klasöre yazar (SHA yan dosyasıyla); dosya yolunu döndürür.</summary>
    function SyncToLocal: string;
    /// <summary>Yerel dosya son eşitlemeden sonra değiştiyse yeni sürüm yapar. DB'de de değiştiyse ERadReportConflict.</summary>
    function PushFromLocal: Boolean;

    function GetKey: string;
    function GetDesignName: string;
    property Key: string read GetKey;
    /// <summary>Report(AKey, ADesign) ile verildiyse o; aksi hâlde '' (komutlar varsayılanı/menüyü kullanır).
    /// Adı Design OLAMAZ: derleyici hata vermeden Design yordamını gizler ve .Design; tasarımcıyı açmaz.</summary>
    property DesignName: string read GetDesignName;
  end;

  /// <summary>Servis: bağlantı + kullanıcı adı. Bir bağlantı başına bir tane; formlar arasında paylaşılır.
  /// Kapanış sırasını kendi çözer (host kapanırken bir şey çağırmaz).</summary>
  IRadReports = interface
    ['{A1D4E7F2-8B3C-4F6A-9D0E-5C2B7A8F1E34}']
    /// <summary>Yeni bir iş nesnesi. ADesign verilirse komutlar o tasarıma gider ve menü çıkmaz.</summary>
    function Report(const AKey: string; const ADesign: string = ''): IRadReport;
    /// <summary>Her rapora otomatik giren sabit veri kümesi (şirket, kullanıcı...). Sahibi host; serbest
    /// bırakılırsa köprü kendini koparır. İş nesnesinde aynı adla Data() verilirse o çağrıda gölgelenir.</summary>
    procedure Shared(ADataSet: TDataSet; const AName: string = '');
    procedure Unshare(const AName: string);
    /// <summary>Klasördeki *.fr3 dosyalarından YALNIZ eksik tasarımları oluşturur. Dosya adı '<anahtar>.fr3' ya da
    /// '<anahtar>@<tasarım>.fr3' (tasarım verilmezse 'Varsayılan'). Var olana dokunmaz, otomatik çağrılmaz.
    /// Oluşturulan sayıyı döndürür.</summary>
    function LoadDefaults(const AFolder: string): Integer;
    /// <summary>SMTP ayarları; parola yalnız bellekte durur, hiçbir yere yazılmaz.</summary>
    procedure SetupMail(const AHost: string; APort: Integer; const AUser, APassword, AFromAddress, AFromName: string);
    /// <summary>Bulut taşıyıcısının yayımlanmış özellikleri (dropbox, onedrive, boxcom, googledrive, gmail, yandexdisk,
    /// outlook, nextcloud, s3, ftp). Değerler host'tan gelir, saklanmaz.</summary>
    procedure SetupCloud(const AProvider: string; const AProps: TArray<TPair<string, string>>);

    function GetLocalFolder: string;
    procedure SetLocalFolder(const AValue: string);
    function GetOnFileName: TRadReportExportEvent;
    procedure SetOnFileName(AValue: TRadReportExportEvent);
    function GetOnBeforeExport: TRadReportExportEvent;
    procedure SetOnBeforeExport(AValue: TRadReportExportEvent);
    function GetOnAfterExport: TRadReportExportEvent;
    procedure SetOnAfterExport(AValue: TRadReportExportEvent);
    function GetUserName: string;
    function GetConnection: TUniConnection;

    /// <summary>Yerel eşitleme ve yedek kökü. Varsayılan: %APPDATA%\<uygulama adı>\Reports.</summary>
    property LocalFolder: string read GetLocalFolder write SetLocalFolder;
    /// <summary>İş nesnesinde verilmediyse kullanılan varsayılan olaylar.</summary>
    property OnFileName: TRadReportExportEvent read GetOnFileName write SetOnFileName;
    property OnBeforeExport: TRadReportExportEvent read GetOnBeforeExport write SetOnBeforeExport;
    property OnAfterExport: TRadReportExportEvent read GetOnAfterExport write SetOnAfterExport;
    property UserName: string read GetUserName;
    property Connection: TUniConnection read GetConnection;
  end;

  /// <summary>İç kullanım (yönetim formu için): iş nesnesini başka bir tasarıma aynı veri/parametrelerle kopyalar.</summary>
  IRadReportInternal = interface
    ['{7C2E9B14-6A0D-4E5F-8B13-2D7A9C4E6F01}']
    function Clone(const ADesign: string): IRadReport;
    function Service: IRadReports;
  end;

  TRadReports = class
  public
    /// <summary>Servisi yaratır. Bağlantı sahiplenilmez (şirket veritabanı; rapor/rapor_surum tabloları orada).</summary>
    class function New(AConnection: TUniConnection; const AUserName: string): IRadReports; static;
  end;

  // ================================================================== yardımcılar (iç kullanım; testler için görünür)

  TRadReportValueResolver = reference to function(const AKey: string): Variant;

  /// <summary>Export dosya adı şablonu çözümleyici. Saf mantık.</summary>
  TRadReportFileName = class
  public
    /// <summary>Dosya adında geçersiz karakterleri '_' yapar, kenar boşluk/nokta kırpar.</summary>
    class function Clean(const AText: string): string; static;
    /// <summary>Değeri dosya adı için sabit biçimli metne çevirir: tarih yyyy-mm-dd, sayı 2 ondalık nokta ayraçlı.</summary>
    class function ValueText(const AValue: Variant): string; static;
    /// <summary>{anahtar} yer tutucularını çözer ve sonucu temizler. Bilinmeyen/boş değer boş kalır.</summary>
    class function Resolve(const ATemplate: string; const AResolver: TRadReportValueResolver): string; static;
    /// <summary>Aynı ada sahip dosya varsa -2, -3 ... ekler (üzerine yazmaz). Yol AMaxPath'i aşarsa adı kısaltır.</summary>
    class function Unique(const AFolder, AName, AExt: string; AMaxPath: Integer = 240): string; static;
  end;

  TRadReportLocalInfo = record
    ReportId: string;
    Version: Integer;
    Sha: string;
  end;

  /// <summary>Yerel çalışma kopyası: <Kök>\<anahtar>\<tasarım>.fr3 + .json yan dosya (senkron anındaki id, sürüm, SHA)
  /// ve <Kök>\_deleted\ silme öncesi yedekleri. "Değişti" kararı SHA ile verilir, zaman damgasıyla değil.</summary>
  TRadReportLocal = class
  strict private
    FRoot: string;
    function Folder(const AKey: string): string;
    function SideFile(const AKey, ADesign: string): string;
  public
    constructor Create(const ARoot: string);
    class function DefaultRoot: string; static;
    class function Sha256(const ABytes: TBytes): string; static;
    function FilePath(const AKey, ADesign: string): string;
    function Write(const AKey, ADesign: string; const AInfo: TRadReportLocalInfo; const AContent: TBytes): string;
    function Read(const AKey, ADesign: string; out AInfo: TRadReportLocalInfo): Boolean;
    function Content(const AKey, ADesign: string): TBytes;
    function FileSha(const AKey, ADesign: string): string;
    /// <summary>Son senkrondan sonra değişti mi (yan dosya yoksa da True: kaynağı bilinmiyor; dosya yoksa False).</summary>
    function Changed(const AKey, ADesign: string): Boolean;
    function Backup(const AKey, ADesign: string; AVersion: Integer; const AContent: TBytes): string;
    property Root: string read FRoot write FRoot;
  end;

  /// <summary>Veritabanı deposu (rapor, rapor_surum). Bağlantıyı dışarıdan alır, sahiplenmez.
  /// Liste sorguları rapor_surum.icerik kolonunu bilerek seçmez.</summary>
  TRadReportRepo = class
  strict private
    FConnection: TUniConnection;
    function Query: TUniQuery;
    function ReadInfo(AQ: TUniQuery): TRadReportInfo;
    procedure InTransaction(const AWork: TProc);
    procedure AddVersion(const AReportId: string; AVersion: Integer; const AContent: TBytes; const ASha, ANote,
      AUser: string);
    function NewId: string;
    procedure EnsureDefault(const AKey: string);
  public
    constructor Create(AConnection: TUniConnection);
    function List(const AKey: string): TArray<TRadReportInfo>;
    function Find(const AKey, ADesign: string; out AInfo: TRadReportInfo): Boolean;
    function FindById(const AId: string; out AInfo: TRadReportInfo): Boolean;
    function Versions(const AReportId: string): TArray<TRadReportVersion>;
    /// <summary>Sürüm içeriği; AVersion = 0 günceldir.</summary>
    function Content(const AReportId: string; AVersion: Integer = 0): TBytes;
    /// <summary>Yeni tasarım için AInfo.Id boş olmalıdır (sürüm 1; anahtarın ilk tasarımıysa varsayılan olur).
    /// Var olan için AExpectedSha kullanıcının açtığı içeriğin SHA'sı; DB'dekiyle farklıysa ERadReportConflict.
    /// İçerik güncel olanla aynıysa yeni sürüm yazılmaz ve False döner.</summary>
    function Save(var AInfo: TRadReportInfo; const AContent: TBytes; const ANote, AExpectedSha, AUser: string): Boolean;
    procedure UpdateInfo(const AInfo: TRadReportInfo; const AUser: string);
    function Copy(const ASourceId, ANewDesign, AUser: string): TRadReportInfo;
    procedure Delete(const AId: string);
    procedure SetDefault(const AId: string);
    function DeleteOldVersions(const AReportId: string): Integer;
    procedure ResetVersions(const AReportId: string);
  end;

  /// <summary>Ortak FastReport bileşenleri: tasarımcı, nesne modülleri, export filtreleri, bulut taşıyıcıları.
  /// Rapor motoru (TfrxReport) burada DEĞİL, iş nesnesindedir.</summary>
  TRadReportsDM = class(TDataModule)
    frxLocalization: TfrLocalizationController;
    frxDesigner: TfrxDesigner;
    frxBarCodeObject: TfrxBarCodeObject;
    frxOLEObject: TfrxOLEObject;
    frxRichObject: TfrxRichObject;
    frxCrossObject: TfrxCrossObject;
    frxGaugeObject: TfrxGaugeObject;
    frxTableObject: TfrxReportTableObject;
    frxMapObject: TfrxMapObject;
    frxCellularTextObject: TfrxReportCellularTextObject;
    frxZipCodeObject: TfrxZipCodeObject;
    frxCheckBoxObject: TfrxCheckBoxObject;
    frxGradientObject: TfrxGradientObject;
    frxChartObject: TfrxChartObject;
    frxHTMLObject: TfrxHTMLObject;
    frxPDFObject: TfrxPDFObject;
    frxGZip: TfrxGZipCompressor;
    frxCrypt: TfrxCrypt;
    fsPascal: TfsPascal;
    fsClassesRTTI: TfsClassesRTTI;
    fsGraphicsRTTI: TfsGraphicsRTTI;
    fsDBRTTI: TfsDBRTTI;
    fsChartRTTI: TfsChartRTTI;
    frxPDFExport: TfrxPDFExport;
    frxXLSXExport: TfrxXLSXExport;
    frxDOCXExport: TfrxDOCXExport;
    frxPPTXExport: TfrxPPTXExport;
    frxHTMLExport: TfrxHTMLExport;
    frxCSVExport: TfrxCSVExport;
    frxRTFExport: TfrxRTFExport;
    frxODSExport: TfrxODSExport;
    frxODTExport: TfrxODTExport;
    frxXMLExport: TfrxXMLExport;
    frxTextExport: TfrxSimpleTextExport;
    frxPNGExport: TfrxPNGExport;
    frxJPEGExport: TfrxJPEGExport;
    frxSVGExport: TfrxSVGExport;
    frxMailExport: TfrxMailExport;
    frxDropboxTransport: TfrxDropboxIOTransport;
    frxOneDriveTransport: TfrxOneDriveIOTransport;
    frxBoxComTransport: TfrxBoxComIOTransport;
    frxGoogleDriveTransport: TfrxGoogleDriveIOTransport;
    frxGMailTransport: TfrxGMailIOTransport;
    frxYandexDiskTransport: TfrxYandexDiskIOTransport;
    frxOutlookTransport: TfrxOutlookIOTransport;
    frxNextCloudTransport: TfrxNextCloudIOTransport;
    frxS3Transport: TfrxS3IOTransport;
    frxFTPTransport: TfrxFTPIOTransport;
  public
    function ExportFilter(AFormat: TRadReportFormat): TfrxCustomExportFilter;
    function Transport(const AProvider: string): TfrxCustomIOTransport;
  end;

const
  RadReportFormatExt: array[TRadReportFormat] of string = ('pdf', 'xlsx', 'docx', 'pptx', 'html', 'csv', 'rtf',
    'ods', 'odt', 'xml', 'txt', 'png', 'jpg', 'svg');
  RadReportFormatName: array[TRadReportFormat] of string = ('PDF', 'Excel (XLSX)', 'Word (DOCX)',
    'PowerPoint (PPTX)', 'HTML', 'CSV', 'RTF', 'OpenDocument Tablo (ODS)', 'OpenDocument Metin (ODT)', 'XML',
    'Metin', 'PNG', 'JPEG', 'SVG');
  RadReportDefaultDesign = 'Varsayılan';

implementation

{$R *.dfm}

uses
  Winapi.Windows, System.IOUtils, System.Hash, System.JSON, System.TypInfo, System.StrUtils, System.UITypes,
  Vcl.Forms, Vcl.Controls, Vcl.Dialogs, Dext.Types.UUID, rad.reports.manage;

resourcestring
  SManageItem = 'Yönet…';
  SNewDesign = 'Yeni tasarım';
  SManage = 'Rapor Yöneticisi';
  SPrint = 'Yazdır';
  SExportMenu = 'Dışa aktar';
  SMailItem = 'E-posta ile gönder';
  SDesignMenu = 'Tasarla';
  SPreviewPrefix = 'Önizle: %s';
  SDesignPrefix = 'Tasarla: %s';
  SNotConnected = 'RadReports: servis kapanmış ya da bağlantı yok.';
  SDataSetNameRequired = 'Data(): veri kümesinin adı yok (AName verin ya da DataSet.Name doldurun).';
  SNoDesign = '"%s" anahtarında "%s" tasarımı yok.';
  SNoDesigns = '"%s" anahtarında tasarım yok.';
  SDesignRequired = '"%s" anahtarında birden çok tasarım var; Report(anahtar, tasarım) ile tasarım adı verin.';
  SPrepareFailed = 'Rapor hazırlanamadı.';
  SUnknownProvider = 'Bilinmeyen bulut sağlayıcısı: %s';
  SProviderNoProp = '%s taşıyıcısında "%s" özelliği yok.';
  SMailNotSetup = 'SetupMail çağrılmadı: SMTP bilgisi yok.';
  SVersionNotFound = 'Sürüm bulunamadı.';
  SDesignNotFoundOrDeleted = 'Tasarım bulunamadı (başka bir kullanıcı silmiş olabilir).';
  SConflict = 'Tasarım siz açtıktan sonra başka biri tarafından değiştirildi.';
  SCopyFailed = 'Kopya oluşturulamadı.';
  SSaveDialogFilter = '%s|*.%s';
  SNewDesignPrompt = 'Yeni tasarımın adı';

type
  TRadReportsService = class;

  TMailSettings = record
    Host: string;
    Port: Integer;
    User: string;
    Password: string;
    FromAddress: string;
    FromName: string;
    IsSet: Boolean;
  end;

  /// <summary>Host'un sabit veri kümelerini izler; serbest bırakılanı listeden düşürür.</summary>
  TSharedWatcher = class(TComponent)
  strict private
    FItems: TList<TPair<string, TDataSet>>;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Add(const AName: string; ADataSet: TDataSet);
    procedure Remove(const AName: string);
    property Items: TList<TPair<string, TDataSet>> read FItems;
  end;

  TRadReportJob = class;

  TRadReportsService = class(TInterfacedObject, IRadReports)
  strict private
    FConnection: TUniConnection;
    FUserName: string;
    FRepo: TRadReportRepo;
    FLocal: TRadReportLocal;
    FDM: TRadReportsDM;
    FShared: TSharedWatcher;
    FMail: TMailSettings;
    FCloud: TDictionary<string, TArray<TPair<string, string>>>;
    FJobs: TList<TRadReportJob>;
    FOnFileName, FOnBeforeExport, FOnAfterExport: TRadReportExportEvent;
    FDesigning: TRadReportJob;
    FShutdown: Boolean;
    function DesignerSave(Report: TfrxReport; SaveAs: Boolean): Boolean;
  private
    procedure RegisterJob(AJob: TRadReportJob);
    procedure UnregisterJob(AJob: TRadReportJob);
    procedure Shutdown;
    procedure CheckAlive;
  public
    constructor Create(AConnection: TUniConnection; const AUserName: string);
    destructor Destroy; override;
    // IRadReports
    function Report(const AKey: string; const ADesign: string = ''): IRadReport;
    procedure Shared(ADataSet: TDataSet; const AName: string = '');
    procedure Unshare(const AName: string);
    function LoadDefaults(const AFolder: string): Integer;
    procedure SetupMail(const AHost: string; APort: Integer; const AUser, APassword, AFromAddress, AFromName: string);
    procedure SetupCloud(const AProvider: string; const AProps: TArray<TPair<string, string>>);
    function GetLocalFolder: string;
    procedure SetLocalFolder(const AValue: string);
    function GetOnFileName: TRadReportExportEvent;
    procedure SetOnFileName(AValue: TRadReportExportEvent);
    function GetOnBeforeExport: TRadReportExportEvent;
    procedure SetOnBeforeExport(AValue: TRadReportExportEvent);
    function GetOnAfterExport: TRadReportExportEvent;
    procedure SetOnAfterExport(AValue: TRadReportExportEvent);
    function GetUserName: string;
    function GetConnection: TUniConnection;
    // iç
    property Repo: TRadReportRepo read FRepo;
    property Local: TRadReportLocal read FLocal;
    property DM: TRadReportsDM read FDM;
    property SharedList: TSharedWatcher read FShared;
    property Mail: TMailSettings read FMail;
    property Cloud: TDictionary<string, TArray<TPair<string, string>>> read FCloud;
    property Designing: TRadReportJob read FDesigning write FDesigning;
    property UserName: string read FUserName;
  end;

  TRadActionKind = (akPreview, akPrint, akExport, akMail, akDesign, akNewDesign, akManage);

  TRadReportAction = class(TAction)
  public
    Kind: TRadActionKind;
    DesignName: string;
    FileFormat: TRadReportFormat;
  end;

  /// <summary>Rapor başlamadan önceki imleç: rapor dolaşırken canlı listenin seçili satırı kaybolmasın.</summary>
  TRadReportCursorMark = record
    DataSet: TDataSet;
    Bookmark: TBookmark;
  end;

  TRadReportJob = class(TInterfacedObject, IRadReport, IRadReportInternal)
  strict private
    FService: TRadReportsService;
    FServiceRef: IRadReports;       // servis, işten önce ölmesin
    FKey: string;
    FDesign: string;
    FData: TList<TPair<string, TDataSet>>;
    FParams: TList<TPair<string, Variant>>;
    FTemplate: string;
    FOnFileName, FOnBeforeExport, FOnAfterExport: TRadReportExportEvent;
    FReport: TfrxReport;
    FBridges: TObjectList<TfrxDBDataset>;
    FCursors: TList<TRadReportCursorMark>;
    FOwner: TComponent;             // eylemler ve menüler için sahip
    FActions: TActionList;
    FPopup: TPopupMenu;
    FDesigningInfo: TRadReportInfo;
    FDesigningSha: string;
    FDesigningIsNew: Boolean;
    function Engine: TfrxReport;
    procedure LoadTemplate(const AInfo: TRadReportInfo);
    procedure CreateBridges;
    procedure BindData;
    procedure UnbindData;
    procedure RestoreCursors;
    function ParamText(const AValue: Variant): string;
    function Resolve(AInteractive: Boolean; out AInfo: TRadReportInfo): Boolean;
    function PickFromMenu(const AList: TArray<TRadReportInfo>; out AInfo: TRadReportInfo): Boolean;
    procedure PrepareSilent;
    function ResolveFileName(const AInfo: TRadReportInfo): string;
    function RunEvent(const AJobHandler, AServiceHandler: TRadReportExportEvent; var AData: TRadReportExportInfo): Boolean;
    function DoExport(const AInfo: TRadReportInfo; AFormat: TRadReportFormat; const AFolder: string): string;
    procedure DoPreview(const AInfo: TRadReportInfo);
    procedure DoDesign(const AInfo: TRadReportInfo; AIsNew: Boolean);
    procedure DoPrint(const AInfo: TRadReportInfo);
    procedure MailDialog(const AInfo: TRadReportInfo);
    procedure ExportDialog(const AInfo: TRadReportInfo; AFormat: TRadReportFormat);
    function Current: TRadReportInfo;
    procedure RebuildActions;
    procedure ActionExecute(Sender: TObject);
    procedure PopupMenuClick(Sender: TObject);
  private
    function SaveFromDesigner(AReport: TfrxReport): Boolean;
    procedure ReleaseEngine;
    procedure FillMenu(AMenu: TMenuItem);
  public
    constructor Create(AService: TRadReportsService; const AKey, ADesign: string);
    destructor Destroy; override;
    // IRadReport
    function Data(ADataSet: TDataSet; const AName: string = ''): IRadReport;
    function Param(const AName: string; const AValue: Variant): IRadReport;
    function FileName(const ATemplate: string): IRadReport;
    function OnFileName(AHandler: TRadReportExportEvent): IRadReport;
    function OnBeforeExport(AHandler: TRadReportExportEvent): IRadReport;
    function OnAfterExport(AHandler: TRadReportExportEvent): IRadReport;
    procedure Run;
    procedure RunDefault;
    procedure Preview;
    procedure Design;
    procedure Print;
    function Export(AFormat: TRadReportFormat; const AFolder: string = ''): string;
    procedure Mail(AFormat: TRadReportFormat; const ATo, ASubject, ABody: string);
    procedure Upload(AFormat: TRadReportFormat; const AProvider: string);
    procedure Manage;
    function Actions: TActionList;
    procedure AddToMenu(AMenu: TMenuItem);
    function List: TArray<TRadReportInfo>;
    function Versions: TArray<TRadReportVersion>;
    procedure Copy(const ANewDesign: string);
    procedure Delete;
    procedure SetDefault;
    procedure Restore(AVersion: Integer);
    procedure DeleteOldVersions;
    procedure ResetVersions;
    function SyncToLocal: string;
    function PushFromLocal: Boolean;
    function GetKey: string;
    function GetDesignName: string;
    // IRadReportInternal
    function Clone(const ADesign: string): IRadReport;
    function Service: IRadReports;
  end;

  /// <summary>AddToMenu'nün menüye bağladığı tutucu: iş nesnesini canlı tutar, menü açılınca listeyi yeniler.</summary>
  TMenuBinder = class(TComponent)
  strict private
    FJob: IRadReport;
    FMenu: TMenuItem;
    FOldPopup: TNotifyEvent;
    FOldClick: TNotifyEvent;
    procedure PopupHandler(Sender: TObject);
    procedure ClickHandler(Sender: TObject);
  public
    constructor Create(AMenu: TMenuItem; const AJob: IRadReport); reintroduce;
    procedure Rebuild;
  end;

var
  GServices: TList<TRadReportsService>;

const
  ForbiddenChars = '\/:*?"<>|';
  LocalIdKey = 'report.id';
  LocalVersionKey = 'report.version';
  LocalShaKey = 'report.sha';

// ====================================================================== TRadReportFileName

class function TRadReportFileName.Clean(const AText: string): string;
var
  I: Integer;
begin
  Result := AText;
  for I := 1 to Length(Result) do
    if (Pos(Result[I], ForbiddenChars) > 0) or (Ord(Result[I]) < 32) then
      Result[I] := '_';
  Result := Result.Trim([' ', '.']);
end;

class function TRadReportFileName.ValueText(const AValue: Variant): string;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Exit('');
  if VarIsFmtBcd(AValue) then
    Exit(CurrToStrF(BcdToCurrency(VarToBcd(AValue)), ffFixed, 2, TFormatSettings.Invariant));
  case VarType(AValue) and varTypeMask of
    varDate:
      if Frac(Double(AValue)) = 0 then
        Result := FormatDateTime('yyyy-mm-dd', VarToDateTime(AValue))
      else
        Result := FormatDateTime('yyyy-mm-dd_hhnn', VarToDateTime(AValue));
    varCurrency:
      Result := CurrToStrF(Currency(AValue), ffFixed, 2, TFormatSettings.Invariant);
    varSingle, varDouble:
      Result := FormatFloat('0.00', Double(AValue), TFormatSettings.Invariant);
    varBoolean:
      Result := IfThen(Boolean(AValue), 'evet', 'hayir');
  else
    Result := VarToStr(AValue);
  end;
end;

class function TRadReportFileName.Resolve(const ATemplate: string; const AResolver: TRadReportValueResolver): string;
var
  LSb: TStringBuilder;
  I, LEnd: Integer;
  LKey: string;
begin
  LSb := TStringBuilder.Create;
  try
    I := 1;
    while I <= Length(ATemplate) do
    begin
      if ATemplate[I] = '{' then
      begin
        LEnd := ATemplate.IndexOf('}', I) + 1;
        if LEnd > I then
        begin
          LKey := System.Copy(ATemplate, I + 1, LEnd - I - 1).Trim;
          if Assigned(AResolver) and (LKey <> '') then
            LSb.Append(Clean(ValueText(AResolver(LKey))));
          I := LEnd + 1;
          Continue;
        end;
      end;
      LSb.Append(ATemplate[I]);
      Inc(I);
    end;
    Result := Clean(LSb.ToString);
  finally
    LSb.Free;
  end;
end;

class function TRadReportFileName.Unique(const AFolder, AName, AExt: string; AMaxPath: Integer): string;
var
  LName, LCandidate: string;
  LCounter, LRoom: Integer;
begin
  LName := Clean(AName);
  if LName = '' then
    LName := 'report';
  LRoom := AMaxPath - Length(IncludeTrailingPathDelimiter(AFolder)) - Length(AExt) - 5;
  if LRoom < 8 then
    LRoom := 8;
  if Length(LName) > LRoom then
    LName := Clean(System.Copy(LName, 1, LRoom));
  LCandidate := LName;
  LCounter := 1;
  while TFile.Exists(TPath.Combine(AFolder, LCandidate + '.' + AExt)) do
  begin
    Inc(LCounter);
    LCandidate := LName + '-' + IntToStr(LCounter);
  end;
  Result := TPath.Combine(AFolder, LCandidate + '.' + AExt);
end;

// ====================================================================== TRadReportLocal

constructor TRadReportLocal.Create(const ARoot: string);
begin
  inherited Create;
  if ARoot = '' then
    FRoot := DefaultRoot
  else
    FRoot := ARoot;
end;

class function TRadReportLocal.DefaultRoot: string;
begin
  Result := TPath.Combine(TPath.Combine(TPath.GetHomePath, TPath.GetFileNameWithoutExtension(ParamStr(0))), 'Reports');
end;

class function TRadReportLocal.Sha256(const ABytes: TBytes): string;
var
  LHash: THashSHA2;
begin
  LHash := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
  if Length(ABytes) > 0 then
    LHash.Update(ABytes);
  Result := LowerCase(LHash.HashAsString);
end;

function TRadReportLocal.Folder(const AKey: string): string;
begin
  Result := TPath.Combine(FRoot, TRadReportFileName.Clean(AKey));
end;

function TRadReportLocal.FilePath(const AKey, ADesign: string): string;
begin
  Result := TPath.Combine(Folder(AKey), TRadReportFileName.Clean(ADesign) + '.fr3');
end;

function TRadReportLocal.SideFile(const AKey, ADesign: string): string;
begin
  Result := TPath.Combine(Folder(AKey), TRadReportFileName.Clean(ADesign) + '.report.json');
end;

function TRadReportLocal.Write(const AKey, ADesign: string; const AInfo: TRadReportLocalInfo;
  const AContent: TBytes): string;
var
  LJson: TJSONObject;
begin
  TDirectory.CreateDirectory(Folder(AKey));
  Result := FilePath(AKey, ADesign);
  TFile.WriteAllBytes(Result, AContent);
  LJson := TJSONObject.Create;
  try
    LJson.AddPair(LocalIdKey, AInfo.ReportId);
    LJson.AddPair(LocalVersionKey, TJSONNumber.Create(AInfo.Version));
    LJson.AddPair(LocalShaKey, AInfo.Sha);
    TFile.WriteAllText(SideFile(AKey, ADesign), LJson.ToJSON, TEncoding.UTF8);
  finally
    LJson.Free;
  end;
end;

function JsonText(AJson: TJSONObject; const AKey: string): string;
var
  LValue: TJSONValue;
begin
  // Anahtarlarda nokta var: GetValue<T> bunu yol ayracı sayar, bu yüzden Values[] ile okunur.
  LValue := AJson.Values[AKey];
  if LValue = nil then
    Result := ''
  else
    Result := LValue.Value;
end;

function TRadReportLocal.Read(const AKey, ADesign: string; out AInfo: TRadReportLocalInfo): Boolean;
var
  LValue: TJSONValue;
begin
  AInfo := Default(TRadReportLocalInfo);
  Result := False;
  if not TFile.Exists(SideFile(AKey, ADesign)) then
    Exit;
  LValue := TJSONObject.ParseJSONValue(TFile.ReadAllText(SideFile(AKey, ADesign), TEncoding.UTF8));
  try
    if not (LValue is TJSONObject) then
      Exit;
    AInfo.ReportId := JsonText(TJSONObject(LValue), LocalIdKey);
    AInfo.Version := StrToIntDef(JsonText(TJSONObject(LValue), LocalVersionKey), 0);
    AInfo.Sha := JsonText(TJSONObject(LValue), LocalShaKey);
    Result := AInfo.Sha <> '';
  finally
    LValue.Free;
  end;
end;

function TRadReportLocal.Content(const AKey, ADesign: string): TBytes;
begin
  if TFile.Exists(FilePath(AKey, ADesign)) then
    Result := TFile.ReadAllBytes(FilePath(AKey, ADesign))
  else
    Result := nil;
end;

function TRadReportLocal.FileSha(const AKey, ADesign: string): string;
begin
  if TFile.Exists(FilePath(AKey, ADesign)) then
    Result := Sha256(TFile.ReadAllBytes(FilePath(AKey, ADesign)))
  else
    Result := '';
end;

function TRadReportLocal.Changed(const AKey, ADesign: string): Boolean;
var
  LInfo: TRadReportLocalInfo;
begin
  if not TFile.Exists(FilePath(AKey, ADesign)) then
    Exit(False);
  if not Read(AKey, ADesign, LInfo) then
    Exit(True);
  Result := not SameText(FileSha(AKey, ADesign), LInfo.Sha);
end;

function TRadReportLocal.Backup(const AKey, ADesign: string; AVersion: Integer; const AContent: TBytes): string;
var
  LFolder: string;
begin
  LFolder := TPath.Combine(FRoot, '_deleted');
  TDirectory.CreateDirectory(LFolder);
  Result := TPath.Combine(LFolder, Format('%s@%s_v%d_%s.fr3', [TRadReportFileName.Clean(AKey),
    TRadReportFileName.Clean(ADesign), AVersion, FormatDateTime('yyyymmdd-hhnnss-zzz', Now)]));
  TFile.WriteAllBytes(Result, AContent);
end;

// ====================================================================== TRadReportRepo

const
  SqlInfo =
    'select r.id::text as id, r.anahtar, r.ad, r.aciklama, r.export_adi, r.varsayilan_mi, r.guncel_surum, ' +
    'r.guncel_sha, r.created_at, r.created_by, r.updated_at, r.updated_by from rapor r ';

constructor TRadReportRepo.Create(AConnection: TUniConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TRadReportRepo.Query: TUniQuery;
begin
  Result := TUniQuery.Create(nil);
  Result.Connection := FConnection;
end;

function TRadReportRepo.NewId: string;
begin
  Result := LowerCase(TUUID.NewV7.ToString).Replace('{', '').Replace('}', '');
end;

procedure TRadReportRepo.InTransaction(const AWork: TProc);
var
  LOwn: Boolean;
begin
  LOwn := not FConnection.InTransaction;
  if LOwn then
    FConnection.StartTransaction;
  try
    AWork();
    if LOwn then
      FConnection.Commit;
  except
    if LOwn and FConnection.InTransaction then
      FConnection.Rollback;
    raise;
  end;
end;

function TRadReportRepo.ReadInfo(AQ: TUniQuery): TRadReportInfo;
begin
  Result.Id := AQ.FieldByName('id').AsString;
  Result.Key := AQ.FieldByName('anahtar').AsString;
  Result.Design := AQ.FieldByName('ad').AsString;
  Result.Description := AQ.FieldByName('aciklama').AsString;
  Result.FileNameTemplate := AQ.FieldByName('export_adi').AsString;
  Result.IsDefault := AQ.FieldByName('varsayilan_mi').AsBoolean;
  Result.Version := AQ.FieldByName('guncel_surum').AsInteger;
  Result.Sha := AQ.FieldByName('guncel_sha').AsString;
  Result.CreatedAt := AQ.FieldByName('created_at').AsDateTime;
  Result.CreatedBy := AQ.FieldByName('created_by').AsString;
  Result.UpdatedAt := AQ.FieldByName('updated_at').AsDateTime;
  Result.UpdatedBy := AQ.FieldByName('updated_by').AsString;
end;

function TRadReportRepo.List(const AKey: string): TArray<TRadReportInfo>;
var
  LQ: TUniQuery;
  LResult: TArray<TRadReportInfo>;
begin
  LQ := Query;
  try
    LQ.SQL.Text := SqlInfo + 'where r.anahtar = :k order by r.varsayilan_mi desc, r.ad';
    LQ.ParamByName('k').AsString := AKey;
    LQ.Open;
    SetLength(LResult, 0);
    while not LQ.Eof do
    begin
      SetLength(LResult, Length(LResult) + 1);
      LResult[High(LResult)] := ReadInfo(LQ);
      LQ.Next;
    end;
    Result := LResult;
  finally
    LQ.Free;
  end;
end;

function TRadReportRepo.Find(const AKey, ADesign: string; out AInfo: TRadReportInfo): Boolean;
var
  LQ: TUniQuery;
begin
  LQ := Query;
  try
    LQ.SQL.Text := SqlInfo + 'where r.anahtar = :k and r.ad = :d';
    LQ.ParamByName('k').AsString := AKey;
    LQ.ParamByName('d').AsString := ADesign;
    LQ.Open;
    Result := not LQ.IsEmpty;
    if Result then
      AInfo := ReadInfo(LQ)
    else
      AInfo := Default(TRadReportInfo);
  finally
    LQ.Free;
  end;
end;

function TRadReportRepo.FindById(const AId: string; out AInfo: TRadReportInfo): Boolean;
var
  LQ: TUniQuery;
begin
  LQ := Query;
  try
    LQ.SQL.Text := SqlInfo + 'where r.id = cast(:id as uuid)';
    LQ.ParamByName('id').AsString := AId;
    LQ.Open;
    Result := not LQ.IsEmpty;
    if Result then
      AInfo := ReadInfo(LQ)
    else
      AInfo := Default(TRadReportInfo);
  finally
    LQ.Free;
  end;
end;

function TRadReportRepo.Versions(const AReportId: string): TArray<TRadReportVersion>;
var
  LQ: TUniQuery;
  LResult: TArray<TRadReportVersion>;
begin
  LQ := Query;
  try
    LQ.SQL.Text := 'select s.id::text as id, s.surum, s.sha256, s.boyut, s.aciklama, s.created_by, s.created_at ' +
      'from rapor_surum s where s.rapor_id = cast(:id as uuid) order by s.surum desc';
    LQ.ParamByName('id').AsString := AReportId;
    LQ.Open;
    SetLength(LResult, 0);
    while not LQ.Eof do
    begin
      SetLength(LResult, Length(LResult) + 1);
      with LResult[High(LResult)] do
      begin
        Id := LQ.FieldByName('id').AsString;
        Version := LQ.FieldByName('surum').AsInteger;
        Sha := LQ.FieldByName('sha256').AsString;
        Size := LQ.FieldByName('boyut').AsInteger;
        Note := LQ.FieldByName('aciklama').AsString;
        CreatedBy := LQ.FieldByName('created_by').AsString;
        CreatedAt := LQ.FieldByName('created_at').AsDateTime;
      end;
      LQ.Next;
    end;
    Result := LResult;
  finally
    LQ.Free;
  end;
end;

function TRadReportRepo.Content(const AReportId: string; AVersion: Integer): TBytes;
var
  LQ: TUniQuery;
begin
  LQ := Query;
  try
    LQ.SQL.Text := 'select s.icerik from rapor_surum s where s.rapor_id = cast(:id as uuid) and s.surum = ' +
      'case when :v = 0 then (select r.guncel_surum from rapor r where r.id = cast(:id as uuid)) else :v end';
    LQ.ParamByName('id').AsString := AReportId;
    LQ.ParamByName('v').AsInteger := AVersion;
    LQ.Open;
    if LQ.IsEmpty then
      raise ERadReportNotFound.Create(SVersionNotFound);
    Result := LQ.FieldByName('icerik').AsBytes;
  finally
    LQ.Free;
  end;
end;

procedure TRadReportRepo.AddVersion(const AReportId: string; AVersion: Integer; const AContent: TBytes;
  const ASha, ANote, AUser: string);
var
  LQ: TUniQuery;
begin
  LQ := Query;
  try
    LQ.SQL.Text := 'insert into rapor_surum (id, rapor_id, surum, icerik, sha256, boyut, aciklama, created_by) ' +
      'values (cast(:id as uuid), cast(:rid as uuid), :v, :c, :sha, :size, :note, :u)';
    LQ.ParamByName('id').AsString := NewId;
    LQ.ParamByName('rid').AsString := AReportId;
    LQ.ParamByName('v').AsInteger := AVersion;
    LQ.ParamByName('c').DataType := ftBlob;
    LQ.ParamByName('c').AsBlob := AContent;
    LQ.ParamByName('sha').AsString := ASha;
    LQ.ParamByName('size').AsInteger := Length(AContent);
    LQ.ParamByName('note').AsString := ANote;
    LQ.ParamByName('u').AsString := AUser;
    LQ.ExecSQL;
  finally
    LQ.Free;
  end;
end;

function TRadReportRepo.Save(var AInfo: TRadReportInfo; const AContent: TBytes; const ANote, AExpectedSha,
  AUser: string): Boolean;
var
  LSha, LNewId: string;
  LInfo: TRadReportInfo;
  LResult: Boolean;
begin
  LSha := TRadReportLocal.Sha256(AContent);
  LInfo := AInfo;
  LResult := True;
  InTransaction(
    procedure
    var
      LQ: TUniQuery;
      LVersion: Integer;
    begin
      LQ := Query;
      try
        if LInfo.Id = '' then
        begin
          LInfo.Id := NewId;
          LInfo.Version := 1;
          LInfo.Sha := LSha;
          if LInfo.Design = '' then
            LInfo.Design := RadReportDefaultDesign;
          // anahtarın ilk tasarımı varsayılan olur
          LQ.SQL.Text := 'insert into rapor (id, anahtar, ad, aciklama, export_adi, varsayilan_mi, guncel_surum, ' +
            'guncel_sha, created_by) values (cast(:id as uuid), :k, :d, :desc, :tpl, ' +
            'not exists (select 1 from rapor x where x.anahtar = :k), 1, :sha, :u)';
          LQ.ParamByName('id').AsString := LInfo.Id;
          LQ.ParamByName('k').AsString := LInfo.Key;
          LQ.ParamByName('d').AsString := LInfo.Design;
          LQ.ParamByName('desc').AsString := LInfo.Description;
          LQ.ParamByName('tpl').AsString := LInfo.FileNameTemplate;
          LQ.ParamByName('sha').AsString := LSha;
          LQ.ParamByName('u').AsString := AUser;
          LQ.ExecSQL;
          AddVersion(LInfo.Id, 1, AContent, LSha, ANote, AUser);
          Exit;
        end;
        LQ.SQL.Text := 'select guncel_surum, guncel_sha from rapor where id = cast(:id as uuid) for update';
        LQ.ParamByName('id').AsString := LInfo.Id;
        LQ.Open;
        if LQ.IsEmpty then
          raise ERadReportNotFound.Create(SDesignNotFoundOrDeleted);
        if (AExpectedSha <> '') and not SameText(LQ.FieldByName('guncel_sha').AsString, AExpectedSha) then
          raise ERadReportConflict.Create(SConflict);
        if SameText(LQ.FieldByName('guncel_sha').AsString, LSha) then
        begin
          LResult := False;
          Exit;
        end;
        LVersion := LQ.FieldByName('guncel_surum').AsInteger + 1;
        LQ.Close;
        AddVersion(LInfo.Id, LVersion, AContent, LSha, ANote, AUser);
        LQ.SQL.Text := 'update rapor set guncel_surum = :v, guncel_sha = :sha, updated_at = now(), updated_by = :u ' +
          'where id = cast(:id as uuid)';
        LQ.ParamByName('id').AsString := LInfo.Id;
        LQ.ParamByName('v').AsInteger := LVersion;
        LQ.ParamByName('sha').AsString := LSha;
        LQ.ParamByName('u').AsString := AUser;
        LQ.ExecSQL;
        LInfo.Version := LVersion;
        LInfo.Sha := LSha;
      finally
        LQ.Free;
      end;
    end);
  if LResult and (AInfo.Id = '') then
  begin
    // out parametresi girişte kaydı sıfırlar; kimlik önce ayrı bir değişkene alınır
    LNewId := LInfo.Id;
    FindById(LNewId, LInfo);
  end;
  AInfo := LInfo;
  Result := LResult;
end;

procedure TRadReportRepo.UpdateInfo(const AInfo: TRadReportInfo; const AUser: string);
var
  LQ: TUniQuery;
begin
  LQ := Query;
  try
    LQ.SQL.Text := 'update rapor set ad = :d, aciklama = :desc, export_adi = :tpl, updated_at = now(), ' +
      'updated_by = :u where id = cast(:id as uuid)';
    LQ.ParamByName('id').AsString := AInfo.Id;
    LQ.ParamByName('d').AsString := AInfo.Design;
    LQ.ParamByName('desc').AsString := AInfo.Description;
    LQ.ParamByName('tpl').AsString := AInfo.FileNameTemplate;
    LQ.ParamByName('u').AsString := AUser;
    LQ.ExecSQL;
  finally
    LQ.Free;
  end;
end;

function TRadReportRepo.Copy(const ASourceId, ANewDesign, AUser: string): TRadReportInfo;
var
  LNewId: string;
  LResult: TRadReportInfo;
begin
  LNewId := NewId;
  InTransaction(
    procedure
    var
      LQ: TUniQuery;
    begin
      LQ := Query;
      try
        LQ.SQL.Text := 'insert into rapor (id, anahtar, ad, aciklama, export_adi, varsayilan_mi, guncel_surum, ' +
          'guncel_sha, created_by) select cast(:nid as uuid), anahtar, :d, aciklama, export_adi, false, 1, ' +
          'guncel_sha, :u from rapor where id = cast(:id as uuid)';
        LQ.ParamByName('nid').AsString := LNewId;
        LQ.ParamByName('d').AsString := ANewDesign;
        LQ.ParamByName('u').AsString := AUser;
        LQ.ParamByName('id').AsString := ASourceId;
        LQ.ExecSQL;
        if LQ.RowsAffected = 0 then
          raise ERadReportNotFound.Create(SDesignNotFoundOrDeleted);
        LQ.SQL.Text := 'insert into rapor_surum (id, rapor_id, surum, icerik, sha256, boyut, aciklama, created_by) ' +
          'select cast(:sid as uuid), cast(:nid as uuid), 1, icerik, sha256, boyut, :note, :u from rapor_surum ' +
          'where rapor_id = cast(:id as uuid) and surum = (select guncel_surum from rapor where id = cast(:id as uuid))';
        LQ.ParamByName('sid').AsString := NewId;
        LQ.ParamByName('nid').AsString := LNewId;
        LQ.ParamByName('note').AsString := 'Kopya';
        LQ.ParamByName('u').AsString := AUser;
        LQ.ParamByName('id').AsString := ASourceId;
        LQ.ExecSQL;
      finally
        LQ.Free;
      end;
    end);
  if not FindById(LNewId, LResult) then
    raise ERadReport.Create(SCopyFailed);
  Result := LResult;
end;

procedure TRadReportRepo.EnsureDefault(const AKey: string);
var
  LQ: TUniQuery;
begin
  // varsayılan kalmadıysa en eski tasarım devralır
  LQ := Query;
  try
    LQ.SQL.Text := 'update rapor set varsayilan_mi = true where id = (select id from rapor where anahtar = :k ' +
      'order by created_at, ad limit 1) and not exists (select 1 from rapor where anahtar = :k and varsayilan_mi)';
    LQ.ParamByName('k').AsString := AKey;
    LQ.ExecSQL;
  finally
    LQ.Free;
  end;
end;

procedure TRadReportRepo.Delete(const AId: string);
var
  LInfo: TRadReportInfo;
begin
  if not FindById(AId, LInfo) then
    Exit;
  InTransaction(
    procedure
    var
      LQ: TUniQuery;
    begin
      LQ := Query;
      try
        LQ.SQL.Text := 'delete from rapor where id = cast(:id as uuid)';
        LQ.ParamByName('id').AsString := AId;
        LQ.ExecSQL;
      finally
        LQ.Free;
      end;
      EnsureDefault(LInfo.Key);
    end);
end;

procedure TRadReportRepo.SetDefault(const AId: string);
begin
  // Tek UPDATE satır satır işlenir ve kısmi UNIQUE indeks ara durumda iki varsayılan görür; önce hepsi kapatılır.
  InTransaction(
    procedure
    var
      LQ: TUniQuery;
    begin
      LQ := Query;
      try
        LQ.SQL.Text := 'update rapor set varsayilan_mi = false where varsayilan_mi ' +
          'and anahtar = (select anahtar from rapor where id = cast(:id as uuid))';
        LQ.ParamByName('id').AsString := AId;
        LQ.ExecSQL;
        LQ.SQL.Text := 'update rapor set varsayilan_mi = true where id = cast(:id as uuid)';
        LQ.ParamByName('id').AsString := AId;
        LQ.ExecSQL;
      finally
        LQ.Free;
      end;
    end);
end;

function TRadReportRepo.DeleteOldVersions(const AReportId: string): Integer;
var
  LQ: TUniQuery;
begin
  LQ := Query;
  try
    LQ.SQL.Text := 'delete from rapor_surum where rapor_id = cast(:id as uuid) ' +
      'and surum < (select guncel_surum from rapor where id = cast(:id as uuid))';
    LQ.ParamByName('id').AsString := AReportId;
    LQ.ExecSQL;
    Result := LQ.RowsAffected;
  finally
    LQ.Free;
  end;
end;

procedure TRadReportRepo.ResetVersions(const AReportId: string);
begin
  InTransaction(
    procedure
    var
      LQ: TUniQuery;
      LCurrent: Integer;
    begin
      LQ := Query;
      try
        LQ.SQL.Text := 'select guncel_surum from rapor where id = cast(:id as uuid) for update';
        LQ.ParamByName('id').AsString := AReportId;
        LQ.Open;
        if LQ.IsEmpty then
          raise ERadReportNotFound.Create(SDesignNotFoundOrDeleted);
        LCurrent := LQ.FieldByName('guncel_surum').AsInteger;
        LQ.Close;
        LQ.SQL.Text := 'delete from rapor_surum where rapor_id = cast(:id as uuid) and surum <> :c';
        LQ.ParamByName('id').AsString := AReportId;
        LQ.ParamByName('c').AsInteger := LCurrent;
        LQ.ExecSQL;
        LQ.SQL.Text := 'update rapor_surum set surum = 1 where rapor_id = cast(:id as uuid)';
        LQ.ParamByName('id').AsString := AReportId;
        LQ.ExecSQL;
        LQ.SQL.Text := 'update rapor set guncel_surum = 1 where id = cast(:id as uuid)';
        LQ.ParamByName('id').AsString := AReportId;
        LQ.ExecSQL;
      finally
        LQ.Free;
      end;
    end);
end;

// ====================================================================== TRadReportsDM

function TRadReportsDM.ExportFilter(AFormat: TRadReportFormat): TfrxCustomExportFilter;
begin
  case AFormat of
    rfPdf: Result := frxPDFExport;
    rfXlsx: Result := frxXLSXExport;
    rfDocx: Result := frxDOCXExport;
    rfPptx: Result := frxPPTXExport;
    rfHtml: Result := frxHTMLExport;
    rfCsv: Result := frxCSVExport;
    rfRtf: Result := frxRTFExport;
    rfOds: Result := frxODSExport;
    rfOdt: Result := frxODTExport;
    rfXml: Result := frxXMLExport;
    rfText: Result := frxTextExport;
    rfPng: Result := frxPNGExport;
    rfJpeg: Result := frxJPEGExport;
    rfSvg: Result := frxSVGExport;
  else
    raise ERadReport.Create('Desteklenmeyen export biçimi.');
  end;
end;

function TRadReportsDM.Transport(const AProvider: string): TfrxCustomIOTransport;
begin
  if SameText(AProvider, 'dropbox') then
    Result := frxDropboxTransport
  else if SameText(AProvider, 'onedrive') then
    Result := frxOneDriveTransport
  else if SameText(AProvider, 'boxcom') then
    Result := frxBoxComTransport
  else if SameText(AProvider, 'googledrive') then
    Result := frxGoogleDriveTransport
  else if SameText(AProvider, 'gmail') then
    Result := frxGMailTransport
  else if SameText(AProvider, 'yandexdisk') then
    Result := frxYandexDiskTransport
  else if SameText(AProvider, 'outlook') then
    Result := frxOutlookTransport
  else if SameText(AProvider, 'nextcloud') then
    Result := frxNextCloudTransport
  else if SameText(AProvider, 's3') then
    Result := frxS3Transport
  else if SameText(AProvider, 'ftp') then
    Result := frxFTPTransport
  else
    raise ERadReport.CreateFmt(SUnknownProvider, [AProvider]);
end;

// ====================================================================== TSharedWatcher

constructor TSharedWatcher.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TList<TPair<string, TDataSet>>.Create;
end;

destructor TSharedWatcher.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TSharedWatcher.Add(const AName: string; ADataSet: TDataSet);
begin
  Remove(AName);
  FItems.Add(TPair<string, TDataSet>.Create(AName, ADataSet));
  ADataSet.FreeNotification(Self);
end;

procedure TSharedWatcher.Remove(const AName: string);
var
  I: Integer;
begin
  for I := FItems.Count - 1 downto 0 do
    if SameText(FItems[I].Key, AName) then
      FItems.Delete(I);
end;

procedure TSharedWatcher.Notification(AComponent: TComponent; Operation: TOperation);
var
  I: Integer;
begin
  inherited;
  if Operation = opRemove then
    for I := FItems.Count - 1 downto 0 do
      if FItems[I].Value = AComponent then
        FItems.Delete(I);
end;

// ====================================================================== TRadReportsService

constructor TRadReportsService.Create(AConnection: TUniConnection; const AUserName: string);
begin
  inherited Create;
  FConnection := AConnection;
  FUserName := AUserName;
  FRepo := TRadReportRepo.Create(AConnection);
  FLocal := TRadReportLocal.Create('');
  FDM := TRadReportsDM.Create(nil);
  FDM.frxDesigner.OnSaveReport := DesignerSave;
  FDM.frxMailExport.ShowExportDialog := False;
  FShared := TSharedWatcher.Create(nil);
  FCloud := TDictionary<string, TArray<TPair<string, string>>>.Create;
  FJobs := TList<TRadReportJob>.Create;
  GServices.Add(Self);
end;

destructor TRadReportsService.Destroy;
begin
  Shutdown;
  if GServices <> nil then
    GServices.Remove(Self);
  FJobs.Free;
  FCloud.Free;
  FShared.Free;
  FLocal.Free;
  FRepo.Free;
  inherited;
end;

procedure TRadReportsService.Shutdown;
var
  LJob: TRadReportJob;
  LOther: TRadReportsService;
begin
  if FShutdown then
    Exit;
  FShutdown := True;
  for LJob in FJobs do
    LJob.ReleaseEngine;
  FreeAndNil(FDM);   // TfrxDesigner.Destroy global frxDesignerComp'u nil yapar (frxDesgn.pas)
  // Yaşayan başka servis varsa tasarımcı globali onun bileşenine geri bağlanır; yoksa tasarımcı kancasız kalır.
  for LOther in GServices do
    if (LOther <> Self) and (LOther.FDM <> nil) then
    begin
      frxDesignerComp := LOther.FDM.frxDesigner;
      Break;
    end;
end;

procedure TRadReportsService.CheckAlive;
begin
  if FShutdown or (FConnection = nil) then
    raise ERadReport.Create(SNotConnected);
end;

procedure TRadReportsService.RegisterJob(AJob: TRadReportJob);
begin
  FJobs.Add(AJob);
end;

procedure TRadReportsService.UnregisterJob(AJob: TRadReportJob);
begin
  FJobs.Remove(AJob);
end;

function TRadReportsService.DesignerSave(Report: TfrxReport; SaveAs: Boolean): Boolean;
begin
  if FDesigning = nil then
    Exit(False);
  Result := FDesigning.SaveFromDesigner(Report);
end;

function TRadReportsService.Report(const AKey: string; const ADesign: string): IRadReport;
begin
  CheckAlive;
  Result := TRadReportJob.Create(Self, AKey, ADesign);
end;

procedure TRadReportsService.Shared(ADataSet: TDataSet; const AName: string);
var
  LName: string;
begin
  LName := AName;
  if LName = '' then
    LName := ADataSet.Name;
  if LName = '' then
    raise ERadReport.Create(SDataSetNameRequired);
  FShared.Add(LName, ADataSet);
end;

procedure TRadReportsService.Unshare(const AName: string);
begin
  FShared.Remove(AName);
end;

function TRadReportsService.LoadDefaults(const AFolder: string): Integer;
var
  LFile, LBase, LKey, LDesign: string;
  LAt: Integer;
  LInfo: TRadReportInfo;
begin
  CheckAlive;
  Result := 0;
  if not TDirectory.Exists(AFolder) then
    Exit;
  for LFile in TDirectory.GetFiles(AFolder, '*.fr3') do
  begin
    LBase := TPath.GetFileNameWithoutExtension(LFile);
    LAt := LBase.IndexOf('@');
    if LAt > 0 then
    begin
      LKey := LowerCase(System.Copy(LBase, 1, LAt));
      LDesign := System.Copy(LBase, LAt + 2, MaxInt).Trim;
    end
    else
    begin
      LKey := LowerCase(LBase);
      LDesign := RadReportDefaultDesign;
    end;
    if (LKey = '') or (LDesign = '') or FRepo.Find(LKey, LDesign, LInfo) then
      Continue;
    LInfo := Default(TRadReportInfo);
    LInfo.Key := LKey;
    LInfo.Design := LDesign;
    FRepo.Save(LInfo, TFile.ReadAllBytes(LFile), 'Varsayılan dosyadan', '', FUserName);
    Inc(Result);
  end;
end;

procedure TRadReportsService.SetupMail(const AHost: string; APort: Integer; const AUser, APassword, AFromAddress,
  AFromName: string);
begin
  FMail.Host := AHost;
  FMail.Port := APort;
  FMail.User := AUser;
  FMail.Password := APassword;
  FMail.FromAddress := AFromAddress;
  FMail.FromName := AFromName;
  FMail.IsSet := AHost <> '';
end;

procedure TRadReportsService.SetupCloud(const AProvider: string; const AProps: TArray<TPair<string, string>>);
begin
  FCloud.AddOrSetValue(LowerCase(AProvider), AProps);
end;

function TRadReportsService.GetLocalFolder: string;
begin
  Result := FLocal.Root;
end;

procedure TRadReportsService.SetLocalFolder(const AValue: string);
begin
  if AValue = '' then
    FLocal.Root := TRadReportLocal.DefaultRoot
  else
    FLocal.Root := AValue;
end;

function TRadReportsService.GetOnFileName: TRadReportExportEvent;
begin
  Result := FOnFileName;
end;

procedure TRadReportsService.SetOnFileName(AValue: TRadReportExportEvent);
begin
  FOnFileName := AValue;
end;

function TRadReportsService.GetOnBeforeExport: TRadReportExportEvent;
begin
  Result := FOnBeforeExport;
end;

procedure TRadReportsService.SetOnBeforeExport(AValue: TRadReportExportEvent);
begin
  FOnBeforeExport := AValue;
end;

function TRadReportsService.GetOnAfterExport: TRadReportExportEvent;
begin
  Result := FOnAfterExport;
end;

procedure TRadReportsService.SetOnAfterExport(AValue: TRadReportExportEvent);
begin
  FOnAfterExport := AValue;
end;

function TRadReportsService.GetUserName: string;
begin
  Result := FUserName;
end;

function TRadReportsService.GetConnection: TUniConnection;
begin
  Result := FConnection;
end;

// ====================================================================== TRadReportJob

constructor TRadReportJob.Create(AService: TRadReportsService; const AKey, ADesign: string);
begin
  inherited Create;
  FService := AService;
  FServiceRef := AService;
  FKey := AKey;
  FDesign := ADesign;
  FData := TList<TPair<string, TDataSet>>.Create;
  FParams := TList<TPair<string, Variant>>.Create;
  FBridges := TObjectList<TfrxDBDataset>.Create(True);
  FCursors := TList<TRadReportCursorMark>.Create;
  FOwner := TComponent.Create(nil);
  FService.RegisterJob(Self);
end;

destructor TRadReportJob.Destroy;
begin
  if FService <> nil then
    FService.UnregisterJob(Self);
  ReleaseEngine;
  FOwner.Free;        // eylemler ve popup menü
  FCursors.Free;
  FBridges.Free;
  FParams.Free;
  FData.Free;
  inherited;
end;

procedure TRadReportJob.ReleaseEngine;
begin
  UnbindData;
  FreeAndNil(FReport);
end;

function TRadReportJob.Engine: TfrxReport;
begin
  FService.CheckAlive;
  if FReport = nil then
  begin
    FReport := TfrxReport.Create(nil);
    FReport.ScriptLanguage := 'PascalScript';
    FReport.EngineOptions.UseGlobalDataSetList := False;
    FReport.PreviewOptions.Buttons := [pbPrint, pbSave, pbExport, pbZoom, pbFind, pbOutline, pbPageSetup, pbTools,
      pbNavigator, pbExportQuick, pbCopy, pbSelection];
  end;
  Result := FReport;
end;

function TRadReportJob.GetKey: string;
begin
  Result := FKey;
end;

function TRadReportJob.GetDesignName: string;
begin
  Result := FDesign;
end;

function TRadReportJob.Service: IRadReports;
begin
  Result := FServiceRef;
end;

function TRadReportJob.Clone(const ADesign: string): IRadReport;
var
  LJob: TRadReportJob;
  LPair: TPair<string, TDataSet>;
  LParam: TPair<string, Variant>;
begin
  LJob := TRadReportJob.Create(FService, FKey, ADesign);
  for LPair in FData do
    LJob.FData.Add(LPair);
  for LParam in FParams do
    LJob.FParams.Add(LParam);
  LJob.FTemplate := FTemplate;
  LJob.FOnFileName := FOnFileName;
  LJob.FOnBeforeExport := FOnBeforeExport;
  LJob.FOnAfterExport := FOnAfterExport;
  Result := LJob;
end;

// ---------------------------------------------------------------------- zincir

function TRadReportJob.Data(ADataSet: TDataSet; const AName: string): IRadReport;
var
  LName: string;
  I: Integer;
begin
  LName := AName;
  if (LName = '') and (ADataSet <> nil) then
    LName := ADataSet.Name;
  if LName = '' then
    raise ERadReport.Create(SDataSetNameRequired);
  for I := FData.Count - 1 downto 0 do
    if SameText(FData[I].Key, LName) then
      FData.Delete(I);
  FData.Add(TPair<string, TDataSet>.Create(LName, ADataSet));
  Result := Self;
end;

function TRadReportJob.Param(const AName: string; const AValue: Variant): IRadReport;
var
  I: Integer;
begin
  for I := FParams.Count - 1 downto 0 do
    if SameText(FParams[I].Key, AName) then
      FParams.Delete(I);
  FParams.Add(TPair<string, Variant>.Create(AName, AValue));
  Result := Self;
end;

function TRadReportJob.FileName(const ATemplate: string): IRadReport;
begin
  FTemplate := ATemplate;
  Result := Self;
end;

function TRadReportJob.OnFileName(AHandler: TRadReportExportEvent): IRadReport;
begin
  FOnFileName := AHandler;
  Result := Self;
end;

function TRadReportJob.OnBeforeExport(AHandler: TRadReportExportEvent): IRadReport;
begin
  FOnBeforeExport := AHandler;
  Result := Self;
end;

function TRadReportJob.OnAfterExport(AHandler: TRadReportExportEvent): IRadReport;
begin
  FOnAfterExport := AHandler;
  Result := Self;
end;

// ---------------------------------------------------------------------- iç yardımcılar

function TRadReportJob.ParamText(const AValue: Variant): string;
begin
  // FastReport değişken değeri bir ifadedir: metin tırnaklanır, sayı/mantıksal çıplak yazılır.
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
    Exit('''''');
  case VarType(AValue) and varTypeMask of
    varSmallint, varInteger, varShortInt, varByte, varWord, varLongWord, varInt64, varUInt64, varCurrency,
      varSingle, varDouble:
      Result := TRadReportFileName.ValueText(AValue);
    varBoolean:
      Result := IfThen(Boolean(AValue), 'True', 'False');
  else
    Result := QuotedStr(TRadReportFileName.ValueText(AValue));
  end;
end;

procedure TRadReportJob.CreateBridges;
var
  LPair: TPair<string, TDataSet>;
  LBridge: TfrxDBDataset;
  LNames: TList<string>;

  procedure AddBridge(const AName: string; ADataSet: TDataSet);
  var
    LMark: TRadReportCursorMark;
  begin
    if (ADataSet = nil) or (LNames.IndexOf(LowerCase(AName)) >= 0) then
      Exit;
    LNames.Add(LowerCase(AName));
    // TfrxDBDataset varsayılan aralıkta imleci geri getirmez; rapor bağlı grid'i de dolaşarak titretir.
    LMark.DataSet := ADataSet;
    LMark.Bookmark := nil;
    if ADataSet.Active and not ADataSet.IsEmpty and not ADataSet.IsUniDirectional then
      LMark.Bookmark := ADataSet.GetBookmark;
    ADataSet.DisableControls;
    FCursors.Add(LMark);
    LBridge := TfrxDBDataset.Create(nil);
    LBridge.UserName := AName;
    LBridge.DataSet := ADataSet;
    FBridges.Add(LBridge);
    Engine.EnabledDataSets.Add(LBridge);
  end;

begin
  UnbindData;
  LNames := TList<string>.Create;
  try
    // iş verileri önce: aynı adlı sabit (Shared) veri kümesini gölgeler
    for LPair in FData do
      AddBridge(LPair.Key, LPair.Value);
    for LPair in FService.SharedList.Items do
      AddBridge(LPair.Key, LPair.Value);
  finally
    LNames.Free;
  end;
end;

procedure TRadReportJob.BindData;
var
  LParam: TPair<string, Variant>;
  LBridge: TfrxDBDataset;
begin
  try
    if FBridges.Count = 0 then
      CreateBridges;        // şablonsuz (yeni) tasarım: LoadTemplate çalışmadı
    // Yükleme DataSets'i .fr3'teki adlarla doldurur; çalıştırma listesi yalnız bu işin köprülerinden oluşur.
    Engine.DataSets.Clear;
    for LBridge in FBridges do
      Engine.DataSets.Add(LBridge);
    for LParam in FParams do
      Engine.Variables[LParam.Key] := ParamText(LParam.Value);
  except
    UnbindData;
    raise;
  end;
end;

procedure TRadReportJob.RestoreCursors;
var
  LMark: TRadReportCursorMark;
begin
  for LMark in FCursors do
    if (LMark.Bookmark <> nil) and LMark.DataSet.Active and LMark.DataSet.BookmarkValid(LMark.Bookmark) then
      LMark.DataSet.GotoBookmark(LMark.Bookmark);
end;

procedure TRadReportJob.UnbindData;
var
  LMark: TRadReportCursorMark;
begin
  RestoreCursors;
  for LMark in FCursors do
  begin
    if LMark.Bookmark <> nil then
      LMark.DataSet.FreeBookmark(LMark.Bookmark);
    LMark.DataSet.EnableControls;
  end;
  FCursors.Clear;
  if FReport <> nil then
  begin
    // Raporun kendi veri kümesi listesi her çalıştırmada yeniden kurulur; eski çalıştırmadan kalan öğe aynı adlı
    // yeni köprüyü gölgeleyip alan çözümlemesini bozar (denemeyle doğrulandı).
    FReport.EnabledDataSets.Clear;
    FReport.DataSets.Clear;
  end;
  FBridges.Clear;
end;

procedure TRadReportJob.LoadTemplate(const AInfo: TRadReportInfo);
var
  LStream: TBytesStream;
begin
  LStream := TBytesStream.Create(FService.Repo.Content(AInfo.Id));
  try
    // Köprüler yüklemeden ÖNCE kurulmalı: bant, görünüm ve sayfalar DataSetName'i yükleme anında EnabledDataSets'te
    // arar (UseGlobalDataSetList kapalı). Bulamazlarsa DataSet nil kalır, sonradan bağlanmaz: rapor hatasız ama satırsız
    // çıkar, tasarımcıda bant "atanmamış" görünür.
    CreateBridges;
    try
      Engine.Clear;
      Engine.LoadFromStream(LStream);
    except
      UnbindData;
      raise;
    end;
  finally
    LStream.Free;
  end;
  Engine.ReportOptions.Name := AInfo.Design;
end;

function TRadReportJob.PickFromMenu(const AList: TArray<TRadReportInfo>; out AInfo: TRadReportInfo): Boolean;
var
  LMenu: TPopupMenu;
  LItem: TMenuItem;
  I: Integer;
  LPt: TPoint;
  LChosen: Integer;
begin
  // Menü tıklanana kadar bu metot dönmez (TPopupMenu.Popup eşzamanlıdır); seçim Tag'de tutulur.
  LChosen := -1;
  LMenu := TPopupMenu.Create(nil);
  try
    for I := 0 to High(AList) do
    begin
      LItem := TMenuItem.Create(LMenu);
      LItem.Caption := AList[I].Design;
      LItem.Default := AList[I].IsDefault;
      LItem.Tag := I;
      LItem.OnClick := PopupMenuClick;
      LMenu.Items.Add(LItem);
    end;
    LItem := TMenuItem.Create(LMenu);
    LItem.Caption := '-';
    LMenu.Items.Add(LItem);
    LItem := TMenuItem.Create(LMenu);
    LItem.Caption := SManageItem;
    LItem.Tag := -2;
    LItem.OnClick := PopupMenuClick;
    LMenu.Items.Add(LItem);
    FPopup := LMenu;
    LMenu.Tag := -1;
    GetCursorPos(LPt);
    LMenu.Popup(LPt.X, LPt.Y);
    Application.ProcessMessages;   // OnClick, Popup döndükten sonra kuyruktan gelir
    LChosen := LMenu.Tag;
  finally
    FPopup := nil;
    LMenu.Free;
  end;
  Result := LChosen >= 0;
  if Result then
    AInfo := AList[LChosen]
  else
  begin
    AInfo := Default(TRadReportInfo);
    if LChosen = -2 then
      Manage;
  end;
end;

procedure TRadReportJob.PopupMenuClick(Sender: TObject);
begin
  if FPopup <> nil then
    FPopup.Tag := TMenuItem(Sender).Tag;
end;

function TRadReportJob.Resolve(AInteractive: Boolean; out AInfo: TRadReportInfo): Boolean;
var
  LList: TArray<TRadReportInfo>;
begin
  FService.CheckAlive;
  if FDesign <> '' then
  begin
    if not FService.Repo.Find(FKey, FDesign, AInfo) then
      raise ERadReportNotFound.CreateFmt(SNoDesign, [FKey, FDesign]);
    Exit(True);
  end;
  LList := FService.Repo.List(FKey);
  if Length(LList) = 0 then
    raise ERadReportNotFound.CreateFmt(SNoDesigns, [FKey]);
  if Length(LList) = 1 then
  begin
    AInfo := LList[0];
    Exit(True);
  end;
  if not AInteractive then
    raise ERadReportDesignRequired.CreateFmt(SDesignRequired, [FKey]);
  Result := PickFromMenu(LList, AInfo);
end;

function TRadReportJob.Current: TRadReportInfo;
begin
  if not Resolve(False, Result) then
    raise ERadReportDesignRequired.CreateFmt(SDesignRequired, [FKey]);
end;

procedure TRadReportJob.PrepareSilent;
begin
  // Ekransız çalışmada FastReport hata kutusu açmasın (kutu uygulamayı kilitler); hata istisna olarak gelir.
  Engine.EngineOptions.NewSilentMode := simReThrow;
  try
    if not Engine.PrepareReport then
      raise ERadReport.Create(SPrepareFailed);
  finally
    Engine.EngineOptions.NewSilentMode := simMessageBoxes;
    RestoreCursors;        // dosya adı şablonu ve olaylar hazırlıktan sonra seçili satırı okur
  end;
end;

function TRadReportJob.ResolveFileName(const AInfo: TRadReportInfo): string;
var
  LTemplate: string;
begin
  LTemplate := FTemplate;
  if LTemplate = '' then
    LTemplate := AInfo.FileNameTemplate;
  if LTemplate = '' then
    Exit(TRadReportFileName.Clean(AInfo.Design));
  Result := TRadReportFileName.Resolve(LTemplate,
    function(const AKey: string): Variant
    var
      LSep: Integer;
      LDataName, LField: string;
      LPair: TPair<string, TDataSet>;
      LParam: TPair<string, Variant>;
      LF: TField;
    begin
      Result := Null;
      LSep := Pos('|', AKey);
      if LSep > 0 then
      begin
        LDataName := Trim(System.Copy(AKey, 1, LSep - 1));
        LField := Trim(System.Copy(AKey, LSep + 1, MaxInt));
        for LPair in FData do
          if SameText(LPair.Key, LDataName) and (LPair.Value <> nil) and LPair.Value.Active then
          begin
            LF := LPair.Value.FindField(LField);
            if (LF <> nil) and not LF.IsNull then
              if LF.DataType in [ftBCD, ftFMTBcd] then
                Result := LF.AsCurrency
              else
                Result := LF.Value;
            Exit;
          end;
        for LPair in FService.SharedList.Items do
          if SameText(LPair.Key, LDataName) and (LPair.Value <> nil) and LPair.Value.Active then
          begin
            LF := LPair.Value.FindField(LField);
            if (LF <> nil) and not LF.IsNull then
              Result := LF.Value;
            Exit;
          end;
      end
      else
        for LParam in FParams do
          if SameText(LParam.Key, AKey) then
            Exit(LParam.Value);
    end);
  if Result = '' then
    Result := TRadReportFileName.Clean(AInfo.Design);
end;

function TRadReportJob.RunEvent(const AJobHandler, AServiceHandler: TRadReportExportEvent;
  var AData: TRadReportExportInfo): Boolean;
begin
  if Assigned(AJobHandler) then
    AJobHandler(AData)
  else if Assigned(AServiceHandler) then
    AServiceHandler(AData);
  Result := not AData.Cancel;
end;

// ---------------------------------------------------------------------- komutlar

procedure TRadReportJob.DoPreview(const AInfo: TRadReportInfo);
var
  LName: string;
begin
  LoadTemplate(AInfo);
  BindData;
  try
    // önizlemenin kendi Dışa aktar düğmesi de şablondan gelen adı önersin
    LName := ResolveFileName(AInfo);
    Engine.ReportOptions.Name := LName;
    Engine.ShowReport;
  finally
    UnbindData;
  end;
end;

procedure TRadReportJob.Preview;
var
  LInfo: TRadReportInfo;
begin
  if Resolve(True, LInfo) then
    DoPreview(LInfo);
end;

procedure TRadReportJob.RunDefault;
var
  LList: TArray<TRadReportInfo>;
  I: Integer;
begin
  FService.CheckAlive;
  LList := FService.Repo.List(FKey);
  if Length(LList) = 0 then
    raise ERadReportNotFound.CreateFmt(SNoDesigns, [FKey]);
  for I := 0 to High(LList) do
    if LList[I].IsDefault then
    begin
      DoPreview(LList[I]);
      Exit;
    end;
  DoPreview(LList[0]);
end;

procedure TRadReportJob.Run;
var
  LList: TArray<TRadReportInfo>;
  LInfo: TRadReportInfo;
begin
  FService.CheckAlive;
  if GetKeyState(VK_CONTROL) < 0 then
  begin
    Manage;
    Exit;
  end;
  if FDesign <> '' then
  begin
    if FService.Repo.Find(FKey, FDesign, LInfo) then
      DoPreview(LInfo)
    else
      DoDesign(LInfo, True);
    Exit;
  end;
  LList := FService.Repo.List(FKey);
  case Length(LList) of
    0: DoDesign(Default(TRadReportInfo), True);
    1: DoPreview(LList[0]);
  else
    if PickFromMenu(LList, LInfo) then
      DoPreview(LInfo);
  end;
end;

procedure TRadReportJob.DoDesign(const AInfo: TRadReportInfo; AIsNew: Boolean);
var
  LPage: TfrxReportPage;
begin
  FDesigningInfo := AInfo;
  FDesigningIsNew := AIsNew;
  if AIsNew then
  begin
    FDesigningInfo.Key := FKey;
    FDesigningInfo.Design := FDesign;      // boşsa Kaydet'te 'Varsayılan' olur
    FDesigningSha := '';
    Engine.Clear;
    Engine.ReportOptions.Name := FDesign;
    // Clear sayfasız bırakır; tasarımcı "Yeni rapor"daki gibi varsayılan ölçülü boş bir sayfayla açılsın
    LPage := TfrxReportPage.Create(Engine);
    LPage.CreateUniqueName;
    LPage.SetDefaults;
  end
  else
  begin
    LoadTemplate(AInfo);
    FDesigningSha := AInfo.Sha;
  end;
  BindData;
  FService.Designing := Self;
  // FastReport tasarımcısı Kaydet'te yalnız global frxDesignerComp'un OnSaveReport'una bakar. Bu global en son
  // yaratılan TfrxDesigner'a işaret eder ve herhangi bir TfrxDesigner yok edilince koşulsuz nil olur (frxDesgn.pas,
  // TfrxDesigner.Destroy). Şirket değişiminde yeni servis kurulup eski servis sonra bırakılınca global nil kalıyordu
  // ve Kaydet dosya diyaloğuna düşüyordu; bu yüzden her tasarım açılışında kendi bileşenimizi yeniden bağlarız.
  frxDesignerComp := FService.DM.frxDesigner;
  try
    Engine.DesignReport;
  finally
    FService.Designing := nil;
    UnbindData;
  end;
end;

function TRadReportJob.SaveFromDesigner(AReport: TfrxReport): Boolean;
var
  LStream: TBytesStream;
  LBytes: TBytes;
  LExisting: TRadReportInfo;
begin
  LStream := TBytesStream.Create;
  try
    AReport.SaveToStream(LStream);
    LBytes := System.Copy(LStream.Bytes, 0, LStream.Size);
  finally
    LStream.Free;
  end;
  // Aynı adla bu arada başkası oluşturmuş olabilir: ona yeni sürüm yaz. Sonuç ayrı değişkene alınır: Find'ın out
  // parametresi kaydı sıfırlar; FDesigningInfo verilirse bulunamayınca anahtar ve ad kaybolur, satır boş anahtarla yazılır.
  if FDesigningIsNew and (FDesigningInfo.Id = '') and (FDesigningInfo.Design <> '') and
    FService.Repo.Find(FKey, FDesigningInfo.Design, LExisting) then
  begin
    FDesigningInfo := LExisting;
    FDesigningSha := LExisting.Sha;
  end;
  FService.Repo.Save(FDesigningInfo, LBytes, '', FDesigningSha, FService.UserName);
  FDesigningSha := FDesigningInfo.Sha;
  FDesigningIsNew := False;
  Result := True;
end;

procedure TRadReportJob.Design;
var
  LInfo: TRadReportInfo;
  LList: TArray<TRadReportInfo>;
begin
  FService.CheckAlive;
  if FDesign <> '' then
  begin
    if FService.Repo.Find(FKey, FDesign, LInfo) then
      DoDesign(LInfo, False)
    else
      DoDesign(LInfo, True);
    Exit;
  end;
  LList := FService.Repo.List(FKey);
  case Length(LList) of
    0: DoDesign(Default(TRadReportInfo), True);
    1: DoDesign(LList[0], False);
  else
    if PickFromMenu(LList, LInfo) then
      DoDesign(LInfo, False);
  end;
end;

procedure TRadReportJob.DoPrint(const AInfo: TRadReportInfo);
begin
  LoadTemplate(AInfo);
  BindData;
  try
    PrepareSilent;
    Engine.PrintOptions.ShowDialog := True;
    Engine.Print;
  finally
    UnbindData;
  end;
end;

procedure TRadReportJob.Print;
var
  LInfo: TRadReportInfo;
begin
  if Resolve(True, LInfo) then
    DoPrint(LInfo);
end;

function TRadReportJob.DoExport(const AInfo: TRadReportInfo; AFormat: TRadReportFormat; const AFolder: string): string;
var
  LData: TRadReportExportInfo;
  LFilter: TfrxCustomExportFilter;
  LPages: TArray<string>;
begin
  Result := '';
  LoadTemplate(AInfo);
  BindData;
  try
    PrepareSilent;
    LData := Default(TRadReportExportInfo);
    LData.Key := FKey;
    LData.Design := AInfo.Design;
    LData.FileFormat := AFormat;
    LData.Folder := AFolder;
    if LData.Folder = '' then
      LData.Folder := TPath.GetDocumentsPath;
    LData.Name := ResolveFileName(AInfo);
    if not RunEvent(FOnFileName, FService.GetOnFileName(), LData) then
      Exit;
    if not RunEvent(FOnBeforeExport, FService.GetOnBeforeExport(), LData) then
      Exit;
    TDirectory.CreateDirectory(LData.Folder);
    LData.FilePath := TRadReportFileName.Unique(LData.Folder, LData.Name, RadReportFormatExt[AFormat]);
    LFilter := FService.DM.ExportFilter(AFormat);
    LFilter.ShowDialog := False;
    LFilter.OverwritePrompt := False;
    LFilter.FileName := LData.FilePath;
    Engine.Export(LFilter);
    // Görüntü biçimleri sayfa başına dosya yazar (ad.1.png ...); ilk sayfanın yolu bildirilir.
    if (AFormat in [rfPng, rfJpeg]) and not TFile.Exists(LData.FilePath) then
    begin
      LPages := TDirectory.GetFiles(LData.Folder, TPath.GetFileNameWithoutExtension(LData.FilePath) + '.*.' +
        RadReportFormatExt[AFormat]);
      if Length(LPages) > 0 then
        LData.FilePath := LPages[0];
    end;
    Result := LData.FilePath;
    RunEvent(FOnAfterExport, FService.GetOnAfterExport(), LData);
  finally
    UnbindData;
  end;
end;

function TRadReportJob.Export(AFormat: TRadReportFormat; const AFolder: string): string;
begin
  Result := DoExport(Current, AFormat, AFolder);
end;

procedure TRadReportJob.Mail(AFormat: TRadReportFormat; const ATo, ASubject, ABody: string);
var
  LInfo: TRadReportInfo;
  LMail: TfrxMailExport;
begin
  LInfo := Current;
  if not FService.Mail.IsSet then
    raise ERadReport.Create(SMailNotSetup);
  LoadTemplate(LInfo);
  BindData;
  LMail := FService.DM.frxMailExport;
  try
    PrepareSilent;
    LMail.UseMAPI := SMTP;
    LMail.SmtpHost := FService.Mail.Host;
    LMail.SmtpPort := FService.Mail.Port;
    LMail.Login := FService.Mail.User;
    LMail.Password := FService.Mail.Password;
    LMail.FromMail := FService.Mail.FromAddress;
    LMail.FromName := FService.Mail.FromName;
    LMail.Address := ATo;
    LMail.Subject := ASubject;
    LMail.Lines.Text := ABody;
    LMail.ExportFilter := FService.DM.ExportFilter(AFormat);
    LMail.ExportFilter.FileName := ResolveFileName(LInfo) + '.' + RadReportFormatExt[AFormat];
    LMail.ShowExportDialog := False;
    LMail.ShowDialog := False;
    Engine.Export(LMail);
  finally
    LMail.Password := '';
    UnbindData;
  end;
end;

procedure TRadReportJob.MailDialog(const AInfo: TRadReportInfo);
var
  LMail: TfrxMailExport;
begin
  // Menüden: FastReport'un kendi posta diyaloğu (adres orada girilir); SetupMail değerleri dolu gelir.
  LoadTemplate(AInfo);
  BindData;
  LMail := FService.DM.frxMailExport;
  try
    PrepareSilent;
    LMail.UseMAPI := SMTP;
    LMail.SmtpHost := FService.Mail.Host;
    LMail.SmtpPort := FService.Mail.Port;
    LMail.Login := FService.Mail.User;
    LMail.Password := FService.Mail.Password;
    LMail.FromMail := FService.Mail.FromAddress;
    LMail.FromName := FService.Mail.FromName;
    LMail.Subject := AInfo.Design;
    LMail.ExportFilter := FService.DM.ExportFilter(rfPdf);
    LMail.ExportFilter.FileName := ResolveFileName(AInfo) + '.pdf';
    LMail.ShowExportDialog := True;
    LMail.ShowDialog := True;
    Engine.Export(LMail);
  finally
    LMail.Password := '';
    UnbindData;
  end;
end;

procedure TRadReportJob.Upload(AFormat: TRadReportFormat; const AProvider: string);
var
  LInfo: TRadReportInfo;
  LTransport: TfrxCustomIOTransport;
  LProps: TArray<TPair<string, string>>;
  LPair: TPair<string, string>;
  LProp: PPropInfo;
  LFilter: TfrxCustomExportFilter;
  LData: TRadReportExportInfo;
begin
  LInfo := Current;
  LTransport := FService.DM.Transport(AProvider);
  if FService.Cloud.TryGetValue(LowerCase(AProvider), LProps) then
    for LPair in LProps do
    begin
      LProp := GetPropInfo(LTransport, LPair.Key);
      if LProp = nil then
        raise ERadReport.CreateFmt(SProviderNoProp, [LTransport.ClassName, LPair.Key]);
      case LProp.PropType^.Kind of
        tkInteger, tkInt64:
          SetOrdProp(LTransport, LProp, StrToInt64(LPair.Value));
        tkEnumeration:
          if SameText(string(LProp.PropType^.Name), 'Boolean') then
            SetOrdProp(LTransport, LProp, Ord(SameText(LPair.Value, 'true') or (LPair.Value = '1')))
          else
            SetEnumProp(LTransport, LProp, LPair.Value);
      else
        SetStrProp(LTransport, LProp, LPair.Value);
      end;
    end;
  LoadTemplate(LInfo);
  BindData;
  try
    PrepareSilent;
    LData := Default(TRadReportExportInfo);
    LData.Key := FKey;
    LData.Design := LInfo.Design;
    LData.FileFormat := AFormat;
    LData.Name := ResolveFileName(LInfo);
    if not RunEvent(FOnFileName, FService.GetOnFileName(), LData) then
      Exit;
    if not RunEvent(FOnBeforeExport, FService.GetOnBeforeExport(), LData) then
      Exit;
    LFilter := FService.DM.ExportFilter(AFormat);
    LFilter.ShowDialog := False;
    LFilter.OverwritePrompt := False;
    LFilter.FileName := LData.Name + '.' + RadReportFormatExt[AFormat];
    LFilter.IOTransport := LTransport;
    try
      Engine.Export(LFilter);
    finally
      LFilter.IOTransport := nil;
    end;
    LData.FilePath := LFilter.FileName;
    RunEvent(FOnAfterExport, FService.GetOnAfterExport(), LData);
  finally
    UnbindData;
  end;
end;

procedure TRadReportJob.Manage;
begin
  FService.CheckAlive;
  TRadReportManageForm.Execute(Self);
end;

procedure TRadReportJob.ExportDialog(const AInfo: TRadReportInfo; AFormat: TRadReportFormat);
var
  LDialog: TSaveDialog;
begin
  LDialog := TSaveDialog.Create(nil);
  try
    LDialog.DefaultExt := RadReportFormatExt[AFormat];
    LDialog.Filter := Format(SSaveDialogFilter, [RadReportFormatName[AFormat], RadReportFormatExt[AFormat]]);
    LDialog.FileName := ResolveFileName(AInfo) + '.' + RadReportFormatExt[AFormat];
    LDialog.Options := LDialog.Options + [ofOverwritePrompt];
    if not LDialog.Execute then
      Exit;
    FTemplate := TPath.GetFileNameWithoutExtension(LDialog.FileName);
    if TFile.Exists(LDialog.FileName) then
      TFile.Delete(LDialog.FileName);   // kullanıcı üzerine yazmayı onayladı; Unique -2 eklemesin
    DoExport(AInfo, AFormat, ExtractFileDir(LDialog.FileName));
  finally
    LDialog.Free;
  end;
end;

// ---------------------------------------------------------------------- eylemler ve menü

procedure TRadReportJob.RebuildActions;
var
  LList: TArray<TRadReportInfo>;
  LInfo: TRadReportInfo;
  F: TRadReportFormat;

  function Add(AKind: TRadActionKind; const ACaption, ADesignName: string; AFormat: TRadReportFormat): TRadReportAction;
  begin
    Result := TRadReportAction.Create(FOwner);
    Result.ActionList := FActions;
    Result.Kind := AKind;
    Result.Caption := ACaption;
    Result.DesignName := ADesignName;
    Result.FileFormat := AFormat;
    Result.OnExecute := ActionExecute;
  end;

begin
  if FActions = nil then
    FActions := TActionList.Create(FOwner);
  while FActions.ActionCount > 0 do
    FActions.Actions[0].Free;
  LList := FService.Repo.List(FKey);
  for LInfo in LList do
    Add(akPreview, Format(SPreviewPrefix, [LInfo.Design]), LInfo.Design, rfPdf).Checked := LInfo.IsDefault;
  if Length(LList) > 0 then
  begin
    Add(akPrint, SPrint, '', rfPdf);
    for F := Low(TRadReportFormat) to High(TRadReportFormat) do
      Add(akExport, RadReportFormatName[F], '', F);
    Add(akMail, SMailItem, '', rfPdf);
    for LInfo in LList do
      Add(akDesign, Format(SDesignPrefix, [LInfo.Design]), LInfo.Design, rfPdf);
  end;
  Add(akNewDesign, SNewDesign, '', rfPdf);
  Add(akManage, SManage, '', rfPdf);
end;

function TRadReportJob.Actions: TActionList;
begin
  FService.CheckAlive;
  RebuildActions;
  Result := FActions;
end;

procedure TRadReportJob.ActionExecute(Sender: TObject);
var
  LAction: TRadReportAction;
  LInfo: TRadReportInfo;
  LName: string;
  LList: TArray<TRadReportInfo>;

  function DefaultInfo: TRadReportInfo;
  var
    J: Integer;
  begin
    LList := FService.Repo.List(FKey);
    if Length(LList) = 0 then
      raise ERadReportNotFound.CreateFmt(SNoDesigns, [FKey]);
    for J := 0 to High(LList) do
      if LList[J].IsDefault then
        Exit(LList[J]);
    Result := LList[0];
  end;

begin
  LAction := Sender as TRadReportAction;
  case LAction.Kind of
    akPreview:
      if FService.Repo.Find(FKey, LAction.DesignName, LInfo) then
        DoPreview(LInfo);
    akPrint:
      DoPrint(DefaultInfo);
    akExport:
      ExportDialog(DefaultInfo, LAction.FileFormat);
    akMail:
      MailDialog(DefaultInfo);
    akDesign:
      if FService.Repo.Find(FKey, LAction.DesignName, LInfo) then
        DoDesign(LInfo, False);
    akNewDesign:
      begin
        LName := '';
        if not InputQuery(SNewDesign, SNewDesignPrompt, LName) or (Trim(LName) = '') then
          Exit;
        LInfo := Default(TRadReportInfo);
        LInfo.Key := FKey;
        LInfo.Design := Trim(LName);
        // DoDesign yeni tasarımın adını FDesign'dan alır; geçici olarak ayarla
        FDesign := LInfo.Design;
        try
          DoDesign(LInfo, True);
        finally
          FDesign := '';
        end;
      end;
    akManage:
      Manage;
  end;
end;

procedure TRadReportJob.FillMenu(AMenu: TMenuItem);
var
  I: Integer;
  LAction: TRadReportAction;
  LItem, LExport, LDesign: TMenuItem;
  LDesignCount, LOldCount: Integer;

  function NewItem(AParent: TMenuItem; AAction: TAction): TMenuItem;
  begin
    Result := TMenuItem.Create(AParent);
    Result.Action := AAction;
    AParent.Add(Result);
  end;

  procedure Separator(AParent: TMenuItem);
  var
    LSep: TMenuItem;
  begin
    LSep := TMenuItem.Create(AParent);
    LSep.Caption := '-';
    AParent.Add(LSep);
  end;

begin
  // Clear kullanılmaz: öğe sayısı sıfıra düşüp yeniden çıkınca VCL üst menüyü de söküp takar (TMenuItem.Delete/Insert,
  // MenuChanged(True)). Yeni öğeler önce eklenir, eskiler sonda silinir; menüde her an en az bir öğe kalır.
  LOldCount := AMenu.Count;
  RebuildActions;
  LExport := nil;
  LDesign := nil;
  LDesignCount := 0;
  for I := 0 to FActions.ActionCount - 1 do
    if TRadReportAction(FActions.Actions[I]).Kind = akDesign then
      Inc(LDesignCount);
  for I := 0 to FActions.ActionCount - 1 do
  begin
    LAction := TRadReportAction(FActions.Actions[I]);
    case LAction.Kind of
      akPreview:
        begin
          LItem := NewItem(AMenu, LAction);
          LItem.Default := LAction.Checked;
          LItem.Checked := False;
        end;
      akPrint:
        begin
          Separator(AMenu);
          NewItem(AMenu, LAction);
        end;
      akExport:
        begin
          if LExport = nil then
          begin
            LExport := TMenuItem.Create(AMenu);
            LExport.Caption := SExportMenu;
            AMenu.Add(LExport);
          end;
          NewItem(LExport, LAction);
        end;
      akMail:
        begin
          NewItem(AMenu, LAction);
          Separator(AMenu);
        end;
      akDesign:
        if LDesignCount = 1 then
          NewItem(AMenu, LAction).Caption := SDesignMenu
        else
        begin
          if LDesign = nil then
          begin
            LDesign := TMenuItem.Create(AMenu);
            LDesign.Caption := SDesignMenu;
            AMenu.Add(LDesign);
          end;
          NewItem(LDesign, LAction).Caption := LAction.DesignName;
        end;
      akNewDesign, akManage:
        NewItem(AMenu, LAction);
    end;
  end;
  for I := LOldCount - 1 downto 0 do
    AMenu[I].Free;
end;

procedure TRadReportJob.AddToMenu(AMenu: TMenuItem);
begin
  FService.CheckAlive;
  TMenuBinder.Create(AMenu, Self);
end;

// ---------------------------------------------------------------------- yönetim

function TRadReportJob.List: TArray<TRadReportInfo>;
begin
  FService.CheckAlive;
  Result := FService.Repo.List(FKey);
end;

function TRadReportJob.Versions: TArray<TRadReportVersion>;
begin
  Result := FService.Repo.Versions(Current.Id);
end;

procedure TRadReportJob.Copy(const ANewDesign: string);
begin
  FService.Repo.Copy(Current.Id, ANewDesign, FService.UserName);
end;

procedure TRadReportJob.Delete;
var
  LInfo: TRadReportInfo;
begin
  LInfo := Current;
  FService.Local.Backup(LInfo.Key, LInfo.Design, LInfo.Version, FService.Repo.Content(LInfo.Id));
  FService.Repo.Delete(LInfo.Id);
end;

procedure TRadReportJob.SetDefault;
begin
  FService.Repo.SetDefault(Current.Id);
end;

procedure TRadReportJob.Restore(AVersion: Integer);
var
  LInfo: TRadReportInfo;
begin
  LInfo := Current;
  FService.Repo.Save(LInfo, FService.Repo.Content(LInfo.Id, AVersion), Format('v%d geri yüklendi', [AVersion]),
    LInfo.Sha, FService.UserName);
end;

procedure TRadReportJob.DeleteOldVersions;
var
  LInfo: TRadReportInfo;
  LVersion: TRadReportVersion;
begin
  LInfo := Current;
  for LVersion in FService.Repo.Versions(LInfo.Id) do
    if LVersion.Version < LInfo.Version then
      FService.Local.Backup(LInfo.Key, LInfo.Design, LVersion.Version, FService.Repo.Content(LInfo.Id, LVersion.Version));
  FService.Repo.DeleteOldVersions(LInfo.Id);
end;

procedure TRadReportJob.ResetVersions;
var
  LInfo: TRadReportInfo;
  LVersion: TRadReportVersion;
begin
  LInfo := Current;
  for LVersion in FService.Repo.Versions(LInfo.Id) do
    FService.Local.Backup(LInfo.Key, LInfo.Design, LVersion.Version, FService.Repo.Content(LInfo.Id, LVersion.Version));
  FService.Repo.ResetVersions(LInfo.Id);
end;

function TRadReportJob.SyncToLocal: string;
var
  LInfo: TRadReportInfo;
  LLocal: TRadReportLocalInfo;
begin
  LInfo := Current;
  LLocal.ReportId := LInfo.Id;
  LLocal.Version := LInfo.Version;
  LLocal.Sha := LInfo.Sha;
  Result := FService.Local.Write(LInfo.Key, LInfo.Design, LLocal, FService.Repo.Content(LInfo.Id));
end;

function TRadReportJob.PushFromLocal: Boolean;
var
  LInfo: TRadReportInfo;
  LLocal: TRadReportLocalInfo;
begin
  LInfo := Current;
  if not FService.Local.Changed(LInfo.Key, LInfo.Design) then
    Exit(False);
  if not FService.Local.Read(LInfo.Key, LInfo.Design, LLocal) then
    LLocal.Sha := '';   // yan dosya yok: kaynağı bilinmiyor, çakışma denetlenemez
  Result := FService.Repo.Save(LInfo, FService.Local.Content(LInfo.Key, LInfo.Design), 'Yerel dosyadan',
    LLocal.Sha, FService.UserName);
  if Result then
  begin
    LLocal.ReportId := LInfo.Id;
    LLocal.Version := LInfo.Version;
    LLocal.Sha := LInfo.Sha;
    FService.Local.Write(LInfo.Key, LInfo.Design, LLocal, FService.Local.Content(LInfo.Key, LInfo.Design));
  end;
end;

// ====================================================================== TMenuBinder

constructor TMenuBinder.Create(AMenu: TMenuItem; const AJob: IRadReport);
var
  LParent: TMenu;
begin
  inherited Create(AMenu);   // menü öğesi yok olunca tutucu da gider; iş nesnesi o zamana kadar canlı
  FJob := AJob;
  FMenu := AMenu;
  LParent := AMenu.GetParentMenu;
  if LParent is TPopupMenu then
  begin
    // Liste menü ekrana gelmeden yenilenir. OnClick'e bağlanılmaz: alt menü açılırken VCL öğenin Click'ini çağırır
    // (WM_INITMENUPOPUP > DispatchPopup); orada yenilemek açık menüyü her fare gezişinde sorguyla yeniden kurar.
    FOldPopup := TPopupMenu(LParent).OnPopup;
    TPopupMenu(LParent).OnPopup := PopupHandler;
  end
  else
  begin
    // Ana menüde OnPopup yok; alt menü açılırken üst öğenin OnClick'i gelir
    FOldClick := AMenu.OnClick;
    AMenu.OnClick := ClickHandler;
  end;
  Rebuild;
end;

procedure TMenuBinder.PopupHandler(Sender: TObject);
begin
  if Assigned(FOldPopup) then
    FOldPopup(Sender);
  Rebuild;
end;

procedure TMenuBinder.ClickHandler(Sender: TObject);
begin
  // Yalnız ana menüde bağlıdır (bkz. Create)
  if Assigned(FOldClick) then
    FOldClick(Sender);
  Rebuild;
end;

procedure TMenuBinder.Rebuild;
var
  LJob: TRadReportJob;
begin
  LJob := FJob as TRadReportJob;
  LJob.FillMenu(FMenu);
end;

// ====================================================================== TRadReports

class function TRadReports.New(AConnection: TUniConnection; const AUserName: string): IRadReports;
begin
  Result := TRadReportsService.Create(AConnection, AUserName);
end;

initialization
  GServices := TList<TRadReportsService>.Create;

finalization
  // FastReport birimleri bu birimden SONRA sonlanır ama Vcl.Forms'tan ÖNCE; host servisi Application'a bağlı bir
  // nesnede tutuyorsa onu çok geç bırakır ve FastReport nesneleri çoktan gitmiş olur (Runtime error 216).
  // Bu yüzden canlı servislerin FastReport nesneleri burada, hâlâ güvenliyken bırakılır.
  for var LService in GServices.ToArray do
    LService.Shutdown;
  FreeAndNil(GServices);   // sonradan yok olan servisler Destroy'da nil denetler

end.
