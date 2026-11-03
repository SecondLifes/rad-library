unit Rad.Editor.FormState.Model;

{ What the TRadPropertiesStore editor shows and edits, without any IDE or DevExpress unit.
  Uses TypInfo on purpose: mORMot's Rtti patches class VMTs, which design time must not do. }

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  rad.formstate.component;

type
  /// <summary>One property path of one component, as the editor lists it.</summary>
  TRadStateLeaf = record
    Component: TComponent;
    Path: string;
    TypeName: string;
    Value: string;
    Restorable: Boolean;
    /// <summary>Why the path cannot be restored; empty when it can.</summary>
    Reason: string;
    function Key: string;
  end;

  TRadStatePreset = (spPage, spSize);

  /// <summary>Owner components, their property paths, and the selection the store will save.</summary>
  TRadStateEditorModel = class
  private
    FStore: TRadPropertiesStore;
    FLeaves: TList<TRadStateLeaf>;
    FSelection: TStringList;
    procedure AddObject(AComponent: TComponent; AObject: TObject; const APrefix: string; ADepth: Integer);
    procedure AddProperty(AComponent: TComponent; AObject: TObject; APropInfo: Pointer;
      const APrefix: string; ADepth: Integer);
    procedure AddCollection(AComponent: TComponent; ACollection: TCollection; const APrefix: string;
      ADepth: Integer);
    procedure AddLeaf(AComponent: TComponent; const APath, ATypeName, AValue, AReason: string);
    function FindComponent(const AName: string): TComponent;
  public
    constructor Create(AStore: TRadPropertiesStore);
    destructor Destroy; override;
    /// <summary>Lists every component of the store's owner and its paths.</summary>
    procedure Build;
    /// <summary>Selection := the store's Items, in their order.</summary>
    procedure LoadFromStore;
    /// <summary>Items := the selection, one item per component in first-seen order.</summary>
    procedure SaveToStore;
    function IsSelected(AComponent: TComponent; const APath: string): Boolean;
    procedure SetSelected(AComponent: TComponent; const APath: string; ASelected: Boolean);
    /// <summary>Moves a selected entry up (ADelta = -1) or down (+1); False at either end.</summary>
    function MoveSelection(AIndex, ADelta: Integer): Boolean;
    /// <summary>The paths a preset picks for one component; empty when none apply.</summary>
    class function PresetPaths(AComponent: TComponent; APreset: TRadStatePreset): TArray<string>; static;
    /// <summary>Selects the preset's paths on every listed component; returns how many were added.</summary>
    function ApplyPreset(APreset: TRadStatePreset): Integer;
    function LeafOf(AComponent: TComponent; const APath: string; out ALeaf: TRadStateLeaf): Boolean;
    property Store: TRadPropertiesStore read FStore;
    property Leaves: TList<TRadStateLeaf> read FLeaves;
    /// <summary>Ordered keys 'Component.Path'.</summary>
    property Selection: TStringList read FSelection;
  end;

const
  STATE_MAX_DEPTH = 3;
  STATE_MAX_COLLECTION_ITEMS = 50;

implementation

uses
  System.TypInfo,
  System.Variants,
  Vcl.Controls;

const
  KEY_SEPARATOR = '.';
  REASON_READ_ONLY = 'salt okunur (setter yok)';
  REASON_COMPONENT = 'bileşen referansı saklanmaz';
  REASON_KIND = 'bu tür saklanamaz';
  PAGE_PROPS: array[0..2] of string = ('ActivePageIndex', 'TabIndex', 'ItemIndex');
  SIZE_ALIGNS = [alTop, alBottom, alLeft, alRight];

function MakeKey(AComponent: TComponent; const APath: string): string;
begin
  Result := AComponent.Name + KEY_SEPARATOR + APath;
end;

function JoinPath(const APrefix, AName: string): string;
begin
  if APrefix = '' then
    Result := AName
  else
    Result := APrefix + KEY_SEPARATOR + AName;
end;

function SafeValueText(AObject: TObject; APropInfo: PPropInfo): string;
begin
  // Boundary: a third-party getter may raise at design time; the list must still open.
  try
    if APropInfo^.PropType^.Kind = tkClass then
      Result := ''
    else
      Result := VarToStr(GetPropValue(AObject, APropInfo, True));
  except
    on Exception do
      Result := '?';
  end;
end;

{ TRadStateLeaf }

function TRadStateLeaf.Key: string;
begin
  Result := MakeKey(Component, Path);
end;

{ TRadStateEditorModel }

constructor TRadStateEditorModel.Create(AStore: TRadPropertiesStore);
begin
  inherited Create;
  FStore := AStore;
  FLeaves := TList<TRadStateLeaf>.Create;
  FSelection := TStringList.Create;
end;

destructor TRadStateEditorModel.Destroy;
begin
  FSelection.Free;
  FLeaves.Free;
  inherited;
end;

procedure TRadStateEditorModel.Build;
var
  I: Integer;
  LComponent: TComponent;
begin
  FLeaves.Clear;
  if FStore.Owner = nil then
    Exit;
  for I := 0 to FStore.Owner.ComponentCount - 1 do
  begin
    LComponent := FStore.Owner.Components[I];
    if (LComponent <> FStore) and (LComponent.Name <> '') and not (LComponent is TRadPropertiesStore) then
      AddObject(LComponent, LComponent, '', 1);
  end;
end;

procedure TRadStateEditorModel.AddLeaf(AComponent: TComponent; const APath, ATypeName, AValue, AReason: string);
var
  LLeaf: TRadStateLeaf;
begin
  LLeaf.Component := AComponent;
  LLeaf.Path := APath;
  LLeaf.TypeName := ATypeName;
  LLeaf.Value := AValue;
  LLeaf.Reason := AReason;
  LLeaf.Restorable := AReason = '';
  FLeaves.Add(LLeaf);
end;

procedure TRadStateEditorModel.AddObject(AComponent: TComponent; AObject: TObject; const APrefix: string;
  ADepth: Integer);
var
  LList: PPropList;
  LCount, I: Integer;
begin
  LCount := GetPropList(AObject.ClassInfo, tkProperties, nil);
  if LCount = 0 then
    Exit;
  GetMem(LList, LCount * SizeOf(Pointer));
  try
    GetPropList(AObject.ClassInfo, tkProperties, LList, True);
    for I := 0 to LCount - 1 do
      AddProperty(AComponent, AObject, LList^[I], APrefix, ADepth);
  finally
    FreeMem(LList);
  end;
end;

procedure TRadStateEditorModel.AddProperty(AComponent: TComponent; AObject: TObject; APropInfo: Pointer;
  const APrefix: string; ADepth: Integer);
var
  LInfo: PPropInfo;
  LPath: string;
  LChild: TObject;
begin
  LInfo := PPropInfo(APropInfo);
  LPath := JoinPath(APrefix, string(LInfo^.Name));
  if LInfo^.PropType^.Kind <> tkClass then
  begin
    if LInfo^.PropType^.Kind in [tkInterface, tkPointer, tkArray, tkDynArray, tkRecord, tkMRecord, tkProcedure] then
      AddLeaf(AComponent, LPath, string(LInfo^.PropType^.Name), '', REASON_KIND)
    else if LInfo^.SetProc = nil then
      AddLeaf(AComponent, LPath, string(LInfo^.PropType^.Name), SafeValueText(AObject, LInfo), REASON_READ_ONLY)
    else
      AddLeaf(AComponent, LPath, string(LInfo^.PropType^.Name), SafeValueText(AObject, LInfo), '');
    Exit;
  end;
  LChild := GetObjectProp(AObject, LInfo);
  if LChild is TComponent then
    AddLeaf(AComponent, LPath, string(LInfo^.PropType^.Name), TComponent(LChild).Name, REASON_COMPONENT)
  else if LChild is TStrings then
    AddLeaf(AComponent, LPath, string(LInfo^.PropType^.Name), IntToStr(TStrings(LChild).Count) + ' satır', '')
  else if (LChild is TCollection) and (ADepth < STATE_MAX_DEPTH) then
    AddCollection(AComponent, TCollection(LChild), LPath, ADepth + 1)
  else if (LChild is TPersistent) and (ADepth < STATE_MAX_DEPTH) then
    AddObject(AComponent, LChild, LPath, ADepth + 1);
end;

procedure TRadStateEditorModel.AddCollection(AComponent: TComponent; ACollection: TCollection;
  const APrefix: string; ADepth: Integer);
var
  I: Integer;
begin
  // Items are reached by index ('Panels.0.Width'); a whole collection is never a leaf.
  for I := 0 to ACollection.Count - 1 do
  begin
    if I >= STATE_MAX_COLLECTION_ITEMS then
      Break;
    AddObject(AComponent, ACollection.Items[I], JoinPath(APrefix, IntToStr(I)), ADepth + 1);
  end;
end;

function TRadStateEditorModel.FindComponent(const AName: string): TComponent;
begin
  if FStore.Owner = nil then
    Result := nil
  else
    Result := FStore.Owner.FindComponent(AName);
end;

procedure TRadStateEditorModel.LoadFromStore;
var
  I, J: Integer;
  LItem: TRadStateItem;
begin
  FSelection.Clear;
  for I := 0 to FStore.Items.Count - 1 do
  begin
    LItem := FStore.Items[I];
    if LItem.Component <> nil then
      for J := 0 to LItem.Properties.Count - 1 do
        if Trim(LItem.Properties[J]) <> '' then
          SetSelected(LItem.Component, Trim(LItem.Properties[J]), True);
  end;
end;

procedure TRadStateEditorModel.SaveToStore;
var
  LItems: TDictionary<TComponent, TRadStateItem>;
  LKey, LName, LPath: string;
  LComponent: TComponent;
  LItem: TRadStateItem;
begin
  LItems := TDictionary<TComponent, TRadStateItem>.Create;
  try
    FStore.Items.Clear;
    for LKey in FSelection do
    begin
      LName := Copy(LKey, 1, Pos(KEY_SEPARATOR, LKey) - 1);
      LPath := Copy(LKey, Length(LName) + 2, MaxInt);
      LComponent := FindComponent(LName);
      if LComponent = nil then
        Continue;
      if not LItems.TryGetValue(LComponent, LItem) then
      begin
        LItem := FStore.Items.Add;
        LItem.Component := LComponent;
        LItems.Add(LComponent, LItem);
      end;
      LItem.Properties.Add(LPath);
    end;
  finally
    LItems.Free;
  end;
end;

function TRadStateEditorModel.IsSelected(AComponent: TComponent; const APath: string): Boolean;
begin
  Result := FSelection.IndexOf(MakeKey(AComponent, APath)) >= 0;
end;

procedure TRadStateEditorModel.SetSelected(AComponent: TComponent; const APath: string; ASelected: Boolean);
var
  LIndex: Integer;
begin
  LIndex := FSelection.IndexOf(MakeKey(AComponent, APath));
  if ASelected and (LIndex < 0) then
    FSelection.Add(MakeKey(AComponent, APath))
  else if not ASelected and (LIndex >= 0) then
    FSelection.Delete(LIndex);
end;

function TRadStateEditorModel.MoveSelection(AIndex, ADelta: Integer): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex < FSelection.Count) and (AIndex + ADelta >= 0) and
    (AIndex + ADelta < FSelection.Count);
  if Result then
    FSelection.Exchange(AIndex, AIndex + ADelta);
end;

function TRadStateEditorModel.LeafOf(AComponent: TComponent; const APath: string; out ALeaf: TRadStateLeaf): Boolean;
var
  LLeaf: TRadStateLeaf;
begin
  for LLeaf in FLeaves do
    if (LLeaf.Component = AComponent) and SameText(LLeaf.Path, APath) then
    begin
      ALeaf := LLeaf;
      Exit(True);
    end;
  Result := False;
end;

class function TRadStateEditorModel.PresetPaths(AComponent: TComponent; APreset: TRadStatePreset): TArray<string>;
var
  LName: string;
begin
  Result := nil;
  case APreset of
    spPage:
      for LName in PAGE_PROPS do
        if (GetPropInfo(AComponent, LName) <> nil) and (GetPropInfo(AComponent, LName)^.SetProc <> nil) then
        begin
          Result := [LName]; // Exit([LName]) is E2001: Exit takes no array constructor
          Exit;
        end;
    spSize:
      // A panel docked to an edge is what a splitter resizes; its size is the splitter position.
      if (AComponent is TControl) and (TControl(AComponent).Align in SIZE_ALIGNS) then
        if TControl(AComponent).Align in [alLeft, alRight] then
          Result := ['Width']
        else
          Result := ['Height'];
  end;
end;

function TRadStateEditorModel.ApplyPreset(APreset: TRadStatePreset): Integer;
var
  I: Integer;
  LComponent: TComponent;
  LPath: string;
begin
  Result := 0;
  if FStore.Owner = nil then
    Exit;
  for I := 0 to FStore.Owner.ComponentCount - 1 do
  begin
    LComponent := FStore.Owner.Components[I];
    if (LComponent.Name = '') or (LComponent is TRadPropertiesStore) then
      Continue;
    for LPath in PresetPaths(LComponent, APreset) do
      if not IsSelected(LComponent, LPath) then
      begin
        SetSelected(LComponent, LPath, True);
        Inc(Result);
      end;
  end;
end;

end.
