unit rad.script.engine;

(* TMS Scripter 8.1 sarmalayıcısı: birden çok TRadScript tek scripter'da, alt program keşfi,
   nesne/bileşen açma, kaynak dosyaları ({$FORM}), OnExecHook ile zaman aşımı, hata çevirisi.
   Thread başına bir motor; Vcl.ScripterInit şart (DefaultMachineClass). Bkz. docs/specs/rad.script.hooks.md *)

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.Variants, System.Diagnostics, System.SyncObjs,
  atScript, atPascal, ap_Classes, Vcl.ScripterInit,
  rad.script;

type
  TRadScriptEngine = class
  private
    class var FClasses: TList<TClass>;
    class var FLock: TCriticalSection;   // DefineClassByRTTI/Compile eş zamanlı iki thread'de INTERNAL ERROR verdi (HooksTest J12)
    class constructor Create;
    class destructor Destroy;
  private
    FScripter: TatPascalScripter;
    FScripts: TList<TatScript>;
    FCodes: TDictionary<TatScript, string>;
    FByCode: TDictionary<string, TatScript>;     // küçük harf kod → script
    FDeadlineMs: Cardinal;
    FWatch: TStopwatch;
    FTimedOut: Boolean;
    FErrRow, FErrCol: Integer;   // OnCompileError'dan; EatCompileError konum taşımaz
    FResourceDirs: TStringList;
    procedure ExecHook(Sender: TObject);
    procedure CompileErrorHook(Sender: TObject; var AMsg: string; ARow, ACol: Integer; var AShow: Boolean);
    function CodeOf(AScript: TatScript): string;
    function ScriptOf(const AScriptCode: string): TatScript;
    function RoutineOf(AScript: TatScript; const AName: string): TatRoutineInfo;
    function TranslateRuntime(const AScript: TatScript; E: Exception): Exception;
  public
    constructor Create;
    destructor Destroy; override;
    /// Her motora DefineClassByRTTI ile açılan sınıflar (global, 8 sınıf ≈ 2 ms).
    class procedure RegisterClass(AClass: TClass);
    class procedure RegisterClasses(const AClasses: array of TClass);
    /// Script kaynağını ekler; ScriptInfo.UnitName = Code (diğer script'ler `uses` ile görür).
    procedure AddScript(AScript: TRadScript);
    /// Paket kaynaklarını %LOCALAPPDATA%\rad\script\<paket>\ altına yazar, SearchPath'e ekler ({$FORM} için).
    procedure AddResources(APackageId: Integer; const AStore: IRadScriptStore; const ANames: array of string);
    /// Script'e global nesne (AddObject). Sınıfı DefineClass/RegisterClass ile açık olmalı.
    procedure Expose(const AName: string; AObject: TObject);
    /// Adıyla bileşen (AddComponent). Adsız bileşen hata.
    procedure ExposeComponent(AComponent: TComponent);
    /// Bu motora özel sınıf kaydı (formun kendi sınıfı gibi).
    procedure DefineClass(AClass: TClass);
    /// Tüm script'leri derler; ilk hata ERadScriptCompile.
    procedure Compile;
    /// Aynı ad birden çok script'te olabilir (paket zinciri); bu yüzden her çağrı script koduyla.
    function HasRoutine(const AScriptCode, AName: string): Boolean;
    function RoutineNames(const AScriptCode: string): TArray<string>;
    function ScriptCodes: TArray<string>;
    /// Alt programı çalıştırır; nesne argümanları TMS'nin beklediği tamsayı tutamağa çevrilir.
    function Call(const AScriptCode, AName: string; const AArgs: array of const): Variant;
    /// Her Call için süre sınırı (ms); 0 = yok. Script kendi thread'inde ERadScriptTimeout ile kesilir.
    procedure SetDeadline(AMs: Cardinal);
    property Scripter: TatPascalScripter read FScripter;
  end;

implementation

uses
  System.IOUtils, System.Character;

resourcestring
  SErrNoName = 'Adı olmayan bileşen script''e açılamaz (%s).';
  SErrRoutine = 'Alt program bulunamadı: %s';
  SErrNoScript = 'Motorda böyle bir script yok: %s';
  SErrTimeout = 'Script süre sınırını aştı (%d ms).';
  SErrNotCompiled = 'Script derlenmeden çağrılamaz: %s';

{ TRadScriptEngine }

class constructor TRadScriptEngine.Create;
begin
  FClasses := TList<TClass>.Create;
  FLock := TCriticalSection.Create;
end;

class destructor TRadScriptEngine.Destroy;
begin
  FLock.Free;
  FClasses.Free;
end;

class procedure TRadScriptEngine.RegisterClass(AClass: TClass);
begin
  if (AClass <> nil) and not FClasses.Contains(AClass) then
    FClasses.Add(AClass);
end;

class procedure TRadScriptEngine.RegisterClasses(const AClasses: array of TClass);
var
  C: TClass;
begin
  for C in AClasses do
    RegisterClass(C);
end;

constructor TRadScriptEngine.Create;
var
  C: TClass;
begin
  inherited Create;
  FScripter := TatPascalScripter.Create(nil);
  FScripter.AddLibrary(TatClassesLibrary);
  FScripter.OnCompileError := CompileErrorHook;
  FScripts := TList<TatScript>.Create;
  FCodes := TDictionary<TatScript, string>.Create;
  FByCode := TDictionary<string, TatScript>.Create;
  FResourceDirs := TStringList.Create;
  FLock.Enter;
  try
    for C in FClasses do
      FScripter.DefineClassByRTTI(C);
  finally
    FLock.Leave;
  end;
end;

destructor TRadScriptEngine.Destroy;
begin
  FResourceDirs.Free;
  FByCode.Free;
  FCodes.Free;
  FScripts.Free;
  FScripter.Free;
  inherited;
end;

procedure TRadScriptEngine.AddScript(AScript: TRadScript);
var
  S: TatScript;
begin
  S := FScripter.Scripts.Add;
  S.UnitName := AScript.Code;
  S.SourceCode.Text := AScript.Source;
  FScripts.Add(S);
  FCodes.Add(S, AScript.Code);
  FByCode.AddOrSetValue(LowerCase(AScript.Code), S);
end;

procedure TRadScriptEngine.AddResources(APackageId: Integer; const AStore: IRadScriptStore;
  const ANames: array of string);
var
  LDir, LName: string;
  LFile: TFileStream;
begin
  LDir := TPath.Combine(TPath.Combine(TPath.Combine(TPath.GetHomePath, 'rad'), 'script'), IntToStr(APackageId));
  TDirectory.CreateDirectory(LDir);
  for LName in ANames do
  begin
    LFile := TFileStream.Create(TPath.Combine(LDir, LName), fmCreate);
    try
      AStore.LoadResource(APackageId, LName, LFile);
    finally
      LFile.Free;
    end;
  end;
  if FResourceDirs.IndexOf(LDir) < 0 then
  begin
    FResourceDirs.Add(LDir);
    FScripter.LibOptions.SearchPath.Add(LDir);
    FScripter.LibOptions.FormFileExt := '.dfm';
  end;
end;

procedure TRadScriptEngine.Expose(const AName: string; AObject: TObject);
begin
  FScripter.AddObject(AName, AObject);
end;

procedure TRadScriptEngine.ExposeComponent(AComponent: TComponent);
begin
  if AComponent.Name = '' then
    raise ERadScript.CreateFmt(SErrNoName, [AComponent.ClassName]);
  FScripter.AddComponent(AComponent);
end;

procedure TRadScriptEngine.DefineClass(AClass: TClass);
begin
  // Dikkat: alt sınıfı tanıtmak TMS'de ata üyelerini görünmez yapar (Probe P1); formlar için kullanma.
  FLock.Enter;
  try
    FScripter.DefineClassByRTTI(AClass);
  finally
    FLock.Leave;
  end;
end;

function TRadScriptEngine.CodeOf(AScript: TatScript): string;
begin
  if not FCodes.TryGetValue(AScript, Result) then Result := '';
end;

procedure TRadScriptEngine.CompileErrorHook(Sender: TObject; var AMsg: string; ARow, ACol: Integer;
  var AShow: Boolean);
begin
  FErrRow := ARow;
  FErrCol := ACol;
  AShow := True;   // istisna yine fırlasın; konumu biz sakladık
end;

procedure TRadScriptEngine.Compile;
var
  S: TatScript;
begin
  FLock.Enter;
  try
    for S in FScripts do
    begin
      FScripter.CurrentScript := S;
      FErrRow := 0;
      FErrCol := 0;
      try
        S.Compile;
      except
        on E: Exception do
          raise ERadScriptCompile.Create(CodeOf(S), FErrRow, FErrCol, E.Message);
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function TRadScriptEngine.ScriptOf(const AScriptCode: string): TatScript;
begin
  if not FByCode.TryGetValue(LowerCase(AScriptCode), Result) then
    raise ERadScript.CreateFmt(SErrNoScript, [AScriptCode]);
end;

function TRadScriptEngine.RoutineOf(AScript: TatScript; const AName: string): TatRoutineInfo;
var
  i: Integer;
begin
  for i := 0 to AScript.ScriptInfo.Routines.Count - 1 do
  begin
    Result := AScript.ScriptInfo.Routines[i];
    if not Result.Internal and SameText(Result.Name, AName) and not Result.Name.StartsWith('__') then Exit;
  end;
  Result := nil;
end;

function TRadScriptEngine.HasRoutine(const AScriptCode, AName: string): Boolean;
begin
  Result := RoutineOf(ScriptOf(AScriptCode), AName) <> nil;
end;

function TRadScriptEngine.RoutineNames(const AScriptCode: string): TArray<string>;
var
  S: TatScript;
  i: Integer;
  L: TList<string>;
begin
  S := ScriptOf(AScriptCode);
  L := TList<string>.Create;
  try
    for i := 0 to S.ScriptInfo.Routines.Count - 1 do
      if not S.ScriptInfo.Routines[i].Internal and not S.ScriptInfo.Routines[i].Name.StartsWith('__') then
        L.Add(S.ScriptInfo.Routines[i].Name);   // ana blok (___MAIN___) dışarıda (Probe P2)
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

function TRadScriptEngine.ScriptCodes: TArray<string>;
var
  S: TatScript;
  L: TList<string>;
begin
  L := TList<string>.Create;
  try
    for S in FScripts do L.Add(CodeOf(S));
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

procedure TRadScriptEngine.SetDeadline(AMs: Cardinal);
begin
  FDeadlineMs := AMs;
end;

procedure TRadScriptEngine.ExecHook(Sender: TObject);
begin
  if (FDeadlineMs > 0) and (FWatch.ElapsedMilliseconds > FDeadlineMs) then
  begin
    FTimedOut := True;
    // Halt değil: komut ortasında VM bozulur (sonda C9). İstisna VM'yi temiz bırakır (C10').
    raise ERadScriptTimeout.Create('', 0, 0, Format(SErrTimeout, [FDeadlineMs]));
  end;
end;

function TRadScriptEngine.TranslateRuntime(const AScript: TatScript; E: Exception): Exception;
var
  LLine, LCol: Integer;
begin
  LLine := 0;
  LCol := 0;
  if E is EatScripterRuntime then
  begin
    LLine := EatScripterRuntime(E).Row;
    LCol := EatScripterRuntime(E).Col;
  end;
  if FTimedOut then
    Result := ERadScriptTimeout.Create(CodeOf(AScript), LLine, LCol, Format(SErrTimeout, [FDeadlineMs]))
  else
    Result := ERadScriptRuntime.Create(CodeOf(AScript), LLine, LCol, E.Message);
end;

function TRadScriptEngine.Call(const AScriptCode, AName: string; const AArgs: array of const): Variant;
var
  S: TatScript;
  LRecs: TArray<TVarRec>;
  LInts: TArray<Int64>;
  i: Integer;
begin
  S := ScriptOf(AScriptCode);
  if RoutineOf(S, AName) = nil then
    raise ERadScript.CreateFmt(SErrRoutine, [AScriptCode + '.' + AName]);
  // Nesneler TMS'ye tamsayı tutamak olarak gider (IntObject = NativeInt / Integer).
  SetLength(LRecs, Length(AArgs));
  SetLength(LInts, Length(AArgs));
  for i := 0 to High(AArgs) do
  begin
    LRecs[i] := AArgs[i];
    if AArgs[i].VType in [vtObject, vtClass, vtPointer, vtInterface] then
    begin
      LInts[i] := Int64(NativeInt(AArgs[i].VPointer));
      {$IFDEF CPU64BITS}
      LRecs[i].VType := vtInt64;
      LRecs[i].VInt64 := @LInts[i];
      {$ELSE}
      LRecs[i].VType := vtInteger;
      LRecs[i].VInteger := Integer(LInts[i]);
      {$ENDIF}
    end;
  end;
  FScripter.CurrentScript := S;
  FTimedOut := False;
  // Compile VM'yi yeniden kurar ve hook'u kaybeder: her çağrıda yeniden bağla (sonda C9 ölçümü).
  FScripter.CallExecHookEvent := FDeadlineMs > 0;
  if FDeadlineMs > 0 then
  begin
    FScripter.OnExecHook := ExecHook;
    FWatch := TStopwatch.StartNew;
  end
  else
    FScripter.OnExecHook := nil;
  try
    Result := FScripter.ExecuteSubroutineAsVariant(AName, LRecs);
  except
    on E: ERadScript do raise;
    on E: Exception do raise TranslateRuntime(S, E);
  end;
end;

end.
