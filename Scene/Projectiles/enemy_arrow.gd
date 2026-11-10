extends Area2D

const FloorBalance = preload("res://Scene/Balance/EnemyFloorBalance.gd")
var armor_piercing: float = 0.0

var speed: float = 200.0
var damage: int = 1
var direction: Vector2 = Vector2.ZERO
var is_broken: bool = false

func _ready() -> void:
	z_index = 3
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("fly")
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta: float) -> void:
	if is_broken:
		return
	var next_pos: Vector2 = global_position + direction * speed * delta
	var tmap = get_parent()
	if tmap != null and tmap.has_method("has_line_of_sight"):
		var wall_hit: bool = tmap.is_global_pos_wall_or_door(next_pos) if tmap.has_method("is_global_pos_wall_or_door") else false
		if wall_hit or not tmap.has_line_of_sight(global_position, next_pos):
			is_broken = true
			queue_free()
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
			var wall_hit: bool = tmap.is_global_pos_wall_or_door(global_position) if tmap.has_method("is_global_pos_wall_or_door") else false
			if wall_hit or not tmap.has_line_of_sight(check_from, target.global_position):
				is_broken = true
				queue_free()
				return
		if target.has_method("take_damage"):
			is_broken = true
			FloorBalance.hit(target, damage, armor_piercing)
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is TileMap:
		is_broken = true
		queue_free()
