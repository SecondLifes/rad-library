# Changelog

All notable changes to RAD Library AI Spec-Kit are documented here.

## Mandatory: record every file that was added, removed or renamed

**Any commit that adds, deletes or renames a file under `.agents/rules/`,
`.agents/commands/`, `.agents/skills/`, `tools/`, or any root-level document
must name that file here, in the same commit.** Not "updated the rules" —
the actual path, and one clause saying what it is for.

Three things in this kit read the file inventory and go wrong silently when
it drifts: `docs/proje-haritasi.md` states what exists and how many, and the
count gate in `tools/verify-kit.ps1` compares those claims against disk;
`tools/generate-ai-configs.ps1` produces one copy or link per source file, so
a file nobody recorded is a file nobody notices going stale; and anyone
auditing this kit later reconstructs what happened from this file plus
`git log`.

A change that only edits the *contents* of an existing file needs no
inventory line — describe the behavior that changed instead. The rule is
about files appearing, disappearing or moving, because those are the changes
that break something else in the kit.

## [Unreleased]

### Added

- `src/test/scratch/rad_dev_repolisteners/PullTest.dpr` —
  46 assertions covering the new pull direction (event fires exactly once with
  the right source/master/value, re-entrancy guard, `DoAssign` carries the pull
  payload, free-notification nils `AMaster`, `PullWarning` reports each silent
  trap). One assertion is red-first: with the old `DoCascade` gate restored it
  fails, proving the invalidation defect below was real. Green on Win32
  and Win64 (35/35).
- `src/test/scratch/rad_dev_repolisteners/build_and_run.bat` and
  `src/test/scratch/rad_dev_livedb/build_and_run.bat` — these two probe
  directories were the only ones in the kit with no build script, which is a
  large part of why their probes rotted unnoticed. Both take a platform
  argument (`Win32` default, `Win64`) and an optional probe name, and both
  honour `%EXTRAU%` for unit paths this repo does not ship.
- `src/component/Rad.Dev.pas` — `AMasterField` and `AAutoFilter`, the pull
  direction's two conveniences. `AMasterField` is the free payload `ACascadeField`
  is for push, and doubles as the parameter/field name the automatic mode uses.
  `AAutoFilter` (`afNone` default, `afParam`, `afFilter`) applies the filter in
  the component for the ordinary "field = master's value" case, so a dependent
  lookup needs no `AOnFilter` at all. Decisions worth knowing: the automatic
  filter runs **before** `AOnFilter`, which still fires and can refine it; an
  empty master **closes** the list dataset, because a city list has no meaning
  before a country is chosen, and closing says that without filter-expression
  tricks; `afFilter` formats integers bare and everything else quoted, so a
  decimal or date master needs `AOnFilter` rather than a silently broken
  expression built with a locale decimal separator. Misconfiguration raises
  `ERadDev` at first popup and is reported by `PullWarning` before that.

- `src/component/Rad.Dev.pas` — `RadChainAudit(ARoot: TComponent): string`
  walks a component tree and collects every `ChainWarning` and `PullWarning`
  it finds, reporting each shared `Properties` instance once. The unit had
  grown three diagnostic queries (`ChainWarning`, `PullWarning`, and the
  settings panel's own `Warnings`) with **no caller anywhere** — a mechanism
  built to surface silent misconfiguration that was itself silent. This stays
  a query rather than an automatic warning, for the reason `ChainWarning`
  already documents: a form mid-DFM-load looks misconfigured for a moment, so
  warning on its own would cry wolf. One `{$IFDEF DEBUG}` line in `FormCreate`
  is now enough to see everything.
- `src/component/Rad.Dev.pas` — `ERadDev`, the unit's first exception class.

### Changed

- `src/component/Rad.Dev.pas` — `AMaster` now rejects anything that is not a
  `TcxCustomEdit` or a `TcxCustomGridTableItem`. The Object Inspector's
  component dropdown offers every component on the form, and `_ValueOf` reads
  only those two kinds — so picking, say, a button handed `AOnFilter` a `Null`
  master value on every call, producing an empty list with no exception and no
  warning. The symptom ("it behaves as if no country is selected") pointed
  nowhere near the cause. It now raises at assignment time, i.e. in the
  designer.

- `src/component/Rad.Dev.pas` — `DoFilter` counts the times it skips because
  the list dataset was busy, and `PullWarning` reports the count. Skipping is
  correct (it breaks recursion) but its consequence was invisible: the dropdown
  opened showing an unfiltered list and nothing said so.

- `src/component/Rad.Dev.pas` — file encoding repaired. It was UTF-8 except for
  three stray cp1254 bytes (`Oluştur`, in the header comment), which made it
  invalid UTF-8 as a whole: `file` reported "Non-ISO extended-ASCII" and any
  UTF-8 tool either failed on those lines or corrupted them. Converted, and a
  BOM added per this kit's `delphi-encoding` rule.

- `src/component/Rad.Dev.pas` — **the cascade's main direction is inverted.**
  A dependent lookup now declares its own master (`AMaster`) and filters its own
  list when its dropdown opens (`AOnFilter`), instead of the source pushing a
  filter into up to four target slots. The dependent knows what it depends on,
  the way a foreign key does; adding one no longer means editing the source, and
  the query runs only when someone actually opens the list — a four-deep chain
  used to fire three queries nobody was looking at.

  Push is kept, deliberately, but reduced to an **invalidation signal**: pure
  pull cannot fix a stale value, because if nobody ever opens the dependent's
  dropdown nothing pulls, and an inconsistent key reaches the database still
  displaying its old text. `AOnCascade` is not deprecated — it still has jobs
  pull cannot do (refreshing a target that has no popup at all).

  The pull fires from a `DoInitPopup` override on `TRadCustomLookupComboBox`,
  before `inherited`. Measured from the vendor source: `DoInitPopup` runs at
  `cxDropDownEdit.pas:3256`, its `OnInitPopup` calls at `:3150`, and
  `ILookupData.DropDown` only at `:3159` — so a filter applied there affects
  *this* opening, and it lands before `Properties.LockDataChanged`
  (`cxLookupEdit.pas:309`) would have suppressed it. The published
  `OnInitPopup` event was rejected for the seam: it belongs to the application,
  and `DoInitPopup` fires it **twice** when a repository item is present
  (`:3150` and `:3152`) — two filter queries per popup, silently.

- `src/component/Rad.Dev.pas` — `FilterNow` added next to `CascadeNow`. Not
  symmetry for its own sake: `TcxCustomDropDownEdit.DropDown` begins with
  `if not IsWindowVisible(Handle) then Exit` (`cxDropDownEdit.pas:3252`), so
  `DoInitPopup` never runs in an invisible window and the pull path would
  otherwise be unmeasurable without a visible form.

- `src/component/Rad.Dev.pas` — `ResetLocateCache` was only clearing the kit's
  own resolved-key cache. DevExpress keeps a second one, `FLookupList`
  (`cxDBLookupEdit.pas:71`), which `GetDisplayLookupText` both reads and writes
  in its `GridMode` branch — and which closing and reopening the list dataset
  does **not** clear; only `CheckLookupList` (`:419-425`) does. A target whose
  list had just been re-filtered therefore kept showing the old text. New
  `ResetDisplayCache` / `ResetCaches` clear both layers, and every place that
  invalidates a target now uses `ResetCaches`.

- `docs/olcum-listesi.md` — Ö-02 largely closed (all six cascade probes now
  compile on Win32 **and** Win64, four of them running green on both), and Ö-11 /
  Ö-12 added for the pull measurements that need a visible window and a live
  database. Also records that today's runs used **stub units** for `JclBase`,
  `JclSysInfo` and `Dext.Types.UUID`, none of which exist on this machine.

### Fixed

- `src/test/scratch/rad_dev_repolisteners/RuntimeTest.dpr` — the probe passed a
  `for..in` loop variable straight into `DoEditKeyPress(var Key: Char)` (W1015,
  twice). A key-press handler is allowed to rewrite the key — swallowing it is
  `Key := #0` — so this wrote back into a loop variable the compiler may keep in
  a register. Copies into a local now. Also an unused variable (H2164). The
  probe directory is now diagnostic-free on both platforms.

- `src/component/Rad.Dev.pas` — `RadChainAudit` looked only at each consumer's
  *active* Properties, so it missed a master set on a consumer's **own**
  Properties while a shared `RepositoryItem` was bound. That is precisely the
  layout `ChainWarning` tells you to adopt, and the kit's own `PerConsumerTest`
  measures — the audit could not check the configuration it recommends. It now
  inspects own and active, deduplicating by instance. `PullTest` T13 was
  verified red before the fix.

- `src/component/Rad.Dev.pas` — `DoFilter` cleared its caches *after* the
  try/finally, so a handler that raised part-way through reopening the list left
  the list changed and both caches stale, and the editor went on rendering the
  old text. Moved into `finally`. The same block also broke the unit's own
  `Enter`-immediately-before-`try` discipline (which `DoLocate` and `DoSearch`
  follow); an assignment sat between them.

- `src/component/Rad.Dev.pas` — `AMaster` accepted a circular assignment: an
  editor as its own master, or — with a shared `RepositoryItem` — a master that
  is another consumer of the very Properties being configured, since one
  `AMaster` field serves them all. `FFiltering` stopped it recursing, so it
  produced no crash, just a list silently filtered by its own value. Now raises
  `ERadDev`.

- `src/component/Rad.Dev.pas` — `RadChainAudit`'s header printed an empty name
  for a root created in code; falls back to the class name.

- `src/component/Rad.Dev.pas` — `DoCascade` exited early when no `AOnCascade`
  handler was assigned, which also killed the target invalidation that runs
  alongside it. Harmless while every cascade had a handler; a silent
  data-integrity bug the moment pull makes an unassigned `AOnCascade` the norm —
  the master changed, the target kept its now-invalid key **and** its stale
  display text, and nothing warned. The gate is now "is there any target",
  the event call is conditional, and `PullTest` asserts it (red-first verified).
  Both families fixed; `TRadComboBoxProperties.CascadeOne` additionally never
  invalidated its targets' caches at all.

### Added

- `src/share/k.setting.pas` + `src/share/k.setting.dfm` — the searchable
  settings panel. `TdxNavBar` on the left (group = category, item = sub-group),
  one `TcxVerticalGrid` holding **every** setting on the right, a search box on
  top, and a Delphi-Object-Inspector-style description strip below it. Values
  live in an `IDocDict` with `PathDelim` set to `'.'`, keyed by the full dotted
  path (`fatura.satis.vade_asim_uyar`); the grid row is only the view. A
  setting class is a `TRadOptions` descendant whose published properties are
  the settings and whose nested published `TRadSetting` fields become
  sub-categories — `TSynAutoCreateFields` already creates, owns and serializes
  that tree, so it is not declared a second time anywhere. Registration and
  presentation come from one fluent chain (`AddMenu` / `AddSubMenu` /
  `Register` / `Title` / `Repository` / `Choices` / …); `Register` builds a row
  for every published property on its own, so the chain only names the ones
  that differ from the default. Rows are created once and filtered by
  `Visible`, which is what lets search span categories.
- `src/test/scratch/rad_setting/` — the panel's probe: `SettingTest.dpr`,
  `SettingModel.pas` (the test setting classes, deliberately in their own unit
  rather than the `.dpr`), `build_and_run.bat` (takes `Win32`/`Win64`).
  52 assertions, green on both platforms: key generation, the `default`
  directive read back through RTTI, the JSON actually being a tree, unknown
  keys surviving a load/save round trip, duplicate/missing `index` raising,
  search crossing category boundaries, and the property accessors reaching the
  store in both directions.

- `.agents/skills/rad-code-fix/` — bundled copy of the workspace's own
  `rad-code-fix` skill: `SKILL.md`, `agents/openai.yaml`,
  `references/finding-taxonomy.md`, `references/probe-patterns.md`,
  `references/toolchain-map.md`. Language- and toolchain-agnostic whole-file
  code auditing — it measures a baseline before changing anything, reports
  findings with evidence, applies approved repairs leaf-first from a dependency
  DAG, implements requested enhancements against acceptance criteria, and
  applies a findings report written elsewhere by re-verifying every entry
  against the code as it stands now rather than trusting it. Now part of the workspace's default skill
  bundle.

- `.agents/skills/mormot2-integration/references/verified-api-traps.md` — mORMot2
  APIs that compile cleanly and fail **silently** at runtime, each entry proven
  by a probe rather than a read-through. First entries: `AesPkcs7` does not
  store a GCM authentication tag even when passed `mGcm` (tamper detection
  silently absent — use `TAesGcm.MacAndCrypt`), its password overload derives
  the IV from the password so repeated saves reuse the keystream, `TAesGcm`
  instances are stateful and not thread-safe, and `mormot.crypt.core` needs
  the separately-downloaded `static/` binaries. `SKILL.md` now points at it and
  instructs adding to it whenever a probe uncovers another one.
- `src/core/rad.cipher.pas` — the encryption layer: `IRadCipher` (bytes in,
  bytes out — no base64, envelope or file-format concerns) and
  `TRadAesGcmCipher` over `TAesGcm.MacAndCrypt` with a random IV per call.
  Documented honestly as **at-rest obfuscation** rather than encryption,
  because the design brief embeds the key in the application: it protects the
  file from anyone who sees the file but not the binary, and nothing more.

### Changed

- `.agents/skills/mormot2-integration/references/verified-api-traps.md` — eight
  more measured traps, taking the file from four entries to twelve. Six come
  from the JSON-layer work and were sitting uncommitted: `DocDict`/`DocList`
  accept invalid JSON silently, `DocDict()` erases the real `Kind`,
  `FlattenFromNestedObjects` does not add the counter it promises,
  `AddOrUpdateObject(..., RecursiveUpdate := True)` corrupts the target,
  `TDocVariantData` is not thread-safe and `IDocDict` cannot be subclassed, and
  a nested `IDocDict` dangles after **one** insertion into its parent. Two are
  new, found while building the settings panel: `mormot.core.base` brings
  `RawUtf8` overloads of `LowerCase`, `Pos` and `Trim` that shadow the RTL
  ones, so unqualified calls on `string` silently round-trip through UTF-8 —
  seven occurrences in one unit that never mentions `RawUtf8`, reported only as
  W1057 warnings a hidden-warning build would drop; and `IDocDict.PathDelim`
  defaults to `#0`, so dotted keys are written as one flat key and no JSON tree
  is ever built. Measured both ways; neither raises.

- `src/core/rad.core.pas` - `TAbstractLockable` routes every lock method through
  a now-**virtual** `GetSafe`, so a descendant that shares another object's data
  can redirect to that object's lock. Without it, an object holding a view over
  another object's structure would guard that structure with a second, private
  lock - two locks, one structure, and writers that never see each other.
  Classes that do not share data are unaffected.
- `src/core/help.mormot.pas` - the flatten failure is `EMormotFlatten`, not the
  shorter `EJsonFlatten`. The short name collided with an identically named
  exception in another unit, so `on E: EJsonFlatten` in any unit that used both
  resolved by `uses` order - silently, with no diagnostic.

- `src/core/rad.config.pas` — encryption now has three modes, chosen with a new
  `TRadCryptMode` constructor argument. `rcmFile` (the default) wraps the whole
  document; **`rcmSection` encrypts only sections whose new virtual
  `TRadOptions.Encrypted` class function returns True**, leaving the rest of the
  file readable and the section names visible — an encrypted section's value
  becomes the single string `RADSEC1:aes-gcm-256:<base64url>` (in INI, a one-key
  `enc=` block). The payload is always the section's JSON, so all three file
  formats share one decrypt path. `rcmNone` is forced whenever no cipher is
  supplied, so a file can never claim encryption it is not doing.
- `TRadOptionsFile` now hashes **its own plaintext serialization** on both save
  and load, instead of the file text. Two bugs made this necessary: a
  section-encrypted document contains a marker that changes every save (random
  IV), so it could never hash equal; and hashing the file text meant any
  formatting difference between disk and our serializer triggered a pointless
  write after every load. Both sides now measure the same deterministic thing.
- `tools/verify-kit.ps1` no longer fails on its own documentation. Excluding the
  script by name was not enough — any file describing the placeholder check
  contains the literal marker, so `docs/proje-haritasi.md` and `CHANGELOG.md`
  were reported as holding unfilled placeholders. Prose writes the marker
  backticked; a real placeholder never is, so only the backticked form is
  excluded. A gate that fails on its own docs teaches people to ignore it.
- **The "dependency-free core" claim is gone — it was false.** `.agents/rules/vendor-integration.md`
  now states two tiers: mORMot2 is a **base dependency** that `src/core/` calls
  directly with no adapter, while UniDAC, DevExpress, TMS, FastReport and JEDI
  remain optional and isolated under `src/vendor/`. The old wording contradicted
  every core unit that ships (`rad.core`, `rad.cipher`, `rad.config`,
  `rad.cache`, `rad.utils`, `rad.thread`, `rad.eventbus` all `uses` mORMot), and
  a rule that contradicts the code teaches the next session either to break
  working code enforcing it or to stop trusting the rules. Corrected in the same
  pass across `library-packaging.md`, `component-patterns.md`, the four identity
  files (`AGENTS.md`, `.claude/CLAUDE.md`, `.github/copilot-instructions.md`,
  `.gemini/rules/project-rules.md`), `.kiro/steering/product.md`, `src/README.md`,
  `ACKNOWLEDGMENTS.md` and five vendor skills. Earlier CHANGELOG entries citing
  the old rule are left as-is: they record what was believed at the time.
- `.agents/rules/delphi-conventions.md` gained two compile-verified traps: set
  constructors cannot hold an element above 255 (`in [128, 192, 256]` is
  `E1012`, and the message points at the whole expression rather than the
  offending member), and an identifier shadowing a same-named routine
  case-insensitively (a local `c` hides a procedure `C`, and the compiler
  reports a missing semicolon that is not there).
- `src/core/rad.config.pas` — optional whole-file encryption. Passing an
  `IRadCipher` to the constructor wraps the entire serialized document in a
  single `data.enc` envelope (base64url, plus `alg` and `v`), so section names
  are hidden too and per-section encryption is unnecessary. The file stays
  valid in its own format and keeps its extension. Also drops this unit's
  duplicate `ERadCore` in favour of `rad.core`'s, so one `except on E: ERadCore`
  really does catch the whole tree.

### Removed

- `src/rad.json.pas` - the JSON abstraction layer is withdrawn. It was an
  interface tree (`IJson`/`IJsonArray`) with a runtime provider-registration
  mechanism over a single implementation, and the abstraction earned nothing:
  there was never a second provider, while a caller who forgot the provider
  unit still compiled and failed only at runtime. `rad.config` now uses
  mORMot's `IDocDict` directly.
- `src/core/rad.cache - Kopya.pas` — an 829-line stray copy of
  `src/core/rad.cache.pas` sitting in the same folder. Two units declaring the
  same symbols in one compilation shadow each other by `uses` order, which is
  exactly the defect that had to be removed from `rad.pas` in this same
  release. Recoverable from git history if it turns out to have been wanted.

### Added

- `TSmartCache` (and `ISmartCache`) gained JSON persistence: `SaveJson`,
  `LoadJson`, `SaveToFile`, `LoadFromFile`. The format is a versioned envelope
  that stores an explicit **type tag** per entry, because this cache is
  type-strict on read — writing `Integer 42` and reading it back as `Int64`
  would make `Get<Integer>` silently return the default. Values that cannot
  round-trip (objects, interfaces, records, arrays, sets, non-Boolean enums)
  are skipped and reported through `SaveJson(out ASkipped)` rather than being
  written as garbage; `TObject` in particular is a raw unowned pointer here, so
  persisting it would be meaningless. `LoadJson` parses in full before touching
  the dictionary, so a malformed document leaves the cache unchanged, and
  `SaveToFile` writes to a temp file and moves it over the target
  (`MoveFileEx`/rename) so a crash mid-write cannot destroy the previous state.
  Persistence uses RTL `System.JSON`, not `rad.json` — the cache must not
  require a JSON provider to be registered.
- `rad.json` gained fluent writers (`SetV` overloads plus `SetVar`), fluent
  `Add` on `IJsonArray`, `Get(AKey, ADefault)` readers, ISO-8601
  `GetDateTime`/`SetDateTime`, and object/record conversion
  (`FromObject`/`ToObject`/`FromRecord`/`ToRecord` with the `TJsonRec.Save`/
  `Load` generic wrapper, since Delphi interfaces cannot carry generic methods).
  `TDateTime` deliberately stays out of the overload sets: it shares `Double`'s
  representation and would make numeric literals ambiguous.
- `src/vendor/rad.json.mormot2.pas` — the first implementation of the
  `rad.json` contract, built on mORMot2 `IDocDict`/`IDocList`. Registers itself
  from `initialization`, so adding the unit to `uses` is the whole setup. It
  lives under `src/vendor/` because `vendor-integration.md` keeps the core
  dependency-free: `rad.json` still knows nothing about mORMot.
- `rad.json` gained a real error contract (`EJson` and four descendants),
  provider registration (`RegisterJsonProvider` / `UnregisterJsonProvider` /
  `IsJsonProviderRegistered`) replacing the two global factory variables, and
  `GetDef` overloads on `IJsonArray` plus the missing `Currency` one on `IJson`.
  Its interface GUIDs were regenerated — the previous pair was hand-written and
  one of them was not a valid RFC 4122 variant.
- `GenerateFluentUnit`, `ListFluentRegions` and `PruneFluentRegions` in
  `src/core/rad.utils.pas`. `GenerateFluentUnit` writes a compile-ready unit to
  disk (UTF-8 + BOM) instead of returning a fragment to paste by hand: it
  resolves `uses` from RTTI `QualifiedName`, wraps everything in
  `{$REGION 'RAD-FLUENT:<Class>:TYPES|IMPL'}` markers, and in `fumMergeRegions`
  mode updates only its own regions so one unit can carry several classes
  alongside hand-written code. Re-runs reuse the GUID already in the file, so
  the operation is idempotent. `PruneFluentRegions` removes orphaned regions
  (dry-run by default) — nothing else in the kit could detect them.
- `.agents/rules/delphi-conventions.md` gained two sections, "RTTI blind spots"
  and "Unit name qualification in generated `uses`". Both document defects that
  were found by compiling and running probe programs, not by reading docs, and
  both silently corrupt any RTTI-driven generator/serializer/mapper.

### Fixed

- **`GenerateFluentCode` silently omitted properties, and silently emitted
  wrong method signatures.** Delphi produces no RTTI for enumerations with
  explicitly assigned values (`TAESKeyLength = (kl128 = 128, ...)`), so such a
  published property is invisible at runtime — confirmed by execution on Delphi
  37.0. The generator now accepts the declaring `.pas` path, reconciles the
  source against what RTTI reports, emits the missing members marked
  `// [KAYNAK]`, and refuses to emit a method whose RTTI signature is provably
  wrong (a lost parameter, or a function degraded to `mkProcedure`) instead of
  producing code that fails to compile or drops a return value.
- **Untyped parameters crashed the generator.** `TRttiParameter.ParamType` is
  `nil` for `var Buf`; the old code dereferenced `.Name` unconditionally.
- **Open-array parameters produced a wrong signature.** `pfArray` was ignored,
  so `const A: array of Integer` was emitted as `const A: Integer`.
- **Generated `uses` could not compile against legacy sources.** RTTI reports
  `System.Classes` while an older unit's own `uses` says `Classes`; both in one
  clause is `E2004`. Bare and namespace-qualified forms of the standard RTL
  roots are now collapsed to one entry.
- `src/core/rad.pas` no longer carries a byte-identical duplicate of
  `GenerateFluentCode` (~350 lines). Two units exporting the same function meant
  `uses` order silently decided which one a project got. `rad.utils.pas` is the
  single source; `rad.pas` keeps a pointer comment.

- **Claude Code could not discover any of this kit's skills.** It looks only
  under `.claude/skills/`; `.agents/skills/` is not one of its discovery
  locations, so every skill here was unreachable by trigger matching and only
  worked if the user typed the generated `/<skill-name>` wrapper by hand.
  `tools/generate-ai-configs.ps1` now creates one junction (Windows, no
  elevation needed) / symlink per skill under `.claude/skills/`, pointing back
  at `.agents/skills/`. The links are gitignored and regenerated after a clone,
  so the "symlink degrades on clone" hazard that keeps rules as copies does not
  apply. Verified against `code.claude.com/docs/en/skills`.
- **Cursor ignored every rule in this kit.** `.cursor/rules/` held `.md` files;
  Cursor recognizes only `.mdc` there and silently skips anything else. The
  frontmatter was already correct — only the extension was wrong. The generator
  now writes `.mdc` and sweeps the old `.md` copies instead of leaving both.
  Verified against `cursor.com/docs/rules`.
- **Gemini CLI read nothing.** The AI-tool table pointed it at
  `.gemini/rules/project-rules.md`, but Gemini CLI builds context from the
  `GEMINI.md` hierarchy. Added a root `GEMINI.md` that imports that file rather
  than duplicating it. Verified against `geminicli.com/docs/cli/gemini-md`.
- **`.claude/settings.json` used invented keys.** `allowCommands`/`denyPaths`
  are not Claude Code settings, so the advertised `.env`/`.key` protection and
  the pre-approved generator command never existed. Rewritten to the real
  `permissions.allow`/`permissions.deny` schema.
- Corrected the false claim, repeated across this kit's rules, `AGENTS.md`,
  `docs/ai-ignore-strategy.md`, the READMEs and the generator itself, that
  `.agents/skills/` "is read as a fallback location natively by every supported
  tool." It is not, and that assumption is what left the skills unreachable.
- Fixed the mutually broken links between `prompt-engineer-analyst.md` and
  `design/prompt-patterns.md` in the bundled `rad-prompt-studio`.

### Added

- `.agents/rules/analysis-output.md` — the input-resolution and output-naming
  rule the three bundled `rad-prompt-studio` master prompts reference but which
  was not present in this kit, leaving them unable to resolve a report path.
- `tools/verify-kit.ps1` and `.github/workflows/verify.yml` — a mechanical
  consistency gate (generator drift, Cursor extension, skill-link presence,
  `SKILL.md` frontmatter, `[FILL IN` residue, README image links, `LICENSE`),
  runnable locally as `pwsh tools/verify-kit.ps1` and in CI from one script.

## [0.1.1] - 2026-08-03

### Fixed

- `CONTRIBUTING.md`/`.tr-TR.md` and `SECURITY.md`/`.tr-TR.md` linked to
  `github.com/SecondLife/rad-library` — a typo'd owner name (missing
  trailing `s`) that 404s. The real authenticated owner is `SecondLifes`;
  every link now points there. Root cause was a stale
  `github_username_or_org` value in the workspace's `template-vars.json`,
  already fixed upstream — this propagates that fix to files generated
  before the correction.

## [0.1.0] - 2026-07-24

### Added

- Initial commit-pinned derivation from the approved base kit.
- Delphi 13+ Win32/Win64, VCL/FMX library and component contract.
- Helper, component, test, performance and optional vendor-integration rules.
- FMX, JEDI and mORMot2 guidance; JEDI/mORMot2 remain conditional pending
  local Delphi 13+ compilation.
