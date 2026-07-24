---
description: "Performance standards — measure-first optimization, TStopwatch/profilers, data-structure selection, batching, UI responsiveness"
globs: ["**/*.pas"]
alwaysApply: false
---

# Performance — Rules

No performance adjective is accepted without measurement. Use Release
Win32 and Win64 builds, record compiler/toolchain and baseline, include
allocation evidence, warm up the workload, repeat runs and document outlier
treatment. There is no universal threshold: choose acceptance criteria for
the actual feature. Correctness, safety and clear semantics take priority.

Use these rules when optimizing Delphi code or reviewing for performance.

## Golden Rule

> **Measure first.** No complex micro-optimization without a measurement,
> benchmark, or complexity argument. The right algorithm and data
> structure beat instruction-level tricks — pick those first.

## Measurement

```pascal
uses System.Diagnostics;

var LSw: TStopwatch;
begin
  LSw := TStopwatch.StartNew;
  DoWork;
  LSw.Stop;
  Writeln(Format('Süre: %d ms', [LSw.ElapsedMilliseconds]));
end;
```

- `TStopwatch` for micro-benchmarks: warm up once, run N iterations,
  report median not single-shot; state N and the machine in benchmark
  notes.
- Profilers for real workloads — sampling the actual app beats guessing
  from source. Name the tool used in the report; don't claim profiling
  happened when only a stopwatch ran.
- A performance claim in a review/report needs a number or a complexity
  argument attached — "should be faster" is not a finding.

## Data structure selection (complexity first)

| Need | Use | Avoid |
|---|---|---|
| Key lookup | `TDictionary<K,V>` — O(1) | `TStringList.IndexOf` linear scan — O(n) |
| Sorted membership | sorted `TList<T>` + `BinarySearch` | repeated linear `IndexOf` |
| Queue/stack | `TQueue<T>` / `TStack<T>` | `TList.Delete(0)` shifting — O(n) per pop |
| Many string appends | `TStringBuilder` | `S := S + ...` in a loop — O(n²) reallocations |
| Large arrays | `SetLength` once (pre-size), fill by index | `Add` growth without `Capacity` when count is known |

Set `Capacity`/`SetLength` up front when the final size is known — cuts
reallocation churn in lists, dictionaries, and dynamic arrays.

## Parameter & memory patterns

- `const` on string/record/interface parameters — skips refcount/copy
  overhead; the kit's default for every such parameter.
- Records for small short-lived value aggregates (stack, no heap);
  classes for identity/lifecycle. Don't heap-allocate in tight loops
  when a record or reused buffer does the job.
- Reuse buffers/objects across loop iterations instead of
  create/destroy per iteration — but only where measurement shows churn
  matters; readability wins otherwise.
- Beware hidden copies: assigning dynamic arrays copies the reference,
  `Copy()` copies data; passing large records without `const`/`var`
  copies the record.

## Database & I/O (usually the real bottleneck)

- N+1 queries, unindexed WHERE/JOIN columns, `SELECT *`, and chatty
  round-trips dominate most "Delphi is slow" reports — check the DB
  database-specific rules selected by the consuming project before touching
  Pascal code.
- Batch inserts via `Params.ArraySize` (FireDAC Array DML) instead of
  row-by-row `ExecSQL`.
- Stream large files (`TFileStream` chunked) — never `TStringList.
  LoadFromFile` a multi-hundred-MB file to "process lines".

## UI responsiveness

- Long work off the main thread (`TTask.Run` + `TThread.Queue` for
  updates — see threading rules); the UI freezing is a correctness bug,
  not a performance nicety.
- Batch UI updates: `BeginUpdate`/`EndUpdate` on lists/grids/memos;
  `DisableControls`/`EnableControls` on datasets bound to UI during bulk
  operations.

## Prohibitions

- ❌ Optimization commits without a before/after measurement in the message or PR
- ❌ `S := S + X` string building in loops — `TStringBuilder`
- ❌ Linear scans where a dictionary/sorted structure fits
- ❌ ASM/pointer tricks for gains a profiler never demanded
- ❌ Caching added "just in case" — caches need invalidation stories
- ❌ Claiming a benchmark ran when it didn't (honesty rule — predictions are labeled predictions)
