extends Node2D
## Ví tiền lưu lâu dài (GameManager): dùng chung mọi nhân vật / mọi lượt, tự lưu (gom khi nhặt, lưu ngay khi chi tiêu,
## chuyển tầng, kết thúc lượt, thoát game), ghi an toàn qua file tạm + bản dự phòng, replay không đụng ví thật,
## save cũ / file hỏng được xử lý đúng.
## Dùng file ví riêng của bài test (user://wallet_unit_test.json) nên không ảnh hưởng ví thật của người chơi.

const GM_SCRIPT := preload("res://Scene/GameManager.gd")
const GAME_UI_SCENE := preload("res://Scene/UI/GameUI.tscn")
const TEST_WALLET := "user://wallet_unit_test.json"

var passed_count: int = 0
var failed_count: int = 0
var _saved_path: String = ""
var _saved_balance: int = 0

func assert_test(cond: bool, test_name: String) -> void:
	if cond:
		print("  [PASS] ", test_name)
		passed_count += 1
	else:
		printerr("  [FAIL] ", test_name)
		failed_count += 1

func _ready() -> void:
	print("\n========================================================")
	print("  RUNNING PERSISTENT WALLET TESTS")
	print("========================================================\n")
	await get_tree().process_frame
	_saved_path = GameManager.wallet_path
	_saved_balance = GameManager.coins
	assert_test(GameManager.wallet_path == GameManager.WALLET_TEST_FILE_PATH, "test runs never touch the player's real wallet file")
	_use_test_wallet()

	await test_persistence()
	await test_pickup_and_debounce()
	test_spending()
	test_flush_points()
	await test_replay()
	test_legacy_and_corruption()
	await test_hud()

	_cleanup()
	GameManager.wallet_path = _saved_path
	GameManager.load_wallet()
	print("\n========================================================")
	print("  TEST RESULTS: ", passed_count, " PASSED, ", failed_count, " FAILED")
	print("========================================================\n")
	get_tree().quit(1 if failed_count > 0 else 0)

# ------------------------------------------------------------------ helpers

func _use_test_wallet() -> void:
	_cleanup()
	GameManager.wallet_path = TEST_WALLET
	GameManager.load_wallet()

func _cleanup() -> void:
	for p in [TEST_WALLET, TEST_WALLET + ".tmp", TEST_WALLET + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

func _disk(path: String = TEST_WALLET) -> int:
	return GM_SCRIPT.read_wallet_file(path)

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

## "Mở lại game": một GameManager mới tinh đọc ví từ đĩa.
func _reopen() -> int:
	var gm: Node = GM_SCRIPT.new()
	gm.wallet_path = TEST_WALLET
	gm.load_wallet()
	var v: int = gm.coins
	gm.free()
	return v

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _pickup(value: int) -> void:
	var coin: Node2D = GameManager.COIN_PICKUP_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	coin.setup(value, rng, GameManager.run_id)
	add_child(coin)
	coin.collect()
	await get_tree().process_frame

# ------------------------------------------------------------------ tests

func test_persistence() -> void:
	print("--- Group 1: the wallet survives runs, heroes, death, menu and restarts ---")
	GameManager.start_new_run("WALLET-1", false, [])
	GameManager.coins = 202
	assert_test(GameManager.coins == 202 and _disk() == 202, "202 coins, saved to disk")
	GameManager.start_new_run("WALLET-2", false, [])
	assert_test(GameManager.coins == 202, "a new run keeps 202")
	GameManager.set_character_by_index(5)
	GameManager.set_character_by_index(0)
	assert_test(GameManager.coins == 202, "changing hero keeps 202")
	var hist := GameManager.run_history.duplicate(true)
	GameManager.finish_run("Fallen upon Floor 1")
	assert_test(GameManager.coins == 202 and _disk() == 202, "dying (end of run) keeps 202")
	GameManager.run_history = hist
	GameManager.save_data_to_disk()
	# main menu -> START (or game over -> choose again) opens a new run in the Guild Hall
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder   # change_scene replaces this placeholder, not the test
	GameManager.start_run_in_hall("WALLET-3")
	var hall: Node = null
	for i in 60:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs != null and cs != holder and cs.is_node_ready():
			hall = cs
			break
	assert_test(hall != null and GameManager.coins == 202, "back to the menu and into a new run keeps 202")
	get_tree().current_scene = self
	if hall != null:
		hall.queue_free()
	GameManager.hall_selecting = false
	await get_tree().process_frame
	assert_test(_reopen() == 202, "closing and reopening the game: still 202")

func test_pickup_and_debounce() -> void:
	print("--- Group 2: picking up coins ---")
	GameManager.start_new_run("WALLET-4", false, [])
	GameManager.coins = 202
	await _pickup(10)
	assert_test(GameManager.coins == 212, "picking up 10 coins -> 212")
	assert_test(_disk() == 202 and GameManager._wallet_dirty, "pickups are batched (not written yet)")
	await _wait(0.6)
	await _pickup(3)
	await _pickup(2)
	assert_test(_disk() == 202, "more pickups inside the window are batched too")
	await _wait(1.1)
	assert_test(_disk() == 217 and not GameManager._wallet_dirty, "saved once ~1.5 s after the first pickup (217)")
	GameManager.coins = 212
	var hist := GameManager.run_history.duplicate(true)
	GameManager.finish_run("Run end")
	assert_test(GameManager.coins == 212 and _disk() == 212, "ending the run still shows 212 (not added twice)")
	assert_test(int(GameManager.run_history[0].get("coins", -1)) == 15, "run history records the coins picked up in that run (10 + 3 + 2)")
	GameManager.run_history = hist
	GameManager.save_data_to_disk()
	# a coin from an earlier run is not credited to the wallet again
	var stale: Node2D = GameManager.COIN_PICKUP_SCRIPT.new()
	var rng := RandomNumberGenerator.new()
	stale.setup(5, rng, GameManager.run_id - 1)
	add_child(stale)
	stale.collect()
	await get_tree().process_frame
	assert_test(GameManager.coins == 212, "coins left over from an old run are not credited")
	GameManager.add_coins(GameManager.MAX_COINS, false)
	assert_test(GameManager.coins == GameManager.MAX_COINS, "the wallet is capped at MAX_COINS")
	GameManager.coins = 212

func test_spending() -> void:
	print("--- Group 3: spending ---")
	GameManager.coins = 212
	assert_test(GameManager.spend_coins(50) and GameManager.coins == 162, "spend 50 -> 162")
	assert_test(_disk() == 162 and not GameManager._wallet_dirty, "spending is saved immediately")
	assert_test(not GameManager.spend_coins(163) and GameManager.coins == 162 and _disk() == 162, "spending more than the balance is refused")
	assert_test(not GameManager.spend_coins(0) and not GameManager.spend_coins(-20) and GameManager.coins == 162, "zero / negative amounts are refused")
	GameManager.add_coins(-30, false)
	assert_test(GameManager.coins == 162, "add_coins ignores negative amounts")
	GameManager.coins = -50
	assert_test(GameManager.coins == 0 and _disk() == 0, "the balance can never go negative")
	GameManager.coins = 162
	# the shops spend through the same wallet
	assert_test(GameManager.spend_coins(162) and GameManager.coins == 0 and not GameManager.spend_coins(1), "spending everything leaves 0, nothing more can be spent")
	GameManager.coins = 162

func test_flush_points() -> void:
	print("--- Group 4: saved right away at floor change / run end / quit ---")
	GameManager.coins = 100
	GameManager.add_coins(1, false)
	GameManager.register_level_advance(2)
	assert_test(_disk() == 101, "floor change saves pending pickups")
	GameManager.add_coins(1, false)
	var hist := GameManager.run_history.duplicate(true)
	GameManager.finish_run("Run end")
	GameManager.run_history = hist
	GameManager.save_data_to_disk()
	assert_test(_disk() == 102, "run end saves pending pickups")
	GameManager.add_coins(1, false)
	GameManager.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_test(_disk() == 103 and not GameManager._wallet_dirty, "closing the game saves pending pickups")
	GameManager.current_level = 1
	assert_test(not FileAccess.file_exists(TEST_WALLET + ".tmp"), "no temp file is left behind")
	assert_test(_disk(TEST_WALLET + ".bak") == 102, "the previous save is kept as a backup")

func test_replay() -> void:
	print("--- Group 5: watching a replay never touches the real wallet ---")
	GameManager.start_new_run("WALLET-5", false, [])
	GameManager.coins = 162
	var before_text := FileAccess.get_file_as_string(TEST_WALLET)
	var frames := []
	for i in 30:
		frames.append({"dx": 1.0, "dy": 0.0})
	GameManager.start_new_run("WALLET-5", true, frames)
	assert_test(GameManager.is_replaying and GameManager.coins == 162, "replay starts with the real balance untouched")
	GameManager.add_coins(40)
	await _pickup(25)
	assert_test(GameManager.coins == 162, "coins picked up in a replay are not added")
	assert_test(not GameManager.spend_coins(10) and GameManager.coins == 162, "nothing can be spent in a replay")
	GameManager.coins = 9999
	assert_test(GameManager.coins == 162, "the balance cannot be overwritten in a replay")
	var hist := GameManager.run_history.duplicate(true)
	GameManager.finish_run("Replay end")
	GameManager.register_level_advance(3)
	GameManager.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	GameManager.run_history = hist
	GameManager.save_data_to_disk()
	assert_test(FileAccess.get_file_as_string(TEST_WALLET) == before_text and _disk() == 162, "the wallet file is not rewritten by the replay")
	GameManager.start_new_run("WALLET-6", false, [])
	assert_test(not GameManager.is_replaying and GameManager.coins == 162, "after the replay: still 162")

func test_legacy_and_corruption() -> void:
	print("--- Group 6: old saves and damaged files ---")
	_cleanup()
	GameManager.run_history.push_front({"seed": "OLD", "coins": 999, "frames": []})
	GameManager.last_recorded_run["coins"] = 555
	assert_test(_reopen() == 0, "an old save without a wallet starts at 0 (run history is not summed)")
	GameManager.run_history.pop_front()
	GameManager.last_recorded_run.erase("coins")
	# corrupted main file, good backup -> backup is used and the main file repaired
	_write(TEST_WALLET + ".bak", '{"version": 1, "coins": 150}')
	_write(TEST_WALLET, '{"version": 1, "coi')
	GameManager.load_wallet()
	assert_test(GameManager.coins == 150, "corrupted main file -> restored from the backup (150)")
	assert_test(_disk() == 150, "the main file is rewritten from the backup")
	# interrupted save: main missing, finished temp file present
	_cleanup()
	_write(TEST_WALLET + ".tmp", '{"version": 1, "coins": 77}')
	_write(TEST_WALLET + ".bak", '{"version": 1, "coins": 70}')
	GameManager.load_wallet()
	assert_test(GameManager.coins == 77 and _disk() == 77, "save interrupted before the swap -> the finished temp file is used")
	# everything broken -> 0
	_cleanup()
	_write(TEST_WALLET, "garbage")
	_write(TEST_WALLET + ".bak", "")
	GameManager.load_wallet()
	assert_test(GameManager.coins == 0, "main and backup both broken -> 0")
	# value checks
	var bad := {
		"negative": '{"coins": -5}', "fraction": '{"coins": 1.5}', "string": '{"coins": "202"}', "bool": '{"coins": true}',
		"too big": '{"coins": %d}' % (GameManager.MAX_COINS + 1), "missing": '{"version": 1}', "array": '[202]', "null": '{"coins": null}',
		"huge": '{"coins": 1e40}',
	}
	var accepted := []
	for k in bad:
		if GM_SCRIPT.parse_wallet_text(bad[k]) != -1:
			accepted.append(k)
	assert_test(accepted.is_empty(), "rejects negative, fractional, text, bool, over-limit, missing and malformed values (%s)" % str(accepted))
	assert_test(GM_SCRIPT.parse_wallet_text('{"version": 1, "coins": 202}') == 202 and GM_SCRIPT.parse_wallet_text('{"coins": 202.0}') == 202
		and GM_SCRIPT.parse_wallet_text('{"coins": %d}' % GameManager.MAX_COINS) == GameManager.MAX_COINS, "accepts whole numbers 0..MAX_COINS")
	_cleanup()
	_write(TEST_WALLET, '{"coins": 5}' + " ".repeat(GameManager.WALLET_MAX_FILE_BYTES))
	assert_test(_disk() == -1, "oversized wallet files are ignored")
	_cleanup()
	GameManager.load_wallet()
	GameManager.coins = 162

func test_hud() -> void:
	print("--- Group 7: HUD shows the wallet ---")
	GameManager.start_new_run("WALLET-7", false, [])
	GameManager.coins = 202
	var ui = GAME_UI_SCENE.instantiate()
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_test(ui.coin_label.text == "202", "HUD shows the wallet balance (202)")
	GameManager.spend_coins(50)
	await get_tree().process_frame
	assert_test(ui.coin_label.text == "152", "HUD updates right after spending (152)")
	GameManager.add_coins(10, false)
	await _wait(0.1)
	assert_test(ui.coin_target_value == 162 and int(ui.coin_label.text) > 152, "HUD starts counting up right after a pickup")
	await _wait(1.0)
	assert_test(ui.coin_label.text == "162", "HUD shows 162")
	GameManager.start_new_run("WALLET-8", false, [])
	await get_tree().process_frame
	assert_test(ui.coin_label.text == "162", "a new run keeps the HUD at 162")
	ui.queue_free()
	await get_tree().process_frame
