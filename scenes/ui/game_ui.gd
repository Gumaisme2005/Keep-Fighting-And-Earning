extends CanvasLayer

const UITheme = preload("res://scenes/ui/ui_theme.gd")
const SLOT_SCENE = preload("res://scenes/ui/inventory_slot.tscn")
const HOTBAR_SIZE = 9
const BAG_SIZE = 16

@export var heart_full: Texture2D
@export var heart_empty: Texture2D
@export var shield_full: Texture2D
@export var shield_empty: Texture2D

@onready var hotbar_container: HBoxContainer = $HotbarBG/HotbarContainer
@onready var heart_bar: HBoxContainer = $HUD/VBoxContainer/HBoxHP/HeartBar
@onready var shield_bar: HBoxContainer = $HUD/VBoxContainer/HBoxShield/ShieldBar

var hotbar_slots: Array = []
var bag_slots: Array = []
var equip_helmet_slot: TextureButton = null
var equip_armor_slot: TextureButton = null
var equip_weapon_slot: TextureButton = null

var player: Node2D = null
var inventory: Node = null
var dungeon_map: TileMap = null

# --- MOBA STATUS HUD (BARS & NUMBERS) ---
var hero_name_label: Label = null
var hero_dmg_label: Label = null
var player_hp_bar: ProgressBar = null
var player_hp_text: Label = null
var player_armor_bar: ProgressBar = null
var player_armor_text: Label = null

# --- CÁC THÀNH PHẦN UI MỞ RỘNG ---
var stats_summary_label: Label = null
var seed_label: Label = null
var floor_kills_label: Label = null
var skill_q_label: Label = null
var skill_rmb_panel: PanelContainer = null
var skill_rmb_label: Label = null
var bag_button: Button = null

var boss_panel: PanelContainer = null
var boss_name_label: Label = null
var boss_hp_bar: ProgressBar = null
var boss_hp_text: Label = null

var banner_panel: PanelContainer = null
var banner_icon: TextureRect = null
var banner_label: Label = null
var toast_label: Label = null
var replay_banner: PanelContainer = null

var inventory_modal: PanelContainer = null
var equip_stats_label: Label = null
var minimap_control: Control = null
var minimap_panel: PanelContainer = null
var minimap_expanded: bool = false
var mute_btn: Button = null

class MinimapCanvas extends Control:
	var tilemap: TileMap = null

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.10, 0.92), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.68, 0.55, 0.28, 0.90), false, 2.0)

		if tilemap == null or not is_instance_valid(tilemap):
			return
		var positions: Array = tilemap.get("room_positions")
		var types: Array = tilemap.get("room_types")
		var edges: Array = tilemap.get("edges")
		var managers: Dictionary = tilemap.get("room_managers")
		var visited: Dictionary = tilemap.get("visited_rooms")
		if positions == null or positions.is_empty():
			return

		var min_gx: int = positions[0].x
		var max_gx: int = positions[0].x
		var min_gy: int = positions[0].y
		var max_gy: int = positions[0].y
		for p in positions:
			min_gx = mini(min_gx, p.x)
			max_gx = maxi(max_gx, p.x)
			min_gy = mini(min_gy, p.y)
			max_gy = maxi(max_gy, p.y)

		var span_x: float = maxf(1.0, float(max_gx - min_gx + 1))
		var span_y: float = maxf(1.0, float(max_gy - min_gy + 1))
		var pad: float = 16.0
		var avail_w: float = size.x - pad * 2.0
		var avail_h: float = size.y - pad * 2.0
		var step: float = minf(avail_w / span_x, avail_h / span_y)
		step = clampf(step, 14.0, 28.0)

		var total_w: float = (max_gx - min_gx) * step
		var total_h: float = (max_gy - min_gy) * step
		var origin := Vector2((size.x - total_w) * 0.5, (size.y - total_h) * 0.5)

		var pos_to_screen := {}
		for i in range(positions.size()):
			var gp: Vector2i = positions[i]
			pos_to_screen[gp] = origin + Vector2((gp.x - min_gx) * step, (gp.y - min_gy) * step)

		if edges != null:
			for edge in edges:
				var u: Vector2i = edge[0]
				var v: Vector2i = edge[1]
				var idx_u: int = positions.find(u)
				var idx_v: int = positions.find(v)
				var u_vis: bool = visited != null and visited.has(idx_u)
				var v_vis: bool = visited != null and visited.has(idx_v)
				if u_vis and v_vis:
					if pos_to_screen.has(u) and pos_to_screen.has(v):
						draw_line(pos_to_screen[u], pos_to_screen[v], Color(0.45, 0.52, 0.65, 0.85), 2.5)
				elif u_vis and not v_vis:
					if pos_to_screen.has(u) and pos_to_screen.has(v):
						var mid: Vector2 = pos_to_screen[u].lerp(pos_to_screen[v], 0.42)
						draw_line(pos_to_screen[u], mid, Color(0.35, 0.42, 0.52, 0.45), 2.0)
				elif v_vis and not u_vis:
					if pos_to_screen.has(u) and pos_to_screen.has(v):
						var mid: Vector2 = pos_to_screen[v].lerp(pos_to_screen[u], 0.42)
						draw_line(pos_to_screen[v], mid, Color(0.35, 0.42, 0.52, 0.45), 2.0)

		var current_room_idx: int = -1
		if tilemap.has_method("get_player_room_index"):
			current_room_idx = tilemap.get_player_room_index()

		var pulse: float = (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
		var room_box := Vector2(step * 0.66, step * 0.66)
		for i in range(positions.size()):
			# Sương mù Đế Chế (Fog of War): Phòng chưa đặt chân tới thì hoàn toàn là màn đêm đen
			if visited == null or not visited.has(i):
				continue

			var gp: Vector2i = positions[i]
			var center: Vector2 = pos_to_screen[gp]
			var rect := Rect2(center - room_box * 0.5, room_box)
			var r_type: int = types[i] if i < types.size() else 1
			var col := Color(0.4, 0.45, 0.52)

			if r_type == 0: # START
				col = Color(0.2, 0.85, 0.45)
			elif r_type == 2: # TREASURE
				col = Color(0.95, 0.8, 0.2)
			elif r_type == 3: # BOSS
				col = Color(0.92, 0.22, 0.25)
			else: # COMBAT
				if managers != null and managers.has(i) and is_instance_valid(managers[i]):
					if managers[i].is_locked:
						col = Color(1.0, 0.55, 0.15)
					elif managers[i].is_cleared:
						col = Color(0.25, 0.68, 0.95)
					elif visited.has(i):
						col = Color(0.55, 0.62, 0.72)

			draw_rect(rect, col, true)
			draw_rect(rect, Color(0.1, 0.1, 0.15, 0.95), false, 1.0)

			if i == current_room_idx:
				draw_rect(rect.grow(2.0), Color(1.0, 1.0, 1.0, 0.65 + pulse * 0.35), false, 2.0)

		# Vẽ chính xác vị trí thực tế (real-time) của người chơi trong phòng và trên hành lang
		var player_screen_pos: Vector2 = pos_to_screen.get(Vector2i.ZERO, origin)
		if tilemap.has_method("get_player_exact_grid_position"):
			var exact_grid: Vector2 = tilemap.get_player_exact_grid_position()
			player_screen_pos = origin + Vector2(
				(exact_grid.x - float(min_gx)) * step,
				(exact_grid.y - float(min_gy)) * step
			)
			player_screen_pos.x = clampf(player_screen_pos.x, 6.0, size.x - 6.0)
			player_screen_pos.y = clampf(player_screen_pos.y, 6.0, size.y - 6.0)
		elif current_room_idx >= 0 and current_room_idx < positions.size():
			player_screen_pos = pos_to_screen[positions[current_room_idx]]

		draw_circle(player_screen_pos, 4.8 + pulse * 1.6, Color(0.20, 0.95, 1.0, 0.35))
		draw_circle(player_screen_pos, 3.6, Color(0.05, 0.08, 0.12, 0.95))
		draw_circle(player_screen_pos, 2.6, Color(0.35, 1.0, 0.95, 1.0))
		draw_circle(player_screen_pos, 1.4, Color.WHITE)

func _ready() -> void:
	add_to_group("game_ui")

	if $HotbarBG != null:
		$HotbarBG.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if $HUD != null:
		$HUD.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Hide legacy individual heart/shield icon containers
	if has_node("HUD/VBoxContainer/HBoxHP"):
		$HUD/VBoxContainer/HBoxHP.visible = false
	if has_node("HUD/VBoxContainer/HBoxShield"):
		$HUD/VBoxContainer/HBoxShield.visible = false

	for i in range(HOTBAR_SIZE):
		var slot = SLOT_SCENE.instantiate()
		hotbar_container.add_child(slot)
		slot.slot_index = i
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_right_clicked.connect(_on_slot_right_clicked)
		hotbar_slots.append(slot)

	_build_enhanced_ui()

	await get_tree().process_frame
	_connect_to_player_and_map()

func _build_enhanced_ui() -> void:
	# 1. MOBA-Style Health & Armor Status Panel (League of Legends style)
	var moba_box := VBoxContainer.new()
	moba_box.add_theme_constant_override("separation", 3)
	moba_box.custom_minimum_size = Vector2(210, 0)

	# Dòng tiêu đề: Tên Tướng + Chỉ số Sát thương
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)

	hero_name_label = Label.new()
	hero_name_label.add_theme_font_override("font", UITheme.FONT_TITLE)
	hero_name_label.add_theme_font_size_override("font_size", 14)
	hero_name_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	hero_name_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.95))
	hero_name_label.add_theme_constant_override("outline_size", 2)
	hero_name_label.text = "HERO"
	header_row.add_child(hero_name_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)

	hero_dmg_label = Label.new()
	hero_dmg_label.add_theme_font_override("font", UITheme.FONT_BODY_BOLD)
	hero_dmg_label.add_theme_font_size_override("font_size", 11)
	hero_dmg_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50))
	hero_dmg_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.95))
	hero_dmg_label.add_theme_constant_override("outline_size", 2)
	hero_dmg_label.text = "⚔ 1 DMG"
	header_row.add_child(hero_dmg_label)
	moba_box.add_child(header_row)

	# Thanh Máu (Health ProgressBar kèm số hiển thị trung tâm)
	var hp_overlay := MarginContainer.new()
	hp_overlay.custom_minimum_size = Vector2(210, 18)

	player_hp_bar = ProgressBar.new()
	player_hp_bar.custom_minimum_size = Vector2(210, 18)
	player_hp_bar.show_percentage = false
	player_hp_bar.min_value = 0
	player_hp_bar.max_value = 100
	player_hp_bar.value = 100

	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.12, 0.07, 0.08, 0.92)
	hp_bg.border_color = Color(0.32, 0.16, 0.18, 0.95)
	hp_bg.set_border_width_all(1)
	hp_bg.set_corner_radius_all(3)
	player_hp_bar.add_theme_stylebox_override("background", hp_bg)

	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.18, 0.78, 0.36)
	hp_fill.set_corner_radius_all(3)
	player_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	hp_overlay.add_child(player_hp_bar)

	player_hp_text = Label.new()
	player_hp_text.add_theme_font_override("font", UITheme.FONT_BODY_BOLD)
	player_hp_text.add_theme_font_size_override("font_size", 10)
	player_hp_text.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	player_hp_text.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.02, 0.95))
	player_hp_text.add_theme_constant_override("outline_size", 3)
	player_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	player_hp_text.text = "100 / 100"
	hp_overlay.add_child(player_hp_text)
	moba_box.add_child(hp_overlay)

	# Thanh Giáp (Armor ProgressBar kèm số hiển thị trung tâm)
	var armor_overlay := MarginContainer.new()
	armor_overlay.custom_minimum_size = Vector2(210, 14)

	player_armor_bar = ProgressBar.new()
	player_armor_bar.custom_minimum_size = Vector2(210, 14)
	player_armor_bar.show_percentage = false
	player_armor_bar.min_value = 0
	player_armor_bar.max_value = 100
	player_armor_bar.value = 100

	var arm_bg := StyleBoxFlat.new()
	arm_bg.bg_color = Color(0.06, 0.10, 0.16, 0.92)
	arm_bg.border_color = Color(0.18, 0.28, 0.42, 0.95)
	arm_bg.set_border_width_all(1)
	arm_bg.set_corner_radius_all(3)
	player_armor_bar.add_theme_stylebox_override("background", arm_bg)

	var arm_fill := StyleBoxFlat.new()
	arm_fill.bg_color = Color(0.24, 0.62, 0.94)
	arm_fill.set_corner_radius_all(3)
	player_armor_bar.add_theme_stylebox_override("fill", arm_fill)
	armor_overlay.add_child(player_armor_bar)

	player_armor_text = Label.new()
	player_armor_text.add_theme_font_override("font", UITheme.FONT_BODY_BOLD)
	player_armor_text.add_theme_font_size_override("font_size", 9)
	player_armor_text.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	player_armor_text.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.95))
	player_armor_text.add_theme_constant_override("outline_size", 3)
	player_armor_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_armor_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	player_armor_text.text = "5 / 5"
	armor_overlay.add_child(player_armor_text)
	moba_box.add_child(armor_overlay)

	$HUD/VBoxContainer.add_child(moba_box)

	# 2. Panel Góc Trên Phải: Tầng, Hạ gục, Seed & Phím điều khiển nhanh
	var top_right := VBoxContainer.new()
	top_right.anchor_left = 1.0
	top_right.anchor_right = 1.0
	top_right.anchor_top = 0.0
	top_right.anchor_bottom = 0.0
	top_right.offset_left = -285.0
	top_right.offset_right = -12.0
	top_right.offset_top = 10.0
	top_right.offset_bottom = 115.0
	top_right.add_theme_constant_override("separation", 6)
	add_child(top_right)

	var run_info_panel := PanelContainer.new()
	run_info_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.06, 0.08, 0.13, 0.94), UITheme.COLOR_GOLD_BORDER, 2, 4, 8, 6))
	top_right.add_child(run_info_panel)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 4)
	run_info_panel.add_child(info_vbox)

	var flr_row := HBoxContainer.new()
	flr_row.add_theme_constant_override("separation", 6)
	floor_kills_label = Label.new()
	floor_kills_label.add_theme_font_size_override("font_size", 12)
	floor_kills_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	floor_kills_label.text = "Floor 1   •   Slain: 0"
	flr_row.add_child(floor_kills_label)
	info_vbox.add_child(flr_row)

	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 6)
	seed_label = Label.new()
	seed_label.add_theme_font_size_override("font_size", 11)
	seed_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	seed_label.text = "Seed: MORIA-EXPEDITION"
	seed_row.add_child(seed_label)
	info_vbox.add_child(seed_row)

	var seed_btn_hbox := HBoxContainer.new()
	seed_btn_hbox.add_theme_constant_override("separation", 4)
	info_vbox.add_child(seed_btn_hbox)

	var copy_btn := UITheme.create_button("Copy", "", Vector2(0, 24), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 10, 5, 4)
	copy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_btn.focus_mode = Control.FOCUS_NONE
	copy_btn.pressed.connect(_on_copy_seed_pressed)
	seed_btn_hbox.add_child(copy_btn)

	var save_seed_btn := UITheme.create_button("Save", "", Vector2(0, 24), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 10, 5, 4)
	save_seed_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_seed_btn.focus_mode = Control.FOCUS_NONE
	save_seed_btn.pressed.connect(_on_save_seed_pressed)
	seed_btn_hbox.add_child(save_seed_btn)

	var map_btn := UITheme.create_button("Map", "", Vector2(0, 24), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 10, 5, 4)
	map_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_btn.focus_mode = Control.FOCUS_NONE
	map_btn.pressed.connect(_toggle_minimap_size)
	seed_btn_hbox.add_child(map_btn)

	var is_muted_now: bool = (get_node_or_null("/root/AudioManager") != null and AudioManager.is_muted)
	mute_btn = UITheme.create_button("Audio", "", Vector2(0, 24), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 11, 5, 4)
	mute_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mute_btn.focus_mode = Control.FOCUS_NONE
	mute_btn.tooltip_text = "Toggle Sound & Music"
	mute_btn.pressed.connect(_on_toggle_mute_pressed)
	seed_btn_hbox.add_child(mute_btn)

	# 3. Minimap Góc Dưới Phía Bên Phải
	minimap_panel = PanelContainer.new()
	minimap_panel.name = "MinimapPanel"
	minimap_panel.anchor_left = 1.0
	minimap_panel.anchor_right = 1.0
	minimap_panel.anchor_top = 1.0
	minimap_panel.anchor_bottom = 1.0
	minimap_panel.offset_left = -195.0
	minimap_panel.offset_right = -10.0
	minimap_panel.offset_top = -158.0
	minimap_panel.offset_bottom = -10.0
	minimap_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.06, 0.08, 0.13, 0.94), UITheme.COLOR_GOLD_BORDER, 2, 4, 4, 4))
	add_child(minimap_panel)

	var mm_vbox := VBoxContainer.new()
	mm_vbox.add_theme_constant_override("separation", 2)
	minimap_panel.add_child(mm_vbox)

	var mm_title := Label.new()
	UITheme.style_header_label(mm_title, 11, UITheme.COLOR_TEXT_GOLD)
	mm_title.text = "DUNGEON MAP"
	mm_vbox.add_child(mm_title)

	minimap_control = MinimapCanvas.new()
	minimap_control.custom_minimum_size = Vector2(177, 122)
	minimap_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minimap_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	minimap_control.tooltip_text = "Dungeon Map:\nGreen: Entrance • Blue: Cleared • Orange: Combat • Gold: Treasure • Red: Boss Lair\nPress M to expand or collapse"
	mm_vbox.add_child(minimap_control)

	# 4. Thanh Máu Boss ở Chính Giữa Phía Trên
	boss_panel = PanelContainer.new()
	boss_panel.anchor_left = 0.5
	boss_panel.anchor_right = 0.5
	boss_panel.anchor_top = 0.0
	boss_panel.anchor_bottom = 0.0
	boss_panel.offset_left = -200.0
	boss_panel.offset_right = 200.0
	boss_panel.offset_top = 12.0
	boss_panel.offset_bottom = 70.0
	boss_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.14, 0.04, 0.06, 0.94), Color(0.95, 0.25, 0.3, 0.95), 2, 4, 10, 8))
	boss_panel.visible = false
	add_child(boss_panel)

	var boss_vbox := VBoxContainer.new()
	boss_vbox.add_theme_constant_override("separation", 4)
	boss_panel.add_child(boss_vbox)

	var boss_header := HBoxContainer.new()
	boss_header.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_header.add_theme_constant_override("separation", 8)
	boss_name_label = Label.new()
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_header_label(boss_name_label, 14, Color(1.0, 0.38, 0.38))
	boss_name_label.text = "BOSS"
	boss_header.add_child(boss_name_label)
	boss_vbox.add_child(boss_header)

	boss_hp_bar = ProgressBar.new()
	boss_hp_bar.custom_minimum_size = Vector2(360, 16)
	boss_hp_bar.max_value = 30
	boss_hp_bar.value = 30
	boss_hp_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.05, 0.05)
	bar_bg.set_corner_radius_all(3)
	var bar_fg := StyleBoxFlat.new()
	bar_fg.bg_color = Color(0.90, 0.18, 0.22)
	bar_fg.set_corner_radius_all(3)
	boss_hp_bar.add_theme_stylebox_override("background", bar_bg)
	boss_hp_bar.add_theme_stylebox_override("fill", bar_fg)
	boss_vbox.add_child(boss_hp_bar)

	boss_hp_text = Label.new()
	boss_hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boss_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.style_body_label(boss_hp_text, 12, Color.WHITE)
	boss_hp_text.text = "30 / 30 • Phase 1"
	boss_hp_bar.add_child(boss_hp_text)

	# 4. Thanh Kỹ Năng (Q / Chuột Phải) & Nút Mở Túi Đồ dưới đáy màn hình
	var bottom_bar := HBoxContainer.new()
	bottom_bar.anchor_left = 0.5
	bottom_bar.anchor_right = 0.5
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_left = -290.0
	bottom_bar.offset_right = 290.0
	bottom_bar.offset_top = -104.0
	bottom_bar.offset_bottom = -72.0
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_bar.add_theme_constant_override("separation", 10)
	add_child(bottom_bar)

	var q_panel := PanelContainer.new()
	q_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER, 2, 4, 10, 5))
	bottom_bar.add_child(q_panel)
	var q_hbox := HBoxContainer.new()
	q_hbox.add_theme_constant_override("separation", 6)
	skill_q_label = Label.new()
	skill_q_label.add_theme_font_size_override("font_size", 11)
	skill_q_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	skill_q_label.text = "Skill Q: READY"
	q_hbox.add_child(skill_q_label)
	q_panel.add_child(q_hbox)

	skill_rmb_panel = PanelContainer.new()
	skill_rmb_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER, 2, 4, 10, 5))
	skill_rmb_panel.visible = false
	bottom_bar.add_child(skill_rmb_panel)
	var rmb_hbox := HBoxContainer.new()
	rmb_hbox.add_theme_constant_override("separation", 6)
	skill_rmb_label = Label.new()
	skill_rmb_label.add_theme_font_size_override("font_size", 11)
	skill_rmb_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	skill_rmb_label.text = "Right Click: READY"
	rmb_hbox.add_child(skill_rmb_label)
	skill_rmb_panel.add_child(rmb_hbox)

	bag_button = UITheme.create_button("Backpack [B / I]", "", Vector2(180, 28), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 11)
	bag_button.focus_mode = Control.FOCUS_NONE
	bag_button.pressed.connect(toggle_inventory_modal)
	bottom_bar.add_child(bag_button)

	# 5. Thông báo Banner & Toast
	banner_panel = PanelContainer.new()
	banner_panel.anchor_left = 0.5
	banner_panel.anchor_right = 0.5
	banner_panel.anchor_top = 0.18
	banner_panel.anchor_bottom = 0.18
	banner_panel.offset_left = -250.0
	banner_panel.offset_right = 250.0
	banner_panel.offset_top = 0.0
	banner_panel.offset_bottom = 42.0
	banner_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.06, 0.08, 0.14, 0.92), Color(0.92, 0.75, 0.32, 0.95), 2, 4, 14, 8))
	banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_panel.visible = false
	add_child(banner_panel)

	var banner_hbox := HBoxContainer.new()
	banner_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_hbox.add_theme_constant_override("separation", 10)
	banner_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_panel.add_child(banner_hbox)

	banner_label = Label.new()
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 16)
	banner_label.add_theme_color_override("font_outline_color", Color.BLACK)
	banner_label.add_theme_constant_override("outline_size", 5)
	banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_hbox.add_child(banner_label)

	toast_label = Label.new()
	toast_label.anchor_left = 0.5
	toast_label.anchor_right = 0.5
	toast_label.anchor_top = 1.0
	toast_label.anchor_bottom = 1.0
	toast_label.offset_left = -240.0
	toast_label.offset_right = 240.0
	toast_label.offset_top = -134.0
	toast_label.offset_bottom = -108.0
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 13)
	toast_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_label.add_theme_constant_override("outline_size", 4)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.visible = false
	add_child(toast_label)

	# 6. Banner Chế độ Replay
	replay_banner = PanelContainer.new()
	replay_banner.anchor_left = 0.5
	replay_banner.anchor_right = 0.5
	replay_banner.anchor_top = 0.0
	replay_banner.anchor_bottom = 0.0
	replay_banner.offset_left = -230.0
	replay_banner.offset_right = 230.0
	replay_banner.offset_top = 74.0
	replay_banner.offset_bottom = 110.0
	replay_banner.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.18, 0.08, 0.28, 0.94), Color(0.82, 0.45, 1.0), 2, 4, 10, 6))
	replay_banner.visible = false
	add_child(replay_banner)

	var replay_hbox := HBoxContainer.new()
	replay_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	replay_hbox.add_theme_constant_override("separation", 10)
	replay_banner.add_child(replay_hbox)

	var replay_lbl := Label.new()
	replay_lbl.text = "REPLAYING COMBAT CHRONICLES"
	UITheme.style_header_label(replay_lbl, 13, Color(0.95, 0.78, 1.0))
	replay_hbox.add_child(replay_lbl)

	var stop_replay_btn := UITheme.create_button("Take Control", "", Vector2(160, 28), Color(0.95, 0.75, 0.35), Color(0.22, 0.14, 0.28, 0.95), 11)
	stop_replay_btn.pressed.connect(func():
		if get_node_or_null("/root/GameManager") != null:
			GameManager.is_replaying = false
		replay_banner.visible = false
		show_toast("Switched to direct control")
	)
	replay_hbox.add_child(stop_replay_btn)

	# 7. Cửa sổ Hành trang & Trang bị
	_build_inventory_modal()

func _build_inventory_modal() -> void:
	inventory_modal = PanelContainer.new()
	inventory_modal.anchor_left = 0.5
	inventory_modal.anchor_right = 0.5
	inventory_modal.anchor_top = 0.5
	inventory_modal.anchor_bottom = 0.5
	inventory_modal.offset_left = -250.0
	inventory_modal.offset_right = 250.0
	inventory_modal.offset_top = -175.0
	inventory_modal.offset_bottom = 155.0
	inventory_modal.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.07, 0.09, 0.15, 0.97), Color(0.88, 0.72, 0.34), 2, 6, 16, 12))
	inventory_modal.visible = false
	add_child(inventory_modal)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	inventory_modal.add_child(root_vbox)

	var header_hbox := HBoxContainer.new()
	root_vbox.add_child(header_hbox)

	var title_lbl := Label.new()
	var hero_name := "HERO"
	if get_node_or_null("/root/GameManager") != null:
		var info: Dictionary = GameManager.get_selected_character_info()
		hero_name = String(info.get("name", "HERO")).to_upper()
	title_lbl.text = "%s — EQUIPMENT & INVENTORY" % hero_name
	UITheme.style_header_label(title_lbl, 15, Color(1.0, 0.86, 0.35))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	var close_btn := UITheme.create_button("Close", "", Vector2(86, 28), Color(0.85, 0.4, 0.4), Color(0.20, 0.12, 0.14, 0.96), 12)
	close_btn.pressed.connect(toggle_inventory_modal)
	header_hbox.add_child(close_btn)

	var body_hbox := HBoxContainer.new()
	body_hbox.add_theme_constant_override("separation", 18)
	root_vbox.add_child(body_hbox)

	# Cột trái: 3 Ô Trang bị đang mặc
	var equip_vbox := VBoxContainer.new()
	equip_vbox.custom_minimum_size = Vector2(175, 0)
	equip_vbox.add_theme_constant_override("separation", 8)
	body_hbox.add_child(equip_vbox)

	var eq_hdr := Label.new()
	eq_hdr.text = "EQUIPPED GEAR — CLICK TO UNEQUIP:"
	UITheme.style_header_label(eq_hdr, 12, Color(0.72, 0.90, 1.0))
	equip_vbox.add_child(eq_hdr)

	var eq_slots_hbox := HBoxContainer.new()
	eq_slots_hbox.add_theme_constant_override("separation", 10)
	equip_vbox.add_child(eq_slots_hbox)

	equip_helmet_slot = _create_equip_slot("Helmet", "helmet", ItemData.ItemType.HELMET, eq_slots_hbox)
	equip_armor_slot = _create_equip_slot("Armor", "armor", ItemData.ItemType.ARMOR, eq_slots_hbox)
	equip_weapon_slot = _create_equip_slot("Weapon", "sword", ItemData.ItemType.WEAPON, eq_slots_hbox)

	equip_stats_label = Label.new()
	UITheme.style_body_label(equip_stats_label, 12, Color(0.90, 0.95, 0.85))
	equip_stats_label.text = "Bonus Attributes:\n+0 Damage • +0 Armor • +0 Health"
	equip_vbox.add_child(equip_stats_label)

	# Cột phải: Lưới 4x4 Túi đồ
	var bag_vbox := VBoxContainer.new()
	bag_vbox.add_theme_constant_override("separation", 6)
	body_hbox.add_child(bag_vbox)

	var bag_hdr := Label.new()
	bag_hdr.text = "BACKPACK STORAGE:"
	UITheme.style_header_label(bag_hdr, 12, Color(0.95, 0.85, 0.55))
	bag_vbox.add_child(bag_hdr)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	bag_vbox.add_child(grid)

	for i in range(BAG_SIZE):
		var slot = SLOT_SCENE.instantiate()
		slot.custom_minimum_size = Vector2(42, 42)
		slot.slot_index = i
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_right_clicked.connect(_on_slot_right_clicked)
		grid.add_child(slot)
		bag_slots.append(slot)

func _create_equip_slot(label_txt: String, icon_name: String, item_type: int, parent_box: Container) -> TextureButton:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	parent_box.add_child(vbox)

	var hdr := HBoxContainer.new()
	hdr.alignment = BoxContainer.ALIGNMENT_CENTER
	hdr.add_theme_constant_override("separation", 3)
	var lbl := Label.new()
	lbl.text = label_txt
	lbl.add_theme_font_size_override("font_size", 10)
	hdr.add_child(lbl)
	vbox.add_child(hdr)

	var slot = SLOT_SCENE.instantiate()
	slot.custom_minimum_size = Vector2(42, 42)
	slot.slot_index = -10 - item_type
	slot.pressed.connect(func():
		if inventory != null:
			inventory.unequip_item(item_type)
			if player != null and player.has_method("_on_equipment_changed"):
				player._on_equipment_changed()
	)
	vbox.add_child(slot)
	return slot

func _connect_to_player_and_map() -> void:
	if get_parent() and get_parent().has_node("Inventory"):
		player = get_parent()
	else:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]

	if player != null:
		if player.has_signal("stats_changed") and not player.stats_changed.is_connected(update_hud):
			player.stats_changed.connect(update_hud)
		if player.has_signal("skill_cooldown_changed") and not player.skill_cooldown_changed.is_connected(_on_skill_cooldown_changed):
			player.skill_cooldown_changed.connect(_on_skill_cooldown_changed)

		if player.has_node("Inventory"):
			inventory = player.get_node("Inventory")
			if not inventory.inventory_changed.is_connected(refresh_ui):
				inventory.inventory_changed.connect(refresh_ui)
			if not inventory.equipment_changed.is_connected(refresh_ui):
				inventory.equipment_changed.connect(refresh_ui)

		var rmb_cd: float = float(player.get("rmb_cd_max")) if player.get("rmb_cd_max") != null else 0.0
		if rmb_cd > 0.0 and skill_rmb_panel != null:
			skill_rmb_panel.visible = true

		_on_skill_cooldown_changed(0.0, 1.0, 0.0, rmb_cd)
		update_hud(player.hp, player.max_hp, player.current_armor, player.max_armor)
		refresh_ui()

	if player != null and player.get_parent() is TileMap:
		dungeon_map = player.get_parent()
	elif get_tree().current_scene and get_tree().current_scene.has_node("TileMap"):
		dungeon_map = get_tree().current_scene.get_node("TileMap")

	if dungeon_map != null:
		minimap_control.tilemap = dungeon_map
		if dungeon_map.has_signal("boss_spawned") and not dungeon_map.boss_spawned.is_connected(_on_boss_spawned):
			dungeon_map.boss_spawned.connect(_on_boss_spawned)
		if dungeon_map.has_signal("dungeon_generated") and not dungeon_map.dungeon_generated.is_connected(_on_dungeon_generated):
			dungeon_map.dungeon_generated.connect(_on_dungeon_generated)

	if get_node_or_null("/root/GameManager") != null:
		if not GameManager.stats_updated.is_connected(_on_game_stats_updated):
			GameManager.stats_updated.connect(_on_game_stats_updated)
		_on_game_stats_updated(GameManager.current_level, GameManager.enemies_killed)
		seed_label.text = "Seed: " + GameManager.current_seed
		replay_banner.visible = GameManager.is_replaying

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I or event.keycode == KEY_TAB or event.keycode == KEY_B:
			toggle_inventory_modal()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_G:
			_quick_drop_item()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_M:
			_toggle_minimap_size()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_N:
			_on_toggle_mute_pressed()
			get_viewport().set_input_as_handled()

func _quick_drop_item() -> void:
	if inventory != null and player != null and inventory.bag.size() > 0:
		var item = inventory.bag[0]
		var item_name: String = item.item_name if item != null else "Item"
		var drop_pos: Vector2 = player.global_position + Vector2(16, 0)
		if inventory.has_method("drop_item"):
			if inventory.drop_item(0, false, drop_pos):
				show_toast("Dropped 1x " + item_name)

func _on_toggle_mute_pressed() -> void:
	if get_node_or_null("/root/AudioManager") != null:
		var muted: bool = AudioManager.toggle_mute()
		if mute_btn != null:
			mute_btn.text = "Audio: Off" if muted else "Audio: On"
		show_toast("Audio Muted" if muted else "Audio Enabled")

func toggle_inventory_modal() -> void:
	if inventory_modal != null:
		inventory_modal.visible = not inventory_modal.visible
		refresh_ui()

func _toggle_minimap_size() -> void:
	if minimap_control == null:
		return
	minimap_expanded = not minimap_expanded
	if minimap_panel != null:
		if minimap_expanded:
			minimap_panel.offset_left = -330.0
			minimap_panel.offset_top = -250.0
			minimap_control.custom_minimum_size = Vector2(305, 205)
		else:
			minimap_panel.offset_left = -195.0
			minimap_panel.offset_top = -158.0
			minimap_control.custom_minimum_size = Vector2(177, 122)
	else:
		minimap_control.custom_minimum_size = Vector2(265, 200) if minimap_expanded else Vector2(177, 122)

func _on_copy_seed_pressed() -> void:
	var s: String = GameManager.current_seed if get_node_or_null("/root/GameManager") != null else "MORIA-EXPEDITION"
	DisplayServer.clipboard_set(s)
	show_toast("Copied Seed: " + s)

func _on_save_seed_pressed() -> void:
	if get_node_or_null("/root/GameManager") != null:
		GameManager.save_seed_entry(GameManager.current_seed)
		show_toast("Seed saved to Chronicles: " + GameManager.current_seed)

func _on_game_stats_updated(level: int, kills: int) -> void:
	if floor_kills_label != null:
		floor_kills_label.text = "Floor %d   •   Slain: %d" % [level, kills]
	if seed_label != null and get_node_or_null("/root/GameManager") != null:
		seed_label.text = "Seed: " + GameManager.current_seed

func _on_dungeon_generated() -> void:
	if boss_panel != null:
		boss_panel.visible = false
	if get_node_or_null("/root/GameManager") != null:
		_on_game_stats_updated(GameManager.current_level, GameManager.enemies_killed)

func _on_boss_spawned(boss: Node2D) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	boss_panel.visible = true
	var b_name: String = boss.get("BOSS_NAME") if boss.get("BOSS_NAME") != null else boss.name
	var b_hp: int = boss.get("hp") if boss.get("hp") != null else 30
	var b_max: int = boss.get("max_hp") if boss.get("max_hp") != null else 30
	_update_boss_bar(b_hp, b_max, 1, b_name)
	if boss.has_signal("boss_hp_changed") and not boss.boss_hp_changed.is_connected(_update_boss_bar):
		boss.boss_hp_changed.connect(_update_boss_bar)
	if not boss.tree_exited.is_connected(_on_boss_died):
		boss.tree_exited.connect(_on_boss_died)

func _update_boss_bar(c_hp: int, m_hp: int, phase: int, b_name: String) -> void:
	if boss_panel == null:
		return
	boss_panel.visible = c_hp > 0
	boss_name_label.text = b_name.to_upper()
	boss_hp_bar.max_value = max(1, m_hp)
	boss_hp_bar.value = clampi(c_hp, 0, m_hp)
	boss_hp_text.text = "%d / %d HP  •  Phase %d" % [c_hp, m_hp, phase]

func _on_boss_died() -> void:
	if boss_panel != null:
		boss_panel.visible = false

func _get_current_hero_skill_names() -> Dictionary:
	var q_name := "Skill Q"
	var rmb_name := "Right Click"
	if get_node_or_null("/root/GameManager") != null:
		var info: Dictionary = GameManager.get_selected_character_info()
		var full_q: String = String(info.get("skill_q", ""))
		if "—" in full_q:
			q_name = full_q.split("—")[0].strip_edges()
		elif ":" in full_q:
			q_name = full_q.split(":")[0].strip_edges()
		var full_rmb: String = String(info.get("skill_rmb", ""))
		if "—" in full_rmb:
			rmb_name = full_rmb.split("—")[0].strip_edges()
		elif ":" in full_rmb:
			rmb_name = full_rmb.split(":")[0].strip_edges()
	return {"q": q_name, "rmb": rmb_name}

func _on_skill_cooldown_changed(q_left: float, _q_max: float, rmb_left: float, rmb_max: float) -> void:
	var skill_names := _get_current_hero_skill_names()
	var q_title: String = skill_names.get("q", "Skill Q")
	var rmb_title: String = skill_names.get("rmb", "Right Click")

	if skill_q_label != null:
		if q_left <= 0.05:
			skill_q_label.text = "%s [Q]: READY" % q_title
			skill_q_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
		else:
			skill_q_label.text = "%s [Q]: %.1fs" % [q_title, q_left]
			skill_q_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)

	if skill_rmb_label != null and rmb_max > 0.0:
		if skill_rmb_panel != null:
			skill_rmb_panel.visible = true
		if rmb_left <= 0.05:
			skill_rmb_label.text = "%s [RMB]: READY" % rmb_title
			skill_rmb_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
		else:
			skill_rmb_label.text = "%s [RMB]: %.1fs" % [rmb_title, rmb_left]
			skill_rmb_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)

func update_hud(current_hp: int, max_hp: int, current_shield: int, max_shield: int) -> void:
	# 1. Cập nhật thanh Máu dạng số chuẩn MOBA (Health Bar & Numeric Text)
	if player_hp_bar != null:
		player_hp_bar.max_value = max(1, max_hp)
		player_hp_bar.value = clamp(current_hp, 0, max_hp)

		var hp_ratio := float(current_hp) / float(max(1, max_hp))
		var fill_style: StyleBoxFlat = player_hp_bar.get_theme_stylebox("fill").duplicate()
		if hp_ratio > 0.5:
			fill_style.bg_color = Color(0.18, 0.78, 0.36)
		elif hp_ratio > 0.25:
			fill_style.bg_color = Color(0.92, 0.65, 0.18)
		else:
			fill_style.bg_color = Color(0.88, 0.22, 0.22)
		player_hp_bar.add_theme_stylebox_override("fill", fill_style)

	if player_hp_text != null:
		player_hp_text.text = "%d / %d" % [current_hp, max_hp]

	# 2. Cập nhật thanh Giáp dạng số chuẩn MOBA (Armor Bar & Numeric Text)
	if player_armor_bar != null:
		player_armor_bar.max_value = max(1, max_shield)
		player_armor_bar.value = clamp(current_shield, 0, max_shield)

	if player_armor_text != null:
		player_armor_text.text = "%d / %d" % [current_shield, max_shield]

	# 3. Cập nhật Tiêu đề Tướng và Chỉ số Sát thương
	if hero_name_label != null:
		var hero_title := "HERO"
		if get_node_or_null("/root/GameManager") != null:
			var h_info: Dictionary = GameManager.get_selected_character_info()
			if h_info.has("name"):
				hero_title = String(h_info["name"]).to_upper()
		hero_name_label.text = hero_title

	if hero_dmg_label != null and player != null:
		var dmg = player.get_total_damage() if player.has_method("get_total_damage") else 1
		hero_dmg_label.text = "⚔ %d DMG" % dmg

func _on_slot_clicked(index: int) -> void:
	if inventory != null and player != null and index >= 0:
		inventory.use_or_equip_item(index, player)

func _on_slot_right_clicked(index: int) -> void:
	if inventory != null and player != null and index >= 0 and index < inventory.bag.size():
		var item = inventory.bag[index]
		var item_name: String = item.item_name if item != null else "Item"
		var drop_pos: Vector2 = player.global_position + Vector2(16, 0)
		if inventory.has_method("drop_item"):
			if inventory.drop_item(index, false, drop_pos):
				show_toast("Dropped 1x " + item_name)

func refresh_ui() -> void:
	if inventory == null:
		return
	for i in range(hotbar_slots.size()):
		if i < inventory.bag.size():
			hotbar_slots[i].set_item(inventory.bag[i])
		else:
			hotbar_slots[i].set_item(null)

	for i in range(bag_slots.size()):
		if i < inventory.bag.size():
			bag_slots[i].set_item(inventory.bag[i])
		else:
			bag_slots[i].set_item(null)

	if bag_button != null:
		bag_button.text = "Backpack: %d / %d [B]" % [inventory.bag.size(), inventory.max_slots]

	if equip_helmet_slot != null:
		equip_helmet_slot.set_item(inventory.equipped_helmet)
	if equip_armor_slot != null:
		equip_armor_slot.set_item(inventory.equipped_armor)
	if equip_weapon_slot != null:
		equip_weapon_slot.set_item(inventory.equipped_weapon)

	if equip_stats_label != null and player != null:
		var total_dmg = player.get_total_damage() if player.has_method("get_total_damage") else 1
		var extra_stats: Array[String] = []
		if inventory.has_method("get_magic_resistance") and inventory.get_magic_resistance() > 0:
			extra_stats.append("• Magic Resist: +%d" % inventory.get_magic_resistance())
		if inventory.has_method("get_speed_bonus") and inventory.get_speed_bonus() > 0.0:
			extra_stats.append("• Move Speed: +%d%%" % int(inventory.get_speed_bonus() * 100))
		if inventory.has_method("get_attack_speed_bonus") and inventory.get_attack_speed_bonus() > 0.0:
			extra_stats.append("• Attack Speed: +%d%%" % int(inventory.get_attack_speed_bonus() * 100))

		var extra_text := ("\n" + "\n".join(extra_stats)) if not extra_stats.is_empty() else ""
		equip_stats_label.text = "TOTAL ATTRIBUTES:\n• Attack Power: %d • Weapon: +%d\n• Physical Defense: +%d\n• Bonus Max HP: +%d%s" % [
			total_dmg,
			inventory.get_weapon_damage(),
			inventory.get_total_defense(),
			inventory.get_total_max_hp_bonus(),
			extra_text
		]

func show_banner(text: String, color: Color = Color.WHITE) -> void:
	if banner_panel == null or banner_label == null:
		return
	banner_label.text = text
	banner_label.add_theme_color_override("font_color", color)
	if banner_icon != null:
		if "BOSS" in text.to_upper():
			banner_icon.texture = UITheme.get_icon("skull")
		elif "PORTAL" in text.to_upper() or "GATEWAY" in text.to_upper() or "CỔNG" in text.to_upper() or "DỊCH CHUYỂN" in text.to_upper():
			banner_icon.texture = UITheme.get_icon("soul_stone")
		elif "CLEARED" in text.to_upper() or "SLAIN" in text.to_upper() or "VICTORY" in text.to_upper() or "DỌN SẠCH" in text.to_upper() or "HẠ GỤC" in text.to_upper():
			banner_icon.texture = UITheme.get_icon("trophy")
		else:
			banner_icon.texture = UITheme.get_icon("sword_royal")
	banner_panel.visible = true
	banner_panel.modulate.a = 1.0
	var tw = create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(banner_panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): banner_panel.visible = false)

func show_toast(text: String) -> void:
	if toast_label == null:
		return
	toast_label.text = text
	toast_label.visible = true
	toast_label.modulate.a = 1.0
	var tw = create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): toast_label.visible = false)

func spawn_damage_number(world_pos: Vector2, amount: int, color: Color = Color(1.0, 0.9, 0.3)) -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var lbl := Label.new()
	lbl.text = ("+" if color.g > 0.85 and color.r < 0.5 else "-") + str(amount)
	lbl.global_position = world_pos + Vector2(randf_range(-8.0, 8.0), -10.0)
	lbl.z_index = 50
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	get_tree().current_scene.add_child(lbl)

	var tw = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 22.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.55)
	tw.chain().tween_callback(lbl.queue_free)
