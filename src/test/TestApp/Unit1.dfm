object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 441
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 185
    Height = 441
    Align = alLeft
    Caption = 'Panel1'
    TabOrder = 0
    object Button1: TButton
      Left = 24
      Top = 40
      Width = 121
      Height = 57
      Caption = 'Button1'
      TabOrder = 0
      OnClick = Button1Click
    end
  end
  object Memo1: TMemo
    Left = 185
    Top = 0
    Width = 439
    Height = 441
    Align = alClient
    Lines.Strings = (
      'Memo1')
    TabOrder = 1
  end
  object AES: TAESEncryption
    Version = '5.2.0.0'
    Left = 100
    Top = 297
  end
  object Conv: TConvert
    Version = '5.2.0.0'
    Left = 44
    Top = 353
  end
  object Salsa: TSalsaEncryption
    Version = '5.2.0.0'
    Left = 52
    Top = 161
  end
  object SPECK: TSPECKEncryption
    Version = '5.2.0.0'
    Left = 108
    Top = 160
  end
end
