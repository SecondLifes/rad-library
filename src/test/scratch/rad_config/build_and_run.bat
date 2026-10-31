@echo off
setlocal
pushd "%~dp0"
set RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
if not exist "%RSVARS%" ( echo [HATA] rsvars yok & exit /b 2 )
call "%RSVARS%" >nul

if "%MORMOT%"=="" set MORMOT=E:\system\dev\Delphi\src\git\synopse\mORMot2\src

set LOG=%~dp0test_log.txt
if exist "%LOG%" del "%LOG%"
set RC=0
call :run Win32 dcc32 "%~dp0bin" "%~dp0dcu"
call :run Win64 dcc64 "%~dp0bin64" "%~dp0dcu64"
type "%LOG%"
exit /b %RC%

:run
echo ===== %~1 ===== >> "%LOG%"
if not exist "%~3" mkdir "%~3"
if not exist "%~4" mkdir "%~4"
%~2 -B -Q -NSSystem;System.Win;Winapi;Vcl;Data;Xml;Web;Soap ^
  -U"..\..\..\core;%MORMOT%\core;%MORMOT%\crypt;%MORMOT%" ^
  -I"%MORMOT%;%MORMOT%\core" ^
  -E"%~3" -N0"%~4" "ConfigTest.dpr" >> "%LOG%" 2>&1
if errorlevel 1 (
  echo === DERLEME BASARISIZ %~1 === >> "%LOG%"
  set RC=1
  goto :eof
)
"%~3\ConfigTest.exe" >> "%LOG%" 2>&1
if errorlevel 1 set RC=1
goto :eof
