program FilterFlowLiveTest;

(*
  CANLI: Help.uni _UseFilter/_OpenFilter (PostgreSQL, %LOCALAPPDATA%\rad\test-db.env, RAD_PG_ degiskenleri).
  Yalniz oturuma ozel gecici tablo kullanir; baglanti kapaninca kaybolur.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, System.IOUtils, Data.DB,
  Uni, UniProvider, PostgreSQLUniProvider, DBAccess,
  rad.sqlfilter, Help.uni;

const
  TBL = 'zz_filtre_akis';

var
  GBasari: Integer = 0;
  GHata: Integer = 0;
  GEnv: TStringList;
  Con: TUniConnection;

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
begin
  Result := GetEnvironmentVariable(AKey);
  if Result = '' then
    Result := GEnv.Values[AKey];
  if Result = '' then
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

procedure Sayi(const AAd: string; ABeklenen: Integer; ADs: TCustomDADataSet);
begin
  Kontrol(AAd, ADs.RecordCount = ABeklenen,
    Format('beklenen=%d gercek=%d SQL=%s', [ABeklenen, ADs.RecordCount, ADs.FinalSQL]));
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

function Sorgu(const ASql: string): TUniQuery;
begin
  Result := TUniQuery.Create(nil);
  Result.Connection := Con;
  Result.SQL.Text := ASql;
end;

function Filtre: IRadSqlFilter;
begin
  Result := Con._NewFilter;
end;

procedure Calistir(const ASql: string);
var
  Q: TUniQuery;
begin
  Q := Sorgu(ASql);
  try
    Q.Execute;
  finally
    Q.Free;
  end;
end;

procedure KendiKosulu;
var
  Q: TUniQuery;
begin
  Q := Sorgu('select id, kod from ' + TBL + ' where aktif or kod = ''zz'' order by kod');
  try
    Q._OpenFilter(Filtre.Greater('id', 1));
    Sayi('F01 kendi WHERE korunur (OR dahil)', 2, Q);
    Q._OpenFilter(Filtre.Equal('kod', 'c'));
    Sayi('F02 onceki tur kosulu kalmaz', 1, Q);
    Q._OpenFilter(Filtre);
    Sayi('F03 bos filtre kendi WHERE ile acar', 3, Q);
    Kontrol('F04 bos filtrede SQL eski metin', Pos('order by kod', Q.FinalSQL) > 0, Q.FinalSQL);
    Q._OpenFilter(Filtre.Greater('id', 0).AddOrderBy('id', True));
    Kontrol('F05 filtre siralamasi', Q.FieldByName('id').AsInteger = 3, Q.FinalSQL);
    Q._OpenFilter(Filtre.Greater('id', 0));
    Kontrol('F06 varsayilan ORDER BY geri gelir', Q.FieldByName('kod').AsString = 'a', Q.FinalSQL);
    Q._UseFilter(Filtre.Greater('id', 1));
    Kontrol('F07 _UseFilter acmaz', not Q.Active);
  finally
    Q.Free;
  end;
end;

procedure GelistiriciParametresi;
var
  Q: TUniQuery;
begin
  Q := Sorgu('select id from ' + TBL + ' where kod <> :gizli');
  try
    Q.ParamByName('gizli').AsString := 'a';
    Q._OpenFilter(Filtre.Greater('id', 2));
    Sayi('F08 gelistirici parametresi', 2, Q);
    Q._OpenFilter(Filtre.Greater('id', 3));
    Sayi('F09 ikinci turda da', 1, Q);
    Kontrol('F10 deger korundu', Q.ParamByName('gizli').AsString = 'a');
  finally
    Q.Free;
  end;
end;

procedure Tablo;
var
  T: TUniTable;
begin
  T := TUniTable.Create(nil);
  try
    T.Connection := Con;
    T.TableName := TBL;
    T._OpenFilter(Filtre.Greater('id', 1).AddOrderBy('id', True));
    Sayi('F11 TUniTable filtre', 3, T);
    Kontrol('F12 TUniTable siralama', T.FieldByName('id').AsInteger = 4, T.FinalSQL);
    T._OpenFilter(Filtre.Equal('kod', 'a'));
    Sayi('F13 TUniTable ikinci tur', 1, T);
    T._OpenFilter(Filtre);
    Sayi('F14 TUniTable bos filtre', 4, T);
  finally
    T.Free;
  end;
end;

procedure KumeIslecleri;
var
  Q: TUniQuery;
begin
  Q := Sorgu('select id from ' + TBL + ' where aktif union all select id from ' + TBL + ' where not aktif');
  try
    Firlatir('F15 UNION + kosul reddedilir', procedure begin Q._OpenFilter(Filtre.Greater('id', 1)); end);
    Q._OpenFilter(Filtre);
    Sayi('F16 UNION + bos filtre acilir', 4, Q);
    Q._OpenFilter(Filtre.AddOrderBy('id', True));
    Sayi('F17 UNION + yalniz siralama', 4, Q);
  finally
    Q.Free;
  end;
  Q := Sorgu('with x as (select id from ' + TBL + ' where aktif union all select id from ' + TBL +
    ' where not aktif) select id from x');
  try
    Q._OpenFilter(Filtre.Greater('id', 1));
    Sayi('F18 CTE icinde UNION dis WHERE alir', 3, Q);
  finally
    Q.Free;
  end;
end;

procedure AdCakismasi;
var
  Q: TUniQuery;
begin
  Q := Sorgu('select id from ' + TBL + ' where kod <> :p1');
  try
    Q.ParamByName('p1').AsString := 'a';
    Firlatir('F19 ayni ad reddedilir', procedure begin Q._OpenFilter(Filtre.Greater('id', 1)); end);
    Q._OpenFilter(Filtre.ParamPrefix('f').Greater('id', 1));
    Sayi('F20 farkli onekle calisir', 3, Q);
  finally
    Q.Free;
  end;
end;

procedure Makro;
var
  Q: TUniQuery;
begin
  Q := Sorgu('select id &ek from ' + TBL + ' where aktif');
  try
    Q._Macro('ek', ', kod');
    Q._OpenFilter(Filtre.Greater('id', 0));
    Kontrol('F21 makro + filtre', Q.FieldCount = 2, Q.FinalSQL);
    Q._Macro('ek', '');
    Q._OpenFilter(Filtre.Greater('id', 0));
    Kontrol('F22 makro degeri degisir', Q.FieldCount = 1, Q.FinalSQL);
  finally
    Q.Free;
  end;
end;

// YAP-58: kasa.liste editorlerinin gonderdigi deger turleri.
procedure DegerTurleri;
var
  Q: TUniQuery;
begin
  Calistir('create temp table zz_filtre_tur (id uuid, aktif boolean)');
  Calistir('insert into zz_filtre_tur values (''01970000-0000-7000-8000-000000000001'', true), ' +
    '(''01970000-0000-7000-8000-000000000002'', false)');
  Q := Sorgu('select id from zz_filtre_tur');
  try
    Q._OpenFilter(Filtre.Equal('aktif', True));
    Sayi('F23 boolean True', 1, Q);
    Q._OpenFilter(Filtre.Equal('aktif', False));
    Sayi('F24 boolean False', 1, Q);
    Q._OpenFilter(Filtre.Equal('id', '{01970000-0000-7000-8000-000000000002}'));
    Sayi('F25 susulu uuid metni', 1, Q);
  finally
    Q.Free;
  end;
end;

begin
  EnvYukle;
  Con := TUniConnection.Create(nil);
  try
    try
      Con.ProviderName := 'PostgreSQL';
      Con.Server := Env('RAD_PG_HOST', '127.0.0.1');
      Con.Port := StrToIntDef(Env('RAD_PG_PORT', '5432'), 5432);
      Con.Database := Env('RAD_PG_DB', 'testdb');
      Con.Username := Env('RAD_PG_USER', 'postgres');
      Con.Password := Env('RAD_PG_PASS');
      Con.LoginPrompt := False;
      Con.Connect;
      Calistir('create temp table ' + TBL + ' (id int, kod text, aktif boolean)');
      Calistir('insert into ' + TBL + ' values (1, ''a'', true), (2, ''b'', true), (3, ''c'', true), (4, ''d'', false)');
      KendiKosulu;
      GelistiriciParametresi;
      Tablo;
      KumeIslecleri;
      AdCakismasi;
      Makro;
      DegerTurleri;
    except
      on E: Exception do
      begin
        Inc(GHata);
        Writeln('  [PATLADI] ', E.ClassName, ': ', E.Message);
      end;
    end;
  finally
    Con.Free;
  end;
  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    Halt(1);
end.
