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
  Vcl.Grids,
  Vcl.ValEdit,
  cxGraphics,
  cxControls,
  cxLookAndFeels,
  cxLookAndFeelPainters,
  cxCustomData,
  cxStyles,
  cxTL,
  cxTextEdit,
  cxInplaceContainer,
  dxScrollbarAnnotations,
  cxTLdxBarBuiltInMenu,
  rad.formstate.component,
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
    vleValues: TValueListEditor;
    chkPlacement: TCheckBox;
    chkActiveControl: TCheckBox;
    chkProps: TCheckBox;
    chkValues: TCheckBox;
    chkCustom: TCheckBox;
    lblVersion: TLabel;
    edtVersion: TEdit;
    lblStorageName: TLabel;
    edtStorageName: TEdit;
    pnlButtons: TPanel;
    btnOk: TButton;
    btnCancel: TButton;
    procedure FormDestroy(Sender: TObject);
    procedure tlPropsNodeCheckChanged(Sender: TcxCustomTreeList; ANode: TcxTreeListNode;
      AState: TcxCheckBoxState);
    procedure ViewChanged(Sender: TObject);
    procedure btnPresetPageClick(Sender: TObject);
    procedure btnPresetSizeClick(Sender: TObject);
    procedure btnUpClick(Sender: TObject);
    procedure btnDownClick(Sender: TObject);
    procedure btnRemoveClick(Sender: TObject);
  private
    FModel: TRadStateEditorModel;
    FUpdating: Boolean;
    function ShowLeaf(const ALeaf: TRadStateLeaf): Boolean;
    function ChildNode(AParent: TcxTreeListNode; const ACaption: string): TcxTreeListNode;
    procedure AddLeafNode(AParent: TcxTreeListNode; const ACaption: string; ALeafIndex: Integer);
    procedure FillByComponent;
    procedure FillByProperty;
    procedure FillTree;
    procedure FillSelected;
    procedure FillValues;
    procedure FillOptions;
    procedure SyncCheck(ANode: TcxTreeListNode);
    procedure ApplyValues;
    procedure ApplyOptions;
    procedure MoveSelected(ADelta: Integer);
  public
    /// <summary>Loads the store into the form; nothing is written yet.</summary>
    procedure Prepare(AStore: TRadPropertiesStore);
    /// <summary>Writes the form back into the store (what OK does).</summary>
    procedure Apply;
    property Model: TRadStateEditorModel read FModel;
    /// <summary>Shows the editor modally; True when the store was changed.</summary>
    class function Execute(AStore: TRadPropertiesStore): Boolean; static;
  end;

implementation

uses
  System.Variants;

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
  FillTree;
  FillSelected;
  FillValues;
  FillOptions;
end;

procedure TRadFormStateEditorForm.Apply;
begin
  FModel.SaveToStore;
  ApplyValues;
  ApplyOptions;
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
  lblSelected.Caption := Format('Kaydedilecekler (%d, sırayla uygulanır)', [lstSelected.Count]);
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

procedure TRadFormStateEditorForm.FillValues;
var
  I: Integer;
  LValue: TRadStoredValue;
begin
  vleValues.Strings.Clear;
  for I := 0 to FModel.Store.StoredValues.Count - 1 do
  begin
    LValue := TRadStoredValue(FModel.Store.StoredValues.Items[I]);
    if LValue.Name <> '' then
      vleValues.Strings.AddPair(LValue.Name, VarToStr(LValue.Value));
  end;
end;

function TextToValue(const AText: string): Variant;
var
  LInt: Integer;
begin
  if AText = '' then
    Result := Unassigned
  else if TryStrToInt(AText, LInt) then
    Result := LInt
  else
    Result := AText;
end;

procedure TRadFormStateEditorForm.ApplyValues;
var
  I: Integer;
  LValue: TRadStoredValue;
begin
  FModel.Store.StoredValues.Clear;
  for I := 0 to vleValues.Strings.Count - 1 do
    if Trim(vleValues.Strings.Names[I]) <> '' then
    begin
      LValue := TRadStoredValue(FModel.Store.StoredValues.Add);
      LValue.Name := Trim(vleValues.Strings.Names[I]);
      LValue.Value := TextToValue(vleValues.Strings.ValueFromIndex[I]);
    end;
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
