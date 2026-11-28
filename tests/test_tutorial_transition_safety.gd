extends "res://tests/tutorial_hall_test_support.gd"

class FaultGenerator extends "res://Scene/Map/dungeon_generator.gd":
	var fault := ""
	func spawn_entities() -> void:
		match fault:
			"silent": return
			"hero":
				the_player.queue_free()
				return
			"world":
				get_parent().queue_free()
				return
			"layout":
				generated_rooms.clear()
				return
		super.spawn_entities()

var _fault := ""
var _stats: Array = []
var _outcomes: Array = []

func _wait_failed_request() -> void:
	for unused in 120:
		await get_tree().process_frame
		if not GameManager._hall_request_pending: break
	await get_tree().process_frame # Flush queued deletion after the owning callback.

func _inject(node: Node) -> void:
	if not _fault.is_empty() and node.scene_file_path == GameManager.DUNGEON_SCENE:
		var gen := node.get_node("TileMap")
		var original: Node2D = gen.the_player
		gen.set_script(FaultGenerator)
		gen.the_player = original
		gen.fault = _fault

func _stats_changed(_floor: int, _kills: int) -> void:
	_stats.append(true)

func _handoff(_hero: Node2D, _world: Node, _run: int, _request: int, success: bool) -> void:
	_outcomes.append(success)

func _state() -> Dictionary:
	return {"level": GameManager.current_level, "vitality": GameManager.floor_vitality_gained,
		"clears": GameManager._vitality_floor_clears.duplicate(true), "seed": GameManager.current_seed,
		"frames": GameManager.current_recording_frames.duplicate(true), "replay": GameManager.replay_frames.duplicate(true),
		"history": GameManager.run_history.duplicate(true), "coins": GameManager.coins, "dirty": GameManager._wallet_dirty,
		"wallet": FileAccess.get_file_as_bytes(GameManager.wallet_path), "selecting": GameManager.hall_selecting,
		"kills": GameManager.enemies_killed, "stats": _stats.size()}

func _fixture() -> void:
	await get_tree().process_frame # Flush queued provisional worlds before the Hall checks player ownership.
	_fault = ""
	await new_hall(2, false)
	GameManager.current_recording_frames = [{"dx": 1.0, "dy": 0.0}]
	GameManager._wallet_dirty = true
	_stats.clear()
	_outcomes.clear()

func _ready() -> void:
	await ticks(2)
	GameManager.stats_updated.connect(_stats_changed)
	GameManager.hall_dungeon_handoff.connect(_handoff)
	get_tree().node_added.connect(_inject)
	for round_index in 5:
		await _fixture()
		var before := _state()
		check(GameManager.enter_dungeon_from_hall(hall.hero), "TRANS-04 accepted deferred failure")
		check(not GameManager.enter_dungeon_from_hall(hall.hero), "TRANS-03 duplicate rejected")
		check(_state() == before, "TRANS-12 acceptance has no progression/recording/Wallet/stats mutation")
		hall.hero.queue_free()
		await _wait_failed_request()
		check(not GameManager._hall_request_pending and _outcomes == [false] and _state() == before, "TRANS-04/11/12 failed deferred request is side-effect free")
		await _fixture()
		check(GameManager.enter_dungeon_from_hall(hall.hero), "TRANS-10 new request accepted")
		GameManager._finish_hall_handoff(weakref(hall.hero), weakref(hall), GameManager.run_id - 1, GameManager._hall_request_serial - 1)
		check(GameManager._hall_request_pending and _outcomes.is_empty(), "TRANS-10 stale callback cannot release newer request")
		hall.hero.queue_free()
		await _wait_failed_request()
		for fault in ["hero", "world", "layout", "silent"]:
			await _fixture()
			_fault = fault
			if fault == "silent": GameManager.current_seed = "" # Even an unset seed cannot commit before success.
			before = _state()
			var old_hall: Node = hall
			check(GameManager.enter_dungeon_from_hall(hall.hero), "TRANS-05/06/07 actual stage " + fault)
			await get_tree().process_frame
			await get_tree().process_frame
			if fault in ["hero", "world"]: await _wait_failed_request()
			if fault in ["layout", "silent"]:
				check(GameManager._hall_request_pending and get_tree().current_scene == old_hall, "TRANS-07 not initialized; Hall retained for recovery")
				if round_index == 0 and fault == "silent":
					await get_tree().create_timer(46.0).timeout # Real bounded timeout, not a success delay.
				else:
					GameManager._process(GameManager.HALL_HANDOFF_TIMEOUT + 1.0) # Controlled failure-clock injection.
				await ticks(4)
				await get_tree().process_frame
			check(not GameManager._hall_request_pending and GameManager._hall_request.is_empty() and _outcomes == [false], "TRANS-05/06/07/08 request and provisional world released " + fault)
			check(get_tree().current_scene == old_hall and _state() == before, "TRANS-11/12 failure preserves production progression " + fault)
			if fault in ["layout", "silent"]:
				check(is_instance_valid(hall.hero) and hall.is_ancestor_of(hall.hero) and hall.hero.can_process(), "TRANS-13 original hero restored for retry")
		await _fixture()
		_fault = "silent"
		check(GameManager.enter_dungeon_from_hall(hall.hero), "TRANS-09 staged run cancellation")
		await get_tree().process_frame
		await get_tree().process_frame
		var old_run: int = GameManager.run_id
		GameManager.run_id += 1
		await _wait_failed_request()
		check(not GameManager._hall_request_pending and GameManager.run_id == old_run + 1 and hall.hero.can_process(), "TRANS-09 run replacement releases only old authority")
		await _fixture()
		_fault = "silent"
		check(GameManager.enter_dungeon_from_hall(hall.hero), "TRANS-06 scene replacement during initialization")
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().current_scene = self # Actual external scene replacement; no false success.
		await _wait_failed_request()
		check(not GameManager._hall_request_pending and _outcomes == [false], "TRANS-06 scene replacement releases old request")
		if GameManager._hall_request_pending:
			print("[TRANS_DIAGNOSTIC] ", JSON.stringify({"processing": GameManager.is_processing(), "paused": get_tree().paused,
				"outcomes": _outcomes, "current": str(get_tree().current_scene), "request": str(GameManager._hall_request)}))
			GameManager._fail_hall_handoff(GameManager._hall_request.run, GameManager._hall_request.id) # Failure cleanup only.
		await _fixture()
		_fault = "silent"
		var portal: Node = hall.get_node("Props/RuneSword")
		hall.hero.global_position = portal.global_position + Vector2(0, 12)
		await ticks(4)
		before = _state()
		for cancellation in 3:
			await key(KEY_E, "interact")
			check(portal.shop != null, "CANCEL actual portal cancellation prompt")
			await choose_portal(portal.shop, false)
			check(not portal.teleporting and not GameManager._hall_request_pending and _state() == before,
				"CANCEL repeated cancel has no transition or production mutation")
		await key(KEY_E, "interact")
		check(portal.shop != null, "TRANS-13 real portal confirmation for failure")
		await choose_portal(portal.shop, true)
		for unused in 400:
			if GameManager._hall_request_pending: break
			await ticks(1)
		check(portal.teleporting and GameManager._hall_request_pending, "TRANS-13 real animation enters provisional world")
		GameManager._process(GameManager.HALL_HANDOFF_TIMEOUT + 1.0)
		await ticks(5)
		check(not portal.teleporting and hall.hero.can_process() and _outcomes == [false], "TRANS-13 failed portal restores control and retry prompt")
		_fault = ""
		await key(KEY_E, "interact")
		check(portal.shop != null, "TRANS-13 portal can reopen after failure")
		await choose_portal(portal.shop, true)
		for unused in 500:
			if get_tree().current_scene.scene_file_path == GameManager.DUNGEON_SCENE: break
			await ticks(1)
		await ticks(5)
		var world := get_tree().current_scene
		check(world.scene_file_path == GameManager.DUNGEON_SCENE and world.get_node("TileMap").entities_ready \
			and GameManager.current_level == 1 and _outcomes == [false, true] and _stats.size() == 1, "TRANS-01/13 retry commits once after actual initialization")
		var actor: CharacterBody2D = world.get_node("TileMap").the_player
		var position_before: Vector2 = actor.position
		Input.action_press("move_right")
		await ticks(4)
		Input.action_release("move_right")
		check(actor.position.distance_to(position_before) > 1 and not GameManager.current_recording_frames.is_empty(), "TRANS-15 production movement/recording after retry")
		check(not GameManager._hall_request_pending and GameManager._hall_request.is_empty() and get_tree().get_nodes_in_group("training_player").is_empty(), "TRANS-14 no retained transition/practice ownership")
		hall = null
		world.free()
		await ticks(55)
		check(get_tree().root.find_children("PortalFlash", "", true, false).is_empty(), "TRANS-14 portal flash cleanup")
		print("[TRACE] transition round=", round_index, " failure/timeout/stale/run/scene/portal retry verified")
	get_tree().node_added.disconnect(_inject)
	GameManager.stats_updated.disconnect(_stats_changed)
	GameManager.hall_dungeon_handoff.disconnect(_handoff)
	print("[TRACE] transition rounds=5 all failure/retry/ownership contracts verified")
	finish("[TUTORIAL_TRANSITION_SAFETY_COMPLETE]")
