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
echo [1/16] Running Unit Tests (UT-01 .. UT-21b)...
"!GODOT_BIN!" --headless --path . "res://tests/test_dungeon_generator_unit.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Unit Tests failed.
    pause
    exit /b 1
)

echo.
echo [2/16] Running Property-Based Tests (100 Seeds x 5 Invariants)...
"!GODOT_BIN!" --headless --path . "res://tests/test_dungeon_properties.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Property Tests failed.
    pause
    exit /b 1
)

echo.
echo [3/16] Running Combat Regression Tests (5 hitbox directions)...
"!GODOT_BIN!" --headless --path . "res://tests/test_orc_battle.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Combat Regression Tests failed.
    pause
    exit /b 1
)

echo.
echo [4/16] Running Dungeon Generator Performance Benchmark...
"!GODOT_BIN!" --headless --path . "res://tests/benchmark_dungeon_generator.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Dungeon Benchmark failed.
    pause
    exit /b 1
)

echo.
echo [5/16] Running Skeleton King Boss Arena Tests (SK-01 .. SK-17)...
"!GODOT_BIN!" --headless --path . "res://tests/test_skeleton_king.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Skeleton King Tests failed.
    pause
    exit /b 1
)

echo.
echo [6/16] Running Doraemon Hero Tests (49 checks: gadgets, friends, supers)...
"!GODOT_BIN!" --headless --path . "res://tests/test_doraemon.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Doraemon Tests failed.
    pause
    exit /b 1
)

echo.
echo [7/16] Running Yugi Atem Hero Tests (animations and combat abilities)...
"!GODOT_BIN!" --headless --path . "res://tests/test_yugi.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Yugi Atem Tests failed.
    pause
    exit /b 1
)

echo.
echo [8/16] Running Werewolf Functional and Integration Tests (50 checks)...
"!GODOT_BIN!" --headless --path . "res://tests/test_werewolf.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Werewolf Tests failed.
    pause
    exit /b 1
)

echo.
echo [9/16] Running MOBA HUD, Stacking and Equipment Tests (15 groups: drag-and-drop, polymorphic equip dict, tooltip expert, anti-shift, anti-duplicate)...
"!GODOT_BIN!" --headless --path . "res://tests/test_moba_hud_and_inventory.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] MOBA HUD and Inventory Tests failed.
    pause
    exit /b 1
)

echo.
echo [10/16] Running Hoshimi Miyabi Hero Tests (18 checks: combo, dash, Frost Wave, Frost Bloom, spirit)...
"!GODOT_BIN!" --headless --path . "res://tests/test_miyabi.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Miyabi Tests failed.
    pause
    exit /b 1
)

echo.
echo [11/16] Running Luong Tho Hero Tests (15 checks: stance, combo, Twin Barrels, White Moon)...
"!GODOT_BIN!" --headless --path . "res://tests/test_luong_tho.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Luong Tho Tests failed.
    pause
    exit /b 1
)

echo.
echo [12/16] Running Projectile Obstacle Regression Tests (11 checks)...
"!GODOT_BIN!" --headless --path . "res://tests/test_projectile_obstacles.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Projectile Obstacle Tests failed.
    pause
    exit /b 1
)

echo.
echo [13/16] Running Skeleton Archer Combat Lifecycle Tests (12 checks)...
"!GODOT_BIN!" --headless --path . "res://tests/test_archer_combat_lifecycle.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Archer Combat Lifecycle Tests failed.
    pause
    exit /b 1
)

echo.
echo [14/16] Running Perk System Tests (Step 1 & Step 2 Verification)...
"!GODOT_BIN!" --headless --path . "res://tests/test_perk_system.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Perk System Tests failed.
    pause
    exit /b 1
)

echo.
echo [15/16] Running Replay Security Tests (Memory protection & Frame limits)...
"!GODOT_BIN!" --headless --path . "res://tests/test_replay_security.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Replay Security Tests failed.
    pause
    exit /b 1
)

echo.
echo [16/16] Running Settings, Graphics & UI Tests (97 checks)...
"!GODOT_BIN!" --headless --path . "res://tests/test_settings_and_ui.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Settings, Graphics & UI Tests failed.
    pause
    exit /b 1
)

echo.
echo ==================================================================
echo   [SUCCESS] ALL TEST SUITES PASSED 100%%
echo ==================================================================
pause
