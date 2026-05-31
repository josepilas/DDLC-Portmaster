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

echo Checking required DDLC assets...
echo Game dir: %GAMEDIR%

set "MISSING=0"
set "WARNINGS=0"

call :check "original\game\audio.rpa" "65683283"
call :check "original\game\images.rpa" "137750644"
call :check "original\game\scripts.rpa" "2708885"
call :check "original\game\fonts.rpa" "1831581"
call :check "original\characters\monika.chr" "137604"
call :check "original\characters\sayori.chr" "59621"
call :check "original\characters\natsuki.chr" "44793"
call :check "original\characters\yuri.chr" "30340"

if not "%MISSING%"=="0" (
    echo.
    echo Required assets are missing.
    echo Copy files from your original DDLC installation into:
    echo   %GAMEDIR%\original\game
    echo   %GAMEDIR%\original\characters
    echo No assets will be downloaded by this wrapper.
    exit /b 1
)

if not "%WARNINGS%"=="0" (
    echo.
    echo Asset size warnings were found. The wrapper will continue, but DDLC 1.1.1 assets are recommended.
)

echo All required DDLC assets were found.
exit /b 0

:check
if not exist "%GAMEDIR%\%~1" (
    echo Missing: ddlc/%~1
    set "MISSING=1"
) else (
    echo Found: ddlc/%~1
    for %%F in ("%GAMEDIR%\%~1") do set "FOUND_SIZE=%%~zF"
    if not "%~2"=="" if not "!FOUND_SIZE!"=="%~2" (
        echo Warning: ddlc/%~1 size is !FOUND_SIZE!; expected %~2 for DDLC 1.1.1.
        set "WARNINGS=1"
    )
)
exit /b 0
