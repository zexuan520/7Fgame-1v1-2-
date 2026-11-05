@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem Managed Zaohua Godot Web build.
rem Usage: build-web.cmd ["C:\path\to\godot.exe"]

for %%I in ("%~dp0.") do set "PROJECT_DIR=%%~fI"
set "GODOT_EXE=%~1"
if not defined GODOT_WEB_PRESET set "GODOT_WEB_PRESET=Web"

if not defined GODOT_EXE if defined GODOT_BIN set "GODOT_EXE=%GODOT_BIN%"
if not defined GODOT_EXE if defined OPENCAT_REPO_ROOT set "GODOT_EXE=%OPENCAT_REPO_ROOT%\Godot\bin\godot.windows.editor.x86_64.exe"
if not defined GODOT_EXE for /f "delims=" %%I in ('where godot.exe 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%I"
if not defined GODOT_EXE for /f "delims=" %%I in ('where godot 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%I"

if not exist "%PROJECT_DIR%\project.godot" (
	echo [ERROR] project.godot is missing from "%PROJECT_DIR%".
	exit /b 1
)
if not exist "%PROJECT_DIR%\export_presets.cfg" (
	echo [ERROR] export_presets.cfg is missing from "%PROJECT_DIR%".
	exit /b 1
)
findstr /L /C:"name=\"%GODOT_WEB_PRESET%\"" "%PROJECT_DIR%\export_presets.cfg" >nul
if errorlevel 1 (
	echo [ERROR] Godot Web export preset "%GODOT_WEB_PRESET%" was not found.
	exit /b 1
)
if not defined GODOT_EXE (
	echo [ERROR] Godot executable was not found.
	echo         Pass it as the first argument, set GODOT_BIN or OPENCAT_REPO_ROOT,
	echo         or add godot.exe to PATH.
	exit /b 1
)
if not exist "%GODOT_EXE%" (
	echo [ERROR] Godot executable does not exist: "%GODOT_EXE%"
	exit /b 1
)

set "STAGE_DIR=%TEMP%\zaohua-godot-web-%RANDOM%-%RANDOM%"
set "OUTPUT_DIR=%PROJECT_DIR%\dist"
set "NEXT_DIR=%PROJECT_DIR%\dist.next"
set "PREVIOUS_DIR=%PROJECT_DIR%\dist.prev"

if exist "%STAGE_DIR%" rmdir /s /q "%STAGE_DIR%"
if exist "%NEXT_DIR%" rmdir /s /q "%NEXT_DIR%"
mkdir "%STAGE_DIR%" || exit /b 1

echo [1/3] Exporting Godot Web release...
call "%GODOT_EXE%" --headless --path "%PROJECT_DIR%" --export-release "%GODOT_WEB_PRESET%" "%STAGE_DIR%\index.html"
if errorlevel 1 goto :failed

echo [2/3] Verifying Web artifacts...
for %%F in (index.html index.js index.wasm index.pck) do (
	if not exist "%STAGE_DIR%\%%F" (
		echo [ERROR] Export did not produce %%F.
		goto :failed
	)
)
if exist "%PROJECT_DIR%\addons\zaohua_platform\plugin.cfg" (
	findstr /L /C:"data-zaohua-godot-sdk" "%STAGE_DIR%\index.html" >nul
	if errorlevel 1 (
		echo [ERROR] Zaohua addon is installed but the exported index.html has no SDK marker.
		echo         Enable the Zaohua Platform editor plugin, then export again.
		goto :failed
	)
)

rem Mobile publishing: copy the source-root landing.html unchanged into dist
if exist "%PROJECT_DIR%\landing.html" copy /y "%PROJECT_DIR%\landing.html" "%STAGE_DIR%\landing.html" >nul

echo [3/3] Publishing atomically to "%OUTPUT_DIR%"...
robocopy "%STAGE_DIR%" "%NEXT_DIR%" /E /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 (
	echo [ERROR] Failed to stage the exported files.
	goto :failed
)
if exist "%PREVIOUS_DIR%" rmdir /s /q "%PREVIOUS_DIR%"
if exist "%OUTPUT_DIR%" (
	move "%OUTPUT_DIR%" "%PREVIOUS_DIR%" >nul
	if errorlevel 1 (
		echo [ERROR] Failed to preserve the previous dist directory.
		goto :failed
	)
)
move "%NEXT_DIR%" "%OUTPUT_DIR%" >nul
if errorlevel 1 (
	echo [ERROR] Failed to publish the new dist directory.
	if not exist "%OUTPUT_DIR%" if exist "%PREVIOUS_DIR%" move "%PREVIOUS_DIR%" "%OUTPUT_DIR%" >nul
	goto :failed
)
if exist "%PREVIOUS_DIR%" rmdir /s /q "%PREVIOUS_DIR%"
if exist "%STAGE_DIR%" rmdir /s /q "%STAGE_DIR%"

echo.
echo [OK] Web build ready: "%OUTPUT_DIR%\index.html"
exit /b 0

:failed
if exist "%STAGE_DIR%" rmdir /s /q "%STAGE_DIR%"
if exist "%NEXT_DIR%" rmdir /s /q "%NEXT_DIR%"
if not exist "%OUTPUT_DIR%" if exist "%PREVIOUS_DIR%" move "%PREVIOUS_DIR%" "%OUTPUT_DIR%" >nul
echo.
echo [ERROR] Godot Web build failed. The previous dist was preserved.
exit /b 1
