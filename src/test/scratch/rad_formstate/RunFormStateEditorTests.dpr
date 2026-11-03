program RunFormStateEditorTests;

{ rad.formstate design-time editor runner (scratch): model and DFM form without the IDE. }

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  Vcl.Forms,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  rad.formstate.core in '..\..\..\core\rad.formstate.core.pas',
  rad.formstate.store in '..\..\..\core\rad.formstate.store.pas',
  rad.formstate.component in '..\..\..\component\rad.formstate.component.pas',
  Rad.Editor.FormState.Model in '..\..\..\packages\Rad.Editor.FormState.Model.pas',
  Rad.Editor.FormState in '..\..\..\packages\Rad.Editor.FormState.pas' {RadFormStateEditorForm},
  FormStateTestA in 'FormStateTestA.pas' {FormA},
  FormStateEditorTests in 'FormStateEditorTests.pas';

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
