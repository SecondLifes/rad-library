program RunDesktopTests;

{ rad.desktop core DUnitX runner (scratch): RTL, mORMot and DUnitX. }

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  rad.desktop.core in '..\..\..\core\rad.desktop.core.pas',
  rad.desktop.commands in '..\..\..\core\rad.desktop.commands.pas',
  rad.desktop.widgets in '..\..\..\core\rad.desktop.widgets.pas',
  rad.desktop.core.Tests in '..\..\unit\rad.desktop.core.Tests.pas';

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
