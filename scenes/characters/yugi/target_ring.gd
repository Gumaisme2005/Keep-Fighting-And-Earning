extends Node2D

const Sprites = preload("res://scenes/characters/yugi/YugiSprites.gd")
var damage := 2
var elapsed := 0.0
var dealt_damage := false

func _ready() -> void:
	name = "YugiTargetRing"
	z_index = -1
	var sprite := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", false)
	frames.set_animation_speed("default", 10.0)
	# Skip Yugi's casting poses. Center the magic frames at the enemy's feet.
	for source in Sprites.frames("shift+right+click", 440):
		var texture := source.duplicate() as AtlasTexture
		texture.margin = Rect2()
		frames.add_frame("default", texture)
	sprite.sprite_frames = frames
	sprite.material = Sprites.material()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(0.65, 0.35)
	add_child(sprite)
	sprite.play("default")

func _physics_process(delta: float) -> void:
	elapsed += delta
	var target := get_parent()
	if target.get("is_dead") == true:
		queue_free()
		return
	if not dealt_damage and elapsed >= 0.35:
		dealt_damage = true
		target.take_damage(damage)
	if elapsed >= 0.8: queue_free()
