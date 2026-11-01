unit rad.script.hooks;

(* Kanca katmanı: form sınıfına bağlı script'leri yükler, `<Bileşen>_Before/_After` alt programlarını
   RTTI ile olaylara sarar (Before False → orijinal çalışmaz), form ölünce çözer.
   Wolvox kalıbı + iptal; TMS EventBroker iptal edemediği için kendi sarmalayıcımız (sonda V3). *)

interface

uses
  System.SysUtils, System.Classes, System.TypInfo, System.Rtti, System.Generics.Collections, System.Variants,
  Vcl.Forms,
  rad.script, rad.script.engine;

type
  TRadNotifyHook = class;
  TRadHookErrorEvent = reference to procedure(AHook: TRadNotifyHook; E: Exception);

  /// Aynı olaya sarılan kancaların ortak durumu: içteki Before iptal edince dıştakiler After'ı atlar.
  TRadHookChain = class
  private
    FDepth: Integer;
    FCancelled: Boolean;
  public
    property Cancelled: Boolean read FCancelled write FCancelled;
  end;

  /// Tek nesne parametreli olayı (TNotifyEvent, TDataSetNotifyEvent...) script alt programlarıyla sarar.
  TRadNotifyHook = class
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
    procedure Handler(Sender: TObject);
    procedure Report(E: Exception);
  public
    /// AChain nil ise kanca kendi zincirini kurar (tek kanca).
    constructor Create(AInstance: TObject; const APropName: string; AEngine: TRadScriptEngine;
      const AScriptCode, ABefore, AAfter: string; AChain: TRadHookChain);
    destructor Destroy; override;
    /// Published olay, tek parametre, sınıf türünde, var/out değil, sonuç yok.
    class function CanHook(AInstance: TObject; const APropName: string): Boolean;
    /// Orijinal olayı geri koyar; idempotent.
    procedure Detach;
    property Instance: TObject read FInstance;
    property PropName: string read FPropName;
    property ScriptCode: string read FScriptCode;
    property Before: string read FBefore;
    property After: string read FAfter;
    property OnError: TRadHookErrorEvent read FOnError write FOnError;
  end;

  /// Forma bağlı script motoru + kancalar; Owner form olduğundan formla birlikte yıkılır.
  TRadScriptAttachment = class(TComponent)
  private
    FEngine: TRadScriptEngine;
    FHooks: TObjectList<TRadNotifyHook>;
    FChains: TObjectList<TRadHookChain>;
    FScripts: TRadScripts;
    FLibraries: TRadScripts;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Detach;
    property Engine: TRadScriptEngine read FEngine;
    property Hooks: TObjectList<TRadNotifyHook> read FHooks;
    /// Bağlanan form script'leri, ata sınıf önce.
    property Scripts: TRadScripts read FScripts;
    property Libraries: TRadScripts read FLibraries;
  end;

  TRadScriptErrorEvent = reference to procedure(AForm: TCustomForm; E: Exception);
  TRadScriptWarningEvent = reference to procedure(const AMessage: string);

  TRadScriptBinder = class
  private
    class var FStore: IRadScriptStore;
    class var FOnError: TRadScriptErrorEvent;
    class var FOnWarning: TRadScriptWarningEvent;
    class function ClassChain(AForm: TCustomForm): TArray<string>;
    class function PrimaryEvent(AInstance: TObject): string;
    class function ResolveTarget(AForm: TCustomForm; const ABase: string; out AInstance: TObject;
      out AProp: string): Boolean;
    class procedure InstallHooks(AForm: TCustomForm; AAtt: TRadScriptAttachment);
    class procedure Warn(const AMsg: string);
  public
    /// Bir kez atanır; nil ise Attach hiçbir şey yapmaz.
    class property Store: IRadScriptStore read FStore write FStore;
    /// Derleme ve çalışma hataları; nil → Application.ShowException.
    class property OnError: TRadScriptErrorEvent read FOnError write FOnError;
    /// Kurulamayan kanca, bulunamayan bileşen.
    class property OnWarning: TRadScriptWarningEvent read FOnWarning write FOnWarning;
    /// Form sınıfı ve ataları için script varsa yükler, derler, kancaları kurar, Form_AfterCreate'i çağırır.
    /// Script yoksa veya derleme hatasıysa (OnError) nil.
    class function Attach(AForm: TCustomForm): TRadScriptAttachment;
    class function AttachmentOf(AForm: TCustomForm): TRadScriptAttachment;
  end;

implementation

resourcestring
  SWarnNoComponent = '%s: "%s" adlı bileşen/olay bulunamadı; "%s" kancası kurulmadı.';
  SWarnCannotHook = '%s: "%s.%s" olayı sarılamaz (tek nesne parametreli olmalı); "%s" kancası kurulmadı.';

const
  SUFFIX_BEFORE = '_before';
  SUFFIX_AFTER = '_after';
  FORM_ALIAS = 'form';
  FORM_AFTER_CREATE = 'Form_AfterCreate';

{ TRadNotifyHook }

constructor TRadNotifyHook.Create(AInstance: TObject; const APropName: string; AEngine: TRadScriptEngine;
  const AScriptCode, ABefore, AAfter: string; AChain: TRadHookChain);
var
  M: TMethod;
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
  M.Code := @TRadNotifyHook.Handler;
  M.Data := Self;
  SetMethodProp(AInstance, APropName, M);
  FAttached := True;
end;

destructor TRadNotifyHook.Destroy;
begin
  Detach;
  if FOwnChain then FChain.Free;
  inherited;
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

procedure TRadNotifyHook.Detach;
begin
  if not FAttached then Exit;
  FAttached := False;
  SetMethodProp(FInstance, FPropName, FOriginal);
end;

procedure TRadNotifyHook.Report(E: Exception);
begin
  if Assigned(FOnError) then FOnError(Self, E)
  else raise E;
end;

procedure TRadNotifyHook.Handler(Sender: TObject);
var
  LGo: Boolean;
  V: Variant;
begin
  if FChain.FDepth = 0 then FChain.FCancelled := False;   // en dış kanca zinciri sıfırlar
  Inc(FChain.FDepth);
  try
    LGo := True;
    if FBefore <> '' then
      try
        V := FEngine.Call(FScriptCode, FBefore, [Sender]);
        // Yalnız açık False iptal eder; procedure (Empty) ve Null geçer.
        LGo := not (VarIsType(V, varBoolean) and not Boolean(V));
      except
        on E: Exception do
        begin
          LGo := False;   // emniyetli taraf: hata = iptal
          Report(E);
        end;
      end;
    if not LGo then
    begin
      FChain.FCancelled := True;
      Exit;
    end;
    if Assigned(FOriginal.Code) then
      TNotifyEvent(FOriginal)(Sender);   // içteki kanca ya da gerçek olay
    if FChain.FCancelled then Exit;      // içteki Before iptal etti: After yok
    if FAfter <> '' then
      try
        FEngine.Call(FScriptCode, FAfter, [Sender]);
      except
        on E: Exception do Report(E);   // kayıt yapıldı, geri alınmaz (kullanıcı kararı)
      end;
  finally
    Dec(FChain.FDepth);
  end;
end;

{ TRadScriptAttachment }

constructor TRadScriptAttachment.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEngine := TRadScriptEngine.Create;
  FHooks := TObjectList<TRadNotifyHook>.Create(True);
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

class procedure TRadScriptBinder.Warn(const AMsg: string);
begin
  if Assigned(FOnWarning) then FOnWarning(AMsg);
end;

class function TRadScriptBinder.ClassChain(AForm: TCustomForm): TArray<string>;
var
  C: TClass;
  L: TList<string>;
begin
  L := TList<string>.Create;
  try
    C := AForm.ClassType;
    while (C <> nil) and (C <> TCustomForm) and (C <> TForm) do
    begin
      L.Insert(0, C.ClassName);   // ata önce
      C := C.ClassParent;
    end;
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

class function TRadScriptBinder.AttachmentOf(AForm: TCustomForm): TRadScriptAttachment;
var
  i: Integer;
begin
  for i := 0 to AForm.ComponentCount - 1 do
    if AForm.Components[i] is TRadScriptAttachment then
      Exit(TRadScriptAttachment(AForm.Components[i]));
  Result := nil;
end;

class function TRadScriptBinder.PrimaryEvent(AInstance: TObject): string;
begin
  if AInstance is TBasicAction then Result := 'OnExecute'
  else if IsPublishedProp(AInstance, 'OnClick') then Result := 'OnClick'
  else Result := '';
end;

class function TRadScriptBinder.ResolveTarget(AForm: TCustomForm; const ABase: string; out AInstance: TObject;
  out AProp: string): Boolean;
var
  P: Integer;
  LCompName, LEvent: string;
  LComp: TComponent;
begin
  // 1) "<Bileşen>" → ana olay
  if SameText(ABase, FORM_ALIAS) then LComp := AForm else LComp := AForm.FindComponent(ABase);
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
  if SameText(LCompName, FORM_ALIAS) then LComp := AForm else LComp := AForm.FindComponent(LCompName);
  if (LComp = nil) or not IsPublishedProp(LComp, LEvent) then Exit(False);
  AInstance := LComp;
  AProp := LEvent;
  Result := True;
end;

type
  TPendingHook = record
    Instance: TObject;
    Prop: string;
    ScriptCode: string;
    Before, After: string;
  end;

class procedure TRadScriptBinder.InstallHooks(AForm: TCustomForm; AAtt: TRadScriptAttachment);
var
  LPending: TList<TPendingHook>;
  LByScript: TObjectList<TList<TPendingHook>>;
  LNames: TArray<string>;
  LName, LLower, LBase, LProp: string;
  LIsBefore: Boolean;
  LInst: TObject;
  i, j, k: Integer;
  H: TPendingHook;
  LHook: TRadNotifyHook;
  LChain: TRadHookChain;
  LFormName: string;
  LScript: TRadScript;
begin
  LFormName := AForm.ClassName;
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
      if not ResolveTarget(AForm, LBase, LInst, LProp) then
      begin
        Warn(Format(SWarnNoComponent, [LFormName, LBase, LName]));
        Continue;
      end;
      if not TRadNotifyHook.CanHook(LInst, LProp) then
      begin
        Warn(Format(SWarnCannotHook, [LFormName, TComponent(LInst).Name, LProp, LName]));
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
        LHook := TRadNotifyHook.Create(H.Instance, H.Prop, AAtt.Engine, H.ScriptCode, H.Before, H.After, LChain);
        LHook.OnError := procedure(AHook: TRadNotifyHook; E: Exception)
          begin
            if Assigned(FOnError) then FOnError(AForm, E)
            else Application.ShowException(E);
          end;
        AAtt.Hooks.Add(LHook);
      end;
  finally
    LByScript.Free;
  end;
end;

class function TRadScriptBinder.Attach(AForm: TCustomForm): TRadScriptAttachment;
var
  LChain: TArray<string>;
  LClass: string;
  LScripts: TRadScripts;
  S, LCopy: TRadScript;
  LPkgIds: TList<Integer>;
  LLibs: TRadScripts;
  i: Integer;
begin
  Result := nil;
  if (FStore = nil) or (AForm = nil) then Exit;
  Result := TRadScriptAttachment.Create(AForm);
  try
    LChain := ClassChain(AForm);
    LPkgIds := TList<Integer>.Create;
    try
      for LClass in LChain do
      begin
        LScripts := FStore.ScriptsFor(skForm, LClass);
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
    finally
      LPkgIds.Free;
    end;
    for S in Result.Libraries do Result.Engine.AddScript(S);
    for S in Result.Scripts do Result.Engine.AddScript(S);
    // Formun kendi sınıfı TMS'ye TANITILMAZ: DefineClassByRTTI(TKasaK) yapılınca 'Form.Caption' bile görünmez
    // (Probe P1/P1d; Ancestor ataması da işe yaramadı). Tanıtılmayınca TMS en yakın kayıtlı ata (TForm) ile bağlar
    // (P1c). Bedeli: formun kendi public metotları script'ten çağrılamaz; bileşenler adlarıyla açık.
    Result.Engine.Expose('Form', AForm);
    for i := 0 to AForm.ComponentCount - 1 do
      if (AForm.Components[i].Name <> '') and not (AForm.Components[i] is TRadScriptAttachment) then
        Result.Engine.ExposeComponent(AForm.Components[i]);
    try
      Result.Engine.Compile;
    except
      on E: Exception do
      begin
        FreeAndNil(Result);
        if Assigned(FOnError) then FOnError(AForm, E)
        else Application.ShowException(E);
        Exit;
      end;
    end;
    InstallHooks(AForm, Result);
    for S in Result.Scripts do
      if Result.Engine.HasRoutine(S.Code, FORM_AFTER_CREATE) then
        try
          Result.Engine.Call(S.Code, FORM_AFTER_CREATE, [AForm]);
        except
          on E: Exception do
            if Assigned(FOnError) then FOnError(AForm, E)
            else Application.ShowException(E);
        end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

end.
