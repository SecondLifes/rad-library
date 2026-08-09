unit Core.Form;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs,rtti, System.Actions, Vcl.ActnList

  ;

const
  WM_CMD = WM_USER + 2000;
  WM_EVENT_CREATE = WM_CMD + 1;
  WM_EVENT_SHOW = WM_CMD + 2;
  WM_EVENT_LOAD = WM_CMD + 3;
type

  TFormEvent = (feOnActivate,feOnDeactivate,feOnClose,feOnCreate,feOnDestroy,feOnHide,feOnShow);
  TCoreForm = class(TForm)
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    FIsShow:Boolean;
    FAutoFree: Boolean;

    { Private declarations }

  protected
    //procedure CreateParams(var Params: TCreateParams); override;
    //procedure CreateWindowHandle(const Params: TCreateParams); override;
    //procedure CreateWnd; override;
    //procedure Deactivate; dynamic;
    //procedure DefineProperties(Filer: TFiler); override;
    //procedure DestroyHandle; override;
    //procedure DestroyWindowHandle; override;
    //procedure DoClose(var Action: TCloseAction); dynamic;
    //procedure AfterConstruction; override;
    //procedure BeforeDestruction; override;
    procedure Activate; override;
    procedure Deactivate; override;
    procedure DoClose(var Action: TCloseAction); override;
    procedure DoCreate; override;
    procedure DoDestroy; override;
    procedure DoHide; override;
    procedure DoShow; override;

    procedure WmCMD(var Msg: TMessage); message WM_CMD;
    procedure ClientWndProc(var Message: TMessage); override;
    procedure DoFormEvent(const AEvent:TFormEvent); virtual;
  public
    { Public declarations }

    function ACmdSys(const AID:SmallInt):variant;
    function _ShowWait:TForm;
    function _IsShowing:Boolean;
    function _ShowMDIChild:TForm;

    property AutoFree: Boolean read FAutoFree write FAutoFree;
  end;

  //Handled:=not (act.Enabled and act.Visible);

implementation
  uses Help.vcl;
{$R *.dfm}

{ TB_Form }




function TCoreForm._IsShowing: Boolean;
begin

end;



function TCoreForm.ACmdSys(const AID: SmallInt): variant;
begin
       case AID of  //Sistem Mesajlarý Eksi ile baþlar
      // WM_EVENT_CREATE:DoFormEvent(oCreate);
       WM_EVENT_SHOW:DoFormEvent(feOnShow);
       //WM_EVENT_LOAD  *-1:;
       0:Result:=(FIsShow and Self.Showing);
      -1:begin Close; end; //F_Main.MDITab.RemoveTab(Self);
      -2:Self.WindowState:=TWindowState.wsMinimized;
      -3:Self.WindowState:=TWindowState.wsMaximized;

    end;
end;



procedure TCoreForm.Activate;
begin
  inherited Activate;
  DoFormEvent(feOnActivate);

end;

procedure TCoreForm.ClientWndProc(var Message: TMessage);
var
  ExStyle: DWORD;
begin
  if (FormStyle = fsMDIForm) then
  begin
    case Message.Msg of
      $3F:
        begin
          Message.Result := CallWindowProc(DefClientProc, ClientHandle,
            Message.Msg, Message.wParam, Message.lParam);
          ExStyle := GetWindowLongPtr(ClientHandle, GWL_EXSTYLE);
          ExStyle := ExStyle and not WS_EX_CLIENTEDGE;
          SetWindowLongPtr(ClientHandle, GWL_EXSTYLE, ExStyle);
          SetWindowPos(ClientHandle, 0, 0, 0, 0, 0, SWP_FRAMECHANGED or
            SWP_NOACTIVATE or SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER);
        end;
    else
      inherited;
    end;
  end else
    inherited;

end;



procedure TCoreForm.Deactivate;
begin
  inherited Deactivate;
  DoFormEvent(feOnDeactivate);

end;

procedure TCoreForm.DoClose(var Action: TCloseAction);
begin
  inherited DoClose(Action);
  DoFormEvent(feOnClose);
end;

procedure TCoreForm.DoCreate;
begin
  inherited DoCreate;
  DoFormEvent(feOnCreate);
  //PostMessage(Self.Handle, WM_CMD,99, WM_EVENT_CREATE);

end;

procedure TCoreForm.DoDestroy;
begin
  DoFormEvent(feOnDestroy);
  inherited DoDestroy;
end;


procedure TCoreForm.DoFormEvent(const AEvent: TFormEvent);
begin

end;


procedure TCoreForm.DoHide;
begin
  inherited DoHide;
  FIsShow:=false;
  DoFormEvent(feOnHide);

end;

procedure TCoreForm.DoShow;
begin
  inherited DoShow;
  PostMessage(Self.Handle, WM_CMD,99, WM_EVENT_SHOW);
end;

procedure TCoreForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
   Action:=TCloseAction.caFree;
   inherited;
end;

function TCoreForm._ShowMDIChild: TForm;
begin
 if FormStyle<>fsMDIChild then
  begin
   PostMessage(Self.Handle, WM_CMD,99, WM_EVENT_CREATE);
  end else Show;

end;

function TCoreForm._ShowWait: TForm;
begin
   if _IsShowing then Exit;
   FIsShow:=false;
   Show;
  while not FIsShow do Application.ProcessMessages;
  
end;

procedure TCoreForm.WmCMD(var Msg: TMessage);
begin
    if  Msg.WParam =99 then
    begin
     ACmdSys(Msg.LParam);
    end

end;






end.
