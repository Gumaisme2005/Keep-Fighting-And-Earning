extends Area2D

@export var speed: float = 190.0
@export var damage: int = 1
var direction: Vector2 = Vector2.ZERO
var is_broken: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	z_index = 3
	if anim != null and anim.sprite_frames != null and anim.sprite_frames.has_animation("fly"):
		anim.play("fly")
	await get_tree().create_timer(3.2).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta: float) -> void:
	if is_broken:
		return
	var next_pos: Vector2 = global_position + direction * speed * delta
	var tmap = get_parent()
	if tmap != null and tmap.has_method("has_line_of_sight"):
		if tmap.is_global_pos_wall_or_door(next_pos) or not tmap.has_line_of_sight(global_position, next_pos):
			_explode()
			return
	global_position = next_pos

func _on_area_entered(area: Area2D) -> void:
	if is_broken:
		return
	if area.name == "PlayerHurtbox":
		var target = area.get_parent()
		var tmap = get_parent()
		if tmap != null and tmap.has_method("has_line_of_sight"):
			var check_from: Vector2 = global_position - direction * 8.0
			if tmap.is_global_pos_wall_or_door(global_position) or not tmap.has_line_of_sight(check_from, target.global_position):
				_explode()
				return
		if target.has_method("take_damage"):
			target.take_damage(damage)
		_explode()

func _on_body_entered(body: Node2D) -> void:
	if body is TileMap:
		_explode()

func _explode() -> void:
	if is_broken:
		return
	is_broken = true
	set_physics_process(false)
	if anim != null and anim.sprite_frames != null and anim.sprite_frames.has_animation("hit"):
		anim.play("hit")
		await anim.animation_finished
	queue_free()

