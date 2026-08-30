@echo off
REM Bu klasordeki butun sondalari derler ve calistirir.
REM   build_and_run.bat              -> Win32, hepsi
REM   build_and_run.bat Win64        -> Win64, hepsi
REM   build_and_run.bat Win32 XTest  -> yalnizca XTest.dpr
REM
REM ! KENDI DIZININDEN derlenir (pushd). dcc32, .dpr icindeki in '...' yollarini
REM   CALISMA DIZININE gore cozuyor; depo kokunden derlemek sahte
REM   "dosya bulunamadi" verir.
setlocal
pushd "%~dp0"
set RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
if not exist "%RSVARS%" ( echo [HATA] rsvars yok & exit /b 2 )
call "%RSVARS%" >nul

set PLAT=%~1
if "%PLAT%"=="" set PLAT=Win32
set DCC=dcc32
if /I "%PLAT%"=="Win64" set DCC=dcc64

if "%MORMOT%"=="" set MORMOT=E:\system\dev\Delphi\src\git\synopse\mORMot2\src
if not exist "%MORMOT%\core\mormot.core.base.pas" (
  echo [HATA] mORMot2 kaynagi bulunamadi: %MORMOT%
  exit /b 3
)
REM EXTRAU: ek birim yolu. rad.pas su an JclBase/JclSysInfo (JEDI JCL) ve
REM Dext.Types.UUID kullaniyor; ikisi de bu depoda YOK. Kurulu olduklari
REM klasorleri noktali virgulle ayirip buraya verin, ornegin:
REM   set EXTRAU=C:\jcl\lib\Win32;C:\dext\src
REM ! JCL derlenmis DCU klasoru kullaniyorsaniz, o klasorde ESKI BIR RTL
REM   (SysUtils.dcu vb.) OLMAMALI - varsa gercek RTL-i golgeler ve
REM   "F2063 Could not compile used unit SysUtils" verir.
if "%UNIDAC%"=="" set UNIDAC=C:\01\Devart\UniDAC13\Lib\%PLAT%
if not exist "%UNIDAC%\Uni.dcu" ( echo [HATA] UniDAC bulunamadi: %UNIDAC% & exit /b 4 )

REM DevExpress DERLENMIS DCU yolu - kaynak klasoru DEGIL.
if "%DXLIB%"=="" set DXLIB=C:\01\DevExpress\Library\RS37\%PLAT%
REM .res/.dfm dosyalari DCU'larin yaninda DEGIL, ayri bir Resources klasorunde.
REM Bu yol verilmezse dcc "dxNavBar.res bulunamadi" gibi 30+ E1026 doker.
if "%DXRES%"=="" set DXRES=C:\01\DevExpress\Library\Sources\Resources
if not exist "%DXLIB%\cxEdit.dcu" (
  echo [HATA] DevExpress %PLAT% DCU bulunamadi: %DXLIB%
  exit /b 5
)

if not exist "%~dp0bin\%PLAT%" mkdir "%~dp0bin\%PLAT%"
if not exist "%~dp0dcu\%PLAT%" mkdir "%~dp0dcu\%PLAT%"

set ONLY=%~2
set FAILED=0
for %%F in (*.dpr) do (
  if "%ONLY%"=="" ( call :one "%%~nF" ) else ( if /I "%%~nF"=="%ONLY%" call :one "%%~nF" )
)
if %FAILED% NEQ 0 ( echo === %PLAT%: %FAILED% SONDA BASARISIZ === & exit /b 1 )
echo === %PLAT%: hepsi tamam ===
exit /b 0

:one
set NAME=%~1
set LOG=%~dp0test_log_%NAME%_%PLAT%.txt
echo --- %NAME% [%PLAT%]
%DCC% -B -Q -NSSystem;System.Win;Winapi;Vcl;Vcl.Imaging;Data;Xml;Web;Soap ^
  -U"..\..\..\core;..\..\..\share;..\..\..\component;%EXTRAU%;%UNIDAC%;%DXLIB%;%MORMOT%\core;%MORMOT%\crypt;%MORMOT%\db;%MORMOT%\net;%MORMOT%\orm;%MORMOT%\rest;%MORMOT%\soa;%MORMOT%\lib;%MORMOT%" ^
  -I"%MORMOT%;%MORMOT%\core" -R"..\..\..\share;%DXRES%" ^
  -E"%~dp0bin\%PLAT%" -N0"%~dp0dcu\%PLAT%" "%NAME%.dpr" > "%LOG%" 2>&1
if ERRORLEVEL 1 (
  type "%LOG%"
  echo [DERLEME BASARISIZ] %NAME% %PLAT%
  set /a FAILED+=1
  exit /b 0
)
"%~dp0bin\%PLAT%\%NAME%.exe" >> "%LOG%" 2>&1
if ERRORLEVEL 1 (
  type "%LOG%"
  echo [CALISMA BASARISIZ] %NAME% %PLAT%
  set /a FAILED+=1
  exit /b 0
)
type "%LOG%"
exit /b 0
