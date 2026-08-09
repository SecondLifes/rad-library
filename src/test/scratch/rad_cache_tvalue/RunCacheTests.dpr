program RunCacheTests;

{ rad.cache TValue geçişinin bağımsız test koşucusu (scratch).
  RunTests.dpr'ın vendor bağımlılıkları (dunitx vendor kopyası, Dext, mormot)
  bu makinede bulunmadığından, yalnız rad.cache testlerini RTL + Delphi'yle
  gelen DUnitX ($(BDS)\source\DUnitX) üzerinden derleyip koşar. }

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  rad.cache in '..\..\..\core\rad.cache.pas',
  rad.cache.Tests in '..\..\unit\rad.cache.Tests.pas';

var
  Runner : ITestRunner;
  Results: IRunResults;
begin
  try
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.AddLogger(TDUnitXConsoleLogger.Create(False));

    Results := Runner.Execute;

    if not Results.AllPassed then
      System.ExitCode := 1;
  except
    on E: Exception do
    begin
      System.Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := 2;
    end;
  end;
end.
