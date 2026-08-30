(*
  Rad.Dev — DevExpress editor genislemeleri: zincirleme (kaskad) lookup.

  AMAC
    Sunucu tarafli, birbirini besleyen lookup zincirleri: Ulke → Sehir → Ilce →
    Mahalle, ya da Grup → Ara grup → Alt grup. Bir seviye secilince bir sonraki
    seviye FILTRELI olarak yeniden yuklenir.

  UCLU YAPI (DevExpress deseni)
    1. Properties      — ayarlar + olaylar (TRadLookupComboBoxProperties)
    2. RepositoryItem  — gridde paylasilan ayar tasiyicisi
    3. Component       — formdaki gorsel editor

  ZINCIR NASIL ISLER
    AComponent1..4  : bu editor degistiginde HABER VERILECEK hedefler
                      (bir editor ya da bir grid kolonu - kolon da bir
                      TComponent'tir: cxGridCustomTableView.pas:3406).
    CascadeField    : hedefe gecirilecek alan adi ("ulke_id" gibi).
    CascadeTag      : serbest tamsayi yuku (seviye no, tur kodu, ...).
    OnCascade       : dolu her hedef icin BIR kez tetiklenir; imzasi
                      (Sender, ASource, ATarget, AValue). Filtreyi/SQL'i
                      uygulamak UYGULAMANIN isidir - bilesen hedefi nasil
                      yenileyecegini bilmez.
    Tetikleyici     : DoEditValueChanged. Kullanicinin OnEditValueChanged
                      olayi TUKETILMEZ. csLoading/csDestroying/csDesigning
                      durumlarinda kaskad calismaz.

  ! TEK KISIT — AYNI RepositoryItem IKI ZINCIR KONUMUNDA PAYLASILAMAZ
    OLCULDU (src/test/scratch/rad_dev_repolisteners): bir RepositoryItem'a
    bagli TUM tuketiciler Properties'in AYNI ORNEGINI paylasir - hem formdaki
    editorun ActiveProperties'i hem grid kolonunun GetProperties'i, item'in
    Properties'iyle ayni isaretci. Dolayisiyla bir item'i hem "Sehir" hem
    "Ilce" konumunda kullanirsaniz ikisi de ayni AComponent listesini gorur ve
    zincir kendi uzerine katlanir. Her zincir konumu KENDI RepositoryItem'ini
    (ya da kendi Properties'ini) kullanmalidir.

    Ayni olcumun ikinci sonucu: Sender'a bakarak "hangi editor degisti"
    sorusu CEVAPLANAMAZ - OnCascade'in ASource parametresi bunun icin var.

    Kolonda published Properties, item'e bagliyken NIL kalir; etkin ornek
    public GetProperties ile alinir.

  AYNI ITEM'I FARKLI SORGULARLA KULLANMA (olculdu, DfmRoundTripTest)
    Bir tuketici IKI Properties nesnesi tasir:
      Editor.Properties        -> O TUKETICIYE OZEL. Item atansa bile ezilmez,
                                  DFM'e yazilir, geri okunur.
      Editor.ActiveProperties  -> PAYLASILAN (item'inki). Editoru gercekten
                                  bu suruyor.
    Grid kolonunda ayni ikilik var, iki farkli ad ile:
      Kolon.Properties     -> kendi nesnesi; ANCAK PropertiesClass (DFM'de
                              PropertiesClassName) atanmissa olusur, yoksa nil.
      Kolon.GetProperties  -> paylasilan olan.

    Desen: ortak davranis + ortak olaylar item'da, yere ozel yuk
    (CascadeField/CascadeTag, zincir yuvalari) her tuketicinin KENDI
    Properties'inde. Boylece tek bir item'i cok yerde, her yerde farkli bir
    sorguyla kullanabilirsiniz.

    ! Yere ozel yuku Items/ListSource gibi ANLAMI OLAN property'lere koymayin:
      Object Inspector'da gercek gorunur, DFM'e yazilir, ama editor onlari
      asla kullanmaz (kullandigi ActiveProperties'tir). CascadeField/CascadeTag
      tam bu is icindir.

    Tuketicinin kendi/etkin Properties'ine, degerine, Caption'ina, DataSet ve
    Field'ina bilesen tipinden bagimsiz erisim: help.Dev.pas'taki
    _OwnProperties / _ActiveProperties / _ValueOf / _CaptionOf / _DataSetOf /
    _FieldOf yordamlari.

  TUKETICILERI SAYMA
    TRadEditRepositoryItem.ConsumerCount / Consumers(i) bir RepositoryItem'i
    su an kullanan editor ve kolonlari verir. Yukaridaki kisiti calisma
    zamaninda denetlemek icin de kullanilabilir - hazir denetim:
    TRadEditRepositoryItem.ChainWarning.

  ARAMAYI GECIKTIRME
    Properties.SearchDelay > 0 iken OnSearch her tus vurusunda degil, tuslar
    durduktan SearchDelay ms sonra BIR kez tetiklenir. 0 (varsayilan) eski
    davranistir. Sunucu tarafli aramada fark buyuk.

  AYNI LISTE SORGUSUNU PAYLASAN EDITORLER
    Iki editor ayni TDataSource'u kullaniyorsa birinin isleyicisi digerinin
    cozumlemesini tetikleyebilir ve ic ice sorgu ac/kapa olusur.
    TRadBusyDataSets bu ozyinelemeyi keser.

  DONGU KORUMASI
    A → B → A seklinde kapanan bir zincir yigin tukenene kadar donerdi;
    DoCascade tekrar-girise kapalidir (olculdu: dongu iki olayda duruyor).

  PERFORMANS NOTU
    GetDisplayLookupText CIZIM yolunda cagrilir. Grid 50 satir cizerken 50 kez
    OnLocate tetiklenmesin diye son cozulen anahtar onbelleklenir
    (FLastKey/FHasLastKey). Kaskad, hedefin bu onbellegini kendisi bosaltir -
    yoksa liste yeniden suzuldukten sonra hedef bos metin gosterirdi.

  IKI AILE, IKI FARKLI KALITIM SEKLI
    Lookup : TRadLookupComboBox ve TRadDBLookupComboBox ortak
             TRadCustomLookupComboBox'tan turer (DevExpress'in kendi ayrimi).
    Combo  : TRadComboBox ve TRadDBComboBox saticinin somut siniflarindan
             turer - gerekcesi kendi bildirimlerinin yaninda yazili.
*)
unit Rad.Dev;

interface

uses
  SysUtils, Classes, Variants, Vcl.Controls,cxDBNavigator, cxNavigator,  data.DB,
  Vcl.ActnList,  Actions, Windows, Winapi.Messages,
  cxGridCustomView,cxGridDBDataDefinitions, cxGridCustomTableView,
  cxEdit, cxGridTableView,cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, cxStyles, cxCustomData, cxFilter, cxData,
  cxDataStorage,  dxDateRanges, dxScrollbarAnnotations,
  cxDBData, cxGridLevel, cxClasses,
  cxGridDBTableView, cxGrid
  ,cxDropDownEdit,Generics.Collections,cxDBEdit,cxContainer
  ,cxDBLookupEdit,cxDBLookupComboBox,cxLookupEdit,dxCoreClasses
  ,System.Types  { TList.Remove satir ici acilimi icin - H2443 }
  ,Vcl.ExtCtrls  { SearchDelay geciktiricisinin TTimer'i }
  ,rad.lookup;   { lookup TANIMLARININ kayit defteri }

type
  {*
  1: Properties Olu�tur;
  2: RepositoryItem Olu�tur
  3: Component Olu�tur

  *}

  {$REGION 'TRadLookupComboBoxProperties'}

  TRadLookupComboBoxProperties = class;

  (* ── Zincir yuvalari ─────────────────────────────────────────────────────
     Dort bilesen referansi + onlari koruyan serbest-birakma bildiricisi.

     NEDEN AYRI BIR SINIF: ayni yuva kumesi hem Lookup hem ComboBox Properties
     sinifinda lazim, ama ikisinin ATALARI farkli (TcxLookupComboBoxProperties
     ve TcxComboBoxProperties) - ortak bir taban sinif turetilemiyor. Kodu iki
     kez yazmak yerine iki Properties de BUNU tasiyor ve delege ediyor
     (workspace kurali: layered-function-design.md).

     NEDEN KENDI BILDIRICIMIZ: Properties bir TPersistent'tir, Notification
     ALAMAZ. DevExpress ayni sorunu Images icin gizli bir yardimci BILESENLE
     cozuyor (TcxCustomEditProperties.GetFreeNotificator, cxEdit.pas:1639) ama
     o alan PRIVATE - torun erisemez. Bu yuzden ayni deseni kendi ornegimizle
     kuruyoruz. Koruma olmazsa: zincirdeki editor/kolon yok edilince isaretci
     sarkar ve ilk erisimde erisim ihlali olur (kit kurali,
     component-patterns.md). *)
  TRadSlotNotify = procedure (ATarget: TComponent; const AValue: Variant) of object;

(*  ── Liste dataset'i ozyineleme kilidi ────────────────────────────────────
    Iki editor AYNI liste sorgusunu paylasabilir (ayni TDataSource). Birinin
    OnSearch/OnLocate isleyicisi sorguyu kapatip acarken, bu digerinin
    goruntu cozumlemesini tetikler; o da ayni sorguyu kapatip acmak ister ve
    ic ice bir yeniden giris olusur - en iyi ihtimalle bosa is, en kotusunde
    sonsuz dongudur.

    Tek is parcacigi (VCL ana thread) oldugu icin "su an degisiyor" ancak biz
    zaten o dataset icin bir isleyicinin ICINDEYSEK dogru olabilir; yani bu
    bir kilit degil, OZYINELEME koruyucusudur. Farkli dataset'ler birbirini
    hic etkilemez.

    Fikir Rad.FilterLookupEdit.pas'taki (2011, kaynagi belirsiz) ayni amacli
    BeginChangeDataSet/EndChangeDataSet desenindendi; kod bu birim icin
    bastan yazildi. *)
  TRadBusyDataSets = class
  private
    class var FItems: TList;
  public
    class constructor Create;
    class destructor Destroy;
    class function IsBusy(ADataSet: TDataSet): Boolean; static;
    class procedure Enter(ADataSet: TDataSet); static;
    class procedure Leave(ADataSet: TDataSet); static;
  end;

  (* ── Repository ortak atasi ──────────────────────────────────────────────
     Bir RepositoryItem'i KULLANAN bilesenleri (formdaki editorler ve grid
     kolonlari) sayilabilir kilar.

     NASIL CALISIYOR (olculdu, RepoListenerTest): TcxEditRepositoryItem her
     tuketicisini bir IcxEditRepositoryItemListener olarak kaydeder ve
     AddListener/RemoveListener SANAL + PUBLIC'tir (cxEdit.pas:255/260).
     Listenin kendisi STRICT PRIVATE oldugu icin okunamaz - ama torun kendi
     kopyasini tutabilir. Arayuz referansi TComponent tabanli bir nesneden
     geldigi icin "as TObject" ile bilesene geri donulebilir.

     Olculen davranis: bir editor + bir grid kolonu baglandiginda liste
     TRadLookupComboBox ve TcxGridColumn'u dogru sirayla verdi; editorun
     RepositoryItem'i nil'lenince liste 1'e dustu - yani sarkma yok.

     NE ISE YARAR: bir RepositoryItem'a bagli TUM tuketiciler AYNI Properties
     ORNEGINI paylasir, dolayisiyla Properties'e bakarak "hangi editor"
     sorusu cevaplanamaz. Zincir mantiginin tuketicileri gormesi gerektiginde
     tek dogru kaynak burasidir. Ayni sebeple birim basligindaki "bir
     RepositoryItem iki zincir konumunda paylasilamaz" kisiti bu liste
     uzerinden calisma zamaninda denetlenebilir. *)
  TRadEditRepositoryItem = class(TcxEditRepositoryItem)
  private
    FConsumers: TList;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AddListener(AListener: IcxEditRepositoryItemListener); override;
    procedure RemoveListener(AListener: IcxEditRepositoryItemListener); override;
    /// <summary>Bu item'i su an kullanan editor/kolon sayisi.</summary>
    function ConsumerCount: Integer;
    /// <summary>AIndex'inci tuketici (editor ya da grid kolonu); cozulemezse nil.</summary>
    function Consumers(AIndex: Integer): TComponent;
    (* Zincir catismasi denetimi. Bos string = sorun yok.

       NE YAKALAR: bu item'in KENDI Properties'inde zincir kurulmus (en az bir
       AComponent dolu) VE item birden fazla tuketici tarafindan kullaniliyor.
       Olculdu: tum tuketiciler ayni Properties ornegini paylasir, yani ikisi
       de ayni hedeflere haber verir - zincir kendi uzerine katlanir.

       NE YAKALAMAZ (ve yakalamamali): zincir her tuketicinin KENDI
       Properties'inde kurulmussa item'in slotlari bostur ve paylasim tamamen
       gecerlidir. Bu, dogru kullanim desenidir.

       Otomatik uyari DEGIL, sorgulanabilir bir denetimdir: DFM yuklenirken
       ara durumlar gecici olarak catisik gorunur, orada uyarmak yanlis alarm
       uretirdi. Tasarim zamaninda bir dogrulama adiminda ya da testte cagirin. *)
    function ChainWarning: string;
  end;

  TRadEditSlots = class
  public const
    CCount = 4;
  private
    FMaster: TObject;
    FItems: array[1..CCount] of TComponent;
    FNotificator: TcxFreeNotificator;
    function  GetNotificator: TcxFreeNotificator;
    procedure SlotFreeNotification(Sender: TComponent);
    function  Contains(AComponent: TComponent): Boolean;
  public
    constructor Create(AMaster: TObject);
    destructor Destroy; override;
    function  Get(AIndex: Integer): TComponent;
    procedure Put(AIndex: Integer; const AValue: TComponent);
    /// <summary>Dolu yuva sayisi.</summary>
    function  FilledCount: Integer;
    /// <summary>Dolu her yuva icin ACallback'i bir kez cagirir.</summary>
    procedure ForEach(const ACallback: TRadSlotNotify; const AValue: Variant);
    procedure Assign(ASource: TRadEditSlots);
  end;

  (* ADI BILINCLI OLARAK FARKLI: eskiden DevExpress'in sinifiyla BIREBIR ayni
     adi tasiyordu (cxDBLookupEdit.TcxCustomDBLookupEditLookupData). Iki birimi
     birden uses'a alan bir cagirici icin hangi tipin geldigi uses SIRASINA
     bagli oluyor ve derleyici hicbir sey soylemiyordu. *)
  TRadLookupEditLookupData = class(cxDBLookupEdit.TcxCustomDBLookupEditLookupData)
   protected
    function Locate(var AText, ATail: string; ANext: Boolean): Boolean; override;
  end;
    TRadLookupSearchEvent  = procedure (Sender:TRadLookupComboBoxProperties; var AText, ATail: string; ANext: Boolean) of object;
    TRadLookupLocateEvent  = procedure (Sender:TRadLookupComboBoxProperties; const AKey: Variant) of object;
    (* Zincirin bir halkasi degistiginde, bagli her hedef icin BIR kez
       tetiklenir. Bilesen hedefi nasil yenileyecegini BILMEZ - filtreyi/SQL'i
       uygulamanin tek dogru yeri uygulamadir; buradaki is yalnizca
       "kim degisti / kime haber verilecek / hangi degerle" ucgenini tasimak.

       ASource NEDEN AYRI BIR PARAMETRE: Sender, Properties'tir - ve bir
       RepositoryItem'a bagli TUM tuketiciler AYNI Properties ORNEGINI
       paylasir (olculdu: editor.ActiveProperties ve kolon.GetProperties,
       item.Properties ile ayni isaretci). Yani Sender'a bakarak hangi
       editorun degistigini AYIRT EDEMEZSINIZ; ASource bunun icin var.

       Gridde ASource, kolonun kendisi degil o anki inplace EDITORDUR.
       Kolona ulasmak gerekirse repository item uzerinden
       TRadEditRepositoryItem.Consumers listesine bakin. *)
    TRadCascadeEvent = procedure (Sender:TRadLookupComboBoxProperties;
      ASource, ATarget: TComponent; const AValue: Variant) of object;

    TRadLookupComboBoxProperties = class(TcxLookupComboBoxProperties)
    private
      FStr: string;
      FInt: Integer;
      FSlots: TRadEditSlots;
      FSearchEvent: TRadLookupSearchEvent;
      FLocateEvent: TRadLookupLocateEvent;
      FCascadeEvent: TRadCascadeEvent;
      (* IKI AYRI ONBELLEK - ayni sey degiller, birlestirmek hata uretir.

         1) OLAY BASTIRMA (FLastKey/FHasLastKey): "bu anahtar icin OnLocate
            zaten tetiklendi". DoLocate doldurur.
         2) METIN ONBELLEGI (FTextKey/FHasText/FLastText): "bu anahtarin
            gosterilecek metni su". YALNIZCA PrepareDisplayValue'nun isabetsiz
            dalinda, tabanin URETTIGI degerle dolar.

         NEDEN AYRI (olculdu, LiveLookupTest M4): tek bayrakta birlestirilince
         DoLocate bayragi set ediyor ama metni dolduramiyor (metni taban uretir,
         DoLocate'ten sonra). Sonraki PrepareDisplayValue "onbellekte var"
         deyip BOS string donduruyordu - editorde metin kayboluyor. Canli
         veritabani testi yakaladi; birim testi yakalayamazdi cunku bos metin
         de gecerli bir metindir. *)
      FLastKey: Variant;
      FHasLastKey: Boolean;
      FTextKey: Variant;
      FHasText: Boolean;
      FLastText: string;
      FSearchDelay: Cardinal;
      FMinSearchLength: Integer;
      FClearTargets: Boolean;
      FLookupCode: string;
      FLookupDef: TRadLookupDef;
      (* A → B → A dongusune karsi. Zincirin bir halkasi, kendisini besleyen
         halkayi yeniden tetiklerse yigin tukenene kadar donerdi; ne derleyici
         ne test bunu yakalar. Bu kitte olculmus bir emsali var: geri besleme
         dongusu 30 saniyede 796.240 isleyici girisi (delphi-conventions.md). *)
      FCascading: Boolean;
      { Kaskad suresince degisikligi baslatan editor. Olay imzasina ek
        parametre koymak yerine alanda tutuluyor: ForEach geri cagirimi
        TRadSlotNotify imzasina bagli. }
      FCascadeSource: TComponent;
      function  GetSlot(AIndex: Integer): TComponent;
      procedure SetSlot(AIndex: Integer; const AValue: TComponent);
      procedure SetLookupCode(const AValue: string);
      procedure CascadeOne(ATarget: TComponent; const AValue: Variant);
      function  ListDataSet: TDataSet;
      procedure ClearTarget(ATarget: TComponent);
      class function TargetProperties(ATarget: TComponent): TRadLookupComboBoxProperties; static;
    protected
        class function GetLookupDataClass: TcxInterfacedPersistentClass; override;
        (* Ozel alanlarimizi KOPYALAMAK ZORUNDAYIZ. TcxCustomEditProperties.Assign
           dogrudan DoAssign'a gider ve taban kendi olaylarini orada tek tek
           kopyalar (cxEdit.pas). Override etmezsek "Editor.Properties := X"
           zincir baglarini, olaylari ve AAStr/AAInt yukunu SESSIZCE dusurur -
           derleyici de calisma zamani da hicbir sey soylemez. *)
        procedure DoAssign(AProperties: TcxCustomEditProperties); override;
        function GetDisplayLookupText(const AKey: TcxEditValue): string; override;
        procedure DoSearch(var AText, ATail: string; ANext: Boolean);
        procedure DoLocate(const AKey: Variant);
    public
      (* Grid, inplace editoru BU siniftan uretir. Override edilmezse taban
         stok TcxLookupComboBox'i dondurur (cxDBLookupComboBox.pas:405) ve
         DoEditValueChanged override'imiz gridde HIC calismaz - kaskad
         yalnizca formda isler, gridde sessizce olmaz.
         PUBLIC olmak zorunda: taban public bildirmis (H2269). *)
      class function GetContainerClass: TcxContainerClass; override;
      (* Cozulmus anahtar/metin ciftini olay tetiklemeden dogrudan verir.
         GetDisplayLookupText'ten daha erken bir seam - grid cizerken tum
         cozumleme yolunu atlatir.
         PUBLIC olmak zorunda: taban public bildirmis (H2269). *)
      procedure PrepareDisplayValue(const AEditValue: TcxEditValue;
        var DisplayValue: TcxEditValue; AEditFocused: Boolean); override;
      (* Geciktirici tetikledi. FindLookupText taban Properties'te PROTECTED
         oldugu icin kontrol onu dogrudan cagiramaz - bu yuzden "ara ve bul"
         adimi burada, torun Properties'te duruyor. *)
      procedure TimedSearch(const AText: string);
      constructor Create(AOwner: TPersistent); override;
      destructor Destroy; override;
      /// <summary>Bagli her zincir hedefi icin OnCascade'i tetikler.
      /// ASource degisikligi baslatan editordur.</summary>
      procedure DoCascade(ASource: TComponent; const AValue: Variant);
      /// <summary>Cozulmus-anahtar onbellegini bosaltir (liste degistiyse).</summary>
      procedure ResetLocateCache;
      /// <summary>Dolu zincir yuvasi sayisi (ChainWarning icin).</summary>
      function ChainSlotCount: Integer;
      (* LookupCode cozulduyse ilgili tanim, yoksa nil. Olay isleyicileri
         sorguyu ve parametre adlarini buradan okur - kayit defterine tekrar
         basvurmalari gerekmez. *)
      property LookupDef: TRadLookupDef read FLookupDef;
    published
      property AComponent1:TComponent index 1 read GetSlot write SetSlot;
      property AComponent2:TComponent index 2 read GetSlot write SetSlot;
      property AComponent3:TComponent index 3 read GetSlot write SetSlot;
      property AComponent4:TComponent index 4 read GetSlot write SetSlot;
      /// <summary>Zincirde hedefe suzme icin gecirilecek alan adi
      /// (ornegin "ulke_id"). Bileseni ilgilendirmez; OnCascade isleyicisine
      /// tasinan serbest yuktur.</summary>
      property CascadeField:string  read FStr write FStr;
      /// <summary>Zincir icin serbest tamsayi yuku (seviye no, tur kodu, ...).</summary>
      property CascadeTag:Integer read FInt write FInt;
      property Buttons;
      property OnButtonClick;
      property Images;
      property OnSearch:TRadLookupSearchEvent read FSearchEvent write FSearchEvent;
      property OnLocate:TRadLookupLocateEvent read FLocateEvent write FLocateEvent;
      (* 0 = kapali (varsayilan, eski davranis): OnSearch her tus vurusunda,
         Locate seam'inden tetiklenir.
         >0 = milisaniye cinsinden GECIKTIRME: tuslar durduktan bu kadar sonra
         OnSearch BIR kez tetiklenir. Sunucu tarafli aramada fark buyuk -
         "Istanbul" yazmak 8 sorgu yerine 1 sorgu eder. *)
      property SearchDelay:Cardinal read FSearchDelay write FSearchDelay default 0;
      (* OnSearch, yazilan metin BU UZUNLUGA erisene kadar hic tetiklenmez.
         0 = kapali (varsayilan). Sunucu tarafli aramada onemli: tek harflik
         bir arama tablonun buyuk bolumunu doner, hem sunucuyu hem agi bosa
         yorar. Tipik deger 2-3. *)
      property MinSearchLength:Integer read FMinSearchLength write FMinSearchLength default 0;
      (* True iken, bir hedefe OnCascade gonderilmeden ONCE hedefin degeri
         temizlenir. Klasik kaskad hatasini kapatir: ulke degisir, sehir
         listesi yenilenir, ama eski sehir DEGERI editorde kalir ve yeni
         listede olmayan bir anahtar gosterilir.

         Yalnizca TcxCustomEdit hedeflerinde islem yapar - bir grid KOLONUNUN
         "degeri" satira gore degisir, kolon duzeyinde temizlemek anlamsizdir.
         Varsayilan False: davranis degisikligi opt-in. *)
      property ClearTargetsOnCascade:Boolean read FClearTargets write FClearTargets default False;
      (* Bu editorun hangi TANIMI gosterdigi - "MARKA", "MUSTERI_TIPI" gibi.
         Atandiginda, kayit defterindeki tanim bu Properties'e uygulanir:
         KeyFieldNames, ListFieldNames, MinSearchLength, SearchDelay ve
         CascadeField (ust parametrenin adi) tanimdan gelir.

         NEDEN KOD, tek tek ayar degil: yeni bir tanim turu eklemek boylece
         FORM DEGISIKLIGI degil, kayit defterine bir SATIR eklemek olur.

         Kayit defteri bos ya da kod bilinmiyorsa SESSIZ kalir - tasarim
         zamaninda ve kayit defteri yuklenmeden once bu normaldir. Kodun
         cozulup cozulmedigini LookupDef <> nil ile anlarsiniz. *)
      property LookupCode:string read FLookupCode write SetLookupCode;
      property OnCascade:TRadCascadeEvent read FCascadeEvent write FCascadeEvent;
    end;

    TRadLookupComboBoxRepository = class(TRadEditRepositoryItem)
    private
      function GetProperties: TRadLookupComboBoxProperties;
      procedure SetProperties(Value: TRadLookupComboBoxProperties);
    public
      class function GetEditPropertiesClass: TcxCustomEditPropertiesClass; override;
    published
      property Properties: TRadLookupComboBoxProperties read GetProperties write SetProperties;
    end;

  (* ── Ortak ata ───────────────────────────────────────────────────────────
     Zincir davranisinin TAMAMI burada; iki somut sinif yalnizca hangi
     published listesini tasiyacaklarina karar veriyor.

     NEDEN AYRI BIR ATA: DB olan sinif eskiden non-DB somut siniftan
     turuyordu ve onun published listesini - iceriden EditValue'yu de -
     miras aliyordu. DB editorde deger ALANDAN gelir; EditValue'nun DFM'e
     yazilmasi yanlistir. DevExpress ayni ayrimi yapiyor: TcxLookupComboBox
     ve TcxDBLookupComboBox'in IKISI de ortak TcxCustomLookupComboBox'tan
     turer (cxDBLookupComboBox.pas:177 ve 225), biri digerinden degil. *)
  TRadCustomLookupComboBox = class(TcxCustomLookupComboBox)
    private
      function GetProperties: TRadLookupComboBoxProperties;
      function GetActiveProperties: TRadLookupComboBoxProperties;
      procedure SetProperties(Value: TRadLookupComboBoxProperties);
    private
      FSearchTimer: TTimer;
      procedure SearchTimerTick(Sender: TObject);
      procedure RestartSearchTimer;
    protected
      procedure DoEditKeyPress(var Key: Char); override;
      procedure DoEditKeyDown(var Key: Word; Shift: TShiftState); override;
      (* Zincirin TETIKLEYICISI. TcxCustomEdit.DoEditValueChanged sanaldir
         (cxEdit.pas:1908) ve deger her degistiginde cagrilir - kullanicinin
         OnEditValueChanged olayini TUKETMEDEN araya girmenin dogru yeri budur.
         Gridde de calisir, cunku Properties.GetContainerClass asagidaki
         non-DB sinifi donduruyor. *)
      procedure DoEditValueChanged; override;
    public
      destructor Destroy; override;
      (* Kaskadi ELLE tetikler. Gerekli, cunku DoEditValueChanged
         csLoading/csDesigning durumlarinda bilincli olarak sessiz kalir:
         bir kaydi programatik yuklerken (form olusurken EditValue atamak,
         DataSet'ten doldurmak) hedefler HIC haber almazdi. Yukleme bittikten
         sonra bunu cagirin. *)
      procedure CascadeNow;
      class function GetPropertiesClass: TcxCustomEditPropertiesClass; override;
      property ActiveProperties: TRadLookupComboBoxProperties read GetActiveProperties;
      property Properties: TRadLookupComboBoxProperties read GetProperties write SetProperties;
    end;

  { Non-DB somut sinif. Gridin inplace editoru de budur -
    TRadLookupComboBoxProperties.GetContainerClass bunu dondurur. }
  TRadLookupComboBox = class(TRadCustomLookupComboBox)
  published
    property Anchors;
    property AutoSize;
    property BeepOnEnter;
    property BiDiMode;
    property Constraints;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property ParentBiDiMode;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property Properties;
    property EditValue;
    property ShowHint;
    property Style;
    property StyleDisabled;
    property StyleFocused;
    property StyleHot;
    property StyleReadOnly;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnEditing;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
  end;

  { DB somut sinif. EditValue BILINCLI olarak published DEGIL: deger
    DataBinding uzerinden alandan gelir. }
  TRadDBLookupComboBox = class(TRadCustomLookupComboBox)
  private
    function GetDataBinding: TcxDBTextEditDataBinding;
    procedure SetDataBinding(Value: TcxDBTextEditDataBinding);
    procedure CMGetDataLink(var Message: TMessage); message CM_GETDATALINK;
  protected
    class function GetDataBindingClass: TcxEditDataBindingClass; override;
  published
    property Anchors;
    property AutoSize;
    property BeepOnEnter;
    property BiDiMode;
    property Constraints;
    property DragCursor;
    property DragKind;
    property DataBinding: TcxDBTextEditDataBinding read GetDataBinding write SetDataBinding;
    property DragMode;
    property Enabled;
    property ParentBiDiMode;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property Properties;
    property ShowHint;
    property Style;
    property StyleDisabled;
    property StyleFocused;
    property StyleHot;
    property StyleReadOnly;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnEditing;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
  end;



  {$ENDREGION}

  TRadComboBoxProperties = class;

  (* Lookup ailesindeki TRadCascadeEvent ile ayni sozlesme, farkli Sender
     tipi. Ayni gerekceler oradaki yorumda. *)
  TRadComboCascadeEvent = procedure (Sender: TRadComboBoxProperties;
    ASource, ATarget: TComponent; const AValue: Variant) of object;

  TRadComboBoxProperties = class(TcxComboBoxProperties)
  private
    FInt: Integer;
    FStr: string;
    { Yuvalar ve serbest-birakma korumasi Lookup ailesiyle AYNI tutucudan
      gelir - iki yerde ayni kodu tutmuyoruz. }
    FSlots: TRadEditSlots;
    FCascadeEvent: TRadComboCascadeEvent;
    FCascading: Boolean;
    FCascadeSource: TComponent;
    function  GetSlot(AIndex: Integer): TComponent;
    procedure SetSlot(AIndex: Integer; const AValue: TComponent);
    procedure CascadeOne(ATarget: TComponent; const AValue: Variant);
   protected
    { Lookup ailesindekiyle ayni gerekce - bkz. oradaki DoAssign notu. }
    procedure DoAssign(AProperties: TcxCustomEditProperties); override;
   public
    (* Gridin inplace editoru. Taban stok TcxComboBox donduruyor
       (cxDropDownEdit.pas:4168); override etmezsek kaskad gridde calismaz -
       Lookup ailesindekiyle ayni tuzak.
       PUBLIC olmak zorunda: taban public bildirmis (H2269). *)
    class function GetContainerClass: TcxContainerClass; override;
    constructor Create(AOwner: TPersistent); override;
    destructor Destroy; override;
    /// <summary>Bagli her zincir hedefi icin OnCascade'i tetikler.</summary>
    procedure DoCascade(ASource: TComponent; const AValue: Variant);
    /// <summary>Dolu zincir yuvasi sayisi (ChainWarning icin).</summary>
    function ChainSlotCount: Integer;
    //procedure DoAssign(AProperties: TcxCustomEditProperties); override;
    //procedure DoInitPopup(Sender: TObject);
    //procedure PrepareDisplayValue(const AEditValue: Variant; var DisplayValue: Variant; AEditFocused: Boolean); override;
    //function DefaultAllowDropDownWhenReadOnly: Boolean; override;
  published
    property AComponent1:TComponent index 1 read GetSlot write SetSlot;
    property AComponent2:TComponent index 2 read GetSlot write SetSlot;
    property AComponent3:TComponent index 3 read GetSlot write SetSlot;
    property AComponent4:TComponent index 4 read GetSlot write SetSlot;
    /// <summary>Bkz. TRadLookupComboBoxProperties.CascadeField.</summary>
    property CascadeField:string  read FStr write FStr;
    /// <summary>Bkz. TRadLookupComboBoxProperties.CascadeTag.</summary>
    property CascadeTag:Integer read FInt write FInt;
    property OnCascade:TRadComboCascadeEvent read FCascadeEvent write FCascadeEvent;

    property AllowDropDownWhenReadOnly default True;
    property Buttons;
    property Alignment;
    property AssignedValues;
    property AutoSelect;
    property BeepOnError;
    property ButtonGlyph;
    property CaseInsensitive;
    property CharCase;
    property ClearKey;
    property DropDownAutoWidth;
    property DropDownListStyle;
    property DropDownRows;
    property DropDownSizeable;
    property DropDownWidth;
    property HideSelection;
    property IgnoreMaskBlank;
    property Images;
    property ImeMode;
    property ImeName;
    property ImmediateDropDownWhenActivated;
    property ImmediateDropDownWhenKeyPressed;
    property ImmediatePost;
    property ImmediateUpdateText;
    property IncrementalFiltering;
    property IncrementalFilteringOptions;
    property IncrementalSearch;
    property ItemHeight;
    property Items;
    property MaskKind;
    property EditMask;
    property MaxLength;
    property Nullstring;
    property OEMConvert;
    property PopupAlignment;
    property PostPopupValueOnTab;
    property ReadOnly;
    property Revertable;
    property Sorted;
    property UseLeftAlignmentOnEditing;
    property UseNullString;
    property ValidateOnEnter;
    property ValidationErrorIconAlignment;
    property ValidationOptions;
    property OnChange;
    property OnCloseUp;
    property OnDrawItem;
    property OnEditValueChanged;
    property OnInitPopup;
    property OnMeasureItem;
    property OnNewLookupDisplayText;
    property OnButtonClick;
    property OnPopup;
    property OnValidate;

    end;

  TRadComboBoxRepository = class(TRadEditRepositoryItem)
    private
      function GetProperties: TRadComboBoxProperties;
      procedure SetProperties(Value: TRadComboBoxProperties);
    public
      class function GetEditPropertiesClass: TcxCustomEditPropertiesClass; override;
    published
      property Properties: TRadComboBoxProperties read GetProperties write SetProperties;
    end;


  (* NEDEN BURADA ORTAK BIR ATA YOK - Lookup ailesinden farkli:
     TcxComboBox ve TcxDBComboBox KARDESTIR (ikisi de TcxCustomComboBox'tan,
     cxDropDownEdit.pas:903 ve cxDBEdit.pas:562). Lookup'ta oldugu gibi ortak
     bir Rad atasi kurmak, DevExpress'in iki ayri published listesini bu birime
     KOPYALAMAYI gerektirirdi; kopyalanan liste satici surumu degistikce
     sessizce bayatlar. Bunun yerine iki somut sinif da saticinin kendi
     somut sinifindan turuyor (published listeler mirasla, kopyasiz geliyor)
     ve yalnizca dort satirlik tetikleyici iki kez yaziliyor - gorunur,
     bayatlamayan bir tekrar. *)

  { Non-DB somut sinif. Gridin inplace editoru budur. }
  TRadComboBox = class(TcxComboBox)
  private
    function GetActiveProperties: TRadComboBoxProperties;
    function GetProperties: TRadComboBoxProperties;
    procedure SetProperties(Value: TRadComboBoxProperties);
  protected
    procedure DoEditValueChanged; override;
  public
    class function GetPropertiesClass: TcxCustomEditPropertiesClass; override;
    property ActiveProperties: TRadComboBoxProperties read GetActiveProperties;
  published
    property Properties: TRadComboBoxProperties read GetProperties write SetProperties;
  end;

  TRadDBComboBox = class(TcxDBComboBox)
  private
    function GetActiveProperties: TRadComboBoxProperties;
    function GetProperties: TRadComboBoxProperties;
    procedure SetProperties(Value: TRadComboBoxProperties);
  protected
    procedure DoEditValueChanged; override;
  public
    class function GetPropertiesClass: TcxCustomEditPropertiesClass; override;
    property ActiveProperties: TRadComboBoxProperties read GetActiveProperties;
  published
    property Properties: TRadComboBoxProperties read GetProperties write SetProperties;
  end;




implementation
  uses Help.Dev,DBAccess, Vcl.Dialogs, Help.vcl;

{ TRadBusyDataSets }

class constructor TRadBusyDataSets.Create;
begin
  FItems := TList.Create;
end;

class destructor TRadBusyDataSets.Destroy;
begin
  FItems.Free;
end;

class function TRadBusyDataSets.IsBusy(ADataSet: TDataSet): Boolean;
begin
  Result := (ADataSet <> nil) and (FItems.IndexOf(ADataSet) >= 0);
end;

class procedure TRadBusyDataSets.Enter(ADataSet: TDataSet);
begin
  if ADataSet <> nil then
    FItems.Add(ADataSet);
end;

class procedure TRadBusyDataSets.Leave(ADataSet: TDataSet);
begin
  if ADataSet <> nil then
    FItems.Remove(ADataSet);
end;

{ TRadEditRepositoryItem }

constructor TRadEditRepositoryItem.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FConsumers := TList.Create;
end;

destructor TRadEditRepositoryItem.Destroy;
begin
  FConsumers.Free;
  inherited Destroy;
end;

procedure TRadEditRepositoryItem.AddListener(AListener: IcxEditRepositoryItemListener);
begin
  inherited AddListener(AListener);
  { Isaretci olarak saklaniyor: tuketiciler TComponent tabanli, referans
    sayimi yok; arayuz referansi tutmak yasam suresini uzatmaz ama gereksiz
    yere kilitler. }
  if FConsumers.IndexOf(Pointer(AListener)) < 0 then
    FConsumers.Add(Pointer(AListener));
end;

procedure TRadEditRepositoryItem.RemoveListener(AListener: IcxEditRepositoryItemListener);
begin
  FConsumers.Remove(Pointer(AListener));
  inherited RemoveListener(AListener);
end;

function TRadEditRepositoryItem.ConsumerCount: Integer;
begin
  Result := FConsumers.Count;
end;

function TRadEditRepositoryItem.Consumers(AIndex: Integer): TComponent;
var
  LIntf: IcxEditRepositoryItemListener;
  LObj: TObject;
begin
  Result := nil;
  if (AIndex < 0) or (AIndex >= FConsumers.Count) then
    Exit;
  LIntf := IcxEditRepositoryItemListener(FConsumers[AIndex]);
  LObj := LIntf as TObject;
  if LObj is TComponent then
    Result := TComponent(LObj);
end;

function TRadEditRepositoryItem.ChainWarning: string;
var
  LFilled, LUsers: Integer;
begin
  Result := '';
  LFilled := 0;
  if Properties is TRadLookupComboBoxProperties then
    LFilled := TRadLookupComboBoxProperties(Properties).ChainSlotCount
  else if Properties is TRadComboBoxProperties then
    LFilled := TRadComboBoxProperties(Properties).ChainSlotCount;
  if LFilled = 0 then
    Exit;

  LUsers := ConsumerCount;
  if LUsers > 1 then
    Result := Format(
      '%s: zincir bu RepositoryItem''in KENDI Properties''inde kurulu ' +
      '(%d hedef), ama item %d tuketici tarafindan paylasiliyor. Tuketiciler ' +
      'ayni Properties ornegini gorur, dolayisiyla hepsi ayni hedeflere haber ' +
      'verir. Zinciri her tuketicinin kendi Properties''ine tasiyin ya da her ' +
      'zincir konumu icin ayri bir RepositoryItem kullanin.',
      [Name, LFilled, LUsers]);
end;

{ TRadEditSlots }

constructor TRadEditSlots.Create(AMaster: TObject);
begin
  inherited Create;
  FMaster := AMaster;
end;

destructor TRadEditSlots.Destroy;
begin
  { Bildirici bizim urettigimiz bir BILESEN; birakmazsak hem sizar hem de yok
    edilmis bir sahip adina bildirim almaya devam eder. }
  FreeAndNil(FNotificator);
  inherited Destroy;
end;

function TRadEditSlots.GetNotificator: TcxFreeNotificator;
begin
  if FNotificator = nil then
  begin
    FNotificator := TcxFreeNotificator.Create(FMaster);
    FNotificator.OnFreeNotification := SlotFreeNotification;
  end;
  Result := FNotificator;
end;

procedure TRadEditSlots.SlotFreeNotification(Sender: TComponent);
var
  i: Integer;
begin
  { Zincirdeki bir editor/kolon yok edildi: isaretciyi BURADA nil'lemezsek ilk
    erisimde erisim ihlali olur. }
  for i := Low(FItems) to High(FItems) do
    if FItems[i] = Sender then
      FItems[i] := nil;
end;

function TRadEditSlots.Get(AIndex: Integer): TComponent;
begin
  Result := FItems[AIndex];
end;

function TRadEditSlots.Contains(AComponent: TComponent): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := Low(FItems) to High(FItems) do
    if FItems[i] = AComponent then
      Exit(True);
end;

procedure TRadEditSlots.Put(AIndex: Integer; const AValue: TComponent);
var
  LOld: TComponent;
begin
  LOld := FItems[AIndex];
  if LOld = AValue then
    Exit;
  FItems[AIndex] := AValue;

  (* RemoveSender REFERANS SAYMAZ - dogrudan ASender.RemoveFreeNotification(Self)
     cagirir (dxCoreClasses.pas, TcxFreeNotificator.RemoveSender). Ayni bilesen
     baska bir yuvada da duruyorsa bildirimi kaldirmak O yuvayi sessizce
     sarkitir: hedef yok edilir, digerinin isaretcisi nil'lenmez, ilk erisimde
     erisim ihlali. Bu yuzden once kalan yuvalara bakiyoruz.
     AddSender tekrarli cagrilabilir - TComponent.FreeNotification zaten
     kayitli bir dinleyiciyi ikinci kez eklemez. *)
  if (LOld <> nil) and not Contains(LOld) then
    GetNotificator.RemoveSender(LOld);
  if AValue <> nil then
    GetNotificator.AddSender(AValue);
end;

function TRadEditSlots.FilledCount: Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := Low(FItems) to High(FItems) do
    if FItems[i] <> nil then
      Inc(Result);
end;

procedure TRadEditSlots.ForEach(const ACallback: TRadSlotNotify; const AValue: Variant);
var
  i: Integer;
begin
  for i := Low(FItems) to High(FItems) do
    if FItems[i] <> nil then
      ACallback(FItems[i], AValue);
end;

procedure TRadEditSlots.Assign(ASource: TRadEditSlots);
var
  i: Integer;
begin
  if ASource = nil then
    Exit;
  for i := Low(FItems) to High(FItems) do
    Put(i, ASource.Get(i));
end;

{ TcxEditRepositoryComboBoxDBItem }

class function TRadComboBoxRepository.GetEditPropertiesClass: TcxCustomEditPropertiesClass;
begin
  Result:=TRadComboBoxProperties;
end;

{ TRadComboBoxProperties }

constructor TRadComboBoxProperties.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner);
  FSlots := TRadEditSlots.Create(Self);
end;

destructor TRadComboBoxProperties.Destroy;
begin
  FreeAndNil(FSlots);
  inherited Destroy;
end;

function TRadComboBoxProperties.GetSlot(AIndex: Integer): TComponent;
begin
  Result := FSlots.Get(AIndex);
end;

procedure TRadComboBoxProperties.SetSlot(AIndex: Integer; const AValue: TComponent);
begin
  FSlots.Put(AIndex, AValue);
end;

procedure TRadComboBoxProperties.DoAssign(AProperties: TcxCustomEditProperties);
var
  LSrc: TRadComboBoxProperties;
begin
  inherited DoAssign(AProperties);
  if not (AProperties is TRadComboBoxProperties) then
    Exit;
  LSrc := TRadComboBoxProperties(AProperties);
  FStr := LSrc.FStr;
  FInt := LSrc.FInt;
  FSlots.Assign(LSrc.FSlots);
  FCascadeEvent := LSrc.FCascadeEvent;
end;

function TRadComboBoxProperties.ChainSlotCount: Integer;
begin
  Result := FSlots.FilledCount;
end;

class function TRadComboBoxProperties.GetContainerClass: TcxContainerClass;
begin
  Result := TRadComboBox;
end;

procedure TRadComboBoxProperties.CascadeOne(ATarget: TComponent; const AValue: Variant);
begin
  FCascadeEvent(Self, FCascadeSource, ATarget, AValue);
end;

procedure TRadComboBoxProperties.DoCascade(ASource: TComponent; const AValue: Variant);
begin
  { Tekrar-giris korumasi: bkz. TRadLookupComboBoxProperties.DoCascade. }
  if FCascading or not Assigned(FCascadeEvent) then
    Exit;
  FCascading := True;
  FCascadeSource := ASource;
  try
    FSlots.ForEach(CascadeOne, AValue);
  finally
    FCascadeSource := nil;
    FCascading := False;
  end;
end;

{ TRadComboBox }

function TRadComboBox.GetActiveProperties: TRadComboBoxProperties;
begin
  Result := TRadComboBoxProperties(InternalGetActiveProperties);
end;

function TRadComboBox.GetProperties: TRadComboBoxProperties;
begin
  Result := TRadComboBoxProperties(inherited Properties);
end;

class function TRadComboBox.GetPropertiesClass: TcxCustomEditPropertiesClass;
begin
  Result := TRadComboBoxProperties;
end;

procedure TRadComboBox.SetProperties(Value: TRadComboBoxProperties);
begin
  Properties.Assign(Value);
end;

procedure TRadComboBox.DoEditValueChanged;
begin
  inherited DoEditValueChanged;
  { Durum korumasi: bkz. TRadCustomLookupComboBox.DoEditValueChanged. }
  if [csLoading, csDestroying, csDesigning] * ComponentState <> [] then
    Exit;
  ActiveProperties.DoCascade(Self, EditValue);
end;

function TRadComboBoxRepository.GetProperties: TRadComboBoxProperties;
begin
  Result := inherited Properties as TRadComboBoxProperties;
end;

procedure TRadComboBoxRepository.SetProperties( Value: TRadComboBoxProperties);
begin
  inherited Properties := Value;
end;

{ TAkComboBoxDBProperties }
  {
    procedure TAkComboBoxDBProperties.DoAssign(AProperties: TcxCustomEditProperties);
    begin
      inherited DoAssign(AProperties);
      FOldOnInitPopup:=Self.OnInitPopup;
      OnInitPopup:=DoInitPopup;

      if AProperties is TcxCustomDropDownEditProperties then
        with TcxCustomDropDownEditProperties(AProperties) do
          Self.OnPopup := OnPopup;

    end;
    procedure TAkComboBoxDBProperties.DoInitPopup(Sender: TObject);
    begin
       if Assigned(FOldOnInitPopup) then FOldOnInitPopup(Sender);
    end;
  }
{ TAkComboBoxDBProperties }








{ TRadDBComboBox }

function TRadDBComboBox.GetActiveProperties: TRadComboBoxProperties;
begin
  Result := TRadComboBoxProperties(InternalGetActiveProperties);
end;

function TRadDBComboBox.GetProperties: TRadComboBoxProperties;
begin
  Result := TRadComboBoxProperties(inherited Properties);
end;

class function TRadDBComboBox.GetPropertiesClass: TcxCustomEditPropertiesClass;
begin
  Result := TRadComboBoxProperties;
end;

procedure TRadDBComboBox.SetProperties(Value: TRadComboBoxProperties);
begin
   Properties.Assign(Value);
end;

procedure TRadDBComboBox.DoEditValueChanged;
begin
  inherited DoEditValueChanged;
  { Durum korumasi: bkz. TRadCustomLookupComboBox.DoEditValueChanged. }
  if [csLoading, csDestroying, csDesigning] * ComponentState <> [] then
    Exit;
  ActiveProperties.DoCascade(Self, EditValue);
end;



{ TRadLookupComboBoxRepository }

class function TRadLookupComboBoxRepository.GetEditPropertiesClass: TcxCustomEditPropertiesClass;
begin
    Result := TRadLookupComboBoxProperties;
end;

function TRadLookupComboBoxRepository.GetProperties: TRadLookupComboBoxProperties;
begin
   Result := inherited Properties as TRadLookupComboBoxProperties;
end;

procedure TRadLookupComboBoxRepository.SetProperties(Value: TRadLookupComboBoxProperties);
begin
  inherited Properties := Value;
end;

{ TRadLookupComboBox }

function TRadCustomLookupComboBox.GetActiveProperties: TRadLookupComboBoxProperties;
begin
    Result := TRadLookupComboBoxProperties(InternalGetActiveProperties);
end;

function TRadCustomLookupComboBox.GetProperties: TRadLookupComboBoxProperties;
begin
  Result := inherited Properties as TRadLookupComboBoxProperties;
end;

class function TRadCustomLookupComboBox.GetPropertiesClass: TcxCustomEditPropertiesClass;
begin
 Result := TRadLookupComboBoxProperties;
end;

procedure TRadCustomLookupComboBox.SetProperties( Value: TRadLookupComboBoxProperties);
begin
    Properties.Assign(Value);
end;

destructor TRadCustomLookupComboBox.Destroy;
begin
  FreeAndNil(FSearchTimer);
  inherited Destroy;
end;

procedure TRadCustomLookupComboBox.RestartSearchTimer;
var
  LDelay: Cardinal;
begin
  LDelay := ActiveProperties.SearchDelay;
  if LDelay = 0 then
    Exit;
  if FSearchTimer = nil then
  begin
    FSearchTimer := TTimer.Create(Self);
    FSearchTimer.Enabled := False;
    FSearchTimer.OnTimer := SearchTimerTick;
  end;
  { Enabled'i once kapatmak sayaci SIFIRLAR - "tuslar durdu" anini boyle
    yakaliyoruz; sadece Interval yazmak sayaci baslatmaz. }
  FSearchTimer.Enabled := False;
  FSearchTimer.Interval := LDelay;
  FSearchTimer.Enabled := True;
end;

procedure TRadCustomLookupComboBox.SearchTimerTick(Sender: TObject);
begin
  FSearchTimer.Enabled := False;
  if [csLoading, csDestroying, csDesigning] * ComponentState <> [] then
    Exit;
  ActiveProperties.TimedSearch(EditingText);
end;

procedure TRadCustomLookupComboBox.DoEditKeyPress(var Key: Char);
begin
  inherited DoEditKeyPress(Key);
  RestartSearchTimer;
end;

procedure TRadCustomLookupComboBox.DoEditKeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited DoEditKeyDown(Key, Shift);
  { Silme tuslari DoEditKeyPress uretmez ama metni degistirir. }
  if (Key = VK_DELETE) or (Key = VK_BACK) then
    RestartSearchTimer;
end;

procedure TRadCustomLookupComboBox.CascadeNow;
begin
  if csDestroying in ComponentState then
    Exit;
  ActiveProperties.DoCascade(Self, EditValue);
end;

procedure TRadCustomLookupComboBox.DoEditValueChanged;
begin
  inherited DoEditValueChanged;
  { DFM yuklenirken, yok edilirken ve TASARIM zamaninda zincir tetiklenmez:
    yukleme sirasinda her ozellik atamasi bir sorgu acardi, tasarim zamaninda
    ise hedefi yeniden yuklemek anlamsiz - ve IDE icinde sorgu calistirir. }
  if [csLoading, csDestroying, csDesigning] * ComponentState <> [] then
    Exit;
  { ActiveProperties: repository uzerinden paylasilan Properties kullaniliyorsa
    dogru ornek odur, Properties degil. }
  ActiveProperties.DoCascade(Self, EditValue);
end;

{ TRadDBLookupComboBox }

procedure TRadDBLookupComboBox.CMGetDataLink(var Message: TMessage);
begin
  Message.Result := LRESULT(GetcxDBEditDataLink(Self));
end;

function TRadDBLookupComboBox.GetDataBinding: TcxDBTextEditDataBinding;
begin
   Result := TcxDBTextEditDataBinding(FDataBinding);
end;

class function TRadDBLookupComboBox.GetDataBindingClass: TcxEditDataBindingClass;
begin
  Result := TcxDBLookupEditDataBinding;
end;

procedure TRadDBLookupComboBox.SetDataBinding(Value: TcxDBTextEditDataBinding);
begin
  FDataBinding.Assign(Value);
end;


{ TRadLookupComboBoxProperties }

constructor TRadLookupComboBoxProperties.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner);
  FSlots := TRadEditSlots.Create(Self);
end;

destructor TRadLookupComboBoxProperties.Destroy;
begin
  FreeAndNil(FSlots);
  inherited Destroy;
end;

function TRadLookupComboBoxProperties.GetSlot(AIndex: Integer): TComponent;
begin
  Result := FSlots.Get(AIndex);
end;

procedure TRadLookupComboBoxProperties.SetSlot(AIndex: Integer; const AValue: TComponent);
begin
  FSlots.Put(AIndex, AValue);
end;

class function TRadLookupComboBoxProperties.TargetProperties(
  ATarget: TComponent): TRadLookupComboBoxProperties;
var
  LProps: TcxCustomEditProperties;
begin
  Result := nil;
  if ATarget = nil then
    Exit;

  (* Hedef ya bizim editorumuz ya da bir grid kolonu olabilir.

     KOLONDA published Properties DEGIL, public GetProperties kullanilir:
     kolon bir RepositoryItem'a baglandiginda published Properties NIL kalir
     (olculdu) - .Properties ile bakan kod hedefi sessizce atlar. GetProperties
     her iki durumda da ETKIN ornegi dondurur. *)
  if ATarget is TRadCustomLookupComboBox then
    LProps := TRadCustomLookupComboBox(ATarget).ActiveProperties
  else if ATarget is TcxCustomGridTableItem then
    LProps := TcxCustomGridTableItem(ATarget).GetProperties
  else
    LProps := nil;

  if LProps is TRadLookupComboBoxProperties then
    Result := TRadLookupComboBoxProperties(LProps);
end;

procedure TRadLookupComboBoxProperties.CascadeOne(ATarget: TComponent;
  const AValue: Variant);
var
  LTarget: TRadLookupComboBoxProperties;
begin
  (* Hedefin listesi birazdan yeniden filtrelenecek, yani onun cozulmus-anahtar
     onbellegi ARTIK GECERSIZ. Temizlemezsek bastirilmis bir OnLocate yuzunden
     hedef, yeni listede bulunmayan eski bir anahtar icin bos metin gosterir.
     Hedef bizim ailemizden degilse yapacak bir sey yok. *)
  LTarget := TargetProperties(ATarget);
  if LTarget <> nil then
    LTarget.ResetLocateCache;

  if FClearTargets then
    ClearTarget(ATarget);

  FCascadeEvent(Self, FCascadeSource, ATarget, AValue);
end;

procedure TRadLookupComboBoxProperties.ClearTarget(ATarget: TComponent);
begin
  (* Yalnizca editor hedefleri. Grid KOLONUNUN degeri satira gore degisir;
     kolon duzeyinde "temizlemek" tum sutunu bozmak olurdu. *)
  if ATarget is TcxCustomEdit then
    TcxCustomEdit(ATarget).EditValue := Null;
end;

procedure TRadLookupComboBoxProperties.ResetLocateCache;
begin
  FHasLastKey := False;
  FLastKey := Unassigned;
  FHasText := False;
  FTextKey := Unassigned;
  FLastText := '';
end;

procedure TRadLookupComboBoxProperties.TimedSearch(const AText: string);
var
  LText, LTail: string;
begin
  LText := AText;
  LTail := '';
  DoSearch(LText, LTail, False);
  { Liste yenilendi; yazilan metni yeni listede bulmayi deniyoruz. }
  if LText <> '' then
    FindLookupText(LText);
end;

function TRadLookupComboBoxProperties.ChainSlotCount: Integer;
begin
  Result := FSlots.FilledCount;
end;

procedure TRadLookupComboBoxProperties.SetLookupCode(const AValue: string);
var
  LDef: TRadLookupDef;
begin
  FLookupCode := Trim(AValue);
  FLookupDef := nil;
  if FLookupCode = '' then
    Exit;

  (* Kayit defteri bos olabilir: tasarim zamani, ya da uygulama henuz
     LoadFromDataSet cagirmadi. Bu bir HATA DEGIL - kod saklanir, tanim
     sonra cozulur. Burada istisna atmak, DFM yuklenirken formu acilamaz
     hale getirirdi. *)
  LDef := LookupRegistry.Find(FLookupCode);
  if LDef = nil then
    Exit;

  FLookupDef := LDef;

  { Tanimdan gelenler. Bos alanlar mevcut degeri EZMEZ. }
  if LDef.KeyField <> '' then
    KeyFieldNames := LDef.KeyField;
  if LDef.ListField <> '' then
    ListFieldNames := LDef.ListField;
  MinSearchLength := LDef.MinSearchLength;
  SearchDelay := LDef.SearchDelay;
  { Ust parametrenin adi zincir yukudur - OnCascade isleyicisi bunu okur. }
  if LDef.ParentParam <> '' then
    CascadeField := LDef.ParentParam;
end;

function TRadLookupComboBoxProperties.ListDataSet: TDataSet;
begin
  Result := nil;
  if (ListSource <> nil) then
    Result := ListSource.DataSet;
end;

procedure TRadLookupComboBoxProperties.PrepareDisplayValue(
  const AEditValue: TcxEditValue; var DisplayValue: TcxEditValue;
  AEditFocused: Boolean);
begin
  (* En erken cikis: ayni anahtar zaten cozulduyse ne olay tetikliyoruz ne de
     listede arama yapiyoruz - dogrudan saklanan metni veriyoruz. Grid bir
     kolonu 50 satir boyarken tum cozumleme yolu bir kez calisir.

     Bayatlik: onbellek yalnizca ResetLocateCache ile bosalir - kaskad hedefi
     bilgilendirirken ve arama listeyi degistirdiginde. Liste bunlarin disinda
     bir yolla degisirse (uygulama dataset'i kendi kapatip acarsa) cagiran
     ResetLocateCache'i kendisi cagirmalidir. *)
  { Kisa devre yalnizca METIN onbellegi doluysa - olay bastirma bayragi
    tek basina metin oldugu anlamina GELMEZ. }
  if FHasText and VarSameValue(FTextKey, AEditValue) then
  begin
    DisplayValue := FLastText;
    Exit;
  end;

  inherited PrepareDisplayValue(AEditValue, DisplayValue, AEditFocused);

  (* Onbellek TAM OLARAK bu yolun urettigi degerle dolduruluyor: baska bir
     cozumleme yolunun (GetDisplayLookupText) degeri farkli bicimlendirilmis
     olabilir. *)
  FTextKey := AEditValue;
  FLastText := VarToStr(DisplayValue);
  FHasText := True;
end;

procedure TRadLookupComboBoxProperties.DoAssign(AProperties: TcxCustomEditProperties);
var
  LSrc: TRadLookupComboBoxProperties;
begin
  inherited DoAssign(AProperties);
  if not (AProperties is TRadLookupComboBoxProperties) then
    Exit;
  LSrc := TRadLookupComboBoxProperties(AProperties);
  FStr := LSrc.FStr;
  FInt := LSrc.FInt;
  FSearchDelay := LSrc.FSearchDelay;
  FMinSearchLength := LSrc.FMinSearchLength;
  FClearTargets := LSrc.FClearTargets;
  FLookupCode := LSrc.FLookupCode;
  FLookupDef := LSrc.FLookupDef;
  FSlots.Assign(LSrc.FSlots);
  FSearchEvent := LSrc.FSearchEvent;
  FLocateEvent := LSrc.FLocateEvent;
  FCascadeEvent := LSrc.FCascadeEvent;
  { Kopya, kaynagin cozdugu anahtari devralmaz. }
  ResetLocateCache;
end;

procedure TRadLookupComboBoxProperties.DoCascade(ASource: TComponent;
  const AValue: Variant);
begin
  if FCascading or not Assigned(FCascadeEvent) then
    Exit;
  FCascading := True;
  FCascadeSource := ASource;
  try
    FSlots.ForEach(CascadeOne, AValue);
  finally
    FCascadeSource := nil;
    FCascading := False;
  end;
end;

procedure TRadLookupComboBoxProperties.DoLocate(const AKey: Variant);
var
  LDS: TDataSet;
begin
  if not Assigned(FLocateEvent) then
    Exit;
  if VarToStr(AKey).IsEmpty then
    Exit;

  { CIZIM YOLU KORUMASI: GetDisplayLookupText her hucre boyamasinda cagrilir.
    Ayni anahtar ust uste gelirse olayi (yani muhtemelen bir sorguyu) tekrar
    tetiklemiyoruz. Gridde 50 satir = 50 sorgu farki. }
  if FHasLastKey and VarSameValue(FLastKey, AKey) then
    Exit;

  { Ayni liste sorgusunu paylasan baska bir editorun isleyicisinin ICINDEYSEK
    geri cekiliyoruz - yoksa ic ice sorgu ac/kapa. }
  LDS := ListDataSet;
  if TRadBusyDataSets.IsBusy(LDS) then
    Exit;

  (* Enter, try'in ICINDE degil hemen ONCESINDE olmali VE arasinda hicbir sey
     calismamali. Onceki halinde araya LockUpdate(True) giriyordu: o istisna
     atarsa Leave hic calismaz, dataset kalici olarak "mesgul" kalir ve o
     dataset'i kullanan HER editorun OnLocate'i sessizce olmez. *)
  TRadBusyDataSets.Enter(LDS);
  try
    { try..finally SART: olay isleyicisi istisna atarsa kilit acik kalir ve
      editor bir daha guncellenmez. }
    LockUpdate(True);
    try
      FLocateEvent(Self, AKey);
      FLastKey := AKey;
      FHasLastKey := True;
      { FLastText'i BURADA doldurmuyoruz - bkz. PrepareDisplayValue'daki not.
        Cagiran GetDisplayLookupText zaten cozumlemeyi kendisi yapiyor;
        burada bir kez daha yapmak cizim yolunda cift is demekti. }
    finally
      LockUpdate(False);
    end;
  finally
    TRadBusyDataSets.Leave(LDS);
  end;
end;

procedure TRadLookupComboBoxProperties.DoSearch(var AText, ATail: string; ANext: Boolean);
var
  LDS: TDataSet;
begin
  if not Assigned(FSearchEvent) then
    Exit;
  { Cok kisa metinle arama yapilmaz - bkz. MinSearchLength. Bos metin her
    zaman gecer: "hepsini goster" anlamina gelir ve listeyi sifirlar. }
  if (FMinSearchLength > 0) and (AText <> '') and
     (Length(AText) < FMinSearchLength) then
    Exit;

  LDS := ListDataSet;
  if TRadBusyDataSets.IsBusy(LDS) then
    Exit;

  { Enter/try eslesmesi icin bkz. DoLocate'teki not. }
  TRadBusyDataSets.Enter(LDS);
  try
    LockUpdate(True);
    try
      FSearchEvent(Self, AText, ATail, ANext);
    finally
      LockUpdate(False);
    end;
  finally
    TRadBusyDataSets.Leave(LDS);
  end;
  { Arama listeyi degistirmis olabilir - onbellekteki anahtar artik gecersiz. }
  ResetLocateCache;
end;

function TRadLookupComboBoxProperties.GetDisplayLookupText(const AKey: TcxEditValue): string;
begin
  DoLocate(AKey);
  Result := inherited GetDisplayLookupText(AKey);
end;

class function TRadLookupComboBoxProperties.GetContainerClass: TcxContainerClass;
begin
  { Gridde inplace editor BUNDAN uretilir. Taban stok TcxLookupComboBox
    donduruyor (cxDBLookupComboBox.pas:405); override etmezsek kaskad
    tetikleyicimiz gridde hic calismaz. }
  Result := TRadLookupComboBox;
end;

class function TRadLookupComboBoxProperties.GetLookupDataClass: TcxInterfacedPersistentClass;
begin
  Result := TRadLookupEditLookupData;
end;

{ TRadLookupEditLookupData }

function TRadLookupEditLookupData.Locate(var AText, ATail: string; ANext: Boolean): Boolean;
var
  LProps: TRadLookupComboBoxProperties;
begin
  LProps := TRadLookupComboBoxProperties(Self.Properties);
  { SearchDelay > 0 ise aramanin sahibi kontroldeki geciktiricidir; burada
    tetiklemek geciktirmeyi anlamsiz kilardi. }
  if LProps.SearchDelay = 0 then
    LProps.DoSearch(AText, ATail, ANext);
  Result := inherited Locate(AText, ATail, ANext);
end;

initialization
  GetRegisteredEditProperties.Register(TRadComboBoxProperties, 'Rad ComboBox|Defines a combo box editor');
  GetRegisteredEditProperties.Register(TRadLookupComboBoxProperties, 'Rad LookupComboBox|LookupComboBox AksaSoft');

  {$IFDEF DX_INITIALIZATION_LOGGING}TdxUnitSectionsLogger.InitializationStarted(dxThisUnitName, SysInit.HInstance);{$ENDIF}
  RegisterClasses([TRadLookupComboBoxRepository]);
  RegisterClasses([TRadComboBoxRepository]);
  {$IFDEF DX_INITIALIZATION_LOGGING}TdxUnitSectionsLogger.InitializationFinished(dxThisUnitName, SysInit.HInstance);{$ENDIF}



   //GetRegisteredEditProperties.Register(TAkComboBoxDBProperties, 'ComboBox Aksa|Defines a combo box editor');
   //FilterEditsController.Register(TAkComboBoxDBProperties, TAkComboBoxDBProperties);


finalization
   GetRegisteredEditProperties.UnRegister(TRadLookupComboBoxProperties);
   GetRegisteredEditProperties.UnRegister(TRadComboBoxProperties);

   //GetRegisteredEditProperties.UnRegister(TAkComboBoxDBProperties);
   //FilterEditsController.Unregister(TAkComboBoxDBProperties, TAkComboBoxDBProperties);

end.
