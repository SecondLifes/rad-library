unit rad.searchexpr;

{ Liste "genel arama" kutusunun ifade çözümleyicisi. Veritabanına bağlı değildir;
  yalnız metni terimlere ayırır ve her terimi alanın türüne göre IRadSqlFilter'a yazar.

  Söz dizimi (boşlukla ayrılan her terim ayrı bir koşuldur, terimler AND ile birleşir;
  bir terim işaretli alanlar arasında OR ile aranır):
    kelime            metin alanında içerir; sayı/tarih/evet-hayır alanında eşit
    "iki kelime"      tırnak içi tek terimdir
    =kelime           metin alanında tam eşit (harf duyarsız)
    >5  >=5  <5  <=5  yalnız sayı ve tarih alanında
    <>5  !=5          eşit değil (sayı, tarih, evet/hayır alanında)
    10..20  10..  ..20  aralık (sayı ve tarih alanında)
    kasa*  *5595  a*b  a?c  metin alanında joker: * her şey, ? tek karakter; sabit başlangıç/bitiş
                      ya da ortada boşluk için tırnak kullanın ("0 555*"); \* \? \\ düz karakterdir
  Rakam alanı (skDigits, örn. telefon): geliştirici ifadesi rakam dışını atar; terimin de rakam
  dışı karakterleri atılır, böylece "0555 557" ile "0(555)557-" aynı sonucu verir.
  Terim bir alanın türüne uymuyorsa o alan o terimin aramasına girmez. Metin alanında
  operatör anlamsızdır; terim yazıldığı gibi düz metin olarak aranır. }

interface

uses
  System.SysUtils, System.Variants, rad.sqlfilter;

type
  TRadSearchKind = (skText, skInteger, skDecimal, skDate, skBoolean, skDigits);
  TRadSearchOp = (soContains, soEqual, soNotEqual, soGreater, soGreaterEqual, soLess,
    soLessEqual, soRange);

  TRadSearchTerm = record
    Op: TRadSearchOp;
    Operand: string;    // operatörsüz değer; aralıkta alt sınır
    Operand2: string;   // yalnız aralıkta üst sınır
    Literal: string;    // metin alanında aranan düz metin (operatör dahil, tırnaksız, kaçışlar çözülmüş)
    Raw: string;        // operatör + işlenmemiş değer (kaçışlar duruyor)
    RawOperand: string; // işlenmemiş değer
    HasWild: Boolean;   // kaçışsız * ya da ? var
  end;
  TRadSearchTerms = TArray<TRadSearchTerm>;

/// <summary>Arama kutusu metnini terimlere ayırır; boş metin için boş dizi döner.</summary>
function RadSearchParse(const AInput: string): TRadSearchTerms;

/// <summary>Metni alan türüne göre değere çevirir; tür uymuyorsa False.
/// Tamsayı yalnız rakam, ondalık '1.234,56' / '1,234.56' / '12.5' (üstel yazım yok),
/// tarih yerel biçim ya da ISO 8601.</summary>
function RadSearchValue(const AText: string; AKind: TRadSearchKind; out AValue: Variant): Boolean;

/// <summary>Terimi AField ifadesi için AFilter'a koşul olarak ekler; terim bu türe uymuyorsa
/// hiçbir şey eklemez ve False döner. AField yalnız geliştirici kodundan gelmelidir.</summary>
function RadSearchApply(const AFilter: IRadSqlFilter; const AField: string;
  AKind: TRadSearchKind; const ATerm: TRadSearchTerm): Boolean;

implementation

const
  OperatorTable: array[0..6] of record Text: string; Op: TRadSearchOp; end = (
    (Text: '>='; Op: soGreaterEqual), (Text: '<='; Op: soLessEqual),
    (Text: '<>'; Op: soNotEqual), (Text: '!='; Op: soNotEqual),
    (Text: '>'; Op: soGreater), (Text: '<'; Op: soLess), (Text: '='; Op: soEqual));

// i konumundaki operatörü okur; yoksa soContains, uzunluk 0.
function ReadOperator(const S: string; i: Integer; out ALen: Integer): TRadSearchOp;
var
  k: Integer;
begin
  Result := soContains;
  ALen := 0;
  for k := Low(OperatorTable) to High(OperatorTable) do
    if Copy(S, i, Length(OperatorTable[k].Text)) = OperatorTable[k].Text then
    begin
      ALen := Length(OperatorTable[k].Text);
      Exit(OperatorTable[k].Op);
    end;
end;

// Kaçışları çözer, jokerleri LIKE desenine çevirir (kaçış karakteri '!'). ADigitsOnly: rakam dışı
// karakterler atılır. ALiteral jokerleri olduğu gibi (* ?) bırakır.
procedure ScanText(const ARaw: string; ADigitsOnly: Boolean; out ALiteral, APattern: string;
  out AWild: Boolean);
var
  i: Integer;
  C: Char;
  LLastMany: Boolean;

  procedure AddLiteral(AChar: Char);
  begin
    if ADigitsOnly and not CharInSet(AChar, ['0'..'9']) then
      Exit;
    ALiteral := ALiteral + AChar;
    if CharInSet(AChar, ['!', '%', '_']) then
      APattern := APattern + '!';
    APattern := APattern + AChar;
    LLastMany := False;
  end;

begin
  ALiteral := '';
  APattern := '';
  AWild := False;
  LLastMany := False;
  i := 1;
  while i <= Length(ARaw) do
  begin
    C := ARaw[i];
    if (C = '\') and (i < Length(ARaw)) and CharInSet(ARaw[i + 1], ['*', '?', '\']) then
    begin
      Inc(i);
      AddLiteral(ARaw[i]);
    end
    else if C = '*' then
    begin
      AWild := True;
      if not LLastMany then
      begin
        ALiteral := ALiteral + C;
        APattern := APattern + '%';
        LLastMany := True;
      end;
    end
    else if C = '?' then
    begin
      AWild := True;
      ALiteral := ALiteral + C;
      APattern := APattern + '_';
      LLastMany := False;
    end
    else
      AddLiteral(C);
    Inc(i);
  end;
end;

// Operatör ve joker çevresindeki boşlukları atar: "> 1" -> ">1", "0 555 *" -> "0 555*", "10 .. 20" -> "10..20".
// Tırnak içine dokunmaz. Operatör yalnız terimin başındaysa sayılır ("ahmet >5" iki terimdir).
function StripSpaceAroundOps(const S: string): string;
var
  i, j, n, LTok, LLen, LBack: Integer;
  LQuote, LDrop: Boolean;
  LPrev: Char;
  LTokText: string;
begin
  Result := '';
  n := Length(S);
  LTok := 1;
  LQuote := False;
  i := 1;
  while i <= n do
  begin
    if LQuote or (S[i] > ' ') then
    begin
      if S[i] = '"' then
        LQuote := not LQuote;
      Result := Result + S[i];
      Inc(i);
      Continue;
    end;
    j := i;
    while (j <= n) and (S[j] <= ' ') do
      Inc(j);
    LDrop := False;
    if (Result <> '') and (j <= n) then
    begin
      LTokText := Copy(Result, LTok, MaxInt);
      ReadOperator(LTokText, 1, LLen);
      LDrop := (LLen > 0) and (LLen = Length(LTokText));
      LPrev := Result[Length(Result)];
      LBack := 0;
      while (Length(Result) - LBack - 1 >= 1) and (Result[Length(Result) - LBack - 1] = Chr(92)) do
        Inc(LBack);
      if (S[j] <> '"') and ((LPrev in ['*', '?']) and (LBack mod 2 = 0)) then
        LDrop := True;
      if (S[j] in ['*', '?']) or (Copy(S, j, 2) = '..') or LTokText.EndsWith('..') then
        LDrop := True;
    end
    else
      LDrop := (j <= n) and (S[j] in ['*', '?']);
    if not LDrop and (j <= n) and (Result <> '') then
    begin
      Result := Result + ' ';
      LTok := Length(Result) + 1;
    end;
    i := j;
  end;
end;

function RadSearchParse(const AInput: string): TRadSearchTerms;
var
  LInput: string;
  i, n, LOpLen, LP: Integer;
  LPat: string;
  LWild: Boolean;
  LOp: TRadSearchOp;
  LOpText, LOperand: string;
  LQuoted: Boolean;
  LTerm: TRadSearchTerm;
begin
  Result := nil;
  LInput := StripSpaceAroundOps(AInput);
  n := Length(LInput);
  i := 1;
  while i <= n do
  begin
    if LInput[i] <= ' ' then
    begin
      Inc(i);
      Continue;
    end;
    LOp := ReadOperator(LInput, i, LOpLen);
    LOpText := Copy(LInput, i, LOpLen);
    Inc(i, LOpLen);
    LQuoted := (i <= n) and (LInput[i] = '"');
    LOperand := '';
    if LQuoted then
    begin
      Inc(i);
      while (i <= n) and (LInput[i] <> '"') do
      begin
        LOperand := LOperand + LInput[i];
        Inc(i);
      end;
      Inc(i);   // kapanış tırnağı (yoksa metin sonu)
    end
    else
      while (i <= n) and (LInput[i] > ' ') do
      begin
        LOperand := LOperand + LInput[i];
        Inc(i);
      end;
    if (LOperand = '') and not LQuoted then
    begin
      LOp := soContains;      // yalnız operatör yazıldı: düz metin say
      LOperand := LOpText;
      LOpText := '';
    end;
    if LOperand = '' then
      Continue;
    LTerm := Default(TRadSearchTerm);
    LTerm.Op := LOp;
    LTerm.Raw := LOpText + LOperand;
    LTerm.RawOperand := LOperand;
    ScanText(LOperand, False, LTerm.Operand, LPat, LTerm.HasWild);
    ScanText(LTerm.Raw, False, LTerm.Literal, LPat, LWild);
    LP := Pos('..', LTerm.Operand);
    if (not LQuoted) and (LOpLen = 0) and (LP > 0) and (Length(LTerm.Operand) > 2) and
      not LTerm.HasWild then
    begin
      LTerm.Op := soRange;
      LTerm.Operand2 := Copy(LTerm.Operand, LP + 2, MaxInt);
      LTerm.Operand := Copy(LTerm.Operand, 1, LP - 1);
    end;
    Result := Result + [LTerm];
  end;
end;

// Yalnız [+-] ve rakamlardan oluşuyor mu (TryStrToInt64 '$FF' gibi onaltılık yazımı da kabul eder).
function IsIntegerText(const S: string): Boolean;
var
  i: Integer;
begin
  Result := S <> '';
  for i := 1 to Length(S) do
    if not (CharInSet(S[i], ['0'..'9']) or ((i = 1) and CharInSet(S[i], ['+', '-']))) then
      Exit(False);
  if Result and (Length(S) = 1) and CharInSet(S[1], ['+', '-']) then
    Result := False;
end;

// '1.234,56' ve '1,234.56' tek ayırıcılı biçime çevrilir; tek ayırıcı ondalık sayılır.
function NormalizeDecimal(const S: string): string;
var
  LDot, LComma: Integer;
begin
  Result := S;
  LDot := LastDelimiter('.', Result);
  LComma := LastDelimiter(',', Result);
  if (LDot > 0) and (LComma > 0) then
  begin
    if LComma > LDot then
      Result := StringReplace(Result, '.', '', [rfReplaceAll])
    else
      Result := StringReplace(Result, ',', '', [rfReplaceAll]);
  end;
  Result := StringReplace(Result, ',', '.', [rfReplaceAll]);
end;

function IsDecimalText(const S: string): Boolean;
var
  i: Integer;
begin
  Result := S <> '';
  for i := 1 to Length(S) do
    if not (CharInSet(S[i], ['0'..'9', '.']) or ((i = 1) and CharInSet(S[i], ['+', '-']))) then
      Exit(False);
end;

function IsoDateFormat: TFormatSettings;
begin
  Result := TFormatSettings.Invariant;
  Result.ShortDateFormat := 'yyyy-mm-dd';
  Result.DateSeparator := '-';
end;

function RadSearchValue(const AText: string; AKind: TRadSearchKind; out AValue: Variant): Boolean;
var
  LInt: Int64;
  LDec: Double;
  LDate: TDateTime;
  LNorm, LLower: string;
begin
  Result := False;
  case AKind of
    skText, skDigits:
      begin
        AValue := AText;
        Result := True;
      end;
    skInteger:
      if IsIntegerText(AText) and TryStrToInt64(AText, LInt) then
      begin
        AValue := LInt;
        Result := True;
      end;
    skDecimal:
      begin
        LNorm := NormalizeDecimal(AText);
        if IsDecimalText(LNorm) and TryStrToFloat(LNorm, LDec, TFormatSettings.Invariant) then
        begin
          AValue := LDec;
          Result := True;
        end;
      end;
    skDate:
      if TryStrToDate(AText, LDate) or TryStrToDate(AText, LDate, IsoDateFormat) then
      begin
        AValue := LDate;
        Result := True;
      end;
    skBoolean:
      begin
        LLower := LowerCase(AText);
        if (LLower = 'evet') or (LLower = 'e') or (LLower = 'true') or (LLower = '1') or
          (LLower = 'aktif') or (LLower = 'var') then
        begin
          AValue := True;
          Result := True;
        end
        else if (LLower = 'hayır') or (LLower = 'hayir') or (LLower = 'h') or (LLower = 'false') or
          (LLower = '0') or (LLower = 'pasif') or (LLower = 'yok') then
        begin
          AValue := False;
          Result := True;
        end;
      end;
  end;
end;

// shortcut: joker koşulu PostgreSQL ILIKE ile yazılır, başka lehçe gerekirse rad.sqlfilter'a taşınır.
function ApplyText(const AFilter: IRadSqlFilter; const AField: string;
  const ATerm: TRadSearchTerm): Boolean;
var
  LExpr, LLiteral, LPattern: string;
  LWild: Boolean;
begin
  LExpr := 'cast(' + AField + ' as text)';
  if ATerm.Op = soEqual then
    ScanText(ATerm.RawOperand, False, LLiteral, LPattern, LWild)
  else
    ScanText(ATerm.Raw, False, LLiteral, LPattern, LWild);
  if LWild then
    AFilter.Raw(LExpr + ' ILIKE ? ESCAPE ''!''', [LPattern])
  else if ATerm.Op = soEqual then
    AFilter.Equal(LExpr, LLiteral, rcInsensitive)
  else
    AFilter.Contains(LExpr, LLiteral, rcInsensitive);
  Result := True;
end;

// AField rakam dışını atan bir ifade olmalı; terimin rakam dışı karakterleri de atılır.
function ApplyDigits(const AFilter: IRadSqlFilter; const AField: string;
  const ATerm: TRadSearchTerm): Boolean;
var
  LLiteral, LPattern: string;
  LWild: Boolean;
begin
  ScanText(ATerm.Raw, True, LLiteral, LPattern, LWild);
  if LLiteral = '' then
    Exit(False);
  if LWild then
    AFilter.Raw(AField + ' LIKE ? ESCAPE ''!''', [LPattern])
  else
    AFilter.Contains(AField, LLiteral);
  Result := True;
end;

function ApplyTyped(const AFilter: IRadSqlFilter; const AField: string; AKind: TRadSearchKind;
  const ATerm: TRadSearchTerm): Boolean;
var
  V, V2: Variant;
begin
  Result := False;
  if ATerm.HasWild then
    Exit;
  if ATerm.Op = soRange then
  begin
    if AKind = skBoolean then
      Exit;
    V := Null;
    V2 := Null;
    if (ATerm.Operand <> '') and not RadSearchValue(ATerm.Operand, AKind, V) then
      Exit;
    if (ATerm.Operand2 <> '') and not RadSearchValue(ATerm.Operand2, AKind, V2) then
      Exit;
    AFilter.Between(AField, V, V2);
    Exit(True);
  end;
  if not RadSearchValue(ATerm.Operand, AKind, V) then
    Exit;
  if (AKind = skBoolean) and not (ATerm.Op in [soContains, soEqual, soNotEqual]) then
    Exit;
  case ATerm.Op of
    soNotEqual: AFilter.NotEqual(AField, V);
    soGreater: AFilter.Greater(AField, V);
    soGreaterEqual: AFilter.GreaterEqual(AField, V);
    soLess: AFilter.Less(AField, V);
    soLessEqual: AFilter.LessEqual(AField, V);
  else
    AFilter.Equal(AField, V);
  end;
  Result := True;
end;

function RadSearchApply(const AFilter: IRadSqlFilter; const AField: string;
  AKind: TRadSearchKind; const ATerm: TRadSearchTerm): Boolean;
begin
  case AKind of
    skText: Result := ApplyText(AFilter, AField, ATerm);
    skDigits: Result := ApplyDigits(AFilter, AField, ATerm);
  else
    Result := ApplyTyped(AFilter, AField, AKind, ATerm);
  end;
end;

end.
