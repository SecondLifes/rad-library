program DbNavTest;

{$APPTYPE CONSOLE}

(* TRadDBLookupComboBox - kayitta GEZINME.

   Soru: bir DB editoru kayit degisince kaskadi tetikliyor mu, ve tetikliyorsa
   AClearTargetsOnCascade hedefin DEGERINI temizliyor mu?

   Kaynak zinciri (26.1.4): kayit degisir -> TcxDBEditDataBinding.DataChanged
   -> Edit.EditValue := StoredValue (cxDBEdit.pas:2279) -> InternalSetEditValue
   -> DoEditValueChanged (cxEdit.pas:5706-5708) -> Rad.Dev DoCascade.

   Beklenen dogru davranis: gezinmede hedefin DEGERI yeni kayittan gelir,
   temizlenmez; ama GECERSIZ KILMA sinyali (onbellek sifirlama + AOnCascade)
   yine gider - hedefin listesi eski master'a gore suzulmustu.
   Veri DISI bir degisiklikte (kod ya da kullanici) temizleme calismaya devam
   eder. *)

uses
  System.SysUtils, System.Classes, System.Variants, Vcl.Forms, Vcl.Controls,
  Data.DB, VirtualTable,
  cxEdit, cxDBLookupComboBox,
  Rad.Dev;

type
  TOlay = class
  public
    KaskadSayisi, NullSayisi: Integer;
    Liste: TDataSet;   { SehirBul'un satir ekleyecegi liste }
    procedure SehirBul(Sender: TRadLookupComboBoxProperties; ASource: TComponent;
      const AKey: Variant);
    procedure Kaskad(Sender: TRadLookupComboBoxProperties;
      ASource, ATarget: TComponent; const AValue: Variant);
    procedure SehirDegisti(Sender: TObject);
    procedure Sifirla;
  end;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;

procedure TOlay.Kaskad(Sender: TRadLookupComboBoxProperties;
  ASource, ATarget: TComponent; const AValue: Variant);
begin
  Inc(KaskadSayisi);
end;

procedure TOlay.SehirDegisti(Sender: TObject);
begin
  if VarIsNull(TcxCustomEdit(Sender).EditValue) then
    Inc(NullSayisi);
end;

procedure TOlay.SehirBul(Sender: TRadLookupComboBoxProperties; ASource: TComponent;
  const AKey: Variant);
begin
  { Sunucudan tek satir cekmenin yerine: anahtar listede yoksa ekle. }
  if (Liste <> nil) and not Liste.Locate('id', AKey, []) then
    Liste.AppendRecord([AKey, 'Paris']);
end;

procedure TOlay.Sifirla;
begin
  KaskadSayisi := 0;
  NullSayisi := 0;
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

function Tablo(AOwner: TComponent; AMetin: Boolean): TVirtualTable;
begin
  Result := TVirtualTable.Create(AOwner);
  Result.AddField('id', ftInteger);
  if AMetin then
    Result.AddField('ad', ftString, 30);
end;

function Editor(AForm: TForm; AKayit, AListe: TDataSource;
  const AAlan: string): TRadDBLookupComboBox;
begin
  Result := TRadDBLookupComboBox.Create(AForm);
  Result.Parent := AForm;
  Result.Properties.ListSource := AListe;
  Result.Properties.KeyFieldNames := 'id';
  Result.Properties.ListFieldNames := 'ad';
  Result.DataBinding.DataSource := AKayit;
  Result.DataBinding.DataField := AAlan;
end;

procedure SonradanAtama(AForm: TForm; ADsSehirB: TDataSource; AOlay: TOlay);
var
  LKayit, LListeA, LListeC: TVirtualTable;
  LDsKayit, LDsA, LDsC: TDataSource;
  LEd1, LEd2: TRadDBLookupComboBox;
begin
  LKayit := TVirtualTable.Create(AForm);
  LKayit.AddField('sehir_id', ftInteger);
  LKayit.Open;
  LKayit.AppendRecord([30]);          { Paris - A listesinde YOK }
  LDsKayit := TDataSource.Create(AForm);
  LDsKayit.DataSet := LKayit;

  LListeA := Tablo(AForm, True);
  LListeA.Open;
  LListeA.AppendRecord([10, 'Istanbul']);
  LDsA := TDataSource.Create(AForm);
  LDsA.DataSet := LListeA;

  { 1) AOnLocate sonradan }
  LEd1 := Editor(AForm, LDsKayit, LDsA, 'sehir_id');
  Kontrol('S00 isleyicisiz, listede olmayan anahtar -> metin bos',
    LEd1.Text = '', '"' + LEd1.Text + '"');
  AOlay.Liste := LListeA;
  LEd1.Properties.AOnLocate := AOlay.SehirBul;
  Kontrol('S01 AOnLocate atanince metin cozuldu (Paris)', LEd1.Text = 'Paris',
    '"' + LEd1.Text + '"');
  AOlay.Liste := nil;

  { 2) ListSource sonradan: C listesinde 30 yok, B'de var. }
  if not ADsSehirB.DataSet.Locate('id', 30, []) then
    ADsSehirB.DataSet.AppendRecord([30, 'Paris']);
  LListeC := Tablo(AForm, True);
  LListeC.Open;
  LListeC.AppendRecord([10, 'Istanbul']);
  LDsC := TDataSource.Create(AForm);
  LDsC.DataSet := LListeC;
  LEd2 := Editor(AForm, LDsKayit, LDsC, 'sehir_id');
  Kontrol('S02 C listesinde metin bos', LEd2.Text = '', '"' + LEd2.Text + '"');
  LEd2.Properties.ListSource := ADsSehirB;
  Kontrol('S03 ListSource degisince metin yeni listeden cozuldu (Paris)',
    LEd2.Text = 'Paris', '"' + LEd2.Text + '"');
end;

var
  LOlay: TOlay;
  LForm: TForm;
  LKayit, LUlkeL, LSehirL: TVirtualTable;
  LDsKayit, LDsUlke, LDsSehir: TDataSource;
  LUlke, LSehir: TRadDBLookupComboBox;

begin
  Application.Initialize;
  LOlay := TOlay.Create;
  try
    LForm := TForm.CreateNew(nil);
    try
      LKayit := TVirtualTable.Create(LForm);
      LKayit.AddField('ulke_id', ftInteger);
      LKayit.AddField('sehir_id', ftInteger);
      LKayit.Open;
      LKayit.AppendRecord([1, 10]);
      LKayit.AppendRecord([2, 20]);
      LKayit.First;

      LUlkeL := Tablo(LForm, True);
      LUlkeL.Open;
      LUlkeL.AppendRecord([1, 'Turkiye']);
      LUlkeL.AppendRecord([2, 'Almanya']);

      LSehirL := Tablo(LForm, True);
      LSehirL.Open;
      LSehirL.AppendRecord([10, 'Istanbul']);
      LSehirL.AppendRecord([20, 'Berlin']);

      LDsKayit := TDataSource.Create(LForm);
      LDsKayit.DataSet := LKayit;
      LDsUlke := TDataSource.Create(LForm);
      LDsUlke.DataSet := LUlkeL;
      LDsSehir := TDataSource.Create(LForm);
      LDsSehir.DataSet := LSehirL;

      { Ulke ONCE baglaniyor: datalink'i kayit kaynaginda once bildirim alir,
        yani gezinmede kaskadi, sehir editoru kendi degerini tazelemeden ONCE
        calistirir. }
      LUlke := Editor(LForm, LDsKayit, LDsUlke, 'ulke_id');
      LSehir := Editor(LForm, LDsKayit, LDsSehir, 'sehir_id');

      LUlke.Properties.AComponent1 := LSehir;
      LUlke.Properties.AClearTargetsOnCascade := True;
      LUlke.Properties.AOnCascade := LOlay.Kaskad;
      LSehir.Properties.OnEditValueChanged := LOlay.SehirDegisti;

      Writeln;
      Writeln('=== Kayitta gezinme ===');
      Kontrol('D00 baslangicta sehir editoru 10', VarToStr(LSehir.EditValue) = '10',
        VarToStr(LSehir.EditValue));

      LOlay.Sifirla;
      LKayit.Next;
      Writeln('  [BILGI] gezinmede kaskad sayisi: ', LOlay.KaskadSayisi,
        ', sehir editorunun Null oldugu an sayisi: ', LOlay.NullSayisi);

      Kontrol('D01 sehir editoru yeni kaydin degerini gosteriyor (20)',
        VarToStr(LSehir.EditValue) = '20', VarToStr(LSehir.EditValue));
      Kontrol('D02 gezinmede sehir editoru HIC Null olmadi (deger temizlenmedi)',
        LOlay.NullSayisi = 0, Format('%d kez Null', [LOlay.NullSayisi]));
      Kontrol('D03 kayit dataset''i dsBrowse kaldi', LKayit.State = dsBrowse);
      Kontrol('D04 sehir alani degismedi (20)',
        LKayit.FieldByName('sehir_id').AsInteger = 20,
        LKayit.FieldByName('sehir_id').AsString);
      Kontrol('D05 gecersiz kilma sinyali gezinmede YINE gidiyor (kaskad >= 1)',
        LOlay.KaskadSayisi >= 1, IntToStr(LOlay.KaskadSayisi));

      Writeln;
      Writeln('=== Veri disi degisiklik ===');
      LOlay.Sifirla;
      LUlke.EditValue := 1;
      Kontrol('D06 kodla degisen ulke sehir editorunu hala temizliyor',
        LOlay.NullSayisi >= 1, Format('%d kez Null', [LOlay.NullSayisi]));
      Kontrol('D07 temizleme kayda YAZMADI (dsBrowse)', LKayit.State = dsBrowse);

      (* ── Sonradan atanan AOnLocate / ListSource ─────────────────────────
         Editor veriye BAGLANDIKTAN sonra atanirlar - kodla kurulan formlarda
         olur. Ilk metin, anahtar listede yokken ve isleyici yokken BOS
         cozulur ve kitin metin onbellegine yazilir. Atama onbellegi
         sifirlamazsa editor bos kalir. (DbLookupLiveTest'in ilk surumu bunu
         canli veritabaninda yakaladi.) *)
      Writeln;
      Writeln('=== Sonradan atanan AOnLocate / ListSource ===');
      SonradanAtama(LForm, LDsSehir, LOlay);
    finally
      LForm.Free;
    end;
  finally
    LOlay.Free;
  end;

  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    ExitCode := 1;
end.
