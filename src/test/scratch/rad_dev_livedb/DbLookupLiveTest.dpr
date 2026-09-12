program DbLookupLiveTest;

(*
  CANLI VERITABANI - TRadDBLookupComboBox, bir KAYIT dataset'ine bagli
  ulke -> sehir. Kullaniciya onerilen kurulumun olculmesi:

    - liste sorgulari sunucuda suzulu ve 'limit 15' ile sinirli,
    - secili_id parametresi, gosterilen anahtarin satirini listede tutar
      (limit disinda kalsa bile metin bos gorunmesin diye),
    - ulke degisince eski sehir KAYIT alaninda (TField.OnChange) temizlenir,
    - gezinme kaydi duzenleme moduna sokmaz.

  ! KIMLIK BILGISI KAYNAK KODA YAZILMAZ: %LOCALAPPDATA%\rad\test-db.env ya da
    RAD_PG_* ortam degiskenleri.
  ! SADECE rad_test_* tablolari olusturulur; testin sonunda silinir.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, System.IOUtils,
  Winapi.Windows, Vcl.Forms, Vcl.Controls, Data.DB,
  Uni, UniProvider, PostgreSQLUniProvider,
  cxEdit, cxDBLookupComboBox,
  Rad.Dev;

type
  TCfg = record Host, Port, Db, User, Pass: string; end;

  TSenaryo = class
  public
    Con: TUniConnection;
    QKayit, QUlke, QSehir: TUniQuery;
    LocateSayisi: Integer;
    procedure SetSecili(AQ: TUniQuery; const AKey: Variant);
    procedure Ara(AQ: TUniQuery; const AText: string);
    procedure UlkeArama(Sender: TRadLookupComboBoxProperties; ASource: TComponent;
      var AText, ATail: string; ANext: Boolean);
    procedure UlkeLocate(Sender: TRadLookupComboBoxProperties; ASource: TComponent;
      const AKey: Variant);
    procedure SehirFilter(Sender: TRadLookupComboBoxProperties;
      ASource, AMaster: TComponent; const AMasterValue: Variant);
    procedure SehirArama(Sender: TRadLookupComboBoxProperties; ASource: TComponent;
      var AText, ATail: string; ANext: Boolean);
    procedure SehirLocate(Sender: TRadLookupComboBoxProperties; ASource: TComponent;
      const AKey: Variant);
    procedure UlkeAlanDegisti(Sender: TField);
  end;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;

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
  Flush(Output);
end;

procedure Bekle(AMs: Cardinal);
var
  LBitis: UInt64;
begin
  LBitis := GetTickCount64 + AMs;
  while GetTickCount64 < LBitis do
  begin
    Application.ProcessMessages;
    Sleep(5);
  end;
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

{ TSenaryo - kullaniciya onerilen isleyicilerin aynisi }

procedure TSenaryo.SetSecili(AQ: TUniQuery; const AKey: Variant);
begin
  if VarIsNull(AKey) or VarIsEmpty(AKey) then
    AQ.ParamByName('secili_id').Clear
  else
    AQ.ParamByName('secili_id').AsInteger := AKey;
end;

procedure TSenaryo.Ara(AQ: TUniQuery; const AText: string);
begin
  AQ.Close;
  if AText = '' then
    AQ.ParamByName('arama').AsString := '%'
  else
    AQ.ParamByName('arama').AsString := '%' + AText + '%';
  AQ.Open;
end;

procedure TSenaryo.UlkeArama(Sender: TRadLookupComboBoxProperties; ASource: TComponent;
  var AText, ATail: string; ANext: Boolean);
begin
  Ara(QUlke, AText);
end;

procedure TSenaryo.UlkeLocate(Sender: TRadLookupComboBoxProperties; ASource: TComponent;
  const AKey: Variant);
begin
  Inc(LocateSayisi);
  QUlke.Close;
  SetSecili(QUlke, AKey);
  QUlke.Open;
end;

procedure TSenaryo.SehirFilter(Sender: TRadLookupComboBoxProperties;
  ASource, AMaster: TComponent; const AMasterValue: Variant);
begin
  if ASource is TcxCustomEdit then
    SetSecili(QSehir, TcxCustomEdit(ASource).EditValue);
end;

procedure TSenaryo.SehirArama(Sender: TRadLookupComboBoxProperties; ASource: TComponent;
  var AText, ATail: string; ANext: Boolean);
begin
  Ara(QSehir, AText);
end;

procedure TSenaryo.SehirLocate(Sender: TRadLookupComboBoxProperties; ASource: TComponent;
  const AKey: Variant);
begin
  Inc(LocateSayisi);
  QSehir.Close;
  SetSecili(QSehir, AKey);
  QSehir.Open;
end;

procedure TSenaryo.UlkeAlanDegisti(Sender: TField);
begin
  QKayit.FieldByName('sehir_id').Clear;
end;

function YeniSorgu(AOwner: TComponent; ACon: TUniConnection; const ASql: string): TUniQuery;
begin
  Result := TUniQuery.Create(AOwner);
  Result.Connection := ACon;
  Result.SQL.Text := ASql;
end;

function Editor(AForm: TForm; AListe: TDataSource; ATop: Integer): TRadDBLookupComboBox;
begin
  Result := TRadDBLookupComboBox.Create(AForm);
  Result.Parent := AForm;
  Result.Left := 20;
  Result.Top := ATop;
  Result.Width := 260;
  Result.Properties.ListSource := AListe;
  Result.Properties.KeyFieldNames := 'id';
  Result.Properties.ListFieldNames := 'ad';
end;

{ Bag, OLAYLAR ATANDIKTAN SONRA: DFM'de de once ozellikler/olaylar yuklenir,
  veri sonra gelir. Ilk surumde once baglaniyordu; ilk metin AOnLocate yokken
  cozulup metin onbellegine BOS olarak yaziliyordu (olculdu, L01). }
procedure Bagla(AEd: TRadDBLookupComboBox; AKayit: TDataSource; const AAlan: string);
begin
  AEd.DataBinding.DataSource := AKayit;
  AEd.DataBinding.DataField := AAlan;
end;

var
  LCfg: TCfg;
  LS: TSenaryo;
  LForm: TForm;
  LDsKayit, LDsUlke, LDsSehir: TDataSource;
  LUlke, LSehir: TRadDBLookupComboBox;
  LDenetim: string;
  i: Integer;

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

      { ── Test verisi (yalnizca rad_test_*) ─────────────────────────────── }
      Calistir(LS.Con, 'drop table if exists rad_test_kayit');
      Calistir(LS.Con, 'drop table if exists rad_test_sehir');
      Calistir(LS.Con, 'drop table if exists rad_test_ulke');
      Calistir(LS.Con, 'create table rad_test_ulke (id integer primary key, ad varchar(60))');
      Calistir(LS.Con, 'create table rad_test_sehir (id integer primary key, ad varchar(60), ' +
        'ulke_id integer)');
      Calistir(LS.Con, 'create table rad_test_kayit (id integer primary key, ulke_id integer, ' +
        'sehir_id integer)');
      Calistir(LS.Con, 'insert into rad_test_ulke values (1,''Turkiye''),(5,''CokSehirli'')');
      Calistir(LS.Con, 'insert into rad_test_sehir values ' +
        '(10,''Istanbul'',1),(11,''Ankara'',1),(12,''Izmir'',1),(13,''Bursa'',1)');
      for i := 1 to 40 do
        Calistir(LS.Con, Format(
          'insert into rad_test_sehir values (%d,''Kent%.2d'',5)', [500 + i, i]));
      { Kayit 1'in sehri Kent40: alfabede 40., 'limit 15'in DISINDA. }
      Calistir(LS.Con, 'insert into rad_test_kayit values (1,5,540),(2,1,11)');
      Writeln('rad_test_ulke (2), rad_test_sehir (44), rad_test_kayit (2) olusturuldu.');

      Application.Initialize;
      LForm := TForm.CreateNew(nil);
      try
        LForm.Width := 400; LForm.Height := 200;
        LForm.Position := poScreenCenter;
        LForm.Show;
        Bekle(150);

        LS.QUlke := YeniSorgu(LForm, LS.Con,
          'select id, ad from rad_test_ulke ' +
          'where ad ilike :arama or id = :secili_id ' +
          'order by (id = :secili_id) desc, ad limit 15');
        LS.QUlke.ParamByName('arama').DataType := ftString;
        LS.QUlke.ParamByName('secili_id').DataType := ftInteger;
        LS.QUlke.ParamByName('arama').AsString := '%';
        LS.QUlke.ParamByName('secili_id').Clear;
        LS.QUlke.Open;

        LS.QSehir := YeniSorgu(LForm, LS.Con,
          'select id, ad from rad_test_sehir ' +
          'where (ulke_id = :ulke_id and ad ilike :arama) or id = :secili_id ' +
          'order by (id = :secili_id) desc, ad limit 15');
        LS.QSehir.ParamByName('ulke_id').DataType := ftInteger;
        LS.QSehir.ParamByName('arama').DataType := ftString;
        LS.QSehir.ParamByName('secili_id').DataType := ftInteger;
        LS.QSehir.ParamByName('ulke_id').Clear;
        LS.QSehir.ParamByName('arama').AsString := '%';
        LS.QSehir.ParamByName('secili_id').Clear;

        LS.QKayit := YeniSorgu(LForm, LS.Con,
          'select id, ulke_id, sehir_id from rad_test_kayit order by id');
        LS.QKayit.Open;
        LS.QKayit.FieldByName('ulke_id').OnChange := LS.UlkeAlanDegisti;

        LDsKayit := TDataSource.Create(LForm);  LDsKayit.DataSet := LS.QKayit;
        LDsUlke := TDataSource.Create(LForm);   LDsUlke.DataSet := LS.QUlke;
        LDsSehir := TDataSource.Create(LForm);  LDsSehir.DataSet := LS.QSehir;

        LUlke := Editor(LForm, LDsUlke, 20);
        LUlke.Name := 'cbUlke';
        LUlke.Properties.AOnSearch := LS.UlkeArama;
        LUlke.Properties.AOnLocate := LS.UlkeLocate;
        LUlke.Properties.AMinSearchLength := 0;

        LSehir := Editor(LForm, LDsSehir, 60);
        LSehir.Name := 'cbSehir';
        LSehir.Properties.AMaster := LUlke;
        LSehir.Properties.AMasterField := 'ulke_id';
        LSehir.Properties.AAutoFilter := afServerParam;
        LSehir.Properties.AOnFilter := LS.SehirFilter;
        LSehir.Properties.AOnSearch := LS.SehirArama;
        LSehir.Properties.AOnLocate := LS.SehirLocate;
        Bagla(LUlke, LDsKayit, 'ulke_id');
        Bagla(LSehir, LDsKayit, 'sehir_id');
        Bekle(100);

        Writeln;
        Writeln('=== L1) limit disindaki anahtarin metni ===');
        Writeln('  [BILGI] AOnLocate cagri sayisi: ', LS.LocateSayisi);
        Kontrol('L01 kayit 1: sehir metni Kent40 (limit 15 disinda)',
          LSehir.Text = 'Kent40', '"' + LSehir.Text + '"');
        Kontrol('L02 kayit 1: ulke metni CokSehirli', LUlke.Text = 'CokSehirli',
          '"' + LUlke.Text + '"');

        Writeln;
        Writeln('=== L2) liste acilisi (pull) ===');
        LSehir.FilterNow;
        Kontrol('L03 sehir listesi limit ile sinirli (15 satir)',
          LS.QSehir.RecordCount = 15, IntToStr(LS.QSehir.RecordCount));
        Kontrol('L04 master parametresi ulke_id = 5',
          VarToStr(LS.QSehir.ParamByName('ulke_id').Value) = '5',
          VarToStr(LS.QSehir.ParamByName('ulke_id').Value));
        Kontrol('L05 secili sehir (540) 15 satirin ICINDE - ayni adli iki parametre birlikte baglandi',
          LS.QSehir.Locate('id', 540, []));

        LDenetim := RadChainAudit(LForm);
        Kontrol('L06 RadChainAudit AOnLocate eksigi bildirmiyor',
          Pos('AOnLocate yok', LDenetim) = 0, LDenetim);
        Writeln('  [BILGI] RadChainAudit: "', LDenetim.Replace(sLineBreak, ' | '), '"');

        Writeln;
        Writeln('=== L3) gezinme ===');
        LS.QKayit.Next;
        Bekle(50);
        Kontrol('L07 kayit 2: sehir metni Ankara', LSehir.Text = 'Ankara',
          '"' + LSehir.Text + '"');
        Kontrol('L08 gezinme kaydi duzenleme moduna sokmadi', LS.QKayit.State = dsBrowse);
        Kontrol('L09 sehir alani korunuyor (11)',
          LS.QKayit.FieldByName('sehir_id').AsInteger = 11,
          LS.QKayit.FieldByName('sehir_id').AsString);

        Writeln;
        Writeln('=== L4) ulke degisince eski sehir KAYITTA temizlenir ===');
        LS.QKayit.Edit;
        LS.QKayit.FieldByName('ulke_id').AsInteger := 5;
        Kontrol('L10 ulke_id OnChange sehir_id''yi temizledi',
          LS.QKayit.FieldByName('sehir_id').IsNull,
          LS.QKayit.FieldByName('sehir_id').AsString);
        LS.QKayit.Cancel;
        Kontrol('L11 Cancel sonrasi kayit geri geldi (sehir 11)',
          LS.QKayit.FieldByName('sehir_id').AsInteger = 11,
          LS.QKayit.FieldByName('sehir_id').AsString);
      finally
        LForm.Free;
      end;
    except
      on E: Exception do
      begin
        Inc(GHata);
        Writeln('  [PATLADI] ', E.ClassName, ': ', E.Message);
      end;
    end;
  finally
    if (LS.Con <> nil) and LS.Con.Connected then
    begin
      Calistir(LS.Con, 'drop table if exists rad_test_kayit');
      Calistir(LS.Con, 'drop table if exists rad_test_sehir');
      Calistir(LS.Con, 'drop table if exists rad_test_ulke');
      Writeln('rad_test_* tablolari silindi.');
    end;
    LS.Con.Free;
    LS.Free;
  end;

  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    ExitCode := 1;
end.
