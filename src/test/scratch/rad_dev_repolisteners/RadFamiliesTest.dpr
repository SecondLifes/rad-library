program RadFamiliesTest;

(*
  Yeni Rad ailelerinin (ButtonEdit, ImageComboBox, ExtLookupComboBox, PopupEdit)
  ortak sozlesmesi; her biri icin Properties/Repository/Edit/DBEdit:
    - dogru Properties sinifi, RadSetting var
    - Properties.Assign RadSetting'i tasir
    - GetContainerClass = Rad editoru (gridin inplace editoru Rad sinifi olur)
    - DFM'e yazilir ve geri okunur, varsayilanken yazilmaz
    - paylasilan RepositoryItem'da her tuketici KENDI Key'ini korur
    - gridde sutunun kendi Key'i inplace editorun InternalProperties'ine gelir
*)

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Variants, System.TypInfo, Vcl.Forms,
  Vcl.Controls, Data.DB,
  cxEdit, cxDBEdit, cxDropDownEdit, cxButtonEdit, cxImageComboBox, cxDBExtLookupComboBox,
  cxCheckComboBox, cxDBCheckComboBox,
  cxGraphics, cxControls, cxLookAndFeels, cxContainer, cxClasses, cxStyles,
  cxCustomData, cxDBData, cxGridCustomTableView, cxGridTableView, cxGridDBTableView,
  cxGridLevel, cxGrid, dxmdaset, Rad.Dev;

type
  TDenemeForm = class(TForm)
  end;

  TAile = record
    Ad: string;
    EditClass, DBClass: TcxCustomEditClass;
    PropsClass: TcxCustomEditPropertiesClass;
    RepoClass: TcxEditRepositoryItemClass;
  end;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;
  GAile: array[0..4] of TAile;

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

procedure Bekle(AMs: Cardinal);
var
  LBitis: UInt64;
begin
  LBitis := GetTickCount64 + AMs;
  while GetTickCount64 < LBitis do
  begin
    Application.ProcessMessages;
    Sleep(5);
  end;
end;

function RS(AProps: TcxCustomEditProperties): TcxRadSetting;
begin
  Result := TcxRadSetting(GetObjectProp(AProps, 'RadSetting', TcxRadSetting));
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

procedure Aile(const AAd: string; AEdit, ADB: TcxCustomEditClass;
  AProps: TcxCustomEditPropertiesClass; ARepo: TcxEditRepositoryItemClass; AIndex: Integer);
begin
  GAile[AIndex].Ad := AAd;
  GAile[AIndex].EditClass := AEdit;
  GAile[AIndex].DBClass := ADB;
  GAile[AIndex].PropsClass := AProps;
  GAile[AIndex].RepoClass := ARepo;
end;

procedure TemelSozlesme(const A: TAile);
var
  LFrm: TDenemeForm;
  LE, LD, LHedef: TcxCustomEdit;
  LRS: TcxRadSetting;
begin
  Writeln;
  Writeln('=== ', A.Ad, ': Properties / Assign / container ===');
  LFrm := TDenemeForm.CreateNew(nil);
  try
    LE := A.EditClass.Create(LFrm); LE.Parent := LFrm;
    LD := A.DBClass.Create(LFrm);   LD.Parent := LFrm;
    LHedef := A.EditClass.Create(LFrm); LHedef.Parent := LFrm;
    Kontrol(A.Ad + ' edit/DB edit Properties sinifi Rad',
      (LE.InternalProperties.ClassType = A.PropsClass) and
      (LD.InternalProperties.ClassType = A.PropsClass));
    Kontrol(A.Ad + ' RadSetting yaratildi', (RS(LE.InternalProperties) <> nil) and
      (RS(LD.InternalProperties) <> nil));
    Kontrol(A.Ad + ' GetContainerClass = Rad editoru (grid inplace)',
      A.PropsClass.GetContainerClass = A.EditClass);

    LRS := RS(LE.InternalProperties);
    LRS.Key := 'k1';
    LRS.Tag := 4;
    LRS.Control2 := LHedef;
    LRS.Master := LHedef;
    LD.InternalProperties.Assign(LE.InternalProperties);
    Kontrol(A.Ad + ' Properties.Assign RadSetting''i tasir',
      (RS(LD.InternalProperties).Key = 'k1') and (RS(LD.InternalProperties).Tag = 4) and
      (RS(LD.InternalProperties).Control2 = LHedef) and
      (RS(LD.InternalProperties).Master = LHedef));
    LHedef.Free;
    Kontrol(A.Ad + ' yok olan hedef/master nil''lendi',
      (LRS.Control2 = nil) and (LRS.Master = nil));
  finally
    LFrm.Free;
  end;
end;

procedure DfmSozlesmesi(const A: TAile);
var
  LFrm, LFrm2: TDenemeForm;
  LE, LH: TcxCustomEdit;
  LMetin: string;
  LYeni: TcxCustomEdit;
begin
  Writeln;
  Writeln('=== ', A.Ad, ': DFM ===');
  LFrm := TDenemeForm.CreateNew(nil);
  try
    LFrm.Name := 'Frm';
    LE := A.EditClass.Create(LFrm); LE.Name := 'edA'; LE.Parent := LFrm;
    LH := A.EditClass.Create(LFrm); LH.Name := 'edB'; LH.Parent := LFrm;
    LMetin := DfmMetni(LFrm);
    Kontrol(A.Ad + ' varsayilanken RadSetting DFM''e yazilmaz',
      Pos('RadSetting', LMetin) = 0);
    RS(LE.InternalProperties).Key := 'dfm';
    RS(LE.InternalProperties).Tag := 6;
    RS(LE.InternalProperties).Control1 := LH;
    LMetin := DfmMetni(LFrm);
    LFrm2 := DfmdenOku(LMetin);
    try
      LYeni := LFrm2.FindComponent('edA') as TcxCustomEdit;
      Kontrol(A.Ad + ' DFM yazilir ve geri okunur',
        (Pos('RadSetting.Key = ''dfm''', LMetin) > 0) and (LYeni <> nil) and
        (RS(LYeni.InternalProperties).Key = 'dfm') and
        (RS(LYeni.InternalProperties).Tag = 6) and
        (RS(LYeni.InternalProperties).Control1 = LFrm2.FindComponent('edB')));
    finally
      LFrm2.Free;
    end;
  finally
    LFrm.Free;
  end;
end;

procedure PaylasilanItem(const A: TAile);
var
  LFrm: TDenemeForm;
  LRepo: TcxEditRepository;
  LItem: TcxEditRepositoryItem;
  L1, L2: TcxCustomEdit;
begin
  Writeln;
  Writeln('=== ', A.Ad, ': paylasilan RepositoryItem ===');
  LFrm := TDenemeForm.CreateNew(nil);
  try
    LRepo := TcxEditRepository.Create(LFrm);
    LItem := LRepo.CreateItem(A.RepoClass);
    Kontrol(A.Ad + ' repository item Properties sinifi Rad',
      LItem.Properties.ClassType = A.PropsClass);
    L1 := A.EditClass.Create(LFrm); L1.Parent := LFrm; L1.RepositoryItem := LItem;
    L2 := A.EditClass.Create(LFrm); L2.Parent := LFrm; L2.RepositoryItem := LItem;
    RS(L1.InternalProperties).Key := 'bir';
    RS(L2.InternalProperties).Key := 'iki';
    Kontrol(A.Ad + ' tuketiciler KENDI Key''ini korur, item''inki bos',
      (RS(L1.InternalProperties).Key = 'bir') and (RS(L2.InternalProperties).Key = 'iki') and
      (RS(LItem.Properties).Key = '') and
      (RS(L1.ActiveProperties).Key = ''));
  finally
    LFrm.Free;
  end;
end;

procedure GridInplace(const A: TAile);
var
  LFrm: TDenemeForm;
  LRepo: TcxEditRepository;
  LItem: TcxEditRepositoryItem;
  LMD: TdxMemData;
  LFld: TStringField;
  LDS: TDataSource;
  LGrid: TcxGrid;
  LView: TcxGridDBTableView;
  LCol: TcxGridDBColumn;
  LEd: TcxCustomEdit;
begin
  Writeln;
  Writeln('=== ', A.Ad, ': gridde inplace editor ===');
  LFrm := TDenemeForm.CreateNew(nil);
  try
    LFrm.SetBounds(50, 50, 500, 300);
    LFrm.Show;
    Bekle(100);
    LMD := TdxMemData.Create(LFrm);
    LFld := TStringField.Create(LFrm); LFld.FieldName := 'ad'; LFld.Size := 20; LFld.DataSet := LMD;
    LMD.Open; LMD.Append; LMD.FieldByName('ad').AsString := 'x'; LMD.Post;
    LDS := TDataSource.Create(LFrm); LDS.DataSet := LMD;
    LRepo := TcxEditRepository.Create(LFrm);
    LItem := LRepo.CreateItem(A.RepoClass);
    LGrid := TcxGrid.Create(LFrm); LGrid.Parent := LFrm; LGrid.SetBounds(0, 0, 480, 250);
    LView := LGrid.CreateView(TcxGridDBTableView) as TcxGridDBTableView;
    LGrid.Levels.Add.GridView := LView;
    LView.DataController.DataSource := LDS;
    LCol := LView.CreateColumn;
    LCol.DataBinding.FieldName := 'ad';
    LCol.PropertiesClass := A.PropsClass;
    RS(LCol.Properties).Key := 'kolon_key';
    LCol.RepositoryItem := LItem;
    LGrid.SetFocus;
    Bekle(100);
    LView.DataController.FocusedRecordIndex := 0;
    LView.Controller.FocusedColumn := LCol;
    LView.Controller.EditingController.ShowEdit(LCol);
    Bekle(60);
    LEd := LView.Controller.EditingController.Edit;
    Kontrol(A.Ad + ' inplace editor Rad sinifi', (LEd <> nil) and (LEd.ClassType = A.EditClass),
      BoolToStr(LEd <> nil, True));
    Kontrol(A.Ad + ' sutunun KENDI Key''i inplace InternalProperties''e geldi',
      (LEd <> nil) and (RS(LEd.InternalProperties).Key = 'kolon_key'));
    LView.Controller.EditingController.HideEdit(False);
  finally
    LFrm.Free;
  end;
end;

var
  i: Integer;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    Application.Initialize;
    Aile('ButtonEdit', TRadButtonEdit, TRadDBButtonEdit, TRadButtonEditProperties,
      TRadButtonEditRepository, 0);
    Aile('ImageComboBox', TRadImageComboBox, TRadDBImageComboBox,
      TRadImageComboBoxProperties, TRadImageComboBoxRepository, 1);
    Aile('ExtLookupComboBox', TRadExtLookupComboBox, TRadDBExtLookupComboBox,
      TRadExtLookupComboBoxProperties, TRadExtLookupComboBoxRepository, 2);
    Aile('PopupEdit', TRadPopupEdit, TRadDBPopupEdit, TRadPopupEditProperties,
      TRadPopupEditRepository, 3);
    Aile('CheckComboBox', TRadCheckComboBox, TRadDBCheckComboBox,
      TRadCheckComboBoxProperties, TRadCheckComboBoxRepository, 4);
    RegisterClasses([TDenemeForm, TRadButtonEdit, TRadImageComboBox,
      TRadExtLookupComboBox, TRadPopupEdit, TRadCheckComboBox]);
    for i := 0 to High(GAile) do
    begin
      TemelSozlesme(GAile[i]);
      DfmSozlesmesi(GAile[i]);
      PaylasilanItem(GAile[i]);
      GridInplace(GAile[i]);
    end;
  except
    on E: Exception do
    begin
      Inc(GHata);
      Writeln('HATA: ', E.ClassName, ': ', E.Message);
    end;
  end;
  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    Halt(1);
end.
