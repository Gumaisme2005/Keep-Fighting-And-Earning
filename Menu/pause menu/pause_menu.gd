extends Control

const UITheme = preload("res://Scene/UI/UITheme.gd")
const SettingsModalScript = preload("res://Scene/UI/SettingsModal.gd")

var info_label: Label = null
var guide_modal: PanelContainer = null
var guide_title_label: Label = null
var guide_body_label: Label = null
var guide_backdrop: ColorRect = null
var settings_modal: Control = null
var card_panel: PanelContainer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_extra_pause_controls()
	hide()

func _build_extra_pause_controls() -> void:
	var bg_rect := get_node_or_null("ColorRect") as ColorRect
	if bg_rect != null:
		bg_rect.color = Color(0.02, 0.03, 0.06, 0.85)

	# Hide legacy unconstrained top vbox to prevent overlapping title bugs
	var top_vbox := get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	if top_vbox != null:
		top_vbox.visible = false

	var vbox := $MarginContainer/HBoxContainer/VBoxContainer as VBoxContainer
	if vbox == null:
		return
	vbox.add_theme_constant_override("separation", 10)

	# Clean legacy separator
	var sep := vbox.get_node_or_null("Seperater") as Control
	if sep != null:
		sep.visible = false

	# Grab original scene buttons before building new card layout
	var resume_btn := vbox.get_node_or_null("Resume_button") as Button
	var restart_btn := vbox.get_node_or_null("Restart_button") as Button
	var exit_btn := vbox.get_node_or_null("Exit_button") as Button

	# Centered Card Panel to contain all pause elements without clipping
	card_panel = PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(510, 0)
	card_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.05, 0.06, 0.11, 0.96), UITheme.COLOR_GOLD_BORDER, 2, 6, 18, 14))
	vbox.add_child(card_panel)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 10)
	card_panel.add_child(card_vbox)

	# 1. Title Label inside Card (Guaranteed Zero Overlap)
	var title_lbl := Label.new()
	title_lbl.text = "EXPEDITION PAUSED"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_title_label(title_lbl, 32, Color(1.0, 0.86, 0.35))
	card_vbox.add_child(title_lbl)

	# 2. Status Info Panel (Seed & Floor badge)
	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_GOLD_BORDER_MUTED, 1, 4, 12, 6))
	card_vbox.add_child(info_panel)

	var info_hbox := HBoxContainer.new()
	info_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_label = Label.new()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_header_label(info_label, 13, UITheme.COLOR_TEXT_GOLD)
	info_hbox.add_child(info_label)
	info_panel.add_child(info_hbox)

	# 3. Two-Column Button Layout
	var cols_hbox := HBoxContainer.new()
	cols_hbox.add_theme_constant_override("separation", 14)
	cols_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_child(cols_hbox)

	# Column 1: Primary Actions & Settings
	var col_left := VBoxContainer.new()
	col_left.add_theme_constant_override("separation", 8)
	col_left.custom_minimum_size = Vector2(230, 0)
	cols_hbox.add_child(col_left)

	if resume_btn != null:
		resume_btn.reparent(col_left)
		resume_btn.text = "RESUME EXPEDITION"
		resume_btn.custom_minimum_size = Vector2(230, 36)
		UITheme.style_button(resume_btn, "", UITheme.COLOR_GOLD_BORDER_HOVER, UITheme.COLOR_BG_DARK, 13)

	var settings_btn := UITheme.create_button("SETTINGS & GRAPHICS", "gear", Vector2(230, 36), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 13)
	settings_btn.pressed.connect(func():
		if settings_modal != null:
			settings_modal.show_modal()
	)
	col_left.add_child(settings_btn)

	var controls_btn := UITheme.create_button("CONTROLS & MANUAL", "question", Vector2(230, 36), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 13)
	controls_btn.pressed.connect(func():
		_show_pause_guide("controls")
	)
	col_left.add_child(controls_btn)

	var lore_btn := UITheme.create_button("EXPEDITION LORE & STORY", "scroll_gold", Vector2(230, 36), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 13)
	lore_btn.pressed.connect(func():
		_show_pause_guide("lore")
	)
	col_left.add_child(lore_btn)

	# Column 2: Run Navigation & Exit
	var col_right := VBoxContainer.new()
	col_right.add_theme_constant_override("separation", 8)
	col_right.custom_minimum_size = Vector2(230, 0)
	cols_hbox.add_child(col_right)

	if restart_btn != null:
		restart_btn.reparent(col_right)
		restart_btn.text = "RETRY CURRENT SEED"
		restart_btn.custom_minimum_size = Vector2(230, 36)
		UITheme.style_button(restart_btn, "", UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 13)

	var save_seed_btn := UITheme.create_button("RECORD SEED TO CHRONICLES", "", Vector2(230, 36), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 12)
	save_seed_btn.pressed.connect(func():
		if get_node_or_null("/root/GameManager") != null:
			DisplayServer.clipboard_set(GameManager.current_seed)
			GameManager.save_seed_entry(GameManager.current_seed)
			info_label.text = "Dungeon seed recorded: " + GameManager.current_seed
	)
	col_right.add_child(save_seed_btn)

	var new_seed_btn := UITheme.create_button("EMBARK ON NEW EXPEDITION", "", Vector2(230, 36), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 12)
	new_seed_btn.pressed.connect(func():
		get_tree().paused = false
		if get_node_or_null("/root/GameManager") != null:
			var s: String = GameManager.generate_random_seed()
			GameManager.replay_seed_run(s, GameManager.selected_character_index)
		else:
			get_tree().reload_current_scene()
	)
	col_right.add_child(new_seed_btn)

	var menu_btn := UITheme.create_button("RETURN TO MAIN MENU", "", Vector2(230, 36), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 13)
	menu_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Menu/main menu/main_menu.tscn")
	)
	col_right.add_child(menu_btn)

	if exit_btn != null:
		exit_btn.reparent(col_right)
		exit_btn.text = "ABANDON & QUIT"
		exit_btn.custom_minimum_size = Vector2(230, 36)
		UITheme.style_danger_button(exit_btn, "", 13)

	_build_pause_guide_modal()
	_build_pause_settings_modal()

func _build_pause_settings_modal() -> void:
	settings_modal = SettingsModalScript.new()
	settings_modal.visible = false
	add_child(settings_modal)

func _build_pause_guide_modal() -> void:
	guide_backdrop = ColorRect.new()
	guide_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	guide_backdrop.color = Color(0.02, 0.03, 0.06, 0.88)
	guide_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	guide_backdrop.visible = false
	guide_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_close_all_submodals()
	)
	add_child(guide_backdrop)

	guide_modal = PanelContainer.new()
	guide_modal.anchor_left = 0.5
	guide_modal.anchor_right = 0.5
	guide_modal.anchor_top = 0.5
	guide_modal.anchor_bottom = 0.5
	guide_modal.offset_left = -390.0
	guide_modal.offset_right = 390.0
	guide_modal.offset_top = -225.0
	guide_modal.offset_bottom = 225.0
	guide_modal.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_GOLD_BORDER, 2, 6, 18, 14))
	guide_modal.visible = false
	add_child(guide_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	guide_modal.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	guide_title_label = Label.new()
	guide_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_header_label(guide_title_label, 15, UITheme.COLOR_TEXT_GOLD)
	header.add_child(guide_title_label)

	var close_btn := UITheme.create_danger_button("Close", "", Vector2(84, 30), 12)
	close_btn.pressed.connect(_close_all_submodals)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.custom_minimum_size = Vector2(720, 0)
	content_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(content_vbox)

	guide_body_label = Label.new()
	guide_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_body_label.add_theme_font_override("font", UITheme.FONT_BODY)
	guide_body_label.add_theme_font_size_override("font_size", 12)
	guide_body_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	content_vbox.add_child(guide_body_label)

func _show_pause_guide(mode: String) -> void:
	if guide_modal == null:
		return
	var hero_info: Dictionary = {}
	if get_node_or_null("/root/GameManager") != null:
		hero_info = GameManager.get_selected_character_info()

	var hero_name: String = String(hero_info.get("name", "Active Hero"))
	var hero_role: String = String(hero_info.get("role", ""))

	if mode == "controls":
		guide_title_label.text = "EXPEDITION CONTROLS & MANUAL"
		guide_body_label.text = """• MOVEMENT & MOUSE AIMING:
  - W, A, S, D / Arrow Keys: Move your hero in 4 directions.
  - Mouse Cursor: 360-degree aiming. All attacks, arrows, and spells fly toward your cursor.
  - Left Mouse Button (LMB): Primary attack / weapon strike / archery.
  - Right Mouse Button (RMB): Secondary action / specialty skill.
  - Key Q: Primary active skill.
  - Key E: Interact, open chests, collect dropped loot, step through portals.

• ACTIVE HERO: %s (%s)
  - %s
  - %s
  - %s

• INVENTORY, HOTBAR & SYSTEM:
  - Tab / I / B: Open 16-slot Backpack and Equipment screen.
  - Keys 1 to 9: Hotbar quick consumption / gear swap.
  - Key G / Right-Click: Drop items onto the floor.
  - Key M: Expand or minimize tactical Minimap.
  - Key N: Toggle audio mute.
  - Key ESC: Pause / Resume.

• COMBAT SURVIVAL:
  - Armor automatically regenerates to full after 5 seconds without taking damage.
  - Use stone columns and walls to block enemy projectiles and kite swarms.""" % [
			hero_name.to_upper(), hero_role,
			String(hero_info.get("controls_guide", "")),
			String(hero_info.get("skill_q", "")),
			String(hero_info.get("tactics", ""))
		]
	else:
		guide_title_label.text = "THE CHRONICLES OF MORIA & STORY"
		var story_txt: String = ""
		if get_node_or_null("/root/GameManager") != null:
			story_txt = String(GameManager.WORLD_LORE.get("story", ""))
		guide_body_label.text = """• THE RESURGENCE IN KHAZAD-DÛM:
%s

• CURRENT CHAMPION DOSSIER: %s (%s)
  - Origin: %s
  - Motivation: %s
  - Lore: %s
  - Quote: %s""" % [
			story_txt,
			hero_name.to_upper(), hero_role,
			String(hero_info.get("origin", "Middle-earth")),
			String(hero_info.get("motivation", "To defeat the shadow")),
			String(hero_info.get("lore", "")),
			String(hero_info.get("quote", ""))
		]

	if guide_backdrop != null:
		guide_backdrop.visible = true
		guide_backdrop.move_to_front()
	guide_modal.visible = true
	guide_modal.move_to_front()

func _unhandled_input(event: InputEvent) -> void:
	var game_over_menu := get_tree().get_first_node_in_group("game_over_menu")
	if game_over_menu != null and game_over_menu.is_visible_in_tree():
		return
	if event.is_action_pressed("esc") and not event.is_echo():
		if settings_modal != null and settings_modal.visible:
			settings_modal.hide_modal()
			get_viewport().set_input_as_handled()
			return
		if guide_modal != null and guide_modal.visible:
			_close_all_submodals()
			get_viewport().set_input_as_handled()
			return
		if get_tree().paused:
			resume()
		else:
			pause()

func _close_all_submodals() -> void:
	if settings_modal != null and settings_modal.visible:
		settings_modal.hide_modal()
	if guide_modal != null and guide_modal.visible:
		guide_modal.visible = false
	if guide_backdrop != null:
		guide_backdrop.visible = false

func resume() -> void:
	_close_all_submodals()
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
