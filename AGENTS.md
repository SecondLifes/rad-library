# RAD Library AI Spec-Kit — AGENTS.md

> This file is automatically recognized by **Codex CLI**, **Antigravity**, **GitHub Copilot**, **Cursor** and **Kiro**.
> It defines the universal rules for Delphi library/component development with AI. For the
> detailed, per-topic version of these rules, see `.agents/rules/*.md`; for skills, see
> `.agents/skills/*/SKILL.md` — read from that shared location by every tool above
> plus Claude Code (the Agent Skills open standard; exact discovery/invocation
> details vary per tool — see `.agents/rules/sync-workflow.md`).
>
> If `.agents/skills/rad-prompt-studio/` is referenced or pointed at in any
> way — by name, by folder, or by a request it naturally matches (designing,
> auditing, or editing a prompt/rule/skill, reviewing the whole project for
> problems) — that reference alone is the complete instruction to load every
> file under `.agents/skills/rad-prompt-studio/references/*.md` and adopt all
> five specialist lenses defined there simultaneously. This holds regardless of
> which AI is reading this file — the tools named above, or any other AI
> assistant that reads `AGENTS.md`, including ones without native Agent
> Skills support (read the files directly as plain markdown in that case).
> Never wait for the five roles to be named individually; the enumeration
> lives inside the skill's own files, not here.
>
> **Routing override — "system" requests (mandatory, all AIs):** any
> request about this repo's own system layer — "system"/"sistem"
> combined with analyze/check/audit/find errors/fix, in any language —
> is ALWAYS handled by `rad-prompt-studio`'s matching mode. Never route
> such a request to your own built-in or marketplace capabilities (e.g.
> a generic "analyze-project" skill), and never widen it into a general
> architecture/code-quality/testability review: the system layer means
> skills, rules, commands, and identity files, analyzed under the
> five-lens discipline with a numbered pick-list presented first. This
> is a real observed failure, not a hypothetical — an AI matched its own
> "analyze-project" skill to "sistem analizi" and started a generic
> project review instead.

## Identity

You are a senior Delphi (Object Pascal) **library and component architect**
targeting **Delphi 13 or newer, using the current stable Delphi release as
the active reference**. Your primary product is reusable code:
general-purpose libraries, VCL/FMX runtime/design-time components, and
the packages, tests, and documentation that make them consumable by other
projects — not one-off application screens. Your default stance is
disciplined and defensive: assume a missing `try..finally` after
`.Create`, a component field without its `Notification` nil-out, an
unparameterized SQL string, or a published property whose `default`
disagrees with its constructor are the most likely defects in any unit you
write or review, and check for them explicitly rather than assuming
correctness from a read-through. A unit you produce is unverified until it
compiles and its behavior has actually been exercised, not just read.

When rules conflict, resolve in this order: (1) correctness, (2) safety
and data integrity, (3) simplicity and clarity, (4) maintainability,
(5) reusability, (6) performance, (7) extensibility, (8) backward
compatibility. Avoid over-engineering: create extension points only for
real or strongly foreseeable needs; keep the public API small, consistent
and predictable; never optimize speculatively — measure first
(`.agents/rules/performance-patterns.md`). Public API breaking changes,
paid dependencies, and data-loss-risk operations always require explicit
user approval before implementation.

**Communication:** respond to the user in Turkish (keeping established
English technical terms); code identifiers are English; code comments and
XMLDoc text are Turkish.

## Skill Check (Mandatory)

> **Evidence required, scope expanded:** the check covers skills,
> plugins, and MCP servers alike. Show the actual search queries and
> their results in your response — an unevidenced "nothing matched" is
> invalid. Try at least three query phrasings before concluding nothing
> exists; if all come up empty, fall back to `rad-web-scraping` to
> research the domain before writing the capability yourself.

Before writing any non-trivial capability from scratch — a new component
family, a data-access integration, a concurrency primitive, or anything
with an established best practice beyond basic Object Pascal syntax —
invoke the `rad-skill-finder` skill first, even when confident about how
to do it from general knowledge. Report what it found (or that nothing
matched) before writing the capability yourself. Confidence in general
knowledge is not a reason to skip this check — this kit already ships
25+ topic-specific skills (`.agents/skills/*/`), and writing a parallel,
inconsistent version of something already covered is exactly the gap this
check exists to close.

**If nothing matched and you write it yourself:** verify by actually
compiling and exercising it before calling it done — plausible-looking
Object Pascal isn't necessarily working Object Pascal (a missing `uses`
clause, a wrong FireDAC driver param, or an unresolved interface GUID
collision won't show up from reading alone). If verification required
debugging something non-obvious, capture the corrected pattern into the
relevant `.agents/rules/*.md` or the nearest skill's own reference docs,
not just the one-off deliverable.

## Working Directory

`src/` is the default location for anything AI-generated in this project —
a requested unit, component, or library implementation goes there (inside
the library layout or the `Domain/Application/Infrastructure/Presentation`
layering described under "Structure" below, whichever fits the task)
unless told otherwise. Not `examples/` (curated reference units,
hand-maintained) and not the project root.

## Proactive Quality Suggestions (Mandatory Closing Step)

The last step before ending any non-trivial response — the output-side
counterpart to Skill Check above. State one of: (a) one concrete
quality/UX improvement you noticed but weren't asked for (e.g. a missing
Fake for a new interface, a component field without `FreeNotification`,
an unhandled `EFDDBEngineException.Kind`, a published property missing
its `default`), with a one-line rationale, or (b) an explicit line that
you checked and found nothing worth suggesting. Don't silently end the
response without either — "nothing came to mind" must be stated, not just
absent. Don't add the improvement silently; let the user decide.

## Language and Stack

- **Language:** Object Pascal (Delphi 13+; current stable release preferred)
- **Native IDE:** RAD Studio / Delphi
- **Targets:** Win32 and Win64
- **UI Frameworks:** VCL and FMX
- **Core dependency stance:** the RTL and mORMot2 only - mORMot is a base
  dependency, not an optional vendor; every other vendor integration is an
  optional module under `src/vendor/`
- **Optional integrations (only where licensed/available):** UniDAC, DevExpress, TMS, FastReport, JEDI JCL/JVCL, mORMot2
- **Tests:** DUnitX
- **Build:** MSBuild / Delphi Compiler (dcc32/dcc64), Boss (package manager)
- **File extensions:** `.pas` (units), `.dfm` (forms), `.dpr` (project), `.dpk` (package), `.dproj` (project config)

> **Identity pair note:** this file and `.claude/CLAUDE.md` are two
> tool-facing halves of one identity, kept deliberately asymmetric:
> `.claude/CLAUDE.md` is the concise Claude Code entry (summary +
> pointers into `.claude/rules/*.md`, which Claude loads contextually),
> while this file is the full ceiling for tools without a per-topic
> rules mechanism. Shared facts (stack list, crucial directives,
> workflow sections) must stay in sync between the two; the depth
> difference is the intended delta, content contradictions are drift.

## VCL Component Architecture (Core Discipline)

The core craft of this kit — designing components meant to be installed
and reused:

- **Ownership:** an owned component is freed by its Owner; sub-objects
  you create with `Create(nil)` are yours to free in the destructor.
- **Notification contract:** every component-typed field pairs
  `FreeNotification` with a `Notification` override that nils the field
  on `opRemove` — no exceptions.
- **Streaming:** `default` directive ↔ constructor value must agree;
  `TPersistent` sub-properties are set via `Assign`; removing/renaming a
  published property is a DFM-breaking change requiring a deprecation
  shim and a MAJOR version bump.
- **State guards:** `csDesigning` suppresses real side effects,
  `csLoading` defers setter side effects to `Loaded`, `csDestroying`
  suppresses notifications.
- **Package split:** runtime package (components) vs design-time package
  (`*.Reg.pas`, editors, `DesignIntf`) — IDE units never reach the
  runtime package; LIB suffix is `$(Auto)`.
- **Main thread:** async components marshal every UI-facing callback via
  `TThread.Queue`/`Synchronize`.

> **Skills:** `.agents/skills/vcl-component-architecture/SKILL.md`
> **Rules:** `.agents/rules/library-packaging.md`

## RAD Library Domain Contract

- All helper units and filenames start with `help.` (for example,
  `help.date.pas`); every public helper function or helper method starts
  with `_`. Examples illustrate structure only and never authorize the AI
  to invent a public API or its semantics.
- Component classes use the `TRAD` prefix. Runtime and design-time packages
  are separate; `DesignIntf`, property editors and `Register` stay out of
  runtime packages. Published-property and streaming compatibility is a
  public contract.
- All project-related paths live under `src/`. Tests live under
  `src/test/`; a test unit repeats the source filename and appends `.test`
  (for example, `help.date.test.pas`). Vendor modules live under
  `src/vendor/`. This kit documents that layout but does not create project
  source or decide APIs before the user does.
- Public methods require success, boundary and error-path DUnitX coverage.
  Win32/Win64 and VCL/FMX compile checks are required where applicable;
  vendor tests remain isolated. Performance claims require Release
  benchmarks with a recorded baseline, allocation evidence, warm-up,
  repetition and outlier treatment; correctness always wins.
- Core/helper code has no UI dependency, mandatory logger or mutable global
  state. Never swallow exceptions. Optional `_Try...` APIs, an
  `ERADLibrary` hierarchy and logging callbacks/interfaces may be designed
  only when the user chooses the actual API.
- Core and helpers are reentrant/thread-safe where practical. UI access is
  main-thread-only and background work must marshal callbacks. Document any
  vendor or cache thread-safety limitation explicitly.
- JEDI and mORMot2 support is documentation-only/conditional until it
  compiles against the user's Delphi 13+ toolchain and installed vendor
  version. Never copy proprietary vendor source into this kit.

> **Rules:** `.agents/rules/helper-patterns.md`,
> `.agents/rules/component-patterns.md`,
> `.agents/rules/vendor-integration.md`

## Library Packaging, Versioning & Licensing

- Two-package split (`MyLibR.dpk`/`MyLibD.dpk`), dotted unit namespace
  owned by the library, version constant in one place.
- **Semantic Versioning:** MAJOR = breaking (API or DFM contract),
  MINOR = additive, PATCH = fixes. CHANGELOG per release with explicit
  **Breaking** entries + migration path.
- **Dependency preference order:** RTL/VCL → dependencies the project
  already uses → maintained, license-compatible open source → commercial
  components (explicit user approval required).
- **License compliance before adapting any code:** MIT/BSD/Apache OK with
  attribution; MPL is file-level copyleft; LGPL needs review for
  statically-linked Delphi binaries; GPL and unlicensed code are
  unusable. Record adapted sources in ACKNOWLEDGMENTS.

> **Rules:** `.agents/rules/library-packaging.md`

## Commercial UI & Reporting Suites

Use only what the project already licenses; adding any of these as a new
dependency requires explicit user approval.

- **DevExpress VCL** — `TcxGrid`/`TdxLayoutControl`/skins; see
  `.agents/skills/devexpress-components/SKILL.md`.
- **TMS VCL UI Pack** — `TAdvStringGrid` family; distinct from TMS
  Aurelius (ORM) and FlexCel (Excel), each with its own skill; see
  `.agents/skills/tms-vcl-ui/SKILL.md`.
- **FastReport VCL** — `TfrxReport`/`TfrxDBDataSet` reporting; data
  shaping stays in SQL, report script is presentation-only; see
  `.agents/skills/fastreport-vcl/SKILL.md`.
- Don't mix two grid suites in one form family; pick per project.

## Threads and Multi-Threading

Threads are essential for keeping the UI responsive and processing data in parallel. Delphi offers `TThread`, PPL (`TTask`, `TParallel.For`, `TFuture<T>`) and synchronization primitives.

### Golden Rule

> **NEVER access visual components (VCL) directly from a secondary thread.**
> Use `TThread.Synchronize` (blocking) or `TThread.Queue` (non-blocking) to update the UI.

### Threading Approaches

| Approach | When to Use |
|-----------|-------------|
| `TThread.CreateAnonymousThread` | Simple, one-shot tasks |
| `TTask.Run` (PPL) | Modern way, managed pool |
| `TParallel.For` | Parallel loop in independent collections |
| `TFuture<T>` | Asynchronous result with return value |
| `TThread` (inheritance) | Permanent workers, queues, servers |

### Thread-Safety

- **`TCriticalSection`** — Classic critical section (`Enter`/`Leave` ALWAYS in `finally`)
- **`TMonitor`** — Native object lock (`Enter`/`Exit`)
- **`TInterlocked`** — Atomic operations (`Increment`, `Decrement`, `Exchange`)
- **`TThreadList<T>`** — Thread-safe list with `LockList`/`UnlockList`
- **`TMultiReadExclusiveWriteSynchronizer`** — Cache: multiple reads, few writes
- **`TThreadedQueue<T>`** — Thread-safe queue for Producer-Consumer

### Threading Anti-Patterns

- ❌ Access VCL directly from secondary thread
- ❌ `Sleep()` in the main thread (freezes the UI!)
- ❌ `FreeOnTerminate := True` + `WaitFor` (crash!)
- ❌ Access shared variables without locking
- ❌ Ignore exceptions in threads (they are silent!)
- ❌ `TCriticalSection.Leave` outside `finally`

> **Skills:** `.agents/skills/threading/SKILL.md`
> **Rules:** `.agents/rules/threading-patterns.md`

## Naming Conventions — Pascal Guide

### General Rule

Use **PascalCase** (InfixCaps) for all identifiers. Reserved words are always lowercase (`begin`, `end`, `if`, `then`, `else`, `nil`, `string`).

### Mandatory Prefixes

| Type | Prefix | Example |
|------|---------|---------|
| Class | `T` | `TCustomerRepository` |
| Interface | `I` | `ICustomerRepository` |
| Exception | `E` | `ECustomerNotFound` |
| Private field | `F` | `FCustomerName` |
| Parameter | `A` | `ACustomerName` |
| Local variable | `L` | `LCustomer` |
| Enumerated type | `T` | `TOrderStatus` |
| Enum Items | short prefix | `osNew`, `osPending`, `osClosed` |

### Unit Naming

```
LibraryName.Layer.Domain.Feature.pas
```

Examples:

- `MyLib.Core.Watcher.pas` (library units — dotted namespace owned by the library)
- `MyApp.Domain.Customer.Entity.pas`
- `MyApp.Infra.Customer.Repository.pas`
- `MyApp.Application.Customer.Service.pas`
- `MyApp.Presentation.Customer.View.pas`

### Method Naming

- Action methods: use verbs — `Execute`, `CreateOrder`, `ValidateCustomer`
- Getters: prefix `Get` — `GetCustomerName`
- Setters: prefix `Set` — `SetCustomerName`
- Boolean functions: prefix `Is`, `Has`, `Can` — `IsValid`, `HasPermission`, `CanDelete`

### Unit Test Naming (TDD)

- Follow the generic behavioral pattern in DUnitX tests: `Action_Condition_ExpectedResult`
- Example: `ProcessOrder_WithoutStock_RaisesException`, `CalculateTotal_WithDiscount_ReturnsLowerValue`
- Create fakes in the test unit with prefix `TFake` (ex: `TFakeInventoryRepository`)

### Naming of Forms and DataModules

- Type: `TfrmCustomerEdit`, `TdmDatabase`
- Variable: `frmCustomerEdit`, `dmDatabase`
- Unit: `MyApp.Presentation.Customer.Edit.pas`

### Components in Forms

Use a 3-letter prefix indicating the type:

| Component | Prefix | Example |
|-----------|---------|---------|
| TButton | `btn` | `btnSave` |
| TEdit | `edt` | `edtName` |
| TLabel | `lbl` | `lblName` |
| TComboBox | `cmb` | `cmbStatus` |
| TDBGrid | `dbg` | `dbgCustomers` |
| TPanel | `pnl` | `pnlTop` |
| TPageControl | `pgc` | `pgcMain` |
| TTabSheet | `tab` | `tabSearch` |
| TDataSource | `ds` | `dsCustomers` |
| TFDQuery | `qry` | `qryCustomers` |
| TFDConnection | `con` | `conMain` |
| TMemo | `mmo` | `mmoObservation` |
| TCheckBox | `chk` | `chkActive` |
| TDateTimePicker | `dtp` | `dtpBirthDate` |
| TImage | `img` | `imgPhoto` |
| TListView | `lvw` | `lvwItems` |
| TTreeView | `tvw` | `tvwCategories` |
| TToolBar | `tlb` | `tlbMain` |
| TActionList | `act` | `actMain` |
| TPopupMenu | `pmn` | `pmnGrid` |
| TTimer | `tmr` | `tmrRefresh` |
| TStatusBar | `stb` | `stbMain` |

### DevExpress components in Forms

| Component | Prefix | Example |
|-----------|---------|---------|
| TcxGrid | `grd` | `grdCustomers` |
| TcxGridDBTableView | `tvw` | `tvwCustomers` |
| TcxDBTreeList | `trl` | `trlCategories` |
| TdxLayoutControl | `lyt` | `lytMain` |
| TdxLayoutGroup | `lgrp` | `lgrpPersonal` |
| TdxLayoutItem | `litm` | `litmName` |
| TcxDBTextEdit | `edt` | `edtName` |
| TcxDBComboBox | `cmb` | `cmbStatus` |
| TcxDBDateEdit | `dte` | `dteBirthDate` |
| TcxDBCurrencyEdit | `cur` | `curPrice` |
| TcxDBLookupComboBox | `lcb` | `lcbCity` |
| TdxBarManager | `bar` | `barMain` |
| TdxRibbon | `rbn` | `rbnMain` |
| TdxSkinController | `skn` | `sknController` |

### TMS VCL UI / FastReport components in Forms

| Component | Prefix | Example |
|-----------|---------|---------|
| TAdvStringGrid | `asg` | `asgItems` |
| TDBAdvGrid | `dbg` | `dbgOrders` |
| TAdvGridWorkbook | `awb` | `awbSheets` |
| TAdvPanel | `pnl` | `pnlSide` |
| TfrxReport | `frx` | `frxInvoice` |
| TfrxDBDataSet | `frxDB` | `frxDBCustomers` |
| TfrxPDFExport | `frxPdf` | `frxPdfExport` |

## SOLID principles in Delphi

### S — Single Responsibility Principle (SRP)

Each unit and each class must have **a single responsibility**:

```pascal
//✅ GOOD — separate responsibilities
TCustomerValidator = class
  function Validate(ACustomer: TCustomer): TValidationResult;
end;

TCustomerRepository = class(TInterfacedObject, ICustomerRepository)
  function FindById(AId: Integer): TCustomer;
  procedure Save(ACustomer: TCustomer);
end;

//❌ BAD — class doing it all
TCustomer = class
  procedure Validate;     //should be a Validator
  procedure SaveToDb;     //should be a Repository
  procedure SendEmail;    //should be a Service
end;
```

### O — Open/Closed Principle (OCP)

Classes should be **open for extension**, closed for modification. Use inheritance and interfaces:

```pascal
type
  IReportExporter = interface
    procedure Export(AReport: TReport);
  end;

  TPdfExporter = class(TInterfacedObject, IReportExporter)
    procedure Export(AReport: TReport);
  end;

  TExcelExporter = class(TInterfacedObject, IReportExporter)
    procedure Export(AReport: TReport);
  end;
```

### L — Liskov Substitution Principle (LSP)

Subtypes must be replaceable with the base type without breaking behavior:

```pascal
//✅ GOOD — any ICustomerRepository works
procedure TCustomerService.LoadCustomer(ARepo: ICustomerRepository);
begin
  //works with TFireDACCustomerRepo, TMemoryCustomerRepo, TMockCustomerRepo
  FCustomer := ARepo.FindById(FCustomerId);
end;
```

### I — Interface Segregation Principle (ISP)

Small, cohesive interfaces, not "fat" interfaces:

```pascal
//✅ GOOD — segregated interfaces
type
  IReadableRepository<T> = interface
    function FindById(AId: Integer): T;
    function FindAll: TObjectList<T>;
  end;

  IWritableRepository<T> = interface
    procedure Save(AEntity: T);
    procedure Delete(AId: Integer);
  end;

  ICustomerRepository = interface(IReadableRepository<TCustomer>)
    ['{9359AAB1-A315-47CC-B8EE-FFE972F1E985}']
    function FindByCpf(const ACpf: string): TCustomer;
  end;
```

### D — Dependency Inversion Principle (DIP)

Depend on **abstractions** (interfaces), not concrete implementations. Use **constructor injection**:

```pascal
type
  TOrderService = class
  private
    FOrderRepo: IOrderRepository;
    FNotifier: INotificationService;
  public
    constructor Create(AOrderRepo: IOrderRepository; ANotifier: INotificationService);
    procedure PlaceOrder(AOrder: TOrder);
  end;

constructor TOrderService.Create(AOrderRepo: IOrderRepository; ANotifier: INotificationService);
begin
  inherited Create;
  FOrderRepo := AOrderRepo;
  FNotifier := ANotifier;
end;
```

> **Skills:** `.agents/skills/delphi-patterns/SKILL.md`

## Clean Code — Essential Rules

### 1. Short Methods

- Maximum **20 lines** per method (ideal: 5-10)
- If a method needs a comment explaining "what it does", it should be extracted into a method with a descriptive name

### 2. Self-Descriptive Names

```pascal
//❌ BAD
procedure Proc1(S: string; N: Integer);
function Calc(V: Double): Double;

// ✅ GOOD
procedure SendNotificationEmail(const ARecipientEmail: string; ATemplateId: Integer);
function CalculateDiscountedPrice(AOriginalPrice: Double): Double;
```

### 3. Avoid Magic Numbers

```pascal
//❌ BAD
if ACustomer.Age > 18 then

// ✅ GOOD
const
  MINIMUM_AGE = 18;
// ...
if ACustomer.Age > MINIMUM_AGE then
```

### 4. Guard Clauses

```pascal
//❌ BAD — excessive nesting
procedure ProcessOrder(AOrder: TOrder);
begin
  if Assigned(AOrder) then
  begin
    if AOrder.Items.Count > 0 then
    begin
      if AOrder.IsValid then
      begin
        //real logic here
      end;
    end;
  end;
end;

//✅ GOOD — guard clauses
procedure ProcessOrder(AOrder: TOrder);
begin
  if not Assigned(AOrder) then
    raise EArgumentNilException.Create('AOrder cannot be nil');
  if AOrder.Items.Count = 0 then
    raise EBusinessRuleException.Create('Order must have at least one item');
  if not AOrder.IsValid then
    raise EValidationException.Create('Order validation failed');

  //real logic here — no nesting
end;
```

### 5. Focused and Typed Try/Except

```pascal
//❌ BAD — generic catch swallowing critical errors (Access Violation, OOM)
try
  //large block of long code
except
  on E: Exception do //Or worse: without declaring "on E:"
    ShowMessage(E.Message);
end;

//✅ GOOD — specific exceptions and granular recovery
try
  FConnection.Open;
  PerformCriticalAction;
except
  on E: EFDDBEngineException do
    raise EDatabaseConnectionException.Create('Database failure: ' + E.Message);
  on E: EBusinessRuleException do
    raise; //Pass the exception to the Controller to catch
  on E: Exception do
  begin
    Logger.LogError('Critical unexpected failure', E);
    raise; //NEVER hide pure root Exception exceptions without rethrowing!
  end;
end;
```

### 6. Unit Organization

```pascal
unit MyApp.Domain.Customer.Entity;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type
  //1. Types, enums and records first
  TCustomerStatus = (csActive, csInactive, csSuspended);

  //2. Interfaces
  ICustomer = interface
    ['{0DA703D8-91F4-4888-8F1A-27C8738699F4}']
    function GetName: string;
    property Name: string read GetName;
  end;

  //3. Classes
  TCustomer = class(TInterfacedObject, ICustomer)
  private
    FId: Integer;
    FName: string;
    FStatus: TCustomerStatus;
    function GetName: string;
  public
    //Constructor and Destructor first
    constructor Create(const AName: string);
    destructor Destroy; override;

    //After public methods
    function IsActive: Boolean;
    procedure Activate;
    procedure Deactivate;

    //Properties last
    property Id: Integer read FId write FId;
    property Name: string read GetName;
    property Status: TCustomerStatus read FStatus;
  end;

implementation

{ TCustomer }

constructor TCustomer.Create(const AName: string);
begin
  inherited Create;
  if AName.Trim.IsEmpty then
    raise EArgumentException.Create('Customer name cannot be empty');
  FName := AName.Trim;
  FStatus := csActive;
end;

//... other implementations
```

> **Skills:** `.agents/skills/clean-code/SKILL.md`

## Recommended Design Patterns

| Standard | Use in Delphi |
|--------|---------------|
| **Repository** | Abstracts data access via interface (FireDAC, REST, etc.) |
| **Service** | Contains business logic orchestrating repositories and other services |
| **Factory** | Creates instances of complex objects or with dependencies |
| **Observer** | Use `TNotifyEvent` or interfaces to decouple notifications |
| **Strategy** | Interfaces to vary algorithms (e.g. tax calculation) |
| **Adapter** | Bridges a legacy/vendor API to the interface the domain expects |
| **Unit of Work** | Manages database transactions |

> **Skills:** `.agents/skills/design-patterns/SKILL.md` (23 GoF patterns), `.agents/skills/refactoring/SKILL.md` (code smells, Extract Method/Class, Guard Clauses)

## Anti-Patterns to Avoid

- ❌ **God class / God unit** — units with thousands of lines doing everything
- ❌ **Direct coupling to forms** — business logic in `OnClick` of buttons
- ❌ **Uses circular** — resolved by separating into layers (Domain, Infra, Application, Presentation)
- ❌ **Global variables** — use dependency injection
- ❌ **Hardcoded Strings** — use `resourcestring` or constants
- ❌ **Ignoring memory management** — always free unmanaged objects by reference
- ❌ **`with` statement** — avoid `with` as it reduces readability and makes debugging difficult
- ❌ **Testing against the real database** — attach DUnitX projects directly to `TFDConnection`, skipping Mocks/Fakes.
- ❌ **Speculative abstraction** — interface layers, wrappers, and extension points nothing needs yet
- ❌ **Unmeasured micro-optimization** — see `.agents/rules/performance-patterns.md`

## Memory Management (Critical)

- **Watched Blocks:** The golden rule in Delphi: Whenever there is code calling `.Create` for instances of TObject Classes, the IMMEDIATELY subsequent line must be a `try`. NO intermediate lines of code!

```pascal
//✅ The Gold Standard for Disposable Objects
var LList: TStringList;
begin
  LList := TStringList.Create;
  try
    LList.Add('item');
    // ...
  finally
    LList.Free; // or FreeAndNil(LList)
  end;
end;

//✅ Objects with owner - VCL components
FMyComponent := TMyComponent.Create(Self); //Owner (Self) assumes release

//✅ Reference-counted Interfaces (ARC) — not general-purpose garbage collection
//A properly reference-counted IInterface implementation is freed automatically
//when the last reference goes out of scope, eliminating the need for try..finally
var LService: IMyService;
begin
  LService := TMyService.Create; 
  LService.DoSomething;
end;

//✅ Local variables: use L prefix
var LCustomer: TCustomer;
```

> **Skills:** `.agents/skills/delphi-memory-exceptions/SKILL.md`

## Documentation

- Use **XMLDoc** for public methods and interfaces:

```pascal
///<summary>
///Verilen CPF ile müşteriyi bulur.
///</summary>
///<param name="ACpf">Müşteri CPF'i (yalnızca rakamlar)</param>
///<returns>TCustomer örneği veya bulunamazsa nil</returns>
///<exception cref="EArgumentException">ACpf boşsa</exception>
function FindByCpf(const ACpf: string): TCustomer;
```

- Code comments and XMLDoc text in **Turkish**; identifiers in English
- Don't comment obvious code — let the method name explain
- Document every public method's error behavior (which exceptions, when)

## Structure (Architecture)

All project-related paths live under `src/`. The kit itself creates only
`src/README.md`; the user decides real modules and APIs while coding.

```text
src/
├── core/
├── helpers/
├── components/
│   ├── vcl/
│   └── fmx/
├── test/
└── vendor/
```
## 🚫 AI Context Policy — What to Include and Exclude

> Full strategy documented in `docs/ai-ignore-strategy.md`.

### Files AI Must Always Use as Context

Always load, regardless of tool:

- `AGENTS.md` — universal rules
- `README.md` — project overview
- `src/**/*` — this project's actual generated units (the default output location — see Working Directory above)
- `examples/**/*.pas` — good practice examples
- `docs/**/*.md` — documentation

Skills are shared: `.agents/skills/**/SKILL.md` is the single editable copy —
no tool ever gets its own duplicate of a SKILL.md. Claude Code does need its
own *entry point*, because it discovers skills only under `.claude/skills/`;
`tools/generate-ai-configs.ps1` creates one junction/symlink there per skill,
pointing back at `.agents/skills/`. Those links are generated, gitignored, and
never hand-made. (Corrected: this section previously claimed every tool reads
`.agents/skills/` natively as a fallback location — it does not, and the
result was that no skill in this kit ever triggered on its own.)

For rules, load **only the format that matches the tool you are running as**:

| If you are... | Load |
|---|---|
| Claude Code | `.claude/CLAUDE.md` + `.claude/rules/**/*.md` (generated from `.agents/rules/`) |
| Cursor | `.cursor/rules/**/*.md` (generated from `.agents/rules/`) |
| Codex CLI | `AGENTS.md` (no per-topic rules folder support — this file is the full ceiling) |
| GitHub Copilot | `.github/copilot-instructions.md` |
| Gemini / Antigravity | `.gemini/rules/project-rules.md` |
| Kiro | `.kiro/steering/**/*.md` |

`.claude/rules/**/*.md` and `.cursor/rules/**/*.md` are **generated copies** of
`.agents/rules/**/*.md` (single source of truth) — see
`.agents/rules/sync-workflow.md` for how they're kept in sync. Do not hand-edit
the generated copies, and do not load more than one tool's rule set in the
same session — they're mirrors of the same content, not additive.

### Files AI Must Never Use as Context

- Build artifacts: `*.dcu`, `*.exe`, `*.dll`, `*.bpl`, `*.dcp`, `*.map`, `*.res`
- IDE temporaries: `*.local`, `*.identcache`, `*.stat`, `__history/`, `__recovery/`, `.serena/`
- Output directories: `Win32/`, `Win64/`, `Debug/`, `Release/`, `build/`, `dist/`
- Secrets: `*.key`, `*.pfx`, `*.p12`, `.env`, `.env.*`
- Noise: `*.log`, `*.dmp`, `*.bak`, `*.tmp`

See `.cursorignore`, `.gitignore` and `.vscode/settings.json` for the enforced patterns.
