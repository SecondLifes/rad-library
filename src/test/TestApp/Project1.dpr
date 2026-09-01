program Project1;

uses
  Vcl.Forms,
  Unit1 in 'Unit1.pas' {Form1},
  rad.utils in '..\..\core\rad.utils.pas',
  rad.cache in '..\..\core\rad.cache.pas',
  rad.json in '..\..\core\rad.json.pas',
  rad.core in '..\..\core\rad.core.pas',
  rad in '..\..\core\rad.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
