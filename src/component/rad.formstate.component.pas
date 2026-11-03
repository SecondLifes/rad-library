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
  rad.formstate.core,
  rad.formstate.store;

type
  TRadStateOption = (soPlacement, soActiveControl, soProps, soValues, soCustom);
  TRadStateOptions = set of TRadStateOption;

const
  RAD_STATE_DEFAULT_OPTIONS = [soPlacement, soProps, soValues, soCustom];

type
  TRadPropertiesStore = class;

  /// <summary>ABefore: the document is read but not applied yet, or the save has not started.</summary>
  TRadStateEvent = procedure(Sender: TRadPropertiesStore; const ABefore: Boolean) of object;
  TRadStateKeyEvent = procedure(Sender: TRadPropertiesStore; var AKey: TRadStateKey) of object;

  /// <summary>One component and the dotted property paths saved for it.</summary>
  TRadStateItem = class(TCollectionItem)
  private
    FComponent: TComponent;
    FProperties: TStrings;
    procedure SetComponent(const AValue: TComponent);
    procedure SetProperties(const AValue: TStrings);
    function OwnerStore: TRadPropertiesStore;
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

  /// <summary>A named value and its design-time default.</summary>
  TRadStoredValue = class(TCollectionItem)
  private
    FName: string;
    FValue: Variant;
    function IsValueStored: Boolean;
  protected
    function GetDisplayName: string; override;
  public
    procedure Assign(ASource: TPersistent); override;
  published
    property Name: string read FName write FName;
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
    class var FRepository: TRadStateRepository;
    class var FScope: RawUtf8;
    class var FClosed: Boolean;
    class var FLive: TList<TRadPropertiesStore>;
    class constructor CreateClass;
    class destructor DestroyClass;
    class procedure SaveLive; static;
  private
    FActive: Boolean;
    FOptions: TRadStateOptions;
    FVersion: Integer;
    FStorageName: string;
    FItems: TRadStateItems;
    FStoredValues: TRadStoredValues;
    FValues: IDocDict;
    FDoc: IDocDict;
    FHook: TComponent;
    FRestored: Boolean;
    FSaved: Boolean;
    FActiveControlName: RawUtf8;
    FErrors: TRawUtf8DynArray;
    FOnLoad: TRadStateEvent;
    FOnSave: TRadStateEvent;
    FOnGetKey: TRadStateKeyEvent;
    procedure SetItems(const AValue: TRadStateItems);
    procedure SetStoredValues(const AValue: TRadStoredValues);
    function GetStoredValue(const AName: string): Variant;
    procedure SetStoredValue(const AName: string; const AValue: Variant);
    function OwnerClassName: RawUtf8;
    function CurrentPpi: Integer;
    procedure AddError(const AText: RawUtf8);
    procedure ApplyDoc;
    procedure BeginApply;
    procedure EndApply;
    procedure ApplyValues;
    procedure ApplyPlacement;
    procedure ApplyProps;
    procedure ApplyCustom;
    function BuildDoc: IDocDict;
    procedure CapturePlacement(const ADoc: IDocDict);
    procedure CaptureProps(const ADoc: IDocDict);
    procedure CaptureCustom(const ADoc: IDocDict);
  protected
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Sets the repository (taken over and freed later) and the scope. Used by TRadFormState.Kur.</summary>
    class procedure Configure(const ARepository: TRadStateRepository; const AScope: RawUtf8); static;
    /// <summary>Saves every live store that loaded and has not saved, then frees the repository.</summary>
    class procedure Shutdown; static;
    /// <summary>The configured repository; a default file store until Configure, nil after Shutdown.</summary>
    class function Repository: TRadStateRepository; static;
    class function Scope: RawUtf8; static;
    class procedure SetScope(const AScope: RawUtf8); static;
    /// <summary>Scope + owner class name (+ '.' + StorageName), after OnGetKey.</summary>
    function Key: TRadStateKey;
    /// <summary>Reads and applies the saved state. False when there is no usable record.</summary>
    function Load: Boolean;
    /// <summary>Writes the state. False when nothing was loaded yet, or the content did not change.</summary>
    function Save: Boolean;
    /// <summary>Deletes the saved record and forgets the runtime values.</summary>
    procedure Reset;
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
    /// <summary>Runtime value, else the StoredValues default, else Null.</summary>
    property StoredValue[const AName: string]: Variant read GetStoredValue write SetStoredValue;
  published
    property Active: Boolean read FActive write FActive default True;
    property Options: TRadStateOptions read FOptions write FOptions default RAD_STATE_DEFAULT_OPTIONS;
    property Version: Integer read FVersion write FVersion default 0;
    property StorageName: string read FStorageName write FStorageName;
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
  mormot.core.text,
  mormot.core.unicode,
  mormot.core.datetime,
  mormot.core.rtti,
  mormot.core.log;

const
  FIELD_STATE = 'state';
  FIELD_NORMAL = 'normal';
  FIELD_ACTIVE_CONTROL = 'activeControl';
  STATE_MAXIMIZED = 'wsMaximized';
  STATE_NORMAL = 'wsNormal';
  NAME_SEPARATOR = '.';
  SIZEABLE_BORDERS = [bsSizeable, bsSizeToolWin];

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
  LStore: TRadPropertiesStore;
begin
  LStore := OwnerStore;
  if (LStore <> nil) and not (csDestroying in LStore.ComponentState) then
    Component := nil;
  FProperties.Free;
  inherited;
end;

function TRadStateItem.OwnerStore: TRadPropertiesStore;
begin
  if (Collection <> nil) and (TRadStateItems(Collection).Owner is TRadPropertiesStore) then
    Result := TRadPropertiesStore(TRadStateItems(Collection).Owner)
  else
    Result := nil;
end;

procedure TRadStateItem.SetComponent(const AValue: TComponent);
var
  LStore: TRadPropertiesStore;
  LOld: TComponent;
begin
  if FComponent = AValue then
    Exit;
  LOld := FComponent;
  FComponent := AValue;
  LStore := OwnerStore;
  if LStore = nil then
    Exit;
  // Drop the link only when no other item still points at the old component.
  if (LOld <> nil) and not TRadStateItems(Collection).Refers(LOld) then
    LOld.RemoveFreeNotification(LStore);
  if AValue <> nil then
    AValue.FreeNotification(LStore);
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
    FValue := TRadStoredValue(ASource).Value;
  end
  else
    inherited;
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
end;

class destructor TRadPropertiesStore.DestroyClass;
begin
  Shutdown;
  FreeAndNil(FLive);
end;

class procedure TRadPropertiesStore.Configure(const ARepository: TRadStateRepository; const AScope: RawUtf8);
begin
  if FRepository <> ARepository then
    FreeAndNil(FRepository);
  FRepository := ARepository;
  FScope := AScope;
  FClosed := False;
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
  FreeAndNil(FRepository);
  FClosed := True;
end;

class function TRadPropertiesStore.Repository: TRadStateRepository;
begin
  if (FRepository = nil) and not FClosed then
    FRepository := TRadStateRepository.Create(TRadFileStateStore.Create);
  Result := FRepository;
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

function TRadPropertiesStore.Key: TRadStateKey;
var
  LName: RawUtf8;
begin
  LName := OwnerClassName;
  if FStorageName <> '' then
    LName := LName + NAME_SEPARATOR + StringToUtf8(FStorageName);
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
begin
  FErrors := nil;
  FDoc := nil;
  FRestored := True; // a load was attempted, so closing may save even without a record
  FSaved := False;
  LRepo := Repository;
  Result := (LRepo <> nil) and LRepo.Load(Key, FDoc);
  if (LRepo <> nil) and not Result and (LRepo.LastError <> '') then
    AddError(StringToUtf8(LRepo.LastError));
  if Assigned(FOnLoad) then
    FOnLoad(Self, True);
  if FDoc <> nil then
    ApplyDoc;
  if Assigned(FOnLoad) then
    FOnLoad(Self, False);
end;

procedure TRadPropertiesStore.ApplyDoc;
begin
  if soValues in FOptions then
    ApplyValues;
  if not TRadStateDoc.VersionMatches(FDoc, FVersion) then
    Exit; // the developer changed the form: its old layout no longer fits, values still do
  BeginApply;
  try
    if soPlacement in FOptions then
      ApplyPlacement;
    if soProps in FOptions then
      ApplyProps;
    if soCustom in FOptions then
      ApplyCustom;
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

procedure TRadPropertiesStore.ApplyCustom;
var
  LCustom, LValues: IDocDict;
  LStateful: IRadStateful;
  I: Integer;
begin
  if not TRadStateDoc.Section(FDoc, RAD_STATE_SECTION_CUSTOM, LCustom) then
    Exit;
  for I := 0 to FItems.Count - 1 do
    if Supports(FItems[I].Component, IRadStateful, LStateful) and
      LCustom.Get(StringToUtf8(FItems[I].Component.Name), LValues) then
      LStateful.LoadState(LValues);
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
begin
  Result := False;
  LRepo := Repository;
  if not FActive or not FRestored or (LRepo = nil) then
    Exit; // never overwrite a record that this owner did not get to read
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
    CaptureCustom(Result);
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
  I: Integer;
begin
  LCustom := DocDict(mFastFloat);
  for I := 0 to FItems.Count - 1 do
    if Supports(FItems[I].Component, IRadStateful, LStateful) then
    begin
      LValues := DocDict(mFastFloat);
      LStateful.SaveState(LValues);
      LCustom.D[StringToUtf8(FItems[I].Component.Name)] := LValues;
    end;
  if LCustom.Len > 0 then
    ADoc.D[RAD_STATE_SECTION_CUSTOM] := LCustom;
end;

procedure TRadPropertiesStore.Reset;
var
  LRepo: TRadStateRepository;
begin
  LRepo := Repository;
  if LRepo <> nil then
    LRepo.Delete(Key);
  FValues := DocDict(mFastFloat);
  FDoc := nil;
end;

{ values }

function TRadPropertiesStore.GetStoredValue(const AName: string): Variant;
var
  LDefault: TRadStoredValue;
begin
  if FValues.Get(StringToUtf8(AName), Result) then
    Exit;
  LDefault := FStoredValues.Find(AName);
  if LDefault <> nil then
    Result := LDefault.Value
  else
    Result := Null;
end;

procedure TRadPropertiesStore.SetStoredValue(const AName: string; const AValue: Variant);
begin
  FValues.Item[StringToUtf8(AName)] := AValue;
end;

function TRadPropertiesStore.GetInteger(const AName: string; ADefault: Integer): Integer;
begin
  if not VariantToInteger(StoredValue[AName], Result) then
    Result := ADefault;
end;

function TRadPropertiesStore.GetDouble(const AName: string; ADefault: Double): Double;
begin
  if not VariantToDouble(StoredValue[AName], Result) then
    Result := ADefault;
end;

function TRadPropertiesStore.GetString(const AName: string; const ADefault: string): string;
var
  LValue: Variant;
begin
  LValue := StoredValue[AName];
  if VarIsEmptyOrNull(LValue) then
    Result := ADefault
  else
    Result := VariantToString(LValue);
end;

function TRadPropertiesStore.GetBoolean(const AName: string; ADefault: Boolean): Boolean;
var
  LValue: Variant;
  LInt: Integer;
begin
  LValue := StoredValue[AName];
  if VarType(LValue) = varBoolean then
    Result := LValue
  else if VariantToInteger(LValue, LInt) then
    Result := LInt <> 0
  else
    Result := ADefault;
end;

function TRadPropertiesStore.GetDate(const AName: string; ADefault: TDateTime): TDateTime;
begin
  // JSON keeps a date as ISO text, so the value comes back as a string.
  if not VariantToDateTime(StoredValue[AName], Result) then
    Result := ADefault;
end;

end.
