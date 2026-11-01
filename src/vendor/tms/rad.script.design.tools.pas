unit rad.script.design.tools;

(* Tasarım oturumu yan penceresi (DFM): TMS özellik/olay inspector'ı ve pencere kipinde bileşen paleti.
   Mantık rad.script.design'da. *)

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls,
  idemain, componentinspector;

type
  TRadScriptDesignTools = class(TForm)
    pnlUst: TPanel;
    rbOzellik: TRadioButton;
    rbOlay: TRadioButton;
    pal: TIDEPaletteToolbar;
    insp: TIDEInspector;
    procedure FormCreate(Sender: TObject);
  end;

implementation

{$R *.dfm}

procedure TRadScriptDesignTools.FormCreate(Sender: TObject);
begin
  pal.Visible := False;   // TIDEPaletteToolbar Visible/TabOrder yayımlamaz, DFM'den okunamaz
  SetBounds(Screen.WorkAreaWidth - Width, Screen.WorkAreaTop + 40, Width, Screen.WorkAreaHeight - 40);
end;

end.
