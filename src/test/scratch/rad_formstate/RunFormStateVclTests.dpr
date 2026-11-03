program RunFormStateVclTests;

{ rad.formstate VCL runner (scratch): DFM-loaded forms and a data module against a file store. }

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
  rad.formstate.dev in '..\..\..\component\rad.formstate.dev.pas',
  rad.formstate.rules in '..\..\..\component\rad.formstate.rules.pas',
  rad.formstate.customizer in '..\..\..\component\rad.formstate.customizer.pas',
  rad.formstate in '..\..\..\component\rad.formstate.pas',
  rad.rtl in '..\..\..\component\rad.rtl.pas',
  FormStateTestA in 'FormStateTestA.pas' {FormA},
  FormStateTestTwo in 'FormStateTestTwo.pas' {FormTwo},
  FormStateTestDm in 'FormStateTestDm.pas' {DmA: TDataModule},
  FormStateTestPlain in 'FormStateTestPlain.pas' {FormPlain},
  FormStateTestCustom in 'FormStateTestCustom.pas' {FormCustom},
  FormStateTestLink in 'FormStateTestLink.pas' {FormLink},
  FormStateVclTests in 'FormStateVclTests.pas',
  FormStateDevTests in 'FormStateDevTests.pas',
  FormStateCustomizerTests in 'FormStateCustomizerTests.pas',
  FormStateRulesTests in 'FormStateRulesTests.pas';

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
