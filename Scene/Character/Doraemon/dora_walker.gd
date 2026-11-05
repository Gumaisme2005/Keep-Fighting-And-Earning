extends Node2D
## Generic summon that moves on its own: Mini-Dora march, Korobashiya, Come-come Cat,
## friends flying in on Take-copters, Gian's recital, Nobita / Suneo helpers.

const Sprites = preload("res://Scene/Character/Doraemon/DoraemonSprites.gd")
const Util = preload("res://Scene/Character/Doraemon/dora_util.gd")
const Fx = preload("res://Scene/Character/Doraemon/dora_fx.gd")
const Projectile = preload("res://Scene/Character/Doraemon/dora_projectile.gd")

var caster: Node2D
var anim: String = "minidora"
var velocity: Vector2 = Vector2.ZERO
var fly: bool = false                 # ignores walls (Take-copter)
var seek: bool = false                # steers towards the nearest enemy
var seek_speed: float = 70.0
var life: float = 1.6
var damage: int = 1
var stun_time: float = 0.0
var radius: float = 10.0
var hit_interval: float = 0.0
var max_hits_per_target: int = 1
var max_targets: int = 99             # finishes (exit animation) after this many distinct hits
var max_total_hits: int = 0           # >0: finishes after this many hits in total (Korobashiya: 3 trips)
var exit_anim: String = ""
var relocate_to: Node2D = null        # Come-come Cat: throws enemies behind this node
var notes_every: float = 0.0          # Gian's recital: music notes shot in all directions
var note_damage: int = 1
var shoot_every: float = 0.0          # Nobita: fires at the nearest enemy
var shoot_damage: int = 1
var shots_left: int = 0
var final_shot_damage: int = 0
var sprite_scale: float = 0.9
var fade_in: float = 0.12

var age: float = 0.0
var finished: bool = false
var hits: Dictionary = {}
var targets_hit: int = 0
var total_hits: int = 0
var _note_t: float = 0.0
var _shot_t: float = 0.0
var _note_i: int = 0
var sprite: AnimatedSprite2D

func _ready() -> void:
	z_index = 2
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.build([anim])
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	sprite.use_parent_material = true
	add_child(sprite)
	sprite.play(anim)
	_face()
	modulate.a = 0.0 if fade_in > 0.0 else 1.0

func _face() -> void:
	var left := velocity.x < -0.01
	if velocity.x == 0.0 and is_instance_valid(caster):
		left = global_position.x > caster.global_position.x
	sprite.flip_h = left
	sprite.offset = Sprites.offset(anim, left)

func _physics_process(delta: float) -> void:
	if finished:
		return
	age += delta
	if fade_in > 0.0:
		modulate.a = clampf(age / fade_in, 0.0, 1.0)
	var world := get_parent()
	if seek:
		var t := Util.nearest(world, global_position, 260.0)
		if t != null:
			velocity = (Util.hit_point(t) + Vector2(0, 8) - global_position).normalized() * seek_speed
	var step := velocity * delta
	if step != Vector2.ZERO:
		if not fly and Util.is_wall(world, global_position + step + step.normalized() * 6.0):
			velocity = Vector2.ZERO
		else:
			global_position += step
		_face()
	if notes_every > 0.0:
		_note_t += delta
		while _note_t >= notes_every:
			_note_t -= notes_every
			_emit_note(world)
	if shoot_every > 0.0 and (shots_left > 0 or final_shot_damage > 0):
		_shot_t += delta
		if _shot_t >= shoot_every:
			_shot_t = 0.0
			_shoot(world)
	if damage > 0:
		_check_hits(world)
	if not finished and age >= life:
		_finish(world)

func _check_hits(world: Node) -> void:
	for t in Util.in_circle(world, global_position + Vector2(0, -10), radius):
		var id: int = t.get_instance_id()
		var rec: Array = hits.get(id, [0, -INF])
		if rec[0] >= max_hits_per_target or (hit_interval > 0.0 and age - float(rec[1]) < hit_interval):
			continue
		if rec[0] == 0:
			targets_hit += 1
		hits[id] = [int(rec[0]) + 1, age]
		total_hits += 1
		Util.hit(caster, t, damage, stun_time)
		if relocate_to != null and is_instance_valid(relocate_to) and is_instance_valid(t) and t.get("is_immovable") != true and t.get("is_dead") != true:
			_throw_behind(world, t)
		if (targets_hit >= max_targets and int(hits[id][0]) >= max_hits_per_target) or (max_total_hits > 0 and total_hits >= max_total_hits):
			_finish(world)
			return

## Come-come Cat: the lured enemy leaps over Doraemon and lands far behind him.
func _throw_behind(world: Node, t: Node2D) -> void:
	var dir := (relocate_to.global_position - t.global_position)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var dest := Util.safe_point(world, relocate_to.global_position, dir, 64.0, 20.0)
	if dest != relocate_to.global_position:
		Fx.spawn(world, "puff", t.global_position, 0.6)
		t.global_position = dest
		Fx.spawn(world, "puff", dest, 0.6)

func _emit_note(world: Node) -> void:
	_note_i += 1
	var p: Node2D = Projectile.new()
	p.caster = caster
	p.anim = "note_a" if _note_i % 2 == 0 else "note_b"
	# Golden-angle spread: notes fan out evenly in every direction.
	var ang := float(_note_i) * 2.39996
	p.velocity = Vector2.RIGHT.rotated(ang) * 120.0
	p.damage = note_damage
	p.stun_time = 0.25
	p.life = 1.3
	p.radius = 7.0
	p.rotate_sprite = false
	p.hit_anim = ""
	world.add_child(p)
	p.global_position = global_position + Vector2(0, -26)

func _shoot(world: Node) -> void:
	var t := Util.nearest(world, global_position, 240.0)
	var dir := Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	if t != null:
		dir = (Util.hit_point(t) - (global_position + Vector2(0, -16))).normalized()
		sprite.flip_h = dir.x < 0.0
		sprite.offset = Sprites.offset(anim, sprite.flip_h)
	var big := shots_left <= 0
	var p: Node2D = Projectile.new()
	p.caster = caster
	p.anim = "bullet"
	p.velocity = dir * (420.0 if big else 340.0)
	p.damage = final_shot_damage if big else shoot_damage
	p.sprite_scale = 1.8 if big else 0.9
	p.radius = 10.0 if big else 6.0
	p.life = 0.8
	world.add_child(p)
	p.global_position = global_position + Vector2(0, -16) + dir * 8.0
	if big:
		final_shot_damage = 0
	else:
		shots_left -= 1

func _finish(world: Node) -> void:
	if finished:
		return
	finished = true
	if exit_anim != "":
		Fx.spawn(world, exit_anim, global_position, sprite_scale, sprite.flip_h)
		queue_free()
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
