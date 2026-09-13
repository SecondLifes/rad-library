program ComboFillTest;

{$APPTYPE CONSOLE}

(* TRadComboBoxProperties - tek olayla, gerektiginde dolan liste.

   Olculen sozlesme:
     - AOnFill'e gelen AParams, tuketicinin KAYDINDAKI AMasterFields alanlarini
       adlariyla ve degerleriyle tasir (formdaki DB editoru icin help.Dev'in
       _DataSetOf'u artik dataset'i buluyor);
     - degerler ayniysa ikinci acilista AOnFill cagrilmaz; degisince ve
       ResetItems sonrasi cagrilir;
     - AMasterFields bossa liste bir kez dolar;
     - eksik alan ERadDev; olay patlarsa sonraki acilis yeniden dener;
     - bir repository'yi paylasan iki tuketici, tek olay, AEditorId'ye gore
       dogru liste;
     - yeni property'ler DFM gidis-donusunde korunur;
     - RadChainAudit eksik AOnFill'i ve kayitta olmayan alani bildirir.

   Help.Dev EN SONDA: yalnizca en yakin class helper gorunur. *)

uses
  System.SysUtils, System.Classes, System.Variants, Vcl.Forms, Vcl.Controls,
  Data.DB, VirtualTable,
  cxEdit, cxDropDownEdit, cxDBEdit,
  Rad.Dev,
  Help.Dev;

type
  TOlay = class
  public
    Sayac: Integer;
    SonUlke: string;
    SonId: string;
    PatlaBirKez: Boolean;
    procedure Doldur(Sender: TRadComboBoxProperties; ASource: TComponent;
      AParams: TParams; AItems: TStrings);
  end;

  { DFM akisinin koku. Combo'yu TEK BASINA kok yapmak onun ic editorunu de
    akisa yazar ve geri okurken TcxCustomComboBoxInnerEdit bulunamaz (olculdu);
    gercek bir DFM'de de combo bir formun icindedir. }
  TDfmForm = class(TForm);

var
  GBasari: Integer = 0;
  GHata: Integer = 0;

procedure TOlay.Doldur(Sender: TRadComboBoxProperties; ASource: TComponent;
  AParams: TParams; AItems: TStrings);
var
  LUlke: string;
begin
  Inc(Sayac);
  SonId := Sender.AEditorId;
  if PatlaBirKez then
  begin
    PatlaBirKez := False;
    raise Exception.Create('sonda: doldurma bilerek patladi');
  end;
  AItems.Clear;
  if SameText(Sender.AEditorId, 'ulke') then
  begin
    AItems.Add('Turkiye');
    AItems.Add('Almanya');
    Exit;
  end;
  LUlke := '';
  if AParams.FindParam('ulke') <> nil then
    LUlke := VarToStr(AParams.ParamByName('ulke').Value);
  SonUlke := LUlke;
  if LUlke = 'Turkiye' then
  begin
    AItems.Add('Istanbul');
    AItems.Add('Ankara');
  end
  else if LUlke = 'Almanya' then
  begin
    AItems.Add('Berlin');
    AItems.Add('Munih');
  end;
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

function Kayit(AOwner: TComponent; const AUlke, ASehir: string): TVirtualTable;
begin
  Result := TVirtualTable.Create(AOwner);
  Result.AddField('ulke', ftString, 60);
  Result.AddField('sehir', ftString, 60);
  Result.Open;
  Result.AppendRecord([AUlke, ASehir]);
end;

function Combo(AForm: TForm; AItem: TcxEditRepositoryItem; ADs: TDataSource;
  const AAlan: string): TRadDBComboBox;
begin
  Result := TRadDBComboBox.Create(AForm);
  Result.Parent := AForm;
  Result.RepositoryItem := AItem;
  Result.DataBinding.DataSource := ADs;
  Result.DataBinding.DataField := AAlan;
end;

function Liste(ACb: TRadDBComboBox): string;
begin
  Result := ACb.ActiveProperties.Items.CommaText;
end;

procedure Doldurma(AOlay: TOlay);
var
  LForm: TForm;
  LKayit, LKayit2: TVirtualTable;
  LDs, LDs2: TDataSource;
  LRepo: TcxEditRepository;
  LRiSehir, LRiUlke, LRiBozuk: TRadComboBoxRepository;
  LSehir, LSehir2, LUlke, LBozuk: TRadDBComboBox;
begin
  Writeln;
  Writeln('=== Doldurma ===');
  LForm := TForm.CreateNew(nil);
  try
    LKayit := Kayit(LForm, 'Turkiye', 'Istanbul');
    LKayit.AppendRecord(['Almanya', 'Berlin']);
    LKayit.First;
    LDs := TDataSource.Create(LForm);
    LDs.DataSet := LKayit;

    LRepo := TcxEditRepository.Create(LForm);
    LRiSehir := TRadComboBoxRepository(LRepo.CreateItem(TRadComboBoxRepository));
    LRiSehir.Properties.AEditorId := 'sehir';
    LRiSehir.Properties.AMasterFields := 'ulke';
    LRiSehir.Properties.AOnFill := AOlay.Doldur;

    LSehir := Combo(LForm, LRiSehir, LDs, 'sehir');

    Kontrol('F00 help.Dev: formdaki DB combo icin _DataSetOf kayit dataset''i',
      _DataSetOf(LSehir) = LKayit);

    AOlay.Sayac := 0;
    LSehir.ActiveProperties.FillItems(LSehir);
    Kontrol('F01 ilk acilista AOnFill bir kez', AOlay.Sayac = 1, IntToStr(AOlay.Sayac));
    Kontrol('F02 AParams kayittaki ulke degerini tasiyor (Turkiye)',
      AOlay.SonUlke = 'Turkiye', AOlay.SonUlke);
    Kontrol('F03 liste Turkiye sehirleri', Liste(LSehir) = 'Istanbul,Ankara', Liste(LSehir));

    LSehir.ActiveProperties.FillItems(LSehir);
    Kontrol('F04 ayni degerle ikinci acilista AOnFill YOK', AOlay.Sayac = 1,
      IntToStr(AOlay.Sayac));

    LKayit.Next;
    LSehir.ActiveProperties.FillItems(LSehir);
    Kontrol('F05 kayit degisince (Almanya) yeniden doldu', AOlay.Sayac = 2,
      IntToStr(AOlay.Sayac));
    Kontrol('F06 liste Almanya sehirleri', Liste(LSehir) = 'Berlin,Munih', Liste(LSehir));

    LSehir.ActiveProperties.ResetItems;
    LSehir.ActiveProperties.FillItems(LSehir);
    Kontrol('F07 ResetItems sonrasi ayni degerle yeniden doldu', AOlay.Sayac = 3,
      IntToStr(AOlay.Sayac));

    { AMasterFields bos: sabit liste, bir kez }
    LRiUlke := TRadComboBoxRepository(LRepo.CreateItem(TRadComboBoxRepository));
    LRiUlke.Properties.AEditorId := 'ulke';
    LRiUlke.Properties.AOnFill := AOlay.Doldur;
    LUlke := Combo(LForm, LRiUlke, LDs, 'ulke');
    AOlay.Sayac := 0;
    LUlke.ActiveProperties.FillItems(LUlke);
    LKayit.First;
    LUlke.ActiveProperties.FillItems(LUlke);
    Kontrol('F08 AMasterFields bos: kayit degisse de liste bir kez doldu',
      AOlay.Sayac = 1, IntToStr(AOlay.Sayac));
    Kontrol('F09 tek olay AEditorId''ye gore ulke listesini verdi',
      Liste(LUlke) = 'Turkiye,Almanya', Liste(LUlke));

    { Paylasilan repository, iki tuketici, farkli kayitlar }
    LKayit2 := Kayit(LForm, 'Almanya', 'Munih');
    LDs2 := TDataSource.Create(LForm);
    LDs2.DataSet := LKayit2;
    LSehir2 := Combo(LForm, LRiSehir, LDs2, 'sehir');
    LKayit.First;                                   { 1. tuketici: Turkiye }
    LSehir.ActiveProperties.FillItems(LSehir);
    Kontrol('F10 1. tuketici Turkiye listesi', Liste(LSehir) = 'Istanbul,Ankara',
      Liste(LSehir));
    LSehir2.ActiveProperties.FillItems(LSehir2);
    Kontrol('F11 2. tuketici (ayni item) kendi kaydinin listesini aldi (Almanya)',
      Liste(LSehir2) = 'Berlin,Munih', Liste(LSehir2));
    LSehir.ActiveProperties.FillItems(LSehir);
    Kontrol('F12 1. tuketici yeniden acinca yine Turkiye listesi',
      Liste(LSehir) = 'Istanbul,Ankara', Liste(LSehir));

    { Olay patlarsa sonraki acilis yeniden dener }
    LSehir.ActiveProperties.ResetItems;
    AOlay.Sayac := 0;
    AOlay.PatlaBirKez := True;
    try
      LSehir.ActiveProperties.FillItems(LSehir);
    except
      on E: Exception do
        Writeln('  [BILGI] beklenen istisna: ', E.Message);
    end;
    LSehir.ActiveProperties.FillItems(LSehir);
    Kontrol('F13 olay patladiktan sonra ayni degerle yeniden denedi',
      AOlay.Sayac = 2, IntToStr(AOlay.Sayac));
    Kontrol('F14 ikinci denemede liste doldu', Liste(LSehir) = 'Istanbul,Ankara',
      Liste(LSehir));

    { Eksik alan }
    LRiBozuk := TRadComboBoxRepository(LRepo.CreateItem(TRadComboBoxRepository));
    LRiBozuk.Properties.AEditorId := 'sehir';
    LRiBozuk.Properties.AMasterFields := 'yok_boyle_alan';
    LRiBozuk.Properties.AOnFill := AOlay.Doldur;
    LBozuk := Combo(LForm, LRiBozuk, LDs, 'sehir');
    try
      LBozuk.ActiveProperties.FillItems(LBozuk);
      Kontrol('F15 kayitta olmayan alan -> ERadDev', False, 'istisna ATILMADI');
    except
      on E: ERadDev do
        Kontrol('F15 kayitta olmayan alan -> ERadDev', Pos('yok_boyle_alan', E.Message) > 0,
          E.Message);
      on E: Exception do
        Kontrol('F15 kayitta olmayan alan -> ERadDev', False, E.ClassName + ': ' + E.Message);
    end;
  finally
    LForm.Free;
  end;
end;

procedure DfmGidisDonus;
var
  LFrm, LYeniFrm: TDfmForm;
  LCb, LBos, LYeni: TRadComboBox;
  LBin: TMemoryStream;
  LTxt: TStringStream;
  LMetin: string;
begin
  Writeln;
  Writeln('=== DFM gidis-donus ===');
  RegisterClasses([TDfmForm, TRadComboBox]);
  LFrm := TDfmForm.CreateNew(nil);
  try
    LFrm.Name := 'frmDfm';
    LCb := TRadComboBox.Create(LFrm);
    LCb.Name := 'cbTek';
    LCb.Parent := LFrm;
    LCb.Properties.AEditorId := 'sehir';
    LCb.Properties.AMasterFields := 'ulke;sehir';
    LBos := TRadComboBox.Create(LFrm);      { hic ayarlanmamis }
    LBos.Name := 'cbBos';
    LBos.Parent := LFrm;
    LBos.Top := 40;

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
      Kontrol('D01 AEditorId DFM''e yazildi', Pos('AEditorId = ''sehir''', LMetin) > 0,
        LMetin);
      Kontrol('D02 AMasterFields DFM''e yazildi',
        Pos('AMasterFields = ''ulke;sehir''', LMetin) > 0);
      Kontrol('D05 bos degerler DFM''e YAZILMIYOR (yalnizca cbTek''te var)',
        Pos('AEditorId', LMetin, Pos('AEditorId', LMetin) + 1) = 0, LMetin);

      LBin.Position := 0;
      LYeniFrm := TDfmForm.CreateNew(nil);
      try
        LBin.ReadComponent(LYeniFrm);
        LYeni := LYeniFrm.FindComponent('cbTek') as TRadComboBox;
        Kontrol('D03 geri okununca AEditorId ayni',
          (LYeni <> nil) and (LYeni.Properties.AEditorId = 'sehir'));
        Kontrol('D04 geri okununca AMasterFields ayni',
          (LYeni <> nil) and (LYeni.Properties.AMasterFields = 'ulke;sehir'));
      finally
        LYeniFrm.Free;
      end;
    finally
      LBin.Free;
    end;
  finally
    LFrm.Free;
  end;
end;

procedure Denetim;
var
  LForm: TForm;
  LKayit: TVirtualTable;
  LDs: TDataSource;
  LCb: TRadDBComboBox;
  LRapor: string;
begin
  Writeln;
  Writeln('=== RadChainAudit ===');
  LForm := TForm.CreateNew(nil);
  try
    LForm.Name := 'frmDenetim';
    LKayit := Kayit(LForm, 'Turkiye', 'Istanbul');
    LDs := TDataSource.Create(LForm);
    LDs.DataSet := LKayit;
    LCb := TRadDBComboBox.Create(LForm);
    LCb.Name := 'cbDenetim';
    LCb.Parent := LForm;
    LCb.DataBinding.DataSource := LDs;
    LCb.DataBinding.DataField := 'sehir';
    LCb.Properties.AEditorId := 'sehir';
    LCb.Properties.AMasterFields := 'ulke;olmayan';
    LRapor := RadChainAudit(LForm);
    Writeln('  [BILGI] ', LRapor.Replace(sLineBreak, ' | '));
    Kontrol('A01 AOnFill eksigi bildiriliyor', Pos('AOnFill', LRapor) > 0);
    Kontrol('A02 kayitta olmayan AMasterFields alani bildiriliyor',
      Pos('olmayan', LRapor) > 0);
    Kontrol('A03 kayitta OLAN alan bulgu sayilmiyor',
      Pos('"ulke"', LRapor) = 0);
  finally
    LForm.Free;
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

var
  LOlay: TOlay;

begin
  Application.Initialize;
  LOlay := TOlay.Create;
  try
    Kos(procedure begin Doldurma(LOlay) end, 'Doldurma');
    Kos(DfmGidisDonus, 'DFM');
    Kos(Denetim, 'Denetim');
  finally
    LOlay.Free;
  end;
  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    ExitCode := 1;
end.
