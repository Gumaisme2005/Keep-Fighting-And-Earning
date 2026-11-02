extends "res://Scene/Projectiles/arrow.gd"

const Sprites = preload("res://Scene/Character/Yugi/YugiSprites.gd")

func _ready() -> void:
	speed = 220.0
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = Sprites.material()
	sprite.scale = Vector2(0.5, 0.5)
	var frames := SpriteFrames.new()
	frames.add_animation("fly")
	frames.set_animation_speed("fly", 12.0)
	for source in Sprites.frames("right-click", 930):
		# Projectiles use a centered origin, unlike the padded character frames.
		var texture := source.duplicate() as AtlasTexture
		texture.margin = Rect2()
		frames.add_frame("fly", texture)
	sprite.sprite_frames = frames
	add_child(sprite)
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	collision.shape = circle
	add_child(collision)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	super._ready()
