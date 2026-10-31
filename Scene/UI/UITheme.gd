extends RefCounted

const ICONS_TEXTURE: Texture2D = preload("res://Assets/Items/Items/Icons.png")
const PORTAL_TEXTURE: Texture2D = preload("res://Assets/Map/Dimensional_Portal.png")
const HEART_FULL_TEX: Texture2D = preload("res://Assets/UI/HP & Shield bar/HeartFull.png")
const SHIELD_FULL_TEX: Texture2D = preload("res://Assets/UI/HP & Shield bar/ShieldFull.png")

const ICON_REGIONS: Dictionary = {
	"skull": Rect2(0, 0, 16, 16),
	"sword_wood": Rect2(16, 0, 16, 16),
	"chest": Rect2(32, 0, 16, 16),
	"lock": Rect2(48, 0, 16, 16),
	"key": Rect2(64, 0, 16, 16),
	"heart": Rect2(80, 0, 16, 16),
	"coins": Rect2(0, 16, 16, 16),
	"star": Rect2(16, 16, 16, 16),
	"diamond": Rect2(64, 16, 16, 16),
	"speaker_on": Rect2(80, 16, 16, 16),
	"speaker_off": Rect2(0, 32, 16, 16),
	"play": Rect2(16, 32, 16, 16),
	"pause": Rect2(32, 32, 16, 16),
	"check": Rect2(48, 32, 16, 16),
	"close": Rect2(64, 32, 16, 16),
	"stop": Rect2(80, 32, 16, 16),
	"shield_wood": Rect2(0, 48, 16, 16),
	"trophy": Rect2(16, 48, 16, 16),
	"hero": Rect2(32, 48, 16, 16),
	"bag": Rect2(64, 48, 16, 16),
	"gear": Rect2(80, 48, 16, 16),
	"info": Rect2(0, 64, 16, 16),
	"question": Rect2(16, 64, 16, 16),
	"arrow_up": Rect2(32, 64, 16, 16),
	"arrow_down": Rect2(48, 64, 16, 16),
	"arrow_left": Rect2(64, 64, 16, 16),
	"arrow_right": Rect2(80, 64, 16, 16),
	"seed": Rect2(64, 80, 16, 16),
	"cloak": Rect2(48, 96, 16, 16),
	"helmet": Rect2(64, 96, 16, 16),
	"armor": Rect2(80, 96, 16, 16),
	"boots": Rect2(48, 112, 16, 16),
	"sword": Rect2(0, 128, 16, 16),
	"shield": Rect2(16, 128, 16, 16),
	"sword_royal": Rect2(48, 128, 16, 16),
	"flame": Rect2(64, 128, 16, 16),
	"ring": Rect2(80, 128, 16, 16),
	"amulet": Rect2(0, 144, 16, 16),
	"coin": Rect2(16, 144, 16, 16),
	"crystal": Rect2(32, 144, 16, 16),
	"scroll_blue": Rect2(48, 144, 16, 16),
	"scroll_gold": Rect2(64, 144, 16, 16),
	"scroll_green": Rect2(80, 144, 16, 16),
	"helmet_large": Rect2(0, 176, 32, 32),
	"shield_large": Rect2(32, 176, 32, 32),
	"gold_bar": Rect2(64, 176, 32, 32),
	"potion_red_large": Rect2(0, 208, 32, 32),
	"potion_blue_large": Rect2(32, 208, 32, 32),
	"sword_large": Rect2(64, 208, 32, 32),
	"soul_stone": Rect2(0, 240, 32, 32),
	"seed_large": Rect2(32, 240, 32, 32),
	"potion_blue": Rect2(32, 272, 16, 16),
	"potion_red": Rect2(48, 272, 16, 16),
	"skill_slash": Rect2(0, 288, 16, 16),
	"skill_stealth": Rect2(16, 288, 16, 16),
	"skill_shield": Rect2(32, 288, 16, 16),
	"skill_aim": Rect2(48, 288, 16, 16),
	"dark_crystal": Rect2(80, 288, 16, 16)
}

static var _icon_cache: Dictionary = {}

static func get_icon(icon_name: String) -> Texture2D:
	if _icon_cache.has(icon_name):
		return _icon_cache[icon_name]
	if icon_name == "portal":
		var p_atlas := AtlasTexture.new()
		p_atlas.atlas = PORTAL_TEXTURE
		p_atlas.region = Rect2(0, 0, 32, 32)
		_icon_cache[icon_name] = p_atlas
		return p_atlas
	var region: Rect2 = ICON_REGIONS.get(icon_name, Rect2(0, 128, 16, 16))
	var atlas := AtlasTexture.new()
	atlas.atlas = ICONS_TEXTURE
	atlas.region = region
	_icon_cache[icon_name] = atlas
	return atlas

static func create_icon_rect(icon_name: String, size_px: int = 18) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = get_icon(icon_name)
	tr.custom_minimum_size = Vector2(size_px, size_px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

static func create_icon_header(icon_name: String, text: String, font_size: int = 15, color: Color = Color(1.0, 0.86, 0.36), icon_size: int = 20) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	var icon := create_icon_rect(icon_name, icon_size)
	hbox.add_child(icon)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 1.0))
	lbl.add_theme_constant_override("outline_size", 4)
	hbox.add_child(lbl)
	return hbox

static func make_panel_style(
	bg_color: Color = Color(0.08, 0.09, 0.14, 0.94),
	border_color: Color = Color(0.76, 0.60, 0.28, 0.95),
	border_width: int = 2,
	corner_radius: int = 4,
	pad_h: int = 12,
	pad_v: int = 10
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(corner_radius)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb

static func style_button(
	btn: Button,
	icon_name: String = "",
	accent_border: Color = Color(0.82, 0.65, 0.30, 0.95),
	bg_base: Color = Color(0.14, 0.15, 0.22, 0.96),
	font_size: int = 13
) -> void:
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if btn.has_theme_font_override("font"):
		btn.remove_theme_font_override("font")
	if not icon_name.is_empty():
		btn.icon = get_icon(icon_name)
		btn.expand_icon = false
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.55))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.78, 0.30))
	btn.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.05, 1.0))
	btn.add_theme_constant_override("outline_size", 4)
	btn.add_theme_constant_override("h_separation", 8)

	var normal := make_panel_style(bg_base, accent_border, 2, 4, 12, 7)
	var hover := make_panel_style(bg_base.lightened(0.14), accent_border.lightened(0.22), 2, 4, 12, 7)
	var pressed := make_panel_style(bg_base.darkened(0.18), accent_border, 2, 4, 12, 7)
	var disabled := make_panel_style(Color(0.1, 0.1, 0.13, 0.65), Color(0.3, 0.3, 0.35, 0.6), 1, 4, 12, 7)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", hover)

static func create_button(
	text: String,
	icon_name: String = "",
	min_size: Vector2 = Vector2(200, 36),
	accent_border: Color = Color(0.82, 0.65, 0.30, 0.95),
	bg_base: Color = Color(0.14, 0.15, 0.22, 0.96),
	font_size: int = 13
) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	style_button(btn, icon_name, accent_border, bg_base, font_size)
	return btn

static func style_line_edit(le: LineEdit, font_size: int = 13) -> void:
	le.add_theme_font_size_override("font_size", font_size)
	le.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	le.add_theme_color_override("font_placeholder_color", Color(0.55, 0.60, 0.70))
	var normal := make_panel_style(Color(0.06, 0.07, 0.11, 0.96), Color(0.45, 0.58, 0.78, 0.9), 2, 4, 10, 5)
	var focus := make_panel_style(Color(0.08, 0.10, 0.16, 0.98), Color(0.95, 0.78, 0.32, 1.0), 2, 4, 10, 5)
	le.add_theme_stylebox_override("normal", normal)
	le.add_theme_stylebox_override("focus", focus)
