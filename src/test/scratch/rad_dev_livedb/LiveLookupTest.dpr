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
  Rad.Dev;

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

type
  TSenaryo = class
  public
    Con: TUniConnection;
    QUlke, QSehir: TUniQuery;
    SehirLookup: TUniQuery;          { M3: tek anahtar cozumleyen sorgu }
    SqlSayaci: Integer;              { calisan sorgu sayisi }
    LocateSayaci: Integer;
    SonSehirSql: string;
    procedure UlkeArama(Sender: TRadLookupComboBoxProperties;
      var AText, ATail: string; ANext: Boolean);
    procedure UlkeKaskad(Sender: TRadLookupComboBoxProperties;
      ASource, ATarget: TComponent; const AValue: Variant);
    procedure SehirLocate(Sender: TRadLookupComboBoxProperties;
      const AKey: Variant);
  end;

procedure TSenaryo.UlkeArama(Sender: TRadLookupComboBoxProperties;
  var AText, ATail: string; ANext: Boolean);
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
  const AKey: Variant);
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
  LDsUlke, LDsSehir: TDataSource;
  LUlke, LSehir: TRadDBLookupComboBox;
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
      LEdUlke.Properties.OnSearch := LS.UlkeArama;
      LEdUlke.Properties.AComponent1 := LSehir;
      LEdUlke.Properties.OnCascade := LS.UlkeKaskad;

      { ══ M1) OnSearch gercek SQL ile suzuyor mu? ═════════════════════ }
      Writeln('=== M1) OnSearch -> gercek parametreli sorgu ===');
      Writeln('  baslangicta ulke listesi : ', LS.QUlke.RecordCount, ' satir (4 bekleniyor)');
      LS.SqlSayaci := 0;
      LText := 'Tu'; LTail := '';
      LEdUlke.Properties.TimedSearch(LText);
      Writeln('  "Tu" arandi -> calisan sorgu : ', LS.SqlSayaci);
      Writeln('  liste simdi : ', LS.QUlke.RecordCount, ' satir (Turkiye + Tunus = 2 bekleniyor)');
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
      LEdUlke.EditValue := 2;      { Almanya }
      Bekle(150);
      Writeln('  Ulke=2 (Almanya) -> ', LS.SonSehirSql,
        '  sehir listesi : ', LS.QSehir.RecordCount, ' satir (2 bekleniyor)');

      { ══ M3) OnLocate: listede OLMAYAN anahtari cozme ════════════════ }
      Writeln;
      Writeln('=== M3) OnLocate -> listede olmayan anahtarin metni ===');
      LSehir.Properties.OnLocate := LS.SehirLocate;
      LSehir.Properties.ResetLocateCache;
      Writeln('  liste su an Almanya sehirleri (', LS.QSehir.RecordCount, ' satir)');
      LS.LocateSayaci := 0;
      LMetin := TPropsAccess(LSehir.Properties).GetDisplayLookupText(30); { Paris - listede YOK }
      Writeln('  anahtar 30 icin metin : "', LMetin, '"  (Paris bekleniyor)');
      Writeln('  OnLocate tetiklenme   : ', LS.LocateSayaci, ' (1 bekleniyor)');

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

      LForm.Free;
    except
      on E: Exception do
        Writeln('HATA: ', E.ClassName, ': ', E.Message);
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
