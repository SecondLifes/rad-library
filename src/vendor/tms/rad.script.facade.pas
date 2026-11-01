unit rad.script.facade;

(* Script'in gördüğü dünya: Db, Msg, Kullanici, Sirket, Param, Log, Mail. Host TRadScriptContext'i
   doldurur; TRadScriptFacade.Bind binder'a ve jobs'a kurucu olarak takar. Kural: overload ve
   varsayılan parametre YOK (RTTI kaydında kayboluyor). Nesneler motorun sahipliğinde (AddOwned).
   Bkz. docs/specs/rad.script.facade.md *)

interface

uses
  System.SysUtils, System.Classes, System.Variants, System.Generics.Collections, System.UITypes,
  Data.DB, Uni,
  rad.script, rad.script.engine, rad.script.hooks, rad.script.jobs;

type
  IRadScriptMailer = interface
    ['{7D4C1E52-9B3A-4F6E-8C21-5A0D3B7E9F14}']
    procedure Send(const ATo, ASubject, ABody: string);
  end;

  TRadScriptMessageEvent = reference to procedure(const AText: string; AKind: TMsgDlgType);
  TRadScriptConfirmEvent = reference to function(const AText: string): Boolean;

  /// Host'un bir kez doldurduğu bağlam; script'e bağlantı dizesi/parola verilmez.
  TRadScriptContext = class
  private
    FConnection: TUniConnection;
    FStore: IRadScriptStore;
    FUserId: Integer;
    FUserName: string;
    FUserCode: string;
    FCompanyCode: string;
    FCompanyName: string;
    FMailer: IRadScriptMailer;
    FOnLog: TProc<string>;
    FOnMessage: TRadScriptMessageEvent;
    FOnConfirm: TRadScriptConfirmEvent;
  public
    property Connection: TUniConnection read FConnection write FConnection;
    property Store: IRadScriptStore read FStore write FStore;
    property UserId: Integer read FUserId write FUserId;
    property UserName: string read FUserName write FUserName;
    property UserCode: string read FUserCode write FUserCode;
    property CompanyCode: string read FCompanyCode write FCompanyCode;
    property CompanyName: string read FCompanyName write FCompanyName;
    /// nil → Mail.Gonder ERadScript.
    property Mailer: IRadScriptMailer read FMailer write FMailer;
    /// nil → mORMot TSynLog.
    property OnLog: TProc<string> read FOnLog write FOnLog;
    /// nil → Vcl.Dialogs.MessageDlg.
    property OnMessage: TRadScriptMessageEvent read FOnMessage write FOnMessage;
    /// nil → KP: Soru False döner, diyalog yok. Formda host MessageDlg verir.
    property OnConfirm: TRadScriptConfirmEvent read FOnConfirm write FOnConfirm;
  end;

  /// Db.Sorgu(...) döner; zincir: Db.Sorgu('... :id').Param('id', 5).Deger
  TRadScriptQuery = class
  private
    FQuery: TUniQuery;
  public
    constructor Create(AConnection: TUniConnection; const ASql: string);
    destructor Destroy; override;
    function Param(const AName: string; const AValue: Variant): TRadScriptQuery;
    function Deger: Variant;
    function Sayi: Integer;
    procedure Calistir;
    function Ac: TDataSet;
    procedure Kapat;
  end;

  TRadScriptDb = class
  private
    FConnection: TUniConnection;
    FQueries: TObjectList<TRadScriptQuery>;
    FInTx: Boolean;   // Firebird'de Connection.InTransaction her SELECT sonrası True (FbDdlProbe); kendi bayrağımız
  public
    constructor Create(AConnection: TUniConnection);
    destructor Destroy; override;
    function Sorgu(const ASql: string): TRadScriptQuery;
    function Deger(const ASql: string): Variant;
    function Sayi(const ASql: string): Integer;
    procedure Calistir(const ASql: string);
    procedure BaslaIslem;
    procedure Onayla;
    procedure GeriAl;
  end;

  TRadScriptMsg = class
  private
    FContext: TRadScriptContext;
    FEngine: TRadScriptEngine;
    procedure Goster(const AText: string; AKind: TMsgDlgType);
  public
    constructor Create(AContext: TRadScriptContext; AEngine: TRadScriptEngine);
    procedure Bilgi(const AText: string);
    procedure Uyari(const AText: string);
    procedure Hata(const AText: string);
    function Soru(const AText: string): Boolean;
    /// Tipli kanca (OnValidate) ErrorText olarak okur.
    procedure HataMetni(const AText: string);
    function SonHata: string;
  end;

  TRadScriptKullanici = class
  private
    FId: Integer;
    FAd: string;
    FKod: string;
  public
    property Id: Integer read FId;
    property Ad: string read FAd;
    property Kod: string read FKod;
  end;

  TRadScriptSirket = class
  private
    FKod: string;
    FAd: string;
  public
    property Kod: string read FKod;
    property Ad: string read FAd;
  end;

  TRadScriptParams = class
  private
    FValues: TDictionary<string, string>;
  public
    constructor Create(const AStore: IRadScriptStore; const APackageIds: TArray<Integer>);
    destructor Destroy; override;
    function Deger(const AName: string): string;
    function DegerVarsayilan(const AName, ADefault: string): string;
  end;

  TRadScriptLog = class
  private
    FOnLog: TProc<string>;
  public
    constructor Create(const AOnLog: TProc<string>);
    procedure Yaz(const AText: string);
    procedure Hata(const AText: string);
  end;

  TRadScriptMail = class
  private
    FMailer: IRadScriptMailer;
  public
    constructor Create(const AMailer: IRadScriptMailer);
    procedure Gonder(const ATo, ASubject, ABody: string);
  end;

  TRadScriptFacade = class
  public
    /// Facade nesnelerini kurar ve motora açar; sahiplik motorda. AEngine.PackageIds dolu olmalı (Param için).
    class procedure Install(AEngine: TRadScriptEngine; AContext: TRadScriptContext);
    /// Binder'ın OnInstallFacade'ini bu bağlamla doldurur; jobs için PrepareProc verir.
    class procedure Bind(AContext: TRadScriptContext);
    class function PrepareProc(AContext: TRadScriptContext): TRadScriptPrepareEvent;
    /// Facade sınıflarını motora kayıt eder (initialization'da bir kez çağrılır).
    class procedure RegisterClasses;
  end;

implementation

uses
  Vcl.Dialogs, mormot.core.base, mormot.core.rtti, mormot.core.log, mormot.core.unicode;

resourcestring
  SErrNoMailer = 'Posta ayarlanmadı (Context.Mailer boş).';
  SErrTxNested = 'Zaten bir işlem (transaction) açık.';
  SErrTxNone = 'Açık işlem yok.';
  SErrNoParam = 'Sorguda böyle bir parametre yok: %s';
  SErrNoConnection = 'Db için bağlantı verilmedi (Context.Connection).';

{ TRadScriptQuery }

constructor TRadScriptQuery.Create(AConnection: TUniConnection; const ASql: string);
begin
  inherited Create;
  FQuery := TUniQuery.Create(nil);
  FQuery.Connection := AConnection;
  FQuery.SQL.Text := ASql;
end;

destructor TRadScriptQuery.Destroy;
begin
  FQuery.Free;
  inherited;
end;

function TRadScriptQuery.Param(const AName: string; const AValue: Variant): TRadScriptQuery;
var
  P: TUniParam;
begin
  P := FQuery.Params.FindParam(AName);
  if P = nil then
    raise ERadScript.CreateFmt(SErrNoParam, [AName]);
  P.Value := AValue;
  Result := Self;
end;

function TRadScriptQuery.Deger: Variant;
begin
  FQuery.Close;
  FQuery.Open;
  try
    if FQuery.Eof then Result := Null else Result := FQuery.Fields[0].Value;
  finally
    FQuery.Close;
  end;
end;

function TRadScriptQuery.Sayi: Integer;
var
  V: Variant;
begin
  V := Deger;
  if VarIsNull(V) then Result := 0 else Result := V;
end;

procedure TRadScriptQuery.Calistir;
begin
  FQuery.Close;
  FQuery.ExecSQL;
end;

function TRadScriptQuery.Ac: TDataSet;
begin
  FQuery.Close;
  FQuery.Open;
  Result := FQuery;
end;

procedure TRadScriptQuery.Kapat;
begin
  FQuery.Close;
end;

{ TRadScriptDb }

constructor TRadScriptDb.Create(AConnection: TUniConnection);
begin
  inherited Create;
  FConnection := AConnection;
  FQueries := TObjectList<TRadScriptQuery>.Create(True);
end;

destructor TRadScriptDb.Destroy;
begin
  if FInTx then
    try
      FConnection.Rollback;   // script Onayla demeden bitti: emniyetli taraf
    except
      // bağlantı kopmuş olabilir; yıkımda yükseltme yok
    end;
  FQueries.Free;   // script Kapat demese de serbest (EARS 2)
  inherited;
end;

function TRadScriptDb.Sorgu(const ASql: string): TRadScriptQuery;
begin
  if FConnection = nil then
    raise ERadScript.Create(SErrNoConnection);
  Result := TRadScriptQuery.Create(FConnection, ASql);
  FQueries.Add(Result);
end;

function TRadScriptDb.Deger(const ASql: string): Variant;
var
  Q: TRadScriptQuery;
begin
  Q := Sorgu(ASql);
  try
    Result := Q.Deger;
  finally
    FQueries.Remove(Q);
  end;
end;

function TRadScriptDb.Sayi(const ASql: string): Integer;
var
  Q: TRadScriptQuery;
begin
  Q := Sorgu(ASql);
  try
    Result := Q.Sayi;
  finally
    FQueries.Remove(Q);
  end;
end;

procedure TRadScriptDb.Calistir(const ASql: string);
var
  Q: TRadScriptQuery;
begin
  Q := Sorgu(ASql);
  try
    Q.Calistir;
  finally
    FQueries.Remove(Q);
  end;
end;

procedure TRadScriptDb.BaslaIslem;
begin
  if FConnection = nil then
    raise ERadScript.Create(SErrNoConnection);
  if FInTx then
    raise ERadScript.Create(SErrTxNested);
  FConnection.StartTransaction;
  FInTx := True;
end;

procedure TRadScriptDb.Onayla;
begin
  if not FInTx then
    raise ERadScript.Create(SErrTxNone);
  FInTx := False;
  FConnection.Commit;
end;

procedure TRadScriptDb.GeriAl;
begin
  if not FInTx then
    raise ERadScript.Create(SErrTxNone);
  FInTx := False;
  FConnection.Rollback;
end;

{ TRadScriptMsg }

constructor TRadScriptMsg.Create(AContext: TRadScriptContext; AEngine: TRadScriptEngine);
begin
  inherited Create;
  FContext := AContext;
  FEngine := AEngine;
end;

procedure TRadScriptMsg.Goster(const AText: string; AKind: TMsgDlgType);
begin
  if Assigned(FContext.OnMessage) then FContext.OnMessage(AText, AKind)
  else MessageDlg(AText, AKind, [mbOK], 0);
end;

procedure TRadScriptMsg.Bilgi(const AText: string);
begin
  Goster(AText, mtInformation);
end;

procedure TRadScriptMsg.Uyari(const AText: string);
begin
  Goster(AText, mtWarning);
end;

procedure TRadScriptMsg.Hata(const AText: string);
begin
  Goster(AText, mtError);
end;

function TRadScriptMsg.Soru(const AText: string): Boolean;
begin
  if Assigned(FContext.OnConfirm) then Result := FContext.OnConfirm(AText)
  else Result := False;   // KP: soru soracak kimse yok
end;

procedure TRadScriptMsg.HataMetni(const AText: string);
begin
  FEngine.LastErrorText := AText;
end;

function TRadScriptMsg.SonHata: string;
begin
  Result := FEngine.LastErrorText;
end;

{ TRadScriptParams }

constructor TRadScriptParams.Create(const AStore: IRadScriptStore; const APackageIds: TArray<Integer>);
var
  L: TObjectList<TRadScriptParam>;
  P: TRadScriptParam;
begin
  inherited Create;
  FValues := TDictionary<string, string>.Create;
  if (AStore = nil) or (Length(APackageIds) = 0) then Exit;
  L := AStore.ParamsOf(APackageIds);
  try
    for P in L do
      FValues.AddOrSetValue(System.SysUtils.LowerCase(P.Name), P.Value);
  finally
    L.Free;
  end;
end;

destructor TRadScriptParams.Destroy;
begin
  FValues.Free;
  inherited;
end;

function TRadScriptParams.Deger(const AName: string): string;
begin
  Result := DegerVarsayilan(AName, '');
end;

function TRadScriptParams.DegerVarsayilan(const AName, ADefault: string): string;
begin
  if not FValues.TryGetValue(System.SysUtils.LowerCase(AName), Result) then Result := ADefault;
end;

{ TRadScriptLog }

constructor TRadScriptLog.Create(const AOnLog: TProc<string>);
begin
  inherited Create;
  FOnLog := AOnLog;
end;

procedure TRadScriptLog.Yaz(const AText: string);
begin
  if Assigned(FOnLog) then FOnLog(AText)
  else TSynLog.Add.Log(sllInfo, StringToUtf8(AText));
end;

procedure TRadScriptLog.Hata(const AText: string);
begin
  if Assigned(FOnLog) then FOnLog('HATA: ' + AText)
  else TSynLog.Add.Log(sllError, StringToUtf8(AText));
end;

{ TRadScriptMail }

constructor TRadScriptMail.Create(const AMailer: IRadScriptMailer);
begin
  inherited Create;
  FMailer := AMailer;
end;

procedure TRadScriptMail.Gonder(const ATo, ASubject, ABody: string);
begin
  if FMailer = nil then
    raise ERadScript.Create(SErrNoMailer);
  FMailer.Send(ATo, ASubject, ABody);
end;

{ TRadScriptFacade }

class procedure TRadScriptFacade.RegisterClasses;
begin
  TRadScriptEngine.RegisterClasses([TRadScriptQuery, TRadScriptDb, TRadScriptMsg, TRadScriptKullanici,
    TRadScriptSirket, TRadScriptParams, TRadScriptLog, TRadScriptMail, TDataSet, TField]);
end;

class procedure TRadScriptFacade.Install(AEngine: TRadScriptEngine; AContext: TRadScriptContext);
var
  LDb: TRadScriptDb;
  LMsg: TRadScriptMsg;
  LUser: TRadScriptKullanici;
  LCompany: TRadScriptSirket;
  LParam: TRadScriptParams;
  LLog: TRadScriptLog;
  LMail: TRadScriptMail;
begin
  LDb := TRadScriptDb.Create(AContext.Connection);
  AEngine.AddOwned(LDb);
  AEngine.Expose('Db', LDb);
  LMsg := TRadScriptMsg.Create(AContext, AEngine);
  AEngine.AddOwned(LMsg);
  AEngine.Expose('Msg', LMsg);
  LUser := TRadScriptKullanici.Create;
  LUser.FId := AContext.UserId;
  LUser.FAd := AContext.UserName;
  LUser.FKod := AContext.UserCode;
  AEngine.AddOwned(LUser);
  AEngine.Expose('Kullanici', LUser);
  LCompany := TRadScriptSirket.Create;
  LCompany.FKod := AContext.CompanyCode;
  LCompany.FAd := AContext.CompanyName;
  AEngine.AddOwned(LCompany);
  AEngine.Expose('Sirket', LCompany);
  LParam := TRadScriptParams.Create(AContext.Store, AEngine.PackageIds);
  AEngine.AddOwned(LParam);
  AEngine.Expose('Param', LParam);
  LLog := TRadScriptLog.Create(AContext.OnLog);
  AEngine.AddOwned(LLog);
  AEngine.Expose('Log', LLog);
  LMail := TRadScriptMail.Create(AContext.Mailer);
  AEngine.AddOwned(LMail);
  AEngine.Expose('Mail', LMail);
end;

class procedure TRadScriptFacade.Bind(AContext: TRadScriptContext);
begin
  TRadScriptBinder.OnInstallFacade := procedure(AEngine: TRadScriptEngine)
    begin
      Install(AEngine, AContext);
    end;
end;

class function TRadScriptFacade.PrepareProc(AContext: TRadScriptContext): TRadScriptPrepareEvent;
begin
  Result := procedure(AEngine: TRadScriptEngine)
    begin
      Install(AEngine, AContext);
    end;
end;

initialization
  TRadScriptFacade.RegisterClasses;

end.
