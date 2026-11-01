program Probe2;

(* Sonda: hangi script govdesi INTERNAL ERROR veriyor (uses, Olay.Json, Log.Wait). Ana thread. *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants,
  Vcl.Forms,
  rad.script, rad.script.engine, rad.script.jobs;

type
  TLog = class
  public
    procedure Add(const S: string);
    procedure Wait(AMs: Integer);
  end;

procedure TLog.Add(const S: string);
begin
  Writeln('    log: ', S);
end;

procedure TLog.Wait(AMs: Integer);
begin
end;

function Dene(const ATag, ABody: string; AWithLib: Boolean): string;
var
  E: TRadScriptEngine;
  S, L: TRadScript;
  Ev: TRadScriptEvent;
  Lg: TLog;
begin
  E := TRadScriptEngine.Create;
  S := TRadScript.Create;
  L := TRadScript.Create;
  Ev := TRadScriptEvent.Create;
  Lg := TLog.Create;
  try
    try
      if AWithLib then
      begin
        L.Code := 'Lib';
        L.Source := 'function Onek: string; begin Result := ''olay:''; end;';
        E.AddScript(L);
      end;
      S.Code := 'Gelen';
      S.Source := 'procedure Calistir(Olay: TRadScriptEvent); begin ' + ABody + ' end;';
      if AWithLib then S.Source := 'uses Lib;'#13#10 + S.Source;
      E.AddScript(S);
      E.Expose('Olay', Ev);
      E.Expose('Log', Lg);
      E.Compile;
      E.Call('Gelen', 'Calistir', [Ev]);
      Result := ATag + ':ok';
    except
      on X: Exception do Result := ATag + ':' + X.ClassName + ':' + X.Message;
    end;
  finally
    Lg.Free;
    Ev.Free;
    L.Free;
    S.Free;
    E.Free;
  end;
end;

begin
  TRadScriptEngine.RegisterClass(TLog);
  Writeln('Q1 ', Dene('bos', '', False));
  Writeln('Q2 ', Dene('channel', 'Log.Add(Olay.Channel);', False));
  Writeln('Q3 ', Dene('json', 'Log.Add(Olay.Json);', False));
  Writeln('Q4 ', Dene('wait', 'Log.Wait(400);', False));
  Writeln('Q5 ', Dene('uses-bos', '', True));
  Writeln('Q6 ', Dene('uses-onek', 'Log.Add(Onek);', True));
  Writeln('Q7 ', Dene('uses-tam', 'Log.Add(Onek + Olay.Channel + ''|'' + Olay.Json); Log.Wait(400);', True));
  Writeln('Q8 ', Dene('concat', 'Log.Add(''a'' + Olay.Channel + ''|'' + Olay.Json);', False));
end.
