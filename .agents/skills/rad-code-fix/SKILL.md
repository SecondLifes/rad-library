---
name: rad-code-fix
description: >-
  Audits complete source files and their repository-internal dependencies, then
  repairs approved findings, implements a requested enhancement, or applies an
  already-written findings report — always in dependency order, always proven by
  measurement. Establishes a baseline first, finds correctness, safety, lifecycle,
  performance, compatibility and coherence defects, re-verifies any finding that
  arrived from elsewhere before touching it, writes red-first regression tests,
  and reports exact evidence and limits. Use it for whole-file audits and deep
  checks, for "find and fix everything in this file", for improving or extending
  existing code, and for acting on a report someone else produced — including
  "apply this report", "fix these findings", "su raporu duzelt", "bu bulgulari
  uygula". Do not use it for diff or pull-request-only review, or for pure visual
  design work.
---

# Code Fix — whole-file, dependency-aware, measured

Provide the process; let the host project provide language, architecture,
toolchain, style and test standards. Never invent a project rule from memory.

## Modes and boundaries

Infer the narrowest mode that satisfies the request:

| Mode | Outcome |
|---|---|
| **Audit-only** | Find and prove defects; report them without writing code. |
| **Audit + Fix** | Audit first, obtain approval, then repair approved findings. |
| **Enhancement** | Turn a requested feature into acceptance criteria, implement it, and prove it without regressing existing behavior. |
| **Apply a report** | Take findings someone else already wrote down, re-verify each one against the code as it is now, then repair the approved survivors. |

Discovery is the expensive part, so the mode boundary is really about **whether
the findings already exist**. When the user hands over a report, do not audit
from scratch — the report is the scope, and Phase 3b explains why it still has
to be checked rather than trusted.

- A diff/PR-only review belongs to the host's diff-review workflow.
- Visual direction and UI aesthetics belong to `frontend-design`; UI guideline
  compliance belongs to `web-design-guidelines`. This skill may still audit or
  implement UI behavior, accessibility and integration correctness.
- Load stack-specific skills when present. They supply domain rules; this skill
  owns orchestration, evidence, scope and verification.

## Usage

| The user says | Mode | What happens |
|---|---|---|
| "audit `parser.py` and everything it depends on" | Audit-only | Baseline, whole-file read, findings with evidence. **No file is written.** |
| "find and fix everything in `OrderService.cs`" | Audit + Fix | Findings first, then the mechanical/design split for approval, then one atomic item at a time |
| "apply `share/analysis/.../codex_v1.md` to the skill it reviews" | Apply a report | Report intake, per-finding re-verification, then the same approval and execution path |
| "add a `--dry-run` flag to the importer" | Enhancement | Acceptance criteria and non-goals first, then red-first tests, then implementation |
| "review this PR" | *none* | Belongs to the host's diff-review workflow; say so rather than auditing whole files |

Two shapes worth recognising because they are easy to mis-serve:

**"Fix everything" without a report** is Audit + Fix, not Apply a report. There
is nothing to intake; discovery happens here.

**"Apply this report" where half the findings are stale** is the common case,
not the exception. Reports are written against a snapshot, and the code moves.
Phase 3b exists for exactly this, and reporting the discards is part of the
deliverable — a user whose report is half-stale needs to know that more than
they need the fixes.

### Worked example — applying a report

Input: a findings report with eleven entries, written a week ago.

1. **Intake** — read it in full, extract each finding with the report's own
   identifier (`CRITICAL-01`, `ERROR-02`, …). Those identifiers become the
   vocabulary for every later message, so the user can match your words to
   their document.
2. **Re-verify** — open the code for each. Two were fixed since the report was
   written; one moved to another file and its line numbers no longer resolve;
   eight still hold.
3. **Report the discards first** — "2 of 11 no longer hold, here is why" is the
   most valuable sentence in the run, because it tells the user their report is
   stale and worth regenerating.
4. **Approve** — the eight survivors split into mechanical and design; the
   design ones are asked about individually.
5. **Execute** — one finding at a time, red-first, checkpoint each.
6. **Report** — closed, discarded, reverted, still open, with the measurement
   behind each.

## Phase 0 — Establish ground truth and safety

Determine these facts before analysis or execution:

1. Language, manifests, runtime and toolchain.
2. Project-owned build, typecheck, lint and test entry points.
3. Existing test framework, layout, naming and assertion style.
4. Governing instructions: `AGENTS.md`, `CLAUDE.md`, repository rules,
   `.editorconfig`, contribution docs, CI and lint configuration.
5. Version-control state for every file in the prospective write scope.

### Protect work already in progress

- Record `git status` and the target diff before writing. Treat every existing
  modification as user-owned.
- Re-read and hash a file immediately before editing it. If it changed since the
  plan was approved, stop that item and re-plan from the new content.
- Never use reset, checkout, blanket restore, stash, or reformatting to clear a
  dirty tree. Roll back only bytes introduced by this session.

### Treat repository commands as untrusted

Read the script or CI target behind a command before running it, then classify it:

| Class | Examples | Action |
|---|---|---|
| **Read-only** | File/graph/history inspection | Run normally. |
| **Local and reversible** | Compile, typecheck, lint, isolated unit tests, bounded probes | Run with a timeout and resource limits after checking the script. |
| **External or hard to undo** | Install, code generation over tracked files, migration, deploy, live service/database, credentials, paid API, external network | Explain the exact effect and obtain explicit approval first. |

Never expose secrets in commands, diagnostics or reports. Use isolated fixtures,
temporary data and test credentials. A probe that can deadlock, hang or exhaust
resources must run with deterministic coordination and a timeout. If safe live
execution is unavailable, use static evidence and label the limitation.

### Verify external behavior live

When a finding or implementation depends on a library, framework, SDK, API or
CLI contract, follow the host instructions for current documentation. Use
Context7 when available, otherwise official documentation, and cite the source
with the finding. Training-data recall is not evidence.

## Phase 1 — Freeze scope and build the dependency plan

Keep three scopes explicit:

- **Understanding scope** — dependencies, callers, tests and rules that may be
  read to understand the target.
- **Finding scope** — files/components that may receive findings.
- **Write scope** — only files the user authorized this session.

Resolve repository-internal dependencies with the host's code-intelligence graph
when available, then language-native/compiler tooling, then text search as a
fallback. Include callers before proposing a public signature or contract change.
External/vendor source stays outside the audit unless explicitly included.

Use the graph only when repository instructions declare it and the target is known
to be covered by a current index. Skip graph calls for untracked, newly created,
temporary/generated or otherwise stale-index targets; go directly to language-native
tooling and targeted text search. For other targets, limit graph discovery to one
bounded lookup; if it reports no coverage, fall back immediately. Never block a
small task on indexing, an unbounded MCP call or repeated graph queries. Scale
preparation to risk: a single-file task needs only its nearest governing rules,
manifest/commands and relevant dependency surface.

Before writing:

1. Build a dependency DAG for every planned change.
2. Detect and report cycles; do not pretend a cyclic graph has a valid topological
   order.
3. Order acyclic work leaf-first, from the least-dependent base component toward
   consumers. Within one dependency layer, order by severity and risk.
4. Define one checkpoint per layer and one verification command per item.
5. Present an inventory and get scope approval if the graph crosses a package/
   module boundary or materially expands the named target/write set.

Finish this plan before editing so later work does not repeatedly invalidate
earlier work.

## Phase 2 — Measure the baseline

After command safety and scope are known, run the safest project-owned build,
typecheck, lint and tests that establish the starting state. Record:

- exact commands, environment and platform;
- diagnostic counts and messages;
- passing, failing, skipped and flaky tests;
- pre-existing failures outside the write scope.

Do not require project-wide zero diagnostics when the baseline is already noisy.
The finish line is no new diagnostics or failures plus closure of approved work.

If execution is unavailable, continue with static analysis. Grade evidence on
two independent axes:

- **Verdict:** `VERIFIED`, `PARTIALLY_VERIFIED`, `UNVERIFIED`.
- **Evidence:** build, test, probe, source inspection, graph/tool output, or
  current external documentation.

Only runtime-dependent claims become unverified merely because the project cannot
build. Source-observable facts remain verifiable.

## Phase 3 — Audit, intake a report, or specify the enhancement

Read each target file in full; diagnostics are evidence, not the audit boundary.
Trace state across every writer and reader rather than inspecting functions in
isolation. Apply only the relevant dimensions in
`references/finding-taxonomy.md` and use `references/probe-patterns.md` when a
behavioral claim needs measurement.

Each audit finding includes:

- stable ID, category and severity;
- exact `file:line` location;
- concrete failure scenario;
- verdict and evidence type;
- dependency/caller impact;
- smallest proposed correction.

Do not label an unrequested new capability as a defect. In Audit-only or Audit +
Fix mode, list it separately as a feature candidate.

### Phase 3b — When the findings arrived in a report

A report is a claim about the past. It was written against a version of the
code, and that version may not be the one in front of you: the defect may have
been fixed, refactored around, or moved. Repairing a finding that no longer
holds means editing working code to remove a defect that is not there — which
is worse than doing nothing, because it looks like progress.

Read the report **in full** before touching anything; a finding's real
qualification is often three paragraphs below its heading. Extract each entry
with the report's own identifier, its claimed location, its claim, and its
recommendation — keeping the recommendation separate from what you decide to
do. If the report has no identifiers, assign your own and say so.

Then give every finding one of these verdicts by looking at the code:

| Verdict | Means | What to do |
|---|---|---|
| **STILL HOLDS** | Present as described | Carry into Phase 4 |
| **PARTIALLY HOLDS** | Real, but the description drifted — moved lines, renamed symbols, narrower or wider than claimed | Carry forward with your corrected description, and say what changed |
| **NO LONGER HOLDS** | Already fixed, or restructured past | Do not touch it. Report it as resolved before this session |
| **CANNOT VERIFY** | Needs something unavailable — a platform, a licence, an external-class command | Report as unverifiable, with what would settle it |

Carry forward any uncertainty the report's own author declared. A finding they
were unsure about does not become certain by being copied into your list.

**Report the discards as prominently as the repairs.** "9 of 11 applied" hides
that two were already fixed; naming which two, and why, tells the user their
report has aged.

A report entry that asks for a capability the code never claimed is a feature
request wearing a finding's clothes. Route it to Enhancement mode with the
user's agreement, or leave it out — do not implement it silently as a repair.

For Enhancement mode, define before implementation:

- acceptance criteria and non-goals;
- current behavior and compatibility constraints;
- affected API/data contracts, callers and dependency layers;
- migration and rollback needs;
- red-first tests and final verification matrix;
- design decisions that require the user's choice.

The user's explicit feature request authorizes that feature's normal implementation,
not unrelated refactors or silent breaking changes.

## Phase 4 — Approval and execution plan

Audit-only stops after delivering findings. For changes, split the ordered list:

1. **Mechanical changes** — restore or add agreed behavior without changing an
   unrelated contract; these may be approved in bulk.
2. **Design decisions** — change ownership, public signatures, error/data policy,
   compatibility or architecture; present each separately.

An explicit “fix/apply everything automatically” authorizes confirmed mechanical
changes in the agreed scope. It never authorizes destructive operations, external
effects, removals, breaking changes or unresolved design forks.

## Phase 5 — Execute one atomic item at a time

For each approved item in DAG order:

1. Re-read/hash affected files and confirm the item is still current.
2. For observable behavior, write the regression or acceptance test first and
   run it to observe the expected failure (**red**). A test green from birth is
   not proof unless an independent mutation/path check demonstrates it exercises
   the changed path.
3. For non-behavioral changes, name and run the equivalent failing check instead
   (lint diagnostic, schema validation, typecheck or structural assertion).
4. Apply the smallest coherent change; do not mix neighboring cleanup into it.
5. Run the focused check to observe success (**green**), then refactor only within
   the approved item while keeping it green.
6. Inspect the diff for scope, encoding, newline and unrelated formatting drift.
7. Record an item checkpoint: changed files, evidence and diagnostic delta.

If an item breaks a previously passing consumer, isolate the cause and revise only
that item while each iteration reduces the failure set. If the same failure repeats,
evidence stops improving, or a safety/permission boundary is reached, roll back only
this session's item patch, record it as open, and continue without leaving the tree
broken. Never destroy user changes to manufacture a clean rollback.

Comments are reserved for non-obvious invariants and safety constraints the code
cannot express. Follow project style. Propose rule/reference documentation updates
separately; do not widen the write scope automatically.

## Phase 6 — Staged verification and convergence

Use increasing verification cost:

1. Focused test/check after each item.
2. Relevant module/package suite after each dependency layer.
3. Full existing suite at the final gate when safe and feasible.

For a suspected flaky test, repeat the exact command in the same environment up
to three times and report every outcome; never rerun until green and hide failures.
Do not claim platforms or configurations that were not exercised.

After implementation, run a fresh audit pass over the agreed finding/write scope.
If it finds a new actionable defect caused by the changes, add it to the DAG and
repeat the item loop. Convergence is reached when a fresh pass finds no new
actionable issue, approved items are closed or explicitly left open, diagnostic
delta is non-regressive, and staged tests meet the baseline plus new expectations.
Stop honestly on non-convergence or an external blocker; never loop without
measurable progress.

## Phase 7 — Report the verified result

Report:

- findings/features by category and final status;
- dependency order actually used;
- each change and its measured evidence;
- baseline versus final diagnostics/tests;
- reverted, blocked, deferred and out-of-scope items;
- untouched files and why;
- platforms, configurations and behaviors not measured.

Say “verified within the agreed scope” only when the convergence gate passes.
Never claim “perfect”; state exactly what was verified and how.

## Hard rules

- Preserve the original encoding, BOM and newline convention of every edited file.
- Re-read immediately before editing and inspect the final diff.
- Keep one work item attributable to one checkpoint.
- Never widen write scope, reformat unrelated code or overwrite user changes.
- Never execute an external/hard-to-undo command without explicit approval.
- Never claim a test, platform or behavior was verified unless it actually ran.

## References

- `references/finding-taxonomy.md` — categories, severity, audit matrix and
  standard finding schema.
- `references/probe-patterns.md` — safe behavioral probes and conversion into
  permanent tests.
- `references/toolchain-map.md` — stack discovery, project-owned commands,
  dependency tooling and live-documentation requirements.
