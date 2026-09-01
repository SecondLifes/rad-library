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
    dxLayoutLookAndFeelList: TdxLayoutLookAndFeelList;
    dxLayoutSkin: TdxLayoutSkinLookAndFeel;
    EditRepository: TcxEditRepository;
    StyleRepository: TcxStyleRepository;
    Edit_Password: TcxEditRepositoryTextItem;
    DefaultEditStyle: TcxDefaultEditStyleController;
    Edit_tel: TcxEditRepositoryMaskItem;
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
    procedure Edit_telPropertiesValidate(Sender: TObject; var DisplayValue: TcxEditValue; var ErrorText: TCaption; var Error: Boolean);
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

procedure Tdm_dev.Edit_telPropertiesValidate(Sender: TObject; var DisplayValue: TcxEditValue; var ErrorText: TCaption; var Error: Boolean);
begin
 ErrorText:=DisplayValue;
 Error:=True;
end;

end.
