unit rad.search.match;

{ Arama metni eşleştirme: Türkçe harf katlama, kelime ve baş harf çıkarma, puanlama.
  Yalnız RTL; veritabanına ve arayüze bağlı değildir. Kurallar web istemcisinde de aynen
  uygulanır (docs/specs/rad.search.md), bu yüzden davranış değişikliği iki tarafta birlikte yapılır. }

interface

type
  /// <summary>Bir başlığın aramaya hazır, bir kez hesaplanmış hali.</summary>
  TRadSearchKey = record
    /// <summary>Katlanmış başlık.</summary>
    Text: string;
    /// <summary>Katlanmış başlığın kelimeleri.</summary>
    Words: TArray<string>;
    /// <summary>Başlık kelimelerinin baş harfleri ('Yurt İçi Satış Faturası' -> 'yisf').</summary>
    Initials: string;
    /// <summary>Katlanmış yol kelimeleri (üst menü başlıkları).</summary>
    PathWords: TArray<string>;
  end;

  /// <summary>Eşleştirme kuralları. Puan 0 eşleşme yok demektir; büyük puan üstte gösterilir.</summary>
  TRadSearchMatch = class abstract
  public
    const
      ScoreNone = 0;
      ScorePath = 100;
      ScoreContains = 200;
      ScoreWords = 300;
      ScoreInitials = 400;
      ScoreStart = 500;
      /// <summary>Baş harf eşleşmesi için en az harf sayısı; tek harf her şeyi bulur.</summary>
      MinInitials = 2;
    /// <summary>Küçük harf; I/İ/ı/i, ş/s, ğ/g, ü/u, ö/o, ç/c, â/a, î/i, û/u aynı sayılır, '&amp;' silinir.</summary>
    class function Fold(const AText: string): string; static;
    /// <summary>Katlanmış metnin harf ve rakam dizileri; diğer her karakter ayırıcıdır.</summary>
    class function Words(const AFolded: string): TArray<string>; static;
    class function Initials(const AWords: TArray<string>): string; static;
    class function Key(const ACaption, APath: string): TRadSearchKey; static;
    /// <summary>AQuery katlanmış olmalı (Fold). Kurallar en güçlüden zayıfa: başlık önek, baş harf önek,
    /// her terim bir kelimenin başı, başlık içerir, terimler yol dahil kelimelerin başı.</summary>
    class function Score(const AQuery: string; const AKey: TRadSearchKey): Integer; static;
  end;

implementation

uses
  System.SysUtils,
  System.Character;

class function TRadSearchMatch.Fold(const AText: string): string;
var
  I: Integer;
begin
  Result := AText.Replace('&', '');
  for I := 1 to Length(Result) do
    case Result[I] of
      'I', #$0130, #$0131, #$00CE, #$00EE: Result[I] := 'i';
      #$015E, #$015F: Result[I] := 's';
      #$011E, #$011F: Result[I] := 'g';
      #$00DC, #$00FC, #$00DB, #$00FB: Result[I] := 'u';
      #$00D6, #$00F6: Result[I] := 'o';
      #$00C7, #$00E7: Result[I] := 'c';
      #$00C2, #$00E2: Result[I] := 'a';
    end;
  Result := Result.ToLowerInvariant;
end;

class function TRadSearchMatch.Words(const AFolded: string): TArray<string>;
var
  I, LStart: Integer;
begin
  Result := nil;
  LStart := 0;
  for I := 1 to Length(AFolded) + 1 do
    if (I <= Length(AFolded)) and AFolded[I].IsLetterOrDigit then
    begin
      if LStart = 0 then
        LStart := I;
    end
    else if LStart > 0 then
    begin
      Result := Result + [Copy(AFolded, LStart, I - LStart)];
      LStart := 0;
    end;
end;

class function TRadSearchMatch.Initials(const AWords: TArray<string>): string;
var
  LWord: string;
begin
  Result := '';
  for LWord in AWords do
    Result := Result + LWord[1];
end;

class function TRadSearchMatch.Key(const ACaption, APath: string): TRadSearchKey;
begin
  Result.Text := Fold(ACaption).Trim;
  Result.Words := Words(Result.Text);
  Result.Initials := Initials(Result.Words);
  Result.PathWords := Words(Fold(APath));
end;

function AnyStartsWith(const AWords: TArray<string>; const ATerm: string): Boolean;
var
  LWord: string;
begin
  for LWord in AWords do
    if LWord.StartsWith(ATerm) then
      Exit(True);
  Result := False;
end;

function AllTermsStart(const ATerms, AWords: TArray<string>): Boolean;
var
  LTerm: string;
begin
  for LTerm in ATerms do
    if not AnyStartsWith(AWords, LTerm) then
      Exit(False);
  Result := Length(ATerms) > 0;
end;

class function TRadSearchMatch.Score(const AQuery: string; const AKey: TRadSearchKey): Integer;
var
  LQuery: string;
  LTerms: TArray<string>;
begin
  LQuery := AQuery.Trim;
  LTerms := Words(LQuery);
  if Length(LTerms) = 0 then
    Exit(ScoreNone);
  if AKey.Text.StartsWith(LQuery) then
    Exit(ScoreStart);
  if (Length(LTerms) = 1) and (Length(LTerms[0]) >= MinInitials) and AKey.Initials.StartsWith(LTerms[0]) then
    Exit(ScoreInitials);
  if AllTermsStart(LTerms, AKey.Words) then
    Exit(ScoreWords);
  if AKey.Text.Contains(LQuery) then
    Exit(ScoreContains);
  if AllTermsStart(LTerms, AKey.Words + AKey.PathWords) then
    Exit(ScorePath);
  Result := ScoreNone;
end;

end.
