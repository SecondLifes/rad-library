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
  TIzleyici = class
  public
    Sayac: Integer;
    SonSource: TComponent;
    SonMaster: TComponent;
    SonDeger: Variant;
    Yineleyen: TRadLookupComboBox;
    procedure Filtre(Sender: TRadLookupComboBoxProperties;
      ASource, AMaster: TComponent; const AMasterValue: Variant);
    procedure Sifirla;
  end;

procedure TIzleyici.Sifirla;
begin
  Sayac := 0;
  SonSource := nil;
  SonMaster := nil;
  SonDeger := Unassigned;
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
end;

var
  LForm: TForm;
  LIzle: TIzleyici;
  LUsta, LBagimli, LKopya, LKaynak, LHedef: TRadLookupComboBox;
  LUyari, LHata, LDenetim: string;
  LDugme: TButton;

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
