program FilterEditTest;

(* Help.Dev._EditToFilter: editor turune gore kosul. Veritabani yok, gizli form kullanir.
   build_and_run.bat ile derlenmez: Help.Dev IDE kutuphane yollarini ister (ERPPlus.dproj kopyasiyla derlenir). *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Variants, Vcl.Forms, Vcl.Controls,
  cxEdit, cxTextEdit, cxMaskEdit, cxButtonEdit, cxDropDownEdit, cxCalendar, cxImageComboBox,
  cxCheckComboBox, cxCurrencyEdit, cxCheckBox, cxLookAndFeelPainters,
  mormot.core.base, mormot.core.variants, rad.sqlfilter, Help.Dev, help.mormot;

type
  // base.filtre kayitli filtre bicimi
  TDeger = record
    Alan: string;
    Ilk, Son: Variant;
  end;

  TKayit = record
    Ad, Arama: string;
    Degerler: TArray<TDeger>;
  end;

  TKayitlar = record
    Kayitlar: TArray<TKayit>;
  end;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;
  Form: TForm;

procedure Esit(const AAd, ABeklenen, AGercek: string);
begin
  if ABeklenen = AGercek then
  begin
    Inc(GBasari);
    Writeln('  [OK]   ', AAd);
  end
  else
  begin
    Inc(GHata);
    Writeln('  [HATA] ', AAd, '  beklenen=[', ABeklenen, '] gercek=[', AGercek, ']');
  end;
end;

function Sonuc(AEdit: TcxCustomEdit): string;
var
  F: IRadSqlFilter;
  P: TRadSqlParam;
begin
  F := TRadSqlFilter.New;
  _EditToFilter(F, 'a.x', AEdit);
  Result := F.GetConditions;
  for P in F.Params do
    Result := Result + ' | ' + VarToStr(P.Value) + ':' + IntToStr(VarType(P.Value));
end;

// Config gibi: JSON metnine yazilip geri okunur.
function GidisDonus(const AKayitlar: TKayitlar): TKayitlar;
var
  D1, D2: TDocVariantData;
  LGiris: TKayitlar;
  LJson: RawUtf8;
begin
  LGiris := AKayitlar;
  D1.InitFast(dvObject);
  D1._RecordSave<TKayitlar>('Filtre.Tkasa_liste', LGiris);
  LJson := D1.ToJson;
  Writeln('   (bilgi) ', string(LJson));
  D2.InitJson(LJson, JSON_FAST);
  Result := Default(TKayitlar);
  D2._RecordLoad<TKayitlar>('Filtre.Tkasa_liste', Result);
end;

function Metin(ACls: TcxCustomEditClass): TcxCustomEdit;
begin
  Result := ACls.Create(Form);
  Result.Parent := Form;
end;

function Durum(AState: TcxCheckBoxState): string;
begin
  if AState = cbsChecked then
    Result := 'cbsChecked'
  else
    Result := 'cbsUnchecked';
end;

var
  E: TcxCustomEdit;
  I: TcxImageComboBox;
  D: TcxDateEdit;
  C: TcxCurrencyEdit;
  T: TcxTextEdit;
  LK, LG: TKayitlar;
  K: TcxCheckComboBox;
  LItem: TcxImageComboBoxItem;
begin
  Application.Initialize;
  Form := TForm.Create(nil);
  try
    try
      E := Metin(TcxTextEdit);
      Esit('E01 bos metin', '', Sonuc(E));
      E.EditValue := 'ali';
      Esit('E02 metin Contains', 'a.x ILIKE :p1 ESCAPE ''!''', Copy(Sonuc(E), 2, Pos(')', Sonuc(E)) - 2));
      E := Metin(TcxButtonEdit);
      E.EditValue := 'b';
      Esit('E03 button Contains', True.ToString, (Pos('ILIKE', Sonuc(E)) > 0).ToString);
      E := Metin(TcxMaskEdit);
      E.EditValue := 'c';
      Esit('E04 mask Contains', True.ToString, (Pos('ILIKE', Sonuc(E)) > 0).ToString);

      I := TcxImageComboBox.Create(Form);
      I.Parent := Form;
      LItem := I.Properties.Items.Add;
      LItem.Description := 'Tumu';
      LItem.Value := '';
      LItem := I.Properties.Items.Add;
      LItem.Description := 'Aktif';
      LItem.Value := True;
      LItem := I.Properties.Items.Add;
      LItem.Description := 'Pasif';
      LItem.Value := False;
      Esit('E05 image combo bos', '', Sonuc(I));
      I.EditValue := '';
      Esit('E06 image combo Tumu', '', Sonuc(I));
      I.EditValue := True;
      Esit('E07 image combo Aktif', '(a.x = :p1) | True:' + IntToStr(varBoolean), Sonuc(I));
      I.EditValue := False;
      Esit('E08 image combo Pasif boolean False', '(a.x = :p1) | False:' + IntToStr(varBoolean), Sonuc(I));

      K := TcxCheckComboBox.Create(Form);
      K.Parent := Form;
      K.Properties.Items.AddCheckItem('TRY');
      K.Properties.Items.AddCheckItem('USD');
      K.Properties.Items.AddCheckItem('EUR');
      Esit('E09 check combo bos', '', Sonuc(K));
      K.States[1] := cbsChecked;
      K.States[2] := cbsChecked;
      Esit('E10 check combo InList', '(a.x IN (:p1, :p2)) | USD:' + IntToStr(varUString) + ' | EUR:' + IntToStr(varUString), Sonuc(K));

      E := Metin(TcxDateEdit);
      Esit('E11 tarih bos', '', Sonuc(E));
      E.EditValue := EncodeDate(2026, 11, 2);
      Esit('E12 tarih tam gun', True.ToString, (Pos('>=', Sonuc(E)) > 0).ToString);

      E := Metin(TcxCurrencyEdit);
      E.EditValue := Null;
      Esit('E13 para bos', '', Sonuc(E));
      E.EditValue := 0;
      Esit('E14 para sifir bos degil', True.ToString, (Pos('= :p1', Sonuc(E)) > 0).ToString);

      E := Metin(TcxCheckBox);
      TcxCheckBox(E).Properties.AllowGrayed := True;
      TcxCheckBox(E).State := cbsGrayed;
      Esit('E15 onay gri', '', Sonuc(E));
      TcxCheckBox(E).State := cbsChecked;
      Esit('E16 onay isaretli', True.ToString, (Pos('= :p1', Sonuc(E)) > 0).ToString);

      Writeln('=== Kayitli filtre: JSON gidis donus + editore yazma ===');
      K.Properties.EditValueFormat := cvfCaptions;
      K.States[0] := cbsChecked;
      K.States[1] := cbsChecked;
      K.States[2] := cbsUnchecked;
      D := TcxDateEdit.Create(Form);
      D.Parent := Form;
      D.Date := EncodeDate(2026, 11, 2);
      C := TcxCurrencyEdit.Create(Form);
      C.Parent := Form;
      C.EditValue := 1234.5;
      I.EditValue := False;
      T := TcxTextEdit.Create(Form);
      T.Parent := Form;
      T.EditValue := 'Ali & Veli';

      LK := Default(TKayitlar);
      SetLength(LK.Kayitlar, 1);
      LK.Kayitlar[0].Ad := 'Pasif kasalar';
      LK.Kayitlar[0].Arama := '> 1';
      SetLength(LK.Kayitlar[0].Degerler, 5);
      LK.Kayitlar[0].Degerler[0].Alan := 'k.aktif_mi';
      LK.Kayitlar[0].Degerler[0].Ilk := I.EditValue;
      LK.Kayitlar[0].Degerler[0].Son := Null;
      LK.Kayitlar[0].Degerler[1].Alan := 'b.doviz';
      LK.Kayitlar[0].Degerler[1].Ilk := _EditGetValue(K);
      LK.Kayitlar[0].Degerler[2].Alan := 'h.tarih';
      LK.Kayitlar[0].Degerler[2].Ilk := D.EditValue;
      LK.Kayitlar[0].Degerler[3].Alan := 'h.tutar';
      LK.Kayitlar[0].Degerler[3].Ilk := C.EditValue;
      LK.Kayitlar[0].Degerler[4].Alan := 'k.ad';
      LK.Kayitlar[0].Degerler[4].Ilk := T.EditValue;

      LG := GidisDonus(LK);
      Esit('K01 ad', 'Pasif kasalar', LG.Kayitlar[0].Ad);
      Esit('K02 arama', '> 1', LG.Kayitlar[0].Arama);
      Esit('K03 satir sayisi', '5', IntToStr(Length(LG.Kayitlar[0].Degerler)));
      Esit('K03b check combo dilden bagimsiz', '["TRY","USD"]', VarToStr(_EditGetValue(K)));

      I.Clear;
      _EditSetValue(I, LG.Kayitlar[0].Degerler[0].Ilk);
      Esit('K04 boolean editor metni', 'Pasif', I.Text);
      Esit('K05 boolean kosul', '(a.x = :p1) | False:' + IntToStr(varBoolean), Sonuc(I));

      K.Clear;
      Esit('K06 check combo bosaldi', '', Sonuc(K));
      _EditSetValue(K, LG.Kayitlar[0].Degerler[1].Ilk);
      Esit('K07 check combo geri', 'cbsChecked cbsChecked cbsUnchecked',
        Format('%s %s %s', [Durum(K.States[0]), Durum(K.States[1]), Durum(K.States[2])]));
      Esit('K07b check combo kosulu', True.ToString, (Pos('IN (:p1, :p2)', Sonuc(K)) > 0).ToString);

      D.Clear;
      _EditSetValue(D, LG.Kayitlar[0].Degerler[2].Ilk);
      Esit('K08 tarih geri', DateToStr(EncodeDate(2026, 11, 2)), DateToStr(D.Date));

      C.Clear;
      _EditSetValue(C, LG.Kayitlar[0].Degerler[3].Ilk);
      Esit('K09 sayi geri', '1234.5', FloatToStr(C.Value, TFormatSettings.Invariant));

      T.Clear;
      _EditSetValue(T, LG.Kayitlar[0].Degerler[4].Ilk);
      Esit('K10 metin geri', 'Ali & Veli', T.Text);
    except
      on Ex: Exception do
      begin
        Inc(GHata);
        Writeln('  [PATLADI] ', Ex.ClassName, ': ', Ex.Message);
      end;
    end;
  finally
    Form.Free;
  end;
  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    Halt(1);
end.
