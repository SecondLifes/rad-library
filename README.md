# RAD Library AI Spec-Kit

An AI specification kit for building a compact, stable and fast reusable
Delphi library/component set. It targets Delphi 13+ (current stable release
preferred), Win32/Win64, VCL and FMX.

[Türkçe](README.tr-TR.md)

## Contract

- Dependency-free core; optional vendor integrations are isolated.
- Helper units use `help.*`; public helper functions/methods begin with `_`.
- Component classes use `TRAD`; runtime/design-time packages are separate.
- All project paths live under `src/`; tests under `src/test/`, vendor
  adapters under `src/vendor/`.
- Test filenames append `.test` to their source filename.
- Public methods need success, boundary and error-path DUnitX coverage.
- Performance claims require recorded Release Win32/Win64 benchmarks.
- Examples describe structure only. The AI must not invent APIs or semantics.

Optional integration guidance covers UniDAC, DevExpress, TMS, FastReport,
JEDI JCL/JVCL and mORMot2. JEDI and mORMot2 remain conditional until the
user's exact versions compile with Delphi 13+.

## Start

Read `AGENTS.md`, then use the matching rule under `.agents/rules/` and skill
under `.agents/skills/`. `src/README.md` documents the actual project
layout — `src/` now contains the real **Rad Core** library (see
Provenance below), not just a placeholder.

## Provenance

Two independent lineages meet in this kit:

- **The AI instruction system** was derived through `rad-template-builder`
  Derivation Mode v2 from **Delphi Library AI Spec-Kit**
  (`delphi-library-expert`) at commit
  `b9795465c997ea841a8b319a9931256a7f35bd5c`. See `derivation.json`. The
  inherited MIT license is preserved.
- **The library code under `src/`** is imported from **Rad Core |
  Enterprise Delphi Framework**, the separately maintained working
  repository this kit's own rules (`help.*` naming, `TRAD` components,
  vendor isolation) were originally modeled on. See `ACKNOWLEDGMENTS.md`.
