unit rad.customfield;

{ Tabloya çalışma zamanında özel alan ekleme: tanım modeli, kolon adı üretimi,
  lehçeye göre DDL metni, çoklu seçim biçimi. Bağlantısız; UniDAC uygulaması
  Help.uni (TRadUniCustomFieldStore), DevExpress yüzü rad.dev.customfields.
  Spec: docs/specs/rad.customfield.md. }

interface

uses
  System.SysUtils, System.Classes, System.Variants, System.Generics.Collections,
  rad.sqlfilter;

type
  ERadCustomField = class(Exception);

  TRadCustomFieldType = (cfText, cfMemo, cfInteger, cfDecimal, cfMoney, cfDate,
    cfTime, cfDateTime, cfBoolean, cfSingleChoice, cfMultiChoice);

  TRadCustomFieldOption = record
    Code: string;
    Caption: string;
  end;

  /// <summary>Bir ozel_alan satırı. ColumnName ve FieldType kaydedildikten sonra değişmez.</summary>
  TRadCustomFieldDef = class
  private
    FOptions: TArray<TRadCustomFieldOption>;
  public
    Id: Integer;
    GroupId: Integer;
    TableName: string;
    ColumnName: string;
    Caption: string;
    FieldType: TRadCustomFieldType;
    Length: Integer;
    Decimals: Integer;
    Required: Boolean;
    DefaultValue: string;
    Filterable: Boolean;
    Order: Integer;
    Active: Boolean;
    constructor Create;
    procedure Assign(ASource: TRadCustomFieldDef);
    function Clone: TRadCustomFieldDef;
    /// <summary>DB'de saklanan tip kodu: 'metin', 'tamsayi' ...</summary>
    function TypeCode: string;
    class function TypeOfCode(const ACode: string): TRadCustomFieldType; static;
    class function TypeCodeOf(AType: TRadCustomFieldType): string; static;
    /// <summary>Liste tipleri için seçenekler; metin biçimi satır başına "kod|başlık".</summary>
    function OptionsText: string;
    procedure SetOptionsText(const AText: string);
    function OptionCaption(const ACode: string): string;
    function HasOptions: Boolean;
    /// <summary>Yeni kayıt için varsayılan; boşsa Null. Tipine göre çevrilir.</summary>
    function DefaultAsVariant: Variant;
    /// <summary>Boş = geçerli; değilse ilk hatanın açıklaması.</summary>
    function Validate: string;
    function IsChoice: Boolean;
    property Options: TArray<TRadCustomFieldOption> read FOptions write FOptions;
  end;

  /// <summary>Bir ozel_alan_grup satırı (= sekme) ve alanları.</summary>
  TRadCustomFieldGroupDef = class
  public
    Id: Integer;
    TableName: string;
    Name: string;
    Order: Integer;
    Active: Boolean;
    Fields: TObjectList<TRadCustomFieldDef>;
    constructor Create;
    destructor Destroy; override;
    function ActiveFields: TArray<TRadCustomFieldDef>;
  end;

  TRadCustomFieldGroups = TObjectList<TRadCustomFieldGroupDef>;

  /// <summary>Tanımların kaynağı. UniDAC uygulaması: Help.uni.TRadUniCustomFieldStore.</summary>
  IRadCustomFieldStore = interface
    ['{5A1C7D2E-8B4F-4C3A-9E6D-1F0B2A3C4D5E}']
    function Dialect: TRadSqlDialect;
    /// <summary>Tanım tabloları yoksa yaratır. İdempotent.</summary>
    procedure EnsureDefinitionTables;
    /// <summary>Gruplar sıra ile, her grubun alanları sıra ile. Sahiplik çağırana geçer.</summary>
    function LoadGroups(const ATable: string; AIncludeInactive: Boolean = False): TRadCustomFieldGroups;
    procedure AddGroup(AGroup: TRadCustomFieldGroupDef);
    procedure UpdateGroup(AGroup: TRadCustomFieldGroupDef);
    /// <summary>Kolon adını üretir, ALTER TABLE + insert tek transaction. ADef.Id/ColumnName dolar.</summary>
    procedure AddField(ADef: TRadCustomFieldDef);
    /// <summary>Başlık/sıra/aktif/zorunlu/varsayılan/seçenekler/filtrele. Tip ve kolon adı değişmez.</summary>
    procedure UpdateField(ADef: TRadCustomFieldDef);
    /// <summary>Yalnız genişletme; küçültme hata.</summary>
    procedure ExtendLength(ADef: TRadCustomFieldDef; ANewLength: Integer);
    /// <summary>Aktif alanların kolon adları, tanım sırasında.</summary>
    function ColumnNames(const ATable: string): TArray<string>;
    function LoadLayout(const ATable: string; AUserId: Integer; AStream: TStream): Boolean;
    procedure SaveLayout(const ATable: string; AUserId: Integer; AStream: TStream);
    procedure DeleteLayout(const ATable: string; AUserId: Integer);
  end;

  /// <summary>Saf DDL/katalog metni; bağlantı yok, birim test edilir. Parametre adları :t / :c.</summary>
  TRadCustomFieldDdl = class
  public const
    ColumnPrefix = 'ozel_';
    GroupTable = 'ozel_alan_grup';
    FieldTable = 'ozel_alan';
    LayoutTable = 'ozel_alan_duzen';
  public
    class function ColumnName(ANumber: Integer): string; static;
    /// <summary>'ozel_7' → 7; desen dışı → 0.</summary>
    class function NumberOf(const AColumnName: string): Integer; static;
    class function NextNumber(const AExisting: TArray<string>): Integer; static;
    class function IsValidTableName(const ATable: string): Boolean; static;
    class function ColumnType(ADialect: TRadSqlDialect; ADef: TRadCustomFieldDef): string; static;
    class function AddColumn(ADialect: TRadSqlDialect; const ATable: string; ADef: TRadCustomFieldDef): string; static;
    class function AlterLength(ADialect: TRadSqlDialect; const ATable: string; ADef: TRadCustomFieldDef;
      ANewLength: Integer): string; static;
    /// <summary>count(*) sorgusu; :t tablo, :c kolon. Firebird'de büyük harfle verilmeli (CatalogName).</summary>
    class function ColumnExistsSql(ADialect: TRadSqlDialect): string; static;
    class function TableExistsSql(ADialect: TRadSqlDialect): string; static;
    /// <summary>Katalog sorgusuna gidecek ad: Firebird büyük harf, diğerleri olduğu gibi (küçük harf önerilir).</summary>
    class function CatalogName(ADialect: TRadSqlDialect; const AName: string): string; static;
    class function CreateDefinitionTables(ADialect: TRadSqlDialect): TArray<string>; static;
  end;

  /// <summary>Çoklu seçim saklama biçimi: |k1|k2| (baş/son ayraç; Contains(alan, '|k1|') kesin bulur).</summary>
  TRadMultiChoice = class
  public const
    Delimiter = '|';
  public
    class function Join(const ACodes: array of string): string; static;
    class function Split(const AValue: string): TArray<string>; static;
    /// <summary>'k' → '|k|'; rad.sqlfilter.Contains için.</summary>
    class function Wrap(const ACode: string): string; static;
    class function IsValidCode(const ACode: string): Boolean; static;
    class function Has(const AValue, ACode: string): Boolean; static;
  end;

implementation

uses
  System.StrUtils, System.DateUtils;

const
  TYPE_CODES: array[TRadCustomFieldType] of string = ('metin', 'not', 'tamsayi', 'ondalik',
    'para', 'tarih', 'saat', 'tarihsaat', 'evethayir', 'tekli', 'coklu');

function IsIdentChar(C: Char; AFirst: Boolean): Boolean;
begin
  Result := CharInSet(C, ['A'..'Z', 'a'..'z', '_']) or (not AFirst and CharInSet(C, ['0'..'9']));
end;

function IsIdent(const S: string): Boolean;
var
  i: Integer;
begin
  Result := S <> '';
  for i := 1 to System.Length(S) do
    if not IsIdentChar(S[i], i = 1) then
      Exit(False);
end;

{ TRadCustomFieldDef }

constructor TRadCustomFieldDef.Create;
begin
  inherited Create;
  Active := True;
  Length := 50;
  Decimals := 2;
end;

procedure TRadCustomFieldDef.Assign(ASource: TRadCustomFieldDef);
begin
  Id := ASource.Id;
  GroupId := ASource.GroupId;
  TableName := ASource.TableName;
  ColumnName := ASource.ColumnName;
  Caption := ASource.Caption;
  FieldType := ASource.FieldType;
  Length := ASource.Length;
  Decimals := ASource.Decimals;
  Required := ASource.Required;
  DefaultValue := ASource.DefaultValue;
  Filterable := ASource.Filterable;
  Order := ASource.Order;
  Active := ASource.Active;
  FOptions := Copy(ASource.FOptions);
end;

function TRadCustomFieldDef.Clone: TRadCustomFieldDef;
begin
  Result := TRadCustomFieldDef.Create;
  Result.Assign(Self);
end;

function TRadCustomFieldDef.TypeCode: string;
begin
  Result := TypeCodeOf(FieldType);
end;

class function TRadCustomFieldDef.TypeCodeOf(AType: TRadCustomFieldType): string;
begin
  Result := TYPE_CODES[AType];
end;

class function TRadCustomFieldDef.TypeOfCode(const ACode: string): TRadCustomFieldType;
var
  T: TRadCustomFieldType;
begin
  for T := Low(T) to High(T) do
    if SameText(TYPE_CODES[T], ACode) then
      Exit(T);
  raise ERadCustomField.CreateFmt('Bilinmeyen özel alan tipi: "%s"', [ACode]);
end;

function TRadCustomFieldDef.IsChoice: Boolean;
begin
  Result := FieldType in [cfSingleChoice, cfMultiChoice];
end;

function TRadCustomFieldDef.HasOptions: Boolean;
begin
  Result := System.Length(FOptions) > 0;
end;

function TRadCustomFieldDef.OptionsText: string;
var
  O: TRadCustomFieldOption;
  LSb: TStringBuilder;
begin
  LSb := TStringBuilder.Create;
  try
    for O in FOptions do
      LSb.Append(O.Code).Append(TRadMultiChoice.Delimiter).AppendLine(O.Caption);
    Result := LSb.ToString.TrimRight;
  finally
    LSb.Free;
  end;
end;

procedure TRadCustomFieldDef.SetOptionsText(const AText: string);
var
  LLine, LCode, LCaption: string;
  P: Integer;
  LList: TList<TRadCustomFieldOption>;
  O: TRadCustomFieldOption;
begin
  LList := TList<TRadCustomFieldOption>.Create;
  try
    for LLine in AText.Split([#13#10, #10], TStringSplitOptions.ExcludeEmpty) do
    begin
      P := Pos(TRadMultiChoice.Delimiter, LLine);
      if P > 0 then
      begin
        LCode := Trim(Copy(LLine, 1, P - 1));
        LCaption := Trim(Copy(LLine, P + 1, MaxInt));
      end
      else
      begin
        LCode := Trim(LLine);
        LCaption := LCode;
      end;
      if LCode = '' then Continue;
      if LCaption = '' then LCaption := LCode;
      O.Code := LCode;
      O.Caption := LCaption;
      LList.Add(O);
    end;
    FOptions := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TRadCustomFieldDef.OptionCaption(const ACode: string): string;
var
  O: TRadCustomFieldOption;
begin
  for O in FOptions do
    if SameText(O.Code, ACode) then
      Exit(O.Caption);
  Result := ACode;
end;

function TRadCustomFieldDef.DefaultAsVariant: Variant;
var
  LText: string;
  D: Double;
  DT: TDateTime;
  FS: TFormatSettings;
begin
  Result := Null;
  LText := Trim(DefaultValue);
  if LText = '' then Exit;
  FS := TFormatSettings.Invariant;
  case FieldType of
    cfInteger: Result := StrToInt(LText);
    cfDecimal, cfMoney:
      if TryStrToFloat(StringReplace(LText, ',', '.', []), D, FS) then Result := D
      else raise ERadCustomField.CreateFmt('Varsayılan sayı değil: "%s"', [LText]);
    cfDate, cfDateTime:
      if TryISO8601ToDate(LText, DT, True) then Result := DT
      else Result := StrToDateTime(LText);
    cfTime: Result := StrToTime(LText);
    cfBoolean: Result := MatchText(LText, ['1', 'true', 't', 'evet', 'e']);
  else
    Result := LText;
  end;
end;

function TRadCustomFieldDef.Validate: string;
var
  O: TRadCustomFieldOption;
begin
  Result := '';
  if Trim(Caption) = '' then Exit('Başlık boş olamaz.');
  if not TRadCustomFieldDdl.IsValidTableName(TableName) then Exit('Tablo adı geçersiz.');
  if (FieldType = cfText) and ((Length < 1) or (Length > 4000)) then Exit('Metin uzunluğu 1..4000 olmalı.');
  if (FieldType = cfDecimal) and ((Decimals < 0) or (Decimals > 8)) then Exit('Ondalık basamak 0..8 olmalı.');
  if IsChoice and not HasOptions then Exit('Seçenek listesi boş olamaz.');
  for O in FOptions do
    if not TRadMultiChoice.IsValidCode(O.Code) then
      Exit(Format('Seçenek kodu "%s" geçersiz ("%s" içeremez, boş olamaz).', [O.Code, TRadMultiChoice.Delimiter]));
  try
    DefaultAsVariant;
  except
    on E: Exception do Exit('Varsayılan değer tipe uymuyor: ' + E.Message);
  end;
end;

{ TRadCustomFieldGroupDef }

constructor TRadCustomFieldGroupDef.Create;
begin
  inherited Create;
  Active := True;
  Fields := TObjectList<TRadCustomFieldDef>.Create(True);
end;

destructor TRadCustomFieldGroupDef.Destroy;
begin
  Fields.Free;
  inherited;
end;

function TRadCustomFieldGroupDef.ActiveFields: TArray<TRadCustomFieldDef>;
var
  F: TRadCustomFieldDef;
  LList: TList<TRadCustomFieldDef>;
begin
  LList := TList<TRadCustomFieldDef>.Create;
  try
    for F in Fields do
      if F.Active then LList.Add(F);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

{ TRadCustomFieldDdl }

class function TRadCustomFieldDdl.ColumnName(ANumber: Integer): string;
begin
  Result := ColumnPrefix + IntToStr(ANumber);
end;

class function TRadCustomFieldDdl.NumberOf(const AColumnName: string): Integer;
begin
  Result := 0;
  if not StartsText(ColumnPrefix, AColumnName) then Exit;
  Result := StrToIntDef(Copy(AColumnName, System.Length(ColumnPrefix) + 1, MaxInt), 0);
  if Result < 0 then Result := 0;
end;

class function TRadCustomFieldDdl.NextNumber(const AExisting: TArray<string>): Integer;
var
  S: string;
  N: Integer;
begin
  Result := 0;
  for S in AExisting do
  begin
    N := NumberOf(S);
    if N > Result then Result := N;
  end;
  Inc(Result);
end;

class function TRadCustomFieldDdl.IsValidTableName(const ATable: string): Boolean;
var
  LParts: TArray<string>;
begin
  LParts := ATable.Split(['.']);
  Result := (System.Length(LParts) in [1, 2]) and IsIdent(LParts[0]) and
    ((System.Length(LParts) = 1) or IsIdent(LParts[1])) and (System.Length(ATable) <= 63);
end;

class function TRadCustomFieldDdl.ColumnType(ADialect: TRadSqlDialect; ADef: TRadCustomFieldDef): string;
const
  VARCHAR_: array[TRadSqlDialect] of string = ('varchar', 'nvarchar', 'varchar', 'varchar');
  MEMO_: array[TRadSqlDialect] of string = ('text', 'nvarchar(max)', 'text', 'blob sub_type text');
  BOOL_: array[TRadSqlDialect] of string = ('boolean', 'bit', 'tinyint(1)', 'boolean');
  TS_: array[TRadSqlDialect] of string = ('timestamp', 'datetime2', 'datetime', 'timestamp');
  DEC_: array[TRadSqlDialect] of string = ('numeric', 'numeric', 'decimal', 'numeric');
begin
  case ADef.FieldType of
    cfText: Result := Format('%s(%d)', [VARCHAR_[ADialect], ADef.Length]);
    cfMemo: Result := MEMO_[ADialect];
    cfInteger: if ADialect = sdMSSQL then Result := 'int' else Result := 'integer';
    cfDecimal: Result := Format('%s(18,%d)', [DEC_[ADialect], ADef.Decimals]);
    cfMoney: Result := DEC_[ADialect] + '(18,4)';
    cfDate: Result := 'date';
    cfTime: Result := 'time';
    cfDateTime: Result := TS_[ADialect];
    cfBoolean: Result := BOOL_[ADialect];
    cfSingleChoice: Result := VARCHAR_[ADialect] + '(50)';
    cfMultiChoice: Result := VARCHAR_[ADialect] + '(500)';
  end;
end;

class function TRadCustomFieldDdl.AddColumn(ADialect: TRadSqlDialect; const ATable: string;
  ADef: TRadCustomFieldDef): string;
begin
  // Zorunluluk editörde; mevcut satırlar yüzünden NOT NULL DDL'i yok (spec EARS 2).
  case ADialect of
    sdPostgreSQL, sdMySQL:
      Result := Format('alter table %s add column %s %s', [ATable, ADef.ColumnName, ColumnType(ADialect, ADef)]);
    sdMSSQL:
      Result := Format('alter table %s add %s %s null', [ATable, ADef.ColumnName, ColumnType(ADialect, ADef)]);
    sdFirebird:
      Result := Format('alter table %s add %s %s', [ATable, ADef.ColumnName, ColumnType(ADialect, ADef)]);
  end;
end;

class function TRadCustomFieldDdl.AlterLength(ADialect: TRadSqlDialect; const ATable: string;
  ADef: TRadCustomFieldDef; ANewLength: Integer): string;
var
  LDef: TRadCustomFieldDef;
  LType: string;
begin
  if ADef.FieldType <> cfText then
    raise ERadCustomField.Create('Uzunluk yalnız metin alanda değiştirilir.');
  if ANewLength <= ADef.Length then
    raise ERadCustomField.CreateFmt('Uzunluk küçültülemez (%d → %d).', [ADef.Length, ANewLength]);
  LDef := ADef.Clone;
  try
    LDef.Length := ANewLength;
    LType := ColumnType(ADialect, LDef);
  finally
    LDef.Free;
  end;
  case ADialect of
    sdPostgreSQL, sdFirebird:
      Result := Format('alter table %s alter column %s type %s', [ATable, ADef.ColumnName, LType]);
    sdMSSQL:
      Result := Format('alter table %s alter column %s %s null', [ATable, ADef.ColumnName, LType]);
    sdMySQL:
      Result := Format('alter table %s modify column %s %s null', [ATable, ADef.ColumnName, LType]);
  end;
end;

class function TRadCustomFieldDdl.ColumnExistsSql(ADialect: TRadSqlDialect): string;
begin
  if ADialect = sdFirebird then
    Result := 'select count(*) from rdb$relation_fields where trim(rdb$relation_name) = :t and trim(rdb$field_name) = :c'
  else
    // Büyük harf şart: SQL Server Türkçe collation'da (Turkish_CI_AS) 'information_schema' ≠ 'INFORMATION_SCHEMA' (i/I).
    // PG ve MySQL tırnaksız adı zaten küçük harfe katlar.
    Result := 'select count(*) from INFORMATION_SCHEMA.COLUMNS where TABLE_NAME = :t and COLUMN_NAME = :c';
end;

class function TRadCustomFieldDdl.TableExistsSql(ADialect: TRadSqlDialect): string;
begin
  if ADialect = sdFirebird then
    Result := 'select count(*) from rdb$relations where trim(rdb$relation_name) = :t'
  else
    Result := 'select count(*) from INFORMATION_SCHEMA.TABLES where TABLE_NAME = :t';
end;

class function TRadCustomFieldDdl.CatalogName(ADialect: TRadSqlDialect; const AName: string): string;
var
  P: Integer;
begin
  // Şema öneki katalogda ayrı kolondur; burada yalnız tablo adı.
  P := Pos('.', AName);
  if P > 0 then Result := Copy(AName, P + 1, MaxInt) else Result := AName;
  if ADialect = sdFirebird then Result := UpperCase(Result);
end;

class function TRadCustomFieldDdl.CreateDefinitionTables(ADialect: TRadSqlDialect): TArray<string>;
const
  ID_: array[TRadSqlDialect] of string = (
    'integer generated by default as identity primary key',
    'int identity(1,1) primary key',
    'int auto_increment primary key',
    'integer generated by default as identity primary key');
  VC_: array[TRadSqlDialect] of string = ('varchar', 'nvarchar', 'varchar', 'varchar');
  MEMO_: array[TRadSqlDialect] of string = ('text', 'nvarchar(max)', 'text', 'blob sub_type text');
  BOOL_: array[TRadSqlDialect] of string = ('boolean', 'bit', 'tinyint(1)', 'boolean');
  TS_: array[TRadSqlDialect] of string = ('timestamp', 'datetime2', 'datetime', 'timestamp');
  BLOB_: array[TRadSqlDialect] of string = ('bytea', 'varbinary(max)', 'longblob', 'blob');
  TRUE_: array[TRadSqlDialect] of string = ('true', '1', '1', 'true');
  FALSE_: array[TRadSqlDialect] of string = ('false', '0', '0', 'false');
var
  V: string;
begin
  V := VC_[ADialect];
  Result := [
    Format('create table %s (id %s, tablo_adi %s(63) not null, adi %s(100) not null, ' +
      'sira integer default 0 not null, aktif_mi %s default %s not null, ' +
      'constraint uq_%0:s unique (tablo_adi, adi))',
      [GroupTable, ID_[ADialect], V, V, BOOL_[ADialect], TRUE_[ADialect]]),
    Format('create table %s (id %s, grup_id integer not null, tablo_adi %s(63) not null, ' +
      'kolon_adi %s(63) not null, baslik %s(100) not null, veri_tipi %s(20) not null, ' +
      'uzunluk integer, ondalik integer, zorunlu_mu %s default %s not null, varsayilan %s(500), ' +
      'secenekler %s, filtrele_mi %s default %s not null, sira integer default 0 not null, ' +
      'aktif_mi %s default %s not null, olusturan %s(100), olusturma_zamani %s, ' +
      'constraint uq_%0:s unique (tablo_adi, kolon_adi), ' +
      'constraint fk_%0:s_grup foreign key (grup_id) references %16:s (id))',
      [FieldTable, ID_[ADialect], V, V, V, V, BOOL_[ADialect], FALSE_[ADialect], V,
       MEMO_[ADialect], BOOL_[ADialect], FALSE_[ADialect], BOOL_[ADialect], TRUE_[ADialect],
       V, TS_[ADialect], GroupTable]),
    Format('create table %s (tablo_adi %s(63) not null, kullanici_id integer not null, duzen %s, ' +
      'constraint pk_%0:s primary key (tablo_adi, kullanici_id))',
      [LayoutTable, V, BLOB_[ADialect]])];
end;

{ TRadMultiChoice }

class function TRadMultiChoice.IsValidCode(const ACode: string): Boolean;
begin
  Result := (Trim(ACode) <> '') and (Pos(Delimiter, ACode) = 0);
end;

class function TRadMultiChoice.Join(const ACodes: array of string): string;
var
  S: string;
begin
  Result := '';
  for S in ACodes do
    if IsValidCode(S) then
      Result := Result + Delimiter + Trim(S);
  if Result <> '' then
    Result := Result + Delimiter;
end;

class function TRadMultiChoice.Split(const AValue: string): TArray<string>;
begin
  Result := AValue.Split([Delimiter], TStringSplitOptions.ExcludeEmpty);
end;

class function TRadMultiChoice.Wrap(const ACode: string): string;
begin
  Result := Delimiter + Trim(ACode) + Delimiter;
end;

class function TRadMultiChoice.Has(const AValue, ACode: string): Boolean;
begin
  Result := Pos(Wrap(ACode), AValue) > 0;
end;

end.
