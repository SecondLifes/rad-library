# Changelog

All notable changes to RAD Library AI Spec-Kit are documented here.

## [Unreleased]

### Fixed

- **Claude Code could not discover any of this kit's skills.** It looks only
  under `.claude/skills/`; `.agents/skills/` is not one of its discovery
  locations, so every skill here was unreachable by trigger matching and only
  worked if the user typed the generated `/<skill-name>` wrapper by hand.
  `tools/generate-ai-configs.ps1` now creates one junction (Windows, no
  elevation needed) / symlink per skill under `.claude/skills/`, pointing back
  at `.agents/skills/`. The links are gitignored and regenerated after a clone,
  so the "symlink degrades on clone" hazard that keeps rules as copies does not
  apply. Verified against `code.claude.com/docs/en/skills`.
- **Cursor ignored every rule in this kit.** `.cursor/rules/` held `.md` files;
  Cursor recognizes only `.mdc` there and silently skips anything else. The
  frontmatter was already correct — only the extension was wrong. The generator
  now writes `.mdc` and sweeps the old `.md` copies instead of leaving both.
  Verified against `cursor.com/docs/rules`.
- **Gemini CLI read nothing.** The AI-tool table pointed it at
  `.gemini/rules/project-rules.md`, but Gemini CLI builds context from the
  `GEMINI.md` hierarchy. Added a root `GEMINI.md` that imports that file rather
  than duplicating it. Verified against `geminicli.com/docs/cli/gemini-md`.
- **`.claude/settings.json` used invented keys.** `allowCommands`/`denyPaths`
  are not Claude Code settings, so the advertised `.env`/`.key` protection and
  the pre-approved generator command never existed. Rewritten to the real
  `permissions.allow`/`permissions.deny` schema.
- Corrected the false claim, repeated across this kit's rules, `AGENTS.md`,
  `docs/ai-ignore-strategy.md`, the READMEs and the generator itself, that
  `.agents/skills/` "is read as a fallback location natively by every supported
  tool." It is not, and that assumption is what left the skills unreachable.
- Fixed the mutually broken links between `prompt-engineer-analyst.md` and
  `design/prompt-patterns.md` in the bundled `rad-prompt-studio`.

### Added

- `.agents/rules/analysis-output.md` — the input-resolution and output-naming
  rule the three bundled `rad-prompt-studio` master prompts reference but which
  was not present in this kit, leaving them unable to resolve a report path.
- `tools/verify-kit.ps1` and `.github/workflows/verify.yml` — a mechanical
  consistency gate (generator drift, Cursor extension, skill-link presence,
  `SKILL.md` frontmatter, `[FILL IN` residue, README image links, `LICENSE`),
  runnable locally as `pwsh tools/verify-kit.ps1` and in CI from one script.

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
