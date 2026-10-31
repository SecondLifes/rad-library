program CoreFormTest;

{$APPTYPE CONSOLE}

{
  TRadFormBase.ClientWndProc / MDIClientEdge sondasi.

  Bu davranis eskiden Core.Form (TCoreForm) icindeydi; birim silindi, tek is
  olan MDI istemci cercevesi yonetimi TRadFormBase'e tasindi. Eski test dosyasi artik var olmayan
  bir API'yi (AutoFree, _ShowMDIChild, ACmdSys) sinamaya calisiyordu ve
  derlenmiyordu; onun hâlâ gecerli olan iddialari rad_formfactory'ye tasindi.
}

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  Vcl.Controls,
  rad.core   in '..\..\..\core\rad.core.pas',
  Help.vcl   in '..\..\..\core\Help.vcl.pas';

const
  WM_MDICLIENT_FRAMECALC = $3F;
  CNISAN                 = LRESULT($5A5A5A);   // "inherited calisti mi" nisani

var
  GOk, GFail: Integer;
  GCagriSayaci: Integer;   // ClientWndProc'a kac kez girildi

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
  Flush(Output);   { cikti yonlendirildiginde tamponda kalmasin - takilirsa
                     nereye kadar gidildigi gorunur }
end;

type
  TMdiTest = class(TRadFormBase)
  public
    constructor Create(AOwner: TComponent); override;
    procedure ClientWndProc(var Message: TMessage); override;
    /// Korumali ClientWndProc'u disaridan cagirilabilir hale getirir.
    function GonderClient(AMsg: Cardinal): LRESULT;
  end;

constructor TMdiTest.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
end;

procedure TMdiTest.ClientWndProc(var Message: TMessage);
begin
  Inc(GCagriSayaci);
  inherited;
end;

function TMdiTest.GonderClient(AMsg: Cardinal): LRESULT;
var
  M: TMessage;
begin
  M.Msg := AMsg;
  M.WParam := 0;
  M.LParam := 0;
  M.Result := CNISAN;      // inherited calisirsa bu deger DEGISIR
  ClientWndProc(M);
  Result := M.Result;
end;

function IstemciStili(AForm: TMdiTest): NativeInt;
begin
  Result := GetWindowLongPtr(AForm.ClientHandle, GWL_EXSTYLE);
end;

{ ------------------------------------------------------------------ }

procedure CukurCerceve;
var
  LF: TMdiTest;
  LSonuc: LRESULT;
begin
  Writeln;
  Writeln('=== MDI istemci cukur cercevesi ===');

  LF := TMdiTest.Create(Application);
  try
    LF.FormStyle := fsMDIForm;
    LF.Show;
    Application.ProcessMessages;

    Chk(LF.ClientHandle <> 0, '01 MDI istemci penceresi olustu');

    { Stili elle GERI KOYUP dalin gercekten calistigini gorelim - formun
      dogal kurulusunda temizlenmis olmasi tek basina kanit degil. }
    SetWindowLongPtr(LF.ClientHandle, GWL_EXSTYLE,
      IstemciStili(LF) or WS_EX_CLIENTEDGE);
    Chk((IstemciStili(LF) and WS_EX_CLIENTEDGE) <> 0,
      '02 WS_EX_CLIENTEDGE elle geri kondu');

    LSonuc := LF.GonderClient(WM_MDICLIENT_FRAMECALC);
    Chk((IstemciStili(LF) and WS_EX_CLIENTEDGE) = 0,
      '03 $3F mesaji cukur kenarligi TEMIZLEDI');

    { $3F, MDICLIENT'in sinif yordamina gider (sonuc nisani ezilir) ama VCL'in
      ShowMDIClientEdge blogu atlanir. Nisan DEGISMEZSE mesaj yutulmus
      demektir: MDICLIENT'in kaydirma hesabi olur (13 numarali iddia). Cerceve
      yine de gelmemis olmali: 0 cocuklu formda VCL blogu onu geri koyardi. }
    Chk(LSonuc <> CNISAN,
      '04 $3F MDICLIENT yordamina iletildi (mesaj yutulmadi)');

    { C-03: stil zaten temizken tekrar yazip SWP_FRAMECHANGED tetiklemek
      gereksiz cerceve cizimi (titreme) demekti. }
    LSonuc := LF.GonderClient(WM_MDICLIENT_FRAMECALC);
    Chk((IstemciStili(LF) and WS_EX_CLIENTEDGE) = 0,
      '05 ikinci $3F stili bozmadi');
    Chk(LSonuc <> CNISAN,
      '06 ikinci $3F de MDICLIENT yordamina iletildi');

    { $3F DISINDAKI mesajlar her zaman inherited a gitmeli. }
    LSonuc := LF.GonderClient(WM_USER + 4242);
    Chk(LSonuc <> CNISAN,
      '07 ilgisiz mesaj da inherited a ulasti');

    { MESAJ FIRTINASI KONTROLU. Stili inherited'dan ONCE silmek MDICLIENT'in
      onu geri koymasina ve SWP_FRAMECHANGED'in yeni bir $3F dogurmasina yol
      aciyordu - sonsuz dongu. Burada birkac yuzden fazla cagri gorurse
      tasarim yine bozulmus demektir. }
    Application.ProcessMessages;
    Chk(GCagriSayaci < 300,
      Format('08 mesaj firtinasi YOK (ClientWndProc cagrisi: %d)', [GCagriSayaci]));
  finally
    LF.Free;
  end;
end;

procedure MdiOlmayanForm;
var
  LF: TMdiTest;
  LSonuc: LRESULT;
begin
  Writeln;
  Writeln('=== fsNormal formda $3F ===');

  LF := TMdiTest.Create(Application);
  try
    LF.Show;
    Application.ProcessMessages;

    Chk(LF.FormStyle = fsNormal, '09 form fsNormal');

    { ClientHandle = 0; korumasiz kod burada GetWindowLongPtr(0, ...)
      cagirirdi. Cokmemesi ve inherited a ulasmasi gerekiyor. }
    LSonuc := LF.GonderClient(WM_MDICLIENT_FRAMECALC);
    Chk(LSonuc <> CNISAN,
      '10 MDI olmayan formda $3F inherited a gitti (guard dogru)');
  finally
    LF.Free;
  end;
end;

function ScrollGorunur(AWnd: HWND; AObj: Integer): Boolean;
var
  LI: TScrollBarInfo;
begin
  FillChar(LI, SizeOf(LI), 0);
  LI.cbSize := SizeOf(LI);
  Result := GetScrollBarInfo(AWnd, AObj, LI) and
    ((LI.rgstate[0] and STATE_SYSTEM_INVISIBLE) = 0);
end;

procedure Bekle(AMs: Cardinal);
var
  LSon: UInt64;
begin
  LSon := GetTickCount64 + AMs;
  while GetTickCount64 < LSon do
  begin
    Application.ProcessMessages;
    Sleep(5);
  end;
end;

{ Gercek mesaj akisi: yukaridakiler ClientWndProc'u elle cagirir, MDICLIENT'in
  kendi $3F trafigini hic gormez. Eski "Exit" tasarimi bu bolumde 13'te
  kalirdi (kaydirma cubugu hic cikmaz). }
procedure GercekAkis;
var
  LF: TMdiTest;
  LC1, LC2: TForm;
  LOnce: Integer;
begin
  Writeln;
  Writeln('=== gercek MDI mesaj akisi ===');

  Application.CreateForm(TMdiTest, LF);
  try
    LF.SetBounds(100, 100, 900, 600);
    LF.FormStyle := fsMDIForm;
    LF.Show;
    LOnce := GCagriSayaci;
    Bekle(200);

    LC1 := TForm.CreateNew(LF);
    LC1.FormStyle := fsMDIChild;
    LC1.Show;
    LC2 := TForm.CreateNew(LF);
    LC2.FormStyle := fsMDIChild;
    LC2.Show;
    Bekle(200);
    Chk((IstemciStili(LF) and WS_EX_CLIENTEDGE) = 0,
      '11 iki cocukla cerceve yok');

    LC2.WindowState := wsMaximized;
    Bekle(200);
    LC2.WindowState := wsNormal;
    Bekle(200);
    Chk((IstemciStili(LF) and WS_EX_CLIENTEDGE) = 0,
      '12 buyut/geri al sonrasi cerceve yok (VCL burada geri koyardi)');

    LC1.SetBounds(LF.ClientWidth + 150, 20, 300, 200);
    Bekle(300);
    Chk(ScrollGorunur(LF.ClientHandle, OBJID_HSCROLL),
      '13 cocuk disari tasinca yatay kaydirma cubugu cikti (MDICLIENT calisiyor)');
    LC1.SetBounds(20, 20, 300, 200);
    Bekle(300);
    Chk(not ScrollGorunur(LF.ClientHandle, OBJID_HSCROLL),
      '14 cocuk geri gelince kaydirma cubugu kayboldu');

    LF.Tile;
    LF.Cascade;
    Bekle(200);
    Chk(GCagriSayaci - LOnce < 1000,
      Format('15 mesaj firtinasi YOK (gercek akis cagrisi: %d)', [GCagriSayaci - LOnce]));
  finally
    LF.Free;
  end;
end;

{ MDIClientEdge ayari. OnCreate'te atama = pencere yokken atama: bayrak ilk $3F'de
  okunur, setter'in SendMessage dali calismaz. }
procedure KenarlikAyari;
var
  LF: TMdiTest;
  LC: TForm;

  function Kenarlik: Boolean;
  begin
    Result := (IstemciStili(LF) and WS_EX_CLIENTEDGE) <> 0;
  end;

begin
  Writeln;
  Writeln('=== MDIClientEdge ayari ===');

  Application.CreateForm(TMdiTest, LF);
  try
    Chk(not LF.MDIClientEdge, '16 varsayilan MDIClientEdge = False');
    LF.MDIClientEdge := True;     // OnCreate'teki gibi: pencere ve FormStyle yok
    LF.SetBounds(100, 100, 900, 600);
    LF.FormStyle := fsMDIForm;
    LF.Show;
    Bekle(300);
    Chk(Kenarlik, '17 True, pencere yokken atandi: cocuksuz formda VCL kenarligi var');

    LC := TForm.CreateNew(LF);
    LC.FormStyle := fsMDIChild;
    LC.Show;
    LC.WindowState := wsMaximized;
    Bekle(300);
    Chk(not Kenarlik, '18 True: buyutulmus cocukta VCL kenarligi kaldirir');
    LC.WindowState := wsNormal;
    Bekle(300);
    Chk(Kenarlik, '19 True: cocuk geri alininca VCL kenarligi geri koyar');

    LF.MDIClientEdge := False;    // calisma zamaninda: SendMessage dali
    Chk(not Kenarlik, '20 True->False hemen uygulandi (mesaj beklenmedi)');
    Bekle(300);
    Chk(not Kenarlik, '21 False kalici (VCL geri koymadi)');

    LF.MDIClientEdge := True;
    Chk(Kenarlik, '22 False->True hemen uygulandi');
  finally
    LF.Free;
  end;
end;

begin
  GOk := 0;
  GFail := 0;
  GCagriSayaci := 0;

  { BEKCI. Bu testin ilk hâli mesaj firtinasina girip %100 CPU'da asili
    kaldi (once stil siliniyor, sonra inherited onu geri koyuyordu).
    Bir daha oturumu kilitlemesin diye sabit sureli sert cikis. }
  TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep(30000);
      Writeln;
      Writeln('  [BEKCI] 30 sn doldu - takilma var. ClientWndProc cagrisi: ',
        GCagriSayaci);
      Flush(Output);
      Halt(3);
    end).Start;

  Application.Initialize;
  try
    CukurCerceve;
    MdiOlmayanForm;
    GercekAkis;
    KenarlikAyari;
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
