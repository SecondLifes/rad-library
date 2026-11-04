unit rad.desktop.sources;

(* VCL command sources of the ERP desktop: TActionList ('act:') and TMenu ('menu:'). A command is
   found by component Name inside the registered list or menu, never through FindComponent on a
   form, so a renamed or removed command becomes a broken tile instead of silently vanishing. *)

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Actions,
  Vcl.ActnList,
  Vcl.Menus,
  rad.desktop.commands;

type
  /// <summary>Commands of one or more action lists; the category is the action's Category.</summary>
  TRadDeskActionSource = class(TInterfacedObject, IRadDeskCommandSource)
  private
    FPrefix: string;
    FLists: TList<TCustomActionList>;
    function FindAction(const AName: string): TContainedAction;
    function InfoOf(AAction: TContainedAction): TRadDeskCommandInfo;
  public
    constructor Create(const APrefix: string = 'act');
    destructor Destroy; override;
    /// <summary>The list must outlive the source, or be removed first.</summary>
    procedure AddList(AList: TCustomActionList);
    procedure RemoveList(AList: TCustomActionList);
    function Prefix: string;
    procedure Enumerate(AList: TList<TRadDeskCommandInfo>);
    function Find(const AName: string; out AInfo: TRadDeskCommandInfo): Boolean;
    function Execute(const AName: string): Boolean;
  end;

  /// <summary>Clickable leaves of a menu; the category is the path of parent captions.</summary>
  TRadDeskMenuSource = class(TInterfacedObject, IRadDeskCommandSource)
  private
    FPrefix: string;
    FMenu: TMenu;
    function FindItem(AParent: TMenuItem; const AName: string): TMenuItem;
    procedure Walk(AParent: TMenuItem; const APath: string; AList: TList<TRadDeskCommandInfo>);
    function InfoOf(AItem: TMenuItem; const APath: string): TRadDeskCommandInfo;
    class function PathOf(AItem: TMenuItem): string; static;
  public
    constructor Create(AMenu: TMenu; const APrefix: string = 'menu');
    function Prefix: string;
    procedure Enumerate(AList: TList<TRadDeskCommandInfo>);
    function Find(const AName: string; out AInfo: TRadDeskCommandInfo): Boolean;
    function Execute(const AName: string): Boolean;
  end;

implementation

uses
  Vcl.Controls;

const
  CPathSeparator = ' › ';

function StripAmp(const AText: string): string;
begin
  Result := StripHotkey(AText);
end;

{ TRadDeskActionSource }

constructor TRadDeskActionSource.Create(const APrefix: string);
begin
  inherited Create;
  FPrefix := APrefix;
  FLists := TList<TCustomActionList>.Create;
end;

destructor TRadDeskActionSource.Destroy;
begin
  FLists.Free;
  inherited Destroy;
end;

procedure TRadDeskActionSource.AddList(AList: TCustomActionList);
begin
  if Assigned(AList) and (FLists.IndexOf(AList) < 0) then
    FLists.Add(AList);
end;

procedure TRadDeskActionSource.RemoveList(AList: TCustomActionList);
begin
  FLists.Remove(AList);
end;

function TRadDeskActionSource.Prefix: string;
begin
  Result := FPrefix;
end;

function TRadDeskActionSource.FindAction(const AName: string): TContainedAction;
var
  LList: TCustomActionList;
  I: Integer;
begin
  for LList in FLists do
    for I := 0 to LList.ActionCount - 1 do
      if SameText(LList.Actions[I].Name, AName) then
        Exit(LList.Actions[I]);
  Result := nil;
end;

function TRadDeskActionSource.InfoOf(AAction: TContainedAction): TRadDeskCommandInfo;
var
  LAction: TCustomAction;
begin
  Result := TRadDeskCommandInfo.Make(TRadDeskCommands.MakeId(FPrefix, AAction.Name), AAction.Name,
    AAction.Category);
  if not (AAction is TCustomAction) then
    Exit;
  LAction := TCustomAction(AAction);
  LAction.Update;
  Result.Caption := StripAmp(LAction.Caption);
  Result.Hint := GetShortHint(LAction.Hint);
  Result.ImageIndex := LAction.ImageIndex;
  Result.Enabled := LAction.Enabled;
  Result.Visible := LAction.Visible;
end;

procedure TRadDeskActionSource.Enumerate(AList: TList<TRadDeskCommandInfo>);
var
  LList: TCustomActionList;
  I: Integer;
begin
  for LList in FLists do
    for I := 0 to LList.ActionCount - 1 do
      if LList.Actions[I].Name <> '' then
        AList.Add(InfoOf(LList.Actions[I]));
end;

function TRadDeskActionSource.Find(const AName: string; out AInfo: TRadDeskCommandInfo): Boolean;
var
  LAction: TContainedAction;
begin
  LAction := FindAction(AName);
  Result := Assigned(LAction);
  if Result then
    AInfo := InfoOf(LAction);
end;

function TRadDeskActionSource.Execute(const AName: string): Boolean;
var
  LAction: TContainedAction;
begin
  LAction := FindAction(AName);
  Result := Assigned(LAction);
  if Result then
    Result := LAction.Execute;
end;

{ TRadDeskMenuSource }

constructor TRadDeskMenuSource.Create(AMenu: TMenu; const APrefix: string);
begin
  inherited Create;
  if not Assigned(AMenu) then
    raise EArgumentNilException.Create('AMenu');
  FMenu := AMenu;
  FPrefix := APrefix;
end;

function TRadDeskMenuSource.Prefix: string;
begin
  Result := FPrefix;
end;

class function TRadDeskMenuSource.PathOf(AItem: TMenuItem): string;
var
  LParent: TMenuItem;
begin
  Result := '';
  LParent := AItem.Parent;
  while Assigned(LParent) and (LParent.Caption <> '') do
  begin
    if Result = '' then
      Result := StripAmp(LParent.Caption)
    else
      Result := StripAmp(LParent.Caption) + CPathSeparator + Result;
    LParent := LParent.Parent;
  end;
end;

function TRadDeskMenuSource.InfoOf(AItem: TMenuItem; const APath: string): TRadDeskCommandInfo;
begin
  if Assigned(AItem.Action) then
    AItem.Action.Update;
  Result := TRadDeskCommandInfo.Make(TRadDeskCommands.MakeId(FPrefix, AItem.Name), StripAmp(AItem.Caption),
    APath, AItem.ImageIndex);
  Result.Hint := GetShortHint(AItem.Hint);
  Result.Enabled := AItem.Enabled;
  Result.Visible := AItem.Visible;
end;

procedure TRadDeskMenuSource.Walk(AParent: TMenuItem; const APath: string; AList: TList<TRadDeskCommandInfo>);
var
  LItem: TMenuItem;
  LPath: string;
  I: Integer;
begin
  for I := 0 to AParent.Count - 1 do
  begin
    LItem := AParent.Items[I];
    if LItem.IsLine or not LItem.Visible then
      Continue;
    if LItem.Count > 0 then
    begin
      LPath := StripAmp(LItem.Caption);
      if APath <> '' then
        LPath := APath + CPathSeparator + LPath;
      Walk(LItem, LPath, AList);
    end
    else if (LItem.Name <> '') and (Assigned(LItem.OnClick) or Assigned(LItem.Action)) then
      AList.Add(InfoOf(LItem, APath));
  end;
end;

procedure TRadDeskMenuSource.Enumerate(AList: TList<TRadDeskCommandInfo>);
begin
  Walk(FMenu.Items, '', AList);
end;

function TRadDeskMenuSource.FindItem(AParent: TMenuItem; const AName: string): TMenuItem;
var
  I: Integer;
begin
  for I := 0 to AParent.Count - 1 do
  begin
    if SameText(AParent.Items[I].Name, AName) then
      Exit(AParent.Items[I]);
    Result := FindItem(AParent.Items[I], AName);
    if Assigned(Result) then
      Exit;
  end;
  Result := nil;
end;

function TRadDeskMenuSource.Find(const AName: string; out AInfo: TRadDeskCommandInfo): Boolean;
var
  LItem: TMenuItem;
begin
  LItem := FindItem(FMenu.Items, AName);
  Result := Assigned(LItem) and (LItem.Count = 0) and not LItem.IsLine;
  if Result then
    AInfo := InfoOf(LItem, PathOf(LItem));
end;

function TRadDeskMenuSource.Execute(const AName: string): Boolean;
var
  LItem: TMenuItem;
begin
  LItem := FindItem(FMenu.Items, AName);
  Result := Assigned(LItem) and LItem.Enabled and (LItem.Count = 0);
  if Result then
    LItem.Click;
end;

end.
