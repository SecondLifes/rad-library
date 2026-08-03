# Contributing to RAD Library AI Spec-Kit

First off, thank you for considering contributing! It's people like you who make this kit better for everyone using it.

By participating in this project, you agree to abide by its [Code of Conduct](CODE_OF_CONDUCT.md).

## How Can I Contribute?

### Reporting Bugs

* Check the [issue tracker](https://github.com/SecondLifes/rad-library/issues) to see if the bug has already been reported.
* If not, open a new issue. Clearly describe the problem and include steps to reproduce it.

### Suggesting Enhancements

* Open an issue with the tag `enhancement`.
* Explain why this would be useful to most users of this kit.

### Pull Requests

1. Fork the repository.
2. Create a new branch for your feature or bugfix.
3. Implement your changes.
4. Follow the conventions in `AGENTS.md` and `.agents/rules/*.md` (consistent with the rest of the project).
5. Verify by actually compiling and exercising your change — a unit is not correct until it has been built and its behavior checked, not just read (see `AGENTS.md`'s Identity section).
6. Submit a Pull Request targeting the `main` branch.

## Technical Standards

This kit's own conventions are the technical standard for contributions —
not restated here to avoid drift between two copies of the same rules.
See `AGENTS.md`'s "Naming Conventions", "SOLID principles", "Clean Code"
and "Memory Management" sections for Delphi's naming, error-handling, and
architecture conventions.

To add new capability rather than fix an existing one:

1. **Rule** → `.agents/rules/your-topic.md`, then run `pwsh tools/generate-ai-configs.ps1` to regenerate `.claude/rules/` and `.cursor/rules/` — do **not** hand-edit those two folders directly, your change will be overwritten on the next run.
2. **Skill** → `.agents/skills/your-framework/SKILL.md` (one copy, read natively by every supported tool — no content to regenerate, but run `pwsh tools/generate-ai-configs.ps1` afterward so Claude Code also gets the matching `/your-framework` command wrapper).
3. **Reference** → mention it in `AGENTS.md` (and `.gemini/rules/project-rules.md` if it's framework/database-specific, matching the existing entries) and in `docs/proje-haritasi.md`.

### Testing

* This kit has no automated test suite of its own — verification means actually compiling and running the Object Pascal code a rule/skill produces against a real RAD Studio/Delphi install, not declaring it correct from reading alone.

## Communication

* Use the [issue tracker](https://github.com/SecondLifes/rad-library/issues) for bugs, questions, and proposals.
* Respect all contributors and maintainers — see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Provenance

This kit began as a fork of [delphicleancode/delphi-spec-kit](https://github.com/delphicleancode/delphi-spec-kit) and has since been extended independently. It keeps that project's original MIT license and copyright notice (see [LICENSE](LICENSE)) — do not change the license or copyright holder in a contribution without discussing it first.
