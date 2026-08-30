unit k.setting;

(* ==========================================================================
   AYAR PANELI - aranabilir, kategorili, JSON destekli

   YERLESIM (k.setting.dfm)
     Sol   : TdxNavBar        Grup = kategori, Oge = alt grup
     Sag   : TcxVerticalGrid  BUTUN ayarlar burada durur
     Ust   : edtSearch        arama kutusu
     Alt   : lblID / lblBaslik / lblGrup / lblInfo
             Delphi Object Inspector'un aciklama seridi ile ayni is

   -- DEPO -----------------------------------------------------------------
   Gercek deger IDocDict'tedir; izgara satiri yalnizca GORUNTUDUR. Anahtar
   tam noktali yoldur:

       fatura.satis.vade_asim_uyar
       ------ ----- --------------
       kategori altgrup  property adi (PascalCase -> snake_case)

   IDocDict.PathDelim '.' yapilir. mORMot'un kendi belgesi
   (mormot.core.variants.pas, IDocDict.PathDelim) soyle diyor:

     - varsayilani #0, yani YALNIZCA kok anahtarlar bulunur
     - '.' verilirse  dict.U['child2.name']  =  dict.D['child2'].U['name']
     - "if the sub object does not exist, setting a value will force its
        creation (and all its nested hierarchy)"

   Sonuc: depoda JSON gercek bir AGAC olarak durur (veritabani sutununa
   yazmaya uygun), erisim ise arayuzun gosterdigi duz noktali anahtarla
   yapilir. Varsayilan #0 oldugu icin PathDelim ACIKCA verilmek zorundadir -
   verilmezse anahtar duz metin olarak yazilir ve agac hic olusmaz. Bu,
   sessizce yanlis calisan turden bir hatadir: kod calisir, JSON yanlis cikar.

   -- NEDEN IDocDict, NEDEN NESNENIN KENDI ALANLARI DEGIL ------------------
   Bilmedigimiz anahtarlar korunur. Yeni surumun ekledigi bir ayar, eski
   surumun panelinde property karsiligi olmadigi halde JSON'da kalir ve geri
   yazilir. Nesne alanlarinda saklansaydi eski istemci onu sessizce silerdi -
   surumleri farkli makinelerin ayni ayar kaydini paylastigi bir ERP'de bu
   dogrudan veri kaybidir.

   -- TRadSetting NEDEN PARAMETRESIZ KURULUR ------------------------------
   TRadOptions -> TSynAutoCreateFields, ic ice published sinif alanlarini
   KENDISI yaratir ve yok eder; bunu PARAMETRESIZ sanal constructor ile
   yapar. Depoyu constructor parametresi yapsaydik cerceve yalnizca KOK
   nesneyi baglayabilir, framework'un yarattigi alt kategoriler bagsiz
   (FDoc = nil) kalirdi. Bu yuzden baglama Bind ile, nesne agaci kuruldUKTAN
   SONRA yapilir.

   -- SATIRLAR YENIDEN KURULMAZ -------------------------------------------
   Butun kategorilerin satirlari bir kez yaratilir; gezinme ve arama yalnizca
   TcxCustomRow.Visible'i degistirir. Aramanin kategoriler ARASINDA
   calisabilmesi bunu zorunlu kiliyor (VS Code davranisi). Maliyeti dusuk:
   satir bir veri nesnesidir, kontrol degil - TcxCustomVerticalGrid'in
   InplaceEditor'u TEKTIR ve yalnizca odakli satir icin acilir.

   -- KULLANIM ------------------------------------------------------------

     type
       TSatisAyar = class(TRadSetting)
       published
         property Vade      : Integer index 0 read GetI write SetI default 30;
         property KdvDahil  : Boolean index 1 read GetB write SetB default False;
         property Depo      : string  index 2 read GetS write SetS;
       end;

       TFaturaAyar = class(TRadSetting)
       private
         FSatis: TSatisAyar;
       published
         property Satis: TSatisAyar read FSatis;   // alt grup - otomatik yaratilir
       end;

     frmSetting
       .AddMenu('Fatura')
         .AddSubMenu('Satis')
           .Register(TSatisAyar)
             .Title('Vade', 'Vade (gun)', 'Musteriye taninan odeme suresi')
             .Repository('Depo', DM.riDepo);

   Register her published property icin satiri KENDILIGINDEN yaratir. Susleme
   metotlari (Title/Repository/...) yalnizca var olani degistirir - hicbir
   ayari zincirde saymak zorunda degilsiniz.

   -- ENUM'LAR ------------------------------------------------------------
   Enum property'ler tek satirlik bir donusturucu ile baglanir:

       function GetRejim(const Index: Integer): TVergiRejimi;
       begin Result := TVergiRejimi(GetI(Index)); end;

   Ordinal saklanir. DIKKAT: acik deger atanmis enum'lar (kl128 = 128) HIC
   RTTI uretmez ve bu panelde SESSIZCE gorunmez - kitin delphi-conventions
   kuralinda olculmus davranis. Boyle bir tur kullanmayin; kullanmak
   zorundaysaniz property'yi Integer yapip Choices ile secenekleri verin.
   ========================================================================== *)

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.Rtti, System.TypInfo, System.Generics.Collections,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  cxGraphics, cxControls, cxLookAndFeels, cxLookAndFeelPainters, cxClasses,
  dxLayoutContainer, dxLayoutControl, dxLayoutcxEditAdapters,
  cxContainer, cxEdit, dxCoreGraphics, cxTextEdit, cxMaskEdit, cxButtonEdit,
  cxLabel, dxNavBarCollns, dxNavBarBase, dxNavBar, cxStyles, cxFilter,
  dxScrollbarAnnotations, cxInplaceContainer, cxVGrid, cxDBLookupComboBox,
  cxDropDownEdit, cxCalendar, cxSpinEdit, cxCheckBox,
  mormot.core.base, mormot.core.variants,
  rad.config;

type
  TRadSetting   = class;
  TRadSettings  = class of TRadSetting;
  ISetting      = interface;

  /// <summary>Ayar katmani hatalari.</summary>
  ERadSetting = class(Exception);

  /// <summary>
  ///   Tek bir ayarin calisma zamani tanimi: depodaki anahtari, izgaradaki
  ///   satiri ve sunum bilgileri.
  /// </summary>
  /// <remarks>
  ///   Deger BURADA tutulmaz. GetValue depodan okur, SetValue depoya yazar.
  ///   Boylece tek dogru hep IDocDict'tedir; satir onun goruntusudur.
  /// </remarks>
  TRadSettingItem = class
  private
    FKey     : RawUtf8;
    FKeyText : string;
    FName    : string;
    FTitle   : string;
    FInfo    : string;
    FPath    : string;
    FRow     : TcxEditorRow;
    FOwner   : TRadSetting;
    FDefault : Variant;
    FDoc     : IDocDict;
    FIndex   : Integer;
  public
    /// <summary>Depodan okur; anahtar yoksa varsayilani dondurur.</summary>
    function  GetValue: Variant;
    /// <summary>Depoya yazar. Satiri tazelemez - onu cerceve yapar.</summary>
    procedure SetValue(const AValue: Variant);
    /// <summary>Depodaki degeri izgara satirina tasir.</summary>
    procedure ToRow;
    /// <summary>Arama eslesmesi. ALower KUCUK HARFE cevrilmis gelmelidir.</summary>
    function  Matches(const ALower: string): Boolean;

    property Key          : string       read FKeyText;
    property Name         : string       read FName;
    property Title        : string       read FTitle   write FTitle;
    property Info         : string       read FInfo    write FInfo;
    property Path         : string       read FPath;
    property Row          : TcxEditorRow read FRow;
    property Owner        : TRadSetting  read FOwner;
    property Index        : Integer      read FIndex;
    property DefaultValue : Variant      read FDefault write FDefault;
  end;

  /// <summary>Ayar panelinin akici (fluent) yuzu.</summary>
  /// <remarks>
  ///   Sunum bilgisi OZNITELIKLE degil bu zincirle verilir (kullanicinin
  ///   karari). Zincirdeki susleme metotlari var olan bir satiri degistirir;
  ///   satirlari Register kendisi yaratir.
  /// </remarks>
  ISetting = interface
    ['{4241666F-5005-4B43-91E4-F2CF946702D3}']
    // -- gezinme ----------------------------------------------------------
    function Clear: ISetting;
    function FindMenuIdx(const aName: string): Integer;
    /// <summary>NavBar GRUBU acar (ust kategori) ve etkin hedef yapar.</summary>
    function AddMenu(const aName: string): ISetting;
    /// <summary>Etkin grubun altina NavBar OGESI ekler (alt grup).</summary>
    function AddSubMenu(const aName: string): ISetting;
    /// <summary>Sinifi kaydeder, ornegini yaratir, satirlarini kurar.</summary>
    function Register(const RadSetting: TRadSettings): ISetting;

    // -- sunum suslemeleri (hepsi istege bagli) ---------------------------
    function Title(const aProp, aTitle: string; const aInfo: string = ''): ISetting;
    function Repository(const aProp: string; aItem: TcxEditRepositoryItem): ISetting;
    function Editor(const aProp: string; aClass: TcxCustomEditPropertiesClass): ISetting;
    function Choices(const aProp: string; const aItems: array of string): ISetting;
    function Image(const aProp: string; aIndex: Integer): ISetting;
    function ReadOnly(const aProp: string): ISetting;
    function HideRow(const aProp: string): ISetting;
    function DefaultValue(const aProp: string; const aValue: Variant): ISetting;

    // -- veri -------------------------------------------------------------
    function  Doc: IDocDict;
    function  LoadJson(const aJson: string): ISetting;
    function  SaveJson: string;
    function  Modified: Boolean;
    procedure RefreshRows;
    /// <summary>Satirlari filtreler; eslesme sayisini dondurur.</summary>
    function  Search(const aText: string): Integer;
    /// <summary>Kurulumda atlanan/suphelii seyler. Bos string = temiz.</summary>
    function  Warnings: string;
    function  ItemCount: Integer;
    function  Item(AIndex: Integer): TRadSettingItem;
  end;

  /// <summary>
  ///   Bir ayar kategorisinin SEMASI. Published property'leri ayarlardir;
  ///   ic ice published TRadSetting alanlari alt kategori olur.
  /// </summary>
  /// <remarks>
  ///   Bu nesne VERI TUTMAZ. Butun erisimler asagidaki index'li ortak
  ///   erisimcilerden gecer ve depodaki (IDocDict) anahtara yonlenir.
  ///
  ///   Her published property'nin index direktifi ZORUNLUDUR ve sinif icinde
  ///   TEK olmalidir - Register ikisini de denetler ve ihlalde ERadSetting
  ///   firlatir. Sebep olculmus degil ama acik: index'siz property tanimsiz
  ///   bir yuvaya yazar, ayni index'i tasiyan iki property ise tek bir degeri
  ///   paylasir ve bu hicbir uyari uretmez.
  ///
  ///   Ata sinifta published property YOKTUR. Bir ornek olsun diye buraya
  ///   published bir 'Value' konsaydi, HER torun sinif onu miras alir, index
  ///   0 her yerde dolu sayilir ve torunun kendi index 0'i ile catisirdi.
  /// </remarks>
  TRadSetting = class(TRadOptions)
  private
    FSetting : ISetting;
    FValues  : TArray<TRadSettingItem>;
    FPath    : string;
  protected
    (* Ortak erisimciler PROTECTED olmak ZORUNDA. Delphi'de plain private
       AYNI BIRIM icinde erisilebilirdir; ayar siniflari baska birimlerde
       tanimlanacagi icin private birakilirsa torun sinif kendi property'sinin
       read/write belirtecinde bunlari KULLANAMAZ ve tasarim hic calismaz. *)
    function  GetV (const Index: Integer): Variant;
    procedure SetV (const Index: Integer; const Value: Variant);
    function  GetS (const Index: Integer): string;
    procedure SetS (const Index: Integer; const Value: string);
    function  GetI (const Index: Integer): Integer;
    procedure SetI (const Index: Integer; const Value: Integer);
    function  GetB (const Index: Integer): Boolean;
    procedure SetB (const Index: Integer; const Value: Boolean);
    function  GetF (const Index: Integer): Double;
    procedure SetF (const Index: Integer; const Value: Double);
    function  GetDt(const Index: Integer): TDateTime;
    procedure SetDt(const Index: Integer; const Value: TDateTime);
  public
    /// <summary>Depoyu ve anahtar onekini baglar. Cerceve cagirir.</summary>
    /// <remarks>
    ///   Constructor parametresi DEGILDIR: TSynAutoCreateFields ic ice
    ///   alanlari parametresiz sanal constructor ile yaratir, oyle olsaydi
    ///   alt kategoriler bagsiz kalirdi. Birim basligindaki aciklamaya bakin.
    /// </remarks>
    procedure Bind(const aSetting: ISetting; const aPath: string);
    procedure SetSlot(AIndex: Integer; AItem: TRadSettingItem);
    function  Slot(AIndex: Integer): TRadSettingItem;
    /// <summary>
    ///   Index ile genel erisim (property adi bilinmeden). Dizi property'si
    ///   DEGIL: GetV/SetV birer index-direktifi erisimcisidir ve parametreleri
    ///   'const'tur; dizi property'si getter imzasinin BIREBIR eslesmesini
    ///   ister, o yuzden E2008 verir.
    /// </summary>
    function  ValueAt(AIndex: Integer): Variant;
    procedure SetValueAt(AIndex: Integer; const AValue: Variant);
    property  Path: string read FPath;
    property  Setting: ISetting read FSetting;
  end;

  TfrmSetting = class(TFrame, ISetting)
    lytSettingGroup_Root: TdxLayoutGroup;
    lytSetting: TdxLayoutControl;
    grpArama: TdxLayoutGroup;
    grpGrup: TdxLayoutGroup;
    grpData: TdxLayoutGroup;
    grpInfo: TdxLayoutGroup;
    edtSearch: TcxButtonEdit;
    dxLayoutItem1: TdxLayoutItem;
    dxLayoutAutoCreatedGroup1: TdxLayoutAutoCreatedGroup;
    dxLayoutAutoCreatedGroup2: TdxLayoutAutoCreatedGroup;
    grpIslem: TdxLayoutGroup;
    lblID: TcxLabel;
    dxLayoutItem2: TdxLayoutItem;
    lblBaslik: TcxLabel;
    dxLayoutItem3: TdxLayoutItem;
    lblGrup: TcxLabel;
    dxLayoutItem4: TdxLayoutItem;
    dxLayoutAutoCreatedGroup3: TdxLayoutAutoCreatedGroup;
    lblInfo: TcxLabel;
    dxLayoutItem5: TdxLayoutItem;
    dxNavBar: TdxNavBar;
    dxLayoutItem6: TdxLayoutItem;
    cxVerticalGrid1: TcxVerticalGrid;
    lytPropStore: TdxLayoutItem;
  private
    FList     : TObjectList<TRadSetting>;
    FItems    : TObjectList<TRadSettingItem>;
    FByRow    : TDictionary<TObject, TRadSettingItem>;
    FDoc      : IDocDict;
    FWarn     : TStringList;
    FGroup    : TdxNavBarGroup;
    FLink     : TdxNavBarItem;
    FCatRow   : TcxCategoryRow;
    FSubRow   : TcxCategoryRow;
    FGroupText: string;
    FLinkText : string;
    FPath     : string;
    FLast     : TRadSetting;
    FUpdating : Integer;
    FModified : Boolean;

    procedure BuildRows(AObj: TRadSetting; AParent: TcxCustomRow; const APath, ACrumb: string);
    function  NewRow(AParent: TcxCustomRow; const ACaption: string): TcxEditorRow;
    function  ApplyEditor(ARow: TcxEditorRow; ARtti: TRttiType): Boolean;
    function  Find(const aProp: string): TRadSettingItem;
    function  Need(const aProp: string): TRadSettingItem;
    procedure ShowInfo(AItem: TRadSettingItem);
    procedure SetRowVisible(ARow: TcxCustomRow; AVisible: Boolean);
    procedure FilterByNav;

    procedure DoValueChanged(Sender: TObject; ARowProperties: TcxCustomEditorRowProperties);
    procedure DoRowChanged(Sender: TObject; AOldRow: TcxCustomRow; AOldCellIndex: Integer);
    procedure DoSearchChanged(Sender: TObject);
    procedure DoNavClick(Sender: TObject; ALink: TdxNavBarItemLink);
  protected
    // -- ISetting ---------------------------------------------------------
    function Clear: ISetting;
    function FindMenuIdx(const aName: string): Integer;
    function AddMenu(const aName: string): ISetting;
    function AddSubMenu(const aName: string): ISetting;
    function Register(const RadSetting: TRadSettings): ISetting;

    function Title(const aProp, aTitle: string; const aInfo: string = ''): ISetting;
    function Repository(const aProp: string; aItem: TcxEditRepositoryItem): ISetting;
    function Editor(const aProp: string; aClass: TcxCustomEditPropertiesClass): ISetting;
    function Choices(const aProp: string; const aItems: array of string): ISetting;
    function Image(const aProp: string; aIndex: Integer): ISetting;
    function ReadOnly(const aProp: string): ISetting;
    function HideRow(const aProp: string): ISetting;
    function DefaultValue(const aProp: string; const aValue: Variant): ISetting;

    function  Doc: IDocDict;
    function  LoadJson(const aJson: string): ISetting;
    function  SaveJson: string;
    function  Modified: Boolean;
    procedure RefreshRows;
    function  Search(const aText: string): Integer;
    function  Warnings: string;
    function  ItemCount: Integer;
    function  Item(AIndex: Integer): TRadSettingItem;

  public
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
  end;

/// <summary>
///   PascalCase adi noktali anahtar parcasina cevirir ve Turkce harfleri
///   ASCII'ye katlar: 'VadeAsimUyar' -> 'vade_asim_uyar'.
/// </summary>
function SettingSlug(const AText: string): string;

implementation

{$R *.dfm}

uses
  System.Character,
  mormot.core.unicode;   // StringToUtf8 / Utf8ToString

type
  /// <summary>
  ///   TcxVerticalGridRows.BeginUpdate/EndUpdate PROTECTED'tir; toplu
  ///   gorunurluk degisiminde tek tek yeniden cizim olmasin diye erisim
  ///   sinifi ile acilir. Ayni desen help.Dev.pas'ta TcxCustomEditAccess
  ///   ile TcxCustomEdit.Properties icin de kullaniliyor.
  /// </summary>
  TcxRowsAccess = class(TcxVerticalGridRows);

const
  /// <summary>
  ///   Delphi, index direktifi TASIMAYAN bir property icin TPropInfo.Index
  ///   alanina bu degeri koyar. Register bunu "index verilmemis" sayar.
  /// </summary>
  CNoIndex = Low(Integer);

  /// <summary>
  ///   Bir ayar sinifinin kabul edilen en buyuk index'i. Yalnizca yanlislikla
  ///   yazilmis dev bir sayinin devasa dizi ayirmasini engeller.
  /// </summary>
  CMaxIndex = 4095;

  /// Turkce harfler ve ASCII karsiliklari. Dosya ASCII kalsin diye kod
  /// noktasi ile yazildi.
  CTrFrom: array[0..11] of Char =
    (#$00E7, #$011F, #$0131, #$00F6, #$015F, #$00FC,
     #$00C7, #$011E, #$0130, #$00D6, #$015E, #$00DC);
  CTrTo: array[0..11] of Char =
    ('c', 'g', 'i', 'o', 's', 'u',
     'C', 'G', 'I', 'O', 'S', 'U');

function FoldTr(AChar: Char): Char;
var
  LIdx: Integer;
begin
  for LIdx := Low(CTrFrom) to High(CTrFrom) do
    if CTrFrom[LIdx] = AChar then
      Exit(CTrTo[LIdx]);
  Result := AChar;
end;

function SettingSlug(const AText: string): string;
var
  LIdx  : Integer;
  LCh   : Char;
  LOut  : TStringBuilder;

  // Ayirici, KAYNAK karakterine degil YAZILANA bakmali. Aksi halde
  // 'Genel Ayarlar' -> 'genel__ayarlar' olur: bosluk bir '_' yazar, ardindan
  // gelen buyuk harf bir tane daha ekler. Olculdu.
  function SonuAyirici: Boolean;
  begin
    Result := (LOut.Length = 0) or (LOut.Chars[LOut.Length - 1] = '_');
  end;

begin
  LOut := TStringBuilder.Create;
  try
    for LIdx := 1 to Length(AText) do
    begin
      LCh := FoldTr(AText[LIdx]);
      if LCh.IsUpper and not SonuAyirici then
        LOut.Append('_');
      if LCh.IsLetterOrDigit then
        LOut.Append(LCh.ToLower)
      else if not SonuAyirici then
        LOut.Append('_');
    end;
    Result := LOut.ToString;
  finally
    LOut.Free;
  end;
  while (Result <> '') and (Result[Length(Result)] = '_') do
    SetLength(Result, Length(Result) - 1);
end;

{ TRadSettingItem }

function TRadSettingItem.GetValue: Variant;
begin
  Result := FDefault;
  if FDoc = nil then
    Exit;
  Result := FDoc.GetDef(FKey, FDefault);
  if VarIsEmpty(Result) or VarIsNull(Result) then
    Result := FDefault;
end;

procedure TRadSettingItem.SetValue(const AValue: Variant);
begin
  if FDoc <> nil then
    FDoc.Item[FKey] := AValue;
end;

procedure TRadSettingItem.ToRow;
begin
  if FRow <> nil then
    FRow.Properties.Value := GetValue;
end;

function TRadSettingItem.Matches(const ALower: string): Boolean;
begin
  // DIKKAT: mormot.core.base, LowerCase ve Pos icin RawUtf8 asiri yuklemeleri
  // tanimliyor ve bunlar RTL'inkileri golgeliyor. Nitelenmeden yazilirsa her
  // karsilastirma sessizce UTF8'e gidip donuyor (W1057). Bu birimdeki butun
  // metin islemleri bu yuzden acikca System / System.SysUtils'ten cagriliyor.
  Result := (ALower = '') or
            (System.Pos(ALower, System.SysUtils.LowerCase(FTitle))   > 0) or
            (System.Pos(ALower, System.SysUtils.LowerCase(FKeyText)) > 0) or
            (System.Pos(ALower, System.SysUtils.LowerCase(FInfo))    > 0) or
            (System.Pos(ALower, System.SysUtils.LowerCase(FPath))    > 0);
end;

{ TRadSetting }

procedure TRadSetting.Bind(const aSetting: ISetting; const aPath: string);
begin
  // ISetting'i tutmak dongu YARATMAZ: cerceve bir TComponent'tir ve
  // TComponent'in _AddRef/_Release'i sayim yapmaz (-1 doner). Bu yuzden
  // burada tutulan referans cerceveyi hayatta tutmaz.
  FSetting := aSetting;
  FPath    := aPath;
end;

procedure TRadSetting.SetSlot(AIndex: Integer; AItem: TRadSettingItem);
begin
  if AIndex < 0 then
    raise ERadSetting.CreateFmt('Gecersiz ayar index: %d', [AIndex]);
  if AIndex > High(FValues) then
    SetLength(FValues, AIndex + 1);
  FValues[AIndex] := AItem;
end;

function TRadSetting.Slot(AIndex: Integer): TRadSettingItem;
begin
  if (AIndex < 0) or (AIndex > High(FValues)) then
    Result := nil
  else
    Result := FValues[AIndex];
end;

function TRadSetting.GetV(const Index: Integer): Variant;
var
  LSlot: TRadSettingItem;
begin
  LSlot := Slot(Index);
  if LSlot = nil then
    Result := Null
  else
    Result := LSlot.GetValue;
end;

procedure TRadSetting.SetV(const Index: Integer; const Value: Variant);
var
  LSlot: TRadSettingItem;
begin
  LSlot := Slot(Index);
  if LSlot = nil then
    Exit;
  LSlot.SetValue(Value);
  LSlot.ToRow;
end;

function TRadSetting.ValueAt(AIndex: Integer): Variant;
begin
  Result := GetV(AIndex);
end;

procedure TRadSetting.SetValueAt(AIndex: Integer; const AValue: Variant);
begin
  SetV(AIndex, AValue);
end;

function TRadSetting.GetS(const Index: Integer): string;
begin
  Result := VarToStr(GetV(Index));
end;

procedure TRadSetting.SetS(const Index: Integer; const Value: string);
begin
  SetV(Index, Value);
end;

function TRadSetting.GetI(const Index: Integer): Integer;
var
  LVal: Variant;
begin
  LVal := GetV(Index);
  if VarIsNull(LVal) or VarIsEmpty(LVal) then
    Result := 0
  else
    Result := LVal;
end;

procedure TRadSetting.SetI(const Index: Integer; const Value: Integer);
begin
  SetV(Index, Value);
end;

function TRadSetting.GetB(const Index: Integer): Boolean;
var
  LVal: Variant;
begin
  LVal := GetV(Index);
  Result := (not VarIsNull(LVal)) and (not VarIsEmpty(LVal)) and Boolean(LVal);
end;

procedure TRadSetting.SetB(const Index: Integer; const Value: Boolean);
begin
  SetV(Index, Value);
end;

function TRadSetting.GetF(const Index: Integer): Double;
var
  LVal: Variant;
begin
  LVal := GetV(Index);
  if VarIsNull(LVal) or VarIsEmpty(LVal) then
    Result := 0
  else
    Result := LVal;
end;

procedure TRadSetting.SetF(const Index: Integer; const Value: Double);
begin
  SetV(Index, Value);
end;

function TRadSetting.GetDt(const Index: Integer): TDateTime;
var
  LVal: Variant;
begin
  LVal := GetV(Index);
  if VarIsNull(LVal) or VarIsEmpty(LVal) then
    Result := 0
  else
    Result := VarToDateTime(LVal);
end;

procedure TRadSetting.SetDt(const Index: Integer; const Value: TDateTime);
begin
  SetV(Index, Value);
end;

{ TfrmSetting }

procedure TfrmSetting.AfterConstruction;
begin
  inherited;
  FList  := TObjectList<TRadSetting>.Create(True);
  FItems := TObjectList<TRadSettingItem>.Create(True);
  FByRow := TDictionary<TObject, TRadSettingItem>.Create;
  FWarn  := TStringList.Create;

  FDoc := DocDict(RawUtf8('{}'));
  // ZORUNLU: varsayilani #0'dir; verilmezse 'a.b.c' DUZ bir anahtar olarak
  // yazilir ve JSON agaci hic olusmaz. Birim basligindaki nota bakin.
  FDoc.PathDelim := '.';

  if csDesigning in ComponentState then
    Exit;

  cxVerticalGrid1.OnEditValueChanged := DoValueChanged;
  cxVerticalGrid1.OnItemChanged      := DoRowChanged;
  edtSearch.Properties.OnChange      := DoSearchChanged;
  dxNavBar.OnLinkClick               := DoNavClick;

  ShowInfo(nil);
end;

procedure TfrmSetting.BeforeDestruction;
begin
  inherited;
  FDoc := nil;
  FByRow.Free;
  FItems.Free;
  FList.Free;
  FWarn.Free;
end;

// -- gezinme ---------------------------------------------------------------

function TfrmSetting.Clear: ISetting;
begin
  Result := Self;
  cxVerticalGrid1.ClearRows;
  dxNavBar.Groups.Clear;
  dxNavBar.Items.Clear;
  FByRow.Clear;
  FItems.Clear;
  FList.Clear;
  FWarn.Clear;
  FGroup     := nil;
  FLink      := nil;
  FCatRow    := nil;
  FSubRow    := nil;
  FLast      := nil;
  FGroupText := '';
  FLinkText  := '';
  FPath      := '';
  FModified  := False;
  ShowInfo(nil);
end;

function TfrmSetting.FindMenuIdx(const aName: string): Integer;
var
  LIdx: Integer;
begin
  for LIdx := 0 to dxNavBar.Items.Count - 1 do
    if SameText(dxNavBar.Items[LIdx].Caption, aName) then
      Exit(LIdx);
  Result := -1;
end;

function TfrmSetting.AddMenu(const aName: string): ISetting;
var
  LIdx: Integer;
begin
  Result := Self;

  // Ayni kategori iki kez acilabilsin: var olani etkin yap, yenisini yaratma.
  for LIdx := 0 to dxNavBar.Groups.Count - 1 do
    if SameText(dxNavBar.Groups[LIdx].Caption, aName) then
    begin
      FGroup := dxNavBar.Groups[LIdx];
      Break;
    end;

  if (FGroup = nil) or (not SameText(FGroup.Caption, aName)) then
  begin
    FGroup         := dxNavBar.Groups.Add;
    FGroup.Caption := aName;
    FCatRow        := TcxCategoryRow(cxVerticalGrid1.Add(TcxCategoryRow));
    FCatRow.Properties.Caption := aName;
  end;

  FGroupText := aName;
  // Yeni kategoriye gecince alt grup baglami sifirlanir.
  FLink     := nil;
  FSubRow   := nil;
  FLinkText := '';
  FPath     := SettingSlug(aName);
  FLast     := nil;
end;

function TfrmSetting.AddSubMenu(const aName: string): ISetting;
begin
  Result := Self;
  if FGroup = nil then
    raise ERadSetting.CreateFmt(
      'AddSubMenu(%s): once AddMenu ile bir kategori acilmalidir.', [aName]);

  FLink         := dxNavBar.Items.Add;
  FLink.Caption := aName;
  // NavBar TUZAGI: Items.Add ogeyi yalnizca genel listeye koyar. Bir gruba
  // BAGLANMADAN oge ekranda GORUNMEZ - hicbir hata da uretmez.
  FGroup.CreateLink(FLink);

  FSubRow := TcxCategoryRow(cxVerticalGrid1.AddChild(FCatRow, TcxCategoryRow));
  FSubRow.Properties.Caption := aName;

  FLinkText := aName;
  FPath     := SettingSlug(FGroupText) + '.' + SettingSlug(aName);
  FLast     := nil;
end;

function TfrmSetting.Register(const RadSetting: TRadSettings): ISetting;
var
  LObj    : TRadSetting;
  LParent : TcxCustomRow;
  LCrumb  : string;
begin
  Result := Self;
  if RadSetting = nil then
    raise ERadSetting.Create('Register: sinif nil.');
  if FGroup = nil then
    raise ERadSetting.CreateFmt(
      'Register(%s): once AddMenu ile bir kategori acilmalidir.',
      [RadSetting.ClassName]);

  // Parametresiz SANAL constructor - metasinif uzerinden dogru sinifi yaratir
  // ve TSynAutoCreateFields ic ice alanlari kendisi kurar.
  LObj := RadSetting.Create;
  FList.Add(LObj);

  if FSubRow <> nil then
  begin
    LParent := FSubRow;
    LCrumb  := FGroupText + ' > ' + FLinkText;
  end
  else
  begin
    LParent := FCatRow;
    LCrumb  := FGroupText;
  end;

  LObj.Bind(Self, FPath);
  BuildRows(LObj, LParent, FPath, LCrumb);
  FLast := LObj;
end;

// -- satir kurulumu --------------------------------------------------------

function TfrmSetting.NewRow(AParent: TcxCustomRow; const ACaption: string): TcxEditorRow;
begin
  Result := TcxEditorRow(cxVerticalGrid1.AddChild(AParent, TcxEditorRow));
  Result.Properties.Caption := ACaption;
end;

function TfrmSetting.ApplyEditor(ARow: TcxEditorRow; ARtti: TRttiType): Boolean;
var
  LCombo: TcxComboBoxProperties;
  LIdx  : Integer;
  LData : PTypeData;
begin
  Result := True;
  case ARtti.TypeKind of
    tkInteger, tkInt64:
      ARow.Properties.EditPropertiesClass := TcxSpinEditProperties;

    tkEnumeration:
      if ARtti.Handle = TypeInfo(Boolean) then
        ARow.Properties.EditPropertiesClass := TcxCheckBoxProperties
      else
      begin
        ARow.Properties.EditPropertiesClass := TcxComboBoxProperties;
        LCombo := ARow.Properties.EditProperties as TcxComboBoxProperties;
        LCombo.DropDownListStyle := lsFixedList;
        LData := GetTypeData(ARtti.Handle);
        for LIdx := LData.MinValue to LData.MaxValue do
          LCombo.Items.Add(GetEnumName(ARtti.Handle, LIdx));
      end;

    tkFloat:
      if ARtti.Handle = TypeInfo(TDateTime) then
        ARow.Properties.EditPropertiesClass := TcxDateEditProperties
      else
      begin
        ARow.Properties.EditPropertiesClass := TcxSpinEditProperties;
        TcxSpinEditProperties(ARow.Properties.EditProperties).ValueType := vtFloat;
      end;

    tkString, tkLString, tkWString, tkUString:
      ARow.Properties.EditPropertiesClass := TcxTextEditProperties;
  else
    ARow.Properties.EditPropertiesClass := TcxTextEditProperties;
    Result := False;
  end;
end;

procedure TfrmSetting.BuildRows(AObj: TRadSetting; AParent: TcxCustomRow;
  const APath, ACrumb: string);
var
  LCtx    : TRttiContext;
  LTyp    : TRttiType;
  LProp   : TRttiProperty;
  LInst   : TRttiInstanceProperty;
  LChild  : TObject;
  LItem   : TRadSettingItem;
  LRow    : TcxEditorRow;
  LCat    : TcxCategoryRow;
  LSeen   : TDictionary<Integer, string>;
  LIdx    : Integer;
  LKey    : string;
  LDup    : string;
begin
  LCtx  := TRttiContext.Create;
  LSeen := TDictionary<Integer, string>.Create;
  try
    LTyp := LCtx.GetType(AObj.ClassInfo);
    if LTyp = nil then
    begin
      FWarn.Add(Format('%s: RTTI yok, hic satir kurulmadi.', [AObj.ClassName]));
      Exit;
    end;

    for LProp in LTyp.GetProperties do
    begin
      if LProp.Visibility <> mvPublished then
        Continue;

      // -- alt kategori: ic ice TRadSetting ------------------------------
      if LProp.PropertyType.TypeKind = tkClass then
      begin
        LChild := LProp.GetValue(AObj).AsObject;
        if not (LChild is TRadSetting) then
        begin
          FWarn.Add(Format('%s.%s: TRadSetting olmayan sinif property atlandi.',
            [AObj.ClassName, LProp.Name]));
          Continue;
        end;
        LCat := TcxCategoryRow(cxVerticalGrid1.AddChild(AParent, TcxCategoryRow));
        LCat.Properties.Caption := LProp.Name;
        LKey := APath + '.' + SettingSlug(LProp.Name);
        TRadSetting(LChild).Bind(Self, LKey);
        BuildRows(TRadSetting(LChild), LCat, LKey, ACrumb + ' > ' + LProp.Name);
        Continue;
      end;

      // -- index denetimi -------------------------------------------------
      if not (LProp is TRttiInstanceProperty) then
      begin
        FWarn.Add(Format('%s.%s: ornek property degil, atlandi.',
          [AObj.ClassName, LProp.Name]));
        Continue;
      end;
      LInst := TRttiInstanceProperty(LProp);
      LIdx  := LInst.Index;

      if LIdx = CNoIndex then
        raise ERadSetting.CreateFmt(
          '%s.%s: index direktifi yok. Ayar property''leri ortak erisimciyi ' +
          'kullanir; index olmadan hangi yuvaya yazacagi belirsizdir.',
          [AObj.ClassName, LProp.Name]);

      if (LIdx < 0) or (LIdx > CMaxIndex) then
        raise ERadSetting.CreateFmt('%s.%s: index %d araligin disinda (0..%d).',
          [AObj.ClassName, LProp.Name, LIdx, CMaxIndex]);

      if LSeen.TryGetValue(LIdx, LDup) then
        raise ERadSetting.CreateFmt(
          '%s: "%s" ve "%s" ayni index''i (%d) paylasiyor. Ikisi tek bir ' +
          'degeri okur/yazar ve bu calisma zamaninda hicbir uyari uretmez.',
          [AObj.ClassName, LDup, LProp.Name, LIdx]);
      LSeen.Add(LIdx, LProp.Name);

      // -- satir ----------------------------------------------------------
      LRow := NewRow(AParent, LProp.Name);
      if not ApplyEditor(LRow, LProp.PropertyType) then
        FWarn.Add(Format('%s.%s: %s turu desteklenmiyor, metin kutusu kuruldu.',
          [AObj.ClassName, LProp.Name,
           GetEnumName(TypeInfo(TTypeKind), Ord(LProp.PropertyType.TypeKind))]));

      LItem := TRadSettingItem.Create;
      FItems.Add(LItem);
      LItem.FName    := LProp.Name;
      LItem.FTitle   := LProp.Name;
      LItem.FPath    := ACrumb;
      LItem.FKeyText := APath + '.' + SettingSlug(LProp.Name);
      LItem.FKey     := StringToUtf8(LItem.FKeyText);
      LItem.FRow     := LRow;
      LItem.FOwner   := AObj;
      LItem.FIndex   := LIdx;
      LItem.FDoc     := FDoc;

      // default direktifi yalnizca ordinal turlerde vardir.
      if (LInst.Default <> CNoIndex) and
         (LProp.PropertyType.TypeKind in [tkInteger, tkEnumeration]) then
      begin
        if LProp.PropertyType.Handle = TypeInfo(Boolean) then
          LItem.FDefault := LInst.Default <> 0
        else
          LItem.FDefault := LInst.Default;
      end
      else
        case LProp.PropertyType.TypeKind of
          tkInteger, tkInt64, tkFloat: LItem.FDefault := 0;
          tkEnumeration:               LItem.FDefault := 0;
        else
          LItem.FDefault := '';
        end;

      AObj.SetSlot(LIdx, LItem);
      FByRow.AddOrSetValue(LRow.Properties, LItem);
      LItem.ToRow;
    end;
  finally
    LSeen.Free;
    LCtx.Free;
  end;
end;

// -- susleme ---------------------------------------------------------------

function TfrmSetting.Find(const aProp: string): TRadSettingItem;
var
  LItem: TRadSettingItem;
begin
  Result := nil;
  // Once en son Register edilen sinif icinde ara - zincir hep onun uzerinedir.
  for LItem in FItems do
    if (LItem.Owner = FLast) and SameText(LItem.Name, aProp) then
      Exit(LItem);
  for LItem in FItems do
    if SameText(LItem.Key, aProp) or SameText(LItem.Name, aProp) then
      Exit(LItem);
end;

function TfrmSetting.Need(const aProp: string): TRadSettingItem;
begin
  Result := Find(aProp);
  if Result = nil then
    raise ERadSetting.CreateFmt(
      '"%s" adinda bir ayar yok. Adi property adiyla ayni yazin (ornek: ' +
      '''Vade''), ya da tam anahtari verin (''fatura.satis.vade'').', [aProp]);
end;

function TfrmSetting.Title(const aProp, aTitle, aInfo: string): ISetting;
var
  LItem: TRadSettingItem;
begin
  Result := Self;
  LItem  := Need(aProp);
  LItem.Title := aTitle;
  if aInfo <> '' then
    LItem.Info := aInfo;
  LItem.Row.Properties.Caption := aTitle;
  LItem.Row.Properties.Hint    := aInfo;
end;

function TfrmSetting.Repository(const aProp: string;
  aItem: TcxEditRepositoryItem): ISetting;
begin
  Result := Self;
  Need(aProp).Row.Properties.RepositoryItem := aItem;
end;

function TfrmSetting.Editor(const aProp: string;
  aClass: TcxCustomEditPropertiesClass): ISetting;
begin
  Result := Self;
  Need(aProp).Row.Properties.EditPropertiesClass := aClass;
end;

function TfrmSetting.Choices(const aProp: string;
  const aItems: array of string): ISetting;
var
  LItem  : TRadSettingItem;
  LCombo : TcxComboBoxProperties;
  LIdx   : Integer;
begin
  Result := Self;
  LItem  := Need(aProp);
  LItem.Row.Properties.EditPropertiesClass := TcxComboBoxProperties;
  LCombo := LItem.Row.Properties.EditProperties as TcxComboBoxProperties;
  LCombo.DropDownListStyle := lsFixedList;
  LCombo.Items.Clear;
  for LIdx := Low(aItems) to High(aItems) do
    LCombo.Items.Add(aItems[LIdx]);
end;

function TfrmSetting.Image(const aProp: string; aIndex: Integer): ISetting;
begin
  Result := Self;
  Need(aProp).Row.Properties.ImageIndex := aIndex;
end;

function TfrmSetting.ReadOnly(const aProp: string): ISetting;
begin
  Result := Self;
  Need(aProp).Row.Properties.Options.Editing := False;
end;

function TfrmSetting.HideRow(const aProp: string): ISetting;
begin
  Result := Self;
  Need(aProp).Row.Visible := False;
end;

function TfrmSetting.DefaultValue(const aProp: string;
  const aValue: Variant): ISetting;
var
  LItem: TRadSettingItem;
begin
  Result := Self;
  LItem  := Need(aProp);
  LItem.DefaultValue := aValue;
  LItem.ToRow;
end;

// -- veri ------------------------------------------------------------------

function TfrmSetting.Doc: IDocDict;
begin
  Result := FDoc;
end;

function TfrmSetting.LoadJson(const aJson: string): ISetting;
var
  LNew : IDocDict;
  LItem: TRadSettingItem;
begin
  Result := Self;
  if System.SysUtils.Trim(aJson) = '' then
    LNew := DocDict(RawUtf8('{}'))
  else
    LNew := DocDict(StringToUtf8(aJson));
  if LNew = nil then
    raise ERadSetting.Create('LoadJson: JSON ayristirilamadi.');
  LNew.PathDelim := '.';

  FDoc := LNew;
  // Yuvalar belgeyi degerle degil REFERANSLA tutuyor; yeni belge her birine
  // ayrica verilmeli, yoksa eskisini okumaya devam ederler.
  for LItem in FItems do
    LItem.FDoc := FDoc;

  FModified := False;
  RefreshRows;
end;

function TfrmSetting.SaveJson: string;
begin
  if FDoc = nil then
    Exit('{}');
  Result := Utf8ToString(FDoc.Value^.ToJson);
end;

function TfrmSetting.Modified: Boolean;
begin
  Result := FModified;
end;

procedure TfrmSetting.RefreshRows;
var
  LItem: TRadSettingItem;
begin
  Inc(FUpdating);
  try
    TcxRowsAccess(cxVerticalGrid1.Rows).BeginUpdate;
    try
      for LItem in FItems do
        LItem.ToRow;
    finally
      TcxRowsAccess(cxVerticalGrid1.Rows).EndUpdate;
    end;
  finally
    Dec(FUpdating);
  end;
end;

function TfrmSetting.ItemCount: Integer;
begin
  Result := FItems.Count;
end;

function TfrmSetting.Item(AIndex: Integer): TRadSettingItem;
begin
  if (AIndex < 0) or (AIndex >= FItems.Count) then
    Result := nil
  else
    Result := FItems[AIndex];
end;

function TfrmSetting.Warnings: string;
begin
  Result := FWarn.Text;
end;

// -- gorunurluk / arama ----------------------------------------------------

procedure TfrmSetting.SetRowVisible(ARow: TcxCustomRow; AVisible: Boolean);
begin
  if (ARow <> nil) and (ARow.Visible <> AVisible) then
    ARow.Visible := AVisible;
end;

function TfrmSetting.Search(const aText: string): Integer;
var
  LLower : string;
  LItem  : TRadSettingItem;
  LIdx   : Integer;
  LRow   : TcxCustomRow;
  LAny   : Boolean;
  LChild : Integer;
begin
  Result := 0;
  LLower := System.SysUtils.LowerCase(System.SysUtils.Trim(aText));

  TcxRowsAccess(cxVerticalGrid1.Rows).BeginUpdate;
  try
    if LLower = '' then
    begin
      // Arama bos: gezinmeye geri don, arama kipini birak.
      FilterByNav;
      Exit(FItems.Count);
    end;

    for LItem in FItems do
    begin
      if LItem.Matches(LLower) then
      begin
        SetRowVisible(LItem.Row, True);
        Inc(Result);
      end
      else
        SetRowVisible(LItem.Row, False);
    end;

    // Kategori satiri, gorunur bir alt ogesi varsa gorunur. Aramada butun
    // kategoriler taranir - VS Code'da oldugu gibi kategoriler arasi gezer.
    for LIdx := cxVerticalGrid1.Rows.Count - 1 downto 0 do
    begin
      LRow := cxVerticalGrid1.Rows[LIdx];
      if not (LRow is TcxCategoryRow) then
        Continue;
      LAny := False;
      for LChild := 0 to LRow.Count - 1 do
        if LRow.Rows[LChild].Visible then
        begin
          LAny := True;
          Break;
        end;
      SetRowVisible(LRow, LAny);
    end;
  finally
    TcxRowsAccess(cxVerticalGrid1.Rows).EndUpdate;
  end;
end;

procedure TfrmSetting.FilterByNav;
var
  LTarget: TcxCustomRow;

  procedure ShowTree(ARow: TcxCustomRow; AVisible: Boolean);
  var
    LIdx: Integer;
  begin
    SetRowVisible(ARow, AVisible);
    for LIdx := 0 to ARow.Count - 1 do
      ShowTree(ARow.Rows[LIdx], AVisible);
  end;

var
  LIdx: Integer;
begin
  // Etkin alt grup varsa onun agaci, yoksa etkin kategorinin agaci gorunur.
  if FSubRow <> nil then
    LTarget := FSubRow
  else
    LTarget := FCatRow;

  TcxRowsAccess(cxVerticalGrid1.Rows).BeginUpdate;
  try
    for LIdx := 0 to cxVerticalGrid1.Rows.Count - 1 do
      SetRowVisible(cxVerticalGrid1.Rows[LIdx], LTarget = nil);

    if LTarget <> nil then
    begin
      ShowTree(LTarget, True);
      // Hedefin ustundeki kategoriler de gorunmeli, yoksa agac kopar.
      LTarget := LTarget.Parent;
      while LTarget <> nil do
      begin
        SetRowVisible(LTarget, True);
        LTarget := LTarget.Parent;
      end;
    end;
  finally
    TcxRowsAccess(cxVerticalGrid1.Rows).EndUpdate;
  end;
end;

procedure TfrmSetting.ShowInfo(AItem: TRadSettingItem);
begin
  if AItem = nil then
  begin
    lblID.Caption     := '';
    lblBaslik.Caption := '';
    lblGrup.Caption   := '';
    lblInfo.Caption   := '';
    Exit;
  end;
  lblID.Caption     := AItem.Key;
  lblBaslik.Caption := AItem.Title;
  lblGrup.Caption   := AItem.Path;
  lblInfo.Caption   := AItem.Info;
end;

// -- olaylar ---------------------------------------------------------------

procedure TfrmSetting.DoValueChanged(Sender: TObject;
  ARowProperties: TcxCustomEditorRowProperties);
var
  LItem: TRadSettingItem;
begin
  // Refresh satira yaziyor, satir bu olayi tetikliyor, olay depoya yaziyor...
  // Sayac olmadan bu dongu kapanmiyor.
  if FUpdating > 0 then
    Exit;
  if ARowProperties = nil then
    Exit;
  if not FByRow.TryGetValue(ARowProperties, LItem) then
    Exit;
  // Value, TcxEditorRowProperties'te published; olayin verdigi ATA turde
  // (TcxCustomEditorRowProperties) protected. Kurdugumuz satirlarin hepsi
  // TcxEditorRow oldugu icin donusum guvenli, ama yine de denetleniyor.
  if not (ARowProperties is TcxEditorRowProperties) then
    Exit;

  Inc(FUpdating);
  try
    LItem.SetValue(TcxEditorRowProperties(ARowProperties).Value);
    FModified := True;
  finally
    Dec(FUpdating);
  end;
end;

procedure TfrmSetting.DoRowChanged(Sender: TObject; AOldRow: TcxCustomRow;
  AOldCellIndex: Integer);
var
  LRow  : TcxCustomRow;
  LItem : TRadSettingItem;
begin
  LRow := cxVerticalGrid1.FocusedRow;
  if not (LRow is TcxEditorRow) then
  begin
    ShowInfo(nil);
    Exit;
  end;
  if FByRow.TryGetValue(TcxEditorRow(LRow).Properties, LItem) then
    ShowInfo(LItem)
  else
    ShowInfo(nil);
end;

procedure TfrmSetting.DoSearchChanged(Sender: TObject);
begin
  Search(edtSearch.Text);
end;

procedure TfrmSetting.DoNavClick(Sender: TObject; ALink: TdxNavBarItemLink);
var
  LIdx: Integer;
begin
  if (ALink = nil) or (ALink.Item = nil) then
    Exit;

  // Tiklanan ogeye karsilik gelen alt grup satirini bul: NavBar oge sirasi
  // ile alt grup satirlarinin sirasi ayni kurulum sirasindan gelir, ama
  // eslesmeyi BASLIKTAN yapmak daha dayanikli.
  FSubRow := nil;
  for LIdx := 0 to cxVerticalGrid1.Rows.Count - 1 do
    if (cxVerticalGrid1.Rows[LIdx] is TcxCategoryRow) and
       SameText(TcxCategoryRow(cxVerticalGrid1.Rows[LIdx]).Properties.Caption,
                ALink.Item.Caption) then
    begin
      FSubRow := TcxCategoryRow(cxVerticalGrid1.Rows[LIdx]);
      Break;
    end;

  edtSearch.Text := '';
  FilterByNav;
end;

end.
