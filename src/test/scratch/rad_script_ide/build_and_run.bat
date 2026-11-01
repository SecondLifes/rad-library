@echo off
setlocal
pushd "%~dp0"
set RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
if not exist "%RSVARS%" ( echo [HATA] rsvars yok & exit /b 2 )
call "%RSVARS%" >nul

if "%MORMOT%"=="" set MORMOT=E:\system\dev\Delphi\src\git\synopse\mORMot2\src
if "%DXRES%"=="" set DXRES=C:\01\DevExpress\Library\Sources\Resources
if "%JCL%"=="" set JCL=E:\system\dev\Delphi\component\2026.6.6\jcl\source
if "%DEXT%"=="" set DEXT=E:\system\dev\Delphi\src\git\cesarliws\dext\Sources
if "%EXTRAU%"=="" set EXTRAU=%JCL%\common;%JCL%\windows;%JCL%\vcl;%JCL%\prototypes;%DEXT%\Core;%DEXT%\Common
if "%EXTRAI%"=="" set EXTRAI=%JCL%\include;%JCL%\include\jedi
REM TMS Scripter 8.1: derlenmis d13 DCU'lari (Win32/Win64 Release) + .res dosyalari ayni klasorde.
if "%TMSSCR%"=="" set TMSSCR=C:\01\tms\scr\tms.biz.scripter\packages\d13

set PROJ=%~2
if "%PROJ%"=="" set PROJ=IdeTest
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
set DX=C:\01\DevExpress\Library\RS37\%~1
set TMS=%TMSSCR%\%~1\Release
%~2 -B -Q -NSSystem;System.Win;Winapi;Vcl;Vcl.Imaging;Data;Xml;Web;Soap ^
  -U"..\..\..\core;..\..\..\vendor\tms;..\..\..\share;..\..\..\component;%EXTRAU%;%UNI%;%DX%;%TMS%;%MORMOT%\core;%MORMOT%\crypt;%MORMOT%\db;%MORMOT%\net;%MORMOT%\orm;%MORMOT%\rest;%MORMOT%\soa;%MORMOT%\lib;%MORMOT%" ^
  -I"%MORMOT%;%MORMOT%\core;%EXTRAI%" -R"..\..\..\share;%DXRES%;%TMS%" ^
  -E"%~3" -N0"%~4" "%PROJ%.dpr" >> "%LOG%" 2>&1
if errorlevel 1 (
  echo === DERLEME BASARISIZ %~1 === >> "%LOG%"
  set RC=1
  goto :eof
)
copy /y "%~dp0*.dfm" "%~3\" >nul 2>&1
"%~3\%PROJ%.exe" >> "%LOG%" 2>&1
if errorlevel 1 set RC=1
goto :eof
