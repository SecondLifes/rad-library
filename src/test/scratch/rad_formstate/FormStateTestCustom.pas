unit FormStateTestCustom;

{ Test form: a store and a customizer that allows Edit1 (move, size, font, colour) and
  Label1 (caption); Button1 is not allowed. }

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  rad.formstate.component, rad.formstate.customizer;

type
  TFormCustom = class(TForm)
    Edit1: TEdit;
    Label1: TLabel;
    Button1: TButton;
    Store1: TRadPropertiesStore;
    Customizer1: TRadFormCustomizer;
  end;

implementation

{$R *.dfm}

end.
