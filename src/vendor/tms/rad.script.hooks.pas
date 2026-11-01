unit rad.script.hooks;

(* Kanca katmanı: form sınıfına bağlı script'leri yükler, `<Bileşen>_Before/_After` alt programlarını
   RTTI ile olaylara sarar (Before False → orijinal çalışmaz), form ölünce çözer.
   Wolvox kalıbı + iptal; TMS EventBroker iptal edemediği için kendi sarmalayıcımız (sonda V3).
   Var parametreli olaylar için tipli kanca sınıfları TypeInfo ile kaydedilir (rad.script.typedhooks). *)

interface

uses
  System.SysUtils, System.Classes, System.TypInfo, System.Rtti, System.Generics.Collections, System.Variants,
  Vcl.Forms,
  rad.script, rad.script.engine;

type
  TRadHookBase = class;
  TRadHookErrorEvent = reference to procedure(AHook: TRadHookBase; E: Exception);

  /// Aynı olaya sarılan kancaların ortak durumu: içteki Before iptal edince dıştakiler After'ı atlar.
  TRadHookChain = class
  private
    FDepth: Integer;
    FCancelled: Boolean;
  public
    property Cancelled: Boolean read FCancelled write FCancelled;
  end;

  /// Olay sarmalayıcı tabanı: Before/After çağrıları, zincir ve hata raporu ortak; imza alt sınıfta.
  TRadHookBase = class abstract
  private
    FInstance: TObject;
    FPropName: string;
    FOriginal: TMethod;
    FEngine: TRadScriptEngine;
    FScriptCode: string;
    FBefore: string;
    FAfter: string;
    FOnError: TRadHookErrorEvent;
    FAttached: Boolean;
    FChain: TRadHookChain;
    FOwnChain: Boolean;
  protected
    procedure Report(E: Exception);
    /// En dış kanca zinciri sıfırlar; her Handler başında.
    procedure BeginChain;
    procedure EndChain;
    /// Before'u çağırır; açık False veya istisna → iptal (zincir işaretlenir), False döner.
    function RunBefore(const AArgs: array of const): Boolean;
    /// Zincir iptal edilmediyse After'ı çağırır; istisna raporlanır, yayılmaz.
    procedure RunAfter(const AArgs: array of const);
    /// Alt sınıfın kendi imzalı Handler metodu.
    function HandlerMethod: TMethod; virtual; abstract;
    property Original: TMethod read FOriginal;
    property Engine: TRadScriptEngine read FEngine;
    property Chain: TRadHookChain read FChain;
  public
    /// AChain nil ise kanca kendi zincirini kurar (tek kanca).
    constructor Create(AInstance: TObject; const APropName: string; AEngine: TRadScriptEngine;
      const AScriptCode, ABefore, AAfter: string; AChain: TRadHookChain); virtual;
    destructor Destroy; override;
    /// Orijinal olayı geri koyar; idempotent.
    procedure Detach;
    property Instance: TObject read FInstance;
    property PropName: string read FPropName;
    property ScriptCode: string read FScriptCode;
    property Before: string read FBefore;
    property After: string read FAfter;
    property OnError: TRadHookErrorEvent read FOnError write FOnError;
  end;
  TRadHookBaseClass = class of TRadHookBase;

  /// Tek nesne parametreli olaylar (TNotifyEvent, TDataSetNotifyEvent...).
  TRadNotifyHook = class(TRadHookBase)
  private
    procedure Handler(Sender: TObject);
  protected
    function HandlerMethod: TMethod; override;
  public
    /// Published olay, tek parametre, sınıf türünde, var/out değil, sonuç yok.
    class function CanHook(AInstance: TObject; const APropName: string): Boolean;
  end;

  /// Forma bağlı script motoru + kancalar; Owner form olduğundan formla birlikte yıkılır.
  TRadScriptAttachment = class(TComponent)
  private
    FEngine: TRadScriptEngine;
    FHooks: TObjectList<TRadHookBase>;
    FChains: TObjectList<TRadHookChain>;
    FScripts: TRadScripts;
    FLibraries: TRadScripts;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Detach;
    property Engine: TRadScriptEngine read FEngine;
    property Hooks: TObjectList<TRadHookBase> read FHooks;
    /// Bağlanan script'ler, ata sınıf önce.
    property Scripts: TRadScripts read FScripts;
    property Libraries: TRadScripts read FLibraries;
  end;

  TRadScriptErrorEvent = reference to procedure(AForm: TCustomForm; E: Exception);
  TRadScriptWarningEvent = reference to procedure(const AMessage: string);
  TRadScriptFacadeInstaller = reference to procedure(AEngine: TRadScriptEngine);

  TRadScriptBinder = class
  private
    class var FStore: IRadScriptStore;
    class var FOnError: TRadScriptErrorEvent;
    class var FOnWarning: TRadScriptWarningEvent;
    class var FOnInstallFacade: TRadScriptFacadeInstaller;
    class var FHookClasses: TDictionary<PTypeInfo, TRadHookBaseClass>;
    class constructor Create;
    class destructor Destroy;
    class function PrimaryEvent(AInstance: TObject): string;
    class function ResolveTarget(AOwner: TComponent; const ABase: string; out AInstance: TObject;
      out AProp: string): Boolean;
    class function HookClassFor(AInstance: TObject; const AProp: string): TRadHookBaseClass;
    class procedure Warn(const AMsg: string);
    class procedure ReportError(AForm: TCustomForm; E: Exception);
  public
    /// Script yükleme + derleme + facade; kanca yok. Attach ve rad.script.commands kullanır. Script yoksa nil.
    class function LoadInto(AOwner: TComponent; AKind: TRadScriptKind; const AChain: TArray<string>): TRadScriptAttachment;
    /// Sınıf zinciri ata önce (TForm/TComponent'e kadar).
    class function ClassChain(AObject: TObject): TArray<string>;
    /// Script'teki alt program adlarından kancaları kurar.
    class procedure InstallHooks(AOwner: TComponent; AAtt: TRadScriptAttachment);
    /// Bir kez atanır; nil ise Attach hiçbir şey yapmaz.
    class property Store: IRadScriptStore read FStore write FStore;
    /// Derleme ve çalışma hataları; nil → Application.ShowException. Form olmayan sahipte AForm nil.
    class property OnError: TRadScriptErrorEvent read FOnError write FOnError;
    /// Kurulamayan kanca, bulunamayan bileşen.
    class property OnWarning: TRadScriptWarningEvent read FOnWarning write FOnWarning;
    /// Facade kurucusu (rad.script.facade atar); Compile'dan önce çağrılır.
    class property OnInstallFacade: TRadScriptFacadeInstaller read FOnInstallFacade write FOnInstallFacade;
    /// Var parametreli olay tipi için kanca sınıfı (rad.script.typedhooks kaydeder).
    class procedure RegisterHookClass(ATypeInfo: PTypeInfo; AClass: TRadHookBaseClass);
    /// Form sınıfı ve ataları için script varsa yükler, derler, kancaları kurar, Form_AfterCreate'i çağırır.
    /// Script yoksa veya derleme hatasıysa (OnError) nil.
    class function Attach(AForm: TCustomForm): TRadScriptAttachment;
    class function AttachmentOf(AOwner: TComponent): TRadScriptAttachment;
  end;

implementation

resourcestring
  SWarnNoComponent = '%s: "%s" adlı bileşen/olay bulunamadı; "%s" kancası kurulmadı.';
  SWarnCannotHook = '%s: "%s.%s" olayı sarılamaz (tek nesne parametreli ya da kayıtlı tip olmalı); "%s" kancası kurulmadı.';

const
  SUFFIX_BEFORE = '_before';
  SUFFIX_AFTER = '_after';
  FORM_ALIAS = 'form';
  FORM_AFTER_CREATE = 'Form_AfterCreate';

{ TRadHookBase }

constructor TRadHookBase.Create(AInstance: TObject; const APropName: string; AEngine: TRadScriptEngine;
  const AScriptCode, ABefore, AAfter: string; AChain: TRadHookChain);
begin
  inherited Create;
  FChain := AChain;
  FOwnChain := AChain = nil;
  if FOwnChain then FChain := TRadHookChain.Create;
  FInstance := AInstance;
  FPropName := APropName;
  FEngine := AEngine;
  FScriptCode := AScriptCode;
  FBefore := ABefore;
  FAfter := AAfter;
  FOriginal := GetMethodProp(AInstance, APropName);
  SetMethodProp(AInstance, APropName, HandlerMethod);
  FAttached := True;
end;

destructor TRadHookBase.Destroy;
begin
  Detach;
  if FOwnChain then FChain.Free;
  inherited;
end;

procedure TRadHookBase.Detach;
begin
  if not FAttached then Exit;
  FAttached := False;
  SetMethodProp(FInstance, FPropName, FOriginal);
end;

procedure TRadHookBase.Report(E: Exception);
begin
  if Assigned(FOnError) then FOnError(Self, E)
  else raise E;
end;

procedure TRadHookBase.BeginChain;
begin
  if FChain.FDepth = 0 then FChain.FCancelled := False;   // en dış kanca zinciri sıfırlar
  Inc(FChain.FDepth);
end;

procedure TRadHookBase.EndChain;
begin
  Dec(FChain.FDepth);
end;

function TRadHookBase.RunBefore(const AArgs: array of const): Boolean;
var
  V: Variant;
begin
  Result := True;
  if FBefore = '' then Exit;
  try
    V := FEngine.Call(FScriptCode, FBefore, AArgs);
    // Yalnız açık False iptal eder; procedure (Empty) ve Null geçer.
    Result := not (VarIsType(V, varBoolean) and not Boolean(V));
  except
    on E: Exception do
    begin
      Result := False;   // emniyetli taraf: hata = iptal
      Report(E);
    end;
  end;
  if not Result then FChain.FCancelled := True;
end;

procedure TRadHookBase.RunAfter(const AArgs: array of const);
begin
  if FChain.FCancelled or (FAfter = '') then Exit;   // içteki Before iptal etti: After yok
  try
    FEngine.Call(FScriptCode, FAfter, AArgs);
  except
    on E: Exception do Report(E);   // kayıt yapıldı, geri alınmaz (kullanıcı kararı)
  end;
end;

{ TRadNotifyHook }

function TRadNotifyHook.HandlerMethod: TMethod;
begin
  Result.Code := @TRadNotifyHook.Handler;
  Result.Data := Self;
end;

class function TRadNotifyHook.CanHook(AInstance: TObject; const APropName: string): Boolean;
var
  LInfo: PPropInfo;
  LCtx: TRttiContext;
  LType: TRttiType;
  LParams: TArray<TRttiParameter>;
begin
  Result := False;
  LInfo := GetPropInfo(AInstance, APropName);
  if (LInfo = nil) or (LInfo^.PropType^.Kind <> tkMethod) then Exit;
  LType := LCtx.GetType(LInfo^.PropType^);
  if not (LType is TRttiMethodType) then Exit;
  if TRttiMethodType(LType).ReturnType <> nil then Exit;
  LParams := TRttiMethodType(LType).GetParameters;
  Result := (Length(LParams) = 1) and (LParams[0].ParamType <> nil) and
    (LParams[0].ParamType.TypeKind = tkClass) and (LParams[0].Flags * [pfVar, pfOut] = []);
end;

procedure TRadNotifyHook.Handler(Sender: TObject);
begin
  BeginChain;
  try
    if not RunBefore([Sender]) then Exit;
    if Assigned(Original.Code) then
      TNotifyEvent(Original)(Sender);   // içteki kanca ya da gerçek olay
    RunAfter([Sender]);
  finally
    EndChain;
  end;
end;

{ TRadScriptAttachment }

constructor TRadScriptAttachment.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEngine := TRadScriptEngine.Create;
  FHooks := TObjectList<TRadHookBase>.Create(True);
  FChains := TObjectList<TRadHookChain>.Create(True);
  FScripts := TRadScripts.Create(True);
  FLibraries := TRadScripts.Create(True);
end;

destructor TRadScriptAttachment.Destroy;
begin
  Detach;
  FHooks.Free;
  FChains.Free;
  FLibraries.Free;
  FScripts.Free;
  FEngine.Free;
  inherited;
end;

procedure TRadScriptAttachment.Detach;
var
  i: Integer;
begin
  for i := FHooks.Count - 1 downto 0 do   // son kurulan (en dış) önce çözülür
    FHooks[i].Detach;
end;

{ TRadScriptBinder }

class constructor TRadScriptBinder.Create;
begin
  FHookClasses := TDictionary<PTypeInfo, TRadHookBaseClass>.Create;
end;

class destructor TRadScriptBinder.Destroy;
begin
  FHookClasses.Free;
end;

class procedure TRadScriptBinder.RegisterHookClass(ATypeInfo: PTypeInfo; AClass: TRadHookBaseClass);
begin
  FHookClasses.AddOrSetValue(ATypeInfo, AClass);
end;

class procedure TRadScriptBinder.Warn(const AMsg: string);
begin
  if Assigned(FOnWarning) then FOnWarning(AMsg);
end;

class procedure TRadScriptBinder.ReportError(AForm: TCustomForm; E: Exception);
begin
  if Assigned(FOnError) then FOnError(AForm, E)
  else Application.ShowException(E);
end;

class function TRadScriptBinder.ClassChain(AObject: TObject): TArray<string>;
var
  C: TClass;
  L: TList<string>;
begin
  L := TList<string>.Create;
  try
    C := AObject.ClassType;
    while (C <> nil) and (C <> TCustomForm) and (C <> TForm) and (C <> TComponent) and (C <> TDataModule) do
    begin
      L.Insert(0, C.ClassName);   // ata önce
      C := C.ClassParent;
    end;
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

class function TRadScriptBinder.AttachmentOf(AOwner: TComponent): TRadScriptAttachment;
var
  i: Integer;
begin
  for i := 0 to AOwner.ComponentCount - 1 do
    if AOwner.Components[i] is TRadScriptAttachment then
      Exit(TRadScriptAttachment(AOwner.Components[i]));
  Result := nil;
end;

class function TRadScriptBinder.PrimaryEvent(AInstance: TObject): string;
begin
  if AInstance is TBasicAction then Result := 'OnExecute'
  else if IsPublishedProp(AInstance, 'OnClick') then Result := 'OnClick'
  else Result := '';
end;

class function TRadScriptBinder.ResolveTarget(AOwner: TComponent; const ABase: string; out AInstance: TObject;
  out AProp: string): Boolean;
var
  P: Integer;
  LCompName, LEvent: string;
  LComp: TComponent;
begin
  // 1) "<Bileşen>" → ana olay
  if SameText(ABase, FORM_ALIAS) then LComp := AOwner else LComp := AOwner.FindComponent(ABase);
  if LComp <> nil then
  begin
    AInstance := LComp;
    AProp := PrimaryEvent(LComp);
    Exit(AProp <> '');
  end;
  // 2) "<Bileşen>_<Olay>"
  P := ABase.LastIndexOf('_');
  if P <= 0 then Exit(False);
  LCompName := ABase.Substring(0, P);
  LEvent := ABase.Substring(P + 1);
  if SameText(LCompName, FORM_ALIAS) then LComp := AOwner else LComp := AOwner.FindComponent(LCompName);
  if LComp = nil then Exit(False);
  AInstance := LComp;
  AProp := LEvent;
  if IsPublishedProp(LComp, LEvent) then Exit(True);
  // DevExpress editörleri olayları Properties alt nesnesinde tutar (edt.Properties.OnValidate).
  if IsPublishedProp(LComp, 'Properties') then
  begin
    AInstance := GetObjectProp(LComp, 'Properties');
    if (AInstance <> nil) and IsPublishedProp(AInstance, LEvent) then Exit(True);
  end;
  Result := False;
end;

class function TRadScriptBinder.HookClassFor(AInstance: TObject; const AProp: string): TRadHookBaseClass;
var
  LInfo: PPropInfo;
begin
  if TRadNotifyHook.CanHook(AInstance, AProp) then Exit(TRadNotifyHook);
  LInfo := GetPropInfo(AInstance, AProp);
  if (LInfo = nil) or (LInfo^.PropType^.Kind <> tkMethod) or
     not FHookClasses.TryGetValue(LInfo^.PropType^, Result) then
    Result := nil;
end;

type
  TPendingHook = record
    Instance: TObject;
    Prop: string;
    ScriptCode: string;
    Before, After: string;
    HookClass: TRadHookBaseClass;
  end;

class procedure TRadScriptBinder.InstallHooks(AOwner: TComponent; AAtt: TRadScriptAttachment);
var
  LPending: TList<TPendingHook>;
  LByScript: TObjectList<TList<TPendingHook>>;
  LNames: TArray<string>;
  LName, LLower, LBase, LProp: string;
  LIsBefore: Boolean;
  LInst: TObject;
  i, j, k: Integer;
  H: TPendingHook;
  LHook: TRadHookBase;
  LChain: TRadHookChain;
  LOwnerName: string;
  LScript: TRadScript;
  LClass: TRadHookBaseClass;
  LForm: TCustomForm;
begin
  LOwnerName := AOwner.ClassName;
  if AOwner is TCustomForm then LForm := TCustomForm(AOwner) else LForm := nil;
  LByScript := TObjectList<TList<TPendingHook>>.Create(True);
  try
   for LScript in AAtt.Scripts do
   begin
    // Script başına liste; aynı (nesne, olay) için before+after tek kancadır.
    LPending := TList<TPendingHook>.Create;
    LByScript.Add(LPending);
    LNames := AAtt.Engine.RoutineNames(LScript.Code);
    for LName in LNames do
    begin
      LLower := LowerCase(LName);
      LIsBefore := LLower.EndsWith(SUFFIX_BEFORE);
      if not LIsBefore and not LLower.EndsWith(SUFFIX_AFTER) then Continue;
      if LIsBefore then LBase := LName.Substring(0, Length(LName) - Length(SUFFIX_BEFORE))
      else LBase := LName.Substring(0, Length(LName) - Length(SUFFIX_AFTER));
      if not ResolveTarget(AOwner, LBase, LInst, LProp) then
      begin
        Warn(Format(SWarnNoComponent, [LOwnerName, LBase, LName]));
        Continue;
      end;
      LClass := HookClassFor(LInst, LProp);
      if LClass = nil then
      begin
        Warn(Format(SWarnCannotHook, [LOwnerName, LBase, LProp, LName]));
        Continue;
      end;
      k := -1;
      for j := 0 to LPending.Count - 1 do
        if (LPending[j].Instance = LInst) and SameText(LPending[j].Prop, LProp) then
        begin
          k := j;
          Break;
        end;
      if k < 0 then
      begin
        H.Instance := LInst;
        H.Prop := LProp;
        H.ScriptCode := LScript.Code;
        H.HookClass := LClass;
        H.Before := '';
        H.After := '';
        LPending.Add(H);
        k := LPending.Count - 1;
      end;
      H := LPending[k];
      if LIsBefore then H.Before := LName else H.After := LName;
      LPending[k] := H;
    end;
   end;
    // Kurulum: liste sonundan başa; ilk script (ata/ilk paket) en dışta kalır → B1,B2,orijinal,A2,A1.
    // Aynı (nesne, olay) için tek zincir nesnesi: içteki iptal dıştakinin After'ını da keser.
    for i := LByScript.Count - 1 downto 0 do
      for j := LByScript[i].Count - 1 downto 0 do
      begin
        H := LByScript[i][j];
        LChain := nil;
        for LHook in AAtt.Hooks do
          if (LHook.Instance = H.Instance) and SameText(LHook.PropName, H.Prop) then
          begin
            LChain := LHook.FChain;
            Break;
          end;
        if LChain = nil then
        begin
          LChain := TRadHookChain.Create;
          AAtt.FChains.Add(LChain);
        end;
        LHook := H.HookClass.Create(H.Instance, H.Prop, AAtt.Engine, H.ScriptCode, H.Before, H.After, LChain);
        LHook.OnError := procedure(AHook: TRadHookBase; E: Exception)
          begin
            ReportError(LForm, E);
          end;
        AAtt.Hooks.Add(LHook);
      end;
  finally
    LByScript.Free;
  end;
end;

class function TRadScriptBinder.LoadInto(AOwner: TComponent; AKind: TRadScriptKind;
  const AChain: TArray<string>): TRadScriptAttachment;
var
  LClass: string;
  LScripts, LLibs: TRadScripts;
  S, LCopy: TRadScript;
  LPkgIds: TList<Integer>;
  i: Integer;
  LForm: TCustomForm;
begin
  Result := nil;
  if (FStore = nil) or (AOwner = nil) then Exit;
  if AOwner is TCustomForm then LForm := TCustomForm(AOwner) else LForm := nil;
  Result := TRadScriptAttachment.Create(AOwner);
  try
    LPkgIds := TList<Integer>.Create;
    try
      for LClass in AChain do
      begin
        LScripts := FStore.ScriptsFor(AKind, LClass);
        try
          for S in LScripts do
          begin
            LCopy := TRadScript.Create;
            LCopy.Assign(S);
            Result.Scripts.Add(LCopy);
            if not LPkgIds.Contains(S.PackageId) then LPkgIds.Add(S.PackageId);
          end;
        finally
          LScripts.Free;
        end;
      end;
      if Result.Scripts.Count = 0 then
      begin
        FreeAndNil(Result);
        Exit;
      end;
      LLibs := FStore.LibrariesOf(LPkgIds.ToArray);
      try
        for S in LLibs do
        begin
          LCopy := TRadScript.Create;
          LCopy.Assign(S);
          Result.Libraries.Add(LCopy);
        end;
      finally
        LLibs.Free;
      end;
      Result.Engine.PackageIds := LPkgIds.ToArray;
    finally
      LPkgIds.Free;
    end;
    for S in Result.Libraries do Result.Engine.AddScript(S);
    for S in Result.Scripts do Result.Engine.AddScript(S);
    // Sahibin kendi sınıfı TMS'ye TANITILMAZ: DefineClassByRTTI(TKasaK) yapılınca 'Form.Caption' bile görünmez
    // (Probe P1/P1d). Tanıtılmayınca TMS en yakın kayıtlı ata (TForm) ile bağlar (P1c).
    if LForm <> nil then Result.Engine.Expose('Form', LForm)
    else Result.Engine.Expose('Modul', AOwner);
    for i := 0 to AOwner.ComponentCount - 1 do
      if (AOwner.Components[i].Name <> '') and not (AOwner.Components[i] is TRadScriptAttachment) then
        Result.Engine.ExposeComponent(AOwner.Components[i]);
    if Assigned(FOnInstallFacade) then FOnInstallFacade(Result.Engine);
    try
      Result.Engine.Compile;
    except
      on E: Exception do
      begin
        FreeAndNil(Result);
        ReportError(LForm, E);
        Exit;
      end;
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

class function TRadScriptBinder.Attach(AForm: TCustomForm): TRadScriptAttachment;
var
  S: TRadScript;
begin
  Result := LoadInto(AForm, skForm, ClassChain(AForm));
  if Result = nil then Exit;
  InstallHooks(AForm, Result);
  for S in Result.Scripts do
    if Result.Engine.HasRoutine(S.Code, FORM_AFTER_CREATE) then
      try
        Result.Engine.Call(S.Code, FORM_AFTER_CREATE, [AForm]);
      except
        on E: Exception do ReportError(AForm, E);
      end;
end;

end.
