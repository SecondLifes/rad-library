object frmSetting: TfrmSetting
  Left = 0
  Top = 0
  Width = 735
  Height = 669
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = [fsBold]
  ParentFont = False
  TabOrder = 0
  object lytSetting: TdxLayoutControl
    Left = 0
    Top = 0
    Width = 735
    Height = 669
    Align = alClient
    TabOrder = 0
    ExplicitLeft = 216
    ExplicitTop = 208
    ExplicitWidth = 300
    ExplicitHeight = 250
    object edtSearch: TcxButtonEdit
      Left = 68
      Top = 33
      Properties.Buttons = <
        item
          Default = True
          Kind = bkEllipsis
        end>
      Style.HotTrack = False
      Style.TransparentBorder = False
      TabOrder = 0
      Text = 'edtSearch'
      Width = 641
    end
    object lblID: TcxLabel
      Left = 213
      Top = 586
      BiDiMode = bdRightToLeft
      Caption = 'fatura.satis.vade_asim_uyar'
      Enabled = False
      ParentBiDiMode = False
      Style.HotTrack = False
      Style.TransparentBorder = False
      TabOrder = 6
      Transparent = True
    end
    object lblBaslik: TcxLabel
      Left = 213
      Top = 517
      AutoSize = False
      Caption = 'Vade a'#351#305'm'#305'nda uyar'
      Style.HotTrack = False
      Style.TransparentBorder = False
      TabOrder = 3
      Transparent = True
      Height = 15
      Width = 333
    end
    object lblGrup: TcxLabel
      Left = 553
      Top = 517
      BiDiMode = bdRightToLeft
      Caption = 'Fatura '#8250' Sat'#305#351
      Enabled = False
      ParentBiDiMode = False
      Style.HotTrack = False
      Style.TransparentBorder = False
      TabOrder = 4
      Transparent = True
    end
    object lblInfo: TcxLabel
      Left = 213
      Top = 539
      AutoSize = False
      Caption = 'A'#231#305'klama'
      Style.HotTrack = False
      Style.TransparentBorder = False
      TabOrder = 5
      Transparent = True
      Height = 40
      Width = 496
    end
    object dxNavBar: TdxNavBar
      Left = 27
      Top = 99
      Width = 150
      Height = 501
      ActiveGroupIndex = 0
      TabOrder = 1
      View = 21
      ViewStyle.SkinNameAssigned = True
      OptionsView.HamburgerMenu.NavigationPaneMode = npmNone
    end
    object cxVerticalGrid1: TcxVerticalGrid
      Left = 213
      Top = 98
      Width = 496
      Height = 377
      OptionsView.RowHeaderWidth = 129
      TabOrder = 2
      Version = 1
    end
    object lytSettingGroup_Root: TdxLayoutGroup
      AlignHorz = ahClient
      AlignVert = avClient
      Hidden = True
      ItemIndex = 1
      Locked = True
      ShowBorder = False
      Index = -1
    end
    object grpArama: TdxLayoutGroup
      Parent = lytSettingGroup_Root
      AlignHorz = ahClient
      AlignVert = avTop
      CaptionOptions.Text = 'New Group'
      CaptionOptions.Visible = False
      Index = 0
    end
    object grpGrup: TdxLayoutGroup
      Parent = dxLayoutAutoCreatedGroup1
      CaptionOptions.Text = 'Kategori'
      Index = 0
    end
    object grpData: TdxLayoutGroup
      Parent = dxLayoutAutoCreatedGroup2
      AlignHorz = ahClient
      AlignVert = avClient
      CaptionOptions.Text = 'Ayarlar'
      Index = 0
    end
    object grpInfo: TdxLayoutGroup
      Parent = dxLayoutAutoCreatedGroup2
      CaptionOptions.Text = 'A'#231#305'klama'
      Index = 1
    end
    object dxLayoutItem1: TdxLayoutItem
      Parent = grpArama
      CaptionOptions.Text = 'Arama'
      Control = edtSearch
      ControlOptions.OriginalHeight = 23
      ControlOptions.OriginalWidth = 121
      ControlOptions.ShowBorder = False
      Index = 0
    end
    object dxLayoutAutoCreatedGroup1: TdxLayoutAutoCreatedGroup
      Parent = lytSettingGroup_Root
      AlignVert = avClient
      LayoutDirection = ldHorizontal
      Index = 1
    end
    object dxLayoutAutoCreatedGroup2: TdxLayoutAutoCreatedGroup
      Parent = dxLayoutAutoCreatedGroup1
      AlignHorz = ahClient
      Index = 1
    end
    object grpIslem: TdxLayoutGroup
      Parent = lytSettingGroup_Root
      CaptionOptions.Text = 'New Group'
      CaptionOptions.Visible = False
      Index = 2
    end
    object dxLayoutItem2: TdxLayoutItem
      Parent = grpInfo
      CaptionOptions.Text = 'cxLabel1'
      CaptionOptions.Visible = False
      Control = lblID
      ControlOptions.OriginalHeight = 15
      ControlOptions.OriginalWidth = 121
      ControlOptions.ShowBorder = False
      Enabled = False
      Index = 2
    end
    object dxLayoutItem3: TdxLayoutItem
      Parent = dxLayoutAutoCreatedGroup3
      AlignHorz = ahClient
      AlignVert = avTop
      CaptionOptions.Text = 'cxLabel2'
      CaptionOptions.Visible = False
      Control = lblBaslik
      ControlOptions.OriginalHeight = 15
      ControlOptions.OriginalWidth = 105
      ControlOptions.ShowBorder = False
      Index = 0
    end
    object dxLayoutItem4: TdxLayoutItem
      Parent = dxLayoutAutoCreatedGroup3
      AlignHorz = ahClient
      AlignVert = avTop
      CaptionOptions.Text = 'cxLabel3'
      CaptionOptions.Visible = False
      Control = lblGrup
      ControlOptions.OriginalHeight = 15
      ControlOptions.OriginalWidth = 49
      ControlOptions.ShowBorder = False
      Enabled = False
      Index = 1
    end
    object dxLayoutAutoCreatedGroup3: TdxLayoutAutoCreatedGroup
      Parent = grpInfo
      LayoutDirection = ldHorizontal
      Index = 0
    end
    object dxLayoutItem5: TdxLayoutItem
      Parent = grpInfo
      AlignHorz = ahClient
      CaptionOptions.Text = 'cxLabel1'
      CaptionOptions.Visible = False
      Control = lblInfo
      ControlOptions.OriginalHeight = 40
      ControlOptions.OriginalWidth = 121
      ControlOptions.ShowBorder = False
      Index = 1
    end
    object dxLayoutItem6: TdxLayoutItem
      Parent = grpGrup
      AlignHorz = ahClient
      AlignVert = avClient
      CaptionOptions.Text = 'navMenu'
      CaptionOptions.Visible = False
      Control = dxNavBar
      ControlOptions.AutoColor = True
      ControlOptions.OriginalHeight = 300
      ControlOptions.OriginalWidth = 150
      Index = 0
    end
    object lytPropStore: TdxLayoutItem
      Parent = grpData
      AlignHorz = ahClient
      AlignVert = avClient
      CaptionOptions.Text = 'cxVerticalGrid1'
      CaptionOptions.Visible = False
      Control = cxVerticalGrid1
      ControlOptions.OriginalHeight = 200
      ControlOptions.OriginalWidth = 150
      ControlOptions.ShowBorder = False
      Index = 0
    end
  end
end
