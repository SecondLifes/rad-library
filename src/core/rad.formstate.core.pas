unit rad.formstate.core;

{ Path engine and document rules of the form-state system (docs/specs/rad.formstate.md).
  RTL + mORMot only: the VCL side lives in rad.formstate.component. }

interface

uses
  System.SysUtils,
  System.Classes,
  mormot.core.base,
  mormot.core.rtti,
  mormot.core.variants;

const
  RAD_STATE_SCHEMA = 1;
  RAD_STATE_DEFAULT_PPI = 96;
  RAD_STATE_KEY_SEPARATOR = '\';

  RAD_STATE_FIELD_SCHEMA = 'schema';
  RAD_STATE_FIELD_VERSION = 'version';
  RAD_STATE_FIELD_KEY = 'key';
  RAD_STATE_FIELD_CLASS = 'class';
  RAD_STATE_FIELD_PPI = 'ppi';
  RAD_STATE_FIELD_SAVED_AT = 'savedAt';

  RAD_STATE_SECTION_FORM = 'form';
  RAD_STATE_SECTION_PROPS = 'props';
  RAD_STATE_SECTION_VALUES = 'values';
  RAD_STATE_SECTION_CUSTOM = 'custom';

type
  /// <summary>Logical record key; each store maps it to its own file name or table row.</summary>
  TRadStateKey = record
    Scope: RawUtf8;
    Name: RawUtf8;
    /// <summary>Key from a scope (user, company) and a name (usually the owner's class name).</summary>
    class function Make(const AScope, AName: RawUtf8): TRadStateKey; static;
    /// <summary>Scope and name joined by a backslash, or the name alone without a scope.</summary>
    function Path: RawUtf8;
  end;

  /// <summary>Rescales pixel values saved at one PPI for another.</summary>
  TRadStateScale = record
    FromPpi: Integer;
    ToPpi: Integer;
    class function Make(AFromPpi, AToPpi: Integer): TRadStateScale; static;
    class function None: TRadStateScale; static;
    /// <summary>True when both PPIs are known and differ.</summary>
    function Active: Boolean;
    function Apply(AValue: Integer): Integer;
  end;

  /// <summary>Outcome of TRadStatePaths.Apply; Errors holds one 'path: reason' line per failure.</summary>
  TRadStateApplyResult = record
    Applied: Integer;
    Errors: TRawUtf8DynArray;
  end;

  /// <summary>Component that keeps state a property path cannot express.</summary>
  IRadStateful = interface
    ['{E51B1468-715E-4FA0-AA15-C5FAC12390C8}']
    procedure SaveState(const ADoc: IDocDict);
    procedure LoadState(const ADoc: IDocDict);
  end;

  /// <summary>Reads and writes published properties addressed by dotted paths.</summary>
  /// <remarks>A step is a property or a collection index ('Font.Size', 'Panels.0.Width'); class steps
  /// go through getters. TComponent references, whole collections and events are not leaves.</remarks>
  TRadStatePaths = class abstract
  public
    /// <summary>Finds the instance that owns the last step and that step's property.</summary>
    class function Resolve(ARoot: TObject; const APath: RawUtf8; out AInst: TObject;
      out AProp: PRttiCustomProp): Boolean; static;
    /// <summary>JSON object of every resolvable path: {"Font.Size":9,...}. Others are skipped.</summary>
    class function Capture(ARoot: TObject; const APaths: TStrings): RawUtf8; static;
    /// <summary>Writes the values of APaths found in AValues; keys not in APaths are never applied.</summary>
    class function Apply(ARoot: TObject; const APaths: TStrings; const AValues: IDocDict;
      const AScale: TRadStateScale): TRadStateApplyResult; static;
    /// <summary>True when the last step is a pixel size or position (Left, Width...).</summary>
    class function IsPixelPath(const APath: RawUtf8): Boolean; static;
  end;

  /// <summary>Header fields and sections of a saved state document.</summary>
  TRadStateDoc = class abstract
  public
    class function New(const AKey: TRadStateKey; const AClassName: RawUtf8;
      AVersion, APpi: Integer): IDocDict; static;
    /// <summary>False for a missing schema or one newer than RAD_STATE_SCHEMA.</summary>
    class function IsSupported(const ADoc: IDocDict): Boolean; static;
    /// <summary>A missing version counts as 0.</summary>
    class function VersionMatches(const ADoc: IDocDict; AVersion: Integer): Boolean; static;
    class function Ppi(const ADoc: IDocDict): Integer; static;
    /// <summary>The section by reference: valid only until a key is added to or removed from ADoc.</summary>
    class function Section(const ADoc: IDocDict; const AName: RawUtf8;
      out ASection: IDocDict): Boolean; static;
  end;

implementation

uses
  mormot.core.text,
  mormot.core.unicode,
  mormot.core.datetime,
  mormot.core.json;

const
  PIXEL_LEAVES: array[0..5] of RawUtf8 = ('Left', 'Top', 'Width', 'Height', 'ClientWidth', 'ClientHeight');
  // Standard JSON; mFastExtended would write the keys without quotes.
  STATE_DOC_MODEL = mFastFloat;
  ERR_PATH_NOT_FOUND = 'path not found';
  ERR_VALUE_REJECTED = 'value not accepted';

// JSONPARSER_TOLERANTOPTIONS is a typed constant, so it cannot seed a true constant (E2026).
function LoadOptions: TJsonParserOptions;
begin
  // Per mORMot's TJsonParserOption doc a null frees a nested instance unless told not to.
  // A class property with a setter must fail instead of loading a temporary instance
  // (verified-api-traps.md); ApplyLeaf also rejects null for a class leaf outright.
  Result := JSONPARSER_TOLERANTOPTIONS + [jpoNullDontReleaseObjectInstance, jpoSetterNoCreate];
end;

{ path walk }

function StepCollection(var AInst: TObject; const AToken: RawUtf8; out AHandled: Boolean): Boolean;
var
  LIndex: Integer;
begin
  AHandled := (AInst is TCollection) and ToInteger(AToken, LIndex);
  Result := AHandled and (LIndex >= 0) and (LIndex < TCollection(AInst).Count);
  if Result then
    AInst := TCollection(AInst).Items[LIndex];
end;

function StepProperty(var AInst: TObject; const AToken: RawUtf8; AIsLast: Boolean;
  out AProp: PRttiCustomProp): Boolean;
begin
  AProp := Rtti.RegisterClass(AInst).Props.Find(AToken);
  Result := (AProp <> nil) and (AProp^.Prop <> nil);
  if not Result or AIsLast then
    Exit;
  Result := AProp^.Value.Kind = rkClass;
  if Result then
  begin
    AInst := AProp^.Prop^.GetObjProp(AInst);
    Result := AInst <> nil;
  end;
end;

function IsLeafSupported(AInst: TObject; AProp: PRttiCustomProp): Boolean;
var
  LSub: TObject;
begin
  if AProp^.Value.Kind in [rkMethod, rkInterface] then
    Exit(False);
  if AProp^.Value.Kind <> rkClass then
    Exit(True);
  LSub := AProp^.Prop^.GetObjProp(AInst);
  Result := (LSub <> nil) and not (LSub is TComponent) and not (LSub is TCollection);
end;

{ capture }

procedure WriteLeaf(AWriter: TJsonWriter; const APath: RawUtf8; AInst: TObject; AProp: PRttiCustomProp);
begin
  AWriter.AddFieldName(APath);
  AProp^.AddValueJson(AWriter, AInst, [woEnumSetsAsText]);
  AWriter.AddComma;
end;

{ apply }

function LoadInto(AInst: TObject; const AJson: RawUtf8): Boolean;
var
  LBuffer: RawUtf8;
  LTarget: TObject;
begin
  LBuffer := AJson;
  UniqueRawUtf8(LBuffer); // JsonToObject parses in place
  LTarget := AInst;
  JsonToObject(LTarget, pointer(LBuffer), Result, nil, LoadOptions);
  Result := Result and (LTarget = AInst);
end;

function ApplyLeaf(AInst: TObject; AProp: PRttiCustomProp; const AValue: Variant): Boolean;
var
  LJson: RawUtf8;
begin
  Result := IsLeafSupported(AInst, AProp);
  if not Result then
    Exit;
  LJson := VariantSaveJson(AValue);
  if AProp^.Value.Kind = rkClass then
    // In place: going through the setter would load a temporary instance.
    Result := not VarIsEmptyOrNull(AValue) and LoadInto(AProp^.Prop^.GetObjProp(AInst), LJson)
  else
    Result := LoadInto(AInst, FormatUtf8('{"%":%}', [AProp^.Name, LJson]));
end;

procedure AddError(var AResult: TRadStateApplyResult; const APath, AReason: RawUtf8);
var
  LCount: Integer;
begin
  LCount := Length(AResult.Errors);
  SetLength(AResult.Errors, LCount + 1);
  AResult.Errors[LCount] := APath + ': ' + AReason;
end;

procedure ApplyPath(ARoot: TObject; const APath: RawUtf8; const AValue: Variant;
  var AResult: TRadStateApplyResult);
var
  LInst: TObject;
  LProp: PRttiCustomProp;
begin
  if not TRadStatePaths.Resolve(ARoot, APath, LInst, LProp) then
    AddError(AResult, APath, ERR_PATH_NOT_FOUND)
  else if ApplyLeaf(LInst, LProp, AValue) then
    Inc(AResult.Applied)
  else
    AddError(AResult, APath, ERR_VALUE_REJECTED);
end;

function ScaledValue(const APath: RawUtf8; const AValue: Variant; const AScale: TRadStateScale): Variant;
var
  LValue: Integer;
begin
  Result := AValue;
  if AScale.Active and TRadStatePaths.IsPixelPath(APath) and VariantToInteger(AValue, LValue) then
    Result := AScale.Apply(LValue);
end;

{ TRadStateKey }

class function TRadStateKey.Make(const AScope, AName: RawUtf8): TRadStateKey;
begin
  Result.Scope := AScope;
  Result.Name := AName;
end;

function TRadStateKey.Path: RawUtf8;
begin
  if Scope = '' then
    Result := Name
  else
    Result := Scope + RAD_STATE_KEY_SEPARATOR + Name;
end;

{ TRadStateScale }

class function TRadStateScale.Make(AFromPpi, AToPpi: Integer): TRadStateScale;
begin
  Result.FromPpi := AFromPpi;
  Result.ToPpi := AToPpi;
end;

class function TRadStateScale.None: TRadStateScale;
begin
  Result := Make(0, 0);
end;

function TRadStateScale.Active: Boolean;
begin
  Result := (FromPpi > 0) and (ToPpi > 0) and (FromPpi <> ToPpi);
end;

function TRadStateScale.Apply(AValue: Integer): Integer;
begin
  if Active then
    Result := Round(Int64(AValue) * ToPpi / FromPpi)
  else
    Result := AValue;
end;

{ TRadStatePaths }

class function TRadStatePaths.Resolve(ARoot: TObject; const APath: RawUtf8; out AInst: TObject;
  out AProp: PRttiCustomProp): Boolean;
var
  LCursor: PUtf8Char;
  LToken: RawUtf8;
  LHandled: Boolean;
begin
  Result := False;
  AInst := ARoot;
  AProp := nil;
  LCursor := pointer(APath);
  while (LCursor <> nil) and (AInst <> nil) do
  begin
    GetNextItem(LCursor, '.', LToken);
    if LToken = '' then
      Exit(False);
    Result := StepCollection(AInst, LToken, LHandled);
    if LHandled then
    begin
      if not Result or (LCursor = nil) then
        Exit(False); // a bare collection item is not a leaf
      Continue;
    end;
    Result := StepProperty(AInst, LToken, LCursor = nil, AProp);
    if not Result then
      Exit;
  end;
end;

class function TRadStatePaths.Capture(ARoot: TObject; const APaths: TStrings): RawUtf8;
var
  LWriter: TJsonWriter;
  LTemp: TTextWriterStackBuffer;
  I: Integer;
  LPath: RawUtf8;
  LInst: TObject;
  LProp: PRttiCustomProp;
begin
  LWriter := TJsonWriter.CreateOwnedStream(LTemp);
  try
    LWriter.Add('{');
    for I := 0 to APaths.Count - 1 do
    begin
      LPath := StringToUtf8(APaths[I]);
      if Resolve(ARoot, LPath, LInst, LProp) and IsLeafSupported(LInst, LProp) then
        WriteLeaf(LWriter, LPath, LInst, LProp);
    end;
    LWriter.CancelLastComma;
    LWriter.Add('}');
    LWriter.SetText(Result);
  finally
    LWriter.Free;
  end;
end;

class function TRadStatePaths.Apply(ARoot: TObject; const APaths: TStrings; const AValues: IDocDict;
  const AScale: TRadStateScale): TRadStateApplyResult;
var
  I: Integer;
  LPath: RawUtf8;
  LValue: Variant;
begin
  Result.Applied := 0;
  Result.Errors := nil;
  if AValues = nil then
    Exit;
  for I := 0 to APaths.Count - 1 do
  begin
    LPath := StringToUtf8(APaths[I]);
    if not AValues.Get(LPath, LValue) then
      Continue;
    try
      ApplyPath(ARoot, LPath, ScaledValue(LPath, LValue, AScale), Result);
    except
      // Boundary: a setter may raise anything; record it and keep restoring the rest.
      on E: Exception do
        AddError(Result, LPath, StringToUtf8(E.ClassName + ': ' + E.Message));
    end;
  end;
end;

class function TRadStatePaths.IsPixelPath(const APath: RawUtf8): Boolean;
var
  LStart: Integer;
  LLeaf: RawUtf8;
  I: Integer;
begin
  LStart := Length(APath);
  while (LStart > 0) and (APath[LStart] <> '.') do
    Dec(LStart);
  LLeaf := Copy(APath, LStart + 1, MaxInt);
  for I := Low(PIXEL_LEAVES) to High(PIXEL_LEAVES) do
    if IdemPropNameU(LLeaf, PIXEL_LEAVES[I]) then
      Exit(True);
  Result := False;
end;

{ TRadStateDoc }

class function TRadStateDoc.New(const AKey: TRadStateKey; const AClassName: RawUtf8;
  AVersion, APpi: Integer): IDocDict;
begin
  Result := DocDict(STATE_DOC_MODEL);
  Result.I[RAD_STATE_FIELD_SCHEMA] := RAD_STATE_SCHEMA;
  Result.I[RAD_STATE_FIELD_VERSION] := AVersion;
  Result.U[RAD_STATE_FIELD_KEY] := AKey.Path;
  Result.U[RAD_STATE_FIELD_CLASS] := AClassName;
  Result.I[RAD_STATE_FIELD_PPI] := APpi;
  Result.U[RAD_STATE_FIELD_SAVED_AT] := NowUtcToString(True, 'T') + 'Z';
end;

class function TRadStateDoc.IsSupported(const ADoc: IDocDict): Boolean;
var
  LSchema: Integer;
begin
  LSchema := 0;
  Result := (ADoc <> nil) and ADoc.Get(RAD_STATE_FIELD_SCHEMA, LSchema) and
    (LSchema >= 1) and (LSchema <= RAD_STATE_SCHEMA);
end;

class function TRadStateDoc.VersionMatches(const ADoc: IDocDict; AVersion: Integer): Boolean;
var
  LVersion: Integer;
begin
  LVersion := 0;
  if ADoc <> nil then
    ADoc.Get(RAD_STATE_FIELD_VERSION, LVersion);
  Result := LVersion = AVersion;
end;

class function TRadStateDoc.Ppi(const ADoc: IDocDict): Integer;
begin
  Result := 0;
  if (ADoc = nil) or not ADoc.Get(RAD_STATE_FIELD_PPI, Result) or (Result <= 0) then
    Result := RAD_STATE_DEFAULT_PPI;
end;

class function TRadStateDoc.Section(const ADoc: IDocDict; const AName: RawUtf8;
  out ASection: IDocDict): Boolean;
begin
  ASection := nil;
  Result := (ADoc <> nil) and ADoc.Get(AName, ASection);
end;

end.
