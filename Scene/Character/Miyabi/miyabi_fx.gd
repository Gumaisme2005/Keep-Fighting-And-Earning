extends Node2D
## One-shot frost effect (frost_hit burst, frost_wave_end, bolt_hit...). Lives for the
## animation's length, counted in physics time so it never depends on the frame rate.

const Sprites = preload("res://Scene/Character/Miyabi/MiyabiSprites.gd")

var anim: String = "frost_hit"
var flipped: bool = false
var k: float = 1.0
var life: float = 0.5
var age: float = 0.0
var sprite: AnimatedSprite2D

static func spawn(world: Node, anim_name: String, at: Vector2, scale_k: float = 0.85, flip: bool = false, angle: float = 0.0) -> Node2D:
	if world == null or not Sprites.ANIMS.has(anim_name):
		return null
	var fx: Node2D = load("res://Scene/Character/Miyabi/miyabi_fx.gd").new()
	fx.anim = anim_name
	fx.k = scale_k
	fx.flipped = flip
	fx.rotation = angle
	world.add_child(fx)
	fx.global_position = at
	return fx

func _ready() -> void:
	z_index = 4
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.build([anim])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.flip_h = flipped
	sprite.scale = Vector2(k, k)
	sprite.use_parent_material = true
	add_child(sprite)
	sprite.play(anim)
	life = Sprites.duration(anim)

func _physics_process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
