program PerConsumerTest;

(*
  SORU: Paylasilan TEK bir RepositoryItem ile, her tuketicinin (combo ya da
  grid kolonu) KENDI yuku olabilir mi?  Ornek: ayni item, bir yerde
  type='marka', baska yerde type='musteri_tipi'.

  Olculen adaylar:
    a) Editorun KENDI Properties'i (ActiveProperties item'inki olsa bile
       ayakta kaliyor mu, yazilabiliyor mu?)
    b) Grid kolonunun kendi Properties'i
    c) Tuketicinin Tag / Name / DataBinding.FieldName alanlari
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, Vcl.Forms, Vcl.Controls,
  cxEdit, cxDropDownEdit, cxLookupEdit, cxDBLookupEdit, cxDBLookupComboBox,
  cxGridCustomTableView, cxGridTableView, cxGridLevel, cxGrid,
  cxGraphics, cxControls, cxLookAndFeels, cxContainer, cxClasses,
  Rad.Dev, Help.Dev;

function AyniMi(A, B: TObject): string;
begin
  if Pointer(A) = Pointer(B) then
    Result := 'AYNI ORNEK'
  else if (A = nil) or (B = nil) then
    Result := 'BIRI NIL'
  else
    Result := 'FARKLI ORNEK';
end;

var
  LForm: TForm;
  LRepo: TcxEditRepository;
  LItem: TRadComboBoxRepository;
  LMarka, LTip: TRadComboBox;
  LGrid: TcxGrid;
  LLevel: TcxGridLevel;
  LView: TcxGridTableView;
  LCol: TcxGridColumn;

begin
  try
    Application.Initialize;
    LForm := TForm.CreateNew(nil);
    try
      LRepo := TcxEditRepository.Create(LForm);
      LItem := TRadComboBoxRepository.Create(LForm);
      LItem.Repository := LRepo;
      LItem.Name := 'OrtakTanimItem';
      LItem.Properties.CascadeField := 'ORTAK';

      LMarka := TRadComboBox.Create(LForm);
      LMarka.Name := 'cbMarka';
      LMarka.Parent := LForm;
      LTip := TRadComboBox.Create(LForm);
      LTip.Name := 'cbMusteriTipi';
      LTip.Parent := LForm;

      Writeln('=== a) Editorun KENDI Properties''i ===');
      Writeln('item baglanmadan once:');
      Writeln('  cbMarka.Properties vs ActiveProperties : ',
        AyniMi(LMarka.Properties, LMarka.ActiveProperties));

      LMarka.RepositoryItem := LItem;
      LTip.RepositoryItem := LItem;

      Writeln('item baglandiktan sonra:');
      Writeln('  cbMarka.Properties vs item.Properties  : ',
        AyniMi(LMarka.Properties, LItem.Properties));
      Writeln('  cbMarka.ActiveProperties vs item.Prop. : ',
        AyniMi(LMarka.ActiveProperties, LItem.Properties));
      Writeln('  cbMarka.Properties vs cbMusteriTipi.Prop: ',
        AyniMi(LMarka.Properties, LTip.Properties));

      Writeln;
      Writeln('  -> kendi Properties''ine yazip okuyabiliyor muyuz?');
      try
        LMarka.Properties.CascadeField := 'marka';
        LTip.Properties.CascadeField := 'musteri_tipi';
        Writeln('     cbMarka.Properties.CascadeField       = "',
          LMarka.Properties.CascadeField, '"');
        Writeln('     cbMusteriTipi.Properties.CascadeField = "',
          LTip.Properties.CascadeField, '"');
        Writeln('     item.Properties.CascadeField          = "',
          LItem.Properties.CascadeField, '" (bozulmamis olmali)');
        Writeln('     cbMarka.ActiveProperties.CascadeField = "',
          LMarka.ActiveProperties.CascadeField, '" (item''inki gelmeli)');
      except
        on E: Exception do
          Writeln('     YAZILAMADI: ', E.ClassName, ': ', E.Message);
      end;

      Writeln;
      Writeln('=== b) Grid kolonunun kendi Properties''i ===');
      LGrid := TcxGrid.Create(LForm);
      LGrid.Parent := LForm;
      LLevel := LGrid.Levels.Add;
      LView := LGrid.CreateView(TcxGridTableView) as TcxGridTableView;
      LLevel.GridView := LView;
      LCol := LView.CreateColumn;
      LCol.Name := 'colTanim';
      LCol.RepositoryItem := LItem;
      Writeln('  kolon.Properties nil mi   : ', BoolToStr(LCol.Properties = nil, True));
      Writeln('  kolon.GetProperties vs item: ', AyniMi(LCol.GetProperties, LItem.Properties));

      Writeln;
      Writeln('=== c) Tuketici uzerindeki diger tasiyicilar ===');
      LMarka.Tag := 11;
      LCol.Tag := 22;
      Writeln('  cbMarka.Tag        = ', LMarka.Tag);
      Writeln('  cbMarka.Name       = ', LMarka.Name);
      Writeln('  kolon.Tag          = ', LCol.Tag);
      Writeln('  kolon.Name         = ', LCol.Name);
      Writeln('  kolon.DataBinding sinifi = ', LCol.DataBinding.ClassName);
      Writeln;
      Writeln('=== d) help.Dev helper''lari ===');
      Writeln('  item._ConsumerCount(LForm) = ', LItem._ConsumerCount(LForm), ' (beklenen 3)');
      var LArr := LItem._Consumers(LForm);
      for var k := 0 to High(LArr) do
        Writeln(Format('    [%d] %-22s %s', [k, LArr[k].ClassName, LArr[k].Name]));
      Writeln('  item._IsUsedBy(cbMarka) = ', BoolToStr(LItem._IsUsedBy(LMarka), True));
      Writeln('  item._IsUsedBy(LForm)   = ', BoolToStr(LItem._IsUsedBy(LForm), True));
      Writeln('  cbMarka._Host           = ', LMarka._Host.Name, ' (grid disi -> kendisi)');

      Writeln;
      Writeln('=== e) Bilesen-bagimsiz erisimciler ===');
      LMarka.Properties.CascadeField := 'marka';
      LCol.PropertiesClass := TRadComboBoxProperties;
      TRadComboBoxProperties(LCol.Properties).CascadeField := 'kolon_marka';
      LCol.Caption := 'Tanim Kolonu';
      LMarka.EditValue := 'M-1';

      for var c in [TComponent(LMarka), TComponent(LCol)] do
      begin
        Writeln('  ', c.ClassName, ' (', c.Name, ')');
        var LOwn := _OwnProperties(c);
        var LAct := _ActiveProperties(c);
        Writeln('    _OwnProperties    : ', BoolToStr(LOwn <> nil, True),
          '  CascadeField="', TRadComboBoxProperties(LOwn).CascadeField, '"');
        Writeln('    _ActiveProperties : ', BoolToStr(LAct <> nil, True),
          '  = item.Properties mi: ', BoolToStr(Pointer(LAct) = Pointer(LItem.Properties), True));
        Writeln('    _ValueOf          : ', VarToStr(_ValueOf(c)));
        Writeln('    _CaptionOf        : ', _CaptionOf(c));
        Writeln('    _DataSetOf        : ', BoolToStr(_DataSetOf(c) <> nil, True), ' (baglanti yok -> False beklenir)');
        Writeln('    _FieldOf          : ', BoolToStr(_FieldOf(c) <> nil, True), ' (baglanti yok -> False beklenir)');
      end;
    finally
      LForm.Free;
    end;
  except
    on E: Exception do
      Writeln('HATA: ', E.ClassName, ': ', E.Message);
  end;
end.
