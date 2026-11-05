extends Node2D
## Miyabi's ice spirit. Floats at her shoulder ((+10, -4) from her frame centre, mirrored when
## she faces left), keeps playing spirit_idle through her frost moves and, every couple of
## seconds, fires a spirit bolt at the nearest enemy it can see. It flinches when she is hurt
## and fades away when she falls. All timing runs in physics time (replay-safe).

const Sprites = preload("res://Scene/Character/Miyabi/MiyabiSprites.gd")
const Util = preload("res://Scene/Character/Miyabi/miyabi_util.gd")
const Bolt = preload("res://Scene/Character/Miyabi/spirit_bolt.gd")

const RELEASE_FRAME := 3

var hero: Node2D
var cooldown: float = 2.0
var attack_range: float = 150.0
var damage: int = 1
var enabled: bool = true
var state: String = "idle"     # idle / attack / hurt / vanish
var shots_fired: int = 0
var _cd: float = 1.0
var _t: float = 0.0
var _target: Node2D = null
var _fired: bool = false
var sprite: AnimatedSprite2D

func _ready() -> void:
	name = "Spirit"
	z_index = 1
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.build(Sprites.SPIRIT_ANIMS)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * Sprites.SCALE
	sprite.use_parent_material = true
	add_child(sprite)
	sprite.play("spirit_idle")
	if hero != null:
		position = _rest_position()

func _rest_position() -> Vector2:
	var f: float = hero.facing
	return hero.centre_local() + Vector2(Sprites.SPIRIT_OFFSET.x * f, Sprites.SPIRIT_OFFSET.y) * Sprites.SCALE

func _physics_process(delta: float) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	position = position.lerp(_rest_position(), clampf(delta * 12.0, 0.0, 1.0))
	_t += delta
	match state:
		"vanish":
			if _t >= Sprites.duration("spirit_vanish"):
				visible = false
				set_physics_process(false)
		"hurt":
			if _t >= Sprites.duration("spirit_hurt"):
				_idle()
		"attack":
			if not _fired and _t >= Sprites.at_frame("spirit_attack", RELEASE_FRAME):
				_fired = true
				_shoot()
			if _t >= Sprites.duration("spirit_attack"):
				_idle()
		_:
			sprite.flip_h = hero.facing < 0.0
			if not enabled or hero.get("is_dead") == true:
				return
			_cd -= delta
			if _cd > 0.0:
				return
			var t := Util.nearest(hero.get_parent(), global_position, attack_range)
			if t == null:
				_cd = 0.2
				return
			_target = t
			_cd = cooldown
			state = "attack"
			_t = 0.0
			_fired = false
			sprite.flip_h = Util.hit_point(t).x < global_position.x
			sprite.play("spirit_attack")

func _shoot() -> void:
	var world := hero.get_parent()
	var f := -1.0 if sprite.flip_h else 1.0
	var from := global_position + Vector2((Sprites.BOLT_OFFSET.x - Sprites.SPIRIT_OFFSET.x) * f, Sprites.BOLT_OFFSET.y - Sprites.SPIRIT_OFFSET.y) * Sprites.SCALE
	var dir := Vector2(f, 0.0)
	if is_instance_valid(_target) and _target.get("is_dead") != true:
		dir = (Util.hit_point(_target) - from).normalized()
	var b: Node2D = Bolt.new()
	b.dir = dir
	b.damage = damage
	world.add_child(b)
	b.global_position = from
	shots_fired += 1

func _idle() -> void:
	state = "idle"
	_t = 0.0
	sprite.play("spirit_idle")

func on_hero_hurt() -> void:
	if state == "idle":
		state = "hurt"
		_t = 0.0
		sprite.play("spirit_hurt")

func on_hero_died() -> void:
	state = "vanish"
	_t = 0.0
	sprite.play("spirit_vanish")
