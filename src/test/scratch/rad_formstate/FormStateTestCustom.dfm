object FormCustom: TFormCustom
  Left = 0
  Top = 0
  Caption = 'Custom'
  ClientHeight = 300
  ClientWidth = 400
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  TextHeight = 15
  object Label1: TLabel
    Left = 10
    Top = 50
    Width = 31
    Height = 15
    Caption = 'Etiket'
  end
  object Edit1: TEdit
    Left = 10
    Top = 10
    Width = 121
    Height = 23
    TabOrder = 0
    Text = 'default'
  end
  object Button1: TButton
    Left = 10
    Top = 80
    Width = 75
    Height = 25
    Caption = 'Kaydet'
    TabOrder = 1
  end
  object Store1: TRadPropertiesStore
    Left = 300
    Top = 10
  end
  object Customizer1: TRadFormCustomizer
    Allowed = <
      item
        Component = Edit1
        Properties.Strings = (
          'Left'
          'Top'
          'Width'
          'Font.Size'
          'Color'
          'Name')
      end
      item
        Component = Label1
        Properties.Strings = (
          'Caption')
      end>
    Captions.Strings = (
      'Caption=Etiket metni')
    Left = 300
    Top = 60
  end
end
