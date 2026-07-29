# The `.rad` Hub — System + User Roots

Two roots, resolved in order like git's `system` → `global` config levels.
Both are outside every repo, never committed, never published.

| Level | Location | Holds | Shared with |
|---|---|---|---|
| **System** | `%ProgramData%\rad` (Windows) / `/usr/local/share/rad` | `registry.json`, `rules\`, `skills\`, `prompts\` | every user on the machine |
| **User** | `%USERPROFILE%\.rad` | `settings.json`, `analysis\`, convenience links | just this user |

Built and maintained by `tools/rad.ps1` in the AI-Spec-Kits-Maker
workspace; any single kit registers itself with its own
`tools/rad-register.ps1`. Both are idempotent and need no elevation.

**A missing system root is never fatal.** It means cross-kit references
and shared rules are unavailable on this machine — say so plainly and
point at `pwsh tools/rad.ps1 -Action Install`; never guess the content
that would have been there.

## Why analysis stays per-user

`analysis\` holds personal work product and its filenames carry no user
(`claude_v1.md`). Two people running the same analysis would collide on
the same filename, so it deliberately stays in the user root while the
factual, shared material lives in the system root.

## `registry.json` — the shared source of truth

```json
{
  "schema_version": 1,
  "updated": "2026-07-29 07:22",
  "updated_by": "user@MACHINE",
  "shared": {
    "rules":   "C:\\ProgramData\\rad\\rules",
    "skills":  "C:\\ProgramData\\rad\\skills",
    "prompts": "C:\\ProgramData\\rad\\prompts"
  },
  "workspaces": { "AI-Spec-Kits-Maker": "E:\\...\\AI-Spec-Kits-Maker" },
  "kits": {
    "erp-muhasebe-temel": {
      "path": "E:\\...\\spec-kits\\erp-muhasebe-temel",
      "registered_at": "...", "registered_by": "...", "machine": "..."
    }
  }
}
```

**This file is authoritative; the convenience links under the user root
are not.** Resolve every path through the registry. A link that is
missing or broken is a cosmetic problem, never a reason to report a kit
as unavailable — check the registry before concluding anything.

Writes are serialized by a lock file and committed by temp-file rename, so
concurrent registrations cannot corrupt or silently overwrite each other.
Never hand-edit `registry.json`; run the scripts.

## Shared rules — read them, they are not optional

`registry.json`'s `shared.rules` folder holds rules that apply to **every**
kit on this machine (commit/versioning discipline, cross-kit reference
resolution, and whatever else the workspace publishes there). Read them at
the start of any task they govern — they are as binding as this kit's own
`.agents/rules/`, and they are deliberately **not** copied into the kit,
so an update in the workspace takes effect everywhere immediately.

Source of truth for their content is the workspace's git-tracked
`shared-rules/` folder; `rad.ps1 -Action Install` publishes it. Never edit
the published copy — edit the workspace source and re-publish.

## Referencing another kit

This kit declares what it borrows in its own root `settings.json`:

```json
"references": [
  { "kit": "erp-muhasebe-temel",
    "reason": "Shared PostgreSQL schema and accounting vocabulary",
    "paths": [".agents/rules/db-schema.md"] }
]
```

Resolve `kit` → `registry.json` → `kits.<name>.path`, then read the listed
paths under it. Full procedure, failure handling and the copy-vs-reference
decision table: the published `cross-kit-reference.md` shared rule.

**Never hardcode another kit's filesystem path** in this kit's files. The
name goes in `settings.json`; the path lives only in the registry.

## Registering this kit

```powershell
pwsh tools/rad-register.ps1                 # register under the folder name
pwsh tools/rad-register.ps1 -Name my-kit    # register under an explicit name
pwsh tools/rad-register.ps1 -Unregister     # remove the entry
```

Re-run it after moving or re-cloning the kit — a registration pointing at
a path that no longer exists is reported as `STALE REGISTRATION` by
`rad.ps1 -Action Verify`.

## Stack keys in the user `settings.json`

```json
"delphi": {
  "installs": ["37", "14"],
  "sources": { "global": ["c:\\01\\git\\opensource"], "TMS": "c:\\01\\TMS" }
}
```

`installs` is an **opaque list** — never interpret the values as product
versions unless the user defines them in that conversation. `sources`
registers directories holding actually-installed library/vendor source:
when a library topic comes up, search these and **read the real installed
source** before reaching for the web, citing the file path read. Missing
file or missing key means skip silently — it is optional infrastructure.

Never store secrets in either root — paths and opaque markers only.

## Disciplines (AI-binding)

1. **Never `rm -rf` anything under either root.** Removing links is
   `rad.ps1 -Action Clean`'s job (it deletes reparse points without
   recursing). A recursive delete pushed through a link destroys real
   repo files.
2. **No destructive git through a link.** A git command run inside
   `.rad\spec-kits\<kit>` operates on the real repo — there is no sandbox
   copy. Know which repo you are really in.
3. **Repair = rebuild.** Broken or suspect links are never fixed by hand:
   `-Action Install` (idempotent), or `Clean` then `Install`.
4. **`-Action Push` is user-invoked.** AIs commit; the user publishes.
