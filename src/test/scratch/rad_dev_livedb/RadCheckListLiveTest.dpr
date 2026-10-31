program RadCheckListLiveTest;

(*
  CANLI VERITABANI - TRadDBCheckListBox: 'Ad=Deger' item'lari, kayda yazma ve
  AValuesIn filtresinin gercek SQL'de calismasi.

  ! KIMLIK BILGISI KAYNAK KODA YAZILMAZ: %LOCALAPPDATA%\rad\test-db.env ya da
    RAD_PG_* ortam degiskenleri.
  ! SADECE rad_test_* tablosu olusturulur; testin sonunda silinir.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, System.IOUtils,
  Winapi.Windows, Winapi.Messages, Vcl.Forms, Vcl.Controls, Data.DB,
  Uni, UniProvider, PostgreSQLUniProvider,
  cxEdit, cxCheckBox, cxCheckListBox, cxDBCheckListBox, cxLookAndFeelPainters,
  cxGraphics, cxControls, cxLookAndFeels, cxContainer, cxClasses,
  Rad.Dev;

type
  TCfg = record Host, Port, Db, User, Pass: string; end;

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

function Sayi(ACon: TUniConnection; const ASql: string): Integer;
var
  LQ: TUniQuery;
begin
  LQ := TUniQuery.Create(nil);
  try
    LQ.Connection := ACon;
    LQ.SQL.Text := ASql;
    LQ.Open;
    Result := LQ.Fields[0].AsInteger;
  finally
    LQ.Free;
  end;
end;

type
  TListHack = class(TcxCustomCheckListBox);

{ Stok (golgelenen) Items: State burada. }
function Durum(AList: TcxCustomCheckListBox; AIndex: Integer): TcxCheckBoxState;
begin
  Result := TListHack(AList).Items[AIndex].State;
end;

procedure Tikla(AList: TcxCustomCheckListBox; AIndex: Integer);
var
  LR: TRect;
begin
  LR := AList.ItemRect(AIndex);
  AList.SetFocus;
  Bekle(30);
  SendMessage(AList.InnerControl.Handle, WM_LBUTTONDOWN, MK_LBUTTON,
    MakeLong(LR.Left + 6, LR.Top + (LR.Bottom - LR.Top) div 2));
  SendMessage(AList.InnerControl.Handle, WM_LBUTTONUP, 0,
    MakeLong(LR.Left + 6, LR.Top + (LR.Bottom - LR.Top) div 2));
  Bekle(40);
end;

var
  LCfg: TCfg;
  LCon: TUniConnection;
  LQ: TUniQuery;
  LDS: TDataSource;
  LForm: TForm;
  LList: TRadDBCheckListBox;

begin
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
      Writeln('Baglandi: ', LCfg.Host, '/', LCfg.Db);

      Calistir(LCon, 'drop table if exists rad_test_cari');
      Calistir(LCon, 'create table rad_test_cari (id integer primary key, ad varchar(40), ' +
        'tip varchar(20))');
      Calistir(LCon, 'insert into rad_test_cari values (1,''Bir'',''A;S''),(2,''Iki'',''AS''),' +
        '(3,''Uc'',''A''),(4,''Dort'',''S''),(5,''Bes'','''')');

      Application.Initialize;
      LForm := TForm.CreateNew(nil);
      try
        LForm.SetBounds(100, 100, 320, 260);
        LForm.Show;
        Bekle(120);
        LQ := TUniQuery.Create(LForm);
        LQ.Connection := LCon;
        LQ.SQL.Text := 'select id, ad, tip from rad_test_cari order by id';
        LQ.Open;
        LDS := TDataSource.Create(LForm);
        LDS.DataSet := LQ;
        LList := TRadDBCheckListBox.Create(LForm);
        LList.Parent := LForm;
        LList.SetBounds(10, 10, 220, 130);
        LList.Items.AddItem('Alici', 'A');
        LList.Items.AddItem('Satici', 'S');
        LList.Items.AddItem('Alici ve Satici', 'AS');
        LList.DataBinding.DataSource := LDS;
        LList.DataBinding.DataField := 'tip';
        Bekle(100);

        Writeln;
        Writeln('=== Okuma ===');
        Kontrol('L01 kayit 1 (A;S): Alici ve Satici secili',
          (Durum(LList, 0) = cbsChecked) and (Durum(LList, 1) = cbsChecked) and
          (Durum(LList, 2) = cbsUnchecked), VarToStr(LList.EditValue));
        LQ.Next;
        Bekle(40);
        Kontrol('L02 kayit 2 (AS): yalniz Alici ve Satici',
          (Durum(LList, 2) = cbsChecked) and (Durum(LList, 0) = cbsUnchecked));
        LQ.Last;
        Bekle(40);
        Kontrol('L03 bos kayit: hicbiri secili degil',
          (Durum(LList, 0) = cbsUnchecked) and (Durum(LList, 1) = cbsUnchecked) and
          (Durum(LList, 2) = cbsUnchecked) and not LList.AHasValues);

        Writeln;
        Writeln('=== Yazma ===');
        LQ.First;
        Bekle(40);
        Tikla(LList, 2);
        Kontrol('L04 tiklama kaydi duzenleme moduna alir', LQ.State = dsEdit);
        LQ.Post;
        Kontrol('L05 Post alana yazdi (A;S;AS)', LQ.FieldByName('tip').AsString = 'A;S;AS',
          LQ.FieldByName('tip').AsString);
        Kontrol('L06 veritabanina yazildi',
          Sayi(LCon, 'select count(*) from rad_test_cari where id = 1 and tip = ''A;S;AS''') = 1);

        Writeln;
        Writeln('=== Filtre (AValuesIn gercek SQL''de) ===');
        LList.AValues := ['A'];
        Kontrol('L07 AValuesIn metni', LList.AValuesIn('tip') = 'tip in (''A'')', LList.AValuesIn('tip'));
        Kontrol('L08 filtre gercek sorguda calisir (tam eslesme)',
          Sayi(LCon, 'select count(*) from rad_test_cari where ' + LList.AValuesIn('tip')) = 1);
        LList.AValues := ['A', 'S'];
        Kontrol('L09 iki deger: IN listesi',
          Sayi(LCon, 'select count(*) from rad_test_cari where ' + LList.AValuesIn('tip')) = 2,
          LList.AValuesIn('tip'));
        LList.Items.Clear;
        LList.Items.AddItem('O''Brien', 'O''B');
        LList.AValues := ['O''B'];
        Kontrol('L10 tek tirnakli deger SQL''i bozmaz',
          Sayi(LCon, 'select count(*) from rad_test_cari where ' + LList.AValuesIn('tip')) = 0,
          LList.AValuesIn('tip'));
        Kontrol('L11 FieldWarning: varchar(20) alani, tek deger sigar', LList.FieldWarning = '',
          LList.FieldWarning);
        LList.Items.Clear;
        LList.Items.AddItem('Alici', 'AAAAAAAAAA');
        LList.Items.AddItem('Satici', 'SSSSSSSSSS');
        LList.Items.AddItem('Diger', 'DDDDDDDDDD');
        Kontrol('L12 FieldWarning: tum degerler alana sigmiyorsa bildirir',
          Pos('karakter', LList.FieldWarning) > 0, LList.FieldWarning);
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
      Calistir(LCon, 'drop table if exists rad_test_cari');
      Writeln('rad_test_cari silindi.');
    end;
    LCon.Free;
  end;
  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    Halt(1);
end.
