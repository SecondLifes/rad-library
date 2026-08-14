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

## Prohibitions

- ❌ `with` statement
- ❌ Global variables
- ❌ Generic Catch (`except on E: Exception`) in business/domain code — allowed only at top-level boundaries (thread roots, request handlers, application-level last-resort handlers) where it must log and re-raise or translate, never swallow
- ❌ Magic numbers — use constants
- ❌ Hardcoded strings — use `resourcestring` or constants
- ❌ Methods > 20 lines
