## 📋 Catalog of Code Smells and Techniques (7–10)

### 7. Remove `with` Statement

**Detect:** Any `with Objeto do begin...end` in the code.

**Rule:** Never use `with`. Prefer local variables or explicit qualification.

**Before:**
```pascal
procedure TCustomerForm.LoadData;
begin
  with qryCustomers do
  begin
    Close;
    SQL.Text := 'SELECT * FROM customers WHERE id = :id';
    ParamByName('id').AsInteger := FCustomerId;
    Open;
    with FieldByName('address') do
    begin
      edtStreet.Text := AsString;
    end;
  end;
end;
```

**After:**
```pascal
procedure TCustomerForm.LoadData;
var LAddressField: TField;
begin
  qryCustomers.Close;
  qryCustomers.SQL.Text := 'SELECT * FROM customers WHERE id = :id';
  qryCustomers.ParamByName('id').AsInteger := FCustomerId;
  qryCustomers.Open;

  LAddressField := qryCustomers.FieldByName('address');
  edtStreet.Text := LAddressField.AsString;
end;
```

---

### 8. Extract Interface / Invert Dependency

**Detect:** Service or class depending directly on concrete class (not interface).

**Before:**
```pascal
TOrderService = class
private
  FEmailSender: TSmtpEmailSender;      //concrete class
  FRepository:  TFireDACOrderRepo;     //concrete class
public
  constructor Create;  //instance internally — impossible to test
end;

constructor TOrderService.Create;
begin
  FEmailSender := TSmtpEmailSender.Create('smtp.server.com', 587);
  FRepository  := TFireDACOrderRepo.Create(GetDatabaseConnection);
end;
```

**After:**
```pascal
//1. Extract interfaces
IEmailSender = interface
  ['{1B557DBD-C928-4017-857D-099583BB7DC4}']
  procedure Send(const ATo, ASubject, ABody: string);
end;

IOrderRepository = interface
  ['{1059B69D-2317-44A3-A6FD-33F704D5F1E9}']
  function FindById(AId: Integer): TOrder;
  procedure Save(AOrder: TOrder);
end;

//2. Inject into the constructor — testable and flexible
TOrderService = class
private
  FEmailSender: IEmailSender;
  FRepository:  IOrderRepository;
public
  constructor Create(ARepository: IOrderRepository; AEmailSender: IEmailSender);
end;

//3. Em testes, injete fakes
TFakeEmailSender = class(TInterfacedObject, IEmailSender)
  FSentMessages: TStringList;
  procedure Send(const ATo, ASubject, ABody: string);
end;
```

---

### 9. Rename — Self-Descriptive Names

**Detect:** Variables like `x`, `tmp`, `data`, `flag`; methods like `Proc1`, `DoIt`, `Handle`.

```pascal
//❌ BEFORE
var x, tmp: Integer;
    s: string;
    flag: Boolean;
procedure Handle(d: TData);
function Calc(v: Double): Double;

//✅ AFTER
var LRetryCount, LMaxRetries: Integer;
    LCustomerFullName: string;
    LIsPaymentApproved: Boolean;
procedure ProcessCustomerOrder(AOrderData: TOrderData);
function CalculateShippingCost(AWeightKg: Double): Currency;
```

---

### 10. Inline Method — Unnecessarily Delegate Method

**Detect:** Method that just calls another method, without additional logic.

```pascal
//❌ BEFORE — unnecessary delegation
function TOrder.GetTotal: Currency;
begin
  Result := CalculateOrderTotal;  //just delegate
end;

function TOrder.CalculateOrderTotal: Currency;
begin
  Result := FSubtotal + FTax - FDiscount;
end;

//✅ AFTER — just a method with a descriptive name
function TOrder.GetTotal: Currency;
begin
  Result := FSubtotal + FTax - FDiscount;
end;
```

---

## 🔄 Secure Refactoring Process

```
1. ENTENDER  → Leia e compreenda o código atual
2. TESTAR    → Escreva/execute testes que cobrem o comportamento atual
3. PEQUENO   → Faça uma refatoração por vez (não tudo de uma vez)
4. TESTAR    → Execute os testes novamente — devem continuar passando
5. COMMIT    → Commit atômico por refatoração (mensagem: "refactor: extract CalculateTax")
6. REPETIR   → Próxima refatoração
```
