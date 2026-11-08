extends Area2D

var is_ready: bool = false
var is_teleporting: bool = false

func _ready() -> void:
	scale = Vector2(0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var label := Label.new()
	label.text = "DESCENT GATEWAY"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-70, -34)
	label.size = Vector2(140, 20)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.6, 0.95, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)

	# Safety delay to avoid premature trigger as boss expires
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree():
		return
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
	print("[PORTAL] Descent Gateway activated!")

	# Mở giao diện Chọn Perk trước khi bước xuống tầng sâu hơn
	var uis = get_tree().get_nodes_in_group("game_ui")
	if not uis.is_empty() and uis[0].has_method("open_perk_selection"):
		uis[0].open_perk_selection(func():
			_proceed_to_next_floor()
		)
	else:
		_proceed_to_next_floor()

func _proceed_to_next_floor() -> void:
	if get_tree():
		get_tree().call_group("game_ui", "show_banner", "DESCENDING TO DEEPER VAULTS OF MORIA...", Color(0.4, 0.85, 1.0))
	if get_parent().has_method("next_level"):
		get_parent().call_deferred("next_level")
