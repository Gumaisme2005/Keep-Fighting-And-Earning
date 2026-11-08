extends CharacterBody2D

const BalanceData = preload("res://Scene/BalanceConfig.gd")
@export var damage: int = 1
@export var speed: float = 70.0
@export var attack_range: float = 20.0 # Chạy lại gần khoảng 20 pixel mới vung rìu
@export var world_item_scene: PackedScene
@export var loot_table: Array[ItemData] = []
@export var drop_chance: float = 0.3
var loot_seed: int = 0

var hp: int = 3
var max_hp: int = 3
var is_dead: bool = false
var is_attacking: bool = false
var is_active = false

@onready var animated_sprite = $AnimatedSprite2D
@onready var axe_hitbox = $AxeHitbox
@onready var axe_collision = $AxeHitbox/CollisionShape2D
var player: Node2D = null

# --- ĐIỀU HƯỚNG AI & TIẾT KIỆM TÍNH TOÁN RAYCAST ---
var _ai_tick_timer: float = 0.0
var _ai_tick_interval: float = 0.1 # Cập nhật tìm đường 10 lần/s thay vì 60 lần/s
var _cached_steer_dir: Vector2 = Vector2.ZERO
var _cached_has_los: bool = true

func _ready() -> void:
	var cfg: Dictionary = BalanceData.get_enemy_stats("orc")
	hp = int(cfg.get("hp", hp))
	max_hp = hp
	damage = int(cfg.get("damage", damage))
	speed = float(cfg.get("speed", speed))
	attack_range = float(cfg.get("attack_range", attack_range))
	drop_chance = float(cfg.get("drop_chance", drop_chance))
	animated_sprite.play("idle")
	axe_collision.disabled = true
	axe_hitbox.position = Vector2(0, -7)
	axe_hitbox.scale = Vector2.ONE
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

	var distance = global_position.distance_to(player.global_position)
	var direction = global_position.direction_to(player.global_position)

	# Luôn quay mặt về phía Player
	if direction.x < 0:
		animated_sprite.flip_h = true
	elif direction.x > 0:
		animated_sprite.flip_h = false

	if is_attacking:
		return

	# Định hướng hitbox rìu về phía Player
	if direction != Vector2.ZERO:
		axe_hitbox.rotation = direction.angle()

	var tmap = get_parent()
	_ai_tick_timer -= delta
	if _ai_tick_timer <= 0.0:
		_ai_tick_timer = _ai_tick_interval
		_cached_has_los = (tmap == null or not tmap.has_method("has_line_of_sight") or tmap.has_line_of_sight(global_position, player.global_position))
		if distance > attack_range or not _cached_has_los:
			_cached_steer_dir = tmap.get_smart_steer_direction(global_position, direction) if (tmap != null and tmap.has_method("get_smart_steer_direction")) else direction
		else:
			_cached_steer_dir = direction

	if distance <= attack_range and _cached_has_los:
		attack()
	else:
		var move_dir: Vector2 = _cached_steer_dir if _cached_steer_dir != Vector2.ZERO else direction
		velocity = move_dir * speed
		move_and_slide()
		animated_sprite.play("walk")

func attack():
	is_attacking = true
	if player != null and is_instance_valid(player):
		var dir = global_position.direction_to(player.global_position)
		if dir != Vector2.ZERO:
			axe_hitbox.rotation = dir.angle()
	animated_sprite.play("attack")
	axe_collision.disabled = false

func take_damage(damage_amount: int) -> void:
	if not is_active or is_dead:
		return

	hp -= damage_amount
	_spawn_damage_popup(damage_amount)
	if hp > 0:
		animated_sprite.play("hurt")
		is_attacking = false
		axe_collision.set_deferred("disabled", true)
	else:
		is_dead = true
		var gm = get_node_or_null("/root/GameManager")
		if gm != null and gm.has_method("register_enemy_kill"):
			gm.register_enemy_kill()
		animated_sprite.play("death")
		$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
		$CollisionShape2D.set_deferred("disabled", true)
		axe_collision.set_deferred("disabled", true)

func _spawn_damage_popup(amount: int) -> void:
	if get_tree():
		get_tree().call_group("game_ui", "spawn_damage_number", global_position + Vector2(0, -20), amount, Color(1.0, 0.9, 0.3))

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "death":
		drop_loot()
		queue_free()
	elif animated_sprite.animation == "hurt":
		if not is_dead:
			animated_sprite.play("idle")
	elif animated_sprite.animation == "attack":
		is_attacking = false
		axe_collision.disabled = true
		animated_sprite.play("idle")

func _on_axe_hitbox_area_entered(area: Area2D) -> void:
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
