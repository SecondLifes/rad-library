unit FormStateTestPlain;

{ Test form without a store: runtime-created stores are attached to it. }

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls;

type
  TFormPlain = class(TForm)
    Edit1: TEdit;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
  end;

implementation

{$R *.dfm}

procedure TFormPlain.FormCreate(Sender: TObject);
begin
  Tag := Tag + 1;
end;

procedure TFormPlain.FormShow(Sender: TObject);
begin
  Tag := Tag + 1;
end;

procedure TFormPlain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  Tag := Tag + 1;
end;

procedure TFormPlain.FormDestroy(Sender: TObject);
begin
  Tag := Tag + 1;
end;

end.
