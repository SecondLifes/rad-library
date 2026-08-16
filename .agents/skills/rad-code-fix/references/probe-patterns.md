# Safe Probe Patterns

A probe turns a behavioral claim into an observation. Run probes only after the
command-safety classification in `SKILL.md`; use isolated fixtures, timeouts and
resource limits. Never target production data, live credentials or paid/external
services without explicit approval.

## Probe contract

Before running, state:

- claim being tested;
- isolated input/fixture and expected observation;
- exact command, timeout and cleanup;
- files/services it may touch;
- how success and failure will be recorded.

If those facts are unknown, do not run the probe.

## Patterns

### Boundary and transformation

Use a table containing the smallest valid value, largest practical value, empty
value, one-past-boundary value and a representative normal value. Assert outputs
and side effects, not implementation details.

### Error path and cleanup

Inject failure through a test double or local fixture at each stage that can fail.
Verify the surfaced error, rollback/cleanup and absence of partial state. Do not
break a real dependency merely to observe failure.

### State machine and invariants

Enumerate allowed transitions. Attempt an invalid transition and verify rejection;
then execute each valid transition and verify the invariant after every step.

### Resource lifecycle

Use counters, handles, temporary directories or lifecycle hooks observable from a
test. Exercise success, early return and failure paths. Verify release exactly once
without relying on timing alone.

### Concurrency

Prefer barriers, latches, deterministic schedulers or instrumented test doubles to
sleep-based races. Bound thread/task count and runtime. For lock behavior, test a
known ordering in a subprocess with a timeout so a deadlock cannot freeze the
audit session.

### Security and integrity

Use inert test payloads and disposable data. Test rejection of malformed,
unauthorized, tampered and cross-boundary input. For cryptographic/integrity output,
alter a copy and verify rejection without exposing or reusing real secrets.

### Serialization and persistence

Test round-trip behavior, missing/extra fields, malformed/truncated data, version
compatibility and atomic failure. Use temporary storage; confirm no partial output
survives a failed write.

### Performance

Record a baseline under the same environment and dataset, warmup policy and sample
count. Change one factor, compare distribution rather than one timing, and report
noise/limitations. Never call a change faster without measurement.

## Convert proof into a permanent test

When a probe confirms a defect:

1. Reduce it to the smallest deterministic reproducer.
2. Add it in the host project's existing test convention.
3. Observe it fail before the fix.
4. Apply the smallest fix and observe it pass.
5. Run the relevant suite and retain the exact evidence in the report.

If the probe cannot become a stable automated test, record why and keep the exact
manual reproduction steps. Do not hide flakiness by rerunning until green.
