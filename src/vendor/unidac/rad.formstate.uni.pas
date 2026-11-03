unit rad.formstate.uni;

{ UniDAC store of the form-state system (docs/specs/rad.formstate.md): one row per record in a
  table the host creates (CreateTableSql). Runs on the host's connection, on the calling thread. }

interface

uses
  System.SysUtils,
  System.Classes,
  Data.DB,
  Uni,
  mormot.core.base,
  rad.formstate.core,
  rad.formstate.store;

const
  RAD_STATE_DEFAULT_TABLE = 'rad_form_state';

type
  /// <summary>PostgreSQL, SQL Server and Firebird (InterBase provider) table store.</summary>
  /// <remarks>Saves with UPDATE, then INSERT when no row changed: one statement pair for all three
  /// databases. The connection belongs to the host and is never opened, closed or freed here.</remarks>
  TRadUniStateStore = class(TInterfacedObject, IRadStateStore)
  private
    FConnection: TUniConnection;
    FTable: string;
    function NewQuery(const ASql: string): TUniQuery;
    procedure SetKeyParams(AQuery: TUniQuery; const AKey: TRadStateKey);
    function WriteRow(const ASql: string; const AKey: TRadStateKey; const AData: RawByteString): Integer;
    procedure WarnIfNotUnicode;
  public
    /// <summary>ATable may be schema-qualified; anything but identifiers raises ERadFormState.</summary>
    constructor Create(AConnection: TUniConnection; const ATable: string = RAD_STATE_DEFAULT_TABLE);
    /// <summary>CREATE TABLE text for a UniDAC provider name ('PostgreSQL', 'SQL Server', 'InterBase').</summary>
    class function CreateTableSql(const AProviderName: string;
      const ATable: string = RAD_STATE_DEFAULT_TABLE): string; static;
    function Load(const AKey: TRadStateKey; out AData: RawByteString): Boolean;
    procedure Save(const AKey: TRadStateKey; const AData: RawByteString);
    procedure Delete(const AKey: TRadStateKey);
    function LoadScope(const AScope: RawUtf8): TRadStateEntries;
    property Table: string read FTable;
  end;

implementation

uses
  mormot.core.os,
  mormot.core.rtti, // lets TSynLog.Add inline (H2443)
  mormot.core.unicode,
  mormot.core.log;

const
  PROVIDER_POSTGRESQL = 'PostgreSQL';
  PROVIDER_SQLSERVER = 'SQL Server';
  PROVIDER_FIREBIRD = 'InterBase';

  SQL_LOAD = 'select payload from %s where scope = :scope and form_key = :form_key';
  SQL_UPDATE = 'update %s set payload = :payload, updated_at = :updated_at ' +
    'where scope = :scope and form_key = :form_key';
  SQL_INSERT = 'insert into %s (scope, form_key, payload, updated_at) ' +
    'values (:scope, :form_key, :payload, :updated_at)';
  SQL_DELETE = 'delete from %s where scope = :scope and form_key = :form_key';
  SQL_SCOPE = 'select form_key, payload from %s where scope = :scope';
  SQL_CREATE = 'create table %s (scope %s not null, form_key %s not null, payload %s not null, ' +
    'updated_at %s not null, primary key (scope, form_key))';

function IsTableName(const AName: string): Boolean;
var
  LPart: string;
begin
  Result := AName <> '';
  for LPart in AName.Split(['.']) do
    Result := Result and IsValidIdent(LPart);
end;

function ToBytes(const AData: RawByteString): TBytes;
begin
  SetLength(Result, Length(AData));
  if AData <> '' then
    Move(Pointer(AData)^, Result[0], Length(AData));
end;

function ToRaw(const ABytes: TBytes): RawByteString;
begin
  SetString(Result, PAnsiChar(PByte(ABytes)), Length(ABytes));
end;

{ TRadUniStateStore }

constructor TRadUniStateStore.Create(AConnection: TUniConnection; const ATable: string);
begin
  inherited Create;
  if AConnection = nil then
    raise ERadFormState.Create('TRadUniStateStore needs a connection');
  if not IsTableName(ATable) then
    raise ERadFormState.CreateFmt('Invalid state table name: %s', [ATable]);
  FConnection := AConnection;
  FTable := ATable;
  WarnIfNotUnicode;
end;

procedure TRadUniStateStore.WarnIfNotUnicode;
begin
  // Measured on PostgreSQL: without UseUnicode a key such as 'İkinci Ω' is stored as '?kinci ?'.
  // Save and load garble it the same way, so lookups still match, but two different non-ASCII
  // scopes can collapse into one. Changing the host's connection here would change its whole
  // app (UseUnicode swaps the field classes), so this only warns.
  if (SameText(FConnection.ProviderName, PROVIDER_POSTGRESQL) or
    SameText(FConnection.ProviderName, PROVIDER_FIREBIRD)) and
    not SameText(FConnection.SpecificOptions.Values['UseUnicode'], 'True') then
    TSynLog.Add.Log(sllWarning, 'rad.formstate: % connection without UseUnicode; non-ASCII scopes ' +
      'and keys are stored lossy', [FConnection.ProviderName]);
end;

class function TRadUniStateStore.CreateTableSql(const AProviderName, ATable: string): string;
begin
  if not IsTableName(ATable) then
    raise ERadFormState.CreateFmt('Invalid state table name: %s', [ATable]);
  if SameText(AProviderName, PROVIDER_POSTGRESQL) then
    Result := Format(SQL_CREATE, [ATable, 'varchar(100)', 'varchar(200)', 'bytea', 'timestamp'])
  else if SameText(AProviderName, PROVIDER_SQLSERVER) then
    // nvarchar: a Turkish user name in the scope must survive a non-Unicode collation
    Result := Format(SQL_CREATE, [ATable, 'nvarchar(100)', 'nvarchar(200)', 'varbinary(max)', 'datetime2'])
  else if SameText(AProviderName, PROVIDER_FIREBIRD) then
    Result := Format(SQL_CREATE, [ATable, 'varchar(100)', 'varchar(200)', 'blob sub_type 0', 'timestamp'])
  else
    raise ERadFormState.CreateFmt('No state table DDL for provider %s', [AProviderName]);
end;

function TRadUniStateStore.NewQuery(const ASql: string): TUniQuery;
begin
  Result := TUniQuery.Create(nil);
  try
    Result.Connection := FConnection;
    Result.SQL.Text := Format(ASql, [FTable]);
  except
    Result.Free;
    raise;
  end;
end;

procedure TRadUniStateStore.SetKeyParams(AQuery: TUniQuery; const AKey: TRadStateKey);
begin
  // Wide strings: an ANSI parameter would mangle a Turkish scope on SQL Server.
  AQuery.ParamByName('scope').AsWideString := Utf8ToString(AKey.Scope);
  AQuery.ParamByName('form_key').AsWideString := Utf8ToString(AKey.Name);
end;

function TRadUniStateStore.WriteRow(const ASql: string; const AKey: TRadStateKey;
  const AData: RawByteString): Integer;
var
  LQuery: TUniQuery;
  LBytes: TBytes;
begin
  LBytes := ToBytes(AData);
  LQuery := NewQuery(ASql);
  try
    SetKeyParams(LQuery, AKey);
    LQuery.ParamByName('payload').DataType := ftBlob;
    LQuery.ParamByName('payload').SetBlobData(PByte(LBytes), Length(LBytes));
    LQuery.ParamByName('updated_at').AsDateTime := NowUtc;
    LQuery.ExecSQL;
    Result := LQuery.RowsAffected;
  finally
    LQuery.Free;
  end;
end;

function TRadUniStateStore.Load(const AKey: TRadStateKey; out AData: RawByteString): Boolean;
var
  LQuery: TUniQuery;
begin
  AData := '';
  LQuery := NewQuery(SQL_LOAD);
  try
    SetKeyParams(LQuery, AKey);
    LQuery.Open;
    if not LQuery.Eof then
      AData := ToRaw(LQuery.Fields[0].AsBytes);
  finally
    LQuery.Free;
  end;
  Result := AData <> '';
end;

procedure TRadUniStateStore.Save(const AKey: TRadStateKey; const AData: RawByteString);
begin
  if WriteRow(SQL_UPDATE, AKey, AData) = 0 then
    WriteRow(SQL_INSERT, AKey, AData);
end;

procedure TRadUniStateStore.Delete(const AKey: TRadStateKey);
var
  LQuery: TUniQuery;
begin
  LQuery := NewQuery(SQL_DELETE);
  try
    SetKeyParams(LQuery, AKey);
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

function TRadUniStateStore.LoadScope(const AScope: RawUtf8): TRadStateEntries;
var
  LQuery: TUniQuery;
  LCount: Integer;
begin
  Result := nil;
  LQuery := NewQuery(SQL_SCOPE);
  try
    LQuery.ParamByName('scope').AsWideString := Utf8ToString(AScope);
    LQuery.Open;
    while not LQuery.Eof do
    begin
      LCount := Length(Result);
      SetLength(Result, LCount + 1);
      Result[LCount].Key := TRadStateKey.Make(AScope, StringToUtf8(LQuery.Fields[0].AsString));
      Result[LCount].Data := ToRaw(LQuery.Fields[1].AsBytes);
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

end.
