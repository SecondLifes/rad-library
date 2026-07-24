## 🎭 Behavioral Patterns

### Strategy — Variation of Algorithms

```pascal
unit MeuApp.Domain.Tax.Strategies;

interface

type
  ITaxStrategy = interface
    ['{E5F6-...}']
    function Calculate(ABaseValue: Currency): Currency;
    function GetDescription: string;
  end;

  TSimplesTaxStrategy = class(TInterfacedObject, ITaxStrategy)
  public
    function Calculate(ABaseValue: Currency): Currency;
    function GetDescription: string;
  end;

  TLucroPresumidoStrategy = class(TInterfacedObject, ITaxStrategy)
  public
    function Calculate(ABaseValue: Currency): Currency;
    function GetDescription: string;
  end;

  TIsencaoStrategy = class(TInterfacedObject, ITaxStrategy)
  public
    function Calculate(ABaseValue: Currency): Currency;
    function GetDescription: string;
  end;

implementation

const
  SIMPLES_RATE = 0.06;
  LUCRO_PRESUMIDO_RATE = 0.15;

function TSimplesTaxStrategy.Calculate(ABaseValue: Currency): Currency;
begin
  Result := ABaseValue * SIMPLES_RATE;
end;

function TSimplesTaxStrategy.GetDescription: string;
begin
  Result := 'Simples Nacional (6%)';
end;

function TIsencaoStrategy.Calculate(ABaseValue: Currency): Currency;
begin
  Result := 0;
end;

function TIsencaoStrategy.GetDescription: string;
begin
  Result := 'Isento de impostos';
end;
```

### Observer — Domain Events

```pascal
unit MeuApp.Domain.Order.Events;

interface

uses
  System.Generics.Collections,
  MeuApp.Domain.Order.Entity;

type
  IOrderEventObserver = interface
    ['{F6A7-...}']
    procedure OnOrderPlaced(AOrder: TOrder);
    procedure OnOrderCancelled(AOrder: TOrder);
  end;

  TOrderEventPublisher = class
  private
    FObservers: TList<IOrderEventObserver>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Subscribe(AObserver: IOrderEventObserver);
    procedure Unsubscribe(AObserver: IOrderEventObserver);
    procedure NotifyOrderPlaced(AOrder: TOrder);
    procedure NotifyOrderCancelled(AOrder: TOrder);
  end;

  //Observers concretos
  TEmailOrderNotifier = class(TInterfacedObject, IOrderEventObserver)
    procedure OnOrderPlaced(AOrder: TOrder);    //send confirmation by email
    procedure OnOrderCancelled(AOrder: TOrder); //sends cancellation notice
  end;

  TStockReservationObserver = class(TInterfacedObject, IOrderEventObserver)
    procedure OnOrderPlaced(AOrder: TOrder);    //reserve stock
    procedure OnOrderCancelled(AOrder: TOrder); //releases stock
  end;

implementation

constructor TOrderEventPublisher.Create;
begin
  inherited Create;
  FObservers := TList<IOrderEventObserver>.Create;
end;

destructor TOrderEventPublisher.Destroy;
begin
  FObservers.Free;
  inherited Destroy;
end;

procedure TOrderEventPublisher.NotifyOrderPlaced(AOrder: TOrder);
var
  LObserver: IOrderEventObserver;
begin
  for LObserver in FObservers do
    LObserver.OnOrderPlaced(AOrder);
end;
```

### Command — Wrapping Actions

```pascal
unit MeuApp.Application.Commands;

interface

uses
  MeuApp.Domain.Customer.Entity,
  MeuApp.Domain.Customer.Repository.Intf;

type
  ICommand = interface
    ['{A7B8-...}']
    procedure Execute;
    procedure Undo;
    function GetDescription: string;
  end;

  TCreateCustomerCommand = class(TInterfacedObject, ICommand)
  private
    FRepository: ICustomerRepository;
    FCustomerData: TCustomerDTO;
    FCreatedId: Integer;
  public
    constructor Create(ARepository: ICustomerRepository; AData: TCustomerDTO);
    procedure Execute;
    procedure Undo;
    function GetDescription: string;
  end;

  TDeleteCustomerCommand = class(TInterfacedObject, ICommand)
  private
    FRepository: ICustomerRepository;
    FCustomerId: Integer;
    FBackup: TCustomer;
  public
    constructor Create(ARepository: ICustomerRepository; ACustomerId: Integer);
    destructor Destroy; override;
    procedure Execute;
    procedure Undo;
    function GetDescription: string;
  end;

  //Command History (for Undo/Redo)
  TCommandHistory = class
  private
    FHistory: TStack<ICommand>;
    FRedoStack: TStack<ICommand>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Execute(ACommand: ICommand);
    procedure Undo;
    procedure Redo;
    function CanUndo: Boolean;
    function CanRedo: Boolean;
  end;
```

### Template Method — Algorithm Skeleton

```pascal
unit MeuApp.Application.Report.Generator;

interface

type
  TReportData = record
    Title: string;
    StartDate: TDate;
    EndDate: TDate;
  end;

  ///<summary>
  ///Abstract base that defines the skeleton of the report generation algorithm.
  ///Subclasses implement variable steps.
  ///</summary>
  TReportGenerator = class abstract
  protected
    FData: TReportData;
    procedure LoadData; virtual; abstract;
    procedure ValidateData; virtual;           //hook with default implementation
    procedure ProcessData; virtual; abstract;
    procedure FormatOutput; virtual; abstract;
    procedure SaveOutput(const APath: string); virtual; abstract;
    procedure SendNotification; virtual;       //optional hook — default: noop
  public
    //Template Method — cannot be overwritten (final)
    procedure Generate(AData: TReportData; const ASavePath: string);
  end;

  TSalesReportGenerator = class(TReportGenerator)
  protected
    procedure LoadData; override;
    procedure ProcessData; override;
    procedure FormatOutput; override;
    procedure SaveOutput(const APath: string); override;
    procedure SendNotification; override;
  end;

implementation

procedure TReportGenerator.Generate(AData: TReportData; const ASavePath: string);
begin
  FData := AData;
  LoadData;
  ValidateData;
  ProcessData;
  FormatOutput;
  SaveOutput(ASavePath);
  SendNotification;
end;

procedure TReportGenerator.ValidateData;
begin
  if FData.Title.Trim.IsEmpty then
    raise EValidationException.Create('Report title cannot be empty');
  if FData.StartDate > FData.EndDate then
    raise EValidationException.Create('StartDate must be before EndDate');
end;

procedure TReportGenerator.SendNotification;
begin
  //Default hook: empty. Subclasses can override to send email etc.
end;
```

### Chain of Responsibility — Validation Pipeline

```pascal
unit MeuApp.Application.Validation.Chain;

interface

uses
  MeuApp.Domain.Customer.Entity;

type
  TValidationResult = record
    IsValid: Boolean;
    ErrorMessage: string;
    class function Ok: TValidationResult; static;
    class function Fail(const AMessage: string): TValidationResult; static;
  end;

  IValidationHandler = interface
    ['{B8C9-...}']
    procedure SetNext(AHandler: IValidationHandler);
    function Validate(ACustomer: TCustomer): TValidationResult;
  end;

  TBaseValidationHandler = class(TInterfacedObject, IValidationHandler)
  private
    FNext: IValidationHandler;
  public
    procedure SetNext(AHandler: IValidationHandler);
    function Validate(ACustomer: TCustomer): TValidationResult; virtual;
  end;

  TNameValidationHandler = class(TBaseValidationHandler)
    function Validate(ACustomer: TCustomer): TValidationResult; override;
  end;

  TCpfValidationHandler = class(TBaseValidationHandler)
    function Validate(ACustomer: TCustomer): TValidationResult; override;
  end;

  TEmailValidationHandler = class(TBaseValidationHandler)
    function Validate(ACustomer: TCustomer): TValidationResult; override;
  end;

implementation

function TBaseValidationHandler.Validate(ACustomer: TCustomer): TValidationResult;
begin
  //Delegates to the next handler if there is one
  if Assigned(FNext) then
    Result := FNext.Validate(ACustomer)
  else
    Result := TValidationResult.Ok;
end;

function TNameValidationHandler.Validate(ACustomer: TCustomer): TValidationResult;
begin
  if ACustomer.Name.Trim.IsEmpty then
    Exit(TValidationResult.Fail('Nome é obrigatório'));
  if ACustomer.Name.Length < 3 then
    Exit(TValidationResult.Fail('Nome deve ter ao menos 3 caracteres'));
  Result := inherited Validate(ACustomer);  //continue the chain
end;
```

### State — Behavior by State

```pascal
unit MeuApp.Domain.Order.States;

interface

uses
  MeuApp.Domain.Order.Entity;

type
  IOrderState = interface
    ['{C9D0-...}']
    procedure Confirm(AOrder: TOrder);
    procedure Ship(AOrder: TOrder);
    procedure Deliver(AOrder: TOrder);
    procedure Cancel(AOrder: TOrder);
    function GetStatusDescription: string;
  end;

  //Condition: New (to be confirmed)
  TNewOrderState = class(TInterfacedObject, IOrderState)
  public
    procedure Confirm(AOrder: TOrder);
    procedure Ship(AOrder: TOrder);   //throws EInvalidOperationException
    procedure Deliver(AOrder: TOrder);
    procedure Cancel(AOrder: TOrder);
    function GetStatusDescription: string;
  end;

  //Status: Confirmed (awaiting shipment)
  TConfirmedOrderState = class(TInterfacedObject, IOrderState)
  public
    procedure Confirm(AOrder: TOrder);  //throws EInvalidOperationException
    procedure Ship(AOrder: TOrder);
    procedure Deliver(AOrder: TOrder);
    procedure Cancel(AOrder: TOrder);
    function GetStatusDescription: string;
  end;

  //Status: In transit
  TShippedOrderState = class(TInterfacedObject, IOrderState)
  public
    procedure Confirm(AOrder: TOrder);
    procedure Ship(AOrder: TOrder);
    procedure Deliver(AOrder: TOrder);
    procedure Cancel(AOrder: TOrder);  //requires calling the carrier
    function GetStatusDescription: string;
  end;

implementation

procedure TNewOrderState.Confirm(AOrder: TOrder);
begin
  AOrder.ConfirmedAt := Now;
  AOrder.SetState(TConfirmedOrderState.Create);  //transition
end;

procedure TNewOrderState.Ship(AOrder: TOrder);
begin
  raise EInvalidOperationException.Create('Pedido ainda não confirmado. Confirme antes de enviar.');
end;

function TNewOrderState.GetStatusDescription: string;
begin
  Result := 'Novo — aguardando confirmação';
end;
```
