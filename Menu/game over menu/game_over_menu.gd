extends Control

const UITheme = preload("res://Scene/UI/UITheme.gd")

var summary_label: Label = null
var save_status_label: Label
var retry_save_button: Button
var completion_actions: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("game_over_menu")
	_build_extra_gameover_controls()
	hide()

func _build_extra_gameover_controls() -> void:
	var bg_rect := get_node_or_null("ColorRect") as ColorRect
	if bg_rect != null:
		bg_rect.color = Color(0.06, 0.02, 0.04, 0.82)

	var top_vbox := get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	if top_vbox != null:
		top_vbox.add_theme_constant_override("separation", 36)

	var title_lbl := get_node_or_null("MarginContainer/VBoxContainer/Label") as Label
	if title_lbl != null:
		title_lbl.text = "CHAMPION FALLEN"
		UITheme.style_title_label(title_lbl, 48, Color(0.98, 0.28, 0.30))

	var vbox := $MarginContainer/HBoxContainer/VBoxContainer as VBoxContainer
	if vbox == null:
		return
	vbox.add_theme_constant_override("separation", 10)

	var summary_panel := PanelContainer.new()
	summary_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_GOLD_BORDER, 2, 4, 14, 8))
	vbox.add_child(summary_panel)
	vbox.move_child(summary_panel, 1)

	var sum_hbox := HBoxContainer.new()
	sum_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_label = Label.new()
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_header_label(summary_label, 14, UITheme.COLOR_TEXT_GOLD)
	sum_hbox.add_child(summary_label)
	summary_panel.add_child(sum_hbox)
	save_status_label = Label.new()
	save_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(save_status_label)
	retry_save_button = UITheme.create_button("RETRY SAVING THIS RUN", "", Vector2(260, 38), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 14)
	retry_save_button.pressed.connect(func():
		retry_save_button.disabled = true
		_refresh_completion(GameManager.retry_pending_completion())
	)
	vbox.add_child(retry_save_button)

	var replay_same_seed_btn := UITheme.create_button("RETRY CURRENT SEED", "", Vector2(260, 38), UITheme.COLOR_GOLD_BORDER_HOVER, UITheme.COLOR_BG_DARK, 14)
	replay_same_seed_btn.pressed.connect(func():
		get_tree().paused = false
		if get_node_or_null("/root/GameManager") != null:
			GameManager.replay_seed_run(GameManager.current_seed, GameManager.selected_character_index)
		else:
			get_tree().reload_current_scene()
	)
	vbox.add_child(replay_same_seed_btn)
	completion_actions.append(replay_same_seed_btn)

	var watch_replay_btn := UITheme.create_button("WATCH COMBAT REPLAY", "", Vector2(260, 38), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 13)
	watch_replay_btn.pressed.connect(func():
		get_tree().paused = false
		if get_node_or_null("/root/GameManager") != null:
			GameManager.start_action_replay()
	)
	vbox.add_child(watch_replay_btn)
	completion_actions.append(watch_replay_btn)

	var save_seed_btn := UITheme.create_button("RECORD SEED TO CHRONICLES", "", Vector2(260, 36), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 13)
	save_seed_btn.pressed.connect(func():
		if get_node_or_null("/root/GameManager") != null:
			DisplayServer.clipboard_set(GameManager.current_seed)
			GameManager.save_seed_entry(GameManager.current_seed)
			summary_label.text = "Dungeon seed recorded: " + GameManager.current_seed
	)
	vbox.add_child(save_seed_btn)
	completion_actions.append(save_seed_btn)

	var retry_btn := vbox.get_node_or_null("Retry_button") as Button
	if retry_btn != null:
		completion_actions.append(retry_btn)
		retry_btn.text = "SELECT NEW CHAMPION"
		retry_btn.custom_minimum_size = Vector2(260, 36)
		UITheme.style_button(retry_btn, "", UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 13)

	var menu_btn := UITheme.create_button("RETURN TO MAIN MENU", "", Vector2(260, 36), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 13)
	menu_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Menu/main menu/main_menu.tscn")
	)
	vbox.add_child(menu_btn)
	completion_actions.append(menu_btn)

	var exit_btn := vbox.get_node_or_null("Exit_button") as Button
	if exit_btn != null:
		exit_btn.text = "ABANDON EXPEDITION & QUIT"
		exit_btn.custom_minimum_size = Vector2(260, 36)
		UITheme.style_danger_button(exit_btn, "", 13)
		vbox.move_child(exit_btn, vbox.get_child_count() - 1)

func _refresh_completion(result: Dictionary) -> void:
	var status := String(result.get("status", "UNAVAILABLE"))
	var saved := status in ["COMMITTED", "DUPLICATE"]
	match status:
		"COMMITTED", "DUPLICATE":
			save_status_label.text = "RUN SAVED"
		"SAVE_FAILED":
			save_status_label.text = "PROGRESS NOT SAVED. Retry saving before leaving.\nQuitting loses this pending run."
		"STORAGE_UNCERTAIN":
			save_status_label.text = "SAVE NOT CONFIRMED. Check storage with Retry Saving.\nKeep this game open until resolved."
		_:
			save_status_label.text = "SAVE NOT CONFIRMED (%s)." % status
	retry_save_button.visible = status in ["SAVE_FAILED", "STORAGE_UNCERTAIN"]
	retry_save_button.disabled = false
	for action in completion_actions:
		action.disabled = not saved

func pause(completion_result: Dictionary = {}) -> void:
	var pause_menu := get_node_or_null("../pause_menu")
	if pause_menu != null:
		pause_menu.hide()
	if summary_label != null and get_node_or_null("/root/GameManager") != null:
		summary_label.text = "Seed: %s\nFloor Reached: %d   •   Enemies Slain: %d" % [
			GameManager.current_seed, GameManager.current_level, GameManager.enemies_killed
		]
	_refresh_completion(GameManager.last_completion_result if completion_result.is_empty() else completion_result)
	show()
	get_tree().paused = true
	if retry_save_button.visible:
		retry_save_button.grab_focus()
	else:
		$MarginContainer/HBoxContainer/VBoxContainer/Retry_button.grab_focus()

func _on_retry_button_pressed() -> void:
	if not GameManager.can_start_new_run():
		return
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scene/UI/CharacterSelect.tscn")

func _on_exit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
