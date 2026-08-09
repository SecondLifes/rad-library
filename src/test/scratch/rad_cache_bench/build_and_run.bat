@echo off
setlocal
pushd "%~dp0"
set RSVARS=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat
if not exist "%RSVARS%" ( echo [HATA] rsvars yok & exit /b 2 )
call "%RSVARS%" >nul
set LOG=%~dp0bench_log.txt
REM -$O+ : optimizasyon acik (release benzeri olcum), her iki unit icin ayni bayraklar
dcc32 -B -Q -$O+ -NSSystem;System.Win;Winapi;Vcl -U"..\..\..\core" -E"%~dp0bin" -N0"%~dp0dcu" "CacheBench.dpr" > "%LOG%" 2>&1
set ERR=%ERRORLEVEL%
if %ERR% NEQ 0 ( type "%LOG%" & echo === DERLEME BASARISIZ === & exit /b %ERR% )
"%~dp0bin\CacheBench.exe" >> "%LOG%" 2>&1
set ERR=%ERRORLEVEL%
type "%LOG%"
exit /b %ERR%
