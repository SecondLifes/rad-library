@echo off
REM rad.desktop - derle + calistir. 1. arguman: Win32 / Win64 / bos (ikisi). 2. arguman: proje (varsayilan RunDesktopTests).
REM 3. arguman: "norun" verilirse yalniz derler.
setlocal
pushd "%~dp0"
set RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
if not exist "%RSVARS%" ( echo [HATA] rsvars yok & exit /b 2 )
call "%RSVARS%" >nul

if "%MORMOT%"=="" set MORMOT=E:\system\dev\Delphi\src\git\synopse\mORMot2\src
if "%DUNITX%"=="" set DUNITX=E:\system\dev\Delphi\src\git\VSoftTechnologies\DUnitX\Source
set PROJ=%~2
if "%PROJ%"=="" set PROJ=RunDesktopTests
set RUN=%~3
set LOG=%~dp0%PROJ%_log.txt
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
set DX=C:\01\DevExpress\Library\RS37\%~1
set DXRES=C:\01\DevExpress\Library\Sources\Resources
set TMSSCR=C:\01\tms\scr\tms.biz.scripter\packages\d13\%~1\Release
%~2 -B -Q -NSSystem;System.Win;Winapi;Vcl;Vcl.Imaging;Data;Xml ^
  -U"%DUNITX%;..\..\..\core;..\..\..\component;..\..\..\vendor\tms;..\..\..\vendor\unidac;..\..\unit;%UNI%;%DX%;%TMSSCR%;%MORMOT%\core;%MORMOT%\crypt;%MORMOT%\ui;%MORMOT%\lib;%MORMOT%\net;%MORMOT%\db;%MORMOT%\orm;%MORMOT%\rest;%MORMOT%\soa;%MORMOT%\app;%MORMOT%" ^
  -I"%MORMOT%;%MORMOT%\core" -R"%DXRES%;%TMSSCR%" ^
  -E"%~3" -N0"%~4" "%PROJ%.dpr" >> "%LOG%" 2>&1
if errorlevel 1 (
  echo === DERLEME BASARISIZ %~1 === >> "%LOG%"
  set RC=1
  goto :eof
)
if /i "%RUN%"=="norun" goto :eof
"%~3\%PROJ%.exe" --exitbehavior:Continue >> "%LOG%" 2>&1
if errorlevel 1 set RC=1
goto :eof
