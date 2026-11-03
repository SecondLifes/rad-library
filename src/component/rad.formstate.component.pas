unit rad.formstate.component;

{ TRadPropertiesStore: saves chosen published properties, the window placement and free
  key/value pairs of a form or data module (docs/specs/rad.formstate.md).
  Consumers add rad.formstate, the entry unit, rather than this one. }

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Forms,
  mormot.core.base,
  mormot.core.variants,
  rad.cipher,
  rad.formstate.core,
  rad.formstate.store;

type
  TRadStateOption = (soPlacement, soActiveControl, soProps, soValues, soCustom);
  TRadStateOptions = set of TRadStateOption;
  /// <summary>svtVariant returns what was saved; the others always return that type.</summary>
  TRadStoredValueType = (svtVariant, svtString, svtInteger, svtFloat, svtDateTime, svtBoolean);
  /// <summary>stDefault: the store given to TRadFormState.Kur. stDatabase: TRadFormState.SetDatabase.
  /// The rest: a file under %LOCALAPPDATA%\exe, the exe folder or %ProgramData%\exe.</summary>
  TRadStorageType = (stDefault, stLocalAppData, stExeFolder, stCommonAppData, stDatabase);

const
  RAD_STATE_DEFAULT_OPTIONS = [soPlacement, soProps, soValues, soCustom];

type
  TRadPropertiesStore = class;

  /// <summary>ABefore: the document is read but not applied yet, or the save has not started.</summary>
  TRadStateEvent = procedure(Sender: TRadPropertiesStore; const ABefore: Boolean) of object;
  TRadStateKeyEvent = procedure(Sender: TRadPropertiesStore; var AKey: TRadStateKey) of object;

  /// <summary>One component and its dotted property paths.</summary>
  /// <remarks>The collection's owner component gets the free notification and must pass opRemove
  /// on to TRadStateItems.ComponentRemoved.</remarks>
  TRadStateItem = class(TCollectionItem)
  private
    FComponent: TComponent;
    FProperties: TStrings;
    procedure SetComponent(const AValue: TComponent);
    procedure SetProperties(const AValue: TStrings);
    function OwnerComponent: TComponent;
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;
    procedure Assign(ASource: TPersistent); override;
  published
    property Component: TComponent read FComponent write SetComponent;
    property Properties: TStrings read FProperties write SetProperties;
  end;

  TRadStateItems = class(TOwnedCollection)
  private
    function GetItem(AIndex: Integer): TRadStateItem;
  public
    function Add: TRadStateItem;
    function Refers(AComponent: TComponent): Boolean;
    /// <summary>Deletes the items of AComponent, or only forgets it while the owner is being destroyed.</summary>
    procedure ComponentRemoved(AComponent: TComponent; ADeleteItems: Boolean);
    property Items[AIndex: Integer]: TRadStateItem read GetItem; default;
  end;

  /// <summary>A named value, its type and its design-time default.</summary>
  TRadStoredValue = class(TCollectionItem)
  private
    FName: string;
    FValueType: TRadStoredValueType;
    FValue: Variant;
    function IsValueStored: Boolean;
    procedure SetValueType(AValue: TRadStoredValueType);
  protected
    function GetDisplayName: string; override;
  public
    procedure Assign(ASource: TPersistent); override;
    /// <summary>AValue as AType; False for Null/Empty or text that does not parse.</summary>
    /// <remarks>Text: invariant or local numbers, ISO 8601 or local dates, True/False/0/1.</remarks>
    class function Convert(const AValue: Variant; AType: TRadStoredValueType;
      var AResult: Variant): Boolean; static;
    /// <summary>'', 0, 0.0, 0 (date), False; Null for svtVariant.</summary>
    class function EmptyOf(AType: TRadStoredValueType): Variant; static;
  published
    property Name: string read FName write FName;
    /// <summary>Changing it converts Value to the new type; a value that does not fit is cleared.</summary>
    property ValueType: TRadStoredValueType read FValueType write SetValueType default svtVariant;
    property Value: Variant read FValue write FValue stored IsValueStored;
  end;

  TRadStoredValues = class(TOwnedCollection)
  public
    function Find(const AName: string): TRadStoredValue;
  end;

  /// <summary>Saves and restores the state of its owner, a form or a data module.</summary>
  /// <remarks>Dropped on a form it loads before the owner's OnCreate and saves on close.
  /// Created at runtime it hooks nothing: call Load and Save yourself.</remarks>
  TRadPropertiesStore = class(TComponent)
  strict private
    class var FDefaultStore: IRadStateStore;
    class var FDatabaseStore: IRadStateStore;
    class var FCipher: IRadCipher;
    class var FBuiltInCipher: IRadCipher;
    class var FScope: RawUtf8;
    class var FClosed: Boolean;
    class var FLive: TList<TRadPropertiesStore>;
    class var FProviders: TList<IRadStateProvider>;
    class var FRepositories: TObjectDictionary<string, TRadStateRepository>;
    class constructor CreateClass;
    class destructor DestroyClass;
    class procedure SaveLive; static;
    class function StoreFor(AType: TRadStorageType; const ARoot: string; out AError: string): IRadStateStore; static;
    class function CipherOf: IRadCipher; static;
  private
    FActive: Boolean;
    FOptions: TRadStateOptions;
    FVersion: Integer;
    FStorageType: TRadStorageType;
    FStorageRoot: string;
    FStorageName: string;
    FEncrypted: Boolean;
    FItems: TRadStateItems;
    FStoredValues: TRadStoredValues;
    FValues: IDocDict;
    FDoc: IDocDict;
    FHook: TComponent;
    FRestored: Boolean;
    FSaved: Boolean;
    FResetPending: Boolean;
    FAttached: TList<TComponent>;
    FBases: IDocDict;
    FActiveControlName: RawUtf8;
    FErrors: TRawUtf8DynArray;
    FOnLoad: TRadStateEvent;
    FOnSave: TRadStateEvent;
    FOnGetKey: TRadStateKeyEvent;
    procedure SetItems(const AValue: TRadStateItems);
    procedure SetStoredValues(const AValue: TRadStoredValues);
    function GetStoredValue(const AName: string): Variant;
    procedure SetStoredValue(const AName: string; const AValue: Variant);
    function TryStoredValue(const AName: string; AType: TRadStoredValueType; out AValue: Variant): Boolean;
    function OwnerClassName: RawUtf8;
    function StoreRepository(out AError: string): TRadStateRepository;
    function CurrentPpi: Integer;
    procedure AddError(const AText: RawUtf8);
    procedure ApplyDoc;
    procedure BeginApply;
    procedure EndApply;
    procedure ApplyValues;
    procedure ApplyPlacement;
    procedure ApplyProps;
    procedure ApplyCustom;
    procedure ApplyProviders;
    procedure CaptureBases;
    function BaseMatches(const AProvider: IRadStateProvider): Boolean;
    function Participants: TArray<TComponent>;
    function BuildDoc: IDocDict;
    procedure CapturePlacement(const ADoc: IDocDict);
    procedure CaptureProps(const ADoc: IDocDict);
    procedure CaptureCustom(const ADoc: IDocDict);
    procedure CaptureProviders(const ADoc: IDocDict);
  protected
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Application defaults: the stDefault store (nil: a file store), the key Encrypted stores
    /// use, and the scope. Used by TRadFormState.Kur.</summary>
    class procedure Configure(const AStore: IRadStateStore; const ACipher: IRadCipher; const AScope: RawUtf8); static;
    /// <summary>The store of stDatabase; nil removes it.</summary>
    class procedure SetDatabase(const AStore: IRadStateStore); static;
    /// <summary>Saves every live store that loaded and has not saved, then releases the stores.</summary>
    class procedure Shutdown; static;
    /// <summary>The plain stDefault repository; nil after Shutdown.</summary>
    class function Repository: TRadStateRepository; static;
    /// <summary>The repository of one storage setting, built on first use; nil and AError when it cannot
    /// be used (no database, a root outside the base folder).</summary>
    class function RepositoryFor(AType: TRadStorageType; const ARoot: string; AEncrypted: Boolean;
      out AError: string): TRadStateRepository; static;
    /// <summary>Reads every record of the scope from the default and the database store.</summary>
    class procedure Prefetch; static;
    class function Scope: RawUtf8; static;
    class procedure SetScope(const AScope: RawUtf8); static;
    /// <summary>Adds an application-wide participant; one with the same Name is replaced.</summary>
    class procedure RegisterProvider(const AProvider: IRadStateProvider); static;
    /// <summary>Removes every provider; Shutdown calls it after the last save.</summary>
    class procedure ClearProviders; static;
    /// <summary>Scope + (StorageName, else the owner class name), after OnGetKey. Outside the file
    /// types StorageRoot is the front of the name, since there is no folder.</summary>
    function Key: TRadStateKey;
    /// <summary>Reads and applies the saved state. False when there is no usable record.</summary>
    function Load: Boolean;
    /// <summary>Writes the state. False when nothing was loaded yet, or the content did not change.</summary>
    function Save: Boolean;
    /// <summary>Deletes the saved record and forgets the runtime values.</summary>
    procedure Reset;
    /// <summary>Applies the participant and provider sections again, for a layer applied after Load
    /// (the company layout): the user's own changes stay on top.</summary>
    procedure Reapply;
    /// <summary>Reapply on every store of AOwner.</summary>
    class procedure ReapplyOwner(AOwner: TComponent); static;
    /// <summary>Reset, and this session saves nothing more: the owner is about to be reopened.</summary>
    procedure ResetSaved;
    /// <summary>A named IRadStateful component that takes part without an Items entry.</summary>
    procedure Attach(AComponent: TComponent);
    procedure Detach(AComponent: TComponent);
    /// <summary>Runs on the owner's first show; focus cannot be given earlier.</summary>
    procedure ApplyActiveControl;
    function GetInteger(const AName: string; ADefault: Integer = 0): Integer;
    function GetDouble(const AName: string; ADefault: Double = 0): Double;
    function GetString(const AName: string; const ADefault: string = ''): string;
    function GetBoolean(const AName: string; ADefault: Boolean = False): Boolean;
    function GetDate(const AName: string; ADefault: TDateTime = 0): TDateTime;
    /// <summary>The last loaded document; nil before Load or without a record.</summary>
    property Doc: IDocDict read FDoc;
    property Restored: Boolean read FRestored;
    property Saved: Boolean read FSaved;
    /// <summary>One line per failure of the last Load ('component.path: reason').</summary>
    property Errors: TRawUtf8DynArray read FErrors;
    /// <summary>Runtime value, else the StoredValues default, as the item's ValueType.</summary>
    /// <remarks>Neither convertible: the type's empty value (Null for svtVariant or an undeclared name).</remarks>
    property StoredValue[const AName: string]: Variant read GetStoredValue write SetStoredValue;
  published
    property Active: Boolean read FActive write FActive default True;
    property Options: TRadStateOptions read FOptions write FOptions default RAD_STATE_DEFAULT_OPTIONS;
    property Version: Integer read FVersion write FVersion default 0;
    property StorageType: TRadStorageType read FStorageType write FStorageType default stDefault;
    /// <summary>Relative folder under the base, e.g. 'ayarlar\rapor'; empty means 'state'.
    /// The scope (user) folder is added below it.</summary>
    property StorageRoot: string read FStorageRoot write FStorageRoot;
    /// <summary>Record name ('ayar' gives ayar.state); empty means the owner class name.</summary>
    property StorageName: string read FStorageName write FStorageName;
    /// <summary>Encrypts with the key given to Kur, else with a key built into the library for this exe
    /// name: that one only keeps the file unreadable in a text editor.</summary>
    property Encrypted: Boolean read FEncrypted write FEncrypted default False;
    property Items: TRadStateItems read FItems write SetItems;
    property StoredValues: TRadStoredValues read FStoredValues write SetStoredValues;
    property OnLoad: TRadStateEvent read FOnLoad write FOnLoad;
    property OnSave: TRadStateEvent read FOnSave write FOnSave;
    property OnGetKey: TRadStateKeyEvent read FOnGetKey write FOnGetKey;
  end;

implementation

uses
  Winapi.Windows,
  Winapi.Messages,
  System.Variants,
  System.Generics.Defaults,
  mormot.crypt.core,
  mormot.core.text,
  mormot.core.unicode,
  mormot.core.datetime,
  mormot.core.rtti,
  mormot.core.log;

resourcestring
  SAttachNeedsStateful = '%s: Attach needs a named component that implements IRadStateful.';
  SNoDatabase = 'stDatabase needs TRadFormState.SetDatabase; nothing is loaded or saved';
  SRootOutside = 'StorageRoot ''%s'' must be a relative folder without ''..''; nothing is loaded or saved';

const
  FIELD_STATE = 'state';
  FIELD_NORMAL = 'normal';
  FIELD_ACTIVE_CONTROL = 'activeControl';
  STATE_MAXIMIZED = 'wsMaximized';
  STATE_NORMAL = 'wsNormal';
  NAME_SEPARATOR = '.';
  ROOT_SEPARATOR = '/';
  BUILT_IN_KEY_SALT: RawUtf8 = 'rad.formstate built-in key/';
  SIZEABLE_BORDERS = [bsSizeable, bsSizeToolWin];
  FILE_TYPES = [stLocalAppData, stExeFolder, stCommonAppData];
  FILE_BASES: array[stLocalAppData..stCommonAppData] of TRadStorageRoot = (srLocalAppData, srExeFolder,
    srCommonAppData);

type
  { The protected events of TCustomForm, without assuming the owner descends from TForm. }
  TCustomFormAccess = class(TCustomForm);

  { One per owner, shared by every store on it: two stores never chain each other's
    handlers, so freeing either one leaves the other and the owner's own events intact. }
  TRadStateHook = class(TComponent)
  private
    FStores: TList<TRadPropertiesStore>;
    FOnCreate: TNotifyEvent;
    FOnShow: TNotifyEvent;
    FOnDestroy: TNotifyEvent;
    FOnCloseQuery: TCloseQueryEvent;
    FShown: Boolean;
    procedure OwnerCreate(Sender: TObject);
    procedure OwnerShow(Sender: TObject);
    procedure OwnerCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure OwnerDestroy(Sender: TObject);
    procedure Install;
    procedure Uninstall;
    function Stores: TArray<TRadPropertiesStore>;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    class function Attach(AStore: TRadPropertiesStore): TRadStateHook;
    procedure Detach(AStore: TRadPropertiesStore);
  end;

function SameEvent(const A, B: TMethod): Boolean;
begin
  Result := (A.Code = B.Code) and (A.Data = B.Data);
end;

procedure LogWarning(const AText: RawUtf8);
begin
  TSynLog.Add.Log(sllWarning, 'rad.formstate %', [AText]);
end;

{ Store calls made from the owner's events run at a boundary: the owner must keep
  creating and closing even if the disk is full or a setter raises. }

procedure SafeLoad(AStore: TRadPropertiesStore);
begin
  try
    AStore.Load;
  except
    on E: Exception do
      LogWarning(StringToUtf8(Format('%s.Load: %s: %s', [AStore.Name, E.ClassName, E.Message])));
  end;
end;

procedure SafeSave(AStore: TRadPropertiesStore);
begin
  try
    AStore.Save;
  except
    on E: Exception do
      LogWarning(StringToUtf8(Format('%s.Save: %s: %s', [AStore.Name, E.ClassName, E.Message])));
  end;
end;

{ TRadStateHook }

constructor TRadStateHook.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FStores := TList<TRadPropertiesStore>.Create;
end;

destructor TRadStateHook.Destroy;
begin
  Uninstall;
  FStores.Free;
  inherited;
end;

class function TRadStateHook.Attach(AStore: TRadPropertiesStore): TRadStateHook;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to AStore.Owner.ComponentCount - 1 do
    if AStore.Owner.Components[I] is TRadStateHook then
      Result := TRadStateHook(AStore.Owner.Components[I]);
  if Result = nil then
  begin
    Result := TRadStateHook.Create(AStore.Owner);
    Result.Install;
  end;
  Result.FStores.Add(AStore);
  // DestroyComponents removes a sibling without telling the others unless it carries
  // csFreeNotification; without this the store would call Detach on a freed hook.
  Result.FreeNotification(AStore);
end;

procedure TRadStateHook.Detach(AStore: TRadPropertiesStore);
begin
  FStores.Remove(AStore);
  if (FStores.Count = 0) and not (csDestroying in Owner.ComponentState) then
    Free; // Destroy uninstalls; an owner being destroyed frees the hook itself
end;

function TRadStateHook.Stores: TArray<TRadPropertiesStore>;
begin
  Result := FStores.ToArray; // a handler may free a store while the list is walked
end;

procedure TRadStateHook.Install;
var
  LForm: TCustomFormAccess;
begin
  if Owner is TCustomForm then
  begin
    LForm := TCustomFormAccess(Owner);
    FOnCreate := LForm.OnCreate;
    FOnShow := LForm.OnShow;
    FOnCloseQuery := LForm.OnCloseQuery;
    FOnDestroy := LForm.OnDestroy;
    LForm.OnCreate := OwnerCreate;
    LForm.OnShow := OwnerShow;
    LForm.OnCloseQuery := OwnerCloseQuery;
    LForm.OnDestroy := OwnerDestroy;
  end
  else if Owner is TDataModule then
  begin
    FOnCreate := TDataModule(Owner).OnCreate;
    FOnDestroy := TDataModule(Owner).OnDestroy;
    TDataModule(Owner).OnCreate := OwnerCreate;
    TDataModule(Owner).OnDestroy := OwnerDestroy;
  end;
end;

procedure TRadStateHook.Uninstall;
var
  LForm: TCustomFormAccess;
  LMine: TNotifyEvent;
  LMineClose: TCloseQueryEvent;
begin
  // Only an event that still points here is given back; anything assigned later is left alone.
  if Owner is TCustomForm then
  begin
    LForm := TCustomFormAccess(Owner);
    LMine := OwnerCreate;
    if SameEvent(TMethod(LForm.OnCreate), TMethod(LMine)) then LForm.OnCreate := FOnCreate;
    LMine := OwnerShow;
    if SameEvent(TMethod(LForm.OnShow), TMethod(LMine)) then LForm.OnShow := FOnShow;
    LMineClose := OwnerCloseQuery;
    if SameEvent(TMethod(LForm.OnCloseQuery), TMethod(LMineClose)) then LForm.OnCloseQuery := FOnCloseQuery;
    LMine := OwnerDestroy;
    if SameEvent(TMethod(LForm.OnDestroy), TMethod(LMine)) then LForm.OnDestroy := FOnDestroy;
  end
  else if Owner is TDataModule then
  begin
    LMine := OwnerCreate;
    if SameEvent(TMethod(TDataModule(Owner).OnCreate), TMethod(LMine)) then TDataModule(Owner).OnCreate := FOnCreate;
    LMine := OwnerDestroy;
    if SameEvent(TMethod(TDataModule(Owner).OnDestroy), TMethod(LMine)) then TDataModule(Owner).OnDestroy := FOnDestroy;
  end;
end;

procedure TRadStateHook.OwnerCreate(Sender: TObject);
var
  LStore: TRadPropertiesStore;
begin
  for LStore in Stores do
    if LStore.Active then
      SafeLoad(LStore); // before the owner's OnCreate: its code sees restored values
  if Assigned(FOnCreate) then
    FOnCreate(Sender);
end;

procedure TRadStateHook.OwnerShow(Sender: TObject);
var
  LStore: TRadPropertiesStore;
begin
  if not FShown then
  begin
    FShown := True;
    for LStore in Stores do
      LStore.ApplyActiveControl;
  end;
  if Assigned(FOnShow) then
    FOnShow(Sender);
end;

procedure TRadStateHook.OwnerCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  LStore: TRadPropertiesStore;
begin
  if Assigned(FOnCloseQuery) then
    FOnCloseQuery(Sender, CanClose);
  if CanClose then
    for LStore in Stores do
      SafeSave(LStore); // the window still exists, so the placement is real
end;

procedure TRadStateHook.OwnerDestroy(Sender: TObject);
var
  LStore: TRadPropertiesStore;
begin
  for LStore in Stores do
    if not LStore.Saved then
      SafeSave(LStore); // before the owner's OnDestroy, which may free what the paths reach
  if Assigned(FOnDestroy) then
    FOnDestroy(Sender);
end;

{ TRadStateItem }

constructor TRadStateItem.Create(ACollection: TCollection);
begin
  inherited;
  FProperties := TStringList.Create;
end;

destructor TRadStateItem.Destroy;
var
  LOwner: TComponent;
begin
  LOwner := OwnerComponent;
  if (LOwner <> nil) and not (csDestroying in LOwner.ComponentState) then
    Component := nil;
  FProperties.Free;
  inherited;
end;

function TRadStateItem.OwnerComponent: TComponent;
begin
  if (Collection <> nil) and (TRadStateItems(Collection).Owner is TComponent) then
    Result := TComponent(TRadStateItems(Collection).Owner)
  else
    Result := nil;
end;

procedure TRadStateItem.SetComponent(const AValue: TComponent);
var
  LOwner, LOld: TComponent;
begin
  if FComponent = AValue then
    Exit;
  LOld := FComponent;
  FComponent := AValue;
  LOwner := OwnerComponent;
  if LOwner = nil then
    Exit;
  // Drop the link only when no other item still points at the old component.
  if (LOld <> nil) and not TRadStateItems(Collection).Refers(LOld) then
    LOld.RemoveFreeNotification(LOwner);
  if AValue <> nil then
    AValue.FreeNotification(LOwner);
end;

procedure TRadStateItem.SetProperties(const AValue: TStrings);
begin
  FProperties.Assign(AValue);
end;

function TRadStateItem.GetDisplayName: string;
begin
  if FComponent = nil then
    Result := inherited GetDisplayName
  else
    Result := FComponent.Name;
end;

procedure TRadStateItem.Assign(ASource: TPersistent);
begin
  if ASource is TRadStateItem then
  begin
    Component := TRadStateItem(ASource).Component;
    Properties := TRadStateItem(ASource).Properties;
  end
  else
    inherited;
end;

{ TRadStateItems }

function TRadStateItems.GetItem(AIndex: Integer): TRadStateItem;
begin
  Result := TRadStateItem(inherited Items[AIndex]);
end;

function TRadStateItems.Add: TRadStateItem;
begin
  Result := TRadStateItem(inherited Add);
end;

function TRadStateItems.Refers(AComponent: TComponent): Boolean;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if Items[I].Component = AComponent then
      Exit(True);
  Result := False;
end;

procedure TRadStateItems.ComponentRemoved(AComponent: TComponent; ADeleteItems: Boolean);
var
  I: Integer;
begin
  for I := Count - 1 downto 0 do
    if Items[I].Component = AComponent then
      if ADeleteItems then
        Items[I].Free
      else
        Items[I].FComponent := nil; // the component is gone: no RemoveFreeNotification on it
end;

{ TRadStoredValue }

function TRadStoredValue.IsValueStored: Boolean;
begin
  Result := not VarIsEmpty(FValue);
end;

procedure TRadStoredValue.SetValueType(AValue: TRadStoredValueType);
begin
  if AValue = FValueType then
    Exit;
  FValueType := AValue;
  // The DFM streams ValueType before Value, so loading reaches here with an empty Value.
  if not VarIsEmpty(FValue) and not Convert(FValue, AValue, FValue) then
    FValue := Unassigned;
end;

function TRadStoredValue.GetDisplayName: string;
begin
  if FName = '' then
    Result := inherited GetDisplayName
  else
    Result := FName;
end;

procedure TRadStoredValue.Assign(ASource: TPersistent);
begin
  if ASource is TRadStoredValue then
  begin
    FName := TRadStoredValue(ASource).Name;
    FValueType := TRadStoredValue(ASource).ValueType;
    FValue := TRadStoredValue(ASource).Value;
  end
  else
    inherited;
end;

function TrimmedText(const AValue: Variant): string;
begin
  Result := System.SysUtils.Trim(VariantToString(AValue)); // mORMot keeps text as RawUtf8 varString
end;

function ToInteger(const AValue: Variant; out AResult: Int64): Boolean;
var
  LFloat: Double;
begin
  Result := True;
  if VarType(AValue) = varBoolean then
    AResult := Ord(Boolean(AValue))
  else if VarIsOrdinal(AValue) then
    AResult := AValue
  else if VarIsNumeric(AValue) then
  begin
    LFloat := AValue;
    Result := (Frac(LFloat) = 0) and (Abs(LFloat) <= High(Int64));
    if Result then
      AResult := Trunc(LFloat);
  end
  else
    Result := VarIsStr(AValue) and TryStrToInt64(TrimmedText(AValue), AResult);
end;

function ToFloat(const AValue: Variant; out AResult: Double): Boolean;
var
  LText: string;
begin
  if VarIsNumeric(AValue) or (VarType(AValue) = varDate) then
  begin
    AResult := AValue;
    Exit(True);
  end;
  LText := TrimmedText(AValue);
  // invariant first: '1.5' is never a thousands-separated 15 in a stored value
  Result := VarIsStr(AValue) and (TryStrToFloat(LText, AResult, TFormatSettings.Invariant) or
    TryStrToFloat(LText, AResult));
end;

function ToDateTime(const AValue: Variant; out AResult: TDateTime): Boolean;
var
  LText: string;
begin
  if VarIsNumeric(AValue) or (VarType(AValue) = varDate) then
  begin
    AResult := VarToDateTime(AValue);
    Exit(True);
  end;
  if not VarIsStr(AValue) then
    Exit(False);
  LText := TrimmedText(AValue);
  AResult := Iso8601ToDateTime(StringToUtf8(LText)); // how JSON keeps a date
  Result := (AResult <> 0) or TryStrToDateTime(LText, AResult);
end;

function ToBoolean(const AValue: Variant; out AResult: Boolean): Boolean;
var
  LInt: Int64;
begin
  Result := True;
  if VarType(AValue) = varBoolean then
    AResult := AValue
  else if ToInteger(AValue, LInt) then
    AResult := LInt <> 0
  else
    Result := VarIsStr(AValue) and TryStrToBool(TrimmedText(AValue), AResult);
end;

class function TRadStoredValue.Convert(const AValue: Variant; AType: TRadStoredValueType;
  var AResult: Variant): Boolean;
var
  LInt: Int64;
  LFloat: Double;
  LDate: TDateTime;
  LBool: Boolean;
begin
  Result := not VarIsEmpty(AValue) and not VarIsNull(AValue);
  if Result then
  try
    case AType of
      svtString: AResult := VariantToString(AValue);
      svtInteger: Result := ToInteger(AValue, LInt);
      svtFloat: Result := ToFloat(AValue, LFloat);
      svtDateTime: Result := ToDateTime(AValue, LDate);
      svtBoolean: Result := ToBoolean(AValue, LBool);
    else
      AResult := AValue;
    end;
  except
    on EVariantError do // e.g. an UInt64 beyond Int64
      Result := False;
  end;
  if Result then
    case AType of // assigned last: AResult may be the same variable as AValue
      svtInteger: AResult := LInt;
      svtFloat: AResult := LFloat;
      svtDateTime: AResult := VarFromDateTime(LDate);
      svtBoolean: AResult := LBool;
    end;
end;

class function TRadStoredValue.EmptyOf(AType: TRadStoredValueType): Variant;
begin
  case AType of
    svtString: Result := '';
    svtInteger: Result := Int64(0);
    svtFloat: Result := Double(0);
    svtDateTime: Result := VarFromDateTime(0);
    svtBoolean: Result := False;
  else
    Result := Null;
  end;
end;

{ TRadStoredValues }

function TRadStoredValues.Find(const AName: string): TRadStoredValue;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if SameText(TRadStoredValue(Items[I]).Name, AName) then
      Exit(TRadStoredValue(Items[I]));
  Result := nil;
end;

{ TRadPropertiesStore: class side }

class constructor TRadPropertiesStore.CreateClass;
begin
  FLive := TList<TRadPropertiesStore>.Create;
  FProviders := TList<IRadStateProvider>.Create;
  FRepositories := TObjectDictionary<string, TRadStateRepository>.Create([doOwnsValues], TIStringComparer.Ordinal);
end;

class destructor TRadPropertiesStore.DestroyClass;
begin
  Shutdown;
  FreeAndNil(FLive);
  FreeAndNil(FProviders);
  FreeAndNil(FRepositories);
  FBuiltInCipher := nil;
end;

class procedure TRadPropertiesStore.Configure(const AStore: IRadStateStore; const ACipher: IRadCipher;
  const AScope: RawUtf8);
begin
  FRepositories.Clear; // built again from the new defaults on first use
  FDefaultStore := AStore;
  FCipher := ACipher;
  FScope := AScope;
  FClosed := False;
end;

class procedure TRadPropertiesStore.SetDatabase(const AStore: IRadStateStore);
begin
  FRepositories.Clear;
  FDatabaseStore := AStore;
end;

class procedure TRadPropertiesStore.SaveLive;
var
  LStore: TRadPropertiesStore;
begin
  if FLive = nil then
    Exit;
  for LStore in FLive.ToArray do
    if LStore.Restored and not LStore.Saved then
      SafeSave(LStore);
end;

class procedure TRadPropertiesStore.Shutdown;
begin
  if FClosed then
    Exit;
  SaveLive; // forms still open at shutdown would otherwise save after the repository is gone
  ClearProviders;
  FRepositories.Clear;
  FDefaultStore := nil;
  FDatabaseStore := nil;
  FCipher := nil;
  FClosed := True;
end;

class function TRadPropertiesStore.Repository: TRadStateRepository;
var
  LError: string;
begin
  Result := RepositoryFor(stDefault, '', False, LError);
end;

function IsRelativeRoot(const ARoot: string): Boolean;
var
  LPart: string;
begin
  Result := (ExtractFileDrive(ARoot) = '') and not ARoot.StartsWith('\') and not ARoot.StartsWith('/');
  if Result then
    for LPart in ARoot.Split(['\', '/']) do
      if LPart = '..' then
        Exit(False);
end;

function FolderOf(const ARoot: string): string;
begin
  if ARoot = '' then
    Result := RAD_STATE_FOLDER
  else
    Result := ARoot;
end;

class function TRadPropertiesStore.StoreFor(AType: TRadStorageType; const ARoot: string;
  out AError: string): IRadStateStore;
begin
  Result := nil;
  case AType of
    stDefault:
      begin
        if FDefaultStore = nil then
          FDefaultStore := TRadFileStateStore.Create;
        Result := FDefaultStore;
      end;
    stDatabase:
      if FDatabaseStore = nil then
        AError := SNoDatabase
      else
        Result := FDatabaseStore;
  else
    if IsRelativeRoot(ARoot) then
      Result := TRadFileStateStore.Create(FILE_BASES[AType], FolderOf(ARoot))
    else
      AError := Format(SRootOutside, [ARoot]);
  end;
end;

class function TRadPropertiesStore.RepositoryFor(AType: TRadStorageType; const ARoot: string;
  AEncrypted: Boolean; out AError: string): TRadStateRepository;
var
  LId: string;
  LStore: IRadStateStore;
begin
  Result := nil;
  AError := '';
  if FClosed then
    Exit;
  LId := Format('%d|%d', [Ord(AType), Ord(AEncrypted)]);
  if AType in FILE_TYPES then
    LId := LId + '|' + ARoot; // the root is a folder only for files
  if FRepositories.TryGetValue(LId, Result) then
    Exit;
  LStore := StoreFor(AType, ARoot, AError);
  if LStore = nil then
    Exit;
  Result := TRadStateRepository.Create(LStore, CipherOf, AEncrypted);
  FRepositories.Add(LId, Result);
end;

class function TRadPropertiesStore.CipherOf: IRadCipher;
var
  LKey: TSha256Digest;
begin
  if FCipher <> nil then
    Exit(FCipher);
  if FBuiltInCipher = nil then
  begin
    // shortcut: anyone with this library and the exe name derives the key; Kur's key is the real protection.
    LKey := Sha256Digest(BUILT_IN_KEY_SALT + StringToUtf8(System.SysUtils.LowerCase(ChangeFileExt(ExtractFileName(ParamStr(0)), ''))));
    try
      FBuiltInCipher := TRadAesGcmCipher.Create(LKey);
    finally
      FillZero(LKey);
    end;
  end;
  Result := FBuiltInCipher;
end;

class procedure TRadPropertiesStore.Prefetch;
var
  LType: TRadStorageType;
  LEncrypted: Boolean;
  LRepo: TRadStateRepository;
  LError: string;
begin
  // Plain and encrypted repositories keep separate caches; prefetch each one a store may use.
  for LType in [stDefault, stDatabase] do
    for LEncrypted := False to True do
    begin
      LRepo := RepositoryFor(LType, '', LEncrypted, LError);
      if LRepo <> nil then
        LRepo.Prefetch(FScope);
    end;
end;

class procedure TRadPropertiesStore.RegisterProvider(const AProvider: IRadStateProvider);
var
  I: Integer;
begin
  for I := FProviders.Count - 1 downto 0 do
    if FProviders[I].Name = AProvider.Name then
      FProviders.Delete(I);
  FProviders.Add(AProvider);
end;

class procedure TRadPropertiesStore.ClearProviders;
begin
  if FProviders <> nil then
    FProviders.Clear;
end;

class function TRadPropertiesStore.Scope: RawUtf8;
begin
  Result := FScope;
end;

class procedure TRadPropertiesStore.SetScope(const AScope: RawUtf8);
begin
  FScope := AScope;
end;

{ TRadPropertiesStore }

constructor TRadPropertiesStore.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FActive := True;
  FOptions := RAD_STATE_DEFAULT_OPTIONS;
  FItems := TRadStateItems.Create(Self, TRadStateItem);
  FStoredValues := TRadStoredValues.Create(Self, TRadStoredValue);
  FValues := DocDict(mFastFloat);
  if not (csDesigning in ComponentState) then
    FLive.Add(Self);
end;

destructor TRadPropertiesStore.Destroy;
begin
  if FLive <> nil then
    FLive.Remove(Self);
  if FHook <> nil then
    TRadStateHook(FHook).Detach(Self);
  FItems.Free;
  FStoredValues.Free;
  FAttached.Free;
  inherited;
end;

procedure TRadPropertiesStore.Loaded;
begin
  inherited;
  if (csDesigning in ComponentState) or not FActive then
    Exit;
  if (Owner is TCustomForm) or (Owner is TDataModule) then
    FHook := TRadStateHook.Attach(Self);
end;

procedure TRadPropertiesStore.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited;
  if AOperation <> opRemove then
    Exit;
  // While the owner is destroyed every child already carries csDestroying, so items are
  // only cleared then: deleting them would touch components that are already gone.
  if FAttached <> nil then
    FAttached.Remove(AComponent);
  if AComponent = FHook then
    FHook := nil
  else if FItems <> nil then
    FItems.ComponentRemoved(AComponent, not (csDestroying in ComponentState));
end;

procedure TRadPropertiesStore.SetItems(const AValue: TRadStateItems);
begin
  FItems.Assign(AValue);
end;

procedure TRadPropertiesStore.SetStoredValues(const AValue: TRadStoredValues);
begin
  FStoredValues.Assign(AValue);
end;

function TRadPropertiesStore.OwnerClassName: RawUtf8;
begin
  if Owner <> nil then
    Result := StringToUtf8(Owner.ClassName)
  else
    Result := StringToUtf8(ClassName);
end;

function TRadPropertiesStore.StoreRepository(out AError: string): TRadStateRepository;
begin
  Result := RepositoryFor(FStorageType, FStorageRoot, FEncrypted, AError);
end;

function TRadPropertiesStore.Key: TRadStateKey;
var
  LName: RawUtf8;
begin
  if FStorageName <> '' then
    LName := StringToUtf8(FStorageName)
  else
    LName := OwnerClassName;
  if (FStorageRoot <> '') and not (FStorageType in FILE_TYPES) then
    LName := StringToUtf8(StringReplace(ExcludeTrailingPathDelimiter(FStorageRoot), '\', ROOT_SEPARATOR,
      [rfReplaceAll])) + ROOT_SEPARATOR + LName;
  Result := TRadStateKey.Make(FScope, LName);
  if Assigned(FOnGetKey) then
    FOnGetKey(Self, Result);
end;

function TRadPropertiesStore.CurrentPpi: Integer;
begin
  if Owner is TControl then
    Result := TControl(Owner).CurrentPPI
  else
    Result := Screen.PixelsPerInch;
end;

procedure TRadPropertiesStore.AddError(const AText: RawUtf8);
var
  LCount: Integer;
begin
  LCount := Length(FErrors);
  SetLength(FErrors, LCount + 1);
  FErrors[LCount] := AText;
  LogWarning(StringToUtf8(Name) + ': ' + AText);
end;

{ load }

function TRadPropertiesStore.Load: Boolean;
var
  LRepo: TRadStateRepository;
  LError: string;
begin
  FErrors := nil;
  FDoc := nil;
  FRestored := True; // a load was attempted, so closing may save even without a record
  FSaved := False;
  FResetPending := False;
  LRepo := StoreRepository(LError);
  Result := (LRepo <> nil) and LRepo.Load(Key, FDoc);
  if LError <> '' then
    AddError(StringToUtf8(LError))
  else if (LRepo <> nil) and not Result and (LRepo.LastError <> '') then
    AddError(StringToUtf8(LRepo.LastError));
  if Assigned(FOnLoad) then
    FOnLoad(Self, True);
  if FBases = nil then
    CaptureBases; // once, before anything is applied: the designed state
  if FDoc <> nil then
    ApplyDoc;
  if Assigned(FOnLoad) then
    FOnLoad(Self, False);
end;

procedure TRadPropertiesStore.ApplyDoc;
var
  LLayout: Boolean;
begin
  if soValues in FOptions then
    ApplyValues;
  // Version gates only the layout: a changed form no longer fits it. Participants carry their
  // own version, so shortcuts or grid layouts survive a Version bump.
  LLayout := TRadStateDoc.VersionMatches(FDoc, FVersion);
  BeginApply;
  try
    if LLayout and (soPlacement in FOptions) then
      ApplyPlacement;
    if LLayout and (soProps in FOptions) then
      ApplyProps;
    if soCustom in FOptions then
    begin
      ApplyCustom;
      ApplyProviders;
    end;
  finally
    EndApply;
  end;
end;

function RedrawTarget(AOwner: TComponent): TWinControl;
begin
  Result := nil;
  if (AOwner is TWinControl) and TWinControl(AOwner).HandleAllocated and TWinControl(AOwner).Visible then
    Result := TWinControl(AOwner);
end;

procedure TRadPropertiesStore.BeginApply;
begin
  // Measured on 50 edits: 40.6 ms unlocked, 15.4 ms with both locks (spec, Ölçümler).
  if Owner is TWinControl then
    TWinControl(Owner).DisableAlign;
  if RedrawTarget(Owner) <> nil then
    SendMessage(RedrawTarget(Owner).Handle, WM_SETREDRAW, 0, 0);
end;

procedure TRadPropertiesStore.EndApply;
var
  LTarget: TWinControl;
begin
  LTarget := RedrawTarget(Owner);
  if LTarget <> nil then
  begin
    SendMessage(LTarget.Handle, WM_SETREDRAW, 1, 0);
    RedrawWindow(LTarget.Handle, nil, 0, RDW_ERASE or RDW_FRAME or RDW_INVALIDATE or RDW_ALLCHILDREN);
  end;
  if Owner is TWinControl then
    TWinControl(Owner).EnableAlign;
end;

procedure TRadPropertiesStore.ApplyValues;
var
  LSection: IDocDict;
begin
  if TRadStateDoc.Section(FDoc, RAD_STATE_SECTION_VALUES, LSection) then
    FValues := LSection.Copy // the section is a reference into FDoc
  else
    FValues := DocDict(mFastFloat);
end;

function ReadNormalRect(const AForm: IDocDict; out ARect: TRect): Boolean;
var
  LList: IDocList;
begin
  ARect := TRect.Empty;
  if not AForm.Get(FIELD_NORMAL, LList) or (LList.Len <> 4) then
    Exit(False);
  ARect := Rect(Integer(LList.I[0]), Integer(LList.I[1]), Integer(LList.I[2]), Integer(LList.I[3]));
  Result := (ARect.Width > 0) and (ARect.Height > 0);
end;

function IsOnAnyMonitor(const ARect: TRect): Boolean;
begin
  Result := (Screen.MonitorFromPoint(ARect.TopLeft, mdNull) <> nil) and
    (Screen.MonitorFromPoint(Point(ARect.Right - 1, ARect.Bottom - 1), mdNull) <> nil);
end;

procedure TRadPropertiesStore.ApplyPlacement;
var
  LSection: IDocDict;
  LRect: TRect;
  LScale: TRadStateScale;
  LForm: TCustomForm;
begin
  if not (Owner is TCustomForm) or not TRadStateDoc.Section(FDoc, RAD_STATE_SECTION_FORM, LSection) or
    not ReadNormalRect(LSection, LRect) then
    Exit;
  LForm := TCustomForm(Owner);
  // Position stays where it was saved; only the size follows a DPI change.
  LScale := TRadStateScale.Make(TRadStateDoc.Ppi(FDoc), CurrentPpi);
  LRect := Bounds(LRect.Left, LRect.Top, LScale.Apply(LRect.Width), LScale.Apply(LRect.Height));
  if not IsOnAnyMonitor(LRect) then
  begin
    AddError('form: saved placement is off every monitor');
    Exit;
  end;
  // OnShow runs before the VCL centers the form (CMShowingChanged), so placement is set here.
  TCustomFormAccess(LForm).Position := poDesigned;
  if TCustomFormAccess(LForm).BorderStyle in SIZEABLE_BORDERS then
    LForm.SetBounds(LRect.Left, LRect.Top, LRect.Width, LRect.Height)
  else
    LForm.SetBounds(LRect.Left, LRect.Top, LForm.Width, LForm.Height);
  if LSection.U[FIELD_STATE] = STATE_MAXIMIZED then
    TCustomFormAccess(LForm).WindowState := wsMaximized;
  LSection.Get(FIELD_ACTIVE_CONTROL, FActiveControlName);
end;

procedure TRadPropertiesStore.ApplyProps;
var
  LProps, LValues: IDocDict;
  LResult: TRadStateApplyResult;
  LScale: TRadStateScale;
  I: Integer;
  LError: RawUtf8;
begin
  if not TRadStateDoc.Section(FDoc, RAD_STATE_SECTION_PROPS, LProps) then
    Exit;
  LScale := TRadStateScale.Make(TRadStateDoc.Ppi(FDoc), CurrentPpi);
  for I := 0 to FItems.Count - 1 do
    if (FItems[I].Component <> nil) and
      LProps.Get(StringToUtf8(FItems[I].Component.Name), LValues) then
    begin
      LResult := TRadStatePaths.Apply(FItems[I].Component, FItems[I].Properties, LValues, LScale);
      for LError in LResult.Errors do
        AddError(StringToUtf8(FItems[I].Component.Name) + NAME_SEPARATOR + LError);
    end;
end;

function SectionKey(const AKind, AName: RawUtf8): RawUtf8;
begin
  Result := AKind + RAD_STATE_SECTION_KEY_SEPARATOR + AName;
end;

function StateVersionOf(AComponent: TComponent): Integer;
var
  LVersion: IRadStateVersion;
begin
  Result := 0;
  if Supports(AComponent, IRadStateVersion, LVersion) then
    Result := LVersion.StateVersion;
end;

function TRadPropertiesStore.Participants: TArray<TComponent>;
var
  LList: TList<TComponent>;
  I: Integer;
begin
  LList := TList<TComponent>.Create;
  try
    for I := 0 to FItems.Count - 1 do
      if Supports(FItems[I].Component, IRadStateful) and (LList.IndexOf(FItems[I].Component) < 0) then
        LList.Add(FItems[I].Component);
    if FAttached <> nil then
      for I := 0 to FAttached.Count - 1 do
        if LList.IndexOf(FAttached[I]) < 0 then
          LList.Add(FAttached[I]);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

procedure TRadPropertiesStore.ApplyCustom;
var
  LCustom, LValues: IDocDict;
  LStateful: IRadStateful;
  LComponent: TComponent;
  LName: RawUtf8;
begin
  if not TRadStateDoc.Section(FDoc, RAD_STATE_SECTION_CUSTOM, LCustom) then
    Exit;
  for LComponent in Participants do
  begin
    LName := StringToUtf8(LComponent.Name);
    if LCustom.Get(LName, LValues) and Supports(LComponent, IRadStateful, LStateful) and
      (TRadStateDoc.SectionVersion(FDoc, SectionKey(RAD_STATE_SECTION_CUSTOM, LName)) = StateVersionOf(LComponent)) then
      try
        LStateful.LoadState(LValues);
      except
        on E: Exception do // boundary: one participant must not stop the others
          AddError(LName + ': ' + StringToUtf8(E.Message));
      end;
  end;
end;

function Fingerprint(const ADoc: IDocDict): Int64;
var
  LJson: RawUtf8;
begin
  LJson := ADoc.Json;
  Result := Int64(crc32c(0, pointer(LJson), Length(LJson))) + 1; // never 0: 0 means unknown
end;

procedure TRadPropertiesStore.CaptureBases;
var
  LValues: IDocDict;
  LProvider: IRadStateProvider;
begin
  FBases := DocDict(mFastFloat);
  if not (soCustom in FOptions) then
    Exit;
  for LProvider in FProviders.ToArray do
    if Supports(LProvider, IRadStateDesignBound) then
      try
        if LProvider.Wants(Owner) then
        begin
          LValues := DocDict(mFastFloat);
          LProvider.Save(Owner, LValues);
          FBases.I[LProvider.Name] := Fingerprint(LValues);
        end;
      except
        on E: Exception do // boundary: one provider must not stop the others
          AddError(LProvider.Name + ': ' + StringToUtf8(E.Message));
      end;
end;

function TRadPropertiesStore.BaseMatches(const AProvider: IRadStateProvider): Boolean;
var
  LBase: Int64;
begin
  if not Supports(AProvider, IRadStateDesignBound) then
    Exit(True);
  LBase := 0;
  Result := (FBases <> nil) and FBases.Get(AProvider.Name, LBase) and (LBase =
    TRadStateDoc.MapValue(FDoc, RAD_STATE_FIELD_BASES, SectionKey(RAD_STATE_SECTION_EXT, AProvider.Name)));
end;

procedure TRadPropertiesStore.ApplyProviders;
var
  LExt, LValues: IDocDict;
  LProvider: IRadStateProvider;
begin
  if not TRadStateDoc.Section(FDoc, RAD_STATE_SECTION_EXT, LExt) then
    Exit;
  for LProvider in FProviders.ToArray do
    if LExt.Get(LProvider.Name, LValues) and BaseMatches(LProvider) and
      (TRadStateDoc.SectionVersion(FDoc, SectionKey(RAD_STATE_SECTION_EXT, LProvider.Name)) = LProvider.Version) then
      try
        if LProvider.Wants(Owner) then
          LProvider.Load(Owner, LValues);
      except
        on E: Exception do // boundary: one provider must not stop the others
          AddError(LProvider.Name + ': ' + StringToUtf8(E.Message));
      end;
end;

procedure TRadPropertiesStore.ApplyActiveControl;
var
  LControl: TComponent;
begin
  if not (soActiveControl in FOptions) or (FActiveControlName = '') or not (Owner is TCustomForm) then
    Exit;
  LControl := Owner.FindComponent(Utf8ToString(FActiveControlName));
  if (LControl is TWinControl) and TWinControl(LControl).CanFocus then
    TCustomForm(Owner).ActiveControl := TWinControl(LControl);
end;

{ save }

function TRadPropertiesStore.Save: Boolean;
var
  LRepo: TRadStateRepository;
  LError: string;
begin
  Result := False;
  LRepo := StoreRepository(LError); // Load already reported LError
  if not FActive or not FRestored or FResetPending or (LRepo = nil) then
    Exit; // never overwrite a record that this owner did not get to read, or one just reset
  if Assigned(FOnSave) then
    FOnSave(Self, True);
  Result := LRepo.Save(Key, BuildDoc);
  FSaved := True;
  if Assigned(FOnSave) then
    FOnSave(Self, False);
end;

function TRadPropertiesStore.BuildDoc: IDocDict;
begin
  Result := TRadStateDoc.New(Key, OwnerClassName, FVersion, CurrentPpi);
  if soPlacement in FOptions then
    CapturePlacement(Result);
  if soProps in FOptions then
    CaptureProps(Result);
  if soCustom in FOptions then
  begin
    CaptureCustom(Result);
    CaptureProviders(Result);
  end;
  if (soValues in FOptions) and (FValues.Len > 0) then
    Result.D[RAD_STATE_SECTION_VALUES] := FValues;
end;

function NormalRect(AForm: TCustomForm): TRect;
var
  LPlacement: TWindowPlacement;
begin
  Result := AForm.BoundsRect;
  if (TCustomFormAccess(AForm).WindowState = wsNormal) or not AForm.HandleAllocated then
    Exit;
  // Maximized: the normal rectangle is in workspace coordinates of the primary monitor.
  LPlacement.length := SizeOf(LPlacement);
  if GetWindowPlacement(AForm.Handle, @LPlacement) then
  begin
    Result := LPlacement.rcNormalPosition;
    Result.Offset(Screen.PrimaryMonitor.WorkareaRect.Left - Screen.PrimaryMonitor.BoundsRect.Left,
      Screen.PrimaryMonitor.WorkareaRect.Top - Screen.PrimaryMonitor.BoundsRect.Top);
  end;
end;

procedure TRadPropertiesStore.CapturePlacement(const ADoc: IDocDict);
var
  LForm: TCustomForm;
  LSection: IDocDict;
  LRect: TRect;
begin
  if not (Owner is TCustomForm) then
    Exit;
  LForm := TCustomForm(Owner);
  LRect := NormalRect(LForm);
  LSection := DocDict(mFastFloat);
  if TCustomFormAccess(LForm).WindowState = wsMaximized then
    LSection.U[FIELD_STATE] := STATE_MAXIMIZED
  else
    LSection.U[FIELD_STATE] := STATE_NORMAL;
  LSection.L[FIELD_NORMAL] := DocList([LRect.Left, LRect.Top, LRect.Right, LRect.Bottom]);
  if (soActiveControl in FOptions) and (LForm.ActiveControl <> nil) then
    LSection.U[FIELD_ACTIVE_CONTROL] := StringToUtf8(LForm.ActiveControl.Name);
  ADoc.D[RAD_STATE_SECTION_FORM] := LSection;
end;

procedure TRadPropertiesStore.CaptureProps(const ADoc: IDocDict);
var
  LProps: IDocDict;
  I: Integer;
  LItem: TRadStateItem;
begin
  LProps := DocDict(mFastFloat);
  for I := 0 to FItems.Count - 1 do
  begin
    LItem := FItems[I];
    if (LItem.Component <> nil) and (LItem.Component.Name <> '') and (LItem.Properties.Count > 0) then
      LProps.D[StringToUtf8(LItem.Component.Name)] :=
        DocDict(TRadStatePaths.Capture(LItem.Component, LItem.Properties), mFastFloat);
  end;
  if LProps.Len > 0 then
    ADoc.D[RAD_STATE_SECTION_PROPS] := LProps;
end;

procedure TRadPropertiesStore.CaptureCustom(const ADoc: IDocDict);
var
  LCustom, LValues: IDocDict;
  LStateful: IRadStateful;
  LComponent: TComponent;
  LName: RawUtf8;
begin
  LCustom := DocDict(mFastFloat);
  for LComponent in Participants do
    if Supports(LComponent, IRadStateful, LStateful) then
    begin
      LName := StringToUtf8(LComponent.Name);
      LValues := DocDict(mFastFloat);
      LStateful.SaveState(LValues);
      if LValues.Len = 0 then
        Continue;
      LCustom.D[LName] := LValues;
      TRadStateDoc.SetSectionVersion(ADoc, SectionKey(RAD_STATE_SECTION_CUSTOM, LName), StateVersionOf(LComponent));
    end;
  if LCustom.Len > 0 then
    ADoc.D[RAD_STATE_SECTION_CUSTOM] := LCustom;
end;

procedure TRadPropertiesStore.CaptureProviders(const ADoc: IDocDict);
var
  LExt, LValues: IDocDict;
  LProvider: IRadStateProvider;
begin
  LExt := DocDict(mFastFloat);
  for LProvider in FProviders.ToArray do
    if LProvider.Wants(Owner) then
    begin
      LValues := DocDict(mFastFloat);
      LProvider.Save(Owner, LValues);
      if LValues.Len = 0 then
        Continue;
      LExt.D[LProvider.Name] := LValues;
      TRadStateDoc.SetSectionVersion(ADoc, SectionKey(RAD_STATE_SECTION_EXT, LProvider.Name), LProvider.Version);
      if FBases <> nil then
        TRadStateDoc.SetMapValue(ADoc, RAD_STATE_FIELD_BASES, SectionKey(RAD_STATE_SECTION_EXT, LProvider.Name),
          FBases.I[LProvider.Name]);
    end;
  if LExt.Len > 0 then
    ADoc.D[RAD_STATE_SECTION_EXT] := LExt;
end;

procedure TRadPropertiesStore.Reset;
var
  LRepo: TRadStateRepository;
  LError: string;
begin
  LRepo := StoreRepository(LError);
  if LRepo <> nil then
    LRepo.Delete(Key);
  FValues := DocDict(mFastFloat);
  FDoc := nil;
end;

procedure TRadPropertiesStore.Reapply;
begin
  if (FDoc = nil) or not (soCustom in FOptions) then
    Exit;
  BeginApply;
  try
    ApplyCustom;
    ApplyProviders;
  finally
    EndApply;
  end;
end;

class procedure TRadPropertiesStore.ReapplyOwner(AOwner: TComponent);
var
  I: Integer;
begin
  if AOwner = nil then
    Exit;
  for I := 0 to AOwner.ComponentCount - 1 do
    if AOwner.Components[I] is TRadPropertiesStore then
      TRadPropertiesStore(AOwner.Components[I]).Reapply;
end;

procedure TRadPropertiesStore.ResetSaved;
begin
  Reset;
  FResetPending := True;
  FSaved := True;
end;

procedure TRadPropertiesStore.Attach(AComponent: TComponent);
begin
  if (AComponent = nil) or (AComponent.Name = '') or not Supports(AComponent, IRadStateful) then
    raise ERadFormState.CreateFmt(SAttachNeedsStateful, [Name]);
  if FAttached = nil then
    FAttached := TList<TComponent>.Create;
  if FAttached.IndexOf(AComponent) < 0 then
  begin
    FAttached.Add(AComponent);
    AComponent.FreeNotification(Self);
  end;
end;

procedure TRadPropertiesStore.Detach(AComponent: TComponent);
begin
  if (FAttached <> nil) and (FAttached.Remove(AComponent) >= 0) then
    AComponent.RemoveFreeNotification(Self);
end;

{ values }

function TRadPropertiesStore.TryStoredValue(const AName: string; AType: TRadStoredValueType;
  out AValue: Variant): Boolean;
var
  LRaw: Variant;
  LDefault: TRadStoredValue;
begin
  if FValues.Get(StringToUtf8(AName), LRaw) and TRadStoredValue.Convert(LRaw, AType, AValue) then
    Exit(True);
  LDefault := FStoredValues.Find(AName);
  Result := (LDefault <> nil) and TRadStoredValue.Convert(LDefault.Value, AType, AValue);
end;

function TRadPropertiesStore.GetStoredValue(const AName: string): Variant;
var
  LDefault: TRadStoredValue;
  LType: TRadStoredValueType;
begin
  LDefault := FStoredValues.Find(AName);
  LType := svtVariant;
  if LDefault <> nil then
    LType := LDefault.ValueType;
  if not TryStoredValue(AName, LType, Result) then
    Result := TRadStoredValue.EmptyOf(LType);
end;

procedure TRadPropertiesStore.SetStoredValue(const AName: string; const AValue: Variant);
begin
  FValues.Item[StringToUtf8(AName)] := AValue;
end;

function TRadPropertiesStore.GetInteger(const AName: string; ADefault: Integer): Integer;
var
  LValue: Variant;
  LInt: Int64;
begin
  Result := ADefault;
  if TryStoredValue(AName, svtInteger, LValue) then
  begin
    LInt := LValue;
    if (LInt >= Low(Integer)) and (LInt <= High(Integer)) then
      Result := LInt;
  end;
end;

function TRadPropertiesStore.GetDouble(const AName: string; ADefault: Double): Double;
var
  LValue: Variant;
begin
  if TryStoredValue(AName, svtFloat, LValue) then
    Result := LValue
  else
    Result := ADefault;
end;

function TRadPropertiesStore.GetString(const AName: string; const ADefault: string): string;
var
  LValue: Variant;
begin
  if TryStoredValue(AName, svtString, LValue) then
    Result := LValue
  else
    Result := ADefault;
end;

function TRadPropertiesStore.GetBoolean(const AName: string; ADefault: Boolean): Boolean;
var
  LValue: Variant;
begin
  if TryStoredValue(AName, svtBoolean, LValue) then
    Result := LValue
  else
    Result := ADefault;
end;

function TRadPropertiesStore.GetDate(const AName: string; ADefault: TDateTime): TDateTime;
var
  LValue: Variant;
begin
  if TryStoredValue(AName, svtDateTime, LValue) then
    Result := VarToDateTime(LValue)
  else
    Result := ADefault;
end;

end.
