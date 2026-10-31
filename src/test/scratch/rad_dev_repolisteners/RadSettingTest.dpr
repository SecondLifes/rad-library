program RadSettingTest;

(*
  TcxRadSetting + TcxRadDataBinding sondasi.

  Olculen sozlesme:
    R01-R03  varsayilanlar, Key/Tag/Control atama, eski adlarla yonlendirme
    R04-R05  Control/Master yok olunca isaretci nil'lenir (sarkan isaretci yok)
    R06-R08  Master tip ve dairesel denetimi
    R09-R10  Assign / DoAssign kopyasi (Data KOPYALANMAZ)
    R11-R14  DataBinding: okuma, kapali dataset, yok olan DataSource, kopya
    R15-R17  DFM: yazilir, geri okunur, eski adlar DFM'e YAZILMAZ ama okunur
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, Vcl.Forms, Vcl.Controls,
  Vcl.StdCtrls, Data.DB,
  cxEdit, cxDropDownEdit, cxLookupEdit, cxDBLookupEdit, cxDBLookupComboBox,
  cxGraphics, cxControls, cxLookAndFeels, cxContainer, cxClasses, dxmdaset,
  Rad.Dev;

type
  TDenemeForm = class(TForm)
  end;

  TIzle = class
  public
    Cagri: Integer;
    SonKaynak, SonHedef: TComponent;
    procedure Kaskad(Sender: TRadComboBoxProperties; ASource, ATarget: TComponent;
      const AValue: Variant);
  end;

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

procedure TIzle.Kaskad(Sender: TRadComboBoxProperties; ASource, ATarget: TComponent;
  const AValue: Variant);
begin
  Inc(Cagri);
  SonKaynak := ASource;
  SonHedef := ATarget;
end;

function HataSinifi(const AProc: TProc): string;
begin
  Result := '';
  try
    AProc;
  except
    on E: Exception do
      Result := E.ClassName;
  end;
end;

function YeniVeri(AOwner: TComponent; out ADS: TDataSource): TdxMemData;
var
  LFld: TStringField;
begin
  Result := TdxMemData.Create(AOwner);
  LFld := TStringField.Create(AOwner);
  LFld.FieldName := 'ad';
  LFld.Size := 20;
  LFld.DataSet := Result;
  Result.Open;
  Result.Append;
  Result.FieldByName('ad').AsString := 'Bir';
  Result.Post;
  Result.Append;
  Result.FieldByName('ad').AsString := 'Iki';
  Result.Post;
  Result.First;
  ADS := TDataSource.Create(AOwner);
  ADS.DataSet := Result;
end;

function DfmMetni(AForm: TComponent): string;
var
  LBin, LTxt: TMemoryStream;
  LList: TStringList;
begin
  LBin := TMemoryStream.Create;
  LTxt := TMemoryStream.Create;
  LList := TStringList.Create;
  try
    LBin.WriteComponent(AForm);
    LBin.Position := 0;
    ObjectBinaryToText(LBin, LTxt);
    LTxt.Position := 0;
    LList.LoadFromStream(LTxt);
    Result := LList.Text;
  finally
    LList.Free;
    LTxt.Free;
    LBin.Free;
  end;
end;

function DfmdenOku(const AMetin: string): TDenemeForm;
var
  LSrc: TStringStream;
  LBin: TMemoryStream;
begin
  LSrc := TStringStream.Create(AMetin);
  LBin := TMemoryStream.Create;
  try
    ObjectTextToBinary(LSrc, LBin);
    LBin.Position := 0;
    Result := TDenemeForm.CreateNew(nil);
    LBin.ReadComponent(Result);
  finally
    LBin.Free;
    LSrc.Free;
  end;
end;

procedure Temel;
var
  LFrm: TDenemeForm;
  LA, LB: TRadComboBox;
  LRS: TcxRadSetting;
begin
  Writeln('=== Varsayilanlar ve atama ===');
  LFrm := TDenemeForm.CreateNew(nil);
  try
    LA := TRadComboBox.Create(LFrm); LA.Name := 'cbA'; LA.Parent := LFrm;
    LB := TRadComboBox.Create(LFrm); LB.Name := 'cbB'; LB.Parent := LFrm;
    LRS := LA.Properties.RadSetting;
    Kontrol('R01 RadSetting yaratildi, varsayilanlar bos',
      (LRS <> nil) and (LRS.Key = '') and (LRS.Tag = 0) and (LRS.Master = nil) and
      (LRS.Control1 = nil) and (LRS.Control4 = nil) and (LRS.DataBinding <> nil) and
      not LRS.DataBinding.IsAvailable and VarIsNull(LRS.DataBinding.Value));

    LRS.Key := 'liste1';
    LRS.Tag := 7;
    LRS.Control1 := LB;
    Kontrol('R02 Key/Tag/Control1 okunur',
      (LRS.Key = 'liste1') and (LRS.Tag = 7) and (LRS.Control1 = LB));
    Kontrol('R03 eski adlar RadSetting''e yonlenir (okuma)',
      (LA.Properties.ACascadeField = 'liste1') and (LA.Properties.ACascadeTag = 7) and
      (LA.Properties.AComponent1 = LB));
    LA.Properties.ACascadeField := 'yeni';
    LA.Properties.AComponent2 := LA;
    Kontrol('R03b eski adlar RadSetting''e yonlenir (yazma)',
      (LRS.Key = 'yeni') and (LRS.Control2 = LA));
  finally
    LFrm.Free;
  end;
end;

procedure Omur;
var
  LFrm: TDenemeForm;
  LA: TRadComboBox;
  LB: TRadComboBox;
  LMas: TRadComboBox;
  LRS: TcxRadSetting;
begin
  Writeln;
  Writeln('=== Yok olan bilesen isaretcisi nil''lenir ===');
  LFrm := TDenemeForm.CreateNew(nil);
  try
    LA := TRadComboBox.Create(LFrm); LA.Name := 'cbA'; LA.Parent := LFrm;
    LB := TRadComboBox.Create(nil);
    LMas := TRadComboBox.Create(nil);
    LRS := LA.Properties.RadSetting;
    LRS.Control3 := LB;
    LRS.Master := LMas;
    Kontrol('R04 Control atandi', LRS.Control3 = LB);
    Kontrol('R05 Master atandi', LRS.Master = LMas);
    LB.Free;
    LMas.Free;
    Kontrol('R04b yok olan Control nil''lendi', LRS.Control3 = nil);
    Kontrol('R05b yok olan Master nil''lendi', LRS.Master = nil);
  finally
    LFrm.Free;
  end;
end;

procedure MasterDenetimi;
var
  LFrm: TDenemeForm;
  LA, LB: TRadComboBox;
  LBtn: TButton;
  LRS: TcxRadSetting;
begin
  Writeln;
  Writeln('=== Master tip ve dairesel denetimi ===');
  LFrm := TDenemeForm.CreateNew(nil);
  try
    LA := TRadComboBox.Create(LFrm); LA.Name := 'cbA'; LA.Parent := LFrm;
    LB := TRadComboBox.Create(LFrm); LB.Name := 'cbB'; LB.Parent := LFrm;
    LBtn := TButton.Create(LFrm); LBtn.Parent := LFrm;
    LRS := LA.Properties.RadSetting;
    Kontrol('R06 editor olmayan Master ERadDev ile reddedilir',
      HataSinifi(procedure begin LRS.Master := LBtn; end) = 'ERadDev');
    Kontrol('R07 editor Master kabul edilir',
      HataSinifi(procedure begin LRS.Master := LB; end) = '');
    Kontrol('R07b kabul edilen Master okunur', LRS.Master = LB);
    Kontrol('R08 kendini Master gostermek (dairesel) reddedilir',
      HataSinifi(procedure begin LRS.Master := LA; end) = 'ERadDev');
    Kontrol('R08b reddedilen atama eski degeri bozmadi', LRS.Master = LB);
    LRS.Master := nil;
    Kontrol('R08c Master nil''e cekilebilir', LRS.Master = nil);
  finally
    LFrm.Free;
  end;
end;

procedure PaylasilanItem;
var
  LFrm: TDenemeForm;
  LRepo: TcxEditRepository;
  LItem: TRadComboBoxRepository;
  LA, LB, LC, LD: TRadComboBox;
  LIzle: TIzle;
begin
  Writeln;
  Writeln('=== Paylasilan item + tuketiciye ozel zincir ===');
  LIzle := TIzle.Create;
  LFrm := TDenemeForm.CreateNew(nil);
  try
    LRepo := TcxEditRepository.Create(LFrm);
    LItem := TRadComboBoxRepository(LRepo.CreateItem(TRadComboBoxRepository));
    LItem.Properties.AOnCascade := LIzle.Kaskad;
    LA := TRadComboBox.Create(LFrm); LA.Parent := LFrm; LA.RepositoryItem := LItem;
    LB := TRadComboBox.Create(LFrm); LB.Parent := LFrm;
    LC := TRadComboBox.Create(LFrm); LC.Parent := LFrm; LC.RepositoryItem := LItem;
    LD := TRadComboBox.Create(LFrm); LD.Parent := LFrm;
    LA.Properties.RadSetting.Control1 := LB;
    LC.Properties.RadSetting.Control1 := LD;

    LA.EditValue := 'x';
    Kontrol('R18 repository''li editor: KENDI zincirinin hedefine haber gider',
      (LIzle.Cagri = 1) and (LIzle.SonHedef = LB) and (LIzle.SonKaynak = LA),
      Format('cagri=%d hedef=%s', [LIzle.Cagri, BoolToStr(LIzle.SonHedef = LB, True)]));
    LIzle.Cagri := 0;
    LC.EditValue := 'y';
    Kontrol('R19 ikinci tuketici: digerinin hedefine DEGIL, kendi hedefine',
      (LIzle.Cagri = 1) and (LIzle.SonHedef = LD) and (LIzle.SonKaynak = LC),
      Format('cagri=%d', [LIzle.Cagri]));
  finally
    LFrm.Free;
    LIzle.Free;
  end;
end;

procedure DuzenlemeSecenegi;
var
  LFrm, LFrm2: TDenemeForm;
  LA, LB: TRadComboBox;
  LL: TRadLookupComboBox;
  LMetin: string;
begin
  Writeln;
  Writeln('=== AEditOnPopup ===');
  LFrm := TDenemeForm.CreateNew(nil);
  try
    LFrm.Name := 'Frm';
    LA := TRadComboBox.Create(LFrm); LA.Name := 'cbA'; LA.Parent := LFrm;
    LB := TRadComboBox.Create(LFrm); LB.Name := 'cbB'; LB.Parent := LFrm;
    LL := TRadLookupComboBox.Create(LFrm); LL.Name := 'lkA'; LL.Parent := LFrm;
    Kontrol('R20 AEditOnPopup varsayilan False (combo ve lookup)',
      not LA.Properties.AEditOnPopup and not LL.Properties.AEditOnPopup);
    LMetin := DfmMetni(LFrm);
    Kontrol('R20b varsayilanken DFM''e yazilmaz', Pos('AEditOnPopup', LMetin) = 0);
    LA.Properties.AEditOnPopup := True;
    LL.Properties.AEditOnPopup := True;
    LB.Properties.Assign(LA.Properties);
    Kontrol('R21 Properties.Assign AEditOnPopup''i kopyalar', LB.Properties.AEditOnPopup);
    LMetin := DfmMetni(LFrm);
    LFrm2 := DfmdenOku(LMetin);
    try
      Kontrol('R22 True iken DFM''e yazilir ve geri okunur',
        (Pos('AEditOnPopup = True', LMetin) > 0) and
        (LFrm2.FindComponent('cbA') as TRadComboBox).Properties.AEditOnPopup and
        (LFrm2.FindComponent('lkA') as TRadLookupComboBox).Properties.AEditOnPopup);
    finally
      LFrm2.Free;
    end;
  finally
    LFrm.Free;
  end;
end;

procedure Kopya;
var
  LFrm: TDenemeForm;
  LA, LB, LC: TRadComboBox;
  LLk1, LLk2: TRadLookupComboBox;
  LDS: TDataSource;
  LDat: TdxMemData;
  LObj: TObject;
begin
  Writeln;
  Writeln('=== Assign / DoAssign ===');
  LFrm := TDenemeForm.CreateNew(nil);
  LObj := TObject.Create;
  try
    LA := TRadComboBox.Create(LFrm); LA.Name := 'cbA'; LA.Parent := LFrm;
    LB := TRadComboBox.Create(LFrm); LB.Name := 'cbB'; LB.Parent := LFrm;
    LC := TRadComboBox.Create(LFrm); LC.Name := 'cbC'; LC.Parent := LFrm;
    LDat := YeniVeri(LFrm, LDS);

    with LA.Properties.RadSetting do
    begin
      Key := 'k';
      Tag := 3;
      Control1 := LB;
      Control4 := LC;
      Master := LC;
      DataBinding.DataSource := LDS;
      DataBinding.DataField := 'ad';
      Data := LObj;
    end;

    LB.Properties.RadSetting.Assign(LA.Properties.RadSetting);
    with LB.Properties.RadSetting do
      Kontrol('R09 RadSetting.Assign her alani kopyalar',
        (Key = 'k') and (Tag = 3) and (Control1 = LB) and (Control4 = LC) and
        (Master = LC) and (DataBinding.DataSource = LDS) and
        (DataBinding.DataField = 'ad'));
    Kontrol('R09b Data KOPYALANMAZ', LB.Properties.RadSetting.Data = nil);

    LC.Properties.Assign(LA.Properties);
    Kontrol('R10 Properties.Assign (DoAssign) RadSetting''i tasir',
      (LC.Properties.RadSetting.Key = 'k') and (LC.Properties.RadSetting.Tag = 3) and
      (LC.Properties.RadSetting.Control1 = LB));

    LLk1 := TRadLookupComboBox.Create(LFrm); LLk1.Name := 'lkA'; LLk1.Parent := LFrm;
    LLk2 := TRadLookupComboBox.Create(LFrm); LLk2.Name := 'lkB'; LLk2.Parent := LFrm;
    LLk1.Properties.RadSetting.Key := 'lk';
    LLk1.Properties.RadSetting.Control2 := LLk2;
    LLk2.Properties.Assign(LLk1.Properties);
    Kontrol('R10b Lookup ailesi de RadSetting''i tasir',
      (LLk2.Properties.RadSetting.Key = 'lk') and
      (LLk2.Properties.RadSetting.Control2 = LLk2));
    Kontrol('R10c Lookup eski adlari RadSetting''e yonlenir',
      (LLk1.Properties.ACascadeField = 'lk') and (LLk1.Properties.AComponent2 = LLk2));
    LLk1.Properties.AMaster := LA;
    Kontrol('R10d AMaster eski adi RadSetting.Master''a yonlenir',
      LLk1.Properties.RadSetting.Master = LA);
  finally
    LObj.Free;
    LFrm.Free;
  end;
end;

procedure VeriBaglama;
var
  LFrm: TDenemeForm;
  LA: TRadComboBox;
  LDS: TDataSource;
  LDat: TdxMemData;
  LBind: TcxRadDataBinding;
  LDS2: TDataSource;
begin
  Writeln;
  Writeln('=== DataBinding ===');
  LFrm := TDenemeForm.CreateNew(nil);
  try
    LA := TRadComboBox.Create(LFrm); LA.Name := 'cbA'; LA.Parent := LFrm;
    LDat := YeniVeri(LFrm, LDS);
    LBind := LA.Properties.RadSetting.DataBinding;

    LBind.DataSource := LDS;
    Kontrol('R11a alan adi yokken kullanilamaz', not LBind.IsAvailable);
    LBind.DataField := 'ad';
    Kontrol('R11 DataSource + DataField: deger okunur',
      LBind.IsAvailable and (VarToStr(LBind.Value) = 'Bir'));
    LDat.Next;
    Kontrol('R12 kayit degisince deger de degisir', VarToStr(LBind.Value) = 'Iki');
    Kontrol('R12b Field cozulur', (LBind.Field <> nil) and (LBind.Field.FieldName = 'ad'));
    LBind.DataField := 'yok_boyle_alan';
    Kontrol('R12c olmayan alan sessizce kullanilamaz (Null)',
      not LBind.IsAvailable and VarIsNull(LBind.Value));
    LBind.DataField := 'ad';
    LDat.Close;
    Kontrol('R13 dataset kapaliyken kullanilamaz', not LBind.IsAvailable);
    LDat.Open;

    LDS2 := TDataSource.Create(nil);
    LDS2.DataSet := LDat;
    LBind.DataSource := LDS2;
    Kontrol('R14a ikinci DataSource baglandi', LBind.IsAvailable);
    LDS2.Free;
    Kontrol('R14 DataSource yok edilince baglanti kopar, AV yok',
      (LBind.DataSource = nil) and not LBind.IsAvailable);
  finally
    LFrm.Free;
  end;
end;

procedure DfmTesti;
var
  LFrm, LFrm2, LFrm3: TDenemeForm;
  LA, LB: TRadComboBox;
  LDS: TDataSource;
  LDat: TdxMemData;
  LMetin: string;
  LYeniA, LYeniB: TRadComboBox;
const
  CEskiDfm =
    'object Frm: TDenemeForm'#13#10 +
    '  object cbA: TRadComboBox'#13#10 +
    '    Properties.ACascadeField = ''eski'''#13#10 +
    '    Properties.ACascadeTag = 5'#13#10 +
    '    Properties.AComponent1 = cbB'#13#10 +
    '  end'#13#10 +
    '  object cbB: TRadComboBox'#13#10 +
    '  end'#13#10 +
    'end'#13#10;
begin
  Writeln;
  Writeln('=== DFM ===');
  LFrm := TDenemeForm.CreateNew(nil);
  try
    LFrm.Name := 'Frm';
    LA := TRadComboBox.Create(LFrm); LA.Name := 'cbA'; LA.Parent := LFrm;
    LB := TRadComboBox.Create(LFrm); LB.Name := 'cbB'; LB.Parent := LFrm;
    LDat := YeniVeri(LFrm, LDS);
    LDat.Name := 'Dat';
    LDS.Name := 'Kaynak';
    with LA.Properties.RadSetting do
    begin
      Key := 'dfm_key';
      Tag := 9;
      Control1 := LB;
      Master := LB;
      DataBinding.DataSource := LDS;
      DataBinding.DataField := 'ad';
    end;
    LMetin := DfmMetni(LFrm);
    Kontrol('R15 RadSetting DFM''e yazilir',
      (Pos('RadSetting.Key = ''dfm_key''', LMetin) > 0) and
      (Pos('RadSetting.Tag = 9', LMetin) > 0) and
      (Pos('RadSetting.Control1 = cbB', LMetin) > 0) and
      (Pos('RadSetting.DataBinding.DataField = ''ad''', LMetin) > 0) and
      (Pos('RadSetting.DataBinding.DataSource = Kaynak', LMetin) > 0));
    Kontrol('R15b eski adlar DFM''e YAZILMAZ',
      (Pos('ACascadeField', LMetin) = 0) and (Pos('AComponent1', LMetin) = 0) and
      (Pos('ACascadeTag', LMetin) = 0));

    LFrm2 := DfmdenOku(LMetin);
    try
      LYeniA := LFrm2.FindComponent('cbA') as TRadComboBox;
      LYeniB := LFrm2.FindComponent('cbB') as TRadComboBox;
      Kontrol('R16 DFM geri okunur',
        (LYeniA <> nil) and (LYeniA.Properties.RadSetting.Key = 'dfm_key') and
        (LYeniA.Properties.RadSetting.Tag = 9) and
        (LYeniA.Properties.RadSetting.Control1 = LYeniB) and
        (LYeniA.Properties.RadSetting.Master = LYeniB) and
        (LYeniA.Properties.RadSetting.DataBinding.DataField = 'ad') and
        (LYeniA.Properties.RadSetting.DataBinding.DataSource =
           (LFrm2.FindComponent('Kaynak') as TDataSource)));
    finally
      LFrm2.Free;
    end;
  finally
    LFrm.Free;
  end;

  LFrm3 := DfmdenOku(CEskiDfm);
  try
    LYeniA := LFrm3.FindComponent('cbA') as TRadComboBox;
    LYeniB := LFrm3.FindComponent('cbB') as TRadComboBox;
    Kontrol('R17 ESKI adli DFM okunur ve RadSetting''e tasinir',
      (LYeniA <> nil) and (LYeniA.Properties.RadSetting.Key = 'eski') and
      (LYeniA.Properties.RadSetting.Tag = 5) and
      (LYeniA.Properties.RadSetting.Control1 = LYeniB));
    LMetin := DfmMetni(LFrm3);
    Kontrol('R17b eski DFM tekrar yazilinca yeni konuma yazilir',
      (Pos('RadSetting.Key = ''eski''', LMetin) > 0) and (Pos('ACascadeField', LMetin) = 0));
  finally
    LFrm3.Free;
  end;
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    Application.Initialize;
    RegisterClasses([TDenemeForm, TRadComboBox, TRadLookupComboBox, TdxMemData,
      TDataSource, TStringField]);
    Temel;
    Omur;
    MasterDenetimi;
    Kopya;
    PaylasilanItem;
    DuzenlemeSecenegi;
    VeriBaglama;
    DfmTesti;
    Sonuc;
  except
    on E: Exception do
    begin
      Writeln('HATA: ', E.ClassName, ': ', E.Message);
      Halt(2);
    end;
  end;
end.
