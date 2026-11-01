unit rad.script.dev;

(* DevExpress sınıflarını script motoruna kaydeden hazır liste + TdxLayoutControl yerleşim akışı kaydı
   (düzen/tasarımcı). Host başlangıçta bir kez çağırır. *)

interface

uses
  cxButtons, cxTextEdit, cxDBEdit, cxMemo, cxDropDownEdit, cxDBLookupComboBox, cxCalendar, cxCurrencyEdit,
  cxCheckBox, cxLabel, cxPC, cxGrid, cxGridLevel, cxGridDBTableView,
  System.Classes,
  dxLayoutControl, dxLayoutContainer,
  rad.script.engine, rad.script.hooks;

/// TcxButton, cx editörleri (DB'li ve DB'siz), grid, layout, sayfa denetimi; TdxLayoutControl yerleşim akışı.
procedure RegisterDevExpressClasses;

implementation

procedure RegisterDevExpressClasses;
var
  LHandler: TRadLayoutHandler;
begin
  TRadScriptEngine.RegisterClasses([
    TcxButton, TcxTextEdit, TcxDBTextEdit, TcxMemo, TcxDBMemo, TcxComboBox, TcxDBComboBox,
    TcxLookupComboBox, TcxDBLookupComboBox, TcxDateEdit, TcxDBDateEdit, TcxCurrencyEdit, TcxDBCurrencyEdit,
    TcxCheckBox, TcxDBCheckBox, TcxLabel, TcxPageControl, TcxTabSheet,
    TcxGrid, TcxGridLevel, TcxGridDBTableView,
    TdxLayoutControl, TdxLayoutItem, TdxLayoutGroup]);
  LHandler.Load := procedure(C: TComponent; S: TStream) begin TdxLayoutControl(C).LoadFromStream(S); end;
  LHandler.Save := procedure(C: TComponent; S: TStream) begin TdxLayoutControl(C).SaveToStream(S); end;
  LHandler.Customize := procedure(C: TComponent; AOn: Boolean) begin TdxLayoutControl(C).Customization := AOn; end;
  TRadScriptBinder.RegisterLayoutClass(TdxLayoutControl, LHandler);
end;

end.
