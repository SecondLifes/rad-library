---
description: "RAD Library VCL/FMX component and package contract"
globs: ["src/**/*.pas", "src/**/*.dpk", "src/**/*.dproj"]
alwaysApply: true
---

# Component Patterns

- Component classes use the `TRAD` prefix.
- Split runtime and design-time packages. Runtime packages must not contain
  `DesignIntf`, design editors, registration units or `Register`.
- Put `Register`, component/property editors and IDE-only dependencies in
  the design-time package; the design package requires the runtime package.
- Register every new component in `Rad.Register.pas`; design-time-only code
  (component/property editors) goes in `Rad.Editor.pas`.
- Constructor defaults, published `default` directives and streaming state
  must agree. Renaming/removing a published property requires a migration
  plan and SemVer-compatible deprecation.
- Observe ownership, `FreeNotification`, `Notification`, `Loaded`,
  `csDesigning`, `csLoading` and `csDestroying`.
- VCL/FMX UI state is main-thread-only. Marshal background callbacks.
- Compile-check applicable runtime/design-time package pairs for Win32 and
  Win64. Treat framework-specific code as separate from the core (which
  depends on the RTL and mORMot2, and nothing else).
- Visual design lives in the DFM (user rule 2026-11-01): forms, frames, dialogs and their static layout/controls are authored in `.dfm`; code creates only data-driven parts (one editor per runtime definition). Code-built UI hit `csLoading`/nil-root traps twice in this kit and cannot be opened in the IDE designer.
