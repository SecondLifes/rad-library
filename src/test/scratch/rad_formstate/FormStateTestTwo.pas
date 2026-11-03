unit FormStateTestTwo;

{ Test form: two stores on one form, the second with its own StorageName. }

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  rad.formstate.component;

type
  TFormTwo = class(TForm)
    Edit1: TEdit;
    Store1: TRadPropertiesStore;
    Store2: TRadPropertiesStore;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
  public
    CreateCalls, ShowCalls, CloseQueryCalls, DestroyCalls: Integer;
  end;

implementation

{$R *.dfm}

procedure TFormTwo.FormCreate(Sender: TObject);
begin
  Inc(CreateCalls);
end;

procedure TFormTwo.FormShow(Sender: TObject);
begin
  Inc(ShowCalls);
end;

procedure TFormTwo.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  Inc(CloseQueryCalls);
end;

procedure TFormTwo.FormDestroy(Sender: TObject);
begin
  Inc(DestroyCalls);
end;

end.
