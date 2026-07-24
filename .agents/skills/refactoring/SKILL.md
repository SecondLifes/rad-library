---
name: "Delphi Code Refactoring"
description: "Refactoring techniques for Object Pascal focused on improving readability, removing code smells, and preserving behavior through practices like Extract Method, Guard Clauses, and polymorphism. Use when restructuring existing code without changing its behavior, not for a one-off review pass (see code-review) or new-code conventions (see clean-code)."
---

# Delphi Code Refactoring — Skill

Use this skill when the user requests refactoring or removal of code smells in Object Pascal. Refactoring **never changes observable behavior** — it only improves the internal structure of the code.

> **Interface GUIDs:** every `['{...}']` in the examples below is a real, unique GUID. When generating new interfaces, always create a fresh GUID (IDE: `Ctrl+Shift+G`, or `TGUID.NewGuid.ToString`) — never emit the literal placeholder text `{GUID}`.

## When to Use

- User asks to "improve", "clean up" or "refactor" existing code
- When reviewing code and finding code smells
- When preparing legacy code to receive new functionality
- Before adding tests to untestable code
- When answering "why is this code difficult to understand?"

## Fundamental Principle

> "Refactoring is the art of changing the structure of code without changing its behavior."
> Always write (or check for) tests **before** refactoring.

## 📋 Catalog of Code Smells and Techniques

1. Extract Method — Long Method
2. Extract Class — Class with Multiple Responsibilities
3. Replace Nested Conditionals with Guard Clauses
4. Replace Magic Numbers with Constants
5. Replace Conditional with Polymorphism (Strategy/State)
6. Introduce Parameter Object
7. Remove `with` Statement
8. Extract Interface / Invert Dependency
9. Rename — Self-Descriptive Names
10. Inline Method — Unnecessarily Delegate Method

Each technique's before/after example is in the reference files below — read the one covering the smell at hand rather than guessing.

## references/

Read only the file(s) relevant to the current task — this skill file is intentionally short; the depth lives in these files.

- `extraction-and-structure.md` — techniques 1–6: Extract Method, Extract Class, Guard Clauses, Magic Numbers, Polymorphism, Parameter Object.
- `dependencies-and-cleanup.md` — techniques 7–10: remove `with`, Extract Interface/Invert Dependency, Rename, Inline Method — plus the secure refactoring process (Understand → Test → Small step → Test → Commit → Repeat).

## ✅ Final Checklist

- [ ] Is there testing covering the behavior before refactoring?
- [ ] Does the observable behavior remain the same?
- [ ] No `with` was introduced?
- [ ] No nameless magic number?
- [ ] Resulting method has ≤ 20 lines?
- [ ] Name of the extracted method needs no comment?
- [ ] Dependencies are now via interface?
- [ ] Do guard clauses replace deep nesting?
- [ ] Were excess parameters grouped in DTO/Record?
