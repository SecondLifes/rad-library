# Embedded resources (RCDATA / .dres) in libraries and components

Embedding arbitrary binary files (SVG/PNG assets, JSON templates, SQL
scripts) into the compiled module and reading them at runtime via
`TResourceStream`. Applies to VCL apps, packages and DLLs alike.

## The canonical way: the Resources and Images dialog

Delphi's native dialog manages project resources and **generates the
`.dres` automatically** at build time — no hand-written `.rc`, no manual
`brcc32`/`cgrc` calls, no `.dproj` surgery.

1. **Project → Resources and Images...**
2. **Add...** → select the physical file (e.g. `assets\icons\save.svg`)
3. In **Properties** set:
   - **Resource identifier** — the name used from code (e.g. `icon_save`)
   - **Resource type** — type **`RCDATA`** (no underscore!)
4. **OK** — entries are stored inside the `.dproj`:

```xml
<ItemGroup>
    <Resource Include="assets\icons\save.svg">
        <ResourceType>RCDATA</ResourceType>
        <ResourceId>icon_save</ResourceId>
    </Resource>
</ItemGroup>
```

5. In the `.dpr`/`.dpk` add the directive: `{$R *.dres}` (the `*` expands
   to the project name). It coexists with the classic `{$R *.res}`
   (icon/version info) — keep both, they serve different purposes.

**Never edit the `.dres` by hand** — it's a binary artifact, regenerated
every build.

## Reading at runtime

```pascal
uses
  System.Classes, System.SysUtils, Winapi.Windows;

function LoadResourceAsString(const AResName: string): string;
var
  LResStream: TResourceStream;
  LStringStream: TStringStream;
begin
  LResStream := TResourceStream.Create(HInstance, AResName, RT_RCDATA);
  try
    LStringStream := TStringStream.Create('', TEncoding.UTF8);
    try
      LStringStream.CopyFrom(LResStream, 0);
      Result := LStringStream.DataString;
    finally
      LStringStream.Free;
    end;
  finally
    LResStream.Free;
  end;
end;
```

Second parameter = the **identifier** (`'icon_save'`), third = the
**type** (`RT_RCDATA` from `Winapi.Windows`, matching the dialog's
`RCDATA`).

**Library/package note:** `HInstance` is per-module — inside a runtime
package (BPL) or DLL it refers to *that module*, so a component reading
its own embedded assets with `HInstance` finds the package's resources,
not the host EXE's. If the lookup must target the module that defines a
specific class, use `FindClassHInstance(TMyComponent)` instead.

## Do NOT hand-write `.rc` files

You *can* add a manual `.rc` via Project → Add to Project, but the output
name (`X.dres` vs `<Project>.dres`) is unpredictable across IDE versions
and breaks `{$R *.dres}` with `E1026`. Always use the dialog. A stray old
`.rc` in an existing project is usually legacy documentation — the real
resource list lives in the `.dproj`'s `<Resource>` items.

## Common errors

| Error | Cause → Fix |
|---|---|
| `E1026 File not found: 'MyLib.dres'` | `{$R *.dres}` present but no resource registered in the dialog → register at least one, or remove the directive |
| `E2606 Duplicate resource: type RCDATA ID <name>` | `{$R *.dres}` declared twice in the same `.dpr`/`.dpk` (keep exactly one), or the same resource registered both via dialog and via a manual `.rc` (drop the `.rc`) |
| `Resource <id> not found` at runtime | Type entered as `RC_DATA` instead of `RCDATA` in the dialog; identifier typo; or running a stale binary — do a full **Build** |
| Dialog pre-fills `RC_DATA` | Some IDE versions default the field with an underscore — delete it and type `RCDATA`; only that matches `RT_RCDATA` |

> Kaynak: `adrianosantostreina/delphi-dev` (MIT) bilgi tabanından
> uyarlanmıştır (FMX/mobil bölümleri çıkarıldı, paket/HInstance notu
> eklendi) — bkz. ACKNOWLEDGMENTS.
