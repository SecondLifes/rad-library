unit rad.tms.formtabs;

{ Her TForm (MDI olsun olmasin) TMS sekme cubugunda bir sekme olur.
  Pencereler bagimsiz kalir, bu yuzden coklu monitorde calisir. }

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.Generics.Collections,
  Vcl.Controls, Vcl.Forms,
  AdvOfficeTabSet, Help.vcl;

type
  TRadFormTabs = class;

  /// <summary>Formun sekme olup olmayacagina son soz; AAccept varsayilan ilkeyle gelir.</summary>
  TRadAcceptFormEvent = procedure(Sender: TObject; AForm: TForm;
    var AAccept: Boolean) of object;

  /// <summary>Formun WindowProc'una takilip sekme cubuguna haber verir.</summary>
  TRadFormTabLink = class(TWinControlHook)
  strict private
    FAttached: Boolean;
    FForm: TForm;
    FTabs: TRadFormTabs;
  protected
    procedure DoWndProc(var Msg: TMessage); override;
  public
    constructor CreateLink(ATabs: TRadFormTabs; AForm: TForm);
    destructor Destroy; override;
    procedure Disconnect;
    property Attached: Boolean read FAttached write FAttached;
    property Form: TForm read FForm;
  end;

  TRadFormTabs = class(TAdvOfficeTabSet)
  strict private
    FAutoAttach: Boolean;
    FCloseQueue: TList<TForm>;
    FHideInactive: Boolean;
    FLinks: TDictionary<Pointer, TRadFormTabLink>;
    FOnAcceptForm: TRadAcceptFormEvent;
    FSyncing: Integer;
    procedure DoDeferredClose;
    procedure FormEvent(const AControl: TForm; const AEvent: TFormEventType);
    procedure HideOthers(AKeep: TForm);
    function HostForm: TCustomForm;
    procedure RemoveTab(AForm: TForm);
    procedure SelectTab(AItem: TOfficeTabCollectionItem);
    procedure SetAutoAttach(const Value: Boolean);
  private
    procedure LinkActivated(ALink: TRadFormTabLink);
    procedure LinkCaptionChanged(ALink: TRadFormTabLink);
    procedure LinkDestroyed(ALink: TRadFormTabLink);
    procedure LinkVisibleChanged(ALink: TRadFormTabLink; AVisible: Boolean);
  protected
    procedure ChangeActiveTab(TabIndex: Integer); override;
    function CanCloseTab(TabIndex: Integer; var CloseAction: TCloseAction): Boolean; override;
    /// <summary>Varsayilan ilke. TRadFormBase icin ShowInTabs, digerleri icin gorunur/normal/boyutlandirilabilir.</summary>
    function IsAcceptable(AForm: TForm): Boolean; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>AForm icin sekme acar; varsa mevcut olani dondurur.</summary>
    function Attach(AForm: TForm): TOfficeTabCollectionItem;
    /// <summary>Sekmeyi kaldirir; form kapanmaz.</summary>
    procedure Detach(AForm: TForm);
    /// <summary>Ilkeye uyuyorsa baglar (AutoAttach yolu).</summary>
    procedure AutoAttachForm(AForm: TForm);
    /// <summary>Formu one getirir, sekmesini secer.</summary>
    procedure ActivateForm(AForm: TForm);
    function TabOf(AForm: TForm): TOfficeTabCollectionItem;
    function FormOf(ATabIndex: Integer): TForm;
  published
    property AutoAttach: Boolean read FAutoAttach write SetAutoAttach default False;
    /// <summary>True: etkin olmayan formlar gizlenir. Coklu monitorde False birakin.</summary>
    property HideInactive: Boolean read FHideInactive write FHideInactive default False;
    property OnAcceptForm: TRadAcceptFormEvent read FOnAcceptForm write FOnAcceptForm;
  end;

implementation

type
  { Screen.OnActiveFormChange tek yayinlidir; burada bir kez alinip dagitilir. }
  TRadFormTabsHub = class
  strict private
    class var FInstance: TRadFormTabsHub;
    var
      FInstalled: Boolean;
      FPrev: TNotifyEvent;
      FTabs: TList<TRadFormTabs>;
    procedure ActiveFormChange(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    class procedure Subscribe(ATabs: TRadFormTabs);
    class procedure Unsubscribe(ATabs: TRadFormTabs);
    class procedure Release;
  end;

{ TRadFormTabsHub }

constructor TRadFormTabsHub.Create;
begin
  inherited Create;
  FTabs := TList<TRadFormTabs>.Create;
end;

destructor TRadFormTabsHub.Destroy;
begin
  if FInstalled and (TMethod(Screen.OnActiveFormChange).Data = Pointer(Self)) then
    Screen.OnActiveFormChange := FPrev;
  FTabs.Free;
  inherited;
end;

procedure TRadFormTabsHub.ActiveFormChange(Sender: TObject);
var
  LTabs: TRadFormTabs;
begin
  if Assigned(FPrev) then
    FPrev(Sender);
  if Screen.ActiveForm is TForm then
    for LTabs in FTabs.ToArray do
      LTabs.AutoAttachForm(TForm(Screen.ActiveForm));
end;

class procedure TRadFormTabsHub.Subscribe(ATabs: TRadFormTabs);
begin
  if FInstance = nil then
    FInstance := TRadFormTabsHub.Create;
  if FInstance.FTabs.IndexOf(ATabs) < 0 then
    FInstance.FTabs.Add(ATabs);
  if not FInstance.FInstalled then
  begin
    FInstance.FPrev := Screen.OnActiveFormChange;
    Screen.OnActiveFormChange := FInstance.ActiveFormChange;
    FInstance.FInstalled := True;
  end;
end;

class procedure TRadFormTabsHub.Unsubscribe(ATabs: TRadFormTabs);
begin
  { Dinleyici yuklu kalir (bos listeyle yalniz zincirler): baskasi ustune yazsa bile sarkan isaretci olmaz. }
  if FInstance <> nil then
    FInstance.FTabs.Remove(ATabs);
end;

class procedure TRadFormTabsHub.Release;
begin
  FreeAndNil(FInstance);
end;

{ TRadFormTabLink }

constructor TRadFormTabLink.CreateLink(ATabs: TRadFormTabs; AForm: TForm);
begin
  inherited Create(AForm);
  FTabs := ATabs;
  FForm := AForm;
end;

destructor TRadFormTabLink.Destroy;
begin
  if FTabs <> nil then
    FTabs.LinkDestroyed(Self);
  inherited;
end;

procedure TRadFormTabLink.Disconnect;
begin
  FTabs := nil;
end;

procedure TRadFormTabLink.DoWndProc(var Msg: TMessage);
begin
  inherited DoWndProc(Msg);
  if (FTabs = nil) or not FAttached then
    Exit;
  case Msg.Msg of
    CM_ACTIVATE:       FTabs.LinkActivated(Self);
    CM_TEXTCHANGED:    FTabs.LinkCaptionChanged(Self);
    CM_VISIBLECHANGED: FTabs.LinkVisibleChanged(Self, Msg.WParam <> 0);
  end;
end;

{ TRadFormTabs }

constructor TRadFormTabs.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLinks := TDictionary<Pointer, TRadFormTabLink>.Create;
  FCloseQueue := TList<TForm>.Create;
end;

destructor TRadFormTabs.Destroy;
var
  LLink: TRadFormTabLink;
begin
  TRadFormTabsHub.Unsubscribe(Self);
  if Assigned(GlobalFormFactory) then
    GlobalFormFactory.RemoveListener(FormEvent);
  TThread.RemoveQueuedEvents(DoDeferredClose);
  for LLink in FLinks.Values.ToArray do
  begin
    LLink.Disconnect;
    LLink.Free;
  end;
  FLinks.Free;
  FCloseQueue.Free;
  inherited;
end;

function TRadFormTabs.HostForm: TCustomForm;
begin
  Result := GetParentForm(Self);
end;

function TRadFormTabs.IsAcceptable(AForm: TForm): Boolean;
begin
  Result := False;
  if (AForm = nil) or (csDestroying in AForm.ComponentState) or not AForm.Visible or
     (AForm = HostForm) or (AForm = Application.MainForm) or (fsModal in AForm.FormState) then
    Exit;
  if AForm is TRadFormBase then
    Result := TRadFormBase(AForm).ShowInTabs
  else
    Result := (AForm.FormStyle in [fsNormal, fsMDIChild]) and
      (AForm.BorderStyle in [bsSizeable, bsSingle]);
  if Assigned(FOnAcceptForm) then
    FOnAcceptForm(Self, AForm, Result);
end;

function TRadFormTabs.TabOf(AForm: TForm): TOfficeTabCollectionItem;
var
  i: Integer;
begin
  Result := nil;
  if AForm = nil then
    Exit;
  for i := 0 to AdvOfficeTabs.Count - 1 do
    if AdvOfficeTabs[i].TabObject = TObject(AForm) then
      Exit(AdvOfficeTabs[i]);
end;

function TRadFormTabs.FormOf(ATabIndex: Integer): TForm;
var
  LForm: TForm;
begin
  Result := nil;
  if (ATabIndex < 0) or (ATabIndex >= AdvOfficeTabs.Count) then
    Exit;
  LForm := TForm(AdvOfficeTabs[ATabIndex].TabObject);
  { Baskasinin sekmesine dokunmamak icin once kendi kaydimiza bak. }
  if FLinks.ContainsKey(Pointer(LForm)) then
    Result := LForm;
end;

function TRadFormTabs.Attach(AForm: TForm): TOfficeTabCollectionItem;
var
  LLink: TRadFormTabLink;
begin
  Result := nil;
  if (AForm = nil) or (csDestroying in AForm.ComponentState) or
     (csDestroying in ComponentState) or (AForm = HostForm) then
    Exit;
  Result := TabOf(AForm);
  if Result <> nil then
    Exit;
  if not FLinks.TryGetValue(Pointer(AForm), LLink) then
  begin
    LLink := TRadFormTabLink.CreateLink(Self, AForm);
    FLinks.Add(Pointer(AForm), LLink);
  end;
  LLink.Attached := True;
  Inc(FSyncing);
  try
    Result := AdvOfficeTabs.Add;
    Result.Caption := AForm.Caption;
    Result.TabObject := AForm;
    if Screen.ActiveForm = AForm then
      SelectTab(Result);
  finally
    Dec(FSyncing);
  end;
end;

procedure TRadFormTabs.RemoveTab(AForm: TForm);
var
  LItem: TOfficeTabCollectionItem;
begin
  if csDestroying in ComponentState then
    Exit;
  LItem := TabOf(AForm);
  if LItem <> nil then
    AdvOfficeTabs.Delete(LItem.Index);
end;

procedure TRadFormTabs.Detach(AForm: TForm);
var
  LLink: TRadFormTabLink;
begin
  if FLinks.TryGetValue(Pointer(AForm), LLink) then
    LLink.Attached := False;
  RemoveTab(AForm);
end;

procedure TRadFormTabs.AutoAttachForm(AForm: TForm);
begin
  if FAutoAttach and (TabOf(AForm) = nil) and IsAcceptable(AForm) then
    Attach(AForm);
end;

procedure TRadFormTabs.SelectTab(AItem: TOfficeTabCollectionItem);
begin
  if (AItem = nil) or (ActiveTabIndex = AItem.Index) then
    Exit;
  Inc(FSyncing);
  try
    ActiveTabIndex := AItem.Index;
  finally
    Dec(FSyncing);
  end;
end;

procedure TRadFormTabs.HideOthers(AKeep: TForm);
var
  LLink: TRadFormTabLink;
begin
  for LLink in FLinks.Values.ToArray do
    if LLink.Attached and (LLink.Form <> AKeep) and LLink.Form.Visible and
       (LLink.Form.FormStyle <> fsMDIChild) then
      LLink.Form.Hide;
end;

procedure TRadFormTabs.ActivateForm(AForm: TForm);
var
  LClient: HWND;
begin
  if (AForm = nil) or (csDestroying in AForm.ComponentState) then
    Exit;
  Inc(FSyncing);   // Show/Hide/aktivasyon geri bildirimleri yok sayilir
  try
    SelectTab(TabOf(AForm));
    if FHideInactive then
      HideOthers(AForm);
    if not AForm.Visible then
      AForm.Show;
    if AForm.FormStyle = fsMDIChild then
    begin
      LClient := GetParent(AForm.Handle);   // MDI cocugun ust penceresi MDICLIENT
      if IsIconic(AForm.Handle) then
        SendMessage(LClient, WM_MDIRESTORE, WPARAM(AForm.Handle), 0)
      else
        SendMessage(LClient, WM_MDIACTIVATE, WPARAM(AForm.Handle), 0);
    end
    else
    begin
      if AForm.WindowState = wsMinimized then
        AForm.WindowState := wsNormal;
      AForm.BringToFront;
      if AForm.CanFocus then
        AForm.SetFocus;
    end;
  finally
    Dec(FSyncing);
  end;
end;

procedure TRadFormTabs.ChangeActiveTab(TabIndex: Integer);
var
  LOld: Integer;
begin
  LOld := ActiveTabIndex;
  inherited;
  if (FSyncing = 0) and not (csDestroying in ComponentState) and
     (ActiveTabIndex = TabIndex) and (TabIndex <> LOld) then
    ActivateForm(FormOf(TabIndex));
end;

function TRadFormTabs.CanCloseTab(TabIndex: Integer; var CloseAction: TCloseAction): Boolean;
var
  LForm: TForm;
begin
  Result := inherited CanCloseTab(TabIndex, CloseAction);   // OnTabClose burada
  LForm := FormOf(TabIndex);
  if Result and (LForm <> nil) then
  begin
    Result := False;   // sekmeyi TMS silmesin; form kapaninca baglanti siler
    if not FCloseQueue.Contains(LForm) then
      FCloseQueue.Add(LForm);
    { Kapatma ertelenir: sekme kendi dugmesinin tiklama isleyicisinde silinmesin. }
    TThread.ForceQueue(nil, DoDeferredClose);
  end;
end;

procedure TRadFormTabs.DoDeferredClose;
var
  LForm: TForm;
begin
  while FCloseQueue.Count > 0 do
  begin
    LForm := FCloseQueue[0];
    FCloseQueue.Delete(0);
    if FLinks.ContainsKey(Pointer(LForm)) then   // bu arada yok olmadiysa
      LForm.Close;
  end;
end;

procedure TRadFormTabs.FormEvent(const AControl: TForm; const AEvent: TFormEventType);
begin
  if AEvent = fetShow then
    AutoAttachForm(AControl);
end;

procedure TRadFormTabs.LinkActivated(ALink: TRadFormTabLink);
begin
  if FSyncing > 0 then
    Exit;
  Inc(FSyncing);
  try
    SelectTab(TabOf(ALink.Form));
    if FHideInactive then
      HideOthers(ALink.Form);
  finally
    Dec(FSyncing);
  end;
end;

procedure TRadFormTabs.LinkCaptionChanged(ALink: TRadFormTabLink);
var
  LItem: TOfficeTabCollectionItem;
begin
  LItem := TabOf(ALink.Form);
  if LItem <> nil then
    LItem.Caption := ALink.Form.Caption;
end;

procedure TRadFormTabs.LinkVisibleChanged(ALink: TRadFormTabLink; AVisible: Boolean);
begin
  { Biz gizlediysek (HideInactive) sekme kalir; kod/kullanici gizlediyse gider. }
  if (FSyncing = 0) and not AVisible then
    Detach(ALink.Form);
end;

procedure TRadFormTabs.LinkDestroyed(ALink: TRadFormTabLink);
begin
  FLinks.Remove(Pointer(ALink.Form));
  if ALink.Attached then
    RemoveTab(ALink.Form);   // yalniz isaretci karsilastirir
end;

procedure TRadFormTabs.SetAutoAttach(const Value: Boolean);
begin
  if FAutoAttach = Value then
    Exit;
  FAutoAttach := Value;
  if csDesigning in ComponentState then
    Exit;
  if Value then
  begin
    TRadFormTabsHub.Subscribe(Self);
    if Assigned(GlobalFormFactory) then
      GlobalFormFactory.AddListener(FormEvent);
  end
  else
  begin
    TRadFormTabsHub.Unsubscribe(Self);
    if Assigned(GlobalFormFactory) then
      GlobalFormFactory.RemoveListener(FormEvent);
  end;
end;

initialization

finalization
  TRadFormTabsHub.Release;

end.
