unit rad.formstate.customize.tools;

{ Tool window of the form customizer session (docs/specs/rad.formcustomizer.md). Layout is in the
  DFM. The inspector is the DevExpress RTTI inspector, narrowed by an interposer class to the
  customizer's allowed paths and given Turkish captions. }

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  cxGraphics,
  cxControls,
  cxLookAndFeels,
  cxLookAndFeelPainters,
  cxStyles,
  cxEdit,
  cxInplaceContainer,
  cxVGrid,
  cxOI,
  cxButtons,
  rad.formstate.customizer;

type
  /// <summary>Interposer: the DFM's TcxRTTIInspector, limited to what the customizer allows.</summary>
  TcxRTTIInspector = class(cxOI.TcxRTTIInspector)
  private
    FCustomizer: TRadFormCustomizer;
    FTarget: TComponent;
    function Relation(const APath: string): Integer;
  protected
    function FilterPropertyEx(const AFullPropertyName: string): Boolean; override;
    function DoEditing(AItem: TcxCustomInplaceEditContainer): Boolean; override;
    function DoDrawRowHeader(AHeaderViewInfo: TcxCustomRowHeaderInfo): Boolean; override;
  public
    /// <summary>Shows ATarget's allowed properties; nil clears the inspector.</summary>
    procedure Bind(ACustomizer: TRadFormCustomizer; ATarget: TComponent);
    /// <summary>True for an allowed path, a path below one, or a parent of one (shown, not editable).</summary>
    function Shows(const APath: string): Boolean;
    /// <summary>True only for a parent row such as Font when only Font.Size is allowed.</summary>
    function IsParentOnly(const APath: string): Boolean;
    property Target: TComponent read FTarget;
  end;

  TRadCustomizeToolsForm = class(TForm)
    pnlTop: TPanel;
    lblTarget: TLabel;
    lblHint: TLabel;
    insp: TcxRTTIInspector;
    pnlButtons: TPanel;
    btnUndo: TcxButton;
    btnResetSelected: TcxButton;
    btnResetAll: TcxButton;
    btnResetForm: TcxButton;
    btnCancel: TcxButton;
    btnSave: TcxButton;
  public
    /// <summary>Puts the window beside AForm, inside the same monitor's work area.</summary>
    procedure PlaceBeside(AForm: TCustomForm);
  end;

implementation

{$R *.dfm}

const
  REL_NONE = 0;
  REL_ALLOWED = 1; // the path or a path below an allowed one
  REL_PARENT = 2;  // only a parent of an allowed path
  WINDOW_GAP = 8;

{ TcxRTTIInspector }

procedure TcxRTTIInspector.Bind(ACustomizer: TRadFormCustomizer; ATarget: TComponent);
begin
  FCustomizer := ACustomizer;
  FTarget := ATarget;
  if (ACustomizer = nil) or (ATarget = nil) or (ACustomizer.AllowedPaths(ATarget) = nil) then
    InspectedObject := nil
  else
  begin
    InspectedObject := nil; // the filter depends on the target: rebuild every row
    InspectedObject := ATarget;
  end;
end;

function TcxRTTIInspector.Relation(const APath: string): Integer;
var
  LPaths: TStrings;
  LAllowed: string;
begin
  Result := REL_NONE;
  if (FCustomizer = nil) or (FTarget = nil) then
    Exit;
  LPaths := FCustomizer.AllowedPaths(FTarget);
  if LPaths = nil then
    Exit;
  for LAllowed in LPaths do
    if SameText(LAllowed, APath) or SameText(Copy(APath, 1, Length(LAllowed) + 1), LAllowed + '.') then
      Exit(REL_ALLOWED)
    else if SameText(Copy(LAllowed, 1, Length(APath) + 1), APath + '.') then
      Result := REL_PARENT;
end;

function TcxRTTIInspector.Shows(const APath: string): Boolean;
begin
  Result := Relation(APath) <> REL_NONE;
end;

function TcxRTTIInspector.IsParentOnly(const APath: string): Boolean;
begin
  Result := Relation(APath) = REL_PARENT;
end;

function TcxRTTIInspector.FilterPropertyEx(const AFullPropertyName: string): Boolean;
begin
  Result := inherited FilterPropertyEx(AFullPropertyName) and
    ((FCustomizer = nil) or Shows(AFullPropertyName));
end;

function TcxRTTIInspector.DoEditing(AItem: TcxCustomInplaceEditContainer): Boolean;
begin
  // A parent row would open the whole object's dialog (Font): editing it is refused, which also
  // keeps its button, double click and Ctrl+Enter from reaching the property editor.
  Result := inherited DoEditing(AItem) and
    not IsParentOnly(GetRowPropertyPath(TcxCellEdit(AItem).EditRowProperties.Row));
end;

function TcxRTTIInspector.DoDrawRowHeader(AHeaderViewInfo: TcxCustomRowHeaderInfo): Boolean;
var
  LPath, LCaption: string;
begin
  // Only the drawn caption changes: the row path is built from Properties.Caption. The path comes
  // back upper-cased (cxOI GetRowPropertyPath), so a row without a Turkish name keeps its own caption.
  if (FCustomizer <> nil) and (AHeaderViewInfo.CaptionsInfo.Count > 0) then
  begin
    LPath := GetRowPropertyPath(AHeaderViewInfo.Row);
    LCaption := FCustomizer.CaptionOf(LPath);
    if LCaption <> LPath then
      AHeaderViewInfo.CaptionsInfo[0].Caption := LCaption;
  end;
  Result := inherited DoDrawRowHeader(AHeaderViewInfo);
end;

{ TRadCustomizeToolsForm }

procedure TRadCustomizeToolsForm.PlaceBeside(AForm: TCustomForm);
var
  LArea: TRect;
  LLeft: Integer;
begin
  LArea := Screen.MonitorFromWindow(AForm.Handle).WorkareaRect;
  LLeft := AForm.Left + AForm.Width + WINDOW_GAP;
  if LLeft + Width > LArea.Right then
    LLeft := AForm.Left - Width - WINDOW_GAP;
  if LLeft < LArea.Left then
    LLeft := LArea.Right - Width;
  SetBounds(LLeft, AForm.Top, Width, Height);
end;

end.
