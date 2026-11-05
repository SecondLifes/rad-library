unit rad.search.popup;

{ Arama kutusunun açılır sonuç listesi ve kutuya bağlanan denetleyici.
  Liste kendi çizen, odak almayan bir açılır penceredir: yazarken odak arama kutusunda kalır.
  Renkler kutunun DevExpress skin'inden okunur; sabit renk yoktur. }

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.ImgList,
  Vcl.Forms,
  Vcl.AppEvnts,
  cxLookAndFeels,
  cxLookAndFeelPainters,
  cxEdit,
  cxTextEdit,
  rad.search.core;

type
  /// <summary>Sağlayıcı anahtarından grup başlığı.</summary>
  TRadSearchCaptionFunc = reference to function(const AKey: string): string;

  TRadSearchPickEvent = procedure(Sender: TObject; const AHit: TRadSearchHit) of object;

  /// <summary>Gruplu, ikonlu, iki satırlı (başlık + yol) sonuç listesi.</summary>
  TRadSearchPopup = class(TCustomControl)
  private
    type
      TRow = record
        IsHeader: Boolean;
        Text: string;
        HitIndex: Integer;
      end;
  private
    FHits: TRadSearchHits;
    FRows: TArray<TRow>;
    FRowIndex: Integer;
    FTopRow: Integer;
    FImages: TCustomImageList;
    FPainter: TcxCustomLookAndFeelPainter;
    FPPI: Integer;
    FMaxRows: Integer;
    FShown: Boolean;
    FOwnerWnd: HWND;
    FOnPick: TRadSearchPickEvent;
    function Scale(AValue: Integer): Integer;
    function ItemHeight: Integer;
    function HeaderHeight: Integer;
    function RowHeight(ARow: Integer): Integer;
    function RowAt(Y: Integer): Integer;
    function VisibleHeight: Integer;
    function ContentColor: TColor;
    function TextColor: TColor;
    function DimColor: TColor;
    procedure EnsureVisible;
    procedure PaintHeader(const ARect: TRect; const AText: string);
    procedure PaintItem(const ARect: TRect; const AHit: TRadSearchHit; ASelected: Boolean);
    procedure WMMouseActivate(var Message: TWMMouseActivate); message WM_MOUSEACTIVATE;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    /// <summary>AGroupCaption sağlayıcı anahtarından grup başlığını verir. AFixedGroup doluysa
    /// tüm sonuçlar bu tek başlığın altında gösterilir (sık kullanılanlar).</summary>
    procedure Fill(const AHits: TRadSearchHits; const AGroupCaption: TRadSearchCaptionFunc;
      const AFixedGroup: string = '');
    /// <summary>AAnchor ekran koordinatıdır; liste altında, sığmazsa üstünde açılır.
    /// AOwnerWnd listenin sahibi olan üst pencere (kutunun formu).</summary>
    procedure ShowAt(const AAnchor: TRect; AMinWidth: Integer; AOwnerWnd: HWND);
    procedure HidePopup;
    /// <summary>Seçimi sonuçlar arasında ADelta kadar kaydırır; başlık satırları atlanır.</summary>
    procedure Move(ADelta: Integer);
    function Selected(out AHit: TRadSearchHit): Boolean;
    function PageRows: Integer;
    property Images: TCustomImageList read FImages write FImages;
    property Painter: TcxCustomLookAndFeelPainter read FPainter write FPainter;
    property PPI: Integer read FPPI write FPPI;
    property Shown: Boolean read FShown;
    property OnPick: TRadSearchPickEvent read FOnPick write FOnPick;
  end;

  /// <summary>Bir DevExpress metin kutusunu arama kutusuna çevirir. Kutunun mevcut olay
  /// işleyicileri korunur ve zincirlenir; Coz eski hallerine döndürür.</summary>
  TRadSearchBox = class(TComponent)
  private
    FEdit: TcxCustomTextEdit;
    FEngine: TRadSearchEngine;
    FPopup: TRadSearchPopup;
    FAppEvents: TApplicationEvents;
    FOldChange: TNotifyEvent;
    FOldKeyDown: TKeyEvent;
    FOldEnter: TNotifyEvent;
    FOldExit: TNotifyEvent;
    FOldFocusChanged: TNotifyEvent;
    FFrequentCaption: string;
    FFrequentCount: Integer;
    FUpdating: Boolean;
    procedure EditChange(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditEnter(Sender: TObject);
    procedure EditExit(Sender: TObject);
    procedure EditFocusChanged(Sender: TObject);
    procedure AppDeactivate(Sender: TObject);
    procedure PopupPick(Sender: TObject; const AHit: TRadSearchHit);
    function GroupCaption(const AProvider: string): string;
    procedure Refresh;
    procedure ClearText;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>AEngine sahiplenilmez. AImages sonuçların ImageIndex'ini çözer (nil olabilir).</summary>
    procedure Bagla(AEdit: TcxCustomTextEdit; AEngine: TRadSearchEngine; AImages: TCustomImageList);
    procedure Coz;
    /// <summary>Kutuya odaklanır ve metni seçer (kısayol tuşu için).</summary>
    procedure Odakla;
    property Edit: TcxCustomTextEdit read FEdit;
    /// <summary>Kutu boşken gösterilen listenin başlığı.</summary>
    property FrequentCaption: string read FFrequentCaption write FFrequentCaption;
    property FrequentCount: Integer read FFrequentCount write FFrequentCount;
  end;

implementation

uses
  System.Math,
  cxGraphics;

type
  TcxEditAccess = class(TcxCustomEdit);

function Blend(AColor1, AColor2: TColor; APercent2: Integer): TColor;
var
  LC1, LC2: Longint;
begin
  LC1 := ColorToRGB(AColor1);
  LC2 := ColorToRGB(AColor2);
  Result := RGB(
    (GetRValue(LC1) * (100 - APercent2) + GetRValue(LC2) * APercent2) div 100,
    (GetGValue(LC1) * (100 - APercent2) + GetGValue(LC2) * APercent2) div 100,
    (GetBValue(LC1) * (100 - APercent2) + GetBValue(LC2) * APercent2) div 100);
end;

{ TRadSearchPopup }

constructor TRadSearchPopup.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  FPPI := Screen.PixelsPerInch;
  FMaxRows := 12;
  FRowIndex := -1;
  Visible := False;
end;

procedure TRadSearchPopup.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := WS_POPUP or WS_BORDER;
  Params.ExStyle := Params.ExStyle or WS_EX_TOOLWINDOW or WS_EX_NOACTIVATE;
  Params.WindowClass.style := Params.WindowClass.style or CS_DROPSHADOW;
  Params.WndParent := FOwnerWnd;
end;

procedure TRadSearchPopup.WMMouseActivate(var Message: TWMMouseActivate);
begin
  // Tıklama listeyi etkinleştirmez; odak arama kutusunda kalır.
  Message.Result := MA_NOACTIVATE;
end;

procedure TRadSearchPopup.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

function TRadSearchPopup.Scale(AValue: Integer): Integer;
begin
  Result := MulDiv(AValue, FPPI, 96);
end;

function TRadSearchPopup.ItemHeight: Integer;
var
  LImage: Integer;
begin
  LImage := 0;
  if Assigned(FImages) then
    LImage := FImages.Height;
  Canvas.Font := Font;
  Result := Max(LImage + Scale(10), Canvas.TextHeight('Ağ') * 2 + Scale(12));
end;

function TRadSearchPopup.HeaderHeight: Integer;
begin
  Canvas.Font := Font;
  Result := Canvas.TextHeight('Ağ') + Scale(10);
end;

function TRadSearchPopup.RowHeight(ARow: Integer): Integer;
begin
  if FRows[ARow].IsHeader then
    Result := HeaderHeight
  else
    Result := ItemHeight;
end;

function TRadSearchPopup.VisibleHeight: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := FTopRow to Min(High(FRows), FTopRow + FMaxRows - 1) do
    Inc(Result, RowHeight(I));
end;

function TRadSearchPopup.PageRows: Integer;
begin
  Result := Max(1, FMaxRows - 2);
end;

function TRadSearchPopup.RowAt(Y: Integer): Integer;
var
  I, LTop: Integer;
begin
  LTop := 0;
  for I := FTopRow to High(FRows) do
  begin
    if (Y >= LTop) and (Y < LTop + RowHeight(I)) then
      Exit(I);
    Inc(LTop, RowHeight(I));
  end;
  Result := -1;
end;

function TRadSearchPopup.ContentColor: TColor;
begin
  if Assigned(FPainter) then
    Result := FPainter.DefaultContentColor
  else
    Result := clWindow;
end;

function TRadSearchPopup.TextColor: TColor;
begin
  if Assigned(FPainter) then
    Result := FPainter.DefaultContentTextColor
  else
    Result := clWindowText;
end;

function TRadSearchPopup.DimColor: TColor;
begin
  Result := Blend(TextColor, ContentColor, 45);
end;

procedure TRadSearchPopup.Fill(const AHits: TRadSearchHits; const AGroupCaption: TRadSearchCaptionFunc;
  const AFixedGroup: string);
var
  I: Integer;
  LRow: TRow;
  LGroup: string;
begin
  FHits := AHits;
  FRows := nil;
  LGroup := #0;
  for I := 0 to High(FHits) do
  begin
    if (AFixedGroup = '') and (FHits[I].Provider <> LGroup) or (AFixedGroup <> '') and (I = 0) then
    begin
      LGroup := FHits[I].Provider;
      LRow.IsHeader := True;
      if AFixedGroup <> '' then
        LRow.Text := AFixedGroup
      else
        LRow.Text := AGroupCaption(LGroup);
      LRow.HitIndex := -1;
      if LRow.Text <> '' then
        FRows := FRows + [LRow];
    end;
    LRow.IsHeader := False;
    LRow.Text := '';
    LRow.HitIndex := I;
    FRows := FRows + [LRow];
  end;
  FTopRow := 0;
  FRowIndex := -1;
  Move(1);
end;

procedure TRadSearchPopup.ShowAt(const AAnchor: TRect; AMinWidth: Integer; AOwnerWnd: HWND);
var
  LWork: TRect;
  LHeight, LTop: Integer;
begin
  if Length(FRows) = 0 then
  begin
    HidePopup;
    Exit;
  end;
  if HandleAllocated and (FOwnerWnd <> AOwnerWnd) then
    DestroyHandle;
  FOwnerWnd := AOwnerWnd;
  HandleNeeded;
  LHeight := VisibleHeight + 2;
  LWork := Screen.MonitorFromRect(AAnchor).WorkareaRect;
  LTop := AAnchor.Bottom + Scale(2);
  if (LTop + LHeight > LWork.Bottom) and (AAnchor.Top - LHeight - Scale(2) >= LWork.Top) then
    LTop := AAnchor.Top - LHeight - Scale(2);
  SetWindowPos(Handle, HWND_TOP, AAnchor.Left, LTop, Max(AMinWidth, AAnchor.Width), LHeight,
    SWP_NOACTIVATE or SWP_SHOWWINDOW);
  FShown := True;
  Invalidate;
end;

procedure TRadSearchPopup.HidePopup;
begin
  if FShown and HandleAllocated then
    ShowWindow(Handle, SW_HIDE);
  FShown := False;
end;

procedure TRadSearchPopup.EnsureVisible;
begin
  if FRowIndex < 0 then
    Exit;
  // Grubun ilk satırı seçiliyse başlığı da görünür tut.
  if (FRowIndex > 0) and FRows[FRowIndex - 1].IsHeader and (FRowIndex - 1 < FTopRow) then
    FTopRow := FRowIndex - 1
  else if FRowIndex < FTopRow then
    FTopRow := FRowIndex;
  if FRowIndex >= FTopRow + FMaxRows then
    FTopRow := FRowIndex - FMaxRows + 1;
end;

procedure TRadSearchPopup.Move(ADelta: Integer);
var
  LRow, LStep, LLeft: Integer;
begin
  if Length(FRows) = 0 then
    Exit;
  LStep := Sign(ADelta);
  LLeft := Abs(ADelta);
  LRow := FRowIndex;
  if LRow < 0 then
    LRow := -1;
  while LLeft > 0 do
  begin
    repeat
      Inc(LRow, LStep);
    until (LRow < 0) or (LRow > High(FRows)) or not FRows[LRow].IsHeader;
    if (LRow < 0) or (LRow > High(FRows)) then
      Break;
    FRowIndex := LRow;
    Dec(LLeft);
  end;
  EnsureVisible;
  if FShown then
    Invalidate;
end;

function TRadSearchPopup.Selected(out AHit: TRadSearchHit): Boolean;
begin
  Result := (FRowIndex >= 0) and (FRowIndex <= High(FRows)) and not FRows[FRowIndex].IsHeader;
  if Result then
    AHit := FHits[FRows[FRowIndex].HitIndex];
end;

procedure TRadSearchPopup.PaintHeader(const ARect: TRect; const AText: string);
var
  LRect: TRect;
begin
  Canvas.Font := Font;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := DimColor;
  LRect := ARect;
  Inc(LRect.Left, Scale(10));
  DrawText(Canvas.Handle, PChar(AText), -1, LRect, DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS or DT_NOPREFIX);
end;

procedure TRadSearchPopup.PaintItem(const ARect: TRect; const AHit: TRadSearchHit; ASelected: Boolean);
var
  LText, LPath: TRect;
  LLeft, LLine: Integer;
  LFore, LDim: TColor;
begin
  LFore := TextColor;
  LDim := DimColor;
  if ASelected then
  begin
    Canvas.Brush.Color := Blend(ContentColor, FPainter.DefaultSelectionColor, 22);
    Canvas.FillRect(Rect(ARect.Left + Scale(4), ARect.Top + 1, ARect.Right - Scale(4), ARect.Bottom - 1));
    Canvas.Brush.Color := FPainter.DefaultSelectionColor;
    Canvas.FillRect(Rect(ARect.Left + Scale(4), ARect.Top + Scale(6), ARect.Left + Scale(7), ARect.Bottom - Scale(6)));
  end;
  LLeft := ARect.Left + Scale(14);
  if Assigned(FImages) then
  begin
    if (AHit.ImageIndex >= 0) and (AHit.ImageIndex < FImages.Count) then
      FImages.Draw(Canvas, LLeft, ARect.Top + (ARect.Height - FImages.Height) div 2, AHit.ImageIndex);
    Inc(LLeft, FImages.Width + Scale(10));
  end;
  Canvas.Brush.Style := bsClear;
  Canvas.Font := Font;
  LLine := Canvas.TextHeight('Ağ');
  if AHit.Path = '' then
    LText := Rect(LLeft, ARect.Top, ARect.Right - Scale(8), ARect.Bottom)
  else
    LText := Rect(LLeft, ARect.Top + (ARect.Height - LLine * 2) div 2 - Scale(1), ARect.Right - Scale(8),
      ARect.Top + (ARect.Height - LLine * 2) div 2 + LLine);
  Canvas.Font.Color := LFore;
  DrawText(Canvas.Handle, PChar(AHit.Caption), -1, LText,
    DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS or DT_NOPREFIX);
  if AHit.Path <> '' then
  begin
    LPath := Rect(LLeft, LText.Bottom + Scale(1), LText.Right, LText.Bottom + LLine + Scale(1));
    Canvas.Font.Color := LDim;
    DrawText(Canvas.Handle, PChar(AHit.Path), -1, LPath,
      DT_SINGLELINE or DT_VCENTER or DT_PATH_ELLIPSIS or DT_NOPREFIX);
  end;
  Canvas.Brush.Style := bsSolid;
end;

procedure TRadSearchPopup.Paint;
var
  I, LTop: Integer;
  LRect: TRect;
begin
  Canvas.Brush.Color := ContentColor;
  Canvas.FillRect(ClientRect);
  if not Assigned(FPainter) then
    FPainter := RootLookAndFeel.Painter;
  LTop := 0;
  for I := FTopRow to High(FRows) do
  begin
    if LTop >= ClientHeight then
      Break;
    LRect := Rect(0, LTop, ClientWidth, LTop + RowHeight(I));
    if FRows[I].IsHeader then
      PaintHeader(LRect, FRows[I].Text)
    else
      PaintItem(LRect, FHits[FRows[I].HitIndex], I = FRowIndex);
    LTop := LRect.Bottom;
  end;
end;

procedure TRadSearchPopup.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  LRow: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  LRow := RowAt(Y);
  if (LRow >= 0) and not FRows[LRow].IsHeader and (LRow <> FRowIndex) then
  begin
    FRowIndex := LRow;
    Invalidate;
  end;
end;

procedure TRadSearchPopup.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  LRow: Integer;
  LHit: TRadSearchHit;
begin
  inherited MouseUp(Button, Shift, X, Y);
  LRow := RowAt(Y);
  if (Button = mbLeft) and (LRow >= 0) and not FRows[LRow].IsHeader then
  begin
    FRowIndex := LRow;
    if Selected(LHit) and Assigned(FOnPick) then
      FOnPick(Self, LHit);
  end;
end;

function TRadSearchPopup.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := True;
  if WheelDelta < 0 then
    FTopRow := Min(FTopRow + 1, Max(0, Length(FRows) - FMaxRows))
  else
    FTopRow := Max(FTopRow - 1, 0);
  Invalidate;
end;

{ TRadSearchBox }

constructor TRadSearchBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FFrequentCaption := 'Sık Kullanılanlar';
  FFrequentCount := 8;
  FPopup := TRadSearchPopup.Create(Self);
  FPopup.OnPick := PopupPick;
  FAppEvents := TApplicationEvents.Create(Self);
  FAppEvents.OnDeactivate := AppDeactivate;
end;

destructor TRadSearchBox.Destroy;
begin
  Coz;
  inherited Destroy;
end;

procedure TRadSearchBox.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FEdit) then
  begin
    FPopup.HidePopup;
    FEdit := nil;
  end;
end;

procedure TRadSearchBox.Bagla(AEdit: TcxCustomTextEdit; AEngine: TRadSearchEngine; AImages: TCustomImageList);
begin
  if not Assigned(AEdit) then
    raise EArgumentNilException.Create('AEdit');
  if not Assigned(AEngine) then
    raise EArgumentNilException.Create('AEngine');
  Coz;
  FEdit := AEdit;
  FEngine := AEngine;
  FEdit.FreeNotification(Self);
  FPopup.Images := AImages;
  FPopup.Font.Assign(FEdit.Style.Font);
  FOldChange := TcxEditAccess(FEdit).Properties.OnChange;
  FOldKeyDown := FEdit.OnKeyDown;
  FOldEnter := FEdit.OnEnter;
  FOldExit := FEdit.OnExit;
  FOldFocusChanged := FEdit.OnFocusChanged;
  TcxEditAccess(FEdit).Properties.OnChange := EditChange;
  FEdit.OnKeyDown := EditKeyDown;
  FEdit.OnEnter := EditEnter;
  FEdit.OnExit := EditExit;
  FEdit.OnFocusChanged := EditFocusChanged;
end;

procedure TRadSearchBox.Coz;
begin
  FPopup.HidePopup;
  if not Assigned(FEdit) then
    Exit;
  TcxEditAccess(FEdit).Properties.OnChange := FOldChange;
  FEdit.OnKeyDown := FOldKeyDown;
  FEdit.OnEnter := FOldEnter;
  FEdit.OnExit := FOldExit;
  FEdit.OnFocusChanged := FOldFocusChanged;
  FEdit.RemoveFreeNotification(Self);
  FEdit := nil;
  FEngine := nil;
end;

procedure TRadSearchBox.Odakla;
begin
  if not Assigned(FEdit) or not FEdit.CanFocus then
    Exit;
  FEdit.SetFocus;
  FEdit.SelectAll;
  Refresh;
end;

function TRadSearchBox.GroupCaption(const AProvider: string): string;
begin
  Result := FEngine.CaptionOf(AProvider);
end;

procedure TRadSearchBox.Refresh;
var
  LText: string;
  LAnchor: TRect;
begin
  if not Assigned(FEdit) or not FEdit.Focused then
    Exit;
  LText := FEdit.EditingText;
  if Trim(LText) = '' then
    FPopup.Fill(FEngine.Frequent(FFrequentCount), GroupCaption, FFrequentCaption)
  else
    FPopup.Fill(FEngine.Search(LText), GroupCaption);
  FPopup.Painter := FEdit.Style.LookAndFeel.Painter;
  FPopup.PPI := FEdit.CurrentPPI;
  LAnchor := FEdit.BoundsRect;
  LAnchor.TopLeft := FEdit.Parent.ClientToScreen(LAnchor.TopLeft);
  LAnchor.BottomRight := FEdit.Parent.ClientToScreen(LAnchor.BottomRight);
  FPopup.ShowAt(LAnchor, MulDiv(380, FEdit.CurrentPPI, 96), GetAncestor(FEdit.Handle, GA_ROOT));
end;

procedure TRadSearchBox.ClearText;
begin
  FUpdating := True;
  try
    FEdit.EditingText := '';
  finally
    FUpdating := False;
  end;
end;

procedure TRadSearchBox.PopupPick(Sender: TObject; const AHit: TRadSearchHit);
var
  LHit: TRadSearchHit;
  LEngine: TRadSearchEngine;
  LCalistir: TThreadProcedure;
begin
  LHit := AHit;
  LEngine := FEngine;
  FPopup.HidePopup;
  ClearText;
  // Klavye/fare olayı bittikten sonra çalışır; açılan form odağı bu olayın ortasında almaz.
  LCalistir :=
    procedure
    begin
      LEngine.Execute(LHit);
    end;
  TThread.ForceQueue(nil, LCalistir);
end;

procedure TRadSearchBox.EditChange(Sender: TObject);
begin
  if Assigned(FOldChange) then
    FOldChange(Sender);
  if not FUpdating then
    Refresh;
end;

procedure TRadSearchBox.EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  LHit: TRadSearchHit;
begin
  if Assigned(FOldKeyDown) then
    FOldKeyDown(Sender, Key, Shift);
  if Shift * [ssCtrl, ssAlt] <> [] then
    Exit;
  case Key of
    VK_DOWN, VK_UP, VK_NEXT, VK_PRIOR:
      begin
        if not FPopup.Shown then
          Refresh
        else
          case Key of
            VK_DOWN: FPopup.Move(1);
            VK_UP: FPopup.Move(-1);
            VK_NEXT: FPopup.Move(FPopup.PageRows);
            VK_PRIOR: FPopup.Move(-FPopup.PageRows);
          end;
        Key := 0;
      end;
    VK_RETURN:
      begin
        if FPopup.Shown and FPopup.Selected(LHit) then
          PopupPick(FPopup, LHit);
        Key := 0;
      end;
    VK_ESCAPE:
      if FPopup.Shown then
      begin
        FPopup.HidePopup;
        Key := 0;
      end
      else if FEdit.EditingText <> '' then
      begin
        ClearText;
        Key := 0;
      end;
  end;
end;

procedure TRadSearchBox.EditEnter(Sender: TObject);
begin
  if Assigned(FOldEnter) then
    FOldEnter(Sender);
  Refresh;
end;

procedure TRadSearchBox.EditExit(Sender: TObject);
begin
  if Assigned(FOldExit) then
    FOldExit(Sender);
  FPopup.HidePopup;
end;

procedure TRadSearchBox.EditFocusChanged(Sender: TObject);
begin
  if Assigned(FOldFocusChanged) then
    FOldFocusChanged(Sender);
  // OnExit yalnız form içi odak değişiminde gelir; başka bir pencere (modal form, başka uygulama)
  // odağı alınca da liste kapanmalı.
  if Assigned(FEdit) and not FEdit.Focused then
    FPopup.HidePopup;
end;

procedure TRadSearchBox.AppDeactivate(Sender: TObject);
begin
  FPopup.HidePopup;
end;

end.
