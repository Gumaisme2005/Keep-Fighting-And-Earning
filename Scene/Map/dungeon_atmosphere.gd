extends Node2D

static var _shared_light_tex: GradientTexture2D = null

static func get_radial_light_texture() -> GradientTexture2D:
	if _shared_light_tex != null:
		return _shared_light_tex
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 0.92, 0.80, 0.55),
		Color(1.0, 0.85, 0.65, 0.18),
		Color(1.0, 0.80, 0.50, 0.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.70, 1.0])

	var tex := GradientTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.gradient = grad
	_shared_light_tex = tex
	return _shared_light_tex


class TorchNode extends Node2D:
	var flame_color: Color = Color(1.0, 0.55, 0.16, 1.0)
	var core_color: Color = Color(1.0, 0.92, 0.42, 1.0)
	var phase: float = 0.0
	var point_light: PointLight2D = null
	var base_energy: float = 0.88

	func _ready() -> void:
		z_index = 2
		if DisplayServer.get_name() == "headless":
			set_process(false)
			return

		point_light = PointLight2D.new()
		point_light.texture = get_script().get_radial_light_texture() if get_script().has_method("get_radial_light_texture") else null
		if point_light.texture == null:
			point_light.texture = load("res://Scene/Map/dungeon_atmosphere.gd").get_radial_light_texture()
		point_light.color = flame_color
		point_light.energy = base_energy
		point_light.texture_scale = 1.65
		add_child(point_light)

		var sparks := CPUParticles2D.new()
		sparks.amount = 7
		sparks.lifetime = 0.75
		sparks.direction = Vector2(0, -1)
		sparks.spread = 28.0
		sparks.gravity = Vector2(0, -26.0)
		sparks.initial_velocity_min = 8.0
		sparks.initial_velocity_max = 18.0
		sparks.scale_amount_min = 1.5
		sparks.scale_amount_max = 2.6
		sparks.color = flame_color.lightened(0.25)
		sparks.position = Vector2(0, -6)
		add_child(sparks)

	func _process(_delta: float) -> void:
		var t: float = Time.get_ticks_msec() * 0.006 + phase
		var flicker: float = sin(t * 2.3) * 0.12 + cos(t * 5.7) * 0.08 + sin(t * 11.3) * 0.05
		if point_light != null:
			point_light.energy = maxf(0.45, base_energy + flicker)
			point_light.texture_scale = 1.60 + flicker * 0.35
		queue_redraw()

	func _draw() -> void:
		var t: float = Time.get_ticks_msec() * 0.008 + phase
		var sway: float = sin(t * 3.1) * 1.4
		var h_pulse: float = cos(t * 4.7) * 1.5

		# Đế sắt & thân đuốc pixel-art
		draw_rect(Rect2(-3, 2, 6, 3), Color(0.22, 0.24, 0.28, 0.95), true)
		draw_rect(Rect2(-2, -3, 4, 7), Color(0.42, 0.26, 0.14, 0.98), true)
		draw_rect(Rect2(-3, -4, 6, 2), Color(0.28, 0.30, 0.35, 0.98), true)

		# Quầng sáng nền dưới chân đuốc
		draw_circle(Vector2(0, -6), 9.0 + h_pulse, Color(flame_color.r, flame_color.g, flame_color.b, 0.18))

		# Ngọn lửa ngoài bập bùng
		draw_circle(Vector2(sway * 0.4, -7.0), 4.2 + h_pulse * 0.3, Color(flame_color.r, flame_color.g, flame_color.b, 0.88))
		draw_circle(Vector2(sway * 0.8, -10.5 - absf(h_pulse) * 0.5), 2.8, Color(flame_color.r, flame_color.g * 0.8, flame_color.b, 0.82))
		# Lõi lửa vàng rực
		draw_circle(Vector2(sway * 0.3, -6.5), 2.3, core_color)
		draw_circle(Vector2(sway * 0.6, -9.0), 1.4, Color(1.0, 0.98, 0.85, 0.95))


class GhostlyWispNode extends Node2D:
	var base_pos: Vector2 = Vector2.ZERO
	var orbit_radius: Vector2 = Vector2(28.0, 20.0)
	var speed_mult: Vector2 = Vector2(1.1, 0.85)
	var phase: float = 0.0
	var wisp_color: Color = Color(0.18, 0.82, 1.0, 0.85)
	var trail_positions: Array[Vector2] = []
	var wisp_light: PointLight2D = null

	func _ready() -> void:
		z_index = 4
		base_pos = position
		for i in range(5):
			trail_positions.append(global_position)

		if DisplayServer.get_name() == "headless":
			set_process(false)
			return

		wisp_light = PointLight2D.new()
		wisp_light.texture = load("res://Scene/Map/dungeon_atmosphere.gd").get_radial_light_texture()
		wisp_light.color = Color(0.20, 0.85, 1.0, 1.0)
		wisp_light.energy = 0.52
		wisp_light.texture_scale = 1.15
		add_child(wisp_light)

		var mist := CPUParticles2D.new()
		mist.amount = 6
		mist.lifetime = 0.9
		mist.direction = Vector2(0, -1)
		mist.spread = 180.0
		mist.gravity = Vector2(0, -8.0)
		mist.initial_velocity_min = 4.0
		mist.initial_velocity_max = 10.0
		mist.scale_amount_min = 1.5
		mist.scale_amount_max = 2.8
		mist.color = Color(0.25, 0.88, 1.0, 0.55)
		add_child(mist)

	func _process(_delta: float) -> void:
		var t: float = Time.get_ticks_msec() * 0.0014 + phase
		var offset := Vector2(
			sin(t * speed_mult.x) * orbit_radius.x + cos(t * 0.45) * 8.0,
			cos(t * speed_mult.y + 0.8) * orbit_radius.y + sin(t * 2.2) * 4.0
		)
		position = base_pos + offset

		trail_positions.push_front(global_position)
		if trail_positions.size() > 6:
			trail_positions.pop_back()

		if wisp_light != null:
			var pulse: float = (sin(t * 3.2) + 1.0) * 0.5
			wisp_light.energy = 0.38 + pulse * 0.26
			wisp_light.texture_scale = 1.0 + pulse * 0.30

		queue_redraw()

	func _draw() -> void:
		var t: float = Time.get_ticks_msec() * 0.004 + phase
		var alpha_Wave: float = 0.65 + 0.30 * sin(t * 1.8)

		# Vẽ đuôi linh hồn xanh mờ ảo phía sau
		for idx in range(1, trail_positions.size()):
			var rel_p: Vector2 = trail_positions[idx] - global_position
			var ratio: float = 1.0 - float(idx) / float(trail_positions.size())
			draw_circle(rel_p, 4.2 * ratio, Color(0.15, 0.75, 1.0, 0.25 * ratio * alpha_Wave))

		# Quầng hào quang ma mị bên ngoài
		draw_circle(Vector2.ZERO, 8.5, Color(0.10, 0.62, 0.95, 0.18 * alpha_Wave))
		# Thân bóng ma xanh lượn lờ
		draw_circle(Vector2.ZERO, 4.8, Color(wisp_color.r, wisp_color.g, wisp_color.b, 0.72 * alpha_Wave))
		draw_circle(Vector2(0, 2.5), 3.4, Color(wisp_color.r, wisp_color.g, wisp_color.b, 0.52 * alpha_Wave))
		# Lõi linh hồn trắng xanh
		draw_circle(Vector2(0, -0.5), 2.4, Color(0.82, 0.98, 1.0, 0.92 * alpha_Wave))
		# Hai đốm mắt linh hồn nhỏ
		draw_rect(Rect2(-2.0, -1.2, 1.2, 1.5), Color(0.04, 0.12, 0.22, 0.85), true)
		draw_rect(Rect2(0.8, -1.2, 1.2, 1.5), Color(0.04, 0.12, 0.22, 0.85), true)


static func setup_dungeon_atmosphere(tilemap: TileMap, player: Node2D, rng_seed: int) -> Node2D:
	# Dọn bầu không khí cũ nếu có
	var old_atmo := tilemap.get_node_or_null("DungeonAtmosphere")
	if old_atmo != null:
		old_atmo.queue_free()

	var root := Node2D.new()
	root.name = "DungeonAtmosphere"
	tilemap.add_child(root)

	# 1. Ánh sáng ngục tối heo hắt (CanvasModulate trầm lạnh)
	if DisplayServer.get_name() != "headless":
		var modulate_node := CanvasModulate.new()
		modulate_node.name = "EerieAmbientModulate"
		modulate_node.color = Color(0.56, 0.58, 0.70, 1.0)
		root.add_child(modulate_node)

	# 2. Đèn lồng linh hồn ấm áp quanh người chơi
	if is_instance_valid(player) and DisplayServer.get_name() != "headless":
		var existing_light := player.get_node_or_null("PlayerSoulLight") as PointLight2D
		if existing_light == null:
			var p_light := PointLight2D.new()
			p_light.name = "PlayerSoulLight"
			p_light.texture = get_radial_light_texture()
			p_light.color = Color(1.0, 0.88, 0.68, 1.0)
			p_light.energy = 0.78
			p_light.texture_scale = 2.6
			player.add_child(p_light)

	var atmo_rng := RandomNumberGenerator.new()
	atmo_rng.seed = rng_seed ^ 0x5A3C91E7

	var rooms: Array = tilemap.get("generated_rooms")
	var types: Array = tilemap.get("room_types")
	if rooms == null or rooms.is_empty():
		return root

	# 3. Đặt đuốc lửa bập bùng & những bóng ma xanh lượn lờ trong từng phòng
	for i in range(rooms.size()):
		var room: Rect2i = rooms[i]
		var r_type: int = types[i] if i < types.size() else 1

		# Màu lửa đuốc theo loại phòng (Cam ấm cho phòng thường, Đỏ huyết ngục cho phòng Boss, Vàng kim cho phòng Kho báu)
		var f_col := Color(1.0, 0.55, 0.16, 1.0)
		if r_type == 3: # BOSS
			f_col = Color(1.0, 0.25, 0.42, 1.0)
		elif r_type == 2: # TREASURE
			f_col = Color(1.0, 0.78, 0.22, 1.0)

		var torch_cells: Array[Vector2i] = [
			Vector2i(room.position.x + 2, room.position.y + 1),
			Vector2i(room.end.x - 3, room.position.y + 1),
			Vector2i(room.position.x + 2, room.end.y - 2),
			Vector2i(room.end.x - 3, room.end.y - 2)
		]

		for tc in torch_cells:
			var torch := TorchNode.new()
			torch.flame_color = f_col
			torch.phase = atmo_rng.randf_range(0.0, TAU)
			torch.position = tilemap.map_to_local(tc)
			root.add_child(torch)

		# Thả 2-3 bóng xanh lượn lờ (Ghostly Blue Wisps) trong mỗi phòng
		var num_wisps: int = 3 if r_type == 3 else 2
		for w_idx in range(num_wisps):
			var wx: int = atmo_rng.randi_range(room.position.x + 4, maxi(room.position.x + 5, room.end.x - 5))
			var wy: int = atmo_rng.randi_range(room.position.y + 4, maxi(room.position.y + 5, room.end.y - 5))
			var wisp := GhostlyWispNode.new()
			wisp.position = tilemap.map_to_local(Vector2i(wx, wy))
			wisp.orbit_radius = Vector2(atmo_rng.randf_range(22.0, 42.0), atmo_rng.randf_range(16.0, 32.0))
			wisp.speed_mult = Vector2(atmo_rng.randf_range(0.75, 1.35), atmo_rng.randf_range(0.65, 1.25))
			wisp.phase = atmo_rng.randf_range(0.0, TAU)
			root.add_child(wisp)

	return root

