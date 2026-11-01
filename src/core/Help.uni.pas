unit Help.uni;

interface

uses System.Classes, System.SysUtils, System.Generics.Collections, Data.DB,System.JSON, Uni, MemDS, VirtualTable,
SqlTimSt,Help.DB,System.Rtti,DBAccess
,rad.core,rad.thread   // TRadTask - _ConnectTestAsync imzasinda gectigi icin ARAYUZDE
              // olmali. Dongu riski yok: rad.thread yalnizca System/Winapi/
              // mormot birimlerine bagli, hicbir Help.* birimini bilmiyor.
,DASQLGenerator,CRAccess,SqlClassesUni
,DAScript, UniScript,Variants
,rad.sqlfilter
,rad.customfield
,rad.script

  {$IFDEF MSWINDOWS}
   ,UniDacVcl
  {$ELSEIF ANDROID}
  {$ELSEIF IOS}
  {$ELSEIF MACOS}
  {$ENDIF}

;



type
  //TFieldsHelpers = type Help.DB.TFieldsHelper;
  //TSQLTimeStampHelps= type TSQLTimeStampHelp;
  //TDataSetHelpers= type TDataSetHelper;



  TBooleanFieldType = (bfUnknown, bfBoolean, bfInteger);
  TDataSetFieldType = (dfUnknown, dfJSONObject, dfJSONArray);
  TOnParamsProc = reference to Procedure(Prm: TUniParams);


  TUniMacroHelper = class helper for TUniMacros
     function _Add(const AMacroName:string; const AValue:string):TUniMacros;
     function _AddStr(const AMacroName:string; const AValue:string):TUniMacros;
  end;

{$REGION 'Uni Connection'}

  TUniConnectionHelper = class helper for TUniConnection //TCustomDAConnection
  strict private

   //function _AsUni:TUniConnection;
   //function _AsDAConnection:TCustomDAConnection;
  public
    //function _DBType:TSqlDBDefinition;
        { Fluent config }
    function _SetProvider (const AValue: string): TUniConnection;
    function _SetServer   (const AValue: string): TUniConnection;
    function _SetDatabase (const AValue: string): TUniConnection;
    function _SetUsername (const AValue: string): TUniConnection;
    function _SetPassword (const AValue: string): TUniConnection;
    function _SetPort  (AValue: Integer): TUniConnection;
    function _SetPool     (AMin: Integer = 1; AMax: Integer = 10): TUniConnection;


    function _Script:TUniScript;
    function _NewConnection:TUniConnection;
    procedure _Thread(AProc:TProc<TUniConnection>);
    //procedure _CreateQuery(const sql:string; const AProc:TProc<TDataSet>); overload;
    function _CreateQuery: TUniQuery; overload;
    function _CreateQuery(const sql:string;IsOpen:Boolean = true): TUniQuery; overload;
    function _CreateQuery(const sql:string;IsOpen:Boolean; const AParams: array of Variant): TUniQuery; overload;

    Procedure _DoEof(SQL: string; AProc:TProc<TDataset>; var Aiptal:Boolean;const ASavePosition: Boolean = False); overload;
    Procedure _DoEof(SQL: string; AProc:TProc<TDataset>); overload;
    function _DoOpen(SQL: string; AProc:TProc<TDataset>):Boolean;

    function  _sqlResults(const sql:string; const DefValue:Variant; const sFieldName:string=''):Variant; overload;
    procedure _sqlResultsList(const ASql:string; AList:TStrings; AFunc:TFunc<TDataSet,string>=nil);
    //function _sqlResults<T>(const sql:string; const DefValue:T; const sFieldName:string=''):TValue;  overload;
    //function _sqlResults.TryAsType<T>(out AResult: T): Boolean;
    function _sqlCount(const ATableName:string;const AWhere:string=''):Integer;


    function _StoredProc(Const ProcName:String; const ParamValue: array of variant; const ReturnField:string):Variant; overload;

    function _StoredProc(Const ProcName:String; OnProc: TOnParamsProc = nil):Boolean; overload;
    function _StoredProc(Const ProcName:String;ParamValue: array of variant; OnProc: TOnParamsProc = nil):Boolean; overload;
    function _StoredProc(Const ProcName:String;ParamName: array of string;
      ParamValue: array of variant; OnProc: TOnParamsProc = nil):Boolean; overload;
    //procedure sql_eof(const sql:string; proc:TAksaDataSetEof);

    //Functionlar


    //procedure _ExecScript(const AScript:string; const ANoPreconnet:Boolean=false);


    function _ServerDate:TDateTime;

    function _ExitsDb(const ADbName:string):Boolean;
    function _ExitsTable(const ATableName:string):Boolean;


    function _ConnectTest(const AConnectionString:string=''):TResult<Boolean>;

    /// <summary>
    ///   Baglantiyi ARKA PLANDA dener. Cagiran ANINDA doner; UI hicbir an
    ///   bloke olmaz. BASLATILMAMIS bir TRadTask dondurur - cagiran zincirler
    ///   ve Start der (repo kurali; bkz. TRadConnection.ExecAsync).
    /// </summary>
    /// <remarks>
    ///   Sonuc kanali:
    ///     OnSuccess -> baglanti kuruldu
    ///     OnError   -> kurulamadi; SEBEBI t.ErrorMsg'dedir
    ///   Iki geri cagirim da ANA THREAD'de calisir (TRadTask.FireCallback
    ///   Synchronize/ForceQueue ile marshall eder), dolayisiyla iclerinde
    ///   dogrudan VCL'e dokunmak guvenlidir.
    ///
    ///   _ConnectTest'ten FARKI: o, Wait ile cagirani bloke eder (mesaj
    ///   pompalayarak). Pompalamak formu "canli" gosterir ama YENIDEN GIRISE
    ///   acar - kullanici ayni dugmeye tekrar basabilir, formu kapatabilir.
    ///   Bu surumde oyle bir pencere yoktur.
    ///
    ///   ZAMAN ASIMI ICIN WithTimeout KULLANMAYIN. TRadTask'in zaman asimi
    ///   ISBIRLIKCIDIR - yalnizca checkpoint'lerde bakilir ve bloke olmus bir
    ///   Connect cagrisini KESEMEZ. Dogru yer saglayicinin kendi secenegidir:
    ///     cn.SpecificOptions.Values['ConnectionTimeout'] := '10';
    ///   (PostgreSQLUniProvider.pas:110 - varsayilan 15 saniye.)
    /// </remarks>
    /// <example>
    ///   <code>
    ///   DM.cn._ConnectTestAsync
    ///     .OnSuccess(procedure(t: TRadTask)
    ///       begin
    ///         ModalResult := mrOk;      // Close CAGIRMAYIN: modal formda
    ///       end)                        // Close, ModalResult'i mrCancel yapar
    ///     .OnError(procedure(t: TRadTask)
    ///       begin
    ///         ShowMessage(t.ErrorMsg);
    ///       end)
    ///     .OnFinally(procedure(t: TRadTask)
    ///       begin
    ///         btnOk.Enabled := True;
    ///       end)
    ///     .Start;
    ///   </code>
    /// </example>
    function _ConnectTestAsync(const AConnectionString:string=''):TRadTask;

    /// <summary>ProviderName → TRadSqlDialect. Tanınmayan sağlayıcıda ERadSqlFilter.</summary>
    function _SqlDialect: TRadSqlDialect;
    /// <summary>Bu bağlantının lehçesiyle yeni IRadSqlFilter.</summary>
    function _NewFilter(AMode: TRadFilterMode = rfmSkipEmpty): IRadSqlFilter;
    /// <summary>Bu bağlantı üstünde özel alan tanım deposu (TRadUniCustomFieldStore).</summary>
    function _CustomFields: IRadCustomFieldStore;
    /// <summary>Bu bağlantı üstünde script paket deposu (TRadUniScriptStore).</summary>
    function _Scripts: IRadScriptStore;
    /// <summary>Aktif özel alan kolonları: ', a.ozel_1, a.ozel_2' (baş virgüllü); yoksa ''.
    /// Açık kolon listeli sorguda &amp;makro yerine gider.</summary>
    function _CustomFieldColumns(const ATable: string; const AAlias: string = ''): string;


   {$IFDEF MSWINDOWS}
    //function _CreateDB(const ADBName:string; const AFolder:string='' ):Boolean;
    //procedure _BackUp( ASaveFile:string=''; ADataBase:string='';const AProc:TProc=nil);
    //procedure _Restore(const ABackupFile:string; ADataBase:string=''; const AProc:TProc=nil);
  {$ELSEIF ANDROID}
  {$ELSEIF IOS}
  {$ELSEIF MACOS}
  {$ENDIF}

  end;




{$ENDREGION}


{$REGION 'TCustomDADataSet'}

 TCustomDADataSetHack= Class(TCustomDADataSet)

   //function SQLGetFrom(const SQLText: string): string;
 End;


  TDADataSetyHelper = class helper for TCustomDADataSet
  private

   public

     function _Transaction:TUniTransaction;
     function _AsUni:TUniConnection;

     function _UpdateStatus(AProc:TProc<TDataSet>; const AUpdateStatus:TUpdateStatusSet=[usModified,usInserted,usDeleted]):TCustomDADataSet;
     function _OpenSQL(const ASQL:string):TCustomDADataSet;
     function _ReOpen:TCustomDADataSet;overload;
     function _ReOpen(const V:Variant):TCustomDADataSet;overload;
     function _ReOpen(const arg:array of variant):TCustomDADataSet;overload;
     //function _ReOpenMaster:TCustomDADataSet;

     function _GetFastID(const AGetID:Byte=2):Variant;
     //procedure _FastFiltre(const AValue:TValue;const AField:TArray<string>);

     function _Macro(const AMacroName,Avalue:string):TCustomDADataSet;
     /// <summary>Filtrenin parametre değerlerini yazar; SQL metni (GetWhere/GetSql) önce atanmış olmalı.</summary>
     function _ApplyFilter(const AFilter: IRadSqlFilter): TCustomDADataSet;
     /// <summary>SQL'deki &amp;AMacro yerine tablonun özel alan kolonlarını yazar
     /// ('select c.id, c.kod &amp;ozel from cari c'). Makro yoksa UniDAC hata verir.</summary>
     function _ApplyCustomFieldMacro(const AMacro, ATable: string; const AAlias: string = ''): TCustomDADataSet;
     /// <summary>Persistent TField'lı KAPALI dataset'te eksik ozel_* alanları için TField yaratır.
     /// Persistent alan yoksa işlemsiz. Açık dataset'te ERadCustomField.</summary>
     function _EnsureCustomFields: TCustomDADataSet;

     function _DataService:TDADataSetService;

     function _SQLGenerate(const Index: Integer):string;

     function _SQLGetFrom: string;
     function _FieldAlias(const AFieldName:string):string;
     function _TableName:string;
     procedure _KeyFieldNames(const AProc:TProc<TStrings>);

     function _SQLInfo:TSQLInfo;
     procedure _Cols( const AProc:TProc<TCRColumnInfo>);

     function Hack:TCustomDADataSetHack;

     procedure _GenerateSQLALL;

     property _GenerateSQLQuery   :string  index 0 read _SQLGenerate;
     property _GenerateSQLInsert  :string  index 1 read _SQLGenerate;
     property _GenerateSQLUpdate  :string  index 2 read _SQLGenerate;
     property _GenerateSQLDelete  :string  index 3 read _SQLGenerate;
     property _GenerateSQLLock    :string  index 4 read _SQLGenerate;
     property _GenerateSQLRefresh :string  index 5 read _SQLGenerate;




  end;

{$ENDREGION}

{$REGION 'Custom fields'}

  /// <summary>IRadCustomFieldStore'un UniDAC uygulaması. Tanım tabloları: ozel_alan_grup,
  /// ozel_alan, ozel_alan_duzen (rad.customfield.TRadCustomFieldDdl). Bağlantıya sahip değildir.</summary>
  /// <summary>Tanım deposu tabanı: sorgu/DDL yardımcıları ve lehçeye göre transaction.</summary>
  TRadUniStoreBase = class(TInterfacedObject)
  protected
    FCon: TUniConnection;
    FDialect: TRadSqlDialect;
    FTx: TUniTransaction;   // yalnız Firebird: DDL + insert için ayrı transaction (bkz. InTransaction)
    function Q(const ASql: string): TUniQuery;
    procedure Exec(const ASql: string);
    function CountOf(const ASql: string; const ANames: array of string; const AValues: array of Variant): Integer;
    function TableExists(const ATable: string): Boolean;
    function ColumnExists(const ATable, AColumn: string): Boolean;
    procedure InTransaction(AProc: TProc);
    /// <summary>Uzun metin alanı; Firebird blob metnini UTF-8 olarak çözer.</summary>
    function MemoText(AField: TField): string;
  public
    constructor Create(ACon: TUniConnection);
    function Dialect: TRadSqlDialect;
  end;

  TRadUniCustomFieldStore = class(TRadUniStoreBase, IRadCustomFieldStore)
  private
    function ExistingColumnNames(const ATable: string): TArray<string>;
    procedure ReadGroup(AQ: TUniQuery; AGroup: TRadCustomFieldGroupDef);
    procedure ReadField(AQ: TUniQuery; ADef: TRadCustomFieldDef);
    procedure WriteFieldParams(AQ: TUniQuery; ADef: TRadCustomFieldDef);
  public
    class function New(ACon: TUniConnection): IRadCustomFieldStore;
    procedure EnsureDefinitionTables;
    function LoadGroups(const ATable: string; AIncludeInactive: Boolean = False): TRadCustomFieldGroups;
    procedure AddGroup(AGroup: TRadCustomFieldGroupDef);
    procedure UpdateGroup(AGroup: TRadCustomFieldGroupDef);
    procedure AddField(ADef: TRadCustomFieldDef);
    procedure UpdateField(ADef: TRadCustomFieldDef);
    procedure ExtendLength(ADef: TRadCustomFieldDef; ANewLength: Integer);
    function ColumnNames(const ATable: string): TArray<string>;
    function LoadLayout(const ATable: string; AUserId: Integer; AStream: TStream): Boolean;
    procedure SaveLayout(const ATable: string; AUserId: Integer; AStream: TStream);
    procedure DeleteLayout(const ATable: string; AUserId: Integer);
  end;

  /// <summary>IRadScriptStore'un UniDAC uygulaması. Tablolar: script_paket, script, script_parametre,
  /// script_db, script_kaynak (rad.script.TRadScriptDdl). Bağlantıya sahip değildir.</summary>
  TRadUniScriptStore = class(TRadUniStoreBase, IRadScriptStore)
  private
    procedure ReadPackage(AQ: TUniQuery; APkg: TRadScriptPackage);
    procedure ReadScript(AQ: TUniQuery; AScript: TRadScript);
    procedure LoadChildren(APkg: TRadScriptPackage);
    function FindPackageId(const ACode: string): Integer;
    function FetchChildId(const ATable, AKeyCol: string; APackageId: Integer; const AKey: Variant): Integer;
    function ExistingChildIds(const ATable, AKeyCol: string; APackageId: Integer): TDictionary<string, Integer>;
    procedure DeleteRemaining(const ATable: string; AIds: TDictionary<string, Integer>);
    procedure WritePackageRow(APkg: TRadScriptPackage);
    procedure SyncScripts(APkg: TRadScriptPackage);
    procedure SyncParams(APkg: TRadScriptPackage);
    procedure SyncDbSteps(APkg: TRadScriptPackage);
    procedure SyncResources(APkg: TRadScriptPackage);
  public
    class function New(ACon: TUniConnection): IRadScriptStore;
    procedure EnsureDefinitionTables;
    function LoadPackages(AIncludeInactive: Boolean): TRadScriptPackages;
    function LoadPackage(const ACode: string): TRadScriptPackage;
    procedure SavePackage(APkg: TRadScriptPackage);
    procedure ImportPackage(APkg: TRadScriptPackage);
    procedure DeletePackage(const ACode: string);
    function ScriptsFor(AKind: TRadScriptKind; const ATarget: string): TRadScripts;
    procedure ApplyPendingDbSteps(APkg: TRadScriptPackage);
    function LoadResource(APackageId: Integer; const AFileName: string; AStream: TStream): Boolean;
    function ResourcesNamed(const AFileName: string): TObjectList<TRadScriptResource>;
    function LibrariesOf(const APackageIds: TArray<Integer>): TRadScripts;
    function ParamsOf(const APackageIds: TArray<Integer>): TObjectList<TRadScriptParam>;
  end;

{$ENDREGION}

{$REGION 'Virtual Table'}

  TVirtualTableHelper = class helper for TVirtualTable
  public
  end;
{$ENDREGION}


 {$REGION 'TUniScript'}
   TUniScriptHelp = class helper for TUniScript
  public
    function _AutoCommit  (const AValue:Boolean):TUniScript;
    function _Delimiter   (const AValue:string):TUniScript;
    function _NoConnect   (const AValue:Boolean):TUniScript;
    function _ScanParams  (const AValue:Boolean):TUniScript;
    function _SQL         (const AValue:string):TUniScript;
    function _Execute     :TUniScript;
   end;
 {$ENDREGION}

 {
 const
  UNIDAC_PROVIDER: array[TSqlDBDefinition.dOracle..high(TSqlDBDefinition)] of string = (
    'Oracle', 'SQL Server', 'Access', 'MySQL', 'SQLite', 'InterBase',
    'NexusDB', 'PostgreSQL', 'DB2', '', 'MySQL');
 }
implementation
  uses
  { rad.thread BURADAN KALDIRILDI - artik ARAYUZ uses'inda (bkz. birim basi).
    Ayni birimi iki uses cumlesinde birden bildirmek E2004 'Identifier
    redeclared' verir. }
  System.StrUtils,System.DateUtils,System.NetEncoding,System.TypInfo,System.Character

  //,Help.SQL.MSSQL

  {$IFDEF MSWINDOWS}
   ,Vcl.Dialogs
  {$ELSEIF ANDROID}
  {$ELSEIF IOS}
  {$ELSEIF MACOS}
  {$ENDIF}

  ;




function SQLGenerate(const ASql: TUniQuery; const AType: Byte): string;
begin
  TDBAccessUtils.SQLGenerator(ASql).GenerateSQL(TDBAccessUtils.GetUpdater(ASql).ParamsInfo, _stUpdate, true);
end;


{ TUniConnectionHelper }

  {$REGION'TUniConnection'}

function Test(const AConnectionString:string=''):Boolean;
    Var
      cn: TUniConnection;
    Begin
      Result:=false;
      cn := TUniConnection.Create(Nil);
      try

        cn.ConnectString := AConnectionString;
        Try
          cn.PerformConnect(False);
          Result := cn.Connected;
        Except
        End;

      finally
        //cn.Disconnect;
        cn.Free;
      end;

    End;

Function TUniConnectionHelper._ConnectTest(const AConnectionString:string=''): TResult<Boolean>;
var
 rs       : TResult<Boolean>;
Begin
 rs.SetFailure('Baglanti denemesi tamamlanmadi.');

 {$IFDEF MSWINDOWS}
   _ConnectTestAsync(AConnectionString)
   .OnError  (procedure (t:TRadTask) begin rs.SetFailure(t.ErrorMsg) end)
  .OnSuccess(procedure (t:TRadTask) begin rs.SetSuccess(True) end)
  .Wait;
 {$ELSE}
  if Test(LConnStr) then
    rs.SetSuccess(True)
  else
    rs.SetFailure('Baglanti kurulamadi.');
 {$ENDIF}

 Result := rs;

End;


function TUniConnectionHelper._ConnectTestAsync(const AConnectionString: string): TRadTask;
var
  LConnStr: string;
begin
  { ANLIK KOPYA - CAGIRAN THREAD'DE alinir, closure'a DEGERLE gecer.

    _ConnectTest'in yaptigi gibi `Self.ConnectString`'i is parcaciginin
    ICINDEN okumak burada calismaz. Orada Wait cagirani bloke ettigi icin iki
    thread hicbir zaman ayni anda calismiyordu; bu surumde cagiran hemen geri
    doner, yani kullanici gorev kosarken Server/Password alanlarini
    degistirebilir. O durumda arka plan, kullanicinin denedigini SANDIGI
    ayarlarla degil, sonradan yazdiklariyla baglanmaya calisirdi.

    ConnectString'in tek tek ozelliklerden derlendigi dogrulandi:
    TCustomDAConnection.GetConnectionString -> FConnectionStringBuilder
    (DBAccess.pas:5821), yani Server/Port/Username/Password/ProviderName/
    Database atandiktan sonra okumak tam dizeyi verir. }
  if AConnectionString.Trim <> '' then
    LConnStr := AConnectionString
  else
    LConnStr := Self.ConnectString;

  Result := TRadTask.Create(
    procedure(t: TRadTask)
    var
      LTemp: TUniConnection;
    begin
      { AYRI baglanti nesnesi. Self'e arka plandan HIC dokunulmaz - denenen
        baglanti basarili olsa bile cagiranin kendi baglantisinin durumu
        degismez; bu bir TEST, bir baglanma degil. }
      LTemp := TUniConnection.Create(nil);
      try
        LTemp.ConnectString := LConnStr;
        LTemp.LoginPrompt   := False;   // arka planda diyalog acilamaz
        LTemp.PerformConnect(False);
        //LTemp.Connect;

        { UniDAC basarisizlikta istisna atar, ama sozlesmeyi sessiz bir
          "Connected=False"a birakmiyoruz: bu da OnError'a gitsin ki cagiran
          tek bir hata yolu gorsun. }
        if not LTemp.Connected then
          raise EDatabaseError.Create('Baglanti kurulamadi (istisna atilmadi).');

        t.SetData('ok', True);
      finally
        if LTemp.Connected then
          LTemp.Disconnect;
        LTemp.Free;
      end;
    end)
    .SetName('UniConnectTest')
    { Saglayici COM tabanli olabilir (OLE DB, ADO koprulu saglayicilar).
      Mevcut _ConnectTest de ayni modeli kullaniyor - tutarli kaliyoruz. }
    .SetCOM(ctmMultiThreaded);

  { BILEREK Start EDILMEZ. Cagiran once OnSuccess/OnError/OnFinally zincirini
    kurar, sonra Start der. Ayrica Start gorevi kendi serbest birakir
    (TRadTask.DoFree), dolayisiyla BASLATILMIS bir gorevi dondurmek sarkan
    isaretci olurdu. Repo genelinde ayni kalip: TRadConnection.ExecAsync. }
end;

function TUniConnectionHelper._SqlDialect: TRadSqlDialect;
begin
  if SameText(ProviderName, 'PostgreSQL') then Result := sdPostgreSQL
  else if SameText(ProviderName, 'SQL Server') then Result := sdMSSQL
  else if SameText(ProviderName, 'MySQL') then Result := sdMySQL
  else if SameText(ProviderName, 'InterBase') then Result := sdFirebird
  else
    raise ERadSqlFilter.CreateFmt('rad.sqlfilter: desteklenmeyen sağlayıcı "%s"', [ProviderName]);
end;

function TUniConnectionHelper._NewFilter(AMode: TRadFilterMode): IRadSqlFilter;
begin
  Result := TRadSqlFilter.New(_SqlDialect, AMode);
end;

function TUniConnectionHelper._CustomFields: IRadCustomFieldStore;
begin
  Result := TRadUniCustomFieldStore.New(Self);
end;

function TUniConnectionHelper._Scripts: IRadScriptStore;
begin
  Result := TRadUniScriptStore.New(Self);
end;

function TUniConnectionHelper._CustomFieldColumns(const ATable, AAlias: string): string;
var
  S, LPrefix: string;
begin
  Result := '';
  if AAlias <> '' then LPrefix := AAlias + '.' else LPrefix := '';
  for S in _CustomFields.ColumnNames(ATable) do
    Result := Result + ', ' + LPrefix + S;
end;

function TUniConnectionHelper._ServerDate: TDateTime;
begin
 {
  case _DBType of
    TSqlDBDefinition.dMSSQL: Result := _sqlResults('SELECT GETDATE() AS dt', Now, 'dt');
    TSqlDBDefinition.dPostgreSQL: Result := _sqlResults('SELECT NOW() AS dt', Now, 'dt');
    TSqlDBDefinition.dSQLite: Result := _sqlResults('SELECT datetime(''now'') AS dt', Now,'dt');
    TSqlDBDefinition.dOracle: Result := _sqlResults('SELECT SYSDATE AS dt FROM DUAL', Now,'dt');
  else
    Result := Now;
  end;
 }
end;



function TUniConnectionHelper._SetDatabase( const AValue: string): TUniConnection;
begin
  inherited Database := AValue;
  Result := Self;
end;

function TUniConnectionHelper._SetPassword( const AValue: string): TUniConnection;
begin
 inherited Password := AValue;
 Result := Self;
end;

function TUniConnectionHelper._SetPool(AMin, AMax: Integer): TUniConnection;
begin
  Pooling                    := True;
  PoolingOptions.MinPoolSize := AMin;
  PoolingOptions.MaxPoolSize := AMax;
  PoolingOptions.Validate    := True;
  Result := Self;
end;

function TUniConnectionHelper._SetPort(AValue: Integer): TUniConnection;
begin
  Port   := AValue;
  Result := Self;
end;

function TUniConnectionHelper._SetProvider( const AValue: string): TUniConnection;
begin
   ProviderName := AValue;
  Result := Self;
end;

function TUniConnectionHelper._SetServer(const AValue: string): TUniConnection;
begin
 inherited Server := AValue;
  Result := Self;
end;

function TUniConnectionHelper._SetUsername( const AValue: string): TUniConnection;
begin
  inherited Username := AValue;
  Result := Self;
end;

function TUniConnectionHelper._CreateQuery: TUniQuery;
begin
  Result := TUniQuery.Create(nil);
  with Result do
  begin
    Connection := self;
  end;
end;



function TUniConnectionHelper._CreateQuery(const sql:string;IsOpen:Boolean; const AParams: array of Variant): TUniQuery;
 var
  i: Integer;
begin
  Result := _CreateQuery;
  Result.SQL.Text:=sql;

  for i := Low(AParams) to High(AParams) do
    Result.Params[i].Value := AParams[i];
 if IsOpen then Result.Open;

end;

function TUniConnectionHelper._CreateQuery(const sql: string; IsOpen: Boolean): TUniQuery;
begin
    result:= _CreateQuery(sql,IsOpen,[]);
end;



 procedure TUniConnectionHelper._DoEof(SQL: string; AProc: TProc<TDataset>; var Aiptal: Boolean;const ASavePosition: Boolean = False);
var
  i: TUniQuery;
begin
  i := _CreateQuery;
  try
    i.SQL.Text := SQL;
    i.Open;

    i._DoEof(AProc,Aiptal,ASavePosition);

  finally
    i.Free;
  end;

end;

 {
function TUniConnectionHelper._DBType:TSqlDBDefinition ;
begin
    for Result := Low(UNIDAC_PROVIDER) to high(UNIDAC_PROVIDER) do
    if SameText(UNIDAC_PROVIDER[Result], ProviderName) then
    begin
      exit;
    end;
  Result := TSqlDBDefinition.dUnknown;

end;
}
procedure TUniConnectionHelper._DoEof(SQL: string; AProc:TProc<TDataset>);
var
  dr:Boolean;
begin
    dr:=false;
    _DoEof(SQL,AProc,dr);
end;




function TUniConnectionHelper._DoOpen(SQL: string; AProc: TProc<TDataset>):Boolean;
var
  i: TUniQuery;
begin
  Result:=False;
  i := _CreateQuery;
  try
    i.SQL.Text := SQL;
    i.Open;
    if i.RecordCount > 0 then
     begin
      Result:=True;
      AProc(i);
     end;
   finally
    i.Free;
  end;


end;



function TUniConnectionHelper._ExitsDb(const ADbName: string): Boolean;
 var
  lst:TStringList;
begin
 //Database:=ADbName;
 lst:=TStringList.Create;
  try
   GetDatabaseNames(lst);
   Result:=lst.IndexOf(ADbName)>-1;
  finally
    lst.Free;
  end;

end;

function TUniConnectionHelper._ExitsTable(const ATableName: string): Boolean;
var
  lst: TStringList;
begin
  lst := TStringList.Create;
  try
    GetTableNames(lst);
    Result := lst.IndexOf(ATableName) > -1;
  finally
    lst.Free;
  end;

end;

function TUniConnectionHelper._sqlResults(const sql: string; const DefValue: Variant; const sFieldName: string): Variant;
var
  qry: TUniQuery;
  fld: TField;
begin
  qry := _CreateQuery;
  try
    Result := DefValue; //varNull;
    qry.SQL.Text := SQL;
    qry.Open;
    if not qry.IsEmpty then
    begin
      if sFieldName <> '' then
        fld := qry.FieldByName(sFieldName)
      else
        fld := qry.Fields[0];
      if not fld.IsNull then
        Result := fld.AsVariant;

    end;
  finally
    qry.Free;
  end;

end;




procedure TUniConnectionHelper._sqlResultsList(const ASql: string; AList: TStrings; AFunc: TFunc<TDataSet, string>);
begin
  AList.BeginUpdate;
  AList.Clear;
  _DoEof(ASql,
  procedure (ds:TDataSet )
   begin
     if Assigned(AFunc) then AList.Add(AFunc(ds))
     else AList.Add(ds.Fields[0].AsString);
   end
  );

  AList.EndUpdate;
end;

function TUniConnectionHelper._sqlCount(const ATableName: string;const AWhere:string): Integer;
var i:Integer;
begin
 i:=-1;
 try
   if not ATableName.IsEmpty then
    Result:=_sqlResults(Concat('SELECT COUNT(*) AS CNT FROM ',ATableName,' ',IfThen(AWhere.IsEmpty,'',' WHERE '+AWhere)),0,'CNT')

 except
   Result:=-1;
 end;
end;

function TUniConnectionHelper._StoredProc(const ProcName: String;
  OnProc: TOnParamsProc): Boolean;
begin
  Result := _StoredProc(ProcName, [], [], OnProc);
end;

function TUniConnectionHelper._StoredProc(const ProcName: String;
  ParamValue: array of variant; OnProc: TOnParamsProc): Boolean;
begin
   Result := _StoredProc(ProcName, [], ParamValue, OnProc);
end;

function TUniConnectionHelper._StoredProc(const ProcName: String;
  ParamName: array of string; ParamValue: array of variant;
  OnProc: TOnParamsProc): Boolean;
var
  sp: TUniStoredProc;
  i: Integer;
  Prm: TUniParam;
begin
  Result := False;
  try
    try
      sp := TUniStoredProc.Create(nil);
      sp.Connection := self;
      sp.Active := False;
      sp.StoredProcName := ProcName;
      sp.PrepareSQL;


      // for i:=0 to sp.ParamCount -1 do
      // ShowMessage(GetEnumName(TypeInfo(TFieldType),ord(sp.Params[i].DataType)));

      if High(ParamValue) > -1 then
      begin

        if High(ParamName) = High(ParamValue) then
          for i := Low(ParamValue) to High(ParamValue) do
            sp.ParamByName(ParamName[i]).Value := ParamValue[i]
        else
          for i := Low(ParamValue) to High(ParamValue) do
            sp.Params[i].Value := ParamValue[i];
      end;
      sp.ExecProc;

      if Assigned(OnProc) then
        OnProc(sp.Params);
      Result := True;
    except
      Result := False;
    end;

  finally
    sp.Free;
  end;

end;


function TUniConnectionHelper._NewConnection: TUniConnection;
begin
Result := TUniConnection.Create(nil);
  try
    // Ana ba�lant�n�n t�m kritik ayarlar�n� kopyala
    Result.ProviderName := Self.ProviderName;
    Result.ConnectString := Self.ConnectString;
    Result.LoginPrompt := False;

    // Pooling ayarlar� (Bunlar ana ba�lant�dan da okunabilir)
    Result.PoolingOptions.MaxPoolSize := 100; // �htiyaca g�re art�r�labilir
    Result.PoolingOptions.MinPoolSize := 5;
    Result.PoolingOptions.ConnectionLifetime := 60; // Saniye cinsinden
    Result.Pooling := True;
    Result.SpecificOptions.Values['Pooling'] := 'True';
    // �NEML�: Burada Connect demiyoruz, sadece nesneyi haz�rl�yoruz.
  except
    FreeAndNil(Result);
    raise;
  end;

end;




function TUniConnectionHelper._Script: TUniScript;
begin
 Result:=TUniScript.Create(nil);
 Result.Connection:=Self;
end;

procedure TUniConnectionHelper._Thread(AProc: TProc<TUniConnection>);
var
  cn: TUniConnection;
begin
if not Assigned(AProc) then Exit;

  // Yeni bir ba�lant� nesnesi olu�tur (Zarf)
  cn := _NewConnection;
  try
    try
      // Connect �a�r�s� Pooling=True oldu�u i�in
      // fiziksel ba�lant� a�maz, POOL'dan bo�ta olan� al�r.
      cn.Connect;

      // ��lemi thread-safe olarak �al��t�r
      AProc(cn);

    finally
      // Disconnect �a�r�s� fiziksel ba�lant�y� kapatmaz,
      // POOL'a "benim i�im bitti, ba�kas� kullanabilir" diye iade eder.
      if cn.Connected then
        cn.Disconnect;
    end;
  finally
    // Nesneyi serbest b�rak�yoruz.
    // Pooling aktif oldu�u i�in fiziksel socket a��k kal�r ve pool'da bekler.
    cn.Free;
  end;
end;


function TUniConnectionHelper._StoredProc(const ProcName: String;
  const ParamValue: array of variant; const ReturnField: string): Variant;
  var
  i:Variant;

begin
  ExecProc(ProcName,ParamValue);


  Result:=ParamByName(ReturnField).Value;


   exit;
    _StoredProc(ProcName,ParamValue,
    Procedure(Prm: TUniParams)
    var
    j:Integer;
    begin
     i:=prm.ParamByName(ReturnField).Value;
    end
     );
 Result:=i;
end;

{$ENDREGION}





{ TUniQueryHelper }

function TDADataSetyHelper.Hack: TCustomDADataSetHack;
begin
 Result:=TCustomDADataSetHack(Self);
end;

function TDADataSetyHelper._AsUni: TUniConnection;
begin
 Result:=Self.Connection as TUniConnection;
end;

function TDADataSetyHelper._SQLInfo: TSQLInfo;
begin
 Result:=TDBAccessUtils.GetSQLInfo(Self);
end;

procedure TDADataSetyHelper._Cols(const AProc: TProc<TCRColumnInfo>);
var
   Cols: TCRColumnsInfo;
   Col:TCRColumnInfo;
begin
   if not Assigned(AProc) then exit;
    Cols:=TCRColumnsInfo.Create;
    try
      for Col in Cols do
       AProc(Col);

    finally
      Cols.Free;
    end;
end;

function TDADataSetyHelper._DataService: TDADataSetService;
begin
 //Assert(not Self.Active,'Dataset Kapal�');
 Result:=TDBAccessUtils.GetDataSetService(Self);

 //TDBAccessUtils.GetSQLInfo(Self).ParseTablesInfo()
 //GetSQLInfo.
 //GetTablesInfo.

end;





function TDADataSetyHelper._FieldAlias(const AFieldName:string): string;
var
 AInfo: TSqlFieldDesc;
begin
  AInfo:=TSqlFieldDesc(Self.GetFieldDesc(AFieldName));
  if AInfo.TableInfo<>nil then
  Result:=AInfo.TableInfo.TableAlias+'.'+AInfo.ActualName
  else
  Result:=AInfo.ActualName;
 {
  for i := 0 to UniQuery1.Fields.Count - 1 do begin
    FieldDesc := TSqlFieldDesc(UniQuery1.GetFieldDesc(UniQuery1.Fields[i]));

    Memo1.Lines.Add(FieldDesc.TableInfo.TableName + '.' + FieldDesc.ActualName + '(' + FieldDesc.Name + ')');
  }
end;

procedure TDADataSetyHelper._GenerateSQLALL;
var
 s:string;
begin
 s:=TDBAccessUtils.SQLGenerator(self).GenerateSQL(TDAParamsInfo.Create(TDAParamInfo) , _stInsert, true);
   if SQL.Text.IsEmpty        then SQL.Text       := _SQLGenerate(0);
   if SQLInsert.Text.IsEmpty  then SQLInsert.Text := _SQLGenerate(1);
   if SQLUpdate.Text.IsEmpty  then SQLUpdate.Text := _SQLGenerate(2);
   if SQLDelete.Text.IsEmpty  then SQLDelete.Text := _SQLGenerate(3);
   if SQLLock.Text.IsEmpty    then SQLLock.Text   := _SQLGenerate(4);
   if SQLRefresh.Text.IsEmpty then SQLRefresh.Text:= _SQLGenerate(5);
end;

function TDADataSetyHelper._GetFastID(const AGetID: Byte): Variant;
var
  LQuery: TUniQuery;
  LKeyField: string;
  LCurrentID: Variant;
  LOperator, LOrderDir, LSQL: string;
begin
  {
  Result := Null;
  LKeyField := Self.KeyFields; // ID alan�n (UUID/LUID)

  if LKeyField.IsEmpty then Exit;
  LCurrentID := Self.FieldByName(LKeyField).Value;
  if VarIsNull(LCurrentID) then Exit;

  // Y�n ve Operat�r Belirleme
  case AGetID of
    0: begin LOperator := 'IS NOT NULL'; LOrderDir := 'ASC';  end; // �lk
    1: begin LOperator := 'IS NOT NULL'; LOrderDir := 'DESC'; end; // Son
    2: begin LOperator := '> :ID';       LOrderDir := 'ASC';  end; // Sonraki
    3: begin LOperator := '< :ID';       LOrderDir := 'DESC'; end; // �nceki
  else Exit;
  end;

  LQuery := _AsUni._CreateQuery;
  try
    // DB Tipine g�re SQL (PostgreSQL i�in LIMIT 1, MSSQL i�in TOP 1)
    case _AsUni._DBType of
      TSqlDBDefinition.dMSSQL:
        LSQL := Format('SELECT TOP 1 %s FROM %s WHERE %s %s ORDER BY %s %s',
                       [LKeyField, _TableName, LKeyField, LOperator, LKeyField, LOrderDir]);
      TSqlDBDefinition.dPostgreSQL, TSqlDBDefinition.dSQLite, TSqlDBDefinition.dMySQL:
        LSQL := Format('SELECT %s FROM %s WHERE %s %s ORDER BY %s %s LIMIT 1',
                       [LKeyField, _TableName, LKeyField, LOperator, LKeyField, LOrderDir]);
    else
      Exit;
    end;

    LQuery.SQL.Text := LSQL;

    // Parametre ata (UUID/LUID string veya binary olsa da UniDAC bunu halleder)
    if LOperator.Contains(':ID') then
      LQuery.ParamByName('ID').Value := LCurrentID;

    LQuery.Open;

    if not LQuery.IsEmpty then
      Result := LQuery.Fields[0].Value
    else
      Result := LCurrentID; // Bulamazsa yerinde kal
  finally
    LQuery.Free;
  end;
 }
end;

procedure TDADataSetyHelper._KeyFieldNames(const AProc:TProc<TStrings>);
var
 lst:TStrings;
begin
  if not Assigned(AProc) then exit;
  lst:=TStringList.Create;
   try
     Hack.GetKeyFieldNames(lst);
     AProc(lst);
   finally
    lst.Free;

   end;

end;

function TDADataSetyHelper._Macro(const AMacroName,
  Avalue: string): TCustomDADataSet;
begin
 MacroByName(AMacroName).Value:=Avalue;
 Result:=self;
end;

function TDADataSetyHelper._ApplyFilter(const AFilter: IRadSqlFilter): TCustomDADataSet;
var
  P: TRadSqlParam;
begin
  for P in AFilter.Params do
    ParamByName(P.Name).Value := P.Value;
  Result := Self;
end;

function TDADataSetyHelper._ApplyCustomFieldMacro(const AMacro, ATable, AAlias: string): TCustomDADataSet;
begin
  MacroByName(AMacro).Value := _AsUni._CustomFieldColumns(ATable, AAlias);
  Result := Self;
end;

function TDADataSetyHelper._EnsureCustomFields: TCustomDADataSet;
var
  i: Integer;
  LDef: TFieldDef;
begin
  Result := Self;
  if Active then
    raise ERadCustomField.Create('_EnsureCustomFields: dataset kapalı olmalı.');
  if FieldCount = 0 then Exit;   // persistent alan yok: dinamik alanlar yeni kolonu zaten görür
  FieldDefs.Updated := False;
  FieldDefs.Update;
  for i := 0 to FieldDefs.Count - 1 do
  begin
    LDef := FieldDefs[i];
    if (TRadCustomFieldDdl.NumberOf(LDef.Name) > 0) and (FindField(LDef.Name) = nil) then
      LDef.CreateField(Self);
  end;
end;



function TDADataSetyHelper._SQLGenerate(const Index: Integer): string;
begin

   Result:='';
   //TDBAccessUtils.SQLGenerator(self).SubstituteParamName := False;

   case _TStatementType(Index) of
     _stQuery:Result:=SQL.Text;
     _stInsert:Result:=SQLInsert.Text;
     _stUpdate:Result:=SQLUpdate.Text;
     _stDelete:Result:=SQLDelete.Text;
     _stLock:Result:=SQLLock.Text;
     _stRefresh:Result:=SQLRefresh.Text;
   end;
   if Result.IsEmpty then


   //result:=_DataService.SQLGenerator.IndexedPrefix;
   if (_DataService<>nil) and (_DataService.SQLGenerator<>nil) then
   Result:=_DataService.SQLGenerator.GenerateSQL(_DataService.Updater.ParamsInfo,_TStatementType(Index),True) ;

   //ShowMessage(Result);
   //Result:=_DataService.SQLGenerator.GenerateSQL(_DataService.Updater.ParamsInfo,_stUpdate,True)
   {
    Result := TDBAccessUtils.SQLGenerator(self).GenerateSQLforUpdTable(_DataService.Updater.ParamsInfo, KeyAndDataFields, _stInsert, true);
    Result:=_DataService.SQLGenerator.GenerateRecCountSQL(true);

    _TStatementType = (_stQuery, _stInsert, _stUpdate, _stDelete, _stLock, _stRefresh,
    _stCustom, _stRefreshQuick, _stRefreshCheckDeleted, _stBatchUpdate, _stRecCount);
     Result:= _SQLGenerator.GenerateSQL(TDBAccessUtils.GetUpdater(self).ParamsInfo, _stUpdate, true);
   }
end;



function TDADataSetyHelper._SQLGetFrom: string;
begin
  Result:=Hack.SQLGetFrom(Self.BaseSQL);

end;


function TDADataSetyHelper._TableName: string;
begin
    Result:=UpdatingTable;
    if Result.IsEmpty then
    Result:=_SQLGetFrom;
     //if DS is TUniQuery then TempStr:=TUniQuery(DS).UpdatingTable   else TempStr:=TUniTable(DS).TableName;
end;

function TDADataSetyHelper._Transaction: TUniTransaction;
begin
 if (State = dsEdit) and (Assigned(UpdateTransaction)) then
  Result:=TUniTransaction(UpdateTransaction)
 else if Assigned(Transaction) then
  Result:=TUniTransaction(Transaction)
 else if Assigned(Connection) then
  Result:=_AsUni.DefaultTransaction
end;

function TDADataSetyHelper._UpdateStatus(AProc: TProc<TDataSet>;  const AUpdateStatus: TUpdateStatusSet): TCustomDADataSet;
begin
 _DoEof(
 procedure (ds:TDataSet)
 begin
  //UpdateResult in [uaFail,uaSkip]
  if Self.UpdateStatus in AUpdateStatus then AProc(ds);
 end
 );

 Result:=Self;
end;

function TDADataSetyHelper._OpenSQL(const ASQL: string): TCustomDADataSet;
begin
 Self.Close;
 SQL.Text:=ASQL;
 Self.Open;
 Result:=Self;
end;

function TDADataSetyHelper._ReOpen: TCustomDADataSet;
begin
Result:=_ReOpen([]);
end;

function TDADataSetyHelper._ReOpen(const arg: array of variant): TCustomDADataSet;
var
 i:Integer;
begin
 DisableControls;
if _IsEditOrInsert then Cancel;

  Close;
   for i := Low(arg) to High(arg) do
      Params.Items[i].Value:=arg[i];
  Open;
 EnableControls;
Result:=Self;
end;
 {
function TDADataSetyHelper._ReOpenMaster: TCustomDADataSet;
begin
 if (MasterSource<>nil) and (not MasterFields.IsEmpty) then //and (not DetailFields.IsEmpty)
  begin
    DisableControls;
    Close;
    ParamByName(DetailFields).Value:=MasterSource.DataSet._V[MasterFields];
    Open;
    EnableControls;
  end;
 //_ReOpen(MasterSource.DataSet._V[MasterFields]);
end;
}
function TDADataSetyHelper._ReOpen(const V: Variant): TCustomDADataSet;
begin
   Result:=_ReOpen([v]);
end;

{ TUniScriptHelp }

function TUniScriptHelp._AutoCommit(const AValue: Boolean): TUniScript;
begin
 AutoCommit:=AValue;
 Result:=self;
end;

function TUniScriptHelp._Delimiter(const AValue: string): TUniScript;
begin
 Delimiter:=AValue;
 Result:=self;
end;

function TUniScriptHelp._Execute: TUniScript;
begin
 Execute;
 Result:=self;
end;

function TUniScriptHelp._NoConnect(const AValue: Boolean): TUniScript;
begin
NoPreconnect:=AValue;
Result:=self;
end;

function TUniScriptHelp._ScanParams(const AValue: Boolean): TUniScript;
begin
ScanParams:=AValue;
Result:=self;
end;

function TUniScriptHelp._SQL(const AValue: string): TUniScript;
begin
SQL.Text:=AValue;
Result:=self;
end;

{ TUniMacroHelper }

function TUniMacroHelper._Add(const AMacroName, AValue: string): TUniMacros;
var
 mc:TUniMacro;
begin
 mc:=FindMacro(AMacroName);
 if mc =nil then
  Self.Add(AMacroName,AValue)
 else
  mc.Value:=AValue;
 Result:=Self;
end;

function TUniMacroHelper._AddStr(const AMacroName, AValue: string): TUniMacros;
var
 mc:TUniMacro;
begin
 mc:=FindMacro(AMacroName);
 if mc =nil then
   _Add(AMacroName,''''+AValue+'''')
 else
  mc.Value:=''''+AValue+'''';
  Result:=Self;
   //Result:=_Add(AMacroName,''''+AValue+'''');
end;

{ TRadUniCustomFieldStore }

function TRadUniStoreBase.MemoText(AField: TField): string;
begin
  // Firebird 'blob sub_type text' TMemoField gelir ve AsString ANSI çözer ('ş' iki karakter olur; ScriptLiveTest S06).
  // PG'de ise AsString doğru, AsBytes ANSI'ye çevirip İ'de EEncodingError verir: yalnız Firebird'de bayt yolu.
  if (FDialect = sdFirebird) and (AField is TBlobField) and not (AField is TWideMemoField) then
    Result := TEncoding.UTF8.GetString(TBlobField(AField).AsBytes)
  else
    Result := AField.AsString;
end;

function FieldBool(AField: TField): Boolean;
begin
  // MySQL tinyint(1) sayı gelir; diğerleri TBooleanField.
  if AField is TBooleanField then Result := AField.AsBoolean
  else Result := AField.AsInteger <> 0;
end;

{ TRadUniStoreBase }

constructor TRadUniStoreBase.Create(ACon: TUniConnection);
begin
  inherited Create;
  if ACon = nil then
    raise EArgumentNilException.Create(ClassName + ': bağlantı nil.');
  FCon := ACon;
  FDialect := ACon._SqlDialect;
end;

class function TRadUniCustomFieldStore.New(ACon: TUniConnection): IRadCustomFieldStore;
begin
  Result := TRadUniCustomFieldStore.Create(ACon);
end;

function TRadUniStoreBase.Dialect: TRadSqlDialect;
begin
  Result := FDialect;
end;

function TRadUniStoreBase.Q(const ASql: string): TUniQuery;
begin
  Result := TUniQuery.Create(nil);
  Result.Connection := FCon;
  if FTx <> nil then
  begin
    Result.Transaction := FTx;
    Result.SpecificOptions.Values['AutoCommit'] := 'False';
  end;
  Result.SQL.Text := ASql;
end;

procedure TRadUniStoreBase.Exec(const ASql: string);
var
  LQ: TUniQuery;
begin
  LQ := Q(ASql);
  try
    LQ.ExecSQL;
  finally
    LQ.Free;
  end;
end;

function TRadUniStoreBase.CountOf(const ASql: string; const ANames: array of string;
  const AValues: array of Variant): Integer;
var
  LQ: TUniQuery;
  i: Integer;
begin
  LQ := Q(ASql);
  try
    for i := 0 to High(ANames) do
      LQ.ParamByName(ANames[i]).Value := AValues[i];
    LQ.Open;
    Result := LQ.Fields[0].AsInteger;
  finally
    LQ.Free;
  end;
end;

function TRadUniStoreBase.TableExists(const ATable: string): Boolean;
begin
  Result := CountOf(TRadCustomFieldDdl.TableExistsSql(FDialect), ['t'],
    [TRadCustomFieldDdl.CatalogName(FDialect, ATable)]) > 0;
end;

function TRadUniStoreBase.ColumnExists(const ATable, AColumn: string): Boolean;
begin
  Result := CountOf(TRadCustomFieldDdl.ColumnExistsSql(FDialect), ['t', 'c'],
    [TRadCustomFieldDdl.CatalogName(FDialect, ATable), TRadCustomFieldDdl.CatalogName(FDialect, AColumn)]) > 0;
end;

procedure TRadUniStoreBase.InTransaction(AProc: TProc);
begin
  (* Firebird (UniDAC InterBase sağlayıcısı): bağlantının AutoCommit'i her
     değişiklikten sonra CommitRetaining yapar, DDL de dahil - bağlantı
     transaction'ı içinde Rollback kolonu geri almaz (FbDdlProbe A: kolon kaldı).
     Ayrı TUniTransaction + sorgu düzeyinde AutoCommit=False ile geri alınıyor
     (FbDdlProbe H/I). Üstelik her SELECT varsayılan transaction'ı açık bırakır,
     bu yüzden InTransaction kontrolü de Firebird'de anlamsız. *)
  if FDialect = sdFirebird then
  begin
    FTx := TUniTransaction.Create(nil);
    try
      FTx.DefaultConnection := FCon;
      FTx.StartTransaction;
      try
        AProc;
        FTx.Commit;
      except
        FTx.Rollback;
        raise;
      end;
    finally
      FreeAndNil(FTx);
    end;
    Exit;
  end;
  if FCon.InTransaction then
  begin
    AProc;   // çağıranın transaction'ı; o yönetir
    Exit;
  end;
  FCon.StartTransaction;
  try
    AProc;
    FCon.Commit;
  except
    FCon.Rollback;
    raise;
  end;
end;

procedure TRadUniCustomFieldStore.EnsureDefinitionTables;
var
  LSql: TArray<string>;
  LNames: array[0..2] of string;
  i: Integer;
begin
  LSql := TRadCustomFieldDdl.CreateDefinitionTables(FDialect);
  LNames[0] := TRadCustomFieldDdl.GroupTable;
  LNames[1] := TRadCustomFieldDdl.FieldTable;
  LNames[2] := TRadCustomFieldDdl.LayoutTable;
  for i := 0 to 2 do
    if not TableExists(LNames[i]) then
      Exec(LSql[i]);
end;

procedure TRadUniCustomFieldStore.ReadGroup(AQ: TUniQuery; AGroup: TRadCustomFieldGroupDef);
begin
  AGroup.Id := AQ.FieldByName('id').AsInteger;
  AGroup.TableName := AQ.FieldByName('tablo_adi').AsString;
  AGroup.Name := AQ.FieldByName('adi').AsString;
  AGroup.Order := AQ.FieldByName('sira').AsInteger;
  AGroup.Active := FieldBool(AQ.FieldByName('aktif_mi'));
end;

procedure TRadUniCustomFieldStore.ReadField(AQ: TUniQuery; ADef: TRadCustomFieldDef);
begin
  ADef.Id := AQ.FieldByName('id').AsInteger;
  ADef.GroupId := AQ.FieldByName('grup_id').AsInteger;
  ADef.TableName := AQ.FieldByName('tablo_adi').AsString;
  ADef.ColumnName := LowerCase(AQ.FieldByName('kolon_adi').AsString);
  ADef.Caption := AQ.FieldByName('baslik').AsString;
  ADef.FieldType := TRadCustomFieldDef.TypeOfCode(AQ.FieldByName('veri_tipi').AsString);
  ADef.Length := AQ.FieldByName('uzunluk').AsInteger;
  ADef.Decimals := AQ.FieldByName('ondalik').AsInteger;
  ADef.Required := FieldBool(AQ.FieldByName('zorunlu_mu'));
  ADef.DefaultValue := AQ.FieldByName('varsayilan').AsString;
  ADef.SetOptionsText(MemoText(AQ.FieldByName('secenekler')));
  ADef.Filterable := FieldBool(AQ.FieldByName('filtrele_mi'));
  ADef.Order := AQ.FieldByName('sira').AsInteger;
  ADef.Active := FieldBool(AQ.FieldByName('aktif_mi'));
end;

function TRadUniCustomFieldStore.LoadGroups(const ATable: string; AIncludeInactive: Boolean): TRadCustomFieldGroups;
var
  LQ: TUniQuery;
  G: TRadCustomFieldGroupDef;
  D: TRadCustomFieldDef;
  LById: TDictionary<Integer, TRadCustomFieldGroupDef>;
  LWhere: string;
begin
  Result := TRadCustomFieldGroups.Create(True);
  LById := TDictionary<Integer, TRadCustomFieldGroupDef>.Create;
  try
    if AIncludeInactive then LWhere := '' else LWhere := ' and aktif_mi = :a';
    LQ := Q(Format('select * from %s where tablo_adi = :t%s order by sira, id', [TRadCustomFieldDdl.GroupTable, LWhere]));
    try
      LQ.ParamByName('t').AsString := ATable;
      if not AIncludeInactive then LQ.ParamByName('a').AsBoolean := True;
      LQ.Open;
      while not LQ.Eof do
      begin
        G := TRadCustomFieldGroupDef.Create;
        ReadGroup(LQ, G);
        Result.Add(G);
        LById.AddOrSetValue(G.Id, G);
        LQ.Next;
      end;
    finally
      LQ.Free;
    end;
    LQ := Q(Format('select * from %s where tablo_adi = :t%s order by sira, id', [TRadCustomFieldDdl.FieldTable, LWhere]));
    try
      LQ.ParamByName('t').AsString := ATable;
      if not AIncludeInactive then LQ.ParamByName('a').AsBoolean := True;
      LQ.Open;
      while not LQ.Eof do
      begin
        D := TRadCustomFieldDef.Create;
        ReadField(LQ, D);
        if LById.TryGetValue(D.GroupId, G) then G.Fields.Add(D)
        else D.Free;   // pasif gruptaki alan: görünmez
        LQ.Next;
      end;
    finally
      LQ.Free;
    end;
  finally
    LById.Free;
  end;
end;

procedure TRadUniCustomFieldStore.AddGroup(AGroup: TRadCustomFieldGroupDef);
var
  LQ: TUniQuery;
begin
  if Trim(AGroup.Name) = '' then
    raise ERadCustomField.Create('Grup adı boş olamaz.');
  if not TRadCustomFieldDdl.IsValidTableName(AGroup.TableName) then
    raise ERadCustomField.Create('Tablo adı geçersiz.');
  LQ := Q(Format('insert into %s (tablo_adi, adi, sira, aktif_mi) values (:t, :n, :s, :a)',
    [TRadCustomFieldDdl.GroupTable]));
  try
    LQ.ParamByName('t').AsString := AGroup.TableName;
    LQ.ParamByName('n').AsString := AGroup.Name;
    LQ.ParamByName('s').AsInteger := AGroup.Order;
    LQ.ParamByName('a').AsBoolean := AGroup.Active;
    LQ.ExecSQL;
    LQ.SQL.Text := Format('select id from %s where tablo_adi = :t and adi = :n', [TRadCustomFieldDdl.GroupTable]);
    LQ.ParamByName('t').AsString := AGroup.TableName;
    LQ.ParamByName('n').AsString := AGroup.Name;
    LQ.Open;
    AGroup.Id := LQ.Fields[0].AsInteger;
  finally
    LQ.Free;
  end;
end;

procedure TRadUniCustomFieldStore.UpdateGroup(AGroup: TRadCustomFieldGroupDef);
var
  LQ: TUniQuery;
begin
  if Trim(AGroup.Name) = '' then
    raise ERadCustomField.Create('Grup adı boş olamaz.');
  LQ := Q(Format('update %s set adi = :n, sira = :s, aktif_mi = :a where id = :id', [TRadCustomFieldDdl.GroupTable]));
  try
    LQ.ParamByName('n').AsString := AGroup.Name;
    LQ.ParamByName('s').AsInteger := AGroup.Order;
    LQ.ParamByName('a').AsBoolean := AGroup.Active;
    LQ.ParamByName('id').AsInteger := AGroup.Id;
    LQ.ExecSQL;
  finally
    LQ.Free;
  end;
end;

function TRadUniCustomFieldStore.ExistingColumnNames(const ATable: string): TArray<string>;
var
  LQ: TUniQuery;
  LList: TList<string>;
begin
  LList := TList<string>.Create;
  try
    LQ := Q(Format('select kolon_adi from %s where tablo_adi = :t', [TRadCustomFieldDdl.FieldTable]));
    try
      LQ.ParamByName('t').AsString := ATable;
      LQ.Open;
      while not LQ.Eof do
      begin
        LList.Add(LQ.Fields[0].AsString);
        LQ.Next;
      end;
    finally
      LQ.Free;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

procedure TRadUniCustomFieldStore.WriteFieldParams(AQ: TUniQuery; ADef: TRadCustomFieldDef);
begin
  AQ.ParamByName('b').AsString := ADef.Caption;
  AQ.ParamByName('z').AsBoolean := ADef.Required;
  if Trim(ADef.DefaultValue) = '' then AQ.ParamByName('v').Clear
  else AQ.ParamByName('v').AsString := ADef.DefaultValue;
  AQ.ParamByName('o').DataType := ftMemo;
  if ADef.HasOptions then AQ.ParamByName('o').AsString := ADef.OptionsText
  else AQ.ParamByName('o').Clear;
  AQ.ParamByName('f').AsBoolean := ADef.Filterable;
  AQ.ParamByName('s').AsInteger := ADef.Order;
  AQ.ParamByName('a').AsBoolean := ADef.Active;
end;

procedure TRadUniCustomFieldStore.AddField(ADef: TRadCustomFieldDef);
var
  LErr: string;
begin
  LErr := ADef.Validate;
  if LErr <> '' then
    raise ERadCustomField.Create(LErr);
  if ADef.GroupId = 0 then
    raise ERadCustomField.Create('Alan bir gruba bağlı olmalı.');
  ADef.ColumnName := TRadCustomFieldDdl.ColumnName(TRadCustomFieldDdl.NextNumber(ExistingColumnNames(ADef.TableName)));
  if ColumnExists(ADef.TableName, ADef.ColumnName) then
    raise ERadCustomField.CreateFmt('"%s" kolonu "%s" tablosunda zaten var; tanım tablosu ile tablo uyumsuz.',
      [ADef.ColumnName, ADef.TableName]);
  InTransaction(
    procedure
    var
      LQ: TUniQuery;
    begin
      Exec(TRadCustomFieldDdl.AddColumn(FDialect, ADef.TableName, ADef));
      LQ := Q(Format('insert into %s (grup_id, tablo_adi, kolon_adi, baslik, veri_tipi, uzunluk, ondalik, ' +
        'zorunlu_mu, varsayilan, secenekler, filtrele_mi, sira, aktif_mi, olusturan, olusturma_zamani) ' +
        'values (:g, :t, :c, :b, :vt, :u, :d, :z, :v, :o, :f, :s, :a, :who, :when)', [TRadCustomFieldDdl.FieldTable]));
      try
        LQ.ParamByName('g').AsInteger := ADef.GroupId;
        LQ.ParamByName('t').AsString := ADef.TableName;
        LQ.ParamByName('c').AsString := ADef.ColumnName;
        LQ.ParamByName('vt').AsString := ADef.TypeCode;
        LQ.ParamByName('u').AsInteger := ADef.Length;
        LQ.ParamByName('d').AsInteger := ADef.Decimals;
        WriteFieldParams(LQ, ADef);
        LQ.ParamByName('who').AsString := FCon.Username;
        LQ.ParamByName('when').AsDateTime := Now;
        LQ.ExecSQL;
        LQ.SQL.Text := Format('select id from %s where tablo_adi = :t and kolon_adi = :c', [TRadCustomFieldDdl.FieldTable]);
        LQ.ParamByName('t').AsString := ADef.TableName;
        LQ.ParamByName('c').AsString := ADef.ColumnName;
        LQ.Open;
        ADef.Id := LQ.Fields[0].AsInteger;
      finally
        LQ.Free;
      end;
    end);
end;

procedure TRadUniCustomFieldStore.UpdateField(ADef: TRadCustomFieldDef);
var
  LQ: TUniQuery;
  LErr: string;
begin
  LErr := ADef.Validate;
  if LErr <> '' then
    raise ERadCustomField.Create(LErr);
  LQ := Q(Format('select veri_tipi, kolon_adi from %s where id = :id', [TRadCustomFieldDdl.FieldTable]));
  try
    LQ.ParamByName('id').AsInteger := ADef.Id;
    LQ.Open;
    if LQ.Eof then
      raise ERadCustomField.CreateFmt('Özel alan tanımı bulunamadı (id=%d).', [ADef.Id]);
    if not SameText(LQ.Fields[0].AsString, ADef.TypeCode) or not SameText(LQ.Fields[1].AsString, ADef.ColumnName) then
      raise ERadCustomField.Create('Özel alanın tipi ve kolon adı değiştirilemez.');
    LQ.SQL.Text := Format('update %s set grup_id = :g, baslik = :b, zorunlu_mu = :z, varsayilan = :v, secenekler = :o, ' +
      'filtrele_mi = :f, sira = :s, aktif_mi = :a where id = :id', [TRadCustomFieldDdl.FieldTable]);
    LQ.ParamByName('g').AsInteger := ADef.GroupId;
    WriteFieldParams(LQ, ADef);
    LQ.ParamByName('id').AsInteger := ADef.Id;
    LQ.ExecSQL;
  finally
    LQ.Free;
  end;
end;

procedure TRadUniCustomFieldStore.ExtendLength(ADef: TRadCustomFieldDef; ANewLength: Integer);
var
  LSql: string;
begin
  LSql := TRadCustomFieldDdl.AlterLength(FDialect, ADef.TableName, ADef, ANewLength);   // doğrulamayı o yapar
  InTransaction(
    procedure
    var
      LQ: TUniQuery;
    begin
      Exec(LSql);
      LQ := Q(Format('update %s set uzunluk = :u where id = :id', [TRadCustomFieldDdl.FieldTable]));
      try
        LQ.ParamByName('u').AsInteger := ANewLength;
        LQ.ParamByName('id').AsInteger := ADef.Id;
        LQ.ExecSQL;
      finally
        LQ.Free;
      end;
    end);
  ADef.Length := ANewLength;
end;

function TRadUniCustomFieldStore.ColumnNames(const ATable: string): TArray<string>;
var
  LGroups: TRadCustomFieldGroups;
  G: TRadCustomFieldGroupDef;
  D: TRadCustomFieldDef;
  LList: TList<string>;
begin
  LList := TList<string>.Create;
  LGroups := LoadGroups(ATable, False);
  try
    for G in LGroups do
      for D in G.ActiveFields do
        LList.Add(D.ColumnName);
    Result := LList.ToArray;
  finally
    LGroups.Free;
    LList.Free;
  end;
end;

function TRadUniCustomFieldStore.LoadLayout(const ATable: string; AUserId: Integer; AStream: TStream): Boolean;
var
  LQ: TUniQuery;
begin
  LQ := Q(Format('select duzen from %s where tablo_adi = :t and kullanici_id = :u', [TRadCustomFieldDdl.LayoutTable]));
  try
    LQ.ParamByName('t').AsString := ATable;
    LQ.ParamByName('u').AsInteger := AUserId;
    LQ.Open;
    Result := not LQ.Eof and not LQ.Fields[0].IsNull;
    if Result then
      TBlobField(LQ.Fields[0]).SaveToStream(AStream);
  finally
    LQ.Free;
  end;
end;

procedure TRadUniCustomFieldStore.SaveLayout(const ATable: string; AUserId: Integer; AStream: TStream);
var
  LQ: TUniQuery;
begin
  DeleteLayout(ATable, AUserId);
  LQ := Q(Format('insert into %s (tablo_adi, kullanici_id, duzen) values (:t, :u, :d)', [TRadCustomFieldDdl.LayoutTable]));
  try
    LQ.ParamByName('t').AsString := ATable;
    LQ.ParamByName('u').AsInteger := AUserId;
    AStream.Position := 0;
    LQ.ParamByName('d').LoadFromStream(AStream, ftBlob);
    LQ.ExecSQL;
  finally
    LQ.Free;
  end;
end;

procedure TRadUniCustomFieldStore.DeleteLayout(const ATable: string; AUserId: Integer);
var
  LQ: TUniQuery;
begin
  LQ := Q(Format('delete from %s where tablo_adi = :t and kullanici_id = :u', [TRadCustomFieldDdl.LayoutTable]));
  try
    LQ.ParamByName('t').AsString := ATable;
    LQ.ParamByName('u').AsInteger := AUserId;
    LQ.ExecSQL;
  finally
    LQ.Free;
  end;
end;


{ TRadUniScriptStore }

class function TRadUniScriptStore.New(ACon: TUniConnection): IRadScriptStore;
begin
  Result := TRadUniScriptStore.Create(ACon);
end;

procedure TRadUniScriptStore.EnsureDefinitionTables;
var
  LSql, LNames: TArray<string>;
  i: Integer;
begin
  LSql := TRadScriptDdl.CreateDefinitionTables(FDialect);
  LNames := TRadScriptDdl.TableNames;
  for i := 0 to High(LNames) do
    if not TableExists(LNames[i]) then
      Exec(LSql[i]);
end;

procedure TRadUniScriptStore.ReadPackage(AQ: TUniQuery; APkg: TRadScriptPackage);
begin
  APkg.Id := AQ.FieldByName('id').AsInteger;
  APkg.Code := AQ.FieldByName('kod').AsString;
  APkg.Name := AQ.FieldByName('adi').AsString;
  APkg.Description := AQ.FieldByName('aciklama').AsString;
  APkg.Version := AQ.FieldByName('surum').AsString;
  APkg.Author := AQ.FieldByName('yazar').AsString;
  APkg.Active := FieldBool(AQ.FieldByName('aktif_mi'));
  APkg.IsProtected := FieldBool(AQ.FieldByName('korumali_mi'));
  APkg.Order := AQ.FieldByName('sira').AsInteger;
  APkg.Created := AQ.FieldByName('olusturma_zamani').AsDateTime;
  APkg.Modified := AQ.FieldByName('degisim_zamani').AsDateTime;
end;

procedure TRadUniScriptStore.ReadScript(AQ: TUniQuery; AScript: TRadScript);
var
  LKind: TRadScriptKind;
begin
  AScript.Id := AQ.FieldByName('id').AsInteger;
  AScript.PackageId := AQ.FieldByName('paket_id').AsInteger;
  AScript.Code := AQ.FieldByName('kod').AsString;
  AScript.Name := AQ.FieldByName('adi').AsString;
  if not TRadScript.KindOfCode(AQ.FieldByName('tur').AsString, LKind) then
    raise ERadScript.CreateFmt('Bilinmeyen script türü: "%s" (id %d).', [AQ.FieldByName('tur').AsString, AScript.Id]);
  AScript.Kind := LKind;
  AScript.Target := AQ.FieldByName('hedef').AsString;
  AScript.Order := AQ.FieldByName('sira').AsInteger;
  AScript.Active := FieldBool(AQ.FieldByName('aktif_mi'));
  AScript.Source := MemoText(AQ.FieldByName('kaynak'));
  AScript.Modified := AQ.FieldByName('degisim_zamani').AsDateTime;
end;

procedure TRadUniScriptStore.LoadChildren(APkg: TRadScriptPackage);
var
  LQ: TUniQuery;
  S: TRadScript;
  P: TRadScriptParam;
  D: TRadScriptDbStep;
  R: TRadScriptResource;
begin
  LQ := Q(Format('select * from %s where paket_id = :p order by sira, id', [TRadScriptDdl.ScriptTable]));
  try
    LQ.ParamByName('p').AsInteger := APkg.Id;
    LQ.Open;
    while not LQ.Eof do
    begin
      S := TRadScript.Create;
      APkg.Scripts.Add(S);
      ReadScript(LQ, S);
      LQ.Next;
    end;
    LQ.Close;
    LQ.SQL.Text := Format('select * from %s where paket_id = :p order by adi', [TRadScriptDdl.ParamTable]);
    LQ.ParamByName('p').AsInteger := APkg.Id;
    LQ.Open;
    while not LQ.Eof do
    begin
      P := APkg.AddParam(LQ.FieldByName('adi').AsString, LQ.FieldByName('deger').AsString);
      P.Id := LQ.FieldByName('id').AsInteger;
      P.Description := LQ.FieldByName('aciklama').AsString;
      LQ.Next;
    end;
    LQ.Close;
    LQ.SQL.Text := Format('select * from %s where paket_id = :p order by sira', [TRadScriptDdl.DbTable]);
    LQ.ParamByName('p').AsInteger := APkg.Id;
    LQ.Open;
    while not LQ.Eof do
    begin
      D := APkg.AddDbStep(LQ.FieldByName('sira').AsInteger, MemoText(LQ.FieldByName('sql_metni')));
      D.Id := LQ.FieldByName('id').AsInteger;
      D.Description := LQ.FieldByName('aciklama').AsString;
      D.Applied := FieldBool(LQ.FieldByName('uygulandi_mi'));
      D.AppliedAt := LQ.FieldByName('uygulama_zamani').AsDateTime;
      LQ.Next;
    end;
    LQ.Close;
    LQ.SQL.Text := Format('select * from %s where paket_id = :p order by dosya_adi', [TRadScriptDdl.ResourceTable]);
    LQ.ParamByName('p').AsInteger := APkg.Id;
    LQ.Open;
    while not LQ.Eof do
    begin
      R := APkg.AddResource(LQ.FieldByName('dosya_adi').AsString, LQ.FieldByName('icerik').AsBytes);
      R.Id := LQ.FieldByName('id').AsInteger;
      LQ.Next;
    end;
  finally
    LQ.Free;
  end;
end;

function TRadUniScriptStore.LoadPackages(AIncludeInactive: Boolean): TRadScriptPackages;
var
  LQ: TUniQuery;
  LWhere: string;
  LPkg: TRadScriptPackage;
begin
  Result := TRadScriptPackages.Create(True);
  try
    if AIncludeInactive then LWhere := '' else LWhere := ' where aktif_mi = :a';
    LQ := Q(Format('select * from %s%s order by sira, id', [TRadScriptDdl.PackageTable, LWhere]));
    try
      if not AIncludeInactive then LQ.ParamByName('a').AsBoolean := True;
      LQ.Open;
      while not LQ.Eof do
      begin
        LPkg := TRadScriptPackage.Create;
        Result.Add(LPkg);
        ReadPackage(LQ, LPkg);
        LQ.Next;
      end;
    finally
      LQ.Free;
    end;
    for LPkg in Result do
      LoadChildren(LPkg);
  except
    Result.Free;
    raise;
  end;
end;

function TRadUniScriptStore.LoadPackage(const ACode: string): TRadScriptPackage;
var
  LQ: TUniQuery;
begin
  Result := nil;
  LQ := Q(Format('select * from %s where kod = :k', [TRadScriptDdl.PackageTable]));
  try
    LQ.ParamByName('k').AsString := ACode;
    LQ.Open;
    if LQ.Eof then Exit;
    Result := TRadScriptPackage.Create;
    try
      ReadPackage(LQ, Result);
      LoadChildren(Result);
    except
      FreeAndNil(Result);
      raise;
    end;
  finally
    LQ.Free;
  end;
end;

function TRadUniScriptStore.FindPackageId(const ACode: string): Integer;
var
  LQ: TUniQuery;
begin
  LQ := Q(Format('select id from %s where kod = :k', [TRadScriptDdl.PackageTable]));
  try
    LQ.ParamByName('k').AsString := ACode;
    LQ.Open;
    if LQ.Eof then Result := 0 else Result := LQ.Fields[0].AsInteger;
  finally
    LQ.Free;
  end;
end;

function TRadUniScriptStore.FetchChildId(const ATable, AKeyCol: string; APackageId: Integer;
  const AKey: Variant): Integer;
var
  LQ: TUniQuery;
begin
  LQ := Q(Format('select id from %s where paket_id = :p and %s = :k', [ATable, AKeyCol]));
  try
    LQ.ParamByName('p').AsInteger := APackageId;
    LQ.ParamByName('k').Value := AKey;
    LQ.Open;
    Result := LQ.Fields[0].AsInteger;
  finally
    LQ.Free;
  end;
end;

function TRadUniScriptStore.ExistingChildIds(const ATable, AKeyCol: string;
  APackageId: Integer): TDictionary<string, Integer>;
var
  LQ: TUniQuery;
begin
  Result := TDictionary<string, Integer>.Create;
  try
    LQ := Q(Format('select id, %s from %s where paket_id = :p', [AKeyCol, ATable]));
    try
      LQ.ParamByName('p').AsInteger := APackageId;
      LQ.Open;
      while not LQ.Eof do
      begin
        Result.AddOrSetValue(LowerCase(LQ.Fields[1].AsString), LQ.Fields[0].AsInteger);
        LQ.Next;
      end;
    finally
      LQ.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TRadUniScriptStore.DeleteRemaining(const ATable: string; AIds: TDictionary<string, Integer>);
var
  LQ: TUniQuery;
  LId: Integer;
begin
  if AIds.Count = 0 then Exit;
  LQ := Q(Format('delete from %s where id = :id', [ATable]));
  try
    for LId in AIds.Values do
    begin
      LQ.ParamByName('id').AsInteger := LId;
      LQ.ExecSQL;
    end;
  finally
    LQ.Free;
  end;
end;

procedure TRadUniScriptStore.WritePackageRow(APkg: TRadScriptPackage);
var
  LQ: TUniQuery;
  LNow: TDateTime;
begin
  LNow := Now;
  APkg.Id := FindPackageId(APkg.Code);
  if APkg.Id = 0 then
  begin
    APkg.Created := LNow;
    LQ := Q(Format('insert into %s (kod, adi, aciklama, surum, yazar, aktif_mi, korumali_mi, sira, ' +
      'olusturma_zamani, degisim_zamani) values (:k, :n, :d, :v, :y, :a, :p, :s, :c, :m)', [TRadScriptDdl.PackageTable]));
  end
  else
    LQ := Q(Format('update %s set adi = :n, aciklama = :d, surum = :v, yazar = :y, aktif_mi = :a, ' +
      'korumali_mi = :p, sira = :s, degisim_zamani = :m where kod = :k', [TRadScriptDdl.PackageTable]));
  try
    LQ.ParamByName('k').AsString := APkg.Code;
    LQ.ParamByName('n').AsString := APkg.Name;
    LQ.ParamByName('d').AsString := APkg.Description;
    LQ.ParamByName('v').AsString := APkg.Version;
    LQ.ParamByName('y').AsString := APkg.Author;
    LQ.ParamByName('a').AsBoolean := APkg.Active;
    LQ.ParamByName('p').AsBoolean := APkg.IsProtected;
    LQ.ParamByName('s').AsInteger := APkg.Order;
    if APkg.Id = 0 then LQ.ParamByName('c').AsDateTime := LNow;
    LQ.ParamByName('m').AsDateTime := LNow;
    LQ.ExecSQL;
  finally
    LQ.Free;
  end;
  APkg.Modified := LNow;
  if APkg.Id = 0 then
    APkg.Id := FindPackageId(APkg.Code);
end;

procedure TRadUniScriptStore.SyncScripts(APkg: TRadScriptPackage);
var
  LIds: TDictionary<string, Integer>;
  S: TRadScript;
  LQ: TUniQuery;
  LId: Integer;
  LNow: TDateTime;
begin
  LNow := Now;
  LIds := ExistingChildIds(TRadScriptDdl.ScriptTable, 'kod', APkg.Id);
  try
    for S in APkg.Scripts do
    begin
      if LIds.TryGetValue(LowerCase(S.Code), LId) then
      begin
        LIds.Remove(LowerCase(S.Code));
        LQ := Q(Format('update %s set kod = :k, adi = :n, tur = :t, hedef = :h, sira = :s, aktif_mi = :a, ' +
          'kaynak = :src, degisim_zamani = :m where id = :id', [TRadScriptDdl.ScriptTable]));
      end
      else
      begin
        LId := 0;
        LQ := Q(Format('insert into %s (paket_id, kod, adi, tur, hedef, sira, aktif_mi, kaynak, degisim_zamani) ' +
          'values (:p, :k, :n, :t, :h, :s, :a, :src, :m)', [TRadScriptDdl.ScriptTable]));
      end;
      try
        if LId = 0 then LQ.ParamByName('p').AsInteger := APkg.Id
        else LQ.ParamByName('id').AsInteger := LId;
        LQ.ParamByName('k').AsString := S.Code;
        LQ.ParamByName('n').AsString := S.Name;
        LQ.ParamByName('t').AsString := S.KindCode;
        LQ.ParamByName('h').AsString := S.Target;
        LQ.ParamByName('s').AsInteger := S.Order;
        LQ.ParamByName('a').AsBoolean := S.Active;
        LQ.ParamByName('src').DataType := ftWideMemo;
        LQ.ParamByName('src').AsString := S.Source;
        LQ.ParamByName('m').AsDateTime := LNow;
        LQ.ExecSQL;
      finally
        LQ.Free;
      end;
      if LId = 0 then LId := FetchChildId(TRadScriptDdl.ScriptTable, 'kod', APkg.Id, S.Code);
      S.Id := LId;
      S.PackageId := APkg.Id;
      S.Modified := LNow;
    end;
    DeleteRemaining(TRadScriptDdl.ScriptTable, LIds);
  finally
    LIds.Free;
  end;
end;

procedure TRadUniScriptStore.SyncParams(APkg: TRadScriptPackage);
var
  LIds: TDictionary<string, Integer>;
  P: TRadScriptParam;
  LQ: TUniQuery;
  LId: Integer;
begin
  LIds := ExistingChildIds(TRadScriptDdl.ParamTable, 'adi', APkg.Id);
  try
    for P in APkg.Params do
    begin
      if LIds.TryGetValue(LowerCase(P.Name), LId) then
      begin
        LIds.Remove(LowerCase(P.Name));
        LQ := Q(Format('update %s set adi = :n, deger = :v, aciklama = :d where id = :id', [TRadScriptDdl.ParamTable]));
      end
      else
      begin
        LId := 0;
        LQ := Q(Format('insert into %s (paket_id, adi, deger, aciklama) values (:p, :n, :v, :d)', [TRadScriptDdl.ParamTable]));
      end;
      try
        if LId = 0 then LQ.ParamByName('p').AsInteger := APkg.Id
        else LQ.ParamByName('id').AsInteger := LId;
        LQ.ParamByName('n').AsString := P.Name;
        LQ.ParamByName('v').AsString := P.Value;
        LQ.ParamByName('d').AsString := P.Description;
        LQ.ExecSQL;
      finally
        LQ.Free;
      end;
      if LId = 0 then LId := FetchChildId(TRadScriptDdl.ParamTable, 'adi', APkg.Id, P.Name);
      P.Id := LId;
    end;
    DeleteRemaining(TRadScriptDdl.ParamTable, LIds);
  finally
    LIds.Free;
  end;
end;

procedure TRadUniScriptStore.SyncDbSteps(APkg: TRadScriptPackage);
var
  LIds: TDictionary<string, Integer>;
  D: TRadScriptDbStep;
  LQ: TUniQuery;
  LId: Integer;
  LKey: string;
begin
  LIds := ExistingChildIds(TRadScriptDdl.DbTable, 'sira', APkg.Id);
  try
    for D in APkg.DbSteps do
    begin
      LKey := IntToStr(D.Order);
      if LIds.TryGetValue(LKey, LId) then
      begin
        LIds.Remove(LKey);
        // uygulandi_mi/uygulama_zamani'na dokunulmaz: uygulanmış adım yeniden koşmaz.
        LQ := Q(Format('update %s set aciklama = :d, sql_metni = :q where id = :id', [TRadScriptDdl.DbTable]));
      end
      else
      begin
        LId := 0;
        LQ := Q(Format('insert into %s (paket_id, sira, aciklama, sql_metni, uygulandi_mi) values (:p, :s, :d, :q, :u)',
          [TRadScriptDdl.DbTable]));
      end;
      try
        if LId = 0 then
        begin
          LQ.ParamByName('p').AsInteger := APkg.Id;
          LQ.ParamByName('s').AsInteger := D.Order;
          LQ.ParamByName('u').AsBoolean := False;
        end
        else
          LQ.ParamByName('id').AsInteger := LId;
        LQ.ParamByName('d').AsString := D.Description;
        LQ.ParamByName('q').DataType := ftWideMemo;
        LQ.ParamByName('q').AsString := D.Sql;
        LQ.ExecSQL;
      finally
        LQ.Free;
      end;
      if LId = 0 then LId := FetchChildId(TRadScriptDdl.DbTable, 'sira', APkg.Id, D.Order);
      D.Id := LId;
    end;
    DeleteRemaining(TRadScriptDdl.DbTable, LIds);
  finally
    LIds.Free;
  end;
end;

procedure TRadUniScriptStore.SyncResources(APkg: TRadScriptPackage);
var
  LIds: TDictionary<string, Integer>;
  R: TRadScriptResource;
  LQ: TUniQuery;
  LId: Integer;
  LStream: TBytesStream;
begin
  LIds := ExistingChildIds(TRadScriptDdl.ResourceTable, 'dosya_adi', APkg.Id);
  try
    for R in APkg.Resources do
    begin
      if LIds.TryGetValue(LowerCase(R.FileName), LId) then
      begin
        LIds.Remove(LowerCase(R.FileName));
        LQ := Q(Format('update %s set dosya_adi = :n, icerik = :i where id = :id', [TRadScriptDdl.ResourceTable]));
      end
      else
      begin
        LId := 0;
        LQ := Q(Format('insert into %s (paket_id, dosya_adi, icerik) values (:p, :n, :i)', [TRadScriptDdl.ResourceTable]));
      end;
      LStream := TBytesStream.Create(R.Content);
      try
        if LId = 0 then LQ.ParamByName('p').AsInteger := APkg.Id
        else LQ.ParamByName('id').AsInteger := LId;
        LQ.ParamByName('n').AsString := R.FileName;
        LStream.Position := 0;
        LQ.ParamByName('i').LoadFromStream(LStream, ftBlob);
        LQ.ExecSQL;
      finally
        LStream.Free;
        LQ.Free;
      end;
      if LId = 0 then LId := FetchChildId(TRadScriptDdl.ResourceTable, 'dosya_adi', APkg.Id, R.FileName);
      R.Id := LId;
    end;
    DeleteRemaining(TRadScriptDdl.ResourceTable, LIds);
  finally
    LIds.Free;
  end;
end;

procedure TRadUniScriptStore.SavePackage(APkg: TRadScriptPackage);
var
  LErr: string;
begin
  LErr := APkg.Validate;
  if LErr <> '' then
    raise ERadScript.Create(LErr);
  InTransaction(
    procedure
    begin
      WritePackageRow(APkg);
      SyncScripts(APkg);
      SyncParams(APkg);
      SyncDbSteps(APkg);
      SyncResources(APkg);
    end);
end;

procedure TRadUniScriptStore.ImportPackage(APkg: TRadScriptPackage);
var
  LExisting: TRadScriptPackage;
  P, E: TRadScriptParam;
begin
  LExisting := LoadPackage(APkg.Code);
  try
    if LExisting <> nil then
      for P in APkg.Params do
      begin
        E := LExisting.ParamByName(P.Name);
        if E <> nil then P.Value := E.Value;   // kurulum ayarı dosyadakini ezer
      end;
    SavePackage(APkg);
  finally
    LExisting.Free;
  end;
end;

procedure TRadUniScriptStore.DeletePackage(const ACode: string);
var
  LQ: TUniQuery;
begin
  LQ := Q(Format('delete from %s where kod = :k', [TRadScriptDdl.PackageTable]));
  try
    LQ.ParamByName('k').AsString := ACode;
    LQ.ExecSQL;
  finally
    LQ.Free;
  end;
end;

function TRadUniScriptStore.ScriptsFor(AKind: TRadScriptKind; const ATarget: string): TRadScripts;
var
  LQ: TUniQuery;
  S: TRadScript;
begin
  Result := TRadScripts.Create(True);
  try
    LQ := Q(Format('select s.* from %s s join %s p on p.id = s.paket_id ' +
      'where s.tur = :t and upper(s.hedef) = upper(:h) and s.aktif_mi = :a and p.aktif_mi = :b ' +
      'order by p.sira, s.sira, s.id', [TRadScriptDdl.ScriptTable, TRadScriptDdl.PackageTable]));
    try
      LQ.ParamByName('t').AsString := TRadScript.KindCodeOf(AKind);
      LQ.ParamByName('h').AsString := ATarget;
      LQ.ParamByName('a').AsBoolean := True;
      LQ.ParamByName('b').AsBoolean := True;
      LQ.Open;
      while not LQ.Eof do
      begin
        S := TRadScript.Create;
        Result.Add(S);
        ReadScript(LQ, S);
        LQ.Next;
      end;
    finally
      LQ.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TRadUniScriptStore.ApplyPendingDbSteps(APkg: TRadScriptPackage);
type
  TStep = record Id, Order: Integer; Sql: string; end;
var
  LQ: TUniQuery;
  LSteps: TList<TStep>;
  LStep: TStep;
  D: TRadScriptDbStep;
  LNow: TDateTime;
begin
  LSteps := TList<TStep>.Create;
  try
    LQ := Q(Format('select id, sira, sql_metni from %s where paket_id = :p and uygulandi_mi = :u order by sira',
      [TRadScriptDdl.DbTable]));
    try
      LQ.ParamByName('p').AsInteger := APkg.Id;
      LQ.ParamByName('u').AsBoolean := False;
      LQ.Open;
      while not LQ.Eof do
      begin
        LStep.Id := LQ.Fields[0].AsInteger;
        LStep.Order := LQ.Fields[1].AsInteger;
        LStep.Sql := MemoText(LQ.Fields[2]);
        LSteps.Add(LStep);
        LQ.Next;
      end;
    finally
      LQ.Free;
    end;
    for LStep in LSteps do
    begin
      try
        Exec(LStep.Sql);
      except
        on E: Exception do
          raise ERadScript.CreateFmt('"%s" paketi DB adımı %d: %s', [APkg.Code, LStep.Order, E.Message]);
      end;
      LNow := Now;
      LQ := Q(Format('update %s set uygulandi_mi = :u, uygulama_zamani = :z where id = :id', [TRadScriptDdl.DbTable]));
      try
        LQ.ParamByName('u').AsBoolean := True;
        LQ.ParamByName('z').AsDateTime := LNow;
        LQ.ParamByName('id').AsInteger := LStep.Id;
        LQ.ExecSQL;
      finally
        LQ.Free;
      end;
      for D in APkg.DbSteps do
        if D.Order = LStep.Order then
        begin
          D.Applied := True;
          D.AppliedAt := LNow;
        end;
    end;
  finally
    LSteps.Free;
  end;
end;

function TRadUniScriptStore.LibrariesOf(const APackageIds: TArray<Integer>): TRadScripts;
var
  LQ: TUniQuery;
  LIds: string;
  i: Integer;
  S: TRadScript;
begin
  Result := TRadScripts.Create(True);
  if Length(APackageIds) = 0 then Exit;
  try
    LIds := '';
    for i := 0 to High(APackageIds) do   // tamsayı: IN listesi güvenli
      LIds := LIds + IfThen(i > 0, ',', '') + IntToStr(APackageIds[i]);
    LQ := Q(Format('select * from %s where tur in (:t, :w) and aktif_mi = :a and paket_id in (%s) order by paket_id, sira, id',
      [TRadScriptDdl.ScriptTable, LIds]));
    try
      LQ.ParamByName('t').AsString := TRadScript.KindCodeOf(skLibrary);
      LQ.ParamByName('w').AsString := TRadScript.KindCodeOf(skWindow);
      LQ.ParamByName('a').AsBoolean := True;
      LQ.Open;
      while not LQ.Eof do
      begin
        S := TRadScript.Create;
        Result.Add(S);
        ReadScript(LQ, S);
        LQ.Next;
      end;
    finally
      LQ.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TRadUniScriptStore.ResourcesNamed(const AFileName: string): TObjectList<TRadScriptResource>;
var
  LQ: TUniQuery;
  R: TRadScriptResource;
begin
  Result := TObjectList<TRadScriptResource>.Create(True);
  try
    LQ := Q(Format('select k.id, k.paket_id, k.dosya_adi, k.icerik from %s k join %s p on p.id = k.paket_id ' +
      'where k.dosya_adi = :n and p.aktif_mi = :a order by p.sira, p.id', [TRadScriptDdl.ResourceTable, TRadScriptDdl.PackageTable]));
    try
      LQ.ParamByName('n').AsString := AFileName;
      LQ.ParamByName('a').AsBoolean := True;
      LQ.Open;
      while not LQ.Eof do
      begin
        R := TRadScriptResource.Create;
        Result.Add(R);
        R.Id := LQ.FieldByName('id').AsInteger;
        R.PackageId := LQ.FieldByName('paket_id').AsInteger;
        R.FileName := LQ.FieldByName('dosya_adi').AsString;
        R.Content := LQ.FieldByName('icerik').AsBytes;
        LQ.Next;
      end;
    finally
      LQ.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TRadUniScriptStore.ParamsOf(const APackageIds: TArray<Integer>): TObjectList<TRadScriptParam>;
var
  LQ: TUniQuery;
  LIds: string;
  i: Integer;
  P: TRadScriptParam;
begin
  Result := TObjectList<TRadScriptParam>.Create(True);
  if Length(APackageIds) = 0 then Exit;
  try
    LIds := '';
    for i := 0 to High(APackageIds) do
      LIds := LIds + IfThen(i > 0, ',', '') + IntToStr(APackageIds[i]);
    LQ := Q(Format('select * from %s where paket_id in (%s) order by paket_id, adi', [TRadScriptDdl.ParamTable, LIds]));
    try
      LQ.Open;
      while not LQ.Eof do
      begin
        P := TRadScriptParam.Create;
        Result.Add(P);
        P.Id := LQ.FieldByName('id').AsInteger;
        P.Name := LQ.FieldByName('adi').AsString;
        P.Value := LQ.FieldByName('deger').AsString;
        P.Description := LQ.FieldByName('aciklama').AsString;
        LQ.Next;
      end;
    finally
      LQ.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TRadUniScriptStore.LoadResource(APackageId: Integer; const AFileName: string; AStream: TStream): Boolean;
var
  LQ: TUniQuery;
begin
  LQ := Q(Format('select icerik from %s where paket_id = :p and dosya_adi = :n', [TRadScriptDdl.ResourceTable]));
  try
    LQ.ParamByName('p').AsInteger := APackageId;
    LQ.ParamByName('n').AsString := AFileName;
    LQ.Open;
    Result := not LQ.Eof;
    if Result and not LQ.Fields[0].IsNull then
      TBlobField(LQ.Fields[0]).SaveToStream(AStream);
  finally
    LQ.Free;
  end;
end;

end.
