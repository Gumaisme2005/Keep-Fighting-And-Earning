extends "res://scenes/characters/yugi/room_blast.gd"

const FPS := 8.0
var damage := 4
var facing := 1.0
var monster: AnimatedSprite2D
var pull_time := 0.0
var hit_time := 0.0
var end_time := 0.0
var pulled := false
var hit_once := false
var locked: Array[Dictionary] = []

func _ready() -> void:
	# Run after room movement/clamping so locked positions stay exact.
	process_physics_priority = 1000
	var world := get_parent()
	if world.has_method("get_player_room_index"):
		var index: int = world.get_player_room_index()
		var rooms: Array = world.get("generated_rooms")
		if index >= 0 and index < rooms.size(): room_rect = rooms[index]
	monster = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", false)
	var summon_frames := Sprites.frames("result-4", 80, 98, 214)
	var attack_frames := Sprites.frames("result-4", 0, 215, 300)
	var recovery_frames := Sprites.frames("result-4", 0, 301)
	for texture in summon_frames: frames.add_frame("default", texture)
	for texture in attack_frames: frames.add_frame("default", texture)
	for texture in recovery_frames: frames.add_frame("default", texture)
	pull_time = summon_frames.size() / FPS
	hit_time = (summon_frames.size() + 3) / FPS
	end_time = frames.get_frame_count("default") / FPS
	monster.sprite_frames = frames
	monster.material = Sprites.material()
	monster.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	monster.scale = Vector2(0.5, 0.5)
	monster.position.y = -40
	monster.flip_h = facing < 0
	add_child(monster)
	z_index = 3

func _physics_process(delta: float) -> void:
	elapsed += delta
	monster.frame = mini(int(elapsed * FPS), monster.sprite_frames.get_frame_count("default") - 1)
	if not pulled and elapsed >= pull_time:
		pulled = true
		_pull_targets()
	for entry in locked:
		var enemy = entry.target
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true or entry.get("rooted", false): continue
		enemy.global_position = entry.position
		if enemy is CharacterBody2D: enemy.velocity = Vector2.ZERO
	if not hit_once and elapsed >= hit_time:
		hit_once = true
		for entry in locked:
			var enemy = entry.target
			if is_instance_valid(enemy) and enemy.get("is_dead") != true: enemy.take_damage(damage)
	if elapsed >= end_time:
		_release_targets()
		queue_free()

func _pull_targets() -> void:
	var targets := _room_targets()
	for i in range(targets.size()):
		var enemy := targets[i]
		if enemy.get("is_immovable") == true:
			# Rooted targets (Skeleton King crystals) are hit in place, never dragged or frozen.
			locked.append({"target": enemy, "position": enemy.global_position, "restore": true, "rooted": true})
			continue
		var desired := global_position + Vector2(facing * 55, (i - (targets.size() - 1) * 0.5) * 14)
		var destination := _safe_front_position(desired)
		# If there is no valid ground in front, lock in place instead of teleporting into a wall.
		if destination == Vector2.INF: destination = enemy.global_position
		var restore := enemy.is_physics_processing()
		var stun := enemy.get_node_or_null("YugiLightningStun")
		if stun != null: restore = stun.restore_physics
		locked.append({"target": enemy, "position": destination, "restore": restore})
		enemy.set_physics_process(false)
		enemy.global_position = destination

func _safe_front_position(desired: Vector2) -> Vector2:
	var world := get_parent()
	var closest := Vector2.INF
	var distance := INF
	# Use room floor cells, keeping away from the boundary/closed doors.
	for y in range(room_rect.position.y + 1, room_rect.end.y - 1):
		for x in range(room_rect.position.x + 1, room_rect.end.x - 1):
			var point: Vector2 = world.to_global(Vector2(x * 16 + 8, y * 16 + 8))
			if (point.x - global_position.x) * facing < 20: continue
			if world.has_method("is_global_pos_wall_or_door") and world.is_global_pos_wall_or_door(point): continue
			if world.has_method("has_line_of_sight") and not world.has_line_of_sight(global_position, point): continue
			var d := point.distance_squared_to(desired)
			if d < distance:
				distance = d
				closest = point
	return closest

func _release_targets() -> void:
	for entry in locked:
		var enemy = entry.target
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.get("is_dead") == true or entry.get("rooted", false): continue
		if enemy.get_node_or_null("YugiLightningStun") == null:
			enemy.set_physics_process(entry.restore)
	locked.clear()

func _exit_tree() -> void:
	_release_targets()
