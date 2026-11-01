program ScriptModelTest;

(* rad.script saf model testi: dogrulama, tur kodlari, DDL metni, .radpaket gidis-donus. DB yok. *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils,
  mormot.core.base,
  rad.sqlfilter, rad.date, rad.script;

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

procedure Firlatir(const AAd: string; AClass: ExceptClass; AProc: TProc);
begin
  try
    AProc;
    Kontrol(AAd, False, 'istisna firlatilmadi');
  except
    on E: Exception do Kontrol(AAd, E is AClass, E.ClassName + ': ' + E.Message);
  end;
end;

function OrnekPaket: TRadScriptPackage;
var
  B: TBytes;
  i: Integer;
begin
  Result := TRadScriptPackage.Create;
  Result.Code := 'firma.kasa-kontrol';
  Result.Name := 'Kasa kontrolleri';
  Result.Description := 'Şube kodu zorunlu, log';
  Result.Version := '1.2.0';
  Result.Author := 'test';
  Result.IsProtected := True;
  Result.Order := 5;
  Result.AddScript('KasaKontrol', skForm, 'Tkasa_k',
    'function btnKaydet_Before(Sender: TObject): Boolean;'#13#10'begin Result := True; end;').Name := 'Kasa kaydet kontrolü ğüşİ';
  Result.AddScript('Sabah', skSchedule, '0 0 8 * * ?', 'procedure Calistir(Olay: TRadEvent); begin end;').Active := False;
  Result.AddScript('Gelen', skEvent, 'efatura.gelen', 'procedure Calistir(Olay: TRadEvent); begin end;');
  Result.AddScript('KurGuncelle', skCommand, 'Tkasa_modul', 'procedure KurGuncelle_Execute(Sender: TObject); begin end;');
  Result.AddScript('Yardimci', skLibrary, '', 'function Topla(a, b: Integer): Integer; begin Result := a + b; end;');
  Result.AddParam('MailAdresi', 'muhasebe@firma.com').Description := 'Uyarı adresi';
  Result.AddDbStep(1, 'create table kasa_log (id integer, kasa_id varchar(36))').Description := 'log tablosu';
  Result.AddDbStep(2, 'create index ix_kasa_log on kasa_log (kasa_id)');
  SetLength(B, 300);
  for i := 0 to High(B) do B[i] := Byte(i * 7);
  Result.AddResource('kur.dfm', B);
  Result.AddResource('bos.txt', nil);
end;

procedure ModelTestleri;
var
  S: TRadScript;
  K: TRadScriptKind;
  P: TRadScriptPackage;
begin
  Writeln('--- M: model');
  Kontrol('M01 tur kodlari', (TRadScript.KindCodeOf(skForm) = 'form') and (TRadScript.KindCodeOf(skLibrary) = 'kutuphane'));
  Kontrol('M02 KindOfCode', TRadScript.KindOfCode('ZAMAN', K) and (K = skSchedule) and not TRadScript.KindOfCode('x', K));
  Kontrol('M03 tanimlayici', TRadScript.IsValidIdentifier('btn_Kaydet1') and not TRadScript.IsValidIdentifier('1abc') and
    not TRadScript.IsValidIdentifier('a b') and not TRadScript.IsValidIdentifier('şube') and not TRadScript.IsValidIdentifier(''));
  Kontrol('M04 paket kodu', TRadScriptPackage.IsValidCode('firma.kasa-kontrol') and TRadScriptPackage.IsValidCode('a1') and
    not TRadScriptPackage.IsValidCode('A') and not TRadScriptPackage.IsValidCode('.ab') and
    not TRadScriptPackage.IsValidCode('Firma') and not TRadScriptPackage.IsValidCode('a b'));
  S := TRadScript.Create;
  try
    Kontrol('M05 bos script gecersiz', S.Validate <> '');
    S.Code := 'X'; S.Name := 'x'; S.Source := 'begin end;'; S.Kind := skForm; S.Target := 'Tkasa_k';
    Kontrol('M06 form gecerli', S.Validate = '', S.Validate);
    S.Target := '9x';
    Kontrol('M07 form hedef gecersiz', S.Validate <> '');
    S.Kind := skSchedule; S.Target := '0 0 8 * * ?';
    Kontrol('M08 zaman gecerli', S.Validate = '', S.Validate);
    S.Target := '60 * *';
    Kontrol('M09 zaman gecersiz', S.Validate <> '');
    S.Kind := skLibrary; S.Target := 'x';
    Kontrol('M10 kutuphane hedef dolu gecersiz', S.Validate <> '');
    S.Target := '';
    Kontrol('M11 kutuphane gecerli', S.Validate = '');
    S.Kind := skEvent;
    Kontrol('M12 olay bos hedef gecersiz', S.Validate <> '');
  finally
    S.Free;
  end;
  P := OrnekPaket;
  try
    Kontrol('M13 ornek paket gecerli', P.Validate = '', P.Validate);
    Kontrol('M14 ScriptByCode/ParamValue', (P.ScriptByCode('sabah') <> nil) and (P.ParamValue('mailadresi', '-') = 'muhasebe@firma.com') and
      (P.ParamValue('yok', '-') = '-') and (P.ResourceByName('KUR.DFM') <> nil));
    P.AddScript('kasakontrol', skLibrary, '', 'x');
    Kontrol('M15 tekrar script kodu', Pos('tekrar', P.Validate) > 0, P.Validate);
    P.Scripts.Delete(P.Scripts.Count - 1);
    P.AddDbStep(2, 'x');
    Kontrol('M16 tekrar db sirasi', Pos('tekrar', P.Validate) > 0, P.Validate);
    P.DbSteps.Delete(P.DbSteps.Count - 1);
    P.AddResource('alt\kur.dfm', nil);
    Kontrol('M17 yol iceren kaynak adi', Pos('Kaynak', P.Validate) > 0, P.Validate);
    P.Resources.Delete(P.Resources.Count - 1);
    P.AddParam('1x', '');
    Kontrol('M18 parametre adi', Pos('Parametre', P.Validate) > 0, P.Validate);
  finally
    P.Free;
  end;
end;

procedure DdlTestleri;
var
  D: TRadSqlDialect;
  A: TArray<string>;
  i: Integer;
  LOk: Boolean;
begin
  Writeln('--- D: DDL');
  for D := Low(TRadSqlDialect) to High(TRadSqlDialect) do
  begin
    A := TRadScriptDdl.CreateDefinitionTables(D);
    LOk := Length(A) = 5;
    for i := 0 to High(A) do
      LOk := LOk and A[i].StartsWith('create table ' + TRadScriptDdl.TableNames[i] + ' (') and
        (Pos('%', A[i]) = 0) and ((i = 0) or (Pos('references script_paket (id) on delete cascade', A[i]) > 0));
    Kontrol('D01 ' + IntToStr(Ord(D)) + ' bes tablo, FK, bos % yok', LOk, string.Join(' | ', A));
  end;
  A := TRadScriptDdl.CreateDefinitionTables(sdMSSQL);
  Kontrol('D02 MSSQL nvarchar(max)/bit', (Pos('kaynak nvarchar(max) not null', A[1]) > 0) and (Pos('aktif_mi bit default 1', A[0]) > 0));
  A := TRadScriptDdl.CreateDefinitionTables(sdFirebird);
  Kontrol('D03 Firebird blob sub_type text', Pos('sql_metni blob sub_type text not null', A[3]) > 0, A[3]);
end;

procedure DosyaTestleri;
var
  P, Q: TRadScriptPackage;
  J: RawUtf8;
  LPath: string;
  LOk: Boolean;
  i: Integer;
begin
  Writeln('--- F: dosya');
  P := OrnekPaket;
  try
    J := TRadScriptPackageFile.ExportPackage(P);
    Kontrol('F01 JSON basligi', (Pos('"format": 1', string(Utf8ToString(J))) > 0) and (Pos('firma.kasa-kontrol', string(Utf8ToString(J))) > 0), string(Utf8ToString(J)).Substring(0, 80));
    Q := TRadScriptPackageFile.ImportPackage(J);
    try
      LOk := (Q.Code = P.Code) and (Q.Name = P.Name) and (Q.Description = P.Description) and (Q.Version = P.Version) and
        (Q.Author = P.Author) and (Q.IsProtected = P.IsProtected) and (Q.Order = P.Order) and (Q.Active = P.Active) and
        (Q.Scripts.Count = 5) and (Q.Params.Count = 1) and (Q.DbSteps.Count = 2) and (Q.Resources.Count = 2) and (Q.Id = 0);
      for i := 0 to P.Scripts.Count - 1 do
        LOk := LOk and (Q.Scripts[i].Code = P.Scripts[i].Code) and (Q.Scripts[i].Name = P.Scripts[i].Name) and
          (Q.Scripts[i].Kind = P.Scripts[i].Kind) and (Q.Scripts[i].Target = P.Scripts[i].Target) and
          (Q.Scripts[i].Order = P.Scripts[i].Order) and (Q.Scripts[i].Active = P.Scripts[i].Active) and
          (Q.Scripts[i].Source = P.Scripts[i].Source) and (Q.Scripts[i].Id = 0);
      Kontrol('F02 gidis-donus script/paket alanlari (Turkce dahil)', LOk);
      Kontrol('F03 parametre/db', (Q.Params[0].Name = 'MailAdresi') and (Q.Params[0].Description = 'Uyarı adresi') and
        (Q.DbSteps[1].Order = 2) and (Q.DbSteps[0].Description = 'log tablosu') and not Q.DbSteps[0].Applied);
      LOk := (Length(Q.Resources[0].Content) = 300) and (Length(Q.Resources[1].Content) = 0);
      for i := 0 to 299 do LOk := LOk and (Q.Resources[0].Content[i] = Byte(i * 7));
      Kontrol('F04 kaynaklar bayt bayt', LOk);
    finally
      Q.Free;
    end;
    LPath := TPath.Combine(TPath.GetTempPath, P.Code + TRadScriptPackageFile.FileExt);
    TRadScriptPackageFile.SaveToFile(P, LPath);
    Q := TRadScriptPackageFile.LoadFromFile(LPath);
    try
      Kontrol('F05 dosyaya yaz/oku', (Q.Code = P.Code) and (Q.Scripts.Count = 5));
    finally
      Q.Free;
      TFile.Delete(LPath);
    end;
  finally
    P.Free;
  end;
  Firlatir('F06 bozuk JSON', ERadScriptFormat, procedure begin TRadScriptPackageFile.ImportPackage('{bozuk').Free; end);
  Firlatir('F07 format yok', ERadScriptFormat, procedure begin TRadScriptPackageFile.ImportPackage('{"a":1}').Free; end);
  Firlatir('F08 format 2', ERadScriptFormat, procedure begin
    TRadScriptPackageFile.ImportPackage('{"format":2,"paket":{"kod":"a.b","adi":"x","surum":"1"}}').Free; end);
  Firlatir('F09 bilinmeyen tur', ERadScriptFormat, procedure begin
    TRadScriptPackageFile.ImportPackage('{"format":1,"paket":{"kod":"a.b","adi":"x","surum":"1"},' +
      '"scriptler":[{"kod":"S","adi":"s","tur":"x","hedef":"","kaynak":"a"}]}').Free; end);
  Firlatir('F10 gecersiz paket kodu', ERadScriptFormat, procedure begin
    TRadScriptPackageFile.ImportPackage('{"format":1,"paket":{"kod":"Büyük","adi":"x","surum":"1"}}').Free; end);
  Firlatir('F11 gecersiz cron', ERadScriptFormat, procedure begin
    TRadScriptPackageFile.ImportPackage('{"format":1,"paket":{"kod":"a.b","adi":"x","surum":"1"},' +
      '"scriptler":[{"kod":"S","adi":"s","tur":"zaman","hedef":"abc","kaynak":"a"}]}').Free; end);
  Firlatir('F12 bozuk base64', ERadScriptFormat, procedure begin
    TRadScriptPackageFile.ImportPackage('{"format":1,"paket":{"kod":"a.b","adi":"x","surum":"1"},' +
      '"kaynaklar":[{"dosya_adi":"a.dfm","icerik":"!!"}]}').Free; end);
  Firlatir('F13 dizi yerine nesne', ERadScriptFormat, procedure begin
    TRadScriptPackageFile.ImportPackage('[1,2]').Free; end);
end;

begin
  try
    ModelTestleri;
    DdlTestleri;
    DosyaTestleri;
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
