# Specification: [Feature Name]

## Contexto

<!-- Describe the problem or need that this feature solves -->

## Functional Requirements

### User Stories

1. **As a** [user type], **I want** [action], **so that** [benefit].
2. **As a** [user type], **I want** [action], **so that** [benefit].

### Acceptance Criteria (EARS)

<!-- Use EARS notation: WHEN [condition] THE SYSTEM SHALL [behavior] -->

1. **WHEN** [event/condition] **THE SYSTEM SHALL** [expected behavior].
2. **WHEN** [event/condition] **THE SYSTEM SHALL** [expected behavior].
3. **WHEN** [event/condition] **THE SYSTEM SHALL** [expected behavior].

## Non-Functional Requirements

- **Performance:** [ex: response in < 500ms]
- **Compatibility:** [ex: Delphi 11+, Windows 10+]
- **Database:** [ex: SQLite via FireDAC]

## Business Rules

1. [Rule 1]
2. [Rule 2]

## Data Model

### Entities

```pascal
type
  T[NomeDaEntidade] = class
  private
    FId: Integer;
    // ... campos
  public
    property Id: Integer read FId write FId;
    // ... properties
  end;
```

### Tables

```sql
CREATE TABLE [nome_tabela] (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  -- campos
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

## Wireframe/Layout

<!-- Describe or reference the screen layout if applicable -->

- Main form: `Tfrm[Nome]`
- Components: `pgcMain`, `tabSearch`, `tabEdit`

## Entry Unit and Setup Call

<!-- share/rules/single-entry-facade.md: a multi-unit system is consumed through ONE entry unit -->

- **Entry unit:** `<root>.<system>` (e.g. `rad.scripting`) — the only unit a consumer adds
- **Re-exported types:** [list the public types/interfaces/exceptions aliased in the entry unit]
- **Cannot be aliased:** [enum values, open generics, helpers, free routines ... and how each is exposed instead]
- **Setup call:** `T<System>.Kur(...)` / `Kapat` — [what it registers and wires, in one call]
- **Per-instance binding point (if any):** [the single base-class hook, e.g. `TBaseForm.DoCreate`]
- **Acceptance:** the host runs the system by adding the entry unit and calling setup — proven by a test

## Out of Scope

- [What will NOT be done in this spec]
