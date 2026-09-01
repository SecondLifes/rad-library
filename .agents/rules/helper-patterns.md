---
description: "RAD Library helper unit, API, test and error-handling contract"
globs: ["src/**/*.pas"]
alwaysApply: true
---

# Helper Patterns

## Naming

- Every helper unit filename and unit name begins with `help.`.
- Every public helper function or helper method begins with `_`. Exception:
  members of a vendor static class — see "Vendor helper units" below.
- Test files live under `src/test/` and append `.test` to the source
  filename: `help.date.pas` → `help.date.test.pas`.
- Names shown here are structural examples, not approved APIs. Never infer
  behavior for an example such as `TDateTime._AsMsSql`; ask the user to
  define semantics, edge cases and compatibility before implementation.

## Vendor helper units — `help.{vendor}.pas`

Helpers that wrap a **specific third-party library** live in one unit per
vendor, named after the vendor rather than after the topic:

| Unit | Covers |
|---|---|
| `help.uni.pas` | UniDAC |
| `help.mormot.pas` | mORMot2 |

One vendor, one unit. Do not split a vendor across topic-named units
(`help.json.pas`, `help.crypt.pas`) — a caller looking for "the mORMot
helpers" must have exactly one place to look, and a topic name stops being
true as soon as the second topic is added.

**Ask the user for the filename before creating one.** The vendor's short
alias is a judgement call (`mormot` vs `mormot2`, `uni` vs `unidac`), it is
permanent once other units import it, and the user owns the naming.

### Shape: helper first, static class second

1. **Prefer a class or record helper.** It keeps the vendor's own type as
   the entry point, so calls read naturally and no new name enters scope.
2. **If a helper cannot be written, declare a class named after the vendor
   alias and make every member `static`.** The class is a namespace, never
   instantiated: `TMormot.Flatten(...)`, not `TMormot.Create`.

A helper cannot be written when:

- **The target is an interface.** Delphi supports class and record helpers
  only; there is no interface helper. `IDocDict` is the case that forced
  `TMormot` into existence.
- **One API must serve several unrelated types.** A helper attaches to
  exactly one type; splitting a coherent API across several helpers to
  satisfy the rule makes it worse, not better.
- **The vendor may add its own helper later.** Only the *nearest* helper for
  a type is visible, so ours would silently hide theirs (or theirs ours)
  with no compiler diagnostic. Check for an existing helper before adding
  one, and record what you found.

Whichever shape is chosen, state the reason in the unit header. The next
reader must not have to re-derive why a static class was used where a
helper looks possible.

### Member naming

The `_` prefix rule above applies to **helper** members, where it separates
our additions from the vendor's own methods on the same type. Members of a
vendor static class do **not** take it — the class name already
disambiguates, and `TMormot._Flatten` is noise.

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
