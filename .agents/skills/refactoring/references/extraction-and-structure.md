## 📋 Catalog of Code Smells and Techniques (1–6)

### 1. Extract Method — Long Method

**Detect:** Method with more than 20 lines or that needs comments to explain blocks.

**Before:**
```pascal
procedure TInvoiceService.GenerateInvoice(AOrder: TOrder);
var
  LTax, LSubtotal, LTotal: Currency;
  LItem: TOrderItem;
  LLines: TStringList;
begin
  //Calculate subtotal
  LSubtotal := 0;
  for LItem in AOrder.Items do
    LSubtotal += LItem.UnitPrice * LItem.Quantity;

  //Calculates tax
  if AOrder.IsExempt then LTax := 0
  else LTax := LSubtotal * 0.12;

  LTotal := LSubtotal + LTax;

  //Generates report lines
  LLines := TStringList.Create;
  try
    LLines.Add('NOTA FISCAL');
    LLines.Add(Format('Cliente: %s', [AOrder.Customer.Name]));
    for LItem in AOrder.Items do
      LLines.Add(Format('  %s x%d = R$%.2f',
        [LItem.Product.Name, LItem.Quantity, LItem.UnitPrice * LItem.Quantity]));
    LLines.Add(Format('Total: R$%.2f', [LTotal]));
    LLines.SaveToFile(AOrder.InvoicePath);
  finally
    LLines.Free;
  end;
end;
```

**After:**
```pascal
procedure TInvoiceService.GenerateInvoice(AOrder: TOrder);
var
  LSubtotal, LTax: Currency;
begin
  LSubtotal := CalculateSubtotal(AOrder);
  LTax      := CalculateTax(AOrder, LSubtotal);
  SaveInvoiceFile(AOrder, LSubtotal + LTax);
end;

function TInvoiceService.CalculateSubtotal(AOrder: TOrder): Currency;
var LItem: TOrderItem;
begin
  Result := 0;
  for LItem in AOrder.Items do
    Result := Result + (LItem.UnitPrice * LItem.Quantity);
end;

function TInvoiceService.CalculateTax(AOrder: TOrder; ASubtotal: Currency): Currency;
const
  STANDARD_TAX_RATE = 0.12;
begin
  if AOrder.IsExempt then Result := 0
  else Result := ASubtotal * STANDARD_TAX_RATE;
end;

procedure TInvoiceService.SaveInvoiceFile(AOrder: TOrder; ATotal: Currency);
var
  LLines: TStringList;
  LItem: TOrderItem;
begin
  LLines := TStringList.Create;
  try
    LLines.Add('NOTA FISCAL');
    LLines.Add(Format('Cliente: %s', [AOrder.Customer.Name]));
    for LItem in AOrder.Items do
      LLines.Add(Format('  %s x%d = R$%.2f',
        [LItem.Product.Name, LItem.Quantity, LItem.UnitPrice * LItem.Quantity]));
    LLines.Add(Format('Total: R$%.2f', [ATotal]));
    LLines.SaveToFile(AOrder.InvoicePath);
  finally
    LLines.Free;
  end;
end;
```

---

### 2. Extract Class — Class with Multiple Responsibilities

**Detect:** Class with fields of different nature, methods without cohesion.

**Before:**
```pascal
TEmployee = class
private
  //Personal data
  FName: string;
  FBirthDate: TDate;
  FCpf: string;
  //Salary data
  FBaseSalary: Currency;
  FBonusPercentage: Double;
  FDepartmentId: Integer;
  //HR Data
  FHiredDate: TDate;
  FVacationDaysLeft: Integer;
  FPerformanceScore: Integer;
public
  function CalculateGrossSalary: Currency;
  function CalculateNetSalary: Currency;
  function CalculateVacationPay: Currency;
  function GetNextVacationDate: TDate;
  function GetYearsOfService: Integer;
  function IsEligibleForBonus: Boolean;
end;
```

**After:**
```pascal
//Value Object — immutable
TEmployeePersonalData = record
  Name: string;
  BirthDate: TDate;
  Cpf: string;
end;

//Cohesive class: salary responsibility
TEmployeeSalary = class
private
  FBaseSalary: Currency;
  FBonusPercentage: Double;
public
  constructor Create(ABaseSalary: Currency; ABonusPercentage: Double);
  function CalculateGross: Currency;
  function CalculateNet: Currency;
  function IsEligibleForBonus: Boolean;
end;

//Cohesive class: HR responsibility
TEmployeeHrRecord = class
private
  FHiredDate: TDate;
  FVacationDaysLeft: Integer;
  FPerformanceScore: Integer;
public
  function GetYearsOfService: Integer;
  function GetNextVacationDate: TDate;
  function CalculateVacationPay(AGrossSalary: Currency): Currency;
end;

//Main entity — now just aggregates the parts
TEmployee = class
private
  FPersonalData: TEmployeePersonalData;
  FSalary: TEmployeeSalary;
  FHrRecord: TEmployeeHrRecord;
public
  constructor Create(AData: TEmployeePersonalData;
    ASalary: TEmployeeSalary; AHr: TEmployeeHrRecord);
  destructor Destroy; override;
  property PersonalData: TEmployeePersonalData read FPersonalData;
  property Salary: TEmployeeSalary read FSalary;
  property HrRecord: TEmployeeHrRecord read FHrRecord;
end;
```

---

### 3. Replace Nested Conditionals with Guard Clauses

**Detect:** More than 2 levels of `if..then..begin..end` nested.

**Before:**
```pascal
function TBankService.Withdraw(AAccount: TAccount; AAmount: Currency): Boolean;
begin
  Result := False;
  if Assigned(AAccount) then
  begin
    if AAccount.IsActive then
    begin
      if AAmount > 0 then
      begin
        if AAccount.Balance >= AAmount then
        begin
          if not AAccount.IsBlocked then
          begin
            AAccount.Balance := AAccount.Balance - AAmount;
            FRepository.Save(AAccount);
            Result := True;
          end;
        end;
      end;
    end;
  end;
end;
```

**After:**
```pascal
function TBankService.Withdraw(AAccount: TAccount; AAmount: Currency): Boolean;
begin
  if not Assigned(AAccount) then
    raise EArgumentNilException.Create('Conta não pode ser nula');
  if not AAccount.IsActive then
    raise EBusinessRuleException.Create('Conta inativa');
  if AAmount <= 0 then
    raise EValidationException.Create('Valor do saque deve ser positivo');
  if AAccount.Balance < AAmount then
    raise EInsufficientFundsException.CreateFmt(
      'Saldo insuficiente. Disponível: R$%.2f', [AAccount.Balance]);
  if AAccount.IsBlocked then
    raise EBusinessRuleException.Create('Conta bloqueada');

  AAccount.Balance := AAccount.Balance - AAmount;
  FRepository.Save(AAccount);
  Result := True;
end;
```

---

### 4. Replace Magic Numbers with Constants

**Detect:** Numeric or string literals without an explanatory name in the code.

**Before:**
```pascal
if AProduct.Stock < 5 then NotifyLowStock(AProduct);
LInstallmentValue := AOrder.Total / 12;
if APassword.Length < 8 then raise ...;
if AUser.FailedLogins >= 3 then LockAccount(AUser);
LInterest := ADebt * 0.02;  //late payment interest
```

**After:**
```pascal
const
  LOW_STOCK_THRESHOLD       = 5;
  MAX_INSTALLMENTS          = 12;
  MIN_PASSWORD_LENGTH       = 8;
  MAX_FAILED_LOGIN_ATTEMPTS = 3;
  MONTHLY_INTEREST_RATE     = 0.02;

if AProduct.Stock < LOW_STOCK_THRESHOLD then NotifyLowStock(AProduct);
LInstallmentValue := AOrder.Total / MAX_INSTALLMENTS;
if APassword.Length < MIN_PASSWORD_LENGTH then raise ...;
if AUser.FailedLogins >= MAX_FAILED_LOGIN_ATTEMPTS then LockAccount(AUser);
LInterest := ADebt * MONTHLY_INTEREST_RATE;
```

---

### 5. Replace Conditional with Polymorphism (Strategy/State)

**Detect:** `case` or `if/else if` string that checks the type or regime of an object.

**Before:**
```pascal
function TShippingService.CalculateFreight(AOrder: TOrder): Currency;
begin
  case AOrder.ShippingMethod of
    smPAC:     Result := AOrder.Weight * 2.50 + 8.0;
    smSEDEX:   Result := AOrder.Weight * 4.80 + 15.0;
    smTransp:  Result := AOrder.Weight * 1.20;
    smRetirada:Result := 0;
  end;
end;
```

**After:**
```pascal
//Interface Strategy
IFreightStrategy = interface
  ['{3C082DC8-0AFD-4050-A54F-3A50B0EF116D}']
  function Calculate(AWeightKg: Double): Currency;
  function GetCarrierName: string;
end;

//Implementations: one per variation
TPACFreightStrategy = class(TInterfacedObject, IFreightStrategy)
  function Calculate(AWeightKg: Double): Currency;   //weight * 2.50 + 8.0
  function GetCarrierName: string;
end;

TSEDEXFreightStrategy = class(TInterfacedObject, IFreightStrategy)
  function Calculate(AWeightKg: Double): Currency;   //weight * 4.80 + 15.0
  function GetCarrierName: string;
end;

TTransportadoraFreightStrategy = class(TInterfacedObject, IFreightStrategy)
  function Calculate(AWeightKg: Double): Currency;   //weight * 1.20
  function GetCarrierName: string;
end;

TRetiradaFreightStrategy = class(TInterfacedObject, IFreightStrategy)
  function Calculate(AWeightKg: Double): Currency;   //always 0
  function GetCarrierName: string;
end;

//Context — no longer needs the case
function TShippingService.CalculateFreight(AOrder: TOrder;
  AStrategy: IFreightStrategy): Currency;
begin
  Result := AStrategy.Calculate(AOrder.WeightKg);
end;
```

---

### 6. Introduce Parameter Object

**Detect:** Method with > 3 parameters, especially if several are optional.

**Before:**
```pascal
function TReportService.GenerateSalesReport(
  AStartDate: TDate;
  AEndDate: TDate;
  const AProductCategory: string;
  const ASalesRepId: string;
  AMinAmount: Currency;
  AGroupByMonth: Boolean;
  AIncludeReturns: Boolean): TReportResult;
```

**After:**
```pascal
TSalesReportFilter = record
  StartDate: TDate;
  EndDate: TDate;
  ProductCategory: string;
  SalesRepId: string;
  MinAmount: Currency;
  GroupByMonth: Boolean;
  IncludeReturns: Boolean;
  //Constructor with defaults
  class function Default: TSalesReportFilter; static;
end;

class function TSalesReportFilter.Default: TSalesReportFilter;
begin
  Result.StartDate       := StartOfYear(Date);
  Result.EndDate         := Date;
  Result.ProductCategory := '';
  Result.SalesRepId      := '';
  Result.MinAmount       := 0;
  Result.GroupByMonth    := False;
  Result.IncludeReturns  := False;
end;

function TReportService.GenerateSalesReport(
  AFilter: TSalesReportFilter): TReportResult;
```
