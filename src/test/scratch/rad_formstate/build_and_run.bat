@echo off
REM rad.formstate - derle + testleri kos. Arguman yok: Win32 ve Win64; "Win32" veya "Win64": yalniz o.
setlocal
pushd "%~dp0"
set RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
if not exist "%RSVARS%" ( echo [HATA] rsvars yok & exit /b 2 )
call "%RSVARS%" >nul

if "%MORMOT%"=="" set MORMOT=E:\system\dev\Delphi\src\git\synopse\mORMot2\src
REM Delphi ships DUnitX DCUs for Win32 only; the git sources build both platforms.
if "%DUNITX%"=="" set DUNITX=E:\system\dev\Delphi\src\git\VSoftTechnologies\DUnitX\Source
set PROJ=%~2
if "%PROJ%"=="" set PROJ=RunFormStateTests
set LOG=%~dp0test_log.txt
if exist "%LOG%" del "%LOG%"
set RC=0
if "%~1"=="" (
  call :run Win32 dcc32 "%~dp0bin" "%~dp0dcu"
  call :run Win64 dcc64 "%~dp0bin64" "%~dp0dcu64"
) else if /i "%~1"=="Win64" (
  call :run Win64 dcc64 "%~dp0bin64" "%~dp0dcu64"
) else (
  call :run Win32 dcc32 "%~dp0bin" "%~dp0dcu"
)
type "%LOG%"
exit /b %RC%

:run
echo ===== %~1 %PROJ% ===== >> "%LOG%"
if not exist "%~3" mkdir "%~3"
if not exist "%~4" mkdir "%~4"
set UNI=C:\01\UniDAC\13\Lib\%~1
%~2 -B -Q -NSSystem;System.Win;Winapi;Vcl;Data;Xml ^
  -U"%DUNITX%;..\..\..\core;..\..\..\vendor\unidac;..\..\unit;%UNI%;%MORMOT%\core;%MORMOT%\crypt;%MORMOT%" ^
  -I"%MORMOT%;%MORMOT%\core" ^
  -E"%~3" -N0"%~4" "%PROJ%.dpr" >> "%LOG%" 2>&1
if errorlevel 1 (
  echo === DERLEME BASARISIZ %~1 === >> "%LOG%"
  set RC=1
  goto :eof
)
"%~3\%PROJ%.exe" --exitbehavior:Continue >> "%LOG%" 2>&1
if errorlevel 1 set RC=1
goto :eof
