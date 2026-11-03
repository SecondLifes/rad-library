unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  rad.cache,
  mormot.core.json,mormot.core.variants,
  MiscObj, CryptBase, AESObj,CryptoConst, SPECKObj, SalsaObj;

type

 TDenemeRec = record
  Ad:string;
  Soyad:string;
  yas:Integer;
 end;

 TRadOptions = class(TSynAutoCreateFields)
  private
    FSectionName: string;
    FEncrypted: Boolean;
    FServerIP: string;
    FPort: Integer;
    FUserName: string;
    FPassport: string;
    FBeniHatirla: Boolean;
    FAutoLogin: Boolean;
    FDeneme: TDenemeRec;
    FArgInt: TArray<Integer>;

    FArgStr: TArray<string>;  public
    //procedure DefaultValues; virtual;
    //procedure Validate; virtual;
    Deneme: TDenemeRec;
    property Encrypted: Boolean read FEncrypted write FEncrypted;
    property SectionName: string read FSectionName write FSectionName;
  published
   property ServerIP: string read FServerIP write FServerIP;
   property Port: Integer read FPort write FPort;
   property UserName: string read FUserName write FUserName;
   property Passport: string read FPassport write FPassport;
   property BeniHatirla: Boolean read FBeniHatirla write FBeniHatirla;
   property AutoLogin: Boolean read FAutoLogin write FAutoLogin;
   property DenemeRec: TDenemeRec read FDeneme write FDeneme;
   property ArgStr:TArray<string> read FArgStr write FArgStr;
   property ArgInt: TArray<Integer> read FArgInt write FArgInt;
  end;



  TForm1 = class(TForm)
    Panel1: TPanel;
    Memo1: TMemo;
    Button1: TButton;
    AES: TAESEncryption;
    Conv: TConvert;
    Salsa: TSalsaEncryption;
    SPECK: TSPECKEncryption;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    Config : TRadConfig;
    RadOptions:TRadOptions;
  end;




var
  Form1: TForm1;

implementation
 uses
 System.IOUtils,
 mormot.core.text
 ,rad , rad.utils, rad.AESObj, rad.json

 ;
{$R *.dfm}


procedure _Add(const Format: string; const Args: array of const); overload;
begin
 Form1.Memo1.Lines.Add(FormatUtf8(Format,Args));
end;

procedure _Add(const Format: string); overload;
begin
 Form1.Memo1.Lines.Add(Format);
end;



procedure TForm1.Button1Click(Sender: TObject);
var
s:string;

begin
 Memo1.Lines.Clear;
    //s:= rad.json.NewJson('').SetStr('Adý','Emrah').SetStr('soyad','BAÞPINAR').SetInt('phone',5555575595).ToJson;
{
SetLength(TRadApp.Config.Connection.FArgStr,2);
SetLength(TRadApp.Config.Connection.FArgInt,2);

TRadApp.Config.Connection.ArgStr[0]:='String 1';
TRadApp.Config.Connection.ArgStr[1]:='String 2';
TRadApp.Config.Connection.ArgInt[0]:=9;
TRadApp.Config.Connection.ArgInt[1]:=99;

TRadApp.Config.Connection.ServerIP:='192.168.1.11';
TRadApp.Config.Connection.Port:=1452;
TRadApp.Config.Connection.UserName :='emrah';
TRadApp.Config.Connection.Passport:='02450350';
TRadApp.Config.Connection.BeniHatirla:=True;
TRadApp.Config.Connection.FDeneme.Ad:='Þenay';
TRadApp.Config.Connection.FDeneme.Soyad:='BAÞPINAR';
TRadApp.Config.Connection.FDeneme.yas:=48;
}
TRadApp.Config.AddOrSet('emr.string','Emrah BAÞPINAR');
TRadApp.Config.AddOrSet('emr.int',14725);
TRadApp.Config.AddOrSet('float',12.99);
TRadApp.Config.AddOrSet('DateTime',Now);
TRadApp.Config.AddOrSet('Date',Date);
TRadApp.Config.AddOrSet('Time',Time);
TRadApp.Config.SaveToFile('E:\system\dev\AI\AI-Spec-Kits-Maker\spec-kits\rad-library\src\core\asd.json');
TRadApp.Config.SaveToFile('E:\system\dev\AI\AI-Spec-Kits-Maker\spec-kits\rad-library\src\core\asd.yml');
TRadApp.Config.SaveToFile('E:\system\dev\AI\AI-Spec-Kits-Maker\spec-kits\rad-library\src\core\asd.xml');
 exit;
 _Add(TPath.GetAppPath);
 _Add(TPath.GetLibraryPath);
 _Add(TPath.GetHomePath);
 _Add(TPath.GetCachePath);

 _add('-----------------------------');

 _Add(rad.TUtils.Folders.sistem.LocalAppData);
 _Add(rad.TUtils.Folders.sistem.AppdataFolder);
 _Add(rad.TUtils.Folders.sistem.CommonFilesFolder);

exit;
{
GenerateFluentUnit(TConvert,'E:\system\dev\AI\AI-Spec-Kits-Maker\spec-kits\rad-library\src\core\rad.AESObj.pas','E:\system\dev\Delphi\component\TMS\tms.vcl.Cryptography\MiscObj.pas',
CFluentGenDefaultOptions,fumMergeRegions
);
GenerateFluentUnit(TAESEncryption,'E:\system\dev\AI\AI-Spec-Kits-Maker\spec-kits\rad-library\src\core\rad.AESObj.pas','E:\system\dev\Delphi\component\TMS\tms.vcl.Cryptography\AESObj.pas',
CFluentGenDefaultOptions,fumMergeRegions
);

GenerateFluentUnit(TSalsaEncryption,'E:\system\dev\AI\AI-Spec-Kits-Maker\spec-kits\rad-library\src\core\rad.AESObj.pas','E:\system\dev\Delphi\component\TMS\tms.vcl.Cryptography\SalsaObj.pas',
CFluentGenDefaultOptions,fumMergeRegions
);

GenerateFluentUnit(TSPECKEncryption,'E:\system\dev\AI\AI-Spec-Kits-Maker\spec-kits\rad-library\src\core\rad.AESObj.pas','E:\system\dev\Delphi\component\TMS\tms.vcl.Cryptography\SPECKObj.pas',
CFluentGenDefaultOptions,fumMergeRegions
);
 }
exit;
 //  var AES:=TAESEncryptionFluent.Create(TAESEncryption.Create(nil),True);
 //  Memo1.Lines.Text := AES.SetAType(atECB).SetOutputFormat(base64url).SetKeyLength(kl128).SetKey('8l6x0rszJkcUviIX4BR-Hg==').Encrypt('Emrah BAÞPINAR')
 // Memo1.Lines.Text:=GenerateFluentCode(TAESEncryption);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Config:=TRadConfig.Create();
  TRadApp.Config.AddOrSet('Connection',TRadOptions.Create());

  Button1Click(nil);
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  TRadApp.Config.Free;
end;



end.
