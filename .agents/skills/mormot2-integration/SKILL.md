---
name: mormot2-integration
description: Design or review optional mORMot2 integration boundaries for RAD Library with explicit compatibility validation.
---

# mORMot2 Integration

**mORMot2 is a base dependency of this library, not an optional vendor.**
`src/core/` calls it directly — no adapter, no conditional compilation, no
justification needed. The `src/vendor/` isolation rule applies to UniDAC,
DevExpress, TMS, FastReport and JEDI; it never applied to mORMot, though this
file used to say otherwise. See `.agents/rules/vendor-integration.md`.

Upstream validation evidence available during kit creation covered Delphi
through 12.3, so Delphi 13+ compatibility remains conditional until locally
compiled.

## Usage

1. Read `.agents/rules/vendor-integration.md`.
2. Identify the exact mORMot2 feature and installed revision.
3. Read all three references. `references/verified-api-traps.md` lists APIs
   that compile cleanly and fail **silently** at runtime — check it before
   using any crypto, and add to it whenever a probe uncovers another one.
4. Compile and execute success/error paths on Win32/Win64 before claiming
   compatibility.

## An API that looks right is not evidence

Every entry in `verified-api-traps.md` was found by writing a probe and
running it, and each one had already passed a plausible read-through. The
crypto entry in particular would have shipped a documented "tamper
detection" guarantee that the code did not provide. When the claim is a
security property, prove it by attacking your own output — flip bits and
confirm the failure — rather than by reading the function name.
