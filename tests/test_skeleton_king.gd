extends Node
## Skeleton King arena: floor rotation, fixed layout, crystals, lasers, summons, death.

const WORLD_SCENE := preload("res://scenes/main/world.tscn")
const LaserVolley := preload("res://scenes/enemies/bosses/skeleton_king/skeleton_king_laser.gd")

var passed := 0
var failed := 0

func _check(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  [PASS] ", name, (" - " + detail) if detail != "" else "")
	else:
		failed += 1
		print("  [FAIL] ", name, (" - " + detail) if detail != "" else "")

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

func _ready() -> void:
	print("\n=== SKELETON KING TESTS ===")
	_test_floor_rotation_and_layout()
	await _test_boss_fight()
	print("[SUMMARY] SKELETON KING: %d PASSED | %d FAILED" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)

func _make_gen(level: int) -> TileMap:
	var world = WORLD_SCENE.instantiate()
	var gen: TileMap = world.get_node("TileMap")
	gen.map_seed = "ALOALO1234"
	gen.current_level = level
	gen.generate_dungeon()
	return gen

func _test_floor_rotation_and_layout() -> void:
	var expected := {1: false, 2: false, 3: true, 4: false, 5: false, 6: true, 9: true}
	var ok := true
	for lv in expected:
		var gen := _make_gen(lv)
		var boss_idx: int = gen.room_types.find(gen.RoomType.BOSS)
		var is_king: bool = gen.skeleton_king_room_index == boss_idx and boss_idx >= 0
		if is_king != expected[lv]:
			ok = false
			print("    level ", lv, " king room mismatch")
		if is_king:
			var room: Rect2i = gen.generated_rooms[boss_idx]
			if room.size != gen.SKELETON_KING_ROOM_SIZE:
				ok = false
			# Clean arena: no pillars and no decor clusters inside.
			for x in range(room.position.x, room.end.x):
				for y in range(room.position.y, room.end.y):
					var c := Vector2i(x, y)
					if gen.get_cell_atlas_coords(gen.LAYER_FLOOR, c) != gen.FLOOR_COORD or gen.get_cell_source_id(gen.LAYER_DECOR, c) != -1:
						ok = false
		gen.get_parent().free()
	_check(ok, "SK-01: Skeleton King arena replaces the boss room on floors 3, 6, 9 (fixed 32x18, clean floor)")

	# Non-boss rooms keep their size on king floors (rng consumption preserved).
	var g3 := _make_gen(3)
	var boss3: int = g3.skeleton_king_room_index
	var others_ok := true
	for i in range(g3.generated_rooms.size()):
		if i == boss3:
			continue
		var r: Rect2i = g3.generated_rooms[i]
		if r.size.x < g3.room_min_size or r.size.x > g3.room_max_size or r.size.y < g3.room_min_size or r.size.y > g3.room_max_size:
			others_ok = false
	_check(others_ok and g3.generated_rooms.size() == 16, "SK-02: Other rooms on a king floor stay within normal size bounds")
	g3.get_parent().free()

func _test_boss_fight() -> void:
	GameManager.set_character_by_index(2)
	GameManager.current_seed = "ALOALO1234"
	GameManager.current_level = 3
	var world = WORLD_SCENE.instantiate()
	add_child(world)
	await _frames(4)
	var gen: TileMap = world.get_node("TileMap")
	var king = gen.active_boss
	_check(is_instance_valid(king) and king.name == "SkeletonKing", "SK-03: Floor 3 spawns the Skeleton King as the active boss")
	if not is_instance_valid(king):
		return
	var room: Rect2i = gen.generated_rooms[gen.skeleton_king_room_index]
	var player: Node2D = gen._resolve_player_node()
	player.max_hp = 999
	player.hp = 999

	# Anchored behind the top wall: sprite bottom sits on the arena's top edge.
	var spr: AnimatedSprite2D = king.sprite
	var sprite_bottom: float = king.position.y + spr.position.y + 348.0 * spr.scale.y * 0.5
	_check(absf(sprite_bottom - room.position.y * 16.0) < 0.5 and absf(king.position.x - (room.position.x + room.size.x * 0.5) * 16.0) < 0.5,
		"SK-04: King is centred on the top wall with his body rising above the arena")

	var hp_before: int = king.hp
	king.take_damage(999)
	_check(king.hp == hp_before, "SK-05: King is invulnerable to direct hits")

	# Walk into the arena: room locks, King awakens with crystals and arena camera.
	player.global_position = gen.to_global(gen.map_to_local(room.get_center() + Vector2i(0, 4)))
	await _frames(20)
	king.action_timer = 999.0 # freeze the AI so the checks below are controlled
	var crystals: Array = king.crystals.duplicate()
	_check(king.is_active and king.awakened and crystals.size() == king.max_crystals, "SK-06: Entering the arena awakens the King and raises Soul Crystals", "crystals=%d" % crystals.size())
	var cam: Camera2D = get_viewport().get_camera_2d()
	_check(cam != null and cam.name == "SkeletonKingArenaCamera", "SK-07: Arena camera frames the whole room and the King")
	var in_room := true
	for c in crystals:
		if not room.has_point(gen.local_to_map(c.position)):
			in_room = false
	_check(in_room and crystals[0].has_node("Hurtbox"), "SK-08: Crystals spawn inside the arena with a Hurtbox")

	# Evenly spaced parallel laser lines.
	var cols: Array[int] = king.get_parallel_lines(true, 4, 1)
	var rows: Array[int] = king.get_parallel_lines(false, 4, 2)
	var even := cols.size() >= 7 and rows.size() >= 4
	for i in range(1, cols.size()):
		even = even and cols[i] - cols[i - 1] == 4
	for i in range(1, rows.size()):
		even = even and rows[i] - rows[i - 1] == 4
	even = even and cols[0] >= room.position.x and cols[-1] < room.end.x and rows[-1] < room.end.y
	_check(even, "SK-09: Vertical / horizontal laser lines are parallel and evenly spaced inside the arena", "cols=%s rows=%s" % [cols, rows])

	# Beam damages a player standing on it, not one standing in the gap.
	var p_local: Vector2 = gen.to_local(player.global_position)
	var on_beam: Node2D = LaserVolley.new()
	on_beam.tilemap = gen
	on_beam.add_line(Vector2(p_local.x, room.position.y * 16.0), Vector2(p_local.x, room.end.y * 16.0), 0.0, 0.1, 0.3)
	var off_beam: Node2D = LaserVolley.new()
	off_beam.tilemap = gen
	off_beam.add_line(Vector2(p_local.x + 40.0, room.position.y * 16.0), Vector2(p_local.x + 40.0, room.end.y * 16.0), 0.0, 0.1, 0.3)
	gen.add_child(on_beam)
	gen.add_child(off_beam)
	await _frames(12)
	_check(on_beam.player_hits == 1 and off_beam.player_hits == 0, "SK-10: Active beam hits the player on it once; the gap between beams is safe")
	await _frames(30)
	_check(not is_instance_valid(on_beam), "SK-11: Laser volley frees itself after firing")

	# Shockwave: beams fire one after another.
	king._fire_shockwave()
	var wave: Node2D = king.volleys[-1]
	var starts: Array = []
	for b in wave.beams:
		starts.append(float(b["start"]))
	var sorted_starts := starts.duplicate()
	sorted_starts.sort()
	_check(wave.beams.size() >= 5 and sorted_starts[-1] > sorted_starts[0], "SK-12: Slam shockwave staggers parallel beams across the arena", "beams=%d" % wave.beams.size())
	wave.queue_free()

	# Every pattern stays inside the arena; grid mixes both orientations.
	var patterns_ok := true
	for pat in ["vertical", "horizontal", "grid", "double_vertical"]:
		king._fire_laser_volley(pat)
		var v: Node2D = king.volleys[-1]
		var has_v := false
		var has_h := false
		for b in v.beams:
			var a: Vector2 = b["a"]
			var e: Vector2 = b["b"]
			if is_equal_approx(a.x, e.x): has_v = true
			if is_equal_approx(a.y, e.y): has_h = true
			var rect := Rect2(Vector2(room.position) * 16.0, Vector2(room.size) * 16.0).grow(0.5)
			patterns_ok = patterns_ok and rect.has_point(a) and rect.has_point(e)
		if pat == "grid": patterns_ok = patterns_ok and has_v and has_h
		if pat == "vertical": patterns_ok = patterns_ok and has_v and not has_h
		if pat == "horizontal": patterns_ok = patterns_ok and has_h and not has_v
		v.queue_free()
	king._fire_shockwave("wave_out")
	var wo: Node2D = king.volleys[-1]
	patterns_ok = patterns_ok and wo.beams.size() >= 8
	wo.queue_free()
	_check(patterns_ok, "SK-12b: Vertical, horizontal, grid, double and shockwave patterns all stay inside the arena")

	# Summon existing dungeon enemies.
	king._summon_minions()
	await _frames(2)
	var minions_ok: bool = king.minions.size() >= 2
	for m in king.minions:
		minions_ok = minions_ok and m.is_active and room.has_point(gen.local_to_map(m.position)) and king.room_manager.enemies.has(m)
	_check(minions_ok, "SK-13: King summons existing enemies into the arena", "count=%d" % king.minions.size())

	# Shattering a crystal wounds the King; below 50% he enrages.
	var c0: Node2D = crystals[0]
	c0.take_damage(c0.hp)
	_check(king.hp == hp_before - king.crystal_damage, "SK-14: Shattering a Soul Crystal damages the King", "hp=%d/%d" % [king.hp, king.max_hp])

	# Crystals are rooted: pushes, Yugi pulls and lightning stuns cannot move or freeze them.
	var c1: Node2D = crystals[1]
	var home: Vector2 = c1.position
	c1.global_position += Vector2(60, 40)
	c1.set_physics_process(false)
	preload("res://scenes/characters/yugi/lightning_hit.gd").apply(c1)
	var pull = preload("res://scenes/characters/yugi/room_pull.gd").new()
	gen.add_child(pull)
	pull.global_position = player.global_position
	await _frames(1)
	pull._pull_targets()
	var age_before: float = c1.age
	await _frames(10)
	_check(c1.position == home and c1.is_physics_processing() and c1.age > age_before,
		"SK-14b: Soul Crystals cannot be moved, pulled or frozen", "pos=%s home=%s" % [c1.position, home])
	pull.queue_free()

	# A crystal left alone expires and heals the King.
	var hp_mid: int = king.hp
	c1.age = c1.lifetime - 0.05
	await _frames(6)
	_check(c1.expired and king.hp == mini(king.max_hp, hp_mid + king.get_expire_heal()) and not king.crystals.has(c1),
		"SK-14c: An expired crystal vanishes and heals the King", "hp %d -> %d (+%d)" % [hp_mid, king.hp, king.get_expire_heal()])
	await _frames(45)
	_check(not is_instance_valid(c1), "SK-14d: Expired crystal is removed after its fade-out")
	while king.hp > king.max_hp / 2:
		king.on_crystal_shattered(null)
	king.action = ""
	await _frames(3)
	_check(king.enraged and king.current_phase == 2, "SK-15: King enrages at 50% HP")
	king.action_timer = 999.0

	# Kill: minions & crystals vanish, death plays, room unlocks and portal opens.
	while king.hp > 0:
		king.on_crystal_shattered(null)
	await _frames(2)
	_check(king.is_dead and king.minions.is_empty() and king.crystals.is_empty(), "SK-16: Death clears crystals and summoned minions")
	await _frames(200)
	var portal_found := false
	for child in gen.get_children():
		if child.name.begins_with("Portal") or child.get_script() == preload("res://scenes/dungeon/portal.gd"):
			portal_found = true
	var cam_after: Camera2D = get_viewport().get_camera_2d()
	_check(not is_instance_valid(king) and portal_found and cam_after != null and cam_after.name == "Camera2D",
		"SK-17: After the death animation the arena unlocks, a portal opens and the hero camera returns")
	world.queue_free()
