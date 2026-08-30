program LookupRegistryTest;

(*
  rad.lookup kayit defteri - CANLI veritabaniyla ucтan uca.

    A) Tanimlar gercek bir tablodan yukleniyor mu?
    B) Zincir cozumu: ILCE -> [ULKE, SEHIR, ILCE]
    C) Validate gercek yapilandirma hatalarini yakaliyor mu?
       (var olmayan ust, dongu, SQL'de olmayan parametre, bildirilmemis parametre)
    D) SQL parametre ayristirici PostgreSQL cast'ini (::text) parametre
       sanmiyor, tirnak icindekini de saymiyor
    E) LookupCode bir editore uygulaninca ayarlar tanimdan geliyor mu?
    F) Uctan uca: kod ile kurulmus zincir gercek SQL calistiriyor mu?

  ! Kimlik bilgisi kaynak koda yazilmaz - %LOCALAPPDATA%\rad\test-db.env
  ! Yalnizca rad_test_* tablolari; sonunda silinir.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, System.IOUtils,
  Winapi.Windows, Vcl.Forms, Vcl.Controls, Data.DB,
  Uni, UniProvider, PostgreSQLUniProvider,
  cxEdit, cxTextEdit, cxMaskEdit, cxDropDownEdit, cxLookupEdit, cxDBLookupEdit,
  cxDBLookupComboBox, cxGraphics, cxControls, cxLookAndFeels, cxContainer,
  cxClasses,
  rad.lookup, Rad.Dev;

type
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
    QSehir: TUniQuery;
    SqlSayaci: Integer;
    procedure Kaskad(Sender: TRadLookupComboBoxProperties;
      ASource, ATarget: TComponent; const AValue: Variant);
  end;

procedure TSenaryo.Kaskad(Sender: TRadLookupComboBoxProperties;
  ASource, ATarget: TComponent; const AValue: Variant);
var
  LDef: TRadLookupDef;
  LHedef: TRadLookupComboBoxProperties;
begin
  { HEDEFIN tanimini kullaniyoruz: sorguyu ve ust parametresinin adini o bilir. }
  if not (ATarget is TRadLookupComboBox) then
    Exit;
  LHedef := TRadLookupComboBox(ATarget).ActiveProperties;
  LDef := LHedef.LookupDef;
  if (LDef = nil) or (LDef.ParentParam = '') then
    Exit;

  Inc(SqlSayaci);
  QSehir.Close;
  QSehir.SQL.Text := LDef.SQL;
  QSehir.ParamByName(LDef.ParentParam).AsInteger := AValue;
  if LDef.SearchParam <> '' then
    QSehir.ParamByName(LDef.SearchParam).AsString := '%';
  QSehir.Open;
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

function Kisalt(const S: string; N: Integer): string;
begin
  Result := StringReplace(Trim(S), #13#10, ' ', [rfReplaceAll]);
  if Length(Result) > N then
    Result := Copy(Result, 1, N) + '...';
end;

var
  LCfg: TCfg;
  LS: TSenaryo;
  LForm: TForm;
  LQDef: TUniQuery;
  LReg: TRadLookupRegistry;
  LZincir: TArray<string>;
  LHata: string;
  LDef: TRadLookupDef;
  LUlke, LSehir: TRadLookupComboBox;
  LDsSehir: TDataSource;
  i: Integer;
  LParams: TArray<string>;

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

      { ── Veri ──────────────────────────────────────────────────────── }
      Calistir(LS.Con, 'drop table if exists rad_test_sehir');
      Calistir(LS.Con, 'drop table if exists rad_test_ulke');
      Calistir(LS.Con, 'drop table if exists rad_test_lookup');
      Calistir(LS.Con,
        'create table rad_test_ulke (id integer primary key, ad varchar(60))');
      Calistir(LS.Con,
        'create table rad_test_sehir (id integer primary key, ad varchar(60), ulke_id integer)');
      Calistir(LS.Con,
        'insert into rad_test_ulke values (1,''Turkiye''),(2,''Almanya''),(3,''Fransa'')');
      Calistir(LS.Con,
        'insert into rad_test_sehir values (10,''Istanbul'',1),(11,''Ankara'',1),' +
        '(12,''Izmir'',1),(20,''Berlin'',2),(21,''Munih'',2),(30,''Paris'',3)');

      Calistir(LS.Con,
        'create table rad_test_lookup (' +
        '  kod varchar(40) primary key, baslik varchar(80), sql_metni text,' +
        '  anahtar_alan varchar(40), liste_alan varchar(40), arama_param varchar(40),' +
        '  ust_kod varchar(40), ust_param varchar(40), tekil_param varchar(40),' +
        '  min_arama integer default 0, arama_gecikme integer default 0)');
      Calistir(LS.Con,
        'insert into rad_test_lookup values (' +
        '''ULKE'', ''Ulke'',' +
        '''select id, ad from rad_test_ulke where ad ilike :arama order by ad'',' +
        '''id'', ''ad'', ''arama'', null, null, null, 2, 300)');
      Calistir(LS.Con,
        'insert into rad_test_lookup values (' +
        '''SEHIR'', ''Sehir'',' +
        '''select id, ad from rad_test_sehir where ulke_id = :ulke_id and ad ilike :arama order by ad'',' +
        '''id'', ''ad'', ''arama'', ''ULKE'', ''ulke_id'', null, 0, 250)');
      Calistir(LS.Con,
        'insert into rad_test_lookup values (' +
        '''ILCE'', ''Ilce'',' +
        '''select id, ad from rad_test_ilce where sehir_id = :sehir_id'',' +
        '''id'', ''ad'', null, ''SEHIR'', ''sehir_id'', null, 0, 0)');
      Writeln('rad_test_lookup: 3 tanim yazildi.');
      Writeln;

      Application.Initialize;
      LForm := TForm.CreateNew(nil);
      LForm.Width := 640; LForm.Height := 300;

      { ══ A) Tablodan yukleme ═══════════════════════════════════════ }
      Writeln('=== A) Tanimlar tablodan yukleniyor ===');
      LReg := LookupRegistry;
      LReg.Clear;
      LQDef := TUniQuery.Create(LForm);
      LQDef.Connection := LS.Con;
      LQDef.SQL.Text := 'select * from rad_test_lookup order by kod';
      LQDef.Open;
      LReg.LoadFromDataSet(LQDef);
      LQDef.Close;
      Writeln('  yuklenen tanim : ', LReg.Defs.Count, ' (3 bekleniyor)');
      for i := 0 to LReg.Defs.Count - 1 do
        Writeln(Format('    %-6s ust=%-6s anahtar=%-4s liste=%-4s min=%d gecikme=%d',
          [LReg.Defs[i].Code, LReg.Defs[i].ParentCode, LReg.Defs[i].KeyField,
           LReg.Defs[i].ListField, LReg.Defs[i].MinSearchLength,
           LReg.Defs[i].SearchDelay]));

      { ══ B) Zincir ═════════════════════════════════════════════════ }
      Writeln;
      Writeln('=== B) Zincir cozumu ===');
      LZincir := LReg.Chain('ILCE');
      Writeln('  Chain(ILCE)      : ', string.Join(' -> ', LZincir),
        '   (ULKE -> SEHIR -> ILCE bekleniyor)');
      Writeln('  ChildrenOf(ULKE) : ', string.Join(', ', LReg.ChildrenOf('ULKE')));

      { ══ C) Validate ═══════════════════════════════════════════════ }
      Writeln;
      Writeln('=== C) Validate ===');
      LHata := LReg.Validate;
      Writeln('  saglam yapilandirma -> "', Trim(LHata), '"  (bos bekleniyor)');

      { var olmayan ust }
      LDef := LReg.Defs.Add;
      LDef.Code := 'BOZUK1';
      LDef.SQL := 'select id, ad from x where ust = :u';
      LDef.KeyField := 'id'; LDef.ListField := 'ad';
      LDef.ParentCode := 'OLMAYAN'; LDef.ParentParam := 'u';
      { dongu }
      LDef := LReg.Defs.Add;
      LDef.Code := 'DONGU_A';
      LDef.SQL := 'select id, ad from a where b = :b';
      LDef.KeyField := 'id'; LDef.ListField := 'ad';
      LDef.ParentCode := 'DONGU_B'; LDef.ParentParam := 'b';
      LDef := LReg.Defs.Add;
      LDef.Code := 'DONGU_B';
      LDef.SQL := 'select id, ad from b where a = :a';
      LDef.KeyField := 'id'; LDef.ListField := 'ad';
      LDef.ParentCode := 'DONGU_A'; LDef.ParentParam := 'a';
      { SQL'de olmayan parametre + bildirilmemis parametre }
      LDef := LReg.Defs.Add;
      LDef.Code := 'BOZUK2';
      LDef.SQL := 'select id, ad from y where kod = :baska';
      LDef.KeyField := 'id'; LDef.ListField := 'ad';
      LDef.SearchParam := 'arama';

      LHata := LReg.Validate;
      Writeln('  bozuk yapilandirma -> ', Length(LHata.Split([#10])) - 1, ' bulgu:');
      for var L in LHata.Split([#13#10]) do
        if Trim(L) <> '' then
          Writeln('    - ', Kisalt(L, 100));

      { ══ D) Parametre ayristirici ══════════════════════════════════ }
      Writeln;
      Writeln('=== D) SQL parametre ayristirici ===');
      LDef := LReg.Defs.Add;
      LDef.Code := 'PARSE';
      LDef.SQL := 'select a::text, b from t where x = :gercek ' +
                  'and y = '':tirnakta'' and z = w::integer and q = :ikinci';
      LParams := LDef.SqlParams;
      Writeln('  bulunan parametreler: [', string.Join(', ', LParams), ']');
      Writeln('    (gercek, ikinci bekleniyor - ::text ve ::integer cast, ' +
              ''':tirnakta'' metin)');

      { temizle, gercek uc tanima geri don }
      LReg.Clear;
      LQDef.Open; LReg.LoadFromDataSet(LQDef); LQDef.Close;

      { ══ E) LookupCode editore uygulaniyor mu? ═════════════════════ }
      Writeln;
      Writeln('=== E) LookupCode -> editor ayarlari ===');
      LSehir := TRadLookupComboBox.Create(LForm);
      LSehir.Name := 'Sehir'; LSehir.Parent := LForm;
      LSehir.Properties.LookupCode := 'SEHIR';
      Writeln('  LookupDef cozuldu mu : ', BoolToStr(LSehir.Properties.LookupDef <> nil, True));
      Writeln('  KeyFieldNames        : "', LSehir.Properties.KeyFieldNames, '"  (id)');
      Writeln('  ListFieldNames       : "', LSehir.Properties.ListFieldNames, '"  (ad)');
      Writeln('  SearchDelay          : ', LSehir.Properties.SearchDelay, '  (250)');
      Writeln('  CascadeField         : "', LSehir.Properties.CascadeField, '"  (ulke_id)');
      Writeln('  bilinmeyen kod sessiz mi:');
      LSehir.Properties.LookupCode := 'YOK_BOYLE_BIRSEY';
      Writeln('    LookupDef = nil    : ',
        BoolToStr(LSehir.Properties.LookupDef = nil, True), '  (istisna atmadi)');
      LSehir.Properties.LookupCode := 'SEHIR';

      { ══ F) Uctan uca ══════════════════════════════════════════════ }
      Writeln;
      Writeln('=== F) Uctan uca: kod ile kurulmus zincir gercek SQL calistiriyor mu? ===');
      LS.QSehir := TUniQuery.Create(LForm);
      LS.QSehir.Connection := LS.Con;
      LDsSehir := TDataSource.Create(LForm);
      LDsSehir.DataSet := LS.QSehir;
      LSehir.Properties.ListSource := LDsSehir;

      LUlke := TRadLookupComboBox.Create(LForm);
      LUlke.Name := 'Ulke'; LUlke.Parent := LForm;
      LUlke.Properties.LookupCode := 'ULKE';
      LUlke.Properties.AComponent1 := LSehir;
      LUlke.Properties.OnCascade := LS.Kaskad;

      Writeln('  Ulke MinSearchLength : ', LUlke.Properties.MinSearchLength, '  (2)');
      LS.SqlSayaci := 0;
      LUlke.EditValue := 1;
      Writeln('  Ulke=1 -> sorgu ', LS.SqlSayaci, ' kez, sehir listesi ',
        LS.QSehir.RecordCount, ' satir  (3 bekleniyor)');
      LUlke.EditValue := 2;
      Writeln('  Ulke=2 -> sehir listesi ', LS.QSehir.RecordCount, ' satir  (2 bekleniyor)');
      LUlke.EditValue := 3;
      Writeln('  Ulke=3 -> sehir listesi ', LS.QSehir.RecordCount, ' satir  (1 bekleniyor)');

      LForm.Free;
    except
      on E: Exception do
        Writeln('HATA: ', E.ClassName, ': ', E.Message);
    end;
  finally
    try
      if (LS.Con <> nil) and LS.Con.Connected then
      begin
        Calistir(LS.Con, 'drop table if exists rad_test_lookup');
        Calistir(LS.Con, 'drop table if exists rad_test_sehir');
        Calistir(LS.Con, 'drop table if exists rad_test_ulke');
        Writeln;
        Writeln('Temizlik: rad_test_* tablolari silindi.');
        LS.Con.Disconnect;
      end;
    except
      on E: Exception do Writeln('TEMIZLIK HATASI: ', E.Message);
    end;
    LS.Con.Free;
    LS.Free;
  end;
end.
