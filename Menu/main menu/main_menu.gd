class_name MainMenu
extends Control

const UITheme = preload("res://Scene/UI/UITheme.gd")

@onready var start_button: Button = $MarginContainer/HBoxContainer/VBoxContainer/Start_button as Button
@onready var exit_button: Button = $MarginContainer/HBoxContainer/VBoxContainer/Exit_button as Button
@onready var start_level = preload("res://Scene/UI/CharacterSelect.tscn") as PackedScene

var seed_input: LineEdit = null
var seed_status_lbl: Label = null
var saved_list_vbox: VBoxContainer = null
var history_list_vbox: VBoxContainer = null
var seed_modal: PanelContainer = null
var lore_modal: PanelContainer = null
var help_modal: PanelContainer = null
var history_hdr_label: Label = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_bgm("menu")
	if not start_button.pressed.is_connected(_on_start_button_pressed):
		start_button.pressed.connect(_on_start_button_pressed)
	if not exit_button.pressed.is_connected(_on_exit_button_pressed):
		exit_button.pressed.connect(_on_exit_button_pressed)

	_enhance_main_menu_ui()

func _enhance_main_menu_ui() -> void:
	var bg_rect := get_node_or_null("TextureRect") as TextureRect
	if bg_rect != null:
		bg_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	# Nút Bật/Tắt Nhạc nền ở góc trên phải Main Menu
	var is_muted_init: bool = (get_node_or_null("/root/AudioManager") != null and AudioManager.is_muted)
	var audio_btn := UITheme.create_button(
		"Audio: Off" if is_muted_init else "Audio: On",
		"",
		Vector2(120, 34),
		UITheme.COLOR_GOLD_BORDER,
		UITheme.COLOR_BG_DARK,
		13
	)
	audio_btn.anchor_left = 1.0
	audio_btn.anchor_right = 1.0
	audio_btn.offset_left = -140.0
	audio_btn.offset_right = -20.0
	audio_btn.offset_top = 18.0
	audio_btn.offset_bottom = 52.0
	audio_btn.pressed.connect(func():
		if get_node_or_null("/root/AudioManager") != null:
			var m: bool = AudioManager.toggle_mute()
			audio_btn.text = "Audio: Off" if m else "Audio: On"
	)
	add_child(audio_btn)

	var top_vbox := get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	if top_vbox != null:
		top_vbox.add_theme_constant_override("separation", 6)

	var title_lbl := get_node_or_null("MarginContainer/VBoxContainer/Label") as Label
	if title_lbl != null:
		title_lbl.text = "KEEP FIGHTING & EARNING"
		UITheme.style_title_label(title_lbl, 54, Color(1.0, 0.88, 0.36))

		var sub_lbl := Label.new()
		sub_lbl.text = "CHRONICLES OF MIDDLE-EARTH: MINES OF MORIA"
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.style_header_label(sub_lbl, 16, Color(0.62, 0.90, 1.0))
		top_vbox.add_child(sub_lbl)

	var sep3 := get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/Seperator3") as Control
	if sep3 != null:
		sep3.visible = false

	var menu_vbox := $MarginContainer/HBoxContainer/VBoxContainer as VBoxContainer
	menu_vbox.add_theme_constant_override("separation", 10)

	# 1. Start Button
	start_button.text = "START EXPEDITION"
	start_button.custom_minimum_size = Vector2(360, 44)
	UITheme.style_button(start_button, "", UITheme.COLOR_GOLD_BORDER_HOVER, UITheme.COLOR_BG_DARK, 16)

	# 2. Palantír Seed Panel
	var seed_panel := PanelContainer.new()
	seed_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_GOLD_BORDER, 2, 4, 12, 10))
	menu_vbox.add_child(seed_panel)
	menu_vbox.move_child(seed_panel, 1)

	var seed_vbox := VBoxContainer.new()
	seed_vbox.add_theme_constant_override("separation", 6)
	seed_panel.add_child(seed_vbox)

	var seed_header := Label.new()
	seed_header.text = "THE PALANTÍR — DUNGEON SEED:"
	UITheme.style_header_label(seed_header, 13, UITheme.COLOR_TEXT_GOLD)
	seed_vbox.add_child(seed_header)

	var seed_hbox := HBoxContainer.new()
	seed_hbox.add_theme_constant_override("separation", 6)
	seed_vbox.add_child(seed_hbox)

	seed_input = LineEdit.new()
	seed_input.custom_minimum_size = Vector2(180, 34)
	seed_input.max_length = 32
	seed_input.placeholder_text = "Enter dungeon seed..."
	seed_input.text = GameManager.current_seed if get_node_or_null("/root/GameManager") != null else "ALOALO1234"
	UITheme.style_line_edit(seed_input, 13)
	seed_input.text_changed.connect(func(new_txt: String):
		if get_node_or_null("/root/GameManager") != null:
			var clean: String = GameManager.sanitize_seed(new_txt)
			if not clean.is_empty():
				GameManager.set_seed(clean)
	)
	seed_hbox.add_child(seed_input)

	var rand_btn := UITheme.create_button("Random", "", Vector2(115, 34), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 13)
	rand_btn.pressed.connect(func():
		if get_node_or_null("/root/GameManager") != null:
			var s: String = GameManager.generate_random_seed()
			GameManager.set_seed(s)
			seed_input.text = s
			_set_seed_status("New seed coordinates set: " + s)
	)
	seed_hbox.add_child(rand_btn)

	var save_btn := UITheme.create_button("Save", "", Vector2(85, 34), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 13)
	save_btn.pressed.connect(func():
		if get_node_or_null("/root/GameManager") != null:
			GameManager.set_seed(seed_input.text)
			seed_input.text = GameManager.current_seed
			GameManager.save_seed_entry(GameManager.current_seed, "Saved from Main Menu")
			_refresh_seed_lists()
			_set_seed_status("Saved seed: " + GameManager.current_seed + " to Chronicles!")
	)
	seed_hbox.add_child(save_btn)

	seed_status_lbl = Label.new()
	seed_status_lbl.text = "A shared seed generates the exact same dungeon layout, traps, enemies and loot."
	seed_status_lbl.add_theme_font_size_override("font_size", 12)
	seed_status_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	seed_vbox.add_child(seed_status_lbl)

	# 3. Archives Button
	var seed_mgr_btn := UITheme.create_button("SAVED SEEDS & COMBAT REPLAYS", "", Vector2(360, 40), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 14)
	seed_mgr_btn.pressed.connect(func():
		_refresh_seed_lists()
		seed_modal.visible = true
		lore_modal.visible = false
		help_modal.visible = false
	)
	menu_vbox.add_child(seed_mgr_btn)
	menu_vbox.move_child(seed_mgr_btn, 2)

	# 4. Info Row: Lore & Controls
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 8)
	menu_vbox.add_child(info_row)
	menu_vbox.move_child(info_row, 3)

	var lore_btn := UITheme.create_button("LORE & CHRONICLES", "", Vector2(176, 38), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 13)
	lore_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lore_btn.pressed.connect(func():
		lore_modal.visible = true
		seed_modal.visible = false
		help_modal.visible = false
	)
	info_row.add_child(lore_btn)

	var help_btn := UITheme.create_button("CONTROLS & MECHANICS", "", Vector2(176, 38), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 13)
	help_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_btn.pressed.connect(func():
		help_modal.visible = true
		seed_modal.visible = false
		lore_modal.visible = false
	)
	info_row.add_child(help_btn)

	# 5. Quit Game Button
	exit_button.text = "QUIT GAME"
	exit_button.custom_minimum_size = Vector2(360, 38)
	UITheme.style_button(exit_button, "", UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 14)

	_build_seed_and_replay_modal()
	_build_lore_modal()
	_build_help_modal()

func _set_seed_status(msg: String) -> void:
	if seed_status_lbl != null:
		seed_status_lbl.text = msg
		seed_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))

func _build_seed_and_replay_modal() -> void:
	seed_modal = PanelContainer.new()
	seed_modal.anchor_left = 0.5
	seed_modal.anchor_right = 0.5
	seed_modal.anchor_top = 0.5
	seed_modal.anchor_bottom = 0.5
	seed_modal.offset_left = -360.0
	seed_modal.offset_right = 360.0
	seed_modal.offset_top = -215.0
	seed_modal.offset_bottom = 215.0
	seed_modal.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_GOLD_BORDER, 2, 6, 16, 14))
	seed_modal.visible = false
	add_child(seed_modal)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	seed_modal.add_child(root_vbox)

	var header := HBoxContainer.new()
	root_vbox.add_child(header)

	var title_lbl := Label.new()
	title_lbl.text = "DUNGEON ARCHIVES & COMBAT REPLAYS"
	UITheme.style_header_label(title_lbl, 16, UITheme.COLOR_TEXT_GOLD)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	var close_btn := UITheme.create_danger_button("Close", "", Vector2(84, 30), 12)
	close_btn.pressed.connect(func(): seed_modal.visible = false)
	header.add_child(close_btn)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	root_vbox.add_child(cols)

	# Column 1: Saved Seeds
	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER_MUTED, 1, 4, 10, 8))
	cols.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_vbox)

	var l_hdr := Label.new()
	l_hdr.text = "SAVED SEEDS:"
	UITheme.style_header_label(l_hdr, 13, UITheme.COLOR_TEXT_GOLD)
	left_vbox.add_child(l_hdr)

	var l_scroll := ScrollContainer.new()
	l_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(l_scroll)

	saved_list_vbox = VBoxContainer.new()
	saved_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saved_list_vbox.add_theme_constant_override("separation", 6)
	l_scroll.add_child(saved_list_vbox)

	# Column 2: Run History & Replays
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER_MUTED, 1, 4, 10, 8))
	cols.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_vbox)

	history_hdr_label = Label.new()
	history_hdr_label.text = "EXPEDITION HISTORY & REPLAYS (Saved: 0/10):"
	UITheme.style_header_label(history_hdr_label, 13, UITheme.COLOR_TEXT_GOLD)
	right_vbox.add_child(history_hdr_label)

	var r_scroll := ScrollContainer.new()
	r_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(r_scroll)

	history_list_vbox = VBoxContainer.new()
	history_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_list_vbox.add_theme_constant_override("separation", 6)
	r_scroll.add_child(history_list_vbox)

func _refresh_seed_lists() -> void:
	if saved_list_vbox == null or history_list_vbox == null:
		return
	for c in saved_list_vbox.get_children():
		c.queue_free()
	for c in history_list_vbox.get_children():
		c.queue_free()

	if get_node_or_null("/root/GameManager") == null:
		return

	for item in GameManager.saved_seeds:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER_MUTED, 1, 4, 8, 6))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		card.add_child(row)

		var s_val: String = String(item.get("seed", "ALOALO1234"))
		var h_idx: int = int(item.get("hero_idx", 2))

		var lbl := Label.new()
		lbl.text = "%s\n%s" % [s_val, String(item.get("note", ""))]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
		row.add_child(lbl)

		var play_btn := UITheme.create_button("Play", "", Vector2(76, 28), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 12)
		play_btn.pressed.connect(func():
			GameManager.replay_seed_run(s_val, h_idx)
		)
		row.add_child(play_btn)

		var del_btn := UITheme.create_danger_button("Del", "", Vector2(50, 28), 11)
		del_btn.tooltip_text = "Delete this seed"
		del_btn.pressed.connect(func():
			GameManager.remove_saved_seed(s_val)
			_refresh_seed_lists()
		)
		row.add_child(del_btn)
		saved_list_vbox.add_child(card)

	if GameManager.run_history.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No combat history recorded.\nComplete an expedition to record a replay."
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
		history_list_vbox.add_child(empty_lbl)
	else:
		for run_item in GameManager.run_history:
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER_MUTED, 1, 4, 8, 6))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			card.add_child(row)

			var s_val: String = String(run_item.get("seed", "ALOALO1234"))
			var h_idx: int = int(run_item.get("hero_idx", 2))
			var h_name: String = String(run_item.get("hero_name", "Hero"))
			var flr: int = int(run_item.get("floor", 1))
			var kills: int = int(run_item.get("kills", 0))

			var lbl := Label.new()
			lbl.text = "%s • Seed: %s\nFloor: %d • Foes Slain: %d" % [h_name, s_val, flr, kills]
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
			row.add_child(lbl)

			var seed_btn := UITheme.create_button("Retry", "", Vector2(76, 28), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 11)
			seed_btn.pressed.connect(func():
				GameManager.replay_seed_run(s_val, h_idx)
			)
			row.add_child(seed_btn)

			if bool(run_item.get("has_replay", false)):
				var watch_btn := UITheme.create_button("Replay", "", Vector2(76, 28), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 11)
				watch_btn.pressed.connect(func():
					GameManager.start_action_replay(run_item)
				)
				row.add_child(watch_btn)

				var del_replay_btn := UITheme.create_danger_button("Del", "", Vector2(50, 28), 11)
				del_replay_btn.tooltip_text = "Delete replay data to free memory"
				del_replay_btn.pressed.connect(func():
					GameManager.delete_replay(run_item)
					_refresh_seed_lists()
				)
				row.add_child(del_replay_btn)

			history_list_vbox.add_child(card)

	if history_hdr_label != null:
		history_hdr_label.text = "EXPEDITION HISTORY & REPLAYS (Saved: %d/10):" % GameManager.get_saved_replays_count()

func _build_lore_modal() -> void:
	lore_modal = PanelContainer.new()
	lore_modal.anchor_left = 0.5
	lore_modal.anchor_right = 0.5
	lore_modal.anchor_top = 0.5
	lore_modal.anchor_bottom = 0.5
	lore_modal.offset_left = -430.0
	lore_modal.offset_right = 430.0
	lore_modal.offset_top = -250.0
	lore_modal.offset_bottom = 250.0
	lore_modal.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_GOLD_BORDER, 2, 6, 18, 14))
	lore_modal.visible = false
	add_child(lore_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	lore_modal.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var icon_hdr := UITheme.create_icon_header("scroll_gold", "CHRONICLES OF MORIA: STORYLINE & HERO DOSSIERS", 16, UITheme.COLOR_TEXT_GOLD)
	icon_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(icon_hdr)

	var close_btn := UITheme.create_danger_button("Close", "", Vector2(84, 30), 12)
	close_btn.pressed.connect(func(): lore_modal.visible = false)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(content_vbox)

	# 1. Prologue & World Story
	var prologue_box := PanelContainer.new()
	prologue_box.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER_MUTED, 1, 4, 12, 10))
	content_vbox.add_child(prologue_box)

	var p_vbox := VBoxContainer.new()
	p_vbox.add_theme_constant_override("separation", 6)
	prologue_box.add_child(p_vbox)

	var p_hdr := Label.new()
	p_hdr.text = "PROLOGUE: THE RESURGENCE IN KHAZAD-DÛM"
	UITheme.style_header_label(p_hdr, 14, UITheme.COLOR_TEXT_GOLD)
	p_vbox.add_child(p_hdr)

	var p_txt := Label.new()
	p_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p_txt.add_theme_font_override("font", UITheme.FONT_BODY)
	p_txt.add_theme_font_size_override("font_size", 12)
	p_txt.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	p_txt.text = GameManager.WORLD_LORE.get("story", "")
	p_vbox.add_child(p_txt)

	# 2. Lore Chapters (Palantir & Determinism, Convergence)
	var chapters: Array = GameManager.WORLD_LORE.get("chapters", [])
	for chap in chapters:
		if chap is Dictionary:
			var chap_box := PanelContainer.new()
			chap_box.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER_MUTED, 1, 4, 10, 8))
			content_vbox.add_child(chap_box)
			var c_vbox := VBoxContainer.new()
			c_vbox.add_theme_constant_override("separation", 4)
			chap_box.add_child(c_vbox)
			var c_title := Label.new()
			c_title.text = String(chap.get("title", ""))
			UITheme.style_header_label(c_title, 13, Color(0.60, 0.88, 1.0))
			c_vbox.add_child(c_title)
			var c_text := Label.new()
			c_text.text = String(chap.get("text", ""))
			c_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			c_text.add_theme_font_override("font", UITheme.FONT_BODY)
			c_text.add_theme_font_size_override("font_size", 12)
			c_text.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
			c_vbox.add_child(c_text)

	# 3. Eight Champions Detailed Profiles
	var heroes_hdr := Label.new()
	heroes_hdr.text = "THE EIGHT CHAMPIONS OF THE FELLOWSHIP VANGUARD"
	UITheme.style_header_label(heroes_hdr, 15, UITheme.COLOR_TEXT_GOLD)
	content_vbox.add_child(heroes_hdr)

	for h in GameManager.CHARACTER_INFO:
		var h_card := PanelContainer.new()
		h_card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER, 1, 4, 12, 10))
		content_vbox.add_child(h_card)

		var h_vbox := VBoxContainer.new()
		h_vbox.add_theme_constant_override("separation", 5)
		h_card.add_child(h_vbox)

		var h_title := Label.new()
		h_title.text = "%d. %s  —  %s  (%s)" % [
			int(h.get("index", 0)) + 1,
			String(h.get("name", "")).to_upper(),
			String(h.get("role", "")),
			String(h.get("weapon", ""))
		]
		UITheme.style_header_label(h_title, 13, UITheme.COLOR_TEXT_GOLD)
		h_vbox.add_child(h_title)

		if h.has("quote") and not String(h.get("quote", "")).is_empty():
			var q_lbl := Label.new()
			q_lbl.text = String(h.get("quote", ""))
			q_lbl.add_theme_font_override("font", UITheme.FONT_BODY)
			q_lbl.add_theme_font_size_override("font_size", 11)
			q_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
			h_vbox.add_child(q_lbl)

		var origin_txt := ""
		if h.has("origin"):
			origin_txt += "• Origin: " + String(h.get("origin", "")) + "\n"
		if h.has("motivation"):
			origin_txt += "• Motivation: " + String(h.get("motivation", "")) + "\n"
		if h.has("tactics"):
			origin_txt += "• Combat Tactics: " + String(h.get("tactics", ""))

		if not origin_txt.is_empty():
			var o_lbl := Label.new()
			o_lbl.text = origin_txt
			o_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			o_lbl.add_theme_font_override("font", UITheme.FONT_BODY)
			o_lbl.add_theme_font_size_override("font_size", 12)
			o_lbl.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
			h_vbox.add_child(o_lbl)

		var lore_lbl := Label.new()
		lore_lbl.text = String(h.get("lore", ""))
		lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lore_lbl.add_theme_font_override("font", UITheme.FONT_BODY)
		lore_lbl.add_theme_font_size_override("font_size", 12)
		lore_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
		h_vbox.add_child(lore_lbl)

func _build_help_modal() -> void:
	help_modal = PanelContainer.new()
	help_modal.anchor_left = 0.5
	help_modal.anchor_right = 0.5
	help_modal.anchor_top = 0.5
	help_modal.anchor_bottom = 0.5
	help_modal.offset_left = -430.0
	help_modal.offset_right = 430.0
	help_modal.offset_top = -250.0
	help_modal.offset_bottom = 250.0
	help_modal.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_GOLD_BORDER, 2, 6, 18, 14))
	help_modal.visible = false
	add_child(help_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	help_modal.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var modal_hdr := UITheme.create_icon_header("question", "EXPEDITION MANUAL: CONTROLS, SHORTCUTS & MECHANICS", 16, UITheme.COLOR_TEXT_GOLD)
	modal_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(modal_hdr)

	var close_top := UITheme.create_danger_button("Close", "", Vector2(84, 30), 12)
	close_top.pressed.connect(func(): help_modal.visible = false)
	header.add_child(close_top)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(content_vbox)

	# Section 1: Movement & Mouse Aiming
	var move_card := PanelContainer.new()
	move_card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER, 1, 4, 12, 10))
	content_vbox.add_child(move_card)

	var m_vbox := VBoxContainer.new()
	m_vbox.add_theme_constant_override("separation", 6)
	move_card.add_child(m_vbox)

	var m_title := Label.new()
	m_title.text = "1. MOVEMENT & MOUSE AIMING"
	UITheme.style_header_label(m_title, 14, UITheme.COLOR_TEXT_GOLD)
	m_vbox.add_child(m_title)

	var m_body := Label.new()
	m_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m_body.add_theme_font_override("font", UITheme.FONT_BODY)
	m_body.add_theme_font_size_override("font_size", 12)
	m_body.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	m_body.text = """• W, A, S, D or Arrow Keys: Move your champion across the 4 cardinal directions.
• Mouse Cursor Aiming: Character continuously rotates 360 degrees toward the cursor. All projectile shots, melee cleaves, dashes, and directional abilities fire exactly toward the cursor's location.
• Left Mouse Button (LMB): Primary attack / weapon strike / arrow shot. Holding the button auto-repeats attacks at champion cooldown speed.
• Right Mouse Button (RMB): Secondary action or specialty ability (unique per hero).
• Key Q: Unleash champion primary active skill (cooldown displayed in HUD).
• Key E: Interact with objects, open dungeon chests, collect world item drops, or step through dimensional portals."""
	m_vbox.add_child(m_body)

	# Section 2: Champion-Specific Keybindings
	var hero_card := PanelContainer.new()
	hero_card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER, 1, 4, 12, 10))
	content_vbox.add_child(hero_card)

	var h_vbox := VBoxContainer.new()
	h_vbox.add_theme_constant_override("separation", 6)
	hero_card.add_child(h_vbox)

	var h_title := Label.new()
	h_title.text = "2. CHAMPION-SPECIFIC BUTTONS & COMBOS"
	UITheme.style_header_label(h_title, 14, UITheme.COLOR_TEXT_GOLD)
	h_vbox.add_child(h_title)

	var h_body := Label.new()
	h_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h_body.add_theme_font_override("font", UITheme.FONT_BODY)
	h_body.add_theme_font_size_override("font_size", 12)
	h_body.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	h_body.text = """• Pyrois (Knight): LMB sword thrust | Q Sovereign Rush: invulnerable charge forward dealing +2 bonus damage (5s CD).
• Olaf (Berserker): LMB wide greataxe cleave hitting multiple foes | Q Durin's Wrath: roar to double melee damage for 5 seconds (5s CD).
• Miya (Archer): LMB rapid long-range arrows (280 px/s) | Q Orthanc Fire: throw alchemical explosive dealing 2x area damage + 1 bonus damage (6.5s CD).
• Charlotte (Shadow Ranger): LMB dual blade flurry | RMB Shadow Step: 400 px/s invulnerable dash + 4 piercing stabs (5s CD) | Q Triple Flurry: rapid 3-slash stationary burst (3s CD).
• Yugi / Atem (Summoner): LMB quick monster strike (hold 0.65s for 2x charge) | RMB location summon (hold 0.65s for 3x charge) | Hold Shift: guard spirit stance; click during guard for 2x combo summon | Q Special Summon: cast 1 of 5 room spells (12s CD).
• Doraemon (Gadget Cat): Mouse Wheel or Z / X: switch active gadget page (10 pages / 20 gadgets) | LMB & RMB: activate page gadgets | Q: friend assist (Nobita, Gian, Shizuka, Dorami, Suneo, Cat) or SUPER move at 100+ power | Key F: eat Dorayaki (+1 HP, +40 power, 12s CD).
• Hoshimi Miyabi (Frost): LMB 3-hit frost combo (3rd hit lunges & freezes) | Shift: invulnerable 72px dash slash | Hold RMB: charge piercing Frost Wave | Q: Frost Bloom ice spike eruption (3x + freeze) | Autonomous Ice Spirit snipes nearby enemies.
• Lương Thơ (Gunblade): LMB 3-step combo: Stab -> Twin Swing -> Ground Smash (2x + daze) | RMB: fire Twin Barrels along cursor | Q: White Moon form (12s total invulnerability, +1 dmg, 25% faster attack, 20% faster move, piercing rounds)."""
	h_vbox.add_child(h_body)

	# Section 3: Backpack, Equipment & Hotbar
	var bag_card := PanelContainer.new()
	bag_card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER, 1, 4, 12, 10))
	content_vbox.add_child(bag_card)

	var b_vbox := VBoxContainer.new()
	b_vbox.add_theme_constant_override("separation", 6)
	bag_card.add_child(b_vbox)

	var b_title := Label.new()
	b_title.text = "3. BACKPACK, EQUIPMENT & HOTBAR SHORTCUTS"
	UITheme.style_header_label(b_title, 14, UITheme.COLOR_TEXT_GOLD)
	b_vbox.add_child(b_title)

	var b_body := Label.new()
	b_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b_body.add_theme_font_override("font", UITheme.FONT_BODY)
	b_body.add_theme_font_size_override("font_size", 12)
	b_body.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	b_body.text = """• Tab, I, or B: Toggle the 16-slot Backpack and Equipment window.
• Hotbar Keys 1 to 9: Quickly consume potions or switch active equipment without opening the inventory.
• Key G: Instantly drop the first item in your backpack onto the floor.
• Right-Click in Inventory: Drop a specific item from any inventory slot to spawn a collectible floor pickup.
• Item Stacking: Consumable potions automatically stack up to 16 units per slot, displaying item count badges."""
	b_vbox.add_child(b_body)

	# Section 4: Exploration & Combat Rules
	var rules_card := PanelContainer.new()
	rules_card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER, 1, 4, 12, 10))
	content_vbox.add_child(rules_card)

	var r_vbox := VBoxContainer.new()
	r_vbox.add_theme_constant_override("separation", 6)
	rules_card.add_child(r_vbox)

	var r_title := Label.new()
	r_title.text = "4. COMBAT MECHANICS & DUNGEON SURVIVAL"
	UITheme.style_header_label(r_title, 14, UITheme.COLOR_TEXT_GOLD)
	r_vbox.add_child(r_title)

	var r_body := Label.new()
	r_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r_body.add_theme_font_override("font", UITheme.FONT_BODY)
	r_body.add_theme_font_size_override("font_size", 12)
	r_body.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	r_body.text = """• Health & Regenerating Armor: Armor shields absorb incoming attacks first. If you avoid damage for 5 seconds, your Armor begins regenerating back to full!
• Line-of-Sight (LoS) & Obstacles: Projectiles and attacks cannot pass through stone walls, closed doors, or wooden crates. Use dungeon pillars to block enemy arrows and break enemy lines of sight.
• Room Locking: Entering an unvisited monster room locks all entrance and exit doors until all enemies are defeated.
• Key M: Toggle between the compact corner minimap radar and the expanded full dungeon tactical overview.
• Key N: Toggle audio BGM and sound effects mute.
• Key ESC: Pause expedition, check seed information, access manual, or retry."""
	r_vbox.add_child(r_body)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if help_modal != null and help_modal.visible:
				help_modal.visible = false
				get_viewport().set_input_as_handled()
			elif lore_modal != null and lore_modal.visible:
				lore_modal.visible = false
				get_viewport().set_input_as_handled()
			elif seed_modal != null and seed_modal.visible:
				seed_modal.visible = false
				get_viewport().set_input_as_handled()

func on_start_pressed() -> void:
	_on_start_button_pressed()

func on_exit_pressed() -> void:
	_on_exit_button_pressed()

func _on_start_button_pressed() -> void:
	if seed_input != null and get_node_or_null("/root/GameManager") != null:
		GameManager.set_seed(seed_input.text)
	get_tree().change_scene_to_packed(start_level)

func _on_exit_button_pressed() -> void:
	get_tree().quit()
