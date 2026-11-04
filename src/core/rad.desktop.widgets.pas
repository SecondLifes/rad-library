unit rad.desktop.widgets;

(* Widget data and providers of the ERP desktop (docs/specs/rad.desktop.md). A provider fills data;
   the view's templates draw it. A provider never paints, so a slow or broken one cannot damage the
   desktop: its error is shown on its own tile. RTL only. *)

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  rad.desktop.core;

type
  TRadDeskTrend = (dtNone, dtUp, dtDown);

  /// <summary>What a provider fills. Plain members only: scripts call these (no overloads, no defaults).</summary>
  TRadDeskWidgetData = class(TPersistent)
  private
    FTitle: string;
    FValue: string;
    FSubText: string;
    FTrend: TRadDeskTrend;
    FColor: Cardinal;
    FLines: TStrings;
    FPoints: TList<Double>;
    FError: string;
    FUpdated: TDateTime;
    FSettings: string;
    function GetPoint(AIndex: Integer): Double;
    function GetPointCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Assign(ASource: TPersistent); override;
    /// <summary>One row of a list widget.</summary>
    procedure AddLine(const AText: string);
    /// <summary>One value of the mini chart.</summary>
    procedure AddPoint(AValue: Double);
    /// <summary>Text of everything drawn; equal signatures need no repaint.</summary>
    function Signature: string;
    property Points[AIndex: Integer]: Double read GetPoint;
    property PointCount: Integer read GetPointCount;
    property Lines: TStrings read FLines;
  published
    property Title: string read FTitle write FTitle;
    /// <summary>The big text of a KPI tile ('₺1,2M').</summary>
    property Value: string read FValue write FValue;
    property SubText: string read FSubText write FSubText;
    property Trend: TRadDeskTrend read FTrend write FTrend;
    /// <summary>ARGB accent; 0 uses the group's color.</summary>
    property Color: Cardinal read FColor write FColor;
    /// <summary>Set by the desktop when Fetch raised; drawn instead of the content.</summary>
    property Error: string read FError write FError;
    property Updated: TDateTime read FUpdated write FUpdated;
    /// <summary>The item's own settings JSON, given to the provider before Fetch (read it from a script).</summary>
    property Settings: string read FSettings write FSettings;
  end;

  IRadDeskWidgetProvider = interface
    ['{2C7E9B14-5A3D-4F18-9E62-7D1B0A4C8F35}']
    function Id: string;
    function Caption: string;
    function DefaultSize: TRadDeskSize;
    /// <summary>Refresh period in milliseconds; 0 fetches once.</summary>
    function Interval: Integer;
    /// <summary>Called on the main thread; ASettings is the item's opaque JSON.</summary>
    procedure Fetch(const ASettings: string; AData: TRadDeskWidgetData);
  end;

  TRadDeskWidgets = class
  private
    FProviders: TList<IRadDeskWidgetProvider>;
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>Replaces a provider with the same id.</summary>
    procedure Add(const AProvider: IRadDeskWidgetProvider);
    procedure Remove(const AId: string);
    function Find(const AId: string): IRadDeskWidgetProvider;
    function All: TArray<IRadDeskWidgetProvider>;
    /// <summary>Fetches into AData; an exception becomes AData.Error and never escapes.</summary>
    class procedure SafeFetch(const AProvider: IRadDeskWidgetProvider; const ASettings: string;
      AData: TRadDeskWidgetData); static;
  end;

  /// <summary>Built-in provider 'clock': time as value, long date as subtext.</summary>
  TRadDeskClockWidget = class(TInterfacedObject, IRadDeskWidgetProvider)
  public
    function Id: string;
    function Caption: string;
    function DefaultSize: TRadDeskSize;
    function Interval: Integer;
    procedure Fetch(const ASettings: string; AData: TRadDeskWidgetData);
  end;

  /// <summary>Provider whose Fetch is an anonymous method; handy for hosts and tests.</summary>
  TRadDeskFuncWidget = class(TInterfacedObject, IRadDeskWidgetProvider)
  private
    FId: string;
    FCaption: string;
    FSize: TRadDeskSize;
    FInterval: Integer;
    FFetch: TProc<string, TRadDeskWidgetData>;
  public
    constructor Create(const AId, ACaption: string; ASize: TRadDeskSize; AInterval: Integer;
      const AFetch: TProc<string, TRadDeskWidgetData>);
    function Id: string;
    function Caption: string;
    function DefaultSize: TRadDeskSize;
    function Interval: Integer;
    procedure Fetch(const ASettings: string; AData: TRadDeskWidgetData);
  end;

implementation

const
  CClockInterval = 1000;

{ TRadDeskWidgetData }

constructor TRadDeskWidgetData.Create;
begin
  inherited Create;
  FLines := TStringList.Create;
  FPoints := TList<Double>.Create;
end;

destructor TRadDeskWidgetData.Destroy;
begin
  FPoints.Free;
  FLines.Free;
  inherited Destroy;
end;

procedure TRadDeskWidgetData.Clear;
begin
  FTitle := '';
  FValue := '';
  FSubText := '';
  FTrend := dtNone;
  FColor := 0;
  FError := '';
  FLines.Clear;
  FPoints.Clear;
end;

procedure TRadDeskWidgetData.Assign(ASource: TPersistent);
var
  LSrc: TRadDeskWidgetData;
begin
  if not (ASource is TRadDeskWidgetData) then
  begin
    inherited Assign(ASource);
    Exit;
  end;
  LSrc := TRadDeskWidgetData(ASource);
  FTitle := LSrc.FTitle;
  FValue := LSrc.FValue;
  FSubText := LSrc.FSubText;
  FTrend := LSrc.FTrend;
  FColor := LSrc.FColor;
  FError := LSrc.FError;
  FUpdated := LSrc.FUpdated;
  FSettings := LSrc.FSettings;
  FLines.Assign(LSrc.FLines);
  FPoints.Clear;
  FPoints.AddRange(LSrc.FPoints);
end;

procedure TRadDeskWidgetData.AddLine(const AText: string);
begin
  FLines.Add(AText);
end;

procedure TRadDeskWidgetData.AddPoint(AValue: Double);
begin
  FPoints.Add(AValue);
end;

function TRadDeskWidgetData.Signature: string;
var
  LPoint: Double;
  LBuilder: TStringBuilder;
begin
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.Append(FTitle).Append(#1).Append(FValue).Append(#1).Append(FSubText).Append(#1)
      .Append(Ord(FTrend)).Append(#1).Append(FColor).Append(#1).Append(FError).Append(#1).Append(FLines.Text);
    for LPoint in FPoints do
      LBuilder.Append(#1).Append(LPoint);
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function TRadDeskWidgetData.GetPoint(AIndex: Integer): Double;
begin
  Result := FPoints[AIndex];
end;

function TRadDeskWidgetData.GetPointCount: Integer;
begin
  Result := FPoints.Count;
end;

{ TRadDeskWidgets }

constructor TRadDeskWidgets.Create;
begin
  inherited Create;
  FProviders := TList<IRadDeskWidgetProvider>.Create;
end;

destructor TRadDeskWidgets.Destroy;
begin
  FProviders.Free;
  inherited Destroy;
end;

procedure TRadDeskWidgets.Add(const AProvider: IRadDeskWidgetProvider);
begin
  if not Assigned(AProvider) then
    raise EArgumentNilException.Create('AProvider');
  Remove(AProvider.Id);
  FProviders.Add(AProvider);
end;

procedure TRadDeskWidgets.Remove(const AId: string);
var
  I: Integer;
begin
  for I := FProviders.Count - 1 downto 0 do
    if SameText(FProviders[I].Id, AId) then
      FProviders.Delete(I);
end;

function TRadDeskWidgets.Find(const AId: string): IRadDeskWidgetProvider;
var
  LProvider: IRadDeskWidgetProvider;
begin
  for LProvider in FProviders do
    if SameText(LProvider.Id, AId) then
      Exit(LProvider);
  Result := nil;
end;

function TRadDeskWidgets.All: TArray<IRadDeskWidgetProvider>;
begin
  Result := FProviders.ToArray;
end;

class procedure TRadDeskWidgets.SafeFetch(const AProvider: IRadDeskWidgetProvider;
  const ASettings: string; AData: TRadDeskWidgetData);
begin
  AData.Clear;
  AData.Settings := ASettings;
  try
    AProvider.Fetch(ASettings, AData);
  except
    // Top-level boundary: one widget's failure is drawn on its tile and must not reach the host.
    on E: Exception do
    begin
      AData.Clear;
      AData.Error := E.Message;
    end;
  end;
  AData.Updated := Now;
end;

{ TRadDeskClockWidget }

function TRadDeskClockWidget.Id: string;
begin
  Result := 'clock';
end;

function TRadDeskClockWidget.Caption: string;
begin
  Result := 'Saat';
end;

function TRadDeskClockWidget.DefaultSize: TRadDeskSize;
begin
  Result := dsWide;
end;

function TRadDeskClockWidget.Interval: Integer;
begin
  Result := CClockInterval;
end;

procedure TRadDeskClockWidget.Fetch(const ASettings: string; AData: TRadDeskWidgetData);
begin
  AData.Title := Caption;
  AData.Value := FormatDateTime('hh:nn', Now);
  AData.SubText := FormatDateTime('dddd, d mmmm yyyy', Now);
end;

{ TRadDeskFuncWidget }

constructor TRadDeskFuncWidget.Create(const AId, ACaption: string; ASize: TRadDeskSize;
  AInterval: Integer; const AFetch: TProc<string, TRadDeskWidgetData>);
begin
  inherited Create;
  FId := AId;
  FCaption := ACaption;
  FSize := ASize;
  FInterval := AInterval;
  FFetch := AFetch;
end;

function TRadDeskFuncWidget.Id: string;
begin
  Result := FId;
end;

function TRadDeskFuncWidget.Caption: string;
begin
  Result := FCaption;
end;

function TRadDeskFuncWidget.DefaultSize: TRadDeskSize;
begin
  Result := FSize;
end;

function TRadDeskFuncWidget.Interval: Integer;
begin
  Result := FInterval;
end;

procedure TRadDeskFuncWidget.Fetch(const ASettings: string; AData: TRadDeskWidgetData);
begin
  if Assigned(FFetch) then
    FFetch(ASettings, AData);
end;

end.
