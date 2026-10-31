@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"

title Keep Fighting And Earning

set "GODOT_BIN=B:\EnvironmentDev\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "!GODOT_BIN!" (
    set "GODOT_BIN=B:\EnvironmentDev\Godot\Godot_v4.7.2-stable_win64_console.exe"
)
if not exist "!GODOT_BIN!" (
    for %%I in (godot.exe godot4.exe) do (
        if not "%%~$PATH:I"=="" set "GODOT_BIN=%%~$PATH:I"
    )
)
if not exist "!GODOT_BIN!" (
    echo [ERROR] Khong tim thay Godot tai B:\EnvironmentDev\Godot\Godot_v4.7.2-stable_win64.exe
    echo Vui long kiem tra lai duong dan Godot Engine!
    pause
    exit /b 1
)

start "" "!GODOT_BIN!" --path .
exit /b 0
