# Finding Taxonomy and Audit Matrix

Use only dimensions applicable to the target. Absence of a feature the code never
promised is not a defect; keep it as a feature candidate.

## Category and severity are separate

### Categories

| Category | Meaning |
|---|---|
| **Correctness bug** | Existing behavior produces a wrong result or violates its contract. |
| **Missing guard/path** | A required boundary, failure path, cleanup or validation is absent. |
| **Dead or senseless code** | Unreachable, unused, contradictory or non-functional code. |
| **Project-rule violation** | A measured violation of a governing host-project rule/tool diagnostic. |
| **Coherence gap** | Sibling paths or the existing API enforce the same invariant inconsistently. |
| **Feature candidate** | New capability not promised by the existing contract; never disguised as a defect. |

### Severity

| Severity | Test |
|---|---|
| **Critical** | Plausible data loss, security/privacy breach, unrecoverable corruption, deadlock, unsafe memory/lifecycle failure, or core-function break. |
| **High** | Wrong externally visible result, serious compatibility break, or common unhandled failure. |
| **Medium** | Bounded defect, fragile behavior or maintainability problem with a concrete failure scenario. |
| **Low** | Local clarity, efficiency or consistency improvement with no current material failure. |

Never infer severity from dramatic wording. Tie it to reachability, impact and
evidence.

## Applicable audit dimensions

Check each dimension only when the target can exhibit it:

1. **Correctness and boundaries** — empty, nil/null, zero, min/max, last element,
   overflow/underflow, encoding and locale-sensitive input.
2. **State and control flow** — every writer/reader, impossible states, stale flags,
   unreachable branches, retries and cancellation.
3. **Error handling and cleanup** — partial failure, exception paths, rollback,
   resource release and error propagation.
4. **Data integrity and privacy** — validation, authorization, tenant/user
   isolation, secret/PII exposure and destructive writes.
5. **Security** — injection, traversal, unsafe deserialization, confused-deputy
   behavior and trust-boundary violations.
6. **Concurrency** — races, lock order, reentrancy, atomicity, starvation and
   deterministic shutdown.
7. **Resource lifecycle** — ownership, leaks, double release, dangling access,
   subscriptions, handles and temporary files.
8. **Performance** — algorithmic growth, repeated I/O, N+1 work, unbounded memory,
   hot-path allocation and unnecessary serialization. Require measurement before
   asserting an optimization result.
9. **API and compatibility** — callers, public signatures, error/data contracts,
   version/migration expectations and backward compatibility.
10. **Observability** — actionable errors, correlation/context, sensitive-log
    redaction and silent failure.
11. **Accessibility/UI behavior** — keyboard, focus, semantics, state feedback and
    error recovery when a user interface is in scope; visual direction belongs to
    the design skills.
12. **Testability and operability** — deterministic seams, isolated dependencies,
    configuration discoverability and safe local verification.

## Standard finding record

```text
ID: stable identifier
Category: one category above
Severity: Critical | High | Medium | Low
Location: file:line and symbol
Verdict: VERIFIED | PARTIALLY_VERIFIED | UNVERIFIED
Evidence type: build | test | probe | source | graph/tool | live documentation
Failure scenario: concrete input/state → observed or predicted result
Dependency/caller impact: what can be invalidated
Recommendation: smallest coherent correction
Verification command: exact focused check
```

## Mechanical versus design decision

A change is mechanical only when it preserves existing public contracts and
restores or implements already-approved behavior. Ownership, public signature,
data/error policy, migration, compatibility and architecture changes are design
decisions even when the code edit is small.
