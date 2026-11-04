object RadDeskMenus: TRadDeskMenus
  OnDestroy = DataModuleDestroy
  Height = 240
  Width = 320
  object pmDesktop: TPopupMenu
    Left = 40
    Top = 24
    object miNewGroup: TMenuItem
      Caption = 'Yeni grup...'
      OnClick = miNewGroupClick
    end
    object miNewFolder: TMenuItem
      Caption = 'Yeni klas'#246'r...'
      OnClick = miNewFolderClick
    end
    object miDeskSep1: TMenuItem
      Caption = '-'
    end
    object miTheme: TMenuItem
      Caption = 'G'#246'r'#252'n'#252'm'
      object miThemeDark: TMenuItem
        Caption = 'Koyu'
        RadioItem = True
        OnClick = miThemeDarkClick
      end
      object miThemeLight: TMenuItem
        Caption = 'A'#231#305'k'
        RadioItem = True
        OnClick = miThemeLightClick
      end
    end
    object miDeskSep2: TMenuItem
      Caption = '-'
    end
    object miReset: TMenuItem
      Caption = 'Varsay'#305'lana d'#246'n'
      OnClick = miResetClick
    end
    object miSaveBase: TMenuItem
      Caption = #350'irket varsay'#305'lan'#305' olarak kaydet'
      OnClick = miSaveBaseClick
    end
  end
  object pmGroup: TPopupMenu
    Left = 128
    Top = 24
    object miGroupAdd: TMenuItem
      Caption = 'K'#305'sayol ekle...'
      OnClick = miGroupAddClick
    end
    object miGroupWidget: TMenuItem
      Caption = 'Widget ekle'
    end
    object miGroupDashboard: TMenuItem
      Caption = 'Dashboard ekle...'
      OnClick = miGroupDashboardClick
    end
    object miGroupSep1: TMenuItem
      Caption = '-'
    end
    object miGroupRename: TMenuItem
      Caption = 'Yeniden adland'#305'r...'
      OnClick = miGroupRenameClick
    end
    object miGroupColor: TMenuItem
      Caption = 'Renk'
    end
    object miGroupStyle: TMenuItem
      Caption = 'Klas'#246're d'#246'n'#252#351't'#252'r'
      OnClick = miGroupStyleClick
    end
    object miGroupCollapse: TMenuItem
      Caption = 'Daralt'
      OnClick = miGroupCollapseClick
    end
    object miGroupSep2: TMenuItem
      Caption = '-'
    end
    object miGroupDelete: TMenuItem
      Caption = 'Grubu kald'#305'r'
      OnClick = miGroupDeleteClick
    end
  end
  object pmItem: TPopupMenu
    Left = 216
    Top = 24
    object miItemOpen: TMenuItem
      Caption = 'A'#231
      Default = True
      OnClick = miItemOpenClick
    end
    object miItemRename: TMenuItem
      Caption = 'Yeniden adland'#305'r...'
      OnClick = miItemRenameClick
    end
    object miItemSize: TMenuItem
      Caption = 'Boyut'
      object miSizeSmall: TMenuItem
        Caption = 'K'#252#231#252'k'
        RadioItem = True
        OnClick = miSizeClick
      end
      object miSizeWide: TMenuItem
        Tag = 1
        Caption = 'Geni'#351
        RadioItem = True
        OnClick = miSizeClick
      end
      object miSizeLarge: TMenuItem
        Tag = 2
        Caption = 'B'#252'y'#252'k'
        RadioItem = True
        OnClick = miSizeClick
      end
    end
    object miItemSep1: TMenuItem
      Caption = '-'
    end
    object miItemRemove: TMenuItem
      Caption = 'Kald'#305'r'
      OnClick = miItemRemoveClick
    end
  end
end
