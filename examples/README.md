# examples/

Curated, **compiling and working** Object Pascal reference units for this
kit — not scratch space and not generated output.

## What belongs here

- Complete `.pas` units that demonstrate a rule end to end, in the form
  you would actually ship: a `help.*` helper with its `_`-prefixed public
  API, a `TRAD` component with matching runtime/design-time packaging, a
  DUnitX fixture showing the success/boundary/error triad.
- Code the AI can read to see *how a rule is really applied*, when the
  short snippet inside a `.agents/rules/*.md` file isn't enough.

## What does not belong here

- **AI-generated deliverables** — those go to `src/`, the working root
  (see `AGENTS.md`'s "Working Directory"). `examples/` is curated
  reference material; `src/` now holds the real Rad Core library.
- Units that don't compile. An example that fails `dcc32`/`dcc64` teaches
  the wrong thing — this kit's own rule is that a unit is unverified until
  it compiles and its behavior has actually been exercised.

## Why this file exists

Git does not track empty directories. Without a file here, `examples/`
silently disappears from any fresh clone — while `AGENTS.md`,
`.claude/CLAUDE.md` and `docs/ai-ignore-strategy.md` all still name
`examples/**/*.pas` as always-load context, leaving a dead reference.
That is exactly what had happened to this kit before this file was added:
the folder was absent while three files still promised it. Same guarantee
`src/README.md` provides for its own folder.

Replace or extend this file freely once real example units land — just
don't delete it while the folder is otherwise empty.
