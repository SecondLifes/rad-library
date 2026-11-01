unit rad.script.uni;

(* UniDAC sınıflarını script motoruna kaydeder. TUniConnection'ın bağlantı/parola üyeleri gizlenir:
   script yalnız InTransaction/Connected gibi masum üyeleri görür. Bkz. docs/specs/rad.script.facade.md *)

interface

uses
  Data.DB, Uni, DBAccess,
  rad.db, rad.script.engine;

/// TDataSet, TField, TUniQuery, TRadQuery, TUniConnection (gizli: Password, Username, Server, Database,
/// ConnectString, Port, ProviderName, SpecificOptions, Options).
procedure RegisterUniClasses;

implementation

procedure RegisterUniClasses;
begin
  TRadScriptEngine.RegisterClasses([TDataSet, TField, TUniQuery, TRadQuery]);
  TRadScriptEngine.RegisterClassHidden(TUniConnection,
    ['Password', 'Username', 'Server', 'Database', 'ConnectString', 'Port', 'ProviderName', 'SpecificOptions',
     'Options', 'EncryptedPassword', 'LoginPrompt', 'Open', 'Connect', 'Close', 'Disconnect']);
end;

end.
