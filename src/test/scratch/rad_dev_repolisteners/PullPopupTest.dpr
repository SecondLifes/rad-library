program PullPopupTest;

(*
  O-11: PULL'un GERCEK POPUP YOLU. Bu sonda GORUNUR PENCERE ISTER.

  Neden ayri bir sonda: TcxCustomDropDownEdit.DropDown
  "if not IsWindowVisible(Handle) then Exit" ile basliyor
  (cxDropDownEdit.pas:3252). Gorunmeyen bir pencerede DoInitPopup HIC
  calismaz, dolayisiyla PullTest pull'u FilterNow ile ELLE tetikliyor.
  Burada acilir listeyi gercekten aciyoruz.

  Olculen dort sey:

    1. Acilir liste acilinca AOnFilter tam BIR kez tetikleniyor mu?
    2. SIRA KANITI - isleyici icinde liste dataset'i degistirildiginde, popup
       acildiktan SONRA o degisiklik AYAKTA mi? Ayakta ise pull'un
       inherited'dan ONCE durmasi dogru demektir: ILookupData.DropDown'un
       aldigi LockDataChanged (cxLookupEdit.pas:309) degisikligi BASTIRMAMIS
       olur. Bu, kod icindeki sira gerekcesinin TEK gercek olcumu.
    3. Master bir grid KOLONU iken AMasterValue odakli satiri takip ediyor mu,
       ve ASource'tan _Host ile kolona ulasilabiliyor mu?
    4. AFilterOnPopup = False iken acilir listeyi acmak hicbir sey
       tetiklemiyor mu?

  ! Bu sonda ne ISPATLAMAZ: popup penceresinin EKRANDA kac satir cizdigini.
    Olculen sey, dataset'in popup acildiktan sonraki durumudur - cizim degil.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, Vcl.Forms, Vcl.Controls,
  Data.DB, MemDS, VirtualTable,
  cxEdit, cxTextEdit, cxMaskEdit, cxDropDownEdit, cxLookupEdit, cxDBLookupEdit,
  cxDBLookupComboBox,
  cxGraphics, cxControls, cxLookAndFeels, cxContainer, cxClasses,
  cxGrid, cxGridLevel, cxGridTableView, cxGridCustomTableView,
  Help.Dev,
  Rad.Dev;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;
  GAtlanan: Integer = 0;
  (* Sira kaniti icin: isleyici CAGRILDIGI AN listeyi bu ulkeye suzer.
     TDataSet olarak tutuluyor, TVirtualTable olarak DEGIL - Filter''a
     TVirtualTable tipi uzerinden yazmak derlenmiyor; bilesenin kendisi de
     ona TDataSet uzerinden yaziyor. *)
  GTablo: TDataSet = nil;
  GFiltreUlkesi: Integer = 0;

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

procedure Atla(const AAd, ASebep: string);
begin
  Inc(GAtlanan);
  Writeln('  [ATLA] ', AAd);
  Writeln('         ', ASebep);
end;

procedure Bekle(AMs: Cardinal);
var
  LSon: Cardinal;
begin
  LSon := TThread.GetTickCount + AMs;
  while TThread.GetTickCount < LSon do
  begin
    Application.ProcessMessages;
    Sleep(5);
  end;
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
    SonMaster: TComponent;
    SonDeger: Variant;
    SonHost: string;
    (* TDataSet olarak tutuluyor, TVirtualTable olarak DEGIL: Filter'a
       TVirtualTable tipi uzerinden yazmak derlenmiyor (E2066). Bilesenin
       kendisi de ona TDataSet uzerinden yaziyor. *)
    Tablo: TDataSet;
    { isleyici listeyi bu ulkeye suzsun }
    FiltreUlkesi: Integer;
    procedure Filtre(Sender: TRadLookupComboBoxProperties;
      ASource, AMaster: TComponent; const AMasterValue: Variant);
    procedure Sifirla;
  end;

procedure TIzleyici.Sifirla;
begin
  Sayac := 0;
  SonMaster := nil;
  SonDeger := Unassigned;
  SonHost := '';
end;

procedure TIzleyici.Filtre(Sender: TRadLookupComboBoxProperties;
  ASource, AMaster: TComponent; const AMasterValue: Variant);
begin
  Inc(Sayac);
  SonMaster := AMaster;
  SonDeger := AMasterValue;
  if ASource is TcxCustomTextEdit then
    SonHost := Ad(TcxCustomTextEdit(ASource)._Host);

  { SIRA KANITININ kalbi: listeyi TAM BU ANDA degistiriyoruz. Bu cagri
    ILookupData.DropDown'dan ONCE gelmeli; sonra gelseydi LockDataChanged
    degisikligi bastirirdi ve popup eski satirlari gosterirdi. }
  if GTablo <> nil then
  begin
    GTablo.Filtered := False;
    GTablo.Filter := 'ulke_id = ' + IntToStr(GFiltreUlkesi);
    GTablo.Filtered := True;
  end;
end;

procedure SehirEkle(ATable: TVirtualTable; AId: Integer; const AAd: string;
  AUlke: Integer);
begin
  ATable.Append;
  ATable.FieldByName('id').AsInteger := AId;
  ATable.FieldByName('ad').AsString := AAd;
  ATable.FieldByName('ulke_id').AsInteger := AUlke;
  ATable.Post;
end;

var
  LForm: TForm;
  LIzle: TIzleyici;
  LVT: TVirtualTable;
  LDs: TDataSource;
  LUsta, LBagimli: TRadLookupComboBox;
  LGrid: TcxGrid;
  LLevel: TcxGridLevel;
  LView: TcxGridTableView;
  LColUlke, LColSehir: TcxGridColumn;

begin
  try
    Application.Initialize;
    LForm := TForm.CreateNew(nil);
    LIzle := TIzleyici.Create;
    try
      LForm.Width := 700;
      LForm.Height := 460;
      LForm.Position := poScreenCenter;
      LForm.Caption := 'PullPopupTest';
      LForm.Show;
      Bekle(200);

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

      LDs := TDataSource.Create(LForm);
      LDs.DataSet := LVT;

      LUsta := TRadLookupComboBox.Create(LForm);
      LUsta.Name := 'Ulke'; LUsta.Parent := LForm;
      LUsta.Left := 20; LUsta.Top := 20; LUsta.Width := 240;
      LUsta.EditValue := 1;

      LBagimli := TRadLookupComboBox.Create(LForm);
      LBagimli.Name := 'Sehir'; LBagimli.Parent := LForm;
      LBagimli.Left := 20; LBagimli.Top := 60; LBagimli.Width := 240;
      LBagimli.Properties.ListSource := LDs;
      LBagimli.Properties.KeyFieldNames := 'id';
      LBagimli.Properties.ListFieldNames := 'ad';
      LBagimli.Properties.AMaster := LUsta;
      LBagimli.Properties.AMasterField := 'ulke_id';
      LBagimli.Properties.AOnFilter := LIzle.Filtre;
      Bekle(150);

      { == 1) Acilir liste acilinca AOnFilter tetikleniyor mu? ========== }
      Writeln('=== 1) Popup acilinca AOnFilter tetikleniyor mu? ===');
      Writeln('  pencere gorunur mu : ', BoolToStr(LForm.Visible, True));
      LIzle.Sifirla;
      GTablo := nil;                  { bu turda listeyi degistirme }
      LBagimli.DroppedDown := True;
      Bekle(250);
      Writeln('  DroppedDown        : ', BoolToStr(LBagimli.DroppedDown, True));
      if not LBagimli.DroppedDown and (LIzle.Sayac = 0) then
        Atla('popup acilinca AOnFilter tetikleniyor',
          'acilir liste hic acilmadi - pencere gercekten gorunur olmali; ' +
          'bu ortamda olculemedi')
      else
      begin
        Kontrol('popup acilisi AOnFilter i TAM BIR kez tetikledi',
          LIzle.Sayac = 1, Format('sayac = %d', [LIzle.Sayac]));
        Kontrol('AMaster dogru geldi', LIzle.SonMaster = LUsta,
          Ad(LIzle.SonMaster));
        Kontrol('AMasterValue ustanin degeri', VarToStr(LIzle.SonDeger) = '1',
          'deger = ' + VarToStr(LIzle.SonDeger));
      end;
      LBagimli.DroppedDown := False;
      Bekle(150);

      { == 2) SIRA KANITI =============================================== }
      Writeln;
      Writeln('=== 2) SIRA KANITI: isleyicinin degisikligi popup ta ayakta mi? ===');
      Writeln('  (pull inherited''dan SONRA olsaydi LockDataChanged bastirirdi)');
      LVT.Filtered := False;
      LIzle.Sifirla;
      GTablo := LVT;
      GFiltreUlkesi := 2;                  { isleyici Almanya''ya suzecek }
      LBagimli.DroppedDown := True;
      Bekle(250);
      Writeln('  isleyicide kurulan filtre : "', LVT.Filter, '"');
      Writeln('  popup acikken satir       : ', LVT.RecordCount);
      if LIzle.Sayac = 0 then
        Atla('sira kaniti', 'AOnFilter tetiklenmedi - popup acilmadi')
      else
      begin
        Kontrol('isleyicinin kurdugu filtre popup acildiktan SONRA ayakta',
          LVT.Filtered and (LVT.Filter = 'ulke_id = 2'),
          Format('Filtered=%s Filter="%s"',
            [BoolToStr(LVT.Filtered, True), LVT.Filter]));
        Kontrol('liste yeni filtrenin satirlarini iceriyor (2)',
          LVT.RecordCount = 2,
          Format('RecordCount = %d; 6 olsaydi degisiklik bastirilmis olurdu',
            [LVT.RecordCount]));
      end;
      LBagimli.DroppedDown := False;
      Bekle(150);
      GTablo := nil;
      LVT.Filtered := False;

      { == 3) AFilterOnPopup = False ==================================== }
      Writeln;
      Writeln('=== 3) AFilterOnPopup = False otomatik yolu kapatiyor mu? ===');
      LBagimli.Properties.AFilterOnPopup := False;
      LIzle.Sifirla;
      LBagimli.DroppedDown := True;
      Bekle(250);
      Kontrol('AFilterOnPopup=False iken popup hicbir sey tetiklemiyor',
        LIzle.Sayac = 0, Format('sayac = %d', [LIzle.Sayac]));
      LBagimli.DroppedDown := False;
      LBagimli.Properties.AFilterOnPopup := True;
      Bekle(150);

      { == 4) Grid: master bir KOLON ==================================== }
      Writeln;
      Writeln('=== 4) Master bir grid KOLONU iken ===');
      LGrid := TcxGrid.Create(LForm);
      LGrid.Name := 'Izgara'; LGrid.Parent := LForm;
      LGrid.Left := 20; LGrid.Top := 110; LGrid.Width := 600; LGrid.Height := 250;
      LLevel := LGrid.Levels.Add;
      LView := LGrid.CreateView(TcxGridTableView) as TcxGridTableView;
      LLevel.GridView := LView;
      LColUlke := LView.CreateColumn;
      LColUlke.Name := 'colUlke';
      LColUlke.Caption := 'colUlke';
      LColSehir := LView.CreateColumn;
      LColSehir.Name := 'colSehir';
      LColSehir.Caption := 'colSehir';
      LColSehir.PropertiesClass := TRadLookupComboBoxProperties;
      with TRadLookupComboBoxProperties(LColSehir.Properties) do
      begin
        ListSource := LDs;
        KeyFieldNames := 'id';
        ListFieldNames := 'ad';
        AMaster := LColUlke;
        AMasterField := 'ulke_id';
        AOnFilter := LIzle.Filtre;
      end;
      LView.DataController.RecordCount := 2;
      LView.DataController.Values[0, LColUlke.Index] := 1;
      LView.DataController.Values[1, LColUlke.Index] := 2;
      LView.DataController.Post;
      Bekle(150);

      LGrid.SetFocus;
      LView.Controller.FocusedRecordIndex := 1;   { ulke = 2 }
      LView.Controller.FocusedItem := LColSehir;
      Bekle(150);
      LIzle.Sifirla;
      LView.Controller.EditingController.ShowEdit(LColSehir);
      Bekle(250);

      if LView.Controller.EditingItem = nil then
        Atla('grid: master kolonun ODAKLI satirdaki degeri',
          'inplace editor acilmadi - DevExpress odaksiz/gorunmeyen izgarada ' +
          'acmiyor; bu ortamda olculemedi')
      else
      begin
        (LView.Controller.EditingController.Edit as TcxCustomDropDownEdit).DroppedDown := True;
        Bekle(250);
        Kontrol('grid inplace popup u AOnFilter i tetikledi',
          LIzle.Sayac >= 1, Format('sayac = %d', [LIzle.Sayac]));
        Kontrol('AMasterValue ODAKLI satirin degeri (2)',
          VarToStr(LIzle.SonDeger) = '2',
          'deger = ' + VarToStr(LIzle.SonDeger) +
          '  (odakli satir 1, ulke = 2)');
        Kontrol('ASource tan _Host ile KOLONA ulasiliyor',
          Pos('colSehir', LIzle.SonHost) > 0, '_Host = ' + LIzle.SonHost);
        (LView.Controller.EditingController.Edit as TcxCustomDropDownEdit).DroppedDown := False;
        Bekle(100);
        LView.Controller.EditingController.HideEdit(True);
      end;
      Bekle(150);
    finally
      LIzle.Free;
      LForm.Free;
    end;

    Writeln;
    Writeln(Format('=== SONUC: %d basarili, %d hata, %d atlanan ===',
      [GBasari, GHata, GAtlanan]));
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
