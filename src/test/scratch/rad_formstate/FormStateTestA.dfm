object FormA: TFormA
  Left = 120
  Top = 120
  Caption = 'FormA'
  ClientHeight = 300
  ClientWidth = 400
  Position = poScreenCenter
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
    Text = 'default'
  end
  object Memo1: TMemo
    Left = 8
    Top = 40
    Width = 185
    Height = 89
    TabOrder = 1
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 281
    Width = 400
    Height = 19
    Panels = <
      item
        Width = 50
      end>
  end
  object Store1: TRadPropertiesStore
    Version = 1
    Items = <
      item
        Component = Edit1
        Properties.Strings = (
          'Width'
          'Text'
          'Font.Style')
      end
      item
        Component = Memo1
        Properties.Strings = (
          'Lines')
      end
      item
        Component = StatusBar1
        Properties.Strings = (
          'Panels.0.Width')
      end>
    StoredValues = <
      item
        Name = 'counter'
        Value = 0
      end>
    Left = 300
    Top = 40
  end
end
