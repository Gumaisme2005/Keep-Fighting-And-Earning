extends Area2D
## Air Cannon (空気砲) blast: flies straight, bursts on the first enemy or wall.

const Sprites = preload("res://Scene/Character/Doraemon/DoraemonSprites.gd")

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var max_distance: float = 190.0
var damage: int = 1
var caster: Node2D
var shooter_origin: Vector2 = Vector2.ZERO
var travelled: float = 0.0
var spent: bool = false
var sprite: Sprite2D

func _ready() -> void:
	z_index = 3
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = Sprites.texture("doraemon_air_shot.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The sprite flies to the right with its trail on the left; rotate to the travel direction.
	sprite.rotation = direction.angle()
	add_child(sprite)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if spent:
		return
	var step := direction * speed * delta
	var tmap = get_parent()
	if tmap != null:
		if tmap.has_method("is_global_pos_wall_or_door") and tmap.is_global_pos_wall_or_door(global_position + step):
			_burst()
			return
		if tmap.has_method("has_line_of_sight") and not tmap.has_line_of_sight(global_position, global_position + step):
			_burst()
			return
	global_position += step
	travelled += step.length()
	# Air disperses near the end of its range.
	sprite.modulate.a = clampf(1.6 - travelled / max_distance, 0.0, 1.0)
	if travelled >= max_distance:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if spent:
		return
	if body is TileMap or body is StaticBody2D:
		_burst()

func _on_area_entered(area: Area2D) -> void:
	if spent or area.name != "Hurtbox":
		return
	var target = area.get_parent()
	if not target.has_method("take_damage") and target.get_parent() != null:
		target = target.get_parent()
	if not target.has_method("take_damage") or target.is_in_group("player"):
		return
	if target.get("is_dead") == true:
		return
	var tmap = get_parent()
	if tmap != null and tmap.has_method("has_line_of_sight"):
		var origin := shooter_origin if shooter_origin != Vector2.ZERO else global_position - direction * 8.0
		if not tmap.has_line_of_sight(origin, target.global_position):
			return
	target.take_damage(damage)
	if is_instance_valid(caster) and caster.has_method("add_power"):
		caster.add_power(3)
	_burst()

func _burst() -> void:
	spent = true
	var puff := AnimatedSprite2D.new()
	puff.sprite_frames = Sprites.build(["puff"])
	puff.centered = false
	var info: Dictionary = Sprites.ANIMS["puff"]
	puff.offset = -Vector2(info["anchor"])
	puff.scale = Vector2(0.7, 0.7)
	puff.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	puff.z_index = 3
	puff.animation_finished.connect(puff.queue_free)
	var tmap = get_parent()
	if tmap != null:
		tmap.add_child(puff)
		puff.global_position = global_position + Vector2(0, 8)
		puff.play("puff")
	queue_free()
