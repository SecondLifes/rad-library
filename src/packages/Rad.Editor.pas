
unit Rad.Editor;



interface

uses
{$IFNDEF DELPHIXE2}
  Classes, SysUtils, TypInfo, Data.DB,
{$ELSE}
  System.Classes, System.SysUtils, System.TypInfo,
{$ENDIF}
  DesignEditors, DesignIntf,ToolsAPI
  //, CRDesign, DADesign

  ;


type
 TPersistentHack = class(TPersistent)

 end;

 TComponentEditorBase = class(TComponentEditor)
    public
     //procedure Edit; override;
     //procedure ExecuteVerb(Index: Integer); override;
     function GetItem:TArray<string>;virtual; abstract;
     function GetVerb(Index: Integer): string; override;
     function GetVerbCount: Integer; override;
   end;

 TAksaPropertiesStoreEditor = class(TComponentEditorBase)
    public
     procedure Edit; override;
     function GetItem:TArray<string>;override;
     procedure ExecuteVerb(Index: Integer); override;
  end;

  TRadPermissonEditor = class(TComponentEditorBase)
    public
     procedure Edit; override;
     function GetItem:TArray<string>;override;
     procedure ExecuteVerb(Index: Integer); override;
  end;

  (* Zincir denetimi. Rad.Dev'deki RadChainAudit'i tasarim zamanindan
     cagirilabilir yapar: bilesene sag tik -> "Zinciri denetle".

     NEDEN GEREKLI: ChainWarning ve PullWarning yazildilar ama koddan
     cagrilmadikca sessizler. Calisma zamaninda bir {$IFDEF DEBUG} satiri
     yeterli; tasarim zamaninda ise formu duzenleyen kisinin elinin altinda
     olmasi gerekiyor - yanlis yapilandirma tam da orada uretiliyor.

     Hicbir sey DEGISTIRMEZ, o yuzden Designer.Modified cagrilmaz. *)
  TRadChainAuditEditor = class(TComponentEditorBase)
    public
     procedure Edit; override;
     function GetItem:TArray<string>;override;
     procedure ExecuteVerb(Index: Integer); override;
  end;

 TAksaCmdListEditor = class(TComponentEditorBase)
    public
     procedure Edit; override;

  end;

   TListBase = class(TStringProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
    procedure DoList(List: TStrings); virtual; abstract;
  end;

   TListDBFields = class(TListBase)
  public
    function GetDataSet:TDataSet;virtual;
    procedure DoList(List: TStrings); override;
  end;

 TListCommand = class(TListDBFields)
  public
    procedure DoList(List: TStrings); override;
  end;

 TListField = class(TListDBFields)
  public
    function GetDataSet:TDataSet;override;
  end;


  {$REGION 'DevExpress'}

  TCxNavigatorEditor = class(TClassProperty)
    public
    procedure Edit; override; // <-- Display the editor here
  end;

  {$ENDREGION}


procedure Register;
implementation
uses System.Variants,Vcl.Controls,vcl.forms,Vcl.Dialogs,
cxNavigator,cxDBNavigator,
cxGridCustomTableView,
cxGridServerModeBandedTableView,
cxGridServerModeTableView,
Help.Dev,
rad.db,
Rad.Dev,          { RadChainAudit + TRadLookupComboBox / TRadDBLookupComboBox }
Permission.Edit


;

procedure Register;
begin
  //RegisterComponentEditor(TAksaPropertiesStore,TAksaPropertiesStoreEditor);
  RegisterComponentEditor(TRadPermission,TRadPermissonEditor);
  (* Zincir denetimi: AMaster/AComponent1..4 tasiyan HER dort sinifa.
     Combo ailesi de kaskad yuvalarina sahip ve kendi sessiz tuzagi var
     (AOnCascade siz zincir - bkz. TRadComboBoxProperties.CascadeWarning);
     onlari disarida birakmak denetimi yarim birakirdi - RADDEV-007. *)
  RegisterComponentEditor(TRadLookupComboBox,TRadChainAuditEditor);
  RegisterComponentEditor(TRadDBLookupComboBox,TRadChainAuditEditor);
  RegisterComponentEditor(TRadComboBox,TRadChainAuditEditor);
  RegisterComponentEditor(TRadDBComboBox,TRadChainAuditEditor);
  //RegisterComponentEditor(TAksaCmdList,TAksaCmdListEditor);

  RegisterPropertyEditor(TypeInfo (string), TRadAutoValueItem, 'Command', TListCommand);
  RegisterPropertyEditor(TypeInfo (string), TRadAutoValueItem, 'FieldName', TListDBFields);
  RegisterPropertyEditor(TypeInfo (string), TRadEventHandler, 'Name', TListDBFields);




  //RegisterPropertyEditor(TypeInfo(TcxCustomNavigatorButtons),nil,'',TCxNavigatorEditor);
  RegisterPropertyEditor(TypeInfo(TcxNavigatorButton),nil,'',TCxNavigatorEditor);

  {
  RegisterPropertyEditor(TypeInfo(string), TFiltreItem, 'FiltreAlan', TListField);
  RegisterPropertyEditor(TypeInfo(string), TFiltreItem, 'Filtre1', TListField);
  RegisterPropertyEditor(TypeInfo(string), TFiltreItem, 'Filtre2', TListField);



  //RegisterPropertyEditor (TypeInfo (string), TAutoSQLSetting, 'UniqueID', TListFieldProperty);




  // TMS

  RegisterComponentEditor(TAdvTouchKeyboard,TAdvSmoothTouchKeyBoardEditor);
  RegisterComponentEditor(TAdvSmoothTouchKeyBoard,TAdvSmoothTouchKeyBoardEditor);
  RegisterComponentEditor(TAdvPopupTouchKeyBoard,TAdvSmoothTouchKeyBoardEditor);
  RegisterComponentEditor(TAdvSmoothPopupTouchKeyBoard,TAdvSmoothTouchKeyBoardEditor);

  }
end;




 function FileOpenExec(const AFilter:string='All Files (*.*)|*.*'; const ATitle:string=''):string;
begin
      with TOpenDialog.Create(Application) do
    try
      Title := ATitle; { name of property as OpenDialog caption }
       Filter := AFilter;
      HelpContext := 0;
      Options := Options + [ofShowHelp, ofPathMustExist, ofFileMustExist];
      if Execute then Result:=Filename else Result:='';
    finally
      Free
    end
end;

function FileSaveExec(const AFilter:string='All Files (*.*)|*.*'; const ATitle:string=''):string;
begin
      with TSaveDialog.Create(Application) do
    try
      Title := ATitle; { name of property as OpenDialog caption }
       Filter := AFilter;
      HelpContext := 0;
      Options := Options + [ofShowHelp, ofPathMustExist, ofFileMustExist];
      if Execute then Result:=Filename else Result:='';
    finally
      Free
    end
end;



{ TComponentEditorBase }

function TComponentEditorBase.GetVerb(Index: Integer): string;
begin
  result:=GetItem[Index];
end;

function TComponentEditorBase.GetVerbCount: Integer;
begin
   result:=Length(GetItem);
end;


{ TAksaPropertiesStoreEditor }

procedure TAksaPropertiesStoreEditor.Edit;
begin
  //ShowPropertiesStoreEditor(TAksaPropertiesStore(GetComponent),GetComponent.Owner);
  Designer.Modified;
end;

procedure TAksaPropertiesStoreEditor.ExecuteVerb(Index: Integer);
begin
 Edit;
end;

function TAksaPropertiesStoreEditor.GetItem: TArray<string>;
begin
  Result:=['Düzenle']
end;

{ TAksaPermissonEditor }

{ TRadChainAuditEditor }

function TRadChainAuditEditor.GetItem: TArray<string>;
begin
  Result := ['Zinciri denetle...'];
end;

procedure TRadChainAuditEditor.ExecuteVerb(Index: Integer);
begin
  Edit;
end;

procedure TRadChainAuditEditor.Edit;
var
  LRoot: TComponent;
  LRapor: string;
begin
  (* Denetimin koku FORM (ya da frame) olmali: RadChainAudit butun bilesen
     agacini gezer ve paylasilan Properties orneklerini bir kez raporlar.
     Designer arayuzu yerine Owner kullaniliyor - sade VCL, surumler arasi
     surprizi yok. Owner yoksa bilesenin kendisiyle yetiniriz. *)
  LRoot := GetComponent;
  if LRoot = nil then
    Exit;
  if LRoot.Owner <> nil then
    LRoot := LRoot.Owner;

  LRapor := RadChainAudit(LRoot);
  if LRapor = '' then
    ShowMessage('Zincir denetimi temiz: rapor edilecek bir sey yok.')
  else
    ShowMessage(LRapor);
end;

procedure TRadPermissonEditor.Edit;
begin
  TRadPermission(GetComponent).Edit;
  Designer.Modified;
end;

procedure TRadPermissonEditor.ExecuteVerb(Index: Integer);
begin
  Edit;

end;

function TRadPermissonEditor.GetItem: TArray<string>;
begin
   Result:=['Düzenle']
end;

{ TListBase }

function TListBase.GetAttributes: TPropertyAttributes;
begin
 Result:=[paValueList, paSortList, paMultiSelect];
end;

procedure TListBase.GetValues(Proc: TGetStrProc);
var
  I: Integer;
  Values: TStringList;
begin
  Values:= TStringList.Create;
  try
  DoList (Values);
  for I:= 0 to Values.Count - 1 do
   Proc (Values[I]);
  finally
  Values.Free;
  end;
end;

{ TListDBFields }

procedure TListDBFields.DoList(List: TStrings);
var
tbl:TDataSet;
i:Integer;
begin
  tbl:=GetDataSet;

  if tbl<>nil then
  begin
    for i := 0 to tbl.FieldCount -1 do
    List.Add(tbl.Fields[i].FieldName);
  end;


end;

function TListDBFields.GetDataSet: TDataSet;
var
 cmp:TPersistent;
begin
  Result:=nil;
  cmp:=GetComponent(0);
  while cmp<>nil do
  begin
      cmp:=TPersistentHack(cmp).GetOwner;
       if cmp is TDataSet then begin Result:=TDataSet(cmp); exit; end;
  end;

end;

{ TListCommand }

procedure TListCommand.DoList(List: TStrings);
var
ds:TDataSet;

begin

 ds:=GetDataSet;
  {
 if (ds<>nil) and (TRadQuery(ds).Connection is TRadConnection) and (TRadConnection(TRadQuery(ds).Connection).CmdList<>nil) then
 List.Assign(TRadConnection(TRadQuery(ds).Connection).CmdList.CommandList);
 }
end;

{ TListField }

function TListField.GetDataSet: TDataSet;
var
 prName:string;
 //sql:TAksaQuery;
begin
  result:=inherited GetDataSet;
  prName:=GetPropName(GetPropInfo);

  if prName='FiltreAlan' then
   begin
   {
     if TFiltreTable(result).MasterSource<>nil then
     Result:=TFiltreTable(result).MasterSource.DataSet
     else
     Result:=nil;
   }
   end;


 {
     if cmp is TFiltreItem then
     begin
       cmp:=TFiltreItem(cmp).Collection.Owner;

       if cmp is TAksaQuery then
          Result:=cmp as TDataSet
       else
       begin
       ShowMessage('3');
         cmp:= TFiltreGroup(cmp).Collection.Owner;
         if GetPropName(GetPropInfo)='FieldSource' then   //FieldTagret
             Result:=cmp as TDataSet
          else  Result:=TFiltreTable(cmp).MasterSource.DataSet
       end;

     end
     else if cmp is TAutoValueItem then
      begin
        Result:= TAksaQuery(TAutoSQLSetting(TAutoValueItem(cmp).Collection.Owner).GetOwner)
      end;
  }
end;

{ TAksaCmdListEditor }

procedure TAksaCmdListEditor.Edit;
var
 edt:IComponentEditor;
begin

  // Designer üzerinden property'yi bul, Edit'i tetikle
  //edt:=GetComponentEditor(Component,Designer);
  //GetComponentProperties()

   //Designer.SelectItemName()
   //GetSelectionEditors
  //Designer.SelectComponent(Component);
  //(Designer as IDesigner).Edit(Component,GetPropInfo(Component, 'CommandList'));;

 // (Designer as IDesigner).Edit()
end;

{ TCxNavigatorEditor }

procedure TCxNavigatorEditor.Edit;
begin
  ShowMessage(GetComponent(0).ClassName) ;
    TcxCustomNavigatorButtons(GetComponent(0))._TR;
    exit;

  if GetComponent(0).ClassName='TcxGridTableViewNavigator' then
  begin
    TcxCustomNavigatorButtons(TcxGridViewNavigator(GetComponent(0)).Buttons)._TR;
    TcxGridViewNavigator(GetComponent(0)).InfoPanel.DisplayMask:='[RecordIndex] / [RecordCount]';
  end else if GetComponent(0).ClassName='TcxNavigator' then
  begin
    TcxCustomNavigatorButtons(TcxNavigator(GetComponent(0)).Buttons)._TR;
    TcxNavigator(GetComponent(0)).InfoPanel.DisplayMask:='[RecordIndex] / [RecordCount]';
  end else if GetComponent(0).ClassName='TcxGridViewNavigator' then
  begin
    TcxGridViewNavigator(GetComponent(0)).Buttons._TR;
    TcxGridViewNavigator(GetComponent(0)).InfoPanel.DisplayMask:='[RecordIndex] / [RecordCount]';
  end else if GetComponent(0).ClassName='TcxControlNavigator' then
  begin
    TcxGridViewNavigator(GetComponent(0)).Buttons._TR;
    TcxGridViewNavigator(GetComponent(0)).InfoPanel.DisplayMask:='[RecordIndex] / [RecordCount]';
  end;

end;

initialization

finalization

end.
