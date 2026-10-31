program CustomFieldsFrameTest;

(*
  TRadCustomFieldsFrame + TRadCustomFieldDesigner sondasi (rad.dev.customfields).
  PostgreSQL testdb (test-db.env) uzerinde: tanimlar store ile kurulur, cerceve
  kodla yaratilir; editor siniflari, baglama, |a|b| yazimi, zorunlu/varsayilan
  zincirleme, duzen kaydet/yukle/sifirla ve sonradan eklenen alan, tanim diyalogu
  olculur. Tablolar sonda silinir.
*)

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Variants, System.IOUtils, System.DateUtils,
  Vcl.Forms, Vcl.Controls, Data.DB,
  Uni, UniProvider, PostgreSQLUniProvider,
  cxEdit, cxDBEdit, cxTextEdit, cxCalendar, cxCurrencyEdit, cxCalc, cxSpinEdit, cxCheckBox, cxImageComboBox,
  cxMemo, cxTimeEdit, cxDropDownEdit, cxLookAndFeelPainters, dxLayoutContainer,
  rad.sqlfilter, rad.customfield, Help.uni, rad.dev, rad.dev.customfields, rad.dev.customfielddesigner;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;
  GEnv: TStringList;

procedure EnvYukle;
var
  LPath: string;
begin
  GEnv := TStringList.Create;
  LPath := TPath.Combine(TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'), 'rad'), 'test-db.env');
  if TFile.Exists(LPath) then
    GEnv.LoadFromFile(LPath, TEncoding.UTF8);
end;

function Env(const AKey: string; const ADefault: string = ''): string;
var
  i: Integer;
begin
  Result := GetEnvironmentVariable(AKey);
  if Result <> '' then Exit;
  for i := 0 to GEnv.Count - 1 do
    if GEnv[i].StartsWith(AKey + '=') then
      Exit(Trim(GEnv[i].Substring(Length(AKey) + 1)));
  Result := ADefault;
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
end;

procedure Olcum(const AAd, ADeger: string);
begin
  Writeln('  [OLCUM] ', AAd, ' = ', ADeger);
end;

procedure Firlatir(const AAd: string; AProc: TProc);
begin
  try
    AProc;
    Kontrol(AAd, False, 'istisna firlatilmadi');
  except
    on E: ERadCustomField do Kontrol(AAd, True);
    on E: Exception do Kontrol(AAd, False, E.ClassName + ': ' + E.Message);
  end;
end;

procedure SessizSil(ACon: TUniConnection; const ATable: string);
begin
  try
    ACon.ExecSQL('drop table ' + ATable);
  except
  end;
end;

procedure Temizle(ACon: TUniConnection);
begin
  SessizSil(ACon, TRadCustomFieldDdl.LayoutTable);
  SessizSil(ACon, TRadCustomFieldDdl.FieldTable);
  SessizSil(ACon, TRadCustomFieldDdl.GroupTable);
  SessizSil(ACon, 'rad_test_cf');
end;

function Alan(AGroup: TRadCustomFieldGroupDef; const ACaption: string; AType: TRadCustomFieldType;
  const AOptions: string = ''; const ADefault: string = ''; ARequired: Boolean = False): TRadCustomFieldDef;
begin
  Result := TRadCustomFieldDef.Create;
  Result.GroupId := AGroup.Id;
  Result.TableName := 'rad_test_cf';
  Result.Caption := ACaption;
  Result.FieldType := AType;
  Result.Length := 30;
  Result.Decimals := 3;
  Result.SetOptionsText(AOptions);
  Result.DefaultValue := ADefault;
  Result.Required := ARequired;
end;

procedure Kur(AStore: IRadCustomFieldStore; var AG1, AG2: TRadCustomFieldGroupDef);
var
  D: TRadCustomFieldDef;
  procedure Ekle(ADef: TRadCustomFieldDef);
  begin
    try
      AStore.AddField(ADef);
    finally
      ADef.Free;
    end;
  end;
begin
  AStore.EnsureDefinitionTables;
  AG1 := TRadCustomFieldGroupDef.Create;
  AG1.TableName := 'rad_test_cf'; AG1.Name := 'Genel'; AG1.Order := 1;
  AStore.AddGroup(AG1);
  AG2 := TRadCustomFieldGroupDef.Create;
  AG2.TableName := 'rad_test_cf'; AG2.Name := 'Ek'; AG2.Order := 2;
  AStore.AddGroup(AG2);
  Ekle(Alan(AG1, 'Metin', cfText, '', '', True));                     // ozel_1 zorunlu
  Ekle(Alan(AG1, 'Tutar', cfMoney, '', '10'));                        // ozel_2 varsayilan 10
  Ekle(Alan(AG1, 'Secim', cfMultiChoice, 'a|A'#13#10'b|B'#13#10'ab|AB', 'a')); // ozel_3 varsayilan |a|
  Ekle(Alan(AG1, 'Tekli', cfSingleChoice, 'x|X'#13#10'y|Y'));         // ozel_4
  Ekle(Alan(AG1, 'Tarih', cfDate));                                   // ozel_5
  Ekle(Alan(AG1, 'Aktif', cfBoolean, '', 'evet'));                    // ozel_6
  Ekle(Alan(AG2, 'Not', cfMemo));                                     // ozel_7
  Ekle(Alan(AG2, 'Sayi', cfInteger));                                 // ozel_8
  Ekle(Alan(AG2, 'Oran', cfDecimal));                                 // ozel_9
  Ekle(Alan(AG2, 'Saat', cfTime));                                    // ozel_10
  Ekle(Alan(AG2, 'Zaman', cfDateTime));                               // ozel_11
  D := Alan(AG2, 'Pasif', cfText);
  try
    AStore.AddField(D);                                               // ozel_12 -> pasif yapilacak
    D.Active := False;
    AStore.UpdateField(D);
  finally
    D.Free;
  end;
end;

function SayF(ACon: TUniConnection; AFrame: TRadCustomFieldsFrame; const AAlias: string): Integer;
var
  LF: IRadSqlFilter;
  LQ: TUniQuery;
begin
  LF := ACon._NewFilter;
  AFrame.ApplyFilter(LF, AAlias);
  LQ := ACon._CreateQuery('select count(*) from rad_test_cf ' + LF.GetWhere, False);
  try
    LQ._ApplyFilter(LF);
    LQ.Open;
    Result := LQ.Fields[0].AsInteger;
  finally
    LQ.Free;
  end;
end;

procedure Senaryo(ACon: TUniConnection);
var
  LStore: IRadCustomFieldStore;
  G1, G2: TRadCustomFieldGroupDef;
  LForm: TForm;
  LFrame: TRadCustomFieldsFrame;
  LQ: TUniQuery;
  LDs: TDataSource;
  LEd: TWinControl;
  LItem: TdxLayoutItem;
  LDlg: TRadCustomFieldDesigner;
  LNew: TRadCustomFieldDef;
  LMs: TMemoryStream;
  LFilt, LDef: TRadCustomFieldsFrame;
  LF: IRadSqlFilter;
begin
  Temizle(ACon);
  ACon.ExecSQL('create table rad_test_cf (id integer not null primary key, ad varchar(40))');
  ACon.ExecSQL('insert into rad_test_cf (id, ad) values (1, ''Bir'')');
  LStore := ACon._CustomFields;
  Kur(LStore, G1, G2);
  try
    LQ := ACon._CreateQuery('select * from rad_test_cf order by id', True);
    LDs := TDataSource.Create(nil);
    LForm := TForm.CreateNew(nil);
    try
      LDs.DataSet := LQ;
      LFrame := TRadCustomFieldsFrame.Create(LForm);
      LFrame.Parent := LForm;
      LFrame.Align := alClient;
      LFrame.Store := LStore;
      LFrame.TableName := 'rad_test_cf';
      LFrame.DataSource := LDs;
      LFrame.UserId := 7;
      LFrame.CanDesign := True;
      LFrame.Rebuild;

      Kontrol('F01 iki grup', LFrame.Groups.Count = 2);
      Kontrol('F02 kok sekmeli', LFrame.Layout.Items.LayoutDirection = ldTabbed);
      Kontrol('F03 grup item', LFrame.GroupItemOf(G1.Id) <> nil);
      Kontrol('F04 grup basligi', (LFrame.GroupItemOf(G2.Id) <> nil) and (LFrame.GroupItemOf(G2.Id).CaptionOptions.Text = 'Ek'));
      Kontrol('F05 11 aktif item', LFrame.Layout.AbsoluteItemCount = 2 + 11, IntToStr(LFrame.Layout.AbsoluteItemCount));
      Kontrol('F06 pasif alan yok', LFrame.ItemOf('ozel_12') = nil);
      LItem := LFrame.ItemOf('ozel_1');
      Kontrol('F07 item adi/basligi', (LItem <> nil) and (LItem.Name = 'li_ozel_1') and (LItem.CaptionOptions.Text = 'Metin'));
      Kontrol('F08 item grubu', (LItem <> nil) and (LItem.Parent = LFrame.GroupItemOf(G1.Id)));
      Kontrol('F09 ozel_7 ikinci grupta', LFrame.ItemOf('ozel_7').Parent = LFrame.GroupItemOf(G2.Id));

      LEd := LFrame.EditorOf('ozel_1');
      Kontrol('F10 metin editoru', LEd is TcxDBTextEdit);
      Kontrol('F11 MaxLength', TcxDBTextEdit(LEd).Properties.MaxLength = 30);
      Kontrol('F12 baglama', (TcxDBTextEdit(LEd).DataBinding.DataSource = LDs) and (TcxDBTextEdit(LEd).DataBinding.DataField = 'ozel_1'));
      Kontrol('F13 para editoru', LFrame.EditorOf('ozel_2') is TcxDBCurrencyEdit);
      Kontrol('F14 coklu editoru', LFrame.EditorOf('ozel_3') is TRadDBCheckComboBox);
      Kontrol('F15 coklu 3 item + wrap', (TRadDBCheckComboBox(LFrame.EditorOf('ozel_3')).Properties.Items.Count = 3) and
        TRadDBCheckComboBox(LFrame.EditorOf('ozel_3')).Properties.AValueWrap);
      Kontrol('F16 tekli editoru', (LFrame.EditorOf('ozel_4') is TcxDBImageComboBox) and
        (TcxDBImageComboBox(LFrame.EditorOf('ozel_4')).Properties.Items.Count = 2));
      Kontrol('F17 tarih editoru', (LFrame.EditorOf('ozel_5') is TcxDBDateEdit) and (TcxDBDateEdit(LFrame.EditorOf('ozel_5')).Properties.Kind = ckDate));
      Kontrol('F18 bool editoru', LFrame.EditorOf('ozel_6') is TcxDBCheckBox);
      Kontrol('F19 memo editoru', LFrame.EditorOf('ozel_7') is TcxDBMemo);
      Kontrol('F20 tamsayi editoru', (LFrame.EditorOf('ozel_8') is TcxDBSpinEdit) and (TcxDBSpinEdit(LFrame.EditorOf('ozel_8')).Properties.ValueType = vtInt));
      Kontrol('F21 ondalik editoru', (LFrame.EditorOf('ozel_9') is TcxDBCalcEdit) and (TcxDBCalcEdit(LFrame.EditorOf('ozel_9')).Properties.DisplayFormat = ',0.000'));
      Kontrol('F22 saat editoru', LFrame.EditorOf('ozel_10') is TcxDBTimeEdit);
      Kontrol('F23 zaman editoru', (LFrame.EditorOf('ozel_11') is TcxDBDateEdit) and (TcxDBDateEdit(LFrame.EditorOf('ozel_11')).Properties.Kind = ckDateTime));
      Kontrol('F24 editor adi', LEd.Name = 'ed_ozel_1');

      // veri -> editor
      LQ.Edit;
      LQ.FieldByName('ozel_3').AsString := '|a|b|';
      LQ.FieldByName('ozel_1').AsString := 'dolu';
      LQ.Post;
      Kontrol('F25 coklu editor 2 secili', Length(TRadDBCheckComboBox(LFrame.EditorOf('ozel_3')).AValues) = 2,
        IntToStr(Length(TRadDBCheckComboBox(LFrame.EditorOf('ozel_3')).AValues)));
      // editor -> veri (wrap)
      LQ.Edit;
      TRadDBCheckComboBox(LFrame.EditorOf('ozel_3')).AValues := ['ab'];
      TRadDBCheckComboBox(LFrame.EditorOf('ozel_3')).PostEditValue;
      Kontrol('F26 editor |ab| yazdi', LQ.FieldByName('ozel_3').AsString = '|ab|', LQ.FieldByName('ozel_3').AsString);
      LQ.Post;
      Kontrol('F27 DB''de |ab|', ACon._sqlResults('select ozel_3 from rad_test_cf where id = 1', '') = '|ab|');

      // varsayilan + zorunlu
      LQ.Append;
      LQ.FieldByName('id').AsInteger := 2;
      Kontrol('F28 varsayilan para 10', Abs(LQ.FieldByName('ozel_2').AsFloat - 10) < 1e-9);
      Kontrol('F29 varsayilan coklu |a|', LQ.FieldByName('ozel_3').AsString = '|a|', LQ.FieldByName('ozel_3').AsString);
      Kontrol('F30 varsayilan bool', LQ.FieldByName('ozel_6').AsBoolean);
      Kontrol('F31 eksik zorunlu listesi', (Length(LFrame.MissingRequired) = 1) and (LFrame.MissingRequired[0] = 'Metin'));
      Firlatir('F32 zorunlu bos: Post hata', procedure begin LQ.Post; end);
      LQ.FieldByName('ozel_1').AsString := 'x';
      LQ.Post;
      Kontrol('F33 dolunca Post gecer', ACon._sqlResults('select count(*) from rad_test_cf', 0) = 2);
      LFrame.AutoValidate := False;
      LQ.Append;
      LQ.FieldByName('id').AsInteger := 3;
      LQ.Post;
      Kontrol('F34 AutoValidate kapali: Post gecer', ACon._sqlResults('select count(*) from rad_test_cf', 0) = 3);
      LFrame.AutoValidate := True;

      // duzen: once ham DevExpress akisi tek basina (Rebuild yok)
      LMs := TMemoryStream.Create;
      try
        LFrame.ItemOf('ozel_5').Visible := False;
        LFrame.Layout.SaveToStream(LMs);
        Olcum('ham dx akisi boyutu', IntToStr(LMs.Size));
        LFrame.ItemOf('ozel_5').Visible := True;
        LMs.Position := 0;
        LFrame.Layout.LoadFromStream(LMs);
        Olcum('ham dx akisi Visible=False geri yukledi mi', BoolToStr(not LFrame.ItemOf('ozel_5').Visible, True) +
          ' (beklenen False: DevExpress Visible saklamaz, cerceve kendi listesinde tasir)');
        LFrame.ItemOf('ozel_5').Visible := True;
      finally
        LMs.Free;
      end;
      // duzen: gizle, kaydet, yeniden kur
      LFrame.ItemOf('ozel_5').Visible := False;
      LFrame.SaveLayout;
      LFrame.Rebuild;
      Kontrol('F35 kayitli duzen: ozel_5 gizli', not LFrame.ItemOf('ozel_5').Visible);
      Kontrol('F36 kayitli duzen: ozel_1 gorunur', LFrame.ItemOf('ozel_1').Visible);
      LNew := Alan(G2, 'Sonradan', cfText);
      try
        LStore.AddField(LNew);
        Kontrol('F37 yeni kolon ozel_13', LNew.ColumnName = 'ozel_13', LNew.ColumnName);
      finally
        LNew.Free;
      end;
      LQ.Close;
      LQ.Open;   // dinamik alanlar: yeni kolon gelir
      LFrame.Rebuild;
      Kontrol('F38 sonradan eklenen gorunur', (LFrame.ItemOf('ozel_13') <> nil) and LFrame.ItemOf('ozel_13').Visible);
      Kontrol('F39 sonradan eklenen kendi grubunda', LFrame.ItemOf('ozel_13').Parent = LFrame.GroupItemOf(G2.Id));
      Kontrol('F40 gizli hala gizli', not LFrame.ItemOf('ozel_5').Visible);
      LFrame.ResetLayout;
      Kontrol('F41 sifirla: ozel_5 gorunur', LFrame.ItemOf('ozel_5').Visible);
      LForm.HandleNeeded;   // Customization pencere ister (CanAllocateHandle); gosterilmemis formda reddediyor
      LFrame.Customizing := True;
      Kontrol('F42 ozellestirme acildi', LFrame.Layout.Customization);
      LFrame.Customizing := False;

      // dataset kancasi geri alinir
      LFrame.DataSource := nil;
      Kontrol('F43 kanca kalkti', not Assigned(LQ.BeforePost) and not Assigned(LQ.OnNewRecord));
      LFrame.DataSource := LDs;
      Kontrol('F44 kanca geri geldi', Assigned(LQ.BeforePost));

      // tanim diyalogu (kodla surulur)
      LDlg := TRadCustomFieldDesigner.CreateDesigner(nil, LStore, 'rad_test_cf');
      try
        Kontrol('D01 gruplar yuklendi', (LDlg.Groups.Count = 2) and (LDlg.LbGroups.Items.Count = 2));
        Kontrol('D02 ilk grup secili', (LDlg.CurrentGroup <> nil) and (LDlg.CurrentGroup.Name = 'Genel'));
        Kontrol('D03 alan listesi', LDlg.LbFields.Items.Count = 6);
        LDlg.SelectField(0);
        Kontrol('D04 alan gosterildi', (LDlg.EdCaption.Text = 'Metin') and not LDlg.CbType.Enabled and LDlg.CbRequired.Checked);
        LDlg.EdCaption.Text := 'Metin 2';
        LDlg.EdLength.Value := 60;
        LDlg.SaveField;
        Kontrol('D05 guncellendi', (LDlg.CurrentField <> nil) and (LDlg.CurrentField.Caption = 'Metin 2') and (LDlg.CurrentField.Length = 60));
        LDlg.NewField;
        Kontrol('D06 yeni alan kipi', (LDlg.CurrentField = nil) and LDlg.CbType.Enabled and LDlg.CbFilterable.Checked);
        LDlg.EdCaption.Text := 'Diyalogdan';
        LDlg.CbType.ItemIndex := Ord(cfSingleChoice);
        LDlg.MemOptions.Lines.Text := 'k1|Bir'#13#10'k2|Iki';
        LDlg.SaveField;
        Kontrol('D07 diyalogdan eklendi', (LDlg.CurrentField <> nil) and (LDlg.CurrentField.ColumnName = 'ozel_14') and
          (LDlg.CurrentField.FieldType = cfSingleChoice) and (Length(LDlg.CurrentField.Options) = 2));
        Kontrol('D08 degisti bayragi', LDlg.Modified);
        LDlg.NewField;
        LDlg.EdCaption.Text := '';
        Firlatir('D09 bos baslik reddedilir', procedure begin LDlg.SaveField; end);
        LDlg.NewGroup;
        LDlg.EdGroupName.Text := 'Yeni Grup';
        LDlg.SaveGroup;
        Kontrol('D10 grup eklendi', (LDlg.Groups.Count = 3) and (LDlg.CurrentGroup <> nil) and (LDlg.CurrentGroup.Name = 'Yeni Grup'));
        LDlg.SelectGroup(1);
        Kontrol('D11 grup secimi', LDlg.CurrentGroup.Name = 'Ek');
        Kontrol('D12 pasif alan listede', Pos('(pasif)', LDlg.LbFields.Items.Text) > 0);
      finally
        LDlg.Free;
      end;
      LQ.Close;
      LQ.Open;
      LFrame.Rebuild;
      Kontrol('F45 diyalog sonrasi 13 item', LFrame.ItemOf('ozel_14') <> nil);
      Kontrol('F46 bos grup sekme olur', LFrame.Layout.FindItem('grp_' + IntToStr(LFrame.Groups[2].Id)) <> nil);
      Olcum('AbsoluteItemCount', IntToStr(LFrame.Layout.AbsoluteItemCount));

      // ---- filtre kipi ----
      LFilt := TRadCustomFieldsFrame.Create(LForm);
      LFilt.Parent := LForm;
      LFilt.Store := LStore;
      LFilt.TableName := 'rad_test_cf';
      LFilt.Mode := cfmFilter;
      LFilt.FilterFlaggedOnly := False;
      LFilt.Rebuild;
      Kontrol('FL01 bagsiz editorler', (LFilt.EditorOf('ozel_1') is TcxTextEdit) and (LFilt.EditorOf('ozel_2') is TcxCurrencyEdit) and
        (LFilt.EditorOf('ozel_3') is TRadCheckComboBox) and (LFilt.EditorOf('ozel_4') is TcxImageComboBox) and
        (LFilt.EditorOf('ozel_5') is TcxDateEdit) and (LFilt.EditorOf('ozel_6') is TcxCheckBox) and
        (LFilt.EditorOf('ozel_8') is TcxSpinEdit) and (LFilt.EditorOf('ozel_9') is TcxCalcEdit) and
        (LFilt.EditorOf('ozel_10') is TcxTimeEdit) and (LFilt.EditorOf('ozel_11') is TcxDateEdit));
      Kontrol('FL02 bos baslangic: kosul yok', not LFilt.HasFilterValues);
      LF := ACon._NewFilter;
      LFilt.ApplyFilter(LF);
      Kontrol('FL03 bos filtre', LF.IsEmpty, LF.GetDebugSql);
      Kontrol('FL04 aralik ikinci editor', (LFilt.EditorToOf('ozel_2') is TcxCurrencyEdit) and (LFilt.EditorToOf('ozel_5') is TcxDateEdit) and
        (LFilt.EditorToOf('ozel_1') = nil));
      Kontrol('FL05 aralik item adi', LFilt.Layout.FindItem('li_ozel_2_2') <> nil);
      Kontrol('FL06 tekli (tumu) secenegi', TcxImageComboBox(LFilt.EditorOf('ozel_4')).Properties.Items.Count = 3);
      Kontrol('FL07 bool gri', TcxCheckBox(LFilt.EditorOf('ozel_6')).State = cbsGrayed);
      Firlatir('FL08 duzenleme kipinde ApplyFilter hata', procedure begin LFrame.ApplyFilter(ACon._NewFilter); end);

      // metin: Contains
      TcxTextEdit(LFilt.EditorOf('ozel_1')).Text := 'dol';
      Kontrol('FL09 metin Contains', SayF(ACon, LFilt, '') = 1);
      Kontrol('FL10 HasFilterValues', LFilt.HasFilterValues);
      LF := ACon._NewFilter;
      LFilt.ApplyFilter(LF, 'c');
      Kontrol('FL11 alias', Pos('c.ozel_1', LF.GetWhere) > 0, LF.GetWhere);
      LFilt.ClearFilter;
      Kontrol('FL12 ClearFilter', not LFilt.HasFilterValues and (TcxTextEdit(LFilt.EditorOf('ozel_1')).Text = ''));
      Kontrol('FL13 temizlenince hepsi', SayF(ACon, LFilt, '') = 3);

      // para araligi: satir 2,3 = 10, satir 1 null
      TcxCurrencyEdit(LFilt.EditorOf('ozel_2')).Value := 5;
      TcxCurrencyEdit(LFilt.EditorToOf('ozel_2')).Value := 20;
      Kontrol('FL14 para Between', SayF(ACon, LFilt, '') = 2);
      TcxCurrencyEdit(LFilt.EditorOf('ozel_2')).Clear;
      Kontrol('FL15 yalniz ust sinir', SayF(ACon, LFilt, '') = 2);
      TcxCurrencyEdit(LFilt.EditorToOf('ozel_2')).Value := 9;
      Kontrol('FL16 ust sinir 9', SayF(ACon, LFilt, '') = 0);
      LFilt.ClearFilter;

      // bool: satir 2,3 true, satir 1 null
      TcxCheckBox(LFilt.EditorOf('ozel_6')).State := cbsChecked;
      Kontrol('FL17 bool true', SayF(ACon, LFilt, '') = 2);
      TcxCheckBox(LFilt.EditorOf('ozel_6')).State := cbsUnchecked;
      Kontrol('FL18 bool false', SayF(ACon, LFilt, '') = 0);
      LFilt.ClearFilter;
      Kontrol('FL19 bool gri = kosul yok', SayF(ACon, LFilt, '') = 3);

      // coklu: satir1 |ab|, satir 2,3 |a| (varsayilan)
      TRadCheckComboBox(LFilt.EditorOf('ozel_3')).AValues := ['ab'];
      Kontrol('FL20 coklu tek kod', SayF(ACon, LFilt, '') = 1);
      TRadCheckComboBox(LFilt.EditorOf('ozel_3')).AValues := ['a', 'ab'];
      Kontrol('FL21 coklu OR', SayF(ACon, LFilt, '') = 3);
      LF := ACon._NewFilter;
      LFilt.ApplyFilter(LF);
      Kontrol('FL22 coklu OR sql', Pos(' OR ', LF.GetWhere) > 0, LF.GetWhere);
      LFilt.ClearFilter;

      // tekli: deger yok -> 0; (tumu) -> hepsi
      TcxImageComboBox(LFilt.EditorOf('ozel_4')).EditValue := 'x';
      Kontrol('FL23 tekli Equal', SayF(ACon, LFilt, '') = 0);
      TcxImageComboBox(LFilt.EditorOf('ozel_4')).ItemIndex := 0;
      Kontrol('FL24 tekli (tumu)', SayF(ACon, LFilt, '') = 3);

      // tarih araligi: satir1 ozel_5 = 20.01.2026 (F25 sonrasi null; burada yazalim)
      ACon.ExecSQL('update rad_test_cf set ozel_5 = ''2026-01-20'' where id = 1');
      TcxDateEdit(LFilt.EditorOf('ozel_5')).Date := EncodeDate(2026, 1, 1);
      TcxDateEdit(LFilt.EditorToOf('ozel_5')).Date := EncodeDate(2026, 1, 20);
      Kontrol('FL25 tarih Between (WholeDay ust sinir dahil)', SayF(ACon, LFilt, '') = 1);
      LF := ACon._NewFilter;
      LFilt.ApplyFilter(LF);
      Kontrol('FL26 tarih yari acik', Pos('< ''2026-01-21''', LF.GetDebugSql) > 0, LF.GetDebugSql);
      LFilt.ClearFilter;

      // tamsayi araligi: spin bos = kosul yok
      Kontrol('FL27 spin bos Null', VarIsNull(TcxSpinEdit(LFilt.EditorOf('ozel_8')).EditValue) or (TcxSpinEdit(LFilt.EditorOf('ozel_8')).Text = ''));
      TcxSpinEdit(LFilt.EditorOf('ozel_8')).Value := 1;
      Kontrol('FL28 tamsayi alt sinir', SayF(ACon, LFilt, '') = 0);
      LFilt.ClearFilter;

      // yalniz filtrele_mi isaretliler
      LNew := LStore.LoadGroups('rad_test_cf', True)[0].Fields[0].Clone;   // ozel_1
      try
        LNew.Filterable := True;
        LStore.UpdateField(LNew);
      finally
        LNew.Free;
      end;
      LFilt.FilterFlaggedOnly := True;
      Kontrol('FL29 yalniz isaretli alan', (LFilt.EditorOf('ozel_1') <> nil) and (LFilt.EditorOf('ozel_2') = nil));
      Kontrol('FL30 filtre kipinde zorunlu listesi bos', Length(LFilt.MissingRequired) = 0);

      // DefaultStore: Store atanmadan
      TRadCustomFieldsFrame.DefaultStore := LStore;
      try
        LDef := TRadCustomFieldsFrame.Create(LForm);
        LDef.Parent := LForm;
        LDef.TableName := 'rad_test_cf';
        LDef.Mode := cfmFilter;
        LDef.FilterFlaggedOnly := False;
        LDef.Rebuild;
        Kontrol('FL31 DefaultStore ile kuruldu', (LDef.Store = LStore) and (LDef.Groups.Count = 3));
      finally
        TRadCustomFieldsFrame.DefaultStore := nil;
      end;
      Kontrol('FL32 DefaultStore nil: Store nil', LDef.Store = nil);
      Kontrol('FL33 kendi Store ustun', LFilt.Store = LStore);
    finally
      LForm.Free;
      LDs.Free;
      LQ.Free;
    end;
  finally
    G1.Free;
    G2.Free;
  end;
  Temizle(ACon);
end;

var
  LCon: TUniConnection;
begin
  EnvYukle;
  try
    LCon := TUniConnection.Create(nil);
    try
      LCon.ProviderName := 'PostgreSQL';
      LCon.Server := Env('RAD_PG_HOST', '127.0.0.1');
      LCon.Port := StrToIntDef(Env('RAD_PG_PORT', '5432'), 5432);
      LCon.Database := Env('RAD_PG_DB', 'testdb');
      LCon.Username := Env('RAD_PG_USER', 'postgres');
      LCon.Password := Env('RAD_PG_PASS');
      LCon.LoginPrompt := False;
      try
        LCon.Connect;
        Writeln('Baglandi: PG -> ', LCon.Server, '/', LCon.Database);
        try
          Senaryo(LCon);
        except
          on E: Exception do
          begin
            Inc(GHata);
            Writeln('  [PATLADI] ', E.ClassName, ': ', E.Message);
            try Temizle(LCon); except end;
          end;
        end;
      except
        on E: Exception do
        begin
          Inc(GHata);
          Writeln('  [BAGLANAMADI] ', E.Message);
        end;
      end;
    finally
      LCon.Free;
    end;
  finally
    GEnv.Free;
  end;
  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    Halt(1);
end.
