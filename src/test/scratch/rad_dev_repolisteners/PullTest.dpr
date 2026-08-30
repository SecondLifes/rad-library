program PullTest;

(*
  PULL yonu (AMaster + AOnFilter) icin olcum sondasi.

  Kaskadin TERSI: bagimli editor, acilir listesi acilmadan hemen once kendi
  MASTER'inin degerini okur ve filtreyi KENDI uygular. Push ise yalnizca bir
  GECERSIZ KILMA sinyali olarak duruyor.

  ! BASSIZ CALISIR, ama bu bir kisittir: TcxCustomDropDownEdit.DropDown
    "if not IsWindowVisible(Handle) then Exit" ile basliyor
    (cxDropDownEdit.pas:3252), yani GORUNMEYEN bir pencerede DoInitPopup HIC
    calismaz. Bu yuzden burada pull, FilterNow ile ELLE tetikleniyor.
    Gercek popup yolunun olcumu gorunur pencere ister - ayri sonda.

  T07 KIRMIZI-ONCE bir regresyondur: AOnCascade ATANMAMISKEN gecersiz kilma
  eskiden HIC calismiyordu (DoCascade "not Assigned(FCascadeEvent)" ile
  cikiyordu). Pull dunyasinda AOnCascade atanmamis olmak KURAL oldugu icin bu,
  sessizce tutarsiz kayit ureten bir hataydi.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, Vcl.Forms, Vcl.Controls,
  cxEdit, cxDropDownEdit, cxLookupEdit, cxDBLookupEdit, cxDBLookupComboBox,
  cxGraphics, cxControls, cxLookAndFeels, cxContainer, cxClasses, Vcl.StdCtrls,
  cxGrid, cxGridLevel, cxGridTableView, cxGridCustomTableView,
  Data.DB, MemDS, VirtualTable,
  Rad.Dev;

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
    Writeln('  [HATA] ', AAd);
  end;
  if ADetay <> '' then
    Writeln('         ', ADetay);
end;

function Ad(AC: TComponent): string;
begin
  if AC = nil then
    Result := '<nil>'
  else if AC.Name <> '' then
    Result := AC.Name
  else
    Result := '<' + AC.ClassName + '>';
end;

type
  { GetDisplayLookupText protected; kitin kendi erisim-sinifi deseni
    (bkz. RuntimeTest.dpr TEditAccess). }
  TPropsAccess = class(TRadLookupComboBoxProperties);

  TIzleyici = class
  public
    Sayac: Integer;
    SonSource: TComponent;
    SonMaster: TComponent;
    SonDeger: Variant;
    Yineleyen: TRadLookupComboBox;
    Patlat: Boolean;              { isleyici istisna atsin mi }
    LocateSayaci: Integer;
    AramaSayaci: Integer;
    SonAramaMetni: string;
    AramaAcsin: Boolean;          { arama isleyicisi dataset i acsin mi }
    AcilacakTablo: TVirtualTable;
    procedure Filtre(Sender: TRadLookupComboBoxProperties;
      ASource, AMaster: TComponent; const AMasterValue: Variant);
    procedure Sifirla;
    procedure Arama(Sender: TRadLookupComboBoxProperties;
      ASource: TComponent; var AText, ATail: string; ANext: Boolean);
    procedure Locate(Sender: TRadLookupComboBoxProperties;
      ASource: TComponent; const AKey: Variant);
    procedure ComboKaskad(Sender: TRadComboBoxProperties;
      ASource, ATarget: TComponent; const AValue: Variant);
  end;

procedure TIzleyici.Sifirla;
begin
  Sayac := 0;
  SonSource := nil;
  SonMaster := nil;
  SonDeger := Unassigned;
end;

procedure TIzleyici.Arama(Sender: TRadLookupComboBoxProperties;
  ASource: TComponent; var AText, ATail: string; ANext: Boolean);
begin
  Inc(AramaSayaci);
  SonAramaMetni := AText;
  if AramaAcsin and (AcilacakTablo <> nil) then
  begin
    AcilacakTablo.Close;
    AcilacakTablo.Open;
  end;
  if Patlat then
    raise Exception.Create('sonda: arama isleyicisi bilerek patladi');
end;

procedure TIzleyici.Locate(Sender: TRadLookupComboBoxProperties;
  ASource: TComponent; const AKey: Variant);
begin
  Inc(LocateSayaci);
end;

procedure TIzleyici.ComboKaskad(Sender: TRadComboBoxProperties;
  ASource, ATarget: TComponent; const AValue: Variant);
begin
  { govde bos - varligi yeterli }
end;

procedure TIzleyici.Filtre(Sender: TRadLookupComboBoxProperties;
  ASource, AMaster: TComponent; const AMasterValue: Variant);
begin
  Inc(Sayac);
  SonSource := ASource;
  SonMaster := AMaster;
  SonDeger := AMasterValue;
  { T03: yeniden giris korumasi calismazsa burasi yigin tukenene kadar doner. }
  if Yineleyen <> nil then
    Yineleyen.FilterNow;
  if Patlat then
    raise Exception.Create('sonda: filtre isleyicisi bilerek patladi');
end;

var
  LForm: TForm;
  LIzle: TIzleyici;
  LUsta, LBagimli, LKopya, LKaynak, LHedef: TRadLookupComboBox;
  LUyari, LHata, LDenetim, LOnce: string;
  LDugme: TButton;
  LUsta2, LOrtak: TRadLookupComboBox;
  LGrid: TcxGrid;
  LLevel: TcxGridLevel;
  LView: TcxGridTableView;
  LCol, LCol2: TcxGridColumn;
  LItem: TRadLookupComboBoxRepository;
  LSlots: TRadEditSlots;
  LBuyukVT: TVirtualTable;
  LBuyukDs: TDataSource;
  LBuyukEd, LBuyukUsta: TRadLookupComboBox;
  LCombo: TRadComboBox;
  i: Integer;
  LVT: TVirtualTable;
  LDs: TDataSource;
  LUlkeOto, LSehirOto: TRadLookupComboBox;

procedure SehirEkle(ATable: TVirtualTable; AId: Integer; const AAd: string;
  AUlke: Integer);
begin
  ATable.Append;
  ATable.FieldByName('id').AsInteger := AId;
  ATable.FieldByName('ad').AsString := AAd;
  ATable.FieldByName('ulke_id').AsInteger := AUlke;
  ATable.Post;
end;

function YeniEditor(const AAd: string): TRadLookupComboBox;
begin
  Result := TRadLookupComboBox.Create(LForm);
  Result.Name := AAd;
  Result.Parent := LForm;
end;

begin
  try
    LForm := TForm.CreateNew(nil);
    LIzle := TIzleyici.Create;
    try
      Writeln('=== T01) AMaster bos iken pull sessiz ===');
      LIzle.Sifirla;
      LBagimli := YeniEditor('Bagimli');
      LBagimli.Properties.AOnFilter := LIzle.Filtre;
      LBagimli.FilterNow;
      Kontrol('AMaster nil -> AOnFilter hic tetiklenmiyor',
        LIzle.Sayac = 0, Format('olay sayisi: %d (0 bekleniyor)', [LIzle.Sayac]));

      Writeln;
      Writeln('=== T02) AMaster + AOnFilter -> bir kez, dogru ucgenle ===');
      LIzle.Sifirla;
      LUsta := YeniEditor('Usta');
      LUsta.EditValue := 'TR';
      LBagimli.Properties.AMaster := LUsta;
      LBagimli.FilterNow;
      Kontrol('tam bir kez tetiklendi',
        LIzle.Sayac = 1, Format('olay sayisi: %d', [LIzle.Sayac]));
      Kontrol('ASource = soruyu soran editor',
        LIzle.SonSource = LBagimli, 'ASource = ' + Ad(LIzle.SonSource));
      Kontrol('AMaster = atanmis usta',
        LIzle.SonMaster = LUsta, 'AMaster = ' + Ad(LIzle.SonMaster));
      Kontrol('AMasterValue = ustanin o anki degeri',
        VarToStr(LIzle.SonDeger) = 'TR', 'deger = ' + VarToStr(LIzle.SonDeger));

      Writeln;
      Writeln('=== T03) Yeniden giris kesiliyor mu? ===');
      LIzle.Sifirla;
      LIzle.Yineleyen := LBagimli;
      LBagimli.FilterNow;
      LIzle.Yineleyen := nil;
      Kontrol('isleyici icinden FilterNow -> yine tek giris',
        LIzle.Sayac = 1,
        Format('olay sayisi: %d (1 bekleniyor; 2+ ise FFiltering calismiyor)',
          [LIzle.Sayac]));

      Writeln;
      Writeln('=== T04) AFilterOnPopup yalnizca OTOMATIK yolu kapatir ===');
      Kontrol('taze bir Properties AFilterOnPopup = True ile geliyor',
        YeniEditor('Taze').Properties.AFilterOnPopup,
        'default direktifi ile constructor ayni olmali');
      LIzle.Sifirla;
      LBagimli.Properties.AFilterOnPopup := False;
      LBagimli.FilterNow;
      Kontrol('AFilterOnPopup=False iken FilterNow YINE tetikliyor',
        LIzle.Sayac = 1, Format('olay sayisi: %d', [LIzle.Sayac]));

      Writeln;
      Writeln('=== T05) DoAssign pull yukunu tasiyor mu? ===');
      LKopya := YeniEditor('Kopya');
      LKopya.Properties := LBagimli.Properties;
      Kontrol('AMaster kopyalandi',
        LKopya.Properties.AMaster = LUsta,
        'AMaster = ' + Ad(LKopya.Properties.AMaster));
      Kontrol('AOnFilter kopyalandi',
        Assigned(LKopya.Properties.AOnFilter));
      Kontrol('AFilterOnPopup kopyalandi (False)',
        LKopya.Properties.AFilterOnPopup = False);
      LBagimli.Properties.AFilterOnPopup := True;

      Writeln;
      Writeln('=== T06) Master yok edilince isaretci nil-leniyor mu? ===');
      LUsta.Free;
      Kontrol('AMaster nil-lendi (kaynak)',
        LBagimli.Properties.AMaster = nil,
        'AMaster = ' + Ad(LBagimli.Properties.AMaster));
      Kontrol('AMaster nil-lendi (DoAssign kopyasi da korumali)',
        LKopya.Properties.AMaster = nil,
        'AMaster = ' + Ad(LKopya.Properties.AMaster));
      LIzle.Sifirla;
      LBagimli.FilterNow;
      Kontrol('master yokken FilterNow patlamiyor ve sessiz',
        LIzle.Sayac = 0);

      Writeln;
      Writeln('=== T07) AOnCascade ATANMAMISKEN gecersiz kilma (KIRMIZI-ONCE) ===');
      LKaynak := YeniEditor('Kaynak');
      LHedef  := YeniEditor('Hedef');
      LKaynak.Properties.AComponent1 := LHedef;
      LKaynak.Properties.AClearTargetsOnCascade := True;
      { AOnCascade BILEREK atanmiyor - pull dunyasinda kural budur. }
      LHedef.EditValue := 'ESKI-SEHIR';
      LKaynak.EditValue := 'DE';
      Kontrol('AOnCascade yokken bile hedefin degeri temizlendi',
        VarToStr(LHedef.EditValue) = '',
        'hedef.EditValue = "' + VarToStr(LHedef.EditValue) + '" (bos olmali)');

      LHedef.EditValue := 'ESKI-SEHIR';
      LKaynak.Properties.AClearTargetsOnCascade := False;
      LKaynak.EditValue := 'FR';
      Kontrol('AClearTargetsOnCascade=False iken deger KORUNUYOR',
        VarToStr(LHedef.EditValue) = 'ESKI-SEHIR',
        'hedef.EditValue = "' + VarToStr(LHedef.EditValue) + '"');

      Writeln;
      Writeln('=== T08) Master, PUSH yuvasi sayilmiyor ===');
      Kontrol('yalnizca AMaster atanmis bir editorde ChainSlotCount = 0',
        LKopya.Properties.ChainSlotCount = 0,
        Format('ChainSlotCount = %d', [LKopya.Properties.ChainSlotCount]));
      Kontrol('AComponent1 dolu kaynakta ChainSlotCount = 1',
        LKaynak.Properties.ChainSlotCount = 1,
        Format('ChainSlotCount = %d', [LKaynak.Properties.ChainSlotCount]));

      Writeln;
      Writeln('=== T09) PullWarning sessiz tuzaklari bildiriyor mu? ===');
      Kontrol('master yokken uyari yok',
        LKaynak.Properties.PullWarning = '',
        '"' + LKaynak.Properties.PullWarning + '"');

      LHedef.Properties.AMaster := LKaynak;
      LUyari := LHedef.Properties.PullWarning;
      Kontrol('AOnFilter yoksa bildiriyor', Pos('AOnFilter', LUyari) > 0);
      Kontrol('ListSource yoksa bildiriyor', Pos('ListSource', LUyari) > 0);
      Kontrol('AOnLocate yoksa bildiriyor', Pos('AOnLocate', LUyari) > 0);
      Writeln('         --- uyari metni ---');
      Writeln('         ', StringReplace(LUyari, sLineBreak,
        sLineBreak + '         ', [rfReplaceAll]));

      Writeln;
      Writeln('=== T10) AMaster tip denetimi ===');
      LDugme := TButton.Create(LForm);
      LDugme.Name := 'Dugme';
      LDugme.Parent := LForm;
      LHata := '';
      try
        LBagimli.Properties.AMaster := LDugme;
      except
        on E: Exception do
          LHata := E.ClassName;
      end;
      Kontrol('editor olmayan bir bilesen ERadDev ile reddediliyor',
        LHata = 'ERadDev',
        'atilan: ' + LHata + ' (ERadDev bekleniyor; bos ise SESSIZCE kabul edildi)');
      Kontrol('reddedilen atama yuvayi bozmadi',
        LBagimli.Properties.AMaster = nil,
        'AMaster = ' + Ad(LBagimli.Properties.AMaster));
      Kontrol('nil atamasi hala serbest (temizleme yolu)',
        LKopya.Properties.AMaster = nil);

      Writeln;
      Writeln('=== T11) RadChainAudit teshisleri topluyor mu? ===');
      LDenetim := RadChainAudit(LForm);
      Kontrol('form denetimi bos donmuyor',
        LDenetim <> '', Format('uzunluk: %d', [Length(LDenetim)]));
      Kontrol('PullWarning bulgusu denetimde gorunuyor',
        Pos('AOnFilter', LDenetim) > 0);
      Kontrol('nil kok icin bos donuyor',
        RadChainAudit(nil) = '');
      Writeln('         --- denetim ciktisi (ilk satir) ---');
      if LDenetim <> '' then
        Writeln('         ', Copy(LDenetim, 1, Pos(sLineBreak, LDenetim + sLineBreak) - 1));

      Writeln;
      Writeln('=== T12) Denetim, grid KOLONUNUN KENDI Properties''ini goruyor mu? ===');
      (* Bu tam olarak ChainWarning''in ONERDIGI yapilandirma: paylasilan
         item yerine her tuketici KENDI Properties''inde master tasisin.
         Denetim bunu kacirirsa, tavsiye edilen kurulum denetlenemez olur. *)
      LUsta2 := YeniEditor('Usta2');
      LGrid := TcxGrid.Create(LForm);
      LGrid.Name := 'Izgara';
      LGrid.Parent := LForm;
      LLevel := LGrid.Levels.Add;
      LView := LGrid.CreateView(TcxGridTableView) as TcxGridTableView;
      LLevel.GridView := LView;
      LCol := LView.CreateColumn;
      LCol.Caption := 'SehirKolonu';
      LCol.PropertiesClass := TRadLookupComboBoxProperties;
      TRadLookupComboBoxProperties(LCol.Properties).AMaster := LUsta2;

      LOnce := LDenetim;
      LDenetim := RadChainAudit(LForm);
      Kontrol('kolonun kendi Properties''i denetimde yeni bir bulgu uretiyor',
        Length(LDenetim) > Length(LOnce),
        Format('once %d karakter, simdi %d', [Length(LOnce), Length(LDenetim)]));
      Kontrol('kolon icin PullWarning gercekten uretilebiliyor',
        TRadLookupComboBoxProperties(LCol.Properties).PullWarning <> '',
        'kolonun kendi PullWarning''i bos ise master hic gorulmuyor demektir');

      Writeln;
      Writeln('=== T13) PAYLASILAN item + KENDI Properties''i (KIRMIZI-ONCE) ===');
      (* Kitin kendi deseni (PerConsumerTest bunu olcuyor): item paylasilir,
         her tuketici yere ozel yuku KENDI Properties''inde tasir. ChainWarning
         master icin tam olarak bunu ONERIYOR. Kolona bir RepositoryItem
         baglaninca _ActiveProperties artik PAYLASILANI dondurur; denetim
         yalnizca ona bakarsa, tavsiye edilen kurulum denetlenemez olur. *)
      LItem := TRadLookupComboBoxRepository.Create(LForm);
      LItem.Name := 'PaylasilanItem';
      LCol2 := LView.CreateColumn;
      LCol2.Caption := 'IlceKolonu';
      LCol2.PropertiesClass := TRadLookupComboBoxProperties;
      TRadLookupComboBoxProperties(LCol2.Properties).AMaster := LUsta2;
      LCol2.RepositoryItem := LItem;

      Kontrol('kurulum dogru: aktif Properties = item''in, kendi Properties''i ayri',
        (LCol2.GetProperties = LItem.Properties) and
        (TRadLookupComboBoxProperties(LCol2.Properties).AMaster = LUsta2),
        'aktif ile kendi ayni ise bu test bir sey olcmez');

      LOnce := LDenetim;
      LDenetim := RadChainAudit(LForm);
      Kontrol('denetim, KENDI Properties''indeki master''i da raporluyor',
        Length(LDenetim) > Length(LOnce),
        Format('once %d karakter, simdi %d ' +
          '(esitse denetim yalnizca aktif Properties''e bakiyor demektir)',
          [Length(LOnce), Length(LDenetim)]));

      Writeln;
      Writeln('=== T14) Dairesel master reddediliyor ===');
      LHata := '';
      try
        LBagimli.Properties.AMaster := LBagimli;
      except
        on E: Exception do
          LHata := E.ClassName;
      end;
      Kontrol('editor kendini master yapamiyor',
        LHata = 'ERadDev', 'atilan: ' + LHata + ' (ERadDev bekleniyor)');

      (* Ikinci sekil: master, AYNI paylasilan Properties'i kullanan baska bir
         tuketici. Tek AMaster alani hepsi icin ortak oldugundan master'in
         master'i yine kendisi olurdu. *)
      LOrtak := YeniEditor('OrtakTuketici');
      LOrtak.RepositoryItem := LItem;
      LHata := '';
      try
        LItem.Properties.AMaster := LOrtak;
      except
        on E: Exception do
          LHata := E.ClassName;
      end;
      Kontrol('paylasilan item, kendi tuketicisini master alamiyor',
        LHata = 'ERadDev', 'atilan: ' + LHata + ' (ERadDev bekleniyor)');
      Kontrol('reddedilen atamalar yuvayi bozmadi',
        (LBagimli.Properties.AMaster = nil) and
        (LItem.Properties.AMaster = nil));

      Writeln;
      Writeln('=== T15) AMasterField serbest yuku ve DoAssign ===');
      LKaynak.Properties.AMasterField := 'ulke_id';
      Kontrol('AMasterField okunup yaziliyor',
        LKaynak.Properties.AMasterField = 'ulke_id');
      LHedef.Properties := LKaynak.Properties;
      Kontrol('DoAssign AMasterField''i tasiyor',
        LHedef.Properties.AMasterField = 'ulke_id',
        'kopyadaki: "' + LHedef.Properties.AMasterField + '"');
      Kontrol('taze bir Properties AAutoFilter = afNone ile geliyor',
        YeniEditor('Taze2').Properties.AAutoFilter = afNone);

      Writeln;
      Writeln('=== T16) AAutoFilter = afClientFilter, AOnFilter YAZMADAN ===');
      LVT := TVirtualTable.Create(LForm);
      LVT.Name := 'SehirTablosu';
      LVT.FieldDefs.Add('id', ftInteger);
      LVT.FieldDefs.Add('ad', ftString, 30);
      LVT.FieldDefs.Add('ulke_id', ftInteger);
      LVT.Open;
      SehirEkle(LVT, 10, 'Istanbul', 1);
      SehirEkle(LVT, 11, 'Ankara',   1);
      SehirEkle(LVT, 12, 'Izmir',    1);
      SehirEkle(LVT, 13, 'Bursa',    1);
      SehirEkle(LVT, 20, 'Berlin',   2);
      SehirEkle(LVT, 21, 'Munih',    2);
      Kontrol('sonda verisi hazir: 6 sehir', LVT.RecordCount = 6,
        Format('RecordCount = %d', [LVT.RecordCount]));

      LDs := TDataSource.Create(LForm);
      LDs.DataSet := LVT;
      LUlkeOto := YeniEditor('UlkeOto');
      LSehirOto := YeniEditor('SehirOto');
      LSehirOto.Properties.ListSource := LDs;
      LSehirOto.Properties.KeyFieldNames := 'id';
      LSehirOto.Properties.ListFieldNames := 'ad';
      LSehirOto.Properties.AMaster := LUlkeOto;
      LSehirOto.Properties.AMasterField := 'ulke_id';
      LSehirOto.Properties.AAutoFilter := afClientFilter;
      { AOnFilter BILEREK atanmiyor - ozelligin butun amaci bu. }

      LUlkeOto.EditValue := 1;
      LSehirOto.FilterNow;
      Kontrol('master=1 -> liste 4 satira suzuldu (isleyici YOK)',
        LVT.RecordCount = 4,
        Format('RecordCount = %d, Filter = "%s"', [LVT.RecordCount, LVT.Filter]));

      LUlkeOto.EditValue := 2;
      LSehirOto.FilterNow;
      Kontrol('master=2 -> liste 2 satira suzuldu',
        LVT.RecordCount = 2,
        Format('RecordCount = %d, Filter = "%s"', [LVT.RecordCount, LVT.Filter]));

      LUlkeOto.EditValue := Null;
      LSehirOto.FilterNow;
      Kontrol('master BOS -> dataset kapatildi (bos liste)',
        not LVT.Active, Format('Active = %s', [BoolToStr(LVT.Active, True)]));

      LUlkeOto.EditValue := 1;
      LSehirOto.FilterNow;
      Kontrol('master geri gelince liste yeniden aciliyor',
        LVT.Active and (LVT.RecordCount = 4),
        Format('Active = %s, RecordCount = %d',
          [BoolToStr(LVT.Active, True), LVT.RecordCount]));

      Writeln;
      Writeln('=== T17) Otomatik kip yanlis yapilandirmayi SESSIZ birakmiyor ===');
      LSehirOto.Properties.AMasterField := '';
      LHata := '';
      try
        LSehirOto.FilterNow;
      except
        on E: Exception do
          LHata := E.ClassName;
      end;
      Kontrol('AMasterField bos -> ERadDev',
        LHata = 'ERadDev', 'atilan: ' + LHata);
      Kontrol('PullWarning de ayni seyi onceden soyluyor',
        Pos('AMasterField', LSehirOto.Properties.PullWarning) > 0);
      LSehirOto.Properties.AMasterField := 'ulke_id';

      LSehirOto.Properties.AAutoFilter := afServerParam;
      LHata := '';
      try
        LSehirOto.FilterNow;
      except
        on E: Exception do
          LHata := E.ClassName;
      end;
      Kontrol('afServerParam, parametresiz bir dataset''te ERadDev atiyor',
        LHata = 'ERadDev', 'atilan: ' + LHata + ' (TVirtualTable parametre almaz)');
      Writeln;
      Writeln('=== T21) Master filtresi arama metnini SIFIRLIYOR mu? ===');
      (* Kullanicinin karari: yeni master, yeni liste. Bos metin mevcut
         sozlesmede zaten "hepsini goster" demek, o yuzden ayri bir
         mekanizma yok - arama BOS metinle bir kez cagriliyor. *)
      LSehirOto.Properties.AAutoFilter := afNone;
      LSehirOto.Properties.AOnFilter := LIzle.Filtre;
      LSehirOto.Properties.AOnSearch := LIzle.Arama;
      LIzle.Sifirla;
      LIzle.AramaSayaci := 0;
      LIzle.SonAramaMetni := 'ONCEKI-ARAMA';
      LSehirOto.FilterNow;
      Kontrol('master filtresinden sonra arama tam bir kez cagrildi',
        LIzle.AramaSayaci = 1, Format('AramaSayaci = %d', [LIzle.AramaSayaci]));
      Kontrol('arama BOS metinle cagrildi (eski metin silindi)',
        LIzle.SonAramaMetni = '',
        'gelen metin: "' + LIzle.SonAramaMetni + '"');
      Kontrol('filtre isleyicisi de calisti',
        LIzle.Sayac = 1, Format('filtre olayi = %d', [LIzle.Sayac]));

      Writeln;
      Writeln('=== T22) TEK yeniden acis: acmayi arama devraliyor mu? ===');
      (* afClientFilter kipinde ApplyAutoFilter normalde dataset i acar.
         AOnSearch bagliysa ACMAMALI - tek Close/Open i arama yapar. Sonda
         isleyicisi acmadigi icin dataset KAPALI kalmali. *)
      LSehirOto.Properties.AOnFilter := nil;
      LSehirOto.Properties.AAutoFilter := afClientFilter;
      LSehirOto.Properties.AMasterField := 'ulke_id';
      LIzle.AramaAcsin := False;
      LUlkeOto.EditValue := 1;
      LVT.Close;
      LIzle.AramaSayaci := 0;
      LSehirOto.FilterNow;
      Kontrol('arama cagrildi', LIzle.AramaSayaci = 1,
        Format('AramaSayaci = %d', [LIzle.AramaSayaci]));
      Kontrol('ApplyAutoFilter dataset i KENDISI acmadi (acis devredildi)',
        not LVT.Active,
        'acik kalsaydi bir acilista iki sorgu kosardi');
      Kontrol('filtre yine de kurulmus',
        LVT.Filter = 'ulke_id = 1', 'Filter = "' + LVT.Filter + '"');

      { Simdi arama gercekten acsin - suzgec korunuyor mu? }
      LIzle.AcilacakTablo := LVT;
      LIzle.AramaAcsin := True;
      LSehirOto.FilterNow;
      LIzle.AramaAcsin := False;
      Kontrol('arama acinca liste master suzgeciyle geliyor',
        LVT.Active and (LVT.RecordCount = 4),
        Format('Active=%s RecordCount=%d (4 bekleniyor)',
          [BoolToStr(LVT.Active, True), LVT.RecordCount]));

      Writeln;
      Writeln('=== T19) Isleyici patlarsa dataset busy KALMIYOR (RADDEV-003) ===');
      LSehirOto.Properties.AAutoFilter := afNone;
      LSehirOto.Properties.AOnFilter := LIzle.Filtre;
      LIzle.Patlat := True;
      LHata := '';
      try
        LSehirOto.FilterNow;
      except
        on E: Exception do LHata := E.Message;
      end;
      LIzle.Patlat := False;
      Kontrol('isleyicinin istisnasi disari cikiyor (yutulmuyor)',
        Pos('bilerek patladi', LHata) > 0, 'mesaj: ' + LHata);
      Kontrol('dataset busy BIRAKILMADI',
        not TRadBusyDataSets.IsBusy(LVT),
        'busy kalsaydi sonraki her filtre sessizce atlanirdi');
      LIzle.Sifirla;
      LSehirOto.FilterNow;
      Kontrol('sonraki filtre yine calisiyor', LIzle.Sayac = 1,
        Format('olay sayisi: %d', [LIzle.Sayac]));

      Writeln;
      Writeln('=== T20) Arama patlarsa onbellek YINE de sifirlaniyor (RADDEV-004) ===');
      LSehirOto.Properties.AOnFilter := nil;
      LSehirOto.Properties.AOnLocate := LIzle.Locate;
      LSehirOto.Properties.AOnSearch := LIzle.Arama;
      LSehirOto.Properties.AMinSearchLength := 0;
      LIzle.LocateSayaci := 0;
      { 1) anahtari cozdur -> onbellek dolar }
      TPropsAccess(LSehirOto.Properties).GetDisplayLookupText(10);
      Kontrol('ilk cozumleme AOnLocate tetikliyor',
        LIzle.LocateSayaci = 1, Format('LocateSayaci = %d', [LIzle.LocateSayaci]));
      TPropsAccess(LSehirOto.Properties).GetDisplayLookupText(10);
      Kontrol('ayni anahtar ikinci kez onbellekten geliyor',
        LIzle.LocateSayaci = 1, Format('LocateSayaci = %d (hala 1 olmali)',
          [LIzle.LocateSayaci]));
      { 2) arama isleyicisi PATLASIN - liste degismis olabilir }
      LIzle.Patlat := True;
      LHata := '';
      try
        LSehirOto.Properties.TimedSearch(LSehirOto, 'ist');
      except
        on E: Exception do LHata := E.Message;
      end;
      LIzle.Patlat := False;
      Kontrol('arama istisnasi disari cikiyor',
        Pos('bilerek patladi', LHata) > 0, 'mesaj: ' + LHata);
      Kontrol('arama dataset i busy birakmadi',
        not TRadBusyDataSets.IsBusy(LVT));
      { 3) onbellek sifirlanmis olmali -> AOnLocate YENIDEN tetiklenmeli }
      TPropsAccess(LSehirOto.Properties).GetDisplayLookupText(10);
      Kontrol('istisnaya ragmen onbellek sifirlandi (AOnLocate yeniden kosuyor)',
        LIzle.LocateSayaci = 2,
        Format('LocateSayaci = %d (2 bekleniyor; 1 kalirsa onbellek BAYAT)',
          [LIzle.LocateSayaci]));

      Writeln;
      Writeln('=== T23) afClientFilter esik uyarisi (200 satir) ===');
      LBuyukVT := TVirtualTable.Create(LForm);
      LBuyukVT.Name := 'BuyukTablo';
      LBuyukVT.FieldDefs.Add('id', ftInteger);
      LBuyukVT.FieldDefs.Add('ad', ftString, 30);
      LBuyukVT.FieldDefs.Add('ulke_id', ftInteger);
      LBuyukVT.Open;
      for i := 1 to 200 do
        SehirEkle(LBuyukVT, i, 'Sehir' + IntToStr(i), 1);
      LBuyukDs := TDataSource.Create(LForm);
      LBuyukDs.DataSet := LBuyukVT;
      LBuyukUsta := YeniEditor('BuyukUsta');
      LBuyukUsta.EditValue := 1;
      LBuyukEd := YeniEditor('BuyukEd');
      LBuyukEd.Properties.ListSource := LBuyukDs;
      LBuyukEd.Properties.AMaster := LBuyukUsta;
      LBuyukEd.Properties.AMasterField := 'ulke_id';
      LBuyukEd.Properties.AAutoFilter := afClientFilter;
      LBuyukEd.Properties.AOnLocate := LIzle.Locate;
      LBuyukEd.Properties.AOnFilter := LIzle.Filtre;
      Kontrol('tam esikte (200) uyari YOK',
        Pos('esik', LBuyukEd.Properties.PullWarning) = 0,
        Format('RecordCount = %d; uyari: %s',
          [LBuyukVT.RecordCount, LBuyukEd.Properties.PullWarning]));
      SehirEkle(LBuyukVT, 201, 'Sehir201', 1);
      Kontrol('esigin bir ustunde (201) uyari VAR',
        Pos('esik', LBuyukEd.Properties.PullWarning) > 0,
        Format('RecordCount = %d', [LBuyukVT.RecordCount]));
      Kontrol('uyari afServerParam i oneriyor',
        Pos('afServerParam', LBuyukEd.Properties.PullWarning) > 0);

      Writeln;
      Writeln('=== T24) Denetim combo ailesini de goruyor mu? (RADDEV-007) ===');
      LCombo := TRadComboBox.Create(LForm);
      LCombo.Name := 'ComboKaynak';
      LCombo.Parent := LForm;
      LCombo.Properties.AComponent1 := LBuyukEd;
      { AOnCascade BILEREK yok - combo hedefinin listesi hic tazelenmez. }
      Kontrol('combo icin CascadeWarning uretiliyor',
        Pos('AOnCascade', LCombo.Properties.CascadeWarning) > 0,
        'uyari: ' + LCombo.Properties.CascadeWarning);
      LOnce := RadChainAudit(LForm);
      Kontrol('denetim combo uyarisini da topluyor',
        Pos('Items', LOnce) > 0,
        'combo uyarisi Items kelimesini iceriyor; denetimde gorunmeli');
      LCombo.Properties.AOnCascade := LIzle.ComboKaskad;
      Kontrol('AOnCascade ataninca combo uyarisi susuyor',
        LCombo.Properties.CascadeWarning = '',
        'uyari: ' + LCombo.Properties.CascadeWarning);

      Writeln;
      Writeln('=== T18) TRadEditSlots sinir denetimi (RADDEV-006) ===');
      (* Paket {$RANGECHECKS OFF} ile derleniyor (RadKon.dpk:17), yani
         derleyici korumasina guvenilemez: FItems[0] ya da FItems[5] sessizce
         dizi disini okur/yazar. Sinif public oldugu icin bu erisim disaridan
         mumkun. *)
      LSlots := TRadEditSlots.Create(nil);
      try
        LHata := '';
        try
          LSlots.Get(0);
        except
          on E: Exception do LHata := E.ClassName;
        end;
        Kontrol('Get(0) reddediliyor', LHata = 'ERadDev',
          'atilan: ' + LHata + ' (sessiz kalirsa dizi disi okuma)');

        LHata := '';
        try
          LSlots.Put(TRadEditSlots.CCount + 1, LBagimli);
        except
          on E: Exception do LHata := E.ClassName;
        end;
        Kontrol('Put(CCount+1) reddediliyor', LHata = 'ERadDev',
          'atilan: ' + LHata + ' (sessiz kalirsa dizi disi YAZMA)');

        LHata := '';
        try
          LSlots.Put(1, LBagimli);
          LSlots.Get(TRadEditSlots.CCount);
        except
          on E: Exception do LHata := E.ClassName;
        end;
        Kontrol('gecerli aralik (1..CCount) etkilenmedi', LHata = '',
          'atilan: ' + LHata);
      finally
        LSlots.Free;
      end;
    finally
      LIzle.Free;
      LForm.Free;
    end;

    Writeln;
    Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
    if GHata > 0 then
      Halt(1);
  except
    on E: Exception do
    begin
      Writeln('HATA: ', E.ClassName, ': ', E.Message);
      Halt(2);
    end;
  end;
end.
