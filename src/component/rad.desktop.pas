unit rad.desktop;

(* Entry unit of the ERP desktop (docs/specs/rad.desktop.md, share/rules/single-entry-facade.md).
   A host adds only this unit:

     TRadDesktop.Kur(DesktopView1, Repository, KullaniciAdi);
     TRadDesktop.EkleAksiyonlar(ActionList1);
     TRadDesktop.EkleMenu(MainMenu1);
     ...
     TRadDesktop.Kapat;   // writes a pending save

   Saves are debounced: a change is written 1.5 s after the last edit, never in a destructor. *)

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.ExtCtrls,
  Vcl.ActnList,
  Vcl.Menus,
  rad.formstate.store,
  rad.desktop.core,
  rad.desktop.commands,
  rad.desktop.widgets,
  rad.desktop.paint,
  rad.desktop.store,
  rad.desktop.sources,
  rad.desktop.view;

type
  TRADDesktopView = rad.desktop.view.TRADDesktopView;
  TRadDeskHit = rad.desktop.view.TRadDeskHit;
  TRadDeskTileView = rad.desktop.view.TRadDeskTileView;
  TRadDeskGroupView = rad.desktop.view.TRadDeskGroupView;
  TRadDeskEffects = rad.desktop.view.TRadDeskEffects;
  TRadDeskLayout = rad.desktop.core.TRadDeskLayout;
  TRadDeskGroup = rad.desktop.core.TRadDeskGroup;
  TRadDeskItem = rad.desktop.core.TRadDeskItem;
  TRadDeskItemKind = rad.desktop.core.TRadDeskItemKind;
  TRadDeskGroupStyle = rad.desktop.core.TRadDeskGroupStyle;
  TRadDeskSize = rad.desktop.core.TRadDeskSize;
  ERadDesktop = rad.desktop.core.ERadDesktop;
  IRadDeskCommandSource = rad.desktop.commands.IRadDeskCommandSource;
  TRadDeskCommandInfo = rad.desktop.commands.TRadDeskCommandInfo;
  TRadDeskCommands = rad.desktop.commands.TRadDeskCommands;
  TRadDeskAllowFunc = rad.desktop.commands.TRadDeskAllowFunc;
  TRadDeskCmdSource = rad.desktop.commands.TRadDeskCmdSource;
  TRadDeskActionSource = rad.desktop.sources.TRadDeskActionSource;
  TRadDeskMenuSource = rad.desktop.sources.TRadDeskMenuSource;
  IRadDeskWidgetProvider = rad.desktop.widgets.IRadDeskWidgetProvider;
  TRadDeskWidgetData = rad.desktop.widgets.TRadDeskWidgetData;
  TRadDeskWidgets = rad.desktop.widgets.TRadDeskWidgets;
  TRadDeskFuncWidget = rad.desktop.widgets.TRadDeskFuncWidget;
  TRadDeskClockWidget = rad.desktop.widgets.TRadDeskClockWidget;
  TRadDeskTrend = rad.desktop.widgets.TRadDeskTrend;
  TRadDeskTheme = rad.desktop.paint.TRadDeskTheme;
  TRadDeskThemeKind = rad.desktop.paint.TRadDeskThemeKind;
  TRadDeskStore = rad.desktop.store.TRadDeskStore;

const
  dkShortcut = rad.desktop.core.dkShortcut;
  dkWidget = rad.desktop.core.dkWidget;
  dkDashboard = rad.desktop.core.dkDashboard;
  gsBox = rad.desktop.core.gsBox;
  gsFolder = rad.desktop.core.gsFolder;
  dsSmall = rad.desktop.core.dsSmall;
  dsWide = rad.desktop.core.dsWide;
  dsLarge = rad.desktop.core.dsLarge;
  dtNone = rad.desktop.widgets.dtNone;
  dtUp = rad.desktop.widgets.dtUp;
  dtDown = rad.desktop.widgets.dtDown;
  tkDark = rad.desktop.paint.tkDark;
  tkLight = rad.desktop.paint.tkLight;
  deAuto = rad.desktop.view.deAuto;
  deFull = rad.desktop.view.deFull;
  deReduced = rad.desktop.view.deReduced;

type
  /// <summary>Wires one desktop view: commands, widgets, permission and debounced persistence.</summary>
  TRadDesktop = class abstract
  private
    class var FView: TRADDesktopView;
    class var FStore: TRadDeskStore;
    class var FCommands: TRadDeskCommands;
    class var FWidgets: TRadDeskWidgets;
    class var FActions: TRadDeskActionSource;
    class var FActionsRef: IRadDeskCommandSource;
    class var FTimer: TTimer;
    class var FDirty: Boolean;
    class procedure ViewChanged(Sender: TObject);
    class procedure TimerFired(Sender: TObject);
    class procedure ResetRequested(Sender: TObject);
    class procedure SaveAsBaseRequested(Sender: TObject);
    class procedure CheckReady; static;
  public
    const SaveDelayMs = 1500;
    /// <summary>Binds AView, loads the company and user layers and starts widgets.</summary>
    /// <param name="ARepository">Not owned; must outlive the desktop (until Kapat).</param>
    class procedure Kur(AView: TRADDesktopView; ARepository: TRadStateRepository; const AUser: string); static;
    /// <summary>Adds a command source; a source with the same prefix is replaced.</summary>
    class procedure Ekle(const ASource: IRadDeskCommandSource); static;
    /// <summary>Adds the actions of AList under the 'act:' prefix.</summary>
    class procedure EkleAksiyonlar(AList: TCustomActionList); static;
    /// <summary>Adds the clickable leaves of AMenu under the 'menu:' prefix.</summary>
    class procedure EkleMenu(AMenu: TMenu); static;
    class procedure EkleWidget(const AProvider: IRadDeskWidgetProvider); static;
    /// <summary>Permission asked for every shortcut on every paint and before every execute.</summary>
    class procedure Izin(const AAllow: TRadDeskAllowFunc); static;
    /// <summary>Writes a pending change now.</summary>
    class procedure Kaydet; static;
    /// <summary>Deletes the user's layout and shows the company layer.</summary>
    class procedure Sifirla; static;
    /// <summary>Saves the current layout as the company layer (administrators).</summary>
    class procedure VarsayilanYap; static;
    /// <summary>Writes a pending change and releases everything; the view stays as it is.</summary>
    class procedure Kapat; static;
    class function Hazir: Boolean; static;
    class property View: TRADDesktopView read FView;
    class property Commands: TRadDeskCommands read FCommands;
    class property Widgets: TRadDeskWidgets read FWidgets;
    class property Store: TRadDeskStore read FStore;
  end;

implementation

class procedure TRadDesktop.CheckReady;
begin
  if not Hazir then
    raise ERadDesktop.Create('TRadDesktop.Kur was not called');
end;

class function TRadDesktop.Hazir: Boolean;
begin
  Result := Assigned(FView) and Assigned(FStore);
end;

class procedure TRadDesktop.Kur(AView: TRADDesktopView; ARepository: TRadStateRepository; const AUser: string);
begin
  if not Assigned(AView) then
    raise EArgumentNilException.Create('AView');
  if Hazir then
    Kapat;
  FStore := TRadDeskStore.Create(ARepository, AUser);
  FCommands := TRadDeskCommands.Create;
  FWidgets := TRadDeskWidgets.Create;
  FWidgets.Add(TRadDeskClockWidget.Create);
  FTimer := TTimer.Create(nil);
  FTimer.Enabled := False;
  FTimer.Interval := SaveDelayMs;
  FTimer.OnTimer := TimerFired;
  FView := AView;
  FView.Commands := FCommands;
  FView.Widgets := FWidgets;
  FView.OnChange := ViewChanged;
  FView.OnResetLayout := ResetRequested;
  FView.OnSaveAsBase := SaveAsBaseRequested;
  FStore.Load(FView.Layout);
  FView.Rebuild;
  FView.RefreshAllWidgets;
end;

class procedure TRadDesktop.Ekle(const ASource: IRadDeskCommandSource);
begin
  CheckReady;
  FCommands.Add(ASource);
  FView.Rebuild;
end;

class procedure TRadDesktop.EkleAksiyonlar(AList: TCustomActionList);
begin
  CheckReady;
  if not Assigned(FActions) then
  begin
    FActions := TRadDeskActionSource.Create;
    FActionsRef := FActions;
    FCommands.Add(FActionsRef);
  end;
  FActions.AddList(AList);
  FView.Rebuild;
end;

class procedure TRadDesktop.EkleMenu(AMenu: TMenu);
begin
  Ekle(TRadDeskMenuSource.Create(AMenu));
end;

class procedure TRadDesktop.EkleWidget(const AProvider: IRadDeskWidgetProvider);
begin
  CheckReady;
  FWidgets.Add(AProvider);
  FView.Rebuild;
  FView.RefreshAllWidgets;
end;

class procedure TRadDesktop.Izin(const AAllow: TRadDeskAllowFunc);
begin
  CheckReady;
  FCommands.Allow := AAllow;
  FView.Rebuild;
end;

class procedure TRadDesktop.ViewChanged(Sender: TObject);
begin
  FDirty := True;
  FTimer.Enabled := False;
  FTimer.Enabled := True;
end;

class procedure TRadDesktop.TimerFired(Sender: TObject);
begin
  Kaydet;
end;

class procedure TRadDesktop.Kaydet;
begin
  if not Hazir then
    Exit;
  FTimer.Enabled := False;
  if FDirty then
    FStore.SaveUser(FView.Layout);
  FDirty := False;
end;

class procedure TRadDesktop.Sifirla;
begin
  CheckReady;
  FTimer.Enabled := False;
  FDirty := False;
  FStore.ResetUser;
  FView.CloseFolder;
  FStore.Load(FView.Layout);
  FView.Rebuild;
  FView.RefreshAllWidgets;
end;

class procedure TRadDesktop.ResetRequested(Sender: TObject);
begin
  Sifirla;
end;

class procedure TRadDesktop.VarsayilanYap;
begin
  CheckReady;
  FStore.SaveBase(FView.Layout);
  FDirty := True;
  Kaydet;
end;

class procedure TRadDesktop.SaveAsBaseRequested(Sender: TObject);
begin
  VarsayilanYap;
end;

class procedure TRadDesktop.Kapat;
begin
  Kaydet;
  if Assigned(FView) then
  begin
    FView.OnChange := nil;
    FView.OnResetLayout := nil;
    FView.OnSaveAsBase := nil;
    FView.Commands := nil;
    FView.Widgets := nil;
  end;
  FView := nil;
  FreeAndNil(FTimer);
  FActionsRef := nil;
  FActions := nil;
  FreeAndNil(FCommands);
  FreeAndNil(FWidgets);
  FreeAndNil(FStore);
  FDirty := False;
end;

end.
