extends Node2D
## Generic Doraemon projectile. One script drives every shot from the 4D pocket:
##   straight  - Air Pistol, Shock Gun beam, pufferfish, music notes, reflected mantle wave
##   homing    - Ataru Gun, Pencil Missile, Dorami's balloon
##   bounce    - Shock-wave Pistol (ricochets off walls)
##   drift     - Bubble Pistol (slow wobbling bubbles that trap)
##   lob       - Grenades, junk, water drops (arc to a point, then land / explode)
##   drop      - Dorayakin (falls from the sky onto a point)
##   static    - lingering hazards (SL smoke, water drops)
## Hits are resolved by distance against enemy hurtboxes every physics frame, so the
## result is deterministic and replays stay in sync.

const Sprites = preload("res://scenes/characters/doraemon/DoraemonSprites.gd")
const Util = preload("res://scenes/characters/doraemon/dora_util.gd")
const Fx = preload("res://scenes/characters/doraemon/dora_fx.gd")

var caster: Node2D
var anim: String = "bullet"
var mode: String = "straight"
var velocity: Vector2 = Vector2.RIGHT * 200.0
var damage: int = 1
var radius: float = 6.0
var life: float = 1.5
var pierce: bool = false
var hit_interval: float = 0.0     # >0: may hit the same enemy again after this delay
var max_hits_per_target: int = 1
var stun_time: float = 0.0
var target: Node2D = null
var turn_rate: float = 5.0
var bounces: int = 0
var wobble: float = 0.0
var lob_to: Vector2 = Vector2.ZERO
var lob_time: float = 0.6
var lob_height: float = 36.0
var fuse: float = 0.0             # lob: seconds on the ground before exploding
var explode_radius: float = 0.0
var explode_damage: int = 0
var explode_anim: String = "explosion"
var explode_scale: float = 0.5
var end_anim: String = ""         # visual when it ends without exploding
var hit_anim: String = "spark"
var rotate_sprite: bool = true
var spin: float = 0.0
var sprite_scale: float = 0.9
var fade_tail: float = 0.25

var age: float = 0.0
var done: bool = false
var hits: Dictionary = {}
var sprite: AnimatedSprite2D
var _lob_from: Vector2
var _landed: bool = false
var _phase: float = 0.0

func _ready() -> void:
	z_index = 3
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.build([anim])
	sprite.centered = false
	sprite.offset = Sprites.offset(anim)
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.use_parent_material = true
	add_child(sprite)
	sprite.play(anim)
	_lob_from = global_position
	_phase = float(int(global_position.x * 7.0 + global_position.y * 3.0) % 100) * 0.0628
	_orient()

func _orient() -> void:
	if rotate_sprite and velocity != Vector2.ZERO and mode != "lob":
		sprite.rotation = velocity.angle()
		sprite.flip_v = false

func _physics_process(delta: float) -> void:
	if done:
		return
	age += delta
	var world := get_parent()
	match mode:
		"straight":
			_move(world, velocity * delta)
		"homing":
			if is_instance_valid(target) and target.get("is_dead") != true:
				var want := (Util.hit_point(target) - global_position).angle()
				var cur := velocity.angle()
				var diff := wrapf(want - cur, -PI, PI)
				velocity = velocity.rotated(clampf(diff, -turn_rate * delta, turn_rate * delta))
			else:
				target = Util.nearest(world, global_position, 160.0)
			_move(world, velocity * delta)
		"bounce":
			_move_bounce(world, velocity * delta)
		"drift":
			var side := velocity.orthogonal().normalized() * sin(age * 6.0 + _phase) * wobble
			_move(world, (velocity + side) * delta)
		"lob":
			_move_lob(world, delta)
		"drop":
			_move_drop(world)
		"static":
			pass
	if done:
		return
	if spin != 0.0:
		sprite.rotation += spin * delta
	if (mode != "lob" and mode != "drop") or _landed:
		_check_hits(world)
	if not done and age >= life:
		if explode_radius > 0.0:
			_explode(world)
		else:
			_finish(world, end_anim)
	elif fade_tail > 0.0 and life - age < fade_tail:
		sprite.modulate.a = clampf((life - age) / fade_tail, 0.0, 1.0)

func _move(world: Node, step: Vector2) -> void:
	if Util.is_wall(world, global_position + step):
		if explode_radius > 0.0:
			_explode(world)
		else:
			_finish(world, hit_anim)
		return
	global_position += step
	_orient()

func _move_bounce(world: Node, step: Vector2) -> void:
	var next := global_position + step
	if Util.is_wall(world, next):
		if bounces <= 0:
			_finish(world, hit_anim)
			return
		bounces -= 1
		if Util.is_wall(world, global_position + Vector2(step.x, 0)):
			velocity.x = -velocity.x
		if Util.is_wall(world, global_position + Vector2(0, step.y)):
			velocity.y = -velocity.y
		Fx.spawn(world, "puff", global_position, 0.35)
		return
	global_position = next

func _move_lob(world: Node, delta: float) -> void:
	if _landed:
		if age >= life - 0.0001:
			return
		return
	var t := clampf(age / lob_time, 0.0, 1.0)
	var flat := _lob_from.lerp(lob_to, t)
	global_position = flat
	sprite.position = Vector2(0, -sin(PI * t) * lob_height)
	if t >= 1.0:
		_landed = true
		sprite.position = Vector2.ZERO
		life = age + fuse
		if fuse <= 0.0:
			if explode_radius > 0.0:
				_explode(world)
			else:
				_check_hits(world)
				_finish(world, end_anim)

func _move_drop(world: Node) -> void:
	if _landed:
		return
	var t := clampf(age / lob_time, 0.0, 1.0)
	sprite.position = Vector2(0, -(1.0 - t * t) * lob_height)
	if t >= 1.0:
		_landed = true
		sprite.position = Vector2.ZERO
		if explode_radius > 0.0:
			_explode(world)
		else:
			_finish(world, end_anim)

func _check_hits(world: Node) -> void:
	for t in Util.in_circle(world, global_position, radius):
		var id: int = t.get_instance_id()
		var rec: Array = hits.get(id, [0, -INF])
		if rec[0] >= max_hits_per_target:
			continue
		if hit_interval > 0.0 and age - float(rec[1]) < hit_interval:
			continue
		if not Util.sees(world, global_position - velocity.normalized() * 6.0, Util.hit_point(t)):
			continue
		hits[id] = [int(rec[0]) + 1, age]
		if explode_radius > 0.0 and not pierce:
			_explode(world)
			return
		Util.hit(caster, t, damage, stun_time)
		if not pierce:
			_finish(world, hit_anim)
			return

func _explode(world: Node) -> void:
	if done:
		return
	done = true
	Fx.spawn(world, explode_anim, global_position, explode_scale)
	for t in Util.in_circle(world, global_position, explode_radius):
		Util.hit(caster, t, explode_damage if explode_damage > 0 else damage, stun_time)
	queue_free()

func _finish(world: Node, fx_anim: String) -> void:
	if done:
		return
	done = true
	if fx_anim != "":
		Fx.spawn(world, fx_anim, global_position, 0.5)
	queue_free()
