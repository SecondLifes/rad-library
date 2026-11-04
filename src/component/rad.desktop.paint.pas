unit rad.desktop.paint;

(* Theme and GDI+ drawing primitives of the ERP desktop (docs/specs/rad.desktop.md). RTL GDI+ only
   (Winapi.GDIPOBJ): software rendering, no GPU, no extra DLL, the same on a shared RDS server. *)

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Types,
  System.UITypes,
  Vcl.Graphics,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ;

type
  TRadDeskThemeKind = (tkDark, tkLight);

  /// <summary>Colors are ARGB. Accents is the palette offered for groups.</summary>
  TRadDeskTheme = record
    Kind: TRadDeskThemeKind;
    WallTop: Cardinal;
    WallBottom: Cardinal;
    WallGlow1: Cardinal;
    WallGlow2: Cardinal;
    GlassTint: Cardinal;
    GlassBorder: Cardinal;
    GlassHighlight: Cardinal;
    Shadow: Cardinal;
    Title: Cardinal;
    Text: Cardinal;
    SubText: Cardinal;
    Hover: Cardinal;
    Pressed: Cardinal;
    Focus: Cardinal;
    DropTarget: Cardinal;
    Broken: Cardinal;
    Up: Cardinal;
    Down: Cardinal;
    Accents: TArray<Cardinal>;
    class function Dark: TRadDeskTheme; static;
    class function Light: TRadDeskTheme; static;
    class function ForKind(AKind: TRadDeskThemeKind): TRadDeskTheme; static;
    /// <summary>AColor, or the accent picked by AIndex when AColor is 0.</summary>
    function Accent(AColor: Cardinal; AIndex: Integer): Cardinal;
  end;

  /// <summary>Stateless GDI+ helpers. Every rectangle is in device pixels.</summary>
  TRadDeskDraw = class abstract
  public
    class function Argb(A, R, G, B: Byte): Cardinal; static; inline;
    class function WithAlpha(AColor: Cardinal; AAlpha: Byte): Cardinal; static; inline;
    /// <summary>Mixes toward white (AAmount &gt; 0) or black (&lt; 0), -1..1.</summary>
    class function Shade(AColor: Cardinal; AAmount: Single): Cardinal; static;
    class function FromColor(AColor: TColor; AAlpha: Byte = 255): Cardinal; static;
    class function ToColor(AArgb: Cardinal): TColor; static;
    class function RectF(const ARect: TRect): TGPRectF; static; inline;
    /// <summary>Caller frees.</summary>
    class function RoundPath(const ARect: TGPRectF; ARadius: Single): TGPGraphicsPath; static;
    class procedure FillRound(G: TGPGraphics; const ARect: TGPRectF; ARadius: Single; AColor: Cardinal); static;
    class procedure StrokeRound(G: TGPGraphics; const ARect: TGPRectF; ARadius, AWidth: Single;
      AColor: Cardinal); static;
    /// <summary>Soft shadow from stacked translucent rounded rectangles; cheap and DPI-proportional.</summary>
    class procedure Shadow(G: TGPGraphics; const ARect: TGPRectF; ARadius, ASize: Single; AColor: Cardinal); static;
    /// <summary>Frosted glass: blurred backdrop clipped to the shape, tint, highlight edge.</summary>
    class procedure Glass(G: TGPGraphics; ABackdrop: TGPBitmap; const ARect: TGPRectF; ARadius: Single;
      const ATheme: TRadDeskTheme; ATint: Cardinal); static;
    /// <summary>Vector folder: back tab and gradient front sheet in AColor.</summary>
    class procedure Folder(G: TGPGraphics; const ARect: TGPRectF; AColor: Cardinal); static;
    /// <summary>Rounded square with the first letter of ACaption: icon of a command without an image.</summary>
    class procedure Monogram(G: TGPGraphics; const ARect: TGPRectF; const ACaption: string;
      AColor: Cardinal; const AFontName: string); static;
    /// <summary>Three ascending bars: the dashboard glyph.</summary>
    class procedure Bars(G: TGPGraphics; const ARect: TGPRectF; AColor: Cardinal); static;
    class procedure Triangle(G: TGPGraphics; const ARect: TGPRectF; AUp: Boolean; AColor: Cardinal); static;
    /// <summary>Line + area chart of AValues inside ARect.</summary>
    class procedure Sparkline(G: TGPGraphics; const ARect: TGPRectF; const AValues: TArray<Double>;
      AColor: Cardinal); static;
    class procedure Text(G: TGPGraphics; const AText, AFontName: string; ASize: Single; AStyle: Integer;
      const ARect: TGPRectF; AColor: Cardinal; AAlign, ALineAlign: TStringAlignment; AWrap: Boolean); static;
    /// <summary>One-line width of AText in pixels.</summary>
    class function TextWidth(G: TGPGraphics; const AText, AFontName: string; ASize: Single; AStyle: Integer): Single; static;
    /// <summary>Largest size from AMax down to AMin (step 1px) at which AText fits AWidth on one line.</summary>
    class function FitSize(G: TGPGraphics; const AText, AFontName: string; AMax, AMin: Single; AStyle: Integer;
      AWidth: Single): Single; static;
    /// <summary>Procedural wallpaper: vertical gradient and two soft radial glows.</summary>
    class procedure Wallpaper(G: TGPGraphics; const ARect: TGPRectF; const ATheme: TRadDeskTheme); static;
    /// <summary>Blur by downscaling 1/AFactor and scaling back with bicubic filtering. Caller frees.</summary>
    class function Blurred(ASource: TGPBitmap; AFactor: Integer): TGPBitmap; static;
    /// <summary>Anti-aliased, ClearType text, half-pixel offset.</summary>
    class procedure Prepare(G: TGPGraphics); static;
  end;

implementation

uses
  System.Math;

const
  CShadowSteps = 6;
  CMonogramFontRatio = 0.48;

{ TRadDeskTheme }

class function TRadDeskTheme.Dark: TRadDeskTheme;
begin
  Result := Default(TRadDeskTheme);
  Result.Kind := tkDark;
  Result.WallTop := $FF0B1E33;
  Result.WallBottom := $FF123A4E;
  Result.WallGlow1 := $802E7DD7;
  Result.WallGlow2 := $6024B39B;
  Result.GlassTint := $26FFFFFF;
  Result.GlassBorder := $40FFFFFF;
  Result.GlassHighlight := $30FFFFFF;
  Result.Shadow := $FF000000;
  Result.Title := $FFF4F7FB;
  Result.Text := $FFEFF3F8;
  Result.SubText := $B0E2E8F0;
  Result.Hover := $2EFFFFFF;
  Result.Pressed := $46FFFFFF;
  Result.Focus := $FF7CC4FF;
  Result.DropTarget := $5A7CC4FF;
  Result.Broken := $FFFFB86B;
  Result.Up := $FF5BD69A;
  Result.Down := $FFFF7A85;
  Result.Accents := [$FF3B82F6, $FF10B981, $FFF59E0B, $FFEF4444, $FF8B5CF6, $FFEC4899,
    $FF14B8A6, $FF64748B];
end;

class function TRadDeskTheme.Light: TRadDeskTheme;
begin
  Result := Dark;
  Result.Kind := tkLight;
  Result.WallTop := $FFE8EFF8;
  Result.WallBottom := $FFD5E2F0;
  Result.WallGlow1 := $70A5C8FF;
  Result.WallGlow2 := $60B5F0DD;
  Result.GlassTint := $8CFFFFFF;
  Result.GlassBorder := $B0FFFFFF;
  Result.GlassHighlight := $C0FFFFFF;
  Result.Shadow := $FF1E3A5F;
  Result.Title := $FF16243A;
  Result.Text := $FF1B2A41;
  Result.SubText := $B0475569;
  Result.Hover := $1E1E3A5F;
  Result.Pressed := $301E3A5F;
  Result.Focus := $FF2563EB;
  Result.DropTarget := $402563EB;
  Result.Broken := $FFB45309;
  Result.Up := $FF15803D;
  Result.Down := $FFB91C1C;
end;

class function TRadDeskTheme.ForKind(AKind: TRadDeskThemeKind): TRadDeskTheme;
begin
  if AKind = tkLight then
    Result := Light
  else
    Result := Dark;
end;

function TRadDeskTheme.Accent(AColor: Cardinal; AIndex: Integer): Cardinal;
begin
  if (AColor <> 0) or (Length(Accents) = 0) then
    Result := AColor
  else
    Result := Accents[Abs(AIndex) mod Length(Accents)];
end;

{ TRadDeskDraw }

class function TRadDeskDraw.Argb(A, R, G, B: Byte): Cardinal;
begin
  Result := (Cardinal(A) shl 24) or (Cardinal(R) shl 16) or (Cardinal(G) shl 8) or B;
end;

class function TRadDeskDraw.WithAlpha(AColor: Cardinal; AAlpha: Byte): Cardinal;
begin
  Result := (AColor and $00FFFFFF) or (Cardinal(AAlpha) shl 24);
end;

class function TRadDeskDraw.Shade(AColor: Cardinal; AAmount: Single): Cardinal;

  function Mix(AChannel: Byte): Byte;
  begin
    if AAmount >= 0 then
      Result := Round(AChannel + (255 - AChannel) * Min(AAmount, 1))
    else
      Result := Round(AChannel * (1 + Max(AAmount, -1)));
  end;

begin
  Result := Argb(AColor shr 24, Mix(Byte(AColor shr 16)), Mix(Byte(AColor shr 8)), Mix(Byte(AColor)));
end;

class function TRadDeskDraw.FromColor(AColor: TColor; AAlpha: Byte): Cardinal;
var
  LRgb: Cardinal;
begin
  LRgb := Cardinal(ColorToRGB(AColor));
  Result := Argb(AAlpha, GetRValue(LRgb), GetGValue(LRgb), GetBValue(LRgb));
end;

class function TRadDeskDraw.ToColor(AArgb: Cardinal): TColor;
begin
  Result := TColor(RGB(Byte(AArgb shr 16), Byte(AArgb shr 8), Byte(AArgb)));
end;

class function TRadDeskDraw.RectF(const ARect: TRect): TGPRectF;
begin
  Result := MakeRect(Single(ARect.Left), ARect.Top, ARect.Width, ARect.Height);
end;

class function TRadDeskDraw.RoundPath(const ARect: TGPRectF; ARadius: Single): TGPGraphicsPath;
var
  D: Single;
begin
  Result := TGPGraphicsPath.Create;
  D := Min(ARadius * 2, Min(ARect.Width, ARect.Height));
  if D <= 1 then
  begin
    Result.AddRectangle(ARect);
    Exit;
  end;
  Result.AddArc(ARect.X, ARect.Y, D, D, 180, 90);
  Result.AddArc(ARect.X + ARect.Width - D, ARect.Y, D, D, 270, 90);
  Result.AddArc(ARect.X + ARect.Width - D, ARect.Y + ARect.Height - D, D, D, 0, 90);
  Result.AddArc(ARect.X, ARect.Y + ARect.Height - D, D, D, 90, 90);
  Result.CloseFigure;
end;

class procedure TRadDeskDraw.FillRound(G: TGPGraphics; const ARect: TGPRectF; ARadius: Single; AColor: Cardinal);
var
  LPath: TGPGraphicsPath;
  LBrush: TGPSolidBrush;
begin
  LPath := RoundPath(ARect, ARadius);
  try
    LBrush := TGPSolidBrush.Create(AColor);
    try
      G.FillPath(LBrush, LPath);
    finally
      LBrush.Free;
    end;
  finally
    LPath.Free;
  end;
end;

class procedure TRadDeskDraw.StrokeRound(G: TGPGraphics; const ARect: TGPRectF; ARadius, AWidth: Single;
  AColor: Cardinal);
var
  LPath: TGPGraphicsPath;
  LPen: TGPPen;
begin
  LPath := RoundPath(ARect, ARadius);
  try
    LPen := TGPPen.Create(AColor, AWidth);
    try
      G.DrawPath(LPen, LPath);
    finally
      LPen.Free;
    end;
  finally
    LPath.Free;
  end;
end;

class procedure TRadDeskDraw.Shadow(G: TGPGraphics; const ARect: TGPRectF; ARadius, ASize: Single;
  AColor: Cardinal);
var
  I: Integer;
  LStep: Single;
  LRect: TGPRectF;
begin
  LStep := ASize / CShadowSteps;
  for I := CShadowSteps downto 1 do
  begin
    LRect := MakeRect(ARect.X - I * LStep * 0.6, ARect.Y - I * LStep * 0.3 + ASize * 0.35,
      ARect.Width + I * LStep * 1.2, ARect.Height + I * LStep * 1.2);
    FillRound(G, LRect, ARadius + I * LStep, WithAlpha(AColor, Round(36 / I)));
  end;
end;

class procedure TRadDeskDraw.Glass(G: TGPGraphics; ABackdrop: TGPBitmap; const ARect: TGPRectF;
  ARadius: Single; const ATheme: TRadDeskTheme; ATint: Cardinal);
var
  LPath: TGPGraphicsPath;
  LTexture: TGPTextureBrush;
  LTop: TGPRectF;
begin
  LPath := RoundPath(ARect, ARadius);
  try
    if Assigned(ABackdrop) then
    begin
      LTexture := TGPTextureBrush.Create(ABackdrop, WrapModeClamp);
      try
        G.FillPath(LTexture, LPath);
      finally
        LTexture.Free;
      end;
    end;
  finally
    LPath.Free;
  end;
  FillRound(G, ARect, ARadius, ATint);
  LTop := MakeRect(ARect.X, ARect.Y, ARect.Width, Min(ARect.Height, ARadius * 3));
  FillRound(G, LTop, ARadius, WithAlpha(ATheme.GlassHighlight, (ATheme.GlassHighlight shr 24) div 3));
  StrokeRound(G, ARect, ARadius, 1, ATheme.GlassBorder);
end;

class procedure TRadDeskDraw.Folder(G: TGPGraphics; const ARect: TGPRectF; AColor: Cardinal);
var
  LTab, LBody: TGPRectF;
  LPath: TGPGraphicsPath;
  LBrush: TGPLinearGradientBrush;
  R: Single;
begin
  R := ARect.Width * 0.08;
  LTab := MakeRect(ARect.X, ARect.Y + ARect.Height * 0.10, ARect.Width * 0.46, ARect.Height * 0.30);
  FillRound(G, LTab, R, Shade(AColor, -0.25));
  FillRound(G, MakeRect(ARect.X, ARect.Y + ARect.Height * 0.20, ARect.Width, ARect.Height * 0.72), R,
    Shade(AColor, -0.18));
  LBody := MakeRect(ARect.X, ARect.Y + ARect.Height * 0.30, ARect.Width, ARect.Height * 0.62);
  LPath := RoundPath(LBody, R);
  try
    LBrush := TGPLinearGradientBrush.Create(LBody, Shade(AColor, 0.25), AColor, LinearGradientModeVertical);
    try
      G.FillPath(LBrush, LPath);
    finally
      LBrush.Free;
    end;
  finally
    LPath.Free;
  end;
  StrokeRound(G, LBody, R, 1, WithAlpha($FFFFFFFF, 70));
end;

class procedure TRadDeskDraw.Monogram(G: TGPGraphics; const ARect: TGPRectF; const ACaption: string;
  AColor: Cardinal; const AFontName: string);
var
  LPath: TGPGraphicsPath;
  LBrush: TGPLinearGradientBrush;
  LLetter: string;
begin
  LPath := RoundPath(ARect, ARect.Width * 0.24);
  try
    LBrush := TGPLinearGradientBrush.Create(ARect, Shade(AColor, 0.18), Shade(AColor, -0.12),
      LinearGradientModeForwardDiagonal);
    try
      G.FillPath(LBrush, LPath);
    finally
      LBrush.Free;
    end;
  finally
    LPath.Free;
  end;
  StrokeRound(G, ARect, ARect.Width * 0.24, 1, WithAlpha($FFFFFFFF, 60));
  LLetter := ACaption.Replace('&', '').Trim;
  if LLetter <> '' then
    LLetter := LLetter.Substring(0, 1).ToUpper;
  Text(G, LLetter, AFontName, ARect.Height * CMonogramFontRatio, FontStyleBold, ARect, $FFFFFFFF,
    StringAlignmentCenter, StringAlignmentCenter, False);
end;

class procedure TRadDeskDraw.Bars(G: TGPGraphics; const ARect: TGPRectF; AColor: Cardinal);
var
  W: Single;
  I: Integer;
const
  CHeights: array[0..2] of Single = (0.45, 0.70, 1.0);
begin
  W := ARect.Width / 4;
  for I := 0 to 2 do
    FillRound(G, MakeRect(ARect.X + I * W * 1.4, ARect.Y + ARect.Height * (1 - CHeights[I]), W,
      ARect.Height * CHeights[I]), W * 0.25, Shade(AColor, 0.1 * I));
end;

class procedure TRadDeskDraw.Triangle(G: TGPGraphics; const ARect: TGPRectF; AUp: Boolean; AColor: Cardinal);
var
  LPoints: array[0..2] of TGPPointF;
  LBrush: TGPSolidBrush;
begin
  if AUp then
  begin
    LPoints[0] := MakePoint(ARect.X + ARect.Width / 2, ARect.Y);
    LPoints[1] := MakePoint(ARect.X + ARect.Width, ARect.Y + ARect.Height);
    LPoints[2] := MakePoint(ARect.X, ARect.Y + ARect.Height);
  end
  else
  begin
    LPoints[0] := MakePoint(ARect.X, ARect.Y);
    LPoints[1] := MakePoint(ARect.X + ARect.Width, ARect.Y);
    LPoints[2] := MakePoint(ARect.X + ARect.Width / 2, ARect.Y + ARect.Height);
  end;
  LBrush := TGPSolidBrush.Create(AColor);
  try
    G.FillPolygon(LBrush, PGPPointF(@LPoints[0]), 3);
  finally
    LBrush.Free;
  end;
end;

class procedure TRadDeskDraw.Sparkline(G: TGPGraphics; const ARect: TGPRectF; const AValues: TArray<Double>;
  AColor: Cardinal);
var
  LPoints: TArray<TGPPointF>;
  LLow, LHigh, LSpan: Double;
  I, N: Integer;
  LPen: TGPPen;
  LArea: TGPGraphicsPath;
  LBrush: TGPLinearGradientBrush;
begin
  N := Length(AValues);
  if N < 2 then
    Exit;
  LLow := MinValue(AValues);
  LHigh := MaxValue(AValues);
  LSpan := Max(LHigh - LLow, 1E-9);
  SetLength(LPoints, N);
  for I := 0 to N - 1 do
    LPoints[I] := MakePoint(ARect.X + ARect.Width * I / (N - 1),
      ARect.Y + ARect.Height * (1 - (AValues[I] - LLow) / LSpan));
  LArea := TGPGraphicsPath.Create;
  try
    LArea.AddLines(PGPPointF(@LPoints[0]), N);
    LArea.AddLine(LPoints[N - 1], MakePoint(ARect.X + ARect.Width, ARect.Y + ARect.Height));
    LArea.AddLine(MakePoint(ARect.X + ARect.Width, ARect.Y + ARect.Height), MakePoint(ARect.X, ARect.Y + ARect.Height));
    LArea.CloseFigure;
    LBrush := TGPLinearGradientBrush.Create(ARect, WithAlpha(AColor, 110), WithAlpha(AColor, 0),
      LinearGradientModeVertical);
    try
      G.FillPath(LBrush, LArea);
    finally
      LBrush.Free;
    end;
  finally
    LArea.Free;
  end;
  LPen := TGPPen.Create(AColor, 2);
  try
    G.DrawLines(LPen, PGPPointF(@LPoints[0]), N);
  finally
    LPen.Free;
  end;
end;

class procedure TRadDeskDraw.Text(G: TGPGraphics; const AText, AFontName: string; ASize: Single;
  AStyle: Integer; const ARect: TGPRectF; AColor: Cardinal; AAlign, ALineAlign: TStringAlignment;
  AWrap: Boolean);
var
  LFont: TGPFont;
  LFormat: TGPStringFormat;
  LBrush: TGPSolidBrush;
begin
  if (AText = '') or (ASize <= 0) then
    Exit;
  LFont := TGPFont.Create(AFontName, ASize, AStyle, UnitPixel);
  try
    if AWrap then
      LFormat := TGPStringFormat.Create(0)
    else
      LFormat := TGPStringFormat.Create(StringFormatFlagsNoWrap);
    try
      LFormat.SetAlignment(AAlign);
      LFormat.SetLineAlignment(ALineAlign);
      LFormat.SetTrimming(StringTrimmingEllipsisCharacter);
      LBrush := TGPSolidBrush.Create(AColor);
      try
        G.DrawString(AText, Length(AText), LFont, ARect, LFormat, LBrush);
      finally
        LBrush.Free;
      end;
    finally
      LFormat.Free;
    end;
  finally
    LFont.Free;
  end;
end;

class function TRadDeskDraw.TextWidth(G: TGPGraphics; const AText, AFontName: string; ASize: Single;
  AStyle: Integer): Single;
var
  LFont: TGPFont;
  LBox: TGPRectF;
begin
  LFont := TGPFont.Create(AFontName, ASize, AStyle, UnitPixel);
  try
    G.MeasureString(AText, Length(AText), LFont, MakePoint(0.0, 0.0), LBox);
    Result := LBox.Width;
  finally
    LFont.Free;
  end;
end;

class function TRadDeskDraw.FitSize(G: TGPGraphics; const AText, AFontName: string; AMax, AMin: Single;
  AStyle: Integer; AWidth: Single): Single;
begin
  Result := AMax;
  while Result > AMin do
  begin
    if TextWidth(G, AText, AFontName, Result, AStyle) <= AWidth then
      Exit;
    Result := Result - 1;
  end;
  Result := AMin;
end;

procedure Glow(G: TGPGraphics; CX, CY, R: Single; AColor: Cardinal);
var
  LPath: TGPGraphicsPath;
  LBrush: TGPPathGradientBrush;
  LCount: Integer;
  LSurround: TGPColor;
begin
  LPath := TGPGraphicsPath.Create;
  try
    LPath.AddEllipse(CX - R, CY - R, R * 2, R * 2);
    LBrush := TGPPathGradientBrush.Create(LPath);
    try
      LBrush.SetCenterColor(AColor);
      LSurround := TRadDeskDraw.WithAlpha(AColor, 0);
      LCount := 1;
      LBrush.SetSurroundColors(@LSurround, LCount);
      G.FillPath(LBrush, LPath);
    finally
      LBrush.Free;
    end;
  finally
    LPath.Free;
  end;
end;

class procedure TRadDeskDraw.Wallpaper(G: TGPGraphics; const ARect: TGPRectF; const ATheme: TRadDeskTheme);
var
  LBrush: TGPLinearGradientBrush;
  LSide: Single;
begin
  LBrush := TGPLinearGradientBrush.Create(MakeRect(ARect.X, ARect.Y - 1, ARect.Width, ARect.Height + 2),
    ATheme.WallTop, ATheme.WallBottom, LinearGradientModeVertical);
  try
    G.FillRectangle(LBrush, ARect);
  finally
    LBrush.Free;
  end;
  LSide := Max(ARect.Width, ARect.Height);
  Glow(G, ARect.X + ARect.Width * 0.78, ARect.Y + ARect.Height * 0.18, LSide * 0.55, ATheme.WallGlow1);
  Glow(G, ARect.X + ARect.Width * 0.12, ARect.Y + ARect.Height * 0.95, LSide * 0.45, ATheme.WallGlow2);
end;

class function TRadDeskDraw.Blurred(ASource: TGPBitmap; AFactor: Integer): TGPBitmap;
var
  LSmall: TGPBitmap;
  G: TGPGraphics;
  W, H: Integer;
begin
  W := Max(1, Integer(ASource.GetWidth) div Max(1, AFactor));
  H := Max(1, Integer(ASource.GetHeight) div Max(1, AFactor));
  LSmall := TGPBitmap.Create(W, H, PixelFormat32bppARGB);
  try
    G := TGPGraphics.Create(LSmall);
    try
      G.SetInterpolationMode(InterpolationModeHighQualityBilinear);
      G.DrawImage(ASource, 0, 0, W, H);
    finally
      G.Free;
    end;
    Result := TGPBitmap.Create(Integer(ASource.GetWidth), Integer(ASource.GetHeight), PixelFormat32bppARGB);
    G := TGPGraphics.Create(Result);
    try
      G.SetInterpolationMode(InterpolationModeHighQualityBicubic);
      G.SetPixelOffsetMode(PixelOffsetModeHalf);
      G.DrawImage(LSmall, MakeRect(-1.0, -1.0, ASource.GetWidth + 2, ASource.GetHeight + 2),
        0, 0, W, H, UnitPixel);
    finally
      G.Free;
    end;
  finally
    LSmall.Free;
  end;
end;

class procedure TRadDeskDraw.Prepare(G: TGPGraphics);
begin
  G.SetSmoothingMode(SmoothingModeAntiAlias);
  G.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);
  G.SetPixelOffsetMode(PixelOffsetModeHalf);
  G.SetCompositingQuality(CompositingQualityHighQuality);
end;

end.
