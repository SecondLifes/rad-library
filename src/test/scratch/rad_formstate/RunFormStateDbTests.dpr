program RunFormStateDbTests;

{ rad.formstate LIVE database runner (scratch): PostgreSQL, SQL Server, Firebird. See FormStateDbTests. }

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  rad.formstate.core in '..\..\..\core\rad.formstate.core.pas',
  rad.formstate.store in '..\..\..\core\rad.formstate.store.pas',
  rad.formstate.uni in '..\..\..\vendor\unidac\rad.formstate.uni.pas',
  FormStateDbTests in 'FormStateDbTests.pas';

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
