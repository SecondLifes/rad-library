unit FormStateVclTests;

{ VCL integration tests of TRadPropertiesStore on DFM-loaded forms and a data module.
  Every test runs against a fresh temporary file store. }

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.Variants,
  System.Diagnostics,
  System.UITypes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  System.Actions,
  Vcl.ActnList,
  Vcl.Menus,
  DUnitX.TestFramework,
  mormot.core.base,
  mormot.core.variants,
  rad.rtl,
  rad.formstate;

type
  [TestFixture]
  TRadFormStateVclTests = class
  private
    FRoot: string;
    function StateFile(const AName: string): string;
    function LoadDoc(const AName: RawUtf8): IDocDict;
    procedure PatchDoc(const AName: RawUtf8; const APatch: TProc<IDocDict>);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure Form_CloseAndReopen_RestoresPropsValuesAndPlacement;
    [Test]
    procedure Form_OwnOnCreate_SeesRestoredValues;
    [Test]
    procedure Form_UserHandlers_RunExactlyOnce;
    [Test]
    procedure Form_VersionChanged_SkipsLayoutKeepsValues;
    [Test]
    procedure Form_ClosedUnchanged_DoesNotRewrite;
    [Test]
    procedure Form_PlacementOffEveryMonitor_IsIgnored;
    [Test]
    procedure Store_CreatedAtRuntime_LeavesFormEventsAlone;
    [Test]
    procedure Store_NeverLoaded_DoesNotSave;
    [Test]
    procedure TwoStores_FirstFreed_SecondStillWorksAndEventsSurvive;
    [Test]
    procedure TwoStores_BothFreed_FormEventsRestored;
    [Test]
    procedure DataModule_RoundTrip_HasNoFormSection;
    [Test]
    procedure Kapat_SavesFormsStillOpen;
    [Test]
    procedure ActionList_ShortcutsRoundTripThroughTheStore;
    [Test]
    procedure Values_DeclaredType_IsWhatComesBack;
    [Test]
    procedure Values_Convert_ParsesTextForms;
    [Test]
    procedure Measure_ThreeHundredPaths;
  end;

implementation

uses
  System.IOUtils,
  mormot.core.text,
  mormot.core.unicode,
  FormStateTestA,
  FormStateTestTwo,
  FormStateTestDm,
  FormStateTestPlain;

const
  SCOPE = 'test';

function SameEvent(const A, B: TMethod): Boolean;
begin
  Result := (A.Code = B.Code) and (A.Data = B.Data);
end;

procedure TRadFormStateVclTests.Setup;
begin
  FRoot := TPath.Combine(TPath.GetTempPath, 'radfsvcl_' + TGuid.NewGuid.ToString);
  TRadFormState.Kur(TRadFormState.FileStore(FRoot), SCOPE);
end;

procedure TRadFormStateVclTests.TearDown;
begin
  TRadFormState.Kapat;
  if TDirectory.Exists(FRoot) then
    TDirectory.Delete(FRoot, True);
end;

function TRadFormStateVclTests.StateFile(const AName: string): string;
begin
  Result := TPath.Combine(TPath.Combine(FRoot, SCOPE), AName + '.state');
end;

function TRadFormStateVclTests.LoadDoc(const AName: RawUtf8): IDocDict;
begin
  if not TRadFormState.Repository.Load(TRadStateKey.Make(SCOPE, AName), Result) then
    Result := nil;
end;

procedure TRadFormStateVclTests.PatchDoc(const AName: RawUtf8; const APatch: TProc<IDocDict>);
var
  LDoc: IDocDict;
begin
  LDoc := LoadDoc(AName);
  Assert.IsTrue(LDoc <> nil, 'record exists');
  APatch(LDoc);
  Assert.IsTrue(TRadFormState.Repository.Save(TRadStateKey.Make(SCOPE, AName), LDoc), 'patched');
end;

function NewChangedFormA: TFormA;
begin
  Result := TFormA.Create(nil);
  Result.Show;
  Result.Edit1.Width := 222;
  Result.Edit1.Text := 'Çığ';
  Result.Edit1.Font.Style := [fsBold];
  Result.Memo1.Lines.Text := 'a'#13#10'b';
  Result.StatusBar1.Panels[0].Width := 77;
  Result.Store1.StoredValue['counter'] := 5;
  Result.Store1.StoredValue['when'] := VarFromDateTime(EncodeDate(2026, 11, 3));
  Result.SetBounds(150, 160, 520, 410);
end;

procedure SaveAndFree(AForm: TCustomForm);
begin
  AForm.Close;
  AForm.Free;
end;

procedure TRadFormStateVclTests.Form_CloseAndReopen_RestoresPropsValuesAndPlacement;
var
  LForm: TFormA;
begin
  SaveAndFree(NewChangedFormA);
  Assert.IsTrue(FileExists(StateFile('TFormA')));
  LForm := TFormA.Create(nil);
  try
    Assert.AreEqual(0, Integer(Length(LForm.Store1.Errors)), Utf8ToString(RawUtf8ArrayToCsv(LForm.Store1.Errors)));
    Assert.AreEqual(222, LForm.Edit1.Width);
    Assert.AreEqual('Çığ', LForm.Edit1.Text);
    Assert.IsTrue(LForm.Edit1.Font.Style = [fsBold]);
    Assert.AreEqual(2, LForm.Memo1.Lines.Count);
    Assert.AreEqual(77, LForm.StatusBar1.Panels[0].Width);
    Assert.AreEqual(5, LForm.Store1.GetInteger('counter'));
    Assert.AreEqual(Double(EncodeDate(2026, 11, 3)), Double(LForm.Store1.GetDate('when')), 1E-9);
    LForm.Show;
    Assert.AreEqual(150, LForm.Left, 'placement survives the show (no centering)');
    Assert.AreEqual(160, LForm.Top);
    Assert.AreEqual(520, LForm.Width);
    Assert.AreEqual(410, LForm.Height);
  finally
    LForm.Free;
  end;
end;

function Declare(AStore: TRadPropertiesStore; const AName: string; AType: TRadStoredValueType;
  const ADefault: Variant): TRadStoredValue;
begin
  Result := TRadStoredValue(AStore.StoredValues.Add);
  Result.Name := AName;
  Result.ValueType := AType;
  Result.Value := ADefault;
end;

procedure TRadFormStateVclTests.Values_DeclaredType_IsWhatComesBack;
var
  LForm: TFormA;
begin
  SaveAndFree(NewChangedFormA);
  LForm := TFormA.Create(nil);
  try
    Assert.AreNotEqual(varDate, Integer(VarType(LForm.Store1.StoredValue['when'])), 'undeclared: JSON text');
    Declare(LForm.Store1, 'when', svtDateTime, Unassigned);
    Assert.AreEqual(varDate, Integer(VarType(LForm.Store1.StoredValue['when'])));
    Assert.AreEqual(Double(EncodeDate(2026, 11, 3)), Double(LForm.Store1.StoredValue['when']), 1E-9);
    Declare(LForm.Store1, 'n', svtInteger, '7');
    Assert.AreEqual(varInt64, Integer(VarType(LForm.Store1.StoredValue['n'])), 'design default converted');
    Assert.AreEqual(Int64(7), Int64(LForm.Store1.StoredValue['n']));
    Declare(LForm.Store1, 'bad', svtInteger, 3);
    LForm.Store1.StoredValue['bad'] := 'abc';
    Assert.AreEqual(Int64(3), Int64(LForm.Store1.StoredValue['bad']), 'unconvertible runtime value: default');
    Declare(LForm.Store1, 'flag', svtBoolean, Unassigned);
    Assert.AreEqual(varBoolean, Integer(VarType(LForm.Store1.StoredValue['flag'])), 'nothing: empty of type');
    Assert.IsFalse(LForm.Store1.StoredValue['flag']);
    Assert.IsTrue(VarIsNull(LForm.Store1.StoredValue['nothing']), 'undeclared and missing: Null');
    Assert.AreEqual(9, LForm.Store1.GetInteger('nothing', 9), 'missing: the caller default, not 0');
    Assert.AreEqual(3, LForm.Store1.GetInteger('bad', 9));
  finally
    LForm.Free;
  end;
end;

procedure TRadFormStateVclTests.Values_Convert_ParsesTextForms;
var
  LValue: Variant;
  LDate: TDateTime;
begin
  Assert.IsTrue(TRadStoredValue.Convert('1.5', svtFloat, LValue));
  Assert.AreEqual(1.5, Double(LValue), 1E-12, 'invariant');
  Assert.IsTrue(TRadStoredValue.Convert('2' + FormatSettings.DecimalSeparator + '5', svtFloat, LValue));
  Assert.AreEqual(2.5, Double(LValue), 1E-12, 'local');
  LDate := EncodeDate(2026, 11, 3) + EncodeTime(10, 20, 30, 0);
  Assert.IsTrue(TRadStoredValue.Convert('2026-11-03T10:20:30', svtDateTime, LValue));
  Assert.AreEqual(Double(LDate), Double(LValue), 1E-6, 'ISO 8601');
  Assert.IsTrue(TRadStoredValue.Convert(DateTimeToStr(LDate), svtDateTime, LValue));
  Assert.AreEqual(Double(LDate), Double(LValue), 1E-5, 'local: ' + DateTimeToStr(LDate));
  Assert.IsTrue(TRadStoredValue.Convert(' 42 ', svtInteger, LValue));
  Assert.AreEqual(Int64(42), Int64(LValue));
  Assert.IsFalse(TRadStoredValue.Convert('4.2', svtInteger, LValue), 'no silent truncation');
  Assert.IsTrue(TRadStoredValue.Convert('true', svtBoolean, LValue));
  Assert.IsTrue(LValue);
  Assert.IsFalse(TRadStoredValue.Convert('yes?', svtBoolean, LValue));
  Assert.IsFalse(TRadStoredValue.Convert(Null, svtString, LValue));
  LValue := '5';
  Assert.IsTrue(TRadStoredValue.Convert(LValue, svtInteger, LValue), 'same variable in and out');
  Assert.AreEqual(Int64(5), Int64(LValue));
end;

procedure TRadFormStateVclTests.Form_OwnOnCreate_SeesRestoredValues;
var
  LForm: TFormA;
begin
  SaveAndFree(NewChangedFormA);
  LForm := TFormA.Create(nil);
  try
    Assert.AreEqual(222, LForm.WidthSeenInCreate);
  finally
    LForm.Free;
  end;
end;

procedure TRadFormStateVclTests.Form_UserHandlers_RunExactlyOnce;
var
  LForm: TFormA;
begin
  LForm := TFormA.Create(nil);
  try
    LForm.Show;
    LForm.Close;
    Assert.AreEqual(1, LForm.CreateCalls);
    Assert.AreEqual(1, LForm.ShowCalls);
    Assert.AreEqual(1, LForm.CloseQueryCalls);
  finally
    LForm.Free;
  end;
end;

procedure TRadFormStateVclTests.Form_VersionChanged_SkipsLayoutKeepsValues;
var
  LForm: TFormA;
begin
  SaveAndFree(NewChangedFormA);
  PatchDoc('TFormA',
    procedure(ADoc: IDocDict)
    begin
      ADoc.I['version'] := 99;
    end);
  LForm := TFormA.Create(nil);
  try
    Assert.AreEqual(121, LForm.Edit1.Width, 'layout from the DFM');
    Assert.AreEqual('default', LForm.Edit1.Text);
    Assert.AreEqual(5, LForm.Store1.GetInteger('counter'), 'values survive');
  finally
    LForm.Free;
  end;
end;

procedure TRadFormStateVclTests.Form_ClosedUnchanged_DoesNotRewrite;
var
  LBefore, LAfter: TBytes;
begin
  SaveAndFree(NewChangedFormA);
  LBefore := TFile.ReadAllBytes(StateFile('TFormA'));
  Sleep(1100); // savedAt has second resolution; a rewrite would change it
  SaveAndFree(TFormA.Create(nil));
  LAfter := TFile.ReadAllBytes(StateFile('TFormA'));
  Assert.AreEqual(Length(LBefore), Length(LAfter));
  Assert.IsTrue(CompareMem(@LBefore[0], @LAfter[0], Length(LBefore)), 'file rewritten');
end;

procedure TRadFormStateVclTests.Form_PlacementOffEveryMonitor_IsIgnored;
var
  LForm: TFormA;
begin
  SaveAndFree(NewChangedFormA);
  PatchDoc('TFormA',
    procedure(ADoc: IDocDict)
    begin
      ADoc.D['form'].L['normal'] := DocList([-32000, -32000, -31500, -31600]);
    end);
  LForm := TFormA.Create(nil);
  try
    Assert.IsTrue(LForm.Left > -30000, 'not moved off screen');
    Assert.AreEqual(222, LForm.Edit1.Width, 'the rest still restores');
    Assert.AreEqual(1, Integer(Length(LForm.Store1.Errors)));
  finally
    LForm.Free;
  end;
end;

procedure TRadFormStateVclTests.Store_CreatedAtRuntime_LeavesFormEventsAlone;
var
  LForm: TFormPlain;
  LStore: TRadPropertiesStore;
  LCreate, LShow, LDestroy: TNotifyEvent;
  LClose: TCloseQueryEvent;
begin
  LForm := TFormPlain.Create(nil);
  try
    LCreate := LForm.OnCreate;
    LShow := LForm.OnShow;
    LClose := LForm.OnCloseQuery;
    LDestroy := LForm.OnDestroy;
    LStore := TRadPropertiesStore.Create(LForm);
    LStore.Free;
    Assert.IsTrue(SameEvent(TMethod(LCreate), TMethod(LForm.OnCreate)), 'OnCreate');
    Assert.IsTrue(SameEvent(TMethod(LShow), TMethod(LForm.OnShow)), 'OnShow');
    Assert.IsTrue(SameEvent(TMethod(LClose), TMethod(LForm.OnCloseQuery)), 'OnCloseQuery');
    Assert.IsTrue(SameEvent(TMethod(LDestroy), TMethod(LForm.OnDestroy)), 'OnDestroy');
  finally
    LForm.Free;
  end;
end;

procedure TRadFormStateVclTests.Store_NeverLoaded_DoesNotSave;
var
  LForm: TFormPlain;
  LStore: TRadPropertiesStore;
begin
  LForm := TFormPlain.Create(nil);
  try
    LStore := TRadPropertiesStore.Create(LForm);
    LStore.Items.Add.Component := LForm.Edit1;
    LStore.Items[0].Properties.Text := 'Width';
    Assert.IsFalse(LStore.Save, 'not loaded yet');
    Assert.IsFalse(FileExists(StateFile('TFormPlain')));
    LStore.Load;
    Assert.IsTrue(LStore.Save);
    Assert.IsTrue(FileExists(StateFile('TFormPlain')));
  finally
    LForm.Free;
  end;
end;

procedure TRadFormStateVclTests.TwoStores_FirstFreed_SecondStillWorksAndEventsSurvive;
var
  LForm: TFormTwo;
begin
  LForm := TFormTwo.Create(nil);
  try
    LForm.Store1.Free;
    LForm.Show;
    LForm.Edit1.Text := 'kept';
    LForm.Close;
    Assert.AreEqual(1, LForm.CloseQueryCalls);
    Assert.IsTrue(FileExists(StateFile('TFormTwo.second')), 'second store saved');
    Assert.IsFalse(FileExists(StateFile('TFormTwo')), 'freed store saved nothing');
  finally
    LForm.Free;
  end;
  LForm := TFormTwo.Create(nil);
  try
    Assert.AreEqual('kept', LForm.Edit1.Text);
    Assert.AreEqual(1, LForm.CreateCalls);
  finally
    LForm.Free;
  end;
end;

procedure TRadFormStateVclTests.TwoStores_BothFreed_FormEventsRestored;
var
  LForm: TFormTwo;
  LExpected: TNotifyEvent;
  LExpectedClose: TCloseQueryEvent;
begin
  LForm := TFormTwo.Create(nil);
  try
    LForm.Store2.Free;
    LForm.Store1.Free;
    LExpected := LForm.FormCreate;
    Assert.IsTrue(SameEvent(TMethod(LExpected), TMethod(LForm.OnCreate)), 'OnCreate');
    LExpected := LForm.FormShow;
    Assert.IsTrue(SameEvent(TMethod(LExpected), TMethod(LForm.OnShow)), 'OnShow');
    LExpectedClose := LForm.FormCloseQuery;
    Assert.IsTrue(SameEvent(TMethod(LExpectedClose), TMethod(LForm.OnCloseQuery)), 'OnCloseQuery');
    LExpected := LForm.FormDestroy;
    Assert.IsTrue(SameEvent(TMethod(LExpected), TMethod(LForm.OnDestroy)), 'OnDestroy');
  finally
    LForm.Free;
  end;
end;

procedure TRadFormStateVclTests.DataModule_RoundTrip_HasNoFormSection;
var
  LDm: TDmA;
  LDoc: IDocDict;
begin
  LDm := TDmA.Create(nil);
  try
    LDm.Timer1.Interval := 4321;
  finally
    LDm.Free;
  end;
  LDoc := LoadDoc('TDmA');
  Assert.IsTrue(LDoc <> nil);
  Assert.IsFalse(LDoc.Exists('form'));
  Assert.IsTrue(LDoc.Exists('props'));
  LDm := TDmA.Create(nil);
  try
    Assert.AreEqual(Cardinal(4321), LDm.Timer1.Interval);
    Assert.AreEqual(1, LDm.CreateCalls);
  finally
    LDm.Free;
  end;
end;

procedure TRadFormStateVclTests.Kapat_SavesFormsStillOpen;
var
  LForm: TFormA;
begin
  LForm := NewChangedFormA;
  try
    TRadFormState.Kapat;
    Assert.IsTrue(FileExists(StateFile('TFormA')), 'saved by Kapat');
  finally
    LForm.Free; // after Kapat a store saves nothing and must not fail
  end;
end;

procedure TRadFormStateVclTests.ActionList_ShortcutsRoundTripThroughTheStore;
var
  LForm: TFormPlain;
  LStore: TRadPropertiesStore;
  LList: TRadActionList;
  LAction: TAction;
  LCtrlS: TShortCut;
begin
  LCtrlS := ShortCut(Ord('S'), [ssCtrl]);
  LForm := TFormPlain.Create(nil);
  try
    LList := TRadActionList.Create(LForm);
    LList.Name := 'Actions1';
    LAction := TAction.Create(LForm);
    LAction.Name := 'actSave';
    LAction.ActionList := LList;
    LAction.ShortCut := LCtrlS;
    LStore := TRadPropertiesStore.Create(LForm);
    LStore.Items.Add.Component := LList; // no paths: the list saves itself (IRadStateful)
    LStore.Load;
    Assert.IsTrue(LStore.Save);
    LAction.ShortCut := 0;
    LStore.Load;
    Assert.AreEqual(Integer(LCtrlS), Integer(LAction.ShortCut));
    Assert.IsTrue(LoadDoc('TFormPlain').Exists('custom'));
  finally
    LForm.Free;
  end;
end;

procedure TRadFormStateVclTests.Measure_ThreeHundredPaths;
const
  EDITS = 50;
  PATHS = 'Left,Width,Anchors,Text,Font.Size,Font.Style';
var
  LForm: TFormPlain;
  LStore: TRadPropertiesStore;
  LEdits: array[0..EDITS - 1] of TEdit;
  I: Integer;
  LWatch: TStopwatch;
  LSaveMs, LLoadMs: Double;
begin
  LForm := TFormPlain.Create(nil);
  try
    LForm.SetBounds(0, 0, 900, 900);
    LStore := TRadPropertiesStore.Create(LForm);
    for I := 0 to High(LEdits) do
    begin
      LEdits[I] := TEdit.Create(LForm);
      LEdits[I].Name := 'E' + IntToStr(I);
      LEdits[I].Parent := LForm;
      LEdits[I].SetBounds(5, I * 16, 200 + I, 15);
      LEdits[I].Text := 'Değer ' + IntToStr(I);
      LStore.Items.Add.Component := LEdits[I];
      LStore.Items[I].Properties.CommaText := PATHS;
    end;
    LForm.Show;
    LStore.Load;
    LWatch := TStopwatch.StartNew;
    Assert.IsTrue(LStore.Save);
    LSaveMs := LWatch.Elapsed.TotalMilliseconds;
    for I := 0 to High(LEdits) do
    begin
      LEdits[I].Width := 50;
      LEdits[I].Text := '';
      LEdits[I].Font.Size := 14;
    end;
    LWatch := TStopwatch.StartNew;
    LStore.Load;
    LLoadMs := LWatch.Elapsed.TotalMilliseconds;
    Assert.AreEqual(0, Integer(Length(LStore.Errors)), Utf8ToString(RawUtf8ArrayToCsv(LStore.Errors)));
    Assert.AreEqual(249, LEdits[49].Width);
    System.Writeln(Format('MEASURE 300 paths: save %.2f ms (file I/O included), load+apply %.2f ms',
      [LSaveMs, LLoadMs]));
  finally
    LForm.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadFormStateVclTests);

end.
