extends Area2D
## Momotaro Kibi-dango: a tamed Tyrannosaurus charges along a line and tramples
## every enemy it touches once, then wanders off. Stops at walls / closed gates.

const Sprites = preload("res://scenes/characters/doraemon/DoraemonSprites.gd")
const RUN_TIME := 1.5
const FADE_TIME := 0.3
const SCALE := 0.75

var direction: Vector2 = Vector2.RIGHT
var speed: float = 190.0
var damage: int = 3
var caster: Node2D
var age: float = 0.0
var stopped: bool = false
var hit_ids: Dictionary = {}
var sprite: AnimatedSprite2D
var dango: Sprite2D

func _ready() -> void:
	z_index = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44, 26)
	shape.shape = rect
	shape.position = Vector2(0, -12)
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.build(["trex"])
	sprite.centered = false
	sprite.flip_h = direction.x < 0.0
	var info: Dictionary = Sprites.ANIMS["trex"]
	var cell: Vector2 = info["cell"]
	var anchor: Vector2 = info["anchor"]
	sprite.offset = Vector2(-(cell.x - anchor.x) if sprite.flip_h else -anchor.x, -anchor.y)
	sprite.scale = Vector2(SCALE, SCALE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate.a = 0.0
	add_child(sprite)
	sprite.play("trex")
	# The thrown dango flies ahead of the dinosaur it lures.
	dango = Sprite2D.new()
	dango.texture = Sprites.texture("doraemon_dango.png")
	dango.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dango.position = Vector2(0, -14)
	add_child(dango)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	age += delta
	sprite.modulate.a = clampf(age / 0.12, 0.0, 1.0)
	if age >= RUN_TIME:
		stopped = true
		sprite.modulate.a = clampf(1.0 - (age - RUN_TIME) / FADE_TIME, 0.0, 1.0)
		if age >= RUN_TIME + FADE_TIME:
			queue_free()
		return
	dango.position = Vector2(0, -14) + direction * minf(age * 260.0, 46.0) + Vector2(0, -sin(minf(age * 6.0, PI)) * 10.0)
	if stopped:
		return
	var step := direction * speed * delta
	var tmap = get_parent()
	if tmap != null and tmap.has_method("is_global_pos_wall_or_door"):
		if tmap.is_global_pos_wall_or_door(global_position + step + direction * 18.0):
			stopped = true
			age = maxf(age, RUN_TIME - 0.2)
			return
	global_position += step
	for area in get_overlapping_areas():
		_on_area_entered(area)

func _on_area_entered(area: Area2D) -> void:
	if area.name != "Hurtbox" or age >= RUN_TIME:
		return
	var target = area.get_parent()
	if not target.has_method("take_damage") and target.get_parent() != null:
		target = target.get_parent()
	if not target.has_method("take_damage") or target.is_in_group("player") or target == caster:
		return
	var id: int = target.get_instance_id()
	if hit_ids.has(id) or target.get("is_dead") == true:
		return
	hit_ids[id] = true
	target.take_damage(damage)
	if is_instance_valid(caster) and caster.has_method("add_power"):
		caster.add_power(3)
