unit Help.uni;

interface

uses System.Classes, System.SysUtils,Data.DB,System.JSON, Uni, MemDS, VirtualTable,
SqlTimSt,Help.DB,System.Rtti,DBAccess
,DASQLGenerator,CRAccess,SqlClassesUni
,DAScript, UniScript,Variants
,mormot.db.core
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
    function _DBType:TSqlDBDefinition;
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


    function _ConnectTest(const AConnectionString:string=''):Boolean;


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


 const
  UNIDAC_PROVIDER: array[TSqlDBDefinition.dOracle..high(TSqlDBDefinition)] of string = (
    'Oracle', 'SQL Server', 'Access', 'MySQL', 'SQLite', 'InterBase',
    'NexusDB', 'PostgreSQL', 'DB2', '', 'MySQL');
implementation
  uses
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

Function TUniConnectionHelper._ConnectTest(const AConnectionString:string=''): Boolean;

var
 AResult:Boolean;
 TempStr:string;
Begin
 AResult:=False;
 TempStr:=ConnectString;
 try
   if not AConnectionString.IsEmpty then ConnectString:=AConnectionString;
   if ProviderName.IsEmpty or Server.IsEmpty or Username.IsEmpty or Password.IsEmpty  then
  Exit;

  {$IFDEF MSWINDOWS}
     //WaitProc( Procedure Begin AResult:=Test(ConnectString); End , True, True );
  {$ELSE}
     AResult:=Test;
  {$ENDIF}


 finally
    ConnectString:=TempStr;
    Result:=AResult;
 end;

End;


function TUniConnectionHelper._ServerDate: TDateTime;
begin
  case _DBType of
    TSqlDBDefinition.dMSSQL: Result := _sqlResults('SELECT GETDATE() AS dt', Now, 'dt');
    TSqlDBDefinition.dPostgreSQL: Result := _sqlResults('SELECT NOW() AS dt', Now, 'dt');
    TSqlDBDefinition.dSQLite: Result := _sqlResults('SELECT datetime(''now'') AS dt', Now,'dt');
    TSqlDBDefinition.dOracle: Result := _sqlResults('SELECT SYSDATE AS dt FROM DUAL', Now,'dt');
  else
    Result := Now;
  end;
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


function TUniConnectionHelper._DBType:TSqlDBDefinition ;
begin
    for Result := Low(UNIDAC_PROVIDER) to high(UNIDAC_PROVIDER) do
    if SameText(UNIDAC_PROVIDER[Result], ProviderName) then
    begin
      exit;
    end;
  Result := TSqlDBDefinition.dUnknown;

end;

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
    // Ana baðlantýnýn tüm kritik ayarlarýný kopyala
    Result.ProviderName := Self.ProviderName;
    Result.ConnectString := Self.ConnectString;
    Result.LoginPrompt := False;

    // Pooling ayarlarý (Bunlar ana baðlantýdan da okunabilir)
    Result.PoolingOptions.MaxPoolSize := 100; // Ýhtiyaca göre artýrýlabilir
    Result.PoolingOptions.MinPoolSize := 5;
    Result.PoolingOptions.ConnectionLifetime := 60; // Saniye cinsinden
    Result.Pooling := True;
    Result.SpecificOptions.Values['Pooling'] := 'True';
    // ÖNEMLÝ: Burada Connect demiyoruz, sadece nesneyi hazýrlýyoruz.
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

  // Yeni bir baðlantý nesnesi oluþtur (Zarf)
  cn := _NewConnection;
  try
    try
      // Connect çaðrýsý Pooling=True olduðu için
      // fiziksel baðlantý açmaz, POOL'dan boþta olaný alýr.
      cn.Connect;

      // Ýþlemi thread-safe olarak çalýþtýr
      AProc(cn);

    finally
      // Disconnect çaðrýsý fiziksel baðlantýyý kapatmaz,
      // POOL'a "benim iþim bitti, baþkasý kullanabilir" diye iade eder.
      if cn.Connected then
        cn.Disconnect;
    end;
  finally
    // Nesneyi serbest býrakýyoruz.
    // Pooling aktif olduðu için fiziksel socket açýk kalýr ve pool'da bekler.
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
 //Assert(not Self.Active,'Dataset Kapalý');
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
  Result := Null;
  LKeyField := Self.KeyFields; // ID alanýn (UUID/LUID)

  if LKeyField.IsEmpty then Exit;
  LCurrentID := Self.FieldByName(LKeyField).Value;
  if VarIsNull(LCurrentID) then Exit;

  // Yön ve Operatör Belirleme
  case AGetID of
    0: begin LOperator := 'IS NOT NULL'; LOrderDir := 'ASC';  end; // Ýlk
    1: begin LOperator := 'IS NOT NULL'; LOrderDir := 'DESC'; end; // Son
    2: begin LOperator := '> :ID';       LOrderDir := 'ASC';  end; // Sonraki
    3: begin LOperator := '< :ID';       LOrderDir := 'DESC'; end; // Önceki
  else Exit;
  end;

  LQuery := _AsUni._CreateQuery;
  try
    // DB Tipine göre SQL (PostgreSQL için LIMIT 1, MSSQL için TOP 1)
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

end.
