unit rad.sqlfilter;

{ Akıcı SQL filtre üretici: WHERE + ORDER BY. Değerler hiçbir zaman SQL metnine
  yazılmaz, hepsi :p1, :p2 ... parametresidir. Alan adları koddan gelir.
  Spec: docs/specs/rad.sqlfilter.md. UniDAC'a aktarma: Help.uni (_ApplyFilter). }

interface

uses
  System.SysUtils, System.Classes, System.Variants, System.Generics.Collections;

type
  TRadSqlDialect = (sdPostgreSQL, sdMSSQL, sdMySQL, sdFirebird);
  /// <summary>SkipEmpty: boş değer koşul üretmez. Strict: boş değer hata, boş IN 1=0.</summary>
  TRadFilterMode = (rfmSkipEmpty, rfmStrict);
  /// <summary>rcDefault: filtre ayarı. rcDatabase: düz işleç, collation'a kalır.</summary>
  TRadCase = (rcDefault, rcDatabase, rcSensitive, rcInsensitive);

  ERadSqlFilter = class(Exception);

  TRadSqlParam = record
    Name: string;   // ':' olmadan
    Value: Variant;
  end;

  IRadSqlFilter = interface
    ['{7B3E2C1A-9D4F-4E8B-A6C5-2F1D0E9B8A73}']
    function Dialect(AValue: TRadSqlDialect): IRadSqlFilter;
    function Mode(AValue: TRadFilterMode): IRadSqlFilter;
    /// <summary>Kullanıcı desenindeki joker karakterler (varsayılan % ve _).</summary>
    function Wildcards(AMany, AOne: Char): IRadSqlFilter;
    function CaseMode(AValue: TRadCase): IRadSqlFilter;
    function CaseSensitive(AValue: Boolean): IRadSqlFilter;
    /// <summary>Parametre adı öneki (varsayılan 'p' → :p1). İki filtre birleşecekse farklı verilir.</summary>
    function ParamPrefix(const AValue: string): IRadSqlFilter;
    /// <summary>Açık (varsayılan): saat bilgisi olmayan tarih "o günün tamamı" sayılır;
    /// Equal → [gün, gün+1), Greater → >= gün+1, LessEqual → &lt; gün+1.</summary>
    function WholeDay(AValue: Boolean): IRadSqlFilter;

    function Equal(const AField: string; const AValue: Variant; ACase: TRadCase = rcDefault): IRadSqlFilter;
    function NotEqual(const AField: string; const AValue: Variant; ACase: TRadCase = rcDefault): IRadSqlFilter;
    function Greater(const AField: string; const AValue: Variant): IRadSqlFilter;
    function GreaterEqual(const AField: string; const AValue: Variant): IRadSqlFilter;
    function Less(const AField: string; const AValue: Variant): IRadSqlFilter;
    function LessEqual(const AField: string; const AValue: Variant): IRadSqlFilter;
    /// <summary>AEscape: desendeki SQL jokerleri (%, _) düz karakter sayılır, ESCAPE '!' eklenir.</summary>
    function Like(const AField, APattern: string; AEscape: Boolean = True; ACase: TRadCase = rcDefault): IRadSqlFilter;
    function NotLike(const AField, APattern: string; AEscape: Boolean = True; ACase: TRadCase = rcDefault): IRadSqlFilter;
    /// <summary>Metin düz aranır; joker yorumu yapılmaz.</summary>
    function Contains(const AField, AText: string; ACase: TRadCase = rcDefault): IRadSqlFilter;
    function NotContains(const AField, AText: string; ACase: TRadCase = rcDefault): IRadSqlFilter;
    function StartsWith(const AField, AText: string; ACase: TRadCase = rcDefault): IRadSqlFilter;
    function EndsWith(const AField, AText: string; ACase: TRadCase = rcDefault): IRadSqlFilter;
    function InList(const AField: string; const AValues: array of Variant): IRadSqlFilter;
    function NotInList(const AField: string; const AValues: array of Variant): IRadSqlFilter;
    /// <summary>Tek taraf boşsa >= ya da &lt;= olur.</summary>
    function Between(const AField: string; const AFrom, ATo: Variant): IRadSqlFilter;
    function NotBetween(const AField: string; const AFrom, ATo: Variant): IRadSqlFilter;
    function IsNull(const AField: string): IRadSqlFilter;
    function IsNotNull(const AField: string): IRadSqlFilter;
    /// <summary>Güvenilen SQL parçası; her ? sırayla parametre olur. Kullanıcı girdisi için değil.</summary>
    function Raw(const ASql: string; const AValues: array of Variant): IRadSqlFilter;
    function BeginOr: IRadSqlFilter;
    function EndOr: IRadSqlFilter;
    function AddOrderBy(const AField: string; ADesc: Boolean = False): IRadSqlFilter;

    /// <summary>'WHERE ...' ya da boş.</summary>
    function GetWhere: string;
    function GetConditions: string;
    /// <summary>'ORDER BY a DESC, b ASC' ya da boş.</summary>
    function GetOrderBy: string;
    /// <summary>'a DESC, b ASC' (başında ORDER BY yok); UniDAC SetOrderBy bu biçimi bekler.</summary>
    function GetOrderByFields: string;
    function GetSql: string;
    /// <summary>Yalnız log/hata ayıklama: değerler metne gömülü. Çalıştırmak için değil.</summary>
    function GetDebugSql: string;
    function Params: TArray<TRadSqlParam>;
    function ParamCount: Integer;
    function IsEmpty: Boolean;
    /// <summary>Koşul, parametre ve sıralamayı siler; ayarlar kalır.</summary>
    function Clear: IRadSqlFilter;
    function ClearConditions: IRadSqlFilter;
    function ClearOrderBy: IRadSqlFilter;
  end;

  /// <summary>TRadSqlFilter.New ile oluşturulur; sınıf değişkeniyle tutulmaz.</summary>
  TRadSqlFilter = class(TInterfacedObject, IRadSqlFilter)
  strict private
  type
    TCond = record
      Sql: string;
      Group: Integer;
    end;
    TLikeKind = (lkPattern, lkContains, lkStarts, lkEnds);
  var
    FDialect: TRadSqlDialect;
    FMode: TRadFilterMode;
    FMany, FOne: Char;
    FCase: TRadCase;
    FPrefix: string;
    FWholeDay: Boolean;
    FConds: TList<TCond>;
    FParams: TList<TRadSqlParam>;
    FOrder: TList<string>;
    FGroup, FGroupSeq, FCounter: Integer;
    function AddParam(const AValue: Variant): string;
    procedure AddCond(const ASql: string);
    function CheckField(const AField: string): string;
    function EffCase(ACase: TRadCase): TRadCase;
    function SkipOrRaise(const AWhat: string): Boolean;
    function IsDay(const AValue: Variant): Boolean;
    function Compare(const AField, AOp: string; const AValue: Variant; ACase: TRadCase): IRadSqlFilter;
    procedure CompareDay(const AField, AOp: string; ADay: TDateTime);
    function LikeCore(const AField, AText: string; AKind: TLikeKind; AEscape, ANot: Boolean;
      ACase: TRadCase): IRadSqlFilter;
    function Translate(const APattern: string; AEscape: Boolean): string;
    function EscapeChar(AChar: Char): string;
    function EscapeAll(const AText: string): string;
    function InCore(const AField: string; const AValues: array of Variant; ANot: Boolean): IRadSqlFilter;
    function BetweenCore(const AField: string; const AFrom, ATo: Variant; ANot: Boolean): IRadSqlFilter;
    procedure RangeCond(const AField: string; const AFrom, ATo: Variant; ANot: Boolean);
    function GroupSql(AFrom: Integer; out ANext: Integer): string;
    function DebugLiteral(const AValue: Variant): string;
    class function IsText(const AValue: Variant): Boolean; static;
    class function IsEmptyValue(const AValue: Variant): Boolean; static;
    class function ValidName(const AName: string; AAllowDot: Boolean): Boolean; static;
  public
    constructor Create(ADialect: TRadSqlDialect; AMode: TRadFilterMode);
    destructor Destroy; override;
    class function New(ADialect: TRadSqlDialect = sdPostgreSQL; AMode: TRadFilterMode = rfmSkipEmpty): IRadSqlFilter; static;

    function Dialect(AValue: TRadSqlDialect): IRadSqlFilter;
    function Mode(AValue: TRadFilterMode): IRadSqlFilter;
    function Wildcards(AMany, AOne: Char): IRadSqlFilter;
    function CaseMode(AValue: TRadCase): IRadSqlFilter;
    function CaseSensitive(AValue: Boolean): IRadSqlFilter;
    function ParamPrefix(const AValue: string): IRadSqlFilter;
    function WholeDay(AValue: Boolean): IRadSqlFilter;
    function Equal(const AField: string; const AValue: Variant; ACase: TRadCase = rcDefault): IRadSqlFilter;
    function NotEqual(const AField: string; const AValue: Variant; ACase: TRadCase = rcDefault): IRadSqlFilter;
    function Greater(const AField: string; const AValue: Variant): IRadSqlFilter;
    function GreaterEqual(const AField: string; const AValue: Variant): IRadSqlFilter;
    function Less(const AField: string; const AValue: Variant): IRadSqlFilter;
    function LessEqual(const AField: string; const AValue: Variant): IRadSqlFilter;
    function Like(const AField, APattern: string; AEscape: Boolean = True; ACase: TRadCase = rcDefault): IRadSqlFilter;
    function NotLike(const AField, APattern: string; AEscape: Boolean = True; ACase: TRadCase = rcDefault): IRadSqlFilter;
    function Contains(const AField, AText: string; ACase: TRadCase = rcDefault): IRadSqlFilter;
    function NotContains(const AField, AText: string; ACase: TRadCase = rcDefault): IRadSqlFilter;
    function StartsWith(const AField, AText: string; ACase: TRadCase = rcDefault): IRadSqlFilter;
    function EndsWith(const AField, AText: string; ACase: TRadCase = rcDefault): IRadSqlFilter;
    function InList(const AField: string; const AValues: array of Variant): IRadSqlFilter;
    function NotInList(const AField: string; const AValues: array of Variant): IRadSqlFilter;
    function Between(const AField: string; const AFrom, ATo: Variant): IRadSqlFilter;
    function NotBetween(const AField: string; const AFrom, ATo: Variant): IRadSqlFilter;
    function IsNull(const AField: string): IRadSqlFilter;
    function IsNotNull(const AField: string): IRadSqlFilter;
    function Raw(const ASql: string; const AValues: array of Variant): IRadSqlFilter;
    function BeginOr: IRadSqlFilter;
    function EndOr: IRadSqlFilter;
    function AddOrderBy(const AField: string; ADesc: Boolean = False): IRadSqlFilter;
    function GetWhere: string;
    function GetConditions: string;
    function GetOrderBy: string;
    function GetOrderByFields: string;
    function GetSql: string;
    function GetDebugSql: string;
    function Params: TArray<TRadSqlParam>;
    function ParamCount: Integer;
    function IsEmpty: Boolean;
    function Clear: IRadSqlFilter;
    function ClearConditions: IRadSqlFilter;
    function ClearOrderBy: IRadSqlFilter;
  end;

implementation

uses
  System.DateUtils, System.StrUtils;

const
  ESCAPE_CHAR = '!';
  ESCAPE_SQL = ' ESCAPE ''' + ESCAPE_CHAR + '''';

resourcestring
  SFieldEmpty = 'Alan adı boş olamaz';
  SValueEmpty = 'Strict mod: %s için boş değer';
  SBetweenHalf = 'Strict mod: %s için Between tek taraflı';
  SOrGroupOpen = 'BeginOr açıkken yeni BeginOr';
  SOrGroupNone = 'Açık BeginOr yokken EndOr';
  SOrGroupNotClosed = 'EndOr eksik';
  SBadName = 'Geçersiz ad: %s';
  SRawEmpty = 'Raw SQL boş';
  SRawCount = 'Raw: ? sayısı (%d) değer sayısına (%d) eşit değil';
  SWildcards = 'Joker karakterler boş ya da aynı olamaz';

{ TRadSqlFilter }

constructor TRadSqlFilter.Create(ADialect: TRadSqlDialect; AMode: TRadFilterMode);
begin
  inherited Create;
  FDialect := ADialect;
  FMode := AMode;
  FMany := '%';
  FOne := '_';
  FCase := rcDatabase;  // harf modu açıkça istenmedikçe düz işleç (indeks kullanılır)
  FPrefix := 'p';
  FWholeDay := True;
  FConds := TList<TCond>.Create;
  FParams := TList<TRadSqlParam>.Create;
  FOrder := TList<string>.Create;
end;

destructor TRadSqlFilter.Destroy;
begin
  FOrder.Free;
  FParams.Free;
  FConds.Free;
  inherited;
end;

class function TRadSqlFilter.New(ADialect: TRadSqlDialect; AMode: TRadFilterMode): IRadSqlFilter;
begin
  Result := TRadSqlFilter.Create(ADialect, AMode);
end;

{ ayarlar }

function TRadSqlFilter.Dialect(AValue: TRadSqlDialect): IRadSqlFilter;
begin
  FDialect := AValue;
  Result := Self;
end;

function TRadSqlFilter.Mode(AValue: TRadFilterMode): IRadSqlFilter;
begin
  FMode := AValue;
  Result := Self;
end;

function TRadSqlFilter.Wildcards(AMany, AOne: Char): IRadSqlFilter;
begin
  if (AMany = #0) or (AOne = #0) or (AMany = AOne) then
    raise ERadSqlFilter.Create(SWildcards);
  FMany := AMany;
  FOne := AOne;
  Result := Self;
end;

function TRadSqlFilter.CaseMode(AValue: TRadCase): IRadSqlFilter;
begin
  if AValue = rcDefault then
    AValue := rcDatabase;
  FCase := AValue;
  Result := Self;
end;

function TRadSqlFilter.CaseSensitive(AValue: Boolean): IRadSqlFilter;
begin
  if AValue then
    Result := CaseMode(rcSensitive)
  else
    Result := CaseMode(rcInsensitive);
end;

function TRadSqlFilter.ParamPrefix(const AValue: string): IRadSqlFilter;
begin
  if not ValidName(AValue, False) then
    raise ERadSqlFilter.CreateFmt(SBadName, [AValue]);
  FPrefix := AValue;
  Result := Self;
end;

function TRadSqlFilter.WholeDay(AValue: Boolean): IRadSqlFilter;
begin
  FWholeDay := AValue;
  Result := Self;
end;

{ iç yardımcılar }

class function TRadSqlFilter.IsText(const AValue: Variant): Boolean;
var
  T: TVarType;
begin
  // varUString = 256, küme sınırı 255: "in [...]" derlenmez.
  T := VarType(AValue) and varTypeMask;
  Result := (T = varString) or (T = varUString) or (T = varOleStr);
end;

class function TRadSqlFilter.IsEmptyValue(const AValue: Variant): Boolean;
begin
  Result := VarIsClear(AValue) or VarIsNull(AValue) or
    (IsText(AValue) and (Trim(VarToStr(AValue)) = ''));
end;

class function TRadSqlFilter.ValidName(const AName: string; AAllowDot: Boolean): Boolean;
var
  i: Integer;
begin
  Result := (AName <> '') and CharInSet(AName[1], ['A'..'Z', 'a'..'z', '_']);
  for i := 2 to Length(AName) do
    if not (CharInSet(AName[i], ['A'..'Z', 'a'..'z', '0'..'9', '_']) or (AAllowDot and (AName[i] = '.'))) then
      Exit(False);
end;

// Saat bilgisi olmayan tarih (varDate, Frac = 0) ve WholeDay açık.
function TRadSqlFilter.IsDay(const AValue: Variant): Boolean;
begin
  Result := FWholeDay and (VarType(AValue) = varDate) and (Frac(TDateTime(AValue)) = 0);
end;

function TRadSqlFilter.AddParam(const AValue: Variant): string;
var
  P: TRadSqlParam;
begin
  Inc(FCounter);
  P.Name := FPrefix + IntToStr(FCounter);
  P.Value := AValue;
  FParams.Add(P);
  Result := ':' + P.Name;
end;

procedure TRadSqlFilter.AddCond(const ASql: string);
var
  C: TCond;
begin
  C.Sql := '(' + ASql + ')';
  C.Group := FGroup;
  FConds.Add(C);
end;

function TRadSqlFilter.CheckField(const AField: string): string;
begin
  Result := Trim(AField);
  if Result = '' then
    raise ERadSqlFilter.Create(SFieldEmpty);
end;

function TRadSqlFilter.EffCase(ACase: TRadCase): TRadCase;
begin
  if ACase = rcDefault then
    Result := FCase
  else
    Result := ACase;
end;

// True: koşul üretilmeyecek. Strict modda hata.
function TRadSqlFilter.SkipOrRaise(const AWhat: string): Boolean;
begin
  if FMode = rfmStrict then
    raise ERadSqlFilter.CreateFmt(SValueEmpty, [AWhat]);
  Result := True;
end;

function TRadSqlFilter.EscapeChar(AChar: Char): string;
begin
  if (AChar = '%') or (AChar = '_') or (AChar = ESCAPE_CHAR) or
     ((FDialect = sdMSSQL) and (AChar = '[')) then
    Result := ESCAPE_CHAR + AChar
  else
    Result := AChar;
end;

// Düz metin: joker yorumu yok, SQL jokerleri kaçırılır.
function TRadSqlFilter.EscapeAll(const AText: string): string;
var
  C: Char;
begin
  Result := '';
  for C in AText do
    Result := Result + EscapeChar(C);
end;

// Kullanıcı jokerleri → % ve _. AEscape açıkken diğer SQL jokerleri kaçırılır,
// çift yazılmış joker düz karakterdir.
function TRadSqlFilter.Translate(const APattern: string; AEscape: Boolean): string;
var
  i: Integer;
  C: Char;
begin
  Result := '';
  i := 1;
  while i <= Length(APattern) do
  begin
    C := APattern[i];
    if (C = FMany) or (C = FOne) then
    begin
      if AEscape and (i < Length(APattern)) and (APattern[i + 1] = C) then
      begin
        Result := Result + EscapeChar(C);
        Inc(i);
      end
      else if C = FMany then
        Result := Result + '%'
      else
        Result := Result + '_';
    end
    else if AEscape then
      Result := Result + EscapeChar(C)
    else
      Result := Result + C;
    Inc(i);
  end;
end;

{ karşılaştırma }

// Gün değeri: [gün, gün+1) yarı açık aralık; 23:59:59'un salise sorunu yok.
procedure TRadSqlFilter.CompareDay(const AField, AOp: string; ADay: TDateTime);
var
  LNext: TDateTime;
begin
  LNext := IncDay(ADay);
  if AOp = '=' then
    RangeCond(AField, ADay, LNext, False)
  else if AOp = '<>' then
    RangeCond(AField, ADay, LNext, True)
  else if AOp = '>' then
    AddCond(Format('%s >= %s', [AField, AddParam(LNext)]))
  else if AOp = '<=' then
    AddCond(Format('%s < %s', [AField, AddParam(LNext)]))
  else
    AddCond(Format('%s %s %s', [AField, AOp, AddParam(ADay)]));
end;

function TRadSqlFilter.Compare(const AField, AOp: string; const AValue: Variant;
  ACase: TRadCase): IRadSqlFilter;
var
  F, P: string;
begin
  Result := Self;
  F := CheckField(AField);
  if IsEmptyValue(AValue) and SkipOrRaise(F) then
    Exit;
  if IsDay(AValue) then
  begin
    CompareDay(F, AOp, AValue);
    Exit;
  end;
  P := AddParam(AValue);
  if IsText(AValue) and (EffCase(ACase) = rcInsensitive) then
  begin
    if FDialect = sdPostgreSQL then
      AddCond(Format('lower(%s) %s lower(%s)', [F, AOp, P]))
    else
      AddCond(Format('UPPER(%s) %s UPPER(%s)', [F, AOp, P]));
  end
  else
    AddCond(Format('%s %s %s', [F, AOp, P]));
end;

function TRadSqlFilter.Equal(const AField: string; const AValue: Variant; ACase: TRadCase): IRadSqlFilter;
begin
  Result := Compare(AField, '=', AValue, ACase);
end;

function TRadSqlFilter.NotEqual(const AField: string; const AValue: Variant; ACase: TRadCase): IRadSqlFilter;
begin
  Result := Compare(AField, '<>', AValue, ACase);
end;

function TRadSqlFilter.Greater(const AField: string; const AValue: Variant): IRadSqlFilter;
begin
  Result := Compare(AField, '>', AValue, rcDatabase);
end;

function TRadSqlFilter.GreaterEqual(const AField: string; const AValue: Variant): IRadSqlFilter;
begin
  Result := Compare(AField, '>=', AValue, rcDatabase);
end;

function TRadSqlFilter.Less(const AField: string; const AValue: Variant): IRadSqlFilter;
begin
  Result := Compare(AField, '<', AValue, rcDatabase);
end;

function TRadSqlFilter.LessEqual(const AField: string; const AValue: Variant): IRadSqlFilter;
begin
  Result := Compare(AField, '<=', AValue, rcDatabase);
end;

{ LIKE ailesi }

function TRadSqlFilter.LikeCore(const AField, AText: string; AKind: TLikeKind;
  AEscape, ANot: Boolean; ACase: TRadCase): IRadSqlFilter;
var
  F, V, Op, Esc: string;
begin
  Result := Self;
  F := CheckField(AField);
  case AKind of
    lkPattern:  V := Translate(AText, AEscape);
    lkContains: V := '%' + EscapeAll(AText) + '%';
    lkStarts:   V := EscapeAll(AText) + '%';
  else
    V := '%' + EscapeAll(AText);
  end;
  if (Trim(AText) = '') and SkipOrRaise(F) then
    Exit;
  // Yalnız çok-karakter jokeri: her şeyle eşleşir, SkipEmpty'de koşul yok.
  if (FMode = rfmSkipEmpty) and (V.Trim(['%']) = '') then
    Exit;
  if AKind <> lkPattern then
    AEscape := True;
  Esc := '';
  if AEscape then
    Esc := ESCAPE_SQL;
  if ANot then Op := 'NOT LIKE' else Op := 'LIKE';
  if EffCase(ACase) <> rcInsensitive then
    AddCond(Format('%s %s %s%s', [F, Op, AddParam(V), Esc]))
  else if FDialect = sdPostgreSQL then
    AddCond(Format('%s %s %s%s', [F, StringReplace(Op, 'LIKE', 'ILIKE', []), AddParam(V), Esc]))
  else
    AddCond(Format('UPPER(%s) %s UPPER(%s)%s', [F, Op, AddParam(V), Esc]));
end;

function TRadSqlFilter.Like(const AField, APattern: string; AEscape: Boolean; ACase: TRadCase): IRadSqlFilter;
begin
  Result := LikeCore(AField, APattern, lkPattern, AEscape, False, ACase);
end;

function TRadSqlFilter.NotLike(const AField, APattern: string; AEscape: Boolean; ACase: TRadCase): IRadSqlFilter;
begin
  Result := LikeCore(AField, APattern, lkPattern, AEscape, True, ACase);
end;

function TRadSqlFilter.Contains(const AField, AText: string; ACase: TRadCase): IRadSqlFilter;
begin
  Result := LikeCore(AField, AText, lkContains, True, False, ACase);
end;

function TRadSqlFilter.NotContains(const AField, AText: string; ACase: TRadCase): IRadSqlFilter;
begin
  Result := LikeCore(AField, AText, lkContains, True, True, ACase);
end;

function TRadSqlFilter.StartsWith(const AField, AText: string; ACase: TRadCase): IRadSqlFilter;
begin
  Result := LikeCore(AField, AText, lkStarts, True, False, ACase);
end;

function TRadSqlFilter.EndsWith(const AField, AText: string; ACase: TRadCase): IRadSqlFilter;
begin
  Result := LikeCore(AField, AText, lkEnds, True, False, ACase);
end;

{ liste ve aralık }

function TRadSqlFilter.InCore(const AField: string; const AValues: array of Variant;
  ANot: Boolean): IRadSqlFilter;
var
  F, L: string;
  V: Variant;
begin
  Result := Self;
  F := CheckField(AField);
  L := '';
  for V in AValues do
    if not (VarIsClear(V) or VarIsNull(V)) then
      L := L + ', ' + AddParam(V);
  if L = '' then
  begin
    if FMode = rfmStrict then
      if ANot then AddCond('1=1') else AddCond('1=0');
    Exit;
  end;
  L := L.Substring(2);
  if ANot then
    AddCond(Format('%s NOT IN (%s)', [F, L]))
  else
    AddCond(Format('%s IN (%s)', [F, L]));
end;

function TRadSqlFilter.InList(const AField: string; const AValues: array of Variant): IRadSqlFilter;
begin
  Result := InCore(AField, AValues, False);
end;

function TRadSqlFilter.NotInList(const AField: string; const AValues: array of Variant): IRadSqlFilter;
begin
  Result := InCore(AField, AValues, True);
end;

// [AFrom, ATo) yarı açık aralık; ANot ile tersi.
procedure TRadSqlFilter.RangeCond(const AField: string; const AFrom, ATo: Variant; ANot: Boolean);
begin
  if ANot then
    AddCond(Format('%s < %s OR %s >= %s', [AField, AddParam(AFrom), AField, AddParam(ATo)]))
  else
    AddCond(Format('%s >= %s AND %s < %s', [AField, AddParam(AFrom), AField, AddParam(ATo)]));
end;

function TRadSqlFilter.BetweenCore(const AField: string; const AFrom, ATo: Variant;
  ANot: Boolean): IRadSqlFilter;
var
  F, Op: string;
  NoFrom, NoTo: Boolean;
begin
  Result := Self;
  F := CheckField(AField);
  NoFrom := IsEmptyValue(AFrom);
  NoTo := IsEmptyValue(ATo);
  if NoFrom and NoTo and SkipOrRaise(F) then
    Exit;
  if (NoFrom or NoTo) and (FMode = rfmStrict) then
    raise ERadSqlFilter.CreateFmt(SBetweenHalf, [F]);
  if NoFrom then
    Compare(F, IfThen(ANot, '>', '<='), ATo, rcDatabase)
  else if NoTo then
    Compare(F, IfThen(ANot, '<', '>='), AFrom, rcDatabase)
  else if IsDay(ATo) then
    RangeCond(F, AFrom, IncDay(ATo), ANot)
  else
  begin
    if ANot then Op := 'NOT BETWEEN' else Op := 'BETWEEN';
    AddCond(Format('%s %s %s AND %s', [F, Op, AddParam(AFrom), AddParam(ATo)]));
  end;
end;

function TRadSqlFilter.Between(const AField: string; const AFrom, ATo: Variant): IRadSqlFilter;
begin
  Result := BetweenCore(AField, AFrom, ATo, False);
end;

function TRadSqlFilter.NotBetween(const AField: string; const AFrom, ATo: Variant): IRadSqlFilter;
begin
  Result := BetweenCore(AField, AFrom, ATo, True);
end;

function TRadSqlFilter.IsNull(const AField: string): IRadSqlFilter;
begin
  AddCond(CheckField(AField) + ' IS NULL');
  Result := Self;
end;

function TRadSqlFilter.IsNotNull(const AField: string): IRadSqlFilter;
begin
  AddCond(CheckField(AField) + ' IS NOT NULL');
  Result := Self;
end;

function TRadSqlFilter.Raw(const ASql: string; const AValues: array of Variant): IRadSqlFilter;
var
  S: string;
  i, N: Integer;
begin
  Result := Self;
  if Trim(ASql) = '' then
    raise ERadSqlFilter.Create(SRawEmpty);
  N := ASql.CountChar('?');
  if N <> Length(AValues) then
    raise ERadSqlFilter.CreateFmt(SRawCount, [N, Length(AValues)]);
  S := '';
  N := 0;
  for i := 1 to Length(ASql) do
    if ASql[i] = '?' then
    begin
      S := S + AddParam(AValues[N]);
      Inc(N);
    end
    else
      S := S + ASql[i];
  AddCond(S);
end;

function TRadSqlFilter.BeginOr: IRadSqlFilter;
begin
  if FGroup <> 0 then
    raise ERadSqlFilter.Create(SOrGroupOpen);
  Inc(FGroupSeq);
  FGroup := FGroupSeq;
  Result := Self;
end;

function TRadSqlFilter.EndOr: IRadSqlFilter;
begin
  if FGroup = 0 then
    raise ERadSqlFilter.Create(SOrGroupNone);
  FGroup := 0;
  Result := Self;
end;

function TRadSqlFilter.AddOrderBy(const AField: string; ADesc: Boolean): IRadSqlFilter;
begin
  if not ValidName(AField, True) then
    raise ERadSqlFilter.CreateFmt(SBadName, [AField]);
  if ADesc then
    FOrder.Add(AField + ' DESC')
  else
    FOrder.Add(AField + ' ASC');
  Result := Self;
end;

{ çıktı }

// AFrom'daki koşulun grubunu birleştirir; ANext bir sonraki işlenecek indeks.
function TRadSqlFilter.GroupSql(AFrom: Integer; out ANext: Integer): string;
var
  G, N: Integer;
begin
  G := FConds[AFrom].Group;
  Result := FConds[AFrom].Sql;
  ANext := AFrom + 1;
  if G = 0 then
    Exit;
  N := 1;
  while (ANext < FConds.Count) and (FConds[ANext].Group = G) do
  begin
    Result := Result + ' OR ' + FConds[ANext].Sql;
    Inc(ANext);
    Inc(N);
  end;
  if N > 1 then
    Result := '(' + Result + ')';
end;

function TRadSqlFilter.GetConditions: string;
var
  i: Integer;
  S: string;
begin
  if FGroup <> 0 then
    raise ERadSqlFilter.Create(SOrGroupNotClosed);
  Result := '';
  i := 0;
  while i < FConds.Count do
  begin
    S := GroupSql(i, i);
    if Result <> '' then
      Result := Result + ' AND ';
    Result := Result + S;
  end;
end;

function TRadSqlFilter.GetWhere: string;
begin
  Result := GetConditions;
  if Result <> '' then
    Result := 'WHERE ' + Result;
end;

function TRadSqlFilter.GetOrderByFields: string;
begin
  Result := string.Join(', ', FOrder.ToArray);
end;

function TRadSqlFilter.GetOrderBy: string;
begin
  if FOrder.Count = 0 then
    Result := ''
  else
    Result := 'ORDER BY ' + GetOrderByFields;
end;

function TRadSqlFilter.GetSql: string;
begin
  Result := Trim(GetWhere + ' ' + GetOrderBy);
end;

// Yalnız okunabilirlik için; lehçeye göre kabaca biçimlenir, çalıştırılmaz.
function TRadSqlFilter.DebugLiteral(const AValue: Variant): string;
var
  T: TVarType;
  D: TDateTime;
begin
  T := VarType(AValue);
  if VarIsClear(AValue) or VarIsNull(AValue) then
    Exit('NULL');
  if T = varBoolean then
  begin
    if FDialect in [sdMSSQL, sdMySQL] then
      Exit(IfThen(AValue, '1', '0'));
    Exit(IfThen(AValue, 'true', 'false'));
  end;
  if T = varDate then
  begin
    D := AValue;
    if Frac(D) = 0 then
      Exit(QuotedStr(FormatDateTime('yyyy-mm-dd', D)));
    Exit(QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss', D)));
  end;
  if IsText(AValue) then
    Exit(QuotedStr(VarToStr(AValue)));
  Result := VarToStr(AValue).Replace(',', '.');
end;

function TRadSqlFilter.GetDebugSql: string;
var
  i: Integer;
begin
  Result := GetSql;
  // Sondan başa: :p10, :p1'den önce değişir.
  for i := FParams.Count - 1 downto 0 do
    Result := Result.Replace(':' + FParams[i].Name, DebugLiteral(FParams[i].Value));
end;

function TRadSqlFilter.Params: TArray<TRadSqlParam>;
begin
  Result := FParams.ToArray;
end;

function TRadSqlFilter.ParamCount: Integer;
begin
  Result := FParams.Count;
end;

function TRadSqlFilter.IsEmpty: Boolean;
begin
  Result := FConds.Count = 0;
end;

function TRadSqlFilter.ClearConditions: IRadSqlFilter;
begin
  FConds.Clear;
  FParams.Clear;
  FCounter := 0;
  FGroup := 0;
  FGroupSeq := 0;
  Result := Self;
end;

function TRadSqlFilter.ClearOrderBy: IRadSqlFilter;
begin
  FOrder.Clear;
  Result := Self;
end;

function TRadSqlFilter.Clear: IRadSqlFilter;
begin
  ClearConditions;
  Result := ClearOrderBy;
end;

end.
