program DfmRoundTripTest;

(*
  KARAR SORUSU: "RepositoryItem = ortak davranis, editorun KENDI Properties'i =
  o editore ozel yuk" deseni guvenli mi?

  Ucu birden olculuyor:
    1) Item atanmasi editorun kendi Properties'ini eziyor mu?
    2) Kendi Properties DFM'e YAZILIYOR mu? (yazilmiyorsa tasarimda girilen
       deger calisma zamaninda yok olur - desen sessizce cokerdi)
    3) DFM'den geri okununca deger ve item baglantisi geri geliyor mu?
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, Vcl.Forms, Vcl.Controls,
  cxEdit, cxDropDownEdit, cxLookupEdit, cxDBLookupEdit, cxDBLookupComboBox,
  cxGridCustomTableView, cxGridTableView, cxGridLevel, cxGrid,
  cxGraphics, cxControls, cxLookAndFeels, cxContainer, cxClasses,
  Rad.Dev;

type
  TDenemeForm = class(TForm)
  end;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;

(* RADDEV-008: bu sonda eskiden yalnizca YAZDIRIYORDU. Beklenen degerler
   parantez icinde metin olarak duruyordu; yanlis bir sonuc hicbir sey
   bozmuyor, cikis kodu 0 kaliyordu - yani sonda bir KAPI degildi. *)
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

function Kur(out ARepo: TcxEditRepository; out AItem: TRadComboBoxRepository;
  out AMarka, ATip: TRadComboBox): TDenemeForm;
begin
  Result := TDenemeForm.CreateNew(nil);
  Result.Name := 'Frm';

  ARepo := TcxEditRepository.Create(Result);
  ARepo.Name := 'Repo';
  AItem := TRadComboBoxRepository.Create(Result);
  AItem.Name := 'OrtakTanim';
  AItem.Repository := ARepo;
  AItem.Properties.Items.Text := 'ORTAK-1'#13#10'ORTAK-2';
  AItem.Properties.ACascadeField := 'ORTAK';

  AMarka := TRadComboBox.Create(Result);
  AMarka.Name := 'cbMarka';
  AMarka.Parent := Result;
  ATip := TRadComboBox.Create(Result);
  ATip.Name := 'cbTip';
  ATip.Parent := Result;
end;

var
  LFrm, LFrm2: TDenemeForm;
  LRepo: TcxEditRepository;
  LItem: TRadComboBoxRepository;
  LMarka, LTip: TRadComboBox;
  LBin, LTxt: TMemoryStream;
  LDfm: TStringList;
  LYeniMarka: TRadComboBox;
  LYeniItem: TRadComboBoxRepository;
  i: Integer;

begin
  try
    Application.Initialize;
    RegisterClasses([TDenemeForm, TcxEditRepository, TRadComboBoxRepository,
      TRadComboBox]);

    LFrm := Kur(LRepo, LItem, LMarka, LTip);
    try
      Writeln('=== 1) Item atamasi kendi Properties''i eziyor mu? ===');
      LMarka.Properties.Items.Text := 'MARKA-A'#13#10'MARKA-B';
      LMarka.Properties.ACascadeField := 'marka';
      LTip.Properties.Items.Text := 'TIP-A';
      LTip.Properties.ACascadeField := 'musteri_tipi';
      Writeln('  atamadan ONCE  cbMarka.Properties.Items = ',
        StringReplace(LMarka.Properties.Items.Text, #13#10, '|', [rfReplaceAll]));

      LMarka.RepositoryItem := LItem;
      LTip.RepositoryItem := LItem;

      Writeln('  atamadan SONRA cbMarka.Properties.Items = ',
        StringReplace(LMarka.Properties.Items.Text, #13#10, '|', [rfReplaceAll]));
      Writeln('                 cbMarka.ActiveProperties.Items = ',
        StringReplace(LMarka.ActiveProperties.Items.Text, #13#10, '|', [rfReplaceAll]));
      Writeln('                 cbMarka.Properties.ACascadeField = "',
        LMarka.Properties.ACascadeField, '"');
      Writeln('                 cbTip.Properties.ACascadeField   = "',
        LTip.Properties.ACascadeField, '"');
      Kontrol('item atamasi tuketicinin KENDI Properties''ini EZMIYOR',
        (Pos('MARKA-A', LMarka.Properties.Items.Text) > 0) and
        (LMarka.Properties.ACascadeField = 'marka') and
        (LTip.Properties.ACascadeField = 'musteri_tipi'));

      Writeln;
      Writeln('  -> item''in Properties''i degisince kendi Properties bozuluyor mu?');
      LItem.Properties.Items.Text := 'ORTAK-DEGISTI';
      Writeln('     cbMarka.Properties.Items       = ',
        StringReplace(LMarka.Properties.Items.Text, #13#10, '|', [rfReplaceAll]));
      Writeln('     cbMarka.ActiveProperties.Items = ',
        StringReplace(LMarka.ActiveProperties.Items.Text, #13#10, '|', [rfReplaceAll]));
      Kontrol('item degisince KENDI Properties bozulmuyor',
        Pos('MARKA-A', LMarka.Properties.Items.Text) > 0);
      Kontrol('ActiveProperties item''in yeni degerini gosteriyor',
        Pos('ORTAK-DEGISTI', LMarka.ActiveProperties.Items.Text) > 0);

      Writeln;
      Writeln('=== 2) DFM''e yaziliyor mu? ===');
      LBin := TMemoryStream.Create;
      LTxt := TMemoryStream.Create;
      LDfm := TStringList.Create;
      try
        LBin.WriteComponent(LFrm);
        LBin.Position := 0;
        ObjectBinaryToText(LBin, LTxt);
        LTxt.Position := 0;
        LDfm.LoadFromStream(LTxt);

        for i := 0 to LDfm.Count - 1 do
          if (Pos('cbMarka', LDfm[i]) > 0) or (Pos('cbTip', LDfm[i]) > 0) or
             (Pos('MARKA-', LDfm[i]) > 0) or (Pos('TIP-', LDfm[i]) > 0) or
             (Pos('CascadeField', LDfm[i]) > 0) or (Pos('RepositoryItem', LDfm[i]) > 0) or
             (Pos('ORTAK', LDfm[i]) > 0) or (Pos('colTanim', LDfm[i]) > 0) or
             (Pos('PropertiesClass', LDfm[i]) > 0) then
            Writeln('  | ', Trim(LDfm[i]));

        Writeln;
        Writeln('=== 2b) GRID KOLONU: PropertiesClass once set edilirse? ===');
        var LGrid := TcxGrid.Create(LFrm);   LGrid.Name := 'Grid'; LGrid.Parent := LFrm;
        var LLvl := LGrid.Levels.Add;
        var LView := LGrid.CreateView(TcxGridTableView) as TcxGridTableView;
        LView.Name := 'View';  LLvl.GridView := LView;
        var LCol := LView.CreateColumn;  LCol.Name := 'colTanim';

        Writeln('  PropertiesClass ATANMADAN, item bagli:');
        LCol.RepositoryItem := LItem;
        Writeln('    kolon.Properties nil mi : ', BoolToStr(LCol.Properties = nil, True));

        Writeln('  simdi PropertiesClass atiyoruz (item hala bagli):');
        LCol.PropertiesClass := TRadComboBoxProperties;
        Writeln('    kolon.Properties nil mi : ', BoolToStr(LCol.Properties = nil, True));
        if LCol.Properties <> nil then
        begin
          TRadComboBoxProperties(LCol.Properties).ACascadeField := 'kolon_yuku';
          Writeln('    kolon.Properties.ACascadeField = "',
            TRadComboBoxProperties(LCol.Properties).ACascadeField, '"');
          Writeln('    kolon.GetProperties vs item   : ',
            BoolToStr(Pointer(LCol.GetProperties) = Pointer(LItem.Properties), True),
            '  (True ise etkin olan HALA item''inki)');
        end;

        Writeln;
        Writeln('  -> kolonun kendi Properties''i DFM''e gidiyor mu?');
        var LBin2 := TMemoryStream.Create;
        var LTxt2 := TMemoryStream.Create;
        var LDfm2 := TStringList.Create;
        try
          LBin2.WriteComponent(LFrm);
          LBin2.Position := 0;
          ObjectBinaryToText(LBin2, LTxt2);
          LTxt2.Position := 0;
          LDfm2.LoadFromStream(LTxt2);
          var bulundu := False;
          for i := 0 to LDfm2.Count - 1 do
            if (Pos('colTanim', LDfm2[i]) > 0) or (Pos('kolon_yuku', LDfm2[i]) > 0) or
               (Pos('PropertiesClassName', LDfm2[i]) > 0) or (Pos('RepositoryItem', LDfm2[i]) > 0) then
            begin
              Writeln('    | ', Trim(LDfm2[i]));
              bulundu := True;
            end;
          if not bulundu then
            Writeln('    (kolonla ilgili HICBIR satir yok - kolon DFM''e yazilmadi)');
        finally
          LDfm2.Free; LTxt2.Free; LBin2.Free;
        end;

        Writeln;
        Writeln('=== 3) Geri okununca? ===');
        LBin.Position := 0;
        LFrm2 := TDenemeForm.CreateNew(nil);
        try
          LBin.ReadComponent(LFrm2);
          LYeniMarka := LFrm2.FindComponent('cbMarka') as TRadComboBox;
          LYeniItem  := LFrm2.FindComponent('OrtakTanim') as TRadComboBoxRepository;
          if LYeniMarka = nil then
            Writeln('  cbMarka bulunamadi')
          else
          begin
            Writeln('  cbMarka.RepositoryItem bagli mi : ',
              BoolToStr(LYeniMarka.RepositoryItem = LYeniItem, True));
            Writeln('  cbMarka.Properties.ACascadeField : "',
              LYeniMarka.Properties.ACascadeField, '"  (beklenen "marka")');
            Writeln('  cbMarka.Properties.Items        : ',
              StringReplace(LYeniMarka.Properties.Items.Text, #13#10, '|', [rfReplaceAll]));
            Writeln('  cbMarka.ActiveProperties.Items  : ',
              StringReplace(LYeniMarka.ActiveProperties.Items.Text, #13#10, '|', [rfReplaceAll]));
            Kontrol('DFM geri okununca RepositoryItem yeniden bagli',
              LYeniMarka.RepositoryItem = LYeniItem);
            Kontrol('DFM geri okununca kendi ACascadeField korunmus',
              LYeniMarka.Properties.ACascadeField = 'marka',
              '"' + LYeniMarka.Properties.ACascadeField + '"');
            Kontrol('DFM geri okununca kendi Items korunmus',
              Pos('MARKA-A', LYeniMarka.Properties.Items.Text) > 0);
          end;
          Kontrol('cbMarka DFM''den geri okunabildi', LYeniMarka <> nil);
        finally
          LFrm2.Free;
        end;
      finally
        LDfm.Free;
        LTxt.Free;
        LBin.Free;
      end;
    finally
      LFrm.Free;
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
