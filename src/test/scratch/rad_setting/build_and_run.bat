@echo off
setlocal
pushd "%~dp0"
set RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
if not exist "%RSVARS%" ( echo [HATA] rsvars yok & exit /b 2 )
call "%RSVARS%" >nul

REM Platform: argumansiz = Win32.  "build_and_run.bat Win64" ikinci hedef.
set PLAT=%~1
if "%PLAT%"=="" set PLAT=Win32
set DCC=dcc32
if /I "%PLAT%"=="Win64" set DCC=dcc64

REM mORMot2 kaynak yolu
if "%MORMOT%"=="" set MORMOT=E:\system\dev\Delphi\src\git\synopse\mORMot2\src
if not exist "%MORMOT%\core\mormot.core.base.pas" (
  echo [HATA] mORMot2 kaynagi bulunamadi: %MORMOT%
  exit /b 3
)

REM DevExpress DERLENMIS DCU yolu. Kaynak klasoru DEGIL - kaynaktan derlemek
REM butun kutuphaneyi yeniden derletir.
if "%DEVEX%"=="" set DEVEX=C:\01\DevExpress\Library\RS37\%PLAT%
REM .res ve .dfm dosyalari DCU'larin yaninda DEGIL, ayri bir Resources
REM klasorunde duruyor. Bu yol verilmezse dcc "dxNavBar.res bulunamadi"
REM gibi otuzdan fazla E1026 doker.
if "%DEVEXSRC%"=="" set DEVEXSRC=C:\01\DevExpress\Library\Sources\Resources
if not exist "%DEVEX%\cxVGrid.dcu" (
  echo [HATA] DevExpress %PLAT% DCU bulunamadi: %DEVEX%
  echo         DEVEX ortam degiskeniyle dogru yolu verin.
  exit /b 4
)

if not exist "%~dp0bin\%PLAT%" mkdir "%~dp0bin\%PLAT%"
if not exist "%~dp0dcu\%PLAT%" mkdir "%~dp0dcu\%PLAT%"

set LOG=%~dp0test_log_%PLAT%.txt
%DCC% -B -Q -NSSystem;System.Win;Winapi;Vcl;Vcl.Imaging;Data;Xml;Web;Soap ^
  -U"..\..\..\core;..\..\..\share;%MORMOT%\core;%MORMOT%;%DEVEX%" ^
  -I"%MORMOT%;%MORMOT%\core" ^
  -R"..\..\..\share;%DEVEXSRC%" ^
  -E"%~dp0bin\%PLAT%" -N0"%~dp0dcu\%PLAT%" "SettingTest.dpr" > "%LOG%" 2>&1
set ERR=%ERRORLEVEL%
if %ERR% NEQ 0 ( type "%LOG%" & echo === %PLAT% DERLEME BASARISIZ === & exit /b %ERR% )

"%~dp0bin\%PLAT%\SettingTest.exe" >> "%LOG%" 2>&1
set ERR=%ERRORLEVEL%
type "%LOG%"
exit /b %ERR%
