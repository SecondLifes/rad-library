program SpikeVcl;

(* TMS Scripter 8.1 VCL sondasi: DevExpress/rad siniflarinin RTTI kaydi, olay kesme
   (EventBroker epTopCall/epBottomCall vs kendi RTTI sarmalayicimiz + iptal),
   DevExpress olay tipi icin adaptor, DFM'den script formu, IDE/editor bilesenlerinin
   ayaga kalkmasi, kancali olay hizi. *)

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Variants, System.Diagnostics, System.TypInfo,
  System.Actions, Vcl.Forms, Vcl.Controls, Vcl.ActnList, Vcl.StdCtrls, Data.DB,
  cxEdit, cxTextEdit, cxDBEdit, cxButtons, cxGrid, cxGridLevel, cxGridTableView, cxGridDBTableView, cxGridCustomTableView,
  cxGridCustomView, cxCustomData, cxControls, cxGraphics, cxLookAndFeels, cxLookAndFeelPainters, cxContainer,
  dxLayoutControl, dxLayoutContainer,
  Uni, rad.db,
  atScript, atPascal, ap_Classes, ap_Controls, ap_Forms, ap_StdCtrls, ap_ActnList,
  Vcl.ScripterInit, Vcl.ScriptForm, IDEDialog, idemain, ScrMemo, ScrMps;

type
  TLogger = class
  private
    FLines: TStringList;
    FAllow: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const S: string);
    procedure Fail(const S: string);
    function Text: string;
    procedure Clear;
    property AllowSave: Boolean read FAllow write FAllow;
  end;

  THost = class
  public
    Log: TLogger;
    procedure ActionExec(Sender: TObject);
    procedure ButtonClick(Sender: TObject);
    procedure EditValidate(Sender: TObject; var DisplayValue: Variant; var ErrorText: TCaption; var Error: Boolean);
  end;

  /// Kendi kancamiz (Wolvox kalibi): orijinal TNotifyEvent saklanir, Before(Sender): boolean iptal edebilir.
  TRadNotifyHook = class
  private
    FInstance: TObject;
    FProp: string;
    FOriginal: TNotifyEvent;
    FScripter: TatCustomScripter;
    FBefore, FAfter: string;
    procedure Handler(Sender: TObject);
  public
    constructor Create(AInstance: TObject; const AProp: string; AScripter: TatCustomScripter; const ABefore, AAfter: string);
    procedure Detach;
  end;

  /// DevExpress olay tipi adaptoru (TcxEditValidateEvent: var parametreli).
  TRadCxDispatcher = class(TatEventDispatcher)
  private
    procedure _TcxEditValidateEvent(Sender: TObject; var DisplayValue: Variant; var ErrorText: TCaption; var Error: Boolean);
  end;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;

procedure Kontrol(const AAd: string; ABasarili: Boolean; const ADetay: string = '');
begin
  if ABasarili then
  begin
    Inc(GBasari);
    Writeln('  [OK]   ', AAd);
  end
  else
  begin
    Inc(GHata);
    Writeln('  [HATA] ', AAd, '  ', ADetay);
  end;
end;

procedure Olcum(const AAd, ADeger: string);
begin
  Writeln('  [OLCUM] ', AAd, ' = ', ADeger);
end;

{ TLogger }

constructor TLogger.Create;
begin
  inherited;
  FLines := TStringList.Create;
  FAllow := True;
end;

destructor TLogger.Destroy;
begin
  FLines.Free;
  inherited;
end;

procedure TLogger.Add(const S: string);
begin
  FLines.Add(S);
end;

procedure TLogger.Fail(const S: string);
begin
  raise Exception.Create(S);
end;

function TLogger.Text: string;
begin
  Result := string.Join(',', FLines.ToStringArray);
end;

procedure TLogger.Clear;
begin
  FLines.Clear;
end;

{ THost }

procedure THost.ActionExec(Sender: TObject);
begin
  Log.Add('delphi-exec');
end;

procedure THost.ButtonClick(Sender: TObject);
begin
  Log.Add('delphi-click');
end;

procedure THost.EditValidate(Sender: TObject; var DisplayValue: Variant; var ErrorText: TCaption; var Error: Boolean);
begin
  Log.Add('delphi-validate:' + VarToStr(DisplayValue));
end;

{ TRadNotifyHook }

constructor TRadNotifyHook.Create(AInstance: TObject; const AProp: string; AScripter: TatCustomScripter;
  const ABefore, AAfter: string);
var
  M: TMethod;
begin
  inherited Create;
  FInstance := AInstance;
  FProp := AProp;
  FScripter := AScripter;
  FBefore := ABefore;
  FAfter := AAfter;
  FOriginal := TNotifyEvent(GetMethodProp(AInstance, AProp));
  M.Code := @TRadNotifyHook.Handler;
  M.Data := Self;
  SetMethodProp(AInstance, AProp, M);
end;

procedure TRadNotifyHook.Detach;
begin
  SetMethodProp(FInstance, FProp, TMethod(FOriginal));
end;

procedure TRadNotifyHook.Handler(Sender: TObject);
var
  LGo: Variant;
begin
  LGo := True;
  if FBefore <> '' then
    LGo := FScripter.ExecuteSubroutineAsVariant(FBefore, [Integer(Pointer(Sender))]);
  if VarIsNull(LGo) or VarIsEmpty(LGo) or Boolean(LGo) then
  begin
    if Assigned(FOriginal) then FOriginal(Sender);
    if FAfter <> '' then
      FScripter.ExecuteSubroutineAsVariant(FAfter, [Integer(Pointer(Sender))]);
  end;
end;

{ TRadCxDispatcher }

procedure TRadCxDispatcher._TcxEditValidateEvent(Sender: TObject; var DisplayValue: Variant;
  var ErrorText: TCaption; var Error: Boolean);
begin
  if DoOnExecuteEvent then
  begin
    if AssignedMethod(BeforeCall) then
      TcxEditValidateEvent(BeforeCall)(Sender, DisplayValue, ErrorText, Error);
    if Assigned(Scripter) and (RoutineName > '') then
      Scripter.ExecuteSubroutine(RoutineName, VarArrayOf([Integer(Pointer(Sender)), DisplayValue, ErrorText, Error]));
    if AssignedMethod(AfterCall) then
      TcxEditValidateEvent(AfterCall)(Sender, DisplayValue, ErrorText, Error);
  end;
end;

function MemberCount(AScripter: TatCustomScripter; const AClassName: string): string;
var
  C: TatClass;
begin
  C := AScripter.Classes.ClassByName(AClassName);
  if C = nil then Exit('(kayitli degil)');
  Result := Format('%d metot, %d ozellik', [C.Methods.Count, C.Properties.Count]);
end;

var
  S: TatPascalScripter;
  Host: THost;
  Form: TForm;
  AL: TActionList;
  Act: TAction;
  Btn: TcxButton;
  Edit: TcxTextEdit;
  Grid: TcxGrid;
  LC: TdxLayoutControl;
  Q: TRadQuery;
  Hook: TRadNotifyHook;
  SW: TStopwatch;
  i: Integer;
  V: Variant;
  LTxt: TCaption;
  LErr: Boolean;
  LDlg: TIDEDialog;
  LEng: TIDEEngine;
  LMemo: TScrMemo;
  LStyler: TScrPascalMemoStyler;
begin
  Host := THost.Create;
  Host.Log := TLogger.Create;
  Form := TForm.CreateNew(nil);
  S := TatPascalScripter.Create(nil);
  try
    try
      AL := TActionList.Create(Form);
      Act := TAction.Create(AL);
      Act.ActionList := AL;
      Act.Name := 'actKaydet';
      Act.OnExecute := Host.ActionExec;
      Btn := TcxButton.Create(Form);
      Btn.Parent := Form;
      Btn.Name := 'btnKaydet';
      Btn.OnClick := Host.ButtonClick;
      Edit := TcxTextEdit.Create(Form);
      Edit.Parent := Form;
      Edit.Name := 'edtAd';
      Edit.Properties.OnValidate := Host.EditValidate;
      Grid := TcxGrid.Create(Form);
      Grid.Parent := Form;
      LC := TdxLayoutControl.Create(Form);
      LC.Parent := Form;
      Q := TRadQuery.Create(Form);
      Q.Name := 'qryKasa';

      // V1: RTTI kaydi
      S.AddLibrary(TatClassesLibrary);
      SW := TStopwatch.StartNew;
      S.DefineClassByRTTI(TLogger);
      S.DefineClassByRTTI(TcxButton);
      S.DefineClassByRTTI(TcxTextEdit);
      S.DefineClassByRTTI(TcxDBTextEdit);
      S.DefineClassByRTTI(TcxGrid);
      S.DefineClassByRTTI(TcxGridDBTableView);
      S.DefineClassByRTTI(TdxLayoutControl);
      S.DefineClassByRTTI(TRadQuery);
      Olcum('V1 8 sinif DefineClassByRTTI', SW.ElapsedMilliseconds.ToString + ' ms');
      Olcum('V1 TcxButton', MemberCount(S, 'TcxButton'));
      Olcum('V1 TcxDBTextEdit', MemberCount(S, 'TcxDBTextEdit'));
      Olcum('V1 TcxGrid', MemberCount(S, 'TcxGrid'));
      Olcum('V1 TcxGridDBTableView', MemberCount(S, 'TcxGridDBTableView'));
      Olcum('V1 TdxLayoutControl', MemberCount(S, 'TdxLayoutControl'));
      Olcum('V1 TRadQuery', MemberCount(S, 'TRadQuery'));
      Kontrol('V1 TRadQuery kayitli', S.Classes.ClassByName('TRadQuery') <> nil);
      S.AddObject('Logger', Host.Log);
      S.AddComponent(Act);
      S.AddComponent(Btn);
      S.AddComponent(Edit);
      S.AddComponent(Q);

      S.SourceCode.Text :=
        'procedure BeforeExec(Sender: TObject); begin Logger.Add(''script-before''); end;' + sLineBreak +
        'procedure AfterClick(Sender: TObject); begin Logger.Add(''script-after''); end;' + sLineBreak +
        'procedure RaiseExec(Sender: TObject); begin Logger.Add(''script-raise''); Logger.Fail(''dur''); end;' + sLineBreak +
        'function BeforeSave(Sender: TObject): boolean; begin Logger.Add(''own-before''); result := Logger.AllowSave; end;' + sLineBreak +
        'procedure AfterSave(Sender: TObject); begin Logger.Add(''own-after''); end;' + sLineBreak +
        'procedure OnValidateScript(Sender: TObject; DisplayValue: Variant; ErrorText: string; Error: boolean); begin Logger.Add(''script-validate:'' + VarToStr(DisplayValue)); end;' + sLineBreak +
        'procedure Touch; begin btnKaydet.Caption := ''Kaydet (script)''; edtAd.Text := ''ali''; qryKasa.SQL.Text := ''select 1''; end;' + sLineBreak +
        'begin end;';
      SW := TStopwatch.StartNew;
      S.Compile;
      Olcum('V1 derleme', SW.ElapsedMilliseconds.ToString + ' ms');
      S.ExecuteSubroutine('Touch');
      Kontrol('V1 script bilesen ozelliklerini yazdi', (Btn.Caption = 'Kaydet (script)') and (Edit.Text = 'ali') and (Q.SQL.Text.Trim = 'select 1'),
        Btn.Caption + '|' + Edit.Text + '|' + Q.SQL.Text);

      // V2: EventBroker epTopCall / epBottomCall
      Host.Log.Clear;
      S.EventBroker.SetEvent(Act, 'OnExecute', 'BeforeExec', S, epTopCall);
      Act.Execute;
      Kontrol('V2 epTopCall sirasi', Host.Log.Text = 'script-before,delphi-exec', Host.Log.Text);
      Host.Log.Clear;
      S.EventBroker.SetEvent(Btn, 'OnClick', 'AfterClick', S, epBottomCall);
      Btn.Click;
      Kontrol('V2 epBottomCall sirasi', Host.Log.Text = 'delphi-click,script-after', Host.Log.Text);
      S.EventBroker.UnsetEvent(Act, 'OnExecute');
      S.EventBroker.UnsetEvent(Btn, 'OnClick');
      Host.Log.Clear;
      Act.Execute; Btn.Click;
      Kontrol('V2 UnsetEvent orijinali geri koydu', Host.Log.Text = 'delphi-exec,delphi-click', Host.Log.Text);
      // iptal: epTopCall'da script exception atarsa orijinal calisir mi?
      Host.Log.Clear;
      S.EventBroker.SetEvent(Act, 'OnExecute', 'RaiseExec', S, epTopCall);
      try
        Act.Execute;
      except
        on E: Exception do Host.Log.Add('exc:' + E.ClassName);
      end;
      Olcum('V2 epTopCall + exception', Host.Log.Text);
      S.EventBroker.UnsetEvent(Act, 'OnExecute');

      // V3: kendi kancamiz, iptal destekli
      Host.Log.Clear;
      Hook := TRadNotifyHook.Create(Act, 'OnExecute', S, 'BeforeSave', 'AfterSave');
      Act.Execute;
      Kontrol('V3 kendi kanca: once/orijinal/sonra', Host.Log.Text = 'own-before,delphi-exec,own-after', Host.Log.Text);
      Host.Log.Clear;
      Host.Log.AllowSave := False;
      Act.Execute;
      Kontrol('V3 iptal: orijinal calismadi', Host.Log.Text = 'own-before', Host.Log.Text);
      Host.Log.AllowSave := True;
      SW := TStopwatch.StartNew;
      for i := 1 to 10000 do Act.Execute;
      Olcum('V3 10.000 kancali Action.Execute (once+sonra script)', SW.ElapsedMilliseconds.ToString + ' ms');
      Hook.Detach;
      Hook.Free;
      Host.Log.Clear;
      Act.Execute;
      Kontrol('V3 Detach orijinali geri koydu', Host.Log.Text = 'delphi-exec', Host.Log.Text);
      SW := TStopwatch.StartNew;
      for i := 1 to 10000 do Act.Execute;
      Olcum('V3 10.000 kancasiz Action.Execute', SW.ElapsedMilliseconds.ToString + ' ms');

      // V4: DevExpress olay tipi adaptoru
      DefineEventAdapter(TypeInfo(TcxEditValidateEvent), TRadCxDispatcher, @TRadCxDispatcher._TcxEditValidateEvent);
      Host.Log.Clear;
      S.EventBroker.SetEvent(Edit.Properties, 'OnValidate', 'OnValidateScript', S, epBottomCall);
      V := 'abc'; LTxt := ''; LErr := False;
      if Assigned(Edit.Properties.OnValidate) then Edit.Properties.OnValidate(Edit, V, LTxt, LErr);
      Kontrol('V4 DX var-parametreli olay adaptoru', Host.Log.Text = 'delphi-validate:abc,script-validate:abc', Host.Log.Text);
      S.EventBroker.UnsetEvent(Edit.Properties, 'OnValidate');

      // V5: DFM'den script formu
      RegisterClasses([TcxButton, TcxTextEdit]);
      S.LibOptions.SearchPath.Add(ExtractFilePath(ParamStr(0)));
      S.LibOptions.FormFileExt := '.dfm';
      S.SourceCode.Text :=
        '{$FORM TfmSpike, spikeform.dfm}' + sLineBreak +
        'function FormDene: string; var f: TfmSpike; begin f := TfmSpike.Create(nil); try result := f.Caption + ''|'' + f.Edit1.Text + ''|'' + f.Button1.Caption; finally f.Free; end; end;' + sLineBreak +
        'begin end;';
      try
        S.Compile;
        V := S.ExecuteSubroutineAsVariant('FormDene');
        Kontrol('V5 DFM script formu', V = 'Script Formu|deger|Selam', VarToStr(V));
      except
        on E: Exception do Kontrol('V5 DFM script formu', False, E.ClassName + ': ' + E.Message);
      end;

      // V6: IDE / editor bilesenleri ayaga kalkiyor mu
      LEng := TIDEEngine.Create(nil);
      LDlg := TIDEDialog.Create(nil);
      LMemo := TScrMemo.Create(Form);
      LStyler := TScrPascalMemoStyler.Create(Form);
      try
        LMemo.Parent := Form;
        LMemo.SyntaxStyles := LStyler;
        LDlg.Engine := LEng;
        Kontrol('V6 TIDEEngine + TIDEDialog + TScrMemo yaratildi', True);
      finally
        LDlg.Free;
        LEng.Free;
      end;
    except
      on E: Exception do
      begin
        Inc(GHata);
        Writeln('  [PATLADI] ', E.ClassName, ': ', E.Message);
      end;
    end;
  finally
    S.Free;
    Form.Free;
    Host.Log.Free;
    Host.Free;
  end;
  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then Halt(1);
end.
