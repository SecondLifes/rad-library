## Thread-Safety — Resource Protection

### TCriticalSection

```pascal
type
  TThreadSafeCounter = class
  private
    FCount: Integer;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Increment;
    procedure Decrement;
    function GetValue: Integer;
  end;

constructor TThreadSafeCounter.Create;
begin
  inherited;
  FLock := TCriticalSection.Create;
  FCount := 0;
end;

destructor TThreadSafeCounter.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TThreadSafeCounter.Increment;
begin
  FLock.Enter;
  try
    Inc(FCount);
  finally
    FLock.Leave;  //ALWAYS finally!
  end;
end;

function TThreadSafeCounter.GetValue: Integer;
begin
  FLock.Enter;
  try
    Result := FCount;
  finally
    FLock.Leave;
  end;
end;
```

### TMonitor (Native Object Lock)

```pascal
{ TMonitor usa o próprio objeto como lock — sem criar TCriticalSection }
procedure TThreadSafeList.AddItem(const AItem: string);
begin
  TMonitor.Enter(FList);
  try
    FList.Add(AItem);
  finally
    TMonitor.Exit(FList);
  end;
end;
```

### TInterlocked (Atomic Operations)

```pascal
{ Para operações simples em Integer/Int64 — sem lock explícito }
TInterlocked.Increment(FProcessedCount);
TInterlocked.Decrement(FPendingCount);
TInterlocked.Add(FTotalBytes, LBytesRead);
TInterlocked.Exchange(FOldValue, LNewValue);
TInterlocked.CompareExchange(FTarget, LNewVal, LExpectedVal);
```

### TThreadList<T> (Thread-Safe List)

```pascal
var
  FSharedList: TThreadList<string>;

{ Thread A: adicionar }
LList := FSharedList.LockList;
try
  LList.Add('item');
finally
  FSharedList.UnlockList;
end;

{ Thread B: ler }
LList := FSharedList.LockList;
try
  for LItem in LList do
    ProcessItem(LItem);
finally
  FSharedList.UnlockList;
end;
```

### TMultiReadExclusiveWriteSynchronizer (MREWS)

```pascal
type
  TThreadSafeCache = class
  private
    FData: TDictionary<string, string>;
    FLock: TMultiReadExclusiveWriteSynchronizer;
  public
    constructor Create;
    destructor Destroy; override;
    function TryGet(const AKey: string; out AValue: string): Boolean;
    procedure Put(const AKey, AValue: string);
  end;

function TThreadSafeCache.TryGet(const AKey: string; out AValue: string): Boolean;
begin
  FLock.BeginRead;  //Multiple threads can read simultaneously
  try
    Result := FData.TryGetValue(AKey, AValue);
  finally
    FLock.EndRead;
  end;
end;

procedure TThreadSafeCache.Put(const AKey, AValue: string);
begin
  FLock.BeginWrite;  //Only one thread can write at a time
  try
    FData.AddOrSetValue(AKey, AValue);
  finally
    FLock.EndWrite;
  end;
end;
```

## Events and Signage

### TEvent

```pascal
uses
  System.SyncObjs;

var
  FStopEvent: TEvent;

{ Criar }
FStopEvent := TEvent.Create(nil, True, False, ''); //Manual reset, initially unsignaled

{ Thread: esperar sinal }
procedure TWorkerThread.Execute;
begin
  while not Terminated do
  begin
    { Esperar até 500ms por sinal de parada }
    if FStopEvent.WaitFor(500) = wrSignaled then
      Break;

    { Fazer trabalho }
    DoWork;
  end;
end;

{ Main thread: sinalizar parada }
FStopEvent.SetEvent;
```

### TSemaphore (Competition Threshold)

```pascal
uses
  System.SyncObjs;

var
  FSemaphore: TSemaphore;

{ Limitar a 5 threads simultâneas }
FSemaphore := TSemaphore.Create(nil, 5, 5, '');

{ Em cada thread: }
FSemaphore.Acquire;
try
  { Apenas 5 threads podem estar aqui simultaneamente }
  PerformLimitedWork;
finally
  FSemaphore.Release;
end;
```
