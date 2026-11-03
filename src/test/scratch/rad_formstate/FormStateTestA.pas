unit FormStateTestA;

{ Test form: one store saving an edit, a memo and a status bar panel. }

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ComCtrls,
  rad.formstate.component;

type
  TFormA = class(TForm)
    Edit1: TEdit;
    Memo1: TMemo;
    StatusBar1: TStatusBar;
    Store1: TRadPropertiesStore;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
  public
    WidthSeenInCreate: Integer;
    CreateCalls, ShowCalls, CloseQueryCalls, DestroyCalls: Integer;
  end;

implementation

{$R *.dfm}

procedure TFormA.FormCreate(Sender: TObject);
begin
  Inc(CreateCalls);
  WidthSeenInCreate := Edit1.Width;
end;

procedure TFormA.FormShow(Sender: TObject);
begin
  Inc(ShowCalls);
end;

procedure TFormA.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  Inc(CloseQueryCalls);
end;

procedure TFormA.FormDestroy(Sender: TObject);
begin
  Inc(DestroyCalls);
end;

end.
