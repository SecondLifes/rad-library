object RadReportManageForm: TRadReportManageForm
  Left = 0
  Top = 0
  Caption = 'Raporlar'
  ClientHeight = 640
  ClientWidth = 1040
  Position = poScreenCenter
  TextHeight = 15
  object grdDesign: TcxGrid
    Left = 0
    Top = 140
    Width = 1040
    Height = 300
    Align = alClient
    PopupMenu = PopupDesign
    TabOrder = 0
    object viewDesign: TcxGridTableView
      Navigator.Buttons.CustomButtons = <>
      ScrollbarAnnotations.CustomAnnotations = <>
      DataController.Summary.DefaultGroupSummaryItems = <>
      DataController.Summary.FooterSummaryItems = <>
      DataController.Summary.SummaryGroups = <>
      OnDblClick = viewDesignDblClick
      OnFocusedRecordChanged = viewDesignFocusedRecordChanged
      OptionsData.Deleting = False
      OptionsData.Editing = False
      OptionsData.Inserting = False
      OptionsSelection.CellSelect = False
      OptionsView.GroupByBox = False
      object colName: TcxGridColumn
        Caption = 'Tasar'#305'm'
        DataBinding.ValueType = 'String'
        Width = 260
      end
      object colDefault: TcxGridColumn
        Caption = 'Varsay'#305'lan'
        DataBinding.ValueType = 'String'
        Width = 90
      end
      object colVersion: TcxGridColumn
        Caption = 'S'#252'r'#252'm'
        DataBinding.ValueType = 'Integer'
        Width = 60
      end
      object colTemplate: TcxGridColumn
        Caption = 'Dosya ad'#305' '#351'ablonu'
        DataBinding.ValueType = 'String'
        Width = 240
      end
      object colUpdatedBy: TcxGridColumn
        Caption = 'Son de'#287'i'#351'tiren'
        DataBinding.ValueType = 'String'
        Width = 120
      end
      object colUpdatedAt: TcxGridColumn
        Caption = 'Tarih'
        DataBinding.ValueType = 'DateTime'
        Width = 140
      end
    end
    object lvlDesign: TcxGridLevel
      GridView = viewDesign
    end
  end
  object grdVersion: TcxGrid
    Left = 0
    Top = 140
    Width = 1040
    Height = 190
    Align = alBottom
    PopupMenu = PopupVersion
    TabOrder = 1
    object viewVersion: TcxGridTableView
      Navigator.Buttons.CustomButtons = <>
      ScrollbarAnnotations.CustomAnnotations = <>
      DataController.Summary.DefaultGroupSummaryItems = <>
      DataController.Summary.FooterSummaryItems = <>
      DataController.Summary.SummaryGroups = <>
      OptionsData.Deleting = False
      OptionsData.Editing = False
      OptionsData.Inserting = False
      OptionsSelection.CellSelect = False
      OptionsView.GroupByBox = False
      object colVNo: TcxGridColumn
        Caption = 'S'#252'r'#252'm'
        DataBinding.ValueType = 'Integer'
        Width = 60
      end
      object colVDate: TcxGridColumn
        Caption = 'Tarih'
        DataBinding.ValueType = 'DateTime'
        Width = 140
      end
      object colVUser: TcxGridColumn
        Caption = 'Kaydeden'
        DataBinding.ValueType = 'String'
        Width = 110
      end
      object colVSize: TcxGridColumn
        Caption = 'Boyut (bayt)'
        DataBinding.ValueType = 'Integer'
        Width = 100
      end
      object colVNote: TcxGridColumn
        Caption = 'Not'
        DataBinding.ValueType = 'String'
        Width = 320
      end
    end
    object lvlVersion: TcxGridLevel
      GridView = viewVersion
    end
  end
  object splVersion: TSplitter
    Left = 0
    Top = 446
    Width = 1040
    Height = 4
    Cursor = crVSplit
    Align = alBottom
  end
  object ActionList: TActionList
    OnUpdate = ActionListUpdate
    object actRefresh: TAction
      Caption = 'Yenile'
      OnExecute = actRefreshExecute
    end
    object actPreview: TAction
      Caption = #214'nizle'
      OnExecute = actPreviewExecute
    end
    object actDesign: TAction
      Caption = 'Tasarla'
      OnExecute = actDesignExecute
    end
    object actNewDesign: TAction
      Caption = 'Yeni tasar'#305'm'
      OnExecute = actNewDesignExecute
    end
    object actCopy: TAction
      Caption = 'Kopyala'
      OnExecute = actCopyExecute
    end
    object actSetDefault: TAction
      Caption = 'Varsay'#305'lan yap'
      OnExecute = actSetDefaultExecute
    end
    object actDelete: TAction
      Caption = 'Kal'#305'c'#305' sil'
      OnExecute = actDeleteExecute
    end
    object actRestore: TAction
      Caption = 'Geri y'#252'kle'
      OnExecute = actRestoreExecute
    end
    object actDeleteOld: TAction
      Caption = 'Eskileri sil'
      OnExecute = actDeleteOldExecute
    end
    object actReset: TAction
      Caption = 'S'#252'r'#252'm'#252' s'#305'f'#305'rla'
      OnExecute = actResetExecute
    end
    object actSyncToLocal: TAction
      Caption = 'Yerele e'#351'itle'
      OnExecute = actSyncToLocalExecute
    end
    object actPushFromLocal: TAction
      Caption = 'De'#287'i'#351'ikli'#287'i y'#252'kle'
      OnExecute = actPushFromLocalExecute
    end
    object actOpenFolder: TAction
      Caption = 'Klas'#246'r'#252' a'#231
      OnExecute = actOpenFolderExecute
    end
  end
  object PopupDesign: TPopupMenu
    object mnuPreview: TMenuItem
      Action = actPreview
    end
    object mnuDesign: TMenuItem
      Action = actDesign
    end
    object mnuNewDesign: TMenuItem
      Action = actNewDesign
    end
    object mnuCopy: TMenuItem
      Action = actCopy
    end
    object mnuSetDefault: TMenuItem
      Action = actSetDefault
    end
    object mnuDelete: TMenuItem
      Action = actDelete
    end
    object mnuSep1: TMenuItem
      Caption = '-'
    end
    object mnuSyncToLocal: TMenuItem
      Action = actSyncToLocal
    end
    object mnuPushFromLocal: TMenuItem
      Action = actPushFromLocal
    end
  end
  object PopupVersion: TPopupMenu
    object mnuRestore: TMenuItem
      Action = actRestore
    end
    object mnuDeleteOld: TMenuItem
      Action = actDeleteOld
    end
    object mnuReset: TMenuItem
      Action = actReset
    end
  end
end
