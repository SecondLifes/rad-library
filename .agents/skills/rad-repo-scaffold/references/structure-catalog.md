# Purpose-fit structure catalog

Use this as a selection guide, not a checklist.

## Core

- `src/`: owned application or library source; prefer unless the ecosystem requires another convention.
- `source/`: existing/build convention requires it; do not duplicate `src/`.
- `lib/`, `modules/`: only for explicitly distinct architectural roles.
- `packages/`: monorepo or multiple published packages.
- `tests/`: automated tests exist or are planned now.
- `examples/`: consumers need runnable examples.
- `scripts/`: repeatable maintenance or build automation.
- `tools/`: owned developer tooling distinct from scripts.
- `vendor/`: intentional vendoring; otherwise use the package manager.

## Shared AI

- `AGENTS.md`: repository-wide shared agent instructions; prefer as the canonical entry point.
- `.agents/skills/`: repository-scoped reusable skills — read as a fallback location natively by Claude Code, Cursor, Codex CLI, Copilot and Gemini/Antigravity (Agent Skills open standard); no per-tool copy needed.
- `.agents/rules/`, `.agents/commands/`: per-topic rules and slash-commands, when a project needs more granularity than a single `AGENTS.md`. Not yet a native fallback location like `.agents/skills/` — tools that support glob-scoped rules (Claude Code, Cursor) need a small generator script to copy these into their own folder; keep the generator next to them (e.g. `tools/generate-ai-configs.ps1`) rather than hand-duplicating.
- `.prompts/`: multiple maintained reusable prompts.
- `.instructions/`: composable instruction fragments across scopes or tools.
- `.memory/`: only when a defined process reads and maintains durable memory — see [memory-pattern.md](memory-pattern.md) for the recommended shape.
- `.docs/`: AI-oriented knowledge that must be separate from user-facing `docs/`.
- `.templates/`: maintained reusable prompt, issue, document, or code templates.

## Tool-specific AI

Create only for selected or already-used tools: `.claude/`/`CLAUDE.md`, `.cursor/`/`CURSOR.md`, `.cline/`, `.roo/`, or `GEMINI.md`. Codex CLI reads `AGENTS.md` directly and needs no dedicated folder. Keep shared rules canonical and adapters concise.

## Delivery and configuration

Create `.github/` only for GitHub workflows or community files in scope. Add `README.md`, `CHANGELOG.md`, `ROADMAP.md`, `SECURITY.md`, `CONTRIBUTING.md`, `SUPPORT.md`, and `LICENSE` only when their lifecycle is defined. Let the chosen technology determine manifests such as `package.json`, `tsconfig.json`, `deno.json`, `composer.json`, or `Cargo.toml`.

For every path ask: Which requirement needs it? Which process maintains it? What becomes materially harder if omitted now? Mark it optional if the last answer is “nothing yet”; exclude it when the first two lack concrete answers.

## Companion AI tools (suggest only, never auto-install)

These are runtime tools/MCP servers, not repository files. Never add install commands, MCP registrations, or plugin manifests for them — name the candidate and the reason in the report, and only install or configure one after the user explicitly confirms.

- Semantic, symbol-level code navigation and refactoring for large or multi-language codebases — e.g. [Serena](https://github.com/oraios/serena) (MCP server, LSP-based; the project's own docs warn against installing it via a marketplace — follow its quick-start instead).
- Session-level context/token management for long-running or expensive sessions — checkpoint/restore across compaction, usage dashboard — e.g. [token-optimizer](https://github.com/alexgreensh/token-optimizer) (Claude Code plugin).

Only raise a candidate when the project's scale or workflow plausibly benefits (large/multi-language codebase, long-lived heavy sessions); don't mention them for small or short-lived repos.
