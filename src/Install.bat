@ECHO OFF
TITLE SecondLife
SETLOCAL EnableDelayedExpansion
:: Türkçe karakterler düzgün görünsün
chcp 65001 >nul
PUSHD %~DP0

cd /d "%~dp0"

radstudio library-path add "$(RAD)\component"
radstudio library-path add "$(RAD)\core"
radstudio library-path add "$(RAD)\packages"
radstudio library-path add "$(RAD)\share"
radstudio library-path add "$(RAD)\vendor"

radstudio env set "RAD" "%cd%"
::radstudio browsingpath add "$(RAD)\component"
::radstudio browsingpath add "$(RAD)\core"
::radstudio browsingpath add "$(RAD)\packages"
::radstudio browsingpath add "$(RAD)\share"
::radstudio browsingpath add "$(RAD)\vendor"

::radstudio library-path -p Win32 add "$(RAD)\Bin\Win32\Release"
::radstudio library-path -p Win64 add "$(RAD)\Bin\Win64\Release"

