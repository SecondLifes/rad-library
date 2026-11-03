object FormLink: TFormLink
  Left = 0
  Top = 0
  Caption = 'Link'
  ClientHeight = 300
  ClientWidth = 400
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  TextHeight = 15
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
  object Store2: TRadPropertiesStore
    StorageName = 'gizli'
    Encrypted = True
    Left = 300
    Top = 60
  end
  object Customizer1: TRadFormCustomizer
    Store = Store2
    Rules.Strings = (
      'TCustomEdit: Width, Font'
      '-Button1')
    Left = 300
    Top = 110
  end
end
