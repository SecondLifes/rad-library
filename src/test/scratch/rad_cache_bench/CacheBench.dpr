program CacheBench;

{ Variant (legacy TSmartParam) vs TValue (yeni) cache mikro-benchmark'ı.
  Her iki implementasyon da AYNI kilidi (TLightweightMREW) kullanır ve
  AThreadSafe=False ile ölçülür — fark saf değer-temsilinden gelir.
  Anahtar dizisi önceden üretilir (IntToStr maliyeti ölçüme karışmaz).
  İlk tur ısınmadır ve atılır; ikinci turun sonuçları yazdırılır. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  rad.cache in '..\..\..\core\rad.cache.pas',
  rad.cache.legacy in 'rad.cache.legacy.pas';

const
  N = 100000;

var
  Keys: TArray<string>;

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

procedure PrepKeys;
var
  i: Integer;
begin
  SetLength(Keys, N);
  for i := 0 to N - 1 do
    Keys[i] := 'K' + IntToStr(i);
end;

procedure BenchLegacy(const APrint: Boolean);
var
  Cache: rad.cache.legacy.TSmartCache;
  sw: TStopwatch;
  i, Toplam: Integer;
  S: string;
  MemOnce, MemSonra: Int64;
  TIntAdd, TIntGet, TIntOver, TStrAdd, TStrGet: Int64;
begin
  Cache := rad.cache.legacy.TSmartCache.Create(False);
  try
    MemOnce := TotalAllocatedBytes;

    sw := TStopwatch.StartNew;
    for i := 0 to N - 1 do
      Cache.AddOrSet(Keys[i], i);
    TIntAdd := sw.ElapsedMilliseconds;

    Toplam := 0;
    sw := TStopwatch.StartNew;
    for i := 0 to N - 1 do
      Toplam := Toplam + Cache.Get(Keys[i], -1);
    TIntGet := sw.ElapsedMilliseconds;

    sw := TStopwatch.StartNew;
    for i := 0 to N - 1 do
      Cache.AddOrSet(Keys[i], i); // aynı değer: eşitlik kısa devresi (VarSameValue)
    TIntOver := sw.ElapsedMilliseconds;

    sw := TStopwatch.StartNew;
    for i := 0 to N - 1 do
      Cache.AddOrSet(Keys[i], 'S' + Keys[i]);
    TStrAdd := sw.ElapsedMilliseconds;

    sw := TStopwatch.StartNew;
    for i := 0 to N - 1 do
      S := Cache.Get(Keys[i], '');
    TStrGet := sw.ElapsedMilliseconds;

    MemSonra := TotalAllocatedBytes;

    if APrint then
    begin
      Writeln(Format('Variant  | int add: %4d ms | int get: %4d ms | ayni-deger yaz: %4d ms | str add: %4d ms | str get: %4d ms | bellek: +%d KB',
        [TIntAdd, TIntGet, TIntOver, TStrAdd, TStrGet, (MemSonra - MemOnce) div 1024]));
      if (Toplam = 0) and (S = '?') then Writeln('.'); // optimizasyon bariyeri
    end;
  finally
    Cache.Free;
  end;
end;

procedure BenchYeni(const APrint: Boolean);
var
  Cache: rad.cache.TSmartCache;
  sw: TStopwatch;
  i, Toplam: Integer;
  S: string;
  MemOnce, MemSonra: Int64;
  TIntAdd, TIntGet, TIntOver, TStrAdd, TStrGet: Int64;
begin
  Cache := rad.cache.TSmartCache.Create(False);
  try
    MemOnce := TotalAllocatedBytes;

    sw := TStopwatch.StartNew;
    for i := 0 to N - 1 do
      Cache.AddOrSet(Keys[i], i);
    TIntAdd := sw.ElapsedMilliseconds;

    Toplam := 0;
    sw := TStopwatch.StartNew;
    for i := 0 to N - 1 do
      Toplam := Toplam + Cache.Get(Keys[i], -1);
    TIntGet := sw.ElapsedMilliseconds;

    sw := TStopwatch.StartNew;
    for i := 0 to N - 1 do
      Cache.AddOrSet(Keys[i], i); // aynı değer: eşitlik kısa devresi (ValuesEqual)
    TIntOver := sw.ElapsedMilliseconds;

    sw := TStopwatch.StartNew;
    for i := 0 to N - 1 do
      Cache.AddOrSet(Keys[i], 'S' + Keys[i]);
    TStrAdd := sw.ElapsedMilliseconds;

    sw := TStopwatch.StartNew;
    for i := 0 to N - 1 do
      S := Cache.Get(Keys[i], '');
    TStrGet := sw.ElapsedMilliseconds;

    MemSonra := TotalAllocatedBytes;

    if APrint then
    begin
      Writeln(Format('TValue   | int add: %4d ms | int get: %4d ms | ayni-deger yaz: %4d ms | str add: %4d ms | str get: %4d ms | bellek: +%d KB',
        [TIntAdd, TIntGet, TIntOver, TStrAdd, TStrGet, (MemSonra - MemOnce) div 1024]));
      if (Toplam = 0) and (S = '?') then Writeln('.');
    end;
  finally
    Cache.Free;
  end;
end;

begin
  try
    PrepKeys;
    Writeln(Format('N = %d, tek thread, AThreadSafe=False, ayni kilit tipi, Win32', [N]));
    Writeln('--- isinma turu (atilir) ---');
    BenchLegacy(False);
    BenchYeni(False);
    Writeln('--- olcum turu ---');
    BenchLegacy(True);
    BenchYeni(True);
    Writeln('--- ikinci olcum turu (tutarlilik kontrolu) ---');
    BenchLegacy(True);
    BenchYeni(True);
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 2;
    end;
  end;
end.
