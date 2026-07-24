---
description: "Optional vendor integration boundary and verification policy"
globs: ["src/vendor/**/*.pas", "src/vendor/**/*.dpk", "src/vendor/**/*.dproj"]
alwaysApply: true
---

# Vendor Integration

The core is dependency-free. UniDAC, DevExpress, TMS, FastReport, JEDI
JCL/JVCL and mORMot2 are optional, feature-scoped integrations under
`src/vendor/`.

- Never make a vendor package a transitive dependency of the core.
- Keep vendor runtime/design-time packages separate where components are
  installed into the IDE.
- Preserve vendor exception causes and document thread-safety limits.
- Do not redistribute proprietary source, binaries, credentials or license
  material.
- Run vendor tests separately and state the exact installed version and
  compiler used.
- JEDI and mORMot2 remain conditional until compiled with Delphi 13+ on the
  user's machine. Documentation compatibility is not runtime verification.
