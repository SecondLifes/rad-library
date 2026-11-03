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

type
  /// <summary>DevExpress classes for the script engine.</summary>
  TRadScriptDev = class abstract
  public
    /// TcxButton, cx editörleri (DB'li ve DB'siz), grid, layout, sayfa denetimi; TdxLayoutControl yerleşim akışı.
    class procedure RegisterAll; static;
  end;

procedure RegisterDevExpressClasses; deprecated 'Use TRadScriptDev.RegisterAll';


implementation

class procedure TRadScriptDev.RegisterAll;
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

{ Deprecated names }

procedure RegisterDevExpressClasses;
begin
  TRadScriptDev.RegisterAll;
end;

end.
