object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 740
  ClientWidth = 760
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  TextHeight = 15
  object Panel1: TPanel
    Left = 0
    Top = 699
    Width = 760
    Height = 41
    Align = alBottom
    Caption = 'Panel1'
    TabOrder = 0
    ExplicitLeft = 88
    ExplicitTop = 472
    ExplicitWidth = 185
  end
  inline FPanel: TfrmSetting
    Left = 0
    Top = 0
    Width = 760
    Height = 699
    Align = alClient
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 1
    ExplicitLeft = 25
    ExplicitTop = 71
    inherited lytSetting: TdxLayoutControl
      Width = 760
      Height = 699
      inherited edtSearch: TcxButtonEdit
        ExplicitWidth = 666
        Width = 666
      end
      inherited lblID: TcxLabel
        Top = 616
        ExplicitTop = 616
        ExplicitWidth = 521
      end
      inherited lblBaslik: TcxLabel
        Top = 547
        ExplicitTop = 547
        ExplicitWidth = 350
        Width = 350
      end
      inherited lblGrup: TcxLabel
        Left = 570
        Top = 547
        ExplicitLeft = 570
        ExplicitTop = 547
        ExplicitWidth = 164
      end
      inherited lblInfo: TcxLabel
        Top = 569
        ExplicitTop = 569
        ExplicitWidth = 521
        Width = 521
      end
      inherited dxNavBar: TdxNavBar
        Height = 531
        ExplicitHeight = 531
      end
      inherited cxVerticalGrid1: TcxVerticalGrid
        Width = 521
        Height = 407
        ExplicitWidth = 521
        ExplicitHeight = 407
        Version = 1
      end
    end
  end
  object cxEditRepository1: TcxEditRepository
    Left = 376
    Top = 376
    PixelsPerInch = 96
    object riDepo: TcxEditRepositoryComboBoxItem
    end
  end
end
