extends SceneTree
## AC-02 / TC-02: exact recovery after Delete Replay (native headless test).
## Run only from a disposable project whose user-data directory is named
## VT073_Sandbox_23001832:
## godot --headless --path <sandbox-project> --script res://tests/vt073/test_replay_undo.gd
## Configure isolation BEFORE launch: autoload initialization can write saves
## before this script runs. This guard does not isolate engine startup itself.

const SANDBOX_NAME: String = "VT073_Sandbox_23001832"


func _initialize() -> void:
	# Never resolve or mutate GameManager before checking the actual save location.
	var user_dir := OS.get_user_data_dir().replace("\\", "/").trim_suffix("/")
	if user_dir.get_file() != SANDBOX_NAME:
		_fail("sandbox required: OS.get_user_data_dir() must end in /" + SANDBOX_NAME)
		return
	call_deferred("_run_tc02")


func _run_tc02() -> void:
	var manager := root.get_node_or_null("GameManager")
	if manager == null:
		_fail("GameManager autoload is not accessible at /root/GameManager")
		return
	if not manager.has_method("delete_replay"):
		_fail("GameManager.delete_replay() is not available")
		return

	# Match the eight input fields recorded by Player 1_Pyrois/player.gd.
	# Fixed values avoid recording, random generation, and wall-clock timestamps.
	var replay: Dictionary = {
		"seed": "VT073_TC02_23001832",
		"hero_idx": 2,
		"hero_name": "Pyrois",
		"floor": 3,
		"kills": 7,
		"reason": "Game Over",
		"date": "2026-01-02 03:04:05",
		"has_replay": true,
		"frames": [
			{"dx": 1.0, "dy": 0.0, "ax": 32.0, "ay": 0.0,
				"atk": true, "q": false, "rmb": false, "slot": -1},
			{"dx": 0.0, "dy": -1.0, "ax": -16.5, "ay": 24.0,
				"atk": false, "q": true, "rmb": false, "slot": 0}
		]
	}
	var original: Dictionary = replay.duplicate(true)
	# Replace sandbox-loaded state; this case covers only the history replay.
	manager.set("run_history", [replay])
	manager.set("last_recorded_run", {})
	manager.set("saved_seeds", [])
	manager.set("current_seed", original["seed"])
	manager.set("selected_character_index", original["hero_idx"])

	if manager.call("delete_replay", replay) != true:
		_fail("delete_replay() rejected the valid fixture")
		return
	var history: Array = manager.get("run_history")
	if history.size() != 1 or not (history[0] is Dictionary):
		_fail("Delete must retain the history entry")
		return
	if history[0].get("frames") != [] or history[0].get("has_replay") != false:
		_fail("Delete did not clear frames and has_replay")
		return

	# Dynamic invocation keeps the test executable before the proposed API exists.
	if not manager.has_method("undo_delete_replay"):
		_fail("undo_delete_replay() is not implemented")
		return
	if manager.call("undo_delete_replay") != true:
		_fail("undo_delete_replay() did not report success")
		return

	# Re-read authoritative state: Undo may replace the stored dictionary.
	history = manager.get("run_history")
	if history.size() != 1 or not (history[0] is Dictionary):
		_fail("Undo must restore exactly one history replay")
		return
	var restored: Dictionary = history[0]
	if restored.get("frames") != original["frames"]:
		_fail("frames were not restored exactly, including order and values")
		return
	if restored.get("has_replay") != original["has_replay"]:
		_fail("has_replay was not restored exactly")
		return
	# Full dictionary equality also catches missing, changed, or extra metadata.
	if restored != original:
		_fail("replay metadata was not restored exactly")
		return
	print("PASS TC-02: replay frames, has_replay, and metadata restored exactly")
	quit(0)


func _fail(message: String) -> void:
	printerr("FAIL TC-02: " + message)
	quit(1)
