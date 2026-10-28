extends Control

const UITheme = preload("res://Scene/UI/UITheme.gd")

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
		title_lbl.text = "TẠM DỪNG CHIẾN DỊCH"
		title_lbl.add_theme_font_size_override("font_size", 46)
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))

	var vbox := $MarginContainer/HBoxContainer/VBoxContainer as VBoxContainer
	if vbox == null:
		return
	vbox.add_theme_constant_override("separation", 10)

	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.08, 0.10, 0.16, 0.95), Color(0.85, 0.68, 0.32), 2, 4, 14, 8))
	vbox.add_child(info_panel)
	vbox.move_child(info_panel, 1)

	var info_hbox := HBoxContainer.new()
	info_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_hbox.add_theme_constant_override("separation", 8)
	info_hbox.add_child(UITheme.create_icon_rect("seed", 18))
	info_label = Label.new()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 13)
	info_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50))
	info_label.add_theme_color_override("font_outline_color", Color.BLACK)
	info_label.add_theme_constant_override("outline_size", 3)
	info_hbox.add_child(info_label)
	info_panel.add_child(info_hbox)

	var resume_btn := vbox.get_node_or_null("Resume_button") as Button
	if resume_btn != null:
		resume_btn.text = "Tiếp tục chiến đấu"
		resume_btn.custom_minimum_size = Vector2(260, 36)
		UITheme.style_button(resume_btn, "play", Color(0.48, 0.88, 0.58), Color(0.12, 0.20, 0.16, 0.96), 13)

	var restart_btn := vbox.get_node_or_null("Restart_button") as Button
	if restart_btn != null:
		restart_btn.text = "Chơi lại cùng Seed"
		restart_btn.custom_minimum_size = Vector2(260, 36)
		UITheme.style_button(restart_btn, "sword", Color(0.92, 0.74, 0.32), Color(0.16, 0.15, 0.22, 0.96), 13)

	var save_seed_btn := UITheme.create_button("Lưu & Sao chép Seed", "chest", Vector2(260, 34), Color(0.52, 0.82, 0.98), Color(0.12, 0.16, 0.24, 0.96), 13)
	save_seed_btn.pressed.connect(func():
		if get_node_or_null("/root/GameManager") != null:
			DisplayServer.clipboard_set(GameManager.current_seed)
			GameManager.save_seed_entry(GameManager.current_seed)
			info_label.text = "Đã lưu & sao chép Seed: " + GameManager.current_seed
	)
	vbox.add_child(save_seed_btn)

	var new_seed_btn := UITheme.create_button("Run Mới (Đổi Seed Ngẫu Nhiên)", "crystal", Vector2(260, 34), Color(0.75, 0.55, 0.98), Color(0.16, 0.12, 0.24, 0.96), 13)
	new_seed_btn.pressed.connect(func():
		get_tree().paused = false
		if get_node_or_null("/root/GameManager") != null:
			var s := GameManager.generate_random_seed()
			GameManager.replay_seed_run(s, GameManager.selected_character_index)
		else:
			get_tree().reload_current_scene()
	)
	vbox.add_child(new_seed_btn)

	var menu_btn := UITheme.create_button("Về Sảnh Chính", "arrow_left", Vector2(260, 34), Color(0.68, 0.75, 0.88), Color(0.13, 0.15, 0.22, 0.96), 13)
	menu_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Menu/main menu/main_menu.tscn")
	)
	vbox.add_child(menu_btn)

	var exit_btn := vbox.get_node_or_null("Exit_button") as Button
	if exit_btn != null:
		exit_btn.text = "Thoát Game"
		exit_btn.custom_minimum_size = Vector2(260, 34)
		UITheme.style_button(exit_btn, "close", Color(0.85, 0.38, 0.38), Color(0.20, 0.11, 0.13, 0.96), 13)
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
		info_label.text = "Seed: %s  |  Tầng: %d  |  Hạ gục: %d" % [
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
