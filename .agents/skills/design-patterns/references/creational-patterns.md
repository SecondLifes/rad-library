## 🏗️ Creational Patterns

### Singleton — Global Configuration

```pascal
unit MeuApp.Infra.AppConfig;

interface

type
  TAppConfig = class
  private
    class var FInstance: TAppConfig;
    FDatabaseUrl: string;
    FApiKey: string;
    constructor Create;
  public
    class function GetInstance: TAppConfig;
    class procedure ReleaseInstance;
    property DatabaseUrl: string read FDatabaseUrl write FDatabaseUrl;
    property ApiKey: string read FApiKey write FApiKey;
  end;

implementation

constructor TAppConfig.Create;
begin
  inherited Create;
  FDatabaseUrl := 'localhost:5432/myapp';
end;

class function TAppConfig.GetInstance: TAppConfig;
begin
  if not Assigned(FInstance) then
    FInstance := TAppConfig.Create;
  Result := FInstance;
end;

class procedure TAppConfig.ReleaseInstance;
begin
  FreeAndNil(FInstance);
end;

initialization
finalization
  TAppConfig.ReleaseInstance;
end.
```

> ⚠️ For multi-threaded environments (e.g. concurrent request handlers or parallel tasks), guard the lazy creation in `GetInstance` with a `TCriticalSection` (or double-checked locking) — the version above is **not** thread-safe.

### Factory Method — Creation with Polymorphism

```pascal
unit MeuApp.Domain.Report.Factory;

interface

uses
  MeuApp.Domain.Report.Intf;

type
  IReportExporter = interface
    ['{51D3D294-51A7-4E29-A5C2-F5B47F04B44A}']
    procedure Export(const AData: TReportData; const AFilePath: string);
  end;

  //Factory method — each subclass decides which exporter to create
  TReportExporterFactory = class abstract
  public
    function CreateExporter: IReportExporter; virtual; abstract;
    //Template Method usando Factory Method
    procedure ExportReport(const AData: TReportData; const AFilePath: string);
  end;

  TPdfReportFactory = class(TReportExporterFactory)
    function CreateExporter: IReportExporter; override;
  end;

  TExcelReportFactory = class(TReportExporterFactory)
    function CreateExporter: IReportExporter; override;
  end;

implementation

procedure TReportExporterFactory.ExportReport(const AData: TReportData; const AFilePath: string);
var
  LExporter: IReportExporter;
begin
  LExporter := CreateExporter;
  LExporter.Export(AData, AFilePath);
end;
```

### Abstract Factory — Family of Related Objects

```pascal
unit MeuApp.Infra.UI.Factory;

interface

type
  IButton = interface ['{...}'] procedure Render; end;
  IInputField = interface ['{...}'] procedure Render; end;
  IDialog = interface ['{...}'] procedure Show(const AMsg: string); end;

  //Abstract Factory
  IUIComponentFactory = interface
    ['{B2C3-...}']
    function CreateButton(const ACaption: string): IButton;
    function CreateInputField(const APlaceholder: string): IInputField;
    function CreateDialog: IDialog;
  end;

  TVCLComponentFactory = class(TInterfacedObject, IUIComponentFactory)
    function CreateButton(const ACaption: string): IButton;
    function CreateInputField(const APlaceholder: string): IInputField;
    function CreateDialog: IDialog;
  end;

  TFMXComponentFactory = class(TInterfacedObject, IUIComponentFactory)
    function CreateButton(const ACaption: string): IButton;
    function CreateInputField(const APlaceholder: string): IInputField;
    function CreateDialog: IDialog;
  end;
```

### Builder — Step by Step Construction

```pascal
unit MeuApp.Infra.Query.Builder;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type
  ///<summary>
  ///Builder for fluent construction of parameterized SQL queries.
  ///</summary>
  TQueryBuilder = class
  private
    FSelect: string;
    FFrom: string;
    FWheres: TStringList;
    FOrderBy: string;
    FLimit: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    function Select(const AFields: string): TQueryBuilder;
    function From(const ATable: string): TQueryBuilder;
    function Where(const ACondition: string): TQueryBuilder;
    function OrderBy(const AField: string; ADesc: Boolean = False): TQueryBuilder;
    function Limit(ACount: Integer): TQueryBuilder;
    function Build: string;
  end;

implementation

constructor TQueryBuilder.Create;
begin
  inherited Create;
  FWheres := TStringList.Create;
  FLimit := 0;
end;

destructor TQueryBuilder.Destroy;
begin
  FWheres.Free;
  inherited Destroy;
end;

function TQueryBuilder.Select(const AFields: string): TQueryBuilder;
begin
  FSelect := AFields;
  Result := Self;
end;

function TQueryBuilder.From(const ATable: string): TQueryBuilder;
begin
  FFrom := ATable;
  Result := Self;
end;

function TQueryBuilder.Where(const ACondition: string): TQueryBuilder;
begin
  FWheres.Add(ACondition);
  Result := Self;
end;

function TQueryBuilder.OrderBy(const AField: string; ADesc: Boolean): TQueryBuilder;
begin
  FOrderBy := AField;
  if ADesc then FOrderBy := FOrderBy + ' DESC';
  Result := Self;
end;

function TQueryBuilder.Limit(ACount: Integer): TQueryBuilder;
begin
  FLimit := ACount;
  Result := Self;
end;

function TQueryBuilder.Build: string;
var
  LSql: TStringBuilder;
begin
  LSql := TStringBuilder.Create;
  try
    LSql.Append('SELECT ').Append(FSelect);
    LSql.Append(' FROM ').Append(FFrom);
    if FWheres.Count > 0 then
      LSql.Append(' WHERE ').Append(String.Join(' AND ', FWheres.ToStringArray));
    if not FOrderBy.IsEmpty then
      LSql.Append(' ORDER BY ').Append(FOrderBy);
    if FLimit > 0 then
      LSql.Append(' LIMIT ').Append(FLimit.ToString);
    Result := LSql.ToString;
  finally
    LSql.Free;
  end;
end;
```
