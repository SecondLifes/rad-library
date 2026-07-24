## Available Approaches

| Approach | When to Use | Complexity |
|-----------|-------------|-------------|
| `TThread` | Full control, long-running threads | Average |
| `TThread.CreateAnonymousThread` | Simple, one-shot tasks | Low |
| `TTask` (PPL) | Modern parallelism, lightweight tasks | Low |
| `TParallel.For` (PPL) | Parallel loops in collections | Low |
| `TFuture<T>` (PPL) | Asynchronous result with return value | Low |
| `TThreadPool` | Reusable Thread Pool | Average |
| Dedicated thread (inheritance) | Permanent workers, servers, queues | High |

## TThread — Classical Approach

### Thread with Inheritance (Recommended for Workers)

```pascal
type
  ///<summary>
  ///Worker thread for background processing.
  ///Demonstrates TThread inheritance with cancellation via Terminated.
  ///</summary>
  TDataProcessorThread = class(TThread)
  private
    FItems: TThreadList<string>;
    FOnProgress: TProc<Integer, Integer>;
    FOnComplete: TProc<Boolean>;
  protected
    procedure Execute; override;
  public
    constructor Create(AItems: TThreadList<string>);
    property OnProgress: TProc<Integer, Integer> write FOnProgress;
    property OnComplete: TProc<Boolean> write FOnComplete;
  end;

constructor TDataProcessorThread.Create(AItems: TThreadList<string>);
begin
  inherited Create(True);   //Create dropdown
  FreeOnTerminate := True;  //Auto-releases when finished
  FItems := AItems;
end;

procedure TDataProcessorThread.Execute;
var
  LList: TList<string>;
  LTotal, I: Integer;
begin
  try
    LList := FItems.LockList;
    try
      LTotal := LList.Count;
    finally
      FItems.UnlockList;
    end;

    for I := 0 to LTotal - 1 do
    begin
      { Verificar cancelamento em cada iteração }
      if Terminated then
        Exit;

      { Processar item }
      ProcessItem(I);

      { Atualizar UI via Queue (não-bloqueante) }
      if Assigned(FOnProgress) then
        TThread.Queue(nil,
          procedure
          begin
            FOnProgress(I + 1, LTotal);
          end);
    end;

    { Notificar conclusão na main thread }
    if Assigned(FOnComplete) then
      TThread.Queue(nil,
        procedure
        begin
          FOnComplete(not Terminated);
        end);
  except
    on E: Exception do
    begin
      TThread.Queue(nil,
        procedure
        begin
          raise EThreadException.Create('Erro no processamento: ' + E.Message);
        end);
    end;
  end;
end;
```

### Use of Dedicated Thread

```pascal
procedure TfrmMain.btnProcessClick(Sender: TObject);
var
  LThread: TDataProcessorThread;
begin
  LThread := TDataProcessorThread.Create(FSharedItems);
  LThread.OnProgress :=
    procedure(ACurrent, ATotal: Integer)
    begin
      pbrProgress.Max := ATotal;
      pbrProgress.Position := ACurrent;
      lblStatus.Caption := Format('Processando %d de %d...', [ACurrent, ATotal]);
    end;
  LThread.OnComplete :=
    procedure(ASuccess: Boolean)
    begin
      if ASuccess then
        ShowMessage('Concluído com sucesso!')
      else
        ShowMessage('Processamento cancelado.');
    end;
  LThread.Start;  //Iniciar a thread
end;

procedure TfrmMain.btnCancelClick(Sender: TObject);
begin
  { Solicitar cancelamento gracioso }
  if Assigned(FCurrentThread) then
    FCurrentThread.Terminate;
end;
```

### CreateAnonymousThread (Simple Tasks)

```pascal
///<summary>
///Simplest way to run code in the background.
///Ideal for one-shot tasks without the need for advanced control.
///</summary>
procedure TfrmMain.LoadDataAsync;
begin
  btnLoad.Enabled := False;

  TThread.CreateAnonymousThread(
    procedure
    var
      LData: TStringList;
    begin
      LData := TStringList.Create;
      try
        { Trabalho pesado (thread secundária — OK!) }
        LData.LoadFromFile('C:\dados\arquivo_grande.csv');
        Sleep(2000); //Simulate processing

        { Atualizar UI (DEVE usar Synchronize ou Queue) }
        TThread.Synchronize(nil,
          procedure
          begin
            mmoOutput.Lines.Assign(LData);
            btnLoad.Enabled := True;
            lblStatus.Caption := Format('Carregados %d registros', [LData.Count]);
          end);
      finally
        LData.Free;
      end;
    end
  ).Start;
end;
```

## Synchronize vs Queue

| Method | Behavior | When to Use |
|--------|--------------|-------------|
| `TThread.Synchronize` | **Blocking** — waits for the main thread to process | When you need the UI result |
| `TThread.Queue` | **Non-blocking** — queue and continue | Progress, logs, visual updates |

```pascal
{ Synchronize: BLOQUEIA a thread até a main thread processar }
TThread.Synchronize(nil,
  procedure
  begin
    lblStatus.Caption := 'Processando...';
  end);
//The thread only continues HERE after the main thread has executed the code above

{ Queue: NÃO BLOQUEIA — enfileira e continua imediatamente }
TThread.Queue(nil,
  procedure
  begin
    lblStatus.Caption := 'Processando...';
  end);
//The thread continues IMMEDIATELY, without waiting for the main thread
```

> **Recommendation:** Prefer `Queue` whenever possible. Use `Synchronize` only when you need a result from the UI back in the thread.

## PPL — Parallel Programming Library (System.Threading)

### TTask — Light Tasks

```pascal
uses
  System.Threading;

///<summary>
///TTask is the modern way to perform tasks in the background.
///Automatically managed by the system thread pool.
///</summary>
procedure TfrmMain.ExecuteMultipleTasks;
var
  LTask1, LTask2, LTask3: ITask;
begin
  LTask1 := TTask.Create(
    procedure
    begin
      { Tarefa 1: Carregar dados do banco }
      LoadCustomers;
    end);

  LTask2 := TTask.Create(
    procedure
    begin
      { Tarefa 2: Processar relatório }
      GenerateReport;
    end);

  LTask3 := TTask.Create(
    procedure
    begin
      { Tarefa 3: Enviar emails }
      SendPendingEmails;
    end);

  { Iniciar todas as tarefas em paralelo }
  LTask1.Start;
  LTask2.Start;
  LTask3.Start;

  { Aguardar todas completarem (com timeout) }
  TTask.WaitForAll([LTask1, LTask2, LTask3], 30000); //30s timeout

  TThread.Queue(nil,
    procedure
    begin
      ShowMessage('Todas as tarefas concluídas!');
    end);
end;
```

### TTask.Run — Direct Shortcut

```pascal
{ Forma mais simples de executar em background via PPL }
TTask.Run(
  procedure
  begin
    { Código executado no ThreadPool }
    PerformHeavyCalculation;

    TThread.Queue(nil,
      procedure
      begin
        lblResult.Caption := 'Cálculo concluído';
      end);
  end);
```

### TParallel.For — Parallel Loops

```pascal
uses
  System.Threading,
  System.SyncObjs;

///<summary>
///TParallel.For distributes loop iterations among multiple threads.
///Ideal for processing independent collections.
///</summary>
procedure TfrmMain.ProcessImagesParallel;
var
  LFiles: TArray<string>;
  LProcessed: Integer;
  LLock: TCriticalSection;
begin
  LFiles := TDirectory.GetFiles('C:\Images', '*.jpg');
  LProcessed := 0;
  LLock := TCriticalSection.Create;
  try
    TParallel.For(0, High(LFiles),
      procedure(AIndex: Integer)
      begin
        { Cada imagem processada em thread separada }
        ResizeImage(LFiles[AIndex]);

        { Atualizar contador de forma thread-safe }
        LLock.Enter;
        try
          Inc(LProcessed);
        finally
          LLock.Leave;
        end;
      end);

    ShowMessage(Format('%d imagens processadas', [LProcessed]));
  finally
    LLock.Free;
  end;
end;
```

> **⚠️ CAUTION:** Each iteration of `TParallel.For` can run on different threads. Shared variables **MUST** be protected with `TCriticalSection`, `TMonitor` or `TInterlocked`.

### TFuture<T> — Asynchronous Result

```pascal
uses
  System.Threading;

///<summary>
///TFuture runs a task and returns a value when done.
///Reading .Value blocks until the result is available.
///</summary>
procedure TfrmMain.CalculateAsync;
var
  LFuture: IFuture<Double>;
begin
  LFuture := TFuture<Double>.Create(
    function: Double
    begin
      { Cálculo pesado em background }
      Sleep(3000);
      Result := CalculateComplexFormula(FInputData);
    end);

  LFuture.Start;

  { Fazer outras coisas enquanto o cálculo roda... }
  PrepareReport;

  { Pegar o resultado (bloqueia SE ainda não terminou) }
  ShowMessage(Format('Resultado: %.2f', [LFuture.Value]));
end;
```
