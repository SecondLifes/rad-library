---
name: "Threading & Multi-Threading"
description: "Threading patterns in Delphi — TThread, TTask, TParallel, Synchronize, Queue, thread-safety, Producer-Consumer, pools, cancellation and debugging"
---

# Threading & Multi-Threading — Skill

Use this skill when working with threads, asynchronous tasks and parallelism in Delphi projects.

## When to Use

- When performing time-consuming operations without blocking the UI (VCL/FMX)
- When implementing parallel data processing
- When creating servers/workers that process concurrent requests
- When synchronizing access to shared resources
- When managing thread pools and work queues
- By implementing graceful thread cancellation

## Golden Rule of Threading in Delphi

> **NEVER access visual components (VCL/FMX) directly from a secondary thread.**
> Use `TThread.Synchronize` or `TThread.Queue` to update the UI.

## Quick Reference

Simplest way to run something in the background and touch the UI when done:

```pascal
TTask.Run(
  procedure
  begin
    PerformHeavyCalculation;
    TThread.Queue(nil,
      procedure
      begin
        lblResult.Caption := 'Cálculo concluído';
      end);
  end);
```

Golden rules: never touch VCL/FMX from a secondary thread (`Synchronize`/`Queue` only), never `Sleep()` on the main thread, protect every shared variable (`TCriticalSection`/`TMonitor`/`TInterlocked`), never call `WaitFor` on a thread with `FreeOnTerminate := True`. Full details and code for each are in the reference files below — read the one that matches the task at hand rather than guessing.

## references/

Read only the file(s) relevant to the current task — this skill file is intentionally short; the depth lives in these files.

- `basics-and-ppl.md` — approach comparison table, `TThread` (inheritance and `CreateAnonymousThread`), `Synchronize` vs `Queue`, and the PPL (`TTask`, `TTask.Run`, `TParallel.For`, `TFuture<T>`).
- `thread-safety.md` — `TCriticalSection`, `TMonitor`, `TInterlocked`, `TThreadList<T>`, `TMultiReadExclusiveWriteSynchronizer`, plus `TEvent`/`TSemaphore` signaling.
- `patterns.md` — Producer-Consumer with `TThreadedQueue`, a custom thread pool, cancellation tokens, the generic background-worker-with-result pattern, and a periodic timer thread.
- `debugging-and-checklist.md` — anti-patterns to avoid, naming threads for the IDE debugger, and the pre-flight checklist.
