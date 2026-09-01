program HelpVclTest;

{ Help.vcl.pas icin regresyon testi.

  Kapsam: SAF MANTIK - konum hesabi, sinir korumalari, menu/aksiyon
  yardimcilari. Gorsel davranis (animasyon, modal, MDI) burada test
  EDILMEZ; onlar bir mesaj dongusu ve gercek pencere gerektirir. Her test
  duzeltilmis somut bir hataya karsilik gelir, testin adinda yazar. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.Threading,
  Winapi.Windows,   // GetTickCount64
  System.Types,
  System.UITypes,
  Vcl.Controls,
  Vcl.ExtCtrls,   // TPanel
  Vcl.Forms,
  Vcl.Menus,
  Vcl.ActnList,
  System.Actions,
  Help.vcl in '..\..\..\core\Help.vcl.pas';

var
  GOk, GFail: Integer;

procedure T(B: Boolean; const S: string);
begin
  if B then begin Inc(GOk); Writeln('  [GECTI] ', S) end
  else begin Inc(GFail); Writeln('  [KALDI] ', S) end;
end;

function YeniForm(AW, AH: Integer): TForm;
begin
  Result := TForm.CreateNew(nil);
  Result.SetBounds(0, 0, AW, AH);
end;

const
  CRect: TRect = (Left: 100; Top: 200; Right: 1100; Bottom: 800);   // 1000 x 600

{ ================================================================== }
{ 1. _PositionEx - konum hesabi                                       }
{ ================================================================== }

procedure KonumHesabi;
var
  F: TForm;
begin
  Writeln;
  Writeln('=== _PositionEx konum hesabi (rect 100,200 - 1100,800 / form 300x100) ===');

  F := YeniForm(300, 100);
  try
    F._PositionEx(CRect, haInsideLeft, vaInsideTop);
    T((F.Left = 100) and (F.Top = 200), Format('01 sol-ust  -> %d,%d', [F.Left, F.Top]));

    F._PositionEx(CRect, haInsideRight, vaInsideTop);
    T((F.Left = 800) and (F.Top = 200), Format('02 sag-ust  -> %d,%d', [F.Left, F.Top]));

    F._PositionEx(CRect, haInsideLeft, vaInsideBottom);
    T((F.Left = 100) and (F.Top = 700), Format('03 sol-alt  -> %d,%d', [F.Left, F.Top]));

    F._PositionEx(CRect, haInsideRight, vaInsideBottom);
    T((F.Left = 800) and (F.Top = 700), Format('04 sag-alt  -> %d,%d', [F.Left, F.Top]));

    F._PositionEx(CRect, haCenter, vaCenter);
    T((F.Left = 450) and (F.Top = 450), Format('05 merkez   -> %d,%d', [F.Left, F.Top]));

    // Disari hizalamalar
    F._PositionEx(CRect, haOutsideLeft, vaOutsideTop);
    T((F.Left = -200) and (F.Top = 100), Format('06 dis sol-ust -> %d,%d', [F.Left, F.Top]));

    F._PositionEx(CRect, haOutsideRight, vaOutsideBottom);
    T((F.Left = 1100) and (F.Top = 800), Format('07 dis sag-alt -> %d,%d', [F.Left, F.Top]));

    // Offset
    F._PositionEx(CRect, haInsideLeft, vaInsideTop, 25);
    T((F.Left = 125) and (F.Top = 225), Format('08 offset 25 -> %d,%d', [F.Left, F.Top]));
  finally
    F.Free;
  end;
end;

{ ================================================================== }
{ 2. Bos dikdortgen korumasi (DUZELTILDI: ekran disina kayiyordu)     }
{ ================================================================== }

procedure BosDikdortgen;
var
  F: TForm;
  LBos, LTers: TRect;
begin
  Writeln;
  Writeln('=== Bos ARect korumasi ===');

  F := YeniForm(300, 100);
  try
    F.Left := 500;
    F.Top := 400;

    LBos := TRect.Create(0, 0, 0, 0);
    F._PositionEx(LBos, haInsideRight, vaInsideBottom);
    T((F.Left = 500) and (F.Top = 400),
      Format('09 bos rect -> konum DEGISMEDI (%d,%d). Duzeltme oncesi -300,-100 olurdu',
             [F.Left, F.Top]));

    // Ters cevrilmis dikdortgen de bos sayilir
    LTers := TRect.Create(900, 900, 100, 100);
    F._PositionEx(LTers, haInsideLeft, vaInsideTop);
    T((F.Left = 500) and (F.Top = 400),
      Format('10 ters rect -> konum DEGISMEDI (%d,%d)', [F.Left, F.Top]));
  finally
    F.Free;
  end;
end;

{ ================================================================== }
{ 3. Position ozelligi (DUZELTILDI: VCL konumu eziyordu)              }
{ ================================================================== }

procedure PositionOzelligi;
var
  F: TForm;
begin
  Writeln;
  Writeln('=== Position -> poDesigned yan etkisi ===');

  F := YeniForm(300, 100);
  try
    T(F.Position = poDefaultPosOnly, '11 VCL varsayilani poDefaultPosOnly (ezen mod)');

    F._PositionEx(CRect, haInsideLeft, vaInsideTop);
    T(F.Position = poDesigned, '12 _PositionEx sonrasi poDesigned');

    F.Position := poScreenCenter;
    F._Position(CRect, wpCenter);
    T(F.Position = poDesigned, '13 poScreenCenter da poDesigned yapiliyor');
  finally
    F.Free;
  end;
end;

{ ================================================================== }
{ 4. wpCustom (DUZELTILDI: TForm olmayanda EInvalidCast atiyordu)     }
{ ================================================================== }

procedure CustomKonum;
var
  F: TForm;
  Pnl: TWinControl;
  LSonuc: TWinControl;
begin
  Writeln;
  Writeln('=== wpCustom ===');

  F := YeniForm(300, 100);
  try
    F.Left := 42;
    F.Top := 43;
    LSonuc := F._Position(CRect, wpCustom);
    T((F.Left = 42) and (F.Top = 43), '14 wpCustom konumu degistirmiyor');
    T(LSonuc = F, '15 wpCustom Self dondurur (Result atanmis)');

    // TForm OLMAYAN bir TWinControl: eski hâl burada EInvalidCast atiyordu
    Pnl := TPanel.Create(F);
    Pnl.Parent := F;
    Pnl.SetBounds(0, 0, 50, 50);
    try
      LSonuc := Pnl._Position(CRect, wpCustom);
      T(LSonuc = Pnl, '16 TForm OLMAYAN kontrolde wpCustom patlamiyor');
    except
      on E: Exception do
        T(False, '16 TForm olmayan wpCustom -> ' + E.ClassName);
    end;
  finally
    F.Free;
  end;
end;

{ ================================================================== }
{ 5. _DefaultKeyGet / _DefaultKeySet (DUZELTILDI: son eleman atlaniyordu) }
{ ================================================================== }

procedure KisayolListesi;
var
  F: TForm;
  AL: TActionList;
  A1, A2, A3: TAction;
  LKisayollar: TArray<TShortCut>;
begin
  Writeln;
  Writeln('=== TActionListHelp kisayollari ===');

  F := TForm.CreateNew(nil);
  try
    AL := TActionList.Create(F);
    A1 := TAction.Create(F); A1.ActionList := AL; A1.Name := 'actBir';
    A2 := TAction.Create(F); A2.ActionList := AL; A2.Name := 'actIki';
    A3 := TAction.Create(F); A3.ActionList := AL; A3.Name := 'actUc';

    A1.ShortCut := 100;
    A2.ShortCut := 200;
    A3.ShortCut := 300;

    LKisayollar := AL._DefaultKeyGet;
    T(Length(LKisayollar) = 3, '17 _DefaultKeyGet uc kisayol dondu');
    T((LKisayollar[0] = 100) and (LKisayollar[2] = 300), '18 degerler dogru');

    A1.ShortCut := 0; A2.ShortCut := 0; A3.ShortCut := 0;
    AL._DefaultKeySet(LKisayollar);

    T(A1.ShortCut = 100, '19 ilk kisayol geri yuklendi');
    T(A2.ShortCut = 200, '20 ortadaki kisayol geri yuklendi');
    T(A3.ShortCut = 300,
      '21 SON kisayol geri yuklendi (duzeltme oncesi ATLANIYORDU)');

    // Dizi Action sayisindan UZUN olursa sinir asilmamali
    SetLength(LKisayollar, 10);
    try
      AL._DefaultKeySet(LKisayollar);
      T(True, '22 fazla uzun dizi sinir asmadi');
    except
      on E: Exception do T(False, '22 fazla uzun dizi -> ' + E.ClassName);
    end;

    T(AL._FindName('actIki') = A2, '23 _FindName');
    T(AL._FindName('yokboyle') = nil, '24 _FindName bulamayinca nil');
  finally
    F.Free;
  end;
end;

{ ================================================================== }
{ 6. _Execute (DUZELTILDI: atanmamis Result)                          }
{ ================================================================== }

procedure AksiyonCalistir;
var
  F: TForm;
  A: TAction;
  i: Integer;
  LHepsiFalse: Boolean;
begin
  Writeln;
  Writeln('=== TActionHelp._Execute ===');

  F := TForm.CreateNew(nil);
  try
    A := TAction.Create(F);
    A.Enabled := False;
    A.Visible := True;

    // Atanmamis Result rastgele bir deger olurdu; 50 kez deneyip
    // hepsinin False geldigini dogruluyoruz.
    LHepsiFalse := True;
    for i := 1 to 50 do
      if A._Execute then
        LHepsiFalse := False;
    T(LHepsiFalse, '25 pasif aksiyon 50 denemede de False (Result atanmis)');

    A.Enabled := True;
    A.Visible := False;
    LHepsiFalse := True;
    for i := 1 to 50 do
      if A._Execute then
        LHepsiFalse := False;
    T(LHepsiFalse, '26 gizli aksiyon 50 denemede de False');

    A._Visible(False);
    T((not A.Visible) and (not A.Enabled), '27 _Visible(False) ikisini de kapatir');
  finally
    F.Free;
  end;
end;

{ ================================================================== }
{ 7. Menu yardimcilari                                                }
{ ================================================================== }

procedure MenuAgaci;
var
  F: TForm;
  M: TMainMenu;
  Kok, Yaprak: TMenuItem;
begin
  Writeln;
  Writeln('=== Menu yardimcilari ===');

  F := TForm.CreateNew(nil);
  try
    M := TMainMenu.Create(F);
    Kok := M._Add('Dosya', 7, 3);
    T(Kok <> nil, '28 _Add ogeyi olusturdu');
    T((Kok.Tag = 7) and (Kok.ImageIndex = 3), '29 Tag ve ImageIndex atandi');
    T(M._FindTag(7) = Kok, '30 _FindTag');
    T(M._FindTag(999) = nil, '31 _FindTag bulamayinca nil');
    T(M._FindCaption('Dosya') = Kok, '32 _FindCaption');

    Yaprak := Kok._AddOrGetPath('Yeni\Proje\Bos');
    T(Yaprak <> nil, '33 _AddOrGetPath yaprak olusturdu');
    T(Yaprak._Caption = 'Bos', '34 yaprak basligi');
    T(Yaprak._TreeCaption('\') = 'Dosya\Yeni\Proje\Bos',
      '35 _TreeCaption -> ' + Yaprak._TreeCaption('\'));

    // Ayni yol tekrar istenirse AYNI ogeyi dondurmeli
    T(Kok._AddOrGetPath('Yeni\Proje\Bos') = Yaprak, '36 _AddOrGetPath idempotent');

    // nil proc ile _ForEach patlamamali (DUZELTILDI)
    try
      M._ForEach(nil);
      T(True, '37 _ForEach(nil) patlamiyor');
    except
      on E: Exception do T(False, '37 _ForEach(nil) -> ' + E.ClassName);
    end;
  finally
    F.Free;
  end;
end;

{ ================================================================== }
{ 8. Sahipsiz nesneler (DUZELTILDI: Owner nil -> erisim ihlali)        }
{ ================================================================== }

procedure SahipsizNesneler;
var
  AL: TActionList;
  A, B: TAction;
begin
  Writeln;
  Writeln('=== Owner = nil korumalari ===');

  AL := TActionList.Create(nil);
  try
    AL.Name := 'actListe';
    try
      T(AL._UniqName = 'actListe', '38 _UniqName sahipsizken patlamiyor');
    except
      on E: Exception do T(False, '38 _UniqName -> ' + E.ClassName);
    end;

    A := TAction.Create(nil);
    B := TAction.Create(nil);
    try
      B.Caption := 'Kaynak';
      B.Tag := 55;
      A._Clone(B);
      T((A.Caption = 'Kaynak') and (A.Tag = 55), '39 _Clone sahipsizken calisti');
    except
      on E: Exception do T(False, '39 _Clone -> ' + E.ClassName);
    end;
    A.Free;
    B.Free;
  finally
    AL.Free;
  end;
end;

{ ================================================================== }
{ 9. _EnsureInWorkArea / _FitToScreen                                 }
{ ================================================================== }

procedure EkranaSigdir;
var
  F: TForm;
  R: TRect;
  LOncekiW: Integer;
begin
  Writeln;
  Writeln('=== _EnsureInWorkArea / _FitToScreen ===');

  R := Screen.WorkAreaRect;

  F := YeniForm(200, 150);
  try
    // Ekranin cok disina koy, iceri cekilmeli
    F.SetBounds(R.Right + 5000, R.Bottom + 5000, 200, 150);
    F._EnsureInWorkArea;
    T((F.Left + F.Width <= R.Right + 1) and (F.Top + F.Height <= R.Bottom + 1),
      Format('40 sag/alt tasma iceri cekildi -> %d,%d', [F.Left, F.Top]));

    F.SetBounds(-5000, -5000, 200, 150);
    F._EnsureInWorkArea;
    T((F.Left >= R.Left) and (F.Top >= R.Top),
      Format('41 sol/ust tasma iceri cekildi -> %d,%d', [F.Left, F.Top]));
  finally
    F.Free;
  end;

  // Sifir boyutlu form: eski hâl sifira bolme veriyordu
  F := TForm.CreateNew(nil);
  try
    F.SetBounds(0, 0, 0, 0);
    try
      F._FitToScreen(True);
      T(True, '42 sifir boyutlu formda _FitToScreen patlamiyor (sifira bolme)');
    except
      on E: Exception do T(False, '42 _FitToScreen -> ' + E.ClassName);
    end;
  finally
    F.Free;
  end;

  // Ekrandan buyuk form: TEK kez olceklenmeli, iki kez degil
  F := YeniForm(R.Width * 2, R.Height * 2);
  try
    LOncekiW := F.Width;
    F._FitToScreen(True);
    T(F.Width <= R.Width,
      Format('43 buyuk form ekrana sigdi (%d -> %d)', [LOncekiW, F.Width]));
    T(F.Width > R.Width div 2,
      Format('44 CIFT olcekleme YOK (%d, yarim ekrandan buyuk)', [F.Width]));
  finally
    F.Free;
  end;
end;


{ ================================================================== }
{ 10. _ModalAsync sozlesmesi                                          }
{ ================================================================== }

type
  { Destructor'i bayrak set eden veri nesnesi: helper'in LData'yi gercekten
    free ettigini kanitlamak icin. }
  TIzliVeri = class(TObject)
  public
    Icerik: string;
    destructor Destroy; override;
  end;

  { DFM'i yok: varsayilan TForm.Create kaynak arar ve EResNotFound atar.
    _ModalAsync sanal kurucuyu cagirdigi icin burayi override ediyoruz. }
  TTestForm = class(TForm)
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  GVeriSilindi: Boolean;

constructor TTestForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
end;

destructor TIzliVeri.Destroy;
begin
  GVeriSilindi := True;
  inherited;
end;

{ Modal acildiktan AGecikmeMs sonra aktif formu kapatir. }
procedure GecikmeliKapat(AGecikmeMs: Integer);
begin
  TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep(AGecikmeMs);
      TThread.Queue(nil,
        procedure
        begin
          if Screen.ActiveCustomForm <> nil then
            Screen.ActiveCustomForm.ModalResult := mrCancel;
        end);
    end).Start;
end;

procedure ModalAsyncMutluYol;
var
  LSonuc: TModalResult;
  LGeriCagrildi: Boolean;
  LOkunan: string;
begin
  Writeln;
  Writeln('=== _ModalAsync mutlu yol ===');
  GVeriSilindi := False;
  LGeriCagrildi := False;
  LOkunan := '';

  LSonuc := TTestForm._ModalAsync(
    function: TObject
    var
      LV: TIzliVeri;
    begin
      Sleep(50);                  // arka plandaki agir is
      LV := TIzliVeri.Create;
      LV.Icerik := 'yuklendi';
      Result := LV;
    end,
    procedure(AData: TObject; AForm: TCustomForm)
    begin
      LGeriCagrildi := True;
      LOkunan := TIzliVeri(AData).Icerik;
      AForm.ModalResult := mrOk;  // modal'i kapat
    end);

  T(LGeriCagrildi, '45 AOnDataReady ANA THREAD de cagrildi');
  T(LOkunan = 'yuklendi', '46 veri geri cagirima ulasti');
  T(LSonuc = mrOk, '47 ShowModal sonucu donuyor (procedure degil function)');
  T(GVeriSilindi, '48 LData helper tarafindan FREE edildi (eski hâlde sizardi)');
end;

procedure ModalAsyncHataYolu;
var
  LSonuc: TModalResult;
  LHataMesaji: string;
begin
  Writeln;
  Writeln('=== _ModalAsync hata yolu ===');
  LHataMesaji := '';

  LSonuc := TTestForm._ModalAsync(
    function: TObject
    begin
      Result := nil;
      raise Exception.Create('yukleme patladi');
    end,
    procedure(AData: TObject; AForm: TCustomForm)
    begin
      AForm.ModalResult := mrOk;   // buraya HIC gelinmemeli
    end,
    procedure(E: Exception)
    begin
      LHataMesaji := E.Message;
    end);

  T(LHataMesaji = 'yukleme patladi',
    '49 ALoadData istisnasi AOnError a ulasti (eski hâlde YUTULUYORDU)');
  T(LSonuc = mrAbort, '50 hata durumunda modal mrAbort ile kapandi');
end;

procedure ModalAsyncErkenKapanma;
var
  LSonuc: TModalResult;
  LGeriCagrildi: Boolean;
  LBitis: UInt64;
begin
  Writeln;
  Writeln('=== _ModalAsync: kullanici veri GELMEDEN kapatirsa ===');
  GVeriSilindi := False;
  LGeriCagrildi := False;

  GecikmeliKapat(120);            // veri gelmeden formu kapat

  LSonuc := TTestForm._ModalAsync(
    function: TObject
    var
      LV: TIzliVeri;
    begin
      Sleep(600);                 // geri cagirim GEC gelecek
      LV := TIzliVeri.Create;
      LV.Icerik := 'gec kaldi';
      Result := LV;
    end,
    procedure(AData: TObject; AForm: TCustomForm)
    begin
      { Form coktan kapandi ve free edildi. Eski hâlde AForm SARKAN
        ISARETCI olurdu ve buraya gelinirdi. }
      LGeriCagrildi := True;
      AForm.ModalResult := mrOk;
    end,
    nil);

  T(LSonuc = mrCancel, '51 form veri gelmeden kapandi (mrCancel)');

  { Gec gelen Queue islensin diye pompala.

    CheckSynchronize SART: Application.ProcessMessages yalnizca PENCERE
    MESAJLARINI isler; TThread.Queue ile birakilan yordamlar ayri bir
    kuyruktadir ve onlari CheckSynchronize bosaltir. Yalnizca
    ProcessMessages cagirmak geri cagirimin hic tetiklenmemesine yol
    aciyordu - o zaman 52 numarali iddia da YANLIS SEBEPLE geciyordu
    (guard calistigi icin degil, kuyruk hic islenmedigi icin). }
  LBitis := GetTickCount64 + 2000;
  while GetTickCount64 < LBitis do
  begin
    Application.ProcessMessages;
    CheckSynchronize(10);
  end;

  T(not LGeriCagrildi,
    '52 gec gelen geri cagirim CAGRILMADI (eski hâlde SARKAN ISARETCI)');
  T(GVeriSilindi, '53 buna ragmen LData temizlendi (sizinti yok)');
end;

{ ================================================================== }

begin
  GOk := 0; GFail := 0;
  Application.Initialize;
  try
    KonumHesabi;
    BosDikdortgen;
    PositionOzelligi;
    CustomKonum;
    KisayolListesi;
    AksiyonCalistir;
    MenuAgaci;
    SahipsizNesneler;
    EkranaSigdir;
    ModalAsyncMutluYol;
    ModalAsyncHataYolu;
    ModalAsyncErkenKapanma;
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
