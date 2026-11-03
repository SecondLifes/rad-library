unit FormStateTestDm;

{ Test data module: a store saving a timer interval. }

interface

uses
  System.SysUtils, System.Classes, Vcl.ExtCtrls,
  rad.formstate.component;

type
  TDmA = class(TDataModule)
    Timer1: TTimer;
    Store1: TRadPropertiesStore;
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
  public
    CreateCalls, DestroyCalls: Integer;
  end;

implementation

{$R *.dfm}

procedure TDmA.DataModuleCreate(Sender: TObject);
begin
  Inc(CreateCalls);
end;

procedure TDmA.DataModuleDestroy(Sender: TObject);
begin
  Inc(DestroyCalls);
end;

end.
