unit Rad.Editor.FormState;

{ The TRadPropertiesStore editor. Layout is in the DFM; code fills it from
  TRadStateEditorModel and writes the store only on OK. No IDE units here. }

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  cxGraphics,
  cxControls,
  cxLookAndFeels,
  cxLookAndFeelPainters,
  cxCustomData,
  cxStyles,
  cxTL,
  cxTextEdit,
  cxDropDownEdit,
  cxInplaceContainer,
  dxScrollbarAnnotations,
  cxTLdxBarBuiltInMenu,
  rad.formstate.component,
  rad.formstate.customizer,
  rad.formstate.rules,
  Rad.Editor.FormState.Model;

type
  TRadFormStateEditorForm = class(TForm)
    pgcMain: TPageControl;
    tabProps: TTabSheet;
    tabValues: TTabSheet;
    tabOptions: TTabSheet;
    pnlTools: TPanel;
    chkGroupByProperty: TCheckBox;
    chkOnlySelected: TCheckBox;
    btnPresetPage: TButton;
    btnPresetSize: TButton;
    tlProps: TcxTreeList;
    colName: TcxTreeListColumn;
    colType: TcxTreeListColumn;
    colValue: TcxTreeListColumn;
    splSelected: TSplitter;
    pnlSelected: TPanel;
    lblSelected: TLabel;
    lstSelected: TListBox;
    pnlOrder: TPanel;
    btnUp: TButton;
    btnDown: TButton;
    btnRemove: TButton;
    pnlValueTools: TPanel;
    btnValueAdd: TButton;
    btnValueDelete: TButton;
    tlValues: TcxTreeList;
    colValueName: TcxTreeListColumn;
    colValueType: TcxTreeListColumn;
    colValueValue: TcxTreeListColumn;
    chkPlacement: TCheckBox;
    chkActiveControl: TCheckBox;
    chkProps: TCheckBox;
    chkValues: TCheckBox;
    chkCustom: TCheckBox;
    lblVersion: TLabel;
    edtVersion: TEdit;
    lblStorageName: TLabel;
    edtStorageName: TEdit;
    tabRules: TTabSheet;
    splRules: TSplitter;
    pnlRules: TPanel;
    lblRules: TLabel;
    memRules: TMemo;
    pnlRulesTools: TPanel;
    btnRulesAppearance: TButton;
    pnlPreview: TPanel;
    lblPreview: TLabel;
    lstPreview: TListBox;
    lblPreviewNote: TLabel;
    pnlButtons: TPanel;
    btnOk: TButton;
    btnCancel: TButton;
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure btnValueAddClick(Sender: TObject);
    procedure btnValueDeleteClick(Sender: TObject);
    procedure tlPropsNodeCheckChanged(Sender: TcxCustomTreeList; ANode: TcxTreeListNode;
      AState: TcxCheckBoxState);
    procedure ViewChanged(Sender: TObject);
    procedure btnPresetPageClick(Sender: TObject);
    procedure btnPresetSizeClick(Sender: TObject);
    procedure btnUpClick(Sender: TObject);
    procedure btnDownClick(Sender: TObject);
    procedure btnRemoveClick(Sender: TObject);
    procedure memRulesChange(Sender: TObject);
    procedure btnRulesAppearanceClick(Sender: TObject);
  private
    FModel: TRadStateEditorModel;
    FCustomizer: TRadFormCustomizer;
    FUpdating: Boolean;
    procedure SelectedPathsOf(AComponent: TComponent; APaths: TStrings);
    function PreviewComponent(ARules: TRadCustomizeRules; AComponent: TComponent): Integer;
    procedure FillPreview;
    function ShowLeaf(const ALeaf: TRadStateLeaf): Boolean;
    function ChildNode(AParent: TcxTreeListNode; const ACaption: string): TcxTreeListNode;
    procedure AddLeafNode(AParent: TcxTreeListNode; const ACaption: string; ALeafIndex: Integer);
    procedure FillByComponent;
    procedure FillByProperty;
    procedure FillTree;
    procedure FillSelected;
    procedure FillValues;
    function TypeNames: TStrings;
    function ValueTypeOf(ANode: TcxTreeListNode): TRadStoredValueType;
    procedure FillOptions;
    procedure SyncCheck(ANode: TcxTreeListNode);
    procedure ApplyValues;
    procedure ApplyOptions;
    procedure MoveSelected(ADelta: Integer);
  public
    /// <summary>Loads the store into the form; nothing is written yet.</summary>
    procedure Prepare(AStore: TRadPropertiesStore); overload;
    /// <summary>Customizer mode: the rules with a preview, and the per-component Allowed list;
    /// no values, options or presets.</summary>
    procedure Prepare(ACustomizer: TRadFormCustomizer); overload;
    /// <summary>Writes the form back into the store (what OK does).</summary>
    procedure Apply;
    /// <summary>The first value row whose name repeats or whose text does not fit its type; '' when all fit.</summary>
    function InvalidValue: string;
    property Model: TRadStateEditorModel read FModel;
    /// <summary>Shows the editor modally; True when the store was changed.</summary>
    class function Execute(AStore: TRadPropertiesStore): Boolean; overload; static;
    /// <summary>Edits ACustomizer.Rules and Allowed; True when it was changed.</summary>
    class function Execute(ACustomizer: TRadFormCustomizer): Boolean; overload; static;
  end;

implementation

uses
  System.Variants,
  System.UITypes,
  Vcl.Dialogs;

resourcestring
  SCustomizerCaption = 'Kullanıcı Düzenleme İzinleri';
  SAllowedCaption = 'Bileşene özel izinler (%d; kurallara eklenir)';
  SSelectedCaption = 'Kaydedilecekler (%d, sırayla uygulanır)';
  SPreviewCaption = 'Önizleme: %d bileşende %d özellik açık';
  SRuleErrorMark = 'HATA ';
  SInvalidValue = '"%s" değeri türüne uymuyor ya da adı tekrar ediyor.';

{$R *.dfm}

const
  COL_NAME = 0;
  COL_TYPE = 1;
  COL_VALUE = 2;
  PATH_SEPARATOR = '.';
  NOT_RESTORABLE_MARK = '— ';
  VERSION_DEFAULT = 0;

{ TRadFormStateEditorForm }

class function TRadFormStateEditorForm.Execute(AStore: TRadPropertiesStore): Boolean;
var
  LForm: TRadFormStateEditorForm;
begin
  LForm := TRadFormStateEditorForm.Create(nil);
  try
    LForm.Prepare(AStore);
    Result := LForm.ShowModal = mrOk;
    if Result then
      LForm.Apply;
  finally
    LForm.Free;
  end;
end;

class function TRadFormStateEditorForm.Execute(ACustomizer: TRadFormCustomizer): Boolean;
var
  LForm: TRadFormStateEditorForm;
begin
  LForm := TRadFormStateEditorForm.Create(nil);
  try
    LForm.Prepare(ACustomizer);
    Result := LForm.ShowModal = mrOk;
    if Result then
      LForm.Apply;
  finally
    LForm.Free;
  end;
end;

procedure TRadFormStateEditorForm.FormDestroy(Sender: TObject);
begin
  FModel.Free;
end;

procedure TRadFormStateEditorForm.Prepare(AStore: TRadPropertiesStore);
begin
  FreeAndNil(FModel);
  FModel := TRadStateEditorModel.Create(AStore);
  FModel.Build;
  FModel.LoadFromStore;
  Caption := Format('%s - %s', [Caption, AStore.Name]);
  tabRules.TabVisible := False;
  FillTree;
  FillSelected;
  FillValues;
  FillOptions;
end;

procedure TRadFormStateEditorForm.Prepare(ACustomizer: TRadFormCustomizer);
begin
  FreeAndNil(FModel);
  FCustomizer := ACustomizer;
  FModel := TRadStateEditorModel.CreateFor(ACustomizer.Owner, ACustomizer.Allowed, False);
  FModel.Build;
  FModel.LoadFromStore;
  Caption := Format('%s - %s', [SCustomizerCaption, ACustomizer.Name]);
  tabValues.TabVisible := False;
  tabOptions.TabVisible := False;
  btnPresetPage.Visible := False;
  btnPresetSize.Visible := False;
  tabRules.PageIndex := 0; // rules are the usual way; single components are the exception
  pgcMain.ActivePage := tabRules;
  memRules.Lines.Assign(ACustomizer.Rules); // OnChange fills the preview
  FillTree;
  FillSelected;
end;

procedure TRadFormStateEditorForm.Apply;
begin
  FModel.SaveToStore;
  if FCustomizer <> nil then
    FCustomizer.Rules.Assign(memRules.Lines);
  if FModel.Store = nil then
    Exit; // customizer mode: no values or options
  ApplyValues;
  ApplyOptions;
end;

{ rules }

procedure TRadFormStateEditorForm.SelectedPathsOf(AComponent: TComponent; APaths: TStrings);
var
  LKey, LPrefix: string;
begin
  APaths.Clear;
  LPrefix := AComponent.Name + PATH_SEPARATOR;
  for LKey in FModel.Selection do
    if LKey.StartsWith(LPrefix, True) then
      APaths.Add(Copy(LKey, Length(LPrefix) + 1, MaxInt));
end;

function TRadFormStateEditorForm.PreviewComponent(ARules: TRadCustomizeRules; AComponent: TComponent): Integer;
var
  LExplicit, LPaths: TStringList;
begin
  LExplicit := TStringList.Create;
  try
    LPaths := TStringList.Create;
    try
      SelectedPathsOf(AComponent, LExplicit);
      ARules.PathsFor(AComponent, LExplicit, LPaths); // the same core the customizer runs
      Result := LPaths.Count;
      if Result > 0 then
        lstPreview.Items.Add(AComponent.Name + ': ' + string.Join(', ', LPaths.ToStringArray));
    finally
      LPaths.Free;
    end;
  finally
    LExplicit.Free;
  end;
end;

procedure TRadFormStateEditorForm.FillPreview;
var
  LRules: TRadCustomizeRules;
  I, LCount, LComponents, LTotal: Integer;
begin
  if (FCustomizer = nil) or (FCustomizer.Owner = nil) or (FModel = nil) then
    Exit;
  LComponents := 0;
  LTotal := 0;
  LRules := TRadCustomizeRules.Create;
  lstPreview.Items.BeginUpdate;
  try
    LRules.Add(memRules.Text);
    lstPreview.Items.Clear;
    for I := 0 to LRules.Errors.Count - 1 do
      lstPreview.Items.Add(SRuleErrorMark + LRules.Errors[I]);
    for I := 0 to FCustomizer.Owner.ComponentCount - 1 do
      if FCustomizer.Owner.Components[I].Name <> '' then
      begin
        LCount := PreviewComponent(LRules, FCustomizer.Owner.Components[I]);
        Inc(LComponents, Ord(LCount > 0));
        Inc(LTotal, LCount);
      end;
  finally
    lstPreview.Items.EndUpdate;
    LRules.Free;
  end;
  lblPreview.Caption := Format(SPreviewCaption, [LComponents, LTotal]);
end;

procedure TRadFormStateEditorForm.memRulesChange(Sender: TObject);
begin
  FillPreview;
end;

procedure TRadFormStateEditorForm.btnRulesAppearanceClick(Sender: TObject);
begin
  if Trim(memRules.Text) <> '' then // Text is TCaption: the string helper does not reach it (E2671)
    memRules.Lines.Add('');
  memRules.Lines.Add(RAD_CUSTOMIZE_APPEARANCE);
end;

{ tree }

function TRadFormStateEditorForm.ShowLeaf(const ALeaf: TRadStateLeaf): Boolean;
begin
  Result := not chkOnlySelected.Checked or FModel.IsSelected(ALeaf.Component, ALeaf.Path);
end;

function TRadFormStateEditorForm.ChildNode(AParent: TcxTreeListNode; const ACaption: string): TcxTreeListNode;
var
  I: Integer;
begin
  for I := 0 to AParent.Count - 1 do
    if AParent.Items[I].Texts[COL_NAME] = ACaption then
      Exit(AParent.Items[I]);
  Result := tlProps.AddChild(AParent);
  Result.Texts[COL_NAME] := ACaption;
  Result.CheckGroupType := ncgCheckGroup;
  Result.AllowGrayed := True;
end;

procedure TRadFormStateEditorForm.AddLeafNode(AParent: TcxTreeListNode; const ACaption: string;
  ALeafIndex: Integer);
var
  LNode: TcxTreeListNode;
  LLeaf: TRadStateLeaf;
begin
  LLeaf := FModel.Leaves[ALeafIndex];
  LNode := tlProps.AddChild(AParent, Pointer(ALeafIndex + 1)); // Data 0 marks a group node
  LNode.Texts[COL_NAME] := ACaption;
  LNode.Texts[COL_TYPE] := LLeaf.TypeName;
  if LLeaf.Restorable then
    LNode.Texts[COL_VALUE] := LLeaf.Value
  else
    LNode.Texts[COL_VALUE] := NOT_RESTORABLE_MARK + LLeaf.Reason;
  LNode.Enabled := LLeaf.Restorable;
  LNode.Checked := LLeaf.Restorable and FModel.IsSelected(LLeaf.Component, LLeaf.Path);
end;

procedure TRadFormStateEditorForm.FillByComponent;
var
  I: Integer;
  LParent: TcxTreeListNode;
  LParts: TArray<string>;
  J: Integer;
begin
  for I := 0 to FModel.Leaves.Count - 1 do
    if ShowLeaf(FModel.Leaves[I]) then
    begin
      LParent := ChildNode(tlProps.Root, FModel.Leaves[I].Component.Name);
      LParts := FModel.Leaves[I].Path.Split([PATH_SEPARATOR]);
      for J := 0 to High(LParts) - 1 do
        LParent := ChildNode(LParent, LParts[J]);
      AddLeafNode(LParent, LParts[High(LParts)], I);
    end;
end;

procedure TRadFormStateEditorForm.FillByProperty;
var
  I: Integer;
  LParent: TcxTreeListNode;
begin
  // One root per path, the components that have it underneath: 'Width' for every panel at once.
  for I := 0 to FModel.Leaves.Count - 1 do
    if ShowLeaf(FModel.Leaves[I]) then
    begin
      LParent := ChildNode(tlProps.Root, FModel.Leaves[I].Path);
      AddLeafNode(LParent, FModel.Leaves[I].Component.Name, I);
    end;
end;

procedure TRadFormStateEditorForm.FillTree;
begin
  FUpdating := True;
  tlProps.BeginUpdate;
  try
    tlProps.Clear;
    tlProps.Root.CheckGroupType := ncgCheckGroup;
    if chkGroupByProperty.Checked then
      FillByProperty
    else
      FillByComponent;
  finally
    tlProps.EndUpdate;
    FUpdating := False;
  end;
end;

procedure TRadFormStateEditorForm.SyncCheck(ANode: TcxTreeListNode);
var
  LLeaf: TRadStateLeaf;
begin
  if ANode.Data = nil then
    Exit; // a group node: the tree list raises the event again for each child (measured)
  LLeaf := FModel.Leaves[Integer(ANode.Data) - 1];
  if LLeaf.Restorable then
    FModel.SetSelected(LLeaf.Component, LLeaf.Path, ANode.CheckState = cbsChecked);
end;

procedure TRadFormStateEditorForm.tlPropsNodeCheckChanged(Sender: TcxCustomTreeList; ANode: TcxTreeListNode;
  AState: TcxCheckBoxState);
begin
  if FUpdating then
    Exit;
  SyncCheck(ANode);
  FillSelected;
end;

procedure TRadFormStateEditorForm.ViewChanged(Sender: TObject);
begin
  if FModel <> nil then
    FillTree;
end;

{ selected list }

procedure TRadFormStateEditorForm.FillSelected;
var
  LIndex: Integer;
begin
  LIndex := lstSelected.ItemIndex;
  lstSelected.Items.Assign(FModel.Selection);
  if LIndex >= lstSelected.Count then
    LIndex := lstSelected.Count - 1;
  lstSelected.ItemIndex := LIndex;
  if FCustomizer <> nil then
  begin
    lblSelected.Caption := Format(SAllowedCaption, [lstSelected.Count]);
    FillPreview;
  end
  else
    lblSelected.Caption := Format(SSelectedCaption, [lstSelected.Count]);
end;

procedure TRadFormStateEditorForm.MoveSelected(ADelta: Integer);
var
  LIndex: Integer;
begin
  LIndex := lstSelected.ItemIndex;
  if FModel.MoveSelection(LIndex, ADelta) then
  begin
    FillSelected;
    lstSelected.ItemIndex := LIndex + ADelta;
  end;
end;

procedure TRadFormStateEditorForm.btnUpClick(Sender: TObject);
begin
  MoveSelected(-1);
end;

procedure TRadFormStateEditorForm.btnDownClick(Sender: TObject);
begin
  MoveSelected(1);
end;

procedure TRadFormStateEditorForm.btnRemoveClick(Sender: TObject);
begin
  if lstSelected.ItemIndex < 0 then
    Exit;
  FModel.Selection.Delete(lstSelected.ItemIndex);
  FillSelected;
  FillTree;
end;

procedure TRadFormStateEditorForm.btnPresetPageClick(Sender: TObject);
begin
  FModel.ApplyPreset(spPage);
  FillSelected;
  FillTree;
end;

procedure TRadFormStateEditorForm.btnPresetSizeClick(Sender: TObject);
begin
  FModel.ApplyPreset(spSize);
  FillSelected;
  FillTree;
end;

{ values and options }

function TRadFormStateEditorForm.TypeNames: TStrings;
begin
  Result := (colValueType.Properties as TcxComboBoxProperties).Items; // ordered as TRadStoredValueType
end;

function TRadFormStateEditorForm.ValueTypeOf(ANode: TcxTreeListNode): TRadStoredValueType;
var
  LIndex: Integer;
begin
  LIndex := TypeNames.IndexOf(VarToStr(ANode.Values[colValueType.ItemIndex]));
  if LIndex < 0 then
    Result := svtVariant
  else
    Result := TRadStoredValueType(LIndex);
end;

procedure TRadFormStateEditorForm.FillValues;
var
  I: Integer;
  LValue: TRadStoredValue;
  LNode: TcxTreeListNode;
begin
  tlValues.Clear;
  for I := 0 to FModel.Store.StoredValues.Count - 1 do
  begin
    LValue := TRadStoredValue(FModel.Store.StoredValues.Items[I]);
    if LValue.Name = '' then
      Continue;
    LNode := tlValues.Add;
    LNode.Values[colValueName.ItemIndex] := LValue.Name;
    LNode.Values[colValueType.ItemIndex] := TypeNames[Ord(LValue.ValueType)];
    LNode.Values[colValueValue.ItemIndex] := VarToStr(LValue.Value);
  end;
end;

function TextToValue(const AText: string; AType: TRadStoredValueType; out AValue: Variant): Boolean;
var
  LInt: Integer;
begin
  AValue := Unassigned;
  Result := True;
  if AText = '' then
    Exit;
  if AType <> svtVariant then
    Exit(TRadStoredValue.Convert(AText, AType, AValue));
  if TryStrToInt(AText, LInt) then
    AValue := LInt
  else
    AValue := AText;
end;

function TRadFormStateEditorForm.InvalidValue: string;
var
  I: Integer;
  LName: string;
  LNames: TStringList;
  LValue: Variant;
begin
  tlValues.HideEdit; // posts a cell still being edited
  LNames := TStringList.Create;
  try
    for I := 0 to tlValues.Count - 1 do
    begin
      LName := Trim(VarToStr(tlValues.Items[I].Values[colValueName.ItemIndex]));
      if LName = '' then
        Continue;
      if (LNames.IndexOf(LName) >= 0) or not TextToValue(VarToStr(tlValues.Items[I].Values[
        colValueValue.ItemIndex]), ValueTypeOf(tlValues.Items[I]), LValue) then
        Exit(LName);
      LNames.Add(LName);
    end;
  finally
    LNames.Free;
  end;
  Result := '';
end;

procedure TRadFormStateEditorForm.ApplyValues;
var
  I: Integer;
  LNode: TcxTreeListNode;
  LName: string;
  LValue: TRadStoredValue;
  LData: Variant;
begin
  tlValues.HideEdit;
  FModel.Store.StoredValues.Clear;
  for I := 0 to tlValues.Count - 1 do
  begin
    LNode := tlValues.Items[I];
    LName := Trim(VarToStr(LNode.Values[colValueName.ItemIndex]));
    if (LName = '') or (FModel.Store.StoredValues.Find(LName) <> nil) then
      Continue;
    LValue := TRadStoredValue(FModel.Store.StoredValues.Add);
    LValue.Name := LName;
    LValue.ValueType := ValueTypeOf(LNode);
    TextToValue(VarToStr(LNode.Values[colValueValue.ItemIndex]), LValue.ValueType, LData);
    LValue.Value := LData; // Unassigned when the text does not fit; OK is blocked before that
  end;
end;

procedure TRadFormStateEditorForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  LInvalid: string;
begin
  if ModalResult <> mrOk then
    Exit;
  LInvalid := InvalidValue;
  CanClose := LInvalid = '';
  if not CanClose then
  begin
    pgcMain.ActivePage := tabValues;
    MessageDlg(Format(SInvalidValue, [LInvalid]), mtWarning, [mbOK], 0);
  end;
end;

procedure TRadFormStateEditorForm.btnValueAddClick(Sender: TObject);
var
  LNode: TcxTreeListNode;
begin
  LNode := tlValues.Add;
  LNode.Values[colValueType.ItemIndex] := TypeNames[Ord(svtVariant)];
  LNode.Focused := True;
  tlValues.FocusedColumn := colValueName;
end;

procedure TRadFormStateEditorForm.btnValueDeleteClick(Sender: TObject);
begin
  if tlValues.FocusedNode <> nil then
    tlValues.FocusedNode.Delete;
end;

procedure TRadFormStateEditorForm.FillOptions;
begin
  chkPlacement.Checked := soPlacement in FModel.Store.Options;
  chkActiveControl.Checked := soActiveControl in FModel.Store.Options;
  chkProps.Checked := soProps in FModel.Store.Options;
  chkValues.Checked := soValues in FModel.Store.Options;
  chkCustom.Checked := soCustom in FModel.Store.Options;
  edtVersion.Text := IntToStr(FModel.Store.Version);
  edtStorageName.Text := FModel.Store.StorageName;
end;

procedure TRadFormStateEditorForm.ApplyOptions;
var
  LOptions: TRadStateOptions;
begin
  LOptions := [];
  if chkPlacement.Checked then Include(LOptions, soPlacement);
  if chkActiveControl.Checked then Include(LOptions, soActiveControl);
  if chkProps.Checked then Include(LOptions, soProps);
  if chkValues.Checked then Include(LOptions, soValues);
  if chkCustom.Checked then Include(LOptions, soCustom);
  FModel.Store.Options := LOptions;
  FModel.Store.Version := StrToIntDef(edtVersion.Text, VERSION_DEFAULT);
  FModel.Store.StorageName := Trim(edtStorageName.Text);
end;

end.
