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

## Prohibitions

- ❌ `with` statement
- ❌ Global variables
- ❌ Generic Catch (`except on E: Exception`) in business/domain code — allowed only at top-level boundaries (thread roots, request handlers, application-level last-resort handlers) where it must log and re-raise or translate, never swallow
- ❌ Magic numbers — use constants
- ❌ Hardcoded strings — use `resourcestring` or constants
- ❌ Methods > 20 lines
