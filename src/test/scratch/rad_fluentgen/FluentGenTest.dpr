program FluentGenTest;

(* GenerateFluentUnit: kaynak tarama, uretim ve birlestirme tuzaklari. Uretilen
   her birim bin\gen altina yazilir; build_and_run.bat hepsini ayrica derler,
   cunku "derlenmeye hazir" iddiasinin tek kaniti derleyicidir. *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Generics.Collections,
  Data.DB, Vcl.Controls, Vcl.Forms, Vcl.Graphics, Vcl.StdCtrls, Vcl.ComCtrls,
  rad.utils, Rad.Editor.Tools, Rad.Editor.FluentOptions, FluentGenFixture;

const
  CDelphiRegKey = 'Software\Embarcadero\BDS\37.0';

var
  GBasari: Integer = 0;
  GHata: Integer = 0;
  GGen, GKutuphane, GFixtureDir: string;

procedure Kontrol(const AAd: string; ABasarili: Boolean; const ADetay: string = '');
begin
  if ABasarili then
  begin
    Inc(GBasari);
    Writeln('  [OK]   ', AAd);
  end
  else
  begin
    Inc(GHata);
    Writeln('  [HATA] ', AAd, '  ', ADetay);
  end;
end;

function Oku(const AAd: string): string;
begin
  Result := TFile.ReadAllText(TPath.Combine(GGen, AAd), TEncoding.UTF8);
end;

function UretFixture(AClass: TClass; const AAd: string): string;
begin
  TRadFluent.GenerateUnit(AClass, TPath.Combine(GGen, AAd), TPath.Combine(GFixtureDir, 'FluentGenFixture.pas'));
  Result := Oku(AAd);
end;

procedure KaynakTaramaTestleri;
var
  LKod: string;
begin
  Writeln('Kaynak tarama:');
  LKod := UretFixture(TFwd, 'x_Fwd.pas');
  Kontrol('ileri bildirim atlanir, sonraki sinif okunmaz', not LKod.Contains('OtherProp'));
  Kontrol('asil sinifin uyesi uretilir', LKod.Contains('SetX'));

  LKod := UretFixture(TOneLiner, 'x_OneLiner.pas');
  Kontrol('tek satirlik sinif sonrakini okumaz', not LKod.Contains('AfterProp'));

  LKod := UretFixture(TUsesBlind, 'x_UsesBlind.pas');
  Kontrol('RTTI gormeyen property kaynaktan gelir', LKod.Contains('SetB'));
  Kontrol('etkin olmayan $IFDEF dali uses''a girmez', not LKod.Contains('Posix.Unistd'));
  Kontrol('etkin uses korunur', LKod.Contains('System.SysUtils'));

  LKod := UretFixture(TOver, 'x_Over.pas');
  Kontrol('saglam overload''lar dusmez',
    LKod.Contains('procedure Foo(const A: Integer); overload;') or LKod.Contains('procedure Foo(A: Integer); overload;'));
  Kontrol('parametresiz overload da kalir', LKod.Contains('procedure Foo; overload;'));
  Kontrol('asilsiz uyari yazilmaz', not LKod.Contains('ÜRETİLMEDİ'));

  LKod := UretFixture(THidden, 'x_Hidden.pas');
  Kontrol('ic ice sinifin uyesi disariya tasmaz', not LKod.Contains('SecretProp'));
  Kontrol('yanindaki metot kalir', LKod.Contains('function Visible: Integer;'));

  LKod := UretFixture(TNested, 'x_Nested.pas');
  Kontrol('ic tipten sonraki uyeler okunmaya devam eder', LKod.Contains('SetTail'));
  Kontrol('public ic tip uretilir', LKod.Contains('function Part:'));

  LKod := UretFixture(TCond, 'x_Cond.pas');
  Kontrol('etkin dal uretilir', LKod.Contains('SetWinProp') and LKod.Contains('SetLastProp'));
  Kontrol('etkin daldan sonraki ELSEIF/ELSE okunmaz', not LKod.Contains('PosixProp') and
    not LKod.Contains('OtherOsProp'));
  Kontrol('CLR dali okunmaz', not LKod.Contains('ClrProp'));

  LKod := UretFixture(TOverBlind, 'x_OverBlind.pas');
  Kontrol('imzasi kurulamayan overload hala dusurulur', LKod.Contains('ÜRETİLMEDİ') and
    not LKod.Contains('procedure Foo'));
end;

procedure UretimTestleri;
var
  LKod: string;
begin
  Writeln('Uretim:');
  LKod := UretFixture(TClash, 'x_Clash.pas');
  Kontrol('gercek metot adini korur', LKod.Contains('function GetName: Integer;'));
  Kontrol('erisimci yeniden adlandirilir', LKod.Contains('function GetNameProp: string;'));
  Kontrol('rapor adlandirmayi yazar', LKod.Contains('GetNameProp'));

  LKod := UretFixture(TFactoryClash, 'x_FactoryClash.pas');
  Kontrol('fabrika adiyla cakisan metot ayrisir', LKod.Contains('function AsInstanceMethod: Integer;') and
    LKod.Contains('function NewMethod: Integer;'));

  LKod := UretFixture(TWord, 'x_Word.pas');
  Kontrol('ayrilmis parametre adi kacirilir', LKod.Contains('&Type: string'));
  Kontrol('ayrilmis metot adi kacirilir', LKod.Contains('procedure &End;'));

  LKod := UretFixture(TGen<Integer>, 'x_Gen.pas');
  Kontrol('generic sinif gecerli ada iner', LKod.Contains('IGen_System_Integer = interface'));

  LKod := UretFixture(TOuter.TInner, 'x_Inner.pas');
  Kontrol('ic ice sinif gecerli ada iner', LKod.Contains('IOuter_TInner = interface'));
  TRadFluent.GenerateUnit(TOuter.TInner, TPath.Combine(GGen, 'x_Inner.pas'), '', CFluentUnitDefaultOptions, fumMergeRegions);
  Kontrol('ic ice sinif birlestirmede cogalmaz',
    Length(LKod.Split(['RAD-FLUENT:'])) = Length(Oku('x_Inner.pas').Split(['RAD-FLUENT:'])));

  LKod := UretFixture(TBitmap, 'b_Bitmap.pas');
  Kontrol('nitelenmis ad sinifin kendisine de uygulanir', LKod.Contains('FInstance: Vcl.Graphics.TBitmap;'));
  Kontrol('parca API''si kisa adda kalir',
    TRadFluent.GenerateCode(TButton, '', CFluentGenDefaultOptions).Contains('function AsInstance: TButton;'));
end;

function Say(const AMetin, AAranan: string): Integer;
begin
  Result := Length(AMetin.Split([AAranan])) - 1;
end;

procedure KalitimTestleri;
var
  LKod: string;
begin
  Writeln('Kalitim:');
  Kontrol('varsayilanlarda kapali', not (fgoIncludeInherited in CFluentGenDefaultOptions) and
    not (fgoIncludeInherited in CFluentUnitDefaultOptions));

  LKod := UretFixture(TLevelMid, 'x_LevelOff.pas');
  Kontrol('kapaliyken ata uyesi yok', not LKod.Contains('BaseOnly') and not LKod.Contains('SetBaseProp'));

  TRadFluent.GenerateUnit(TLevelMid, TPath.Combine(GGen, 'x_LevelOn.pas'), TPath.Combine(GFixtureDir, 'FluentGenFixture.pas'),
    CFluentUnitDefaultOptions + [fgoIncludeInherited]);
  LKod := Oku('x_LevelOn.pas');
  Kontrol('ata metodu ve propertysi gelir', LKod.Contains('function BaseOnly: Integer;') and LKod.Contains('SetBaseProp'));
  Kontrol('TComponent uyeleri gelir', LKod.Contains('SetName'));
  Kontrol('TPersistent ve TObject uyeleri gelmez', not LKod.Contains('Assign') and not LKod.Contains('ClassName'));
  Kontrol('override tek uye olur', Say(LKod, '    procedure Run;') = 2, IntToStr(Say(LKod, '    procedure Run;')));
  Kontrol('yeniden bildirilen property tek uye olur', Say(LKod, '    function SetShared(') = 2);
  Kontrol('turemis metodun gizledigi overload uretilmez', LKod.Contains('procedure Over(A: Double);') and
    not LKod.Contains('Over(const A: string)') and not LKod.Contains('Over(A: Integer)'));
  Kontrol('turemis property atadaki metodu gizler', LKod.Contains('SetHiddenByProp') and
    not LKod.Contains('function HiddenByProp('));
  Kontrol('turemis metot atadaki propertyyi gizler', LKod.Contains('function HiddenByMethod(') and
    not LKod.Contains('SetHiddenByMethod'));
  {$WARN SYMBOL_DEPRECATED OFF}
  Kontrol('eski ad sarmalayici olarak calisir', GenerateFluentCode(TOther).Contains('IOther = interface'));
  {$WARN SYMBOL_DEPRECATED ON}
  Kontrol('rapor kapsami yazar', LKod.Contains('Kalıtılan üyeler dahil'));

  Kontrol('sayac secenegi izler', TRadFluent.CountMembers(TLevelMid, True) > TRadFluent.CountMembers(TLevelMid, False));
end;

procedure FormTestleri;
var
  LForm: TRadFluentOptionsForm;
begin
  Writeln('Secenek formu:');
  LForm := TRadFluentOptionsForm.Create(nil);
  try
    LForm.Prepare([TLabel, TLevelMid]);
    Kontrol('DFM yuklenir, siniflar listelenir', LForm.lstClasses.Items.Count = 2);
    Kontrol('sayilar gorunur', LForm.lstClasses.Items[0].StartsWith('TLabel: ') and
      LForm.lstClasses.Items[0].Contains('kalıtılanlarla'), LForm.lstClasses.Items[0]);
    Kontrol('varsayilan kapali', LForm.Options = CFluentUnitDefaultOptions);
    LForm.chkInherited.Checked := True;
    Kontrol('isaretleyince acilir', fgoIncludeInherited in LForm.Options);
  finally
    LForm.Free;
  end;
end;

procedure UretGercek(const AClasses: array of TClass);
var
  LClass: TClass;
  LKaynak: string;
begin
  Writeln('Gercek siniflar (derleme adimi bat icinde):');
  for LClass in AClasses do
  begin
    LKaynak := TRadFluentDesign.FindSource(LClass.UnitName, GKutuphane);
    TRadFluent.GenerateUnit(LClass, TPath.Combine(GGen, 'b_' + LClass.ClassName + '.pas'), LKaynak);
    TRadFluent.GenerateUnit(LClass, TPath.Combine(GGen, 'i_' + LClass.ClassName + '.pas'), LKaynak,
      CFluentUnitDefaultOptions + [fgoIncludeInherited]);
    Kontrol(LClass.ClassName, True);
  end;
end;

procedure Yaz(const AAd, AMetin: string; AEncoding: TEncoding; ABom: Boolean);
var
  LAkis: TFileStream;
  LBayt, LOnEk: TBytes;
begin
  LBayt := AEncoding.GetBytes(StringReplace(AMetin, '|', sLineBreak, [rfReplaceAll]));
  LAkis := TFileStream.Create(TPath.Combine(GGen, AAd), fmCreate);
  try
    if ABom then
    begin
      LOnEk := AEncoding.GetPreamble;
      LAkis.WriteBuffer(LOnEk, Length(LOnEk));
    end;
    LAkis.WriteBuffer(LBayt, Length(LBayt));
  finally
    LAkis.Free;
  end;
end;

procedure Birlestir(const AAd: string);
begin
  TRadFluent.GenerateUnit(TLabel, TPath.Combine(GGen, AAd), '', CFluentUnitDefaultOptions, fumMergeRegions);
end;

procedure BirlestirmeTestleri;
var
  LKod: string;
  LAnsi: TEncoding;
begin
  Writeln('Birlestirme:');
  Yaz('m1_nobom.pas', 'unit m1_nobom;|interface|// Açıklama: şğüİ|implementation|end.|', TEncoding.UTF8, False);
  Birlestir('m1_nobom.pas');
  Kontrol('BOM''suz UTF-8 Turkce metin korunur', Oku('m1_nobom.pas').Contains('Açıklama: şğüİ'));

  LAnsi := TEncoding.GetEncoding(1254);
  try
    Yaz('m1_ansi.pas', 'unit m1_ansi;|interface|// Açıklama: şğüİ|implementation|end.|', LAnsi, False);
  finally
    LAnsi.Free;
  end;
  Birlestir('m1_ansi.pas');
  Kontrol('ANSI Turkce metin korunur', Oku('m1_ansi.pas').Contains('Açıklama: şğüİ'));

  Yaz('m2_yorum.pas', 'unit m2_yorum;|interface|uses|  System.Classes, // temel|  Vcl.Controls;|implementation|end.|', TEncoding.UTF8, True);
  Birlestir('m2_yorum.pas');
  Kontrol('yorumlu uses satiri korunur', Oku('m2_yorum.pas').Contains('System.Classes, // temel'));

  Yaz('m3_noktali.pas', 'unit m3_noktali;|interface|uses|  System.Classes, // a; b|  Vcl.Controls;|implementation|end.|', TEncoding.UTF8, True);
  Birlestir('m3_noktali.pas');
  LKod := Oku('m3_noktali.pas');
  Kontrol('yorumdaki noktali virgul sonlandirici sayilmaz', LKod.Contains('// a; b'));
  Kontrol('birimler koda yazilir', LKod.Contains('Vcl.Controls, Vcl.StdCtrls') or LKod.Contains(', Vcl.StdCtrls'));

  Yaz('m3_blok.pas', 'unit m3_blok;|interface|uses|  System.Classes {temel; birim},|  Vcl.Controls;|implementation|end.|', TEncoding.UTF8, True);
  Birlestir('m3_blok.pas');
  Kontrol('blok yorumu da korunur', Oku('m3_blok.pas').Contains('{temel; birim}'));

  Yaz('m4_tek.pas', 'unit m4_tek;|interface|implementation|uses|  System.Classes;|end.|', TEncoding.UTF8, True);
  Birlestir('m4_tek.pas');
  LKod := Oku('m4_tek.pas');
  Kontrol('implementation uses''taki tek birim tasinir, cumle kalkar',
    not LKod.Substring(LKod.IndexOf('implementation')).Contains('uses'));

  Yaz('m4_cok.pas', 'unit m4_cok;|interface|implementation|uses|  System.SysUtils, System.Classes, System.Math;|end.|', TEncoding.UTF8, True);
  Birlestir('m4_cok.pas');
  LKod := Oku('m4_cok.pas');
  LKod := LKod.Substring(LKod.IndexOf('implementation'));
  Kontrol('digerleri implementation uses''ta kalir', LKod.Contains('System.SysUtils, System.Math;'));

  Yaz('m5_alan.pas', 'unit m5_alan;|interface|type|  TCfg = record|    UsesTls: Boolean;|  end;|implementation|end.|', TEncoding.UTF8, True);
  Birlestir('m5_alan.pas');
  LKod := Oku('m5_alan.pas');
  Kontrol('uses ile baslayan alan cumle sanilmaz', LKod.Contains('    UsesTls: Boolean;'));
  Kontrol('uses cumlesi yerine acilir', LKod.Contains('interface' + sLineBreak + sLineBreak + 'uses'), LKod.Substring(0, 80));

  Yaz('m6_yorumlu.pas', 'unit m6_yorumlu;|interface|{|implementation|}|implementation // not|end.|', TEncoding.UTF8, True);
  Birlestir('m6_yorumlu.pas');
  Kontrol('yorumdaki anahtar kelime yaniltmaz, satir sonu yorumu engellemez',
    Oku('m6_yorumlu.pas').IndexOf('RAD-FLUENT') > Oku('m6_yorumlu.pas').IndexOf('}'));
end;

procedure Kur;
begin
  GGen := TPath.Combine(ExtractFilePath(ParamStr(0)), 'gen');
  if TDirectory.Exists(GGen) then
    TDirectory.Delete(GGen, True);
  TDirectory.CreateDirectory(GGen);
  GFixtureDir := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..');
  GKutuphane := StringReplace(TRadFluentDesign.LibraryPath(CDelphiRegKey), '$(BDS)',
    GetEnvironmentVariable('BDS'), [rfReplaceAll, rfIgnoreCase]);
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    Kur;
    KaynakTaramaTestleri;
    UretimTestleri;
    KalitimTestleri;
    FormTestleri;
    UretGercek([TComponent, TStream, TList, TCollection, TStrings, TForm, TPageControl,
      TControl, TWinControl, TDataSet, TDataSource, TField, TBitmap, TCanvas, TButton, TLabel]);
    BirlestirmeTestleri;
  except
    on E: Exception do
    begin
      Inc(GHata);
      Writeln('  [HATA] beklenmeyen istisna: ', E.ClassName, ': ', E.Message);
    end;
  end;
  Writeln(Format('Sonuc: %d basarili, %d hata', [GBasari, GHata]));
  if GHata > 0 then
    Halt(1);
end.
