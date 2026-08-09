@echo off
setlocal
pushd "%~dp0"
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" >nul
set LOG=%~dp0smoke_log.txt
dcc32 -B -Q -NSSystem;System.Win;Winapi;Vcl -U"..\..\..\core" -E"%~dp0bin" -N0"%~dp0dcu" "InterfaceSmoke.dpr" > "%LOG%" 2>&1
set ERR=%ERRORLEVEL%
if %ERR% NEQ 0 ( type "%LOG%" & exit /b %ERR% )
"%~dp0bin\InterfaceSmoke.exe" >> "%LOG%" 2>&1
set ERR=%ERRORLEVEL%
type "%LOG%"
exit /b %ERR%
