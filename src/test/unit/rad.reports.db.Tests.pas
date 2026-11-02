unit rad.reports.db.Tests;

(* rad.reports — veritabanı ve FastReport gerektiren DUnitX testleri: depo, servis/iş nesnesi API'si, ribbon yönetim formu.

  Gerçek PostgreSQL'e karşı çalışır: fixture atılabilir bir veritabanı (radreports_test_<rastgele>) yaratır, şemayı
  Rad-DB\sql\schema.sql'in rapor bölümünden kurar, bitince siler. Mevcut hiçbir veritabanına dokunmaz.

  Bağlantı ortam değişkenleriyle verilir (parola repoya yazılmaz):
    RAPOR_TEST_PGPWD   (zorunlu; yoksa bu testler "atlandı" diye geçer)
    RAPOR_TEST_PGHOST  (varsayılan 127.0.0.1), RAPOR_TEST_PGPORT (5432), RAPOR_TEST_PGUSER (postgres) *)

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.Classes, System.IOUtils, System.Variants, System.Generics.Collections, Data.DB, DBAccess,
  Uni, UniScript, PostgreSQLUniProvider, Vcl.Forms, Vcl.Menus, Vcl.ActnList, frxClass, frxDesgn,
  rad.reports;

type
  TTestDb = class
  strict private
    class var FConnection: TUniConnection;
    class var FName: string;
    class var FUsers: Integer;
    class function NewConnection(const ADb: string): TUniConnection; static;
    class function SchemaPath: string; static;
  public
    class function Ready: Boolean; static;
    class procedure Open; static;
    class procedure Close; static;
    class function Connection: TUniConnection; static;
  end;

  TDbTestBase = class
  protected
    FTemp: string;
    function Skip: Boolean;
    function Bytes(const S: string): TBytes;
    function Text(const B: TBytes): string;
    function TemplateBytes(const ATitleExpr: string = '[baslik]'): TBytes;
  public
    [SetupFixture] procedure SetupFixture;
    [TearDownFixture] procedure TearDownFixture;
    [Setup] procedure Setup; virtual;
    [TearDown] procedure TearDown; virtual;
  end;

  [TestFixture]
  TRadReportRepoTests = class(TDbTestBase)
  strict private
    FRepo: TRadReportRepo;
    function NewInfo(const AKey, ADesign: string): TRadReportInfo;
  public
    [Setup] procedure Setup; override;
    [TearDown] procedure TearDown; override;
    [Test] procedure Save_New_FirstDesignIsDefault;
    [Test] procedure Save_SecondDesign_NotDefault;
    [Test] procedure Save_EmptyDesign_BecomesDefaultName;
    [Test] procedure Save_SameContent_NoNewVersion;
    [Test] procedure Save_StaleSha_Conflict;
    [Test] procedure Content_ByVersion;
    [Test] procedure List_DefaultFirstThenByName;
    [Test] procedure Copy_NotDefault_Version1;
    [Test] procedure Delete_DefaultMovesToOldest;
    [Test] procedure Delete_CascadesVersions;
    [Test] procedure SetDefault_Switches;
    [Test] procedure DeleteOldVersions_KeepsCurrent;
    [Test] procedure ResetVersions_Then_NextIsTwo;
    [Test] procedure Find_Missing_False;
  end;

  [TestFixture]
  TRadReportsApiTests = class(TDbTestBase)
  strict private
    FReports: IRadReports;
    FQ1, FQ2: TUniQuery;
    FOut: string;
    procedure Seed(const AKey: string; const ADesigns: array of string);
    function Query(const AMusteri: string): TUniQuery;
  public
    [Setup] procedure Setup; override;
    [TearDown] procedure TearDown; override;
    [Test] procedure LoadDefaults_CreatesOnlyMissing;
    [Test] procedure LoadDefaults_ParsesAtSeparator;
    [Test] procedure Report_List;
    [Test] procedure Export_FileNameFromTemplate;
    [Test] procedure Export_EventsInOrderAndCancel;
    [Test] procedure Export_JobEventBeatsServiceEvent;
    [Test] procedure Export_MultiDesign_NoName_Raises;
    [Test] procedure Export_MultiDesign_WithName_Ok;
    [Test] procedure Export_AllFormats;
    [Test] procedure Export_MissingParam_RaisesNoDialog;
    [Test] procedure TwoJobs_DoNotMix;
    [Test] procedure Shared_UsedAndShadowed;
    [Test] procedure Data_NoName_Raises;
    [Test] procedure Local_SyncPushConflict;
    [Test] procedure Delete_WritesBackup;
    [Test] procedure ResetVersions_WritesBackups;
    [Test] procedure Restore_WritesNewVersion;
    [Test] procedure Copy_And_SetDefault;
    [Test] procedure Actions_KindsAndCount;
    [Test] procedure AddToMenu_BuildsItems;
    [Test] procedure ManageForm_ListsAndEnables;
    [Test] procedure ServiceReleased_JobStillAlive_RaisesOnUse;
    [Test] procedure TwoServices_DesignerHookSurvivesRelease;
    [Test] procedure ManageForm_DesignButton_OpensDesigner;
    [Test] procedure NewNamedDesign_SavedUnderItsKey;
    [Test] procedure Export_RendersDataRows_EveryRun;
    [Test] procedure Design_LoadedTemplate_BandKeepsDataSet;
    [Test] procedure Export_KeepsCursorAndControls;
    [Test] procedure AddToMenu_SubmenuOpen_DoesNotRebuild;
    [Test] procedure AddToMenu_MainMenu_RefreshesOnClick;
  end;

implementation

uses
  Winapi.Windows, Winapi.Messages, System.UITypes, Vcl.ExtCtrls, rad.reports.manage;

type
  /// <summary>Tasarımcı modal açıldığı için çağrı dönmez: zamanlayıcı pencereyi bulur, istenirse kaydeder ve kapatır.
  /// Tasarımcı hiç açılmazsa çağrı hemen döner ve Opened False kalır.</summary>
  TDesignerDriver = class
  strict private
    FTimer: TTimer;
    FSave: Boolean;
    procedure Tick(Sender: TObject);
  public
    Opened: Boolean;
    BandBound: Boolean;
    Error: string;
    constructor Create(ASave: Boolean);
    destructor Destroy; override;
  end;

constructor TDesignerDriver.Create(ASave: Boolean);
begin
  inherited Create;
  FSave := ASave;
  FTimer := TTimer.Create(nil);
  FTimer.Interval := 100;
  FTimer.OnTimer := Tick;
end;

destructor TDesignerDriver.Destroy;
begin
  FTimer.Free;
  inherited;
end;

procedure TDesignerDriver.Tick(Sender: TObject);
var
  I: Integer;
  LDesigner: TfrxCustomDesigner;
  LBand: TfrxComponent;
begin
  for I := 0 to Screen.FormCount - 1 do
    if Screen.Forms[I] is TfrxCustomDesigner then
    begin
      FTimer.Enabled := False;
      LDesigner := TfrxCustomDesigner(Screen.Forms[I]);
      Opened := True;
      LBand := LDesigner.Report.FindObject('MasterData1');
      BandBound := (LBand is TfrxDataBand) and (TfrxDataBand(LBand).DataSet <> nil);
      try
        if FSave then
          frxDesignerComp.OnSaveReport(LDesigner.Report, False);
      except
        on E: Exception do
          Error := E.ClassName + ': ' + E.Message;   // zamanlayıcıdan istisna kaçarsa testi hata kutusu kilitler
      end;
      LDesigner.Modified := False;
      LDesigner.ModalResult := mrCancel;
      Exit;
    end;
end;

{ TTestDb }

class function TTestDb.NewConnection(const ADb: string): TUniConnection;
var
  LPort: string;
begin
  Result := TUniConnection.Create(nil);
  Result.ProviderName := 'PostgreSQL';
  Result.Server := GetEnvironmentVariable('RAPOR_TEST_PGHOST');
  if Result.Server = '' then
    Result.Server := '127.0.0.1';
  LPort := GetEnvironmentVariable('RAPOR_TEST_PGPORT');
  if LPort = '' then
    LPort := '5432';
  Result.Port := StrToInt(LPort);
  Result.Username := GetEnvironmentVariable('RAPOR_TEST_PGUSER');
  if Result.Username = '' then
    Result.Username := 'postgres';
  Result.Password := GetEnvironmentVariable('RAPOR_TEST_PGPWD');
  Result.Database := ADb;
  Result.SpecificOptions.Values['PostgreSQL.Charset'] := 'UTF8';
  Result.Connect;
end;

class function TTestDb.SchemaPath: string;
begin
  // <spec-kits>\rad-library\src\test\RunTests.exe  ->  <spec-kits>\Rad-DB\sql\schema.sql
  Result := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\..\Rad-DB\sql\schema.sql'));
end;

class function TTestDb.Ready: Boolean;
begin
  Result := GetEnvironmentVariable('RAPOR_TEST_PGPWD') <> '';
end;

class procedure TTestDb.Open;
var
  LAdmin: TUniConnection;
  LScript: TUniScript;
  LAll: string;
  LStart, LEnd: Integer;
begin
  Inc(FUsers);
  if FConnection <> nil then
    Exit;
  FName := 'radreports_test_' + LowerCase(TGUID.NewGuid.ToString.Substring(1, 8));
  LAdmin := NewConnection('postgres');
  try
    LAdmin.ExecSQL('create database ' + FName);
  finally
    LAdmin.Free;
  end;
  FConnection := NewConnection(FName);
  LAll := TFile.ReadAllText(SchemaPath, TEncoding.UTF8);
  // yalnız rapor ve rapor_surum: 'CREATE TABLE rapor (' öncesindeki yorumdan 'CREATE TABLE sys_audit_log' öncesine kadar
  LStart := LAll.IndexOf('CREATE TABLE rapor (');
  LStart := LAll.LastIndexOf(#10 + '--', LStart);
  LEnd := LAll.IndexOf('CREATE TABLE sys_audit_log');
  LEnd := LAll.LastIndexOf(#10 + '--', LEnd);
  if (LStart < 0) or (LEnd <= LStart) then
    raise Exception.Create('schema.sql içinde rapor bölümü bulunamadı');
  LScript := TUniScript.Create(nil);
  try
    LScript.Connection := FConnection;
    LScript.SQL.Text := Copy(LAll, LStart + 1, LEnd - LStart);
    LScript.Execute;
  finally
    LScript.Free;
  end;
  if LScript = nil then
    Exit;
end;

class procedure TTestDb.Close;
var
  LAdmin: TUniConnection;
begin
  Dec(FUsers);
  if (FUsers > 0) or (FConnection = nil) then
    Exit;
  FreeAndNil(FConnection);
  LAdmin := NewConnection('postgres');
  try
    LAdmin.ExecSQL('drop database if exists ' + FName + ' with (force)');
  finally
    LAdmin.Free;
  end;
end;

class function TTestDb.Connection: TUniConnection;
begin
  Result := FConnection;
end;

{ TDbTestBase }

procedure TDbTestBase.SetupFixture;
begin
  if TTestDb.Ready then
    TTestDb.Open;
end;

procedure TDbTestBase.TearDownFixture;
begin
  if TTestDb.Ready then
    TTestDb.Close;
end;

procedure TDbTestBase.Setup;
begin
  FTemp := TPath.Combine(TPath.GetTempPath, 'radreports_t_' + TGUID.NewGuid.ToString.Substring(1, 8));
  TDirectory.CreateDirectory(FTemp);
  if TTestDb.Ready then
    TTestDb.Connection.ExecSQL('delete from rapor');
end;

procedure TDbTestBase.TearDown;
begin
  if TDirectory.Exists(FTemp) then
    TDirectory.Delete(FTemp, True);
end;

function TDbTestBase.Skip: Boolean;
begin
  Result := not TTestDb.Ready;
  if Result then
    Assert.Pass('RAPOR_TEST_PGPWD yok: veritabanı testi atlandı');
end;

function TDbTestBase.Bytes(const S: string): TBytes;
begin
  Result := TEncoding.UTF8.GetBytes(S);
end;

function TDbTestBase.Text(const B: TBytes): string;
begin
  Result := TEncoding.UTF8.GetString(B);
end;

function TDbTestBase.TemplateBytes(const ATitleExpr: string): TBytes;
var
  R: TfrxReport;
  DataPage: TfrxDataPage;
  Page: TfrxReportPage;
  Band: TfrxReportTitle;
  Master: TfrxMasterData;
  Memo: TfrxMemoView;
  S: TBytesStream;
begin
  R := TfrxReport.Create(nil);
  S := TBytesStream.Create;
  try
    DataPage := TfrxDataPage.Create(R);
    DataPage.Name := 'Data';
    Page := TfrxReportPage.Create(R);
    Page.Name := 'Page1';
    Page.SetDefaults;
    Band := TfrxReportTitle.Create(Page);
    Band.Name := 'ReportTitle1';
    Band.Height := 30;
    Memo := TfrxMemoView.Create(Band);
    Memo.Name := 'Memo1';
    Memo.SetBounds(0, 0, 400, 20);
    Memo.Text := ATitleExpr;
    Master := TfrxMasterData.Create(Page);
    Master.Name := 'MasterData1';
    Master.Height := 20;
    Master.Top := 40;
    Master.DataSetName := 'ana';
    Memo := TfrxMemoView.Create(Master);
    Memo.Name := 'Memo2';
    Memo.SetBounds(0, 0, 400, 20);
    Memo.Text := '[ana."musteri"] [ana."tutar"]';
    R.SaveToStream(S);
    Result := Copy(S.Bytes, 0, S.Size);
  finally
    S.Free;
    R.Free;
  end;
end;

{ TRadReportRepoTests }

procedure TRadReportRepoTests.Setup;
begin
  inherited;
  if TTestDb.Ready then
    FRepo := TRadReportRepo.Create(TTestDb.Connection);
end;

procedure TRadReportRepoTests.TearDown;
begin
  FreeAndNil(FRepo);
  inherited;
end;

function TRadReportRepoTests.NewInfo(const AKey, ADesign: string): TRadReportInfo;
begin
  Result := Default(TRadReportInfo);
  Result.Key := AKey;
  Result.Design := ADesign;
end;

procedure TRadReportRepoTests.Save_New_FirstDesignIsDefault;
var
  I: TRadReportInfo;
begin
  if Skip then Exit;
  I := NewInfo('zz.liste', 'A');
  Assert.IsTrue(FRepo.Save(I, Bytes('v1'), 'ilk', '', 'ali'));
  Assert.AreEqual(36, Length(I.Id));
  Assert.AreEqual(I.Id, LowerCase(I.Id));
  Assert.AreEqual(1, I.Version);
  Assert.IsTrue(I.IsDefault);
  Assert.AreEqual('ali', I.CreatedBy);
  Assert.AreEqual(TRadReportLocal.Sha256(Bytes('v1')), I.Sha);
end;

procedure TRadReportRepoTests.Save_SecondDesign_NotDefault;
var
  A, B: TRadReportInfo;
begin
  if Skip then Exit;
  A := NewInfo('zz.liste', 'A');
  FRepo.Save(A, Bytes('a'), '', '', 'u');
  B := NewInfo('zz.liste', 'B');
  FRepo.Save(B, Bytes('b'), '', '', 'u');
  Assert.IsFalse(B.IsDefault);
end;

procedure TRadReportRepoTests.Save_EmptyDesign_BecomesDefaultName;
var
  I: TRadReportInfo;
begin
  if Skip then Exit;
  I := NewInfo('zz.liste', '');
  FRepo.Save(I, Bytes('a'), '', '', 'u');
  Assert.AreEqual(RadReportDefaultDesign, I.Design);
end;

procedure TRadReportRepoTests.Save_SameContent_NoNewVersion;
var
  I: TRadReportInfo;
begin
  if Skip then Exit;
  I := NewInfo('zz.liste', 'A');
  FRepo.Save(I, Bytes('v1'), '', '', 'u');
  Assert.IsFalse(FRepo.Save(I, Bytes('v1'), '', I.Sha, 'u'));
  Assert.AreEqual(1, Length(FRepo.Versions(I.Id)));
end;

procedure TRadReportRepoTests.Save_StaleSha_Conflict;
var
  I: TRadReportInfo;
  LOld: string;
begin
  if Skip then Exit;
  I := NewInfo('zz.liste', 'A');
  FRepo.Save(I, Bytes('v1'), '', '', 'u');
  LOld := I.Sha;
  FRepo.Save(I, Bytes('v2'), '', LOld, 'u');
  Assert.WillRaise(
    procedure
    var
      X: TRadReportInfo;
    begin
      X := I;
      FRepo.Save(X, Bytes('v3'), '', LOld, 'u');
    end, ERadReportConflict);
  Assert.AreEqual(2, Length(FRepo.Versions(I.Id)), 'çakışmada sürüm yazılmaz');
end;

procedure TRadReportRepoTests.Content_ByVersion;
var
  I: TRadReportInfo;
begin
  if Skip then Exit;
  I := NewInfo('zz.liste', 'A');
  FRepo.Save(I, Bytes('v1'), '', '', 'u');
  FRepo.Save(I, Bytes('v2'), '', I.Sha, 'u');
  FRepo.Save(I, Bytes('v3'), '', I.Sha, 'u');
  Assert.AreEqual('v3', Text(FRepo.Content(I.Id)));
  Assert.AreEqual('v1', Text(FRepo.Content(I.Id, 1)));
  Assert.AreEqual(3, FRepo.Versions(I.Id)[0].Version, 'en yeni sürüm başta');
end;

procedure TRadReportRepoTests.List_DefaultFirstThenByName;
var
  I: TRadReportInfo;
  L: TArray<TRadReportInfo>;
begin
  if Skip then Exit;
  I := NewInfo('zz.liste', 'Zeta');
  FRepo.Save(I, Bytes('a'), '', '', 'u');
  I := NewInfo('zz.liste', 'Alfa');
  FRepo.Save(I, Bytes('b'), '', '', 'u');
  I := NewInfo('zz.liste', 'Beta');
  FRepo.Save(I, Bytes('c'), '', '', 'u');
  I := NewInfo('baska', 'X');
  FRepo.Save(I, Bytes('d'), '', '', 'u');
  L := FRepo.List('zz.liste');
  Assert.AreEqual(3, Length(L));
  Assert.AreEqual('Zeta', L[0].Design, 'varsayılan önce');
  Assert.AreEqual('Alfa', L[1].Design);
  Assert.AreEqual('Beta', L[2].Design);
end;

procedure TRadReportRepoTests.Copy_NotDefault_Version1;
var
  I, C: TRadReportInfo;
begin
  if Skip then Exit;
  I := NewInfo('zz.liste', 'A');
  FRepo.Save(I, Bytes('v1'), '', '', 'u');
  FRepo.Save(I, Bytes('v2'), '', I.Sha, 'u');
  C := FRepo.Copy(I.Id, 'A kopya', 'veli');
  Assert.AreEqual('A kopya', C.Design);
  Assert.IsFalse(C.IsDefault);
  Assert.AreEqual(1, C.Version);
  Assert.AreEqual('v2', Text(FRepo.Content(C.Id)));
  Assert.AreEqual('veli', C.CreatedBy);
end;

procedure TRadReportRepoTests.Delete_DefaultMovesToOldest;
var
  A, B, C, X: TRadReportInfo;
begin
  if Skip then Exit;
  A := NewInfo('zz.liste', 'A');
  FRepo.Save(A, Bytes('a'), '', '', 'u');
  B := NewInfo('zz.liste', 'B');
  FRepo.Save(B, Bytes('b'), '', '', 'u');
  C := NewInfo('zz.liste', 'C');
  FRepo.Save(C, Bytes('c'), '', '', 'u');
  FRepo.Delete(A.Id);
  Assert.IsFalse(FRepo.FindById(A.Id, X));
  Assert.IsTrue(FRepo.FindById(B.Id, X));
  Assert.IsTrue(X.IsDefault, 'en eski kalan (B) varsayılan olur');
  Assert.IsTrue(FRepo.FindById(C.Id, X));
  Assert.IsFalse(X.IsDefault);
end;

procedure TRadReportRepoTests.Delete_CascadesVersions;
var
  I: TRadReportInfo;
begin
  if Skip then Exit;
  I := NewInfo('zz.liste', 'A');
  FRepo.Save(I, Bytes('v1'), '', '', 'u');
  FRepo.Save(I, Bytes('v2'), '', I.Sha, 'u');
  FRepo.Delete(I.Id);
  Assert.AreEqual(0, Length(FRepo.Versions(I.Id)));
end;

procedure TRadReportRepoTests.SetDefault_Switches;
var
  A, B, X: TRadReportInfo;
begin
  if Skip then Exit;
  A := NewInfo('zz.liste', 'A');
  FRepo.Save(A, Bytes('a'), '', '', 'u');
  B := NewInfo('zz.liste', 'B');
  FRepo.Save(B, Bytes('b'), '', '', 'u');
  FRepo.SetDefault(B.Id);
  Assert.IsTrue(FRepo.FindById(B.Id, X) and X.IsDefault);
  Assert.IsTrue(FRepo.FindById(A.Id, X) and not X.IsDefault);
  Assert.AreEqual('B', FRepo.List('zz.liste')[0].Design);
end;

procedure TRadReportRepoTests.DeleteOldVersions_KeepsCurrent;
var
  I: TRadReportInfo;
  N: Integer;
begin
  if Skip then Exit;
  I := NewInfo('zz.liste', 'A');
  FRepo.Save(I, Bytes('v1'), '', '', 'u');
  for N := 2 to 4 do
    FRepo.Save(I, Bytes('v' + IntToStr(N)), '', I.Sha, 'u');
  Assert.AreEqual(3, FRepo.DeleteOldVersions(I.Id));
  Assert.AreEqual(1, Length(FRepo.Versions(I.Id)));
  Assert.AreEqual(4, FRepo.Versions(I.Id)[0].Version);
  Assert.AreEqual('v4', Text(FRepo.Content(I.Id)));
end;

procedure TRadReportRepoTests.ResetVersions_Then_NextIsTwo;
var
  I, X: TRadReportInfo;
begin
  if Skip then Exit;
  I := NewInfo('zz.liste', 'A');
  FRepo.Save(I, Bytes('v1'), '', '', 'u');
  FRepo.Save(I, Bytes('v2'), '', I.Sha, 'u');
  FRepo.Save(I, Bytes('v3'), '', I.Sha, 'u');
  FRepo.ResetVersions(I.Id);
  Assert.IsTrue(FRepo.FindById(I.Id, X));
  Assert.AreEqual(1, X.Version);
  Assert.AreEqual(1, Length(FRepo.Versions(I.Id)));
  Assert.AreEqual('v3', Text(FRepo.Content(I.Id)), 'içerik korunur');
  Assert.AreEqual(I.Sha, X.Sha);
  Assert.IsTrue(FRepo.Save(X, Bytes('v7'), '', X.Sha, 'u'));
  Assert.AreEqual(2, X.Version);
end;

procedure TRadReportRepoTests.Find_Missing_False;
var
  X: TRadReportInfo;
begin
  if Skip then Exit;
  Assert.IsFalse(FRepo.Find('yok', 'yok', X));
  Assert.IsFalse(FRepo.FindById('00000000-0000-0000-0000-000000000000', X));
end;

{ TRadReportsApiTests }

procedure TRadReportsApiTests.Setup;
begin
  inherited;
  if not TTestDb.Ready then
    Exit;
  FReports := TRadReports.New(TTestDb.Connection, 'ali');
  FReports.LocalFolder := TPath.Combine(FTemp, 'local');
  FOut := TPath.Combine(FTemp, 'out');
  FQ1 := Query('Ahmet/Yılmaz');
  FQ2 := Query('Mehmet');
end;

procedure TRadReportsApiTests.TearDown;
begin
  FreeAndNil(FQ1);
  FreeAndNil(FQ2);
  FReports := nil;
  inherited;
end;

function TRadReportsApiTests.Query(const AMusteri: string): TUniQuery;
begin
  Result := TUniQuery.Create(nil);
  Result.Connection := TTestDb.Connection;
  Result.SQL.Text := 'select :m as musteri, 1234.5::numeric(18,2) as tutar, date ''2026-11-01'' as tarih';
  Result.ParamByName('m').AsString := AMusteri;
  Result.Open;
end;

procedure TRadReportsApiTests.Seed(const AKey: string; const ADesigns: array of string);
var
  LFolder, LDesign: string;
begin
  LFolder := TPath.Combine(FTemp, 'seed_' + TGUID.NewGuid.ToString.Substring(1, 6));
  TDirectory.CreateDirectory(LFolder);
  for LDesign in ADesigns do
    if LDesign = '' then
      TFile.WriteAllBytes(TPath.Combine(LFolder, AKey + '.fr3'), TemplateBytes)
    else
      TFile.WriteAllBytes(TPath.Combine(LFolder, AKey + '@' + LDesign + '.fr3'), TemplateBytes);
  FReports.LoadDefaults(LFolder);
end;

procedure TRadReportsApiTests.LoadDefaults_CreatesOnlyMissing;
var
  LFolder: string;
  L: TArray<TRadReportInfo>;
  J: IRadReport;
begin
  if Skip then Exit;
  LFolder := TPath.Combine(FTemp, 'defaults');
  TDirectory.CreateDirectory(LFolder);
  TFile.WriteAllBytes(TPath.Combine(LFolder, 'zz.liste.fr3'), TemplateBytes);
  Assert.AreEqual(1, FReports.LoadDefaults(LFolder));
  L := FReports.Report('zz.liste').List;
  Assert.AreEqual(1, Length(L));
  Assert.AreEqual(RadReportDefaultDesign, L[0].Design);
  Assert.IsTrue(L[0].IsDefault);
  // ikinci çağrı dokunmaz; kullanıcı değişikliği (yeni sürüm) ezilmez
  J := FReports.Report('zz.liste');
  J.SyncToLocal;
  TFile.WriteAllBytes(FReports.LocalFolder + '\zz.liste\' + RadReportDefaultDesign + '.fr3', TemplateBytes('[x]'));
  Assert.IsTrue(J.PushFromLocal);
  Assert.AreEqual(0, FReports.LoadDefaults(LFolder));
  Assert.AreEqual(2, FReports.Report('zz.liste').List[0].Version, 'var olan tasarım ezilmedi');
end;

procedure TRadReportsApiTests.LoadDefaults_ParsesAtSeparator;
var
  L: TArray<TRadReportInfo>;
begin
  if Skip then Exit;
  Seed('Kasa.Liste', ['', 'Kasa Özeti']);
  L := FReports.Report('kasa.liste').List;
  Assert.AreEqual(2, Length(L));
  Assert.AreEqual(RadReportDefaultDesign, L[0].Design, 'anahtar küçük harfe iner, varsayılan önce');
  Assert.AreEqual('Kasa Özeti', L[1].Design);
end;

procedure TRadReportsApiTests.Report_List;
begin
  if Skip then Exit;
  Seed('zz.liste', ['A', 'B']);
  Assert.AreEqual(2, Length(FReports.Report('zz.liste').List));
  Assert.AreEqual(0, Length(FReports.Report('yok').List));
end;

procedure TRadReportsApiTests.Export_FileNameFromTemplate;
var
  P: string;
begin
  if Skip then Exit;
  Seed('zz.liste', ['']);
  P := FReports.Report('zz.liste').Data(FQ1, 'ana').Param('baslik', 'Başlık')
    .FileName('fis-{ana|musteri}-{ana|tarih}-{ana|tutar}').Export(rfPdf, FOut);
  Assert.IsTrue(TFile.Exists(P), P);
  Assert.AreEqual('fis-Ahmet_Yılmaz-2026-11-01-1234.50.pdf', ExtractFileName(P));
  Assert.IsTrue(TFile.GetSize(P) > 500);
end;

procedure TRadReportsApiTests.Export_EventsInOrderAndCancel;
var
  LOrder, P: string;
  LAfter: Boolean;
begin
  if Skip then Exit;
  Seed('zz.liste', ['']);
  LOrder := '';
  P := FReports.Report('zz.liste').Data(FQ1, 'ana').Param('baslik', 'x').FileName('x')
    .OnFileName(procedure(var I: TRadReportExportInfo) begin LOrder := LOrder + 'A'; I.Name := I.Name + '-ev'; end)
    .OnBeforeExport(procedure(var I: TRadReportExportInfo) begin LOrder := LOrder + 'B'; end)
    .OnAfterExport(procedure(var I: TRadReportExportInfo)
      begin
        LOrder := LOrder + 'C';
        Assert.IsTrue(TFile.Exists(I.FilePath));
      end)
    .Export(rfPdf, FOut);
  Assert.AreEqual('ABC', LOrder);
  Assert.AreEqual('x-ev.pdf', ExtractFileName(P));
  LAfter := False;
  P := FReports.Report('zz.liste').Data(FQ1, 'ana').Param('baslik', 'x')
    .OnFileName(procedure(var I: TRadReportExportInfo) begin I.Cancel := True; end)
    .OnAfterExport(procedure(var I: TRadReportExportInfo) begin LAfter := True; end)
    .Export(rfPdf, FOut);
  Assert.AreEqual('', P);
  Assert.IsFalse(LAfter);
end;

procedure TRadReportsApiTests.Export_JobEventBeatsServiceEvent;
var
  LWho, P: string;
begin
  if Skip then Exit;
  Seed('zz.liste', ['']);
  FReports.OnFileName := procedure(var I: TRadReportExportInfo) begin LWho := 'service'; end;
  P := FReports.Report('zz.liste').Data(FQ1, 'ana').Param('baslik', 'x').FileName('s').Export(rfPdf, FOut);
  Assert.AreEqual('service', LWho);
  Assert.AreEqual('s.pdf', ExtractFileName(P));
  P := FReports.Report('zz.liste').Data(FQ1, 'ana').Param('baslik', 'x').FileName('j')
    .OnFileName(procedure(var I: TRadReportExportInfo) begin LWho := 'job'; end).Export(rfPdf, FOut);
  Assert.AreEqual('job', LWho);
end;

procedure TRadReportsApiTests.Export_MultiDesign_NoName_Raises;
begin
  if Skip then Exit;
  Seed('zz.liste', ['A', 'B']);
  Assert.WillRaise(
    procedure
    begin
      FReports.Report('zz.liste').Data(FQ1, 'ana').Param('baslik', 'x').Export(rfPdf, FOut);
    end, ERadReportDesignRequired);
end;

procedure TRadReportsApiTests.Export_MultiDesign_WithName_Ok;
var
  P: string;
begin
  if Skip then Exit;
  Seed('zz.liste', ['A', 'B']);
  P := FReports.Report('zz.liste', 'B').Data(FQ1, 'ana').Param('baslik', 'x').Export(rfPdf, FOut);
  Assert.AreEqual('B.pdf', ExtractFileName(P), 'şablon yoksa tasarım adı');
  Assert.WillRaise(procedure begin FReports.Report('zz.liste', 'Yok').Data(FQ1, 'ana').Export(rfPdf, FOut); end,
    ERadReportNotFound);
end;

procedure TRadReportsApiTests.Export_AllFormats;
var
  F: TRadReportFormat;
  P: string;
begin
  if Skip then Exit;
  Seed('zz.liste', ['']);
  for F := Low(TRadReportFormat) to High(TRadReportFormat) do
  begin
    P := FReports.Report('zz.liste').Data(FQ1, 'ana').Param('baslik', 'x').FileName('t').Export(F, FOut);
    Assert.IsTrue(TFile.Exists(P), 'yazılmadı: ' + RadReportFormatExt[F]);
    Assert.IsTrue(TFile.GetSize(P) > 0, 'boş: ' + RadReportFormatExt[F]);
  end;
end;

procedure TRadReportsApiTests.Export_MissingParam_RaisesNoDialog;
begin
  // Hata kutusu açılsaydı test askıda kalırdı; sessiz modda istisna gelmeli.
  if Skip then Exit;
  Seed('zz.liste', ['']);
  Assert.WillRaise(procedure begin FReports.Report('zz.liste').Data(FQ1, 'ana').Export(rfPdf, FOut); end, Exception);
end;

procedure TRadReportsApiTests.TwoJobs_DoNotMix;
var
  JA, JB: IRadReport;
  PA, PB: string;
begin
  if Skip then Exit;
  Seed('zz.liste', ['']);
  // iki form, aynı anahtar, aynı 'ana' adı, farklı veri: iç içe kurulup sırayla çalıştırılır
  JA := FReports.Report('zz.liste').Data(FQ1, 'ana').Param('baslik', 'A').FileName('{ana|musteri}');
  JB := FReports.Report('zz.liste').Data(FQ2, 'ana').Param('baslik', 'B').FileName('{ana|musteri}');
  PA := JA.Export(rfPdf, FOut);
  PB := JB.Export(rfPdf, FOut);
  Assert.AreEqual('Ahmet_Yılmaz.pdf', ExtractFileName(PA));
  Assert.AreEqual('Mehmet.pdf', ExtractFileName(PB));
  // aynı iş nesnesi ikinci kez: veriler yerinde
  PA := JA.FileName('tekrar-{ana|musteri}').Export(rfPdf, FOut);
  Assert.AreEqual('tekrar-Ahmet_Yılmaz.pdf', ExtractFileName(PA));
end;

procedure TRadReportsApiTests.Shared_UsedAndShadowed;
var
  P: string;
begin
  if Skip then Exit;
  Seed('zz.liste', ['']);
  FReports.Shared(FQ2, 'ana');
  P := FReports.Report('zz.liste').Param('baslik', 'x').FileName('{ana|musteri}').Export(rfPdf, FOut);
  Assert.AreEqual('Mehmet.pdf', ExtractFileName(P), 'sabit veri kümesi kullanılır');
  P := FReports.Report('zz.liste').Data(FQ1, 'ana').Param('baslik', 'x').FileName('{ana|musteri}').Export(rfPdf, FOut);
  Assert.AreEqual('Ahmet_Yılmaz.pdf', ExtractFileName(P), 'iş verisi sabiti gölgeler');
  FReports.Unshare('ana');
  // sabit kaldırılınca veri yok: şablon çözülemez, dosya adı tasarım adına düşer
  P := FReports.Report('zz.liste').Param('baslik', 'x').FileName('{ana|musteri}').Export(rfPdf, FOut);
  Assert.AreEqual(RadReportDefaultDesign + '.pdf', ExtractFileName(P), 'sabit kaldırıldı');
end;

procedure TRadReportsApiTests.Data_NoName_Raises;
var
  Q: TUniQuery;
begin
  if Skip then Exit;
  Q := TUniQuery.Create(nil);
  try
    Assert.WillRaise(procedure begin FReports.Report('zz.liste').Data(Q); end, ERadReport);
    Q.Name := 'qryAna';
    Assert.IsNotNull(FReports.Report('zz.liste').Data(Q));
  finally
    Q.Free;
  end;
end;

procedure TRadReportsApiTests.Local_SyncPushConflict;
var
  J: IRadReport;
  P: string;
  LRepo: TRadReportRepo;
  LInfo: TRadReportInfo;
begin
  if Skip then Exit;
  Seed('zz.liste', ['']);
  J := FReports.Report('zz.liste');
  P := J.SyncToLocal;
  Assert.IsTrue(TFile.Exists(P));
  Assert.IsFalse(J.PushFromLocal, 'değişmeyen dosya yüklenmez');
  TFile.WriteAllBytes(P, TFile.ReadAllBytes(P) + Bytes(' '));
  Assert.IsTrue(J.PushFromLocal);
  Assert.AreEqual(2, J.List[0].Version);
  Assert.IsFalse(J.PushFromLocal, 'yüklendikten sonra değişmemiş sayılır');
  // yerel + DB aynı anda değişince çakışma
  TFile.WriteAllBytes(P, TFile.ReadAllBytes(P) + Bytes('  '));
  LRepo := TRadReportRepo.Create(TTestDb.Connection);
  try
    LRepo.Find('zz.liste', RadReportDefaultDesign, LInfo);
    LRepo.Save(LInfo, Bytes('baskasi'), 'başkası', '', 'veli');
  finally
    LRepo.Free;
  end;
  Assert.WillRaise(procedure begin J.PushFromLocal; end, ERadReportConflict);
end;

procedure TRadReportsApiTests.Delete_WritesBackup;
begin
  if Skip then Exit;
  Seed('zz.liste', ['A', 'B']);
  FReports.Report('zz.liste', 'A').Delete;
  Assert.AreEqual(1, Length(FReports.Report('zz.liste').List));
  Assert.IsTrue(FReports.Report('zz.liste').List[0].IsDefault, 'B varsayılan olur');
  Assert.AreEqual(1, Length(TDirectory.GetFiles(TPath.Combine(FReports.LocalFolder, '_deleted'))));
end;

procedure TRadReportsApiTests.ResetVersions_WritesBackups;
var
  J: IRadReport;
  P: string;
begin
  if Skip then Exit;
  Seed('zz.liste', ['']);
  J := FReports.Report('zz.liste');
  P := J.SyncToLocal;
  TFile.WriteAllBytes(P, TFile.ReadAllBytes(P) + Bytes(' '));
  J.PushFromLocal;
  TFile.WriteAllBytes(P, TFile.ReadAllBytes(P) + Bytes(' '));
  J.PushFromLocal;
  Assert.AreEqual(3, Length(J.Versions));
  J.ResetVersions;
  Assert.AreEqual(1, Length(J.Versions));
  Assert.AreEqual(1, J.List[0].Version);
  Assert.AreEqual(3, Length(TDirectory.GetFiles(TPath.Combine(FReports.LocalFolder, '_deleted'))), 'her sürüm yedeklenir');
  J.DeleteOldVersions;   // güncel tek: sessizce 0
  Assert.AreEqual(1, Length(J.Versions));
end;

procedure TRadReportsApiTests.Restore_WritesNewVersion;
var
  J: IRadReport;
  P: string;
  V: TArray<TRadReportVersion>;
begin
  if Skip then Exit;
  Seed('zz.liste', ['']);
  J := FReports.Report('zz.liste');
  P := J.SyncToLocal;
  TFile.WriteAllBytes(P, TFile.ReadAllBytes(P) + Bytes(' '));
  J.PushFromLocal;
  J.Restore(1);
  V := J.Versions;
  Assert.AreEqual(3, Length(V));
  Assert.AreEqual(V[2].Sha, V[0].Sha, 'v3 içeriği v1 ile aynı');
  Assert.AreEqual('v1 geri yüklendi', V[0].Note);
end;

procedure TRadReportsApiTests.Copy_And_SetDefault;
var
  L: TArray<TRadReportInfo>;
begin
  if Skip then Exit;
  Seed('zz.liste', ['']);
  FReports.Report('zz.liste').Copy('Özet');
  L := FReports.Report('zz.liste').List;
  Assert.AreEqual(2, Length(L));
  Assert.AreEqual('Özet', L[1].Design);
  FReports.Report('zz.liste', 'Özet').SetDefault;
  L := FReports.Report('zz.liste').List;
  Assert.AreEqual('Özet', L[0].Design);
  Assert.IsTrue(L[0].IsDefault);
  Assert.IsFalse(L[1].IsDefault);
end;

procedure TRadReportsApiTests.Actions_KindsAndCount;
var
  A: TActionList;
  LFormats: Integer;
begin
  if Skip then Exit;
  Seed('zz.liste', ['A', 'B']);
  A := FReports.Report('zz.liste').Actions;
  LFormats := Ord(High(TRadReportFormat)) - Ord(Low(TRadReportFormat)) + 1;
  // 2 önizle + yazdır + N export + posta + 2 tasarla + yeni + yönet
  Assert.AreEqual(2 + 1 + LFormats + 1 + 2 + 1 + 1, A.ActionCount);
  Assert.AreEqual('Önizle: A', A.Actions[0].Caption);
  Assert.IsTrue(TAction(A.Actions[0]).Checked, 'varsayılan işaretli');
  Assert.AreEqual(2, FReports.Report('yok').Actions.ActionCount, 'tasarım yoksa yalnız yeni + yönet');
end;

procedure TRadReportsApiTests.AddToMenu_BuildsItems;
var
  LPopup: TPopupMenu;
  LRoot: TMenuItem;
  I, LSub: Integer;
begin
  if Skip then Exit;
  Seed('zz.liste', ['A', 'B']);
  LPopup := TPopupMenu.Create(nil);
  try
    LRoot := TMenuItem.Create(LPopup);
    LRoot.Caption := 'Raporlar';
    LPopup.Items.Add(LRoot);
    FReports.Report('zz.liste').Data(FQ1, 'ana').AddToMenu(LRoot);
    // A, B, -, Yazdır, Dışa aktar▸, E-posta, -, Tasarla▸, Yeni tasarım, Rapor Yöneticisi
    Assert.AreEqual(10, LRoot.Count);
    Assert.AreEqual('Önizle: A', LRoot[0].Caption);
    Assert.IsTrue(LRoot[0].Default);
    LSub := 0;
    for I := 0 to LRoot.Count - 1 do
      if LRoot[I].Count > 0 then
        Inc(LSub);
    Assert.AreEqual(2, LSub, 'Dışa aktar ve Tasarla alt menüleri');
    Assert.AreEqual(Ord(High(TRadReportFormat)) + 1, LRoot[4].Count);
    // OnPopup zinciri: yeniden kurulunca öğe sayısı aynı kalır
    LPopup.OnPopup(LPopup);
    Assert.AreEqual(10, LRoot.Count);
  finally
    LPopup.Free;
  end;
end;

procedure TRadReportsApiTests.AddToMenu_SubmenuOpen_DoesNotRebuild;
var
  LPopup: TPopupMenu;
  LRoot: TMenuItem;
begin
  // Fare alt menüye gelince Windows WM_INITMENUPOPUP gönderir, VCL bunu öğenin Click'ine çevirir. Burada yeniden kurmak
  // ekrandaki menüyü söküp takar ve her turda SQL çalıştırır (sahibin belirtisi: alt menü gelmiyor, ekran titriyor).
  // Liste menü açılırken OnPopup'ta zaten yenilenir. Tag işareti: serbest kalan adres yeni öğeye verilebildiği için
  // nesne karşılaştırması güvenilir değil.
  if Skip then Exit;
  Seed('zz.liste', ['A', 'B']);
  LPopup := TPopupMenu.Create(nil);
  try
    LRoot := TMenuItem.Create(LPopup);
    LRoot.Caption := 'Raporlar';
    LPopup.Items.Add(LRoot);
    FReports.Report('zz.liste').Data(FQ1, 'ana').AddToMenu(LRoot);
    LPopup.OnPopup(LPopup);
    LRoot[0].Tag := 777;
    SendMessage(PopupList.Window, WM_INITMENUPOPUP, WPARAM(LRoot.Handle), 0);
    Assert.AreEqual(777, LRoot[0].Tag, 'alt menü açılırken öğeler yeniden kurulmamalı');
    // Yeni tasarım bir sonraki açılışta görünür
    Seed('zz.liste', ['C']);
    LPopup.OnPopup(LPopup);
    Assert.AreEqual('Önizle: C', LRoot[2].Caption);
  finally
    LPopup.Free;
  end;
end;

procedure TRadReportsApiTests.AddToMenu_MainMenu_RefreshesOnClick;
var
  LMain: TMainMenu;
  LRoot: TMenuItem;
begin
  // Ana menüde OnPopup yoktur: liste üst öğenin Click'inde yenilenir.
  if Skip then Exit;
  Seed('zz.liste', ['A']);
  LMain := TMainMenu.Create(nil);
  try
    LRoot := TMenuItem.Create(LMain);
    LRoot.Caption := 'Raporlar';
    LMain.Items.Add(LRoot);
    FReports.Report('zz.liste').Data(FQ1, 'ana').AddToMenu(LRoot);
    Seed('zz.liste', ['B']);
    LRoot.Click;
    Assert.AreEqual('Önizle: B', LRoot[1].Caption);
  finally
    LMain.Free;
  end;
end;

procedure TRadReportsApiTests.ManageForm_ListsAndEnables;
var
  F: TRadReportManageForm;
begin
  if Skip then Exit;
  Seed('zz.liste', ['A', 'B']);
  F := TRadReportManageForm.Create(nil);
  try
    F.Job := FReports.Report('zz.liste').Data(FQ1, 'ana');
    F.Refresh;
    Assert.AreEqual(2, F.viewDesign.DataController.RecordCount);
    Assert.AreEqual(1, F.viewVersion.DataController.RecordCount);
    F.ActionList.UpdateAction(F.actSetDefault);
    Assert.IsFalse(F.actSetDefault.Enabled, 'varsayılan seçiliyken kapalı');
    F.viewDesign.DataController.FocusedRecordIndex := 1;
    F.ActionList.UpdateAction(F.actSetDefault);
    Assert.IsTrue(F.actSetDefault.Enabled);
    F.ActionList.UpdateAction(F.actReset);
    Assert.IsFalse(F.actReset.Enabled, 'tek sürümde sıfırlama kapalı');
  finally
    F.Free;
  end;
end;

procedure TRadReportsApiTests.ServiceReleased_JobStillAlive_RaisesOnUse;
var
  J: IRadReport;
  P: string;
begin
  if Skip then Exit;
  Seed('zz.liste', ['']);
  J := FReports.Report('zz.liste').Data(FQ1, 'ana').Param('baslik', 'x').FileName('once');
  FReports := nil;   // iş nesnesi servisi tutar: hâlâ çalışır
  P := J.Export(rfPdf, FOut);
  Assert.AreEqual('once.pdf', ExtractFileName(P));
  J := nil;
  FReports := TRadReports.New(TTestDb.Connection, 'ali');
  FReports.LocalFolder := TPath.Combine(FTemp, 'local');
end;

procedure TRadReportsApiTests.TwoServices_DesignerHookSurvivesRelease;
var
  LNew: IRadReports;
begin
  // Şirket değişimi sırası: yeni servis önce kurulur, eski servis sonra bırakılır. FastReport'un TfrxDesigner.Destroy'u
  // global frxDesignerComp'u koşulsuz nil yapar; kanca kaybolursa tasarımcı Kaydet'te dosya diyaloğuna düşer.
  if Skip then Exit;
  LNew := TRadReports.New(TTestDb.Connection, 'veli');
  FReports := nil;
  Assert.IsNotNull(frxDesignerComp, 'eski servis gidince tasarımcı bileşeni nil kalmamalı');
  Assert.IsTrue(Assigned(frxDesignerComp.OnSaveReport), 'OnSaveReport kancası yaşayan servise bağlı olmalı');
  FReports := LNew;
end;

procedure TRadReportsApiTests.ManageForm_DesignButton_OpensDesigner;
var
  F: TRadReportManageForm;
  LDriver: TDesignerDriver;
begin
  // Tasarla düğmesi arayüz üzerinden .Design çağırır; aynı adlı özellik yordamı gizlerse sessizce hiçbir şey olmaz.
  if Skip then Exit;
  Seed('zz.liste', ['A']);
  LDriver := TDesignerDriver.Create(False);
  F := TRadReportManageForm.Create(nil);
  try
    F.Job := FReports.Report('zz.liste').Data(FQ1, 'ana');
    F.Refresh;
    F.actDesignExecute(F);
    Assert.IsTrue(LDriver.Opened, 'Tasarla düğmesi tasarımcıyı açmalı');
  finally
    F.Free;
    LDriver.Free;
  end;
end;

procedure TRadReportsApiTests.NewNamedDesign_SavedUnderItsKey;
var
  LDriver: TDesignerDriver;
  L: TArray<TRadReportInfo>;
begin
  // Yeni tasarım adla açılıp kaydedilince anahtarı ve adı korunmalı. Repo.Find'ın out parametresi kaydı sıfırlarsa
  // satır boş anahtarla 'Varsayılan' adıyla yazılır ve hiçbir listede görünmez.
  if Skip then Exit;
  LDriver := TDesignerDriver.Create(True);
  try
    FReports.Report('zz.yeni', 'Kasalar').Data(FQ1, 'ana').Design;
    Assert.IsTrue(LDriver.Opened, 'tasarımcı açılmalı');
    Assert.AreEqual('', LDriver.Error);
  finally
    LDriver.Free;
  end;
  L := FReports.Report('zz.yeni').List;
  Assert.AreEqual(1, Length(L), 'tasarım kendi anahtarının listesinde görünmeli');
  Assert.AreEqual('Kasalar', L[0].Design);
  Assert.IsTrue(L[0].IsDefault, 'anahtarın ilk tasarımı varsayılan');
  Assert.AreEqual(0, Length(FReports.Report('').List), 'boş anahtarla satır yazılmamalı');
end;

procedure TRadReportsApiTests.Export_RendersDataRows_EveryRun;
var
  J: IRadReport;
begin
  // Bant veri kümesine yükleme anında bağlanır. Köprü yüklemeden sonra kurulursa rapor hatasız ama satırsız çıkar;
  // bu yüzden dosya adı değil, çıktının içeriği denetlenir.
  if Skip then Exit;
  Seed('zz.liste', ['']);
  J := FReports.Report('zz.liste').Data(FQ2, 'ana').Param('baslik', 'x');
  Assert.Contains(TFile.ReadAllText(J.FileName('bir').Export(rfCsv, FOut)), 'Mehmet', 'ilk çalıştırmada satır basılmalı');
  Assert.Contains(TFile.ReadAllText(J.FileName('iki').Export(rfCsv, FOut)), 'Mehmet', 'aynı işin ikinci çalıştırması da basmalı');
end;

procedure TRadReportsApiTests.Design_LoadedTemplate_BandKeepsDataSet;
var
  LDriver: TDesignerDriver;
begin
  // Sahibin belirtisi: kayıtlı tasarım tasarımcıda açılınca Master Data'nın DataSet'i boş görünüyordu, önizleme satırsızdı.
  // Akışın tamamı: tasarla, kaydet (.fr3'e <Datasets> yazılır), yeniden yükleyip bas.
  if Skip then Exit;
  Seed('zz.liste', ['']);
  LDriver := TDesignerDriver.Create(True);
  try
    FReports.Report('zz.liste').Data(FQ1, 'ana').Design;
    Assert.IsTrue(LDriver.Opened, 'tasarımcı açılmalı');
    Assert.IsTrue(LDriver.BandBound, 'kayıtlı bant veri kümesine bağlı açılmalı');
    Assert.AreEqual('', LDriver.Error);
  finally
    LDriver.Free;
  end;
  Assert.AreEqual(2, FReports.Report('zz.liste').List[0].Version, 'kaydet yeni sürüm yazmalı');
  Assert.Contains(TFile.ReadAllText(FReports.Report('zz.liste').Data(FQ1, 'ana').Param('baslik', 'x').FileName('sonra')
    .Export(rfCsv, FOut)), 'Ahmet', 'tasarımcıdan kaydedilen şablon satır basmalı');
end;

procedure TRadReportsApiTests.Export_KeepsCursorAndControls;
var
  Q: TUniQuery;
  P: string;
begin
  // Rapor listenin canlı sorgusunu dolaşır: grid'in seçili satırı değişmemeli, dosya adı şablonu da seçili satırı okumalı.
  if Skip then Exit;
  Seed('zz.liste', ['']);
  Q := TUniQuery.Create(nil);
  try
    Q.Connection := TTestDb.Connection;
    Q.SQL.Text := 'select m as musteri, 1.50::numeric(18,2) as tutar from unnest(array[''A'',''B'',''C'']) m order by 1';
    Q.Open;
    Q.Next;
    P := FReports.Report('zz.liste').Data(Q, 'ana').Param('baslik', 'x').FileName('{ana|musteri}').Export(rfCsv, FOut);
    Assert.AreEqual(2, Q.RecNo, 'imleç seçili satırda kalmalı');
    Assert.IsFalse(Q.ControlsDisabled, 'denetimler geri açılmalı');
    Assert.AreEqual('B.csv', ExtractFileName(P), 'dosya adı seçili satırdan gelmeli');
    Assert.Contains(TFile.ReadAllText(P), 'C', 'tüm satırlar basılmalı');
  finally
    Q.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadReportRepoTests);
  TDUnitX.RegisterTestFixture(TRadReportsApiTests);

end.
