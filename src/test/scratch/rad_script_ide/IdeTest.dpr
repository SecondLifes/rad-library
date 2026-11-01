program IdeTest;

(* 6. asama: TRadScriptIde (TMS IDE paketin ustunde, sanal dosyalar, CreateFor, deneme olayi). Win32, TMS IDE + DevExpress.
   Spec: docs/specs/rad.script.ide.md *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, System.Generics.Collections, System.Generics.Defaults,
  System.Diagnostics, System.IOUtils,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls,
  atScript, idemain,
  rad.sqlfilter, rad.script, rad.script.engine, rad.script.hooks, rad.script.jobs, rad.script.design, rad.script.ide,
  rad.script.newscript, rad.script.packages;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;
  GLog: TStringList;
  GMsgs: TList<string>;

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

type
  TLogger = class(TComponent)
  public
    procedure Add(const S: string);
  end;

  TFakeStore = class(TInterfacedObject, IRadScriptStore)
  public
    Saved: Integer;
    function Dialect: TRadSqlDialect;
    procedure EnsureDefinitionTables;
    function LoadPackages(AIncludeInactive: Boolean): TRadScriptPackages;
    function LoadPackage(const ACode: string): TRadScriptPackage;
    procedure SavePackage(APkg: TRadScriptPackage);
    procedure ImportPackage(APkg: TRadScriptPackage);
    procedure DeletePackage(const ACode: string);
    function ScriptsFor(AKind: TRadScriptKind; const ATarget: string): TRadScripts;
    procedure ApplyPendingDbSteps(APkg: TRadScriptPackage);
    function LoadResource(APackageId: Integer; const AFileName: string; AStream: TStream): Boolean;
    function ResourcesNamed(const AFileName: string): TObjectList<TRadScriptResource>;
    function LibrariesOf(const APackageIds: TArray<Integer>): TRadScripts;
    function ParamsOf(const APackageIds: TArray<Integer>): TObjectList<TRadScriptParam>;
  end;

procedure TLogger.Add(const S: string);
begin
  GLog.Add(S);
end;

function TFakeStore.Dialect: TRadSqlDialect; begin Result := sdPostgreSQL; end;
procedure TFakeStore.EnsureDefinitionTables; begin end;
function Paket: TRadScriptPackage; forward;
function TFakeStore.LoadPackages(AIncludeInactive: Boolean): TRadScriptPackages;
var
  P: TRadScriptPackage;
begin
  Result := TRadScriptPackages.Create(True);
  Result.Add(Paket);
  P := TRadScriptPackage.Create;
  P.Code := 'korumali'; P.Name := 'Korumalı'; P.Version := '1'; P.Active := False; P.IsProtected := True; P.Id := 8; P.Order := 2;
  P.AddDbStep(1, 'select 1');
  Result.Add(P);
end;
function TFakeStore.LoadPackage(const ACode: string): TRadScriptPackage; begin Result := nil; end;
procedure TFakeStore.SavePackage(APkg: TRadScriptPackage); begin Inc(Saved); end;
procedure TFakeStore.ImportPackage(APkg: TRadScriptPackage); begin end;
procedure TFakeStore.DeletePackage(const ACode: string); begin end;
function TFakeStore.ScriptsFor(AKind: TRadScriptKind; const ATarget: string): TRadScripts; begin Result := TRadScripts.Create(True); end;
procedure TFakeStore.ApplyPendingDbSteps(APkg: TRadScriptPackage); begin end;
function TFakeStore.LoadResource(APackageId: Integer; const AFileName: string; AStream: TStream): Boolean; begin Result := False; end;
function TFakeStore.ResourcesNamed(const AFileName: string): TObjectList<TRadScriptResource>; begin Result := TObjectList<TRadScriptResource>.Create(True); end;
function TFakeStore.LibrariesOf(const APackageIds: TArray<Integer>): TRadScripts; begin Result := TRadScripts.Create(True); end;
function TFakeStore.ParamsOf(const APackageIds: TArray<Integer>): TObjectList<TRadScriptParam>; begin Result := TObjectList<TRadScriptParam>.Create(True); end;

const
  OZET_DFM =
    'object OzetForm: TOzetForm'#13#10 +
    '  Caption = ''Ozet'''#13#10 +
    '  ClientHeight = 100'#13#10 +
    '  ClientWidth = 200'#13#10 +
    '  object btnTamam: TButton'#13#10 +
    '    Left = 8'#13#10 +
    '    Top = 8'#13#10 +
    '    Width = 75'#13#10 +
    '    Height = 25'#13#10 +
    '    Caption = ''Tamam'''#13#10 +
    '    OnClick = btnTamamClick'#13#10 +
    '  end'#13#10 +
    'end'#13#10;

function Paket: TRadScriptPackage;
begin
  Result := TRadScriptPackage.Create;
  Result.Code := 'test.ide';
  Result.Name := 'IDE testi';
  Result.Version := '1';
  Result.Active := True;
  Result.Id := 7;
  Result.AddScript('Yardimci', skLibrary, '', 'function Ek(S: string): string; begin Result := S + ''!''; end;');
  Result.AddScript('Gelen', skEvent, 'efatura.gelen',
    'uses Yardimci;'#13#10'procedure Calistir(Olay: TRadScriptEvent);'#13#10'begin'#13#10 +
    '  Kayit.Add(Ek(Olay.Channel) + ''|'' + Olay.Json + ''|'' + Olay.ScriptCode);'#13#10'end;');
  Result.AddScript('Ozet', skWindow, '', '{$FORM TOzetForm, Ozet.dfm}'#13#10'procedure btnTamamClick(Sender: TObject); begin Caption := ''tik''; end;'#13#10'begin end.');
  Result.AddResource('Ozet.dfm', TEncoding.UTF8.GetBytes(OZET_DFM));
  Result.AddScript('KasaForm', skForm, 'TKasaK', 'procedure Form_AfterCreate(Sender: TObject); begin end;');
end;

procedure Testler;
var
  LStore: TFakeStore;
  LStoreIntf: IRadScriptStore;
  P: TRadScriptPackage;
  Ide: TRadScriptIde;
  LFile: TIDEProjectFile;
  LIntf: IScriptBasedForm;
  LSw: TStopwatch;
  V: string;
  LLogger: TLogger;
  LCwdBefore: TArray<string>;
  LPkgForm: TRadScriptPackagesForm;
begin
  LStore := TFakeStore.Create;
  LStoreIntf := LStore;
  TRadScriptBinder.Store := LStoreIntf;
  P := Paket;
  LLogger := TLogger.Create(nil);
  LCwdBefore := TDirectory.GetFiles(GetCurrentDir);
  try
    P.IsProtected := True;
    try
      TRadScriptIde.Open(P, 'Gelen', nil);
      Kontrol('I08a korumali paket reddi', False);
    except
      on E: ERadScript do Kontrol('I08a korumali paket reddi', True);
    end;
    P.IsProtected := False;

    LSw := TStopwatch.StartNew;
    Ide := TRadScriptIde.Open(P, 'Gelen', nil);
    LSw.Stop;
    Writeln(Format('  olcum: IDE acilis (4 script, TMS IDE formu) %d ms', [LSw.ElapsedMilliseconds]));
    Ide.OnMessage := procedure(AMsg: string) begin GMsgs.Add(AMsg); end;
    Ide.LiveConfirmed := True;
    Kontrol('I01 acildi: 4 dosya, etkin Gelen, IDE formu', (TRadScriptIde.Active = Ide) and (Ide.IdeEngine.Files.Count = 4) and
      (Ide.IdeEngine.ActiveFile <> nil) and (Ide.IdeEngine.ActiveFile.UnitName = 'Gelen') and (Ide.IdeForm <> nil) and
      Ide.IdeForm.Visible and (Ide.Engine.Scripter = Ide.IdeEngine.Scripter), IntToStr(Ide.IdeEngine.Files.Count));
    try
      TRadScriptIde.Open(P, 'Gelen', nil);
      Kontrol('I08b ikinci IDE reddi', False);
    except
      on E: ERadScript do Kontrol('I08b ikinci IDE reddi', True);
    end;
    try
      TRadScriptDesigner.StartWindow('x', 'y');
      Kontrol('I08c IDE acikken tasarimci (store LoadPackage nil -> paket yok hatasi beklenir)', False);
    except
      on E: ERadScript do Kontrol('I08c IDE acikken tasarimci reddi', True, E.Message);
    end;

    LFile := Ide.IdeEngine.Files.FindByUnitName('Ozet');
    Kontrol('I02 pencere dosyasi: form + DFM + olay SaveEvents''te', (LFile <> nil) and LFile.IsForm and (LFile.Form <> nil) and
      (LFile.Form.FindComponent('btnTamam') is TButton) and Supports(LFile.Form, IScriptBasedForm, LIntf) and
      (LIntf.GetSaveEvents.IndexOfName('btnTamam.OnClick') >= 0) and (LFile.Script.DesignFormResource <> ''));

    // deneme olayi: Kayit nesnesi + Calistir(Olay)
    Ide.Engine.Expose('Kayit', LLogger);
    Ide.TestChannel := 'efatura.gelen';
    Ide.TestJson := '{"no":5}';
    GMsgs.Clear;
    Ide.RunTest;
    Kontrol('I04 RunTest olay: kutuphane uses + Olay + Kayit', (GLog.Count = 1) and (GLog[0] = 'efatura.gelen!|{"no":5}|Gelen'),
      string.Join(';', GLog.ToStringArray) + ' / ' + string.Join(';', GMsgs.ToArray));

    // form script'i: calistirilmaz
    Ide.IdeEngine.ActiveFile := Ide.IdeEngine.Files.FindByUnitName('KasaForm');
    GMsgs.Clear;
    Ide.RunTest;
    Kontrol('I05 form script''i yalniz mesaj', (GMsgs.Count >= 1) and GMsgs[GMsgs.Count - 1].Contains('derlendi'), string.Join(';', GMsgs.ToArray));

    // kaydet: kaynak DB'ye, diske degil
    LFile := Ide.IdeEngine.Files.FindByUnitName('Yardimci');
    LFile.Script.SourceCode.Text := 'function Ek(S: string): string; begin Result := S + ''?''; end;';
    GMsgs.Clear;
    LFile.Save;
    Kontrol('I03 Save -> paket kaynagi + SavePackage + mesaj', (LStore.Saved = 1) and P.ScriptByCode('Yardimci').Source.Contains('''?''') and
      (GMsgs.Count = 1) and GMsgs[0].Contains('Yardimci'), string.Join(';', GMsgs.ToArray));
    Kontrol('I03b diske dosya yazilmadi', Length(TDirectory.GetFiles(GetCurrentDir)) = Length(LCwdBefore));
    LFile := Ide.IdeEngine.Files.FindByUnitName('Ozet');
    LFile.Save;
    V := TEncoding.UTF8.GetString(P.ResourceByName('Ozet.dfm').Content);
    Kontrol('I06 pencere Save: kok sinif TOzetForm, SaveEvents korunur', V.StartsWith('object OzetForm: TOzetForm') and
      V.Contains('btnTamam.OnClick=btnTamamClick') and (LStore.Saved = 2), IntToStr(LStore.Saved) + ' ' + V);

    Ide.Close;
    Kontrol('I07 kapandi', TRadScriptIde.Active = nil);

    // ---- yeni script iskeletleri ----
    Kontrol('I09 iskeletler', TRadScriptNewScriptForm.Skeleton(skWindow, 'Ozet').StartsWith('{$FORM TOzetForm, Ozet.dfm}') and
      TRadScriptNewScriptForm.Skeleton(skCommand, 'Kur').Contains('Kur_Execute') and TRadScriptNewScriptForm.Skeleton(skEvent, 'x').Contains('Calistir(Olay') and
      (TRadScriptNewScriptForm.Skeleton(skLibrary, 'x') = ''));

    // ---- paket yoneticisi: yukle, sec, dugmeler, kapat ----
    LPkgForm := TRadScriptPackagesForm.Open(nil, LStoreIntf, nil);
    try
      Kontrol('I10 yonetici: 2 paket, ilk secili, 4 script', (LPkgForm.vwPaket.DataController.RecordCount = 2) and
        (LPkgForm.vwPaket.Controller.FocusedRecordIndex = 0) and (LPkgForm.vwScript.DataController.RecordCount = 4) and
        (VarToStr(LPkgForm.vwPaket.DataController.Values[0, LPkgForm.colKod.Index]) = 'test.ide') and
        (LPkgForm.vwKaynak.DataController.RecordCount = 1) and LPkgForm.btnIde.Enabled and LPkgForm.btnScriptYeni.Enabled);
      LPkgForm.vwPaket.Controller.FocusedRecordIndex := 1;
      Kontrol('I10b korumali paket: IDE/tasarla/yeni script kapali, DB adimi var', not LPkgForm.btnIde.Enabled and not LPkgForm.btnTasarla.Enabled and
        not LPkgForm.btnScriptYeni.Enabled and LPkgForm.btnDbUygula.Enabled and (LPkgForm.vwDb.DataController.RecordCount = 1));
      LPkgForm.vwPaket.Controller.FocusedRecordIndex := 0;
      LPkgForm.vwScript.Controller.FocusedRecordIndex := 2;   // Ozet (pencere)
      Kontrol('I10c pencere secili: Tasarla acik', LPkgForm.btnTasarla.Enabled);
      LPkgForm.vwScript.Controller.FocusedRecordIndex := 3;   // KasaForm, host geri cagrisi yok
      Kontrol('I10d form script, geri cagri yok: Tasarla kapali', not LPkgForm.btnTasarla.Enabled);
      LPkgForm.btnIdeClick(nil);
      Kontrol('I10e IDE''de ac: etkin script KasaForm', (TRadScriptIde.Active <> nil) and (TRadScriptIde.Active.IdeEngine.ActiveFile.UnitName = 'KasaForm'));
    finally
      LPkgForm.Free;   // IDE'yi de kapatir
    end;
    Kontrol('I10f yonetici kapaninca IDE kapandi', TRadScriptIde.Active = nil);
  finally
    LLogger.Free;
    P.Free;
    TRadScriptBinder.Store := nil;
    LStoreIntf := nil;
  end;
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  GLog := TStringList.Create;
  GMsgs := TList<string>.Create;
  try
    try
      System.Classes.RegisterClass(TButton);
      TRadScriptEngine.RegisterClasses([TLogger, TButton, TForm]);
      Testler;
    except
      on E: Exception do
      begin
        Inc(GHata);
        Writeln('[ISTISNA] ', E.ClassName, ': ', E.Message);
      end;
    end;
  finally
    GMsgs.Free;
    GLog.Free;
  end;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then ExitCode := 1;
end.
