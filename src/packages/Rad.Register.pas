
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
 ,Rad.Dev
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
  ,TRadLookupComboBox,TRadDBLookupComboBox,TRadComboBox,TRadDBComboBox
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
  RegisterEditRepositoryItem(TRadComboBoxRepository, 'Rad ComboBox');//   ayraç |
  RegisterEditRepositoryItem(TRadLookupComboBoxRepository, 'Rad LookupComboBox');//   ayraç |

  //GetRegisteredEditProperties.Register(TAkComboBoxDBProperties, 'TcxEditRepositoryComboBoxDBItem');
  //FilterEditsController.Register(TAkComboBoxDBProperties, TcxFilterComboBoxHelper);
  //dxUnitsLoader.AddUnit(SysInit.HInstance, dxThisUnitName, nil, TcxInplaceComboBoxCustomDrawHelper.Finalize);

finalization

  //UnRegisterEditRepositoryItem(TEditRepositoryFilterLookupEditItem);
  UnRegisterEditRepositoryItem(TRadComboBoxRepository);
  UnRegisterEditRepositoryItem(TRadLookupComboBoxRepository);

  //FilterEditsController.Unregister(TcxComboBoxProperties, TcxFilterComboBoxHelper);
  //dxUnitsLoader.RemoveUnit(SysInit.HInstance, dxThisUnitName, TcxInplaceComboBoxCustomDrawHelper.Finalize);

end.
