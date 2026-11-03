unit rad.desktop.core;

(* Model of the ERP desktop (docs/specs/rad.desktop.md): groups of shortcuts and widgets placed on a
   cell grid, JSON round trip, company/user layer merge, grid packing and keyboard navigation.
   RTL + mORMot only; the VCL view lives in rad.desktop.view. *)

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.Generics.Collections,
  mormot.core.base,
  mormot.core.variants;

const
  RAD_DESK_SCHEMA = 1;
  /// <summary>A tile (one shortcut) is this many cells wide and high.</summary>
  RAD_DESK_TILE_CELLS = 2;
  /// <summary>Smallest box group width in cells (two tiles).</summary>
  RAD_DESK_MIN_GROUP_COLS = 4;
  RAD_DESK_DEFAULT_GROUP_COLS = 8;
  /// <summary>A folder group is one tile on the grid.</summary>
  RAD_DESK_FOLDER_CELLS = 2;
  /// <summary>Tiles per row in an opened folder panel.</summary>
  RAD_DESK_FOLDER_PANEL_TILES = 4;

type
  ERadDesktop = class(Exception);

  TRadDeskItemKind = (dkShortcut, dkWidget, dkDashboard);
  TRadDeskGroupStyle = (gsBox, gsFolder);
  /// <summary>Widget size in tiles: 1x1, 2x1, 2x2.</summary>
  TRadDeskSize = (dsSmall, dsWide, dsLarge);
  TRadDeskDirection = (ddLeft, ddUp, ddRight, ddDown);

  TRadDeskItem = class
  private
    FId: string;
    FKind: TRadDeskItemKind;
    FTarget: string;
    FCaption: string;
    FSize: TRadDeskSize;
    FSettings: string;
  public
    /// <summary>An empty AId gets a new unique id.</summary>
    constructor Create(AKind: TRadDeskItemKind; const ATarget: string; const AId: string = '');
    function Clone: TRadDeskItem;
    /// <summary>Width and height in tiles; a shortcut is always 1x1.</summary>
    function TileSpan: TPoint;
    property Id: string read FId;
    property Kind: TRadDeskItemKind read FKind write FKind;
    /// <summary>Command id ('act:actFatura'), widget provider id or dashboard name.</summary>
    property Target: string read FTarget write FTarget;
    /// <summary>Empty: the caption comes from the command or the provider.</summary>
    property Caption: string read FCaption write FCaption;
    property Size: TRadDeskSize read FSize write FSize;
    /// <summary>Provider-specific JSON, opaque to the desktop.</summary>
    property Settings: string read FSettings write FSettings;
  end;

  TRadDeskItems = TObjectList<TRadDeskItem>;

  TRadDeskGroup = class
  private
    FId: string;
    FTitle: string;
    FColor: Cardinal;
    FStyle: TRadDeskGroupStyle;
    FCol: Integer;
    FRow: Integer;
    FCols: Integer;
    FCollapsed: Boolean;
    FItems: TRadDeskItems;
    procedure SetCols(AValue: Integer);
  public
    constructor Create(const ATitle: string; const AId: string = '');
    destructor Destroy; override;
    function Clone: TRadDeskGroup;
    function IndexOfItem(const AId: string): Integer;
    function FindItem(const AId: string): TRadDeskItem;
    property Id: string read FId;
    property Title: string read FTitle write FTitle;
    /// <summary>ARGB accent; 0 means the theme's default.</summary>
    property Color: Cardinal read FColor write FColor;
    property Style: TRadDeskGroupStyle read FStyle write FStyle;
    /// <summary>Top-left cell. Pixels are never stored: the cell survives DPI and resolution changes.</summary>
    property Col: Integer read FCol write FCol;
    property Row: Integer read FRow write FRow;
    /// <summary>Width in cells for a box group (rounded up to whole tiles); a folder ignores it.</summary>
    property Cols: Integer read FCols write SetCols;
    property Collapsed: Boolean read FCollapsed write FCollapsed;
    property Items: TRadDeskItems read FItems;
  end;

  TRadDeskGroups = TObjectList<TRadDeskGroup>;

  TRadDeskLayout = class
  private
    FGroups: TRadDeskGroups;
    FRemoved: TStringList;
    FBaseVersion: Integer;
    procedure ReadGroups(const AArr: PDocVariantData);
    function GroupToDoc(AGroup: TRadDeskGroup): Variant;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Assign(ASource: TRadDeskLayout);
    function ToJson: RawUtf8;
    /// <summary>False (layout untouched) for text that is not a desktop document.</summary>
    function FromJson(const AJson: RawUtf8): Boolean;
    function IndexOfGroup(const AId: string): Integer;
    function FindGroup(const AId: string): TRadDeskGroup;
    /// <summary>Group holding the item, or nil.</summary>
    function GroupOfItem(const AItemId: string; out AIndex: Integer): TRadDeskGroup;
    function AddGroup(const ATitle: string; AStyle: TRadDeskGroupStyle = gsBox): TRadDeskGroup;
    /// <summary>Removes and remembers the id so a merge never brings a company group back.</summary>
    procedure DeleteGroup(const AId: string);
    procedure DeleteItem(const AItemId: string);
    /// <summary>Moves an item to AGroup at AIndex (-1: end); False when either is unknown.</summary>
    function MoveItem(const AItemId: string; AGroup: TRadDeskGroup; AIndex: Integer): Boolean;
    /// <summary>Adds company groups and items the user has neither nor removed; takes ABase's version.</summary>
    procedure MergeBase(ABase: TRadDeskLayout);
    property Groups: TRadDeskGroups read FGroups;
    /// <summary>Ids the user removed; consulted by MergeBase.</summary>
    property Removed: TStringList read FRemoved;
    /// <summary>Version of the company layer; the user layer records the one it was merged with.</summary>
    property BaseVersion: Integer read FBaseVersion write FBaseVersion;
  end;

  TRadDeskSpans = TArray<TPoint>;

  TRadDeskPacked = record
    /// <summary>Position of each span in tiles, same order as the input.</summary>
    Cells: TArray<TPoint>;
    /// <summary>Rows of tiles used (at least 1).</summary>
    Rows: Integer;
  end;

  /// <summary>Cell grid arithmetic. Pure functions, no state.</summary>
  TRadDeskGrid = class abstract
  private
    class function PlacementOrder(const ARects: TArray<TRect>; AFixed: Integer): TArray<Integer>; static;
    class function DropBelow(const ARect: TRect; APlaced: TList<TRect>): TRect; static;
  public
    /// <summary>Packs spans (tiles) left to right, top to bottom, first fit, into AColumns tiles.</summary>
    class function Pack(const ASpans: TRadDeskSpans; AColumns: Integer): TRadDeskPacked; static;
    /// <summary>Box width in tiles.</summary>
    class function TileColumns(AGroup: TRadDeskGroup): Integer; static;
    /// <summary>Height in cells: title row + content (only the title when collapsed).</summary>
    class function GroupRows(AGroup: TRadDeskGroup; AContentTileRows: Integer): Integer; static;
    /// <summary>Pushes every group overlapping another one down until none overlap; AFixed stays put.</summary>
    class procedure Resolve(const ARects: TArray<TRect>; AFixed: Integer; out AMoved: TArray<TRect>); static;
    /// <summary>Clamps a rectangle into AColumns cells (left edge first); height is kept.</summary>
    class function Clamp(const ARect: TRect; AColumns: Integer): TRect; static;
  end;

  /// <summary>Keyboard helpers: nearest rectangle in a direction and Turkish-aware type-to-find.</summary>
  TRadDeskNav = class abstract
  public
    /// <summary>Index of the nearest rectangle from ACurrent in ADir, or -1.</summary>
    class function Nearest(const ARects: TArray<TRect>; ACurrent: Integer;
      ADir: TRadDeskDirection): Integer; static;
    /// <summary>Lower case with I/İ/ı/i folded together and '&amp;' removed.</summary>
    class function Fold(const AText: string): string; static;
    /// <summary>First caption after AStart (wrapping) that starts with AText, else one that contains it; -1.</summary>
    class function Find(const ACaptions: TArray<string>; AStart: Integer; const AText: string): Integer; static;
  end;

  /// <summary>Text codes of the enums in JSON.</summary>
  TRadDeskCodes = class abstract
  public
    class function KindCode(AKind: TRadDeskItemKind): RawUtf8; static;
    class function KindOf(const ACode: RawUtf8; out AKind: TRadDeskItemKind): Boolean; static;
    class function StyleCode(AStyle: TRadDeskGroupStyle): RawUtf8; static;
    class function StyleOf(const ACode: RawUtf8): TRadDeskGroupStyle; static;
    class function SizeCode(ASize: TRadDeskSize): RawUtf8; static;
    class function SizeOf(const ACode: RawUtf8): TRadDeskSize; static;
    class function NewId: string; static;
  end;

implementation

uses
  System.Math,
  System.Generics.Defaults,
  mormot.core.unicode,
  mormot.core.json;

const
  CKindCodes: array[TRadDeskItemKind] of RawUtf8 = ('shortcut', 'widget', 'dashboard');
  CStyleCodes: array[TRadDeskGroupStyle] of RawUtf8 = ('box', 'folder');
  CSizeCodes: array[TRadDeskSize] of RawUtf8 = ('small', 'wide', 'large');
  CMaxResolvePasses = 1000;
  /// Secondary axis offset weighs this much more than the primary distance.
  CNavSideWeight = 2;

{ TRadDeskCodes }

class function TRadDeskCodes.KindCode(AKind: TRadDeskItemKind): RawUtf8;
begin
  Result := CKindCodes[AKind];
end;

class function TRadDeskCodes.KindOf(const ACode: RawUtf8; out AKind: TRadDeskItemKind): Boolean;
var
  LKind: TRadDeskItemKind;
begin
  for LKind := Low(TRadDeskItemKind) to High(TRadDeskItemKind) do
    if CKindCodes[LKind] = ACode then
    begin
      AKind := LKind;
      Exit(True);
    end;
  Result := False;
end;

class function TRadDeskCodes.StyleCode(AStyle: TRadDeskGroupStyle): RawUtf8;
begin
  Result := CStyleCodes[AStyle];
end;

class function TRadDeskCodes.StyleOf(const ACode: RawUtf8): TRadDeskGroupStyle;
begin
  if ACode = CStyleCodes[gsFolder] then
    Result := gsFolder
  else
    Result := gsBox;
end;

class function TRadDeskCodes.SizeCode(ASize: TRadDeskSize): RawUtf8;
begin
  Result := CSizeCodes[ASize];
end;

class function TRadDeskCodes.SizeOf(const ACode: RawUtf8): TRadDeskSize;
var
  LSize: TRadDeskSize;
begin
  for LSize := Low(TRadDeskSize) to High(TRadDeskSize) do
    if CSizeCodes[LSize] = ACode then
      Exit(LSize);
  Result := dsSmall;
end;

class function TRadDeskCodes.NewId: string;
begin
  Result := System.SysUtils.LowerCase(TGUID.NewGuid.ToString.Substring(1, 13).Replace('-', ''));
end;

{ TRadDeskItem }

constructor TRadDeskItem.Create(AKind: TRadDeskItemKind; const ATarget: string; const AId: string);
begin
  inherited Create;
  FKind := AKind;
  FTarget := ATarget;
  if AId = '' then
    FId := TRadDeskCodes.NewId
  else
    FId := AId;
end;

function TRadDeskItem.Clone: TRadDeskItem;
begin
  Result := TRadDeskItem.Create(FKind, FTarget, FId);
  Result.FCaption := FCaption;
  Result.FSize := FSize;
  Result.FSettings := FSettings;
end;

function TRadDeskItem.TileSpan: TPoint;
begin
  if FKind = dkShortcut then
    Exit(Point(1, 1));
  case FSize of
    dsWide: Result := Point(2, 1);
    dsLarge: Result := Point(2, 2);
  else
    Result := Point(1, 1);
  end;
end;

{ TRadDeskGroup }

constructor TRadDeskGroup.Create(const ATitle: string; const AId: string);
begin
  inherited Create;
  FItems := TRadDeskItems.Create(True);
  FTitle := ATitle;
  FCols := RAD_DESK_DEFAULT_GROUP_COLS;
  if AId = '' then
    FId := TRadDeskCodes.NewId
  else
    FId := AId;
end;

destructor TRadDeskGroup.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

procedure TRadDeskGroup.SetCols(AValue: Integer);
begin
  if AValue < RAD_DESK_MIN_GROUP_COLS then
    AValue := RAD_DESK_MIN_GROUP_COLS;
  FCols := ((AValue + RAD_DESK_TILE_CELLS - 1) div RAD_DESK_TILE_CELLS) * RAD_DESK_TILE_CELLS;
end;

function TRadDeskGroup.Clone: TRadDeskGroup;
var
  LItem: TRadDeskItem;
begin
  Result := TRadDeskGroup.Create(FTitle, FId);
  Result.FColor := FColor;
  Result.FStyle := FStyle;
  Result.FCol := FCol;
  Result.FRow := FRow;
  Result.FCols := FCols;
  Result.FCollapsed := FCollapsed;
  for LItem in FItems do
    Result.FItems.Add(LItem.Clone);
end;

function TRadDeskGroup.IndexOfItem(const AId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
    if FItems[I].Id = AId then
      Exit(I);
  Result := -1;
end;

function TRadDeskGroup.FindItem(const AId: string): TRadDeskItem;
var
  LIndex: Integer;
begin
  LIndex := IndexOfItem(AId);
  if LIndex < 0 then
    Result := nil
  else
    Result := FItems[LIndex];
end;

{ TRadDeskLayout }

constructor TRadDeskLayout.Create;
begin
  inherited Create;
  FGroups := TRadDeskGroups.Create(True);
  FRemoved := TStringList.Create;
  FRemoved.Sorted := True;
  FRemoved.Duplicates := dupIgnore;
end;

destructor TRadDeskLayout.Destroy;
begin
  FRemoved.Free;
  FGroups.Free;
  inherited Destroy;
end;

procedure TRadDeskLayout.Clear;
begin
  FGroups.Clear;
  FRemoved.Clear;
  FBaseVersion := 0;
end;

procedure TRadDeskLayout.Assign(ASource: TRadDeskLayout);
var
  LGroup: TRadDeskGroup;
begin
  Clear;
  for LGroup in ASource.FGroups do
    FGroups.Add(LGroup.Clone);
  FRemoved.Assign(ASource.FRemoved);
  FBaseVersion := ASource.FBaseVersion;
end;

function TRadDeskLayout.GroupToDoc(AGroup: TRadDeskGroup): Variant;
var
  LItems: TDocVariantData;
  LItem: TRadDeskItem;
begin
  LItems.InitFast(dvArray);
  for LItem in AGroup.Items do
    LItems.AddItem(_ObjFast(['id', LItem.Id, 'kind', TRadDeskCodes.KindCode(LItem.Kind),
      'target', LItem.Target, 'caption', LItem.Caption, 'size', TRadDeskCodes.SizeCode(LItem.Size),
      'settings', LItem.Settings]));
  Result := _ObjFast(['id', AGroup.Id, 'title', AGroup.Title, 'color', Int64(AGroup.Color),
    'style', TRadDeskCodes.StyleCode(AGroup.Style), 'col', AGroup.Col, 'row', AGroup.Row,
    'cols', AGroup.Cols, 'collapsed', AGroup.Collapsed, 'items', Variant(LItems)]);
end;

function TRadDeskLayout.ToJson: RawUtf8;
var
  LDoc, LGroups, LRemoved: TDocVariantData;
  LGroup: TRadDeskGroup;
  I: Integer;
begin
  LGroups.InitFast(dvArray);
  for LGroup in FGroups do
    LGroups.AddItem(GroupToDoc(LGroup));
  LRemoved.InitFast(dvArray);
  for I := 0 to FRemoved.Count - 1 do
    LRemoved.AddItem(FRemoved[I]);
  LDoc.InitFast(dvObject);
  LDoc.AddValue('schema', RAD_DESK_SCHEMA);
  LDoc.AddValue('baseVersion', FBaseVersion);
  LDoc.AddValue('removed', Variant(LRemoved));
  LDoc.AddValue('groups', Variant(LGroups));
  Result := LDoc.ToJson;
end;

function ReadItem(const AObj: PDocVariantData): TRadDeskItem;
var
  LId, LCode, LText: RawUtf8;
  LKind: TRadDeskItemKind;
begin
  Result := nil;
  if not AObj^.GetAsRawUtf8('id', LId) or (LId = '') then
    Exit;
  if not AObj^.GetAsRawUtf8('kind', LCode) or not TRadDeskCodes.KindOf(LCode, LKind) then
    Exit;
  AObj^.GetAsRawUtf8('target', LText);
  Result := TRadDeskItem.Create(LKind, Utf8ToString(LText), Utf8ToString(LId));
  if AObj^.GetAsRawUtf8('caption', LText) then
    Result.Caption := Utf8ToString(LText);
  if AObj^.GetAsRawUtf8('size', LCode) then
    Result.Size := TRadDeskCodes.SizeOf(LCode);
  if AObj^.GetAsRawUtf8('settings', LText) then
    Result.Settings := Utf8ToString(LText);
end;

procedure ReadItems(AGroup: TRadDeskGroup; const AObj: PDocVariantData);
var
  LArr: PDocVariantData;
  LItem: TRadDeskItem;
  I: Integer;
begin
  if not AObj^.GetAsArray('items', LArr) then
    Exit;
  for I := 0 to LArr^.Count - 1 do
  begin
    LItem := ReadItem(_Safe(LArr^.Values[I]));
    if Assigned(LItem) and (AGroup.IndexOfItem(LItem.Id) < 0) then
      AGroup.Items.Add(LItem)
    else
      LItem.Free;
  end;
end;

function ReadGroup(const AObj: PDocVariantData): TRadDeskGroup;
var
  LId, LText: RawUtf8;
  LNum: Int64;
  LInt: Integer;
  LBool: Boolean;
begin
  Result := nil;
  if not AObj^.GetAsRawUtf8('id', LId) or (LId = '') then
    Exit;
  AObj^.GetAsRawUtf8('title', LText);
  Result := TRadDeskGroup.Create(Utf8ToString(LText), Utf8ToString(LId));
  if AObj^.GetAsInt64('color', LNum) then
    Result.Color := Cardinal(LNum);
  if AObj^.GetAsRawUtf8('style', LText) then
    Result.Style := TRadDeskCodes.StyleOf(LText);
  if AObj^.GetAsInteger('col', LInt) then
    Result.Col := System.Math.Max(0, LInt);
  if AObj^.GetAsInteger('row', LInt) then
    Result.Row := System.Math.Max(0, LInt);
  if AObj^.GetAsInteger('cols', LInt) then
    Result.Cols := LInt;
  if AObj^.GetAsBoolean('collapsed', LBool) then
    Result.Collapsed := LBool;
  ReadItems(Result, AObj);
end;

procedure TRadDeskLayout.ReadGroups(const AArr: PDocVariantData);
var
  LGroup: TRadDeskGroup;
  I: Integer;
begin
  for I := 0 to AArr^.Count - 1 do
  begin
    LGroup := ReadGroup(_Safe(AArr^.Values[I]));
    if Assigned(LGroup) and (IndexOfGroup(LGroup.Id) < 0) then
      FGroups.Add(LGroup)
    else
      LGroup.Free;
  end;
end;

function TRadDeskLayout.FromJson(const AJson: RawUtf8): Boolean;
var
  LDoc: TDocVariantData;
  LArr: PDocVariantData;
  LSchema, LVersion, I: Integer;
begin
  Result := IsValidJson(AJson) and LDoc.InitJson(AJson, JSON_FAST) and (LDoc.Kind = dvObject)
    and LDoc.GetAsInteger('schema', LSchema) and (LSchema >= 1) and (LSchema <= RAD_DESK_SCHEMA);
  if not Result then
    Exit;
  Clear;
  if LDoc.GetAsInteger('baseVersion', LVersion) then
    FBaseVersion := LVersion;
  if LDoc.GetAsArray('removed', LArr) then
    for I := 0 to LArr^.Count - 1 do
      FRemoved.Add(VariantToString(LArr^.Values[I]));
  if LDoc.GetAsArray('groups', LArr) then
    ReadGroups(LArr);
end;

function TRadDeskLayout.IndexOfGroup(const AId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FGroups.Count - 1 do
    if FGroups[I].Id = AId then
      Exit(I);
  Result := -1;
end;

function TRadDeskLayout.FindGroup(const AId: string): TRadDeskGroup;
var
  LIndex: Integer;
begin
  LIndex := IndexOfGroup(AId);
  if LIndex < 0 then
    Result := nil
  else
    Result := FGroups[LIndex];
end;

function TRadDeskLayout.GroupOfItem(const AItemId: string; out AIndex: Integer): TRadDeskGroup;
var
  LGroup: TRadDeskGroup;
begin
  for LGroup in FGroups do
  begin
    AIndex := LGroup.IndexOfItem(AItemId);
    if AIndex >= 0 then
      Exit(LGroup);
  end;
  AIndex := -1;
  Result := nil;
end;

function TRadDeskLayout.AddGroup(const ATitle: string; AStyle: TRadDeskGroupStyle): TRadDeskGroup;
begin
  Result := TRadDeskGroup.Create(ATitle);
  Result.Style := AStyle;
  FGroups.Add(Result);
end;

procedure TRadDeskLayout.DeleteGroup(const AId: string);
var
  LIndex: Integer;
  LItem: TRadDeskItem;
begin
  LIndex := IndexOfGroup(AId);
  if LIndex < 0 then
    Exit;
  FRemoved.Add(AId);
  for LItem in FGroups[LIndex].Items do
    FRemoved.Add(LItem.Id);
  FGroups.Delete(LIndex);
end;

procedure TRadDeskLayout.DeleteItem(const AItemId: string);
var
  LGroup: TRadDeskGroup;
  LIndex: Integer;
begin
  LGroup := GroupOfItem(AItemId, LIndex);
  if not Assigned(LGroup) then
    Exit;
  FRemoved.Add(AItemId);
  LGroup.Items.Delete(LIndex);
end;

function TRadDeskLayout.MoveItem(const AItemId: string; AGroup: TRadDeskGroup; AIndex: Integer): Boolean;
var
  LFrom: TRadDeskGroup;
  LIndex: Integer;
  LItem: TRadDeskItem;
begin
  LFrom := GroupOfItem(AItemId, LIndex);
  Result := Assigned(LFrom) and Assigned(AGroup) and (FGroups.IndexOf(AGroup) >= 0);
  if not Result then
    Exit;
  if (LFrom = AGroup) and (AIndex > LIndex) then
    Dec(AIndex);
  LItem := LFrom.Items.Extract(LFrom.Items[LIndex]);
  if (AIndex < 0) or (AIndex > AGroup.Items.Count) then
    AGroup.Items.Add(LItem)
  else
    AGroup.Items.Insert(AIndex, LItem);
end;

procedure TRadDeskLayout.MergeBase(ABase: TRadDeskLayout);
var
  LBase, LOwn: TRadDeskGroup;
  LItem: TRadDeskItem;
  LIndex: Integer;
begin
  for LBase in ABase.Groups do
  begin
    if FRemoved.IndexOf(LBase.Id) >= 0 then
      Continue;
    LOwn := FindGroup(LBase.Id);
    if not Assigned(LOwn) then
    begin
      LOwn := LBase.Clone;
      LOwn.Items.Clear;
      FGroups.Add(LOwn);
    end;
    for LItem in LBase.Items do
      if (FRemoved.IndexOf(LItem.Id) < 0) and not Assigned(GroupOfItem(LItem.Id, LIndex)) then
        LOwn.Items.Add(LItem.Clone);
  end;
  FBaseVersion := ABase.BaseVersion;
end;

{ TRadDeskGrid }

class function TRadDeskGrid.Pack(const ASpans: TRadDeskSpans; AColumns: Integer): TRadDeskPacked;
var
  LUsed: TList<TRect>;
  I: Integer;

  function IsFree(const ARect: TRect): Boolean;
  var
    LRect, LDummy: TRect;
  begin
    for LRect in LUsed do
      if IntersectRect(LDummy, LRect, ARect) then
        Exit(False);
    Result := True;
  end;

  function Place(const ASpan: TPoint): TPoint;
  var
    LRow, LCol: Integer;
  begin
    LRow := 0;
    repeat
      for LCol := 0 to AColumns - ASpan.X do
        if IsFree(Rect(LCol, LRow, LCol + ASpan.X, LRow + ASpan.Y)) then
          Exit(Point(LCol, LRow));
      Inc(LRow);
    until False;
  end;

var
  LSpan, LCell: TPoint;
begin
  AColumns := System.Math.Max(1, AColumns);
  SetLength(Result.Cells, Length(ASpans));
  Result.Rows := 1;
  LUsed := TList<TRect>.Create;
  try
    for I := 0 to High(ASpans) do
    begin
      LSpan := Point(System.Math.Min(System.Math.Max(1, ASpans[I].X), AColumns),
        System.Math.Max(1, ASpans[I].Y));
      LCell := Place(LSpan);
      Result.Cells[I] := LCell;
      LUsed.Add(Rect(LCell.X, LCell.Y, LCell.X + LSpan.X, LCell.Y + LSpan.Y));
      Result.Rows := System.Math.Max(Result.Rows, LCell.Y + LSpan.Y);
    end;
  finally
    LUsed.Free;
  end;
end;

class function TRadDeskGrid.TileColumns(AGroup: TRadDeskGroup): Integer;
begin
  Result := System.Math.Max(1, AGroup.Cols div RAD_DESK_TILE_CELLS);
end;

class function TRadDeskGrid.GroupRows(AGroup: TRadDeskGroup; AContentTileRows: Integer): Integer;
begin
  if AGroup.Style = gsFolder then
    Exit(RAD_DESK_FOLDER_CELLS);
  Result := 1;
  if not AGroup.Collapsed then
    Inc(Result, System.Math.Max(1, AContentTileRows) * RAD_DESK_TILE_CELLS);
end;

class procedure TRadDeskGrid.Resolve(const ARects: TArray<TRect>; AFixed: Integer;
  out AMoved: TArray<TRect>);
var
  LOrder: TArray<Integer>;
  LPlaced: TList<TRect>;
  I: Integer;
begin
  AMoved := Copy(ARects);
  LOrder := PlacementOrder(AMoved, AFixed);
  LPlaced := TList<TRect>.Create;
  try
    for I in LOrder do
    begin
      AMoved[I] := DropBelow(AMoved[I], LPlaced);
      LPlaced.Add(AMoved[I]);
    end;
  finally
    LPlaced.Free;
  end;
end;

class function TRadDeskGrid.PlacementOrder(const ARects: TArray<TRect>; AFixed: Integer): TArray<Integer>;
var
  LList: TList<Integer>;
  I: Integer;
begin
  LList := TList<Integer>.Create;
  try
    for I := 0 to High(ARects) do
      if I <> AFixed then
        LList.Add(I);
    LList.Sort(TComparer<Integer>.Construct(
      function(const A, B: Integer): Integer
      begin
        Result := CompareValue(ARects[A].Top, ARects[B].Top);
        if Result = 0 then
          Result := CompareValue(ARects[A].Left, ARects[B].Left);
        if Result = 0 then
          Result := CompareValue(A, B);
      end));
    if (AFixed >= 0) and (AFixed <= High(ARects)) then
      LList.Insert(0, AFixed);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

class function TRadDeskGrid.DropBelow(const ARect: TRect; APlaced: TList<TRect>): TRect;
var
  LPass: Integer;
  LMoved: Boolean;
  LOther, LDummy: TRect;
begin
  Result := ARect;
  for LPass := 1 to CMaxResolvePasses do
  begin
    LMoved := False;
    for LOther in APlaced do
      if IntersectRect(LDummy, Result, LOther) then
      begin
        Result.Offset(0, LOther.Bottom - Result.Top);
        LMoved := True;
      end;
    if not LMoved then
      Exit;
  end;
  raise ERadDesktop.Create('Grid could not be resolved');
end;

class function TRadDeskGrid.Clamp(const ARect: TRect; AColumns: Integer): TRect;
begin
  Result := ARect;
  if Result.Right > AColumns then
    Result.Offset(AColumns - Result.Right, 0);
  if Result.Left < 0 then
    Result.Offset(-Result.Left, 0);
  if Result.Top < 0 then
    Result.Offset(0, -Result.Top);
end;

{ TRadDeskNav }

procedure NavDistance(const AFrom, ATo: TPoint; ADir: TRadDeskDirection; out AMain, ASide: Integer);
begin
  case ADir of
    ddLeft:  AMain := AFrom.X - ATo.X;
    ddRight: AMain := ATo.X - AFrom.X;
    ddUp:    AMain := AFrom.Y - ATo.Y;
  else
    AMain := ATo.Y - AFrom.Y;
  end;
  if ADir in [ddLeft, ddRight] then
    ASide := Abs(ATo.Y - AFrom.Y)
  else
    ASide := Abs(ATo.X - AFrom.X);
end;

class function TRadDeskNav.Nearest(const ARects: TArray<TRect>; ACurrent: Integer;
  ADir: TRadDeskDirection): Integer;
var
  LFrom: TPoint;
  LMain, LSide, LScore, LBest, LPass, I: Integer;
begin
  Result := -1;
  if (ACurrent < 0) or (ACurrent > High(ARects)) then
    Exit;
  LFrom := ARects[ACurrent].CenterPoint;
  // Pass 0 keeps to a 45 degree cone, so a tile half a row lower is not "below"; pass 1 takes any.
  for LPass := 0 to 1 do
  begin
    LBest := MaxInt;
    for I := 0 to High(ARects) do
    begin
      NavDistance(LFrom, ARects[I].CenterPoint, ADir, LMain, LSide);
      if (I = ACurrent) or (LMain <= 0) or ((LPass = 0) and (LSide > LMain)) then
        Continue;
      LScore := LMain + CNavSideWeight * LSide;
      if LScore < LBest then
      begin
        LBest := LScore;
        Result := I;
      end;
    end;
    if Result >= 0 then
      Exit;
  end;
end;

class function TRadDeskNav.Fold(const AText: string): string;
var
  I: Integer;
begin
  Result := AText.Replace('&', '');
  for I := 1 to Length(Result) do
    case Result[I] of
      'I', #$0130, #$0131: Result[I] := 'i';
    end;
  Result := Result.ToLowerInvariant;
end;

class function TRadDeskNav.Find(const ACaptions: TArray<string>; AStart: Integer; const AText: string): Integer;
var
  LNeedle: string;
  LCount, LPass, I, LIndex: Integer;
begin
  Result := -1;
  LNeedle := Fold(AText);
  LCount := Length(ACaptions);
  if (LNeedle = '') or (LCount = 0) then
    Exit;
  for LPass := 0 to 1 do
    for I := 1 to LCount do
    begin
      LIndex := (System.Math.Max(-1, AStart) + I) mod LCount;
      if (LPass = 0) and Fold(ACaptions[LIndex]).StartsWith(LNeedle) then
        Exit(LIndex);
      if (LPass = 1) and Fold(ACaptions[LIndex]).Contains(LNeedle) then
        Exit(LIndex);
    end;
end;

end.
