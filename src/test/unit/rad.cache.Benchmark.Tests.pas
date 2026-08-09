unit rad.cache.Benchmark.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  System.IOUtils,
  System.Generics.Collections,
  Dext.Collections.Dict,
  rad.cache;

type
  [TestFixture]
  TCollectionBenchmarkTests = class
  public
    [Test]
    procedure Benchmark_TSmartCache;
    [Test]
    procedure Benchmark_RtlDictionary;
    [Test]
    procedure Benchmark_DextDictionary;
  end;

implementation

function TotalAllocatedBytes: Int64;
var
  State: TMemoryManagerState;
  i: Integer;
begin
  GetMemoryManagerState(State);
  Result := State.TotalAllocatedMediumBlockSize + State.TotalAllocatedLargeBlockSize;
  for i := 0 to High(State.SmallBlockTypeStates) do
    Result := Result + Int64(State.SmallBlockTypeStates[i].AllocatedBlockCount) *
                        State.SmallBlockTypeStates[i].UseableBlockSize;
end;

const
  N = 50000;

{ ── mORMot TSmartCache (Core\rad.cache.pas, TDynArrayHashed tabanlı) ── }

procedure TCollectionBenchmarkTests.Benchmark_TSmartCache;
var
  Cache: TSmartCache;
  sw: TStopwatch;
  memBefore, memAfter: Int64;
  i, v, mismatches: Integer;
  Report, Phase: string;
begin
  // AThreadSafe=False: kilit maliyeti karışıma girmesin, saf veri yapısı ölçülsün.
  Cache := TSmartCache.Create(False);
  i := -1;
  Phase := 'baslamadi';
  try
    try
      memBefore := TotalAllocatedBytes;
      Phase := 'Ekleme';
      sw := TStopwatch.StartNew;
      for i := 1 to N do
        Cache.AddOrSet('Key' + IntToStr(i), i * 2);
      sw.Stop;
      memAfter := TotalAllocatedBytes;
      Report := Format('Ekleme: %d ms, bellek: +%d KB', [sw.ElapsedMilliseconds, (memAfter - memBefore) div 1024]);

      mismatches := 0;
      Phase := 'Bulma';
      sw := TStopwatch.StartNew;
      for i := 1 to N do
      begin
        v := Cache.Get('Key' + IntToStr(i), -1);
        if v <> i * 2 then Inc(mismatches);
      end;
      sw.Stop;
      Report := Report + sLineBreak + Format('Bulma: %d ms, hatali: %d', [sw.ElapsedMilliseconds, mismatches]);

      Phase := 'Silme';
      sw := TStopwatch.StartNew;
      for i := 1 to N do
        Cache.Remove('Key' + IntToStr(i));
      sw.Stop;
      Report := Report + sLineBreak + Format('Silme: %d ms, kalan: %d', [sw.ElapsedMilliseconds, Cache.Count]);

      if mismatches <> 0 then
        raise Exception.CreateFmt('Veri dogrulugu hatasi: %d hatali kayit', [mismatches]);
      if Cache.Count <> 0 then
        raise Exception.CreateFmt('Silme sonrasi bos olmali, kalan: %d', [Cache.Count]);
    except
      // Assert.Pass burada DEĞİL — DUnitX'in kendi "başarılı" kontrol akışı
      // exception'ı bu except'e yakalanmasın diye en dışarıda çağrılıyor.
      on E: Exception do
        Assert.Fail(Format('[%s fazi, i=%d''de patladi] %s: %s' + sLineBreak + '%s',
          [Phase, i, E.ClassName, E.Message, Report]));
    end;
  finally
    Cache.Free;
  end;
  Assert.Pass(Report);
end;

{ ── RTL System.Generics.Collections.TDictionary ── }

procedure TCollectionBenchmarkTests.Benchmark_RtlDictionary;
var
  Dict: System.Generics.Collections.TDictionary<string, Integer>;
  sw: TStopwatch;
  memBefore, memAfter: Int64;
  i, v, mismatches: Integer;
  Report: string;
begin
  Dict := System.Generics.Collections.TDictionary<string, Integer>.Create(N);
  try
    memBefore := TotalAllocatedBytes;
    sw := TStopwatch.StartNew;
    for i := 1 to N do
      Dict.AddOrSetValue('Key' + IntToStr(i), i * 2);
    sw.Stop;
    memAfter := TotalAllocatedBytes;
    Report := Format('Ekleme: %d ms, bellek: +%d KB', [sw.ElapsedMilliseconds, (memAfter - memBefore) div 1024]);

    mismatches := 0;
    sw := TStopwatch.StartNew;
    for i := 1 to N do
    begin
      if not Dict.TryGetValue('Key' + IntToStr(i), v) then v := -1;
      if v <> i * 2 then Inc(mismatches);
    end;
    sw.Stop;
    Report := Report + sLineBreak + Format('Bulma: %d ms, hatali: %d', [sw.ElapsedMilliseconds, mismatches]);

    sw := TStopwatch.StartNew;
    for i := 1 to N do
      Dict.Remove('Key' + IntToStr(i));
    sw.Stop;
    Report := Report + sLineBreak + Format('Silme: %d ms, kalan: %d', [sw.ElapsedMilliseconds, Dict.Count]);

    Assert.AreEqual(0, mismatches, 'Veri dogrulugu hatasi: ' + Report);
    Assert.AreEqual(0, Dict.Count, 'Silme sonrasi bos olmali: ' + Report);
    Assert.Pass(Report);
  finally
    Dict.Free;
  end;
end;

{ ── Dext.Collections.Dict.TDictionary ── }

procedure TCollectionBenchmarkTests.Benchmark_DextDictionary;
var
  Dict: Dext.Collections.Dict.TDictionary<string, Integer>;
  sw: TStopwatch;
  memBefore, memAfter: Int64;
  i, v, mismatches: Integer;
  Report: string;
begin
  Dict := Dext.Collections.Dict.TDictionary<string, Integer>.Create(N);
  try
    memBefore := TotalAllocatedBytes;
    sw := TStopwatch.StartNew;
    for i := 1 to N do
      Dict.AddOrSetValue('Key' + IntToStr(i), i * 2);
    sw.Stop;
    memAfter := TotalAllocatedBytes;
    Report := Format('Ekleme: %d ms, bellek: +%d KB', [sw.ElapsedMilliseconds, (memAfter - memBefore) div 1024]);

    mismatches := 0;
    sw := TStopwatch.StartNew;
    for i := 1 to N do
    begin
      if not Dict.TryGetValue('Key' + IntToStr(i), v) then v := -1;
      if v <> i * 2 then Inc(mismatches);
    end;
    sw.Stop;
    Report := Report + sLineBreak + Format('Bulma: %d ms, hatali: %d', [sw.ElapsedMilliseconds, mismatches]);

    sw := TStopwatch.StartNew;
    for i := 1 to N do
      Dict.Remove('Key' + IntToStr(i));
    sw.Stop;
    Report := Report + sLineBreak + Format('Silme: %d ms, kalan: %d', [sw.ElapsedMilliseconds, Dict.Count]);

    Assert.AreEqual(0, mismatches, 'Veri dogrulugu hatasi: ' + Report);
    Assert.AreEqual(0, Dict.Count, 'Silme sonrasi bos olmali: ' + Report);
    Assert.Pass(Report);
  finally
    Dict.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCollectionBenchmarkTests);

end.
