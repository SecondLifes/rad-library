program UniAsyncTest;

{$APPTYPE CONSOLE}

{
  _ConnectTestAsync davranis sondasi.

  Canli bir PostgreSQL sunucusu GEREKMEZ - olculen sey baglantinin kurulmasi
  degil, fonksiyonun SOZLESMESI: cagirani bloke etmemesi, hatayi OnError'a
  sebebiyle birlikte tasimasi ve geri cagirimlarin ANA THREAD'de kosmasi.

  Hedef 192.0.2.1 (RFC 5737 TEST-NET-1) - tanim geregi yonlendirilemez,
  dolayisiyla her makinede ayni sonucu verir.
}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  Uni,
  UniProvider,
  PostgreSQLUniProvider,
  rad.thread    in '..\..\..\core\rad.thread.pas',
  Help.uni      in '..\..\..\core\Help.uni.pas';

var
  GOk, GFail: Integer;

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
  Flush(Output);
end;

var
  GBasariliCagrildi : Boolean;
  GHataCagrildi     : Boolean;
  GSonundaCagrildi  : Boolean;
  GHataMesaji       : string;
  GHataThreadID     : TThreadID;
  GSonThreadID      : TThreadID;
  GBitti            : Boolean;

procedure Pompala(AMaxMs: Cardinal);
var
  LBitis: UInt64;
begin
  LBitis := GetTickCount64 + AMaxMs;
  while (not GBitti) and (GetTickCount64 < LBitis) do
  begin
    Application.ProcessMessages;
    { Application.ProcessMessages TEK BASINA yetmez: TThread.Queue/ForceQueue
      kuyrugunu bosaltan sey CheckSynchronize'dir. Bu oturumda daha once bir
      test tam bu yuzden YANLIS SEBEPLE gecmisti. }
    CheckSynchronize(10);
    Sleep(5);
  end;
end;

procedure Sozlesme;
var
  cn    : TUniConnection;
  gorev : TRadTask;
  LBas, LBaslatmaSuresi: UInt64;
begin
  Writeln;
  Writeln('=== _ConnectTestAsync sozlesmesi ===');

  cn := TUniConnection.Create(nil);
  try
    cn.ProviderName := 'PostgreSQL';
    cn.Server       := '192.0.2.1';      // yonlendirilemez
    cn.Port         := 5432;
    cn.Username     := 'yok';
    cn.Password     := 'yok';
    cn.Database     := 'yok';
    cn.LoginPrompt  := False;
    cn.SpecificOptions.Values['ConnectionTimeout'] := '3';

    gorev := cn._ConnectTestAsync;
    Chk(gorev <> nil, '01 gorev nesnesi dondu');
    Chk(not gorev.IsRunning, '02 gorev BASLATILMAMIS dondu (zincirlenebilir)');

    gorev
      .OnSuccess(procedure(t: TRadTask)
        begin
          GBasariliCagrildi := True;
        end)
      .OnError(procedure(t: TRadTask)
        begin
          GHataCagrildi := True;
          GHataMesaji   := t.ErrorMsg;
          GHataThreadID := TThread.CurrentThread.ThreadID;
        end)
      .OnFinally(procedure(t: TRadTask)
        begin
          GSonundaCagrildi := True;
          GSonThreadID     := TThread.CurrentThread.ThreadID;
          GBitti           := True;
        end);

    LBas := GetTickCount64;
    gorev.Start;
    LBaslatmaSuresi := GetTickCount64 - LBas;

    { ASIL IDDIA: Start ANINDA doner. Eski _ConnectTest burada baglanti
      denemesi bitene kadar (varsayilan 15 sn) cagirani tutardi. }
    Chk(LBaslatmaSuresi < 250,
      Format('03 Start ANINDA dondu (%d ms) - UI bloke DEGIL', [LBaslatmaSuresi]));
    Chk(not GSonundaCagrildi,
      '04 Start dondugunde gorev HENUZ bitmemisti (gercekten asenkron)');

    Pompala(40000);

    Chk(GBitti, '05 gorev makul surede tamamlandi');
    Chk(GHataCagrildi, '06 yonlendirilemez adres -> OnError tetiklendi');
    Chk(not GBasariliCagrildi, '07 OnSuccess tetiklenMEDI');
    Chk(GHataMesaji <> '', '08 hata SEBEBI tasindi: ' + Copy(GHataMesaji, 1, 70));
    Chk(GSonundaCagrildi, '09 OnFinally tetiklendi');
    Chk(GHataThreadID = MainThreadID,
      '10 OnError ANA THREAD de kostu (VCL e dokunmak guvenli)');
    Chk(GSonThreadID = MainThreadID,
      '11 OnFinally ANA THREAD de kostu');
    Chk(not cn.Connected,
      '12 kaynak baglanti ETKILENMEDI (bu bir TEST, baglanma degil)');
  finally
    cn.Free;
  end;
end;

begin
  GOk := 0;
  GFail := 0;

  TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep(60000);
      Writeln;
      Writeln('  [BEKCI] 60 sn doldu - takilma var.');
      Flush(Output);
      Halt(3);
    end).Start;

  Application.Initialize;
  try
    Sozlesme;
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
