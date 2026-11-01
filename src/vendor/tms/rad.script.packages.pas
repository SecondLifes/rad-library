unit rad.script.packages;

(* Script paket yöneticisi (DFM, DevExpress): paket listesi + script/parametre/DB adımı/kaynak sekmeleri,
   içe/dışa aktarma, IDE'de aç, tasarla. Veriye bağlı parça kodla doldurulur (grid satırları).
   Bkz. docs/specs/rad.script.ide.md *)

interface

uses
  System.SysUtils, System.Classes, System.Variants, System.Generics.Collections,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Dialogs,
  cxGraphics, cxControls, cxLookAndFeels, cxLookAndFeelPainters, cxStyles, cxCustomData, cxFilter, cxData,
  cxDataStorage, cxEdit, cxNavigator, dxDateRanges, dxScrollbarAnnotations, cxClasses, cxGridCustomView,
  cxGridCustomTableView, cxGridTableView, cxGridLevel, cxGrid, cxCheckBox, cxTextEdit, cxPC, cxContainer,
  rad.script, rad.script.hooks, rad.script.facade, rad.script.ide, rad.script.design, rad.script.newscript;

type
  TRadScriptOpenFormEvent = reference to procedure(const AFormClassName, APackageCode: string);

  TRadScriptPackagesForm = class(TForm)
    pnlUst: TPanel;
    btnYeni: TButton;
    btnSil: TButton;
    btnIceAktar: TButton;
    btnDisaAktar: TButton;
    btnIde: TButton;
    btnTasarla: TButton;
    btnYenile: TButton;
    grdPaket: TcxGrid;
    vwPaket: TcxGridTableView;
    colKod: TcxGridColumn;
    colAd: TcxGridColumn;
    colSurum: TcxGridColumn;
    colYazar: TcxGridColumn;
    colSira: TcxGridColumn;
    colAktif: TcxGridColumn;
    colKorumali: TcxGridColumn;
    lvlPaket: TcxGridLevel;
    spl: TSplitter;
    pcDetay: TcxPageControl;
    tsScript: TcxTabSheet;
    tsParam: TcxTabSheet;
    tsDb: TcxTabSheet;
    tsKaynak: TcxTabSheet;
    pnlScript: TPanel;
    btnScriptYeni: TButton;
    btnScriptSil: TButton;
    grdScript: TcxGrid;
    vwScript: TcxGridTableView;
    colSKod: TcxGridColumn;
    colSAd: TcxGridColumn;
    colSTur: TcxGridColumn;
    colSHedef: TcxGridColumn;
    colSSira: TcxGridColumn;
    colSAktif: TcxGridColumn;
    lvlScript: TcxGridLevel;
    grdParam: TcxGrid;
    vwParam: TcxGridTableView;
    colPAd: TcxGridColumn;
    colPDeger: TcxGridColumn;
    colPAciklama: TcxGridColumn;
    lvlParam: TcxGridLevel;
    pnlDb: TPanel;
    btnDbUygula: TButton;
    grdDb: TcxGrid;
    vwDb: TcxGridTableView;
    colDSira: TcxGridColumn;
    colDAciklama: TcxGridColumn;
    colDUygulandi: TcxGridColumn;
    colDZaman: TcxGridColumn;
    lvlDb: TcxGridLevel;
    pnlKaynak: TPanel;
    btnKaynakDisa: TButton;
    btnKaynakIce: TButton;
    btnKaynakSil: TButton;
    grdKaynak: TcxGrid;
    vwKaynak: TcxGridTableView;
    colKDosya: TcxGridColumn;
    colKBoyut: TcxGridColumn;
    lvlKaynak: TcxGridLevel;
    dlgAc: TOpenDialog;
    dlgKaydet: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnYenileClick(Sender: TObject);
    procedure btnYeniClick(Sender: TObject);
    procedure btnSilClick(Sender: TObject);
    procedure btnIceAktarClick(Sender: TObject);
    procedure btnDisaAktarClick(Sender: TObject);
    procedure btnIdeClick(Sender: TObject);
    procedure btnTasarlaClick(Sender: TObject);
    procedure btnScriptYeniClick(Sender: TObject);
    procedure btnScriptSilClick(Sender: TObject);
    procedure btnDbUygulaClick(Sender: TObject);
    procedure btnKaynakDisaClick(Sender: TObject);
    procedure btnKaynakIceClick(Sender: TObject);
    procedure btnKaynakSilClick(Sender: TObject);
    procedure vwPaketFocusedRecordChanged(Sender: TcxCustomGridTableView; APrevFocusedRecord,
      AFocusedRecord: TcxCustomGridRecord; ANewItemRecordFocusingChanged: Boolean);
    procedure vwDetayFocusedRecordChanged(Sender: TcxCustomGridTableView; APrevFocusedRecord,
      AFocusedRecord: TcxCustomGridRecord; ANewItemRecordFocusingChanged: Boolean);
    procedure vwPaketEditValueChanged(Sender: TcxCustomGridTableView; AItem: TcxCustomGridTableItem);
    procedure vwScriptEditValueChanged(Sender: TcxCustomGridTableView; AItem: TcxCustomGridTableItem);
    procedure vwParamEditValueChanged(Sender: TcxCustomGridTableView; AItem: TcxCustomGridTableItem);
  private
    FStore: IRadScriptStore;
    FContext: TRadScriptContext;
    FPackages: TRadScriptPackages;
    FFilling: Boolean;
    FOnOpenFormForDesign: TRadScriptOpenFormEvent;
    FOnPackagesChanged: TProc;
    function Store: IRadScriptStore;
    function Current: TRadScriptPackage;
    function CurrentScript: TRadScript;
    function CurrentResource: TRadScriptResource;
    procedure FillPackages(const ASelectCode: string);
    procedure FillDetail;
    procedure UpdateButtons;
    procedure SaveCurrent;
    procedure Changed;
    procedure IdeSaved(APkg: TRadScriptPackage);
  public
    /// Yüklemek için Store şart (nil → TRadScriptBinder.Store); Context IDE'nin facade'ı için.
    class function Open(AOwner: TComponent; const AStore: IRadScriptStore; AContext: TRadScriptContext): TRadScriptPackagesForm; static;
    procedure Reload;
    property Context: TRadScriptContext read FContext write FContext;
    /// form script'i için "Tasarla": host formu açar ve TRadScriptDesigner.Start çağırır.
    property OnOpenFormForDesign: TRadScriptOpenFormEvent read FOnOpenFormForDesign write FOnOpenFormForDesign;
    /// Her SavePackage/DeletePackage sonrası (KP'ye "paketler değişti" yayını için host).
    property OnPackagesChanged: TProc read FOnPackagesChanged write FOnPackagesChanged;
  end;

implementation

uses
  System.UITypes, System.IOUtils, System.DateUtils;

{$R *.dfm}

resourcestring
  SNewCode = 'Paket kodu (küçük harf, rakam, nokta, tire):';
  SNewName = 'Paket adı:';
  SConfirmDelete = '"%s" paketi silinsin mi? Script, parametre, DB adımı ve kaynaklar gider; script_db ile yaratılan tablolar kalır.';
  SConfirmDeleteScript = '"%s" script''i silinsin mi?';
  SConfirmDeleteRes = '"%s" kaynağı silinsin mi?';
  SImported = 'İçe aktarıldı: %s';
  SPendingDb = '%s: uygulanmamış %d DB adımı var. Şimdi uygulansın mı?';
  SDbApplied = 'DB adımları uygulandı: %s';
  SDbError = 'DB adımı hatası: %s';
  SExported = 'Dışa aktarıldı: %s';
  SNoDesign = 'Tasarla: pencere script''i seçin ya da form script''i için host geri çağrısı tanımlı olmalı.';
  SProtected = 'Korumalı paket: kaynak açılmaz.';
  SResExists = '"%s" kaynağı zaten var; üstüne yazılsın mı?';

const
  KIND_IDX = 0;

{ TRadScriptPackagesForm }

class function TRadScriptPackagesForm.Open(AOwner: TComponent; const AStore: IRadScriptStore;
  AContext: TRadScriptContext): TRadScriptPackagesForm;
begin
  Result := TRadScriptPackagesForm.Create(AOwner);
  Result.FStore := AStore;
  Result.FContext := AContext;
  Result.Reload;
  Result.Show;
end;

procedure TRadScriptPackagesForm.FormCreate(Sender: TObject);
begin
  FPackages := TRadScriptPackages.Create(True);
  pcDetay.ActivePage := tsScript;
end;

procedure TRadScriptPackagesForm.FormDestroy(Sender: TObject);
begin
  if (TRadScriptIde.Active <> nil) and (FPackages.Contains(TRadScriptIde.Active.Package)) then TRadScriptIde.Active.Close;
  FPackages.Free;
end;

function TRadScriptPackagesForm.Store: IRadScriptStore;
begin
  Result := FStore;
  if Result = nil then Result := TRadScriptBinder.Store;
  if Result = nil then raise ERadScript.Create('Script store atanmadı.');
end;

function TRadScriptPackagesForm.Current: TRadScriptPackage;
var
  LRec: TcxCustomGridRecord;
begin
  Result := nil;
  LRec := vwPaket.Controller.FocusedRecord;
  if (LRec <> nil) and (LRec.RecordIndex >= 0) and (LRec.RecordIndex < FPackages.Count) then
    Result := FPackages[LRec.RecordIndex];
end;

function TRadScriptPackagesForm.CurrentScript: TRadScript;
var
  LRec: TcxCustomGridRecord;
  P: TRadScriptPackage;
begin
  Result := nil;
  P := Current;
  LRec := vwScript.Controller.FocusedRecord;
  if (P <> nil) and (LRec <> nil) and (LRec.RecordIndex >= 0) and (LRec.RecordIndex < P.Scripts.Count) then
    Result := P.Scripts[LRec.RecordIndex];
end;

function TRadScriptPackagesForm.CurrentResource: TRadScriptResource;
var
  LRec: TcxCustomGridRecord;
  P: TRadScriptPackage;
begin
  Result := nil;
  P := Current;
  LRec := vwKaynak.Controller.FocusedRecord;
  if (P <> nil) and (LRec <> nil) and (LRec.RecordIndex >= 0) and (LRec.RecordIndex < P.Resources.Count) then
    Result := P.Resources[LRec.RecordIndex];
end;

procedure TRadScriptPackagesForm.Reload;
var
  LCode: string;
begin
  if Current <> nil then LCode := Current.Code else LCode := '';
  FillPackages(LCode);
end;

procedure TRadScriptPackagesForm.FillPackages(const ASelectCode: string);
var
  L: TRadScriptPackages;
  P: TRadScriptPackage;
  i, LSel: Integer;
begin
  L := Store.LoadPackages(True);
  FPackages.Free;
  FPackages := L;
  FFilling := True;
  vwPaket.BeginUpdate;
  try
    vwPaket.DataController.RecordCount := FPackages.Count;
    LSel := -1;
    for i := 0 to FPackages.Count - 1 do
    begin
      P := FPackages[i];
      vwPaket.DataController.Values[i, colKod.Index] := P.Code;
      vwPaket.DataController.Values[i, colAd.Index] := P.Name;
      vwPaket.DataController.Values[i, colSurum.Index] := P.Version;
      vwPaket.DataController.Values[i, colYazar.Index] := P.Author;
      vwPaket.DataController.Values[i, colSira.Index] := P.Order;
      vwPaket.DataController.Values[i, colAktif.Index] := P.Active;
      vwPaket.DataController.Values[i, colKorumali.Index] := P.IsProtected;
      if SameText(P.Code, ASelectCode) then LSel := i;
    end;
  finally
    vwPaket.EndUpdate;
    FFilling := False;
  end;
  if (LSel < 0) and (FPackages.Count > 0) then LSel := 0;
  if LSel >= 0 then vwPaket.Controller.FocusedRecordIndex := LSel;
  FillDetail;
end;

procedure TRadScriptPackagesForm.FillDetail;
var
  P: TRadScriptPackage;
  i: Integer;
begin
  P := Current;
  FFilling := True;
  vwScript.BeginUpdate;
  vwParam.BeginUpdate;
  vwDb.BeginUpdate;
  vwKaynak.BeginUpdate;
  try
    if P = nil then
    begin
      vwScript.DataController.RecordCount := 0;
      vwParam.DataController.RecordCount := 0;
      vwDb.DataController.RecordCount := 0;
      vwKaynak.DataController.RecordCount := 0;
    end
    else
    begin
      vwScript.DataController.RecordCount := P.Scripts.Count;
      for i := 0 to P.Scripts.Count - 1 do
      begin
        vwScript.DataController.Values[i, colSKod.Index] := P.Scripts[i].Code;
        vwScript.DataController.Values[i, colSAd.Index] := P.Scripts[i].Name;
        vwScript.DataController.Values[i, colSTur.Index] := P.Scripts[i].KindCode;
        vwScript.DataController.Values[i, colSHedef.Index] := P.Scripts[i].Target;
        vwScript.DataController.Values[i, colSSira.Index] := P.Scripts[i].Order;
        vwScript.DataController.Values[i, colSAktif.Index] := P.Scripts[i].Active;
      end;
      vwParam.DataController.RecordCount := P.Params.Count;
      for i := 0 to P.Params.Count - 1 do
      begin
        vwParam.DataController.Values[i, colPAd.Index] := P.Params[i].Name;
        vwParam.DataController.Values[i, colPDeger.Index] := P.Params[i].Value;
        vwParam.DataController.Values[i, colPAciklama.Index] := P.Params[i].Description;
      end;
      vwDb.DataController.RecordCount := P.DbSteps.Count;
      for i := 0 to P.DbSteps.Count - 1 do
      begin
        vwDb.DataController.Values[i, colDSira.Index] := P.DbSteps[i].Order;
        vwDb.DataController.Values[i, colDAciklama.Index] := P.DbSteps[i].Description;
        vwDb.DataController.Values[i, colDUygulandi.Index] := P.DbSteps[i].Applied;
        if P.DbSteps[i].Applied then vwDb.DataController.Values[i, colDZaman.Index] := P.DbSteps[i].AppliedAt
        else vwDb.DataController.Values[i, colDZaman.Index] := Null;
      end;
      vwKaynak.DataController.RecordCount := P.Resources.Count;
      for i := 0 to P.Resources.Count - 1 do
      begin
        vwKaynak.DataController.Values[i, colKDosya.Index] := P.Resources[i].FileName;
        vwKaynak.DataController.Values[i, colKBoyut.Index] := Length(P.Resources[i].Content);
      end;
    end;
  finally
    vwKaynak.EndUpdate;
    vwDb.EndUpdate;
    vwParam.EndUpdate;
    vwScript.EndUpdate;
    FFilling := False;
  end;
  UpdateButtons;
end;

procedure TRadScriptPackagesForm.UpdateButtons;
var
  P: TRadScriptPackage;
  S: TRadScript;
begin
  P := Current;
  S := CurrentScript;
  btnSil.Enabled := P <> nil;
  btnDisaAktar.Enabled := P <> nil;
  btnIde.Enabled := (P <> nil) and not P.IsProtected;
  btnTasarla.Enabled := (P <> nil) and not P.IsProtected and (S <> nil) and
    ((S.Kind = skWindow) or ((S.Kind = skForm) and Assigned(FOnOpenFormForDesign)));
  btnScriptYeni.Enabled := (P <> nil) and not P.IsProtected;
  btnScriptSil.Enabled := (S <> nil) and not P.IsProtected;
  btnDbUygula.Enabled := (P <> nil) and (P.DbSteps.Count > 0);
  btnKaynakDisa.Enabled := CurrentResource <> nil;
  btnKaynakIce.Enabled := (P <> nil) and not P.IsProtected;
  btnKaynakSil.Enabled := (CurrentResource <> nil) and not P.IsProtected;
  vwScript.OptionsData.Editing := (P <> nil) and not P.IsProtected;
end;

procedure TRadScriptPackagesForm.Changed;
begin
  if Assigned(FOnPackagesChanged) then FOnPackagesChanged;
end;

procedure TRadScriptPackagesForm.SaveCurrent;
begin
  if Current = nil then Exit;
  Store.SavePackage(Current);
  Changed;
end;

procedure TRadScriptPackagesForm.vwPaketFocusedRecordChanged(Sender: TcxCustomGridTableView;
  APrevFocusedRecord, AFocusedRecord: TcxCustomGridRecord; ANewItemRecordFocusingChanged: Boolean);
begin
  if not FFilling then FillDetail;
end;

procedure TRadScriptPackagesForm.vwDetayFocusedRecordChanged(Sender: TcxCustomGridTableView;
  APrevFocusedRecord, AFocusedRecord: TcxCustomGridRecord; ANewItemRecordFocusingChanged: Boolean);
begin
  if not FFilling then UpdateButtons;
end;

procedure TRadScriptPackagesForm.vwPaketEditValueChanged(Sender: TcxCustomGridTableView; AItem: TcxCustomGridTableItem);
var
  P: TRadScriptPackage;
  V: Variant;
begin
  P := Current;
  if FFilling or (P = nil) then Exit;
  vwPaket.DataController.Post;
  V := vwPaket.DataController.Values[vwPaket.Controller.FocusedRecordIndex, AItem.Index];
  if AItem = colAd then P.Name := VarToStr(V)
  else if AItem = colSurum then P.Version := VarToStr(V)
  else if AItem = colYazar then P.Author := VarToStr(V)
  else if AItem = colSira then P.Order := StrToIntDef(VarToStr(V), P.Order)
  else if AItem = colAktif then P.Active := V = True
  else Exit;
  SaveCurrent;
end;

procedure TRadScriptPackagesForm.vwScriptEditValueChanged(Sender: TcxCustomGridTableView; AItem: TcxCustomGridTableItem);
var
  S: TRadScript;
  V: Variant;
begin
  S := CurrentScript;
  if FFilling or (S = nil) then Exit;
  vwScript.DataController.Post;
  V := vwScript.DataController.Values[vwScript.Controller.FocusedRecordIndex, AItem.Index];
  if AItem = colSAd then S.Name := VarToStr(V)
  else if AItem = colSHedef then S.Target := VarToStr(V)
  else if AItem = colSSira then S.Order := StrToIntDef(VarToStr(V), S.Order)
  else if AItem = colSAktif then S.Active := V = True
  else Exit;
  SaveCurrent;
end;

procedure TRadScriptPackagesForm.vwParamEditValueChanged(Sender: TcxCustomGridTableView; AItem: TcxCustomGridTableItem);
var
  P: TRadScriptPackage;
  i: Integer;
begin
  P := Current;
  if FFilling or (P = nil) or (AItem <> colPDeger) then Exit;
  vwParam.DataController.Post;
  i := vwParam.Controller.FocusedRecordIndex;
  if (i < 0) or (i >= P.Params.Count) then Exit;
  P.Params[i].Value := VarToStr(vwParam.DataController.Values[i, colPDeger.Index]);
  SaveCurrent;
end;

procedure TRadScriptPackagesForm.btnYenileClick(Sender: TObject);
begin
  Reload;
end;

procedure TRadScriptPackagesForm.btnYeniClick(Sender: TObject);
var
  P: TRadScriptPackage;
  LCode, LName: string;
begin
  if not InputQuery(Caption, SNewCode, LCode) then Exit;
  if not TRadScriptPackage.IsValidCode(LCode) then
  begin
    MessageDlg(Format('Paket kodu geçersiz: "%s".', [LCode]), mtError, [mbOK], 0);
    Exit;
  end;
  LName := LCode;
  if not InputQuery(Caption, SNewName, LName) then Exit;
  P := TRadScriptPackage.Create;
  try
    P.Code := LCode;
    P.Name := LName;
    P.Version := '1.0';
    P.Active := True;
    P.Order := FPackages.Count + 1;
    if FContext <> nil then P.Author := FContext.UserName;
    Store.SavePackage(P);
  finally
    P.Free;
  end;
  Changed;
  FillPackages(LCode);
end;

procedure TRadScriptPackagesForm.btnSilClick(Sender: TObject);
var
  P: TRadScriptPackage;
begin
  P := Current;
  if P = nil then Exit;
  if MessageDlg(Format(SConfirmDelete, [P.Code]), mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;
  Store.DeletePackage(P.Code);
  Changed;
  FillPackages('');
end;

procedure TRadScriptPackagesForm.btnIceAktarClick(Sender: TObject);
var
  P: TRadScriptPackage;
  LPending: Integer;
  D: TRadScriptDbStep;
begin
  if not dlgAc.Execute then Exit;
  P := TRadScriptPackageFile.LoadFromFile(dlgAc.FileName);
  try
    Store.ImportPackage(P);
    LPending := 0;
    for D in P.DbSteps do if not D.Applied then Inc(LPending);
    Changed;
    FillPackages(P.Code);
    MessageDlg(Format(SImported, [P.Code]), mtInformation, [mbOK], 0);
    if (LPending > 0) and (MessageDlg(Format(SPendingDb, [P.Code, LPending]), mtConfirmation, [mbYes, mbNo], 0) = mrYes) then
      btnDbUygulaClick(nil);
  finally
    P.Free;
  end;
end;

procedure TRadScriptPackagesForm.btnDisaAktarClick(Sender: TObject);
var
  P: TRadScriptPackage;
begin
  P := Current;
  if P = nil then Exit;
  dlgKaydet.FileName := P.Code + TRadScriptPackageFile.FileExt;
  if not dlgKaydet.Execute then Exit;
  TRadScriptPackageFile.SaveToFile(P, dlgKaydet.FileName);
  MessageDlg(Format(SExported, [dlgKaydet.FileName]), mtInformation, [mbOK], 0);
end;

procedure TRadScriptPackagesForm.IdeSaved(APkg: TRadScriptPackage);
begin
  Changed;
  FillDetail;
end;

procedure TRadScriptPackagesForm.btnIdeClick(Sender: TObject);
var
  P: TRadScriptPackage;
  S: TRadScript;
  LCode: string;
begin
  P := Current;
  if P = nil then Exit;
  if P.IsProtected then
  begin
    MessageDlg(SProtected, mtInformation, [mbOK], 0);
    Exit;
  end;
  if TRadScriptIde.Active <> nil then TRadScriptIde.Active.Close;
  S := CurrentScript;
  if S <> nil then LCode := S.Code else LCode := '';
  TRadScriptIde.Open(P, LCode, FContext).OnSaved := IdeSaved;
end;

procedure TRadScriptPackagesForm.btnTasarlaClick(Sender: TObject);
var
  P: TRadScriptPackage;
  S: TRadScript;
begin
  P := Current;
  S := CurrentScript;
  if (P = nil) or (S = nil) or P.IsProtected then Exit;
  if S.Kind = skWindow then TRadScriptDesigner.StartWindow(P.Code, S.Code)
  else if (S.Kind = skForm) and Assigned(FOnOpenFormForDesign) then FOnOpenFormForDesign(S.Target, P.Code)
  else MessageDlg(SNoDesign, mtInformation, [mbOK], 0);
end;

procedure TRadScriptPackagesForm.btnScriptYeniClick(Sender: TObject);
var
  P: TRadScriptPackage;
  S: TRadScript;
begin
  P := Current;
  if (P = nil) or P.IsProtected then Exit;
  if not TRadScriptNewScriptForm.Execute(P, S) then Exit;
  SaveCurrent;
  FillDetail;
  vwScript.Controller.FocusedRecordIndex := P.Scripts.IndexOf(S);
end;

procedure TRadScriptPackagesForm.btnScriptSilClick(Sender: TObject);
var
  P: TRadScriptPackage;
  S: TRadScript;
  R: TRadScriptResource;
begin
  P := Current;
  S := CurrentScript;
  if (P = nil) or (S = nil) then Exit;
  if MessageDlg(Format(SConfirmDeleteScript, [S.Code]), mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;
  if S.Kind = skWindow then
  begin
    R := P.ResourceByName(S.DfmFileName);
    if R <> nil then P.Resources.Remove(R);
  end;
  P.Scripts.Remove(S);
  SaveCurrent;
  FillDetail;
end;

procedure TRadScriptPackagesForm.btnDbUygulaClick(Sender: TObject);
var
  P: TRadScriptPackage;
begin
  P := Current;
  if P = nil then Exit;
  try
    Store.ApplyPendingDbSteps(P);
    MessageDlg(Format(SDbApplied, [P.Code]), mtInformation, [mbOK], 0);
  except
    on E: Exception do MessageDlg(Format(SDbError, [E.Message]), mtError, [mbOK], 0);
  end;
  Reload;
end;

procedure TRadScriptPackagesForm.btnKaynakDisaClick(Sender: TObject);
var
  R: TRadScriptResource;
begin
  R := CurrentResource;
  if R = nil then Exit;
  dlgKaydet.FileName := R.FileName;
  if dlgKaydet.Execute then TFile.WriteAllBytes(dlgKaydet.FileName, R.Content);
end;

procedure TRadScriptPackagesForm.btnKaynakIceClick(Sender: TObject);
var
  P: TRadScriptPackage;
  R: TRadScriptResource;
  LName: string;
begin
  P := Current;
  if (P = nil) or not dlgAc.Execute then Exit;
  LName := ExtractFileName(dlgAc.FileName);
  R := P.ResourceByName(LName);
  if (R <> nil) and (MessageDlg(Format(SResExists, [LName]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then Exit;
  if R = nil then P.AddResource(LName, TFile.ReadAllBytes(dlgAc.FileName))
  else R.Content := TFile.ReadAllBytes(dlgAc.FileName);
  SaveCurrent;
  FillDetail;
end;

procedure TRadScriptPackagesForm.btnKaynakSilClick(Sender: TObject);
var
  P: TRadScriptPackage;
  R: TRadScriptResource;
begin
  P := Current;
  R := CurrentResource;
  if (P = nil) or (R = nil) then Exit;
  if MessageDlg(Format(SConfirmDeleteRes, [R.FileName]), mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;
  P.Resources.Remove(R);
  SaveCurrent;
  FillDetail;
end;

end.
