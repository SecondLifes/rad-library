## Anti-Patterns to Avoid

```pascal
//❌ NEVER access UI directly from secondary thread
TThread.CreateAnonymousThread(
  procedure
  begin
    lblStatus.Caption := 'Processando...';  //CRASH or unpredictable behavior!
  end).Start;

//✅ ALWAYS use Synchronize/Queue for UI
TThread.CreateAnonymousThread(
  procedure
  begin
    TThread.Queue(nil,
      procedure
      begin
        lblStatus.Caption := 'Processando...';  //Safe!
      end);
  end).Start;

//⚠️ Lifecycle: a queued anonymous method runs LATER on the main thread —
//the form/control it captures (lblStatus) may already be destroyed by then.
//Guard against it: cancel/wait for worker threads in the form's
//OnClose/destructor (TThread.RemoveQueuedEvents(Self) helps), or queue
//against the owning object instead of nil so pending events can be purged.

//❌ NEVER create thread with FreeOnTerminate=True and keep reference
FMyThread := TMyThread.Create(True);
FMyThread.FreeOnTerminate := True;
FMyThread.Start;
//... after
FMyThread.WaitFor;  //CRASH! The object may have already been released!

//✅ If you need WaitFor, DO NOT use FreeOnTerminate
FMyThread := TMyThread.Create(True);
FMyThread.FreeOnTerminate := False;
FMyThread.Start;
//... after
FMyThread.WaitFor;
FMyThread.Free;

//❌ NEVER access shared variables without protection
Inc(FSharedCounter);  //Race condition!

//✅ ALWAYS secure shared access
TInterlocked.Increment(FSharedCounter);  //Atomic!
// ou
FLock.Enter;
try
  Inc(FSharedCounter);
finally
  FLock.Leave;
end;

//❌ NEVER use Sleep() in the main thread
Sleep(5000);  //Freeze UI for 5 seconds!

//✅ Move heavy work to thread
TTask.Run(
  procedure
  begin
    Sleep(5000);  //OK in secondary thread
    TThread.Queue(nil,
      procedure
      begin
        lblStatus.Caption := 'Concluído';
      end);
  end);

//❌ NEVER ignore exceptions in threads (they are silent!)
TThread.CreateAnonymousThread(
  procedure
  begin
    RiskyOperation;  //If you throw an exception, no one will know!
  end).Start;

//✅ ALWAYS handle exceptions in threads
TThread.CreateAnonymousThread(
  procedure
  begin
    try
      RiskyOperation;
    except
      on E: Exception do
        TThread.Queue(nil,
          procedure
          begin
            HandleError(E.Message);
          end);
    end;
  end).Start;
```

## Thread Debugging

### Name Threads (Facilitates Debug)

```pascal
TThread.CreateAnonymousThread(
  procedure
  begin
    TThread.NameThreadForDebugging('DataLoader');
    //...code
  end).Start;

{ Para TThread herdado: }
procedure TMyThread.Execute;
begin
  TThread.NameThreadForDebugging('MyWorker_' + FId.ToString);
  // ...
end;
```

### Thread Window in IDE

- **View → Debug Windows → Threads:** Lists all active threads
- Each named thread appears with its custom name
- Useful for identifying deadlocks and race conditions

## Threading Checklist

- [ ] Are heavy operations on secondary threads (not the main thread)?
- [ ] Does every UI update use `Synchronize` or `Queue`?
- [ ] Shared variables protected with locks (`TCriticalSection`, `TMonitor`, `TInterlocked`)?
- [ ] `FreeOnTerminate` configured correctly (True for fire-and-forget, False if you need WaitFor)?
- [ ] Threads check `Terminated` in loops for graceful cancellation?
- [ ] Exceptions handled within threads (do not propagate silently)?
- [ ] Threads named with `NameThreadForDebugging` to facilitate debugging?
- [ ] `TCriticalSection.Leave` always on `finally`?
- [ ] Without `Sleep()` in the main thread?
- [ ] No deadlocks (locks nested in the same order)?
