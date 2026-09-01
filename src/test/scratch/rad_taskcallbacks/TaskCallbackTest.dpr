program TaskCallbackTest;

{$APPTYPE CONSOLE}

{
  Soru: "Error aldiginda OnSuccess de cagriliyor olabilir mi?"

  Cevap kodu okuyarak degil SAYARAK veriliyor. Her senaryoda her geri
  cagirimin kac kez tetiklendigi tek tek sayiliyor.

  TRadTask.Create varsayilanlari: FRepeatCount=1, FRetryCount=0.
}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  Vcl.Forms,
  rad.core   in '..\..\..\core\rad.core.pas',
  rad.thread in '..\..\..\core\rad.thread.pas';

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

type
  TSayac = record
    Basari, Hata, Iptal, ZamanAsimi, Sonunda: Integer;
    procedure Sifirla;
    function Ozet: string;
  end;

procedure TSayac.Sifirla;
begin
  Basari := 0; Hata := 0; Iptal := 0; ZamanAsimi := 0; Sonunda := 0;
end;

function TSayac.Ozet: string;
begin
  Result := Format('basari=%d hata=%d iptal=%d zamanasimi=%d sonunda=%d',
    [Basari, Hata, Iptal, ZamanAsimi, Sonunda]);
end;

var
  GS: TSayac;

{ Sayaclari kuran ortak zincir. Wait kullaniyoruz ki olcum deterministik olsun. }
procedure Kos(AProc: TRadTaskProc; AAyar: TProc<TRadTask>);
var
  t: TRadTask;
begin
  GS.Sifirla;
  t := TRadTask.Create(AProc);
  t.OnSuccess(procedure(x: TRadTask) begin Inc(GS.Basari)     end)
   .OnError  (procedure(x: TRadTask) begin Inc(GS.Hata)       end)
   .OnCancel (procedure(x: TRadTask) begin Inc(GS.Iptal)      end)
   .OnTimeout(procedure(x: TRadTask) begin Inc(GS.ZamanAsimi) end)
   .OnFinally(procedure(x: TRadTask) begin Inc(GS.Sonunda)    end);
  if Assigned(AAyar) then
    AAyar(t);
  t.Wait;
end;

var
  GDeneme: Integer;

{ ------------------------------------------------------------------ }

procedure VarsayilanHata;
begin
  Writeln;
  Writeln('=== 1) Varsayilan gorev, HER ZAMAN hata ===');
  Kos(procedure(t: TRadTask)
      begin
        raise Exception.Create('patladi');
      end, nil);
  Writeln('  ', GS.Ozet);
  Chk(GS.Hata = 1,   '01 OnError TAM 1 kez');
  Chk(GS.Basari = 0, '02 OnSuccess HIC cagrilmadi');
  Chk(GS.Sonunda = 1,'03 OnFinally 1 kez');
end;

procedure VarsayilanBasari;
begin
  Writeln;
  Writeln('=== 2) Varsayilan gorev, basarili ===');
  Kos(procedure(t: TRadTask)
      begin
        // is yok
      end, nil);
  Writeln('  ', GS.Ozet);
  Chk(GS.Basari = 1, '04 OnSuccess 1 kez');
  Chk(GS.Hata = 0,   '05 OnError hic');
end;

procedure RetryBasarisiz;
begin
  Writeln;
  Writeln('=== 3) Retry(2), her denemede hata ===');
  Kos(procedure(t: TRadTask)
      begin
        raise Exception.Create('yine patladi');
      end,
      procedure(t: TRadTask) begin t.SetRetry(2, 10) end);
  Writeln('  ', GS.Ozet);
  Chk(GS.Hata = 1,   '06 tukenen retry sonrasi OnError TAM 1 kez');
  Chk(GS.Basari = 0, '07 OnSuccess hic');
end;

procedure RetrySonraBasari;
begin
  Writeln;
  Writeln('=== 4) Retry(2), ilk deneme hata, ikinci basarili ===');
  GDeneme := 0;
  Kos(procedure(t: TRadTask)
      begin
        Inc(GDeneme);
        if GDeneme = 1 then
          raise Exception.Create('ilk deneme');
      end,
      procedure(t: TRadTask) begin t.SetRetry(2, 10) end);
  Writeln('  ', GS.Ozet);
  Chk(GS.Basari = 1, '08 retry basarili -> OnSuccess 1 kez');
  Chk(GS.Hata = 0,   '09 retry ICINDE olan hata OnError''e YANSIMADI');
end;

procedure RepeatBasarisiz;
begin
  Writeln;
  Writeln('=== 5) SetRepeat(3), her turda hata ===');
  Kos(procedure(t: TRadTask)
      begin
        raise Exception.Create('her turda');
      end,
      procedure(t: TRadTask) begin t.SetRepeat(3, 0) end);
  Writeln('  ', GS.Ozet);
  Chk(GS.Hata = 3,   '10 OnError HER TUR icin ayri tetiklendi (3 kez)');
  Chk(GS.Basari = 0, '11 OnSuccess hic');
  Chk(GS.Sonunda = 1,'12 OnFinally yine TEK kez');
end;

procedure RepeatKarisik;
begin
  Writeln;
  Writeln('=== 6) SetRepeat(3), ilk tur hata, sonrakiler basarili ===');
  GDeneme := 0;
  Kos(procedure(t: TRadTask)
      begin
        Inc(GDeneme);
        if GDeneme = 1 then
          raise Exception.Create('sadece ilk tur');
      end,
      procedure(t: TRadTask) begin t.SetRepeat(3, 0) end);
  Writeln('  ', GS.Ozet);

  { ISTE KRITIK SENARYO. OnError tur icinde ANINDA tetiklenir; OnSuccess ise
    TUM turlar bittikten SONRA, FSuccessInt bayragina bakilarak tetiklenir.
    Son tur basarili oldugu icin bayrak 1 kalir -> IKISI DE cagrilir. }
  Chk(GS.Hata = 1,   '13 ilk turun hatasi OnError uretti');
  Chk(GS.Basari = 1, '14 ve OnSuccess DE cagrildi -> IKISI BIRDEN');
end;

begin
  GOk := 0;
  GFail := 0;

  TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep(60000);
      Writeln;
      Writeln('  [BEKCI] 60 sn doldu.');
      Flush(Output);
      Halt(3);
    end).Start;

  Application.Initialize;
  try
    VarsayilanHata;
    VarsayilanBasari;
    RetryBasarisiz;
    RetrySonraBasari;
    RepeatBasarisiz;
    RepeatKarisik;
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
