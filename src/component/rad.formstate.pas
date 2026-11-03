unit rad.formstate;

{ Entry unit of the form-state system (docs/specs/rad.formstate.md).
  uses rad.formstate;  TRadFormState.Kur(TRadFormState.FileStore, 'emrah');  ...  TRadFormState.Kapat; }

interface

uses
  rad.cipher,
  rad.formstate.core,
  rad.formstate.store,
  rad.formstate.component,
  mormot.core.base;

type
  TRadPropertiesStore = rad.formstate.component.TRadPropertiesStore;
  TRadStateItem = rad.formstate.component.TRadStateItem;
  TRadStoredValue = rad.formstate.component.TRadStoredValue;
  TRadStateOption = rad.formstate.component.TRadStateOption;
  TRadStateOptions = rad.formstate.component.TRadStateOptions;
  TRadStateEvent = rad.formstate.component.TRadStateEvent;
  TRadStateKeyEvent = rad.formstate.component.TRadStateKeyEvent;
  TRadStateKey = rad.formstate.core.TRadStateKey;
  IRadStateful = rad.formstate.core.IRadStateful;
  IRadStateStore = rad.formstate.store.IRadStateStore;
  TRadStateEntry = rad.formstate.store.TRadStateEntry;
  TRadStateEntries = rad.formstate.store.TRadStateEntries;
  TRadFileStateStore = rad.formstate.store.TRadFileStateStore;
  TRadCallbackStateStore = rad.formstate.store.TRadCallbackStateStore;
  TRadStateRepository = rad.formstate.store.TRadStateRepository;
  ERadFormState = rad.formstate.store.ERadFormState;
  IRadCipher = rad.cipher.IRadCipher;
  TRadAesGcmCipher = rad.cipher.TRadAesGcmCipher;

const
  soPlacement = rad.formstate.component.soPlacement;
  soActiveControl = rad.formstate.component.soActiveControl;
  soProps = rad.formstate.component.soProps;
  soValues = rad.formstate.component.soValues;
  soCustom = rad.formstate.component.soCustom;

type
  /// <summary>One setup call for every TRadPropertiesStore in the application.</summary>
  TRadFormState = class abstract
  public
    /// <summary>Where and how states are saved. Closes any earlier setup first.</summary>
    /// <param name="AScope">User or company part of every key, e.g. 'emrah'.</param>
    /// <param name="ACipher">nil saves plain JSON; existing plain records stay readable later.</param>
    class procedure Kur(const AStore: IRadStateStore; const AScope: RawUtf8 = '';
      const ACipher: IRadCipher = nil); static;
    /// <summary>Saves open forms that have not saved yet, then releases the store. Safe to call twice.</summary>
    class procedure Kapat; static;
    /// <summary>Reads every record of the current scope in one store call.</summary>
    class procedure Prefetch; static;
    /// <summary>Changes the scope after login without rebuilding the store.</summary>
    class procedure SetScope(const AScope: RawUtf8); static;
    /// <summary>One file per record under AFolder (default %LOCALAPPDATA%\exe name\state).</summary>
    class function FileStore(const AFolder: string = ''): IRadStateStore; static;
    /// <summary>Routes to TRadCallbackStateStore.DoLoad/DoSave/DoDelete/DoLoadScope.</summary>
    class function CallbackStore: IRadStateStore; static;
    class function Repository: TRadStateRepository; static;
  end;

implementation

class procedure TRadFormState.Kur(const AStore: IRadStateStore; const AScope: RawUtf8;
  const ACipher: IRadCipher);
begin
  TRadPropertiesStore.Configure(TRadStateRepository.Create(AStore, ACipher), AScope);
end;

class procedure TRadFormState.Kapat;
begin
  TRadPropertiesStore.Shutdown;
end;

class procedure TRadFormState.Prefetch;
begin
  if TRadPropertiesStore.Repository <> nil then
    TRadPropertiesStore.Repository.Prefetch(TRadPropertiesStore.Scope);
end;

class procedure TRadFormState.SetScope(const AScope: RawUtf8);
begin
  TRadPropertiesStore.SetScope(AScope);
end;

class function TRadFormState.FileStore(const AFolder: string): IRadStateStore;
begin
  Result := TRadFileStateStore.Create(AFolder);
end;

class function TRadFormState.CallbackStore: IRadStateStore;
begin
  Result := TRadCallbackStateStore.Create;
end;

class function TRadFormState.Repository: TRadStateRepository;
begin
  Result := TRadPropertiesStore.Repository;
end;

end.
