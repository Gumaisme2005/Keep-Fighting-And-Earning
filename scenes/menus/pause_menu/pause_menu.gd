extends Control

const UITheme = preload("res://scenes/ui/ui_theme.gd")

var info_label: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_extra_pause_controls()
	hide()

func _build_extra_pause_controls() -> void:
	var bg_rect := get_node_or_null("ColorRect") as ColorRect
	if bg_rect != null:
		bg_rect.color = Color(0.03, 0.04, 0.08, 0.78)

	var top_vbox := get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	if top_vbox != null:
		top_vbox.add_theme_constant_override("separation", 40)

	var title_lbl := get_node_or_null("MarginContainer/VBoxContainer/Label") as Label
	if title_lbl != null:
		title_lbl.text = "EXPEDITION PAUSED"
		UITheme.style_title_label(title_lbl, 46, Color(1.0, 0.86, 0.35))

	var vbox := $MarginContainer/HBoxContainer/VBoxContainer as VBoxContainer
	if vbox == null:
		return
	vbox.add_theme_constant_override("separation", 10)

	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_GOLD_BORDER, 2, 4, 14, 8))
	vbox.add_child(info_panel)
	vbox.move_child(info_panel, 1)

	var info_hbox := HBoxContainer.new()
	info_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_label = Label.new()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_header_label(info_label, 14, UITheme.COLOR_TEXT_GOLD)
	info_hbox.add_child(info_label)
	info_panel.add_child(info_hbox)

	var resume_btn := vbox.get_node_or_null("Resume_button") as Button
	if resume_btn != null:
		resume_btn.text = "RESUME EXPEDITION"
		resume_btn.custom_minimum_size = Vector2(260, 38)
		UITheme.style_button(resume_btn, "", UITheme.COLOR_GOLD_BORDER_HOVER, UITheme.COLOR_BG_DARK, 14)

	var restart_btn := vbox.get_node_or_null("Restart_button") as Button
	if restart_btn != null:
		restart_btn.text = "RETRY CURRENT SEED"
		restart_btn.custom_minimum_size = Vector2(260, 38)
		UITheme.style_button(restart_btn, "", UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 14)

	var save_seed_btn := UITheme.create_button("RECORD SEED TO CHRONICLES", "", Vector2(260, 36), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 13)
	save_seed_btn.pressed.connect(func():
		if get_node_or_null("/root/GameManager") != null:
			DisplayServer.clipboard_set(GameManager.current_seed)
			GameManager.save_seed_entry(GameManager.current_seed)
			info_label.text = "Dungeon seed recorded: " + GameManager.current_seed
	)
	vbox.add_child(save_seed_btn)

	var new_seed_btn := UITheme.create_button("EMBARK ON NEW EXPEDITION", "", Vector2(260, 36), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 13)
	new_seed_btn.pressed.connect(func():
		get_tree().paused = false
		if get_node_or_null("/root/GameManager") != null:
			var s: String = GameManager.generate_random_seed()
			GameManager.replay_seed_run(s, GameManager.selected_character_index)
		else:
			get_tree().reload_current_scene()
	)
	vbox.add_child(new_seed_btn)

	var menu_btn := UITheme.create_button("RETURN TO MAIN MENU", "", Vector2(260, 36), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 13)
	menu_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/menus/main_menu/main_menu.tscn")
	)
	vbox.add_child(menu_btn)

	var exit_btn := vbox.get_node_or_null("Exit_button") as Button
	if exit_btn != null:
		exit_btn.text = "ABANDON EXPEDITION & QUIT"
		exit_btn.custom_minimum_size = Vector2(260, 36)
		UITheme.style_danger_button(exit_btn, "", 13)
		vbox.move_child(exit_btn, vbox.get_child_count() - 1)

func _unhandled_input(event: InputEvent) -> void:
	var game_over_menu := get_tree().get_first_node_in_group("game_over_menu")
	if game_over_menu != null and game_over_menu.is_visible_in_tree():
		return
	if event.is_action_pressed("esc") and not event.is_echo():
		if get_tree().paused:
			resume()
		else:
			pause()

func resume() -> void:
	get_tree().paused = false
	hide()

func pause() -> void:
	if info_label != null and get_node_or_null("/root/GameManager") != null:
		info_label.text = "Seed: %s  •  Floor: %d  •  Enemies Slain: %d" % [
			GameManager.current_seed, GameManager.current_level, GameManager.enemies_killed
		]
	show()
	get_tree().paused = true

func _on_resume_button_pressed() -> void:
	resume()

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	if get_node_or_null("/root/GameManager") != null:
		GameManager.replay_seed_run(GameManager.current_seed, GameManager.selected_character_index)
	else:
		get_tree().reload_current_scene()

func _on_exit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
