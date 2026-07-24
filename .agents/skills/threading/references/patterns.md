## Producer-Consumer Pattern

```pascal
type
  ///<summary>
  ///Producer-Consumer com TThreadedQueue (fila thread-safe).
  ///</summary>
  TProducerConsumerDemo = class
  private
    FQueue: TThreadedQueue<string>;
    FProducerThread: TThread;
    FConsumerThread: TThread;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
  end;

constructor TProducerConsumerDemo.Create;
begin
  inherited;
  { QueueDepth=100, PushTimeout=1000ms, PopTimeout=1000ms }
  FQueue := TThreadedQueue<string>.Create(100, 1000, 1000);
end;

procedure TProducerConsumerDemo.Start;
begin
  { Producer: gera itens continuamente }
  FProducerThread := TThread.CreateAnonymousThread(
    procedure
    var
      I: Integer;
    begin
      I := 0;
      while not TThread.Current.CheckTerminated do
      begin
        Inc(I);
        FQueue.PushItem(Format('Item_%d', [I]));
        Sleep(100);
      end;
    end);
  FProducerThread.FreeOnTerminate := False;

  { Consumer: processa itens da fila }
  FConsumerThread := TThread.CreateAnonymousThread(
    procedure
    var
      LItem: string;
      LResult: TWaitResult;
    begin
      while not TThread.Current.CheckTerminated do
      begin
        LResult := FQueue.PopItem(LItem);
        if LResult = wrSignaled then
          ProcessItem(LItem);
      end;
    end);
  FConsumerThread.FreeOnTerminate := False;

  FProducerThread.Start;
  FConsumerThread.Start;
end;

procedure TProducerConsumerDemo.Stop;
begin
  FProducerThread.Terminate;
  FConsumerThread.Terminate;
  FProducerThread.WaitFor;
  FConsumerThread.WaitFor;
  FProducerThread.Free;
  FConsumerThread.Free;
end;
```

## Custom Thread Pool

```pascal
type
  TCustomThreadPool = class
  private
    FThreads: TObjectList<TThread>;
    FQueue: TThreadedQueue<TProc>;
    FMaxThreads: Integer;
  public
    constructor Create(AMaxThreads: Integer = 4);
    destructor Destroy; override;
    procedure QueueWork(AProc: TProc);
  end;

constructor TCustomThreadPool.Create(AMaxThreads: Integer);
var
  I: Integer;
begin
  inherited Create;
  FMaxThreads := AMaxThreads;
  FQueue := TThreadedQueue<TProc>.Create(1000, INFINITE, 500);
  FThreads := TObjectList<TThread>.Create(True);

  for I := 0 to FMaxThreads - 1 do
  begin
    var LThread := TThread.CreateAnonymousThread(
      procedure
      var
        LProc: TProc;
        LResult: TWaitResult;
      begin
        while not TThread.Current.CheckTerminated do
        begin
          LResult := FQueue.PopItem(LProc);
          if (LResult = wrSignaled) and Assigned(LProc) then
          try
            LProc();
          except
            on E: Exception do
              { Log error, don't crash the pool thread }
              TThread.Queue(nil,
                procedure
                begin
                  // Logger.LogError(E);
                end);
          end;
        end;
      end);
    LThread.FreeOnTerminate := False;
    LThread.Start;
    FThreads.Add(LThread);
  end;
end;

procedure TCustomThreadPool.QueueWork(AProc: TProc);
begin
  FQueue.PushItem(AProc);
end;
```

## Cancellation with Token

```pascal
type
  ICancellationToken = interface
    ['{CANCEL01-0001-0001-0001-000000000001}']
    function IsCancelled: Boolean;
    procedure Cancel;
    procedure ThrowIfCancelled;
  end;

  TCancellationToken = class(TInterfacedObject, ICancellationToken)
  private
    FCancelled: Integer;  //0=false, 1=true (atomic)
  public
    function IsCancelled: Boolean;
    procedure Cancel;
    procedure ThrowIfCancelled;
  end;

function TCancellationToken.IsCancelled: Boolean;
begin
  Result := TInterlocked.Read(FCancelled) = 1;
end;

procedure TCancellationToken.Cancel;
begin
  TInterlocked.Exchange(FCancelled, 1);
end;

procedure TCancellationToken.ThrowIfCancelled;
begin
  if IsCancelled then
    raise EOperationCancelled.Create('Operação cancelada pelo usuário');
end;

{ Uso: }
procedure ProcessWithCancellation(AToken: ICancellationToken);
begin
  for var I := 0 to 999 do
  begin
    AToken.ThrowIfCancelled;
    ProcessItem(I);
  end;
end;
```

## Important Standards

### Pattern: Background Worker with Result

```pascal
type
  ///<summary>
  ///Generic background worker that executes a function and returns
  ///the result in the main thread.
  ///</summary>
  TBackgroundWorker<T> = class
  public
    class procedure Execute(
      AWorkFunc: TFunc<T>;
      AOnSuccess: TProc<T>;
      AOnError: TProc<Exception>);
  end;

class procedure TBackgroundWorker<T>.Execute(
  AWorkFunc: TFunc<T>;
  AOnSuccess: TProc<T>;
  AOnError: TProc<Exception>);
begin
  TTask.Run(
    procedure
    var
      LResult: T;
    begin
      try
        LResult := AWorkFunc();
        TThread.Queue(nil,
          procedure
          begin
            AOnSuccess(LResult);
          end);
      except
        on E: Exception do
          TThread.Queue(nil,
            procedure
            begin
              AOnError(E);
            end);
      end;
    end);
end;

{ Uso elegante: }
TBackgroundWorker<TObjectList<TCustomer>>.Execute(
  function: TObjectList<TCustomer>
  begin
    Result := FCustomerRepo.FindAll;
  end,
  procedure(ACustomers: TObjectList<TCustomer>)
  begin
    FillGrid(ACustomers);
    lblStatus.Caption := Format('%d clientes carregados', [ACustomers.Count]);
  end,
  procedure(AError: Exception)
  begin
    ShowMessage('Erro: ' + AError.Message);
  end);
```

### Default: Timer Thread (Periodic Execution)

```pascal
type
  TTimerThread = class(TThread)
  private
    FInterval: Cardinal;
    FOnTimer: TProc;
  protected
    procedure Execute; override;
  public
    constructor Create(AIntervalMs: Cardinal; AOnTimer: TProc);
  end;

constructor TTimerThread.Create(AIntervalMs: Cardinal; AOnTimer: TProc);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FInterval := AIntervalMs;
  FOnTimer := AOnTimer;
end;

procedure TTimerThread.Execute;
begin
  while not Terminated do
  begin
    Sleep(FInterval);
    if not Terminated and Assigned(FOnTimer) then
      FOnTimer();
  end;
end;
```
