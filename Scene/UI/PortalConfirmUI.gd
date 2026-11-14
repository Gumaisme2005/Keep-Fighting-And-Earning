extends CanvasLayer
## Hộp thoại "Dịch chuyển đến hầm ngục?" của thanh kiếm rune trong Guild Hall (xem rune_portal_npc.gd).
## Cùng phong cách pixel với các cửa hàng (ShopUI / MageShopUI): vẽ ở 424x236 rồi phóng to theo số nguyên.
## CÓ -> đóng hộp thoại rồi phát `confirmed`; KHÔNG / ESC -> đóng và phát `cancelled`.
## E (interact), Enter, Space bấm nút đang chọn; mũi tên trái/phải đổi nút. Game tạm dừng khi hộp thoại mở.

signal closed
signal confirmed
signal cancelled

const W := 424
const H := 236
const UI_DIR := "res://Assets/UI/Shop/"
const FONT_PATH := UI_DIR + "forge5vn.fnt"   # font pixel có dấu tiếng Việt (dòng cao 10px)

const TITLE := "CỔNG RUNE"
const QUESTION := "DỊCH CHUYỂN ĐẾN HẦM NGỤC?"
const YES := "CÓ"
const NO := "KHÔNG"

const COL_WHITE := Color("ffffff")
const COL_SHADOW := Color("4d314a")
const COL_DISABLED := Color("c9a38f")

var yes_button: Button
var no_button: Button

var _window: Control
var _was_paused := false
var _closing := false

static func open(parent: Node) -> CanvasLayer:
	var ui := CanvasLayer.new()
	ui.set_script(load("res://Scene/UI/PortalConfirmUI.gd"))
	ui.name = "PortalConfirmUI"
	parent.add_child(ui)
	return ui

## Chọn CÓ (true) hoặc KHÔNG (false).
func choose(yes: bool) -> void:
	if _closing:
		return
	close()
	if yes:
		confirmed.emit()
	else:
		cancelled.emit()

func close() -> void:
	if _closing:
		return
	_closing = true
	get_tree().paused = _was_paused
	closed.emit()
	queue_free()

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_was_paused = get_tree().paused
	get_tree().paused = true
	get_viewport().size_changed.connect(_fit_window)
	_fit_window()
	yes_button.grab_focus()

func _exit_tree() -> void:
	if not _closing and is_inside_tree():
		get_tree().paused = _was_paused

func _input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed("esc") and not event.is_echo():
		get_viewport().set_input_as_handled()
		choose(false)
	elif event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		choose(no_button == null or not no_button.has_focus())

func _fit_window() -> void:
	if _window == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var screen := Vector2(get_window().size) if get_window() != null else vp
	if screen.x <= 0.0 or screen.y <= 0.0:
		screen = vp
	var stretch := minf(screen.x / vp.x, screen.y / vp.y)
	var px := maxf(1.0, floorf(minf(screen.x / W, screen.y / H)))
	_window.scale = Vector2.ONE * (px / stretch)
	_window.position = ((screen - Vector2(W, H) * px) / 2.0).floor() / stretch

# ------------------------------------------------------------------ build

func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.03, 0.05, 0.1, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var win := Control.new()
	win.name = "Window"
	win.size = Vector2(W, H)
	win.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	win.theme = _make_theme()
	win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(win)
	_window = win

	_nine(win, "Frame", "panel.png", Rect2(104, 76, 216, 92), 8)
	_banner(win, "TitleBanner", Rect2(137, 64, 150, 25), TITLE, 20)
	var q := _label(win, "Question", Rect2(110, 106, 204, 10), QUESTION)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	yes_button = _button(win, "YesButton", Rect2(130, 136, 72, 16), YES)
	no_button = _button(win, "NoButton", Rect2(222, 136, 72, 16), NO)
	yes_button.focus_neighbor_right = yes_button.get_path_to(no_button)
	no_button.focus_neighbor_left = no_button.get_path_to(yes_button)
	yes_button.pressed.connect(choose.bind(true))
	no_button.pressed.connect(choose.bind(false))

func _tex(file: String) -> Texture2D:
	return load(UI_DIR + file)

func _style(file: String, margin: int, content := -1) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _tex(file)
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(content if content >= 0 else margin)
	return sb

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = load(FONT_PATH)
	t.default_font_size = 10
	t.set_color("font_color", "Label", COL_WHITE)
	t.set_constant("line_spacing", "Label", 0)
	t.set_stylebox("normal", "Button", _style("button.png", 4, 2))
	t.set_stylebox("hover", "Button", _style("button_hover.png", 4, 2))
	t.set_stylebox("pressed", "Button", _style("button_pressed.png", 4, 2))
	t.set_stylebox("hover_pressed", "Button", _style("button_pressed.png", 4, 2))
	t.set_stylebox("disabled", "Button", _style("button_disabled.png", 4, 2))
	t.set_stylebox("focus", "Button", _style("button_hover.png", 4, 2))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", COL_WHITE)
	t.set_color("font_disabled_color", "Button", COL_DISABLED)
	t.set_font_size("font_size", "Button", 10)
	t.add_type("BannerLabel")
	t.set_type_variation("BannerLabel", "Label")
	t.set_color("font_shadow_color", "BannerLabel", COL_SHADOW)
	t.set_constant("shadow_offset_x", "BannerLabel", 1)
	t.set_constant("shadow_offset_y", "BannerLabel", 1)
	t.set_constant("shadow_outline_size", "BannerLabel", 0)
	return t

func _nine(parent: Node, n: String, file: String, r: Rect2, margin: int, tile := false) -> NinePatchRect:
	var p := NinePatchRect.new()
	p.name = n
	p.texture = _tex(file)
	p.patch_margin_left = margin
	p.patch_margin_right = margin
	p.patch_margin_top = margin
	p.patch_margin_bottom = margin
	if tile:
		p.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	p.position = r.position
	p.size = r.size
	return p

func _banner(parent: Node, n: String, r: Rect2, text: String, font_size: int) -> NinePatchRect:
	var p := _nine(parent, n, "banner.png", r, 0, true)
	p.patch_margin_left = 6
	p.patch_margin_right = 6
	p.patch_margin_top = 4
	p.patch_margin_bottom = 5
	var l := Label.new()
	l.name = "Text"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.theme_type_variation = "BannerLabel"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if font_size != 10:
		l.add_theme_font_size_override("font_size", font_size)
	p.add_child(l)
	l.text = text
	l.position = Vector2(4, 0)
	l.size = Vector2(r.size.x - 8, r.size.y - 3)
	return p

func _label(parent: Node, n: String, r: Rect2, text: String) -> Label:
	var l := Label.new()
	l.name = n
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)   # thêm vào cây trước để kích thước tính theo font pixel của theme
	l.text = text
	l.position = r.position
	l.size = r.size
	return l

func _button(parent: Node, n: String, r: Rect2, text: String) -> Button:
	var b := Button.new()
	b.name = n
	b.focus_mode = Control.FOCUS_ALL
	parent.add_child(b)
	b.text = text
	b.position = r.position
	b.size = r.size
	return b
