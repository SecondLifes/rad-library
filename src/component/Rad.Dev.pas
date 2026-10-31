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
                      TComponent'tir: cxGridCustomTableView.pas:3407).
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
    (RadSetting: Key/Tag/Master/Control1..4/DataBinding) her tuketicinin
    KENDI Properties'inde. Boylece tek bir item'i cok yerde, her yerde farkli
    bir sorguyla kullanabilirsiniz. Kaskad, tuketicinin KENDI RadSetting.Controls
    zincirini kullanir; o bossa item'inkini (eski davranis; RadSettingTest R18).

    ! Yere ozel yuku Items/ListSource gibi ANLAMI OLAN property'lere koymayin:
      Object Inspector'da gercek gorunur, DFM'e yazilir, ama editor onlari
      asla kullanmaz (kullandigi ActiveProperties'tir). CascadeField/CascadeTag
      tam bu is icindir.

    Tuketicinin kendi/etkin Properties'ine, degerine, Caption'ina, DataSet ve
    Field'ina bilesen tipinden bagimsiz erisim: help.Dev.pas'taki
    _OwnProperties / _ActiveProperties / _ValueOf / _CaptionOf / _DataSetOf /
    _FieldOf yordamlari.

  TARIF: TEK ITEM, TEK ISLEYICI, TUKETICI-BASINA TUR
    Bir ERP'de "marka", "musteri tipi", "birim" gibi onlarca liste ayni
    tablodan gelir; degisen yalnizca bir tur kodudur. Hepsini tek bir
    RepositoryItem ve tek bir isleyiciyle surebilirsiniz:

      // veri modulunde - ORTAK olan her sey burada
      riTanim.Properties.OnSearch := DM.TanimAra;

      // formlarda - her tuketici KENDI turunu soyler
      cbMarka.RepositoryItem := riTanim;
      cbMarka.Properties.CascadeField := 'marka';
      cbTip.RepositoryItem := riTanim;
      cbTip.Properties.CascadeField := 'musteri_tipi';

      procedure TDM.TanimAra(Sender: TRadLookupComboBoxProperties;
        ASource: TComponent; var AText, ATail: string; ANext: Boolean);
      var
        LOwn: TcxCustomEditProperties;
      begin
        if ASource = nil then Exit;
        LOwn := _OwnProperties(ASource);            // help.Dev
        if not (LOwn is TRadLookupComboBoxProperties) then Exit;

        Q.Close;
        Q.SQL.Text := 'select id, deger from tanimlar ' +
                      'where tur = :tur and deger ilike :ara';
        Q.ParamByName('tur').AsString :=
          TRadLookupComboBoxProperties(LOwn).CascadeField;
        Q.ParamByName('ara').AsString := '%' + AText + '%';
        Q.Open;
      end;

    IKI TUZAK - ikisi de olculdu, ikisi de sessiz:

    1) Turu SENDER'dan OKUMAYIN. Sender PAYLASILAN ornektir; bir item'a bagli
       her tuketici icin AYNI degeri verir. Yukaridaki kod calisir, ama
       CascadeField'i Sender'dan okusaydiniz her combo ayni turu sorardi ve
       hicbir hata almadan yanlis liste gosterirdi.

    2) GRID KOLONUNDA kolonun kendi Properties'i ancak PropertiesClass (DFM'de
       PropertiesClassName) atanmissa OLUSUR; atanmamissa _OwnProperties nil
       doner ve yukaridaki isleyici sessizce Exit eder. Kolonlarda yere ozel
       yuk kullanacaksaniz PropertiesClass'i atamayi unutmayin.

  COMBO: TEK OLAYLA, GEREKTIGINDE DOLAN LISTE (TRadComboBox / TRadDBComboBox)
    Uc property ve tek olay:
      AEditorId     : liste kimligi ('ulke', 'sehir'); bilesen yorumlamaz.
      AMasterFields : listenin bagli oldugu KAYIT alanlari ('ulke;sehir').
      AOnFill       : uygulamadaki TEK doldurma yeri.

    Acilir liste acilirken bilesen AMasterFields alanlarini SORAN editorun
    kaydindan okur (formda editorun kendi kaydi, gridde satirin kaydi). Degerler
    son doldurmadakiyle ayniysa AOnFill CAGRILMAZ; farkliysa ayni adli
    parametrelerle cagrilir. AMasterFields bossa liste bir kez dolar. Tablo
    degisince: Properties.ResetItems.

      // veri modulunde - her repository item'a AYNI isleyici atanir
      procedure TDM.ListeDoldur(Sender: TRadComboBoxProperties;
        ASource: TComponent; AParams: TParams; AItems: TStrings);
      begin
        case IndexText(Sender.AEditorId, ['ulke', 'sehir']) of
          0: Q.SQL.Text := 'select ad from adr_ulke order by ad';
          1: Q.SQL.Text := 'select s.ad from adr_sehir s join adr_ulke u ' +
                           'on u.kod = s.ulke_kod where u.ad = :ulke order by s.ad';
        end;
        Q.Params.AssignValues(AParams);
        Q.Open;
        try
          AItems.Clear;
          while not Q.Eof do
          begin
            AItems.Add(Q.Fields[0].AsString);
            Q.Next;
          end;
        finally
          Q.Close;
        end;
      end;

    AItems = Sender.Items: repository atanmisken editorun KENDI Items'i hic
    kullanilmaz (olculdu). Sender repository'ninkidir; ASource soran editor.

    EDITOR BUTONU - bilesen hicbir sey eklemez. Repository'nin
    Properties.OnButtonClick'ini yazin: AButtonIndex Buttons koleksiyonundaki
    gercek indekstir; Sender editordur, TRadComboBoxProperties(
    TcxCustomEdit(Sender).ActiveProperties).AEditorId ile liste kimligini okuyun,
    editor kapaninca ResetItems cagirin.
    ! OnButtonClick'i YALNIZCA repository'ye yazin: editorun kendi Properties'ine
      de yazilirsa IKI kez gelir (cxEdit.pas:4897-4900).

  CHECK COMBO: DEGER TASIYAN ITEM'LAR, OLAY YAZMADAN (TRadCheckComboBox /
  TRadDBCheckComboBox)
    Stok TcxCheckComboBox'ta bir item'in "degeri" yoktur; EditValue ya bit
    maskesi ya da uzunluk-onekli caption kodlamasidir (cxCheckBox.pas:633) ve
    filtre SQL'ine uymaz. Deger istemek her formda OnStatesToEditValue /
    OnEditValueToStates yazmak demekti.

      Items           : TRadCheckComboBoxItems - her item'da Description + VALUE
                        ('Aktif' / 't'). Tasarimcida tek koleksiyon, DFM'e yazilir.
                        Tabanin kendi Items'i gizlidir; bizimki ona AYNALANIR
                        (indeks bazli, tek yon). Value bossa deger = Description.
                        Hicbir item'da Value yoksa stok davranis.
                        Kod: Items.AddItem('Aktif', 't'), Items.IndexOfValue('t').
      EditValue       : secili degerler AValueDelimiter (;) ile: 't;f'.
      AValues         : editorde dizi olarak al / geri yukle: cb.AValues := ['A','AS'].
                        DB editorde atama kaydi DUZENLEME moduna alir; alana
                        yazma PostEditValue ile ya da odak cikinca olur.
      AHasValues      : secim var mi.
      AValuesIn(alan) : "cari_tip in ('A','AS')"; bos secimde ''. Metin uretir;
                        parametre tercih ediyorsaniz AValues dizisini
                        '= any(:p)' ile gecirin.

    Dikis yeri olay DEGIL: CalculateCheckStatesByEditValue ve
    CalculateEditValueByCheckStates sanal (cxCheckComboBox.pas:246-249). Olaylari
    yine de atarsaniz OLAY KAZANIR ve deger kipi sessizce devre disi kalir
    (RadChainAudit bunu bildirir). Hicbir item'da Value yoksa stok davranis aynen surer.
    SINIR: gridin FILTRE SATIRI kendi stok TcxCheckComboBox'unu yaratir
    (cxCheckComboBox.pas:1725-1757); oraya deger kipi gitmez.

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
unit rad.dev;

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
  ,cxCheckBox,cxCheckComboBox,cxDBCheckComboBox  { TRadCheckComboBox ailesi }
  ,cxButtonEdit,cxImageComboBox,cxDBExtLookupComboBox
  ,cxCheckListBox,cxDBCheckListBox,cxDB
  ,System.Types  { TList.Remove satir ici acilimi icin - H2443 }
  ,Vcl.ExtCtrls; { SearchDelay geciktiricisinin TTimer'i }

(* ==========================================================================
   BILESENIN BEKLEDIGI SORGU SEKLI

   Bir ERP lookup'i BUTUN tabloyu cekmez. Beklenen sekil sunucu tarafli,
   SINIRLI ve iki parametreli tek bir sorgudur:

     select id, ad from sehir
      where ulke_id = :ulke_id       { master suzgeci - AMasterField }
        and ad ilike :arama          { artimli arama - AOnSearch'un isi }
      order by ad
      limit 15                       { SATIR SINIRI: UYGULAMANIN ISI }

   -- SATIR SINIRINI BILESEN KOYMAZ --------------------------------------
   limit / top / rownum sozdizimi veritabanina gore degisir ve dogru sayi
   ekrana gore degisir; bileseni SQL uretmeye yaklastirmamak icin bu tamamen
   uygulamada birakildi.

   ! UniDAC'in TCustomDADataSet.FetchRows'u (varsayilan 25) BU ISI YAPMAZ.
     O yalnizca bir gidis-donuste kac satir tasinacagini soyler; sorgu yine
     butun sonuc kumesini uretir ve non-GridMode bir lookup acilir listeyi
     doldururken hepsini yurur. Gercek sinir SQL'dedir (ya da GridMode).

   -- IKI MEKANIZMA, TEK SORGU -------------------------------------------
   AAutoFilter = afServerParam master parametresini kurar; AOnSearch arama
   parametresini kurar ve dataset'i YENIDEN ACAR. Acilir liste her acildiginda
   bileseni sunlari yapar:

     1. master parametresini kurar (dataset'i ACMADAN),
     2. AOnFilter varsa cagirir,
     3. aramayi BOS metinle bir kez cagirir -> tek Close/Open ORADA olur.

   Ucuncu adim ayni zamanda ARAMA METNINI SIFIRLAR: "ank" yazip sonra ulkeyi
   degistiren bir kullanici, Almanya listesini "ank" ile suzulmus ve bos
   gormemelidir.

   ! SQL.Text'i BASTAN ATAYAN bir isleyici master parametresini YOK EDER.
     Parametre degerleri Close/Open boyunca korunur (UniDAC), ama SQL metni
     degisince koleksiyon yeniden kurulur ve yeni metinde bulunmayan
     parametre gider. Isleyiciler parametre atamali, SQL degistirmemelidir.

   -- AOnLocate NEDEN SART ------------------------------------------------
   Liste master'a gore suzuldugu icin, kayitli anahtar suzulmus listede
   BULUNMAYABILIR. O durumda taban sinif bos metin uretir
   (cxDBLookupEdit.pas:626-632) ve GridMode = True bunu COZMEZ: oradaki
   Locate ayni suzulmus dataset'e bakar ve bos cevabi onbellege yapistirir.
   Tek cozum AOnLocate'tir - uygulama o tek anahtarin satirini sunucudan
   ceker.

   -- afClientFilter NE ZAMAN ---------------------------------------------
   Yalnizca TAMAMI BELLEKTE DURAN kucuk listeler icin (doviz, birim, KDV
   orani): bir kez cekilir, master degistikce aga hic gidilmez. Buyuk
   listelerde yanlis secim, calisan ama gitgide yavaslayan bir ekran demek -
   PullWarning bunu CIstemciFiltreUyariEsigi satirini asinca bildirir.
   Bu kipte SQL suzgecsiz olmali ve AMasterField dataset'te GERCEKTEN VAR
   OLAN bir alan olmalidir.
   ========================================================================== *)

type
  {*
  1: Properties Oluştur;
  2: RepositoryItem Oluştur
  3: Component Oluştur

  *}

  {$REGION 'TRadLookupComboBoxProperties'}

  /// <summary>Rad.Dev yapilandirma hatalari.</summary>
  ERadDev = class(Exception);

const
  (* afClientFilter uyari esigi. OLCUM DEGIL, KARAR: doviz/birim/KDV gibi
     gercekten kucuk listeler rahatlikla altinda kalir; sehir/cari/stok gibi
     yanlis kullanimlar hizla ustune cikar. Yanlis alarm riski dusuk tutuldu. *)
  CIstemciFiltreUyariEsigi = 200;

type

  (* PULL'un OTOMATIK kipi: basit "alan = master'in degeri" durumunda
     AOnFilter yazmadan filtreyi bilesenin kendisi uygular.

     ! DEGERLERE ACIK SAYI ATANMAZ. Kitin delphi-conventions kuralinda
       olculmus davranis: acik deger atanmis bir enum HIC RTTI uretmez ve
       published property'si Object Inspector'da SESSIZCE gorunmez. *)
  TRadAutoFilter = (
    /// Otomatik filtre yok; yalnizca AOnFilter calisir (varsayilan).
    afNone,
    /// Liste dataset'inin AMasterField adli PARAMETRESI atanir ve dataset
    /// yeniden acilir. Sunucu tarafli suzme; UniDAC (TCustomDADataSet) ister.
    afServerParam,
    /// TDataSet.Filter ifadesi kurulur (AMasterField = deger). Saticidan
    /// bagimsiz, ama suzme ISTEMCI tarafindadir - butun satirlar cekilir.
    afClientFilter);

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
     cozuyor (TcxCustomEditProperties.GetFreeNotificator, cxEdit.pas:1375) ama
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
    procedure CheckIndex(AIndex: Integer);
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

  (* Bagimsiz veri baglantisi: bir DataSource + alan adi. Editorun kendi
     DataBinding'inden TAMAMEN ayridir. v1: yalnizca okuma; degisim olayi
     TODO.md RAD-06'da. TDataLink DataSource yok edilince kendiliginden kopar. *)
  TcxRadDataBinding = class(TcxInterfacedPersistent)
  private
    FDataField: string;
    FLink: TDataLink;
    function GetDataSource: TDataSource;
    function GetField: TField;
    function GetValue: Variant;
    procedure SetDataSource(const AValue: TDataSource);
  public
    constructor Create(AOwner: TPersistent); override;
    destructor Destroy; override;
    procedure Assign(ASource: TPersistent); override;
    /// <summary>Dataset acik ve alan bulunuyor mu.</summary>
    function IsAvailable: Boolean;
    property Field: TField read GetField;
    /// <summary>Alanin degeri; kullanilamiyorsa Null.</summary>
    property Value: Variant read GetValue;
  published
    property DataSource: TDataSource read GetDataSource write SetDataSource;
    property DataField: string read FDataField write FDataField;
  end;

  (* Tuketiciye ozel genel ayar kumesi (DevExpress'in Automation'i gibi):
     Properties tasir, DoAssign'la kopyalanir. Yere ozel yuk repository'de degil,
     tuketicinin KENDI Properties'indeki bu nesnede durur.
       Key     : serbest metin (liste/sorgu/alan kimligi, ...); bilesen yorumlamaz.
       Tag     : serbest tamsayi yuku.
       Master  : bu tuketicinin bagli oldugu editor/kolon (pull yonu).
       Control1..4: haber verilecek hedefler (push yonu, bildirimsiz referanslar).
       DataBinding: bagimsiz veri alani.
       Data    : yalnizca calisma zamani, DFM'e yazilmaz, kopyalanmaz. *)
  TcxRadSetting = class(TcxInterfacedPersistent)
  private
    FKey: string;
    FTag: Integer;
    FData: TObject;
    FControls: TRadEditSlots;
    FMasterHolder: TRadEditSlots;
    FDataBinding: TcxRadDataBinding;
    FIdx: Integer;
    function GetControl(AIndex: Integer): TComponent;
    function GetMaster: TComponent;
    procedure SetControl(AIndex: Integer; const AValue: TComponent);
    procedure SetDataBinding(const AValue: TcxRadDataBinding);
    procedure SetMaster(const AValue: TComponent);
  public
    constructor Create(AOwner: TPersistent); override;
    destructor Destroy; override;
    procedure Assign(ASource: TPersistent); override;
    /// <summary>Push hedef yuvalari (Control1..4); sahibi bu nesnedir.</summary>
    property Controls: TRadEditSlots read FControls;
    /// <summary>Master'in AYRI tutucusu: push hedefleriyle karismasin diye.</summary>
    property MasterHolder: TRadEditSlots read FMasterHolder;
    property Data: TObject read FData write FData;
  published
    property Key: string read FKey write FKey;
    property Tag: Integer read FTag write FTag default 0;
    property Idx: Integer read FIdx write FIdx default 0;
    property Master: TComponent read GetMaster write SetMaster;
    property Control1: TComponent index 1 read GetControl write SetControl;
    property Control2: TComponent index 2 read GetControl write SetControl;
    property Control3: TComponent index 3 read GetControl write SetControl;
    property Control4: TComponent index 4 read GetControl write SetControl;
    property DataBinding: TcxRadDataBinding read FDataBinding write SetDataBinding;
  end;

  (* ADI BILINCLI OLARAK FARKLI: eskiden DevExpress'in sinifiyla BIREBIR ayni
     adi tasiyordu (cxDBLookupEdit.TcxCustomDBLookupEditLookupData). Iki birimi
     birden uses'a alan bir cagirici icin hangi tipin geldigi uses SIRASINA
     bagli oluyor ve derleyici hicbir sey soylemiyordu. *)
  TRadLookupEditLookupData = class(cxDBLookupEdit.TcxCustomDBLookupEditLookupData)
   protected
    function Locate(var AText, ATail: string; ANext: Boolean): Boolean; override;
  end;
    (* ASource NEDEN VAR - kaskad olayindakiyle AYNI gerekce:
       Sender, PAYLASILAN Properties ornegidir. Bir RepositoryItem'a bagli tum
       tuketiciler onu paylasir (olculdu), dolayisiyla Sender'a bakarak "su an
       hangi editor soruyor" sorusu CEVAPLANAMAZ.

       Yere ozel yuku (hangi tanim turu, hangi filtre) ASource'un KENDI
       Properties'inden okuyun: help.Dev'deki _OwnProperties(ASource).

       ! ASource nil OLABILIR. OnLocate cizim yolundan da tetiklenir
         (GetDisplayLookupText -> DoLocate) ve orada bir kaynak YOKTUR: cizim
         makinesi paylasilan Properties uzerinde calisir. Uydurma bir deger
         gecmek yerine nil geciyoruz - isleyici bunu kontrol etmelidir. *)
    TRadLookupSearchEvent  = procedure (Sender:TRadLookupComboBoxProperties;
      ASource: TComponent; var AText, ATail: string; ANext: Boolean) of object;
    TRadLookupLocateEvent  = procedure (Sender:TRadLookupComboBoxProperties;
      ASource: TComponent; const AKey: Variant) of object;
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

    (* PULL yonu - kaskadin TERSI ve artik TERCIH EDILEN yon.

       Bu editorun acilir listesi ACILMADAN HEMEN ONCE, kendi MASTER'inin o
       anki degeriyle bir kez tetiklenir. Filtreyi/SQL'i uygulamak yine
       UYGULAMANIN isidir; bilesen yalnizca "kim soruyor / kimin degeri /
       hangi deger" ucgenini tasir.

       NEDEN PUSH DEGIL: bagimli olan, neye bagli oldugunu bilir - yabanci
       anahtar gibi. Yeni bir bagimli editor eklemek icin KAYNAGI duzenlemek
       gerekmez ve dort yuva siniri yoktur. Ayrica sorgu, liste GERCEKTEN
       acilinca kosar: ulke->sehir->ilce->mahalle zincirinde push, kimsenin
       bakmadigi uc sorgu calistiriyordu.

       PUSH YINE DE DURUYOR, ama artik yalnizca GECERSIZ KILMA sinyali olarak
       (bkz. CascadeOne). Saf pull bayat degeri duzeltemez: master degisir,
       kullanici bagimlinin listesini HIC acmazsa hicbir sey "pull" edilmez ve
       tutarsiz anahtar kayda gider.

       ASource: soruyu SORAN tuketici - bu editorun kendisi. Gridde inplace
         EDITORDUR, kolon degil (AOnCascade/AOnSearch/AOnLocate ile AYNI
         sozlesme). Kolona ulasmak icin help.Dev'deki hazir yol:
         TcxCustomTextEdit(ASource)._Host.
       AMaster: AMaster property'sine atanmis bilesen - bir editor ya da bir
         grid KOLONU.
       AMasterValue: _ValueOf(AMaster). Kolonda ODAKLI kaydin degeridir;
         odakli kayit yoksa UNASSIGNED gelir - kolonun EditValue'su oyle
         doner (cxGridCustomTableView.pas:13724, 26.1.3; DxAuditTest G02).
         Detay seviyesi (pattern) kolonunda deger HIC okunamaz, hep
         Unassigned'dir (G01; PullWarning bunu bildirir). Null yalnizca
         _ValueOf'un tanimadigi bir turde gelir. Isleyici bu yuzden hem
         VarIsNull hem VarIsEmpty gozetmelidir.

       Sender NEDEN AYIRT ETMEZ: AOnCascade'dekiyle ayni gerekce - bir
       RepositoryItem'a bagli tum tuketiciler AYNI Properties ORNEGINI
       paylasir. Yere ozel yuk ASource'un KENDI Properties'inden okunur:
       help.Dev'deki _OwnProperties(ASource). *)
    TRadLookupFilterEvent = procedure (Sender:TRadLookupComboBoxProperties;
      ASource, AMaster: TComponent; const AMasterValue: Variant) of object;

    TRadLookupComboBoxProperties = class(TcxLookupComboBoxProperties)
    private
      FRadSetting: TcxRadSetting;
      { RadSetting'in tutuculari; SAHIBI RadSetting'tir, burada yalnizca kisayol. }
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
      (* A → B → A dongusune karsi. Zincirin bir halkasi, kendisini besleyen
         halkayi yeniden tetiklerse yigin tukenene kadar donerdi; ne derleyici
         ne test bunu yakalar. Bu kitte olculmus bir emsali var: geri besleme
         dongusu 30 saniyede 796.240 isleyici girisi (delphi-conventions.md). *)
      FCascading: Boolean;
      { Kaskad suresince degisikligi baslatan editor. Olay imzasina ek
        parametre koymak yerine alanda tutuluyor: ForEach geri cagirimi
        TRadSlotNotify imzasina bagli. }
      FCascadeSource: TComponent;
      { Kaskad suresince: degisiklik VERIDEN mi geldi (bkz. DoCascade). }
      FCascadeFromData: Boolean;
      (* PULL tarafi. FMasterSlot AYRI bir tutucudur, AComponent1..4'un
         yuvalarindan biri DEGIL: TRadEditSlots'un FilledCount/ForEach'i
         "push hedefleri" demektir ve master oraya konsaydi kaynak KENDI
         master'ina push yapardi (A->B->A dongusu), ChainSlotCount da
         pull-only bir editor icin dolu zincir bildirirdi. Ayri tutucu
         bedava degil ama BEDELSIZ: TcxFreeNotificator ORNEK BASINA yaratilir
         (GetNotificator) ve RemoveSender yalnizca KENDI bildiricisini siler
         (dxCoreClasses.pas, TcxFreeNotificator.RemoveSender), dolayisiyla iki
         tutucu birbirinin serbest-birakma kaydini bozamaz. *)
      FMasterSlot: TRadEditSlots;
      FFilterEvent: TRadLookupFilterEvent;
      FFilterOnPopup: Boolean;
      FEditOnPopup: Boolean;
      (* PULL icin AYRI bayrak - FCascading ile BIRLESTIRILEMEZ. Push ve pull
         ters yonlerdir: A'nin push'u B'yi temizler, B'nin acilan listesi pull
         yapar. Tek bayragi paylassalardi ikinci adim sessizce atlanirdi ve bu
         ozellikle paylasilan bir Properties ornegi uzerinde gorunmez olurdu. *)
      FFiltering: Boolean;
      (* DoFilter, liste dataset'i mesgulken SESSIZCE cikar - dogru davranis
         (ozyinelemeyi keser) ama sonucu gorunmez: kullanici SUZULMEMIS bir
         liste gorur ve bunun oldugunu hicbir sey soylemez. Sayac bunu
         PullWarning uzerinden gorunur kilar. *)
      FSkippedFilters: Integer;
      (* Arama ve locate yollari da mesgul dataset yuzunden atlanabiliyor ama
         eskiden bu SESSIZDI - yalnizca DoFilter sayiyordu. Atlanan bir arama,
         kullanicinin yazdigi metnin hic uygulanmamasi demek. *)
      FSkippedSearches: Integer;
      FMasterField: string;
      FAutoFilter: TRadAutoFilter;
      procedure ApplyAutoFilter(ADataSet: TDataSet; const AValue: Variant;
        AOpen: Boolean);
      function  CacheAllowed: Boolean;
      function  GetMaster: TComponent;
      procedure SetMaster(const AValue: TComponent);
      function  GetSlot(AIndex: Integer): TComponent;
      procedure SetSlot(AIndex: Integer; const AValue: TComponent);
      function  GetCascadeField: string;
      procedure SetCascadeField(const AValue: string);
      function  GetCascadeTag: Integer;
      procedure SetCascadeTag(const AValue: Integer);
      procedure SetRadSetting(const AValue: TcxRadSetting);
      procedure CascadeOne(ATarget: TComponent; const AValue: Variant);
      function  ListDataSet: TDataSet;
      procedure ClearTarget(ATarget: TComponent);
      procedure SetLocateEvent(const AValue: TRadLookupLocateEvent);
    protected
        class function GetLookupDataClass: TcxInterfacedPersistentClass; override;
        (* Ozel alanlarimizi KOPYALAMAK ZORUNDAYIZ. TcxCustomEditProperties.Assign
           dogrudan DoAssign'a gider ve taban kendi olaylarini orada tek tek
           kopyalar (cxEdit.pas). Override etmezsek "Editor.Properties := X"
           zincir baglarini, olaylari ve AAStr/AAInt yukunu SESSIZCE dusurur -
           derleyici de calisma zamani da hicbir sey soylemez. *)
        procedure DoAssign(AProperties: TcxCustomEditProperties); override;
        function GetDisplayLookupText(const AKey: TcxEditValue): string; override;
        procedure DoSearch(ASource: TComponent; var AText, ATail: string; ANext: Boolean);
        procedure DoLocate(ASource: TComponent; const AKey: Variant);
        (* Her Properties degisikliginde (ListSource, KeyFieldNames, AOnLocate
           ...) kitin metin/anahtar onbellegi bosaltilir - bkz. uygulamadaki not. *)
        procedure DoChanged; override;
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
      procedure TimedSearch(ASource: TComponent; const AText: string);
      constructor Create(AOwner: TPersistent); override;
      destructor Destroy; override;
      /// <summary>Bagli her zincir hedefi icin OnCascade'i tetikler.
      /// ASource degisikligi baslatan editordur.</summary>
      /// <remarks>AFromData = True: deger veriden geldi (kayitta gezinme).
      /// Gecersiz kilma (onbellek + AOnCascade) yine yapilir, ama
      /// AClearTargetsOnCascade hedefin degerini TEMIZLEMEZ.</remarks>
      procedure DoCascade(ASource: TComponent; const AValue: Variant;
        AFromData: Boolean = False; AChain: TRadEditSlots = nil);
      /// <summary>Cozulmus-anahtar onbellegini bosaltir (liste degistiyse).</summary>
      procedure ResetLocateCache;
      /// <summary>Dolu zincir yuvasi sayisi (ChainWarning icin).</summary>
      function ChainSlotCount: Integer;
      (* PUBLIC oldu: combo ailesi de hedefinin onbelleklerini gecersiz
         kilabilsin diye. Govdesi degismedi. *)
      class function TargetProperties(ATarget: TComponent): TRadLookupComboBoxProperties; static;
      /// <summary>PULL: master'in degerini okur ve AOnFilter'i BIR kez
      /// tetikler. ASource soruyu soran tuketicidir.</summary>
      procedure DoFilter(ASource: TComponent);
      /// <summary>DevExpress'in anahtar->metin onbellegini bosaltir
      /// (FLookupList; GridMode=True iken dolar).</summary>
      procedure ResetDisplayCache;
      /// <summary>Her iki katmani birden bosaltir: kitin cozulmus-anahtar
      /// onbellegi + DevExpress'in FLookupList'i.</summary>
      procedure ResetCaches;
      /// <summary>Master yuvasi dolu mu.</summary>
      function HasMaster: Boolean;
      /// <summary>Pull yapilandirmasindaki SESSIZ tuzaklar. Bos string =
      /// sorun yok. ChainWarning gibi bir SORGUDUR - kendiliginden uyari
      /// vermez, cunku DFM yuklenirken her yapilandirma bir an eksik
      /// gorunur.</summary>
      function PullWarning: string;
    published
      /// <summary>Tuketiciye ozel genel ayar kumesi (Key, Tag, Master, Control1..4, DataBinding).</summary>
      property RadSetting: TcxRadSetting read FRadSetting write SetRadSetting;
      { Eski ad: RadSetting'e yonlendirir, DFM'e YAZILMAZ ama eski DFM'ler okunur. }
      property AComponent1:TComponent index 1 read GetSlot write SetSlot stored False;
      property AComponent2:TComponent index 2 read GetSlot write SetSlot stored False;
      property AComponent3:TComponent index 3 read GetSlot write SetSlot stored False;
      property AComponent4:TComponent index 4 read GetSlot write SetSlot stored False;
      (* PULL: bu editor KIMIN degerine bagli. Doldurulunca acilir liste
         acilmadan once AOnFilter bu bilesenin degeriyle tetiklenir. Bir
         editor ya da bir grid KOLONU olabilir; kolonda ODAKLI kaydin degeri
         okunur.

         Serbest-birakma korumasi AComponent1..4 ile ayni desendendir, ama
         AYRI bir tutucudan gelir - gerekcesi FMasterSlot'un yaninda. *)
      property AMaster:TComponent read GetMaster write SetMaster stored False;
      (* PULL yonunun serbest yuku - ACascadeField'in karsiligi. Iki isi var:
           1. AOnFilter isleyicisine tasinir (bilesen yorumlamaz);
           2. AAutoFilter <> afNone iken KULLANILIR: suzulecek parametrenin
              ya da alanin adidir (ornegin 'ulke_id').
         Otomatik kip kapaliyken tamamen serbesttir. *)
      property AMasterField:string read FMasterField write FMasterField;
      /// <summary>Zincirde hedefe suzme icin gecirilecek alan adi
      /// (ornegin "ulke_id"). Bileseni ilgilendirmez; OnCascade isleyicisine
      /// tasinan serbest yuktur.</summary>
      property ACascadeField:string  read GetCascadeField write SetCascadeField stored False;
      /// <summary>Zincir icin serbest tamsayi yuku (seviye no, tur kodu, ...).</summary>
      property ACascadeTag:Integer read GetCascadeTag write SetCascadeTag stored False;
      property AOnSearch:TRadLookupSearchEvent read FSearchEvent write FSearchEvent;
      property AOnLocate:TRadLookupLocateEvent read FLocateEvent write SetLocateEvent;
      /// <summary>Tuslar durduktan sonra OnSearch'un tetiklenmesi icin
      /// beklenen sure (ms). 0 = geciktirme yok, OnSearch her tus vurusunda
      /// Locate seam'inden tetiklenir.</summary>
      /// <remarks>Sunucu tarafli aramada fark buyuk: "Istanbul" yazmak
      /// geciktirme kapaliyken 8 sorgu, acikken 1 sorgu eder.
      /// Varsayilan 500 ms. Constructor da 500 atar - default direktifi ile
      /// constructor AYNI olmak zorunda, yoksa deger ya sessizce kaybolur ya
      /// da gereksiz yere DFM'e yazilir.</remarks>
      property ASearchDelay:Cardinal read FSearchDelay write FSearchDelay default 500;

      (* Yazilan metin BU UZUNLUGA erisene kadar OnSearch hic tetiklenmez.
         Bos metin her zaman gecer - "hepsini goster" anlamina gelir, yani
         acilir listeyi acmak calismaya devam eder.

         VARSAYILAN 3 - bilincli bir karar. Buyuk listelerde (cari, stok) tek
         harflik arama tablonun buyuk bolumunu doner; 3 harf makul bir alt
         sinir.

         ! KISA KODLU LISTELERDE ELLE 0 VERIN. ERP'de kisa kodlar var:
             birim  kg, lt, m, ad      (1-2)
             doviz  TL                 (2)
             ulke   TR, DE             (2)
           Varsayilan 3 iken kullanici "TL" yazdiginda liste BOS gelir ve
           HICBIR uyari cikmaz - ne istisna, ne log. Belirti "arama calismiyor"
           olur, sebebi burasidir. Bu listelerde AMinSearchLength := 0 yapin.
           (Kullanicinin karari: bu tur listeler az, elle verilecek.) *)
      property AMinSearchLength:Integer read FMinSearchLength write FMinSearchLength default 3;
      (* True iken, bir hedefe OnCascade gonderilmeden ONCE hedefin degeri
         temizlenir. Klasik kaskad hatasini kapatir: ulke degisir, sehir
         listesi yenilenir, ama eski sehir DEGERI editorde kalir ve yeni
         listede olmayan bir anahtar gosterilir.

         Yalnizca TcxCustomEdit hedeflerinde islem yapar - bir grid KOLONUNUN
         "degeri" satira gore degisir, kolon duzeyinde temizlemek anlamsizdir.
         Varsayilan False: davranis degisikligi opt-in.

         DB EDITORDE KAYITTA GEZINME TEMIZLEMEZ: orada degisiklik veriden
         gelir ve hedef kendi degerini ayni kayittan alir (DbNavTest). DB
         formunda "ulke degisince sehri sil" kurali icin dogru yer yine de
         KAYIT alanidir (ulke_id alaninin TField.OnChange'i) - editor degeri
         temizlemek alani yazmaz. *)
      property AClearTargetsOnCascade:Boolean read FClearTargets write FClearTargets default False;
      property AOnCascade:TRadCascadeEvent read FCascadeEvent write FCascadeEvent;

      (* True iken acilir liste her acilisinda AOnFilter kendiliginden
         tetiklenir (TRadCustomLookupComboBox.DoInitPopup). False iken pull
         YALNIZCA FilterNow ile tetiklenir - listeyi kendi zamanlamasiyla
         suzmek isteyen uygulamalar icindir.
         Varsayilan True; constructor da True atar - default direktifi ile
         constructor AYNI olmak zorunda, yoksa deger ya sessizce kaybolur ya
         da gereksiz yere DFM'e yazilir. *)
      property AFilterOnPopup:Boolean read FFilterOnPopup write FFilterOnPopup default True;
      /// <summary>DB'ye bagli editorde acilir liste acilirken dataset'i duzenleme
      /// moduna alir (secim ilk harekette kaybolmaz). Varsayilan False.</summary>
      property AEditOnPopup:Boolean read FEditOnPopup write FEditOnPopup default False;
      (* Basit "alan = master'in degeri" durumunda AOnFilter yazmaktan kurtarir.
         AMasterField ZORUNLUDUR.

         SIRA: once otomatik filtre, SONRA AOnFilter. Isleyici hala calisir ve
         isterse uzerine yazar - otomatik kip onu bastirmaz, ona baslangic
         noktasi verir.

         MASTER BOSSA (Null/Unassigned/bos metin) liste dataset'i KAPATILIR:
         kaskadda ulke secilmeden sehir listelenmemelidir. Iki kip icin de
         ayni kural - ifade oyunu yok.

         SINIR: afClientFilter'in ifadesi tamsayi ve metin degerleri icin uretilir.
         Ondalik/tarih bir master anahtari icin AOnFilter yazin - yerel ondalik
         ayraci filtre ifadesini sessizce bozardi. *)
      property AAutoFilter:TRadAutoFilter read FAutoFilter write FAutoFilter default afNone;
      property AOnFilter:TRadLookupFilterEvent read FFilterEvent write FFilterEvent;

      property Buttons;
      property OnButtonClick;
      property Images;
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
      (* > 0 iken deger VERIDEN geliyor: DB binding'in DataChanged'i (kayitta
         gezinme, dataset'in tazelenmesi) EditValue'yu yeniden atiyor ve bu da
         DoEditValueChanged'e iniyor (cxDBEdit.pas:2279 -> cxEdit.pas:5706).
         Kaskad bu durumda hedefin DEGERINI temizlememeli - hedef kendi degerini
         ayni kayittan alir (DbNavTest D01/D02). Sayac, cunku DataChanged ic
         ice gelebilir. Binding sinifi implementation'da (TRadDBLookupEditDataBinding). *)
      FDataChanging: Integer;
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
      (* PULL DIKISI. Neden BURASI ve neden inherited'DAN ONCE:

         1. Cagri sirasi (kaynaktan okundu, cxDropDownEdit.pas):
            SetDroppedDown -> DropDown (:3251) -> StorePosition ->
            DoInitPopup (:3256) -> DropDownAllowed -> SetupPopupWindow.
            DoInitPopup, acilir listenin verisi okunmadan ONCE calisir:
            govdesinde once OnInitPopup'lar (:3150), SONRA
            ILookupData.DropDown (:3159) var. Yani burada degistirilen
            ListSource.DataSet BU acilisi etkiler.

         2. ILookupData.DropDown, Properties.LockDataChanged yapiyor
            (cxLookupEdit.pas:309). Kilit ALINDIKTAN sonra dataset'i acip
            kapamak degisikligin BASTIRILMASI demektir. Bu yuzden pull
            inherited'dan ONCE.

         3. Published OnInitPopup olayini KULLANMIYORUZ, cunku (a) o
            kullanicinin olayidir, tuketmek DoEditValueChanged icin de
            reddettigimiz sey (asagidaki nota bakin), (b) DoInitPopup onu
            RepositoryItem varken IKI KEZ cagiriyor (:3150 ve :3152) -
            acilis basina iki filtre sorgusu, sessizce. *)
      procedure DoInitPopup; override;
    public
      destructor Destroy; override;
      (* Kaskadi ELLE tetikler. Gerekli, cunku DoEditValueChanged
         csLoading/csDesigning durumlarinda bilincli olarak sessiz kalir:
         bir kaydi programatik yuklerken (form olusurken EditValue atamak,
         DataSet'ten doldurmak) hedefler HIC haber almazdi. Yukleme bittikten
         sonra bunu cagirin. *)
      procedure CascadeNow;
      (* Pull'u ELLE tetikler; CascadeNow'in pull karsiligi. GEREKLI, cunku
         TcxCustomDropDownEdit.DropDown "if not IsWindowVisible(Handle) then
         Exit" ile BASLIYOR (cxDropDownEdit.pas:3253): GORUNMEYEN bir
         pencerede DoInitPopup HIC calismaz. Bassiz bir sonda pull mantigini
         ancak buradan olcebilir. AFilterOnPopup=False iken de tek giristir. *)
      procedure FilterNow;
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

  (* Listenin TEK doldurma yeri.
       Sender : olayi TASIYAN Properties - repository'ye yazildiysa
                repository'ninki (paylasilan, editorun GERCEKTEN kullandigi).
       ASource: soran editor - formdaki combo ya da gridin hucre editoru.
                Kendi Properties'i: help.Dev'deki _OwnProperties(ASource).
       AParams: AMasterFields'teki alanlar, AYNI ADLA, tuketicinin kaydindaki
                degerleriyle dolu.
       AItems : doldurulacak liste = Sender.Items. Ayrica verilir, cunku
                repository atanmisken editorun KENDI Properties'indeki Items'i
                HIC kullanilmaz (olculdu) - yanlis listeyi doldurmak kolaydir. *)
  TRadComboFillEvent = procedure (Sender: TRadComboBoxProperties;
    ASource: TComponent; AParams: TParams; AItems: TStrings) of object;

  TRadComboBoxProperties = class(TcxComboBoxProperties)
  private
    FRadSetting: TcxRadSetting;
    { Yuvalar ve serbest-birakma korumasi Lookup ailesiyle AYNI tutucudan
      gelir - iki yerde ayni kodu tutmuyoruz. }
    FSlots: TRadEditSlots;
    FCascadeEvent: TRadComboCascadeEvent;
    FCascading: Boolean;
    FCascadeSource: TComponent;
    FEditorId: string;
    FMasterFields: string;
    FFillEvent: TRadComboFillEvent;
    FEditOnPopup: Boolean;
    (* Son doldurmanin anahtari (AMasterFields degerleri). Items gibi
       PAYLASILAN Properties'te durur - repository'nin butun tuketicileri ayni
       Items'i gordugu icin dogrusu budur: gridde satir degisince anahtar da
       degisir ve liste yeniden dolar. *)
    FFillKey: string;
    FFilled: Boolean;
    FFilling: Boolean;
    function  GetSlot(AIndex: Integer): TComponent;
    procedure SetSlot(AIndex: Integer; const AValue: TComponent);
    function  GetCascadeField: string;
    procedure SetCascadeField(const AValue: string);
    function  GetCascadeTag: Integer;
    procedure SetCascadeTag(const AValue: Integer);
    procedure SetRadSetting(const AValue: TcxRadSetting);
    procedure CascadeOne(ATarget: TComponent; const AValue: Variant);
    function  MasterValues(ASource: TComponent; AParams: TParams): string;
    procedure SetMasterFields(const AValue: string);
    procedure SetEditorId(const AValue: string);
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
    /// <summary>AChain: tuketicinin KENDI Control1..4 yuvalari. Bos/nil ise bu
    /// Properties'in kendi yuvalari (eski davranis: zincir item'da).</summary>
    procedure DoCascade(ASource: TComponent; const AValue: Variant;
      AChain: TRadEditSlots = nil);
    /// <summary>Dolu zincir yuvasi sayisi (ChainWarning icin).</summary>
    function ChainSlotCount: Integer;
    /// <summary>Combo tarafindaki SESSIZ tuzak. Bos string = sorun yok.</summary>
    function CascadeWarning: string;
    /// <summary>Listeyi bir sonraki acilista yeniden doldurur (ornegin tanim
    /// editoru kapaninca).</summary>
    procedure ResetItems;
    /// <summary>AOnFill'i gerekirse cagirir: AMasterFields degerleri son
    /// doldurmadakiyle ayniysa hicbir sey yapmaz. Acilir liste acilirken
    /// kendiliginden cagrilir; elle de cagrilabilir.</summary>
    procedure FillItems(ASource: TComponent);
    /// <summary>AConsumer'in kaydinda bulunmayan AMasterFields alanlari
    /// (RadChainAudit icin). Bos string = sorun yok ya da bilinemiyor.</summary>
    function MissingMasterFields(AConsumer: TComponent): string;
    //procedure DoAssign(AProperties: TcxCustomEditProperties); override;
    //procedure DoInitPopup(Sender: TObject);
    //procedure PrepareDisplayValue(const AEditValue: Variant; var DisplayValue: Variant; AEditFocused: Boolean); override;
    //function DefaultAllowDropDownWhenReadOnly: Boolean; override;
  published
    /// <summary>Tuketiciye ozel genel ayar kumesi (Key, Tag, Master, Control1..4, DataBinding).</summary>
    property RadSetting: TcxRadSetting read FRadSetting write SetRadSetting;
    { Eski adlar: RadSetting'e yonlendirir, DFM'e YAZILMAZ ama eski DFM'ler okunur. }
    property AComponent1:TComponent index 1 read GetSlot write SetSlot stored False;
    property AComponent2:TComponent index 2 read GetSlot write SetSlot stored False;
    property AComponent3:TComponent index 3 read GetSlot write SetSlot stored False;
    property AComponent4:TComponent index 4 read GetSlot write SetSlot stored False;
    property ACascadeField:string  read GetCascadeField write SetCascadeField stored False;
    property ACascadeTag:Integer read GetCascadeTag write SetCascadeTag stored False;
    property AOnCascade:TRadComboCascadeEvent read FCascadeEvent write FCascadeEvent;
    /// <summary>Liste kimligi (ornegin 'sehir'). Bilesen YORUMLAMAZ; AOnFill
    /// ve OnButtonClick okur - uygulamadaki tek AOnFill hangi listeyi
    /// dolduracagini buna gore secer.</summary>
    property AEditorId:string read FEditorId write SetEditorId;
    /// <summary>Listenin bagli oldugu KAYIT alanlari, ';' ile ('ulke;sehir').
    /// Degerleri AOnFill'e AParams olarak ayni adla gider; son doldurmadakiyle
    /// ayniysa liste yeniden doldurulmaz. Bos = sabit liste, bir kez dolar.</summary>
    property AMasterFields:string read FMasterFields write SetMasterFields;
    property AOnFill:TRadComboFillEvent read FFillEvent write FFillEvent;
    /// <summary>DB'ye bagli editorde acilir liste acilirken dataset'i duzenleme
    /// moduna alir (secim ilk harekette kaybolmaz). Varsayilan False.</summary>
    property AEditOnPopup:Boolean read FEditOnPopup write FEditOnPopup default False;

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
    { AOnFill'in tetigi - bkz. TRadCustomLookupComboBox.DoInitPopup'taki gerekce. }
    procedure DoInitPopup; override;
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
    procedure DoInitPopup; override;
  public
    class function GetPropertiesClass: TcxCustomEditPropertiesClass; override;
    property ActiveProperties: TRadComboBoxProperties read GetActiveProperties;
  published
    property Properties: TRadComboBoxProperties read GetProperties write SetProperties;
  end;

  {$REGION 'TRadCheckComboBox ailesi'}

  /// <summary>Deger<->secim donusumleri; item metnini ve degerini sahipten
  /// (Names/Values) alir. Check combo ile check list box ortak kullanir.</summary>
  TRadValueList = class
  private
    FDelimiter: string;
    FWrap: Boolean;
    FNames, FValues: TFunc<Integer, string>;
    FCount: TFunc<Integer>;
  public
    constructor Create(const ADelimiter: string; ACount: TFunc<Integer>;
      ANames, AValues: TFunc<Integer, string>);
    function Count: Integer;
    function Name(AIndex: Integer): string;
    /// <summary>Item degeri; bossa Name(i).</summary>
    function Value(AIndex: Integer): string;
    /// <summary>En az bir item'da Value var mi.</summary>
    function HasValues: Boolean;
    function IndexOfValue(const AValue: string): Integer;
    function StatesOf(const AEditValue: TcxEditValue): TcxCheckStates;
    function StatesOfValues(const AValues: array of string): TcxCheckStates;
    function ValuesOfStates(const AStates: TcxCheckStates): TArray<string>;
    /// <summary>Secili degerler ayracla; Wrap acikken bas/son ayrac da yazilir (|a|b|).</summary>
    function Join(const AStates: TcxCheckStates): string;
    function InClause(const AField: string; const AValues: TArray<string>): string;
    /// <summary>Ayni degerli item, ayrac iceren deger. Bos = sorun yok.</summary>
    function Warning: string;
    /// <summary>Bagli DB alani degerleri tasiyamiyorsa bildirir.</summary>
    function FieldWarning(const AName: string; AField: TField): string;
    property Delimiter: string read FDelimiter write FDelimiter;
    /// <summary>Bas ve sona da ayrac: "|a|b|". LIKE '%|a|%' tek kodu kesin bulur (rad.customfield coklu).</summary>
    property Wrap: Boolean read FWrap write FWrap;
  end;

  TRadCheckComboBoxProperties = class;

  /// <summary>Stok item + Value.</summary>
  TRadCheckComboBoxItem = class(TcxCheckComboBoxItem)
  private
    FValue: string;
    procedure SetValue(const AValue: string);
  public
    procedure Assign(Source: TPersistent); override;
    /// <summary>Value; bossa Description.</summary>
    function EffectiveValue: string;
  published
    property Value: string read FValue write SetValue;
  end;

  TRadCheckComboBoxItems = class(TcxCheckComboBoxItems)
  private
    function GetItem(AIndex: Integer): TRadCheckComboBoxItem;
    procedure SetItem(AIndex: Integer; const AValue: TRadCheckComboBoxItem);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TRadCheckComboBoxItem;
    function AddItem(const ADescription, AValue: string): TRadCheckComboBoxItem;
    function IndexOfValue(const AValue: string): Integer;
    function HasValues: Boolean;
    property Items[AIndex: Integer]: TRadCheckComboBoxItem read GetItem write SetItem; default;
  end;

  (* Deger tasiyan check combo. Birim basligindaki CHECK COMBO notuna bakin.
     Tabanin Items'i private alanla sabit sinifta kurulur (cxCheckComboBox.pas:1168);
     bu yuzden kendi Items'imiz tabanin Items'ini GOLGELER ve ona aynalanir. *)
  TRadCheckComboBoxProperties = class(TcxCheckComboBoxProperties)
  private
    FItems: TRadCheckComboBoxItems;
    FValues: TRadValueList;
    FRadSetting: TcxRadSetting;
    FSyncing: Boolean;
    procedure SetRadSetting(const AValue: TcxRadSetting);
    procedure SetItems(const AValue: TRadCheckComboBoxItems);
    procedure SetValueDelimiter(const AValue: string);
    function  IsValueDelimiterStored: Boolean;
    function  GetValueWrap: Boolean;
    procedure SetValueWrap(const AValue: Boolean);
    { Bizim Items -> tabanin Items'i (indeks bazli; taban secimleri bozulmaz). }
    procedure SyncBaseItems;
    { Deger kipi: bir item'da Value var VE olaylar bos (olay kazanir). }
    function  ValueMode: Boolean;
    function  GetValueDelimiter: string;
  protected
    procedure DoAssign(AProperties: TcxCustomEditProperties); override;
    procedure CalculateCheckStatesByEditValue(Sender: TObject; const AEditValue: TcxEditValue;
      var ACheckStates: TcxCheckStates); override;
    function CalculateEditValueByCheckStates(Sender: TObject;
      const ACheckStates: TcxCheckStates): TcxEditValue; override;
  public
    constructor Create(AOwner: TPersistent); override;
    destructor Destroy; override;
    class function GetContainerClass: TcxContainerClass; override;
    /// <summary>EditValue'daki secili degerler, item sirasinda; bilinmeyenler atlanir.</summary>
    function ValuesOf(const AEditValue: TcxEditValue): TArray<string>;
    /// <summary>Degerlerden EditValue ('A;AS'); hicbiri yoksa ''.</summary>
    function EditValueOf(const AValues: array of string): TcxEditValue;
    /// <summary>"alan in ('A','AS')"; secim yoksa ''. Tek tirnak ikilenir.</summary>
    function ValuesIn(const AField: string; const AEditValue: TcxEditValue): string;
    /// <summary>Sessiz tuzaklar: ayni degerli item, ayrac iceren deger, olay
    /// cakismasi. Bos string = sorun yok.</summary>
    function CheckWarning: string;
    /// <summary>AConsumer'in bagli DB alani EditValue'yu tasiyamiyorsa
    /// (metin degil ya da kisa) bildirir; bagli alan yoksa bos.</summary>
    function FieldWarning(AConsumer: TComponent): string;
  published
    property RadSetting: TcxRadSetting read FRadSetting write SetRadSetting;
    { Tabanin Items'ini golgeler: tasarimci ve DFM yalniz bunu gorur. }
    property Items: TRadCheckComboBoxItems read FItems write SetItems;
    property AValueDelimiter: string read GetValueDelimiter write SetValueDelimiter
      stored IsValueDelimiterStored;
    /// <summary>EditValue bas/son ayracli yazilir: "|a|b|" (rad.customfield coklu secim bicimi).</summary>
    property AValueWrap: Boolean read GetValueWrap write SetValueWrap default False;
    (* cvfInteger kalsaydi taban 64 item'da istisna atar (CheckEditValueFormat,
       cxCheckComboBox.pas:1334) ve IsEditValueStored (:1492) EditValue'yu sayi
       sanirdi. Deger kipinde bu property yorumlanmaz; Value'suz item'larla
       stok davranis istenirse elle degistirilir. Yapici da AYNISINI atar. *)
    property EditValueFormat default cvfStatesString;
  end;

  TRadCheckComboBoxRepository = class(TRadEditRepositoryItem)
  private
    function GetProperties: TRadCheckComboBoxProperties;
    procedure SetProperties(Value: TRadCheckComboBoxProperties);
  public
    class function GetEditPropertiesClass: TcxCustomEditPropertiesClass; override;
  published
    property Properties: TRadCheckComboBoxProperties read GetProperties write SetProperties;
  end;

  { Kardes siniflar - ortak Rad atasi yok; gerekcesi TRadComboBox'un ustunde. }
  TRadCheckComboBox = class(TcxCheckComboBox)
  private
    function GetActiveProperties: TRadCheckComboBoxProperties;
    function GetProperties: TRadCheckComboBoxProperties;
    procedure SetProperties(Value: TRadCheckComboBoxProperties);
    function GetValues: TArray<string>;
    procedure SetValues(const AValues: TArray<string>);
    function GetHasValues: Boolean;
  public
    class function GetPropertiesClass: TcxCustomEditPropertiesClass; override;
    function AValuesIn(const AField: string): string;
    property ActiveProperties: TRadCheckComboBoxProperties read GetActiveProperties;
    property AValues: TArray<string> read GetValues write SetValues;
    property AHasValues: Boolean read GetHasValues;
  published
    property Properties: TRadCheckComboBoxProperties read GetProperties write SetProperties;
  end;

  TRadDBCheckComboBox = class(TcxDBCheckComboBox)
  private
    function GetActiveProperties: TRadCheckComboBoxProperties;
    function GetProperties: TRadCheckComboBoxProperties;
    procedure SetProperties(Value: TRadCheckComboBoxProperties);
    function GetValues: TArray<string>;
    procedure SetValues(const AValues: TArray<string>);
    function GetHasValues: Boolean;
  public
    class function GetPropertiesClass: TcxCustomEditPropertiesClass; override;
    function AValuesIn(const AField: string): string;
    property ActiveProperties: TRadCheckComboBoxProperties read GetActiveProperties;
    property AValues: TArray<string> read GetValues write SetValues;
    property AHasValues: Boolean read GetHasValues;
  published
    property Properties: TRadCheckComboBoxProperties read GetProperties write SetProperties;
  end;

  TRadCheckListCore = class;

  /// <summary>Check list item: Text + Value (+ Enabled, ImageIndex, Tag). State calisma
  /// zamani; EditValue/AValues ile verilir.</summary>
  TRadCheckListBoxItem = class(TCollectionItem)
  private
    FText: TCaption;
    FValue: string;
    FEnabled: Boolean;
    FImageIndex: TcxImageIndex;
    FTag: Integer;
    procedure SetText(const AValue: TCaption);
    procedure SetValue(const AValue: string);
    procedure SetEnabled(AValue: Boolean);
    procedure SetImageIndex(AValue: TcxImageIndex);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(Collection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
    function EffectiveValue: string;
  published
    property Text: TCaption read FText write SetText;
    property Value: string read FValue write SetValue;
    property Enabled: Boolean read FEnabled write SetEnabled default True;
    property ImageIndex: TcxImageIndex read FImageIndex write SetImageIndex default -1;
    property Tag: Integer read FTag write FTag default 0;
  end;

  TRadCheckListBoxItems = class(TOwnedCollection)
  private
    FCore: TRadCheckListCore;
    function GetItem(AIndex: Integer): TRadCheckListBoxItem;
    procedure SetItem(AIndex: Integer; const AValue: TRadCheckListBoxItem);
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    function Add: TRadCheckListBoxItem;
    function AddItem(const AText, AValue: string): TRadCheckListBoxItem;
    function IndexOfValue(const AValue: string): Integer;
    function HasValues: Boolean;
    property Items[AIndex: Integer]: TRadCheckListBoxItem read GetItem write SetItem; default;
  end;

  { CheckListBox: editor degil kap (Properties yok); RadSetting kontrolun kendisinde.
    Kontrolun Items'i (stok, State tasir) bizim Items'ten AYNALANIR. }
  TRadCheckListCore = class
  private
    FControl: TcxCustomCheckListBox;
    FItems: TRadCheckListBoxItems;
    FValues: TRadValueList;
    FSyncing: Boolean;
    function OwnsStatesEvent: Boolean;
    function OwnsValueEvent: Boolean;
    procedure Rebind;
    procedure SyncBaseItems;
    procedure StatesToValue(Sender: TObject; const ACheckStates: TcxCheckStates;
      out AEditValue: TcxEditValue);
    procedure ValueToStates(Sender: TObject; const AEditValue: TcxEditValue;
      var ACheckStates: TcxCheckStates);
  public
    constructor Create(AControl: TcxCustomCheckListBox);
    destructor Destroy; override;
    procedure SetItems(const AValue: TRadCheckListBoxItems);
    function ValueMode: Boolean;
    function ValuesOf: TArray<string>;
    function EditValueOf(const AValues: array of string): TcxEditValue;
    function ValuesIn(const AField: string): string;
    function CheckWarning: string;
    property Items: TRadCheckListBoxItems read FItems;
    property List: TRadValueList read FValues;
  end;

  TRadCheckListBox = class(TcxCheckListBox)
  private
    FCore: TRadCheckListCore;
    FRadSetting: TcxRadSetting;
    function GetHasValues: Boolean;
    function GetItems: TRadCheckListBoxItems;
    function GetValueDelimiter: string;
    function GetValues: TArray<string>;
    function IsValueDelimiterStored: Boolean;
    procedure SetItems(const AValue: TRadCheckListBoxItems);
    procedure SetRadSetting(const AValue: TcxRadSetting);
    procedure SetValueDelimiter(const AValue: string);
    procedure SetValues(const AValues: TArray<string>);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function AValuesIn(const AField: string): string;
    function CheckWarning: string;
    property AValues: TArray<string> read GetValues write SetValues;
    property AHasValues: Boolean read GetHasValues;
  published
    property RadSetting: TcxRadSetting read FRadSetting write SetRadSetting;
    { Stok Items'i golgeler (Text + Value); stok Items ona aynalanir. }
    property Items: TRadCheckListBoxItems read GetItems write SetItems;
    property AValueDelimiter: string read GetValueDelimiter write SetValueDelimiter
      stored IsValueDelimiterStored;
    property EditValueFormat default cvfStatesString;
  end;

  TRadDBCheckListBox = class(TcxDBCheckListBox)
  private
    FCore: TRadCheckListCore;
    FRadSetting: TcxRadSetting;
    function GetHasValues: Boolean;
    function GetItems: TRadCheckListBoxItems;
    function GetValueDelimiter: string;
    function GetValues: TArray<string>;
    function IsValueDelimiterStored: Boolean;
    procedure SetItems(const AValue: TRadCheckListBoxItems);
    procedure SetRadSetting(const AValue: TcxRadSetting);
    procedure SetValueDelimiter(const AValue: string);
    procedure SetValues(const AValues: TArray<string>);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function AValuesIn(const AField: string): string;
    function CheckWarning: string;
    function FieldWarning: string;
    property AValues: TArray<string> read GetValues write SetValues;
    property AHasValues: Boolean read GetHasValues;
    property EditValue;
  published
    property RadSetting: TcxRadSetting read FRadSetting write SetRadSetting;
    property Items: TRadCheckListBoxItems read GetItems write SetItems;
    property AValueDelimiter: string read GetValueDelimiter write SetValueDelimiter
      stored IsValueDelimiterStored;
    property EditValueFormat default cvfStatesString;
  end;

  {$ENDREGION}




  {$REGION 'RadSetting tasiyan editorler'}

  TRadButtonEditProperties = class(TcxButtonEditProperties)
  private
    FRadSetting: TcxRadSetting;
    procedure SetRadSetting(const AValue: TcxRadSetting);
  protected
    procedure DoAssign(AProperties: TcxCustomEditProperties); override;
  public
    constructor Create(AOwner: TPersistent); override;
    destructor Destroy; override;
    class function GetContainerClass: TcxContainerClass; override;
  published
    property RadSetting: TcxRadSetting read FRadSetting write SetRadSetting;
  end;

  TRadButtonEditRepository = class(TRadEditRepositoryItem)
  private
    function GetProperties: TRadButtonEditProperties;
    procedure SetProperties(Value: TRadButtonEditProperties);
  public
    class function GetEditPropertiesClass: TcxCustomEditPropertiesClass; override;
  published
    property Properties: TRadButtonEditProperties read GetProperties write SetProperties;
  end;

  TRadButtonEdit = class(TcxButtonEdit)
  private
    function GetActiveProperties: TRadButtonEditProperties;
    function GetProperties: TRadButtonEditProperties;
    procedure SetProperties(Value: TRadButtonEditProperties);
  public
    class function GetPropertiesClass: TcxCustomEditPropertiesClass; override;
    property ActiveProperties: TRadButtonEditProperties read GetActiveProperties;
  published
    property Properties: TRadButtonEditProperties read GetProperties write SetProperties;
  end;

  TRadDBButtonEdit = class(TcxDBButtonEdit)
  private
    function GetActiveProperties: TRadButtonEditProperties;
    function GetProperties: TRadButtonEditProperties;
    procedure SetProperties(Value: TRadButtonEditProperties);
  public
    class function GetPropertiesClass: TcxCustomEditPropertiesClass; override;
    property ActiveProperties: TRadButtonEditProperties read GetActiveProperties;
  published
    property Properties: TRadButtonEditProperties read GetProperties write SetProperties;
  end;
  TRadImageComboBoxProperties = class(TcxImageComboBoxProperties)
  private
    FRadSetting: TcxRadSetting;
    procedure SetRadSetting(const AValue: TcxRadSetting);
  protected
    procedure DoAssign(AProperties: TcxCustomEditProperties); override;
  public
    constructor Create(AOwner: TPersistent); override;
    destructor Destroy; override;
    class function GetContainerClass: TcxContainerClass; override;
  published
    property RadSetting: TcxRadSetting read FRadSetting write SetRadSetting;
  end;

  TRadImageComboBoxRepository = class(TRadEditRepositoryItem)
  private
    function GetProperties: TRadImageComboBoxProperties;
    procedure SetProperties(Value: TRadImageComboBoxProperties);
  public
    class function GetEditPropertiesClass: TcxCustomEditPropertiesClass; override;
  published
    property Properties: TRadImageComboBoxProperties read GetProperties write SetProperties;
  end;

  TRadImageComboBox = class(TcxImageComboBox)
  private
    function GetActiveProperties: TRadImageComboBoxProperties;
    function GetProperties: TRadImageComboBoxProperties;
    procedure SetProperties(Value: TRadImageComboBoxProperties);
  public
    class function GetPropertiesClass: TcxCustomEditPropertiesClass; override;
    property ActiveProperties: TRadImageComboBoxProperties read GetActiveProperties;
  published
    property Properties: TRadImageComboBoxProperties read GetProperties write SetProperties;
  end;

  TRadDBImageComboBox = class(TcxDBImageComboBox)
  private
    function GetActiveProperties: TRadImageComboBoxProperties;
    function GetProperties: TRadImageComboBoxProperties;
    procedure SetProperties(Value: TRadImageComboBoxProperties);
  public
    class function GetPropertiesClass: TcxCustomEditPropertiesClass; override;
    property ActiveProperties: TRadImageComboBoxProperties read GetActiveProperties;
  published
    property Properties: TRadImageComboBoxProperties read GetProperties write SetProperties;
  end;
  TRadExtLookupComboBoxProperties = class(TcxExtLookupComboBoxProperties)
  private
    FRadSetting: TcxRadSetting;
    procedure SetRadSetting(const AValue: TcxRadSetting);
  protected
    procedure DoAssign(AProperties: TcxCustomEditProperties); override;
  public
    constructor Create(AOwner: TPersistent); override;
    destructor Destroy; override;
    class function GetContainerClass: TcxContainerClass; override;
  published
    property RadSetting: TcxRadSetting read FRadSetting write SetRadSetting;
  end;

  TRadExtLookupComboBoxRepository = class(TRadEditRepositoryItem)
  private
    function GetProperties: TRadExtLookupComboBoxProperties;
    procedure SetProperties(Value: TRadExtLookupComboBoxProperties);
  public
    class function GetEditPropertiesClass: TcxCustomEditPropertiesClass; override;
  published
    property Properties: TRadExtLookupComboBoxProperties read GetProperties write SetProperties;
  end;

  TRadExtLookupComboBox = class(TcxExtLookupComboBox)
  private
    function GetActiveProperties: TRadExtLookupComboBoxProperties;
    function GetProperties: TRadExtLookupComboBoxProperties;
    procedure SetProperties(Value: TRadExtLookupComboBoxProperties);
  public
    class function GetPropertiesClass: TcxCustomEditPropertiesClass; override;
    property ActiveProperties: TRadExtLookupComboBoxProperties read GetActiveProperties;
  published
    property Properties: TRadExtLookupComboBoxProperties read GetProperties write SetProperties;
  end;

  TRadDBExtLookupComboBox = class(TcxDBExtLookupComboBox)
  private
    function GetActiveProperties: TRadExtLookupComboBoxProperties;
    function GetProperties: TRadExtLookupComboBoxProperties;
    procedure SetProperties(Value: TRadExtLookupComboBoxProperties);
  public
    class function GetPropertiesClass: TcxCustomEditPropertiesClass; override;
    property ActiveProperties: TRadExtLookupComboBoxProperties read GetActiveProperties;
  published
    property Properties: TRadExtLookupComboBoxProperties read GetProperties write SetProperties;
  end;
  TRadPopupEditProperties = class(TcxPopupEditProperties)
  private
    FRadSetting: TcxRadSetting;
    procedure SetRadSetting(const AValue: TcxRadSetting);
  protected
    procedure DoAssign(AProperties: TcxCustomEditProperties); override;
  public
    constructor Create(AOwner: TPersistent); override;
    destructor Destroy; override;
    class function GetContainerClass: TcxContainerClass; override;
  published
    property RadSetting: TcxRadSetting read FRadSetting write SetRadSetting;
  end;

  TRadPopupEditRepository = class(TRadEditRepositoryItem)
  private
    function GetProperties: TRadPopupEditProperties;
    procedure SetProperties(Value: TRadPopupEditProperties);
  public
    class function GetEditPropertiesClass: TcxCustomEditPropertiesClass; override;
  published
    property Properties: TRadPopupEditProperties read GetProperties write SetProperties;
  end;

  TRadPopupEdit = class(TcxPopupEdit)
  private
    function GetActiveProperties: TRadPopupEditProperties;
    function GetProperties: TRadPopupEditProperties;
    procedure SetProperties(Value: TRadPopupEditProperties);
  public
    class function GetPropertiesClass: TcxCustomEditPropertiesClass; override;
    property ActiveProperties: TRadPopupEditProperties read GetActiveProperties;
  published
    property Properties: TRadPopupEditProperties read GetProperties write SetProperties;
  end;

  TRadDBPopupEdit = class(TcxDBPopupEdit)
  private
    function GetActiveProperties: TRadPopupEditProperties;
    function GetProperties: TRadPopupEditProperties;
    procedure SetProperties(Value: TRadPopupEditProperties);
  public
    class function GetPropertiesClass: TcxCustomEditPropertiesClass; override;
    property ActiveProperties: TRadPopupEditProperties read GetActiveProperties;
  published
    property Properties: TRadPopupEditProperties read GetProperties write SetProperties;
  end;
  {$ENDREGION}

(* ZINCIR DENETIMI - uc teshis sorgusunu tek cagrida toplar.

   Neden var: ChainWarning ve PullWarning yazildilar ama HICBIR YERDEN
   cagrilmiyorlardi. "Sessiz tuzagi bildir" diye eklenen mekanizmanin
   kendisi sessiz kalmisti; bir uyari, onu soran biri olmadan uyari degildir.

   Neden hala KENDILIGINDEN uyarmiyor: DFM yuklenirken her yapilandirma bir
   an eksik gorunur (master atandi, olay henuz atanmadi). Otomatik uyari
   yanlis alarm uretirdi - kitin ChainWarning icin verdigi kararin aynisi.
   Bu yuzden bu bir SORGUDUR; cagirmak size kalmis:

     {$IFDEF DEBUG}
     OutputDebugString(PChar(RadChainAudit(Self)));
     {$ENDIF}

   Adi '_' ile BASLAMIYOR: bu bir helper birimi degil (helper-patterns.md'deki
   '_' kurali help.* birimleri icindir), Rad.Dev'in kendi genel yuzeyidir.

   ARoot'un BILESEN AGACINI gezer (Owner zinciri). Tasarim zamaninda yaratilan
   grid kolonlari da bu agactadir. Kod icinde Owner'siz yaratilmis bir editor
   bulunamaz - o zaman onun Properties'ini dogrudan sorgulayin.

   Paylasilan Properties ornekleri BIR KEZ raporlanir: bir RepositoryItem'a
   bagli on tuketici ayni uyariyi on kez basmaz. *)
function RadChainAudit(ARoot: TComponent): string;

implementation
  uses Help.Dev,DBAccess, Vcl.Dialogs, Help.vcl, System.TypInfo;

function RadChainAudit(ARoot: TComponent): string;
var
  LSeen: TList<TObject>;
  LOut: TStringList;
  LKokAdi: string;

  procedure Ekle(const AText: string);
  begin
    if AText <> '' then
      LOut.Add(AText);
  end;

  procedure BakProperties(AProps: TcxCustomEditProperties);
  begin
    if AProps = nil then
      Exit;
    { Paylasilan ornek: ayni Properties'i ikinci kez raporlamayiz. }
    if LSeen.IndexOf(AProps) >= 0 then
      Exit;

    (* HER IKI AILE de denetlenir. Eskiden yalnizca lookup ailesine
       bakiliyordu; combo'nun kendi sessiz tuzagi (AOnCascade'siz zincir)
       denetimde hic gorunmuyordu - RADDEV-007. *)
    if AProps is TRadLookupComboBoxProperties then
    begin
      LSeen.Add(AProps);
      Ekle(TRadLookupComboBoxProperties(AProps).PullWarning);
    end
    else if AProps is TRadComboBoxProperties then
    begin
      LSeen.Add(AProps);
      Ekle(TRadComboBoxProperties(AProps).CascadeWarning);
    end
    else if AProps is TRadCheckComboBoxProperties then
    begin
      LSeen.Add(AProps);
      Ekle(TRadCheckComboBoxProperties(AProps).CheckWarning);
    end;
  end;

  procedure Gez(AC: TComponent);
  var
    i: Integer;
  begin
    if AC = nil then
      Exit;
    if AC is TRadEditRepositoryItem then
      Ekle(TRadEditRepositoryItem(AC).ChainWarning)
    else if (AC is TcxCustomEdit) or (AC is TcxCustomGridTableItem) then
    begin
      (* IKISINE DE bakilir. Bir tuketici paylasilan bir RepositoryItem'a
         bagliyken KENDI Properties'inde de yuk tasiyabilir - kitin kendi
         deseni budur (PerConsumerTest bunu olcuyor) ve ChainWarning master
         icin tam olarak bunu ONERIYOR. Yalnizca aktif Properties'e bakan bir
         denetim, tavsiye ettigi kurulumu denetleyemezdi.
         Ayni ornek iki kez raporlanmaz: LSeen bunu zaten kesiyor. *)
      BakProperties(_OwnProperties(AC));
      BakProperties(_ActiveProperties(AC));
      { Combo listesi: AMasterFields TUKETICININ kaydinda var mi? Paylasilan
        item icin bile tuketici basina bakilir - her tuketicinin kaydi farkli. }
      if _ActiveProperties(AC) is TRadComboBoxProperties then
        Ekle(TRadComboBoxProperties(_ActiveProperties(AC)).MissingMasterFields(AC));
      if (_OwnProperties(AC) <> _ActiveProperties(AC)) and
         (_OwnProperties(AC) is TRadComboBoxProperties) then
        Ekle(TRadComboBoxProperties(_OwnProperties(AC)).MissingMasterFields(AC));
      { Check combo: bagli DB alani 'A;S;AS' metnini tasiyabiliyor mu? }
      if _ActiveProperties(AC) is TRadCheckComboBoxProperties then
        Ekle(TRadCheckComboBoxProperties(_ActiveProperties(AC)).FieldWarning(AC));
    end;
    for i := 0 to AC.ComponentCount - 1 do
      Gez(AC.Components[i]);
  end;

begin
  Result := '';
  if ARoot = nil then
    Exit;
  { Kod icinde yaratilmis bir formun Name'i bostur; basligin hangi koku
    denetledigini soylemesi gerekiyor. }
  if ARoot.Name <> '' then
    LKokAdi := ARoot.Name
  else
    LKokAdi := '<' + ARoot.ClassName + '>';
  LSeen := TList<TObject>.Create;
  try
    LOut := TStringList.Create;
    try
      Gez(ARoot);
      if LOut.Count > 0 then
        Result := Format('RadChainAudit(%s): %d bulgu',
          [LKokAdi, LOut.Count]) + sLineBreak + LOut.Text;
    finally
      LOut.Free;
    end;
  finally
    LSeen.Free;
  end;
end;

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
  (* SIRA HAYATI ONEM TASIYOR - RADDEV-001.

     inherited Destroy, bagli listener'lari kaldirirken RemoveNotification'i
     calistirir (cxEdit.pas:6745-6755) ve orada RemoveListener SANALDIR
     (cxEdit.pas:260). Cagri bizim override'imiza duser, o da FConsumers'a
     dokunur. Listeyi ONCE serbest biraksaydik - eskiden oyleydi - serbest
     birakilmis bir TList uzerinde Remove cagrilirdi.

     OLCULDU, tahmin degil: eski sirayla, uc tuketici bagliyken Free ->
     EAccessViolation (DestructorTest T02). Bu, "bellek yoneticisi blogu
     henuz geri vermediyse sessizce calisabilir" turunden bir tuzak degil;
     bu makinede her seferinde coktu.

     Tetikleyici siradan: tasarimcida bir RepositoryItem'i hala kullanan
     kolonlar/editorler varken silmek. *)
  inherited Destroy;
  FreeAndNil(FConsumers);
end;

procedure TRadEditRepositoryItem.AddListener(AListener: IcxEditRepositoryItemListener);
begin
  inherited AddListener(AListener);
  { Isaretci olarak saklaniyor: tuketiciler TComponent tabanli, referans
    sayimi yok; arayuz referansi tutmak yasam suresini uzatmaz ama gereksiz
    yere kilitler. }
  if (FConsumers <> nil) and (FConsumers.IndexOf(Pointer(AListener)) < 0) then
    FConsumers.Add(Pointer(AListener));
end;

procedure TRadEditRepositoryItem.RemoveListener(AListener: IcxEditRepositoryItemListener);
begin
  { Destroy'dan SONRA gelen bir cagriya karsi: liste orada nil'lenir. }
  if FConsumers <> nil then
    FConsumers.Remove(Pointer(AListener));
  inherited RemoveListener(AListener);
end;

function TRadEditRepositoryItem.ConsumerCount: Integer;
begin
  { Destroy sonrasi cagri: liste nil'lenmis olur (bkz. Destroy'daki not). }
  if FConsumers = nil then
    Exit(0);
  Result := FConsumers.Count;
end;

function TRadEditRepositoryItem.Consumers(AIndex: Integer): TComponent;
var
  LIntf: IcxEditRepositoryItemListener;
  LObj: TObject;
begin
  Result := nil;
  if (FConsumers = nil) or (AIndex < 0) or (AIndex >= FConsumers.Count) then
    Exit;
  LIntf := IcxEditRepositoryItemListener(FConsumers[AIndex]);
  LObj := LIntf as TObject;
  if LObj is TComponent then
    Result := TComponent(LObj);
end;

function TRadEditRepositoryItem.ChainWarning: string;
var
  LFilled, LUsers: Integer;
  LMaster: Boolean;
begin
  Result := '';
  LFilled := 0;
  LMaster := False;
  if Properties is TRadLookupComboBoxProperties then
  begin
    LFilled := TRadLookupComboBoxProperties(Properties).ChainSlotCount;
    LMaster := TRadLookupComboBoxProperties(Properties).HasMaster;
  end
  else if Properties is TRadComboBoxProperties then
    LFilled := TRadComboBoxProperties(Properties).ChainSlotCount;
  if (LFilled = 0) and not LMaster then
    Exit;

  LUsers := ConsumerCount;
  if LUsers <= 1 then
    Exit;

  (* PULL yonu de push ile AYNI sekilde katlanir, ama duzeltmesi FARKLI
     oldugu icin ayri bir mesaj: item'in KENDI Properties'inde bir AMaster
     varsa, o item'i kullanan HER tuketici AYNI master'a bakar. "Her tuketici
     kendi master'ini gorsun" istegi sessizce kaybolur. *)
  if LMaster then
    Result := Format(
      '%s: AMaster bu RepositoryItem''in KENDI Properties''inde kurulu, ama ' +
      'item %d tuketici tarafindan paylasiliyor. Hepsi ayni master''in ' +
      'degerine gore suzulur. Master''i her tuketicinin KENDI Properties''ine ' +
      'tasiyin.',
      [Name, LUsers]);

  if LFilled = 0 then
    Exit;
  if Result <> '' then
    Result := Result + sLineBreak;

  Result := Result + Format(
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

procedure TRadEditSlots.CheckIndex(AIndex: Integer);
begin
  (* RADDEV-006. Derleyici korumasina GUVENILEMEZ: paket
     {$RANGECHECKS OFF} ile derleniyor (RadKon.dpk:17) ve bu sinif public,
     yani Get/Put disaridan cagrilabilir. Denetimsiz haliyle Get(0) dizi disi
     OKUMA, Put(5, X) dizi disi YAZMA yapiyordu - ikisi de sessizce
     (PullTest T18, duzeltmeden once olculdu). *)
  if (AIndex < Low(FItems)) or (AIndex > High(FItems)) then
    raise ERadDev.CreateFmt(
      'Yuva indeksi %d gecersiz; gecerli aralik %d..%d. Bu sinif ' +
      '{$RANGECHECKS OFF} ile derlenen bir pakette yer aldigi icin denetim ' +
      'elle yapiliyor - aksi halde dizi disi erisim sessiz kalirdi.',
      [AIndex, Low(FItems), High(FItems)]);
end;

function TRadEditSlots.Get(AIndex: Integer): TComponent;
begin
  CheckIndex(AIndex);
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
  CheckIndex(AIndex);
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

{ Acilir liste acilirken DB editorunun dataset'ini duzenleme moduna alir.
  DataSource.AutoEdit = False iken secim, dataset duzenlenmedigi icin ilk
  harekette sessizce eski degere doner (olculdu: ComboEditModeProbe). }
type
  { DataBinding korunmus; ayni birimde erisim sinifi. }
  TRadEditAccess = class(TcxCustomEdit);

procedure RadEnterEditMode(AEdit: TcxCustomEdit);
var
  LBinding: TcxDBEditDataBinding;
begin
  if not (TRadEditAccess(AEdit).DataBinding is TcxDBEditDataBinding) then
    Exit;
  LBinding := TcxDBEditDataBinding(TRadEditAccess(AEdit).DataBinding);
  if (LBinding.DataLink.DataSet <> nil) and
     (LBinding.DataLink.DataSet.State = dsBrowse) and LBinding.CanModify then
    { DataLink.Edit AutoEdit'i gozetir (TDataSource.Edit); secenek acik istek. }
    LBinding.DataLink.DataSet.Edit;
end;

{ TcxRadDataBinding }

constructor TcxRadDataBinding.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner);
  FLink := TDataLink.Create;
end;

destructor TcxRadDataBinding.Destroy;
begin
  FreeAndNil(FLink);
  inherited Destroy;
end;

procedure TcxRadDataBinding.Assign(ASource: TPersistent);
begin
  if ASource is TcxRadDataBinding then
  begin
    DataSource := TcxRadDataBinding(ASource).DataSource;
    FDataField := TcxRadDataBinding(ASource).FDataField;
  end
  else
    inherited Assign(ASource);
end;

function TcxRadDataBinding.GetDataSource: TDataSource;
begin
  Result := FLink.DataSource;
end;

procedure TcxRadDataBinding.SetDataSource(const AValue: TDataSource);
begin
  FLink.DataSource := AValue;
end;

function TcxRadDataBinding.GetField: TField;
begin
  Result := nil;
  if (FDataField <> '') and (FLink.DataSet <> nil) then
    Result := FLink.DataSet.FindField(FDataField);
end;

function TcxRadDataBinding.IsAvailable: Boolean;
begin
  Result := FLink.Active and (Field <> nil);
end;

function TcxRadDataBinding.GetValue: Variant;
begin
  if IsAvailable then
    Result := Field.Value
  else
    Result := Null;
end;

{ TcxRadSetting }

constructor TcxRadSetting.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner);
  FControls := TRadEditSlots.Create(Self);
  FMasterHolder := TRadEditSlots.Create(Self);
  FDataBinding := TcxRadDataBinding.Create(Self);
end;

destructor TcxRadSetting.Destroy;
begin
  FreeAndNil(FDataBinding);
  FreeAndNil(FMasterHolder);
  FreeAndNil(FControls);
  inherited Destroy;
end;

procedure TcxRadSetting.Assign(ASource: TPersistent);
var
  LSrc: TcxRadSetting;
begin
  if not (ASource is TcxRadSetting) then
  begin
    inherited Assign(ASource);
    Exit;
  end;
  LSrc := TcxRadSetting(ASource);
  FKey := LSrc.FKey;
  FTag := LSrc.FTag;
  FControls.Assign(LSrc.FControls);
  FMasterHolder.Assign(LSrc.FMasterHolder);
  FDataBinding.Assign(LSrc.FDataBinding);
  { Data kopyalanmaz: calisma zamani durumu, sahibi belli degil. }
end;

function TcxRadSetting.GetControl(AIndex: Integer): TComponent;
begin
  Result := FControls.Get(AIndex);
end;

procedure TcxRadSetting.SetControl(AIndex: Integer; const AValue: TComponent);
begin
  FControls.Put(AIndex, AValue);
end;

function TcxRadSetting.GetMaster: TComponent;
begin
  Result := FMasterHolder.Get(1);
end;

procedure TcxRadSetting.SetDataBinding(const AValue: TcxRadDataBinding);
begin
  FDataBinding.Assign(AValue);
end;

procedure TcxRadSetting.SetMaster(const AValue: TComponent);
begin
  (* TIP DENETIMI: Object Inspector'daki acilir liste formdaki HER bileseni
     gosterir; _ValueOf yalnizca TcxCustomEdit ve TcxCustomGridTableItem tanir,
     digerlerinde Null doner ve filtre SESSIZCE bos calisir. *)
  if (AValue <> nil) and not (AValue is TcxCustomEdit) and
     not (AValue is TcxCustomGridTableItem) then
    raise ERadDev.CreateFmt(
      'Master bir editor (TcxCustomEdit) ya da bir grid kolonu ' +
      '(TcxCustomGridTableItem) olmalidir; %s verildi. Degeri _ValueOf okur ' +
      've baska turlerde Null doner - yani filtre sessizce bos calisirdi.',
      [AValue.ClassName]);
  (* DAIRESEL MASTER: editor kendini master gosterir ya da master, bu
     Properties'i paylasan baska bir tuketicidir (paylasilan RepositoryItem). *)
  if (AValue <> nil) and
     ((_OwnProperties(AValue) = Owner) or (_ActiveProperties(AValue) = Owner)) then
    raise ERadDev.CreateFmt(
      'Master dairesel: %s bu Properties ornegini kullaniyor, yani editor ' +
      'kendi degerine gore suzulurdu. Paylasilan bir RepositoryItem ' +
      'kullaniyorsaniz master''i tuketicinin KENDI Properties''ine tasiyin.',
      [AValue.Name]);
  FMasterHolder.Put(1, AValue);
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
  FRadSetting := TcxRadSetting.Create(Self);
  FSlots := FRadSetting.Controls;
end;

destructor TRadComboBoxProperties.Destroy;
begin
  FSlots := nil;
  FreeAndNil(FRadSetting);
  inherited Destroy;
end;

function TRadComboBoxProperties.GetSlot(AIndex: Integer): TComponent;
begin
  Result := FSlots.Get(AIndex);
end;

function TRadComboBoxProperties.GetCascadeField: string;
begin
  Result := FRadSetting.Key;
end;

procedure TRadComboBoxProperties.SetCascadeField(const AValue: string);
begin
  FRadSetting.Key := AValue;
end;

function TRadComboBoxProperties.GetCascadeTag: Integer;
begin
  Result := FRadSetting.Tag;
end;

procedure TRadComboBoxProperties.SetCascadeTag(const AValue: Integer);
begin
  FRadSetting.Tag := AValue;
end;

procedure TRadComboBoxProperties.SetRadSetting(const AValue: TcxRadSetting);
begin
  FRadSetting.Assign(AValue);
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
  FRadSetting.Assign(LSrc.FRadSetting);
  FEditOnPopup := LSrc.FEditOnPopup;
  FCascadeEvent := LSrc.FCascadeEvent;
  FEditorId := LSrc.FEditorId;
  FMasterFields := LSrc.FMasterFields;
  FFillEvent := LSrc.FFillEvent;
  { Kopya, kaynagin doldurma anahtarini devralmaz. }
  ResetItems;
end;

function TRadComboBoxProperties.CascadeWarning: string;
begin
  Result := '';
  (* AOnFill'siz liste kurulumu: AEditorId/AMasterFields yazilmis ama listeyi
     dolduracak olay yok - acilir liste hep bos (ya da tasarimdaki Items ile)
     gelir, hicbir uyari cikmaz. *)
  if ((FEditorId <> '') or (FMasterFields <> '')) and not Assigned(FFillEvent) then
    Result := Format('AEditorId="%s" / AMasterFields="%s" yazilmis ama AOnFill ' +
      'yok: liste hic doldurulmaz.', [FEditorId, FMasterFields]);

  if FSlots.FilledCount = 0 then
    Exit;

  (* COMBO'YA OZGU. Lookup ailesinde hedef, kendi listesini bir dataset'ten
     alir; kaynak yalnizca "degerin gecersiz" sinyalini gonderse bile hedef
     acilirken kendi pull'uyla tazelenir.

     Combo'nun listesi Items: TStrings'tir - onu YALNIZCA bir isleyici
     doldurabilir. AOnCascade atanmamissa hedefin listesi HIC degismez:
     kaskad kurulmus gorunur, calisir gorunur, ama secenekler sabit kalir.
     Bu, hicbir istisna veya uyari uretmeyen turden bir hatadir. *)
  if not Assigned(FCascadeEvent) then
  begin
    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result +
      'Zincir kurulmus (' + IntToStr(FSlots.FilledCount) + ' hedef) ama ' +
      'AOnCascade yok. Combo hedefinin listesi Items''tir ve yalnizca bir ' +
      'isleyici doldurabilir - kaynak degistiginde hedefin secenekleri HIC ' +
      'degismez. (Lookup hedefleri kendi AOnFilter''i ile tazelenebilir; ' +
      'combo icin boyle bir yol yoktur.)';
  end;
end;

function TRadComboBoxProperties.ChainSlotCount: Integer;
begin
  Result := FSlots.FilledCount;
end;

{ Mesajlar icin: kodla yaratilmis bir dataset'in Name'i bostur. }
function DataSetAdi(ADataSet: TDataSet): string;
begin
  if ADataSet.Name <> '' then
    Result := ADataSet.Name
  else
    Result := '<' + ADataSet.ClassName + '>';
end;

procedure TRadComboBoxProperties.SetEditorId(const AValue: string);
begin
  if FEditorId = AValue then
    Exit;
  FEditorId := AValue;
  ResetItems;   { baska bir liste isteniyor }
end;

procedure TRadComboBoxProperties.SetMasterFields(const AValue: string);
begin
  if FMasterFields = AValue then
    Exit;
  FMasterFields := AValue;
  ResetItems;
end;

procedure TRadComboBoxProperties.ResetItems;
begin
  FFilled := False;
  FFillKey := '';
end;

function TRadComboBoxProperties.MasterValues(ASource: TComponent;
  AParams: TParams): string;
var
  LNames: TArray<string>;
  LName: string;
  LDS: TDataSet;
  LField: TField;
  LParam: TParam;
  LValue: Variant;
begin
  (* Degerler SORAN editorun kaydindan okunur. _DataSetOf formdaki DB
     editorunde veri baglantisini, gridin hucre editorunde kolonun
     DataController'ini kullanir (help.Dev). Properties'ten sorulamaz:
     paylasilir, hangi kaydi soracagini bilemez. *)
  Result := '';
  LNames := FMasterFields.Split([';'], TStringSplitOptions.ExcludeEmpty);
  if Length(LNames) = 0 then
    Exit;
  LDS := _DataSetOf(ASource);
  for LName in LNames do
  begin
    LValue := Null;
    LField := nil;
    if LDS <> nil then
      LField := LDS.FindField(Trim(LName));
    { Alan listesi bilinirken alan YOKSA sessiz bos liste yerine sebebi
      soyleyen istisna. Kapali ve alansiz bir dataset'te bilinemez. }
    if (LField = nil) and (LDS <> nil) and (LDS.Active or (LDS.FieldCount > 0)) then
      raise ERadDev.CreateFmt(
        'AMasterFields: "%s" alani %s dataset''inde yok (AEditorId="%s"). ' +
        'Alan adini kayittaki alanla ayni yazin.', [Trim(LName), DataSetAdi(LDS), FEditorId]);
    if (LField <> nil) and LDS.Active then
      LValue := LField.Value;
    if LField <> nil then
      LParam := AParams.CreateParam(LField.DataType, Trim(LName), ptInput)
    else
      LParam := AParams.CreateParam(ftUnknown, Trim(LName), ptInput);
    LParam.Value := LValue;
    { Tur de anahtarda: Null ile bos metin ayni sayilmasin. }
    Result := Result + IntToStr(VarType(LValue)) + ':' + VarToStr(LValue) + #1;
  end;
end;

procedure TRadComboBoxProperties.FillItems(ASource: TComponent);
var
  LParams: TParams;
  LKey: string;
begin
  if FFilling or not Assigned(FFillEvent) then
    Exit;
  LParams := TParams.Create(nil);
  try
    LKey := MasterValues(ASource, LParams);
    if FFilled and (LKey = FFillKey) then
      Exit;
    FFilling := True;
    try
      Items.BeginUpdate;
      try
        FFillEvent(Self, ASource, LParams, Items);
      finally
        Items.EndUpdate;
      end;
      { Anahtar YALNIZCA basarida kaydedilir: olay istisna atarsa bir sonraki
        acilis yeniden dener (ComboFillTest F13). }
      FFillKey := LKey;
      FFilled := True;
    finally
      FFilling := False;
    end;
  finally
    LParams.Free;
  end;
end;

function TRadComboBoxProperties.MissingMasterFields(AConsumer: TComponent): string;
var
  LNames: TArray<string>;
  LName: string;
  LDS: TDataSet;
begin
  Result := '';
  LNames := FMasterFields.Split([';'], TStringSplitOptions.ExcludeEmpty);
  if Length(LNames) = 0 then
    Exit;
  LDS := _DataSetOf(AConsumer);
  { Alan listesi bilinmiyorsa (kapali, alansiz dataset) YANLIS alarm vermeyiz. }
  if (LDS = nil) or (LDS.FieldCount = 0) then
    Exit;
  for LName in LNames do
    if LDS.FindField(Trim(LName)) = nil then
    begin
      if Result <> '' then
        Result := Result + sLineBreak;
      Result := Result + Format('%s: AMasterFields "%s" alani %s dataset''inde ' +
        'yok - liste acilinca ERadDev atilir.', [AConsumer.Name, Trim(LName), DataSetAdi(LDS)]);
    end;
end;

class function TRadComboBoxProperties.GetContainerClass: TcxContainerClass;
begin
  Result := TRadComboBox;
end;

procedure TRadComboBoxProperties.CascadeOne(ATarget: TComponent; const AValue: Variant);
var
  LTarget: TRadLookupComboBoxProperties;
begin
  (* Lookup ailesindekiyle AYNI gecersiz kilma. Eskiden yalnizca olay
     cagriliyordu: bir combo'nun AComponent1'i bir lookup editorunu
     gosteriyorsa, o hedefin cozulmus-anahtar ve metin onbellekleri HIC
     bosaltilmiyordu - hedef, artik gecerli olmayan bir anahtari eski
     metniyle gostermeye devam ediyordu.

     AClearTargetsOnCascade karsiligi BILINCLI olarak yok: combo'nun degeri
     bir yabanci anahtar degil, gosterilen metindir; "degerin artik gecersiz"
     iddiasi orada cok daha zayif. *)
  LTarget := TRadLookupComboBoxProperties.TargetProperties(ATarget);
  if LTarget <> nil then
    LTarget.ResetCaches;

  if Assigned(FCascadeEvent) then
    FCascadeEvent(Self, FCascadeSource, ATarget, AValue);
end;

procedure TRadComboBoxProperties.DoCascade(ASource: TComponent; const AValue: Variant;
  AChain: TRadEditSlots);
var
  LChain: TRadEditSlots;
begin
  { Tuketicinin KENDI zinciri varsa o kazanir; yoksa bu Properties'inki (item). }
  LChain := AChain;
  if (LChain = nil) or (LChain.FilledCount = 0) then
    LChain := FSlots;
  { Tekrar-giris korumasi ve isleyici kapisinin NEDEN kalktigi:
    bkz. TRadLookupComboBoxProperties.DoCascade. }
  if FCascading or (LChain.FilledCount = 0) then
    Exit;
  FCascading := True;
  FCascadeSource := ASource;
  try
    LChain.ForEach(CascadeOne, AValue);
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
  ActiveProperties.DoCascade(Self, EditValue, Properties.RadSetting.Controls);
end;

procedure TRadComboBox.DoInitPopup;
begin
  (* inherited'DAN ONCE: DoInitPopup liste penceresi kurulmadan calisir
     (cxDropDownEdit.pas:3256), burada doldurulan Items BU acilista gorunur.
     Published OnInitPopup KULLANILMAZ: repository varken iki kez tetiklenir
     (:3150 ve :3152) - acilis basina iki sorgu. *)
  if [csDestroying, csDesigning] * ComponentState = [] then
    ActiveProperties.FillItems(Self);
  inherited DoInitPopup;
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
  ActiveProperties.DoCascade(Self, EditValue, Properties.RadSetting.Controls);
end;

procedure TRadDBComboBox.DoInitPopup;
begin
  { Gerekce TRadComboBox.DoInitPopup'ta. Iki sinif kardes (ortak Rad atasi
    yok - bkz. sinif bildirimlerindeki not), tetik bu yuzden iki kez yazili. }
  if [csDestroying, csDesigning] * ComponentState = [] then
  begin
    if ActiveProperties.AEditOnPopup then
      RadEnterEditMode(Self);
    ActiveProperties.FillItems(Self);
  end;
  inherited DoInitPopup;
end;



{ TRadValueList }

constructor TRadValueList.Create(const ADelimiter: string; ACount: TFunc<Integer>;
  ANames, AValues: TFunc<Integer, string>);
begin
  inherited Create;
  FDelimiter := ADelimiter;
  FCount := ACount;
  FNames := ANames;
  FValues := AValues;
end;

function TRadValueList.Count: Integer;
begin
  Result := FCount();
end;

function TRadValueList.Name(AIndex: Integer): string;
begin
  if (AIndex < 0) or (AIndex >= Count) then
    Exit('');
  Result := FNames(AIndex);
end;

function TRadValueList.Value(AIndex: Integer): string;
begin
  if (AIndex < 0) or (AIndex >= Count) then
    Exit('');
  Result := FValues(AIndex);
  if Result = '' then
    Result := FNames(AIndex);
end;

function TRadValueList.HasValues: Boolean;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    if FValues(i) <> '' then
      Exit(True);
  Result := False;
end;

function TRadValueList.IndexOfValue(const AValue: string): Integer;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    if SameText(Value(i), AValue) then
      Exit(i);
  Result := -1;
end;

function TRadValueList.StatesOf(const AEditValue: TcxEditValue): TcxCheckStates;
var
  LPart: string;
  i, LIdx: Integer;
begin
  SetLength(Result, Count);
  for i := 0 to High(Result) do
    Result[i] := cbsUnchecked;
  if VarIsNull(AEditValue) or VarIsEmpty(AEditValue) then
    Exit;
  for LPart in VarToStr(AEditValue).Split([FDelimiter], TStringSplitOptions.ExcludeEmpty) do
  begin
    LIdx := IndexOfValue(Trim(LPart));
    if LIdx >= 0 then
      Result[LIdx] := cbsChecked;
  end;
end;

function TRadValueList.StatesOfValues(const AValues: array of string): TcxCheckStates;
var
  i, j: Integer;
begin
  SetLength(Result, Count);
  for i := 0 to High(Result) do
  begin
    Result[i] := cbsUnchecked;
    for j := Low(AValues) to High(AValues) do
      if SameText(Value(i), Trim(AValues[j])) then
      begin
        Result[i] := cbsChecked;
        Break;
      end;
  end;
end;

function TRadValueList.ValuesOfStates(const AStates: TcxCheckStates): TArray<string>;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to High(AStates) do
    if AStates[i] = cbsChecked then
      Result := Result + [Value(i)];
end;

function TRadValueList.Join(const AStates: TcxCheckStates): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(AStates) do
    if AStates[i] = cbsChecked then
    begin
      if Result <> '' then
        Result := Result + FDelimiter;
      Result := Result + Value(i);
    end;
  if FWrap and (Result <> '') then
    Result := FDelimiter + Result + FDelimiter;   { okuma tarafi (StatesOf) bos parcalari zaten atar }
end;

function TRadValueList.InClause(const AField: string; const AValues: TArray<string>): string;
var
  LValue: string;
begin
  Result := '';
  if Length(AValues) = 0 then
    Exit;
  for LValue in AValues do
  begin
    if Result <> '' then
      Result := Result + ',';
    Result := Result + '''' + StringReplace(LValue, '''', '''''', [rfReplaceAll]) + '''';
  end;
  Result := AField + ' in (' + Result + ')';
end;

function TRadValueList.Warning: string;

  procedure Ekle(const AText: string);
  begin
    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result + AText;
  end;

var
  i, j: Integer;
  LValue: string;
begin
  Result := '';
  for i := 0 to Count - 1 do
  begin
    LValue := Value(i);
    if (FDelimiter <> '') and (Pos(FDelimiter, LValue) > 0) then
      Ekle(Format('Items: "%s" degeri ayraci (%s) iceriyor; EditValue''da ' +
        'ikiye bolunur ve hic eslesmez.', [LValue, FDelimiter]));
    for j := 0 to i - 1 do
      if SameText(Value(j), LValue) then
      begin
        Ekle(Format('Items: "%s" degeri iki item''da (%s, %s); ikincisi ' +
          'hic secilemez, EditValue hep birincisini gosterir.',
          [LValue, Name(j), Name(i)]));
        Break;
      end;
  end;
end;

function TRadValueList.FieldWarning(const AName: string; AField: TField): string;
var
  LNeeded, i: Integer;
begin
  Result := '';
  if (Count = 0) or (AField = nil) then
    Exit;
  if not (AField.DataType in [ftString, ftWideString, ftMemo, ftWideMemo]) then
    Exit(Format('%s: bagli alan "%s" metin degil (%s); EditValue ''%s'' gibi bir ' +
      'metindir, alana yazilamaz.', [AName, AField.FieldName,
      GetEnumName(TypeInfo(TFieldType), Ord(AField.DataType)), Value(0)]));
  if AField.Size <= 0 then
    Exit;
  LNeeded := Length(FDelimiter) * (Count - 1);
  for i := 0 to Count - 1 do
    Inc(LNeeded, Length(Value(i)));
  if AField.Size < LNeeded then
    Result := Format('%s: "%s" alani %d karakter; tum degerler secilince %d gerekir ' +
      '- kayit kesilir ya da hata verir.', [AName, AField.FieldName,
      AField.Size, LNeeded]);
end;

{ TRadCheckComboBoxItem }

procedure TRadCheckComboBoxItem.SetValue(const AValue: string);
begin
  if FValue = AValue then
    Exit;
  FValue := AValue;
  Changed(False);
end;

procedure TRadCheckComboBoxItem.Assign(Source: TPersistent);
begin
  inherited Assign(Source);
  if Source is TRadCheckComboBoxItem then
    Value := TRadCheckComboBoxItem(Source).Value;
end;

function TRadCheckComboBoxItem.EffectiveValue: string;
begin
  if FValue <> '' then
    Result := FValue
  else
    Result := Description;
end;

{ TRadCheckComboBoxItems }

function TRadCheckComboBoxItems.GetItem(AIndex: Integer): TRadCheckComboBoxItem;
begin
  Result := TRadCheckComboBoxItem(inherited Items[AIndex]);
end;

procedure TRadCheckComboBoxItems.SetItem(AIndex: Integer; const AValue: TRadCheckComboBoxItem);
begin
  GetItem(AIndex).Assign(AValue);
end;

procedure TRadCheckComboBoxItems.Update(Item: TCollectionItem);
begin
  if not IsDestroying and (OwningProperties is TRadCheckComboBoxProperties) then
    TRadCheckComboBoxProperties(OwningProperties).SyncBaseItems;
  inherited Update(Item);
end;

function TRadCheckComboBoxItems.Add: TRadCheckComboBoxItem;
begin
  Result := TRadCheckComboBoxItem(inherited Add);
end;

function TRadCheckComboBoxItems.AddItem(const ADescription, AValue: string): TRadCheckComboBoxItem;
begin
  BeginUpdate;
  try
    Result := Add;
    Result.Description := ADescription;
    Result.Value := AValue;
  finally
    EndUpdate;
  end;
end;

function TRadCheckComboBoxItems.IndexOfValue(const AValue: string): Integer;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    if SameText(Items[i].EffectiveValue, AValue) then
      Exit(i);
  Result := -1;
end;

function TRadCheckComboBoxItems.HasValues: Boolean;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    if Items[i].Value <> '' then
      Exit(True);
  Result := False;
end;

{ TRadCheckComboBoxProperties }

constructor TRadCheckComboBoxProperties.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner);
  FRadSetting := TcxRadSetting.Create(Self);
  FItems := TRadCheckComboBoxItems.Create(Self, TRadCheckComboBoxItem);
  FValues := TRadValueList.Create(cxCheckComboValuesDelimiter,   { ';' }
    function: Integer begin Result := FItems.Count; end,
    function(AIndex: Integer): string begin Result := FItems[AIndex].Description; end,
    function(AIndex: Integer): string begin Result := FItems[AIndex].Value; end);
  { published 'default cvfStatesString' ile AYNI olmak zorunda (kit kurali). }
  EditValueFormat := cvfStatesString;
end;

destructor TRadCheckComboBoxProperties.Destroy;
begin
  FSyncing := True;   { yikimda tabana aynalama yok }
  FreeAndNil(FValues);
  FreeAndNil(FItems);
  FreeAndNil(FRadSetting);
  inherited Destroy;
end;

procedure TRadCheckComboBoxProperties.SetRadSetting(const AValue: TcxRadSetting);
begin
  FRadSetting.Assign(AValue);
end;

procedure TRadCheckComboBoxProperties.SetItems(const AValue: TRadCheckComboBoxItems);
begin
  FItems.Assign(AValue);
end;

class function TRadCheckComboBoxProperties.GetContainerClass: TcxContainerClass;
begin
  Result := TRadCheckComboBox;
end;

function TRadCheckComboBoxProperties.GetValueDelimiter: string;
begin
  Result := FValues.Delimiter;
end;

procedure TRadCheckComboBoxProperties.SetValueDelimiter(const AValue: string);
begin
  if FValues.Delimiter = AValue then
    Exit;
  FValues.Delimiter := AValue;
  Changed;
end;

function TRadCheckComboBoxProperties.IsValueDelimiterStored: Boolean;
begin
  Result := FValues.Delimiter <> cxCheckComboValuesDelimiter;
end;

function TRadCheckComboBoxProperties.GetValueWrap: Boolean;
begin
  Result := FValues.Wrap;
end;

procedure TRadCheckComboBoxProperties.SetValueWrap(const AValue: Boolean);
begin
  if FValues.Wrap = AValue then
    Exit;
  FValues.Wrap := AValue;
  Changed;
end;

procedure TRadCheckComboBoxProperties.SyncBaseItems;
var
  LBase: TcxCheckComboBoxItems;
  i: Integer;
begin
  if FSyncing then
    Exit;
  FSyncing := True;
  try
    LBase := inherited Items;
    LBase.BeginUpdate;
    try
      while LBase.Count > FItems.Count do
        LBase.Delete(LBase.Count - 1);
      while LBase.Count < FItems.Count do
        LBase.Add;
      for i := 0 to FItems.Count - 1 do
        LBase[i].Assign(FItems[i]);
    finally
      LBase.EndUpdate;
    end;
  finally
    FSyncing := False;
  end;
end;

function TRadCheckComboBoxProperties.ValueMode: Boolean;
begin
  (* Olaylar atanmissa TABAN onlari cagirir (cxCheckComboBox.pas:1354, :1383);
     override'lar inherited'a duserek ayni sozlesmeyi korur. *)
  Result := FItems.HasValues and
    not Assigned(OnStatesToEditValue) and not Assigned(OnEditValueToStates);
end;

procedure TRadCheckComboBoxProperties.DoAssign(AProperties: TcxCustomEditProperties);
begin
  inherited DoAssign(AProperties);
  if not (AProperties is TRadCheckComboBoxProperties) then
    Exit;
  FRadSetting.Assign(TRadCheckComboBoxProperties(AProperties).FRadSetting);
  FItems.Assign(TRadCheckComboBoxProperties(AProperties).FItems);
  FValues.Delimiter := TRadCheckComboBoxProperties(AProperties).FValues.Delimiter;
  FValues.Wrap := TRadCheckComboBoxProperties(AProperties).FValues.Wrap;
end;

procedure TRadCheckComboBoxProperties.CalculateCheckStatesByEditValue(Sender: TObject;
  const AEditValue: TcxEditValue; var ACheckStates: TcxCheckStates);
begin
  if ValueMode then
    ACheckStates := FValues.StatesOf(AEditValue)
  else
    inherited CalculateCheckStatesByEditValue(Sender, AEditValue, ACheckStates);
end;

function TRadCheckComboBoxProperties.CalculateEditValueByCheckStates(Sender: TObject;
  const ACheckStates: TcxCheckStates): TcxEditValue;
begin
  if ValueMode then
    Result := FValues.Join(ACheckStates)
  else
    Result := inherited CalculateEditValueByCheckStates(Sender, ACheckStates);
end;

function TRadCheckComboBoxProperties.ValuesOf(const AEditValue: TcxEditValue): TArray<string>;
begin
  Result := nil;
  if ValueMode then
    Result := FValues.ValuesOfStates(FValues.StatesOf(AEditValue));
end;

function TRadCheckComboBoxProperties.EditValueOf(const AValues: array of string): TcxEditValue;
begin
  Result := CalculateEditValueByCheckStates(nil, FValues.StatesOfValues(AValues));
end;

function TRadCheckComboBoxProperties.ValuesIn(const AField: string;
  const AEditValue: TcxEditValue): string;
begin
  Result := FValues.InClause(AField, ValuesOf(AEditValue));
end;

function TRadCheckComboBoxProperties.CheckWarning: string;
begin
  Result := '';
  if not FItems.HasValues then
    Exit;
  Result := FValues.Warning;
  if Assigned(OnStatesToEditValue) or Assigned(OnEditValueToStates) then
  begin
    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result + 'Items''ta Value var ama OnStatesToEditValue/OnEditValueToStates atanmis: ' +
      'olay kazanir, deger kipi (AValues, AValuesIn) devre disi.';
  end;
end;

function TRadCheckComboBoxProperties.FieldWarning(AConsumer: TComponent): string;
begin
  Result := FValues.FieldWarning(AConsumer.Name, _FieldOf(AConsumer));
end;

{ TRadCheckListBoxItem }

constructor TRadCheckListBoxItem.Create(Collection: TCollection);
begin
  inherited Create(Collection);
  FEnabled := True;
  FImageIndex := -1;
end;

function TRadCheckListBoxItem.GetDisplayName: string;
begin
  Result := FText;
  if Result = '' then
    Result := inherited GetDisplayName;
end;

procedure TRadCheckListBoxItem.SetText(const AValue: TCaption);
begin
  if FText = AValue then
    Exit;
  FText := AValue;
  Changed(False);
end;

procedure TRadCheckListBoxItem.SetValue(const AValue: string);
begin
  if FValue = AValue then
    Exit;
  FValue := AValue;
  Changed(False);
end;

procedure TRadCheckListBoxItem.SetEnabled(AValue: Boolean);
begin
  if FEnabled = AValue then
    Exit;
  FEnabled := AValue;
  Changed(False);
end;

procedure TRadCheckListBoxItem.SetImageIndex(AValue: TcxImageIndex);
begin
  if FImageIndex = AValue then
    Exit;
  FImageIndex := AValue;
  Changed(False);
end;

procedure TRadCheckListBoxItem.Assign(Source: TPersistent);
begin
  if Source is TRadCheckListBoxItem then
  begin
    FText := TRadCheckListBoxItem(Source).FText;
    FValue := TRadCheckListBoxItem(Source).FValue;
    FEnabled := TRadCheckListBoxItem(Source).FEnabled;
    FImageIndex := TRadCheckListBoxItem(Source).FImageIndex;
    FTag := TRadCheckListBoxItem(Source).FTag;
    Changed(False);
  end
  else
    inherited Assign(Source);
end;

function TRadCheckListBoxItem.EffectiveValue: string;
begin
  if FValue <> '' then
    Result := FValue
  else
    Result := FText;
end;

{ TRadCheckListBoxItems }

function TRadCheckListBoxItems.GetItem(AIndex: Integer): TRadCheckListBoxItem;
begin
  Result := TRadCheckListBoxItem(inherited Items[AIndex]);
end;

procedure TRadCheckListBoxItems.SetItem(AIndex: Integer; const AValue: TRadCheckListBoxItem);
begin
  GetItem(AIndex).Assign(AValue);
end;

procedure TRadCheckListBoxItems.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if FCore <> nil then
    FCore.SyncBaseItems;
end;

function TRadCheckListBoxItems.Add: TRadCheckListBoxItem;
begin
  Result := TRadCheckListBoxItem(inherited Add);
end;

function TRadCheckListBoxItems.AddItem(const AText, AValue: string): TRadCheckListBoxItem;
begin
  BeginUpdate;
  try
    Result := Add;
    Result.Text := AText;
    Result.Value := AValue;
  finally
    EndUpdate;
  end;
end;

function TRadCheckListBoxItems.IndexOfValue(const AValue: string): Integer;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    if SameText(Items[i].EffectiveValue, AValue) then
      Exit(i);
  Result := -1;
end;

function TRadCheckListBoxItems.HasValues: Boolean;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    if Items[i].Value <> '' then
      Exit(True);
  Result := False;
end;

{ TRadCheckListCore }

type
  { Korunmus olaylara ve Items'a ayni birimden erisim. }
  TRadListAccess = class(TcxCustomCheckListBox);

constructor TRadCheckListCore.Create(AControl: TcxCustomCheckListBox);
begin
  inherited Create;
  FControl := AControl;
  FItems := TRadCheckListBoxItems.Create(AControl, TRadCheckListBoxItem);
  FItems.FCore := Self;
  FValues := TRadValueList.Create(cxCheckComboValuesDelimiter,
    function: Integer begin Result := FItems.Count; end,
    function(AIndex: Integer): string begin Result := FItems[AIndex].Text; end,
    function(AIndex: Integer): string begin Result := FItems[AIndex].Value; end);
end;

destructor TRadCheckListCore.Destroy;
begin
  FSyncing := True;
  if OwnsStatesEvent then
    TRadListAccess(FControl).OnCheckStatesToEditValue := nil;
  if OwnsValueEvent then
    TRadListAccess(FControl).OnEditValueToCheckStates := nil;
  FItems.FCore := nil;
  FreeAndNil(FItems);
  FreeAndNil(FValues);
  inherited Destroy;
end;

procedure TRadCheckListCore.SetItems(const AValue: TRadCheckListBoxItems);
begin
  FItems.Assign(AValue);
end;

function TRadCheckListCore.OwnsStatesEvent: Boolean;
begin
  Result := TMethod(TRadListAccess(FControl).OnCheckStatesToEditValue).Data = Self;
end;

function TRadCheckListCore.OwnsValueEvent: Boolean;
begin
  Result := TMethod(TRadListAccess(FControl).OnEditValueToCheckStates).Data = Self;
end;

procedure TRadCheckListCore.Rebind;
var
  LList: TRadListAccess;
begin
  LList := TRadListAccess(FControl);
  if FItems.HasValues then
  begin
    { Kullanicinin kendi olayi varsa dokunmayiz; CheckWarning bildirir. }
    if not Assigned(LList.OnCheckStatesToEditValue) then
      LList.OnCheckStatesToEditValue := StatesToValue;
    if not Assigned(LList.OnEditValueToCheckStates) then
      LList.OnEditValueToCheckStates := ValueToStates;
  end
  else
  begin
    if OwnsStatesEvent then
      LList.OnCheckStatesToEditValue := nil;
    if OwnsValueEvent then
      LList.OnEditValueToCheckStates := nil;
  end;
end;

// Bizim Items -> kontrolun stok Items'i; indeks bazli, State korunur.
procedure TRadCheckListCore.SyncBaseItems;
var
  LBase: TcxCheckListBoxItems;
  i: Integer;
begin
  if FSyncing then
    Exit;
  FSyncing := True;
  try
    LBase := TRadListAccess(FControl).Items;
    LBase.BeginUpdate;
    try
      while LBase.Count > FItems.Count do
        LBase.Delete(LBase.Count - 1);
      while LBase.Count < FItems.Count do
        LBase.Add;
      for i := 0 to FItems.Count - 1 do
      begin
        LBase[i].Text := FItems[i].Text;
        LBase[i].Enabled := FItems[i].Enabled;
        LBase[i].ImageIndex := FItems[i].ImageIndex;
        LBase[i].Tag := FItems[i].Tag;
      end;
    finally
      LBase.EndUpdate;
    end;
    Rebind;
  finally
    FSyncing := False;
  end;
end;

function TRadCheckListCore.ValueMode: Boolean;
begin
  Result := FItems.HasValues and OwnsStatesEvent and OwnsValueEvent;
end;

procedure TRadCheckListCore.StatesToValue(Sender: TObject;
  const ACheckStates: TcxCheckStates; out AEditValue: TcxEditValue);
begin
  AEditValue := FValues.Join(ACheckStates);
end;

procedure TRadCheckListCore.ValueToStates(Sender: TObject;
  const AEditValue: TcxEditValue; var ACheckStates: TcxCheckStates);
begin
  ACheckStates := FValues.StatesOf(AEditValue);
end;

function TRadCheckListCore.ValuesOf: TArray<string>;
begin
  Result := nil;
  if ValueMode then
    Result := FValues.ValuesOfStates(FValues.StatesOf(TRadListAccess(FControl).EditValue));
end;

function TRadCheckListCore.EditValueOf(const AValues: array of string): TcxEditValue;
begin
  Result := FValues.Join(FValues.StatesOfValues(AValues));
end;

function TRadCheckListCore.ValuesIn(const AField: string): string;
begin
  Result := FValues.InClause(AField, ValuesOf);
end;

function TRadCheckListCore.CheckWarning: string;
begin
  Result := '';
  if not FItems.HasValues then
    Exit;
  Result := FValues.Warning;
  if not ValueMode then
  begin
    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result + 'Items''ta Value var ama OnCheckStatesToEditValue/' +
      'OnEditValueToCheckStates atanmis: olay kazanir, deger kipi devre disi.';
  end;
end;

{ TRadCheckListBox }

constructor TRadCheckListBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCore := TRadCheckListCore.Create(Self);
  FRadSetting := TcxRadSetting.Create(Self);
  { published 'default cvfStatesString' ile AYNI olmak zorunda. }
  EditValueFormat := cvfStatesString;
end;

destructor TRadCheckListBox.Destroy;
begin
  FreeAndNil(FRadSetting);
  FreeAndNil(FCore);
  inherited Destroy;
end;

function TRadCheckListBox.GetHasValues: Boolean;
begin
  Result := Length(AValues) > 0;
end;

function TRadCheckListBox.GetItems: TRadCheckListBoxItems;
begin
  Result := FCore.Items;
end;

function TRadCheckListBox.GetValueDelimiter: string;
begin
  Result := FCore.List.Delimiter;
end;

function TRadCheckListBox.GetValues: TArray<string>;
begin
  Result := FCore.ValuesOf;
end;

function TRadCheckListBox.IsValueDelimiterStored: Boolean;
begin
  Result := FCore.List.Delimiter <> cxCheckComboValuesDelimiter;
end;

procedure TRadCheckListBox.SetItems(const AValue: TRadCheckListBoxItems);
begin
  FCore.SetItems(AValue);
end;

procedure TRadCheckListBox.SetRadSetting(const AValue: TcxRadSetting);
begin
  FRadSetting.Assign(AValue);
end;

procedure TRadCheckListBox.SetValueDelimiter(const AValue: string);
begin
  FCore.List.Delimiter := AValue;
end;

procedure TRadCheckListBox.SetValues(const AValues: TArray<string>);
begin
  EditValue := FCore.EditValueOf(AValues);
end;

function TRadCheckListBox.AValuesIn(const AField: string): string;
begin
  Result := FCore.ValuesIn(AField);
end;

function TRadCheckListBox.CheckWarning: string;
begin
  Result := FCore.CheckWarning;
end;

{ TRadDBCheckListBox }

constructor TRadDBCheckListBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCore := TRadCheckListCore.Create(Self);
  FRadSetting := TcxRadSetting.Create(Self);
  EditValueFormat := cvfStatesString;
end;

destructor TRadDBCheckListBox.Destroy;
begin
  FreeAndNil(FRadSetting);
  FreeAndNil(FCore);
  inherited Destroy;
end;

function TRadDBCheckListBox.GetHasValues: Boolean;
begin
  Result := Length(AValues) > 0;
end;

function TRadDBCheckListBox.GetItems: TRadCheckListBoxItems;
begin
  Result := FCore.Items;
end;

function TRadDBCheckListBox.GetValueDelimiter: string;
begin
  Result := FCore.List.Delimiter;
end;

function TRadDBCheckListBox.GetValues: TArray<string>;
begin
  Result := FCore.ValuesOf;
end;

function TRadDBCheckListBox.IsValueDelimiterStored: Boolean;
begin
  Result := FCore.List.Delimiter <> cxCheckComboValuesDelimiter;
end;

procedure TRadDBCheckListBox.SetItems(const AValue: TRadCheckListBoxItems);
begin
  FCore.SetItems(AValue);
end;

procedure TRadDBCheckListBox.SetRadSetting(const AValue: TcxRadSetting);
begin
  FRadSetting.Assign(AValue);
end;

procedure TRadDBCheckListBox.SetValueDelimiter(const AValue: string);
begin
  FCore.List.Delimiter := AValue;
end;

procedure TRadDBCheckListBox.SetValues(const AValues: TArray<string>);
begin
  EditValue := FCore.EditValueOf(AValues);
end;

function TRadDBCheckListBox.AValuesIn(const AField: string): string;
begin
  Result := FCore.ValuesIn(AField);
end;

function TRadDBCheckListBox.CheckWarning: string;
begin
  Result := FCore.CheckWarning;
end;

function TRadDBCheckListBox.FieldWarning: string;
var
  LField: TField;
begin
  LField := nil;
  if (DataBinding.DataSource <> nil) and (DataBinding.DataSource.DataSet <> nil) then
    LField := DataBinding.DataSource.DataSet.FindField(DataBinding.DataField);
  Result := FCore.List.FieldWarning(Name, LField);
end;

{ TRadCheckComboBoxRepository }

class function TRadCheckComboBoxRepository.GetEditPropertiesClass: TcxCustomEditPropertiesClass;
begin
  Result := TRadCheckComboBoxProperties;
end;

function TRadCheckComboBoxRepository.GetProperties: TRadCheckComboBoxProperties;
begin
  Result := inherited Properties as TRadCheckComboBoxProperties;
end;

procedure TRadCheckComboBoxRepository.SetProperties(Value: TRadCheckComboBoxProperties);
begin
  inherited Properties := Value;
end;

{ TRadCheckComboBox }

class function TRadCheckComboBox.GetPropertiesClass: TcxCustomEditPropertiesClass;
begin
  Result := TRadCheckComboBoxProperties;
end;

function TRadCheckComboBox.GetActiveProperties: TRadCheckComboBoxProperties;
begin
  Result := TRadCheckComboBoxProperties(InternalGetActiveProperties);
end;

function TRadCheckComboBox.GetProperties: TRadCheckComboBoxProperties;
begin
  Result := TRadCheckComboBoxProperties(inherited Properties);
end;

procedure TRadCheckComboBox.SetProperties(Value: TRadCheckComboBoxProperties);
begin
  Properties.Assign(Value);
end;

function TRadCheckComboBox.GetValues: TArray<string>;
begin
  Result := ActiveProperties.ValuesOf(EditValue);
end;

procedure TRadCheckComboBox.SetValues(const AValues: TArray<string>);
begin
  EditValue := ActiveProperties.EditValueOf(AValues);
end;

function TRadCheckComboBox.GetHasValues: Boolean;
begin
  Result := Length(AValues) > 0;
end;

function TRadCheckComboBox.AValuesIn(const AField: string): string;
begin
  Result := ActiveProperties.ValuesIn(AField, EditValue);
end;

{ TRadDBCheckComboBox }

type
  TRadDBBindingAccess = class(TcxDBEditDataBinding);

class function TRadDBCheckComboBox.GetPropertiesClass: TcxCustomEditPropertiesClass;
begin
  Result := TRadCheckComboBoxProperties;
end;

function TRadDBCheckComboBox.GetActiveProperties: TRadCheckComboBoxProperties;
begin
  Result := TRadCheckComboBoxProperties(InternalGetActiveProperties);
end;

function TRadDBCheckComboBox.GetProperties: TRadCheckComboBoxProperties;
begin
  Result := TRadCheckComboBoxProperties(inherited Properties);
end;

procedure TRadDBCheckComboBox.SetProperties(Value: TRadCheckComboBoxProperties);
begin
  Properties.Assign(Value);
end;

function TRadDBCheckComboBox.GetValues: TArray<string>;
begin
  Result := ActiveProperties.ValuesOf(EditValue);
end;

procedure TRadDBCheckComboBox.SetValues(const AValues: TArray<string>);
begin
  (* Kodla atanan deger alana GITMEZDI: DB editor yalnizca baglantisi
     "duzenleniyor + degisti" iken yazar (CanPostEditorValue, cxDBEdit.pas:1980)
     ve EditValue atamasi bunu isaretlemez - PostEditValue sessizce hicbir sey
     yapmiyordu (CheckComboTest B03, olculdu). SetEditMode kaydi duzenlemeye
     alir ve baglantiyi degisti isaretler (:2182-2196); yazma yine
     PostEditValue'ya ya da odak cikisina kalir. Alan yoksa / salt okunursa
     False doner ve deger yalnizca editorde kalir. *)
  { SetEditMode torunda protected'a cekilmis; erisim sinifi (birimin deyimi). }
  TRadDBBindingAccess(DataBinding).SetEditMode;
  EditValue := ActiveProperties.EditValueOf(AValues);
end;

function TRadDBCheckComboBox.GetHasValues: Boolean;
begin
  Result := Length(AValues) > 0;
end;

function TRadDBCheckComboBox.AValuesIn(const AField: string): string;
begin
  Result := ActiveProperties.ValuesIn(AField, EditValue);
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
  LDelay := ActiveProperties.ASearchDelay;
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
  { Kaynak: geciktiriciyi calistiran editorun kendisi. }
  ActiveProperties.TimedSearch(Self, EditingText);
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
  ActiveProperties.DoCascade(Self, EditValue, False, Properties.RadSetting.Controls);
end;

procedure TRadCustomLookupComboBox.FilterNow;
begin
  if csDestroying in ComponentState then
    Exit;
  ActiveProperties.DoFilter(Self);
end;

procedure TRadCustomLookupComboBox.DoInitPopup;
begin
  { Tasarim zamaninda IDE icinde sorgu calistirmayiz - DoEditValueChanged ile
    ayni gerekce. csLoading BILINCLI olarak listede yok: yukleme sirasinda
    acilir liste zaten acilmaz.
    ActiveProperties, Properties DEGIL: repository item uzerinden paylasilan
    Properties kullaniliyorsa dogru ornek odur. }
  if ActiveProperties.AEditOnPopup and
     ([csDestroying, csDesigning] * ComponentState = []) then
    RadEnterEditMode(Self);
  if ActiveProperties.AFilterOnPopup and
     ([csDestroying, csDesigning] * ComponentState = []) then
    ActiveProperties.DoFilter(Self);
  inherited DoInitPopup;
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
  ActiveProperties.DoCascade(Self, EditValue, FDataChanging > 0,
    Properties.RadSetting.Controls);
end;

type
  (* Kayit degisimini kullanici/kod degisikliginden AYIRT etmenin tek yeri.
     TcxDBEditDataBinding.DataChanged sanal ve protected (cxDBEdit.pas:192);
     gezinmede EditValue'yu burada yeniden atiyor (:2279). Sinif
     implementation'da: public API degil, yalnizca GetDataBindingClass
     tarafindan uretilir. *)
  TRadDBLookupEditDataBinding = class(TcxDBLookupEditDataBinding)
  protected
    procedure DataChanged; override;
  end;

procedure TRadDBLookupEditDataBinding.DataChanged;
var
  LEd: TRadCustomLookupComboBox;
begin
  if Edit is TRadCustomLookupComboBox then
    LEd := TRadCustomLookupComboBox(Edit)
  else
    LEd := nil;
  if LEd <> nil then
    Inc(LEd.FDataChanging);
  try
    inherited DataChanged;
  finally
    if LEd <> nil then
      Dec(LEd.FDataChanging);
  end;
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
  Result := TRadDBLookupEditDataBinding;
end;

procedure TRadDBLookupComboBox.SetDataBinding(Value: TcxDBTextEditDataBinding);
begin
  FDataBinding.Assign(Value);
end;


{ TRadLookupComboBoxProperties }

constructor TRadLookupComboBoxProperties.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner);
  FRadSetting := TcxRadSetting.Create(Self);
  { Tutucular RadSetting'e ait; Master AYRI tutucuda (bkz. FMasterSlot). }
  FSlots := FRadSetting.Controls;
  FMasterSlot := FRadSetting.MasterHolder;
  FSearchDelay      := 500;
  FMinSearchLength  := 3;
  { default direktifi ile AYNI olmak zorunda. }
  FFilterOnPopup    := True;
end;

destructor TRadLookupComboBoxProperties.Destroy;
begin
  FSlots := nil;
  FMasterSlot := nil;
  FreeAndNil(FRadSetting);
  inherited Destroy;
end;

function TRadLookupComboBoxProperties.GetMaster: TComponent;
begin
  Result := FMasterSlot.Get(1);
end;

procedure TRadLookupComboBoxProperties.SetMaster(const AValue: TComponent);
begin
  { Tip ve dairesel master denetimi TcxRadSetting.SetMaster'dadir. }
  FRadSetting.Master := AValue;
end;

function TRadLookupComboBoxProperties.HasMaster: Boolean;
begin
  Result := FMasterSlot.Get(1) <> nil;
end;

function TRadLookupComboBoxProperties.GetSlot(AIndex: Integer): TComponent;
begin
  Result := FSlots.Get(AIndex);
end;

function TRadLookupComboBoxProperties.GetCascadeField: string;
begin
  Result := FRadSetting.Key;
end;

procedure TRadLookupComboBoxProperties.SetCascadeField(const AValue: string);
begin
  FRadSetting.Key := AValue;
end;

function TRadLookupComboBoxProperties.GetCascadeTag: Integer;
begin
  Result := FRadSetting.Tag;
end;

procedure TRadLookupComboBoxProperties.SetCascadeTag(const AValue: Integer);
begin
  FRadSetting.Tag := AValue;
end;

procedure TRadLookupComboBoxProperties.SetRadSetting(const AValue: TcxRadSetting);
begin
  FRadSetting.Assign(AValue);
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
  (* PUSH ARTIK BIR GECERSIZ KILMA SINYALIDIR, FILTRE DEGIL.
     "Degerim degisti, seninki artik gecersiz" - suzme isini hedefin KENDI
     pull'u yapar (AOnFilter, acilir liste acilirken).

     Push neden tamamen kaldirilmadi: saf pull, hedefin acilir listesi HIC
     acilmazsa bayat degeri duzeltemez - hedef tutarsiz bir anahtari eski
     metniyle gostermeye devam eder. Bu deligi ancak kaynaktan gonderilen bir
     sinyal kapatir. *)
  LTarget := TargetProperties(ATarget);
  if LTarget <> nil then
    LTarget.ResetCaches;   { iki katman: kitin + DevExpress'in }

  (* Deger VERIDEN geldiyse (kayitta gezinme) hedef TEMIZLENMEZ: hedef kendi
     degerini ayni kayittan alir. Temizlenseydi - OLCULDU, DbNavTest D01 -
     hedef editor, kayit alani doluyken BOS gorunuyordu: kaskad hedefin kendi
     tazelemesinden SONRA calisabiliyor. Gecersiz kilma (yukaridaki onbellek
     sifirlama) ve AOnCascade yine calisir - hedefin listesi eski master'a
     gore suzulmustu. *)
  if FClearTargets and not FCascadeFromData then
    ClearTarget(ATarget);

  { Olay ARTIK KOSULLU: atanmamis olmasi NORMALDIR - pull dunyasinda kural. }
  if Assigned(FCascadeEvent) then
    FCascadeEvent(Self, FCascadeSource, ATarget, AValue);
end;

procedure TRadLookupComboBoxProperties.ClearTarget(ATarget: TComponent);
begin
  (* Yalnizca editor hedefleri. Grid KOLONUNUN degeri satira gore degisir;
     kolon duzeyinde "temizlemek" tum sutunu bozmak olurdu. *)
  if ATarget is TcxCustomEdit then
    TcxCustomEdit(ATarget).EditValue := Null;
end;

function TRadLookupComboBoxProperties.CacheAllowed: Boolean;
var
  LOwner: TComponent;
begin
  (* RADDEV-002. Cozulmus-anahtar ve metin onbellekleri Properties'te durur,
     yani bir RepositoryItem'a bagli TUM tuketiciler tarafindan PAYLASILIR.

     Kitin kendi deseni (LiveLookupTest M5) tam da bunu yapiyor: tek isleyici,
     paylasilan item, tuketici-basina TUR - isleyici ASource'un KENDI
     Properties'inden turu okuyup AYNI dataset'ten FARKLI satirlari cekiyor.
     O durumda ayni sayisal anahtar iki tuketici icin farkli kaydi gosterir;
     onbellek acik kalirsa ikinci tuketicinin OnLocate'i BASTIRILIR ve
     birincinin metni yeniden kullanilir. Sessiz, yanlis metin.

     Cizim yolunda tuketici KIMLIGI YOKTUR (GetDisplayLookupText -> DoLocate
     ASource olarak nil alir), dolayisiyla onbellegi tuketici basina ayirmak
     MUMKUN DEGIL. Yapilabilecek dogru sey, belirsizligin var oldugu TEK
     durumda onbellegi kapatmak: Properties paylasilan bir item'a ait VE
     birden fazla tuketicisi var.

     Bedeli dar: tek tuketicili item'lar ve editorun/kolonun KENDI
     Properties'i etkilenmez, yani cizim yolundaki 50-satir-1-sorgu kazanci
     yaygin durumda korunur. *)
  LOwner := GetOwnerComponent(Self);
  Result := not ((LOwner is TRadEditRepositoryItem) and
                 (TRadEditRepositoryItem(LOwner).ConsumerCount > 1));
end;

procedure TRadLookupComboBoxProperties.ResetDisplayCache;
begin
  (* DevExpress'in anahtar->metin onbellegi: FLookupList
     (cxDBLookupEdit.pas:71). YALNIZCA GridMode=True iken vardir ve
     GetDisplayLookupText'in GridMode dalinda hem OKUNUR hem YAZILIR
     (:604-605 ve :621).

     ! LISTE DATASET'INI KAPATIP ACMAK BU ONBELLEGI BOSALTMAZ. Tek bosaltan
       CheckLookupList (:419-425). Yani pull listeyi yeni bir master
       degeriyle yeniden yuklese bile, hedef ESKI metni gostermeye devam
       ederdi - sessiz, hicbir uyari uretmeyen bir hata.

     CheckLookupList protected ve virtual DEGIL; torun oldugumuz icin
     dogrudan cagirabiliyoruz. RefreshNonShareable de ona ulasir ama ayrica
     CheckLookup + CheckLookupColumn kosturur - gecersiz kilmanin ihtiyaci
     olmayan is. GridMode=False iken FLookupList nil'dir ve cagri ucuz bir
     islemsizliktir; DataController nil denetimi saticinin kendi govdesinde. *)
  CheckLookupList;
end;

procedure TRadLookupComboBoxProperties.ResetCaches;
begin
  ResetLocateCache;    { kitin kendi FHasLastKey / FHasText onbellekleri }
  ResetDisplayCache;   { DevExpress'in FLookupList'i }
end;

procedure TRadLookupComboBoxProperties.ApplyAutoFilter(ADataSet: TDataSet;
  const AValue: Variant; AOpen: Boolean);
var
  LLiteral: string;
  LBos: Boolean;
begin
  (* AOpen = False demek: dataset'i YENIDEN ACMA, yalnizca filtreyi kur.
     Cagiran (DoFilter) bir AOnSearch isleyicisi oldugunu biliyorsa acmayi
     ONA devreder - boylece bir acilista tek sorgu kosar, iki degil. *)
  if ADataSet = nil then
    raise ERadDev.Create(
      'AAutoFilter acik ama ListSource/dataset yok: suzecek bir sey bulunamadi.');
  if FMasterField = '' then
    raise ERadDev.Create(
      'AAutoFilter acik ama AMasterField bos: hangi parametrenin/alanin ' +
      'suzulecegi bilinmiyor.');

  (* MASTER BOSSA LISTE DE BOS: kaskadda ulke secilmeden sehir
     listelenmemeli. Iki kip bunu FARKLI yoldan yapiyor ve fark onemli:

       afServerParam -> parametre NULL'a cekilir. Sorgu "ulke_id = null"
         olur ve sifir satir doner. Dataset ACIK kalir, dolayisiyla arama
         isleyicisi sonradan yeniden acsa bile master suzgeci HALA gecerlidir.
       afClientFilter -> dataset KAPATILIR. Kurulacak bir parametre yok;
         "hicbir satir" ifadesini filtre metniyle kurmak ancak uydurma bir
         ifadeyle olurdu.

     Eskiden ikisi de kapatiyordu. Bu, arama isleyicisine devredilen bir
     acilisla birlestiginde SESSIZ bir hata uretirdi: master bossa dataset
     kapanir, sonra arama onu master suzgeci OLMADAN yeniden acar ve liste
     BUTUN satirlari gosterirdi. *)
  LBos := VarIsNull(AValue) or VarIsEmpty(AValue) or (VarToStr(AValue) = '');
  if LBos and (FAutoFilter = afClientFilter) then
  begin
    ADataSet.Close;
    Exit;
  end;

  case FAutoFilter of
    afServerParam:
      begin
        (* Sunucu tarafli. UniDAC'e baglidir - bu birimin implementation'i
           zaten DBAccess kullaniyor. Baska bir saticinin dataset'i icin
           afClientFilter'i ya da AOnFilter'i kullanin. *)
        if not (ADataSet is TCustomDADataSet) then
          raise ERadDev.CreateFmt(
            'AAutoFilter = afServerParam, parametreli bir UniDAC dataset''i ister ' +
            '(TCustomDADataSet); liste dataset''i %s. afClientFilter kipini ya da ' +
            'AOnFilter''i kullanin.', [ADataSet.ClassName]);
        if AOpen then
          ADataSet.Close;
        { ParamByName yoksa istisna atar - sessiz yanlis suzmeden iyidir. }
        if LBos then
          TCustomDADataSet(ADataSet).ParamByName(FMasterField).Clear
        else
          TCustomDADataSet(ADataSet).ParamByName(FMasterField).Value := AValue;
        if AOpen then
          ADataSet.Open;
      end;

    afClientFilter:
      begin
        (* Saticidan bagimsiz ama suzme ISTEMCI tarafinda: butun satirlar
           cekilir. Buyuk listelerde afServerParam tercih edilmelidir.

           Deger bicimi BILINCLI olarak dar: tamsayilar ciplak, digerleri
           tirnakli metin. Ondalik/tarih icin yerel ayrac ifadeyi SESSIZCE
           bozardi - o durumda AOnFilter yazilmalidir (property notuna bakin). *)
        case VarType(AValue) and varTypeMask of
          varSmallInt, varInteger, varShortInt, varByte, varWord,
          varLongWord, varInt64, varUInt64:
            LLiteral := VarToStr(AValue);
        else
          LLiteral := QuotedStr(VarToStr(AValue));
        end;
        ADataSet.Filtered := False;
        ADataSet.Filter := FMasterField + ' = ' + LLiteral;
        ADataSet.Filtered := True;
        { Filter/Filtered Close/Open boyunca korunur; acmayi arama isleyicisi
          devraldiysa suzgec yine de gecerli kalir. }
        if AOpen and not ADataSet.Active then
          ADataSet.Open;
      end;
  end;
end;

procedure TRadLookupComboBoxProperties.DoFilter(ASource: TComponent);
var
  LMaster: TComponent;
  LValue: Variant;
  LDS: TDataSet;
  LAramaAcacak: Boolean;
  LText, LTail: string;
begin
  LMaster := FMasterSlot.Get(1);
  { Otomatik kip acikken AOnFilter GEREKMEZ - pull'un bir isleyici yazmadan
    calisabilmesi bu ozelligin butun amaci. }
  if FFiltering or (LMaster = nil) or
     ((FAutoFilter = afNone) and not Assigned(FFilterEvent)) then
    Exit;

  (* Master'in degeri: help.Dev'deki _ValueOf HER IKI sekli de kabul eder -
     editor ise EditValue, grid KOLONU ise ODAKLI kaydin degeri. Kolonda
     odakli kayit yoksa UNASSIGNED doner (kolonun EditValue'su,
     cxGridCustomTableView.pas:13724; DxAuditTest G02). ApplyAutoFilter
     Null/Unassigned/bos metni ayni "bos master" sayar. Isleyiciye oldugu
     gibi geciyoruz, uydurma bir deger uretmiyoruz. *)
  LValue := _ValueOf(LMaster);

  { Isleyici liste dataset'ini kapatip acacak. Ayni dataset'i paylasan baska
    bir editorun cizim yolundan yeniden girmesini kesen mevcut mekanizma bu -
    bkz. DoSearch/DoLocate'teki ayni desen. }
  LDS := ListDataSet;
  if TRadBusyDataSets.IsBusy(LDS) then
  begin
    { Sessiz kalmiyoruz: PullWarning bunu bildirir. }
    Inc(FSkippedFilters);
    Exit;
  end;

  (* TEK YENIDEN ACIS.

     Bir AOnSearch isleyicisi varsa acmayi ONA devrediyoruz: ApplyAutoFilter
     yalnizca parametreyi/filtreyi kurar, dataset'i acmaz; hemen ardindan
     aramayi BOS metinle bir kez cagiririz ve tek Close/Open'i o yapar.

     Iki sey birden cozuluyor:
       1. Bir acilista IKI sorgu kosuyordu (once master filtresi, sonra
          arama). Artik bir.
       2. Master degisince ESKI ARAMA METNI parametrede kaliyordu: Almanya'ya
          gecince liste hala "ank" ile suzulu gelir, bos gorunur ve sebebi
          gorunmezdi. Bos metin mevcut sozlesmede zaten "hepsini goster"
          demek ve uzunluk kapisindan muaf, o yuzden ayri bir mekanizmaya
          gerek yok.

     Parametrelerin birbirini korudugu DOGRULANDI (UniDAC kaynagi): Close/Open
     params koleksiyonuna dokunmaz; koleksiyon yalnizca SQL.Text/makro
     degisince yeniden kurulur, o zaman bile degerler ADA GORE korunur.
     Dolayisiyla arama isleyicisinin Close/Open'i az once kurdugumuz master
     parametresini silmez.
     ! Bunun tek istisnasi, SQL.Text'i BASTAN ATAYAN bir isleyicidir: yeni
       metinde master parametresi yoksa gider. Birim basligindaki nota bakin. *)
  LAramaAcacak := Assigned(FSearchEvent);

  { Enter/try eslesmesi icin bkz. DoLocate'teki not: Enter'dan HEMEN SONRA
    try gelir, arada tek satir bile olmaz. }
  TRadBusyDataSets.Enter(LDS);
  try
    FFiltering := True;
    { SIRA: once otomatik, sonra isleyici - isleyici uzerine yazabilsin. }
    if FAutoFilter <> afNone then
      ApplyAutoFilter(LDS, LValue, not LAramaAcacak);
    if Assigned(FFilterEvent) then
      FFilterEvent(Self, ASource, LMaster, LValue);
  finally
    try
      FFiltering := False;
      (* ONBELLEKLER ISTISNA HALINDE DE BOSALTILIR. Isleyici dataset'i acmis
         ve yolun ortasinda patlamis olabilir: liste ARTIK DEGISMISTIR,
         dolayisiyla onbellek bayattir. *)
      ResetCaches;
    finally
      (* RADDEV-003: Leave AYRI finally'de - ResetCaches patlarsa dataset
         KALICI busy kalirdi ve sonraki her filtre sessizce atlanirdi. *)
      TRadBusyDataSets.Leave(LDS);
    end;
  end;

  (* ARAMA SIFIRLAMA - busy sarmalinin DISINDA olmak ZORUNDA.
     DoSearch kendi IsBusy denetimini yapiyor; bu cagriyi Enter/Leave arasina
     koysaydik kendi kilidimize takilir ve arama SESSIZCE atlanirdi. *)
  if LAramaAcacak then
  begin
    LText := '';
    LTail := '';
    DoSearch(ASource, LText, LTail, False);
  end;
end;

function TRadLookupComboBoxProperties.PullWarning: string;

  procedure Ekle(const AText: string);
  begin
    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result + AText;
  end;

begin
  Result := '';
  if not HasMaster then
    Exit;

  if (FAutoFilter = afNone) and not Assigned(FFilterEvent) then
    Ekle('AMaster atanmis ama ne AOnFilter ne de AAutoFilter var: acilir ' +
         'liste hic suzulmez, kaskad sessizce YOKTUR.');

  if (FAutoFilter <> afNone) and (FMasterField = '') then
    Ekle('AAutoFilter acik ama AMasterField bos: hangi parametrenin/alanin ' +
         'suzulecegi bilinmiyor - acilir liste ilk acilista istisna atar.');

  if ListSource = nil then
    Ekle('AMaster atanmis ama ListSource yok: pull suzecek bir dataset ' +
         'bulamaz.');

  (* Detay seviyesi kolonu: tasarimcida secilebilen TEK ornek pattern
     gorunumundedir ve DevExpress belgesine gore pattern gorunumde deger
     okunamaz (TcxCustomGridTableItem.EditValue, TcxCustomGridView.IsPattern).
     Olculdu: _ValueOf hep Unassigned doner (DxAuditTest G01), yani filtre
     her acilista bos master ile calisir ve liste bos gelir - sessizce. *)
  if (FMasterSlot.Get(1) is TcxCustomGridTableItem) and
     (TcxCustomGridTableItem(FMasterSlot.Get(1)).GridView <> nil) and
     TcxCustomGridTableItem(FMasterSlot.Get(1)).GridView.IsPattern then
    Ekle('AMaster bir detay seviyesi (pattern) gorunumunun kolonu: pattern ' +
         'gorunumde deger okunamaz, master hep bos gelir ve liste hic ' +
         'dolmaz. Ust seviyedeki bir kolonu ya da bir editoru master yapin.');

  (* Bu ucuncu madde en sinsisi ve OLCULMUS bir davranisa dayaniyor.
     Pull, listeyi master'a gore SUZER. Saklanan anahtar o filtrenin disinda
     kaldigi anda:
       GridMode=False -> GetRecordIndexByKey -1 doner ve metin '' olur
                         (cxDBLookupEdit.pas:626-632)
       GridMode=True  -> ADataSet.Locate AYNI SUZULMUS dataset'e bakar,
                         bulamaz, '' uretir ve bunu FLookupList'e YAPISTIRIR
                         (:609-621) - yani GridMode acmak COZUM DEGIL, daha
                         kotusu: bos cevap artik yapiskan.
     Tek gercek cozum AOnLocate: uygulama O ANAHTARIN satirini sunucudan
     ceker. Yan fayda: AOnLocate'in klasik kusuru (listeyi tek satira
     daraltmak) pull altinda kayboluyor, cunku acilis her seferinde
     AOnFilter ile listeyi yeniden genisletiyor. *)
  if not Assigned(FLocateEvent) then
    Ekle('AMaster atanmis ama AOnLocate yok: liste master''a gore ' +
         'suzuldugu icin, suzulmus listede bulunmayan bir anahtarin metni ' +
         'BOS gosterilir. GridMode=True bunu COZMEZ - Locate ayni suzulmus ' +
         'dataset''e bakar ve bos cevabi onbellege yazar.');

  if FSkippedSearches > 0 then
    Ekle(Format('Arama/locate %d kez ATLANDI: liste dataset''i o anda ' +
      'mesguldu. Kullanicinin yazdigi metin o denemelerde hic uygulanmadi, ' +
      'ya da bir anahtarin metni bos gorundu.', [FSkippedSearches]));

  if (FAutoFilter = afClientFilter) and (ListDataSet <> nil) and
     ListDataSet.Active and
     (ListDataSet.RecordCount > CIstemciFiltreUyariEsigi) then
    Ekle(Format('AAutoFilter = afClientFilter ama liste %d satir (esik %d). ' +
      'Bu kip BUTUN satirlari cekip bellekte suzer; bu boyutta afServerParam ' +
      'ile sunucuda suzun ve SQL''e bir satir siniri (limit/top) koyun.',
      [ListDataSet.RecordCount, CIstemciFiltreUyariEsigi]));

  if FSkippedFilters > 0 then
    Ekle(Format('Filtre %d kez ATLANDI: liste dataset''i o anda mesguldu ' +
      '(TRadBusyDataSets). Acilir liste o acilislarda SUZULMEMIS haliyle ' +
      'gorundu. Ayni dataset''i birden fazla editor paylasiyorsa beklenen ' +
      'olabilir; degilse AOnFilter isleyicisi kendi listesini yeniden ' +
      'aciyor demektir.', [FSkippedFilters]));
end;

procedure TRadLookupComboBoxProperties.ResetLocateCache;
begin
  FHasLastKey := False;
  FLastKey := Unassigned;
  FHasText := False;
  FTextKey := Unassigned;
  FLastText := '';
end;

procedure TRadLookupComboBoxProperties.DoChanged;
begin
  (* Onbellekteki metin, ONU URETEN ayarlarla gecerlidir. Editor veriye
     baglandiktan SONRA ListSource ya da AOnLocate atanirsa (kodla kurulan
     formlar) ilk metin ayar yokken BOS cozulmus ve onbellege yazilmistir;
     sifirlanmazsa editor bos kalir - OLCULDU, DbNavTest S01/S03.

     Cizim yolunu BOZMAZ: DoLocate isleyiciyi LockUpdate(True) altinda
     cagirir ve kilitliyken gelen Changed DoChanged'e HIC inmez
     (cxEdit.pas:11128-11129) - yani "ayni anahtar icin bir kez sorgula"
     kazanci korunur. *)
  ResetLocateCache;
  inherited DoChanged;
end;

procedure TRadLookupComboBoxProperties.SetLocateEvent(const AValue: TRadLookupLocateEvent);
begin
  FLocateEvent := AValue;
  { Olay atamasi taban sinifin setter'larindan gecmez; Changed'i biz
    cagiriyoruz: onbellek sifirlanir ve editorler metni yeniden cozer. }
  Changed;
end;

procedure TRadLookupComboBoxProperties.TimedSearch(ASource: TComponent;
  const AText: string);
var
  LText, LTail: string;
begin
  LText := AText;
  LTail := '';
  DoSearch(ASource, LText, LTail, False);
  { Liste yenilendi; yazilan metni yeni listede bulmayi deniyoruz. }
  if LText <> '' then
    FindLookupText(LText);
end;

function TRadLookupComboBoxProperties.ChainSlotCount: Integer;
begin
  Result := FSlots.FilledCount;
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
  if CacheAllowed and FHasText and VarSameValue(FTextKey, AEditValue) then
  begin
    DisplayValue := FLastText;
    Exit;
  end;

  inherited PrepareDisplayValue(AEditValue, DisplayValue, AEditFocused);

  (* Onbellek TAM OLARAK bu yolun urettigi degerle dolduruluyor: baska bir
     cozumleme yolunun (GetDisplayLookupText) degeri farkli bicimlendirilmis
     olabilir. *)
  if CacheAllowed then
  begin
    FTextKey := AEditValue;
    FLastText := VarToStr(DisplayValue);
    FHasText := True;
  end;
end;

procedure TRadLookupComboBoxProperties.DoAssign(AProperties: TcxCustomEditProperties);
var
  LSrc: TRadLookupComboBoxProperties;
begin
  inherited DoAssign(AProperties);
  if not (AProperties is TRadLookupComboBoxProperties) then
    Exit;
  LSrc := TRadLookupComboBoxProperties(AProperties);
  FRadSetting.Assign(LSrc.FRadSetting);
  FSearchDelay := LSrc.FSearchDelay;
  FMinSearchLength := LSrc.FMinSearchLength;
  FClearTargets := LSrc.FClearTargets;
  FFilterOnPopup := LSrc.FFilterOnPopup;
  FEditOnPopup := LSrc.FEditOnPopup;
  FMasterField := LSrc.FMasterField;
  FAutoFilter := LSrc.FAutoFilter;
  FSearchEvent := LSrc.FSearchEvent;
  FLocateEvent := LSrc.FLocateEvent;
  FCascadeEvent := LSrc.FCascadeEvent;
  FFilterEvent := LSrc.FFilterEvent;
  { FFiltering/FCascading KOPYALANMAZ - gecici durum. }
  { Kopya, kaynagin cozdugu anahtari devralmaz. }
  ResetCaches;
end;

procedure TRadLookupComboBoxProperties.DoCascade(ASource: TComponent;
  const AValue: Variant; AFromData: Boolean; AChain: TRadEditSlots);
var
  LChain: TRadEditSlots;
begin
  { Tuketicinin KENDI zinciri varsa o kazanir; yoksa bu Properties'inki (item). }
  LChain := AChain;
  if (LChain = nil) or (LChain.FilledCount = 0) then
    LChain := FSlots;
  (* DEGISTI - eskiden "not Assigned(FCascadeEvent)" ile de cikiliyordu.
     PULL dunyasinda uygulamalarin cogunda AOnCascade HIC ATANMAZ; eski kosul
     GECERSIZ KILMA sinyalini de birlikte oldururdu: master degisir, hedefin
     degeri ve onbellekleri oldugu gibi kalir, hedef yeni master'a ait olmayan
     bir anahtari eski metniyle gostermeye devam ederdi. Ne derleyici ne test
     yakalar; yalnizca tutarsiz kaydedilmis bir satir gorunur.

     Cikis kosulu artik "yapacak is var mi": dolu hedef yoksa hicbir sey
     yapmayiz. *)
  if FCascading or (LChain.FilledCount = 0) then
    Exit;
  FCascading := True;
  FCascadeSource := ASource;
  FCascadeFromData := AFromData;
  try
    LChain.ForEach(CascadeOne, AValue);
  finally
    FCascadeFromData := False;
    FCascadeSource := nil;
    FCascading := False;
  end;
end;

procedure TRadLookupComboBoxProperties.DoLocate(ASource: TComponent;
  const AKey: Variant);
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
  if CacheAllowed and FHasLastKey and VarSameValue(FLastKey, AKey) then
    Exit;

  { Ayni liste sorgusunu paylasan baska bir editorun isleyicisinin ICINDEYSEK
    geri cekiliyoruz - yoksa ic ice sorgu ac/kapa. }
  LDS := ListDataSet;
  if TRadBusyDataSets.IsBusy(LDS) then
  begin
    { Cizim yolundaki atlama da sayilir: atlanan bir locate, o anahtarin
      metninin BOS gorunmesi demek - ve bu bugune kadar sessizdi. }
    Inc(FSkippedSearches);
    Exit;
  end;

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
      FLocateEvent(Self, ASource, AKey);
      if CacheAllowed then
      begin
        FLastKey := AKey;
        FHasLastKey := True;
      end;
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

procedure TRadLookupComboBoxProperties.DoSearch(ASource: TComponent;
  var AText, ATail: string; ANext: Boolean);
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
  begin
    { Sessiz kalmiyordu artik: PullWarning bunu bildirir. Atlanan bir arama,
      kullanicinin yazdigi metnin hic uygulanmamasi demektir. }
    Inc(FSkippedSearches);
    Exit;
  end;

  { Enter/try eslesmesi icin bkz. DoLocate'teki not. }
  TRadBusyDataSets.Enter(LDS);
  try
    try
      LockUpdate(True);
      try
        FSearchEvent(Self, ASource, AText, ATail, ANext);
      finally
        LockUpdate(False);
      end;
    finally
      (* RADDEV-004: ISTISNA HALINDE DE bosaltilir. Arama isleyicisi
         dataset'i yeniden acmis ve yolun ortasinda patlamis olabilir - liste
         DEGISMISTIR, dolayisiyla hem bizim cozulmus-anahtar onbellegimiz hem
         DevExpress'in FLookupList'i bayattir. Eskiden bu satir try'in
         DISINDAYDI: olculdu, patlayan bir aramadan sonra ayni anahtar
         onbellekten geliyor ve AOnLocate bir daha kosmuyordu
         (PullTest T20, duzeltmeden once). *)
      ResetCaches;
    end;
  finally
    (* RADDEV-003: Leave AYRI ve EN DIS finally'de. ResetCaches'in kendisi
       patlarsa (CheckLookupList vendor koduna giriyor) Leave atlanirdi ve
       dataset KALICI busy gorunurdu - sonraki her arama/filtre sessizce
       atlanirdi. *)
    TRadBusyDataSets.Leave(LDS);
  end;
end;

function TRadLookupComboBoxProperties.GetDisplayLookupText(const AKey: TcxEditValue): string;
begin
  { CIZIM YOLU: kaynak yok - bkz. TRadLookupLocateEvent'teki not. }
  DoLocate(nil, AKey);
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
  if LProps.ASearchDelay = 0 then
    (* Kaynak BURADA var: lookup-data'nin Edit'i kendi Owner'idir
       (cxLookupEdit.pas, TcxCustomLookupEditLookupData.GetEdit). Ata sinifta
       protected; torun oldugumuz icin erisebiliyoruz. *)
    LProps.DoSearch(Self.Edit, AText, ATail, ANext);
  Result := inherited Locate(AText, ATail, ANext);
end;

{ TRadButtonEditProperties }

constructor TRadButtonEditProperties.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner);
  FRadSetting := TcxRadSetting.Create(Self);
end;

destructor TRadButtonEditProperties.Destroy;
begin
  FreeAndNil(FRadSetting);
  inherited Destroy;
end;

procedure TRadButtonEditProperties.DoAssign(AProperties: TcxCustomEditProperties);
begin
  inherited DoAssign(AProperties);
  if AProperties is TRadButtonEditProperties then
    FRadSetting.Assign(TRadButtonEditProperties(AProperties).FRadSetting);
end;

procedure TRadButtonEditProperties.SetRadSetting(const AValue: TcxRadSetting);
begin
  FRadSetting.Assign(AValue);
end;

class function TRadButtonEditProperties.GetContainerClass: TcxContainerClass;
begin
  Result := TRadButtonEdit;
end;

{ TRadButtonEditRepository }

class function TRadButtonEditRepository.GetEditPropertiesClass: TcxCustomEditPropertiesClass;
begin
  Result := TRadButtonEditProperties;
end;

function TRadButtonEditRepository.GetProperties: TRadButtonEditProperties;
begin
  Result := inherited Properties as TRadButtonEditProperties;
end;

procedure TRadButtonEditRepository.SetProperties(Value: TRadButtonEditProperties);
begin
  inherited Properties := Value;
end;

{ TRadButtonEdit }

function TRadButtonEdit.GetActiveProperties: TRadButtonEditProperties;
begin
  Result := TRadButtonEditProperties(InternalGetActiveProperties);
end;

function TRadButtonEdit.GetProperties: TRadButtonEditProperties;
begin
  Result := TRadButtonEditProperties(inherited Properties);
end;

class function TRadButtonEdit.GetPropertiesClass: TcxCustomEditPropertiesClass;
begin
  Result := TRadButtonEditProperties;
end;

procedure TRadButtonEdit.SetProperties(Value: TRadButtonEditProperties);
begin
  Properties.Assign(Value);
end;

{ TRadDBButtonEdit }

function TRadDBButtonEdit.GetActiveProperties: TRadButtonEditProperties;
begin
  Result := TRadButtonEditProperties(InternalGetActiveProperties);
end;

function TRadDBButtonEdit.GetProperties: TRadButtonEditProperties;
begin
  Result := TRadButtonEditProperties(inherited Properties);
end;

class function TRadDBButtonEdit.GetPropertiesClass: TcxCustomEditPropertiesClass;
begin
  Result := TRadButtonEditProperties;
end;

procedure TRadDBButtonEdit.SetProperties(Value: TRadButtonEditProperties);
begin
  Properties.Assign(Value);
end;
{ TRadImageComboBoxProperties }

constructor TRadImageComboBoxProperties.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner);
  FRadSetting := TcxRadSetting.Create(Self);
end;

destructor TRadImageComboBoxProperties.Destroy;
begin
  FreeAndNil(FRadSetting);
  inherited Destroy;
end;

procedure TRadImageComboBoxProperties.DoAssign(AProperties: TcxCustomEditProperties);
begin
  inherited DoAssign(AProperties);
  if AProperties is TRadImageComboBoxProperties then
    FRadSetting.Assign(TRadImageComboBoxProperties(AProperties).FRadSetting);
end;

procedure TRadImageComboBoxProperties.SetRadSetting(const AValue: TcxRadSetting);
begin
  FRadSetting.Assign(AValue);
end;

class function TRadImageComboBoxProperties.GetContainerClass: TcxContainerClass;
begin
  Result := TRadImageComboBox;
end;

{ TRadImageComboBoxRepository }

class function TRadImageComboBoxRepository.GetEditPropertiesClass: TcxCustomEditPropertiesClass;
begin
  Result := TRadImageComboBoxProperties;
end;

function TRadImageComboBoxRepository.GetProperties: TRadImageComboBoxProperties;
begin
  Result := inherited Properties as TRadImageComboBoxProperties;
end;

procedure TRadImageComboBoxRepository.SetProperties(Value: TRadImageComboBoxProperties);
begin
  inherited Properties := Value;
end;

{ TRadImageComboBox }

function TRadImageComboBox.GetActiveProperties: TRadImageComboBoxProperties;
begin
  Result := TRadImageComboBoxProperties(InternalGetActiveProperties);
end;

function TRadImageComboBox.GetProperties: TRadImageComboBoxProperties;
begin
  Result := TRadImageComboBoxProperties(inherited Properties);
end;

class function TRadImageComboBox.GetPropertiesClass: TcxCustomEditPropertiesClass;
begin
  Result := TRadImageComboBoxProperties;
end;

procedure TRadImageComboBox.SetProperties(Value: TRadImageComboBoxProperties);
begin
  Properties.Assign(Value);
end;

{ TRadDBImageComboBox }

function TRadDBImageComboBox.GetActiveProperties: TRadImageComboBoxProperties;
begin
  Result := TRadImageComboBoxProperties(InternalGetActiveProperties);
end;

function TRadDBImageComboBox.GetProperties: TRadImageComboBoxProperties;
begin
  Result := TRadImageComboBoxProperties(inherited Properties);
end;

class function TRadDBImageComboBox.GetPropertiesClass: TcxCustomEditPropertiesClass;
begin
  Result := TRadImageComboBoxProperties;
end;

procedure TRadDBImageComboBox.SetProperties(Value: TRadImageComboBoxProperties);
begin
  Properties.Assign(Value);
end;
{ TRadExtLookupComboBoxProperties }

constructor TRadExtLookupComboBoxProperties.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner);
  FRadSetting := TcxRadSetting.Create(Self);
end;

destructor TRadExtLookupComboBoxProperties.Destroy;
begin
  FreeAndNil(FRadSetting);
  inherited Destroy;
end;

procedure TRadExtLookupComboBoxProperties.DoAssign(AProperties: TcxCustomEditProperties);
begin
  inherited DoAssign(AProperties);
  if AProperties is TRadExtLookupComboBoxProperties then
    FRadSetting.Assign(TRadExtLookupComboBoxProperties(AProperties).FRadSetting);
end;

procedure TRadExtLookupComboBoxProperties.SetRadSetting(const AValue: TcxRadSetting);
begin
  FRadSetting.Assign(AValue);
end;

class function TRadExtLookupComboBoxProperties.GetContainerClass: TcxContainerClass;
begin
  Result := TRadExtLookupComboBox;
end;

{ TRadExtLookupComboBoxRepository }

class function TRadExtLookupComboBoxRepository.GetEditPropertiesClass: TcxCustomEditPropertiesClass;
begin
  Result := TRadExtLookupComboBoxProperties;
end;

function TRadExtLookupComboBoxRepository.GetProperties: TRadExtLookupComboBoxProperties;
begin
  Result := inherited Properties as TRadExtLookupComboBoxProperties;
end;

procedure TRadExtLookupComboBoxRepository.SetProperties(Value: TRadExtLookupComboBoxProperties);
begin
  inherited Properties := Value;
end;

{ TRadExtLookupComboBox }

function TRadExtLookupComboBox.GetActiveProperties: TRadExtLookupComboBoxProperties;
begin
  Result := TRadExtLookupComboBoxProperties(InternalGetActiveProperties);
end;

function TRadExtLookupComboBox.GetProperties: TRadExtLookupComboBoxProperties;
begin
  Result := TRadExtLookupComboBoxProperties(inherited Properties);
end;

class function TRadExtLookupComboBox.GetPropertiesClass: TcxCustomEditPropertiesClass;
begin
  Result := TRadExtLookupComboBoxProperties;
end;

procedure TRadExtLookupComboBox.SetProperties(Value: TRadExtLookupComboBoxProperties);
begin
  Properties.Assign(Value);
end;

{ TRadDBExtLookupComboBox }

function TRadDBExtLookupComboBox.GetActiveProperties: TRadExtLookupComboBoxProperties;
begin
  Result := TRadExtLookupComboBoxProperties(InternalGetActiveProperties);
end;

function TRadDBExtLookupComboBox.GetProperties: TRadExtLookupComboBoxProperties;
begin
  Result := TRadExtLookupComboBoxProperties(inherited Properties);
end;

class function TRadDBExtLookupComboBox.GetPropertiesClass: TcxCustomEditPropertiesClass;
begin
  Result := TRadExtLookupComboBoxProperties;
end;

procedure TRadDBExtLookupComboBox.SetProperties(Value: TRadExtLookupComboBoxProperties);
begin
  Properties.Assign(Value);
end;
{ TRadPopupEditProperties }

constructor TRadPopupEditProperties.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner);
  FRadSetting := TcxRadSetting.Create(Self);
end;

destructor TRadPopupEditProperties.Destroy;
begin
  FreeAndNil(FRadSetting);
  inherited Destroy;
end;

procedure TRadPopupEditProperties.DoAssign(AProperties: TcxCustomEditProperties);
begin
  inherited DoAssign(AProperties);
  if AProperties is TRadPopupEditProperties then
    FRadSetting.Assign(TRadPopupEditProperties(AProperties).FRadSetting);
end;

procedure TRadPopupEditProperties.SetRadSetting(const AValue: TcxRadSetting);
begin
  FRadSetting.Assign(AValue);
end;

class function TRadPopupEditProperties.GetContainerClass: TcxContainerClass;
begin
  Result := TRadPopupEdit;
end;

{ TRadPopupEditRepository }

class function TRadPopupEditRepository.GetEditPropertiesClass: TcxCustomEditPropertiesClass;
begin
  Result := TRadPopupEditProperties;
end;

function TRadPopupEditRepository.GetProperties: TRadPopupEditProperties;
begin
  Result := inherited Properties as TRadPopupEditProperties;
end;

procedure TRadPopupEditRepository.SetProperties(Value: TRadPopupEditProperties);
begin
  inherited Properties := Value;
end;

{ TRadPopupEdit }

function TRadPopupEdit.GetActiveProperties: TRadPopupEditProperties;
begin
  Result := TRadPopupEditProperties(InternalGetActiveProperties);
end;

function TRadPopupEdit.GetProperties: TRadPopupEditProperties;
begin
  Result := TRadPopupEditProperties(inherited Properties);
end;

class function TRadPopupEdit.GetPropertiesClass: TcxCustomEditPropertiesClass;
begin
  Result := TRadPopupEditProperties;
end;

procedure TRadPopupEdit.SetProperties(Value: TRadPopupEditProperties);
begin
  Properties.Assign(Value);
end;

{ TRadDBPopupEdit }

function TRadDBPopupEdit.GetActiveProperties: TRadPopupEditProperties;
begin
  Result := TRadPopupEditProperties(InternalGetActiveProperties);
end;

function TRadDBPopupEdit.GetProperties: TRadPopupEditProperties;
begin
  Result := TRadPopupEditProperties(inherited Properties);
end;

class function TRadDBPopupEdit.GetPropertiesClass: TcxCustomEditPropertiesClass;
begin
  Result := TRadPopupEditProperties;
end;

procedure TRadDBPopupEdit.SetProperties(Value: TRadPopupEditProperties);
begin
  Properties.Assign(Value);
end;
initialization
  GetRegisteredEditProperties.Register(TRadComboBoxProperties, 'Rad ComboBox|Defines a combo box editor');
  GetRegisteredEditProperties.Register(TRadLookupComboBoxProperties, 'Rad LookupComboBox|LookupComboBox AksaSoft');
  GetRegisteredEditProperties.Register(TRadCheckComboBoxProperties, 'Rad CheckComboBox|Check combo with item values');
  GetRegisteredEditProperties.Register(TRadButtonEditProperties, 'Rad ButtonEdit|Button edit with RadSetting');
  GetRegisteredEditProperties.Register(TRadImageComboBoxProperties, 'Rad ImageComboBox|Image combo with RadSetting');
  GetRegisteredEditProperties.Register(TRadExtLookupComboBoxProperties, 'Rad ExtLookupComboBox|Grid lookup with RadSetting');
  GetRegisteredEditProperties.Register(TRadPopupEditProperties, 'Rad PopupEdit|Popup edit with RadSetting');

  {$IFDEF DX_INITIALIZATION_LOGGING}TdxUnitSectionsLogger.InitializationStarted(dxThisUnitName, SysInit.HInstance);{$ENDIF}
  RegisterClasses([TRadLookupComboBoxRepository]);
  RegisterClasses([TRadComboBoxRepository]);
  RegisterClasses([TRadCheckComboBoxRepository]);
  RegisterClasses([TRadButtonEditRepository, TRadImageComboBoxRepository,
    TRadExtLookupComboBoxRepository, TRadPopupEditRepository]);
  {$IFDEF DX_INITIALIZATION_LOGGING}TdxUnitSectionsLogger.InitializationFinished(dxThisUnitName, SysInit.HInstance);{$ENDIF}



   //GetRegisteredEditProperties.Register(TAkComboBoxDBProperties, 'ComboBox Aksa|Defines a combo box editor');
   //FilterEditsController.Register(TAkComboBoxDBProperties, TAkComboBoxDBProperties);


finalization
   GetRegisteredEditProperties.UnRegister(TRadPopupEditProperties);
   GetRegisteredEditProperties.UnRegister(TRadExtLookupComboBoxProperties);
   GetRegisteredEditProperties.UnRegister(TRadImageComboBoxProperties);
   GetRegisteredEditProperties.UnRegister(TRadButtonEditProperties);
   GetRegisteredEditProperties.UnRegister(TRadCheckComboBoxProperties);
   GetRegisteredEditProperties.UnRegister(TRadLookupComboBoxProperties);
   GetRegisteredEditProperties.UnRegister(TRadComboBoxProperties);

   //GetRegisteredEditProperties.UnRegister(TAkComboBoxDBProperties);
   //FilterEditsController.Unregister(TAkComboBoxDBProperties, TAkComboBoxDBProperties);

end.
