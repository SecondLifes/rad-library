object RadScriptNewScriptForm: TRadScriptNewScriptForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Yeni script'
  ClientHeight = 214
  ClientWidth = 420
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  TextHeight = 15
  object lblKod: TLabel
    Left = 16
    Top = 16
    Width = 60
    Height = 15
    Caption = 'Kod'
  end
  object lblAd: TLabel
    Left = 16
    Top = 48
    Width = 60
    Height = 15
    Caption = 'Ad'
  end
  object lblTur: TLabel
    Left = 16
    Top = 80
    Width = 60
    Height = 15
    Caption = 'T'#252'r'
  end
  object lblHedef: TLabel
    Left = 16
    Top = 112
    Width = 60
    Height = 15
    Caption = 'Hedef'
  end
  object lblIpucu: TLabel
    Left = 96
    Top = 140
    Width = 308
    Height = 30
    AutoSize = False
    Caption = ''
    WordWrap = True
  end
  object edtKod: TEdit
    Left = 96
    Top = 13
    Width = 308
    Height = 23
    TabOrder = 0
  end
  object edtAd: TEdit
    Left = 96
    Top = 45
    Width = 308
    Height = 23
    TabOrder = 1
  end
  object cmbTur: TComboBox
    Left = 96
    Top = 77
    Width = 308
    Height = 23
    Style = csDropDownList
    TabOrder = 2
    OnChange = cmbTurChange
  end
  object edtHedef: TEdit
    Left = 96
    Top = 109
    Width = 308
    Height = 23
    TabOrder = 3
  end
  object btnTamam: TButton
    Left = 242
    Top = 176
    Width = 80
    Height = 25
    Caption = 'Tamam'
    Default = True
    TabOrder = 4
    OnClick = btnTamamClick
  end
  object btnIptal: TButton
    Left = 324
    Top = 176
    Width = 80
    Height = 25
    Cancel = True
    Caption = #304'ptal'
    ModalResult = 2
    TabOrder = 5
  end
end
