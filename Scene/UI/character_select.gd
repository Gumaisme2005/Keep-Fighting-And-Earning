extends Control

const UITheme = preload("res://Scene/UI/UITheme.gd")
const DUNGEON_BG_TEX: Texture2D = preload("res://Assets/UI/Background/Dungeon.png")

@export var character_scenes: Array[PackedScene] = [
	preload("res://Scene/Character/Player 3_Miya/player_3.tscn"),
	preload("res://Scene/Character/Player 2_Olaf/player_2.tscn"),
	preload("res://Scene/Character/Player 1_Pyrois/player.tscn"),
	preload("res://Scene/Character/Player 4_Charlotte/player_4.tscn"),
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

	var idx_counter: int = 0
	for child in object_container.get_children():
		if child is TextureRect:
			var p := child as TextureRect
			p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			p.custom_minimum_size = Vector2(104, 104)
			p.mouse_filter = Control.MOUSE_FILTER_STOP
			var captured_idx := idx_counter
			p.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					_select_index(captured_idx)
			)
			portraits.append(p)
			idx_counter += 1

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

func _build_hero_details_and_seed_bar() -> void:
	var main_vbox := $PanelContainer/MarginContainer/VBoxContainer as VBoxContainer
	main_vbox.add_theme_constant_override("separation", 10)

	# 1. Thanh tiêu đề trên cùng
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(header_hbox)
	main_vbox.move_child(header_hbox, 0)

	var back_btn := UITheme.create_button("Về Sảnh Chính", "arrow_left", Vector2(150, 34), Color(0.65, 0.72, 0.88), Color(0.12, 0.14, 0.22, 0.96), 12)
	back_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://Menu/main menu/main_menu.tscn")
	)
	header_hbox.add_child(back_btn)

	var title_box := UITheme.create_icon_header("soul_stone", "SẢNH ANH HÙNG — CHỌN THỢ SĂN & TỌA ĐỘ SEED", 18, Color(1.0, 0.88, 0.36), 24)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	header_hbox.add_child(title_box)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(150, 0)
	header_hbox.add_child(spacer)

	# 2. Bảng Hồ Sơ Anh Hùng (Hero Dossier Card)
	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.07, 0.09, 0.15, 0.95), Color(0.85, 0.68, 0.32, 0.95), 2, 6, 16, 12))
	main_vbox.add_child(info_panel)
	main_vbox.move_child(info_panel, 2)

	var dossier_vbox := VBoxContainer.new()
	dossier_vbox.add_theme_constant_override("separation", 8)
	info_panel.add_child(dossier_vbox)

	# Tên & Vai trò
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 8)
	name_row.add_child(UITheme.create_icon_rect("hero", 20))
	hero_name_label = Label.new()
	hero_name_label.add_theme_font_size_override("font_size", 16)
	hero_name_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.38))
	hero_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hero_name_label.add_theme_constant_override("outline_size", 4)
	name_row.add_child(hero_name_label)
	dossier_vbox.add_child(name_row)

	# Tiểu sử ngắn (Lore)
	hero_lore_label = Label.new()
	hero_lore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_lore_label.add_theme_font_size_override("font_size", 12)
	hero_lore_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))
	dossier_vbox.add_child(hero_lore_label)

	# Hàng 4 Chỉ số có Icon Pixel Art
	var stats_row := HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 24)
	dossier_vbox.add_child(stats_row)

	stat_hp_label = _create_stat_badge(stats_row, "heart", Color(1.0, 0.45, 0.48))
	stat_armor_label = _create_stat_badge(stats_row, "shield", Color(0.48, 0.82, 1.0))
	stat_dmg_label = _create_stat_badge(stats_row, "sword", Color(1.0, 0.82, 0.38))
	stat_spd_label = _create_stat_badge(stats_row, "boots", Color(0.55, 0.95, 0.68))

	# Khung Tuyệt Kỹ
	var skill_panel := PanelContainer.new()
	skill_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.10, 0.13, 0.21, 0.92), Color(0.38, 0.58, 0.82, 0.8), 1, 4, 12, 8))
	dossier_vbox.add_child(skill_panel)

	var skill_hbox := HBoxContainer.new()
	skill_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_hbox.add_theme_constant_override("separation", 12)
	skill_panel.add_child(skill_hbox)

	skill_icon_rect = UITheme.create_icon_rect("skill_shield", 28)
	skill_hbox.add_child(skill_icon_rect)

	var skill_text_vbox := VBoxContainer.new()
	skill_text_vbox.add_theme_constant_override("separation", 3)
	skill_hbox.add_child(skill_text_vbox)

	skill_q_label = Label.new()
	skill_q_label.add_theme_font_size_override("font_size", 12)
	skill_q_label.add_theme_color_override("font_color", Color(0.58, 0.94, 1.0))
	skill_text_vbox.add_child(skill_q_label)

	skill_rmb_label = Label.new()
	skill_rmb_label.add_theme_font_size_override("font_size", 12)
	skill_rmb_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.65))
	skill_text_vbox.add_child(skill_rmb_label)

	# 3. Thanh La Bàn Seed & Nút Vào Hầm Ngục
	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(bottom_hbox)
	main_vbox.move_child(bottom_hbox, 3)

	bottom_hbox.add_child(UITheme.create_icon_header("seed", "Tọa độ Seed:", 13, Color(0.65, 0.95, 0.78), 18))

	seed_input = LineEdit.new()
	seed_input.custom_minimum_size = Vector2(180, 34)
	seed_input.max_length = 32
	seed_input.text = GameManager.current_seed if get_node_or_null("/root/GameManager") != null else "ALOALO1234"
	UITheme.style_line_edit(seed_input, 13)
	bottom_hbox.add_child(seed_input)

	var rnd_btn := UITheme.create_button("Đổi Seed", "crystal", Vector2(115, 34), Color(0.52, 0.78, 0.98), Color(0.12, 0.16, 0.26, 0.96), 12)
	rnd_btn.pressed.connect(func():
		if get_node_or_null("/root/GameManager") != null:
			var s := GameManager.generate_random_seed()
			GameManager.set_seed(s)
			seed_input.text = s
	)
	bottom_hbox.add_child(rnd_btn)

	hero_selection_button.text = "XUẤT KÍCH VÀO HẦM NGỤC (ENTER)"
	hero_selection_button.custom_minimum_size = Vector2(300, 42)
	UITheme.style_button(hero_selection_button, "sword_royal", Color(0.96, 0.78, 0.28, 1.0), Color(0.18, 0.15, 0.26, 0.98), 15)

func _create_stat_badge(parent: Container, icon_name: String, color: Color) -> Label:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.add_child(UITheme.create_icon_rect(icon_name, 18))
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
		if i == selected_index:
			portraits[i].modulate = Color(1.15, 1.12, 1.0, 1.0)
			portraits[i].scale = Vector2(1.08, 1.08)
		else:
			portraits[i].modulate = Color(0.38, 0.40, 0.48, 0.85)
			portraits[i].scale = Vector2.ONE

func _update_hero_info_display() -> void:
	if hero_name_label == null or get_node_or_null("/root/GameManager") == null:
		return
	var info: Dictionary = GameManager.CHARACTER_INFO[clampi(selected_index, 0, GameManager.CHARACTER_INFO.size() - 1)]
	hero_name_label.text = "%s  —  %s  (%s)" % [
		String(info.get("name", "Hero")).to_upper(),
		String(info.get("role", "")),
		String(info.get("weapon", ""))
	]
	hero_lore_label.text = String(info.get("lore", ""))
	stat_hp_label.text = "Máu: %d" % int(info.get("hp", 4))
	stat_armor_label.text = "Giáp: %d" % int(info.get("armor", 1))
	stat_dmg_label.text = "Sát thương: %d" % int(info.get("damage", 1))
	stat_spd_label.text = "Tốc độ: %d" % int(info.get("speed", 160))

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
		var chosen_seed := seed_input.text if seed_input != null else GameManager.current_seed
		GameManager.start_new_run(chosen_seed, false, [])
	var error := get_tree().change_scene_to_file(game_world_path)
	if error != OK:
		push_error("Could not open game world: %s (error %s)" % [game_world_path, error])
