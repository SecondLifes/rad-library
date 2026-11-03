unit FormStateDbTests;

{ LIVE tests of TRadUniStateStore. Servers and credentials: %LOCALAPPDATA%\rad\test-db.env
  (RAD_PG_*, RAD_FB_*); SQL Server is localhost\rad_filter_test with Windows authentication.
  Only the table rad_form_state_test is created, and it is dropped at the end.
  Firebird runs on Win32 only unless RAD_FB_CLIENT64 names a 64-bit client. }

interface

uses
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  Data.DB,
  DUnitX.TestFramework,
  Uni,
  mormot.core.base,
  mormot.core.variants,
  rad.cipher,
  rad.formstate.core,
  rad.formstate.store,
  rad.formstate.uni;

type
  TRadFormStateDbTests = class
  private
    FConnection: TUniConnection;
    FStore: IRadStateStore;
    FSkipReason: string;
    function Skipped: Boolean;
    function RowCount: Integer;
    procedure Exec(const ASql: string);
  protected
    /// <summary>Configures and opens FConnection, or sets FSkipReason.</summary>
    procedure Connect(AConnection: TUniConnection); virtual; abstract;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;
    [Setup]
    procedure Setup;
    [Test]
    procedure SaveThenLoad_BinaryPayload_ComesBackIdentical;
    [Test]
    procedure SaveTwice_UpdatesTheSameRow;
    [Test]
    procedure Delete_RemovesTheRow;
    [Test]
    procedure LoadScope_TurkishScope_ReturnsOnlyItsRows;
    [Test]
    procedure Repository_EncryptedRoundTrip;
    [Test]
    procedure Measure_SaveAndLoad;
  end;

  [TestFixture]
  TPostgreSqlStateTests = class(TRadFormStateDbTests)
  protected
    procedure Connect(AConnection: TUniConnection); override;
  end;

  [TestFixture]
  TSqlServerStateTests = class(TRadFormStateDbTests)
  protected
    procedure Connect(AConnection: TUniConnection); override;
  end;

  [TestFixture]
  TFirebirdStateTests = class(TRadFormStateDbTests)
  protected
    procedure Connect(AConnection: TUniConnection); override;
  end;

  [TestFixture]
  TUniStateStoreOfflineTests = class
  public
    [Test]
    procedure CreateTableSql_UnknownProvider_Raises;
    [Test]
    procedure TableName_NotAnIdentifier_Raises;
  end;

implementation

uses
  System.IOUtils,
  PostgreSQLUniProvider,
  SQLServerUniProvider,
  InterBaseUniProvider,
  mormot.core.text,
  mormot.core.unicode;

const
  TEST_TABLE = 'rad_form_state_test';
  SCOPE_TR = 'Çağrı Şükrü';
  PAYLOAD_SIZE = 300000;

var
  GEnv: TStringList;

function Env(const AKey: string; const ADefault: string = ''): string;
var
  I: Integer;
begin
  Result := GetEnvironmentVariable(AKey);
  if Result <> '' then
    Exit;
  if GEnv = nil then
  begin
    GEnv := TStringList.Create;
    if TFile.Exists(TPath.Combine(TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'), 'rad'), 'test-db.env')) then
      GEnv.LoadFromFile(TPath.Combine(TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'), 'rad'),
        'test-db.env'), TEncoding.UTF8);
  end;
  for I := 0 to GEnv.Count - 1 do
    if GEnv[I].StartsWith(AKey + '=') then
      Exit(System.SysUtils.Trim(GEnv[I].Substring(Length(AKey) + 1))); // mORMot shadows Trim
  Result := ADefault;
end;

function Payload(ASeed: Byte): RawByteString;
var
  I: Integer;
begin
  SetLength(Result, PAYLOAD_SIZE);
  for I := 1 to PAYLOAD_SIZE do
    Result[I] := AnsiChar((I * 31 + ASeed) and $FF); // every byte value, #0 included
end;

{ TRadFormStateDbTests }

function TRadFormStateDbTests.Skipped: Boolean;
begin
  Result := FSkipReason <> '';
  if Result then
    System.Writeln('  SKIPPED ', ClassName, ': ', FSkipReason);
end;

procedure TRadFormStateDbTests.Exec(const ASql: string);
begin
  FConnection.ExecSQL(ASql);
end;

procedure TRadFormStateDbTests.SetupFixture;
begin
  FConnection := TUniConnection.Create(nil);
  FConnection.LoginPrompt := False;
  try
    Connect(FConnection);
  except
    on E: EDatabaseError do
      FSkipReason := E.Message;
  end;
  if FSkipReason <> '' then
    Exit;
  try
    Exec('drop table ' + TEST_TABLE);
  except
    on EDatabaseError do; // not there yet
  end;
  Exec(TRadUniStateStore.CreateTableSql(FConnection.ProviderName, TEST_TABLE));
  FStore := TRadUniStateStore.Create(FConnection, TEST_TABLE);
end;

procedure TRadFormStateDbTests.TearDownFixture;
begin
  FStore := nil;
  if (FSkipReason = '') and FConnection.Connected then
    Exec('drop table ' + TEST_TABLE);
  FConnection.Free;
end;

procedure TRadFormStateDbTests.Setup;
begin
  if FSkipReason = '' then
    Exec('delete from ' + TEST_TABLE);
end;

function TRadFormStateDbTests.RowCount: Integer;
var
  LQuery: TUniQuery;
begin
  LQuery := TUniQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := 'select count(*) from ' + TEST_TABLE;
    LQuery.Open;
    Result := LQuery.Fields[0].AsInteger;
  finally
    LQuery.Free;
  end;
end;

procedure TRadFormStateDbTests.SaveThenLoad_BinaryPayload_ComesBackIdentical;
var
  LKey: TRadStateKey;
  LBack: RawByteString;
begin
  if Skipped then
    Exit;
  LKey := TRadStateKey.Make('emrah', 'TLoginForm');
  FStore.Save(LKey, Payload(1));
  Assert.IsTrue(FStore.Load(LKey, LBack));
  Assert.AreEqual(PAYLOAD_SIZE, Length(LBack));
  Assert.IsTrue(LBack = Payload(1), 'bytes differ');
  Assert.IsFalse(FStore.Load(TRadStateKey.Make('emrah', 'TOther'), LBack));
end;

procedure TRadFormStateDbTests.SaveTwice_UpdatesTheSameRow;
var
  LKey: TRadStateKey;
  LBack: RawByteString;
begin
  if Skipped then
    Exit;
  LKey := TRadStateKey.Make('', 'TLoginForm');
  FStore.Save(LKey, 'first');
  FStore.Save(LKey, 'second');
  Assert.AreEqual(1, RowCount);
  Assert.IsTrue(FStore.Load(LKey, LBack));
  Assert.IsTrue(LBack = 'second');
end;

procedure TRadFormStateDbTests.Delete_RemovesTheRow;
var
  LKey: TRadStateKey;
  LBack: RawByteString;
begin
  if Skipped then
    Exit;
  LKey := TRadStateKey.Make('emrah', 'TLoginForm');
  FStore.Save(LKey, 'x');
  FStore.Delete(LKey);
  Assert.AreEqual(0, RowCount);
  Assert.IsFalse(FStore.Load(LKey, LBack));
end;

procedure TRadFormStateDbTests.LoadScope_TurkishScope_ReturnsOnlyItsRows;
var
  LEntries: TRadStateEntries;
  LBack: RawByteString;
begin
  if Skipped then
    Exit;
  FStore.Save(TRadStateKey.Make(StringToUtf8(SCOPE_TR), 'TFaturaForm'), 'a');
  // 'Ω' is outside code page 1254: an ANSI parameter would turn it into '?' on this machine too.
  FStore.Save(TRadStateKey.Make(StringToUtf8(SCOPE_TR), StringToUtf8('TCariForm.İkinci Ω')), 'b');
  FStore.Save(TRadStateKey.Make('başka', 'TFaturaForm'), 'c');
  LEntries := FStore.LoadScope(StringToUtf8(SCOPE_TR));
  Assert.AreEqual(2, Integer(Length(LEntries)));
  // A lossy parameter breaks save and load the same way, so only the stored name can show it.
  Assert.IsTrue((Utf8ToString(LEntries[0].Key.Name) = 'TCariForm.İkinci Ω') or
    (Utf8ToString(LEntries[1].Key.Name) = 'TCariForm.İkinci Ω'),
    'stored name: ' + Utf8ToString(LEntries[0].Key.Name) + ' / ' + Utf8ToString(LEntries[1].Key.Name));
  Assert.IsTrue(FStore.Load(TRadStateKey.Make(StringToUtf8(SCOPE_TR), StringToUtf8('TCariForm.İkinci Ω')), LBack),
    'non-ANSI key round trip');
  Assert.IsTrue(LBack = 'b');
end;

procedure TRadFormStateDbTests.Repository_EncryptedRoundTrip;
var
  LKeyBytes: THash256;
  LCipher: IRadCipher;
  LRepo: TRadStateRepository;
  LDoc: IDocDict;
  LKey: TRadStateKey;
begin
  if Skipped then
    Exit;
  FillChar(LKeyBytes, SizeOf(LKeyBytes), $3C);
  LCipher := TRadAesGcmCipher.Create(LKeyBytes);
  LKey := TRadStateKey.Make('emrah', 'TLoginForm');
  LRepo := TRadStateRepository.Create(FStore, LCipher);
  try
    LDoc := TRadStateDoc.New(LKey, 'TLoginForm', 1, RAD_STATE_DEFAULT_PPI);
    LDoc.U['note'] := 'Çığ';
    Assert.IsTrue(LRepo.Save(LKey, LDoc));
  finally
    LRepo.Free;
  end;
  LRepo := TRadStateRepository.Create(FStore, LCipher);
  try
    Assert.IsTrue(LRepo.Load(LKey, LDoc), LRepo.LastError);
    Assert.AreEqual('Çığ', LDoc.S['note']);
  finally
    LRepo.Free;
  end;
end;

procedure TRadFormStateDbTests.Measure_SaveAndLoad;
const
  ROUNDS = 50;
var
  LKey: TRadStateKey;
  LData, LBack: RawByteString;
  LWatch: TStopwatch;
  I: Integer;
  LSave, LLoad: Double;
begin
  if Skipped then
    Exit;
  LKey := TRadStateKey.Make('emrah', 'TMeasure');
  LData := Copy(Payload(7), 1, 6000); // about one encrypted 300-path form
  FStore.Save(LKey, LData);
  LWatch := TStopwatch.StartNew;
  for I := 1 to ROUNDS do
    FStore.Save(LKey, LData);
  LSave := LWatch.Elapsed.TotalMilliseconds / ROUNDS;
  LWatch := TStopwatch.StartNew;
  for I := 1 to ROUNDS do
    FStore.Load(LKey, LBack);
  LLoad := LWatch.Elapsed.TotalMilliseconds / ROUNDS;
  System.Writeln(Format('  MEASURE %s 6 KB: save %.2f ms, load %.2f ms', [ClassName, LSave, LLoad]));
  Assert.IsTrue(LBack = LData);
end;

{ connections }

procedure TPostgreSqlStateTests.Connect(AConnection: TUniConnection);
begin
  AConnection.ProviderName := 'PostgreSQL';
  AConnection.Server := Env('RAD_PG_HOST', '127.0.0.1');
  AConnection.Port := StrToIntDef(Env('RAD_PG_PORT', '5432'), 5432);
  AConnection.Database := Env('RAD_PG_DB', 'testdb');
  AConnection.Username := Env('RAD_PG_USER', 'postgres');
  AConnection.Password := Env('RAD_PG_PASS');
  // Without it PostgreSQL stores 'İkinci Ω' as '?kinci ?' (LoadScope test, measured).
  AConnection.SpecificOptions.Values['UseUnicode'] := 'True';
  AConnection.Connect;
end;

procedure TSqlServerStateTests.Connect(AConnection: TUniConnection);
begin
  AConnection.ProviderName := 'SQL Server';
  AConnection.Server := Env('RAD_MS_SERVER', 'localhost');
  AConnection.Database := Env('RAD_MS_DB', 'rad_filter_test');
  AConnection.SpecificOptions.Values['Authentication'] := 'auWindows';
  AConnection.SpecificOptions.Values['Provider'] := 'prDirect';
  AConnection.Connect;
end;

procedure TFirebirdStateTests.Connect(AConnection: TUniConnection);
var
  LClient: string;
begin
  {$IFDEF WIN64}
  LClient := Env('RAD_FB_CLIENT64');
  {$ELSE}
  LClient := Env('RAD_FB_CLIENT', 'C:\Program Files (x86)\Firebird\Firebird_5_0\fbclient.dll');
  {$ENDIF}
  if (Env('RAD_FB_DB') = '') or (LClient = '') then
    raise EDatabaseError.Create('no Firebird client or database for this platform');
  AConnection.ProviderName := 'InterBase';
  AConnection.Server := Env('RAD_FB_HOST', 'localhost');
  AConnection.Database := Env('RAD_FB_DB');
  AConnection.Username := Env('RAD_FB_USER', 'SYSDBA');
  AConnection.Password := Env('RAD_FB_PASS');
  AConnection.SpecificOptions.Values['ClientLibrary'] := LClient;
  AConnection.SpecificOptions.Values['Charset'] := 'UTF8';
  AConnection.SpecificOptions.Values['UseUnicode'] := 'True';
  AConnection.Connect;
end;

{ TUniStateStoreOfflineTests }

procedure TUniStateStoreOfflineTests.CreateTableSql_UnknownProvider_Raises;
begin
  Assert.WillRaise(
    procedure
    begin
      TRadUniStateStore.CreateTableSql('Oracle');
    end, ERadFormState);
end;

procedure TUniStateStoreOfflineTests.TableName_NotAnIdentifier_Raises;
begin
  Assert.WillRaise(
    procedure
    begin
      TRadUniStateStore.CreateTableSql('PostgreSQL', 'x; drop table y');
    end, ERadFormState);
  Assert.WillNotRaise(
    procedure
    begin
      TRadUniStateStore.CreateTableSql('PostgreSQL', 'app.rad_form_state');
    end);
end;

initialization
  TDUnitX.RegisterTestFixture(TPostgreSqlStateTests);
  TDUnitX.RegisterTestFixture(TSqlServerStateTests);
  TDUnitX.RegisterTestFixture(TFirebirdStateTests);
  TDUnitX.RegisterTestFixture(TUniStateStoreOfflineTests);

finalization
  GEnv.Free;

end.
