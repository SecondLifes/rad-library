program CustomizeSessionTest;

(* Customizer session without the mouse (docs/specs/rad.formcustomizer.md, phase 5): behaviours,
   inspector filter, undo, reset, save and cancel through TRadFormCustomizer.Customize. *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls,
  mormot.core.base, mormot.core.variants,
  FormDesigner,
  rad.formstate.core,
  rad.formstate,
  rad.formstate.customize.tools,
  rad.formstate.customize.session,
  FormStateTestCustom in '..\rad_formstate\FormStateTestCustom.pas' {FormCustom};

const
  SCOPE = 'test';
  RECORD_NAME = 'TFormCustom';
  DESIGN_WIDTH = 121;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;
  GRoot: string;

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

procedure Settle;
begin
  Application.ProcessMessages;
  CheckSynchronize; // the session frees itself through the main-thread queue
end;

function SavedEdit1: IDocDict;
var
  LDoc, LCustom, LSection, LDiff, LEdit: IDocDict;
begin
  Result := nil;
  if TRadFormState.Repository.Load(TRadStateKey.Make(SCOPE, RECORD_NAME), LDoc) and
    LDoc.Get('custom', LCustom) and LCustom.Get('Customizer1', LSection) and
    LSection.Get('diff', LDiff) and LDiff.Get('Edit1', LEdit) then
    Result := LEdit.Copy; // Get hands out a reference into LDoc, which dies with this function
end;

function NoControlDesigning(AForm: TForm): Boolean;
var
  I: Integer;
begin
  for I := 0 to AForm.ComponentCount - 1 do
    if csDesigning in AForm.Components[I].ComponentState then
      Exit(False);
  Result := True;
end;

function OpenSession(AForm: TFormCustom): TRadFormCustomizeSession;
begin
  AForm.Show;
  Settle;
  AForm.Customizer1.Customize;
  Result := TRadFormCustomizeSession.Active;
end;

procedure BehavioursAndFilter;
var
  LForm: TFormCustom;
  LSession: TRadFormCustomizeSession;
begin
  LForm := TFormCustom.Create(nil);
  try
    LSession := OpenSession(LForm);
    Kontrol('S1 Customize oturumu acar', LSession <> nil);
    Kontrol('S2 hicbir bilesene csDesigning acilmaz', NoControlDesigning(LForm));
    Kontrol('S3 izinsiz dugme korunur', LSession.Designer.IsProtected(LForm.Button1));
    Kontrol('S4 tasinabilir Edit1 kilitli/korunan degil',
      not LSession.Designer.IsProtected(LForm.Edit1) and not LSession.Designer.IsLocked(LForm.Edit1));
    Kontrol('S5 geometri izni olmayan Label1 kilitli', LSession.Designer.IsLocked(LForm.Label1));
    LSession.Select(LForm.Edit1);
    Kontrol('S6 inspector Edit1''i gosterir', LSession.Tools.insp.InspectedObject = LForm.Edit1);
    Kontrol('S7 izinli yol gorunur', LSession.Tools.insp.Shows('Width') and LSession.Tools.insp.Shows('Font.Size'));
    Kontrol('S8 izinsiz yol gizli', not LSession.Tools.insp.Shows('Text') and
      not LSession.Tools.insp.Shows('Font.Name'));
    Kontrol('S9 Font yalniz ust satir, duzenlenmez', LSession.Tools.insp.Shows('Font') and
      LSession.Tools.insp.IsParentOnly('Font'));
    LSession.Select(LForm.Button1);
    Kontrol('S10 izinsiz bilesen secilemez', LSession.Current = nil);
    LSession.Close;
    Settle;
    Kontrol('S11 kapaninca oturum biter', TRadFormCustomizeSession.Active = nil);
    Kontrol('S12 kapaninca csDesigning yine kapali', NoControlDesigning(LForm));
  finally
    LForm.Free;
  end;
end;

procedure UndoSaveResetCancel;
var
  LForm: TFormCustom;
  LSession: TRadFormCustomizeSession;
  LEdit: IDocDict;
begin
  LForm := TFormCustom.Create(nil);
  try
    LSession := OpenSession(LForm);
    LSession.Select(LForm.Edit1);
    LForm.Edit1.Width := 300;
    LSession.Changed;
    Kontrol('U1 geri alinabilir', LSession.CanUndo);
    LSession.Undo;
    Kontrol('U2 geri al eski genisligi koyar', LForm.Edit1.Width = DESIGN_WIDTH, IntToStr(LForm.Edit1.Width));
    LForm.Edit1.Width := 250;
    LSession.Changed;
    LSession.Save;
    Settle;
    LEdit := SavedEdit1;
    Kontrol('U3 Kaydet farki yazar', (LEdit <> nil) and LEdit.Exists('Width') and (LEdit.I['Width'] = 250));
  finally
    LForm.Free;
  end;
  LForm := TFormCustom.Create(nil);
  try
    Kontrol('U4 yeniden acilista kullanici genisligi', LForm.Edit1.Width = 250, IntToStr(LForm.Edit1.Width));
    LSession := OpenSession(LForm);
    LSession.Select(LForm.Edit1);
    LSession.ResetSelected;
    Kontrol('U5 seciliyi sifirla tasarim genisligini koyar', LForm.Edit1.Width = DESIGN_WIDTH,
      IntToStr(LForm.Edit1.Width));
    LSession.Save;
    Settle;
    Kontrol('U6 varsayilana donen yol farktan cikar', SavedEdit1 = nil);
    LSession := OpenSession(LForm);
    LForm.Label1.Caption := 'Gecici';
    LSession.Select(LForm.Label1);
    LSession.Changed;
    LSession.Cancel;
    Settle;
    Kontrol('U7 Vazgec oturum basini geri koyar', LForm.Label1.Caption = 'Etiket', LForm.Label1.Caption);
  finally
    LForm.Free;
  end;
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  GRoot := TPath.Combine(TPath.GetTempPath, 'radfssess_' + TGuid.NewGuid.ToString);
  TRadFormState.Kur(TRadFormState.FileStore(GRoot), SCOPE);
  try
    BehavioursAndFilter;
    UndoSaveResetCancel;
  except
    on E: Exception do
      Kontrol('beklenmeyen istisna', False, E.ClassName + ': ' + E.Message);
  end;
  TRadFormState.Kapat;
  if TDirectory.Exists(GRoot) then
    TDirectory.Delete(GRoot, True);
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    ExitCode := 1;
end.
