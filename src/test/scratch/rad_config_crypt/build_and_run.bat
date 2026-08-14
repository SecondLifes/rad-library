@echo off
setlocal
pushd "%~dp0"
set RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
if not exist "%RSVARS%" ( echo [HATA] rsvars yok & exit /b 2 )
call "%RSVARS%" >nul

REM mORMot2 kaynak yolu — bu makinede kurulu konum.
REM Baska bir makinede farkliysa MORMOT ortam degiskeniyle gecersiz kil:
REM   set MORMOT=D:\yol\mORMot2\src  &&  build_and_run.bat
if "%MORMOT%"=="" set MORMOT=E:\system\dev\Delphi\src\git\synopse\mORMot2\src
if not exist "%MORMOT%\core\mormot.core.base.pas" (
  echo [HATA] mORMot2 kaynagi bulunamadi: %MORMOT%
  echo         MORMOT ortam degiskeniyle dogru yolu verin.
  exit /b 3
)

REM dcc32 cikti klasorlerini kendisi olusturmaz (F2039)
if not exist "%~dp0bin" mkdir "%~dp0bin"
if not exist "%~dp0dcu" mkdir "%~dp0dcu"

set LOG=%~dp0test_log.txt
dcc32 -B -Q -NSSystem;System.Win;Winapi;Vcl;Data;Xml;Web;Soap ^
  -U"..\..\..\core;%MORMOT%\core;%MORMOT%\crypt;%MORMOT%" -I"%MORMOT%;%MORMOT%\core" ^
  -E"%~dp0bin" -N0"%~dp0dcu" "ConfigCryptTest.dpr" > "%LOG%" 2>&1
set ERR=%ERRORLEVEL%
if %ERR% NEQ 0 ( type "%LOG%" & echo === DERLEME BASARISIZ === & exit /b %ERR% )

"%~dp0bin\ConfigCryptTest.exe" >> "%LOG%" 2>&1
set ERR=%ERRORLEVEL%
type "%LOG%"
exit /b %ERR%
