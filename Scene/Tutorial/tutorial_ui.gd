extends CanvasLayer
const Content = preload("res://Scene/Tutorial/tutorial_content.gd")
const Pixel = preload("res://Scene/UI/HeroSelectUI.gd")
const SlotScene = preload("res://Scene/UI/InventorySlot.tscn")
signal start_requested
signal declined
signal control_requested(action: String)
signal destroyed
const SIZE := Vector2(960, 600)
var root: Control
var window: Control
var arena: TextureRect
var title: Label
var objective: Label
var progress: Label
var status: Label
var feedback_label: Label
var marker: Label
var bag_slots: Array[Control] = []
var equipment_slots: Array[Control] = []
var modal: Control
var modal_title: Label
var modal_text: Label
var primary: Button
var secondary: Button
var tooltip_panel: PanelContainer
var tooltip_label: Label
var host: Node
var context: Node
var _feedback_left := 0.0
var _intent := ""
var _secondary_action := "resume"
var _tooltip_slot: WeakRef
var _tooltip_item_id := 0
var _inventory_dirty := true

func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.018, 0.03, 0.96)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	window = Control.new()
	window.size = SIZE
	window.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	window.theme = Pixel.make_theme(load("res://Assets/UI/Shop/forge5vn.fnt"))
	window.theme.default_font_size = 16
	window.theme.set_font_size("font_size", "Button", 16)
	root.add_child(window)
	Pixel.nine(window, "Frame", "panel.png", Rect2(Vector2.ZERO, SIZE), 8).self_modulate = Color(0.23, 0.23, 0.29)
	Pixel.nine(window, "HeaderPanel", "panel.png", Rect2(12, 10, 936, 68), 8).self_modulate = Color(0.32, 0.30, 0.34)
	Pixel.nine(window, "LessonPanel", "panel.png", Rect2(664, 80, 284, 422), 8).self_modulate = Color(0.29, 0.28, 0.34)
	title = _label("Title", Rect2(20, 16, 920, 24), "ADVENTURER TRAINING", 20)
	progress = _label("Progress", Rect2(20, 52, 920, 28), "", 10)
	arena = TextureRect.new()
	arena.name = "PracticeArena"
	arena.position = Vector2(16, 96)
	arena.size = Vector2(640, 400)
	arena.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arena.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(arena)
	marker = _label("ObjectiveMarker", Rect2(16, 80, 640, 14), "", 10)
	objective = _label("Objective", Rect2(676, 86, 264, 120), "", 10)
	status = _label("PracticeStatus", Rect2(676, 210, 264, 68), "", 10)
	_label("BagTitle", Rect2(676, 282, 264, 16), "PRACTICE BAG - Click to use", 10)
	for index in 16:
		var slot: Control = SlotScene.instantiate()
		slot.set_meta("tutorial_custom_tooltip", true)
		slot.slot_index = index
		slot.position = Vector2(676 + (index % 8) * 33, 306 + (index / 8) * 36)
		slot.size = Vector2(30, 30)
		window.add_child(slot)
		slot.key_label.add_theme_font_size_override("font_size", 12)
		slot.count_label.add_theme_font_size_override("font_size", 12)
		slot.slot_clicked.connect(_use)
		slot.slot_right_clicked.connect(_drop)
		slot.slot_dropped.connect(_drag)
		bag_slots.append(slot)
		slot.mouse_entered.connect(_show_tooltip.bind(slot))
		slot.mouse_exited.connect(_hide_tooltip)
	_label("EquipTitle", Rect2(676, 388, 264, 16), "HELM / ARMOR / WEAPON", 10)
	for index in 3:
		var slot: Control = SlotScene.instantiate()
		slot.set_meta("tutorial_custom_tooltip", true)
		slot.slot_kind = slot.SlotKind.EQUIPMENT
		slot.slot_index = -1 - index
		slot.equip_type = [ItemData.ItemType.HELMET, ItemData.ItemType.ARMOR, ItemData.ItemType.WEAPON][index]
		slot.position = Vector2(676 + index * 44, 414)
		slot.size = Vector2(38, 38)
		window.add_child(slot)
		slot.slot_clicked.connect(_unequip.bind(slot.equip_type))
		slot.slot_dropped.connect(_drag)
		equipment_slots.append(slot)
		slot.mouse_entered.connect(_show_tooltip.bind(slot))
		slot.mouse_exited.connect(_hide_tooltip)
	var recovery_hint := _label("RecoveryHint", Rect2(676, 456, 264, 50), "Missing gear or potions?\nRestart for a fresh lesson.\nRight-click bag items: drop.", 10)
	recovery_hint.add_theme_font_size_override("font_size", 14)
	feedback_label = _label("Feedback", Rect2(20, 506, 920, 34), "", 10)
	_button("Skip", Rect2(20, 550, 160, 28), "Skip Tutorial", func(): control_requested.emit("skip"))
	_button("Restart", Rect2(190, 550, 180, 28), "Restart / Recover", func(): control_requested.emit("restart"))
	_button("Pause", Rect2(760, 550, 180, 28), "Pause / Resume", func(): control_requested.emit("pause"))
	tooltip_panel = PanelContainer.new()
	tooltip_panel.custom_minimum_size.x = 280
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_theme_stylebox_override("panel", Pixel._style("panel.png", 8))
	tooltip_panel.self_modulate = Color(0.30, 0.28, 0.34)
	window.add_child(tooltip_panel)
	tooltip_label = Label.new()
	tooltip_label.custom_minimum_size.x = 264
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_child(tooltip_label)
	tooltip_panel.hide()
	_build_modal()
	get_viewport().size_changed.connect(_fit)
	_fit()

func _label(n: String, rect: Rect2, value: String, font_size: int) -> Label:
	var label := Pixel.label(window, n, rect, value, true)
	label.add_theme_font_size_override("font_size", maxi(16, font_size))
	label.add_theme_color_override("font_color", Color("f0ddbc"))
	return label

func _button(n: String, rect: Rect2, value: String, action: Callable) -> Button:
	var button := Pixel.button(window, n, rect, value)
	button.pressed.connect(action)
	return button

func _build_modal() -> void:
	modal = Control.new()
	modal.size = SIZE
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	window.add_child(modal)
	var shade := ColorRect.new()
	shade.size = SIZE
	shade.color = Color(0.01, 0.015, 0.025, 0.96)
	modal.add_child(shade)
	Pixel.nine(modal, "ConsentFrame", "panel.png", Rect2(210, 170, 540, 250), 8).self_modulate = Color(0.32, 0.30, 0.34)
	modal_title = Pixel.label(modal, "Heading", Rect2(230, 190, 500, 32), "", true)
	modal_title.add_theme_font_size_override("font_size", 20)
	modal_text = Pixel.label(modal, "Message", Rect2(230, 242, 500, 90), "", true)
	primary = Pixel.button(modal, "Primary", Rect2(230, 366, 240, 30), "")
	secondary = Pixel.button(modal, "Secondary", Rect2(490, 366, 240, 30), "")
	primary.pressed.connect(func():
		if _intent == "consent": start_requested.emit()
		else: control_requested.emit(_intent))
	secondary.pressed.connect(func():
		if _intent == "consent": declined.emit()
		else: control_requested.emit(_secondary_action))

func show_modal(intent: String, heading: String, message: String, yes: String, no: String = "Resume", secondary_action: String = "resume") -> void:
	_intent = intent
	_secondary_action = secondary_action
	modal_title.text = heading
	modal_text.text = message
	primary.text = yes
	secondary.text = no
	primary.visible = not yes.is_empty()
	secondary.visible = not no.is_empty()
	modal.show()
	if primary.visible: primary.grab_focus()

func _fit() -> void:
	var available := get_viewport().get_visible_rect().size
	var factor := minf(available.x / SIZE.x, available.y / SIZE.y)
	window.scale = Vector2.ONE * factor
	window.position = (available - SIZE * factor) * 0.5

func arena_point(at: Vector2) -> Vector2:
	# Actual TextureRect content rect, including aspect-preserving letterboxing.
	var local: Vector2 = arena.get_global_transform_with_canvas().affine_inverse() * at
	var factor := minf(arena.size.x / 640.0, arena.size.y / 400.0)
	var offset := (arena.size - Vector2(640, 400) * factor) * 0.5
	var point := (local - offset) / factor
	return point if Rect2(0, 0, 640, 400).has_point(point) else Vector2.INF

func bind_context(value: Node) -> void:
	_hide_tooltip()
	if is_instance_valid(context) and context.local_feedback.is_connected(_feedback):
		context.local_feedback.disconnect(_feedback)
	if is_instance_valid(context) and is_instance_valid(context.hero):
		var previous: Node = context.hero.inventory
		if previous.inventory_changed.is_connected(_inventory_changed): previous.inventory_changed.disconnect(_inventory_changed)
		if previous.equipment_changed.is_connected(_inventory_changed): previous.equipment_changed.disconnect(_inventory_changed)
	context = value
	arena.texture = context.viewport.get_texture() if is_instance_valid(context) else null
	if is_instance_valid(context):
		context.local_feedback.connect(_feedback)
		context.hero.inventory.inventory_changed.connect(_inventory_changed)
		context.hero.inventory.equipment_changed.connect(_inventory_changed)
	_refresh_inventory()

func _inventory_changed() -> void:
	_inventory_dirty = true

func _feedback(method: StringName, arguments: Array) -> void:
	if method == &"spawn_damage_number" and arguments.size() >= 2:
		feedback_label.text = "Practice: " + str(arguments[1]) + " damage / healing"
	elif not arguments.is_empty():
		feedback_label.text = str(arguments[0])
	_feedback_left = 3.0

func notify(message: String) -> void:
	feedback_label.text = message
	_feedback_left = 4.0

func _process(delta: float) -> void:
	if not is_instance_valid(host) or host.session == null:
		return
	var step: int = host.session.get_current_step()
	if step < 0:
		return
	var snapshot: Dictionary = host.session.get_progress()[step]
	title.text = "ADVENTURER TRAINING  /  " + str(GameManager.CHARACTER_INFO[host.hero_index].name)
	progress.text = "STEP %d / 8  -  %s  -  %d / %d" % [step + 1, Content.TITLES[step], snapshot.progress, snapshot.required]
	objective.text = Content.instruction(step, host.hero_index)
	marker.text = ["Walk in three directions", "Approach the dummy in the center", "Use your representative skill on the dummy", "Armor is beside your starting point", "Equip the collected armor", "Red rune: two hits, then wait for armor regen", "Potion: recover missing health", "Return to the Rune Portal"][step]
	if is_instance_valid(context) and is_instance_valid(context.hero):
		var hero: CharacterBody2D = context.hero
		var skill: float = hero.q_cd_remaining
		if host.hero_index == 5: skill = hero.friend_cd
		if host.hero_index == 6 or host.hero_index == 7: skill = hero.q_cd
		status.text = "HP %d / %d    ARMOR %d / %d\nDMG %d  /  Q cooldown %.1fs\nPotions %d  /  Cooldown %.1fs" % [hero.hp, hero.max_hp, hero.current_armor, hero.max_armor, hero.get_total_damage(), skill, hero.inventory.get_potion_count(), hero.potion_cooldown_remaining]
		if _inventory_dirty: _refresh_inventory()
	_feedback_left = maxf(0.0, _feedback_left - delta)
	if _feedback_left == 0.0:
		feedback_label.text = "Practice only - your run, items and rewards are preserved."

func _refresh_inventory() -> void:
	_inventory_dirty = false
	var inventory: Node = context.hero.inventory if is_instance_valid(context) and is_instance_valid(context.hero) else null
	for index in bag_slots.size():
		bag_slots[index].set_item(inventory.bag[index] if inventory != null else null)
		bag_slots[index].tooltip_text = "" # bounded local tooltip, not a native popup
	for slot in equipment_slots:
		slot.set_item(inventory.get_equipped_item(slot.equip_type) if inventory != null else null)
		slot.tooltip_text = ""
	if tooltip_panel.visible:
		var source = _tooltip_slot.get_ref() if _tooltip_slot != null else null
		if not is_instance_valid(source) or source.current_item == null or source.current_item.get_instance_id() != _tooltip_item_id:
			_hide_tooltip()

func _hide_tooltip() -> void:
	if is_instance_valid(tooltip_panel): tooltip_panel.hide()
	_tooltip_slot = null
	_tooltip_item_id = 0

func _show_tooltip(slot: Control) -> void:
	if slot.current_item == null or modal.visible:
		_hide_tooltip()
		return
	_tooltip_slot = weakref(slot)
	_tooltip_item_id = slot.current_item.get_instance_id()
	var text: String = slot.current_item.get_tooltip_text()
	var supported := ""
	for index in text.length():
		if text[index] == "\n" or window.theme.default_font.has_char(text.unicode_at(index)):
			supported += text[index]
	tooltip_label.text = supported
	tooltip_panel.size = tooltip_panel.get_combined_minimum_size()
	tooltip_panel.position = (slot.position + Vector2(36, 12)).clamp(Vector2(12, 12), SIZE - tooltip_panel.size - Vector2(12, 12))
	tooltip_panel.show()

func _can_use() -> bool:
	return not modal.visible and is_instance_valid(context) and context.live()

func _use(index: int) -> void:
	if _can_use():
		context.hero.inventory.use_or_equip_item(index, context.hero)
		_refresh_inventory()

func _drop(index: int) -> void:
	if _can_use():
		context.hero.inventory.drop_item(index, true, context.hero.position + Vector2(0, 24), true)
		_refresh_inventory()

func _unequip(_index: int, type: int) -> void:
	if _can_use():
		context.hero.inventory.unequip_item(type)
		_refresh_inventory()

func _drag(data: Dictionary, target: Control) -> void:
	if not _can_use() or not is_instance_valid(data.get("origin_slot")) \
		or not (bag_slots.has(data.origin_slot) or equipment_slots.has(data.origin_slot)):
		return
	var inventory: Node = context.hero.inventory
	if data.origin_slot.current_item != data.get("item"):
		return
	if data.slot_kind == 0 and target.slot_kind == 0:
		inventory.swap_slots(data.slot_index, target.slot_index)
	elif data.slot_kind == 0 and target.slot_kind == 1 and data.item.type == target.equip_type:
		inventory.use_or_equip_item(data.slot_index, context.hero)
	elif data.slot_kind == 1 and target.slot_kind == 0:
		# Use the guarded inventory API; never write equipment dictionaries directly.
		inventory.unequip_item(data.equip_type)
	_refresh_inventory()

func _exit_tree() -> void:
	bind_context(null)
	destroyed.emit()
