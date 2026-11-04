unit rad.desktop.script;

(* Script widgets of the ERP desktop (docs/specs/rad.desktop.md): every routine named
   '<Kod>_Yenile(W: TRadDeskWidgetData)' in a 'kutuphane' script becomes the widget provider
   'script:<Kod>'. The script only fills W (Title, Value, SubText, Trend, AddLine, AddPoint,
   Settings); the desktop draws it. Runs on the main thread under a deadline, so a stuck script
   is cut by ERadScriptTimeout and shown as an error on its own tile. *)

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  rad.script,
  rad.script.engine,
  rad.desktop.core,
  rad.desktop.widgets;

const
  RAD_DESK_SCRIPT_SUFFIX = '_Yenile';
  RAD_DESK_SCRIPT_PREFIX = 'script';
  RAD_DESK_SCRIPT_DEADLINE_MS = 3000;
  RAD_DESK_SCRIPT_INTERVAL_MS = 60000;

type
  TRadDeskScriptWidget = class(TInterfacedObject, IRadDeskWidgetProvider)
  private
    FEngine: TRadScriptEngine;
    FScriptCode: string;
    FName: string;
    FSize: TRadDeskSize;
    FInterval: Integer;
  public
    /// <summary>AEngine is not owned (TRadDeskScriptWidgets owns it).</summary>
    constructor Create(AEngine: TRadScriptEngine; const AScriptCode, AName: string);
    function Id: string;
    function Caption: string;
    function DefaultSize: TRadDeskSize;
    function Interval: Integer;
    procedure Fetch(const ASettings: string; AData: TRadDeskWidgetData);
    property Size: TRadDeskSize read FSize write FSize;
    property RefreshInterval: Integer read FInterval write FInterval;
  end;

  /// <summary>Owns one engine with the library scripts and registers their widget routines.</summary>
  TRadDeskScriptWidgets = class
  private
    FEngine: TRadScriptEngine;
    FIds: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>Adds every active 'kutuphane' script of the active packages, compiles, then registers
    /// one provider per '_Yenile' routine into AWidgets. Returns how many were registered.</summary>
    function Load(const AStore: IRadScriptStore; AWidgets: TRadDeskWidgets): Integer;
    /// <summary>Same as Load for scripts already in hand (tests, a single package).</summary>
    function LoadScripts(const AScripts: TArray<TRadScript>; AWidgets: TRadDeskWidgets): Integer;
    /// <summary>Removes the providers this instance registered.</summary>
    procedure Unload(AWidgets: TRadDeskWidgets);
    property Engine: TRadScriptEngine read FEngine;
  end;

implementation

uses
  System.StrUtils;

{ TRadDeskScriptWidget }

constructor TRadDeskScriptWidget.Create(AEngine: TRadScriptEngine; const AScriptCode, AName: string);
begin
  inherited Create;
  if not Assigned(AEngine) then
    raise EArgumentNilException.Create('AEngine');
  FEngine := AEngine;
  FScriptCode := AScriptCode;
  FName := AName;
  FSize := dsSmall;
  FInterval := RAD_DESK_SCRIPT_INTERVAL_MS;
end;

function TRadDeskScriptWidget.Id: string;
begin
  Result := RAD_DESK_SCRIPT_PREFIX + ':' + FName;
end;

function TRadDeskScriptWidget.Caption: string;
begin
  Result := FName;
end;

function TRadDeskScriptWidget.DefaultSize: TRadDeskSize;
begin
  Result := FSize;
end;

function TRadDeskScriptWidget.Interval: Integer;
begin
  Result := FInterval;
end;

procedure TRadDeskScriptWidget.Fetch(const ASettings: string; AData: TRadDeskWidgetData);
begin
  FEngine.SetDeadline(RAD_DESK_SCRIPT_DEADLINE_MS);
  try
    FEngine.Call(FScriptCode, FName + RAD_DESK_SCRIPT_SUFFIX, [AData]);
  finally
    FEngine.SetDeadline(0);
  end;
end;

{ TRadDeskScriptWidgets }

constructor TRadDeskScriptWidgets.Create;
begin
  inherited Create;
  FIds := TList<string>.Create;
  TRadScriptEngine.RegisterClass(TRadDeskWidgetData);
end;

destructor TRadDeskScriptWidgets.Destroy;
begin
  FIds.Free;
  FEngine.Free;
  inherited Destroy;
end;

function TRadDeskScriptWidgets.LoadScripts(const AScripts: TArray<TRadScript>; AWidgets: TRadDeskWidgets): Integer;
var
  LScript: TRadScript;
  LCode, LRoutine: string;
  LProvider: TRadDeskScriptWidget;
begin
  if not Assigned(AWidgets) then
    raise EArgumentNilException.Create('AWidgets');
  Unload(AWidgets);
  FreeAndNil(FEngine);
  FEngine := TRadScriptEngine.Create;
  for LScript in AScripts do
    FEngine.AddScript(LScript);
  FEngine.Compile;
  Result := 0;
  for LCode in FEngine.ScriptCodes do
    for LRoutine in FEngine.RoutineNames(LCode) do
      if EndsText(RAD_DESK_SCRIPT_SUFFIX, LRoutine) and (Length(LRoutine) > Length(RAD_DESK_SCRIPT_SUFFIX)) then
      begin
        LProvider := TRadDeskScriptWidget.Create(FEngine, LCode,
          LRoutine.Substring(0, Length(LRoutine) - Length(RAD_DESK_SCRIPT_SUFFIX)));
        AWidgets.Add(LProvider);
        FIds.Add(LProvider.Id);
        Inc(Result);
      end;
end;

function TRadDeskScriptWidgets.Load(const AStore: IRadScriptStore; AWidgets: TRadDeskWidgets): Integer;
var
  LPackages: TRadScriptPackages;
  LPackage: TRadScriptPackage;
  LScript: TRadScript;
  LList: TList<TRadScript>;
begin
  if not Assigned(AStore) then
    raise EArgumentNilException.Create('AStore');
  LPackages := AStore.LoadPackages(False);
  LList := TList<TRadScript>.Create;
  try
    for LPackage in LPackages do
      for LScript in LPackage.Scripts do
        if LScript.Active and (LScript.Kind = skLibrary) then
          LList.Add(LScript);
    Result := LoadScripts(LList.ToArray, AWidgets);
  finally
    LList.Free;
    LPackages.Free;
  end;
end;

procedure TRadDeskScriptWidgets.Unload(AWidgets: TRadDeskWidgets);
var
  LId: string;
begin
  if Assigned(AWidgets) then
    for LId in FIds do
      AWidgets.Remove(LId);
  FIds.Clear;
end;

end.
