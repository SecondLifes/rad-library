unit rad.script.typedhooks;

(* Var parametreli olaylar için elle yazılmış kancalar (sonda V4 kalıbı, TMS TatEventDispatcher yok).
   Var parametreler script'e değerle gider; geri yazma yalnız iptal alanı: Before False → CanClose/Error.
   Yeni tip = TRadHookBase alt sınıfı + RegisterHookClass. Bkz. docs/specs/rad.script.facade.md *)

interface

uses
  System.SysUtils, System.Classes, System.Variants, System.TypInfo,
  Vcl.Forms, Vcl.Controls,
  cxEdit,
  rad.script.engine, rad.script.hooks;

type
  /// TCloseQueryEvent: Form_OnCloseQuery_Before(Sender, CanClose): Boolean; False → CanClose := False.
  TRadCloseQueryHook = class(TRadHookBase)
  private
    procedure Handler(Sender: TObject; var CanClose: Boolean);
  protected
    function HandlerMethod: TMethod; override;
  end;

  /// TcxEditValidateEvent: edt_OnValidate_Before(Sender, DisplayValue, ErrorText): Boolean;
  /// False → Error := True, ErrorText := Msg.SonHata (varsa).
  TRadCxValidateHook = class(TRadHookBase)
  private
    procedure Handler(Sender: TObject; var DisplayValue: Variant; var ErrorText: TCaption; var Error: Boolean);
  protected
    function HandlerMethod: TMethod; override;
  end;

implementation

{ TRadCloseQueryHook }

function TRadCloseQueryHook.HandlerMethod: TMethod;
begin
  Result.Code := @TRadCloseQueryHook.Handler;
  Result.Data := Self;
end;

procedure TRadCloseQueryHook.Handler(Sender: TObject; var CanClose: Boolean);
begin
  BeginChain;
  try
    if not RunBefore([Sender, CanClose]) then
    begin
      CanClose := False;
      Exit;
    end;
    if Assigned(Original.Code) then
      TCloseQueryEvent(Original)(Sender, CanClose);
    RunAfter([Sender, CanClose]);
  finally
    EndChain;
  end;
end;

{ TRadCxValidateHook }

function TRadCxValidateHook.HandlerMethod: TMethod;
begin
  Result.Code := @TRadCxValidateHook.Handler;
  Result.Data := Self;
end;

procedure TRadCxValidateHook.Handler(Sender: TObject; var DisplayValue: Variant; var ErrorText: TCaption;
  var Error: Boolean);
var
  LText: string;
begin
  BeginChain;
  try
    Engine.LastErrorText := '';
    LText := ErrorText;
    if not RunBefore([Sender, DisplayValue, LText]) then
    begin
      Error := True;
      if Engine.LastErrorText <> '' then ErrorText := Engine.LastErrorText;
      Exit;
    end;
    if Assigned(Original.Code) then
      TcxEditValidateEvent(Original)(Sender, DisplayValue, ErrorText, Error);
    LText := ErrorText;
    RunAfter([Sender, DisplayValue, LText]);
  finally
    EndChain;
  end;
end;

initialization
  TRadScriptBinder.RegisterHookClass(TypeInfo(TCloseQueryEvent), TRadCloseQueryHook);
  TRadScriptBinder.RegisterHookClass(TypeInfo(TcxEditValidateEvent), TRadCxValidateHook);

end.
