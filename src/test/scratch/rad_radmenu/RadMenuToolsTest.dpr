program RadMenuToolsTest;

(* Rad.Editor.Tools: RadMenu sahipligi ve secimden Fluent uretimi, IDE'siz.
   IDE tarafi (INTAServices, IDesigner) burada calismaz; elle dogrulama adimlari
   src/README.md icinde. *)

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Generics.Collections,
  Vcl.Menus, Vcl.Controls, Vcl.StdCtrls,
  rad.utils, Rad.Editor.Tools;

const
  CDelphiRegKey = 'Software\Embarcadero\BDS\37.0';

var
  GBasari: Integer = 0;
  GHata: Integer = 0;

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

type
  TGomuluFrame = class(TComponent)
  public
    procedure GomuluYap;
  end;

  TKalemItem = class(TCollectionItem);

  TGenel<T> = class(TPersistent);

  TTiklamaSayaci = class
  public
    Sayi: Integer;
    procedure Tikla(Sender: TObject);
  end;

procedure TGomuluFrame.GomuluYap;
begin
  SetInline(True);
end;

procedure TTiklamaSayaci.Tikla(Sender: TObject);
begin
  Inc(Sayi);
end;

procedure SecimTestleri;
var
  LKok: TComponent;
  LB1, LB2: TButton;
  LEtiket: TLabel;
  LFrame: TGomuluFrame;
  LKalemler: TCollection;
  LSonuc: TRadFluentSelection;
begin
  Writeln('Secim:');
  LKok := TComponent.Create(nil);
  LKalemler := TCollection.Create(TKalemItem);
  try
    LKok.Name := 'Form1';
    LB1 := TButton.Create(LKok);
    LB2 := TButton.Create(LKok);
    LEtiket := TLabel.Create(LKok);
    LFrame := TGomuluFrame.Create(LKok);
    LFrame.Name := 'Frame1';
    LFrame.GomuluYap;

    LSonuc := TRadFluentDesign.Selection([], LKok);
    Kontrol('bos secim', (LSonuc.Classes = nil) and (LSonuc.Skipped = nil));

    LSonuc := TRadFluentDesign.Selection([LB1, LB2, LEtiket], LKok);
    Kontrol('ayni sinif bir kez, secim sirasiyla',
      (Length(LSonuc.Classes) = 2) and (LSonuc.Classes[0] = TButton) and (LSonuc.Classes[1] = TLabel));

    LSonuc := TRadFluentDesign.Selection([LKok], LKok);
    Kontrol('kok sarmalanmaz', (LSonuc.Classes = nil) and (Length(LSonuc.Skipped) = 1) and
      (LSonuc.Skipped[0] = 'Form1'));

    LSonuc := TRadFluentDesign.Selection([LB1, LFrame], LKok);
    Kontrol('gomulu frame atlanir, yanindaki kalir',
      (Length(LSonuc.Classes) = 1) and (LSonuc.Classes[0] = TButton) and
      (Length(LSonuc.Skipped) = 1) and (LSonuc.Skipped[0] = 'Frame1'));

    LSonuc := TRadFluentDesign.Selection([LKalemler.Add], nil);
    Kontrol('bilesen olmayan TPersistent da secilebilir',
      (Length(LSonuc.Classes) = 1) and (LSonuc.Classes[0] = TKalemItem));
  finally
    LKalemler.Free;
    LKok.Free;
  end;
end;

procedure DosyaAdiTestleri;
begin
  Writeln('Dosya adi:');
  Kontrol('T onekini atar', TRadFluentDesign.DefaultFileName(TButton) = 'Button.Fluent.pas');
  Kontrol('generic adi temizler', TRadFluentDesign.DefaultFileName(TGenel<Integer>) = 'Genel.Fluent.pas',
    TRadFluentDesign.DefaultFileName(TGenel<Integer>));
end;

procedure KaynakAramaTestleri;
var
  LKok, LDizin1, LDizin2, LYol: string;
begin
  Writeln('Kaynak arama:');
  LKok := TPath.Combine(TPath.GetTempPath, 'rad_radmenu_' + TGUID.NewGuid.ToString);
  LDizin1 := TPath.Combine(LKok, 'a');
  LDizin2 := TPath.Combine(LKok, 'b');
  TDirectory.CreateDirectory(LDizin1);
  TDirectory.CreateDirectory(LDizin2);
  try
    TFile.WriteAllText(TPath.Combine(LDizin2, 'Foo.Bar.pas'), 'unit Foo.Bar;');
    LYol := Format(';$(YOK)\x; %s ;%s;', [LDizin1, LDizin2]);
    Kontrol('bos, makrolu ve bosluklu girdileri gecer',
      SameText(TRadFluentDesign.FindSource('Foo.Bar', LYol), TPath.Combine(LDizin2, 'Foo.Bar.pas')),
      TRadFluentDesign.FindSource('Foo.Bar', LYol));
    Kontrol('bulunamazsa bos', TRadFluentDesign.FindSource('Yok', LYol) = '');
    Kontrol('bos yol listesi', TRadFluentDesign.FindSource('Foo.Bar', '') = '');
  finally
    TDirectory.Delete(LKok, True);
  end;
end;

procedure KutuphaneYoluTestleri;
var
  LYol: string;
begin
  Writeln('Kutuphane yolu (HKCU, salt okunur):');
  LYol := TRadFluentDesign.LibraryPath(CDelphiRegKey);
  Kontrol('kurulu IDE anahtarindan okunur', Pos('$(BDS)', LYol) > 0, LYol);
  LYol := StringReplace(LYol, '$(BDS)', GetEnvironmentVariable('BDS'), [rfReplaceAll, rfIgnoreCase]);
  Kontrol('Vcl.StdCtrls kaynagi bu yoldan bulunur', TRadFluentDesign.FindSource('Vcl.StdCtrls', LYol) <> '');
  Kontrol('olmayan anahtar bos doner', TRadFluentDesign.LibraryPath('Software\Rad\Yok') = '');
end;

procedure UretimTestleri;
var
  LHedef, LIlk, LYol: string;
  LSiniflar: TArray<string>;
begin
  Writeln('Uretim:');
  LHedef := TPath.Combine(ExtractFilePath(ParamStr(0)), 'gen');
  TDirectory.CreateDirectory(LHedef);
  LHedef := TPath.Combine(LHedef, 'RadMenuProbe.Fluent.pas');
  if FileExists(LHedef) then
    DeleteFile(LHedef);
  LYol := StringReplace(TRadFluentDesign.LibraryPath(CDelphiRegKey), '$(BDS)',
    GetEnvironmentVariable('BDS'), [rfReplaceAll, rfIgnoreCase]);

  TRadFluentDesign.WriteUnit([TButton, TLabel], LHedef, LYol);
  LSiniflar := TRadFluent.ListRegions(LHedef);
  Kontrol('iki sinif tek birimde', (Length(LSiniflar) = 2) and (LSiniflar[0] = 'TButton') and
    (LSiniflar[1] = 'TLabel'));
  LIlk := TFile.ReadAllText(LHedef, TEncoding.UTF8);
  Kontrol('kaynak taranmis (TLabel/TButton birimi bulundu)', Pos('StdCtrls.pas', LIlk) > 0);
  Kontrol('ic ice tipin dis sinifi uses''a girmez', Pos('TCustomButton;', LIlk) = 0);

  TRadFluentDesign.WriteUnit([TButton], LHedef, LYol);
  Kontrol('yeniden uretim digerine dokunmaz, GUID sabit',
    TFile.ReadAllText(LHedef, TEncoding.UTF8) = LIlk);
end;

procedure MenuTestleri;
var
  LAna: TMainMenu;
  LMenu: TRadToolMenu;
  LOge: TMenuItem;
  LSayac: TTiklamaSayaci;
  LSahip: TComponent;
  LOnce: Integer;
begin
  Writeln('Menu sahipligi:');
  LSayac := TTiklamaSayaci.Create;
  LAna := TMainMenu.Create(nil);
  try
    LOnce := LAna.Items.Count;
    LMenu := TRadToolMenu.Create(nil);
    try
      Kontrol('baslik', LMenu.Root.Caption = SRadMenuCaption);
      LOge := LMenu.AddTool(SRadFluentCaption, LSayac.Tikla);
      LAna.Items.Add(LMenu.Root);
      Kontrol('ust duzey oge eklendi', LAna.Items.Count = LOnce + 1);
      Kontrol('arac kokun altinda', (LMenu.Root.Count = 1) and (LMenu.Root[0] = LOge));
      LOge.Click;
      Kontrol('tiklama isleyiciye ulasir', LSayac.Sayi = 1);
    finally
      LMenu.Free;
    end;
    Kontrol('Free kalinti birakmaz (paket kaldirma)', LAna.Items.Count = LOnce);
  finally
    LAna.Free;
  end;

  // IDE kapanisi: ana menu once yikilir, bizim finalization sonra calisir.
  LAna := TMainMenu.Create(nil);
  LMenu := TRadToolMenu.Create(nil);
  try
    LMenu.AddTool(SRadFluentCaption, LSayac.Tikla);
    LAna.Items.Add(LMenu.Root);
    LAna.Free;
    Kontrol('host once yikilirsa Root nil olur', LMenu.Root = nil);
    Kontrol('sahipli oge kalmaz', LMenu.ComponentCount = 0, IntToStr(LMenu.ComponentCount));
  finally
    LMenu.Free;
  end;
  Kontrol('host once yikilinca Free guvenli', True);

  // Menu servisi ogenin sahipligini devralirsa kok yasamaya devam eder.
  LSahip := TComponent.Create(nil);
  LAna := TMainMenu.Create(nil);
  LMenu := TRadToolMenu.Create(nil);
  try
    LMenu.AddTool(SRadFluentCaption, LSayac.Tikla);
    LAna.Items.Add(LMenu.Root);
    LOnce := LAna.Items.Count;
    LSahip.InsertComponent(LMenu.Root);
    Kontrol('sahip degisince Root kaybolmaz', (LMenu.Root <> nil) and (LMenu.Root.Count = 1));
    FreeAndNil(LMenu);
    Kontrol('sahip degisse de Free menuyu temizler', LAna.Items.Count = LOnce - 1);
    Kontrol('yeni sahipte kalinti yok', LSahip.ComponentCount = 0);
  finally
    LMenu.Free;
    LAna.Free;
    LSahip.Free;
  end;

  // Yeni sahip koku once yok ederse (IDE kapanisi) cift Free olmamali.
  LSahip := TComponent.Create(nil);
  LMenu := TRadToolMenu.Create(nil);
  try
    LSahip.InsertComponent(LMenu.Root);
    FreeAndNil(LSahip);
    Kontrol('yeni sahip yok edince Root nil olur', LMenu.Root = nil);
  finally
    LMenu.Free;
    LSahip.Free;
  end;
  LSayac.Free;
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    SecimTestleri;
    DosyaAdiTestleri;
    KaynakAramaTestleri;
    KutuphaneYoluTestleri;
    UretimTestleri;
    MenuTestleri;
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
