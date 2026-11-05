extends Node2D
## Twin Barrels round. Flies along the aim (the sprite faces right; mirrored and tilted for
## other directions), bursts with *_bullet_hit on the first enemy or wall. Rounds fired in the
## white-haired form pierce: they hit every enemy on their path once and burst at walls.
## Moves in physics time, so replays stay in sync.

const Sprites = preload("res://Scene/Character/LuongTho/LTSprites.gd")
const Util = preload("res://Scene/Character/LuongTho/lt_util.gd")

var form: String = "base"
var dir: Vector2 = Vector2.RIGHT
var speed: float = 320.0
var max_range: float = 220.0
var damage: int = 1
var pierce: bool = false
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
	sprite.sprite_frames = Sprites.bullet_frames()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * Sprites.SCALE
	sprite.use_parent_material = true
	var left := dir.x < 0.0
	sprite.flip_h = left
	sprite.offset = Sprites.offset(left, Sprites.BULLET_FRAME, Sprites.BULLET_PIVOT)
	sprite.rotation = (-dir if left else dir).angle()
	add_child(sprite)
	sprite.play(form + "_fly")

func _physics_process(delta: float) -> void:
	if done:
		return
	var world := get_parent()
	var step := dir * speed * delta
	if travelled >= max_range or Util.is_wall(world, global_position + step):
		_burst(world)
		return
	global_position += step
	travelled += step.length()
	for t in Util.enemies(world):
		var id: int = t.get_instance_id()
		if hits.has(id):
			continue
		if Util.hit_point(t).distance_to(global_position) <= 4.0 + Util.ENEMY_RADIUS:
			hits[id] = true
			t.take_damage(damage)
			if not pierce:
				_burst(world)
				return
			spawn_hit(world, form, global_position)

func _burst(world: Node) -> void:
	done = true
	spawn_hit(world, form, global_position)
	queue_free()

## One-shot bullet impact effect.
static func spawn_hit(world: Node, form_name: String, at: Vector2) -> void:
	if world == null:
		return
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = Sprites.bullet_frames()
	fx.centered = false
	fx.offset = Sprites.offset(false, Sprites.BULLET_FRAME, Sprites.BULLET_PIVOT)
	fx.scale = Vector2.ONE * Sprites.SCALE
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.z_index = 4
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	fx.material = mat
	world.add_child(fx)
	fx.global_position = at
	fx.play(form_name + "_hit")
	fx.animation_finished.connect(fx.queue_free)
