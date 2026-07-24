# project:review

`project:review`

Please review the current diffs (`git diff` and `git diff --cached`) against this project's Delphi coding standards from `.claude/CLAUDE.md` and the appropriate rules within `.claude/rules/` (generated from the canonical `.agents/rules/`). Use the `code-review` skill's checklist (correctness, security, performance, SOLID, memory, naming, tests) as the review structure, and confirm at minimum that:
- Naming conventions (`T`, `I`, `E`, `F`, `A`, `L` prefixes) are respected.
- `try..finally` is correctly applied to ALL unowned object creations.
- There are no `with` statements.
- Memory leaks are unlikely with the new changes.
- Specific database or framework constraints (MSSQL, PostgreSQL, etc.) are respected.
