class_name DungeonNavHelper
extends RefCounted

## DungeonNavHelper — Chuyên trách kiểm tra va chạm, tầm nhìn (Line of Sight) và thuật toán né tường (Steering).

static func is_cell_wall_or_door(gen: TileMap, cell: Vector2i) -> bool:
	if gen.get_cell_atlas_coords(gen.LAYER_FLOOR, cell) != gen.FLOOR_COORD:
		return true
	if gen.get_layers_count() > 2 and gen.get_cell_source_id(2, cell) != -1:
		return true
	var decor: TileData = gen.get_cell_tile_data(gen.LAYER_DECOR, cell)
	if decor != null and gen.tile_set != null:
		for layer in range(gen.tile_set.get_physics_layers_count()):
			if decor.get_collision_polygons_count(layer) > 0:
				return true
	return false

static func is_global_pos_wall_or_door(gen: TileMap, world_pos: Vector2) -> bool:
	var cell: Vector2i = gen.local_to_map(gen.to_local(world_pos))
	return is_cell_wall_or_door(gen, cell)

static func has_line_of_sight(gen: TileMap, from_global: Vector2, to_global: Vector2) -> bool:
	var p0: Vector2 = gen.to_local(from_global)
	var p1: Vector2 = gen.to_local(to_global)
	var dist: float = p0.distance_to(p1)
	if dist < 4.0:
		return not is_cell_wall_or_door(gen, gen.local_to_map(p1))
	var steps: int = maxi(2, int(ceil(dist / 4.0)))
	var last_cell := Vector2i(999999, 999999)
	for s in range(0, steps + 1):
		var t: float = float(s) / float(steps)
		var sample_local: Vector2 = p0.lerp(p1, t)
		var cell: Vector2i = gen.local_to_map(sample_local)
		if cell == last_cell:
			continue
		last_cell = cell
		if is_cell_wall_or_door(gen, cell):
			return false
	return true

static func get_smart_steer_direction(gen: TileMap, from_global: Vector2, desired_dir: Vector2) -> Vector2:
	if desired_dir == Vector2.ZERO:
		return Vector2.ZERO
	var base_dir: Vector2 = desired_dir.normalized()
	var probe_angles: Array[float] = [0.0, 0.45, -0.45, 0.90, -0.90, 1.35, -1.35]
	for ang in probe_angles:
		var cand: Vector2 = base_dir.rotated(ang)
		var check_pos: Vector2 = from_global + cand * 18.0
		if not is_global_pos_wall_or_door(gen, check_pos) and has_line_of_sight(gen, from_global, check_pos):
			return cand
	return base_dir

static func resolve_player_node(gen: TileMap) -> Node2D:
	if is_instance_valid(gen.the_player) and gen.the_player is CharacterBody2D:
		return gen.the_player
	if gen.get_tree() != null:
		for node in gen.get_tree().get_nodes_in_group("player"):
			if node is CharacterBody2D and is_instance_valid(node):
				gen.the_player = node
				return gen.the_player
	return gen.the_player

static func get_player_room_index(gen: TileMap) -> int:
	var p := resolve_player_node(gen)
	if not is_instance_valid(p):
		return 0
	var local_pos = gen.to_local(p.global_position)
	var cell = gen.local_to_map(local_pos)
	for i in range(gen.generated_rooms.size()):
		if gen.generated_rooms[i].grow(1).has_point(cell):
			gen.visited_rooms[i] = true
			return i
	return -1

static func get_player_exact_grid_position(gen: TileMap) -> Vector2:
	var p := resolve_player_node(gen)
	if not is_instance_valid(p):
		return Vector2.ZERO
	var local_pos: Vector2 = gen.to_local(p.global_position)
	var tile_pos: Vector2 = local_pos / 16.0
	var c_size: float = maxf(1.0, float(gen.cell_size))
	return Vector2(
		(tile_pos.x - c_size * 0.5) / c_size,
		(tile_pos.y - c_size * 0.5) / c_size
	)
