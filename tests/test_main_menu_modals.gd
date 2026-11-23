extends Node
## Main Menu: các modal (CONTROLS & MECHANICS, LORE & CHRONICLES, SAVED SEEDS & COMBAT REPLAYS) luôn nằm gọn trong
## màn hình ở mọi cỡ cửa sổ, chữ dài tự xuống dòng / cuộn dọc, nút Close luôn thấy và bấm được (SPK-11).
## Menu được dựng trong SubViewport có kích thước cố định để giả lập từng cỡ khung nhìn.

const MENU_SCENE := "res://Menu/main menu/main_menu.tscn"
const MODALS := [
	["help_modal", "CONTROLS & MECHANICS"],
	["lore_modal", "LORE & CHRONICLES"],
	["seed_modal", "SAVED SEEDS & COMBAT REPLAYS"],
]
## Kích thước khung nhìn của UI (đơn vị sau khi co giãn canvas_items, cơ sở 1152x648, aspect expand):
## 1152x648 = cửa sổ 16:9 (1280x720, 1600x900, 1920x1080); 1293x648 = cửa sổ 1917x960 như ảnh lỗi;
## 1280x720 / 1600x900 / 1920x1080 = không co giãn; 800x480 và 640x360 = cửa sổ nhỏ (640x360 phải cuộn mới đọc hết).
const SIZES := [Vector2i(1152, 648), Vector2i(1293, 648), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(800, 480), Vector2i(640, 360)]
const HELP_LINES := [
	"• W, A, S, D: Move your champion in 4 directions",
	"• Left Click: Strike or fire towards mouse cursor",
	"• Key Q: Unleash champion active ability",
	"• Right Click: Shadow Step dash exclusive to Charlotte",
	"• Yugi: Left/Right Click to summon (hold 0.65s to charge), hold Shift to guard, Shift + Click for combo summons",
	"• Doraemon: Mouse Wheel / Z / X switch gadget page, Left / Right Click use the page gadgets, Q friend (or SUPER with a full power bar), F Dorayaki",
	"• Miyabi: Left Click 3-hit combo, Shift dash slash, hold / release Right Click for a Frost Wave, Q Frost Bloom",
	"• Lương Thơ: Left Click combo Stab → Twin Swing → Ground Smash, Right Click Twin Barrels, Q White Moon transformation",
	"• Key E: Interact and pick up dropped loot or chests",
	"• Keys 1 to 9: Quick-use potions or equip hotbar items",
	"• Key I or Tab: Toggle Backpack & Equipment screen",
	"• Key M: Expand or minimize the tactical Minimap",
	"• Key ESC: Pause expedition, save seed, or retry",
]

var passed_count: int = 0
var failed_count: int = 0

func assert_test(cond: bool, test_name: String) -> void:
	if cond:
		print("  [PASS] ", test_name)
		passed_count += 1
	else:
		printerr("  [FAIL] ", test_name)
		failed_count += 1

func _ready() -> void:
	print("\n========================================================")
	print("  RUNNING MAIN MENU MODAL LAYOUT TESTS")
	print("========================================================\n")
	await get_tree().process_frame
	# một seed có ghi chú dài để thử thẻ trong danh sách SAVED SEEDS
	GameManager.save_seed_entry("LONG_NOTE_SEED", "A very long expedition note that used to push the Play and Del buttons out of the column")
	for s in SIZES:
		await test_size(s)
	await test_resize_while_open()
	print("\n========================================================")
	print("  TEST RESULTS: ", passed_count, " PASSED, ", failed_count, " FAILED")
	print("========================================================\n")
	get_tree().quit(1 if failed_count > 0 else 0)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _open_menu(size: Vector2i) -> Array:
	var vp := SubViewport.new()
	vp.size = size
	vp.gui_disable_input = true
	add_child(vp)
	var menu: Control = load(MENU_SCENE).instantiate()
	vp.add_child(menu)
	await _frames(3)
	return [vp, menu]

func _button(menu: Node, text: String) -> Button:
	for n in menu.find_children("*", "Button", true, false):
		if (n as Button).text == text:
			return n
	return null

func _close_button(modal: Control) -> Button:
	for n in modal.find_children("*", "Button", true, false):
		if (n as Button).text == "Close":
			return n
	return null

func _inside(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(0.5).encloses(inner)

## Mọi nút trong modal nằm trong modal và trong khung cuộn chứa nó (không bị cắt / đẩy ra ngoài).
func _buttons_unclipped(modal: Control) -> bool:
	var m := modal.get_global_rect()
	for n in modal.find_children("*", "Button", true, false):
		var b := n as Button
		if not b.is_visible_in_tree():
			continue
		var r := b.get_global_rect()
		var p: Node = b.get_parent()
		while p != null and p != modal:
			if p is ScrollContainer:
				var sr := (p as ScrollContainer).get_global_rect()
				# nút có thể nằm dưới phần đang thấy (cuộn dọc), nhưng không được tràn ngang
				if r.position.x < sr.position.x - 0.5 or r.end.x > sr.end.x + 0.5:
					return false
				break
			p = p.get_parent()
		if r.position.x < m.position.x - 0.5 or r.end.x > m.end.x + 0.5:
			return false
	return true

func test_size(size: Vector2i) -> void:
	print("--- Viewport %dx%d ---" % [size.x, size.y])
	var parts: Array = await _open_menu(size)
	var vp: SubViewport = parts[0]
	var menu: Control = parts[1]
	var view := Rect2(Vector2.ZERO, Vector2(size))
	for spec in MODALS:
		var modal: Control = menu.get(spec[0])
		var btn := _button(menu, spec[1])
		assert_test(modal != null and btn != null, "%s: modal and its menu button exist" % spec[0])
		if modal == null or btn == null:
			continue
		btn.pressed.emit()
		await _frames(3)
		var r := modal.get_global_rect()
		assert_test(modal.visible and _inside(view, r), "%s fits inside %dx%d (%s)" % [spec[0], size.x, size.y, str(r)])
		assert_test(absf(r.get_center().x - view.get_center().x) <= 1.0 and absf(r.get_center().y - view.get_center().y) <= 1.0, "%s is centred" % spec[0])
		var close := _close_button(modal)
		assert_test(close != null and close.is_visible_in_tree() and _inside(r, close.get_global_rect()) and _inside(view, close.get_global_rect()),
			"%s: Close button fully visible" % spec[0])
		assert_test(_buttons_unclipped(modal), "%s: no button is pushed out of its column" % spec[0])
		if spec[0] == "help_modal":
			var body: Label = menu.help_body
			var scroll: ScrollContainer = menu.help_scroll
			assert_test(body != null and body.autowrap_mode != TextServer.AUTOWRAP_OFF and body.get_parent() == scroll
				and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "controls text wraps inside a vertical-only scroll area")
			assert_test(body != null and scroll != null and body.size.x <= scroll.size.x + 0.5, "controls text is no wider than the modal")
			assert_test(body != null and Array(body.text.split("\n")) == HELP_LINES, "all 13 control lines are kept unchanged")
			if size.y <= 360:
				var bar := scroll.get_v_scroll_bar()
				assert_test(bar.max_value > bar.page + 1.0, "short window: the controls text can be scrolled")
		if close != null:
			close.pressed.emit()
			await _frames(2)
		assert_test(not modal.visible, "%s: Close hides it" % spec[0])
	vp.queue_free()
	await _frames(2)

func test_resize_while_open() -> void:
	print("--- Resizing the window while CONTROLS & MECHANICS is open ---")
	var parts: Array = await _open_menu(Vector2i(1293, 648))
	var vp: SubViewport = parts[0]
	var menu: Control = parts[1]
	var modal: Control = menu.help_modal
	_button(menu, "CONTROLS & MECHANICS").pressed.emit()
	await _frames(3)
	var design := modal.get_global_rect().size
	vp.size = Vector2i(800, 480)
	await _frames(3)
	assert_test(_inside(Rect2(0, 0, 800, 480), modal.get_global_rect()) and _inside(modal.get_global_rect(), _close_button(modal).get_global_rect()),
		"shrinking the window keeps the open modal and Close on screen (%s)" % str(modal.get_global_rect()))
	vp.size = Vector2i(1920, 1080)
	await _frames(3)
	assert_test(modal.get_global_rect().size.is_equal_approx(design) and _inside(Rect2(0, 0, 1920, 1080), modal.get_global_rect()),
		"growing the window restores the design size (%s)" % str(modal.get_global_rect().size))
	vp.queue_free()
	await _frames(2)
