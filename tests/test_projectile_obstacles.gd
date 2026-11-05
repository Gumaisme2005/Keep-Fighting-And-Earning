extends Node

var failed := 0

func check(ok: bool, label: String) -> void:
	print("[PASS] " if ok else "[FAIL] ", label)
	if not ok:
		failed += 1

func _ready() -> void:
	# Use the real map/TileSet, isolated from generation, enemies and player input.
	var world = load("res://world.tscn").instantiate()
	var map = world.get_node("TileMap")
	world.remove_child(map)
	world.free()
	map.set_script(null)
	add_child(map)
	map.set_script(load("res://Scene/Map/dungeon_generator.gd"))
	map.clear()
	# Attach the generator after entering the tree to skip automatic generation.
	for x in range(7):
		for y in range(3):
			map.set_cell(0, Vector2i(x, y), 0, Vector2i(1, 6))
	var cell := Vector2i(3, 1)
	var start: Vector2 = map.map_to_local(Vector2i(1, 1))
	var finish: Vector2 = map.map_to_local(Vector2i(5, 1))
	var center: Vector2 = map.map_to_local(cell)
	check(map.has_line_of_sight(start, finish), "Open floor lets shots through")
	map.set_cell(1, cell, 1, Vector2i(1, 2))
	check(map.is_global_pos_wall_or_door(center), "Wooden crate blocks shots")
	check(not map.has_line_of_sight(start, finish), "Crate blocks the full shot segment")
	check(not map.has_line_of_sight(start, center), "Crate blocks the endpoint")
	check(not map.has_line_of_sight(center, finish), "Shots cannot start inside a crate")
	for mode in ["straight", "homing", "drift"]:
		var shot = load("res://Scene/Character/Doraemon/dora_projectile.gd").new()
		shot.mode = mode
		shot.hit_anim = ""
		map.add_child(shot)
		shot.position = start
		shot._move(map, finish - start)
		check(shot.done and shot.position == start, mode + " cannot skip a crate in one frame")
	var bounce = load("res://Scene/Character/Doraemon/dora_projectile.gd").new()
	map.add_child(bounce)
	bounce.position = start
	bounce.velocity = Vector2.RIGHT * 300
	bounce.bounces = 1
	bounce._move_bounce(map, finish - start)
	check(bounce.position == start and bounce.velocity.x < 0 and bounce.bounces == 0, "Ricochet reverses at the crate")
	var air = load("res://Scene/Character/Doraemon/air_cannon_shot.gd").new()
	map.add_child(air)
	air.position = start
	air._physics_process(0.25)
	check(air.spent and air.position == start, "Air Cannon cannot skip a crate")
	map.set_cell(1, cell, 1, Vector2i(0, 0))
	check(not map.is_global_pos_wall_or_door(center) and map.has_line_of_sight(start, finish), "Non-solid decoration does not block shots")
	map.free()
	print("[SUMMARY] Projectile obstacle failures: ", failed)
	get_tree().quit(1 if failed else 0)
