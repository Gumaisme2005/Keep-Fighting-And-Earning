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
echo [1/13] Running Unit Tests (UT-01 .. UT-13)...
"!GODOT_BIN!" --headless --path . "res://tests/test_dungeon_generator_unit.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Unit Tests failed.
    pause
    exit /b 1
)

echo.
echo [2/12] Running Property-Based Tests (100 Seeds x 5 Invariants)...
"!GODOT_BIN!" --headless --path . "res://tests/test_dungeon_properties.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Property Tests failed.
    pause
    exit /b 1
)

echo.
echo [3/12] Running Combat Regression Tests (5 hitbox directions)...
"!GODOT_BIN!" --headless --path . "res://tests/test_orc_battle.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Combat Regression Tests failed.
    pause
    exit /b 1
)

echo.
echo [4/12] Running Dungeon Generator Performance Benchmark...
"!GODOT_BIN!" --headless --path . "res://tests/benchmark_dungeon_generator.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Dungeon Benchmark failed.
    pause
    exit /b 1
)

echo.
echo [5/12] Running Skeleton King Boss Arena Tests (SK-01 .. SK-17)...
"!GODOT_BIN!" --headless --path . "res://tests/test_skeleton_king.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Skeleton King Tests failed.
    pause
    exit /b 1
)

echo.
echo [6/12] Running Doraemon Hero Tests (49 checks: gadgets, friends, supers)...
"!GODOT_BIN!" --headless --path . "res://tests/test_doraemon.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Doraemon Tests failed.
    pause
    exit /b 1
)

echo.
echo [7/12] Running Yugi Atem Hero Tests (animations and combat abilities)...
"!GODOT_BIN!" --headless --path . "res://tests/test_yugi.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Yugi Atem Tests failed.
    pause
    exit /b 1
)

echo.
echo [8/12] Running Werewolf Functional and Integration Tests (50 checks)...
"!GODOT_BIN!" --headless --path . "res://tests/test_werewolf.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Werewolf Tests failed.
    pause
    exit /b 1
)

echo.
echo [9/12] Running MOBA HUD, Stacking and Equipment Tests (15 groups: drag-and-drop, polymorphic equip dict, tooltip expert, anti-shift, anti-duplicate)...
"!GODOT_BIN!" --headless --path . "res://tests/test_moba_hud_and_inventory.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] MOBA HUD and Inventory Tests failed.
    pause
    exit /b 1
)

echo.
echo [10/12] Chay Hoshimi Miyabi Hero Tests (18 checks: combo, dash, Frost Wave, Frost Bloom, spirit)...
"!GODOT_BIN!" --headless --path . "res://tests/test_miyabi.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [THAT BAI] Miyabi Tests gap loi!
    pause
    exit /b 1
)

echo.
echo [11/12] Chay Luong Tho Hero Tests (15 checks: stance, combo, Twin Barrels, White Moon)...
"!GODOT_BIN!" --headless --path . "res://tests/test_luong_tho.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [THAT BAI] Luong Tho Tests gap loi!
    pause
    exit /b 1
)

echo.
echo [12/13] Running Projectile Obstacle Regression Tests (11 checks)...
"!GODOT_BIN!" --headless --path . "res://tests/test_projectile_obstacles.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Projectile Obstacle Tests failed.
    pause
    exit /b 1
)

echo.
echo [13/13] Running Perk System Tests (Step 1 & Step 2 Verification)...
"!GODOT_BIN!" --headless --path . "res://tests/test_perk_system.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Perk System Tests failed.
    pause
    exit /b 1
)

echo.
echo ==================================================================
echo   [SUCCESS] ALL TEST SUITES PASSED 100%%
echo ==================================================================
pause
