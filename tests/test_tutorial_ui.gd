extends "res://tests/tutorial_hall_test_support.gd"
const Content = preload("res://Scene/Tutorial/tutorial_content.gd")

func _ready() -> void:
	await ticks(2)
	await new_hall(2)
	await start()
	for resolution in [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1920, 1080)]:
		get_window().size = resolution
		await get_tree().process_frame
		host.ui._fit()
		await capture("layout_%dx%d" % [resolution.x, resolution.y])
		var window: Control = host.ui.window
		var viewport_rect := get_viewport().get_visible_rect()
		check(viewport_rect.encloses(Rect2(window.position, window.size * window.scale)), "UI-11 frame fits %s" % resolution)
		var point := Vector2(320, 188)
		var mapped: Vector2 = host.ui.arena_point(host.ui.arena.get_global_transform_with_canvas() * point)
		check(mapped.is_equal_approx(point), "INPUT-08/09 mouse mapping at %s" % resolution)
		check(not host.ui.arena_point(window.position).is_finite(), "Letterbox/outside arena rejects world click %s" % resolution)
		for slot in host.ui.bag_slots + host.ui.equipment_slots:
			check(Rect2(Vector2.ZERO, host.ui.SIZE).encloses(Rect2(slot.position, slot.size)), "UI-12 inventory slot within frame")
		check(not Rect2(host.ui.arena.position, host.ui.arena.size).intersects(Rect2(host.ui.objective.position, host.ui.objective.size)),
			"Objective does not cover practice target %s" % resolution)
	get_window().size = Vector2i(1280, 720)
	await ticks(4)
	check(host.ui.bag_slots[0].current_item == context.hero.inventory.bag[0] and host.ui.status.text.contains("HP"), "UI-04/05 private status and inventory")
	host.ui._show_tooltip(host.ui.bag_slots[0])
	await ticks(3)
	check(host.ui.tooltip_panel.visible and Rect2(Vector2.ZERO, host.ui.SIZE).encloses(Rect2(host.ui.tooltip_panel.position, host.ui.tooltip_panel.size)),
		"UI tooltip stays within the tutorial frame")
	check(host.ui.bag_slots[0]._get_tooltip(Vector2.ZERO).is_empty(), "Tutorial slots cannot open native tooltip windows")
	host.ui._drop(0)
	host.ui._refresh_inventory()
	check(not host.ui.tooltip_panel.visible, "Tooltip closes immediately when its item leaves the slot")
	var actual_binding := InputMap.action_get_events("skill_1").duplicate()
	InputMap.action_erase_events("skill_1")
	var remap := InputEventKey.new()
	remap.physical_keycode = KEY_T
	InputMap.action_add_event("skill_1", remap)
	check(Content.instruction(2, 0).begins_with("T:"), "UI-03 instructions read current InputMap")
	InputMap.action_erase_events("skill_1")
	for event in actual_binding: InputMap.action_add_event("skill_1", event)
	for index in 8:
		check(Content.instruction(2, index).contains(Content.SKILLS[index]), "UI-03 distinct skill profile %d" % index)
	context.feedback(&"show_toast", ["Local practice feedback"])
	check(host.ui.feedback_label.text == "Local practice feedback", "UI-06 local feedback delivered")
	# Pointer clicks on UI cannot arm Input polling, even with global attack held.
	var actions: int = context._serial
	var mouse := InputEventMouseButton.new()
	mouse.position = host.ui.bag_slots[15].get_global_rect().get_center()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	Input.action_press("attack")
	get_viewport().push_input(mouse, true)
	await ticks(8)
	Input.action_release("attack")
	mouse = mouse.duplicate()
	mouse.pressed = false
	get_viewport().push_input(mouse, true)
	check(context._serial == actions, "INPUT-06 inventory click does not become world attack")
	_baseline.clear()
	var old: WeakRef = weakref(context.world)
	var id: String = host.session.get_session_id()
	host._control("restart")
	check(host.mode == "confirm", "Restart asks for explicit confirmation")
	host.ui.primary.pressed.emit()
	await ticks(10)
	context = host.flow.active_context
	check(old.get_ref() == null and host.session.get_session_id() != id and get_tree().get_nodes_in_group("training_player").size() == 1,
		"Restart creates exactly one clean generation")
	check(host.ui.context == context and host.ui.arena.texture != null and host.session.get_progress()[0].progress == 0,
		"Restart binds fresh private UI")
	var leased: WeakRef = weakref(host.lease)
	Input.action_press("attack")
	host.queue_free()
	await ticks(5)
	var late := Node2D.new()
	hall.add_child(late)
	check(not hall.hero.can_process() and not late.can_process(), "Host removal keeps held input leased and safely suspends late nodes")
	Input.action_release("attack")
	await ticks(8)
	check(hall.hero.can_process() and late.can_process() and leased.get_ref() == null \
		and get_tree().get_nodes_in_group("training_player").is_empty(), "Release guard disconnects and frees lease after host deletion")
	print("[TRACE] UI responsive mapping/inventory/focus/controls/local feedback verified")
	finish("[TUTORIAL_UI_COMPLETE]")
