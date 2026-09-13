program ComboFillLiveTest;

(*
  CANLI VERITABANI - TRadDBComboBox, tek AOnFill ile Ulke -> Sehir -> Ilce,
  kayda yalnizca ADLAR yazilir. Formda ve gridde.

  Olculen:
    - tek global AOnFill, AEditorId'ye gore dogru SQL'i calistiriyor;
    - AMasterFields degerleri SORAN editorun kaydindan geliyor (formda kaydin,
      gridde satirin);
    - ayni degerlerle ikinci acilista sorgu gitmiyor;
    - gridde satir degisince liste degisiyor;
    - ACIK NOKTA: gridde ayni satirda ust kolonda degistirilen deger, alt
      kolonun listesi acilmadan KAYIT ALANINA yazilmis oluyor mu?

  ! KIMLIK BILGISI KAYNAK KODA YAZILMAZ: %LOCALAPPDATA%\rad\test-db.env ya da
    RAD_PG_* ortam degiskenleri.
  ! SADECE rad_test_* tablolari olusturulur; testin sonunda silinir.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, System.IOUtils, System.StrUtils,
  Winapi.Windows, Vcl.Forms, Vcl.Controls, Data.DB,
  Uni, UniProvider, PostgreSQLUniProvider,
  cxEdit, cxDropDownEdit, cxDBEdit, cxDataUtils, cxCustomData,
  cxGrid, cxGridLevel, cxGridCustomTableView, cxGridTableView, cxGridDBTableView,
  Rad.Dev;

type
  TCfg = record Host, Port, Db, User, Pass: string; end;

  TSenaryo = class
  public
    Con: TUniConnection;
    QKayit, QListe: TUniQuery;
    SorguSayisi: Integer;
    procedure ListeDoldur(Sender: TRadComboBoxProperties; ASource: TComponent;
      AParams: TParams; AItems: TStrings);
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

{ TSenaryo - kullaniciya onerilen TEK global isleyici }

procedure TSenaryo.ListeDoldur(Sender: TRadComboBoxProperties; ASource: TComponent;
  AParams: TParams; AItems: TStrings);
begin
  Inc(SorguSayisi);
  QListe.Close;
  case IndexText(Sender.AEditorId, ['ulke', 'sehir', 'ilce']) of
    0: QListe.SQL.Text := 'select ad from rad_test_ulke order by ad';
    1: QListe.SQL.Text :=
         'select s.ad from rad_test_sehir s join rad_test_ulke u on u.kod = s.ulke_kod ' +
         'where u.ad = :ulke order by s.ad';
    2: QListe.SQL.Text :=
         'select i.ad from rad_test_ilce i ' +
         'join rad_test_sehir s on s.id = i.sehir_id ' +
         'join rad_test_ulke u on u.kod = s.ulke_kod ' +
         'where u.ad = :ulke and s.ad = :sehir order by i.ad';
  else
    Exit;
  end;
  QListe.Params.AssignValues(AParams);
  QListe.Open;
  try
    AItems.Clear;
    while not QListe.Eof do
    begin
      AItems.Add(QListe.Fields[0].AsString);
      QListe.Next;
    end;
  finally
    QListe.Close;
  end;
end;

function Item(ARepo: TcxEditRepository; const AId, AAlanlar: string;
  ASen: TSenaryo): TRadComboBoxRepository;
begin
  Result := TRadComboBoxRepository(ARepo.CreateItem(TRadComboBoxRepository));
  Result.Properties.AEditorId := AId;
  Result.Properties.AMasterFields := AAlanlar;
  Result.Properties.AOnFill := ASen.ListeDoldur;
end;

function Combo(AForm: TForm; AItem: TcxEditRepositoryItem; ADs: TDataSource;
  const AAlan: string; ATop: Integer): TRadDBComboBox;
begin
  Result := TRadDBComboBox.Create(AForm);
  Result.Parent := AForm;
  Result.Left := 20;
  Result.Top := ATop;
  Result.Width := 200;
  Result.RepositoryItem := AItem;
  Result.DataBinding.DataSource := ADs;
  Result.DataBinding.DataField := AAlan;
end;

{ Listeyi GERCEKTEN acarak (DoInitPopup yolu) doldurur, sonra kapatir. }
function Ac(AEd: TcxCustomDropDownEdit): string;
begin
  AEd.DroppedDown := True;
  Bekle(60);
  Result := TcxCustomComboBoxProperties(AEd.ActiveProperties).Items.CommaText;
  AEd.DroppedDown := False;
  Bekle(20);
end;

var
  LCfg: TCfg;
  LS: TSenaryo;
  LForm: TForm;
  LDsKayit: TDataSource;
  LRepo: TcxEditRepository;
  LRiUlke, LRiSehir, LRiIlce: TRadComboBoxRepository;
  LUlke, LSehir, LIlce: TRadDBComboBox;
  LGrid: TcxGrid;
  LLevel: TcxGridLevel;
  LView: TcxGridDBTableView;
  LColUlke, LColSehir, LColIlce: TcxGridDBColumn;
  LOnce: Integer;
  LListe: string;

procedure GridHucre(ASatir: Integer; ACol: TcxGridDBColumn; out AListe: string);
var
  LEd: TcxCustomEdit;
begin
  LView.DataController.FocusedRecordIndex := ASatir;
  LView.Controller.FocusedColumn := ACol;
  LView.Controller.EditingController.ShowEdit(ACol);
  Bekle(40);
  LEd := LView.Controller.EditingController.Edit;
  if LEd is TcxCustomDropDownEdit then
    AListe := Ac(TcxCustomDropDownEdit(LEd))
  else
    AListe := '<hucre editoru acilmadi>';
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

      { ── Test verisi (yalnizca rad_test_*) ─────────────────────────────── }
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
        'ulke varchar(60), sehir varchar(60), ilce varchar(60))');
      Calistir(LS.Con, 'insert into rad_test_ulke values (''TR'',''Turkiye''),(''DE'',''Almanya'')');
      Calistir(LS.Con, 'insert into rad_test_sehir values (1,''TR'',''Istanbul''),' +
        '(2,''TR'',''Ankara''),(3,''DE'',''Berlin''),(4,''DE'',''Munih'')');
      Calistir(LS.Con, 'insert into rad_test_ilce values (1,1,''Kadikoy''),(2,1,''Besiktas''),' +
        '(3,2,''Cankaya''),(4,3,''Mitte'')');
      Calistir(LS.Con, 'insert into rad_test_kayit values ' +
        '(1,''Turkiye'',''Istanbul'',''Kadikoy''),(2,''Almanya'',''Berlin'',''Mitte'')');
      Writeln('rad_test_ulke/sehir/ilce/kayit olusturuldu.');

      Application.Initialize;
      LForm := TForm.CreateNew(nil);
      try
        LForm.Width := 700; LForm.Height := 420;
        LForm.Position := poScreenCenter;
        LForm.Show;
        Bekle(150);

        LS.QListe := TUniQuery.Create(LForm);
        LS.QListe.Connection := LS.Con;
        LS.QKayit := TUniQuery.Create(LForm);
        LS.QKayit.Connection := LS.Con;
        LS.QKayit.SQL.Text := 'select id, ulke, sehir, ilce from rad_test_kayit order by id';
        LS.QKayit.Open;
        LDsKayit := TDataSource.Create(LForm);
        LDsKayit.DataSet := LS.QKayit;

        LRepo := TcxEditRepository.Create(LForm);
        LRiUlke := Item(LRepo, 'ulke', '', LS);
        LRiSehir := Item(LRepo, 'sehir', 'ulke', LS);
        LRiIlce := Item(LRepo, 'ilce', 'ulke;sehir', LS);

        LUlke := Combo(LForm, LRiUlke, LDsKayit, 'ulke', 20);
        LSehir := Combo(LForm, LRiSehir, LDsKayit, 'sehir', 50);
        LIlce := Combo(LForm, LRiIlce, LDsKayit, 'ilce', 80);
        Bekle(80);

        Writeln;
        Writeln('=== F) Formda ===');
        LS.SorguSayisi := 0;
        LListe := Ac(LSehir);
        Kontrol('F01 kayit 1 (Turkiye): sehir listesi', LListe = 'Ankara,Istanbul', LListe);
        Kontrol('F02 bir sorgu', LS.SorguSayisi = 1, IntToStr(LS.SorguSayisi));
        LListe := Ac(LSehir);
        Kontrol('F03 yeniden acinca SORGU YOK', LS.SorguSayisi = 1, IntToStr(LS.SorguSayisi));
        LListe := Ac(LIlce);
        Kontrol('F04 ilce listesi iki ust alanla (Turkiye/Istanbul)',
          LListe = 'Besiktas,Kadikoy', LListe);
        LListe := Ac(LUlke);
        Kontrol('F05 sabit ulke listesi', LListe = 'Almanya,Turkiye', LListe);
        LOnce := LS.SorguSayisi;
        LS.QKayit.Next;
        Bekle(40);
        Ac(LUlke);
        Kontrol('F06 ulke listesi kayit degisince tekrar SORGULANMADI',
          LS.SorguSayisi = LOnce, IntToStr(LS.SorguSayisi - LOnce));
        LListe := Ac(LSehir);
        Kontrol('F07 kayit 2 (Almanya): sehir listesi', LListe = 'Berlin,Munih', LListe);
        LListe := Ac(LIlce);
        Kontrol('F08 kayit 2: ilce listesi', LListe = 'Mitte', LListe);
        Kontrol('F09 gezinme kaydi duzenleme moduna sokmadi', LS.QKayit.State = dsBrowse);

        Writeln;
        Writeln('=== G) Gridde ===');
        LGrid := TcxGrid.Create(LForm);
        LGrid.Parent := LForm;
        LGrid.SetBounds(240, 20, 420, 340);
        LLevel := LGrid.Levels.Add;
        LView := LGrid.CreateView(TcxGridDBTableView) as TcxGridDBTableView;
        LLevel.GridView := LView;
        LView.DataController.DataSource := LDsKayit;
        LColUlke := LView.CreateColumn;
        LColUlke.DataBinding.FieldName := 'ulke';
        LColUlke.RepositoryItem := LRiUlke;
        LColSehir := LView.CreateColumn;
        LColSehir.DataBinding.FieldName := 'sehir';
        LColSehir.RepositoryItem := LRiSehir;
        LColIlce := LView.CreateColumn;
        LColIlce.DataBinding.FieldName := 'ilce';
        LColIlce.RepositoryItem := LRiIlce;
        LGrid.SetFocus;
        Bekle(120);

        GridHucre(0, LColSehir, LListe);
        Kontrol('G01 satir 1 (Turkiye): sehir hucresinin listesi', LListe = 'Ankara,Istanbul',
          LListe);
        GridHucre(1, LColSehir, LListe);
        Kontrol('G02 satir 2 (Almanya): sehir hucresinin listesi', LListe = 'Berlin,Munih',
          LListe);
        GridHucre(0, LColIlce, LListe);
        Kontrol('G03 satir 1: ilce hucresinin listesi', LListe = 'Besiktas,Kadikoy', LListe);

        (* ACIK NOKTA: ayni satirda ust kolonun degeri degisir, alt kolon acilir.
           Degisiklik gridin veri denetleyicisi uzerinden yapiliyor - hucre
           editorunun "kaydet" adiminin yaptigi sey. *)
        LView.DataController.FocusedRecordIndex := 0;
        LView.DataController.Edit;
        LView.DataController.SetEditValue(LColUlke.Index, 'Almanya', evsValue);
        Writeln('  [BILGI] SetEditValue sonrasi kayit alani ulke = "',
          LS.QKayit.FieldByName('ulke').AsString, '", dataset durumu = ',
          Ord(LS.QKayit.State));
        GridHucre(0, LColSehir, LListe);
        Writeln('  [BILGI] ayni satirda sehir hucresinin listesi = "', LListe, '"');
        Kontrol('G04 ayni satirda ust kolon degisince alt kolonun listesi yeni degere gore',
          LListe = 'Berlin,Munih', LListe);
        LView.DataController.Cancel;
        if LS.QKayit.State in [dsEdit, dsInsert] then
          LS.QKayit.Cancel;
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
    ExitCode := 1;
end.
