unit rad.script.commands;

(* `komut` türü: modül sınıfına bağlı script'ler menüye komut ekler; alt program `<Kod>_Execute(Sender)`.
   Host (ERPPlus Tbase_modul.Register) AAdd ile kendi TAction'ını üretir. Bkz. docs/specs/rad.script.facade.md *)

interface

uses
  System.SysUtils, System.Classes,
  rad.script, rad.script.engine, rad.script.hooks;

type
  TRadScriptAddCommand = reference to procedure(const ACode, ACaption: string; AOnExecute: TNotifyEvent);

  /// Bir komut script'inin çalıştırıcısı; motorun sahipliğinde.
  TRadScriptCommand = class
  private
    FAttachment: TRadScriptAttachment;
    FCode: string;
    FRoutine: string;
  public
    constructor Create(AAttachment: TRadScriptAttachment; const ACode: string);
    procedure Execute(Sender: TObject);
    property Code: string read FCode;
  end;

  TRadScriptCommands = class
  public
    /// Modül sınıfı (ve ataları) için `komut` script'lerini yükler, her biri için AAdd çağırır. Script yoksa nil.
    class function Attach(AModule: TComponent; const AAdd: TRadScriptAddCommand): TRadScriptAttachment;
  end;

implementation

uses
  Vcl.Forms;

const
  SUFFIX_EXECUTE = '_Execute';

{ TRadScriptCommand }

constructor TRadScriptCommand.Create(AAttachment: TRadScriptAttachment; const ACode: string);
begin
  inherited Create;
  FAttachment := AAttachment;
  FCode := ACode;
  FRoutine := ACode + SUFFIX_EXECUTE;
end;

procedure TRadScriptCommand.Execute(Sender: TObject);
begin
  try
    FAttachment.Engine.Call(FCode, FRoutine, [Sender]);
  except
    on E: Exception do
      if Assigned(TRadScriptBinder.OnError) then TRadScriptBinder.OnError(nil, E)
      else Application.ShowException(E);
  end;
end;

{ TRadScriptCommands }

class function TRadScriptCommands.Attach(AModule: TComponent; const AAdd: TRadScriptAddCommand): TRadScriptAttachment;
var
  S: TRadScript;
  LCmd: TRadScriptCommand;
begin
  Result := TRadScriptBinder.LoadInto(AModule, skCommand, TRadScriptBinder.ClassChain(AModule));
  if Result = nil then Exit;
  for S in Result.Scripts do
  begin
    if not Result.Engine.HasRoutine(S.Code, S.Code + SUFFIX_EXECUTE) then
    begin
      if Assigned(TRadScriptBinder.OnWarning) then
        TRadScriptBinder.OnWarning(Format('%s: "%s" komut script''inde %s%s yok.', [AModule.ClassName, S.Code, S.Code, SUFFIX_EXECUTE]));
      Continue;
    end;
    LCmd := TRadScriptCommand.Create(Result, S.Code);
    Result.Engine.AddOwned(LCmd);
    AAdd(S.Code, S.Name, LCmd.Execute);
  end;
end;

end.
