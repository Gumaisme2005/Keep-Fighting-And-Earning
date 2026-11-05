extends Node2D

const Sprites = preload("res://Scene/Character/Yugi/YugiSprites.gd")
const Flash = preload("res://Scene/Character/Yugi/explosion_flash.gd")
const RELEASE_TIME := 0.8
const IMPACT_TIME := 1.3
const DAMAGE_RATIO := 0.5
var caster: Node2D
var room_rect := Rect2i()
var elapsed := 0.0
var detonated := false
var last_damage := 0
var orb: Sprite2D
var impact_position := Vector2.ZERO
var release_position := Vector2.ZERO

func _ready() -> void:
	var world := get_parent()
	impact_position = global_position
	if world.has_method("get_player_room_index"):
		var index: int = world.get_player_room_index()
		var rooms: Array = world.get("generated_rooms")
		if index >= 0 and index < rooms.size():
			room_rect = rooms[index]
			impact_position = world.to_global((Vector2(room_rect.position) + Vector2(room_rect.size) * 0.5) * 16.0)
	var monster := AnimatedSprite2D.new()
	monster.sprite_frames = Sprites.animation("result-1", 1180)
	monster.sprite_frames.set_animation_loop("default", false)
	monster.sprite_frames.set_animation_speed("default", 5.0)
	monster.material = Sprites.material()
	monster.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	monster.scale = Vector2(0.5, 0.5)
	monster.position.y = -40
	# The sheet faces right; mirror it so the summon always faces the room center.
	var face_left := impact_position.x < global_position.x
	monster.flip_h = face_left
	add_child(monster)
	monster.play("default")
	orb = Sprite2D.new()
	orb.texture = preload("res://Assets/Character/Yugi/result-1-attack.png")
	orb.material = Sprites.material()
	orb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	orb.scale = Vector2(0.65, 0.65)
	orb.position = Vector2(0, -55)
	orb.flip_h = face_left
	orb.hide()
	add_child(orb)
	release_position = orb.global_position
	z_index = 3

func _physics_process(delta: float) -> void:
	elapsed += delta
	if not detonated:
		if elapsed >= RELEASE_TIME:
			orb.show()
			orb.global_position = release_position.lerp(impact_position, clampf((elapsed - RELEASE_TIME) / (IMPACT_TIME - RELEASE_TIME), 0, 1))
		if elapsed >= IMPACT_TIME:
			detonated = true
			orb.hide()
			_detonate()
	if elapsed >= 2.0: queue_free()

func _faces_left() -> bool:
	# Shared by room summons: face the side with the most enemies in the room.
	var left := 0
	var right := 0
	for target in _room_targets():
		var dx := target.global_position.x - global_position.x
		if dx < 0: left += 1
		elif dx > 0: right += 1
	if left != right: return left > right
	# Tie (or no enemies): face the room center instead of a fixed side.
	var world := get_parent()
	if room_rect.size != Vector2i.ZERO and world is Node2D:
		var center := (world as Node2D).to_global((Vector2(room_rect.position) + Vector2(room_rect.size) * 0.5) * 16.0)
		return center.x < global_position.x
	return false

func _room_targets() -> Array[Node2D]:
	var targets: Array[Node2D] = []
	var world := get_parent()
	if room_rect.size == Vector2i.ZERO or not world.has_method("local_to_map"): return targets
	# Spatial membership also includes boss summons absent from RoomManager.enemies.
	for hurtbox in world.find_children("Hurtbox", "Area2D", true, false):
		var target := hurtbox.get_parent()
		if not target.has_method("take_damage"): target = target.get_parent()
		if not target is Node2D or not target.has_method("take_damage"): continue
		if target.is_in_group("player") or target.is_queued_for_deletion() or target.get("is_dead") == true: continue
		if target.get("hp") == null or float(target.get("hp")) <= 0 or targets.has(target): continue
		var cell: Vector2i = world.local_to_map(world.to_local(target.global_position))
		if room_rect.has_point(cell): targets.append(target)
	return targets

func _detonate() -> void:
	var targets := _room_targets()
	# Snapshot all HP before applying any hits; death callbacks cannot change the mean.
	var total_hp := 0.0
	for target in targets: total_hp += float(target.get("hp"))
	last_damage = maxi(1, floori(total_hp / targets.size() * DAMAGE_RATIO)) if not targets.is_empty() else 0
	for target in targets:
		if is_instance_valid(target): target.take_damage(last_damage)
	var flash := Flash.new()
	flash.radius = maxf(120.0, Vector2(room_rect.size).length() * 16.0)
	get_parent().add_child(flash)
	flash.global_position = impact_position
