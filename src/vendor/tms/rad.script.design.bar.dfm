object RadScriptDesignBar: TRadScriptDesignBar
  Left = 0
  Top = 0
  BorderIcons = []
  BorderStyle = bsToolWindow
  Caption = 'Script tasar'#305'm'#305
  ClientHeight = 36
  ClientWidth = 760
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  Position = poDesigned
  OnCreate = FormCreate
  TextHeight = 15
  object lblPaket: TLabel
    Left = 8
    Top = 10
    Width = 200
    Height = 15
    AutoSize = False
    Caption = 'paket'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblSecili: TLabel
    Left = 214
    Top = 10
    Width = 210
    Height = 15
    AutoSize = False
    Caption = ''
  end
  object btnYerlesim: TButton
    Left = 430
    Top = 6
    Width = 80
    Height = 25
    Caption = 'Yerle'#351'im'
    TabOrder = 0
  end
  object btnKaydet: TButton
    Left = 516
    Top = 6
    Width = 80
    Height = 25
    Caption = 'Kaydet'
    TabOrder = 1
  end
  object btnVazgec: TButton
    Left = 602
    Top = 6
    Width = 72
    Height = 25
    Caption = 'Vazge'#231
    TabOrder = 2
  end
  object btnKapat: TButton
    Left = 680
    Top = 6
    Width = 72
    Height = 25
    Caption = 'Kapat'
    TabOrder = 3
  end
end
