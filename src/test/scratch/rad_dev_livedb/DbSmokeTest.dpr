program DbSmokeTest;

(*
  Baglanti duman testi. Buyuk lookup testini yazmadan once "baglanabiliyor
  muyuz, hangi surum, hangi tablolar var" sorusunu cevaplar.

  ! KIMLIK BILGISI KAYNAK KODA YAZILMAZ. Bu depo GitHub'a yayinlaniyor ve
    src/test/scratch git'te izleniyor. Baglanti bilgisi depo DISINDAKI
    %LOCALAPPDATA%\rad\test-db.env dosyasindan ya da RAD_PG_* ortam
    degiskenlerinden okunur.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils,
  Data.DB, Uni, UniProvider, PostgreSQLUniProvider;

type
  TCfg = record
    Host, Port, Db, User, Pass: string;
  end;

function Oku: TCfg;
var
  LPath, LLine, LKey, LVal: string;
  LList: TStringList;
  p: Integer;
begin
  { Once ortam degiskeni, sonra dosya. }
  Result.Host := GetEnvironmentVariable('RAD_PG_HOST');
  Result.Port := GetEnvironmentVariable('RAD_PG_PORT');
  Result.Db   := GetEnvironmentVariable('RAD_PG_DB');
  Result.User := GetEnvironmentVariable('RAD_PG_USER');
  Result.Pass := GetEnvironmentVariable('RAD_PG_PASS');
  if Result.Host <> '' then
    Exit;

  LPath := TPath.Combine(TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'), 'rad'),
    'test-db.env');
  if not TFile.Exists(LPath) then
    raise Exception.CreateFmt(
      'Baglanti yapilandirmasi yok: %s (ya da RAD_PG_* ortam degiskenleri).',
      [LPath]);

  LList := TStringList.Create;
  try
    LList.LoadFromFile(LPath, TEncoding.UTF8);
    for LLine in LList do
    begin
      if (LLine = '') or LLine.StartsWith('#') then
        Continue;
      p := Pos('=', LLine);
      if p = 0 then
        Continue;
      LKey := Trim(Copy(LLine, 1, p - 1));
      LVal := Trim(Copy(LLine, p + 1, MaxInt));
      if LKey = 'RAD_PG_HOST' then Result.Host := LVal
      else if LKey = 'RAD_PG_PORT' then Result.Port := LVal
      else if LKey = 'RAD_PG_DB'   then Result.Db   := LVal
      else if LKey = 'RAD_PG_USER' then Result.User := LVal
      else if LKey = 'RAD_PG_PASS' then Result.Pass := LVal;
    end;
  finally
    LList.Free;
  end;
end;

var
  LCfg: TCfg;
  LCon: TUniConnection;
  LQry: TUniQuery;

begin
  try
    LCfg := Oku;
    Writeln(Format('Baglaniliyor: %s:%s/%s  kullanici=%s  (parola gizli)',
      [LCfg.Host, LCfg.Port, LCfg.Db, LCfg.User]));

    LCon := TUniConnection.Create(nil);
    try
      LCon.ProviderName := 'PostgreSQL';
      LCon.Server := LCfg.Host;
      LCon.Port := StrToIntDef(LCfg.Port, 5432);
      LCon.Database := LCfg.Db;
      LCon.Username := LCfg.User;
      LCon.Password := LCfg.Pass;
      LCon.LoginPrompt := False;
      LCon.Connect;
      Writeln('  BAGLANDI.');

      LQry := TUniQuery.Create(nil);
      try
        LQry.Connection := LCon;

        LQry.SQL.Text := 'select version()';
        LQry.Open;
        Writeln('  surum : ', Copy(LQry.Fields[0].AsString, 1, 60));
        LQry.Close;

        LQry.SQL.Text :=
          'select count(*) from information_schema.tables ' +
          'where table_schema = ''public''';
        LQry.Open;
        Writeln('  public semasindaki tablo sayisi : ', LQry.Fields[0].AsInteger);
        LQry.Close;

        Writeln('  ilk 15 tablo:');
        LQry.SQL.Text :=
          'select table_name from information_schema.tables ' +
          'where table_schema = ''public'' order by table_name limit 15';
        LQry.Open;
        while not LQry.Eof do
        begin
          Writeln('    - ', LQry.Fields[0].AsString);
          LQry.Next;
        end;
        LQry.Close;

        { Kullaniciya soz verildi: rad_test_* disinda hicbir seye dokunulmuyor. }
        LQry.SQL.Text :=
          'select count(*) from information_schema.tables ' +
          'where table_schema = ''public'' and table_name like ''rad\_test\_%''';
        LQry.Open;
        Writeln('  onceden kalmis rad_test_* tablosu : ', LQry.Fields[0].AsInteger);
        LQry.Close;
      finally
        LQry.Free;
      end;
    finally
      LCon.Free;
    end;
    Writeln('TAMAM');
  except
    on E: Exception do
      Writeln('HATA: ', E.ClassName, ': ', E.Message);
  end;
end.
