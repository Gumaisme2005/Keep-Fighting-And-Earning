extends Node2D
## Bolt fired by Miyabi's ice spirit: flies straight, bursts (bolt_hit) on the first enemy
## or wall it meets.

const Sprites = preload("res://Scene/Character/Miyabi/MiyabiSprites.gd")
const Util = preload("res://Scene/Character/Miyabi/miyabi_util.gd")
const Fx = preload("res://Scene/Character/Miyabi/miyabi_fx.gd")

var dir: Vector2 = Vector2.RIGHT
var speed: float = 220.0
var life: float = 0.8
var damage: int = 1
var age: float = 0.0
var done: bool = false
var sprite: AnimatedSprite2D

func _ready() -> void:
	z_index = 3
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.build(["bolt"])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * Sprites.SCALE
	sprite.use_parent_material = true
	var left := dir.x < 0.0
	sprite.flip_h = left
	sprite.rotation = (-dir if left else dir).angle()
	add_child(sprite)
	sprite.play("bolt")

func _physics_process(delta: float) -> void:
	if done:
		return
	age += delta
	var world := get_parent()
	var step := dir * speed * delta
	if age >= life or Util.is_wall(world, global_position + step):
		_burst(world)
		return
	global_position += step
	for t in Util.enemies(world):
		if Util.hit_point(t).distance_to(global_position) <= 5.0 + Util.ENEMY_RADIUS:
			t.take_damage(damage)
			_burst(world)
			return

func _burst(world: Node) -> void:
	done = true
	Fx.spawn(world, "bolt_hit", global_position, Sprites.SCALE, sprite.flip_h, sprite.rotation)
	queue_free()
