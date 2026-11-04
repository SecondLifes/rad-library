unit rad.desktop.picker;

(* "Kısayol ekle" dialog of the ERP desktop: searchable, checkable list of every command the user may
   see. Layout lives in the DFM; only the rows are created in code. *)

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  rad.desktop.commands;

type
  TRadDeskPickerForm = class(TForm)
    pnlTop: TPanel;
    edtSearch: TEdit;
    lvCommands: TListView;
    pnlBottom: TPanel;
    lblCount: TLabel;
    btnOk: TButton;
    btnCancel: TButton;
    procedure edtSearchChange(Sender: TObject);
    procedure lvCommandsItemChecked(Sender: TObject; Item: TListItem);
    procedure lvCommandsDblClick(Sender: TObject);
    procedure edtSearchKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FAll: TRadDeskCommandInfos;
    FChecked: TStringList;
    FFilling: Boolean;
    procedure UpdateCount;
    function GroupOf(const ACategory: string): Integer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Loads the rows; Execute calls it, a test or a snapshot may call it directly.</summary>
    procedure Load(const ACommands: TRadDeskCommandInfos);
    procedure Fill;
    /// <summary>True with the checked ids (in list order) when the user confirmed.</summary>
    class function Execute(const ACommands: TRadDeskCommandInfos; out AIds: TArray<string>): Boolean; static;
  end;

implementation

{$R *.dfm}

uses
  rad.desktop.core;

constructor TRadDeskPickerForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FChecked := TStringList.Create;
  FChecked.Sorted := True;
  FChecked.Duplicates := dupIgnore;
end;

destructor TRadDeskPickerForm.Destroy;
begin
  FChecked.Free;
  inherited Destroy;
end;

class function TRadDeskPickerForm.Execute(const ACommands: TRadDeskCommandInfos; out AIds: TArray<string>): Boolean;
var
  LForm: TRadDeskPickerForm;
  LInfo: TRadDeskCommandInfo;
begin
  AIds := nil;
  LForm := TRadDeskPickerForm.Create(nil);
  try
    LForm.Load(ACommands);
    Result := LForm.ShowModal = mrOk;
    if Result then
      for LInfo in ACommands do
        if LForm.FChecked.IndexOf(LInfo.Id) >= 0 then
          AIds := AIds + [LInfo.Id];
    Result := Result and (Length(AIds) > 0);
  finally
    LForm.Free;
  end;
end;

procedure TRadDeskPickerForm.Load(const ACommands: TRadDeskCommandInfos);
begin
  FAll := ACommands;
  Fill;
end;

function TRadDeskPickerForm.GroupOf(const ACategory: string): Integer;
var
  I: Integer;
  LGroup: TListGroup;
  LHeader: string;
begin
  LHeader := ACategory;
  if LHeader = '' then
    LHeader := 'Diğer';
  for I := 0 to lvCommands.Groups.Count - 1 do
    if lvCommands.Groups[I].Header = LHeader then
      Exit(lvCommands.Groups[I].GroupID);
  LGroup := lvCommands.Groups.Add;
  LGroup.Header := LHeader;
  LGroup.State := [lgsNormal, lgsCollapsible];
  Result := LGroup.GroupID;
end;

procedure TRadDeskPickerForm.Fill;
var
  LInfo: TRadDeskCommandInfo;
  LItem: TListItem;
  LNeedle: string;
begin
  LNeedle := TRadDeskNav.Fold(System.SysUtils.Trim(edtSearch.Text));
  FFilling := True;
  lvCommands.Items.BeginUpdate;
  try
    lvCommands.Items.Clear;
    lvCommands.Groups.Clear;
    for LInfo in FAll do
    begin
      if (LNeedle <> '') and not TRadDeskNav.Fold(LInfo.Caption + ' ' + LInfo.Category).Contains(LNeedle) then
        Continue;
      LItem := lvCommands.Items.Add;
      LItem.GroupID := GroupOf(LInfo.Category);
      LItem.Caption := LInfo.Caption;
      LItem.SubItems.Add(LInfo.Category);
      LItem.Checked := FChecked.IndexOf(LInfo.Id) >= 0;
      LItem.Data := Pointer(lvCommands.Items.Count - 1);
      LItem.SubItems.Add(LInfo.Id);
    end;
  finally
    lvCommands.Items.EndUpdate;
    FFilling := False;
  end;
  UpdateCount;
end;

procedure TRadDeskPickerForm.UpdateCount;
begin
  lblCount.Caption := Format('%d seçili · %d komut', [FChecked.Count, lvCommands.Items.Count]);
  btnOk.Enabled := FChecked.Count > 0;
end;

procedure TRadDeskPickerForm.edtSearchChange(Sender: TObject);
begin
  Fill;
end;

procedure TRadDeskPickerForm.edtSearchKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_DOWN) and (lvCommands.Items.Count > 0) then
  begin
    lvCommands.SetFocus;
    lvCommands.ItemIndex := 0;
    Key := 0;
  end;
end;

procedure TRadDeskPickerForm.lvCommandsItemChecked(Sender: TObject; Item: TListItem);
var
  LId: string;
begin
  if FFilling or (Item.SubItems.Count < 2) then
    Exit;
  LId := Item.SubItems[1];
  if Item.Checked then
    FChecked.Add(LId)
  else if FChecked.IndexOf(LId) >= 0 then
    FChecked.Delete(FChecked.IndexOf(LId));
  UpdateCount;
end;

procedure TRadDeskPickerForm.lvCommandsDblClick(Sender: TObject);
begin
  if Assigned(lvCommands.Selected) then
    lvCommands.Selected.Checked := not lvCommands.Selected.Checked;
end;

end.
