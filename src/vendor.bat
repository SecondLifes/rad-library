@ECHO OFF
TITLE SecondLife
SETLOCAL EnableDelayedExpansion
:: Türkçe karakterler düzgün görünsün
chcp 65001 >nul
PUSHD %~DP0

SET Curr=%~dp0vendor
::SET FDelphi=%~dp0git\Delphi\
SET FDelphi=%~dp0vendor\


:: Git kontrolü
where git >nul 2>nul
if %ERRORLEVEL% neq 0 (
    call :color 31 "[HATA] Git sistemde bulunamadı! Lütfen Git'in kurulu ve PATH'e ekli olduğundan emin olun."
    pause
    exit /b 1
)

::git config --global user.email "baspinar99@gmail.com"
::git config --global user.name "Emrah BAŞPINAR"

:: https://api.github.com/users/VSoftTechnologies/repos?type=owner   all,owner,member


:: Renkli mesajlar için
set "ESC="
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do (
  set "ESC=!ESC!%%b"
)

::https://github.com/project-jedi
call :git project-jedi,"jcl,jvcl,jedi"

::https://github.com/exilon
call :git exilon,"QuickLib,QuickLogger"

::https://github.com/cesarliws
call :git cesarliws,"dext"

::https://github.com/gabr42
call :git gabr42,"OmniThreadLibrary-NG,OmniThreadLibrary,GpDelphiUnits,GpDelphiCode"

:: Delphi
::https://github.com/VSoftTechnologies
call :git VSoftTechnologies,"DUnitX,VSoft.AnsiConsole,VSoft.Awaitable,VSoft.SemanticVersion,VSoft.System.Console,VSoft.CommandLineParser,VSoft.Messaging,VSoft.Awaitable,VSoft.CancellationToken,VSoft.WeakReferences,VSoft.UUIDv7,VSoft.Ulid,VSoft.System.TimeProvider,VSoft.System.Console,VSoft.Awaitable,VSoft.OperationResult,VSoft.ThreadpoolTimer"


::https://gitee.com/z-proj/qdac.git
call :base https://gitee.com/z-proj/qdac,"%FDelphi%qdac\3.0"
call :base https://gitee.com/z-proj/qdac,"%FDelphi%qdac\4.0",4.0

::https://github.com/synopse
call :git synopse,"mORMot2"

:: --- BİTİŞ ---
echo.
call :color 32 "[TAMAMLANDI] Tüm kütüphaneler kontrol edildi."
pause
ENDLOCAL
EXIT /B 0


:bitbucket
 call :DownloadGit https://bitbucket.org/%~1,"%~2",%~3
EXIT /B 0

:color
:: %1 = renk kodu, %2... = mesaj
echo !ESC![%~1m%~2!ESC![0m
exit /b
	
:git
 if "%~3"=="" (set "folder=!FDelphi!") else (set "folder=%~3") 
 ::for %%a in (%~2) do ( echo %%a)
 for %%a in (%~2) do (call :base "https://github.com/%~1/%%a","!folder!%~1\%%a")
 ::for %%a in (%~2) do (call :color 33 "!folder!%~1\%%a" pause)

exit /b

:gitm
 (
 for %%a in (%~2) do ( call :base "%~1/%%a","%~3\%%a")
 )
exit /b
 	
:base
	set "URL=%~1"
	set "fd="
	if "%~2"=="" (set "fd=!FDelphi!") else (set "fd=%~2") 
	if "%~3"=="" (set "branc=master") else (set "branc=%~3") 
    
	::git submodule update --init --recursive
    :: Hedef dizine geç
    if not exist "!fd!" mkdir "!fd!"
    cd /d "!fd!"
	
    call :color 36 "[BİLGİ] !URL! başlatılıyor..."
	if exist "!fd!\.git" (
		cd "!fd!"
		call :color 33 "[BİLGİ] Repo zaten var, guncelleniyor..."
		::git pull
		git fetch origin !REMOTE_BRANCH!
        git reset --hard FETCH_HEAD
		call :color 32 "[BAŞARI] Repo basariyla guncellendi."
		cd /d "!fd!"
	) else (
	   call :color 33 "[BİLGİ] Repo indiriliyor..."
	   ::git clone -b "!branc!" --single-branch "!URL!" "!folder!"
	   if "%~3"=="" (git clone "!URL!" "!fd!") else (git clone -b "!branc!" --single-branch "!URL!" "!fd!")
	   call :color 32 "[BAŞARI] Repo basariyla indirildi."
	)

exit /b

