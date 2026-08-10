---
description: "RAD Library helper unit, API, test and error-handling contract"
globs: ["src/**/*.pas"]
alwaysApply: true
---

# Helper Patterns

## Naming

- Every helper unit filename and unit name begins with `help.`.
- Every public helper function or helper method begins with `_`.
- Test files live under `src/test/` and append `.test` to the source
  filename: `help.date.pas` → `help.date.test.pas`.
- Names shown here are structural examples, not approved APIs. Never infer
  behavior for an example such as `TDateTime._AsMsSql`; ask the user to
  define semantics, edge cases and compatibility before implementation.

## API discipline

- Keep the public surface small, predictable and documented with XMLDoc.
- Do not add hidden global state, UI dependencies or mandatory logging to
  core/helper units.
- Never swallow an exception. Preserve the original cause when translating
  vendor errors.
- `_Try...` forms and an `ERADLibrary` exception hierarchy are optional
  design choices, not permission to invent signatures.

## Verification

Every approved public method requires DUnitX success, boundary and error
tests. Claims about speed require the benchmark protocol in
`performance.md`; code without compilation/execution evidence is
unverified.
