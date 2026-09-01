program FormFactoryTest;

{$APPTYPE CONSOLE}

{
  TFormFactory / TRadFormBase davranis sondasi.

  Amac: "su hata var" demek yerine OLCMEK. Her iddia calisan koda dayanir.

  Tasarim karari (test bunu KORUR): TRadFormBase'e kopru TAKILMAZ. Kopru
  duz TForm'un eksik yasam dongusu kancalarini telafi eder; TRadFormBase'in
  o kancalari zaten vardir ve ikisini birden takmak cift tetikleme uretir.
}

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  Vcl.Controls,
  rad.core in '..\..\..\core\rad.core.pas',
  Help.vcl in '..\..\..\core\Help.vcl.pas';

var
  GOk, GFail: Integer;
  GYaratmaSayaci: Integer;   // TRadTest kurucusunda artar

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

type
  { TRadFormBase turevi. DFM tasimadigi icin sanal kurucu CreateNew'e
    yonlendirilir - aksi halde EResNotFound alinir. }
  TRadTest = class(TRadFormBase)
  public
    ShowSayaci: Integer;
    KendiOlaySayaci: Integer;
    constructor Create(AOwner: TComponent); override;
    procedure DoShow; override;
    procedure DoEvent(const AEvent: TFormEventType); override;
    procedure DisaridanDeactivate;
  end;

  { DoEvent'i override edip `inherited` CAGIRMAYAN turev. NotifyEvent
    tasariminin sinandigi yer: boyle bir turev global baglantiyi
    koparabiliyor mu? }
  TInatciTest = class(TRadFormBase)
  public
    constructor Create(AOwner: TComponent); override;
    procedure DoEvent(const AEvent: TFormEventType); override;
  end;

  TDuzTest = class(TForm)
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TOlayDinleyici = class
  public
    RadSayaci: Integer;
    DuzSayaci: Integer;
    InatciSayaci: Integer;
    CaptionSayaci: Integer;
    procedure Yakala(const AControl: TForm; const AEvent: TFormEventType);
  end;

constructor TRadTest.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Inc(GYaratmaSayaci);
end;

procedure TRadTest.DoShow;
begin
  Inc(ShowSayaci);
  inherited;
end;

procedure TRadTest.DoEvent(const AEvent: TFormEventType);
begin
  inherited;
  Inc(KendiOlaySayaci);
end;

procedure TRadTest.DisaridanDeactivate;
begin
  Deactivate;   // protected; turevden erisilebilir
end;

constructor TInatciTest.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
end;

procedure TInatciTest.DoEvent(const AEvent: TFormEventType);
begin
  // BILEREK `inherited` YOK
end;

constructor TDuzTest.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
end;

procedure TOlayDinleyici.Yakala(const AControl: TForm; const AEvent: TFormEventType);
begin
  if AEvent = fetCaptionChange then
    Inc(CaptionSayaci);

  if AControl is TInatciTest then
    Inc(InatciSayaci)
  else if AControl is TRadTest then
    Inc(RadSayaci)
  else
    Inc(DuzSayaci);
end;

function KopruSayisi(AForm: TComponent): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to AForm.ComponentCount - 1 do
    if AForm.Components[i] is TFormEventBridge then
      Inc(Result);
end;

{ ------------------------------------------------------------------ }

procedure KopruKurulumu;
var
  LRad: TRadTest;
  LDuz: TDuzTest;
begin
  Writeln;
  Writeln('=== Kopru yalnizca IHTIYACI OLANA takiliyor mu ===');

  LRad := GlobalFormFactory.Get<TRadTest>('kopru-rad');
  LDuz := GlobalFormFactory.Get<TDuzTest>('kopru-duz');

  Chk(KopruSayisi(LDuz) = 1, '01 duz TForm: kopru KURULDU (kancalari yok)');
  Chk(KopruSayisi(LRad) = 0, '02 TRadFormBase: kopru KURULMADI (kancalari var)');
end;

procedure AutoFreeTutarliligi;
var
  LRad: TRadTest;
  LDuz: TDuzTest;
  i: Integer;
  LKopru: TFormEventBridge;
begin
  Writeln;
  Writeln('=== New<T> "AutoFree=True" niyeti iki ailede de uygulaniyor mu ===');

  LRad := GlobalFormFactory.Get<TRadTest>('af-rad');
  LDuz := GlobalFormFactory.Get<TDuzTest>('af-duz');

  LKopru := nil;
  for i := 0 to LDuz.ComponentCount - 1 do
    if LDuz.Components[i] is TFormEventBridge then
      LKopru := TFormEventBridge(LDuz.Components[i]);

  Chk(Assigned(LKopru) and LKopru.AutoFree,
    '03 duz form: kopru AutoFree=True');
  Chk(LRad._AutoFree,
    '04 TRadFormBase: _AutoFree=True (ayni sozlesme, kopru olmadan)');
end;

procedure GlobalOlaylar;
var
  LDinleyici: TOlayDinleyici;
  LRad: TRadTest;
  LDuz: TDuzTest;
  LInatci: TInatciTest;
  LKendi: Integer;
begin
  Writeln;
  Writeln('=== RegisterEvent her iki form ailesini de goruyor mu ===');

  LDinleyici := TOlayDinleyici.Create;
  try
    GlobalFormFactory.RegisterEvent(LDinleyici.Yakala);

    LRad := GlobalFormFactory.Get<TRadTest>('olay-rad');
    LDuz := GlobalFormFactory.Get<TDuzTest>('olay-duz');
    LInatci := GlobalFormFactory.Get<TInatciTest>('olay-inatci');

    LRad.Show;
    LDuz.Show;
    Application.ProcessMessages;

    LKendi := LRad.KendiOlaySayaci;
    LRad.Caption := 'yeni baslik';       // fetCaptionChange
    Application.ProcessMessages;

    Chk(LDinleyici.DuzSayaci > 0,
      Format('05 duz form olay uretti (%d)', [LDinleyici.DuzSayaci]));
    Chk(LDinleyici.RadSayaci > 0,
      Format('06 TRadFormBase olay uretti (%d)', [LDinleyici.RadSayaci]));
    Chk(LDinleyici.CaptionSayaci > 0,
      '07 Caption degisimi fetCaptionChange uretti (koprudeki tek bosluk)');
    Chk(LRad.KendiOlaySayaci > LKendi,
      '08 turevin kendi DoEvent uzanti noktasi da calisti');
    Chk(LDinleyici.InatciSayaci > 0,
      Format('09 `inherited` CAGIRMAYAN override global baglantiyi KOPARMADI (%d)',
        [LDinleyici.InatciSayaci]));

    LRad.Close;
    LDuz.Close;
    LInatci.Close;
    Application.ProcessMessages;

    GlobalFormFactory.RegisterEvent(nil);
  finally
    LDinleyici.Free;
  end;
end;

procedure ShowWaitDavranisi;
var
  LF: TRadTest;
  LOnceki: Integer;
  LBas, LSure: UInt64;
begin
  Writeln;
  Writeln('=== _ShowWait: odak kaybi artik durumu bozuyor mu ===');

  LF := TRadTest.Create(Application);
  try
    LF.Show;
    Application.ProcessMessages;   // WM_EVENT_AFTERSHOW burada islenir
    Chk(LF._IsShowing, '10 gosterildikten sonra _IsShowing True');

    { Deactivate gercek hayatta baska bir pencere odak alinca gelir. }
    LF.DisaridanDeactivate;

    Chk(LF.Visible, '11 Deactivate sonrasi form hala gorunur');
    Chk(LF._IsShowing,
      '12 _IsShowing HALA True (odak ile gosterim artik karistirilmiyor)');

    LOnceki := LF.ShowSayaci;
    LBas := GetTickCount64;
    LF._ShowWait;                   // eski hâlde burasi SONSUZ donerdi
    LSure := GetTickCount64 - LBas;

    Chk(LSure < 500, Format('13 _ShowWait ANINDA dondu (%d ms)', [LSure]));
    Chk(LF.ShowSayaci = LOnceki, '14 gereksiz yeniden gosterim yapilmadi');

    { Gizlenmis formda: gercekten beklemeli ama zaman asimina takilmamali. }
    LF.Hide;
    Application.ProcessMessages;
    Chk(not LF._IsShowing, '15 Hide sonrasi _IsShowing False');

    LBas := GetTickCount64;
    LF._ShowWait;
    LSure := GetTickCount64 - LBas;
    Chk(LF._IsShowing, '16 _ShowWait formu gercekten gosterdi');
    Chk(LSure < 4000, Format('17 zaman asimina TAKILMADI (%d ms)', [LSure]));
  finally
    LF.Free;
  end;
end;

procedure SarkanIsaretci;
var
  LIlk: TRadTest;
  LOnce: Integer;
begin
  Writeln;
  Writeln('=== Sozlukte sarkan isaretci kaliyor mu ===');

  { ADRES KARSILASTIRMASI KULLANILAMAZ. Form serbest birakildiktan sonra
    bellek yoneticisi ayni blogu yeni forma geri verebilir; adresler
    esitlense de sozluk dogru temizlenmis olabilir. Bu testin ilk hâli tam
    bu yuzden YANLIS KALDI raporu uretti.

    Gecerli olcut: Get<T> gercekten YENI bir nesne YARATTI mi? Kurucu
    sayaci bunu kesin gosterir - sarkan kayit donseydi kurucu hic
    calismazdi. }
  LIlk := GlobalFormFactory.Get<TRadTest>('sarkan');
  LOnce := GYaratmaSayaci;
  LIlk.Free;

  GlobalFormFactory.Get<TRadTest>('sarkan');
  Chk(GYaratmaSayaci = LOnce + 1,
    '18 ayni anahtar YENI nesne yaratti (kayit dusurulmus)');
end;

begin
  GOk := 0;
  GFail := 0;
  Application.Initialize;
  GlobalFormFactory := TFormFactory.Create;
  try
    KopruKurulumu;
    AutoFreeTutarliligi;
    GlobalOlaylar;
    ShowWaitDavranisi;
    SarkanIsaretci;
  except
    on E: Exception do
    begin
      Inc(GFail);
      Writeln('  [PATLADI] ', E.ClassName, ': ', E.Message);
    end;
  end;

  Writeln;
  Writeln(Format('SONUC: %d gecti, %d kaldi.', [GOk, GFail]));
  if GFail > 0 then
    ExitCode := 1;
end.
