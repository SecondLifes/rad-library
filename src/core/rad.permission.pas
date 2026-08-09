unit rad.permission;

interface

uses
  mormot.core.base,
  mormot.core.data;

type
  IPermission = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function  IsExists(const AName: string): Boolean;
    function  Get     (const AName: string; const ADefault: Boolean = False): Boolean;
    procedure Add     (const AName: string; const AValue: Boolean);
    function  AddOrGet(const AName: string; const ADefault: Boolean = False): Boolean;
    function  ToJson: RawUtf8;
    procedure FromJson(const AJson: RawUtf8);
    procedure Clear;
  end;

function NewPermission(const AJson: RawUtf8 = '[]'): IPermission;

implementation

uses
  mormot.core.unicode,
  mormot.core.variants,
  mormot.core.json,
  mormot.core.text;

type
  TRadPermissionImpl = class(TInterfacedObject, IPermission)
  private
    FArr : TRawUtf8DynArray;
    FHash: TDynArrayHashed;
    function  K(const AName: string): RawUtf8; inline;
    procedure HashAdd(const AKey: RawUtf8);
  public
    constructor Create(const AJson: RawUtf8);
    function  IsExists(const AName: string): Boolean;
    function  Get     (const AName: string; const ADefault: Boolean = False): Boolean;
    procedure Add     (const AName: string; const AValue: Boolean);
    function  AddOrGet(const AName: string; const ADefault: Boolean = False): Boolean;
    function  ToJson: RawUtf8;
    procedure FromJson(const AJson: RawUtf8);
    procedure Clear;
  end;

{ TRadPermissionImpl }

constructor TRadPermissionImpl.Create(const AJson: RawUtf8);
begin
  inherited Create;
  FHash.InitSpecific(TypeInfo(TRawUtf8DynArray), FArr, djRawUtf8, nil, {caseInsensitive=}True);
  if AJson <> '[]' then
    FromJson(AJson);
end;

function TRadPermissionImpl.K(const AName: string): RawUtf8;
begin
  Result := StringToUtf8(AName);
end;

procedure TRadPermissionImpl.HashAdd(const AKey: RawUtf8);
var
  idx: Integer;
  added: Boolean;
begin
  idx := FHash.FindHashedForAdding(AKey, added);
  if added then
    FArr[idx] := AKey;
end;

function TRadPermissionImpl.IsExists(const AName: string): Boolean;
begin
  Result := FHash.FindHashed(AName) >= 0;
end;

function TRadPermissionImpl.Get(const AName: string; const ADefault: Boolean): Boolean;
begin
  if FHash.FindHashed(AName) >= 0 then
    Result := True
  else
    Result := ADefault;
end;

procedure TRadPermissionImpl.Add(const AName: string; const AValue: Boolean);
begin
  if AValue then
    HashAdd(K(AName))
  else
    FHash.FindHashedAndDelete(AName);
end;

function TRadPermissionImpl.AddOrGet(const AName: string; const ADefault: Boolean): Boolean;
var
  key: RawUtf8;
begin
  key := K(AName);
  if FHash.FindHashed(key) >= 0 then
    Result := True
  else
  begin
    Result := ADefault;
    if ADefault then
      HashAdd(key);
  end;
end;

function TRadPermissionImpl.ToJson: RawUtf8;
var
  W: TJsonWriter;
  i: Integer;
begin
  W := TJsonWriter.CreateOwnedStream(512);
  try
    W.Add('[');
    for i := 0 to High(FArr) do
    begin
      if i > 0 then W.AddComma;
      W.AddJsonString(FArr[i]);
    end;
    W.Add(']');
    W.SetText(Result);
  finally
    W.Free;
  end;
end;

procedure TRadPermissionImpl.FromJson(const AJson: RawUtf8);
var
  dv: TDocVariantData;
  i : Integer;
  k : RawUtf8;
begin
  Clear;
  dv.InitJson(AJson, JSON_FAST);
  if dv.Kind = dvArray then
    for i := 0 to dv.Count - 1 do
    begin
      VariantToUtf8(dv.Values[i], k);
      HashAdd(k);
    end;
end;

procedure TRadPermissionImpl.Clear;
begin
  SetLength(FArr, 0);
  FHash.ReHash;
end;

{ Factory }

function NewPermission(const AJson: RawUtf8): IPermission;
begin
  Result := TRadPermissionImpl.Create(AJson);
end;

end.
