unit DesktopDemoMain;

(* Demo host of the ERP desktop: actions and a menu as command sources, sample widgets, a file
   store. "--shot <folder>" writes PNG snapshots of the main states and exits. *)

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Actions,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.ActnList,
  Vcl.Menus,
  Vcl.ImgList,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  System.ImageList,
  rad.formstate.store,
  rad.desktop;

type
  TDemoForm = class(TForm)
    alMain: TActionList;
    actFatura: TAction;
    actIrsaliye: TAction;
    actSiparis: TAction;
    actTeklif: TAction;
    actCari: TAction;
    actStok: TAction;
    actSayim: TAction;
    actTransfer: TAction;
    actKasa: TAction;
    actBanka: TAction;
    actCek: TAction;
    actSenet: TAction;
    actTahsilat: TAction;
    actTediye: TAction;
    actRapor: TAction;
    actAyarlar: TAction;
    actPersonel: TAction;
    actMail: TAction;
    ilIcons: TImageList;
    mmMain: TMainMenu;
    miDosya: TMenuItem;
    miYedekAl: TMenuItem;
    miCikis: TMenuItem;
    pnlStatus: TPanel;
    lblStatus: TLabel;
    Desktop: TRADDesktopView;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ActionExecute(Sender: TObject);
    procedure miYedekAlClick(Sender: TObject);
    procedure miCikisClick(Sender: TObject);
  private
    FStateStore: IRadStateStore;
    FRepository: TRadStateRepository;
    procedure BuildIcons;
    procedure AddWidgets;
    procedure SeedLayout;
    procedure DashboardOpen(Sender: TObject; AItem: TRadDeskItem);
  public
    procedure Shots(const AFolder: string);
  end;

var
  DemoForm: TDemoForm;

implementation

{$R *.dfm}

uses
  System.IOUtils,
  System.Math,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ,
  rad.desktop.paint,
  rad.desktop.core,
  rad.desktop.picker,
  Vcl.Imaging.pngimage;

const
  CIconSize = 40;
  CGlyphFont = 'Segoe Fluent Icons';
  CGlyphFallback = 'Segoe MDL2 Assets';

type
  TIconDef = record
    Glyph: Char;
    Color: Cardinal;
  end;

const
  CIcons: array[0..17] of TIconDef = (
    (Glyph: #$E8A5; Color: $FF3B82F6), (Glyph: #$E7B8; Color: $FF6366F1), (Glyph: #$E7BF; Color: $FF0EA5E9),
    (Glyph: #$E8EC; Color: $FF8B5CF6), (Glyph: #$E716; Color: $FF10B981), (Glyph: #$E7B8; Color: $FFF59E0B),
    (Glyph: #$E8EF; Color: $FFF97316), (Glyph: #$E8AB; Color: $FFEAB308), (Glyph: #$E8C7; Color: $FF22C55E),
    (Glyph: #$E825; Color: $FF14B8A6), (Glyph: #$E7C3; Color: $FF06B6D4), (Glyph: #$E8A4; Color: $FF0891B2),
    (Glyph: #$E8C7; Color: $FF16A34A), (Glyph: #$E8C8; Color: $FFDC2626), (Glyph: #$E9D2; Color: $FFEC4899),
    (Glyph: #$E713; Color: $FF64748B), (Glyph: #$E77B; Color: $FF84CC16), (Glyph: #$E715; Color: $FFEF4444));

function GlyphFont: string;
begin
  if Screen.Fonts.IndexOf(CGlyphFont) >= 0 then
    Result := CGlyphFont
  else
    Result := CGlyphFallback;
end;

procedure TDemoForm.BuildIcons;
var
  I: Integer;
  LBmp: TGPBitmap;
  G: TGPGraphics;
  LIcon: TIcon;
  LHandle: HICON;
  R: TGPRectF;
begin
  ilIcons.Clear;
  ilIcons.ColorDepth := cd32Bit;
  ilIcons.SetSize(CIconSize, CIconSize);
  for I := 0 to High(CIcons) do
  begin
    LBmp := TGPBitmap.Create(CIconSize, CIconSize, PixelFormat32bppARGB);
    try
      G := TGPGraphics.Create(LBmp);
      try
        TRadDeskDraw.Prepare(G);
        G.SetTextRenderingHint(TextRenderingHintAntiAliasGridFit);
        R := MakeRect(1.0, 1, CIconSize - 2, CIconSize - 2);
        TRadDeskDraw.FillRound(G, R, 10, CIcons[I].Color);
        TRadDeskDraw.FillRound(G, MakeRect(1.0, 1, CIconSize - 2, (CIconSize - 2) / 2), 10,
          TRadDeskDraw.WithAlpha($FFFFFFFF, 34));
        TRadDeskDraw.Text(G, CIcons[I].Glyph, GlyphFont, 20, FontStyleRegular, R, $FFFFFFFF,
          StringAlignmentCenter, StringAlignmentCenter, False);
      finally
        G.Free;
      end;
      LBmp.GetHICON(LHandle);
      LIcon := TIcon.Create;
      try
        LIcon.Handle := LHandle;
        ilIcons.AddIcon(LIcon);
      finally
        LIcon.Free;
      end;
    finally
      LBmp.Free;
    end;
  end;
end;

procedure TDemoForm.AddWidgets;
begin
  TRadDesktop.EkleWidget(TRadDeskFuncWidget.Create('ciro', 'Günlük ciro', dsWide, 60000,
    procedure(ASettings: string; AData: TRadDeskWidgetData)
    const
      CSeries: array[0..13] of Double = (42, 47, 44, 52, 58, 55, 61, 66, 63, 70, 74, 71, 79, 86);
    var
      V: Double;
    begin
      AData.Title := 'Günlük ciro';
      AData.Value := '₺ 1,28 M';
      AData.SubText := 'Dün: ₺ 1,12 M  ·  +14,3%';
      AData.Trend := dtUp;
      for V in CSeries do
        AData.AddPoint(V);
    end));
  TRadDesktop.EkleWidget(TRadDeskFuncWidget.Create('tahsilat', 'Tahsilat oranı', dsSmall, 60000,
    procedure(ASettings: string; AData: TRadDeskWidgetData)
    begin
      AData.Title := 'Tahsilat';
      AData.Value := '%87';
      AData.SubText := 'Hedef %90';
      AData.Trend := dtDown;
    end));
  TRadDesktop.EkleWidget(TRadDeskFuncWidget.Create('siparis', 'Bekleyen siparişler', dsLarge, 60000,
    procedure(ASettings: string; AData: TRadDeskWidgetData)
    begin
      AData.Title := 'Bekleyen siparişler';
      AData.Value := '23';
      AData.SubText := '5 tanesi bugün sevk edilmeli';
      AData.AddLine('SP-1042  Akdeniz Gıda      ₺ 84.300');
      AData.AddLine('SP-1045  Ege Tekstil       ₺ 41.950');
      AData.AddLine('SP-1047  Marmara Yapı      ₺ 128.000');
      AData.AddLine('SP-1050  Karadeniz Lojistik ₺ 22.480');
      AData.AddLine('SP-1051  Anadolu Medikal   ₺ 9.600');
    end));
  TRadDesktop.EkleWidget(TRadDeskFuncWidget.Create('kasa', 'Kasa bakiyesi', dsSmall, 60000,
    procedure(ASettings: string; AData: TRadDeskWidgetData)
    begin
      AData.Title := 'Kasa';
      AData.Value := '₺ 214 B';
      AData.SubText := '3 kasa';
      AData.Trend := dtUp;
    end));
end;

procedure TDemoForm.SeedLayout;
var
  L: TRadDeskLayout;
  G: TRadDeskGroup;

  procedure Add(AGroup: TRadDeskGroup; const AId: string);
  begin
    AGroup.Items.Add(TRadDeskItem.Create(dkShortcut, AId));
  end;

  function Widget(AGroup: TRadDeskGroup; const AId: string; ASize: TRadDeskSize): TRadDeskItem;
  begin
    Result := TRadDeskItem.Create(dkWidget, AId);
    Result.Size := ASize;
    AGroup.Items.Add(Result);
  end;

begin
  L := Desktop.Layout;
  if L.Groups.Count > 0 then
    Exit;
  G := L.AddGroup('Satış');
  G.Col := 0; G.Row := 0; G.Cols := 8; G.Color := $FF3B82F6;
  Add(G, 'act:actFatura'); Add(G, 'act:actIrsaliye'); Add(G, 'act:actSiparis'); Add(G, 'act:actTeklif');
  Add(G, 'act:actCari'); Add(G, 'act:actMail');
  G := L.AddGroup('Bugün');
  G.Col := 9; G.Row := 0; G.Cols := 8; G.Color := $FF10B981;
  Widget(G, 'ciro', dsWide); Widget(G, 'clock', dsWide); Widget(G, 'tahsilat', dsSmall);
  Widget(G, 'kasa', dsSmall); Widget(G, 'siparis', dsLarge);
  G := L.AddGroup('Stok');
  G.Col := 0; G.Row := 6; G.Cols := 8; G.Color := $FFF59E0B;
  Add(G, 'act:actStok'); Add(G, 'act:actSayim'); Add(G, 'act:actTransfer'); Add(G, 'act:actEski');
  G := L.AddGroup('Tahsilat', gsFolder);
  G.Col := 19; G.Row := 0; G.Color := $FF8B5CF6;
  Add(G, 'act:actTahsilat'); Add(G, 'act:actKasa'); Add(G, 'act:actBanka'); Add(G, 'act:actCek');
  Add(G, 'act:actSenet');
  G := L.AddGroup('Tediye', gsFolder);
  G.Col := 19; G.Row := 2; G.Color := $FFEF4444;
  Add(G, 'act:actTediye'); Add(G, 'act:actKasa'); Add(G, 'act:actBanka');
  G := L.AddGroup('Raporlar');
  G.Col := 0; G.Row := 10; G.Cols := 8; G.Color := $FFEC4899;
  L.Groups.Last.Items.Add(TRadDeskItem.Create(dkDashboard, 'Satış Performansı'));
  L.Groups.Last.Items.Last.Size := dsWide;
  Add(G, 'act:actRapor');
  Add(G, 'menu:miYedekAl');
  G := L.AddGroup('Sistem', gsFolder);
  G.Col := 19; G.Row := 4; G.Color := $FF64748B;
  Add(G, 'act:actAyarlar'); Add(G, 'act:actPersonel');
  Desktop.Changed;
end;

procedure TDemoForm.FormCreate(Sender: TObject);
var
  LRoot: string;
begin
  BuildIcons;
  LRoot := TPath.Combine(ExtractFilePath(ParamStr(0)), 'desktop-state');
  if FindCmdLineSwitch('shot') and TDirectory.Exists(LRoot) then
    TDirectory.Delete(LRoot, True);
  FStateStore := TRadFileStateStore.Create(LRoot);
  FRepository := TRadStateRepository.Create(FStateStore, nil, False);
  TRadDesktop.Kur(Desktop, FRepository, 'demo');
  TRadDesktop.EkleAksiyonlar(alMain);
  TRadDesktop.EkleMenu(mmMain);
  TRadDesktop.Izin(
    function(const AId: string): Boolean
    begin
      Result := AId <> 'act:actPersonel';
    end);
  AddWidgets;
  Desktop.OnOpenDashboard := DashboardOpen;
  SeedLayout;
end;

procedure TDemoForm.FormDestroy(Sender: TObject);
begin
  TRadDesktop.Kapat;
  FRepository.Free;
end;

procedure TDemoForm.ActionExecute(Sender: TObject);
begin
  lblStatus.Caption := 'Çalıştırıldı: ' + TAction(Sender).Caption;
end;

procedure TDemoForm.DashboardOpen(Sender: TObject; AItem: TRadDeskItem);
begin
  lblStatus.Caption := 'Dashboard açılacak: ' + AItem.Target;
end;

procedure TDemoForm.miYedekAlClick(Sender: TObject);
begin
  lblStatus.Caption := 'Yedek alındı';
end;

procedure TDemoForm.miCikisClick(Sender: TObject);
begin
  Close;
end;

procedure SavePng(ABitmap: TBitmap; const AFileName: string);
var
  LPng: TPngImage;
begin
  LPng := TPngImage.Create;
  try
    LPng.Assign(ABitmap);
    LPng.SaveToFile(AFileName);
  finally
    LPng.Free;
  end;
end;

procedure TDemoForm.Shots(const AFolder: string);

  procedure Pump;
  begin
    Application.ProcessMessages;
  end;

  function TileCenter(const ATarget: string): TPoint;
  var
    LTile: TRadDeskTileView;
  begin
    for LTile in Desktop.Tiles do
      if LTile.Item.Target = ATarget then
        Exit(LTile.Rect.CenterPoint);
    Result := Point(-1, -1);
  end;

  function GroupByTitle(const ATitle: string): TRadDeskGroup;
  var
    LGroup: TRadDeskGroup;
  begin
    for LGroup in Desktop.Layout.Groups do
      if LGroup.Title = ATitle then
        Exit(LGroup);
    Result := nil;
  end;

var
  P, Q: TPoint;
  LPicker: TRadDeskPickerForm;
  LBmp: TBitmap;
begin
  ForceDirectories(AFolder);
  Pump;
  Desktop.RefreshAllWidgets;
  Desktop.SetFocus;
  Desktop.FocusItem('');
  Desktop.SaveSnapshot(TPath.Combine(AFolder, '01_masaustu_koyu.png'));
  Desktop.OpenFolder(GroupByTitle('Tahsilat'));
  Desktop.SaveSnapshot(TPath.Combine(AFolder, '02_klasor_acik.png'));
  Desktop.CloseFolder;
  Desktop.Rebuild;
  P := TileCenter('act:actFatura');
  Q := Point(Desktop.GroupViews[2].Rect.Left + 120, Desktop.GroupViews[2].Rect.Top + 90);
  Desktop.Perform(WM_LBUTTONDOWN, MK_LBUTTON, MakeLParam(P.X, P.Y));
  Desktop.Perform(WM_MOUSEMOVE, MK_LBUTTON, MakeLParam(P.X + 20, P.Y + 20));
  Desktop.Perform(WM_MOUSEMOVE, MK_LBUTTON, MakeLParam(Q.X, Q.Y));
  Desktop.SaveSnapshot(TPath.Combine(AFolder, '03_surukle.png'));
  Desktop.Perform(WM_KEYDOWN, VK_ESCAPE, 0);
  Desktop.Perform(WM_LBUTTONUP, 0, MakeLParam(Q.X, Q.Y));
  Desktop.ThemeKind := tkLight;
  Desktop.SaveSnapshot(TPath.Combine(AFolder, '04_masaustu_acik.png'));
  Desktop.ThemeKind := tkDark;
  Desktop.Effects := deReduced;
  Desktop.SaveSnapshot(TPath.Combine(AFolder, '05_uzak_masaustu.png'));
  Desktop.Effects := deAuto;
  LPicker := TRadDeskPickerForm.Create(nil);
  try
    LPicker.Load(TRadDesktop.Commands.All);
    LPicker.Show;
    Pump;
    LBmp := LPicker.GetFormImage;
    try
      SavePng(LBmp, TPath.Combine(AFolder, '06_kisayol_ekle.png'));
    finally
      LBmp.Free;
    end;
  finally
    LPicker.Free;
  end;
end;

initialization
  RegisterClass(TRADDesktopView);

end.
