extends Control

const UITheme = preload("res://Scene/UI/UITheme.gd")

var summary_label: Label = null

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
		title_lbl.text = "THỢ SĂN GỤC NGÃ"
		title_lbl.add_theme_font_size_override("font_size", 48)
		title_lbl.add_theme_color_override("font_color", Color(0.98, 0.28, 0.30))

	var vbox := $MarginContainer/HBoxContainer/VBoxContainer as VBoxContainer
	if vbox == null:
		return
	vbox.add_theme_constant_override("separation", 10)

	var summary_panel := PanelContainer.new()
	summary_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.09, 0.08, 0.14, 0.96), Color(0.92, 0.42, 0.42), 2, 4, 14, 8))
	vbox.add_child(summary_panel)
	vbox.move_child(summary_panel, 1)

	var sum_hbox := HBoxContainer.new()
	sum_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	sum_hbox.add_theme_constant_override("separation", 8)
	sum_hbox.add_child(UITheme.create_icon_rect("skull", 20))
	summary_label = Label.new()
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.add_theme_font_size_override("font_size", 13)
	summary_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.55))
	summary_label.add_theme_color_override("font_outline_color", Color.BLACK)
	summary_label.add_theme_constant_override("outline_size", 3)
	sum_hbox.add_child(summary_label)
	summary_panel.add_child(sum_hbox)

	var replay_same_seed_btn := UITheme.create_button("Chơi lại cùng Seed này", "sword_royal", Vector2(260, 36), Color(0.95, 0.76, 0.30), Color(0.16, 0.15, 0.24, 0.96), 13)
	replay_same_seed_btn.pressed.connect(func():
		get_tree().paused = false
		if get_node_or_null("/root/GameManager") != null:
			GameManager.replay_seed_run(GameManager.current_seed, GameManager.selected_character_index)
		else:
			get_tree().reload_current_scene()
	)
	vbox.add_child(replay_same_seed_btn)

	var watch_replay_btn := UITheme.create_button("Phát lại Replay ván vừa rồi (60Hz)", "play", Vector2(260, 36), Color(0.76, 0.48, 0.98), Color(0.18, 0.12, 0.26, 0.96), 12)
	watch_replay_btn.pressed.connect(func():
		get_tree().paused = false
		if get_node_or_null("/root/GameManager") != null:
			GameManager.start_action_replay()
	)
	vbox.add_child(watch_replay_btn)

	var save_seed_btn := UITheme.create_button("Lưu & Sao chép Seed", "chest", Vector2(260, 34), Color(0.48, 0.80, 0.98), Color(0.12, 0.16, 0.24, 0.96), 12)
	save_seed_btn.pressed.connect(func():
		if get_node_or_null("/root/GameManager") != null:
			DisplayServer.clipboard_set(GameManager.current_seed)
			GameManager.save_seed_entry(GameManager.current_seed)
			summary_label.text = "Đã lưu & sao chép Seed: " + GameManager.current_seed
	)
	vbox.add_child(save_seed_btn)

	var retry_btn := vbox.get_node_or_null("Retry_button") as Button
	if retry_btn != null:
		retry_btn.text = "Chọn lại Thợ Săn / Seed"
		retry_btn.custom_minimum_size = Vector2(260, 34)
		UITheme.style_button(retry_btn, "hero", Color(0.55, 0.88, 0.68), Color(0.12, 0.18, 0.16, 0.96), 13)

	var menu_btn := UITheme.create_button("Về Sảnh Chính", "arrow_left", Vector2(260, 34), Color(0.68, 0.75, 0.88), Color(0.13, 0.15, 0.22, 0.96), 12)
	menu_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Menu/main menu/main_menu.tscn")
	)
	vbox.add_child(menu_btn)

	var exit_btn := vbox.get_node_or_null("Exit_button") as Button
	if exit_btn != null:
		exit_btn.text = "Thoát Game"
		exit_btn.custom_minimum_size = Vector2(260, 34)
		UITheme.style_button(exit_btn, "close", Color(0.85, 0.38, 0.38), Color(0.20, 0.11, 0.13, 0.96), 12)
		vbox.move_child(exit_btn, vbox.get_child_count() - 1)

func pause() -> void:
	var pause_menu := get_node_or_null("../pause_menu")
	if pause_menu != null:
		pause_menu.hide()
	if summary_label != null and get_node_or_null("/root/GameManager") != null:
		summary_label.text = "Seed: %s\nĐạt Tầng: %d   |   Hạ gục: %d quái" % [
			GameManager.current_seed, GameManager.current_level, GameManager.enemies_killed
		]
	show()
	get_tree().paused = true
	$MarginContainer/HBoxContainer/VBoxContainer/Retry_button.grab_focus()

func _on_retry_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scene/UI/CharacterSelect.tscn")

func _on_exit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
