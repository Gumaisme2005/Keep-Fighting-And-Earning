# VT-075 - kiem chung cac assumption cua plan AI bang repository that.
# Chay tu thu muc goc project:  powershell -File tests/vt075/tools/plan_review_checks.ps1
$godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "B:\EnvironmentDev\Godot\Godot_v4.7.2-stable_win64_console.exe" }

"== A1: co lop mang/API trong code game? (mong doi: 0 ket qua) =="
$net = Get-ChildItem -Recurse -Filter *.gd -Path Scene,Menu | Select-String -Pattern "HTTPRequest|HTTPClient|ENet|WebSocket|MultiplayerAPI"
"matches=$(@($net).Count)"

"== A2: co addons/GUT/gdUnit4? (mong doi: khong) =="
"addons_dir_exists=$(Test-Path addons)"
"test_helper_in_existing_tests:"
Select-String -Path tests/test_dungeon_generator_unit.gd -Pattern "func _assert_true" | ForEach-Object { $_.Line.Trim() }

"== A3: GameManager co khoa/Mutex? mutator co emit + ghi file co dinh? =="
"mutex_in_Scene=$(@(Get-ChildItem -Recurse -Filter *.gd -Path Scene | Select-String -Pattern 'Mutex').Count)"
Select-String -Path Scene/GameManager.gd -Pattern "saved_data_changed.emit|SAVE_FILE_PATH|func save_seed_entry|func remove_saved_seed|func finish_run" | ForEach-Object { "GameManager.gd:$($_.LineNumber): $($_.Line.Trim())" }

"== A4: Thread/Mutex/Semaphore trong --headless =="
& $godot --headless --script res://tests/vt075/tools/thread_probe.gd 2>&1 | Select-String -Pattern "threads=|lost_updates"

"== A5: co co coverage trong godot --help? (mong doi: khong) =="
"coverage_flag_matches=$(@(& $godot --help | Select-String -Pattern 'coverage').Count)"

"== A6: co gh CLI? (mong doi: khong) =="
"gh_found=$([bool](Get-Command gh -ErrorAction SilentlyContinue))"

"== CI pin Godot version =="
Select-String -Path .github/workflows/ci.yml -Pattern "GODOT_VERSION" | ForEach-Object { $_.Line.Trim() }
& $godot --version

