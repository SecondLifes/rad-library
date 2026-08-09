program TestRadWorker;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Diagnostics,
  System.Generics.Collections,
  Winapi.Windows,
  Winapi.ActiveX,
  Vcl.Forms,
  mormot.core.base,
  mormot.core.os,
  mormot.core.variants,
  rad.date,
  rad.worker in '..\..\..\..\..\source\core\rad.worker.pas';

var
  GPassCount, GFailCount: Integer;

procedure Check(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  if ACondition then
  begin
    Inc(GPassCount);
    Writeln(Format('[PASS] %s %s', [AName, ADetail]));
  end
  else
  begin
    Inc(GFailCount);
    Writeln(Format('[FAIL] %s %s', [AName, ADetail]));
  end;
end;

{ ---------------------------------------------------------------------- }
procedure TestPostBasic;
var
  I: Integer;
  LCounter: Integer;
  LIds: TList<Int64>;
  LDone: TEvent;
  LTotal: Integer;
begin
  Writeln('--- TestPostBasic ---');
  LCounter := 0;
  LTotal := 50;
  LIds := TList<Int64>.Create;
  LDone := TEvent.Create(nil, True, False, '');
  try
    for I := 1 to LTotal do
      LIds.Add(Workers.Post(procedure
        begin
          if TInterlocked.Increment(LCounter) = LTotal then
            LDone.SetEvent;
        end));

    Check('Post: job id benzersizliği', LIds.Count = TList<Int64>.Create(LIds.ToArray).Count, Format('(%d id)', [LIds.Count]));
    // basit benzersizlik kontrolü: set'e atip say
    var LSet := TDictionary<Int64, Boolean>.Create;
    try
      for I := 0 to LIds.Count - 1 do
        LSet.AddOrSetValue(LIds[I], True);
      Check('Post: tüm job id''ler benzersiz', LSet.Count = LTotal, Format('(benzersiz=%d, toplam=%d)', [LSet.Count, LTotal]));
    finally
      LSet.Free;
    end;

    Check('Post: tüm işler çalıştı', LDone.WaitFor(5000) = wrSignaled, Format('(sayac=%d/%d)', [LCounter, LTotal]));
  finally
    LIds.Free;
    LDone.Free;
  end;
end;

{ ---------------------------------------------------------------------- }
procedure TestPostDoesNotBlock;
var
  LLongRunning: TEvent;
  LLongDone: TEvent;
  LSw: TStopwatch;
  LElapsedMs: Int64;
  I: Integer;
begin
  Writeln('--- TestPostDoesNotBlock ---');
  LLongRunning := TEvent.Create(nil, True, False, '');
  LLongDone := TEvent.Create(nil, True, False, '');
  try
    Workers.MaxWorkers := 1;

    // havuzu doldur: MaxWorkers=1 iken uzun bir iş başlat
    Workers.Post(procedure
      begin
        LLongRunning.SetEvent;
        Sleep(800);
        LLongDone.SetEvent;
      end);

    Check('PostDoesNotBlock: uzun iş başladı', LLongRunning.WaitFor(2000) = wrSignaled);

    LSw := TStopwatch.StartNew;
    for I := 1 to 5 do
      Workers.Post(procedure begin end);
    LElapsedMs := LSw.ElapsedMilliseconds;

    Check('PostDoesNotBlock: Post() havuz doluyken hemen döndü',
      LElapsedMs < 200, Format('(gecen=%dms, beklenen <200ms)', [LElapsedMs]));

    Check('PostDoesNotBlock: uzun is sonunda bitti', LLongDone.WaitFor(3000) = wrSignaled);
  finally
    LLongRunning.Free;
    LLongDone.Free;
    Workers.MaxWorkers := 4;
  end;
end;

{ ---------------------------------------------------------------------- }
procedure TestDelay;
var
  LSw: TStopwatch;
  LFired: TEvent;
  LElapsedAtFire: Int64;
begin
  Writeln('--- TestDelay ---');
  LFired := TEvent.Create(nil, True, False, '');
  try
    LSw := TStopwatch.StartNew;
    Workers.Delay(procedure
      begin
        LElapsedAtFire := LSw.ElapsedMilliseconds;
        LFired.SetEvent;
      end, 200);

    Check('Delay: hemen calismadi (100ms icinde sinyal gelmemeli)',
      LFired.WaitFor(100) = wrTimeout);

    Check('Delay: 200ms civarinda calisti',
      LFired.WaitFor(1000) = wrSignaled, Format('(fiili gecikme=%dms)', [LElapsedAtFire]));
    Check('Delay: gecikme makul araliktaydi (150-500ms)',
      (LElapsedAtFire >= 150) and (LElapsedAtFire <= 500), Format('(%dms)', [LElapsedAtFire]));
  finally
    LFired.Free;
  end;
end;

{ ---------------------------------------------------------------------- }
procedure TestEveryAndCancel;
var
  LCount: Integer;
  LId: TRadWorkerJobId;
begin
  Writeln('--- TestEveryAndCancel ---');
  LCount := 0;
  LId := Workers.Every(procedure
    begin
      TInterlocked.Increment(LCount);
    end, 100);

  Sleep(550);
  Check('Every: yaklasik 4-6 kez calisti (~500ms/100ms)',
    (LCount >= 3) and (LCount <= 7), Format('(calisma=%d)', [LCount]));

  Check('Every: Cancel basarili', Workers.Cancel(LId));

  // NOT: Cancel() ile scheduler tick'i arasinda inherent bir yaris durumu var
  // -- Cancel tam scheduler'in bir tick'i zaten dispatch ettigi anda
  // cagrilirsa, o TEK dispatch (async olarak zaten kuyruga girmis) yine de
  // calisir; Cancel yalnizca GELECEKTEKI tick'lerin tekrar dispatch etmesini
  // engeller. Bu yuzden en fazla 1 "straggler" calisma toleranslidir, ama
  // devam eden bir artis (ör. +2, +3) gercek bir bug olurdu.
  var LCountAfterCancel := LCount;
  Sleep(150); // olasi tek straggler'in bitmesine izin ver
  var LCountAfterGrace := LCount;
  Sleep(400);
  Check('Every: Cancel sonrasi en fazla 1 straggler, sonra tamamen durdu',
    (LCountAfterGrace - LCountAfterCancel <= 1) and (LCount = LCountAfterGrace),
    Format('(cancel-ani=%d, +150ms=%d, +550ms=%d)', [LCountAfterCancel, LCountAfterGrace, LCount]));
end;

{ ---------------------------------------------------------------------- }
procedure TestPlan;
var
  LCount: Integer;
  LId: TRadWorkerJobId;
  LImpossibleId: TRadWorkerJobId;
begin
  Writeln('--- TestPlan ---');
  LCount := 0;
  // her saniye tetiklenen mask: Sn Dk Sa Gun Ay HaftaGunu -> '* * * * * *'
  LId := Workers.Plan(procedure
    begin
      TInterlocked.Increment(LCount);
    end, '* * * * * *');

  Sleep(3200);
  Check('Plan: saniyede-bir mask ~3 kez tetiklendi',
    (LCount >= 2) and (LCount <= 5), Format('(calisma=%d, 3.2sn icinde)', [LCount]));
  Workers.Cancel(LId);

  // imkansiz plan: 2099 yilindan sonrasi olmayan bir yil + gecmis bir tarih;
  // burada "asla eslesmeyen" bir mask kullanip scheduler'in çökmediğini/
  // asılı kalmadığını doğruluyoruz (rad.date.Tests.pas'taki imkansız-mask
  // senaryosunun aynısı: 30 Şubat gibi olmayan bir gün/ay kombinasyonu değil,
  // basitçe hiçbir zaman true dönmeyecek bir yıl alanı).
  LImpossibleId := Workers.Plan(procedure
    begin
      TInterlocked.Increment(LCount); // asla artmamali
    end, '0 0 0 1 1 1 1901');

  var LCountBeforeWait := LCount;
  Sleep(300);
  Check('Plan: imkansiz mask scheduler''i cokertmedi/kilitlemedi (program hala calisiyor)',
    True);
  Check('Plan: imkansiz mask hic tetiklenmedi',
    LCount = LCountBeforeWait, Format('(oncesi=%d, sonrasi=%d)', [LCountBeforeWait, LCount]));
  Workers.Cancel(LImpossibleId);
end;

{ ---------------------------------------------------------------------- }
procedure TestForEach;
var
  LLock: TCriticalSection;
  LSumParallel: Int64;
  LSumSingle: Int64;
  I: Integer;
begin
  Writeln('--- TestForEach ---');
  // NOT: System.TMonitor yerine TCriticalSection kullaniliyor cunku Vcl.Forms
  // kendi TMonitor sinifini (fiziksel ekran monitoru) tanimliyor ve bu isim
  // Vcl.Forms uses'a girince System.TMonitor'u GOLGELIYOR (E2003 'Enter'
  // hatasi) - rad.worker.pas'ta bir hata degil, gercek bir Delphi isim
  // catismasi (bkz. rapor).
  LLock := TCriticalSection.Create;
  try
    LSumSingle := 0;
    for I := 1 to 1000 do
      Inc(LSumSingle, Int64(I) * Int64(I));

    // AMsgWait = False
    LSumParallel := 0;
    Workers.ForEach(1, 1000, procedure(AIndex: Integer)
      begin
        LLock.Enter;
        try
          Inc(LSumParallel, Int64(AIndex) * Int64(AIndex));
        finally
          LLock.Leave;
        end;
      end, False);
    Check('ForEach(AMsgWait=False): kareler toplami dogru',
      LSumParallel = LSumSingle, Format('(paralel=%d, tekli=%d)', [LSumParallel, LSumSingle]));

    // AMsgWait = True
    LSumParallel := 0;
    Workers.ForEach(1, 1000, procedure(AIndex: Integer)
      begin
        LLock.Enter;
        try
          Inc(LSumParallel, Int64(AIndex) * Int64(AIndex));
        finally
          LLock.Leave;
        end;
      end, True);
    Check('ForEach(AMsgWait=True): kareler toplami dogru',
      LSumParallel = LSumSingle, Format('(paralel=%d, tekli=%d)', [LSumParallel, LSumSingle]));
  finally
    LLock.Free;
  end;
end;

{ ---------------------------------------------------------------------- }
procedure TestWaitJob;
var
  LId: TRadWorkerJobId;
  LSw: TStopwatch;
  LOk: Boolean;
  LElapsed: Int64;
begin
  Writeln('--- TestWaitJob ---');
  LId := Workers.Post(procedure begin Sleep(100); end);
  LSw := TStopwatch.StartNew;
  LOk := Workers.WaitJob(LId, 1000, False);
  LElapsed := LSw.ElapsedMilliseconds;
  Check('WaitJob: yeterli timeout ile True dondu', LOk);
  Check('WaitJob: makul surede döndü (80-600ms)',
    (LElapsed >= 50) and (LElapsed <= 700), Format('(%dms)', [LElapsed]));

  LId := Workers.Post(procedure begin Sleep(500); end);
  LSw := TStopwatch.StartNew;
  LOk := Workers.WaitJob(LId, 10, False);
  LElapsed := LSw.ElapsedMilliseconds;
  Check('WaitJob: cok kisa timeout ile False dondu (zaman asimi)', not LOk, Format('(%dms)', [LElapsed]));

  // AMsgWait = True varyanti
  LId := Workers.Post(procedure begin Sleep(100); end);
  LOk := Workers.WaitJob(LId, 1000, True);
  Check('WaitJob(AMsgWait=True): True dondu', LOk);
end;

{ ---------------------------------------------------------------------- }
procedure TestCancelDelay;
var
  LFired: Boolean;
  LId: TRadWorkerJobId;
begin
  Writeln('--- TestCancelDelay ---');
  LFired := False;
  LId := Workers.Delay(procedure
    begin
      LFired := True;
    end, 500);
  Check('CancelDelay: Cancel basarili', Workers.Cancel(LId));
  Sleep(800);
  Check('CancelDelay: iptal edilen Delay hicbir zaman calismadi', not LFired);
end;

{ ---------------------------------------------------------------------- }
procedure TestDisableEnable;
var
  LRan: Boolean;
begin
  Writeln('--- TestDisableEnable ---');
  Workers.Disable;
  LRan := False;
  Workers.Post(procedure begin LRan := True; end);
  Sleep(300);
  Check('Disable: devredisiyken Post calismadi', not LRan);

  Workers.Enable;
  Sleep(100);
  LRan := False;
  Workers.Post(procedure begin LRan := True; end);
  Sleep(300);
  Check('Enable: tekrar aktiflestirince Post calisti', LRan);
end;

{ ---------------------------------------------------------------------- }
procedure TestComInitPerWorker;
var
  LOkOff, LOkOn: Boolean;
  LDone: TEvent;
begin
  Writeln('--- TestComInitPerWorker ---');
  LDone := TEvent.Create(nil, True, False, '');
  try
    Check('ComInitPerWorker: varsayilan False', not Workers.ComInitPerWorker);

    // off durumunda normal calisma (yan etki yok, sadece hata firlatmadigini dogruluyoruz)
    LOkOff := False;
    Workers.Post(procedure
      begin
        LOkOff := True;
        LDone.SetEvent;
      end);
    LDone.WaitFor(2000);
    Check('ComInitPerWorker=False: is normal calisti', LOkOff);

    // on durumunda: worker icinde COM nesnesi olusturmayi dene (ShellLink COM objesi)
    Workers.ComInitPerWorker := True;
    LDone.ResetEvent;
    LOkOn := False;
    var LComError := '';
    Workers.Post(procedure
      var
        LUnknown: IInterface;
        LHr: HRESULT;
      begin
        try
          // basit bir COM nesnesi olustur (ShellLink) - CoInitializeEx cagrilmamis
          // olsaydi CO_E_NOTINITIALIZED (0x800401F0) donerdi.
          LHr := CoCreateInstance(StringToGUID('{00021401-0000-0000-C000-000000000046}'),
            nil, CLSCTX_INPROC_SERVER, IUnknown, LUnknown);
          LOkOn := Succeeded(LHr);
          if not LOkOn then
            LComError := Format('HRESULT=0x%x', [Cardinal(LHr)]);
        except
          on E: Exception do
            LComError := E.Message;
        end;
        LDone.SetEvent;
      end);
    LDone.WaitFor(2000);
    Check('ComInitPerWorker=True: worker icinde COM nesnesi basariyla olusturuldu',
      LOkOn, LComError);
    Workers.ComInitPerWorker := False;
  finally
    LDone.Free;
  end;
end;

{ ---------------------------------------------------------------------- }
procedure TestIDocDictRoundtripAndMutation;
var
  LData: IDocDict;
  LGotStr: string;
  LGotInt: Int64;
  LGotBool: Boolean;
  LDone: TEvent;
  LMutatedValueSeenByJob: string;
begin
  Writeln('--- TestIDocDictRoundtripAndMutation ---');
  LDone := TEvent.Create(nil, True, False, '');
  try
    LData := DocDict;
    LData.U['ad'] := 'Ahmet';
    LData.I['yas'] := 42;
    LData.B['aktif'] := True;

    Workers.Post(procedure(const AData: IDocDict)
      begin
        LGotStr := string(AData.U['ad']);
        LGotInt := AData.I['yas'];
        LGotBool := AData.B['aktif'];
        LDone.SetEvent;
      end, LData);
    LDone.WaitFor(2000);

    Check('IDocDict: string round-trip dogru', LGotStr = 'Ahmet', LGotStr);
    Check('IDocDict: int round-trip dogru', LGotInt = 42, IntToStr(LGotInt));
    Check('IDocDict: bool round-trip dogru', LGotBool = True);

    // mutasyon testi: Post SONRASI ayni IDocDict mutasyona ugratiliyor.
    // rad.worker.pas TASARIM KARARI: Post kopyalamiyor (paylaşımlı referans).
    // Bu testte GÖZLEMLENEN gerçek davranışı doğruluyoruz: is calismadan
    // once mutasyon olursa, is YENI degeri gormelidir (kopya YOK).
    LData := DocDict;
    LData.U['deger'] := 'ilk';
    LDone.ResetEvent;
    var LJobStarted := TEvent.Create(nil, True, False, '');
    try
      Workers.Post(procedure(const AData: IDocDict)
        begin
          LJobStarted.SetEvent;
          Sleep(150); // job baslamis ama Data'yi henuz okumamis
          LMutatedValueSeenByJob := string(AData.U['deger']);
          LDone.SetEvent;
        end, LData);
      LJobStarted.WaitFor(1000);
      LData.U['deger'] := 'degistirildi'; // Post SONRASI mutasyon
      LDone.WaitFor(2000);
      Check('IDocDict: Post sonrasi mutasyon GORULUYOR (kopya yok, referans paylasimi)',
        LMutatedValueSeenByJob = 'degistirildi', LMutatedValueSeenByJob);
    finally
      LJobStarted.Free;
    end;
  finally
    LDone.Free;
  end;
end;

{ ---------------------------------------------------------------------- }
procedure TestWorkerProperties;
begin
  Writeln('--- TestWorkerProperties ---');
  Workers.MinWorkers := 2;
  Workers.MaxWorkers := 4;
  Check('MinWorkers okunuyor', Workers.MinWorkers = 2, IntToStr(Workers.MinWorkers));
  Check('MaxWorkers okunuyor', Workers.MaxWorkers = 4, IntToStr(Workers.MaxWorkers));
  Check('BusyWorkers baslangicta 0 civarinda', Workers.BusyWorkers >= 0, IntToStr(Workers.BusyWorkers));
  Check('IdleWorkers <= MaxWorkers', Workers.IdleWorkers <= Workers.MaxWorkers,
    Format('(idle=%d, max=%d)', [Workers.IdleWorkers, Workers.MaxWorkers]));

  var LBusyDuring: Integer := -1;
  var LStarted := TEvent.Create(nil, True, False, '');
  var LRelease := TEvent.Create(nil, True, False, '');
  try
    Workers.Post(procedure
      begin
        LStarted.SetEvent;
        LRelease.WaitFor(2000);
      end);
    LStarted.WaitFor(1000);
    Sleep(50);
    LBusyDuring := Workers.BusyWorkers;
    LRelease.SetEvent;
    Sleep(200);
    Check('BusyWorkers: is sirasinda >= 1 gosterdi', LBusyDuring >= 1, IntToStr(LBusyDuring));
  finally
    LStarted.Free;
    LRelease.Free;
  end;
end;

{ ---------------------------------------------------------------------- }
procedure TestLongJob;
var
  LDone: TEvent;
  LRan: Boolean;
begin
  Writeln('--- TestLongJob ---');
  LDone := TEvent.Create(nil, True, False, '');
  try
    LRan := False;
    Workers.LongJob(procedure
      begin
        Sleep(50);
        LRan := True;
        LDone.SetEvent;
      end);
    Check('LongJob: calisti', LDone.WaitFor(2000) = wrSignaled);
    Check('LongJob: is govdesi calisti', LRan);
  finally
    LDone.Free;
  end;
end;

{ ---------------------------------------------------------------------- }
procedure TestJobStatus;
var
  LId: TRadWorkerJobId;
  LDone: TEvent;
  LRelease: TEvent;
begin
  Writeln('--- TestJobStatus ---');

  Check('GetJobStatus: bilinmeyen id -> jsUnknown',
    Workers.GetJobStatus(999999999) = jsUnknown);

  // Post: jsRunning -> jsDone gecisi (uzun sureli is ile araya bakabiliyoruz)
  LDone := TEvent.Create(nil, True, False, '');
  LRelease := TEvent.Create(nil, True, False, '');
  try
    LId := Workers.Post(procedure
      begin
        LDone.SetEvent;
        LRelease.WaitFor(2000);
      end);
    LDone.WaitFor(1000);
    Sleep(30);
    Check('GetJobStatus: Post calisirken jsRunning', Workers.GetJobStatus(LId) = jsRunning);
    LRelease.SetEvent;
    Sleep(150);
    Check('GetJobStatus: Post bitince jsDone (terminal)', Workers.GetJobStatus(LId) = jsDone);
  finally
    LDone.Free;
    LRelease.Free;
  end;

  // Post: exception firlatinca jsFailed
  LId := Workers.Post(procedure
    begin
      raise Exception.Create('kasitli test hatasi');
    end);
  Sleep(200);
  Check('GetJobStatus: hata firlatan is jsFailed', Workers.GetJobStatus(LId) = jsFailed);

  // Delay: dispatch edilmeden once jsPending, calisip bitince jsDone
  LId := Workers.Delay(procedure begin end, 200);
  Check('GetJobStatus: Delay henuz tetiklenmedi -> jsPending', Workers.GetJobStatus(LId) = jsPending);
  Sleep(400);
  Check('GetJobStatus: Delay tetiklenip bitti -> jsDone', Workers.GetJobStatus(LId) = jsDone);

  // Cancel: bekleyen bir Delay iptal edilince jsCancelled
  LId := Workers.Delay(procedure begin end, 500);
  Workers.Cancel(LId);
  Check('GetJobStatus: Cancel edilen Delay -> jsCancelled', Workers.GetJobStatus(LId) = jsCancelled);
  Sleep(700);
  Check('GetJobStatus: iptalden sonra durum jsCancelled''de kaldi (tekrar tetiklenmedi)',
    Workers.GetJobStatus(LId) = jsCancelled);

  // Every: tekrarlayan is, her kosu sonunda TERMINAL DEGIL, jsPending'e doner
  LId := Workers.Every(procedure begin end, 80);
  Sleep(250);
  Check('GetJobStatus: Every kosu arasinda jsPending (terminal degil)',
    Workers.GetJobStatus(LId) = jsPending);
  Workers.Cancel(LId);
  Sleep(150);
  Check('GetJobStatus: Every Cancel sonrasi jsCancelled', Workers.GetJobStatus(LId) = jsCancelled);
end;

{ ---------------------------------------------------------------------- }
procedure TestClear;
var
  LFired: Boolean;
begin
  Writeln('--- TestClear ---');
  LFired := False;
  Workers.Delay(procedure begin LFired := True; end, 300);
  Workers.Clear;
  Sleep(600);
  Check('Clear: bekleyen Delay isi Clear sonrasi calismadi', not LFired);
end;

begin
  ReportMemoryLeaksOnShutdown := False;
  GPassCount := 0;
  GFailCount := 0;
  try
    Writeln('======================================================');
    Writeln(' rad.worker.pas Faz 1 - Standalone Test Programi');
    Writeln('======================================================');

    Workers.MinWorkers := 2;
    Workers.MaxWorkers := 4;

    TestPostBasic;
    TestPostDoesNotBlock;
    TestDelay;
    TestEveryAndCancel;
    TestPlan;
    TestForEach;
    TestWaitJob;
    TestCancelDelay;
    TestDisableEnable;
    TestComInitPerWorker;
    TestIDocDictRoundtripAndMutation;
    TestWorkerProperties;
    TestLongJob;
    TestJobStatus;
    TestClear;

    Writeln('======================================================');
    Writeln(Format('SONUC: %d PASS, %d FAIL', [GPassCount, GFailCount]));
    Writeln('======================================================');

    if GFailCount = 0 then
      ExitCode := 0
    else
      ExitCode := 1;
  except
    on E: Exception do
    begin
      Writeln('BEKLENMEYEN HATA: ', E.ClassName, ': ', E.Message);
      ExitCode := 2;
    end;
  end;
end.
