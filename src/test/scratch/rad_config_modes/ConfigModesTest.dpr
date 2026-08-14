program ConfigModesTest;

{ Uc mod: SIFRESIZ (rcmNone), SIFRELI (rcmFile), BOLUM SIFRELI (rcmSection).
  Ucu de uc bicimde (json/ini/yaml) sinaniyor. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  mormot.core.base,
  mormot.core.text,
  mormot.core.json,      // TSynAutoCreateFields
  mormot.crypt.core,
  rad.core   in '..\..\..\core\rad.core.pas',
  rad.cipher in '..\..\..\core\rad.cipher.pas',
  rad.config in '..\..\..\core\rad.config.pas';

type
  TSunucuAyar = class(TSynAutoCreateFields)     // ic ice bolum
  private
    FHost: RawUtf8;
    FPort: Integer;
  published
    property Host: RawUtf8 read FHost write FHost;
    property Port: Integer read FPort write FPort;
  end;

  TLogAyar = class(TRadOptions)
  private
    FPath: RawUtf8;
    FSeviye: Integer;
  public
    procedure DefaultValues; override;
    procedure Validate; override;
  published
    property Path: RawUtf8 read FPath write FPath;
    property Seviye: Integer read FSeviye write FSeviye;
  end;

  TVeritabaniAyar = class(TRadOptions)          // SIR TASIYAN bolum
  private
    FKullanici: RawUtf8;
    FParola: RawUtf8;
    FSunucu: TSunucuAyar;                       // otomatik yaratilir
  public
    procedure DefaultValues; override;
    /// rcmSection modunda BU bolum sifrelenir, digerleri duz kalir.
    class function Encrypted: Boolean; override;
  published
    property Kullanici: RawUtf8 read FKullanici write FKullanici;
    property Parola: RawUtf8 read FParola write FParola;
    property Sunucu: TSunucuAyar read FSunucu;
  end;

  TArayuzAyar = class(TRadOptions)
  private
    FTema: RawUtf8;
    FSonAcilanlar: TRawUtf8DynArray;
  published
    property Tema: RawUtf8 read FTema write FTema;
    property SonAcilanlar: TRawUtf8DynArray read FSonAcilanlar write FSonAcilanlar;
  end;

procedure TLogAyar.DefaultValues;
begin
  FPath := 'C:\varsayilan\log';
  FSeviye := 2;
end;

procedure TLogAyar.Validate;
begin
  if FPath = '' then
    raise ERadOptionsValidation.Create('Log.Path bos olamaz');
end;

class function TVeritabaniAyar.Encrypted: Boolean;
begin
  Result := True;
end;

procedure TVeritabaniAyar.DefaultValues;
begin
  FKullanici := 'sa';
  FSunucu.Host := 'localhost';
  FSunucu.Port := 5432;
end;

const
  CParola  = 'P@rol4-cok-gizli-2026';
  CKullan  = 'uygulama_kullanicisi';
  CLogYolu = 'D:\uretim\loglar';

var
  GOk, GFail: Integer;
  GDir: string;

procedure T(B: Boolean; const S: string);
begin
  if B then begin Inc(GOk); Writeln('  [GECTI] ', S) end
  else begin Inc(GFail); Writeln('  [KALDI] ', S) end;
end;

function YeniCipher: IRadCipher;
var
  K: THash256;
begin
  FillCharFast(K, SizeOf(K), 42);
  Result := TRadAesGcmCipher.Create(K, 256);
end;

function YanlisCipher: IRadCipher;
var
  K: THash256;
begin
  FillCharFast(K, SizeOf(K), 99);
  Result := TRadAesGcmCipher.Create(K, 256);
end;

function Yol(const AAd: string): string;
begin
  Result := TPath.Combine(GDir, AAd);
  if TFile.Exists(Result) then
    TFile.Delete(Result);
end;

{ Bir dosyayi bastan kurar, doldurur, kaydeder. }
procedure Doldur(const ADosya: string; const ACipher: IRadCipher;
  AMod: TRadCryptMode = rcmFile);
var
  LCfg: TRadOptionsFile;
  LDb: TVeritabaniAyar;
begin
  LCfg := TRadOptionsFile.Create(ADosya, rofAuto, ACipher, AMod);
  try
    LCfg.Section<TLogAyar>('Log');
    LCfg.Section<TVeritabaniAyar>('Veritabani');
    LCfg.Configure<TArayuzAyar>(
      procedure(o: TArayuzAyar)
      begin
        o.Tema := 'koyu';
        o.SonAcilanlar := ['bir.dpr', 'iki.dpr'];
      end, 'Arayuz');
    LCfg.Load;

    LDb := LCfg.Get<TVeritabaniAyar>;
    LDb.Kullanici := CKullan;
    LDb.Parola := CParola;
    LDb.Sunucu.Host := 'db.uretim.local';
    LDb.Sunucu.Port := 5433;
    LCfg.Get<TLogAyar>.Path := CLogYolu;
    LCfg.SaveForce;
  finally
    LCfg.Free;
  end;
end;

{ Kaydedilenin aynen geri geldigini dogrular. }
procedure Dogrula(const ADosya, AAd: string; const ACipher: IRadCipher;
  AMod: TRadCryptMode = rcmFile);
var
  LCfg: TRadOptionsFile;
  LDb: TVeritabaniAyar;
  LUi: TArayuzAyar;
begin
  LCfg := TRadOptionsFile.Create(ADosya, rofAuto, ACipher, AMod);
  try
    LCfg.Section<TLogAyar>('Log');
    LCfg.Section<TVeritabaniAyar>('Veritabani');
    LCfg.Section<TArayuzAyar>('Arayuz');
    LCfg.Load;

    LDb := LCfg.Get<TVeritabaniAyar>;
    LUi := LCfg.Get<TArayuzAyar>;
    T(LDb.Parola = CParola,                AAd + ' parola');
    T(LDb.Kullanici = CKullan,             AAd + ' kullanici');
    T(LDb.Sunucu.Host = 'db.uretim.local', AAd + ' IC ICE nesne (Host)');
    T(LDb.Sunucu.Port = 5433,              AAd + ' ic ice nesne (Port)');
    T(LCfg.Get<TLogAyar>.Path = CLogYolu,  AAd + ' log yolu');
    T(LCfg.Get<TLogAyar>.Seviye = 2,       AAd + ' DefaultValues korundu');
    T(LUi.Tema = 'koyu',                   AAd + ' Configure degeri');
    T(Length(LUi.SonAcilanlar) = 2,        AAd + ' DIZI uzunlugu');
    T((Length(LUi.SonAcilanlar) = 2) and
      (LUi.SonAcilanlar[1] = 'iki.dpr'),   AAd + ' dizi elemani');
    T(not LCfg.Save,                       AAd + ' Load sonrasi Save yazmiyor');
  finally
    LCfg.Free;
  end;
end;

{ ================================================================ }
{ MOD 1 — SIFRESIZ                                                  }
{ ================================================================ }

procedure Sifresiz(const AUzanti, AAd: string);
var
  LDosya, LMetin: string;
begin
  Writeln;
  Writeln('=== MOD 1 SIFRESIZ / ', AAd, ' ===');
  LDosya := Yol('duz' + AUzanti);

  Doldur(LDosya, nil, rcmNone);
  LMetin := TFile.ReadAllText(LDosya, TEncoding.UTF8);

  T(Pos(CParola, LMetin) > 0,    AAd + ' 1a parola dosyada GORUNUYOR (beklenen)');
  T(Pos('Veritabani', LMetin) > 0, AAd + ' 1b bolum adlari gorunuyor');
  T(Pos('enc', LMetin) = 0,      AAd + ' 1c zarf YOK');

  Dogrula(LDosya, AAd + ' 1d', nil, rcmNone);
end;

{ ================================================================ }
{ MOD 2 — SIFRELI (dosya butun)                                     }
{ ================================================================ }

procedure Sifreli(const AUzanti, AAd: string);
var
  LDosya, LMetin: string;
begin
  Writeln;
  Writeln('=== MOD 2 SIFRELI / ', AAd, ' ===');
  LDosya := Yol('sifreli' + AUzanti);

  Doldur(LDosya, YeniCipher);
  LMetin := TFile.ReadAllText(LDosya, TEncoding.UTF8);

  T(Pos(CParola, LMetin) = 0,      AAd + ' 2a parola GORUNMUYOR');
  T(Pos(CKullan, LMetin) = 0,      AAd + ' 2b kullanici adi gorunmuyor');
  T(Pos(CLogYolu, LMetin) = 0,     AAd + ' 2c log yolu gorunmuyor');
  T(Pos('Veritabani', LMetin) = 0, AAd + ' 2d BOLUM ADLARI bile gorunmuyor');
  T(Pos('db.uretim.local', LMetin) = 0, AAd + ' 2e ic ice deger gorunmuyor');
  T(Pos('enc', LMetin) > 0,        AAd + ' 2f zarf var');
  T(Pos('aes-gcm-256', LMetin) > 0, AAd + ' 2g algoritma etiketi');

  Dogrula(LDosya, AAd + ' 2h', YeniCipher);
end;

{ ================================================================ }
{ MOD 3 — BOLUM SIFRELI                                             }
{ ================================================================ }

procedure BolumSifreli(const AUzanti, AAd: string);
var
  LDosya, LMetin: string;
  LCfg: TRadOptionsFile;
begin
  Writeln;
  Writeln('=== MOD 3 BOLUM SIFRELI / ', AAd, ' ===');
  LDosya := Yol('bolum' + AUzanti);

  Doldur(LDosya, YeniCipher, rcmSection);
  LMetin := TFile.ReadAllText(LDosya, TEncoding.UTF8);

  // SIR TASIYAN bolum gizli...
  T(Pos(CParola, LMetin) = 0,           AAd + ' 3a parola GORUNMUYOR');
  T(Pos(CKullan, LMetin) = 0,           AAd + ' 3b kullanici gorunmuyor');
  T(Pos('db.uretim.local', LMetin) = 0, AAd + ' 3c ic ice deger gorunmuyor');
  T(Pos('RADSEC1', LMetin) > 0,         AAd + ' 3d bolum isareti var');

  // ...ama dosyanin geri kalani DUZ. rcmFile'dan farki tam olarak bu.
  T(Pos('Veritabani', LMetin) > 0,      AAd + ' 3e bolum ADI gorunuyor');
  // DIKKAT: JSON ters bolüyu kacisliyor (D:\\uretim\\loglar), ham CLogYolu
  // aranirsa JSON ve YAML'de bulunamaz. Kacislanmayan bir parca ariyoruz.
  T(Pos('uretim', LMetin) > 0,          AAd + ' 3f SIFRESIZ bolum duz duruyor');
  T(Pos('koyu', LMetin) > 0,            AAd + ' 3g diger duz bolum de okunur');

  Dogrula(LDosya, AAd + ' 3h', YeniCipher, rcmSection);

  // Yanlis anahtar SADECE sifreli bolumu vurmali
  LCfg := TRadOptionsFile.Create(LDosya, rofAuto, YanlisCipher, rcmSection);
  try
    LCfg.Section<TLogAyar>('Log');
    LCfg.Section<TVeritabaniAyar>('Veritabani');
    try
      LCfg.Load;
      T(False, AAd + ' 3i yanlis anahtar -> ERadOptionsDecrypt');
    except
      on E: ERadOptionsDecrypt do
        T(True, AAd + ' 3i yanlis anahtar -> ERadOptionsDecrypt');
    end;
  finally
    LCfg.Free;
  end;

  // Anahtarsiz acmak da reddedilmeli
  LCfg := TRadOptionsFile.Create(LDosya, rofAuto, nil, rcmNone);
  try
    LCfg.Section<TVeritabaniAyar>('Veritabani');
    try
      LCfg.Load;
      T(False, AAd + ' 3j anahtarsiz -> ERadOptionsDecrypt');
    except
      on E: ERadOptionsDecrypt do
        T(True, AAd + ' 3j anahtarsiz -> ERadOptionsDecrypt');
    end;
  finally
    LCfg.Free;
  end;
end;

{ ================================================================ }

procedure ZarfGoster;
begin
  Writeln;
  Writeln('--- SIFRESIZ .json ---');
  Writeln(TFile.ReadAllText(TPath.Combine(GDir, 'duz.json'), TEncoding.UTF8));
  Writeln('--- SIFRELI (rcmFile) .json ---');
  Writeln(TFile.ReadAllText(TPath.Combine(GDir, 'sifreli.json'), TEncoding.UTF8));
  Writeln('--- BOLUM SIFRELI (rcmSection) .json ---');
  Writeln(TFile.ReadAllText(TPath.Combine(GDir, 'bolum.json'), TEncoding.UTF8));
  Writeln('--- BOLUM SIFRELI (rcmSection) .ini ---');
  Writeln(TFile.ReadAllText(TPath.Combine(GDir, 'bolum.ini'), TEncoding.UTF8));
end;

begin
  GOk := 0; GFail := 0;
  GDir := TPath.GetDirectoryName(ParamStr(0));
  try
    Sifresiz('.json', 'JSON');
    Sifresiz('.ini',  'INI ');
    Sifresiz('.yaml', 'YAML');

    Sifreli('.json', 'JSON');
    Sifreli('.ini',  'INI ');
    Sifreli('.yaml', 'YAML');

    BolumSifreli('.json', 'JSON');
    BolumSifreli('.ini',  'INI ');
    BolumSifreli('.yaml', 'YAML');

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
