---
description: "Library packaging standards — runtime/design-time package split, SemVer, CHANGELOG discipline, open-source license compliance"
globs: ["**/*.dpk", "**/*.dproj", "**/*.pas"]
alwaysApply: false
---

# Library Packaging, Versioning & Licensing — Rules

Use these rules when structuring, versioning, or releasing a reusable
Delphi library or component package.

RAD Library targets Delphi 13+ Win32/Win64. Keep the core dependency-free.
All project packages belong under `src/`; optional vendor packages belong
under `src/vendor/`. VCL and FMX component packages follow
`component-patterns.md`.

## Package layout

- Two-package split as the professional default: runtime (`MyLibR.dpk`,
  all component/logic units) + design-time (`MyLibD.dpk`, `*.Reg.pas`
  and editors, requires the runtime package + `designide`). Full detail:
  `vcl-component-architecture` skill, `design-time-integration.md`.
- LIB suffix `$(Auto)` — never a hardcoded compiler version.
- Unit namespace: one dotted prefix owned by the library
  (`MyLib.Core.*`, `MyLib.UI.*`); no bare unit names that can collide
  with other installed packages.
- Folder shape: `source/` (units), `packages/<DelphiVersion>/` (dpk/dproj
  per supported IDE version), `src/test/` (DUnitX project),
  `docs/`.

## Public API discipline

- The public API is every symbol reachable from outside the library —
  keep it small, consistent, predictable; hide implementation units from
  documentation and don't re-export them.
- A **breaking change** is: removing/renaming a public symbol, changing
  a signature, changing documented behavior, or removing/renaming a
  published property (DFM compatibility — see
  `vcl-component-architecture`, `streaming-and-properties.md`).
- Deprecate before removing: `deprecated 'Use X instead'` for at least
  one minor release cycle where feasible.

## Semantic Versioning

`MAJOR.MINOR.PATCH`:

| Bump | When |
|---|---|
| MAJOR | any breaking change (API or DFM streaming contract) |
| MINOR | new backward-compatible functionality |
| PATCH | backward-compatible bug fixes only |

- Version is recorded in one place (a `MyLib.Version.pas` constant or the
  package options) and referenced everywhere else — no scattered copies.
- CHANGELOG.md per release: Added / Changed / Fixed / **Breaking** —
  breaking entries state the migration path, not just the removal.

## Dependency policy (order of preference)

1. Delphi RTL/VCL and stock components
2. Dependencies the host project already uses
3. Actively maintained, license-compatible open-source libraries
4. Commercial components — **only with explicit user approval**

For every proposed external dependency state: why it's needed, why
RTL/VCL isn't enough, its license, maintenance status, vendor lock-in
impact, and the dependency-free alternative.

## Open-source license compliance

Before adapting code or shipping a dependency:

| License | Can a closed-source Delphi lib use it? |
|---|---|
| MIT / BSD / Apache-2.0 | ✅ yes — keep the notice/attribution (Apache: NOTICE file, state changes) |
| MPL-1.1/2.0 | ✅ file-level copyleft — modified MPL *files* stay MPL; common in the Delphi ecosystem (many classic libs are MPL) |
| LGPL | ⚠️ dynamic linking OK; static linking into a monolithic EXE (the Delphi norm) triggers obligations — legal review before use |
| GPL | ❌ viral for distributed closed-source binaries — do not link |
| "Free for personal use" / no license file | ❌ no license = no grant — treat as unusable |

- Record every adapted source in ACKNOWLEDGMENTS with its license.
- Never copy code verbatim from a repo without checking its license
  first — analyze the approach, verify the license, then implement
  appropriately for this project (kit-wide research rule).

## Release checklist

- [ ] Compiles clean (no hints/warnings left unexplained) on every supported Delphi version
- [ ] DUnitX suite green
- [ ] Version constant + package version + CHANGELOG all bumped consistently
- [ ] Breaking changes: MAJOR bump + migration notes
- [ ] New published properties have correct `default`s (DFM compat)
- [ ] LICENSE + ACKNOWLEDGMENTS current
- [ ] README install steps verified against a clean checkout
