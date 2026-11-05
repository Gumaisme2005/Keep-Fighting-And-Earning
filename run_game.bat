@echo off
setlocal
cd /d "%~dp0"
if defined GODOT_BIN goto launch
for %%I in (godot.exe godot4.exe) do (
    if not "%%~$PATH:I"=="" set "GODOT_BIN=%%~$PATH:I"
)
if defined GODOT_BIN goto launch
echo [ERROR] Godot not found. Set GODOT_BIN to your Godot 4.7.2 executable or add it to PATH.
exit /b 1
:launch
start "" "%GODOT_BIN%" --path "%~dp0."
exit /b %ERRORLEVEL%
