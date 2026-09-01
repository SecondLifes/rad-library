program PermissionTest;

{$APPTYPE CONSOLE}

{
  TRadPermission'in dataset alan baglantisi sondasi.

  Modal duzenleyici (TPermission_Edit.Load) test edilemez - etkilesim ister.
  Olculen sey onun ALTINDAKI sozlesme: alandan okuma, alana yazma, kayit
  akisini ele gecirmeme, hatali yapilandirmada sessiz kalmama ve bagli
  dataset yok edilince sarkan isaretci birakmama.
}

uses
  System.SysUtils,
  System.Classes,
  Data.DB,
  Vcl.Forms,
  VirtualTable,
  mormot.core.base,   // RawUtf8
  rad.core        in '..\..\..\core\rad.core.pas',
  rad.permission  in '..\..\..\core\rad.permission.pas',
  Permission.Edit in '..\..\..\component\Permission.Edit.pas';

var
  GOk, GFail: Integer;

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
  CTree1 = '{permisson:[{kod:"Stok",adi:"Stok"}]}';
  CTree2 = '{permisson:[{kod:"Muhasebe",adi:"Muhasebe"}]}';

function YeniTablo(AOwner: TComponent; const ABaslangic: string): TVirtualTable;
begin
  Result := TVirtualTable.Create(AOwner);
  Result.AddField('YETKI', ftString, 4000);
  Result.Open;
  Result.Append;
  Result.FieldByName('YETKI').AsString := ABaslangic;
  Result.Post;
end;

{ ------------------------------------------------------------------ }

procedure AlandanOkuma;
var
  LSahip: TComponent;
  LTablo: TVirtualTable;
  LPerm : TRadPermission;
begin
  Writeln;
  Writeln('=== Alandan okuma ===');
  LSahip := TComponent.Create(nil);
  try
    LTablo := YeniTablo(LSahip, CTree1);
    LPerm  := TRadPermission.Create(LSahip);

    Chk(not LPerm.IsFieldLinked, '01 baglanti kurulmadan IsFieldLinked False');
    Chk(not LPerm.LoadFromField, '02 baglantisiz LoadFromField SESSIZ False');

    LPerm.DataSet   := LTablo;
    LPerm.TreeField := 'YETKI';

    Chk(LPerm.IsFieldLinked, '03 baglanti kurulunca IsFieldLinked True');
    Chk(LPerm.LoadFromField, '04 LoadFromField True dondu');
    Chk(LPerm.Tree = RawUtf8(CTree1), '05 Tree alandaki degeri aldi');
  finally
    LSahip.Free;
  end;
end;

procedure AlanaYazma;
var
  LSahip: TComponent;
  LTablo: TVirtualTable;
  LPerm : TRadPermission;
begin
  Writeln;
  Writeln('=== Alana yazma ===');
  LSahip := TComponent.Create(nil);
  try
    LTablo := YeniTablo(LSahip, CTree1);
    LPerm  := TRadPermission.Create(LSahip);
    LPerm.DataSet   := LTablo;
    LPerm.TreeField := 'YETKI';

    LPerm.Tree := RawUtf8(CTree2);
    Chk(LPerm.SaveToField, '06 SaveToField True dondu');
    Chk(LTablo.FieldByName('YETKI').AsString = CTree2, '07 alan yeni degeri tasiyor');
    Chk(LTablo.State = dsBrowse, '08 bilesen Edit/Post''u kendi tamamladi');
  finally
    LSahip.Free;
  end;
end;

procedure KayitAkisiniEleGecirmeme;
var
  LSahip: TComponent;
  LTablo: TVirtualTable;
  LPerm : TRadPermission;
begin
  Writeln;
  Writeln('=== Cagiran ZATEN duzenleme modundayken ===');
  LSahip := TComponent.Create(nil);
  try
    LTablo := YeniTablo(LSahip, CTree1);
    LPerm  := TRadPermission.Create(LSahip);
    LPerm.DataSet   := LTablo;
    LPerm.TreeField := 'YETKI';

    { Cagiran kendi duzenlemesini baslatmis; henuz Post etmeye hazir degil. }
    LTablo.Edit;
    LPerm.Tree := RawUtf8(CTree2);
    LPerm.SaveToField;

    Chk(LTablo.State = dsEdit,
      '09 dataset HALA dsEdit - bilesen cagiranin Post''unu CALMADI');
    Chk(LTablo.FieldByName('YETKI').AsString = CTree2,
      '10 alan yine de dolduruldu');

    LTablo.Post;
    Chk(LTablo.FieldByName('YETKI').AsString = CTree2,
      '11 cagiranin Post''undan sonra deger kalici');
  finally
    LSahip.Free;
  end;
end;

procedure HataliYapilandirma;
var
  LSahip: TComponent;
  LTablo: TVirtualTable;
  LBos  : TVirtualTable;
  LPerm : TRadPermission;
begin
  Writeln;
  Writeln('=== Hatali yapilandirma SESSIZ kalmamali ===');
  LSahip := TComponent.Create(nil);
  try
    LTablo := YeniTablo(LSahip, CTree1);
    LPerm  := TRadPermission.Create(LSahip);
    LPerm.Name := 'Perm1';

    ChkRaises(procedure begin LPerm.SaveToField end,
      '12 baglantisiz SaveToField -> ERadPermission');

    LPerm.DataSet   := LTablo;
    LPerm.TreeField := 'OLMAYAN_ALAN';
    ChkRaises(procedure begin LPerm.SaveToField end,
      '13 olmayan alan -> ERadPermission');

    LPerm.TreeField := 'YETKI';
    LTablo.Close;
    ChkRaises(procedure begin LPerm.SaveToField end,
      '14 kapali dataset -> ERadPermission');

    LBos := TVirtualTable.Create(LSahip);
    LBos.AddField('YETKI', ftString, 4000);
    LBos.Open;                        // acik ama KAYITSIZ
    LPerm.DataSet := LBos;
    ChkRaises(procedure begin LPerm.SaveToField end,
      '15 bos dataset -> ERadPermission');
  finally
    LSahip.Free;
  end;
end;

procedure SarkanIsaretci;
var
  LSahip: TComponent;
  LTablo: TVirtualTable;
  LPerm : TRadPermission;
begin
  Writeln;
  Writeln('=== FreeNotification (kit kurali) ===');
  LSahip := TComponent.Create(nil);
  try
    LTablo := YeniTablo(nil, CTree1);   // sahipsiz - elle yok edecegiz
    LPerm  := TRadPermission.Create(LSahip);
    LPerm.DataSet   := LTablo;
    LPerm.TreeField := 'YETKI';
    Chk(LPerm.DataSet = LTablo, '16 DataSet atandi');

    LTablo.Free;   // bilesen HALA yasiyor

    Chk(LPerm.DataSet = nil,
      '17 dataset yok edilince DataSet nil''lendi (sarkan isaretci YOK)');
    Chk(not LPerm.IsFieldLinked, '18 baglanti otomatik koptu');
    Chk(not LPerm.LoadFromField, '19 sonrasinda LoadFromField sessizce False');
  finally
    LSahip.Free;
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
    HataliYapilandirma;
    SarkanIsaretci;
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
