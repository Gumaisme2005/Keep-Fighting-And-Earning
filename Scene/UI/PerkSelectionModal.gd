extends CanvasLayer

const PerkData = preload("res://Scene/Perks/PerkData.gd")
const UITheme = preload("res://Scene/UI/UITheme.gd")

signal perk_chosen(perk: PerkData)

var _on_complete_callback: Callable = Callable()
var _target_player: Node2D = null
var _cards_container: HBoxContainer = null
var _overlay_rect: ColorRect = null
var _center_panel: PanelContainer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = false
	_build_ui()

func _build_ui() -> void:
	# 1. Màn mờ tối hậu cảnh chặn mọi click xuyên thấu
	_overlay_rect = ColorRect.new()
	_overlay_rect.color = Color(0.04, 0.05, 0.08, 0.88)
	_overlay_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay_rect)

	# 2. Khung căn giữa màn hình
	var center_container := CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_container)

	_center_panel = PanelContainer.new()
	_center_panel.custom_minimum_size = Vector2(860, 480)
	var panel_style := UITheme.make_panel_style(
		UITheme.COLOR_BG_PANEL,
		UITheme.COLOR_GOLD_BORDER,
		2,
		8,
		24,
		20
	)
	_center_panel.add_theme_stylebox_override("panel", panel_style)
	center_container.add_child(_center_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	_center_panel.add_child(main_vbox)

	# 3. Tiêu đề Vàng Kim & Lời Dẫn
	var title_lbl := Label.new()
	title_lbl.text = "✦ CỔ VẬT CHÚC PHÚC (CHOOSE A BLESSING) ✦"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", UITheme.FONT_TITLE)
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05, 0.95))
	title_lbl.add_theme_constant_override("outline_size", 4)
	main_vbox.add_child(title_lbl)

	var subtitle_lbl := Label.new()
	subtitle_lbl.text = "Hào quang cổ xưa soi chiếu lòng Hầm Mỏ Moria. Hãy chọn 1 nguồn sức mạnh để tiếp tục đào sâu."
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_lbl.add_theme_font_override("font", UITheme.FONT_BODY)
	subtitle_lbl.add_theme_font_size_override("font_size", 12)
	subtitle_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	main_vbox.add_child(subtitle_lbl)

	# 4. Hàng ngang 3 thẻ bài Perk
	_cards_container = HBoxContainer.new()
	_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_container.add_theme_constant_override("separation", 20)
	_cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_cards_container)

func show_selection(player: Node2D = null, on_complete: Callable = Callable()) -> void:
	_target_player = player
	_on_complete_callback = on_complete

	var seed_str: String = ""
	var floor_num: int = 1
	if get_node_or_null("/root/GameManager") != null:
		seed_str = GameManager.current_seed
		floor_num = GameManager.current_level

	var perks: Array[PerkData] = PerkManager.roll_perks(3, seed_str, floor_num)
	if perks.is_empty():
		# Nếu không còn Perk nào hợp lệ, tự động tiếp tục
		if _on_complete_callback.is_valid():
			_on_complete_callback.call()
		return

	_populate_cards(perks)
	visible = true
	get_tree().paused = true

func _populate_cards(perks: Array[PerkData]) -> void:
	for child in _cards_container.get_children():
		child.queue_free()

	for perk in perks:
		var card := _create_perk_card(perk)
		_cards_container.add_child(card)

func _create_perk_card(perk: PerkData) -> Control:
	var card_panel := PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(245, 340)

	var border_color: Color = perk.get_rarity_border_color()
	var normal_style := UITheme.make_panel_style(UITheme.COLOR_BG_DARK, border_color, 2, 8, 14, 14)
	var hover_style := UITheme.make_panel_style(UITheme.COLOR_BG_HOVER, UITheme.COLOR_GOLD_BORDER_HOVER, 3, 8, 14, 14)

	card_panel.add_theme_stylebox_override("panel", normal_style)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 10)
	card_panel.add_child(card_vbox)

	# 1. Huy hiệu Phẩm Cấp (Rarity Badge)
	var badge_lbl := Label.new()
	badge_lbl.text = "✦ " + perk.get_rarity_name().to_upper() + " ✦"
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_font_override("font", UITheme.FONT_BODY_BOLD)
	badge_lbl.add_theme_font_size_override("font_size", 10)
	badge_lbl.add_theme_color_override("font_color", perk.get_rarity_color())
	card_vbox.add_child(badge_lbl)

	# 2. Khung Icon lớn (128x128 hoặc 96x96 căn giữa với khung viền bo)
	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(104, 104)
	icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.04, 0.05, 0.08, 0.95)
	frame_style.border_color = perk.get_rarity_color() * 0.75
	frame_style.set_border_width_all(1)
	frame_style.set_corner_radius_all(6)
	frame_style.set_content_margin_all(4)
	icon_frame.add_theme_stylebox_override("panel", frame_style)

	var icon_container := CenterContainer.new()
	icon_frame.add_child(icon_container)

	var icon_rect := TextureRect.new()
	icon_rect.texture = perk.get_full_texture()
	if icon_rect.texture == null:
		icon_rect.texture = perk.get_pixel_texture()
	icon_rect.custom_minimum_size = Vector2(96, 96)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_container.add_child(icon_rect)
	card_vbox.add_child(icon_frame)

	# 3. Tên Perk
	var name_lbl := Label.new()
	name_lbl.text = perk.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", UITheme.FONT_HEADER)
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	card_vbox.add_child(name_lbl)

	# 4. Mô tả chi tiết
	var desc_lbl := Label.new()
	desc_lbl.text = perk.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_override("font", UITheme.FONT_BODY)
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(desc_lbl)

	# 5. Nút bấm Chọn
	var btn := UITheme.create_button("TIẾP NHẬN", "", Vector2(180, 36), border_color, UITheme.COLOR_BG_DARK, 12)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func():
		_on_perk_card_selected(perk)
	)
	card_vbox.add_child(btn)

	# Hiệu ứng rê chuột
	card_panel.mouse_entered.connect(func():
		card_panel.add_theme_stylebox_override("panel", hover_style)
	)
	card_panel.mouse_exited.connect(func():
		card_panel.add_theme_stylebox_override("panel", normal_style)
	)

	return card_panel

func _on_perk_card_selected(perk: PerkData) -> void:
	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_sfx("pickup", 1.05, 1.15)

	PerkManager.add_perk(perk, _target_player)
	visible = false
	get_tree().paused = false
	perk_chosen.emit(perk)

	if get_tree():
		get_tree().call_group("game_ui", "show_banner", "CHÚC PHÚC: " + perk.name.to_upper(), perk.get_rarity_color())

	if _on_complete_callback.is_valid():
		_on_complete_callback.call()
