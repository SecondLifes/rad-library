unit rad.formstate.store;

{ Stores, encryption envelope and the cached repository of the form-state system
  (docs/specs/rad.formstate.md). RTL + mORMot + rad.cipher; no VCL, no threads. }

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  mormot.core.base,
  mormot.core.variants,
  rad.core,
  rad.cipher,
  rad.formstate.core;

type
  ERadFormState = class(ERadCore);

  TRadStateEntry = record
    Key: TRadStateKey;
    Data: RawByteString;
  end;

  TRadStateEntries = array of TRadStateEntry;

  /// <summary>Where saved states live. Stores move bytes only; encoding is the repository's job.</summary>
  IRadStateStore = interface
    ['{F4348895-7C8D-43E5-BED6-79B1ED9B0F9D}']
    function Load(const AKey: TRadStateKey; out AData: RawByteString): Boolean;
    procedure Save(const AKey: TRadStateKey; const AData: RawByteString);
    procedure Delete(const AKey: TRadStateKey);
    /// <summary>Every record of one scope, for Prefetch.</summary>
    function LoadScope(const AScope: RawUtf8): TRadStateEntries;
  end;

  /// <summary>One file per record: Root\Scope\Name.state, written through a temporary file.</summary>
  TRadFileStateStore = class(TInterfacedObject, IRadStateStore)
  private
    FRoot: TFileName;
    function ScopeFolder(const AScope: RawUtf8): TFileName;
  public
    /// <summary>An empty root means DefaultRoot.</summary>
    constructor Create(const ARoot: TFileName = '');
    /// <summary>%LOCALAPPDATA%\exe name\state, or a state folder beside the exe.</summary>
    class function DefaultRoot: TFileName; static;
    /// <summary>One path segment safe as a Windows file name; never empty, never '..'.</summary>
    class function SafeSegment(const ASegment: RawUtf8): TFileName; static;
    /// <summary>The file of AKey; raises ERadFormState if it would fall outside Root.</summary>
    function FileNameOf(const AKey: TRadStateKey): TFileName;
    function Load(const AKey: TRadStateKey; out AData: RawByteString): Boolean;
    procedure Save(const AKey: TRadStateKey; const AData: RawByteString);
    procedure Delete(const AKey: TRadStateKey);
    function LoadScope(const AScope: RawUtf8): TRadStateEntries;
    property Root: TFileName read FRoot;
  end;

  TRadStateLoadFunc = reference to function(const AKey: TRadStateKey; out AData: RawByteString): Boolean;
  TRadStateSaveProc = reference to procedure(const AKey: TRadStateKey; const AData: RawByteString);
  TRadStateDeleteProc = reference to procedure(const AKey: TRadStateKey);
  TRadStateScopeFunc = reference to function(const AScope: RawUtf8): TRadStateEntries;

  /// <summary>Routes every call to host functions assigned once to the class vars.</summary>
  TRadCallbackStateStore = class(TInterfacedObject, IRadStateStore)
  public
    class var DoLoad: TRadStateLoadFunc;
    class var DoSave: TRadStateSaveProc;
    class var DoDelete: TRadStateDeleteProc;
    class var DoLoadScope: TRadStateScopeFunc;
    /// <summary>Clears the four functions.</summary>
    class procedure Reset; static;
    function Load(const AKey: TRadStateKey; out AData: RawByteString): Boolean;
    /// <summary>Raises ERadFormState when DoSave is not assigned: a lost save must not look like success.</summary>
    procedure Save(const AKey: TRadStateKey; const AData: RawByteString);
    procedure Delete(const AKey: TRadStateKey);
    function LoadScope(const AScope: RawUtf8): TRadStateEntries;
  end;

  /// <summary>Plain JSON, or 'RADS' + version + algorithm label + cipher output.</summary>
  TRadStateEnvelope = class abstract
  public
    class function Encode(const AJson: RawUtf8; const ACipher: IRadCipher): RawByteString; static;
    /// <summary>False for unknown bytes, a missing or different cipher, or tampered data.</summary>
    class function Decode(const AData: RawByteString; const ACipher: IRadCipher;
      out AJson: RawUtf8): Boolean; static;
    class function IsEncrypted(const AData: RawByteString): Boolean; static;
  end;

  /// <summary>Store + envelope + cache. Skips a save whose content did not change.</summary>
  TRadStateRepository = class
  private
    FStore: IRadStateStore;
    FCipher: IRadCipher;
    FCache: TDictionary<RawUtf8, RawByteString>;
    FHashes: TDictionary<RawUtf8, Cardinal>;
    FPrefetched: TDictionary<RawUtf8, Boolean>;
    FLastError: string;
    function ReadPayload(const AKey: TRadStateKey; out AData: RawByteString): Boolean;
    function ParseDoc(const AKey: TRadStateKey; const AData: RawByteString; out ADoc: IDocDict): Boolean;
    function Fail(const AKey: TRadStateKey; const AReason: string): Boolean;
  public
    constructor Create(const AStore: IRadStateStore; const ACipher: IRadCipher = nil);
    destructor Destroy; override;
    /// <summary>False when there is no record or it cannot be read (LastError says why).</summary>
    function Load(const AKey: TRadStateKey; out ADoc: IDocDict): Boolean;
    /// <summary>Stamps savedAt and writes; False when the content matches the last load or save.</summary>
    function Save(const AKey: TRadStateKey; const ADoc: IDocDict): Boolean;
    procedure Delete(const AKey: TRadStateKey);
    /// <summary>Reads a whole scope in one store call; later loads of that scope never hit the store.</summary>
    procedure Prefetch(const AScope: RawUtf8);
    property Store: IRadStateStore read FStore;
    property LastError: string read FLastError;
  end;

implementation

uses
  Winapi.Windows,
  System.IOUtils,
  mormot.core.os,
  mormot.core.rtti, // lets TSynLog.Add inline (H2443)
  mormot.core.unicode,
  mormot.core.text,
  mormot.core.datetime,
  mormot.core.log;

const
  STATE_EXT = '.state';
  TEMP_EXT = '.tmp';
  STATE_FOLDER = 'state';
  INVALID_FILE_CHARS = ['<', '>', ':', '"', '/', '\', '|', '?', '*'];
  RESERVED_NAMES: array[0..21] of string = ('CON', 'PRN', 'AUX', 'NUL',
    'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
    'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9');
  ENVELOPE_MAGIC: RawByteString = 'RADS';
  ENVELOPE_VERSION = #1;
  ENVELOPE_HEADER = 6; // magic + version + label length

{ file names }

function ReplaceInvalidChars(const AText: string): string;
var
  I: Integer;
begin
  Result := AText;
  for I := 1 to Length(Result) do
    if (Result[I] < ' ') or CharInSet(Result[I], INVALID_FILE_CHARS) then
      Result[I] := '_';
end;

function TrimTrailingDots(const AText: string): string;
begin
  Result := AText;
  while (Result <> '') and CharInSet(Result[Length(Result)], ['.', ' ']) do
    SetLength(Result, Length(Result) - 1);
end;

function IsReservedName(const AText: string): Boolean;
var
  LBase: string;
  I: Integer;
begin
  // Qualified: mormot.core.base shadows Pos and UpperCase with RawUtf8 overloads (W1057).
  LBase := System.SysUtils.UpperCase(Copy(AText, 1, System.Pos('.', AText + '.') - 1));
  for I := Low(RESERVED_NAMES) to High(RESERVED_NAMES) do
    if LBase = RESERVED_NAMES[I] then
      Exit(True);
  Result := False;
end;

{ TRadFileStateStore }

constructor TRadFileStateStore.Create(const ARoot: TFileName);
begin
  inherited Create;
  if ARoot = '' then
    FRoot := DefaultRoot
  else
    FRoot := ExcludeTrailingPathDelimiter(ExpandFileName(ARoot));
end;

class function TRadFileStateStore.DefaultRoot: TFileName;
var
  LBase: TFileName;
begin
  LBase := GetEnvironmentVariable('LOCALAPPDATA');
  if LBase = '' then
    Exit(ExtractFilePath(ParamStr(0)) + STATE_FOLDER);
  Result := TPath.Combine(TPath.Combine(LBase, ChangeFileExt(ExtractFileName(ParamStr(0)), '')),
    STATE_FOLDER);
end;

class function TRadFileStateStore.SafeSegment(const ASegment: RawUtf8): TFileName;
begin
  Result := TrimTrailingDots(ReplaceInvalidChars(Utf8ToString(ASegment)));
  if Result = '' then
    Result := '_'
  else if IsReservedName(Result) then
    Result := '_' + Result;
end;

function TRadFileStateStore.ScopeFolder(const AScope: RawUtf8): TFileName;
begin
  if AScope = '' then
    Result := FRoot
  else
    Result := TPath.Combine(FRoot, SafeSegment(AScope));
end;

function TRadFileStateStore.FileNameOf(const AKey: TRadStateKey): TFileName;
begin
  Result := ExpandFileName(TPath.Combine(ScopeFolder(AKey.Scope), SafeSegment(AKey.Name) + STATE_EXT));
  if not SameText(Copy(Result, 1, Length(FRoot) + 1), IncludeTrailingPathDelimiter(FRoot)) then
    raise ERadFormState.CreateFmt('State file outside the store root: %s', [Result]);
end;

function TRadFileStateStore.Load(const AKey: TRadStateKey; out AData: RawByteString): Boolean;
var
  LFile: TFileName;
begin
  AData := '';
  LFile := FileNameOf(AKey);
  if FileExists(LFile) then
    AData := StringFromFile(LFile);
  Result := AData <> '';
end;

procedure TRadFileStateStore.Save(const AKey: TRadStateKey; const AData: RawByteString);
var
  LFile, LTemp: TFileName;
begin
  LFile := FileNameOf(AKey);
  LTemp := LFile + TEMP_EXT;
  ForceDirectories(ExtractFilePath(LFile));
  // Readers see the old file or the new one, never a half-written one.
  if not FileFromString(AData, LTemp) then
    raise ERadFormState.CreateFmt('Cannot write %s', [LTemp]);
  if not MoveFileEx(PChar(LTemp), PChar(LFile), MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
  begin
    System.SysUtils.DeleteFile(LTemp);
    raise ERadFormState.CreateFmt('Cannot replace %s: %s', [LFile, SysErrorMessage(GetLastError)]);
  end;
end;

procedure TRadFileStateStore.Delete(const AKey: TRadStateKey);
var
  LFile: TFileName;
begin
  LFile := FileNameOf(AKey);
  if FileExists(LFile) and not System.SysUtils.DeleteFile(LFile) then
    raise ERadFormState.CreateFmt('Cannot delete %s', [LFile]);
end;

function TRadFileStateStore.LoadScope(const AScope: RawUtf8): TRadStateEntries;
var
  LFiles: TArray<string>;
  I: Integer;
begin
  Result := nil;
  if not TDirectory.Exists(ScopeFolder(AScope)) then
    Exit;
  LFiles := TDirectory.GetFiles(ScopeFolder(AScope), '*' + STATE_EXT);
  SetLength(Result, Length(LFiles));
  for I := 0 to High(LFiles) do
  begin
    // The name is the file name, i.e. after SafeSegment; class names pass through unchanged.
    Result[I].Key := TRadStateKey.Make(AScope, StringToUtf8(TPath.GetFileNameWithoutExtension(LFiles[I])));
    Result[I].Data := StringFromFile(LFiles[I]);
  end;
end;

{ TRadCallbackStateStore }

class procedure TRadCallbackStateStore.Reset;
begin
  DoLoad := nil;
  DoSave := nil;
  DoDelete := nil;
  DoLoadScope := nil;
end;

function TRadCallbackStateStore.Load(const AKey: TRadStateKey; out AData: RawByteString): Boolean;
begin
  AData := '';
  Result := Assigned(DoLoad) and DoLoad(AKey, AData) and (AData <> '');
end;

procedure TRadCallbackStateStore.Save(const AKey: TRadStateKey; const AData: RawByteString);
begin
  if not Assigned(DoSave) then
    raise ERadFormState.Create('TRadCallbackStateStore.DoSave is not assigned');
  DoSave(AKey, AData);
end;

procedure TRadCallbackStateStore.Delete(const AKey: TRadStateKey);
begin
  if Assigned(DoDelete) then
    DoDelete(AKey);
end;

function TRadCallbackStateStore.LoadScope(const AScope: RawUtf8): TRadStateEntries;
begin
  if Assigned(DoLoadScope) then
    Result := DoLoadScope(AScope)
  else
    Result := nil;
end;

{ TRadStateEnvelope }

class function TRadStateEnvelope.IsEncrypted(const AData: RawByteString): Boolean;
begin
  Result := (Length(AData) > ENVELOPE_HEADER) and (Copy(AData, 1, 4) = ENVELOPE_MAGIC);
end;

class function TRadStateEnvelope.Encode(const AJson: RawUtf8; const ACipher: IRadCipher): RawByteString;
var
  LLabel: RawUtf8;
begin
  if ACipher = nil then
    Exit(AJson);
  LLabel := ACipher.AlgorithmId;
  Result := ENVELOPE_MAGIC + ENVELOPE_VERSION + AnsiChar(Length(LLabel)) + LLabel +
    ACipher.Encrypt(AJson);
end;

function DecodeEncrypted(const AData: RawByteString; const ACipher: IRadCipher; out AJson: RawUtf8): Boolean;
var
  LLabelLen: Integer;
begin
  Result := False;
  if (ACipher = nil) or (AData[5] <> ENVELOPE_VERSION) then
    Exit;
  LLabelLen := Ord(AData[6]);
  if Copy(AData, ENVELOPE_HEADER + 1, LLabelLen) <> ACipher.AlgorithmId then
    Exit; // a different algorithm would decrypt into garbage or fail for the wrong reason
  try
    AJson := ACipher.Decrypt(Copy(AData, ENVELOPE_HEADER + LLabelLen + 1, MaxInt));
    Result := True;
  except
    on ERadCipherData do
      Result := False; // wrong key or tampered: GCM cannot tell which, and must not say
  end;
end;

class function TRadStateEnvelope.Decode(const AData: RawByteString; const ACipher: IRadCipher;
  out AJson: RawUtf8): Boolean;
begin
  AJson := '';
  if IsEncrypted(AData) then
    Exit(DecodeEncrypted(AData, ACipher, AJson));
  Result := (AData <> '') and (AData[1] = '{');
  if Result then
    AJson := AData;
end;

{ TRadStateRepository }

constructor TRadStateRepository.Create(const AStore: IRadStateStore; const ACipher: IRadCipher);
begin
  inherited Create;
  if AStore = nil then
    raise ERadFormState.Create('TRadStateRepository needs a store');
  FStore := AStore;
  FCipher := ACipher;
  FCache := TDictionary<RawUtf8, RawByteString>.Create;
  FHashes := TDictionary<RawUtf8, Cardinal>.Create;
  FPrefetched := TDictionary<RawUtf8, Boolean>.Create;
end;

destructor TRadStateRepository.Destroy;
begin
  FPrefetched.Free;
  FHashes.Free;
  FCache.Free;
  inherited;
end;

function ContentHash(const ADoc: IDocDict): Cardinal;
var
  LJson: RawUtf8;
begin
  // savedAt changes on every save; leaving it out lets an unchanged form skip the write.
  ADoc.Del(RAD_STATE_FIELD_SAVED_AT);
  LJson := ADoc.Json;
  Result := crc32c(0, pointer(LJson), Length(LJson));
end;

function TRadStateRepository.Fail(const AKey: TRadStateKey; const AReason: string): Boolean;
begin
  FLastError := Format('%s: %s', [Utf8ToString(AKey.Path), AReason]);
  TSynLog.Add.Log(sllWarning, 'rad.formstate %', [FLastError]);
  Result := False;
end;

function TRadStateRepository.ReadPayload(const AKey: TRadStateKey; out AData: RawByteString): Boolean;
begin
  Result := FCache.TryGetValue(AKey.Path, AData);
  if Result or FPrefetched.ContainsKey(AKey.Scope) then
    Exit; // a prefetched scope already holds every record it has
  Result := FStore.Load(AKey, AData);
  if Result then
    FCache.AddOrSetValue(AKey.Path, AData);
end;

function TRadStateRepository.ParseDoc(const AKey: TRadStateKey; const AData: RawByteString;
  out ADoc: IDocDict): Boolean;
var
  LJson: RawUtf8;
  LData: TDocVariantData;
begin
  ADoc := nil;
  if not TRadStateEnvelope.Decode(AData, FCipher, LJson) then
    Exit(Fail(AKey, 'cannot decode (unknown format, wrong key or tampered)'));
  // DocDict() accepts broken JSON silently (verified-api-traps.md); InitJson reports it.
  if not LData.InitJson(LJson, JSON_FAST_FLOAT) or (LData.Kind <> dvObject) then
    Exit(Fail(AKey, 'invalid JSON'));
  ADoc := DocDictCopy(LData); // DocDict(LData) would be a weak reference to this stack record
  if not TRadStateDoc.IsSupported(ADoc) then
    Exit(Fail(AKey, 'unsupported schema'));
  FHashes.AddOrSetValue(AKey.Path, ContentHash(ADoc));
  Result := True;
end;

function TRadStateRepository.Load(const AKey: TRadStateKey; out ADoc: IDocDict): Boolean;
var
  LData: RawByteString;
begin
  ADoc := nil;
  FLastError := '';
  Result := ReadPayload(AKey, LData) and ParseDoc(AKey, LData, ADoc);
  if not Result then
    ADoc := nil;
end;

function TRadStateRepository.Save(const AKey: TRadStateKey; const ADoc: IDocDict): Boolean;
var
  LHash, LOld: Cardinal;
  LData: RawByteString;
begin
  LHash := ContentHash(ADoc);
  if FHashes.TryGetValue(AKey.Path, LOld) and (LOld = LHash) then
    Exit(False);
  ADoc.U[RAD_STATE_FIELD_SAVED_AT] := NowUtcToString(True, 'T') + 'Z';
  LData := TRadStateEnvelope.Encode(ADoc.Json, FCipher);
  FStore.Save(AKey, LData);
  FCache.AddOrSetValue(AKey.Path, LData);
  FHashes.AddOrSetValue(AKey.Path, LHash);
  Result := True;
end;

procedure TRadStateRepository.Delete(const AKey: TRadStateKey);
begin
  FStore.Delete(AKey);
  FCache.Remove(AKey.Path);
  FHashes.Remove(AKey.Path);
end;

procedure TRadStateRepository.Prefetch(const AScope: RawUtf8);
var
  LEntry: TRadStateEntry;
begin
  for LEntry in FStore.LoadScope(AScope) do
    FCache.AddOrSetValue(LEntry.Key.Path, LEntry.Data);
  FPrefetched.AddOrSetValue(AScope, True);
end;

end.
