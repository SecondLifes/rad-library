---
name: unidac-data-access
description: "Standards for Devart UniDAC (TUniConnection, TUniQuery, providers, SpecificOptions) as an alternative data-access layer to FireDAC"
---

# UniDAC Data Access — Skill

Use this skill only for an approved optional RAD Library integration under
`src/vendor/`. The dependency-free core must not reference UniDAC.

> **Commercial dependency:** UniDAC is a paid Devart product. Per this kit's
> dependency policy, do not introduce it into a project that doesn't already
> use it without explicit user approval. Docs:
> [docs.devart.com/unidac](https://docs.devart.com/unidac/basics.htm).

## Usage

| You say | What happens |
|---|---|
| "This project uses UniDAC — add a repository for X" | UniDAC-idiomatic repository (TUniConnection/TUniQuery, parameterized, provider-aware) following the kit's SOLID rules. |
| "Should we use UniDAC or FireDAC?" | The comparison below + a recommendation grounded in the project's actual constraints (existing license, target DBs, direct-mode need). |
| "Configure UniDAC for SQL Server/PostgreSQL" | Provider unit + `ProviderName` + `SpecificOptions` setup per the patterns below. |
| No provider/database named | Asks which database and which UniDAC provider edition is licensed — never assumes. |

## Core component map

| UniDAC | FireDAC equivalent | Note |
|---|---|---|
| `TUniConnection` | `TFDConnection` | `ProviderName` selects the DBMS |
| `TUniQuery` | `TFDQuery` | live/editable by default |
| `TUniTable` | `TFDTable` | |
| `TUniStoredProc` | `TFDStoredProc` | |
| `TUniSQL` | `TFDCommand` | no result set |
| `TUniScript` | `TFDScript` | multi-statement scripts |
| `TUniTransaction` | `TFDTransaction` | explicit/nested transactions |

## Connection pattern

```pascal
uses
  Uni,
  SQLServerUniProvider;   //her sağlayıcının kendi unit'i uses'a girer

FConnection := TUniConnection.Create(nil);
FConnection.ProviderName := 'SQL Server';
FConnection.Server := 'db-host';
FConnection.Database := 'mydb';
FConnection.Username := 'app_user';
FConnection.Password := 'secret';
//Sağlayıcıya özgü seçenekler SpecificOptions üzerinden verilir:
FConnection.SpecificOptions.Values['Provider'] := 'prDirect';
FConnection.Connect;
```

Key facts (verified against Devart docs):

- Each DBMS needs its provider unit in `uses` (e.g.
  `SQLServerUniProvider`, `PostgreSQLUniProvider`, `OracleUniProvider`);
  forgetting it raises "provider is not registered" at runtime.
- `ProviderName` switches the active provider; changing it on an open
  connection forces a close.
- `SpecificOptions` is the per-provider escape hatch on connection AND
  dataset components (`TUniQuery.SpecificOptions` etc.).
- Devart's **direct mode** (where offered per provider) connects without
  native client libraries — a deployment advantage over client-library-
  dependent stacks; verify per-provider availability in current docs.

## Macros — portable SQL fragments

UniDAC macros (`{if}`/`&Macro` syntax) allow one SQL text to serve
multiple DBMSs. Use them for genuinely portable repositories; don't
macro-ify SQL that only ever targets one DBMS — plain SQL is easier to
read and plan-analyze.

## When to prefer UniDAC over FireDAC

- ✅ Project already licensed and built on UniDAC (consistency wins).
- ✅ Direct-mode deployment without native clients is a hard requirement.
- ✅ A DBMS FireDAC covers poorly but Devart covers well is central.
- ❌ Greenfield with standard DBs and no existing license — FireDAC is
  free with Delphi and this kit's default; adding a paid dependency
  needs explicit approval.

## Shared discipline (same as FireDAC rules)

- Parameterized queries only; transactions explicit; connection/query
  lifecycle owned clearly (`try..finally`); no secrets in logs; error
  handling maps provider exceptions to domain exceptions at the
  repository boundary.
- SQL dialect rules belong to the consuming project; this skill only changes
  the component layer.
