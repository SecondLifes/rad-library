program RunDesktopScriptTests;

{ rad.desktop.script DUnitX runner: widget routines of library scripts run through TMS Scripter. }

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  Vcl.Forms,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  rad.script,
  rad.script.engine,
  rad.desktop.core in '..\..\..\core\rad.desktop.core.pas',
  rad.desktop.widgets in '..\..\..\core\rad.desktop.widgets.pas',
  rad.desktop.script in '..\..\..\vendor\tms\rad.desktop.script.pas';

type
  [TestFixture]
  TDesktopScriptTests = class
  private
    FPackage: TRadScriptPackage;
    FWidgets: TRadDeskWidgets;
    FLoader: TRadDeskScriptWidgets;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure Load_RegistersOneProviderPerRoutine;
    [Test] procedure Fetch_ScriptFillsData;
    [Test] procedure Fetch_ScriptError_BecomesTileError;
    [Test] procedure Fetch_SettingsReachTheScript;
    [Test] procedure Unload_RemovesOnlyItsProviders;
  end;

const
  CSource =
    'procedure Ciro_Yenile(W: TRadDeskWidgetData);' + sLineBreak +
    'begin' + sLineBreak +
    '  W.Title := ''Ciro'';' + sLineBreak +
    '  W.Value := ''1.250'';' + sLineBreak +
    '  W.SubText := ''bugün'';' + sLineBreak +
    '  W.AddLine(''satır 1'');' + sLineBreak +
    '  W.AddPoint(1);' + sLineBreak +
    '  W.AddPoint(4);' + sLineBreak +
    'end;' + sLineBreak +
    'procedure Bozuk_Yenile(W: TRadDeskWidgetData);' + sLineBreak +
    'begin' + sLineBreak +
    '  W.Value := ''yarım'';' + sLineBreak +
    '  Raise(''veri alınamadı'');' + sLineBreak +
    'end;' + sLineBreak +
    'procedure Ayar_Yenile(W: TRadDeskWidgetData);' + sLineBreak +
    'begin' + sLineBreak +
    '  W.Value := W.Settings;' + sLineBreak +
    'end;' + sLineBreak +
    'function Yardimci: Integer;' + sLineBreak +
    'begin' + sLineBreak +
    '  Result := 1;' + sLineBreak +
    'end;';

procedure TDesktopScriptTests.Setup;
begin
  FPackage := TRadScriptPackage.Create;
  FPackage.Code := 'masaustu';
  FPackage.AddScript('MasaustuWidget', skLibrary, '', CSource);
  FWidgets := TRadDeskWidgets.Create;
  FWidgets.Add(TRadDeskClockWidget.Create);
  FLoader := TRadDeskScriptWidgets.Create;
  Assert.AreEqual(3, FLoader.LoadScripts(FPackage.Scripts.ToArray, FWidgets));
end;

procedure TDesktopScriptTests.TearDown;
begin
  FLoader.Free;
  FWidgets.Free;
  FPackage.Free;
end;

procedure TDesktopScriptTests.Load_RegistersOneProviderPerRoutine;
begin
  Assert.IsNotNull(FWidgets.Find('script:Ciro'));
  Assert.IsNotNull(FWidgets.Find('script:Bozuk'));
  Assert.IsNotNull(FWidgets.Find('script:Ayar'));
  Assert.IsNull(FWidgets.Find('script:Yardimci'));
  Assert.AreEqual(4, Integer(Length(FWidgets.All)));
end;

procedure TDesktopScriptTests.Fetch_ScriptFillsData;
var
  LData: TRadDeskWidgetData;
begin
  LData := TRadDeskWidgetData.Create;
  try
    TRadDeskWidgets.SafeFetch(FWidgets.Find('script:Ciro'), '', LData);
    Assert.AreEqual('', LData.Error);
    Assert.AreEqual('Ciro', LData.Title);
    Assert.AreEqual('1.250', LData.Value);
    Assert.AreEqual('bugün', LData.SubText);
    Assert.AreEqual(1, LData.Lines.Count);
    Assert.AreEqual(2, LData.PointCount);
    Assert.AreEqual(4.0, LData.Points[1], 0.001);
  finally
    LData.Free;
  end;
end;

procedure TDesktopScriptTests.Fetch_ScriptError_BecomesTileError;
var
  LData: TRadDeskWidgetData;
begin
  LData := TRadDeskWidgetData.Create;
  try
    TRadDeskWidgets.SafeFetch(FWidgets.Find('script:Bozuk'), '', LData);
    Assert.IsTrue(LData.Error.Contains('veri alınamadı'), LData.Error);
    Assert.AreEqual('', LData.Value, 'partial data is dropped');
    TRadDeskWidgets.SafeFetch(FWidgets.Find('script:Ciro'), '', LData);
    Assert.AreEqual('1.250', LData.Value, 'the engine still works after an error');
  finally
    LData.Free;
  end;
end;

procedure TDesktopScriptTests.Fetch_SettingsReachTheScript;
var
  LData: TRadDeskWidgetData;
begin
  LData := TRadDeskWidgetData.Create;
  try
    TRadDeskWidgets.SafeFetch(FWidgets.Find('script:Ayar'), '{"depo":3}', LData);
    Assert.AreEqual('{"depo":3}', LData.Value);
  finally
    LData.Free;
  end;
end;

procedure TDesktopScriptTests.Unload_RemovesOnlyItsProviders;
begin
  FLoader.Unload(FWidgets);
  Assert.IsNull(FWidgets.Find('script:Ciro'));
  Assert.IsNotNull(FWidgets.Find('clock'));
end;

var
  LRunner: ITestRunner;
  LResults: IRunResults;
begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  TDUnitX.RegisterTestFixture(TDesktopScriptTests);
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
