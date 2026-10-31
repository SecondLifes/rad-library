unit rad.dev.customfielddesigner;

{ Özel alan tanım diyaloğu: sol kategori, sağ alan (Wolvox düzeni). Görsel kısım
  DFM'de; burada yalnız davranış. Çerçeve (rad.dev.customfields) ShowDesigner ile açar.
  Spec: docs/specs/rad.customfield.md. }

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Variants, System.UITypes,
  Vcl.Controls, Vcl.Forms, Vcl.Graphics, Vcl.Dialogs,
  cxGraphics, cxControls, cxLookAndFeels, cxLookAndFeelPainters, cxContainer, cxEdit, cxTextEdit,
  cxMaskEdit, cxDropDownEdit, cxSpinEdit, cxCheckBox, cxMemo, cxButtons, cxLabel, cxListBox, cxClasses,
  dxLayoutContainer, dxLayoutControl, dxLayoutcxEditAdapters, dxLayoutControlAdapters,
  rad.customfield, Vcl.Menus, Vcl.StdCtrls, cxCustomListBox;

type
  TRadCustomFieldDesigner = class(TForm)
    lcMain: TdxLayoutControl;
    lcMainGroup_Root: TdxLayoutGroup;
    grpTop: TdxLayoutGroup;
    grpGroups: TdxLayoutGroup;
    grpFields: TdxLayoutGroup;
    grpBottom: TdxLayoutGroup;
    grpGroupButtons: TdxLayoutGroup;
    grpFlags: TdxLayoutGroup;
    grpFieldButtons: TdxLayoutGroup;
    lstGroups: TcxListBox;
    edtGroupName: TcxTextEdit;
    spnGroupOrder: TcxSpinEdit;
    chkGroupActive: TcxCheckBox;
    btnGroupNew: TcxButton;
    btnGroupSave: TcxButton;
    lstFields: TcxListBox;
    lblColumn: TcxLabel;
    edtCaption: TcxTextEdit;
    cmbType: TcxComboBox;
    spnLength: TcxSpinEdit;
    spnDecimals: TcxSpinEdit;
    edtDefault: TcxTextEdit;
    mmoOptions: TcxMemo;
    spnOrder: TcxSpinEdit;
    chkRequired: TcxCheckBox;
    chkFilterable: TcxCheckBox;
    chkActive: TcxCheckBox;
    btnFieldNew: TcxButton;
    btnFieldSave: TcxButton;
    btnClose: TcxButton;
    liGroups: TdxLayoutItem;
    liGroupName: TdxLayoutItem;
    liGroupOrder: TdxLayoutItem;
    liGroupActive: TdxLayoutItem;
    liGroupNew: TdxLayoutItem;
    liGroupSave: TdxLayoutItem;
    liFields: TdxLayoutItem;
    liColumn: TdxLayoutItem;
    liCaption: TdxLayoutItem;
    liType: TdxLayoutItem;
    liLength: TdxLayoutItem;
    liDecimals: TdxLayoutItem;
    liDefault: TdxLayoutItem;
    liOptions: TdxLayoutItem;
    liOrder: TdxLayoutItem;
    liRequired: TdxLayoutItem;
    liFilterable: TdxLayoutItem;
    liActive: TdxLayoutItem;
    liFieldNew: TdxLayoutItem;
    liFieldSave: TdxLayoutItem;
    liClose: TdxLayoutItem;
    procedure lstGroupsClick(Sender: TObject);
    procedure lstFieldsClick(Sender: TObject);
    procedure btnGroupNewClick(Sender: TObject);
    procedure btnGroupSaveClick(Sender: TObject);
    procedure btnFieldNewClick(Sender: TObject);
    procedure btnFieldSaveClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure cmbTypeChange(Sender: TObject);
  private
    FStore: IRadCustomFieldStore;
    FTableName: string;
    FGroups: TRadCustomFieldGroups;
    FCurGroup: TRadCustomFieldGroupDef;
    FCurField: TRadCustomFieldDef;   // nil = yeni
    FChanged: Boolean;
    procedure FillGroups;
    procedure FillFields;
    procedure ShowGroup;
    procedure ShowField;
    procedure Reload(AGroupId, AFieldId: Integer);
    procedure Fail(const AMsg: string);
  public
    constructor CreateDesigner(AOwner: TComponent; AStore: IRadCustomFieldStore; const ATableName: string);
    destructor Destroy; override;
    { Testten sürülebilmesi için açık; düğme işleyicileri bunları çağırır. }
    procedure SelectGroup(AIndex: Integer);
    procedure SelectField(AIndex: Integer);
    procedure NewGroup;
    procedure SaveGroup;
    procedure NewField;
    procedure SaveField;
    property Groups: TRadCustomFieldGroups read FGroups;
    property CurrentGroup: TRadCustomFieldGroupDef read FCurGroup;
    property CurrentField: TRadCustomFieldDef read FCurField;
    /// <summary>Diyalog açıkken en az bir tanım değişti mi.</summary>
    property Modified: Boolean read FChanged;
    property EdGroupName: TcxTextEdit read edtGroupName;
    property EdGroupOrder: TcxSpinEdit read spnGroupOrder;
    property CbGroupActive: TcxCheckBox read chkGroupActive;
    property EdCaption: TcxTextEdit read edtCaption;
    property CbType: TcxComboBox read cmbType;
    property EdLength: TcxSpinEdit read spnLength;
    property EdDecimals: TcxSpinEdit read spnDecimals;
    property EdOrder: TcxSpinEdit read spnOrder;
    property EdDefault: TcxTextEdit read edtDefault;
    property CbRequired: TcxCheckBox read chkRequired;
    property CbFilterable: TcxCheckBox read chkFilterable;
    property CbActive: TcxCheckBox read chkActive;
    property MemOptions: TcxMemo read mmoOptions;
    property LbGroups: TcxListBox read lstGroups;
    property LbFields: TcxListBox read lstFields;
  end;

const
  TYPE_CAPTIONS: array[TRadCustomFieldType] of string = ('Metin', 'Not', 'Tamsayı', 'Ondalıklı sayı',
    'Para', 'Tarih', 'Saat', 'Tarih-Saat', 'Evet/Hayır', 'Tekli seçim', 'Çoklu seçim');

implementation

{$R *.dfm}

uses
  System.StrUtils;

constructor TRadCustomFieldDesigner.CreateDesigner(AOwner: TComponent; AStore: IRadCustomFieldStore;
  const ATableName: string);
var
  T: TRadCustomFieldType;
begin
  inherited Create(AOwner);
  FStore := AStore;
  FTableName := ATableName;
  FGroups := TRadCustomFieldGroups.Create(True);
  Caption := Caption + ' — ' + ATableName;
  for T := Low(T) to High(T) do
    cmbType.Properties.Items.Add(TYPE_CAPTIONS[T]);
  Reload(0, 0);
end;

destructor TRadCustomFieldDesigner.Destroy;
begin
  FGroups.Free;
  inherited;
end;

procedure TRadCustomFieldDesigner.Fail(const AMsg: string);
begin
  MessageDlg(AMsg, mtError, [mbOK], 0);
end;

procedure TRadCustomFieldDesigner.Reload(AGroupId, AFieldId: Integer);
var
  LGroups: TRadCustomFieldGroups;
  i, j: Integer;
begin
  LGroups := FStore.LoadGroups(FTableName, True);
  FGroups.Free;
  FGroups := LGroups;
  FCurGroup := nil;
  FCurField := nil;
  FillGroups;
  for i := 0 to FGroups.Count - 1 do
    if FGroups[i].Id = AGroupId then
    begin
      SelectGroup(i);
      for j := 0 to FCurGroup.Fields.Count - 1 do
        if FCurGroup.Fields[j].Id = AFieldId then
          SelectField(j);
      Exit;
    end;
  if FGroups.Count > 0 then SelectGroup(0) else ShowGroup;
end;

procedure TRadCustomFieldDesigner.FillGroups;
var
  G: TRadCustomFieldGroupDef;
begin
  lstGroups.Items.BeginUpdate;
  try
    lstGroups.Items.Clear;
    for G in FGroups do
      lstGroups.Items.Add(G.Name + IfThen(not G.Active, ' (pasif)', ''));
  finally
    lstGroups.Items.EndUpdate;
  end;
end;

procedure TRadCustomFieldDesigner.FillFields;
var
  D: TRadCustomFieldDef;
begin
  lstFields.Items.BeginUpdate;
  try
    lstFields.Items.Clear;
    if FCurGroup <> nil then
      for D in FCurGroup.Fields do
        lstFields.Items.Add(Format('%s  [%s, %s]%s', [D.Caption, D.ColumnName, TYPE_CAPTIONS[D.FieldType],
          IfThen(not D.Active, ' (pasif)', '')]));
  finally
    lstFields.Items.EndUpdate;
  end;
end;

procedure TRadCustomFieldDesigner.SelectGroup(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= FGroups.Count) then Exit;
  FCurGroup := FGroups[AIndex];
  lstGroups.ItemIndex := AIndex;
  FCurField := nil;
  ShowGroup;
  FillFields;
  ShowField;
end;

procedure TRadCustomFieldDesigner.SelectField(AIndex: Integer);
begin
  if (FCurGroup = nil) or (AIndex < 0) or (AIndex >= FCurGroup.Fields.Count) then Exit;
  FCurField := FCurGroup.Fields[AIndex];
  lstFields.ItemIndex := AIndex;
  ShowField;
end;

procedure TRadCustomFieldDesigner.ShowGroup;
begin
  if FCurGroup = nil then
  begin
    edtGroupName.Text := '';
    spnGroupOrder.Value := FGroups.Count + 1;
    chkGroupActive.Checked := True;
  end
  else
  begin
    edtGroupName.Text := FCurGroup.Name;
    spnGroupOrder.Value := FCurGroup.Order;
    chkGroupActive.Checked := FCurGroup.Active;
  end;
  btnFieldNew.Enabled := FCurGroup <> nil;
  btnFieldSave.Enabled := FCurGroup <> nil;
end;

procedure TRadCustomFieldDesigner.ShowField;
begin
  if FCurField = nil then
  begin
    lblColumn.Caption := '(kaydedince üretilir)';
    edtCaption.Text := '';
    cmbType.ItemIndex := 0;
    spnLength.Value := 50;
    spnDecimals.Value := 2;
    edtDefault.Text := '';
    mmoOptions.Lines.Text := '';
    if FCurGroup <> nil then spnOrder.Value := FCurGroup.Fields.Count + 1 else spnOrder.Value := 1;
    chkRequired.Checked := False;
    chkFilterable.Checked := True;   // varsayılan: filtrede çıkar; istemeyen kaldırır (çerçeve FilterFlaggedOnly)
    chkActive.Checked := True;
    cmbType.Enabled := True;
  end
  else
  begin
    lblColumn.Caption := FCurField.ColumnName;
    edtCaption.Text := FCurField.Caption;
    cmbType.ItemIndex := Ord(FCurField.FieldType);
    spnLength.Value := FCurField.Length;
    spnDecimals.Value := FCurField.Decimals;
    edtDefault.Text := FCurField.DefaultValue;
    mmoOptions.Lines.Text := FCurField.OptionsText;
    spnOrder.Value := FCurField.Order;
    chkRequired.Checked := FCurField.Required;
    chkFilterable.Checked := FCurField.Filterable;
    chkActive.Checked := FCurField.Active;
    cmbType.Enabled := False;   // tip kaydedildikten sonra kilitli
  end;
  cmbTypeChange(nil);
end;

procedure TRadCustomFieldDesigner.cmbTypeChange(Sender: TObject);
var
  T: TRadCustomFieldType;
begin
  if cmbType.ItemIndex < 0 then Exit;
  T := TRadCustomFieldType(cmbType.ItemIndex);
  spnLength.Enabled := T = cfText;
  spnDecimals.Enabled := (T = cfDecimal) and (FCurField = nil);
  mmoOptions.Enabled := T in [cfSingleChoice, cfMultiChoice];
end;

procedure TRadCustomFieldDesigner.NewGroup;
begin
  FCurGroup := nil;
  FCurField := nil;
  lstGroups.ItemIndex := -1;
  ShowGroup;
  FillFields;
  ShowField;
end;

procedure TRadCustomFieldDesigner.SaveGroup;
var
  G: TRadCustomFieldGroupDef;
  LNew: Boolean;
  LId: Integer;
begin
  LNew := FCurGroup = nil;
  if LNew then G := TRadCustomFieldGroupDef.Create else G := FCurGroup;
  try
    G.TableName := FTableName;
    G.Name := Trim(edtGroupName.Text);
    G.Order := spnGroupOrder.Value;
    G.Active := chkGroupActive.Checked;
    if LNew then FStore.AddGroup(G) else FStore.UpdateGroup(G);
    FChanged := True;
    LId := G.Id;
  finally
    if LNew then G.Free;
  end;
  Reload(LId, 0);   // yeni grubu id ile yeniden bulur
end;

procedure TRadCustomFieldDesigner.NewField;
begin
  if FCurGroup = nil then Exit;
  FCurField := nil;
  lstFields.ItemIndex := -1;
  ShowField;
end;

procedure TRadCustomFieldDesigner.SaveField;
var
  D: TRadCustomFieldDef;
  LNew: Boolean;
  LErr: string;
  LNewLen: Integer;
begin
  if FCurGroup = nil then
    raise ERadCustomField.Create('Önce bir kategori seçin.');
  LNew := FCurField = nil;
  if LNew then D := TRadCustomFieldDef.Create else D := FCurField.Clone;
  try
    D.GroupId := FCurGroup.Id;
    D.TableName := FTableName;
    D.Caption := Trim(edtCaption.Text);
    if LNew then
    begin
      D.FieldType := TRadCustomFieldType(cmbType.ItemIndex);
      D.Length := spnLength.Value;
      D.Decimals := spnDecimals.Value;
    end;
    D.DefaultValue := edtDefault.Text;
    D.SetOptionsText(mmoOptions.Lines.Text);
    D.Order := spnOrder.Value;
    D.Required := chkRequired.Checked;
    D.Filterable := chkFilterable.Checked;
    D.Active := chkActive.Checked;
    LErr := D.Validate;
    if LErr <> '' then
      raise ERadCustomField.Create(LErr);
    if LNew then
      FStore.AddField(D)
    else
    begin
      FStore.UpdateField(D);
      LNewLen := spnLength.Value;
      if (D.FieldType = cfText) and (LNewLen <> D.Length) then
        FStore.ExtendLength(D, LNewLen);   // küçültme: store hata verir
    end;
    FChanged := True;
    Reload(FCurGroup.Id, D.Id);   // alanı id ile yeniden bulur
  finally
    D.Free;
  end;
end;

procedure TRadCustomFieldDesigner.lstGroupsClick(Sender: TObject);
begin
  SelectGroup(lstGroups.ItemIndex);
end;

procedure TRadCustomFieldDesigner.lstFieldsClick(Sender: TObject);
begin
  SelectField(lstFields.ItemIndex);
end;

procedure TRadCustomFieldDesigner.btnGroupNewClick(Sender: TObject);
begin
  NewGroup;
end;

procedure TRadCustomFieldDesigner.btnGroupSaveClick(Sender: TObject);
begin
  try
    SaveGroup;
  except
    on E: Exception do Fail(E.Message);
  end;
end;

procedure TRadCustomFieldDesigner.btnFieldNewClick(Sender: TObject);
begin
  NewField;
end;

procedure TRadCustomFieldDesigner.btnFieldSaveClick(Sender: TObject);
begin
  try
    SaveField;
  except
    on E: Exception do Fail(E.Message);
  end;
end;

procedure TRadCustomFieldDesigner.btnCloseClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

end.
