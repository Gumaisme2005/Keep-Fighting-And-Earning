extends Node2D
## Miyabi's Frost Wave (released Right Click): a frost crescent that flies along the aim,
## passes through every enemy (one hit each) and fades out with frost_wave_end when it
## reaches a wall or the end of its range. Moves in physics time, so replays stay in sync.

const Sprites = preload("res://Scene/Character/Miyabi/MiyabiSprites.gd")
const Util = preload("res://Scene/Character/Miyabi/miyabi_util.gd")
const Fx = preload("res://Scene/Character/Miyabi/miyabi_fx.gd")

var dir: Vector2 = Vector2.RIGHT
var speed: float = 230.0
var max_range: float = 180.0
var damage: int = 1
var k: float = 1.0               # size from the charge level
var freeze_time: float = 0.0
var travelled: float = 0.0
var hits: Dictionary = {}
var done: bool = false
var sprite: AnimatedSprite2D

func _ready() -> void:
	z_index = 3
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.build(["frost_wave"])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * Sprites.SCALE * k
	sprite.use_parent_material = true
	# The crescent is drawn facing right: mirror it for leftward throws, then tilt to the aim.
	var left := dir.x < 0.0
	sprite.flip_h = left
	sprite.rotation = (-dir if left else dir).angle()
	add_child(sprite)
	sprite.play("frost_wave")

func _physics_process(delta: float) -> void:
	if done:
		return
	var world := get_parent()
	var step := dir * speed * delta
	if travelled >= max_range or Util.is_wall(world, global_position + step):
		_end(world)
		return
	global_position += step
	travelled += step.length()
	var r := 12.0 * k
	for t in Util.enemies(world):
		var id: int = t.get_instance_id()
		if hits.has(id):
			continue
		if Util.hit_point(t).distance_to(global_position) <= r + Util.ENEMY_RADIUS:
			hits[id] = true
			Util.hit(world, t, damage, freeze_time)

func _end(world: Node) -> void:
	done = true
	Fx.spawn(world, "frost_wave_end", global_position, Sprites.SCALE * k, sprite.flip_h, sprite.rotation)
	queue_free()
