unit rad.eventbus.Benchmark;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Diagnostics,
  rad.eventbus;

type
  [TestFixture]
  TChannelBusBenchmarkTestleri = class
  public
    [Test]
    procedure Benchmark_DmSync;
    [Test]
    procedure Benchmark_DmAsync;
    [Test]
    procedure Benchmark_DmMainSync;
    [Test]
    procedure Benchmark_DmMainAsync;
  end;

implementation

type
  TOlcumOlayi = record
    Index: Integer;
  end;

// Not: dmMainSync/dmMainAsync ölçümlerinde ana thread'in CheckSynchronize'i ne
// kadar SIK pompaladığı, ölçülen gecikmenin bir parçası haline gelir — bu yüzden
// (rad.eventbus.Tests.pas'taki GorevBekle'nin aksine) burada 5 ms'lik bekleme
// ARALIKLARI YOK: sıkı bir döngüyle (busy-spin) sürekli pompalanıyor ki ölçülen
// süre kütüphanenin gerçek dispatch maliyetini yansıtsın, polling aralığını değil.
function GorevBekleOlcum(AOlay: TEvent; AZamanAsimiMs: Integer): Boolean;
var
  BaslangicTick: UInt64;
begin
  BaslangicTick := TThread.GetTickCount64;
  repeat
    if AOlay.WaitFor(0) = wrSignaled then Exit(True);
    CheckSynchronize(0);
  until TThread.GetTickCount64 - BaslangicTick >= UInt64(AZamanAsimiMs);
  Result := AOlay.WaitFor(0) = wrSignaled;
end;

// Publish anından handler'ın çalıştığı ana kadar geçen uçtan uca gecikmeyi
// (dispatch/marshalling dahil) mikrosaniye cinsinden özetler.
function OlcumRaporu(const ABaslik: string; AToplamOlay: Integer; const ASw: TStopwatch;
  const APublishTick, AHandledTick: TArray<Int64>): string;
var
  i: Integer;
  Freq: Int64;
  GecikmeUs, ToplamGecikmeUs, MinGecikmeUs, MaxGecikmeUs: Double;
  SaniyeSn: Double;
begin
  Freq := TStopwatch.Frequency;
  ToplamGecikmeUs := 0;
  MinGecikmeUs := (AHandledTick[0] - APublishTick[0]) * 1000000.0 / Freq;
  MaxGecikmeUs := MinGecikmeUs;
  for i := 0 to AToplamOlay - 1 do
  begin
    GecikmeUs := (AHandledTick[i] - APublishTick[i]) * 1000000.0 / Freq;
    ToplamGecikmeUs := ToplamGecikmeUs + GecikmeUs;
    if GecikmeUs < MinGecikmeUs then MinGecikmeUs := GecikmeUs;
    if GecikmeUs > MaxGecikmeUs then MaxGecikmeUs := GecikmeUs;
  end;
  SaniyeSn := ASw.Elapsed.TotalSeconds;
  Result := Format('%s: %d olay, %.0f olay/sn, gecikme(us) ort=%.2f min=%.2f max=%.2f, toplam=%d ms',
    [ABaslik, AToplamOlay, AToplamOlay / SaniyeSn, ToplamGecikmeUs / AToplamOlay, MinGecikmeUs, MaxGecikmeUs,
     ASw.ElapsedMilliseconds]);
end;

{ ── dmSync: aynı thread'de, doğrudan çağrı — taban çizgisi (baseline) ── }

procedure TChannelBusBenchmarkTestleri.Benchmark_DmSync;
const
  N = 200000;
var
  Bus: TChannelBus;
  PublishTick, HandledTick: TArray<Int64>;
  sw: TStopwatch;
  i: Integer;
  Olay: TOlcumOlayi;
begin
  Bus := CreateChannelBus;
  SetLength(PublishTick, N);
  SetLength(HandledTick, N);
  try
    Bus.Subscribe<TOlcumOlayi>('bench.sync', dmSync,
      procedure(const AEvent: TOlcumOlayi)
      begin
        HandledTick[AEvent.Index] := TStopwatch.GetTimeStamp;
      end);

    sw := TStopwatch.StartNew;
    for i := 0 to N - 1 do
    begin
      Olay.Index := i;
      PublishTick[i] := TStopwatch.GetTimeStamp;
      Bus.Publish<TOlcumOlayi>('bench.sync', Olay);
    end;
    sw.Stop;

    Assert.Pass(OlcumRaporu('dmSync', N, sw, PublishTick, HandledTick));
  finally
    Bus.Free;
  end;
end;

{ ── dmAsync: TTask üzerinden arka planda paralel dispatch ── }

procedure TChannelBusBenchmarkTestleri.Benchmark_DmAsync;
const
  N = 20000;
var
  Bus: TChannelBus;
  PublishTick, HandledTick: TArray<Int64>;
  sw: TStopwatch;
  Sayac: Integer;
  BittiOlay: TEvent;
begin
  Bus := CreateChannelBus(opBlockPublisher, 4096); // yayıncı hiç veri kaybetmesin
  SetLength(PublishTick, N);
  SetLength(HandledTick, N);
  Sayac := 0;
  BittiOlay := TEvent.Create(nil, True, False, '');
  try
    Bus.Subscribe<TOlcumOlayi>('bench.async', dmAsync,
      procedure(const AEvent: TOlcumOlayi)
      begin
        HandledTick[AEvent.Index] := TStopwatch.GetTimeStamp;
        if TInterlocked.Increment(Sayac) = N then
          BittiOlay.SetEvent;
      end);

    sw := TStopwatch.StartNew;
    // Ana thread'den opBlockPublisher ile dmAsync Publish çağırmak DEBUG derlemede
    // kasıtlı bir guard'a takılır (bkz. rad.eventbus.md "opBlockPublisher + Ana
    // Thread Riski") — bu yüzden yayın, gerçek kullanım deseniyle tutarlı olarak
    // bir arka plan thread'inden yapılıyor (OpBlockPublisherHicVeriKaybetmez
    // testinde uygulanan düzeltmeyle aynı desen).
    TThread.CreateAnonymousThread(
      procedure
      var
        j: Integer;
        LOlay: TOlcumOlayi;
      begin
        for j := 0 to N - 1 do
        begin
          LOlay.Index := j;
          PublishTick[j] := TStopwatch.GetTimeStamp;
          Bus.Publish<TOlcumOlayi>('bench.async', LOlay);
        end;
      end).Start;

    Assert.IsTrue(GorevBekleOlcum(BittiOlay, 60000), 'dmAsync ölçümü zamanında bitmedi');
    sw.Stop;

    Assert.Pass(OlcumRaporu('dmAsync', N, sw, PublishTick, HandledTick));
  finally
    BittiOlay.Free;
    Bus.Free;
  end;
end;

{ ── dmMainSync: arka plan thread'inden yayın, ana thread'e TThread.Synchronize ── }

procedure TChannelBusBenchmarkTestleri.Benchmark_DmMainSync;
const
  N = 5000; // ana thread marshalling maliyeti yüksek — daha küçük N
var
  Bus: TChannelBus;
  PublishTick, HandledTick: TArray<Int64>;
  sw: TStopwatch;
  BittiOlay: TEvent;
begin
  Bus := CreateChannelBus;
  SetLength(PublishTick, N);
  SetLength(HandledTick, N);
  BittiOlay := TEvent.Create(nil, True, False, '');
  try
    Bus.Subscribe<TOlcumOlayi>('bench.mainsync', dmMainSync,
      procedure(const AEvent: TOlcumOlayi)
      begin
        HandledTick[AEvent.Index] := TStopwatch.GetTimeStamp;
        if AEvent.Index = N - 1 then
          BittiOlay.SetEvent;
      end);

    sw := TStopwatch.StartNew;
    TThread.CreateAnonymousThread(
      procedure
      var
        j: Integer;
        LOlay: TOlcumOlayi;
      begin
        for j := 0 to N - 1 do
        begin
          LOlay.Index := j;
          PublishTick[j] := TStopwatch.GetTimeStamp;
          Bus.Publish<TOlcumOlayi>('bench.mainsync', LOlay);
        end;
      end).Start;

    // Ana thread burada CheckSynchronize'i pompalamazsa TThread.Synchronize hiç
    // tetiklenmez ve arka plan thread'i sonsuza kadar bekler — dmMainSync'in
    // gerçek maliyetinin bir parçası da tam olarak bu pompalama gecikmesidir.
    Assert.IsTrue(GorevBekleOlcum(BittiOlay, 60000), 'dmMainSync ölçümü zamanında bitmedi');
    sw.Stop;

    Assert.Pass(OlcumRaporu('dmMainSync', N, sw, PublishTick, HandledTick));
  finally
    BittiOlay.Free;
    Bus.Free;
  end;
end;

{ ── dmMainAsync: ana thread'den yayın, TThread.ForceQueue ile kuyruklanır ── }

procedure TChannelBusBenchmarkTestleri.Benchmark_DmMainAsync;
const
  N = 20000;
var
  Bus: TChannelBus;
  PublishTick, HandledTick: TArray<Int64>;
  sw: TStopwatch;
  i: Integer;
  Olay: TOlcumOlayi;
  BittiOlay: TEvent;
begin
  Bus := CreateChannelBus;
  SetLength(PublishTick, N);
  SetLength(HandledTick, N);
  BittiOlay := TEvent.Create(nil, True, False, '');
  try
    Bus.Subscribe<TOlcumOlayi>('bench.mainasync', dmMainAsync,
      procedure(const AEvent: TOlcumOlayi)
      begin
        HandledTick[AEvent.Index] := TStopwatch.GetTimeStamp;
        if AEvent.Index = N - 1 then
          BittiOlay.SetEvent;
      end);

    sw := TStopwatch.StartNew;
    for i := 0 to N - 1 do
    begin
      Olay.Index := i;
      PublishTick[i] := TStopwatch.GetTimeStamp;
      Bus.Publish<TOlcumOlayi>('bench.mainasync', Olay);
    end;

    Assert.IsTrue(GorevBekleOlcum(BittiOlay, 60000), 'dmMainAsync ölçümü zamanında bitmedi');
    sw.Stop;

    Assert.Pass(OlcumRaporu('dmMainAsync', N, sw, PublishTick, HandledTick));
  finally
    BittiOlay.Free;
    Bus.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TChannelBusBenchmarkTestleri);

end.
