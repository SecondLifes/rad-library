program RadSettingLiveTest;

(*
  CANLI VERITABANI - TcxRadSetting.

  Olculen:
    A) Ulke -> Il -> Ilce zinciri RadSetting.Control1 ile kurulur; hedefin
       Key/Tag'i olay isleyicisinde okunur ve liste PostgreSQL'den dolar.
       Zincir koparilabilir, hedef yok edilince AV olmaz.
    B) RadSetting.DataBinding gercek bir TUniQuery'e baglanir: deger okunur,
       gezinme/yenileme/duzenleme gorulur, dataset yok edilince AV olmaz.
    C) Tek RepositoryItem + tek isleyici, TUKETICI-BASINA Key: formda ve
       gridde ayni isleyici her tuketicinin KENDI Key'ini okur.

  ! KIMLIK BILGISI KAYNAK KODA YAZILMAZ: %LOCALAPPDATA%\rad\test-db.env ya da
    RAD_PG_* ortam degiskenleri.
  ! SADECE rad_test_* tablolari olusturulur; testin sonunda silinir.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, System.IOUtils, System.TypInfo,
  Winapi.Windows, Vcl.Forms, Vcl.Controls, Data.DB,
  Uni, UniProvider, PostgreSQLUniProvider,
  cxEdit, cxDropDownEdit, cxDBEdit, cxDataUtils, cxCustomData, cxClasses,
  cxGrid, cxGridLevel, cxGridCustomTableView, cxGridTableView, cxGridDBTableView,
  Rad.Dev, Help.Dev;

type
  TCfg = record Host, Port, Db, User, Pass: string; end;

  TEditHack = class(TcxCustomEdit)
  public
    procedure Press(AIndex: Integer);
  end;

  TSenaryo = class
  public
    Con: TUniConnection;
    Q: TUniQuery;
    KademeSayisi: Integer;
    SonKey: string;
    SonTag: Integer;
    TiklaKey: string;
    procedure Kademe(Sender: TRadComboBoxProperties; ASource, ATarget: TComponent;
      const AValue: Variant);
    procedure Tikla(Sender: TObject; AButtonIndex: Integer);
  end;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;

procedure TEditHack.Press(AIndex: Integer);
begin
  DoButtonClick(AIndex);
end;

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

{ TSenaryo }

(* Zincir halkasi: kaynaktaki degere gore HEDEFIN listesini PostgreSQL'den doldurur.
   Hangi SQL'in calisacagi hedefin KENDI RadSetting.Key'inden gelir. *)
procedure TSenaryo.Kademe(Sender: TRadComboBoxProperties; ASource, ATarget: TComponent;
  const AValue: Variant);
var
  LHedef: TRadComboBoxProperties;
begin
  Inc(KademeSayisi);
  LHedef := TRadComboBoxProperties(_OwnProperties(ATarget));
  SonKey := LHedef.RadSetting.Key;
  SonTag := LHedef.RadSetting.Tag;
  Q.Close;
  if SonKey = 'sehir' then
    Q.SQL.Text := 'select s.ad from rad_test_sehir s ' +
      'join rad_test_ulke u on u.kod = s.ulke_kod where u.ad = :ust order by s.ad'
  else if SonKey = 'ilce' then
    Q.SQL.Text := 'select i.ad from rad_test_ilce i ' +
      'join rad_test_sehir s on s.id = i.sehir_id where s.ad = :ust order by i.ad'
  else
    Exit;
  Q.ParamByName('ust').AsString := VarToStr(AValue);
  Q.Open;
  LHedef.Items.Clear;
  while not Q.Eof do
  begin
    LHedef.Items.Add(Q.Fields[0].AsString);
    Q.Next;
  end;
  Q.Close;
end;

(* TEK isleyici: Sender editordur; Key'i editorun KENDI Properties'inden okur. *)
procedure TSenaryo.Tikla(Sender: TObject; AButtonIndex: Integer);
begin
  TiklaKey := TcxRadSetting(GetObjectProp(TcxCustomEdit(Sender).InternalProperties,
    'RadSetting', TcxRadSetting)).Key;
end;

var
  LCfg: TCfg;
  LS: TSenaryo;
  LForm: TForm;
  LUlke, LSehir, LIlce: TRadComboBox;
  LQKayit: TUniQuery;
  LDsKayit: TDataSource;
  LBind, LBind2: TcxRadDataBinding;
  LRepo: TcxEditRepository;
  LItem: TRadComboBoxRepository;
  LEdKasa, LEdDepo: TRadComboBox;
  LGrid: TcxGrid;
  LView: TcxGridDBTableView;
  LColK, LColD: TcxGridDBColumn;
  LV: Variant;
  LBtnItem: TRadButtonEditRepository;
  LBtnKasa, LBtnDepo: TRadButtonEdit;
  LGrid2: TcxGrid;
  LView2: TcxGridDBTableView;
  LBtnColK, LBtnColD: TcxGridDBColumn;

procedure GridTikla(ACol: TcxGridDBColumn);
begin
  LView.Controller.FocusedColumn := ACol;
  LView.Controller.EditingController.ShowEdit(ACol);
  Bekle(40);
  LS.TiklaKey := '<hucre editoru acilmadi>';
  if LView.Controller.EditingController.Edit <> nil then
    TEditHack(LView.Controller.EditingController.Edit).Press(0);
  LView.Controller.EditingController.HideEdit(False);
  Bekle(20);
end;

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

      Calistir(LS.Con, 'drop table if exists rad_test_kayit');
      Calistir(LS.Con, 'drop table if exists rad_test_ilce');
      Calistir(LS.Con, 'drop table if exists rad_test_sehir');
      Calistir(LS.Con, 'drop table if exists rad_test_ulke');
      Calistir(LS.Con, 'create table rad_test_ulke (kod char(2) primary key, ad varchar(60))');
      Calistir(LS.Con, 'create table rad_test_sehir (id integer primary key, ' +
        'ulke_kod char(2), ad varchar(60))');
      Calistir(LS.Con, 'create table rad_test_ilce (id integer primary key, ' +
        'sehir_id integer, ad varchar(60))');
      Calistir(LS.Con, 'create table rad_test_kayit (id integer primary key, ' +
        'ulke varchar(60), sehir varchar(60))');
      Calistir(LS.Con, 'insert into rad_test_ulke values (''TR'',''Turkiye''),(''DE'',''Almanya'')');
      Calistir(LS.Con, 'insert into rad_test_sehir values (1,''TR'',''Istanbul''),' +
        '(2,''TR'',''Ankara''),(3,''DE'',''Berlin''),(4,''DE'',''Munih'')');
      Calistir(LS.Con, 'insert into rad_test_ilce values (1,1,''Kadikoy''),(2,1,''Besiktas''),' +
        '(3,2,''Cankaya''),(4,3,''Mitte'')');
      Calistir(LS.Con, 'insert into rad_test_kayit values (1,''Turkiye'',''Istanbul''),' +
        '(2,''Almanya'',''Berlin'')');
      Writeln('rad_test_ulke/sehir/ilce/kayit olusturuldu.');

      Application.Initialize;
      LForm := TForm.CreateNew(nil);
      try
        LForm.Width := 760; LForm.Height := 460;
        LForm.Position := poScreenCenter;
        LForm.Show;
        Bekle(150);

        LS.Q := TUniQuery.Create(LForm);
        LS.Q.Connection := LS.Con;

        Writeln;
        Writeln('=== A) Ulke -> Il -> Ilce, RadSetting.Control1 zinciri ===');
        LUlke := TRadComboBox.Create(LForm);  LUlke.Parent := LForm;
        LUlke.SetBounds(20, 20, 160, 24);
        LSehir := TRadComboBox.Create(LForm); LSehir.Parent := LForm;
        LSehir.SetBounds(20, 50, 160, 24);
        LIlce := TRadComboBox.Create(LForm);  LIlce.Parent := LForm;
        LIlce.SetBounds(20, 80, 160, 24);
        LSehir.Properties.RadSetting.Key := 'sehir';
        LSehir.Properties.RadSetting.Tag := 2;
        LIlce.Properties.RadSetting.Key := 'ilce';
        LIlce.Properties.RadSetting.Tag := 3;
        LUlke.Properties.RadSetting.Control1 := LSehir;
        LSehir.Properties.RadSetting.Control1 := LIlce;
        LUlke.Properties.AOnCascade := LS.Kademe;
        LSehir.Properties.AOnCascade := LS.Kademe;
        Bekle(60);

        LUlke.EditValue := 'Turkiye';
        Bekle(40);
        Kontrol('A01 ulke secilince il listesi PostgreSQL''den gelir',
          LSehir.Properties.Items.CommaText = 'Ankara,Istanbul', LSehir.Properties.Items.CommaText);
        Kontrol('A02 isleyici HEDEFIN Key/Tag''ini gordu', (LS.SonKey = 'sehir') and (LS.SonTag = 2),
          LS.SonKey + '/' + IntToStr(LS.SonTag));
        LSehir.EditValue := 'Istanbul';
        Bekle(40);
        Kontrol('A03 il secilince ilce listesi gelir',
          LIlce.Properties.Items.CommaText = 'Besiktas,Kadikoy', LIlce.Properties.Items.CommaText);
        Kontrol('A04 ikinci halka: Key=ilce, Tag=3', (LS.SonKey = 'ilce') and (LS.SonTag = 3),
          LS.SonKey + '/' + IntToStr(LS.SonTag));
        Kontrol('A05 iki halka = iki isleyici cagrisi', LS.KademeSayisi = 2, IntToStr(LS.KademeSayisi));

        LUlke.EditValue := 'Almanya';
        Bekle(40);
        Kontrol('A06 ulke degisince il listesi yenilenir',
          LSehir.Properties.Items.CommaText = 'Berlin,Munih', LSehir.Properties.Items.CommaText);

        LS.KademeSayisi := 0;
        LUlke.Properties.RadSetting.Control1 := nil;
        LUlke.EditValue := 'Turkiye';
        Bekle(40);
        Kontrol('A07 Control1 bosaltilinca zincir durur', LS.KademeSayisi = 0, IntToStr(LS.KademeSayisi));

        LUlke.Properties.RadSetting.Control1 := LSehir;
        LSehir.Properties.RadSetting.Control1 := LIlce;
        LIlce.Free;
        Kontrol('A08 hedef yok edildi: yuva nil''lendi, AV yok',
          LSehir.Properties.RadSetting.Control1 = nil);
        LUlke.EditValue := 'Almanya';
        Bekle(40);
        LSehir.EditValue := 'Berlin';
        Bekle(40);
        Kontrol('A09 yok olan hedefe haber gonderilmedi, yine calisiyor',
          LSehir.Properties.Items.CommaText = 'Berlin,Munih', LSehir.Properties.Items.CommaText);

        Writeln;
        Writeln('=== B) RadSetting.DataBinding, canli TUniQuery ===');
        LQKayit := TUniQuery.Create(LForm);
        LQKayit.Connection := LS.Con;
        LQKayit.SQL.Text := 'select id, ulke, sehir from rad_test_kayit order by id';
        LQKayit.Open;
        LDsKayit := TDataSource.Create(LForm);
        LDsKayit.DataSet := LQKayit;
        LBind := LUlke.Properties.RadSetting.DataBinding;
        LBind.DataSource := LDsKayit;
        LBind.DataField := 'ulke';
        Kontrol('B01 baslangic degeri', VarToStr(LBind.Value) = 'Turkiye', VarToStr(LBind.Value));
        LQKayit.Next;
        Kontrol('B02 kayit degisince deger de degisir', VarToStr(LBind.Value) = 'Almanya',
          VarToStr(LBind.Value));
        LQKayit.Close;
        Kontrol('B03 sorgu kapaliyken kullanilamaz', not LBind.IsAvailable);
        LQKayit.Open;
        Kontrol('B04 sorgu yeniden acilinca baglanti geri gelir (yenileme)',
          LBind.IsAvailable and (VarToStr(LBind.Value) = 'Turkiye'), VarToStr(LBind.Value));
        LQKayit.Edit;
        LQKayit.FieldByName('ulke').AsString := 'Fransa';
        Kontrol('B05 duzenleme sirasindaki (kaydedilmemis) deger okunur',
          VarToStr(LBind.Value) = 'Fransa', VarToStr(LBind.Value));
        LQKayit.Cancel;
        Kontrol('B06 iptal sonrasi eski deger', VarToStr(LBind.Value) = 'Turkiye', VarToStr(LBind.Value));
        LBind2 := LSehir.Properties.RadSetting.DataBinding;
        LBind2.DataSource := LDsKayit;
        LBind2.DataField := 'sehir';
        Kontrol('B07 iki baglanti ayni dataset''te birbirinden bagimsiz',
          (VarToStr(LBind.Value) = 'Turkiye') and (VarToStr(LBind2.Value) = 'Istanbul'));
        LUlke.Properties.Assign(LSehir.Properties);
        Kontrol('B08 Properties.Assign DataBinding''i kopyalar',
          (LUlke.Properties.RadSetting.DataBinding.DataField = 'sehir') and
          (LUlke.Properties.RadSetting.DataBinding.DataSource = LDsKayit));
        LDsKayit.Free;
        Kontrol('B09 DataSource yok edilince AV yok, baglanti kopar',
          (LBind.DataSource = nil) and not LBind.IsAvailable and VarIsNull(LBind.Value));

        Writeln;
        Writeln('=== C) Tek RepositoryItem + tek isleyici, tuketici-basina Key ===');
        LDsKayit := TDataSource.Create(LForm);
        LDsKayit.DataSet := LQKayit;
        LRepo := TcxEditRepository.Create(LForm);
        LItem := TRadComboBoxRepository(LRepo.CreateItem(TRadComboBoxRepository));
        LItem.Properties.OnButtonClick := LS.Tikla;

        LEdKasa := TRadComboBox.Create(LForm); LEdKasa.Parent := LForm;
        LEdKasa.SetBounds(220, 20, 140, 24);
        LEdKasa.RepositoryItem := LItem;
        LEdKasa.Properties.RadSetting.Key := 'IDKasa';
        LEdDepo := TRadComboBox.Create(LForm); LEdDepo.Parent := LForm;
        LEdDepo.SetBounds(220, 50, 140, 24);
        LEdDepo.RepositoryItem := LItem;
        LEdDepo.Properties.RadSetting.Key := 'IDDepo';
        Bekle(40);

        LS.TiklaKey := '';
        TEditHack(LEdKasa).Press(0);
        Kontrol('C01 formda kasa editoru: isleyici Key=IDKasa gordu', LS.TiklaKey = 'IDKasa', LS.TiklaKey);
        TEditHack(LEdDepo).Press(0);
        Kontrol('C02 formda depo editoru: isleyici Key=IDDepo gordu', LS.TiklaKey = 'IDDepo', LS.TiklaKey);

        LGrid := TcxGrid.Create(LForm);
        LGrid.Parent := LForm;
        LGrid.SetBounds(380, 20, 340, 200);
        LView := LGrid.CreateView(TcxGridDBTableView) as TcxGridDBTableView;
        LGrid.Levels.Add.GridView := LView;
        LView.DataController.DataSource := LDsKayit;
        LColK := LView.CreateColumn; LColK.DataBinding.FieldName := 'ulke';
        LColD := LView.CreateColumn; LColD.DataBinding.FieldName := 'sehir';
        LColK.PropertiesClass := TRadComboBoxProperties;
        LColD.PropertiesClass := TRadComboBoxProperties;
        TRadComboBoxProperties(LColK.Properties).RadSetting.Key := 'IDKasa';
        TRadComboBoxProperties(LColD.Properties).RadSetting.Key := 'IDDepo';
        LColK.RepositoryItem := LItem;
        LColD.RepositoryItem := LItem;
        LGrid.SetFocus;
        Bekle(120);
        LView.DataController.FocusedRecordIndex := 0;
        GridTikla(LColK);
        Kontrol('C03 gridde kasa sutunu: isleyici Key=IDKasa gordu', LS.TiklaKey = 'IDKasa', LS.TiklaKey);
        GridTikla(LColD);
        Kontrol('C04 gridde depo sutunu: isleyici Key=IDDepo gordu', LS.TiklaKey = 'IDDepo', LS.TiklaKey);
        LV := LItem.Properties.RadSetting.Key;
        Kontrol('C05 paylasilan item''in kendi Key''i bos kaldi', VarToStr(LV) = '', VarToStr(LV));

        Writeln;
        Writeln('=== D) TRadButtonEdit: ayni senaryo (OrtakBtn: Kasa/Depo) ===');
        LBtnItem := TRadButtonEditRepository(LRepo.CreateItem(TRadButtonEditRepository));
        LBtnItem.Properties.OnButtonClick := LS.Tikla;
        LBtnKasa := TRadButtonEdit.Create(LForm); LBtnKasa.Parent := LForm;
        LBtnKasa.SetBounds(220, 90, 140, 24);
        LBtnKasa.RepositoryItem := LBtnItem;
        LBtnKasa.Properties.RadSetting.Key := 'IDKasa';
        LBtnDepo := TRadButtonEdit.Create(LForm); LBtnDepo.Parent := LForm;
        LBtnDepo.SetBounds(220, 120, 140, 24);
        LBtnDepo.RepositoryItem := LBtnItem;
        LBtnDepo.Properties.RadSetting.Key := 'IDDepo';
        Bekle(40);
        TEditHack(LBtnKasa).Press(0);
        Kontrol('D01 formda kasa: isleyici Key=IDKasa gordu', LS.TiklaKey = 'IDKasa', LS.TiklaKey);
        TEditHack(LBtnDepo).Press(0);
        Kontrol('D02 formda depo: isleyici Key=IDDepo gordu', LS.TiklaKey = 'IDDepo', LS.TiklaKey);

        LGrid2 := TcxGrid.Create(LForm);
        LGrid2.Parent := LForm;
        LGrid2.SetBounds(380, 240, 340, 180);
        LView2 := LGrid2.CreateView(TcxGridDBTableView) as TcxGridDBTableView;
        LGrid2.Levels.Add.GridView := LView2;
        LView2.DataController.DataSource := LDsKayit;
        LBtnColK := LView2.CreateColumn; LBtnColK.DataBinding.FieldName := 'ulke';
        LBtnColD := LView2.CreateColumn; LBtnColD.DataBinding.FieldName := 'sehir';
        LBtnColK.PropertiesClass := TRadButtonEditProperties;
        LBtnColD.PropertiesClass := TRadButtonEditProperties;
        TRadButtonEditProperties(LBtnColK.Properties).RadSetting.Key := 'IDKasa';
        TRadButtonEditProperties(LBtnColD.Properties).RadSetting.Key := 'IDDepo';
        LBtnColK.RepositoryItem := LBtnItem;
        LBtnColD.RepositoryItem := LBtnItem;
        LGrid2.SetFocus;
        Bekle(120);
        LView2.DataController.FocusedRecordIndex := 0;
        LView := LView2;
        GridTikla(LBtnColK);
        Kontrol('D03 gridde kasa sutunu: isleyici Key=IDKasa gordu', LS.TiklaKey = 'IDKasa', LS.TiklaKey);
        GridTikla(LBtnColD);
        Kontrol('D04 gridde depo sutunu: isleyici Key=IDDepo gordu', LS.TiklaKey = 'IDDepo', LS.TiklaKey);      finally
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
      Calistir(LS.Con, 'drop table if exists rad_test_ilce');
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
    Halt(1);
end.
