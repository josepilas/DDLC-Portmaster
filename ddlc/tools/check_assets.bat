@echo off
setlocal EnableExtensions EnableDelayedExpansion

if /I "%SKIP_ASSET_CHECK%"=="1" (
    echo SKIP_ASSET_CHECK=1, skipping asset validation.
    exit /b 0
)

if "%~1"=="" (
    set "GAMEDIR=%~dp0.."
) else (
    set "GAMEDIR=%~1"
)
set "ORIGINAL_CONTAINER=%GAMEDIR%\original"
set "ORIGINAL_ROOT=%ORIGINAL_CONTAINER%"

echo Checking required DDLC assets...
echo Game dir: %GAMEDIR%
echo Original container: %ORIGINAL_CONTAINER%

call :has_required "%ORIGINAL_CONTAINER%"
if "%HAS_REQUIRED%"=="1" (
    set "ORIGINAL_ROOT=%ORIGINAL_CONTAINER%"
) else (
    for /d %%D in ("%ORIGINAL_CONTAINER%\*") do (
        if "!HAS_REQUIRED!"=="1" goto :resolved_root
        call :has_required "%%~fD"
        if "!HAS_REQUIRED!"=="1" set "ORIGINAL_ROOT=%%~fD"
    )
)
:resolved_root
echo Detected asset root: %ORIGINAL_ROOT%

set "MISSING=0"
set "WARNINGS=0"

call :check "game\audio.rpa" "65683283"
call :check "game\images.rpa" "137750644"
call :check "game\scripts.rpa" "2708885"
call :check "game\fonts.rpa" "1831581"
call :check "characters\monika.chr" "137604"
call :check "characters\sayori.chr" "59621"
call :check "characters\natsuki.chr" "44793"
call :check "characters\yuri.chr" "30340"

if not "%MISSING%"=="0" (
    echo.
    echo Required assets are missing.
    echo Extract or copy your DDLC root into:
    echo   %ORIGINAL_CONTAINER%
    echo No assets will be downloaded by this wrapper.
    exit /b 1
)

if not "%WARNINGS%"=="0" (
    echo.
    echo Asset size warnings were found. The wrapper will continue, but DDLC 1.1.1 assets are recommended.
)

echo All required DDLC assets were found.
exit /b 0

:has_required
set "HAS_REQUIRED=0"
if exist "%~1\game\audio.rpa" if exist "%~1\game\images.rpa" if exist "%~1\game\scripts.rpa" if exist "%~1\game\fonts.rpa" if exist "%~1\characters\monika.chr" if exist "%~1\characters\sayori.chr" if exist "%~1\characters\natsuki.chr" if exist "%~1\characters\yuri.chr" set "HAS_REQUIRED=1"
exit /b 0

:check
if not exist "%ORIGINAL_ROOT%\%~1" (
    echo Missing: original/%~1
    set "MISSING=1"
) else (
    echo Found: original/%~1
    for %%F in ("%ORIGINAL_ROOT%\%~1") do set "FOUND_SIZE=%%~zF"
    if not "%~2"=="" if not "!FOUND_SIZE!"=="%~2" (
        echo Warning: original/%~1 size is !FOUND_SIZE!; expected %~2 for DDLC 1.1.1.
        set "WARNINGS=1"
    )
)
exit /b 0
