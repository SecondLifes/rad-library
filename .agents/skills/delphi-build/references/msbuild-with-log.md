# Build via .bat with log redirection

## The problem

Capturing a Delphi compile's stdout directly from an AI tool's shell on
Windows is fragile: the child `cmd.exe` doesn't reliably inherit the cwd,
`2>&1` at the outer shell doesn't always capture everything MSBuild/dcc32
emit, and mixed encodings (compiler CP1252 vs shell UTF-8) garble output.

## The solution

The `.bat` itself redirects **all** output to a log file; the agent just
runs the `.bat` and then `Read`s the log. Works from any shell, any
encoding, no race conditions.

### `build.bat` template

```bat
@echo off
REM build.bat — projeyi MSBuild ile derler; tüm çıktı log dosyasına gider
setlocal

set CONFIG=%1
if "%CONFIG%"=="" set CONFIG=Debug

set PLAT=%2
if "%PLAT%"=="" set PLAT=Win32

REM Studio klasörünü KEŞFET — sürüm numarasını asla varsayma:
REM   dir "C:\Program Files (x86)\Embarcadero\Studio" /b /ad
REM Birden fazla sürüm varsa geliştiriciye sor. Community Edition farklı
REM bir yola kurulmuş olabilir.
set RSVARS=C:\Program Files (x86)\Embarcadero\Studio\<SURUM>\bin\rsvars.bat
if not exist "%RSVARS%" (
  echo [build.bat] HATA: rsvars.bat bulunamadi: "%RSVARS%"
  exit /b 2
)

call "%RSVARS%"
if %ERRORLEVEL% NEQ 0 (
  echo [build.bat] HATA: rsvars.bat basarisiz
  exit /b 1
)

set LOG=%~dp0build_log.txt

msbuild "%~dp0MyLib.dproj" /t:Build /p:Config=%CONFIG% /p:Platform=%PLAT% /nologo /v:minimal /clp:NoSummary > "%LOG%" 2>&1
set ERR=%ERRORLEVEL%

type "%LOG%"

if %ERR% EQU 0 (
  echo === BUILD OK ===
) else (
  echo === BUILD FAILED ^| kod %ERR% ^| build_log.txt'ye bak ===
)
exit /b %ERR%
```

### Key points

| Point | Why |
|---|---|
| `%~dp0` | Resolves the `.bat`'s own directory (trailing backslash included) — callable from anywhere. |
| `> "%LOG%" 2>&1` | Captures stdout **and** stderr into the file. |
| `set ERR=%ERRORLEVEL%` **immediately** after msbuild | ⚠️ **The exit-code trap:** `%ERRORLEVEL%` reflects the *last* command. If the `.bat` runs `type "%LOG%"` and then `exit /b %ERRORLEVEL%`, it returns the `type`'s code (almost always 0) and masks the MSBuild failure. Capture first, `type` after, exit with the captured value. |
| `/v:minimal /clp:NoSummary /nologo` | Cuts MSBuild noise without losing errors. |
| Verify via log content | Grep the log for `error E`, `error F`, `Fatal` — never trust exit code alone. |

### Two-package library build order

```bat
REM Önce runtime, sonra design-time (design-time paketi runtime'ı requires eder)
msbuild "%~dp0packages\MyLibR.dproj" /t:Build /p:Config=%CONFIG% /p:Platform=Win32 > "%LOG%" 2>&1
set ERR=%ERRORLEVEL%
if %ERR% NEQ 0 goto :fail
msbuild "%~dp0packages\MyLibD.dproj" /t:Build /p:Config=%CONFIG% /p:Platform=Win32 >> "%LOG%" 2>&1
set ERR=%ERRORLEVEL%
```

### DUnitX test run variant

```bat
@echo off
call "<RSVARS_YOLU>"
set LOG=%~dp0test_log.txt

msbuild "%~dp0tests\MyLib.Tests.dproj" /t:Build /p:Config=Debug /p:Platform=Win32 > "%LOG%" 2>&1
set ERR=%ERRORLEVEL%
if %ERR% NEQ 0 ( type "%LOG%" & exit /b %ERR% )

REM DİKKAT: DUnitX "--exit" tek başına kabul etmez — anahtar:değer ister.
REM Doğru anahtar "exitbehavior"; değerler: Continue (default) | Pause.
"%~dp0tests\Win32\Debug\MyLib.Tests.exe" --exitbehavior:Continue >> "%LOG%" 2>&1
set ERR=%ERRORLEVEL%
type "%LOG%"
exit /b %ERR%
```

> Running with a bare `--exit` fails with:
> `ECommandLineError: Option [exit] expected a following :value but none was found`

### Invoking from the agent's shell

```bash
# Bash (Git Bash / MSYS)
cmd.exe /c '"<absolute-path>\build.bat" 2>&1'
```

```powershell
# PowerShell
& cmd.exe /c '"<absolute-path>\build.bat" 2>&1'
```

Variants that FAIL in these environments: `Set-Location <dir>; cmd.exe /c
"build.bat"` (child cmd doesn't see the cwd) and `cmd.exe /c 'cd /d <dir>
&& build.bat'` with spaces/special chars in the path. Absolute quoted path
is the invariant that always works.

## Identifier → missing unit table (E2003-class errors)

Most `Undeclared identifier` errors are a missing `uses` entry:

| Missing identifier | Unit to add |
|---|---|
| `TColor`, `TBitmap`, `TFont`, `TCanvas` | `Vcl.Graphics` |
| `TList<>`, `TObjectList<>`, `TDictionary<>` | `System.Generics.Collections` |
| `Format`, `IntToStr`, `Trim`, `FreeAndNil` | `System.SysUtils` |
| `TDateTime` helpers, `IncDay`, `DaysBetween` | `System.DateUtils` |
| `TStringList`, `TStringStream`, `TComponent` | `System.Classes` |
| `RGB`, `MessageBox`, `LoadCursor` | `Winapi.Windows` |
| `TStopwatch` | `System.Diagnostics` |
| `TTask`, `TParallel`, `IFuture` | `System.Threading` |

## When to ask the developer before generating the `.bat`

- Two or more `Studio\<N>.0\` folders installed (multiple Delphi versions) —
  list them and ask which one.
- The project targets a non-Win32 platform — machine-specific SDK/PA Server
  setup; don't guess.
- The `.dproj` defines build configurations beyond `Debug`/`Release`.

> Kaynak: bu referans, `adrianosantostreina/delphi-dev` (MIT) bilgi
> tabanındaki build kataloğundan bu kitin kütüphane/paket hedefine
> uyarlanmıştır — bkz. ACKNOWLEDGMENTS.
