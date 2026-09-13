unit dm.dev;

interface

uses
  System.SysUtils, System.Classes, dxCore, cxLookAndFeels, cxClasses,
  dxSkinsForm, System.ImageList, Vcl.ImgList, Vcl.Controls, cxImageList,
  cxGraphics,help.dev, dxLayoutLookAndFeels, cxEdit, cxEditRepositoryItems, cxStyles;

type
  Tdm_dev = class(TDataModule)
    SkinController: TdxSkinController;
    cxLookAndFeelController: TcxLookAndFeelController;
    dxLayoutFeel: TdxLayoutLookAndFeelList;
    dxLayoutSkin: TdxLayoutSkinLookAndFeel;
    EditRepository: TcxEditRepository;
    StyleRepository: TcxStyleRepository;
    Stil_Password: TcxEditRepositoryTextItem;
    DefaultEditStyle: TcxDefaultEditStyleController;
    Stil_tel: TcxEditRepositoryMaskItem;
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;



implementation
 uses rad,  mormot.core.base, mormot.core.data,mormot.core.variants,mormot.core.text;
{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

procedure Tdm_dev.DataModuleCreate(Sender: TObject);
begin
 SkinController._Load;
end;

procedure Tdm_dev.DataModuleDestroy(Sender: TObject);
begin
  SkinController._Save;
end;

(* Stil_tel'in (eski adiyla Edit_tel) OnValidate isleyicisi KALDIRILDI: kosulsuz Error := True
   yapiyordu ve ValidationOptions varsayilani [evoRaiseException] oldugu icin
   HER numara bir istisnayla reddediliyordu (DxAuditTest T01). Eksik numarayi
   maskenin kendisi zaten reddediyor (T02 olcumu) - gercek bir dogrulama
   kaybolmadi. *)

end.
