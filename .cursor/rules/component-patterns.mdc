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
- Constructor defaults, published `default` directives and streaming state
  must agree. Renaming/removing a published property requires a migration
  plan and SemVer-compatible deprecation.
- Observe ownership, `FreeNotification`, `Notification`, `Loaded`,
  `csDesigning`, `csLoading` and `csDestroying`.
- VCL/FMX UI state is main-thread-only. Marshal background callbacks.
- Compile-check applicable runtime/design-time package pairs for Win32 and
  Win64. Treat framework-specific code as separate from the dependency-free
  core.
