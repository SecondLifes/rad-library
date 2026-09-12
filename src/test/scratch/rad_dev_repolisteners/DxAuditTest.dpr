program DxAuditTest;

{$APPTYPE CONSOLE}

(* DevExpress MCP denetiminin (2026-09-12) bulgulari icin kirmizi-once sonda.

   Her blok bir bulguyu olcer; bulgu numaralari denetim raporundakilerdir:
     #1 dm.dev      Edit_tel OnValidate her degeri reddediyordu
     #2 Permission  Fix, BeforeUpdate + EndUpdate ile kilidi eksiye dusuruyordu
     #3 Permission  TRadPermission FDataBinding'i serbest birakmiyordu
     #4 Permission  SaveToField, DataSource nil iken AV veriyordu
     #5 Rad.Dev     pattern (detay seviyesi) kolonu master olunca uyari yoktu
     #6 Rad.Dev     odakli kayit yokken kolon degeri Unassigned (Null degil)
     #7 help.Dev    Parent'siz editorde _Host AV veriyordu

   Help.Dev EN SONDA: yalnizca en yakin class helper gorunur. *)

uses
  System.SysUtils, System.Classes, System.Variants, Vcl.Forms, Vcl.Controls,
  Data.DB, VirtualTable,
  cxEdit, cxTextEdit, cxMaskEdit, cxInplaceContainer, cxTL,
  cxGrid, cxGridLevel, cxGridTableView, cxGridCustomTableView, dxLayoutControl,
  mormot.core.base,
  rad.core        in '..\..\..\core\rad.core.pas',
  rad.permission  in '..\..\..\core\rad.permission.pas',
  Permission.Edit in '..\..\..\component\Permission.Edit.pas',
  dm.dev          in '..\..\..\share\dm.dev.pas',
  Rad.Dev,
  Help.Dev        in '..\..\..\core\help.Dev.pas';

type
  TTreeAccess = class(TcxCustomTreeList);

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
  Flush(Output);
end;

procedure Bilgi(const AAd, ADeger: string);
begin
  Writeln('  [BILGI] ', AAd, ': ', ADeger);
  Flush(Output);
end;

procedure IstisnaBekle(AProc: TProc; const AAd: string);
begin
  try
    AProc();
    Kontrol(AAd, False, 'istisna ATILMADI');
  except
    on E: ERadPermission do
      Kontrol(AAd, True);
    on E: Exception do
      Kontrol(AAd, False, 'yanlis tip: ' + E.ClassName + ': ' + E.Message);
  end;
end;

function Ayrilan: NativeUInt;
var
  LDurum: TMemoryManagerState;
  i: Integer;
begin
  GetMemoryManagerState(LDurum);
  Result := LDurum.TotalAllocatedMediumBlockSize + LDurum.TotalAllocatedLargeBlockSize;
  for i := Low(LDurum.SmallBlockTypeStates) to High(LDurum.SmallBlockTypeStates) do
    Inc(Result, NativeUInt(LDurum.SmallBlockTypeStates[i].UseableBlockSize) *
      LDurum.SmallBlockTypeStates[i].AllocatedBlockCount);
end;

{ #2 ---------------------------------------------------------------- }

procedure PermissionFix;
var
  LForm: TForm;
  LFr: TPermission_Edit;
  LJson: RawUtf8;
begin
  Writeln;
  Writeln('=== #2 TPermission_Edit.Fix kilit dengesi ===');
  LForm := TForm.CreateNew(nil);
  try
    LFr := TPermission_Edit.Create(LForm);
    LFr.Parent := LForm;
    LJson := '{"permisson":[{"id":"stok","name":"Stok","child":[{"id":"liste","name":"Liste"}]}]}';
    LFr.Load(@LJson);
    Kontrol('P01 agac iki dugumle yuklendi', LFr.cxTree.AbsoluteCount = 2,
      IntToStr(LFr.cxTree.AbsoluteCount));
    Kontrol('P02 alt dugumun kodu tam yol', LFr.cxTree.AbsoluteItems[1].Texts[1] = 'stok.liste',
      LFr.cxTree.AbsoluteItems[1].Texts[1]);

    LFr.actFixExecute(nil);

    Kontrol('P03 Fix alt dugum kodunu son parcaya indirdi',
      LFr.cxTree.AbsoluteItems[1].Texts[1] = 'liste', LFr.cxTree.AbsoluteItems[1].Texts[1]);
    Kontrol('P04 Fix sonrasi DataController.LockCount = 0',
      TTreeAccess(LFr.cxTree).DataController.LockCount = 0, IntToStr(TTreeAccess(LFr.cxTree).DataController.LockCount));
    { Kilit eksiye duserse sonraki dengeli bir BeginUpdate kilitlemez.
      IsLocked burada KULLANILAMAZ: 'not HandleAllocated' da iceriyor
      (cxInplaceContainer.pas:13484) ve gosterilmemis formda hep True. }
    LFr.cxTree.BeginUpdate;
    try
      Kontrol('P05 Fix sonrasi BeginUpdate sayaci 1 yapiyor',
        TTreeAccess(LFr.cxTree).DataController.LockCount = 1,
        IntToStr(TTreeAccess(LFr.cxTree).DataController.LockCount));
    finally
      LFr.cxTree.EndUpdate;
    end;
    Kontrol('P06 dengeli cift sonrasi sayac 0',
      TTreeAccess(LFr.cxTree).DataController.LockCount = 0,
      IntToStr(TTreeAccess(LFr.cxTree).DataController.LockCount));
  finally
    LForm.Free;
  end;
end;

{ #3 ---------------------------------------------------------------- }

procedure PermissionSizinti;
const
  CTur = 500;
  CTolerans = 8192;
var
  i: Integer;
  LOnce, LSonra: NativeUInt;
begin
  Writeln;
  Writeln('=== #3 TRadPermission bellek sizintisi ===');
  TRadPermission.Create(nil).Free;   // isinma: tek seferlik ayirmalar
  LOnce := Ayrilan;
  for i := 1 to CTur do
    TRadPermission.Create(nil).Free;
  LSonra := Ayrilan;
  Kontrol(Format('S01 %d yarat/yok et turu sizdirmiyor', [CTur]),
    (LSonra <= LOnce) or (LSonra - LOnce < CTolerans),
    Format('fark %d bayt', [Int64(LSonra) - Int64(LOnce)]));
end;

{ #4 ---------------------------------------------------------------- }

procedure PermissionKayit;
var
  LPerm: TRadPermission;
  LKaynak: TDataSource;
  LTablo: TVirtualTable;
begin
  Writeln;
  Writeln('=== #4 SaveToField hatali yapilandirmada ERadPermission ===');
  LTablo := TVirtualTable.Create(nil);
  try
    LTablo.AddField('YETKI', ftString, 4000);
    LKaynak := TDataSource.Create(nil);
    try
      LKaynak.DataSet := LTablo;
      LPerm := TRadPermission.Create(nil);
      try
        LPerm.Name := 'Perm1';
        LPerm.Storage := psDatabase;
        LPerm.Tree := '{"permisson":[]}';

        IstisnaBekle(procedure begin LPerm.SaveToField end,
          'K01 DataSource yok -> ERadPermission');

        LPerm.DataBinding.DataSource := LKaynak;
        LPerm.DataBinding.DataField := 'YETKI';
        IstisnaBekle(procedure begin LPerm.SaveToField end,
          'K02 dataset kapali -> ERadPermission');

        LTablo.Open;
        IstisnaBekle(procedure begin LPerm.SaveToField end,
          'K03 dataset bos -> ERadPermission');

        LTablo.Append;
        LTablo.FieldByName('YETKI').AsString := '';
        LTablo.Post;
        { "Alan yok" SaveToField'a ulasamiyor: acik dataset'te olmayan bir
          DataField atamak binding'in kendisinde EDatabaseError atiyor
          (olculdu). O yuzden burada sinanmiyor. }
        Kontrol('K05 dogru yapilandirmada SaveToField True', LPerm.SaveToField);
        Kontrol('K06 alan yazildi', LTablo.FieldByName('YETKI').AsString = '{"permisson":[]}',
          LTablo.FieldByName('YETKI').AsString);
      finally
        LPerm.Free;
      end;
    finally
      LKaynak.Free;
    end;
  finally
    LTablo.Free;
  end;
end;

{ #7 ---------------------------------------------------------------- }

procedure HostBekle(AEd: TcxTextEdit; const AAd: string);
begin
  try
    Kontrol(AAd, TcxCustomTextEdit(AEd)._Host = AEd);
  except
    on E: Exception do
      Kontrol(AAd, False, E.ClassName + ': ' + E.Message);
  end;
end;

procedure HostParentsiz;
var
  LEd: TcxTextEdit;
  LForm: TForm;
  LLay: TdxLayoutControl;
begin
  Writeln;
  Writeln('=== #7 grid disi editorde _Host ===');
  LEd := TcxTextEdit.Create(nil);
  try
    HostBekle(LEd, 'H01 Parent''siz editorde _Host editorun kendisi');
  finally
    LEd.Free;
  end;

  { Ayni satirin ikinci kolu: HER TdxLayoutControl'u detached edit form
    sanip Tag'i layout item'a cast ediyordu. Formdaki siradan bir layout
    control'deki editorde Tag = 0 -> nil uzerinden erisim. }
  LForm := TForm.CreateNew(nil);
  try
    LLay := TdxLayoutControl.Create(LForm);
    LLay.Parent := LForm;
    LEd := TcxTextEdit.Create(LForm);
    LEd.Parent := LLay;
    HostBekle(LEd, 'H02 siradan layout control''deki editorde _Host editorun kendisi');
  finally
    LForm.Free;
  end;
end;

{ #1 ---------------------------------------------------------------- }

procedure TelefonDogrulama;
var
  LDm: Tdm_dev;
  LForm: TForm;
  LEd: TcxMaskEdit;
  LSonuc: Boolean;
begin
  Writeln;
  Writeln('=== #1 dm.dev Edit_tel dogrulamasi ===');
  LDm := Tdm_dev.Create(nil);
  try
    LForm := TForm.CreateNew(nil);
    try
      LEd := TcxMaskEdit.Create(LForm);
      LEd.Parent := LForm;
      LEd.RepositoryItem := LDm.Edit_tel;

      LEd.EditValue := '(555)123-4567';
      try
        LSonuc := LEd.ValidateEdit(True);
        Kontrol('T01 gecerli numara kabul edilir', LSonuc);
      except
        on E: Exception do
          Kontrol('T01 gecerli numara kabul edilir', False, E.ClassName + ': ' + E.Message);
      end;

      { Olcum, iddia degil: maske eksik numarayi kendisi reddediyor mu? }
      LEd.EditValue := '(555)12';
      try
        LSonuc := LEd.ValidateEdit(False);
        Bilgi('T02 eksik numara (maske kendi basina)', BoolToStr(LSonuc, True));
      except
        on E: Exception do
          Bilgi('T02 eksik numara (maske kendi basina)', 'istisna ' + E.ClassName);
      end;
    finally
      LForm.Free;
    end;
  finally
    LDm.Free;
  end;
end;

{ #5 #6 ------------------------------------------------------------- }

procedure PatternMaster;
var
  LForm: TForm;
  LGrid: TcxGrid;
  LSeviyeM, LSeviyeD: TcxGridLevel;
  LGorM, LGorD: TcxGridTableView;
  LKolM, LKolD: TcxGridColumn;
  LCombo: TRadLookupComboBox;
  LUyari: string;
begin
  Writeln;
  Writeln('=== #5 #6 grid kolonu master ===');
  LForm := TForm.CreateNew(nil);
  try
    LGrid := TcxGrid.Create(LForm);
    LGrid.Parent := LForm;
    LSeviyeM := LGrid.Levels.Add;
    LGorM := LGrid.CreateView(TcxGridTableView) as TcxGridTableView;
    LSeviyeM.GridView := LGorM;
    LSeviyeD := LSeviyeM.Add;
    LGorD := LGrid.CreateView(TcxGridTableView) as TcxGridTableView;
    LSeviyeD.GridView := LGorD;
    LKolM := LGorM.CreateColumn;
    LKolD := LGorD.CreateColumn;

    Kontrol('G00 detay gorunumu pattern', LGorD.IsPattern);
    Kontrol('G00b ust gorunum pattern degil', not LGorM.IsPattern);
    Kontrol('G01 pattern kolonunun degeri okunamaz (Unassigned)', VarIsEmpty(_ValueOf(LKolD)),
      VarTypeAsText(VarType(_ValueOf(LKolD))));
    Kontrol('G02 odakli kayit yokken kolon degeri Unassigned, Null degil',
      VarIsEmpty(_ValueOf(LKolM)), VarTypeAsText(VarType(_ValueOf(LKolM))));

    LCombo := TRadLookupComboBox.Create(LForm);
    LCombo.Parent := LForm;
    LCombo.Properties.AMaster := LKolD;
    LUyari := LCombo.Properties.PullWarning;
    Kontrol('G03 pattern kolonu master olunca PullWarning soyluyor',
      Pos('pattern', LowerCase(LUyari)) > 0, LUyari);

    LCombo.Properties.AMaster := LKolM;
    LUyari := LCombo.Properties.PullWarning;
    Kontrol('G04 normal kolon pattern uyarisi uretmiyor',
      Pos('pattern', LowerCase(LUyari)) = 0, LUyari);
  finally
    LForm.Free;
  end;
end;

procedure Kos(AProc: TProc; const AAd: string);
begin
  try
    AProc();
  except
    on E: Exception do
    begin
      Inc(GHata);
      Writeln('  [PATLADI] ', AAd, ': ', E.ClassName, ': ', E.Message);
    end;
  end;
end;

begin
  Application.Initialize;
  Kos(PermissionFix, '#2');
  Kos(PermissionSizinti, '#3');
  Kos(PermissionKayit, '#4');
  Kos(HostParentsiz, '#7');
  Kos(TelefonDogrulama, '#1');
  Kos(PatternMaster, '#5/#6');
  Writeln;
  Writeln(Format('SONUC: %d gecti, %d kaldi.', [GBasari, GHata]));
  if GHata > 0 then
    ExitCode := 1;
end.
