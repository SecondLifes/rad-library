unit rad.dev.customfields;

{ Özel alan çerçevesi: tanımları (rad.customfield) okur, her alan için DB-bağlı
  DevExpress editörü yaratıp DFM'deki TdxLayoutControl'e yerleştirir; kategori = sekme.
  Statik parça (layout, alt çubuk, düğmeler) DFM'de; sekme/item/editör tanımdan geldiği
  için her zaman kodla. Düzen kullanıcı başına Store'da saklanır. "Ayar" düğmesi
  tanım diyaloğunu (rad.dev.customfielddesigner) açar. Filtre kipinde (Mode = cfmFilter)
  editörler bağsızdır ve ApplyFilter değerleri IRadSqlFilter'a koşul olarak yazar.
  Spec: docs/specs/rad.customfield.md. }

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Variants, System.UITypes,
  System.Generics.Collections, Vcl.Controls, Vcl.Forms, Vcl.ExtCtrls, Vcl.Graphics, Data.DB,
  cxGraphics, cxControls, cxLookAndFeels, cxLookAndFeelPainters, cxContainer, cxEdit, cxTextEdit,
  cxMaskEdit, cxDropDownEdit, cxCalendar, cxCurrencyEdit, cxCalc, cxSpinEdit, cxCheckBox,
  cxImageComboBox, cxMemo, cxTimeEdit, cxDBEdit, cxButtons, cxCheckComboBox, cxClasses,
  dxLayoutContainer, dxLayoutControl, dxLayoutcxEditAdapters, dxLayoutControlAdapters,
  rad.sqlfilter, rad.customfield, rad.dev, Vcl.Menus, Vcl.StdCtrls,
  System.ImageList, Vcl.ImgList, cxImageList;

type
  /// <summary>cfmEdit: DB-bağlı editörler, kayıt düzenleme. cfmFilter: bağsız editörler, ApplyFilter.</summary>
  TRadCustomFieldsMode = (cfmEdit, cfmFilter);

  TRadCustomFieldsFrame = class(TFrame)
    lcRadCustomFields: TdxLayoutControl;
    lcRadCustomFieldsGroup_Root: TdxLayoutGroup;
    pnlBar: TPanel;
    btnDesign: TcxButton;
    PopupOzelAlanMenu: TPopupMenu;
    Ayar1: TMenuItem;
    Dzenle1: TMenuItem;
    Kaydet1: TMenuItem;
    DzeniSfrla1: TMenuItem;
    cxImgOzelAlan: TcxImageList;
    procedure Ayar1Click(Sender: TObject);
    procedure btnDesignClick(Sender: TObject);
    procedure DzeniSfrla1Click(Sender: TObject);
    procedure Dzenle1Click(Sender: TObject);
    procedure Kaydet1Click(Sender: TObject);
  private
    FTableName: string;
    FDataSource: TDataSource;
    FStore: IRadCustomFieldStore;
    FUserId: Integer;
    FCanDesign: Boolean;
    FAutoValidate: Boolean;
    FAutoDefaults: Boolean;
    FGroups: TRadCustomFieldGroups;
    FHooked: TDataSet;
    FOldBeforePost, FOldOnNewRecord: TDataSetNotifyEvent;
    FOnFieldsChanged: TNotifyEvent;
    FBuilt: Boolean;
    FMode: TRadCustomFieldsMode;
    FFilterFlaggedOnly: Boolean;
    /// <summary>Kodla yaratılmış editör, item ve grupları söker; DFM'deki layout ve kök grup kalır.</summary>
    procedure ClearItems;
    function CreateEditor(ADef: TRadCustomFieldDef): TWinControl;
    function CreateFilterEditor(ADef: TRadCustomFieldDef): TWinControl;
    /// <summary>Bu alan bu kipte gösterilir mi (filtre kipi + FilterFlaggedOnly → yalnız filtrele_mi).</summary>
    function Shown(ADef: TRadCustomFieldDef): Boolean;
    function IsRange(ADef: TRadCustomFieldDef): Boolean;
    function LayoutKey: string;
    function EditValueOf(AEdit: TWinControl): Variant;
    /// <summary>Filtre editörünü boşaltır (evet/hayır gri). Name atamasından SONRA çağrılmalı:
    /// csSetCaption yüzünden Name metne kopyalanır ('ed_ozel_1' aranırdı).</summary>
    procedure ResetFilterEditor(AEdit: TWinControl);
    procedure AddFilterCondition(const AFilter: IRadSqlFilter; ADef: TRadCustomFieldDef; const AField: string);
    function GetStore: IRadCustomFieldStore;
    procedure SetMode(const AValue: TRadCustomFieldsMode);
    procedure SetFilterFlaggedOnly(const AValue: Boolean);
    procedure BuildGroups;
    procedure ApplySavedLayout;
    procedure HookDataSet;
    procedure UnhookDataSet;
    procedure DoBeforePost(DataSet: TDataSet);
    procedure DoNewRecord(DataSet: TDataSet);
    procedure SetCanDesign(const AValue: Boolean);
    procedure SetDataSource(const AValue: TDataSource);
    procedure SetTableName(const AValue: string);
    function GetCustomizing: Boolean;
    procedure SetCustomizing(const AValue: Boolean);
    function DataSet: TDataSet;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    /// <summary>Store atanmamış her çerçevenin kullandığı depo; uygulama açılışında bir kez atanır
    /// (şirket bağlantısı değişince yeniden). Bağlantı kapanmadan nil yapılmalı: depo bağlantıyı tutar.</summary>
    class var DefaultStore: IRadCustomFieldStore;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Tanımları yükler, editörleri ve sekmeleri sıfırdan kurar, kayıtlı düzeni uygular.</summary>
    procedure Rebuild;
    /// <summary>Tanım diyaloğu (modal); kapanınca Rebuild + OnFieldsChanged.</summary>
    procedure ShowDesigner;
    procedure SaveLayout;
    procedure ResetLayout;
    /// <summary>Geçerli kayıtta boş kalan zorunlu alanların başlıkları (filtre kipinde boş).</summary>
    function MissingRequired: TArray<string>;
    /// <summary>Filtre kipi: editör değerlerini koşul olarak ekler. Metin → Contains; sayı/tarih/saat →
    /// Between (iki editör, tek taraf boş olabilir); evet/hayır → gri = koşul yok; tekli → Equal;
    /// çoklu → seçili kodların OR'u (Contains '|kod|'). Boş editör koşul üretmez (rfmSkipEmpty).
    /// AAlias verilirse alan 'c.ozel_1' yazılır.</summary>
    procedure ApplyFilter(const AFilter: IRadSqlFilter; const AAlias: string = '');
    /// <summary>Filtre kipi: bütün editörleri boşaltır (evet/hayır gri).</summary>
    procedure ClearFilter;
    /// <summary>Filtre kipi: en az bir editörde değer var mı.</summary>
    function HasFilterValues: Boolean;
    /// <summary>Aralık tiplerinde ikinci ("…e") editör; yoksa nil.</summary>
    function EditorToOf(const AColumn: string): TWinControl;
    function EditorOf(const AColumn: string): TWinControl;
    function ItemOf(const AColumn: string): TdxLayoutItem;
    function GroupItemOf(AGroupId: Integer): TdxLayoutGroup;
    class function GroupName(AGroupId: Integer): string; static;
    class function ItemName(const AColumn: string): string; static;
    class function EditorName(const AColumn: string): string; static;
    class function EditorToName(const AColumn: string): string; static;
    class function ItemToName(const AColumn: string): string; static;
    property Layout: TdxLayoutControl read lcRadCustomFields;
    property Groups: TRadCustomFieldGroups read FGroups;
    /// <summary>Bu çerçevenin deposu; atanmamışsa DefaultStore.</summary>
    property Store: IRadCustomFieldStore read GetStore write FStore;
    /// <summary>Layout'un çalışma zamanı özelleştirme kipi (sürükle, gizle).</summary>
    property Customizing: Boolean read GetCustomizing write SetCustomizing;
  published
    property TableName: string read FTableName write SetTableName;
    property DataSource: TDataSource read FDataSource write SetDataSource;
    property UserId: Integer read FUserId write FUserId default 0;
    /// <summary>"Ayar" düğmesi görünür mü (yetki).</summary>
    property CanDesign: Boolean read FCanDesign write SetCanDesign default False;
    /// <summary>BeforePost'ta zorunlu alan kontrolü (mevcut işleyici zincirlenir).</summary>
    property AutoValidate: Boolean read FAutoValidate write FAutoValidate default True;
    /// <summary>OnNewRecord'da varsayılanlar (mevcut işleyici zincirlenir).</summary>
    property AutoDefaults: Boolean read FAutoDefaults write FAutoDefaults default True;
    property OnFieldsChanged: TNotifyEvent read FOnFieldsChanged write FOnFieldsChanged;
    property Mode: TRadCustomFieldsMode read FMode write SetMode default cfmEdit;
    /// <summary>Filtre kipinde yalnız filtrele_mi işaretli alanlar (varsayılan). Kapalıysa hepsi.</summary>
    property FilterFlaggedOnly: Boolean read FFilterFlaggedOnly write SetFilterFlaggedOnly default True;
  end;

implementation

{$R *.dfm}

uses
  System.StrUtils, rad.dev.customfielddesigner;

type
  TEditAccess = class(TcxCustomEdit);

const
  LAYOUT_MAGIC = 'RADCF1';

{ Düzen blob'u: MAGIC, Int32 ad sayısı, her ad (Int32 uzunluk + UTF8), Int32 boyut + DevExpress akışı.
  Ad listesi iki iş görür: kayıt sonrası eklenen alanı ayırt eder (listede yok = yeni, gizlenmedi) ve
  görünürlüğü taşır ('-' önekli ad = gizli). DevExpress akışı Visible'ı SAKLAMAZ
  (TdxCustomLayoutItem.GetStoredProperties: IsUserDefined/ParentName/Index/Align/Width/Height/IsFloat;
  ölçüldü: ham SaveToStream/LoadFromStream gizli öğeyi görünür getirdi). }

procedure WriteNames(AStream: TStream; const ANames: TArray<string>);
var
  S: string;
  B: TBytes;
  N: Integer;
begin
  B := TEncoding.UTF8.GetBytes(LAYOUT_MAGIC);
  AStream.WriteBuffer(B, Length(B));
  N := Length(ANames);
  AStream.WriteBuffer(N, SizeOf(N));
  for S in ANames do
  begin
    B := TEncoding.UTF8.GetBytes(S);
    N := Length(B);
    AStream.WriteBuffer(N, SizeOf(N));
    if N > 0 then AStream.WriteBuffer(B, N);
  end;
end;

function ReadNames(AStream: TStream; out ANames: TArray<string>): Boolean;
var
  B: TBytes;
  N, i: Integer;
begin
  Result := False;
  SetLength(B, Length(LAYOUT_MAGIC));
  if AStream.Read(B, Length(B)) <> Length(B) then Exit;
  if TEncoding.UTF8.GetString(B) <> LAYOUT_MAGIC then Exit;
  AStream.ReadBuffer(N, SizeOf(N));
  SetLength(ANames, N);
  for i := 0 to N - 1 do
  begin
    AStream.ReadBuffer(N, SizeOf(N));
    SetLength(B, N);
    if N > 0 then AStream.ReadBuffer(B, N);
    ANames[i] := TEncoding.UTF8.GetString(B);
  end;
  Result := True;
end;

{ TRadCustomFieldsFrame }

constructor TRadCustomFieldsFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  // DFM'den gelen 'RadCustomFieldsFrame' adı: aynı forma iki çerçeve (düzenleme + filtre) konunca
  // EComponentError. Kodla yaratılanı adsız bırak; tasarımda bırakılanın adını okuyucu sonra verir.
  if not (csDesigning in ComponentState) then Name := '';
  FAutoValidate := True;
  FAutoDefaults := True;
  FFilterFlaggedOnly := True;
  FGroups := TRadCustomFieldGroups.Create(True);
end;

destructor TRadCustomFieldsFrame.Destroy;
begin
  UnhookDataSet;
  FGroups.Free;
  inherited;
end;

class function TRadCustomFieldsFrame.GroupName(AGroupId: Integer): string;
begin
  Result := 'grp_' + IntToStr(AGroupId);
end;

class function TRadCustomFieldsFrame.ItemName(const AColumn: string): string;
begin
  Result := 'li_' + AColumn;
end;

class function TRadCustomFieldsFrame.EditorName(const AColumn: string): string;
begin
  Result := 'ed_' + AColumn;
end;

class function TRadCustomFieldsFrame.EditorToName(const AColumn: string): string;
begin
  Result := 'ed_' + AColumn + '_2';
end;

class function TRadCustomFieldsFrame.ItemToName(const AColumn: string): string;
begin
  Result := 'li_' + AColumn + '_2';
end;

function TRadCustomFieldsFrame.EditorToOf(const AColumn: string): TWinControl;
begin
  Result := lcRadCustomFields.FindComponent(EditorToName(AColumn)) as TWinControl;
end;

function TRadCustomFieldsFrame.Shown(ADef: TRadCustomFieldDef): Boolean;
begin
  Result := ADef.Active and ((FMode = cfmEdit) or not FFilterFlaggedOnly or ADef.Filterable);
end;

function TRadCustomFieldsFrame.IsRange(ADef: TRadCustomFieldDef): Boolean;
begin
  Result := ADef.FieldType in [cfInteger, cfDecimal, cfMoney, cfDate, cfDateTime, cfTime];
end;

function TRadCustomFieldsFrame.LayoutKey: string;
begin
  // Düzen ve filtre kipinin item'ları farklı (aralık çiftleri); kayıt anahtarı da farklı.
  if FMode = cfmFilter then Result := FTableName + ':f' else Result := FTableName;
end;

function TRadCustomFieldsFrame.GetStore: IRadCustomFieldStore;
begin
  if FStore <> nil then Result := FStore else Result := DefaultStore;
end;

function TRadCustomFieldsFrame.DataSet: TDataSet;
begin
  if FDataSource = nil then Result := nil else Result := FDataSource.DataSet;
end;

function TRadCustomFieldsFrame.EditorOf(const AColumn: string): TWinControl;
begin
  Result := lcRadCustomFields.FindComponent(EditorName(AColumn)) as TWinControl;
end;

function TRadCustomFieldsFrame.ItemOf(const AColumn: string): TdxLayoutItem;
begin
  Result := lcRadCustomFields.FindItem(ItemName(AColumn)) as TdxLayoutItem;
end;

function TRadCustomFieldsFrame.GroupItemOf(AGroupId: Integer): TdxLayoutGroup;
begin
  Result := lcRadCustomFields.FindItem(GroupName(AGroupId)) as TdxLayoutGroup;
end;

function TRadCustomFieldsFrame.CreateEditor(ADef: TRadCustomFieldDef): TWinControl;
var
  O: TRadCustomFieldOption;
  LImg: TcxImageComboBoxItem;
begin
  case ADef.FieldType of
    cfText:
      begin
        Result := TcxDBTextEdit.Create(lcRadCustomFields);
        TcxDBTextEdit(Result).Properties.MaxLength := ADef.Length;
      end;
    cfMemo:
      begin
        Result := TcxDBMemo.Create(lcRadCustomFields);
        TcxDBMemo(Result).Properties.ScrollBars := System.UITypes.TScrollStyle.ssVertical;
        Result.Height := 72;
      end;
    cfInteger:
      begin
        Result := TcxDBSpinEdit.Create(lcRadCustomFields);
        TcxDBSpinEdit(Result).Properties.ValueType := vtInt;
      end;
    cfDecimal:
      begin
        Result := TcxDBCalcEdit.Create(lcRadCustomFields);
        if ADef.Decimals > 0 then
          TcxDBCalcEdit(Result).Properties.DisplayFormat := ',0.' + StringOfChar('0', ADef.Decimals)
        else
          TcxDBCalcEdit(Result).Properties.DisplayFormat := ',0';
      end;
    cfMoney:
      begin
        Result := TcxDBCurrencyEdit.Create(lcRadCustomFields);
        TcxDBCurrencyEdit(Result).Properties.DisplayFormat := ',0.00##';
      end;
    cfDate:
      Result := TcxDBDateEdit.Create(lcRadCustomFields);
    cfDateTime:
      begin
        Result := TcxDBDateEdit.Create(lcRadCustomFields);
        TcxDBDateEdit(Result).Properties.Kind := ckDateTime;
      end;
    cfTime:
      Result := TcxDBTimeEdit.Create(lcRadCustomFields);
    cfBoolean:
      begin
        Result := TcxDBCheckBox.Create(lcRadCustomFields);
        if (Store <> nil) and (Store.Dialect = sdMySQL) then
        begin
          TcxDBCheckBox(Result).Properties.ValueChecked := 1;   // tinyint(1)
          TcxDBCheckBox(Result).Properties.ValueUnchecked := 0;
        end;
      end;
    cfSingleChoice:
      begin
        Result := TcxDBImageComboBox.Create(lcRadCustomFields);
        for O in ADef.Options do
        begin
          LImg := TcxDBImageComboBox(Result).Properties.Items.Add;
          LImg.Value := O.Code;
          LImg.Description := O.Caption;
        end;
      end;
  else // cfMultiChoice
    Result := TRadDBCheckComboBox.Create(lcRadCustomFields);
    for O in ADef.Options do
      TRadDBCheckComboBox(Result).Properties.Items.AddItem(O.Caption, O.Code);
    TRadDBCheckComboBox(Result).Properties.AValueDelimiter := TRadMultiChoice.Delimiter;
    TRadDBCheckComboBox(Result).Properties.AValueWrap := True;
  end;
  Result.Name := EditorName(ADef.ColumnName);
  // Parent ATANMAZ: layout, Parent olan kontrole kendiliğinden item açar; CreateItemForControl ikinciyi reddeder.
  // DataBinding TcxCustomEdit'te protected; erişim sınıfı (rad.dev'deki TRadEditAccess kalıbı).
  TcxDBEditDataBinding(TEditAccess(Result).DataBinding).DataSource := FDataSource;
  TcxDBEditDataBinding(TEditAccess(Result).DataBinding).DataField := ADef.ColumnName;
end;

function TRadCustomFieldsFrame.CreateFilterEditor(ADef: TRadCustomFieldDef): TWinControl;
var
  O: TRadCustomFieldOption;
  LImg: TcxImageComboBoxItem;
begin
  // Bağsız karşılıklar; değer okuma EditValueOf / AddFilterCondition'da.
  case ADef.FieldType of
    cfText, cfMemo: Result := TcxTextEdit.Create(lcRadCustomFields);
    cfInteger:
      begin
        Result := TcxSpinEdit.Create(lcRadCustomFields);
        TcxSpinEdit(Result).Properties.ValueType := vtInt;
      end;
    cfDecimal: Result := TcxCalcEdit.Create(lcRadCustomFields);
    cfMoney: Result := TcxCurrencyEdit.Create(lcRadCustomFields);
    cfDate: Result := TcxDateEdit.Create(lcRadCustomFields);
    cfDateTime:
      begin
        Result := TcxDateEdit.Create(lcRadCustomFields);
        TcxDateEdit(Result).Properties.Kind := ckDateTime;
      end;
    cfTime: Result := TcxTimeEdit.Create(lcRadCustomFields);
    cfBoolean:
      begin
        Result := TcxCheckBox.Create(lcRadCustomFields);
        TcxCheckBox(Result).Properties.AllowGrayed := True;
        TcxCheckBox(Result).State := cbsGrayed;   // gri = koşul yok
      end;
    cfSingleChoice:
      begin
        Result := TcxImageComboBox.Create(lcRadCustomFields);
        LImg := TcxImageComboBox(Result).Properties.Items.Add;
        LImg.Value := Null;
        LImg.Description := '(tümü)';
        for O in ADef.Options do
        begin
          LImg := TcxImageComboBox(Result).Properties.Items.Add;
          LImg.Value := O.Code;
          LImg.Description := O.Caption;
        end;
      end;
  else // cfMultiChoice
    Result := TRadCheckComboBox.Create(lcRadCustomFields);
    for O in ADef.Options do
      TRadCheckComboBox(Result).Properties.Items.AddItem(O.Caption, O.Code);
    TRadCheckComboBox(Result).Properties.AValueDelimiter := TRadMultiChoice.Delimiter;
  end;
end;

procedure TRadCustomFieldsFrame.ResetFilterEditor(AEdit: TWinControl);
begin
  if AEdit is TcxCheckBox then TcxCheckBox(AEdit).State := cbsGrayed
  else if AEdit is TcxCustomEdit then TcxCustomEdit(AEdit).Clear;   // sayı editörleri '0' ile doğar
end;

procedure TRadCustomFieldsFrame.BuildGroups;
var
  G: TRadCustomFieldGroupDef;
  D: TRadCustomFieldDef;
  LGrp, LPair: TdxLayoutGroup;
  LItem: TdxLayoutItem;
  LEd: TWinControl;
begin
  for G in FGroups do
  begin
    LGrp := lcRadCustomFields.Items.CreateGroup;
    LGrp.Name := GroupName(G.Id);
    LGrp.CaptionOptions.Text := G.Name;
    for D in G.ActiveFields do
    begin
      if not Shown(D) then Continue;
      if FMode = cfmEdit then
      begin
        LItem := LGrp.CreateItemForControl(CreateEditor(D));
        LItem.Name := ItemName(D.ColumnName);
        LItem.CaptionOptions.Text := D.Caption;
        Continue;
      end;
      LEd := CreateFilterEditor(D);
      LEd.Name := EditorName(D.ColumnName);
      ResetFilterEditor(LEd);
      if not IsRange(D) then
      begin
        LItem := LGrp.CreateItemForControl(LEd);
        LItem.Name := ItemName(D.ColumnName);
        LItem.CaptionOptions.Text := D.Caption;
        Continue;
      end;
      // Aralık: yatay çift ("…den" / "…e"); ilk item alanın başlığını taşır, ikincisi '-'.
      LPair := LGrp.CreateGroup;
      LPair.Name := 'rg_' + D.ColumnName;
      LPair.LayoutDirection := ldHorizontal;
      LPair.ShowBorder := False;
      LItem := LPair.CreateItemForControl(LEd);
      LItem.Name := ItemName(D.ColumnName);
      LItem.CaptionOptions.Text := D.Caption;
      LEd := CreateFilterEditor(D);
      LEd.Name := EditorToName(D.ColumnName);
      ResetFilterEditor(LEd);
      LItem := LPair.CreateItemForControl(LEd);
      LItem.Name := ItemToName(D.ColumnName);
      LItem.CaptionOptions.Text := '-';
    end;
  end;
end;

function TRadCustomFieldsFrame.EditValueOf(AEdit: TWinControl): Variant;
begin
  Result := Null;
  if AEdit = nil then Exit;
  if AEdit is TcxCheckBox then
  begin
    case TcxCheckBox(AEdit).State of
      cbsChecked: Result := True;
      cbsUnchecked: Result := False;
    end;
    Exit;
  end;
  Result := TcxCustomEdit(AEdit).EditValue;
  if VarIsNull(Result) or VarIsEmpty(Result) then Exit(Null);
  if (AEdit is TcxCustomDateEdit) or (AEdit is TcxCustomTimeEdit) then
  begin
    // Maskeli Text boşken de '  .  .' olabilir; ölçü EditValue. 0 = NullDate (saatte de boş).
    if VarToDateTime(Result) = 0 then Exit(Null);
    Exit(VarFromDateTime(VarToDateTime(Result)));   // varDate: rad.sqlfilter WholeDay bunu bekler
  end;
  if VarIsStr(Result) and (Trim(VarToStr(Result)) = '') then
    Result := Null;   // boş metin = koşul yok
end;

procedure TRadCustomFieldsFrame.AddFilterCondition(const AFilter: IRadSqlFilter; ADef: TRadCustomFieldDef;
  const AField: string);
var
  V, V2: Variant;
  LCodes: TArray<string>;
  S: string;
begin
  V := EditValueOf(EditorOf(ADef.ColumnName));
  case ADef.FieldType of
    cfText, cfMemo:
      if not VarIsNull(V) then AFilter.Contains(AField, VarToStr(V), rcInsensitive);
    cfBoolean, cfSingleChoice:
      if not VarIsNull(V) and (VarToStr(V) <> '') then AFilter.Equal(AField, V);
    cfMultiChoice:
      begin
        LCodes := TRadCheckComboBox(EditorOf(ADef.ColumnName)).AValues;
        if Length(LCodes) = 0 then Exit;
        AFilter.BeginOr;
        for S in LCodes do
          AFilter.Contains(AField, TRadMultiChoice.Wrap(S));
        AFilter.EndOr;
      end;
  else // aralık tipleri
    V2 := EditValueOf(EditorToOf(ADef.ColumnName));
    if VarIsNull(V) and VarIsNull(V2) then Exit;
    AFilter.Between(AField, V, V2);
  end;
end;

procedure TRadCustomFieldsFrame.ApplyFilter(const AFilter: IRadSqlFilter; const AAlias: string);
var
  G: TRadCustomFieldGroupDef;
  D: TRadCustomFieldDef;
  LPrefix: string;
begin
  if FMode <> cfmFilter then
    raise ERadCustomField.Create('ApplyFilter yalnız filtre kipinde (Mode = cfmFilter).');
  if AFilter = nil then
    raise ERadCustomField.Create('ApplyFilter: filtre nil.');
  if AAlias <> '' then LPrefix := AAlias + '.' else LPrefix := '';
  for G in FGroups do
    for D in G.ActiveFields do
      if Shown(D) and (EditorOf(D.ColumnName) <> nil) then
        AddFilterCondition(AFilter, D, LPrefix + D.ColumnName);
end;

procedure TRadCustomFieldsFrame.ClearFilter;
var
  i: Integer;
  C: TComponent;
begin
  for i := 0 to lcRadCustomFields.ComponentCount - 1 do
  begin
    C := lcRadCustomFields.Components[i];
    if not StartsText('ed_', C.Name) then Continue;
    if C is TWinControl then ResetFilterEditor(TWinControl(C));
  end;
end;

function TRadCustomFieldsFrame.HasFilterValues: Boolean;
var
  i: Integer;
  C: TComponent;
begin
  for i := 0 to lcRadCustomFields.ComponentCount - 1 do
  begin
    C := lcRadCustomFields.Components[i];
    if StartsText('ed_', C.Name) and (C is TWinControl) then
      if C is TRadCheckComboBox then
      begin
        if TRadCheckComboBox(C).AHasValues then Exit(True);
      end
      else if not VarIsNull(EditValueOf(TWinControl(C))) then
        Exit(True);
  end;
  Result := False;
end;

procedure TRadCustomFieldsFrame.ClearItems;
var
  i: Integer;
  LItems: TList<TdxCustomLayoutItem>;
  LRoot: TdxLayoutGroup;
begin
  lcRadCustomFields.Customization := False;
  lcRadCustomFields.BeginUpdate;
  try
    // 1) editörler: layout'un sahip olduğu, bizim adlandırdığımız kontroller
    for i := lcRadCustomFields.ComponentCount - 1 downto 0 do
      if StartsText('ed_', lcRadCustomFields.Components[i].Name) then
        lcRadCustomFields.Components[i].Free;
    // 2) item'lar (kontrolü gitmiş), 3) kök altındaki gruplar; kök DFM'den gelir, kalır
    LItems := TList<TdxCustomLayoutItem>.Create;
    try
      for i := 0 to lcRadCustomFields.AbsoluteItemCount - 1 do
        if lcRadCustomFields.AbsoluteItems[i] is TdxLayoutItem then
          LItems.Add(lcRadCustomFields.AbsoluteItems[i]);
      for i := LItems.Count - 1 downto 0 do
        LItems[i].Free;
    finally
      LItems.Free;
    end;
    LRoot := lcRadCustomFields.Items;
    for i := LRoot.Count - 1 downto 0 do
      LRoot.Items[i].Free;
  finally
    lcRadCustomFields.EndUpdate;
  end;
end;

procedure TRadCustomFieldsFrame.ApplySavedLayout;
var
  LMem, LDx: TMemoryStream;
  LSize: Integer;
  LNames: TArray<string>;
  LSaved: TDictionary<string, Boolean>;
  LVisible: Boolean;
  G: TRadCustomFieldGroupDef;
  D: TRadCustomFieldDef;
  LItem: TdxLayoutItem;
  S: string;
begin
  LMem := TMemoryStream.Create;
  try
    if not Store.LoadLayout(LayoutKey, FUserId, LMem) then Exit;
    LMem.Position := 0;
    if not ReadNames(LMem, LNames) then Exit;   // bilinmeyen biçim: varsayılan düzen
    LDx := TMemoryStream.Create;
    try
      LMem.ReadBuffer(LSize, SizeOf(LSize));
      LDx.CopyFrom(LMem, LSize);
      LDx.Position := 0;
      lcRadCustomFields.LoadFromStream(LDx);   // DevExpress akışı kendi başına; konum/uzunluk varsayımı yapmasın
    finally
      LDx.Free;
    end;
    LSaved := TDictionary<string, Boolean>.Create;   // ad → görünür mü
    try
      for S in LNames do
        if S.StartsWith('-') then LSaved.AddOrSetValue(S.Substring(1), False)
        else LSaved.AddOrSetValue(S, True);
      for G in FGroups do
        for D in G.ActiveFields do
        begin
          LItem := ItemOf(D.ColumnName);
          if LItem = nil then Continue;
          if LSaved.TryGetValue(LItem.Name, LVisible) then
            LItem.Visible := LVisible
          else
          begin
            LItem.Parent := GroupItemOf(G.Id);   // kayıttan sonra eklenen: kendi grubunun sonuna
            LItem.Visible := True;
          end;
        end;
    finally
      LSaved.Free;
    end;
  finally
    LMem.Free;
  end;
end;

procedure TRadCustomFieldsFrame.Ayar1Click(Sender: TObject);
begin
  ShowDesigner;
end;

procedure TRadCustomFieldsFrame.Rebuild;
begin
  if csDesigning in ComponentState then Exit;
  UnhookDataSet;
  ClearItems;
  FGroups.Clear;
  FBuilt := False;
  if (Store = nil) or (FTableName = '') then Exit;
  FGroups.Free;
  FGroups := Store.LoadGroups(FTableName, False);
  lcRadCustomFields.BeginUpdate;
  try
    BuildGroups;
    ApplySavedLayout;
  finally
    lcRadCustomFields.ApplyBestFit;
    lcRadCustomFields.EndUpdate;
  end;
  FBuilt := True;
  if FMode = cfmEdit then HookDataSet;

end;

procedure TRadCustomFieldsFrame.SaveLayout;
var
  LMem, LDx: TMemoryStream;
  LSize: Integer;
  LNames: TList<string>;
  i: Integer;
begin
  if (Store = nil) or not FBuilt then Exit;
  LNames := TList<string>.Create;
  LMem := TMemoryStream.Create;
  try
    for i := 0 to lcRadCustomFields.AbsoluteItemCount - 1 do
      if lcRadCustomFields.AbsoluteItems[i] is TdxLayoutItem then
        LNames.Add(IfThen(lcRadCustomFields.AbsoluteItems[i].Visible, '', '-') + lcRadCustomFields.AbsoluteItems[i].Name);
    WriteNames(LMem, LNames.ToArray);
    LDx := TMemoryStream.Create;
    try
      lcRadCustomFields.SaveToStream(LDx);
      LSize := LDx.Size;
      LMem.WriteBuffer(LSize, SizeOf(LSize));
      LDx.Position := 0;
      LMem.CopyFrom(LDx, LSize);
    finally
      LDx.Free;
    end;
    LMem.Position := 0;
    Store.SaveLayout(LayoutKey, FUserId, LMem);
  finally
    LMem.Free;
    LNames.Free;
  end;
end;

procedure TRadCustomFieldsFrame.ResetLayout;
begin
  if Store = nil then Exit;
  Store.DeleteLayout(LayoutKey, FUserId);
  Rebuild;
end;

procedure TRadCustomFieldsFrame.ShowDesigner;
var
  LDlg: TRadCustomFieldDesigner;
begin
  if (Store = nil) or (FTableName = '') then
    raise ERadCustomField.Create('Store ve TableName atanmadan tanım diyaloğu açılamaz.');
  LDlg := TRadCustomFieldDesigner.CreateDesigner(Self, Store, FTableName);
  try
    LDlg.ShowModal;
    if LDlg.Modified then
    begin
      Rebuild;
      if Assigned(FOnFieldsChanged) then FOnFieldsChanged(Self);
    end;
  finally
    LDlg.Free;
  end;
end;

function TRadCustomFieldsFrame.MissingRequired: TArray<string>;
var
  G: TRadCustomFieldGroupDef;
  D: TRadCustomFieldDef;
  F: TField;
  LList: TList<string>;
  LDs: TDataSet;
begin
  LList := TList<string>.Create;
  try
    LDs := DataSet;
    if (LDs <> nil) and (FMode = cfmEdit) then
      for G in FGroups do
        for D in G.ActiveFields do
          if D.Required then
          begin
            F := LDs.FindField(D.ColumnName);
            if (F = nil) or F.IsNull or (F.AsString = '') or
               ((F.DataType in [ftString, ftWideString, ftMemo, ftWideMemo]) and (Trim(F.AsString) = '')) then
              LList.Add(D.Caption);
          end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

procedure TRadCustomFieldsFrame.HookDataSet;
var
  LDs: TDataSet;
begin
  LDs := DataSet;
  if (LDs = nil) or (LDs = FHooked) then Exit;
  UnhookDataSet;
  FHooked := LDs;
  FHooked.FreeNotification(Self);
  FOldBeforePost := FHooked.BeforePost;
  FOldOnNewRecord := FHooked.OnNewRecord;
  FHooked.BeforePost := DoBeforePost;
  FHooked.OnNewRecord := DoNewRecord;
end;

procedure TRadCustomFieldsFrame.UnhookDataSet;
begin
  if FHooked = nil then Exit;
  // Başkası sonradan üstüne yazdıysa dokunma; yalnız bizim işleyici duruyorsa eskiyi geri koy.
  if TMethod(FHooked.BeforePost).Code = @TRadCustomFieldsFrame.DoBeforePost then
    FHooked.BeforePost := FOldBeforePost;
  if TMethod(FHooked.OnNewRecord).Code = @TRadCustomFieldsFrame.DoNewRecord then
    FHooked.OnNewRecord := FOldOnNewRecord;
  FHooked := nil;
end;

procedure TRadCustomFieldsFrame.DoBeforePost(DataSet: TDataSet);
var
  LMissing: TArray<string>;
begin
  if Assigned(FOldBeforePost) then FOldBeforePost(DataSet);
  if not FAutoValidate then Exit;
  LMissing := MissingRequired;
  if Length(LMissing) > 0 then
    raise ERadCustomField.Create('Zorunlu alanlar boş: ' + string.Join(', ', LMissing));
end;

procedure TRadCustomFieldsFrame.DoNewRecord(DataSet: TDataSet);
var
  G: TRadCustomFieldGroupDef;
  D: TRadCustomFieldDef;
  F: TField;
  V: Variant;
begin
  if Assigned(FOldOnNewRecord) then FOldOnNewRecord(DataSet);
  if not FAutoDefaults then Exit;
  for G in FGroups do
    for D in G.ActiveFields do
    begin
      if Trim(D.DefaultValue) = '' then Continue;
      F := DataSet.FindField(D.ColumnName);
      if F = nil then Continue;
      V := D.DefaultAsVariant;
      if D.FieldType = cfMultiChoice then
        V := TRadMultiChoice.Join(TRadMultiChoice.Split(VarToStr(V)));   // 'a' ya da '|a|b|' → '|a|b|'
      F.Value := V;
    end;
end;

procedure TRadCustomFieldsFrame.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if Operation <> opRemove then Exit;
  if AComponent = FDataSource then FDataSource := nil;
  if AComponent = FHooked then FHooked := nil;
end;

procedure TRadCustomFieldsFrame.SetDataSource(const AValue: TDataSource);
begin
  if FDataSource = AValue then Exit;
  UnhookDataSet;
  FDataSource := AValue;
  if FDataSource <> nil then FDataSource.FreeNotification(Self);
  if FBuilt then Rebuild;
end;

procedure TRadCustomFieldsFrame.SetTableName(const AValue: string);
begin
  if FTableName = AValue then Exit;
  FTableName := AValue;
  if FBuilt then Rebuild;
end;

procedure TRadCustomFieldsFrame.SetMode(const AValue: TRadCustomFieldsMode);
begin
  if FMode = AValue then Exit;
  FMode := AValue;
  if FBuilt then Rebuild;
end;

procedure TRadCustomFieldsFrame.SetFilterFlaggedOnly(const AValue: Boolean);
begin
  if FFilterFlaggedOnly = AValue then Exit;
  FFilterFlaggedOnly := AValue;
  if FBuilt and (FMode = cfmFilter) then Rebuild;
end;

procedure TRadCustomFieldsFrame.SetCanDesign(const AValue: Boolean);
begin
  FCanDesign := AValue;
  btnDesign.Visible := AValue;
end;

function TRadCustomFieldsFrame.GetCustomizing: Boolean;
begin
  Result := lcRadCustomFields.Customization;
end;

procedure TRadCustomFieldsFrame.SetCustomizing(const AValue: Boolean);
begin
  lcRadCustomFields.Customization := AValue;
end;

procedure TRadCustomFieldsFrame.btnDesignClick(Sender: TObject);
begin
  ShowDesigner;
end;

procedure TRadCustomFieldsFrame.DzeniSfrla1Click(Sender: TObject);
begin
  Customizing := False;
  ResetLayout;
end;

procedure TRadCustomFieldsFrame.Dzenle1Click(Sender: TObject);
begin
Customizing := not Customizing;
end;

procedure TRadCustomFieldsFrame.Kaydet1Click(Sender: TObject);
begin
  Customizing := False;
  SaveLayout;
end;

end.
