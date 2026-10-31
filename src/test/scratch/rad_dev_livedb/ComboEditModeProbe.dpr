program ComboEditModeProbe;

(*
  SONDA (sinama): DB'ye bagli combo acilip bir oge secilip kapaninca
    1) kayit degeri eski haline donuyor mu,
    2) dataset duzenleme moduna geciyor mu?
  Olay sirasi (BeforeEdit / AfterEdit / OnDataChange) gunluge yazilir. Basarisiz
  olursa cikis kodu 1 - yani deger GERI DONUYORSA test kirmizi olur.

  ! KIMLIK BILGISI KAYNAK KODA YAZILMAZ: %LOCALAPPDATA%\rad\test-db.env.
  ! SADECE rad_test_* tablosu olusturulur; sonunda silinir.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, System.IOUtils,
  Winapi.Windows, Winapi.Messages, Vcl.Forms, Vcl.Controls, Data.DB,
  Uni, UniProvider, PostgreSQLUniProvider,
  cxEdit, cxDropDownEdit, cxDBEdit, cxClasses,
  Rad.Dev;

type
  TCfg = record Host, Port, Db, User, Pass: string; end;

  TOlay = class
  public
    Gunluk: TStringList;
    procedure Once(D: TDataSet);
    procedure Sonra(D: TDataSet);
    procedure Degisti(S: TObject; F: TField);
  end;

var
  GHata: Integer = 0;

procedure TOlay.Once(D: TDataSet);   begin Gunluk.Add('BeforeEdit'); end;
procedure TOlay.Sonra(D: TDataSet);  begin Gunluk.Add('AfterEdit');  end;
procedure TOlay.Degisti(S: TObject; F: TField);
begin
  if F = nil then Gunluk.Add('DataChange(kayit)') else Gunluk.Add('DataChange(' + F.FieldName + ')');
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

procedure Kontrol(const AAd: string; AOk: Boolean; const ADetay: string = '');
begin
  if AOk then
    Writeln('  [OK]   ', AAd)
  else
  begin
    Inc(GHata);
    Writeln('  [HATA] ', AAd, '  ', ADetay);
  end;
  if ADetay <> '' then Writeln('         ', ADetay);
  Flush(Output);
end;

function Durum(D: TDataSet): string;
begin
  case D.State of
    dsBrowse: Result := 'dsBrowse';
    dsEdit: Result := 'dsEdit';
    dsInsert: Result := 'dsInsert';
  else
    Result := 'durum=' + IntToStr(Ord(D.State));
  end;
end;

(* Gercek kullanici davranisi: odak, acilir liste, ok tusu + Enter, kapanis. *)
procedure Sec(AEd: TcxCustomDropDownEdit; ATus: Word);
begin
  AEd.SetFocus;
  Bekle(40);
  AEd.DroppedDown := True;
  Bekle(80);
  { Acik listede ok tusu: DevExpress tuslari editorun kendisine yonlendirir. }
  SendMessage(AEd.Handle, WM_KEYDOWN, ATus, 0);
  SendMessage(AEd.Handle, WM_KEYUP, ATus, 0);
  Bekle(40);
  SendMessage(AEd.Handle, WM_KEYDOWN, VK_RETURN, 0);
  SendMessage(AEd.Handle, WM_KEYUP, VK_RETURN, 0);
  Bekle(60);
  if AEd.DroppedDown then
    AEd.DroppedDown := False;
  Bekle(60);
end;

var
  LCfg: TCfg;
  LCon: TUniConnection;
  LQ: TUniQuery;
  LDS: TDataSource;
  LForm: TForm;
  LStok, LRad: TcxDBComboBox;
  LRadDb: TRadDBComboBox;
  LLook: TRadDBLookupComboBox;
  LQListe: TUniQuery;
  LDSListe: TDataSource;
  LOlay: TOlay;
  LOnce: string;

procedure Dene(const AAd: string; AEd: TcxCustomDropDownEdit; const AAlan: string;
  ABeklenenGeriDoner: Boolean = False);
begin
  Writeln;
  Writeln('--- ', AAd);
  LQ.First;
  LOlay.Gunluk.Clear;
  LOnce := LQ.FieldByName(AAlan).AsString;
  Writeln('    baslangic: ', AAlan, '=', LOnce, ' ', Durum(LQ));
  Sec(AEd, VK_DOWN);
  Writeln('    olaylar  : ', LOlay.Gunluk.CommaText);
  Writeln('    sonra    : ', AAlan, '=', LQ.FieldByName(AAlan).AsString, ' ', Durum(LQ),
    ' EditValue=', VarToStr(AEd.EditValue));
  if ABeklenenGeriDoner then
    Kontrol(AAd + ': (belgelenmis) secim dataset duzenlenmedigi icin geri doner',
      (LQ.FieldByName(AAlan).AsString = LOnce) and (VarToStr(AEd.EditValue) = LOnce) and
      (LQ.State = dsBrowse))
  else
    Kontrol(AAd + ': secilen deger geri DONMEDI',
      (LQ.FieldByName(AAlan).AsString <> LOnce) or (VarToStr(AEd.EditValue) <> LOnce),
      'kayit=' + LQ.FieldByName(AAlan).AsString + ' editor=' + VarToStr(AEd.EditValue));
  if LQ.State in [dsEdit, dsInsert] then
    LQ.Cancel;
end;

begin
  LOlay := TOlay.Create;
  LOlay.Gunluk := TStringList.Create;
  try
    try
      LCfg := Oku;
      LCon := TUniConnection.Create(nil);
      LCon.ProviderName := 'PostgreSQL';
      LCon.Server := LCfg.Host;
      LCon.Port := StrToIntDef(LCfg.Port, 5432);
      LCon.Database := LCfg.Db;
      LCon.Username := LCfg.User;
      LCon.Password := LCfg.Pass;
      LCon.LoginPrompt := False;
      LCon.Connect;
      Calistir(LCon, 'drop table if exists rad_test_combo');
      Calistir(LCon, 'create table rad_test_combo (id integer primary key, tur varchar(20), ad varchar(20))');
      Calistir(LCon, 'insert into rad_test_combo values (1,''A'',''Bir''),(2,''B'',''Iki'')');
      Calistir(LCon, 'drop table if exists rad_test_tur');
      Calistir(LCon, 'create table rad_test_tur (kod varchar(20) primary key, ad varchar(20))');
      Calistir(LCon, 'insert into rad_test_tur values (''A'',''Alfa''),(''B'',''Beta''),(''C'',''Gama'')');

      Application.Initialize;
      LForm := TForm.CreateNew(nil);
      try
        LForm.SetBounds(100, 100, 420, 200);
        LForm.Show;
        Bekle(120);
        LQ := TUniQuery.Create(LForm);
        LQ.Connection := LCon;
        LQ.SQL.Text := 'select id, tur, ad from rad_test_combo order by id';
        LQ.BeforeEdit := LOlay.Once;
        LQ.AfterEdit := LOlay.Sonra;
        LQ.Open;
        LDS := TDataSource.Create(LForm);
        LDS.DataSet := LQ;
        LDS.OnDataChange := LOlay.Degisti;
        Writeln('AutoEdit = ', BoolToStr(LDS.AutoEdit, True));

        LStok := TcxDBComboBox.Create(LForm);
        LStok.Parent := LForm; LStok.SetBounds(20, 20, 160, 24);
        LStok.Properties.Items.CommaText := 'A,B,C,D';
        LStok.DataBinding.DataSource := LDS;
        LStok.DataBinding.DataField := 'tur';
        LRadDb := TRadDBComboBox.Create(LForm);
        LRadDb.Parent := LForm; LRadDb.SetBounds(20, 60, 160, 24);
        LRadDb.Properties.Items.CommaText := 'Bir,Iki,Uc,Dort';
        LRadDb.DataBinding.DataSource := LDS;
        LRadDb.DataBinding.DataField := 'ad';
        LQListe := TUniQuery.Create(LForm);
        LQListe.Connection := LCon;
        LQListe.SQL.Text := 'select kod, ad from rad_test_tur order by kod';
        LQListe.Open;
        LDSListe := TDataSource.Create(LForm);
        LDSListe.DataSet := LQListe;
        LLook := TRadDBLookupComboBox.Create(LForm);
        LLook.Parent := LForm; LLook.SetBounds(20, 100, 160, 24);
        LLook.Properties.ListSource := LDSListe;
        LLook.Properties.KeyFieldNames := 'kod';
        LLook.Properties.ListFieldNames := 'ad';
        LLook.DataBinding.DataSource := LDS;
        LLook.DataBinding.DataField := 'tur';
        Bekle(100);

        Dene('stok TcxDBComboBox (AutoEdit=True)', LStok, 'tur');
        Dene('TRadDBComboBox (AutoEdit=True)', LRadDb, 'ad');

        LDS.AutoEdit := False;
        Dene('stok TcxDBComboBox (AutoEdit=False)', LStok, 'tur', True);
        Dene('TRadDBComboBox (AutoEdit=False)', LRadDb, 'ad', True);

        LRadDb.Properties.AEditOnPopup := True;
        Dene('TRadDBComboBox (AutoEdit=False, AEditOnPopup=True)', LRadDb, 'ad');
        LRadDb.Properties.AEditOnPopup := False;
        Dene('TRadDBLookupComboBox (AutoEdit=False)', LLook, 'tur', True);
        LLook.Properties.AEditOnPopup := True;
        Dene('TRadDBLookupComboBox (AutoEdit=False, AEditOnPopup=True)', LLook, 'tur');
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
    if (LCon <> nil) and LCon.Connected then
      begin
        Calistir(LCon, 'drop table if exists rad_test_combo');
        Calistir(LCon, 'drop table if exists rad_test_tur');
      end;
    LCon.Free;
    LOlay.Gunluk.Free;
    LOlay.Free;
  end;
  if GHata > 0 then Halt(1);
end.
