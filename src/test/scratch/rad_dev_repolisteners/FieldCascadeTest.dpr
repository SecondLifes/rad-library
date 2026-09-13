program FieldCascadeTest;

{$APPTYPE CONSOLE}

(* TRadFieldCascade - bir alan DUZENLENINCE ona bagli alanlari siler.

   Kural bir satirla verilir: 'ulke;sehir;ilce' = ulke duzenlenince sehir ve
   ilce, sehir duzenlenince ilce silinir.

   Olculen sozlesme:
     - duzenleme siler; GEZINME silmez (dataset dsBrowse kalir);
     - ayni degeri yeniden yazmak silmez;
     - ust alani bosaltmak (Clear) da siler;
     - iki bagimsiz zincir bir bilesende birbirine karismaz;
     - yeni kayitta da calisir; Cancel her seyi geri getirir;
     - DataSource yok edilince ADataSource nil'lenir (sarkan isaretci yok);
     - AChains DFM gidis-donusunde korunur;
     - gridden (DevExpress veri denetleyicisi) yapilan degisiklikte de calisir. *)

uses
  System.SysUtils, System.Classes, System.Variants, Vcl.Forms, Vcl.Controls,
  Data.DB, VirtualTable,
  cxGrid, cxGridLevel, cxGridCustomTableView, cxGridTableView, cxGridDBTableView,
  cxDataUtils,
  rad.db;

type
  TDfmForm = class(TForm);

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
  Flush(Output);
end;

function Tablo(AOwner: TComponent): TVirtualTable;
begin
  Result := TVirtualTable.Create(AOwner);
  Result.AddField('ulke', ftString, 40);
  Result.AddField('sehir', ftString, 40);
  Result.AddField('ilce', ftString, 40);
  Result.AddField('tip', ftString, 40);
  Result.AddField('alt_tip', ftString, 40);
  Result.Open;
  Result.AppendRecord(['Turkiye', 'Istanbul', 'Kadikoy', 'A', 'A1']);
  Result.AppendRecord(['Almanya', 'Berlin', 'Mitte', 'B', 'B1']);
  Result.First;
end;

function S(ADataSet: TDataSet; const AAlan: string): string;
begin
  if ADataSet.FieldByName(AAlan).IsNull then
    Result := '<null>'
  else
    Result := ADataSet.FieldByName(AAlan).AsString;
end;

procedure Temel;
var
  LSahip: TComponent;
  LT: TVirtualTable;
  LDs: TDataSource;
  LC: TRadFieldCascade;
begin
  Writeln;
  Writeln('=== Temel ===');
  LSahip := TComponent.Create(nil);
  try
    LT := Tablo(LSahip);
    LDs := TDataSource.Create(LSahip);
    LDs.DataSet := LT;
    LC := TRadFieldCascade.Create(LSahip);
    LC.AChains.Text := 'ulke;sehir;ilce' + sLineBreak + 'tip;alt_tip';
    LC.ADataSource := LDs;

    LT.Edit;
    LT.FieldByName('ulke').AsString := 'Almanya';
    Kontrol('C01 ulke duzenlenince sehir silindi', S(LT, 'sehir') = '<null>', S(LT, 'sehir'));
    Kontrol('C02 ulke duzenlenince ilce silindi', S(LT, 'ilce') = '<null>', S(LT, 'ilce'));
    Kontrol('C03 baska zincir (tip) etkilenmedi', S(LT, 'tip') = 'A', S(LT, 'tip'));
    LT.Cancel;
    Kontrol('C04 Cancel eski degerleri geri getirdi', S(LT, 'sehir') = 'Istanbul',
      S(LT, 'sehir'));

    LT.Edit;
    LT.FieldByName('sehir').AsString := 'Ankara';
    Kontrol('C05 sehir duzenlenince yalnizca ilce silindi',
      (S(LT, 'ilce') = '<null>') and (S(LT, 'ulke') = 'Turkiye'),
      S(LT, 'ulke') + '/' + S(LT, 'ilce'));
    LT.Cancel;

    LT.Edit;
    LT.FieldByName('ulke').AsString := 'Turkiye';      { ayni deger }
    Kontrol('C06 ayni degeri yeniden yazmak SILMEDI', S(LT, 'sehir') = 'Istanbul',
      S(LT, 'sehir'));
    LT.Cancel;

    LT.Next;
    LT.First;
    Kontrol('C07 gezinme SILMEDI', (S(LT, 'sehir') = 'Istanbul') and (S(LT, 'ilce') = 'Kadikoy'),
      S(LT, 'sehir') + '/' + S(LT, 'ilce'));
    Kontrol('C08 gezinme kaydi duzenleme moduna sokmadi', LT.State = dsBrowse);

    LT.Edit;
    LT.FieldByName('tip').AsString := 'Z';
    Kontrol('C09 ikinci zincir: tip duzenlenince alt_tip silindi',
      S(LT, 'alt_tip') = '<null>', S(LT, 'alt_tip'));
    Kontrol('C10 ikinci zincir birinciyi etkilemedi', S(LT, 'sehir') = 'Istanbul',
      S(LT, 'sehir'));
    LT.Cancel;

    LT.Edit;
    LT.FieldByName('ulke').Clear;
    Kontrol('C11 ust alani bosaltmak da siler', S(LT, 'sehir') = '<null>', S(LT, 'sehir'));
    LT.Cancel;

    LT.Append;
    LT.FieldByName('ulke').AsString := 'Turkiye';
    LT.FieldByName('sehir').AsString := 'Izmir';
    LT.FieldByName('ulke').AsString := 'Almanya';
    Kontrol('C12 yeni kayitta da calisiyor', S(LT, 'sehir') = '<null>', S(LT, 'sehir'));
    LT.Cancel;

    LT.First;
    LT.Edit;
    LT.FieldByName('ulke').AsString := 'Almanya';
    LT.Post;
    Kontrol('C13 Post sonrasi silme kalici', S(LT, 'sehir') = '<null>', S(LT, 'sehir'));
  finally
    LSahip.Free;
  end;
end;

procedure SarkanIsaretci;
var
  LSahip: TComponent;
  LT: TVirtualTable;
  LDs: TDataSource;
  LC: TRadFieldCascade;
begin
  Writeln;
  Writeln('=== DataSource yok edilince ===');
  LSahip := TComponent.Create(nil);
  try
    LT := Tablo(LSahip);
    LDs := TDataSource.Create(nil);          { sahipsiz - elle yok edecegiz }
    LDs.DataSet := LT;
    LC := TRadFieldCascade.Create(LSahip);
    LC.AChains.Text := 'ulke;sehir';
    LC.ADataSource := LDs;
    LDs.Free;
    Kontrol('C14 ADataSource nil''lendi', LC.ADataSource = nil);
    LT.Edit;
    LT.FieldByName('ulke').AsString := 'Almanya';   { artik bagli degil }
    Kontrol('C15 bagi kopunca silme yok, istisna yok', S(LT, 'sehir') = 'Istanbul',
      S(LT, 'sehir'));
    LT.Cancel;
  finally
    LSahip.Free;
  end;
end;

procedure Dfm;
var
  LFrm, LYeni: TDfmForm;
  LC: TRadFieldCascade;
  LBin: TMemoryStream;
  LTxt: TStringStream;
  LMetin: string;
begin
  Writeln;
  Writeln('=== DFM gidis-donus ===');
  RegisterClasses([TDfmForm, TRadFieldCascade]);
  LFrm := TDfmForm.CreateNew(nil);
  try
    LFrm.Name := 'frmDfm';
    LC := TRadFieldCascade.Create(LFrm);
    LC.Name := 'Cascade1';
    LC.AChains.Text := 'ulke;sehir;ilce' + sLineBreak + 'tip;alt_tip';
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
      Kontrol('C16 AChains DFM''e yazildi', Pos('ulke;sehir;ilce', LMetin) > 0, LMetin);
      LBin.Position := 0;
      LYeni := TDfmForm.CreateNew(nil);
      try
        LBin.ReadComponent(LYeni);
        LC := LYeni.FindComponent('Cascade1') as TRadFieldCascade;
        Kontrol('C17 geri okununca iki zincir de var',
          (LC <> nil) and (LC.AChains.Count = 2) and (LC.AChains[1] = 'tip;alt_tip'));
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

procedure Grid;
var
  LForm: TForm;
  LT: TVirtualTable;
  LDs: TDataSource;
  LC: TRadFieldCascade;
  LGrid: TcxGrid;
  LView: TcxGridDBTableView;
  LColUlke: TcxGridDBColumn;
begin
  Writeln;
  Writeln('=== Gridden degisiklik ===');
  LForm := TForm.CreateNew(nil);
  try
    LT := Tablo(LForm);
    LDs := TDataSource.Create(LForm);
    LDs.DataSet := LT;
    LC := TRadFieldCascade.Create(LForm);
    LC.AChains.Text := 'ulke;sehir;ilce';
    LC.ADataSource := LDs;

    LGrid := TcxGrid.Create(LForm);
    LGrid.Parent := LForm;
    LView := LGrid.CreateView(TcxGridDBTableView) as TcxGridDBTableView;
    LGrid.Levels.Add.GridView := LView;
    LView.DataController.DataSource := LDs;
    LColUlke := LView.CreateColumn;
    LColUlke.DataBinding.FieldName := 'ulke';
    LView.CreateColumn.DataBinding.FieldName := 'sehir';

    LView.DataController.FocusedRecordIndex := 0;
    LView.DataController.Edit;
    LView.DataController.SetEditValue(LColUlke.Index, 'Almanya', evsValue);
    Kontrol('C18 gridde ulke degisince sehir silindi', S(LT, 'sehir') = '<null>',
      S(LT, 'sehir'));
    LView.DataController.Cancel;
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

begin
  Application.Initialize;
  Kos(Temel, 'Temel');
  Kos(SarkanIsaretci, 'Sarkan');
  Kos(Dfm, 'DFM');
  Kos(Grid, 'Grid');
  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    ExitCode := 1;
end.
