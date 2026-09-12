unit Kisayol.Edit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, cxGraphics, cxLookAndFeels,
  cxLookAndFeelPainters, Vcl.Menus, Vcl.StdCtrls, cxButtons, Vcl.ExtCtrls,
  dxBarBuiltInMenu, cxControls, cxPC, System.Actions, Vcl.ActnList, Data.DB,
  DBAccess, Uni, MemDS, VirtualTable, cxStyles, cxCustomData, cxFilter, cxData,
  cxDataStorage, cxEdit, cxNavigator, dxDateRanges, dxScrollbarAnnotations,
  cxDBData, cxGridCustomTableView, cxGridTableView, cxGridDBTableView,
  cxGridCustomView, cxClasses, cxGridLevel, cxGrid, cxDropDownEdit,
  Vcl.ComCtrls, JvExComCtrls, JvHotKey, Vcl.Mask, Vcl.DBCtrls, VirtualQuery,
  System.ImageList, Vcl.ImgList, cxImageList,Generics.Collections, 
  cxContainer, cxGroupBox, cxMemo;

type


  TKisayol_Edit = class(TForm)
    actlst1: TActionList;
    ImageList32: TcxImageList;
    act_Kaydet: TAction;
    act_orjinal: TAction;
    act_exit: TAction;
    pnlKey: TcxGroupBox;
    HotKey1: TJvHotKey;
    btnOk: TcxButton;
    cbtCancel: TcxButton;
    cxStyleRepository1: TcxStyleRepository;
    cxStyleRed: TcxStyle;
    cxG: TcxGrid;
    TableAct: TcxGridTableView;
    colIdx: TcxGridColumn;
    colName: TcxGridColumn;
    colKey: TcxGridColumn;
    TableGlobal: TcxGridTableView;
    colIdx1: TcxGridColumn;
    colName1: TcxGridColumn;
    colKey1: TcxGridColumn;
    cxGNormal: TcxGridLevel;
    cxGlobal: TcxGridLevel;
    pnlAlt: TcxGroupBox;
    btnKaydet: TcxButton;
    cxButton2: TcxButton;
    cxButton1: TcxButton;
    actReset: TAction;
    procedure HotKey1Change(Sender: TObject);
    procedure act_KaydetExecute(Sender: TObject);
    procedure cbtCancelClick(Sender: TObject);
    procedure colKeyGetDisplayText(Sender: TcxCustomGridTableItem; ARecord:
        TcxCustomGridRecord; var AText: string);
    procedure FormShow(Sender: TObject);
    procedure colKeyPropertiesPopup(Sender: TObject);
    procedure colKeyPropertiesCloseUp(Sender: TObject);
    procedure TableActStylesGetContentStyle(Sender: TcxCustomGridTableView;
      ARecord: TcxCustomGridRecord; AItem: TcxCustomGridTableItem;
      var AStyle: TcxStyle);
  private
    { Private declarations }
    //LastHotkey:TShortCut;
    ActiveAct:TAction;
    ArgActList:TArray<TActionList>;
    ArgAct:TArray<TAction>;
    ArgDefaultKey:TArray<TShortCut>;
    function IsKeyUses(const AAct:TAction):Boolean;
    procedure ViewCols(AView: TcxCustomGridTableView; out AIdx, AName, AKey: TcxGridColumn);
    function IdxCol(AView: TcxCustomGridTableView): TcxGridColumn;

  public
    { Public declarations }
   procedure Refresh;
   procedure AddAction(const AList: TActionList);
   procedure AddList(const arg: TArray<TActionList>);
  class function Edit(const AOwner: TComponent):Boolean;
  end;



implementation
  uses rad.rtl;
{$R *.dfm}
  var
   Kisayol_Edit: TKisayol_Edit;

 type
  TcxPopupEditAccess = class(TcxPopupEdit);





procedure TKisayol_Edit.AddAction(const AList: TActionList);
var
 i,j,k:Integer;
 act:TAction;
 view:TcxGridTableView;
begin
   if AList.Tag = -1 then Exit;

   i:=Length(ArgActList);
   SetLength(ArgActList,i+1);
   ArgActList[i]:=AList;

   i:=Length(ArgAct);
   SetLength(ArgAct,i+AList.ActionCount);
   SetLength(ArgDefaultKey,i+AList.ActionCount);
   for j := i to i+AList.ActionCount-1 do
   begin
     act:=TAction(AList.Actions[j-i]);
     ArgAct[j]:=act;
     ArgDefaultKey[j]:=act.ShortCut;
   end;

Refresh;
exit;

TableAct.DataController.BeginUpdate;
try
  k:=Length(ArgAct);
   for i := 0 to AList.ActionCount-1 do
      begin
       act:=TAction(AList.Actions[i]);
       if act.Tag>-1 then
        begin
         SetLength(ArgAct,k+1);
         SetLength(ArgDefaultKey,k+1);
         ArgAct[k]:=act;
         ArgDefaultKey[k]:=act.ShortCut;
         if (act is TRadAction) and (not TRadAction(act).GlobalKey.IsEmpty) then
          view:=TableGlobal
         else
          view:=TableAct;

         j:=view.DataController.AppendRecord;

         view.DataController.Values[j,colIdx.Index]:=k;
         view.DataController.Values[j,colName.Index]:=StripHotkey(act.Caption);
         view.DataController.Values[j,colKey.Index]:=ShortCutToText(act.ShortCut);
         view.DataController.PostEditingData;
         Inc(k);
        end;

          //vt.AppendRecord([s,act.Name,StripHotkey(act.Caption),ShortCutToText(act.ShortCut)]);
     end;

finally
  TableAct.DataController.EndUpdate;
end;


end;

 procedure TKisayol_Edit.AddList(const arg: TArray<TActionList>);
  var
   lst:TActionList;
  begin

   for lst in arg do AddAction(lst);
  end;



procedure TKisayol_Edit.colKeyPropertiesCloseUp(Sender: TObject);
var
 LEd: TcxPopupEdit;
begin
 { Sender editorun kendisi (cxDropDownEdit.pas:3120). }
 LEd := TcxPopupEdit(Sender);
 if (ActiveAct <> nil) and (TcxPopupEditAccess(LEd).PopupWindow.ModalResult = mrOk) then
  begin
    ActiveAct.ShortCut:=HotKey1.HotKey;
    LEd.EditingText:=ShortCutToText(ActiveAct.ShortCut);
    LEd.PostEditValue;
  end;
end;

Procedure TKisayol_Edit.colKeyPropertiesPopup(Sender: TObject);
var
 i:Integer;
begin
 ActiveAct:=nil;
 i:=cxG.ActiveView.DataController.FocusedRecordIndex;
 if i > -1 then
  begin
    //TcxPopupEditProperties(colKey.Properties).;
    //TextToShortCut(ActiveAct.ShortCut);
    ActiveAct:=ArgAct[Integer(cxG.ActiveView.DataController.Values[i,
      IdxCol(TcxCustomGridTableView(cxG.ActiveView)).Index])];
    HotKey1.HotKey:=ActiveAct.ShortCut; //cxG.ActiveView.DataController.Values[i,colKey.Index];
  end;

end;

class function TKisayol_Edit.Edit(const AOwner: TComponent): Boolean;
var
 i:Integer;
 c:TComponent;
  frm: TKisayol_Edit;
begin
frm:=TKisayol_Edit.Create(nil);
try
frm.TableAct.DataController.BeginFullUpdate;
frm.TableGlobal.DataController.BeginFullUpdate;
try
   for i := 0 to AOwner.ComponentCount -1 do
    begin
     c:=AOwner.Components[i];
      if (c is TRadActionList)  or (c is TActionList) then
       begin
        frm.AddAction(c As TActionList);
       end;
    end;
finally
  frm.TableAct.DataController.EndFullUpdate;
  frm.TableGlobal.DataController.EndFullUpdate;
end;

   if frm.ShowModal = mrOk then
    begin
      Result:=True
    end
    else
    begin
      Result:=False;
      frm.actReset.Execute
    end;



finally
  FreeAndNil(frm);
end;
end;


procedure TKisayol_Edit.act_KaydetExecute(Sender: TObject);
  var
   i,j:Integer;
begin
 i:=TAction(Sender).Tag;
    case i of
      1:ModalResult:=mrOk;
      2:ModalResult:=mrCancel;
      3,4:begin


          if i = 3 then
           begin
            j:=High(ArgActList);
            for i := 0 to j do
             if ArgActList[i] is TRadActionList then
              TRadActionList(ArgActList[i]).ShortCutDefaultRestore;
           end
           else
           begin
            j:=High(ArgAct);
            for i := 0 to j do
             ArgAct[i].ShortCut:=ArgDefaultKey[i];
           end;

          Refresh;


        end;

    end;
end;

procedure TKisayol_Edit.cbtCancelClick(Sender: TObject);
begin

if TcxGridTableView(cxG.ActiveView).Controller.EditingController.Edit <> nil then
  begin
   if TWinControl(Sender).Tag = 1 then
    begin
      //ShowMessage(ShortCutToText(HotKey1.HotKey));
      HotKey1.HotKey:=HotKey1.HotKey;
      TcxPopupEditPopupWindow(pnlKey.Parent).ModalResult:=mrOk;
      //TableAct.Controller.EditingController.HideEdit(True);
    end;
   //else TableAct.Controller.EditingController.HideEdit(False);

    //TcxPopupEditAccess
  end;
end;

procedure TKisayol_Edit.colKeyGetDisplayText(Sender: TcxCustomGridTableItem;  ARecord: TcxCustomGridRecord; var AText: string);
begin
 //AText:=ShortCutToText(StrToIntDef(AText,0));
 // AText:=ShortCutToText(ArgAct[Integer(ARecord.Values[0])].ShortCut);
end;

procedure TKisayol_Edit.FormShow(Sender: TObject);
begin
 cxG.ActiveLevel:=cxGNormal;
end;



procedure TKisayol_Edit.HotKey1Change(Sender: TObject);
begin
 //LastHotkey:=HotKey1.HotKey;
 //LastKey:=ShortCutToText(HotKey1.HotKey);
end;




function TKisayol_Edit.IsKeyUses(const AAct:TAction): Boolean;
var
 i,j:Integer;
begin
//s:=ShortCutToText(AAct.ShortCut);
if AAct.ShortCut > 0 then
 begin
  j:=High(ArgAct);
 for i := 0  to j do
  begin
     if (AAct<>ArgAct[i]) and (AAct.ShortCut = ArgAct[i].ShortCut) then
     begin
       Result:=True;
       Exit;
     end;
  end;
 end;

  Result:=False;
end;

procedure TKisayol_Edit.Refresh;
var
 i,j:Integer;
 act:TAction;
 view:TcxGridTableView;
 LIdx, LName, LKey: TcxGridColumn;
begin
  TableAct.BeginUpdate();
  TableGlobal.BeginUpdate();
  try
    TableAct.DataController.RecordCount:=0;
    TableGlobal.DataController.RecordCount:=0;
    i:=0;
    for act in ArgAct do
    begin
      if act.Tag>-1 then
      begin
        if (act is TRadAction) and (not TRadAction(act).GlobalKey.IsEmpty) then
          view:=TableGlobal
        else
          view:=TableAct;
        ViewCols(view, LIdx, LName, LKey);

        j:=view.DataController.AppendRecord;
        view.DataController.Values[j,LIdx.Index]:=i;
        view.DataController.Values[j,LName.Index]:=StripHotkey(act.Caption);
        view.DataController.Values[j,LKey.Index]:=ShortCutToText(act.ShortCut);
        view.DataController.PostEditingData;
      end;
      Inc(i);
    end;
    TableAct.DataController.Refresh;
    TableGlobal.DataController.Refresh;
  finally
    TableAct.EndUpdate;
    TableGlobal.EndUpdate;
  end;
end;

procedure TKisayol_Edit.TableActStylesGetContentStyle( Sender: TcxCustomGridTableView; ARecord: TcxCustomGridRecord; AItem: TcxCustomGridTableItem; var AStyle: TcxStyle);
var
 LDeger: Variant;
begin
 { Iki gorunum de bu isleyiciyi kullaniyor; indeks Sender'in KENDI kolonundan
   alinir. Yeni eklenmis bir kayitta deger henuz bos olabilir. }
 LDeger := ARecord.Values[IdxCol(Sender).Index];
 if VarIsNull(LDeger) or VarIsEmpty(LDeger) then
  Exit;
 if IsKeyUses(ArgAct[Integer(LDeger)]) then
  AStyle:=cxStyleRed;
end;

procedure TKisayol_Edit.ViewCols(AView: TcxCustomGridTableView; out AIdx, AName, AKey: TcxGridColumn);
begin
  { DataController.Values'in ikinci indeksi kolonun KENDI gorunumundeki
    konumudur (DevExpress: TcxCustomDataController.Values). TableAct'in
    kolonunu TableGlobal'in kayitlarina vermek yalnizca iki gorunum ayni
    siradayken dogru calisirdi. }
  if AView = TableGlobal then
  begin
    AIdx := colIdx1;
    AName := colName1;
    AKey := colKey1;
  end
  else
  begin
    AIdx := colIdx;
    AName := colName;
    AKey := colKey;
  end;
end;

function TKisayol_Edit.IdxCol(AView: TcxCustomGridTableView): TcxGridColumn;
var
  LName, LKey: TcxGridColumn;
begin
  ViewCols(AView, Result, LName, LKey);
end;

initialization
  //ActionEditor.RegisterEditForm(TKisayol_Edit);

 finalization
     //if Assigned(FActionManager) then  FActionManager.Free;
     //if Assigned(Kisayol_Edit)   then  FreeAndNil(Kisayol_Edit);
end.
