program SqlFilterLiveTest;

(*
  CANLI: rad.sqlfilter + Help.uni (_NewFilter/_ApplyFilter) uc sunucuda.
  PostgreSQL : %LOCALAPPDATA%\rad\test-db.env, RAD_PG_ degiskenleri
  SQL Server : localhost, Windows kimlik dogrulamasi, rad_filter_test
  Firebird   : RAD_FB_DB / RAD_FB_USER / RAD_FB_PASS (ayni env dosyasi); yoksa atlanir.
               Yalniz Win32 (64-bit fbclient.dll yok) - RAD_FB_CLIENT64 verilirse Win64 de.
  Yalniz rad_test_filtre tablosu olusturulur ve sonunda silinir.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, System.IOUtils, System.TypInfo, System.DateUtils, Data.DB,
  Uni, UniProvider, PostgreSQLUniProvider, SQLServerUniProvider, InterBaseUniProvider,
  rad.sqlfilter, Help.uni;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;
  GEnv: TStringList;

procedure EnvYukle;
var
  LPath: string;
begin
  GEnv := TStringList.Create;
  LPath := TPath.Combine(TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'), 'rad'), 'test-db.env');
  if TFile.Exists(LPath) then
    GEnv.LoadFromFile(LPath, TEncoding.UTF8);
end;

function Env(const AKey: string; const ADefault: string = ''): string;
var
  i: Integer;
  LLine: string;
begin
  Result := GetEnvironmentVariable(AKey);
  if Result <> '' then Exit;
  for i := 0 to GEnv.Count - 1 do
  begin
    LLine := GEnv[i];
    if LLine.StartsWith(AKey + '=') then
      Exit(Trim(LLine.Substring(Length(AKey) + 1)));
  end;
  Result := ADefault;
end;

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

procedure Olcum(const AAd: string; const ADeger: string);
begin
  Writeln('  [OLCUM] ', AAd, ' = ', ADeger);
end;

procedure Calistir(ACon: TUniConnection; const ASql: string);
var
  LQ: TUniQuery;
begin
  LQ := TUniQuery.Create(nil);
  try
    LQ.Connection := ACon;
    LQ.SQL.Text := ASql;
    LQ.ExecSQL;
  finally
    LQ.Free;
  end;
end;

function Say(ACon: TUniConnection; AF: IRadSqlFilter): Integer;
var
  LQ: TUniQuery;
begin
  LQ := TUniQuery.Create(nil);
  try
    LQ.Connection := ACon;
    LQ.SQL.Text := 'select count(*) from rad_test_filtre ' + AF.GetWhere;
    LQ._ApplyFilter(AF);
    LQ.Open;
    Result := LQ.Fields[0].AsInteger;
  finally
    LQ.Free;
  end;
end;

function IlkId(ACon: TUniConnection; AF: IRadSqlFilter): Integer;
var
  LQ: TUniQuery;
begin
  LQ := TUniQuery.Create(nil);
  try
    LQ.Connection := ACon;
    LQ.SQL.Text := 'select id from rad_test_filtre ' + AF.GetSql;
    LQ._ApplyFilter(AF);
    LQ.Open;
    if LQ.Eof then Result := -1 else Result := LQ.Fields[0].AsInteger;
  finally
    LQ.Free;
  end;
end;

procedure Sayim(ACon: TUniConnection; const AAd: string; AF: IRadSqlFilter; ABeklenen: Integer);
var
  N: Integer;
begin
  try
    N := Say(ACon, AF);
    Kontrol(AAd, N = ABeklenen, Format('beklenen=%d gercek=%d sql=[%s]', [ABeklenen, N, AF.GetWhere]));
  except
    on E: Exception do
      Kontrol(AAd, False, E.ClassName + ': ' + E.Message + ' sql=[' + AF.GetWhere + ']');
  end;
end;

procedure TabloKur(ACon: TUniConnection; ADialect: TRadSqlDialect);
var
  LStr, LTs: string;
  LQ: TUniQuery;
  procedure Satir(AId: Integer; const AAd, ATel, ATip: string; const ATarih, AZaman, ATutar: Variant);
  begin
    LQ.ParamByName('id').AsInteger := AId;
    LQ.ParamByName('ad').AsString := AAd;
    LQ.ParamByName('tel').AsString := ATel;
    if ATip = '' then LQ.ParamByName('tip').Clear else LQ.ParamByName('tip').AsString := ATip;
    if VarIsNull(ATarih) then LQ.ParamByName('tarih').Clear else LQ.ParamByName('tarih').AsDate := ATarih;
    if VarIsNull(AZaman) then LQ.ParamByName('zaman').Clear else LQ.ParamByName('zaman').AsDateTime := AZaman;
    if VarIsNull(ATutar) then LQ.ParamByName('tutar').Clear else LQ.ParamByName('tutar').AsFloat := ATutar;
    LQ.ExecSQL;
  end;
begin
  try
    Calistir(ACon, 'drop table rad_test_filtre');
  except
    // yoksa sorun degil
  end;
  if ADialect = sdMSSQL then LStr := 'nvarchar' else LStr := 'varchar';
  if ADialect = sdMSSQL then LTs := 'datetime2' else LTs := 'timestamp';
  Calistir(ACon, Format('create table rad_test_filtre (id integer not null primary key, ad %s(40), ' +
    'tel %s(20), tip %s(5), tarih date, zaman %s, tutar numeric(10,2))', [LStr, LStr, LStr, LTs]));
  LQ := TUniQuery.Create(nil);
  try
    LQ.Connection := ACon;
    LQ.SQL.Text := 'insert into rad_test_filtre (id, ad, tel, tip, tarih, zaman, tutar) ' +
      'values (:id, :ad, :tel, :tip, :tarih, :zaman, :tutar)';
    LQ.ParamByName('tip').DataType := ftString;
    LQ.ParamByName('tarih').DataType := ftDate;
    LQ.ParamByName('zaman').DataType := ftDateTime;
    LQ.ParamByName('tutar').DataType := ftFloat;
    // 'i/I' icermeyen adlar: Turkce collation'da UPPER('i') = 'İ', ALI <> ALİ. Türkçe ölçümleri ayrı (T1..T4).
    Satir(1, 'Ela', '0555 1234', 'A', EncodeDate(2026, 1, 5), EncodeDateTime(2026, 1, 5, 10, 30, 0, 0), 10.5);
    Satir(2, 'ela veli', '0555 5595', 'S', EncodeDate(2026, 1, 20), EncodeDateTime(2026, 1, 20, 23, 59, 59, 0), 20);
    Satir(3, '50% indirim', '0212 5595', 'AS', EncodeDate(2026, 2, 1), EncodeDate(2026, 2, 1), 30);
    Satir(4, 'a_b', '', 'A', Null, Null, 40);
    Satir(5, 'ŞENAY', '0555 9999', '', EncodeDate(2026, 3, 1), EncodeDateTime(2026, 3, 1, 8, 0, 0, 0), Null);
    Satir(6, 'İsmail', '', '', Null, Null, 5);
  finally
    LQ.Free;
  end;
end;

procedure Senaryolar(ACon: TUniConnection; const AAd: string);
var
  D: TRadSqlDialect;
  function F: IRadSqlFilter;
  begin
    Result := ACon._NewFilter.CaseSensitive(False);  // varsayilan artik duz islec; olcumler duyarsiz bekler
  end;
begin
  D := ACon._SqlDialect;
  Writeln('--- ', AAd, ' (', GetEnumName(TypeInfo(TRadSqlDialect), Ord(D)), ') ---');
  TabloKur(ACon, D);

  Sayim(ACon, AAd + ' L01 bos filtre tum satirlar', F, 6);
  Sayim(ACon, AAd + ' L02 Eq duyarsiz ELA', F.Equal('ad', 'ELA'), 1);
  Sayim(ACon, AAd + ' L04 Contains duyarsiz ela', F.Contains('ad', 'ela'), 2);
  if D in [sdMSSQL, sdMySQL] then
  begin
    // rcSensitive bu lehçelerde düz işleç: sonuç collation'a bağlı, ölçülür.
    Olcum(AAd + ' L03 Eq duyarli ELA (collation)', IntToStr(Say(ACon, F.Equal('ad', 'ELA', rcSensitive))));
    Olcum(AAd + ' L05 Contains duyarli ela (collation)', IntToStr(Say(ACon, F.Contains('ad', 'ela', rcSensitive))));
  end
  else
  begin
    Sayim(ACon, AAd + ' L03 Eq duyarli ELA', F.Equal('ad', 'ELA', rcSensitive), 0);
    Sayim(ACon, AAd + ' L05 Contains duyarli ela', F.Contains('ad', 'ela', rcSensitive), 1);
  end;
  Sayim(ACon, AAd + ' L06 Like *5595', F.Wildcards('*', '?').Like('tel', '*5595'), 2);
  Sayim(ACon, AAd + ' L07 Like 50%* (% duz)', F.Wildcards('*', '?').Like('ad', '50%*'), 1);
  Sayim(ACon, AAd + ' L08 Contains % duz', F.Contains('ad', '%'), 1);
  Sayim(ACon, AAd + ' L09 Contains _ duz', F.Contains('ad', '_'), 1);
  Sayim(ACon, AAd + ' L10 Like a?b', F.Wildcards('*', '?').Like('ad', 'a?b'), 1);
  Sayim(ACon, AAd + ' L11 EndsWith _b', F.EndsWith('ad', '_b'), 1);
  Sayim(ACon, AAd + ' L12 kacis kapali %5595', F.Like('tel', '%5595', False), 2);
  Sayim(ACon, AAd + ' L13 kacis kapali _ joker', F.Like('ad', 'a_b', False, rcSensitive), 1);
  Sayim(ACon, AAd + ' L14 InList tip A,S', F.InList('tip', ['A', 'S']), 3);
  Sayim(ACon, AAd + ' L15 NotInList tip A (NULL disarida)', F.NotInList('tip', ['A']), 2);
  Sayim(ACon, AAd + ' L16 Between ocak', F.Between('tarih', EncodeDate(2026, 1, 1), EncodeDate(2026, 1, 31)), 2);
  Sayim(ACon, AAd + ' L17 Between tek taraf', F.Between('tarih', EncodeDate(2026, 2, 1), Null), 2);
  Sayim(ACon, AAd + ' L18 IsNull tarih', F.IsNull('tarih'), 2);
  Sayim(ACon, AAd + ' L19 IsNotNull tutar', F.IsNotNull('tutar'), 5);
  Sayim(ACon, AAd + ' L20 OR grubu + Gt', F.BeginOr.Equal('tip', 'S').Equal('tip', 'AS').EndOr.Greater('tutar', 15), 2);
  Sayim(ACon, AAd + ' L21 Raw ?', F.Raw('tutar > ?', [25]), 2);
  Sayim(ACon, AAd + ' L22 Strict bos InList 1=0', ACon._NewFilter(rfmStrict).InList('tip', []), 0);
  Sayim(ACon, AAd + ' L23 Gte/Lte sayi', F.GreaterEqual('tutar', 10).LessEqual('tutar', 30), 3);
  Sayim(ACon, AAd + ' L24 NotEq duyarsiz', F.NotEqual('ad', 'ELA'), 5);
  Sayim(ACon, AAd + ' L25 StartsWith duyarsiz e', F.StartsWith('ad', 'e'), 2);
  Sayim(ACon, AAd + ' L26 bos degerler atlanir', F.Equal('ad', '').InList('tip', []).Between('tarih', Null, Null), 6);
  Kontrol(AAd + ' L27 OrderBy tutar DESC ilk id=4', IlkId(ACon, F.AddOrderBy('tutar', True).IsNotNull('tutar')) = 4);
  Kontrol(AAd + ' L28 OrderBy tip ASC, tutar DESC (tip NULL haric) ilk id=4',
    IlkId(ACon, F.IsNotNull('tip').AddOrderBy('tip').AddOrderBy('tutar', True)) = 4);
  Sayim(ACon, AAd + ' L29 Eq tarih', F.Equal('tarih', EncodeDate(2026, 2, 1)), 1);
  Sayim(ACon, AAd + ' L30 Eq sayi 0 deger', F.Equal('tutar', 0), 0);
  Sayim(ACon, AAd + ' L31 Equal zaman gun (10:30 / 23:59:59 kayitlari)', F.Equal('zaman', EncodeDate(2026, 1, 20)), 1);
  Sayim(ACon, AAd + ' L32 Greater zaman gun', F.Greater('zaman', EncodeDate(2026, 1, 20)), 2);
  Sayim(ACon, AAd + ' L33 GreaterEqual zaman gun', F.GreaterEqual('zaman', EncodeDate(2026, 1, 20)), 3);
  Sayim(ACon, AAd + ' L34 Less zaman gun', F.Less('zaman', EncodeDate(2026, 1, 20)), 1);
  Sayim(ACon, AAd + ' L35 LessEqual zaman gun', F.LessEqual('zaman', EncodeDate(2026, 1, 20)), 2);
  Sayim(ACon, AAd + ' L36 Between zaman gun', F.Between('zaman', EncodeDate(2026, 1, 1), EncodeDate(2026, 1, 20)), 2);
  Sayim(ACon, AAd + ' L37 NotBetween zaman gun (NULL haric)', F.NotBetween('zaman', EncodeDate(2026, 1, 1), EncodeDate(2026, 1, 20)), 2);
  Sayim(ACon, AAd + ' L38 NotEqual zaman gun', F.NotEqual('zaman', EncodeDate(2026, 1, 20)), 3);
  Sayim(ACon, AAd + ' L39 WholeDay kapali, tam zaman', F.WholeDay(False).Equal('zaman', EncodeDate(2026, 2, 1)), 1);
  Sayim(ACon, AAd + ' L40 NotContains ela', F.NotContains('ad', 'ela'), 4);
  Sayim(ACon, AAd + ' L41 NotBetween tutar 10..30', F.NotBetween('tutar', 10, 30), 2);
  Sayim(ACon, AAd + ' L42 Equal tarih (date sutunu) gun araligi', F.Equal('tarih', EncodeDate(2026, 1, 20)), 1);
  Olcum(AAd + ' DEBUG', F.Equal('zaman', EncodeDate(2026, 1, 20)).Contains('ad', 'x').GetDebugSql);
  // Türkçe harf: sonuç lehçeye/collation'a bağlı, ölçülür.
  Olcum(AAd + ' T1 Contains duyarsiz "şenay"', IntToStr(Say(ACon, F.Contains('ad', 'şenay'))) + ' (ŞENAY satiri 1 beklenir)');
  Olcum(AAd + ' T2 Contains duyarsiz "ismail"', IntToStr(Say(ACon, F.Contains('ad', 'ismail'))) + ' (İsmail satiri; noktali I)');
  Olcum(AAd + ' T3 Eq duyarsiz "İSMAİL"', IntToStr(Say(ACon, F.Equal('ad', 'İSMAİL'))));
  Olcum(AAd + ' T4 StartsWith duyarsiz "ı"', IntToStr(Say(ACon, F.StartsWith('ad', 'ı'))) + ' (0 beklenir; I/ı ayrimi)');

  Calistir(ACon, 'drop table rad_test_filtre');
end;

function Baglan(const AAd, AProvider, AServer, ADb, AUser, APass: string; AOpts: TProc<TUniConnection>): TUniConnection;
begin
  Result := TUniConnection.Create(nil);
  try
    Result.ProviderName := AProvider;
    Result.Server := AServer;
    Result.Database := ADb;
    Result.Username := AUser;
    Result.Password := APass;
    Result.LoginPrompt := False;
    if Assigned(AOpts) then AOpts(Result);
    Result.Connect;
    Writeln('Baglandi: ', AAd, ' -> ', AServer, '/', ADb);
  except
    on E: Exception do
    begin
      Writeln('  [BAGLANAMADI] ', AAd, ': ', E.Message);
      Result.Free;
      Result := nil;
    end;
  end;
end;

procedure Sunucu(const AAd: string; ACon: TUniConnection);
begin
  if ACon = nil then
  begin
    Inc(GHata);
    Exit;
  end;
  try
    try
      Senaryolar(ACon, AAd);
    except
      on E: Exception do
      begin
        Inc(GHata);
        Writeln('  [PATLADI] ', AAd, ' ', E.ClassName, ': ', E.Message);
      end;
    end;
  finally
    ACon.Free;
  end;
end;

var
  LCon: TUniConnection;
  LFbClient: string;
begin
  EnvYukle;
  try
    LCon := Baglan('PostgreSQL', 'PostgreSQL', Env('RAD_PG_HOST', '127.0.0.1'), Env('RAD_PG_DB', 'testdb'),
      Env('RAD_PG_USER', 'postgres'), Env('RAD_PG_PASS'),
      procedure(C: TUniConnection) begin C.Port := StrToIntDef(Env('RAD_PG_PORT', '5432'), 5432); end);
    Sunucu('PG', LCon);

    LCon := Baglan('SQL Server', 'SQL Server', Env('RAD_MS_SERVER', 'localhost'), Env('RAD_MS_DB', 'rad_filter_test'), '', '',
      procedure(C: TUniConnection)
      begin
        C.SpecificOptions.Values['Authentication'] := 'auWindows';
        C.SpecificOptions.Values['Provider'] := 'prDirect';
      end);
    Sunucu('MS', LCon);

    {$IFDEF WIN64}
    LFbClient := Env('RAD_FB_CLIENT64');
    {$ELSE}
    LFbClient := Env('RAD_FB_CLIENT', 'C:\Program Files (x86)\Firebird\Firebird_5_0\fbclient.dll');
    {$ENDIF}
    if (Env('RAD_FB_DB') = '') or (LFbClient = '') then
      Writeln('  [ATLANDI] Firebird: RAD_FB_DB/RAD_FB_USER/RAD_FB_PASS (ve Win64 icin RAD_FB_CLIENT64) tanimli degil')
    else
    begin
      LCon := Baglan('Firebird', 'InterBase', Env('RAD_FB_HOST', 'localhost'), Env('RAD_FB_DB'),
        Env('RAD_FB_USER', 'SYSDBA'), Env('RAD_FB_PASS'),
        procedure(C: TUniConnection)
        begin
          C.SpecificOptions.Values['ClientLibrary'] := LFbClient;
          C.SpecificOptions.Values['Charset'] := 'UTF8';
          C.SpecificOptions.Values['UseUnicode'] := 'True';
        end);
      Sunucu('FB', LCon);
    end;
  finally
    GEnv.Free;
  end;
  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    Halt(1);
end.
