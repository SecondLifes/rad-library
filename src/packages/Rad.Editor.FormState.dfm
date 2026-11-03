object RadFormStateEditorForm: TRadFormStateEditorForm
  Left = 0
  Top = 0
  Caption = 'Form Durumu'
  ClientHeight = 560
  ClientWidth = 880
  Color = clBtnFace
  Constraints.MinHeight = 420
  Constraints.MinWidth = 640
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnDestroy = FormDestroy
  TextHeight = 15
  object pgcMain: TPageControl
    Left = 0
    Top = 0
    Width = 880
    Height = 516
    ActivePage = tabProps
    Align = alClient
    TabOrder = 0
    object tabProps: TTabSheet
      Caption = #214'zellikler'
      object splSelected: TSplitter
        Left = 589
        Top = 37
        Height = 449
        Align = alRight
        ExplicitLeft = 600
      end
      object pnlTools: TPanel
        Left = 0
        Top = 0
        Width = 872
        Height = 37
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        object chkGroupByProperty: TCheckBox
          Left = 8
          Top = 9
          Width = 150
          Height = 19
          Caption = #214'zelli'#287'e g'#246're grupla'
          TabOrder = 0
          OnClick = ViewChanged
        end
        object chkOnlySelected: TCheckBox
          Left = 168
          Top = 9
          Width = 130
          Height = 19
          Caption = 'Yaln'#305'z se'#231'ililer'
          TabOrder = 1
          OnClick = ViewChanged
        end
        object btnPresetPage: TButton
          Left = 312
          Top = 5
          Width = 130
          Height = 27
          Hint = 'Sayfa ve sekme bile'#351'enlerinin ActivePageIndex/TabIndex/ItemIndex de'#287'erini se'#231'er'
          Caption = 'Haz'#305'r: sayfa/sekme'
          ParentShowHint = False
          ShowHint = True
          TabOrder = 2
          OnClick = btnPresetPageClick
        end
        object btnPresetSize: TButton
          Left = 448
          Top = 5
          Width = 150
          Height = 27
          Hint = 'Kenara yasl'#305' panellerin geni'#351'li'#287'i/y'#252'ksekli'#287'i (splitter konumu)'
          Caption = 'Haz'#305'r: splitter boyutlar'#305
          ParentShowHint = False
          ShowHint = True
          TabOrder = 3
          OnClick = btnPresetSizeClick
        end
      end
      object tlProps: TcxTreeList
        Left = 0
        Top = 37
        Width = 589
        Height = 449
        Align = alClient
        Bands = <
          item
          end>
        FindPanel.Behavior = fcbFilter
        FindPanel.DisplayMode = fpdmAlways
        FindPanel.InfoText = 'Bile'#351'en ya da '#246'zellik ara...'
        Navigator.Buttons.CustomButtons = <>
        OptionsCustomizing.BandCustomizing = False
        OptionsCustomizing.ColumnMoving = False
        OptionsData.Editing = False
        OptionsData.Deleting = False
        OptionsSelection.CellSelect = False
        OptionsView.CheckGroups = True
        OptionsView.ColumnAutoWidth = True
        ScrollbarAnnotations.CustomAnnotations = <>
        TabOrder = 1
        OnNodeCheckChanged = tlPropsNodeCheckChanged
        object colName: TcxTreeListColumn
          Caption.Text = 'Ad'
          Width = 230
          Position.ColIndex = 0
          Position.RowIndex = 0
          Position.BandIndex = 0
        end
        object colType: TcxTreeListColumn
          Caption.Text = 'T'#252'r'
          Width = 120
          Position.ColIndex = 1
          Position.RowIndex = 0
          Position.BandIndex = 0
        end
        object colValue: TcxTreeListColumn
          Caption.Text = 'De'#287'er'
          Width = 220
          Position.ColIndex = 2
          Position.RowIndex = 0
          Position.BandIndex = 0
        end
      end
      object pnlSelected: TPanel
        Left = 592
        Top = 37
        Width = 280
        Height = 449
        Align = alRight
        BevelOuter = bvNone
        TabOrder = 2
        object lblSelected: TLabel
          Left = 0
          Top = 0
          Width = 280
          Height = 15
          Align = alTop
          Caption = 'Kaydedilecekler'
        end
        object lstSelected: TListBox
          Left = 0
          Top = 15
          Width = 280
          Height = 397
          Align = alClient
          ItemHeight = 15
          TabOrder = 0
        end
        object pnlOrder: TPanel
          Left = 0
          Top = 412
          Width = 280
          Height = 37
          Align = alBottom
          BevelOuter = bvNone
          TabOrder = 1
          object btnUp: TButton
            Left = 0
            Top = 5
            Width = 75
            Height = 27
            Hint = 'S'#305'ra '#246'nemli: Align '#246'nce, boyut sonra'
            Caption = 'Yukar'#305
            ParentShowHint = False
            ShowHint = True
            TabOrder = 0
            OnClick = btnUpClick
          end
          object btnDown: TButton
            Left = 81
            Top = 5
            Width = 75
            Height = 27
            Caption = 'A'#351'a'#287#305
            TabOrder = 1
            OnClick = btnDownClick
          end
          object btnRemove: TButton
            Left = 162
            Top = 5
            Width = 75
            Height = 27
            Caption = #199#305'kar'
            TabOrder = 2
            OnClick = btnRemoveClick
          end
        end
      end
    end
    object tabValues: TTabSheet
      Caption = 'De'#287'erler'
      ImageIndex = 1
      object vleValues: TValueListEditor
        Left = 0
        Top = 0
        Width = 872
        Height = 486
        Align = alClient
        KeyOptions = [keyEdit, keyAdd, keyDelete, keyUnique]
        TabOrder = 0
        TitleCaptions.Strings = (
          'Ad'
          'Varsay'#305'lan de'#287'er')
        ColWidths = (
          220
          646)
      end
    end
    object tabOptions: TTabSheet
      Caption = 'Se'#231'enekler'
      ImageIndex = 2
      object lblVersion: TLabel
        Left = 16
        Top = 160
        Width = 80
        Height = 15
        Caption = 'S'#252'r'#252'm (Version)'
      end
      object lblStorageName: TLabel
        Left = 16
        Top = 212
        Width = 128
        Height = 15
        Caption = 'Kay'#305't ad'#305' eki (StorageName)'
      end
      object chkPlacement: TCheckBox
        Left = 16
        Top = 16
        Width = 400
        Height = 19
        Caption = 'Pencere yerle'#351'imi (konum, boyut, ekran durumu)'
        TabOrder = 0
      end
      object chkActiveControl: TCheckBox
        Left = 16
        Top = 41
        Width = 400
        Height = 19
        Caption = 'Odaktaki kontrol (ActiveControl)'
        TabOrder = 1
      end
      object chkProps: TCheckBox
        Left = 16
        Top = 66
        Width = 400
        Height = 19
        Caption = 'Se'#231'ili '#246'zellikler'
        TabOrder = 2
      end
      object chkValues: TCheckBox
        Left = 16
        Top = 91
        Width = 400
        Height = 19
        Caption = 'De'#287'erler (StoredValue)'
        TabOrder = 3
      end
      object chkCustom: TCheckBox
        Left = 16
        Top = 116
        Width = 400
        Height = 19
        Caption = 'IRadStateful bile'#351'enlerin kendi verisi'
        TabOrder = 4
      end
      object edtVersion: TEdit
        Left = 16
        Top = 181
        Width = 80
        Height = 23
        NumbersOnly = True
        TabOrder = 5
      end
      object edtStorageName: TEdit
        Left = 16
        Top = 233
        Width = 250
        Height = 23
        TabOrder = 6
      end
    end
  end
  object pnlButtons: TPanel
    Left = 0
    Top = 516
    Width = 880
    Height = 44
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object btnOk: TButton
      Left = 704
      Top = 9
      Width = 80
      Height = 27
      Caption = 'Tamam'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object btnCancel: TButton
      Left = 790
      Top = 9
      Width = 80
      Height = 27
      Cancel = True
      Caption = 'Vazge'#231
      ModalResult = 2
      TabOrder = 1
    end
  end
end
