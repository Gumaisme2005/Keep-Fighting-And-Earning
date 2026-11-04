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
    echo [ERROR] Godot executable not found at B:\EnvironmentDev\Godot\Godot_v4.7.2-stable_win64_console.exe
    echo Please verify the Godot binary path.
    pause
    exit /b 1
)

echo ==================================================================
echo   KEEP FIGHTING AND EARNING - AUTOMATED TEST SUITE
echo   Godot: !GODOT_BIN!
echo ==================================================================

echo.
echo [1/7] Running Unit Tests (UT-01 .. UT-13)...
"!GODOT_BIN!" --headless --path . "res://tests/test_dungeon_generator_unit.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Unit Tests failed.
    pause
    exit /b 1
)

echo.
echo [2/7] Running Property-Based Tests (100 Seeds x 5 Invariants)...
"!GODOT_BIN!" --headless --path . "res://tests/test_dungeon_properties.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Property Tests failed.
    pause
    exit /b 1
)

echo.
echo [3/7] Running Combat Regression Tests (5 hitbox directions)...
"!GODOT_BIN!" --headless --path . "res://tests/test_orc_battle.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Combat Regression Tests failed.
    pause
    exit /b 1
)

echo.
echo [4/7] Running Dungeon Generator Performance Benchmark...
"!GODOT_BIN!" --headless --path . "res://tests/benchmark_dungeon_generator.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Dungeon Benchmark failed.
    pause
    exit /b 1
)

echo.
echo [5/7] Running Skeleton King Boss Arena Tests (SK-01 .. SK-17)...
"!GODOT_BIN!" --headless --path . "res://tests/test_skeleton_king.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Skeleton King Tests failed.
    pause
    exit /b 1
)

echo.
echo [6/7] Running Doraemon Hero Tests (47 checks: gadgets, friends, supers)...
"!GODOT_BIN!" --headless --path . "res://tests/test_doraemon.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Doraemon Tests failed.
    pause
    exit /b 1
)

echo.
echo [7/7] Chay Doraemon Hero Tests (48 checks: 20 gadgets, 6 friends, 10 supers)...
"!GODOT_BIN!" --headless --path . "res://tests/test_doraemon.tscn"
echo [7/8] Running Yugi Atem Hero Tests (animations and combat abilities)...
"!GODOT_BIN!" --headless --path . "res://tests/test_yugi.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Yugi Atem Tests failed.
    pause
    exit /b 1
)

echo.
echo [8/8] Running Werewolf Functional & Integration Tests (50 checks)...
"!GODOT_BIN!" --headless --path . "res://tests/test_werewolf.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Werewolf Tests failed.
    pause
    exit /b 1
)

echo.
echo [8/8] Chay Hoshimi Miyabi Hero Tests (18 checks: combo, dash, Frost Wave, Frost Bloom, spirit)...
"!GODOT_BIN!" --headless --path . "res://tests/test_miyabi.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [THAT BAI] Miyabi Tests gap loi!
    pause
    exit /b 1
)

echo.
echo [9/9] Chay Luong Tho Hero Tests (15 checks: stance, combo, Twin Barrels, White Moon)...
"!GODOT_BIN!" --headless --path . "res://tests/test_luong_tho.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [THAT BAI] Luong Tho Tests gap loi!
    pause
    exit /b 1
)

echo.
echo ==================================================================
echo   [SUCCESS] ALL TEST SUITES PASSED 100%%
echo ==================================================================
pause
