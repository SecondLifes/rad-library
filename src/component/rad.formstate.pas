unit rad.formstate;

{ Entry unit of the form-state system (docs/specs/rad.formstate.md).
  uses rad.formstate;  TRadFormState.Kur(TRadFormState.FileStore, 'emrah');  ...  TRadFormState.Kapat; }

interface

uses
  Uni,
  rad.cipher,
  rad.formstate.core,
  rad.formstate.store,
  rad.formstate.component,
  rad.formstate.uni,
  rad.formstate.dev,
  Vcl.Forms,
  mormot.core.base;

type
  TRadPropertiesStore = rad.formstate.component.TRadPropertiesStore;
  TRadStateItem = rad.formstate.component.TRadStateItem;
  TRadStoredValue = rad.formstate.component.TRadStoredValue;
  TRadStoredValueType = rad.formstate.component.TRadStoredValueType;
  TRadStorageRoot = rad.formstate.store.TRadStorageRoot;
  TRadStateOption = rad.formstate.component.TRadStateOption;
  TRadStateOptions = rad.formstate.component.TRadStateOptions;
  TRadStateEvent = rad.formstate.component.TRadStateEvent;
  TRadStateKeyEvent = rad.formstate.component.TRadStateKeyEvent;
  TRadStateKey = rad.formstate.core.TRadStateKey;
  IRadStateful = rad.formstate.core.IRadStateful;
  IRadStateVersion = rad.formstate.core.IRadStateVersion;
  IRadStateProvider = rad.formstate.core.IRadStateProvider;
  IRadStateDesignBound = rad.formstate.core.IRadStateDesignBound;
  TRadGridStateProvider = rad.formstate.dev.TRadGridStateProvider;
  TRadLayoutStateProvider = rad.formstate.dev.TRadLayoutStateProvider;
  IRadStateStore = rad.formstate.store.IRadStateStore;
  TRadStateEntry = rad.formstate.store.TRadStateEntry;
  TRadStateEntries = rad.formstate.store.TRadStateEntries;
  TRadFileStateStore = rad.formstate.store.TRadFileStateStore;
  TRadCallbackStateStore = rad.formstate.store.TRadCallbackStateStore;
  TRadUniStateStore = rad.formstate.uni.TRadUniStateStore;
  TRadStateRepository = rad.formstate.store.TRadStateRepository;
  ERadFormState = rad.formstate.store.ERadFormState;
  IRadCipher = rad.cipher.IRadCipher;
  TRadAesGcmCipher = rad.cipher.TRadAesGcmCipher;

const
  RAD_STATE_DEFAULT_TABLE = rad.formstate.uni.RAD_STATE_DEFAULT_TABLE;
  soPlacement = rad.formstate.component.soPlacement;
  soActiveControl = rad.formstate.component.soActiveControl;
  soProps = rad.formstate.component.soProps;
  soValues = rad.formstate.component.soValues;
  soCustom = rad.formstate.component.soCustom;
  svtVariant = rad.formstate.component.svtVariant;
  svtString = rad.formstate.component.svtString;
  svtInteger = rad.formstate.component.svtInteger;
  svtFloat = rad.formstate.component.svtFloat;
  svtDateTime = rad.formstate.component.svtDateTime;
  svtBoolean = rad.formstate.component.svtBoolean;
  srLocalAppData = rad.formstate.store.srLocalAppData;
  srExeFolder = rad.formstate.store.srExeFolder;
  RAD_STATE_FOLDER = rad.formstate.store.RAD_STATE_FOLDER;

type
  /// <summary>One setup call for every TRadPropertiesStore in the application.</summary>
  TRadReopenProc = reference to procedure(AForm: TCustomForm);

  TRadFormState = class abstract
  public
    /// <summary>Host hook for ResetForm: close AForm and open it again the same way.</summary>
    class var Reopen: TRadReopenProc;
    /// <summary>Where and how states are saved. Closes any earlier setup first.</summary>
    /// <param name="AScope">User or company part of every key, e.g. 'emrah'.</param>
    /// <param name="ACipher">nil saves plain JSON; existing plain records stay readable later.</param>
    class procedure Kur(const AStore: IRadStateStore; const AScope: RawUtf8 = '';
      const ACipher: IRadCipher = nil); static;
    /// <summary>Saves open forms that have not saved yet, then releases the store and the providers.
    /// Safe to call twice.</summary>
    class procedure Kapat; static;
    /// <summary>Reads every record of the current scope in one store call.</summary>
    class procedure Prefetch; static;
    /// <summary>Changes the scope after login without rebuilding the store.</summary>
    class procedure SetScope(const AScope: RawUtf8); static;
    /// <summary>One file per record under AFolder (default %LOCALAPPDATA%\exe name\state).</summary>
    class function FileStore(const AFolder: string = ''): IRadStateStore; overload; static;
    /// <summary>One file per record under ABase\AFolder; an empty AFolder uses ABase itself.</summary>
    /// <remarks>srExeFolder fails under Program Files: saves are then only logged.</remarks>
    class function FileStore(ABase: TRadStorageRoot;
      const AFolder: string = RAD_STATE_FOLDER): IRadStateStore; overload; static;
    /// <summary>Routes to TRadCallbackStateStore.DoLoad/DoSave/DoDelete/DoLoadScope.</summary>
    class function CallbackStore: IRadStateStore; static;
    /// <summary>One row per record in ATable on the host's connection; DDL: TRadUniStateStore.CreateTableSql.</summary>
    class function DbStore(AConnection: TUniConnection;
      const ATable: string = RAD_STATE_DEFAULT_TABLE): IRadStateStore; static;
    class function Repository: TRadStateRepository; static;
    /// <summary>Application-wide participant (grid layouts, ...); Kapat removes them.</summary>
    class procedure RegisterProvider(const AProvider: IRadStateProvider); static;
    /// <summary>Deletes the form's saved state and reopens it through Reopen, so DFM, company layout
    /// and host code apply in their own order. Without Reopen the form closes with a notice.</summary>
    class procedure ResetForm(AForm: TCustomForm); static;
  end;

implementation

uses
  System.UITypes,
  Vcl.Dialogs;

resourcestring
  SResetReopen = 'Formun ayarları sıfırlandı. Form yeniden açıldığında varsayılan görünüm gelir.';

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

class function TRadFormState.FileStore(ABase: TRadStorageRoot; const AFolder: string): IRadStateStore;
begin
  Result := TRadFileStateStore.Create(ABase, AFolder);
end;

class function TRadFormState.CallbackStore: IRadStateStore;
begin
  Result := TRadCallbackStateStore.Create;
end;

class function TRadFormState.DbStore(AConnection: TUniConnection; const ATable: string): IRadStateStore;
begin
  Result := TRadUniStateStore.Create(AConnection, ATable);
end;

class function TRadFormState.Repository: TRadStateRepository;
begin
  Result := TRadPropertiesStore.Repository;
end;

class procedure TRadFormState.RegisterProvider(const AProvider: IRadStateProvider);
begin
  TRadPropertiesStore.RegisterProvider(AProvider);
end;

class procedure TRadFormState.ResetForm(AForm: TCustomForm);
var
  I: Integer;
begin
  for I := 0 to AForm.ComponentCount - 1 do
    if AForm.Components[I] is TRadPropertiesStore then
      TRadPropertiesStore(AForm.Components[I]).ResetSaved;
  if Assigned(Reopen) then
    Reopen(AForm)
  else
  begin
    MessageDlg(SResetReopen, mtInformation, [mbOK], 0);
    AForm.Close;
  end;
end;

end.
