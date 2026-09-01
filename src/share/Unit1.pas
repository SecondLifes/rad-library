unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, k.setting, Vcl.ExtCtrls, cxEdit, cxEditRepositoryItems, cxClasses;

type
  TForm1 = class(TForm)
    Panel1: TPanel;
    FPanel: TfrmSetting;
    cxEditRepository1: TcxEditRepository;
    riDepo: TcxEditRepositoryComboBoxItem;
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;



  TSatisAyar = class(TRadSetting)
  published
    property Vade         : Integer index 0 read GetI write SetI default 30;
    property KdvDahil     : Boolean index 1 read GetB write SetB default False;
    property Depo         : string  index 2 read GetS write SetS;
    property VadeAsimUyar : Boolean index 3 read GetB write SetB default True;
  end;

  TAlisAyar = class(TRadSetting)
  published
    property IskontoOrani : Double  index 0 read GetF write SetF;
    property OtomatikOnay : Boolean index 1 read GetB write SetB default False;
  end;


  TFaturaAyar = class(TRadSetting)
  private
    FAlis  : TAlisAyar;
    FSatis : TSatisAyar;
  published
    property Alis  : TAlisAyar  read FAlis;
    property Satis : TSatisAyar read FSatis;
  end;

  TGenelAyar = class(TRadSetting)
published
  property SirketKodu     : string  index 0 read GetS write SetS;
  property SirketAdi      : string  index 1 read GetS write SetS;
  property ParaBirimi     : string  index 2 read GetS write SetS;
  property OndalikBasamak : Integer index 3 read GetI write SetI default 2;
end;


var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
begin


FPanel
  .AddMenu('Fatura')                              // NavBar GRUBU
    .AddSubMenu('Satis')                          // NavBar OGESI
      .Register(TSatisAyar)
        .Title('Vade',         'Vade (gun)', 'Musteriye taninan odeme suresi')
        .Title('KdvDahil',     'KDV dahil')
        .Title('VadeAsimUyar', 'Vade asiminda uyar')
        .Repository('Depo', riDepo)            // DevExpress lookup
    .AddSubMenu('Alis')
      .Register(TAlisAyar)
        .Title('IskontoOrani', 'Iskonto %')
  .AddMenu('Genel')
    .Register(TGenelAyar)
      .Choices('ParaBirimi', ['TL', 'USD', 'EUR'])
      .ReadOnly('SirketKodu');

//FPanel.LoadJson(DbdenAyarJsonuOku);
end;

end.
