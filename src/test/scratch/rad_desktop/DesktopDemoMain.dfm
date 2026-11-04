object DemoForm: TDemoForm
  Left = 0
  Top = 0
  Caption = 'ERP Masa'#252'st'#252' - rad.desktop demo'
  ClientHeight = 860
  ClientWidth = 1440
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Menu = mmMain
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object Desktop: TRADDesktopView
    Left = 0
    Top = 0
    Width = 1440
    Height = 832
    Align = alClient
    Images = ilIcons
    TabOrder = 0
  end
  object pnlStatus: TPanel
    Left = 0
    Top = 832
    Width = 1440
    Height = 28
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object lblStatus: TLabel
      Left = 12
      Top = 6
      Width = 3
      Height = 15
    end
  end
  object alMain: TActionList
    Images = ilIcons
    Left = 56
    Top = 64
    object actFatura: TAction
      Category = 'Sat'#305#351
      Caption = 'Sat'#305#351' Faturas'#305
      ImageIndex = 0
      OnExecute = ActionExecute
    end
    object actIrsaliye: TAction
      Category = 'Sat'#305#351
      Caption = 'Sat'#305#351' '#304'rsaliyesi'
      ImageIndex = 1
      OnExecute = ActionExecute
    end
    object actSiparis: TAction
      Category = 'Sat'#305#351
      Caption = 'Al'#305'nan Sipari'#351
      ImageIndex = 2
      OnExecute = ActionExecute
    end
    object actTeklif: TAction
      Category = 'Sat'#305#351
      Caption = 'Verilen Teklif'
      ImageIndex = 3
      OnExecute = ActionExecute
    end
    object actCari: TAction
      Category = 'Cari'
      Caption = 'Cari Kartlar'
      ImageIndex = 4
      OnExecute = ActionExecute
    end
    object actStok: TAction
      Category = 'Stok'
      Caption = 'Stok Kartlar'#305
      ImageIndex = 5
      OnExecute = ActionExecute
    end
    object actSayim: TAction
      Category = 'Stok'
      Caption = 'Stok Say'#305'm'#305
      ImageIndex = 6
      OnExecute = ActionExecute
    end
    object actTransfer: TAction
      Category = 'Stok'
      Caption = 'Depolar Aras'#305' Transfer'
      ImageIndex = 7
      OnExecute = ActionExecute
    end
    object actKasa: TAction
      Category = 'Finans'
      Caption = 'Kasa Hareketleri'
      ImageIndex = 8
      OnExecute = ActionExecute
    end
    object actBanka: TAction
      Category = 'Finans'
      Caption = 'Banka Hareketleri'
      ImageIndex = 9
      OnExecute = ActionExecute
    end
    object actCek: TAction
      Category = 'Finans'
      Caption = #199'ek Tahsilat'#305
      ImageIndex = 10
      OnExecute = ActionExecute
    end
    object actSenet: TAction
      Category = 'Finans'
      Caption = 'Senet Tahsilat'#305
      ImageIndex = 11
      OnExecute = ActionExecute
    end
    object actTahsilat: TAction
      Category = 'Finans'
      Caption = 'Cari Tahsilat'
      ImageIndex = 12
      OnExecute = ActionExecute
    end
    object actTediye: TAction
      Category = 'Finans'
      Caption = 'Cari Tediye'
      ImageIndex = 13
      OnExecute = ActionExecute
    end
    object actRapor: TAction
      Category = 'Raporlar'
      Caption = 'Sat'#305#351' Analizi'
      ImageIndex = 14
      OnExecute = ActionExecute
    end
    object actAyarlar: TAction
      Category = 'Sistem'
      Caption = 'Program Ayarlar'#305
      ImageIndex = 15
      OnExecute = ActionExecute
    end
    object actPersonel: TAction
      Category = 'Sistem'
      Caption = 'Personel Bordro'
      ImageIndex = 16
      OnExecute = ActionExecute
    end
    object actMail: TAction
      Category = 'Sat'#305#351
      Caption = 'E-Fatura G'#246'nder'
      ImageIndex = 17
      OnExecute = ActionExecute
    end
  end
  object ilIcons: TImageList
    ColorDepth = cd32Bit
    Height = 40
    Width = 40
    Left = 136
    Top = 64
  end
  object mmMain: TMainMenu
    Left = 216
    Top = 64
    object miDosya: TMenuItem
      Caption = '&Dosya'
      object miYedekAl: TMenuItem
        Caption = 'Yedek Al'
        OnClick = miYedekAlClick
      end
      object miCikis: TMenuItem
        Caption = #199#305'k'#305#351
        OnClick = miCikisClick
      end
    end
  end
end
