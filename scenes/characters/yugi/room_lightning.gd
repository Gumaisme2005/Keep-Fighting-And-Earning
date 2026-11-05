extends "res://scenes/characters/yugi/room_blast.gd"

const LightningHit = preload("res://scenes/characters/yugi/lightning_hit.gd")
const FPS := 8.0
var damage := 4
var monster: AnimatedSprite2D
var strike_time := 0.0
var total_time := 0.0
var struck := false

func _ready() -> void:
	var world := get_parent()
	if world.has_method("get_player_room_index"):
		var index: int = world.get_player_room_index()
		var rooms: Array = world.get("generated_rooms")
		if index >= 0 and index < rooms.size(): room_rect = rooms[index]
	monster = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", FPS)
	frames.set_animation_loop("default", false)
	var intro := Sprites.frames("result-3-creature-part-1", 0)
	# Part 2 includes remnants of the previous row at its top: exclude them.
	var attack := Sprites.frames("result-3-creature-part-2", 0, 24)
	for texture in intro: frames.add_frame("default", texture)
	for texture in attack: frames.add_frame("default", texture)
	strike_time = (intro.size() + 6) / FPS
	total_time = (intro.size() + attack.size()) / FPS
	monster.sprite_frames = frames
	monster.material = Sprites.material()
	monster.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	monster.scale = Vector2(0.5, 0.5)
	monster.position.y = -40
	# The sheet faces right; turn toward the side holding the most enemies.
	monster.flip_h = _faces_left()
	add_child(monster)
	z_index = 3

func _physics_process(delta: float) -> void:
	elapsed += delta
	monster.frame = mini(int(elapsed * FPS), monster.sprite_frames.get_frame_count("default") - 1)
	if not struck and elapsed >= strike_time:
		struck = true
		for target in _room_targets():
			target.take_damage(damage)
			if is_instance_valid(target) and not target.is_queued_for_deletion():
				LightningHit.apply(target)
	if elapsed >= total_time: queue_free()
