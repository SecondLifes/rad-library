# Design-Time Integration — Packages, Register, Editors

## Runtime vs design-time package split

A distributable component library ships (at minimum) two packages:

| Package | Suffix convention | Contains | Requires |
|---|---|---|---|
| Runtime (`MyLibR.dpk`) | `R` | All component/logic units | `rtl`, `vcl`, other runtime deps |
| Design-time (`MyLibD.dpk`) | `D` | `*.Reg.pas` (Register), property/component editors | `MyLibR`, `designide` |

Hard rules:

- `DesignIntf`, `DesignEditors`, `ToolsAPI` units appear ONLY in the
  design-time package — they cannot be deployed with an application, and
  a runtime package referencing them will not build outside the IDE.
- The design-time package is compiled with "Designtime only" usage; the
  runtime one "Runtime only" (or both, for trivial libs — but the split
  is the professional default).
- Set the package's LIB suffix to `$(Auto)` (Description page → LIB
  suffix) so the produced BPL carries the compiler version suffix
  (e.g. `MyLibR290.bpl` style) automatically per Delphi release — never
  hardcode a version number that goes stale.
- Unit names must be globally unique across all installed packages — use
  a dotted namespace prefix owned by the library (e.g.
  `MyLib.Core.Watcher.pas`).

## The Register unit

Registration lives in a dedicated unit (`MyLib.Reg.pas`) in the
design-time package — never inside a component unit:

```pascal
unit MyLib.Reg;

interface

procedure Register;   //büyük R — IDE bu imzayı arar

implementation

uses
  System.Classes,
  MyLib.Core.Watcher,
  MyLib.Core.Throttle;

procedure Register;
begin
  RegisterComponents('MyLib', [TFolderWatcher, TThrottle]);
end;

end.
```

- One palette category per library (`'MyLib'`), not per component.
- `RegisterComponents` streams from the runtime units; the Reg unit is
  the only design-time-package member besides editors.

## Property editors

For a published property that needs a picker/dialog beyond the default
Object Inspector editing:

```pascal
uses DesignIntf, DesignEditors;

TFilePatternProperty = class(TStringProperty)
public
  function GetAttributes: TPropertyAttributes; override;   //[paDialog]
  procedure Edit; override;                                //dialog aç
end;

procedure Register;
begin
  RegisterPropertyEditor(TypeInfo(string), TFolderWatcher,
    'Pattern', TFilePatternProperty);
end;
```

Common base classes: `TStringProperty`, `TIntegerProperty`,
`TEnumProperty`, `TClassProperty`, `TComponentProperty`. Override
`GetValues`/`GetAttributes` (`paValueList`, `paDialog`, `paMultiSelect`)
per need.

## Component editors

Right-click/double-click behavior on the designer surface:

```pascal
TFolderWatcherEditor = class(TComponentEditor)
public
  function GetVerbCount: Integer; override;
  function GetVerb(Index: Integer): string; override;   //'Test Watch...'
  procedure ExecuteVerb(Index: Integer); override;
end;

//Register içinde:
RegisterComponentEditor(TFolderWatcher, TFolderWatcherEditor);
```

After a component editor mutates the component, call
`Designer.Modified` so the IDE marks the form dirty.

## Design-time behavior of the component itself

- Real side effects (connections, threads, timers, file watchers) are
  suppressed under `csDesigning` — the designer instance is a *picture*
  of the component, not a live one.
- A visual component should still paint something meaningful at design
  time (placeholder text/frame) so the developer can see and select it.

## Checklist — design-time review

- [ ] `DesignIntf`/`DesignEditors` referenced only from the design-time package?
- [ ] Runtime package builds standalone (Runtime only, no IDE units)?
- [ ] LIB suffix `$(Auto)`, not hardcoded?
- [ ] Register unit separate from component units, one palette category?
- [ ] `Designer.Modified` called after editor-driven mutations?
- [ ] Dotted, library-owned unit namespace throughout?
