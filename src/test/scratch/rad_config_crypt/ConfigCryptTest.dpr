program ConfigCryptTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  mormot.core.base,
  mormot.core.text,
  mormot.core.json,
  mormot.crypt.core,
  rad.core   in '..\..\..\core\rad.core.pas',
  rad.cipher in '..\..\..\core\rad.cipher.pas',
  rad.config in '..\..\..\core\rad.config.pas';

type
  TLogSec = class(TRadOptions)
  private
    FPath: RawUtf8;
    FRetry: Integer;
  public
    procedure DefaultValues; override;
  published
    property Path: RawUtf8 read FPath write FPath;
    property Retry: Integer read FRetry write FRetry;
  end;

  TDbSec = class(TRadOptions)
  private
    FUser: RawUtf8;
    FPwd: RawUtf8;
  published
    property User: RawUtf8 read FUser write FUser;
    property Pwd: RawUtf8 read FPwd write FPwd;
  end;

procedure TLogSec.DefaultValues;
begin
  FPath := 'C:\varsayilan';
  FRetry := 3;
end;

var
  GOk, GFail: Integer;

procedure T(B: Boolean; const S: string);
begin
  if B then begin Inc(GOk); Writeln('  [GECTI] ', S) end
  else begin Inc(GFail); Writeln('  [KALDI] ', S) end;
end;

function YeniCipher(AByte: Byte): IRadCipher;
var
  K: THash256;
begin
  FillCharFast(K, SizeOf(K), AByte);
  Result := TRadAesGcmCipher.Create(K, 256);
end;

const
  CGizli = 'cok-gizli-parola-42';

var
  GDir: string;

function Yol(const AAd: string): string;
begin
  Result := TPath.Combine(GDir, AAd);
  if TFile.Exists(Result) then
    TFile.Delete(Result);
end;

{ ---------------------------------------------------------------- }

procedure Senaryo(const AUzanti, AAd: string);
var
  LDosya, LMetin: string;
  LCfg: TRadOptionsFile;
begin
  Writeln;
  Writeln('=== ', AAd, ' ===');
  LDosya := Yol('gizli' + AUzanti);

  // 1) Sifreli yaz
  LCfg := TRadOptionsFile.Create(LDosya, rofAuto, YeniCipher(7));
  try
    T(LCfg.Encrypted, AAd + ' 01 Encrypted = True');
    LCfg.Section<TLogSec>('Logging');
    LCfg.Section<TDbSec>('Db');
    LCfg.Load;                              // dosya yok -> olustur
    LCfg.Get<TDbSec>.Pwd := CGizli;
    LCfg.Get<TLogSec>.Path := 'D:\loglar';
    T(LCfg.Save, AAd + ' 02 degisiklik kaydedildi');
    T(not LCfg.Save, AAd + ' 03 ikinci Save yazmadi (hash DUZ METIN uzerinden)');
  finally
    LCfg.Free;
  end;

  // 2) Dosyanin icinde sir GORUNMEMELI
  LMetin := TFile.ReadAllText(LDosya, TEncoding.UTF8);
  T(Pos(CGizli, LMetin) = 0,        AAd + ' 04 parola dosyada GORUNMUYOR');
  T(Pos('D:\loglar', LMetin) = 0,   AAd + ' 05 diger degerler de gorunmuyor');
  T(Pos('Logging', LMetin) = 0,     AAd + ' 06 BOLUM ADLARI bile gorunmuyor');
  T(Pos('enc', LMetin) > 0,         AAd + ' 07 zarf anahtari var');
  T(Pos('aes-gcm-256', LMetin) > 0, AAd + ' 08 algoritma etiketi var');

  // 3) Ayni anahtarla geri yukle
  LCfg := TRadOptionsFile.Create(LDosya, rofAuto, YeniCipher(7));
  try
    LCfg.Section<TLogSec>('Logging');
    LCfg.Section<TDbSec>('Db');
    LCfg.Load;
    T(LCfg.Get<TDbSec>.Pwd = CGizli,          AAd + ' 09 parola geri yuklendi');
    T(LCfg.Get<TLogSec>.Path = 'D:\loglar',   AAd + ' 10 diger deger geri yuklendi');
    T(LCfg.Get<TLogSec>.Retry = 3,            AAd + ' 11 DefaultValues korundu');
    T(not LCfg.Save, AAd + ' 12 Load sonrasi Save gereksiz yazma YAPMIYOR');
  finally
    LCfg.Free;
  end;
end;

procedure YanlisAnahtar;
var
  LDosya: string;
  LCfg: TRadOptionsFile;
begin
  Writeln;
  Writeln('=== Yanlis anahtar / anahtarsiz ===');
  LDosya := Yol('yanlis.json');

  LCfg := TRadOptionsFile.Create(LDosya, rofAuto, YeniCipher(7));
  try
    LCfg.Section<TDbSec>('Db');
    LCfg.Load;
    LCfg.Get<TDbSec>.Pwd := CGizli;
    LCfg.SaveForce;
  finally
    LCfg.Free;
  end;

  // Yanlis anahtar
  LCfg := TRadOptionsFile.Create(LDosya, rofAuto, YeniCipher(9));
  try
    LCfg.Section<TDbSec>('Db');
    try
      LCfg.Load;
      T(False, '13 yanlis anahtar -> ERadOptionsDecrypt');
    except
      on E: ERadOptionsDecrypt do T(True, '13 yanlis anahtar -> ERadOptionsDecrypt');
    end;
  finally
    LCfg.Free;
  end;

  // Hic anahtar yok
  LCfg := TRadOptionsFile.Create(LDosya);
  try
    LCfg.Section<TDbSec>('Db');
    try
      LCfg.Load;
      T(False, '14 anahtarsiz acma -> ERadOptionsDecrypt');
    except
      on E: ERadOptionsDecrypt do T(True, '14 anahtarsiz acma -> ERadOptionsDecrypt');
    end;
  finally
    LCfg.Free;
  end;

  // ERadCore tek atadan yakalanabiliyor mu (rad.core ile rad.config ayni agac)
  LCfg := TRadOptionsFile.Create(LDosya);
  try
    LCfg.Section<TDbSec>('Db');
    try
      LCfg.Load;
      T(False, '15 ERadCore tek except ile yakalaniyor');
    except
      on E: ERadCore do T(True, '15 ERadCore tek except ile yakalaniyor');
    end;
  finally
    LCfg.Free;
  end;
end;

procedure Kurcalama;
var
  LDosya: string;
  LCfg: TRadOptionsFile;
  LMetin: string;
  i: Integer;
begin
  Writeln;
  Writeln('=== Kurcalanmis dosya ===');
  LDosya := Yol('kurcala.json');

  LCfg := TRadOptionsFile.Create(LDosya, rofAuto, YeniCipher(7));
  try
    LCfg.Section<TDbSec>('Db');
    LCfg.Load;
    LCfg.Get<TDbSec>.Pwd := CGizli;
    LCfg.SaveForce;
  finally
    LCfg.Free;
  end;

  // base64url govdesinin ortasindaki bir karakteri degistir
  LMetin := TFile.ReadAllText(LDosya, TEncoding.UTF8);
  i := Pos('"enc"', LMetin) + 40;
  if LMetin[i] = 'A' then LMetin[i] := 'B' else LMetin[i] := 'A';
  TFile.WriteAllText(LDosya, LMetin, TEncoding.UTF8);

  LCfg := TRadOptionsFile.Create(LDosya, rofAuto, YeniCipher(7));
  try
    LCfg.Section<TDbSec>('Db');
    try
      LCfg.Load;
      T(False, '16 kurcalama -> ERadOptionsDecrypt');
    except
      on E: ERadOptionsDecrypt do T(True, '16 kurcalama -> ERadOptionsDecrypt');
    end;
  finally
    LCfg.Free;
  end;
end;

procedure DuzdenSifreliye;
var
  LDosya: string;
  LCfg: TRadOptionsFile;
  LMetin: string;
begin
  Writeln;
  Writeln('=== Duz -> sifreli -> duz gecisi ===');
  LDosya := Yol('gecis.json');

  // Duz olarak olustur
  LCfg := TRadOptionsFile.Create(LDosya);
  try
    LCfg.Section<TDbSec>('Db');
    LCfg.Load;
    LCfg.Get<TDbSec>.Pwd := CGizli;
    LCfg.SaveForce;
  finally
    LCfg.Free;
  end;
  LMetin := TFile.ReadAllText(LDosya, TEncoding.UTF8);
  T(Pos(CGizli, LMetin) > 0, '17 duz dosyada parola GORUNUYOR (beklenen)');

  // Cipher VERILDI ama dosya duz: hata verilmemeli, okunmali
  LCfg := TRadOptionsFile.Create(LDosya, rofAuto, YeniCipher(7));
  try
    LCfg.Section<TDbSec>('Db');
    LCfg.Load;
    T(LCfg.Get<TDbSec>.Pwd = CGizli, '18 cipher varken DUZ dosya okunabildi');
    T(LCfg.Save, '19 bir sonraki Save sifreledi');
  finally
    LCfg.Free;
  end;
  LMetin := TFile.ReadAllText(LDosya, TEncoding.UTF8);
  T(Pos(CGizli, LMetin) = 0, '20 artik sifreli');

  // RemoveCipher -> duz metne donus
  LCfg := TRadOptionsFile.Create(LDosya, rofAuto, YeniCipher(7));
  try
    LCfg.Section<TDbSec>('Db');
    LCfg.Load;
    LCfg.RemoveCipher;
    T(not LCfg.Encrypted, '21 RemoveCipher sonrasi Encrypted = False');
    T(LCfg.Save, '22 icerik degismese de yazdi (FForceNextSave)');
  finally
    LCfg.Free;
  end;
  LMetin := TFile.ReadAllText(LDosya, TEncoding.UTF8);
  T(Pos(CGizli, LMetin) > 0, '23 tekrar duz metin');
end;

procedure AnahtarRotasyonu;
var
  LDosya: string;
  LCfg: TRadOptionsFile;
begin
  Writeln;
  Writeln('=== Anahtar rotasyonu ===');
  LDosya := Yol('rotasyon.json');

  LCfg := TRadOptionsFile.Create(LDosya, rofAuto, YeniCipher(7));
  try
    LCfg.Section<TDbSec>('Db');
    LCfg.Load;
    LCfg.Get<TDbSec>.Pwd := CGizli;
    LCfg.SaveForce;
    LCfg.ChangeCipher(YeniCipher(9));
    T(LCfg.Save, '24 ChangeCipher sonrasi Save YAZDI');
  finally
    LCfg.Free;
  end;

  // Eski anahtar artik acmamali
  LCfg := TRadOptionsFile.Create(LDosya, rofAuto, YeniCipher(7));
  try
    LCfg.Section<TDbSec>('Db');
    try
      LCfg.Load;
      T(False, '25 ESKI anahtar artik acamiyor');
    except
      on E: ERadOptionsDecrypt do T(True, '25 ESKI anahtar artik acamiyor');
    end;
  finally
    LCfg.Free;
  end;

  // Yeni anahtar acmali
  LCfg := TRadOptionsFile.Create(LDosya, rofAuto, YeniCipher(9));
  try
    LCfg.Section<TDbSec>('Db');
    LCfg.Load;
    T(LCfg.Get<TDbSec>.Pwd = CGizli, '26 YENI anahtar aciyor');
  finally
    LCfg.Free;
  end;

  // ChangeCipher(nil) reddedilmeli
  LCfg := TRadOptionsFile.Create(LDosya, rofAuto, YeniCipher(9));
  try
    try
      LCfg.ChangeCipher(nil);
      T(False, '27 ChangeCipher(nil) -> ERadOptions');
    except
      on E: ERadOptions do T(True, '27 ChangeCipher(nil) -> ERadOptions');
    end;
  finally
    LCfg.Free;
  end;
end;

procedure ZarfGoster;
begin
  Writeln;
  Writeln('--- uretilen JSON zarfi ---');
  Writeln(TFile.ReadAllText(TPath.Combine(GDir, 'gizli.json'), TEncoding.UTF8));
  Writeln('--- uretilen INI zarfi ---');
  Writeln(TFile.ReadAllText(TPath.Combine(GDir, 'gizli.ini'), TEncoding.UTF8));
end;

begin
  GOk := 0; GFail := 0;
  GDir := TPath.GetDirectoryName(ParamStr(0));
  try
    Senaryo('.json', 'JSON');
    Senaryo('.ini',  'INI ');
    Senaryo('.yaml', 'YAML');
    YanlisAnahtar;
    Kurcalama;
    DuzdenSifreliye;
    AnahtarRotasyonu;
    ZarfGoster;
  except
    on E: Exception do
    begin
      Inc(GFail);
      Writeln('  [PATLADI] ', E.ClassName, ': ', E.Message);
    end;
  end;

  Writeln;
  Writeln(Format('SONUC: %d gecti, %d kaldi.', [GOk, GFail]));
  if GFail > 0 then ExitCode := 1;
end.
