unit HostDfm;

{ Sonda: cerceve tasarim zamaninda forma birakilmis gibi, host DFM'inden "inline" akitilir. }

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms,
  rad.dev.customfields;

type
  TfrmHost = class(TForm)
    FOzel: TRadCustomFieldsFrame;
  end;

implementation

{$R *.dfm}

end.
