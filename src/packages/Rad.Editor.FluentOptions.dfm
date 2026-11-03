object RadFluentOptionsForm: TRadFluentOptionsForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Fluent Birimi Se'#231'enekleri'
  ClientHeight = 262
  ClientWidth = 470
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object lblClasses: TLabel
    Left = 12
    Top = 12
    Width = 81
    Height = 15
    Caption = 'Se'#231'ili s'#305'n'#305'flar:'
  end
  object lstClasses: TListBox
    Left = 12
    Top = 33
    Width = 446
    Height = 137
    ItemHeight = 15
    TabOrder = 0
  end
  object chkInherited: TCheckBox
    Left = 12
    Top = 182
    Width = 446
    Height = 19
    Caption =
      'Kal'#305't'#305'lan '#252'yeleri de '#252'ret (TComponent dahil, TPersistent ve TObjec' +
      't hari'#231')'
    TabOrder = 1
  end
  object btnOk: TButton
    Left = 302
    Top = 223
    Width = 75
    Height = 27
    Caption = 'Devam'
    Default = True
    ModalResult = 1
    TabOrder = 2
  end
  object btnCancel: TButton
    Left = 383
    Top = 223
    Width = 75
    Height = 27
    Cancel = True
    Caption = 'Vazge'#231
    ModalResult = 2
    TabOrder = 3
  end
end
