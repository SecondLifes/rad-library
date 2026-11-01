unit rad.script.design.bar;

(* Tasarım oturumu araç çubuğu: ekranın üstünde yüzen küçük pencere (DFM). Mantık rad.script.design'da. *)

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls;

type
  TRadScriptDesignBar = class(TForm)
    lblPaket: TLabel;
    lblSecili: TLabel;
    btnYerlesim: TButton;
    btnKaydet: TButton;
    btnVazgec: TButton;
    btnKapat: TButton;
    procedure FormCreate(Sender: TObject);
  end;

implementation

{$R *.dfm}

procedure TRadScriptDesignBar.FormCreate(Sender: TObject);
begin
  SetBounds((Screen.WorkAreaWidth - Width) div 2, Screen.WorkAreaTop, Width, Height);
end;

end.
