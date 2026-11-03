unit rad.formstate.rules;

{ Permission rules of TRadFormCustomizer (docs/specs/rad.formcustomizer.md): 'TControl: Left, Top'
  opens properties by class, '-Edit1' or '-TPanel: Color' closes them again; a closing line always wins.
  TypInfo only: the design-time preview runs this too, and mORMot's RTTI patches class VMTs. }

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

const
  /// <summary>Appearance only: geometry, captions, font, colour and hint. Never an edit's Text: that is data.</summary>
  RAD_CUSTOMIZE_APPEARANCE =
    'TControl: Left, Top, Width, Height, Hint, Font, Color' + sLineBreak +
    'TCustomLabel, TButtonControl, TCustomGroupBox, TCustomPanel: Caption' + sLineBreak +
    'TcxCustomButton, TcxCustomLabel, TcxCustomGroupBox, TcxCustomCheckBox: Caption' + sLineBreak +
    'TcxCustomEdit: Style.Color, Style.Font';

type
  TRadCustomizeRule = record
    Deny: Boolean;
    /// <summary>Class names (matching descendants too), component names or '*'.</summary>
    Targets: TArray<string>;
    /// <summary>Property paths; a closing rule without paths closes the whole component.</summary>
    Paths: TArray<string>;
  end;

  /// <summary>Parsed rule lines; turns them into the leaf property paths of one component.</summary>
  TRadCustomizeRules = class
  private
    FRules: TList<TRadCustomizeRule>;
    FErrors: TStrings;
    procedure ParseLine(const ALine: string; ALineNo: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>Adds the rules of AText (one per line); a bad line goes to Errors and is skipped.</summary>
    procedure Add(const AText: string);
    /// <summary>Adds the leaf paths the opening rules give AComponent.</summary>
    procedure AddAllowed(AComponent: TComponent; APaths: TStrings);
    /// <summary>Removes what the closing rules take from AComponent.</summary>
    procedure RemoveDenied(AComponent: TComponent; APaths: TStrings);
    /// <summary>What AComponent may change: the opening rules (controls only, unless AOpenRules is False)
    /// plus AExplicit (may be nil), minus the closing rules and Name.</summary>
    procedure PathsFor(AComponent: TComponent; const AExplicit: TStrings; APaths: TStrings;
      AOpenRules: Boolean = True);
    /// <summary>'*', the component's name, or the name of its class or an ancestor class.</summary>
    class function Matches(AComponent: TComponent; const ATarget: string): Boolean; static;
    /// <summary>APath and, for an object property, its writable leaves; nothing when APath does not exist.</summary>
    class procedure Expand(AObject: TObject; const APath: string; APaths: TStrings); static;
    property Errors: TStrings read FErrors;
  end;

implementation

uses
  System.TypInfo,
  System.StrUtils,
  Vcl.Graphics,
  Vcl.Controls;

resourcestring
  SRuleNoColon = '%d. satır: "Sınıf: özellik, özellik" bekleniyor: %s';
  SRuleNoTarget = '%d. satır: sınıf ya da bileşen adı yok: %s';
  SRuleNoPath = '%d. satır: özellik yok: %s';

const
  MAX_DEPTH = 3;
  PATH_SEPARATOR = '.';
  ANY_TARGET = '*';
  DENY_PREFIX = '-';
  // A renamed component would no longer match its saved changes or the code that names it.
  FORBIDDEN_PATH = 'Name';
  SKIPPED_KINDS = [tkMethod, tkInterface, tkPointer, tkArray, tkDynArray, tkRecord, tkMRecord, tkProcedure,
    tkClassRef];
  // Size covers Height; the others only change with the font itself.
  REDUNDANT_FONT_PROPS: array[0..4] of string = ('Height', 'Charset', 'Orientation', 'Pitch', 'Quality');

function SplitList(const AText: string): TArray<string>;
var
  LPart: string;
begin
  Result := nil;
  for LPart in AText.Split([',']) do
    if Trim(LPart) <> '' then
      Result := Result + [Trim(LPart)];
end;

function IsComment(const ALine: string): Boolean;
begin
  Result := (ALine = '') or ALine.StartsWith('//') or ALine.StartsWith(';');
end;

{ TRadCustomizeRules }

constructor TRadCustomizeRules.Create;
begin
  inherited Create;
  FRules := TList<TRadCustomizeRule>.Create;
  FErrors := TStringList.Create;
end;

destructor TRadCustomizeRules.Destroy;
begin
  FErrors.Free;
  FRules.Free;
  inherited;
end;

procedure TRadCustomizeRules.Add(const AText: string);
var
  LLines: TArray<string>;
  I: Integer;
begin
  LLines := AText.Split([#13#10, #10, #13]);
  for I := 0 to High(LLines) do
    ParseLine(Trim(LLines[I]), I + 1);
end;

procedure TRadCustomizeRules.ParseLine(const ALine: string; ALineNo: Integer);
var
  LRule: TRadCustomizeRule;
  LText: string;
  LColon, LDot: Integer;
begin
  if IsComment(ALine) then
    Exit;
  LRule.Deny := ALine.StartsWith(DENY_PREFIX);
  LText := Trim(Copy(ALine, 1 + Ord(LRule.Deny), MaxInt));
  LColon := Pos(':', LText);
  LDot := Pos(PATH_SEPARATOR, LText);
  if LColon > 0 then
  begin
    LRule.Targets := SplitList(Copy(LText, 1, LColon - 1));
    LRule.Paths := SplitList(Copy(LText, LColon + 1, MaxInt));
  end
  else if not LRule.Deny then
  begin
    FErrors.Add(Format(SRuleNoColon, [ALineNo, ALine]));
    Exit;
  end
  else if LDot > 0 then // -Edit1.Color
  begin
    LRule.Targets := [Trim(Copy(LText, 1, LDot - 1))];
    LRule.Paths := [Trim(Copy(LText, LDot + 1, MaxInt))];
  end
  else
  begin
    LRule.Targets := SplitList(LText);
    LRule.Paths := nil;
  end;
  if Length(LRule.Targets) = 0 then
    FErrors.Add(Format(SRuleNoTarget, [ALineNo, ALine]))
  else if not LRule.Deny and (Length(LRule.Paths) = 0) then
    FErrors.Add(Format(SRuleNoPath, [ALineNo, ALine]))
  else
    FRules.Add(LRule);
end;

class function TRadCustomizeRules.Matches(AComponent: TComponent; const ATarget: string): Boolean;
var
  LClass: TClass;
begin
  if (ATarget = ANY_TARGET) or SameText(AComponent.Name, ATarget) then
    Exit(True);
  LClass := AComponent.ClassType;
  while LClass <> nil do
  begin
    if SameText(LClass.ClassName, ATarget) then
      Exit(True);
    LClass := LClass.ClassParent;
  end;
  Result := False;
end;

function RuleMatches(const ARule: TRadCustomizeRule; AComponent: TComponent): Boolean;
var
  LTarget: string;
begin
  for LTarget in ARule.Targets do
    if TRadCustomizeRules.Matches(AComponent, LTarget) then
      Exit(True);
  Result := False;
end;

procedure AddLeaves(AObject: TObject; AInfo: PPropInfo; const APath: string; ADepth: Integer;
  APaths: TStrings); forward;

procedure AddChildLeaves(AChild: TObject; const APath: string; ADepth: Integer; APaths: TStrings);
var
  LList: PPropList;
  LCount, I: Integer;
begin
  LCount := GetPropList(AChild.ClassInfo, tkProperties, nil);
  if LCount = 0 then
    Exit;
  GetMem(LList, LCount * SizeOf(Pointer));
  try
    GetPropList(AChild.ClassInfo, tkProperties, LList, True);
    for I := 0 to LCount - 1 do
      if not ((AChild is TFont) and MatchText(string(LList^[I]^.Name), REDUNDANT_FONT_PROPS)) then
        AddLeaves(AChild, LList^[I], APath + PATH_SEPARATOR + string(LList^[I]^.Name), ADepth - 1, APaths);
  finally
    FreeMem(LList);
  end;
end;

procedure AddLeaves(AObject: TObject; AInfo: PPropInfo; const APath: string; ADepth: Integer;
  APaths: TStrings);
var
  LChild: TObject;
begin
  if AInfo^.PropType^.Kind in SKIPPED_KINDS then
    Exit;
  if AInfo^.PropType^.Kind <> tkClass then
  begin
    if (AInfo^.SetProc <> nil) and (APaths.IndexOf(APath) < 0) then
      APaths.Add(APath);
    Exit;
  end;
  LChild := GetObjectProp(AObject, AInfo);
  if (LChild = nil) or (LChild is TComponent) or (LChild is TCollection) then
    Exit; // references are not saved; collection items are reached by index only
  if LChild is TStrings then
  begin
    if (AInfo^.SetProc <> nil) and (APaths.IndexOf(APath) < 0) then
      APaths.Add(APath);
  end
  else if (LChild is TPersistent) and (ADepth > 0) then
    AddChildLeaves(LChild, APath, ADepth, APaths);
end;

class procedure TRadCustomizeRules.Expand(AObject: TObject; const APath: string; APaths: TStrings);
var
  LSegments: TArray<string>;
  LInfo: PPropInfo;
  LPath: string;
  I: Integer;
begin
  LSegments := APath.Split([PATH_SEPARATOR]);
  LPath := '';
  for I := 0 to High(LSegments) do
  begin
    LInfo := GetPropInfo(AObject, Trim(LSegments[I]));
    if LInfo = nil then
      Exit; // a class without the property: the rule simply does not apply to it
    LPath := IfThen(LPath = '', '', LPath + PATH_SEPARATOR) + string(LInfo^.Name);
    if I = High(LSegments) then
      AddLeaves(AObject, LInfo, LPath, MAX_DEPTH, APaths)
    else if LInfo^.PropType^.Kind = tkClass then
    begin
      AObject := GetObjectProp(AObject, LInfo);
      if AObject = nil then
        Exit;
    end
    else
      Exit;
  end;
end;

procedure TRadCustomizeRules.AddAllowed(AComponent: TComponent; APaths: TStrings);
var
  LRule: TRadCustomizeRule;
  LPath: string;
begin
  for LRule in FRules do
    if not LRule.Deny and RuleMatches(LRule, AComponent) then
      for LPath in LRule.Paths do
        Expand(AComponent, LPath, APaths);
end;

function IsUnder(const APath, APrefix: string): Boolean;
begin
  Result := SameText(APath, APrefix) or StartsText(APrefix + PATH_SEPARATOR, APath);
end;

procedure TRadCustomizeRules.RemoveDenied(AComponent: TComponent; APaths: TStrings);
var
  LRule: TRadCustomizeRule;
  LPath: string;
  I: Integer;
begin
  for LRule in FRules do
  begin
    if not LRule.Deny or not RuleMatches(LRule, AComponent) then
      Continue;
    if Length(LRule.Paths) = 0 then
    begin
      APaths.Clear;
      Exit;
    end;
    for LPath in LRule.Paths do
      for I := APaths.Count - 1 downto 0 do
        if IsUnder(APaths[I], LPath) then
          APaths.Delete(I);
  end;
end;

procedure TRadCustomizeRules.PathsFor(AComponent: TComponent; const AExplicit: TStrings; APaths: TStrings;
  AOpenRules: Boolean);
var
  LPath: string;
  I: Integer;
begin
  if AOpenRules and (AComponent is TControl) then
    AddAllowed(AComponent, APaths);
  if AExplicit <> nil then
    for I := 0 to AExplicit.Count - 1 do
    begin
      LPath := Trim(AExplicit[I]);
      if (LPath <> '') and (APaths.IndexOf(LPath) < 0) then
        APaths.Add(LPath);
    end;
  RemoveDenied(AComponent, APaths);
  I := APaths.IndexOf(FORBIDDEN_PATH);
  if I >= 0 then
    APaths.Delete(I);
end;

end.
