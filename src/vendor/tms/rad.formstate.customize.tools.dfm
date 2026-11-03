object RadCustomizeToolsForm: TRadCustomizeToolsForm
  Left = 0
  Top = 0
  BorderStyle = bsSizeToolWin
  Caption = 'Formu D'#252'zenle'
  ClientHeight = 520
  ClientWidth = 340
  Color = clBtnFace
  Constraints.MinHeight = 360
  Constraints.MinWidth = 300
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  Position = poDesigned
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 340
    Height = 58
    Align = alTop
    BevelOuter = bvNone
    Padding.Left = 10
    Padding.Top = 8
    Padding.Right = 10
    Padding.Bottom = 6
    TabOrder = 0
    object lblTarget: TLabel
      Left = 10
      Top = 8
      Width = 320
      Height = 20
      Align = alTop
      Caption = 'Bir kontrol se'#231'in'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -15
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
    end
    object lblHint: TLabel
      Left = 10
      Top = 28
      Width = 320
      Height = 24
      Align = alClient
      Caption = 'Se'#231'mek i'#231'in t'#305'klay'#305'n, ta'#351#305'mak i'#231'in s'#252'r'#252'kleyin.'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      WordWrap = True
    end
  end
  object insp: TcxRTTIInspector
    Left = 0
    Top = 58
    Width = 340
    Height = 350
    Align = alClient
    OptionsView.RowHeaderWidth = 150
    TabOrder = 1
  end
  object pnlButtons: TPanel
    Left = 0
    Top = 408
    Width = 340
    Height = 112
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object btnUndo: TcxButton
      Left = 10
      Top = 8
      Width = 100
      Height = 28
      Caption = 'Geri al'
      TabOrder = 0
    end
    object btnResetSelected: TcxButton
      Left = 118
      Top = 8
      Width = 104
      Height = 28
      Caption = 'Se'#231'iliyi s'#305'f'#305'rla'
      TabOrder = 1
    end
    object btnResetAll: TcxButton
      Left = 230
      Top = 8
      Width = 100
      Height = 28
      Caption = 'T'#252'm'#252'n'#252' s'#305'f'#305'rla'
      TabOrder = 2
    end
    object btnResetForm: TcxButton
      Left = 10
      Top = 42
      Width = 320
      Height = 28
      Caption = 'Formu varsay'#305'lana d'#246'nd'#252'r'
      TabOrder = 3
    end
    object btnCancel: TcxButton
      Left = 118
      Top = 76
      Width = 100
      Height = 28
      Caption = 'Vazge'#231
      TabOrder = 4
    end
    object btnSave: TcxButton
      Left = 230
      Top = 76
      Width = 100
      Height = 28
      Caption = 'Kaydet'
      Default = True
      TabOrder = 5
    end
  end
end
