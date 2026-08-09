unit Permission.Edit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  System.Actions, Vcl.ActnList, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, cxFilter, cxCustomData, cxStyles,
  dxScrollbarAnnotations, cxTL, cxTextEdit, cxTLdxBarBuiltInMenu,
  cxInplaceContainer,

  mormot.core.variants, mormot.core.base, mormot.core.json, Vcl.Menus, cxButtons,
  rad.permission;


type

  TRadPermission = class(TComponent)
  private
    FTree: RawUtf8;      // tüm yetki tanımları — DFM'e yazılır
    FData: IPermission;  // izin verilenler — DB'den yüklenir
    procedure TreeRead(Reader: TReader);
    procedure TreeWrite(Writer: TWriter);
  protected
    procedure DefineProperties(Filer: TFiler); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Edit;
    procedure Show;
    property Data: IPermission read FData;
  published
  end;

  TcxTreeListHack = class(cxTL.TcxTreeList)
  private
    FOnAdd: TcxTreeListNodeChangedEvent;
  public
   function AddNode(ANode, ARelative: TcxTreeListNode; AData: Pointer; AttachMode: TcxTreeListNodeAttachMode): TcxTreeListNode; override;
   property OnAddNode:TcxTreeListNodeChangedEvent read FOnAdd write FOnAdd;
  end;

  TcxTreeList= class(TcxTreeListHack);


  TPermission_Edit = class(TFrame)
    pnlAlt: TPanel;
    Act_1: TActionList;
    act_append: TAction;
    act_ins: TAction;
    cxTree: TcxTreeList;
    Col_adi: TcxTreeListColumn;
    Col_kod: TcxTreeListColumn;
    PopupMenu1: TPopupMenu;
    Ekle1: TMenuItem;
    Ekle2: TMenuItem;
    act_expand: TAction;
    mnA1: TMenuItem;
    btn_ok: TcxButton;
    btn_cancel: TcxButton;
    N1: TMenuItem;
    act_yetkikodu_copy: TAction;
    YetkiKodunuKopyala1: TMenuItem;
    IDFix1: TMenuItem;
    actFix: TAction;
    procedure act_appendExecute(Sender: TObject);
    procedure act_expandExecute(Sender: TObject);
    procedure cxTreeDblClick(Sender: TObject);
    procedure cxTreeDragOver(Sender, Source: TObject; X, Y: Integer; State:
        TDragState; var Accept: Boolean);
    procedure btn_okClick(Sender: TObject);
    procedure actFixExecute(Sender: TObject);
  private
    { Private declarations }
    FJson:IDocDict;
    FEditMode:Boolean;
    procedure LoadJson(const Json:IDocAny; const ANode:TcxTreeListNode);
    procedure OnAddNode(Sender: TcxCustomTreeList; ANode: TcxTreeListNode);

    procedure Fix;
    procedure SetEditMode(const Value: Boolean);
    procedure SetYetki(const Value: RawUtf8);
    function GetYetki:RawUtf8;
    procedure Ekle(const AList: IDocList; const ANode: TcxTreeListNode);
  public
    { Public declarations }
    procedure ReLoad(const AJsonStr:RawUtf8; const IsEdit:Boolean=false);
    //class function View(const AControl:TWinControl):TPermission_Edit;
    class procedure Load(const AJsonStr:PRawUtf8; const IsEdit:Boolean=false);
    procedure AfterConstruction; override;
    function MakeJson:RawUtf8;


    property EditMode: Boolean read FEditMode write SetEditMode;
    property Yetki: RawUtf8 read GetYetki write SetYetki;
  end;



//var Permission_Edit: TPermission_Edit;

implementation
  uses mormot.core.text,Clipbrd;
{$R *.dfm}

type
    TcxTreeListNodeHelper = class helper for TcxTreeListNode
    function _AsStrBase:string;
    function _AsString(ALevel:Integer=0; const ABirles:Boolean=True):string;
    function _AddNode(const AKod, ACaption:string;const AChecked:Boolean):TcxTreeListNode;
   end;

procedure TPermission_Edit.actFixExecute(Sender: TObject);
begin
 Fix;
end;

procedure TPermission_Edit.act_appendExecute(Sender: TObject);
var
 nd:TcxTreeListNode;
begin
    nd:=cxTree.FocusedNode;
     if nd=nil then exit;

 case TAction(Sender).tag of
  1: cxTree.Navigator.Buttons.Append.Click;
  2: cxTree.Navigator.Buttons.Insert.Click;
  3: if nd <> nil then Clipboard.AsText:=nd._AsString();   //nd.Texts[Col_kod.ItemIndex];

 end;

end;

procedure TPermission_Edit.act_expandExecute(Sender: TObject);
begin
  if act_expand.Checked then
   begin
    cxTree.FullExpand;
   end
  else
   begin
    cxTree.FullCollapse;
   end;

end;

procedure TPermission_Edit.AfterConstruction;
begin
  inherited;
  self.cxTree.Clear;
  EditMode:=false;
end;


procedure TPermission_Edit.btn_okClick(Sender: TObject);
begin
try
  MakeJson;
  GetParentForm(Self).ModalResult:=mrOk;
except
 on E: Exception do
  begin
    MessageDlg(E.Message, TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], 0);

  end;
end;
end;

procedure TPermission_Edit.cxTreeDblClick(Sender: TObject);
begin
   act_yetkikodu_copy.Execute;
end;

procedure TPermission_Edit.cxTreeDragOver(Sender, Source: TObject; X, Y:
    Integer; State: TDragState; var Accept: Boolean);
begin
 Accept := FEditMode;
end;

procedure TPermission_Edit.Fix;
 var
  i,DotPos:Integer;
  s:string;
begin
cxTree.BeforeUpdate;
 try
 for i := 0 to cxTree.AbsoluteCount -1 do
  begin

    s:=cxTree.AbsoluteItems[i].Texts[1].Replace(' ','');
    DotPos := LastDelimiter('.', s);
    if DotPos > 0 then
      s := Copy(s, DotPos + 1, MaxInt);
    cxTree.AbsoluteItems[i].Texts[1]:=s;
  end;

 finally
   cxTree.EndUpdate;
 end;
end;

function TPermission_Edit.GetYetki: RawUtf8;
var
 nd:TcxTreeListNode;
 i,j:Integer;
 list:IDocList;
begin
 Result:='';
 list:=DocList();
 j:=cxTree.AbsoluteCount -1;
 for i := 0 to j do
  begin
    nd:=cxTree.AbsoluteItems[i];
    if (not nd.HasChildren) and (nd.Checked) then
     list.Append(nd.Texts[1]);
  end;
 Result:=list.Json; //.ToJson(TTextWriterJsonFormat.jsonUnquotedPropNameCompact,[]);

end;

class procedure TPermission_Edit.Load(const AJsonStr:PRawUtf8; const IsEdit:Boolean=false);
 var
  fr:TPermission_Edit;
  frm:TForm;
begin
  frm:=TForm.Create(nil);
  frm.Position:=poDesktopCenter;
  fr:=TPermission_Edit.Create(frm);
  fr.parent:=frm;

  frm.ClientHeight:=fr.Height;
  frm.ClientWidth:=fr.Width;
  fr.Align:=alClient;

  try
   fr.FJson:=DocDict(AJsonStr^,mFastExtended);
   fr.FJson.PathDelim:='.';

   fr.EditMode:=IsEdit;

   if not fr.FJson.Exists('permisson') then
   fr.FJson.A['permisson']:=DocList(mFastExtended);

   fr.LoadJson(fr.FJson.A['permisson'],fr.cxTree.Root);
   TcxTreeListHack(fr.cxTree).OnAddNode:=fr.OnAddNode;


   if frm.ShowModal = mrOk then
    begin
     if IsEdit then
      begin

       AJsonStr^:=fr.FJson.ToJson(TTextWriterJsonFormat.jsonUnquotedPropNameCompact,[]);
      end;
    end;

  finally
    FreeAndNil(frm);
  end;

end;

procedure TPermission_Edit.LoadJson(const Json:IDocAny; const ANode:TcxTreeListNode);
var
 v:TDocDictFields;
 val:TDocValue;
 obj:IDocObject;

 nd:TcxTreeListNode;
begin


  if Json.Kind = dvUndefined then
   begin

   end
  else if Json.Kind = dvObject then
   begin
     if json.AsDict.Exists('id') then
      begin

       nd:=ANode._AddNode(Json.AsDict.S['id'],Json.AsDict.S['name'],True);
       if Json.AsDict.Exists('child') then
        LoadJson(Json.AsDict.A['child'],nd);

      end;

   end
   else
   begin
    for val in Json.AsList.GetEnumerator do
     begin


        //LoadJson(IDocDict(val),ANode)
        try
        if val.Kind = dvObject then
           LoadJson(IDocDict(val),ANode);
        except

        end;


     end;

   end;




end;



procedure TPermission_Edit.Ekle(const AList: IDocList; const ANode: TcxTreeListNode);
var
  i: Integer;
  nd: TcxTreeListNode;
  dic: IDocDict;
  ParentID, FullID, CurrentID, ExpectedParentID: string;
begin

  if (ANode = cxTree.Root) then //or (ANode.Parent =cxTree.Root)
   ParentID:=''
  else
   ParentID := Trim(ANode.Texts[1]);

  for i := 0 to ANode.Count - 1 do
  begin
    nd := ANode.Items[i];
    dic := DocDict();

    FullID := Trim(nd.Texts[1]);
    CurrentID := '';
    ExpectedParentID := '';

    // ID ayrıştırma
    var DotPos := LastDelimiter('.', FullID);
    if DotPos > 0 then
    begin
      ExpectedParentID := Copy(FullID, 1, DotPos - 1);
      CurrentID := Copy(FullID, DotPos + 1, MaxInt);
    end
    else
    begin
      if ParentID.IsEmpty then
        CurrentID := FullID
      else
       begin
        ExpectedParentID:=ParentID;
        CurrentID := FullID;
       end;
    end;

    // ID boşsa hata
    if CurrentID.IsEmpty then
    begin
      raise EInvalidOpException.CreateFmt('"%s (%s)" için ID boş olamaz.', [nd.Texts[1], nd.Texts[0]]);
    end;

    // Hiyerarşik kontrol
    if not ExpectedParentID.IsEmpty then
    begin
      if ExpectedParentID <> ParentID then
      begin
        raise EInvalidOpException.CreateFmt(
          '"%s != %s" Hatalı hiyerarşik ID "%s (%s)"', [ANode.Parent.Texts[1].Trim, ExpectedParentID, nd.Texts[1], nd.Texts[0]]);
      end;
    end
    else
    begin
      // Kök seviyesindeyse parent yoksa ExpectedParentID boş olmalı
      if not ParentID.IsEmpty then
      begin
        raise EInvalidOpException.CreateFmt(
          'Beklenen parent "%s", fakat "%s" bulunamadı.', [ANode.Parent.Texts[1].Trim, nd.Texts[1]]);
      end;
    end;

    // Benzersizlik kontrolü
    {
    if AUsedIDs.ContainsKey(FullID) then
    begin
      raise EInvalidOpException.CreateFmt('ID "%s" zaten mevcut.', [FullID]);
    end;
    AUsedIDs.Add(FullID, True);
    }
    // JSON objesini oluştur
    dic.S['id'] := CurrentID;
    dic.S['name'] := nd.Texts[0].Trim;

    // Recursive alt düğümler
    if nd.HasChildren then
    begin
      dic.A['child'] := DocList();
      Ekle(dic.A['child'], nd);
    end;

    AList.AppendDoc(dic);
  end;
end;

function TPermission_Edit.MakeJson:RawUtf8;

begin
  //Fix;
  FJson.A['permisson'].Clear;
  Ekle(FJson.A['permisson'], cxTree.Root);

  Result := FJson.ToJson(TTextWriterJsonFormat.jsonUnquotedPropNameCompact, []);


end;

procedure TPermission_Edit.OnAddNode(Sender: TcxCustomTreeList; ANode: TcxTreeListNode);
begin
   ANode.CheckGroupType:=ncgCheckGroup;
  if ANode.Parent <> ANode.Root then
   ANode.Texts[1]:=ANode.Parent.Texts[1]+'.';

end;

procedure TPermission_Edit.ReLoad(const AJsonStr: RawUtf8; const IsEdit: Boolean);
begin
   if FJson <> nil then
    FJson :=nil;

    FJson:=DocDict(AJsonStr,mFastExtended);
    FJson.PathDelim:='.';

   cxTree.Clear;

   EditMode:=IsEdit;

   if not FJson.Exists('permisson') then
   FJson.A['permisson']:=DocList(mFastExtended);

   LoadJson(FJson.A['permisson'],cxTree.Root);
   TcxTreeListHack(cxTree).OnAddNode:=OnAddNode;


end;

procedure TPermission_Edit.SetEditMode(const Value: Boolean);
begin
  FEditMode := Value;
  pnlAlt.Visible:=Value;
  cxTree.OptionsData.Editing:=Value;
  cxTree.OptionsData.Appending:=Value;
  cxTree.OptionsData.Inserting:=Value;
  cxTree.OptionsData.Deleting:=Value;

  cxTree.OptionsSelection.CellSelect:=Value;
  cxTree.Navigator.Visible:=Value;
  Col_kod.Visible:=Value;

  act_append.Visible:=Value;
  act_append.Enabled:=Value;
  act_ins.Visible:=Value;
  act_ins.Enabled:=Value;
  actFix.Visible:=Value;
  actFix.Enabled:=Value;

end;

procedure TPermission_Edit.SetYetki(const Value: RawUtf8);
var
 nd:TcxTreeListNode;
 i,j:Integer;
 list:IDocList;
begin
 list:=DocList(Value);
 
 j:=cxTree.AbsoluteCount -1;
 for i := 0 to j do
  begin
    nd:=cxTree.AbsoluteItems[i];
    nd.Checked:=list.Exists(nd.Texts[1]);
  end;

end;

{ TcxTreeListNodeHelper }

function TcxTreeListNodeHelper._AddNode(const AKod, ACaption: string; const AChecked: Boolean): TcxTreeListNode;
begin
  Result:=Self.AddChild;
  Result.Texts[0]:=ACaption;
  if Self = self.Root then
   Result.Texts[1]:=AKod
  else
   Result.Texts[1]:=Texts[1]+'.'+AKod;
  Result.CheckGroupType:=ncgCheckGroup;
  Result.Checked:=AChecked;
end;

function TcxTreeListNodeHelper._AsStrBase: string;
begin
  Result:=Trim(StringReplace(Texts[1],' ','',[rfReplaceAll]));
    var DotPos := LastDelimiter('.', Result);
    if DotPos > 0 then
      Result := Copy(Result, DotPos + 1, MaxInt);
end;

function TcxTreeListNodeHelper._AsString(ALevel: Integer; const ABirles: Boolean): string;
var
 nd:TcxTreeListNode;
begin
 nd:=Self;
 Result:='';

  while nd.Level>ALevel do
   begin
     if ABirles then
      begin
         if Result.IsEmpty then
        Result:=nd._AsStrBase
        else
        Result:=nd._AsStrBase+'.'+Result;
      end;
     nd:=nd.Parent;
   end;
 if Result.IsEmpty then
 Result:=nd._AsStrBase
 else
 Result:=nd._AsStrBase+'.'+Result;

end;

{ TcxTreeListHack }

function TcxTreeListHack.AddNode(ANode, ARelative: TcxTreeListNode;
  AData: Pointer; AttachMode: TcxTreeListNodeAttachMode): TcxTreeListNode;
begin
    Result:=inherited AddNode(ANode, ARelative, AData, AttachMode);
    if Assigned(FOnAdd) then FOnAdd(Self,Result);
end;

{ TRadPermission }

constructor TRadPermission.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FData := NewPermission;
end;

procedure TRadPermission.DefineProperties(Filer: TFiler);
  function DoWrite: Boolean;
  begin
    if Filer.Ancestor = nil then
      Result := FTree <> ''
    else
      Result := FTree <> TRadPermission(Filer.Ancestor).FTree;
  end;
begin
  Filer.DefineProperty('Tree', TreeRead, TreeWrite, DoWrite);
end;

procedure TRadPermission.TreeRead(Reader: TReader);
begin
  FTree := Reader.ReadString;
end;

procedure TRadPermission.TreeWrite(Writer: TWriter);
begin
  Writer.WriteString(FTree);
end;

procedure TRadPermission.Loaded;
begin
  inherited;
end;

procedure TRadPermission.Edit;
begin
  if csAncestor in ComponentState then
    TPermission_Edit.Load(@FTree, False)
  else
    TPermission_Edit.Load(@FTree, True);
end;

procedure TRadPermission.Show;
begin
  TPermission_Edit.Load(@FTree, False);
end;

end.
