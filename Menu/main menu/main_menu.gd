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
var undo_replay_btn: Button = null

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

	# VT-073: One-step Undo for Delete Replay.
	undo_replay_btn = UITheme.create_button(
		"Undo Last Delete",
		"",
		Vector2(160, 28),
		UITheme.COLOR_GOLD_BORDER,
		UITheme.COLOR_BG_DARK,
		11
	)

	undo_replay_btn.tooltip_text = "Restore the last deleted replay in this session"
	undo_replay_btn.disabled = true
	undo_replay_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	undo_replay_btn.pressed.connect(func():
		if not GameManager.undo_delete_replay():
			push_warning("Undo failed or is no longer available.")
		_refresh_seed_lists()
	)

	right_vbox.add_child(undo_replay_btn)

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
	if undo_replay_btn != null:
		undo_replay_btn.disabled = not GameManager.can_undo_delete_replay()
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
	lore_modal.offset_left = -350.0
	lore_modal.offset_right = 350.0
	lore_modal.offset_top = -220.0
	lore_modal.offset_bottom = 220.0
	lore_modal.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_GOLD_BORDER, 2, 6, 18, 14))
	lore_modal.visible = false
	add_child(lore_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	lore_modal.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var h_title := Label.new()
	h_title.text = "CHRONICLES OF MIDDLE-EARTH: MINES OF MORIA"
	UITheme.style_header_label(h_title, 15, UITheme.COLOR_TEXT_GOLD)
	h_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(h_title)

	var close_btn := UITheme.create_danger_button("Close", "", Vector2(84, 30), 12)
	close_btn.pressed.connect(func(): lore_modal.visible = false)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(content_vbox)

	var story_lbl := Label.new()
	story_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_lbl.add_theme_font_size_override("font_size", 13)
	story_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	story_lbl.text = GameManager.WORLD_LORE["story"] + "\n\n" + \
		"• SIX CHAMPIONS OF THE FELLOWSHIP VANGUARD:\n" + \
		"  1. Pyrois — Knight of the White Tower: Vitality 4, Armor 4, Damage 1. Wields the Blade of Andúril and Gondor Aegis, initiating Sovereign Rush.\n" + \
		"  2. Olaf — Dwarven Berserker of Erebor: Vitality 6, Armor 1, Damage 2. Swings the Greataxe of Khazad-dûm, unleashing Durin's Wrath to double strike damage.\n" + \
		"  3. Miya — Mirkwood Elven Archer: Vitality 3, Armor 1, Damage 1. Draws the Galadhrim Bow from afar, bombarding hordes with Orthanc Fire.\n" + \
		"  4. Charlotte — Dúnedain Shadow Ranger: Vitality 5, Armor 0, Damage 2. Brandishes the Twin Blades of Narsil with Triple Flurry and evasive Shadow Step.\n" + \
		"  5. Yugi / Atem — Pharaoh Summoner: Vitality 5, Armor 1, Damage 1. Summons monsters from his Duel Deck, guards with Shift, and unleashes a random Special Summon with Q.\n" + \
		"  6. Doraemon — Gadget Cat of the 22nd Century: Vitality 5, Armor 2, Damage 1. Fights with his whole 4D Pocket: 20 gadgets on 10 pages, 6 friends on Take-copters and 10 super moves powered by a 3-bar gauge.\n\n" + \
		"• THE SHADOW LEGION OF MORIA:\n" + \
		"  - Hostile Ranks: Moria Orcs, Armored Uruk-hai, Barrow-wight Remains, Minas Morgul Bone Archers, Angmar Blood Bats, and Warg-breed Werewolves.\n" + \
		"  - Dungeon Overlords: The Necromancer of Dol Guldur summoning toxic shades, and the ruthless Warg Rider Chieftain."
	content_vbox.add_child(story_lbl)

func _build_help_modal() -> void:
	help_modal = PanelContainer.new()
	help_modal.anchor_left = 0.5
	help_modal.anchor_right = 0.5
	help_modal.anchor_top = 0.5
	help_modal.anchor_bottom = 0.5
	help_modal.offset_left = -310.0
	help_modal.offset_right = 310.0
	help_modal.offset_top = -185.0
	help_modal.offset_bottom = 185.0
	help_modal.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_GOLD_BORDER, 2, 6, 18, 14))
	help_modal.visible = false
	add_child(help_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	help_modal.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var h_title := Label.new()
	h_title.text = "COMBAT CONTROLS & MECHANICS"
	UITheme.style_header_label(h_title, 15, UITheme.COLOR_TEXT_GOLD)
	h_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(h_title)

	var close_top := UITheme.create_danger_button("Close", "", Vector2(84, 30), 12)
	close_top.pressed.connect(func(): help_modal.visible = false)
	header.add_child(close_top)

	var body := Label.new()
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98))
	body.text = """• W, A, S, D: Move your champion in 4 directions
• Left Click: Strike or fire towards mouse cursor
• Key Q: Unleash champion active ability
• Right Click: Shadow Step dash exclusive to Charlotte
• Yugi: Left/Right Click to summon (hold 0.65s to charge), hold Shift to guard, Shift + Click for combo summons
• Doraemon: Mouse Wheel / Z / X switch gadget page, Left / Right Click use the page gadgets, Q friend (or SUPER with a full power bar), F Dorayaki
• Key E: Interact and pick up dropped loot or chests
• Keys 1 to 9: Quick-use potions or equip hotbar items
• Key I or Tab: Toggle Backpack & Equipment screen
• Key M: Expand or minimize the tactical Minimap
• Key ESC: Pause expedition, save seed, or retry"""
	vbox.add_child(body)

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
