program DesignVclTest;

(* 5. asama VCL testi (Win32, DevExpress + TMS): pencere script'i (TRadScriptForm, $FORM + DesignFormResource),
   Attach ile duzen/yerlesim uygulama (sahte store), paket oncelik sirasi, script > duzen, olcumler.
   Spec: docs/specs/rad.script.designer.md *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, System.Generics.Collections, System.Generics.Defaults,
  System.Diagnostics,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls,
  cxEdit, cxTextEdit, cxGraphics, cxControls, cxLookAndFeels, cxLookAndFeelPainters, cxContainer,
  dxLayoutControl, dxLayoutContainer, dxLayoutcxEditAdapters, dxLayoutControlAdapters,
  atScript,
  mormot.core.base,
  rad.sqlfilter, rad.script, rad.script.override, rad.script.engine, rad.script.hooks, rad.script.dev, rad.script.design;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;
  GLog: TStringList;
  GErrors: TList<string>;

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

  TKasaK = class(TForm)
  public
    btnKaydet: TButton;
    edt: TcxTextEdit;
    lyt: TdxLayoutControl;
    lytItemNot: TdxLayoutItem;
    Kayit: TLogger;
    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
  end;

  TFakeStore = class(TInterfacedObject, IRadScriptStore)
  public
    Packages: TRadScriptPackages;
    Saved: Boolean;
    constructor Create;
    destructor Destroy; override;
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
    function AddPackage(const ACode: string; AOrder: Integer): TRadScriptPackage;
    function Sorted: TList<TRadScriptPackage>;
  end;

procedure TLogger.Add(const S: string);
begin
  GLog.Add(S);
end;

constructor TKasaK.CreateNew(AOwner: TComponent; Dummy: Integer);
begin
  inherited CreateNew(AOwner, Dummy);
  Caption := 'Kasa';
  btnKaydet := TButton.Create(Self);
  btnKaydet.Name := 'btnKaydet';
  btnKaydet.Parent := Self;
  btnKaydet.Caption := 'Kaydet';
  lyt := TdxLayoutControl.Create(Self);
  lyt.Name := 'lyt';
  lyt.Parent := Self;
  lyt.Align := alClient;
  edt := TcxTextEdit.Create(Self);
  edt.Name := 'edt';
  lytItemNot := lyt.Items.CreateItemForControl(edt);
  lytItemNot.Name := 'lytItemNot';
  Kayit := TLogger.Create(Self);
  Kayit.Name := 'Kayit';
end;

{ TFakeStore }

constructor TFakeStore.Create;
begin
  inherited Create;
  Packages := TRadScriptPackages.Create(True);
end;

destructor TFakeStore.Destroy;
begin
  Packages.Free;
  inherited;
end;

function TFakeStore.AddPackage(const ACode: string; AOrder: Integer): TRadScriptPackage;
begin
  Result := TRadScriptPackage.Create;
  Result.Code := ACode;
  Result.Name := ACode;
  Result.Version := '1';
  Result.Active := True;
  Result.Order := AOrder;
  Result.Id := Packages.Count + 1;
  Packages.Add(Result);
end;

function TFakeStore.Sorted: TList<TRadScriptPackage>;
var
  P: TRadScriptPackage;
begin
  Result := TList<TRadScriptPackage>.Create;
  for P in Packages do if P.Active then Result.Add(P);
  Result.Sort(TComparer<TRadScriptPackage>.Construct(
    function(const A, B: TRadScriptPackage): Integer begin Result := A.Order - B.Order; if Result = 0 then Result := A.Id - B.Id; end));
end;

function TFakeStore.Dialect: TRadSqlDialect; begin Result := sdPostgreSQL; end;
procedure TFakeStore.EnsureDefinitionTables; begin end;
function TFakeStore.LoadPackages(AIncludeInactive: Boolean): TRadScriptPackages; begin Result := TRadScriptPackages.Create(True); end;
function TFakeStore.LoadPackage(const ACode: string): TRadScriptPackage;
var
  P: TRadScriptPackage;
begin
  Result := nil;
  for P in Packages do
    if SameText(P.Code, ACode) then
    begin
      Packages.Extract(P);   // gercek store yeni nesne verir, sahiplik cagirana: burada listeden cikarilir
      Exit(P);
    end;
end;
procedure TFakeStore.SavePackage(APkg: TRadScriptPackage); begin Saved := True; end;
procedure TFakeStore.ImportPackage(APkg: TRadScriptPackage); begin end;
procedure TFakeStore.DeletePackage(const ACode: string); begin end;
procedure TFakeStore.ApplyPendingDbSteps(APkg: TRadScriptPackage); begin end;
function TFakeStore.ParamsOf(const APackageIds: TArray<Integer>): TObjectList<TRadScriptParam>; begin Result := TObjectList<TRadScriptParam>.Create(True); end;

function TFakeStore.ScriptsFor(AKind: TRadScriptKind; const ATarget: string): TRadScripts;
var
  LSorted: TList<TRadScriptPackage>;
  P: TRadScriptPackage;
  S, C: TRadScript;
begin
  Result := TRadScripts.Create(True);
  LSorted := Sorted;
  try
    for P in LSorted do
      for S in P.Scripts do
        if S.Active and (S.Kind = AKind) and SameText(S.Target, ATarget) then
        begin
          C := TRadScript.Create;
          C.Assign(S);
          C.PackageId := P.Id;
          Result.Add(C);
        end;
  finally
    LSorted.Free;
  end;
end;

function TFakeStore.LibrariesOf(const APackageIds: TArray<Integer>): TRadScripts;
var
  P: TRadScriptPackage;
  S, C: TRadScript;
  LId: Integer;
begin
  Result := TRadScripts.Create(True);
  for LId in APackageIds do
    for P in Packages do
      if P.Id = LId then
        for S in P.Scripts do
          if S.Active and (S.Kind in [skLibrary, skWindow]) then
          begin
            C := TRadScript.Create;
            C.Assign(S);
            C.PackageId := P.Id;
            Result.Add(C);
          end;
end;

function TFakeStore.LoadResource(APackageId: Integer; const AFileName: string; AStream: TStream): Boolean;
var
  P: TRadScriptPackage;
  R: TRadScriptResource;
begin
  Result := False;
  for P in Packages do
    if P.Id = APackageId then
    begin
      R := P.ResourceByName(AFileName);
      if R = nil then Exit;
      AStream.WriteBuffer(R.Content, Length(R.Content));
      Exit(True);
    end;
end;

function TFakeStore.ResourcesNamed(const AFileName: string): TObjectList<TRadScriptResource>;
var
  LSorted: TList<TRadScriptPackage>;
  P: TRadScriptPackage;
  R, C: TRadScriptResource;
begin
  Result := TObjectList<TRadScriptResource>.Create(True);
  LSorted := Sorted;
  try
    for P in LSorted do
      for R in P.Resources do
        if SameText(R.FileName, AFileName) then
        begin
          C := TRadScriptResource.Create;
          C.Id := R.Id; C.PackageId := P.Id; C.FileName := R.FileName; C.Content := R.Content;
          Result.Add(C);
        end;
  finally
    LSorted.Free;
  end;
end;

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
  OZET_SRC =
    '{$FORM TOzetForm, Ozet.dfm}'#13#10 +
    'procedure btnTamamClick(Sender: TObject);'#13#10 +
    'begin'#13#10 +
    '  Caption := ''tik'';'#13#10 +
    'end;'#13#10 +
    'begin end.';

function Bytes(const S: string): TBytes;
begin
  Result := TEncoding.UTF8.GetBytes(S);
end;

function ScriptFormOf(AForm: TForm): TRadScriptForm;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to AForm.ComponentCount - 1 do
    if AForm.Components[i] is TRadScriptForm then Exit(TRadScriptForm(AForm.Components[i]));
end;

procedure Testler;
var
  LStore: TFakeStore;
  LStoreIntf: IRadScriptStore;
  P, P2, P3: TRadScriptPackage;
  F, F2: TKasaK;
  SF: TRadScriptForm;
  LAtt: TRadScriptAttachment;
  LCls: TatClass;
  LSnap, LSnap2, LDiff: TRadPropSnapshot;
  LMem: TBytesStream;
  LSw: TStopwatch;
  V: string;
  LWarn: Boolean;
  LEng: TRadScriptEngine;
begin
  LStore := TFakeStore.Create;
  LStoreIntf := LStore;
  TRadScriptBinder.Store := LStoreIntf;
  TRadScriptBinder.OnError := procedure(AForm: TCustomForm; E: Exception) begin GErrors.Add(E.Message); end;
  TRadScriptBinder.OnWarning := procedure(const S: string) begin GErrors.Add('UYARI ' + S); end;
  try
    // ---- pencere script'i ----
    P := LStore.AddPackage('p1', 1);
    P.AddScript('Ozet', skWindow, '', OZET_SRC);
    P.AddResource('Ozet.dfm', Bytes(OZET_DFM));
    P.AddScript('KasaForm', skForm, 'TKasaK',
      'uses Ozet;'#13#10 +
      'procedure Form_AfterCreate(Sender: TObject);'#13#10 +
      'var F: TOzetForm;'#13#10 +
      'begin'#13#10 +
      '  F := TOzetForm.Create(Form);'#13#10 +
      '  F.Caption := ''ozet-script'';'#13#10 +
      '  F.Show;'#13#10 +
      '  Kayit.Add(F.btnTamam.Caption);'#13#10 +
      'end;');
    Kontrol('V00 paket gecerli', P.Validate = '', P.Validate);
    // tani: zincir motorda nasil gorunuyor
    LEng := TRadScriptEngine.Create;
    try
      for V in ['TComponent', 'TControl', 'TWinControl', 'TScrollingWinControl', 'TCustomForm', 'TForm', 'TScriptForm', 'TRadScriptForm'] do
      begin
        LCls := LEng.Scripter.Classes.ClassByName(V);
        if LCls = nil then Writeln('  tani: ', V, ' YOK')
        else
        begin
          if LCls.Ancestor = nil then Write('  tani: ', V, ' ata=NIL') else Write('  tani: ', V, ' ata=', LCls.Ancestor.Name);
          Writeln(' props=', LCls.Properties.Count, ' methods=', LCls.Methods.Count,
            ' Show=', LCls.Methods.MethodByName('Show') <> nil, ' ShowModal=', LCls.Methods.MethodByName('ShowModal') <> nil,
            ' Create=', LCls.Methods.MethodByName('Create') <> nil);
        end;
      end;
    finally
      LEng.Free;
    end;
    F := TKasaK.CreateNew(nil);
    try
      LAtt := TRadScriptBinder.Attach(F);
      Kontrol('V01 pencere derlendi ve acildi', (LAtt <> nil) and (GErrors.Count = 0), string.Join(';', GErrors.ToArray));
      SF := ScriptFormOf(F);
      Kontrol('V01b TRadScriptForm ornegi, DFM bilesenleri, script ozelligi', (SF <> nil) and (SF.Caption = 'ozet-script') and
        (SF.FindComponent('btnTamam') is TButton) and (GLog.IndexOf('Tamam') >= 0) and SF.Visible);
      if SF <> nil then
      begin
        TButton(SF.FindComponent('btnTamam')).Click;
        Kontrol('V01c DFM olayi -> script rutini', SF.Caption = 'tik', SF.Caption);
      end;
      if LAtt <> nil then
      begin
        LCls := LAtt.Engine.Scripter.Classes.ClassByName('TOzetForm');
        Kontrol('V01d olcum 1: TOzetForm sinifinda Create/ShowModal/Release', (LCls <> nil) and
          (LCls.Methods.MethodByName('Create') <> nil) and (LCls.Methods.MethodByName('ShowModal') <> nil) and
          (LCls.Methods.MethodByName('Release') <> nil) and (LCls.Methods.MethodByName('Free') = nil));
      end;
    finally
      F.Free;
    end;
    GLog.Clear;
    GErrors.Clear;

    // ---- dfm kaynagi eksik ----
    P.Resources.Clear;
    F := TKasaK.CreateNew(nil);
    try
      LAtt := TRadScriptBinder.Attach(F);
      Kontrol('V02 dfm yok -> uyari + derleme hatasi', (LAtt = nil) and (GErrors.Count = 2) and GErrors[0].Contains('Ozet.dfm'),
        string.Join(';', GErrors.ToArray));
    finally
      F.Free;
    end;
    P.Active := False;
    GErrors.Clear;

    // ---- duzen: script'siz paket, Attach nil ama uygulanir; uyari ----
    P2 := LStore.AddPackage('p2', 2);
    P2.AddResource(TRadScriptBinder.OverrideFileName('TKasaK'), Bytes(
      '{"format":1,"form":"TKasaK","props":{"Form.Caption":"Kasa (sube)","btnKaydet.Caption":"Kaydet*",' +
      '"edt.Properties.ReadOnly":"True","lytItemNot.Visible":"False","yok.Caption":"x"}}'));
    F := TKasaK.CreateNew(nil);
    try
      LAtt := TRadScriptBinder.Attach(F);
      Kontrol('V03 duzen uygulandi, Attach nil', (LAtt = nil) and (F.Caption = 'Kasa (sube)') and (F.btnKaydet.Caption = 'Kaydet*') and
        F.edt.Properties.ReadOnly and not F.lytItemNot.Visible);
      Kontrol('V03b bulunamayan anahtar uyari', (GErrors.Count = 1) and GErrors[0].Contains('yok.Caption') and GErrors[0].Contains('paket 2'),
        string.Join(';', GErrors.ToArray));
    finally
      F.Free;
    end;
    GErrors.Clear;

    // ---- oncelik: sira buyuk kazanir; bozuk json uyari ----
    P3 := LStore.AddPackage('p3', 3);
    P3.AddResource(TRadScriptBinder.OverrideFileName('TKasaK'), Bytes('{"format":1,"props":{"btnKaydet.Caption":"Uc"}}'));
    LStore.AddPackage('p0', 0).AddResource(TRadScriptBinder.OverrideFileName('TKasaK'), Bytes('bozuk'));
    F := TKasaK.CreateNew(nil);
    try
      TRadScriptBinder.Attach(F);
      Kontrol('V04 sirasi buyuk paket kazanir', F.btnKaydet.Caption = 'Uc', F.btnKaydet.Caption);
      Kontrol('V04b bozuk json uyari, digerleri uygulandi', (GErrors.Count = 2) and GErrors[0].Contains('okunamadı') and (F.Caption = 'Kasa (sube)'),
        string.Join(';', GErrors.ToArray));
    finally
      F.Free;
    end;
    GErrors.Clear;

    // ---- script duzenin ustune yazar ----
    P3.AddScript('Ust', skForm, 'TKasaK', 'procedure Form_AfterCreate(Sender: TObject); begin btnKaydet.Caption := ''Script''; end;');
    F := TKasaK.CreateNew(nil);
    try
      LAtt := TRadScriptBinder.Attach(F);
      Kontrol('V05 Form_AfterCreate duzeni ezer', (LAtt <> nil) and (F.btnKaydet.Caption = 'Script') and (F.Caption = 'Kasa (sube)'),
        string.Join(';', GErrors.ToArray));
    finally
      F.Free;
    end;
    GErrors.Clear;

    // ---- yerlesim akisi ----
    F := TKasaK.CreateNew(nil);
    LMem := TBytesStream.Create;
    try
      F.lytItemNot.AlignHorz := ahLeft;
      F.lytItemNot.Width := 123;
      F.lyt.SaveToStream(LMem);
      P3.AddResource(TRadScriptBinder.LayoutFileName('TKasaK', 'lyt'), Copy(LMem.Bytes, 0, LMem.Size));
      LStore.AddPackage('p4', 4).AddResource(TRadScriptBinder.LayoutFileName('TKasaK', 'lyt'), Bytes('bozuk'));
    finally
      LMem.Free;
      F.Free;
    end;
    F2 := TKasaK.CreateNew(nil);
    try
      TRadScriptBinder.Attach(F2);
      Kontrol('V06 yerlesim akisi uygulandi', (F2.lytItemNot.Width = 123) and (F2.lytItemNot.AlignHorz = ahLeft),
        IntToStr(F2.lytItemNot.Width));
      LWarn := False;
      for V in GErrors do if V.Contains('Yerleşim') and V.Contains('paket 5') then LWarn := True;
      Kontrol('V06b bozuk yerlesim uyari, form ayakta', LWarn, string.Join(';', GErrors.ToArray));
    finally
      F2.Free;
    end;
    GErrors.Clear;

    // ---- olcum 3: anlik goruntu DevExpress'li formda ----
    F := TKasaK.CreateNew(nil);
    try
      LSw := TStopwatch.StartNew;
      LSnap := TRadPropSnapshot.Capture(F);
      LSw.Stop;
      try
        Writeln(Format('  olcum: TKasaK %d anahtar, Capture %d ms', [LSnap.Count, LSw.ElapsedMilliseconds]));
        Kontrol('V07 DevExpress alt ozellikleri yakalanir', LSnap.TryGetValue('edt.Properties.ReadOnly', V) and (V = 'False') and
          LSnap.TryGetValue('lytItemNot.Visible', V) and (V = 'True') and LSnap.TryGetValue('edt.Style.Color', V));
        F.edt.Properties.ReadOnly := True;
        F.edt.Style.Color := 255;
        LSnap2 := TRadPropSnapshot.Capture(F);
        LDiff := TRadPropSnapshot.Diff(LSnap, LSnap2);
        try
          Kontrol('V07b fark', LDiff.TryGetValue('edt.Properties.ReadOnly', V) and (V = 'True') and LDiff.TryGetValue('edt.Style.Color', V) and (V = '255'),
            IntToStr(LDiff.Count) + ' ' + string.Join(',', LDiff.Keys.ToArray));
          Writeln('  fark anahtarlari: ', string.Join(',', LDiff.Keys.ToArray));
        finally
          LDiff.Free;
          LSnap2.Free;
        end;
      finally
        LSnap.Free;
      end;
    finally
      F.Free;
    end;
  finally
    TRadScriptBinder.Store := nil;
    LStoreIntf := nil;
  end;
end;


procedure OturumTestleri;
var
  LStore: TFakeStore;
  LStoreIntf: IRadScriptStore;
  P, P2: TRadScriptPackage;
  F: TKasaK;
  D: TRadScriptDesigner;
  LCh, LSnap: TRadPropSnapshot;
  R: TRadScriptResource;
  V, LCls: string;
  LMsgs: TList<string>;
  LSw: TStopwatch;
  LBtn: TButton;
  LClosed: Boolean;
begin
  Writeln('--- tasarim oturumu');
  LMsgs := TList<string>.Create;
  LStore := TFakeStore.Create;
  LStoreIntf := LStore;
  TRadScriptBinder.Store := LStoreIntf;
  try
    P := LStore.AddPackage('p1', 1);
    LStore.AddPackage('korumali', 2).IsProtected := True;
    F := TKasaK.CreateNew(nil);
    try
      try
        TRadScriptDesigner.Start(F, 'korumali');
        Kontrol('S06a korumali paket reddi', False);
      except
        on E: ERadScript do Kontrol('S06a korumali paket reddi', True);
      end;
      try
        TRadScriptDesigner.Start(F, 'yok');
        Kontrol('S06b bilinmeyen paket', False);
      except
        on E: ERadScript do Kontrol('S06b bilinmeyen paket', True);
      end;
      LSw := TStopwatch.StartNew;
      D := TRadScriptDesigner.Start(F, 'p1');
      LSw.Stop;
      Writeln(Format('  olcum: Start (TMS tasarimci + inspector + anlik goruntu) %d ms', [LSw.ElapsedMilliseconds]));
      D.OnMessage := procedure(AMsg: string) begin LMsgs.Add(AMsg); end;
      LClosed := False;
      D.OnClosed := procedure(Sender: TObject) begin LClosed := True; end;
      Kontrol('S01 oturum acik', (TRadScriptDesigner.Active = D) and (D.Mode = dmForm) and (D.Form = F) and
        D.IdeEngine.FormDesigner.Active and D.IdeEngine.Inspector.Visible, '');
      try
        TRadScriptDesigner.Start(F, 'p1');
        Kontrol('S06c ikinci oturum reddi', False);
      except
        on E: ERadScript do Kontrol('S06c ikinci oturum reddi', True);
      end;
      // All controls are protected here (ProtectedInverse, empty list), and TMS skips protected ones.
      Kontrol('S01c mevcut formda csDesigning acilmaz',
        not (csDesigning in F.btnKaydet.ComponentState) and not (csDesigning in F.edt.ComponentState));
      D.Select(F.btnKaydet);
      Kontrol('S01b secim inspector + cubuk', (D.IdeEngine.SelectedComponent = F.btnKaydet) and (D.IdeEngine.Inspector.Instance = F.btnKaydet));

      F.btnKaydet.Caption := 'Kaydet*';
      F.edt.Properties.ReadOnly := True;
      F.edt.Left := F.edt.Left + 50;     // yerlesim cocugu: gurultu, farka girmez
      F.Left := F.Left + 10;             // pencere konumu: gurultu
      LCh := D.Changes;
      try
        Kontrol('S02 fark gurultusuz', (LCh.Count = 2) and LCh.TryGetValue('btnKaydet.Caption', V) and LCh.TryGetValue('edt.Properties.ReadOnly', V),
          IntToStr(LCh.Count) + ' ' + string.Join(',', LCh.Keys.ToArray));
      finally
        LCh.Free;
      end;
      D.Save;
      R := P.ResourceByName(TRadScriptBinder.OverrideFileName('TKasaK'));
      Kontrol('S03 Kaydet: duzen kaynagi + SavePackage', (R <> nil) and (R.PackageId = 0) and LStore.Saved and (LMsgs.Count = 1), string.Join(';', LMsgs.ToArray));
      if R <> nil then
      begin
        LSnap := TRadPropSnapshot.FromJsonBytes(R.Content, LCls);
        try
          Kontrol('S03b duzen icerigi', (LCls = 'TKasaK') and (LSnap.Count = 2) and LSnap.TryGetValue('btnKaydet.Caption', V) and (V = 'Kaydet*'));
        finally
          LSnap.Free;
        end;
      end;
      Kontrol('S03c yerlesim kaynagi', P.ResourceByName(TRadScriptBinder.LayoutFileName('TKasaK', 'lyt')) <> nil);
      // ikinci kaydet: birlestirme
      F.Caption := 'Kasa ğüş';
      D.Save;
      R := P.ResourceByName(TRadScriptBinder.OverrideFileName('TKasaK'));
      LSnap := TRadPropSnapshot.FromJsonBytes(R.Content, LCls);
      try
        Kontrol('S03d ikinci Kaydet birlesir, Turkce', (LSnap.Count = 3) and LSnap.TryGetValue('Form.Caption', V) and (V = 'Kasa ğüş') and
          LSnap.TryGetValue('btnKaydet.Caption', V) and (V = 'Kaydet*'), IntToStr(LSnap.Count));
      finally
        LSnap.Free;
      end;
      // vazgec: son kayda doner
      F.btnKaydet.Caption := 'X';
      F.edt.Properties.ReadOnly := False;
      D.Cancel;
      Kontrol('S04 Vazgec son kayda doner', (F.btnKaydet.Caption = 'Kaydet*') and F.edt.Properties.ReadOnly);
      D.ToggleLayout;
      Kontrol('S04b yerlesim kipi', D.Customizing and F.lyt.Customization);
      D.Close;
      Kontrol('S05 Kapat: oturum yok, form ayakta, yerlesim kipi kapali', (TRadScriptDesigner.Active = nil) and LClosed and
        (F.btnKaydet.Caption = 'Kaydet*') and not F.lyt.Customization and (F.ComponentCount > 0));
    finally
      F.Free;
    end;

    // ---- pencere kipi ----
    P2 := LStore.AddPackage('p2', 3);
    P2.AddScript('Ozet', skWindow, '', OZET_SRC);
    P2.AddResource('Ozet.dfm', Bytes(OZET_DFM));
    LMsgs.Clear;
    D := TRadScriptDesigner.StartWindow('p2', 'Ozet');
    D.OnMessage := procedure(AMsg: string) begin LMsgs.Add(AMsg); end;
    Kontrol('S07 pencere oturumu: DFM yuklendi', (D.Mode = dmWindow) and (D.Form is TRadScriptForm) and (D.Form.FindComponent('btnTamam') is TButton) and
      (D.Form.Caption = 'Ozet') and D.IdeEngine.PaletteToolbar.Visible);
    LBtn := TButton.Create(D.Form);
    LBtn.Name := 'btnEk';
    LBtn.Parent := D.Form;
    LBtn.Caption := 'Ek';
    D.Save;
    R := P2.ResourceByName('Ozet.dfm');
    V := TEncoding.UTF8.GetString(R.Content);
    Kontrol('S07b DFM kaydi: kok sinif TOzetForm, yeni bilesen, olay SaveEvents''te', V.StartsWith('object OzetForm: TOzetForm') and V.Contains('btnEk') and
      V.Contains('btnTamam.OnClick=btnTamamClick') and not V.Contains('OnClick = ') and LStore.Saved and (LMsgs.Count = 1), V);
    // tasarimcinin yazdigi DFM calisma zamaninda yuklenir ve olay baglanir (SaveEvents yolu)
    F := TKasaK.CreateNew(nil);
    try
      P2.AddScript('KasaForm', skForm, 'TKasaK',
        'uses Ozet;'#13#10'procedure Form_AfterCreate(Sender: TObject);'#13#10'var F: TOzetForm;'#13#10 +
        'begin F := TOzetForm.Create(Form); F.Show; end;');
      LStore.Packages.Add(P2);   // ScriptsFor gorsun
      TRadScriptBinder.OnError := procedure(AForm: TCustomForm; E: Exception) begin LMsgs.Add('HATA ' + E.Message); end;
      TRadScriptBinder.Attach(F);
      if ScriptFormOf(F) <> nil then TButton(ScriptFormOf(F).FindComponent('btnTamam')).Click;
      Kontrol('S07b2 SaveEvents''li DFM calisma zamaninda baglanir', (ScriptFormOf(F) <> nil) and (ScriptFormOf(F).Caption = 'tik') and
        (ScriptFormOf(F).FindComponent('btnEk') <> nil), string.Join(';', LMsgs.ToArray));
      LStore.Packages.Extract(P2);
      P2.Scripts.Delete(P2.Scripts.Count - 1);
    finally
      F.Free;
    end;
    // kaynak bos -> iskelet; DFM'de bilinmeyen olay rutini -> uyari
    P2.ScriptByCode('Ozet').Source := '';
    P2.AddResource('x', nil);
    LMsgs.Clear;
    D.Save;
    Kontrol('S07c bos kaynak -> $FORM iskeleti', P2.ScriptByCode('Ozet').Source.Contains('{$FORM TOzetForm, Ozet.dfm}'), P2.ScriptByCode('Ozet').Source);
    Kontrol('S07d DFM olayi script''te yok -> uyari', (LMsgs.Count = 2) and LMsgs[1].Contains('btnTamamClick'), string.Join(';', LMsgs.ToArray));
    P2.ScriptByCode('Ozet').Source := '{$FORM TOzetForm, Ozet.dfm} begin x := ; end.';
    LMsgs.Clear;
    D.Save;
    Kontrol('S07e derleme hatasi uyari, kayit yine var', (LMsgs.Count = 2) and LMsgs[1].Contains('derlenemedi'), string.Join(';', LMsgs.ToArray));
    D.Close;
    Kontrol('S08 pencere oturumu kapandi', TRadScriptDesigner.Active = nil);
  finally
    TRadScriptBinder.Store := nil;
    LStoreIntf := nil;
    LMsgs.Free;
  end;
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  GLog := TStringList.Create;
  GErrors := TList<string>.Create;
  try
    try
      System.Classes.RegisterClass(TButton);
      TRadScriptDev.RegisterAll;
      TRadScriptEngine.RegisterClasses([TLogger, TButton, TForm]);
      Testler;
      OturumTestleri;
    except
      on E: Exception do
      begin
        Inc(GHata);
        Writeln('[ISTISNA] ', E.ClassName, ': ', E.Message);
      end;
    end;
  finally
    GErrors.Free;
    GLog.Free;
  end;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then ExitCode := 1;
end.
