object DmA: TDmA
  OnCreate = DataModuleCreate
  OnDestroy = DataModuleDestroy
  Height = 200
  Width = 300
  object Timer1: TTimer
    Enabled = False
    Left = 40
    Top = 24
  end
  object Store1: TRadPropertiesStore
    Items = <
      item
        Component = Timer1
        Properties.Strings = (
          'Interval')
      end>
    Left = 120
    Top = 24
  end
end
