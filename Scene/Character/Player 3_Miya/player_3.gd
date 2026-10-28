extends "res://Scene/Character/Player 1_Pyrois/player.gd"

@export var arrow_scene: PackedScene
@export var bomb_scene: PackedScene

func _ready() -> void:
	speed = 180.0
	base_max_hp = 4
	base_armor = 1
	base_damage = 2
	super._ready()

func attack() -> void:
	is_attacking = true
	animated_sprite.play("attack_1")
	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_sfx("slash")

	if arrow_scene != null:
		var arrow = arrow_scene.instantiate()
		get_parent().add_child(arrow)

		var aim_pos = get_aim_world_position()
		var shoot_direction = global_position.direction_to(aim_pos).normalized()
		if shoot_direction == Vector2.ZERO:
			shoot_direction = Vector2.RIGHT

		if "shooter_origin" in arrow:
			arrow.shooter_origin = global_position
		arrow.global_position = global_position + (shoot_direction * 6.0)
		arrow.direction = shoot_direction
		arrow.rotation = shoot_direction.angle()
		arrow.damage = get_total_damage()

func use_special_skill() -> void:
	if not can_use_skill:
		return

	start_skill_cooldown()
	is_casting_skill = true
	animated_sprite.play("skill")

	if bomb_scene != null:
		var bomb = bomb_scene.instantiate()
		get_parent().add_child(bomb)
		bomb.damage = get_total_damage() * 3
		var aim_pos = get_aim_world_position()
		bomb.throw_bomb(global_position, aim_pos)

	await get_tree().create_timer(0.5).timeout

	if not is_dead and not is_hurt:
		is_casting_skill = false
		if animated_sprite.animation == "skill":
			animated_sprite.play("idle")
