unit Help.Dev;

interface

uses
Winapi.Windows,System.SysUtils,System.UITypes,System.Classes,Vcl.Graphics,Vcl.Menus, Data.DB,System.Rtti,
Vcl.Controls,Vcl.Dialogs,Generics.Collections

,rad.db, rad.sqlfilter
,dxCore, dxCoreGraphics, dxGDIPlusApi,
cxLookAndFeels,cxLookAndFeelPainters, dxSkinsCore, dxSkinsLookAndFeelPainter,

cxNavigator, cxDBNavigator,
cxEdit, cxButtonEdit, cxMaskEdit, cxTextEdit, cxSpinEdit, cxDBEdit,
cxImageComboBox,


cxTL,cxDBTL,

cxGrid, cxVGrid, cxGridTableView, cxGridCustomView, cxGridCustomTableView, cxGridDBTableView,

cxGridDBDataDefinitions,cxGridLayoutView,cxGridDetachedEditForm,cxGridInplaceEditForm



;

type
     TcxGridDetachedEditFormAcces =class (TcxGridDetachedEditForm);

    TcxRootLookAndFeelhelp = class helper for TcxCustomLookAndFeelController
      function _AsVariant: Variant;
      (* Uc'u de FONKSIYON olarak bildirilmisti ama hicbiri Result'a bir sey
         atamiyordu (W1035) - "LSkin := X._Load;" yazan biri COP bir isaretci
         alirdi. Tek cagiran (dm.dev.pas) zaten deyim olarak kullaniyor, yani
         prosedure cevirmek hicbir kullanimi bozmuyor. *)
      procedure _FromVariant(v: variant);
      procedure _Save;
      procedure _Load;
    end;

    TcxCustomTextEditHelp = class helper for TcxCustomTextEdit
     function _DataSet:TDataSet;
     function _Field:TField;
     function _GridItem:TcxCustomGridTableItem;
     Function _ColDB:TcxGridDBColumn;
     /// <summary>Bu editorun "sahibi": gridde inplace ise ilgili KOLON,
     /// degilse editorun kendisi. Paylasilan bir RepositoryItem uzerinden
     /// calisan ortak bir olay isleyicisinin "su an kimi sunuyorum"
     /// sorusuna verdigi cevap budur.</summary>
     /// <remarks>Neden gerekli: bir RepositoryItem'a bagli TUM tuketiciler
     /// Properties'in AYNI ornegini paylasir (olculdu), dolayisiyla
     /// Sender/Properties'e bakarak tuketici ayirt edilemez.</remarks>
     function _Host: TComponent;
   end;

    (* Paylasilan bir edit repository item'ini KULLANAN bilesenleri bulur.

       Stok DevExpress item'leriyle de calisir: dinleyici listesi
       TcxEditRepositoryItem'da strict private oldugu icin okunamaz, bu yuzden
       burada bilesen agaci TARANIR. Tam ve ucuz yol torun sinifta
       (Rad.Dev'deki TRadEditRepositoryItem.ConsumerCount/Consumers) - o
       AddListener'i override ederek gercek listeyi tutar. Buradaki tarama
       o torune ihtiyac duymayan genel kullanim icindir.

       SINIR: tarama, ARoot'un bilesen agaci ile gridlerin View/Item
       agaclarini gezer. IDE'de tasarlanmis formlarda kolonlar zaten formun
       bilesenidir; calisma zamaninda uretilmis ve hicbir gride bagli olmayan
       bir kolon bulunamaz. *)
    TcxEditRepositoryItemHelp = class helper for TcxEditRepositoryItem
      /// <summary>AConsumer (editor ya da grid kolonu) bu item'i mi kullaniyor?</summary>
      function _IsUsedBy(AConsumer: TComponent): Boolean;
      /// <summary>ARoot altinda bu item'i kullanan editor ve kolonlar.
      /// ARoot bos birakilirsa item'in kendi Owner'i taranir.</summary>
      function _Consumers(ARoot: TComponent = nil): TArray<TComponent>;
      /// <summary>_Consumers'in uzunlugu.</summary>
      function _ConsumerCount(ARoot: TComponent = nil): Integer;
    end;

    TcxSpinEditHelper = class helper for TcxCustomSpinEdit
      procedure _DownButton(const BtnIndex: Integer =
        cxSpinBackwardButtonIndex);
      procedure _ValueUp;
      procedure _ValueDown;
    end;

    TcxImageComboBoxItemsHelp = class helper for TcxImageComboBoxItems
      function _Add(const AImg: Integer; const ADescription: string; const AValue: Variant; const ATag: Integer = 0): TcxImageComboBoxItem;
    end;

    TcxNavigatorControlButtonsHelper = class helper for TcxCustomNavigatorButtons
      procedure _TR;
      procedure _Visible(const AutoCmds: TRadQueryCmds);
    end;

    TcxGridTableOptionsDataHelper = class helper for TcxGridTableOptionsData

    end;

    TcxCustomGridTableViewhelper = class helper for TcxCustomGridTableView
    public
      function _EditMode(const IsEdit:Boolean) :TcxCustomGridTableView;
    end;

(*  ── Tuketici erisimcileri ────────────────────────────────────────────────
    Bir zincir/ortak olay isleyicisinin elinde bir TComponent olur - ama bu
    bilesen formdaki bir EDITOR de olabilir, bir GRID KOLONU da. Asagidaki
    yordamlar ikisini de kabul eder ve ayirt etmeyi cagirandan alir.

    _OwnProperties NEDEN ONEMLI: bir RepositoryItem'a bagli tum tuketiciler
    Properties'in AYNI ornegini paylasir; ama her tuketici KENDI Properties
    nesnesini de korur ve o nesne DFM'e yazilir (olculdu, DfmRoundTripTest).
    Yani "ortak davranis = item, yere ozel yuk = kendi Properties" deseni
    calisir. Bu yordam o yere ozel nesneyi verir - ActiveProperties/
    GetProperties ise PAYLASILAN olani verir, ikisi karistirilmamalidir.

    ! Grid kolonunda kendi Properties nesnesi ancak PropertiesClass (ya da
      DFM'de PropertiesClassName) atanmissa OLUSUR; atanmamissa nil doner.  *)

/// <summary>Tuketicinin KENDI Properties nesnesi (paylasilan degil).
/// Kolonda PropertiesClass atanmamissa nil doner.</summary>
function _OwnProperties(AConsumer: TComponent): TcxCustomEditProperties;
/// <summary>Tuketicinin ETKIN Properties'i - repository item varsa onunki.</summary>
function _ActiveProperties(AConsumer: TComponent): TcxCustomEditProperties;
/// <summary>Editorun EditValue'su; kolonda odakli kaydin degeri.</summary>
function _ValueOf(AConsumer: TComponent): Variant;
/// <summary>Kolonun Caption'i; editorde bagli kolonunki, yoksa bilesen adi.</summary>
function _CaptionOf(AConsumer: TComponent): string;
/// <summary>Bagli TDataSet; cozulemezse nil.</summary>
function _DataSetOf(AConsumer: TComponent): TDataSet;
/// <summary>Bagli TField; cozulemezse nil.</summary>
function _FieldOf(AConsumer: TComponent): TField;
/// <summary>Odagin bulundugu editor; yoksa nil. Odak editorun IC denetimindedir (TcxCustomInnerTextEdit),
/// bu yuzden 'ActiveControl is TcxCustomEdit' her zaman False'tur; bu islev yerine kullanilir.</summary>
function _ActiveEdit: TcxCustomEdit;
/// <summary>Editorun degerini filtre kosuluna cevirir; bos editor kosul yazmaz. TcxTextEdit, TcxMaskEdit,
/// TcxButtonEdit: Contains (harf duyarsiz). TcxCheckComboBox: isaretli Description'lar InList. Digerleri: Equal.
/// TcxCheckBox AllowGrayed olmali (gri = bos); yoksa isaretsiz durum False kosulu yazar.</summary>
procedure _EditToFilter(const AFilter: IRadSqlFilter; const AField: string; AEdit: TcxCustomEdit);
/// <summary>Editor degerini dilden bagimsiz saklanacak bicimde verir. TcxCheckComboBox: isaretli Description'lar
/// JSON dizisi (["TRY","USD"]; EditValue DevExpress'e ozgu ";3:TRY3:USD" bicimindedir). Digerleri: EditValue.</summary>
function _EditGetValue(AEdit: TcxCustomEdit): Variant;
/// <summary>_EditGetValue degerini editore yazar; JSON'dan metin donen tarihi (yyyy-mm-dd...) TDate'e cevirir.</summary>
procedure _EditSetValue(AEdit: TcxCustomEdit; const AValue: Variant);




type
  (* DevExpress skin renklerinin, DevExpress OLMAYAN bilesenler (scControls, TMS...) icin
     anlamsal karsiliklari. Bilesenler DevExpress'in renk adlarini bilmez, yalniz bu
     alanlari okur. Skin ya da palet degisince Init'in kaydettigi dinleyici alanlari
     yeniler ve OnChanged'i tetikler.

     Kullanim: acilista bir kez TSkinRenk.Init; sonra SkinRenk.Content gibi oku. Skin yoksa
     (VCLStyle, UseSkins kapali) sistem renkleri kalir. *)
  TSkinRenk = record
    HeaderFill, HeaderBorder, HeaderText,
    Content, ContentText,
    Selection, SelectionText, SearchHighlight, SearchHighlightText: TColor;
    /// <summary>Renkler yenilendikten sonra, ana thread'de cagrilir.</summary>
    class var OnChanged: TNotifyEvent;
    /// <summary>Renkleri ilk kez doldurur ve skin degisimine kaydolur (tekrar cagri zararsiz).</summary>
    class procedure Init; static;
    /// <summary>Renkleri skinden yeniden okur. Dinleyici bunu kendisi cagirir; elle gerekirse acik.</summary>
    class procedure Yenile; static;
  end;

var
  SkinRenk: TSkinRenk;

implementation
 uses
 Vcl.Forms, System.Variants, cxCheckComboBox, cxCalendar,
 rad,
 mormot.core.base,mormot.core.variants, mormot.core.text
 ;

type
  (* TcxCustomEdit.Properties PROTECTED'tir (cxEdit.pas) - her somut editor
     onu kendi tipiyle yeniden bildirir. Genel bir yordam taban uzerinden
     erisemez; erisim sinifi bu dosyanin zaten kullandigi deyim
     (bkz. TcxGridDetachedEditFormAcces). *)
  TcxCustomEditAccess = class(TcxCustomEdit);
{ TcxRootLookAndFeelhelp }

function TcxRootLookAndFeelhelp._AsVariant: Variant;
begin
 ObjectToVariant(Self,Result, [woStoreStoredFalse]); //woEnumSetsAsText
 TDocVariantData(Result).Delete(['Name','Tag','OnPopupSysMenu','OnSkinControl','OnSkinForm']);
end;

procedure TcxRootLookAndFeelhelp._FromVariant( v: variant);
begin
   try
    Self.BeginUpdate;
    TcxRootLookAndFeel.Instance.BeginUpdate;
    DocVariantToObject(TDocVariantData(v),self);
  finally
    TcxRootLookAndFeel.Instance.EndUpdate;
    Self.EndUpdate;
    TdxVisualRefinements.LightStyleMode := lsmOnlyBorders;
   end;

end;



procedure TcxRootLookAndFeelhelp._Load;
begin
 _FromVariant(Config.GetValue('skin',varNull));
end;

procedure TcxRootLookAndFeelhelp._Save;
begin
   Config.SetValue('skin',_AsVariant);
end;

{ TcxNavigatorControlButtonsHelper }

procedure TcxNavigatorControlButtonsHelper._TR;
Procedure up(Btn:TcxNavigatorButton;Img:Byte;Hints:String);
begin
  Btn.ImageIndex:=Img;
  Btn.Hint:=Hints;
end;
begin

    Up(Self.Append,0,'Kay�t Ekle');
    Up(Self.Cancel,1,'D�zenlemeyi �ptal Et');
    Up(Self.Delete,2,'Aktif Kayd� Sil');
    Up(Self.Edit,3,'Kayd� D�zenle');
    Up(Self.Filter,4,'Filtre Olu�tur');
    Up(Self.First,5,'�lk Kay�t');
    Up(Self.GotoBookmark,6,'Yerimi ne git');
    Up(Self.Insert,7,'Kay�t Ekle');
    Up(Self.Last,8,'Son Kay�t');
    Up(Self.Next,9,'Sonraki Kay�t');
    Up(Self.NextPage,10,'Sonraki Sayfa');
    Up(Self.Post,11,'Kaydet');
    Up(Self.Prior,12,'�nceki kay�t');
    Up(Self.PriorPage,13,'�nceki Sayfa');
    Up(Self.Refresh,14,'Yenile');
    Up(Self.SaveBookmark,15,'Yerimi Kaydet');
    Self.GotoBookmark.Visible:=False;
    Self.SaveBookmark.Visible:=False;
    Self.NextPage.Visible:=False;
    Self.PriorPage.Visible:=False;

end;

procedure TcxNavigatorControlButtonsHelper._Visible(const AutoCmds: TRadQueryCmds);
begin
      Insert.Visible:=not (rcNoInsert in AutoCmds);
      Append.Visible:=Insert.Visible;

      Delete.Visible:=not (rcNoDelete in AutoCmds);

      Edit.Visible:=not (rcNoEdit in AutoCmds);
      Post.Visible:=Edit.Visible;
      Cancel.Visible:=Edit.Visible;
end;

{ TcxSpinEditHelper }

procedure TcxSpinEditHelper._DownButton(const BtnIndex: Integer);
begin
  Self.Increment(TcxSpinEditButton(BtnIndex));
  Self.PostEditValue;

end;

procedure TcxSpinEditHelper._ValueDown;
begin
  _DownButton(0);
end;

procedure TcxSpinEditHelper._ValueUp;
begin
_DownButton(1);
end;

{ TcxImageComboBoxItemsHelp }

  function TcxImageComboBoxItemsHelp._Add(const AImg: Integer; const ADescription: string; const AValue: Variant; const ATag: Integer):
    TcxImageComboBoxItem;
  begin
    Result := Add;
    Result.ImageIndex := AImg;
    Result.Description := ADescription;
    Result.Value := AValue;
    Result.Tag := ATag;
  end;

{ TcxCustomTextEditHelp }

  function TcxCustomTextEditHelp._ColDB: TcxGridDBColumn;
  var
    LItem: TcxCustomGridTableItem;
  begin
    { Sert cast yerine denetimli: _GridItem nil de donebilir, DB OLMAYAN bir
      kolon da (TdxLayoutControl dalinda GridViewItem herhangi bir item
      olabilir). Ikisinde de nil dogru cevap. }
    Result := nil;
    LItem := _GridItem;
    if LItem is TcxGridDBColumn then
      Result := TcxGridDBColumn(LItem);
  end;

  function TcxCustomTextEditHelp._DataSet: TDataSet;
  var
    LCol: TcxGridDBColumn;
  begin
    { Eskiden: _ColDB nil oldugunda (gridde inplace OLMAYAN her editor - yani
      formdaki siradan bir combo) dogrudan nil uzerinden alan zinciri
      cozuluyor ve ERISIM IHLALI aliniyordu. Artik her adim korunuyor. }
    Result := nil;
    (* HER DB editoru: DataBinding'i TcxDBEditDataBinding olan editor (formdaki
       TcxDBComboBox, TRadDBComboBox, TcxDBButtonEdit ...). Eskiden yalnizca
       TcxDBButtonEdit taniniyordu; digerleri nil donuyordu. Ayni sinama
       GetcxDBEditDataLink'te de var (cxDBEdit.pas:1389-1395). Gridin hucre
       editoru DB editoru DEGILDIR ve asagidaki kolon yoluna duser. *)
    if TcxCustomEditAccess(Self).DataBinding is TcxDBEditDataBinding then
    begin
      if TcxDBEditDataBinding(TcxCustomEditAccess(Self).DataBinding).DataSource <> nil then
        Result := TcxDBEditDataBinding(TcxCustomEditAccess(Self).DataBinding).DataSource.DataSet;
      Exit;
    end;

    LCol := _ColDB;
    if (LCol <> nil) and (LCol.DataBinding <> nil) and
       (LCol.DataBinding.DataController <> nil) and
       (LCol.DataBinding.DataController.DataSource <> nil) then
      Result := LCol.DataBinding.DataController.DataSource.DataSet;
  end;

  function TcxCustomTextEditHelp._Field: TField;
  var
    LCol: TcxGridDBColumn;
  begin
    { Eskiden: TcxDBButtonEdit DISINDAKI her editor icin Result TANIMSIZ
      kaliyordu (W1035) - cagirana cop bir isaretci gidiyordu. Simdi hem
      baslatiliyor hem de grid kolonu yolu ekli. }
    Result := nil;
    { Her DB editoru - bkz. _DataSet'teki not. }
    if TcxCustomEditAccess(Self).DataBinding is TcxDBEditDataBinding then
      Exit(TcxDBEditDataBinding(TcxCustomEditAccess(Self).DataBinding).Field);

    LCol := _ColDB;
    if (LCol <> nil) and (LCol.DataBinding <> nil) then
      Result := LCol.DataBinding.Field;
  end;

  function TcxCustomTextEditHelp._GridItem: TcxCustomGridTableItem;
  begin
    { Result BASLATILMALI: iki dal da tutmazsa (grid disi bir editor)
      donen deger TANIMSIZ kaliyordu - W1035. Cagiran 'nil mi' diye
      baktiginda cop bir isaretci gecip erisim ihlali uretebilirdi. }
    Result := nil;
    (* OLCULDU (RuntimeTest): burasi eskiden yalnizca TcxGridDBColumn'u
       kabul ediyordu. Veri BAGLI OLMAYAN bir gorunumun kolonu
       TcxGridColumn'dur, TcxGridDBColumn degil - o durumda _GridItem nil
       donuyor, _Host da kolon yerine editorun kendisini veriyordu.
       Donus tipi zaten TcxCustomGridTableItem; taban tipe genisletmek hem
       dogru hem de DB kolonlarini kapsamaya devam ediyor. *)
    if TcxCustomEdit(self).InplaceParams.Position.Item is TcxCustomGridTableItem then
      begin
        Result :=
          TcxCustomGridTableItem(TcxCustomEdit(self).InplaceParams.Position.Item)
      end
    (* Detached edit form: DevExpress oradaki editorun Tag'ine layout item'i
       koyar (cxGridDetachedEditForm.pas:286, kendi GetLayoutItem'i). Eskiden
       HER TdxLayoutControl'deki editor boyle sayiliyordu - formdaki siradan
       bir layout control'de Tag = 0 iken nil, dolu iken rastgele bir adres
       cast ediliyordu; Parent'siz editorde de Parent.ClassName AV veriyordu
       (DxAuditTest H01/H02). Artik editorun formu gercekten o form mu diye
       bakiliyor. *)
    else if (Self.Tag <> 0) and
            (GetParentForm(Self) is TcxGridCustomDetachedEditForm) then
      Result := TcxGridDetachedEditFormLayoutItem(Self.Tag).GridViewItem;
  end;

{ Tuketici erisimcileri }

function _OwnProperties(AConsumer: TComponent): TcxCustomEditProperties;
begin
  Result := nil;
  if AConsumer is TcxCustomEdit then
    Result := TcxCustomEditAccess(AConsumer).Properties
  else if AConsumer is TcxCustomGridTableItem then
    { Kolonda published Properties = KENDI nesnesi; PropertiesClass
      atanmamissa nil'dir. Etkin olani GetProperties verir. }
    Result := TcxCustomGridTableItem(AConsumer).Properties;
end;

function _ActiveProperties(AConsumer: TComponent): TcxCustomEditProperties;
begin
  Result := nil;
  if AConsumer is TcxCustomEdit then
    Result := TcxCustomEdit(AConsumer).ActiveProperties
  else if AConsumer is TcxCustomGridTableItem then
    Result := TcxCustomGridTableItem(AConsumer).GetProperties;
end;

function _ValueOf(AConsumer: TComponent): Variant;
begin
  Result := Null;
  if AConsumer is TcxCustomEdit then
    Result := TcxCustomEdit(AConsumer).EditValue
  else if AConsumer is TcxCustomGridTableItem then
    Result := TcxCustomGridTableItem(AConsumer).EditValue;
end;

function _CaptionOf(AConsumer: TComponent): string;
var
  LItem: TcxCustomGridTableItem;
begin
  Result := '';
  if AConsumer = nil then
    Exit;
  if AConsumer is TcxCustomGridTableItem then
    Exit(TcxCustomGridTableItem(AConsumer).Caption);
  if AConsumer is TcxCustomTextEdit then
  begin
    { Editorun Caption'i yoktur; gridde inplace ise bagli kolonunki anlamli. }
    LItem := TcxCustomTextEdit(AConsumer)._GridItem;
    if LItem <> nil then
      Exit(LItem.Caption);
  end;
  Result := AConsumer.Name;
end;

function _DataSetOf(AConsumer: TComponent): TDataSet;
var
  LCol: TcxGridDBColumn;
begin
  Result := nil;
  if AConsumer is TcxCustomTextEdit then
    Exit(TcxCustomTextEdit(AConsumer)._DataSet);
  if AConsumer is TcxGridDBColumn then
  begin
    LCol := TcxGridDBColumn(AConsumer);
    if (LCol.DataBinding <> nil) and (LCol.DataBinding.DataController <> nil) and
       (LCol.DataBinding.DataController.DataSource <> nil) then
      Result := LCol.DataBinding.DataController.DataSource.DataSet;
  end;
end;

function _ActiveEdit: TcxCustomEdit;
var
  LControl: TWinControl;
begin
  LControl := Screen.ActiveControl;
  while (LControl <> nil) and not (LControl is TcxCustomEdit) do
    LControl := LControl.Parent;
  Result := TcxCustomEdit(LControl);
end;

function CheckedDescriptions(AEdit: TcxCustomCheckComboBox): TArray<Variant>;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to AEdit.ActiveProperties.Items.Count - 1 do
    if AEdit.States[i] = cbsChecked then
      Result := Result + [Variant(AEdit.ActiveProperties.Items[i].Description)];
end;

procedure _EditToFilter(const AFilter: IRadSqlFilter; const AField: string; AEdit: TcxCustomEdit);
begin
  if AEdit is TcxCustomCheckComboBox then
    AFilter.InList(AField, CheckedDescriptions(TcxCustomCheckComboBox(AEdit)))
  else if (AEdit is TcxTextEdit) or (AEdit is TcxMaskEdit) or (AEdit is TcxButtonEdit) then
    AFilter.Contains(AField, VarToStr(AEdit.EditValue), rcInsensitive)
  else
    AFilter.Equal(AField, AEdit.EditValue);
end;

function _EditGetValue(AEdit: TcxCustomEdit): Variant;
var
  V: Variant;
begin
  if AEdit is TcxCustomCheckComboBox then
  begin
    TDocVariant.NewFast(Result, dvArray);
    for V in CheckedDescriptions(TcxCustomCheckComboBox(AEdit)) do
      TDocVariantData(Result).AddItem(V);
  end
  else
    Result := AEdit.EditValue;
end;

procedure SetCheckedDescriptions(AEdit: TcxCustomCheckComboBox; const AValue: Variant);
var
  i, j: Integer;
  LDizi: PDocVariantData;
  LIsaretli: Boolean;
begin
  LDizi := _Safe(AValue);
  for i := 0 to AEdit.ActiveProperties.Items.Count - 1 do
  begin
    LIsaretli := False;
    for j := 0 to LDizi^.Count - 1 do
      LIsaretli := LIsaretli or (VarToStr(LDizi^.Values[j]) = AEdit.ActiveProperties.Items[i].Description);
    if LIsaretli then
      AEdit.States[i] := cbsChecked
    else
      AEdit.States[i] := cbsUnchecked;
  end;
end;

procedure _EditSetValue(AEdit: TcxCustomEdit; const AValue: Variant);
var
  LFormat: TFormatSettings;
begin
  if AEdit is TcxCustomCheckComboBox then
    SetCheckedDescriptions(TcxCustomCheckComboBox(AEdit), AValue)
  else if (AEdit is TcxCustomDateEdit) and VarIsStr(AValue) then
  begin
    LFormat := TFormatSettings.Invariant;
    LFormat.DateSeparator := '-';
    LFormat.ShortDateFormat := 'yyyy-mm-dd';
    AEdit.EditValue := StrToDate(Copy(VarToStr(AValue), 1, 10), LFormat);
  end
  else
    AEdit.EditValue := AValue;
end;

function _FieldOf(AConsumer: TComponent): TField;
begin
  Result := nil;
  if AConsumer is TcxCustomTextEdit then
    Exit(TcxCustomTextEdit(AConsumer)._Field);
  if AConsumer is TcxGridDBColumn then
    if TcxGridDBColumn(AConsumer).DataBinding <> nil then
      Result := TcxGridDBColumn(AConsumer).DataBinding.Field;
end;

{ TcxCustomTextEditHelp - _Host }

function TcxCustomTextEditHelp._Host: TComponent;
begin
  Result := _GridItem;
  if Result = nil then
    Result := Self;
end;

{ TcxEditRepositoryItemHelp }

function TcxEditRepositoryItemHelp._IsUsedBy(AConsumer: TComponent): Boolean;
begin
  Result := False;
  if AConsumer = nil then
    Exit;
  if AConsumer is TcxCustomEdit then
    Result := TcxCustomEdit(AConsumer).RepositoryItem = Self
  else if AConsumer is TcxCustomGridTableItem then
    Result := TcxCustomGridTableItem(AConsumer).RepositoryItem = Self;
end;

function TcxEditRepositoryItemHelp._Consumers(ARoot: TComponent): TArray<TComponent>;
var
  LFound: TList<TComponent>;

  procedure Ekle(AComp: TComponent);
  begin
    if _IsUsedBy(AComp) and (LFound.IndexOf(AComp) < 0) then
      LFound.Add(AComp);
  end;

  procedure TaraGrid(AGrid: TcxCustomGrid);
  var
    v, i: Integer;
    LView: TcxCustomGridView;
  begin
    for v := 0 to AGrid.ViewCount - 1 do
    begin
      LView := AGrid.Views[v];
      if LView is TcxCustomGridTableView then
        for i := 0 to TcxCustomGridTableView(LView).ItemCount - 1 do
          Ekle(TcxCustomGridTableView(LView).Items[i]);
    end;
  end;

  procedure Tara(AComp: TComponent);
  var
    i: Integer;
  begin
    if AComp = nil then
      Exit;
    for i := 0 to AComp.ComponentCount - 1 do
    begin
      Ekle(AComp.Components[i]);
      { Grid kolonlari her zaman formun bileseni olmayabilir - gorunumlerin
        kendi Item listesine de bakiyoruz. }
      if AComp.Components[i] is TcxCustomGrid then
        TaraGrid(TcxCustomGrid(AComp.Components[i]));
      Tara(AComp.Components[i]);
    end;
  end;

begin
  if ARoot = nil then
    ARoot := Self.Owner;
  LFound := TList<TComponent>.Create;
  try
    Tara(ARoot);
    Result := LFound.ToArray;
  finally
    LFound.Free;
  end;
end;

function TcxEditRepositoryItemHelp._ConsumerCount(ARoot: TComponent): Integer;
begin
  Result := Length(_Consumers(ARoot));
end;

{ TSkinRenk }

type
  (* RootLookAndFeel'e AddChangeListener ile kaydolur: skin adi, palet ya da UseSkins degisince
     MasterLookAndFeelChanged gelir. Referans sayimsiz (-1): TcxLookAndFeel arayuzu Supports ile
     sorgular, sayimli olsaydi her sorgu nesneyi serbest birakirdi. *)
  TSkinRenkDinleyici = class(TObject, IcxLookAndFeelNotificationListener)
  private
    function GetObject: TObject;
    procedure MasterLookAndFeelChanged(Sender: TcxLookAndFeel; AChangedValues: TcxLookAndFeelValues);
    procedure MasterLookAndFeelDestroying(Sender: TcxLookAndFeel);
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  end;

var
  GDinleyici: TSkinRenkDinleyici;
  GKayitli: Boolean;

function TSkinRenkDinleyici.GetObject: TObject;
begin
  Result := Self;
end;

procedure TSkinRenkDinleyici.MasterLookAndFeelChanged(Sender: TcxLookAndFeel; AChangedValues: TcxLookAndFeelValues);
begin
  TSkinRenk.Yenile;
end;

procedure TSkinRenkDinleyici.MasterLookAndFeelDestroying(Sender: TcxLookAndFeel);
begin
  GKayitli := False;
end;

function TSkinRenkDinleyici.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;
end;

function TSkinRenkDinleyici._AddRef: Integer;
begin
  Result := -1;
end;

function TSkinRenkDinleyici._Release: Integer;
begin
  Result := -1;
end;

function SkinRengiBul(ASkin: TdxSkin; const AAdlar: array of string; ADefault: TColor): TColor;
var
  LAd: string;
  LRenk: TdxSkinColor;
begin
  Result := ADefault;
  if ASkin = nil then
    Exit;
  // out asiri yuklemesi: bulunamazsa nil doner, .Value'da access violation olmaz.
  for LAd in AAdlar do
    if ASkin.GetColorByName(LAd, LRenk) then
      Exit(LRenk.Value);
end;

class procedure TSkinRenk.Yenile;
var
  LPainter: TcxCustomLookAndFeelPainter;
  LSkin: TdxSkin;
begin
  LSkin := nil;
  LPainter := RootLookAndFeel.Painter;
  if LPainter is TdxSkinLookAndFeelPainter then
    LSkin := TdxSkinLookAndFeelPainter(LPainter).SkinInfo.Skin;

  SkinRenk.HeaderFill       := SkinRengiBul(LSkin, ['ContainerBorderColor'], clBtnFace);
  SkinRenk.HeaderBorder     := SkinRengiBul(LSkin, ['ContainerHighlightBorderColor'], clBtnShadow);
  SkinRenk.HeaderText       := SkinRengiBul(LSkin, ['ContentTextColor'], clBtnText);
  SkinRenk.Content          := SkinRengiBul(LSkin, ['ContentColor', 'ContentEvenColor'], clWindow);
  SkinRenk.ContentText      := SkinRengiBul(LSkin, ['ContentTextColor'], clWindowText);
  SkinRenk.Selection        := SkinRengiBul(LSkin, ['SelectionColor'], clHighlight);
  SkinRenk.SelectionText    := SkinRengiBul(LSkin, ['SelectionTextColor'], clHighlightText);
  SkinRenk.SearchHighlight  := SkinRengiBul(LSkin, ['SearchResultHighlightColor'], clYellow);
  SkinRenk.SearchHighlightText := SkinRengiBul(LSkin, ['SearchResultHighlightTextColor'], clBlack);

  if Assigned(TSkinRenk.OnChanged) then
    TSkinRenk.OnChanged(nil);
end;

class procedure TSkinRenk.Init;
begin
  if not GKayitli then
  begin
    if GDinleyici = nil then
      GDinleyici := TSkinRenkDinleyici.Create;
    RootLookAndFeel.AddChangeListener(GDinleyici);
    GKayitli := True;
  end;
  Yenile;
end;



{ TcxCustomGridTableViewhelper }

function TcxCustomGridTableViewhelper._EditMode( const IsEdit: Boolean): TcxCustomGridTableView;
begin
 OptionsSelection.CellSelect:=IsEdit;
 //OptionsData.Deleting:=IsEdit;
 OptionsData.Deleting:=IsEdit;
 OptionsData.Editing:=IsEdit;
 OptionsData.Inserting:=IsEdit;
end;

initialization
finalization
  // cxLookAndFeels bu birimden SONRA sonlanir (uses'ta), kok hala yasiyor.
  if GKayitli and (GDinleyici <> nil) then
    RootLookAndFeel.RemoveChangeListener(GDinleyici);
  GDinleyici.Free;

end.

