object RadScriptPackagesForm: TRadScriptPackagesForm
  Left = 0
  Top = 0
  Caption = 'Script paketleri'
  ClientHeight = 620
  ClientWidth = 980
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object spl: TSplitter
    Left = 0
    Top = 274
    Width = 980
    Height = 4
    Cursor = crVSplit
    Align = alTop
  end
  object pnlUst: TPanel
    Left = 0
    Top = 0
    Width = 980
    Height = 36
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object btnYeni: TButton
      Left = 8
      Top = 6
      Width = 90
      Height = 25
      Caption = 'Yeni paket'
      TabOrder = 0
      OnClick = btnYeniClick
    end
    object btnSil: TButton
      Left = 102
      Top = 6
      Width = 70
      Height = 25
      Caption = 'Sil'
      TabOrder = 1
      OnClick = btnSilClick
    end
    object btnIceAktar: TButton
      Left = 190
      Top = 6
      Width = 90
      Height = 25
      Caption = #304'e aktar...'
      TabOrder = 2
      OnClick = btnIceAktarClick
    end
    object btnDisaAktar: TButton
      Left = 284
      Top = 6
      Width = 96
      Height = 25
      Caption = 'D'#305#351'a aktar...'
      TabOrder = 3
      OnClick = btnDisaAktarClick
    end
    object btnIde: TButton
      Left = 398
      Top = 6
      Width = 90
      Height = 25
      Caption = 'IDE'#39'de a'#231
      TabOrder = 4
      OnClick = btnIdeClick
    end
    object btnTasarla: TButton
      Left = 492
      Top = 6
      Width = 80
      Height = 25
      Caption = 'Tasarla'
      TabOrder = 5
      OnClick = btnTasarlaClick
    end
    object btnYenile: TButton
      Left = 590
      Top = 6
      Width = 70
      Height = 25
      Caption = 'Yenile'
      TabOrder = 6
      OnClick = btnYenileClick
    end
  end
  object grdPaket: TcxGrid
    Left = 0
    Top = 36
    Width = 980
    Height = 238
    Align = alTop
    TabOrder = 1
    object vwPaket: TcxGridTableView
      Navigator.Buttons.CustomButtons = <>
      DataController.Summary.DefaultGroupSummaryItems = <>
      DataController.Summary.FooterSummaryItems = <>
      DataController.Summary.SummaryGroups = <>
      OptionsData.Deleting = False
      OptionsData.Inserting = False
      OptionsView.GroupByBox = False
      OnEditValueChanged = vwPaketEditValueChanged
      OnFocusedRecordChanged = vwPaketFocusedRecordChanged
      object colKod: TcxGridColumn
        Caption = 'Kod'
        Options.Editing = False
        Width = 160
      end
      object colAd: TcxGridColumn
        Caption = 'Ad'
        Width = 220
      end
      object colSurum: TcxGridColumn
        Caption = 'S'#252'r'#252'm'
        Width = 70
      end
      object colYazar: TcxGridColumn
        Caption = 'Yazar'
        Width = 120
      end
      object colSira: TcxGridColumn
        Caption = 'S'#305'ra'
        Width = 50
      end
      object colAktif: TcxGridColumn
        Caption = 'Aktif'
        PropertiesClassName = 'TcxCheckBoxProperties'
        Width = 50
      end
      object colKorumali: TcxGridColumn
        Caption = 'Korumal'#305
        PropertiesClassName = 'TcxCheckBoxProperties'
        Options.Editing = False
        Width = 70
      end
    end
    object lvlPaket: TcxGridLevel
      GridView = vwPaket
    end
  end
  object pcDetay: TcxPageControl
    Left = 0
    Top = 278
    Width = 980
    Height = 342
    Align = alClient
    TabOrder = 2
    Properties.ActivePage = tsScript
    Properties.CustomButtons.Buttons = <>
    object tsScript: TcxTabSheet
      Caption = 'Script'#39'ler'
      ImageIndex = 0
      object pnlScript: TPanel
        Left = 0
        Top = 0
        Width = 972
        Height = 32
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        object btnScriptYeni: TButton
          Left = 4
          Top = 4
          Width = 90
          Height = 25
          Caption = 'Yeni script'
          TabOrder = 0
          OnClick = btnScriptYeniClick
        end
        object btnScriptSil: TButton
          Left = 98
          Top = 4
          Width = 70
          Height = 25
          Caption = 'Sil'
          TabOrder = 1
          OnClick = btnScriptSilClick
        end
      end
      object grdScript: TcxGrid
        Left = 0
        Top = 32
        Width = 972
        Height = 282
        Align = alClient
        TabOrder = 1
        object vwScript: TcxGridTableView
          Navigator.Buttons.CustomButtons = <>
          DataController.Summary.DefaultGroupSummaryItems = <>
          DataController.Summary.FooterSummaryItems = <>
          DataController.Summary.SummaryGroups = <>
          OptionsData.Deleting = False
          OptionsData.Inserting = False
          OptionsView.GroupByBox = False
          OnEditValueChanged = vwScriptEditValueChanged
          OnFocusedRecordChanged = vwDetayFocusedRecordChanged
          object colSKod: TcxGridColumn
            Caption = 'Kod'
            Options.Editing = False
            Width = 140
          end
          object colSAd: TcxGridColumn
            Caption = 'Ad'
            Width = 220
          end
          object colSTur: TcxGridColumn
            Caption = 'T'#252'r'
            Options.Editing = False
            Width = 80
          end
          object colSHedef: TcxGridColumn
            Caption = 'Hedef'
            Width = 200
          end
          object colSSira: TcxGridColumn
            Caption = 'S'#305'ra'
            Width = 50
          end
          object colSAktif: TcxGridColumn
            Caption = 'Aktif'
            PropertiesClassName = 'TcxCheckBoxProperties'
            Width = 50
          end
        end
        object lvlScript: TcxGridLevel
          GridView = vwScript
        end
      end
    end
    object tsParam: TcxTabSheet
      Caption = 'Parametreler'
      ImageIndex = 1
      object grdParam: TcxGrid
        Left = 0
        Top = 0
        Width = 972
        Height = 314
        Align = alClient
        TabOrder = 0
        object vwParam: TcxGridTableView
          Navigator.Buttons.CustomButtons = <>
          DataController.Summary.DefaultGroupSummaryItems = <>
          DataController.Summary.FooterSummaryItems = <>
          DataController.Summary.SummaryGroups = <>
          OptionsData.Deleting = False
          OptionsData.Inserting = False
          OptionsView.GroupByBox = False
          OnEditValueChanged = vwParamEditValueChanged
          object colPAd: TcxGridColumn
            Caption = 'Ad'
            Options.Editing = False
            Width = 160
          end
          object colPDeger: TcxGridColumn
            Caption = 'De'#287'er'
            Width = 300
          end
          object colPAciklama: TcxGridColumn
            Caption = 'A'#231#305'klama'
            Options.Editing = False
            Width = 300
          end
        end
        object lvlParam: TcxGridLevel
          GridView = vwParam
        end
      end
    end
    object tsDb: TcxTabSheet
      Caption = 'DB ad'#305'mlar'#305
      ImageIndex = 2
      object pnlDb: TPanel
        Left = 0
        Top = 0
        Width = 972
        Height = 32
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        object btnDbUygula: TButton
          Left = 4
          Top = 4
          Width = 120
          Height = 25
          Caption = 'Bekleyenleri uygula'
          TabOrder = 0
          OnClick = btnDbUygulaClick
        end
      end
      object grdDb: TcxGrid
        Left = 0
        Top = 32
        Width = 972
        Height = 282
        Align = alClient
        TabOrder = 1
        object vwDb: TcxGridTableView
          Navigator.Buttons.CustomButtons = <>
          DataController.Summary.DefaultGroupSummaryItems = <>
          DataController.Summary.FooterSummaryItems = <>
          DataController.Summary.SummaryGroups = <>
          OptionsData.Deleting = False
          OptionsData.Editing = False
          OptionsData.Inserting = False
          OptionsView.GroupByBox = False
          object colDSira: TcxGridColumn
            Caption = 'S'#305'ra'
            Width = 50
          end
          object colDAciklama: TcxGridColumn
            Caption = 'A'#231#305'klama'
            Width = 400
          end
          object colDUygulandi: TcxGridColumn
            Caption = 'Uyguland'#305
            PropertiesClassName = 'TcxCheckBoxProperties'
            Width = 80
          end
          object colDZaman: TcxGridColumn
            Caption = 'Zaman'
            Width = 140
          end
        end
        object lvlDb: TcxGridLevel
          GridView = vwDb
        end
      end
    end
    object tsKaynak: TcxTabSheet
      Caption = 'Kaynaklar'
      ImageIndex = 3
      object pnlKaynak: TPanel
        Left = 0
        Top = 0
        Width = 972
        Height = 32
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        object btnKaynakDisa: TButton
          Left = 4
          Top = 4
          Width = 90
          Height = 25
          Caption = 'D'#305#351'a al...'
          TabOrder = 0
          OnClick = btnKaynakDisaClick
        end
        object btnKaynakIce: TButton
          Left = 98
          Top = 4
          Width = 90
          Height = 25
          Caption = 'Ekle/de'#287'i'#351'tir...'
          TabOrder = 1
          OnClick = btnKaynakIceClick
        end
        object btnKaynakSil: TButton
          Left = 192
          Top = 4
          Width = 70
          Height = 25
          Caption = 'Sil'
          TabOrder = 2
          OnClick = btnKaynakSilClick
        end
      end
      object grdKaynak: TcxGrid
        Left = 0
        Top = 32
        Width = 972
        Height = 282
        Align = alClient
        TabOrder = 1
        object vwKaynak: TcxGridTableView
          Navigator.Buttons.CustomButtons = <>
          DataController.Summary.DefaultGroupSummaryItems = <>
          DataController.Summary.FooterSummaryItems = <>
          DataController.Summary.SummaryGroups = <>
          OptionsData.Deleting = False
          OptionsData.Editing = False
          OptionsData.Inserting = False
          OptionsView.GroupByBox = False
          OnFocusedRecordChanged = vwDetayFocusedRecordChanged
          object colKDosya: TcxGridColumn
            Caption = 'Dosya'
            Width = 300
          end
          object colKBoyut: TcxGridColumn
            Caption = 'Boyut'
            Width = 90
          end
        end
        object lvlKaynak: TcxGridLevel
          GridView = vwKaynak
        end
      end
    end
  end
  object dlgAc: TOpenDialog
    Filter = 'Script paketi (*.radpaket)|*.radpaket|T'#252'm dosyalar (*.*)|*.*'
    Options = [ofHideReadOnly, ofFileMustExist, ofEnableSizing]
    Left = 880
    Top = 8
  end
  object dlgKaydet: TSaveDialog
    DefaultExt = 'radpaket'
    Filter = 'Script paketi (*.radpaket)|*.radpaket|T'#252'm dosyalar (*.*)|*.*'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Left = 920
    Top = 8
  end
end
