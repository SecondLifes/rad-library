
unit Rad.Register;

interface
uses System.Classes,System.Variants,Vcl.Controls,vcl.forms,Vcl.ActnList,System.Actions
,cxEditRepositoryEditor
//, cxEdit,cxFilterControlUtils ,cxDropDownEdit,

;

procedure Register;


implementation
 uses SqlClassesUni
 ,rad.rtl
 ,rad.db, Permission.Edit
 //, Dev.Extra
 //,Aksa.Collections,Aksa.BoundLabel
 //,Aksa.Vcl

 //,Aksa.Dev,Aksa.Dev.Extra,Aksa.Dev.FilterLookupEdit
 //,Rad.TMS

 //Aksa.DB,Aksa.Filtre, Aksa.Vcl,Aksa.Secure ,Vcl.BoundLabel
 //DevExpress
 //,sDBCreatorU,sDBMsSqlU, sEventCollectionU, sFieldCollectionU,sTableCollectionU
 ;


  procedure Register;
  begin

  //RegisterClass(TAksaForm);
  //RegisterNoIcon([TBase_DataModul,TAksaForm]);
  //RegisterCustomModule(TAksaForm, TCustomModule);
  //RegisterCustomModule(TBase_DataModul, TDataModuleCustomModule);

  RegisterComponents('RadKon',[
  TRadActionList
  ,TRadPermission//TAksaPropertiesStore,TAksaActionList,TAksaCmdList
  ,TRadConnection,TRadQuery,TRadEventHandler,TRadUnitOfWork
  //,TAkDBComboBox,TAksaLookupComboBox,TAksaDBLookupComboBox
  {
  TDepoValue,TStickyLabel
  //TCommadList,
  ,TAksaActionList


  //TSecureManager,TUSersForm,

  ,TaDBNavigator
  //,TFiltreTable

  }
  ]); //TUSersForm,TUserManager TSecurityManager,TSecurityForms

  RegisterActions('RadKon', [TRadAction], nil);

  //RegisterComponents('SDK DB', [TsDBMsSql, TsDBCreator]);
  end;


initialization

  //RegisterEditRepositoryItem(TEditRepositoryFilterLookupEditItem, 'TEditRepositoryFilterLookupEditItem');//   ayraç |
  //*RegisterEditRepositoryItem(TAksaComboBoxRepository, 'ComboBox Aksa');//   ayraç |
  //*RegisterEditRepositoryItem(TAksaLookupComboBoxRepository, 'LookupComboBox Aksa');//   ayraç |

  //GetRegisteredEditProperties.Register(TAkComboBoxDBProperties, 'TcxEditRepositoryComboBoxDBItem');
  //FilterEditsController.Register(TAkComboBoxDBProperties, TcxFilterComboBoxHelper);
  //dxUnitsLoader.AddUnit(SysInit.HInstance, dxThisUnitName, nil, TcxInplaceComboBoxCustomDrawHelper.Finalize);

finalization

  //UnRegisterEditRepositoryItem(TEditRepositoryFilterLookupEditItem);
  //*UnRegisterEditRepositoryItem(TAksaComboBoxRepository);
  //*UnRegisterEditRepositoryItem(TAksaLookupComboBoxRepository);

  //FilterEditsController.Unregister(TcxComboBoxProperties, TcxFilterComboBoxHelper);
  //dxUnitsLoader.RemoveUnit(SysInit.HInstance, dxThisUnitName, TcxInplaceComboBoxCustomDrawHelper.Finalize);

end.
end.
