# MSB6002 / MSB6003 — "command line too long" fixes

## Symptom

```
warning MSB6002: The command-line for the "DCC" task is too long.
error MSB6003: The specified task executable "dcc32.exe" could not be run.
The filename or extension is too long
```

Compiles fine in the IDE, fails on the command line — typically on
machines with **many globally installed component libraries** (TMS,
DevExpress, ACBr, ...) that inflate `DCC_UsePackage`/`DCC_UnitSearchPath`.
Windows' `CreateProcess` limit is ~32,000 characters; a fat compiler
command line easily exceeds it.

## Preferred fix — compiler response file

Add to the `.dproj`, in a base `PropertyGroup` (no platform condition):

```xml
<DCC_ForceExecute>true</DCC_ForceExecute>
```

MSBuild then writes a response file (`<Project>.cmds`) and passes only
`@Project.cmds` to dcc — the length limit disappears. Least invasive
option: no paths removed, no project restructuring.

## Fallback — direct dcc32/dcc64 with a `.cfg`

Call the compiler directly with a `.cfg` file named after the project
(the compiler reads `MyLib.cfg` automatically when it sits next to the
project and the cwd is the project folder):

```ini
; .cfg — yorumlar ; ile başlar
-DDEBUG                 ; conditional define
-NSWinapi;System        ; namespace prefix'leri (-NS, boşluksuz)
-E".\bin"               ; EXE/BPL çıktı klasörü
-N0".\dcu"              ; DCU çıktı klasörü
-U"libs\somelib\src"    ; arama yolu (klasör başına tekrarlanır)
-I"libs\includes"       ; .inc dosyaları için include yolu
```

```bat
call "<RSVARS_YOLU>"
cd /d "%PROJ_DIR%"   & REM ZORUNLU: dcc32 .cfg içindeki göreli yolları cwd'ye göre çözer
dcc32.exe "MyLib.dpr" >> "%LOG%" 2>&1
```

## Other mitigations (if it still overflows)

- Trim `DCC_UnitSearchPath`: remove paths of libraries this project
  doesn't actually use.
- Point at a single folder of pre-compiled `.dcu`s instead of many source
  trees.
- Map the library root to a drive letter (`subst X: C:\very\long\root`)
  to shorten every path at once.

> Kaynak: `adrianosantostreina/delphi-dev` (MIT) bilgi tabanından
> uyarlanmıştır — bkz. ACKNOWLEDGMENTS.
