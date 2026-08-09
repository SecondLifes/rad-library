unit rad.rtl;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Actions,
  Vcl.ActnList,
  mormot.core.base,
  mormot.core.unicode,
  mormot.core.json,
  mormot.core.variants;

type
  TRadActionList = class;

  TRadOnLoadEvent = procedure(const AList: TRadActionList);
  TRadOnSaveEvent = procedure(const AList: TRadActionList);

  TRadAction = class(TAction)
  private
    FGlobalKey: string;
  published
    property GlobalKey: string read FGlobalKey write FGlobalKey;
  end;

  TRadActionList = class(TActionList)
  private
    FDefaultKeys: TArray<TShortCut>;
    function  GetActions: TArray<TContainedAction>;
  protected
    procedure Loaded; override;
  public
    class var OnLoad: TRadOnLoadEvent;
    class var OnSave: TRadOnSaveEvent;

    procedure ShortCutDefaultStore;
    procedure ShortCutDefaultRestore;

    procedure LoadFromJson(const AJson: RawUtf8);
    function  ToJson: RawUtf8;

  published
   property Json :RawUtf8 read ToJson write LoadFromJson stored False;


  end;

  [ComponentPlatformsAttribute(pidAllPlatforms)]
  TRadCmdList = class(TComponent)
  strict private
    FCmdList: TStrings;
    procedure SetCmdList(const Value: TStrings);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property CommandList: TStrings read FCmdList write SetCmdList;
  end;

implementation
 uses Math;
{ TRadActionList }

function TRadActionList.GetActions: TArray<TContainedAction>;
var
  i: Integer;
begin
  SetLength(Result, ActionCount);
  for i := 0 to ActionCount - 1 do
    Result[i] := Actions[i];
end;

procedure TRadActionList.Loaded;
begin
  inherited;
  if Assigned(OnLoad) then
    OnLoad(Self);
  ShortCutDefaultStore;
end;

procedure TRadActionList.ShortCutDefaultStore;
var
  i: Integer;
begin
  SetLength(FDefaultKeys, ActionCount);
  for i := 0 to ActionCount - 1 do
    if Actions[i] is TCustomAction then
      FDefaultKeys[i] := TCustomAction(Actions[i]).ShortCut
    else
      FDefaultKeys[i] := 0;
end;

procedure TRadActionList.ShortCutDefaultRestore;
var
  i: Integer;
begin
  if Length(FDefaultKeys) = 0 then Exit;
  for i := 0 to Min(ActionCount, Length(FDefaultKeys)) - 1 do
    if Actions[i] is TCustomAction then
      TCustomAction(Actions[i]).ShortCut := FDefaultKeys[i];
end;

procedure TRadActionList.LoadFromJson(const AJson: RawUtf8);
var
  dv   : TDocVariantData;
  i    : Integer;
  act  : TContainedAction;
  sc   : ShortInt;
  name : RawUtf8;
  idx  : Integer;
begin
  if AJson = '' then Exit;
  dv.InitJson(AJson, JSON_FAST);
  if dv.Kind <> dvObject then Exit;

  for i := 0 to ActionCount - 1 do
  begin
    act := Actions[i];
    if not (act is TCustomAction) then Continue;

    // GlobalKey varsa onu ara, yoksa action adını ara
    if (act is TRadAction) and (TRadAction(act).GlobalKey <> '') then
      name := StringToUtf8(TRadAction(act).GlobalKey)
    else
      name := StringToUtf8(act.Name);

    idx := dv.GetValueIndex(name);
    if idx >= 0 then
      TCustomAction(act).ShortCut := dv.Values[idx];
  end;
end;

function TRadActionList.ToJson: RawUtf8;
var
  W     : TJsonWriter;
  i     : Integer;
  act   : TContainedAction;
  key   : string;
  first : Boolean;
begin
 if csDesigning in ComponentState then exit;

  W := TJsonWriter.CreateOwnedStream(1024);
  try
    W.Add('{');
    first := True;
    for i := 0 to ActionCount - 1 do
    begin
      act := Actions[i];
      if not (act is TCustomAction) then Continue;

      if (act is TRadAction) and (TRadAction(act).GlobalKey <> '') then
        key := TRadAction(act).GlobalKey
      else
        key := act.Name;

      if not first then W.AddComma;
      first := False;
      W.AddFieldName(StringToUtf8(key));
      W.Add(TCustomAction(act).ShortCut);
    end;
    W.Add('}');
    W.SetText(Result);
  finally
    W.Free;
  end;
end;



{ TRadCmdList }

constructor TRadCmdList.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCmdList := TStringList.Create;
  //if not Assigned(GlobalCmdList) then GlobalCmdList:=Self;

end;

destructor TRadCmdList.Destroy;
begin
  FCmdList.Free;
  inherited;
end;

procedure TRadCmdList.SetCmdList(const Value: TStrings);
begin
 FCmdList.Assign(Value);
end;

end.
