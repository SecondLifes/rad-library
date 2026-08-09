object Permission_Edit: TPermission_Edit
  Left = 0
  Top = 0
  Width = 440
  Height = 556
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = [fsBold]
  ParentFont = False
  TabOrder = 0
  object pnlAlt: TPanel
    Left = 0
    Top = 494
    Width = 440
    Height = 62
    Align = alBottom
    TabOrder = 0
    Visible = False
    object btn_ok: TcxButton
      Left = 165
      Top = 1
      Width = 274
      Height = 60
      Align = alClient
      Caption = 'Kaydet'
      OptionsImage.Glyph.SourceDPI = 96
      OptionsImage.Glyph.Data = {
        3C3F786D6C2076657273696F6E3D22312E302220656E636F64696E673D225554
        462D38223F3E0D0A3C7376672076657273696F6E3D22312E31222069643D224C
        61796572312220786D6C6E733D22687474703A2F2F7777772E77332E6F72672F
        323030302F7376672220786D6C6E733A786C696E6B3D22687474703A2F2F7777
        772E77332E6F72672F313939392F786C696E6B2220783D223070782220793D22
        307078222076696577426F783D2230203020333220333222207374796C653D22
        656E61626C652D6261636B67726F756E643A6E6577203020302033322033323B
        2220786D6C3A73706163653D227072657365727665223E262331333B26233130
        3B20203C7374796C6520747970653D22746578742F6373732220786D6C3A7370
        6163653D227072657365727665223E2E477265656E262331333B262331303B20
        2020207B262331333B262331303B20202020202066696C6C3A23303339433233
        3B262331333B262331303B202020202020666F6E742D66616D696C793A266170
        6F733B64782D666F6E742D69636F6E732661706F733B3B262331333B26233130
        3B202020202020666F6E742D73697A653A333270783B262331333B262331303B
        202020207D262331333B262331303B20203C2F7374796C653E0D0A3C74657874
        20783D22302220793D2233322220636C6173733D22477265656E223EEF8EBF3C
        2F746578743E0D0A3C2F7376673E0D0A}
      TabOrder = 0
      OnClick = btn_okClick
    end
    object btn_cancel: TcxButton
      Left = 1
      Top = 1
      Width = 164
      Height = 60
      Align = alLeft
      Caption = #304'ptal'
      ModalResult = 2
      OptionsImage.Glyph.SourceDPI = 96
      OptionsImage.Glyph.Data = {
        3C3F786D6C2076657273696F6E3D22312E302220656E636F64696E673D225554
        462D38223F3E0D0A3C7376672076657273696F6E3D22312E31222069643D224C
        61796572312220786D6C6E733D22687474703A2F2F7777772E77332E6F72672F
        323030302F7376672220786D6C6E733A786C696E6B3D22687474703A2F2F7777
        772E77332E6F72672F313939392F786C696E6B2220783D223070782220793D22
        307078222076696577426F783D2230203020333220333222207374796C653D22
        656E61626C652D6261636B67726F756E643A6E6577203020302033322033323B
        2220786D6C3A73706163653D227072657365727665223E262331333B26233130
        3B20203C7374796C6520747970653D22746578742F6373732220786D6C3A7370
        6163653D227072657365727665223E2E526564262331333B262331303B202020
        207B262331333B262331303B20202020202066696C6C3A234431314331433B26
        2331333B262331303B202020202020666F6E742D66616D696C793A2661706F73
        3B64782D666F6E742D69636F6E732661706F733B3B262331333B262331303B20
        2020202020666F6E742D73697A653A333270783B262331333B262331303B2020
        20207D262331333B262331303B20203C2F7374796C653E0D0A3C746578742078
        3D22302220793D2233322220636C6173733D22526564223EEF8F803C2F746578
        743E0D0A3C2F7376673E0D0A}
      TabOrder = 1
    end
  end
  object cxTree: TcxTreeList
    Left = 0
    Top = 0
    Width = 440
    Height = 494
    Align = alClient
    Bands = <
      item
      end>
    DragMode = dmAutomatic
    FindPanel.Behavior = fcbFilter
    FindPanel.DisplayMode = fpdmAlways
    FindPanel.InfoText = 'H'#305'zl'#305' Arama...'
    Navigator.Buttons.First.Visible = False
    Navigator.Buttons.PriorPage.Visible = False
    Navigator.Buttons.NextPage.Visible = False
    Navigator.Buttons.Last.Visible = False
    Navigator.Buttons.Append.Visible = True
    Navigator.Buttons.SaveBookmark.Visible = False
    Navigator.Buttons.GotoBookmark.Visible = False
    Navigator.Buttons.Filter.Visible = False
    OptionsBehavior.GoToNextCellOnEnter = True
    OptionsBehavior.GoToNextCellOnTab = True
    OptionsBehavior.AutoDragCopy = True
    OptionsBehavior.DragDropText = True
    OptionsBehavior.DragFocusing = True
    OptionsBehavior.ExpandOnIncSearch = True
    OptionsBehavior.FocusCellOnCycle = True
    OptionsBehavior.FocusFirstCellOnNewRecord = True
    OptionsBehavior.Sorting = False
    OptionsCustomizing.BandCustomizing = False
    OptionsCustomizing.BandHorzSizing = False
    OptionsCustomizing.BandMoving = False
    OptionsCustomizing.BandsQuickCustomizationShowCommands = False
    OptionsCustomizing.ColumnMoving = False
    OptionsCustomizing.ColumnsQuickCustomizationShowCommands = False
    OptionsData.Editing = False
    OptionsData.AnsiSort = True
    OptionsData.Deleting = False
    OptionsData.ImmediatePost = True
    OptionsData.MultiThreadedSorting = bTrue
    OptionsSelection.CellSelect = False
    OptionsView.ColumnAutoWidth = True
    OptionsView.CheckGroups = True
    OptionsView.DropNodeIndicator = True
    OptionsView.TreeLineStyle = tllsSolid
    PopupMenu = PopupMenu1
    ScrollbarAnnotations.CustomAnnotations = <>
    TabOrder = 1
    OnDblClick = cxTreeDblClick
    OnDragOver = cxTreeDragOver
    Data = {
      00000500F70000000F00000044617461436F6E74726F6C6C6572310200000012
      000000546378537472696E6756616C7565547970651200000054637853747269
      6E6756616C75655479706502000000445855464D5400000C0000004B0075006C
      006C0061006E003101630031016C006100720001445855464D5400000F000000
      4B0075006C006C0061006E0031016300310120004B0061007900310174000009
      00000075007300650072002E0065006400690074000100000000000000020801
      0000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF010000000808000000
      0000000000FFFFFFFFFFFFFFFFFFFFFFFF0A0801000000}
    object Col_adi: TcxTreeListColumn
      Caption.Text = 'Yetki Ad'#305
      Width = 266
      Position.ColIndex = 0
      Position.RowIndex = 0
      Position.BandIndex = 0
    end
    object Col_kod: TcxTreeListColumn
      Visible = False
      Caption.Text = 'Yetki Kodu'
      Width = 301
      Position.ColIndex = 1
      Position.RowIndex = 0
      Position.BandIndex = 0
    end
  end
  object Act_1: TActionList
    Left = 712
    Top = 616
    object act_append: TAction
      Tag = 1
      Caption = #304#231'ine Ekle'
      Enabled = False
      ShortCut = 16423
      Visible = False
      OnExecute = act_appendExecute
    end
    object act_ins: TAction
      Tag = 2
      Caption = 'Ekle'
      Enabled = False
      ShortCut = 16424
      Visible = False
      OnExecute = act_appendExecute
    end
    object act_expand: TAction
      AutoCheck = True
      Caption = 'T'#252'm'#252'n'#252' A'#231' / Kapat'
      ShortCut = 16433
      OnExecute = act_expandExecute
    end
    object act_yetkikodu_copy: TAction
      Tag = 3
      Caption = 'Yetki Kodunu Kopyala'
      OnExecute = act_appendExecute
    end
    object actFix: TAction
      Caption = 'ID Fix'
      Visible = False
      OnExecute = actFixExecute
    end
  end
  object PopupMenu1: TPopupMenu
    Left = 240
    Top = 328
    object Ekle1: TMenuItem
      Action = act_append
    end
    object Ekle2: TMenuItem
      Action = act_ins
    end
    object mnA1: TMenuItem
      Action = act_expand
      AutoCheck = True
    end
    object N1: TMenuItem
      Caption = '-'
    end
    object YetkiKodunuKopyala1: TMenuItem
      Action = act_yetkikodu_copy
    end
    object IDFix1: TMenuItem
      Action = actFix
    end
  end
end
