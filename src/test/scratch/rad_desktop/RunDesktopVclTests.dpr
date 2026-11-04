program RunDesktopVclTests;

{ rad.desktop view, store and facade DUnitX runner (scratch, VCL). }

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  Vcl.Forms,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  rad.desktop.core in '..\..\..\core\rad.desktop.core.pas',
  rad.desktop.commands in '..\..\..\core\rad.desktop.commands.pas',
  rad.desktop.widgets in '..\..\..\core\rad.desktop.widgets.pas',
  rad.desktop.store in '..\..\..\core\rad.desktop.store.pas',
  rad.desktop.paint in '..\..\..\component\rad.desktop.paint.pas',
  rad.desktop.view in '..\..\..\component\rad.desktop.view.pas',
  rad.desktop.dialogs in '..\..\..\component\rad.desktop.dialogs.pas' {RadDeskMenus: TDataModule},
  rad.desktop.picker in '..\..\..\component\rad.desktop.picker.pas' {RadDeskPickerForm},
  rad.desktop.sources in '..\..\..\component\rad.desktop.sources.pas',
  rad.desktop in '..\..\..\component\rad.desktop.pas',
  rad.desktop.view.Tests in '..\..\unit\rad.desktop.view.Tests.pas';

var
  LRunner: ITestRunner;
  LResults: IRunResults;
begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
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
