program CustomizeLinkTest;

(* A host that uses only the entry units, as ERPPlus does: Customize must find its session.
   It once raised "oturum yüklü değil" because nothing linked rad.formstate.customize.session. *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils,
  Vcl.Forms,
  rad.scripting,
  rad.formstate,
  FormStateTestCustom in '..\rad_formstate\FormStateTestCustom.pas' {FormCustom};

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

var
  LRoot: string;
  LForm: TFormCustom;
begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  LRoot := TPath.Combine(TPath.GetTempPath, 'radfslink_' + TGuid.NewGuid.ToString);
  TRadFormState.Kur(TRadFormState.FileStore(LRoot), 'test');
  LForm := TFormCustom.Create(nil);
  try
    LForm.Show;
    try
      LForm.Customizer1.Customize;
      Kontrol('L1 yalniz rad.scripting ile Customize oturum acar', TRadFormCustomizeSession.Active <> nil);
    except
      on E: Exception do
        Kontrol('L1 yalniz rad.scripting ile Customize oturum acar', False, E.Message);
    end;
    if TRadFormCustomizeSession.Active <> nil then
      TRadFormCustomizeSession.Active.Close;
    Application.ProcessMessages;
    CheckSynchronize;
  finally
    LForm.Free;
  end;
  TRadFormState.Kapat;
  if TDirectory.Exists(LRoot) then
    TDirectory.Delete(LRoot, True);
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    ExitCode := 1;
end.
