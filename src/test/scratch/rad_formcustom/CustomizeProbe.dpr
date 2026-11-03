program CustomizeProbe;

(* Probe for the customizer session (docs/specs/rad.formcustomizer.md, phase 5): does TAdvFormDesigner
   with *Runtime edit behaviours select and drag controls on a live form with DevExpress editors,
   leave csDesigning off, and keep a protected button from firing? Mouse input is posted, not real. *)

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.StrUtils, System.Classes,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls,
  cxEdit, cxTextEdit, cxControls, cxContainer,
  FormDesigner;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;

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
    Writeln('  [HATA] ', AAd, '  ', ADetay);
  end;
end;

type
  TProbeForm = class(TForm)
  public
    Edit1: TEdit;
    Button1: TButton;
    Button2: TButton;
    CxEdit1: TcxTextEdit;
    Clicks: Integer;
    procedure ButtonClick(Sender: TObject);
    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
  end;

  TBehaviours = class
  public
    Form: TProbeForm;
    procedure EditBehaviour(Sender: TObject; TheComponent: TComponent; var Behaviour: TEditBehaviour);
  end;

constructor TProbeForm.CreateNew(AOwner: TComponent; Dummy: Integer);
begin
  inherited;
  SetBounds(100, 100, 500, 300);
  Edit1 := TEdit.Create(Self);
  Edit1.Name := 'Edit1';
  Edit1.Parent := Self;
  Edit1.SetBounds(16, 16, 120, 24);
  Button1 := TButton.Create(Self);
  Button1.Name := 'Button1';
  Button1.Parent := Self;
  Button1.SetBounds(16, 80, 90, 28);
  Button1.OnClick := ButtonClick;
  Button2 := TButton.Create(Self);
  Button2.Name := 'Button2';
  Button2.Parent := Self;
  Button2.SetBounds(120, 80, 90, 28);
  Button2.OnClick := ButtonClick;
  CxEdit1 := TcxTextEdit.Create(Self);
  CxEdit1.Name := 'CxEdit1';
  CxEdit1.Parent := Self;
  CxEdit1.SetBounds(200, 16, 150, 24);
end;

procedure TProbeForm.ButtonClick(Sender: TObject);
begin
  Inc(Clicks);
end;

procedure TBehaviours.EditBehaviour(Sender: TObject; TheComponent: TComponent; var Behaviour: TEditBehaviour);
begin
  if TheComponent = Form.Button1 then
    Behaviour := ebProtected
  else if (TheComponent = Form.Button2) then
    Behaviour := ebLockedRuntime
  else
    Behaviour := ebDefaultRuntime;
end;

procedure Pump;
var
  I: Integer;
begin
  for I := 1 to 5 do
  begin
    Application.ProcessMessages;
    Sleep(10);
  end;
end;

function ParamAt(X, Y: Integer): LPARAM;
begin
  Result := MakeLParam(Word(X), Word(Y));
end;

procedure ClickAt(AControl: TWinControl; X, Y: Integer);
begin
  PostMessage(AControl.Handle, WM_LBUTTONDOWN, MK_LBUTTON, ParamAt(X, Y));
  PostMessage(AControl.Handle, WM_LBUTTONUP, 0, ParamAt(X, Y));
  Pump;
end;

procedure PostedDrag(AControl: TWinControl; ADx: Integer);
var
  I: Integer;
begin
  PostMessage(AControl.Handle, WM_LBUTTONDOWN, MK_LBUTTON, ParamAt(5, 5));
  Pump;
  for I := 1 to 6 do
  begin
    PostMessage(AControl.Handle, WM_MOUSEMOVE, MK_LBUTTON, ParamAt(5 + I * ADx div 6, 5));
    Pump;
  end;
  PostMessage(AControl.Handle, WM_LBUTTONUP, 0, ParamAt(5 + ADx, 5));
  Pump;
end;

procedure RealDrag(AControl: TWinControl; ADx: Integer);
var
  P: TPoint;
  I: Integer;
begin
  P := AControl.ClientToScreen(Point(5, 5));
  SetCursorPos(P.X, P.Y);
  mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
  Pump;
  for I := 1 to 6 do
  begin
    SetCursorPos(P.X + I * ADx div 6, P.Y);
    Pump;
  end;
  mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
  Pump;
end;

var
  LForm: TProbeForm;
  LDesigner: TAdvFormDesigner;
  LBehaviours: TBehaviours;
  LLeft: Integer;
begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  LBehaviours := TBehaviours.Create;
  LForm := TProbeForm.CreateNew(nil);
  try
    LBehaviours.Form := LForm;
    LForm.Show;
    Pump;
    LDesigner := TAdvFormDesigner.Create(LForm);
    LDesigner.ProtectMode := pmUnselect;
    LDesigner.MultiSelect := False;
    LDesigner.OnEditBehaviour := LBehaviours.EditBehaviour;
    LDesigner.Active := True;
    Pump;
    Kontrol('P1 csDesigning kapali (Edit1)', not (csDesigning in LForm.Edit1.ComponentState));
    Kontrol('P2 csDesigning kapali (CxEdit1)', not (csDesigning in LForm.CxEdit1.ComponentState));
    Kontrol('P3 csDesigning kapali (Button1, korunan)', not (csDesigning in LForm.Button1.ComponentState));
    ClickAt(LForm.Edit1, 5, 5);
    Kontrol('P4 tik Edit1 secer', LDesigner.Control = LForm.Edit1,
      'secili: ' + IfThen(LDesigner.Control <> nil, LDesigner.Control.Name, 'yok'));
    ClickAt(LForm.Button1, 5, 5);
    Kontrol('P5 korunan dugme OnClick calismaz', LForm.Clicks = 0, IntToStr(LForm.Clicks));
    Kontrol('P6 korunan dugme secilmez', LDesigner.Control <> LForm.Button1);
    ClickAt(LForm.CxEdit1, 5, 5);
    Kontrol('P7 tik CxEdit1 secer', LDesigner.Control = LForm.CxEdit1,
      'secili: ' + IfThen(LDesigner.Control <> nil, LDesigner.Control.Name, 'yok'));
    ClickAt(LForm.Button2, 5, 5);
    Kontrol('P11 kilitli (ebLockedRuntime) dugme OnClick calismaz', LForm.Clicks = 0, IntToStr(LForm.Clicks));
    Kontrol('P12 kilitli dugme secilir', LDesigner.Control = LForm.Button2);
    Kontrol('P13 kilitli dugmede csDesigning kapali', not (csDesigning in LForm.Button2.ComponentState));
    LLeft := LForm.Edit1.Left;
    PostedDrag(LForm.Edit1, 48);
    // TMS reads the real cursor while dragging, so posted moves do not drag: information only.
    Writeln(Format('  [BILGI] P8 gonderilmis mesajla surukleme: %d -> %d', [LLeft, LForm.Edit1.Left]));
    if FindCmdLineSwitch('realmouse') then // moves the user's real cursor: run only on request
    begin
      LLeft := LForm.Edit1.Left;
      SetForegroundWindow(LForm.Handle);
      RealDrag(LForm.Edit1, 48);
      Kontrol('P9 gercek fare surukleme Edit1''i tasir (on planda pencere gerekir)', LForm.Edit1.Left > LLeft,
        Format('%d -> %d', [LLeft, LForm.Edit1.Left]));
    end;
    LDesigner.Active := False;
    Pump;
    Kontrol('P10 kapaninca csDesigning yine kapali', not (csDesigning in LForm.Edit1.ComponentState));
  finally
    LForm.Free;
    LBehaviours.Free;
  end;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    ExitCode := 1;
end.
