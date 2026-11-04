extends CanvasLayer
## 4D Pocket HUD: current gadget page, the gadgets on Left / Right click with their
## cooldowns, the Q action (next friend or the page's super move), Dorayaki and the
## 3-bar power gauge.

const UITheme = preload("res://Scene/UI/UITheme.gd")
const PANEL_SIZE := Vector2(318, 132)

var panel: PanelContainer
var bars: Control
var title: Label
var rows: Array[Label] = []
var state: Dictionary = {}

func _ready() -> void:
	layer = 5
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_style(Color(0.05, 0.06, 0.12, 0.86), Color(0.35, 0.62, 0.95, 0.95), 2, 6, 8, 6))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = PANEL_SIZE
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	title = _label(box, 12, Color(0.55, 0.85, 1.0))
	for i in range(4):
		rows.append(_label(box, 11, Color(0.93, 0.94, 0.98)))
	bars = Control.new()
	bars.custom_minimum_size = Vector2(PANEL_SIZE.x - 16, 12)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.draw.connect(_draw_bars)
	box.add_child(bars)
	_place()
	get_viewport().size_changed.connect(_place)

func _label(parent: Node, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	l.custom_minimum_size = Vector2(PANEL_SIZE.x - 16, 0)
	parent.add_child(l)
	return l

func _place() -> void:
	var vp := get_viewport().get_visible_rect().size
	panel.position = Vector2(12, vp.y - PANEL_SIZE.y - 12)

func refresh(s: Dictionary) -> void:
	state = s
	title.text = "4D POCKET  < %d / %d >  %s" % [int(s.get("page", 0)) + 1, int(s.get("pages", 1)), String(s.get("page_name", ""))]
	rows[0].text = "LMB  %s%s" % [String(s.get("lmb", "")), _cd(float(s.get("lmb_cd", 0.0)))]
	rows[1].text = "RMB  %s%s" % [String(s.get("rmb", "")), _cd(float(s.get("rmb_cd", 0.0)))]
	if bool(s.get("super_ready", false)):
		rows[2].text = "Q    * SUPER: %s" % String(s.get("super", ""))
		rows[2].add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		rows[2].text = "Q    Friend: %s%s" % [String(s.get("friend", "")), _cd(float(s.get("q_cd", 0.0)))]
		rows[2].add_theme_color_override("font_color", Color(0.93, 0.94, 0.98))
	rows[3].text = "F    Dorayaki%s     Wheel / Z X: switch page" % _cd(float(s.get("eat_cd", 0.0)))
	bars.queue_redraw()

func _cd(t: float) -> String:
	return "  (%.1fs)" % t if t > 0.05 else "  - ready"

func _draw_bars() -> void:
	var w := bars.size.x
	var power := float(state.get("power", 0.0))
	var seg_w := (w - 8.0) / 3.0
	for i in range(3):
		var r := Rect2(i * (seg_w + 4.0), 2, seg_w, 8)
		bars.draw_rect(r, Color(0.1, 0.1, 0.18, 0.9))
		var fill := clampf((power - i * 100.0) / 100.0, 0.0, 1.0)
		if fill > 0.0:
			var col := Color(1.0, 0.8, 0.25) if fill >= 1.0 else Color(0.35, 0.65, 1.0)
			bars.draw_rect(Rect2(r.position, Vector2(seg_w * fill, 8)), col)
		bars.draw_rect(r, Color(0.6, 0.75, 1.0, 0.8), false, 1.0)
