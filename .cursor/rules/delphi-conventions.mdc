---
description: "Delphi Object Pascal conventions — naming, style, formatting"
globs: ["**/*.pas", "**/*.dpr", "**/*.dpk"]
alwaysApply: true
---

# Delphi Conventions — Rules

## Nomenclatura

- **PascalCase** for all identifiers
- Reserved words in **lowercase** (`begin`, `end`, `if`, `nil`, `string`)
- Prefixes: `T` (classes), `I` (interfaces), `E` (exceptions), `F` (private fields), `A` (parameters), `L` (local variables)
- General units use clear English dotted names. Helper units begin with
  `help.` as required by `helper-patterns.md`.
- Reusable component classes begin with `TRAD`.

## Formatting

- Indentation: 2 spaces
- Limit: 120 characters per line
- `begin` on the same line for `if`/`for`/`while` blocks
- `begin` on new line for method body

## Unit Mandatory Sections

```pascal
unit Nome;
interface
uses { ... };
type { Enums → Interfaces → Classes }
implementation
uses { imports extras };
{ Implementação agrupada por classe }
end.
```

## Documentation

- XMLDoc for public methods and properties
- Comments, XMLDoc and code identifiers default to English.
- Do not comment self-explanatory code

## Memory Management

- `try/finally` with `Free` for temporary objects
- Interfaces for automatic reference counting
- Local variables with prefix `L`
- Owner pattern for visual components

## RTTI blind spots (verified by execution, Delphi 37.0 / Athens)

Any RTTI-driven code — generators, serializers, ORM mapping, DI containers,
property inspectors — must account for these. All three were confirmed by
compiling and running probe programs, not by reading documentation.

**1. Enumerations with explicitly assigned values produce no RTTI at all.**

```pascal
TAESKeyLength = (kl128 = 128, kl192 = 192, kl256 = 256);   // no RTTI
TKeyLength    = (kl128, kl192, kl256);                     // has RTTI
```

The compiler *accepts* a `published` property of such a type but emits no RTTI
record for it. At runtime the property is invisible to `GetDeclaredProperties`,
`GetProperties` **and** the legacy `TypInfo.GetPropList`. There is no exception —
it is silently absent. Prefer contiguous enumerations for any type that reaches a
published property, a serialized field, or an RTTI-driven mapping. When a
third-party type cannot be changed (e.g. TMS `TAESKeyLength`, `THashSize`), the
only recovery is to parse the declaring `.pas` source and reconcile it against
what RTTI reports.

**2. The same blindness corrupts method signatures, silently.**

- A method taking a parameter of an RTTI-less type reports an **empty parameter
  list** — generated pass-through code fails to compile (E2035).
- A function returning an RTTI-less type reports `MethodKind = mkProcedure` with
  `ReturnType = nil` — generated code compiles and silently discards the result.

**3. `TRttiParameter.ParamType` is `nil` for untyped parameters** (`var Buf`), and
open-array parameters carry `pfArray` with `ParamType` naming the *element* type.
Dereferencing `ParamType.Name` without a nil check is an access violation; ignoring
`pfArray` produces a wrong signature that still compiles. Dynamic arrays do **not**
set `pfArray`, so the two are distinguishable.

Also: `TRttiType.QualifiedName` raises `ENonPublicType` for types not declared in a
unit's interface section (e.g. inside a `.dpr` or an `implementation` block). Guard it.

## Unit name qualification in generated `uses`

`Classes` and `System.Classes` are the **same unit** (unit scope names). Emitting
both in one `uses` clause is `E2004 Identifier redeclared`. RTTI reports the
qualified form while legacy/vendor sources declare the bare form, so any tool that
merges the two lists must treat them as duplicates. Applies to the standard RTL
roots (`System`, `Winapi`, `Vcl`, `Data`, `Xml`, `Web`, `Soap`, `FMX`, `REST`, ...);
do not collapse arbitrary `Foo.Bar` / `Bar` pairs, which may be genuinely different.

## Block comments that quote code (verified by compilation)

Neither Delphi block-comment form nests, and each ends at its first closing
delimiter. A comment quoting JSON, DFM or Pascal therefore closes early, and the
failure is confusing: `E2029 'INTERFACE' expected` on the following line, then
`E2038 Illegal character in input file`.

- **Brace form** — a `}` anywhere in the sample ends the comment. A JSON example
  such as `{"name":"Ahmet"}` is enough.
- **Star-paren form** — writing the closing star-paren sequence literally inside
  the text ends the comment, *including* when the text is documenting the
  delimiters themselves.

Both were hit and reproduced in this kit. Rules: prefer the star-paren form for
any comment containing a code sample, and never write either closing delimiter
literally inside a comment — describe the delimiters in words instead.

## Window procedures: three traps, all measured on Win32 + Win64

Reconstructing a window procedure by hand — a common move when a VCL field you
need is `private` — fails in three independent ways. All three were measured by
running a probe against a live MDI form, not read from documentation.

**1. `GetWindowLong` truncates the pointer on Win64.** It returns `Longint`.
Measured on the same window: `GetWindowLongPtr` gave `$21777E40F06`,
`GetWindowLong` gave `$77E40F06` — the top 32 bits were silently lost. Calling
that value as a procedure jumps to an invalid address. Win32 shows no
difference, so the bug hides until a 64-bit build. Always `GetWindowLongPtr` /
`SetWindowLongPtr` for `GWL_WNDPROC`, and hold the result in `NativeInt`, never
`Longint`/`DWORD`.

**2. Reading `GWL_WNDPROC` after the VCL has subclassed returns the VCL hook,
not the original.** Measured on an MDI client window: the value at
`GetWindowLongPtr(ClientHandle, GWL_WNDPROC)` sat in the application's own
address space, while `GetClassLongPtr(ClientHandle, GCL_WNDPROC)` — the real
`MDICLIENT` class procedure — sat in `user32`. Feeding the first to
`CallWindowProc` re-enters the hook. Anything the VCL captured *before*
subclassing (`FDefClientProc` and friends) cannot be recovered this way; call
`inherited` and let the VCL use its own saved pointer.

**3. A form's handle is not its client area's handle.** `Self.Handle` and
`ClientHandle` returned different procedures on both platforms. Passing one
window's procedure together with another window's handle compiles, runs, and
dispatches the wrong code against the wrong window.

**Consuming a message can be load-bearing.** Not calling `inherited` looks like
an oversight and is sometimes the only thing preventing a feedback loop: the
default handler re-applies the state the override just cleared, the resulting
`SWP_FRAMECHANGED` regenerates the message, and it never settles. Measured in
this kit at 796,240 handler entries in 30 seconds at 100% CPU. Before "fixing" a
missing `inherited`, check whether the default handler writes back the state
being changed — and when the omission is deliberate, say so in a comment with
the measurement, or the next reader will fix it again.

## Set constructors stop at 255 (verified by compilation)

A set's element ordinal must fit in `0..255`, so an `in [...]` test against
anything larger is a compile error, not a runtime surprise:

```pascal
if not (AKeySizeBits in [128, 192, 256]) then   // E1012 — 256 is out of range
if (AKeySizeBits <> 128) and (AKeySizeBits <> 192) and
   (AKeySizeBits <> 256) then                   // correct
```

The message is `E1012 Constant expression violates subrange bounds`, preceded
by `W1012` as a warning on the same line, and it points at the whole
expression rather than the offending element — so the cause is not obvious
when the set has several members and only one is over the limit.

This has now been hit twice in this kit: once on a `$0100` variant-type
constant, once on an AES key-size check. Any `in [...]` over numeric
constants, bit masks or type codes needs a glance at whether every member is
under 256; the moment one is not, rewrite as explicit comparisons or a
`case` statement.

## An identifier shadows a same-named routine, case-insensitively

Delphi identifiers are case-insensitive, so a local variable `c` hides a
unit-level procedure `C` for the whole scope. The call site still looks
correct, and the compiler reports the *consequence*, not the cause:

```
E2066 Missing operator or semicolon
E2014 Statement expected, but expression of type 'RawByteString' found
```

Reading that message it is easy to hunt for a missing semicolon that is not
there. When an error like this lands on a line whose syntax is plainly fine,
check whether one of its identifiers is also declared locally under a
different case. Single-letter locals (`c`, `i`, `s`) next to single-letter
helpers are the usual pairing — give one of the two a longer name.

## Exposing a record-typed lock or state: pointer, never value (measured)

A property that hands out a **record** — a lock, a counter, any mutable state —
must return `P<Record>`, not the record. Three shapes were compiled and run on
Delphi 37.0 Win32, each calling a mutating method three times:

| Property shape | Real field after 3 calls |
|---|---|
| `read GetRecByValue` (getter returns the record) | **0** |
| `read FField` (read specifier is the field itself) | 3 |
| `read GetPtr` (getter returns `P<Record>`) | 3 |

The value-returning getter mutates a temporary that dies at end of statement.
It compiles, runs, emits no warning and protects nothing — for a lock that
means every "guarded" section runs unguarded. The field-backed form happens to
work because the compiler reaches the field directly, but it breaks the moment
someone writes `L := Obj.Safe;` (measured: the copy's counter advanced, the
original's did not), and it cannot be used at all when the getter must be
virtual — which is exactly what a shared lock needs (see below).

Applies to `TRadLock`/`TRadOSLock` in `rad.core`, and to any record carrying
counters, handles or ownership.

## One data structure, one lock — route it through a virtual getter

When objects in a hierarchy share the *same* underlying data — a child JSON
document that points into its parent's tree, a view over a parent buffer —
giving the child its own lock means two locks guarding one structure, and
writers through parent and child never see each other. Neither compiler nor
test notices; only a race in production does.

`TAbstractLockable` therefore routes every lock method through a **virtual**
`GetLock: PRadLock`. A child overrides it to return the root's lock and holds
an interface reference to the root so the pointer cannot dangle. Anything that
does not share data overrides nothing.

Two regression assertions in this kit exist purely to keep that honest
(`rad_jsonthread` 11 and 14, `rad_jsoncontract` 05): with the override removed,
a writer going through the child stops blocking on the root's held write lock,
and a child of a thread-safe root starts reporting `ThreadSafe = False`. Both
were verified to fail before passing.

## Interfaces: a contract can inherit a lock surface (verified)

`IJson = interface(ILockable)` works and costs the implementer nothing: a class
descending from a base that already implements `ILockable` satisfies the derived
interface without redeclaring a single lock method. A property whose read
specifier is a method of the *ancestor* interface (`property ThreadSafe: Boolean
read IsThreadSafe;`) also compiles. Both were compiled and run before being
relied on.

Prefer this over making callers discover the capability through
`Supports(X, ILockable, ...)` when locking is part of what the type is for —
grouping several calls under one lock is otherwise invisible in the API.

## Prohibitions

- ❌ `with` statement
- ❌ Global variables
- ❌ Generic Catch (`except on E: Exception`) in business/domain code — allowed only at top-level boundaries (thread roots, request handlers, application-level last-resort handlers) where it must log and re-raise or translate, never swallow
- ❌ Magic numbers — use constants
- ❌ Hardcoded strings — use `resourcestring` or constants
- ❌ Methods > 20 lines
