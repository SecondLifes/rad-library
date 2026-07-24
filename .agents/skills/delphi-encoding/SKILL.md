---
name: "Delphi Source Encoding (UTF-8 BOM)"
description: "File encoding for Delphi sources — UTF-8 with BOM for .pas/.dpr/.dpk/.inc, mojibake diagnosis and repair, TEncoding on file I/O, why this matters for this kit's Turkish comments"
---

# Delphi Source Encoding — Skill

Use this skill when creating new `.pas`/`.dpr`/`.dpk`/`.inc` files, when
accented characters look corrupted (mojibake) in the IDE or at runtime,
or when auditing a repository's encoding consistency.

**Why this matters in this kit specifically:** code comments and XMLDoc
are written in **Turkish** (`ç ğ ı İ ö ş ü`). A source file saved without
the UTF-8 BOM is read by dcc32 as ANSI, and every Turkish character in
comments and string literals silently corrupts (`Değer` → `DeÄŸer`).

## The rule

| Item | Value |
|---|---|
| Encoding | **UTF-8 with BOM** for `.pas`, `.dpr`, `.dpk`, `.inc` |
| BOM bytes | `EF BB BF` (first 3 bytes of the file) |
| Line endings | **CRLF** (`0D 0A`) — Windows standard; bare LF can confuse the RAD Studio editor |
| Accented string literals | Write the character directly: `'Kayıt bulunamadı'` — never `#NNN` codes |
| IDE setting (Delphi 12+) | Tools → Options → Editor → General → "Default file encoding" = `UTF-8 with BOM` |

**Files this rule does NOT apply to:**

- `.dfm` — stays in the IDE's own format (current Delphi versions stream
  text DFMs as UTF-16 LE with BOM). Do not convert.
- `.dproj` (XML) — UTF-8 **without** BOM is MSBuild's default. Leave as is.

## Checklist when creating/editing a Delphi file

1. New file written by an AI tool → **verify the BOM** — some file-write
   tools emit UTF-8 *without* BOM on Windows; the content bytes are right
   but dcc reads the file as ANSI. Check and prepend if missing
   (`references/utf8-bom.md` has the scripts).
2. Editing an existing file preserves its BOM — only *newly created*
   files need the check.
3. `TStringList.LoadFromFile`/`SaveToFile` → always pass `TEncoding.UTF8`
   explicitly as the second parameter.
4. Never "fix" broken accents by re-saving as ANSI — the bug is in the
   write step's encoding, not in the accents.

## Anti-pattern — `#NNN` character concatenation

```pascal
//❌ YASAK — okunmaz, gereksiz (legacy ANSI döneminin kalıntısı)
LMsg := 'Ge' + #231 + 'ersiz de' + #287 + 'er';

//✅ DOĞRU — UTF-8 BOM'lu dosyada doğrudan yaz
LMsg := 'Geçersiz değer';
```

## Symptoms that route here

- Runtime/UI shows `DeÄŸer`, `Ã§`, `ÄŸ` instead of `Değer`, `ç`, `ğ`.
- Accents become literal `?` or `�` (U+FFFD) after a file was generated.
- Git diff shows the whole file changed after merely opening it in the
  IDE (IDE re-saved with different encoding).

## references/

- `utf8-bom.md` — BOM verification and mass-fix PowerShell scripts, the
  AI-write-tool caveat and byte-level repair procedure, Turkish character
  codepoint table, known pitfalls (`__history/`, PowerShell 5.1 vs 7+
  `-Encoding UTF8` difference).
