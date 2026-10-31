program CustomFieldLiveTest;

(*
  CANLI: rad.customfield + Help.uni (TRadUniCustomFieldStore, _CustomFieldColumns,
  _ApplyCustomFieldMacro, _EnsureCustomFields) uc sunucuda.
  Baglanti bilgileri: %LOCALAPPDATA%\rad\test-db.env (SqlFilterLiveTest ile ayni).
  Yalniz rad_test_cf + ozel_alan_grup/ozel_alan/ozel_alan_duzen olusturulur, sonunda silinir.
  Firebird yalniz Win32 (64-bit fbclient.dll yok).
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, System.IOUtils, System.DateUtils, Data.DB,
  Uni, UniProvider, PostgreSQLUniProvider, SQLServerUniProvider, InterBaseUniProvider,
  rad.sqlfilter, rad.customfield, Help.uni;

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

procedure Firlatir(const AAd: string; AProc: TProc);
begin
  try
    AProc;
    Kontrol(AAd, False, 'istisna firlatilmadi');
  except
    on E: Exception do Kontrol(AAd, True);
  end;
end;

procedure Calistir(ACon: TUniConnection; const ASql: string);
begin
  ACon.ExecSQL(ASql);
end;

procedure SessizSil(ACon: TUniConnection; const ATable: string);
begin
  try
    Calistir(ACon, 'drop table ' + ATable);
  except
    // yoksa sorun degil
  end;
end;

function KolonVar(ACon: TUniConnection; const ATable, AColumn: string): Boolean;
var
  LQ: TUniQuery;
  D: TRadSqlDialect;
begin
  D := ACon._SqlDialect;
  LQ := ACon._CreateQuery(TRadCustomFieldDdl.ColumnExistsSql(D), False);
  try
    LQ.ParamByName('t').AsString := TRadCustomFieldDdl.CatalogName(D, ATable);
    LQ.ParamByName('c').AsString := TRadCustomFieldDdl.CatalogName(D, AColumn);
    LQ.Open;
    Result := LQ.Fields[0].AsInteger > 0;
  finally
    LQ.Free;
  end;
end;

function Say(ACon: TUniConnection; AF: IRadSqlFilter): Integer;
var
  LQ: TUniQuery;
begin
  LQ := ACon._CreateQuery('select count(*) from rad_test_cf ' + AF.GetWhere, False);
  try
    LQ._ApplyFilter(AF);
    LQ.Open;
    Result := LQ.Fields[0].AsInteger;
  finally
    LQ.Free;
  end;
end;

function YeniAlan(AGroup: TRadCustomFieldGroupDef; const ACaption: string; AType: TRadCustomFieldType;
  ALen: Integer = 50): TRadCustomFieldDef;
begin
  Result := TRadCustomFieldDef.Create;
  Result.GroupId := AGroup.Id;
  Result.TableName := 'rad_test_cf';
  Result.Caption := ACaption;
  Result.FieldType := AType;
  Result.Length := ALen;
end;

procedure Temizle(ACon: TUniConnection);
begin
  SessizSil(ACon, TRadCustomFieldDdl.LayoutTable);
  SessizSil(ACon, TRadCustomFieldDdl.FieldTable);
  SessizSil(ACon, TRadCustomFieldDdl.GroupTable);
  SessizSil(ACon, 'rad_test_cf');
end;

procedure Senaryolar(ACon: TUniConnection; const AAd: string);
var
  LStore: IRadCustomFieldStore;
  LGrp: TRadCustomFieldGroupDef;
  LGroups: TRadCustomFieldGroups;
  LTxt, LPara, LCoklu, LTarih, LBool, LUzun: TRadCustomFieldDef;
  LQ: TUniQuery;
  LNames: TArray<string>;
  LStr: string;
  LMem, LMem2: TMemoryStream;
  i: Integer;
  LDialect: TRadSqlDialect;
begin
  Writeln('--- ', AAd, ' ---');
  LDialect := ACon._SqlDialect;
  Temizle(ACon);
  if LDialect = sdMSSQL then LStr := 'nvarchar' else LStr := 'varchar';
  Calistir(ACon, Format('create table rad_test_cf (id integer not null primary key, ad %s(40))', [LStr]));
  Calistir(ACon, 'insert into rad_test_cf (id, ad) values (1, ''Bir'')');
  Calistir(ACon, 'insert into rad_test_cf (id, ad) values (2, ''Iki'')');

  LStore := ACon._CustomFields;
  Kontrol('L01 lehce', LStore.Dialect = LDialect);
  LStore.EnsureDefinitionTables;
  LStore.EnsureDefinitionTables;   // idempotent
  Kontrol('L02 tanim tablolari var', KolonVar(ACon, TRadCustomFieldDdl.FieldTable, 'kolon_adi'));

  LGroups := LStore.LoadGroups('rad_test_cf');
  try
    Kontrol('L03 bos tablo: grup yok', LGroups.Count = 0);
  finally
    LGroups.Free;
  end;

  LGrp := TRadCustomFieldGroupDef.Create;
  try
    LGrp.TableName := 'rad_test_cf';
    LGrp.Name := 'Genel';
    LGrp.Order := 1;
    LStore.AddGroup(LGrp);
    Kontrol('L04 grup id dolar', LGrp.Id > 0, IntToStr(LGrp.Id));
    Firlatir('L05 ayni adli grup DB reddeder', procedure
      var G: TRadCustomFieldGroupDef;
      begin
        G := TRadCustomFieldGroupDef.Create;
        try
          G.TableName := 'rad_test_cf'; G.Name := 'Genel';
          LStore.AddGroup(G);
        finally
          G.Free;
        end;
      end);

    LTxt := YeniAlan(LGrp, 'Metin', cfText, 30);
    LPara := YeniAlan(LGrp, 'Tutar', cfMoney);
    LCoklu := YeniAlan(LGrp, 'Secim', cfMultiChoice);
    LCoklu.SetOptionsText('a|A secenek'#13#10'b|B secenek'#13#10'ab|AB');
    LTarih := YeniAlan(LGrp, 'Tarih', cfDate);
    LBool := YeniAlan(LGrp, 'Aktif', cfBoolean);
    LUzun := YeniAlan(LGrp, StringOfChar('X', 150), cfText);   // baslik 100'u asar: insert patlar, DDL geri alinmali
    try
      LStore.AddField(LTxt);
      Kontrol('L06 ilk kolon ozel_1', LTxt.ColumnName = 'ozel_1', LTxt.ColumnName);
      Kontrol('L07 alan id dolar', LTxt.Id > 0);
      Kontrol('L08 kolon tabloda', KolonVar(ACon, 'rad_test_cf', 'ozel_1'));
      LStore.AddField(LPara);
      LStore.AddField(LCoklu);
      LStore.AddField(LTarih);
      LStore.AddField(LBool);
      Kontrol('L09 besinci kolon ozel_5', LBool.ColumnName = 'ozel_5', LBool.ColumnName);

      if LDialect = sdMySQL then
        Writeln('  [ATLANDI] L10 MySQL DDL geri alinamaz')
      else
      begin
        try
          LStore.AddField(LUzun);
          Kontrol('L10 insert patlayinca istisna', False, 'istisna yok');
        except
          on E: Exception do
          begin
            Kontrol('L10 insert patlayinca istisna', True);
            Olcum(AAd + ' L10 istisna', E.ClassName + ': ' + StringReplace(E.Message, #13#10, ' / ', [rfReplaceAll]));
          end;
        end;
        Olcum(AAd + ' L10 sonrasi InTransaction', BoolToStr(ACon.InTransaction, True));
        Kontrol('L11 DDL geri alindi: ozel_6 yok', not KolonVar(ACon, 'rad_test_cf', 'ozel_6'));
        if LDialect = sdFirebird then
          Olcum(AAd + ' L12', 'InTransaction Firebird''de her SELECT sonrasi True kalir (varsayilan transaction); olculmez')
        else
          Kontrol('L12 transaction kapandi', not ACon.InTransaction);
      end;

      LNames := LStore.ColumnNames('rad_test_cf');
      Kontrol('L13 kolon adlari 5', Length(LNames) = 5, IntToStr(Length(LNames)));
      Kontrol('L14 kolon sirasi', (Length(LNames) = 5) and (LNames[0] = 'ozel_1') and (LNames[4] = 'ozel_5'));
      Kontrol('L15 _CustomFieldColumns', ACon._CustomFieldColumns('rad_test_cf', 'c') =
        ', c.ozel_1, c.ozel_2, c.ozel_3, c.ozel_4, c.ozel_5', ACon._CustomFieldColumns('rad_test_cf', 'c'));
      Kontrol('L16 _CustomFieldColumns aliassiz', ACon._CustomFieldColumns('rad_test_cf') = ', ozel_1, ozel_2, ozel_3, ozel_4, ozel_5');

      // deger yaz / oku
      LQ := ACon._CreateQuery('update rad_test_cf set ozel_1 = :a, ozel_2 = :b, ozel_3 = :c, ozel_4 = :d, ozel_5 = :e where id = 1', False);
      try
        LQ.ParamByName('a').AsString := 'merhaba';
        LQ.ParamByName('b').AsFloat := 12.5;
        LQ.ParamByName('c').AsString := TRadMultiChoice.Join(['a', 'b']);
        LQ.ParamByName('d').AsDate := EncodeDate(2026, 1, 20);
        LQ.ParamByName('e').AsBoolean := True;
        LQ.ExecSQL;
        LQ.SQL.Text := 'select * from rad_test_cf where id = 1';
        LQ.Open;
        Kontrol('L17 metin okundu', LQ.FieldByName('ozel_1').AsString = 'merhaba');
        Kontrol('L18 para okundu', Abs(LQ.FieldByName('ozel_2').AsFloat - 12.5) < 1e-9);
        Kontrol('L19 coklu okundu |a|b|', LQ.FieldByName('ozel_3').AsString = '|a|b|', LQ.FieldByName('ozel_3').AsString);
        Kontrol('L20 tarih okundu', DateOf(LQ.FieldByName('ozel_4').AsDateTime) = EncodeDate(2026, 1, 20));
        Kontrol('L21 bool okundu', LQ.FieldByName('ozel_5').AsBoolean);
        Olcum(AAd + ' ozel_3 alan tipi', LQ.FieldByName('ozel_3').ClassName);
        Olcum(AAd + ' ozel_5 alan tipi', LQ.FieldByName('ozel_5').ClassName);
      finally
        LQ.Free;
      end;

      // filtre
      Kontrol('L22 coklu Contains b', Say(ACon, ACon._NewFilter.Contains('ozel_3', TRadMultiChoice.Wrap('b'))) = 1);
      Kontrol('L23 coklu Contains ab (kismi eslesmez)', Say(ACon, ACon._NewFilter.Contains('ozel_3', TRadMultiChoice.Wrap('ab'))) = 0);
      Kontrol('L24 coklu Contains a', Say(ACon, ACon._NewFilter.Contains('ozel_3', TRadMultiChoice.Wrap('a'))) = 1);
      Kontrol('L25 para filtre', Say(ACon, ACon._NewFilter.Greater('ozel_2', 10)) = 1);

      // makro
      LQ := ACon._CreateQuery('select c.id, c.ad &ozel from rad_test_cf c order by c.id', False);
      try
        LQ._ApplyCustomFieldMacro('ozel', 'rad_test_cf', 'c');
        LQ.Open;
        Kontrol('L26 makro ile 7 alan', LQ.FieldCount = 7, IntToStr(LQ.FieldCount));
        Kontrol('L27 makro FinalSQL', Pos('c.ozel_5', LQ.FinalSQL) > 0);
      finally
        LQ.Free;
      end;
      LQ := ACon._CreateQuery('select c.id &ozel from rad_test_cf c', False);
      try
        LQ._ApplyCustomFieldMacro('ozel', 'baska_tablo', 'c');   // tanim yok -> bos
        LQ.Open;
        Kontrol('L28 tanimsiz tabloda makro bos', LQ.FieldCount = 1);
      finally
        LQ.Free;
      end;

      // persistent TField
      LQ := ACon._CreateQuery('select * from rad_test_cf order by id', False);
      try
        LQ.FieldDefs.Update;
        LQ.FieldDefs[0].CreateField(LQ);
        LQ.FieldDefs[1].CreateField(LQ);
        Kontrol('L29 persistent 2 alan', LQ.FieldCount = 2);
        Kontrol('L30 ozel_1 henuz yok', LQ.FindField('ozel_1') = nil);
        LQ._EnsureCustomFields;
        Kontrol('L31 ozel_1..5 yaratildi', (LQ.FindField('ozel_1') <> nil) and (LQ.FindField('ozel_5') <> nil), IntToStr(LQ.FieldCount));
        LQ.Open;
        Kontrol('L32 acildi, deger geldi', LQ.FieldByName('ozel_1').AsString = 'merhaba');
        Firlatir('L33 acik dataset hata', procedure begin LQ._EnsureCustomFields; end);
      finally
        LQ.Free;
      end;
      LQ := ACon._CreateQuery('select * from rad_test_cf', False);
      try
        LQ._EnsureCustomFields;
        Kontrol('L34 dinamik alanlarda islemsiz', LQ.FieldCount = 0);
      finally
        LQ.Free;
      end;

      // guncelleme
      LTxt.Caption := 'Metin 2';
      LTxt.Active := False;
      LStore.UpdateField(LTxt);
      LGroups := LStore.LoadGroups('rad_test_cf');
      try
        Kontrol('L35 aktif alan 4', (LGroups.Count = 1) and (Length(LGroups[0].ActiveFields) = 4));
        Kontrol('L36 pasif de yuklenmez', LGroups[0].Fields.Count = 4);
      finally
        LGroups.Free;
      end;
      LGroups := LStore.LoadGroups('rad_test_cf', True);
      try
        Kontrol('L37 pasif dahil 5', LGroups[0].Fields.Count = 5);
        Kontrol('L38 baslik guncellendi', LGroups[0].Fields[0].Caption = 'Metin 2');
        Kontrol('L39 secenekler gidis-donus', LGroups[0].Fields[2].OptionsText = LCoklu.OptionsText, LGroups[0].Fields[2].OptionsText);
        Kontrol('L40 tip gidis-donus', LGroups[0].Fields[1].FieldType = cfMoney);
      finally
        LGroups.Free;
      end;
      Firlatir('L41 tip degisimi reddedilir', procedure
        var D: TRadCustomFieldDef;
        begin
          D := LPara.Clone;
          try
            D.FieldType := cfInteger;
            LStore.UpdateField(D);
          finally
            D.Free;
          end;
        end);
      Kontrol('L42 _CustomFieldColumns pasifi atlar', ACon._CustomFieldColumns('rad_test_cf') = ', ozel_2, ozel_3, ozel_4, ozel_5');

      // uzunluk
      LStore.ExtendLength(LTxt, 60);
      Kontrol('L43 uzunluk guncel', LTxt.Length = 60);
      Calistir(ACon, 'update rad_test_cf set ozel_1 = ''' + StringOfChar('y', 55) + ''' where id = 2');
      Kontrol('L44 55 karakter sigdi', ACon._sqlResults('select ozel_1 from rad_test_cf where id = 2', '') = StringOfChar('y', 55));
      Firlatir('L45 kucultme reddedilir', procedure begin LStore.ExtendLength(LTxt, 30); end);

      // duzen
      LMem := TMemoryStream.Create;
      LMem2 := TMemoryStream.Create;
      try
        for i := 0 to 999 do LMem.Write(i, SizeOf(i));
        LStore.SaveLayout('rad_test_cf', 7, LMem);
        LStore.SaveLayout('rad_test_cf', 7, LMem);   // ustune yazar
        Kontrol('L46 duzen yuklendi', LStore.LoadLayout('rad_test_cf', 7, LMem2));
        Kontrol('L47 duzen ayni', (LMem2.Size = LMem.Size) and CompareMem(LMem.Memory, LMem2.Memory, LMem.Size), IntToStr(LMem2.Size));
        LMem2.Clear;
        Kontrol('L48 baska kullanici yok', not LStore.LoadLayout('rad_test_cf', 8, LMem2));
        LStore.DeleteLayout('rad_test_cf', 7);
        Kontrol('L49 silindi', not LStore.LoadLayout('rad_test_cf', 7, LMem2));
      finally
        LMem.Free;
        LMem2.Free;
      end;
    finally
      LTxt.Free; LPara.Free; LCoklu.Free; LTarih.Free; LBool.Free; LUzun.Free;
    end;
  finally
    LGrp.Free;
  end;
  Temizle(ACon);
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
        try Temizle(ACon); except end;
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
