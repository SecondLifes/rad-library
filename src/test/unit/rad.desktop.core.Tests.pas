unit rad.desktop.core.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Types,
  System.Rtti,
  System.Generics.Collections,
  mormot.core.base,
  rad.cmd,
  rad.desktop.core,
  rad.desktop.commands,
  rad.desktop.widgets;

type
  [TestFixture]
  TDesktopModelTests = class
  private
    function SampleLayout: TRadDeskLayout;
  public
    [Test] procedure Json_RoundTrip_KeepsEverything;
    [Test] procedure Json_RoundTrip_TurkishText;
    [Test] procedure FromJson_Invalid_ReturnsFalseAndKeepsLayout;
    [Test] procedure FromJson_NewerSchema_ReturnsFalse;
    [Test] procedure FromJson_DuplicateIds_KeepsFirst;
    [Test] procedure Cols_RoundsUpToWholeTiles;
    [Test] procedure DeleteGroup_RemembersGroupAndItems;
    [Test] procedure MergeBase_AddsNewButNotRemoved;
    [Test] procedure MergeBase_TwiceAddsNothing;
    [Test] procedure MoveItem_WithinAndAcrossGroups;
    [Test] procedure MoveItem_UnknownItem_ReturnsFalse;
  end;

  [TestFixture]
  TDesktopGridTests = class
  public
    [Test] procedure Pack_MixedSpans_FirstFit;
    [Test] procedure Pack_SpanWiderThanColumns_IsClamped;
    [Test] procedure Pack_Empty_OneRow;
    [Test] procedure Resolve_PushesOverlapsDown_NoOverlapLeft;
    [Test] procedure Resolve_NoOverlap_Unchanged;
    [Test] procedure Resolve_FixedNeverMoves;
    [Test] procedure Clamp_KeepsInsideColumns;
    [Test] procedure GroupRows_CollapsedAndFolder;
  end;

  [TestFixture]
  TDesktopNavTests = class
  public
    [Test] procedure Nearest_PicksClosestInDirection;
    [Test] procedure Nearest_NothingThatWay_MinusOne;
    [Test] procedure Fold_TurkishI_AndAccelerator;
    [Test] procedure Find_PrefersStartsWith_ThenContains;
    [Test] procedure Find_WrapsFromStart;
  end;

  [TestFixture]
  TDesktopCommandTests = class
  public
    [Test] procedure Resolve_Missing_Denied_Ok;
    [Test] procedure Execute_RechecksPermission;
    [Test] procedure All_FiltersAndSorts;
    [Test] procedure CmdSource_DescribeAndExecute;
    [Test] procedure SplitId_RejectsMalformed;
  end;

  [TestFixture]
  TDesktopWidgetTests = class
  public
    [Test] procedure SafeFetch_Exception_BecomesError;
    [Test] procedure Clock_FillsValue;
    [Test] procedure Registry_ReplacesSameId;
    [Test] procedure Signature_ChangesOnlyWithContent;
  end;

implementation

type
  /// In-memory source: names in FEnabled run, FRan records what ran.
  TFakeSource = class(TInterfacedObject, IRadDeskCommandSource)
  public
    FRan: TList<string>;
    constructor Create;
    destructor Destroy; override;
    function Prefix: string;
    procedure Enumerate(AList: TList<TRadDeskCommandInfo>);
    function Find(const AName: string; out AInfo: TRadDeskCommandInfo): Boolean;
    function Execute(const AName: string): Boolean;
  end;

constructor TFakeSource.Create;
begin
  inherited Create;
  FRan := TList<string>.Create;
end;

destructor TFakeSource.Destroy;
begin
  FRan.Free;
  inherited Destroy;
end;

function TFakeSource.Prefix: string;
begin
  Result := 'f';
end;

procedure TFakeSource.Enumerate(AList: TList<TRadDeskCommandInfo>);
var
  LHidden: TRadDeskCommandInfo;
begin
  AList.Add(TRadDeskCommandInfo.Make('f:zfatura', 'Fatura', 'Satış'));
  AList.Add(TRadDeskCommandInfo.Make('f:afis', 'Fiş', 'Alış'));
  AList.Add(TRadDeskCommandInfo.Make('f:yasak', 'Yasak', 'Alış'));
  LHidden := TRadDeskCommandInfo.Make('f:gizli', 'Gizli', 'Alış');
  LHidden.Visible := False;
  AList.Add(LHidden);
end;

function TFakeSource.Find(const AName: string; out AInfo: TRadDeskCommandInfo): Boolean;
begin
  Result := (AName = 'zfatura') or (AName = 'afis') or (AName = 'yasak') or (AName = 'gizli');
  AInfo := TRadDeskCommandInfo.Make('f:' + AName, AName, '');
  AInfo.Visible := AName <> 'gizli';
end;

function TFakeSource.Execute(const AName: string): Boolean;
begin
  FRan.Add(AName);
  Result := True;
end;

function RectsOverlap(const ARects: TArray<TRect>): Boolean;
var
  I, J: Integer;
  LDummy: TRect;
begin
  for I := 0 to High(ARects) do
    for J := I + 1 to High(ARects) do
      if IntersectRect(LDummy, ARects[I], ARects[J]) then
        Exit(True);
  Result := False;
end;

{ TDesktopModelTests }

function TDesktopModelTests.SampleLayout: TRadDeskLayout;
var
  LGroup: TRadDeskGroup;
  LItem: TRadDeskItem;
begin
  Result := TRadDeskLayout.Create;
  LGroup := Result.AddGroup('Satış');
  LGroup.Col := 2;
  LGroup.Row := 3;
  LGroup.Color := $FF3366CC;
  LGroup.Items.Add(TRadDeskItem.Create(dkShortcut, 'act:actFatura', 'i1'));
  LItem := TRadDeskItem.Create(dkWidget, 'clock', 'i2');
  LItem.Size := dsLarge;
  LItem.Settings := '{"a":1}';
  LItem.Caption := 'Saat';
  LGroup.Items.Add(LItem);
  LGroup := Result.AddGroup('Tahsilat', gsFolder);
  LGroup.Collapsed := True;
  Result.Removed.Add('eski');
  Result.BaseVersion := 7;
end;

procedure TDesktopModelTests.Json_RoundTrip_KeepsEverything;
var
  LSrc, LDst: TRadDeskLayout;
  LItem: TRadDeskItem;
begin
  LSrc := SampleLayout;
  try
    LDst := TRadDeskLayout.Create;
    try
      Assert.IsTrue(LDst.FromJson(LSrc.ToJson));
      Assert.AreEqual(2, LDst.Groups.Count);
      Assert.AreEqual(7, LDst.BaseVersion);
      Assert.AreEqual(1, LDst.Removed.Count);
      Assert.AreEqual(LSrc.Groups[0].Id, LDst.Groups[0].Id);
      Assert.AreEqual(2, LDst.Groups[0].Col);
      Assert.AreEqual(3, LDst.Groups[0].Row);
      Assert.AreEqual(Cardinal($FF3366CC), LDst.Groups[0].Color);
      Assert.IsTrue(LDst.Groups[1].Style = gsFolder);
      Assert.IsTrue(LDst.Groups[1].Collapsed);
      LItem := LDst.Groups[0].Items[1];
      Assert.IsTrue(LItem.Kind = dkWidget);
      Assert.IsTrue(LItem.Size = dsLarge);
      Assert.AreEqual('{"a":1}', LItem.Settings);
      Assert.AreEqual('Saat', LItem.Caption);
      Assert.AreEqual(LSrc.ToJson, LDst.ToJson);
    finally
      LDst.Free;
    end;
  finally
    LSrc.Free;
  end;
end;

procedure TDesktopModelTests.Json_RoundTrip_TurkishText;
var
  LSrc, LDst: TRadDeskLayout;
begin
  LSrc := TRadDeskLayout.Create;
  try
    LSrc.AddGroup('İşlemler ğüşıöç ĞÜŞİÖÇ');
    LDst := TRadDeskLayout.Create;
    try
      Assert.IsTrue(LDst.FromJson(LSrc.ToJson));
      Assert.AreEqual('İşlemler ğüşıöç ĞÜŞİÖÇ', LDst.Groups[0].Title);
    finally
      LDst.Free;
    end;
  finally
    LSrc.Free;
  end;
end;

procedure TDesktopModelTests.FromJson_Invalid_ReturnsFalseAndKeepsLayout;
var
  LLayout: TRadDeskLayout;
begin
  LLayout := SampleLayout;
  try
    Assert.IsFalse(LLayout.FromJson('{broken'));
    Assert.IsFalse(LLayout.FromJson('[1,2,3]'));
    Assert.IsFalse(LLayout.FromJson('{"groups":[]}'));
    Assert.IsFalse(LLayout.FromJson(''));
    Assert.AreEqual(2, LLayout.Groups.Count);
  finally
    LLayout.Free;
  end;
end;

procedure TDesktopModelTests.FromJson_NewerSchema_ReturnsFalse;
var
  LLayout: TRadDeskLayout;
begin
  LLayout := TRadDeskLayout.Create;
  try
    Assert.IsFalse(LLayout.FromJson('{"schema":99,"groups":[]}'));
    Assert.IsTrue(LLayout.FromJson('{"schema":1}'));
    Assert.AreEqual(0, LLayout.Groups.Count);
  finally
    LLayout.Free;
  end;
end;

procedure TDesktopModelTests.FromJson_DuplicateIds_KeepsFirst;
var
  LLayout: TRadDeskLayout;
begin
  LLayout := TRadDeskLayout.Create;
  try
    Assert.IsTrue(LLayout.FromJson('{"schema":1,"groups":[' +
      '{"id":"g","title":"A","items":[{"id":"x","kind":"shortcut","target":"a:1"},' +
      '{"id":"x","kind":"shortcut","target":"a:2"},{"id":"y","kind":"bogus"}]},' +
      '{"id":"g","title":"B"},{"title":"no id"}]}'));
    Assert.AreEqual(1, LLayout.Groups.Count);
    Assert.AreEqual('A', LLayout.Groups[0].Title);
    Assert.AreEqual(1, LLayout.Groups[0].Items.Count);
    Assert.AreEqual('a:1', LLayout.Groups[0].Items[0].Target);
  finally
    LLayout.Free;
  end;
end;

procedure TDesktopModelTests.Cols_RoundsUpToWholeTiles;
var
  LGroup: TRadDeskGroup;
begin
  LGroup := TRadDeskGroup.Create('x');
  try
    LGroup.Cols := 5;
    Assert.AreEqual(6, LGroup.Cols);
    LGroup.Cols := 1;
    Assert.AreEqual(RAD_DESK_MIN_GROUP_COLS, LGroup.Cols);
    LGroup.Cols := 10;
    Assert.AreEqual(10, LGroup.Cols);
  finally
    LGroup.Free;
  end;
end;

procedure TDesktopModelTests.DeleteGroup_RemembersGroupAndItems;
var
  LLayout: TRadDeskLayout;
  LId: string;
begin
  LLayout := SampleLayout;
  try
    LId := LLayout.Groups[0].Id;
    LLayout.DeleteGroup(LId);
    Assert.AreEqual(1, LLayout.Groups.Count);
    Assert.IsTrue(LLayout.Removed.IndexOf(LId) >= 0);
    Assert.IsTrue(LLayout.Removed.IndexOf('i1') >= 0);
    Assert.IsTrue(LLayout.Removed.IndexOf('i2') >= 0);
  finally
    LLayout.Free;
  end;
end;

procedure TDesktopModelTests.MergeBase_AddsNewButNotRemoved;
var
  LBase, LUser: TRadDeskLayout;
  LGroup: TRadDeskGroup;
begin
  LBase := TRadDeskLayout.Create;
  LUser := TRadDeskLayout.Create;
  try
    LGroup := LBase.AddGroup('Ortak');
    LGroup.Items.Add(TRadDeskItem.Create(dkShortcut, 'a:1', 'b1'));
    LGroup.Items.Add(TRadDeskItem.Create(dkShortcut, 'a:2', 'b2'));
    LBase.AddGroup('Silinen').Items.Add(TRadDeskItem.Create(dkShortcut, 'a:3', 'b3'));
    LBase.BaseVersion := 4;
    LUser.Removed.Add(LBase.Groups[1].Id);
    LUser.Removed.Add('b2');
    LUser.MergeBase(LBase);
    Assert.AreEqual(1, LUser.Groups.Count);
    Assert.AreEqual(1, LUser.Groups[0].Items.Count);
    Assert.AreEqual('b1', LUser.Groups[0].Items[0].Id);
    Assert.AreEqual(4, LUser.BaseVersion);
    LGroup.Items.Add(TRadDeskItem.Create(dkShortcut, 'a:4', 'b4'));
    LUser.MergeBase(LBase);
    Assert.AreEqual(2, LUser.Groups[0].Items.Count);
  finally
    LUser.Free;
    LBase.Free;
  end;
end;

procedure TDesktopModelTests.MergeBase_TwiceAddsNothing;
var
  LBase, LUser: TRadDeskLayout;
  LJson: RawUtf8;
begin
  LBase := SampleLayout;
  LUser := TRadDeskLayout.Create;
  try
    LUser.MergeBase(LBase);
    LJson := LUser.ToJson;
    LUser.MergeBase(LBase);
    Assert.AreEqual(LJson, LUser.ToJson);
  finally
    LUser.Free;
    LBase.Free;
  end;
end;

procedure TDesktopModelTests.MoveItem_WithinAndAcrossGroups;
var
  LLayout: TRadDeskLayout;
  LFirst, LSecond: TRadDeskGroup;
begin
  LLayout := SampleLayout;
  try
    LFirst := LLayout.Groups[0];
    LSecond := LLayout.Groups[1];
    Assert.IsTrue(LLayout.MoveItem('i1', LFirst, 2));
    Assert.AreEqual('i2', LFirst.Items[0].Id);
    Assert.AreEqual('i1', LFirst.Items[1].Id);
    Assert.IsTrue(LLayout.MoveItem('i1', LSecond, -1));
    Assert.AreEqual(1, LFirst.Items.Count);
    Assert.AreEqual('i1', LSecond.Items[0].Id);
  finally
    LLayout.Free;
  end;
end;

procedure TDesktopModelTests.MoveItem_UnknownItem_ReturnsFalse;
var
  LLayout: TRadDeskLayout;
begin
  LLayout := SampleLayout;
  try
    Assert.IsFalse(LLayout.MoveItem('none', LLayout.Groups[0], 0));
    Assert.IsFalse(LLayout.MoveItem('i1', nil, 0));
  finally
    LLayout.Free;
  end;
end;

{ TDesktopGridTests }

procedure TDesktopGridTests.Pack_MixedSpans_FirstFit;
var
  LPacked: TRadDeskPacked;
begin
  LPacked := TRadDeskGrid.Pack([Point(1, 1), Point(2, 2), Point(1, 1), Point(2, 1), Point(1, 1)], 4);
  // 4 columns: A(0,0), B 2x2 at (1,0), C(3,0); the wide D finds no 2-cell gap until row 2; E fills (0,1).
  Assert.AreEqual<TPoint>(Point(0, 0), LPacked.Cells[0]);
  Assert.AreEqual<TPoint>(Point(1, 0), LPacked.Cells[1]);
  Assert.AreEqual<TPoint>(Point(3, 0), LPacked.Cells[2]);
  Assert.AreEqual<TPoint>(Point(0, 2), LPacked.Cells[3]);
  Assert.AreEqual<TPoint>(Point(0, 1), LPacked.Cells[4]);
  Assert.AreEqual(3, LPacked.Rows);
end;

procedure TDesktopGridTests.Pack_SpanWiderThanColumns_IsClamped;
var
  LPacked: TRadDeskPacked;
begin
  LPacked := TRadDeskGrid.Pack([Point(3, 1), Point(1, 1)], 2);
  Assert.AreEqual<TPoint>(Point(0, 0), LPacked.Cells[0]);
  Assert.AreEqual<TPoint>(Point(0, 1), LPacked.Cells[1]);
  Assert.AreEqual(2, LPacked.Rows);
end;

procedure TDesktopGridTests.Pack_Empty_OneRow;
begin
  Assert.AreEqual(1, TRadDeskGrid.Pack([], 4).Rows);
end;

procedure TDesktopGridTests.Resolve_PushesOverlapsDown_NoOverlapLeft;
var
  LOut: TArray<TRect>;
begin
  TRadDeskGrid.Resolve([Rect(0, 0, 4, 4), Rect(2, 2, 6, 5), Rect(4, 4, 8, 6), Rect(10, 0, 12, 2)], 0, LOut);
  Assert.IsFalse(RectsOverlap(LOut));
  Assert.AreEqual<TRect>(Rect(0, 0, 4, 4), LOut[0]);
  Assert.AreEqual(4, LOut[1].Top);
  Assert.AreEqual<TRect>(Rect(10, 0, 12, 2), LOut[3]);
end;

procedure TDesktopGridTests.Resolve_NoOverlap_Unchanged;
var
  LIn, LOut: TArray<TRect>;
  I: Integer;
begin
  LIn := [Rect(0, 0, 2, 2), Rect(2, 0, 4, 2), Rect(0, 5, 3, 6)];
  TRadDeskGrid.Resolve(LIn, -1, LOut);
  for I := 0 to High(LIn) do
    Assert.AreEqual<TRect>(LIn[I], LOut[I]);
end;

procedure TDesktopGridTests.Resolve_FixedNeverMoves;
var
  LOut: TArray<TRect>;
begin
  TRadDeskGrid.Resolve([Rect(0, 0, 4, 4), Rect(0, 1, 4, 3)], 1, LOut);
  Assert.AreEqual<TRect>(Rect(0, 1, 4, 3), LOut[1]);
  Assert.AreEqual(3, LOut[0].Top);
  Assert.IsFalse(RectsOverlap(LOut));
end;

procedure TDesktopGridTests.Clamp_KeepsInsideColumns;
begin
  Assert.AreEqual<TRect>(Rect(6, 0, 10, 2), TRadDeskGrid.Clamp(Rect(8, 0, 12, 2), 10));
  Assert.AreEqual<TRect>(Rect(0, 0, 4, 2), TRadDeskGrid.Clamp(Rect(-3, -1, 1, 1), 10));
  Assert.AreEqual<TRect>(Rect(0, 3, 12, 5), TRadDeskGrid.Clamp(Rect(0, 3, 12, 5), 10), 'wider than grid: left wins');
end;

procedure TDesktopGridTests.GroupRows_CollapsedAndFolder;
var
  LGroup: TRadDeskGroup;
begin
  LGroup := TRadDeskGroup.Create('x');
  try
    Assert.AreEqual(1 + 3 * RAD_DESK_TILE_CELLS, TRadDeskGrid.GroupRows(LGroup, 3));
    Assert.AreEqual(1 + RAD_DESK_TILE_CELLS, TRadDeskGrid.GroupRows(LGroup, 0));
    LGroup.Collapsed := True;
    Assert.AreEqual(1, TRadDeskGrid.GroupRows(LGroup, 3));
    LGroup.Style := gsFolder;
    Assert.AreEqual(RAD_DESK_FOLDER_CELLS, TRadDeskGrid.GroupRows(LGroup, 3));
  finally
    LGroup.Free;
  end;
end;

{ TDesktopNavTests }

procedure TDesktopNavTests.Nearest_PicksClosestInDirection;
var
  LRects: TArray<TRect>;
begin
  LRects := [Rect(100, 100, 120, 120), Rect(200, 100, 220, 120), Rect(140, 300, 160, 320),
    Rect(130, 110, 150, 130), Rect(100, 0, 120, 20)];
  Assert.AreEqual(3, TRadDeskNav.Nearest(LRects, 0, ddRight));
  Assert.AreEqual(2, TRadDeskNav.Nearest(LRects, 0, ddDown));
  Assert.AreEqual(4, TRadDeskNav.Nearest(LRects, 0, ddUp));
  Assert.AreEqual(0, TRadDeskNav.Nearest(LRects, 3, ddLeft));
end;

procedure TDesktopNavTests.Nearest_NothingThatWay_MinusOne;
begin
  Assert.AreEqual(-1, TRadDeskNav.Nearest([Rect(0, 0, 10, 10), Rect(20, 0, 30, 10)], 0, ddLeft));
  Assert.AreEqual(-1, TRadDeskNav.Nearest([Rect(0, 0, 10, 10)], 5, ddLeft));
end;

procedure TDesktopNavTests.Fold_TurkishI_AndAccelerator;
begin
  Assert.AreEqual(TRadDeskNav.Fold('İSTANBUL'), TRadDeskNav.Fold('ıstanbul'));
  Assert.AreEqual(TRadDeskNav.Fold('ISTANBUL'), TRadDeskNav.Fold('istanbul'));
  Assert.AreEqual('fatura', TRadDeskNav.Fold('&Fatura'));
  // Arama kutusuyla aynı kural (rad.search.match): Türkçe harfler ASCII karşılığına katlanır.
  Assert.AreEqual('csguo', TRadDeskNav.Fold('ÇŞĞÜÖ'));
end;

procedure TDesktopNavTests.Find_PrefersStartsWith_ThenContains;
var
  LCaps: TArray<string>;
begin
  LCaps := ['Cari Tediye', 'Tediye Fişi', 'Çek Tediyesi'];
  Assert.AreEqual(1, TRadDeskNav.Find(LCaps, -1, 'tedi'));
  Assert.AreEqual(2, TRadDeskNav.Find(LCaps, -1, 'çek'));
  Assert.AreEqual(0, TRadDeskNav.Find(LCaps, -1, 'cari'));
  Assert.AreEqual(-1, TRadDeskNav.Find(LCaps, -1, 'yok'));
  Assert.AreEqual(1, TRadDeskNav.Find(['x', 'Tahsilat'], -1, 'TAHSİLAT'));
end;

procedure TDesktopNavTests.Find_WrapsFromStart;
begin
  Assert.AreEqual(0, TRadDeskNav.Find(['Fatura A', 'B', 'Fatura C'], 2, 'fat'));
  Assert.AreEqual(2, TRadDeskNav.Find(['Fatura A', 'B', 'Fatura C'], 0, 'fat'));
end;

{ TDesktopCommandTests }

procedure TDesktopCommandTests.Resolve_Missing_Denied_Ok;
var
  LCmds: TRadDeskCommands;
  LInfo: TRadDeskCommandInfo;
begin
  LCmds := TRadDeskCommands.Create;
  try
    LCmds.Add(TFakeSource.Create);
    LCmds.Allow :=
      function(const AId: string): Boolean
      begin
        Result := AId <> 'f:yasak';
      end;
    Assert.IsTrue(LCmds.Resolve('f:afis', LInfo) = crOk);
    Assert.AreEqual('f:afis', LInfo.Id);
    Assert.IsTrue(LCmds.Resolve('f:yasak', LInfo) = crDenied);
    Assert.IsTrue(LCmds.Resolve('f:gizli', LInfo) = crHidden);
    Assert.IsTrue(LCmds.Resolve('f:yok', LInfo) = crMissing);
    Assert.IsTrue(LCmds.Resolve('x:afis', LInfo) = crMissing);
    Assert.IsTrue(LCmds.Resolve('afis', LInfo) = crMissing);
  finally
    LCmds.Free;
  end;
end;

procedure TDesktopCommandTests.Execute_RechecksPermission;
var
  LCmds: TRadDeskCommands;
  LSource: TFakeSource;
  LKeep: IRadDeskCommandSource;
  LDeny: Boolean;
begin
  LCmds := TRadDeskCommands.Create;
  try
    LSource := TFakeSource.Create;
    LKeep := LSource;
    LCmds.Add(LKeep);
    LDeny := False;
    LCmds.Allow :=
      function(const AId: string): Boolean
      begin
        Result := not LDeny;
      end;
    Assert.IsTrue(LCmds.Execute('f:afis'));
    LDeny := True;
    Assert.IsFalse(LCmds.Execute('f:afis'));
    Assert.IsFalse(LCmds.Execute('f:gizli'));
    Assert.AreEqual(1, LSource.FRan.Count);
  finally
    LCmds.Free;
  end;
end;

procedure TDesktopCommandTests.All_FiltersAndSorts;
var
  LCmds: TRadDeskCommands;
  LAll: TRadDeskCommandInfos;
begin
  LCmds := TRadDeskCommands.Create;
  try
    LCmds.Add(TFakeSource.Create);
    LCmds.Allow :=
      function(const AId: string): Boolean
      begin
        Result := AId <> 'f:yasak';
      end;
    LAll := LCmds.All;
    Assert.AreEqual(2, Integer(Length(LAll)));
    Assert.AreEqual('f:afis', LAll[0].Id, 'Alış before Satış');
    Assert.AreEqual('f:zfatura', LAll[1].Id);
  finally
    LCmds.Free;
  end;
end;

procedure TDesktopCommandTests.CmdSource_DescribeAndExecute;
var
  LCmds: TRadDeskCommands;
  LSource: TRadDeskCmdSource;
  LKeep: IRadDeskCommandSource;
  LRan: Integer;
  LInfo: TRadDeskCommandInfo;
  LFuncs: ICmds;
begin
  LRan := 0;
  LFuncs := TRadCmds.New;
  LFuncs.RegisterCommand('KurGuncelle',
    function(Sender: TObject; const Args: TArray<TValue>): TValue
    begin
      Inc(LRan);
      Result := TValue.Empty;
    end);
  LSource := TRadDeskCmdSource.Create(LFuncs);
  LKeep := LSource;
  LSource.Describe('KurGuncelle', 'Kur güncelle', 'Finans');
  LCmds := TRadDeskCommands.Create;
  try
    LCmds.Add(LKeep);
    Assert.IsTrue(LCmds.Resolve('cmd:KurGuncelle', LInfo) = crOk);
    Assert.AreEqual('Kur güncelle', LInfo.Caption);
    Assert.AreEqual(1, Integer(Length(LCmds.All)));
    Assert.IsTrue(LCmds.Execute('cmd:KurGuncelle'));
    Assert.AreEqual(1, LRan);
    Assert.IsTrue(LCmds.Resolve('cmd:Yok', LInfo) = crMissing);
  finally
    LCmds.Free;
  end;
end;

procedure TDesktopCommandTests.SplitId_RejectsMalformed;
var
  LPrefix, LName: string;
begin
  Assert.IsTrue(TRadDeskCommands.SplitId('act:a:b', LPrefix, LName));
  Assert.AreEqual('act', LPrefix);
  Assert.AreEqual('a:b', LName);
  Assert.IsFalse(TRadDeskCommands.SplitId(':x', LPrefix, LName));
  Assert.IsFalse(TRadDeskCommands.SplitId('act:', LPrefix, LName));
  Assert.IsFalse(TRadDeskCommands.SplitId('act', LPrefix, LName));
end;

{ TDesktopWidgetTests }

procedure TDesktopWidgetTests.SafeFetch_Exception_BecomesError;
var
  LData: TRadDeskWidgetData;
  LProvider: IRadDeskWidgetProvider;
begin
  LProvider := TRadDeskFuncWidget.Create('boom', 'Boom', dsSmall, 0,
    procedure(ASettings: string; AData: TRadDeskWidgetData)
    begin
      AData.Value := 'half';
      raise EInvalidOpException.Create('kaput');
    end);
  LData := TRadDeskWidgetData.Create;
  try
    TRadDeskWidgets.SafeFetch(LProvider, '', LData);
    Assert.AreEqual('kaput', LData.Error);
    Assert.AreEqual('', LData.Value, 'partial data is dropped');
    Assert.IsTrue(LData.Updated > 0);
  finally
    LData.Free;
  end;
end;

procedure TDesktopWidgetTests.Clock_FillsValue;
var
  LData: TRadDeskWidgetData;
  LClock: IRadDeskWidgetProvider;
begin
  // A constructor passed straight to a const interface parameter is never released: hold it.
  LClock := TRadDeskClockWidget.Create;
  LData := TRadDeskWidgetData.Create;
  try
    TRadDeskWidgets.SafeFetch(LClock, '', LData);
    Assert.AreEqual('', LData.Error);
    Assert.AreEqual(5, Length(LData.Value));
  finally
    LData.Free;
  end;
end;

procedure TDesktopWidgetTests.Registry_ReplacesSameId;
var
  LReg: TRadDeskWidgets;
begin
  LReg := TRadDeskWidgets.Create;
  try
    LReg.Add(TRadDeskFuncWidget.Create('k', 'A', dsSmall, 0, nil));
    LReg.Add(TRadDeskFuncWidget.Create('K', 'B', dsSmall, 0, nil));
    Assert.AreEqual(1, Integer(Length(LReg.All)));
    Assert.AreEqual('B', LReg.Find('k').Caption);
    Assert.IsNull(LReg.Find('none'));
  finally
    LReg.Free;
  end;
end;

procedure TDesktopWidgetTests.Signature_ChangesOnlyWithContent;
var
  A, B: TRadDeskWidgetData;
begin
  A := TRadDeskWidgetData.Create;
  B := TRadDeskWidgetData.Create;
  try
    A.Value := '12';
    A.AddPoint(1.5);
    A.AddLine('x');
    B.Assign(A);
    B.Updated := Now + 1;
    Assert.AreEqual(A.Signature, B.Signature, 'the refresh time is not content');
    B.AddPoint(2);
    Assert.AreNotEqual(A.Signature, B.Signature);
    B.Assign(A);
    B.Trend := dtUp;
    Assert.AreNotEqual(A.Signature, B.Signature);
  finally
    B.Free;
    A.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDesktopModelTests);
  TDUnitX.RegisterTestFixture(TDesktopGridTests);
  TDUnitX.RegisterTestFixture(TDesktopNavTests);
  TDUnitX.RegisterTestFixture(TDesktopCommandTests);
  TDUnitX.RegisterTestFixture(TDesktopWidgetTests);

end.
