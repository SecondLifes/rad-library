---
name: tms-vcl-ui
description: "Standards for TMS VCL UI Pack components (TAdvStringGrid family, Adv* editors, panels) in Delphi VCL applications"
---

# TMS VCL UI — Skill

Use this skill for an approved optional **TMS VCL UI Pack** integration under
`src/vendor/`. The dependency-free core must not reference TMS. Aurelius and
FlexCel are outside this kit; do not route to removed skills.

> **Commercial dependency:** TMS VCL UI Pack is a paid product. Do not
> introduce it into a project that doesn't already use it without explicit
> user approval — plain VCL or the project's existing suite (e.g.
> DevExpress, see `devexpress-components`) comes first. Product page:
> [tmssoftware.com — TAdvStringGrid](https://www.tmssoftware.com/site/advgrid.asp).

## Usage

| You say | What happens |
|---|---|
| "Build this screen with TMS grid" | `TAdvStringGrid`-based UI following the conventions below (only if TMS is already a project dependency — otherwise flags the policy first). |
| "Export/import this grid to CSV/XLS/HTML" | Uses TAdvStringGrid's built-in save/load members instead of hand-rolled loops. |
| "TMS or DevExpress for this project?" | Comparison scoped to what the project already licenses — never recommends buying a second suite for one screen. |
| No component/screen named | Asks which screen and which TMS components are in scope. |

## Core components (verified against vendor site/docs)

| Component | Usage | Prefix |
|---|---|---|
| `TAdvStringGrid` | Feature-rich grid: insert/delete/move rows & columns, clipboard, CSV/XLS/HTML/stream save-load, grouping, filtering, mini-HTML cells | `asg` |
| `TAdvGridWorkbook` | Multi-sheet wrapper over TAdvStringGrid | `awb` |
| `TDBAdvGrid` | DB-aware TAdvStringGrid variant | `dbg` |
| `TAdvEdit` / `TAdvSpinEdit` | Validated/masked edits | `edt` |
| `TAdvComboBox` | Extended combo | `cmb` |
| `TAdvPanel` / `TAdvPanelGroup` | Collapsible/styled panels | `pnl` |
| `TAdvToolBar` / `TAdvToolBarPager` | Office-style toolbars/ribbon | `atb` |
| `THTMLabel` / `THTMListBox` | Mini-HTML-rendering text components | `lbl` |

## Conventions

- **One suite per form family.** Don't mix TMS grids and DevExpress grids
  in the same application area — pick per project, for visual and
  behavioral consistency.
- **Grid data loading:** batch-fill inside
  `BeginUpdate`/`EndUpdate` to avoid per-cell repaints; use the grid's
  own CSV/XLS/stream loaders rather than cell-by-cell loops when
  importing.
- **Mini-HTML** in cells/labels is for light formatting (bold, color,
  links) — not layout; complex cell layouts belong to owner-draw or a
  different control.
- **DB-aware vs manual:** `TDBAdvGrid` for straight dataset display;
  plain `TAdvStringGrid` + explicit fill when the grid shows derived/
  composed data — don't fake DB-awareness by syncing manually in both
  directions.
- **Styling** through the suite's style/appearance mechanisms — no
  hardcoded per-cell colors scattered in event handlers; centralize in
  one styling routine.
- **Licensing/installation:** TMS products install via TMS Smart Setup /
  subscription manager; source-only distribution — the design-time and
  runtime package split follows this kit's `library-packaging` rule like
  any other component suite.

## Checklist

- [ ] TMS already a project dependency (or user approved adding it)?
- [ ] Grid fills wrapped in `BeginUpdate`/`EndUpdate`?
- [ ] Built-in import/export used instead of hand-rolled cell loops?
- [ ] No suite mixing on the same form family?
- [ ] Aurelius/FlexCel questions routed to their own skills?
