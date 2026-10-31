program PermissionTest;

{$APPTYPE CONSOLE}

{
  TRadPermission + TPermission_Edit sondasi.

  Modal duzenleyici (TPermission_Edit.Load) test edilemez - etkilesim ister.
  Olculen sey onun ALTINDAKI sozlesme:
    * alandan okuma / alana yazma (SaveToField gercekten Post eder mi),
    * kayit akisini ele gecirmeme, hatali yapilandirmada sessiz kalmama,
    * bagli dataset yok edilince sarkan isaretci birakmama,
    * agac duzenleyicide Ctrl+Asagi (act_ins) yeni dugumu SONRASINA ekler mi.

  Dataset: FireDAC TFDMemTable (ek kutuphane gerektirmez). Eski surum UniDAC
  VirtualTable ve kaldirilmis DataSet/TreeField API'sine bagliydi.
}

uses
  System.SysUtils,
  System.Classes,
  Data.DB,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Menus,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.Stan.Param,
  FireDAC.Stan.Async,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  FireDAC.DApt.Intf,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  cxTL,
  mormot.core.base,   // RawUtf8
  rad.core        in '..\..\..\core\rad.core.pas',
  rad.permission  in '..\..\..\core\rad.permission.pas',
  Permission.Edit in '..\..\..\component\Permission.Edit.pas';

type
  /// BeforePost'ta istisna atan dinleyici: Post'un basarisizligini taklit eder.
  TPostBozucu = class
    procedure BeforePost(ADataSet: TDataSet);
  end;

var
  GOk, GFail: Integer;

procedure TPostBozucu.BeforePost(ADataSet: TDataSet);
begin
  raise EDatabaseError.Create('kisit ihlali (test)');
end;

procedure Chk(ADogru: Boolean; const AMesaj: string);
begin
  if ADogru then
  begin
    Inc(GOk);
    Writeln('  [GECTI] ', AMesaj);
  end
  else
  begin
    Inc(GFail);
    Writeln('  [KALDI] ', AMesaj);
  end;
  Flush(Output);
end;

procedure ChkRaises(AProc: TProc; const AMesaj: string);
begin
  try
    AProc();
    Chk(False, AMesaj + ' (istisna ATILMADI)');
  except
    on E: ERadPermission do
      Chk(True, AMesaj);
    on E: Exception do
      Chk(False, AMesaj + ' (yanlis tip: ' + E.ClassName + ')');
  end;
end;

const
  CTree1 = '{"permisson":[{"id":"Stok","name":"Stok"}]}';
  CTree2 = '{"permisson":[{"id":"Muhasebe","name":"Muhasebe"}]}';

function YeniTablo(AOwner: TComponent; const ABaslangic: string): TFDMemTable;
begin
  Result := TFDMemTable.Create(AOwner);
  Result.FieldDefs.Add('YETKI', ftString, 4000);
  Result.CreateDataSet;
  Result.Append;
  Result.FieldByName('YETKI').AsString := ABaslangic;
  Result.Post;
end;

/// Bileseni TDataSource uzerinden tabloya baglar; TDataSource bilesen sahibine aittir.
function Bagla(APerm: TRadPermission; ATablo: TDataSet; const AAlan: string): TDataSource;
begin
  Result := TDataSource.Create(APerm.Owner);
  Result.DataSet := ATablo;
  APerm.DataBinding.DataSource := Result;
  APerm.DataBinding.DataField := AAlan;
end;

{ ------------------------------------------------------------------ }

procedure AlandanOkuma;
var
  LSahip: TComponent;
  LTablo: TFDMemTable;
  LPerm : TRadPermission;
begin
  Writeln;
  Writeln('=== Alandan okuma ===');
  LSahip := TComponent.Create(nil);
  try
    LTablo := YeniTablo(LSahip, CTree1);
    LPerm  := TRadPermission.Create(LSahip);

    Chk(not LPerm.DataBinding.IsDataSourceLive, '01 baglanti kurulmadan IsDataSourceLive False');
    Chk(not LPerm.LoadFromField, '02 baglantisiz LoadFromField SESSIZ False');

    Bagla(LPerm, LTablo, 'YETKI');

    Chk(LPerm.DataBinding.IsDataSourceLive, '03 baglanti kurulunca IsDataSourceLive True');
    Chk(LPerm.LoadFromField, '04 LoadFromField True dondu');
    Chk(LPerm.Tree = RawUtf8(CTree1), '05 Tree alandaki degeri aldi');
  finally
    LSahip.Free;
  end;
end;

procedure AlanaYazma;
var
  LSahip: TComponent;
  LTablo: TFDMemTable;
  LPerm : TRadPermission;
begin
  Writeln;
  Writeln('=== Alana yazma (Post dahil) ===');
  LSahip := TComponent.Create(nil);
  try
    LTablo := YeniTablo(LSahip, CTree1);
    LPerm  := TRadPermission.Create(LSahip);
    Bagla(LPerm, LTablo, 'YETKI');

    LPerm.Tree := RawUtf8(CTree2);
    Chk(LPerm.SaveToField, '06 SaveToField True dondu');
    Chk(LTablo.State = dsBrowse, '07 bilesen Edit/Post''u kendi tamamladi (dsBrowse)');
    { Cancel de dsBrowse'a doner; ayirt eden alan degeridir: Cancel olsaydi
      eski deger geri gelirdi. }
    Chk(LTablo.FieldByName('YETKI').AsString = CTree2, '08 alan yeni degeri TASIYOR (Post edildi)');
    LTablo.First;
    Chk(LTablo.FieldByName('YETKI').AsString = CTree2, '09 kayit yeniden okununca da yeni deger');
  finally
    LSahip.Free;
  end;
end;

procedure KayitAkisiniEleGecirmeme;
var
  LSahip: TComponent;
  LTablo: TFDMemTable;
  LPerm : TRadPermission;
begin
  Writeln;
  Writeln('=== Cagiran ZATEN duzenleme modundayken ===');
  LSahip := TComponent.Create(nil);
  try
    LTablo := YeniTablo(LSahip, CTree1);
    LPerm  := TRadPermission.Create(LSahip);
    Bagla(LPerm, LTablo, 'YETKI');

    { Cagiran kendi duzenlemesini baslatmis; henuz Post etmeye hazir degil. }
    LTablo.Edit;
    LPerm.Tree := RawUtf8(CTree2);
    LPerm.SaveToField;

    Chk(LTablo.State = dsEdit,
      '10 dataset HALA dsEdit - bilesen cagiranin Post''unu CALMADI');
    Chk(LTablo.FieldByName('YETKI').AsString = CTree2,
      '11 alan yine de dolduruldu');

    LTablo.Post;
    Chk(LTablo.FieldByName('YETKI').AsString = CTree2,
      '12 cagiranin Post''undan sonra deger kalici');
  finally
    LSahip.Free;
  end;
end;

procedure PostBasarisiz;
var
  LSahip : TComponent;
  LTablo : TFDMemTable;
  LPerm  : TRadPermission;
  LBozucu: TPostBozucu;
  LAtildi: Boolean;
begin
  Writeln;
  Writeln('=== Post basarisiz olursa dataset askida kalmamali ===');
  LSahip  := TComponent.Create(nil);
  LBozucu := TPostBozucu.Create;
  try
    LTablo := YeniTablo(LSahip, CTree1);
    LPerm  := TRadPermission.Create(LSahip);
    Bagla(LPerm, LTablo, 'YETKI');

    LTablo.BeforePost := LBozucu.BeforePost;
    LPerm.Tree := RawUtf8(CTree2);
    LAtildi := False;
    try
      LPerm.SaveToField;
    except
      on EDatabaseError do
        LAtildi := True;
    end;

    Chk(LAtildi, '13 Post hatasi sessizce yutulmadi, aynen yukari gitti');
    Chk(LTablo.State = dsBrowse, '14 dataset dsEdit''te ASKIDA kalmadi (Cancel edildi)');
    Chk(LTablo.FieldByName('YETKI').AsString = CTree1, '15 eski deger korundu');
  finally
    LBozucu.Free;
    LSahip.Free;
  end;
end;

procedure HataliYapilandirma;
var
  LSahip: TComponent;
  LTablo: TFDMemTable;
  LBos  : TFDMemTable;
  LPerm : TRadPermission;
  LSrc  : TDataSource;
  LAtildi: Boolean;
begin
  Writeln;
  Writeln('=== Hatali yapilandirma SESSIZ kalmamali ===');
  LSahip := TComponent.Create(nil);
  try
    LTablo := YeniTablo(LSahip, CTree1);
    LPerm  := TRadPermission.Create(LSahip);
    LPerm.Name := 'Perm1';

    ChkRaises(procedure begin LPerm.SaveToField end,
      '16 baglantisiz SaveToField -> ERadPermission');

    LSrc := Bagla(LPerm, LTablo, 'YETKI');
    { Olmayan alan adi ATANIRKEN VCL zaten EDatabaseError atar (GetFieldProperty);
      CheckLink'e hic gelinmez. Onemli olan sessiz kalmamasi. }
    LAtildi := False;
    try
      LPerm.DataBinding.DataField := 'OLMAYAN_ALAN';
    except
      on EDatabaseError do
        LAtildi := True;
    end;
    Chk(LAtildi, '17 olmayan alan adi atanirken EDatabaseError (sessiz degil)');

    LPerm.DataBinding.DataField := 'YETKI';
    LTablo.FieldByName('YETKI').ReadOnly := True;
    ChkRaises(procedure begin LPerm.SaveToField end,
      '18 salt okunur alan -> ERadPermission (DB hatasi degil)');
    Chk(LTablo.State = dsBrowse, '19 salt okunur denemede dataset dsBrowse');
    LTablo.FieldByName('YETKI').ReadOnly := False;

    LTablo.Close;
    ChkRaises(procedure begin LPerm.SaveToField end,
      '20 kapali dataset -> ERadPermission');

    LBos := TFDMemTable.Create(LSahip);
    LBos.FieldDefs.Add('YETKI', ftString, 4000);
    LBos.CreateDataSet;               // acik ama KAYITSIZ
    LSrc.DataSet := LBos;
    ChkRaises(procedure begin LPerm.SaveToField end,
      '21 bos dataset -> ERadPermission');
  finally
    LSahip.Free;
  end;
end;

procedure SarkanIsaretci;
var
  LSahip: TComponent;
  LTablo: TFDMemTable;
  LPerm : TRadPermission;
  LSrc  : TDataSource;
begin
  Writeln;
  Writeln('=== FreeNotification (kit kurali) ===');
  LSahip := TComponent.Create(nil);
  try
    LTablo := YeniTablo(nil, CTree1);   // sahipsiz - elle yok edecegiz
    LPerm  := TRadPermission.Create(LSahip);
    LSrc   := Bagla(LPerm, LTablo, 'YETKI');
    Chk(LSrc.DataSet = LTablo, '22 DataSet atandi');

    LTablo.Free;   // bilesen HALA yasiyor

    Chk(LSrc.DataSet = nil,
      '23 dataset yok edilince DataSet nil''lendi (sarkan isaretci YOK)');
    Chk(not LPerm.DataBinding.IsDataSourceLive, '24 baglanti otomatik koptu');
    Chk(not LPerm.LoadFromField, '25 sonrasinda LoadFromField sessizce False');

    LSrc.Free;     // DataSource da bilesenden once gidebilir
    Chk(LPerm.DataBinding.DataSource = nil, '26 DataSource yok edilince baglanti nil');
  finally
    LSahip.Free;
  end;
end;

{ ------------------------------------------------------------------ }

function Adlar(ANode: TcxTreeListNode): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to ANode.Count - 1 do
    Result := Result + ANode.Items[i].Texts[0] + ',';
end;

{ DX, duzenlenmeden birakilan "ekleniyor" durumundaki bos dugumu odak
  ayrilinca siler (DB Insert iptali gibi). Test ilerlerken yeni dugumu
  onaylar. }
procedure Tamamla(AFr: TPermission_Edit; ANode: TcxTreeListNode; const AAd: string);
begin
  ANode.Texts[0] := AAd;
  AFr.cxTree.Post;
end;

procedure AltaEkle;
const
  CJson = '{"permisson":[{"id":"a","name":"A","child":[' +
    '{"id":"x","name":"X"},{"id":"y","name":"Y"}]},{"id":"b","name":"B"}]}';
var
  LForm: TForm;
  LFr  : TPermission_Edit;
  LJson: RawUtf8;
  LA, LYeni: TcxTreeListNode;
begin
  Writeln;
  Writeln('=== Ctrl+Asagi (act_ins): yeni dugum SONRASINA eklenir ===');
  LForm := TForm.CreateNew(nil);
  try
    LForm.SetBounds(100, 100, 600, 500);
    LFr := TPermission_Edit.Create(LForm);
    LFr.Parent := LForm;
    LFr.Align := alClient;
    LFr.EditMode := True;
    LJson := CJson;
    LFr.Load(@LJson);
    LForm.Show;
    Application.ProcessMessages;
    LA := LFr.cxTree.Root.Items[0];
    Chk(Adlar(LA) = 'X,Y,', '27 baslangic agaci: a -> X,Y');

    { kardesi OLAN dugumun sonrasi: X'in sonrasi = X ile Y arasi }
    LFr.cxTree.FocusedNode := LA.Items[0];
    LFr.act_ins.Execute;
    Chk(LA.Count = 3, '28 bir dugum eklendi');
    LYeni := LA.Items[1];
    Chk((LA.Items[0].Texts[0] = 'X') and (LA.Items[2].Texts[0] = 'Y'),
      '29 yeni dugum X ile Y ARASINDA (ustune degil, altina)');
    Chk(LFr.cxTree.FocusedNode = LYeni, '30 odak yeni dugumde');
    Chk(LYeni.Texts[1] = 'a.', '31 yeni dugumun kodu ust dugumun onekiyle basliyor');
    Tamamla(LFr, LYeni, 'N1');

    { SON cocugun sonrasi: Y'nin sonrasi = listenin sonu }
    LFr.cxTree.FocusedNode := LA.Items[2];
    LFr.act_ins.Execute;
    Chk((LA.Count = 4) and (LA.Items[2].Texts[0] = 'Y'),
      '32 son cocugun sonrasina eklendi, Y yerinde');
    Chk(LFr.cxTree.FocusedNode = LA.Items[3], '33 odak yeni son dugumde');
    Tamamla(LFr, LA.Items[3], 'N2');

    { ust seviye: a'nin sonrasi = a ile b arasi }
    LFr.cxTree.FocusedNode := LA;
    LFr.act_ins.Execute;
    Chk(LFr.cxTree.Root.Count = 3, '34 ust seviyede bir dugum eklendi');
    Chk((LFr.cxTree.Root.Items[0] = LA) and (LFr.cxTree.Root.Items[2].Texts[0] = 'B'),
      '35 ust seviyede a ile B arasinda');
    Chk(LFr.cxTree.Root.Items[1].Parent = LFr.cxTree.Root,
      '36 yeni dugum ust seviyede (a''nin cocugu OLMADI)');
    Tamamla(LFr, LFr.cxTree.Root.Items[1], 'N3');

    { ust seviyenin SONU }
    LFr.cxTree.FocusedNode := LFr.cxTree.Root.Items[2];
    LFr.act_ins.Execute;
    Chk((LFr.cxTree.Root.Count = 4) and (LFr.cxTree.Root.Items[2].Texts[0] = 'B'),
      '37 ust seviye sonuna eklendi, B yerinde');
  finally
    LForm.Free;
  end;
end;

function YeniFrame(AForm: TForm; const AJson: RawUtf8; AEdit: Boolean): TPermission_Edit;
var
  LJson: RawUtf8;
begin
  Result := TPermission_Edit.Create(AForm);
  Result.Parent := AForm;
  Result.Align := alClient;
  Result.EditMode := AEdit;
  LJson := AJson;
  Result.Load(@LJson);
end;

procedure Sablonlar;
const
  CJson = '{"permisson":[{"id":"cari","name":"Cari"},{"id":"kasa","name":"Kasa"},' +
    '{"id":"banka","name":"Banka"}]}';
var
  LForm: TForm;
  LFr  : TPermission_Edit;
  LRes : TRadTemplateResult;
  LRoot: TcxTreeListNode;
  LYeni, LOzel: TcxTreeListNode;
begin
  Writeln;
  Writeln('=== Sablon sistemi (CRUD tohumu, coklu uygulama, sablon olarak kaydet) ===');
  LForm := TForm.CreateNew(nil);
  try
    LForm.SetBounds(100, 100, 600, 500);
    LFr := YeniFrame(LForm, CJson, True);
    LForm.Show;
    Application.ProcessMessages;
    LRoot := LFr.cxTree.Root;

    Chk(LFr.itmSablonlar.Count = 1, '38 sablon anahtari yokken hazir CRUD tohumlandi');
    Chk(LFr.itmSablonlar.Items[0].Caption = 'Ekle - Sil - Düzenle', '39 tohum sablonun adi');

    { A: SECILI dugumlerin hepsine }
    LRoot.Items[0].Focused := True;
    LRoot.Items[1].Selected := True;
    LRoot.Items[2].Selected := True;
    Chk(LFr.cxTree.SelectionCount = 3, '40 uc dugum secili (coklu secim acik)');
    LRes := LFr.ApplyTemplate(0);
    Chk((LRes.Targets = 3) and (LRes.Added = 9) and (LRes.Skipped = 0) and (LRes.Failed = 0),
      Format('41 uc dugume uygulandi: 9 eklendi (%d/%d/%d/%d)',
        [LRes.Targets, LRes.Added, LRes.Skipped, LRes.Failed]));
    Chk((LRoot.Items[0].Count = 3) and (LRoot.Items[0].Items[0].Texts[1] = 'cari.ekle') and
        (LRoot.Items[2].Items[2].Texts[1] = 'banka.edit'),
      '42 kodlar ust dugumun onekiyle olustu (cari.ekle, banka.edit)');

    { tekrar: mesaj kutusu YOK (konsolu kilitlerdi), hepsi atlanir }
    LRes := LFr.ApplyTemplate(0);
    Chk((LRes.Added = 0) and (LRes.Skipped = 9),
      Format('43 tekrar uygulama: 0 eklendi, 9 atlandi, mesaj kutusu yok (%d/%d)',
        [LRes.Added, LRes.Skipped]));
    Chk((LRoot.Items[0].Count = 3) and (LRoot.Items[1].Count = 3),
      '44 tekrarlar COGALMADI');

    { kismi: cari'den sil'i kaldir, yalniz cari'ye uygula }
    LRoot.Items[0].Items[1].Delete;
    LFr.cxTree.ClearSelection;
    LRoot.Items[0].Focused := True;
    LRes := LFr.ApplyTemplate(0);
    Chk((LRes.Targets = 1) and (LRes.Added = 1) and (LRes.Skipped = 2),
      Format('45 kismi: eksik olan 1 eklendi, 2 atlandi (%d/%d/%d)',
        [LRes.Targets, LRes.Added, LRes.Skipped]));

    { gecersiz indeks sessizce yutulmaz ama zarar da vermez }
    LRes := LFr.ApplyTemplate(99);
    Chk((LRes.Targets = 0) and (LRes.Added = 0), '46 gecersiz sablon indeksi: bir sey yapilmadi');

    { B: sablon olarak kaydet }
    Chk(LFr.SaveAsTemplate(LRoot.Items[1], 'Kasa Seti', 'Kasa Seti'), '47 SaveAsTemplate True');
    Chk(LFr.itmSablonlar.Count = 2, '48 menude iki sablon');
    LYeni := LFr.cxTree.Add;
    LYeni.Texts[0] := 'Yeni';
    LYeni.Texts[1] := 'yeni';
    LFr.cxTree.ClearSelection;
    LYeni.Focused := True;
    LRes := LFr.ApplyTemplate(1);
    Chk((LRes.Added = 3) and (LYeni.Items[0].Texts[1] = 'yeni.ekle'),
      '49 kaydedilen sablon baska dugumde calisti (yeni.ekle)');
    Chk(LFr.SaveAsTemplate(LRoot.Items[1], 'kasa seti', 'Kasa Seti 2') and
        (LFr.itmSablonlar.Count = 2),
      '50 ayni kodlu sablon DEGISTIRILDI, cogalmadi');
    Chk(not LFr.SaveAsTemplate(LYeni.Items[0], 'x', 'x'), '51 alt dugumsuz dugum sablon olmaz');
    Chk(not LFr.SaveAsTemplate(LRoot.Items[1], '  ', 'x'), '52 bos sablon kodu reddedilir');
    Chk(LFr.itmSablonlar.Count = 2, '53 reddedilenler menuyu degistirmedi');

    { ic ice sablon: banka -> ozel -> detay }
    LOzel := LRoot.Items[2].AddChild;
    LOzel.Texts[0] := 'Özel';
    LOzel.Texts[1] := 'banka.ozel';
    LOzel.AddChild;
    LOzel.Items[0].Texts[0] := 'Detay';
    LOzel.Items[0].Texts[1] := 'banka.ozel.detay';
    Chk(LFr.SaveAsTemplate(LRoot.Items[2], 'Banka Seti', 'Banka Seti'), '54 ic ice sablon kaydedildi');
    LYeni := LFr.cxTree.Add;
    LYeni.Texts[0] := 'Yeni2';
    LYeni.Texts[1] := 'yeni2';
    LFr.cxTree.ClearSelection;
    LYeni.Focused := True;
    LFr.ApplyTemplate(2);
    Chk((LYeni.Count = 4) and (LYeni.Items[3].Texts[1] = 'yeni2.ozel') and
        (LYeni.Items[3].Count = 1) and (LYeni.Items[3].Items[0].Texts[1] = 'yeni2.ozel.detay'),
      '55 ic ice sablon kodlari yeni oneke gore yeniden turedi (yeni2.ozel.detay)');
  finally
    LForm.Free;
  end;

  { tohum KURALLARI }
  LForm := TForm.CreateNew(nil);
  try
    LFr := YeniFrame(LForm, '{"permisson":[],"sablon":[]}', True);
    Chk(LFr.itmSablonlar.Count = 0, '56 sablon anahtari BOS dizi olarak varsa yeniden tohumlanmaz');
  finally
    LForm.Free;
  end;
  LForm := TForm.CreateNew(nil);
  try
    LFr := YeniFrame(LForm, '{"permisson":[]}', False);
    Chk(LFr.itmSablonlar.Count = 0, '57 salt okunur acilista tohumlanmaz');
  finally
    LForm.Free;
  end;
end;

begin
  GOk := 0;
  GFail := 0;
  Application.Initialize;
  try
    AlandanOkuma;
    AlanaYazma;
    KayitAkisiniEleGecirmeme;
    PostBasarisiz;
    HataliYapilandirma;
    SarkanIsaretci;
    AltaEkle;
    Sablonlar;
  except
    on E: Exception do
    begin
      Inc(GFail);
      Writeln('  [PATLADI] ', E.ClassName, ': ', E.Message);
    end;
  end;

  Writeln;
  Writeln(Format('SONUC: %d gecti, %d kaldi.', [GOk, GFail]));
  if GFail > 0 then
    ExitCode := 1;
end.
