# `src/` layout

This directory now contains the real **Rad Core** library — imported from
its original working repository (`Rad Core | Enterprise Delphi Framework`,
maintained separately outside this kit). It is the reference implementation
this kit's rules were themselves derived from (see `ACKNOWLEDGMENTS.md`).

```text
src/
├── core/        reusable library code (RTL + mORMot2 only) — help.*.pas units
│                (help.date, help.rtti, help.str, Help.DB, Help.uni, Help.vcl)
│                plus rad.*.pas core units (rad.cache, rad.cmd, rad.eventbus,
│                rad.permission, rad.sqlfilter, rad.customfield, rad.script, rad.script.override (+ vendor/tms: rad.script.engine/hooks/jobs/facade/commands/typedhooks/dev/uni, tasarımcı: rad.script.design/.bar/.tools, IDE: rad.script.ide/.newscript/.packages; giriş birimleri rad.scripting (ERP) ve rad.scripting.kp (KP)), rad.thread, rad.utils,
│                rad.worker, ...)
├── component/   VCL components and their editors (Permission.Edit,
│                rad.db, rad.rtl, rad.vcl, rad.formstate, rad.dev, rad.dev.customfields —
│                custom-field frame — and rad.dev.customfielddesigner, its
│                definition dialog) — no separate fmx/ split yet;
│                everything here targets VCL today
├── share/       shared forms used across components (Kisayol.Edit) — not part of the original layout contract
│                below; kept as its own top-level folder rather than
│                forced into component/
├── packages/    RadKon (runtime only, {$RUNONLY}) and RadKonD (design only:
│                Rad.Register.pas, Rad.Editor.pas, Rad.Editor.FormState(.Model),
│                and Rad.Editor.Tools.pas plus Rad.Editor.FluentOptions.pas,
│                the IDE-free parts of RadMenü). Install RadKonD in the IDE;
│                it pulls in RadKon. RadScriptTms(Design) for the script system.
├── test/
│   ├── unit/    DUnitX test units (one per source unit, `.Tests.pas`)
│   ├── app/     a DUnitX GUI test runner project (Rad_Test_GUI)
│   └── scratch/ ad hoc benchmark/smoke-test projects, kept for reference
├── rad.json.pas, clear.ps1, vendor.bat   root-level support files
```

A source named `help.date.pas` is tested by
`src/test/unit/help.date.Tests.pas`. Component classes use `TRAD`. Real
imported code is the working reference — it does not by itself authorize
inventing new public API surface beyond what it actually contains; extend
it following the same rules (`helper-patterns.md`, `component-patterns.md`,
`vendor-integration.md`) as any other change to this library.

## RadMenü (design-time tools)

RadKon adds a top-level **RadMenü** to the IDE main menu, right after Tools, and a
**RadMenü** submenu to the designer's right-click menu. Design-time tools go there:
add one `AddTool` line in `TRadMenuTools.Install` (`packages/Rad.Editor.pas`) plus
its handler, and the tool appears in both. `RadMenü` is built with
`INTAServices`, not with a component editor, so no registered editor is
replaced or disabled. The menu is removed in the unit's `finalization`.
The right-click submenu is a `TSelectionEditor` verb, which adds a line without
touching component editors. It copies the main menu's items, and the IDE drops it
when the package unloads.

**Seçili Komponenti Fluent'e Çevir** is in both menus. On the form itself the
right-click RadMenü is hidden, because the command cannot run there. It runs
`TRadFluent.GenerateUnit` on the class of every selected component. A form first lists
the classes with their member counts and asks whether to include inherited
members (`fgoIncludeInherited`, off by default); the counts show the cost before
you choose. Then it asks for a `.pas` path and opens the result in the
editor, because the generated unit needs its `uses` clause to compile and may
hold several classes. If the file exists, only that class's `RAD-FLUENT`
regions are updated; everything else in it stays. Sources are looked up in the
IDE's Browsing and Search paths to see past the RTTI blind spots. If a source is
not found, the class is generated from RTTI alone and the unit's header says so.
The form or frame being designed cannot be converted: its class is not loaded in
the IDE.

`Rad.Editor.Tools.pas` and `Rad.Editor.FluentOptions.pas` must stay free of `DesignIntf`, `DesignEditors` and
`ToolsAPI`. `test/scratch/rad_radmenu/build_and_run.bat` tests it from a console
on Win32 and Win64, compiles a generated unit and checks the linker map for
those units. `test/scratch/rad_fluentgen/build_and_run.bat` covers the generator
itself: every unit it produces, from trap classes and merge targets, must compile.
A public member that uses a private nested type still needs a manual edit
(`TStringBuilder.GetEnumerator`): RTTI cannot tell such a type apart.

### Manual check in the IDE

The console cannot reach these, so run them after every change to the menu:

1. Rebuild and install RadKon. **RadMenü** appears after Tools.
2. On a form, select a `TButton`, choose RadMenü > Seçili Komponenti Fluent'e
   Çevir. The options form lists `TButton` with its member counts and the
   inherited box is off. Choose Devam and save as the suggested
   `Button.Fluent.pas`. The unit opens in the editor and compiles. Vazgeç on the
   form writes nothing.
3. Select a `TLabel`, tick the inherited box and save into the same file. The
   unit compiles and the `TLabel` wrapper has `SetName`. `TButton` stays, `TLabel` is
   added. Run it again with unsaved edits in that tab: the edits survive.
4. Select nothing, so the form itself is selected. RadMenü shows a message and
   writes no file; the right-click menu has no RadMenü line. Do the same
   with a frame dropped on a form.
5. Right-click a `TButton`: one **RadMenü** line opens a submenu with the
   command, and it gives the same result as step 2.
6. Right-click and double-click `TRadPermission`, `TRadComboBox` and a stock
   `TButton`. Their usual editors and context menu entries work as before.
7. Component > Install Packages: untick RadKon. Both **RadMenü** entries
   disappear. Tick it again: one of each returns, not two.
8. Close the IDE. No error appears on shutdown.

## Form state (`rad.formstate`)

`TRadPropertiesStore` saves chosen published properties, the window placement and
free key/value pairs of a form or data module as JSON, and restores them before the
owner's `OnCreate`. One setup call through the entry unit:

```pascal
uses rad.formstate;
TRadFormState.Kur(TRadFormState.FileStore, 'emrah');   // or DbStore(Conn), CallbackStore; 3rd: IRadCipher
// FileStore(srExeFolder, 'state'): beside the exe instead of %LOCALAPPDATA%\<exe>
...
TRadFormState.Kapat;                                    // saves forms still open
```

| Unit | Role |
|---|---|
| `core/rad.formstate.core` | dotted property paths over mORMot RTTI, document rules, `IRadStateful` |
| `core/rad.formstate.store` | file and callback stores, encryption envelope, cached repository, `Prefetch` |
| `vendor/unidac/rad.formstate.uni` | database store (PostgreSQL, SQL Server, Firebird) |
| `component/rad.formstate.component` | `TRadPropertiesStore` |
| `component/rad.formstate` | entry unit: aliases and `TRadFormState` |
| `packages/Rad.Editor.FormState(.Model)` | design-time editor (right click: Durum Editörü...) |

A `StoredValues` item with a `ValueType` (`svtInteger`, `svtDateTime`, ...) always reads back
as that type: an unconvertible value falls back to its default, never raises.
`TRadActionList` implements `IRadStateful`: list it in `Items` and its shortcuts are
saved with the form. Spec, decisions and measurements: `docs/specs/rad.formstate.md`.
Tests: `test/scratch/rad_formstate/build_and_run.bat Win32|Win64 <runner>` with
`RunFormStateTests`, `RunFormStateVclTests`, `RunFormStateEditorTests` or
`RunFormStateDbTests` (live databases).
