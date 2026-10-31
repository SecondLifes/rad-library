program RadCheckListTest;

(*
  TRadCheckListBox / TRadDBCheckListBox: 'Ad=Deger' item'lari, EditValue 'A;AS',
  AValues / AValuesIn, kullanici olayi cakismasi, DFM, DB baglama.
*)

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Variants, Vcl.Forms,
  Vcl.Controls, Data.DB,
  cxEdit, cxCheckBox, cxCheckListBox, cxDBCheckListBox, cxGraphics, cxControls,
  cxLookAndFeels, cxLookAndFeelPainters, cxContainer, cxClasses, cxStyles, dxmdaset, Rad.Dev;

type
  TDenemeForm = class(TForm)
  end;

  { Kullanici tiklamasi: Mark, durumu degistirir ve EditValue'yu gunceller. }
  TTikla = class(TRadCheckListBox)
  public
    procedure Isaretle(AIndex: Integer; AOn: Boolean);
  end;

  TTiklaDB = class(TRadDBCheckListBox)
  public
    procedure Isaretle(AIndex: Integer; AOn: Boolean);
  end;

  TOlay = class
  public
    Cagri: Integer;
    procedure Durumdan(Sender: TObject; const ACheckStates: TcxCheckStates;
      out AEditValue: TcxEditValue);
  end;

var
  GBasari: Integer = 0;
  GHata: Integer = 0;

procedure TTikla.Isaretle(AIndex: Integer; AOn: Boolean);
begin
  Mark(AIndex, AOn);
end;

procedure TTiklaDB.Isaretle(AIndex: Integer; AOn: Boolean);
begin
  Mark(AIndex, AOn);
end;

procedure TOlay.Durumdan(Sender: TObject; const ACheckStates: TcxCheckStates;
  out AEditValue: TcxEditValue);
begin
  Inc(Cagri);
  AEditValue := 'KULLANICI';
end;

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
    Writeln('  [HATA] ', AAd);
  end;
  if ADetay <> '' then
    Writeln('         ', ADetay);
end;

function DfmMetni(AForm: TComponent): string;
var
  LBin, LTxt: TMemoryStream;
  LList: TStringList;
begin
  LBin := TMemoryStream.Create;
  LTxt := TMemoryStream.Create;
  LList := TStringList.Create;
  try
    LBin.WriteComponent(AForm);
    LBin.Position := 0;
    ObjectBinaryToText(LBin, LTxt);
    LTxt.Position := 0;
    LList.LoadFromStream(LTxt);
    Result := LList.Text;
  finally
    LList.Free;
    LTxt.Free;
    LBin.Free;
  end;
end;

function DfmdenOku(const AMetin: string): TDenemeForm;
var
  LSrc: TStringStream;
  LBin: TMemoryStream;
begin
  LSrc := TStringStream.Create(AMetin);
  LBin := TMemoryStream.Create;
  try
    ObjectTextToBinary(LSrc, LBin);
    LBin.Position := 0;
    Result := TDenemeForm.CreateNew(nil);
    LBin.ReadComponent(Result);
  finally
    LBin.Free;
    LSrc.Free;
  end;
end;

function Yeni(AForm: TForm): TTikla;
begin
  Result := TTikla.Create(AForm);
  Result.Parent := AForm;
  Result.SetBounds(10, 10, 200, 120);
end;

{ Gercek fare tiklamasi: DB baglamayi duzenleme moduna alan yol bu (Mark degil). }
procedure Tikla(AList: TcxCustomCheckListBox; AIndex: Integer);
var
  LR: TRect;
begin
  LR := AList.ItemRect(AIndex);
  AList.SetFocus;
  Application.ProcessMessages;
  SendMessage(AList.InnerControl.Handle, WM_LBUTTONDOWN, MK_LBUTTON,
    MakeLong(LR.Left + 6, LR.Top + (LR.Bottom - LR.Top) div 2));
  SendMessage(AList.InnerControl.Handle, WM_LBUTTONUP, 0,
    MakeLong(LR.Left + 6, LR.Top + (LR.Bottom - LR.Top) div 2));
  Application.ProcessMessages;
end;

procedure Cari(ALB: TRadCheckListBox);
begin
  ALB.Items.Clear;
  ALB.Items.AddItem('Alici', 'A');
  ALB.Items.AddItem('Satici', 'S');
  ALB.Items.AddItem('Alici ve Satici', 'AS');
end;

type
  TListHack = class(TcxCustomCheckListBox);

{ Stok (golgelenen) Items: State burada. }
function Durum(ALB: TcxCustomCheckListBox; AIndex: Integer): TcxCheckBoxState;
begin
  Result := TListHack(ALB).Items[AIndex].State;
end;

function TabanSayi(ALB: TcxCustomCheckListBox): Integer;
begin
  Result := TListHack(ALB).Items.Count;
end;

procedure Temel;
var
  LFrm: TDenemeForm;
  LLB: TTikla;
begin
  Writeln('=== Deger kipi ===');
  LFrm := TDenemeForm.CreateNew(nil);
  try
    LLB := Yeni(LFrm);
    Kontrol('R01 varsayilan: EditValueFormat cvfStatesString, deger listesi bos',
      (LLB.EditValueFormat = cvfStatesString) and (LLB.Items.Count = 0));
    LLB.Items.AddItem('Aktif', 't');
    LLB.Items.AddItem('Pasif', 'f');
    LLB.EditValue := 'f';
    Kontrol('R01b Items Text + Value; stok Items aynalandi',
      (LLB.Items[1].Text = 'Pasif') and (TabanSayi(LLB) = 2) and (Durum(LLB, 1) = cbsChecked) and
      (Durum(LLB, 0) = cbsUnchecked));
    LLB.Items[0].Value := 'x';
    Kontrol('R01c Value degisince secim ve metin korunur',
      (Durum(LLB, 1) = cbsChecked) and (LLB.Items[0].Text = 'Aktif') and (TabanSayi(LLB) = 2));
    Cari(LLB);
    Kontrol('R02 AddItem item + degeri kurar (Ad gorunur)',
      (LLB.Items.Count = 3) and (TabanSayi(LLB) = 3) and (LLB.Items[0].Text = 'Alici') and
      (LLB.Items[2].Text = 'Alici ve Satici'));
    LLB.EditValue := 'A;AS';
    Kontrol('R03 EditValue -> secimler',
      (Durum(LLB, 0) = cbsChecked) and (Durum(LLB, 1) = cbsUnchecked) and
      (Durum(LLB, 2) = cbsChecked));
    LLB.Isaretle(1, True);
    Kontrol('R04 kullanici isaretleyince EditValue degerlerle guncellenir',
      VarToStr(LLB.EditValue) = 'A;S;AS', VarToStr(LLB.EditValue));
    LLB.AValues := ['S'];
    Kontrol('R05 AValues atama/okuma',
      (VarToStr(LLB.EditValue) = 'S') and (Length(LLB.AValues) = 1) and
      (LLB.AValues[0] = 'S') and LLB.AHasValues);
    LLB.AValues := [];
    Kontrol('R05b bos secim: AHasValues False, EditValue bos',
      not LLB.AHasValues and (VarToStr(LLB.EditValue) = ''));
    LLB.AValues := ['A', 'S'];
    Kontrol('R06 AValuesIn SQL uretir',
      LLB.AValuesIn('cari_tip') = 'cari_tip in (''A'',''S'')', LLB.AValuesIn('cari_tip'));
    LLB.EditValue := 'X;A';
    Kontrol('R07 bilinmeyen deger atlanir', (Length(LLB.AValues) = 1) and (LLB.AValues[0] = 'A'));
    LLB.AValueDelimiter := '|';
    LLB.AValues := ['A', 'S'];
    Kontrol('R08 ayrac degisince EditValue ayraci degisir',
      VarToStr(LLB.EditValue) = 'A|S', VarToStr(LLB.EditValue));
    LLB.AValueDelimiter := ';';
    LLB.AValues := [];
    Kontrol('R09 AValuesIn secim yokken bos', LLB.AValuesIn('x') = '');
  finally
    LFrm.Free;
  end;
end;

procedure OlayCakismasi;
var
  LFrm: TDenemeForm;
  LLB: TTikla;
  LOlay: TOlay;
  i: Integer;
begin
  Writeln;
  Writeln('=== Olay cakismasi ve stok kip ===');
  LOlay := TOlay.Create;
  LFrm := TDenemeForm.CreateNew(nil);
  try
    LLB := Yeni(LFrm);
    LLB.OnCheckStatesToEditValue := LOlay.Durumdan;
    Cari(LLB);
    LLB.Isaretle(0, True);
    Kontrol('R10 kullanicinin kendi olayi kazanir (deger kipi devre disi)',
      (LOlay.Cagri > 0) and (VarToStr(LLB.EditValue) = 'KULLANICI'));
    Kontrol('R10b CheckWarning bunu bildirir', Pos('olay kazanir', LLB.CheckWarning) > 0,
      LLB.CheckWarning);
  finally
    LFrm.Free;
    LOlay.Free;
  end;

  LFrm := TDenemeForm.CreateNew(nil);
  try
    LLB := Yeni(LFrm);
    Cari(LLB);
    Kontrol('R11 deger kipinde olaylar bagli', Assigned(LLB.OnCheckStatesToEditValue) and
      Assigned(LLB.OnEditValueToCheckStates));
    LLB.EditValue := 'A;AS';
    LLB.Items.AddItem('Diger', 'D');
    Kontrol('R11b item eklenince mevcut secimler korunur',
      (LLB.Items.Count = 4) and (Durum(LLB, 0) = cbsChecked) and
      (Durum(LLB, 2) = cbsChecked) and (Durum(LLB, 3) = cbsUnchecked));
    for i := 0 to LLB.Items.Count - 1 do
      LLB.Items[i].Value := '';
    Kontrol('R12 Value''lar bosalinca olaylar birakilir (stok davranis), Items kalir',
      not Assigned(LLB.OnCheckStatesToEditValue) and
      not Assigned(LLB.OnEditValueToCheckStates) and (LLB.Items.Count = 4));
    Cari(LLB);
    LLB.Items.AddItem('Alici', 'A');
    Kontrol('R13 ayni deger iki item''da: CheckWarning bildirir',
      Pos('iki item', LLB.CheckWarning) > 0, LLB.CheckWarning);
    LLB.Items.Clear;
    LLB.Items.AddItem('X;Y', 'Z;W');
    Kontrol('R13b ayrac iceren deger: CheckWarning bildirir',
      Pos('ayraci', LLB.CheckWarning) > 0, LLB.CheckWarning);
  finally
    LFrm.Free;
  end;
end;

procedure Cok;
var
  LFrm: TDenemeForm;
  LLB: TTikla;
  i: Integer;
  LHata: Boolean;
begin
  Writeln;
  Writeln('=== 64+ item ===');
  LFrm := TDenemeForm.CreateNew(nil);
  try
    LLB := Yeni(LFrm);
    LHata := False;
    try
      for i := 1 to 70 do
        LLB.Items.AddItem(Format('Ad%d', [i]), Format('D%d', [i]));
    except
      LHata := True;
    end;
    Kontrol('R14 70 item istisnasiz (cvfInteger 64 siniri uygulanmaz)',
      not LHata and (LLB.Items.Count = 70));
    LLB.AValues := ['D1', 'D70'];
    Kontrol('R14b secim dogru', (Length(LLB.AValues) = 2) and (LLB.AValues[1] = 'D70'));
  finally
    LFrm.Free;
  end;
end;

procedure DfmSozlesmesi;
var
  LFrm, LFrm2: TDenemeForm;
  LLB, LYeni: TTikla;
  LMetin: string;
begin
  Writeln;
  Writeln('=== DFM ===');
  LFrm := TDenemeForm.CreateNew(nil);
  try
    LFrm.Name := 'Frm';
    LLB := Yeni(LFrm);
    LLB.Name := 'lbA';
    LMetin := DfmMetni(LFrm);
    Kontrol('R15 varsayilanken Value/RadSetting DFM''e yazilmaz',
      (Pos('Value', LMetin) = 0) and (Pos('RadSetting', LMetin) = 0));
    Cari(LLB);
    LLB.RadSetting.Key := 'cari_tip';
    LLB.RadSetting.Tag := 3;
    LMetin := DfmMetni(LFrm);
    Kontrol('R16 Items (Text + Value) ve RadSetting yazilir, Items tek kez',
      (Pos('Value = ''AS''', LMetin) > 0) and (Pos('RadSetting.Key = ''cari_tip''', LMetin) > 0) and
      (Pos('Items = <', LMetin) > 0) and (LMetin.CountChar('<') = 1), LMetin);
    LFrm2 := DfmdenOku(LMetin);
    try
      LYeni := nil;
      if LFrm2.FindComponent('lbA') is TRadCheckListBox then
        LYeni := TTikla(LFrm2.FindComponent('lbA'));
      Kontrol('R17 DFM geri okunur: item''lar, RadSetting, deger kipi',
        (LYeni <> nil) and (LYeni.Items.Count = 3) and
        (LYeni.RadSetting.Key = 'cari_tip') and (LYeni.RadSetting.Tag = 3) and
        Assigned(LYeni.OnCheckStatesToEditValue));
      if LYeni <> nil then
      begin
        LYeni.EditValue := 'S';
        Kontrol('R17b yuklenen kontrolde deger kipi calisir',
          (Durum(LYeni, 1) = cbsChecked) and (Durum(LYeni, 0) = cbsUnchecked));
      end;
    finally
      LFrm2.Free;
    end;
  finally
    LFrm.Free;
  end;
end;

procedure VeriBaglama;
var
  LFrm: TDenemeForm;
  LMD: TdxMemData;
  LFld: TStringField;
  LDS: TDataSource;
  LLB: TTiklaDB;
begin
  Writeln;
  Writeln('=== DB baglama ===');
  LFrm := TDenemeForm.CreateNew(nil);
  try
    LFrm.SetBounds(50, 50, 300, 250);
    LFrm.Show;
    LMD := TdxMemData.Create(LFrm);
    LFld := TStringField.Create(LFrm); LFld.FieldName := 'tip'; LFld.Size := 20; LFld.DataSet := LMD;
    LMD.Open;
    LMD.Append; LMD.FieldByName('tip').AsString := 'A;S'; LMD.Post;
    LMD.Append; LMD.FieldByName('tip').AsString := 'AS'; LMD.Post;
    LMD.First;
    LDS := TDataSource.Create(LFrm); LDS.DataSet := LMD;
    LLB := TTiklaDB.Create(LFrm);
    LLB.Parent := LFrm;
    LLB.SetBounds(10, 10, 200, 120);
    LLB.Items.AddItem('Alici', 'A');
    LLB.Items.AddItem('Satici', 'S');
    LLB.Items.AddItem('Alici ve Satici', 'AS');
    LLB.DataBinding.DataSource := LDS;
    LLB.DataBinding.DataField := 'tip';
    Application.ProcessMessages;
    Kontrol('R18 kayittaki deger secimlere yansir',
      (Durum(LLB, 0) = cbsChecked) and (Durum(LLB, 1) = cbsChecked) and
      (Durum(LLB, 2) = cbsUnchecked), VarToStr(LLB.EditValue));
    LMD.Next;
    Application.ProcessMessages;
    Kontrol('R19 kayit degisince secimler degisir',
      (Durum(LLB, 2) = cbsChecked) and (Durum(LLB, 0) = cbsUnchecked),
      VarToStr(LLB.EditValue));
    Tikla(LLB, 0);
    Writeln('    [BILGI] isaretleme sonrasi EditValue=', VarToStr(LLB.EditValue),
      ' dataset=', Ord(LMD.State), ' alan=', LMD.FieldByName('tip').AsString);
    Kontrol('R19b kullanici isaretlemesi kaydi duzenleme moduna alir', LMD.State = dsEdit);
    LMD.Post;
    Kontrol('R19c Post alana degerleri yazar (A;AS)', LMD.FieldByName('tip').AsString = 'A;AS',
      LMD.FieldByName('tip').AsString);
    Kontrol('R20 DB varyantinda AValues/AValuesIn calisir',
      (Length(LLB.AValues) > 0) and (LLB.AValuesIn('tip') <> ''));
    Kontrol('R21 FieldWarning: yeterince uzun metin alani sorun degil',
      LLB.FieldWarning = '', LLB.FieldWarning);
    LLB.DataBinding.DataField := '';
    LMD.Cancel;
  finally
    LFrm.Free;
  end;
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    Application.Initialize;
    RegisterClasses([TDenemeForm, TRadCheckListBox, TTikla]);
    Temel;
    OlayCakismasi;
    Cok;
    DfmSozlesmesi;
    VeriBaglama;
  except
    on E: Exception do
    begin
      Inc(GHata);
      Writeln('HATA: ', E.ClassName, ': ', E.Message);
    end;
  end;
  Writeln;
  Writeln(Format('=== SONUC: %d basarili, %d hata ===', [GBasari, GHata]));
  if GHata > 0 then
    Halt(1);
end.
