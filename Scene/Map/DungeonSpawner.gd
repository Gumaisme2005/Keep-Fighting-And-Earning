class_name DungeonSpawner
extends RefCounted

## DungeonSpawner — Chuyên trách quy hoạch và khởi tạo thực thể (Player, Quái, Boss, Rương, Bẫy gai, Portal).

## Thương nhân lang thang (hiệp sĩ Joanna / pháp sư Eleonore) có thể đứng ở phòng xuất phát tầng 3, 6, 9, 12…
const WANDERING_MERCHANT = preload("res://Scene/Map/Merchants/wandering_merchant.gd")

static func plan_traps(gen: TileMap) -> void:
	gen.reserved_trap_positions.clear()

	for i in range(1, gen.generated_rooms.size()):
		if gen.room_types[i] == gen.RoomType.COMBAT:
			var room = gen.generated_rooms[i]
			var center = room.get_center()
			var trap_positions: Array[Vector2i] = []
			var pattern_type = gen.rng.randi() % 3

			if pattern_type == 0:
				var offset = 3
				var length = 4
				trap_positions.append(center)
				trap_positions.append(center + Vector2i(0, -length))
				trap_positions.append(center + Vector2i(0, length))
				trap_positions.append(center + Vector2i(-offset, 0))
				trap_positions.append(center + Vector2i(offset, 0))
			elif pattern_type == 1:
				var offset = 2
				trap_positions.append(center + Vector2i(-offset, -offset))
				trap_positions.append(center + Vector2i(offset, -offset))
				trap_positions.append(center + Vector2i(-offset, offset))
				trap_positions.append(center + Vector2i(offset, offset))
			elif pattern_type == 2:
				var radius = 3
				for dir in [
					Vector2i(-radius, 0), Vector2i(radius, 0),
					Vector2i(0, -radius), Vector2i(0, radius),
					Vector2i(-2, -2), Vector2i(2, -2),
					Vector2i(-2, 2), Vector2i(2, 2)
				]:
					trap_positions.append(center + dir)

			for pos in trap_positions:
				if gen.get_cell_atlas_coords(gen.LAYER_FLOOR, pos) == gen.FLOOR_COORD:
					if not gen.reserved_trap_positions.has(pos):
						gen.reserved_trap_positions.append(pos)
					for dx in range(-2, 3):
						for dy in range(-2, 3):
							gen.forbidden_decor_cells[pos + Vector2i(dx, dy)] = true

static func is_valid_entity_spawn_cell(gen: TileMap, cell: Vector2i) -> bool:
	if gen.get_cell_atlas_coords(gen.LAYER_FLOOR, cell) != gen.FLOOR_COORD:
		return false
	if gen.reserved_trap_positions.has(cell):
		return false
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var check_cell = cell + Vector2i(dx, dy)
			if gen.get_cell_source_id(gen.LAYER_DECOR, check_cell) != -1:
				return false
			if (dx == 0 and dy == 0) and gen.get_cell_atlas_coords(gen.LAYER_FLOOR, check_cell) != gen.FLOOR_COORD:
				return false
	return true

static func is_valid_combat_spawn_cell(gen: TileMap, room_index: int, cell: Vector2i) -> bool:
	if not is_valid_entity_spawn_cell(gen, cell):
		return false
	return not gen.enable_combat_room_variants or gen._combat_room_spawn_cells.get(room_index, {}).has(cell)

static func plan_enemy_spawns(gen: TileMap) -> void:
	gen.planned_enemy_spawns.clear()
	for i in range(gen.generated_rooms.size()):
		if gen.room_types[i] != gen.RoomType.COMBAT:
			gen.planned_enemy_spawns.append([])
			continue

		var room = gen.generated_rooms[i]
		var num_e = gen.rng.randi_range(gen.min_enemies, gen.max_enemies)
		var room_spawns: Array = []
		var used_cells: Dictionary = {}

		for j in range(num_e):
			var enemy_type_idx = gen.rng.randi() % gen.enemy_scenes.size()
			var loot_seed = gen.rng.randi()
			var chosen_cell := Vector2i(-9999, -9999)

			for attempt in range(30):
				var rx = gen.rng.randi_range(room.position.x + 3, room.end.x - 4)
				var ry = gen.rng.randi_range(room.position.y + 3, room.end.y - 4)
				var candidate = Vector2i(rx, ry)
				if not used_cells.has(candidate) and is_valid_combat_spawn_cell(gen, i, candidate):
					chosen_cell = candidate
					break

			if chosen_cell == Vector2i(-9999, -9999):
				for rx in range(room.position.x + 3, room.end.x - 3):
					for ry in range(room.position.y + 3, room.end.y - 3):
						var candidate = Vector2i(rx, ry)
						if not used_cells.has(candidate) and is_valid_combat_spawn_cell(gen, i, candidate):
							chosen_cell = candidate
							break
					if chosen_cell != Vector2i(-9999, -9999):
						break

			if chosen_cell != Vector2i(-9999, -9999):
				used_cells[chosen_cell] = true
				room_spawns.append({
					"cell": chosen_cell,
					"enemy_idx": enemy_type_idx,
					"loot_seed": loot_seed
				})

		gen.planned_enemy_spawns.append(room_spawns)

static func spawn_entities(gen: TileMap) -> void:
	if gen.generated_rooms.is_empty():
		return

	if gen.the_player == null:
		var character_to_spawn: PackedScene = gen.PLAYER_SCENE
		if gen.is_inside_tree() and gen.get_node_or_null("/root/GameManager") != null and GameManager.selected_character_scene != null:
			character_to_spawn = GameManager.selected_character_scene

		gen.the_player = character_to_spawn.instantiate()
		gen.the_player.name = "Player"
		gen.the_player.z_index = 2
		gen.add_child(gen.the_player)

	gen.the_player.global_position = gen.to_global(gen.map_to_local(gen.generated_rooms[0].get_center()))

	for i in range(1, gen.generated_rooms.size()):
		var room = gen.generated_rooms[i]
		var type = gen.room_types[i]

		if type == gen.RoomType.TREASURE:
			var chest = gen.CHEST_SCENE.instantiate()
			if "loot_seed" in chest:
				chest.loot_seed = (gen.get_effective_seed_string() + "_chest_" + str(i)).hash()
			gen.add_child(chest)
			chest.global_position = gen.to_global(gen.map_to_local(room.get_center()))

		elif type == gen.RoomType.COMBAT:
			var manager = gen.ROOM_MANAGER.instantiate()
			manager.room_index = i
			manager.room_rect = room
			manager.tilemap = gen

			var shape = RectangleShape2D.new()
			shape.size = Vector2((room.size.x - 4) * 16, (room.size.y - 4) * 16)
			manager.get_node("CollisionShape2D").shape = shape
			manager.global_position = gen.to_global(gen.map_to_local(room.get_center()))

			var entrances = []
			for x in range(room.position.x - 1, room.end.x + 1):
				for y in range(room.position.y - 1, room.end.y + 1):
					if x == room.position.x - 1 or x == room.end.x or y == room.position.y - 1 or y == room.end.y:
						if gen.get_cell_atlas_coords(gen.LAYER_FLOOR, Vector2i(x, y)) == gen.FLOOR_COORD:
							entrances.append(Vector2i(x, y))

			manager.entrances = entrances
			gen.add_child(manager)
			gen.room_managers[i] = manager

			var spawns: Array = gen.planned_enemy_spawns[i] if i < gen.planned_enemy_spawns.size() else []
			for spawn_info in spawns:
				var enemy = gen.enemy_scenes[spawn_info["enemy_idx"]].instantiate()
				if "loot_seed" in enemy:
					enemy.loot_seed = spawn_info["loot_seed"]
				if gen.current_level > 1:
					var bonus_hp: int = (gen.current_level - 1) * 2
					if "hp" in enemy:
						enemy.hp += bonus_hp
						if "max_hp" in enemy:
							enemy.max_hp = enemy.hp
					if "damage" in enemy and gen.current_level >= 3:
						enemy.damage += 1
				enemy.z_index = 2
				enemy.add_to_group("enemies")
				gen.add_child(enemy)
				enemy.global_position = gen.to_global(gen.map_to_local(spawn_info["cell"]))
				manager.enemies.append(enemy)

		elif type == gen.RoomType.BOSS:
			var manager = gen.ROOM_MANAGER.instantiate()
			manager.is_boss_room = true
			manager.room_index = i
			manager.room_rect = room
			manager.tilemap = gen

			var shape = RectangleShape2D.new()
			shape.size = Vector2((room.size.x - 4) * 16, (room.size.y - 4) * 16)
			manager.get_node("CollisionShape2D").shape = shape
			manager.global_position = gen.to_global(gen.map_to_local(room.get_center()))

			var entrances = []
			for x in range(room.position.x - 1, room.end.x + 1):
				for y in range(room.position.y - 1, room.end.y + 1):
					if x == room.position.x - 1 or x == room.end.x or y == room.position.y - 1 or y == room.end.y:
						if gen.get_cell_atlas_coords(gen.LAYER_FLOOR, Vector2i(x, y)) == gen.FLOOR_COORD:
							entrances.append(Vector2i(x, y))

			manager.entrances = entrances
			gen.add_child(manager)
			gen.room_managers[i] = manager

			if i == gen.skeleton_king_room_index:
				var king: Node2D = gen.SKELETON_KING_SCRIPT.new()
				king.name = "SkeletonKing"
				king.tilemap = gen
				king.room_rect = room
				king.room_manager = manager
				king.level = gen.current_level
				king.z_index = 1
				king.add_to_group("enemies")
				king.add_to_group("boss")
				king.position = Vector2(room.position.x + room.size.x * 0.5, room.position.y + 1) * 16.0
				gen.add_child(king)
				manager.enemies.append(king)
				gen.active_boss = king
				print("[BOSS] Tầng ", gen.current_level, " - Boss: Skeleton King xuất hiện!")
				continue

			var boss_instance: Node2D
			if gen.current_level % 2 != 0:
				boss_instance = gen.NECROMANCER_SCENE.instantiate()
				print("[BOSS] Tầng ", gen.current_level, " - Boss: Necromancer xuất hiện!")
			else:
				boss_instance = gen.RIDER_ORC_SCENE.instantiate()
				print("[BOSS] Tầng ", gen.current_level, " - Boss: Orc Rider xuất hiện!")

			boss_instance.z_index = 2
			boss_instance.add_to_group("enemies")
			boss_instance.add_to_group("boss")
			if gen.current_level > 1:
				var boss_bonus_hp: int = (gen.current_level - 1) * 20
				if "hp" in boss_instance:
					boss_instance.hp += boss_bonus_hp
					if "max_hp" in boss_instance:
						boss_instance.max_hp = boss_instance.hp
				if "melee_damage" in boss_instance:
					boss_instance.melee_damage += gen.current_level - 1
				if "damage" in boss_instance:
					boss_instance.damage += gen.current_level - 1
			gen.add_child(boss_instance)

			boss_instance.global_position = gen.to_global(gen.map_to_local(room.get_center()))
			manager.enemies.append(boss_instance)
			gen.active_boss = boss_instance

	for pos in gen.reserved_trap_positions:
		var trap = gen.SPIKE_TRAP.instantiate()
		gen.add_child(trap)
		trap.global_position = gen.to_global(gen.map_to_local(pos))

	WANDERING_MERCHANT.spawn_on_floor(gen)

	gen.DUNGEON_ATMOSPHERE.setup_dungeon_atmosphere(gen, gen.the_player, gen.get_effective_seed_string().hash())
	if gen.is_inside_tree() and gen.get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_bgm("dungeon")

	gen.room_state_changed.emit()

static func spawn_portal(gen: TileMap, pos: Vector2) -> void:
	print("[VICTORY] Boss đã gục ngã! Triệu hồi Cổng Dịch Chuyển & 2 Rương Kho Báu...")
	var portal = gen.PORTAL_SCENE.instantiate()
	gen.add_child(portal)
	portal.global_position = pos
	spawn_boss_chests(gen, pos)

static func spawn_boss_chests(gen: TileMap, center_pos: Vector2) -> void:
	var offsets: Array[Vector2] = [Vector2(-48, 8), Vector2(48, 8)]
	for i in range(2):
		var chest = gen.CHEST_SCENE.instantiate()
		chest.set("is_boss_chest", true)
		if "loot_seed" in chest:
			chest.loot_seed = (gen.get_effective_seed_string() + "_boss_chest_" + str(gen.current_level) + "_" + str(i)).hash()
		gen.add_child(chest)
		chest.global_position = center_pos + offsets[i]
