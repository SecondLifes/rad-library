---
name: rad-repo-scaffold
description: Gather a repository's purpose from a prompt or Markdown specification, resolve missing requirements, and create a minimal, purpose-fit AI-ready structure. Use when asked to initialize, scaffold, organize, or make a new or existing repository ready for Codex, Claude, Cursor, Cline, Roo, or other AI coding agents without generating every possible AI-tool directory.
---

# Rad Repo Scaffold

Create only the structure justified by the project's purpose, technology, workflows, and selected AI tools. Preserve existing work.

## Workflow

1. Accept a direct purpose description or one or more `.md` requirement files and read them completely.
2. For an existing repository, inspect its structure and instructions first. Treat open IDE buffers as authoritative when IDE-aware tools are available.
3. Extract purpose, deliverables, maturity, technologies, package layout, selected AI assistants, documentation and automation needs, source/test layout, constraints, and prohibited changes.
4. Ask only questions whose answers materially change the structure. Do not ask for discoverable information.
5. Read [references/structure-catalog.md](references/structure-catalog.md); also read [references/memory-pattern.md](references/memory-pattern.md) when a memory workflow is in scope. Propose only justified paths and give a one-line reason for every top-level entry.
6. Separate paths into required now, optional later, and excluded. Explain exclusions for tempting but unnecessary AI-tool folders. Note, in the report only, any companion AI tool from the catalog's "Companion AI tools" list that plausibly fits the project's scale — never install or configure one without explicit confirmation.
7. Confirm before creating a large structure, modifying existing files, or adding unrequested tool-specific configuration.
8. Save the approved structure as JSON. Run `python scripts/apply_structure.py --root <repo> --plan <plan.json>`, review its dry run, then rerun with `--apply`. **Prerequisite:** this step needs a Python 3 interpreter on PATH — it is the only part of this kit that does; if Python isn't available, create the approved folders/files manually (or via PowerShell) following the same plan JSON instead of skipping the scaffold.
9. Verify and report created, skipped, and conflicting paths.

## Plan Format

```json
{
  "directories": ["src", "tests", ".agents/skills"],
  "files": {"AGENTS.md": "# Repository instructions\n"}
}
```

Do not create placeholder documents without a concrete reader and purpose.

## Safety

- Reject absolute paths and traversal outside the repository root.
- Create missing paths only; never overwrite existing files.
- Preserve user-owned, generated, unknown, and IDE-managed files.
- Do not initialize Git, install dependencies, move files, or delete content unless explicitly requested.
- Prefer one canonical shared instruction source; add tool adapters only when required.
- Keep generated instruction files (`AGENTS.md`, adapters, rule files) short; link to a reference doc instead of inlining large content — every line in them is re-read on future turns.
- Create memory folders only for a defined memory workflow, following [references/memory-pattern.md](references/memory-pattern.md).
- Avoid duplicate `src`/`source` or `lib`/`modules`/`packages` roles.
- Companion AI tools (MCP servers, plugins) are runtime installs, not repository files — only name them as a suggestion in the report; never add install commands, MCP registrations, or plugin manifests for them without explicit confirmation.

## Output

Return the approved tree, assumptions, created and skipped paths, conflicts, and next action. Keep future options separate from completed work.
