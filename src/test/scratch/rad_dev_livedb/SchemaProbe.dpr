program SchemaProbe;

(*
  radcore semasini OKUR - hicbir sey degistirmez, hicbir tablo yaratmaz.
  Amac: sube/yetki modelinin bugun nasil durdugunu gormek.

  ! Kimlik bilgisi kaynak koda yazilmaz - %LOCALAPPDATA%\rad\test-db.env
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, System.StrUtils, Data.DB,
  Uni, UniProvider, PostgreSQLUniProvider;

type
  TCfg = record Host, Port, Db, User, Pass: string; end;

function Oku: TCfg;
var
  LPath, LLine, LKey, LVal: string;
  LList: TStringList;
  p: Integer;
begin
  Result.Host := GetEnvironmentVariable('RAD_PG_HOST');
  Result.Port := GetEnvironmentVariable('RAD_PG_PORT');
  Result.Db   := GetEnvironmentVariable('RAD_PG_DB');
  Result.User := GetEnvironmentVariable('RAD_PG_USER');
  Result.Pass := GetEnvironmentVariable('RAD_PG_PASS');
  if Result.Host <> '' then Exit;
  LPath := TPath.Combine(TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'), 'rad'),
    'test-db.env');
  if not TFile.Exists(LPath) then
    raise Exception.CreateFmt('Baglanti yapilandirmasi yok: %s', [LPath]);
  LList := TStringList.Create;
  try
    LList.LoadFromFile(LPath, TEncoding.UTF8);
    for LLine in LList do
    begin
      if (LLine = '') or LLine.StartsWith('#') then Continue;
      p := Pos('=', LLine);
      if p = 0 then Continue;
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
  LQ: TUniQuery;
  LTablo: TStringList;
  i: Integer;

begin
  try
    LCfg := Oku;
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

      LQ := TUniQuery.Create(nil);
      LTablo := TStringList.Create;
      try
        LQ.Connection := LCon;

        LQ.SQL.Text :=
          'select table_name from information_schema.tables ' +
          'where table_schema = ''public'' order by table_name';
        LQ.Open;
        while not LQ.Eof do
        begin
          LTablo.Add(LQ.Fields[0].AsString);
          LQ.Next;
        end;
        LQ.Close;

        for i := 0 to LTablo.Count - 1 do
        begin
          Writeln('=== ', LTablo[i], ' ===');
          LQ.SQL.Text :=
            'select column_name, data_type, is_nullable ' +
            'from information_schema.columns ' +
            'where table_schema = ''public'' and table_name = :t ' +
            'order by ordinal_position';
          LQ.ParamByName('t').AsString := LTablo[i];
          LQ.Open;
          while not LQ.Eof do
          begin
            Writeln(Format('    %-24s %-20s %s',
              [LQ.Fields[0].AsString, LQ.Fields[1].AsString,
               IfThen(LQ.Fields[2].AsString = 'NO', 'not null', '')]));
            LQ.Next;
          end;
          LQ.Close;

          LQ.SQL.Text := Format('select count(*) from %s', [LTablo[i]]);
          LQ.Open;
          Writeln('    -> ', LQ.Fields[0].AsInteger, ' kayit');
          LQ.Close;
          Writeln;
        end;
      finally
        LTablo.Free;
        LQ.Free;
      end;
    finally
      LCon.Free;
    end;
  except
    on E: Exception do
      Writeln('HATA: ', E.ClassName, ': ', E.Message);
  end;
end.
