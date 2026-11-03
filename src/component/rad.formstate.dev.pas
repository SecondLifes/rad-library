unit rad.formstate.dev;

{ DevExpress providers of the form-state system (docs/specs/rad.formcustomizer.md): every named
  grid view and layout control of a form keeps the user's layout. Register them once:
  TRadFormState.RegisterProvider(TRadGridStateProvider.Create). }

interface

uses
  System.SysUtils,
  System.Classes,
  mormot.core.base,
  mormot.core.variants,
  rad.formstate.core;

type
  /// <summary>Saves each named component of one kind as a base64 stream under its name.</summary>
  /// <remarks>Design bound: the store drops the section once the designed component changes.</remarks>
  TRadStreamStateProvider = class abstract(TInterfacedObject, IRadStateProvider, IRadStateDesignBound)
  protected
    function Matches(AComponent: TComponent): Boolean; virtual; abstract;
    procedure StoreTo(AComponent: TComponent; AStream: TStream); virtual; abstract;
    procedure RestoreFrom(AComponent: TComponent; AStream: TStream); virtual; abstract;
  public
    function Name: RawUtf8; virtual; abstract;
    function Version: Integer; virtual;
    function Wants(AOwner: TComponent): Boolean;
    procedure Save(AOwner: TComponent; const ADoc: IDocDict);
    procedure Load(AOwner: TComponent; const ADoc: IDocDict);
  end;

  /// <summary>Column order, width, visibility, sorting and grouping of every named grid view.</summary>
  /// <remarks>Filter, summary and data state are not kept; restoring never creates or deletes columns.</remarks>
  TRadGridStateProvider = class(TRadStreamStateProvider)
  protected
    function Matches(AComponent: TComponent): Boolean; override;
    procedure StoreTo(AComponent: TComponent; AStream: TStream); override;
    procedure RestoreFrom(AComponent: TComponent; AStream: TStream); override;
  public
    function Name: RawUtf8; override;
  end;

  /// <summary>Arrangement of every named layout control, as the user left it in its own customization mode.</summary>
  TRadLayoutStateProvider = class(TRadStreamStateProvider)
  protected
    function Matches(AComponent: TComponent): Boolean; override;
    procedure StoreTo(AComponent: TComponent; AStream: TStream); override;
    procedure RestoreFrom(AComponent: TComponent; AStream: TStream); override;
  public
    function Name: RawUtf8; override;
  end;

implementation

uses
  mormot.core.buffers,
  mormot.core.unicode,
  cxGridCustomView,
  dxLayoutControl;

const
  PROVIDER_VERSION = 1;

{ TRadStreamStateProvider }

function TRadStreamStateProvider.Version: Integer;
begin
  Result := PROVIDER_VERSION;
end;

function TRadStreamStateProvider.Wants(AOwner: TComponent): Boolean;
var
  I: Integer;
begin
  for I := 0 to AOwner.ComponentCount - 1 do
    if (AOwner.Components[I].Name <> '') and Matches(AOwner.Components[I]) then
      Exit(True);
  Result := False;
end;

procedure TRadStreamStateProvider.Save(AOwner: TComponent; const ADoc: IDocDict);
var
  I: Integer;
  LComponent: TComponent;
  LStream: TMemoryStream;
  LData: RawByteString;
begin
  for I := 0 to AOwner.ComponentCount - 1 do
  begin
    LComponent := AOwner.Components[I];
    if (LComponent.Name = '') or not Matches(LComponent) then
      Continue;
    LStream := TMemoryStream.Create;
    try
      StoreTo(LComponent, LStream);
      SetString(LData, PAnsiChar(LStream.Memory), LStream.Size);
    finally
      LStream.Free;
    end;
    ADoc.U[StringToUtf8(LComponent.Name)] := BinToBase64(LData);
  end;
end;

procedure TRadStreamStateProvider.Load(AOwner: TComponent; const ADoc: IDocDict);
var
  I: Integer;
  LComponent: TComponent;
  LText: RawUtf8;
  LData: RawByteString;
  LStream: TMemoryStream;
begin
  for I := 0 to AOwner.ComponentCount - 1 do
  begin
    LComponent := AOwner.Components[I];
    if (LComponent.Name = '') or not Matches(LComponent) or
      not ADoc.Get(StringToUtf8(LComponent.Name), LText) then
      Continue;
    LData := Base64ToBin(LText);
    if LData = '' then
      Continue;
    LStream := TMemoryStream.Create;
    try
      LStream.WriteBuffer(pointer(LData)^, Length(LData));
      LStream.Position := 0;
      RestoreFrom(LComponent, LStream);
    finally
      LStream.Free;
    end;
  end;
end;

{ TRadGridStateProvider }

function TRadGridStateProvider.Name: RawUtf8;
begin
  Result := 'cxgrid';
end;

function TRadGridStateProvider.Matches(AComponent: TComponent): Boolean;
begin
  Result := AComponent is TcxCustomGridView;
end;

procedure TRadGridStateProvider.StoreTo(AComponent: TComponent; AStream: TStream);
begin
  TcxCustomGridView(AComponent).StoreToStream(AStream, []);
end;

procedure TRadGridStateProvider.RestoreFrom(AComponent: TComponent; AStream: TStream);
begin
  // Default AChildrenCreating = True would create saved columns the form no longer has.
  TcxCustomGridView(AComponent).RestoreFromStream(AStream, False, False, []);
end;

{ TRadLayoutStateProvider }

function TRadLayoutStateProvider.Name: RawUtf8;
begin
  Result := 'dxlayout';
end;

function TRadLayoutStateProvider.Matches(AComponent: TComponent): Boolean;
begin
  Result := AComponent is TdxCustomLayoutControl;
end;

procedure TRadLayoutStateProvider.StoreTo(AComponent: TComponent; AStream: TStream);
begin
  TdxCustomLayoutControl(AComponent).SaveToStream(AStream);
end;

procedure TRadLayoutStateProvider.RestoreFrom(AComponent: TComponent; AStream: TStream);
begin
  TdxCustomLayoutControl(AComponent).LoadFromStream(AStream);
end;

end.
