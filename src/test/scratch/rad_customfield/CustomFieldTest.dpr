program CustomFieldTest;

(* rad.customfield cekirdek testleri: baglantisiz. DDL metni, kolon adi uretimi,
   tip kodlari, secenek metni, varsayilan cevirisi, coklu secim bicimi. *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Variants, System.DateUtils,
  rad.sqlfilter, rad.customfield;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;

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

procedure Esit(const AAd, ABeklenen, AGercek: string);
begin
  Kontrol(AAd, ABeklenen = AGercek, 'beklenen=[' + ABeklenen + '] gercek=[' + AGercek + ']');
end;

procedure Firlatir(const AAd: string; AProc: TProc);
begin
  try
    AProc;
    Kontrol(AAd, False, 'istisna firlatilmadi');
  except
    on E: ERadCustomField do Kontrol(AAd, True);
    on E: Exception do Kontrol(AAd, False, E.ClassName + ': ' + E.Message);
  end;
end;

function Alan(AType: TRadCustomFieldType; ALen: Integer = 50; ADec: Integer = 2): TRadCustomFieldDef;
begin
  Result := TRadCustomFieldDef.Create;
  Result.TableName := 'cari';
  Result.ColumnName := 'ozel_3';
  Result.Caption := 'Test';
  Result.FieldType := AType;
  Result.Length := ALen;
  Result.Decimals := ADec;
end;

procedure TipTestleri;
var
  T: TRadCustomFieldType;
  D: TRadCustomFieldDef;
begin
  for T := Low(T) to High(T) do
    Kontrol('T01 tip kodu gidis-donus ' + TRadCustomFieldDef.TypeCodeOf(T),
      TRadCustomFieldDef.TypeOfCode(TRadCustomFieldDef.TypeCodeOf(T)) = T);
  Firlatir('T02 bilinmeyen tip kodu', procedure begin TRadCustomFieldDef.TypeOfCode('xyz'); end);
  D := Alan(cfText, 80);
  try
    Esit('T03 PG varchar', 'varchar(80)', TRadCustomFieldDdl.ColumnType(sdPostgreSQL, D));
    Esit('T04 MSSQL nvarchar', 'nvarchar(80)', TRadCustomFieldDdl.ColumnType(sdMSSQL, D));
    Esit('T05 FB varchar', 'varchar(80)', TRadCustomFieldDdl.ColumnType(sdFirebird, D));
    Esit('T06 MySQL varchar', 'varchar(80)', TRadCustomFieldDdl.ColumnType(sdMySQL, D));
  finally
    D.Free;
  end;
  D := Alan(cfMoney);
  try
    Esit('T07 para PG', 'numeric(18,4)', TRadCustomFieldDdl.ColumnType(sdPostgreSQL, D));
    Esit('T08 para MySQL', 'decimal(18,4)', TRadCustomFieldDdl.ColumnType(sdMySQL, D));
  finally
    D.Free;
  end;
  D := Alan(cfDecimal, 50, 3);
  try
    Esit('T09 ondalik', 'numeric(18,3)', TRadCustomFieldDdl.ColumnType(sdMSSQL, D));
  finally
    D.Free;
  end;
  D := Alan(cfBoolean);
  try
    Esit('T10 bool MSSQL', 'bit', TRadCustomFieldDdl.ColumnType(sdMSSQL, D));
    Esit('T11 bool MySQL', 'tinyint(1)', TRadCustomFieldDdl.ColumnType(sdMySQL, D));
    Esit('T12 bool FB', 'boolean', TRadCustomFieldDdl.ColumnType(sdFirebird, D));
  finally
    D.Free;
  end;
  D := Alan(cfMemo);
  try
    Esit('T13 memo FB', 'blob sub_type text', TRadCustomFieldDdl.ColumnType(sdFirebird, D));
    Esit('T14 memo MSSQL', 'nvarchar(max)', TRadCustomFieldDdl.ColumnType(sdMSSQL, D));
  finally
    D.Free;
  end;
  D := Alan(cfDateTime);
  try
    Esit('T15 tarihsaat MSSQL', 'datetime2', TRadCustomFieldDdl.ColumnType(sdMSSQL, D));
    Esit('T16 tarihsaat MySQL', 'datetime', TRadCustomFieldDdl.ColumnType(sdMySQL, D));
  finally
    D.Free;
  end;
  D := Alan(cfMultiChoice);
  try
    Esit('T17 coklu', 'varchar(500)', TRadCustomFieldDdl.ColumnType(sdPostgreSQL, D));
  finally
    D.Free;
  end;
end;

procedure DdlTestleri;
var
  D: TRadCustomFieldDef;
begin
  D := Alan(cfText, 50);
  try
    Esit('D01 add PG', 'alter table cari add column ozel_3 varchar(50)', TRadCustomFieldDdl.AddColumn(sdPostgreSQL, 'cari', D));
    Esit('D02 add MSSQL', 'alter table cari add ozel_3 nvarchar(50) null', TRadCustomFieldDdl.AddColumn(sdMSSQL, 'cari', D));
    Esit('D03 add FB', 'alter table cari add ozel_3 varchar(50)', TRadCustomFieldDdl.AddColumn(sdFirebird, 'cari', D));
    Esit('D04 add MySQL', 'alter table cari add column ozel_3 varchar(50)', TRadCustomFieldDdl.AddColumn(sdMySQL, 'cari', D));
    Esit('D05 alter len PG', 'alter table cari alter column ozel_3 type varchar(100)',
      TRadCustomFieldDdl.AlterLength(sdPostgreSQL, 'cari', D, 100));
    Esit('D06 alter len MSSQL', 'alter table cari alter column ozel_3 nvarchar(100) null',
      TRadCustomFieldDdl.AlterLength(sdMSSQL, 'cari', D, 100));
    Esit('D07 alter len FB', 'alter table cari alter column ozel_3 type varchar(100)',
      TRadCustomFieldDdl.AlterLength(sdFirebird, 'cari', D, 100));
    Esit('D08 alter len MySQL', 'alter table cari modify column ozel_3 varchar(100) null',
      TRadCustomFieldDdl.AlterLength(sdMySQL, 'cari', D, 100));
    Kontrol('D09 alter len kaynagi degismez', D.Length = 50);
    Firlatir('D10 kucultme hata', procedure begin TRadCustomFieldDdl.AlterLength(sdPostgreSQL, 'cari', D, 50); end);
  finally
    D.Free;
  end;
  D := Alan(cfInteger);
  try
    Firlatir('D11 tamsayida uzunluk hata', procedure begin TRadCustomFieldDdl.AlterLength(sdPostgreSQL, 'cari', D, 100); end);
  finally
    D.Free;
  end;
  Kontrol('D12 kolon var PG', Pos('INFORMATION_SCHEMA.COLUMNS', TRadCustomFieldDdl.ColumnExistsSql(sdPostgreSQL)) > 0);
  Kontrol('D13 kolon var FB', Pos('rdb$relation_fields', TRadCustomFieldDdl.ColumnExistsSql(sdFirebird)) > 0);
  Esit('D14 katalog adi FB buyuk', 'CARI', TRadCustomFieldDdl.CatalogName(sdFirebird, 'cari'));
  Esit('D15 katalog adi sema ayrilir', 'cari', TRadCustomFieldDdl.CatalogName(sdPostgreSQL, 'public.cari'));
  Kontrol('D16 tanim tablolari 3 adet', Length(TRadCustomFieldDdl.CreateDefinitionTables(sdPostgreSQL)) = 3);
  Kontrol('D17 tanim tablosu MSSQL identity', Pos('identity(1,1)', TRadCustomFieldDdl.CreateDefinitionTables(sdMSSQL)[0]) > 0);
  Kontrol('D18 tanim tablosu FB blob', Pos('duzen blob', TRadCustomFieldDdl.CreateDefinitionTables(sdFirebird)[2]) > 0);
  Kontrol('D19 unique isimleri tabloya gore', Pos('uq_ozel_alan_grup', TRadCustomFieldDdl.CreateDefinitionTables(sdPostgreSQL)[0]) > 0);
  Kontrol('D20 FK grup', Pos('references ozel_alan_grup (id)', TRadCustomFieldDdl.CreateDefinitionTables(sdPostgreSQL)[1]) > 0);
end;

procedure AdTestleri;
begin
  Esit('A01 kolon adi', 'ozel_7', TRadCustomFieldDdl.ColumnName(7));
  Kontrol('A02 numara', TRadCustomFieldDdl.NumberOf('ozel_12') = 12);
  Kontrol('A03 numara buyuk harf', TRadCustomFieldDdl.NumberOf('OZEL_12') = 12);
  Kontrol('A04 numara desen disi', TRadCustomFieldDdl.NumberOf('adi') = 0);
  Kontrol('A05 numara bozuk', TRadCustomFieldDdl.NumberOf('ozel_x') = 0);
  Kontrol('A06 sonraki bos', TRadCustomFieldDdl.NextNumber([]) = 1);
  Kontrol('A07 sonraki', TRadCustomFieldDdl.NextNumber(['ozel_1', 'ozel_5', 'ozel_3', 'adi']) = 6);
  Kontrol('A08 tablo adi gecerli', TRadCustomFieldDdl.IsValidTableName('cari'));
  Kontrol('A09 tablo adi semali', TRadCustomFieldDdl.IsValidTableName('public.cari'));
  Kontrol('A10 tablo adi bosluk', not TRadCustomFieldDdl.IsValidTableName('cari x'));
  Kontrol('A11 tablo adi enjeksiyon', not TRadCustomFieldDdl.IsValidTableName('cari; drop table x'));
  Kontrol('A12 tablo adi bos', not TRadCustomFieldDdl.IsValidTableName(''));
  Kontrol('A13 tablo adi rakamla baslamaz', not TRadCustomFieldDdl.IsValidTableName('1cari'));
end;

procedure SecenekTestleri;
var
  D: TRadCustomFieldDef;
begin
  D := Alan(cfMultiChoice);
  try
    D.SetOptionsText('a|Aktif'#13#10'p|Pasif'#13#10#13#10'x');
    Kontrol('S01 secenek sayisi', Length(D.Options) = 3);
    Esit('S02 kod', 'p', D.Options[1].Code);
    Esit('S03 baslik', 'Pasif', D.Options[1].Caption);
    Esit('S04 basliksiz = kod', 'x', D.Options[2].Caption);
    Esit('S05 metin gidis-donus', 'a|Aktif'#13#10'p|Pasif'#13#10'x|x', D.OptionsText);
    Esit('S06 baslik bul', 'Aktif', D.OptionCaption('a'));
    Esit('S07 bilinmeyen kod oldugu gibi', 'q', D.OptionCaption('q'));
    Esit('S08 gecerli', '', D.Validate);
    D.SetOptionsText('');
    Kontrol('S09 bos liste gecersiz', D.Validate <> '');
    D.Caption := '';
    D.SetOptionsText('a|A');
    Kontrol('S10 bos baslik gecersiz', D.Validate <> '');
  finally
    D.Free;
  end;
  Esit('S11 join', '|a|b|', TRadMultiChoice.Join(['a', 'b']));
  Esit('S12 join bos', '', TRadMultiChoice.Join([]));
  Esit('S13 join gecersiz atlanir', '|a|', TRadMultiChoice.Join(['a', '', 'x|y']));
  Kontrol('S14 split', Length(TRadMultiChoice.Split('|a|b|')) = 2);
  Kontrol('S15 split bos', Length(TRadMultiChoice.Split('')) = 0);
  Esit('S16 wrap', '|a|', TRadMultiChoice.Wrap('a'));
  Kontrol('S17 has', TRadMultiChoice.Has('|a|ab|', 'ab'));
  Kontrol('S18 has kismi eslesmez', not TRadMultiChoice.Has('|ab|', 'a'));
  Kontrol('S19 gecersiz kod', not TRadMultiChoice.IsValidCode('a|b'));
  Kontrol('S20 gecersiz bos kod', not TRadMultiChoice.IsValidCode('  '));
end;

procedure VarsayilanTestleri;
var
  D: TRadCustomFieldDef;
begin
  D := Alan(cfInteger);
  try
    Kontrol('V01 bos = Null', VarIsNull(D.DefaultAsVariant));
    D.DefaultValue := '42';
    Kontrol('V02 tamsayi', D.DefaultAsVariant = 42);
    D.DefaultValue := 'abc';
    Kontrol('V03 tamsayi bozuk gecersiz', D.Validate <> '');
    D.FieldType := cfMoney;
    D.DefaultValue := '12,5';
    Kontrol('V04 para virgul', Abs(Double(D.DefaultAsVariant) - 12.5) < 1e-9);
    D.DefaultValue := '12.5';
    Kontrol('V05 para nokta', Abs(Double(D.DefaultAsVariant) - 12.5) < 1e-9);
    D.FieldType := cfBoolean;
    D.DefaultValue := 'evet';
    Kontrol('V06 bool evet', D.DefaultAsVariant = True);
    D.DefaultValue := '0';
    Kontrol('V07 bool 0', D.DefaultAsVariant = False);
    D.FieldType := cfDate;
    D.DefaultValue := '2026-01-20';
    Kontrol('V08 tarih ISO', VarToDateTime(D.DefaultAsVariant) = EncodeDate(2026, 1, 20));
    D.FieldType := cfText;
    D.DefaultValue := ' x ';
    Kontrol('V09 metin kirpilir', D.DefaultAsVariant = 'x');
  finally
    D.Free;
  end;
end;

procedure GrupTestleri;
var
  G: TRadCustomFieldGroupDef;
  D: TRadCustomFieldDef;
begin
  G := TRadCustomFieldGroupDef.Create;
  try
    D := Alan(cfText); G.Fields.Add(D);
    D := Alan(cfText); D.Active := False; G.Fields.Add(D);
    Kontrol('G01 aktif alanlar', Length(G.ActiveFields) = 1);
    D := G.Fields[0].Clone;
    try
      Kontrol('G02 klon', (D.Caption = 'Test') and (D.ColumnName = 'ozel_3'));
    finally
      D.Free;
    end;
  finally
    G.Free;
  end;
end;

begin
  try
    TipTestleri;
    DdlTestleri;
    AdTestleri;
    SecenekTestleri;
    VarsayilanTestleri;
    GrupTestleri;
  except
    on E: Exception do
    begin
      Inc(GHata);
      Writeln('  [PATLADI] ', E.ClassName, ': ', E.Message);
    end;
  end;
  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    Halt(1);
end.
