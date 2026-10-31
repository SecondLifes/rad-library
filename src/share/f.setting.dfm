object F_Setting: TF_Setting
  Left = 0
  Top = 0
  Caption = 'F_Setting'
  ClientHeight = 641
  ClientWidth = 780
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = [fsBold]
  TextHeight = 15
  object lytSetting: TdxLayoutControl
    Left = 0
    Top = 0
    Width = 780
    Height = 641
    Align = alClient
    TabOrder = 0
    ExplicitWidth = 651
    ExplicitHeight = 554
    object edtSearch: TcxButtonEdit
      Left = 61
      Top = 21
      Properties.Buttons = <
        item
          Default = True
          Glyph.SourceDPI = 96
          Glyph.Data = {
            3C3F786D6C2076657273696F6E3D22312E302220656E636F64696E673D225554
            462D38223F3E0D0A3C7376672076657273696F6E3D22312E31222069643D224C
            617965725F312220786D6C6E733D22687474703A2F2F7777772E77332E6F7267
            2F323030302F7376672220786D6C6E733A786C696E6B3D22687474703A2F2F77
            77772E77332E6F72672F313939392F786C696E6B2220783D223070782220793D
            22307078222076696577426F783D2230203020333220333222207374796C653D
            22656E61626C652D6261636B67726F756E643A6E657720302030203332203332
            3B2220786D6C3A73706163653D227072657365727665223E262331333B262331
            303B3C7374796C6520747970653D22746578742F6373732220786D6C3A737061
            63653D227072657365727665223E2E426C61636B7B66696C6C3A233732373237
            323B7D262331333B262331303B2623393B2E57686974657B66696C6C3A234646
            464646463B7D3C2F7374796C653E0D0A3C7061746820636C6173733D22426C61
            636B2220643D224D32362C36682D3463302D302E332C302D302E362C302D3156
            3463302D322D322D322D342D32682D326C302C30632D322C302D342C302D342C
            32763163302C302E342C302C302E372C302C31483843362E392C362C362C362E
            392C362C38763268326831386832563820202623393B4332382C362E392C3237
            2E312C362C32362C367A222F3E0D0A3C7061746820636C6173733D2257686974
            652220643D224D31392C34682D34632D302E352C302D312C302E342D312C3176
            3063302C302E352C302C312C302C31683663302C302C302D302E342C302D3176
            304332302C342E342C31392E362C342C31392C347A222F3E0D0A3C7061746820
            636C6173733D22426C61636B2220643D224D382C313276313663302C312E312C
            302E392C322C322C3268313463312E312C302C322D302E392C322D3263302D31
            2E312C302D31362C302D313648387A204D31322C3238682D3256313468325632
            387A204D31362C3238682D3256313468325632387A20202623393B204D32302C
            3238682D3256313468325632387A204D32342C3238682D325631346832563238
            7A222F3E0D0A3C2F7376673E0D0A}
          Kind = bkGlyph
        end>
      Style.HotTrack = False
      Style.TransparentBorder = False
      TabOrder = 0
      Width = 698
    end
    object dxNavBar: TdxNavBar
      Left = 22
      Top = 108
      Width = 263
      Height = 511
      Color = 16053492
      ActiveGroupIndex = -1
      TabOrder = 1
      View = 21
      ViewStyle.SkinNameAssigned = True
      OptionsView.HamburgerMenu.NavigationPaneMode = npmNone
    end
    object Pages: TcxPageControl
      Left = 315
      Top = 107
      Width = 444
      Height = 513
      Color = 16053492
      ParentBackground = False
      ParentColor = False
      TabOrder = 2
      Properties.CustomButtons.Buttons = <>
      ClientRectBottom = 512
      ClientRectLeft = 1
      ClientRectRight = 443
      ClientRectTop = 1
    end
    object lytSettingGroup_Root: TdxLayoutGroup
      AlignHorz = ahClient
      AlignVert = avClient
      Hidden = True
      ItemIndex = 1
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
      Parent = dxLayoutAutoCreatedGroup1
      AlignHorz = ahClient
      AlignVert = avClient
      CaptionOptions.Text = 'Ayarlar'
      Locked = True
      UseIndent = False
      Index = 1
    end
    object dxLayoutItem1: TdxLayoutItem
      Parent = grpArama
      CaptionOptions.Text = 'Arama'
      Control = edtSearch
      ControlOptions.OriginalHeight = 34
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
    object dxLayoutItem6: TdxLayoutItem
      Parent = grpGrup
      AlignHorz = ahClient
      AlignVert = avClient
      SizeOptions.AssignedValues = [sovSizableHorz]
      SizeOptions.SizableHorz = True
      SizeOptions.Width = 265
      CaptionOptions.Text = 'navMenu'
      CaptionOptions.Visible = False
      Control = dxNavBar
      ControlOptions.AutoColor = True
      ControlOptions.OriginalHeight = 300
      ControlOptions.OriginalWidth = 150
      Index = 0
    end
    object dxLayoutItem2: TdxLayoutItem
      Parent = grpData
      AlignHorz = ahClient
      AlignVert = avClient
      CaptionOptions.Text = 'cxPageControl1'
      CaptionOptions.Visible = False
      Control = Pages
      ControlOptions.AutoColor = True
      ControlOptions.OriginalHeight = 193
      ControlOptions.OriginalWidth = 289
      ControlOptions.ShowBorder = False
      Index = 0
    end
  end
  object dsAyar: TUniDataSource
    Left = 64
    Top = 480
  end
end
