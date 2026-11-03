unit FormStateDevTests;

{ DevExpress providers of the form-state system: grid and layout state per user, dropped once the
  designed component changes. Forms are built in code so one test can vary the design. }

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  DUnitX.TestFramework,
  cxGrid,
  cxGridLevel,
  cxGridTableView,
  dxLayoutControl,
  dxLayoutContainer,
  mormot.core.base,
  mormot.core.variants,
  rad.formstate.core,
  rad.formstate;

type
  [TestFixture]
  TRadFormStateDevTests = class
  private
    FRoot: string;
    function SavedDoc: IDocDict;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure Grid_UserLayout_RoundTrips;
    [Test]
    procedure Grid_DesignChanged_DropsUserLayout;
    [Test]
    procedure Grid_Save_RecordsFingerprintAndVersion;
    [Test]
    procedure Layout_UserArrangement_RoundTrips;
  end;

implementation

uses
  System.IOUtils,
  FormStateTestPlain;

const
  SCOPE = 'test';
  RECORD_NAME = 'TFormPlain';
  COLUMN_COUNT = 3;
  DESIGN_WIDTH = 100;
  USER_WIDTH = 250;

function NewGridForm(ALastWidth: Integer = DESIGN_WIDTH): TFormPlain;
var
  LGrid: TcxGrid;
  LView: TcxGridTableView;
  LColumn: TcxGridColumn;
  I: Integer;
begin
  Result := TFormPlain.Create(nil);
  LGrid := TcxGrid.Create(Result);
  LGrid.Name := 'Grid1';
  LGrid.Parent := Result;
  LView := LGrid.CreateView(TcxGridTableView) as TcxGridTableView;
  LView.Name := 'tvTest';
  LGrid.Levels.Add.GridView := LView;
  for I := 0 to COLUMN_COUNT - 1 do
  begin
    LColumn := LView.CreateColumn;
    LColumn.Name := 'col' + IntToStr(I);
    LColumn.Caption := LColumn.Name;
    LColumn.Width := DESIGN_WIDTH;
  end;
  LView.Columns[COLUMN_COUNT - 1].Width := ALastWidth;
end;

function ViewOf(AForm: TForm): TcxGridTableView;
begin
  Result := AForm.FindComponent('tvTest') as TcxGridTableView;
end;

function ColumnOf(AForm: TForm; const AName: string): TcxGridColumn;
begin
  Result := AForm.FindComponent(AName) as TcxGridColumn;
end;

function NewLayoutForm: TFormPlain;
var
  LLayout: TdxLayoutControl;
  LEdit: TEdit;
  I: Integer;
begin
  Result := TFormPlain.Create(nil);
  LLayout := TdxLayoutControl.Create(Result);
  LLayout.Name := 'Layout1';
  LLayout.Parent := Result;
  for I := 0 to 1 do
  begin
    LEdit := TEdit.Create(Result);
    LEdit.Name := 'LayoutEdit' + IntToStr(I); // TFormPlain already has Edit1
    LLayout.CreateItemForControl(LEdit, LLayout.Items).Name := 'liEdit' + IntToStr(I);
  end;
end;

function LayoutItem(AForm: TForm; const AName: string): TdxCustomLayoutItem;
var
  LRoot: TdxLayoutGroup;
  I: Integer;
begin
  LRoot := (AForm.FindComponent('Layout1') as TdxLayoutControl).Items;
  for I := 0 to LRoot.Count - 1 do
    if LRoot.Items[I].Name = AName then
      Exit(LRoot.Items[I]);
  Result := nil;
end;

function OpenWithStore(AForm: TForm): TRadPropertiesStore;
begin
  Result := TRadPropertiesStore.Create(AForm);
  Result.Load;
end;

procedure TRadFormStateDevTests.Setup;
begin
  FRoot := TPath.Combine(TPath.GetTempPath, 'radfsdev_' + TGuid.NewGuid.ToString);
  TRadFormState.Kur(TRadFormState.FileStore(FRoot), SCOPE);
  TRadFormState.RegisterProvider(TRadGridStateProvider.Create);
  TRadFormState.RegisterProvider(TRadLayoutStateProvider.Create);
end;

procedure TRadFormStateDevTests.TearDown;
begin
  TRadFormState.Kapat;
  if TDirectory.Exists(FRoot) then
    TDirectory.Delete(FRoot, True);
end;

function TRadFormStateDevTests.SavedDoc: IDocDict;
begin
  if not TRadFormState.Repository.Load(TRadStateKey.Make(SCOPE, RECORD_NAME), Result) then
    Result := nil;
end;

procedure SaveUserGridLayout(ALastWidth: Integer);
var
  LForm: TFormPlain;
  LStore: TRadPropertiesStore;
begin
  LForm := NewGridForm(ALastWidth);
  try
    LStore := OpenWithStore(LForm);
    ColumnOf(LForm, 'col0').Width := USER_WIDTH;
    ColumnOf(LForm, 'col2').Index := 0;
    Assert.IsTrue(LStore.Save, 'saved');
  finally
    LForm.Free;
  end;
end;

procedure TRadFormStateDevTests.Grid_UserLayout_RoundTrips;
var
  LForm: TFormPlain;
begin
  SaveUserGridLayout(DESIGN_WIDTH);
  LForm := NewGridForm;
  try
    OpenWithStore(LForm);
    Assert.AreEqual(USER_WIDTH, ColumnOf(LForm, 'col0').Width);
    Assert.AreEqual('col2', ViewOf(LForm).VisibleColumns[0].Name);
  finally
    LForm.Free;
  end;
end;

procedure TRadFormStateDevTests.Grid_DesignChanged_DropsUserLayout;
var
  LForm: TFormPlain;
begin
  SaveUserGridLayout(DESIGN_WIDTH);
  LForm := NewGridForm(DESIGN_WIDTH - 10); // the developer changed the grid
  try
    OpenWithStore(LForm);
    Assert.AreEqual(DESIGN_WIDTH, ColumnOf(LForm, 'col0').Width, 'user width dropped');
    Assert.AreEqual('col0', ViewOf(LForm).VisibleColumns[0].Name, 'designed order');
  finally
    LForm.Free;
  end;
end;

procedure TRadFormStateDevTests.Grid_Save_RecordsFingerprintAndVersion;
var
  LDoc: IDocDict;
begin
  SaveUserGridLayout(DESIGN_WIDTH);
  LDoc := SavedDoc;
  Assert.IsTrue(LDoc <> nil);
  Assert.AreEqual(Int64(1), TRadStateDoc.MapValue(LDoc, RAD_STATE_FIELD_SECTIONS, 'ext/cxgrid'));
  Assert.IsTrue(TRadStateDoc.MapValue(LDoc, RAD_STATE_FIELD_BASES, 'ext/cxgrid') <> 0, 'fingerprint');
  System.Writeln('MEASURE cxgrid record bytes (3 columns): ', Length(LDoc.Json));
  Assert.AreEqual(Int64(0), TRadStateDoc.MapValue(LDoc, RAD_STATE_FIELD_BASES, 'ext/dxlayout'),
    'no layout control: no section');
end;

procedure TRadFormStateDevTests.Layout_UserArrangement_RoundTrips;
var
  LForm: TFormPlain;
  LStore: TRadPropertiesStore;
begin
  LForm := NewLayoutForm;
  try
    LStore := OpenWithStore(LForm);
    Assert.IsTrue(LayoutItem(LForm, 'liEdit0') <> nil, 'items sit in the root group');
    Assert.AreEqual(0, LayoutItem(LForm, 'liEdit0').Index, 'designed order');
    LayoutItem(LForm, 'liEdit1').Index := 0;
    Assert.IsTrue(LStore.Save);
  finally
    LForm.Free;
  end;
  LForm := NewLayoutForm;
  try
    OpenWithStore(LForm);
    Assert.AreEqual(0, LayoutItem(LForm, 'liEdit1').Index, 'user order restored');
  finally
    LForm.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadFormStateDevTests);

end.
