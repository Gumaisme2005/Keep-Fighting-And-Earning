extends CanvasLayer
## Bảng chọn nhân vật của màn "Chọn nhân vật" trong Guild Hall (kiểu Soul Knight, xem hall_select.gd):
##   trên: tên + vai trò; trái: chỉ số (máu, giáp, sát thương, tốc độ) + vũ khí;
##   giữa: nhân vật cỡ lớn chạy idle; phải: cách chơi (kỹ năng Q, đòn đánh chuột trái / phải) từ BalanceConfig;
##   dưới: băng 8 nhân vật với ◀ ▶ để xem người khác, QUAY LẠI và BẮT ĐẦU.
## Cùng phong cách pixel với các cửa hàng: vẽ ở 424x236 rồi phóng to theo số nguyên.
## BẮT ĐẦU -> phát `started(index)`; QUAY LẠI / ESC -> `closed`; đổi người đang xem -> `changed(index)`.
## Phím: ◀ ▶ / A D để đổi người, Enter để bắt đầu, ESC để quay lại.

signal closed
signal started(index: int)
signal changed(index: int)

const W := 424
const H := 236
const UI_DIR := "res://Assets/UI/Shop/"
const FONT_PATH := UI_DIR + "forge5vn.fnt"   # font pixel có dấu tiếng Việt (dòng cao 10px)
const SHOW_SCALE := 3.0                        # nhân vật ở giữa = cỡ trong sảnh x3
const STAGE_CENTRE_X := 61.0
const THUMB := 22                              # ô nhân vật trong băng chọn
const BAR_W := 74.0                            # thanh chỉ số
const TEXT_W := 178                            # bề rộng chữ ở cột "cách chơi"

## [nhãn, khoá trong CHARACTER_INFO, giá trị tối đa của thanh, màu]
const STATS := [
	["MÁU", "hp", 8.0, Color("e0504a")],
	["GIÁP", "armor", 6.0, Color("9fb4c8")],
	["SÁT THƯƠNG", "damage", 4.0, Color("f0a040")],
	["TỐC ĐỘ", "speed", 200.0, Color("6cd27a")],
]

const COL_WHITE := Color("ffffff")
const COL_SOFT := Color("f4e4d4")
const COL_GOLD := Color("f3e3a0")
const COL_LABEL := Color("e8c9a0")
const COL_SHADOW := Color("4d314a")
const COL_DISABLED := Color("c9a38f")
const COL_BAR_BG := Color("5a3a3e")

var index := 0
var statues: Array = []   # AnimatedSprite2D của các anh hùng trong sảnh, theo chỉ số nhân vật

var start_button: Button
var back_button: Button
var prev_button: Button
var next_button: Button
var name_label: Label
var role_label: Label
var stat_values: Array[Label] = []
var stat_fills: Array[ColorRect] = []
var weapon_label: Label
var skills_box: VBoxContainer
var show_sprite: AnimatedSprite2D
var thumbs: Array[Button] = []

var _font: Font
var _window: Control
var _closing := false

static func open(hero_index: int, hall_statues: Array, parent: Node) -> CanvasLayer:
	var ui := CanvasLayer.new()
	ui.set_script(load("res://Scene/UI/HeroSelectUI.gd"))
	ui.name = "HeroSelectUI"
	ui.index = hero_index
	ui.statues = hall_statues
	parent.add_child(ui)
	return ui

## Đổi người đang xem (băng chọn, ◀ ▶).
func show_hero(i: int) -> void:
	var n := _count()
	if n <= 0:
		return
	index = posmod(i, n)
	_fill()
	changed.emit(index)

func start() -> void:
	if _closing:
		return
	_closing = true
	started.emit(index)
	queue_free()

func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	queue_free()

func _ready() -> void:
	layer = 20
	_font = load(FONT_PATH)
	_build()
	_fill()
	get_viewport().size_changed.connect(_fit_window)
	_fit_window()
	start_button.grab_focus()

func _input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed("esc") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_LEFT or k == KEY_A:
			get_viewport().set_input_as_handled()
			show_hero(index - 1)
		elif k == KEY_RIGHT or k == KEY_D:
			get_viewport().set_input_as_handled()
			show_hero(index + 1)
		elif k == KEY_ENTER or k == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			start()

func _fit_window() -> void:
	if _window != null:
		fit(_window, get_viewport(), get_window())

## Phóng to cửa sổ W x H theo số nguyên điểm ảnh thật trên màn hình (bù cho stretch "canvas_items").
static func fit(win: Control, vp_node: Viewport, window: Window) -> void:
	var vp := vp_node.get_visible_rect().size
	var screen := Vector2(window.size) if window != null else vp
	if screen.x <= 0.0 or screen.y <= 0.0:
		screen = vp
	var stretch := minf(screen.x / vp.x, screen.y / vp.y)
	var px := maxf(1.0, floorf(minf(screen.x / W, screen.y / H)))
	win.scale = Vector2.ONE * (px / stretch)
	win.position = ((screen - Vector2(W, H) * px) / 2.0).floor() / stretch

# ------------------------------------------------------------------ data

func _count() -> int:
	var gm := get_node_or_null("/root/GameManager")
	return gm.CHARACTER_INFO.size() if gm != null else statues.size()

func info() -> Dictionary:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return {}
	if gm.has_method("refresh_balance_data"):
		gm.refresh_balance_data()
	var list: Array = gm.CHARACTER_INFO
	return list[clampi(index, 0, list.size() - 1)] if not list.is_empty() else {}

func _statue(i: int) -> AnimatedSprite2D:
	return statues[i] as AnimatedSprite2D if i >= 0 and i < statues.size() else null

## Font pixel chỉ có chữ hoa + dấu tiếng Việt: thay các ký tự không có (—, û, ...) bằng ký tự gần nhất.
func clean(t: String) -> String:
	t = t.replace("—", "-").replace("–", "-").replace("•", "-").replace("û", "u").replace("â", "a").replace("…", "...")
	var out := ""
	for ch in t:
		if ch == " " or ch == "\n" or _font == null or _font.has_char(ch.unicode_at(0)):
			out += ch
		else:
			out += " "
	return out.to_upper()

func _fill() -> void:
	var d := info()
	name_label.text = clean(String(d.get("name", "HERO")))
	role_label.text = clean(String(d.get("role", "")))
	for i in STATS.size():
		var v := float(d.get(STATS[i][1], 0))
		stat_values[i].text = str(int(round(v)))
		stat_fills[i].size.x = roundf(clampf(v / float(STATS[i][2]), 0.04, 1.0) * BAR_W)
	weapon_label.text = clean(String(d.get("weapon", "")))
	for c in skills_box.get_children():
		skills_box.remove_child(c)
		c.queue_free()
	# Kỹ năng Q trước, rồi đòn đánh thường / chuột phải ("Tên — Phím: mô tả")
	for key in ["skill_q", "skill_rmb"]:
		var text := String(d.get(key, ""))
		if text.is_empty():
			continue
		var head := text
		var body := ""
		var cut := text.find(" — ")
		if cut >= 0:
			head = text.substr(0, cut)
			body = text.substr(cut + 3)
		_wrap_label(skills_box, "Head_" + key, clean(head), COL_GOLD)
		if body != "":
			_wrap_label(skills_box, "Body_" + key, clean(body), COL_SOFT)
	for i in thumbs.size():
		thumbs[i].button_pressed = i == index
	_setup_show_sprite()

## Nhân vật ở giữa: cùng SpriteFrames với bản trong sảnh, quay mặt sang phải, căn giữa "sân khấu".
func _setup_show_sprite() -> void:
	var st := _statue(index)
	if st == null:
		show_sprite.visible = false
		return
	show_sprite.visible = true
	show_sprite.sprite_frames = st.sprite_frames
	show_sprite.material = st.material
	show_sprite.centered = false
	var tex := st.sprite_frames.get_frame_texture("idle", 0)
	var anchor: Vector2 = st.get_meta("anchor", Vector2(tex.get_width() / 2.0, tex.get_height()))
	show_sprite.offset = Vector2(-anchor.x, -anchor.y)
	show_sprite.scale = st.scale * SHOW_SCALE
	var used := content_rect(tex)
	var cx := used.position.x + used.size.x / 2.0
	show_sprite.position.x = STAGE_CENTRE_X - roundf((cx - anchor.x) * show_sprite.scale.x)
	var shadow := show_sprite.get_parent().get_node_or_null("Shadow") as Control
	if shadow != null:
		shadow.position.x = show_sprite.position.x - shadow.size.x / 2.0   # bóng dưới chân
	show_sprite.play("idle")

## Phần có màu của một khung hình (toạ độ khung, tính cả margin của AtlasTexture).
static func content_rect(tex: Texture2D) -> Rect2:
	var full := Rect2(Vector2.ZERO, tex.get_size())
	var img: Image = null
	var off := Vector2.ZERO
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		if at.atlas == null or at.atlas.get_image() == null:
			return full
		img = at.atlas.get_image().get_region(Rect2i(at.region))
		off = at.margin.position
	else:
		img = tex.get_image()
	if img == null:
		return full
	var used := img.get_used_rect()
	return Rect2(off + Vector2(used.position), Vector2(used.size))

## Ảnh nhỏ cho băng chọn: chỉ phần có màu của khung idle đầu tiên.
static func thumb_texture(st: AnimatedSprite2D) -> Texture2D:
	if st == null:
		return null
	var tex := st.sprite_frames.get_frame_texture("idle", 0)
	if not (tex is AtlasTexture):
		return tex
	var at := tex as AtlasTexture
	var r := content_rect(tex)
	var t := AtlasTexture.new()
	t.atlas = at.atlas
	t.region = Rect2(at.region.position + r.position - at.margin.position, r.size)
	return t

# ------------------------------------------------------------------ build

func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.04, 0.03, 0.07, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var win := Control.new()
	win.name = "Window"
	win.size = Vector2(W, H)
	win.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	win.theme = make_theme(_font)
	win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(win)
	_window = win

	var title := nine(win, "TitleBanner", "banner.png", Rect2(102, 0, 220, 25), 0, true)
	title.patch_margin_left = 6
	title.patch_margin_right = 6
	title.patch_margin_top = 4
	title.patch_margin_bottom = 5
	name_label = label(title, "Text", Rect2(4, 0, 212, 22), "")
	name_label.theme_type_variation = "BannerLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	role_label = label(win, "Role", Rect2(102, 27, 220, 10), "")
	role_label.theme_type_variation = "BannerLabel"
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.add_theme_color_override("font_color", COL_LABEL)

	# --- trái: chỉ số
	var left := nine(win, "StatsCard", "panel.png", Rect2(6, 38, 92, 164), 8)
	var lh := label(left, "Header", Rect2(0, 6, 92, 10), "CHỈ SỐ")
	lh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lh.add_theme_color_override("font_color", COL_GOLD)
	for i in STATS.size():
		var y := 18 + i * 23
		var l := label(left, "Stat%d" % i, Rect2(7, y, 70, 10), String(STATS[i][0]))
		l.add_theme_color_override("font_color", COL_LABEL)
		var v := label(left, "Value%d" % i, Rect2(49, y, 36, 10), "0")
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_values.append(v)
		var bg := ColorRect.new()
		bg.name = "Bar%d" % i
		bg.color = COL_SHADOW
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left.add_child(bg)
		bg.position = Vector2(7, y + 11)
		bg.size = Vector2(BAR_W + 4, 8)
		var back := ColorRect.new()
		back.name = "Back"
		back.color = COL_BAR_BG
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(back)
		back.position = Vector2(2, 2)
		back.size = Vector2(BAR_W, 4)
		var fill := ColorRect.new()
		fill.name = "Fill"
		fill.color = STATS[i][3]
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(fill)
		fill.position = Vector2(2, 2)
		fill.size = Vector2(0, 4)
		stat_fills.append(fill)
	var wh := label(left, "WeaponHeader", Rect2(7, 112, 78, 10), "VŨ KHÍ")
	wh.add_theme_color_override("font_color", COL_GOLD)
	weapon_label = label(left, "Weapon", Rect2(7, 123, 78, 38), "", true)
	weapon_label.add_theme_color_override("font_color", COL_SOFT)

	# --- giữa: nhân vật cỡ lớn (trong suốt để thấy sảnh phía sau, như Soul Knight)
	var stage := Control.new()
	stage.name = "Stage"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win.add_child(stage)
	stage.position = Vector2(100, 38)
	stage.size = Vector2(122, 164)
	var shadow := ColorRect.new()
	shadow.name = "Shadow"
	shadow.color = Color(0, 0, 0, 0.35)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(shadow)
	shadow.position = Vector2(31, 148)
	shadow.size = Vector2(60, 4)
	show_sprite = AnimatedSprite2D.new()
	show_sprite.name = "Hero"
	show_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage.add_child(show_sprite)
	show_sprite.position = Vector2(STAGE_CENTRE_X, 150)

	# --- phải: cách chơi
	var right := nine(win, "HowToCard", "panel.png", Rect2(226, 38, 192, 164), 8)
	var rh := label(right, "Header", Rect2(0, 6, 192, 10), "CÁCH CHƠI")
	rh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rh.add_theme_color_override("font_color", COL_GOLD)
	skills_box = VBoxContainer.new()
	skills_box.name = "Skills"
	skills_box.add_theme_constant_override("separation", 2)
	skills_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(skills_box)
	skills_box.position = Vector2(7, 19)
	skills_box.size = Vector2(TEXT_W, 140)

	# --- dưới: QUAY LẠI, băng chọn ◀ ... ▶, BẮT ĐẦU
	back_button = button(win, "BackButton", Rect2(6, 208, 70, 18), "QUAY LẠI")
	back_button.pressed.connect(close)
	var n := _count()
	var strip_w := n * (THUMB + 2) - 2
	var x0 := roundf((W - strip_w) / 2.0)
	prev_button = button(win, "PrevButton", Rect2(x0 - 18, 208, 14, 18), "<")
	next_button = button(win, "NextButton", Rect2(x0 + strip_w + 4, 208, 14, 18), ">")
	prev_button.pressed.connect(func(): show_hero(index - 1))
	next_button.pressed.connect(func(): show_hero(index + 1))
	for i in n:
		var b := Button.new()
		b.name = "Thumb%d" % i
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.theme_type_variation = "ThumbButton"
		win.add_child(b)
		b.position = Vector2(x0 + i * (THUMB + 2), 206)
		b.size = Vector2(THUMB, THUMB)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = thumb_texture(_statue(i))
		icon.material = _statue(i).material if _statue(i) != null else null
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		icon.position = Vector2(2, 2)
		icon.size = Vector2(THUMB - 4, THUMB - 4)
		var idx := i
		b.pressed.connect(func(): show_hero(idx))
		thumbs.append(b)
	start_button = button(win, "StartButton", Rect2(348, 208, 70, 18), "BẮT ĐẦU")
	start_button.pressed.connect(start)

func _wrap_label(parent: Control, n: String, text: String, color: Color) -> Label:
	var l := Label.new()
	l.name = n
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(TEXT_W, 0)
	parent.add_child(l)
	l.text = text
	l.add_theme_color_override("font_color", color)
	return l

# ------------------------------------------------------------------ shared pixel-UI helpers (also used by hall_select.gd)

static func _style(file: String, margin: int, content := -1) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(UI_DIR + file)
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(content if content >= 0 else margin)
	return sb

static func make_theme(font: Font) -> Theme:
	var t := Theme.new()
	t.default_font = font
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
	# ô nhân vật trong băng chọn: khung ô túi đồ của cửa hàng, sáng lên khi đang chọn
	t.add_type("ThumbButton")
	t.set_type_variation("ThumbButton", "Button")
	t.set_stylebox("normal", "ThumbButton", _style("slot.png", 3, 0))
	t.set_stylebox("hover", "ThumbButton", _style("slot_hover.png", 3, 0))
	t.set_stylebox("pressed", "ThumbButton", _style("slot_selected.png", 3, 0))
	t.set_stylebox("hover_pressed", "ThumbButton", _style("slot_selected.png", 3, 0))
	t.set_stylebox("focus", "ThumbButton", StyleBoxEmpty.new())
	t.add_type("BannerLabel")
	t.set_type_variation("BannerLabel", "Label")
	t.set_color("font_shadow_color", "BannerLabel", COL_SHADOW)
	t.set_constant("shadow_offset_x", "BannerLabel", 1)
	t.set_constant("shadow_offset_y", "BannerLabel", 1)
	t.set_constant("shadow_outline_size", "BannerLabel", 0)
	return t

static func nine(parent: Node, n: String, file: String, r: Rect2, margin: int, tile := false) -> NinePatchRect:
	var p := NinePatchRect.new()
	p.name = n
	p.texture = load(UI_DIR + file)
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

static func label(parent: Node, n: String, r: Rect2, text: String, wrap_text := false) -> Label:
	var l := Label.new()
	l.name = n
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap_text:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)   # thêm vào cây trước để kích thước tính theo font pixel của theme
	l.text = text
	l.position = r.position
	l.size = r.size
	return l

static func button(parent: Node, n: String, r: Rect2, text: String) -> Button:
	var b := Button.new()
	b.name = n
	b.focus_mode = Control.FOCUS_ALL
	parent.add_child(b)
	b.text = text
	b.position = r.position
	b.size = r.size
	return b
