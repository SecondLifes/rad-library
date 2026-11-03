program SearchExprTest;

(* rad.searchexpr testleri: baglantisiz, yalniz terim ayristirma, deger cevirme ve uretilen SQL. *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Variants,
  rad.sqlfilter, rad.searchexpr;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;

procedure Kontrol(const AAd: string; ABasarili: Boolean; const ADetay: string = '');
begin
  if ABasarili then
  begin
    Inc(GBasari);
    Writeln('  [OK]   ', AAd);
  end
  else
  begin
    Inc(GHata);
    Writeln('  [HATA] ', AAd, '  ', ADetay);
  end;
end;

procedure Esit(const AAd, ABeklenen, AGercek: string);
begin
  Kontrol(AAd, ABeklenen = AGercek, 'beklenen=[' + ABeklenen + '] gercek=[' + AGercek + ']');
end;

function Terimler(const AMetin: string): string;
var
  T: TRadSearchTerm;
begin
  Result := '';
  for T in TRadSearch.Parse(AMetin) do
    Result := Result + Format('{%d|%s|%s}', [Ord(T.Op), T.Operand, T.Operand2]);
end;

function Goster(const V: Variant): string;
begin
  case VarType(V) of
    varDate: Result := FormatDateTime('dd.mm.yyyy hh:nn', V);
    varDouble: Result := FloatToStr(V, TFormatSettings.Invariant);
  else
    Result := VarToStr(V);
  end;
end;

function Deger(const AMetin: string; AKind: TRadSearchKind): string;
var
  V: Variant;
begin
  if TRadSearch.Value(AMetin, AKind, V) then
    Result := Goster(V)
  else
    Result := '<yok>';
end;

function Kosul(const AMetin: string; AKind: TRadSearchKind; out AParams: string): string;
var
  F: IRadSqlFilter;
  P: TRadSqlParam;
  T: TRadSearchTerm;
  LVar: Boolean;
begin
  F := TRadSqlFilter.New;
  LVar := False;
  for T in TRadSearch.Parse(AMetin) do
    LVar := TRadSearch.Apply(F, 'x.alan', AKind, T) or LVar;
  if not LVar then
    Exit('<eklenmedi>');
  Result := F.GetConditions;
  AParams := '';
  for P in F.Params do
    AParams := AParams + Goster(P.Value) + ';';
end;

var
  S, LP: string;
  F: IRadSqlFilter;

begin
  try
    FormatSettings := TFormatSettings.Create('tr-TR');
    Writeln('=== Ayristirma ===');
    Esit('P01 bos', '', Terimler('   '));
    Esit('P02 tek kelime', '{0|ahmet|}', Terimler('ahmet'));
    Esit('P03 iki kelime', '{0|ahmet|}{0|istanbul|}', Terimler('  ahmet   istanbul '));
    Esit('P04 tirnakli', '{0|kasa merkez|}{0|x|}', Terimler('"kasa merkez" x'));
    Esit('P05 kapanmamis tirnak', '{0|kasa merkez|}', Terimler('"kasa merkez'));
    Esit('P06 >=', '{' + IntToStr(Ord(soGreaterEqual)) + '|10|}', Terimler('>=10'));
    Esit('P07 <>', '{' + IntToStr(Ord(soNotEqual)) + '|5|}', Terimler('<>5'));
    Esit('P08 !=', '{' + IntToStr(Ord(soNotEqual)) + '|5|}', Terimler('!=5'));
    Esit('P09 =tirnak', '{' + IntToStr(Ord(soEqual)) + '|a b|}', Terimler('="a b"'));
    Esit('P10 aralik', '{' + IntToStr(Ord(soRange)) + '|10|20}', Terimler('10..20'));
    Esit('P11 acik ust', '{' + IntToStr(Ord(soRange)) + '|10|}', Terimler('10..'));
    Esit('P12 acik alt', '{' + IntToStr(Ord(soRange)) + '||20}', Terimler('..20'));
    Esit('P13 yalniz ..', '{0|..|}', Terimler('..'));
    Esit('P14 yalniz operator', '{0|>|}', Terimler('>'));
    Esit('P15 tirnakli aralik degil', '{0|1..2|}', Terimler('"1..2"'));
    Esit('P16 ondalik aralik', '{' + IntToStr(Ord(soRange)) + '|1.5|2.5}', Terimler('1.5..2.5'));

    Writeln('=== Deger cevirme ===');
    Esit('V01 tamsayi', '42', Deger('42', skInteger));
    Esit('V02 tamsayi onaltili', '<yok>', Deger('$FF', skInteger));
    Esit('V03 tamsayi harf', '<yok>', Deger('12a', skInteger));
    Esit('V04 tamsayi tek isaret', '<yok>', Deger('-', skInteger));
    Esit('V05 ondalik tr', '1234.56', Deger('1.234,56', skDecimal));
    Esit('V06 ondalik en', '1234.56', Deger('1,234.56', skDecimal));
    Esit('V07 ondalik tek ayirici', '12.5', Deger('12,5', skDecimal));
    Esit('V08 ustel yok', '<yok>', Deger('12e3', skDecimal));
    Esit('V09 tarih tr', '01.11.2026 00:00', Deger('01.11.2026', skDate));
    Esit('V10 tarih iso', '01.11.2026 00:00', Deger('2026-11-01', skDate));
    Esit('V11 gecersiz tarih', '<yok>', Deger('abc', skDate));
    Esit('V12 evet', 'True', Deger('Evet', skBoolean));
    Esit('V13 hayir', 'False', Deger('hayir', skBoolean));
    Esit('V14 bilinmeyen', '<yok>', Deger('belki', skBoolean));

    Writeln('=== Koşul uretimi ===');
    S := Kosul('=KASA', skText, LP);
    Kontrol('K01 metin esit', (Pos('cast(x.alan as text)', S) > 0) and (Pos('KASA', LP) > 0), S + ' ' + LP);
    S := Kosul('>5', skText, LP);
    Kontrol('K02 metinde operator duz arama', Pos('>5', LP) > 0, S + ' ' + LP);
    S := Kosul('>=1.000,5', skDecimal, LP);
    Kontrol('K03 ondalik >=', (Pos('>=', S) > 0) and (LP = '1000.5;'), S + ' ' + LP);
    S := Kosul('10..20', skInteger, LP);
    Kontrol('K04 tamsayi aralik', (Pos('BETWEEN', S) > 0) and (LP = '10;20;'), S + ' ' + LP);
    S := Kosul('10..', skInteger, LP);
    Kontrol('K05 acik ust', (Pos('>=', S) > 0) and (LP = '10;'), S + ' ' + LP);
    S := Kosul('abc', skInteger, LP);
    Esit('K06 uymayan terim', '<eklenmedi>', S);
    S := Kosul('>01.11.2026', skDate, LP);
    Kontrol('K07 tarih >', Pos('<', S) + Pos('>', S) > 0, S + ' ' + LP);
    Writeln('   (bilgi) tarih > : ' + S + ' | ' + LP);
    S := Kosul('01.11.2026', skDate, LP);
    Writeln('   (bilgi) tarih eşit : ' + S + ' | ' + LP);
    Kontrol('K08 tarih esit gunun tamami', Pos('>=', S) > 0, S + ' ' + LP);
    S := Kosul('>evet', skBoolean, LP);
    Esit('K09 evet-hayir operator yok', '<eklenmedi>', S);
    S := Kosul('!=evet', skBoolean, LP);
    Kontrol('K10 evet-hayir esit degil', Pos('<>', S) > 0, S + ' ' + LP);
    S := Kosul('01.11.2026..30.11.2026', skDate, LP);
    Writeln('   (bilgi) tarih aralik : ' + S + ' | ' + LP);
    Kontrol('K11 tarih aralik', S <> '<eklenmedi>', S);
    S := Kosul('10..abc', skInteger, LP);
    Esit('K12 yarim gecersiz aralik', '<eklenmedi>', S);
    Writeln('=== Joker ve rakam alani ===');
    S := Kosul('kasa*', skText, LP);
    Kontrol('J01 baslar', (Pos('ILIKE', S) > 0) and (LP = 'kasa%;'), S + ' ' + LP);
    S := Kosul('*5595', skText, LP);
    Kontrol('J02 biter', LP = '%5595;', S + ' ' + LP);
    S := Kosul('a*b?c', skText, LP);
    Kontrol('J03 ortada', LP = 'a%b_c;', S + ' ' + LP);
    S := Kosul('a**b', skText, LP);
    Kontrol('J04 ardisik yildiz tek', LP = 'a%b;', S + ' ' + LP);
    S := Kosul('a??b', skText, LP);
    Kontrol('J05 ardisik soru iki karakter', LP = 'a__b;', S + ' ' + LP);
    S := Kosul('50%*', skText, LP);
    Kontrol('J06 yuzde ve alt cizgi kacar', LP = '50!%%;', S + ' ' + LP);
    S := Kosul('a\*b', skText, LP);
    Kontrol('J07 kacisli yildiz duz', LP = '%a*b%;', S + ' ' + LP);
    S := Kosul('"0 555*"', skText, LP);
    Kontrol('J08 tirnakta bosluklu joker', LP = '0 555%;', S + ' ' + LP);
    S := Kosul('=kasa*', skText, LP);
    Kontrol('J09 esit + joker', LP = 'kasa%;', S + ' ' + LP);
    S := Kosul('>5*', skText, LP);
    Kontrol('J10 operator + joker metinde duz desen', LP = '>5%;', S + ' ' + LP);
    S := Kosul('12*', skInteger, LP);
    Esit('J11 sayida joker dusurulur', '<eklenmedi>', S);
    S := Kosul('"0(555) 557-"', skDigits, LP);
    Kontrol('J12 rakam alani rakam disini atar', (Pos('LIKE', S) > 0) and (LP = '%0555557%;'), S + ' ' + LP);
    S := Kosul('"0 555 557*"', skDigits, LP);
    Kontrol('J13 rakam alani joker', (Pos('LIKE ', S) > 0) and (LP = '0555557%;'), S + ' ' + LP);
    S := Kosul('ahmet', skDigits, LP);
    Esit('J14 rakamsiz terim rakam alanina girmez', '<eklenmedi>', S);
    S := Kosul('*5595', skDigits, LP);
    Kontrol('J15 rakam alani biter', LP = '%5595;', S + ' ' + LP);

    Writeln('=== Operator ve joker cevresinde bosluk ===');
    Esit('S01 operator sonrasi bosluk', Terimler('>1'), Terimler('> 1'));
    Esit('S02 cok bosluk', Terimler('>=5'), Terimler('>=   5'));
    Esit('S03 joker oncesi bosluk', Terimler('0555*'), Terimler('0555 *'));
    Esit('S04 joker sonrasi bosluk', Terimler('*5595'), Terimler('* 5595'));
    Esit('S05 aralik bosluklu', Terimler('10..20'), Terimler('10 .. 20'));
    Esit('S06 operator terim basinda degilse ayri terim', Terimler('ahmet') + Terimler('>5'), Terimler('ahmet >5'));
    Esit('S07 tirnak ici dokunulmaz', Terimler('"a * b"'), Terimler('"a * b"'));
    Esit('S08 operator + tirnak', Terimler('="kasa merkez"'), Terimler('= "kasa merkez"'));
    Esit('S09 kacisli yildiz sonrasi bosluk korunur', Terimler('a\*') + Terimler('b'), Terimler('a\* b'));
    Esit('S10 bosluklu telefon deseni', Terimler('0 555 557*'), Terimler('0 555 557 *'));

    Writeln('=== Bos OR grubu + Raw (base.filtre akisi) ===');
    F := TRadSqlFilter.New;
    F.BeginOr;
    F.EndOr;
    F.Raw('1 = 0', []);
    Esit('G01 bos grup', '(1 = 0)', F.GetConditions);
    F := TRadSqlFilter.New;
    F.BeginOr;
    TRadSearch.Apply(F, 'a.x', skText, TRadSearch.Parse('ali')[0]);
    TRadSearch.Apply(F, 'a.y', skText, TRadSearch.Parse('ali')[0]);
    F.EndOr;
    F.BeginOr;
    TRadSearch.Apply(F, 'a.x', skText, TRadSearch.Parse('veli')[0]);
    F.EndOr;
    Writeln('   (bilgi) iki terim: ', F.GetConditions);
    Kontrol('G02 terimler AND, alanlar OR', (Pos(' OR ', F.GetConditions) > 0) and (Pos(' AND ', F.GetConditions) > 0), F.GetConditions);
  except
    on E: Exception do
    begin
      Writeln('ISTISNA: ', E.ClassName, ': ', E.Message);
      Inc(GHata);
    end;
  end;
  Writeln;
  Writeln(Format('Sonuc: %d basarili, %d hata', [GBasari, GHata]));
  if GHata > 0 then
    Halt(1);
end.
