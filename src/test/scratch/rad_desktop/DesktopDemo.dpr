program DesktopDemo;

{ rad.desktop demo. DesktopDemo.exe --shot <folder> writes PNG snapshots and exits; any error goes to
  <folder>\error.txt instead of a dialog, so an unattended run can never hang. }

uses
  System.SysUtils,
  System.IOUtils,
  Vcl.Forms,
  Vcl.XPMan,
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
  DesktopDemoMain in 'DesktopDemoMain.pas' {DemoForm};

procedure RunShots(const AFolder: string);
begin
  ForceDirectories(AFolder);
  try
    Application.CreateForm(TDemoForm, DemoForm);
    DemoForm.Show;
    DemoForm.Shots(AFolder);
    DemoForm.Free;
  except
    on E: Exception do
      TFile.WriteAllText(TPath.Combine(AFolder, 'error.txt'), E.ClassName + ': ' + E.Message);
  end;
end;

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  if FindCmdLineSwitch('shot') then
  begin
    RunShots(ParamStr(ParamCount));
    Exit;
  end;
  ReportMemoryLeaksOnShutdown := True;
  Application.CreateForm(TDemoForm, DemoForm);
  Application.Run;
end.
