unit help.str;

{
  TRadStringHelper — string için genel amaçlı record helper.

  DOSYA ADI NOTU (2026-07-09): Bu ünite önceden `help.string.pas` (unit
  help.string;) idi — bu, dcc32'de GERÇEK bir derleme hatasıydı: `string`
  Delphi'de ayrılmış (reserved) bir kelime olduğu için noktalı unit adının
  bileşeni olamıyor (E2029 "Identifier expected but 'STRING' found", minimal
  bir repro ile doğrulandı). Ünite hiçbir projeye bağlı olmadığı için (RunTests
  .dproj/.dpr, RadKon.dpk'da yoktu) bu şimdiye kadar hiç fark edilmemişti.
  `help.str` olarak yeniden adlandırıldı — bkz. project_delphi_compiler_quirks.md.

  MİMARİ NOT (ÖNEMLİ — 2026-07-09 GÜNCELLEMESİ): Delphi'nin RTL'i (System.SysUtils)
  `string` tipi için zaten native bir `TStringHelper` sağlıyor (Trim/ToUpper/
  ToLower/Split/StartsWith/EndsWith/PadLeft/PadRight/Contains vb.). Bu unit'teki
  TÜM metotlar çakışmayı azaltmak için `_` önekiyle isimlendirildi, AMA gerçek
  `dcc32` derlemesiyle doğrulandı ki bu TEK BAŞINA YETERLİ DEĞİL: Delphi'de bir
  tip için birden fazla helper aktif olduğunda sadece EN YAKINI kullanılabiliyor
  ve bu "en yakınlık" o helper'ın GÖRÜNÜR OLDUĞU TÜM UNIT boyunca geçerli — yani
  `TRadStringHelper` görünürse, native `TStringHelper`'ın `_` önekli OLMAYAN
  metotları (`AStr.Trim`, `AStr.StartsWith` vb.) o unit'in HER YERİNDE (sadece
  bu dosyanın implementasyonu değil) E2003 Undeclared identifier ile tamamen
  görünmez olur — küçük bir repro ile doğrulandı (bkz.
  project_delphi_compiler_quirks.md). Bu yüzden bu dosyanın implementasyonu
  artık native helper metotlarına HİÇ dot-syntax ile dokunmuyor; onun yerine
  extension/dot-syntax OLMAYAN düz RTL fonksiyonlarını kullanıyor
  (`System.SysUtils.Trim(S)`, `System.StrUtils.StartsStr/EndsStr/ContainsStr`)
  — sıradan fonksiyon çağrısı oldukları için helper gölgelemesinden etkilenmiyorlar.
  SONUÇ (çağıran kod için): help.str.pas'ı `uses` eden bir unit'te native
  `TStringHelper` metotlarına da (`AStr.Trim` gibi) dot-syntax ile ihtiyaç
  varsa ve `TRadStringHelper` o unit'te daha yakın helper ise, AYNI gölgeleme
  orada da geçerlidir — native ihtiyaç için düz `Trim(S)`/`StrUtils` fonksiyonu
  kullanılmalı, `AStr.Trim` değil.

  Bu nedenle RTL'in native TStringHelper'ında zaten dot-syntax ile aynı
  ergonomiyle var olan metotlar (Trim, ToUpper, ToLower, PadLeft, PadRight,
  Split, StartsWith, EndsWith) buraya TEKRAR eklenmedi — ince bir `_`
  sarmalayıcının gerçek bir ergonomik kazancı olmazdı (bkz. delphi-helper-
  builder skill'indeki "GEÇERSİZ dışlama gerekçesi" kuralı: bu istisna değil,
  kuralın ruhuna uygun bir ayrım — kural "RTL'de free function var" diye
  atmayı yasaklıyor, "aynı tipte native METOD zaten var" durumunu değil).

  Kaynaklar (delphi-helper-builder skill ile analiz edildi, bkz. docs\vendor\...):
    - GpString.pas (gabr42)                — PosR, HexStr fikirleri (çoğu fonksiyon modern RTL Split ile örtüştüğü için alınmadı)
    - JclStrings.pas (JEDI JCL)             — Ensure(No)Prefix/Suffix, Center, Repeat, Reverse, Is*, HasPrefix/Suffix, CompareNatural, Between/Before/After
    - mormot.core.unicode.pas (mORMot2)     — string<->RawUtf8/WinAnsiString köprüsü, IsUpper/IsLower fikri
    - System.Masks (RTL, ayrı unit)         — MatchesMask için ince sarmalayıcı (_IsWildcardMatch)

  CamelCase/PascalCase/SnakeCase dönüşümleri mORMot2'nin CamelCase/UnCamelCase
  fonksiyonlarından ilham aldı ama BAĞIMSIZ yazıldı (kendi sözcük-bölme
  mantığımız — mORMot2'nin identifier-özel varsayımlarına bağımlı değil,
  test edilmesi/doğrulanması daha kolay).

  Türkçe-duyarlı büyük/küçük harf dönüşümü (_ToUpperTR/_ToLowerTR/_ToTitleCase)
  İCAT — RTL'in UpperCase/ToUpper'ı Unicode invariant-case kullanır, 'i' harfini
  Türkçe 'İ' değil düz 'I' yapar; bu üç metot i/İ/ı/I harflerini özel olarak
  eşleyerek bu klasik Türkçe Delphi hatasını düzeltir.

  Büyük/karmaşık işler statik core fonksiyon + ince helper wrapper modeliyle
  yazıldı (TrCharUpper/TrCharLower/SplitIntoWords). RawUtf8/mORMot2 tipleri
  sadece dönüşüm metotlarında (_ToUtf8 vb.) görünür, geri kalan API standart
  `string` kullanır.

  SINIRLAMA (surrogate pair): `_Reverse`, `_ToUpperTR` ve `_ToLowerTR` UTF-16
  code unit bazlı çalışır — emoji gibi surrogate pair (2 code unit) veya
  combining mark içeren metinlerde Unicode grapheme farkındalığı YOKTUR
  (`_Reverse` iki code unit'i ters çevirip geçersiz bir dizi üretebilir).
  Bu metotlar çoğunlukla ASCII/Türkçe alfabe metinleri için tasarlandı.
}

interface

uses
  System.SysUtils, mormot.core.base;

type
  TRadStringHelper = record helper for string
  public
    { ===== RawUtf8 / mORMot2 köprüsü ===== }
    function _ToUtf8: RawUtf8;
    function _ToWinAnsi: WinAnsiString;
    function _ToBytesUtf8: TBytes;
    class function _FromUtf8(const AUtf8: RawUtf8): string; static;
    class function _FromWinAnsi(const AWinAnsi: WinAnsiString): string; static;
    class function _FromBytesUtf8(const ABytes: TBytes): string; static;

    { ===== Türkçe-duyarlı büyük/küçük harf (icat) ===== }
    function _ToUpperTR: string;
    function _ToLowerTR: string;
    function _ToTitleCase: string;
    function _ToCamelCase: string;
    function _ToPascalCase: string;
    function _ToSnakeCase: string;
    function _IsUpper: Boolean;
    function _IsLower: Boolean;

    { ===== Kırpma / Doldurma / Ortalama ===== }
    function _Center(ALen: Integer; AChar: Char = ' '): string;
    function _Truncate(AMaxLen: Integer; const AEllipsis: string = '...'): string;
    function _Mask(AVisibleStart, AVisibleEnd: Integer; AMaskChar: Char = '*'): string;
    function _RepeatText(ACount: Integer): string;
    function _Reverse: string;

    { ===== Guard / Ensure (icat) ===== }
    function _EnsurePrefix(const APrefix: string): string;
    function _EnsureSuffix(const ASuffix: string): string;
    function _EnsureNoPrefix(const APrefix: string): string;
    function _EnsureNoSuffix(const ASuffix: string): string;
    function _DefaultIfEmpty(const ADefault: string): string;
    function _DefaultIfWhiteSpace(const ADefault: string): string;

    { ===== Sayısal/Boolean güvenli dönüşüm (icat) ===== }
    function _ToIntOrDefault(ADefault: Integer = 0): Integer;
    function _ToInt64OrDefault(ADefault: Int64 = 0): Int64;
    function _ToFloatOrDefault(ADefault: Double = 0): Double;
    function _ToBoolOrDefault(ADefault: Boolean = False): Boolean;
    function _TryToInt(out AValue: Integer): Boolean;
    function _TryToFloat(out AValue: Double): Boolean;

    { ===== Test / Karşılaştırma ===== }
    function _IsAlpha: Boolean;
    function _IsAlphaNumeric: Boolean;
    function _IsDigitsOnly: Boolean;
    function _IsOneOf(const AList: array of string; ACaseSensitive: Boolean = False): Boolean;
    function _EqualsIgnoreCase(const AOther: string): Boolean;
    function _HasPrefixOf(const APrefixes: array of string; ACaseSensitive: Boolean = True): Boolean;
    function _HasSuffixOf(const ASuffixes: array of string; ACaseSensitive: Boolean = True): Boolean;
    function _ContainsAny(const AList: array of string): Boolean;
    function _ContainsAll(const AList: array of string): Boolean;
    function _CompareNatural(const AOther: string): Integer;
    function _LevenshteinDistance(const AOther: string): Integer;
    function _SimilarityRatio(const AOther: string): Double;
    function _IsWildcardMatch(const APattern: string): Boolean;

    { ===== Çıkarma (Extraction) ===== }
    function _Left(ACount: Integer): string;
    function _Right(ACount: Integer): string;
    function _Before(const ASub: string): string;
    function _After(const ASub: string): string;
    function _Between(const AStart, AEnd: string): string;
    function _SplitTrimmed(const ADelimiter: string; ARemoveEmpty: Boolean = True): TArray<string>;

    { ===== Diziler ile ilişki ===== }
    class function _Join(const ASeparator: string; const AValues: array of string): string; static;
  end;

implementation

uses
  System.StrUtils, System.Character, System.Math,
  System.Masks, System.Generics.Collections,
  mormot.core.unicode;

{ Türkçe-duyarlı tek karakter dönüşümü (üç metot tarafından paylaşılıyor) }

function TrCharUpper(const C: Char): Char;
begin
  case C of
    'i': Result := 'İ';
    'ı': Result := 'I';
  else
    Result := System.Character.TCharacter.ToUpper(C);
  end;
end;

function TrCharLower(const C: Char): Char;
begin
  case C of
    'I': Result := 'ı';
    'İ': Result := 'i';
  else
    Result := System.Character.TCharacter.ToLower(C);
  end;
end;

{ CamelCase/PascalCase/SnakeCase için ortak sözcük bölme: harf/rakam dizileri
  sözcük; sözcük sınırları üç durumda tetiklenir: (1) küçükten BÜYÜĞE geçiş
  (camelCase), (2) rakamdan BÜYÜK harfe geçiş (ör. "SHA256Hash" -> "SHA256" +
  "Hash"), (3) ardışık BÜYÜK harflerden küçük harfe geçiş / acronym sonu (ör.
  "HTTPServer" -> "HTTP" + "Server", son BÜYÜK harf bir sonraki sözcüğe kalır).
  Diğer her şey ayırıcı olarak atılır. }
function SplitIntoWords(const S: string): TArray<string>;
var
  LWords: TList<string>;
  LCurrent: string;
  i: Integer;
  LChar: Char;
begin
  LWords := TList<string>.Create;
  try
    LCurrent := '';
    for i := 1 to Length(S) do
    begin
      LChar := S[i];
      if System.Character.TCharacter.IsLetterOrDigit(LChar) then
      begin
        if (LCurrent <> '') and System.Character.TCharacter.IsUpper(LChar) and
           System.Character.TCharacter.IsLower(LCurrent[Length(LCurrent)]) then
        begin
          // (1) camelCase: kucukten BUYUGE gecis
          LWords.Add(LCurrent);
          LCurrent := LChar;
        end
        else if (LCurrent <> '') and System.Character.TCharacter.IsUpper(LChar) and
                System.Character.TCharacter.IsDigit(LCurrent[Length(LCurrent)]) then
        begin
          // (2) rakamdan BUYUK harfe gecis
          LWords.Add(LCurrent);
          LCurrent := LChar;
        end
        else if (Length(LCurrent) >= 2) and
                System.Character.TCharacter.IsLower(LChar) and
                System.Character.TCharacter.IsUpper(LCurrent[Length(LCurrent)]) and
                System.Character.TCharacter.IsUpper(LCurrent[Length(LCurrent) - 1]) then
        begin
          // (3) ardisik BUYUK harflerden kucuge gecis: son BUYUK harf yeni sozcuge kalir
          LWords.Add(Copy(LCurrent, 1, Length(LCurrent) - 1));
          LCurrent := LCurrent[Length(LCurrent)] + LChar;
        end
        else
          LCurrent := LCurrent + LChar;
      end
      else if LCurrent <> '' then
      begin
        LWords.Add(LCurrent);
        LCurrent := '';
      end;
    end;
    if LCurrent <> '' then
      LWords.Add(LCurrent);
    Result := LWords.ToArray;
  finally
    LWords.Free;
  end;
end;

{ TStringHelper.Split ile ayni semantik (coklu karakterli alt-dize ayirici,
  karakter kumesi DEGIL) - native helper golgelendigi icin dot-syntax yerine
  duz fonksiyon olarak yeniden yazildi. }
function SplitBySubstring(const S, ADelimiter: string): TArray<string>;
var
  LList: TList<string>;
  LStart, LPos, LDelimLen: Integer;
begin
  LList := TList<string>.Create;
  try
    if ADelimiter = '' then
      LList.Add(S)
    else
    begin
      LDelimLen := Length(ADelimiter);
      LStart := 1;
      repeat
        LPos := System.Pos(ADelimiter, S, LStart);
        if LPos = 0 then
        begin
          LList.Add(Copy(S, LStart, MaxInt));
          Break;
        end;
        LList.Add(Copy(S, LStart, LPos - LStart));
        LStart := LPos + LDelimLen;
      until False;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

{ RawUtf8 / mORMot2 köprüsü }

function TRadStringHelper._ToUtf8: RawUtf8;
begin
  Result := StringToUtf8(Self);
end;

function TRadStringHelper._ToWinAnsi: WinAnsiString;
begin
  Result := StringToWinAnsi(Self);
end;

function TRadStringHelper._ToBytesUtf8: TBytes;
begin
  Result := TEncoding.UTF8.GetBytes(Self);
end;

class function TRadStringHelper._FromUtf8(const AUtf8: RawUtf8): string;
begin
  Result := Utf8ToString(AUtf8);
end;

class function TRadStringHelper._FromWinAnsi(const AWinAnsi: WinAnsiString): string;
begin
  Result := WinAnsiToUnicodeString(AWinAnsi);
end;

class function TRadStringHelper._FromBytesUtf8(const ABytes: TBytes): string;
begin
  Result := TEncoding.UTF8.GetString(ABytes);
end;

{ Türkçe-duyarlı büyük/küçük harf }

function TRadStringHelper._ToUpperTR: string;
var i: Integer;
begin
  Result := Self;
  for i := 1 to Length(Result) do
    Result[i] := TrCharUpper(Result[i]);
end;

function TRadStringHelper._ToLowerTR: string;
var i: Integer;
begin
  Result := Self;
  for i := 1 to Length(Result) do
    Result[i] := TrCharLower(Result[i]);
end;

function TRadStringHelper._ToTitleCase: string;
var
  i: Integer;
  LNewWord: Boolean;
begin
  Result := Self._ToLowerTR;
  LNewWord := True;
  for i := 1 to Length(Result) do
  begin
    if not System.Character.TCharacter.IsLetterOrDigit(Result[i]) then
      LNewWord := True
    else if LNewWord then
    begin
      Result[i] := TrCharUpper(Result[i]);
      LNewWord := False;
    end;
  end;
end;

function TRadStringHelper._ToCamelCase: string;
var
  LWords: TArray<string>;
  i: Integer;
begin
  LWords := SplitIntoWords(Self);
  Result := '';
  for i := 0 to High(LWords) do
    if i = 0 then
      Result := Result + LWords[i]._ToLowerTR
    else
      Result := Result + LWords[i]._ToTitleCase;
end;

function TRadStringHelper._ToPascalCase: string;
var
  LWords: TArray<string>;
  i: Integer;
begin
  LWords := SplitIntoWords(Self);
  Result := '';
  for i := 0 to High(LWords) do
    Result := Result + LWords[i]._ToTitleCase;
end;

function TRadStringHelper._ToSnakeCase: string;
var
  LWords: TArray<string>;
  i: Integer;
begin
  LWords := SplitIntoWords(Self);
  Result := '';
  for i := 0 to High(LWords) do
  begin
    if i > 0 then
      Result := Result + '_';
    Result := Result + LWords[i]._ToLowerTR;
  end;
end;

function TRadStringHelper._IsUpper: Boolean;
var
  i: Integer;
  LHasLetter: Boolean;
begin
  LHasLetter := False;
  for i := 1 to Length(Self) do
    if System.Character.TCharacter.IsLetter(Self[i]) then
    begin
      LHasLetter := True;
      if not System.Character.TCharacter.IsUpper(Self[i]) then
        Exit(False);
    end;
  Result := LHasLetter;
end;

function TRadStringHelper._IsLower: Boolean;
var
  i: Integer;
  LHasLetter: Boolean;
begin
  LHasLetter := False;
  for i := 1 to Length(Self) do
    if System.Character.TCharacter.IsLetter(Self[i]) then
    begin
      LHasLetter := True;
      if not System.Character.TCharacter.IsLower(Self[i]) then
        Exit(False);
    end;
  Result := LHasLetter;
end;

{ Kırpma / Doldurma / Ortalama }

function TRadStringHelper._Center(ALen: Integer; AChar: Char): string;
var
  LTotal, LLeft: Integer;
begin
  if Length(Self) >= ALen then
    Exit(Self);
  LTotal := ALen - Length(Self);
  LLeft := LTotal div 2;
  Result := StringOfChar(AChar, LLeft) + Self + StringOfChar(AChar, LTotal - LLeft);
end;

function TRadStringHelper._Truncate(AMaxLen: Integer; const AEllipsis: string): string;
begin
  if Length(Self) <= AMaxLen then
    Exit(Self);
  if AMaxLen <= Length(AEllipsis) then
    Result := Copy(Self, 1, AMaxLen)
  else
    Result := Copy(Self, 1, AMaxLen - Length(AEllipsis)) + AEllipsis;
end;

function TRadStringHelper._Mask(AVisibleStart, AVisibleEnd: Integer; AMaskChar: Char): string;
var
  i, LVisibleStart, LVisibleEnd: Integer;
begin
  // negatif AVisibleStart/AVisibleEnd 0'a clamp edilir
  LVisibleStart := Max(AVisibleStart, 0);
  LVisibleEnd := Max(AVisibleEnd, 0);
  Result := Self;
  for i := 1 to Length(Result) do
    if (i > LVisibleStart) and (i <= Length(Result) - LVisibleEnd) then
      Result[i] := AMaskChar;
end;

function TRadStringHelper._RepeatText(ACount: Integer): string;
var
  LSelfLen, i: Integer;
begin
  if ACount <= 0 then
    Exit('');
  LSelfLen := Length(Self);
  SetLength(Result, LSelfLen * ACount);
  if LSelfLen > 0 then
    for i := 0 to ACount - 1 do
      Move(Self[1], Result[1 + i * LSelfLen], LSelfLen * SizeOf(Char));
end;

function TRadStringHelper._Reverse: string;
var
  i, LLen: Integer;
begin
  LLen := Length(Self);
  SetLength(Result, LLen);
  for i := 1 to LLen do
    Result[i] := Self[LLen - i + 1];
end;

{ Guard / Ensure }

function TRadStringHelper._EnsurePrefix(const APrefix: string): string;
begin
  if StartsStr(APrefix, Self) then
    Result := Self
  else
    Result := APrefix + Self;
end;

function TRadStringHelper._EnsureSuffix(const ASuffix: string): string;
begin
  if EndsStr(ASuffix, Self) then
    Result := Self
  else
    Result := Self + ASuffix;
end;

function TRadStringHelper._EnsureNoPrefix(const APrefix: string): string;
begin
  if (APrefix <> '') and StartsStr(APrefix, Self) then
    Result := Copy(Self, Length(APrefix) + 1, MaxInt)
  else
    Result := Self;
end;

function TRadStringHelper._EnsureNoSuffix(const ASuffix: string): string;
begin
  if (ASuffix <> '') and EndsStr(ASuffix, Self) then
    Result := Copy(Self, 1, Length(Self) - Length(ASuffix))
  else
    Result := Self;
end;

function TRadStringHelper._DefaultIfEmpty(const ADefault: string): string;
begin
  if Self = '' then
    Result := ADefault
  else
    Result := Self;
end;

function TRadStringHelper._DefaultIfWhiteSpace(const ADefault: string): string;
begin
  if System.SysUtils.Trim(Self) = '' then
    Result := ADefault
  else
    Result := Self;
end;

{ Sayısal/Boolean güvenli dönüşüm }

function TRadStringHelper._ToIntOrDefault(ADefault: Integer): Integer;
begin
  if not TryStrToInt(Self, Result) then
    Result := ADefault;
end;

function TRadStringHelper._ToInt64OrDefault(ADefault: Int64): Int64;
begin
  if not TryStrToInt64(Self, Result) then
    Result := ADefault;
end;

function TRadStringHelper._ToFloatOrDefault(ADefault: Double): Double;
begin
  if not TryStrToFloat(Self, Result) then
    Result := ADefault;
end;

function TRadStringHelper._ToBoolOrDefault(ADefault: Boolean): Boolean;
begin
  if not TryStrToBool(Self, Result) then
    Result := ADefault;
end;

function TRadStringHelper._TryToInt(out AValue: Integer): Boolean;
begin
  Result := TryStrToInt(Self, AValue);
end;

function TRadStringHelper._TryToFloat(out AValue: Double): Boolean;
begin
  Result := TryStrToFloat(Self, AValue);
end;

{ Test / Karşılaştırma }

function TRadStringHelper._IsAlpha: Boolean;
var
  i: Integer;
begin
  Result := Self <> '';
  for i := 1 to Length(Self) do
    if not System.Character.TCharacter.IsLetter(Self[i]) then
      Exit(False);
end;

function TRadStringHelper._IsAlphaNumeric: Boolean;
var
  i: Integer;
begin
  Result := Self <> '';
  for i := 1 to Length(Self) do
    if not System.Character.TCharacter.IsLetterOrDigit(Self[i]) then
      Exit(False);
end;

function TRadStringHelper._IsDigitsOnly: Boolean;
var
  i: Integer;
begin
  Result := Self <> '';
  for i := 1 to Length(Self) do
    if not System.Character.TCharacter.IsDigit(Self[i]) then
      Exit(False);
end;

function TRadStringHelper._IsOneOf(const AList: array of string; ACaseSensitive: Boolean): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(AList) do
    if (ACaseSensitive and (Self = AList[i])) or
       ((not ACaseSensitive) and SameText(Self, AList[i])) then
      Exit(True);
end;

function TRadStringHelper._EqualsIgnoreCase(const AOther: string): Boolean;
begin
  Result := SameText(Self, AOther);
end;

function TRadStringHelper._HasPrefixOf(const APrefixes: array of string; ACaseSensitive: Boolean): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(APrefixes) do
    if (ACaseSensitive and StartsStr(APrefixes[i], Self)) or
       ((not ACaseSensitive) and StartsText(APrefixes[i], Self)) then
      Exit(True);
end;

function TRadStringHelper._HasSuffixOf(const ASuffixes: array of string; ACaseSensitive: Boolean): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(ASuffixes) do
    if (ACaseSensitive and EndsStr(ASuffixes[i], Self)) or
       ((not ACaseSensitive) and EndsText(ASuffixes[i], Self)) then
      Exit(True);
end;

function TRadStringHelper._ContainsAny(const AList: array of string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(AList) do
    if ContainsStr(Self, AList[i]) then
      Exit(True);
end;

function TRadStringHelper._ContainsAll(const AList: array of string): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to High(AList) do
    if not ContainsStr(Self, AList[i]) then
      Exit(False);
end;

function TRadStringHelper._CompareNatural(const AOther: string): Integer;
var
  i1, i2, LLen1, LLen2, LStart1, LStart2, LTrim1, LTrim2: Integer;
  LDigits1, LDigits2: string;
begin
  i1 := 1;
  i2 := 1;
  LLen1 := Length(Self);
  LLen2 := Length(AOther);
  while (i1 <= LLen1) and (i2 <= LLen2) do
  begin
    if System.Character.TCharacter.IsDigit(Self[i1]) and System.Character.TCharacter.IsDigit(AOther[i2]) then
    begin
      LStart1 := i1;
      while (i1 <= LLen1) and System.Character.TCharacter.IsDigit(Self[i1]) do
        Inc(i1);
      LStart2 := i2;
      while (i2 <= LLen2) and System.Character.TCharacter.IsDigit(AOther[i2]) do
        Inc(i2);
      // Int64'e cevirmek yerine string olarak karsilastir (StrToInt64 uzun
      // rakam bloklarinda EConvertError atiyordu): bastaki sifirlari kirp,
      // uzunluklari karsilastir, esitse leksik karsilastir.
      LDigits1 := Copy(Self, LStart1, i1 - LStart1);
      LDigits2 := Copy(AOther, LStart2, i2 - LStart2);
      LTrim1 := 1;
      while (LTrim1 < Length(LDigits1)) and (LDigits1[LTrim1] = '0') do
        Inc(LTrim1);
      LDigits1 := Copy(LDigits1, LTrim1, MaxInt);
      LTrim2 := 1;
      while (LTrim2 < Length(LDigits2)) and (LDigits2[LTrim2] = '0') do
        Inc(LTrim2);
      LDigits2 := Copy(LDigits2, LTrim2, MaxInt);
      if Length(LDigits1) <> Length(LDigits2) then
        Exit(Length(LDigits1) - Length(LDigits2))
      else if LDigits1 <> LDigits2 then
        Exit(CompareStr(LDigits1, LDigits2));
    end
    else
    begin
      if Self[i1] <> AOther[i2] then
        Exit(Ord(Self[i1]) - Ord(AOther[i2]));
      Inc(i1);
      Inc(i2);
    end;
  end;
  Result := (LLen1 - i1 + 1) - (LLen2 - i2 + 1);
end;

function TRadStringHelper._LevenshteinDistance(const AOther: string): Integer;
var
  i, j, LLen1, LLen2, LCost: Integer;
  LPrev, LCurr, LTemp: TArray<Integer>;
begin
  LLen1 := Length(Self);
  LLen2 := Length(AOther);
  SetLength(LPrev, LLen2 + 1);
  SetLength(LCurr, LLen2 + 1);
  for j := 0 to LLen2 do
    LPrev[j] := j;
  for i := 1 to LLen1 do
  begin
    LCurr[0] := i;
    for j := 1 to LLen2 do
    begin
      if Self[i] = AOther[j] then
        LCost := 0
      else
        LCost := 1;
      LCurr[j] := Min(Min(LCurr[j - 1] + 1, LPrev[j] + 1), LPrev[j - 1] + LCost);
    end;
    LTemp := LPrev;
    LPrev := LCurr;
    LCurr := LTemp;
  end;
  Result := LPrev[LLen2];
end;

function TRadStringHelper._SimilarityRatio(const AOther: string): Double;
var
  LMaxLen, LDist: Integer;
begin
  LMaxLen := Max(Length(Self), Length(AOther));
  if LMaxLen = 0 then
    Exit(1.0);
  LDist := Self._LevenshteinDistance(AOther);
  Result := 1.0 - (LDist / LMaxLen);
end;

function TRadStringHelper._IsWildcardMatch(const APattern: string): Boolean;
begin
  Result := System.Masks.MatchesMask(Self, APattern);
end;

{ Çıkarma (Extraction) }

function TRadStringHelper._Left(ACount: Integer): string;
begin
  Result := Copy(Self, 1, Max(ACount, 0));
end;

function TRadStringHelper._Right(ACount: Integer): string;
begin
  // negatif/sifir ACount -> bos string (kontrat aciklamasi)
  if ACount <= 0 then
    Exit('');
  if ACount >= Length(Self) then
    Result := Self
  else
    Result := Copy(Self, Length(Self) - ACount + 1, ACount);
end;

function TRadStringHelper._Before(const ASub: string): string;
var
  LPos: Integer;
begin
  LPos := Pos(ASub, Self);
  if LPos = 0 then
    Result := Self
  else
    Result := Copy(Self, 1, LPos - 1);
end;

function TRadStringHelper._After(const ASub: string): string;
var
  LPos: Integer;
begin
  LPos := Pos(ASub, Self);
  if LPos = 0 then
    Result := ''
  else
    Result := Copy(Self, LPos + Length(ASub), MaxInt);
end;

function TRadStringHelper._Between(const AStart, AEnd: string): string;
begin
  Result := Self._After(AStart)._Before(AEnd);
end;

function TRadStringHelper._SplitTrimmed(const ADelimiter: string; ARemoveEmpty: Boolean): TArray<string>;
var
  LRaw: TArray<string>;
  LList: TList<string>;
  i: Integer;
  LItem: string;
begin
  LRaw := SplitBySubstring(Self, ADelimiter);
  LList := TList<string>.Create;
  try
    for i := 0 to High(LRaw) do
    begin
      LItem := System.SysUtils.Trim(LRaw[i]);
      if (LItem <> '') or (not ARemoveEmpty) then
        LList.Add(LItem);
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

{ Diziler ile ilişki }

class function TRadStringHelper._Join(const ASeparator: string; const AValues: array of string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(AValues) do
  begin
    if i > 0 then
      Result := Result + ASeparator;
    Result := Result + AValues[i];
  end;
end;

end.
