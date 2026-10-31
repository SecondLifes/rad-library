program FbDdlProbe;

(* Sonda: UniDAC InterBase saglayicisinda StartTransaction icinde DDL + basarisiz
   insert + Rollback sonrasi kolon kaliyor mu, InTransaction ne diyor? *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, Data.DB,
  Uni, UniProvider, InterBaseUniProvider;

var
  GEnv: TStringList;

function Env(const AKey: string; const ADefault: string = ''): string;
var
  i: Integer;
begin
  Result := GetEnvironmentVariable(AKey);
  if Result <> '' then Exit;
  for i := 0 to GEnv.Count - 1 do
    if GEnv[i].StartsWith(AKey + '=') then
      Exit(Trim(GEnv[i].Substring(Length(AKey) + 1)));
  Result := ADefault;
end;

function KolonVar(C: TUniConnection; const ACol: string): Boolean;
var
  Q: TUniQuery;
begin
  Q := TUniQuery.Create(nil);
  try
    Q.Connection := C;
    Q.SQL.Text := 'select count(*) from rdb$relation_fields where trim(rdb$relation_name) = ''RAD_PROBE'' and trim(rdb$field_name) = ''' + ACol + '''';
    Q.Open;
    Result := Q.Fields[0].AsInteger > 0;
  finally
    Q.Free;
  end;
end;

procedure Dene(C: TUniConnection; const AAd: string; AProc: TProc);
begin
  Writeln('--- ', AAd);
  try
    AProc;
    Writeln('  istisna yok');
  except
    on E: Exception do Writeln('  istisna: ', E.ClassName, ' ', StringReplace(E.Message, #13#10, ' / ', [rfReplaceAll]));
  end;
  Writeln('  InTransaction=', C.InTransaction, ' DefaultTransaction.Active=', C.DefaultTransaction.Active);
end;

var
  C: TUniConnection;
  Q: TUniQuery;
begin
  GEnv := TStringList.Create;
  GEnv.LoadFromFile(TPath.Combine(TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'), 'rad'), 'test-db.env'), TEncoding.UTF8);
  C := TUniConnection.Create(nil);
  try
    C.ProviderName := 'InterBase';
    C.Server := Env('RAD_FB_HOST', 'localhost');
    C.Database := Env('RAD_FB_DB');
    C.Username := Env('RAD_FB_USER', 'SYSDBA');
    C.Password := Env('RAD_FB_PASS');
    C.LoginPrompt := False;
    C.SpecificOptions.Values['ClientLibrary'] := Env('RAD_FB_CLIENT', 'C:\Program Files (x86)\Firebird\Firebird_5_0\fbclient.dll');
    C.SpecificOptions.Values['Charset'] := 'UTF8';
    C.SpecificOptions.Values['UseUnicode'] := 'True';
    C.Connect;
    Writeln('AutoCommit=', C.AutoCommit, ' InTransaction(basta)=', C.InTransaction);
    try C.ExecSQL('drop table rad_probe'); except end;
    C.ExecSQL('create table rad_probe (id integer primary key, ad varchar(5))');
    Writeln('create sonrasi InTransaction=', C.InTransaction);

    Dene(C, 'A: StartTransaction; DDL; kotu insert; Rollback', procedure
      begin
        C.StartTransaction;
        try
          C.ExecSQL('alter table rad_probe add k1 varchar(10)');
          Writeln('  DDL sonrasi InTransaction=', C.InTransaction);
          C.ExecSQL('insert into rad_probe (id, ad) values (1, ''cokuzunmetin'')');
          C.Commit;
        except
          C.Rollback;
          Writeln('  Rollback sonrasi InTransaction=', C.InTransaction);
          raise;
        end;
      end);
    Writeln('  k1 var mi: ', KolonVar(C, 'K1'));

    Dene(C, 'B: StartTransaction; DDL; Rollback (insert yok)', procedure
      begin
        C.StartTransaction;
        C.ExecSQL('alter table rad_probe add k2 varchar(10)');
        C.Rollback;
      end);
    Writeln('  k2 var mi: ', KolonVar(C, 'K2'));

    Dene(C, 'C: TUniQuery ile DDL, ayni transaction', procedure
      begin
        C.StartTransaction;
        try
          Q := TUniQuery.Create(nil);
          try
            Q.Connection := C;
            Q.SQL.Text := 'alter table rad_probe add k3 varchar(10)';
            Q.ExecSQL;
            Q.SQL.Text := 'insert into rad_probe (id, ad) values (2, ''cokuzunmetin'')';
            Q.ExecSQL;
          finally
            Q.Free;
          end;
          C.Commit;
        except
          C.Rollback;
          raise;
        end;
      end);
    Writeln('  k3 var mi: ', KolonVar(C, 'K3'));

    Dene(C, 'D: kotu insert sonrasi Rollback; sonra InTransaction', procedure
      begin
        C.StartTransaction;
        try
          C.ExecSQL('insert into rad_probe (id, ad) values (3, ''cokuzunmetin'')');
          C.Commit;
        except
          C.Rollback;
          raise;
        end;
      end);
    Dene(C, 'E: TUniQuery SpecificOptions AutoCommit=False ile DDL + kotu insert; Rollback', procedure
      begin
        C.StartTransaction;
        try
          Q := TUniQuery.Create(nil);
          try
            Q.Connection := C;
            Q.SpecificOptions.Values['AutoCommit'] := 'False';
            Q.SQL.Text := 'alter table rad_probe add k5 varchar(10)';
            Q.ExecSQL;
            Writeln('  DDL sonrasi InTransaction=', C.InTransaction);
            Q.SQL.Text := 'insert into rad_probe (id, ad) values (5, ''cokuzunmetin'')';
            Q.ExecSQL;
          finally
            Q.Free;
          end;
          C.Commit;
        except
          C.Rollback;
          raise;
        end;
      end);
    Writeln('  k5 var mi: ', KolonVar(C, 'K5'));

    Dene(C, 'F: Connection.AutoCommit=False ile ExecSQL DDL + kotu insert; Rollback', procedure
      begin
        C.AutoCommit := False;
        try
          C.StartTransaction;
          try
            C.ExecSQL('alter table rad_probe add k6 varchar(10)');
            C.ExecSQL('insert into rad_probe (id, ad) values (6, ''cokuzunmetin'')');
            C.Commit;
          except
            C.Rollback;
            raise;
          end;
        finally
          C.AutoCommit := True;
        end;
      end);
    Writeln('  k6 var mi: ', KolonVar(C, 'K6'));

    Dene(C, 'G: E gibi ama iyi insert; Commit', procedure
      begin
        C.StartTransaction;
        Q := TUniQuery.Create(nil);
        try
          Q.Connection := C;
          Q.SpecificOptions.Values['AutoCommit'] := 'False';
          Q.SQL.Text := 'alter table rad_probe add k7 varchar(10)';
          Q.ExecSQL;
          Q.SQL.Text := 'insert into rad_probe (id, ad) values (7, ''kisa'')';
          Q.ExecSQL;
        finally
          Q.Free;
        end;
        C.Commit;
      end);
    Writeln('  k7 var mi: ', KolonVar(C, 'K7'));
    if C.InTransaction then C.Commit;
    Dene(C, 'H: ayri TUniTransaction, AutoCommit=False sorgular, DDL + kotu insert; Rollback', procedure
      var T: TUniTransaction;
      begin
        T := TUniTransaction.Create(nil);
        try
          T.DefaultConnection := C;
          T.StartTransaction;
          try
            Q := TUniQuery.Create(nil);
            try
              Q.Connection := C;
              Q.Transaction := T;
              Q.SpecificOptions.Values['AutoCommit'] := 'False';
              Q.SQL.Text := 'alter table rad_probe add k8 varchar(10)';
              Q.ExecSQL;
              Q.SQL.Text := 'insert into rad_probe (id, ad) values (8, ''cokuzunmetin'')';
              Q.ExecSQL;
            finally
              Q.Free;
            end;
            T.Commit;
          except
            T.Rollback;
            raise;
          end;
        finally
          T.Free;
        end;
      end);
    Writeln('  k8 var mi: ', KolonVar(C, 'K8'));
    if C.InTransaction then C.Commit;

    Dene(C, 'I: H gibi, iyi insert; Commit', procedure
      var T: TUniTransaction;
      begin
        T := TUniTransaction.Create(nil);
        try
          T.DefaultConnection := C;
          T.StartTransaction;
          Q := TUniQuery.Create(nil);
          try
            Q.Connection := C;
            Q.Transaction := T;
            Q.SpecificOptions.Values['AutoCommit'] := 'False';
            Q.SQL.Text := 'alter table rad_probe add k9 varchar(10)';
            Q.ExecSQL;
            Q.SQL.Text := 'insert into rad_probe (id, ad) values (9, ''kisa'')';
            Q.ExecSQL;
          finally
            Q.Free;
          end;
          T.Commit;
        finally
          T.Free;
        end;
      end);
    Writeln('  k9 var mi: ', KolonVar(C, 'K9'));
    if C.InTransaction then C.Commit;

    Dene(C, 'J: ana sorgu ACIKKEN ayri transaction ile DDL (object in use?)', procedure
      var T: TUniTransaction; QA: TUniQuery;
      begin
        QA := TUniQuery.Create(nil);
        try
          QA.Connection := C;
          QA.SQL.Text := 'select * from rad_probe';
          QA.Open;
          T := TUniTransaction.Create(nil);
          try
            T.DefaultConnection := C;
            T.StartTransaction;
            try
              Q := TUniQuery.Create(nil);
              try
                Q.Connection := C;
                Q.Transaction := T;
                Q.SpecificOptions.Values['AutoCommit'] := 'False';
                Q.SQL.Text := 'alter table rad_probe add k10 varchar(10)';
                Q.ExecSQL;
              finally
                Q.Free;
              end;
              T.Commit;
            except
              T.Rollback;
              raise;
            end;
          finally
            T.Free;
          end;
        finally
          QA.Free;
        end;
      end);
    Writeln('  k10 var mi: ', KolonVar(C, 'K10'));
    if C.InTransaction then C.Commit;
    try C.ExecSQL('drop table rad_probe'); except on E: Exception do Writeln('drop: ', E.Message); end;
  finally
    C.Free;
    GEnv.Free;
  end;
end.
