unit FormStateRulesTests;

{ TRadFormCustomizer permissions by rule ('TControl: Left', '-Edit1') and its link to a chosen store. }

interface

uses
  System.SysUtils,
  System.Classes,
  DUnitX.TestFramework,
  rad.formstate;

type
  [TestFixture]
  TRadFormRulesTests = class
  private
    FRoot: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure Parse_BadLinesGoToErrors;
    [Test]
    procedure Matches_ClassChainNameAndStar;
    [Test]
    procedure Expand_ObjectPropertyGivesWritableLeaves;
    [Test]
    procedure Deny_WinsOverRulesAndAllowed;
    [Test]
    procedure Customizer_FormAndDefaultRules;
    [Test]
    procedure Customizer_StoreLink_SavesIntoTheChosenStore;
  end;

implementation

uses
  System.IOUtils,
  mormot.core.os,
  mormot.core.variants,
  rad.formstate.core,
  rad.formstate.store,
  rad.formstate.rules,
  FormStateTestCustom,
  FormStateTestLink;

const
  SCOPE = 'test';

procedure TRadFormRulesTests.Setup;
begin
  FRoot := TPath.Combine(TPath.GetTempPath, 'radfsrule_' + TGuid.NewGuid.ToString);
  TRadFormState.Kur(TRadFormState.FileStore(FRoot), SCOPE);
end;

procedure TRadFormRulesTests.TearDown;
begin
  TRadFormState.CustomizeRules := '';
  TRadFormState.Kapat;
  if TDirectory.Exists(FRoot) then
    TDirectory.Delete(FRoot, True);
end;

function RulesOf(const AText: string): TRadCustomizeRules;
begin
  Result := TRadCustomizeRules.Create;
  Result.Add(AText);
end;

function PathsOf(ARules: TRadCustomizeRules; AComponent: TComponent): TStringList;
begin
  Result := TStringList.Create;
  ARules.AddAllowed(AComponent, Result);
  ARules.RemoveDenied(AComponent, Result);
end;

procedure TRadFormRulesTests.Parse_BadLinesGoToErrors;
var
  LRules: TRadCustomizeRules;
begin
  LRules := RulesOf('// yorum' + sLineBreak + '' + sLineBreak + 'TControl Left' + sLineBreak + ': Left' +
    sLineBreak + 'TButton:' + sLineBreak + 'TControl: Left' + sLineBreak + '-Edit1' + sLineBreak +
    '-TPanel: Color');
  try
    Assert.AreEqual(3, LRules.Errors.Count, LRules.Errors.Text);
    Assert.Contains(LRules.Errors[0], '3. satır');
  finally
    LRules.Free;
  end;
end;

procedure TRadFormRulesTests.Matches_ClassChainNameAndStar;
var
  LForm: TFormCustom;
begin
  LForm := TFormCustom.Create(nil);
  try
    Assert.IsTrue(TRadCustomizeRules.Matches(LForm.Edit1, 'TCustomEdit'), 'ancestor class');
    Assert.IsTrue(TRadCustomizeRules.Matches(LForm.Edit1, 'twincontrol'), 'case-insensitive');
    Assert.IsTrue(TRadCustomizeRules.Matches(LForm.Edit1, 'Edit1'), 'component name');
    Assert.IsTrue(TRadCustomizeRules.Matches(LForm.Edit1, '*'));
    Assert.IsFalse(TRadCustomizeRules.Matches(LForm.Edit1, 'TButton'));
    Assert.IsFalse(TRadCustomizeRules.Matches(LForm.Edit1, 'TEdit1'));
  finally
    LForm.Free;
  end;
end;

procedure TRadFormRulesTests.Expand_ObjectPropertyGivesWritableLeaves;
var
  LForm: TFormCustom;
  LPaths: TStringList;
begin
  LForm := TFormCustom.Create(nil);
  LPaths := TStringList.Create;
  try
    TRadCustomizeRules.Expand(LForm.Edit1, 'Font', LPaths);
    Assert.IsTrue(LPaths.IndexOf('Font.Size') >= 0, LPaths.CommaText);
    Assert.IsTrue(LPaths.IndexOf('Font.Style') >= 0);
    Assert.IsTrue(LPaths.IndexOf('Font.Name') >= 0);
    Assert.IsTrue(LPaths.IndexOf('Font.Color') >= 0);
    Assert.IsTrue(LPaths.IndexOf('Font.Height') < 0, 'Size covers Height');
    LPaths.Clear;
    TRadCustomizeRules.Expand(LForm.Edit1, 'font.size', LPaths);
    Assert.AreEqual('Font.Size', LPaths.Text.Trim, 'the real spelling');
    LPaths.Clear;
    TRadCustomizeRules.Expand(LForm.Label1, 'Text', LPaths);
    TRadCustomizeRules.Expand(LForm.Edit1, 'Yok.Size', LPaths);
    Assert.AreEqual(0, LPaths.Count, 'a missing property opens nothing');
  finally
    LPaths.Free;
    LForm.Free;
  end;
end;

procedure TRadFormRulesTests.Deny_WinsOverRulesAndAllowed;
var
  LForm: TFormCustom;
  LRules: TRadCustomizeRules;
  LPaths: TStringList;
begin
  LForm := TFormCustom.Create(nil);
  LRules := RulesOf('TControl: Left, Font' + sLineBreak + '-Edit1.Font' + sLineBreak + '-Button1');
  try
    LPaths := PathsOf(LRules, LForm.Edit1);
    try
      Assert.IsTrue(LPaths.IndexOf('Left') >= 0);
      Assert.IsTrue(LPaths.IndexOf('Font.Size') < 0, 'closed again');
    finally
      LPaths.Free;
    end;
    LPaths := PathsOf(LRules, LForm.Button1);
    try
      Assert.AreEqual(0, LPaths.Count, 'a closed component has nothing');
    finally
      LPaths.Free;
    end;
    LForm.Customizer1.Rules.Text := '-Edit1.Color';
    Assert.IsFalse(LForm.Customizer1.IsAllowed(LForm.Edit1, 'Color'), 'closing wins over Allowed too');
    Assert.IsTrue(LForm.Customizer1.IsAllowed(LForm.Edit1, 'Width'));
  finally
    LRules.Free;
    LForm.Free;
  end;
end;

procedure TRadFormRulesTests.Customizer_FormAndDefaultRules;
var
  LForm: TFormCustom;
begin
  TRadFormState.CustomizeRules := 'TCustomLabel: Font' + sLineBreak + 'TControl: Name';
  LForm := TFormCustom.Create(nil);
  try
    Assert.IsTrue(LForm.Customizer1.IsAllowed(LForm.Label1, 'Font.Size'), 'application rule');
    Assert.IsTrue(LForm.Customizer1.IsAllowed(LForm.Label1, 'Caption'), 'Allowed still adds');
    Assert.IsFalse(LForm.Customizer1.IsAllowed(LForm.Label1, 'Name'), 'Name never opens');
    Assert.IsTrue(LForm.Customizer1.AllowedPaths(LForm.Button1) = nil);
    LForm.Customizer1.Rules.Text := 'TButton: Caption';
    Assert.IsTrue(LForm.Customizer1.IsAllowed(LForm.Button1, 'Caption'), 'form rule, picked up at once');
    Assert.IsTrue(LForm.Customizer1.CanMove(LForm.Edit1), 'explicit Allowed unchanged');
  finally
    LForm.Free;
  end;
end;

procedure TRadFormRulesTests.Customizer_StoreLink_SavesIntoTheChosenStore;
var
  LForm: TFormLink;
  LBefore: IDocDict;
  LSecret, LPlain: RawByteString;
begin
  LForm := TFormLink.Create(nil);
  try
    Assert.IsTrue(LForm.Customizer1.Store = LForm.Store2, 'the DFM link, not the first store');
    Assert.IsTrue(LForm.Customizer1.IsAllowed(LForm.Edit1, 'Font.Size'), 'rules from the DFM');
    Assert.IsTrue(LForm.Customizer1.AllowedPaths(LForm.Button1) = nil);
    LBefore := LForm.Customizer1.SnapshotAll;
    LForm.Edit1.Width := 222;
    LForm.Customizer1.Commit(LBefore);
  finally
    LForm.Free;
  end;
  LSecret := StringFromFile(TPath.Combine(TPath.Combine(FRoot, SCOPE), 'gizli.state'));
  LPlain := StringFromFile(TPath.Combine(TPath.Combine(FRoot, SCOPE), 'TFormLink.state'));
  Assert.IsTrue(TRadStateEnvelope.IsEncrypted(LSecret), 'the customizer saved through the encrypted store');
  Assert.IsFalse(Pos(RawByteString('Customizer1'), LPlain) > 0, 'nothing of it in the first store');
  LForm := TFormLink.Create(nil);
  try
    Assert.AreEqual(222, LForm.Edit1.Width);
  finally
    LForm.Free;
  end;
end;

end.
