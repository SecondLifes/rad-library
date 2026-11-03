@echo off
setlocal
pushd "%~dp0"
set RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
if not exist "%RSVARS%" ( echo [HATA] rsvars yok & exit /b 2 )
call "%RSVARS%" >nul

if "%MORMOT%"=="" set MORMOT=E:\system\dev\Delphi\src\git\synopse\mORMot2\src

set PROJ=RadMenuToolsTest
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
set NS=-NSSystem;System.Win;Winapi;Vcl;Vcl.Imaging;Data;Xml;Web;Soap
set UNITS=..\..\..\core;..\..\..\packages;%MORMOT%\core;%MORMOT%\crypt;%MORMOT%\lib;%MORMOT%\ui;%MORMOT%
%~2 -B -Q -GD %NS% -U"%UNITS%" -I"%MORMOT%;%MORMOT%\core" -R"%MORMOT%" -E"%~3" -N0"%~4" "%PROJ%.dpr" >> "%LOG%" 2>&1
if errorlevel 1 (
  echo === DERLEME BASARISIZ %~1 === >> "%LOG%"
  set RC=1
  goto :eof
)
"%~3\%PROJ%.exe" >> "%LOG%" 2>&1
if errorlevel 1 set RC=1

REM Uretilen birim gercekten derlenmeli: "derlenmeye hazir" iddiasinin kaniti.
echo --- uretilen birim derleniyor >> "%LOG%"
%~2 -B -Q %NS% -N0"%~4" "%~3\gen\RadMenuProbe.Fluent.pas" >> "%LOG%" 2>&1
if errorlevel 1 (
  echo === URETILEN BIRIM DERLENMEDI %~1 === >> "%LOG%"
  set RC=1
)

REM Runtime sizinti kontrolu: IDE birimleri map dosyasinda gorunmemeli.
findstr /I /C:"DesignIntf" /C:"DesignEditors" /C:"ToolsAPI" "%~3\%PROJ%.map" >nul
if errorlevel 1 (
  echo [OK]   IDE birimi baglanmadi >> "%LOG%"
) else (
  echo [HATA] IDE birimi map dosyasinda >> "%LOG%"
  set RC=1
)
goto :eof
