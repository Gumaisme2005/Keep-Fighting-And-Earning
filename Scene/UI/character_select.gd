extends Control

const UITheme = preload("res://Scene/UI/UITheme.gd")
const DUNGEON_BG_TEX: Texture2D = preload("res://Assets/UI/Background/Dungeon.png")
const ARCHER_PORTRAIT: Texture2D = preload("res://Assets/UI/Button&Character/Human_Archer.png")
const KNIGHT_PORTRAIT: Texture2D = preload("res://Assets/UI/Button&Character/Human_Knight.png")
const SOLDIER_PORTRAIT: Texture2D = preload("res://Assets/UI/Button&Character/Soldier.png")
const SWORDSMAN_PORTRAIT: Texture2D = preload("res://Assets/UI/Button&Character/Swordsman.png")

@export var character_scenes: Array[PackedScene] = [
	preload("res://Scene/Character/Player 3_Miya/player_3.tscn"),
	preload("res://Scene/Character/Player 2_Olaf/player_2.tscn"),
	preload("res://Scene/Character/Player 1_Pyrois/player.tscn"),
	preload("res://Scene/Character/Player 4_Charlotte/player_4.tscn"),
	preload("res://Scene/Character/Yugi/yugi.tscn"),
	preload("res://Scene/Character/Doraemon/doraemon.tscn"),
	preload("res://Scene/Character/Miyabi/miyabi.tscn"),
	preload("res://Scene/Character/LuongTho/luong_tho.tscn"),
]
@export_file("*.tscn") var game_world_path: String = "res://world.tscn"

@onready var navigation: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer
@onready var scroll_container: ScrollContainer = navigation.get_node("ScrollContainer")
@onready var object_container: HBoxContainer = scroll_container.get_node("HBoxContainer")
@onready var previous_button: Button = navigation.get_node("TextureRect/PreviousButton")
@onready var next_button: Button = navigation.get_node("TextureRect2/PreviousButton")
@onready var hero_selection_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HeroSelectionButton
@onready var selection_marker: Control = $SelectMaker

var target_scroll: float = 0.0
var selected_index: int = 0
var portraits: Array[TextureRect] = []
var scroll_tween: Tween

var hero_name_label: Label = null
var hero_lore_label: Label = null
var stat_hp_label: Label = null
var stat_armor_label: Label = null
var stat_dmg_label: Label = null
var stat_spd_label: Label = null
var skill_icon_rect: TextureRect = null
var skill_q_label: Label = null
var skill_rmb_label: Label = null
var seed_input: LineEdit = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg_tex := TextureRect.new()
	bg_tex.texture = DUNGEON_BG_TEX
	bg_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_tex)
	move_child(bg_tex, 0)

	var root_panel := $PanelContainer as PanelContainer
	if root_panel != null:
		root_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.05, 0.06, 0.11, 0.72), Color(0.75, 0.60, 0.28, 0.85), 2, 0, 0, 0))

	_add_yugi_portrait()
	_add_doraemon_portrait()
	_add_miyabi_portrait()
	_add_luong_tho_portrait()

	var idx_counter: int = 0
	for child in object_container.get_children():
		if child is TextureRect:
			var p := child as TextureRect
			p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			p.custom_minimum_size = Vector2(104, 104)
			p.pivot_offset = Vector2(52, 52)
			p.mouse_filter = Control.MOUSE_FILTER_STOP
			var captured_idx := idx_counter
			p.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					_select_index(captured_idx)
			)
			portraits.append(p)
			idx_counter += 1

	var hero_textures: Array[Texture2D] = [
		ARCHER_PORTRAIT,
		KNIGHT_PORTRAIT,
		SOLDIER_PORTRAIT,
		SWORDSMAN_PORTRAIT
	]
	for i in range(mini(portraits.size(), hero_textures.size())):
		if hero_textures[i] != null:
			portraits[i].texture = hero_textures[i]

	previous_button.pressed.connect(_on_previous_button_pressed)
	next_button.pressed.connect(_on_next_button_pressed)
	hero_selection_button.pressed.connect(_on_hero_selection_button_pressed)
	selection_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_selection_button.disabled = true
	previous_button.disabled = true
	next_button.disabled = true

	_build_hero_details_and_seed_bar()

	await get_tree().process_frame
	await get_tree().process_frame
	if portraits.is_empty():
		return

	if get_node_or_null("/root/GameManager") != null:
		selected_index = clampi(GameManager.selected_character_index, 0, portraits.size() - 1)

	target_scroll = _get_portrait_scroll(selected_index)
	scroll_container.scroll_horizontal = roundi(target_scroll)
	_select_deselect_highlight()
	_update_buttons()
	_update_hero_info_display()

func _add_luong_tho_portrait() -> void:
	var portrait := TextureRect.new()
	portrait.name = "TextureRect8"
	# 52x52 canvas (base-form idle frame) with the feet at ~83% height, like the other portraits.
	portrait.texture = preload("res://Scene/Character/LuongTho/LTSprites.gd").texture("lt_portrait.png")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	object_container.add_child(portrait)
	# Keep the trailing MarginContainer spacer as the last child.
	object_container.move_child(portrait, object_container.get_child_count() - 2)

func _add_miyabi_portrait() -> void:
	var portrait := TextureRect.new()
	portrait.name = "TextureRect7"
	# 52x52 canvas (Miyabi + her spirit) with the feet at ~83% height, like the other portraits.
	portrait.texture = preload("res://Scene/Character/Miyabi/MiyabiSprites.gd").texture("miyabi_portrait.png")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	object_container.add_child(portrait)
	# Keep the trailing MarginContainer spacer as the last child.
	object_container.move_child(portrait, object_container.get_child_count() - 2)

func _add_doraemon_portrait() -> void:
	var portrait := TextureRect.new()
	portrait.name = "TextureRect6"
	# 52x52 canvas with the feet at ~80% height, matching the other hero portraits.
	portrait.texture = preload("res://Scene/Character/Doraemon/DoraemonSprites.gd").texture("doraemon_portrait.png")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	object_container.add_child(portrait)
	# Keep the trailing MarginContainer spacer as the last child.
	object_container.move_child(portrait, object_container.get_child_count() - 2)

func _add_yugi_portrait() -> void:
	var yugi_portrait := TextureRect.new()
	yugi_portrait.name = "TextureRect5"
	# The supplied icon has a 1px pale-green border on its left and bottom edges.
	# Exclude that border without broadening the chroma key over character colors.
	var yugi_icon_source: Texture2D = preload("res://Assets/Character/Yugi/icon.png")
	var yugi_icon := AtlasTexture.new()
	yugi_icon.atlas = yugi_icon_source
	yugi_icon.region = Rect2(1, 0, yugi_icon_source.get_width() - 1, yugi_icon_source.get_height() - 1)
	# Pad the portrait to the selection cell instead of enlarging the tightly
	# cropped image to fill it. Keeps Yugi comparable to the other hero icons.
	var icon_padding := Vector2(104, 104) - yugi_icon.region.size
	# Other portraits place their feet near y=103 on a 128px canvas.
	# Match that baseline on our 104px canvas, accounting for Yugi's last row.
	var yugi_top_padding := roundf(103.0 * 104.0 / 128.0) - (yugi_icon.region.size.y - 1.0)
	yugi_icon.margin = Rect2(Vector2(icon_padding.x * 0.5, yugi_top_padding), icon_padding)
	yugi_icon.filter_clip = true
	yugi_portrait.texture = yugi_icon
	yugi_portrait.material = preload("res://Scene/Character/Yugi/YugiSprites.gd").material()
	yugi_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	yugi_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	object_container.add_child(yugi_portrait)
	# Keep the trailing MarginContainer spacer as the last child.
	object_container.move_child(yugi_portrait, object_container.get_child_count() - 2)

func _build_hero_details_and_seed_bar() -> void:
	var main_vbox := $PanelContainer/MarginContainer/VBoxContainer as VBoxContainer
	main_vbox.add_theme_constant_override("separation", 10)

	# 1. Thanh tiêu đề trên cùng
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(header_hbox)
	main_vbox.move_child(header_hbox, 0)

	var back_btn := UITheme.create_button("MAIN MENU", "", Vector2(150, 34), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 12)
	back_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://Menu/main menu/main_menu.tscn")
	)
	header_hbox.add_child(back_btn)

	var title_lbl := Label.new()
	title_lbl.text = "THE FELLOWSHIP VANGUARD — SELECT YOUR CHAMPION"
	UITheme.style_header_label(title_lbl, 17, UITheme.COLOR_TEXT_GOLD)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_hbox.add_child(title_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(150, 0)
	header_hbox.add_child(spacer)

	# 2. Bảng Hồ Sơ Anh Hùng
	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_GOLD_BORDER, 2, 6, 16, 12))
	main_vbox.add_child(info_panel)
	main_vbox.move_child(info_panel, 2)

	var dossier_vbox := VBoxContainer.new()
	dossier_vbox.add_theme_constant_override("separation", 8)
	info_panel.add_child(dossier_vbox)

	# Tên & Vai trò
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 8)
	hero_name_label = Label.new()
	UITheme.style_header_label(hero_name_label, 17, Color(1.0, 0.88, 0.38))
	name_row.add_child(hero_name_label)
	dossier_vbox.add_child(name_row)

	# Tiểu sử ngắn
	hero_lore_label = Label.new()
	hero_lore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_lore_label.add_theme_font_override("font", UITheme.FONT_BODY)
	hero_lore_label.add_theme_font_size_override("font_size", 13)
	hero_lore_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))
	dossier_vbox.add_child(hero_lore_label)

	# Hàng 4 Chỉ số có Icon Pixel Art
	var stats_row := HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 24)
	dossier_vbox.add_child(stats_row)

	stat_hp_label = _create_stat_badge(stats_row, "HP:", Color(1.0, 0.45, 0.48))
	stat_armor_label = _create_stat_badge(stats_row, "ARMOR:", Color(0.48, 0.82, 1.0))
	stat_dmg_label = _create_stat_badge(stats_row, "DMG:", Color(1.0, 0.82, 0.38))
	stat_spd_label = _create_stat_badge(stats_row, "SPD:", Color(0.55, 0.95, 0.68))

	# Khung Tuyệt Kỹ
	var skill_panel := PanelContainer.new()
	skill_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER, 1, 4, 12, 8))
	dossier_vbox.add_child(skill_panel)

	var skill_text_vbox := VBoxContainer.new()
	skill_text_vbox.add_theme_constant_override("separation", 3)
	skill_panel.add_child(skill_text_vbox)

	skill_q_label = Label.new()
	skill_q_label.add_theme_font_override("font", UITheme.FONT_BODY)
	skill_q_label.add_theme_font_size_override("font_size", 13)
	skill_q_label.add_theme_color_override("font_color", Color(0.58, 0.94, 1.0))
	skill_text_vbox.add_child(skill_q_label)

	skill_rmb_label = Label.new()
	skill_rmb_label.add_theme_font_override("font", UITheme.FONT_BODY)
	skill_rmb_label.add_theme_font_size_override("font_size", 13)
	skill_rmb_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.65))
	skill_text_vbox.add_child(skill_rmb_label)

	# 3. Thanh Mật mã định mệnh & Nút Vào Hầm Ngục
	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(bottom_hbox)
	main_vbox.move_child(bottom_hbox, 3)

	var seed_lbl := Label.new()
	seed_lbl.text = "DUNGEON SEED:"
	UITheme.style_header_label(seed_lbl, 14, UITheme.COLOR_TEXT_GOLD)
	bottom_hbox.add_child(seed_lbl)

	seed_input = LineEdit.new()
	seed_input.custom_minimum_size = Vector2(180, 34)
	seed_input.max_length = 32
	seed_input.text = GameManager.current_seed if get_node_or_null("/root/GameManager") != null else "MORIA-EXPEDITION"
	UITheme.style_line_edit(seed_input, 13)
	bottom_hbox.add_child(seed_input)

	var rnd_btn := UITheme.create_button("RANDOM", "", Vector2(120, 34), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 13)
	rnd_btn.pressed.connect(func():
		if get_node_or_null("/root/GameManager") != null:
			var s: String = GameManager.generate_random_seed()
			GameManager.set_seed(s)
			seed_input.text = s
	)
	bottom_hbox.add_child(rnd_btn)

	hero_selection_button.text = "ENTER THE MINES OF MORIA"
	hero_selection_button.custom_minimum_size = Vector2(320, 44)
	UITheme.style_button(hero_selection_button, "", UITheme.COLOR_GOLD_BORDER_HOVER, UITheme.COLOR_BG_DARK, 16)

func _create_stat_badge(parent: Container, label_prefix: String, color: Color) -> Label:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	var pre_lbl := Label.new()
	pre_lbl.text = label_prefix
	pre_lbl.add_theme_font_override("font", UITheme.FONT_TITLE)
	pre_lbl.add_theme_font_size_override("font_size", 12)
	pre_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	hbox.add_child(pre_lbl)
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	hbox.add_child(lbl)
	parent.add_child(hbox)
	return lbl

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT or event.keycode == KEY_A:
			_on_previous_button_pressed()
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			_on_next_button_pressed()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_hero_selection_button_pressed()
		elif event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://Menu/main menu/main_menu.tscn")

func _on_previous_button_pressed() -> void:
	_select_index(selected_index - 1)

func _on_next_button_pressed() -> void:
	_select_index(selected_index + 1)

func _select_index(index: int) -> void:
	if portraits.is_empty():
		return
	selected_index = clampi(index, 0, portraits.size() - 1)
	_select_deselect_highlight()
	_update_hero_info_display()
	_tween_scroll(_get_portrait_scroll(selected_index))

func _get_portrait_scroll(index: int) -> float:
	var portrait := portraits[index]
	var center_x := portrait.get_global_rect().get_center().x
	var marker_x := selection_marker.get_global_rect().get_center().x
	var scrollbar := scroll_container.get_h_scroll_bar()
	return clampf(
		scroll_container.scroll_horizontal + center_x - marker_x,
		scrollbar.min_value,
		maxf(scrollbar.min_value, scrollbar.max_value - scrollbar.page)
	)

func _tween_scroll(scroll_value: float) -> void:
	if scroll_tween != null and scroll_tween.is_running():
		scroll_tween.kill()
	target_scroll = scroll_value
	hero_selection_button.disabled = true
	scroll_tween = create_tween()
	scroll_tween.tween_property(scroll_container, "scroll_horizontal", roundi(target_scroll), 0.18)
	scroll_tween.finished.connect(_on_scroll_finished)
	previous_button.disabled = selected_index == 0
	next_button.disabled = selected_index == portraits.size() - 1

func _on_scroll_finished() -> void:
	_select_deselect_highlight()
	_update_buttons()
	_update_hero_info_display()

func get_selected_value() -> TextureRect:
	var marker_x := selection_marker.get_global_rect().get_center().x
	var selected: TextureRect = null
	var nearest_distance: float = INF
	for portrait in portraits:
		var distance := absf(portrait.get_global_rect().get_center().x - marker_x)
		if distance < nearest_distance:
			nearest_distance = distance
			selected = portrait
	return selected

func _select_deselect_highlight() -> void:
	for i in range(portraits.size()):
		portraits[i].scale = Vector2.ONE
		if i == selected_index:
			portraits[i].modulate = Color(1.20, 1.18, 1.05, 1.0)
		else:
			portraits[i].modulate = Color(0.68, 0.70, 0.78, 0.88)

func _update_hero_info_display() -> void:
	if hero_name_label == null or get_node_or_null("/root/GameManager") == null:
		return
	if GameManager.has_method("refresh_balance_data"):
		GameManager.refresh_balance_data()
	var info: Dictionary = GameManager.CHARACTER_INFO[clampi(selected_index, 0, GameManager.CHARACTER_INFO.size() - 1)]
	hero_name_label.text = "%s  —  %s  •  %s" % [
		String(info.get("name", "Hero")).to_upper(),
		String(info.get("role", "")),
		String(info.get("weapon", ""))
	]
	hero_lore_label.text = String(info.get("lore", ""))
	stat_hp_label.text = "Vitality: %d" % int(info.get("hp", 4))
	stat_armor_label.text = "Armor: %d" % int(info.get("armor", 1))
	stat_dmg_label.text = "Damage: %d" % int(info.get("damage", 1))
	stat_spd_label.text = "Speed: %d" % int(info.get("speed", 160))

	if skill_icon_rect != null:
		skill_icon_rect.texture = UITheme.get_icon(String(info.get("skill_icon", "skill_slash")))
	skill_q_label.text = String(info.get("skill_q", ""))
	skill_rmb_label.text = String(info.get("skill_rmb", ""))

func _update_buttons() -> void:
	previous_button.disabled = portraits.is_empty() or selected_index == 0
	next_button.disabled = portraits.is_empty() or selected_index == portraits.size() - 1
	hero_selection_button.disabled = (
		portraits.is_empty() or selected_index >= character_scenes.size()
		or character_scenes[selected_index] == null
	)

func _on_hero_selection_button_pressed() -> void:
	if hero_selection_button.disabled:
		return
	if get_node_or_null("/root/GameManager") != null:
		GameManager.set_character_by_index(selected_index)
		var chosen_seed: String = seed_input.text if seed_input != null else GameManager.current_seed
		GameManager.start_new_run(chosen_seed, false, [])
	var error := get_tree().change_scene_to_file(game_world_path)
	if error != OK:
		push_error("Could not open game world: %s — error code %s" % [game_world_path, error])
