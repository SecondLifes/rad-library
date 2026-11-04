unit rad.desktop.store;

(* Persistence of the ERP desktop over TRadStateRepository (rad.formstate.store): one company
   layer 'desktop\base' and one record per user 'desktop\user.<name>'. The user record is a full
   layout plus the ids it removed; loading merges new company groups and items into it. *)

interface

uses
  System.SysUtils,
  mormot.core.base,
  rad.formstate.core,
  rad.formstate.store,
  rad.desktop.core;

const
  RAD_DESK_STATE_SCOPE = 'desktop';
  RAD_DESK_STATE_BASE = 'base';
  RAD_DESK_STATE_USER_PREFIX = 'user.';

type
  TRadDeskStore = class
  private
    FRepository: TRadStateRepository;
    FUser: string;
    function UserKey: TRadStateKey;
    function BaseKey: TRadStateKey;
    function Read(const AKey: TRadStateKey; ALayout: TRadDeskLayout): Boolean;
    function Write(const AKey: TRadStateKey; ALayout: TRadDeskLayout): Boolean;
  public
    /// <summary>The repository is not owned and must outlive the store.</summary>
    constructor Create(ARepository: TRadStateRepository; const AUser: string);
    /// <summary>The company layer alone; False (layout cleared) when there is none.</summary>
    function LoadBase(ALayout: TRadDeskLayout): Boolean;
    /// <summary>The user's layout with new company content merged in, or the company layer when the
    /// user never saved one. False when neither exists (layout cleared).</summary>
    function Load(ALayout: TRadDeskLayout): Boolean;
    /// <summary>False when nothing changed since the last load or save.</summary>
    function SaveUser(ALayout: TRadDeskLayout): Boolean;
    /// <summary>Writes ALayout as the company layer with the next version; the removed list is dropped.</summary>
    procedure SaveBase(ALayout: TRadDeskLayout);
    procedure ResetUser;
    function HasUserLayout: Boolean;
    property User: string read FUser;
    property Repository: TRadStateRepository read FRepository;
  end;

implementation

uses
  mormot.core.variants,
  mormot.core.unicode;

constructor TRadDeskStore.Create(ARepository: TRadStateRepository; const AUser: string);
begin
  inherited Create;
  if not Assigned(ARepository) then
    raise EArgumentNilException.Create('ARepository');
  if AUser.Trim = '' then
    raise EArgumentException.Create('AUser is empty');
  FRepository := ARepository;
  FUser := AUser.Trim;
end;

function TRadDeskStore.UserKey: TRadStateKey;
begin
  Result := TRadStateKey.Make(RAD_DESK_STATE_SCOPE, StringToUtf8(RAD_DESK_STATE_USER_PREFIX +
    System.SysUtils.LowerCase(FUser)));
end;

function TRadDeskStore.BaseKey: TRadStateKey;
begin
  Result := TRadStateKey.Make(RAD_DESK_STATE_SCOPE, RAD_DESK_STATE_BASE);
end;

function TRadDeskStore.Read(const AKey: TRadStateKey; ALayout: TRadDeskLayout): Boolean;
var
  LDoc: IDocDict;
begin
  Result := FRepository.Load(AKey, LDoc) and ALayout.FromJson(LDoc.Json);
end;

function TRadDeskStore.Write(const AKey: TRadStateKey; ALayout: TRadDeskLayout): Boolean;
var
  LData: TDocVariantData;
begin
  if not LData.InitJson(ALayout.ToJson, JSON_FAST_FLOAT) then
    raise ERadDesktop.Create('Desktop layout produced invalid JSON');
  Result := FRepository.Save(AKey, DocDictCopy(LData));
end;

function TRadDeskStore.LoadBase(ALayout: TRadDeskLayout): Boolean;
begin
  Result := Read(BaseKey, ALayout);
  if not Result then
    ALayout.Clear;
end;

function TRadDeskStore.Load(ALayout: TRadDeskLayout): Boolean;
var
  LBase: TRadDeskLayout;
  LHasBase: Boolean;
begin
  LBase := TRadDeskLayout.Create;
  try
    LHasBase := Read(BaseKey, LBase);
    if Read(UserKey, ALayout) then
    begin
      if LHasBase then
        ALayout.MergeBase(LBase);
      Exit(True);
    end;
    ALayout.Clear;
    if LHasBase then
      ALayout.Assign(LBase);
    Result := LHasBase;
  finally
    LBase.Free;
  end;
end;

function TRadDeskStore.SaveUser(ALayout: TRadDeskLayout): Boolean;
begin
  Result := Write(UserKey, ALayout);
end;

procedure TRadDeskStore.SaveBase(ALayout: TRadDeskLayout);
var
  LOld, LNew: TRadDeskLayout;
begin
  LOld := TRadDeskLayout.Create;
  LNew := TRadDeskLayout.Create;
  try
    Read(BaseKey, LOld);
    LNew.Assign(ALayout);
    LNew.Removed.Clear;
    LNew.BaseVersion := LOld.BaseVersion + 1;
    Write(BaseKey, LNew);
    ALayout.BaseVersion := LNew.BaseVersion;
  finally
    LNew.Free;
    LOld.Free;
  end;
end;

procedure TRadDeskStore.ResetUser;
begin
  FRepository.Delete(UserKey);
end;

function TRadDeskStore.HasUserLayout: Boolean;
var
  LDoc: IDocDict;
begin
  Result := FRepository.Load(UserKey, LDoc);
end;

end.
