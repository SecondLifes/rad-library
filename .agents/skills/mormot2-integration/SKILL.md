---
name: mormot2-integration
description: Design or review optional mORMot2 integration boundaries for RAD Library with explicit compatibility validation.
---

# mORMot2 Integration

mORMot2 support is optional. Upstream validation evidence available during
kit creation covered Delphi through 12.3, so Delphi 13+ compatibility remains
conditional until locally compiled.

## Usage

1. Read `.agents/rules/vendor-integration.md`.
2. Identify the exact mORMot2 feature and installed revision.
3. Read both references.
4. Keep the adapter under `src/vendor/` and the core dependency-free.
5. Compile and execute success/error paths on Win32/Win64 before claiming
   compatibility.
