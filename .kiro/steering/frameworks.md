# Frameworks — RAD Library

- Delphi 13+; current stable release preferred.
- Win32/Win64, VCL and FMX.
- DUnitX tests under `src/test/`.
- VCL/FMX runtime/design-time component package pairs.
- Optional integrations under `src/vendor/`: UniDAC, DevExpress, TMS,
  FastReport, JEDI JCL/JVCL and mORMot2.
- JEDI/mORMot2 remain conditional until locally compiled with Delphi 13+.

Use `.agents/rules/vendor-integration.md` and the matching skill. Never
couple the core to a vendor package.
