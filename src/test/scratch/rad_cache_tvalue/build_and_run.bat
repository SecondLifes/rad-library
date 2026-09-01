@echo off
REM rad.cache TValue gecisi - derle + testleri kos (log dosyasina yonlendirilmis)
setlocal
pushd "%~dp0"

set RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
if not exist "%RSVARS%" (
  echo [HATA] rsvars.bat bulunamadi: "%RSVARS%"
  exit /b 2
)
call "%RSVARS%" >nul

set LOG=%~dp0build_log.txt
set DUNITX=%BDS%\source\DUnitX
set MORMOT=E:\system\dev\Delphi\src\git\synopse\mORMot2\src

dcc32 -B -Q -NSSystem;System.Win;Winapi;Vcl -U"%DUNITX%;..\..\..\core;..\..\unit;%MORMOT%;%MORMOT%\core" -I"%MORMOT%;%MORMOT%\core" -E"%~dp0bin" -N0"%~dp0dcu" "RunCacheTests.dpr" > "%LOG%" 2>&1
set ERR=%ERRORLEVEL%
type "%LOG%"
if %ERR% NEQ 0 (
  echo === DERLEME BASARISIZ ^| kod %ERR% ===
  exit /b %ERR%
)

echo === DERLEME OK - testler kosuyor ===
"%~dp0bin\RunCacheTests.exe" --exitbehavior:Continue >> "%LOG%" 2>&1
set ERR=%ERRORLEVEL%
type "%LOG%"
exit /b %ERR%
