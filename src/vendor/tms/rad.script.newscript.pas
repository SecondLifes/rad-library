unit rad.script.newscript;

(* Yeni script diyaloğu (DFM): kod, ad, tür, hedef; türe göre iskelet. Paket yöneticisi çağırır. *)

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls,
  rad.script;

type
  TRadScriptNewScriptForm = class(TForm)
    lblKod: TLabel;
    edtKod: TEdit;
    lblAd: TLabel;
    edtAd: TEdit;
    lblTur: TLabel;
    cmbTur: TComboBox;
    lblHedef: TLabel;
    edtHedef: TEdit;
    lblIpucu: TLabel;
    btnTamam: TButton;
    btnIptal: TButton;
    procedure cmbTurChange(Sender: TObject);
    procedure btnTamamClick(Sender: TObject);
  private
    FPackage: TRadScriptPackage;
    function Kind: TRadScriptKind;
  public
    /// Diyaloğu açar; onaylanırsa script (ve pencere için boş DFM kaynağı) pakete eklenir, döner.
    class function Execute(APackage: TRadScriptPackage; out AScript: TRadScript): Boolean; static;
    /// Türe göre başlangıç kaynağı.
    class function Skeleton(AKind: TRadScriptKind; const ACode: string): string; static;
  end;

implementation

uses
  Vcl.Dialogs;

{$R *.dfm}

resourcestring
  SHintForm = 'Form sınıf adı (Tkasa_k); atalar da eşleşir';
  SHintEvent = 'rad.eventbus kanal adı (efatura.gelen)';
  SHintSchedule = 'Quartz maskesi: sn dk saat gün ay haftagünü (0 0 8 * * ?)';
  SHintCommand = 'Modül sınıf adı (Tkasa_modul)';
  SHintNone = 'Hedef yok';
  SErrDup = 'Bu kodda script zaten var: %s';

class function TRadScriptNewScriptForm.Skeleton(AKind: TRadScriptKind; const ACode: string): string;
begin
  case AKind of
    skForm: Result := 'procedure Form_AfterCreate(Sender: TObject);'#13#10'begin'#13#10'end;'#13#10;
    skEvent, skSchedule: Result := 'procedure Calistir(Olay: TRadScriptEvent);'#13#10'begin'#13#10'end;'#13#10;
    skCommand: Result := Format('procedure %s_Execute(Sender: TObject);'#13#10'begin'#13#10'end;'#13#10, [ACode]);
    skWindow: Result := Format('{$FORM T%sForm, %s.dfm}'#13#10'begin'#13#10'end.'#13#10, [ACode, ACode]);
  else
    Result := '';
  end;
end;

class function TRadScriptNewScriptForm.Execute(APackage: TRadScriptPackage; out AScript: TRadScript): Boolean;
var
  F: TRadScriptNewScriptForm;
  K: TRadScriptKind;
begin
  AScript := nil;
  F := TRadScriptNewScriptForm.Create(nil);
  try
    F.FPackage := APackage;
    for K := Low(TRadScriptKind) to High(TRadScriptKind) do F.cmbTur.Items.Add(TRadScript.KindCodeOf(K));
    F.cmbTur.ItemIndex := 0;
    F.cmbTurChange(nil);
    Result := F.ShowModal = mrOk;
    if not Result then Exit;
    AScript := APackage.AddScript(Trim(F.edtKod.Text), F.Kind, Trim(F.edtHedef.Text), Skeleton(F.Kind, Trim(F.edtKod.Text)));
    AScript.Name := Trim(F.edtAd.Text);
    AScript.Order := APackage.Scripts.Count;
    if (F.Kind = skWindow) and (APackage.ResourceByName(AScript.DfmFileName) = nil) then
      APackage.AddResource(AScript.DfmFileName,
        TEncoding.UTF8.GetBytes(Format('object %sForm: T%sForm'#13#10'  Caption = ''%s'''#13#10'end'#13#10, [AScript.Code, AScript.Code, AScript.Name])));
  finally
    F.Free;
  end;
end;

function TRadScriptNewScriptForm.Kind: TRadScriptKind;
begin
  Result := TRadScriptKind(cmbTur.ItemIndex);
end;

procedure TRadScriptNewScriptForm.cmbTurChange(Sender: TObject);
begin
  case Kind of
    skForm: lblIpucu.Caption := SHintForm;
    skEvent: lblIpucu.Caption := SHintEvent;
    skSchedule: lblIpucu.Caption := SHintSchedule;
    skCommand: lblIpucu.Caption := SHintCommand;
  else
    lblIpucu.Caption := SHintNone;
  end;
  edtHedef.Enabled := not (Kind in [skLibrary, skWindow]);
  if not edtHedef.Enabled then edtHedef.Text := '';
end;

procedure TRadScriptNewScriptForm.btnTamamClick(Sender: TObject);
var
  S: TRadScript;
  LErr: string;
begin
  if (FPackage <> nil) and (FPackage.ScriptByCode(Trim(edtKod.Text)) <> nil) then
  begin
    MessageDlg(Format(SErrDup, [Trim(edtKod.Text)]), mtError, [mbOK], 0);
    Exit;
  end;
  S := TRadScript.Create;
  try
    S.Code := Trim(edtKod.Text);
    S.Name := Trim(edtAd.Text);
    S.Kind := Kind;
    S.Target := Trim(edtHedef.Text);
    S.Source := Skeleton(Kind, S.Code);
    LErr := S.Validate;
  finally
    S.Free;
  end;
  if LErr <> '' then
  begin
    MessageDlg(LErr, mtError, [mbOK], 0);
    Exit;
  end;
  ModalResult := mrOk;
end;

end.
