object RadScriptDesignTools: TRadScriptDesignTools
  Left = 0
  Top = 0
  BorderIcons = []
  BorderStyle = bsSizeToolWin
  Caption = #214'zellikler'
  ClientHeight = 600
  ClientWidth = 320
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
  object pnlUst: TPanel
    Left = 0
    Top = 0
    Width = 320
    Height = 28
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object rbOzellik: TRadioButton
      Left = 8
      Top = 5
      Width = 90
      Height = 17
      Caption = #214'zellikler'
      Checked = True
      TabOrder = 0
      TabStop = True
    end
    object rbOlay: TRadioButton
      Left = 110
      Top = 5
      Width = 80
      Height = 17
      Caption = 'Olaylar'
      TabOrder = 1
    end
  end
  object pal: TIDEPaletteToolbar
    Left = 0
    Top = 28
    Width = 320
    Height = 96
    Align = alTop
  end
  object insp: TIDEInspector
    Left = 0
    Top = 124
    Width = 320
    Height = 476
    Align = alClient
    TabOrder = 1
  end
end
