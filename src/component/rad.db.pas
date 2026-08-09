unit rad.db;

{
  Smart Delphi Framework — UniDAC veritabanı katmanı
  TAksa* → TRad* migration, Aksa.*/sdk bağımlılıkları temizlendi.

  Bileşenler:
    TRadEventHandler    — paylaşılan dataset event handler component
    TRadAutoValueItem   — event bazlı otomatik alan doldurma
    TRadFilterItem      — design-time filtre tanımı
    TRadUnitOfWork      — birden fazla dataset/SQL tek transaction'da
    TRadConnectionSetting — audit, DB versiyon, SQL migration
    TRadConnection      — TUniConnection + fluent API + helpers
    TRadQuery           — TUniQuery + auto-transaction + fluent API + async

  TDataSetHelper (Help.DB.pas) metodları TRadQuery üzerinde otomatik çalışır.

  Kullanım örneği:
    Conn.InTransaction(procedure begin
      Qry.Post;          // otomatik savepoint/commit
      Conn.Exec('INSERT INTO Log ...');
    end);

    Conn.QueryInt('SELECT COUNT(*) FROM Orders WHERE Status = :S', [1]);

    Qry.OpenAsync
       .OnSuccess(procedure(t) begin Grid.Refresh end)
       .Start;
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Variants,
  System.Rtti,
  System.StrUtils,
  System.Math,
  System.IOUtils,
  System.Generics.Collections,
  System.Generics.Defaults,
  Data.DB,
  Data.SqlTimSt,
  Uni,
  UniProvider,
  DBAccess,
  UniScript,
  MemDS,
  mormot.core.base,
  mormot.core.variants,
  mormot.core.unicode,
  mormot.db.core,
  Help.DB,
  rad.permission,
  rad.thread;

const
  RadFilterTypeConst: array[1..4] of string = (' AND ', ' AND NOT ', ' OR ', ' OR NOT ');

type
  { ── Enum tipler ──────────────────────────────────────────────────────────── }

  TRadFilterType = (rfAnd = 0, rfNotAnd = 1, rfOr = 2, rfNotOr = 3);

  TRadFilterOp = (
    foEqual, foNotEqual, foLess, foLessEqual, foGreater, foGreaterEqual,
    foLike, foNotLike, foBetween, foNotBetween,
    foInList, foNotInList, foBeginsWith, foEndsWith
  );

  TRadDSEventKind = (
    evLoaded,
    evBeforeOpen,  evAfterOpen,
    evBeforeInsert, evAfterInsert,
    evBeforeEdit,   evAfterEdit,
    evBeforePost,   evAfterPost,
    evBeforeDelete, evAfterDelete,
    evError
  );
  TRadDSEventKinds = set of TRadDSEventKind;

  TRadDSNotifyEvent = procedure(const AEvent: TRadDSEventKind;
                                ADataSet: TDataSet;
                                const AArgs: TArray<TValue>) of object;

  TRadAuditType  = (auNone, auChange, auFull);
  TRadSQLLogType = (slNone, slLast, slFull);

  TRadWorkAction = (waInsert, waUpdate, waDelete, waExecSQL);

  TRadQueryCmd  = (rcNoInsert, rcNoEdit, rcNoDelete, rcSoftDelete,
                   rcDetailsOpen, rcDetailsPost, rcMasterEdit, rcMasterInsertID);
  TRadQueryCmds = set of TRadQueryCmd;


  { ── Forward decls ────────────────────────────────────────────────────────── }

  TRadQuery             = class;
  TRadConnection        = class;
  TRadEventHandlerItem  = class;
  TRadAutoValueItem     = class;
  TRadFilterItem        = class;


  { ── Delegate tipler ──────────────────────────────────────────────────────── }

  TRadIDGenerator  = function(const AScope: string; const AInc: Cardinal = 1): Variant of object;
  TRadCmdExecutor  = function(const ACmd: string; ADataSet: TDataSet;
                               const AArgs: TArray<TValue>): Variant of object;
  TQueryProc       = reference to procedure(q: TRadQuery);

  { ── TRadEventHandler ─────────────────────────────────────────────────────── }

  [ComponentPlatformsAttribute(pidAllPlatforms)]
  TRadEventHandler = class(TComponent)
  strict private
    FEnabled : Boolean;
    FEvents  : TRadDSEventKinds;
    FOnEvent : TRadDSNotifyEvent;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Enabled: Boolean          read FEnabled  write FEnabled default True;
    property Events:  TRadDSEventKinds read FEvents   write FEvents;
    property OnEvent: TRadDSNotifyEvent read FOnEvent write FOnEvent;
  end;

  TRadEventHandlerItem = class(TCollectionItem)
  strict private
    FEnabled : Boolean;
    FHandler : TRadEventHandler;
  public
    constructor Create(Collection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
  published
    property Enabled: Boolean          read FEnabled write FEnabled default True;
    property Handler: TRadEventHandler read FHandler write FHandler;
  end;

  TRadEventHandlers = class(TCollection)
  public type
    TEnumerator = record
    private
      FCol: TRadEventHandlers;
      FIdx: Integer;
      function GetCurrent: TRadEventHandlerItem;
    public
      constructor Create(ACol: TRadEventHandlers);
      function MoveNext: Boolean;
      property Current: TRadEventHandlerItem read GetCurrent;
    end;
  private
    FOwner: TPersistent;
    function GetItem(Index: Integer): TRadEventHandlerItem;
  public
    constructor Create(AOwner: TPersistent);
    function GetOwner: TPersistent; override;
    function Add: TRadEventHandlerItem;
    function GetEnumerator: TEnumerator;
    property Items[Index: Integer]: TRadEventHandlerItem read GetItem; default;
  end;

  { ── TRadAutoValueItem ────────────────────────────────────────────────────── }

  TRadAutoValueItem = class(TCollectionItem)
  strict private
    FEnabled   : Boolean;
    FEvents    : TRadDSEventKinds;
    FFieldName : string;
    FCommand   : string;
    FValue     : Variant;
  public
    constructor Create(Collection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
  published
    property Enabled:   Boolean          read FEnabled   write FEnabled default True;
    property Events:    TRadDSEventKinds read FEvents    write FEvents;
    property FieldName: string           read FFieldName write FFieldName;
    property Command:   string           read FCommand   write FCommand;
    property Value:     Variant          read FValue     write FValue;
  end;

  TRadAutoValues = class(TCollection)
  public type
    TEnumerator = record
    private
      FCol: TRadAutoValues;
      FIdx: Integer;
      function GetCurrent: TRadAutoValueItem;
    public
      constructor Create(ACol: TRadAutoValues);
      function MoveNext: Boolean;
      property Current: TRadAutoValueItem read GetCurrent;
    end;
  private
    FOwner: TPersistent;
    function GetItem(Index: Integer): TRadAutoValueItem;
  public
    constructor Create(AOwner: TPersistent);
    function GetOwner: TPersistent; override;
    function Add: TRadAutoValueItem;
    function GetEnumerator: TEnumerator;
    property Items[Index: Integer]: TRadAutoValueItem read GetItem; default;
  end;

  { ── TRadFilterItem ───────────────────────────────────────────────────────── }

  TRadFilterItem = class(TCollectionItem)
  strict private
    FAlias      : string;
    FFilterField: string;
    FFilter1    : string;
    FFilter2    : string;
    FOperation  : TRadFilterOp;
    FCaption    : string;
    FFilterType : TRadFilterType;
    FEnable     : Boolean;
    FFieldType  : TFieldType;
    function  GetDisplayName: string; override;
    procedure SetFilterField(const Value: string);
  public
    constructor Create(Collection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
    function  ResolvedField: string;
  published
    property Alias      : string          read FAlias       write FAlias;
    property Caption    : string          read FCaption     write FCaption;
    property FilterType : TRadFilterType  read FFilterType  write FFilterType;
    property Operation  : TRadFilterOp   read FOperation   write FOperation;
    property FilterField: string          read FFilterField write SetFilterField;
    property Filter1    : string          read FFilter1     write FFilter1;
    property Filter2    : string          read FFilter2     write FFilter2;
    property Enable     : Boolean         read FEnable      write FEnable;
    property FieldType  : TFieldType      read FFieldType   write FFieldType;
  end;

  TRadFilterCollection = class(TCollection)
  public type
    TEnumerator = record
    private
      FCol: TRadFilterCollection;
      FIdx: Integer;
      function GetCurrent: TRadFilterItem;
    public
      constructor Create(ACol: TRadFilterCollection);
      function MoveNext: Boolean;
      property Current: TRadFilterItem read GetCurrent;
    end;
  private
    FOwner: TPersistent;
    function GetItem(Index: Integer): TRadFilterItem;
  public
    constructor Create(AOwner: TPersistent);
    function GetOwner: TPersistent; override;
    function Add: TRadFilterItem;
    function GetEnumerator: TEnumerator;
    property Items[Index: Integer]: TRadFilterItem read GetItem; default;
  end;

  { ── TRadQuerySetting ─────────────────────────────────────────────────────── }

  TRadQuerySetting = class(TPersistent)
  strict private
    FOwner         : TPersistent;
    FEventHandlers : TRadEventHandlers;
    FAutoValues    : TRadAutoValues;
    FFilters       : TRadFilterCollection;
    FCommands      : TRadQueryCmds;
    FDeleteConfirm : Boolean;
    procedure SetAutoValues(const Value: TRadAutoValues);
  public
    constructor Create(AOwner: TPersistent);
    destructor  Destroy; override;
    function    GetOwner: TPersistent; override;
    function    IsCommand(ACmd: TRadQueryCmd): Boolean;
    function    SetCommand(ACmd: TRadQueryCmd; AValue: Boolean): TRadQuerySetting;
    function    LoadPermission(const AScope: string; const APermission: IPermission): TRadQuerySetting;
  published
    property EventHandlers : TRadEventHandlers    read FEventHandlers write FEventHandlers;
    property AutoValues    : TRadAutoValues       read FAutoValues    write SetAutoValues;
    property Filters       : TRadFilterCollection read FFilters       write FFilters;
    property Commands      : TRadQueryCmds        read FCommands      write FCommands;
    property DeleteConfirm : Boolean              read FDeleteConfirm write FDeleteConfirm;
  end;

  { ── TRadUnitOfWork ───────────────────────────────────────────────────────── }

  TRadWorkItem = record
    DataSet: TDataSet;
    Action : TRadWorkAction;
    SQL    : string;
  end;

  [ComponentPlatformsAttribute(pidAllPlatforms)]
  TRadUnitOfWork = class(TComponent)
  strict private
    FConnection: TRadConnection;
    FItems     : TList<TRadWorkItem>;
    FInWork    : Boolean;
    FInCommit  : Boolean;
    procedure SetConnection(const Value: TRadConnection);
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;

    class function ActionToStr(const AAction: TRadWorkAction): string;

    procedure RegisterDataSet(ADataSet: TDataSet; AAction: TRadWorkAction);
    procedure RegisterSQL(const ASQL: string);
    function  Commit: Boolean;
    procedure Rollback;
    procedure Clear;

    property InWork  : Boolean read FInWork;
    property InCommit: Boolean read FInCommit;
  published
    property Connection: TRadConnection read FConnection write SetConnection;
  end;

  { ── TRadConnectionSetting ────────────────────────────────────────────────── }

  TRadConnectionSetting = class(TPersistent)
  private
    FConnection   : TRadConnection;
    FSqlFileList  : TList<TPair<Cardinal, string>>;
    FDBVersion    : Integer;
    FSettingTable : string;
    FVersionField : string;
    FDBMinVersion : Cardinal;
    FAudit        : TRadAuditType;
    FSQLLogType   : TRadSQLLogType;
    function GetDBVersion: Integer;
  public
    constructor Create(AOwner: TRadConnection);
    destructor  Destroy; override;
    procedure   MigrateDBFolder(const AFolder: string);
  published
    property DBSettingTable: string          read FSettingTable write FSettingTable;
    property DBVersionField: string          read FVersionField write FVersionField;
    property DBMinVersion  : Cardinal        read FDBMinVersion write FDBMinVersion;
    property DBVersion     : Integer         read GetDBVersion;
    property Audit         : TRadAuditType   read FAudit        write FAudit;
    property SQLLogType    : TRadSQLLogType  read FSQLLogType   write FSQLLogType;
  end;

  { ── TRadConnection ───────────────────────────────────────────────────────── }

  [ComponentPlatformsAttribute(pidAllPlatforms)]
  TRadConnection = class(TUniConnection)
  strict private
    FSetting     : TRadConnectionSetting;
    FIDGenerator : TRadIDGenerator;
    FCmdExecutor : TRadCmdExecutor;
    FGlobalEvent : TRadDSNotifyEvent;
  private
    function  CloneConnection: TUniConnection;
    function  DoGenID(const AScope: string; const AInc: Cardinal = 1): Variant;
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;

    { Fluent config }
    function Provider (const AValue: string): TRadConnection;
    function Server   (const AValue: string): TRadConnection;
    function Database (const AValue: string): TRadConnection;
    function Username (const AValue: string): TRadConnection;
    function Password (const AValue: string): TRadConnection;
    function SetPort  (AValue: Integer): TRadConnection;
    function Pool     (AMin: Integer = 1; AMax: Integer = 10): TRadConnection;

    { Bağlantı }
    function TryConnect: Boolean;
    function Ping: Boolean;

    { DB meta helpers }
    function ServerType: TSqlDBDefinition;
    procedure ServerMacroLoad;
    function TableExists(const ATableName: string): Boolean;
    function QueryScalar(const ASQL: string; const ADefault: Variant): Variant;

    { Audit }
    function AuditCapture(ADataSet: TDataSet; const AOperation: string): string;

    { Query factory & RAII }
    function NewQuery: TRadQuery; overload;
    function NewQuery(const ASQL: string): TRadQuery; overload;
    procedure WithQuery(AProc: TQueryProc); overload;
    procedure WithQuery(const ASQL: string; AProc: TQueryProc); overload;

    { Quick exec }
    function Exec(const ASQL: string): Variant; overload;
    function Exec(const ASQL: string; const AParams: array of Variant): Variant; overload;
    procedure ExecBatch(const ASQLList: array of string); overload;
    procedure ExecBatch(const ASQLList: array of string;
                        const AParamsList: array of TArray<Variant>); overload;

    { Async exec }
    function ExecAsync(const ASQL: string): TRadTask; overload;
    function ExecAsync(const ASQL: string; const AParams: array of Variant): TRadTask; overload;

    { Connection-level scalar — lifecycle tamamen yönetilir }
    function QueryInt   (const ASQL: string; const AParams: array of Variant; ADefault: Integer  = 0): Integer; overload;
    function QueryInt64 (const ASQL: string; const AParams: array of Variant; ADefault: Int64    = 0): Int64; overload;
    function QueryStr   (const ASQL: string; const AParams: array of Variant; const ADefault: string = ''): string; overload;
    function QueryFloat (const ASQL: string; const AParams: array of Variant; ADefault: Double   = 0): Double; overload;
    function QueryBool  (const ASQL: string; const AParams: array of Variant; ADefault: Boolean  = False): Boolean; overload;
    function QueryVar   (const ASQL: string; const AParams: array of Variant): Variant; overload;
    function QueryExists(const ASQL: string; const AParams: array of Variant): Boolean; overload;

    { Parametresiz overload'lar }
    function QueryInt   (const ASQL: string; ADefault: Integer  = 0): Integer; overload;
    function QueryInt64 (const ASQL: string; ADefault: Int64    = 0): Int64; overload;
    function QueryStr   (const ASQL: string; const ADefault: string = ''): string; overload;
    function QueryFloat (const ASQL: string; ADefault: Double   = 0): Double; overload;
    function QueryBool  (const ASQL: string; ADefault: Boolean  = False): Boolean; overload;
    function QueryVar   (const ASQL: string): Variant; overload;
    function QueryExists(const ASQL: string): Boolean; overload;

    { Transaction }
    procedure InTransaction(AProc: TProc); overload;
    function  InTransaction(AFunc: TFunc<Boolean>): Boolean; overload;
    procedure WithSavepoint(const AName: string; AProc: TProc);

  published
    property Setting    : TRadConnectionSetting read FSetting     write FSetting;
    property IDGenerator: TRadIDGenerator       read FIDGenerator write FIDGenerator;
    property CmdExecutor: TRadCmdExecutor       read FCmdExecutor write FCmdExecutor;
    property GlobalEvent: TRadDSNotifyEvent     read FGlobalEvent write FGlobalEvent;
  end;

  { ── TRadQuery ────────────────────────────────────────────────────────────── }

  [ComponentPlatformsAttribute(pidWin32 or pidWin64)]
  TRadQuery = class(TUniQuery)
  strict private
    FOwnsTransactionType: Byte;
    FSavePointName      : string;
    FSQLCommands        : TList<string>;
    FLastEvent          : TRadDSEventKind;
    FLastFilter         : Variant;
  private
    FSetting   : TRadQuerySetting;
    FDetailSets: TList<TDataSet>;
    FUnitOfWork: TRadUnitOfWork;
  protected
    procedure DoEvent(const AEvent: TRadDSEventKind);
    procedure DoAfterDelete; override;
    procedure DoAfterEdit;   override;
    procedure DoAfterInsert; override;
    procedure DoAfterOpen;   override;
    procedure DoAfterPost;   override;
    procedure DoAfterScroll; override;
    procedure DoBeforeDelete; override;
    procedure DoBeforeEdit;   override;
    procedure DoBeforeInsert; override;
    procedure DoBeforeOpen;   override;
    procedure DoBeforePost;   override;
    procedure Loaded; override;
    procedure ApplyUpdates; override;
    procedure Post; override;
    procedure InternalDelete; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;

    { Transaction helpers — dahili, UnitOfWork farkındalıklı }
    procedure _BeginWork;
    procedure _CommitWork;
    procedure _RollbackWork;
    procedure _ExecuteSQLCommands;
    procedure _AddWorkAction(const AAction: TRadWorkAction);
    function  _Transaction: TUniTransaction;

    { ID & kod }
    function _GenID(const AScopeName: string = ''): Variant;
    function _LastInsertId: Largeint;

    { Detail set yönetimi }
    function  _DetailSets: TList<TDataSet>;
    procedure _DetailsOpen;
    procedure _DetailsPost;

    { Fluent kurulum }
    function Text      (const ASQL: string): TRadQuery;
    function Param     (const AName: string; const AValue: Variant): TRadQuery;
    function ParamNull (const AName: string; AType: TFieldType = ftString): TRadQuery;
    function BindDoc   (const ADoc: TDocVariantData): TRadQuery;
    function CachedMode(AEnabled: Boolean = True): TRadQuery;

    { Filtre }
    procedure FiltreApply(const AValue: Variant);
    procedure FiltreClear;

    { Satır iterasyonu & çıktı }
    procedure Each(AProc: TProc);
    function  ToDocList: IDocList;
    procedure _ToList(const ALst: TStrings; const AFields: TArray<string> = [];
                      const AFormat: string = '');

    { Scalar — terminal, otomatik free }
    function ScalarInt  (ADefault: Integer  = 0): Integer;
    function ScalarInt64(ADefault: Int64    = 0): Int64;
    function ScalarStr  (const ADefault: string = ''): string;
    function ScalarFloat(ADefault: Double   = 0): Double;
    function ScalarBool (ADefault: Boolean  = False): Boolean;
    function ScalarVar: Variant;

    { Open/Exec }
    function OpenSelf: TRadQuery;
    function OpenAsync: TRadTask;
    function ExecAsync: TRadTask;

    { Bağlantı cast }
    function AsCn: TRadConnection;

  published
    property Setting    : TRadQuerySetting  read FSetting    write FSetting;
    property UnitOfWork : TRadUnitOfWork    read FUnitOfWork write FUnitOfWork;
    property LastEvent  : TRadDSEventKind   read FLastEvent;
    property LastFilter : Variant           read FLastFilter;
  end;

{ Filtre SQL üretici }
function RadFilterToSQL(const AFieldType: TFieldType; AOperation: TRadFilterOp;
                        const AFieldName: string; const v1, v2: Variant): string;

implementation
 uses help.uni;
{ ═══════════════════════════════════════════════════════════════════════════════
  Yardımcı
  ═══════════════════════════════════════════════════════════════════════════════}

function RadFilterToSQL(const AFieldType: TFieldType; AOperation: TRadFilterOp;
                        const AFieldName: string; const v1, v2: Variant): string;
const
  CFilterFmt: array[TRadFilterOp] of string = (
    '=%s', '<>%s', '<%s', '<=%s', '>%s', '>=%s',
    'LIKE %s', 'NOT LIKE %s',
    'BETWEEN %s AND %s', 'NOT BETWEEN %s AND %s',
    'IN (%s)', 'NOT IN (%s)',
    'LIKE %s', 'LIKE %s'
  );
var
  s, Val1, Val2: string;
  Val: Variant;
begin
  Val1 := '';
  Val2 := '';

  if AOperation in [foBetween, foNotBetween] then
  begin
    if not VarIsNull(v2) and not VarIsEmpty(v2) then
      Val2 := FieldToSqlStr(AFieldType, v2, 1)
    else
      AOperation := foGreaterEqual;
  end;

  s := AFieldName + ' ' + CFilterFmt[AOperation];

  case AOperation of
    foLike, foNotLike  : Val := '%' + VarToStr(v1) + '%';
    foBeginsWith       : Val := VarToStr(v1) + '%';
    foEndsWith         : Val := '%' + VarToStr(v1);
  else
    Val := v1;
  end;

  Val1 := FieldToSqlStr(AFieldType, Val);

  if Val2.IsEmpty then
    Result := Format(s, [Val1])
  else
    Result := Format(s, [Val1, Val2]);
end;

{ ═══════════════════════════════════════════════════════════════════════════════
  TRadEventHandler
  ═══════════════════════════════════════════════════════════════════════════════}

constructor TRadEventHandler.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEnabled := True;
  FEvents  := [];
end;

{ ── TRadEventHandlerItem ─────────────────────────────────────────────────────}

constructor TRadEventHandlerItem.Create(Collection: TCollection);
begin
  inherited Create(Collection);
  FEnabled := True;
  FHandler := nil;
end;

procedure TRadEventHandlerItem.Assign(Source: TPersistent);
var
  Src: TRadEventHandlerItem;
begin
  if Source is TRadEventHandlerItem then
  begin
    Src      := TRadEventHandlerItem(Source);
    FEnabled := Src.FEnabled;
    FHandler := Src.FHandler;
  end
  else
    inherited Assign(Source);
end;

{ ── TRadEventHandlers ────────────────────────────────────────────────────────}

constructor TRadEventHandlers.Create(AOwner: TPersistent);
begin
  inherited Create(TRadEventHandlerItem);
  FOwner := AOwner;
end;

function TRadEventHandlers.GetOwner: TPersistent;
begin
  Result := FOwner;
end;

function TRadEventHandlers.Add: TRadEventHandlerItem;
begin
  Result := TRadEventHandlerItem(inherited Add);
end;

function TRadEventHandlers.GetItem(Index: Integer): TRadEventHandlerItem;
begin
  Result := TRadEventHandlerItem(inherited GetItem(Index));
end;

function TRadEventHandlers.GetEnumerator: TEnumerator;
begin
  Result := TEnumerator.Create(Self);
end;

constructor TRadEventHandlers.TEnumerator.Create(ACol: TRadEventHandlers);
begin
  FCol := ACol;
  FIdx := -1;
end;

function TRadEventHandlers.TEnumerator.MoveNext: Boolean;
begin
  Inc(FIdx);
  Result := FIdx < FCol.Count;
end;

function TRadEventHandlers.TEnumerator.GetCurrent: TRadEventHandlerItem;
begin
  Result := FCol[FIdx];
end;

{ ═══════════════════════════════════════════════════════════════════════════════
  TRadAutoValueItem / TRadAutoValues
  ═══════════════════════════════════════════════════════════════════════════════}

constructor TRadAutoValueItem.Create(Collection: TCollection);
begin
  inherited Create(Collection);
  FEnabled   := True;
  FEvents    := [];
  FFieldName := '';
  FCommand   := '';
  FValue     := Null;
end;

procedure TRadAutoValueItem.Assign(Source: TPersistent);
var
  Src: TRadAutoValueItem;
begin
  if Source is TRadAutoValueItem then
  begin
    Src        := TRadAutoValueItem(Source);
    FEnabled   := Src.FEnabled;
    FEvents    := Src.FEvents;
    FFieldName := Src.FFieldName;
    FCommand   := Src.FCommand;
    FValue     := Src.FValue;
  end
  else
    inherited Assign(Source);
end;

constructor TRadAutoValues.Create(AOwner: TPersistent);
begin
  inherited Create(TRadAutoValueItem);
  FOwner := AOwner;
end;

function TRadAutoValues.GetOwner: TPersistent; begin Result := FOwner; end;

function TRadAutoValues.Add: TRadAutoValueItem;
begin
  Result := TRadAutoValueItem(inherited Add);
end;

function TRadAutoValues.GetItem(Index: Integer): TRadAutoValueItem;
begin
  Result := TRadAutoValueItem(inherited GetItem(Index));
end;

function TRadAutoValues.GetEnumerator: TEnumerator;
begin
  Result := TEnumerator.Create(Self);
end;

constructor TRadAutoValues.TEnumerator.Create(ACol: TRadAutoValues);
begin
  FCol := ACol;
  FIdx := -1;
end;

function TRadAutoValues.TEnumerator.MoveNext: Boolean;
begin
  Inc(FIdx);
  Result := FIdx < FCol.Count;
end;

function TRadAutoValues.TEnumerator.GetCurrent: TRadAutoValueItem;
begin
  Result := FCol[FIdx];
end;

{ ═══════════════════════════════════════════════════════════════════════════════
  TRadFilterItem / TRadFilterCollection
  ═══════════════════════════════════════════════════════════════════════════════}

constructor TRadFilterItem.Create(Collection: TCollection);
begin
  inherited Create(Collection);
  FEnable    := True;
  FFieldType := TFieldType.ftUnknown;
end;

procedure TRadFilterItem.Assign(Source: TPersistent);
var
  Src: TRadFilterItem;
begin
  if Source is TRadFilterItem then
  begin
    Src         := TRadFilterItem(Source);
    FAlias      := Src.FAlias;
    FFilterField := Src.FFilterField;
    FFilter1    := Src.FFilter1;
    FFilter2    := Src.FFilter2;
    FOperation  := Src.FOperation;
    FCaption    := Src.FCaption;
    FFilterType := Src.FFilterType;
    FEnable     := Src.FEnable;
    FFieldType  := Src.FFieldType;
  end
  else
    inherited Assign(Source);
end;

function TRadFilterItem.GetDisplayName: string;
begin
  Result := FFilterField + '-' + FCaption;
end;

procedure TRadFilterItem.SetFilterField(const Value: string);
begin
  FFilterField := Value;
  if FFilter1.IsEmpty  then FFilter1  := Value;
  if FCaption.IsEmpty  then FCaption  := Value;
  inherited SetDisplayName(Value + '-' + FCaption);
end;

function TRadFilterItem.ResolvedField: string;
begin
  Result := '';
  if not FAlias.IsEmpty      then Result := FAlias + '.';
  if not FFilterField.IsEmpty then Result := Result + FFilterField
  else if not FFilter1.IsEmpty then Result := Result + FFilter1;
end;

constructor TRadFilterCollection.Create(AOwner: TPersistent);
begin
  inherited Create(TRadFilterItem);
  FOwner := AOwner;
end;

function TRadFilterCollection.GetOwner: TPersistent; begin Result := FOwner; end;

function TRadFilterCollection.Add: TRadFilterItem;
begin
  Result := TRadFilterItem(inherited Add);
end;

function TRadFilterCollection.GetItem(Index: Integer): TRadFilterItem;
begin
  Result := TRadFilterItem(inherited GetItem(Index));
end;

function TRadFilterCollection.GetEnumerator: TEnumerator;
begin
  Result := TEnumerator.Create(Self);
end;

constructor TRadFilterCollection.TEnumerator.Create(ACol: TRadFilterCollection);
begin
  FCol := ACol;
  FIdx := -1;
end;

function TRadFilterCollection.TEnumerator.MoveNext: Boolean;
begin
  Inc(FIdx);
  Result := FIdx < FCol.Count;
end;

function TRadFilterCollection.TEnumerator.GetCurrent: TRadFilterItem;
begin
  Result := FCol[FIdx];
end;

{ ═══════════════════════════════════════════════════════════════════════════════
  TRadQuerySetting
  ═══════════════════════════════════════════════════════════════════════════════}

constructor TRadQuerySetting.Create(AOwner: TPersistent);
begin
  FOwner         := AOwner;
  FEventHandlers := TRadEventHandlers.Create(Self);
  FAutoValues    := TRadAutoValues.Create(Self);
  FFilters       := TRadFilterCollection.Create(Self);
end;

destructor TRadQuerySetting.Destroy;
begin
  FEventHandlers.Free;
  FAutoValues.Free;
  FFilters.Free;
  inherited Destroy;
end;

function TRadQuerySetting.GetOwner: TPersistent;
begin
  Result := FOwner;
end;

function TRadQuerySetting.IsCommand(ACmd: TRadQueryCmd): Boolean;
begin
  Result := ACmd in FCommands;
end;

function TRadQuerySetting.SetCommand(ACmd: TRadQueryCmd; AValue: Boolean): TRadQuerySetting;
begin
  if AValue then Include(FCommands, ACmd) else Exclude(FCommands, ACmd);
  Result := Self;
end;

function TRadQuerySetting.LoadPermission(const AScope: string;
                                          const APermission: IPermission): TRadQuerySetting;
begin
  if APermission <> nil then
  begin
    SetCommand(rcNoInsert, not APermission.Get(AScope + '.add',    True));
    SetCommand(rcNoEdit,   not APermission.Get(AScope + '.edit',   True));
    SetCommand(rcNoDelete, not APermission.Get(AScope + '.delete', True));
  end;
  Result := Self;
end;

procedure TRadQuerySetting.SetAutoValues(const Value: TRadAutoValues);
begin
  FAutoValues.Assign(Value);
end;

{ ═══════════════════════════════════════════════════════════════════════════════
  TRadUnitOfWork
  ═══════════════════════════════════════════════════════════════════════════════}

constructor TRadUnitOfWork.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems  := TList<TRadWorkItem>.Create;
  FInWork := False;
end;

destructor TRadUnitOfWork.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

procedure TRadUnitOfWork.SetConnection(const Value: TRadConnection);
begin
  if FInWork then
    raise Exception.Create('İşlem devam ederken bağlantı değiştirilemez.');
  FConnection := Value;
end;

class function TRadUnitOfWork.ActionToStr(const AAction: TRadWorkAction): string;
begin
  case AAction of
    waInsert  : Result := 'INSERT';
    waUpdate  : Result := 'UPDATE';
    waDelete  : Result := 'DELETE';
    waExecSQL : Result := 'EXECSQL';
  else
    Result := 'NONE';
  end;
end;

procedure TRadUnitOfWork.RegisterDataSet(ADataSet: TDataSet; AAction: TRadWorkAction);
var
  Item: TRadWorkItem;
begin
  Item.DataSet := ADataSet;
  Item.Action  := AAction;
  Item.SQL     := '';
  FItems.Add(Item);
  FInWork := True;
end;

procedure TRadUnitOfWork.RegisterSQL(const ASQL: string);
var
  Item: TRadWorkItem;
begin
  Item.DataSet := nil;
  Item.Action  := waExecSQL;
  Item.SQL     := ASQL;
  FItems.Add(Item);
  FInWork := True;
end;

function TRadUnitOfWork.Commit: Boolean;
var
  i      : Integer;
  Item   : TRadWorkItem;
  Updated: TList<TDataSet>;
begin
  Result := False;
  if (FConnection = nil) or (FItems.Count = 0) then Exit;

  FInCommit := True;
  Updated   := TList<TDataSet>.Create;
  try
    if not TUniConnection(FConnection).InTransaction then
      FConnection.StartTransaction;
    try
      for i := 0 to FItems.Count - 1 do
      begin
        Item := FItems[i];
        case Item.Action of
          waInsert, waUpdate, waDelete:
            if Assigned(Item.DataSet) then
            begin
              if Item.DataSet.State in [dsInsert, dsEdit] then
                Item.DataSet.Post;
              if (Item.DataSet is TRadQuery) and TRadQuery(Item.DataSet).CachedUpdates then
              begin
                TRadQuery(Item.DataSet).ApplyUpdates;
                if not Updated.Contains(Item.DataSet) then
                  Updated.Add(Item.DataSet);
              end;
            end;
          waExecSQL:
            FConnection.ExecSQL(Item.SQL);
        end;
      end;

      for i := 0 to Updated.Count - 1 do
        TRadQuery(Updated[i])._ExecuteSQLCommands;

      FConnection.Commit;
      Result := True;
      Clear;
    except
      if TUniConnection(FConnection).InTransaction then FConnection.Rollback;
      raise;
    end;
  finally
    Updated.Free;
    FInCommit := False;
  end;
end;

procedure TRadUnitOfWork.Rollback;
begin
  if Assigned(FConnection) and TUniConnection(FConnection).InTransaction then
    FConnection.Rollback;
  Clear;
end;

procedure TRadUnitOfWork.Clear;
begin
  FItems.Clear;
  FInWork := False;
end;

{ ═══════════════════════════════════════════════════════════════════════════════
  TRadConnectionSetting
  ═══════════════════════════════════════════════════════════════════════════════}

constructor TRadConnectionSetting.Create(AOwner: TRadConnection);
begin
  inherited Create;
  FConnection := AOwner;
  FDBVersion  := -1;  // -1 = henüz okunmadı
end;

destructor TRadConnectionSetting.Destroy;
begin
  FSqlFileList.Free;
  inherited Destroy;
end;

function TRadConnectionSetting.GetDBVersion: Integer;
begin
  Result := FDBVersion;
  if FDBVersion > -1 then Exit;
  if FConnection.Connected and not FSettingTable.IsEmpty and not FVersionField.IsEmpty then
    if FConnection.TableExists(FSettingTable) then
      FDBVersion := FConnection.QueryScalar(
        'SELECT ' + FVersionField + ' FROM ' + FSettingTable, 0);
  Result := FDBVersion;
end;

procedure TRadConnectionSetting.MigrateDBFolder(const AFolder: string);
var
  i      : Integer;
  s      : string;
  ArgFile: TArray<string>;
  SqlFolder: string;
  Script : TUniScript;
begin
  SqlFolder := AFolder + PathDelim + FConnection.ProviderName + PathDelim;
  if not FConnection.Connected then Exit;
  if not TDirectory.Exists(SqlFolder) then
  begin
    ForceDirectories(SqlFolder);
    Exit;
  end;

  if not Assigned(FSqlFileList) then
  begin
    ArgFile := TDirectory.GetFiles(SqlFolder, '*.sql');
    if Length(ArgFile) > 0 then
    begin
      FSqlFileList := TList<TPair<Cardinal, string>>.Create;
      for s in ArgFile do
      begin
        i := StrToIntDef(TPath.GetFileNameWithoutExtension(s), 0);
        if i > DBVersion then
          FSqlFileList.Add(TPair<Cardinal, string>.Create(i, s));
      end;
      FSqlFileList.Sort(TComparer<TPair<Cardinal, string>>.Construct(
        function(const Left, Right: TPair<Cardinal, string>): Integer
        begin
          Result := CompareInteger(Left.Key, Right.Key);
        end
      ));
    end;
  end;

  if not Assigned(FSqlFileList) then Exit;

  Script := TUniScript.Create(nil);
  try
    Script.Connection := FConnection;
    for var SqlFile in FSqlFileList do
      Script.ExecuteFile(SqlFile.Value);
  finally
    Script.Free;
  end;
end;

{ ═══════════════════════════════════════════════════════════════════════════════
  TRadConnection
  ═══════════════════════════════════════════════════════════════════════════════}

constructor TRadConnection.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSetting := TRadConnectionSetting.Create(Self);
end;

destructor TRadConnection.Destroy;
begin
  FSetting.Free;
  inherited Destroy;
end;

function TRadConnection.DoGenID(const AScope: string; const AInc: Cardinal): Variant;
begin
  if Assigned(FIDGenerator) then
    Result := FIDGenerator(AScope, AInc)
  else
    Result := Null;
end;

function TRadConnection.CloneConnection: TUniConnection;
begin
  Result := TUniConnection.Create(nil);
  Result.AssignConnect(Self);
  if Pooling then
  begin
    Result.Pooling := True;
    Result.PoolingOptions.MinPoolSize        := PoolingOptions.MinPoolSize;
    Result.PoolingOptions.MaxPoolSize        := PoolingOptions.MaxPoolSize;
    Result.PoolingOptions.ConnectionLifetime := PoolingOptions.ConnectionLifetime;
    Result.PoolingOptions.Validate           := PoolingOptions.Validate;
  end;
end;

{ Fluent config }

function TRadConnection.Provider(const AValue: string): TRadConnection;
begin
  ProviderName := AValue;
  Result := Self;
end;

function TRadConnection.Server(const AValue: string): TRadConnection;
begin
  inherited Server := AValue;
  Result := Self;
end;

function TRadConnection.Database(const AValue: string): TRadConnection;
begin
  inherited Database := AValue;
  Result := Self;
end;

function TRadConnection.Username(const AValue: string): TRadConnection;
begin
  inherited Username := AValue;
  Result := Self;
end;

function TRadConnection.Password(const AValue: string): TRadConnection;
begin
  inherited Password := AValue;
  Result := Self;
end;

function TRadConnection.SetPort(AValue: Integer): TRadConnection;
begin
  Port   := AValue;
  Result := Self;
end;

function TRadConnection.Pool(AMin, AMax: Integer): TRadConnection;
begin
  Pooling                    := True;
  PoolingOptions.MinPoolSize := AMin;
  PoolingOptions.MaxPoolSize := AMax;
  PoolingOptions.Validate    := True;
  Result := Self;
end;

{ Bağlantı }

function TRadConnection.TryConnect: Boolean;
begin
  Result := False;
  try
    Connect;
    Result := True;
  except
  end;
end;

function TRadConnection.Ping: Boolean;
begin
  Result := False;
  try
    inherited Ping;
    Result := True;
  except
  end;
end;

{ DB meta helpers }

function TRadConnection.ServerType: TSqlDBDefinition;
var
  pn: string;
begin
  pn := LowerCase(ProviderName);
  if pn.Contains('mssql') or pn.Contains('sqlserver') then
    Result := dMSSQL
  else if pn.Contains('postgre') then
    Result := dPostgreSQL
  else if pn.Contains('mysql') then
    Result := dMySQL
  else if pn.Contains('firebird') then
    Result := dFirebird
  else if pn.Contains('oracle') then
    Result := dOracle
  else if pn.Contains('sqlite') then
    Result := dSQLite
  else
    Result := dUnknown;
end;

procedure TRadConnection.ServerMacroLoad;
begin
  case ServerType of
    dMSSQL:
      Macros.Add('now', 'CURRENT_TIMESTAMP', 'SQLServer');
    dPostgreSQL:
      Macros.Add('now', 'CURRENT_TIMESTAMP', 'PostgreSQL');
    dMySQL:
      Macros.Add('now', 'NOW()', 'MySQL');
  end;
end;

function TRadConnection.TableExists(const ATableName: string): Boolean;
var
  q: TUniQuery;
begin
  Result := False;
  q := TUniQuery.Create(nil);
  try
    q.Connection := Self;
    case ServerType of
      dMSSQL:
        q.SQL.Text := 'SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = :N';
      dPostgreSQL:
        q.SQL.Text := 'SELECT 1 FROM information_schema.tables WHERE table_name = :N';
      dMySQL:
        q.SQL.Text := 'SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = :N AND TABLE_SCHEMA = DATABASE()';
    else
      q.SQL.Text := 'SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = :N';
    end;
    q.ParamByName('N').AsString := ATableName;
    q.Open;
    Result := not q.IsEmpty;
    q.Close;
  finally
    q.Free;
  end;
end;

function TRadConnection.QueryScalar(const ASQL: string; const ADefault: Variant): Variant;
var
  q: TUniQuery;
begin
  Result := ADefault;
  q := TUniQuery.Create(nil);
  try
    q.Connection := Self;
    q.SQL.Text   := ASQL;
    q.Open;
    if not q.IsEmpty then Result := q.Fields[0].Value;
    q.Close;
  finally
    q.Free;
  end;
end;

{ Audit }

function TRadConnection.AuditCapture(ADataSet: TDataSet; const AOperation: string): string;
var
  i         : Integer;
  LSnapshot : IDocDict;
  LField    : TField;
  TableName : string;
  RecID     : string;
  AuditID   : Variant;
begin
  AuditID   := DoGenID('SYS_AUDIT_LOG');
  TableName := (ADataSet as TRadQuery)._TableName;
  RecID     := ADataSet.FieldByName((ADataSet as TRadQuery).KeyFields).AsString;

  LSnapshot := DocDict();
  for i := 0 to ADataSet.FieldCount - 1 do
  begin
    LField := ADataSet.Fields[i];
    if (AOperation = 'UPDATE') and (FSetting.Audit = auChange) then
    begin
      if LField._IsChange and not (LField.FieldKind in [fkCalculated, fkLookup]) then
        LSnapshot.SetDefault(LField.FieldName, _ArrFast([LField.OldValue, LField.Value]));
    end
    else
      LSnapshot.SetDefault(LField.FieldName, LField.Value);
  end;

  Result :=
    'INSERT INTO sys_audit_log (id, tablo_adi, kayit_id, kayiteden, operasyon, snapshot) ' +
    'VALUES (' + QuotedStr(VarToStr(AuditID)) + ', ' +
               QuotedStr(TableName)           + ', ' +
               QuotedStr(RecID)               + ', ' +
               QuotedStr('Sistem')            + ', ' +
               QuotedStr(AOperation)          + ', ' +
               QuotedStr(LSnapshot.Json)      + ')';
end;

{ Query factory & RAII }

function TRadConnection.NewQuery: TRadQuery;
begin
  Result := TRadQuery.Create(nil);
  Result.Connection := Self;
end;

function TRadConnection.NewQuery(const ASQL: string): TRadQuery;
begin
  Result := NewQuery;
  Result.SQL.Text := ASQL;
end;

procedure TRadConnection.WithQuery(AProc: TQueryProc);
var
  q: TRadQuery;
begin
  q := NewQuery;
  try
    AProc(q);
  finally
    q.Free;
  end;
end;

procedure TRadConnection.WithQuery(const ASQL: string; AProc: TQueryProc);
var
  q: TRadQuery;
begin
  q := NewQuery(ASQL);
  try
    AProc(q);
  finally
    q.Free;
  end;
end;

{ Quick exec }

function TRadConnection.Exec(const ASQL: string): Variant;
begin
  Result := ExecSQL(ASQL);
end;

function TRadConnection.Exec(const ASQL: string; const AParams: array of Variant): Variant;
begin
  Result := ExecSQL(ASQL, AParams);
end;

procedure TRadConnection.ExecBatch(const ASQLList: array of string);
begin
  {
  InTransaction(procedure begin
    for var i := 0 to High(ASQLList) do
      ExecSQL(ASQLList[i]);
  end);
  }
end;

procedure TRadConnection.ExecBatch(const ASQLList: array of string;
                                   const AParamsList: array of TArray<Variant>);
begin
  {
  InTransaction(procedure begin
    for var i := 0 to High(ASQLList) do
      if i <= High(AParamsList) then
        ExecSQL(ASQLList[i], AParamsList[i])
      else
        ExecSQL(ASQLList[i]);
  end);
  }
end;

function TRadConnection.ExecAsync(const ASQL: string): TRadTask;
var
  LSQL: string;
begin
  LSQL := ASQL;
  Result := TRadTask.Create(procedure(t: TRadTask) begin
    var conn := CloneConnection;
    try
      conn.Connect;
      try
        conn.ExecSQL(LSQL);
      finally
        conn.Disconnect;
      end;
    finally
      conn.Free;
    end;
  end);
end;

function TRadConnection.ExecAsync(const ASQL: string; const AParams: array of Variant): TRadTask;
var
  LSQL   : string;
  LParams: TArray<Variant>;
begin
  LSQL := ASQL;
  SetLength(LParams, Length(AParams));
  for var i := 0 to High(AParams) do LParams[i] := AParams[i];

  Result := TRadTask.Create(procedure(t: TRadTask) begin
    var conn := CloneConnection;
    try
      conn.Connect;
      try
        conn.ExecSQL(LSQL, LParams);
      finally
        conn.Disconnect;
      end;
    finally
      conn.Free;
    end;
  end);
end;

{ Connection-level scalar — private helper }

procedure BindQ(q: TRadQuery; const AParams: array of Variant);
begin
  for var i := 0 to High(AParams) do
    q.Params[i].Value := AParams[i];
end;

{ Parametreli overload'lar }

function TRadConnection.QueryInt(const ASQL: string; const AParams: array of Variant; ADefault: Integer): Integer;
var q: TRadQuery;
begin
  q := NewQuery(ASQL);
  try
    BindQ(q, AParams); q.Open;
    Result := IfThen(q.IsEmpty, ADefault, q.Fields[0].AsInteger);
  finally q.Free; end;
end;

function TRadConnection.QueryInt64(const ASQL: string; const AParams: array of Variant; ADefault: Int64): Int64;
var q: TRadQuery;
begin
  q := NewQuery(ASQL);
  try
    BindQ(q, AParams); q.Open;
    Result := IfThen(q.IsEmpty, ADefault, q.Fields[0].AsLargeInt);
  finally q.Free; end;
end;

function TRadConnection.QueryStr(const ASQL: string; const AParams: array of Variant; const ADefault: string): string;
var q: TRadQuery;
begin
  q := NewQuery(ASQL);
  try
    BindQ(q, AParams); q.Open;
    if q.IsEmpty then Result := ADefault else Result := q.Fields[0].AsString;
  finally q.Free; end;
end;

function TRadConnection.QueryFloat(const ASQL: string; const AParams: array of Variant; ADefault: Double): Double;
var q: TRadQuery;
begin
  q := NewQuery(ASQL);
  try
    BindQ(q, AParams); q.Open;
    Result := IfThen(q.IsEmpty, ADefault, q.Fields[0].AsFloat);
  finally q.Free; end;
end;

function TRadConnection.QueryBool(const ASQL: string; const AParams: array of Variant; ADefault: Boolean): Boolean;
var q: TRadQuery;
begin
  q := NewQuery(ASQL);
  try
    BindQ(q, AParams); q.Open;
    if q.IsEmpty then Result := ADefault else Result := q.Fields[0].AsBoolean;
  finally q.Free; end;
end;

function TRadConnection.QueryVar(const ASQL: string; const AParams: array of Variant): Variant;
var q: TRadQuery;
begin
  q := NewQuery(ASQL);
  try
    BindQ(q, AParams); q.Open;
    if q.IsEmpty then Result := Null else Result := q.Fields[0].Value;
  finally q.Free; end;
end;

function TRadConnection.QueryExists(const ASQL: string; const AParams: array of Variant): Boolean;
var q: TRadQuery;
begin
  q := NewQuery(ASQL);
  try
    BindQ(q, AParams); q.Open;
    Result := not q.IsEmpty;
  finally q.Free; end;
end;

{ Parametresiz overload'lar }

function TRadConnection.QueryInt   (const ASQL: string; ADefault: Integer): Integer;  begin Result := QueryInt   (ASQL, [], ADefault); end;
function TRadConnection.QueryInt64 (const ASQL: string; ADefault: Int64): Int64;      begin Result := QueryInt64 (ASQL, [], ADefault); end;
function TRadConnection.QueryStr   (const ASQL: string; const ADefault: string): string; begin Result := QueryStr(ASQL, [], ADefault); end;
function TRadConnection.QueryFloat (const ASQL: string; ADefault: Double): Double;    begin Result := QueryFloat (ASQL, [], ADefault); end;
function TRadConnection.QueryBool  (const ASQL: string; ADefault: Boolean): Boolean;  begin Result := QueryBool  (ASQL, [], ADefault); end;
function TRadConnection.QueryVar   (const ASQL: string): Variant;                     begin Result := QueryVar   (ASQL, []); end;
function TRadConnection.QueryExists(const ASQL: string): Boolean;                     begin Result := QueryExists(ASQL, []); end;

{ Transaction }

procedure TRadConnection.InTransaction(AProc: TProc);
begin
  StartTransaction;
  try
    AProc();
    Commit;
  except
    Rollback;
    raise;
  end;
end;

function TRadConnection.InTransaction(AFunc: TFunc<Boolean>): Boolean;
begin
  StartTransaction;
  try
    Result := AFunc();
    if Result then Commit else Rollback;
  except
    Rollback;
    raise;
  end;
end;

procedure TRadConnection.WithSavepoint(const AName: string; AProc: TProc);
begin
  Savepoint(AName);
  try
    AProc();
    ReleaseSavepoint(AName);
  except
    RollbackToSavepoint(AName);
    raise;
  end;
end;

{ ═══════════════════════════════════════════════════════════════════════════════
  TRadQuery
  ═══════════════════════════════════════════════════════════════════════════════}

constructor TRadQuery.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSQLCommands := TList<string>.Create;
  FSetting     := TRadQuerySetting.Create(Self);
  FLastFilter  := Null;
end;

destructor TRadQuery.Destroy;
begin
  FSQLCommands.Free;
  FSetting.Free;
  FDetailSets.Free;
  inherited Destroy;
end;

function TRadQuery.AsCn: TRadConnection;
begin
  Result := TRadConnection(Connection);
end;

{ ── Internal transaction ─────────────────────────────────────────────────────}

procedure TRadQuery._BeginWork;
begin
  if Assigned(FUnitOfWork) then Exit;

  if Connection.InTransaction then
  begin
    FOwnsTransactionType := 10;
    FSavePointName := 'SP_' + Copy(GuidToString(TGuid.NewGuid), 2, 8);
    Connection.Savepoint(FSavePointName);
  end
  else
  begin
    FOwnsTransactionType := 1;
    FSavePointName := '';
    Connection.StartTransaction;
  end;
end;

procedure TRadQuery._CommitWork;
begin
  if Assigned(FUnitOfWork) then Exit;

  if FOwnsTransactionType = 1 then
    Connection.Commit
  else if FSavePointName <> '' then
    Connection.ReleaseSavepoint(FSavePointName);

  FOwnsTransactionType := 0;
  FSavePointName := '';
end;

procedure TRadQuery._RollbackWork;
begin
  if Assigned(FUnitOfWork) then Exit;

  if FOwnsTransactionType = 1 then
    Connection.Rollback
  else if FSavePointName <> '' then
    Connection.RollbackToSavepoint(FSavePointName);

  FOwnsTransactionType := 0;
  FSavePointName := '';
end;

procedure TRadQuery._ExecuteSQLCommands;
var
  s: string;
begin
  for s in FSQLCommands do
    Connection.ExecSQL(s);
  FSQLCommands.Clear;
end;

procedure TRadQuery._AddWorkAction(const AAction: TRadWorkAction);
begin
  if Assigned(FUnitOfWork) and FUnitOfWork.InCommit then Exit;

  if AsCn.Setting.Audit <> auNone then
    FSQLCommands.Add(AsCn.AuditCapture(Self, TRadUnitOfWork.ActionToStr(AAction)));

  if Assigned(FUnitOfWork) then
    FUnitOfWork.RegisterDataSet(Self, AAction);
end;

function TRadQuery._Transaction: TUniTransaction;
begin
  if (State = dsEdit) and Assigned(UpdateTransaction) then
    Result := UpdateTransaction
  else if Assigned(Transaction) then
    Result := Transaction
  else if Assigned(Connection) then
    Result := (Connection as TUniConnection).DefaultTransaction
  else
    Result := nil;
end;

{ ── ID ───────────────────────────────────────────────────────────────────────}

function TRadQuery._GenID(const AScopeName: string): Variant;
var
  Scope: string;
begin
  Scope := IfThen(AScopeName.IsEmpty, _TableName, AScopeName);
  Assert(not Scope.IsEmpty, Name + ' — kapsam adı verilmemiş');
  Result := AsCn.DoGenID(Scope);
end;

function TRadQuery._LastInsertId: Largeint;
begin
  Result := 0;
  if KeyFields.IsEmpty or (FindField(KeyFields) = nil) then Exit;
  Result := FieldByName(KeyFields).AsLargeInt;
end;

{ ── Detail setler ────────────────────────────────────────────────────────────}

function TRadQuery._DetailSets: TList<TDataSet>;
begin
  if not Assigned(FDetailSets) then
  begin
    FDetailSets := TList<TDataSet>.Create;
    GetDetailDataSets(FDetailSets);
  end;
  Result := FDetailSets;
end;

procedure TRadQuery._DetailsOpen;
begin
  if rcDetailsOpen in FSetting.Commands then
    for var i := 0 to _DetailSets.Count - 1 do
      (_DetailSets[i] as TRadQuery).Open;
end;

procedure TRadQuery._DetailsPost;
begin
  if rcDetailsPost in FSetting.Commands then
    for var i := 0 to _DetailSets.Count - 1 do
      (_DetailSets[i] as TRadQuery)._Post;
end;

{ ── Event dispatcher ─────────────────────────────────────────────────────────}

procedure TRadQuery.DoEvent(const AEvent: TRadDSEventKind);
var
  Itm : TRadAutoValueItem;
  HItm: TRadEventHandlerItem;
  fld : TField;
  vr  : Variant;
begin
  FLastEvent := AEvent;
  if not Active then Exit;

  if Assigned(AsCn.GlobalEvent) then
    AsCn.GlobalEvent(AEvent, Self, []);

  for Itm in FSetting.AutoValues do
    if Itm.Enabled and (AEvent in Itm.Events) then
    begin
      if Itm.Command.IsEmpty then
        _Value(Itm.FieldName, Itm.Value)
      else if Assigned(AsCn.CmdExecutor) then
      begin
        fld := _F(Itm.FieldName);
        vr  := AsCn.CmdExecutor(Itm.Command, Self, [TValue.From<TField>(fld)]);
        if vr <> Unassigned then
          fld.Value := vr;
      end;
    end;

  for HItm in FSetting.EventHandlers do
    if HItm.Enabled and (AEvent in HItm.Handler.Events) and Assigned(HItm.Handler.OnEvent) then
      HItm.Handler.OnEvent(AEvent, Self, []);
end;

{ ── TDataSet override'ları ───────────────────────────────────────────────────}

procedure TRadQuery.DoAfterDelete;  begin inherited DoAfterDelete;  DoEvent(evAfterDelete);  end;
procedure TRadQuery.DoAfterInsert;  begin _DetailsOpen; DoEvent(evAfterInsert); inherited DoAfterInsert; end;
procedure TRadQuery.DoAfterOpen;    begin _DetailsOpen; DoEvent(evAfterOpen);   inherited DoAfterOpen;   end;
procedure TRadQuery.DoAfterPost;    begin _DetailsPost; DoEvent(evAfterPost);   inherited DoAfterPost;   end;
procedure TRadQuery.DoAfterScroll;  begin _DetailsOpen; inherited DoAfterScroll; end;

procedure TRadQuery.DoAfterEdit;
begin
  if (rcMasterEdit in FSetting.Commands) and (MasterSource <> nil) then
    MasterSource.DataSet._Edit;
  DoEvent(evAfterEdit);
  inherited DoAfterEdit;
end;

procedure TRadQuery.DoBeforeDelete;
begin
  DoEvent(evBeforeDelete);
  inherited DoBeforeDelete;
  _AddWorkAction(waDelete);
end;

procedure TRadQuery.DoBeforeEdit;
begin
  DoEvent(evBeforeEdit);
  inherited DoBeforeEdit;
end;

procedure TRadQuery.DoBeforeInsert;
begin
  DoEvent(evBeforeInsert);
  inherited DoBeforeInsert;
end;

procedure TRadQuery.DoBeforeOpen;
begin
  if Assigned(Connection) and Assigned(AsCn.GlobalEvent) then
    AsCn.GlobalEvent(evBeforeOpen, Self, []);
  inherited DoBeforeOpen;
end;

procedure TRadQuery.DoBeforePost;
begin
  if (State = dsInsert)
    and (rcMasterInsertID in FSetting.Commands)
    and Assigned(MasterSource)
    and not MasterFields.IsEmpty
    and not DetailFields.IsEmpty
  then
    _V[DetailFields] := MasterSource.DataSet._V[MasterFields];

  DoEvent(evBeforePost);
  inherited DoBeforePost;

  if State = dsInsert then
    _AddWorkAction(waInsert)
  else if State = dsEdit then
    _AddWorkAction(waUpdate);
end;

procedure TRadQuery.Loaded;
begin
  inherited Loaded;
end;

procedure TRadQuery.ApplyUpdates;
begin
  if Assigned(FUnitOfWork) then
  begin
    inherited ApplyUpdates;
    Exit;
  end;

  _BeginWork;
  try
    inherited ApplyUpdates;
    _ExecuteSQLCommands;
    _CommitWork;
    CommitUpdates;
  except
    _RollbackWork;
    RestoreUpdates;
    FSQLCommands.Clear;
    raise;
  end;
end;

procedure TRadQuery.Post;
begin
  if Assigned(FUnitOfWork) or CachedUpdates then
  begin
    inherited Post;
    Exit;
  end;

  _BeginWork;
  try
    inherited Post;
    _ExecuteSQLCommands;
    _CommitWork;
  except
    _RollbackWork;
    FSQLCommands.Clear;
    raise;
  end;
end;

procedure TRadQuery.InternalDelete;
begin
  if Assigned(FUnitOfWork) or CachedUpdates then
  begin
    inherited InternalDelete;
    Exit;
  end;

  _BeginWork;
  try
    inherited InternalDelete;
    _ExecuteSQLCommands;
    _CommitWork;
  except
    _RollbackWork;
    FSQLCommands.Clear;
    raise;
  end;
end;

{ ── Fluent kurulum ───────────────────────────────────────────────────────────}

function TRadQuery.Text(const ASQL: string): TRadQuery;
begin
  SQL.Text := ASQL;
  Result   := Self;
end;

function TRadQuery.Param(const AName: string; const AValue: Variant): TRadQuery;
begin
  ParamByName(AName).Value := AValue;
  Result := Self;
end;

function TRadQuery.ParamNull(const AName: string; AType: TFieldType): TRadQuery;
begin
  with ParamByName(AName) do
  begin
    DataType := AType;
    Clear;
  end;
  Result := Self;
end;

function TRadQuery.BindDoc(const ADoc: TDocVariantData): TRadQuery;
var
  i   : Integer;
  name: RawUtf8;
  p   : TParam;
begin
  for i := 0 to ADoc.Count - 1 do
  begin
    name := ADoc.Names[i];
    p    := ParamByName(Utf8ToString(name));
    if Assigned(p) then
      p.Value := ADoc.Values[i];
  end;
  Result := Self;
end;

function TRadQuery.CachedMode(AEnabled: Boolean): TRadQuery;
begin
  CachedUpdates := AEnabled;
  DMLRefresh    := AEnabled;
  Result := Self;
end;

{ ── Filtre ───────────────────────────────────────────────────────────────────}

function VarIsSame(const A, B: Variant): Boolean;
begin
  if TVarData(A).VType <> TVarData(B).VType then
    Result := False
  else
    Result := A = B;
end;

procedure TRadQuery.FiltreApply(const AValue: Variant);
var
  Itm    : TRadFilterItem;
  s, tmp : string;
begin
  if VarIsNull(AValue) or VarToStr(AValue).IsEmpty then
  begin
    FiltreClear;
    Exit;
  end;

  if VarIsSame(AValue, FLastFilter) then Exit;
  FLastFilter := AValue;

  s := '';
  for Itm in FSetting.Filters do
    if Itm.Enable then
    begin
      if Itm.FieldType = TFieldType.ftUnknown then
        Itm.FieldType := FieldByName(Itm.Filter1).DataType;

      tmp := RadFilterToSQL(Itm.FieldType, Itm.Operation, Itm.ResolvedField, AValue, Null);
      if not tmp.IsEmpty then
      begin
        if not s.IsEmpty then
          s := s + RadFilterTypeConst[Integer(Itm.FilterType) + 1];
        s := s + tmp;
      end;
    end;

  if s.IsEmpty then
    Filtered := False
  else
  begin
    FilterSQL := s;
    Filtered  := True;
  end;
end;

procedure TRadQuery.FiltreClear;
begin
  FilterSQL   := '';
  Filtered    := False;
  FLastFilter := Null;
end;

{ ── Iterasyon & çıktı ────────────────────────────────────────────────────────}

procedure TRadQuery.Each(AProc: TProc);
begin
  DisableControls;
  try
    First;
    while not Eof do
    begin
      AProc();
      Next;
    end;
  finally
    EnableControls;
  end;
end;

function TRadQuery.ToDocList: IDocList;
var
  list: IDocList;
begin
  list := DocList;
  DisableControls;
  try
    First;
    while not Eof do
    begin
      var dict := DocDict;
      for var i := 0 to Fields.Count - 1 do
        dict.S[StringToUtf8(Fields[i].FieldName)] := StringToUtf8(Fields[i].AsString);
      list.Append(dict.AsVariant);
      Next;
    end;
  finally
    EnableControls;
  end;
  Result := list;
end;

procedure TRadQuery._ToList(const ALst: TStrings; const AFields: TArray<string>;
                            const AFormat: string);
var
  cnt: Integer;
  fmt: Boolean;
begin
  cnt := Length(AFields);
  fmt := not AFormat.IsEmpty;
  ALst.BeginUpdate;
  ALst.Clear;
  try
    _DoEof(procedure begin
      case cnt of
        0: ALst.Add(Fields[0].AsString);
        1: if fmt then ALst.Add(Format(AFormat, [_S[AFields[0]]]))
           else ALst.Add(_S[AFields[0]]);
      end;
    end);
  finally
    ALst.EndUpdate;
  end;
end;

{ ── Scalar — terminal ────────────────────────────────────────────────────────}

function TRadQuery.ScalarInt(ADefault: Integer): Integer;
begin
  Open;
  try
    if IsEmpty then Result := ADefault else Result := Fields[0].AsInteger;
  finally
    Close; Free;
  end;
end;

function TRadQuery.ScalarInt64(ADefault: Int64): Int64;
begin
  Open;
  try
    if IsEmpty then Result := ADefault else Result := Fields[0].AsLargeInt;
  finally
    Close; Free;
  end;
end;

function TRadQuery.ScalarStr(const ADefault: string): string;
begin
  Open;
  try
    if IsEmpty then Result := ADefault else Result := Fields[0].AsString;
  finally
    Close; Free;
  end;
end;

function TRadQuery.ScalarFloat(ADefault: Double): Double;
begin
  Open;
  try
    if IsEmpty then Result := ADefault else Result := Fields[0].AsFloat;
  finally
    Close; Free;
  end;
end;

function TRadQuery.ScalarBool(ADefault: Boolean): Boolean;
begin
  Open;
  try
    if IsEmpty then Result := ADefault else Result := Fields[0].AsBoolean;
  finally
    Close; Free;
  end;
end;

function TRadQuery.ScalarVar: Variant;
begin
  Open;
  try
    if IsEmpty then Result := Null else Result := Fields[0].Value;
  finally
    Close; Free;
  end;
end;

{ ── Open / Exec ─────────────────────────────────────────────────────────────}

function TRadQuery.OpenSelf: TRadQuery;
begin
  Open;
  Result := Self;
end;

function TRadQuery.OpenAsync: TRadTask;
var
  LCn  : TRadConnection;
  LSQL : string;
  LQry : TRadQuery;
begin
  LCn  := AsCn;
  LSQL := SQL.Text;
  LQry := Self;

  Result := TRadTask.Create(procedure(t: TRadTask) begin
    var conn := LCn.CloneConnection;
    try
      conn.Connect;
      LQry.Connection := conn;
      LQry.Open;
    except
      conn.Free;
      raise;
    end;
  end);
end;

function TRadQuery.ExecAsync: TRadTask;
var
  LCn  : TRadConnection;
  LSQL : string;
begin
  LCn  := AsCn;
  LSQL := SQL.Text;

  Result := TRadTask.Create(procedure(t: TRadTask) begin
    var conn := LCn.CloneConnection;
    try
      conn.Connect;
      try
        conn.ExecSQL(LSQL);
      finally
        conn.Disconnect;
        conn.Free;
      end;
    except
      conn.Free;
      raise;
    end;
  end);
end;

end.
