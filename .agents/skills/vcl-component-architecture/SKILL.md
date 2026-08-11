---
name: vcl-component-architecture
description: "Designing runtime and design-time VCL components — TComponent ownership, Notification, streaming/DFM, published properties, property/component editors, Register units, package split"
---

# VCL Component Architecture — Skill

Use this skill when designing or reviewing a reusable VCL component or component
library for Delphi — anything descending from `TComponent` that is meant to be
installed into the IDE palette or consumed by other projects as a package.

In RAD Library, component classes begin with `TRAD`; project files live under
`src/`; runtime and design-time packages are always separate. Examples never
authorize invented public APIs.

## Usage

| You say | What happens |
|---|---|
| "Create a component that does X" / "X yapan bir component yaz" | Full component design: ancestor choice, ownership model, published property surface, streaming compatibility, Register unit, runtime/design-time package split — per the references below. |
| "Review this component" + a `.pas` path | Checks the unit against the lifecycle/streaming/design-time checklists (Notification handling, default values, `csDesigning` guards, package placement). |
| "Add a property editor for Y" | Design-time work only: `DesignIntf`/`DesignEditors` code goes in the design-time package, never the runtime one. |
| No component or path named | Asks what the component should do and which ancestor family it belongs to (non-visual `TComponent`, windowed `TWinControl`, painted `TGraphicControl`) — never guesses the ancestor. |

## When to Use

- Writing a new non-visual (`TComponent`) or visual (`TGraphicControl`/`TWinControl`/`TCustomControl`) component
- Deciding published property surface and DFM streaming behavior
- Handling references to sibling components safely (`Notification`/`FreeNotification`)
- Building runtime + design-time packages and registering into the IDE palette
- Writing property editors / component editors
- Keeping DFM backward compatibility across library versions

## Quick Reference

Golden rules:

1. **Ancestor discipline:** descend from the `TCustom*` ancestor and publish
   selectively — never publish everything the ancestor protected.
2. **Ownership:** an owned component is freed by its Owner; never `Free` what
   you don't own. Sub-objects that are not components (`TPersistent` props)
   are created in the constructor and freed in the destructor.
3. **Cross-component references:** every field holding another component MUST
   pair a `FreeNotification` with a `Notification` override that nils the
   field on `opRemove` — the single most common component bug.
4. **Streaming:** every published property gets a sensible default (`default`
   directive + constructor assignment must agree); `TPersistent` properties
   get a setter calling `Assign`, never a direct field write.
5. **Design/runtime split:** `DesignIntf`/`DesignEditors` code lives ONLY in
   the design-time package; the runtime package must remain installable in a
   built application without IDE units.
6. **Main thread:** VCL is single-threaded — a component exposing async work
   marshals every UI-facing callback through `TThread.Queue`/`Synchronize`.

## references/

Read only the file(s) relevant to the current task — this skill file is
intentionally short; the depth lives in these files.

- `component-lifecycle.md` — TComponent ownership model, constructor/destructor
  discipline, `Notification`/`FreeNotification`, `ComponentState`
  (`csDesigning`, `csLoading`, `csDestroying`) guards, `Loaded` override.
- `streaming-and-properties.md` — published property design, `default`/`stored`
  directives, `TPersistent` sub-properties and `Assign`, collections
  (`TCollection`/`TOwnedCollection`), events, `DefineProperties`, DFM
  backward compatibility rules.
- `design-time-integration.md` — `Register` procedure and `*.Reg.pas` unit
  conventions, runtime vs design-time package layout (`$LIBSUFFIX`,
  requires/contains), property editors, component editors, palette
  categories, and what belongs in which package.
- `embedded-resources.md` — embedding binary assets via the Resources and
  Images dialog (RCDATA + `.dres`), reading them with `TResourceStream`,
  the per-module `HInstance` rule for packages, and the
  `E1026`/`E2606`/`RC_DATA` pitfalls.
