@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"

title Keep Fighting And Earning - Automated Test Suite

if not defined GODOT_BIN set "GODOT_BIN=B:\EnvironmentDev\Godot\Godot_v4.7.2-stable_win64_console.exe"
if not exist "!GODOT_BIN!" (
    set "GODOT_BIN=B:\EnvironmentDev\Godot\Godot_v4.7.2-stable_win64.exe"
)
if not exist "!GODOT_BIN!" (
    for %%I in (godot.exe godot4.exe) do (
        if not "%%~$PATH:I"=="" set "GODOT_BIN=%%~$PATH:I"
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
echo [Tutorial] Running Tutorial Framework in an isolated project and save profile...
if not defined PYTHON_BIN set "PYTHON_BIN=python"
"!PYTHON_BIN!" tests\run_tutorial_verification.py --godot "!GODOT_BIN!" --cross-fps --suites test_tutorial_framework test_tutorial_movement test_tutorial_combat test_tutorial_hero_skills
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Tutorial Framework failed or did not complete.
    exit /b 1
)

echo [1/26] Running Unit Tests (UT-01 .. UT-13)...
"!GODOT_BIN!" --headless --path . "res://tests/test_dungeon_generator_unit.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Unit Tests failed.
    pause
    exit /b 1
)

echo.
echo [2/26] Running Property-Based Tests (100 Seeds x 5 Invariants)...
"!GODOT_BIN!" --headless --path . "res://tests/test_dungeon_properties.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Property Tests failed.
    pause
    exit /b 1
)

echo.
echo [3/26] Running Combat Regression Tests (5 hitbox directions)...
"!GODOT_BIN!" --headless --path . "res://tests/test_orc_battle.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Combat Regression Tests failed.
    pause
    exit /b 1
)

echo.
echo [4/26] Running Dungeon Generator Performance Benchmark...
"!GODOT_BIN!" --headless --path . "res://tests/benchmark_dungeon_generator.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Dungeon Benchmark failed.
    pause
    exit /b 1
)

echo.
echo [5/26] Running Skeleton King Boss Arena Tests (SK-01 .. SK-17)...
"!GODOT_BIN!" --headless --path . "res://tests/test_skeleton_king.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Skeleton King Tests failed.
    pause
    exit /b 1
)

echo.
echo [6/26] Running Doraemon Hero Tests (49 checks: gadgets, friends, supers)...
"!GODOT_BIN!" --headless --path . "res://tests/test_doraemon.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Doraemon Tests failed.
    pause
    exit /b 1
)

echo.
echo [7/26] Running Yugi Atem Hero Tests (animations and combat abilities)...
"!GODOT_BIN!" --headless --path . "res://tests/test_yugi.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Yugi Atem Tests failed.
    pause
    exit /b 1
)

echo.
echo [8/26] Running Werewolf Functional and Integration Tests (50 checks)...
"!GODOT_BIN!" --headless --path . "res://tests/test_werewolf.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Werewolf Tests failed.
    pause
    exit /b 1
)

echo.
echo [9/26] Running MOBA HUD, Stacking and Equipment Tests (15 groups: drag-and-drop, polymorphic equip dict, tooltip expert, anti-shift, anti-duplicate)...
"!GODOT_BIN!" --headless --path . "res://tests/test_moba_hud_and_inventory.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] MOBA HUD and Inventory Tests failed.
    pause
    exit /b 1
)

echo.
echo [10/26] Chay Hoshimi Miyabi Hero Tests (18 checks: combo, dash, Frost Wave, Frost Bloom, spirit)...
"!GODOT_BIN!" --headless --path . "res://tests/test_miyabi.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [THAT BAI] Miyabi Tests gap loi!
    pause
    exit /b 1
)

echo.
echo [11/26] Chay Luong Tho Hero Tests (15 checks: stance, combo, Twin Barrels, White Moon)...
"!GODOT_BIN!" --headless --path . "res://tests/test_luong_tho.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [THAT BAI] Luong Tho Tests gap loi!
    pause
    exit /b 1
)

echo.
echo [12/26] Running Projectile Obstacle Regression Tests (11 checks)...
"!GODOT_BIN!" --headless --path . "res://tests/test_projectile_obstacles.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Projectile Obstacle Tests failed.
    pause
    exit /b 1
)

echo.
echo [13/26] Running Perk System Tests (Step 1 & Step 2 Verification)...
"!GODOT_BIN!" --headless --path . "res://tests/test_perk_system.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Perk System Tests failed.
    pause
    exit /b 1
)

echo.
echo [14/26] Running Replay Security Tests (Memory protection & Frame limits)...
"!GODOT_BIN!" --headless --path . "res://tests/test_replay_security.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Replay Security Tests failed.
    pause
    exit /b 1
)

echo.
echo [15/26] Running Coin Drop and Pickup Tests (drops, magnet, fallen hero)...
"!GODOT_BIN!" --headless --path . "res://tests/test_coins.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Coin Tests failed.
    pause
    exit /b 1
)

echo.
echo [16/26] Running Guild Hall Tests (scene, walls, minimap, no T key)...
"!GODOT_BIN!" --headless --path . "res://tests/test_guild_hall.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Guild Hall Tests failed.
    pause
    exit /b 1
)

echo.
echo [17/26] Running Guild Hall Character Select Tests (panel, start, ESC, hall_selecting)...
"!GODOT_BIN!" --headless --path . "res://tests/test_hall_select.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Character Select Tests failed.
    pause
    exit /b 1
)

echo.
echo [18/26] Running Rune Sword Portal Tests (hall to floor 1, replay buffer)...
"!GODOT_BIN!" --headless --path . "res://tests/test_rune_portal.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Rune Portal Tests failed.
    pause
    exit /b 1
)

echo.
echo [19/26] Running Blacksmith Shop Tests (buy, sell, equip, stock reset per run)...
"!GODOT_BIN!" --headless --path . "res://tests/test_shop.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Blacksmith Shop Tests failed.
    pause
    exit /b 1
)

echo.
echo [20/26] Running Mage Perk Shop Tests...
"!GODOT_BIN!" --headless --path . "res://tests/test_mage_shop.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Mage Shop Tests failed.
    pause
    exit /b 1
)

echo.
echo [21/26] Running Alchemist Potion Shop Tests...
"!GODOT_BIN!" --headless --path . "res://tests/test_potion_shop.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Potion Shop Tests failed.
    pause
    exit /b 1
)

echo.
echo [22/26] Running Persistent Wallet Tests (save, backup, replay safety)...
"!GODOT_BIN!" --headless --path . "res://tests/test_wallet.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Persistent Wallet Tests failed.
    pause
    exit /b 1
)

echo.
echo [23/26] Running Wandering Merchant Tests (Joanna / Eleonore shops on floors 3, 6, 9...)...
"!GODOT_BIN!" --headless --path . "res://tests/test_wandering_merchant.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Wandering Merchant Tests failed.
    pause
    exit /b 1
)

echo.
echo [24/26] Running Main Menu Modal Layout Tests (Controls, Lore, Seeds fit the window - SPK-11)...
"!GODOT_BIN!" --headless --path . "res://tests/test_main_menu_modals.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Main Menu Modal Layout Tests failed.
    pause
    exit /b 1
)

echo.
echo [25/26] Running Yugi Audio Tests (summon, voice and Q card sounds from the MUGEN Yami Yugi)...
"!GODOT_BIN!" --headless --path . "res://tests/test_yugi_audio.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Yugi Audio Tests failed.
    pause
    exit /b 1
)

echo.
echo [26/26] Running Miyabi and Luong Tho Sound Effect Tests (synthesised frost / gunblade sounds)...
"!GODOT_BIN!" --headless --path . "res://tests/test_hero_sfx.tscn"
if !ERRORLEVEL! NEQ 0 (
    echo [FAILED] Miyabi and Luong Tho Sound Effect Tests failed.
    pause
    exit /b 1
)

echo.
echo ==================================================================
echo   [SUCCESS] ALL TEST SUITES PASSED 100%%
echo ==================================================================
pause
