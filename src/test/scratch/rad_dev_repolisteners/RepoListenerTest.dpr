program RepoListenerTest;

(*
  Rad.Dev zincir altyapisi icin olcum sondasi.

  1) TcxEditRepositoryItem'den tuketici bilesenlere (formdaki editor / grid
     kolonu) ulasilabiliyor mu?  -> TRadEditRepositoryItem.Consumers
  2) Bir RepositoryItem'a bagli tuketiciler Properties'in AYNI ornegini mi
     paylasiyor?
  3) Kaskad gercekten tetikleniyor mu, ASource dogru geliyor mu?
  4) A -> B -> A dongusu kiriliyor mu?
  5) Ayni bilesen iki yuvada iken biri temizlenince digeri hala korunuyor mu?
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, Vcl.Forms, Vcl.Controls,
  cxEdit, cxDropDownEdit, cxLookupEdit, cxDBLookupEdit, cxDBLookupComboBox,
  cxGridCustomTableView, cxGridTableView, cxGridLevel, cxGrid,
  cxGraphics, cxControls, cxLookAndFeels, cxContainer, cxClasses,
  Rad.Dev;

type
  TIzleyici = class
  public
    Kayit: TStringList;
    AramaSayisi: Integer;
    constructor Create;
    destructor Destroy; override;
    procedure Kaskad(Sender: TRadLookupComboBoxProperties;
      ASource, ATarget: TComponent; const AValue: Variant);
    procedure DonguKaskad(Sender: TRadLookupComboBoxProperties;
      ASource, ATarget: TComponent; const AValue: Variant);
    procedure Arama(Sender: TRadLookupComboBoxProperties;
      ASource: TComponent; var AText, ATail: string; ANext: Boolean);
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
var
  GBasari: Integer = 0;
  GHata: Integer = 0;

(* RADDEV-008: bu sonda eskiden yalnizca YAZDIRIYORDU. Beklenen degerler
   parantez icinde metin olarak duruyordu; yanlis bir sonuc hicbir sey
   bozmuyor, cikis kodu 0 kaliyordu - yani sonda bir KAPI degildi.
   Kontrol, her iddiayi gercek bir assert'e cevirir ve hata varsa program
   non-zero ile biter. *)
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

procedure Sonuc;
begin
  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    Halt(1);
end;


constructor TIzleyici.Create;
begin
  inherited Create;
  Kayit := TStringList.Create;
end;

destructor TIzleyici.Destroy;
begin
  Kayit.Free;
  inherited Destroy;
end;

procedure TIzleyici.Kaskad(Sender: TRadLookupComboBoxProperties;
  ASource, ATarget: TComponent; const AValue: Variant);
begin
  Kayit.Add(Format('kaynak=%s hedef=%s deger=%s alan=%s',
    [Ad(ASource), Ad(ATarget), VarToStr(AValue), Sender.ACascadeField]));
end;

procedure TIzleyici.DonguKaskad(Sender: TRadLookupComboBoxProperties;
  ASource, ATarget: TComponent; const AValue: Variant);
begin
  Kayit.Add(Format('dongu: kaynak=%s hedef=%s', [Ad(ASource), Ad(ATarget)]));
  { Hedefe deger yaziyoruz - hedef de bize geri zincirli. Koruma yoksa
    burada sonsuz doner. }
  if ATarget is TRadLookupComboBox then
    TRadLookupComboBox(ATarget).EditValue := VarToStr(AValue) + '+';
end;

procedure TIzleyici.Arama(Sender: TRadLookupComboBoxProperties;
  ASource: TComponent; var AText, ATail: string; ANext: Boolean);
begin
  Inc(AramaSayisi);
  Kayit.Add('arama: "' + AText + '"');
end;

function AyniMi(A, B: TObject): string;
begin
  if Pointer(A) = Pointer(B) then
    Result := 'AYNI ORNEK'
  else
    Result := 'FARKLI';
end;

var
  LForm: TForm;
  LRepo: TcxEditRepository;
  LItem: TRadLookupComboBoxRepository;
  LUlke, LSehir, LIlce: TRadLookupComboBox;
  LGrid: TcxGrid;
  LLevel: TcxGridLevel;
  LView: TcxGridTableView;
  LCol: TcxGridColumn;
  LIzle: TIzleyici;
  i: Integer;
  LDizi: string;
  LC: TComponent;

begin
  try
    Application.Initialize;
    LForm := TForm.CreateNew(nil);
    LIzle := TIzleyici.Create;
    try
      LUlke  := TRadLookupComboBox.Create(LForm);  LUlke.Name  := 'Ulke';   LUlke.Parent  := LForm;
      LSehir := TRadLookupComboBox.Create(LForm);  LSehir.Name := 'Sehir';  LSehir.Parent := LForm;
      LIlce  := TRadLookupComboBox.Create(LForm);  LIlce.Name  := 'Ilce';   LIlce.Parent  := LForm;

      Writeln('=== 1) Tuketici listesi ===');
      LRepo := TcxEditRepository.Create(LForm);
      LItem := TRadLookupComboBoxRepository.Create(LForm);
      LItem.Repository := LRepo;
      LItem.Name := 'OrtakItem';
      Writeln('baslangic          : ', LItem.ConsumerCount);

      LUlke.RepositoryItem := LItem;
      Writeln('editor baglandi    : ', LItem.ConsumerCount);

      LGrid := TcxGrid.Create(LForm);
      LGrid.Parent := LForm;
      LLevel := LGrid.Levels.Add;
      LView := LGrid.CreateView(TcxGridTableView) as TcxGridTableView;
      LLevel.GridView := LView;
      LCol := LView.CreateColumn;
      LCol.Caption := 'SehirKolonu';
      LCol.RepositoryItem := LItem;
      Writeln('kolon da baglandi  : ', LItem.ConsumerCount);
      Kontrol('editor + kolon -> iki tuketici', LItem.ConsumerCount = 2,
        Format('ConsumerCount = %d', [LItem.ConsumerCount]));
      for i := 0 to LItem.ConsumerCount - 1 do
      begin
        LC := LItem.Consumers(i);
        if LC = nil then
          Writeln(Format('  [%d] cozulemedi', [i]))
        else
          Writeln(Format('  [%d] %-22s %s', [i, LC.ClassName, Ad(LC)]));
      end;

      Writeln;
      Writeln('=== 2) Properties: ornek mi kopya mi? ===');
      Writeln('editor.ActiveProperties vs item.Properties : ',
        AyniMi(LUlke.ActiveProperties, LItem.Properties));
      Writeln('kolon.Properties (published) nil mi        : ',
        BoolToStr(LCol.Properties = nil, True));
      Writeln('kolon.GetProperties     vs item.Properties : ',
        AyniMi(LCol.GetProperties, LItem.Properties));

      Kontrol('editor ve kolon Properties ORNEGINI paylasiyor',
        (LUlke.ActiveProperties = LItem.Properties) and
        (LCol.GetProperties = LItem.Properties));
      Kontrol('kolonun published Properties i nil (item bagliyken)',
        LCol.Properties = nil);
      { Bundan sonrasi repository'siz, dogrudan editor Properties'i uzerinden }
      LUlke.RepositoryItem := nil;
      Writeln('item koparildi, kalan tuketici             : ', LItem.ConsumerCount);
      Kontrol('kopma sonrasi tek tuketici kaldi', LItem.ConsumerCount = 1,
        Format('ConsumerCount = %d', [LItem.ConsumerCount]));

      Writeln;
      Writeln('=== 3) Kaskad tetikleniyor mu? ===');
      LUlke.Properties.ACascadeField := 'ulke_id';
      LUlke.Properties.AComponent1 := LSehir;
      LUlke.Properties.AComponent2 := LIlce;
      LUlke.Properties.AOnCascade := LIzle.Kaskad;
      LIzle.Kayit.Clear;
      LUlke.EditValue := 'TR';
      Writeln('olay sayisi: ', LIzle.Kayit.Count, ' (beklenen 2)');
      Kontrol('iki dolu yuva -> iki kaskad olayi', LIzle.Kayit.Count = 2,
        Format('olay = %d', [LIzle.Kayit.Count]));
      for i := 0 to LIzle.Kayit.Count - 1 do
        Writeln('  ', LIzle.Kayit[i]);

      Writeln;
      Writeln('=== 4) A -> B -> A dongusu ===');
      LUlke.Properties.AComponent2 := nil;
      LUlke.Properties.AOnCascade := LIzle.DonguKaskad;
      LSehir.Properties.AComponent1 := LUlke;          { geri baglanti }
      LSehir.Properties.AOnCascade := LIzle.DonguKaskad;
      LIzle.Kayit.Clear;
      LUlke.EditValue := 'X';
      Writeln('olay sayisi: ', LIzle.Kayit.Count, ' (sonlu ise koruma calisti)');
      Kontrol('A->B->A dongusu kirildi (sonlu olay sayisi)',
        (LIzle.Kayit.Count > 0) and (LIzle.Kayit.Count <= 4),
        Format('olay = %d; sinirsiz olsaydi yigin tukenirdi',
          [LIzle.Kayit.Count]));
      for i := 0 to LIzle.Kayit.Count - 1 do
        Writeln('  ', LIzle.Kayit[i]);

      Writeln;
      Writeln('=== 5) Ayni bilesen iki yuvada ===');
      LUlke.Properties.AOnCascade := nil;
      LSehir.Properties.AOnCascade := nil;
      LSehir.Properties.AComponent1 := nil;
      LUlke.Properties.AComponent1 := LSehir;
      LUlke.Properties.AComponent2 := LSehir;   { AYNI bilesen, iki yuva }
      LUlke.Properties.AComponent1 := nil;      { birini temizle }
      Writeln('yuva1=', Ad(LUlke.Properties.AComponent1),
              '  yuva2=', Ad(LUlke.Properties.AComponent2));
      LSehir.Free;                               { hedefi yok et }
      Writeln('Sehir yok edildi -> yuva2 = ', Ad(LUlke.Properties.AComponent2),
              '   (nil olmali; degilse sarkan isaretci)');
      Kontrol('hedef yok edilince KALAN yuva da nil-lendi',
        LUlke.Properties.AComponent2 = nil,
        'nil degilse sarkan isaretci - ilk erisimde erisim ihlali');
      Writeln;
      Writeln('=== 6) DoAssign: zincir yuku kopyalaniyor mu? ===');
      var LKaynak := TRadLookupComboBox.Create(LForm);
      LKaynak.Name := 'Kaynak'; LKaynak.Parent := LForm;
      var LHedefE := TRadLookupComboBox.Create(LForm);
      LHedefE.Name := 'HedefE'; LHedefE.Parent := LForm;
      LKaynak.Properties.ACascadeField := 'ulke_id';
      LKaynak.Properties.ACascadeTag := 7;
      LKaynak.Properties.ASearchDelay := 350;
      LKaynak.Properties.AComponent1 := LHedefE;
      LKaynak.Properties.AOnCascade := LIzle.Kaskad;

      var LKopya := TRadLookupComboBox.Create(LForm);
      LKopya.Name := 'Kopya'; LKopya.Parent := LForm;
      LKopya.Properties := LKaynak.Properties;   { -> Assign -> DoAssign }

      Writeln('  CascadeField : "', LKopya.Properties.ACascadeField, '"  (ulke_id)');
      Writeln('  CascadeTag   : ', LKopya.Properties.ACascadeTag, '  (7)');
      Writeln('  SearchDelay  : ', LKopya.Properties.ASearchDelay, '  (350)');
      Writeln('  AComponent1  : ', Ad(LKopya.Properties.AComponent1), '  (HedefE)');
      Writeln('  OnCascade    : ', BoolToStr(Assigned(LKopya.Properties.AOnCascade), True));
      Writeln('  ChainSlotCount: ', LKopya.Properties.ChainSlotCount, '  (1)');

      Writeln;
      Writeln('  -> kopyanin yuvasi da korumali mi? (HedefE yok edilince)');
      LHedefE.Free;
      Writeln('     kaynak.AComponent1 = ', Ad(LKaynak.Properties.AComponent1),
              '   kopya.AComponent1 = ', Ad(LKopya.Properties.AComponent1),
              '   (ikisi de <nil> olmali)');
      Kontrol('DoAssign zincir yukunu tasidi',
        (LKopya.Properties.ACascadeField = 'ulke_id') and
        (LKopya.Properties.ACascadeTag = 7) and
        (LKopya.Properties.ASearchDelay = 350) and
        Assigned(LKopya.Properties.AOnCascade));
      Kontrol('kopyanin yuvasi da serbest-birakma korumali',
        (LKaynak.Properties.AComponent1 = nil) and
        (LKopya.Properties.AComponent1 = nil));

      Writeln;
      Writeln('=== 7) ChainWarning ===');
      var LRepo2 := TRadLookupComboBoxRepository.Create(LForm);
      LRepo2.Name := 'ZincirliItem';
      LRepo2.Repository := LRepo;
      var LT := TRadLookupComboBox.Create(LForm); LT.Name := 'T'; LT.Parent := LForm;
      LRepo2.Properties.AComponent1 := LT;
      var LA := TRadLookupComboBox.Create(LForm); LA.Name := 'A'; LA.Parent := LForm;
      LA.RepositoryItem := LRepo2;
      Writeln('  tek tuketici : "', LRepo2.ChainWarning, '"  (bos olmali)');
      var LB := TRadLookupComboBox.Create(LForm); LB.Name := 'B'; LB.Parent := LForm;
      LB.RepositoryItem := LRepo2;
      Writeln('  iki tuketici : ', Copy(LRepo2.ChainWarning, 1, 90), '...');
      LRepo2.Properties.AComponent1 := nil;
      Writeln('  zincir bosalt: "', LRepo2.ChainWarning, '"  (bos olmali)');
      Kontrol('zincir bosalinca ChainWarning susuyor',
        LRepo2.ChainWarning = '', '"' + LRepo2.ChainWarning + '"');
      Writeln;
      Writeln('=== 8) MinSearchLength (E-01) ===');
      LDizi := '';
      var LArama := TRadLookupComboBox.Create(LForm);
      LArama.Name := 'Arama'; LArama.Parent := LForm;
      LArama.Properties.AOnSearch := LIzle.Arama;
      LArama.Properties.AMinSearchLength := 3;
      { Genel giris noktasi TimedSearch (public); DoSearch protected. }
      for var Metin in ['a', 'an', 'ank', 'anka', ''] do
      begin
        LIzle.AramaSayisi := 0;
        LArama.Properties.TimedSearch(LArama, Metin);
        Writeln(Format('  "%s" (%d harf) -> OnSearch %d kez',
          [Metin, Length(Metin), LIzle.AramaSayisi]));
        if LDizi <> '' then
          LDizi := LDizi + ',';
        LDizi := LDizi + IntToStr(LIzle.AramaSayisi);
      end;
      Writeln('  beklenen: 0,0,1,1,1  (bos metin "hepsini goster" demek, gecer)');
      Kontrol('AMinSearchLength dizisi 0,0,1,1,1',
        LDizi = '0,0,1,1,1', 'olculen: ' + LDizi);

      Writeln;
      Writeln('=== 9) ClearTargetsOnCascade (E-02) ===');
      var LKay := TRadLookupComboBox.Create(LForm); LKay.Name := 'Kay'; LKay.Parent := LForm;
      var LHed := TRadLookupComboBox.Create(LForm); LHed.Name := 'Hed'; LHed.Parent := LForm;
      LKay.Properties.AComponent1 := LHed;
      LKay.Properties.AOnCascade := LIzle.Kaskad;
      LHed.EditValue := 'ESKI-SEHIR';
      Writeln('  kapaliyken:');
      LKay.EditValue := 'TR';
      Writeln('    hedef.EditValue = "', VarToStr(LHed.EditValue), '"  (ESKI-SEHIR kalmali)');
      Kontrol('kapaliyken hedefin degeri KORUNUYOR',
        VarToStr(LHed.EditValue) = 'ESKI-SEHIR');
      LKay.Properties.AClearTargetsOnCascade := True;
      LHed.EditValue := 'ESKI-SEHIR';
      Writeln('  aciksa:');
      LKay.EditValue := 'DE';
      Writeln('    hedef.EditValue = "', VarToStr(LHed.EditValue), '"  (bos olmali)');
      Kontrol('aciksa hedefin degeri TEMIZLENIYOR',
        VarToStr(LHed.EditValue) = '');

      Writeln;
      Writeln('=== 10) CascadeNow (E-03) ===');
      LIzle.Kayit.Clear;
      LKay.Properties.AClearTargetsOnCascade := False;
      LKay.CascadeNow;
      Writeln('  CascadeNow -> olay sayisi: ', LIzle.Kayit.Count, ' (1 beklenir)');
      Kontrol('CascadeNow tam bir olay uretiyor', LIzle.Kayit.Count = 1,
        Format('olay = %d', [LIzle.Kayit.Count]));
      for i := 0 to LIzle.Kayit.Count - 1 do
        Writeln('    ', LIzle.Kayit[i]);
    finally
      LIzle.Free;
      LForm.Free;
    end;
    Sonuc;
  except
    on E: Exception do
    begin
      Writeln('HATA: ', E.ClassName, ': ', E.Message);
      Halt(2);
    end;
  end;
end.
