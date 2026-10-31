unit HostDfm2;

{ Sonda 2: cerceve, host formun TdxLayoutControl'u icindeki bir item'a birakilmis (kasa.k.dfm gibi). }

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms,
  cxGraphics, cxControls, cxLookAndFeels, cxLookAndFeelPainters, cxContainer, cxEdit, cxClasses,
  dxLayoutContainer, dxLayoutControl, dxLayoutControlAdapters,
  rad.dev.customfields;

type
  TfrmHost2 = class(TForm)
    lc: TdxLayoutControl;
    lcGroup_Root: TdxLayoutGroup;
    FOzel: TRadCustomFieldsFrame;
    liOzel: TdxLayoutItem;
  end;

implementation

{$R *.dfm}

end.
