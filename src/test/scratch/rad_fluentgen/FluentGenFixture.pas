unit FluentGenFixture;

{ GenerateFluentUnit'in kaynak tarayicisini ve uretecini yanilttigi olculen
  kaliplar. Sinif sirasi onemli: ileri bildirimin ardindaki sinif tuzagin parcasi. }

interface

uses
  System.SysUtils,
  {$IFDEF POSIX} Posix.Unistd, {$ENDIF}
  System.Classes;

type
  TBlind = (b1 = 10, b2 = 20);

  TFwd = class;

  TOther = class
  private
    FOther: Integer;
  public
    property OtherProp: Integer read FOther write FOther;
  end;

  TFwd = class
  private
    FX: Integer;
  public
    property X: Integer read FX write FX;
  end;

  TOneLiner = class(TFwd);

  TAfterOneLiner = class
  private
    FAfter: Integer;
  public
    property AfterProp: Integer read FAfter write FAfter;
  end;

  TOver = class
  public
    procedure Foo(A: Integer); overload;
    procedure Foo; overload;
    function Bar: Integer;
  end;

  TOverBlind = class
  public
    procedure Foo(A: TBlind); overload;
    procedure Foo; overload;
  end;

  TWord = class
  private
    FType: Integer;
  public
    procedure Run(const &Type: string);
    procedure &End;
    property &Type: Integer read FType write FType;
  end;

  TGen<T> = class
  public
    procedure Put(const A: T);
  end;

  TOuter = class
  public type
    TInner = class
    public
      procedure Go;
    end;
  end;

  THidden = class
  private type
    TSecret = class
    private
      FSecret: Integer;
    public
      property SecretProp: Integer read FSecret write FSecret;
    end;
  public
    function Visible: Integer;
  end;

  TNested = class
  private
    FTail: Integer;
  public type
    TPart = record
    public
      Value: Integer;
    end;
  public
    function Part: TPart;
    property Tail: Integer read FTail write FTail;
  end;

  TCond = class
  private
    FValue: Integer;
  public
  {$IF Defined(MSWINDOWS)}
    property WinProp: Integer read FValue write FValue;
  {$ELSEIF Defined(POSIX)}
    property PosixProp: Integer read FValue write FValue;
  {$ELSE}
    property OtherOsProp: Integer read FValue write FValue;
  {$ENDIF POSIX}
  {$IF DEFINED(CLR)}
    property ClrProp: Integer read FValue write FValue;
  {$ENDIF}
    property LastProp: Integer read FValue write FValue;
  end;

  TLevelBase = class(TComponent)
  private
    FShared: Integer;
  public
    procedure Run; virtual;
    procedure Over(A: Integer); overload;
    procedure Over(const A: string); overload;
    function BaseOnly: Integer;
    function HiddenByProp(A: Integer): Integer;
    property Shared: Integer read FShared write FShared;
    property BaseProp: Integer read FShared write FShared;
    property HiddenByMethod: Integer read FShared write FShared;
  end;

  TLevelMid = class(TLevelBase)
  public
    procedure Run; override;
    procedure Over(A: Double);
    function HiddenByMethod(A: Integer): Integer;
    property Shared;
    property HiddenByProp: Integer read FShared write FShared;
  end;

  TIdx = class
  private
    function GetItem(AIndex: Integer): string;
    procedure SetItem(AIndex: Integer; const AValue: string);
  public
    property Items[AIndex: Integer]: string read GetItem write SetItem;
  end;

  TUsesBlind = class
  private
    FB: TBlind;
  public
    property B: TBlind read FB write FB;
  end;

  TClash = class
  private
    FName: string;
  public
    function GetName: Integer;
    property Name: string read FName write FName;
  end;

  TFactoryClash = class
  public
    function AsInstance: Integer;
    function New: Integer;
  end;

implementation

procedure TOver.Foo(A: Integer); begin end;
procedure TOver.Foo; begin end;
function TOver.Bar: Integer; begin Result := 1; end;
procedure TOverBlind.Foo(A: TBlind); begin end;
procedure TOverBlind.Foo; begin end;
procedure TWord.Run(const &Type: string); begin end;
procedure TWord.&End; begin end;
procedure TGen<T>.Put(const A: T); begin end;
procedure TOuter.TInner.Go; begin end;
function THidden.Visible: Integer; begin Result := 0; end;
function TNested.Part: TPart; begin Result := Default(TPart); end;
procedure TLevelBase.Run; begin end;
procedure TLevelBase.Over(A: Integer); begin end;
procedure TLevelBase.Over(const A: string); begin end;
function TLevelBase.BaseOnly: Integer; begin Result := 0; end;
procedure TLevelMid.Run; begin end;
procedure TLevelMid.Over(A: Double); begin end;
function TLevelBase.HiddenByProp(A: Integer): Integer; begin Result := A; end;
function TLevelMid.HiddenByMethod(A: Integer): Integer; begin Result := A; end;
function TIdx.GetItem(AIndex: Integer): string; begin Result := ''; end;
procedure TIdx.SetItem(AIndex: Integer; const AValue: string); begin end;
function TClash.GetName: Integer; begin Result := 0; end;
function TFactoryClash.AsInstance: Integer; begin Result := 0; end;
function TFactoryClash.New: Integer; begin Result := 0; end;

end.
