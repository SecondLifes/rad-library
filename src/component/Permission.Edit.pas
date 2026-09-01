unit Permission.Edit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  System.Actions, Vcl.ActnList, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, cxFilter, cxCustomData, cxStyles,
  dxScrollbarAnnotations, cxTL, cxTextEdit, cxTLdxBarBuiltInMenu,
  cxInplaceContainer,cxDB,

  mormot.core.variants, mormot.core.base, mormot.core.json, Vcl.Menus, cxButtons,
  Data.DB,        // TDataSet / TField - DataSet ve TreeField ozellikleri icin
  rad.core,       // ERadCore - kitin istisna agacinin koku
  rad.permission, cxContainer, cxEdit, cxDBEdit;

resourcestring
  SRadPermNoLink    = 'TRadPermission "%s": DataSet ve TreeField atanmadan alana yazilamaz.';
  SRadPermClosed    = 'TRadPermission "%s": "%s" dataset''i kapali; alan okunup yazilamaz.';
  SRadPermNoField   = 'TRadPermission "%s": "%s" dataset''inde "%s" adli alan yok.';
  SRadPermNoRecord  = 'TRadPermission "%s": "%s" dataset''inde gecerli kayit yok (bos).';


type

  /// <summary>Bu bilesenin kendi istisna tipi.</summary>
  ERadPermission = class(ERadCore);

  /// <summary>Yetki TANIMLARININ nerede saklanacagi.</summary>
  /// <remarks>
  ///   psDfm      : tanimlar formun/DM'in DFM'ine gomulur. Veritabanina hic
  ///                dokunulmaz; DataSet/DBField atanmis olsa bile.
  ///   psDatabase : tanimlar DataSet.DBField alanindan okunur ve oraya yazilir.
  ///                DFM'e YAZILMAZ - iki kaynak olsaydi biri bayatlar ve hangi
  ///                surumun gecerli oldugu belirsizlesirdi.
  ///
  ///   Bu secim TASARIM ZAMANINDA da gecerlidir: bilesenin isi tanimlari IDE'de
  ///   duzenlemektir (cagri Rad.Editor'daki bilesen editorunden gelir), yani
  ///   psDatabase secildiginde IDE'den canli veritabanina yazilir. Bilincli
  ///   secimdir; eskiden burada kosulsuz bir csDesigning korumasi vardi ve her
  ///   tasarim zamani kaydini SESSIZCE iptal ediyordu.
  /// </remarks>
  TRadPermissionStorage = (psDfm, psDatabase);

  TRadPermission = class(TComponent)
  private
    FTree: RawUtf8;      // tüm yetki tanımları — DFM'e yazılır
    FData: IPermission;  // izin verilenler — DB'den yüklenir
    FStorage: TRadPermissionStorage;
    FDataBinding : TcxDBDataBinding;

    /// <summary>
    ///   Bagli alani cozer. ARaise=False iken "baglanti yok" sessizdir
    ///   (bilesen alansiz da calisir); True iken sebep istisna olur.
    /// </summary>
    procedure TreeRead(Reader: TReader);
    procedure TreeWrite(Writer: TWriter);
    function GetDataBinding: TcxDBDataBinding;
    procedure SetDataBinding(const Value: TcxDBDataBinding);
  protected
    procedure DefineProperties(Filer: TFiler); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;

    /// <summary>Tanimlari bagli alandan okur. Baglanti yoksa False, istisna yok.</summary>
    function LoadFromField: Boolean;
    /// <summary>
    ///   Tanimlari bagli alana yazar. Baglanti eksikse ISTISNA atar - burasi
    ///   veri KAYBI noktasi, sessiz basarisizlik olmamali.
    /// </summary>
    function SaveToField: Boolean;

    procedure Edit;
    procedure Show;

    /// <summary>Yetki tanimlari (JSON). DFM ve/veya bagli alanla beslenir.</summary>
    property Tree: RawUtf8 read FTree write FTree;
    property Data: IPermission read FData;
  published
    /// <summary>Tanimlar nereye kaydedilsin: DFM mi, veritabani mi.</summary>
    property Storage: TRadPermissionStorage read FStorage write FStorage default psDfm;
    property DataBinding: TcxDBDataBinding read GetDataBinding write SetDataBinding;
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
    itmSablon: TMenuItem;
    itmSablonlar: TMenuItem;
    procedure act_appendExecute(Sender: TObject);
    procedure act_expandExecute(Sender: TObject);
    procedure cxTreeDblClick(Sender: TObject);
    procedure cxTreeDragOver(Sender, Source: TObject; X, Y: Integer; State:
        TDragState; var Accept: Boolean);
    procedure btn_okClick(Sender: TObject);
    procedure actFixExecute(Sender: TObject);
    procedure itmSablonClick(Sender: TObject);
    procedure SablonClick(Sender: TObject);
    procedure cxTreeEditValueChanged(Sender: TcxCustomTreeList; AColumn: TcxTreeListColumn);
    procedure Col_kodPropertiesValidate(Sender: TObject; var DisplayValue: TcxEditValue; var ErrorText: TCaption; var Error: Boolean);
  private
    { Private declarations }
    FRootName : string;
    FJson:IDocDict;
    FEditMode:Boolean;
    procedure LoadJson(const Json:IDocAny; ANode:TcxTreeListNode);
    procedure OnAddNode(Sender: TcxCustomTreeList; ANode: TcxTreeListNode);

    procedure Fix;
    procedure SetEditMode(const Value: Boolean);
    procedure SetYetki(const Value: RawUtf8);
    function GetYetki:RawUtf8;
    procedure Ekle(const AList: IDocList; const ANode: TcxTreeListNode);
  public
    { Public declarations }
    procedure ReLoad(const aRootName:string);

    procedure Load(const AJsonStr:PRawUtf8); overload;
    class procedure Load(const AJsonStr:PRawUtf8; const IsEdit:Boolean); overload;
    procedure AfterConstruction; override;
    function MakeJson:RawUtf8;


    property EditMode: Boolean read FEditMode write SetEditMode;
    property Yetki: RawUtf8 read GetYetki write SetYetki;
  end;



//var Permission_Edit: TPermission_Edit;

implementation
  uses mormot.core.text,
       mormot.core.unicode,   // StringToUtf8 / Utf8ToString - alan <-> RawUtf8 donusumu
       Clipbrd,
       help.vcl
       ;
{$R *.dfm}

type
    TcxTreeListNodeHelper = class helper for TcxTreeListNode
    function _KodeFix(const ACode:string):string;
    function _Kod:string;
    function _SetKod(aKod:string):TcxTreeListNode;
    function _AsStrBase:string;
    function _AsString(ALevel:Integer=0; const ABirles:Boolean=True):string;
    function _AddNode(AKod, ACaption:string;const AChecked:Boolean):TcxTreeListNode;
    //function _FindID(const AKod:string):TcxTreeListNode;
    function _FindChildID(const AKod:string):TcxTreeListNode;
    //function _IDCheck(const AKod:string):Boolean;
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
  if SameText(FRootName,'permisson') then
    GetParentForm(Self).ModalResult:=mrOk
  else
    ReLoad('permisson');

except
 on E: Exception do
  begin
    MessageDlg(E.Message, TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], 0);

  end;
end;
end;

procedure TPermission_Edit.Col_kodPropertiesValidate(Sender: TObject; var DisplayValue: TcxEditValue; var ErrorText: TCaption; var Error: Boolean);
var
 edt :TcxTextEdit absolute Sender;
 s:string;
begin

  if not VarSameValue(edt.EditingValue,edt.EditValue) then
   begin
    s:=VarToStrDef(edt.EditingValue,'');
    if s = '' then
     begin
       ErrorText :='ID ler Boş olamaz';
       Error:=True;

     end
    else if (cxTree.FocusedNode <> nil) and ( cxTree.FocusedNode.Parent._FindChildID(s) <> nil)  then
     begin
       ErrorText :='Bu id kullanılmış ('+s+')';
       Error:=True;
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

procedure TPermission_Edit.cxTreeEditValueChanged(Sender: TcxCustomTreeList; AColumn: TcxTreeListColumn);
begin
  //ShowMessage(BoolToStr(Col_kod.Editing,true)+sLineBreak+AColumn.value+sLineBreak+AColumn.EditValue);

  //if (AColumn = Col_kod) and (SameText(Col_kod.EditValue,Col_kod.Value)) then
  //ShowMessage(Col_kod.Value+sLineBreak+Col_kod.EditValue)
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
 Result:=list.Json; //.ToJson(TTextWriterJsonFormat.jsonCompact,[]);

end;

procedure TPermission_Edit.itmSablonClick(Sender: TObject);
begin
  if itmSablon.Checked then
   begin
    ReLoad('sablon');
    Col_adi.Caption.Text:='Şablon Adı';
    Col_kod.Caption.Text:='Şablon Kodu';
   end
  else
   begin
    ReLoad('permisson');
    Col_adi.Caption.Text:='Yetki Adı';
    Col_kod.Caption.Text:='Yetki Kodu';
   end;

end;

class procedure TPermission_Edit.Load(const AJsonStr:PRawUtf8; const IsEdit:Boolean);
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
   fr.EditMode:=IsEdit;
   fr.Load(AJsonStr);

   if frm.ShowModal = mrOk then
    begin
     if IsEdit then
      begin

       { STANDART JSON zorunlu: belge mFast ile acilir (mFastExtended DEGIL) ve
         bicim jsonCompact'tir. mFastExtended, ToJson'a hangi bicimi verirsen
         ver anahtarlari TIRNAKSIZ yazar - olculdu - ve PostgreSQL json/jsonb
         kolonu bunu "json tipi icin gecersiz girdi sozdizimi" diye reddeder.
         mFast eski genisletilmis kayitlari da okuyabilir, yani gecis sorunsuz. }
       AJsonStr^:=fr.FJson.ToJson(TTextWriterJsonFormat.jsonCompact,[]);
      end;
    end;

  finally
    FreeAndNil(frm);
  end;

end;


procedure TPermission_Edit.Load(const AJsonStr: PRawUtf8);
begin
 FJson:=DocDict(AJsonStr^,mFast);
 FJson.PathDelim:='.';
 ReLoad('permisson');
end;

procedure TPermission_Edit.LoadJson(const Json:IDocAny; ANode:TcxTreeListNode);
var
 v:TDocDictFields;
 val:TDocValue;
 obj:IDocObject;

 nd:TcxTreeListNode;
begin
  if ANode = nil then
   begin
     if cxTree.FocusedNode = nil then
      begin
        Exit;
      end
     else
      begin
        ANode:=cxTree.FocusedNode;
      end;
   end;

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
    if SameText(FRootName,'permisson') and CurrentID.IsEmpty then
    begin
      raise EInvalidOpException.CreateFmt('"%s (%s)" için ID boş olamaz.', [nd.Texts[1], nd.Texts[0]]);
    end;

    // Hiyerarşik kontrol
    if SameText(FRootName,'permisson') and (not ExpectedParentID.IsEmpty) then
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
      if SameText(FRootName,'permisson') and (not ParentID.IsEmpty) then
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
  FJson.A[FRootName].Clear;
  Ekle(FJson.A[FRootName], cxTree.Root);

  Result := FJson.ToJson(TTextWriterJsonFormat.jsonCompact, []);


end;

procedure TPermission_Edit.OnAddNode(Sender: TcxCustomTreeList; ANode: TcxTreeListNode);
begin
   ANode.CheckGroupType:=ncgCheckGroup;
  if ANode.Parent <> ANode.Root then
   ANode.Texts[1]:=ANode.Parent.Texts[1]+'.';

end;


procedure TPermission_Edit.SablonClick(Sender: TObject);
var
 itm : TMenuItem absolute sender;
 aList: IDocList;
begin
  try
    aList:=FJson.L['sablon'].O[itm.Tag].L['child'];
    if aList<>nil then
     begin
      LoadJson(aList,nil);
     end;
  finally

  end;

end;

procedure TPermission_Edit.ReLoad(const aRootName:string);
var
 i:Integer;
begin
   if FJson <> nil then
   FRootName :=aRootName;
   if not FJson.Exists(FRootName) then
      FJson.A[FRootName]:=DocList(mFast);
   //FJson.A[FRootName].Clear;

   //cxTree.BeforeUpdate;

   cxTree.Clear;
   LoadJson(FJson.A[FRootName],cxTree.Root);
   TcxTreeListHack(cxTree).OnAddNode:=OnAddNode;
   if SameText(FRootName,'permisson') then
    begin
     itmSablonlar._ClearSubMenu;
     if FJson.Exists('sablon') then
      begin
       for i := 0 to FJson.L['sablon'].Len -1 do
        begin
         itmSablonlar._Add(FJson.L['sablon'].O[i].S['name'])
         ._SetClick(SablonClick)
         ._SetTag(i)
         ._SetHint(FJson.L['sablon'].O[i].S['id']);
        end;
      end;


    end;

end;




procedure TPermission_Edit.SetEditMode(const Value: Boolean);
begin
  FEditMode := Value;
  pnlAlt.Visible:=Value;
  itmSablon.Visible:=Value;
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

function TcxTreeListNodeHelper._AddNode(AKod,ACaption: string; const AChecked: Boolean): TcxTreeListNode;
begin
 AKod :=_KodeFix(Self._Kod+'.'+AKod);

 Result :=_FindChildID(AKod);
 if Result = nil then
  begin
   Result:=Self.AddChild;
   Result.Texts[0]:=ACaption.Trim;
   //if Self = self.Root then
   // Result.Texts[1]:=Trim(AKod)
   //else
   Result._SetKod(AKod);
   Result.CheckGroupType:=ncgCheckGroup;
   Result.Checked:=AChecked;
   end
   else
     ShowMessage(Format('Bu id kullanılıyor. (%s -> %s)',[AKod,ACaption]))
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

function TcxTreeListNodeHelper._FindChildID(const AKod: string): TcxTreeListNode;
begin
   for var i := 0 to Self.Count -1 do
   begin
     if SameText(Self.Items[i]._Kod,AKod) then
      Exit(Self.Items[i]);
   end;
 result:=nil
end;



function TcxTreeListNodeHelper._Kod: string;
begin
 Result:=Trim(Self.Texts[1]);
end;

function TcxTreeListNodeHelper._KodeFix(const ACode: string): string;
begin
result:=ACode.Replace(' ','');
if result[1] ='.' then
System.Delete(result,1,1);
end;

function TcxTreeListNodeHelper._SetKod(aKod: string): TcxTreeListNode;
begin
self.Texts[1]:=aKod;
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
  FDataBinding :=TcxDBDataBinding.Create(Self,Self);
  { published 'default psDfm' ile AYNI olmak ZORUNDA (kit kurali,
    component-patterns.md): ayrisirsa DFM'e yazilmayan bir deger, sonraki
    yuklemede baska bir davranisa donusur. }
  FStorage := psDfm;
end;

procedure TRadPermission.DefineProperties(Filer: TFiler);
  function DoWrite: Boolean;
  begin
    { psDatabase'de tanimlarin tek kaynagi veritabanidir. DFM'e de yazsaydik
      iki kopya olurdu; dataset kapaliyken acilan bir form bayat DFM kopyasini
      tasir ve sonra onu veritabanina geri yazabilirdi. }
    if FStorage = psDatabase then
      Exit(False);

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
  if (not (csDesigning in ComponentState)) and (Storage = psDatabase)  then
    LoadFromField;


end;

procedure TRadPermission.SetDataBinding(const Value: TcxDBDataBinding);
begin
 FDataBinding.Assign(Value);
end;

function TRadPermission.LoadFromField: Boolean;
begin
  Result := FDataBinding.IsDataSourceLive;
  if Result then
    FTree := StringToUtf8(FDataBinding.Field.AsString);
end;

function TRadPermission.SaveToField: Boolean;
var
  LBizAldik: Boolean;
begin
  if not FDataBinding.IsDataSourceLive then
  begin
   raise ERadPermission.CreateFmt('Hata :%s -> %s',[FDataBinding.DataSource.Name,FDataBinding.DataField]);
   Exit;
  end;
  { Dataset ZATEN duzenleme modundaysa Post ETMEYIZ. Etseydik cagiranin
    ayni kayittaki DIGER bekleyen degisikliklerini de, o daha hazir
    olmadan islerdik - bilesenin isi yetki alanini yazmak, cagiranin kayit
    akisini yonetmek degil. O durumda alani doldurup birakiyoruz; Post
    cagirana ait. }

  LBizAldik := not (FDataBinding.DataSource.State in [dsEdit, dsInsert]);
  if LBizAldik then
    FDataBinding.SetEditMode;

  FDataBinding.Field.AsString := Utf8ToString(FTree);

  if LBizAldik then
    FDataBinding.UpdateDataSource;

  Result := True;
end;

procedure TRadPermission.Edit;
var
  LOncekiTree: RawUtf8;
begin
  { Alan bagliysa DFM'deki kopya bayat olabilir - duzenlemeye her zaman
    kaynagin guncel hâliyle baslanir. }

  LoadFromField;

  LOncekiTree := FTree;

  if csAncestor in ComponentState then
    TPermission_Edit.Load(@FTree, False)
  else
    TPermission_Edit.Load(@FTree, True);

  { TPermission_Edit.Load, @FTree'ye YALNIZCA ShowModal=mrOk VE IsEdit iken
    yazar (bkz. o metodun govdesi). Dolayisiyla degerin degismis olmasi
    "kullanici onayladi ve gercekten bir sey degisti" demektir. Iptal veya
    salt-okunur acilista burasi calismaz - gereksiz Edit/Post yok. }
  if FTree = LOncekiTree then
    Exit;                    { iptal edildi ya da hicbir sey degismedi }

  { psDfm: kaydetme isini DFM akisi yapar - bilesen editoru Designer.Modified
    cagirir ve form kaydedilirken Tree DFM'e yazilir (bkz. DefineProperties).
    psDatabase: SaveToField yazar ve yazamiyorsa SEBEBINI SOYLER - burasi veri
    kaybi noktasi, sessiz basarisizlik yok. }
  if FStorage = psDatabase then
    SaveToField;
end;

function TRadPermission.GetDataBinding: TcxDBDataBinding;
begin
 Result:=FDataBinding;
end;

procedure TRadPermission.Show;
begin
  { Salt okunur goruntuleme: kaynaktan tazele, geri YAZMA. }
  LoadFromField;
  TPermission_Edit.Load(@FTree, False);
end;

end.
