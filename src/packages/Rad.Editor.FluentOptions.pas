unit Rad.Editor.FluentOptions;

{ The question RadMenu asks before writing a Fluent unit. The layout is in the
  DFM; only the class list is filled from the selection. No IDE units here. }

interface

uses
  System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  rad.utils;

type
  TRadFluentOptionsForm = class(TForm)
    lblClasses: TLabel;
    lstClasses: TListBox;
    chkInherited: TCheckBox;
    btnOk: TButton;
    btnCancel: TButton;
  public
    /// <summary>Lists the classes with their member counts.</summary>
    procedure Prepare(const AClasses: array of TClass);
    /// <summary>The generator options the form currently stands for.</summary>
    function Options: TFluentGenOptions;
  public
    /// <summary>Asks how the unit should be generated; False if the user cancelled.</summary>
    class function Ask(const AClasses: array of TClass; out AOptions: TFluentGenOptions): Boolean; static;
  end;



implementation

uses
  System.SysUtils,
  Rad.Editor.Tools;

{$R *.dfm}

class function TRadFluentOptionsForm.Ask(const AClasses: array of TClass; out AOptions: TFluentGenOptions): Boolean;
var
  LForm: TRadFluentOptionsForm;
begin
  LForm := TRadFluentOptionsForm.Create(nil);
  try
    LForm.Prepare(AClasses);
    Result := LForm.ShowModal = mrOk;
    AOptions := LForm.Options;
  finally
    LForm.Free;
  end;
end;

{ TRadFluentOptionsForm }

procedure TRadFluentOptionsForm.Prepare(const AClasses: array of TClass);
var
  LClass: TClass;
begin
  lstClasses.Items.Clear;
  for LClass in AClasses do
    lstClasses.Items.Add(Format(SRadFluentClassCounts,
      [LClass.ClassName, TRadFluent.CountMembers(LClass, False), TRadFluent.CountMembers(LClass, True)]));
end;

function TRadFluentOptionsForm.Options: TFluentGenOptions;
begin
  Result := CFluentUnitDefaultOptions;
  if chkInherited.Checked then
    Include(Result, fgoIncludeInherited);
end;

end.
