program RunTests;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ENDIF }
  System.Diagnostics,
  DUnitX.ConsoleWriter.Base in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.ConsoleWriter.Base.pas',
  DUnitX.DUnitCompatibility in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.DUnitCompatibility.pas',
  DUnitX.Generics in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.Generics.pas',
  DUnitX.InternalInterfaces in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.InternalInterfaces.pas',
  DUnitX.ServiceLocator in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.ServiceLocator.pas',
  DUnitX.Loggers.Console in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.Loggers.Console.pas',
  DUnitX.Loggers.Text in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.Loggers.Text.pas',
  DUnitX.Loggers.XML.NUnit in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.Loggers.XML.NUnit.pas',
  DUnitX.Loggers.XML.xUnit in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.Loggers.XML.xUnit.pas',
  DUnitX.MacOS.Console in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.MacOS.Console.pas',
  DUnitX.Test in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.Test.pas',
  DUnitX.TestFixture in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.TestFixture.pas',
  DUnitX.TestFramework in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.TestFramework.pas',
  DUnitX.TestResult in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.TestResult.pas',
  DUnitX.RunResults in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.RunResults.pas',
  DUnitX.TestRunner in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.TestRunner.pas',
  DUnitX.Utils in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.Utils.pas',
  DUnitX.Utils.XML in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.Utils.XML.pas',
  DUnitX.WeakReference in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.WeakReference.pas',
  DUnitX.Windows.Console in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.Windows.Console.pas',
  DUnitX.StackTrace.EurekaLog7 in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.StackTrace.EurekaLog7.pas',
  DUnitX.FixtureResult in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.FixtureResult.pas',
  DUnitX.Loggers.Null in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.Loggers.Null.pas',
  DUnitX.MemoryLeakMonitor.Default in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.MemoryLeakMonitor.Default.pas',
  DUnitX.Extensibility in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.Extensibility.pas',
  DUnitX.CommandLine.OptionDef in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.CommandLine.OptionDef.pas',
  DUnitX.CommandLine.Options in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.CommandLine.Options.pas',
  DUnitX.CommandLine.Parser in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.CommandLine.Parser.pas',
  DUnitX.FixtureProvider in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.FixtureProvider.pas',
  DUnitX.Timeout in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.Timeout.pas',
  DUnitX.Attributes in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.Attributes.pas',
  DUnitX.Linux.Console in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.Linux.Console.pas',
  DUnitX.FixtureBuilder in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.FixtureBuilder.pas',
  DUnitX.FilterBuilder in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.FilterBuilder.pas',
  DUnitX.Filters in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.Filters.pas',
  DUnitX.Loggers.XML.JUnit in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.Loggers.XML.JUnit.pas',
  DUnitX.OptionsDefinition in '..\vendor\vsofttechnologies\dunitx\Source\DUnitX.OptionsDefinition.pas',
  rad.cache.Benchmark.Tests in 'unit\rad.cache.Benchmark.Tests.pas',
  rad.cache.Tests in 'unit\rad.cache.Tests.pas',
  rad.cmd.Tests in 'unit\rad.cmd.Tests.pas',
  rad.eventbus.Benchmark in 'unit\rad.eventbus.Benchmark.pas',
  rad.eventbus.Tests in 'unit\rad.eventbus.Tests.pas',
  rad.thread.Tests in 'unit\rad.thread.Tests.pas',
  rad.utils.Tests in 'unit\rad.utils.Tests.pas';

{ keep comment here to protect the following conditional from being removed by the IDE when adding a unit }
{$IFNDEF TESTINSIGHT}
var
  runner : ITestRunner;
  results : IRunResults;
  logger : ITestLogger;
  stopWatch : TStopWatch;

  nunitLogger : ITestLogger;

{$ENDIF}
begin
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  {$ELSE}

  try
    //Check command line options, will exit if invalid
    TDUnitX.CheckCommandLine;
    //Create the runner
    runner := TDUnitX.CreateRunner;
    //Tell the runner to use RTTI to find Fixtures
    runner.UseRTTI := True;
    //When true, Assertions must be made during tests;
    runner.FailsOnNoAsserts := False;
    {$IFNDEF CI}
    TDUnitX.Options.ExitBehavior := TDUnitXExitBehavior.Pause;
    {$ELSE}
    //no point logging to the console, CI server will use the xml results and exit code.
    TDUnitX.Options.ConsoleMode := TDunitXConsoleMode.Off;
    {$ENDIF}
    //tell the runner how we will log things
    //Log to the console window if desired
    if TDUnitX.Options.ConsoleMode <> TDunitXConsoleMode.Off then
    begin
      logger := TDUnitXConsoleLogger.Create(TDUnitX.Options.ConsoleMode = TDunitXConsoleMode.Quiet);
      runner.AddLogger(logger);
    end;


    nunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    runner.AddLogger(nunitLogger);


    //Run tests
    stopWatch := TStopWatch.StartNew;
    results := runner.Execute;
    stopWatch.Stop;

    {$IFNDEF CI}
    //if TDUnitX.Options.ConsoleMode <> TDunitXConsoleMode.Off then
    //  System.Write(Format('Done in %d ms.. press <Enter> key to quit.', [stopWatch.ElapsedMilliseconds]));

    //We don't want this happening when running under CI.
    //if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
   //   System.Readln;
    {$ENDIF}

  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
  {$ENDIF}
end.

