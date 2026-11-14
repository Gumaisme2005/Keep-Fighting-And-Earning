extends Node
const F = preload("res://tests/vt074/quality_fixture.gd")
const Player = preload("res://Scene/Character/BasePlayer.gd")
const Menu = preload("res://Menu/game over menu/game_over_menu.tscn")
var passed := 0
var failed := 0

func eq(actual: Variant, expected: Variant, label: String) -> void:
	var ok: bool = actual == expected
	if ok: passed += 1
	else: failed += 1
	print("[DEATH_ASSERT] ", JSON.stringify({"label": label, "actual": actual, "expected": expected, "result": "PASS" if ok else "FAIL"}))

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	# Autoload has already loaded only this child's probed empty userdata directory.
	GameManager.completion_store = F.Store.new("user://death.json")
	GameManager.completion_clock = func(): return F.DATE
	GameManager.start_new_run("ALOALO1234")
	GameManager.set_character_by_index(0)
	GameManager.current_level = 5
	GameManager.enemies_killed = 307
	GameManager.current_recording_frames = F.payload(18000).frames
	var token := GameManager.current_run_id
	GameManager.completion_store.fault = "open"
	var menu := Menu.instantiate()
	add_child(menu)
	var player := Player.new()
	add_child(player)
	player.set_physics_process(false)
	player.hp = 1
	player.current_armor = 0
	player.take_damage(1)
	eq(player.is_dead, true, "actual take_damage death")
	eq(GameManager.last_completion_result.status, "SAVE_FAILED", "death observes failure")
	eq(GameManager.run_history.size(), 0, "failed death no history")
	var frozen := JSON.stringify(GameManager._envelope).sha256_text()
	await get_tree().create_timer(2.2).timeout
	eq(menu.visible, true, "actual delayed death opens Game Over")
	eq(menu.save_status_label.text.contains("PROGRESS NOT SAVED"), true, "failure visible")
	eq(menu.retry_save_button.visible, true, "controlled retry offered")
	var blocked := true
	for action in menu.completion_actions: blocked = blocked and action.disabled
	eq(blocked, true, "navigation cannot drop pending completion")
	GameManager.current_level = 99
	GameManager.enemies_killed = 999
	GameManager.completion_store.fault = ""
	menu.retry_save_button.pressed.emit()
	eq(GameManager.last_completion_result.status, "COMMITTED", "UI retry commits frozen death")
	eq(GameManager.current_run_id, token, "UI retry same ID")
	eq(JSON.stringify(GameManager._envelope).sha256_text(), frozen, "UI retry same full payload")
	eq(GameManager.run_history[0].floor, 5, "death original floor")
	eq(GameManager.run_history[0].kills, 307, "death original kills")
	eq(menu.save_status_label.text, "RUN SAVED", "success explicit")
	eq(menu.retry_save_button.visible, false, "retry hidden after success")
	menu.pause({"status": "STORAGE_UNCERTAIN"})
	eq(menu.save_status_label.text.contains("SAVE NOT CONFIRMED"), true, "uncertain never claims saved")
	menu.pause({"status": "CONFLICT"})
	eq(menu.save_status_label.text.contains("SAVE NOT CONFIRMED"), true, "unexpected never claims saved")
	get_tree().paused = false
	player.free()
	menu.free()
	GameManager.completion_clock = Callable()
	print("[DEATH RESULTS] ", JSON.stringify({"passed": passed, "failed": failed}))
	get_tree().quit(1 if failed else 0)
