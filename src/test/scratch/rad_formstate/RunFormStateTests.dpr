program RunFormStateTests;

{ rad.formstate DUnitX runner (scratch): RTL, mORMot and the DUnitX shipped with Delphi. }

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  rad.formstate.core in '..\..\..\core\rad.formstate.core.pas',
  rad.formstate.core.Tests in '..\..\unit\rad.formstate.core.Tests.pas';

var
  LRunner: ITestRunner;
  LResults: IRunResults;
begin
  ReportMemoryLeaksOnShutdown := True;
  try
    LRunner := TDUnitX.CreateRunner;
    LRunner.UseRTTI := True;
    LRunner.AddLogger(TDUnitXConsoleLogger.Create(True));
    LResults := LRunner.Execute;
    if not LResults.AllPassed then
      System.ExitCode := 1;
  except
    on E: Exception do
    begin
      System.Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := 2;
    end;
  end;
end.
