unit rad.script.ide;

(* Script sistemi 6. aşama: TMS Scripter IDE'si (TIDEDialog) paketin üstünde. Paket = proje, script = sanal
   dosya (OnCheckValidFile/OnLoadFile/OnSaveFile ile DB'den okunur, DB'ye yazılır; diske dokunulmaz).
   IDE'nin scripter'ı TRadScriptEngine.CreateFor ile sarılır: aynı sınıf kayıtları, form zinciri, facade.
   Bkz. docs/specs/rad.script.ide.md *)

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Vcl.Forms, Vcl.Menus, Vcl.ActnList, Vcl.Dialogs, Vcl.Controls,
  atScript, atScripter, idemain, IDEDialog, fIDEEditor,
  rad.script, rad.script.engine, rad.script.hooks, rad.script.jobs, rad.script.facade, rad.script.design;

type
  /// Tek etkin IDE (Active). Open açar; IDE penceresi kapanınca nesne kendini serbest bırakır.
  TRadScriptIde = class(TComponent)
  private
    class var FActive: TRadScriptIde;
  private
    FPackage: TRadScriptPackage;
    FStore: IRadScriptStore;
    FContext: TRadScriptContext;
    FIdeEngine: TIDEEngine;
    FScripter: TIDEScripter;
    FEngine: TRadScriptEngine;
    FDialog: TIDEDialog;
    FIdeForm: TForm;
    FEvent: TRadScriptEvent;
    FPendingEvents: TDictionary<string, TArray<string>>;   // kod → DFM'den sökülen olaylar (SaveEvents'e)
    FTestChannel: string;
    FTestJson: string;
    FLiveConfirmed: Boolean;
    FClosing: Boolean;
    FOnSaved: TProc<TRadScriptPackage>;
    FOnMessage: TProc<string>;
    procedure CheckValidFile(Sender: TObject; AType: TIDEFileType; AFileName: string; var AValid: Boolean);
    procedure LoadFile(Sender: TObject; AType: TIDEFileType; AFileName: string; var AContent: string;
      AFile: TIDEProjectFile; var AHandled: Boolean);
    procedure SaveFile(Sender: TObject; AType: TIDEFileType; AFileName: string; AContent: string;
      AFile: TIDEProjectFile; var AHandled: Boolean);
    procedure OpenDialog(Sender: TObject; AType: TIDEFileType; var AFileName: string; var AResultOk, AHandled: Boolean);
    procedure SaveDialog(Sender: TObject; AType: TIDEFileType; var AFileName: string; AFile: TIDEProjectFile;
      var AResultOk, AHandled: Boolean);
    procedure ConfirmSave(Sender: TObject; AType: TIDEFileType; AFileName: string; AFile: TIDEProjectFile;
      var AAction: TIDEConfirmSaveType; var AHandled: Boolean);
    procedure CreateIdeForm(Sender: TObject);
    procedure ActiveFileChanged(Sender: TObject);
    procedure MenuTestEventClick(Sender: TObject);
    procedure MenuRunTestClick(Sender: TObject);
    function CodeOfFileName(const AFileName: string): string;
    function ScriptOfFile(AFile: TIDEProjectFile): TRadScript;
    function WindowDfmOf(AScript: TRadScript; const ADfm: string): string;
    procedure Setup(const AScriptCode: string);
    procedure Say(const AMsg: string);
    function ConfirmLive: Boolean;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    destructor Destroy; override;
    /// Paketi IDE'de açar (sahiplik çağıranda kalır), AScriptCode etkin dosya olur. Korumalı paket reddedilir;
    /// tasarımcı açıkken reddedilir. AContext nil → facade yok (Db/Msg çözülmez).
    class function Open(APackage: TRadScriptPackage; const AScriptCode: string; AContext: TRadScriptContext): TRadScriptIde; static;
    class property Active: TRadScriptIde read FActive;
    /// Etkin script: `olay/zaman` → derle + `Calistir(Olay)` deneme olayıyla; `kutuphane/pencere` → IDE'nin Run'ı
    /// (ana blok); `form/komut` → yalnız mesaj (canlı form/modül gerekir). Hatalar OnMessage'a.
    procedure RunTest;
    /// Tüm proje dosyalarını kaydeder (DB'ye).
    procedure SaveAll;
    /// Kaydedilmemiş değişiklik sorulmadan atılır (önce SaveAll çağrılır istenirse).
    procedure Close;
    property Package: TRadScriptPackage read FPackage;
    property IdeEngine: TIDEEngine read FIdeEngine;
    property Engine: TRadScriptEngine read FEngine;
    property IdeForm: TForm read FIdeForm;
    /// Deneme olayının kanalı ve JSON'u (`Olay.Channel/Json`).
    property TestChannel: string read FTestChannel write FTestChannel;
    property TestJson: string read FTestJson write FTestJson;
    /// Deneme çalıştırmasında "şirket DB'sinde çalışacak" onayı; test True verir.
    property LiveConfirmed: Boolean read FLiveConfirmed write FLiveConfirmed;
    property OnSaved: TProc<TRadScriptPackage> read FOnSaved write FOnSaved;
    property OnMessage: TProc<string> read FOnMessage write FOnMessage;
  end;

implementation

uses
  System.StrUtils, System.UITypes;

resourcestring
  SErrNoStore = 'TRadScriptBinder.Store atanmadan IDE açılamaz.';
  SErrActive = 'Zaten açık bir IDE var.';
  SErrDesigner = 'Tasarım oturumu açıkken IDE açılamaz.';
  SErrProtected = 'Korumalı paket IDE''de açılamaz: %s';
  SErrNoPackage = 'Paket verilmedi.';
  SMsgNoOpen = 'Script''ler paket yöneticisinden eklenir; IDE''den dosya açılmaz.';
  SMsgNoRename = 'Script adı paket yöneticisinden değiştirilir.';
  SConfirmSave = '"%s" değişti. Kaydedilsin mi?';
  SConfirmLive = 'Deneme çalıştırması şirket veritabanında (%s) çalışacak. Devam?';
  SMsgFormScript = '%s: form/komut script''i IDE''de çalıştırılamaz (canlı form gerekir); yalnız derlendi.';
  SMsgRunOk = '%s çalıştı.';
  SMsgNoActive = 'Etkin script yok.';
  SMsgSaved = 'Kaydedildi: %s';
  STitle = 'Script IDE — %s [%s, canlı veritabanı]';
  SMenuTest = 'Deneme';
  SMenuTestEvent = 'Deneme olayı...';
  SMenuRunTest = 'Calistir(Olay) çalıştır';
  SPromptChannel = 'Kanal';
  SPromptJson = 'JSON';

const
  EXT_UNIT = '.pas';
  EXT_FORM = '.dfm';
  ROUTINE_RUN = 'Calistir';

{ TRadScriptIde }

class function TRadScriptIde.Open(APackage: TRadScriptPackage; const AScriptCode: string;
  AContext: TRadScriptContext): TRadScriptIde;
begin
  if TRadScriptBinder.Store = nil then raise ERadScript.Create(SErrNoStore);
  if APackage = nil then raise ERadScript.Create(SErrNoPackage);
  if FActive <> nil then raise ERadScript.Create(SErrActive);
  if TRadScriptDesigner.Active <> nil then raise ERadScript.Create(SErrDesigner);
  if APackage.IsProtected then raise ERadScript.CreateFmt(SErrProtected, [APackage.Code]);
  Result := TRadScriptIde.Create(nil);
  try
    Result.FPackage := APackage;
    Result.FStore := TRadScriptBinder.Store;
    Result.FContext := AContext;
    Result.Setup(AScriptCode);
  except
    Result.Free;
    raise;
  end;
end;

destructor TRadScriptIde.Destroy;
begin
  FClosing := True;
  if FActive = Self then FActive := nil;
  FreeAndNil(FDialog);
  FreeAndNil(FEngine);        // scripter'ı sahiplenmez
  FreeAndNil(FIdeEngine);
  FreeAndNil(FScripter);
  FEvent.Free;
  FPendingEvents.Free;
  inherited;
end;

procedure TRadScriptIde.Say(const AMsg: string);
begin
  if Assigned(FOnMessage) then FOnMessage(AMsg)
  else if Assigned(TRadScriptBinder.OnWarning) then TRadScriptBinder.OnWarning(AMsg);
end;

procedure TRadScriptIde.Setup(const AScriptCode: string);
var
  S: TRadScript;
  LFile, LMain: TIDEProjectFile;
  LIntf: IScriptBasedForm;
  LEvents: TArray<string>;
  E: string;
begin
  FActive := Self;
  FPendingEvents := TDictionary<string, TArray<string>>.Create;
  FScripter := TIDEScripter.Create(Self);
  FIdeEngine := TIDEEngine.Create(Self);
  FIdeEngine.Scripter := FScripter;
  FIdeEngine.AutoUsesClauseOnSave := False;   // uses satırını script yazarı yönetir
  FIdeEngine.PreventDefaultEventCreation := False;
  FIdeEngine.OnCheckValidFile := CheckValidFile;
  FIdeEngine.OnLoadFile := LoadFile;
  FIdeEngine.OnSaveFile := SaveFile;
  FIdeEngine.OnOpenDialog := OpenDialog;
  FIdeEngine.OnSaveDialog := SaveDialog;
  FIdeEngine.OnConfirmSaveFile := ConfirmSave;
  FIdeEngine.OnActiveFileChanged := ActiveFileChanged;
  // IDE scripter'ı bizim dünyayı görür: sınıflar, form zinciri, VCL metotları, pencere sınıfı, facade.
  FEngine := TRadScriptEngine.CreateFor(FScripter);
  FEngine.PackageIds := [FPackage.Id];
  FEvent := TRadScriptEvent.Create;
  FEngine.Expose('Olay', FEvent);
  if FContext <> nil then TRadScriptFacade.Install(FEngine, FContext);
  TRadScriptDesigner.RegisterPaletteInto(FIdeEngine);
  FIdeEngine.NewProject;
  FIdeEngine.ProjectName := FPackage.Code;
  LMain := nil;
  for S in FPackage.Scripts do
  begin
    LFile := FIdeEngine.OpenFile(S.Code + EXT_UNIT);
    if LFile = nil then Continue;
    FEngine.AdoptScript(LFile.Script, S.Code);
    if (S.Kind = skWindow) and (LFile.Form <> nil) and FPendingEvents.TryGetValue(S.Code, LEvents) and
       Supports(LFile.Form, IScriptBasedForm, LIntf) then
      for E in LEvents do
        if LIntf.GetSaveEvents.IndexOfName(Copy(E, 1, Pos('=', E) - 1)) < 0 then LIntf.GetSaveEvents.Add(E);
    if SameText(S.Code, AScriptCode) then LMain := LFile;
  end;
  if LMain = nil then
    for S in FPackage.Scripts do
      if S.Kind in [skLibrary, skWindow] then
      begin
        LMain := FIdeEngine.OpenFile(S.Code + EXT_UNIT);
        Break;
      end;
  if LMain <> nil then
  begin
    FIdeEngine.MainUnit := LMain;
    FIdeEngine.ActiveFile := LMain;
  end;
  FDialog := TIDEDialog.Create(Self);
  FDialog.Engine := FIdeEngine;
  FDialog.IDECloseAction := icaCloseAll;
  if FContext <> nil then FDialog.Title := Format(STitle, [FPackage.Name, FContext.CompanyName])
  else FDialog.Title := Format(STitle, [FPackage.Name, '-']);
  FDialog.OnCreateIDEForm := CreateIdeForm;
  FDialog.Show;
end;

function TRadScriptIde.CodeOfFileName(const AFileName: string): string;
begin
  Result := ChangeFileExt(ExtractFileName(AFileName), '');
end;

function TRadScriptIde.ScriptOfFile(AFile: TIDEProjectFile): TRadScript;
begin
  if AFile = nil then Exit(nil);
  Result := FPackage.ScriptByCode(AFile.UnitName);
end;

procedure TRadScriptIde.CheckValidFile(Sender: TObject; AType: TIDEFileType; AFileName: string; var AValid: Boolean);
var
  S: TRadScript;
begin
  S := FPackage.ScriptByCode(CodeOfFileName(AFileName));
  case AType of
    iftScript: AValid := S <> nil;
    iftForm: AValid := (S <> nil) and (S.Kind = skWindow);
  else
    AValid := False;
  end;
end;

procedure TRadScriptIde.LoadFile(Sender: TObject; AType: TIDEFileType; AFileName: string; var AContent: string;
  AFile: TIDEProjectFile; var AHandled: Boolean);
var
  S: TRadScript;
  R: TRadScriptResource;
begin
  S := FPackage.ScriptByCode(CodeOfFileName(AFileName));
  if S = nil then Exit;
  AHandled := True;
  case AType of
    iftScript: AContent := S.Source;
    iftForm:
      begin
        R := FPackage.ResourceByName(S.DfmFileName);
        if R = nil then AContent := Format('object %sForm: T%sForm'#13#10'end'#13#10, [S.Code, S.Code])
        else AContent := TEncoding.UTF8.GetString(R.Content);
        FPendingEvents.AddOrSetValue(S.Code, TRadScriptDesigner.ExtractDfmEvents(AContent));
        if AFile.Script <> nil then AFile.Script.DesignFormResource := AContent;   // derleme dosya aramasın
      end;
  else
    AHandled := False;
  end;
end;

function TRadScriptIde.WindowDfmOf(AScript: TRadScript; const ADfm: string): string;
var
  P1, P2: Integer;
begin
  // IDE kök sınıfı kendi Delphi sınıfıyla yazar; script'in bildirdiği ad konur.
  Result := ADfm;
  P1 := Pos(': ', Result);
  P2 := Pos(#13, Result);
  if (P1 > 0) and (P2 > P1) then
    Result := Copy(Result, 1, P1 + 1) + 'T' + AScript.Code + 'Form' + Copy(Result, P2, MaxInt);
end;

procedure TRadScriptIde.SaveFile(Sender: TObject; AType: TIDEFileType; AFileName: string; AContent: string;
  AFile: TIDEProjectFile; var AHandled: Boolean);
var
  S: TRadScript;
  R: TRadScriptResource;
  LDfm: string;
begin
  S := FPackage.ScriptByCode(CodeOfFileName(AFileName));
  if S = nil then Exit;
  AHandled := True;
  case AType of
    iftScript:
      begin
        S.Source := AContent;
        if S.Kind = skWindow then Exit;   // DFM kaydı hemen arkadan gelir; paket o zaman yazılır
      end;
    iftForm:
      begin
        LDfm := WindowDfmOf(S, AContent);
        R := FPackage.ResourceByName(S.DfmFileName);
        if R = nil then FPackage.AddResource(S.DfmFileName, TEncoding.UTF8.GetBytes(LDfm))
        else R.Content := TEncoding.UTF8.GetBytes(LDfm);
        if AFile.Script <> nil then AFile.Script.DesignFormResource := LDfm;
      end;
  else
    AHandled := False;
    Exit;
  end;
  FStore.SavePackage(FPackage);
  if Assigned(FOnSaved) then FOnSaved(FPackage);
  Say(Format(SMsgSaved, [S.Code]));
end;

procedure TRadScriptIde.OpenDialog(Sender: TObject; AType: TIDEFileType; var AFileName: string;
  var AResultOk, AHandled: Boolean);
begin
  AHandled := True;
  AResultOk := False;
  Say(SMsgNoOpen);
end;

procedure TRadScriptIde.SaveDialog(Sender: TObject; AType: TIDEFileType; var AFileName: string;
  AFile: TIDEProjectFile; var AResultOk, AHandled: Boolean);
begin
  AHandled := True;
  AResultOk := False;
  Say(SMsgNoRename);
end;

procedure TRadScriptIde.ConfirmSave(Sender: TObject; AType: TIDEFileType; AFileName: string;
  AFile: TIDEProjectFile; var AAction: TIDEConfirmSaveType; var AHandled: Boolean);
begin
  AHandled := True;
  if FClosing then
  begin
    AAction := cstDontSave;   // programatik Close: host karar verdi, soru yok (pencere X'i yine sorar)
    Exit;
  end;
  case MessageDlg(Format(SConfirmSave, [CodeOfFileName(AFileName)]), mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
    mrYes: AAction := cstSave;
    mrNo: AAction := cstDontSave;
  else
    AAction := cstCancel;
  end;
end;

procedure TRadScriptIde.CreateIdeForm(Sender: TObject);
var
  LForm: TIDEEditorForm;
  LMenu, LItem: TMenuItem;
begin
  LForm := Sender as TIDEEditorForm;
  FIdeForm := LForm;
  LForm.FreeNotification(Self);
  // TMS'nin kendi formuna tek menü: deneme olayı ve Calistir(Olay).
  LMenu := TMenuItem.Create(LForm);
  LMenu.Caption := SMenuTest;
  LForm.MainMenu1.Items.Add(LMenu);
  LItem := TMenuItem.Create(LForm);
  LItem.Caption := SMenuTestEvent;
  LItem.OnClick := MenuTestEventClick;
  LMenu.Add(LItem);
  LItem := TMenuItem.Create(LForm);
  LItem.Caption := SMenuRunTest;
  LItem.OnClick := MenuRunTestClick;
  LMenu.Add(LItem);
  ActiveFileChanged(nil);
end;

procedure TRadScriptIde.ActiveFileChanged(Sender: TObject);
var
  S: TRadScript;
  i: Integer;
  LRunnable: Boolean;
begin
  // form/komut script'i IDE'de çalıştırılamaz: TMS'nin Run/adım eylemleri adına göre kapatılır (en iyi çaba).
  if FIdeForm = nil then Exit;
  S := ScriptOfFile(FIdeEngine.ActiveFile);
  LRunnable := (S = nil) or not (S.Kind in [skForm, skCommand]);
  for i := 0 to FIdeForm.ComponentCount - 1 do
    if (FIdeForm.Components[i] is TAction) and
       (ContainsText(FIdeForm.Components[i].Name, 'Run') or ContainsText(FIdeForm.Components[i].Name, 'Step') or
        ContainsText(FIdeForm.Components[i].Name, 'Trace')) then
      TAction(FIdeForm.Components[i]).Enabled := LRunnable;
end;

procedure TRadScriptIde.MenuTestEventClick(Sender: TObject);
var
  LChannel, LJson: string;
begin
  LChannel := FTestChannel;
  LJson := FTestJson;
  if InputQuery(SMenuTestEvent, SPromptChannel, LChannel) and InputQuery(SMenuTestEvent, SPromptJson, LJson) then
  begin
    FTestChannel := LChannel;
    FTestJson := LJson;
  end;
end;

procedure TRadScriptIde.MenuRunTestClick(Sender: TObject);
begin
  RunTest;
end;

function TRadScriptIde.ConfirmLive: Boolean;
var
  LName: string;
begin
  if FLiveConfirmed or (FContext = nil) then Exit(True);
  LName := FContext.CompanyName;
  if LName = '' then LName := '?';
  Result := MessageDlg(Format(SConfirmLive, [LName]), mtWarning, [mbYes, mbNo], 0) = mrYes;
  FLiveConfirmed := Result;
end;

procedure TRadScriptIde.RunTest;
var
  S: TRadScript;
  LFile: TIDEProjectFile;
begin
  LFile := FIdeEngine.ActiveFile;
  S := ScriptOfFile(LFile);
  if S = nil then
  begin
    Say(SMsgNoActive);
    Exit;
  end;
  if not ConfirmLive then Exit;
  try
    // IDE'nin Run'ı editördeki kaynağı script'e yazar, derler (hata listesiyle) ve ana bloğu koşar.
    FIdeEngine.RunScript(rmActiveUnit);
    if S.Kind in [skForm, skCommand] then
    begin
      Say(Format(SMsgFormScript, [S.Code]));
      Exit;
    end;
    if S.Kind in [skEvent, skSchedule] then
    begin
      FEvent.Fill(FTestChannel, FTestJson, FPackage.Code, S.Code);
      if FEngine.HasRoutine(S.Code, ROUTINE_RUN) then FEngine.Call(S.Code, ROUTINE_RUN, [FEvent]);
    end;
    Say(Format(SMsgRunOk, [S.Code]));
  except
    on E: Exception do Say(E.Message);
  end;
end;

procedure TRadScriptIde.SaveAll;
var
  i: Integer;
begin
  for i := 0 to FIdeEngine.Files.Count - 1 do
    TIDEProjectFile(FIdeEngine.Files.Items[i]).Save;   // SaveFile motorda private; dosya kendi kaydeder
end;

procedure TRadScriptIde.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FIdeForm) then
  begin
    FIdeForm := nil;
    if not FClosing then TThread.ForceQueue(nil, procedure begin Close; end);   // IDE formu kendini yıkıyor
  end;
end;

procedure TRadScriptIde.Close;
begin
  if FClosing then Exit;
  FClosing := True;
  if FIdeForm <> nil then
  begin
    FIdeForm.RemoveFreeNotification(Self);
    FIdeForm.Close;   // DestroyOnClose: TMS formu kendini serbest bırakır
    FIdeForm := nil;
  end;
  Free;
end;

end.
