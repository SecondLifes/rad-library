unit rad.formstate.customize.session;

{ Editing session of TRadFormCustomizer (docs/specs/rad.formcustomizer.md): the TMS form designer on
  the live form, only the allowed controls selectable, nothing switched to csDesigning, and the
  tool window beside it. Registers itself with the customizer when this package is loaded. }

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.Generics.Collections,
  Winapi.Windows,
  Vcl.Controls,
  Vcl.Forms,
  mormot.core.base,
  mormot.core.variants,
  cxVGrid,
  FormDesigner,
  rad.formstate.customizer,
  rad.formstate.customize.tools;

type
  /// <summary>One open customizing session; at most one at a time.</summary>
  TRadFormCustomizeSession = class(TComponent)
  strict private
    class var FActive: TRadFormCustomizeSession;
  private
    FCustomizer: TRadFormCustomizer;
    FForm: TCustomForm;
    FDesigner: TAdvFormDesigner;
    FTools: TRadCustomizeToolsForm;
    FBefore: IDocDict;
    FUndo: TList<TPair<string, IDocDict>>;
    FCurrent: TComponent;
    FCurrentValues: IDocDict;
    FCurrentBounds: TRect;
    FClosing: Boolean;
    procedure EditBehaviour(Sender: TObject; TheComponent: TComponent; var Behaviour: TEditBehaviour);
    procedure DesignerSelectionChange(Sender: TObject);
    procedure DesignerMoveSize(Sender: TObject; TheControl: TControl);
    procedure DesignerGrabs(Sender: TObject; var VisibleGrabs, EnabledGrabs: TGrabPositions);
    procedure DesignerKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure DesignerPopup(Sender: TObject; var Handled: Boolean);
    procedure InspectorChanged(Sender: TObject);
    procedure InspectorEdited(Sender: TObject; ARowProperties: TcxCustomEditorRowProperties);
    procedure ButtonClick(Sender: TObject);
    function IsLayoutChild(AControl: TControl): Boolean;
    procedure RememberCurrent;
    procedure PushIfChanged;
    procedure ShowTarget;
    procedure Refresh;
  protected
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
  public
    constructor CreateFor(ACustomizer: TRadFormCustomizer);
    destructor Destroy; override;
    /// <summary>Opens a session for ACustomizer, or brings the open one forward.</summary>
    class function Open(ACustomizer: TRadFormCustomizer): TRadFormCustomizeSession; static;
    class property Active: TRadFormCustomizeSession read FActive;
    /// <summary>Selects AComponent as a click would; nil clears the selection.</summary>
    procedure Select(AComponent: TComponent);
    /// <summary>Records a change made to the selected component outside the inspector.</summary>
    procedure Changed;
    procedure Undo;
    function CanUndo: Boolean;
    /// <summary>Puts the selected component's allowed properties back to their defaults.</summary>
    procedure ResetSelected;
    procedure ResetAll;
    /// <summary>Saves the user's changes through the customizer, then closes.</summary>
    procedure Save;
    /// <summary>Puts every value back to the session start, then closes.</summary>
    procedure Cancel;
    /// <summary>Closes without saving and deletes the form's saved state, then reopens it.</summary>
    procedure ResetForm;
    procedure Close;
    property Designer: TAdvFormDesigner read FDesigner;
    property Tools: TRadCustomizeToolsForm read FTools;
    property Current: TComponent read FCurrent;
  end;

implementation

uses
  System.UITypes,
  Vcl.Dialogs,
  mormot.core.unicode,
  rad.script.hooks,
  rad.formstate;

resourcestring
  SNotAForm = 'TRadFormCustomizer %s: its owner must be a form.';
  SPickControl = 'Bir kontrol se'#231'in';
  SConfirmResetForm = 'Bu formdaki t'#252'm ki'#351'isel ayarlar silinecek ve form yeniden a'#231#305'lacak. Devam edilsin mi?';

{ TRadFormCustomizeSession }

class function TRadFormCustomizeSession.Open(ACustomizer: TRadFormCustomizer): TRadFormCustomizeSession;
begin
  if FActive <> nil then
  begin
    FActive.FTools.Show;
    Exit(FActive);
  end;
  Result := TRadFormCustomizeSession.CreateFor(ACustomizer);
end;

constructor TRadFormCustomizeSession.CreateFor(ACustomizer: TRadFormCustomizer);
begin
  inherited Create(nil);
  if not (ACustomizer.Owner is TCustomForm) then
    raise EInvalidOperation.CreateFmt(SNotAForm, [ACustomizer.Name]);
  FActive := Self;
  FCustomizer := ACustomizer;
  FCustomizer.FreeNotification(Self);
  FForm := TCustomForm(ACustomizer.Owner);
  FForm.FreeNotification(Self);
  FUndo := TList<TPair<string, IDocDict>>.Create;
  FBefore := FCustomizer.SnapshotAll;
  FDesigner := TAdvFormDesigner.Create(FForm);
  FDesigner.FreeNotification(Self);
  FDesigner.ShowNonVisual := False;     // stores and datasets are not the user's business
  FDesigner.ProtectMode := pmUnselect;
  FDesigner.MultiSelect := False;       // the inspector shows one object
  FDesigner.SnapToGrid := True;
  FDesigner.GridStep := FCustomizer.GridStep;
  FDesigner.OnEditBehaviour := EditBehaviour;
  FDesigner.OnSelectionChange := DesignerSelectionChange;
  FDesigner.OnMoveSizeControl := DesignerMoveSize;
  FDesigner.OnCustomizeGrabs := DesignerGrabs;
  FDesigner.OnKeyDown := DesignerKeyDown;
  FDesigner.OnContextPopup := DesignerPopup;
  FDesigner.Active := True;
  FTools := TRadCustomizeToolsForm.Create(Self);
  FTools.insp.OnPropertyChanged := InspectorChanged;
  FTools.insp.OnEdited := InspectorEdited;
  FTools.btnUndo.OnClick := ButtonClick;
  FTools.btnResetSelected.OnClick := ButtonClick;
  FTools.btnResetAll.OnClick := ButtonClick;
  FTools.btnResetForm.OnClick := ButtonClick;
  FTools.btnCancel.OnClick := ButtonClick;
  FTools.btnSave.OnClick := ButtonClick;
  FTools.PlaceBeside(FForm);
  ShowTarget;
  FTools.Show;
end;

destructor TRadFormCustomizeSession.Destroy;
begin
  if FActive = Self then
    FActive := nil;
  FUndo.Free;
  inherited;
end;

procedure TRadFormCustomizeSession.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited;
  if AOperation <> opRemove then
    Exit;
  if AComponent = FDesigner then
    FDesigner := nil;
  if (AComponent = FForm) or (AComponent = FCustomizer) then
  begin
    FForm := nil;
    FCustomizer := nil;
    FCurrent := nil;
    if not FClosing then
      Close;
  end
  else if AComponent = FCurrent then
    FCurrent := nil;
end;

function TRadFormCustomizeSession.IsLayoutChild(AControl: TControl): Boolean;
var
  LParent: TWinControl;
  LHandler: TRadLayoutHandler;
begin
  LParent := AControl.Parent;
  while LParent <> nil do
  begin
    if TRadScriptBinder.LayoutHandlerOf(LParent, LHandler) then
      Exit(True);
    LParent := LParent.Parent;
  end;
  Result := False;
end;

procedure TRadFormCustomizeSession.EditBehaviour(Sender: TObject; TheComponent: TComponent;
  var Behaviour: TEditBehaviour);
begin
  // *Runtime behaviours keep csDesigning off; a protected control is skipped altogether.
  if (FCustomizer = nil) or (FCustomizer.AllowedPaths(TheComponent) = nil) then
    Behaviour := ebProtected
  else if not (TheComponent is TControl) or IsLayoutChild(TControl(TheComponent)) or
    not (FCustomizer.CanMove(TheComponent) or FCustomizer.CanResize(TheComponent)) then
    Behaviour := ebLockedRuntime
  else
    Behaviour := ebDefaultRuntime;
end;

procedure TRadFormCustomizeSession.RememberCurrent;
begin
  if FCurrent = nil then
    Exit;
  FCurrentValues := FCustomizer.Snapshot(FCurrent);
  if FCurrent is TControl then
    FCurrentBounds := TControl(FCurrent).BoundsRect;
end;

procedure TRadFormCustomizeSession.PushIfChanged;
var
  LNow: IDocDict;
begin
  if (FCurrent = nil) or (FCurrentValues = nil) then
    Exit;
  LNow := FCustomizer.Snapshot(FCurrent);
  if LNow.Json <> FCurrentValues.Json then
  begin
    FUndo.Add(TPair<string, IDocDict>.Create(FCurrent.Name, FCurrentValues));
    FCurrentValues := LNow;
  end;
end;

procedure TRadFormCustomizeSession.ShowTarget;
begin
  if FCurrent = nil then
    FTools.lblTarget.Caption := SPickControl
  else
    FTools.lblTarget.Caption := FCurrent.Name;
  FTools.insp.Bind(FCustomizer, FCurrent);
  FTools.btnUndo.Enabled := CanUndo;
  FTools.btnResetSelected.Enabled := FCurrent <> nil;
end;

procedure TRadFormCustomizeSession.Refresh;
begin
  FTools.insp.RefreshInspectedProperties;
  if FDesigner <> nil then
    FDesigner.Update;
  FTools.btnUndo.Enabled := CanUndo;
end;

procedure TRadFormCustomizeSession.Select(AComponent: TComponent);
begin
  PushIfChanged; // a dialog edit does not raise OnPropertyChanged: catch it on leaving
  if (AComponent <> nil) and (FCustomizer.AllowedPaths(AComponent) = nil) then
    AComponent := nil;
  FCurrent := AComponent;
  if FCurrent <> nil then
    FCurrent.FreeNotification(Self);
  RememberCurrent;
  ShowTarget;
end;

procedure TRadFormCustomizeSession.DesignerSelectionChange(Sender: TObject);
begin
  if (FDesigner <> nil) and (FDesigner.Component <> FCurrent) then
    Select(FDesigner.Component);
end;

procedure TRadFormCustomizeSession.DesignerMoveSize(Sender: TObject; TheControl: TControl);
var
  LBounds: TRect;
begin
  if TheControl <> FCurrent then
    Exit;
  LBounds := TheControl.BoundsRect;
  if not FCustomizer.CanMove(TheControl) then
    LBounds.SetLocation(FCurrentBounds.Left, FCurrentBounds.Top);
  if not FCustomizer.CanResize(TheControl) then
  begin
    LBounds.Width := FCurrentBounds.Width;
    LBounds.Height := FCurrentBounds.Height;
  end;
  TheControl.BoundsRect := LBounds;
  Changed;
end;

procedure TRadFormCustomizeSession.DesignerGrabs(Sender: TObject; var VisibleGrabs, EnabledGrabs: TGrabPositions);
begin
  if (FCurrent <> nil) and not FCustomizer.CanResize(FCurrent) then
  begin
    VisibleGrabs := [];
    EnabledGrabs := [];
  end;
end;

procedure TRadFormCustomizeSession.DesignerKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = Ord('Z')) and (ssCtrl in Shift) then
  begin
    Key := 0;
    Undo;
  end
  else if (Key = VK_DELETE) or ((ssCtrl in Shift) and (Key in [Ord('C'), Ord('V'), Ord('X')])) then
    Key := 0; // the user changes properties, never the form's components
end;

procedure TRadFormCustomizeSession.DesignerPopup(Sender: TObject; var Handled: Boolean);
begin
  Handled := True; // the designer's own menu offers delete, align and copy
end;

procedure TRadFormCustomizeSession.InspectorChanged(Sender: TObject);
begin
  // Caption-like rows post on every keystroke (cxOI EditChange, ipaAutoUpdate). Refreshing the
  // inspector here rebuilt the open editor with its text selected, so the next key replaced it.
  if FDesigner <> nil then
    FDesigner.Update; // the grab handles follow a typed size at once
  if not FTools.insp.IsEditing then
    InspectorEdited(Sender, nil); // a value list or check box posts without an open editor
end;

procedure TRadFormCustomizeSession.InspectorEdited(Sender: TObject; ARowProperties: TcxCustomEditorRowProperties);
begin
  // One undo step per edit, not per keystroke; the inspector already shows what it wrote.
  PushIfChanged;
  if FCurrent is TControl then
    FCurrentBounds := TControl(FCurrent).BoundsRect;
  FTools.btnUndo.Enabled := CanUndo;
end;

procedure TRadFormCustomizeSession.Changed;
begin
  PushIfChanged;
  if FCurrent is TControl then
    FCurrentBounds := TControl(FCurrent).BoundsRect;
  Refresh;
end;

function TRadFormCustomizeSession.CanUndo: Boolean;
begin
  Result := FUndo.Count > 0;
end;

procedure TRadFormCustomizeSession.Undo;
var
  LStep: TPair<string, IDocDict>;
  LComponent: TComponent;
begin
  PushIfChanged;
  if not CanUndo then
    Exit;
  LStep := FUndo.Last;
  FUndo.Delete(FUndo.Count - 1);
  LComponent := FForm.FindComponent(LStep.Key);
  if LComponent = nil then
    Exit;
  FCustomizer.ApplyValues(LComponent, LStep.Value);
  if LComponent = FCurrent then
    RememberCurrent;
  Refresh;
end;

procedure TRadFormCustomizeSession.ResetSelected;
var
  LValues, LDefaults: IDocDict;
begin
  if (FCurrent = nil) or not FBefore.Get(StringToUtf8(FCurrent.Name), LValues) then
    Exit;
  PushIfChanged;
  LValues := LValues.Copy; // the session start, with the true defaults of saved changes on top
  LDefaults := FCustomizer.Defaults(FCurrent);
  LValues.Update(LDefaults);
  FCustomizer.ApplyValues(FCurrent, LValues);
  Changed;
end;

procedure TRadFormCustomizeSession.ResetAll;
var
  LComponent: TComponent;
begin
  for LComponent in FCustomizer.Targets do
  begin
    Select(LComponent);
    ResetSelected;
  end;
  Select(nil);
end;

procedure TRadFormCustomizeSession.Save;
begin
  PushIfChanged;
  FCustomizer.Commit(FBefore);
  Close;
end;

procedure TRadFormCustomizeSession.Cancel;
var
  LComponent: TComponent;
  LValues: IDocDict;
begin
  for LComponent in FCustomizer.Targets do
    if FBefore.Get(StringToUtf8(LComponent.Name), LValues) then
      FCustomizer.ApplyValues(LComponent, LValues);
  Close;
end;

procedure TRadFormCustomizeSession.ResetForm;
var
  LForm: TCustomForm;
begin
  if MessageDlg(SConfirmResetForm, mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  LForm := FForm;
  Close;
  if LForm <> nil then
    TRadFormState.ResetForm(LForm);
end;

procedure TRadFormCustomizeSession.Close;
begin
  if FClosing then
    Exit;
  FClosing := True;
  if FDesigner <> nil then
  begin
    FDesigner.Active := False;
    FreeAndNil(FDesigner);
  end;
  if FTools <> nil then
    FTools.insp.Bind(nil, nil);
  FActive := nil;
  // The click that closed the session is still running in the tool window: free afterwards.
  System.Classes.TThread.ForceQueue(nil, Free);
end;

procedure TRadFormCustomizeSession.ButtonClick(Sender: TObject);
begin
  if Sender = FTools.btnUndo then
    Undo
  else if Sender = FTools.btnResetSelected then
    ResetSelected
  else if Sender = FTools.btnResetAll then
    ResetAll
  else if Sender = FTools.btnResetForm then
    ResetForm
  else if Sender = FTools.btnCancel then
    Cancel
  else if Sender = FTools.btnSave then
    Save;
end;

initialization
  TRadFormCustomizer.RegisterSession(
    procedure(ACustomizer: TRadFormCustomizer)
    begin
      TRadFormCustomizeSession.Open(ACustomizer);
    end);

finalization
  TRadFormCustomizer.RegisterSession(nil);

end.
