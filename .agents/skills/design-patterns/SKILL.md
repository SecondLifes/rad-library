---
name: "Design Patterns GoF — Delphi"
description: "Implementation of the 23 GoF (Gang of Four) patterns in Object Pascal / Delphi with interfaces, TInterfacedObject and SOLID principles. Covers Creational, Structural and Behavioral patterns."
---

# Design Patterns GoF in Delphi — Skill

Use this skill when the user requests implementation of design patterns in Delphi. Always apply together with naming conventions (T/I/E/F/A/L) and memory management (try..finally).

## When to Use

- Create `Factory`, `Abstract Factory` or `Builder` for creating complex objects
- Implement `Strategy` to vary algorithms (calculation of freight, taxes, export)
- Use `Observer` for decoupled notifications (Domain Events)
- Apply `Command` for undo/redo, job queues or auditing
- Use `Decorator` to add responsibilities without inheritance
- Implement `Adapter` for integration with legacy systems
- Use `Facade` to simplify complex subsystems (e.g. NFe emission)
- Apply `Template Method` to algorithms with variations (reports, exports)
- Use `State` for behavior that changes depending on the state of the object
- Use `Chain of Responsibility` for validation or processing pipelines

## 📌 Guide to Choosing the Right Pattern

| Need | Standard | Category |
|---|---|---|
| Create objects with type variation | Factory Method / Abstract Factory | Creational |
| Create complex objects step by step | Builder | Creational |
| Ensure Global Single Instance | Singleton | Creational |
| Copy objects | Prototype | Creational |
| Adapt incompatible interface | Adapter | Structural |
| Add responsibilities dynamically | Decorator | Structural |
| Simplify complex system | Facade | Structural |
| Control access to an object | Proxy | Structural |
| Compose objects in tree structure | Composite | Structural |
| Vary algorithm without changing context | Strategy | Behavioral |
| Notify multiple objects about changes | Observer | Behavioral |
| Encapsulate actions with undo/redo | Command | Behavioral |
| Algorithm with variations | Template Method | Behavioral |
| Pass request through handler chain | Chain of Responsibility | Behavioral |
| Behavior that changes with the state | State | Behavioral |

Full implementation and code for each pattern is in the reference files below — read the one matching the category the task needs rather than guessing.

## references/

Read only the file(s) relevant to the current task — this skill file is intentionally short; the depth lives in these files.

- `creational-patterns.md` — Singleton, Factory Method, Abstract Factory, Builder.
- `structural-patterns.md` — Adapter, Decorator, Facade, Proxy.
- `behavioral-patterns.md` — Strategy, Observer, Command, Template Method, Chain of Responsibility, State.

## ✅ Final Checklist

- [ ] All dependencies injected via constructor (DIP)
- [ ] Every interface implementation uses `TInterfacedObject` (ARC)
- [ ] No `.Create` without `try..finally` (except on ARC interfaces)
- [ ] Each class has a single responsibility (SRP)
- [ ] DUnitX tests cover each pattern with Fakes/Stubs
- [ ] XMLDoc in Portuguese in public methods
- [ ] Prefixes: `T` class, `I` interface, `E` exception, `F` field, `A` param, `L` location
