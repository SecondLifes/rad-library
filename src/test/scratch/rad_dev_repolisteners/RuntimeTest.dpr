program RuntimeTest;

(*
  CANLI davranis sondasi - gercek pencere, gercek mesaj dongusu.

  Onceki sondalarin OLCEMEDIGI uc sey:
    A) SearchDelay geciktiricisi: hizli tuslar 1 arama mi uretiyor, 5 mi?
    B) Gridde INPLACE duzenleme kaskadi tetikliyor mu, ASource ne geliyor?
    C) help.Dev'deki _Host, inplace editorden KOLONU dondurebiliyor mu?

  Tus vurusu icin DoEditKeyPress dogrudan cagriliyor (erisim sinifiyla).
  Windows'un tusu teslim etmesi bizim kodumuz degil; olculmek istenen sey
  "tus geldiginde geciktirici dogru davraniyor mu".

  ! GORUNUR PENCERE SART: B ve C bolumleri, pencere MINIMIZE calistirilirsa
    olculemez - DevExpress gorunmeyen bir gridde inplace editor ACMAZ
    (olculdu: -WindowStyle Minimized ile EditingItem nil kaliyor). Testi
    normal pencereyle calistirin. A bolumu pencereden bagimsiz calisir.
*)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Variants, Winapi.Windows,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls,
  cxEdit, cxTextEdit, cxMaskEdit, cxDropDownEdit, cxLookupEdit, cxDBLookupEdit,
  cxDBLookupComboBox,
  cxGridCustomTableView, cxGridTableView, cxGridLevel, cxGrid,
  cxGridCustomView, cxCustomData,
  cxGraphics, cxControls, cxLookAndFeels, cxContainer, cxClasses,
  Rad.Dev, Help.Dev;

type
  { Erisim sinifi: DoEditKeyPress protected. }
  TEditAccess = class(TRadLookupComboBox);

  TSayac = class
  public
    Arama: Integer;
    Kaskad: Integer;
    SonKaynak: TComponent;
    SonHedef: TComponent;
    SonHostSinif: string;
    procedure OnArama(Sender: TRadLookupComboBoxProperties;
      ASource: TComponent; var AText, ATail: string; ANext: Boolean);
    procedure OnKaskad(Sender: TRadLookupComboBoxProperties;
      ASource, ATarget: TComponent; const AValue: Variant);
  end;

procedure TSayac.OnArama(Sender: TRadLookupComboBoxProperties;
  ASource: TComponent; var AText, ATail: string; ANext: Boolean);
begin
  Inc(Arama);
end;

procedure TSayac.OnKaskad(Sender: TRadLookupComboBoxProperties;
  ASource, ATarget: TComponent; const AValue: Variant);
var
  LHost: TComponent;
begin
  Inc(Kaskad);
  SonKaynak := ASource;
  SonHedef := ATarget;
  SonHostSinif := '<yok>';
  if ASource is TcxCustomTextEdit then
  begin
    LHost := TcxCustomTextEdit(ASource)._Host;
    if LHost <> nil then
      SonHostSinif := LHost.ClassName + '/' + LHost.Name;
  end;
end;

function Ad(AC: TComponent): string;
begin
  if AC = nil then
    Result := '<nil>'
  else if AC.Name <> '' then
    Result := AC.ClassName + '/' + AC.Name
  else
    Result := AC.ClassName;
end;

{ Mesaj dongusunu ADilisecek kadar dondur - TTimer ancak boyle atesler. }
procedure Bekle(AMs: Cardinal);
var
  LBitis: UInt64;
begin
  LBitis := GetTickCount64 + AMs;
  while GetTickCount64 < LBitis do
  begin
    Application.ProcessMessages;
    Sleep(5);
  end;
end;

var
  LForm: TForm;
  LSayac: TSayac;
  LEdit, LHedef: TRadLookupComboBox;
  LGrid: TcxGrid;
  LLvl: TcxGridLevel;
  LView: TcxGridTableView;
  LCol: TcxGridColumn;
  LProps: TRadLookupComboBoxProperties;
  LInplace: TcxCustomEdit;
  i: Integer;
  LKey: Char;

begin
  try
    Application.Initialize;
    LSayac := TSayac.Create;
    LForm := TForm.CreateNew(nil);
    try
      LForm.Name := 'RuntimeFrm';
      LForm.Width := 700;
      LForm.Height := 500;
      LForm.Position := poScreenCenter;
      LForm.Show;
      Bekle(200);

      LHedef := TRadLookupComboBox.Create(LForm);
      LHedef.Name := 'Hedef';
      LHedef.Parent := LForm;
      LHedef.Left := 20; LHedef.Top := 20;

      { ══ A) SearchDelay ══════════════════════════════════════════════ }
      Writeln('=== A) SearchDelay geciktiricisi ===');
      LEdit := TRadLookupComboBox.Create(LForm);
      LEdit.Name := 'Arama';
      LEdit.Parent := LForm;
      LEdit.Left := 20; LEdit.Top := 60; LEdit.Width := 200;
      LEdit.Properties.AOnSearch := LSayac.OnArama;

      { A1: geciktirici KAPALI }
      LEdit.Properties.ASearchDelay := 0;
      LSayac.Arama := 0;
      for LKey in 'ankara' do
        TEditAccess(LEdit).DoEditKeyPress(LKey);
      Bekle(600);
      Writeln(Format('  SearchDelay=0   : 6 tus -> OnSearch %d kez  (geciktirici yok)',
        [LSayac.Arama]));

      { A2: geciktirici ACIK }
      LEdit.Properties.ASearchDelay := 250;
      LSayac.Arama := 0;
      for LKey in 'ankara' do
      begin
        TEditAccess(LEdit).DoEditKeyPress(LKey);
        Bekle(30);   { tuslar arasi 30 ms - insan hizindan hizli }
      end;
      Writeln(Format('  SearchDelay=250 : tuslar bitti, hemen -> OnSearch %d kez  (0 olmali)',
        [LSayac.Arama]));
      Bekle(500);
      Writeln(Format('                    500 ms sonra   -> OnSearch %d kez  (1 olmali)',
        [LSayac.Arama]));

      { A3: MinSearchLength geciktirici yolunda da gecerli mi? }
      LEdit.Properties.AMinSearchLength := 4;
      LEdit.Properties.ASearchDelay := 200;
      LSayac.Arama := 0;
      LEdit.Properties.TimedSearch(LEdit, 'ab');
      Bekle(50);
      Writeln(Format('  MinSearchLength=4, "ab" -> OnSearch %d kez  (0 olmali)', [LSayac.Arama]));
      LEdit.Properties.TimedSearch(LEdit, 'abcd');
      Writeln(Format('                     "abcd" -> OnSearch %d kez  (1 olmali)', [LSayac.Arama]));
      LEdit.Properties.AMinSearchLength := 0;

      { ══ B + C) Grid inplace ═════════════════════════════════════════ }
      Writeln;
      Writeln('=== B) Gridde inplace duzenleme kaskadi ===');
      LGrid := TcxGrid.Create(LForm);
      LGrid.Parent := LForm;
      LGrid.Left := 20; LGrid.Top := 110;
      LGrid.Width := 620; LGrid.Height := 300;
      LGrid.Name := 'Grid';
      LLvl := LGrid.Levels.Add;
      LView := LGrid.CreateView(TcxGridTableView) as TcxGridTableView;
      LView.Name := 'View';
      LLvl.GridView := LView;

      LCol := LView.CreateColumn;
      LCol.Name := 'colSehir';
      LCol.Caption := 'Sehir';
      LCol.PropertiesClass := TRadLookupComboBoxProperties;
      LProps := TRadLookupComboBoxProperties(LCol.Properties);
      LProps.AComponent1 := LHedef;
      LProps.AOnCascade := LSayac.OnKaskad;
      LView.OptionsData.Editing := True;
      LView.OptionsSelection.CellSelect := True;

      LView.DataController.RecordCount := 2;
      Bekle(150);
      Writeln('  kolon.Properties sinifi : ', LCol.Properties.ClassName);
      Writeln('  kayit sayisi            : ', LView.DataController.RecordCount);

      { Pencereyi one getir ve gride ODAK ver - ShowEdit odaksiz calismiyor. }
      SetForegroundWindow(LForm.Handle);
      Bekle(150);
      if LGrid.CanFocus then
        LGrid.SetFocus;
      Bekle(150);
      LView.Controller.FocusedRecordIndex := 0;
      LView.Controller.FocusedItemIndex := LCol.Index;
      Bekle(150);
      Writeln('  grid odakli mi          : ', BoolToStr(LGrid.Focused, True));
      Writeln('  odakli kayit / kolon    : ',
        LView.Controller.FocusedRecordIndex, ' / ', LView.Controller.FocusedItemIndex);

      LView.Controller.EditingItem := LCol;
      Bekle(250);
      LInplace := LView.Controller.EditingController.Edit;
      if LInplace = nil then
      begin
        Writeln('  EditingItem yolu tutmadi, ShowEdit deneniyor...');
        LView.Controller.EditingController.ShowEdit(LCol);
        Bekle(250);
        LInplace := LView.Controller.EditingController.Edit;
      end;
      Writeln('  EditingItem             : ', Ad(LView.Controller.EditingItem));
      if LInplace = nil then
        Writeln('  !! inplace editor acilmadi - B ve C olculemedi')
      else
      begin
        Writeln('  inplace editor sinifi   : ', LInplace.ClassName,
          '   (TRadLookupComboBox olmali)');
        LSayac.Kaskad := 0;
        LSayac.SonKaynak := nil;
        LInplace.EditValue := 'IST';
        Bekle(200);
        Writeln('  EditValue atandi -> kaskad ', LSayac.Kaskad, ' kez  (1 olmali)');
        Writeln('    ASource : ', Ad(LSayac.SonKaynak));
        Writeln('    ATarget : ', Ad(LSayac.SonHedef));
        Writeln;
        Writeln('=== C) _Host inplace editorden KOLONU buluyor mu? ===');
        Writeln('    _Host   : ', LSayac.SonHostSinif,
          '   (TcxGridColumn/colSehir olmali)');
      end;

      LView.Controller.EditingController.HideEdit(True);
      Bekle(100);
    finally
      LForm.Free;
      LSayac.Free;
    end;
  except
    on E: Exception do
      Writeln('HATA: ', E.ClassName, ': ', E.Message);
  end;
end.
