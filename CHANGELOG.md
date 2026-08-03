# Changelog

All notable changes to RAD Library AI Spec-Kit are documented here.

## [0.1.1] - 2026-08-03

### Fixed

- `CONTRIBUTING.md`/`.tr-TR.md` and `SECURITY.md`/`.tr-TR.md` linked to
  `github.com/SecondLife/rad-library` — a typo'd owner name (missing
  trailing `s`) that 404s. The real authenticated owner is `SecondLifes`;
  every link now points there. Root cause was a stale
  `github_username_or_org` value in the workspace's `template-vars.json`,
  already fixed upstream — this propagates that fix to files generated
  before the correction.

## [0.1.0] - 2026-07-24

### Added

- Initial commit-pinned derivation from the approved base kit.
- Delphi 13+ Win32/Win64, VCL/FMX library and component contract.
- Helper, component, test, performance and optional vendor-integration rules.
- FMX, JEDI and mORMot2 guidance; JEDI/mORMot2 remain conditional pending
  local Delphi 13+ compilation.
