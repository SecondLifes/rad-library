program SqlFilterTest;

(* rad.sqlfilter cekirdek testleri: baglantisiz, yalniz uretilen SQL ve parametreler. *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Variants,
  rad.sqlfilter;

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

function ParamStr(AF: IRadSqlFilter): string;
var
  P: TRadSqlParam;
begin
  Result := '';
  for P in AF.Params do
    Result := Result + P.Name + '=' + VarToStr(P.Value) + ';';
end;

procedure Firlatir(const AAd: string; AProc: TProc);
begin
  try
    AProc;
    Kontrol(AAd, False, 'istisna firlatilmadi');
  except
    on E: ERadSqlFilter do
      Kontrol(AAd, True);
    on E: Exception do
      Kontrol(AAd, False, E.ClassName + ': ' + E.Message);
  end;
end;

var
  F: IRadSqlFilter;
  D1, D2, D3: TDateTime;

begin
  try
    Writeln('=== Bos filtre ===');
    F := TRadSqlFilter.New;
    Esit('T01a GetWhere bos', '', F.GetWhere);
    Esit('T01b GetConditions bos', '', F.GetConditions);
    Esit('T01c GetOrderBy bos', '', F.GetOrderBy);
    Esit('T01d GetSql bos', '', F.GetSql);
    Kontrol('T01e IsEmpty', F.IsEmpty and (F.ParamCount = 0));

    Writeln('=== Eq ve karsilastirma ===');
    F := TRadSqlFilter.New.Equal('tip', 'A', rcDatabase);
    Esit('T02a tek Eq', 'WHERE (tip = :p1)', F.GetWhere);
    Esit('T02b parametre', 'p1=A;', ParamStr(F));
    Esit('T02c GetConditions', '(tip = :p1)', F.GetConditions);
    F := TRadSqlFilter.New.Equal('a', 1).NotEqual('b', 2).Greater('c', 3).GreaterEqual('d', 4).Less('e', 5).LessEqual('f', 6);
    Esit('T03 alti islec',
      'WHERE (a = :p1) AND (b <> :p2) AND (c > :p3) AND (d >= :p4) AND (e < :p5) AND (f <= :p6)',
      F.GetWhere);
    Esit('T03b parametre sirasi', 'p1=1;p2=2;p3=3;p4=4;p5=5;p6=6;', ParamStr(F));

    Writeln('=== Bos deger: SkipEmpty ===');
    F := TRadSqlFilter.New.Equal('a', '').Equal('b', Null).Equal('c', Unassigned).Equal('d', 0).Equal('e', False);
    Esit('T04a bos metin/Null/Unassigned atlanir, 0 ve False deger', 'WHERE (d = :p1) AND (e = :p2)',
      F.GetWhere);
    Esit('T04b parametreler yalniz uretilenler icin', 'p1=0;p2=False;', ParamStr(F));
    F := TRadSqlFilter.New.Like('a', '').Contains('b', '').StartsWith('c', '').EndsWith('d', '');
    Esit('T04c bos desenler atlanir', '', F.GetWhere);

    Writeln('=== Bos deger: Strict ===');
    Firlatir('T05a Strict Eq bos metin', procedure begin TRadSqlFilter.New(sdPostgreSQL, rfmStrict).Equal('a', ''); end);
    Firlatir('T05b Strict Eq Null', procedure begin TRadSqlFilter.New.Mode(rfmStrict).Equal('a', Null); end);
    Firlatir('T05c Strict Contains bos', procedure begin TRadSqlFilter.New.Mode(rfmStrict).Contains('a', ''); end);
    Firlatir('T05d Strict Between iki taraf bos', procedure begin TRadSqlFilter.New.Mode(rfmStrict).Between('a', Null, Null); end);
    Firlatir('T05e Strict Between tek taraf bos', procedure begin TRadSqlFilter.New.Mode(rfmStrict).Between('a', 1, Null); end);
    F := TRadSqlFilter.New.Mode(rfmStrict).Equal('d', 0);
    Esit('T05f Strict 0 deger kabul', 'WHERE (d = :p1)', F.GetWhere);

    Writeln('=== InList ===');
    F := TRadSqlFilter.New.InList('sube', ['01', '02']);
    Esit('T06a iki oge', 'WHERE (sube IN (:p1, :p2))', F.GetWhere);
    Esit('T06b parametreler', 'p1=01;p2=02;', ParamStr(F));
    F := TRadSqlFilter.New.InList('sube', ['01', Null, '02']);
    Esit('T06c Null oge atilir', 'WHERE (sube IN (:p1, :p2))', F.GetWhere);
    F := TRadSqlFilter.New.InList('sube', []).NotInList('x', [Null]);
    Esit('T06d bos liste atlanir', '', F.GetWhere);
    F := TRadSqlFilter.New.Mode(rfmStrict).InList('sube', []);
    Esit('T06e Strict bos InList 1=0', 'WHERE (1=0)', F.GetWhere);
    F := TRadSqlFilter.New.Mode(rfmStrict).NotInList('sube', []);
    Esit('T06f Strict bos NotInList 1=1', 'WHERE (1=1)', F.GetWhere);
    F := TRadSqlFilter.New.NotInList('sube', [7]);
    Esit('T06g NotInList', 'WHERE (sube NOT IN (:p1))', F.GetWhere);
    F := TRadSqlFilter.New.InList('ad', ['x']).CaseSensitive(False);
    Esit('T06h InList harf modundan etkilenmez', 'WHERE (ad IN (:p1))', F.GetWhere);

    Writeln('=== Between ===');
    D1 := EncodeDate(2026, 1, 1);
    D2 := EncodeDate(2026, 1, 31);
    F := TRadSqlFilter.New.Between('tutar', 10, 20);
    Esit('T07a iki taraf (sayi)', 'WHERE (tutar BETWEEN :p1 AND :p2)', F.GetWhere);
    F := TRadSqlFilter.New.Between('tarih', D1, D2);
    Esit('T07a2 iki taraf (gun) -> yari acik aralik', 'WHERE (tarih >= :p1 AND tarih < :p2)', F.GetWhere);
    Kontrol('T07b tarih degerleri (bitis gun+1)', (F.Params[0].Value = D1) and (F.Params[1].Value = D2 + 1));
    F := TRadSqlFilter.New.Between('tarih', D1, Null);
    Esit('T07c yalniz baslangic', 'WHERE (tarih >= :p1)', F.GetWhere);
    F := TRadSqlFilter.New.Between('tutar', Null, 20);
    Esit('T07d yalniz bitis (sayi)', 'WHERE (tutar <= :p1)', F.GetWhere);
    F := TRadSqlFilter.New.Between('tarih', Null, Null).Between('s', '', '');
    Esit('T07e ikisi bos atlanir', '', F.GetWhere);

    Writeln('=== Like: joker ve kacis (PostgreSQL) ===');
    F := TRadSqlFilter.New.CaseSensitive(False).Wildcards('*', '?').Like('telefon', '*5595');
    Esit('T08a ILIKE ESCAPE', 'WHERE (telefon ILIKE :p1 ESCAPE ''!'')', F.GetWhere);
    Esit('T08b * -> %', 'p1=%5595;', ParamStr(F));
    F := TRadSqlFilter.New.Wildcards('*', '?').Like('ad', '50%*');
    Esit('T09a % duz karakter', 'p1=50!%%;', ParamStr(F));
    F := TRadSqlFilter.New.Wildcards('*', '?').Like('ad', 'a_b!c?d');
    Esit('T09b _ ve ! kacirilir, ? -> _', 'p1=a!_b!!c_d;', ParamStr(F));
    F := TRadSqlFilter.New.Wildcards('*', '?').Like('ad', 'x**y??z');
    Esit('T10 cift joker duz karakter', 'p1=x*y?z;', ParamStr(F));
    F := TRadSqlFilter.New.Like('ad', '50%%');
    Esit('T10b varsayilan jokerde cift % duz %', 'p1=50!%;', ParamStr(F));
    F := TRadSqlFilter.New.CaseSensitive(False).Like('telefon', '%5595', False);
    Esit('T11a kacis kapali: ESCAPE yok', 'WHERE (telefon ILIKE :p1)', F.GetWhere);
    Esit('T11b kacis kapali: desen oldugu gibi', 'p1=%5595;', ParamStr(F));
    F := TRadSqlFilter.New.Wildcards('*', '?').Like('ad', '*50%_**', False);
    Esit('T11c kacis kapali: yalniz joker cevirisi, cift yazim yok', 'p1=%50%_%%;', ParamStr(F));
    F := TRadSqlFilter.New.Wildcards('*', '?').Like('a', '*').Like('b', '***', False);
    Esit('T12a yalniz joker desen atlanir', '', F.GetWhere);
    F := TRadSqlFilter.New.Like('c', '%').Like('d', '%%%', False);
    Esit('T12a2 varsayilan jokerde % atlanir', '', F.GetWhere);
    F := TRadSqlFilter.New.Wildcards('*', '?').Like('b', '***');
    Esit('T12a4 kacis acikken *** = duz * ve joker, atlanmaz', 'p1=*%;', ParamStr(F));
    F := TRadSqlFilter.New.Wildcards('*', '?').Like('c', '%');
    Esit('T12a3 ozel jokerde % duz karakter, atlanmaz', 'p1=!%;', ParamStr(F));
    F := TRadSqlFilter.New.CaseSensitive(False).Wildcards('*', '?').Like('a', '?');
    Esit('T12b tek karakter jokeri atlanmaz', 'WHERE (a ILIKE :p1 ESCAPE ''!'')', F.GetWhere);
    F := TRadSqlFilter.New.CaseSensitive(False).Mode(rfmStrict).Like('a', '%');
    Esit('T12c Strict: yalniz joker desen yazilir', 'WHERE (a ILIKE :p1 ESCAPE ''!'')', F.GetWhere);
    F := TRadSqlFilter.New.CaseSensitive(False).NotLike('a', 'x');
    Esit('T12d NotLike', 'WHERE (a NOT ILIKE :p1 ESCAPE ''!'')', F.GetWhere);

    Writeln('=== Contains / StartsWith / EndsWith ===');
    F := TRadSqlFilter.New.CaseSensitive(False).Wildcards('*', '?').Contains('ad', '50%*');
    Esit('T13a Contains tamamen kacirilir (* SQL jokeri degil, duz kalir)', 'p1=%50!%*%;', ParamStr(F));
    Esit('T13b Contains SQL', 'WHERE (ad ILIKE :p1 ESCAPE ''!'')', F.GetWhere);
    F := TRadSqlFilter.New.StartsWith('ad', 'ab').EndsWith('soyad', 'c_');
    Esit('T14 StartsWith/EndsWith', 'p1=ab%;p2=%c!_;', ParamStr(F));

    Writeln('=== Harf duyarliligi ===');
    F := TRadSqlFilter.New.Like('a', 'x', True, rcSensitive).Contains('b', 'y', rcSensitive);
    Esit('T15a PG rcSensitive LIKE', 'WHERE (a LIKE :p1 ESCAPE ''!'') AND (b LIKE :p2 ESCAPE ''!'')', F.GetWhere);
    F := TRadSqlFilter.New.Equal('ad', 'ali', rcInsensitive);
    Esit('T15b PG Eq metin rcInsensitive acik', 'WHERE (lower(ad) = lower(:p1))', F.GetWhere);
    F := TRadSqlFilter.New.Equal('ad', 'ali');
    Esit('T15b0 varsayilan duz islec (lower yok)', 'WHERE (ad = :p1)', F.GetWhere);
    F := TRadSqlFilter.New.Like('a', 'x').Contains('b', 'y');
    Esit('T15b1 varsayilan LIKE (ILIKE degil)', 'WHERE (a LIKE :p1 ESCAPE ''!'') AND (b LIKE :p2 ESCAPE ''!'')', F.GetWhere);
    F := TRadSqlFilter.New.CaseMode(rcDefault).Equal('ad', 'ali');
    Esit('T15b2 CaseMode(rcDefault) = rcDatabase', 'WHERE (ad = :p1)', F.GetWhere);
    F := TRadSqlFilter.New.AddOrderBy('k.ad', True).AddOrderBy('b.doviz');
    Esit('T15g GetOrderByFields oneksiz', 'k.ad DESC, b.doviz ASC', F.GetOrderByFields);
    Esit('T15h GetOrderBy onekli', 'ORDER BY k.ad DESC, b.doviz ASC', F.GetOrderBy);
    Esit('T15i bos siralama', '', TRadSqlFilter.New.GetOrderByFields);
    F := TRadSqlFilter.New.Equal('ad', 'ali', rcSensitive).NotEqual('b', 'x', rcSensitive);
    Esit('T15c PG Eq rcSensitive', 'WHERE (ad = :p1) AND (b <> :p2)', F.GetWhere);
    F := TRadSqlFilter.New.CaseSensitive(True).Equal('ad', 'ali').Like('b', 'x').Contains('c', 'y', rcInsensitive);
    Esit('T15d filtre geneli duyarli, cagri basina ezme',
      'WHERE (ad = :p1) AND (b LIKE :p2 ESCAPE ''!'') AND (c ILIKE :p3 ESCAPE ''!'')', F.GetWhere);
    F := TRadSqlFilter.New.Equal('n', 5).Greater('s', 'abc');
    Esit('T15e sayi ve siralama islecleri harf modundan etkilenmez', 'WHERE (n = :p1) AND (s > :p2)', F.GetWhere);
    F := TRadSqlFilter.New.CaseMode(rcDatabase).Like('a', 'x').Equal('b', 'y');
    Esit('T15f rcDatabase duz islec', 'WHERE (a LIKE :p1 ESCAPE ''!'') AND (b = :p2)', F.GetWhere);

    Writeln('=== Lehceler ===');
    F := TRadSqlFilter.New(sdMSSQL).CaseSensitive(False).Like('a', 'x[1]').Equal('b', 'y');
    Esit('T16a MSSQL duyarsiz UPPER', 'WHERE (UPPER(a) LIKE UPPER(:p1) ESCAPE ''!'') AND (UPPER(b) = UPPER(:p2))', F.GetWhere);
    Esit('T16b MSSQL [ kacirilir', 'p1=x![1];p2=y;', ParamStr(F));
    F := TRadSqlFilter.New(sdMSSQL).CaseMode(rcDatabase).Like('a', 'x');
    Esit('T16c MSSQL rcDatabase', 'WHERE (a LIKE :p1 ESCAPE ''!'')', F.GetWhere);
    F := TRadSqlFilter.New(sdPostgreSQL).Like('a', 'x[1]');
    Esit('T16d PG [ kacirilmaz', 'p1=x[1];', ParamStr(F));
    F := TRadSqlFilter.New(sdFirebird).CaseSensitive(False).Like('a', 'x').NotLike('b', 'y', True, rcSensitive);
    Esit('T17a Firebird', 'WHERE (UPPER(a) LIKE UPPER(:p1) ESCAPE ''!'') AND (b NOT LIKE :p2 ESCAPE ''!'')', F.GetWhere);
    F := TRadSqlFilter.New(sdMySQL).CaseSensitive(False).Contains('a', 'x');
    Esit('T17b MySQL', 'WHERE (UPPER(a) LIKE UPPER(:p1) ESCAPE ''!'')', F.GetWhere);
    F := TRadSqlFilter.New.CaseSensitive(False).Dialect(sdFirebird).Like('a', 'x');
    Esit('T17c Dialect sonradan', 'WHERE (UPPER(a) LIKE UPPER(:p1) ESCAPE ''!'')', F.GetWhere);

    Writeln('=== OR grubu ===');
    F := TRadSqlFilter.New.Equal('a', 1).BeginOr.Equal('b', 2).Equal('c', 3).EndOr.Equal('d', 4);
    Esit('T18a AND + OR grubu', 'WHERE (a = :p1) AND ((b = :p2) OR (c = :p3)) AND (d = :p4)', F.GetWhere);
    F := TRadSqlFilter.New.BeginOr.Equal('b', 2).Equal('c', '').EndOr;
    Esit('T18b grupta tek kosul kalirsa', 'WHERE (b = :p1)', F.GetWhere);
    F := TRadSqlFilter.New.Equal('a', 1).BeginOr.Equal('b', '').EndOr;
    Esit('T18c grup bos kalirsa', 'WHERE (a = :p1)', F.GetWhere);
    F := TRadSqlFilter.New.BeginOr.Equal('a', 1).EndOr.BeginOr.Equal('b', 2).Equal('c', 3).EndOr;
    Esit('T18d iki ayri grup', 'WHERE (a = :p1) AND ((b = :p2) OR (c = :p3))', F.GetWhere);
    Firlatir('T18e ic ice BeginOr', procedure begin TRadSqlFilter.New.BeginOr.BeginOr; end);
    Firlatir('T18f Begin olmadan EndOr', procedure begin TRadSqlFilter.New.EndOr; end);
    Firlatir('T18g acik grupla GetWhere', procedure begin TRadSqlFilter.New.BeginOr.Equal('a', 1).GetWhere; end);

    Writeln('=== OrderBy ===');
    F := TRadSqlFilter.New.AddOrderBy('adi', True).AddOrderBy('soyad');
    Esit('T19a iki alan', 'ORDER BY adi DESC, soyad ASC', F.GetOrderBy);
    Esit('T19b GetWhere bos, GetSql yalniz ORDER BY', 'ORDER BY adi DESC, soyad ASC', F.GetSql);
    F.Equal('x', 1);
    Esit('T19c GetSql ikisi', 'WHERE (x = :p1) ORDER BY adi DESC, soyad ASC', F.GetSql);
    F := TRadSqlFilter.New.AddOrderBy('t.ad').AddOrderBy('_x9');
    Esit('T19d nokta ve alt cizgi gecerli', 'ORDER BY t.ad ASC, _x9 ASC', F.GetOrderBy);
    Firlatir('T19e gecersiz ad (bosluk)', procedure begin TRadSqlFilter.New.AddOrderBy('ad; drop'); end);
    Firlatir('T19f gecersiz ad (parantez)', procedure begin TRadSqlFilter.New.AddOrderBy('lower(ad)'); end);
    Firlatir('T19g bos ad', procedure begin TRadSqlFilter.New.AddOrderBy(''); end);
    Firlatir('T19h rakamla baslayan', procedure begin TRadSqlFilter.New.AddOrderBy('1ad'); end);

    Writeln('=== Clear ===');
    F := TRadSqlFilter.New(sdMSSQL).Wildcards('*', '?').CaseSensitive(True).ParamPrefix('q')
      .Equal('a', 1).BeginOr.Equal('b', 2).AddOrderBy('c');
    F.Clear;
    Esit('T20a Clear sonrasi bos', '', F.GetSql);
    Kontrol('T20b parametre yok', F.ParamCount = 0);
    F.Like('ad', '*x').AddOrderBy('z');
    Esit('T20c ayarlar korunur (lehce, joker, harf, onek), sayac bastan',
      'WHERE (ad LIKE :q1 ESCAPE ''!'') ORDER BY z ASC', F.GetSql);
    Esit('T20d joker ayari korunmus', 'q1=%x;', ParamStr(F));
    F := TRadSqlFilter.New.Equal('a', 1).AddOrderBy('b');
    F.ClearConditions;
    Esit('T20e ClearConditions', 'ORDER BY b ASC', F.GetSql);
    F := TRadSqlFilter.New.Equal('a', 1).AddOrderBy('b');
    F.ClearOrderBy;
    Esit('T20f ClearOrderBy', 'WHERE (a = :p1)', F.GetSql);

    Writeln('=== ParamPrefix ve Raw ===');
    F := TRadSqlFilter.New.ParamPrefix('f').Equal('a', 1).Equal('b', 2);
    Esit('T21a onek', 'WHERE (a = :f1) AND (b = :f2)', F.GetWhere);
    Firlatir('T21b bos onek', procedure begin TRadSqlFilter.New.ParamPrefix(''); end);
    Firlatir('T21c gecersiz onek', procedure begin TRadSqlFilter.New.ParamPrefix('1x'); end);
    F := TRadSqlFilter.New.Equal('a', 1).Raw('exists (select 1 from h where h.id = c.id and h.t = ?)', [5]);
    Esit('T22a Raw ? -> :pN', 'WHERE (a = :p1) AND (exists (select 1 from h where h.id = c.id and h.t = :p2))', F.GetWhere);
    Esit('T22b Raw parametre', 'p1=1;p2=5;', ParamStr(F));
    F := TRadSqlFilter.New.Raw('a = b', []);
    Esit('T22c Raw parametresiz', 'WHERE (a = b)', F.GetWhere);
    Firlatir('T22d Raw ? sayisi uyusmaz', procedure begin TRadSqlFilter.New.Raw('a = ?', []); end);
    Firlatir('T22e Raw bos SQL', procedure begin TRadSqlFilter.New.Raw('', []); end);
    F := TRadSqlFilter.New.Raw('a = ? or b = ?', [Null, 1]);
    Esit('T22f Raw Null degeri atlamaz', 'WHERE (a = :p1 or b = :p2)', F.GetWhere);

    Writeln('=== IsNull ===');
    F := TRadSqlFilter.New.IsNull('a').IsNotNull('b');
    Esit('T23a IsNull/IsNotNull', 'WHERE (a IS NULL) AND (b IS NOT NULL)', F.GetWhere);
    Kontrol('T23b parametre yok', F.ParamCount = 0);
    F := TRadSqlFilter.New.Mode(rfmStrict).IsNull('a');
    Esit('T23c Strict IsNull', 'WHERE (a IS NULL)', F.GetWhere);

    Writeln('=== Alan adi ===');
    Firlatir('T24a bos alan', procedure begin TRadSqlFilter.New.Equal('', 1); end);
    Firlatir('T24b bos alan Like', procedure begin TRadSqlFilter.New.Like(' ', 'x'); end);
    F := TRadSqlFilter.New.Equal('coalesce(a, b)', 1);
    Esit('T24c ifade kabul edilir', 'WHERE (coalesce(a, b) = :p1)', F.GetWhere);

    Writeln('=== Deger tipleri ===');
    F := TRadSqlFilter.New.Equal('a', Double(1.5)).Equal('b', True).Equal('c', D1);
    Kontrol('T25 Variant tipleri korunur', (VarType(F.Params[0].Value) = varDouble) and
      (VarType(F.Params[1].Value) = varBoolean) and (VarType(F.Params[2].Value) = varDate),
      Format('%d %d %d', [VarType(F.Params[0].Value), VarType(F.Params[1].Value), VarType(F.Params[2].Value)]));
    Writeln('=== NotBetween / NotContains ===');
    F := TRadSqlFilter.New.NotBetween('t', 1, 5);
    Esit('T26a NotBetween', 'WHERE (t NOT BETWEEN :p1 AND :p2)', F.GetWhere);
    F := TRadSqlFilter.New.NotBetween('t', 1, Null);
    Esit('T26b NotBetween yalniz baslangic', 'WHERE (t < :p1)', F.GetWhere);
    F := TRadSqlFilter.New.NotBetween('t', Null, 5);
    Esit('T26c NotBetween yalniz bitis', 'WHERE (t > :p1)', F.GetWhere);
    F := TRadSqlFilter.New.NotBetween('t', Null, Null);
    Esit('T26d NotBetween bos atlanir', '', F.GetWhere);
    F := TRadSqlFilter.New.CaseSensitive(False).NotContains('ad', 'x%');
    Esit('T27a NotContains', 'WHERE (ad NOT ILIKE :p1 ESCAPE ''!'')', F.GetWhere);
    Esit('T27b NotContains deger', 'p1=%x!%%;', ParamStr(F));
    F := TRadSqlFilter.New(sdMSSQL).CaseSensitive(False).NotContains('ad', 'x');
    Esit('T27c NotContains MSSQL', 'WHERE (UPPER(ad) NOT LIKE UPPER(:p1) ESCAPE ''!'')', F.GetWhere);
    F := TRadSqlFilter.New.NotContains('ad', '');
    Esit('T27d NotContains bos atlanir', '', F.GetWhere);

    Writeln('=== WholeDay (saatsiz tarih = tum gun) ===');
    D1 := EncodeDate(2026, 10, 31);
    D2 := EncodeDate(2026, 11, 1);
    F := TRadSqlFilter.New.Equal('t', D1);
    Esit('T28a Equal gun -> [gun, gun+1)', 'WHERE (t >= :p1 AND t < :p2)', F.GetWhere);
    Kontrol('T28b parametreler gun, gun+1', (F.Params[0].Value = D1) and (F.Params[1].Value = D2));
    F := TRadSqlFilter.New.NotEqual('t', D1);
    Esit('T28c NotEqual gun', 'WHERE (t < :p1 OR t >= :p2)', F.GetWhere);
    F := TRadSqlFilter.New.Greater('t', D1);
    Esit('T28d Greater gun -> >= gun+1', 'WHERE (t >= :p1)', F.GetWhere);
    Kontrol('T28e Greater parametre gun+1', F.Params[0].Value = D2);
    F := TRadSqlFilter.New.GreaterEqual('t', D1);
    Kontrol('T28f GreaterEqual gun', (F.GetWhere = 'WHERE (t >= :p1)') and (F.Params[0].Value = D1));
    F := TRadSqlFilter.New.Less('t', D1);
    Kontrol('T28g Less gun', (F.GetWhere = 'WHERE (t < :p1)') and (F.Params[0].Value = D1));
    F := TRadSqlFilter.New.LessEqual('t', D1);
    Kontrol('T28h LessEqual gun -> < gun+1', (F.GetWhere = 'WHERE (t < :p1)') and (F.Params[0].Value = D2));
    F := TRadSqlFilter.New.Between('t', EncodeDate(2026, 10, 1), D1);
    Esit('T28i Between gun -> [bas, bit+1)', 'WHERE (t >= :p1 AND t < :p2)', F.GetWhere);
    Kontrol('T28j Between bitis gun+1', F.Params[1].Value = D2);
    F := TRadSqlFilter.New.NotBetween('t', EncodeDate(2026, 10, 1), D1);
    Esit('T28k NotBetween gun', 'WHERE (t < :p1 OR t >= :p2)', F.GetWhere);
    F := TRadSqlFilter.New.Between('t', D1, Null);
    Kontrol('T28l Between yalniz baslangic gun', (F.GetWhere = 'WHERE (t >= :p1)') and (F.Params[0].Value = D1));
    F := TRadSqlFilter.New.Between('t', Null, D1);
    Kontrol('T28m Between yalniz bitis gun -> < gun+1', (F.GetWhere = 'WHERE (t < :p1)') and (F.Params[0].Value = D2));
    D3 := D1 + 0.5;
    F := TRadSqlFilter.New.Equal('t', D3);
    Esit('T28n saatli deger duz esitlik', 'WHERE (t = :p1)', F.GetWhere);
    Kontrol('T28n2 saatli deger varDate kaldi', VarType(F.Params[0].Value) = varDate);
    F := TRadSqlFilter.New.WholeDay(False).Equal('t', D1).Greater('u', D1);
    Esit('T28o WholeDay kapali', 'WHERE (t = :p1) AND (u > :p2)', F.GetWhere);
    F := TRadSqlFilter.New.Between('t', EncodeDate(2026, 10, 1), D3);
    Esit('T28p bitis saatli -> BETWEEN', 'WHERE (t BETWEEN :p1 AND :p2)', F.GetWhere);
    F := TRadSqlFilter.New.InList('t', [D1]);
    Esit('T28q InList gun degismez', 'WHERE (t IN (:p1))', F.GetWhere);
    F := TRadSqlFilter.New.Equal('n', 5).Equal('s', 'x', rcDatabase);
    Esit('T28r sayi ve metin etkilenmez', 'WHERE (n = :p1) AND (s = :p2)', F.GetWhere);

    Writeln('=== GetDebugSql ===');
    F := TRadSqlFilter.New.Equal('ad', 'O''Brien', rcDatabase).Greater('n', 10).Equal('b', True)
      .Equal('t', D3).Equal('x', Double(1.5)).IsNull('z').AddOrderBy('ad');
    Esit('T29a PG', 'WHERE (ad = ''O''''Brien'') AND (n > 10) AND (b = true) AND ' +
      '(t = ''2026-10-31 12:00:00'') AND (x = 1.5) AND (z IS NULL) ORDER BY ad ASC', F.GetDebugSql);
    F := TRadSqlFilter.New(sdMSSQL).Equal('b', True).Equal('t', D1);
    Esit('T29b MSSQL bool 1, gun', 'WHERE (b = 1) AND (t >= ''2026-10-31'' AND t < ''2026-11-01'')', F.GetDebugSql);
    F := TRadSqlFilter.New.InList('c', [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
    Esit('T29c :p1 ile :p10/:p11 karismaz', 'WHERE (c IN (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11))', F.GetDebugSql);
    F := TRadSqlFilter.New.Raw('a = ?', [Null]);
    Esit('T29d NULL', 'WHERE (a = NULL)', F.GetDebugSql);
    Esit('T29e GetSql degismez', 'WHERE (a = :p1)', F.GetSql);
    F := TRadSqlFilter.New.CaseSensitive(False).Contains('ad', 'x');
    Esit('T29f ESCAPE korunur', 'WHERE (ad ILIKE ''%x%'' ESCAPE ''!'')', F.GetDebugSql);

    Writeln('=== RadSqlHasSetOperator ===');
    Kontrol('T30a duz sorgu', not RadSqlHasSetOperator('select a from t where b = 1'));
    Kontrol('T30b union', RadSqlHasSetOperator('select a from t UNION ALL select a from u'));
    Kontrol('T30c intersect', RadSqlHasSetOperator('select a from t intersect select a from u'));
    Kontrol('T30d except', RadSqlHasSetOperator('select a from t' + sLineBreak + 'except' + sLineBreak + 'select a from u'));
    Kontrol('T30e alt sorguda sayilmaz', not RadSqlHasSetOperator('select * from (select a from t union select a from u) x'));
    Kontrol('T30f CTE icinde sayilmaz', not RadSqlHasSetOperator('with x as (select a from t union select a from u) select * from x'));
    Kontrol('T30g metin icinde sayilmaz', not RadSqlHasSetOperator('select ''a union b'' from t'));
    Kontrol('T30h kacisli metin', not RadSqlHasSetOperator('select ''o''''union'' from t'));
    Kontrol('T30i tirnakli ad', not RadSqlHasSetOperator('select "union" from t'));
    Kontrol('T30j satir yorumu', not RadSqlHasSetOperator('select a -- union' + sLineBreak + 'from t'));
    Kontrol('T30k blok yorumu', not RadSqlHasSetOperator('select /* union */ a from t'));
    Kontrol('T30l kelime parcasi', not RadSqlHasSetOperator('select union_id, reunion, union2 from t'));
    Kontrol('T30m yorum sonrasi union', RadSqlHasSetOperator('select a /* x */ from t union select 1'));
    Kontrol('T30n parantez kapaninca', RadSqlHasSetOperator('(select a from t) union (select a from u)'));
    Kontrol('T30o kapanmamis tirnak', not RadSqlHasSetOperator('select ''union'));
    Kontrol('T30p bos', not RadSqlHasSetOperator(''));
  except
    on E: Exception do
    begin
      Inc(GHata);
      Writeln('  [PATLADI] ', E.ClassName, ': ', E.Message);
    end;
  end;
  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    Halt(1);
end.
