unit rad.reports.manage;

(* Rapor yönetim formu (DevExpress Ribbon). IRadReport.Manage ile açılır; doğrudan kullanılmaz.

  Üstte anahtarın tasarımları, altta seçili tasarımın sürümleri. Komutlar TAction'dır; ribbon düğmeleri ve sağ tık
  menüleri aynı eylemleri kullanır. Form, verilen iş nesnesinin veri kümelerini/parametrelerini korur: Önizle ve Tasarla
  seçili tasarım için iş nesnesinin kopyasıyla (IRadReportInternal.Clone) çalışır.

  Ribbon belgeli koda dayalı yöntemle kurulur (TdxBarManager + TdxRibbon, RibbonKur). Form TdxRibbonForm'dan türer:
  Ribbon yalnız bu formla doğru çalışır (DevExpress belgesi) ve kütüphane ERP'ye özgü base.form'a bağlanamaz. *)

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Actions, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Menus, Vcl.ActnList, cxGraphics, cxControls, cxLookAndFeels, cxLookAndFeelPainters, cxStyles,
  cxCustomData, cxFilter, cxData, cxDataStorage, cxEdit, cxNavigator, dxDateRanges, dxScrollbarAnnotations,
  cxClasses, cxGridLevel, cxGridCustomView, cxGridCustomTableView, cxGridTableView, cxGrid,
  Vcl.Graphics, dxCore, dxForms, dxBar, dxRibbonSkins, dxRibbon, dxRibbonForm,
  rad.reports;

type
  TRadReportManageForm = class(TdxRibbonForm)
    grdDesign: TcxGrid;
    viewDesign: TcxGridTableView;
    colName: TcxGridColumn;
    colDefault: TcxGridColumn;
    colVersion: TcxGridColumn;
    colTemplate: TcxGridColumn;
    colUpdatedBy: TcxGridColumn;
    colUpdatedAt: TcxGridColumn;
    lvlDesign: TcxGridLevel;
    splVersion: TSplitter;
    grdVersion: TcxGrid;
    viewVersion: TcxGridTableView;
    colVNo: TcxGridColumn;
    colVDate: TcxGridColumn;
    colVUser: TcxGridColumn;
    colVSize: TcxGridColumn;
    colVNote: TcxGridColumn;
    lvlVersion: TcxGridLevel;
    ActionList: TActionList;
    actRefresh: TAction;
    actPreview: TAction;
    actDesign: TAction;
    actNewDesign: TAction;
    actCopy: TAction;
    actSetDefault: TAction;
    actDelete: TAction;
    actRestore: TAction;
    actDeleteOld: TAction;
    actReset: TAction;
    actSyncToLocal: TAction;
    actPushFromLocal: TAction;
    actOpenFolder: TAction;
    PopupDesign: TPopupMenu;
    mnuPreview: TMenuItem;
    mnuDesign: TMenuItem;
    mnuNewDesign: TMenuItem;
    mnuCopy: TMenuItem;
    mnuSetDefault: TMenuItem;
    mnuDelete: TMenuItem;
    mnuSep1: TMenuItem;
    mnuSyncToLocal: TMenuItem;
    mnuPushFromLocal: TMenuItem;
    PopupVersion: TPopupMenu;
    mnuRestore: TMenuItem;
    mnuDeleteOld: TMenuItem;
    mnuReset: TMenuItem;
    procedure actRefreshExecute(Sender: TObject);
    procedure actPreviewExecute(Sender: TObject);
    procedure actDesignExecute(Sender: TObject);
    procedure actNewDesignExecute(Sender: TObject);
    procedure actCopyExecute(Sender: TObject);
    procedure actSetDefaultExecute(Sender: TObject);
    procedure actDeleteExecute(Sender: TObject);
    procedure actRestoreExecute(Sender: TObject);
    procedure actDeleteOldExecute(Sender: TObject);
    procedure actResetExecute(Sender: TObject);
    procedure actSyncToLocalExecute(Sender: TObject);
    procedure actPushFromLocalExecute(Sender: TObject);
    procedure actOpenFolderExecute(Sender: TObject);
    procedure ActionListUpdate(Action: TBasicAction; var Handled: Boolean);
    procedure viewDesignFocusedRecordChanged(Sender: TcxCustomGridTableView; APrevFocusedRecord,
      AFocusedRecord: TcxCustomGridRecord; ANewItemRecordFocusingChanged: Boolean);
    procedure viewDesignDblClick(Sender: TObject);
  strict private
    FBarManager: TdxBarManager;
    FRibbon: TdxRibbon;
    FImages: TcxImageList;
    FJob: IRadReport;
    FList: TArray<TRadReportInfo>;
    FVersions: TArray<TRadReportVersion>;
    function Selected(out AInfo: TRadReportInfo): Boolean;
    function SelectedVersion(out AVersion: TRadReportVersion): Boolean;
    function JobFor(const ADesign: string): IRadReport;
    procedure LoadVersions;
    procedure Guarded(const AWork: TProc);
    function Confirm(const AText: string): Boolean;
    procedure BuildRibbon;
    function GlyphIndex(AGlyph: Word): Integer;
    function AddButton(ABar: TdxBar; AAction: TAction; AGlyph: Word): TdxBarLargeButton;
  protected
    procedure DoShow; override;
  public
    constructor Create(AOwner: TComponent); override;
    /// <summary>Formu modal açar; AJob'un anahtarına süzülür, veri kümelerini Önizle/Tasarla için kullanır.</summary>
    class procedure Execute(const AJob: IRadReport); static;
    procedure Refresh;
    property Job: IRadReport read FJob write FJob;
  end;

implementation

{$R *.dfm}

uses
  System.StrUtils, System.UITypes, System.IOUtils, Winapi.ShellAPI, Vcl.Dialogs;

resourcestring
  STitle = 'Raporlar — %s';
  STabDesigns = 'Tasarımlar';
  STabVersions = 'Sürümler';
  STabLocal = 'Yerel dosya';
  SGrpRun = 'Çalıştır';
  SGrpEdit = 'Düzenle';
  SGrpVersions = 'Sürüm işlemleri';
  SGrpSync = 'Eşitle';
  SYes = 'Evet';
  SNo = 'Hayır';
  SDeleteConfirm = '"%s" tasarımı tüm sürümleriyle KALICI olarak silinecek. Devam edilsin mi?' + sLineBreak +
    'Son içerik yerel yedek klasörüne yazılır.';
  SDeleteOldConfirm = 'Güncel sürüm dışındaki TÜM eski sürümler silinecek. Devam edilsin mi?';
  SResetConfirm = 'Eski sürümler silinecek ve güncel içerik 1. sürüm olacak. Bu işlem geri alınamaz ' +
    '(yalnız yerel yedekten dönülebilir). Devam edilsin mi?';
  SRestoreConfirm = 'v%d içeriği yeni sürüm olarak yazılsın mı?';
  SNewDesignPrompt = 'Yeni tasarımın adı';
  SCopyPrompt = 'Kopyanın adı';
  SSynced = 'Yerel dosya yazıldı:' + sLineBreak + '%s';
  SPushed = 'Yerel değişiklik yeni sürüm olarak yüklendi.';
  SUnchanged = 'Yerel dosya son eşitlemeden beri değişmemiş.';

constructor TRadReportManageForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BuildRibbon;
end;

class procedure TRadReportManageForm.Execute(const AJob: IRadReport);
var
  LForm: TRadReportManageForm;
begin
  LForm := TRadReportManageForm.Create(Application);
  try
    LForm.Job := AJob;
    LForm.ShowModal;
  finally
    LForm.Free;
  end;
end;

procedure TRadReportManageForm.DoShow;
begin
  inherited;
  if FJob <> nil then
    Caption := Format(STitle, [FJob.Key]);
  Refresh;
end;

function TRadReportManageForm.Confirm(const AText: string): Boolean;
begin
  Result := MessageDlg(AText, mtConfirmation, [mbYes, mbNo], 0) = mrYes;
end;

procedure TRadReportManageForm.Guarded(const AWork: TProc);
begin
  try
    AWork();
  except
    on E: ERadReport do
    begin
      MessageDlg(E.Message, mtWarning, [mbOK], 0);
      Refresh;
    end;
  end;
end;

function TRadReportManageForm.JobFor(const ADesign: string): IRadReport;
var
  LInternal: IRadReportInternal;
begin
  if Supports(FJob, IRadReportInternal, LInternal) then
    Result := LInternal.Clone(ADesign)
  else
    raise ERadReport.Create('İş nesnesi klonlanamıyor.');
end;

function TRadReportManageForm.Selected(out AInfo: TRadReportInfo): Boolean;
var
  LIdx: Integer;
begin
  LIdx := viewDesign.DataController.FocusedRecordIndex;
  Result := (LIdx >= 0) and (LIdx <= High(FList));
  if Result then
    AInfo := FList[LIdx]
  else
    AInfo := Default(TRadReportInfo);
end;

function TRadReportManageForm.SelectedVersion(out AVersion: TRadReportVersion): Boolean;
var
  LIdx: Integer;
begin
  LIdx := viewVersion.DataController.FocusedRecordIndex;
  Result := (LIdx >= 0) and (LIdx <= High(FVersions));
  if Result then
    AVersion := FVersions[LIdx]
  else
    AVersion := Default(TRadReportVersion);
end;

procedure TRadReportManageForm.Refresh;
var
  I, LKeep: Integer;
  LName: string;
  LInfo: TRadReportInfo;
  LDC: TcxCustomDataController;
begin
  if FJob = nil then
    Exit;
  LName := '';
  if Selected(LInfo) then
    LName := LInfo.Design;
  FList := FJob.List;
  LDC := viewDesign.DataController;
  viewDesign.BeginUpdate;
  try
    LDC.RecordCount := Length(FList);
    for I := 0 to High(FList) do
    begin
      LDC.Values[I, colName.Index] := FList[I].Design;
      LDC.Values[I, colDefault.Index] := IfThen(FList[I].IsDefault, SYes, SNo);
      LDC.Values[I, colVersion.Index] := FList[I].Version;
      LDC.Values[I, colTemplate.Index] := FList[I].FileNameTemplate;
      LDC.Values[I, colUpdatedBy.Index] := IfThen(FList[I].UpdatedBy <> '', FList[I].UpdatedBy, FList[I].CreatedBy);
      if FList[I].UpdatedAt <> 0 then
        LDC.Values[I, colUpdatedAt.Index] := FList[I].UpdatedAt
      else
        LDC.Values[I, colUpdatedAt.Index] := FList[I].CreatedAt;
    end;
  finally
    viewDesign.EndUpdate;
  end;
  LKeep := 0;
  if LName <> '' then
    for I := 0 to High(FList) do
      if SameText(FList[I].Design, LName) then
      begin
        LKeep := I;
        Break;
      end;
  if Length(FList) > 0 then
    LDC.FocusedRecordIndex := LKeep;
  LoadVersions;
end;

procedure TRadReportManageForm.LoadVersions;
var
  I: Integer;
  LInfo: TRadReportInfo;
  LDC: TcxCustomDataController;
begin
  SetLength(FVersions, 0);
  if Selected(LInfo) then
    FVersions := JobFor(LInfo.Design).Versions;
  LDC := viewVersion.DataController;
  viewVersion.BeginUpdate;
  try
    LDC.RecordCount := Length(FVersions);
    for I := 0 to High(FVersions) do
    begin
      LDC.Values[I, colVNo.Index] := FVersions[I].Version;
      LDC.Values[I, colVDate.Index] := FVersions[I].CreatedAt;
      LDC.Values[I, colVUser.Index] := FVersions[I].CreatedBy;
      LDC.Values[I, colVSize.Index] := FVersions[I].Size;
      LDC.Values[I, colVNote.Index] := FVersions[I].Note;
    end;
  finally
    viewVersion.EndUpdate;
  end;
end;

procedure TRadReportManageForm.viewDesignFocusedRecordChanged(Sender: TcxCustomGridTableView; APrevFocusedRecord,
  AFocusedRecord: TcxCustomGridRecord; ANewItemRecordFocusingChanged: Boolean);
begin
  LoadVersions;
end;

procedure TRadReportManageForm.viewDesignDblClick(Sender: TObject);
begin
  if actPreview.Enabled then
    actPreview.Execute;
end;

procedure TRadReportManageForm.ActionListUpdate(Action: TBasicAction; var Handled: Boolean);
var
  LInfo: TRadReportInfo;
  LHas: Boolean;
begin
  LHas := (FJob <> nil) and Selected(LInfo);
  actPreview.Enabled := LHas;
  actDesign.Enabled := LHas;
  actNewDesign.Enabled := FJob <> nil;
  actCopy.Enabled := LHas;
  actSetDefault.Enabled := LHas and not LInfo.IsDefault;
  actDelete.Enabled := LHas;
  actRestore.Enabled := LHas and (viewVersion.DataController.FocusedRecordIndex >= 0);
  actDeleteOld.Enabled := LHas and (LInfo.Version > 1);
  actReset.Enabled := LHas and (LInfo.Version > 1);
  actSyncToLocal.Enabled := LHas;
  actPushFromLocal.Enabled := LHas;
  actOpenFolder.Enabled := FJob <> nil;
  Handled := True;
end;

procedure TRadReportManageForm.actRefreshExecute(Sender: TObject);
begin
  Guarded(procedure begin Refresh; end);
end;

procedure TRadReportManageForm.actPreviewExecute(Sender: TObject);
var
  LInfo: TRadReportInfo;
begin
  if Selected(LInfo) then
    Guarded(procedure begin JobFor(LInfo.Design).Preview; end);
end;

procedure TRadReportManageForm.actDesignExecute(Sender: TObject);
var
  LInfo: TRadReportInfo;
begin
  if Selected(LInfo) then
    Guarded(
      procedure
      begin
        JobFor(LInfo.Design).Design;
        Refresh;
      end);
end;

procedure TRadReportManageForm.actNewDesignExecute(Sender: TObject);
var
  LName: string;
begin
  LName := '';
  if not InputQuery(actNewDesign.Caption, SNewDesignPrompt, LName) or (Trim(LName) = '') then
    Exit;
  Guarded(
    procedure
    begin
      JobFor(Trim(LName)).Design;
      Refresh;
    end);
end;

procedure TRadReportManageForm.actCopyExecute(Sender: TObject);
var
  LInfo: TRadReportInfo;
  LName: string;
begin
  if not Selected(LInfo) then
    Exit;
  LName := LInfo.Design + ' (kopya)';
  if not InputQuery(actCopy.Caption, SCopyPrompt, LName) or (Trim(LName) = '') then
    Exit;
  Guarded(
    procedure
    begin
      JobFor(LInfo.Design).Copy(Trim(LName));
      Refresh;
    end);
end;

procedure TRadReportManageForm.actSetDefaultExecute(Sender: TObject);
var
  LInfo: TRadReportInfo;
begin
  if Selected(LInfo) then
    Guarded(
      procedure
      begin
        JobFor(LInfo.Design).SetDefault;
        Refresh;
      end);
end;

procedure TRadReportManageForm.actDeleteExecute(Sender: TObject);
var
  LInfo: TRadReportInfo;
begin
  if Selected(LInfo) and Confirm(Format(SDeleteConfirm, [LInfo.Design])) then
    Guarded(
      procedure
      begin
        JobFor(LInfo.Design).Delete;
        Refresh;
      end);
end;

procedure TRadReportManageForm.actRestoreExecute(Sender: TObject);
var
  LInfo: TRadReportInfo;
  LVersion: TRadReportVersion;
begin
  if Selected(LInfo) and SelectedVersion(LVersion) and Confirm(Format(SRestoreConfirm, [LVersion.Version])) then
    Guarded(
      procedure
      begin
        JobFor(LInfo.Design).Restore(LVersion.Version);
        Refresh;
      end);
end;

procedure TRadReportManageForm.actDeleteOldExecute(Sender: TObject);
var
  LInfo: TRadReportInfo;
begin
  if Selected(LInfo) and Confirm(SDeleteOldConfirm) then
    Guarded(
      procedure
      begin
        JobFor(LInfo.Design).DeleteOldVersions;
        Refresh;
      end);
end;

procedure TRadReportManageForm.actResetExecute(Sender: TObject);
var
  LInfo: TRadReportInfo;
begin
  if Selected(LInfo) and Confirm(SResetConfirm) then
    Guarded(
      procedure
      begin
        JobFor(LInfo.Design).ResetVersions;
        Refresh;
      end);
end;

procedure TRadReportManageForm.actSyncToLocalExecute(Sender: TObject);
var
  LInfo: TRadReportInfo;
begin
  if Selected(LInfo) then
    Guarded(procedure begin MessageDlg(Format(SSynced, [JobFor(LInfo.Design).SyncToLocal]), mtInformation, [mbOK], 0); end);
end;

procedure TRadReportManageForm.actPushFromLocalExecute(Sender: TObject);
var
  LInfo: TRadReportInfo;
begin
  if Selected(LInfo) then
    Guarded(
      procedure
      begin
        if JobFor(LInfo.Design).PushFromLocal then
          MessageDlg(SPushed, mtInformation, [mbOK], 0)
        else
          MessageDlg(SUnchanged, mtInformation, [mbOK], 0);
        Refresh;
      end);
end;

procedure TRadReportManageForm.actOpenFolderExecute(Sender: TObject);
var
  LInternal: IRadReportInternal;
  LFolder: string;
begin
  if not Supports(FJob, IRadReportInternal, LInternal) then
    Exit;
  LFolder := LInternal.Service.LocalFolder;
  ForceDirectories(LFolder);
  ShellExecute(0, 'open', PChar(LFolder), nil, nil, SW_SHOWNORMAL);
end;

// ---------------------------------------------------------------------- ribbon

function TRadReportManageForm.GlyphIndex(AGlyph: Word): Integer;
const
  Size = 32;
  Color = $00C8781E;   // BGR: ribbon üzerinde okunaklı mavi
var
  LGray, LAlpha: TBitmap;
  X, Y: Integer;
  LDest: PRGBQuad;
  LA: Byte;
begin
  // Segoe MDL2 Assets glifini beyaz zemine siyah çiz; koyuluk = alfa; rengi önceden çarpılmış olarak yaz.
  LGray := TBitmap.Create;
  LAlpha := TBitmap.Create;
  try
    LGray.PixelFormat := pf24bit;
    LGray.SetSize(Size, Size);
    LGray.Canvas.Brush.Color := clWhite;
    LGray.Canvas.FillRect(Rect(0, 0, Size, Size));
    LGray.Canvas.Font.Name := 'Segoe MDL2 Assets';
    LGray.Canvas.Font.Size := 17;
    LGray.Canvas.Font.Color := clBlack;
    LGray.Canvas.Brush.Style := bsClear;
    LGray.Canvas.TextOut((Size - LGray.Canvas.TextWidth(Char(AGlyph))) div 2,
      (Size - LGray.Canvas.TextHeight(Char(AGlyph))) div 2, Char(AGlyph));
    LAlpha.PixelFormat := pf32bit;
    LAlpha.AlphaFormat := afPremultiplied;
    LAlpha.SetSize(Size, Size);
    for Y := 0 to Size - 1 do
    begin
      LDest := PRGBQuad(LAlpha.ScanLine[Y]);
      for X := 0 to Size - 1 do
      begin
        LA := 255 - PByte(NativeInt(LGray.ScanLine[Y]) + X * 3 + 1)^;
        LDest^.rgbRed := (Color and $FF) * LA div 255;
        LDest^.rgbGreen := ((Color shr 8) and $FF) * LA div 255;
        LDest^.rgbBlue := ((Color shr 16) and $FF) * LA div 255;
        LDest^.rgbReserved := LA;
        Inc(LDest);
      end;
    end;
    Result := FImages.Add(LAlpha, nil);
  finally
    LAlpha.Free;
    LGray.Free;
  end;
end;

function TRadReportManageForm.AddButton(ABar: TdxBar; AAction: TAction; AGlyph: Word): TdxBarLargeButton;
begin
  Result := TdxBarLargeButton.Create(Self);
  ABar.ItemLinks.Add.Item := Result;
  Result.Action := AAction;
  if AGlyph <> 0 then
    Result.LargeImageIndex := GlyphIndex(AGlyph);
end;

procedure TRadReportManageForm.BuildRibbon;
var
  LTab: TdxRibbonTab;

  procedure Group(const ACaption: string; const AActions: array of TAction; const AGlyphs: array of Word);
  var
    LBar: TdxBar;
    I: Integer;
  begin
    LBar := FBarManager.AddToolBar;
    LBar.Caption := ACaption;
    LBar.Visible := False;      // ribbona yerleşmeden gösterilmesin (bozuk çizimi önler)
    for I := Low(AActions) to High(AActions) do
      AddButton(LBar, AActions[I], AGlyphs[I]);
    LTab.AddToolBar(LBar);
    LBar.Visible := True;
  end;

begin
  FBarManager := TdxBarManager.Create(Self);
  FImages := TcxImageList.Create(Self);
  FImages.SetSize(32, 32);
  FBarManager.ImageOptions.LargeImages := FImages;
  FRibbon := TdxRibbon.Create(Self);
  FRibbon.Parent := Self;
  FRibbon.BeginUpdate;
  try
    FRibbon.Style := rsOffice365;
    FRibbon.BarManager := FBarManager;

    LTab := FRibbon.Tabs.Add;
    LTab.Caption := STabDesigns;
    Group(SGrpRun, [actPreview, actRefresh], [$E890, $E72C]);
    Group(SGrpEdit, [actDesign, actNewDesign, actCopy, actSetDefault, actDelete], [$E70F, $E710, $E8C8, $E735, $E74D]);

    LTab := FRibbon.Tabs.Add;
    LTab.Caption := STabVersions;
    Group(SGrpVersions, [actRestore, actDeleteOld, actReset], [$E7A7, $E894, $E777]);

    LTab := FRibbon.Tabs.Add;
    LTab.Caption := STabLocal;
    Group(SGrpSync, [actSyncToLocal, actPushFromLocal, actOpenFolder], [$E896, $E898, $E8B7]);

    FRibbon.ActiveTab := FRibbon.Tabs[0];
  finally
    FRibbon.EndUpdate;
  end;
end;

end.
