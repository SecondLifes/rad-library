---
name: jedi-integration
description: Design or review optional JEDI JCL/JVCL integration boundaries for RAD Library without coupling the core.
---

# JEDI Integration

JEDI support is optional and conditional until the exact installed JCL/JVCL
version compiles with Delphi 13+.

## Usage

1. Read `.agents/rules/vendor-integration.md`.
2. Determine whether the feature needs JCL, JVCL or both.
3. Read the corresponding reference.
4. Keep the integration under `src/vendor/` and out of the core.
5. Record installed versions and run Win32/Win64 compile/tests before
   changing status from conditional to verified.

Never redistribute JEDI or third-party files from the user's installation.
