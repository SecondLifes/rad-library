---
description: "Design Patterns (GoF) in Delphi — Creational, Structural and Behavioral with Object Pascal"
globs: ["**/*.pas"]
alwaysApply: false
---

# Design Patterns GoF — Rules

Use these rules when implementing design patterns in Object Pascal/Delphi.

> **Interface GUIDs:** every `['{...}']` below is a real, unique GUID generated for this example. When writing new interfaces, always generate a fresh GUID (IDE: `Ctrl+Shift+G`, or `TGUID.NewGuid.ToString`) — never emit the literal placeholder text `{GUID}`, and never reuse a GUID across two different interfaces.

---

## 🏗️ Creational Patterns

### Factory Method

```pascal
//Product Interface
IButton = interface
  ['{EDF8C141-96C2-417D-98E8-2D3AB67DB22A}']
  procedure Render;
end;

//Abstract Creator
TButtonFactory = class abstract
public
  function CreateButton: IButton; virtual; abstract;
end;

//Concrete implementations
TVCLButton = class(TInterfacedObject, IButton)
  procedure Render;
end;

TFMXButton = class(TInterfacedObject, IButton)
  procedure Render;
end;
```

### Abstract Factory

```pascal
//Abstract factory interface
IUIFactory = interface
  ['{F104148C-C1E6-42AD-85C5-AE16DD3B98FB}']
  function CreateButton: IButton;
  function CreateDialog: IDialog;
end;

//Concrete factories by platform
TVCLFactory = class(TInterfacedObject, IUIFactory)
  function CreateButton: IButton;
  function CreateDialog: IDialog;
end;

TFMXFactory = class(TInterfacedObject, IUIFactory)
  function CreateButton: IButton;
  function CreateDialog: IDialog;
end;
```

### Singleton

```pascal
//Singleton thread-safe em Delphi
TAppConfig = class
private
  class var FInstance: TAppConfig;
  constructor Create;
public
  class function GetInstance: TAppConfig;
  class procedure ReleaseInstance;
  property DatabaseUrl: string read FDatabaseUrl write FDatabaseUrl;
end;

class function TAppConfig.GetInstance: TAppConfig;
begin
  if not Assigned(FInstance) then
    FInstance := TAppConfig.Create;
  Result := FInstance;
end;
```

> ⚠️ For multi-threaded environments use `TCriticalSection` when creating the instance.

### Builder

```pascal
//Builder for building complex queries
TQueryBuilder = class
private
  FSql: TStringBuilder;
  FParams: TDictionary<string, Variant>;
public
  constructor Create;
  destructor Destroy; override;
  function Select(const AFields: string): TQueryBuilder;
  function From(const ATable: string): TQueryBuilder;
  function Where(const ACondition: string): TQueryBuilder;
  function OrderBy(const AField: string): TQueryBuilder;
  function Build: string;
end;

//Fluent use (Fluent Interface)
var LSql: string;
begin
  LSql := TQueryBuilder.Create
    .Select('id, name, email')
    .From('customers')
    .Where('active = 1')
    .OrderBy('name')
    .Build;
end;
```

> ⚠️ Always `try..finally Builder.Free` for manually created builder instances.

### Prototype

```pascal
//Clonable via interface
IClonable = interface
  ['{8AE31E08-12F0-4C4F-8BB3-5244B029DA98}']
  function Clone: TObject;
end;

TCustomer = class(TInterfacedObject, IClonable)
private
  FId: Integer;
  FName: string;
public
  function Clone: TObject;
end;

function TCustomer.Clone: TObject;
var LClone: TCustomer;
begin
  LClone := TCustomer.Create;
  LClone.FId := FId;
  LClone.FName := FName;
  Result := LClone;
end;
```

---

## 🔧 Structural Patterns

### Adapter

```pascal
//Legacy system with incompatible interface
TOldPaymentGateway = class
  procedure ProcessarPagamento(AValor: Double; ACartao: string);
end;

//New interface expected by the domain
IPaymentGateway = interface
  ['{341BB356-7D8C-4913-99FF-C45A22202DEE}']
  procedure ProcessPayment(AAmount: Currency; const ACardToken: string);
end;

// Adapter fazendo a ponte
TPaymentGatewayAdapter = class(TInterfacedObject, IPaymentGateway)
private
  FOldGateway: TOldPaymentGateway;
public
  constructor Create(AOldGateway: TOldPaymentGateway);
  procedure ProcessPayment(AAmount: Currency; const ACardToken: string);
end;

procedure TPaymentGatewayAdapter.ProcessPayment(AAmount: Currency; const ACardToken: string);
begin
  FOldGateway.ProcessarPagamento(AAmount, ACardToken);
end;
```

### Decorator

```pascal
//Adds behavior without inheritance
ILogger = interface
  ['{8BADE402-1532-4A0F-98BC-16782FB337F8}']
  procedure Log(const AMessage: string);
end;

TConsoleLogger = class(TInterfacedObject, ILogger)
  procedure Log(const AMessage: string);
end;

//Decorator that adds timestamp
TTimestampLoggerDecorator = class(TInterfacedObject, ILogger)
private
  FInner: ILogger;
public
  constructor Create(AInner: ILogger);
  procedure Log(const AMessage: string);
end;

procedure TTimestampLoggerDecorator.Log(const AMessage: string);
begin
  FInner.Log(Format('[%s] %s', [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), AMessage]));
end;
```

### Facade

```pascal
//Simplifies complex NF-e issuance subsystem
TNFeFacade = class
private
  FXmlBuilder: TNFeXmlBuilder;
  FSigner: TDigitalSigner;
  FTransmitter: TSefazTransmitter;
  FStorage: INFeRepository;
public
  constructor Create(ARepo: INFeRepository);
  destructor Destroy; override;
  ///<summary>Issues NF-e hiding all the complexity of the subsystems.</summary>
  procedure EmitirNFe(ANFe: TNFe);
end;
```

### Proxy

```pascal
//Controlled access proxy (authorization)
ICustomerRepository = interface ... end;

TSecureCustomerRepositoryProxy = class(TInterfacedObject, ICustomerRepository)
private
  FReal: ICustomerRepository;
  FCurrentUser: TUser;
  procedure CheckPermission(const AAction: string);
public
  constructor Create(AReal: ICustomerRepository; ACurrentUser: TUser);
  function FindById(AId: Integer): TCustomer;
  procedure Delete(AId: Integer);
end;

procedure TSecureCustomerRepositoryProxy.Delete(AId: Integer);
begin
  CheckPermission('DELETE_CUSTOMER');
  FReal.Delete(AId);
end;
```

### Composite

```pascal
//Leaf or container component — treats evenly
IMenuComponent = interface
  ['{6861ACE3-E553-4639-B2F3-664564915B25}']
  procedure Render;
  function GetLabel: string;
end;

TMenuItem = class(TInterfacedObject, IMenuComponent)   // Folha
  procedure Render;
  function GetLabel: string;
end;

TMenuGroup = class(TInterfacedObject, IMenuComponent)  //Container
private
  FChildren: TList<IMenuComponent>;
public
  constructor Create;
  destructor Destroy; override;
  procedure Add(AItem: IMenuComponent);
  procedure Render;
  function GetLabel: string;
end;
```

---

## 🎭 Behavioral Patterns

### Strategy

```pascal
//Vary the calculation algorithm without changing the context
ITaxStrategy = interface
  ['{798745AF-D375-4887-968D-9D949F33F67F}']
  function Calculate(ABaseValue: Currency): Currency;
  function GetName: string;
end;

TSimplesTaxStrategy = class(TInterfacedObject, ITaxStrategy)
  function Calculate(ABaseValue: Currency): Currency;   // 6%
  function GetName: string;
end;

TLucroPresumidoStrategy = class(TInterfacedObject, ITaxStrategy)
  function Calculate(ABaseValue: Currency): Currency;   // 15%
  function GetName: string;
end;

//Context using strategy
TOrderCalculator = class
private
  FTaxStrategy: ITaxStrategy;
public
  constructor Create(ATaxStrategy: ITaxStrategy);
  function CalculateTotal(AOrder: TOrder): Currency;
end;
```

### Observer

```pascal
//Decoupled notification of domain events
IOrderObserver = interface
  ['{DCC75EDF-819D-460D-A002-4C2AB42A9336}']
  procedure OnOrderPlaced(AOrder: TOrder);
end;

TOrderEventPublisher = class
private
  FObservers: TList<IOrderObserver>;
public
  constructor Create;
  destructor Destroy; override;
  procedure Subscribe(AObserver: IOrderObserver);
  procedure Unsubscribe(AObserver: IOrderObserver);
  procedure Notify(AOrder: TOrder);
end;

//Observers concretos
TEmailNotifier = class(TInterfacedObject, IOrderObserver)
  procedure OnOrderPlaced(AOrder: TOrder);  //send email
end;

TStockUpdater = class(TInterfacedObject, IOrderObserver)
  procedure OnOrderPlaced(AOrder: TOrder);  //updates stock
end;
```

### Command

```pascal
//Encapsulates actions as objects (undo/redo, queues)
ICommand = interface
  ['{18BF147B-1810-4D16-9AD9-52427ACCD35A}']
  procedure Execute;
  procedure Undo;
end;

TCreateCustomerCommand = class(TInterfacedObject, ICommand)
private
  FRepository: ICustomerRepository;
  FCustomer: TCustomer;
  FCreatedId: Integer;
public
  constructor Create(ARepository: ICustomerRepository; ACustomer: TCustomer);
  procedure Execute;
  procedure Undo;
end;

//CommandBus / History
TCommandHistory = class
private
  FHistory: TStack<ICommand>;
public
  procedure Execute(ACommand: ICommand);
  procedure Undo;
end;
```

### Template Method

```pascal
//Defines the skeleton of the algorithm — subclasses fill in the gaps
TReportGenerator = class abstract
public
  //Template Method: defines the sequence
  procedure GenerateReport(const AFilePath: string);
protected
  procedure LoadData; virtual; abstract;
  procedure ProcessData; virtual; abstract;
  procedure WriteOutput(const AFilePath: string); virtual; abstract;
  procedure SendNotification; virtual;  //hook with default implementation
end;

procedure TReportGenerator.GenerateReport(const AFilePath: string);
begin
  LoadData;
  ProcessData;
  WriteOutput(AFilePath);
  SendNotification;
end;

TSalesReportGenerator = class(TReportGenerator)
protected
  procedure LoadData; override;
  procedure ProcessData; override;
  procedure WriteOutput(const AFilePath: string); override;
end;
```

### Chain of Responsibility

```pascal
//Pass the request through the chain until someone handles it
IRequestHandler = interface
  ['{4B1A129A-3260-4F25-97E5-4D0FD3ACDA2E}']
  procedure SetNext(AHandler: IRequestHandler);
  function Handle(ARequest: TValidationRequest): Boolean;
end;

TBaseHandler = class(TInterfacedObject, IRequestHandler)
private
  FNext: IRequestHandler;
public
  procedure SetNext(AHandler: IRequestHandler);
  function Handle(ARequest: TValidationRequest): Boolean; virtual;
end;

TNameValidationHandler = class(TBaseHandler)
  function Handle(ARequest: TValidationRequest): Boolean; override;
end;

TCpfValidationHandler = class(TBaseHandler)
  function Handle(ARequest: TValidationRequest): Boolean; override;
end;

TAgeValidationHandler = class(TBaseHandler)
  function Handle(ARequest: TValidationRequest): Boolean; override;
end;
```

### State

```pascal
//Behavior varies depending on internal state
IOrderState = interface
  ['{38DEBFED-45FD-4893-AE0E-878182857E33}']
  procedure Confirm(AOrder: TOrder);
  procedure Ship(AOrder: TOrder);
  procedure Cancel(AOrder: TOrder);
  function GetStatus: string;
end;

TNewOrderState = class(TInterfacedObject, IOrderState) ... end;
TConfirmedOrderState = class(TInterfacedObject, IOrderState) ... end;
TShippedOrderState = class(TInterfacedObject, IOrderState) ... end;
TCancelledOrderState = class(TInterfacedObject, IOrderState) ... end;

TOrder = class
private
  FState: IOrderState;
public
  procedure Confirm;  //delegation for FState.Confirm(Self)
  procedure Ship;
  procedure Cancel;
  procedure SetState(AState: IOrderState);
end;
```

---

## ✅ Checklist — Design Patterns in Delphi

- [ ] Define interface before implementing (`I` prefix)
- [ ] Inject dependencies via constructor (never hardcoded)
- [ ] Use `TInterfacedObject` in all interface implementations
- [ ] Creational patterns create objects — don't mix with business logic
- [ ] Behavioral patterns prefer interfaces to inheritance
- [ ] Avoid `with`, global variables and direct coupling in any pattern
- [ ] Cover each pattern with DUnitX tests using Fakes
