---
name: unidac-data-access
description: "Standards for Devart UniDAC (TUniConnection, TUniQuery, providers, SpecificOptions) as an alternative data-access layer to FireDAC"
---

# UniDAC Data Access — Skill

Use this skill only for an approved optional RAD Library integration under
`src/vendor/`. The core must not reference UniDAC. (The core does depend on
the RTL and mORMot2 - that is the only exception, see `.agents/rules/vendor-integration.md`.)

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

## Firebird: DDL you want to roll back needs its own transaction (measured)

With the InterBase provider, `TUniConnection.AutoCommit` (default `True`) runs
`CommitRetaining` after **every** modifying statement — DDL included — even
inside an explicit `StartTransaction`. So `StartTransaction; ExecSQL('alter
table … add …'); <failing insert>; Rollback` leaves the column in place
(`FbDdlProbe` A, Firebird 5.0.4, UniDAC 13). Two more surprises: every
`SELECT` starts the default transaction and leaves it active, so
`InTransaction` is `True` after any query (B–G all failed with "Can't perform
operation on active transaction"), and a connection-level `AutoCommit := False`
does not help once that default transaction is active.

What works (H/I): a dedicated `TUniTransaction` with `DefaultConnection`, every
query in the unit of work bound to it (`Query.Transaction := Tx`) and
`Query.SpecificOptions.Values['AutoCommit'] := 'False'`; `Tx.Commit` /
`Tx.Rollback`. `ALTER TABLE` through that transaction succeeded while another
query on the same table was open (J). PostgreSQL and SQL Server roll DDL back
fine through the plain connection transaction; MySQL never does.
Implementation: `Help.uni.TRadUniCustomFieldStore.InTransaction`.

## Firebird: text blobs need ftWideMemo on write and a byte path on read (measured)

A `blob sub_type text` column on a `Charset=UTF8`/`UseUnicode=True` connection, UniDAC 13,
Firebird 5 (ScriptLiveTest S06, 2026-11-01):

- **Write:** a parameter set with `DataType := ftMemo` then `AsString` is sent as ANSI bytes and
  Firebird rejects Turkish text with `SQL error code = -303 Malformed string`. Use `ftWideMemo`.
- **Read:** the field arrives as `TMemoField` (not wide) and `AsString` decodes the UTF-8 bytes as
  ANSI: `'ş'` becomes two characters, 100 chars become 105. Read `TBlobField(F).AsBytes` and decode
  with `TEncoding.UTF8`.
- **But only for Firebird.** On PostgreSQL the same `text` column also arrives as `TMemoField`, yet
  `AsString` is already correct and the `AsBytes` path converts the Unicode string to ANSI, raising
  `EEncodingError: No mapping for the Unicode character` on `İ`. The choice must be keyed on the
  dialect, not on the field class. `Help.uni.pas` `TRadUniStoreBase.MemoText` is the shared fix.

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
