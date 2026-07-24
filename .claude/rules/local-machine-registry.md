# The `.rad` Hub (`%USERPROFILE%\.rad`) — Rules

A per-machine, per-user hub that gives every AI session one fixed place
to find this ecosystem's pieces — regardless of where the workspace or a
kit clone actually lives on disk. Built and maintained by
`tools/rad.ps1` in the AI-Spec-Kits-Maker workspace; fully rebuildable
at any time (new PC, after a format, moved workspace) with
`pwsh tools/rad.ps1 -Action Install`.

## The one mental model that matters

**`.rad` is a WINDOW, not a photocopy.** Every link under it opens onto
the real files in the real repos. Editing through the window edits the
real file (intended); deleting or running destructive git commands
through the window destroys the real thing (so don't).

## Structure

```
%USERPROFILE%\.rad\
  settings.json        REAL FILE — machine registry (see below)
  analysis\{repo}\     REAL FOLDERS — analysis outputs live here now,
                       decoupled from every repo (see analysis-output.md)
  workspace  -> <workspace root>            (link)
  prompts    -> <workspace>\Prompts         (link)
  tools      -> <workspace>\tools           (link)
  spec-kits\{kit} -> <workspace>\spec-kits\{kit}   (links, one per kit)
  skills\{Category}\{skill} -> real skill folder    (links)
  skills\_new\{repo}@{skill}                (links awaiting categorization)
```

- **Real data in `.rad` is ONLY `settings.json` and `analysis\`** —
  everything else is links, reproducible from the committed
  `rad-skills-index.json` at the workspace root. `-Action Clean` removes
  links only and never touches those two.
- **Skill categories** (Delphi, Excel, MSSQL, Firebird, Web, ...) are
  AI-managed: when `rad-skill-finder` installs or an AI authors a new
  skill, it adds the entry to the workspace's `rad-skills-index.json`
  (creating a fitting category if none fits) and re-runs Install.
  Anything not in the index appears under `skills\_new\` and
  `-Action Verify` lists it as pending categorization.
- Byte-identical bundled mirrors of workspace `rad-*` masters are
  auto-skipped (hash check) — a mirror showing up under `_new` is a
  **staleness signal**: refresh the bundled copy instead of
  categorizing it.

## `settings.json` — the machine registry

```json
{
  "workspace_root": "E:\\...\\AI-Spec-Kits-Maker",
  "last_bootstrap": { "date": "...", "machine": "..." },
  "delphi": {
    "installs": ["37", "14"],
    "sources": {
      "global": ["c:\\01\\git\\opensource", "c:\\01\\FastReport"],
      "TMS": "c:\\01\\TMS",
      "devexpress": "c:\\01\\DevExpress"
    }
  }
}
```

- **`workspace_root`** — written by every Install run; the canonical way
  for a kit cloned *anywhere* to find the parent workspace (used by
  edit-base-prompt's Golden Rule 6 when `../../` doesn't resolve).
- **Stack keys** (`delphi`, ...) — user-maintained. `installs` is an
  **opaque list**: never interpret the values as product versions unless
  the user defines them in that conversation. `sources` registers local
  directories holding actually-installed library/vendor source code —
  when a library/component topic comes up, search these and **read the
  real installed source** before reaching for the web; cite the actual
  file path read. Missing file or missing key = skip silently, it's
  optional infrastructure.
- Never store secrets here — paths and opaque markers only.

## Disciplines (AI-binding)

1. **Never `rm -rf` anything under `.rad`.** Removing links is
   `-Action Clean`'s job (it deletes reparse points without recursing).
   A recursive delete pushed through a link destroys real repo files.
2. **No destructive git through the window.** A git command run inside
   `.rad\spec-kits\<kit>` or `.rad\workspace` operates on the real repo
   — there is no sandbox copy. Know which repo you're really in.
3. **Repair = rebuild.** Broken/missing/suspect links are never fixed by
   hand — `-Action Install` (idempotent) or `Clean` + `Install`.
4. **`-Action Push` is user-invoked.** AIs commit; the user publishes —
   `rad.ps1 -Action Push` (kits first, root last, `--follow-tags`) runs
   only when the user asks for it in that turn.
