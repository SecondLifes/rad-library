# `src/` layout

This directory now contains the real **Rad Core** library — imported from
its original working repository (`Rad Core | Enterprise Delphi Framework`,
maintained separately outside this kit). It is the reference implementation
this kit's rules were themselves derived from (see `ACKNOWLEDGMENTS.md`).

```text
src/
├── core/        reusable library code (RTL + mORMot2 only) — help.*.pas units
│                (help.date, help.rtti, help.str, Help.DB, Help.uni, Help.vcl)
│                plus rad.*.pas core units (rad.cache, rad.cmd, rad.eventbus,
│                rad.permission, rad.thread, rad.utils, rad.worker, ...)
├── component/   VCL components and their editors (Permission.Edit,
│                rad.db, rad.rtl, rad.vcl) — no separate fmx/ split yet;
│                everything here targets VCL today
├── share/       shared forms used across components (Core.Form,
│                Kisayol.Edit) — not part of the original layout contract
│                below; kept as its own top-level folder rather than
│                forced into component/
├── packages/    Delphi package project files (RadKon.dpk/.dproj) plus
│                their registration/editor units (Rad.Register.pas,
│                Rad.Editor.pas)
├── test/
│   ├── unit/    DUnitX test units (one per source unit, `.Tests.pas`)
│   ├── app/     a DUnitX GUI test runner project (Rad_Test_GUI)
│   └── scratch/ ad hoc benchmark/smoke-test projects, kept for reference
├── rad.json.pas, clear.ps1, vendor.bat   root-level support files
```

A source named `help.date.pas` is tested by
`src/test/unit/help.date.Tests.pas`. Component classes use `TRAD`. Real
imported code is the working reference — it does not by itself authorize
inventing new public API surface beyond what it actually contains; extend
it following the same rules (`helper-patterns.md`, `component-patterns.md`,
`vendor-integration.md`) as any other change to this library.
