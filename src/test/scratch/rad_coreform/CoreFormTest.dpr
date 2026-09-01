program CoreFormTest;

{$APPTYPE CONSOLE}

{
  TCoreForm.ClientWndProc sondasi.

  Core.Form sadelestirildikten sonra bu birimde TEK is kaldi: MDI istemci
  alaninin cukur cercevesini kaldirmak. Eski test dosyasi artik var olmayan
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
  Help.vcl   in '..\..\..\core\Help.vcl.pas',
  Core.Form  in '..\..\..\share\Core.Form.pas';

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
  TMdiTest = class(TCoreForm)
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

    { $3F BILEREK TUKETILIR - nisan degeri DEGISMEMELI.

      Bu iddia bir "eksigi" degil, KASITLI bir tasarimi korur. Mesaji
      inherited'a iletmeyi denedik: MDICLIENT kenarligi geri koyuyor, biz
      siliyoruz, SWP_FRAMECHANGED yeni $3F doguruyor - 30 saniyede 796.240
      cagri, kilitli surec. Bu satir kirmiziya donerse birisi o degisikligi
      tekrar denemis demektir; 08 numarali iddia da onunla birlikte duser. }
    Chk(LSonuc = CNISAN,
      '04 $3F tuketildi, inherited a iletilmedi (dongu kirici)');

    { C-03: stil zaten temizken tekrar yazip SWP_FRAMECHANGED tetiklemek
      gereksiz cerceve cizimi (titreme) demekti. }
    LSonuc := LF.GonderClient(WM_MDICLIENT_FRAMECALC);
    Chk((IstemciStili(LF) and WS_EX_CLIENTEDGE) = 0,
      '05 ikinci $3F stili bozmadi');
    Chk(LSonuc = CNISAN,
      '06 ikinci $3F de tuketildi');

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
