unit rad.script.dev;

(* DevExpress sınıflarını script motoruna kaydeden hazır liste. Host başlangıçta bir kez çağırır. *)

interface

uses
  cxButtons, cxTextEdit, cxDBEdit, cxMemo, cxDropDownEdit, cxDBLookupComboBox, cxCalendar, cxCurrencyEdit,
  cxCheckBox, cxLabel, cxPC, cxGrid, cxGridLevel, cxGridDBTableView,
  dxLayoutControl, dxLayoutContainer,
  rad.script.engine;

/// TcxButton, cx editörleri (DB'li ve DB'siz), grid, layout, sayfa denetimi.
procedure RegisterDevExpressClasses;

implementation

procedure RegisterDevExpressClasses;
begin
  TRadScriptEngine.RegisterClasses([
    TcxButton, TcxTextEdit, TcxDBTextEdit, TcxMemo, TcxDBMemo, TcxComboBox, TcxDBComboBox,
    TcxLookupComboBox, TcxDBLookupComboBox, TcxDateEdit, TcxDBDateEdit, TcxCurrencyEdit, TcxDBCurrencyEdit,
    TcxCheckBox, TcxDBCheckBox, TcxLabel, TcxPageControl, TcxTabSheet,
    TcxGrid, TcxGridLevel, TcxGridDBTableView,
    TdxLayoutControl, TdxLayoutItem, TdxLayoutGroup]);
end;

end.
