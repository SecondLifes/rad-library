unit rad.desktop.dialogs;

(* Context menus of the ERP desktop. The menus are designed in the DFM; only the data-driven entries
   (group colors, widget providers) are created in code. *)

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  Vcl.Menus,
  Vcl.Graphics;

type
  TRadDeskMenus = class(TDataModule)
    pmDesktop: TPopupMenu;
    miNewGroup: TMenuItem;
    miNewFolder: TMenuItem;
    miDeskSep1: TMenuItem;
    miTheme: TMenuItem;
    miThemeDark: TMenuItem;
    miThemeLight: TMenuItem;
    miDeskSep2: TMenuItem;
    miReset: TMenuItem;
    miSaveBase: TMenuItem;
    pmGroup: TPopupMenu;
    miGroupAdd: TMenuItem;
    miGroupWidget: TMenuItem;
    miGroupDashboard: TMenuItem;
    miGroupSep1: TMenuItem;
    miGroupRename: TMenuItem;
    miGroupColor: TMenuItem;
    miGroupStyle: TMenuItem;
    miGroupCollapse: TMenuItem;
    miGroupSep2: TMenuItem;
    miGroupDelete: TMenuItem;
    pmItem: TPopupMenu;
    miItemOpen: TMenuItem;
    miItemRename: TMenuItem;
    miItemSize: TMenuItem;
    miSizeSmall: TMenuItem;
    miSizeWide: TMenuItem;
    miSizeLarge: TMenuItem;
    miItemSep1: TMenuItem;
    miItemRemove: TMenuItem;
    procedure miNewGroupClick(Sender: TObject);
    procedure miNewFolderClick(Sender: TObject);
    procedure miThemeDarkClick(Sender: TObject);
    procedure miThemeLightClick(Sender: TObject);
    procedure miResetClick(Sender: TObject);
    procedure miSaveBaseClick(Sender: TObject);
    procedure miGroupAddClick(Sender: TObject);
    procedure miGroupDashboardClick(Sender: TObject);
    procedure miGroupRenameClick(Sender: TObject);
    procedure miGroupStyleClick(Sender: TObject);
    procedure miGroupCollapseClick(Sender: TObject);
    procedure miGroupDeleteClick(Sender: TObject);
    procedure miItemOpenClick(Sender: TObject);
    procedure miItemRenameClick(Sender: TObject);
    procedure miSizeClick(Sender: TObject);
    procedure miItemRemoveClick(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
  private
    FView: TObject;
    FGroupId: string;
    FItemId: string;
    FCell: TPoint;
    procedure BuildColors;
    procedure BuildWidgets;
    procedure ColorClick(Sender: TObject);
    procedure WidgetClick(Sender: TObject);
    procedure PrepareDesktop;
    procedure PrepareGroup;
    procedure PrepareItem;
  public
    /// <summary>Shows the menu that fits AHit (a TRadDeskHit) for AView (a TRADDesktopView).</summary>
    procedure Popup(AView: TObject; const AHit; const AScreen: TPoint);
  end;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

uses
  Vcl.Dialogs,
  rad.desktop.core,
  rad.desktop.widgets,
  rad.desktop.paint,
  rad.desktop.picker,
  rad.desktop.view;

const
  CColorNames: array[0..7] of string = ('Mavi', 'Yeşil', 'Turuncu', 'Kırmızı', 'Mor', 'Pembe', 'Turkuaz', 'Gri');
  CSwatchSize = 14;

function View(ASelf: TRadDeskMenus): TRADDesktopView; inline;
begin
  Result := TRADDesktopView(ASelf.FView);
end;

function CurrentGroup(ASelf: TRadDeskMenus): TRadDeskGroup;
begin
  Result := View(ASelf).Layout.FindGroup(ASelf.FGroupId);
end;

function CurrentItem(ASelf: TRadDeskMenus): TRadDeskItem;
var
  LIndex: Integer;
  LGroup: TRadDeskGroup;
begin
  LGroup := View(ASelf).Layout.GroupOfItem(ASelf.FItemId, LIndex);
  if Assigned(LGroup) then
    Result := LGroup.Items[LIndex]
  else
    Result := nil;
end;

procedure TRadDeskMenus.DataModuleDestroy(Sender: TObject);
begin
  FView := nil;
end;

procedure TRadDeskMenus.Popup(AView: TObject; const AHit; const AScreen: TPoint);
var
  LHit: TRadDeskHit;
begin
  LHit := TRadDeskHit(AHit);
  FView := AView;
  FGroupId := '';
  FItemId := '';
  if Assigned(LHit.Group) then
    FGroupId := LHit.Group.Id;
  if Assigned(LHit.Item) then
    FItemId := LHit.Item.Id;
  FCell := View(Self).CellAt(View(Self).ScreenToClient(AScreen));
  case LHit.Kind of
    hkItem:
      begin
        PrepareItem;
        pmItem.Popup(AScreen.X, AScreen.Y);
      end;
    hkGroupTitle, hkGroupBody, hkGroupGrip, hkFolder, hkPanel:
      if not View(Self).Locked then
      begin
        PrepareGroup;
        pmGroup.Popup(AScreen.X, AScreen.Y);
      end;
    hkDesktop:
      begin
        PrepareDesktop;
        pmDesktop.Popup(AScreen.X, AScreen.Y);
      end;
  end;
end;

procedure TRadDeskMenus.PrepareDesktop;
var
  LLocked: Boolean;
begin
  LLocked := View(Self).Locked;
  miNewGroup.Visible := not LLocked;
  miNewFolder.Visible := not LLocked;
  miDeskSep1.Visible := not LLocked;
  miThemeDark.Checked := View(Self).ThemeKind = tkDark;
  miThemeLight.Checked := View(Self).ThemeKind = tkLight;
  miReset.Visible := not LLocked;
  miSaveBase.Visible := View(Self).CanEditBase;
end;

procedure TRadDeskMenus.PrepareGroup;
var
  LGroup: TRadDeskGroup;
begin
  LGroup := CurrentGroup(Self);
  if not Assigned(LGroup) then
    Exit;
  BuildColors;
  BuildWidgets;
  miGroupDashboard.Visible := View(Self).AllowDashboards;
  if LGroup.Style = gsFolder then
    miGroupStyle.Caption := 'Kutuya dönüştür'
  else
    miGroupStyle.Caption := 'Klasöre dönüştür';
  miGroupCollapse.Visible := LGroup.Style = gsBox;
  if LGroup.Collapsed then
    miGroupCollapse.Caption := 'Genişlet'
  else
    miGroupCollapse.Caption := 'Daralt';
end;

procedure TRadDeskMenus.PrepareItem;
var
  LItem: TRadDeskItem;
  LEdit: Boolean;
begin
  LItem := CurrentItem(Self);
  if not Assigned(LItem) then
    Exit;
  LEdit := not View(Self).Locked;
  miItemRename.Visible := LEdit;
  miItemRemove.Visible := LEdit;
  miItemSep1.Visible := LEdit;
  miItemSize.Visible := LEdit and (LItem.Kind <> dkShortcut);
  miSizeSmall.Checked := LItem.Size = dsSmall;
  miSizeWide.Checked := LItem.Size = dsWide;
  miSizeLarge.Checked := LItem.Size = dsLarge;
end;

function SwatchBitmap(AColor: Cardinal): TBitmap;
begin
  Result := TBitmap.Create;
  Result.SetSize(CSwatchSize, CSwatchSize);
  Result.Canvas.Brush.Color := clFuchsia;
  Result.Canvas.FillRect(Rect(0, 0, CSwatchSize, CSwatchSize));
  Result.Canvas.Brush.Color := TRadDeskDraw.ToColor(AColor);
  Result.Canvas.Pen.Color := TRadDeskDraw.ToColor(TRadDeskDraw.Shade(AColor, -0.3));
  Result.Canvas.Ellipse(1, 1, CSwatchSize - 1, CSwatchSize - 1);
  Result.Transparent := True;
  Result.TransparentColor := clFuchsia;
end;

procedure TRadDeskMenus.BuildColors;
var
  LTheme: TRadDeskTheme;
  LItem: TMenuItem;
  LBmp: TBitmap;
  I: Integer;
begin
  if miGroupColor.Count > 0 then
    Exit;
  LTheme := TRadDeskTheme.Dark;
  for I := 0 to High(LTheme.Accents) do
  begin
    LItem := TMenuItem.Create(Self);
    LItem.Caption := CColorNames[I mod Length(CColorNames)];
    LItem.Tag := I;
    LItem.OnClick := ColorClick;
    LBmp := SwatchBitmap(LTheme.Accents[I]);
    try
      LItem.Bitmap.Assign(LBmp);
    finally
      LBmp.Free;
    end;
    miGroupColor.Add(LItem);
  end;
end;

procedure TRadDeskMenus.BuildWidgets;
var
  LProvider: IRadDeskWidgetProvider;
  LItem: TMenuItem;
begin
  miGroupWidget.Clear;
  miGroupWidget.Visible := Assigned(View(Self).Widgets) and (Length(View(Self).Widgets.All) > 0);
  if not miGroupWidget.Visible then
    Exit;
  for LProvider in View(Self).Widgets.All do
  begin
    LItem := TMenuItem.Create(Self);
    LItem.Caption := LProvider.Caption;
    LItem.Hint := LProvider.Id;
    LItem.OnClick := WidgetClick;
    miGroupWidget.Add(LItem);
  end;
end;

procedure TRadDeskMenus.ColorClick(Sender: TObject);
var
  LGroup: TRadDeskGroup;
begin
  LGroup := CurrentGroup(Self);
  if not Assigned(LGroup) then
    Exit;
  LGroup.Color := TRadDeskTheme.Dark.Accents[TMenuItem(Sender).Tag];
  View(Self).Changed;
end;

procedure TRadDeskMenus.WidgetClick(Sender: TObject);
begin
  View(Self).AddWidget(CurrentGroup(Self), TMenuItem(Sender).Hint);
end;

procedure TRadDeskMenus.miNewGroupClick(Sender: TObject);
var
  LTitle: string;
begin
  LTitle := 'Yeni grup';
  if InputQuery('Yeni grup', 'Grup adı:', LTitle) and (LTitle.Trim <> '') then
    View(Self).NewGroup(LTitle.Trim, gsBox, FCell);
end;

procedure TRadDeskMenus.miNewFolderClick(Sender: TObject);
var
  LTitle: string;
begin
  LTitle := 'Yeni klasör';
  if InputQuery('Yeni klasör', 'Klasör adı:', LTitle) and (LTitle.Trim <> '') then
    View(Self).NewGroup(LTitle.Trim, gsFolder, FCell);
end;

procedure TRadDeskMenus.miThemeDarkClick(Sender: TObject);
begin
  View(Self).ThemeKind := tkDark;
end;

procedure TRadDeskMenus.miThemeLightClick(Sender: TObject);
begin
  View(Self).ThemeKind := tkLight;
end;

procedure TRadDeskMenus.miResetClick(Sender: TObject);
begin
  if View(Self).Confirm('Masaüstü şirket varsayılanına döndürülsün mü? Kendi düzeniniz silinir.') then
    View(Self).DoResetLayout;
end;

procedure TRadDeskMenus.miSaveBaseClick(Sender: TObject);
begin
  if View(Self).Confirm('Bu düzen bütün kullanıcıların varsayılanı olarak kaydedilsin mi?') then
    View(Self).DoSaveAsBase;
end;

procedure TRadDeskMenus.miGroupAddClick(Sender: TObject);
var
  LIds: TArray<string>;
begin
  if not Assigned(View(Self).Commands) then
    Exit;
  if TRadDeskPickerForm.Execute(View(Self).Commands.All, LIds) then
    View(Self).AddShortcuts(CurrentGroup(Self), LIds);
end;

procedure TRadDeskMenus.miGroupDashboardClick(Sender: TObject);
var
  LName: string;
begin
  LName := '';
  if InputQuery('Dashboard ekle', 'Dashboard adı:', LName) then
    View(Self).AddDashboard(CurrentGroup(Self), LName);
end;

procedure TRadDeskMenus.miGroupRenameClick(Sender: TObject);
var
  LGroup: TRadDeskGroup;
  LTitle: string;
begin
  LGroup := CurrentGroup(Self);
  if not Assigned(LGroup) then
    Exit;
  LTitle := LGroup.Title;
  if InputQuery('Yeniden adlandır', 'Grup adı:', LTitle) and (LTitle.Trim <> '') then
  begin
    LGroup.Title := LTitle.Trim;
    View(Self).Changed;
  end;
end;

procedure TRadDeskMenus.miGroupStyleClick(Sender: TObject);
var
  LGroup: TRadDeskGroup;
begin
  LGroup := CurrentGroup(Self);
  if not Assigned(LGroup) then
    Exit;
  if LGroup.Style = gsFolder then
    LGroup.Style := gsBox
  else
    LGroup.Style := gsFolder;
  LGroup.Collapsed := False;
  View(Self).CloseFolder;
  View(Self).Changed;
end;

procedure TRadDeskMenus.miGroupCollapseClick(Sender: TObject);
begin
  View(Self).ToggleCollapsed(CurrentGroup(Self));
end;

procedure TRadDeskMenus.miGroupDeleteClick(Sender: TObject);
begin
  View(Self).RemoveGroup(CurrentGroup(Self));
end;

procedure TRadDeskMenus.miItemOpenClick(Sender: TObject);
begin
  View(Self).ExecuteItem(CurrentItem(Self));
end;

procedure TRadDeskMenus.miItemRenameClick(Sender: TObject);
var
  LItem: TRadDeskItem;
  LCaption: string;
begin
  LItem := CurrentItem(Self);
  if not Assigned(LItem) then
    Exit;
  LCaption := LItem.Caption;
  if InputQuery('Yeniden adlandır', 'Başlık (boş: komutun kendi adı):', LCaption) then
  begin
    LItem.Caption := LCaption.Trim;
    View(Self).Changed;
  end;
end;

procedure TRadDeskMenus.miSizeClick(Sender: TObject);
var
  LItem: TRadDeskItem;
begin
  LItem := CurrentItem(Self);
  if not Assigned(LItem) then
    Exit;
  LItem.Size := TRadDeskSize(TMenuItem(Sender).Tag);
  View(Self).Changed;
end;

procedure TRadDeskMenus.miItemRemoveClick(Sender: TObject);
begin
  View(Self).RemoveItem(CurrentItem(Self));
end;

end.
