@echo off
setlocal
pushd "%~dp0"
set RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
if not exist "%RSVARS%" ( echo [HATA] rsvars yok & exit /b 2 )
call "%RSVARS%" >nul

REM mORMot2 kaynak yolu
if "%MORMOT%"=="" set MORMOT=E:\system\dev\Delphi\src\git\synopse\mORMot2\src
if not exist "%MORMOT%\core\mormot.core.base.pas" (
  echo [HATA] mORMot2 kaynagi bulunamadi: %MORMOT%
  exit /b 3
)

REM Help.vcl.pas DevExpress'e bagli (cxGeometry, cxControls).
REM DCU'lar Library\RS37\Win32 ve Win64'te, .res kaynaklari Sources altinda.
if "%DXLIB%"=="" set DXLIB=C:\01\DevExpress\Library\RS37\Win32
if "%DXLIB64%"=="" set DXLIB64=C:\01\DevExpress\Library\RS37\Win64
if "%DXRES%"=="" set DXRES=C:\01\DevExpress\Library\Sources\Resources
if not exist "%DXLIB%\cxGeometry.dcu" (
  echo [HATA] DevExpress kutuphanesi bulunamadi: %DXLIB%
  echo         DXLIB / DXRES ortam degiskenleriyle dogru yolu verin.
  exit /b 4
)
if not exist "%DXLIB64%\cxGeometry.dcu" (
  echo [HATA] DevExpress Win64 kutuphanesi bulunamadi: %DXLIB64%
  exit /b 4
)

set LOG=%~dp0test_log.txt
if exist "%LOG%" del "%LOG%"
set RC=0
call :run Win32 dcc32 "%DXLIB%" "%~dp0bin" "%~dp0dcu"
call :run Win64 dcc64 "%DXLIB64%" "%~dp0bin64" "%~dp0dcu64"
type "%LOG%"
exit /b %RC%

:run
echo ===== %~1 ===== >> "%LOG%"
if not exist "%~4" mkdir "%~4"
if not exist "%~5" mkdir "%~5"
%~2 -B -Q -NSSystem;System.Win;Winapi;Vcl;Data;Xml;Web;Soap ^
  -U"..\..\..\core;..\..\..\share;..\..\..\component;%~3;%MORMOT%\core;%MORMOT%\crypt;%MORMOT%" ^
  -I"%MORMOT%;%MORMOT%\core" -R"%DXRES%" ^
  -E"%~4" -N0"%~5" "CoreFormTest.dpr" >> "%LOG%" 2>&1
if errorlevel 1 (
  echo === DERLEME BASARISIZ %~1 === >> "%LOG%"
  set RC=1
  goto :eof
)
"%~4\CoreFormTest.exe" >> "%LOG%" 2>&1
if errorlevel 1 set RC=1
goto :eof
