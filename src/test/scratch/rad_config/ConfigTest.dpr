program ConfigTest;

{$APPTYPE CONSOLE}

{ TRadConfig sondasi: Get overload'lari, alt nesne omru, kayit/yukleme, bozuk dosya. }

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  rad.core   in '..\..\..\core\rad.core.pas',
  rad.config in '..\..\..\core\rad.config.pas';

type
  TDepoOptions = class(TRadOptions)
  private
    FDepoAdi: string;
  public
    class var Made, Freed: Integer;
    constructor Create; override;
    destructor Destroy; override;
  published
    property DepoAdi: string read FDepoAdi write FDepoAdi;
  end;

  TConfigGenel = class(TRadConfig)
  private
    FDepo: TDepoOptions;
  published
    property Depo: TDepoOptions read FDepo write FDepo;
  end;

var
  GOk, GFail: Integer;
  GFile: string;

constructor TDepoOptions.Create;
begin
  inherited;
  Inc(Made);
end;

destructor TDepoOptions.Destroy;
begin
  Inc(Freed);
  inherited;
end;

procedure Chk(ADogru: Boolean; const AMesaj: string);
begin
  if ADogru then
  begin
    Inc(GOk);
    Writeln('  [GECTI] ', AMesaj);
  end
  else
  begin
    Inc(GFail);
    Writeln('  [KALDI] ', AMesaj);
  end;
end;

procedure DosyaSil;
begin
  if TFile.Exists(GFile) then
    TFile.Delete(GFile);
end;

procedure GetOverloadlari;
var
  LAyar: TConfigGenel;
begin
  Writeln;
  Writeln('=== Get overload''lari ===');
  DosyaSil;
  LAyar := TConfigGenel.Create;
  try
    Chk(LAyar.Get('yok', 'x') = 'x', '01 string varsayilani');
    Chk(LAyar.Get('yok', 5) = 5, '02 Integer literali belirsiz degil');
    Chk(LAyar.Get('yok', Int64(7)) = 7, '03 Int64');
    Chk(LAyar.Get('yok', True), '04 Boolean');
    Chk(LAyar.Get('yok', 1.5) = 1.5, '05 Double literali belirsiz degil');
    Chk(LAyar.GetDateTime('yok', 2.0) = 2.0, '06 GetDateTime');
    LAyar.SetV('adi', 'Emrah').SetV('n', 7);
    Chk(LAyar.Get('adi', '') = 'Emrah', '07 SetV/Get string');
    Chk(LAyar.Get('n', 0) = 7, '08 SetV/Get Integer, zincirleme');
    Chk(LAyar.SetJson('x', '{"a":1}') = LAyar, '09 SetJson Self dondurur');
  finally
    LAyar.Free;
  end;
end;

procedure OmurVeKayit;
var
  LAyar: TConfigGenel;
begin
  Writeln;
  Writeln('=== Alt nesne omru, kayit, yukleme ===');
  DosyaSil;
  TDepoOptions.Made := 0;
  TDepoOptions.Freed := 0;
  LAyar := TConfigGenel.Create;
  Chk(TDepoOptions.Made = 1, '10 alt nesne bir kez yaratildi');
  LAyar.SetV('adi', 'Emrah');
  LAyar.Depo.DepoAdi := 'Merkez';
  LAyar.Json.Item['kayip'] := 'x';
  Chk(Pos('kayip', LAyar.Json.ToString) = 0, '11 Json anlik goruntu: yazma kaybolur');
  Chk(Pos('Merkez', LAyar.Json.ToString) > 0, '12 Json yayinlanmis alani icerir');
  Chk(LAyar.SaveIfNeeded, '14 SaveIfNeeded kaydeder');
  LAyar.Free;
  Chk(TDepoOptions.Freed = 1, '13 alt nesne bir kez yikildi (Free hatasiz)');
  Chk(TFile.Exists(GFile), '14b dosya yazildi');
  LAyar := TConfigGenel.Create;
  try
    Chk(LAyar.Get('adi', '') = 'Emrah', '15 yeniden yukleme: serbest anahtar');
    Chk(LAyar.Depo.DepoAdi = 'Merkez', '16 yeniden yukleme: alt nesne');
  finally
    LAyar.Free;
  end;
end;

procedure FreeKaydetmez;
var
  LAyar: TConfigGenel;
begin
  Writeln;
  Writeln('=== Free tek basina KAYDETMEZ (acik SaveIfNeeded gerekir) ===');
  DosyaSil;
  LAyar := TConfigGenel.Create;
  LAyar.SetV('adi', 'x');
  LAyar.Free;
  Chk(not TFile.Exists(GFile), '20 SaveIfNeeded cagrilmadan Free dosya yazmaz');
end;

procedure BozukDosya;
var
  LAyar: TConfigGenel;
  LHata: Boolean;
begin
  Writeln;
  Writeln('=== Bozuk / bos dosya ===');
  TFile.WriteAllText(GFile, '{ bozuk json "');
  LHata := False;
  try
    LAyar := TConfigGenel.Create;
    LAyar.Free;
  except
    on ERadConfig do
      LHata := True;
  end;
  Chk(LHata, '17 bozuk dosya ERadConfig firlatir');
  Chk(TFile.ReadAllText(GFile) = '{ bozuk json "', '18 bozuk dosyanin uzerine yazilmadi');

  TFile.WriteAllText(GFile, '');
  LHata := False;
  try
    LAyar := TConfigGenel.Create;
    LAyar.Free;
  except
    LHata := True;
  end;
  Chk(not LHata, '19 bos dosya sorunsuz acilir');
end;

begin
  GOk := 0;
  GFail := 0;
  GFile := ChangeFileExt(ParamStr(0), '.setting.json');
  try
    GetOverloadlari;
    OmurVeKayit;
    FreeKaydetmez;
    BozukDosya;
  except
    on E: Exception do
    begin
      Inc(GFail);
      Writeln('  [PATLADI] ', E.ClassName, ': ', E.Message);
    end;
  end;
  DosyaSil;
  Writeln;
  Writeln(Format('SONUC: %d gecti, %d kaldi.', [GOk, GFail]));
  if GFail > 0 then
    ExitCode := 1;
end.
