## 🔧 Structural Patterns

### Adapter — Legacy Integration

```pascal
unit MeuApp.Infra.Payment.Adapter;

interface

type
  //Legacy system — cannot be changed
  TLegacyPaymentGateway = class
    procedure ProcessarPagamento(AValor: Double; ACodigoCartao: string);
  end;

  //Interface expected by the modern domain
  IPaymentGateway = interface
    ['{C3D4-...}']
    procedure ProcessPayment(AAmount: Currency; const ACardToken: string);
  end;

  //Adapter: translates the new call to the legacy one
  TLegacyPaymentAdapter = class(TInterfacedObject, IPaymentGateway)
  private
    FLegacy: TLegacyPaymentGateway;
  public
    constructor Create(ALegacy: TLegacyPaymentGateway);
    destructor Destroy; override;
    procedure ProcessPayment(AAmount: Currency; const ACardToken: string);
  end;

implementation

constructor TLegacyPaymentAdapter.Create(ALegacy: TLegacyPaymentGateway);
begin
  inherited Create;
  if not Assigned(ALegacy) then
    raise EArgumentNilException.Create('ALegacy gateway cannot be nil');
  FLegacy := ALegacy;
end;

destructor TLegacyPaymentAdapter.Destroy;
begin
  FLegacy.Free;  //The adapter has the legacy
  inherited Destroy;
end;

procedure TLegacyPaymentAdapter.ProcessPayment(AAmount: Currency; const ACardToken: string);
begin
  FLegacy.ProcessarPagamento(AAmount, ACardToken);
end;
```

### Decorator — Extension without Inheritance

```pascal
unit MeuApp.Infra.Logger.Decorators;

interface

type
  ILogger = interface
    ['{D4E5-...}']
    procedure Log(const ALevel, AMessage: string);
  end;

  TConsoleLogger = class(TInterfacedObject, ILogger)
    procedure Log(const ALevel, AMessage: string);
  end;

  //Decorator: adds timestamp
  TTimestampDecorator = class(TInterfacedObject, ILogger)
  private
    FInner: ILogger;
  public
    constructor Create(AInner: ILogger);
    procedure Log(const ALevel, AMessage: string);
  end;

  //Decorator: filters by minimum level
  TLevelFilterDecorator = class(TInterfacedObject, ILogger)
  private
    FInner: ILogger;
    FMinLevel: string;
  public
    constructor Create(AInner: ILogger; const AMinLevel: string);
    procedure Log(const ALevel, AMessage: string);
  end;

implementation

procedure TConsoleLogger.Log(const ALevel, AMessage: string);
begin
  Writeln(Format('[%s] %s', [ALevel, AMessage]));
end;

procedure TTimestampDecorator.Log(const ALevel, AMessage: string);
begin
  FInner.Log(ALevel, Format('%s | %s', [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), AMessage]));
end;

procedure TLevelFilterDecorator.Log(const ALevel, AMessage: string);
begin
  if ALevel >= FMinLevel then //DEBUG filter in production
    FInner.Log(ALevel, AMessage);
end;
```

### Facade — Simplifying Subsystems

```pascal
unit MeuApp.Application.NFe.Facade;

interface

uses
  MeuApp.Domain.NFe.Entity,
  MeuApp.Domain.NFe.Repository.Intf;

type
  ///<summary>
  ///Facade that simplifies the complete process of issuing NF-e,
  ///hiding XML, digital signature and communication with SEFAZ.
  ///</summary>
  TNFeFacade = class
  private
    FXmlBuilder: TNFeXmlBuilder;
    FSigner: TDigitalSigner;
    FTransmitter: TSefazTransmitter;
    FRepository: INFeRepository;
    procedure GenerateXml(ANFe: TNFe);
    procedure SignXml(ANFe: TNFe);
    procedure TransmitToSefaz(ANFe: TNFe);
    procedure PersistResult(ANFe: TNFe);
  public
    constructor Create(ARepository: INFeRepository);
    destructor Destroy; override;
    ///<summary>Issue NF-e: generates XML → signs → transmits → persists.</summary>
    procedure EmitirNFe(ANFe: TNFe);
    ///<summary>Cancels NF-e already issued.</summary>
    procedure CancelarNFe(const AChaveAcesso: string; const AMotivo: string);
  end;
```

### Proxy — Access Control

```pascal
unit MeuApp.Infra.Customer.Repository.Proxy;

interface

uses
  MeuApp.Domain.Customer.Entity,
  MeuApp.Domain.Customer.Repository.Intf,
  MeuApp.Domain.User.Entity;

type
  ///<summary>
  ///Security proxy that checks permissions before delegating to the real repository.
  ///</summary>
  TSecureCustomerRepositoryProxy = class(TInterfacedObject, ICustomerRepository)
  private
    FReal: ICustomerRepository;
    FCurrentUser: TUser;
    procedure CheckPermission(const AAction: string);
  public
    constructor Create(AReal: ICustomerRepository; ACurrentUser: TUser);
    function FindById(AId: Integer): TCustomer;
    function FindAll: TObjectList<TCustomer>;
    procedure Insert(ACustomer: TCustomer);
    procedure Update(ACustomer: TCustomer);
    procedure Delete(AId: Integer);
  end;

implementation

procedure TSecureCustomerRepositoryProxy.CheckPermission(const AAction: string);
begin
  if not FCurrentUser.HasPermission(AAction) then
    raise EAuthorizationException.CreateFmt(
      'User "%s" does not have permission: %s', [FCurrentUser.Login, AAction]);
end;

procedure TSecureCustomerRepositoryProxy.Delete(AId: Integer);
begin
  CheckPermission('CUSTOMER_DELETE');
  FReal.Delete(AId);
end;
```
