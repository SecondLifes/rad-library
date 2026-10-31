unit FormTabsDfmMdi;

{ DFM'den yuklenen MDI cocuk: Create ile yaratilir, CreateNew cagrilmaz. }

interface

uses
  Vcl.Forms, Help.vcl;

type
  TDfmMdi = class(TRadFormBase)
  end;

implementation

{$R *.dfm}

end.
