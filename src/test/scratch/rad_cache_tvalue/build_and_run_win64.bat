@echo off
setlocal
pushd "%~dp0"

set RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
call "%RSVARS%" >nul
set DUNITX=%BDS%\source\DUnitX
set MORMOT=E:\system\dev\Delphi\src\git\synopse\mORMot2\src

if not exist "%~dp0bin64" mkdir "%~dp0bin64"
if not exist "%~dp0dcu64" mkdir "%~dp0dcu64"

dcc64 -B -Q -NSSystem;System.Win;Winapi;Vcl -U"%DUNITX%;..\..\..\core;..\..\unit;%MORMOT%;%MORMOT%\core" -I"%MORMOT%;%MORMOT%\core" -E"%~dp0bin64" -N0"%~dp0dcu64" "RunCacheTests.dpr"
if errorlevel 1 exit /b %errorlevel%

"%~dp0bin64\RunCacheTests.exe" --exitbehavior:Continue
exit /b %errorlevel%
