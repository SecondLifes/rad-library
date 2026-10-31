program CheckComboTest;

{$APPTYPE CONSOLE}

(* TRadCheckComboBox - deger tasiyan check combo, olay yazmadan.

   Items      : TRadCheckComboBoxItems, her item Description + Value; tabanin Items'i
                ona aynalanir. Items.AddItem('Aktif', 't').
   EditValue  : secili degerler ayracla ('A;AS'); AValues dizi olarak alir/yukler.
   AValuesIn  : "cari_tip in ('A','AS')".

   Help.Dev EN SONDA: yalnizca en yakin class helper gorunur. *)

uses
  System.SysUtils, System.Classes, System.Variants, Vcl.Forms, Vcl.Controls,
  Data.DB, VirtualTable,
  cxEdit, cxLookAndFeelPainters, cxCheckBox, cxCheckComboBox, cxDBCheckComboBox,
  Rad.Dev,
  Help.Dev;

type
  TDfmForm = class(TForm);

  TOlay = class
  public
    Sayac: Integer;
    procedure StatesToValue(Sender: TObject; const ACheckStates: TcxCheckStates;
      out AValue: TcxEditValue);
  end;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;

procedure TOlay.StatesToValue(Sender: TObject; const ACheckStates: TcxCheckStates;
  out AValue: TcxEditValue);
begin
  Inc(Sayac);
  AValue := 'OLAY';
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

function Dizi(const A: TArray<string>): string;
begin
  Result := string.Join('|', A);
end;

procedure Kur(AProps: TRadCheckComboBoxProperties);
begin
  AProps.Items.Clear;
  AProps.Items.AddItem('Alici', 'A');
  AProps.Items.AddItem('Satici', 'S');
  AProps.Items.AddItem('Alici ve Satici', 'AS');
end;

function Taban(AProps: TRadCheckComboBoxProperties): TcxCheckComboBoxItems;
begin
  Result := TcxCheckComboBoxProperties(AProps).Items;   { golgelenen stok koleksiyon }
end;

procedure Temel;
var
  LForm: TForm;
  LCb: TRadCheckComboBox;
  LProps: TRadCheckComboBoxProperties;
  i: Integer;
begin
  Writeln;
  Writeln('=== Temel ===');
  LForm := TForm.CreateNew(nil);
  try
    LCb := TRadCheckComboBox.Create(LForm);
    LCb.Parent := LForm;
    LProps := LCb.Properties;
    { Kullanici senaryosu: Items tasarimcida, her item'da Description + Value. }
    LProps.Items.AddItem('Aktif', 't');
    LProps.Items.AddItem('Pasif', 'f');
    LCb.AValues := ['t'];
    Kontrol('K00 gorunen metin Description (Aktif), EditValue Value (t)',
      (LCb.Text = 'Aktif') and (VarToStr(LCb.EditValue) = 't'), LCb.Text + '/' + VarToStr(LCb.EditValue));
    Kontrol('K00b taban Items aynalandi (2, Aktif)', (Taban(LProps).Count = 2) and
      (Taban(LProps)[0].Description = 'Aktif') and (Taban(LProps)[0] is TcxCheckComboBoxItem));
    LProps.Items[1].Value := 'x';
    Kontrol('K00c Value degisince Description ve taban sabit',
      (LProps.Items[1].Description = 'Pasif') and (Taban(LProps).Count = 2) and
      (Taban(LProps)[1].Description = 'Pasif'));
    LProps.Items.Delete(0);
    Kontrol('K00d item silinince taban da azalir', (Taban(LProps).Count = 1) and
      (Taban(LProps)[0].Description = 'Pasif'));
    Kur(LProps);
    Kontrol('K01 Items 3, taban 3', (LProps.Items.Count = 3) and (Taban(LProps).Count = 3),
      IntToStr(LProps.Items.Count));
    Kontrol('K02 Description = ad', (LProps.Items[0].Description = 'Alici') and
      (LProps.Items[2].Description = 'Alici ve Satici'));
    Kontrol('K03 yapici EditValueFormat''i cvfInteger''dan cikardi',
      LProps.EditValueFormat <> cvfInteger);

    LCb.AValues := ['A', 'AS'];
    Kontrol('K04 AValues -> EditValue ''A;AS''', VarToStr(LCb.EditValue) = 'A;AS',
      VarToStr(LCb.EditValue));
    { Gorunen metnin ayraci stok Delimiter'dir (';', bosluksuz) - deger ayraci degil. }
    Kontrol('K05 gosterilen metin adlar', LCb.Text = 'Alici;Alici ve Satici', LCb.Text);
    Kontrol('K06 AHasValues True', LCb.AHasValues);

    LCb.EditValue := 'as;a';
    Kontrol('K07 EditValue -> AValues, harf duyarsiz, item sirasinda',
      Dizi(LCb.AValues) = 'A|AS', Dizi(LCb.AValues));
    Kontrol('K08 EditValue normalize edilmedi (verilen metin korunur)',
      VarToStr(LCb.EditValue) = 'as;a', VarToStr(LCb.EditValue));

    LCb.EditValue := 'X;S';
    Kontrol('K09 bilinmeyen deger atlanir', Dizi(LCb.AValues) = 'S', Dizi(LCb.AValues));

    LCb.EditValue := '';
    Kontrol('K10 bos EditValue -> hic secim', Length(LCb.AValues) = 0, Dizi(LCb.AValues));
    Kontrol('K11 AHasValues False', not LCb.AHasValues);
    Kontrol('K12 AValuesIn bosta ''''', LCb.AValuesIn('cari_tip') = '', LCb.AValuesIn('cari_tip'));

    LCb.AValues := ['A', 'AS'];
    Kontrol('K13 AValuesIn', LCb.AValuesIn('cari_tip') = 'cari_tip in (''A'',''AS'')',
      LCb.AValuesIn('cari_tip'));

    LProps.Items.AddItem('O''R', 'O''R');
    LCb.AValues := ['O''R'];
    Kontrol('K14 tek tirnak ikilenir', LCb.AValuesIn('f') = 'f in (''O''''R'')', LCb.AValuesIn('f'));

    LCb.AValues := [];
    LProps.Items.Clear;
    for i := 1 to 70 do
      LProps.Items.AddItem(Format('Kalem%d', [i]), Format('K%d', [i]));
    Kontrol('K15 70 item istisna atmadi (64 siniri devre disi)',
      (LProps.Items.Count = 70) and (Taban(LProps).Count = 70));
    LCb.AValues := ['K70'];
    Kontrol('K16 70. item secilebiliyor', VarToStr(LCb.EditValue) = 'K70', VarToStr(LCb.EditValue));

    { Bos Value: deger = Description }
    LProps.Items.Clear;
    LProps.Items.AddItem('Aktif', '');
    LProps.Items.AddItem('Pasif', 'P');
    LCb.AValues := ['Aktif', 'P'];
    Kontrol('K17 bos Value: deger = Description', VarToStr(LCb.EditValue) = 'Aktif;P',
      VarToStr(LCb.EditValue));
    Kontrol('K17b gorunen metin Description', LCb.Text = 'Aktif;Pasif', LCb.Text);
    Kontrol('K17c IndexOfValue EffectiveValue ile',
      (LProps.Items.IndexOfValue('aktif') = 0) and (LProps.Items.IndexOfValue('P') = 1) and
      (LProps.Items.IndexOfValue('Pasif') = -1));

    { Hicbir item'da Value yok: stok davranis }
    LProps.Items.Clear;
    LProps.Items.AddCheckItem('Bir');
    LProps.Items.AddCheckItem('Iki');
    LProps.EditValueFormat := cvfInteger;
    LCb.States[1] := cbsChecked;
    Kontrol('K18 Value yokken stok bit maskesi', VarToStr(LCb.EditValue) = '2',
      VarToStr(LCb.EditValue));
    Kontrol('K18b Value yokken CheckWarning bos', LProps.CheckWarning = '', LProps.CheckWarning);
  finally
    LForm.Free;
  end;
end;

procedure Paylasim;
var
  LForm: TForm;
  LRepo: TcxEditRepository;
  LRi: TRadCheckComboBoxRepository;
  LCb1, LCb2: TRadCheckComboBox;
begin
  Writeln;
  Writeln('=== Paylasilan repository ===');
  LForm := TForm.CreateNew(nil);
  try
    LRepo := TcxEditRepository.Create(LForm);
    LRi := TRadCheckComboBoxRepository(LRepo.CreateItem(TRadCheckComboBoxRepository));
    Kur(LRi.Properties);
    LCb1 := TRadCheckComboBox.Create(LForm);
    LCb1.Parent := LForm;
    LCb1.RepositoryItem := LRi;
    LCb2 := TRadCheckComboBox.Create(LForm);
    LCb2.Parent := LForm;
    LCb2.RepositoryItem := LRi;
    LCb1.AValues := ['A'];
    LCb2.AValues := ['S'];
    Kontrol('P01 iki editor ayni item, bagimsiz degerler',
      (VarToStr(LCb1.EditValue) = 'A') and (VarToStr(LCb2.EditValue) = 'S'),
      VarToStr(LCb1.EditValue) + '/' + VarToStr(LCb2.EditValue));
    Kontrol('P02 metinler de bagimsiz', (LCb1.Text = 'Alici') and (LCb2.Text = 'Satici'),
      LCb1.Text + '/' + LCb2.Text);
  finally
    LForm.Free;
  end;
end;

procedure Dfm;
var
  LFrm, LYeni: TDfmForm;
  LCb: TRadCheckComboBox;
  LBin: TMemoryStream;
  LTxt: TStringStream;
  LMetin: string;
begin
  Writeln;
  Writeln('=== DFM gidis-donus ===');
  RegisterClasses([TDfmForm, TRadCheckComboBox]);
  LFrm := TDfmForm.CreateNew(nil);
  try
    LFrm.Name := 'frmDfm';
    LCb := TRadCheckComboBox.Create(LFrm);
    LCb.Name := 'cbTip';
    LCb.Parent := LFrm;
    Kur(LCb.Properties);
    LCb.AValues := ['A', 'AS'];
    LBin := TMemoryStream.Create;
    try
      LBin.WriteComponent(LFrm);
      LBin.Position := 0;
      LTxt := TStringStream.Create('');
      try
        ObjectBinaryToText(LBin, LTxt);
        LMetin := LTxt.DataString;
      finally
        LTxt.Free;
      end;
      Kontrol('D01 Value DFM''e yazildi', Pos('Value = ''AS''', LMetin) > 0, LMetin);
      Kontrol('D02 Items Description ile yazildi',
        (Pos('Properties.Items = <', LMetin) > 0) and (Pos('''Alici''', LMetin) > 0), LMetin);
      Kontrol('D02b Items DFM''de tek kez gecer',
        LMetin.CountChar('<') = 1, IntToStr(LMetin.CountChar('<')));
      Kontrol('D03 EditValue DFM''e yazildi', Pos('EditValue = ''A;AS''', LMetin) > 0);
      LBin.Position := 0;
      LYeni := TDfmForm.CreateNew(nil);
      try
        LBin.ReadComponent(LYeni);
        LCb := LYeni.FindComponent('cbTip') as TRadCheckComboBox;
        Kontrol('D04 geri okununca Items, Value ve taban aynasi', (LCb <> nil) and
          (LCb.Properties.Items.Count = 3) and (LCb.Properties.Items[2].Description = 'Alici ve Satici') and
          (LCb.Properties.Items[2].Value = 'AS') and (Taban(LCb.Properties).Count = 3));
        Kontrol('D05 geri okununca AValues korundu', (LCb <> nil) and (Dizi(LCb.AValues) = 'A|AS'));
      finally
        LYeni.Free;
      end;
    finally
      LBin.Free;
    end;
  finally
    LFrm.Free;
  end;
end;

procedure DbKip;
var
  LForm: TForm;
  LT: TVirtualTable;
  LDs: TDataSource;
  LCb: TRadDBCheckComboBox;
begin
  Writeln;
  Writeln('=== DB ===');
  LForm := TForm.CreateNew(nil);
  try
    LT := TVirtualTable.Create(LForm);
    LT.AddField('cari_tip', ftString, 20);
    LT.Open;
    LT.AppendRecord(['A;S']);
    LDs := TDataSource.Create(LForm);
    LDs.DataSet := LT;
    LCb := TRadDBCheckComboBox.Create(LForm);
    LCb.Parent := LForm;
    Kur(LCb.Properties);
    LCb.DataBinding.DataSource := LDs;
    LCb.DataBinding.DataField := 'cari_tip';
    Kontrol('B01 alandan iki item isaretli', Dizi(LCb.AValues) = 'A|S', Dizi(LCb.AValues));
    Kontrol('B02 AHasValues True', LCb.AHasValues);
    LT.Edit;
    LCb.AValues := ['A', 'S', 'AS'];
    LCb.PostEditValue;
    Kontrol('B03 alan ''A;S;AS''', LT.FieldByName('cari_tip').AsString = 'A;S;AS',
      LT.FieldByName('cari_tip').AsString);
    LT.Cancel;
  finally
    LForm.Free;
  end;
end;

procedure Denetim;
var
  LForm: TForm;
  LT: TVirtualTable;
  LDs: TDataSource;
  LCb: TRadCheckComboBox;
  LDb: TRadDBCheckComboBox;
  LOlay: TOlay;
  LRapor: string;
begin
  Writeln;
  Writeln('=== RadChainAudit ===');
  LOlay := TOlay.Create;
  LForm := TForm.CreateNew(nil);
  try
    LForm.Name := 'frmDenetim';
    LCb := TRadCheckComboBox.Create(LForm);
    LCb.Name := 'cbTemiz';
    LCb.Parent := LForm;
    Kur(LCb.Properties);
    LRapor := RadChainAudit(LForm);
    Kontrol('A00 duzgun kurulumda rapor bos', LRapor = '', LRapor);

    LCb.Properties.Items.AddItem('Tekrar', 'A');           { ayni deger }
    LCb.Properties.Items.AddItem('Ayracli', 'X;Y');        { ayrac iceren deger }
    LCb.Properties.OnStatesToEditValue := LOlay.StatesToValue;   { olay kazanir }
    LT := TVirtualTable.Create(LForm);
    LT.AddField('kisa', ftString, 3);
    LT.AddField('sayi', ftInteger);
    LT.Open;
    LT.AppendRecord(['A', 1]);
    LDs := TDataSource.Create(LForm);
    LDs.DataSet := LT;
    LDb := TRadDBCheckComboBox.Create(LForm);
    LDb.Name := 'cbKisa';
    LDb.Parent := LForm;
    Kur(LDb.Properties);
    LDb.DataBinding.DataSource := LDs;
    LDb.DataBinding.DataField := 'kisa';                  { A;S;AS sigmaz (7 > 3) }
    LRapor := RadChainAudit(LForm);
    Writeln('  [BILGI] ', LRapor.Replace(sLineBreak, ' | '));
    Kontrol('A01 ayni degerli iki item bildirildi', Pos('"A"', LRapor) > 0);
    Kontrol('A02 ayrac iceren deger bildirildi', Pos('X;Y', LRapor) > 0);
    Kontrol('A03 olay cakismasi bildirildi', Pos('OnStatesToEditValue', LRapor) > 0);
    Kontrol('A04 kisa DB alani bildirildi', Pos('kisa', LRapor) > 0);
    { Olay varken bir kutuyu isaretlemek EditValue'yu OLAYDAN alir, degerden degil. }
    LOlay.Sayac := 0;
    LCb.States[0] := cbsChecked;
    Kontrol('A05 olay kazanirken deger kipi gercekten devre disi',
      (LOlay.Sayac = 1) and (VarToStr(LCb.EditValue) = 'OLAY'), VarToStr(LCb.EditValue));
    LCb.Properties.OnStatesToEditValue := nil;
    LDb.DataBinding.DataField := 'sayi';
    LRapor := RadChainAudit(LForm);
    Kontrol('A06 metin olmayan DB alani bildirildi', Pos('sayi', LRapor) > 0, LRapor);
  finally
    LForm.Free;
    LOlay.Free;
  end;
end;

procedure Kos(AProc: TProc; const AAd: string);
begin
  try
    AProc();
  except
    on E: Exception do
    begin
      Inc(GHata);
      Writeln('  [PATLADI] ', AAd, ': ', E.ClassName, ': ', E.Message);
    end;
  end;
end;

begin
  Application.Initialize;
  Kos(Temel, 'Temel');
  Kos(Paylasim, 'Paylasim');
  Kos(Dfm, 'DFM');
  Kos(DbKip, 'DB');
  Kos(Denetim, 'Denetim');
  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    ExitCode := 1;
end.
