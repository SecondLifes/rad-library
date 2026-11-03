unit rad.formstate.core.Tests;

{ DUnitX tests of rad.formstate.core: fake TPersistent classes, no VCL, no files. }

interface

uses
  System.SysUtils,
  System.Classes,
  DUnitX.TestFramework,
  mormot.core.base,
  mormot.core.rtti,
  mormot.core.variants,
  rad.formstate.core;

type
  TProbeAlign = (paNone, paTop, paClient, paRight);
  TProbeAnchor = (pnLeft, pnTop, pnRight, pnBottom);
  TProbeAnchors = set of TProbeAnchor;
  TProbeStyle = (psBold, psItalic, psUnderline);
  TProbeStyles = set of TProbeStyle;

  EProbe = class(Exception);

  TProbeFont = class(TPersistent)
  private
    FName: string;
    FSize: Integer;
    FStyle: TProbeStyles;
  public
    procedure Assign(Source: TPersistent); override;
  published
    property Name: string read FName write FName;
    property Size: Integer read FSize write FSize;
    property Style: TProbeStyles read FStyle write FStyle;
  end;

  TProbeItem = class(TCollectionItem)
  private
    FWidth: Integer;
    FCaption: string;
  published
    property Width: Integer read FWidth write FWidth;
    property Caption: string read FCaption write FCaption;
  end;

  TProbeComp = class(TComponent)
  private
    FFont: TProbeFont;
    FGetterFont: TProbeFont;
    FLines: TStrings;
    FItems: TOwnedCollection;
    FAlign: TProbeAlign;
    FAnchors: TProbeAnchors;
    FCaption: string;
    FRatio: Double;
    FWhen: TDateTime;
    FWidth: Integer;
    FBoom: Integer;
    FRef: TComponent;
    FSetterCalls: Integer;
    function GetGetterFont: TProbeFont;
    procedure SetGetterFont(const AValue: TProbeFont);
    procedure SetFont(const AValue: TProbeFont);
    procedure SetLines(const AValue: TStrings);
    procedure SetItems(const AValue: TOwnedCollection);
    function GetAlign: TProbeAlign;
    procedure SetAlign(AValue: TProbeAlign);
    function GetAnchors: TProbeAnchors;
    procedure SetAnchors(AValue: TProbeAnchors);
    procedure SetBoom(AValue: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property SetterCalls: Integer read FSetterCalls;
  published
    property Font: TProbeFont read FFont write SetFont;
    property GetterFont: TProbeFont read GetGetterFont write SetGetterFont;
    property Lines: TStrings read FLines write SetLines;
    property Items: TOwnedCollection read FItems write SetItems;
    property Align: TProbeAlign read GetAlign write SetAlign;
    property Anchors: TProbeAnchors read GetAnchors write SetAnchors;
    property Caption: string read FCaption write FCaption;
    property Ratio: Double read FRatio write FRatio;
    property When: TDateTime read FWhen write FWhen;
    property Width: Integer read FWidth write FWidth;
    property Boom: Integer read FBoom write SetBoom;
    property Ref: TComponent read FRef write FRef;
  end;

  [TestFixture]
  TRadFormStateCoreTests = class
  private
    FComp: TProbeComp;
    FPaths: TStringList;
    procedure Fill;
    procedure Scramble;
    function Doc(const AJson: RawUtf8): IDocDict;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure Capture_AllLeafKinds_RoundTripsEveryValue;
    [Test]
    procedure Capture_TurkishText_KeepsCharacters;
    [Test]
    procedure Capture_UnsupportedLeaves_AreSkipped;
    [Test]
    procedure Capture_NoPaths_ReturnsEmptyObject;
    [Test]
    procedure Resolve_GetterClassStep_ReachesNestedInstance;
    [Test]
    procedure Resolve_CollectionIndexOutOfRange_ReturnsFalse;
    [Test]
    procedure Resolve_BareCollectionItem_ReturnsFalse;
    [Test]
    procedure Resolve_UnknownStep_ReturnsFalse;
    [Test]
    procedure Apply_KeyNotInPathList_IsNotApplied;
    [Test]
    procedure Apply_SetterRaises_KeepsGoingAndReportsPath;
    [Test]
    procedure Apply_NullForClassLeaf_RejectedAndInstanceKept;
    [Test]
    procedure Apply_UnresolvablePath_ReportsError;
    [Test]
    procedure Apply_GetterClassLeaf_WritesInPlaceWithoutSetter;
    [Test]
    procedure Apply_Scale_ChangesOnlyPixelLeaves;
    [Test]
    procedure IsPixelPath_LastStepDecides;
    [Test]
    procedure Doc_New_WritesHeader;
    [Test]
    procedure Doc_NewerSchema_IsNotSupported;
    [Test]
    procedure Doc_VersionMismatch_IsDetected;
    [Test]
    procedure Doc_MissingPpi_DefaultsTo96;
    [Test]
    procedure Key_Path_JoinsScopeAndName;
  end;

implementation

uses
  System.DateUtils,
  mormot.core.text,
  mormot.core.unicode;

const
  CAPTION_TR = 'Çığ Şükrü ÖĞÜ';
  WHEN_VALUE = 46329.5; // 2026-11-03 12:00

{ TProbeFont }

procedure TProbeFont.Assign(Source: TPersistent);
begin
  if Source is TProbeFont then
  begin
    FName := TProbeFont(Source).Name;
    FSize := TProbeFont(Source).Size;
    FStyle := TProbeFont(Source).Style;
  end
  else
    inherited;
end;

{ TProbeComp }

constructor TProbeComp.Create(AOwner: TComponent);
begin
  inherited;
  FFont := TProbeFont.Create;
  FGetterFont := TProbeFont.Create;
  FLines := TStringList.Create;
  FItems := TOwnedCollection.Create(Self, TProbeItem);
end;

destructor TProbeComp.Destroy;
begin
  FItems.Free;
  FLines.Free;
  FGetterFont.Free;
  FFont.Free;
  inherited;
end;

function TProbeComp.GetGetterFont: TProbeFont;
begin
  Result := FGetterFont;
end;

procedure TProbeComp.SetGetterFont(const AValue: TProbeFont);
begin
  Inc(FSetterCalls);
  FGetterFont.Assign(AValue);
end;

procedure TProbeComp.SetFont(const AValue: TProbeFont);
begin
  FFont.Assign(AValue);
end;

procedure TProbeComp.SetLines(const AValue: TStrings);
begin
  FLines.Assign(AValue);
end;

procedure TProbeComp.SetItems(const AValue: TOwnedCollection);
begin
  FItems.Assign(AValue);
end;

function TProbeComp.GetAlign: TProbeAlign;
begin
  Result := FAlign;
end;

procedure TProbeComp.SetAlign(AValue: TProbeAlign);
begin
  FAlign := AValue;
end;

function TProbeComp.GetAnchors: TProbeAnchors;
begin
  Result := FAnchors;
end;

procedure TProbeComp.SetAnchors(AValue: TProbeAnchors);
begin
  FAnchors := AValue;
end;

procedure TProbeComp.SetBoom(AValue: Integer);
const
  FORBIDDEN = 13;
begin
  if AValue = FORBIDDEN then
    raise EProbe.Create('forbidden value');
  FBoom := AValue;
end;

{ TRadFormStateCoreTests }

procedure TRadFormStateCoreTests.Setup;
begin
  FComp := TProbeComp.Create(nil);
  TProbeItem(FComp.Items.Add).Width := 10;
  TProbeItem(FComp.Items.Add).Width := 20;
  FPaths := TStringList.Create;
end;

procedure TRadFormStateCoreTests.TearDown;
begin
  FPaths.Free;
  FComp.Free;
end;

function TRadFormStateCoreTests.Doc(const AJson: RawUtf8): IDocDict;
begin
  Result := DocDict(AJson, mFastFloat);
end;

procedure TRadFormStateCoreTests.Fill;
begin
  FComp.Font.Name := 'Segoe UI';
  FComp.Font.Size := 13;
  FComp.Font.Style := [psBold, psUnderline];
  FComp.GetterFont.Size := 17;
  FComp.GetterFont.Style := [psItalic];
  FComp.Lines.Text := 'x'#13#10'yé';
  TProbeItem(FComp.Items.Items[1]).Width := 77;
  FComp.Align := paClient;
  FComp.Anchors := [pnLeft, pnBottom];
  FComp.Caption := CAPTION_TR;
  FComp.Ratio := 0.1;
  FComp.When := WHEN_VALUE;
  FComp.Width := 111;
end;

procedure TRadFormStateCoreTests.Scramble;
begin
  FComp.Font.Size := 8;
  FComp.Font.Style := [];
  FComp.GetterFont.Size := 8;
  FComp.GetterFont.Style := [];
  FComp.Lines.Clear;
  TProbeItem(FComp.Items.Items[1]).Width := 1;
  FComp.Align := paNone;
  FComp.Anchors := [];
  FComp.Caption := '';
  FComp.Ratio := 0;
  FComp.When := 0;
  FComp.Width := 0;
end;

procedure TRadFormStateCoreTests.Capture_AllLeafKinds_RoundTripsEveryValue;
var
  LJson: RawUtf8;
  LResult: TRadStateApplyResult;
begin
  FPaths.CommaText := 'Font.Size,Font.Style,GetterFont.Size,GetterFont.Style,Lines,Items.1.Width,' +
    'Align,Anchors,Caption,Ratio,When,Width';
  Fill;
  LJson := TRadStatePaths.Capture(FComp, FPaths);
  Scramble;
  LResult := TRadStatePaths.Apply(FComp, FPaths, Doc(LJson), TRadStateScale.None);
  Assert.AreEqual(0, Integer(Length(LResult.Errors)), Utf8ToString(RawUtf8ArrayToCsv(LResult.Errors)));
  Assert.AreEqual(FPaths.Count, LResult.Applied);
  Assert.AreEqual(13, FComp.Font.Size);
  Assert.IsTrue(FComp.Font.Style = [psBold, psUnderline], 'Font.Style');
  Assert.AreEqual(17, FComp.GetterFont.Size);
  Assert.IsTrue(FComp.GetterFont.Style = [psItalic], 'GetterFont.Style');
  Assert.AreEqual(2, FComp.Lines.Count);
  Assert.AreEqual('yé', FComp.Lines[1]);
  Assert.AreEqual(77, TProbeItem(FComp.Items.Items[1]).Width);
  Assert.AreEqual(Ord(paClient), Ord(FComp.Align));
  Assert.IsTrue(FComp.Anchors = [pnLeft, pnBottom], 'Anchors');
  Assert.AreEqual(CAPTION_TR, FComp.Caption);
  Assert.AreEqual(Double(0.1), FComp.Ratio, 1E-12);
  Assert.AreEqual(Double(WHEN_VALUE), Double(FComp.When), 1 / SecsPerDay);
  Assert.AreEqual(111, FComp.Width);
end;

procedure TRadFormStateCoreTests.Capture_TurkishText_KeepsCharacters;
var
  LDoc: IDocDict;
begin
  FPaths.Add('Caption');
  FComp.Caption := CAPTION_TR;
  LDoc := Doc(TRadStatePaths.Capture(FComp, FPaths));
  Assert.AreEqual(CAPTION_TR, LDoc.S['Caption']);
end;

procedure TRadFormStateCoreTests.Capture_UnsupportedLeaves_AreSkipped;
var
  LDoc: IDocDict;
  LRef: TComponent;
begin
  LRef := TComponent.Create(nil);
  try
    FComp.Ref := LRef;
    FPaths.CommaText := 'Ref,Items,Nope,Font.Nope,Width';
    LDoc := Doc(TRadStatePaths.Capture(FComp, FPaths));
    Assert.AreEqual(1, LDoc.Len, Utf8ToString(LDoc.Json));
    Assert.IsTrue(LDoc.Exists('Width'));
  finally
    FComp.Ref := nil;
    LRef.Free;
  end;
end;

procedure TRadFormStateCoreTests.Capture_NoPaths_ReturnsEmptyObject;
begin
  Assert.AreEqual('{}', Utf8ToString(TRadStatePaths.Capture(FComp, FPaths)));
end;

procedure TRadFormStateCoreTests.Resolve_GetterClassStep_ReachesNestedInstance;
var
  LInst: TObject;
  LProp: PRttiCustomProp;
begin
  Assert.IsTrue(TRadStatePaths.Resolve(FComp, 'GetterFont.Size', LInst, LProp));
  Assert.AreSame(FComp.GetterFont, LInst);
end;

procedure TRadFormStateCoreTests.Resolve_CollectionIndexOutOfRange_ReturnsFalse;
var
  LInst: TObject;
  LProp: PRttiCustomProp;
begin
  Assert.IsFalse(TRadStatePaths.Resolve(FComp, 'Items.5.Width', LInst, LProp));
  Assert.IsFalse(TRadStatePaths.Resolve(FComp, 'Items.-1.Width', LInst, LProp));
end;

procedure TRadFormStateCoreTests.Resolve_BareCollectionItem_ReturnsFalse;
var
  LInst: TObject;
  LProp: PRttiCustomProp;
begin
  Assert.IsFalse(TRadStatePaths.Resolve(FComp, 'Items.0', LInst, LProp));
end;

procedure TRadFormStateCoreTests.Resolve_UnknownStep_ReturnsFalse;
var
  LInst: TObject;
  LProp: PRttiCustomProp;
begin
  Assert.IsFalse(TRadStatePaths.Resolve(FComp, 'Font.Nope', LInst, LProp));
  Assert.IsFalse(TRadStatePaths.Resolve(FComp, 'Width.Size', LInst, LProp));
  Assert.IsFalse(TRadStatePaths.Resolve(FComp, '', LInst, LProp));
  Assert.IsFalse(TRadStatePaths.Resolve(FComp, 'Font..Size', LInst, LProp));
  Assert.IsFalse(TRadStatePaths.Resolve(nil, 'Width', LInst, LProp));
end;

procedure TRadFormStateCoreTests.Apply_KeyNotInPathList_IsNotApplied;
var
  LResult: TRadStateApplyResult;
begin
  FPaths.Add('Width');
  FComp.Name := 'Original';
  LResult := TRadStatePaths.Apply(FComp,
    FPaths, Doc('{"Width":5,"Caption":"hack","Name":"Hacked"}'), TRadStateScale.None);
  Assert.AreEqual(1, LResult.Applied);
  Assert.AreEqual(5, FComp.Width);
  Assert.AreEqual('', FComp.Caption);
  Assert.AreEqual('Original', FComp.Name);
end;

procedure TRadFormStateCoreTests.Apply_SetterRaises_KeepsGoingAndReportsPath;
var
  LResult: TRadStateApplyResult;
begin
  FPaths.CommaText := 'Boom,Width';
  LResult := TRadStatePaths.Apply(FComp, FPaths, Doc('{"Boom":13,"Width":9}'), TRadStateScale.None);
  Assert.AreEqual(1, LResult.Applied);
  Assert.AreEqual(9, FComp.Width);
  Assert.AreEqual(1, Integer(Length(LResult.Errors)));
  Assert.IsTrue(Pos('Boom', Utf8ToString(LResult.Errors[0])) = 1, Utf8ToString(LResult.Errors[0]));
end;

procedure TRadFormStateCoreTests.Apply_NullForClassLeaf_RejectedAndInstanceKept;
var
  LFont: TProbeFont;
  LResult: TRadStateApplyResult;
begin
  FPaths.CommaText := 'Font,Lines';
  LFont := FComp.Font;
  FComp.Font.Size := 12;
  LResult := TRadStatePaths.Apply(FComp, FPaths, Doc('{"Font":null,"Lines":null}'), TRadStateScale.None);
  Assert.AreEqual(0, LResult.Applied);
  Assert.AreEqual(2, Integer(Length(LResult.Errors)));
  Assert.AreSame(LFont, FComp.Font);
  Assert.AreEqual(12, FComp.Font.Size);
end;

procedure TRadFormStateCoreTests.Apply_UnresolvablePath_ReportsError;
var
  LResult: TRadStateApplyResult;
begin
  FPaths.Add('Items.9.Width');
  LResult := TRadStatePaths.Apply(FComp, FPaths, Doc('{"Items.9.Width":3}'), TRadStateScale.None);
  Assert.AreEqual(0, LResult.Applied);
  Assert.AreEqual(1, Integer(Length(LResult.Errors)));
end;

procedure TRadFormStateCoreTests.Apply_GetterClassLeaf_WritesInPlaceWithoutSetter;
var
  LResult: TRadStateApplyResult;
begin
  FPaths.Add('GetterFont');
  LResult := TRadStatePaths.Apply(FComp, FPaths,
    Doc('{"GetterFont":{"Size":21,"Style":["psBold"]}}'), TRadStateScale.None);
  Assert.AreEqual(1, LResult.Applied);
  Assert.AreEqual(21, FComp.GetterFont.Size);
  Assert.IsTrue(FComp.GetterFont.Style = [psBold]);
  Assert.AreEqual(0, FComp.SetterCalls);
end;

procedure TRadFormStateCoreTests.Apply_Scale_ChangesOnlyPixelLeaves;
var
  LResult: TRadStateApplyResult;
begin
  FPaths.CommaText := 'Width,Items.0.Width,Font.Size,Ratio';
  LResult := TRadStatePaths.Apply(FComp, FPaths,
    Doc('{"Width":100,"Items.0.Width":10,"Font.Size":9,"Ratio":2.5}'), TRadStateScale.Make(96, 144));
  Assert.AreEqual(4, LResult.Applied);
  Assert.AreEqual(150, FComp.Width);
  Assert.AreEqual(15, TProbeItem(FComp.Items.Items[0]).Width);
  Assert.AreEqual(9, FComp.Font.Size);
  Assert.AreEqual(Double(2.5), FComp.Ratio, 1E-12);
end;

procedure TRadFormStateCoreTests.IsPixelPath_LastStepDecides;
begin
  Assert.IsTrue(TRadStatePaths.IsPixelPath('Width'));
  Assert.IsTrue(TRadStatePaths.IsPixelPath('Panels.0.width'));
  Assert.IsTrue(TRadStatePaths.IsPixelPath('Splitter.ClientHeight'));
  Assert.IsFalse(TRadStatePaths.IsPixelPath('Width.Size'));
  Assert.IsFalse(TRadStatePaths.IsPixelPath('Font.Size'));
  Assert.IsFalse(TRadStatePaths.IsPixelPath(''));
end;

procedure TRadFormStateCoreTests.Doc_New_WritesHeader;
var
  LDoc: IDocDict;
begin
  LDoc := TRadStateDoc.New(TRadStateKey.Make('emrah', 'TLoginForm'), 'TLoginForm', 3, 144);
  Assert.AreEqual(RAD_STATE_SCHEMA, Integer(LDoc.I[RAD_STATE_FIELD_SCHEMA]));
  Assert.AreEqual(3, Integer(LDoc.I[RAD_STATE_FIELD_VERSION]));
  Assert.AreEqual('emrah\TLoginForm', LDoc.S[RAD_STATE_FIELD_KEY]);
  Assert.AreEqual(144, TRadStateDoc.Ppi(LDoc));
  Assert.IsTrue(TRadStateDoc.IsSupported(LDoc));
  Assert.IsTrue(Pos('"schema":1', Utf8ToString(LDoc.Json)) > 0, 'standard JSON keys');
end;

procedure TRadFormStateCoreTests.Doc_NewerSchema_IsNotSupported;
begin
  Assert.IsFalse(TRadStateDoc.IsSupported(Doc('{"schema":2}')));
  Assert.IsFalse(TRadStateDoc.IsSupported(Doc('{"version":1}')));
  Assert.IsFalse(TRadStateDoc.IsSupported(nil));
end;

procedure TRadFormStateCoreTests.Doc_VersionMismatch_IsDetected;
begin
  Assert.IsTrue(TRadStateDoc.VersionMatches(Doc('{"schema":1,"version":3}'), 3));
  Assert.IsFalse(TRadStateDoc.VersionMatches(Doc('{"schema":1,"version":2}'), 3));
  Assert.IsTrue(TRadStateDoc.VersionMatches(Doc('{"schema":1}'), 0));
end;

procedure TRadFormStateCoreTests.Doc_MissingPpi_DefaultsTo96;
begin
  Assert.AreEqual(RAD_STATE_DEFAULT_PPI, TRadStateDoc.Ppi(Doc('{"schema":1}')));
  Assert.AreEqual(RAD_STATE_DEFAULT_PPI, TRadStateDoc.Ppi(Doc('{"ppi":0}')));
end;

procedure TRadFormStateCoreTests.Key_Path_JoinsScopeAndName;
begin
  Assert.AreEqual('emrah\TLoginForm', Utf8ToString(TRadStateKey.Make('emrah', 'TLoginForm').Path));
  Assert.AreEqual('TLoginForm', Utf8ToString(TRadStateKey.Make('', 'TLoginForm').Path));
end;

initialization
  TDUnitX.RegisterTestFixture(TRadFormStateCoreTests);

end.
