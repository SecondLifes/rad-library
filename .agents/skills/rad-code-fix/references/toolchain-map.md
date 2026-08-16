# Toolchain Discovery Map

This file is a discovery map, not a frozen command cookbook. Project scripts and
CI are authoritative for how that repository builds and tests. Tool behavior and
flags change; verify current third-party syntax with Context7 when available,
otherwise official documentation, and cite the source in the audit report.

## Resolution order

1. Read the host instructions and CI configuration.
2. Read manifest-defined scripts/tasks and existing developer documentation.
3. Inspect existing test files to identify framework and conventions.
4. Prefer project wrappers/lockfiles over a globally installed tool.
5. If an invocation is still unknown, consult current official documentation.
6. Record the exact command, version/source and verification date in the run
   report; do not permanently claim “strictest” flags without a source.

Use code-graph discovery only for targets known to be covered by a current index.
Skip it for untracked, newly created, temporary/generated or stale-index targets.
Otherwise give it one bounded attempt; missing coverage is a reason to fall back to
language-native tooling and targeted text search, not a reason to index or traverse
the entire workspace.

## Stack map

| Stack signal | Project-owned entry points to inspect | Dependency/impact evidence | Test convention evidence |
|---|---|---|---|
| JavaScript/TypeScript (`package.json`, lockfile, `tsconfig*`) | package scripts, workspace config, CI | package/workspace graph, imports, compiler/bundler output | test scripts, config and existing test files |
| Python (`pyproject.toml`, lockfile, requirements files) | project tool sections, task runner, CI | imports, package metadata, type-checker output | configured test paths, fixtures and existing tests |
| .NET (`*.sln`, `*.csproj`, props/targets) | solution/project targets, repo scripts, CI | project references, compiler/analyzer output | test projects and existing framework attributes |
| Rust (`Cargo.toml`, lockfile) | workspace/package tasks and CI | workspace graph, module/use paths, compiler output | existing test modules/integration tests |
| Go (`go.mod`, workspace files) | repo scripts and CI | package/import graph and compiler output | `_test` files and existing table/fixture style |
| Java/Kotlin (`pom.xml`, Gradle files/wrapper) | wrapper tasks, modules and CI | module/dependency graph and compiler output | configured test source sets and existing tests |
| Delphi/Object Pascal (`*.dproj`, `*.groupproj`) | project groups, build scripts, CI and installed IDE/compiler rules | `uses` graph, project search paths, compiler diagnostics | existing DUnitX/DUnit tests and runner configuration |
| C/C++ (CMake/project files, compile database) | project presets/scripts and CI | build graph, includes, linker/compiler output | configured test targets and existing fixtures |

## Command record template

```text
Purpose: build | typecheck | lint | focused test | module suite | full suite
Command: exact project-owned invocation
Resolved from: file/path and line/task name
Tool/runtime version: observed output
Current documentation: Context7 library ID or official URL, when external behavior matters
Verified on: ISO date and platform
Safety class: read-only | local/reversible | external/hard-to-undo
Timeout/limits: value used
```

## Diagnostics discipline

- Establish the repository's normal configuration first; an optional stricter pass
  is separate evidence and must not silently redefine project policy.
- Preserve baseline diagnostics outside the write scope.
- Explain each dismissed diagnostic with evidence; “cosmetic” is not evidence.
- If the required SDK, platform or commercial dependency is unavailable, continue
  with source/graph evidence and mark only execution-dependent claims unverified.
