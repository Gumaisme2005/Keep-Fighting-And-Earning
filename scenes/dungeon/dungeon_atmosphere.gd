extends Node2D

const TEX_COBWEB_LG: Texture2D = preload("res://Assets/Map/Atmosphere/cobweb_corner_large.png")
const TEX_COBWEB_SM: Texture2D = preload("res://Assets/Map/Atmosphere/cobweb_corner_small.png")
const TEX_COBWEB_WALL: Texture2D = preload("res://Assets/Map/Atmosphere/cobweb_wall_hanging.png")

const TEX_SKELETON_ADVENTURER: Texture2D = preload("res://Assets/Map/Atmosphere/skeleton_fallen_adventurer.png")
const TEX_SKELETON_RIBCAGE: Texture2D = preload("res://Assets/Map/Atmosphere/skeleton_ribcage_skull.png")
const TEX_SKELETON_BONE_PILE: Texture2D = preload("res://Assets/Map/Atmosphere/skeleton_bone_pile.png")
const TEX_SKELETON_SHATTERED: Texture2D = preload("res://Assets/Map/Atmosphere/skeleton_shattered.png")

const TEX_WALL_CRACK_MAJOR: Texture2D = preload("res://Assets/Map/Atmosphere/wall_crack_major.png")
const TEX_WALL_CRACK_MINOR: Texture2D = preload("res://Assets/Map/Atmosphere/wall_crack_minor.png")

const TEX_DEBRIS_RUBBLE: Texture2D = preload("res://Assets/Map/Atmosphere/debris_stone_rubble.png")
const TEX_DEBRIS_IRON: Texture2D = preload("res://Assets/Map/Atmosphere/debris_iron_scrap.png")
const TEX_BROKEN_PILLAR: Texture2D = preload("res://Assets/Map/Atmosphere/broken_pillar.png")
const TEX_IRON_CHAINS: Texture2D = preload("res://Assets/Map/Atmosphere/iron_chains_wall.png")

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
	var sparks: CPUParticles2D = null
	var base_energy: float = 0.95
	var current_energy: float = 0.0
	var room_index: int = -1
	var tilemap: TileMap = null

	func _ready() -> void:
		z_index = 1
		if DisplayServer.get_name() == "headless":
			set_process(false)
			return

		point_light = PointLight2D.new()
		point_light.texture = load("res://scenes/dungeon/dungeon_atmosphere.gd").get_radial_light_texture()
		point_light.color = flame_color
		point_light.energy = 0.0
		point_light.texture_scale = 1.65
		point_light.visible = false
		add_child(point_light)

		sparks = CPUParticles2D.new()
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
		sparks.emitting = false
		add_child(sparks)

	func _process(delta: float) -> void:
		var is_visited: bool = false
		if room_index == 0:
			is_visited = true
		elif tilemap != null and "visited_rooms" in tilemap:
			is_visited = tilemap.visited_rooms.has(room_index)

		var target_energy: float = base_energy if is_visited else 0.0
		current_energy = lerpf(current_energy, target_energy, delta * 3.5)

		var t: float = Time.get_ticks_msec() * 0.006 + phase
		var flicker: float = sin(t * 2.3) * 0.12 + cos(t * 5.7) * 0.08 + sin(t * 11.3) * 0.05
		if point_light != null:
			if current_energy > 0.05:
				point_light.visible = true
				point_light.energy = maxf(0.0, current_energy + flicker * (current_energy / base_energy))
				point_light.texture_scale = 1.60 + flicker * 0.35
				if sparks != null and not sparks.emitting:
					sparks.emitting = true
			else:
				point_light.visible = false
				point_light.energy = 0.0
				if sparks != null and sparks.emitting:
					sparks.emitting = false
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
			draw_rect(Rect2(-6, -3, 3, 7), iron_dark, true)
			draw_rect(Rect2(-4, -1, 5, 2), iron_mid, true)
		elif wall_side == "right":
			draw_rect(Rect2(3, -3, 3, 7), iron_dark, true)
			draw_rect(Rect2(-1, -1, 5, 2), iron_mid, true)
		else:
			draw_rect(Rect2(-3, -2, 6, 5), iron_dark, true)
			draw_rect(Rect2(-2, 1, 4, 2), iron_mid, true)

		# Thân đuốc gỗ & vòng sắt kẹp trên tường
		draw_rect(Rect2(-1.5, -4, 3, 6), wood_col, true)
		draw_rect(Rect2(-2.5, -4, 5, 1.5), iron_mid, true)

		if current_energy > 0.08:
			var alpha_ratio: float = clampf(current_energy / base_energy, 0.0, 1.0)
			# Quầng sáng hắt lên mặt gạch tường
			draw_circle(Vector2(0, -6.5), (7.5 + h_pulse) * alpha_ratio, Color(flame_color.r, flame_color.g, flame_color.b, 0.16 * alpha_ratio))

			# Ngọn lửa bập bùng sát tường
			draw_circle(Vector2(sway * 0.35, -6.5), (3.6 + h_pulse * 0.25) * alpha_ratio, Color(flame_color.r, flame_color.g, flame_color.b, 0.90 * alpha_ratio))
			draw_circle(Vector2(sway * 0.7, -9.5 - absf(h_pulse) * 0.4), 2.3 * alpha_ratio, Color(flame_color.r, flame_color.g * 0.78, flame_color.b, 0.84 * alpha_ratio))
			# Lõi lửa vàng sáng
			draw_circle(Vector2(sway * 0.25, -6.2), 2.0 * alpha_ratio, Color(core_color.r, core_color.g, core_color.b, core_color.a * alpha_ratio))
			draw_circle(Vector2(sway * 0.5, -8.3), 1.2 * alpha_ratio, Color(1.0, 0.98, 0.85, 0.95 * alpha_ratio))


class GhostlyWispNode extends Node2D:
	var base_pos: Vector2 = Vector2.ZERO
	var orbit_radius: Vector2 = Vector2(28.0, 20.0)
	var speed_mult: Vector2 = Vector2(1.1, 0.85)
	var phase: float = 0.0
	var wisp_color: Color = Color(0.18, 0.82, 1.0, 0.85)
	var trail_positions: Array[Vector2] = []
	var wisp_light: PointLight2D = null
	var mist: CPUParticles2D = null
	var room_index: int = -1
	var tilemap: TileMap = null
	var current_alpha: float = 0.0

	func _ready() -> void:
		z_index = 3
		base_pos = position
		for i in range(5):
			trail_positions.append(global_position)

		if DisplayServer.get_name() == "headless":
			set_process(false)
			return

		wisp_light = PointLight2D.new()
		wisp_light.texture = load("res://scenes/dungeon/dungeon_atmosphere.gd").get_radial_light_texture()
		wisp_light.color = Color(0.20, 0.85, 1.0, 1.0)
		wisp_light.energy = 0.0
		wisp_light.texture_scale = 1.15
		wisp_light.visible = false
		add_child(wisp_light)

		mist = CPUParticles2D.new()
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
		mist.emitting = false
		add_child(mist)

	func _process(delta: float) -> void:
		var is_visited: bool = false
		if room_index == 0:
			is_visited = true
		elif tilemap != null and "visited_rooms" in tilemap:
			is_visited = tilemap.visited_rooms.has(room_index)

		var target_alpha: float = 1.0 if is_visited else 0.0
		current_alpha = lerpf(current_alpha, target_alpha, delta * 3.0)

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
			if current_alpha > 0.05:
				wisp_light.visible = true
				var pulse: float = (sin(t * 3.2) + 1.0) * 0.5
				wisp_light.energy = (0.38 + pulse * 0.26) * current_alpha
				wisp_light.texture_scale = 1.0 + pulse * 0.30
				if mist != null and not mist.emitting:
					mist.emitting = true
			else:
				wisp_light.visible = false
				wisp_light.energy = 0.0
				if mist != null and mist.emitting:
					mist.emitting = false

		queue_redraw()

	func _draw() -> void:
		if current_alpha <= 0.05:
			return
		var t: float = Time.get_ticks_msec() * 0.004 + phase
		var alpha_wave: float = (0.65 + 0.30 * sin(t * 1.8)) * current_alpha

		for idx in range(1, trail_positions.size()):
			var rel_p: Vector2 = trail_positions[idx] - global_position
			var ratio: float = 1.0 - float(idx) / float(trail_positions.size())
			draw_circle(rel_p, 4.2 * ratio, Color(0.15, 0.75, 1.0, 0.25 * ratio * alpha_wave))

		draw_circle(Vector2.ZERO, 8.5, Color(0.10, 0.62, 0.95, 0.18 * alpha_wave))
		draw_circle(Vector2.ZERO, 4.8, Color(wisp_color.r, wisp_color.g, wisp_color.b, 0.72 * alpha_wave))
		draw_circle(Vector2(0, 2.5), 3.4, Color(wisp_color.r, wisp_color.g, wisp_color.b, 0.52 * alpha_wave))
		draw_circle(Vector2(0, -0.5), 2.4, Color(0.82, 0.98, 1.0, 0.92 * alpha_wave))
		draw_rect(Rect2(-2.0, -1.2, 1.2, 1.5), Color(0.04, 0.12, 0.22, 0.85 * current_alpha), true)
		draw_rect(Rect2(0.8, -1.2, 1.2, 1.5), Color(0.04, 0.12, 0.22, 0.85 * current_alpha), true)


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
	var old_atmo := tilemap.get_node_or_null("DungeonAtmosphere")
	if old_atmo != null:
		old_atmo.queue_free()

	var root := Node2D.new()
	root.name = "DungeonAtmosphere"
	tilemap.add_child(root)

	# 0. Nền đá sâu thẳm Moria (Deep Obsidian Bedrock Backdrop)
	# Khắc phục triệt để lỗi viền xám và khoảng trống xám vô tận ngoài rìa bản đồ
	var existing_bg: Node = null
	if tilemap.get_parent() != null:
		existing_bg = tilemap.get_parent().get_node_or_null("BedrockBackground")
	if existing_bg == null:
		var bg := ColorRect.new()
		bg.name = "BedrockVoidBackdrop"
		bg.z_index = -100
		bg.z_as_relative = false
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.color = Color(0.012, 0.012, 0.018, 1.0)
		bg.position = Vector2(-30000, -30000)
		bg.size = Vector2(60000, 60000)
		root.add_child(bg)

	# 1. Ánh sáng ngục tối heo hắt (Màn đêm Moria tối sâu thẳm như Đế Chế)
	if DisplayServer.get_name() != "headless":
		var modulate_node := CanvasModulate.new()
		modulate_node.name = "EerieAmbientModulate"
		modulate_node.color = Color(0.06, 0.06, 0.10, 1.0)
		root.add_child(modulate_node)

	# 2. Đèn lồng linh hồn ấm áp quanh người chơi rọi đường đi trong bóng tối
	if is_instance_valid(player) and DisplayServer.get_name() != "headless":
		var existing_light := player.get_node_or_null("PlayerSoulLight") as PointLight2D
		if existing_light == null:
			var p_light := PointLight2D.new()
			p_light.name = "PlayerSoulLight"
			p_light.texture = get_radial_light_texture()
			p_light.color = Color(1.0, 0.88, 0.68, 1.0)
			p_light.energy = 1.15
			p_light.texture_scale = 3.2
			player.add_child(p_light)

	var atmo_rng := RandomNumberGenerator.new()
	atmo_rng.seed = rng_seed ^ 0x5A3C91E7

	var rooms: Array = tilemap.get("generated_rooms")
	var types: Array = tilemap.get("room_types")
	if rooms == null or rooms.is_empty():
		return root

	var skeleton_textures: Array[Texture2D] = [
		TEX_SKELETON_ADVENTURER,
		TEX_SKELETON_RIBCAGE,
		TEX_SKELETON_BONE_PILE,
		TEX_SKELETON_SHATTERED
	]

	# Duyệt qua từng phòng hầm ngục
	for i in range(rooms.size()):
		var room: Rect2i = rooms[i]
		var r_type: int = types[i] if i < types.size() else 1

		# A. Đuốc tường (Moria Wall Sconce Bracket)
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
			torch.tilemap = tilemap
			torch.room_index = i
			root.add_child(torch)

		# B. Bóng ma xanh lượn lờ (Ghostly Blue Wisps)
		var num_wisps: int = 3 if r_type == 3 else 2
		for w_idx in range(num_wisps):
			var wx: int = atmo_rng.randi_range(room.position.x + 4, maxi(room.position.x + 5, room.end.x - 5))
			var wy: int = atmo_rng.randi_range(room.position.y + 4, maxi(room.position.y + 5, room.end.y - 5))
			var wisp := GhostlyWispNode.new()
			wisp.position = tilemap.map_to_local(Vector2i(wx, wy))
			wisp.orbit_radius = Vector2(atmo_rng.randf_range(22.0, 42.0), atmo_rng.randf_range(16.0, 32.0))
			wisp.speed_mult = Vector2(atmo_rng.randf_range(0.75, 1.35), atmo_rng.randf_range(0.65, 1.25))
			wisp.phase = atmo_rng.randf_range(0.0, TAU)
			wisp.tilemap = tilemap
			wisp.room_index = i
			root.add_child(wisp)

		# C. Mạng nhện BẤT ĐỐI XỨNG & NGẪU NHIÊN (Không tự động gán cả 4 góc)
		# 40% cơ hội không có mạng nhện, 45% có 1 mạng, 15% có 2 mạng (Boss room có 1-2 mạng)
		var cobweb_quota: int = 0
		var web_roll: float = atmo_rng.randf()
		if r_type == 3:
			cobweb_quota = 1 if web_roll < 0.5 else 2
		else:
			if web_roll < 0.40:
				cobweb_quota = 0
			elif web_roll < 0.85:
				cobweb_quota = 1
			else:
				cobweb_quota = 2

		var possible_corners: Array[Dictionary] = [
			{"cell": room.position, "offset": Vector2(-6, -6), "flip_h": false, "flip_v": false},
			{"cell": Vector2i(room.end.x - 1, room.position.y), "offset": Vector2(6, -6), "flip_h": true, "flip_v": false},
			{"cell": Vector2i(room.position.x, room.end.y - 1), "offset": Vector2(-6, 6), "flip_h": false, "flip_v": true},
			{"cell": Vector2i(room.end.x - 1, room.end.y - 1), "offset": Vector2(6, 6), "flip_h": true, "flip_v": true}
		]
		# Trộn ngẫu nhiên các góc để phân bổ hoàn toàn tự nhiên
		for k in range(possible_corners.size() - 1, 0, -1):
			var swap_idx := atmo_rng.randi_range(0, k)
			var temp = possible_corners[k]
			possible_corners[k] = possible_corners[swap_idx]
			possible_corners[swap_idx] = temp

		for w_i in range(mini(cobweb_quota, possible_corners.size())):
			var c_info: Dictionary = possible_corners[w_i]
			var web_sprite := Sprite2D.new()
			var pick_tex_roll := atmo_rng.randf()
			if pick_tex_roll < 0.35:
				web_sprite.texture = TEX_COBWEB_LG
			elif pick_tex_roll < 0.80:
				web_sprite.texture = TEX_COBWEB_SM
			else:
				web_sprite.texture = TEX_COBWEB_WALL

			web_sprite.position = tilemap.map_to_local(c_info["cell"]) + c_info["offset"]
			web_sprite.flip_h = bool(c_info["flip_h"]) if atmo_rng.randf() > 0.2 else not bool(c_info["flip_h"])
			web_sprite.flip_v = bool(c_info["flip_v"]) if atmo_rng.randf() > 0.2 else not bool(c_info["flip_v"])
			web_sprite.modulate = Color(1.0, 1.0, 1.0, atmo_rng.randf_range(0.38, 0.65))
			web_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			web_sprite.z_index = 0
			root.add_child(web_sprite)

		# D. Hài cốt & Xác Xương phong phú kiểu Minecraft (Pixel-Art Đa Dạng)
		var num_skeletons: int = atmo_rng.randi_range(2, 4) if r_type == 3 else atmo_rng.randi_range(1, 3)
		var placed_skels := 0
		var attempts := 0
		while placed_skels < num_skeletons and attempts < 15:
			attempts += 1
			var sx: int = atmo_rng.randi_range(room.position.x + 2, room.end.x - 3)
			var sy: int = atmo_rng.randi_range(room.position.y + 2, room.end.y - 3)
			var s_cell := Vector2i(sx, sy)
			if tilemap.get_cell_atlas_coords(0, s_cell) == Vector2i(1, 6):
				var skel_sprite := Sprite2D.new()
				var tex_idx := atmo_rng.randi_range(0, skeleton_textures.size() - 1)
				skel_sprite.texture = skeleton_textures[tex_idx]
				skel_sprite.position = tilemap.map_to_local(s_cell) + Vector2(atmo_rng.randf_range(-4, 4), atmo_rng.randf_range(-4, 4))
				skel_sprite.flip_h = atmo_rng.randf() > 0.5
				skel_sprite.rotation = atmo_rng.randf_range(-0.25, 0.25)
				skel_sprite.modulate = Color(0.92, 0.90, 0.86, atmo_rng.randf_range(0.82, 0.98))
				skel_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				skel_sprite.z_index = 0
				root.add_child(skel_sprite)
				placed_skels += 1

		# E. Vết nứt tường đá cổ xưa (Wall Cracks & Fissures)
		var num_cracks: int = atmo_rng.randi_range(2, 4)
		for c_idx in range(num_cracks):
			var cx: int = atmo_rng.randi_range(room.position.x + 1, room.end.x - 2)
			var cy: int = room.position.y # Tường Bắc
			if atmo_rng.randf() > 0.5:
				cy = room.end.y - 1 # Tường Nam
			var crack_sprite := Sprite2D.new()
			crack_sprite.texture = TEX_WALL_CRACK_MAJOR if atmo_rng.randf() > 0.5 else TEX_WALL_CRACK_MINOR
			crack_sprite.position = tilemap.map_to_local(Vector2i(cx, cy)) + Vector2(atmo_rng.randf_range(-3, 3), atmo_rng.randf_range(-3, 3))
			crack_sprite.flip_h = atmo_rng.randf() > 0.5
			crack_sprite.flip_v = atmo_rng.randf() > 0.5
			crack_sprite.modulate = Color(1.0, 1.0, 1.0, atmo_rng.randf_range(0.68, 0.90))
			crack_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			crack_sprite.z_index = 1
			root.add_child(crack_sprite)

		# F. Cột đá đổ nát (Ruined Broken Pillars)
		if room.size.x >= 10 and room.size.y >= 9:
			if atmo_rng.randf() < 0.65:
				var pillar_pos := room.position + Vector2i(2, 2)
				if atmo_rng.randf() > 0.5:
					pillar_pos = Vector2i(room.end.x - 3, room.position.y + 2)
				var pillar_sprite := Sprite2D.new()
				pillar_sprite.texture = TEX_BROKEN_PILLAR
				pillar_sprite.position = tilemap.map_to_local(pillar_pos)
				pillar_sprite.flip_h = atmo_rng.randf() > 0.5
				pillar_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				pillar_sprite.z_index = 1
				root.add_child(pillar_sprite)

		# G. Xiềng xích sắt trên tường (Iron Chains & Wall Shackles)
		if atmo_rng.randf() < 0.55:
			var chain_x: int = atmo_rng.randi_range(room.position.x + 2, room.end.x - 3)
			var chain_cell := Vector2i(chain_x, room.position.y)
			if _is_wall_tile(tilemap, chain_cell):
				var chain_sprite := Sprite2D.new()
				chain_sprite.texture = TEX_IRON_CHAINS
				chain_sprite.position = tilemap.map_to_local(chain_cell) + Vector2(0, 2)
				chain_sprite.flip_h = atmo_rng.randf() > 0.5
				chain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				chain_sprite.z_index = 1
				root.add_child(chain_sprite)

		# H. Đống đổ nát đá trầm tích & Sắt thép vụn (Stone Rubble & Iron Scraps)
		var num_debris: int = atmo_rng.randi_range(2, 4)
		var placed_debris := 0
		var d_attempts := 0
		while placed_debris < num_debris and d_attempts < 15:
			d_attempts += 1
			var dx: int = atmo_rng.randi_range(room.position.x + 1, room.end.x - 2)
			var dy: int = atmo_rng.randi_range(room.position.y + 1, room.end.y - 2)
			var d_cell := Vector2i(dx, dy)
			if tilemap.get_cell_atlas_coords(0, d_cell) == Vector2i(1, 6):
				var d_sprite := Sprite2D.new()
				d_sprite.texture = TEX_DEBRIS_RUBBLE if atmo_rng.randf() > 0.5 else TEX_DEBRIS_IRON
				d_sprite.position = tilemap.map_to_local(d_cell) + Vector2(atmo_rng.randf_range(-3, 3), atmo_rng.randf_range(-3, 3))
				d_sprite.flip_h = atmo_rng.randf() > 0.5
				d_sprite.rotation = atmo_rng.randf_range(-0.35, 0.35)
				d_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				d_sprite.z_index = 0
				root.add_child(d_sprite)
				placed_debris += 1

	return root
