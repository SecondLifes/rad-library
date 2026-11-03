unit FormStateTestLink;

{ Test form: two stores, the customizer bound to the second (encrypted) one, permissions by rule only. }

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  rad.formstate;

type
  TFormLink = class(TForm)
    Edit1: TEdit;
    Button1: TButton;
    Store1: TRadPropertiesStore;
    Store2: TRadPropertiesStore;
    Customizer1: TRadFormCustomizer;
  end;

implementation

{$R *.dfm}

end.
