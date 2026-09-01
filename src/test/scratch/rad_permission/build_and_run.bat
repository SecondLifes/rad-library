@echo off
setlocal
pushd "%~dp0"
set RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
if not exist "%RSVARS%" ( echo [HATA] rsvars yok & exit /b 2 )
call "%RSVARS%" >nul

if "%MORMOT%"=="" set MORMOT=E:\system\dev\Delphi\src\git\synopse\mORMot2\src
if "%UNIDAC%"=="" set UNIDAC=C:\01\Devart\UniDAC13\Lib\Win32
if "%DXLIB%"=="" set DXLIB=C:\01\DevExpress\Library\RS37\Win32
if "%DXRES%"=="" set DXRES=C:\01\DevExpress\Library\Sources\Resources
if not exist "%UNIDAC%\Uni.dcu" ( echo [HATA] UniDAC bulunamadi: %UNIDAC% & exit /b 4 )

if not exist "%~dp0bin" mkdir "%~dp0bin"
if not exist "%~dp0dcu" mkdir "%~dp0dcu"

set LOG=%~dp0test_log.txt
dcc32 -B -Q -NSSystem;System.Win;Winapi;Vcl;Data;Xml;Web;Soap ^
  -U"..\..\..\core;..\..\..\share;..\..\..\component;%UNIDAC%;%DXLIB%;%MORMOT%\core;%MORMOT%\crypt;%MORMOT%" ^
  -I"%MORMOT%;%MORMOT%\core" -R"%DXRES%" ^
  -E"%~dp0bin" -N0"%~dp0dcu" "PermissionTest.dpr" > "%LOG%" 2>&1
set ERR=%ERRORLEVEL%
if %ERR% NEQ 0 ( type "%LOG%" & echo === DERLEME BASARISIZ === & exit /b %ERR% )

"%~dp0bin\PermissionTest.exe" >> "%LOG%" 2>&1
set ERR=%ERRORLEVEL%
type "%LOG%"
exit /b %ERR%