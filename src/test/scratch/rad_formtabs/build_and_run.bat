@echo off
setlocal
pushd "%~dp0"
set RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
if not exist "%RSVARS%" ( echo [HATA] rsvars yok & exit /b 2 )
call "%RSVARS%" >nul

if "%MORMOT%"=="" set MORMOT=E:\system\dev\Delphi\src\git\synopse\mORMot2\src
if "%DXLIB%"=="" set DXLIB=C:\01\DevExpress\Library\RS37\Win32
if "%DXLIB64%"=="" set DXLIB64=C:\01\DevExpress\Library\RS37\Win64
if "%DXRES%"=="" set DXRES=C:\01\DevExpress\Library\Sources\Resources
if "%TMSLIB%"=="" set TMSLIB=C:\01\tms\.tmssetup\lib\dcus\d13\win32intel\Release
if "%TMSLIB64%"=="" set TMSLIB64=C:\01\tms\.tmssetup\lib\dcus\d13\win64intel\Release
if not exist "%TMSLIB%\AdvOfficeTabSet.dcu" ( echo [HATA] TMS DCU bulunamadi: %TMSLIB% & exit /b 4 )
if not exist "%TMSLIB64%\AdvOfficeTabSet.dcu" ( echo [HATA] TMS Win64 DCU bulunamadi: %TMSLIB64% & exit /b 4 )
if not exist "%DXLIB%\cxGeometry.dcu" ( echo [HATA] DevExpress bulunamadi: %DXLIB% & exit /b 4 )
if not exist "%DXLIB64%\cxGeometry.dcu" ( echo [HATA] DevExpress Win64 bulunamadi: %DXLIB64% & exit /b 4 )

set LOG=%~dp0test_log.txt
if exist "%LOG%" del "%LOG%"
set RC=0
call :run Win32 dcc32 "%DXLIB%" "%TMSLIB%" "%~dp0bin" "%~dp0dcu"
call :run Win64 dcc64 "%DXLIB64%" "%TMSLIB64%" "%~dp0bin64" "%~dp0dcu64"
type "%LOG%"
exit /b %RC%

:run
echo ===== %~1 ===== >> "%LOG%"
if not exist "%~5" mkdir "%~5"
if not exist "%~6" mkdir "%~6"
%~2 -B -Q -NSSystem;System.Win;Winapi;Vcl;Data;Xml;Web;Soap ^
  -U"..\..\..\core;..\..\..\component;%~3;%~4;%MORMOT%\core;%MORMOT%\crypt;%MORMOT%" ^
  -I"%MORMOT%;%MORMOT%\core" -R"%DXRES%" ^
  -E"%~5" -N0"%~6" "FormTabsTest.dpr" >> "%LOG%" 2>&1
if errorlevel 1 (
  echo === DERLEME BASARISIZ %~1 === >> "%LOG%"
  set RC=1
  goto :eof
)
"%~5\FormTabsTest.exe" >> "%LOG%" 2>&1
if errorlevel 1 set RC=1
goto :eof
