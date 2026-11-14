extends Node2D
## Màn "Chọn nhân vật" trong Guild Hall (giống Soul Knight), do guild_hall.gd tạo khi GameManager.hall_selecting:
##   - camera nhìn toàn sảnh, chưa có ai điều khiển; thanh trên "CHỌN NHÂN VẬT", nút MENU CHÍNH, nút DANH SÁCH;
##   - bấm vào một anh hùng -> camera tiến lại gần người đó + mở bảng HeroSelectUI (chỉ số, cách chơi, băng chọn ◀ ▶);
##   - BẮT ĐẦU -> guild_hall.start_with_hero(): người đó bước ra khỏi chỗ đứng và người chơi điều khiển luôn.
## Vòng sáng hồng dưới chân đánh dấu nhân vật chọn lần trước.

const SELECT_UI := preload("res://Scene/UI/HeroSelectUI.gd")
const UI_DIR := "res://Assets/UI/Shop/"
const FONT_PATH := UI_DIR + "forge5vn.fnt"
const W := 424
const H := 236
## Phần sảnh lấp kín màn hình (từ tường trái tới tường phải, trần tới tường dưới): camera phóng to vừa phủ kín
## khung này theo tỉ lệ cửa sổ và bị giới hạn trong khung, nên không bao giờ thấy bãi cỏ hay nền đen bên ngoài.
const VIEW_RECT := Rect2(16, 4, 550, 338)
const OVERVIEW_BOTTOM := 330.0               # mép dưới luôn thấy được (tường dưới)
const FOCUS_ZOOM := 3.4                       # khi mở bảng thông tin: tiến lại gần anh hùng
const HIT_RECT := Rect2(-15, -42, 30, 44)     # vùng bấm quanh chân mỗi anh hùng (px trong sảnh)
const RING_COLOR := Color(1.0, 0.36, 0.66)

var hall: Node2D = null
var camera: Camera2D = null
var hud: CanvasLayer = null
var panel: CanvasLayer = null
var ring: Node2D = null
var hovered: Node2D = null
var _ring_t := 0.0
var _cam_tween: Tween = null

func _ready() -> void:
	hall = get_parent() as Node2D
	camera = Camera2D.new()
	camera.name = "SelectCamera"
	camera.position = overview_centre()
	camera.zoom = Vector2.ONE * overview_zoom()
	camera.limit_left = int(VIEW_RECT.position.x)
	camera.limit_top = int(VIEW_RECT.position.y)
	camera.limit_right = int(VIEW_RECT.end.x)
	camera.limit_bottom = int(VIEW_RECT.end.y)
	add_child(camera)
	camera.make_current()
	ring = Node2D.new()
	ring.name = "SelectRing"
	ring.z_index = -7
	ring.draw.connect(_draw_ring)
	add_child(ring)
	_build_hud()
	_place_ring()

func _process(delta: float) -> void:
	_ring_t += delta
	ring.queue_redraw()
	if panel != null:
		return
	# sáng lên khi rê chuột qua một anh hùng
	var h := hero_at(get_global_mouse_position())
	if h != hovered:
		if hovered != null and is_instance_valid(hovered):
			hovered.modulate = Color.WHITE
		hovered = h
		if hovered != null:
			hovered.modulate = Color(1.25, 1.25, 1.25)

func _unhandled_input(event: InputEvent) -> void:
	if panel != null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = get_canvas_transform().affine_inverse() * (event as InputEventMouseButton).position
		var h := hero_at(p)
		if h != null:
			get_viewport().set_input_as_handled()
			open_panel(int(h.get_meta("hero_index")))

# ------------------------------------------------------------------ heroes

func heroes() -> Array:
	var out := []
	for i in GameManager.CHARACTER_SCENES.size():
		out.append(hall.hall_hero_node(i))
	return out

## Anh hùng dưới điểm p (toạ độ sảnh); nhiều người chồng lên nhau thì lấy người gần chân nhất.
func hero_at(p: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for h in heroes():
		if h == null or not h.is_visible_in_tree():
			continue
		var rel: Vector2 = p - h.global_position
		if HIT_RECT.has_point(rel) and rel.length() < best_d:
			best = h
			best_d = rel.length()
	return best

func _place_ring() -> void:
	var h: Node2D = hall.hall_hero_node(int(GameManager.selected_character_index))
	ring.visible = h != null
	if h != null:
		ring.position = h.global_position - global_position

func _draw_ring() -> void:
	var pulse := 0.55 + 0.25 * sin(_ring_t * 4.0)
	ring.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	var c := RING_COLOR
	c.a = pulse
	ring.draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 40, c, 1.5)
	c.a = pulse * 0.45
	ring.draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 40, c, 1.0)

# ------------------------------------------------------------------ panel / camera

func open_panel(index: int) -> CanvasLayer:
	if panel != null:
		return panel
	if hovered != null and is_instance_valid(hovered):
		hovered.modulate = Color.WHITE
	hovered = null
	hud.visible = false
	panel = SELECT_UI.open(index, heroes(), self)
	panel.changed.connect(_focus)
	panel.closed.connect(_on_panel_closed)
	panel.started.connect(_on_started)
	_focus(index)
	return panel

var _focused: Array = []

## Camera tiến lại gần anh hùng đang xem; bản đứng trong sảnh của người đó (kể cả linh hồn của Miyabi) tạm ẩn
## vì bảng đã vẽ người đó cỡ lớn.
func _focus(index: int) -> void:
	_unfocus()
	var h: Node2D = hall.hall_hero_node(index)
	if h == null:
		return
	for n in h.get_parent().get_children():
		if n.has_meta("hero_index") and int(n.get_meta("hero_index")) == index and n.visible:
			n.visible = false
			_focused.append(n)
	_move_camera(h.global_position + Vector2(0, -14), maxf(FOCUS_ZOOM, overview_zoom() * 1.6))

func _unfocus() -> void:
	for n in _focused:
		if is_instance_valid(n):
			n.visible = true
	_focused.clear()

func _on_panel_closed() -> void:
	panel = null
	_unfocus()
	if hud != null:
		hud.visible = true
	_move_camera(overview_centre(), overview_zoom())

func _on_started(index: int) -> void:
	panel = null
	_unfocus()
	# chuyển cảnh ngắn: tối lại rồi sáng dần ở camera của nhân vật (lớp này gắn vào sảnh nên còn sau khi màn chọn bị xoá)
	var fade := CanvasLayer.new()
	fade.name = "StartFade"
	fade.layer = 30
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 1)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.add_child(rect)
	hall.add_child(fade)
	var tw := fade.create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.4).set_delay(0.05)
	tw.tween_callback(fade.queue_free)
	hall.start_with_hero(index)

## Độ phóng để khung VIEW_RECT phủ kín màn hình (cửa sổ rộng thì cắt bớt trên / dưới, cửa sổ cao thì cắt hai bên).
func overview_zoom() -> float:
	var vp := get_viewport().get_visible_rect().size
	return maxf(vp.x / VIEW_RECT.size.x, vp.y / VIEW_RECT.size.y)

## Tâm camera khi nhìn toàn sảnh. Cửa sổ quá rộng thì không thấy hết chiều cao: ưu tiên giữ hàng anh hùng ở đáy
## (chân ở y 316, tường dưới ở y 330) và cắt bớt phần tường trên (nơi thanh tiêu đề che sẵn).
func overview_centre() -> Vector2:
	var c := VIEW_RECT.get_center()
	var h := get_viewport().get_visible_rect().size.y / overview_zoom()
	c.y = maxf(c.y, OVERVIEW_BOTTOM - h / 2.0)
	return c

func _on_viewport_resized() -> void:
	if panel == null and camera != null and (_cam_tween == null or not _cam_tween.is_running()):
		camera.zoom = Vector2.ONE * overview_zoom()
		camera.position = overview_centre() - global_position

func _move_camera(target: Vector2, zoom: float) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(camera, "position", target - global_position, 0.35)
	_cam_tween.tween_property(camera, "zoom", Vector2.ONE * zoom, 0.35)

func back_to_menu() -> void:
	GameManager.hall_selecting = false
	get_tree().change_scene_to_file("res://Menu/main menu/main_menu.tscn")

# ------------------------------------------------------------------ HUD (pixel UI, 424 x 236 phóng to theo số nguyên)

var _window: Control

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "SelectHUD"
	hud.layer = 10
	add_child(hud)
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var win := Control.new()
	win.name = "Window"
	win.size = Vector2(W, H)
	win.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win.theme = SELECT_UI.make_theme(load(FONT_PATH))
	root.add_child(win)
	_window = win
	var top := SELECT_UI.nine(win, "TitleBanner", "banner.png", Rect2(122, 0, 180, 25), 0, true)
	top.patch_margin_left = 6
	top.patch_margin_right = 6
	top.patch_margin_top = 4
	top.patch_margin_bottom = 5
	var title := SELECT_UI.label(top, "Text", Rect2(4, 0, 172, 22), "CHỌN NHÂN VẬT")
	title.theme_type_variation = "BannerLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	var menu_btn := SELECT_UI.button(win, "MenuButton", Rect2(6, 5, 84, 16), "MENU CHÍNH")
	menu_btn.pressed.connect(back_to_menu)
	var list_btn := SELECT_UI.button(win, "ListButton", Rect2(6, 214, 110, 16), "DANH SÁCH NHÂN VẬT")
	list_btn.pressed.connect(func(): open_panel(int(GameManager.selected_character_index)))
	var hint := SELECT_UI.label(win, "Hint", Rect2(122, 218, 180, 10), "BẤM VÀO MỘT NHÂN VẬT ĐỂ CHỌN")
	hint.theme_type_variation = "BannerLabel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	get_viewport().size_changed.connect(_fit_window)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_fit_window()

## HUD bám theo các góc màn hình (như ảnh mẫu): phóng to theo số nguyên rồi trải khung ảo ra hết bề ngang / dọc.
func _fit_window() -> void:
	if _window == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var screen := Vector2(get_window().size) if get_window() != null else vp
	if screen.x <= 0.0 or screen.y <= 0.0:
		screen = vp
	var stretch := minf(screen.x / vp.x, screen.y / vp.y)
	var px := maxf(1.0, floorf(minf(screen.x / W, screen.y / H)))
	var vs := (screen / px).floor()            # kích thước màn hình tính bằng điểm ảnh của HUD
	_window.size = vs
	_window.scale = Vector2.ONE * (px / stretch)
	_window.position = Vector2.ZERO
	_window.get_node("TitleBanner").position = Vector2(roundf((vs.x - 180.0) / 2.0), 0)
	_window.get_node("MenuButton").position = Vector2(6, 5)
	_window.get_node("ListButton").position = Vector2(6, vs.y - 22.0)
	_window.get_node("Hint").position = Vector2(roundf((vs.x - 180.0) / 2.0), vs.y - 18.0)
