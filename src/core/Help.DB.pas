unit Help.DB;

interface

uses System.Classes, System.SysUtils, Data.DB, SqlTimSt,
     mormot.core.base, mormot.core.unicode;

type


  TBooleanFieldType = (bfUnknown, bfBoolean, bfInteger);
  TDataSetFieldType = (dfUnknown, dfJSONObject, dfJSONArray);

  TDBFieldAttr = class(TCustomAttribute)
  private
    fName : string;
    //FValue: Variant;
  public
    constructor Create(const aName: string);
    property Name : string read fName;
    //property DefaultValue:Variant read FValue;
  end;

TDbClass = class
  strict private
    FDataSet: TDataSet;
    // Index bazl� Field referanslar�n� cache'lemek i�in
    FFieldCache: array of TField;
    FIsMapped: Boolean;

    procedure MapFields;
    procedure SetDataset(const Value: TDataSet);
  protected
    // Alt s�n�flar dataset de�i�ti�inde haberdar olabilir
    procedure OnDataSetChanged; virtual;
  public
    constructor Create(const aDataSet: TDataSet); virtual;

    // Index bazl� h�zl� eri�im
    function GetVar(const Index: Integer): Variant; virtual;
    procedure SetVar(const Index: Integer; const Value: Variant); virtual;

    // Yard�mc� metodlar


    property Data: TDataSet read FDataSet write SetDataset;
  end;


{$REGION 'Dataset Helper'}

  TDataSetHelper = class helper for TDataSet
  private
    function GetString(FieldName: String): String;
    procedure SetString(FieldName: String; const Value: String);
    function GetInteger(FieldName: String): Integer;
    procedure SetInteger(FieldName: String; const Value: Integer);
    function GetBoolean(FieldName: String): Boolean;
    procedure SetBoolean(FieldName: String; const Value: Boolean);
    function GetExtended(FieldName: String): Extended;
    procedure SetExtended(FieldName: String; const Value: Extended);
    function GetDateTime(FieldName: String): TDateTime;
    procedure SetDateTime(FieldName: String; const Value: TDateTime);
    function GetVariant(FieldName: String): Variant;
    procedure SetVariant(FieldName: String; const Value: Variant);

  public
    // normaller
    function _Close:TDataSet;
    function _Open:TDataSet;
    function _DisableControls:TDataSet;
    function _EnableControls:TDataSet;
    function _Insert:TDataSet;
    function _Append:TDataSet;
    function _Post:TDataSet;
    function _Edit:TDataSet;
    procedure _Bookmark(AProc:TProc<TDataset>;var AGoto:Boolean);
    function  _Value(const AFieldName:string; AValue:Variant;const AIIF:Boolean=true):TDataSet;
    function _Values:TArray<Variant>;overload;
    function _Values(const AFields:TArray<string>):TArray<Variant>;overload;
    //function _ToList(const AFiedName:string):TDataSet;

    function _WTry(const AFieldName:string; const AProc:TProc<TField>):TDataSet;overload;

    function _W(const AFieldName:string;const V:string;const AIIF:Boolean=true):TDataSet; overload;
    function _W(const AFieldName:string;const V:Integer;const AIIF:Boolean=true):TDataSet;overload;
    function _W(const AFieldName:string;const V:Boolean;const AIIF:Boolean=true):TDataSet;overload;
    function _W(const AFieldName:string;const V:Variant;const AIIF:Boolean=true):TDataSet;overload;
    function _W(const AFieldName:string;const V:TStream;const AIIF:Boolean=true):TDataSet;overload;


    function _WDt(const AFieldName:string):TDataSet;overload;
    function _WDt(const AFieldName:string;const V:TDateTime;const AIIF:Boolean=true):TDataSet;overload;
    Function _F(Const FieldName: String): TField;


    function _LoadValueALL(const ADataSet:TDataSet; const ADisable:TArray<string>=[];const ABeforePost:TProc<TDataSet>=nil):TDataSet;overload;
    function _LoadValue(const ADataSet:TDataSet; const ADisable:TArray<string>=[]):TDataSet;overload;
    function _LoadValue(const ADataSet:TDataSet; const AFieldName:array of string;const ASourceFieldName:array of string):TDataSet;overload;

    property _D[FieldName: String]: Extended Read GetExtended Write SetExtended;
    property _DT[FieldName: String]: TDateTime Read GetDateTime Write SetDateTime;
    property _S[FieldName: String]: String Read GetString Write SetString;
    property _I[FieldName: String]: Integer Read GetInteger Write SetInteger;
    property _B[FieldName: String]: Boolean Read GetBoolean Write SetBoolean;
    property _V[FieldName: String]: Variant Read GetVariant Write SetVariant;

    function _EofField(AProc:TProc<TField>;const ADisable:TArray<string>=[]):TDataSet;
    function _DoEof(AProc:TProc<TDataset>; Var Cancel: Boolean; SavePosition: Boolean = False):TDataSet; overload;
    function _DoEof(AProc:TProc<TDataset>; SavePosition: Boolean = False):TDataSet; overload;
    function _DoEof(AProc:TProc; SavePosition: Boolean = False):TDataSet; overload;
    function _DoEofAndClose(AProc:TProc<TDataset>):TDataSet; overload;

    Function _IsEditOrInsert: Boolean;
    Function _IsChangeField(Const AField: String): Boolean; Overload;
    Function _IsChangeField(Const AField: TArray<String>): Boolean; Overload;
    Function _AddField(Const fieldName: String; Const fieldType: TFieldType; Const
      size: Integer = 0; Const origin: String = ''; Const displaylabel: String = ''):
      TField;
    Procedure _ReOpen;

    function _Locate(const KeyFields:string; const KeyValues:Variant; Options:Data.TLocateOptions=[]):Boolean;


    function _toAs<T:class>:T;

    function _ToJSONArray: RawUtf8;
    function _ToJSONArrayALL: RawUtf8;
    function _ToJSONArrayALLStr: string;
    function _ToJSONObject(const ADisableField: TArray<string> = []): RawUtf8;
    function _ToJSONObjectStr(const AJsonStr: Boolean = true; const ADisableField: TArray<string> = []): string;
    function _ToJSONStructure: RawUtf8;

    procedure _FromJsonArray(const AJson: RawUtf8; const isRecord: Boolean);
    procedure _FromJson(const AJson: RawUtf8; const ArecNo: Integer; const isRecord: Boolean); overload;
    procedure _FromJson(const AJson: RawUtf8); overload;
    procedure _FromJsonStr(const AJson: string);

  end;
{$ENDREGION}

 {$REGION ' TField Helper'}
   TFieldsHelper = class helper for TField
    public
      function _IsChange: Boolean;
      function _GetType<T: class>: T;
      function _SaveToFile(const AFileName: string): Boolean;
      function _LoadToFile(const AFileName: string): Boolean;
      function _SqlStr(const AInc: Integer = 0): string;
    end;
 {$ENDREGION}

   TSQLTimeStampHelp = record helper for TSQLTimeStamp
     function AsString:string;
     procedure SetDateToTimeStamp(const dt:TDateTime);
   end;


    function BooleanFieldToType(const booleanField: TBooleanField): TBooleanFieldType;
    function DataSetFieldToType(const dataSetField: TDataSetField): TDataSetFieldType;
    function FieldToSqlStr(const ADataType: TFieldType; const v1: Variant; const AInc: Integer = 0): string;

implementation
  uses
   ZLib, System.Variants,
  System.StrUtils, System.Rtti, System.Math, System.TypInfo, FmtBcd,
  mormot.core.text, mormot.core.json, mormot.core.datetime,
  mormot.core.variants, mormot.core.buffers;


   function FieldToSqlStr(const ADataType:TFieldType; const v1:Variant;const AInc:Integer=0):string;
     begin

          if ADataType in [ftString,ftMemo,ftFixedChar,ftWideString,ftFixedWideChar,ftWideMemo] then
           begin
              Result:=QuotedStr(VarToStr(v1));
           end else if ADataType in [ftDate,ftDateTime] then
           begin
               var ATimeStamp:=VarToSQLTimeStamp(v1);
                ATimeStamp.Day:=ATimeStamp.Day+AInc;
                if ADataType = ftDate then
                Result:=QuotedStr(SQLTimeStampToStr('yyyy-mm-dd',ATimeStamp))
                else
                Result:=QuotedStr(SQLTimeStampToStr('yyyy-mm-dd hh:nn:ss',ATimeStamp));
           end else if ADataType in [ftSmallint, ftInteger, ftWord,ftLargeint] then
           begin
               Result:=VarToStr(v1);
           end else if ADataType in [TFieldType.ftSingle, TFieldType.ftFloat] then
           begin
               Result:=VarToStr(v1).Replace(',','.');
           end;
     end;


{ ── mORMot2 destekli JSON yardımcıları ────────────────────────────────────── }

// Bir field değerini W'ye yazar. Tüm JSON generation buradan geçer.
procedure WriteFieldJson(W: TJsonWriter; AField: TField);
var
  bft: TBooleanFieldType;
  dft: TDataSetFieldType;
  ts : TSQLTimeStamp;
  ms : TMemoryStream;
  dt : TDateTime;
  raw: RawByteString;
begin
  if AField.IsNull then
  begin
    case AField.DataType of
      ftString, ftWideString, ftMemo, ftWideMemo: W.AddDirect('"', '"');
      else W.AddNull;
    end;
    Exit;
  end;
  case AField.DataType of
    ftLargeint, ftAutoInc: W.Add(AField.AsLargeInt);
    ftFloat, TFieldType.ftSingle: W.AddDouble(AField.AsFloat);
    ftFMTBcd, ftBCD:
      W.AddDouble(BcdToDouble(AField.AsBcd));
    ftBoolean:
    begin
      bft := BooleanFieldToType(TBooleanField(AField));
      if bft = bfInteger then W.Add(AField.AsInteger)
      else W.Add(AField.AsBoolean);
    end;
    ftInteger, ftSmallint, ftShortint, ftLongWord:
      W.Add(AField.AsInteger);
    ftCurrency:
      W.AddCurr(AField.AsCurrency);
    ftString, ftWideString, ftMemo, ftWideMemo:
      W.AddJsonEscapeString(AField.AsWideString.Trim);
    ftDate:
    begin
      dt := AField.AsDateTime;
      W.AddDirect('"');
      W.AddDateTime(dt, {WithMS=}False);
      W.AddDirect('"');
    end;
    ftTimeStamp, ftDateTime:
    begin
      dt := AField.AsDateTime;
      W.AddDirect('"');
      W.AddDateTime(dt, {WithMS=}False);
      W.AddDirect('"');
    end;
    ftTime:
    begin
      ts := AField.AsSQLTimeStamp;
      W.AddJsonString(StringToUtf8(SQLTimeStampToStr('hh:nn:ss', ts)));
    end;
    ftDataSet:
    begin
      dft := DataSetFieldToType(TDataSetField(AField));
      var nestedDS := TDataSetField(AField).NestedDataSet;
      case dft of
        dfJSONObject: W.AddString(nestedDS._ToJSONObject);
        dfJSONArray:  W.AddString(nestedDS._ToJSONArrayALL);
      else
        W.AddNull;
      end;
    end;
    ftGraphic, ftBlob, ftStream:
    begin
      ms := TMemoryStream.Create;
      try
        TBlobField(AField).SaveToStream(ms);
        SetLength(raw, ms.Size);
        if ms.Size > 0 then
          Move(ms.Memory^, pointer(raw)^, ms.Size);
        W.AddJsonString(BinToBase64(raw));
      finally
        ms.Free;
      end;
    end;
  else
    W.AddNull;
  end;
end;

// JSON string'teki bir değeri ilgili field tipine dönüştürür.
procedure SetFieldFromJsonValue(AField: TField; const S: string; IsNull: Boolean);
var
  ms : TMemoryStream;
  raw: RawByteString;
begin
  if IsNull then begin AField.Clear; Exit; end;
  case AField.DataType of
    ftBoolean:  AField.AsBoolean  := StrToBoolDef(S, False);
    ftInteger, ftSmallint, ftShortint, ftLongWord:
                AField.AsInteger  := StrToIntDef(S, 0);
    ftLargeint, ftAutoInc:
                AField.AsLargeInt := StrToInt64Def(S, 0);
    ftCurrency: AField.AsCurrency := StrToCurrDef(S, 0);
    ftFloat, ftFMTBcd, ftBCD, TFieldType.ftSingle:
                AField.AsFloat    := Iso8601ToDateTime(StringToUtf8(S));
    ftString, ftWideString, ftMemo, ftWideMemo:
                AField.AsString   := S;
    ftDate, ftTimeStamp, ftDateTime:
                AField.AsDateTime := Iso8601ToDateTime(StringToUtf8(S));
    ftTime:
    begin
      var t := StringToUtf8(S);
      AField.AsDateTime := Iso8601ToDateTime(t);
    end;
    ftGraphic, ftBlob, ftStream:
    begin
      raw := Base64ToBin(StringToUtf8(S));
      ms  := TMemoryStream.Create;
      try
        ms.WriteBuffer(pointer(raw)^, Length(raw));
        ms.Position := 0;
        TBlobField(AField).LoadFromStream(ms);
      finally
        ms.Free;
      end;
    end;
  end;
end;

function BooleanFieldToType(const booleanField: TBooleanField): TBooleanFieldType;
const
  DESC_BOOLEAN_FIELD_TYPE: array [TBooleanFieldType] of string = ('Unknown', 'Boolean', 'Integer');
var
  index: Integer;
  origin: string;
begin
  Result := bfUnknown;
  origin := Trim(booleanField.Origin);
  for index := Ord(Low(TBooleanFieldType)) to Ord(High(TBooleanFieldType)) do
    if (LowerCase(DESC_BOOLEAN_FIELD_TYPE[TBooleanFieldType(index)]) = LowerCase(origin)) then
      Exit(TBooleanFieldType(index));
end;

function DataSetFieldToType(const dataSetField: TDataSetField): TDataSetFieldType;
const
  DESC_DATASET_FIELD_TYPE: array [TDataSetFieldType] of string = ('Unknown', 'JSONObject', 'JSONArray');
var
  index: Integer;
  origin: string;
begin
  Result := dfUnknown;
  origin := Trim(dataSetField.Origin);
  for index := Ord(Low(TDataSetFieldType)) to Ord(High(TDataSetFieldType)) do
    if (LowerCase(DESC_DATASET_FIELD_TYPE[TDataSetFieldType(index)]) = LowerCase(origin)) then
      Exit(TDataSetFieldType(index));
end;

function MakeValidIdent(const s: string): string;
var
  x: Integer;
  c: Char;
begin
  SetLength(Result, Length(s));
  x := 0;

  for c in s do
  begin
    if CharInSet(c, ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
    begin
      Inc(x);
      Result[x] := c;
    end;
  end;

  SetLength(Result, x);

  if x = 0 then
    Result := '_'
  else if CharInSet(Result[1], ['0'..'9']) then
    Result := '_' + Result;
end;


{$REGION 'TDataSetelper'}


function TDataSetHelper._AddField(const fieldName: string;
  const fieldType: TFieldType; const size: Integer; const origin,
  displaylabel: string): TField;
begin
  Result := DefaultFieldClasses[fieldType].Create(Self);
  Result.FieldName := fieldName;

  if (Result.FieldName = '') then
    Result.FieldName := 'Field' + IntToStr(Self.FieldCount + 1);

  Result.FieldKind := fkData;
  Result.DataSet := Self;
  Result.Name := MakeValidIdent(Self.Name + Result.FieldName);
  Result.Size := size;
  Result.Origin := origin;
  if not(displaylabel.IsEmpty) then
    Result.DisplayLabel := displaylabel;

  if (fieldType in [ftString, ftWideString]) and (size <= 0) then
    raise Exception.CreateFmt('Size not defined for field "%s".', [fieldName]);
end;

function TDataSetHelper._Append: TDataSet;
begin
Append;
Result:=Self;
end;

procedure TDataSetHelper._Bookmark(AProc: TProc<TDataset>;var AGoto:Boolean);
var
  bookMark: TBookmark;
begin
  AGoto := False;
  DisableControls;
  try
    bookMark := Self.Bookmark;
    AProc(Self);
    if AGoto and BookmarkValid(bookMark) then
      GotoBookmark(bookMark);
    FreeBookmark(bookMark);
  finally
    EnableControls;
  end;
end;

function TDataSetHelper._Close: TDataSet;
begin
 Self.Close;
 Result:=Self;
end;

function TDataSetHelper._DisableControls: TDataSet;
begin
DisableControls;
Result:=Self;
end;

function TDataSetHelper._DoEof(AProc:TProc<TDataset>; var Cancel: Boolean; SavePosition: Boolean):TDataSet;
var
  LBookmark: TBookmark;
begin
  Result := Self;
  if not Assigned(AProc) or IsEmpty then Exit;

  DisableControls;
  Self._Post;
  try
    LBookmark := nil;
    if SavePosition then
      LBookmark := GetBookmark;
    try
      First;
      while not Eof do
      begin
        AProc(Self);
        if Cancel then  Break;
        Next;
      end;
    finally
      if Assigned(LBookmark) then
      begin
        if BookmarkValid(LBookmark) then
          GotoBookmark(LBookmark);
        FreeBookmark(LBookmark);
      end;
    end;
  finally
    EnableControls;
  end;


end;

function TDataSetHelper._DoEof(AProc:TProc<TDataset>; SavePosition: Boolean):TDataSet;
var
  Aiptal: Boolean;
begin
  Aiptal := false;
  Result:= Self._DoEof(AProc, Aiptal, SavePosition)
end;

function TDataSetHelper._DoEof(AProc:TProc; SavePosition: Boolean):TDataSet;
var
  Aiptal: Boolean;
begin
  Aiptal := false;
  Result:= Self._DoEof(procedure( ds:TDataSet) begin AProc(); end , Aiptal, SavePosition)

end;

function TDataSetHelper._DoEofAndClose(AProc:TProc<TDataset>):TDataSet;
begin
  Result:=Self;
  Self.Open;
  try
    Self._DoEof(AProc);
  finally
    Self.Close;
  end;

end;





function TDataSetHelper._Edit: TDataSet;
begin
if (not _IsEditOrInsert) and (RecordCount > 0) then
Self.Edit;
Result:=Self;
end;

function TDataSetHelper._EnableControls: TDataSet;
begin
EnableControls;
Result:=Self;
end;

function TDataSetHelper._EofField(AProc: TProc<TField>;const ADisable:TArray<string>=[]): TDataSet;
var
 i:Integer;
begin
 for i := 0 to FieldCount -1 do
 begin
   if not MatchText(Fields[i].FieldName,ADisable) then
      AProc(Fields[i]);
 end;
 Result:=self;
end;

function TDataSetHelper._F(const FieldName: String): TField;
begin
  Result := Self.FieldByName(FieldName)
end;



function TDataSetHelper.GetBoolean(FieldName: String): Boolean;
begin
  Result := Self.FieldByName(FieldName).AsBoolean;
end;

function TDataSetHelper.GetDateTime(FieldName: String): TDateTime;
begin
   Result := Self.FieldByName(FieldName).AsDateTime;
end;

function TDataSetHelper.GetExtended(FieldName: String): Extended;
begin
  Result := Self.FieldByName(FieldName).AsFloat;
end;

function TDataSetHelper.GetInteger(FieldName: String): Integer;
begin
  Result := Self.FieldByName(FieldName).AsInteger;
end;

procedure TDataSetHelper.SetBoolean(FieldName: String; const Value: Boolean);
begin
  Self.FieldByName(FieldName).AsBoolean := Value;
end;

procedure TDataSetHelper.SetDateTime(FieldName: String; const Value: TDateTime);
begin
  Self.FieldByName(FieldName).AsDateTime:=Value;
end;

procedure TDataSetHelper.SetExtended(FieldName: String; const Value: Extended);
begin
  Self.FieldByName(FieldName).AsFloat := Value;
end;

procedure TDataSetHelper.SetInteger(FieldName: String; const Value: Integer);
begin
  Self.FieldByName(FieldName).AsInteger := Value;
end;

function TDataSetHelper.GetString(FieldName: String): String;
begin
  Result := Self.FieldByName(FieldName).AsString;
end;




function TDataSetHelper.GetVariant(FieldName: String): Variant;
begin
   Result := Self.FieldByName(FieldName).AsVariant;
end;

procedure TDataSetHelper._FromJson(const AJson: RawUtf8; const ArecNo: Integer; const isRecord: Boolean);
var
  dv    : TDocVariantData;
  field : TField;
  idx   : PtrInt;
  V     : PVariant;
  IsNull: Boolean;
  S     : string;
  dft   : TDataSetFieldType;
  nested: TDataSet;
begin
  if AJson = '' then Exit;
  if not dv.InitJson(AJson, JSON_FAST) then Exit;
  if (ArecNo > 0) and (RecordCount >= ArecNo) then Self.RecNo := ArecNo;
  for field in Self.Fields do
  begin
    if field.ReadOnly then Continue;
    if dv.Kind = dvObject then
    begin
      idx := dv.GetValueIndex(StringToUtf8(field.FieldName));
      if idx < 0 then Continue;
      V := @dv.Values[idx];
    end
    else if dv.Kind = dvArray then
    begin
      if field.Index >= dv.Count then Continue;
      V := @dv.Values[field.Index];
    end
    else Continue;
    IsNull := VarIsNull(V^) or VarIsEmpty(V^);
    case field.DataType of
      ftDataSet:
      begin
        if IsNull then Continue;
        dft    := DataSetFieldToType(TDataSetField(field));
        nested := TDataSetField(field).NestedDataSet;
        case dft of
          dfJSONObject: nested._FromJson(VariantSaveJson(V^), 0, True);
          dfJSONArray:
          begin
            nested.First;
            while not nested.Eof do nested.Delete;
            nested._FromJsonArray(VariantSaveJson(V^), False);
          end;
        end;
      end;
    else
      S := VarToStr(V^);
      SetFieldFromJsonValue(field, S, IsNull);
    end;
  end;
end;

procedure TDataSetHelper._FromJson(const AJson: RawUtf8);
var
  dv: TDocVariantData;
begin
  if AJson = '' then Exit;
  if not dv.InitJson(AJson, JSON_FAST) then Exit;
  case dv.Kind of
    dvObject: _FromJson(AJson, 0, False);
    dvArray:  _FromJsonArray(AJson, False);
  end;
end;

procedure TDataSetHelper._FromJsonArray(const AJson: RawUtf8; const isRecord: Boolean);
var
  dv   : TDocVariantData;
  i    : Integer;
  recNo: Integer;
begin
  if AJson = '' then Exit;
  if not dv.InitJson(AJson, JSON_FAST) then Exit;
  if dv.Kind <> dvArray then Exit;
  recNo := 0;
  for i := 0 to dv.Count - 1 do
  begin
    if not Self.IsEmpty then Inc(recNo);
    _FromJson(VariantSaveJson(dv.Values[i]), recNo, isRecord);
  end;
end;

procedure TDataSetHelper._FromJsonStr(const AJson: string);
begin
  _FromJson(StringToUtf8(AJson));
end;

function TDataSetHelper._LoadValue(const ADataSet: TDataSet; const ADisable:TArray<string>=[]):TDataSet;
var
 i:Integer;
 sf:TField;
begin
 if not Self._IsEditOrInsert then Self.Edit;
  for i := 0 to Fields.Count -1 do
    begin
      sf:=ADataSet.FindField(Fields.Fields[i].FieldName);
      if (sf<>nil) and (not sf.IsNull) and (not sf.AsString.IsEmpty) and (not MatchText(sf.FieldName,ADisable))  then
       begin
        Fields.Fields[i].Value:=sf.Value;
       end;
    end;
Result:=self;
end;

procedure TDataSetHelper.SetString(FieldName: String; const Value: String);
begin
  Self.FieldByName(FieldName).AsString := Value;
end;



procedure TDataSetHelper.SetVariant(FieldName: String; const Value: Variant);
begin
   Self.FieldByName(FieldName).AsVariant := Value;
end;


function TDataSetHelper._toAs<T>: T;
begin
 Result:= Self as T;
end;

function TDataSetHelper._Insert: TDataSet;
begin
Insert;
Result:=Self;
end;

function TDataSetHelper._IsChangeField(const AField: string): Boolean;
begin
 Result:=FieldByName(AField)._IsChange;
end;

function TDataSetHelper._IsChangeField(const AField: TArray<string>): Boolean;
var
 s:string;
begin
  Result:=false;
   for s in AField do
    begin
      Result:=FieldByName(s)._IsChange;
      if Result then exit; 
    end;
end;

function TDataSetHelper._IsEditOrInsert: Boolean;
begin
  // Self.UpdateStatus Buraya bak
  Result := Self.State in [dsInsert,dsEdit];
end;


function TDataSetHelper._LoadValue(const ADataSet: TDataSet; const AFieldName, ASourceFieldName: array of string):TDataSet;
var
 i:Integer;
 sf:TField;
begin
   Result := Self;
   for I := Low( AFieldName ) to High( AFieldName ) do
      begin
         sf := ADataSet.FieldByName( ASourceFieldName[ i ] );
         if ( sf <> nil ) and ( not sf.IsNull ) and ( not sf.AsString.IsEmpty ) then
            FieldByName( AFieldName[ i ] ).Value := sf.Value;
         //var s:=AFieldName[i]+' : '+FieldByName(AFieldName[i]).AsString;
      end;
end;

function TDataSetHelper._LoadValueALL(const ADataSet: TDataSet; const ADisable: TArray<string>;const ABeforePost:TProc<TDataSet>):TDataSet;
begin
  if not Active then Open;
  if _IsEditOrInsert then Post;
   ADataSet._DoEof(
   procedure (ds:TDataSet )
   begin
      Self.Insert;
      Self._LoadValue(ds,ADisable);
      if Assigned(ABeforePost) then ABeforePost(Self);
      
      Self._Post;
   end
   ,true)
end;

function TDataSetHelper._Locate(const KeyFields: string; const KeyValues: Variant; Options: Data.TLocateOptions): Boolean;
begin
  Self.DisableControls;
  try
    Result := Self.Locate(KeyFields, KeyValues, Options);
  finally
    Self.EnableControls;
  end;
end;

function TDataSetHelper._Open: TDataSet;
begin
 Self.Open;
 Result:=Self;
end;

function TDataSetHelper._Post: TDataSet;
begin
   if _IsEditOrInsert then Self.Post;
   Result:=Self;
end;

procedure TDataSetHelper._ReOpen;
begin
 Close;
 Open;
end;

function TDataSetHelper._ToJSONArray: RawUtf8;
var
  W    : TJsonWriter;
  i    : Integer;
  First: Boolean;
begin
  W := TJsonWriter.CreateOwnedStream(4096);
  try
    W.Add('[');
    First := True;
    for i := 0 to Pred(FieldCount) do
      if Fields[i].Visible then
      begin
        if not First then W.AddComma else First := False;
        WriteFieldJson(W, Fields[i]);
      end;
    W.Add(']');
    Result := W.Text;
  finally
    W.Free;
  end;
end;

function TDataSetHelper._ToJSONArrayALL: RawUtf8;
var
  W       : TJsonWriter;
  bookMark: TBookmark;
  First   : Boolean;
begin
  W := TJsonWriter.CreateOwnedStream(65536);
  try
    W.Add('[');
    First := True;
    if not Self.IsEmpty then
    begin
      Self.DisableControls;
      try
        bookMark := Self.Bookmark;
        Self.First;
        while not Self.Eof do
        begin
          if not First then W.AddComma else First := False;
          W.AddString(_ToJSONArray);
          Self.Next;
        end;
      finally
        if Self.BookmarkValid(bookMark) then Self.GotoBookmark(bookMark);
        Self.FreeBookmark(bookMark);
        Self.EnableControls;
      end;
    end;
    W.Add(']');
    Result := W.Text;
  finally
    W.Free;
  end;
end;

function TDataSetHelper._ToJSONArrayALLStr: string;
begin
  Result := Utf8ToString(_ToJSONArrayALL);
end;

function TDataSetHelper._ToJSONObject(const ADisableField: TArray<string>): RawUtf8;
var
  W    : TJsonWriter;
  i    : Integer;
  First: Boolean;
begin
  if IsEmpty then begin Result := '{}'; Exit; end;
  W := TJsonWriter.CreateOwnedStream(4096);
  try
    W.Add('{');
    First := True;
    for i := 0 to Pred(FieldCount) do
    begin
      if not Fields[i].Visible then Continue;
      if MatchText(Fields[i].FieldName, ADisableField) then Continue;
      if not First then W.AddComma else First := False;
      W.AddFieldName(StringToUtf8(Fields[i].FieldName));
      WriteFieldJson(W, Fields[i]);
    end;
    W.Add('}');
    Result := W.Text;
  finally
    W.Free;
  end;
end;

function TDataSetHelper._ToJSONObjectStr(const AJsonStr: Boolean; const ADisableField: TArray<string>): string;
begin
  if IsEmpty then begin Result := '{}'; Exit; end;
  Result := Utf8ToString(_ToJSONObject(ADisableField));
end;

function TDataSetHelper._ToJSONStructure: RawUtf8;
var
  W: TJsonWriter;
  i: Integer;
begin
  W := TJsonWriter.CreateOwnedStream(4096);
  try
    W.Add('[');
    for i := 0 to Pred(FieldCount) do
    begin
      if i > 0 then W.AddComma;
      W.Add('{');
      W.AddFieldName('FieldName'); W.AddJsonString(StringToUtf8(Fields[i].FieldName)); W.AddComma;
      W.AddFieldName('DataType');  W.AddJsonString(StringToUtf8(GetEnumName(TypeInfo(TFieldType), Integer(Fields[i].DataType)))); W.AddComma;
      W.AddFieldName('Size');      W.Add(Fields[i].Size);
      W.Add('}');
    end;
    W.Add(']');
    Result := W.Text;
  finally
    W.Free;
  end;
end;

function TDataSetHelper._Value(const AFieldName: string; AValue: Variant;const AIIF:Boolean): TDataSet;
begin
 Result:=self;
 if AIIF then 
 FieldByName(AFieldName).Value:=AValue;
end;

function TDataSetHelper._Values(const AFields: TArray<string>): TArray<Variant>;
var
 s:string;
begin
   SetLength(Result,length(AFields));
   for var i := Low(AFields) to High(AFields) do
     Result[i]:=FieldByName(AFields[i]).Value;


end;


function TDataSetHelper._W(const AFieldName: string; const V: Boolean;const AIIF: Boolean): TDataSet;
begin
   if AIIF then
   _B[AFieldName]:=V;
   Result:=Self;
end;

function TDataSetHelper._W(const AFieldName, V: string;const AIIF: Boolean): TDataSet;
begin
if AIIF then
   _S[AFieldName]:=V;
   Result:=Self;
end;

function TDataSetHelper._W(const AFieldName: string; const V: Integer;const AIIF: Boolean): TDataSet;
begin
if AIIF then
  _I[AFieldName]:=V;
  Result:=Self;
end;

function TDataSetHelper._Values: TArray<Variant>;
var
  i:integer;
begin
   SetLength(Result,FieldCount);
   for i := 0 to FieldCount -1 do
     Result[i]:=Fields[i].Value;

end;

{$ENDREGION}
{ TUniConnectionHelper }







{ TFieldsHelper }

function TFieldsHelper._LoadToFile(const AFileName: string): Boolean;
 begin
   try

   if DataType=ftWideMemo then
    //TMemoField(Self).Value:=FileToString(AFileName)
    TMemoField(Self).LoadFromFile(AFileName)
   else
    TBlobField(Self).LoadFromFile(AFileName);

    Result:=True;
 except
  Result:=False;

 end;
end;

function TFieldsHelper._SaveToFile(const AFileName: string): Boolean;
begin
  try
    if DataType=ftWideMemo then TWideMemoField(Self).SaveToFile(AFileName)  else
    TBlobField(Self).SaveToFile(AFileName);
    Result:=True;
 except
  Result:=False;

 end;
end;

function TFieldsHelper._SqlStr(const AInc: Integer): string;
begin
 Result:=FieldToSqlStr(Self.DataType,Self.Value,AInc);
end;

function TFieldsHelper._GetType<T>: T;
begin
 Result :=Self as T;
end;

function TFieldsHelper._IsChange: Boolean;
begin
 Result:=false;
 if DataSet.State = dsInsert then Result:=True
 else if DataSet.State = dsEdit then
    Result:=not VarSameValue(Value,OldValue);
end;



{ TSQLTimeStampHelp }

function TSQLTimeStampHelp.AsString: string;
begin
 Result:=SQLTimeStampToStr('YYYY-MM-DD HH:NN:SS',Self);

end;

procedure TSQLTimeStampHelp.SetDateToTimeStamp(const dt: TDateTime);
begin
 Self:=DateTimeToSQLTimeStamp(dt);
end;

{ Coll }

constructor TDBFieldAttr.Create(const aName: string);
begin
fName:=aName;
//FValue:=AValue;
end;

{ TDbClass }

constructor TDbClass.Create(const aDataSet: TDataSet);
begin
  inherited Create;
  SetDataset(aDataSet);
end;

procedure TDbClass.MapFields;
var
  Context: TRttiContext;
  RType: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  DBAttr: TDBFieldAttr;
  MaxIndex: Integer;
  LField: TField;
begin
  if FIsMapped or (FDataSet = nil) then Exit;

  Context := TRttiContext.Create;
  try
    RType := Context.GetType(Self.ClassType);

    // �nce maksimum index'i bulup array boyutunu ayarlayal�m
    MaxIndex := -1;
    for Prop in RType.GetProperties do
    begin
      for Attr in Prop.GetAttributes do
        if Attr is TDBFieldAttr then
          MaxIndex := Max(MaxIndex, TRttiInstanceProperty(Prop).Index);
    end;

    if MaxIndex = -1 then Exit;

    SetLength(FFieldCache, MaxIndex + 1);

    // Field'lar� cache'e alal�m
    for Prop in RType.GetProperties do
    begin
      for Attr in Prop.GetAttributes do
      begin
        if Attr is TDBFieldAttr then
        begin
          DBAttr := TDBFieldAttr(Attr);
          // FieldByName yerine FindField kullanmak daha g�venlidir (Exception f�rlatmaz)
          LField := FDataSet.FindField(DBAttr.Name);
          FFieldCache[TRttiInstanceProperty(Prop).Index] := LField;
        end;
      end;
    end;

    FIsMapped := True;
  finally
    Context.Free;
  end;
end;

procedure TDbClass.SetDataset(const Value: TDataSet);
begin
  if FDataSet <> Value then
  begin
    FDataSet := Value;
    FIsMapped := False; // Dataset de�i�irse haritalama yenilenmeli
    SetLength(FFieldCache, 0);
    if FDataSet <> nil then
      MapFields;
    OnDataSetChanged;
  end;
end;

function TDbClass.GetVar(const Index: Integer): Variant;
var
  LField: TField;
begin
  // H�zl� eri�im: RTTI yok, sadece array lookup
  if (Index >= 0) and (Index < Length(FFieldCache)) then
  begin
    LField := FFieldCache[Index];
    if Assigned(LField) then
      Exit(LField.Value);
  end;
  Result := Null;
end;

procedure TDbClass.SetVar(const Index: Integer; const Value: Variant);
var
  LField: TField;
begin
  if (Index >= 0) and (Index < Length(FFieldCache)) then
  begin
    LField := FFieldCache[Index];
    if Assigned(LField) then
    begin
      // Dataset edit modunda de�ilse otomatik moda sok (Helper'�n� kullan�yoruz)

      if not (FDataSet.State in [dsEdit, dsInsert]) then
        FDataSet.Edit;

      LField.Value := Value;
    end;
  end;
end;

procedure TDbClass.OnDataSetChanged;
begin
  // Alt s�n�flar override edebilir
end;

function TDataSetHelper._W(const AFieldName: string; const V: Variant;  const AIIF: Boolean): TDataSet;
begin
   Result:=_Value(AFieldName,v,AIIF)
end;

function TDataSetHelper._WDt(const AFieldName: string): TDataSet;
begin
  Result:=Self._WDt(AFieldName,Now,True);
end;

function TDataSetHelper._WDt(const AFieldName: string; const V: TDateTime; const AIIF: Boolean): TDataSet;
begin
   if AIIF then _DT[AFieldName]:=V;
   Result:=Self;
end;


function TDataSetHelper._WTry(const AFieldName: string; const AProc: TProc<TField>): TDataSet;
begin
 Result:=Self;
 if not Assigned(AProc) then exit;

 var fld:= FindField(AFieldName);
 if fld <> nil then
  AProc(fld);

end;

function TDataSetHelper._W(const AFieldName: string; const V: TStream; const AIIF: Boolean): TDataSet;
begin
  if AIIF then TBlobField(_F(AFieldName)).LoadFromStream(V);
   Result:=Self;

end;

end.
