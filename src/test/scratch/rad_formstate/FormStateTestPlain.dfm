object FormPlain: TFormPlain
  Left = 100
  Top = 100
  Caption = 'FormPlain'
  ClientHeight = 200
  ClientWidth = 300
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  TextHeight = 15
  object Edit1: TEdit
    Left = 8
    Top = 8
    Width = 121
    Height = 23
    TabOrder = 0
    Text = 'plain'
  end
end
