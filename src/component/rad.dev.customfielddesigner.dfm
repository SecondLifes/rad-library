object RadCustomFieldDesigner: TRadCustomFieldDesigner
  Left = 0
  Top = 0
  Caption = #214'zel Alan Tan'#305'mlar'#305
  ClientHeight = 670
  ClientWidth = 720
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object lcMain: TdxLayoutControl
    Left = 0
    Top = 0
    Width = 720
    Height = 670
    Align = alClient
    TabOrder = 0
    ExplicitWidth = 900
    ExplicitHeight = 620
    object lstGroups: TcxListBox
      Left = 19
      Top = 42
      Width = 245
      Height = 467
      ItemHeight = 26
      TabOrder = 0
      OnClick = lstGroupsClick
    end
    object edtGroupName: TcxTextEdit
      Left = 85
      Top = 514
      TabOrder = 1
      Width = 179
    end
    object spnGroupOrder: TcxSpinEdit
      Left = 85
      Top = 542
      TabOrder = 2
      Width = 179
    end
    object chkGroupActive: TcxCheckBox
      Left = 19
      Top = 570
      Caption = 'Aktif'
      TabOrder = 3
      Transparent = True
    end
    object btnGroupNew: TcxButton
      Left = 19
      Top = 596
      Width = 120
      Height = 25
      Caption = 'Yeni kategori'
      TabOrder = 4
      OnClick = btnGroupNewClick
    end
    object btnGroupSave: TcxButton
      Left = 144
      Top = 596
      Width = 120
      Height = 25
      Caption = 'Kategoriyi kaydet'
      TabOrder = 5
      OnClick = btnGroupSaveClick
    end
    object lstFields: TcxListBox
      Left = 291
      Top = 42
      Width = 410
      Height = 140
      ItemHeight = 26
      TabOrder = 6
      OnClick = lstFieldsClick
    end
    object lblColumn: TcxLabel
      Left = 414
      Top = 187
      Caption = '-'
      TabOrder = 7
      Transparent = True
    end
    object edtCaption: TcxTextEdit
      Left = 414
      Top = 215
      TabOrder = 8
      Width = 287
    end
    object cmbType: TcxComboBox
      Left = 414
      Top = 243
      Properties.DropDownListStyle = lsFixedList
      Properties.OnChange = cmbTypeChange
      TabOrder = 9
      Width = 287
    end
    object spnLength: TcxSpinEdit
      Left = 414
      Top = 271
      Properties.MaxValue = 4000.000000000000000000
      Properties.MinValue = 1.000000000000000000
      TabOrder = 10
      Value = 50
      Width = 287
    end
    object spnDecimals: TcxSpinEdit
      Left = 414
      Top = 299
      Properties.MaxValue = 8.000000000000000000
      TabOrder = 11
      Value = 2
      Width = 287
    end
    object edtDefault: TcxTextEdit
      Left = 414
      Top = 327
      TabOrder = 12
      Width = 287
    end
    object mmoOptions: TcxMemo
      Left = 414
      Top = 355
      Properties.ScrollBars = ssVertical
      TabOrder = 13
      Height = 80
      Width = 287
    end
    object spnOrder: TcxSpinEdit
      Left = 414
      Top = 440
      TabOrder = 14
      Width = 287
    end
    object chkRequired: TcxCheckBox
      Left = 291
      Top = 468
      Caption = 'Zorunlu'
      TabOrder = 15
      Transparent = True
    end
    object chkFilterable: TcxCheckBox
      Left = 359
      Top = 468
      Caption = 'Filtrele'
      TabOrder = 16
      Transparent = True
    end
    object chkActive: TcxCheckBox
      Left = 420
      Top = 468
      Caption = 'Aktif'
      TabOrder = 17
      Transparent = True
    end
    object btnFieldNew: TcxButton
      Left = 291
      Top = 494
      Width = 120
      Height = 25
      Caption = 'Yeni alan'
      TabOrder = 18
      OnClick = btnFieldNewClick
    end
    object btnFieldSave: TcxButton
      Left = 416
      Top = 494
      Width = 120
      Height = 25
      Caption = 'Alan'#305' kaydet'
      TabOrder = 19
      OnClick = btnFieldSaveClick
    end
    object btnClose: TcxButton
      Left = 592
      Top = 637
      Width = 120
      Height = 25
      Caption = 'Tamam'
      TabOrder = 20
      OnClick = btnCloseClick
    end
    object lcMainGroup_Root: TdxLayoutGroup
      AlignHorz = ahClient
      AlignVert = avClient
      Hidden = True
      ShowBorder = False
      Index = -1
    end
    object grpTop: TdxLayoutGroup
      Parent = lcMainGroup_Root
      AlignHorz = ahClient
      AlignVert = avClient
      LayoutDirection = ldHorizontal
      ShowBorder = False
      Index = 0
    end
    object grpGroups: TdxLayoutGroup
      Parent = grpTop
      AlignHorz = ahLeft
      AlignVert = avClient
      CaptionOptions.Text = 'Kategori'
      Index = 0
    end
    object grpFields: TdxLayoutGroup
      Parent = grpTop
      AlignHorz = ahClient
      AlignVert = avClient
      CaptionOptions.Text = 'Alan Tan'#305'mlar'#305
      Index = 1
    end
    object grpBottom: TdxLayoutGroup
      Parent = lcMainGroup_Root
      AlignHorz = ahRight
      LayoutDirection = ldHorizontal
      ShowBorder = False
      Index = 1
    end
    object liGroups: TdxLayoutItem
      Parent = grpGroups
      AlignHorz = ahClient
      AlignVert = avClient
      CaptionOptions.Visible = False
      Control = lstGroups
      ControlOptions.OriginalHeight = 220
      ControlOptions.OriginalWidth = 240
      ControlOptions.ShowBorder = False
      Index = 0
    end
    object liGroupName: TdxLayoutItem
      Parent = grpGroups
      AlignHorz = ahClient
      CaptionOptions.Text = 'Kategori ad'#305
      Control = edtGroupName
      ControlOptions.OriginalHeight = 23
      ControlOptions.OriginalWidth = 154
      ControlOptions.ShowBorder = False
      Index = 1
    end
    object liGroupOrder: TdxLayoutItem
      Parent = grpGroups
      CaptionOptions.Text = 'S'#305'ralama'
      Control = spnGroupOrder
      ControlOptions.OriginalHeight = 23
      ControlOptions.OriginalWidth = 100
      ControlOptions.ShowBorder = False
      Index = 2
    end
    object liGroupActive: TdxLayoutItem
      Parent = grpGroups
      CaptionOptions.Visible = False
      Control = chkGroupActive
      ControlOptions.OriginalHeight = 21
      ControlOptions.OriginalWidth = 80
      ControlOptions.ShowBorder = False
      Index = 3
    end
    object grpGroupButtons: TdxLayoutGroup
      Parent = grpGroups
      LayoutDirection = ldHorizontal
      ShowBorder = False
      Index = 4
    end
    object liGroupNew: TdxLayoutItem
      Parent = grpGroupButtons
      CaptionOptions.Visible = False
      Control = btnGroupNew
      ControlOptions.OriginalHeight = 25
      ControlOptions.OriginalWidth = 120
      ControlOptions.ShowBorder = False
      Index = 0
    end
    object liGroupSave: TdxLayoutItem
      Parent = grpGroupButtons
      CaptionOptions.Visible = False
      Control = btnGroupSave
      ControlOptions.OriginalHeight = 25
      ControlOptions.OriginalWidth = 120
      ControlOptions.ShowBorder = False
      Index = 1
    end
    object liFields: TdxLayoutItem
      Parent = grpFields
      AlignHorz = ahClient
      CaptionOptions.Visible = False
      Control = lstFields
      ControlOptions.OriginalHeight = 140
      ControlOptions.OriginalWidth = 560
      ControlOptions.ShowBorder = False
      Index = 0
    end
    object liColumn: TdxLayoutItem
      Parent = grpFields
      CaptionOptions.Text = 'Kolon ad'#305
      Control = lblColumn
      ControlOptions.OriginalHeight = 23
      ControlOptions.OriginalWidth = 200
      ControlOptions.ShowBorder = False
      Index = 1
    end
    object liCaption: TdxLayoutItem
      Parent = grpFields
      AlignHorz = ahClient
      CaptionOptions.Text = 'Alan tan'#305'm'#305
      Control = edtCaption
      ControlOptions.OriginalHeight = 23
      ControlOptions.OriginalWidth = 440
      ControlOptions.ShowBorder = False
      Index = 2
    end
    object liType: TdxLayoutItem
      Parent = grpFields
      CaptionOptions.Text = 'Veri tipi'
      Control = cmbType
      ControlOptions.OriginalHeight = 23
      ControlOptions.OriginalWidth = 200
      ControlOptions.ShowBorder = False
      Index = 3
    end
    object liLength: TdxLayoutItem
      Parent = grpFields
      CaptionOptions.Text = 'Uzunluk'
      Control = spnLength
      ControlOptions.OriginalHeight = 23
      ControlOptions.OriginalWidth = 100
      ControlOptions.ShowBorder = False
      Index = 4
    end
    object liDecimals: TdxLayoutItem
      Parent = grpFields
      CaptionOptions.Text = 'Ondal'#305'k basamak'
      Control = spnDecimals
      ControlOptions.OriginalHeight = 23
      ControlOptions.OriginalWidth = 100
      ControlOptions.ShowBorder = False
      Index = 5
    end
    object liDefault: TdxLayoutItem
      Parent = grpFields
      AlignHorz = ahClient
      CaptionOptions.Text = 'Varsay'#305'lan'
      Control = edtDefault
      ControlOptions.OriginalHeight = 23
      ControlOptions.OriginalWidth = 440
      ControlOptions.ShowBorder = False
      Index = 6
    end
    object liOptions: TdxLayoutItem
      Parent = grpFields
      AlignHorz = ahClient
      CaptionOptions.AlignVert = tavTop
      CaptionOptions.Text = 'Se'#231'enekler (kod|ba'#351'l'#305'k)'
      Control = mmoOptions
      ControlOptions.OriginalHeight = 80
      ControlOptions.OriginalWidth = 440
      ControlOptions.ShowBorder = False
      Index = 7
    end
    object liOrder: TdxLayoutItem
      Parent = grpFields
      CaptionOptions.Text = 'S'#305'ralama'
      Control = spnOrder
      ControlOptions.OriginalHeight = 23
      ControlOptions.OriginalWidth = 100
      ControlOptions.ShowBorder = False
      Index = 8
    end
    object grpFlags: TdxLayoutGroup
      Parent = grpFields
      LayoutDirection = ldHorizontal
      ShowBorder = False
      Index = 9
    end
    object liRequired: TdxLayoutItem
      Parent = grpFlags
      CaptionOptions.Visible = False
      Control = chkRequired
      ControlOptions.OriginalHeight = 21
      ControlOptions.OriginalWidth = 63
      ControlOptions.ShowBorder = False
      Index = 0
    end
    object liFilterable: TdxLayoutItem
      Parent = grpFlags
      CaptionOptions.Visible = False
      Control = chkFilterable
      ControlOptions.OriginalHeight = 21
      ControlOptions.OriginalWidth = 56
      ControlOptions.ShowBorder = False
      Index = 1
    end
    object liActive: TdxLayoutItem
      Parent = grpFlags
      CaptionOptions.Visible = False
      Control = chkActive
      ControlOptions.OriginalHeight = 21
      ControlOptions.OriginalWidth = 46
      ControlOptions.ShowBorder = False
      Index = 2
    end
    object grpFieldButtons: TdxLayoutGroup
      Parent = grpFields
      LayoutDirection = ldHorizontal
      ShowBorder = False
      Index = 10
    end
    object liFieldNew: TdxLayoutItem
      Parent = grpFieldButtons
      CaptionOptions.Visible = False
      Control = btnFieldNew
      ControlOptions.OriginalHeight = 25
      ControlOptions.OriginalWidth = 120
      ControlOptions.ShowBorder = False
      Index = 0
    end
    object liFieldSave: TdxLayoutItem
      Parent = grpFieldButtons
      CaptionOptions.Visible = False
      Control = btnFieldSave
      ControlOptions.OriginalHeight = 25
      ControlOptions.OriginalWidth = 120
      ControlOptions.ShowBorder = False
      Index = 1
    end
    object liClose: TdxLayoutItem
      Parent = grpBottom
      CaptionOptions.Visible = False
      Control = btnClose
      ControlOptions.OriginalHeight = 25
      ControlOptions.OriginalWidth = 120
      ControlOptions.ShowBorder = False
      Index = 0
    end
  end
end
