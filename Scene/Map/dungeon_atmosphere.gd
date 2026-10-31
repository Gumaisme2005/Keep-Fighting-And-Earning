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
	var wall_side: String = "top" # "top", "bottom", "left", "right"
	var point_light: PointLight2D = null
	var base_energy: float = 0.88

	func _ready() -> void:
		z_index = 1
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
		sparks.amount = 6
		sparks.lifetime = 0.65
		sparks.direction = Vector2(0, -1)
		sparks.spread = 24.0
		sparks.gravity = Vector2(0, -24.0)
		sparks.initial_velocity_min = 6.0
		sparks.initial_velocity_max = 15.0
		sparks.scale_amount_min = 1.2
		sparks.scale_amount_max = 2.2
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
		var sway: float = sin(t * 3.1) * 1.1
		var h_pulse: float = cos(t * 4.7) * 1.2

		# Giá sắt đính trực tiếp vào gạch tường (Wall Sconce Bracket)
		var iron_dark := Color(0.16, 0.17, 0.22, 0.98)
		var iron_mid := Color(0.28, 0.31, 0.38, 0.98)
		var wood_col := Color(0.44, 0.27, 0.14, 0.98)

		if wall_side == "left":
			# Bản lề sắt đóng chặt vào tường bên trái
			draw_rect(Rect2(-6, -3, 3, 7), iron_dark, true)
			draw_rect(Rect2(-4, -1, 5, 2), iron_mid, true)
		elif wall_side == "right":
			# Bản lề sắt đóng chặt vào tường bên phải
			draw_rect(Rect2(3, -3, 3, 7), iron_dark, true)
			draw_rect(Rect2(-1, -1, 5, 2), iron_mid, true)
		else:
			# Bản lề sắt đóng vào tường Bắc/Nam
			draw_rect(Rect2(-3, -2, 6, 5), iron_dark, true)
			draw_rect(Rect2(-2, 1, 4, 2), iron_mid, true)

		# Thân đuốc gỗ & vòng sắt kẹp trên tường
		draw_rect(Rect2(-1.5, -4, 3, 6), wood_col, true)
		draw_rect(Rect2(-2.5, -4, 5, 1.5), iron_mid, true)

		# Quầng sáng hắt lên mặt gạch tường
		draw_circle(Vector2(0, -6.5), 7.5 + h_pulse, Color(flame_color.r, flame_color.g, flame_color.b, 0.16))

		# Ngọn lửa bập bùng sát tường
		draw_circle(Vector2(sway * 0.35, -6.5), 3.6 + h_pulse * 0.25, Color(flame_color.r, flame_color.g, flame_color.b, 0.90))
		draw_circle(Vector2(sway * 0.7, -9.5 - absf(h_pulse) * 0.4), 2.3, Color(flame_color.r, flame_color.g * 0.78, flame_color.b, 0.84))
		# Lõi lửa vàng sáng
		draw_circle(Vector2(sway * 0.25, -6.2), 2.0, core_color)
		draw_circle(Vector2(sway * 0.5, -8.3), 1.2, Color(1.0, 0.98, 0.85, 0.95))


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


static func _is_wall_tile(tilemap: TileMap, cell: Vector2i) -> bool:
	return tilemap.get_cell_source_id(0, cell) != -1 and tilemap.get_cell_atlas_coords(0, cell) != Vector2i(1, 6)

static func _find_wall_torch_mounts(tilemap: TileMap, room: Rect2i) -> Array[Dictionary]:
	var mounts: Array[Dictionary] = []

	# 1. Hai ngọn đuốc đính trực tiếp lên Tường Bắc (y = room.position.y - 1)
	var top_y: int = room.position.y - 1
	var top_targets: Array[int] = [room.position.x + 3, room.end.x - 4]
	for base_x in top_targets:
		for dx in [0, 1, -1, 2, -2, 3, -3]:
			var tx: int = clampi(base_x + dx, room.position.x + 1, room.end.x - 2)
			var c := Vector2i(tx, top_y)
			if _is_wall_tile(tilemap, c) and _is_wall_tile(tilemap, c + Vector2i(-1, 0)) and _is_wall_tile(tilemap, c + Vector2i(1, 0)):
				mounts.append({
					"cell": c,
					"pos": tilemap.map_to_local(c) + Vector2(0, 4),
					"side": "top"
				})
				break

	# 2. Một ngọn đuốc đính lên Tường Tây (x = room.position.x - 1)
	var left_x: int = room.position.x - 1
	var mid_y: int = room.position.y + int(room.size.y / 2)
	for dy in [-3, 3, -4, 4, -2, 2, 0]:
		var ty: int = clampi(mid_y + dy, room.position.y + 2, room.end.y - 3)
		var c := Vector2i(left_x, ty)
		if _is_wall_tile(tilemap, c) and _is_wall_tile(tilemap, c + Vector2i(0, -1)) and _is_wall_tile(tilemap, c + Vector2i(0, 1)):
			mounts.append({
				"cell": c,
				"pos": tilemap.map_to_local(c) + Vector2(4, 0),
				"side": "left"
			})
			break

	# 3. Một ngọn đuốc đính lên Tường Đông (x = room.end.x)
	var right_x: int = room.end.x
	for dy in [-3, 3, -4, 4, -2, 2, 0]:
		var ty: int = clampi(mid_y + dy, room.position.y + 2, room.end.y - 3)
		var c := Vector2i(right_x, ty)
		if _is_wall_tile(tilemap, c) and _is_wall_tile(tilemap, c + Vector2i(0, -1)) and _is_wall_tile(tilemap, c + Vector2i(0, 1)):
			mounts.append({
				"cell": c,
				"pos": tilemap.map_to_local(c) + Vector2(-4, 0),
				"side": "right"
			})
			break

	return mounts

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

	# 3. Đính đuốc lửa bập bùng trực tiếp lên gạch tường & thả những bóng ma xanh lượn lờ
	for i in range(rooms.size()):
		var room: Rect2i = rooms[i]
		var r_type: int = types[i] if i < types.size() else 1

		# Màu lửa đuốc theo loại phòng (Cam ấm cho phòng thường, Đỏ huyết ngục cho phòng Boss, Vàng kim cho phòng Kho báu)
		var f_col := Color(1.0, 0.55, 0.16, 1.0)
		if r_type == 3: # BOSS
			f_col = Color(1.0, 0.25, 0.42, 1.0)
		elif r_type == 2: # TREASURE
			f_col = Color(1.0, 0.78, 0.22, 1.0)

		var wall_mounts: Array[Dictionary] = _find_wall_torch_mounts(tilemap, room)
		for m in wall_mounts:
			var torch := TorchNode.new()
			torch.flame_color = f_col
			torch.wall_side = String(m.get("side", "top"))
			torch.phase = atmo_rng.randf_range(0.0, TAU)
			torch.position = m.get("pos", Vector2.ZERO)
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

