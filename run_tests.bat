@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"

title Keep Fighting And Earning - Automated Test Suite

set "GODOT_BIN=B:\EnvironmentDev\Godot\Godot_v4.7.2-stable_win64_console.exe"
if not exist "!GODOT_BIN!" (
    set "GODOT_BIN=B:\EnvironmentDev\Godot\Godot_v4.7.2-stable_win64.exe"
)
if not exist "!GODOT_BIN!" (
    for %%I in (godot.exe godot4.exe) do (
        if not "!GODOT_BIN!"=="" set "GODOT_BIN=%%~$PATH:I"
    )
)
if not exist "!GODOT_BIN!" (
    echo [ERROR] Khong tim thay Godot tai B:\EnvironmentDev\Godot\Godot_v4.7.2-stable_win64_console.exe
    echo Vui long kiem tra lai duong dan Godot Engine!
    pause
    exit /b 1
)

echo ==================================================================
echo   KEEP FIGHTING AND EARNING - AUTOMATED TEST SUITE
echo   Godot: !GODOT_BIN!
echo ==================================================================

echo.
echo [1/4] Chay Unit Tests (UT-01 .. UT-13)...
"!GODOT_BIN!" --headless --path . "res://tests/test_dungeon_generator_unit.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [THAT BAI] Unit Tests gap loi!
    pause
    exit /b 1
)

echo.
echo [2/4] Chay Property-Based Tests (100 Seeds x 5 Invariants)...
"!GODOT_BIN!" --headless --path . "res://tests/test_dungeon_properties.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [THAT BAI] Property Tests gap loi!
    pause
    exit /b 1
)

echo.
echo [3/4] Chay Combat Regression Tests (5 huong hitbox Orc)...
"!GODOT_BIN!" --headless --path . "res://test_orc_battle.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [THAT BAI] Combat Regression Tests gap loi!
    pause
    exit /b 1
)

echo.
echo [4/4] Chay Benchmark Hieu Nang Bo Sinh Nguc...
"!GODOT_BIN!" --headless --path . "res://tests/benchmark_dungeon_generator.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [THAT BAI] Benchmark gap loi!
    pause
    exit /b 1
)

echo.
echo ==================================================================
echo   [THANH CONG] TAT CA UNIT, PROPERTY, COMBAT VA BENCHMARK PASS 100%%!
echo ==================================================================
pause
