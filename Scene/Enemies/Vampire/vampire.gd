extends CharacterBody2D

const BalanceData = preload("res://Scene/BalanceConfig.gd")
@export var damage: int = 1
@export var speed: float = 75.0
@export var attack_range: float = 165.0
@export var retreat_range: float = 65.0
@export var attack_cooldown: float = 1.75
@export var magic_spell_scene: PackedScene = preload("res://Scene/Projectiles/magic_spell.tscn")
@export var world_item_scene: PackedScene = preload("res://Scene/Items/WorldItem/WorldItem.tscn")
@export var loot_table: Array[ItemData] = [
	preload("res://Scene/Items/Common/health_potion.tres"),
	preload("res://Scene/Items/Rare/big_health_potion.tres"),
	preload("res://Scene/Items/Rare/iron_armor.tres")
]
@export var drop_chance: float = 0.35
var loot_seed: int = 0

var hp: int = 4
var is_dead: bool = false
var is_attacking: bool = false
var is_active: bool = false
var can_attack: bool = true
var strafe_timer: float = 0.0
var strafe_sign: float = 1.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var bite_hitbox = $BiteHitbox
@onready var bite_collision = $BiteHitbox/CollisionShape2D
var player: Node2D = null

# --- ĐIỀU HƯỚNG AI & TIẾT KIỆM TÍNH TOÁN RAYCAST ---
var _ai_tick_timer: float = 0.0
var _ai_tick_interval: float = 0.1 # Cập nhật tìm đường và tầm nhìn 10 lần/s thay vì 60 lần/s
var _cached_has_los: bool = true
var _cached_steer_dir: Vector2 = Vector2.ZERO
var _cached_retreat_dir: Vector2 = Vector2.ZERO
var _cached_strafe_dir: Vector2 = Vector2.ZERO

func _ready() -> void:
	var cfg: Dictionary = BalanceData.get_enemy_stats("vampire")
	hp = int(cfg.get("hp", hp))
	damage = int(cfg.get("damage", damage))
	speed = float(cfg.get("speed", speed))
	attack_range = float(cfg.get("attack_range", attack_range))
	retreat_range = float(cfg.get("retreat_range", retreat_range))
	attack_cooldown = float(cfg.get("attack_cooldown", attack_cooldown))
	drop_chance = float(cfg.get("drop_chance", drop_chance))
	animated_sprite.play("idle")
	bite_collision.disabled = true
	bite_hitbox.position = Vector2(0, -8)
	bite_hitbox.scale = Vector2.ONE
	_ai_tick_timer = randf_range(0.0, _ai_tick_interval)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(delta: float) -> void:
	if not is_active:
		return
	if player == null or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
		else:
			return
	if is_dead or animated_sprite.animation == "hurt":
		return

	strafe_timer += delta
	if strafe_timer >= 1.2:
		strafe_timer = 0.0
		strafe_sign = -strafe_sign

	var distance: float = global_position.distance_to(player.global_position)
	var direction: Vector2 = global_position.direction_to(player.global_position)

	if direction.x < 0:
		animated_sprite.flip_h = true
	elif direction.x > 0:
		animated_sprite.flip_h = false

	if is_attacking:
		return

	var tmap = get_parent()
	_ai_tick_timer -= delta
	if _ai_tick_timer <= 0.0:
		_ai_tick_timer = _ai_tick_interval
		_cached_has_los = (tmap == null or not tmap.has_method("has_line_of_sight") or tmap.has_line_of_sight(global_position, player.global_position))
		if not _cached_has_los or distance > attack_range:
			_cached_steer_dir = tmap.get_smart_steer_direction(global_position, direction) if (tmap != null and tmap.has_method("get_smart_steer_direction")) else direction
		elif distance < retreat_range:
			_cached_retreat_dir = tmap.get_smart_steer_direction(global_position, -direction) if (tmap != null and tmap.has_method("get_smart_steer_direction")) else -direction
		else:
			var lateral: Vector2 = direction.orthogonal() * strafe_sign
			_cached_strafe_dir = tmap.get_smart_steer_direction(global_position, lateral) if (tmap != null and tmap.has_method("get_smart_steer_direction")) else lateral

	# Nếu bị tường đá che khuất -> Lượn vòng qua vật cản tìm góc bắn
	if not _cached_has_los:
		var move_dir: Vector2 = _cached_steer_dir if _cached_steer_dir != Vector2.ZERO else direction
		velocity = move_dir * speed
		animated_sprite.play("walk")
		move_and_slide()
		return

	if distance > attack_range:
		# Bay áp sát về phía tầm bắn
		var move_dir: Vector2 = _cached_steer_dir if _cached_steer_dir != Vector2.ZERO else direction
		velocity = move_dir * speed
		animated_sprite.play("walk")
		move_and_slide()
	elif distance < retreat_range:
		# Người chơi áp sát quá gần -> Dơi vỗ cánh lùi lại giữ cự ly bắn chưởng
		var retreat_dir: Vector2 = _cached_retreat_dir if _cached_retreat_dir != Vector2.ZERO else -direction
		velocity = retreat_dir * (speed * 0.9)
		animated_sprite.play("walk")
		move_and_slide()
	else:
		# Trong tầm bắn lý tưởng
		if can_attack:
			velocity = Vector2.ZERO
			attack()
		else:
			# Bay lượn đảo cánh (Strafe) né đòn trong thời gian hồi phép
			var strafe_dir: Vector2 = _cached_strafe_dir if _cached_strafe_dir != Vector2.ZERO else (direction.orthogonal() * strafe_sign)
			velocity = strafe_dir * (speed * 0.75)
			animated_sprite.play("walk")
			move_and_slide()
			if get_slide_collision_count() > 0:
				strafe_sign = -strafe_sign

func attack() -> void:
	is_attacking = true
	can_attack = false
	if player != null and is_instance_valid(player):
		var dir = global_position.direction_to(player.global_position)
		if dir != Vector2.ZERO:
			bite_hitbox.rotation = dir.angle()
	animated_sprite.play("attack")
	bite_collision.disabled = false

	# Nhịp vỗ cánh phát động ma pháp (bắn chưởng pháp sư)
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree() or is_dead:
		return

	if animated_sprite.animation != "hurt" and is_instance_valid(player):
		var tmap = get_parent()
		if tmap == null or not tmap.has_method("has_line_of_sight") or tmap.has_line_of_sight(global_position, player.global_position):
			shoot_magic_spell()

	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree() or is_dead:
		return

	if is_attacking:
		is_attacking = false
		bite_collision.disabled = true
		animated_sprite.play("idle")

	await get_tree().create_timer(maxf(0.1, attack_cooldown - 0.70)).timeout
	if not is_inside_tree() or is_dead:
		return
	can_attack = true

func shoot_magic_spell() -> void:
	if magic_spell_scene == null or get_parent() == null or not is_instance_valid(player):
		return
	var spell = magic_spell_scene.instantiate()
	var shoot_dir: Vector2 = global_position.direction_to(player.global_position).normalized()
	if shoot_dir == Vector2.ZERO:
		shoot_dir = Vector2.RIGHT
	var spawn_pos: Vector2 = global_position + (shoot_dir * 8.0)
	if get_parent() is Node2D:
		spell.position = (get_parent() as Node2D).to_local(spawn_pos)
	spell.direction = shoot_dir
	spell.rotation = shoot_dir.angle()
	spell.damage = damage
	get_parent().add_child(spell)
	spell.global_position = spawn_pos

func take_damage(damage_amount: int) -> void:
	if not is_active or is_dead:
		return

	hp -= damage_amount
	if get_tree():
		get_tree().call_group("game_ui", "spawn_damage_number", global_position + Vector2(0, -20), damage_amount, Color(1.0, 0.9, 0.3))
	if hp > 0:
		animated_sprite.play("hurt")
		is_attacking = false
		bite_collision.set_deferred("disabled", true)
	else:
		is_dead = true
		if get_node_or_null("/root/GameManager") != null:
			GameManager.register_enemy_kill()
		animated_sprite.play("death")
		$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
		$CollisionShape2D.set_deferred("disabled", true)
		bite_collision.set_deferred("disabled", true)

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "death":
		drop_loot()
		queue_free()
	elif animated_sprite.animation == "hurt":
		if not is_dead:
			animated_sprite.play("idle")
	elif animated_sprite.animation == "attack":
		is_attacking = false
		bite_collision.disabled = true
		animated_sprite.play("idle")

func _on_bite_hitbox_area_entered(area: Area2D) -> void:
	if area.name == "PlayerHurtbox":
		var target = area.get_parent()
		var tmap = get_parent()
		if tmap != null and tmap.has_method("has_line_of_sight") and not tmap.has_line_of_sight(global_position, target.global_position):
			return
		if target.has_method("take_damage"):
			target.take_damage(damage)

func drop_loot() -> void:
	var item_scene = world_item_scene if world_item_scene != null else preload("res://Scene/Items/WorldItem/WorldItem.tscn")
	var rng := RandomNumberGenerator.new()
	rng.seed = loot_seed if loot_seed != 0 else (int(global_position.x * 911) ^ int(global_position.y * 3571))
	if rng.randf() <= drop_chance:
		var floor_lvl := 1
		if get_node_or_null("/root/GameManager") != null:
			floor_lvl = GameManager.current_level
		var random_item: ItemData = ItemDatabase.get_random_drop(floor_lvl, false, rng)
		if random_item == null and loot_table.size() > 0:
			random_item = loot_table[rng.randi() % loot_table.size()]

		if random_item != null:
			var item_drop = item_scene.instantiate()
			item_drop.item_data = random_item
			item_drop.global_position = global_position
			var parent_node = get_parent() if get_parent() != null else get_tree().current_scene
			parent_node.call_deferred("add_child", item_drop)
