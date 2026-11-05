unit rad.rtl;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Actions,
  Vcl.ActnList,
  Data.DB,
  Vcl.DBActns,
  mormot.core.base,
  mormot.core.unicode,
  mormot.core.json,
  mormot.core.variants,
  rad.formstate.core;

type
  TRadActionList = class;

  TRadOnLoadEvent = procedure(const AList: TRadActionList);
  TRadOnSaveEvent = procedure(const AList: TRadActionList);

  /// <summary>Kısayolu form bağımsız (genel) saklanan eylemlerin arayüzü. Aynı GlobalKey'e
  /// sahip eylemler bütün formlarda aynı kısayolu paylaşır (TRadActionList JSON'u bu anahtarla yazar/okur).</summary>
  IRadGlobalKey = interface
    ['{5C1F0E62-8A3D-4B7E-9F21-6D4A8E3B7C15}']
    function GetGlobalKey: string;
  end;

  TRadAction = class(TAction, IRadGlobalKey)
  private
    FGlobalKey: string;
    function GetGlobalKey: string;
  published
    property GlobalKey: string read FGlobalKey write FGlobalKey;
  end;

  /// <summary>Kaydet: veri kümesi Edit/Insert durumundaysa Post eder. DataSource boşsa VCL odaktaki
  /// veri-bağlı denetimin DataSource'unu kullanır. Post'tan önce RadCommitEditors (genel kanca)
  /// çalışır: açık satır içi düzenleyicinin değeri veri kümesine yazılsın diye.</summary>
  TRadDataSetPost = class(TDataSetPost, IRadGlobalKey)
  private
    FGlobalKey: string;
    function GetGlobalKey: string;
  public
    procedure ExecuteTarget(Target: TObject); override;
  published
    property GlobalKey: string read FGlobalKey write FGlobalKey;
  end;

  /// <summary>İptal: veri kümesi Edit/Insert durumundaysa Cancel eder; önce RadCancelEditors.</summary>
  TRadDataSetCancel = class(TDataSetCancel, IRadGlobalKey)
  private
    FGlobalKey: string;
    function GetGlobalKey: string;
  public
    procedure ExecuteTarget(Target: TObject); override;
  published
    property GlobalKey: string read FGlobalKey write FGlobalKey;
  end;


  TRadActionList = class(TActionList, IRadStateful)
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
    { IRadStateful: the same shape as ToJson, kept per form by TRadPropertiesStore. }
    procedure SaveState(const ADoc: IDocDict);
    procedure LoadState(const ADoc: IDocDict);


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

var
  /// <summary>Kaydet'ten önce çağrılır. Satır içi düzenleyicileri (cxGrid, cx editörleri) bilen birim
  /// (rad.dev) atar; rad.rtl DevExpress'e bağımlı olmasın diye kanca.</summary>
  RadCommitEditors: TProc = nil;
  /// <summary>İptal'den önce çağrılır (açık düzenleyiciyi iptal eder).</summary>
  RadCancelEditors: TProc = nil;

type
  /// <summary>Global shortcut keys of actions.</summary>
  TRadGlobalKey = class abstract
  public
    /// <summary>Eylemin GlobalKey'i; arayüzü desteklemiyorsa ya da boşsa ''.</summary>
    class function KeyOf(AAction: TObject): string; static;
  end;

function RadGlobalKeyOf(AAction: TObject): string; deprecated 'Use TRadGlobalKey.KeyOf';


implementation
 uses Math;
class function TRadGlobalKey.KeyOf(AAction: TObject): string;
var
  LKey: IRadGlobalKey;
begin
  if Supports(AAction, IRadGlobalKey, LKey) then
    Result := LKey.GetGlobalKey
  else
    Result := '';
end;

{ TRadAction }

function TRadAction.GetGlobalKey: string;
begin
  Result := FGlobalKey;
end;

{ TRadDataSetPost }

function TRadDataSetPost.GetGlobalKey: string;
begin
  Result := FGlobalKey;
end;

procedure TRadDataSetPost.ExecuteTarget(Target: TObject);
begin
  if Assigned(RadCommitEditors) then
    RadCommitEditors();
  inherited ExecuteTarget(Target);
end;

{ TRadDataSetCancel }

function TRadDataSetCancel.GetGlobalKey: string;
begin
  Result := FGlobalKey;
end;

procedure TRadDataSetCancel.ExecuteTarget(Target: TObject);
begin
  if Assigned(RadCancelEditors) then
    RadCancelEditors();
  inherited ExecuteTarget(Target);
end;

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
    if TRadGlobalKey.KeyOf(act) <> '' then
      name := StringToUtf8(TRadGlobalKey.KeyOf(act))
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

      if TRadGlobalKey.KeyOf(act) <> '' then
        key := TRadGlobalKey.KeyOf(act)
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



{ TRadActionList: IRadStateful }

procedure TRadActionList.SaveState(const ADoc: IDocDict);
begin
  // Shortcuts by action name, or by GlobalKey; sharing a key across forms stays OnLoad/OnSave's job.
  ADoc.Update(DocDict(ToJson, mFastFloat));
end;

procedure TRadActionList.LoadState(const ADoc: IDocDict);
begin
  LoadFromJson(ADoc.Json);
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

{ Deprecated names }

function RadGlobalKeyOf(AAction: TObject): string;
begin
  Result := TRadGlobalKey.KeyOf(AAction);
end;

end.
