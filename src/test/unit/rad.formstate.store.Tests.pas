unit rad.formstate.store.Tests;

{ DUnitX tests of rad.formstate.store: file and callback stores, envelope, repository.
  File tests run in a fresh temporary folder that TearDown removes. }

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DUnitX.TestFramework,
  mormot.core.base,
  mormot.core.variants,
  rad.cipher,
  rad.formstate.core,
  rad.formstate.store;

type
  /// <summary>In-memory store that counts calls.</summary>
  TFakeStore = class(TInterfacedObject, IRadStateStore)
  private
    FData: TDictionary<RawUtf8, RawByteString>;
  public
    LoadCalls: Integer;
    SaveCalls: Integer;
    constructor Create;
    destructor Destroy; override;
    procedure Put(const AKey: TRadStateKey; const AData: RawByteString);
    function Get(const AKey: TRadStateKey): RawByteString;
    function Load(const AKey: TRadStateKey; out AData: RawByteString): Boolean;
    procedure Save(const AKey: TRadStateKey; const AData: RawByteString);
    procedure Delete(const AKey: TRadStateKey);
    function LoadScope(const AScope: RawUtf8): TRadStateEntries;
  end;

  [TestFixture]
  TRadFormStateStoreTests = class
  private
    FRoot: string;
    FCipher: IRadCipher;
    FKey: TRadStateKey;
    function NewDoc(AWidth: Integer): IDocDict;
    function FlipByte(const AData: RawByteString; AIndex: Integer): RawByteString;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure File_SaveThenLoad_ReturnsSameBytes;
    [Test]
    procedure File_LoadMissing_ReturnsFalse;
    [Test]
    procedure File_SaveTwice_OverwritesAndLeavesNoTempFile;
    [Test]
    procedure File_HostileKey_StaysUnderRoot;
    [Test]
    procedure File_SafeSegment_HandlesWindowsNames;
    [Test]
    procedure File_LoadScope_ReturnsOnlyThatScope;
    [Test]
    procedure File_Delete_RemovesFile;
    [Test]
    procedure Callback_Calls_RouteToClassFunctions;
    [Test]
    procedure Callback_SaveWithoutFunction_Raises;
    [Test]
    procedure Envelope_Plain_RoundTrips;
    [Test]
    procedure Envelope_Encrypted_RoundTripsAndHidesText;
    [Test]
    procedure Envelope_AnyTamperedByte_FailsDecode;
    [Test]
    procedure Envelope_EncryptedWithoutCipher_FailsDecode;
    [Test]
    procedure Envelope_OtherAlgorithm_FailsDecode;
    [Test]
    procedure Envelope_PlainStillReadsWithCipher;
    [Test]
    procedure Envelope_Garbage_FailsDecode;
    [Test]
    procedure Repo_SaveUnchanged_SkipsWrite;
    [Test]
    procedure Repo_LoadThenSaveUnchanged_SkipsWrite;
    [Test]
    procedure Repo_Save_StampsSavedAt;
    [Test]
    procedure Repo_TamperedRecord_LoadFailsWithReason;
    [Test]
    procedure Repo_NewerSchema_LoadFails;
    [Test]
    procedure Repo_InvalidJson_LoadFails;
    [Test]
    procedure Repo_Prefetch_AvoidsStoreLoads;
    [Test]
    procedure Repo_LoadedDoc_OutlivesTheCall;
    [Test]
    procedure Repo_FileStoreEncrypted_EndToEnd;
  end;

implementation

uses
  System.IOUtils,
  mormot.core.os,
  mormot.core.text,
  mormot.core.unicode;

const
  SCOPE = 'emrah';
  FORM_CLASS = 'TLoginForm';
  KEY_BYTE = $5A;

function TestCipher(ABits: Integer = 256): IRadCipher;
var
  LKey: THash256;
begin
  FillChar(LKey, SizeOf(LKey), KEY_BYTE);
  Result := TRadAesGcmCipher.Create(LKey, ABits);
end;

{ TFakeStore }

constructor TFakeStore.Create;
begin
  inherited Create;
  FData := TDictionary<RawUtf8, RawByteString>.Create;
end;

destructor TFakeStore.Destroy;
begin
  FData.Free;
  inherited;
end;

procedure TFakeStore.Put(const AKey: TRadStateKey; const AData: RawByteString);
begin
  FData.AddOrSetValue(AKey.Path, AData);
end;

function TFakeStore.Get(const AKey: TRadStateKey): RawByteString;
begin
  if not FData.TryGetValue(AKey.Path, Result) then
    Result := '';
end;

function TFakeStore.Load(const AKey: TRadStateKey; out AData: RawByteString): Boolean;
begin
  Inc(LoadCalls);
  Result := FData.TryGetValue(AKey.Path, AData);
end;

procedure TFakeStore.Save(const AKey: TRadStateKey; const AData: RawByteString);
begin
  Inc(SaveCalls);
  Put(AKey, AData);
end;

procedure TFakeStore.Delete(const AKey: TRadStateKey);
begin
  FData.Remove(AKey.Path);
end;

function TFakeStore.LoadScope(const AScope: RawUtf8): TRadStateEntries;
var
  LPair: TPair<RawUtf8, RawByteString>;
  LCount: Integer;
begin
  Result := nil;
  for LPair in FData do
    if Copy(LPair.Key, 1, Length(AScope) + 1) = AScope + RAD_STATE_KEY_SEPARATOR then
    begin
      LCount := Length(Result);
      SetLength(Result, LCount + 1);
      Result[LCount].Key := TRadStateKey.Make(AScope, Copy(LPair.Key, Length(AScope) + 2, MaxInt));
      Result[LCount].Data := LPair.Value;
    end;
end;

{ TRadFormStateStoreTests }

procedure TRadFormStateStoreTests.Setup;
begin
  FRoot := TPath.Combine(TPath.GetTempPath, 'radfs_' + TGuid.NewGuid.ToString);
  FCipher := TestCipher;
  FKey := TRadStateKey.Make(SCOPE, FORM_CLASS);
end;

procedure TRadFormStateStoreTests.TearDown;
begin
  TRadCallbackStateStore.Reset;
  FCipher := nil;
  if TDirectory.Exists(FRoot) then
    TDirectory.Delete(FRoot, True);
end;

function TRadFormStateStoreTests.NewDoc(AWidth: Integer): IDocDict;
begin
  Result := TRadStateDoc.New(FKey, FORM_CLASS, 1, RAD_STATE_DEFAULT_PPI);
  Result.D[RAD_STATE_SECTION_PROPS] := DocDict(FormatUtf8('{"Edit1":{"Width":%}}', [AWidth]), mFastFloat);
  Result.U['note'] := 'Çığ';
end;

function TRadFormStateStoreTests.FlipByte(const AData: RawByteString; AIndex: Integer): RawByteString;
begin
  SetString(Result, PAnsiChar(AData), Length(AData)); // own copy before writing into it
  Result[AIndex] := AnsiChar(Ord(Result[AIndex]) xor $01);
end;

procedure TRadFormStateStoreTests.File_SaveThenLoad_ReturnsSameBytes;
var
  LStore: IRadStateStore;
  LData, LBack: RawByteString;
begin
  LStore := TRadFileStateStore.Create(FRoot);
  LData := RawByteString('a') + AnsiChar(0) + AnsiChar(255) + RawByteString('{x}');
  LStore.Save(FKey, LData);
  Assert.IsTrue(LStore.Load(FKey, LBack));
  Assert.IsTrue(LBack = LData);
end;

procedure TRadFormStateStoreTests.File_LoadMissing_ReturnsFalse;
var
  LStore: IRadStateStore;
  LBack: RawByteString;
begin
  LStore := TRadFileStateStore.Create(FRoot);
  Assert.IsFalse(LStore.Load(FKey, LBack));
  Assert.IsTrue(LBack = '');
end;

procedure TRadFormStateStoreTests.File_SaveTwice_OverwritesAndLeavesNoTempFile;
var
  LStore: TRadFileStateStore;
  LIntf: IRadStateStore;
  LBack: RawByteString;
begin
  LStore := TRadFileStateStore.Create(FRoot);
  LIntf := LStore;
  LIntf.Save(FKey, 'first');
  LIntf.Save(FKey, 'second');
  Assert.IsTrue(LIntf.Load(FKey, LBack));
  Assert.IsTrue(LBack = 'second');
  Assert.AreEqual(0, Integer(Length(TDirectory.GetFiles(FRoot, '*.tmp', TSearchOption.soAllDirectories))));
end;

procedure TRadFormStateStoreTests.File_HostileKey_StaysUnderRoot;
const
  HOSTILE: array[0..3, 0..1] of RawUtf8 = (('..\..\x', '..'), ('a/b:c', 'CON'),
    ('', 'x\..\..\y'), ('..', '..\..\Windows\win'));
var
  LStore: TRadFileStateStore;
  LIntf: IRadStateStore;
  LKey: TRadStateKey;
  I: Integer;
  LFile: string;
begin
  LStore := TRadFileStateStore.Create(FRoot);
  LIntf := LStore;
  for I := Low(HOSTILE) to High(HOSTILE) do
  begin
    LKey := TRadStateKey.Make(HOSTILE[I, 0], HOSTILE[I, 1]);
    LIntf.Save(LKey, 'x');
    LFile := LStore.FileNameOf(LKey);
    Assert.IsTrue(LFile.StartsWith(IncludeTrailingPathDelimiter(LStore.Root), True), LFile);
    Assert.IsTrue(FileExists(LFile), LFile);
  end;
end;

procedure TRadFormStateStoreTests.File_SafeSegment_HandlesWindowsNames;
begin
  Assert.AreEqual('_', TRadFileStateStore.SafeSegment('..'));
  Assert.AreEqual('_', TRadFileStateStore.SafeSegment(''));
  Assert.AreEqual('_CON', TRadFileStateStore.SafeSegment('CON'));
  Assert.AreEqual('_con.txt', TRadFileStateStore.SafeSegment('con.txt'));
  Assert.AreEqual('_LPT9', TRadFileStateStore.SafeSegment('LPT9'));
  Assert.AreEqual('a_b_c', TRadFileStateStore.SafeSegment('a:b/c'));
  Assert.AreEqual('x', TRadFileStateStore.SafeSegment('x. .'));
  Assert.AreEqual(FORM_CLASS, TRadFileStateStore.SafeSegment(FORM_CLASS));
  Assert.AreEqual('Çığ', TRadFileStateStore.SafeSegment('Çığ'));
  Assert.AreEqual('CONSOLE', TRadFileStateStore.SafeSegment('CONSOLE'));
end;

procedure TRadFormStateStoreTests.File_LoadScope_ReturnsOnlyThatScope;
var
  LStore: IRadStateStore;
  LEntries: TRadStateEntries;
begin
  LStore := TRadFileStateStore.Create(FRoot);
  LStore.Save(TRadStateKey.Make(SCOPE, 'TA'), 'a');
  LStore.Save(TRadStateKey.Make(SCOPE, 'TB'), 'b');
  LStore.Save(TRadStateKey.Make('other', 'TC'), 'c');
  LEntries := LStore.LoadScope(SCOPE);
  Assert.AreEqual(2, Integer(Length(LEntries)));
  Assert.AreEqual(0, Integer(Length(LStore.LoadScope('nobody'))));
end;

procedure TRadFormStateStoreTests.File_Delete_RemovesFile;
var
  LStore: TRadFileStateStore;
  LIntf: IRadStateStore;
begin
  LStore := TRadFileStateStore.Create(FRoot);
  LIntf := LStore;
  LIntf.Save(FKey, 'x');
  LIntf.Delete(FKey);
  Assert.IsFalse(FileExists(LStore.FileNameOf(FKey)));
  LIntf.Delete(FKey); // deleting a missing record is not an error
end;

procedure TRadFormStateStoreTests.Callback_Calls_RouteToClassFunctions;
var
  LStore: IRadStateStore;
  LSaved: RawByteString;
  LBack: RawByteString;
begin
  TRadCallbackStateStore.DoSave :=
    procedure(const AKey: TRadStateKey; const AData: RawByteString)
    begin
      LSaved := AKey.Path + '=' + AData;
    end;
  TRadCallbackStateStore.DoLoad :=
    function(const AKey: TRadStateKey; out AData: RawByteString): Boolean
    begin
      AData := 'loaded';
      Result := True;
    end;
  LStore := TRadCallbackStateStore.Create;
  LStore.Save(FKey, 'v');
  Assert.IsTrue(LSaved = 'emrah\TLoginForm=v');
  Assert.IsTrue(LStore.Load(FKey, LBack));
  Assert.IsTrue(LBack = 'loaded');
  Assert.AreEqual(0, Integer(Length(LStore.LoadScope(SCOPE))));
end;

procedure TRadFormStateStoreTests.Callback_SaveWithoutFunction_Raises;
var
  LStore: IRadStateStore;
  LBack: RawByteString;
begin
  LStore := TRadCallbackStateStore.Create;
  Assert.IsFalse(LStore.Load(FKey, LBack));
  Assert.WillRaise(
    procedure
    begin
      LStore.Save(FKey, 'v');
    end, ERadFormState);
end;

procedure TRadFormStateStoreTests.Envelope_Plain_RoundTrips;
var
  LJson: RawUtf8;
begin
  Assert.IsTrue(TRadStateEnvelope.Decode(TRadStateEnvelope.Encode('{"a":1}', nil), nil, LJson));
  Assert.IsTrue(LJson = '{"a":1}');
end;

procedure TRadFormStateStoreTests.Envelope_Encrypted_RoundTripsAndHidesText;
var
  LData: RawByteString;
  LJson: RawUtf8;
begin
  LData := TRadStateEnvelope.Encode('{"secret":"Çığ"}', FCipher);
  Assert.IsTrue(TRadStateEnvelope.IsEncrypted(LData));
  Assert.AreEqual(0, System.Pos(RawByteString('secret'), LData));
  Assert.IsTrue(TRadStateEnvelope.Decode(LData, FCipher, LJson));
  Assert.IsTrue(LJson = StringToUtf8('{"secret":"Çığ"}'));
end;

procedure TRadFormStateStoreTests.Envelope_AnyTamperedByte_FailsDecode;
const
  // GCM rebuilds the last 4 bytes of the 16-byte IV itself (verified-api-traps.md),
  // so flipping them still decrypts correctly; every other byte must be rejected.
  IV_DEAD_TAIL = 4;
var
  LData: RawByteString;
  LJson: RawUtf8;
  LHeader, I, LRejected, LSurvivedWrong: Integer;
begin
  LData := TRadStateEnvelope.Encode('{"a":1,"b":"payload"}', FCipher);
  LHeader := 6 + Length(FCipher.AlgorithmId);
  LRejected := 0;
  LSurvivedWrong := 0;
  for I := 1 to Length(LData) do
    if not TRadStateEnvelope.Decode(FlipByte(LData, I), FCipher, LJson) then
      Inc(LRejected)
    else if LJson <> '{"a":1,"b":"payload"}' then
      Inc(LSurvivedWrong);
  Assert.AreEqual(0, LSurvivedWrong, 'a flipped byte produced different plaintext');
  Assert.AreEqual(Length(LData) - IV_DEAD_TAIL, LRejected, Format('header %d', [LHeader]));
end;

procedure TRadFormStateStoreTests.Envelope_EncryptedWithoutCipher_FailsDecode;
var
  LJson: RawUtf8;
begin
  Assert.IsFalse(TRadStateEnvelope.Decode(TRadStateEnvelope.Encode('{"a":1}', FCipher), nil, LJson));
end;

procedure TRadFormStateStoreTests.Envelope_OtherAlgorithm_FailsDecode;
var
  LJson: RawUtf8;
begin
  Assert.IsFalse(TRadStateEnvelope.Decode(TRadStateEnvelope.Encode('{"a":1}', FCipher), TestCipher(128), LJson));
end;

procedure TRadFormStateStoreTests.Envelope_PlainStillReadsWithCipher;
var
  LJson: RawUtf8;
begin
  Assert.IsTrue(TRadStateEnvelope.Decode('{"a":1}', FCipher, LJson));
end;

procedure TRadFormStateStoreTests.Envelope_Garbage_FailsDecode;
var
  LJson: RawUtf8;
begin
  Assert.IsFalse(TRadStateEnvelope.Decode('', FCipher, LJson));
  Assert.IsFalse(TRadStateEnvelope.Decode('hello', FCipher, LJson));
  Assert.IsFalse(TRadStateEnvelope.Decode('RADS', FCipher, LJson));
  Assert.IsFalse(TRadStateEnvelope.Decode('RADS'#2#3'abcXXXXXXXX', FCipher, LJson));
end;

procedure TRadFormStateStoreTests.Repo_SaveUnchanged_SkipsWrite;
var
  LFake: TFakeStore;
  LRepo: TRadStateRepository;
begin
  LFake := TFakeStore.Create;
  LRepo := TRadStateRepository.Create(LFake);
  try
    Assert.IsTrue(LRepo.Save(FKey, NewDoc(5)));
    Assert.IsFalse(LRepo.Save(FKey, NewDoc(5)), 'same content');
    Assert.AreEqual(1, LFake.SaveCalls);
    Assert.IsTrue(LRepo.Save(FKey, NewDoc(6)));
    Assert.AreEqual(2, LFake.SaveCalls);
  finally
    LRepo.Free;
  end;
end;

procedure TRadFormStateStoreTests.Repo_LoadThenSaveUnchanged_SkipsWrite;
var
  LFake: TFakeStore;
  LRepo: TRadStateRepository;
  LDoc: IDocDict;
begin
  LFake := TFakeStore.Create;
  LFake.Put(FKey, NewDoc(7).Json);
  LRepo := TRadStateRepository.Create(LFake);
  try
    Assert.IsTrue(LRepo.Load(FKey, LDoc), LRepo.LastError);
    Assert.IsFalse(LRepo.Save(FKey, NewDoc(7)));
    Assert.AreEqual(0, LFake.SaveCalls);
  finally
    LRepo.Free;
  end;
end;

procedure TRadFormStateStoreTests.Repo_Save_StampsSavedAt;
var
  LFake: TFakeStore;
  LRepo: TRadStateRepository;
  LSaved: IDocDict;
begin
  LFake := TFakeStore.Create;
  LRepo := TRadStateRepository.Create(LFake);
  try
    LRepo.Save(FKey, NewDoc(1));
    LSaved := DocDict(RawUtf8(LFake.Get(FKey)), mFastFloat);
    Assert.IsTrue(Length(LSaved.U[RAD_STATE_FIELD_SAVED_AT]) = Length('2026-11-03T10:00:00Z'),
      Utf8ToString(LSaved.U[RAD_STATE_FIELD_SAVED_AT]));
  finally
    LRepo.Free;
  end;
end;

procedure TRadFormStateStoreTests.Repo_TamperedRecord_LoadFailsWithReason;
var
  LFake: TFakeStore;
  LKeepAlive: IRadStateStore;
  LRepo: TRadStateRepository;
  LDoc: IDocDict;
  LData: RawByteString;
begin
  LFake := TFakeStore.Create;
  LKeepAlive := LFake; // the store outlives the first repository
  LRepo := TRadStateRepository.Create(LFake, FCipher);
  try
    LRepo.Save(FKey, NewDoc(1));
  finally
    LRepo.Free;
  end;
  LData := LFake.Get(FKey);
  LFake.Put(FKey, FlipByte(LData, Length(LData) - 20));
  LRepo := TRadStateRepository.Create(LFake, FCipher);
  try
    Assert.IsFalse(LRepo.Load(FKey, LDoc));
    Assert.IsTrue(LDoc = nil, 'no document on failure');
    Assert.IsTrue(LRepo.LastError <> '');
  finally
    LRepo.Free;
  end;
end;

procedure TRadFormStateStoreTests.Repo_NewerSchema_LoadFails;
var
  LFake: TFakeStore;
  LRepo: TRadStateRepository;
  LDoc: IDocDict;
begin
  LFake := TFakeStore.Create;
  LFake.Put(FKey, '{"schema":99}');
  LRepo := TRadStateRepository.Create(LFake);
  try
    Assert.IsFalse(LRepo.Load(FKey, LDoc));
  finally
    LRepo.Free;
  end;
end;

procedure TRadFormStateStoreTests.Repo_InvalidJson_LoadFails;
var
  LFake: TFakeStore;
  LRepo: TRadStateRepository;
  LDoc: IDocDict;
begin
  LFake := TFakeStore.Create;
  LFake.Put(FKey, '{"schema":1,broken');
  LRepo := TRadStateRepository.Create(LFake);
  try
    Assert.IsFalse(LRepo.Load(FKey, LDoc));
  finally
    LRepo.Free;
  end;
end;

procedure TRadFormStateStoreTests.Repo_Prefetch_AvoidsStoreLoads;
var
  LFake: TFakeStore;
  LRepo: TRadStateRepository;
  LDoc: IDocDict;
begin
  LFake := TFakeStore.Create;
  LFake.Put(TRadStateKey.Make(SCOPE, 'TA'), NewDoc(1).Json);
  LFake.Put(TRadStateKey.Make(SCOPE, 'TB'), NewDoc(2).Json);
  LRepo := TRadStateRepository.Create(LFake);
  try
    LRepo.Prefetch(SCOPE);
    Assert.IsTrue(LRepo.Load(TRadStateKey.Make(SCOPE, 'TA'), LDoc), LRepo.LastError);
    Assert.IsTrue(LRepo.Load(TRadStateKey.Make(SCOPE, 'TB'), LDoc), LRepo.LastError);
    Assert.IsFalse(LRepo.Load(TRadStateKey.Make(SCOPE, 'TMissing'), LDoc));
    Assert.AreEqual(0, LFake.LoadCalls);
    Assert.IsFalse(LRepo.Load(TRadStateKey.Make('other', 'TA'), LDoc));
    Assert.AreEqual(1, LFake.LoadCalls, 'a scope that was not prefetched still asks the store');
  finally
    LRepo.Free;
  end;
end;

procedure TRadFormStateStoreTests.Repo_LoadedDoc_OutlivesTheCall;
var
  LFake: TFakeStore;
  LRepo: TRadStateRepository;
  LDoc, LProps: IDocDict;
  LNoise: TArray<string>;
  I: Integer;
begin
  LFake := TFakeStore.Create;
  LFake.Put(FKey, NewDoc(42).Json);
  LRepo := TRadStateRepository.Create(LFake);
  try
    Assert.IsTrue(LRepo.Load(FKey, LDoc), LRepo.LastError);
  finally
    LRepo.Free;
  end;
  SetLength(LNoise, 1000); // reuse freed memory before reading the document
  for I := 0 to High(LNoise) do
    LNoise[I] := StringOfChar('#', 64);
  Assert.IsTrue(TRadStateDoc.Section(LDoc, RAD_STATE_SECTION_PROPS, LProps));
  Assert.AreEqual(42, Integer(LProps.D['Edit1'].I['Width']));
  Assert.AreEqual('Çığ', LDoc.S['note']);
end;

procedure TRadFormStateStoreTests.Repo_FileStoreEncrypted_EndToEnd;
var
  LStore: TRadFileStateStore;
  LIntf: IRadStateStore;
  LRepo: TRadStateRepository;
  LDoc, LProps: IDocDict;
begin
  LStore := TRadFileStateStore.Create(FRoot);
  LIntf := LStore;
  LRepo := TRadStateRepository.Create(LIntf, FCipher);
  try
    Assert.IsTrue(LRepo.Save(FKey, NewDoc(9)));
  finally
    LRepo.Free;
  end;
  Assert.AreEqual(0, System.Pos(RawByteString('Edit1'), StringFromFile(LStore.FileNameOf(FKey))));
  LRepo := TRadStateRepository.Create(LIntf, FCipher);
  try
    Assert.IsTrue(LRepo.Load(FKey, LDoc), LRepo.LastError);
    Assert.IsTrue(TRadStateDoc.Section(LDoc, RAD_STATE_SECTION_PROPS, LProps));
    Assert.AreEqual(9, Integer(LProps.D['Edit1'].I['Width']));
  finally
    LRepo.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadFormStateStoreTests);

end.
