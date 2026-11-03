unit Rad.Editor.Tools;

{ IDE-free part of the RadMenu design-time tools: menu ownership and the
  selection-to-Fluent logic. Rad.Editor wires these to the Open Tools API;
  keeping the IDE units out of here is what makes this testable from a console. }

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.Win.Registry,
  Winapi.Windows, Vcl.Menus,
  rad.utils;

resourcestring
  SRadMenuCaption = 'RadMenü';
  SRadFluentCaption = 'Seçili Komponenti Fluent''e Çevir';
  SRadFluentNoDesigner = 'Açık bir form tasarımcısı yok. Önce formu tasarım görünümünde açın.';
  SRadFluentNothing = 'Çevrilecek bileşen seçili değil. Form veya frame kökü çevrilemez: sınıfı IDE''ye yüklü değil.';
  SRadFluentSkipped = 'Atlandı (sınıfı IDE''ye yüklü değil): %s';
  SRadFluentSaveTitle = 'Fluent birimi (dosya varsa içine eklenir)';
  SRadFluentSaveFilter = 'Delphi birimi (*.pas)|*.pas';
  SRadFluentClassCounts = '%s: %d üye, kalıtılanlarla %d üye';

type
  /// <summary>Owns the RadMenu items; freeing it removes them from the host menu.</summary>
  /// <remarks>The host may destroy the root first (IDE shutdown) or take over its ownership;
  /// both are safe, and freeing this object still removes the items.</remarks>
  TRadToolMenu = class(TComponent)
  strict private
    FRoot: TMenuItem;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Adds one tool under the root.</summary>
    function AddTool(const ACaption: string; AOnClick: TNotifyEvent): TMenuItem;
    /// <summary>The top-level item; nil once the host has destroyed it.</summary>
    property Root: TMenuItem read FRoot;
  end;

  /// <summary>What a designer selection turns into.</summary>
  TRadFluentSelection = record
    /// <summary>Distinct classes, in selection order.</summary>
    Classes: TArray<TClass>;
    /// <summary>Names of the selected objects that cannot be wrapped.</summary>
    Skipped: TArray<string>;
  end;

type
  /// <summary>Selection and output handling of the Fluent tool.</summary>
  TRadFluentDesign = class abstract
  public
    /// <summary>Splits a selection into wrappable classes and skipped objects.</summary>
    class function Selection(const AItems: array of TPersistent; ARoot: TComponent): TRadFluentSelection; static;
    /// <summary>Suggested file name: TButton gives Button.Fluent.pas.</summary>
    class function DefaultFileName(AClass: TClass): string; static;
    /// <summary>First AUnitName.pas in a semicolon-separated path list, or an empty string.</summary>
    class function FindSource(const AUnitName, ASearchPath: string): string; static;
    /// <summary>The IDE's browsing and search paths, macros unexpanded.</summary>
    class function LibraryPath(const ABaseRegKey: string): string; static;
    /// <summary>Writes or merges every class into one unit at AOutputPath.</summary>
    class procedure WriteUnit(const AClasses: array of TClass; const AOutputPath, ASearchPath: string;
    AOptions: TFluentGenOptions = CFluentUnitDefaultOptions); static;
  end;











implementation

const
  CMenuName = 'RadMenu';
  CFluentFileSuffix = '.Fluent.pas';
  CPathSeparator = ';';
  // Sources are the same for every platform, so one key serves both IDE bitnesses.
  CLibraryKey = '\Library\Win32';
  CBrowsingPathValue = 'Browsing Path';
  CSearchPathValue = 'Search Path';

{ TRadToolMenu }

constructor TRadToolMenu.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FRoot := TMenuItem.Create(Self);
  FRoot.Name := CMenuName;
  FRoot.Caption := SRadMenuCaption;
  FRoot.FreeNotification(Self);
end;

destructor TRadToolMenu.Destroy;
var
  LRoot: TMenuItem;
begin
  LRoot := FRoot;
  FRoot := nil;
  LRoot.Free;
  inherited Destroy;
end;

function TRadToolMenu.AddTool(const ACaption: string; AOnClick: TNotifyEvent): TMenuItem;
begin
  Result := TMenuItem.Create(Self);
  Result.Caption := ACaption;
  Result.OnClick := AOnClick;
  FRoot.Add(Result);
end;

procedure TRadToolMenu.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  // opRemove also fires when the owner changes, and inherited then drops the free
  // notification; only a real destruction ends the root.
  if (Operation = opRemove) and (AComponent = FRoot) then
    if csDestroying in AComponent.ComponentState then
      FRoot := nil
    else
      FRoot.FreeNotification(Self);
end;

{ Selection }

function DisplayName(AItem: TPersistent): string;
begin
  if (AItem is TComponent) and (TComponent(AItem).Name <> '') then
    Result := TComponent(AItem).Name
  else
    Result := AItem.ClassName;
end;

function IsDesignedClass(AItem: TPersistent; ARoot: TComponent): Boolean;
begin
  // The root and embedded frames are classes under design: their code is not loaded in the IDE.
  Result := (AItem = ARoot) or
    ((AItem is TComponent) and (csInline in TComponent(AItem).ComponentState));
end;

class function TRadFluentDesign.Selection(const AItems: array of TPersistent; ARoot: TComponent): TRadFluentSelection;
var
  LClasses: TList<TClass>;
  LSkipped: TList<string>;
  LItem: TPersistent;
begin
  LClasses := TList<TClass>.Create;
  try
    LSkipped := TList<string>.Create;
    try
      for LItem in AItems do
        if IsDesignedClass(LItem, ARoot) then
          LSkipped.Add(DisplayName(LItem))
        else if not LClasses.Contains(LItem.ClassType) then
          LClasses.Add(LItem.ClassType);
      Result.Classes := LClasses.ToArray;
      Result.Skipped := LSkipped.ToArray;
    finally
      LSkipped.Free;
    end;
  finally
    LClasses.Free;
  end;
end;

class function TRadFluentDesign.DefaultFileName(AClass: TClass): string;
var
  LGeneric: Integer;
begin
  Result := AClass.ClassName;
  LGeneric := Pos('<', Result);
  if LGeneric > 0 then
    Result := Copy(Result, 1, LGeneric - 1);
  if (Length(Result) > 1) and (Result[1] = 'T') then
    Delete(Result, 1, 1);
  Result := Result + CFluentFileSuffix;
end;

class function TRadFluentDesign.FindSource(const AUnitName, ASearchPath: string): string;
var
  LDir: string;
begin
  for LDir in ASearchPath.Split([CPathSeparator], TStringSplitOptions.ExcludeEmpty) do
  begin
    Result := IncludeTrailingPathDelimiter(LDir.Trim) + AUnitName + '.pas';
    if FileExists(Result) then
      Exit;
  end;
  Result := '';
end;

class function TRadFluentDesign.LibraryPath(const ABaseRegKey: string): string;
var
  LRegistry: TRegistry;
begin
  Result := '';
  LRegistry := TRegistry.Create(KEY_READ);
  try
    if LRegistry.OpenKeyReadOnly(ABaseRegKey + CLibraryKey) then
      Result := LRegistry.ReadString(CBrowsingPathValue) + CPathSeparator +
        LRegistry.ReadString(CSearchPathValue);
  finally
    LRegistry.Free;
  end;
end;

class procedure TRadFluentDesign.WriteUnit(const AClasses: array of TClass; const AOutputPath, ASearchPath: string;
  AOptions: TFluentGenOptions);
var
  LClass: TClass;
begin
  // fumMergeRegions creates a missing file too, so one selection can share a unit.
  for LClass in AClasses do
    TRadFluent.GenerateUnit(LClass, AOutputPath, TRadFluentDesign.FindSource(LClass.UnitName, ASearchPath),
      AOptions, fumMergeRegions);
end;

end.
