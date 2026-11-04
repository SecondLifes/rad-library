unit rad.desktop.view.Tests;

interface

uses
  DUnitX.TestFramework,
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.IOUtils,
  System.Generics.Collections,
  Vcl.Forms,
  Vcl.Controls,
  rad.formstate.store,
  rad.desktop.core,
  rad.desktop.commands,
  rad.desktop.widgets,
  rad.desktop.store,
  rad.desktop.view,
  rad.desktop;

type
  TRanList = class
  public
    Ran: TList<string>;
    constructor Create;
    destructor Destroy; override;
  end;

  [TestFixture]
  TDesktopViewTests = class
  private
    FForm: TForm;
    FView: TRADDesktopView;
    FCmds: TRadDeskCommands;
    FWidgets: TRadDeskWidgets;
    FRan: TRanList;
    FChanges: Integer;
    FDenied: string;
    procedure ViewChanged(Sender: TObject);
    procedure ConfirmYes(Sender: TObject; const AMessage: string; var AConfirmed: Boolean);
    procedure Seed;
    function TileOf(const ATarget: string): TRadDeskTileView;
    procedure Click(const P: TPoint);
    procedure Drag(const AFrom, ATo: TPoint);
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure Arrange_GroupsDoNotOverlap_TilesInsideGroups;
    [Test] procedure HitTest_TileTitleBodyDesktop;
    [Test] procedure Click_ExecutesCommand;
    [Test] procedure Denied_Hidden_Missing_Broken;
    [Test] procedure DragItem_ToOtherGroup_Moves;
    [Test] procedure DragItem_ToDesktop_CreatesGroup;
    [Test] procedure DragGroup_OntoAnother_NoOverlapLeft;
    [Test] procedure Locked_NoDrag;
    [Test] procedure Keyboard_ArrowsAndEnter;
    [Test] procedure Keyboard_TypeToFind;
    [Test] procedure Folder_ClickOpens_EscCloses;
    [Test] procedure Collapse_ShrinksGroup;
    [Test] procedure Widget_ErrorStaysOnTile;
    [Test] procedure Snapshot_WritesPng;
    [Test] procedure Dpi_TilesScale;
    [Test] procedure Narrow_GroupsStayVisible_StoredCellKept;
    [Test] procedure Reduced_InRemoteOrForced;
  end;

  [TestFixture]
  TDesktopStoreTests = class
  private
    FRoot: string;
    FStore: IRadStateStore;
    FRepo: TRadStateRepository;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure Load_Nothing_FalseAndEmpty;
    [Test] procedure SaveUser_ThenLoad_RoundTrip;
    [Test] procedure SaveBase_UserWithoutRecordGetsBase_VersionGrows;
    [Test] procedure Load_MergesNewBaseIntoUser;
    [Test] procedure ResetUser_FallsBackToBase;
    [Test] procedure Facade_KurKaydetKapat;
    [Test] procedure Facade_WithoutKur_Raises;
  end;

implementation

type
  TViewAccess = class(TRADDesktopView);

  TListSource = class(TInterfacedObject, IRadDeskCommandSource)
  private
    FRan: TRanList;
  public
    constructor Create(ARan: TRanList);
    function Prefix: string;
    procedure Enumerate(AList: TList<TRadDeskCommandInfo>);
    function Find(const AName: string; out AInfo: TRadDeskCommandInfo): Boolean;
    function Execute(const AName: string): Boolean;
  end;

const
  CNames: array[0..5] of string = ('Fatura', 'Irsaliye', 'Kasa', 'Banka', 'Cek', 'Senet');

constructor TRanList.Create;
begin
  inherited Create;
  Ran := TList<string>.Create;
end;

destructor TRanList.Destroy;
begin
  Ran.Free;
  inherited Destroy;
end;

constructor TListSource.Create(ARan: TRanList);
begin
  inherited Create;
  FRan := ARan;
end;

function TListSource.Prefix: string;
begin
  Result := 't';
end;

procedure TListSource.Enumerate(AList: TList<TRadDeskCommandInfo>);
var
  LName: string;
begin
  for LName in CNames do
    AList.Add(TRadDeskCommandInfo.Make('t:' + LName, LName, 'Test'));
end;

function TListSource.Find(const AName: string; out AInfo: TRadDeskCommandInfo): Boolean;
var
  LName: string;
begin
  for LName in CNames do
    if SameText(LName, AName) then
    begin
      AInfo := TRadDeskCommandInfo.Make('t:' + LName, LName, 'Test');
      Exit(True);
    end;
  Result := False;
end;

function TListSource.Execute(const AName: string): Boolean;
begin
  FRan.Ran.Add(AName);
  Result := True;
end;

{ TDesktopViewTests }

procedure TDesktopViewTests.ViewChanged(Sender: TObject);
begin
  Inc(FChanges);
end;

procedure TDesktopViewTests.ConfirmYes(Sender: TObject; const AMessage: string; var AConfirmed: Boolean);
begin
  AConfirmed := True;
end;

procedure TDesktopViewTests.Setup;
begin
  FRan := TRanList.Create;
  FCmds := TRadDeskCommands.Create;
  FCmds.Add(TListSource.Create(FRan));
  FDenied := '';
  FCmds.Allow :=
    function(const AId: string): Boolean
    begin
      Result := AId <> FDenied;
    end;
  FWidgets := TRadDeskWidgets.Create;
  FForm := TForm.CreateNew(nil);
  FForm.SetBounds(0, 0, 1200, 800);
  FForm.Position := poDesigned;
  FView := TRADDesktopView.Create(FForm);
  FView.Parent := FForm;
  FView.Align := alClient;
  FView.Effects := deFull;
  FView.Commands := FCmds;
  FView.Widgets := FWidgets;
  FView.OnChange := ViewChanged;
  FView.OnConfirm := ConfirmYes;
  FChanges := 0;
  Seed;
  FForm.Show;
  Application.ProcessMessages;
end;

procedure TDesktopViewTests.TearDown;
begin
  FForm.Free;
  FWidgets.Free;
  FCmds.Free;
  FRan.Free;
end;

procedure TDesktopViewTests.Seed;
var
  G: TRadDeskGroup;
begin
  G := FView.Layout.AddGroup('A');
  G.Items.Add(TRadDeskItem.Create(dkShortcut, 't:Fatura', 'a1'));
  G.Items.Add(TRadDeskItem.Create(dkShortcut, 't:Irsaliye', 'a2'));
  G.Items.Add(TRadDeskItem.Create(dkShortcut, 't:Kasa', 'a3'));
  G := FView.Layout.AddGroup('B');
  G.Col := 10;
  G.Items.Add(TRadDeskItem.Create(dkShortcut, 't:Banka', 'b1'));
  G.Items.Add(TRadDeskItem.Create(dkShortcut, 't:Yok', 'b2'));
  G := FView.Layout.AddGroup('K', gsFolder);
  G.Col := 20;
  G.Items.Add(TRadDeskItem.Create(dkShortcut, 't:Cek', 'k1'));
  FView.Rebuild;
end;

function TDesktopViewTests.TileOf(const ATarget: string): TRadDeskTileView;
var
  LTile: TRadDeskTileView;
begin
  FView.HitTest(Point(0, 0));
  for LTile in FView.Tiles do
    if LTile.Item.Target = ATarget then
      Exit(LTile);
  raise EAssertionFailed.Create('tile not found: ' + ATarget);
end;

procedure TDesktopViewTests.Click(const P: TPoint);
begin
  FView.Perform(WM_LBUTTONDOWN, MK_LBUTTON, MakeLParam(P.X, P.Y));
  FView.Perform(WM_LBUTTONUP, 0, MakeLParam(P.X, P.Y));
end;

procedure TDesktopViewTests.Drag(const AFrom, ATo: TPoint);
begin
  FView.Perform(WM_LBUTTONDOWN, MK_LBUTTON, MakeLParam(AFrom.X, AFrom.Y));
  FView.Perform(WM_MOUSEMOVE, MK_LBUTTON, MakeLParam(AFrom.X + 20, AFrom.Y + 20));
  FView.Perform(WM_MOUSEMOVE, MK_LBUTTON, MakeLParam(ATo.X, ATo.Y));
  FView.Perform(WM_LBUTTONUP, 0, MakeLParam(ATo.X, ATo.Y));
end;

procedure TDesktopViewTests.Arrange_GroupsDoNotOverlap_TilesInsideGroups;
var
  LGroups: TArray<TRadDeskGroupView>;
  LTile: TRadDeskTileView;
  LView: TRadDeskGroupView;
  I, J: Integer;
  LDummy: TRect;
begin
  FView.HitTest(Point(0, 0));
  LGroups := FView.GroupViews;
  Assert.AreEqual(3, Integer(Length(LGroups)));
  for I := 0 to High(LGroups) do
    for J := I + 1 to High(LGroups) do
      Assert.IsFalse(IntersectRect(LDummy, LGroups[I].Rect, LGroups[J].Rect));
  for LTile in FView.Tiles do
    for LView in LGroups do
      if LView.Group = LTile.Group then
        Assert.IsTrue(LView.Rect.Contains(LTile.Rect), LTile.Item.Id + ' outside its group');
end;

procedure TDesktopViewTests.HitTest_TileTitleBodyDesktop;
var
  LView: TRadDeskGroupView;
begin
  Assert.IsTrue(FView.HitTest(TileOf('t:Fatura').Rect.CenterPoint).Kind = hkItem);
  LView := FView.GroupViews[0];
  Assert.IsTrue(FView.HitTest(LView.TitleRect.CenterPoint).Kind = hkGroupTitle);
  Assert.IsTrue(FView.HitTest(Point(LView.Rect.Left + 4, LView.Rect.Bottom - 30)).Kind = hkGroupBody);
  Assert.IsTrue(FView.HitTest(Point(FView.ClientWidth - 5, FView.ClientHeight - 5)).Kind = hkDesktop);
  Assert.IsTrue(FView.HitTest(FView.GroupViews[2].Rect.CenterPoint).Kind = hkFolder);
end;

procedure TDesktopViewTests.Click_ExecutesCommand;
begin
  Click(TileOf('t:Kasa').Rect.CenterPoint);
  Assert.AreEqual(1, FRan.Ran.Count);
  Assert.AreEqual('Kasa', FRan.Ran[0]);
  Assert.AreEqual(0, FChanges, 'a click does not change the layout');
end;

procedure TDesktopViewTests.Denied_Hidden_Missing_Broken;
var
  LTile: TRadDeskTileView;
begin
  Assert.IsTrue(TileOf('t:Yok').State = crMissing);
  Click(TileOf('t:Yok').Rect.CenterPoint);
  Assert.AreEqual(0, FRan.Ran.Count, 'a broken shortcut never runs');
  FDenied := 't:Banka';
  FView.Rebuild;
  FView.HitTest(Point(0, 0));
  for LTile in FView.Tiles do
    Assert.AreNotEqual('t:Banka', LTile.Item.Target, 'denied is not drawn');
  Assert.IsFalse(FCmds.Execute('t:Banka'));
end;

procedure TDesktopViewTests.DragItem_ToOtherGroup_Moves;
var
  LTarget: TPoint;
begin
  LTarget := TileOf('t:Banka').Rect.CenterPoint;
  Drag(TileOf('t:Fatura').Rect.CenterPoint, Point(LTarget.X + 30, LTarget.Y));
  Assert.AreEqual(2, FView.Layout.Groups[0].Items.Count);
  Assert.AreEqual(3, FView.Layout.Groups[1].Items.Count);
  Assert.AreEqual('a1', FView.Layout.Groups[1].Items[1].Id, 'dropped after Banka');
  Assert.AreEqual(1, FChanges);
  Assert.AreEqual(0, FRan.Ran.Count, 'a drag is not a click');
end;

procedure TDesktopViewTests.DragItem_ToDesktop_CreatesGroup;
begin
  Drag(TileOf('t:Kasa').Rect.CenterPoint, Point(200, 700));
  Assert.AreEqual(4, FView.Layout.Groups.Count);
  Assert.AreEqual('a3', FView.Layout.Groups[3].Items[0].Id);
end;

procedure TDesktopViewTests.DragGroup_OntoAnother_NoOverlapLeft;
var
  LGroups: TArray<TRadDeskGroupView>;
  LFrom: TPoint;
  I, J: Integer;
  LDummy: TRect;
begin
  FView.HitTest(Point(0, 0));
  LFrom := Point(FView.GroupViews[1].TitleRect.Left + 60, FView.GroupViews[1].TitleRect.CenterPoint.Y);
  Drag(LFrom, Point(FView.GroupViews[0].TitleRect.Left + 80, FView.GroupViews[0].TitleRect.CenterPoint.Y + 20));
  Assert.AreEqual(1, FChanges);
  FView.HitTest(Point(0, 0));
  LGroups := FView.GroupViews;
  for I := 0 to High(LGroups) do
    for J := I + 1 to High(LGroups) do
      Assert.IsFalse(IntersectRect(LDummy, LGroups[I].Rect, LGroups[J].Rect));
  Assert.IsTrue(FView.Layout.Groups[1].Col < 10, 'B moved left');
end;

procedure TDesktopViewTests.Locked_NoDrag;
begin
  FView.Locked := True;
  Drag(TileOf('t:Fatura').Rect.CenterPoint, TileOf('t:Banka').Rect.CenterPoint);
  Assert.AreEqual(3, FView.Layout.Groups[0].Items.Count);
  Assert.AreEqual(0, FChanges);
end;

procedure TDesktopViewTests.Keyboard_ArrowsAndEnter;
begin
  FView.FocusItem('a1');
  FView.Perform(WM_KEYDOWN, VK_RIGHT, 0);
  Assert.AreEqual('a2', FView.FocusedItem.Id);
  FView.Perform(WM_KEYDOWN, VK_RETURN, 0);
  Assert.AreEqual('Irsaliye', FRan.Ran[0]);
end;

procedure TDesktopViewTests.Keyboard_TypeToFind;
begin
  FView.FocusItem('a1');
  FView.Perform(WM_CHAR, Ord('b'), 0);
  Assert.AreEqual('b1', FView.FocusedItem.Id);
end;

procedure TDesktopViewTests.Folder_ClickOpens_EscCloses;
begin
  FView.HitTest(Point(0, 0));
  Click(FView.GroupViews[2].Rect.CenterPoint);
  Assert.IsTrue(FView.PanelGroup = FView.Layout.Groups[2]);
  Assert.IsFalse(FView.PanelRect.IsEmpty);
  Assert.IsTrue(TileOf('t:Cek').InPanel);
  Click(TileOf('t:Cek').Rect.CenterPoint);
  Assert.AreEqual('Cek', FRan.Ran[0]);
  FView.Perform(WM_KEYDOWN, VK_ESCAPE, 0);
  Assert.IsNull(FView.PanelGroup);
end;

procedure TDesktopViewTests.Collapse_ShrinksGroup;
var
  LBefore: Integer;
begin
  FView.HitTest(Point(0, 0));
  LBefore := FView.GroupViews[0].Rect.Height;
  FView.ToggleCollapsed(FView.Layout.Groups[0]);
  FView.HitTest(Point(0, 0));
  Assert.IsTrue(FView.GroupViews[0].Rect.Height < LBefore div 2);
  Assert.IsTrue(FView.Layout.Groups[0].Collapsed);
  Assert.AreEqual(1, FChanges);
end;

procedure TDesktopViewTests.Widget_ErrorStaysOnTile;
var
  LItem: TRadDeskItem;
  LFile: string;
begin
  FWidgets.Add(TRadDeskFuncWidget.Create('boom', 'Boom', dsWide, 0,
    procedure(ASettings: string; AData: TRadDeskWidgetData)
    begin
      raise EInvalidOpException.Create('veri yok');
    end));
  LItem := FView.AddWidget(FView.Layout.Groups[0], 'boom');
  Assert.IsNotNull(LItem);
  FView.RefreshAllWidgets;
  LFile := TPath.Combine(TPath.GetTempPath, 'raddesk_widget.png');
  FView.SaveSnapshot(LFile);
  Assert.IsTrue(TFile.Exists(LFile));
  TFile.Delete(LFile);
end;

procedure TDesktopViewTests.Snapshot_WritesPng;
var
  LFile: string;
  LBytes: TBytes;
begin
  LFile := TPath.Combine(TPath.GetTempPath, 'raddesk_snapshot.png');
  FView.SaveSnapshot(LFile);
  LBytes := TFile.ReadAllBytes(LFile);
  TFile.Delete(LFile);
  Assert.IsTrue(Length(LBytes) > 1000);
  Assert.AreEqual(Byte($89), LBytes[0]);
  Assert.AreEqual(Byte(Ord('P')), LBytes[1]);
end;

procedure TDesktopViewTests.Dpi_TilesScale;
var
  LBefore, LAfter: Integer;
begin
  LBefore := TileOf('t:Fatura').Rect.Width;
  // CurrentPPI of a windowed control is GetDpiForWindow (96 in this runner) unless the form is not Scaled;
  // then it is the value ChangeScale records - what VCL calls on WM_DPICHANGED.
  FForm.Scaled := False;
  TViewAccess(FView).ChangeScale(144, 96, True);
  LAfter := TileOf('t:Fatura').Rect.Width;
  Assert.IsTrue((LAfter > LBefore * 1.3) and (LAfter < LBefore * 1.7),
    Format('96 dpi %d px, 144 dpi %d px, form ppi %d, view ppi %d', [LBefore, LAfter, FForm.CurrentPPI,
      FView.CurrentPPI]));
end;

procedure TDesktopViewTests.Narrow_GroupsStayVisible_StoredCellKept;
var
  LView: TRadDeskGroupView;
begin
  FForm.Width := 520;
  Application.ProcessMessages;
  FView.HitTest(Point(0, 0));
  for LView in FView.GroupViews do
    Assert.IsTrue(LView.Rect.Right <= FView.ClientWidth, LView.Group.Title + ' outside');
  Assert.AreEqual(10, FView.Layout.Groups[1].Col, 'the stored cell is not rewritten by a resize');
  Assert.AreEqual(0, FChanges);
end;

procedure TDesktopViewTests.Reduced_InRemoteOrForced;
begin
  FView.Effects := deReduced;
  Assert.IsTrue(FView.ReducedEffects);
  FView.Effects := deFull;
  Assert.IsFalse(FView.ReducedEffects);
  FView.Effects := deAuto;
  Assert.AreEqual(GetSystemMetrics(SM_REMOTESESSION) <> 0, FView.ReducedEffects);
end;

{ TDesktopStoreTests }

procedure TDesktopStoreTests.Setup;
begin
  FRoot := TPath.Combine(TPath.GetTempPath, 'raddesk_store_' + TRadDeskCodes.NewId);
  FStore := TRadFileStateStore.Create(FRoot);
  FRepo := TRadStateRepository.Create(FStore, nil, False);
end;

procedure TDesktopStoreTests.TearDown;
begin
  FRepo.Free;
  FStore := nil;
  if TDirectory.Exists(FRoot) then
    TDirectory.Delete(FRoot, True);
end;

procedure TDesktopStoreTests.Load_Nothing_FalseAndEmpty;
var
  LStore: TRadDeskStore;
  LLayout: TRadDeskLayout;
begin
  LStore := TRadDeskStore.Create(FRepo, 'ali');
  LLayout := TRadDeskLayout.Create;
  try
    LLayout.AddGroup('x');
    Assert.IsFalse(LStore.Load(LLayout));
    Assert.AreEqual(0, LLayout.Groups.Count);
  finally
    LLayout.Free;
    LStore.Free;
  end;
end;

procedure TDesktopStoreTests.SaveUser_ThenLoad_RoundTrip;
var
  LStore: TRadDeskStore;
  LA, LB: TRadDeskLayout;
begin
  LStore := TRadDeskStore.Create(FRepo, 'Ali');
  LA := TRadDeskLayout.Create;
  LB := TRadDeskLayout.Create;
  try
    LA.AddGroup('Satış').Items.Add(TRadDeskItem.Create(dkShortcut, 'act:x'));
    Assert.IsTrue(LStore.SaveUser(LA));
    Assert.IsFalse(LStore.SaveUser(LA), 'unchanged content is not written again');
    Assert.IsTrue(LStore.HasUserLayout);
    Assert.IsTrue(LStore.Load(LB));
    Assert.AreEqual(LA.ToJson, LB.ToJson);
  finally
    LB.Free;
    LA.Free;
    LStore.Free;
  end;
end;

procedure TDesktopStoreTests.SaveBase_UserWithoutRecordGetsBase_VersionGrows;
var
  LAdmin, LUser: TRadDeskStore;
  LBase, LLoaded: TRadDeskLayout;
begin
  LAdmin := TRadDeskStore.Create(FRepo, 'admin');
  LUser := TRadDeskStore.Create(FRepo, 'veli');
  LBase := TRadDeskLayout.Create;
  LLoaded := TRadDeskLayout.Create;
  try
    LBase.AddGroup('Ortak');
    LBase.Removed.Add('kalmamali');
    LAdmin.SaveBase(LBase);
    Assert.AreEqual(1, LBase.BaseVersion);
    LAdmin.SaveBase(LBase);
    Assert.AreEqual(2, LBase.BaseVersion);
    Assert.IsTrue(LUser.Load(LLoaded));
    Assert.AreEqual('Ortak', LLoaded.Groups[0].Title);
    Assert.AreEqual(0, LLoaded.Removed.Count, 'the company layer carries no removed list');
    Assert.AreEqual(2, LLoaded.BaseVersion);
  finally
    LLoaded.Free;
    LBase.Free;
    LUser.Free;
    LAdmin.Free;
  end;
end;

procedure TDesktopStoreTests.Load_MergesNewBaseIntoUser;
var
  LStore: TRadDeskStore;
  LBase, LUser, LLoaded: TRadDeskLayout;
begin
  LStore := TRadDeskStore.Create(FRepo, 'ayse');
  LBase := TRadDeskLayout.Create;
  LUser := TRadDeskLayout.Create;
  LLoaded := TRadDeskLayout.Create;
  try
    LBase.AddGroup('Ortak').Items.Add(TRadDeskItem.Create(dkShortcut, 'act:a', 'o1'));
    LStore.SaveBase(LBase);
    LStore.Load(LUser);
    LUser.Groups[0].Title := 'Benim';
    LUser.AddGroup('Kişisel');
    LStore.SaveUser(LUser);
    LBase.Groups[0].Items.Add(TRadDeskItem.Create(dkShortcut, 'act:b', 'o2'));
    LBase.AddGroup('Yeni ortak');
    LStore.SaveBase(LBase);
    Assert.IsTrue(LStore.Load(LLoaded));
    Assert.AreEqual(3, LLoaded.Groups.Count);
    Assert.AreEqual('Benim', LLoaded.Groups[0].Title, 'the user rename survives');
    Assert.AreEqual(2, LLoaded.Groups[0].Items.Count, 'the new company item arrives');
  finally
    LLoaded.Free;
    LUser.Free;
    LBase.Free;
    LStore.Free;
  end;
end;

procedure TDesktopStoreTests.ResetUser_FallsBackToBase;
var
  LStore: TRadDeskStore;
  LLayout: TRadDeskLayout;
begin
  LStore := TRadDeskStore.Create(FRepo, 'can');
  LLayout := TRadDeskLayout.Create;
  try
    LLayout.AddGroup('Ortak');
    LStore.SaveBase(LLayout);
    LLayout.AddGroup('Benim');
    LStore.SaveUser(LLayout);
    LStore.ResetUser;
    Assert.IsFalse(LStore.HasUserLayout);
    Assert.IsTrue(LStore.Load(LLayout));
    Assert.AreEqual(1, LLayout.Groups.Count);
  finally
    LLayout.Free;
    LStore.Free;
  end;
end;

procedure TDesktopStoreTests.Facade_KurKaydetKapat;
var
  LForm: TForm;
  LView: TRADDesktopView;
  LCheck: TRadDeskStore;
  LLayout: TRadDeskLayout;
begin
  LForm := TForm.CreateNew(nil);
  LLayout := TRadDeskLayout.Create;
  LCheck := TRadDeskStore.Create(FRepo, 'facade');
  try
    LView := TRADDesktopView.Create(LForm);
    LView.Parent := LForm;
    TRadDesktop.Kur(LView, FRepo, 'facade');
    Assert.IsTrue(TRadDesktop.Hazir);
    LView.NewGroup('Test', gsBox, Point(0, 0));
    Assert.IsFalse(LCheck.HasUserLayout, 'debounced: nothing written yet');
    TRadDesktop.Kapat;
    Assert.IsFalse(TRadDesktop.Hazir);
    Assert.IsTrue(LCheck.Load(LLayout), 'Kapat flushed the pending save');
    Assert.AreEqual('Test', LLayout.Groups[0].Title);
  finally
    TRadDesktop.Kapat;
    LCheck.Free;
    LLayout.Free;
    LForm.Free;
  end;
end;

procedure TDesktopStoreTests.Facade_WithoutKur_Raises;
begin
  TRadDesktop.Kapat;
  try
    TRadDesktop.Sifirla;
    Assert.Fail('Sifirla without Kur must raise');
  except
    on E: ERadDesktop do
      Assert.Pass;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDesktopViewTests);
  TDUnitX.RegisterTestFixture(TDesktopStoreTests);

end.
