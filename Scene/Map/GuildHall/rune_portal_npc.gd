extends "res://Scene/Map/GuildHall/blacksmith_npc.gd"
## Thanh kiếm rune giữa Guild Hall: đứng gần + nhấn E (action "interact") sẽ hỏi "Dịch chuyển đến hầm ngục?".
## Chọn CÓ: cổng rune sau lưng người trùm mũ xoáy xanh (animation "active"), nhân vật bị hút vào,
## màn hình loé sáng rồi GameManager.enter_dungeon_from_hall() đưa nhân vật (giữ máu, đồ, xu, chấn) xuống hầm ngục tầng 1.
## Trong lúc dịch chuyển game tạm dừng (chỉ thanh kiếm, nhân vật bị hút và lớp loé sáng còn chạy).

signal teleport_started(hero: Node2D)

const CONFIRM_UI := preload("res://Scene/UI/PortalConfirmUI.gd")
const FLASH_COLOR := Color(0.62, 0.9, 1.0)
const PULL_TIME := 1.6     # nhân vật trôi vào cổng
const FLASH_IN := 0.45     # loé sáng che màn hình khi cổng xoáy xong
const FLASH_OUT := 0.6     # tan dần khi đã ở hầm ngục

var teleporting := false
var flash: CanvasLayer = null

func can_open() -> bool:
	return not teleporting and super.can_open()

func _process(delta: float) -> void:
	super._process(delta)
	if teleporting and _prompt != null:
		_prompt.visible = false

func _create_shop(_who: Node2D) -> CanvasLayer:
	var ui: CanvasLayer = CONFIRM_UI.open(get_tree().current_scene)
	ui.confirmed.connect(_on_confirmed)
	return ui

func _on_confirmed() -> void:
	var who := hero_near
	if who == null or not is_instance_valid(who):
		for n in get_tree().get_nodes_in_group("player"):
			if n is CharacterBody2D:
				who = n
				break
	if who != null:
		start_teleport(who)

## Chạy hiệu ứng cổng rồi dịch chuyển `who` xuống hầm ngục tầng 1.
func start_teleport(who: Node2D) -> void:
	if teleporting or who == null:
		return
	teleporting = true
	teleport_started.emit(who)
	var tree := get_tree()
	tree.paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "velocity" in who:
		who.velocity = Vector2.ZERO
	var keep_modulate: Color = who.modulate
	var keep_scale: Vector2 = who.scale
	_sfx("portal")

	# cổng xoáy (24 khung hình, ~2.4 s, chạy 1 lần)
	play("active")
	frame = 0

	# nhân vật trôi về chân thanh kiếm, nhỏ dần và mờ đi
	var target := global_position + Vector2(0, 6)
	var pull := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	pull.tween_interval(0.35)
	pull.chain().tween_property(who, "global_position", target, PULL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pull.tween_property(who, "scale", keep_scale * 0.35, PULL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	pull.tween_property(who, "modulate", Color(FLASH_COLOR.r, FLASH_COLOR.g, FLASH_COLOR.b, 0.0), PULL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await animation_finished
	if not is_inside_tree():
		return

	# loé sáng che màn hình (lớp này gắn vào root nên còn sống khi đổi scene)
	flash = _make_flash()
	var fin := flash.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fin.tween_property(flash.get_node("Rect"), "color:a", 1.0, FLASH_IN)
	await fin.finished
	if not is_inside_tree():
		return

	# trả lại dáng vẻ bình thường rồi đổi sang hầm ngục
	pull.kill()
	if is_instance_valid(who):
		who.modulate = keep_modulate
		who.scale = keep_scale
	tree.paused = false
	var fl := flash
	var fout := fl.create_tween()
	fout.tween_interval(0.15)
	fout.tween_property(fl.get_node("Rect"), "color:a", 0.0, FLASH_OUT)
	fout.tween_callback(fl.queue_free)
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("enter_dungeon_from_hall"):
		gm.enter_dungeon_from_hall(who)
	else:
		fl.queue_free()

func _make_flash() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "PortalFlash"
	layer.layer = 40
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var rect := ColorRect.new()
	rect.name = "Rect"
	rect.color = Color(FLASH_COLOR.r, FLASH_COLOR.g, FLASH_COLOR.b, 0.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	get_tree().root.add_child(layer)
	return layer

func _sfx(key: String) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_sfx"):
		am.play_sfx(key)
