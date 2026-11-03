unit FormStateEditorTests;

{ Tests of the TRadPropertiesStore design-time editor without the IDE: the model on a
  DFM-loaded form, and the editor form itself (DFM with DevExpress controls). }

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.Menus,
  Vcl.ComCtrls,
  DUnitX.TestFramework,
  cxTL,
  mormot.core.base,
  mormot.core.variants,
  mormot.core.unicode,
  rad.formstate.core,
  rad.formstate.store,
  rad.formstate.component,
  rad.rtl,
  Rad.Editor.FormState.Model,
  Rad.Editor.FormState,
  FormStateTestA;

type
  [TestFixture]
  TRadFormStateEditorTests = class
  private
    FRoot: string;
    FForm: TFormA;
    function HasLeaf(AModel: TRadStateEditorModel; const AComponent, APath: string;
      out ALeaf: TRadStateLeaf): Boolean;
    function FindNode(ANode: TcxTreeListNode; const ACaptions: array of string): TcxTreeListNode;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure Model_Build_ListsComponentPathsButNotTheStore;
    [Test]
    procedure Model_ComponentReference_IsListedNotRestorable;
    [Test]
    procedure Model_LoadFromStore_KeepsItemOrder;
    [Test]
    procedure Model_SaveToStore_GroupsByComponent;
    [Test]
    procedure Model_StatefulComponent_HasItsOwnStateRow;
    [Test]
    procedure Model_MoveSelection_StopsAtTheEnds;
    [Test]
    procedure Model_Presets_PickPageIndexAndDockedSize;
    [Test]
    procedure PagePreset_TabIndexPath_RestoresTheActivePage;
    [Test]
    procedure Form_Prepare_FillsTreeSelectionAndValues;
    [Test]
    procedure Form_CheckingALeaf_SelectsItAndApplyWritesItems;
    [Test]
    procedure Form_CheckingAGroup_SelectsEveryRestorableLeafBelow;
    [Test]
    procedure Form_WithoutApply_StoreIsUntouched;
    [Test]
    procedure Form_GroupByProperty_PutsPathsAtTheRoot;
    [Test]
    procedure Form_NotRestorableLeaf_IsDisabled;
  end;

implementation

uses
  System.IOUtils;

procedure TRadFormStateEditorTests.Setup;
begin
  FRoot := TPath.Combine(TPath.GetTempPath, 'radfsed_' + TGuid.NewGuid.ToString);
  TRadPropertiesStore.Configure(TRadStateRepository.Create(TRadFileStateStore.Create(FRoot)), 'test');
  FForm := TFormA.Create(nil);
end;

procedure TRadFormStateEditorTests.TearDown;
begin
  FForm.Free;
  TRadPropertiesStore.Shutdown;
  if TDirectory.Exists(FRoot) then
    TDirectory.Delete(FRoot, True);
end;

function TRadFormStateEditorTests.HasLeaf(AModel: TRadStateEditorModel; const AComponent, APath: string;
  out ALeaf: TRadStateLeaf): Boolean;
begin
  Result := AModel.LeafOf(FForm.FindComponent(AComponent), APath, ALeaf);
end;

function TRadFormStateEditorTests.FindNode(ANode: TcxTreeListNode; const ACaptions: array of string): TcxTreeListNode;
var
  I, J: Integer;
begin
  Result := ANode;
  for I := 0 to High(ACaptions) do
  begin
    ANode := Result;
    Result := nil;
    for J := 0 to ANode.Count - 1 do
      if ANode.Items[J].Texts[0] = ACaptions[I] then
        Result := ANode.Items[J];
    if Result = nil then
      Exit;
  end;
end;

procedure TRadFormStateEditorTests.Model_Build_ListsComponentPathsButNotTheStore;
var
  LModel: TRadStateEditorModel;
  LLeaf: TRadStateLeaf;
begin
  LModel := TRadStateEditorModel.Create(FForm.Store1);
  try
    LModel.Build;
    Assert.IsTrue(HasLeaf(LModel, 'Edit1', 'Width', LLeaf) and LLeaf.Restorable);
    Assert.IsTrue(HasLeaf(LModel, 'Edit1', 'Font.Size', LLeaf) and LLeaf.Restorable, 'nested class step');
    Assert.IsTrue(HasLeaf(LModel, 'StatusBar1', 'Panels.0.Width', LLeaf), 'collection index');
    Assert.IsTrue(HasLeaf(LModel, 'Memo1', 'Lines', LLeaf) and LLeaf.Restorable, 'TStrings leaf');
    for LLeaf in LModel.Leaves do
      Assert.IsFalse(LLeaf.Component is TRadPropertiesStore, 'the store lists itself');
  finally
    LModel.Free;
  end;
end;

procedure TRadFormStateEditorTests.Model_ComponentReference_IsListedNotRestorable;
var
  LModel: TRadStateEditorModel;
  LMenu: TPopupMenu;
  LLeaf: TRadStateLeaf;
begin
  LMenu := TPopupMenu.Create(FForm);
  LMenu.Name := 'Pop1';
  FForm.Edit1.PopupMenu := LMenu;
  LModel := TRadStateEditorModel.Create(FForm.Store1);
  try
    LModel.Build;
    Assert.IsTrue(HasLeaf(LModel, 'Edit1', 'PopupMenu', LLeaf));
    Assert.IsFalse(LLeaf.Restorable);
    Assert.IsTrue(LLeaf.Reason <> '');
  finally
    LModel.Free;
  end;
end;

procedure TRadFormStateEditorTests.Model_LoadFromStore_KeepsItemOrder;
var
  LModel: TRadStateEditorModel;
begin
  LModel := TRadStateEditorModel.Create(FForm.Store1);
  try
    LModel.LoadFromStore;
    Assert.AreEqual('Edit1.Width,Edit1.Text,Edit1.Font.Style,Memo1.Lines,StatusBar1.Panels.0.Width',
      LModel.Selection.CommaText);
  finally
    LModel.Free;
  end;
end;

procedure TRadFormStateEditorTests.Model_SaveToStore_GroupsByComponent;
var
  LModel: TRadStateEditorModel;
begin
  LModel := TRadStateEditorModel.Create(FForm.Store1);
  try
    LModel.LoadFromStore;
    LModel.SetSelected(FForm.Memo1, 'Width', True);
    LModel.SetSelected(FForm.Edit1, 'Text', False);
    LModel.SaveToStore;
  finally
    LModel.Free;
  end;
  Assert.AreEqual(3, FForm.Store1.Items.Count);
  Assert.AreSame(FForm.Edit1, FForm.Store1.Items[0].Component);
  Assert.AreEqual('Width,Font.Style', FForm.Store1.Items[0].Properties.CommaText);
  Assert.AreSame(FForm.Memo1, FForm.Store1.Items[1].Component);
  Assert.AreEqual('Lines,Width', FForm.Store1.Items[1].Properties.CommaText);
end;

procedure TRadFormStateEditorTests.Model_StatefulComponent_HasItsOwnStateRow;
var
  LList: TRadActionList;
  LModel: TRadStateEditorModel;
  LLeaf: TRadStateLeaf;
  LItem: TRadStateItem;
  I: Integer;
begin
  LList := TRadActionList.Create(FForm);
  LList.Name := 'Actions1';
  LModel := TRadStateEditorModel.Create(FForm.Store1);
  try
    LModel.Build;
    Assert.IsTrue(LModel.LeafOf(LList, STATE_SELF_PATH, LLeaf) and LLeaf.Restorable);
    LModel.LoadFromStore;
    LModel.SetSelected(LList, STATE_SELF_PATH, True);
    LModel.SaveToStore;
  finally
    LModel.Free;
  end;
  LItem := nil;
  for I := 0 to FForm.Store1.Items.Count - 1 do
    if FForm.Store1.Items[I].Component = LList then
      LItem := FForm.Store1.Items[I];
  Assert.IsTrue(LItem <> nil, 'an item for the list');
  Assert.AreEqual(0, LItem.Properties.Count, 'no paths: the list saves itself');
  LModel := TRadStateEditorModel.Create(FForm.Store1);
  try
    LModel.LoadFromStore;
    Assert.IsTrue(LModel.IsSelected(LList, STATE_SELF_PATH), 'reopening the editor shows it checked');
  finally
    LModel.Free;
  end;
end;

procedure TRadFormStateEditorTests.Model_MoveSelection_StopsAtTheEnds;
var
  LModel: TRadStateEditorModel;
begin
  LModel := TRadStateEditorModel.Create(FForm.Store1);
  try
    LModel.LoadFromStore;
    Assert.IsFalse(LModel.MoveSelection(0, -1));
    Assert.IsFalse(LModel.MoveSelection(LModel.Selection.Count - 1, 1));
    Assert.IsTrue(LModel.MoveSelection(0, 1));
    Assert.AreEqual('Edit1.Text', LModel.Selection[0]);
  finally
    LModel.Free;
  end;
end;

procedure TRadFormStateEditorTests.Model_Presets_PickPageIndexAndDockedSize;
var
  LModel: TRadStateEditorModel;
  LPages: TPageControl;
begin
  LPages := TPageControl.Create(FForm);
  LPages.Name := 'Pages1';
  LPages.Parent := FForm;
  LModel := TRadStateEditorModel.Create(FForm.Store1);
  try
    Assert.AreEqual(1, LModel.ApplyPreset(spPage));
    // ActivePageIndex is public, not published; TabIndex is the published path (Vcl.ComCtrls).
    Assert.IsTrue(LModel.IsSelected(LPages, 'TabIndex'), LModel.Selection.CommaText);
    Assert.IsTrue(LModel.ApplyPreset(spSize) >= 1);
    Assert.IsTrue(LModel.IsSelected(FForm.StatusBar1, 'Height'), 'alBottom docks by height');
  finally
    LModel.Free;
  end;
end;

procedure TRadFormStateEditorTests.PagePreset_TabIndexPath_RestoresTheActivePage;
const
  PAGE_COUNT = 3;
var
  LPages: TPageControl;
  LSheet: TTabSheet;
  LPaths: TStringList;
  LJson: RawUtf8;
  I: Integer;
begin
  LPages := TPageControl.Create(FForm);
  LPages.Parent := FForm;
  for I := 1 to PAGE_COUNT do
  begin
    LSheet := TTabSheet.Create(FForm);
    LSheet.PageControl := LPages;
  end;
  FForm.Show;
  LPaths := TStringList.Create;
  try
    LPaths.Add(TRadStateEditorModel.PresetPaths(LPages, spPage)[0]);
    LPages.ActivePageIndex := 2;
    LJson := TRadStatePaths.Capture(LPages, LPaths);
    LPages.ActivePageIndex := 0;
    TRadStatePaths.Apply(LPages, LPaths, DocDict(LJson, mFastFloat), TRadStateScale.None);
    Assert.AreEqual(2, LPages.ActivePageIndex, Utf8ToString(LJson));
  finally
    LPaths.Free;
  end;
end;

procedure TRadFormStateEditorTests.Form_Prepare_FillsTreeSelectionAndValues;
var
  LEditor: TRadFormStateEditorForm;
begin
  LEditor := TRadFormStateEditorForm.Create(nil);
  try
    LEditor.Prepare(FForm.Store1);
    Assert.IsTrue(FindNode(LEditor.tlProps.Root, ['Edit1', 'Font', 'Size']) <> nil, 'Edit1 > Font > Size');
    Assert.AreEqual(5, LEditor.lstSelected.Count);
    Assert.AreEqual('0', LEditor.vleValues.Values['counter']);
    Assert.IsTrue(LEditor.chkPlacement.Checked);
    Assert.AreEqual('1', LEditor.edtVersion.Text);
  finally
    LEditor.Free;
  end;
end;

procedure TRadFormStateEditorTests.Form_CheckingALeaf_SelectsItAndApplyWritesItems;
var
  LEditor: TRadFormStateEditorForm;
  LNode: TcxTreeListNode;
begin
  LEditor := TRadFormStateEditorForm.Create(nil);
  try
    LEditor.Prepare(FForm.Store1);
    LNode := FindNode(LEditor.tlProps.Root, ['Edit1', 'Height']);
    Assert.IsTrue(LNode <> nil);
    Assert.IsFalse(LNode.Checked);
    LNode.Checked := True;
    Assert.AreEqual(6, LEditor.lstSelected.Count);
    LEditor.Apply;
  finally
    LEditor.Free;
  end;
  Assert.IsTrue(FForm.Store1.Items[0].Properties.IndexOf('Height') >= 0);
end;

procedure TRadFormStateEditorTests.Form_CheckingAGroup_SelectsEveryRestorableLeafBelow;
var
  LEditor: TRadFormStateEditorForm;
  LGroup: TcxTreeListNode;
begin
  LEditor := TRadFormStateEditorForm.Create(nil);
  try
    LEditor.Prepare(FForm.Store1);
    LGroup := FindNode(LEditor.tlProps.Root, ['Edit1', 'Font']);
    Assert.IsTrue(LGroup <> nil);
    LGroup.Checked := True;
    Assert.IsTrue(LEditor.Model.IsSelected(FForm.Edit1, 'Font.Size'), 'Font.Size');
    Assert.IsTrue(LEditor.Model.IsSelected(FForm.Edit1, 'Font.Name'), 'Font.Name');
    Assert.IsTrue(LEditor.Model.IsSelected(FForm.Edit1, 'Font.Color'), 'Font.Color');
    Assert.IsTrue(LEditor.lstSelected.Count > 6, IntToStr(LEditor.lstSelected.Count));
  finally
    LEditor.Free;
  end;
end;

procedure TRadFormStateEditorTests.Form_WithoutApply_StoreIsUntouched;
var
  LEditor: TRadFormStateEditorForm;
  LBefore: string;
begin
  LBefore := FForm.Store1.Items[0].Properties.CommaText;
  LEditor := TRadFormStateEditorForm.Create(nil);
  try
    LEditor.Prepare(FForm.Store1);
    FindNode(LEditor.tlProps.Root, ['Edit1', 'Height']).Checked := True;
    LEditor.vleValues.Strings.Clear;
  finally
    LEditor.Free; // closed with Cancel
  end;
  Assert.AreEqual(LBefore, FForm.Store1.Items[0].Properties.CommaText);
  Assert.AreEqual(1, FForm.Store1.StoredValues.Count);
end;

procedure TRadFormStateEditorTests.Form_GroupByProperty_PutsPathsAtTheRoot;
var
  LEditor: TRadFormStateEditorForm;
begin
  LEditor := TRadFormStateEditorForm.Create(nil);
  try
    LEditor.Prepare(FForm.Store1);
    LEditor.chkGroupByProperty.Checked := True; // OnClick rebuilds the tree
    Assert.IsTrue(FindNode(LEditor.tlProps.Root, ['Width', 'Edit1']) <> nil, 'Width > Edit1');
    Assert.IsTrue(FindNode(LEditor.tlProps.Root, ['Width', 'Memo1']) <> nil, 'Width > Memo1');
    Assert.IsTrue(FindNode(LEditor.tlProps.Root, ['Width', 'Edit1']).Checked, 'selection survives');
  finally
    LEditor.Free;
  end;
end;

procedure TRadFormStateEditorTests.Form_NotRestorableLeaf_IsDisabled;
var
  LEditor: TRadFormStateEditorForm;
  LMenu: TPopupMenu;
  LNode: TcxTreeListNode;
begin
  LMenu := TPopupMenu.Create(FForm);
  LMenu.Name := 'Pop1';
  FForm.Edit1.PopupMenu := LMenu;
  LEditor := TRadFormStateEditorForm.Create(nil);
  try
    LEditor.Prepare(FForm.Store1);
    LNode := FindNode(LEditor.tlProps.Root, ['Edit1', 'PopupMenu']);
    Assert.IsTrue(LNode <> nil);
    Assert.IsFalse(LNode.Enabled);
  finally
    LEditor.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadFormStateEditorTests);

end.
