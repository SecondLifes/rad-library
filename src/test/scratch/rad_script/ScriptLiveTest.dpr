program ScriptLiveTest;

(*
  CANLI: rad.script + Help.uni (TRadUniScriptStore) uc sunucuda (EARS 1-8, 10; cron 9 model testinde).
  Baglanti bilgileri: %LOCALAPPDATA%\rad\test-db.env (CustomFieldLiveTest ile ayni).
  Yalniz script_* tablolari + rad_test_sc_log olusturulur, sonunda silinir.
  Firebird yalniz Win32 (64-bit fbclient.dll yok).
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.StrUtils, System.Classes, System.Variants, System.IOUtils, System.DateUtils, System.Diagnostics, Data.DB,
  Uni, UniProvider, PostgreSQLUniProvider, SQLServerUniProvider, InterBaseUniProvider,
  mormot.core.base, mormot.core.unicode,
  rad.sqlfilter, rad.script, Help.uni;

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
      Exit(System.SysUtils.Trim(LLine.Substring(Length(AKey) + 1)));
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

procedure SessizSil(ACon: TUniConnection; const ATable: string);
begin
  try
    ACon.ExecSQL('drop table ' + ATable);
  except
    // yoksa sorun degil
  end;
end;

procedure Temizle(ACon: TUniConnection);
begin
  SessizSil(ACon, 'script_kaynak');
  SessizSil(ACon, 'script_db');
  SessizSil(ACon, 'script_parametre');
  SessizSil(ACon, 'script');
  SessizSil(ACon, 'script_paket');
  SessizSil(ACon, 'rad_test_sc_log');
end;

function Sayi(ACon: TUniConnection; const ASql: string): Integer;
var
  Q: TUniQuery;
begin
  Q := TUniQuery.Create(nil);
  try
    Q.Connection := ACon;
    Q.SQL.Text := ASql;
    Q.Open;
    Result := Q.Fields[0].AsInteger;
  finally
    Q.Free;
  end;
end;

function OrnekPaket: TRadScriptPackage;
var
  B: TBytes;
  i: Integer;
begin
  Result := TRadScriptPackage.Create;
  Result.Code := 'test.kasa';
  Result.Name := 'Kasa kontrolleri ğüşİ';
  Result.Version := '1.0.0';
  Result.Author := 'test';
  Result.Order := 2;
  Result.AddScript('KasaKontrol', skForm, 'Tkasa_k',
    'function btnKaydet_Before(Sender: TObject): Boolean;'#13#10'begin'#13#10'  // şube ğüşİ'#13#10'  Result := True;'#13#10'end;');
  Result.AddScript('Pasif', skForm, 'Tkasa_k', 'procedure x; begin end;').Active := False;
  Result.AddScript('Gelen', skEvent, 'efatura.gelen', 'procedure Calistir(Olay: TRadEvent); begin end;');
  Result.AddParam('MailAdresi', 'a@b.com').Description := 'Uyarı';
  Result.AddParam('Esik', '10');
  Result.AddDbStep(1, 'create table rad_test_sc_log (id integer, kasa_id varchar(36))');
  Result.AddDbStep(2, 'create index ix_rad_test_sc_log on rad_test_sc_log (kasa_id)');
  SetLength(B, 2000);
  for i := 0 to High(B) do B[i] := Byte(i * 13);
  Result.AddResource('kur.dfm', B);
end;

procedure Senaryolar(ACon: TUniConnection; const AAd: string);
var
  LStore: IRadScriptStore;
  P, Q, R: TRadScriptPackage;
  L: TRadScriptPackages;
  S: TRadScripts;
  LSw: TStopwatch;
  LBayt: TBytesStream;
  LOk: Boolean;
  i: Integer;
  LKaynak: string;
begin
  Writeln('--- ', AAd);
  Temizle(ACon);
  LStore := ACon._Scripts;
  Kontrol(AAd + ' S00 Dialect', LStore.Dialect = ACon._SqlDialect);

  // EARS 1: idempotent DDL
  LSw := TStopwatch.StartNew;
  LStore.EnsureDefinitionTables;
  Olcum(AAd + ' 5 tablo DDL', IntToStr(LSw.ElapsedMilliseconds) + ' ms');
  LStore.EnsureDefinitionTables;
  Kontrol(AAd + ' S01 EnsureDefinitionTables idempotent', Sayi(ACon, 'select count(*) from script_paket') = 0);

  // EARS 2: yeni paket tek transaction
  P := OrnekPaket;
  try
    LSw := TStopwatch.StartNew;
    LStore.SavePackage(P);
    Olcum(AAd + ' SavePackage (3 script, 2 param, 2 db, 1 kaynak)', IntToStr(LSw.ElapsedMilliseconds) + ' ms');
    Kontrol(AAd + ' S02 Id dolar', (P.Id > 0) and (P.Scripts[0].Id > 0) and (P.Params[0].Id > 0) and (P.DbSteps[0].Id > 0) and (P.Resources[0].Id > 0));
    Kontrol(AAd + ' S03 satir sayilari', (Sayi(ACon, 'select count(*) from script') = 3) and (Sayi(ACon, 'select count(*) from script_parametre') = 2) and
      (Sayi(ACon, 'select count(*) from script_db') = 2) and (Sayi(ACon, 'select count(*) from script_kaynak') = 1));

    // basarisiz alt kayit -> paket de yok (kod uzunlugu DB'de 50 ile sinirli, modelde de; o yuzden hedef 200'u asiriyoruz)
    R := TRadScriptPackage.Create;
    try
      R.Code := 'test.bozuk';
      R.Name := 'x';
      R.AddScript('A', skEvent, StringOfChar('e', 300), 'begin end;');
      Firlatir(AAd + ' S04 alt kayit hatasi yukselir', procedure begin LStore.SavePackage(R); end);
      Kontrol(AAd + ' S04b paket satiri da yok (tek transaction)', Sayi(ACon, 'select count(*) from script_paket where kod = ''test.bozuk''') = 0);
    finally
      R.Free;
    end;

    // yukle ve karsilastir
    Q := LStore.LoadPackage('test.kasa');
    try
      Kontrol(AAd + ' S05 LoadPackage var', Q <> nil);
      if Q <> nil then
      begin
        LOk := (Q.Name = P.Name) and (Q.Scripts.Count = 3) and (Q.Params.Count = 2) and (Q.DbSteps.Count = 2) and (Q.Resources.Count = 1) and
          (Q.Scripts[0].Source = P.Scripts[0].Source) and (Q.Scripts[0].Kind = skForm) and (Q.Scripts[0].Target = 'Tkasa_k') and
          not Q.Scripts[1].Active and (Q.ParamValue('MailAdresi', '') = 'a@b.com') and not Q.DbSteps[0].Applied and
          (Length(Q.Resources[0].Content) = 2000) and (Q.Created > 0) and (Q.Modified > 0);
        for i := 0 to 1999 do LOk := LOk and (Q.Resources[0].Content[i] = Byte(i * 13));
        Kontrol(AAd + ' S06 yuklenen = kaydedilen (Turkce kaynak, 2000 bayt blob)', LOk,
          Format('yuklenen=[%s] (%d) kaydedilen=[%s] (%d) n=%d', [Q.Scripts[0].Source.Substring(50), Length(Q.Scripts[0].Source), P.Scripts[0].Source.Substring(50), Length(P.Scripts[0].Source), Length(Q.Resources[0].Content)]));
      end;
    finally
      Q.Free;
    end;
    Kontrol(AAd + ' S07 LoadPackage yok = nil', LStore.LoadPackage('yok.yok') = nil);

    // EARS 3: update - script sil, kalanlar Id korur
    i := P.Scripts[0].Id;
    P.Scripts.Delete(2);   // Gelen
    P.Scripts[0].Source := P.Scripts[0].Source + #13#10'// v2';
    P.Params.Delete(1);    // Esik
    P.AddParam('Yeni', 'y');
    P.Version := '1.1.0';
    LStore.SavePackage(P);
    Q := LStore.LoadPackage('test.kasa');
    try
      Kontrol(AAd + ' S08 silinen gitti, Id korundu, kaynak guncel', (Q.Scripts.Count = 2) and (Q.Scripts[0].Id = i) and
        Q.Scripts[0].Source.EndsWith('// v2') and (Q.Params.Count = 2) and (Q.ParamByName('Esik') = nil) and
        (Q.ParamByName('Yeni') <> nil) and (Q.Version = '1.1.0') and (Q.Id = P.Id));
    finally
      Q.Free;
    end;

    // EARS 4: ScriptsFor
    R := TRadScriptPackage.Create;
    try
      R.Code := 'test.ikinci';
      R.Name := 'ikinci';
      R.Order := 1;   // P'den once calismali
      R.AddScript('Once', skForm, 'TKASA_K', 'begin end;');
      R.AddScript('Olay2', skEvent, 'efatura.gelen', 'begin end;');
      LStore.SavePackage(R);
      S := LStore.ScriptsFor(skForm, 'tkasa_k');
      try
        Kontrol(AAd + ' S09 ScriptsFor: aktif, sirali, harf duyarsiz', (S.Count = 2) and (S[0].Code = 'Once') and (S[1].Code = 'KasaKontrol'),
          IntToStr(S.Count));
      finally
        S.Free;
      end;
      R.Active := False;
      LStore.SavePackage(R);
      S := LStore.ScriptsFor(skForm, 'Tkasa_k');
      try
        Kontrol(AAd + ' S10 pasif paketin scripti gelmez', (S.Count = 1) and (S[0].Code = 'KasaKontrol'));
      finally
        S.Free;
      end;
      S := LStore.ScriptsFor(skEvent, 'yok');
      try
        Kontrol(AAd + ' S11 eslesme yok = bos', S.Count = 0);
      finally
        S.Free;
      end;
      L := LStore.LoadPackages(False);
      try
        Kontrol(AAd + ' S12 LoadPackages aktif', (L.Count = 1) and (L[0].Code = 'test.kasa') and (L[0].Scripts.Count = 2));
      finally
        L.Free;
      end;
      L := LStore.LoadPackages(True);
      try
        Kontrol(AAd + ' S13 LoadPackages hepsi, sira', (L.Count = 2) and (L[0].Code = 'test.ikinci') and (L[1].Code = 'test.kasa'));
      finally
        L.Free;
      end;
    finally
      R.Free;
    end;

    // EARS 5: DB adimlari - 2. adim bozuk
    P.DbSteps[1].Sql := 'create index ix_bozuk on tablo_yok (x)';
    P.AddDbStep(3, 'insert into rad_test_sc_log (id) values (1)');
    LStore.SavePackage(P);
    Firlatir(AAd + ' S14 2. adim hata', procedure begin LStore.ApplyPendingDbSteps(P); end);
    Kontrol(AAd + ' S15 1 uygulandi, 2-3 bekliyor', P.DbSteps[0].Applied and not P.DbSteps[1].Applied and not P.DbSteps[2].Applied and
      (Sayi(ACon, 'select count(*) from rad_test_sc_log') = 0) and
      (Sayi(ACon, 'select count(*) from script_db where uygulandi_mi = ' + IfThen(LStore.Dialect in [sdPostgreSQL, sdFirebird], 'true', '1')) = 1));
    P.DbSteps[1].Sql := 'create index ix_rad_test_sc_log on rad_test_sc_log (kasa_id)';
    LStore.SavePackage(P);
    LStore.ApplyPendingDbSteps(P);
    Kontrol(AAd + ' S16 tekrar: 2 ve 3 uygulandi, 1 tekrar kosmadi', P.DbSteps[1].Applied and P.DbSteps[2].Applied and
      (Sayi(ACon, 'select count(*) from rad_test_sc_log') = 1));
    LStore.ApplyPendingDbSteps(P);
    Kontrol(AAd + ' S17 ucuncu cagri bos', Sayi(ACon, 'select count(*) from rad_test_sc_log') = 1);

    // EARS 6/8: export -> import (parametre degeri korunur)
    P.ParamByName('MailAdresi').Value := 'kurulum@firma.com';
    LStore.SavePackage(P);
    LKaynak := string(Utf8ToString(TRadScriptPackageFile.ExportPackage(OrnekPaket)));   // dosyada a@b.com, Esik var, Yeni yok
    Q := TRadScriptPackageFile.ImportPackage(StringToUtf8(LKaynak));
    try
      LStore.ImportPackage(Q);
      R := LStore.LoadPackage('test.kasa');
      try
        Kontrol(AAd + ' S18 ImportPackage: deger korundu, yeni param geldi, olmayan silindi',
          (R.ParamValue('MailAdresi', '') = 'kurulum@firma.com') and (R.ParamByName('Esik') <> nil) and (R.ParamByName('Yeni') = nil) and
          (R.Scripts.Count = 3) and (R.Version = '1.0.0'));
        Kontrol(AAd + ' S19 ImportPackage: uygulanmis db adimi uygulanmis kaldi', R.DbSteps[0].Applied and R.DbSteps[1].Applied and (R.DbSteps.Count = 2));
      finally
        R.Free;
      end;
    finally
      Q.Free;
    end;

    // kutuphane listesi (3. asama Attach bunu kullanir)
    P.AddScript('Yardimci', skLibrary, '', 'function Ek: string; begin Result := ''ek''; end;');
    P.AddScript('PasifLib', skLibrary, '', 'function Yok: string; begin Result := ''''; end;').Active := False;
    LStore.SavePackage(P);
    S := LStore.LibrariesOf([P.Id, 99999]);
    try
      Kontrol(AAd + ' S23 LibrariesOf: yalniz aktif kutuphane', (S.Count = 1) and (S[0].Code = 'Yardimci') and (S[0].PackageId = P.Id),
        IntToStr(S.Count));
    finally
      S.Free;
    end;
    S := LStore.LibrariesOf([]);
    try
      Kontrol(AAd + ' S23b LibrariesOf bos', S.Count = 0);
    finally
      S.Free;
    end;

    // kaynak akisi
    LBayt := TBytesStream.Create;
    try
      Kontrol(AAd + ' S20 LoadResource', LStore.LoadResource(P.Id, 'kur.dfm', LBayt) and (LBayt.Size = 2000) and
        not LStore.LoadResource(P.Id, 'yok.dfm', LBayt));
    finally
      LBayt.Free;
    end;

    // EARS 10: sil, cascade, kullanici tablosu kalir
    LStore.DeletePackage('test.kasa');
    LStore.DeletePackage('test.ikinci');
    Kontrol(AAd + ' S21 DeletePackage cascade', (Sayi(ACon, 'select count(*) from script_paket') = 0) and (Sayi(ACon, 'select count(*) from script') = 0) and
      (Sayi(ACon, 'select count(*) from script_parametre') = 0) and (Sayi(ACon, 'select count(*) from script_db') = 0) and
      (Sayi(ACon, 'select count(*) from script_kaynak') = 0));
    Kontrol(AAd + ' S22 kullanici tablosu duruyor', Sayi(ACon, 'select count(*) from rad_test_sc_log') = 1);
  finally
    P.Free;
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
