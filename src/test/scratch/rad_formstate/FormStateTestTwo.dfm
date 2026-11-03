object FormTwo: TFormTwo
  Left = 100
  Top = 100
  Caption = 'FormTwo'
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
    Text = 'two'
  end
  object Store1: TRadPropertiesStore
    Options = [soProps]
    Items = <
      item
        Component = Edit1
        Properties.Strings = (
          'Width')
      end>
    Left = 200
    Top = 16
  end
  object Store2: TRadPropertiesStore
    Options = [soProps]
    StorageName = 'second'
    Items = <
      item
        Component = Edit1
        Properties.Strings = (
          'Text')
      end>
    Left = 200
    Top = 72
  end
end
