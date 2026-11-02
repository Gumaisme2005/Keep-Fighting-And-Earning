extends "res://Scene/Character/Yugi/room_blast.gd"

const FireBeam = preload("res://Scene/Character/Yugi/fire_beam.gd")
const FPS := 8.0
const FIRE_DURATION := 3.0
const TICK := 0.25
var move_name := "result-5"
var damage_per_tick := 1
var monster: AnimatedSprite2D
var start_time := 0.0
var fire_active := false
var tick_left := 0.0
var attack_start := 0
var beams: Dictionary = {}

func _ready() -> void:
	var world := get_parent()
	if world.has_method("get_player_room_index"):
		var index: int = world.get_player_room_index()
		var rooms: Array = world.get("generated_rooms")
		if index >= 0 and index < rooms.size(): room_rect = rooms[index]
	monster = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", false)
	var summon := Sprites.frames("result-5", 0, 98, 190)
	var attack := Sprites.frames("result-5", 0, 195, 280)
	for texture in summon: frames.add_frame("default", texture)
	for texture in attack: frames.add_frame("default", texture)
	attack_start = summon.size()
	start_time = (attack_start + 3) / FPS
	monster.sprite_frames = frames
	monster.material = Sprites.material()
	monster.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	monster.position.y = -40
	monster.scale = Vector2(0.5, 0.5)
	add_child(monster)
	z_index = 3

func _physics_process(delta: float) -> void:
	var previous := elapsed
	elapsed += delta
	fire_active = elapsed >= start_time and elapsed < start_time + FIRE_DURATION
	if elapsed < start_time:
		monster.frame = int(elapsed * FPS)
	elif fire_active:
		var phase := int((elapsed - start_time) * 10) % 2
		monster.frame = attack_start + 3 + phase
		var targets := _room_targets()
		var live_ids: Array[int] = []
		for target in targets:
			var id := target.get_instance_id()
			live_ids.append(id)
			if not beams.has(id):
				var beam := FireBeam.new()
				add_child(beam)
				beams[id] = beam
			beams[id].aim(global_position + Vector2(24, -15), target.global_position + Vector2(0, -8), phase)
		for id in beams.keys():
			if not live_ids.has(id):
				beams[id].queue_free()
				beams.erase(id)
		tick_left -= maxf(0, elapsed - maxf(previous, start_time))
		while tick_left <= 0:
			for target in targets:
				if is_instance_valid(target) and target.get("is_dead") != true:
					target.take_damage(damage_per_tick)
			tick_left += TICK
	else:
		for beam in beams.values(): beam.queue_free()
		beams.clear()
		monster.frame = attack_start + 2
		if elapsed >= start_time + FIRE_DURATION + 0.4: queue_free()
