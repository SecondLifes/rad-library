program SettingTest;

(* k.setting - ayar paneli sondasi.

   Modeli olcer, gorsel etkilesimi DEGIL: kayit, anahtar uretimi, JSON agaci,
   varsayilanlar, savunma denetimleri, arama ve gidis-donus. Klavye/fare ile
   duzenleme ayri bir olcum (bkz. docs/olcum-listesi.md) - DevExpress gorunmez
   bir izgarada inplace editor acmiyor. *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Forms,
  Vcl.Controls,
  mormot.core.variants,
  k.setting in '..\..\..\share\k.setting.pas',
  SettingModel in 'SettingModel.pas';

var
  GGecti : Integer = 0;
  GKaldi : Integer = 0;

procedure Ok(const ABaslik: string; ADogru: Boolean; const ADetay: string = '');
begin
  if ADogru then
  begin
    Inc(GGecti);
    Writeln(Format('  [OK]   %s', [ABaslik]));
  end
  else
  begin
    Inc(GKaldi);
    Writeln(Format('  [HATA] %s   %s', [ABaslik, ADetay]));
  end;
end;

procedure Esit(const ABaslik, ABeklenen, AGercek: string);
begin
  Ok(ABaslik, ABeklenen = AGercek,
     Format('beklenen=<%s> gercek=<%s>', [ABeklenen, AGercek]));
end;

/// Bir eylemin belirtilen istisnayi firlatip firlatmadigini olcer.
function Firlatiyor(AProc: TProc; out AMesaj: string): Boolean;
begin
  AMesaj := '';
  try
    AProc;
    Result := False;
  except
    on E: Exception do
    begin
      AMesaj := E.ClassName + ': ' + E.Message;
      Result := E is ERadSetting;
    end;
  end;
end;

// ---------------------------------------------------------------------------

procedure Test01_Slug;
begin
  Writeln('01 - anahtar uretimi (PascalCase -> snake_case)');
  Esit('VadeAsimUyar',  'vade_asim_uyar', SettingSlug('VadeAsimUyar'));
  Esit('Vade',          'vade',           SettingSlug('Vade'));
  Esit('KdvDahil',      'kdv_dahil',      SettingSlug('KdvDahil'));
  Esit('Fatura',        'fatura',         SettingSlug('Fatura'));
  // Turkce harfler ASCII'ye katlanmali; DFM'deki ornek 'fatura.satis...'
  Esit('Satis (TR)',    'satis',          SettingSlug('Sat'#$0131#$015F));
  Esit('Odeme (TR)',    'odeme',          SettingSlug(#$00D6'deme'));
  Esit('Bosluk',        'genel_ayarlar',  SettingSlug('Genel Ayarlar'));
  Writeln;
end;

procedure Test02_KayitVeAnahtar(const S: ISetting);
var
  LItem: TRadSettingItem;
  LIdx : Integer;
  LBul : string;
begin
  Writeln('02 - kayit, kategori agaci, tam anahtar');

  S.Clear
   .AddMenu('Fatura')
     .AddSubMenu('Satis')
       .Register(TSatisAyar);

  Ok('4 ayar kuruldu', S.ItemCount = 4, IntToStr(S.ItemCount));

  LBul := '';
  for LIdx := 0 to S.ItemCount - 1 do
  begin
    LItem := S.Item(LIdx);
    if SameText(LItem.Name, 'VadeAsimUyar') then
      LBul := LItem.Key;
  end;
  // DFM'deki lblID orneginin birebir karsiligi
  Esit('tam anahtar', 'fatura.satis.vade_asim_uyar', LBul);

  Ok('uyari yok', S.Warnings = '', S.Warnings);
  Writeln;
end;

procedure Test03_Varsayilanlar(const S: ISetting);
var
  LItem : TRadSettingItem;
  LIdx  : Integer;
  LVade, LKdv, LUyar, LDepo: Variant;
begin
  Writeln('03 - default direktifi RTTI''den okunuyor mu');

  LVade := Null; LKdv := Null; LUyar := Null; LDepo := Null;
  for LIdx := 0 to S.ItemCount - 1 do
  begin
    LItem := S.Item(LIdx);
    if SameText(LItem.Name, 'Vade')         then LVade := LItem.GetValue;
    if SameText(LItem.Name, 'KdvDahil')     then LKdv  := LItem.GetValue;
    if SameText(LItem.Name, 'VadeAsimUyar') then LUyar := LItem.GetValue;
    if SameText(LItem.Name, 'Depo')         then LDepo := LItem.GetValue;
  end;

  Esit('Vade default 30',            '30',    VarToStr(LVade));
  Esit('KdvDahil default False',     'False', BoolToStr(LKdv,  True));
  Esit('VadeAsimUyar default True',  'True',  BoolToStr(LUyar, True));
  Esit('Depo (default yok) bos',     '',      VarToStr(LDepo));
  Writeln;
end;

procedure Test04_YazVeAgac(const S: ISetting);
var
  LJson: string;
begin
  Writeln('04 - PathDelim: JSON gercekten AGAC mi');

  S.Doc.PathDelim := '.';
  S.Doc.I['fatura.satis.vade'] := 45;
  S.Doc.B['fatura.satis.kdv_dahil'] := True;

  LJson := S.SaveJson;
  Writeln('       ', LJson);

  // Duz anahtar yazilsaydi JSON soyle olurdu: {"fatura.satis.vade":45}
  Ok('duz anahtar YOK',   Pos('"fatura.satis.vade"', LJson) = 0, LJson);
  Ok('fatura dugumu var', Pos('"fatura"', LJson) > 0, LJson);
  Ok('satis dugumu var',  Pos('"satis"',  LJson) > 0, LJson);
  Ok('vade dugumu var',   Pos('"vade"',   LJson) > 0, LJson);

  // Ic ice yazilan deger duz yolla geri okunabilmeli
  Ok('yol ile geri okuma', S.Doc.I['fatura.satis.vade'] = 45,
     VarToStr(S.Doc.I['fatura.satis.vade']));
  Writeln;
end;

procedure Test05_PathDelimYokken;
var
  LDoc: IDocDict;
begin
  Writeln('05 - PathDelim VERILMEZSE ne oluyor (belgelenen varsayilan #0)');
  LDoc := DocDict('{}');
  LDoc.I['a.b.c'] := 7;
  // Varsayilan #0: anahtar DUZ metin olarak yazilir, agac olusmaz.
  Ok('#0 iken anahtar duz kaliyor', Pos('"a.b.c"', Utf8ToString(LDoc.Value^.ToJson)) > 0,
     Utf8ToString(LDoc.Value^.ToJson));
  Writeln('       ', Utf8ToString(LDoc.Value^.ToJson));
  Writeln('       -> bu yuzden AfterConstruction PathDelim''i acikca ayarliyor');
  Writeln;
end;

procedure Test06_AltKategori(const S: ISetting);
var
  LIdx    : Integer;
  LAlis   : Integer;
  LSatis  : Integer;
  LItem   : TRadSettingItem;
begin
  Writeln('06 - ic ice sinif = alt kategori (TSynAutoCreateFields)');

  S.Clear
   .AddMenu('Fatura')
     .Register(TFaturaAyar);

  LAlis  := 0;
  LSatis := 0;
  for LIdx := 0 to S.ItemCount - 1 do
  begin
    LItem := S.Item(LIdx);
    if Pos('fatura.alis.',  LItem.Key) = 1 then Inc(LAlis);
    if Pos('fatura.satis.', LItem.Key) = 1 then Inc(LSatis);
  end;

  Ok('alis alt kategorisi 2 ayar',  LAlis  = 2, IntToStr(LAlis));
  Ok('satis alt kategorisi 4 ayar', LSatis = 4, IntToStr(LSatis));
  Ok('toplam 6',                    S.ItemCount = 6, IntToStr(S.ItemCount));
  Ok('uyari yok', S.Warnings = '', S.Warnings);
  Writeln;
end;

procedure Test07_Savunma(const S: ISetting);
var
  LMsg: string;
begin
  Writeln('07 - savunma denetimleri');

  Ok('cakisan index ERadSetting firlatiyor',
     Firlatiyor(procedure
                begin
                  S.Clear.AddMenu('Test').Register(TCakisanAyar);
                end, LMsg), LMsg);
  Writeln('       ', LMsg);

  Ok('index''siz property ERadSetting firlatiyor',
     Firlatiyor(procedure
                begin
                  S.Clear.AddMenu('Test').Register(TIndeksizAyar);
                end, LMsg), LMsg);
  Writeln('       ', LMsg);

  Ok('AddMenu''suz Register firlatiyor',
     Firlatiyor(procedure
                begin
                  S.Clear.Register(TGenelAyar);
                end, LMsg), LMsg);

  Ok('AddMenu''suz AddSubMenu firlatiyor',
     Firlatiyor(procedure
                begin
                  S.Clear.AddSubMenu('Satis');
                end, LMsg), LMsg);

  Ok('bilinmeyen property suslemesi firlatiyor',
     Firlatiyor(procedure
                begin
                  S.Clear.AddMenu('Fatura').Register(TSatisAyar)
                   .Title('YokBoyleBirSey', 'x');
                end, LMsg), LMsg);
  Writeln('       ', LMsg);
  Writeln;
end;

procedure Test08_Susleme(const S: ISetting);
var
  LIdx : Integer;
  LIt  : TRadSettingItem;
begin
  Writeln('08 - fluent susleme var olan satiri degistiriyor');

  S.Clear
   .AddMenu('Fatura')
     .AddSubMenu('Satis')
       .Register(TSatisAyar)
         .Title('Vade', 'Vade (gun)', 'Musteriye taninan odeme suresi')
         .DefaultValue('Depo', 'MERKEZ')
         .ReadOnly('KdvDahil');

  LIt := nil;
  for LIdx := 0 to S.ItemCount - 1 do
    if SameText(S.Item(LIdx).Name, 'Vade') then
      LIt := S.Item(LIdx);

  Ok('Vade bulundu', LIt <> nil);
  if LIt <> nil then
  begin
    Esit('baslik',        'Vade (gun)', LIt.Title);
    Esit('satir basligi', 'Vade (gun)', LIt.Row.Properties.Caption);
    Esit('yol',           'Fatura > Satis', LIt.Path);
    Ok('aciklama satir hint''ine gitti',
       LIt.Row.Properties.Hint = 'Musteriye taninan odeme suresi',
       LIt.Row.Properties.Hint);
  end;

  LIt := nil;
  for LIdx := 0 to S.ItemCount - 1 do
    if SameText(S.Item(LIdx).Name, 'Depo') then
      LIt := S.Item(LIdx);
  Ok('DefaultValue okunuyor', (LIt <> nil) and (VarToStr(LIt.GetValue) = 'MERKEZ'),
     VarToStr(LIt.GetValue));

  LIt := nil;
  for LIdx := 0 to S.ItemCount - 1 do
    if SameText(S.Item(LIdx).Name, 'KdvDahil') then
      LIt := S.Item(LIdx);
  Ok('ReadOnly satiri duzenlemeye kapatti',
     (LIt <> nil) and (not LIt.Row.Properties.Options.Editing));
  Writeln;
end;

procedure Test09_Arama(const S: ISetting);
var
  LTum, LVade, LYok, LKategori: Integer;
begin
  Writeln('09 - arama (kategoriler ARASINDA)');

  S.Clear
   .AddMenu('Fatura')
     .AddSubMenu('Satis').Register(TSatisAyar)
   .AddMenu('Genel')
     .Register(TGenelAyar);

  LTum := S.ItemCount;
  Ok('iki kategoriden 6 ayar', LTum = 6, IntToStr(LTum));

  LVade     := S.Search('vade');
  LKategori := S.Search('sirket');
  LYok      := S.Search('zzzzz');

  Ok('"vade" 2 eslesme (Vade + VadeAsimUyar)', LVade = 2, IntToStr(LVade));
  // 'sirket' YALNIZCA Genel kategorisinde; arama kategori sinirini asmali
  Ok('"sirket" farkli kategoride bulundu', LKategori = 1, IntToStr(LKategori));
  Ok('eslesmeyen arama 0', LYok = 0, IntToStr(LYok));
  Ok('bos arama gezinmeye donuyor', S.Search('') = LTum, IntToStr(S.Search('')));
  Writeln;
end;

procedure Test10_GidisDonus(const S: ISetting);
var
  LJson, LGeri: string;
  LIdx: Integer;
  LIt : TRadSettingItem;
begin
  Writeln('10 - JSON gidis-donus + BILINMEYEN anahtar korunuyor mu');

  S.Clear
   .AddMenu('Fatura')
     .AddSubMenu('Satis')
       .Register(TSatisAyar);

  // Panelde property karsiligi OLMAYAN bir anahtar: yeni bir surumun
  // ekledigi ayari temsil ediyor.
  S.Doc.S['fatura.satis.gelecek_surum_ayari'] := 'korunmali';
  S.Doc.I['fatura.satis.vade'] := 90;

  LJson := S.SaveJson;
  Ok('bilinmeyen anahtar JSON''da', Pos('gelecek_surum_ayari', LJson) > 0, LJson);

  S.LoadJson(LJson);

  LIt := nil;
  for LIdx := 0 to S.ItemCount - 1 do
    if SameText(S.Item(LIdx).Name, 'Vade') then
      LIt := S.Item(LIdx);
  Ok('yuklenen deger okunuyor', (LIt <> nil) and (LIt.GetValue = 90),
     VarToStr(LIt.GetValue));
  Ok('satir da tazelendi', (LIt <> nil) and (LIt.Row.Properties.Value = 90),
     VarToStr(LIt.Row.Properties.Value));

  LGeri := S.SaveJson;
  Ok('bilinmeyen anahtar HALA duruyor', Pos('gelecek_surum_ayari', LGeri) > 0, LGeri);
  Ok('LoadJson sonrasi Modified False', not S.Modified);
  Writeln('       ', LGeri);
  Writeln;
end;

procedure Test11_ErisimciKopruleri(const S: ISetting);
var
  LObj: TSatisAyar;
begin
  Writeln('11 - property erisimcileri depoya baglaniyor mu');

  S.Clear
   .AddMenu('Fatura')
     .AddSubMenu('Satis')
       .Register(TSatisAyar);

  // Register ornegi kendisi yaratip sahiplenir; testte S.Item uzerinden
  // sahibine ulasiyoruz.
  LObj := TSatisAyar(S.Item(0).Owner);
  Ok('sahip TSatisAyar', LObj is TSatisAyar, LObj.ClassName);

  LObj.Vade := 60;
  Ok('property -> depo', S.Doc.I['fatura.satis.vade'] = 60,
     VarToStr(S.Doc.I['fatura.satis.vade']));
  Ok('property geri okuma', LObj.Vade = 60, IntToStr(LObj.Vade));

  S.Doc.I['fatura.satis.vade'] := 15;
  Ok('depo -> property', LObj.Vade = 15, IntToStr(LObj.Vade));

  LObj.Depo := 'ANKARA';
  Esit('string erisimci', 'ANKARA', S.Doc.S['fatura.satis.depo']);

  LObj.KdvDahil := True;
  Ok('boolean erisimci', S.Doc.B['fatura.satis.kdv_dahil'] = True);
  Writeln;
end;

// ---------------------------------------------------------------------------

var
  LForm  : TForm;
  LFrame : TfrmSetting;
  LSet   : ISetting;
begin
  ReportMemoryLeaksOnShutdown := True;
  try
    Application.Initialize;

    // TFrame bir ust kontrol ister. Form GOSTERILMIYOR - bu sonda modeli
    // olcuyor, cizimi degil.
    LForm := TForm.CreateNew(nil);
    try
      LFrame := TfrmSetting.Create(LForm);
      LFrame.Parent := LForm;
      LSet := LFrame as ISetting;

      Writeln('=== k.setting sondasi ===');
      Writeln;
      Test01_Slug;
      Test02_KayitVeAnahtar(LSet);
      Test03_Varsayilanlar(LSet);
      Test04_YazVeAgac(LSet);
      Test05_PathDelimYokken;
      Test06_AltKategori(LSet);
      Test07_Savunma(LSet);
      Test08_Susleme(LSet);
      Test09_Arama(LSet);
      Test10_GidisDonus(LSet);
      Test11_ErisimciKopruleri(LSet);

      LSet := nil;
    finally
      LForm.Free;
    end;

    Writeln('=========================================');
    Writeln(Format('GECTI: %d    KALDI: %d', [GGecti, GKaldi]));
    if GKaldi > 0 then
      ExitCode := 1;
  except
    on E: Exception do
    begin
      Writeln('BEKLENMEYEN ISTISNA: ', E.ClassName, ': ', E.Message);
      ExitCode := 2;
    end;
  end;
end.
