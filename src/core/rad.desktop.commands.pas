unit rad.desktop.commands;

(* Command sources of the ERP desktop (docs/specs/rad.desktop.md). A command id is 'prefix:name';
   each source owns one prefix. Permission is asked on every resolve, never only when a shortcut is
   saved. RTL only (+ rad.cmd for the ICmds source). *)

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  rad.cmd;

const
  RAD_DESK_ID_SEPARATOR = ':';

type
  TRadDeskCommandInfo = record
    /// <summary>Full id with prefix ('act:actFatura').</summary>
    Id: string;
    Caption: string;
    /// <summary>Path shown in the picker ('Satış > Faturalar').</summary>
    Category: string;
    Hint: string;
    ImageIndex: Integer;
    Enabled: Boolean;
    Visible: Boolean;
    class function Make(const AId, ACaption, ACategory: string; AImageIndex: Integer = -1): TRadDeskCommandInfo; static;
  end;

  TRadDeskCommandInfos = TArray<TRadDeskCommandInfo>;

  /// <summary>Resolution outcome of a shortcut's target.</summary>
  TRadDeskResolve = (crOk, crMissing, crDenied, crHidden);

  IRadDeskCommandSource = interface
    ['{6E3A1F52-9C4B-4D7E-8A21-5B0C9D3E7F46}']
    /// <summary>Unique prefix without the separator ('act').</summary>
    function Prefix: string;
    /// <summary>Adds every command of the source; Id carries the prefix.</summary>
    procedure Enumerate(AList: TList<TRadDeskCommandInfo>);
    /// <summary>AName is the part after the prefix.</summary>
    function Find(const AName: string; out AInfo: TRadDeskCommandInfo): Boolean;
    /// <summary>False when the command no longer exists or is disabled.</summary>
    function Execute(const AName: string): Boolean;
  end;

  TRadDeskAllowFunc = reference to function(const ACommandId: string): Boolean;

  TRadDeskCommands = class
  private
    FSources: TList<IRadDeskCommandSource>;
    FAllow: TRadDeskAllowFunc;
    function SourceOf(const APrefix: string): IRadDeskCommandSource;
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>Replaces a source with the same prefix.</summary>
    procedure Add(const ASource: IRadDeskCommandSource);
    procedure Remove(const APrefix: string);
    procedure Clear;
    function IsAllowed(const AId: string): Boolean;
    function Resolve(const AId: string; out AInfo: TRadDeskCommandInfo): TRadDeskResolve;
    /// <summary>Resolves again (permission included) right before running; False if not crOk or disabled.</summary>
    function Execute(const AId: string): Boolean;
    /// <summary>Visible, allowed commands sorted by category then caption, for the picker.</summary>
    function All: TRadDeskCommandInfos;
    class function SplitId(const AId: string; out APrefix, AName: string): Boolean; static;
    class function MakeId(const APrefix, AName: string): string; static;
    /// <summary>Nil allows everything.</summary>
    property Allow: TRadDeskAllowFunc read FAllow write FAllow;
  end;

  /// <summary>Source over rad.cmd's ICmds. ICmds has no caption, so Describe supplies it.</summary>
  TRadDeskCmdSource = class(TInterfacedObject, IRadDeskCommandSource)
  private
    FCmds: ICmds;
    FPrefix: string;
    FInfos: TDictionary<string, TRadDeskCommandInfo>;
  public
    constructor Create(const ACmds: ICmds; const APrefix: string = 'cmd');
    destructor Destroy; override;
    /// <summary>Only described commands are listed; an undescribed one still runs by id.</summary>
    procedure Describe(const AName, ACaption, ACategory: string; AImageIndex: Integer = -1);
    function Prefix: string;
    procedure Enumerate(AList: TList<TRadDeskCommandInfo>);
    function Find(const AName: string; out AInfo: TRadDeskCommandInfo): Boolean;
    function Execute(const AName: string): Boolean;
  end;

implementation

uses
  System.Generics.Defaults;

{ TRadDeskCommandInfo }

class function TRadDeskCommandInfo.Make(const AId, ACaption, ACategory: string;
  AImageIndex: Integer): TRadDeskCommandInfo;
begin
  Result := Default(TRadDeskCommandInfo);
  Result.Id := AId;
  Result.Caption := ACaption;
  Result.Category := ACategory;
  Result.ImageIndex := AImageIndex;
  Result.Enabled := True;
  Result.Visible := True;
end;

{ TRadDeskCommands }

constructor TRadDeskCommands.Create;
begin
  inherited Create;
  FSources := TList<IRadDeskCommandSource>.Create;
end;

destructor TRadDeskCommands.Destroy;
begin
  FSources.Free;
  inherited Destroy;
end;

class function TRadDeskCommands.SplitId(const AId: string; out APrefix, AName: string): Boolean;
var
  LPos: Integer;
begin
  LPos := AId.IndexOf(RAD_DESK_ID_SEPARATOR);
  Result := LPos > 0;
  if Result then
  begin
    APrefix := AId.Substring(0, LPos);
    AName := AId.Substring(LPos + 1);
    Result := AName <> '';
  end;
end;

class function TRadDeskCommands.MakeId(const APrefix, AName: string): string;
begin
  Result := APrefix + RAD_DESK_ID_SEPARATOR + AName;
end;

function TRadDeskCommands.SourceOf(const APrefix: string): IRadDeskCommandSource;
var
  LSource: IRadDeskCommandSource;
begin
  for LSource in FSources do
    if SameText(LSource.Prefix, APrefix) then
      Exit(LSource);
  Result := nil;
end;

procedure TRadDeskCommands.Add(const ASource: IRadDeskCommandSource);
begin
  if not Assigned(ASource) then
    raise EArgumentNilException.Create('ASource');
  Remove(ASource.Prefix);
  FSources.Add(ASource);
end;

procedure TRadDeskCommands.Remove(const APrefix: string);
var
  I: Integer;
begin
  for I := FSources.Count - 1 downto 0 do
    if SameText(FSources[I].Prefix, APrefix) then
      FSources.Delete(I);
end;

procedure TRadDeskCommands.Clear;
begin
  FSources.Clear;
end;

function TRadDeskCommands.IsAllowed(const AId: string): Boolean;
begin
  Result := not Assigned(FAllow) or FAllow(AId);
end;

function TRadDeskCommands.Resolve(const AId: string; out AInfo: TRadDeskCommandInfo): TRadDeskResolve;
var
  LPrefix, LName: string;
  LSource: IRadDeskCommandSource;
begin
  AInfo := TRadDeskCommandInfo.Make(AId, '', '');
  if not SplitId(AId, LPrefix, LName) then
    Exit(crMissing);
  LSource := SourceOf(LPrefix);
  if not Assigned(LSource) or not LSource.Find(LName, AInfo) then
    Exit(crMissing);
  AInfo.Id := AId;
  if not IsAllowed(AId) then
    Exit(crDenied);
  if not AInfo.Visible then
    Exit(crHidden);
  Result := crOk;
end;

function TRadDeskCommands.Execute(const AId: string): Boolean;
var
  LInfo: TRadDeskCommandInfo;
  LPrefix, LName: string;
begin
  Result := (Resolve(AId, LInfo) = crOk) and LInfo.Enabled and SplitId(AId, LPrefix, LName);
  if Result then
    Result := SourceOf(LPrefix).Execute(LName);
end;

function TRadDeskCommands.All: TRadDeskCommandInfos;
var
  LList: TList<TRadDeskCommandInfo>;
  LSource: IRadDeskCommandSource;
  I: Integer;
begin
  LList := TList<TRadDeskCommandInfo>.Create;
  try
    for LSource in FSources do
      LSource.Enumerate(LList);
    for I := LList.Count - 1 downto 0 do
      if not LList[I].Visible or not IsAllowed(LList[I].Id) then
        LList.Delete(I);
    LList.Sort(TComparer<TRadDeskCommandInfo>.Construct(
      function(const A, B: TRadDeskCommandInfo): Integer
      begin
        Result := AnsiCompareText(A.Category, B.Category);
        if Result = 0 then
          Result := AnsiCompareText(A.Caption, B.Caption);
      end));
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

{ TRadDeskCmdSource }

constructor TRadDeskCmdSource.Create(const ACmds: ICmds; const APrefix: string);
begin
  inherited Create;
  if not Assigned(ACmds) then
    raise EArgumentNilException.Create('ACmds');
  FCmds := ACmds;
  FPrefix := APrefix;
  FInfos := TDictionary<string, TRadDeskCommandInfo>.Create;
end;

destructor TRadDeskCmdSource.Destroy;
begin
  FInfos.Free;
  inherited Destroy;
end;

procedure TRadDeskCmdSource.Describe(const AName, ACaption, ACategory: string; AImageIndex: Integer);
begin
  FInfos.AddOrSetValue(AnsiLowerCase(AName), TRadDeskCommandInfo.Make(
    TRadDeskCommands.MakeId(FPrefix, AName), ACaption, ACategory, AImageIndex));
end;

function TRadDeskCmdSource.Prefix: string;
begin
  Result := FPrefix;
end;

procedure TRadDeskCmdSource.Enumerate(AList: TList<TRadDeskCommandInfo>);
var
  LInfo: TRadDeskCommandInfo;
begin
  for LInfo in FInfos.Values do
    if FCmds.Exists(LInfo.Id.Substring(Length(FPrefix) + 1)) then
      AList.Add(LInfo);
end;

function TRadDeskCmdSource.Find(const AName: string; out AInfo: TRadDeskCommandInfo): Boolean;
begin
  Result := FCmds.Exists(AName);
  if not Result then
    Exit;
  if not FInfos.TryGetValue(AnsiLowerCase(AName), AInfo) then
    AInfo := TRadDeskCommandInfo.Make(TRadDeskCommands.MakeId(FPrefix, AName), AName, '');
end;

function TRadDeskCmdSource.Execute(const AName: string): Boolean;
begin
  Result := FCmds.Exists(AName);
  if Result then
    FCmds.Execute(AName);
end;

end.
