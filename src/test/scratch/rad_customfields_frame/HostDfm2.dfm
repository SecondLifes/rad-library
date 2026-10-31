object frmHost2: TfrmHost2
  Left = 0
  Top = 0
  Caption = 'Host2'
  ClientHeight = 400
  ClientWidth = 600
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  TextHeight = 15
  object lc: TdxLayoutControl
    Left = 0
    Top = 0
    Width = 600
    Height = 400
    Align = alClient
    TabOrder = 0
    inline FOzel: TRadCustomFieldsFrame
      Left = 10
      Top = 10
      Width = 500
      Height = 300
      TabOrder = 0
    end
    object lcGroup_Root: TdxLayoutGroup
      AlignHorz = ahClient
      AlignVert = avClient
      ButtonOptions.Buttons = <>
      Hidden = True
      ShowBorder = False
      Index = -1
    end
    object liOzel: TdxLayoutItem
      Parent = lcGroup_Root
      AlignHorz = ahClient
      AlignVert = avClient
      CaptionOptions.Text = 'Ozel'
      Control = FOzel
      ControlOptions.OriginalHeight = 300
      ControlOptions.OriginalWidth = 500
      ControlOptions.ShowBorder = False
      Index = 0
    end
  end
end
