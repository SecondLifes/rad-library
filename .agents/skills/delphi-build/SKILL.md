---
name: delphi-build
description: "Building Delphi library packages and test projects from the command line — rsvars + MSBuild with log-file capture, first-error diagnosis, dcc32 error catalog (E2003/E2065), MSB6003 command-line-too-long fixes"
---

# Delphi Build (Command Line) — Skill

Use this skill whenever a `.dproj`/`.dpk`/`.dpr` must be compiled outside the
IDE — verifying that generated code actually compiles (this kit's mandatory
verification step), running the DUnitX suite from a script, or diagnosing a
command-line build failure.

## Usage

| You say | What happens |
|---|---|
| "Compile this project/package" / "derle" | Locates or generates a `build.bat` (rsvars + MSBuild + log redirect), runs it, reads the log, diagnoses the FIRST error. |
| A dcc error code (`E2003`, `E2065`, `MSB6003`...) | Looks it up in the error catalog below / in `references/`. |
| "Run the tests from the command line" | Builds the DUnitX project and runs it with `--exitbehavior:Continue`, capturing output to a log file. |

## Core principle

**Never trust the exit code alone — read the log.** All build output
(stdout+stderr) is redirected to a log file; success is confirmed by
grepping the log for `error E`/`error F`/`Fatal`, not by `%ERRORLEVEL%`
in isolation (a `type`/`echo` after MSBuild silently resets it).

## Quick flow

1. **Discover the installed Delphi first — never hardcode a Studio version:**
   ```bat
   dir "C:\Program Files (x86)\Embarcadero\Studio" /b /ad
   ```
   More than one version installed → ask the developer which to use.
   Community Edition may live outside `Program Files (x86)`.
2. Generate/locate `build.bat` following `references/msbuild-with-log.md`
   (rsvars → MSBuild → `> build_log.txt 2>&1` → `set ERR` **immediately**).
3. Run it, `Read` the log, fix the **first** error (the rest is usually cascade).
4. Repeat until the log is clean; only then report success.

## dcc32 quick error catalog

| Error | Typical cause |
|---|---|
| `E2003 Undeclared identifier` | Missing unit in `uses` — see the identifier→unit table in `references/msbuild-with-log.md` |
| `E2065 Unsatisfied forward or external declaration` | Declared but never implemented method |
| `E1026 File not found: '*.dres'` | `{$R *.dres}` present but no resource registered (see `vcl-component-architecture` → `embedded-resources.md`) |
| `MSB6002/MSB6003 command line too long` | Search paths blew the ~32k `CreateProcess` limit — see `references/msb6003-response-files.md` |
| `ECommandLineError: Option [exit]...` | DUnitX takes `--exitbehavior:Continue`, not `--exit` |

## Library-specific notes

- A two-package library builds in order: **runtime `.dpk` first, then
  design-time `.dpk`** (design-time `requires` the runtime package).
- `$(Auto)` LIB suffix means output BPL names differ per IDE version —
  scripts must not hardcode `MyLibR290.bpl`-style names.
- Test project (`src/test/`) is a plain console `.dpr` — build it with the
  same rsvars/MSBuild pattern and run with `--exitbehavior:Continue`.

## references/

- `msbuild-with-log.md` — the `build.bat` template (log capture, the
  exit-code trap, DUnitX invocation, how to call it from Bash/PowerShell),
  plus the identifier→unit table for `E2003`-class errors.
- `msb6003-response-files.md` — `DCC_ForceExecute` response-file fix and
  the `.cfg` fallback for command-line-too-long failures.
