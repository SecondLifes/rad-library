@echo off
REM RunTests.bat - örnek
REM Bu dosyayı scr\test\RunTests.bat olarak yerleştirin
chcp 65001 >nul
PUSHD %~DP0
set DELPHI_PATH=C:\Program Files (x86)\Embarcadero\Studio\37.0\bin
set PROJECT_DIR=%~dp0
set OUTPUT_DIR=%PROJECT_DIR%..\bin


call "%DELPHI_PATH%\rsvars.bat"

echo [1/2] Test projesi derleniyor...
MSBuild ".\RunTests.dproj" /t:Build /p:Config=Debug /p:platform=Win32

if %ERRORLEVEL% NEQ 0 (
    echo [HATA] Derleme basarisiz!
    pause
    exit /b %ERRORLEVEL%
)

echo [2/2] Testler calistiriliyor...
".\RunTests.exe" -xml:".\test_results.xml"
echo Test tamamlandi. Raporlar scr\test altinda.

