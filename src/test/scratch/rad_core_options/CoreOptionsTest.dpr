program coretest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  mormot.core.base,
  mormot.core.json,
  // Ayar sistemi rad.core'dan rad.config'e TASINDI; bu test o tasimadan
  // once yazilmisti ve bu yuzden derlenmiyordu.
  rad.core   in '..\..\..\core\rad.core.pas',
  rad.cipher in '..\..\..\core\rad.cipher.pas',
  rad.config in '..\..\..\core\rad.config.pas';

type
  TLogConfig = class(TSynAutoCreateFields)     // ic ice bolum
  private
    FVerbose: Boolean;
    FEnvironment: RawUtf8;
  published
    property Verbose: Boolean read FVerbose write FVerbose;
    property Environment: RawUtf8 read FEnvironment write FEnvironment;
  end;

  TLoggingOptions = class(TRadOptions)
  private
    FPath: RawUtf8;
    FConfig: TLogConfig;                        // OTOMATIK yaratilir
  public
    procedure DefaultValues; override;
    procedure Validate; override;
  published
    property Path: RawUtf8 read FPath write FPath;
    property Config: TLogConfig read FConfig;
  end;

  TGlobalOptions = class(TRadOptions)
  private
    FStartMinimized: Boolean;
    FServers: TRawUtf8DynArray;
    FRetry: Integer;
  public
    procedure DefaultValues; override;
  published
    property StartMinimized: Boolean read FStartMinimized write FStartMinimized;
    property Servers: TRawUtf8DynArray read FServers write FServers;
    property Retry: Integer read FRetry write FRetry;
  end;

  TUIOptions = class(TRadOptions)
  private
    FForeColor: Integer;
    FBackgroundColor: Integer;
  published
    property ForeColor: Integer read FForeColor write FForeColor;
    property BackgroundColor: Integer read FBackgroundColor write FBackgroundColor;
  end;

procedure TLoggingOptions.DefaultValues;
begin
  FPath := 'C:\01';
  FConfig.Verbose := False;
  FConfig.Environment := 'DEV';
end;

procedure TLoggingOptions.Validate;
begin
  if FPath = '' then
    raise ERadOptionsValidation.Create('Logging.Path bos olamaz');
end;

procedure TGlobalOptions.DefaultValues;
begin
  FStartMinimized := False;
  FRetry := 3;
end;

var
  GOk, GFail: Integer;

procedure C(B: Boolean; const S: string);
begin
  if B then begin Inc(GOk); Writeln('  [GECTI] ', S) end
  else begin Inc(GFail); Writeln('  [KALDI] ', S) end;
end;

procedure Senaryo(const AFile: string; const AAd: string);
var
  cfg: TRadOptionsFile;
  log: TLoggingOptions;
  gl: TGlobalOptions;
begin
  Writeln;
  Writeln('=== ', AAd, ' -> ', ExtractFileName(AFile), ' ===');
  if TFile.Exists(AFile) then TFile.Delete(AFile);

  // 1) Bolumleri tanimla + varsayilanlari kur
  cfg := TRadOptionsFile.Create(AFile);
  try
    cfg.Section<TLoggingOptions>('Logging');
    cfg.Configure<TGlobalOptions>(
      procedure(o: TGlobalOptions)
      begin
        o.StartMinimized := True;
        o.Servers := ['ServerOne', 'ServerTwo'];
      end, 'GlobalOptions');
    cfg.Section<TUIOptions>;                    // ad TUIOptions -> UIOptions

    C(cfg.Count = 3, AAd + ' 01 uc bolum kayitli');
    C(cfg.SectionNames[2] = 'UIOptions', AAd + ' 02 ad sinif adindan turedi');

    cfg.Load;                                   // dosya yok -> varsayilan + yaz
    C(TFile.Exists(AFile), AAd + ' 03 dosya olusturuldu');
    C(cfg.Get<TLoggingOptions>.Path = 'C:\01', AAd + ' 04 DefaultValues uygulandi');

    // 2) Degistir ve kaydet
    log := cfg.Get<TLoggingOptions>;
    log.Path := 'D:\loglar';
    log.Config.Verbose := True;
    log.Config.Environment := 'PRO';
    cfg.Get<TUIOptions>.ForeColor := 77;
    C(cfg.Save, AAd + ' 05 degisiklik kaydedildi');
    C(not cfg.Save, AAd + ' 06 ikinci Save DEGISMEDIGI icin yazmadi');
  finally
    cfg.Free;
  end;

  // 3) Yeni kapla geri yukle
  cfg := TRadOptionsFile.Create(AFile);
  try
    cfg.Section<TLoggingOptions>('Logging');
    cfg.Section<TGlobalOptions>('GlobalOptions');
    cfg.Section<TUIOptions>;
    cfg.Load;

    log := cfg.Get<TLoggingOptions>;
    gl := cfg.Get<TGlobalOptions>;
    C(log.Path = 'D:\loglar',                AAd + ' 07 string geri yuklendi');
    C(log.Config.Verbose,                    AAd + ' 08 IC ICE nesne geri yuklendi');
    C(log.Config.Environment = 'PRO',        AAd + ' 09 ic ice string');
    C(gl.StartMinimized,                     AAd + ' 10 bool');
    C(gl.Retry = 3,                          AAd + ' 11 DefaultValues korundu');
    C(Length(gl.Servers) = 2,                AAd + ' 12 DIZI geri yuklendi');
    C((Length(gl.Servers) = 2) and (gl.Servers[1] = 'ServerTwo'), AAd + ' 13 dizi elemani');
    C(cfg.Get<TUIOptions>.ForeColor = 77,    AAd + ' 14 ucuncu bolum');
  finally
    cfg.Free;
  end;
end;

var
  LDir, LFile: string;
  cfg: TRadOptionsFile;
  LSec: TUIOptions;
begin
  GOk := 0; GFail := 0;
  //LDir := TPath.Combine(TPath.GetTempPath, 'radcore_test');

  LDir := TPath.GetDirectoryName(ParamStr(0));

  Senaryo(TPath.Combine(LDir, 'ayar.json'), 'JSON');
  Senaryo(TPath.Combine(LDir, 'ayar.ini'),  'INI ');
  Senaryo(TPath.Combine(LDir, 'ayar.yaml'), 'YAML');

  Writeln;
  Writeln('=== Hata yollari ===');
  LFile := TPath.Combine(LDir, 'hata.json');
  if TFile.Exists(LFile) then TFile.Delete(LFile);

  cfg := TRadOptionsFile.Create(LFile);
  try
    cfg.Section<TUIOptions>;
    // Ayni ad baska sinifla
    try
      cfg.Section<TLoggingOptions>('UIOptions');
      C(False, '20 ad cakismasi -> ERadOptionsSection');
    except
      on E: ERadOptionsSection do C(True, '20 ad cakismasi -> ERadOptionsSection');
    end;
    // Kayitsiz bolum
    try
      cfg.Get<TGlobalOptions>;
      C(False, '21 kayitsiz bolum -> ERadOptionsSection');
    except
      on E: ERadOptionsSection do C(True, '21 kayitsiz bolum -> ERadOptionsSection');
    end;
    C(not cfg.Has<TGlobalOptions>, '22 Has False donuyor');
    C(cfg.TryGet<TUIOptions>(LSec), '23 TryGet True');
    // Ayni sinif ayni bolum tekrar eklenirse MEVCUT doner
    C(cfg.Section<TUIOptions> = LSec, '24 tekrar ekleme mevcut ornegi dondurdu');
    // Dogrulama hatasi
    cfg.Section<TLoggingOptions>('Logging').Path := '';
    try
      cfg.SaveForce;
      C(False, '25 Validate reddi -> ERadOptionsValidation');
    except
      on E: ERadOptionsValidation do C(True, '25 Validate reddi -> ERadOptionsValidation');
    end;
  finally
    cfg.Free;
  end;

  Writeln;
  Writeln('--- uretilen JSON ---');
  Writeln(TFile.ReadAllText(TPath.Combine(LDir, 'ayar.json'), TEncoding.UTF8));
  Writeln('--- uretilen INI ---');
  Writeln(TFile.ReadAllText(TPath.Combine(LDir, 'ayar.ini'), TEncoding.UTF8));

  Writeln;
  Writeln(System.SysUtils.Format('SONUC: %d gecti, %d kaldi.', [GOk, GFail]));
  if GFail > 0 then ExitCode := 1;
end.
