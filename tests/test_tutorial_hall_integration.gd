extends "res://tests/tutorial_hall_test_support.gd"

func _ready() -> void:
	await ticks(2)
	await new_hall(2, false)
	check(hall.hero.can_process(), "Standalone hero active before host")
	hall.enable_tutorial_feature()
	await ticks(3)
	host = hall.tutorial_host
	check(host.mode == "consent", "Explicit fixture activation")
	host.ui.secondary.pressed.emit()
	await ticks(5)
	check(host.mode == "hall" and hall.hero.can_process() and host.session == null, "Not Now restores gameplay; no session")
	await ticks(15)
	check(host.mode == "hall", "No duplicate invitation within visit")
	var npc: Node = hall.get_node("Props/Blacksmith")
	hall.hero.global_position = npc.global_position + Vector2(0, 12)
	await ticks(5)
	check(npc.can_open(), "Shop usable after declining")
	var shop: CanvasLayer = npc.open_shop()
	check(shop != null and get_tree().paused, "Normal shop opens")
	shop.close()
	await ticks(3)
	host.persistence.mark_completed()
	host.open_invitation()
	check(host.mode == "consent", "Completed user can manually replay")
	await start()
	_baseline.clear()
	host.restart()
	await ticks(8)
	check(host.persistence.completed, "Replay restart preserves prior completion")
	host.cancel()
	await ticks(8)
	check(host.persistence.completed and hall.hero.can_process(), "Replay cancellation preserves prior completion")
	for index in 8:
		await new_hall(index)
		check(hall.hero.process_mode == Node.PROCESS_MODE_DISABLED, "Consent owns input %d" % index)
		await start()
		var id: String = host.session.get_session_id()
		host.start_tutorial()
		check(host.session.get_session_id() == id and get_tree().get_nodes_in_group("training_player").size() == 1, "Start is single-session %d" % index)
		_baseline.clear()
		host.session.skip_tutorial()
		await ticks(8)
		check(hall.hero.can_process() and host.session.get_state() == Session.State.SKIPPED and not host.persistence.completed,
			"Skip restores original; no completion %d" % index)
		print("[TRACE] hall hero=", index, " consent/start/skip/restore verified")
	# Exercise the actual GameManager activation contract, preserving this test root.
	hall.free()
	hall = null
	get_tree().current_scene = null
	Save.memory_completed = false
	GameManager.start_run_in_hall("TUTORIAL4")
	await ticks(6)
	hall = get_tree().current_scene
	check(hall != null and not hall.tutorial_feature_enabled and hall.tutorial_host == null,
		"Unopted fixture/API entry keeps legacy hall behavior")
	hall.free()
	hall = null
	get_tree().current_scene = null
	GameManager.start_run_in_hall("TUTORIAL4", true)
	await ticks(6)
	hall = get_tree().current_scene
	check(hall != null and hall.tutorial_feature_enabled and hall.hero == null, "Production start arms only selected hall visit")
	var panel: CanvasLayer = hall.get_node("HeroSelect").open_panel(0)
	panel.start()
	await ticks(40)
	host = hall.tutorial_host
	check(host != null and host.mode == "hall", "Real start_run -> selection; completed user not auto prompted")
	host.open_invitation()
	check(host.mode == "consent", "Real production visit still offers manual replay")
	var prior_hero: Node = hall.hero
	var prior_host: WeakRef = weakref(host)
	var replacement: Node2D = GameManager.CHARACTER_SCENES[0].instantiate()
	hall.place_hero(replacement)
	await ticks(10)
	check(prior_host.get_ref() == null and replacement.can_process() and not prior_hero.can_process() \
		and get_tree().get_nodes_in_group("training_player").is_empty(), "HALL-12 replacement cleans host without restoring old hero input")
	finish("[TUTORIAL_HALL_INTEGRATION_COMPLETE]")
