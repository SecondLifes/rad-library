unit rad.script.engine;

(* TMS Scripter 8.1 sarmalayıcısı: birden çok TRadScript tek scripter'da, script kodlu alt program
   çağrısı, nesne/bileşen açma, kaynak dosyaları ({$FORM}), OnExecHook ile zaman aşımı, hata çevirisi,
   sahipli facade nesneleri, API referansı üretimi. Thread başına bir motor; Vcl.ScripterInit şart.
   Bkz. docs/specs/rad.script.hooks.md ve rad.script.facade.md *)

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.Variants, System.Diagnostics, System.SyncObjs,
  atScript, atPascal, ap_Classes, ap_System, ap_SysUtils, ap_StrUtils, ap_DateUtils, ap_Math, ap_Variants,
  Vcl.ScripterInit,
  rad.script;

type
  TRadScriptEngine = class
  private
    class var FClasses: TList<TClass>;
    class var FHidden: TDictionary<TClass, TArray<string>>;
    class var FLock: TCriticalSection;   // DefineClassByRTTI/Compile eş zamanlı iki thread'de emniyet (Probe P3 temizdi, kilit ucuz)
    class constructor Create;
    class destructor Destroy;
  private
    FScripter: TatPascalScripter;
    FScripts: TList<TatScript>;
    FCodes: TDictionary<TatScript, string>;
    FByCode: TDictionary<string, TatScript>;     // küçük harf kod → script
    FDefined: TList<TClass>;                     // referans için: bu motora tanıtılan sınıflar
    FExposed: TStringList;                       // ad=sınıf adı
    FOwned: TObjectList<TObject>;                // motorla yıkılan facade nesneleri
    FPackageIds: TArray<Integer>;
    FLastErrorText: string;
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
    procedure DefineAndHide(AClass: TClass);
    procedure HideObjectLifetime;
    function TranslateRuntime(const AScript: TatScript; E: Exception): Exception;
  public
    constructor Create;
    destructor Destroy; override;
    /// Her motora DefineClassByRTTI ile açılan sınıflar (global, 8 sınıf ≈ 2 ms).
    class procedure RegisterClass(AClass: TClass);
    class procedure RegisterClasses(const AClasses: array of TClass);
    /// Sınıfı kaydeder, verilen üyeleri (özellik/metot) TMS tanımından siler: Password, Server...
    class procedure RegisterClassHidden(AClass: TClass; const AHiddenMembers: array of string);
    /// Script kaynağını ekler; UnitName = Code (diğer script'ler `uses` ile görür).
    procedure AddScript(AScript: TRadScript);
    /// Paket kaynaklarını %LOCALAPPDATA%\rad\script\<paket>\ altına yazar, SearchPath'e ekler ({$FORM} için).
    procedure AddResources(APackageId: Integer; const AStore: IRadScriptStore; const ANames: array of string);
    /// Script'e global nesne (AddObject). Sınıfı DefineClass/RegisterClass ile açık olmalı.
    procedure Expose(const AName: string; AObject: TObject);
    /// Adıyla bileşen (AddComponent). Adsız bileşen hata.
    procedure ExposeComponent(AComponent: TComponent);
    /// Bu motora özel sınıf kaydı. Dikkat: alt sınıfı tanıtmak TMS'de ata üyelerini görünmez yapar (Probe P1); formlar için kullanma.
    procedure DefineClass(AClass: TClass);
    /// Motor yıkılırken serbest bırakılacak nesne (facade). Sahiplik motora geçer.
    procedure AddOwned(AObject: TObject);
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
    /// Kayıtlı sınıflar ve açık nesneler için Markdown API referansı (rad-script skill'i bunu kullanır).
    function ExportReference: string;
    property Scripter: TatPascalScripter read FScripter;
    /// Bağlı paketler (Param facade'ı için); binder/jobs doldurur.
    property PackageIds: TArray<Integer> read FPackageIds write FPackageIds;
    /// Msg.HataMetni ile konur; tipli kanca (OnValidate) ErrorText olarak okur ve siler.
    property LastErrorText: string read FLastErrorText write FLastErrorText;
  end;

implementation

uses
  System.IOUtils, System.Character;

const
  LIFETIME_MEMBERS: array[0..4] of string = ('Free', 'Destroy', 'Create', 'FreeInstance', 'CleanupInstance');

resourcestring
  SErrNoName = 'Adı olmayan bileşen script''e açılamaz (%s).';
  SErrRoutine = 'Alt program bulunamadı: %s';
  SErrNoScript = 'Motorda böyle bir script yok: %s';
  SErrTimeout = 'Script süre sınırını aştı (%d ms).';

{ TRadScriptEngine }

class constructor TRadScriptEngine.Create;
begin
  FClasses := TList<TClass>.Create;
  FHidden := TDictionary<TClass, TArray<string>>.Create;
  FLock := TCriticalSection.Create;
end;

class destructor TRadScriptEngine.Destroy;
begin
  FLock.Free;
  FHidden.Free;
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

class procedure TRadScriptEngine.RegisterClassHidden(AClass: TClass; const AHiddenMembers: array of string);
var
  L: TArray<string>;
  i: Integer;
begin
  RegisterClass(AClass);
  SetLength(L, Length(AHiddenMembers));
  for i := 0 to High(AHiddenMembers) do L[i] := AHiddenMembers[i];
  FHidden.AddOrSetValue(AClass, L);
end;

constructor TRadScriptEngine.Create;
var
  C: TClass;
begin
  inherited Create;
  FScripter := TatPascalScripter.Create(nil);
  FScripter.AddLibrary(TatClassesLibrary);
  FScripter.OnCompileError := CompileErrorHook;
  HideObjectLifetime;
  FScripts := TList<TatScript>.Create;
  FCodes := TDictionary<TatScript, string>.Create;
  FByCode := TDictionary<string, TatScript>.Create;
  FDefined := TList<TClass>.Create;
  FExposed := TStringList.Create;
  FOwned := TObjectList<TObject>.Create(True);
  FResourceDirs := TStringList.Create;
  FLock.Enter;
  try
    for C in FClasses do
      DefineAndHide(C);
  finally
    FLock.Leave;
  end;
end;

destructor TRadScriptEngine.Destroy;
begin
  FOwned.Free;   // facade nesneleri scripter'dan önce: script artık çalışmıyor
  FResourceDirs.Free;
  FExposed.Free;
  FDefined.Free;
  FByCode.Free;
  FCodes.Free;
  FScripts.Free;
  FScripter.Free;
  inherited;
end;

procedure TRadScriptEngine.HideObjectLifetime;
var
  LDef: TatClass;
  LName: string;
  LMeth: TatMethod;
begin
  // Script hiçbir nesneyi yıkmaz/yaratmaz: Free/Destroy/Create TObject tanımından silinir (facade ve bileşenler motorun/formun malı).
  LDef := FScripter.Classes.ClassByName('TObject');
  if LDef = nil then Exit;
  for LName in LIFETIME_MEMBERS do
  begin
    LMeth := LDef.Methods.MethodByName(LName);
    if LMeth <> nil then LMeth.Free;
  end;
end;

procedure TRadScriptEngine.DefineAndHide(AClass: TClass);
var
  LDef: TatClass;
  LHidden: TArray<string>;
  LName: string;
  LProp: TatProperty;
  LMeth: TatMethod;
begin
  LDef := FScripter.DefineClassByRTTI(AClass);
  if not FDefined.Contains(AClass) then FDefined.Add(AClass);
  if LDef = nil then Exit;
  // RTTI kaydı TObject'in Create/Free'sini her sınıfa kopyalar: script nesne yaratmaz/yıkmaz, hepsinden sil.
  for LName in LIFETIME_MEMBERS do
  begin
    LMeth := LDef.Methods.MethodByName(LName);
    if LMeth <> nil then LMeth.Free;
  end;
  if not FHidden.TryGetValue(AClass, LHidden) then Exit;
  for LName in LHidden do
  begin
    LProp := LDef.Properties.PropertyByName(LName);
    if LProp <> nil then LProp.Free;
    LMeth := LDef.Methods.MethodByName(LName);
    if LMeth <> nil then LMeth.Free;
  end;
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
  FExposed.Values[AName] := AObject.ClassName;
end;

procedure TRadScriptEngine.ExposeComponent(AComponent: TComponent);
begin
  if AComponent.Name = '' then
    raise ERadScript.CreateFmt(SErrNoName, [AComponent.ClassName]);
  FScripter.AddComponent(AComponent);
end;

procedure TRadScriptEngine.DefineClass(AClass: TClass);
begin
  FLock.Enter;
  try
    DefineAndHide(AClass);
  finally
    FLock.Leave;
  end;
end;

procedure TRadScriptEngine.AddOwned(AObject: TObject);
begin
  FOwned.Add(AObject);
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

function TRadScriptEngine.ExportReference: string;
var
  SB: TStringBuilder;
  C: TClass;
  LDef: TatClass;
  i, j: Integer;
  M: TatMethod;
  P: TatProperty;
  A: TatDataDef;
  LArgs: string;
  LSeen: TList<string>;
  LName: string;
begin
  SB := TStringBuilder.Create;
  LSeen := TList<string>.Create;
  try
    SB.AppendLine('# Script API referansı').AppendLine;
    SB.AppendLine('Üretildi: TRadScriptEngine.ExportReference. Elle düzenleme yapma.').AppendLine;
    if FExposed.Count > 0 then
    begin
      SB.AppendLine('## Global nesneler').AppendLine;
      for i := 0 to FExposed.Count - 1 do
        SB.Append('- `').Append(FExposed.Names[i]).Append('`: ').AppendLine(FExposed.ValueFromIndex[i]);
      SB.AppendLine;
    end;
    for C in FDefined do
    begin
      LDef := FScripter.Classes.ClassByName(C.ClassName);
      if (LDef = nil) or LSeen.Contains(C.ClassName) then Continue;
      LSeen.Add(C.ClassName);
      SB.Append('## ').AppendLine(C.ClassName);
      if LDef.AncestorName <> '' then SB.Append('Atası: ').AppendLine(LDef.AncestorName);
      SB.AppendLine;
      if LDef.Properties.Count > 0 then
      begin
        SB.AppendLine('### Özellikler');
        for i := 0 to LDef.Properties.Count - 1 do
        begin
          P := TatProperty(LDef.Properties.Items[i]);
          SB.Append('- `').Append(P.Name).Append(': ').Append(P.PropTypeName).Append('`');
          if not P.Writeable then SB.Append(' (salt okunur)');
          SB.AppendLine;
        end;
        SB.AppendLine;
      end;
      if LDef.Methods.Count > 0 then
      begin
        SB.AppendLine('### Metotlar');
        for i := 0 to LDef.Methods.Count - 1 do
        begin
          M := TatMethod(LDef.Methods.Items[i]);
          LArgs := '';
          for j := 0 to M.ArgDefs.Count - 1 do
          begin
            A := TatDataDef(M.ArgDefs.Items[j]);
            if j > 0 then LArgs := LArgs + '; ';
            if A.Modifier = moVar then LArgs := LArgs + 'var ';
            LName := A.Name;
            if LName = '' then LName := 'A' + IntToStr(j + 1);
            LArgs := LArgs + LName;
            if A.DataTypeName <> '' then LArgs := LArgs + ': ' + A.DataTypeName;
          end;
          SB.Append('- `').Append(M.Name).Append('(').Append(LArgs).Append(')');
          if M.ResultTypeName <> '' then SB.Append(': ').Append(M.ResultTypeName);
          SB.AppendLine('`');
        end;
        SB.AppendLine;
      end;
    end;
    Result := SB.ToString;
  finally
    LSeen.Free;
    SB.Free;
  end;
end;

end.
