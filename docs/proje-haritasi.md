# RAD Library AI Spec-Kit — Project Map

Canonical system content lives under `.agents/`; generated Claude/Cursor
copies are maintained by `tools/generate-ai-configs.ps1`.

## Rules

| Rule | Purpose |
|---|---|
| `component-patterns.md` | TRAD components, streaming and package split |
| `delphi-conventions.md` | Object Pascal naming and style |
| `design-patterns.md` | Pattern selection |
| `helper-patterns.md` | `help.*`, `_` public helpers and tests |
| `kit-settings.md` | Operational settings |
| `library-packaging.md` | Packages, SemVer and licensing |
| `local-machine-registry.md` | Local machine discovery |
| `memory-exceptions.md` | Lifetime and exception safety |
| `performance-patterns.md` | Evidence-based optimization |
| `refactoring.md` | Behavior-preserving change |
| `solid-patterns.md` | SOLID boundaries |
| `sync-workflow.md` | Canonical/generated ownership |
| `tdd-patterns.md` | DUnitX and `src/test/` |
| `threading-patterns.md` | Reentrancy and UI-thread rules |
| `vendor-integration.md` | Optional vendor isolation |

## Skills

| Skills | Scope |
|---|---|
| `clean-code`, `code-review`, `refactoring` | Quality and review |
| `delphi-build`, `delphi-encoding`, `delphi-http-client` | Delphi tooling/fundamentals |
| `delphi-memory-exceptions`, `delphi-patterns`, `design-patterns` | Core correctness/design |
| `dunitx-testing`, `tdd-dunitx`, `threading` | Tests and concurrency |
| `vcl-component-architecture`, `fmx-component-architecture` | VCL/FMX components |
| `unidac-data-access`, `devexpress-components`, `tms-vcl-ui`, `fastreport-vcl` | Optional vendor adapters |
| `jedi-integration`, `mormot2-integration` | Conditional JEDI/mORMot2 adapters |
| `rad-powershell-master`, `rad-python` | Supporting language/tool skills |
| `rad-prompt-studio`, `rad-repo-scaffold` | System analysis and repository setup |
| `rad-skill-finder`, `rad-web-scraping` | Capability discovery/research |

## Commands and identities

- `.agents/commands/review.md` — hand-authored review command.
- `.claude/commands/*.md` — generated skill wrappers plus `review.md`.
- `AGENTS.md`, `.claude/CLAUDE.md`, `.gemini/rules/project-rules.md`,
  `.github/copilot-instructions.md` — one behavioral contract, reworded per tool.

## Project layout

Only `src/README.md` exists initially. The user creates actual `src/core/`,
`src/helpers/`, `src/components/`, `src/test/` and `src/vendor/` content
while designing the real APIs.
