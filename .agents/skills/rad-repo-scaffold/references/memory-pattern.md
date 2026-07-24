# Memory pattern

Use only when a defined process reads and maintains durable memory (an agent instruction, a hook, a documented review cadence). If nothing concrete maintains it yet, a single `NOTES.md` or no memory folder at all is enough.

## Shape

- `<memory-root>/INDEX.md` — one line per memory file, newest-relevant first: `- [Title](file.md) — one-line hook`. This is a pointer list, not content; keep it under ~200 lines so it stays cheap to load in full.
- `<memory-root>/<topic>.md` — one file per topic, with frontmatter:

  ```markdown
  ---
  name: kebab-case-slug
  description: one-line summary — used to judge relevance to a future task
  metadata:
    type: user | feedback | project | reference
  ---

  Body: the fact or rule first, then a **Why:** line (the motivation —
  constraint, past incident, or stated preference) and, for feedback/project
  types, a **How to apply:** line (when this should change behavior).
  ```

## Rules

- Never write memory content directly into `INDEX.md` — it only points to files.
- Link related memory files with `[[name]]`, referencing the target file's `name:` slug.
- Organize by topic, not chronologically; update or delete entries that turn out wrong or stale instead of layering corrections on top.
- Don't record what's already derivable from the repo itself (code, git history, architecture) — only what isn't discoverable by reading the project.
