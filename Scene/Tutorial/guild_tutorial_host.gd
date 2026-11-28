extends Node
## One opt-in owner per real Guild Hall visit. No autoload or run reset.
const Session = preload("res://Scene/Tutorial/tutorial_session.gd")
const Flow = preload("res://Scene/Tutorial/tutorial_flow.gd")
const UI = preload("res://Scene/Tutorial/tutorial_ui.gd")
const Persistence = preload("res://Scene/Tutorial/tutorial_persistence.gd")
const Adapter = preload("res://Scene/Tutorial/tutorial_input_adapter.gd")
const Lease = preload("res://Scene/Tutorial/tutorial_input_lease.gd")
const Presentation = preload("res://Scene/Tutorial/tutorial_arena_presentation.gd")
const Observer = preload("res://Scene/Tutorial/tutorial_dungeon_observer.gd")
const ReleaseGuard = preload("res://Scene/Tutorial/tutorial_release_guard.gd")
var hall: Node2D
var production_hero: CharacterBody2D
var hero_index: int
var session: RefCounted
var flow: Node
var ui: CanvasLayer
var persistence: RefCounted
var adapter := Adapter.new()
var lease: RefCounted
var observer: Node
var prompt_layer: CanvasLayer
var prompt_button: Button
var entry_hint: Label
var portal_marker: Polygon2D
var mode := "waiting"
var invitation_shown := false
var _restarting := false
var _armed := false
var _neutral_ticks := 0
var _focused := true
var _closing := false
var _pointer_at := Vector2.INF

func configure(scene: Node2D, hero: CharacterBody2D, index: int, save: RefCounted = null) -> void:
	hall = scene
	production_hero = hero
	hero_index = index
	persistence = save if save != null else Persistence.new()
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100
	_build_prompt()
	get_window().focus_exited.connect(_focus_lost)
	get_window().focus_entered.connect(_focus_returned)

func _valid_hero() -> bool:
	return is_instance_valid(hall) and not hall.is_queued_for_deletion() and is_instance_valid(production_hero) \
		and not production_hero.is_queued_for_deletion() and production_hero.is_inside_tree() \
		and hall.is_ancestor_of(production_hero) and hall.hero == production_hero and not production_hero.is_dead \
		and not production_hero.is_training() and not GameManager.is_replaying

func _available() -> bool:
	if not _valid_hero() or get_tree().paused or GameManager.hall_selecting or not _focused:
		return false
	if production_hero.get("intro_active") == true:
		return false # Yugi's introductory animation still owns gameplay input
	if hall.get_node_or_null("HeroSelect") != null or hall.get_node_or_null("HeroSelectDone") != null \
		or hall.get_node_or_null("StartFade") != null:
		return false
	for node in hall.find_children("*", "", true, false):
		if node == self or is_ancestor_of(node): continue
		# External effects can own unbound SceneTreeTimers. Let them finish before
		# acquiring input, rather than expiring a frozen production projectile.
		if node != production_hero and not production_hero.is_ancestor_of(node) and node.get_script() != null:
			var path: String = node.get_script().resource_path
			if path.begins_with("res://Scene/Projectiles/") or Flow.Combat.ALLOWED_EFFECTS.has(path.get_file()) \
				or node.get("caster") == production_hero:
				return false
		if node.get("inventory_modal") is Control and node.inventory_modal.is_visible_in_tree():
			return false
		if node.get("teleporting") == true or node.get("shop") != null:
			return false
		if node is Control and node.is_visible_in_tree() and node.name in ["pause_menu", "game_over_menu"]:
			return false
		if node.name == "InventoryModal" and node is CanvasItem and node.is_visible_in_tree():
			return false
	return true

func _build_prompt() -> void:
	prompt_layer = CanvasLayer.new()
	prompt_layer.layer = 12
	add_child(prompt_layer)
	prompt_button = Button.new()
	prompt_button.text = "Adventurer Training"
	prompt_button.tooltip_text = "Finish active effects and close other screens before starting training."
	prompt_button.theme = UI.Pixel.make_theme(load("res://Assets/UI/Shop/forge5vn.fnt"))
	prompt_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	prompt_button.offset_left = 16
	prompt_button.offset_top = -44
	prompt_button.offset_right = 200
	prompt_button.offset_bottom = -16
	prompt_layer.add_child(prompt_button)
	prompt_button.pressed.connect(open_invitation)
	entry_hint = Label.new()
	entry_hint.theme = prompt_button.theme
	entry_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	entry_hint.offset_left = -400
	entry_hint.offset_right = 0
	entry_hint.offset_top = 82
	entry_hint.offset_bottom = 126
	entry_hint.scale = Vector2(2, 2)
	entry_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry_hint.add_theme_font_size_override("font_size", 14)
	entry_hint.add_theme_color_override("font_color", Color("f4d58c"))
	entry_hint.add_theme_color_override("font_outline_color", Color("171219"))
	entry_hint.add_theme_constant_override("outline_size", 4)
	var hint_panel := StyleBoxFlat.new()
	hint_panel.bg_color = Color(0.06, 0.04, 0.07, 0.94)
	hint_panel.border_color = Color("b89a52")
	hint_panel.set_border_width_all(1)
	hint_panel.content_margin_left = 8
	hint_panel.content_margin_right = 8
	hint_panel.content_margin_top = 5
	hint_panel.content_margin_bottom = 5
	entry_hint.add_theme_stylebox_override("normal", hint_panel)
	prompt_layer.add_child(entry_hint)
	entry_hint.hide()
	portal_marker = Polygon2D.new()
	portal_marker.polygon = PackedVector2Array([Vector2(-7, -10), Vector2(7, -10), Vector2(0, 0)])
	portal_marker.color = Color("f4d58c")
	portal_marker.z_index = 100
	add_child(portal_marker)
	var portal := hall.get_node_or_null("Props/RuneSword")
	if portal != null: portal_marker.position = hall.to_local(portal.global_position) + Vector2(0, -40)
	portal_marker.hide()
	prompt_layer.hide()

func _process(_delta: float) -> void:
	if _closing: return
	entry_hint.visible = mode == "entry"
	portal_marker.visible = mode == "entry"
	if not _valid_hero():
		cancel()
		return
	if mode == "waiting" and _available():
		mode = "hall"
		prompt_layer.show()
		if not invitation_shown and not persistence.completed:
			open_invitation()
	if mode in ["hall", "entry"]:
		prompt_button.disabled = not _available()
	if mode == "training" and get_tree().paused:
		_pause("The game was paused by another screen. Resume it before continuing.")
	_update_aim()

func _update_aim() -> void:
	if mode != "training" or not _armed or not is_instance_valid(flow) or not is_instance_valid(flow.active_context) or not is_instance_valid(ui): return
	var point: Vector2 = _pointer_at if _pointer_at.is_finite() else get_viewport().get_mouse_position()
	var at: Vector2 = ui.arena_point(point)
	if at.is_finite():
		var actor: CharacterBody2D = flow.active_context.hero
		if is_instance_valid(actor):
			var world_point: Vector2 = flow.active_context.viewport.canvas_transform.affine_inverse() * at
			actor.training_aim = world_point - actor.global_position

func open_invitation() -> void:
	if not mode in ["hall", "entry"] or not _available():
		return
	invitation_shown = true
	_suspend()
	_new_ui()
	mode = "consent"
	ui.show_modal("consent", "Welcome, Adventurer", "Learn movement, combat, equipment and survival before entering the dungeon.\nPractice is optional and gives no rewards.", "Start Tutorial", "Not Now")
	print("[TRACE] tutorial consent; production input suspended")

func _suspend() -> void:
	if lease != null:
		return
	production_hero.clear_training_input()
	lease = Lease.new()
	lease.acquire(hall, self)
	prompt_layer.hide()

func _new_ui() -> void:
	if is_instance_valid(ui): return
	ui = UI.new()
	ui.host = self
	add_child(ui)
	ui.start_requested.connect(start_tutorial)
	ui.declined.connect(decline)
	ui.control_requested.connect(_control)
	ui.destroyed.connect(_ui_destroyed)
	ui.arena.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.arena.gui_input.connect(_arena_input)

func start_tutorial() -> void:
	if mode != "consent" or not _valid_hero(): return
	_dispose_observer()
	if session != null and session.get_state() == Session.State.ACTIVE:
		_restarting = true
		session.cancel_tutorial()
		_restarting = false
	if is_instance_valid(flow): flow.free()
	session = Session.new()
	session.step_changed.connect(_step_changed)
	session.progress_changed.connect(_progress_changed)
	session.tutorial_skipped.connect(_terminal)
	session.tutorial_cancelled.connect(_terminal)
	session.start_tutorial(hero_index)
	flow = Flow.new()
	flow.input_enabled = false
	flow.context_changed.connect(_context_changed)
	add_child(flow)
	if not flow.bind(session):
		cancel()
		return
	mode = "training"
	_wait_for_release()
	print("[TRACE] tutorial start; exclusive practice input; hero=", hero_index)

func _context_changed(value: Node) -> void:
	adapter.clear()
	_armed = false
	_neutral_ticks = 0
	if is_instance_valid(ui): ui.bind_context(value)
	if value == null: return
	value.input_adapter = adapter
	_disable_native_input(value.world)
	value.world.child_entered_tree.connect(_disable_native_input)
	var presentation := Presentation.new()
	value.world.add_child(presentation)
	presentation.configure(value)
	value.set_input_enabled(false)
	print("[TRACE] tutorial viewport/hero/inventory rebound")

func _disable_native_input(node: Node) -> void:
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	node.set_process_unhandled_key_input(false)
	for child in node.get_children(): _disable_native_input(child)

func _wait_for_release() -> void:
	adapter.clear()
	_armed = false
	_neutral_ticks = 0
	if is_instance_valid(flow): flow.set_input_enabled(false)
	if is_instance_valid(ui):
		ui.show_modal("release", "Release controls", "Release held keys and mouse buttons to continue safely.", "", "")

func _physics_process(_delta: float) -> void:
	if mode == "training" and get_tree().paused:
		_pause("The game was paused by another screen. Resume it before continuing.")
	_update_aim()
	if mode in ["training", "releasing"] and not _armed:
		_neutral_ticks = _neutral_ticks + 1 if Adapter.neutral() and _focused and not get_tree().paused else 0
		if _neutral_ticks < 2: return
		if mode == "releasing":
			_restore()
		else:
			_armed = true
			adapter.enabled = true
			if is_instance_valid(flow): flow.set_input_enabled(true)
			if is_instance_valid(ui): ui.modal.hide()

func _input(event: InputEvent) -> void:
	if lease == null: return
	if event is InputEventMouse:
		_pointer_at = event.position
		_update_aim()
	if event.is_action_pressed("esc") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if mode == "consent": decline()
		elif mode == "training": _pause("Training paused. Your adventure is waiting in the hall.")
		elif mode in ["pause", "confirm"]: _control("resume")
		return
	# Releases must clear world holds even when the pointer is over inventory/UI.
	if event is InputEventMouseButton and not event.pressed:
		var held: bool = adapter.mouse_actions.get(&"attack" if event.button_index == MOUSE_BUTTON_LEFT else &"skill_2", false)
		adapter.observe(event)
		if held and mode == "training" and _armed:
			_dispatch(event)
	if mode != "training" or not _armed:
		if event is InputEventKey and not event.is_action("ui_accept") and not event.is_action("ui_left") and not event.is_action("ui_right") and not event.is_action("ui_focus_next"):
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if lease == null: return
	if mode == "training" and _armed and not event is InputEventMouseButton:
		adapter.observe(event)
		_dispatch(event)
	get_viewport().set_input_as_handled()

func _arena_input(event: InputEvent) -> void:
	if mode != "training" or not _armed or ui.modal.visible: return
	if event is InputEventMouseButton:
		if not ui.arena_point(_pointer_at).is_finite(): return
		adapter.observe(event)
		if event.pressed: _dispatch(event)
		ui.arena.accept_event()

func _dispatch(event: InputEvent) -> void:
	if not is_instance_valid(flow) or not is_instance_valid(flow.active_context) or not flow.active_context.live(): return
	var ctx: Node = flow.active_context
	ctx.hero._unhandled_input(event)
	if event.is_action_pressed("interact"):
		var pickup_event := InputEventKey.new()
		pickup_event.keycode = KEY_E # WorldItem's existing gameplay handler
		pickup_event.pressed = true
		for item in ctx.world.get_children():
			if item.get("training_context") == ctx and item.get("is_player_near") == true \
				and item.get("player_node") == ctx.hero and item.has_method("_is_nearest_pickup_candidate") \
				and item._is_nearest_pickup_candidate():
				item._unhandled_input(pickup_event)
				break # one E chooses one source, even after that source queues free

func _pause(message: String) -> void:
	mode = "pause"
	adapter.clear()
	_armed = false
	if is_instance_valid(flow): flow.set_input_enabled(false)
	if is_instance_valid(ui): ui.show_modal("resume", "Training paused", message, "Resume", "Skip Tutorial", "skip")

func _focus_lost() -> void:
	_focused = false
	if mode == "training": _pause("Window focus was lost. Release controls, then resume when ready.")

func _focus_returned() -> void:
	_focused = true

func _control(action: String) -> void:
	match action:
		"skip", "restart":
			if mode == "confirm":
				if action == "skip": session.skip_tutorial()
				else: restart()
			elif mode in ["training", "pause"]:
				_pause("")
				mode = "confirm"
				ui.show_modal(action, "Skip training?" if action == "skip" else "Restart training?", "Your original hero is preserved. Restart creates a fresh practice arena; no progress or practice items carry over.", "Skip Tutorial" if action == "skip" else "Restart Tutorial")
		"pause":
			if mode == "training": _pause("Training paused. Resume, skip or restart at any time.")
		"resume":
			if mode in ["pause", "confirm"] and _focused and not get_tree().paused:
				mode = "training"
				_wait_for_release()

func restart() -> void:
	if session == null or lease == null: return
	_restarting = true
	adapter.clear()
	session.restart_tutorial(hero_index)
	_restarting = false
	mode = "training"
	_wait_for_release()
	print("[TRACE] tutorial restart; new generation; original run preserved")

func decline() -> void:
	if mode == "consent": _release_to_hall()

func _step_changed(_id: String, step: int) -> void:
	print("[TRACE] tutorial UI step=", step)
	if step == 7:
		adapter.clear()
		call_deferred("_finish_practice", session.get_session_id())

func _progress_changed(_id: String, _step: int, _count: int, _required: int) -> void:
	if is_instance_valid(ui): ui.notify("Objective progress confirmed by gameplay.")

func _finish_practice(id: String) -> void:
	if session.get_session_id() != id or session.get_state() != Session.State.ACTIVE or session.get_current_step() != 7: return
	observer = Observer.new()
	get_tree().root.add_child(observer)
	if not observer.bind(session, production_hero, hall, persistence):
		observer.queue_free()
		observer = null
		cancel()
		return
	_release_to_hall()
	print("[TRACE] tutorial practice cleanup; return to original hero; ACTIVE at portal")

func _terminal(_id: String) -> void:
	if not _restarting:
		adapter.clear()
		call_deferred("_release_to_hall")

func _release_to_hall() -> void:
	if _closing: return
	adapter.clear()
	if is_instance_valid(flow): flow.free()
	flow = null
	if lease == null:
		if session != null and session.get_state() != Session.State.ACTIVE:
			mode = "hall"
			prompt_button.text = "Adventurer Training"
		return
	mode = "releasing"
	_wait_for_release()

func _restore() -> void:
	if is_instance_valid(production_hero) and not production_hero.is_queued_for_deletion():
		production_hero.clear_training_input()
	if lease != null:
		lease.release()
		lease = null
	mode = "entry" if session != null and session.get_state() == Session.State.ACTIVE and session.get_current_step() == 7 else "hall"
	if is_instance_valid(ui): ui.queue_free()
	ui = null
	prompt_layer.show()
	prompt_button.text = "Train again" if mode == "entry" else "Adventurer Training"
	entry_hint.text = "Practice complete! Follow the gold marker to the Rune Portal.\nStand beside the sword, press %s, then confirm when ready." % UI.Content.binding(&"interact")
	print("[TRACE] tutorial production input restored after neutral controls")

func _ui_destroyed() -> void:
	ui = null
	# Child exit notifications also run during parent teardown. Never remove
	# siblings or grab focus while the tree is locked adding/removing children.
	if not _closing:
		call_deferred("_cancel_if_ui_missing")

func _cancel_if_ui_missing() -> void:
	if is_inside_tree() and not _closing and not is_instance_valid(ui) and lease != null and mode != "releasing":
		cancel()

func _dispose_observer() -> void:
	# A root ticket can outlive the hall; queue deletion safely even when this
	# callback runs while the root is already removing the hall's children.
	if is_instance_valid(observer): observer.queue_free()
	observer = null

func cancel() -> void:
	if session != null and session.get_state() == Session.State.ACTIVE: session.cancel_tutorial()
	_dispose_observer()
	_release_to_hall()
	if not _valid_hero(): queue_free()

func _exit_tree() -> void:
	_closing = true
	adapter.clear()
	if is_instance_valid(flow): flow.free()
	var keep_ticket: bool = is_instance_valid(observer) and observer.pending
	if not keep_ticket:
		_dispose_observer()
		if session != null and session.get_state() == Session.State.ACTIVE: session.cancel_tutorial()
	if lease != null:
		if is_instance_valid(hall) and not hall.is_queued_for_deletion() and not Adapter.neutral():
			var guard := ReleaseGuard.new()
			guard.lease = lease
			get_tree().root.add_child.call_deferred(guard)
		else:
			lease.release()
		lease = null
