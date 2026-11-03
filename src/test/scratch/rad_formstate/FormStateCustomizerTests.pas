unit FormStateCustomizerTests;

{ TRadFormCustomizer without the TMS session: whitelist, captions, the user's changes through the
  store, scaling, reset and the order against a layer applied after the load (company layout). }

interface

uses
  System.SysUtils,
  System.Classes,
  System.Variants,
  Vcl.Controls,
  Vcl.Forms,
  DUnitX.TestFramework,
  mormot.core.base,
  mormot.core.variants,
  rad.formstate.core,
  rad.formstate;

type
  [TestFixture]
  TRadFormCustomizerTests = class
  private
    FRoot: string;
    function LoadDoc: IDocDict;
    procedure PatchDiff(const APatch: TProc<IDocDict, IDocDict>);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure Whitelist_AndCaptions;
    [Test]
    procedure Commit_SavesOnlyChangedPaths_AndRoundTrips;
    [Test]
    procedure TamperedRecord_AppliesAllowedPathsOnly;
    [Test]
    procedure SavedAtAnotherPpi_IsScaled;
    [Test]
    procedure ResetPath_PutsTheDefaultBack;
    [Test]
    procedure Reapply_AfterALaterLayer_UserWinsAndResetGivesThatLayer;
    [Test]
    procedure Customize_WithoutSession_Raises;
    [Test]
    procedure FreedAllowedComponent_LeavesTheList;
  end;

implementation

uses
  Winapi.Windows,
  System.IOUtils,
  FormStateTestCustom;

const
  SCOPE = 'test';
  RECORD_NAME = 'TFormCustom';
  DESIGN_WIDTH = 121;
  USER_WIDTH = 200;

procedure TRadFormCustomizerTests.Setup;
begin
  FRoot := TPath.Combine(TPath.GetTempPath, 'radfscust_' + TGuid.NewGuid.ToString);
  TRadFormState.Kur(TRadFormState.FileStore(FRoot), SCOPE);
end;

procedure TRadFormCustomizerTests.TearDown;
begin
  TRadFormState.Kapat;
  if TDirectory.Exists(FRoot) then
    TDirectory.Delete(FRoot, True);
end;

function TRadFormCustomizerTests.LoadDoc: IDocDict;
begin
  if not TRadFormState.Repository.Load(TRadStateKey.Make(SCOPE, RECORD_NAME), Result) then
    Result := nil;
end;

procedure TRadFormCustomizerTests.PatchDiff(const APatch: TProc<IDocDict, IDocDict>);
var
  LDoc, LCustom, LSection: IDocDict;
begin
  LDoc := LoadDoc;
  Assert.IsTrue((LDoc <> nil) and LDoc.Get('custom', LCustom) and LCustom.Get('Customizer1', LSection),
    'customizer section exists');
  APatch(LDoc, LSection);
  Assert.IsTrue(TRadFormState.Repository.Save(TRadStateKey.Make(SCOPE, RECORD_NAME), LDoc), 'patched');
end;

procedure SaveUserChanges;
var
  LForm: TFormCustom;
  LBefore: IDocDict;
begin
  LForm := TFormCustom.Create(nil);
  try
    LBefore := LForm.Customizer1.SnapshotAll;
    LForm.Edit1.Width := USER_WIDTH;
    LForm.Label1.Caption := 'Yeni';
    LForm.Customizer1.Commit(LBefore);
  finally
    LForm.Free;
  end;
end;

procedure TRadFormCustomizerTests.Whitelist_AndCaptions;
var
  LForm: TFormCustom;
  LCustomizer: TRadFormCustomizer;
begin
  LForm := TFormCustom.Create(nil);
  try
    LCustomizer := LForm.Customizer1;
    Assert.IsTrue(LCustomizer.Store = LForm.Store1, 'joined the owner store');
    Assert.IsTrue(LCustomizer.IsAllowed(LForm.Edit1, 'width'), 'case-insensitive path');
    Assert.IsFalse(LCustomizer.IsAllowed(LForm.Edit1, 'Text'));
    Assert.IsTrue(LCustomizer.AllowedPaths(LForm.Button1) = nil, 'not allowed at all');
    Assert.IsTrue(LCustomizer.CanMove(LForm.Edit1));
    Assert.IsTrue(LCustomizer.CanResize(LForm.Edit1));
    Assert.IsFalse(LCustomizer.CanMove(LForm.Label1));
    Assert.AreEqual('Etiket metni', LCustomizer.CaptionOf('Caption'), 'Captions wins');
    Assert.AreEqual('Yazı boyutu', LCustomizer.CaptionOf('Font.Size'), 'built-in');
    Assert.AreEqual('Tag', LCustomizer.CaptionOf('Tag'), 'unknown: the path');
  finally
    LForm.Free;
  end;
end;

procedure TRadFormCustomizerTests.Commit_SavesOnlyChangedPaths_AndRoundTrips;
var
  LForm: TFormCustom;
  LCustom, LSection, LDiff, LEdit: IDocDict;
begin
  SaveUserChanges;
  Assert.IsTrue(LoadDoc.Get('custom', LCustom) and LCustom.Get('Customizer1', LSection) and
    LSection.Get('diff', LDiff) and LDiff.Get('Edit1', LEdit));
  Assert.IsTrue(LEdit.Exists('Width'));
  Assert.IsFalse(LEdit.Exists('Left'), 'untouched paths are not saved: they keep following the DFM');
  Assert.IsFalse(LEdit.Exists('Font.Size'));
  Assert.AreEqual(Int64(1), TRadStateDoc.SectionVersion(LoadDoc, 'custom/Customizer1'));
  LForm := TFormCustom.Create(nil);
  try
    Assert.AreEqual(USER_WIDTH, LForm.Edit1.Width);
    Assert.AreEqual('Yeni', LForm.Label1.Caption);
  finally
    LForm.Free;
  end;
end;

procedure TRadFormCustomizerTests.TamperedRecord_AppliesAllowedPathsOnly;
var
  LForm: TFormCustom;
begin
  SaveUserChanges;
  PatchDiff(
    procedure(ADoc, ASection: IDocDict)
    var
      LDiff: IDocDict;
    begin
      ASection.Get('diff', LDiff);
      LDiff.D['Button1'] := DocDict('{"Caption":"hacked"}', mFastFloat);
      LDiff.D['Edit1'] := DocDict('{"Width":200,"Text":"hacked"}', mFastFloat);
    end);
  LForm := TFormCustom.Create(nil);
  try
    Assert.AreEqual('Kaydet', LForm.Button1.Caption);
    Assert.AreEqual('default', LForm.Edit1.Text);
    Assert.AreEqual(USER_WIDTH, LForm.Edit1.Width);
  finally
    LForm.Free;
  end;
end;

procedure TRadFormCustomizerTests.SavedAtAnotherPpi_IsScaled;
var
  LForm: TFormCustom;
  LExpected: Integer;
begin
  SaveUserChanges;
  PatchDiff(
    procedure(ADoc, ASection: IDocDict)
    var
      LDiff, LEdit: IDocDict;
    begin
      ASection.I['ppi'] := 192;
      ASection.Get('diff', LDiff);
      LDiff.Get('Edit1', LEdit);
      LEdit.I['Width'] := 400;
    end);
  LForm := TFormCustom.Create(nil);
  try
    LExpected := MulDiv(400, LForm.CurrentPPI, 192);
    Assert.AreEqual(LExpected, LForm.Edit1.Width);
  finally
    LForm.Free;
  end;
end;

procedure TRadFormCustomizerTests.ResetPath_PutsTheDefaultBack;
var
  LForm: TFormCustom;
begin
  SaveUserChanges;
  LForm := TFormCustom.Create(nil);
  try
    Assert.AreEqual(USER_WIDTH, LForm.Edit1.Width);
    LForm.Customizer1.ResetPath(LForm.Edit1, 'Width');
    Assert.AreEqual(DESIGN_WIDTH, LForm.Edit1.Width, 'default back at once');
    Assert.AreEqual('Yeni', LForm.Label1.Caption, 'other changes stay');
  finally
    LForm.Free;
  end;
  LForm := TFormCustom.Create(nil);
  try
    Assert.AreEqual(DESIGN_WIDTH, LForm.Edit1.Width, 'and the reset was saved');
  finally
    LForm.Free;
  end;
end;

procedure TRadFormCustomizerTests.Reapply_AfterALaterLayer_UserWinsAndResetGivesThatLayer;
var
  LForm: TFormCustom;
begin
  SaveUserChanges;
  LForm := TFormCustom.Create(nil);
  try
    LForm.Label1.Caption := 'Şirket'; // the company layout, applied after the store loaded
    TRadFormState.Reapply(LForm);
    Assert.AreEqual('Yeni', LForm.Label1.Caption, 'the user stays on top');
    LForm.Customizer1.ResetPath(LForm.Label1, 'Caption');
    Assert.AreEqual('Şirket', LForm.Label1.Caption, 'reset gives the company value, not the DFM one');
  finally
    LForm.Free;
  end;
end;

procedure TRadFormCustomizerTests.Customize_WithoutSession_Raises;
var
  LForm: TFormCustom;
begin
  TRadFormCustomizer.RegisterSession(nil);
  LForm := TFormCustom.Create(nil);
  try
    Assert.WillRaise(
      procedure
      begin
        LForm.Customizer1.Customize;
      end, ERadFormState, 'no session registered');
  finally
    LForm.Free;
  end;
end;

procedure TRadFormCustomizerTests.FreedAllowedComponent_LeavesTheList;
var
  LForm: TFormCustom;
begin
  LForm := TFormCustom.Create(nil);
  try
    Assert.AreEqual(2, LForm.Customizer1.Allowed.Count);
    LForm.Label1.Free;
    Assert.AreEqual(1, LForm.Customizer1.Allowed.Count);
    LForm.Customizer1.Commit(LForm.Customizer1.SnapshotAll); // must not touch the freed label
  finally
    LForm.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadFormCustomizerTests);

end.
