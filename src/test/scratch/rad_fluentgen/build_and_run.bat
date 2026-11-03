@echo off
setlocal EnableDelayedExpansion
pushd "%~dp0"
set RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
if not exist "%RSVARS%" ( echo [HATA] rsvars yok & exit /b 2 )
call "%RSVARS%" >nul

if "%MORMOT%"=="" set MORMOT=E:\system\dev\Delphi\src\git\synopse\mORMot2\src

set PROJ=FluentGenTest
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
%~2 -B -Q %NS% -U"%UNITS%" -I"%MORMOT%;%MORMOT%\core" -R"%MORMOT%;..\..\..\packages" -E"%~3" -N0"%~4" "%PROJ%.dpr" >> "%LOG%" 2>&1
if errorlevel 1 (
  echo === DERLEME BASARISIZ %~1 === >> "%LOG%"
  set RC=1
  goto :eof
)
"%~3\%PROJ%.exe" >> "%LOG%" 2>&1
if errorlevel 1 set RC=1

REM Uretilen her birim derlenmeli. Derlenemeyen birim adi ve ilk hatasi loga yazilir.
set /a TOPLAM=0
set /a KOTU=0
for %%F in ("%~3\gen\*.pas") do (
  set /a TOPLAM+=1
  %~2 -Q %NS% -U"%~4" -N0"%~4" "%%F" > "%~3\gen\derleme.txt" 2>&1
  if errorlevel 1 (
    set /a KOTU+=1
    set RC=1
    echo [HATA] derlenmedi: %%~nxF >> "%LOG%"
    findstr /C:" Error: " /C:" Fatal: " "%~3\gen\derleme.txt" | findstr /N "^" | findstr /B "1: 2:" >> "%LOG%"
  )
)
echo Uretilen birim: !TOPLAM! toplam, !KOTU! derlenmedi >> "%LOG%"
goto :eof
