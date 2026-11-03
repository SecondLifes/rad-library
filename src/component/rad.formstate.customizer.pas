unit rad.formstate.customizer;

{ TRadFormCustomizer: per-user visual changes on the components and properties that rules and the
  Allowed list open (docs/specs/rad.formcustomizer.md). Saves only what the user changed, through
  its TRadPropertiesStore. The editing session lives in the TMS package and registers itself here,
  so this unit stays free of TMS. }

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Forms,
  mormot.core.base,
  mormot.core.variants,
  rad.formstate.core,
  rad.formstate.store,
  rad.formstate.component,
  rad.formstate.rules;

type
  TRadFormCustomizer = class;

  /// <summary>rpRulesAndAllowed: rules open by class, Allowed adds single components.
  /// rpAllowedOnly: only what Allowed lists; opening rules are ignored, closing rules still apply.</summary>
  TRadPermissionMode = (rpRulesAndAllowed, rpAllowedOnly);

  /// <summary>Opens the editing session; registered by the TMS package.</summary>
  TRadCustomizeSession = reference to procedure(ACustomizer: TRadFormCustomizer);

  /// <summary>Lets the user change the allowed properties of the allowed components at runtime.</summary>
  /// <remarks>Saves through Store, else the owner's first TRadPropertiesStore; keeps the user's changes
  /// only, so a property the user never touched still follows the DFM.</remarks>
  TRadFormCustomizer = class(TComponent, IRadStateful, IRadStateVersion)
  strict private
    class var FSession: TRadCustomizeSession;
    class var FDefaultRules: string;
    class var FRulesVersion: Integer;
    class function GetDefaultRules: string; static;
    class procedure SetDefaultRules(const AValue: string); static;
  private
    FAllowed: TRadStateItems;
    FPermissionMode: TRadPermissionMode;
    FRules: TStrings;
    FResolved: TObjectDictionary<TComponent, TStringList>;
    FTargets: TList<TComponent>;
    FResolvedVersion: Integer;
    FCaptions: TStrings;
    FGridStep: Integer;
    FOnChanged: TNotifyEvent;
    FStore: TRadPropertiesStore;
    FDiff: IDocDict;
    FDefaults: IDocDict;
    FPpi: Integer;
    FLoaded: Boolean;
    procedure SetAllowed(const AValue: TRadStateItems);
    procedure SetRules(const AValue: TStrings);
    procedure SetPermissionMode(AValue: TRadPermissionMode);
    procedure SetStore(AValue: TRadPropertiesStore);
    procedure SetCaptions(const AValue: TStrings);
    procedure RulesChanged(Sender: TObject);
    procedure Invalidate;
    procedure Resolve;
    procedure ResolveComponent(AComponent: TComponent; ARules: TRadCustomizeRules);
    function ItemOf(AComponent: TComponent): TRadStateItem;
    function ChildDoc(const ADoc: IDocDict; const AName: RawUtf8; ACreate: Boolean): IDocDict;
    procedure RememberDefault(AComponent: TComponent; const APath: RawUtf8; const AValue: Variant;
      AReplace: Boolean);
    procedure ApplyDiff(const AScale: TRadStateScale);
    procedure CommitPath(AComponent: TComponent; const AKey: RawUtf8; const AOld, ANew: Variant);
    procedure TakeOverwrittenDefaults;
    procedure NormalizeDiff;
    function CurrentPpi: Integer;
    procedure Changed;
  protected
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SaveState(const ADoc: IDocDict);
    /// <summary>First call applies the saved changes; a later call (after the company layout)
    /// applies them again and takes the overwritten values as their defaults.</summary>
    procedure LoadState(const ADoc: IDocDict);
    function StateVersion: Integer;
    /// <summary>Opens the editing session; raises ERadFormState when no session is registered.</summary>
    procedure Customize;
    function IsAllowed(AComponent: TComponent; const APath: string): Boolean;
    /// <summary>The allowed paths of AComponent (rules, then Allowed, minus closing rules and Name);
    /// nil when it is not allowed at all. Valid until the rules or Allowed change.</summary>
    function AllowedPaths(AComponent: TComponent): TStrings;
    /// <summary>Every component with at least one allowed path, in the owner's order.</summary>
    function Targets: TArray<TComponent>;
    function CanMove(AComponent: TComponent): Boolean;
    function CanResize(AComponent: TComponent): Boolean;
    /// <summary>Captions entry, else a built-in Turkish name, else the path itself.</summary>
    function CaptionOf(const APath: string): string;
    /// <summary>Current values of AComponent's allowed paths.</summary>
    function Snapshot(AComponent: TComponent): IDocDict;
    /// <summary>Snapshot of every allowed component, by name: what a session keeps to compare and cancel.</summary>
    function SnapshotAll: IDocDict;
    /// <summary>Writes AValues into AComponent; paths that are not allowed are ignored.</summary>
    procedure ApplyValues(AComponent: TComponent; const AValues: IDocDict);
    /// <summary>Adds every allowed path that differs from ABefore (a SnapshotAll) to the changes and saves.
    /// A path back at its default leaves the changes instead.</summary>
    procedure Commit(const ABefore: IDocDict);
    /// <summary>The known defaults of AComponent's changed paths (a copy); empty when nothing changed.</summary>
    function Defaults(AComponent: TComponent): IDocDict;
    /// <summary>Forgets the saved change of one path and puts its default back.</summary>
    procedure ResetPath(AComponent: TComponent; const APath: string);
    /// <summary>Forgets every saved change and puts the defaults back.</summary>
    procedure ResetAll;
    class procedure RegisterSession(const ASession: TRadCustomizeSession); static;
    /// <summary>Rules every customizer of the application uses before its own Rules
    /// (e.g. RAD_CUSTOMIZE_APPEARANCE); set once at startup.</summary>
    class property DefaultRules: string read GetDefaultRules write SetDefaultRules;
    /// <summary>Component name -> {path: value} of the user's changes.</summary>
    property Diff: IDocDict read FDiff;
  published
    /// <summary>Where the changes are saved (its Encrypted, StorageType...); empty: the owner's first store.</summary>
    property Store: TRadPropertiesStore read FStore write SetStore;
    /// <summary>rpAllowedOnly: the user sees only what Allowed lists, whatever the rules open.</summary>
    property PermissionMode: TRadPermissionMode read FPermissionMode write SetPermissionMode
      default rpRulesAndAllowed;
    /// <summary>'TControl: Left, Top' opens by class (descendants too), '-Edit1' or '-TPanel: Color'
    /// closes; a closing line always wins, also over Allowed.</summary>
    property Rules: TStrings read FRules write SetRules;
    /// <summary>Exceptions for single components, added to what the rules open.</summary>
    property Allowed: TRadStateItems read FAllowed write SetAllowed;
    property Captions: TStrings read FCaptions write SetCaptions;
    property GridStep: Integer read FGridStep write FGridStep default 8;
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
  end;

implementation

uses
  System.Variants,
  mormot.core.text,
  mormot.core.unicode,
  mormot.core.rtti,
  mormot.core.log;

resourcestring
  SNoSession = 'Form düzenleme oturumu yüklü değil: uygulama rad.scripting birimini uses etmeli ' +
    '(RadScriptTmsDesign paketi; runtime paketle çalışılıyorsa bu paket de yüklenmeli).';
  SNoStore = 'rad.formstate %s: no TRadPropertiesStore on the owner, changes are not saved';

const
  STATE_VERSION = 1;
  DEFAULT_GRID_STEP = 8;
  FIELD_PPI = 'ppi';
  FIELD_DIFF = 'diff';
  MOVE_PATHS: array[0..1] of string = ('Left', 'Top');
  SIZE_PATHS: array[0..1] of string = ('Width', 'Height');
  BUILT_IN_CAPTIONS: array[0..23] of string = (
    'Font=Yazı', 'Style=Görünüm', 'Properties=Özellikler', 'Margins=Kenar boşlukları',
    'Caption=Başlık', 'Text=Metin', 'Hint=İpucu', 'Color=Renk', 'Visible=Görünür', 'Enabled=Etkin',
    'Left=Sol', 'Top=Üst', 'Width=Genişlik', 'Height=Yükseklik', 'TabOrder=Sekme sırası',
    'ReadOnly=Salt okunur', 'Font.Name=Yazı tipi', 'Font.Size=Yazı boyutu', 'Font.Color=Yazı rengi',
    'Font.Style=Yazı stili', 'Properties.ReadOnly=Salt okunur', 'Style.Color=Arka plan rengi',
    'Style.Font.Size=Yazı boyutu', 'Style.Font.Color=Yazı rengi');

function KeysOf(const ADoc: IDocDict): TRawUtf8DynArray;
var
  LKey: TDocKey;
  LCount: Integer;
begin
  // Keys enumerates weak references: copy them before the loop body writes to ADoc.
  SetLength(Result, ADoc.Len);
  LCount := 0;
  for LKey in ADoc.Keys do
  begin
    Result[LCount] := LKey.Utf8;
    Inc(LCount);
  end;
  SetLength(Result, LCount);
end;

function SameJsonValue(const A, B: Variant): Boolean;
begin
  Result := VariantSaveJson(A) = VariantSaveJson(B);
end;

{ TRadFormCustomizer }

constructor TRadFormCustomizer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAllowed := TRadStateItems.Create(Self, TRadStateItem);
  FRules := TStringList.Create;
  TStringList(FRules).OnChange := RulesChanged;
  FCaptions := TStringList.Create;
  FGridStep := DEFAULT_GRID_STEP;
  FDiff := DocDict(mFastFloat);
  FDefaults := DocDict(mFastFloat);
end;

destructor TRadFormCustomizer.Destroy;
begin
  if (FStore <> nil) and not (csDestroying in FStore.ComponentState) then
    FStore.Detach(Self);
  Invalidate;
  FAllowed.Free;
  FRules.Free;
  FCaptions.Free;
  inherited;
end;

procedure TRadFormCustomizer.Loaded;
var
  I: Integer;
begin
  inherited;
  if (csDesigning in ComponentState) or (Owner = nil) then
    Exit;
  for I := 0 to Owner.ComponentCount - 1 do
    if (FStore = nil) and (Owner.Components[I] is TRadPropertiesStore) then
      SetStore(TRadPropertiesStore(Owner.Components[I]));
  if FStore = nil then
    TSynLog.Add.Log(sllWarning, StringToUtf8(SNoStore), [Name])
  else
    FStore.Attach(Self);
end;

procedure TRadFormCustomizer.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited;
  if AOperation <> opRemove then
    Exit;
  if AComponent = FStore then
    FStore := nil
  else if FAllowed <> nil then
  begin
    FAllowed.ComponentRemoved(AComponent, not (csDestroying in ComponentState));
    if FResolved <> nil then
    begin
      FResolved.Remove(AComponent);
      FTargets.Remove(AComponent);
    end;
  end;
end;

procedure TRadFormCustomizer.SetAllowed(const AValue: TRadStateItems);
begin
  FAllowed.Assign(AValue);
  Invalidate;
end;

procedure TRadFormCustomizer.SetRules(const AValue: TStrings);
begin
  FRules.Assign(AValue);
end;

procedure TRadFormCustomizer.SetPermissionMode(AValue: TRadPermissionMode);
begin
  FPermissionMode := AValue;
  Invalidate;
end;

procedure TRadFormCustomizer.RulesChanged(Sender: TObject);
begin
  Invalidate;
end;

procedure TRadFormCustomizer.SetStore(AValue: TRadPropertiesStore);
begin
  if AValue = FStore then
    Exit;
  if FStore <> nil then
  begin
    FStore.RemoveFreeNotification(Self);
    if ComponentState * [csLoading, csDesigning] = [] then
      FStore.Detach(Self);
  end;
  FStore := AValue;
  if FStore = nil then
    Exit;
  FStore.FreeNotification(Self);
  if ComponentState * [csLoading, csDesigning] = [] then
    FStore.Attach(Self); // after loading; Loaded attaches the DFM link
end;

class function TRadFormCustomizer.GetDefaultRules: string;
begin
  Result := FDefaultRules;
end;

class procedure TRadFormCustomizer.SetDefaultRules(const AValue: string);
begin
  FDefaultRules := AValue;
  Inc(FRulesVersion); // live customizers resolve again on their next question
end;

procedure TRadFormCustomizer.Invalidate;
begin
  FreeAndNil(FResolved);
  FreeAndNil(FTargets);
end;

procedure TRadFormCustomizer.Resolve;
var
  LRules: TRadCustomizeRules;
  I: Integer;
begin
  Invalidate;
  FResolved := TObjectDictionary<TComponent, TStringList>.Create([doOwnsValues]);
  FTargets := TList<TComponent>.Create;
  FResolvedVersion := FRulesVersion;
  LRules := TRadCustomizeRules.Create;
  try
    LRules.Add(FDefaultRules);
    LRules.Add(FRules.Text);
    for I := 0 to LRules.Errors.Count - 1 do
      TSynLog.Add.Log(sllWarning, 'rad.formstate %.Rules: %', [Name, LRules.Errors[I]]);
    if Owner <> nil then
      for I := 0 to Owner.ComponentCount - 1 do
        ResolveComponent(Owner.Components[I], LRules);
    for I := 0 to FAllowed.Count - 1 do // an Allowed component the owner does not own
      if (FAllowed[I].Component <> nil) and not FResolved.ContainsKey(FAllowed[I].Component) then
        ResolveComponent(FAllowed[I].Component, LRules);
  finally
    LRules.Free;
  end;
end;

procedure TRadFormCustomizer.ResolveComponent(AComponent: TComponent; ARules: TRadCustomizeRules);
var
  LPaths: TStringList;
  LItem: TRadStateItem;
begin
  if (AComponent.Name = '') or FResolved.ContainsKey(AComponent) then
    Exit; // the changes are saved by name
  LPaths := TStringList.Create; // case-insensitive, like the paths themselves
  try
    LItem := ItemOf(AComponent);
    if LItem <> nil then
      ARules.PathsFor(AComponent, LItem.Properties, LPaths, FPermissionMode = rpRulesAndAllowed)
    else
      ARules.PathsFor(AComponent, nil, LPaths, FPermissionMode = rpRulesAndAllowed);
  except
    LPaths.Free;
    raise;
  end;
  if LPaths.Count = 0 then
    LPaths.Free
  else
  begin
    FResolved.Add(AComponent, LPaths);
    FTargets.Add(AComponent);
    AComponent.FreeNotification(Self);
  end;
end;

function TRadFormCustomizer.Targets: TArray<TComponent>;
begin
  if (FResolved = nil) or (FResolvedVersion <> FRulesVersion) then
    Resolve;
  Result := FTargets.ToArray;
end;

procedure TRadFormCustomizer.SetCaptions(const AValue: TStrings);
begin
  FCaptions.Assign(AValue);
end;

function TRadFormCustomizer.ItemOf(AComponent: TComponent): TRadStateItem;
var
  I: Integer;
begin
  for I := 0 to FAllowed.Count - 1 do
    if (AComponent <> nil) and (FAllowed[I].Component = AComponent) then
      Exit(FAllowed[I]);
  Result := nil;
end;

function TRadFormCustomizer.AllowedPaths(AComponent: TComponent): TStrings;
var
  LPaths: TStringList;
begin
  if (FResolved = nil) or (FResolvedVersion <> FRulesVersion) then
    Resolve;
  if (AComponent <> nil) and FResolved.TryGetValue(AComponent, LPaths) then
    Result := LPaths
  else
    Result := nil;
end;

function TRadFormCustomizer.IsAllowed(AComponent: TComponent; const APath: string): Boolean;
var
  LPaths: TStrings;
begin
  LPaths := AllowedPaths(AComponent);
  Result := (LPaths <> nil) and (LPaths.IndexOf(APath) >= 0);
end;

function TRadFormCustomizer.CanMove(AComponent: TComponent): Boolean;
begin
  Result := IsAllowed(AComponent, MOVE_PATHS[0]) or IsAllowed(AComponent, MOVE_PATHS[1]);
end;

function TRadFormCustomizer.CanResize(AComponent: TComponent): Boolean;
begin
  Result := IsAllowed(AComponent, SIZE_PATHS[0]) or IsAllowed(AComponent, SIZE_PATHS[1]);
end;

function TRadFormCustomizer.CaptionOf(const APath: string): string;
var
  LPair: string;
begin
  Result := FCaptions.Values[APath];
  if Result <> '' then
    Exit;
  for LPair in BUILT_IN_CAPTIONS do
    if SameText(Copy(LPair, 1, Pos('=', LPair) - 1), APath) then
      Exit(Copy(LPair, Pos('=', LPair) + 1, MaxInt));
  Result := APath;
end;

function TRadFormCustomizer.CurrentPpi: Integer;
begin
  if Owner is TControl then
    Result := TControl(Owner).CurrentPPI
  else
    Result := Screen.PixelsPerInch;
end;

function TRadFormCustomizer.ChildDoc(const ADoc: IDocDict; const AName: RawUtf8; ACreate: Boolean): IDocDict;
begin
  if not ADoc.Get(AName, Result) then
  begin
    Result := nil;
    if not ACreate then
      Exit;
    ADoc.D[AName] := DocDict(mFastFloat); // stores a copy: take the stored one back
    ADoc.Get(AName, Result);
  end;
end;

function TRadFormCustomizer.Snapshot(AComponent: TComponent): IDocDict;
var
  LPaths: TStrings;
begin
  LPaths := AllowedPaths(AComponent);
  if LPaths = nil then
    Result := DocDict(mFastFloat)
  else
    Result := DocDict(TRadStatePaths.Capture(AComponent, LPaths), mFastFloat);
end;

function TRadFormCustomizer.SnapshotAll: IDocDict;
var
  LComponent: TComponent;
begin
  Result := DocDict(mFastFloat);
  for LComponent in Targets do
    Result.D[StringToUtf8(LComponent.Name)] := Snapshot(LComponent);
end;

procedure TRadFormCustomizer.ApplyValues(AComponent: TComponent; const AValues: IDocDict);
var
  LPaths: TStrings;
  LResult: TRadStateApplyResult;
  LError: RawUtf8;
begin
  LPaths := AllowedPaths(AComponent);
  if (LPaths = nil) or (AValues = nil) then
    Exit;
  LResult := TRadStatePaths.Apply(AComponent, LPaths, AValues, TRadStateScale.None);
  for LError in LResult.Errors do
    TSynLog.Add.Log(sllWarning, 'rad.formstate %.%: %', [Name, AComponent.Name, LError]);
end;

procedure TRadFormCustomizer.RememberDefault(AComponent: TComponent; const APath: RawUtf8;
  const AValue: Variant; AReplace: Boolean);
var
  LDefaults: IDocDict;
begin
  LDefaults := ChildDoc(FDefaults, StringToUtf8(AComponent.Name), True);
  if AReplace or not LDefaults.Exists(APath) then
    LDefaults.Item[APath] := AValue;
end;

procedure TRadFormCustomizer.ApplyDiff(const AScale: TRadStateScale);
var
  LComponent: TComponent;
  LValues: IDocDict;
  LResult: TRadStateApplyResult;
  LError: RawUtf8;
begin
  for LComponent in Targets do
  begin
    if not FDiff.Get(StringToUtf8(LComponent.Name), LValues) then
      Continue;
    LResult := TRadStatePaths.Apply(LComponent, AllowedPaths(LComponent), LValues, AScale);
    for LError in LResult.Errors do
      TSynLog.Add.Log(sllWarning, 'rad.formstate %.%: %', [Name, LComponent.Name, LError]);
  end;
end;

procedure TRadFormCustomizer.NormalizeDiff;
var
  LComponent: TComponent;
  LValues, LNow: IDocDict;
  LKey: RawUtf8;
  LValue: Variant;
begin
  // Re-read the applied values so every saved pixel value is in the current PPI from now on.
  for LComponent in Targets do
  begin
    if not FDiff.Get(StringToUtf8(LComponent.Name), LValues) then
      Continue;
    LNow := Snapshot(LComponent);
    for LKey in KeysOf(LValues) do
      if LNow.Get(LKey, LValue) then
        LValues.Item[LKey] := LValue;
  end;
  FPpi := CurrentPpi;
end;

procedure TRadFormCustomizer.TakeOverwrittenDefaults;
var
  LComponent: TComponent;
  LValues, LNow: IDocDict;
  LKey: RawUtf8;
  LNew: Variant;
begin
  // Something applied after the first load (the company layout): what it wrote is the default now.
  for LComponent in Targets do
  begin
    if not FDiff.Get(StringToUtf8(LComponent.Name), LValues) then
      Continue;
    LNow := Snapshot(LComponent);
    for LKey in KeysOf(LValues) do
      if LNow.Get(LKey, LNew) and not SameJsonValue(LNew, LValues.Item[LKey]) then
        RememberDefault(LComponent, LKey, LNew, True);
  end;
end;

procedure TRadFormCustomizer.SaveState(const ADoc: IDocDict);
begin
  if FDiff.Len = 0 then
    Exit;
  ADoc.I[FIELD_PPI] := FPpi;
  ADoc.D[FIELD_DIFF] := FDiff;
end;

procedure TRadFormCustomizer.LoadState(const ADoc: IDocDict);
var
  LDiff, LValues, LNow: IDocDict;
  LComponent: TComponent;
  LKey: RawUtf8;
  LValue: Variant;
begin
  if FLoaded then
  begin
    TakeOverwrittenDefaults;
    ApplyDiff(TRadStateScale.None);
    Exit;
  end;
  FLoaded := True;
  if not ADoc.Get(FIELD_DIFF, LDiff) then
    Exit;
  FDiff := LDiff.Copy;
  FPpi := ADoc.I[FIELD_PPI];
  for LComponent in Targets do
  begin
    if not FDiff.Get(StringToUtf8(LComponent.Name), LValues) then
      Continue;
    LNow := Snapshot(LComponent);
    for LKey in KeysOf(LValues) do
      if LNow.Get(LKey, LValue) then
        RememberDefault(LComponent, LKey, LValue, False);
  end;
  ApplyDiff(TRadStateScale.Make(FPpi, CurrentPpi));
  NormalizeDiff;
end;

function TRadFormCustomizer.StateVersion: Integer;
begin
  Result := STATE_VERSION;
end;

procedure TRadFormCustomizer.Changed;
begin
  FPpi := CurrentPpi;
  if FStore <> nil then
    FStore.Save;
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

function TRadFormCustomizer.Defaults(AComponent: TComponent): IDocDict;
var
  LDefaults: IDocDict;
begin
  LDefaults := ChildDoc(FDefaults, StringToUtf8(AComponent.Name), False);
  if LDefaults = nil then
    Result := DocDict(mFastFloat)
  else
    Result := LDefaults.Copy;
end;

procedure TRadFormCustomizer.CommitPath(AComponent: TComponent; const AKey: RawUtf8;
  const AOld, ANew: Variant);
var
  LName: RawUtf8;
  LDefaults, LDiff: IDocDict;
  LDefault: Variant;
begin
  LName := StringToUtf8(AComponent.Name);
  LDefaults := ChildDoc(FDefaults, LName, False);
  if (LDefaults <> nil) and LDefaults.Get(AKey, LDefault) and SameJsonValue(LDefault, ANew) then
  begin
    LDiff := ChildDoc(FDiff, LName, False); // back at its default: not a change any more
    if LDiff <> nil then
    begin
      LDiff.Del(AKey);
      if LDiff.Len = 0 then
        FDiff.Del(LName);
    end;
    Exit;
  end;
  if not VarIsEmpty(AOld) then
    RememberDefault(AComponent, AKey, AOld, False); // first change: the session start is the default
  ChildDoc(FDiff, LName, True).Item[AKey] := ANew;
end;

procedure TRadFormCustomizer.Commit(const ABefore: IDocDict);
var
  LComponent: TComponent;
  LBefore, LNow: IDocDict;
  LKey: RawUtf8;
  LOld, LNew: Variant;
begin
  for LComponent in Targets do
  begin
    if not ABefore.Get(StringToUtf8(LComponent.Name), LBefore) then
      Continue;
    LNow := Snapshot(LComponent);
    for LKey in KeysOf(LNow) do
    begin
      LNew := LNow.Item[LKey];
      LOld := Unassigned;
      if not (LBefore.Get(LKey, LOld) and SameJsonValue(LOld, LNew)) then
        CommitPath(LComponent, LKey, LOld, LNew);
    end;
  end;
  Changed;
end;

procedure TRadFormCustomizer.ResetPath(AComponent: TComponent; const APath: string);
var
  LDiff, LDefaults, LValue: IDocDict;
  LKey: RawUtf8;
begin
  LKey := StringToUtf8(APath);
  LDiff := ChildDoc(FDiff, StringToUtf8(AComponent.Name), False);
  if (LDiff = nil) or not LDiff.Exists(LKey) then
    Exit;
  LDiff.Del(LKey);
  if LDiff.Len = 0 then
    FDiff.Del(StringToUtf8(AComponent.Name));
  LDefaults := ChildDoc(FDefaults, StringToUtf8(AComponent.Name), False);
  if (LDefaults <> nil) and LDefaults.Exists(LKey) then
  begin
    LValue := DocDict(mFastFloat);
    LValue.Item[LKey] := LDefaults.Item[LKey];
    ApplyValues(AComponent, LValue);
  end;
  Changed;
end;

procedure TRadFormCustomizer.ResetAll;
var
  LComponent: TComponent;
  LDefaults: IDocDict;
begin
  for LComponent in Targets do
  begin
    LDefaults := ChildDoc(FDefaults, StringToUtf8(LComponent.Name), False);
    if LDefaults <> nil then
      ApplyValues(LComponent, LDefaults);
  end;
  FDiff := DocDict(mFastFloat);
  Changed;
end;

procedure TRadFormCustomizer.Customize;
begin
  if not Assigned(FSession) then
    raise ERadFormState.Create(SNoSession);
  Invalidate; // controls created at runtime since the last question get their rules too
  FSession(Self);
end;

class procedure TRadFormCustomizer.RegisterSession(const ASession: TRadCustomizeSession);
begin
  FSession := ASession;
end;

end.
