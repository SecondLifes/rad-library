
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

  /// <summary>Opens the TRadPropertiesStore editor (Rad.Editor.FormState).</summary>
  TRadFormStateEditor = class(TComponentEditorBase)
    public
     procedure Edit; override;
     function GetItem:TArray<string>;override;
     procedure ExecuteVerb(Index: Integer); override;
  end;

  /// <summary>Opens the allowed-list editor of a TRadFormCustomizer.</summary>
  TRadFormCustomizerEditor = class(TComponentEditorBase)
    public
     procedure Edit; override;
     function GetItem:TArray<string>;override;
     procedure ExecuteVerb(Index: Integer); override;
  end;

  /// <summary>Items of a TRadPropertiesStore or Allowed of a TRadFormCustomizer, from the Object Inspector.</summary>
  TRadStateItemsProperty = class(TClassProperty)
    public
     function GetAttributes: TPropertyAttributes; override;
     procedure Edit; override;
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
uses System.Variants,Vcl.Controls,vcl.forms,Vcl.Dialogs, rad.formstate.component, rad.formstate.customizer, Rad.Editor.FormState,
cxNavigator,cxDBNavigator,
cxGridCustomTableView,
cxGridServerModeBandedTableView,
cxGridServerModeTableView,
Help.Dev,
rad.db,
Rad.Dev,          { RadChainAudit + TRadLookupComboBox / TRadDBLookupComboBox }
Permission.Edit,
Vcl.Menus,
DesignMenus,
rad.utils,
Rad.Editor.Tools,
Rad.Editor.FluentOptions


;

type
  { RadMenu: the IDE main menu for design-time tools. It is not a component
    editor, so no registered editor is replaced. A new tool is one AddTool line
    in Install plus its handler; the right-click RadMenu picks it up too. }
  TRadMenuTools = class(TRadToolMenu)
  strict private
    class var FInstance: TRadMenuTools;
    procedure FluentClick(Sender: TObject);
  public
    class procedure Install;
    class procedure Uninstall;
    /// <summary>Copies the tools under AItem; False if there are none.</summary>
    class function AddToolsTo(const AItem: IMenuItem): Boolean;
  end;

  { Right-click RadMenu. A selection editor only adds a verb: the designer creates
    every match, so component editors stay as they are. }
  TRadMenuSelectionEditor = class(TSelectionEditor)
  public
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
    procedure PrepareItem(Index: Integer; const AItem: IMenuItem); override;
  end;

procedure Register;
begin
  //RegisterComponentEditor(TAksaPropertiesStore,TAksaPropertiesStoreEditor);
  RegisterComponentEditor(TRadPermission,TRadPermissonEditor);
  RegisterComponentEditor(TRadPropertiesStore,TRadFormStateEditor);
  RegisterPropertyEditor(TypeInfo(TRadStateItems), TRadPropertiesStore, 'Items', TRadStateItemsProperty);
  RegisterComponentEditor(TRadFormCustomizer, TRadFormCustomizerEditor);
  RegisterPropertyEditor(TypeInfo(TRadStateItems), TRadFormCustomizer, 'Allowed', TRadStateItemsProperty);
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

  RegisterSelectionEditor(TComponent,TRadMenuSelectionEditor);
  TRadMenuTools.Install;
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

{ TRadFormStateEditor }

procedure TRadFormStateEditor.Edit;
begin
  // Modified only after OK: Cancel must leave the form untouched.
  if TRadFormStateEditorForm.Execute(TRadPropertiesStore(Component)) then
    Designer.Modified;
end;

procedure TRadFormStateEditor.ExecuteVerb(Index: Integer);
begin
  Edit;
end;

function TRadFormStateEditor.GetItem: TArray<string>;
begin
  Result := ['Durum Edit'#246'r'#252'...'];
end;

{ TRadStateItemsProperty }

function TRadStateItemsProperty.GetAttributes: TPropertyAttributes;
begin
  Result := inherited GetAttributes + [paDialog] - [paSubProperties];
end;

procedure TRadStateItemsProperty.Edit;
var
  LChanged: Boolean;
begin
  if GetComponent(0) is TRadFormCustomizer then
    LChanged := TRadFormStateEditorForm.Execute(TRadFormCustomizer(GetComponent(0)))
  else
    LChanged := TRadFormStateEditorForm.Execute(GetComponent(0) as TRadPropertiesStore);
  if LChanged then
    Modified;
end;

{ TRadFormCustomizerEditor }

procedure TRadFormCustomizerEditor.Edit;
begin
  if TRadFormStateEditorForm.Execute(TRadFormCustomizer(Component)) then
    Designer.Modified;
end;

procedure TRadFormCustomizerEditor.ExecuteVerb(Index: Integer);
begin
  Edit;
end;

function TRadFormCustomizerEditor.GetItem: TArray<string>;
begin
  Result := ['Kullan'#305'c'#305' '#304'zinleri...'];
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

  LRapor := TRadChain.Audit(LRoot);
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
  { Editor TcxNavigatorButton turundeki property'ler icin kayitli; o
    property'leri yayinlayan nesne TcxCustomNavigatorButtons'tir. Eskiden
    burada bir hata ayiklama ShowMessage'i ve exit'ten sonra kalan, ilgisiz iki
    sinifi (TcxControlNavigator -> TcxGridViewNavigator) birbirine cast eden
    olu kod vardi. }
  if GetComponent(0) is TcxCustomNavigatorButtons then
  begin
    TcxCustomNavigatorButtons(GetComponent(0))._TR;
    Modified;
  end;
end;

{ TRadMenuTools }

const
  CIdeToolsMenu = 'ToolsMenu';
  CPascalExt = '.pas';

procedure AttachAfterToolsMenu(const AServices: INTAServices; AItem: TMenuItem);
var
  I: Integer;
begin
  for I := 0 to AServices.MainMenu.Items.Count - 1 do
    if AServices.MainMenu.Items[I].Name = CIdeToolsMenu then
    begin
      AServices.AddActionMenu(CIdeToolsMenu, nil, AItem, True, False);
      Exit;
    end;
  { AddActionMenu raises on an unknown name, which would abort Register. }
  AServices.MainMenu.Items.Add(AItem);
end;

function CurrentDesigner: IDesigner;
var
  LModules: IOTAModuleServices;
  LModule: IOTAModule;
  LForm: INTAFormEditor;
  I: Integer;
begin
  Result := nil;
  if not Supports(BorlandIDEServices, IOTAModuleServices, LModules) then
    Exit;
  LModule := LModules.CurrentModule;
  if LModule = nil then
    Exit;
  for I := 0 to LModule.ModuleFileCount - 1 do
    if Supports(LModule.ModuleFileEditors[I], INTAFormEditor, LForm) then
      Exit(LForm.FormDesigner);
end;

function FluentSelectionOf(const ADesigner: IDesigner;
  const AList: IDesignerSelections): TRadFluentSelection;
var
  LItems: TArray<TPersistent>;
  I: Integer;
begin
  SetLength(LItems, AList.Count);
  for I := 0 to AList.Count - 1 do
    LItems[I] := AList[I];
  Result := TRadFluentDesign.Selection(LItems, ADesigner.Root);
end;

function AskFluentPath(const ADesigner: IDesigner; AClass: TClass; out APath: string): Boolean;
var
  LDialog: TSaveDialog;
  LImpl, LIntf, LForm: string;
begin
  ADesigner.ModuleFileNames(LImpl, LIntf, LForm);
  LDialog := TSaveDialog.Create(nil);
  try
    LDialog.Title := SRadFluentSaveTitle;
    LDialog.Filter := SRadFluentSaveFilter;
    LDialog.InitialDir := ExtractFilePath(LImpl);
    LDialog.FileName := TRadFluentDesign.DefaultFileName(AClass);
    LDialog.Options := LDialog.Options + [ofPathMustExist, ofNoChangeDir];
    Result := LDialog.Execute;
    APath := LDialog.FileName;
  finally
    LDialog.Free;
  end;
  { DefaultExt is no help: "Foo.Fluent" already has an extension for the dialog. }
  if Result and not SameText(ExtractFileExt(APath), CPascalExt) then
    APath := APath + CPascalExt;
end;

procedure WriteAndOpenFluent(const AClasses: TArray<TClass>; const APath: string;
  AOptions: TFluentGenOptions);
var
  LServices: IOTAServices;
  LActions: IOTAActionServices;
  LOpen: Boolean;
begin
  LServices := BorlandIDEServices as IOTAServices;
  LActions := BorlandIDEServices as IOTAActionServices;
  LOpen := (BorlandIDEServices as IOTAModuleServices).FindModule(APath) <> nil;
  { The merge reads the file from disk: unsaved editor changes must get there first. }
  if LOpen then
    LActions.SaveFile(APath);
  TRadFluentDesign.WriteUnit(AClasses, APath,
    LServices.ExpandRootMacro(TRadFluentDesign.LibraryPath(LServices.GetBaseRegistryKey)), AOptions);
  if LOpen then
    LActions.ReloadFile(APath)
  else
    LActions.OpenFile(APath);
end;

procedure ConvertToFluent(const ADesigner: IDesigner; const AList: IDesignerSelections);
var
  LSelection: TRadFluentSelection;
  LOptions: TFluentGenOptions;
  LPath: string;
begin
  LSelection := FluentSelectionOf(ADesigner, AList);
  if LSelection.Classes = nil then
  begin
    ShowMessage(SRadFluentNothing);
    Exit;
  end;
  if not TRadFluentOptionsForm.Ask(LSelection.Classes, LOptions) then
    Exit;
  if not AskFluentPath(ADesigner, LSelection.Classes[0], LPath) then
    Exit;
  WriteAndOpenFluent(LSelection.Classes, LPath, LOptions);
  if LSelection.Skipped <> nil then
    ShowMessage(Format(SRadFluentSkipped, [string.Join(', ', LSelection.Skipped)]));
end;

procedure TRadMenuTools.FluentClick(Sender: TObject);
var
  LDesigner: IDesigner;
  LList: IDesignerSelections;
begin
  LDesigner := CurrentDesigner;
  if LDesigner = nil then
  begin
    ShowMessage(SRadFluentNoDesigner);
    Exit;
  end;
  LList := CreateSelectionList;
  LDesigner.GetSelections(LList);
  ConvertToFluent(LDesigner, LList);
end;

class procedure TRadMenuTools.Install;
var
  LServices: INTAServices;
begin
  if (FInstance <> nil) or not Supports(BorlandIDEServices, INTAServices, LServices) then
    Exit;
  FInstance := TRadMenuTools.Create(nil);
  FInstance.AddTool(SRadFluentCaption, FInstance.FluentClick);
  AttachAfterToolsMenu(LServices, FInstance.Root);
end;

class procedure TRadMenuTools.Uninstall;
begin
  FreeAndNil(FInstance);
end;

class function TRadMenuTools.AddToolsTo(const AItem: IMenuItem): Boolean;
var
  I: Integer;
begin
  Result := (FInstance <> nil) and (FInstance.Root <> nil) and (FInstance.Root.Count > 0);
  if not Result then
    Exit;
  { The handlers belong to FInstance, which outlives any selection editor. }
  for I := 0 to FInstance.Root.Count - 1 do
    AItem.AddItem(FInstance.Root[I].Caption, 0, False, True, FInstance.Root[I].OnClick);
end;

{ TRadMenuSelectionEditor }

function TRadMenuSelectionEditor.GetVerb(Index: Integer): string;
begin
  Result := SRadMenuCaption;
end;

function TRadMenuSelectionEditor.GetVerbCount: Integer;
begin
  Result := 1;
end;

procedure TRadMenuSelectionEditor.PrepareItem(Index: Integer; const AItem: IMenuItem);
var
  LList: IDesignerSelections;
begin
  LList := CreateSelectionList;
  Designer.GetSelections(LList);
  AItem.Visible := (FluentSelectionOf(Designer, LList).Classes <> nil) and
    TRadMenuTools.AddToolsTo(AItem);
end;

initialization

finalization
  TRadMenuTools.Uninstall;

end.
