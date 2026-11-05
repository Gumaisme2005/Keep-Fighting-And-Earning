extends Node2D
## One-shot visual effect (explosion, smoke, spark, friend exit door...). Frees itself when
## the animation ends (or after `life` seconds for looping animations). Optional timed
## area hits (`strikes`) let a visual also deal damage, e.g. the Mini Thundercloud.

const Sprites = preload("res://scenes/characters/doraemon/DoraemonSprites.gd")
const Util = preload("res://scenes/characters/doraemon/dora_util.gd")

var anim: String = "puff"
var life: float = -1.0
var fx_scale: float = 0.9
var flip: bool = false
var unshaded: bool = true
var caster: Node2D
var strikes: Array = []   # [{ "t": sec, "r": radius, "dmg": int, "stun": sec }]
var fade_out: float = 0.0
var age: float = 0.0
var sprite: AnimatedSprite2D

static func spawn(world: Node, anim_name: String, global_pos: Vector2, scale_k: float = 0.9, flipped: bool = false, life_s: float = -1.0) -> Node2D:
	if world == null:
		return null
	var fx: Node2D = load("res://scenes/characters/doraemon/dora_fx.gd").new()
	fx.anim = anim_name
	fx.fx_scale = scale_k
	fx.flip = flipped
	fx.life = life_s
	world.add_child(fx)
	fx.global_position = global_pos
	return fx

func _ready() -> void:
	z_index = 3
	if unshaded:
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = mat
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.build([anim])
	sprite.centered = false
	sprite.flip_h = flip
	sprite.offset = Sprites.offset(anim, flip)
	sprite.scale = Vector2(fx_scale, fx_scale)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.use_parent_material = true
	add_child(sprite)
	sprite.play(anim)
	if life < 0.0:
		life = maxf(Sprites.duration(anim), 0.35) if not bool(Sprites.ANIMS[anim]["loop"]) else 0.6

func _physics_process(delta: float) -> void:
	age += delta
	for s in strikes:
		if not s.get("done", false) and age >= float(s["t"]):
			s["done"] = true
			for t in Util.in_circle(get_parent(), global_position + Vector2(s.get("dx", 0.0), s.get("dy", -6.0)), float(s["r"])):
				Util.hit(caster, t, int(s["dmg"]), float(s.get("stun", 0.0)))
	if fade_out > 0.0 and life - age < fade_out:
		modulate.a = clampf((life - age) / fade_out, 0.0, 1.0)
	if age >= life:
		queue_free()
