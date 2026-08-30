program LiveLookupTest;

(*
  CANLI VERITABANI testi - Rad.Dev'in sunucu tarafli lookup + kaskad
  iddialarinin gercek SQL ile olculmesi.

  Olculen dort sey:
    M1) OnSearch gercek parametreli sorguyu calistirip listeyi suzuyor mu?
    M2) Kaskad: ulke secilince sehir listesi gercekten filtreleniyor mu?
    M3) OnLocate: listede OLMAYAN bir anahtarin metni cozulebiliyor mu?
        (sunucu tarafli lookup'in varlik sebebi tam olarak bu)
    M4) Onbellek: grid ayni anahtari N kez boyarken OnLocate 1 kez mi
        tetikleniyor, N kez mi? - performans iddiasinin olcumu

  ! KIMLIK BILGISI KAYNAK KODA YAZILMAZ - depo GitHub'a yayinlaniyor.
    %LOCALAPPDATA%\rad\test-db.env ya da RAD_PG_* ortam degiskenleri.

  ! SADECE rad_test_* tablolari olusturulur ve testin sonunda silinir.
    Kullanicinin mevcut tablolarina DOKUNULMAZ.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, System.IOUtils,
  Winapi.Windows, Vcl.Forms, Vcl.Controls, Data.DB,
  Uni, UniProvider, PostgreSQLUniProvider,
  cxEdit, cxTextEdit, cxMaskEdit, cxDropDownEdit, cxLookupEdit, cxDBLookupEdit,
  cxDBLookupComboBox, cxGridCustomTableView, cxGridTableView, cxGridLevel,
  cxGrid, cxGridCustomView, cxGridDBTableView, cxDBData, cxCustomData,
  cxGraphics, cxControls, cxLookAndFeels, cxContainer, cxClasses,
  Rad.Dev, Help.Dev;

type
  { GetDisplayLookupText protected; testten erisim icin erisim sinifi. }
  TPropsAccess = class(TRadLookupComboBoxProperties);

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
  GBasari: Integer = 0;
  GHata: Integer = 0;
  GAtlanan: Integer = 0;

(* RADDEV-008: bu sonda eskiden yalnizca YAZDIRIYORDU. Beklenen degerler
   parantez icinde metin olarak duruyordu ve yanlis bir sonuc hicbir seyi
   bozmuyordu - nitekim M1 UZUN SUREDIR OLU bir olcumdu (asagiya bakin). *)
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
    Writeln('  [HATA] ', AAd);
  end;
  if ADetay <> '' then
    Writeln('         ', ADetay);
end;

procedure Atla(const AAd, ASebep: string);
begin
  Inc(GAtlanan);
  Writeln('  [ATLA] ', AAd);
  Writeln('         ', ASebep);
end;

procedure Sonuc;
begin
  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata, %d atlanan ===',
    [GBasari, GHata, GAtlanan]));
  if GHata > 0 then
    Halt(1);
end;

type
  TSenaryo = class
  public
    Con: TUniConnection;
    QUlke, QSehir: TUniQuery;
    QSehir2: TUniQuery;              { M6-M9: iki parametreli + limit }
    Sehir2Sql: string;               { son kosan sorgunun parametreleri }
    Sehir2Sayaci: Integer;
    SehirLookup: TUniQuery;          { M3: tek anahtar cozumleyen sorgu }
    SqlSayaci: Integer;              { calisan sorgu sayisi }
    LocateSayaci: Integer;
    SonSehirSql: string;
    OrtakKayit: TStringList;         { M5: her cagrida kaynak + tur }
    procedure UlkeArama(Sender: TRadLookupComboBoxProperties;
      ASource: TComponent; var AText, ATail: string; ANext: Boolean);
    { M5: TEK isleyici, PAYLASILAN item, tuketici-basina tur }
    procedure OrtakTanimArama(Sender: TRadLookupComboBoxProperties;
      ASource: TComponent; var AText, ATail: string; ANext: Boolean);
    procedure UlkeKaskad(Sender: TRadLookupComboBoxProperties;
      ASource, ATarget: TComponent; const AValue: Variant);
    procedure SehirLocate(Sender: TRadLookupComboBoxProperties;
      ASource: TComponent; const AKey: Variant);
    { M6-M9: gercek ERP sekli - master parametresi + arama + limit }
    procedure Sehir2Arama(Sender: TRadLookupComboBoxProperties;
      ASource: TComponent; var AText, ATail: string; ANext: Boolean);
  end;

procedure TSenaryo.Sehir2Arama(Sender: TRadLookupComboBoxProperties;
  ASource: TComponent; var AText, ATail: string; ANext: Boolean);
begin
  Inc(Sehir2Sayaci);
  (* NOTR ARAMA DEGERI UYGULAMANIN ISI. Parametre hic atanmazsa Null kalir
     ve 'ad ilike NULL' SIFIR satir doner - bilesen bunu bilemez, cunku
     notr degerin ne oldugu SQL'e baglidir ('%' burada, baska yerde ''). *)
  QSehir2.Close;
  if AText = '' then
    QSehir2.ParamByName('arama').AsString := '%'
  else
    QSehir2.ParamByName('arama').AsString := '%' + AText + '%';
  QSehir2.Open;
  Sehir2Sql := Format('ulke_id=%s arama=%s',
    [VarToStr(QSehir2.ParamByName('ulke_id').Value),
     QSehir2.ParamByName('arama').AsString]);
end;

procedure TSenaryo.OrtakTanimArama(Sender: TRadLookupComboBoxProperties;
  ASource: TComponent; var AText, ATail: string; ANext: Boolean);
var
  LOwn: TcxCustomEditProperties;
  LTur, LAd: string;
begin
  (* Kullanicinin deseni: PAYLASILAN item tek isleyiciyi tasir, her tuketici
     kendi Properties'inde turunu soyler. Sender PAYLASILAN ornek oldugu icin
     tur ondan OKUNAMAZ - ASource'un KENDI Properties'inden okunur. *)
  if ASource = nil then
  begin
    OrtakKayit.Add('ASource=nil (kaynak yok)');
    Exit;
  end;
  LAd := ASource.Name;
  LOwn := _OwnProperties(ASource);
  if LOwn is TRadLookupComboBoxProperties then
    LTur := TRadLookupComboBoxProperties(LOwn).ACascadeField
  else
    LTur := '<kendi Properties yok>';
  OrtakKayit.Add(Format('kaynak=%s tur=%s paylasilan(Sender).ACascadeField=%s',
    [LAd, LTur, Sender.ACascadeField]));
end;

procedure TSenaryo.UlkeArama(Sender: TRadLookupComboBoxProperties;
  ASource: TComponent; var AText, ATail: string; ANext: Boolean);
begin
  Inc(SqlSayaci);
  QUlke.Close;
  QUlke.ParamByName('arama').AsString := '%' + AText + '%';
  QUlke.Open;
end;

procedure TSenaryo.UlkeKaskad(Sender: TRadLookupComboBoxProperties;
  ASource, ATarget: TComponent; const AValue: Variant);
begin
  Inc(SqlSayaci);
  QSehir.Close;
  if VarIsNull(AValue) or (VarToStr(AValue) = '') then
    QSehir.ParamByName('ulke_id').Clear
  else
    QSehir.ParamByName('ulke_id').AsInteger := AValue;
  QSehir.Open;
  SonSehirSql := 'ulke_id=' + VarToStr(AValue);
end;

procedure TSenaryo.SehirLocate(Sender: TRadLookupComboBoxProperties;
  ASource: TComponent; const AKey: Variant);
begin
  { M3: listede olmayan bir anahtarin satirini SUNUCUDAN cek ve listeye koy. }
  Inc(LocateSayaci);
  Inc(SqlSayaci);
  QSehir.Close;
  QSehir.SQL.Text :=
    'select id, ad, ulke_id from rad_test_sehir where id = :tek_id';
  QSehir.ParamByName('tek_id').AsInteger := AKey;
  QSehir.Open;
end;

procedure Bekle(AMs: Cardinal);
var LBitis: UInt64;
begin
  LBitis := GetTickCount64 + AMs;
  while GetTickCount64 < LBitis do
  begin
    Application.ProcessMessages;
    Sleep(5);
  end;
end;

procedure Calistir(ACon: TUniConnection; const ASql: string);
var LQ: TUniQuery;
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

var
  LCfg: TCfg;
  LS: TSenaryo;
  LForm: TForm;
  LDsUlke, LDsSehir, LDsSehir2: TDataSource;
  LSehir2: TRadLookupComboBox;
  LHataM5b: string;
  LSehir: TRadDBLookupComboBox;   { LUlke kaldirildi - hic kullanilmiyordu (H2164) }
  LEdUlke: TRadLookupComboBox;
  LText, LTail: string;
  i, LOnce: Integer;
  LMetin: string;
  LDeger: Variant;

begin
  LS := TSenaryo.Create;
  try
    try
      LCfg := Oku;
      LS.Con := TUniConnection.Create(nil);
      LS.Con.ProviderName := 'PostgreSQL';
      LS.Con.Server := LCfg.Host;
      LS.Con.Port := StrToIntDef(LCfg.Port, 5432);
      LS.Con.Database := LCfg.Db;
      LS.Con.Username := LCfg.User;
      LS.Con.Password := LCfg.Pass;
      LS.Con.LoginPrompt := False;
      LS.Con.Connect;
      Writeln('Baglandi: ', LCfg.Host, '/', LCfg.Db);

      { ── Test verisi (yalnizca rad_test_*) ───────────────────────────── }
      Calistir(LS.Con, 'drop table if exists rad_test_sehir');
      Calistir(LS.Con, 'drop table if exists rad_test_ulke');
      Calistir(LS.Con,
        'create table rad_test_ulke (id integer primary key, ad varchar(60))');
      Calistir(LS.Con,
        'create table rad_test_sehir (id integer primary key, ad varchar(60), ' +
        'ulke_id integer)');
      Calistir(LS.Con,
        'insert into rad_test_ulke values ' +
        '(1,''Turkiye''),(2,''Almanya''),(3,''Fransa''),(4,''Tunus'')');
      Calistir(LS.Con,
        'insert into rad_test_sehir values ' +
        '(10,''Istanbul'',1),(11,''Ankara'',1),(12,''Izmir'',1),(13,''Bursa'',1),' +
        '(20,''Berlin'',2),(21,''Munih'',2),' +
        '(30,''Paris'',3),(31,''Lyon'',3),' +
        '(40,''Tunus sehri'',4)');
      Writeln('rad_test_ulke (4) ve rad_test_sehir (9) olusturuldu.');
      Writeln;

      Application.Initialize;
      LForm := TForm.CreateNew(nil);
      LForm.Width := 700; LForm.Height := 460;
      LForm.Position := poScreenCenter;
      LForm.Show;
      Bekle(150);

      LS.QUlke := TUniQuery.Create(LForm);
      LS.QUlke.Connection := LS.Con;
      LS.QUlke.SQL.Text :=
        'select id, ad from rad_test_ulke where ad ilike :arama order by ad';
      LS.QUlke.ParamByName('arama').AsString := '%';
      LS.QUlke.Open;

      LS.QSehir := TUniQuery.Create(LForm);
      LS.QSehir.Connection := LS.Con;
      LS.QSehir.SQL.Text :=
        'select id, ad, ulke_id from rad_test_sehir where ulke_id = :ulke_id ' +
        'order by ad';
      LS.QSehir.ParamByName('ulke_id').Clear;

      LDsUlke := TDataSource.Create(LForm);  LDsUlke.DataSet := LS.QUlke;
      LDsSehir := TDataSource.Create(LForm); LDsSehir.DataSet := LS.QSehir;

      LSehir := TRadDBLookupComboBox.Create(LForm);
      LSehir.Name := 'Sehir'; LSehir.Parent := LForm;
      LSehir.Left := 20; LSehir.Top := 70; LSehir.Width := 260;
      LSehir.Properties.ListSource := LDsSehir;
      LSehir.Properties.KeyFieldNames := 'id';
      LSehir.Properties.ListFieldNames := 'ad';

      LEdUlke := TRadLookupComboBox.Create(LForm);
      LEdUlke.Name := 'Ulke'; LEdUlke.Parent := LForm;
      LEdUlke.Left := 20; LEdUlke.Top := 20; LEdUlke.Width := 260;
      LEdUlke.Properties.ListSource := LDsUlke;
      LEdUlke.Properties.KeyFieldNames := 'id';
      LEdUlke.Properties.ListFieldNames := 'ad';
      LEdUlke.Properties.AOnSearch := LS.UlkeArama;
      (* OLU OLCUM ONARIMI. M1 iki harfli "Tu" ile ariyordu ama varsayilan
         AMinSearchLength 3'tur, yani DoSearch uzunluk kapisindan cikiyor ve
         SORGU HIC KOSMUYORDU. Sonda bunu yalnizca yazdirdigi icin kimse fark
         etmedi (olculdu: "calisan sorgu : 0", liste 4 satirda kaldi).

         0 yapmak ayni zamanda DOGRU yapilandirma: birimin kendi notu ulke
         kodlari icin (TR, DE - iki harf) bunu acikca soyluyor. *)
      LEdUlke.Properties.AMinSearchLength := 0;
      LEdUlke.Properties.AComponent1 := LSehir;
      LEdUlke.Properties.AOnCascade := LS.UlkeKaskad;

      { ══ M1) OnSearch gercek SQL ile suzuyor mu? ═════════════════════ }
      Writeln('=== M1) OnSearch -> gercek parametreli sorgu ===');
      Writeln('  baslangicta ulke listesi : ', LS.QUlke.RecordCount, ' satir (4 bekleniyor)');
      LS.SqlSayaci := 0;
      LText := 'Tu'; LTail := '';
      LEdUlke.Properties.TimedSearch(LEdUlke, LText);
      Writeln('  "Tu" arandi -> calisan sorgu : ', LS.SqlSayaci);
      Kontrol('iki harfli arama GERCEKTEN sorgu kosturuyor',
        LS.SqlSayaci = 1,
        Format('sorgu = %d. Sifirsa AMinSearchLength kapisi kesmis demektir - ' +
               'kisa kodlu listelerde 0 verilmeli.', [LS.SqlSayaci]));
      Writeln('  liste simdi : ', LS.QUlke.RecordCount, ' satir (Turkiye + Tunus = 2 bekleniyor)');
      Kontrol('arama listeyi gercekten suzdu (2 satir)',
        LS.QUlke.RecordCount = 2,
        Format('RecordCount = %d', [LS.QUlke.RecordCount]));
      LS.QUlke.First;
      while not LS.QUlke.Eof do
      begin
        Writeln('    - ', LS.QUlke.FieldByName('ad').AsString);
        LS.QUlke.Next;
      end;

      { ══ M2) Kaskad gercekten filtreliyor mu? ════════════════════════ }
      Writeln;
      Writeln('=== M2) Kaskad -> sehir listesi filtreleniyor mu? ===');
      Writeln('  once sehir listesi : ', LS.QSehir.RecordCount, ' satir (0 bekleniyor, parametre bos)');
      LEdUlke.EditValue := 1;      { Turkiye }
      Bekle(150);
      Writeln('  Ulke=1 (Turkiye) -> ', LS.SonSehirSql,
        '  sehir listesi : ', LS.QSehir.RecordCount, ' satir (4 bekleniyor)');
      Kontrol('kaskad Turkiye icin 4 sehir getirdi', LS.QSehir.RecordCount = 4,
        Format('RecordCount = %d', [LS.QSehir.RecordCount]));
      LEdUlke.EditValue := 2;      { Almanya }
      Bekle(150);
      Writeln('  Ulke=2 (Almanya) -> ', LS.SonSehirSql,
        '  sehir listesi : ', LS.QSehir.RecordCount, ' satir (2 bekleniyor)');
      Kontrol('kaskad Almanya icin 2 sehir getirdi', LS.QSehir.RecordCount = 2,
        Format('RecordCount = %d', [LS.QSehir.RecordCount]));

      { ══ M3) OnLocate: listede OLMAYAN anahtari cozme ════════════════ }
      Writeln;
      Writeln('=== M3) OnLocate -> listede olmayan anahtarin metni ===');
      LSehir.Properties.AOnLocate := LS.SehirLocate;
      LSehir.Properties.ResetLocateCache;
      Writeln('  liste su an Almanya sehirleri (', LS.QSehir.RecordCount, ' satir)');
      LS.LocateSayaci := 0;
      LMetin := TPropsAccess(LSehir.Properties).GetDisplayLookupText(30); { Paris - listede YOK }
      Writeln('  anahtar 30 icin metin : "', LMetin, '"  (Paris bekleniyor)');
      Writeln('  OnLocate tetiklenme   : ', LS.LocateSayaci, ' (1 bekleniyor)');
      Kontrol('AOnLocate suzulmus listede OLMAYAN anahtari cozuyor',
        LS.LocateSayaci = 1, Format('LocateSayaci = %d', [LS.LocateSayaci]));

      { ══ M4) Onbellek: ayni anahtar N kez ════════════════════════════ }
      Writeln;
      Writeln('=== M4) Onbellek -> ayni anahtar 50 kez cozulurse? ===');
      { Cizim yolunun GERCEK giris noktasi PrepareDisplayValue - public,
        ve eklenen onbellek tam orada kisa devre yapiyor. }
      LSehir.Properties.ResetLocateCache;
      TPropsAccess(LSehir.Properties).GetDisplayLookupText(31);  { onbellegi doldur }
      LS.LocateSayaci := 0;
      for i := 1 to 50 do
      begin
        LDeger := 31;
        LSehir.Properties.PrepareDisplayValue(31, LDeger, False);
      end;
      Writeln('  50 cozumleme -> OnLocate ', LS.LocateSayaci,
        ' kez  (onbellek calisiyorsa 0 - zaten cozulmus)');
      Writeln('  gosterilen metin      : "', VarToStr(LDeger), '"');
      LOnce := LS.LocateSayaci;

      LS.LocateSayaci := 0;
      for i := 1 to 50 do
      begin
        LSehir.Properties.ResetLocateCache;    { onbellegi her seferinde bosalt }
        TPropsAccess(LSehir.Properties).GetDisplayLookupText(31);
      end;
      Writeln('  onbellek kapaliyken   -> OnLocate ', LS.LocateSayaci,
        ' kez  (50 bekleniyor)');
      Writeln(Format('  KAZANC: %d yerine %d sorgu', [LS.LocateSayaci, LOnce]));

      { ══ M5) Paylasilan item + tuketici-basina tur ═══════════════════ }
      Writeln;
      Writeln('=== M5) TEK item, TEK isleyici, tuketici-basina tur ===');
      LS.OrtakKayit := TStringList.Create;
      try
        var LRepo := TcxEditRepository.Create(LForm);
        var LItem := TRadLookupComboBoxRepository.Create(LForm);
        LItem.Repository := LRepo;
        LItem.Name := 'riTanim';
        LItem.Properties.ACascadeField := 'ORTAK';        { paylasilan yuk }
        LItem.Properties.AOnSearch := LS.OrtakTanimArama; { TEK isleyici }
        (* OLU OLCUM ONARIMI (M1 ile ayni sinif hata). Asagida tek harfle
           ('a' / 'b') arama tetikleniyor ama varsayilan AMinSearchLength 3;
           DoSearch uzunluk kapisindan cikiyor ve isleyici HIC kosmuyordu.
           Sonda yalnizca yazdirdigi icin bu yillarca fark edilmedi: kayit
           listesi bos kaliyor, "beklenen ..." satiri yine de basiliyordu.
           M5 in olctugu sey uzunluk kapisi degil, tuketici-basina yuk. *)
        LItem.Properties.AMinSearchLength := 0;

        var LMarka := TRadLookupComboBox.Create(LForm);
        LMarka.Name := 'cbMarka'; LMarka.Parent := LForm;
        LMarka.Properties.ACascadeField := 'marka';       { yere ozel yuk }
        LMarka.RepositoryItem := LItem;

        var LTip := TRadLookupComboBox.Create(LForm);
        LTip.Name := 'cbMusteriTipi'; LTip.Parent := LForm;
        LTip.Properties.ACascadeField := 'musteri_tipi';
        LTip.RepositoryItem := LItem;

        Writeln('  iki combo, tek item. Her birinden arama tetikleniyor:');
        LMarka.ActiveProperties.TimedSearch(LMarka, 'a');
        LTip.ActiveProperties.TimedSearch(LTip, 'b');
        for i := 0 to LS.OrtakKayit.Count - 1 do
          Writeln('    ', LS.OrtakKayit[i]);
        Writeln('  beklenen: kaynak dogru editor, tur ''marka'' / ''musteri_tipi'',');
        Writeln('            paylasilan Sender ise ikisinde de ''ORTAK''');
        Kontrol('iki tuketici de kendi turuyle kaydedildi',
          (LS.OrtakKayit.Count = 2) and
          (Pos('tur=marka', LS.OrtakKayit[0]) > 0) and
          (Pos('tur=musteri_tipi', LS.OrtakKayit[1]) > 0),
          'kayit sayisi: ' + IntToStr(LS.OrtakKayit.Count));
        Kontrol('paylasilan Sender ikisinde de ORTAK yukunu tasiyor',
          (LS.OrtakKayit.Count = 2) and
          (Pos('paylasilan(Sender).ACascadeField=ORTAK', LS.OrtakKayit[0]) > 0) and
          (Pos('paylasilan(Sender).ACascadeField=ORTAK', LS.OrtakKayit[1]) > 0));
      finally
        LS.OrtakKayit.Free;
      end;


      { == M5b) SQL.Text ATAYAN ISLEYICI master parametresini yok eder ==== }
      Writeln;
      Writeln('=== M5b) SQL.Text degistiren isleyicinin bedeli ===');
      (* M3'teki SehirLocate, QSehir'in SQL.Text'ini BASTAN ATIYOR
         ('where id = :tek_id'). Parametre DEGERLERI Close/Open boyunca
         korunur, ama SQL METNI degisince koleksiyon yeniden kurulur ve yeni
         metinde bulunmayan parametre GIDER. Dolayisiyla hala bagli olan
         UlkeKaskad, QSehir'de artik var olmayan 'ulke_id'yi arar.

         Bu bir bilesen hatasi DEGIL - isleyicinin sozlesmeyi bozmasi. Birim
         basligi bunu yaziyor; burada CANLI olarak olculuyor. *)
      LHataM5b := '';
      try
        LEdUlke.EditValue := 1;
      except
        on E: Exception do
          LHataM5b := E.Message;
      end;
      Kontrol('SQL.Text degistiren isleyici master parametresini YOK ETTI',
        Pos('not found', LHataM5b) > 0,
        'atilan: "' + LHataM5b + '"  <- isleyiciler parametre atamali, ' +
        'SQL degistirmemelidir');

      { Eski senaryonun kaskadini sokuyoruz; M6-M9 temiz bir kurulum ister. }
      LEdUlke.Properties.AOnCascade := nil;
      LEdUlke.Properties.AComponent1 := nil;
      LEdUlke.Properties.AOnLocate := nil;

      { == M6-M9) GERCEK ERP SEKLI: master + arama + limit, TEK sorgu ===== }
      Writeln;
      Writeln('=== M6-M9) afServerParam + AOnSearch, iki parametreli sinirli sorgu ===');

      { 40 sehirli bir ulke: satir sinirinin gercekten uygulandigini gormek icin }
      Calistir(LS.Con, 'insert into rad_test_ulke values (5,''CokSehirli'')');
      for i := 1 to 40 do
        Calistir(LS.Con, Format(
          'insert into rad_test_sehir values (%d,''Kent%.2d'',5)', [500 + i, i]));

      LS.QSehir2 := TUniQuery.Create(LForm);
      LS.QSehir2.Connection := LS.Con;
      (* Kullanicinin tarif ettigi sekil: iki parametre + SATIR SINIRI.
         Sinir SQL'de, bilesende degil. *)
      LS.QSehir2.SQL.Text :=
        'select id, ad from rad_test_sehir ' +
        'where ulke_id = :ulke_id and ad ilike :arama order by ad limit 15';
      LS.QSehir2.ParamByName('ulke_id').Clear;
      LS.QSehir2.ParamByName('arama').AsString := '%';

      LDsSehir2 := TDataSource.Create(LForm);
      LDsSehir2.DataSet := LS.QSehir2;

      LSehir2 := TRadLookupComboBox.Create(LForm);
      LSehir2.Name := 'Sehir2'; LSehir2.Parent := LForm;
      LSehir2.Left := 20; LSehir2.Top := 130; LSehir2.Width := 260;
      LSehir2.Properties.ListSource := LDsSehir2;
      LSehir2.Properties.KeyFieldNames := 'id';
      LSehir2.Properties.ListFieldNames := 'ad';
      LSehir2.Properties.AMaster := LEdUlke;
      LSehir2.Properties.AMasterField := 'ulke_id';
      LSehir2.Properties.AAutoFilter := afServerParam;
      LSehir2.Properties.AOnSearch := LS.Sehir2Arama;
      LSehir2.Properties.AMinSearchLength := 0;
      { AOnFilter YOK - otomatik kip yeterli. }

      { ── M6) Bir acilista TEK sorgu, dogru parametrelerle ────────────── }
      Writeln;
      Writeln('  M6) acilista tek sorgu mu?');
      LEdUlke.EditValue := 1;                 { Turkiye }
      LS.Sehir2Sayaci := 0;
      LSehir2.FilterNow;
      Writeln('    kosan sorgu : ', LS.Sehir2Sayaci, '   (', LS.Sehir2Sql, ')');
      Writeln('    satir       : ', LS.QSehir2.RecordCount);
      Kontrol('acilis basina TEK sorgu kosuyor', LS.Sehir2Sayaci = 1,
        Format('kosan = %d (iki ise master filtresi ve arama ayri ayri ' +
               'aciyor demektir)', [LS.Sehir2Sayaci]));
      Kontrol('master parametresi dogru kuruldu',
        Pos('ulke_id=1', LS.Sehir2Sql) > 0, LS.Sehir2Sql);
      Kontrol('arama parametresi NOTR degerle acildi',
        Pos('arama=%', LS.Sehir2Sql) > 0, LS.Sehir2Sql);
      Kontrol('Turkiye icin 4 sehir geldi', LS.QSehir2.RecordCount = 4,
        Format('RecordCount = %d', [LS.QSehir2.RecordCount]));

      { ── M7) Arama, master parametresini KORUYOR mu? ─────────────────── }
      Writeln;
      Writeln('  M7) uc harf yazilinca master parametresi korunuyor mu?');
      LS.Sehir2Sayaci := 0;
      LSehir2.Properties.TimedSearch(LSehir2, 'ank');
      Writeln('    kosan sorgu : ', LS.Sehir2Sayaci, '   (', LS.Sehir2Sql, ')');
      Writeln('    satir       : ', LS.QSehir2.RecordCount);
      Kontrol('arama ikinci bir sorgu kosturdu', LS.Sehir2Sayaci = 1,
        Format('kosan = %d', [LS.Sehir2Sayaci]));
      Kontrol('master parametresi Close/Open sonrasi HALA dogru',
        Pos('ulke_id=1', LS.Sehir2Sql) > 0,
        LS.Sehir2Sql + '  <- kaybolsaydi butun ulkelerin sehirleri gelirdi');
      Kontrol('arama gercekten suzdu (Ankara)', LS.QSehir2.RecordCount = 1,
        Format('RecordCount = %d', [LS.QSehir2.RecordCount]));

      { ── M8) Master degisince ESKI ARAMA METNI etkisiz mi? ───────────── }
      Writeln;
      Writeln('  M8) master degisince eski arama metni ne oluyor?');
      LEdUlke.EditValue := 2;                 { Almanya - "ank" yok }
      LS.Sehir2Sayaci := 0;
      LSehir2.FilterNow;
      Writeln('    kosan sorgu : ', LS.Sehir2Sayaci, '   (', LS.Sehir2Sql, ')');
      Writeln('    satir       : ', LS.QSehir2.RecordCount);
      Kontrol('yeni master ile arama metni SIFIRLANDI',
        Pos('arama=%', LS.Sehir2Sql) > 0,
        LS.Sehir2Sql + '  <- eski metin kalsaydi Almanya listesi BOS gelirdi');
      Kontrol('Almanya icin 2 sehir geldi', LS.QSehir2.RecordCount = 2,
        Format('RecordCount = %d (eski "ank" etkili olsaydi 0 olurdu)',
          [LS.QSehir2.RecordCount]));

      { ── M9) SQL'deki satir siniri gercekten uygulaniyor mu? ─────────── }
      Writeln;
      Writeln('  M9) 40 sehirli ulkede limit 15 tutuyor mu?');
      LEdUlke.EditValue := 5;                 { CokSehirli - 40 sehir }
      LS.Sehir2Sayaci := 0;
      LSehir2.FilterNow;
      Writeln('    kosan sorgu : ', LS.Sehir2Sayaci, '   (', LS.Sehir2Sql, ')');
      Writeln('    satir       : ', LS.QSehir2.RecordCount, '  (40 degil 15 bekleniyor)');
      Kontrol('satir siniri uygulandi: 40 sehirden 15 satir',
        LS.QSehir2.RecordCount = 15,
        Format('RecordCount = %d. Sinir SQL''dedir; bilesen sinir uretmez.',
          [LS.QSehir2.RecordCount]));

      LForm.Free;
      Sonuc;
    except
      on E: Exception do
      begin
        Writeln('HATA: ', E.ClassName, ': ', E.Message);
        Halt(2);
      end;
    end;
  finally
    { ── Temizlik: yalnizca kendi tablolarimiz ─────────────────────────── }
    try
      if (LS.Con <> nil) and LS.Con.Connected then
      begin
        Calistir(LS.Con, 'drop table if exists rad_test_sehir');
        Calistir(LS.Con, 'drop table if exists rad_test_ulke');
        Writeln;
        Writeln('Temizlik: rad_test_* tablolari silindi.');
        LS.Con.Disconnect;
      end;
    except
      on E: Exception do
        Writeln('TEMIZLIK HATASI: ', E.Message);
    end;
    LS.Con.Free;
    LS.Free;
  end;
end.
