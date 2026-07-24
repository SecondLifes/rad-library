---
name: fmx-component-architecture
description: Design or review Delphi 13+ FMX components, styles, lifecycle and runtime/design-time packages for RAD Library.
---

# FMX Component Architecture

Use for FMX component design, review or package work. Load only the
reference needed by the request.

## Usage

1. Read `.agents/rules/component-patterns.md`.
2. Identify target platforms, ownership/lifecycle, rendering/style needs and
   package boundary.
3. Read the matching reference in this folder.
4. Propose the smallest public surface; do not invent APIs from examples.
5. Compile-check Win32/Win64 and exercise lifecycle/streaming behavior before
   marking the work verified.

## References

- `references/component-lifecycle-and-streaming.md`
- `references/rendering-styles-and-platforms.md`
- `references/design-time-packaging.md`
