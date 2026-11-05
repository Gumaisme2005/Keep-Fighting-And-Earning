extends Node2D

const Sprites = preload("res://Scene/Character/Yugi/YugiSprites.gd")
const STUN_SECONDS := 2.0
var remaining := STUN_SECONDS
var restore_physics := false
var target: Node2D

static func apply(enemy: Node2D) -> void:
	var existing := enemy.get_node_or_null("YugiLightningStun")
	if existing != null:
		existing.remaining = STUN_SECONDS
		return
	var effect := load("res://Scene/Character/Yugi/lightning_hit.gd").new() as Node2D
	effect.name = "YugiLightningStun"
	enemy.add_child(effect)

func _ready() -> void:
	target = get_parent() as Node2D
	restore_physics = target.is_physics_processing()
	# Rooted targets (Skeleton King crystals) still show the strike but are never frozen.
	if target.get("is_immovable") != true:
		target.set_physics_process(false)
	if target is CharacterBody2D: target.velocity = Vector2.ZERO
	var sprite := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 12.0)
	frames.set_animation_loop("default", false)
	var texture := preload("res://Assets/Character/Yugi/result-3-attack.png")
	# Each multi-bolt cluster is ONE frame, including the narrow initial bolts.
	for bounds in [[40, 53], [68, 82], [88, 102], [116, 187], [199, 270], [282, 349], [365, 425], [439, 491], [501, 550]]:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(bounds[0], 0, bounds[1] - bounds[0], texture.get_height())
		atlas.margin = Rect2((80 - atlas.region.size.x) / 2.0, 0, 80 - atlas.region.size.x, 0)
		atlas.filter_clip = true
		frames.add_frame("default", atlas)
	sprite.sprite_frames = frames
	sprite.material = Sprites.material()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position.y = -31.5
	sprite.scale = Vector2(0.65, 0.5)
	add_child(sprite)
	sprite.play("default")
	sprite.animation_finished.connect(sprite.hide)
	z_index = 5

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	if target.get("is_dead") == true:
		# Let the strike remain visible on a lethal hit without reviving enemy AI.
		remaining = minf(remaining, 0.75)
	remaining -= delta
	if target is CharacterBody2D: target.velocity = Vector2.ZERO
	if remaining <= 0:
		if target.get("is_dead") != true:
			target.set_physics_process(restore_physics)
		queue_free()

func _exit_tree() -> void:
	if is_instance_valid(target) and not target.is_queued_for_deletion() and target.get("is_dead") != true:
		target.set_physics_process(restore_physics)
