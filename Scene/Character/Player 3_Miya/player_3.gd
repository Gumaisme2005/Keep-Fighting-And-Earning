extends "res://Scene/Character/Player 1_Pyrois/player.gd"

@export var arrow_scene: PackedScene
@export var bomb_scene: PackedScene

var attack_cooldown_time: float = 0.46
var arrow_fly_speed: float = 280.0
var bomb_damage_mult: int = 2
var bomb_bonus_damage: int = 1
var _can_shoot_arrow: bool = true

func _ready() -> void:
	hero_balance_id = "miya"
	var cfg: Dictionary = BalanceData.get_hero_stats("miya")
	attack_cooldown_time = float(cfg.get("attack_cooldown", 0.46))
	arrow_fly_speed = float(cfg.get("arrow_speed", 280.0))
	bomb_damage_mult = int(cfg.get("bomb_damage_mult", 2))
	bomb_bonus_damage = int(cfg.get("bomb_bonus_damage", 1))
	super._ready()

func attack() -> void:
	if not _can_shoot_arrow:
		return
	_can_shoot_arrow = false
	is_attacking = true
	_attack_timer = attack_cooldown_time
	animated_sprite.play("attack_1")
	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_sfx("slash", 1.15, 1.28)

	if arrow_scene != null and get_parent() != null:
		var arrow = arrow_scene.instantiate()

		var aim_pos = get_aim_world_position()
		var shoot_direction = global_position.direction_to(aim_pos).normalized()
		if shoot_direction == Vector2.ZERO:
			shoot_direction = Vector2.LEFT if animated_sprite.flip_h else Vector2.RIGHT

		var spawn_pos: Vector2 = global_position + (shoot_direction * 6.0)
		var tmap = get_parent()
		if tmap != null and tmap.has_method("is_global_pos_wall_or_door"):
			if tmap.is_global_pos_wall_or_door(spawn_pos):
				spawn_pos = global_position

		if "shooter_origin" in arrow:
			arrow.shooter_origin = global_position
		if "speed" in arrow:
			arrow.speed = arrow_fly_speed
		if tmap is Node2D:
			arrow.position = (tmap as Node2D).to_local(spawn_pos)
		arrow.direction = shoot_direction
		arrow.rotation = shoot_direction.angle()
		arrow.damage = get_total_damage()

		get_parent().add_child(arrow)
		arrow.global_position = spawn_pos

	get_tree().create_timer(attack_cooldown_time).timeout.connect(func():
		if is_instance_valid(self):
			_can_shoot_arrow = true
			if is_attacking:
				is_attacking = false
				if not is_dead and not is_hurt and not is_casting_skill:
					animated_sprite.play("idle")
	)

func use_special_skill() -> void:
	if not can_use_skill:
		return

	start_skill_cooldown()
	is_casting_skill = true
	animated_sprite.play("skill")

	if bomb_scene != null:
		var bomb = bomb_scene.instantiate()
		get_parent().add_child(bomb)
		bomb.damage = get_total_damage() * bomb_damage_mult + bomb_bonus_damage
		var aim_pos = get_aim_world_position()
		bomb.throw_bomb(global_position, aim_pos)

	await get_tree().create_timer(0.45).timeout

	is_casting_skill = false
	if not is_dead and not is_hurt and animated_sprite.animation == "skill":
		animated_sprite.play("idle")
