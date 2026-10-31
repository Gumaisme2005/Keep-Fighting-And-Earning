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
		"Nhạc: TẮT" if is_muted_init else "Nhạc: BẬT",
		"speaker_off" if is_muted_init else "speaker_on",
		Vector2(126, 34),
		Color(0.85, 0.72, 0.98),
		Color(0.12, 0.10, 0.18, 0.94),
		12
	)
	audio_btn.anchor_left = 1.0
	audio_btn.anchor_right = 1.0
	audio_btn.offset_left = -146.0
	audio_btn.offset_right = -20.0
	audio_btn.offset_top = 18.0
	audio_btn.offset_bottom = 52.0
	audio_btn.pressed.connect(func():
		if get_node_or_null("/root/AudioManager") != null:
			var m: bool = AudioManager.toggle_mute()
			audio_btn.text = "Nhạc: TẮT" if m else "Nhạc: BẬT"
			audio_btn.icon = UITheme.get_icon("speaker_off" if m else "speaker_on")
	)
	add_child(audio_btn)

	var top_vbox := get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	if top_vbox != null:
		top_vbox.add_theme_constant_override("separation", 6)

	var title_lbl := get_node_or_null("MarginContainer/VBoxContainer/Label") as Label
	if title_lbl != null:
		title_lbl.text = "KEEP FIGHTING & EARNING"
		title_lbl.add_theme_font_size_override("font_size", 52)
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.36))
		title_lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.08, 1.0))
		title_lbl.add_theme_constant_override("outline_size", 14)

		var sub_hbox := HBoxContainer.new()
		sub_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		sub_hbox.add_theme_constant_override("separation", 10)
		sub_hbox.add_child(UITheme.create_icon_rect("soul_stone", 24))
		var sub_lbl := Label.new()
		sub_lbl.text = "BIÊN NIÊN SỬ TRUNG ĐỊA: HẦM MỎ MORIA  —  PROCEDURAL DUNGEON ROGUELIKE"
		sub_lbl.add_theme_font_size_override("font_size", 14)
		sub_lbl.add_theme_color_override("font_color", Color(0.62, 0.90, 1.0))
		sub_lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.06, 1.0))
		sub_lbl.add_theme_constant_override("outline_size", 5)
		sub_hbox.add_child(sub_lbl)
		sub_hbox.add_child(UITheme.create_icon_rect("soul_stone", 24))
		top_vbox.add_child(sub_hbox)

	var sep3 := get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/Seperator3") as Control
	if sep3 != null:
		sep3.visible = false

	var menu_vbox := $MarginContainer/HBoxContainer/VBoxContainer as VBoxContainer
	menu_vbox.add_theme_constant_override("separation", 10)

	# 1. Nút Bắt đầu (Chọn Anh Hùng)
	start_button.text = "BẮT ĐẦU CHIẾN DỊCH (CHỌN TƯỚNG)"
	start_button.custom_minimum_size = Vector2(360, 42)
	UITheme.style_button(start_button, "sword_royal", Color(0.95, 0.76, 0.28, 1.0), Color(0.16, 0.14, 0.24, 0.96), 15)

	# 2. Khung La Bàn Nhân Quả (Seed Bản Đồ)
	var seed_panel := PanelContainer.new()
	seed_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.08, 0.10, 0.16, 0.95), Color(0.45, 0.72, 0.92, 0.92), 2, 4, 12, 10))
	menu_vbox.add_child(seed_panel)
	menu_vbox.move_child(seed_panel, 1)

	var seed_vbox := VBoxContainer.new()
	seed_vbox.add_theme_constant_override("separation", 6)
	seed_panel.add_child(seed_vbox)

	var seed_header := UITheme.create_icon_header("seed", "THỦY TINH CẦU PALANTÍR — SEED HẦM MỎ MORIA (TÁI LẬP 100%):", 12, Color(0.65, 0.95, 0.78), 18)
	seed_vbox.add_child(seed_header)

	var seed_hbox := HBoxContainer.new()
	seed_hbox.add_theme_constant_override("separation", 6)
	seed_vbox.add_child(seed_hbox)

	seed_input = LineEdit.new()
	seed_input.custom_minimum_size = Vector2(180, 34)
	seed_input.max_length = 32
	seed_input.placeholder_text = "Nhập mã Seed..."
	seed_input.text = GameManager.current_seed if get_node_or_null("/root/GameManager") != null else "ALOALO1234"
	UITheme.style_line_edit(seed_input, 13)
	seed_input.text_changed.connect(func(new_txt: String):
		if get_node_or_null("/root/GameManager") != null:
			var clean := GameManager.sanitize_seed(new_txt)
			if not clean.is_empty():
				GameManager.set_seed(clean)
	)
	seed_hbox.add_child(seed_input)

	var rand_btn := UITheme.create_button("Ngẫu nhiên", "crystal", Vector2(108, 34), Color(0.55, 0.78, 0.98), Color(0.12, 0.16, 0.26, 0.96), 12)
	rand_btn.pressed.connect(func():
		if get_node_or_null("/root/GameManager") != null:
			var s := GameManager.generate_random_seed()
			GameManager.set_seed(s)
			seed_input.text = s
			_set_seed_status("Đã tạo tọa độ Seed mới: " + s)
	)
	seed_hbox.add_child(rand_btn)

	var save_btn := UITheme.create_button("Lưu", "chest", Vector2(76, 34), Color(0.92, 0.75, 0.32), Color(0.18, 0.15, 0.12, 0.96), 12)
	save_btn.pressed.connect(func():
		if get_node_or_null("/root/GameManager") != null:
			GameManager.set_seed(seed_input.text)
			seed_input.text = GameManager.current_seed
			GameManager.save_seed_entry(GameManager.current_seed, "Lưu từ Sảnh Chính")
			_refresh_seed_lists()
			_set_seed_status("Đã lưu Seed [" + GameManager.current_seed + "] vào Kho Lưu Trữ!")
	)
	seed_hbox.add_child(save_btn)

	seed_status_lbl = Label.new()
	seed_status_lbl.text = "Cùng một Seed luôn sinh ra cùng đồ thị phòng, bẫy, quái và vật phẩm."
	seed_status_lbl.add_theme_font_size_override("font_size", 11)
	seed_status_lbl.add_theme_color_override("font_color", Color(0.76, 0.82, 0.90))
	seed_vbox.add_child(seed_status_lbl)

	# 3. Nút Kho Seed Đã Lưu & Phát Lại Replay
	var seed_mgr_btn := UITheme.create_button("KHO SEED ĐÃ LƯU & REPLAY MỘT RUN", "scroll_gold", Vector2(360, 38), Color(0.85, 0.68, 0.32), Color(0.14, 0.15, 0.22, 0.96), 13)
	seed_mgr_btn.pressed.connect(func():
		_refresh_seed_lists()
		seed_modal.visible = true
		lore_modal.visible = false
		help_modal.visible = false
	)
	menu_vbox.add_child(seed_mgr_btn)
	menu_vbox.move_child(seed_mgr_btn, 2)

	# 4. Hàng 2 nút: Cốt Truyện / Bối Cảnh & Hướng Dẫn Điều Khiển
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 8)
	menu_vbox.add_child(info_row)
	menu_vbox.move_child(info_row, 3)

	var lore_btn := UITheme.create_button("BỐI CẢNH & CỐT TRUYỆN", "scroll_blue", Vector2(176, 36), Color(0.48, 0.78, 0.96), Color(0.12, 0.16, 0.24, 0.96), 12)
	lore_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lore_btn.pressed.connect(func():
		lore_modal.visible = true
		seed_modal.visible = false
		help_modal.visible = false
	)
	info_row.add_child(lore_btn)

	var help_btn := UITheme.create_button("ĐIỀU KHIỂN & CƠ CHẾ", "question", Vector2(176, 36), Color(0.55, 0.85, 0.68), Color(0.12, 0.18, 0.18, 0.96), 12)
	help_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_btn.pressed.connect(func():
		help_modal.visible = true
		seed_modal.visible = false
		lore_modal.visible = false
	)
	info_row.add_child(help_btn)

	# 5. Nút Thoát Game
	exit_button.text = "THOÁT GAME"
	exit_button.custom_minimum_size = Vector2(360, 36)
	UITheme.style_button(exit_button, "close", Color(0.82, 0.36, 0.36, 0.92), Color(0.18, 0.11, 0.13, 0.95), 13)

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
	seed_modal.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.06, 0.08, 0.13, 0.98), Color(0.92, 0.74, 0.32), 2, 6, 16, 14))
	seed_modal.visible = false
	add_child(seed_modal)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	seed_modal.add_child(root_vbox)

	var header := HBoxContainer.new()
	root_vbox.add_child(header)

	var title_box := UITheme.create_icon_header("scroll_gold", "KHO SEED ĐÃ LƯU & LỊCH SỬ REPLAY MỘT RUN", 16, Color(1.0, 0.86, 0.35), 22)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	var close_btn := UITheme.create_button("Đóng", "close", Vector2(84, 30), Color(0.85, 0.4, 0.4), Color(0.2, 0.12, 0.14, 0.96), 12)
	close_btn.pressed.connect(func(): seed_modal.visible = false)
	header.add_child(close_btn)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	root_vbox.add_child(cols)

	# Cột 1: Seed đã lưu
	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.09, 0.11, 0.17, 0.95), Color(0.38, 0.62, 0.85, 0.8), 1, 4, 10, 8))
	cols.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_vbox)

	left_vbox.add_child(UITheme.create_icon_header("chest", "DANH SÁCH SEED ĐÃ LƯU:", 13, Color(0.55, 0.90, 1.0), 18))

	var l_scroll := ScrollContainer.new()
	l_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(l_scroll)

	saved_list_vbox = VBoxContainer.new()
	saved_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saved_list_vbox.add_theme_constant_override("separation", 6)
	l_scroll.add_child(saved_list_vbox)

	# Cột 2: Lịch sử Run & Replay
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.09, 0.11, 0.17, 0.95), Color(0.75, 0.52, 0.92, 0.8), 1, 4, 10, 8))
	cols.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_vbox)

	right_vbox.add_child(UITheme.create_icon_header("crystal", "LỊCH SỬ RUN & PHÁT LẠI REPLAY (60HZ):", 13, Color(0.92, 0.72, 1.0), 18))

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
		card.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.12, 0.15, 0.22, 0.92), Color(0.35, 0.50, 0.70, 0.7), 1, 4, 8, 6))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		card.add_child(row)

		var s_val: String = String(item.get("seed", "ALOALO1234"))
		var h_idx: int = int(item.get("hero_idx", 2))
		row.add_child(UITheme.create_icon_rect("seed", 16))

		var lbl := Label.new()
		lbl.text = "%s\n(%s)" % [s_val, String(item.get("note", ""))]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
		row.add_child(lbl)

		var play_btn := UITheme.create_button("Chơi", "play", Vector2(68, 28), Color(0.45, 0.85, 0.55), Color(0.12, 0.22, 0.16, 0.96), 11)
		play_btn.pressed.connect(func():
			GameManager.replay_seed_run(s_val, h_idx)
		)
		row.add_child(play_btn)

		var del_btn := UITheme.create_button("", "close", Vector2(30, 28), Color(0.85, 0.4, 0.4), Color(0.22, 0.12, 0.14, 0.96), 10)
		del_btn.tooltip_text = "Xóa Seed này"
		del_btn.pressed.connect(func():
			GameManager.remove_saved_seed(s_val)
			_refresh_seed_lists()
		)
		row.add_child(del_btn)
		saved_list_vbox.add_child(card)

	if GameManager.run_history.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Chưa có lịch sử ván đấu.\nHãy hoàn thành 1 lượt chạy để ghi lại Replay 60Hz!"
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.86))
		history_list_vbox.add_child(empty_lbl)
	else:
		for run_item in GameManager.run_history:
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.13, 0.12, 0.22, 0.92), Color(0.58, 0.42, 0.78, 0.7), 1, 4, 8, 6))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			card.add_child(row)

			var s_val: String = String(run_item.get("seed", "ALOALO1234"))
			var h_idx: int = int(run_item.get("hero_idx", 2))
			var h_name: String = String(run_item.get("hero_name", "Hero"))
			var flr: int = int(run_item.get("floor", 1))
			var kills: int = int(run_item.get("kills", 0))

			row.add_child(UITheme.create_icon_rect("trophy", 16))
			var lbl := Label.new()
			lbl.text = "%s | Seed: %s\nTầng %d | Hạ gục: %d" % [h_name, s_val, flr, kills]
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 1.0))
			row.add_child(lbl)

			var seed_btn := UITheme.create_button("Chơi lại", "sword", Vector2(78, 28), Color(0.85, 0.68, 0.32), Color(0.18, 0.15, 0.12, 0.96), 10)
			seed_btn.pressed.connect(func():
				GameManager.replay_seed_run(s_val, h_idx)
			)
			row.add_child(seed_btn)

			if bool(run_item.get("has_replay", false)):
				var watch_btn := UITheme.create_button("Replay", "play", Vector2(74, 28), Color(0.75, 0.48, 0.98), Color(0.20, 0.12, 0.28, 0.96), 10)
				watch_btn.pressed.connect(func():
					GameManager.start_action_replay(run_item)
				)
				row.add_child(watch_btn)

			history_list_vbox.add_child(card)

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
	lore_modal.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.06, 0.08, 0.14, 0.98), Color(0.45, 0.78, 0.98), 2, 6, 18, 14))
	lore_modal.visible = false
	add_child(lore_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	lore_modal.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var h_title := UITheme.create_icon_header("soul_stone", "BIÊN NIÊN SỬ TRUNG ĐỊA — HẦM MỎ MORIA (CHÚA TỂ NHỮNG CHIẾC NHẪN)", 14, Color(0.55, 0.90, 1.0), 22)
	h_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(h_title)

	var close_btn := UITheme.create_button("Đóng", "close", Vector2(84, 30), Color(0.85, 0.4, 0.4), Color(0.2, 0.12, 0.14, 0.96), 12)
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
	story_lbl.add_theme_font_size_override("font_size", 12)
	story_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	story_lbl.text = GameManager.WORLD_LORE["story"] + "\n\n" + \
		"• 4 ANH HÙNG ĐOÀN HỘ NHẪN (THE FELLOWSHIP VANGUARD):\n" + \
		"  1. Pyrois — Hiệp Sĩ Thành Gondor (HP: 4 | Giáp: 4 | ST: 1): Kiếm Andúril & Khiên Minas Tirith tự hồi phục, [Q] Xung Kích Vương Giả.\n" + \
		"  2. Olaf — Chiến Binh Người Lùn Erebor (HP: 6 | Giáp: 1 | ST: 2): Chiến Rìu Khazad-dûm, [Q] Chiến Nộ Durin nhân đôi sát thương.\n" + \
		"  3. Miya — Cung Thủ Tiên Tộc Mirkwood (HP: 3 | Giáp: 1 | ST: 1): Cung Galadhrim tầm xa & [Q] Lửa Orthanc nổ diện rộng.\n" + \
		"  4. Charlotte — Biệt Kích Dúnedain (HP: 5 | Giáp: 0 | ST: 2): Song Kiếm Narsil, [Q] Tam Đoạn Trảm & [Chuột Phải] Ảnh Bộ Đột Kích.\n\n" + \
		"• QUÂN ĐOÀN HẮC ÁM MORDOR & MORIA (5 QUÁI THƯỜNG & 2 ĐẠI THỦ LĨNH):\n" + \
		"  - Quái vật: Orc Moria, Uruk-hai Thiết Giáp, Hài Cốt Barrow-wight, Cung Thủ Xương Minas Morgul, Ác Linh Huyết Quỷ Angmar.\n" + \
		"  - Đại Thủ Lĩnh (Boss): Tử Linh Pháp Sư Dol Guldur (triệu hồi vong hồn & nổ độc) và Thủ Lĩnh Kỵ Binh Warg (xung kích & xoay giáo)."
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
	help_modal.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.06, 0.08, 0.13, 0.98), Color(0.55, 0.88, 0.68), 2, 6, 18, 14))
	help_modal.visible = false
	add_child(help_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	help_modal.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var h_title := UITheme.create_icon_header("question", "HƯỚNG DẪN ĐIỀU KHIỂN & CƠ CHẾ CHIẾN ĐẤU", 15, Color(0.55, 0.95, 0.75), 20)
	h_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(h_title)

	var close_top := UITheme.create_button("Đóng", "close", Vector2(84, 30), Color(0.85, 0.4, 0.4), Color(0.2, 0.12, 0.14, 0.96), 12)
	close_top.pressed.connect(func(): help_modal.visible = false)
	header.add_child(close_top)

	var body := Label.new()
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98))
	body.text = """• [W / A / S / D]: Di chuyển nhân vật 4 hướng trong hầm ngục
• [Chuột Trái]: Tấn công cơ bản theo hướng con trỏ chuột
• [Phím Q]: Kích hoạt Tuyệt kỹ chủ động của từng Thợ Săn
• [Chuột Phải]: Tuyệt kỹ Ảnh Bộ Đột Kích (dành riêng cho Charlotte)
• [Phím E]: Tương tác nhặt vật phẩm rơi ra từ Rương & Quái vật
• [Phím 1 - 9]: Sử dụng nhanh bình máu hoặc mặc trang bị trên thanh Hotbar
• [Phím I / Tab]: Mở Túi đồ 16 ô & Bảng Trang bị (Mũ, Giáp, Vũ khí)
• [Phím M]: Phóng to / Thu nhỏ Bản đồ chiến thuật Minimap
• [Phím ESC]: Tạm dừng / Lưu Seed / Chơi lại cùng Seed"""
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
