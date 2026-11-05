program RunSearchTests;

{ rad.search DUnitX runner (scratch): eşleştirici ve motor. build_and_run.bat Win32 RunSearchTests }

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  rad.search.match in '..\..\..\core\rad.search.match.pas',
  rad.search.core in '..\..\..\core\rad.search.core.pas',
  rad.search.match.Tests in '..\..\unit\rad.search.match.Tests.pas';

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
