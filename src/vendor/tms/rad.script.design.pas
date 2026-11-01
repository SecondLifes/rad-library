unit rad.script.design;

(* Script sistemi 5. aşama: tasarım oturumu. İki kip: mevcut ERP formunu özelleştirme (özellik farkı →
   <Sınıf>.duzen.json + <Sınıf>.<Yerleşim>.layout) ve `pencere` script'inin DFM'ini tasarlama (TMS
   TIDEFormDesigner + palet). Araç çubuğu ve özellik penceresi DFM'de (rad.script.design.bar / .tools).
   Bkz. docs/specs/rad.script.designer.md *)

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.Types,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls,
  atScript, idemain, FormDesigner, componentinspector,
  mormot.core.base,
  rad.script, rad.script.override, rad.script.engine, rad.script.hooks,
  rad.script.design.bar, rad.script.design.tools;

type
  TRadScriptDesignMode = (dmForm, dmWindow);

  /// Tek etkin oturum (Active). Start/StartWindow açar; Kaydet/Vazgeç/Kapat düğmeleri ya da metotlar bitirir.
  TRadScriptDesigner = class(TComponent)
  private
    class var FActive: TRadScriptDesigner;
    class var FPalette: TList<TPair<string, TComponentClass>>;
    class constructor Create;
    class destructor Destroy;
  private
    FMode: TRadScriptDesignMode;
    FStore: IRadScriptStore;
    FForm: TCustomForm;
    FOwnForm: Boolean;
    FPackage: TRadScriptPackage;
    FScript: TRadScript;
    FEngine: TIDEEngine;
    FDesigner: TIDEFormDesigner;
    FBar: TRadScriptDesignBar;
    FTools: TRadScriptDesignTools;
    FSnapshot: TRadPropSnapshot;
    FCustomizing: Boolean;
    FClosing: Boolean;
    FOnClosed: TProc<TObject>;
    FOnMessage: TProc<string>;
    procedure Open;
    procedure BuildUi;
    procedure DesignerKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure DesignerSelectionChange(Sender: TObject);
    procedure BarClick(Sender: TObject);
    procedure ModeClick(Sender: TObject);
    function LayoutControls: TArray<TComponent>;
    function IsLayoutChild(AComponent: TComponent): Boolean;
    procedure SaveForm;
    procedure SaveWindow;
    function WindowDfm: string;
    function CheckWindow(const ADfm: string): string;
    procedure Say(const AMsg: string);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    destructor Destroy; override;
    /// Açık ERP formunda tasarım; paket TRadScriptBinder.Store'dan yüklenir (korumalı paket reddedilir).
    class function Start(AForm: TCustomForm; const APackageCode: string): TRadScriptDesigner; static;
    /// `pencere` script'inin formunu tasarlar; DFM kaynağı varsa yüklenir, yoksa boş form.
    class function StartWindow(const APackageCode, AScriptCode: string): TRadScriptDesigner; static;
    /// DFM metnindeki `OnX = Rutin` satırlarını söker, `Bileşen.OnX=Rutin` listesi döner (kök = Self). TMS tasarımcısı
    /// olayları DFM satırı olarak değil TScriptForm.SaveEvents'te tutar; çalışma zamanı yükleyicisi ikisini de bağlar.
    class function ExtractDfmEvents(var ADfm: string): TArray<string>; static;
    /// Pencere paleti sayfası + sınıf (DFM'den okunabilmesi için Classes.RegisterClass de yapılır).
    class procedure RegisterPaletteClass(const APage: string; AClass: TComponentClass); static;
    /// Kayıtlı paleti bir IDE motoruna yazar (IDE'nin pencere tasarımcısı da aynı listeyi görür).
    class procedure RegisterPaletteInto(AEngine: TIDEEngine); static;
    class property Active: TRadScriptDesigner read FActive;
    /// Form kipi: fark + yerleşim akışları pakete; pencere kipi: DFM pakete. Store.SavePackage.
    procedure Save;
    /// Form kipi: değişen özellikler ilk değere döner. Oturum açık kalır.
    procedure Cancel;
    /// Tasarımcıyı söker; form normal çalışır. Nesne kendini serbest bırakır.
    procedure Close;
    /// Form kipi: adlı TdxLayoutControl'lerin Customization kipini açar/kapar.
    procedure ToggleLayout;
    procedure Select(AComponent: TComponent);
    /// İlk anlık görüntüye göre şu anki fark (yerleşim gürültüsü ayıklanmış). Sahiplik çağırana.
    function Changes: TRadPropSnapshot;
    property Mode: TRadScriptDesignMode read FMode;
    property Form: TCustomForm read FForm;
    property Package: TRadScriptPackage read FPackage;
    property Script: TRadScript read FScript;
    property IdeEngine: TIDEEngine read FEngine;
    property Customizing: Boolean read FCustomizing;
    property OnClosed: TProc<TObject> read FOnClosed write FOnClosed;
    /// Uyarı/bilgi metinleri; nil → TRadScriptBinder.OnWarning.
    property OnMessage: TProc<string> read FOnMessage write FOnMessage;
  end;

implementation

uses
  System.StrUtils, System.TypInfo, System.RegularExpressions, Winapi.Windows, Vcl.Dialogs,
  Data.DB, Uni,
  cxButtons, cxTextEdit, cxMemo, cxDropDownEdit, cxCalendar, cxCurrencyEdit, cxCheckBox, cxLabel,
  dxLayoutControl;

resourcestring
  SErrNoStore = 'TRadScriptBinder.Store atanmadan tasarım açılamaz.';
  SErrActive = 'Zaten açık bir tasarım oturumu var.';
  SErrNoPackage = 'Paket bulunamadı: %s';
  SErrProtected = 'Korumalı paket tasarlanamaz: %s';
  SErrNoScript = 'Paket %s içinde pencere script''i yok: %s';
  SWarnEvent = '%s: DFM''deki "%s = %s" için script''te alt program yok.';
  SWarnCompile = 'Pencere derlenemedi (kayıt yine yapıldı): %s';
  SSaved = 'Kaydedildi: %s';
  BAR_PAGE_STD = 'Standart';
  BAR_PAGE_DEV = 'DevExpress';
  BAR_PAGE_DATA = 'Veri';

const
  SIZE_PROPS: array[0..3] of string = ('Left', 'Top', 'Width', 'Height');

{ TRadScriptDesigner }

class constructor TRadScriptDesigner.Create;
begin
  FPalette := TList<TPair<string, TComponentClass>>.Create;
  RegisterPaletteClass(BAR_PAGE_STD, TLabel);
  RegisterPaletteClass(BAR_PAGE_STD, TEdit);
  RegisterPaletteClass(BAR_PAGE_STD, TButton);
  RegisterPaletteClass(BAR_PAGE_STD, TCheckBox);
  RegisterPaletteClass(BAR_PAGE_STD, TComboBox);
  RegisterPaletteClass(BAR_PAGE_STD, TMemo);
  RegisterPaletteClass(BAR_PAGE_STD, TPanel);
  RegisterPaletteClass(BAR_PAGE_STD, TGroupBox);
  RegisterPaletteClass(BAR_PAGE_DEV, TcxButton);
  RegisterPaletteClass(BAR_PAGE_DEV, TcxLabel);
  RegisterPaletteClass(BAR_PAGE_DEV, TcxTextEdit);
  RegisterPaletteClass(BAR_PAGE_DEV, TcxMemo);
  RegisterPaletteClass(BAR_PAGE_DEV, TcxComboBox);
  RegisterPaletteClass(BAR_PAGE_DEV, TcxDateEdit);
  RegisterPaletteClass(BAR_PAGE_DEV, TcxCurrencyEdit);
  RegisterPaletteClass(BAR_PAGE_DEV, TcxCheckBox);
  RegisterPaletteClass(BAR_PAGE_DEV, TdxLayoutControl);
  RegisterPaletteClass(BAR_PAGE_DATA, TDataSource);
  RegisterPaletteClass(BAR_PAGE_DATA, TUniQuery);
end;

class destructor TRadScriptDesigner.Destroy;
begin
  FPalette.Free;
end;

class procedure TRadScriptDesigner.RegisterPaletteClass(const APage: string; AClass: TComponentClass);
begin
  FPalette.Add(TPair<string, TComponentClass>.Create(APage, AClass));
  System.Classes.RegisterClass(AClass);
end;

class procedure TRadScriptDesigner.RegisterPaletteInto(AEngine: TIDEEngine);
var
  P: TPair<string, TComponentClass>;
begin
  AEngine.BeginRegisterComponents;
  try
    for P in FPalette do AEngine.RegisterComponent(P.Key, P.Value);
  finally
    AEngine.EndRegisterComponents;
  end;
end;

class function TRadScriptDesigner.Start(AForm: TCustomForm; const APackageCode: string): TRadScriptDesigner;
begin
  if TRadScriptBinder.Store = nil then raise ERadScript.Create(SErrNoStore);
  if FActive <> nil then raise ERadScript.Create(SErrActive);
  Result := TRadScriptDesigner.Create(nil);
  try
    Result.FMode := dmForm;
    Result.FStore := TRadScriptBinder.Store;
    Result.FForm := AForm;
    Result.FPackage := Result.FStore.LoadPackage(APackageCode);
    if Result.FPackage = nil then raise ERadScript.CreateFmt(SErrNoPackage, [APackageCode]);
    if Result.FPackage.IsProtected then raise ERadScript.CreateFmt(SErrProtected, [APackageCode]);
    Result.Open;
  except
    Result.Free;
    raise;
  end;
end;

class function TRadScriptDesigner.ExtractDfmEvents(var ADfm: string): TArray<string>;
var
  L: TStringList;
  LStack: TStack<string>;
  LOut: TList<string>;
  i: Integer;
  LTrim, LName: string;
  M: TMatch;
begin
  L := TStringList.Create;
  LStack := TStack<string>.Create;
  LOut := TList<string>.Create;
  try
    L.Text := ADfm;
    i := 0;
    while i < L.Count do
    begin
      LTrim := System.SysUtils.Trim(L[i]);
      M := TRegEx.Match(LTrim, '^(object|inherited|inline)\s+(\w+)\s*:', [roIgnoreCase]);
      if M.Success then
      begin
        if LStack.Count = 0 then LName := 'Self' else LName := M.Groups[2].Value;
        LStack.Push(LName);
      end
      else if SameText(LTrim, 'end') then
      begin
        if LStack.Count > 0 then LStack.Pop;
      end
      else
      begin
        M := TRegEx.Match(LTrim, '^(On\w+)\s*=\s*(\w+)$');
        if M.Success and (LStack.Count > 0) then
        begin
          LOut.Add(LStack.Peek + '.' + M.Groups[1].Value + '=' + M.Groups[2].Value);
          L.Delete(i);
          Continue;
        end;
      end;
      Inc(i);
    end;
    ADfm := L.Text;
    Result := LOut.ToArray;
  finally
    LOut.Free;
    LStack.Free;
    L.Free;
  end;
end;

class function TRadScriptDesigner.StartWindow(const APackageCode, AScriptCode: string): TRadScriptDesigner;
var
  LRes: TRadScriptResource;
  LMem: TStringStream;
  LDfm, E: string;
  LEvents: TArray<string>;
  LIntf: IScriptBasedForm;
begin
  if TRadScriptBinder.Store = nil then raise ERadScript.Create(SErrNoStore);
  if FActive <> nil then raise ERadScript.Create(SErrActive);
  Result := TRadScriptDesigner.Create(nil);
  try
    Result.FMode := dmWindow;
    Result.FStore := TRadScriptBinder.Store;
    Result.FPackage := Result.FStore.LoadPackage(APackageCode);
    if Result.FPackage = nil then raise ERadScript.CreateFmt(SErrNoPackage, [APackageCode]);
    if Result.FPackage.IsProtected then raise ERadScript.CreateFmt(SErrProtected, [APackageCode]);
    Result.FScript := Result.FPackage.ScriptByCode(AScriptCode);
    if (Result.FScript = nil) or (Result.FScript.Kind <> skWindow) then
      raise ERadScript.CreateFmt(SErrNoScript, [APackageCode, AScriptCode]);
    Result.FForm := TRadScriptForm.CreateNew(nil);
    Result.FOwnForm := True;
    Result.FForm.Name := AScriptCode + 'Form';
    Result.FForm.Caption := Result.FScript.Name;
    Result.Open;
    LRes := Result.FPackage.ResourceByName(Result.FScript.DfmFileName);
    if LRes <> nil then
    begin
      LDfm := TEncoding.UTF8.GetString(LRes.Content);
      LEvents := ExtractDfmEvents(LDfm);
      LMem := TStringStream.Create(LDfm, TEncoding.UTF8);
      try
        LMem.Position := 0;
        Result.FDesigner.LoadFromStream(LMem, dfmText);
      finally
        LMem.Free;
      end;
      if Supports(Result.FForm, IScriptBasedForm, LIntf) then
        for E in LEvents do
          if LIntf.GetSaveEvents.IndexOfName(Copy(E, 1, System.Pos('=', E) - 1)) < 0 then LIntf.GetSaveEvents.Add(E);
    end;
  except
    Result.Free;
    raise;
  end;
end;

destructor TRadScriptDesigner.Destroy;
begin
  FClosing := True;
  if FActive = Self then FActive := nil;
  FreeAndNil(FDesigner);
  FreeAndNil(FEngine);
  FreeAndNil(FTools);
  FreeAndNil(FBar);
  FSnapshot.Free;
  if FOwnForm then FreeAndNil(FForm);
  FPackage.Free;
  inherited;
end;

procedure TRadScriptDesigner.Open;
begin
  FActive := Self;
  FForm.FreeNotification(Self);
  FForm.Show;
  FEngine := TIDEEngine.Create(Self);
  FEngine.PreventDefaultEventCreation := True;   // kod editörü 6. aşamada
  if FMode = dmWindow then RegisterPaletteInto(FEngine);
  FDesigner := TIDEFormDesigner.Create(FForm);
  FDesigner.FreeNotification(Self);
  FDesigner.OnKeyDown := DesignerKeyDown;
  FDesigner.OnSelectionChange := DesignerSelectionChange;
  if FMode = dmForm then
  begin
    // Mevcut formda: seç ama taşıma/boyut/silme yok (Wolvox LockAll karşılığı).
    FDesigner.LockedInverse := True;
    FDesigner.ProtectedInverse := True;
    FDesigner.ProtectMode := pmLockKeyboard;
    FSnapshot := TRadPropSnapshot.Capture(FForm);
  end;
  FDesigner.Active := True;
  FEngine.FormDesigner := FDesigner;
  BuildUi;
end;

procedure TRadScriptDesigner.BuildUi;
begin
  FBar := TRadScriptDesignBar.Create(Self);
  FBar.lblPaket.Caption := FPackage.Name + ' (' + FPackage.Code + ')';
  FBar.btnYerlesim.Visible := (FMode = dmForm) and (Length(LayoutControls) > 0);
  FBar.btnKaydet.OnClick := BarClick;
  FBar.btnVazgec.OnClick := BarClick;
  FBar.btnKapat.OnClick := BarClick;
  FBar.btnYerlesim.OnClick := BarClick;
  FBar.btnVazgec.Visible := FMode = dmForm;
  FTools := TRadScriptDesignTools.Create(Self);
  FTools.rbOzellik.OnClick := ModeClick;
  FTools.rbOlay.OnClick := ModeClick;
  FTools.rbOlay.Visible := FMode = dmWindow;   // mevcut formda olaylar kancayla değişir
  FTools.pal.Visible := FMode = dmWindow;
  FEngine.Inspector := FTools.insp;
  if FMode = dmWindow then
  begin
    FEngine.PaletteToolbar := FTools.pal;
    FTools.pal.UpdatePalette;
  end;
  FBar.Show;
  FTools.Show;
  Select(FForm);
end;

procedure TRadScriptDesigner.Say(const AMsg: string);
begin
  if Assigned(FOnMessage) then FOnMessage(AMsg)
  else if Assigned(TRadScriptBinder.OnWarning) then TRadScriptBinder.OnWarning(AMsg);
end;

procedure TRadScriptDesigner.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FDesigner) then FDesigner := nil;
  if (Operation = opRemove) and (AComponent = FForm) and not FClosing then
  begin
    FForm := nil;
    FOwnForm := False;
    Close;
  end;
end;

procedure TRadScriptDesigner.DesignerKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (FMode = dmForm) and (Key = VK_DELETE) then Key := 0;   // mevcut formdan bileşen silinmez
end;

procedure TRadScriptDesigner.DesignerSelectionChange(Sender: TObject);
var
  C: TComponent;
begin
  if (FBar = nil) or (FDesigner = nil) then Exit;
  C := FDesigner.Component;
  if C = nil then C := FForm;
  if C = nil then FBar.lblSecili.Caption := ''
  else FBar.lblSecili.Caption := C.Name + ': ' + C.ClassName;
end;

procedure TRadScriptDesigner.ModeClick(Sender: TObject);
begin
  if FTools.rbOlay.Checked then FTools.insp.Mode := imEvents else FTools.insp.Mode := imProperties;
end;

procedure TRadScriptDesigner.BarClick(Sender: TObject);
begin
  if Sender = FBar.btnKaydet then Save
  else if Sender = FBar.btnVazgec then Cancel
  else if Sender = FBar.btnYerlesim then ToggleLayout
  else if Sender = FBar.btnKapat then
    TThread.ForceQueue(nil, procedure begin Close; end);   // düğmenin sahibi de yıkılacak: tıklama bitince
end;

procedure TRadScriptDesigner.Select(AComponent: TComponent);
begin
  if FEngine <> nil then FEngine.SelectedComponent := AComponent;
  DesignerSelectionChange(nil);
end;

function TRadScriptDesigner.LayoutControls: TArray<TComponent>;
var
  i: Integer;
  L: TList<TComponent>;
  H: TRadLayoutHandler;
begin
  L := TList<TComponent>.Create;
  try
    if FForm <> nil then
      for i := 0 to FForm.ComponentCount - 1 do
        if (FForm.Components[i].Name <> '') and TRadScriptBinder.LayoutHandlerOf(FForm.Components[i], H) then
          L.Add(FForm.Components[i]);
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

function TRadScriptDesigner.IsLayoutChild(AComponent: TComponent): Boolean;
var
  P: TWinControl;
  H: TRadLayoutHandler;
begin
  Result := False;
  if not (AComponent is TControl) then Exit;
  P := TControl(AComponent).Parent;
  while P <> nil do
  begin
    if TRadScriptBinder.LayoutHandlerOf(P, H) then Exit(True);
    P := P.Parent;
  end;
end;

function TRadScriptDesigner.Changes: TRadPropSnapshot;
var
  LNow: TRadPropSnapshot;
  LKey, LComp, LProp, V: string;
  LDot: Integer;
  C: TComponent;
  LDrop: Boolean;
begin
  if FSnapshot = nil then Exit(TRadPropSnapshot.Create);
  LNow := TRadPropSnapshot.Capture(FForm);
  try
    Result := TRadPropSnapshot.Diff(FSnapshot, LNow);
  finally
    LNow.Free;
  end;
  // Gürültü: pencere konumu ve yerleşimin yönettiği kontrollerin konum/boyutu kullanıcı işi değildir.
  for LKey in Result.Keys.ToArray do
  begin
    LDot := LKey.LastIndexOf('.');
    LComp := LKey.Substring(0, LKey.IndexOf('.'));
    LProp := LKey.Substring(LDot + 1);
    // DevExpress'in AssignedValues defteri kullanıcı değeri değil; düzen dosyasına girmez.
    LDrop := LKey.Contains('.AssignedValues');
    if not LDrop and MatchText(LProp, SIZE_PROPS) and (LKey.CountChar('.') = 1) then
    begin
      if SameText(LComp, TRadPropSnapshot.FORM_KEY) then LDrop := MatchText(LProp, ['Left', 'Top'])
      else
      begin
        C := FForm.FindComponent(LComp);
        LDrop := (C <> nil) and IsLayoutChild(C);
      end;
    end;
    if LDrop then Result.Remove(LKey);
  end;
  if Result.TryGetValue(TRadPropSnapshot.FORM_KEY + '.ActiveControl', V) then Result.Remove(TRadPropSnapshot.FORM_KEY + '.ActiveControl');
end;

procedure TRadScriptDesigner.Cancel;
var
  LDiff: TRadPropSnapshot;
  LKey, LOld: string;
  LObj: TObject;
  LProp: PPropInfo;
begin
  if FMode <> dmForm then Exit;
  LDiff := Changes;
  try
    for LKey in LDiff.Keys do
      if FSnapshot.TryGetValue(LKey, LOld) and TRadPropText.Resolve(FForm, LKey, LObj, LProp) then
        try
          TRadPropText.WriteProp(FForm, LObj, LProp, LOld);
        except
          on E: Exception do Say(LKey + ': ' + E.Message);
        end;
  finally
    LDiff.Free;
  end;
  if FTools <> nil then FTools.insp.Update;
end;

procedure TRadScriptDesigner.ToggleLayout;
var
  C: TComponent;
  H: TRadLayoutHandler;
begin
  if FMode <> dmForm then Exit;
  FCustomizing := not FCustomizing;
  for C in LayoutControls do
    if TRadScriptBinder.LayoutHandlerOf(C, H) then H.Customize(C, FCustomizing);
  if FBar <> nil then FBar.btnYerlesim.Caption := IfThen(FCustomizing, 'Yerleşim ✓', 'Yerleşim');
end;

procedure TRadScriptDesigner.SaveForm;
var
  LDiff, LOld: TRadPropSnapshot;
  LName, LCls: string;
  R: TRadScriptResource;
  C: TComponent;
  H: TRadLayoutHandler;
  LMem: TBytesStream;
begin
  LDiff := Changes;
  try
    LName := TRadScriptBinder.OverrideFileName(FForm.ClassName);
    R := FPackage.ResourceByName(LName);
    if R <> nil then
    begin
      // Eski düzen + yeni fark (yeni kazanır): "orijinale döndür" = eski anahtarın değeri de değişince düşer.
      LOld := TRadPropSnapshot.FromJsonBytes(R.Content, LCls);
      try
        LOld.Merge(LDiff);
        R.Content := LOld.ToJsonBytes(FForm.ClassName);
      finally
        LOld.Free;
      end;
    end
    else if LDiff.Count > 0 then
      FPackage.AddResource(LName, LDiff.ToJsonBytes(FForm.ClassName));
  finally
    LDiff.Free;
  end;
  for C in LayoutControls do
    if TRadScriptBinder.LayoutHandlerOf(C, H) then
    begin
      LMem := TBytesStream.Create;
      try
        H.Save(C, LMem);
        LName := TRadScriptBinder.LayoutFileName(FForm.ClassName, C.Name);
        R := FPackage.ResourceByName(LName);
        if R = nil then FPackage.AddResource(LName, Copy(LMem.Bytes, 0, LMem.Size))
        else R.Content := Copy(LMem.Bytes, 0, LMem.Size);
      finally
        LMem.Free;
      end;
    end;
  FStore.SavePackage(FPackage);
  // Kaydedilen = yeni başlangıç: Vazgeç artık buraya döner.
  FSnapshot.Free;
  FSnapshot := TRadPropSnapshot.Capture(FForm);
  Say(Format(SSaved, [FPackage.Code]));
end;

function TRadScriptDesigner.WindowDfm: string;
var
  LMem: TStringStream;
  LFirst: Integer;
begin
  LMem := TStringStream.Create('', TEncoding.UTF8);
  try
    FDesigner.SaveToStream(LMem, dfmText);
    Result := LMem.DataString;
  finally
    LMem.Free;
  end;
  // Kök sınıf adı Delphi sınıfı (TRadScriptForm) olarak yazılır; script'in bildirdiği ad konur.
  LFirst := System.Pos(': ' + FForm.ClassName, Result);
  if LFirst > 0 then
    Result := Copy(Result, 1, LFirst + 1) + 'T' + FScript.Code + 'Form' + Copy(Result, LFirst + 2 + Length(FForm.ClassName), MaxInt);
end;

function TRadScriptDesigner.CheckWindow(const ADfm: string): string;
var
  LEngine: TRadScriptEngine;
  L: TRadScript;
  LRes: TRadScriptResource;
  M: TMatch;
  LNames: TArray<string>;
begin
  Result := '';
  LEngine := TRadScriptEngine.Create;
  try
    for L in FPackage.Scripts do
      if L.Active and (L.Kind in [skLibrary, skWindow]) then
      begin
        LEngine.AddScript(L);
        if L.Kind = skWindow then
        begin
          if L = FScript then LEngine.SetFormResource(L.Code, ADfm)
          else
          begin
            LRes := FPackage.ResourceByName(L.DfmFileName);
            if LRes <> nil then LEngine.SetFormResource(L.Code, TEncoding.UTF8.GetString(LRes.Content));
          end;
        end;
      end;
    try
      LEngine.Compile;
    except
      on E: Exception do Exit(Format(SWarnCompile, [E.Message]));
    end;
    LNames := LEngine.RoutineNames(FScript.Code);
    for M in TRegEx.Matches(ADfm, '(On\w+)\s*=\s*(\w+)') do
      if not MatchText(M.Groups[2].Value, LNames) then
        Result := Result + Format(SWarnEvent, [FScript.Code, M.Groups[1].Value, M.Groups[2].Value]) + sLineBreak;
  finally
    LEngine.Free;
  end;
end;

procedure TRadScriptDesigner.SaveWindow;
var
  LDfm, LWarn: string;
  R: TRadScriptResource;
begin
  LDfm := WindowDfm;
  R := FPackage.ResourceByName(FScript.DfmFileName);
  if R = nil then FPackage.AddResource(FScript.DfmFileName, TEncoding.UTF8.GetBytes(LDfm))
  else R.Content := TEncoding.UTF8.GetBytes(LDfm);
  if System.SysUtils.Trim(FScript.Source) = '' then
    FScript.Source := Format('{$FORM T%sForm, %s}'#13#10'begin'#13#10'end.', [FScript.Code, FScript.DfmFileName]);
  FStore.SavePackage(FPackage);
  Say(Format(SSaved, [FPackage.Code]));
  LWarn := CheckWindow(LDfm);
  if LWarn <> '' then Say(System.SysUtils.Trim(LWarn));
end;

procedure TRadScriptDesigner.Save;
begin
  if FMode = dmForm then SaveForm else SaveWindow;
end;

procedure TRadScriptDesigner.Close;
begin
  if FClosing then Exit;
  FClosing := True;
  if FCustomizing then ToggleLayout;   // kapatırken yerleşim kipi kapanır
  if FDesigner <> nil then FDesigner.Active := False;
  if Assigned(FOnClosed) then FOnClosed(Self);
  Free;
end;

end.
