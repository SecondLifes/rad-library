object dm_dev: Tdm_dev
  OnCreate = DataModuleCreate
  OnDestroy = DataModuleDestroy
  Height = 557
  Width = 720
  object SkinController: TdxSkinController
    NativeStyle = False
    SkinName = 'WXICompact'
    Left = 584
    Top = 8
  end
  object cxLookAndFeelController: TcxLookAndFeelController
    NativeStyle = False
    SkinName = 'WXICompact'
    Left = 640
    Top = 8
  end
  object dxLayoutLookAndFeelList: TdxLayoutLookAndFeelList
    Left = 520
    Top = 16
    object dxLayoutSkin: TdxLayoutSkinLookAndFeel
      PixelsPerInch = 96
    end
  end
  object EditRepository: TcxEditRepository
    Left = 576
    Top = 72
    PixelsPerInch = 96
    object Edit_Password: TcxEditRepositoryTextItem
      Properties.PasswordChar = '*'
      Properties.ShowPasswordRevealButton = True
    end
    object Edit_tel: TcxEditRepositoryMaskItem
      Properties.EditMask = '!\(999\)999-9999;1;_'
      Properties.OnValidate = Edit_telPropertiesValidate
    end
  end
  object StyleRepository: TcxStyleRepository
    Left = 648
    Top = 64
    PixelsPerInch = 96
  end
  object DefaultEditStyle: TcxDefaultEditStyleController
    StyleFocused.Color = 3074027
    StyleFocused.TextColor = clBlack
    Left = 640
    Top = 152
    PixelsPerInch = 96
  end
end
