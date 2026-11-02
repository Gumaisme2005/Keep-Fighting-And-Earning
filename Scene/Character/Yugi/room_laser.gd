# Reuse the room-scoped enemy lookup; this spell has its own animation/timing.
extends "res://Scene/Character/Yugi/room_blast.gd"

const PEAK_FRAME := 5
const FRAME_SECONDS := 0.2
const BEAM_DURATION := 3.0
const TICK_SECONDS := 0.25
var damage_per_tick := 1
var current_target: Node2D
var monster: AnimatedSprite2D
var beam_active := false
var tick_remaining := 0.0
var beam_origin := Vector2.ZERO

func _ready() -> void:
	var world := get_parent()
	if world.has_method("get_player_room_index"):
		var index: int = world.get_player_room_index()
		var rooms: Array = world.get("generated_rooms")
		if index >= 0 and index < rooms.size(): room_rect = rooms[index]
	monster = AnimatedSprite2D.new()
	monster.sprite_frames = Sprites.animation("result-2", 675)
	monster.material = Sprites.material()
	monster.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	monster.scale = Vector2(0.5, 0.5)
	monster.position.y = -35
	add_child(monster)
	# Physics-driven frames keep the held peak and damage ticks in replay sync.
	monster.frame = 0
	var peak := monster.sprite_frames.get_frame_texture("default", PEAK_FRAME) as AtlasTexture
	beam_origin = (Vector2(1152, 62) - peak.region.position + peak.margin.position - Vector2(90, 80)) * 0.5 + monster.position
	z_index = 3

func _physics_process(delta: float) -> void:
	var previous := elapsed
	elapsed += delta
	var start := PEAK_FRAME * FRAME_SECONDS
	var finish := start + BEAM_DURATION
	beam_active = elapsed >= start and elapsed < finish
	if elapsed < start:
		monster.frame = mini(PEAK_FRAME, int(elapsed / FRAME_SECONDS))
	elif beam_active:
		monster.frame = PEAK_FRAME
		_refresh_target()
		if is_instance_valid(current_target):
			tick_remaining -= maxf(0, elapsed - maxf(previous, start))
			while tick_remaining <= 0 and is_instance_valid(current_target):
				current_target.take_damage(damage_per_tick)
				tick_remaining += TICK_SECONDS
				_refresh_target()
	else:
		current_target = null
		var recovery_frame := PEAK_FRAME + 1 + int((elapsed - finish) / FRAME_SECONDS)
		if recovery_frame >= monster.sprite_frames.get_frame_count("default"):
			queue_free()
			return
		monster.frame = recovery_frame
	if is_instance_valid(current_target):
		monster.flip_h = current_target.global_position.x < global_position.x
	queue_redraw()

func _refresh_target() -> void:
	var targets := _room_targets()
	if is_instance_valid(current_target) and targets.has(current_target): return
	current_target = null
	for target in targets:
		if current_target == null or float(target.get("hp")) > float(current_target.get("hp")):
			current_target = target

func _draw() -> void:
	if not beam_active or not is_instance_valid(current_target): return
	var origin := beam_origin
	if monster.flip_h: origin.x = -origin.x
	var endpoint := to_local(current_target.global_position + Vector2(0, -8))
	draw_line(origin, endpoint, Color(0.55, 0.15, 1.0, 0.5), 11.0, true)
	draw_line(origin, endpoint, Color(0.85, 0.45, 1.0), 6.0, true)
	draw_line(origin, endpoint, Color(1.0, 0.9, 1.0), 2.0, true)
