extends Area2D

var is_ready: bool = false
var is_teleporting: bool = false

func _ready() -> void:
	scale = Vector2(0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var label := Label.new()
	label.text = "[CỔNG QUA TẦNG]"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-60, -34)
	label.size = Vector2(120, 20)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.6, 0.95, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)

	# Thời gian trễ 0.8s để tránh dịch chuyển nhầm ngay khoảnh khắc Boss vừa nổ tung
	await get_tree().create_timer(0.8).timeout
	is_ready = true
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_trigger_teleport()
			break

func _on_body_entered(body: Node2D) -> void:
	if is_ready and body.is_in_group("player"):
		_trigger_teleport()

func _trigger_teleport() -> void:
	if is_teleporting:
		return
	is_teleporting = true
	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_sfx("portal")
	print("[PORTAL] Cổng không gian được kích hoạt!")
	if get_tree():
		get_tree().call_group("game_ui", "show_banner", "ĐANG DỊCH CHUYỂN SANG TẦNG TIẾP THEO...", Color(0.4, 0.85, 1.0))
	if get_parent().has_method("next_level"):
		get_parent().call_deferred("next_level")
