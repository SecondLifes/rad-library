object RadDeskPickerForm: TRadDeskPickerForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  Caption = 'K'#305'sayol ekle'
  ClientHeight = 520
  ClientWidth = 560
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = False
  Position = poOwnerFormCenter
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 560
    Height = 48
    Align = alTop
    BevelOuter = bvNone
    Padding.Left = 12
    Padding.Top = 12
    Padding.Right = 12
    Padding.Bottom = 8
    ParentColor = True
    TabOrder = 0
    object edtSearch: TEdit
      Left = 12
      Top = 12
      Width = 536
      Height = 28
      Align = alClient
      TabOrder = 0
      TextHint = 'Komut ya da kategori ara...'
      OnChange = edtSearchChange
      OnKeyDown = edtSearchKeyDown
    end
  end
  object lvCommands: TListView
    AlignWithMargins = True
    Left = 12
    Top = 48
    Width = 536
    Height = 420
    Margins.Left = 12
    Margins.Top = 0
    Margins.Right = 12
    Margins.Bottom = 0
    Align = alClient
    BorderStyle = bsNone
    Checkboxes = True
    Columns = <
      item
        Caption = 'Komut'
        Width = 320
      end
      item
        Caption = 'Kategori'
        Width = 190
      end>
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
    OnDblClick = lvCommandsDblClick
    OnItemChecked = lvCommandsItemChecked
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 468
    Width = 560
    Height = 52
    Align = alBottom
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 2
    DesignSize = (
      560
      52)
    object lblCount: TLabel
      Left = 12
      Top = 18
      Width = 3
      Height = 15
    end
    object btnOk: TButton
      Left = 352
      Top = 10
      Width = 92
      Height = 32
      Anchors = [akTop, akRight]
      Caption = 'Ekle'
      Default = True
      Enabled = False
      ModalResult = 1
      TabOrder = 0
    end
    object btnCancel: TButton
      Left = 456
      Top = 10
      Width = 92
      Height = 32
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'Vazge'#231
      ModalResult = 2
      TabOrder = 1
    end
  end
end
