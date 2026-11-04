unit rad.desktop.view;

(* TRADDesktopView: the ERP desktop surface (docs/specs/rad.desktop.md). One window that paints
   itself with GDI+: frosted groups on a wallpaper, shortcut and widget tiles, folder panels.
   Geometry is derived from the cell grid of rad.desktop.core on every arrange; nothing is stored
   in pixels. Scene (wallpaper + groups + tiles) is cached; hover, focus and drag are overlays. *)

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.ExtCtrls,
  Vcl.ImgList,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ,
  rad.desktop.core,
  rad.desktop.commands,
  rad.desktop.widgets,
  rad.desktop.paint;

type
  TRadDeskHitKind = (hkNone, hkDesktop, hkGroupTitle, hkGroupBody, hkGroupGrip, hkFolder, hkPanel, hkItem);
  TRadDeskEffects = (deAuto, deFull, deReduced);
  TRadDeskDragMode = (dmNone, dmItem, dmGroup, dmResize);

  TRadDeskHit = record
    Kind: TRadDeskHitKind;
    Group: TRadDeskGroup;
    Item: TRadDeskItem;
    class function None: TRadDeskHit; static;
  end;

  TRadDeskTileView = record
    Item: TRadDeskItem;
    Group: TRadDeskGroup;
    Rect: TRect;
    State: TRadDeskResolve;
    Caption: string;
    ImageIndex: Integer;
    Enabled: Boolean;
    InPanel: Boolean;
  end;

  TRadDeskGroupView = record
    Group: TRadDeskGroup;
    Rect: TRect;
    Cells: TRect;
    TitleRect: TRect;
    GripRect: TRect;
    Accent: Cardinal;
    Count: Integer;
  end;

  TRadDeskItemEvent = procedure(Sender: TObject; AItem: TRadDeskItem) of object;
  TRadDeskExecuteEvent = procedure(Sender: TObject; AItem: TRadDeskItem; var AHandled: Boolean) of object;
  TRadDeskConfirmEvent = procedure(Sender: TObject; const AMessage: string; var AConfirmed: Boolean) of object;
  TRadDeskMenuEvent = procedure(Sender: TObject; const AHit: TRadDeskHit; const AScreenPoint: TPoint;
    var AHandled: Boolean) of object;

  TRADDesktopView = class(TCustomControl)
  private
    FLayout: TRadDeskLayout;
    FCommands: TRadDeskCommands;
    FWidgets: TRadDeskWidgets;
    FImages: TCustomImageList;
    FImageLink: TChangeLink;
    FWallpaper: TPicture;
    FThemeKind: TRadDeskThemeKind;
    FTheme: TRadDeskTheme;
    FCellSize: Integer;
    FLocked: Boolean;
    FEffects: TRadDeskEffects;
    FAllowDashboards: Boolean;
    FCanEditBase: Boolean;
    FGroups: TArray<TRadDeskGroupView>;
    FTiles: TList<TRadDeskTileView>;
    FPanelGroup: TRadDeskGroup;
    FPanelRect: TRect;
    FArranged: Boolean;
    FContentHeight: Integer;
    FScrollY: Integer;
    FWall: TGPBitmap;
    FWallBlur: TGPBitmap;
    FWallValid: Boolean;
    FScene: TBitmap;
    FSceneValid: Boolean;
    FBuffer: TBitmap;
    FHot: TRadDeskHit;
    FFocusId: string;
    FPress: TRadDeskHit;
    FPressPoint: TPoint;
    FPressed: Boolean;
    FDragMode: TRadDeskDragMode;
    FDragPoint: TPoint;
    FDragOffset: TPoint;
    FData: TObjectDictionary<string, TRadDeskWidgetData>;
    FDue: TDictionary<string, Cardinal>;
    FTimer: TTimer;
    FFind: string;
    FFindTick: Cardinal;
    FMenus: TObject;
    FOnExecute: TRadDeskExecuteEvent;
    FOnChange: TNotifyEvent;
    FOnOpenDashboard: TRadDeskItemEvent;
    FOnConfirm: TRadDeskConfirmEvent;
    FOnResetLayout: TNotifyEvent;
    FOnSaveAsBase: TNotifyEvent;
    FOnContextMenu: TRadDeskMenuEvent;
    procedure SetImages(AValue: TCustomImageList);
    procedure SetWallpaper(AValue: TPicture);
    procedure SetThemeKind(AValue: TRadDeskThemeKind);
    procedure SetCellSize(AValue: Integer);
    procedure SetEffects(AValue: TRadDeskEffects);
    procedure SetCommands(AValue: TRadDeskCommands);
    procedure SetWidgets(AValue: TRadDeskWidgets);
    procedure ImagesChanged(Sender: TObject);
    procedure WallpaperChanged(Sender: TObject);
    procedure TimerTick(Sender: TObject);
    function Px(AValue: Integer): Integer;
    function Cell: Integer;
    function GridColumns: Integer;
    function GroupPixelRect(const ACells: TRect): TRect;
    function TileSlot(const AContent: TRect; ATileCols, ATileRows: Integer): TSize;
    procedure Arrange;
    procedure ArrangeGroup(AGroup: TRadDeskGroup; out AView: TRadDeskGroupView; AIndex: Integer);
    procedure ArrangePanel;
    function VisibleTiles(AGroup: TRadDeskGroup; AInPanel: Boolean): TList<TRadDeskTileView>;
    procedure PlaceTiles(ATiles: TList<TRadDeskTileView>; const AContent: TRect; ATileCols: Integer);
    procedure NeedArranged;
    function GetTiles: TList<TRadDeskTileView>;
    function GetGroupViews: TArray<TRadDeskGroupView>;
    function GetPanelRect: TRect;
    procedure BuildWall;
    procedure DrawWallpaperPicture(G: TGPGraphics);
    procedure BuildScene;
    procedure PaintGroup(G: TGPGraphics; const AView: TRadDeskGroupView);
    procedure PaintFolder(G: TGPGraphics; const AView: TRadDeskGroupView);
    procedure PaintPanel(G: TGPGraphics);
    procedure PaintTile(G: TGPGraphics; const ATile: TRadDeskTileView);
    procedure PaintShortcut(G: TGPGraphics; const ATile: TRadDeskTileView; AAccent: Cardinal);
    procedure PaintWidget(G: TGPGraphics; const ATile: TRadDeskTileView; AAccent: Cardinal);
    procedure PaintWidgetText(G: TGPGraphics; LData: TRadDeskWidgetData; const ARect: TGPRectF);
    procedure PaintWidgetLine(G: TGPGraphics; const ALine: string; const ARect: TGPRectF);
    procedure PaintWidgetChart(G: TGPGraphics; LData: TRadDeskWidgetData; const ARect: TGPRectF; AAccent: Cardinal);
    procedure PaintDashboard(G: TGPGraphics; const ATile: TRadDeskTileView; AAccent: Cardinal);
    procedure PaintIcons;
    procedure PaintEmptyHint(G: TGPGraphics);
    procedure PaintOverlay(G: TGPGraphics);
    procedure PaintDragGhost(G: TGPGraphics);
    procedure PaintScrollHint(G: TGPGraphics);
    function TileIconRect(const ATile: TRadDeskTileView): TRect;
    function AccentOf(AGroup: TRadDeskGroup): Cardinal;
    function GroupViewOf(AGroup: TRadDeskGroup; out AView: TRadDeskGroupView): Boolean;
    function TileIndexOf(const AItemId: string): Integer;
    function ResolveItem(AItem: TRadDeskItem; out AInfo: TRadDeskCommandInfo): TRadDeskResolve;
    function WidgetData(AItem: TRadDeskItem): TRadDeskWidgetData;
    procedure RefreshWidgets(AForce: Boolean);
    procedure SyncTimer;
    procedure SetHot(const AHit: TRadDeskHit);
    procedure StartDrag;
    procedure DropItem(const APoint: TPoint);
    procedure DropGroup(const APoint: TPoint);
    procedure DropResize(const APoint: TPoint);
    function DropIndex(AGroup: TRadDeskGroup; const APoint: TPoint): Integer;
    procedure ClickHit(const AHit: TRadDeskHit);
    procedure MoveFocus(ADir: TRadDeskDirection);
    procedure FindByText(AChar: Char);
    procedure ScrollBy(ADelta: Integer);
    procedure ShowContextMenu(const AHit: TRadDeskHit; const AScreen: TPoint);
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure CMFontChanged(var Message: TMessage); message CM_FONTCHANGED;
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DblClick; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(var Key: Char); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure DoContextPopup(MousePos: TPoint; var Handled: Boolean); override;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure ChangeScale(M, D: Integer; isDpiChange: Boolean); override;
    procedure DoEnter; override;
    procedure DoExit; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Re-arranges and repaints after the layout was changed in code; raises OnChange.</summary>
    procedure Changed;
    /// <summary>Re-arranges and repaints without raising OnChange (data or permission changed).</summary>
    procedure Rebuild;
    function HitTest(const APoint: TPoint): TRadDeskHit;
    /// <summary>Grid cell under a client point (scroll included).</summary>
    function CellAt(const APoint: TPoint): TPoint;
    function ReducedEffects: Boolean;
    procedure OpenFolder(AGroup: TRadDeskGroup);
    procedure CloseFolder;
    /// <summary>Runs a shortcut through Commands, a dashboard through OnOpenDashboard.</summary>
    function ExecuteItem(AItem: TRadDeskItem): Boolean;
    function NewGroup(const ATitle: string; AStyle: TRadDeskGroupStyle; const ACell: TPoint): TRadDeskGroup;
    procedure AddShortcuts(AGroup: TRadDeskGroup; const AIds: TArray<string>);
    function AddWidget(AGroup: TRadDeskGroup; const AProviderId: string): TRadDeskItem;
    function AddDashboard(AGroup: TRadDeskGroup; const AName: string): TRadDeskItem;
    procedure ToggleCollapsed(AGroup: TRadDeskGroup);
    /// <summary>Asks through OnConfirm (or a message box), then removes.</summary>
    function RemoveGroup(AGroup: TRadDeskGroup): Boolean;
    function RemoveItem(AItem: TRadDeskItem): Boolean;
    function Confirm(const AMessage: string): Boolean;
    /// <summary>Fetches every widget now.</summary>
    procedure RefreshAllWidgets;
    /// <summary>Writes what is on screen (scene and overlays) as PNG.</summary>
    procedure SaveSnapshot(const AFileName: string);
    procedure DoResetLayout;
    procedure DoSaveAsBase;
    function FocusedItem: TRadDeskItem;
    procedure FocusItem(const AItemId: string);
    property Layout: TRadDeskLayout read FLayout;
    property Commands: TRadDeskCommands read FCommands write SetCommands;
    property Widgets: TRadDeskWidgets read FWidgets write SetWidgets;
    property Theme: TRadDeskTheme read FTheme;
    /// <summary>Arranged tiles of this frame (arranges first when needed).</summary>
    property Tiles: TList<TRadDeskTileView> read GetTiles;
    property GroupViews: TArray<TRadDeskGroupView> read GetGroupViews;
    property PanelGroup: TRadDeskGroup read FPanelGroup;
    property PanelRect: TRect read GetPanelRect;
    property DragMode: TRadDeskDragMode read FDragMode;
    property ScrollY: Integer read FScrollY;
  published
    property Align;
    property Anchors;
    property Constraints;
    property Font;
    property ParentFont;
    property TabOrder;
    property TabStop default True;
    property Visible;
    property Images: TCustomImageList read FImages write SetImages;
    property Wallpaper: TPicture read FWallpaper write SetWallpaper;
    property ThemeKind: TRadDeskThemeKind read FThemeKind write SetThemeKind default tkDark;
    /// <summary>Grid cell in 96-DPI pixels; a tile is two cells.</summary>
    property CellSize: Integer read FCellSize write SetCellSize default 48;
    /// <summary>No drag, no edit menu: the layout cannot change.</summary>
    property Locked: Boolean read FLocked write FLocked default False;
    /// <summary>deAuto reduces blur and refresh rates in a remote desktop session.</summary>
    property Effects: TRadDeskEffects read FEffects write SetEffects default deAuto;
    property AllowDashboards: Boolean read FAllowDashboards write FAllowDashboards default True;
    /// <summary>Shows "Save as company default" in the desktop menu.</summary>
    property CanEditBase: Boolean read FCanEditBase write FCanEditBase default False;
    property OnExecute: TRadDeskExecuteEvent read FOnExecute write FOnExecute;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnOpenDashboard: TRadDeskItemEvent read FOnOpenDashboard write FOnOpenDashboard;
    property OnConfirm: TRadDeskConfirmEvent read FOnConfirm write FOnConfirm;
    property OnResetLayout: TNotifyEvent read FOnResetLayout write FOnResetLayout;
    property OnSaveAsBase: TNotifyEvent read FOnSaveAsBase write FOnSaveAsBase;
    /// <summary>Set AHandled to replace the built-in menus.</summary>
    property OnContextMenu: TRadDeskMenuEvent read FOnContextMenu write FOnContextMenu;
  end;

implementation

uses
  System.Math,
  System.StrUtils,
  System.UITypes,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.Imaging.pngimage,
  rad.desktop.dialogs;

const
  CMargin = 20;
  CGap = 12;
  CPad = 6;
  CRadius = 14;
  CTileRadius = 10;
  CShadow = 18;
  CBlurFactor = 14;
  CReducedMinInterval = 5000;
  CTimerInterval = 1000;
  CFindResetMs = 1000;
  CTitleFont = 13;
  CCaptionFont = 12;
  CValueFont = 26;
  CSmallFont = 11;
  CMonogram = 38;
  CScrollStep = 60;
  CHintEmptyDesktop = 'Masaüstü boş. Sağ tıklayıp bir grup ekleyin.';
  CHintEmptyGroup = 'Sağ tıklayıp kısayol ekleyin ya da buraya sürükleyin.';
  CNewGroupTitle = 'Yeni grup';

{ TRadDeskHit }

class function TRadDeskHit.None: TRadDeskHit;
begin
  Result := Default(TRadDeskHit);
end;

function SameHit(const A, B: TRadDeskHit): Boolean;
begin
  Result := (A.Kind = B.Kind) and (A.Group = B.Group) and (A.Item = B.Item);
end;

function MissingCaption(const ATarget: string): string;
var
  LPrefix: string;
begin
  if not TRadDeskCommands.SplitId(ATarget, LPrefix, Result) then
    Result := ATarget;
end;

{ TRADDesktopView }

constructor TRADDesktopView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csCaptureMouse, csClickEvents, csDoubleClicks]
    - [csAcceptsControls];
  TabStop := True;
  Width := 640;
  Height := 400;
  FLayout := TRadDeskLayout.Create;
  FTiles := TList<TRadDeskTileView>.Create;
  FScene := TBitmap.Create;
  FScene.PixelFormat := pf32bit;
  FBuffer := TBitmap.Create;
  FBuffer.PixelFormat := pf32bit;
  FWallpaper := TPicture.Create;
  FWallpaper.OnChange := WallpaperChanged;
  FImageLink := TChangeLink.Create;
  FImageLink.OnChange := ImagesChanged;
  FData := TObjectDictionary<string, TRadDeskWidgetData>.Create([doOwnsValues]);
  FDue := TDictionary<string, Cardinal>.Create;
  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := CTimerInterval;
  FTimer.OnTimer := TimerTick;
  FCellSize := 48;
  FAllowDashboards := True;
  FThemeKind := tkDark;
  FTheme := TRadDeskTheme.ForKind(FThemeKind);
  Font.Name := 'Segoe UI';
end;

destructor TRADDesktopView.Destroy;
begin
  FTimer.Enabled := False;
  FMenus.Free;
  FImageLink.Free;
  FWall.Free;
  FWallBlur.Free;
  FData.Free;
  FDue.Free;
  FWallpaper.Free;
  FBuffer.Free;
  FScene.Free;
  FTiles.Free;
  FLayout.Free;
  inherited Destroy;
end;

procedure TRADDesktopView.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FImages) then
  begin
    FImages := nil;
    Rebuild;
  end;
end;

procedure TRADDesktopView.SetImages(AValue: TCustomImageList);
begin
  if FImages = AValue then
    Exit;
  if Assigned(FImages) then
  begin
    FImages.UnRegisterChanges(FImageLink);
    FImages.RemoveFreeNotification(Self);
  end;
  FImages := AValue;
  if Assigned(FImages) then
  begin
    FImages.RegisterChanges(FImageLink);
    FImages.FreeNotification(Self);
  end;
  Rebuild;
end;

procedure TRADDesktopView.SetWallpaper(AValue: TPicture);
begin
  FWallpaper.Assign(AValue);
end;

procedure TRADDesktopView.SetThemeKind(AValue: TRadDeskThemeKind);
begin
  if FThemeKind = AValue then
    Exit;
  FThemeKind := AValue;
  FTheme := TRadDeskTheme.ForKind(AValue);
  FWallValid := False;
  Rebuild;
end;

procedure TRADDesktopView.SetCellSize(AValue: Integer);
begin
  AValue := EnsureRange(AValue, 24, 96);
  if FCellSize = AValue then
    Exit;
  FCellSize := AValue;
  Rebuild;
end;

procedure TRADDesktopView.SetEffects(AValue: TRadDeskEffects);
begin
  if FEffects = AValue then
    Exit;
  FEffects := AValue;
  FWallValid := False;
  Rebuild;
end;

procedure TRADDesktopView.SetCommands(AValue: TRadDeskCommands);
begin
  FCommands := AValue;
  Rebuild;
end;

procedure TRADDesktopView.SetWidgets(AValue: TRadDeskWidgets);
begin
  FWidgets := AValue;
  FData.Clear;
  FDue.Clear;
  Rebuild;
end;

procedure TRADDesktopView.ImagesChanged(Sender: TObject);
begin
  Rebuild;
end;

procedure TRADDesktopView.WallpaperChanged(Sender: TObject);
begin
  FWallValid := False;
  Rebuild;
end;

procedure TRADDesktopView.CMFontChanged(var Message: TMessage);
begin
  inherited;
  Rebuild;
end;

procedure TRADDesktopView.ChangeScale(M, D: Integer; isDpiChange: Boolean);
begin
  inherited ChangeScale(M, D, isDpiChange);
  FWallValid := False;
  Rebuild;
end;

function TRADDesktopView.Px(AValue: Integer): Integer;
begin
  Result := MulDiv(AValue, CurrentPPI, Screen.DefaultPixelsPerInch);
end;

function TRADDesktopView.Cell: Integer;
begin
  Result := Max(8, Px(FCellSize));
end;

function TRADDesktopView.GridColumns: Integer;
begin
  Result := Max(RAD_DESK_MIN_GROUP_COLS, (ClientWidth - 2 * Px(CMargin)) div Cell);
end;

function TRADDesktopView.ReducedEffects: Boolean;
begin
  Result := (FEffects = deReduced) or ((FEffects = deAuto) and (GetSystemMetrics(SM_REMOTESESSION) <> 0));
end;

procedure TRADDesktopView.Changed;
begin
  Rebuild;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TRADDesktopView.Rebuild;
begin
  FArranged := False;
  FSceneValid := False;
  if HandleAllocated then
    Invalidate;
  SyncTimer;
end;

function TRADDesktopView.GetTiles: TList<TRadDeskTileView>;
begin
  NeedArranged;
  Result := FTiles;
end;

function TRADDesktopView.GetGroupViews: TArray<TRadDeskGroupView>;
begin
  NeedArranged;
  Result := FGroups;
end;

function TRADDesktopView.GetPanelRect: TRect;
begin
  NeedArranged;
  Result := FPanelRect;
end;

procedure TRADDesktopView.NeedArranged;
begin
  if not FArranged then
    Arrange;
end;

procedure TRADDesktopView.Resize;
begin
  inherited Resize;
  FWallValid := False;
  Rebuild;
end;

{ --- resolve and data --- }

function TRADDesktopView.ResolveItem(AItem: TRadDeskItem; out AInfo: TRadDeskCommandInfo): TRadDeskResolve;
var
  LProvider: IRadDeskWidgetProvider;
begin
  AInfo := TRadDeskCommandInfo.Make(AItem.Target, AItem.Caption, '');
  case AItem.Kind of
    dkShortcut:
      if Assigned(FCommands) then
        Result := FCommands.Resolve(AItem.Target, AInfo)
      else
        Result := crMissing;
    dkWidget:
      begin
        LProvider := nil;
        if Assigned(FWidgets) then
          LProvider := FWidgets.Find(AItem.Target);
        if Assigned(LProvider) then
        begin
          AInfo.Caption := LProvider.Caption;
          Result := crOk;
        end
        else
          Result := crMissing;
      end;
  else
    if FAllowDashboards then
      Result := crOk
    else
      Result := crHidden;
  end;
  if AItem.Caption <> '' then
    AInfo.Caption := AItem.Caption;
  if AInfo.Caption = '' then
    AInfo.Caption := MissingCaption(AItem.Target);
end;

function TRADDesktopView.WidgetData(AItem: TRadDeskItem): TRadDeskWidgetData;
begin
  if not FData.TryGetValue(AItem.Id, Result) then
  begin
    Result := TRadDeskWidgetData.Create;
    FData.Add(AItem.Id, Result);
  end;
end;

procedure TRADDesktopView.RefreshWidgets(AForce: Boolean);
var
  LGroup: TRadDeskGroup;
  LItem: TRadDeskItem;
  LProvider: IRadDeskWidgetProvider;
  LNow, LDue: Cardinal;
  LInterval: Integer;
  LAny: Boolean;
  LBefore: string;
begin
  if not Assigned(FWidgets) then
    Exit;
  LNow := GetTickCount;
  LAny := False;
  for LGroup in FLayout.Groups do
    for LItem in LGroup.Items do
    begin
      if LItem.Kind <> dkWidget then
        Continue;
      LProvider := FWidgets.Find(LItem.Target);
      if not Assigned(LProvider) then
        Continue;
      if not AForce and FDue.TryGetValue(LItem.Id, LDue) and (Integer(LDue - LNow) > 0) then
        Continue;
      LBefore := WidgetData(LItem).Signature;
      TRadDeskWidgets.SafeFetch(LProvider, LItem.Settings, WidgetData(LItem));
      LAny := LAny or (WidgetData(LItem).Signature <> LBefore);
      LInterval := LProvider.Interval;
      if (LInterval > 0) and ReducedEffects then
        LInterval := Max(LInterval, CReducedMinInterval);
      if LInterval <= 0 then
        FDue.AddOrSetValue(LItem.Id, LNow + Cardinal(MaxInt))
      else
        FDue.AddOrSetValue(LItem.Id, LNow + Cardinal(LInterval));
    end;
  if LAny then
  begin
    FSceneValid := False;
    Invalidate;
  end;
end;

procedure TRADDesktopView.RefreshAllWidgets;
begin
  RefreshWidgets(True);
end;

procedure TRADDesktopView.SyncTimer;
var
  LGroup: TRadDeskGroup;
  LItem: TRadDeskItem;
  LHas: Boolean;
begin
  LHas := False;
  if Assigned(FWidgets) then
    for LGroup in FLayout.Groups do
      for LItem in LGroup.Items do
        LHas := LHas or (LItem.Kind = dkWidget);
  FTimer.Enabled := LHas and not (csDesigning in ComponentState);
end;

procedure TRADDesktopView.TimerTick(Sender: TObject);
begin
  RefreshWidgets(False);
end;

{ --- arrange --- }

function TRADDesktopView.GroupPixelRect(const ACells: TRect): TRect;
var
  LHalf: Integer;
begin
  LHalf := Px(CGap) div 2;
  Result := Rect(Px(CMargin) + ACells.Left * Cell + LHalf, Px(CMargin) + ACells.Top * Cell + LHalf - FScrollY,
    Px(CMargin) + ACells.Right * Cell - LHalf, Px(CMargin) + ACells.Bottom * Cell - LHalf - FScrollY);
end;

function TRADDesktopView.TileSlot(const AContent: TRect; ATileCols, ATileRows: Integer): TSize;
begin
  Result.cx := Max(1, AContent.Width div Max(1, ATileCols));
  Result.cy := Max(1, Min(AContent.Height div Max(1, ATileRows), Cell * RAD_DESK_TILE_CELLS));
end;

function TRADDesktopView.VisibleTiles(AGroup: TRadDeskGroup; AInPanel: Boolean): TList<TRadDeskTileView>;
var
  LItem: TRadDeskItem;
  LTile: TRadDeskTileView;
  LInfo: TRadDeskCommandInfo;
begin
  Result := TList<TRadDeskTileView>.Create;
  for LItem in AGroup.Items do
  begin
    LTile := Default(TRadDeskTileView);
    LTile.Item := LItem;
    LTile.Group := AGroup;
    LTile.InPanel := AInPanel;
    LTile.State := ResolveItem(LItem, LInfo);
    if LTile.State in [crDenied, crHidden] then
      Continue;
    LTile.Caption := LInfo.Caption;
    LTile.ImageIndex := LInfo.ImageIndex;
    LTile.Enabled := (LTile.State = crOk) and LInfo.Enabled;
    Result.Add(LTile);
  end;
end;

procedure TRADDesktopView.PlaceTiles(ATiles: TList<TRadDeskTileView>; const AContent: TRect; ATileCols: Integer);
var
  LSpans: TRadDeskSpans;
  LPacked: TRadDeskPacked;
  LSlot: TSize;
  LTile: TRadDeskTileView;
  LSpan: TPoint;
  I, LInset: Integer;
begin
  SetLength(LSpans, ATiles.Count);
  for I := 0 to ATiles.Count - 1 do
    LSpans[I] := ATiles[I].Item.TileSpan;
  LPacked := TRadDeskGrid.Pack(LSpans, ATileCols);
  LSlot := TileSlot(AContent, ATileCols, LPacked.Rows);
  LInset := Px(2);
  for I := 0 to ATiles.Count - 1 do
  begin
    LTile := ATiles[I];
    LSpan := Point(Min(LSpans[I].X, ATileCols), LSpans[I].Y);
    LTile.Rect := Rect(AContent.Left + LPacked.Cells[I].X * LSlot.cx, AContent.Top + LPacked.Cells[I].Y * LSlot.cy,
      AContent.Left + (LPacked.Cells[I].X + LSpan.X) * LSlot.cx, AContent.Top + (LPacked.Cells[I].Y + LSpan.Y) * LSlot.cy);
    LTile.Rect.Inflate(-LInset, -LInset);
    FTiles.Add(LTile);
  end;
end;

procedure TRADDesktopView.ArrangeGroup(AGroup: TRadDeskGroup; out AView: TRadDeskGroupView; AIndex: Integer);
var
  LTiles: TList<TRadDeskTileView>;
  LSpans: TRadDeskSpans;
  LTileCols, LRows, I: Integer;
begin
  AView := Default(TRadDeskGroupView);
  AView.Group := AGroup;
  AView.Accent := FTheme.Accent(AGroup.Color, AIndex);
  LTiles := VisibleTiles(AGroup, False);
  try
    AView.Count := LTiles.Count;
    LTileCols := TRadDeskGrid.TileColumns(AGroup);
    SetLength(LSpans, LTiles.Count);
    for I := 0 to LTiles.Count - 1 do
      LSpans[I] := LTiles[I].Item.TileSpan;
    LRows := TRadDeskGrid.GroupRows(AGroup, TRadDeskGrid.Pack(LSpans, LTileCols).Rows);
    if AGroup.Style = gsFolder then
      AView.Cells := Rect(AGroup.Col, AGroup.Row, AGroup.Col + RAD_DESK_FOLDER_CELLS, AGroup.Row + LRows)
    else
      AView.Cells := Rect(AGroup.Col, AGroup.Row, AGroup.Col + AGroup.Cols, AGroup.Row + LRows);
  finally
    LTiles.Free;
  end;
end;

procedure TRADDesktopView.ArrangePanel;
var
  LView: TRadDeskGroupView;
  LTiles: TList<TRadDeskTileView>;
  LSpans: TRadDeskSpans;
  LTileSize, W, H, I: Integer;
  LContent: TRect;
begin
  FPanelRect := TRect.Empty;
  if not Assigned(FPanelGroup) or not GroupViewOf(FPanelGroup, LView) then
    Exit;
  LTiles := VisibleTiles(FPanelGroup, True);
  try
    SetLength(LSpans, LTiles.Count);
    for I := 0 to LTiles.Count - 1 do
      LSpans[I] := LTiles[I].Item.TileSpan;
    LTileSize := Cell * RAD_DESK_TILE_CELLS;
    W := RAD_DESK_FOLDER_PANEL_TILES * LTileSize + 2 * Px(CPad);
    H := Cell + TRadDeskGrid.Pack(LSpans, RAD_DESK_FOLDER_PANEL_TILES).Rows * LTileSize + Px(CPad);
    FPanelRect := Bounds(LView.Rect.Right + Px(CGap), LView.Rect.Top, W, H);
    if FPanelRect.Right > ClientWidth - Px(CPad) then
      FPanelRect.Offset(LView.Rect.Left - Px(CGap) - W - FPanelRect.Left, 0);
    if FPanelRect.Bottom > ClientHeight - Px(CPad) then
      FPanelRect.Offset(0, Max(Px(CPad) - FPanelRect.Top, ClientHeight - Px(CPad) - FPanelRect.Bottom));
    LContent := Rect(FPanelRect.Left + Px(CPad), FPanelRect.Top + Cell, FPanelRect.Right - Px(CPad),
      FPanelRect.Bottom - Px(CPad));
    PlaceTiles(LTiles, LContent, RAD_DESK_FOLDER_PANEL_TILES);
  finally
    LTiles.Free;
  end;
end;

procedure TRADDesktopView.Arrange;
var
  LCells, LResolved: TArray<TRect>;
  LTiles: TList<TRadDeskTileView>;
  LContent: TRect;
  I: Integer;
begin
  FTiles.Clear;
  SetLength(FGroups, FLayout.Groups.Count);
  SetLength(LCells, FLayout.Groups.Count);
  for I := 0 to FLayout.Groups.Count - 1 do
  begin
    ArrangeGroup(FLayout.Groups[I], FGroups[I], I);
    LCells[I] := TRadDeskGrid.Clamp(FGroups[I].Cells, GridColumns);
  end;
  TRadDeskGrid.Resolve(LCells, -1, LResolved);
  FContentHeight := 0;
  for I := 0 to High(FGroups) do
  begin
    FGroups[I].Cells := LResolved[I];
    FGroups[I].Rect := GroupPixelRect(LResolved[I]);
    FGroups[I].TitleRect := Rect(FGroups[I].Rect.Left, FGroups[I].Rect.Top, FGroups[I].Rect.Right,
      FGroups[I].Rect.Top + Cell - Px(CGap) div 2);
    FGroups[I].GripRect := Rect(FGroups[I].Rect.Right - Px(16), FGroups[I].Rect.Bottom - Px(16),
      FGroups[I].Rect.Right, FGroups[I].Rect.Bottom);
    FContentHeight := Max(FContentHeight, FGroups[I].Rect.Bottom + FScrollY + Px(CMargin));
    if (FGroups[I].Group.Style = gsFolder) or FGroups[I].Group.Collapsed then
      Continue;
    LTiles := VisibleTiles(FGroups[I].Group, False);
    try
      LContent := Rect(FGroups[I].Rect.Left + Px(CPad), FGroups[I].TitleRect.Bottom,
        FGroups[I].Rect.Right - Px(CPad), FGroups[I].Rect.Bottom - Px(CPad));
      PlaceTiles(LTiles, LContent, TRadDeskGrid.TileColumns(FGroups[I].Group));
    finally
      LTiles.Free;
    end;
  end;
  if Assigned(FPanelGroup) and (FLayout.Groups.IndexOf(FPanelGroup) < 0) then
    FPanelGroup := nil;
  ArrangePanel;
  FArranged := True;
end;

function TRADDesktopView.GroupViewOf(AGroup: TRadDeskGroup; out AView: TRadDeskGroupView): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(FGroups) do
    if FGroups[I].Group = AGroup then
    begin
      AView := FGroups[I];
      Exit(True);
    end;
  Result := False;
end;

function TRADDesktopView.TileIndexOf(const AItemId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FTiles.Count - 1 do
    if FTiles[I].Item.Id = AItemId then
      Exit(I);
  Result := -1;
end;

function TRADDesktopView.AccentOf(AGroup: TRadDeskGroup): Cardinal;
var
  LView: TRadDeskGroupView;
begin
  if GroupViewOf(AGroup, LView) then
    Result := LView.Accent
  else
    Result := FTheme.Accent(AGroup.Color, 0);
end;

{ --- painting --- }

procedure TRADDesktopView.DrawWallpaperPicture(G: TGPGraphics);
var
  LBmp: TBitmap;
  LPic: TGPBitmap;
begin
  // TPicture.Bitmap would replace a JPEG/PNG with an empty bitmap: draw the graphic into our own.
  LBmp := TBitmap.Create;
  try
    LBmp.PixelFormat := pf24bit;
    LBmp.SetSize(FWallpaper.Graphic.Width, FWallpaper.Graphic.Height);
    LBmp.Canvas.Draw(0, 0, FWallpaper.Graphic);
    LPic := TGPBitmap.Create(LBmp.Handle, 0);
    try
      G.SetInterpolationMode(InterpolationModeHighQualityBicubic);
      G.DrawImage(LPic, 0, 0, ClientWidth, ClientHeight);
    finally
      LPic.Free;
    end;
  finally
    LBmp.Free;
  end;
end;

procedure TRADDesktopView.BuildWall;
var
  G: TGPGraphics;
begin
  FreeAndNil(FWall);
  FreeAndNil(FWallBlur);
  FWall := TGPBitmap.Create(Max(1, ClientWidth), Max(1, ClientHeight), PixelFormat32bppARGB);
  G := TGPGraphics.Create(FWall);
  try
    TRadDeskDraw.Prepare(G);
    if Assigned(FWallpaper.Graphic) and not FWallpaper.Graphic.Empty then
      DrawWallpaperPicture(G)
    else
      TRadDeskDraw.Wallpaper(G, MakeRect(0.0, 0, ClientWidth, ClientHeight), FTheme);
  finally
    G.Free;
  end;
  if not ReducedEffects then
    FWallBlur := TRadDeskDraw.Blurred(FWall, Px(CBlurFactor));
  FWallValid := True;
end;

procedure TRADDesktopView.BuildScene;
var
  G: TGPGraphics;
  I: Integer;
begin
  NeedArranged;
  if not FWallValid then
    BuildWall;
  FScene.SetSize(Max(1, ClientWidth), Max(1, ClientHeight));
  G := TGPGraphics.Create(FScene.Canvas.Handle);
  try
    G.DrawImage(FWall, 0, 0);
    TRadDeskDraw.Prepare(G);
    for I := 0 to High(FGroups) do
      if FGroups[I].Group.Style = gsFolder then
        PaintFolder(G, FGroups[I])
      else
        PaintGroup(G, FGroups[I]);
    for I := 0 to FTiles.Count - 1 do
      if not FTiles[I].InPanel then
        PaintTile(G, FTiles[I]);
    if Assigned(FPanelGroup) then
      PaintPanel(G);
    if Length(FGroups) = 0 then
      PaintEmptyHint(G);
  finally
    G.Free;
  end;
  PaintIcons;
  FSceneValid := True;
end;

procedure TRADDesktopView.PaintGroup(G: TGPGraphics; const AView: TRadDeskGroupView);
var
  R, LTitle: TGPRectF;
  LText: string;
  LBar: TGPRectF;
  LContent: TRect;
begin
  R := TRadDeskDraw.RectF(AView.Rect);
  if not ReducedEffects then
    TRadDeskDraw.Shadow(G, R, Px(CRadius), Px(CShadow), FTheme.Shadow);
  if ReducedEffects then
    TRadDeskDraw.FillRound(G, R, Px(CRadius), TRadDeskDraw.WithAlpha(FTheme.WallBottom, 235))
  else
    TRadDeskDraw.Glass(G, FWallBlur, R, Px(CRadius), FTheme, FTheme.GlassTint);
  LBar := MakeRect(R.X + Px(12), R.Y + (AView.TitleRect.Height - Px(14)) / 2, Px(4), Px(14));
  TRadDeskDraw.FillRound(G, LBar, Px(2), AView.Accent);
  LTitle := MakeRect(R.X + Px(24), R.Y, R.Width - Px(64), AView.TitleRect.Height);
  TRadDeskDraw.Text(G, AView.Group.Title, Font.Name, Px(CTitleFont), FontStyleBold, LTitle, FTheme.Title,
    StringAlignmentNear, StringAlignmentCenter, False);
  LText := IntToStr(AView.Count);
  if AView.Group.Collapsed then
    LText := LText + '  ▸'
  else
    LText := LText + '  ▾';
  TRadDeskDraw.Text(G, LText, Font.Name, Px(CSmallFont), FontStyleRegular,
    MakeRect(R.X + R.Width - Px(60), R.Y, Px(48), AView.TitleRect.Height), FTheme.SubText,
    StringAlignmentFar, StringAlignmentCenter, False);
  if (AView.Count = 0) and not AView.Group.Collapsed then
  begin
    LContent := Rect(AView.Rect.Left + Px(CPad), AView.TitleRect.Bottom, AView.Rect.Right - Px(CPad),
      AView.Rect.Bottom - Px(CPad));
    TRadDeskDraw.Text(G, CHintEmptyGroup, Font.Name, Px(CSmallFont), FontStyleRegular,
      TRadDeskDraw.RectF(LContent), FTheme.SubText, StringAlignmentCenter, StringAlignmentCenter, True);
  end;
end;

procedure TRADDesktopView.PaintFolder(G: TGPGraphics; const AView: TRadDeskGroupView);
var
  R, LIcon: TGPRectF;
  S: Single;
  LOpen: Boolean;
begin
  R := TRadDeskDraw.RectF(AView.Rect);
  LOpen := AView.Group = FPanelGroup;
  if not ReducedEffects then
    TRadDeskDraw.Shadow(G, R, Px(CRadius), Px(CShadow) / 2, FTheme.Shadow);
  if ReducedEffects then
    TRadDeskDraw.FillRound(G, R, Px(CRadius), TRadDeskDraw.WithAlpha(FTheme.WallBottom, 235))
  else if LOpen then
    TRadDeskDraw.Glass(G, FWallBlur, R, Px(CRadius), FTheme, TRadDeskDraw.WithAlpha(AView.Accent, 90))
  else
    TRadDeskDraw.Glass(G, FWallBlur, R, Px(CRadius), FTheme, FTheme.GlassTint);
  if ReducedEffects and LOpen then
    TRadDeskDraw.StrokeRound(G, R, Px(CRadius), Px(2), AView.Accent);
  S := Min(R.Width, R.Height) * 0.46;
  LIcon := MakeRect(R.X + (R.Width - S) / 2, R.Y + R.Height * 0.14, S, S * 0.86);
  TRadDeskDraw.Folder(G, LIcon, AView.Accent);
  TRadDeskDraw.Text(G, AView.Group.Title, Font.Name, Px(CCaptionFont), FontStyleRegular,
    MakeRect(R.X + Px(4), R.Y + R.Height * 0.62, R.Width - Px(8), R.Height * 0.36), FTheme.Text,
    StringAlignmentCenter, StringAlignmentNear, True);
end;

procedure TRADDesktopView.PaintPanel(G: TGPGraphics);
var
  R: TGPRectF;
  LAccent: Cardinal;
  I: Integer;
begin
  R := TRadDeskDraw.RectF(FPanelRect);
  LAccent := AccentOf(FPanelGroup);
  TRadDeskDraw.Shadow(G, R, Px(CRadius), Px(CShadow) * 1.5, FTheme.Shadow);
  if ReducedEffects then
    TRadDeskDraw.FillRound(G, R, Px(CRadius), TRadDeskDraw.WithAlpha(FTheme.WallBottom, 245))
  else
    TRadDeskDraw.Glass(G, FWallBlur, R, Px(CRadius), FTheme, TRadDeskDraw.WithAlpha(FTheme.GlassTint,
      Min(255, (FTheme.GlassTint shr 24) * 2)));
  TRadDeskDraw.FillRound(G, MakeRect(R.X + Px(12), R.Y + (Cell - Px(14)) / 2, Px(4), Px(14)), Px(2), LAccent);
  TRadDeskDraw.Text(G, FPanelGroup.Title, Font.Name, Px(CTitleFont), FontStyleBold,
    MakeRect(R.X + Px(24), R.Y, R.Width - Px(36), Cell), FTheme.Title, StringAlignmentNear,
    StringAlignmentCenter, False);
  if FPanelGroup.Items.Count = 0 then
    TRadDeskDraw.Text(G, CHintEmptyGroup, Font.Name, Px(CSmallFont), FontStyleRegular,
      MakeRect(R.X + Px(CPad), R.Y + Cell, R.Width - 2 * Px(CPad), R.Height - Cell - Px(CPad)), FTheme.SubText,
      StringAlignmentCenter, StringAlignmentCenter, True);
  for I := 0 to FTiles.Count - 1 do
    if FTiles[I].InPanel then
      PaintTile(G, FTiles[I]);
end;

procedure TRADDesktopView.PaintTile(G: TGPGraphics; const ATile: TRadDeskTileView);
var
  LAccent: Cardinal;
begin
  LAccent := AccentOf(ATile.Group);
  case ATile.Item.Kind of
    dkWidget: PaintWidget(G, ATile, LAccent);
    dkDashboard: PaintDashboard(G, ATile, LAccent);
  else
    PaintShortcut(G, ATile, LAccent);
  end;
end;

function TRADDesktopView.TileIconRect(const ATile: TRadDeskTileView): TRect;
var
  S: Integer;
begin
  if Assigned(FImages) and (ATile.ImageIndex >= 0) and (ATile.ImageIndex < FImages.Count) then
    S := FImages.Width
  else
    S := Min(Px(CMonogram), ATile.Rect.Width - Px(16));
  Result := Bounds(ATile.Rect.Left + (ATile.Rect.Width - S) div 2, ATile.Rect.Top + Px(6), S, S);
end;

procedure TRADDesktopView.PaintShortcut(G: TGPGraphics; const ATile: TRadDeskTileView; AAccent: Cardinal);
var
  LIcon: TRect;
  LColor, LText: Cardinal;
  LBadge: TGPRectF;
begin
  LIcon := TileIconRect(ATile);
  LText := FTheme.Text;
  if not ATile.Enabled then
    LText := FTheme.SubText;
  if not (Assigned(FImages) and (ATile.ImageIndex >= 0) and (ATile.ImageIndex < FImages.Count)) then
  begin
    LColor := AAccent;
    if ATile.State <> crOk then
      LColor := $FF6B7280;
    TRadDeskDraw.Monogram(G, TRadDeskDraw.RectF(LIcon), ATile.Caption, LColor, Font.Name);
  end;
  if ATile.State = crMissing then
  begin
    LBadge := MakeRect(Single(LIcon.Right - Px(8)), LIcon.Top - Px(6), Px(16), Px(16));
    TRadDeskDraw.FillRound(G, LBadge, Px(8), FTheme.Broken);
    TRadDeskDraw.Text(G, '!', Font.Name, Px(11), FontStyleBold, LBadge, $FF1F2937, StringAlignmentCenter,
      StringAlignmentCenter, False);
  end;
  TRadDeskDraw.Text(G, ATile.Caption, Font.Name, Px(CCaptionFont), FontStyleRegular,
    MakeRect(Single(ATile.Rect.Left + Px(2)), LIcon.Bottom + Px(4), ATile.Rect.Width - Px(4),
      ATile.Rect.Bottom - LIcon.Bottom - Px(4)), LText, StringAlignmentCenter, StringAlignmentNear, True);
end;

procedure TRADDesktopView.PaintWidget(G: TGPGraphics; const ATile: TRadDeskTileView; AAccent: Cardinal);
var
  R, LText, LChart: TGPRectF;
  LData: TRadDeskWidgetData;
  LTitle: string;
begin
  R := TRadDeskDraw.RectF(ATile.Rect);
  TRadDeskDraw.FillRound(G, R, Px(CTileRadius), TRadDeskDraw.WithAlpha(AAccent, 52));
  TRadDeskDraw.StrokeRound(G, R, Px(CTileRadius), 1, TRadDeskDraw.WithAlpha(AAccent, 110));
  LData := WidgetData(ATile.Item);
  LTitle := ATile.Item.Caption;
  if LTitle = '' then
    LTitle := IfThen(LData.Title <> '', LData.Title, ATile.Caption);
  TRadDeskDraw.Text(G, LTitle, Font.Name, Px(CSmallFont), FontStyleBold,
    MakeRect(R.X + Px(12), R.Y + Px(8), R.Width - Px(24), Px(18)), FTheme.SubText, StringAlignmentNear,
    StringAlignmentNear, False);
  if ATile.State <> crOk then
    LData.Error := 'Widget bulunamadı: ' + ATile.Item.Target;
  if LData.Error <> '' then
  begin
    TRadDeskDraw.Text(G, '⚠ ' + LData.Error, Font.Name, Px(CSmallFont), FontStyleRegular,
      MakeRect(R.X + Px(12), R.Y + Px(30), R.Width - Px(24), R.Height - Px(38)), FTheme.Broken,
      StringAlignmentNear, StringAlignmentNear, True);
    Exit;
  end;
  // A short tile puts the chart beside the value, a tall one below the text.
  LText := MakeRect(R.X + Px(12), R.Y + Px(26), R.Width - Px(24), R.Height - Px(32));
  LChart := MakeRect(0.0, 0, 0, 0);
  if LData.PointCount >= 2 then
    if R.Height < Px(150) then
    begin
      LText.Width := R.Width * 0.56 - Px(12);
      LChart := MakeRect(R.X + R.Width * 0.58, R.Y + Px(30), R.Width * 0.42 - Px(12), R.Height - Px(44));
    end
    else
      LChart := MakeRect(R.X + Px(10), R.Y + R.Height * 0.62, R.Width - Px(20), R.Height * 0.32);
  PaintWidgetText(G, LData, LText);
  if LChart.Width > 0 then
    PaintWidgetChart(G, LData, LChart, AAccent);
end;

procedure TRADDesktopView.PaintWidgetText(G: TGPGraphics; LData: TRadDeskWidgetData; const ARect: TGPRectF);
var
  LSize, Y, LTrend: Single;
  I: Integer;
begin
  LTrend := 0;
  LSize := TRadDeskDraw.FitSize(G, LData.Value, Font.Name, Px(CValueFont), Px(13), FontStyleBold,
    ARect.Width - LTrend);
  TRadDeskDraw.Text(G, LData.Value, Font.Name, LSize, FontStyleBold,
    MakeRect(ARect.X, ARect.Y, ARect.Width - LTrend, LSize * 1.4), FTheme.Title, StringAlignmentNear,
    StringAlignmentNear, False);
  // The trend sits beside the title (top right), so the value keeps the whole width of a small tile.
  if LData.Trend <> dtNone then
    TRadDeskDraw.Triangle(G, MakeRect(ARect.X + ARect.Width - Px(10), ARect.Y - Px(15), Px(10), Px(8)),
      LData.Trend = dtUp, IfThen(LData.Trend = dtUp, FTheme.Up, FTheme.Down));
  Y := ARect.Y + LSize * 1.35;
  TRadDeskDraw.Text(G, LData.SubText, Font.Name, Px(CSmallFont), FontStyleRegular,
    MakeRect(ARect.X, Y, ARect.Width, Px(16)), FTheme.SubText, StringAlignmentNear, StringAlignmentNear, False);
  Y := Y + Px(22);
  for I := 0 to LData.Lines.Count - 1 do
  begin
    if Y + Px(16) > ARect.Y + ARect.Height then
      Break;
    PaintWidgetLine(G, LData.Lines[I], MakeRect(ARect.X, Y, ARect.Width, Px(17)));
    Y := Y + Px(19);
  end;
end;

procedure TRADDesktopView.PaintWidgetLine(G: TGPGraphics; const ALine: string; const ARect: TGPRectF);
var
  LTab: Integer;
  LRight: Single;
begin
  // 'left<TAB>right': the right part (an amount) is right-aligned, the left part gives way.
  LTab := ALine.IndexOf(#9);
  if LTab < 0 then
  begin
    TRadDeskDraw.Text(G, ALine, Font.Name, Px(CSmallFont + 1), FontStyleRegular, ARect, FTheme.Text,
      StringAlignmentNear, StringAlignmentNear, False);
    Exit;
  end;
  TRadDeskDraw.Text(G, ALine.Substring(LTab + 1), Font.Name, Px(CSmallFont + 1), FontStyleBold, ARect, FTheme.Title,
    StringAlignmentFar, StringAlignmentNear, False);
  LRight := TRadDeskDraw.TextWidth(G, ALine.Substring(LTab + 1), Font.Name, Px(CSmallFont + 1), FontStyleBold);
  TRadDeskDraw.Text(G, ALine.Substring(0, LTab), Font.Name, Px(CSmallFont + 1), FontStyleRegular,
    MakeRect(ARect.X, ARect.Y, Max(0, ARect.Width - LRight - Px(8)), ARect.Height), FTheme.Text,
    StringAlignmentNear, StringAlignmentNear, False);
end;

procedure TRADDesktopView.PaintWidgetChart(G: TGPGraphics; LData: TRadDeskWidgetData; const ARect: TGPRectF;
  AAccent: Cardinal);
var
  LPoints: TArray<Double>;
  LColor: Cardinal;
  I: Integer;
begin
  LColor := LData.Color;
  if LColor = 0 then
    LColor := TRadDeskDraw.Shade(AAccent, 0.35);
  SetLength(LPoints, LData.PointCount);
  for I := 0 to LData.PointCount - 1 do
    LPoints[I] := LData.Points[I];
  TRadDeskDraw.Sparkline(G, ARect, LPoints, LColor);
end;

procedure TRADDesktopView.PaintDashboard(G: TGPGraphics; const ATile: TRadDeskTileView; AAccent: Cardinal);
var
  R, LIcon: TGPRectF;
  LBrush: TGPLinearGradientBrush;
  LPath: TGPGraphicsPath;
  S: Single;
begin
  R := TRadDeskDraw.RectF(ATile.Rect);
  LPath := TRadDeskDraw.RoundPath(R, Px(CTileRadius));
  try
    LBrush := TGPLinearGradientBrush.Create(R, TRadDeskDraw.WithAlpha(AAccent, 200),
      TRadDeskDraw.WithAlpha(TRadDeskDraw.Shade(AAccent, -0.35), 200), LinearGradientModeForwardDiagonal);
    try
      G.FillPath(LBrush, LPath);
    finally
      LBrush.Free;
    end;
  finally
    LPath.Free;
  end;
  S := Min(R.Width, R.Height) * 0.34;
  LIcon := MakeRect(R.X + Px(12), R.Y + Px(12), S, S);
  TRadDeskDraw.Bars(G, LIcon, $F0FFFFFF);
  TRadDeskDraw.Text(G, ATile.Caption, Font.Name, Px(CCaptionFont + 1), FontStyleBold,
    MakeRect(R.X + Px(12), R.Y + R.Height - Px(44), R.Width - Px(24), Px(40)), $FFFFFFFF,
    StringAlignmentNear, StringAlignmentFar, True);
end;

procedure TRADDesktopView.PaintIcons;
var
  LTile: TRadDeskTileView;
  LIcon: TRect;
begin
  if not Assigned(FImages) then
    Exit;
  for LTile in FTiles do
    if (LTile.Item.Kind = dkShortcut) and (LTile.ImageIndex >= 0) and (LTile.ImageIndex < FImages.Count) then
    begin
      LIcon := TileIconRect(LTile);
      FImages.Draw(FScene.Canvas, LIcon.Left, LIcon.Top, LTile.ImageIndex, LTile.Enabled);
    end;
end;

procedure TRADDesktopView.PaintEmptyHint(G: TGPGraphics);
begin
  TRadDeskDraw.Text(G, CHintEmptyDesktop, Font.Name, Px(CTitleFont + 2), FontStyleRegular,
    MakeRect(0.0, 0, ClientWidth, ClientHeight), FTheme.SubText, StringAlignmentCenter,
    StringAlignmentCenter, True);
end;

procedure TRADDesktopView.PaintOverlay(G: TGPGraphics);
var
  I: Integer;
  LView: TRadDeskGroupView;
  R: TGPRectF;
begin
  if FHot.Kind = hkItem then
  begin
    I := TileIndexOf(FHot.Item.Id);
    if I >= 0 then
      TRadDeskDraw.FillRound(G, TRadDeskDraw.RectF(FTiles[I].Rect), Px(CTileRadius),
        IfThen(FPressed and (FDragMode = dmNone), FTheme.Pressed, FTheme.Hover));
  end;
  if (FHot.Kind in [hkFolder, hkGroupTitle, hkGroupGrip]) and GroupViewOf(FHot.Group, LView) then
  begin
    if FHot.Kind = hkFolder then
      R := TRadDeskDraw.RectF(LView.Rect)
    else
      R := TRadDeskDraw.RectF(LView.TitleRect);
    TRadDeskDraw.FillRound(G, R, Px(CRadius), FTheme.Hover);
    if (FHot.Group.Style = gsBox) and not FLocked then
      TRadDeskDraw.Text(G, '◢', Font.Name, Px(12), FontStyleRegular, TRadDeskDraw.RectF(LView.GripRect),
        FTheme.SubText, StringAlignmentCenter, StringAlignmentCenter, False);
  end;
  I := TileIndexOf(FFocusId);
  if Focused and (I >= 0) then
    TRadDeskDraw.StrokeRound(G, TRadDeskDraw.RectF(FTiles[I].Rect), Px(CTileRadius), Px(2), FTheme.Focus);
  if FDragMode <> dmNone then
    PaintDragGhost(G);
  PaintScrollHint(G);
end;

procedure TRADDesktopView.PaintDragGhost(G: TGPGraphics);
var
  LHit: TRadDeskHit;
  LView: TRadDeskGroupView;
  LCell: TPoint;
  LCells: TRect;
  R: TGPRectF;
  I: Integer;
begin
  case FDragMode of
    dmItem:
      begin
        LHit := HitTest(FDragPoint);
        if (LHit.Kind in [hkPanel]) then
          TRadDeskDraw.StrokeRound(G, TRadDeskDraw.RectF(FPanelRect), Px(CRadius), Px(2), FTheme.Focus)
        else if (LHit.Kind <> hkNone) and (LHit.Kind <> hkDesktop) and GroupViewOf(LHit.Group, LView) then
          TRadDeskDraw.FillRound(G, TRadDeskDraw.RectF(LView.Rect), Px(CRadius), FTheme.DropTarget)
        else
        begin
          LCell := CellAt(FDragPoint);
          R := TRadDeskDraw.RectF(GroupPixelRect(Rect(LCell.X, LCell.Y, LCell.X + RAD_DESK_DEFAULT_GROUP_COLS,
            LCell.Y + 1 + RAD_DESK_TILE_CELLS)));
          TRadDeskDraw.StrokeRound(G, R, Px(CRadius), Px(2), FTheme.Focus);
        end;
        I := TileIndexOf(FPress.Item.Id);
        if I >= 0 then
        begin
          R := TRadDeskDraw.RectF(FTiles[I].Rect);
          R.X := FDragPoint.X - R.Width / 2;
          R.Y := FDragPoint.Y - R.Height / 2;
          TRadDeskDraw.FillRound(G, R, Px(CTileRadius), TRadDeskDraw.WithAlpha(FTheme.Focus, 90));
          TRadDeskDraw.Text(G, FTiles[I].Caption, Font.Name, Px(CCaptionFont), FontStyleBold, R, $FFFFFFFF,
            StringAlignmentCenter, StringAlignmentCenter, True);
        end;
      end;
    dmGroup, dmResize:
      if GroupViewOf(FPress.Group, LView) then
      begin
        LCell := CellAt(Point(FDragPoint.X - FDragOffset.X, FDragPoint.Y - FDragOffset.Y));
        if FDragMode = dmGroup then
          LCells := Rect(LCell.X, LCell.Y, LCell.X + LView.Cells.Width, LCell.Y + LView.Cells.Height)
        else
          LCells := Rect(LView.Cells.Left, LView.Cells.Top, Max(LView.Cells.Left + RAD_DESK_MIN_GROUP_COLS,
            CellAt(FDragPoint).X + 1), LView.Cells.Bottom);
        LCells := TRadDeskGrid.Clamp(LCells, GridColumns);
        TRadDeskDraw.FillRound(G, TRadDeskDraw.RectF(GroupPixelRect(LCells)), Px(CRadius), FTheme.DropTarget);
        TRadDeskDraw.StrokeRound(G, TRadDeskDraw.RectF(GroupPixelRect(LCells)), Px(CRadius), Px(2), FTheme.Focus);
      end;
  end;
end;

procedure TRADDesktopView.PaintScrollHint(G: TGPGraphics);
var
  LTrack, LThumb: Single;
begin
  if FContentHeight <= ClientHeight then
    Exit;
  LTrack := ClientHeight - Px(16);
  LThumb := Max(Px(24), LTrack * ClientHeight / FContentHeight);
  TRadDeskDraw.FillRound(G, MakeRect(ClientWidth - Px(7), Px(8) + (LTrack - LThumb) * FScrollY /
    Max(1, FContentHeight - ClientHeight), Px(4), LThumb), Px(2), TRadDeskDraw.WithAlpha(FTheme.Text, 90));
end;

procedure TRADDesktopView.Paint;
var
  G: TGPGraphics;
begin
  if not FSceneValid then
    BuildScene;
  FBuffer.SetSize(FScene.Width, FScene.Height);
  FBuffer.Canvas.Draw(0, 0, FScene);
  G := TGPGraphics.Create(FBuffer.Canvas.Handle);
  try
    TRadDeskDraw.Prepare(G);
    PaintOverlay(G);
  finally
    G.Free;
  end;
  Canvas.Draw(0, 0, FBuffer);
end;

procedure TRADDesktopView.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure TRADDesktopView.SaveSnapshot(const AFileName: string);
var
  LPng: TPngImage;
begin
  HandleNeeded;
  Paint;
  LPng := TPngImage.Create;
  try
    LPng.Assign(FBuffer);
    LPng.SaveToFile(AFileName);
  finally
    LPng.Free;
  end;
end;

{ --- hit testing --- }

function TRADDesktopView.HitTest(const APoint: TPoint): TRadDeskHit;
var
  I: Integer;
begin
  NeedArranged;
  Result := TRadDeskHit.None;
  if not ClientRect.Contains(APoint) then
    Exit;
  Result.Kind := hkDesktop;
  if Assigned(FPanelGroup) and FPanelRect.Contains(APoint) then
  begin
    Result.Kind := hkPanel;
    Result.Group := FPanelGroup;
    for I := 0 to FTiles.Count - 1 do
      if FTiles[I].InPanel and FTiles[I].Rect.Contains(APoint) then
      begin
        Result.Kind := hkItem;
        Result.Item := FTiles[I].Item;
        Exit;
      end;
    Exit;
  end;
  for I := 0 to FTiles.Count - 1 do
    if not FTiles[I].InPanel and FTiles[I].Rect.Contains(APoint) then
    begin
      Result.Kind := hkItem;
      Result.Item := FTiles[I].Item;
      Result.Group := FTiles[I].Group;
      Exit;
    end;
  for I := High(FGroups) downto 0 do
    if FGroups[I].Rect.Contains(APoint) then
    begin
      Result.Group := FGroups[I].Group;
      if FGroups[I].Group.Style = gsFolder then
        Result.Kind := hkFolder
      else if FGroups[I].GripRect.Contains(APoint) and not FGroups[I].Group.Collapsed then
        Result.Kind := hkGroupGrip
      else if FGroups[I].TitleRect.Contains(APoint) then
        Result.Kind := hkGroupTitle
      else
        Result.Kind := hkGroupBody;
      Exit;
    end;
end;

function TRADDesktopView.CellAt(const APoint: TPoint): TPoint;
begin
  Result.X := Max(0, Floor((APoint.X - Px(CMargin)) / Cell));
  Result.Y := Max(0, Floor((APoint.Y + FScrollY - Px(CMargin)) / Cell));
end;

{ --- mouse --- }

procedure TRADDesktopView.SetHot(const AHit: TRadDeskHit);
begin
  if SameHit(AHit, FHot) then
    Exit;
  FHot := AHit;
  Invalidate;
end;

procedure TRADDesktopView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if CanFocus and not Focused then
    SetFocus;
  if Button <> mbLeft then
    Exit;
  FPress := HitTest(Point(X, Y));
  FPressPoint := Point(X, Y);
  FPressed := True;
  if (FPress.Kind = hkItem) then
    FFocusId := FPress.Item.Id;
  Invalidate;
end;

procedure TRADDesktopView.StartDrag;
var
  LView: TRadDeskGroupView;
begin
  case FPress.Kind of
    hkItem: FDragMode := dmItem;
    hkGroupTitle, hkFolder: FDragMode := dmGroup;
    hkGroupGrip: FDragMode := dmResize;
  else
    FDragMode := dmNone;
  end;
  if (FDragMode in [dmGroup, dmResize]) and GroupViewOf(FPress.Group, LView) then
    FDragOffset := Point(FPressPoint.X - LView.Rect.Left, FPressPoint.Y - LView.Rect.Top);
  if (FDragMode = dmGroup) and (FPress.Group = FPanelGroup) then
    CloseFolder;
end;

procedure TRADDesktopView.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if FPressed and (FDragMode = dmNone) and not FLocked and ((Abs(X - FPressPoint.X) > Mouse.DragThreshold) or
    (Abs(Y - FPressPoint.Y) > Mouse.DragThreshold)) then
    StartDrag;
  if FDragMode <> dmNone then
  begin
    FDragPoint := Point(X, Y);
    Invalidate;
  end
  else
    SetHot(HitTest(Point(X, Y)));
end;

procedure TRADDesktopView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  LMode: TRadDeskDragMode;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (Button <> mbLeft) or not FPressed then
    Exit;
  FPressed := False;
  LMode := FDragMode;
  FDragMode := dmNone;
  case LMode of
    dmItem: DropItem(Point(X, Y));
    dmGroup: DropGroup(Point(X, Y));
    dmResize: DropResize(Point(X, Y));
  else
    if SameHit(HitTest(Point(X, Y)), FPress) then
      ClickHit(FPress);
  end;
  Invalidate;
end;

procedure TRADDesktopView.ClickHit(const AHit: TRadDeskHit);
begin
  case AHit.Kind of
    hkItem: ExecuteItem(AHit.Item);
    hkFolder:
      if FPanelGroup = AHit.Group then
        CloseFolder
      else
        OpenFolder(AHit.Group);
    hkPanel: ;
  else
    CloseFolder;
  end;
end;

procedure TRADDesktopView.DblClick;
var
  LHit: TRadDeskHit;
begin
  inherited DblClick;
  LHit := HitTest(ScreenToClient(Mouse.CursorPos));
  if (LHit.Kind = hkGroupTitle) and not FLocked then
    ToggleCollapsed(LHit.Group);
end;

procedure TRADDesktopView.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  SetHot(TRadDeskHit.None);
end;

function TRADDesktopView.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if not Result then
  begin
    ScrollBy(-Sign(WheelDelta) * Px(CScrollStep));
    Result := True;
  end;
end;

procedure TRADDesktopView.ScrollBy(ADelta: Integer);
var
  LNew: Integer;
begin
  NeedArranged;
  LNew := EnsureRange(FScrollY + ADelta, 0, Max(0, FContentHeight - ClientHeight));
  if LNew = FScrollY then
    Exit;
  FScrollY := LNew;
  Rebuild;
end;

{ --- drop --- }

function TRADDesktopView.DropIndex(AGroup: TRadDeskGroup; const APoint: TPoint): Integer;
var
  I: Integer;
  LTile: TRadDeskTileView;
begin
  for I := 0 to FTiles.Count - 1 do
  begin
    LTile := FTiles[I];
    if (LTile.Group = AGroup) and LTile.Rect.Contains(APoint) then
    begin
      Result := AGroup.IndexOfItem(LTile.Item.Id);
      if APoint.X > LTile.Rect.CenterPoint.X then
        Inc(Result);
      Exit;
    end;
  end;
  Result := -1;
end;

procedure TRADDesktopView.DropItem(const APoint: TPoint);
var
  LHit: TRadDeskHit;
  LGroup: TRadDeskGroup;
  LItemId: string;
begin
  LItemId := FPress.Item.Id;
  LHit := HitTest(APoint);
  case LHit.Kind of
    hkPanel, hkFolder, hkGroupTitle, hkGroupBody, hkGroupGrip:
      FLayout.MoveItem(LItemId, LHit.Group, -1);
    hkItem:
      if Assigned(LHit.Group) then
        FLayout.MoveItem(LItemId, LHit.Group, DropIndex(LHit.Group, APoint))
      else if Assigned(FPanelGroup) then
        FLayout.MoveItem(LItemId, FPanelGroup, FPanelGroup.IndexOfItem(LHit.Item.Id));
    hkDesktop:
      begin
        LGroup := NewGroup(CNewGroupTitle, gsBox, CellAt(APoint));
        FLayout.MoveItem(LItemId, LGroup, -1);
      end;
  else
    Exit;
  end;
  FFocusId := LItemId;
  Changed;
end;

procedure TRADDesktopView.DropGroup(const APoint: TPoint);
var
  LCell: TPoint;
  LView: TRadDeskGroupView;
  LCells, LResolved: TArray<TRect>;
  LIndex, I: Integer;
begin
  if not GroupViewOf(FPress.Group, LView) then
    Exit;
  LCell := CellAt(Point(APoint.X - FDragOffset.X, APoint.Y - FDragOffset.Y));
  LIndex := FLayout.Groups.IndexOf(FPress.Group);
  SetLength(LCells, Length(FGroups));
  for I := 0 to High(FGroups) do
    LCells[I] := FGroups[I].Cells;
  LCells[LIndex] := TRadDeskGrid.Clamp(Rect(LCell.X, LCell.Y, LCell.X + LView.Cells.Width,
    LCell.Y + LView.Cells.Height), GridColumns);
  TRadDeskGrid.Resolve(LCells, LIndex, LResolved);
  for I := 0 to High(FGroups) do
  begin
    FGroups[I].Group.Col := LResolved[I].Left;
    FGroups[I].Group.Row := LResolved[I].Top;
  end;
  Changed;
end;

procedure TRADDesktopView.DropResize(const APoint: TPoint);
var
  LView: TRadDeskGroupView;
begin
  if not GroupViewOf(FPress.Group, LView) then
    Exit;
  FPress.Group.Col := LView.Cells.Left;
  FPress.Group.Row := LView.Cells.Top;
  FPress.Group.Cols := Min(GridColumns, CellAt(APoint).X + 1) - LView.Cells.Left;
  Changed;
end;

{ --- operations --- }

procedure TRADDesktopView.OpenFolder(AGroup: TRadDeskGroup);
begin
  FPanelGroup := AGroup;
  Rebuild;
end;

procedure TRADDesktopView.CloseFolder;
begin
  if not Assigned(FPanelGroup) then
    Exit;
  FPanelGroup := nil;
  Rebuild;
end;

function TRADDesktopView.ExecuteItem(AItem: TRadDeskItem): Boolean;
var
  LHandled: Boolean;
begin
  Result := False;
  if not Assigned(AItem) then
    Exit;
  LHandled := False;
  if Assigned(FOnExecute) then
    FOnExecute(Self, AItem, LHandled);
  if LHandled then
    Exit(True);
  case AItem.Kind of
    dkShortcut:
      Result := Assigned(FCommands) and FCommands.Execute(AItem.Target);
    dkDashboard:
      if FAllowDashboards and Assigned(FOnOpenDashboard) then
      begin
        FOnOpenDashboard(Self, AItem);
        Result := True;
      end;
    dkWidget:
      begin
        FDue.Remove(AItem.Id);
        RefreshWidgets(False);
        Result := True;
      end;
  end;
end;

function TRADDesktopView.NewGroup(const ATitle: string; AStyle: TRadDeskGroupStyle;
  const ACell: TPoint): TRadDeskGroup;
var
  LCells, LResolved: TArray<TRect>;
  I: Integer;
begin
  NeedArranged;
  Result := FLayout.AddGroup(ATitle, AStyle);
  Result.Col := Min(ACell.X, Max(0, GridColumns - Result.Cols));
  Result.Row := ACell.Y;
  SetLength(LCells, Length(FGroups) + 1);
  for I := 0 to High(FGroups) do
    LCells[I] := FGroups[I].Cells;
  if AStyle = gsFolder then
    LCells[High(LCells)] := Rect(Result.Col, Result.Row, Result.Col + RAD_DESK_FOLDER_CELLS,
      Result.Row + RAD_DESK_FOLDER_CELLS)
  else
    LCells[High(LCells)] := Rect(Result.Col, Result.Row, Result.Col + Result.Cols,
      Result.Row + 1 + RAD_DESK_TILE_CELLS);
  TRadDeskGrid.Resolve(LCells, High(LCells), LResolved);
  for I := 0 to High(FGroups) do
  begin
    FGroups[I].Group.Col := LResolved[I].Left;
    FGroups[I].Group.Row := LResolved[I].Top;
  end;
  Changed;
end;

procedure TRADDesktopView.AddShortcuts(AGroup: TRadDeskGroup; const AIds: TArray<string>);
var
  LId: string;
begin
  if not Assigned(AGroup) or (Length(AIds) = 0) then
    Exit;
  for LId in AIds do
    AGroup.Items.Add(TRadDeskItem.Create(dkShortcut, LId));
  Changed;
end;

function TRADDesktopView.AddWidget(AGroup: TRadDeskGroup; const AProviderId: string): TRadDeskItem;
var
  LProvider: IRadDeskWidgetProvider;
begin
  Result := nil;
  if not Assigned(AGroup) or not Assigned(FWidgets) then
    Exit;
  LProvider := FWidgets.Find(AProviderId);
  if not Assigned(LProvider) then
    Exit;
  Result := TRadDeskItem.Create(dkWidget, LProvider.Id);
  Result.Size := LProvider.DefaultSize;
  AGroup.Items.Add(Result);
  Changed;
  RefreshWidgets(False);
end;

function TRADDesktopView.AddDashboard(AGroup: TRadDeskGroup; const AName: string): TRadDeskItem;
begin
  Result := nil;
  if not Assigned(AGroup) or (AName.Trim = '') then
    Exit;
  Result := TRadDeskItem.Create(dkDashboard, AName.Trim);
  Result.Size := dsWide;
  AGroup.Items.Add(Result);
  Changed;
end;

procedure TRADDesktopView.ToggleCollapsed(AGroup: TRadDeskGroup);
begin
  if not Assigned(AGroup) or (AGroup.Style = gsFolder) then
    Exit;
  AGroup.Collapsed := not AGroup.Collapsed;
  Changed;
end;

function TRADDesktopView.Confirm(const AMessage: string): Boolean;
begin
  if Assigned(FOnConfirm) then
  begin
    Result := False;
    FOnConfirm(Self, AMessage, Result);
  end
  else
    Result := MessageDlg(AMessage, mtConfirmation, [mbYes, mbNo], 0) = mrYes;
end;

function TRADDesktopView.RemoveGroup(AGroup: TRadDeskGroup): Boolean;
begin
  Result := Assigned(AGroup) and Confirm(Format('"%s" grubu ve içindeki %d öğe kaldırılsın mı?',
    [AGroup.Title, AGroup.Items.Count]));
  if not Result then
    Exit;
  if FPanelGroup = AGroup then
    FPanelGroup := nil;
  FLayout.DeleteGroup(AGroup.Id);
  Changed;
end;

function TRADDesktopView.RemoveItem(AItem: TRadDeskItem): Boolean;
var
  LInfo: TRadDeskCommandInfo;
begin
  Result := Assigned(AItem);
  if not Result then
    Exit;
  ResolveItem(AItem, LInfo);
  Result := Confirm(Format('"%s" kaldırılsın mı?', [LInfo.Caption]));
  if not Result then
    Exit;
  FData.Remove(AItem.Id);
  FDue.Remove(AItem.Id);
  if FFocusId = AItem.Id then
    FFocusId := '';
  FLayout.DeleteItem(AItem.Id);
  Changed;
end;

procedure TRADDesktopView.DoResetLayout;
begin
  if Assigned(FOnResetLayout) then
    FOnResetLayout(Self);
end;

procedure TRADDesktopView.DoSaveAsBase;
begin
  if Assigned(FOnSaveAsBase) then
    FOnSaveAsBase(Self);
end;

function TRADDesktopView.FocusedItem: TRadDeskItem;
var
  I: Integer;
begin
  NeedArranged;
  I := TileIndexOf(FFocusId);
  if I < 0 then
    Result := nil
  else
    Result := FTiles[I].Item;
end;

procedure TRADDesktopView.FocusItem(const AItemId: string);
begin
  FFocusId := AItemId;
  Invalidate;
end;

{ --- keyboard --- }

procedure TRADDesktopView.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  inherited;
  Message.Result := Message.Result or DLGC_WANTARROWS or DLGC_WANTCHARS;
end;

procedure TRADDesktopView.DoEnter;
begin
  inherited DoEnter;
  NeedArranged;
  if (TileIndexOf(FFocusId) < 0) and (FTiles.Count > 0) then
    FFocusId := FTiles[0].Item.Id;
  Invalidate;
end;

procedure TRADDesktopView.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

procedure TRADDesktopView.MoveFocus(ADir: TRadDeskDirection);
var
  LRects: TArray<TRect>;
  LCurrent, LNext, I: Integer;
begin
  NeedArranged;
  if FTiles.Count = 0 then
    Exit;
  SetLength(LRects, FTiles.Count);
  for I := 0 to FTiles.Count - 1 do
    LRects[I] := FTiles[I].Rect;
  LCurrent := TileIndexOf(FFocusId);
  if LCurrent < 0 then
    LNext := 0
  else
    LNext := TRadDeskNav.Nearest(LRects, LCurrent, ADir);
  if LNext >= 0 then
    FocusItem(FTiles[LNext].Item.Id);
end;

procedure TRADDesktopView.KeyDown(var Key: Word; Shift: TShiftState);
var
  LItem: TRadDeskItem;
begin
  inherited KeyDown(Key, Shift);
  LItem := FocusedItem;
  case Key of
    VK_LEFT: MoveFocus(ddLeft);
    VK_RIGHT: MoveFocus(ddRight);
    VK_UP: MoveFocus(ddUp);
    VK_DOWN: MoveFocus(ddDown);
    VK_RETURN: ExecuteItem(LItem);
    VK_ESCAPE:
      begin
        FDragMode := dmNone;
        FPressed := False;
        CloseFolder;
      end;
    VK_DELETE:
      if not FLocked then
        RemoveItem(LItem);
  else
    Exit;
  end;
  Key := 0;
end;

procedure TRADDesktopView.FindByText(AChar: Char);
var
  LCaptions: TArray<string>;
  I, LFound: Integer;
begin
  NeedArranged;
  if GetTickCount - FFindTick > CFindResetMs then
    FFind := '';
  FFindTick := GetTickCount;
  FFind := FFind + AChar;
  SetLength(LCaptions, FTiles.Count);
  for I := 0 to FTiles.Count - 1 do
    LCaptions[I] := FTiles[I].Caption;
  if Length(FFind) = 1 then
    LFound := TRadDeskNav.Find(LCaptions, TileIndexOf(FFocusId), FFind)
  else
    LFound := TRadDeskNav.Find(LCaptions, TileIndexOf(FFocusId) - 1, FFind);
  if LFound >= 0 then
    FocusItem(FTiles[LFound].Item.Id);
end;

procedure TRADDesktopView.KeyPress(var Key: Char);
begin
  inherited KeyPress(Key);
  if Key >= ' ' then
  begin
    FindByText(Key);
    Key := #0;
  end;
end;

{ --- context menu --- }

procedure TRADDesktopView.DoContextPopup(MousePos: TPoint; var Handled: Boolean);
var
  LHit: TRadDeskHit;
  LScreen: TPoint;
begin
  inherited DoContextPopup(MousePos, Handled);
  if Handled then
    Exit;
  if (MousePos.X < 0) and (MousePos.Y < 0) then
  begin
    LHit := TRadDeskHit.None;
    LHit.Item := FocusedItem;
    if Assigned(LHit.Item) then
    begin
      LHit.Kind := hkItem;
      LHit.Group := FTiles[TileIndexOf(FFocusId)].Group;
      MousePos := FTiles[TileIndexOf(FFocusId)].Rect.CenterPoint;
    end
    else
      MousePos := Point(Px(CMargin), Px(CMargin));
  end
  else
    LHit := HitTest(MousePos);
  LScreen := ClientToScreen(MousePos);
  ShowContextMenu(LHit, LScreen);
  Handled := True;
end;

procedure TRADDesktopView.ShowContextMenu(const AHit: TRadDeskHit; const AScreen: TPoint);
var
  LHandled: Boolean;
begin
  LHandled := False;
  if Assigned(FOnContextMenu) then
    FOnContextMenu(Self, AHit, AScreen, LHandled);
  if LHandled then
    Exit;
  if not Assigned(FMenus) then
    FMenus := TRadDeskMenus.Create(nil);
  TRadDeskMenus(FMenus).Popup(Self, AHit, AScreen);
end;

end.
