extends CharacterBody2D

const BalanceData = preload("res://scripts/core/balance_config.gd")

@export var damage: int = 2
@export var pounce_damage: int = 3
@export var speed: float = 95.0
@export var pounce_speed: float = 175.0
@export var pounce_distance: float = 95.0
@export var pounce_windup_time: float = 0.65
@export var attack_range: float = 24.0
@export var pounce_min_range: float = 50.0
@export var pounce_max_range: float = 135.0
@export var pounce_cooldown: float = 3.5

@export var world_item_scene: PackedScene = preload("res://scenes/items/world_item/world_item.tscn")
@export var loot_table: Array[ItemData] = [
	preload("res://scenes/items/health_potion.tres"),
	preload("res://scenes/items/big_health_potion.tres"),
	preload("res://scenes/items/iron_sword.tres")
]
@export var drop_chance: float = 0.35
var loot_seed: int = 0

var hp: int = 5
var max_hp: int = 5
var is_dead: bool = false
var is_attacking: bool = false
var is_preparing_pounce: bool = false
var is_pouncing: bool = false
var is_active: bool = false

var pounce_timer: float = 0.0
var pounce_direction: Vector2 = Vector2.ZERO
var pounce_traveled: float = 0.0
var show_pounce_warning: bool = false
var windup_flash_tween: Tween = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var claw_hitbox: Area2D = $ClawHitbox
@onready var claw_collision: CollisionShape2D = $ClawHitbox/CollisionShape2D
@onready var pounce_hitbox: Area2D = $PounceHitbox
@onready var pounce_collision: CollisionShape2D = $PounceHitbox/CollisionShape2D

var player: Node2D = null

func _ready() -> void:
	var cfg: Dictionary = BalanceData.get_enemy_stats("werewolf")
	hp = int(cfg.get("hp", hp))
	max_hp = hp
	damage = int(cfg.get("damage", damage))
	pounce_damage = int(cfg.get("pounce_damage", pounce_damage))
	speed = float(cfg.get("speed", speed))
	pounce_speed = float(cfg.get("pounce_speed", pounce_speed))
	pounce_distance = float(cfg.get("pounce_distance", pounce_distance))
	pounce_windup_time = float(cfg.get("pounce_windup_time", pounce_windup_time))
	attack_range = float(cfg.get("attack_range", attack_range))
	pounce_min_range = float(cfg.get("pounce_min_range", pounce_min_range))
	pounce_max_range = float(cfg.get("pounce_max_range", pounce_max_range))
	pounce_cooldown = float(cfg.get("pounce_cooldown", pounce_cooldown))
	drop_chance = float(cfg.get("drop_chance", drop_chance))

	animated_sprite.play("idle")
	claw_collision.disabled = true
	pounce_collision.disabled = true
	claw_hitbox.position = Vector2(0, -8)
	pounce_hitbox.position = Vector2(0, -8)

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _draw() -> void:
	if show_pounce_warning:
		var origin: Vector2 = Vector2(0, -8)
		var norm_dir: Vector2 = pounce_direction.normalized() if pounce_direction != Vector2.ZERO else Vector2.RIGHT
		var end_pt: Vector2 = origin + norm_dir * pounce_distance

		# 1. Dải màu đỏ mờ biểu thị toàn bộ vệt lao đến
		draw_line(origin, end_pt, Color(1.0, 0.15, 0.15, 0.30), 22.0)
		# 2. Vạch chỉ hướng trung tâm sắc nét
		draw_line(origin, end_pt, Color(1.0, 0.3, 0.3, 0.85), 2.5)
		# 3. Điểm đánh dấu đích đến của cú vồ (tầm dừng lại)
		draw_circle(end_pt, 6.0, Color(1.0, 0.2, 0.2, 0.75))
		draw_arc(end_pt, 8.5, 0.0, TAU, 16, Color(1.0, 0.85, 0.3, 0.95), 1.5)

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	if pounce_timer > 0.0:
		pounce_timer -= delta

	if player == null or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
		else:
			return

	if is_dead or animated_sprite.animation == "hurt":
		return

	# Đang trong pha tụ lực/khựng lại cảnh báo -> đứng yên
	if is_preparing_pounce:
		velocity = Vector2.ZERO
		return

	# Đang trong cú vồ: di chuyển theo một khoảng cách nhất định với vận tốc vừa phải
	if is_pouncing:
		var remain_dist: float = pounce_distance - pounce_traveled
		if remain_dist <= 0.0 or is_on_wall():
			is_pouncing = false
			velocity = Vector2.ZERO
		else:
			var current_spd: float = pounce_speed
			if pounce_traveled > pounce_distance * 0.7:
				current_spd = pounce_speed * 0.65

			var step_dist: float = current_spd * delta
			if step_dist >= remain_dist:
				step_dist = remain_dist
				pounce_traveled = pounce_distance
				is_pouncing = false
				velocity = Vector2.ZERO
			else:
				pounce_traveled += step_dist
				velocity = pounce_direction * current_spd

			move_and_slide()
		return

	if is_attacking:
		return

	var distance: float = global_position.distance_to(player.global_position)
	var direction: Vector2 = global_position.direction_to(player.global_position)

	# Định hướng sprite
	if direction.x < 0:
		animated_sprite.flip_h = true
	elif direction.x > 0:
		animated_sprite.flip_h = false

	# Xoay hitboxes theo hướng người chơi
	if direction != Vector2.ZERO:
		claw_hitbox.rotation = direction.angle()
		pounce_hitbox.rotation = direction.angle()

	var tmap = get_parent()
	var has_los: bool = (tmap == null or not tmap.has_method("has_line_of_sight") or tmap.has_line_of_sight(global_position, player.global_position))

	# 1. Cự ly gần -> Đòn cào thường (Claw Slash - Attack01)
	if distance <= attack_range and has_los:
		attack_claw(direction)
	# 2. Cự ly trung bình + có LOS + hết cooldown -> Khựng lại tụ lực chuẩn bị vồ (Pounce - Attack02)
	elif distance >= pounce_min_range and distance <= pounce_max_range and pounce_timer <= 0.0 and has_los:
		start_pounce_windup(direction)
	# 3. Di chuyển truy đuổi bình thường
	else:
		var move_dir: Vector2 = tmap.get_smart_steer_direction(global_position, direction) if (tmap != null and tmap.has_method("get_smart_steer_direction")) else direction
		velocity = move_dir * speed
		move_and_slide()
		animated_sprite.play("walk")

func attack_claw(dir: Vector2) -> void:
	is_attacking = true
	is_pouncing = false
	if dir != Vector2.ZERO:
		claw_hitbox.rotation = dir.angle()
	animated_sprite.play("attack_1")
	claw_collision.disabled = false

func start_pounce_windup(dir: Vector2) -> void:
	is_attacking = true
	is_preparing_pounce = true
	is_pouncing = false
	velocity = Vector2.ZERO
	pounce_direction = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	pounce_timer = pounce_cooldown

	# Xoay hitbox theo hướng đã nhắm
	pounce_hitbox.rotation = pounce_direction.angle()

	# Hiển thị vệt cảnh báo đỏ
	show_pounce_warning = true
	queue_redraw()

	# Hoạt ảnh khựng lại, mắt/người chớp đỏ nhẹ tụ lực
	animated_sprite.play("idle")
	_start_windup_flash()

	# Đợi một nhịp tụ lực
	if get_tree() != null:
		await get_tree().create_timer(pounce_windup_time).timeout

	if not is_inside_tree() or is_queued_for_deletion():
		return

	# Tắt cảnh báo đỏ
	show_pounce_warning = false
	queue_redraw()
	_stop_windup_flash()

	# Nếu trong lúc tụ lực bị chết hoặc trúng đòn choáng thì hủy cú vồ
	if not is_preparing_pounce or is_dead or animated_sprite.animation == "hurt":
		is_preparing_pounce = false
		is_attacking = false
		return

	# Bắt đầu lao đến
	is_preparing_pounce = false
	is_pouncing = true
	pounce_traveled = 0.0
	animated_sprite.play("attack_2")
	pounce_collision.disabled = false

func _start_windup_flash() -> void:
	if not is_inside_tree():
		return
	if windup_flash_tween != null:
		windup_flash_tween.kill()
	windup_flash_tween = create_tween().set_loops()
	windup_flash_tween.tween_property(animated_sprite, "modulate", Color(1.3, 0.45, 0.45), 0.16)
	windup_flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.16)

func _stop_windup_flash() -> void:
	if windup_flash_tween != null:
		windup_flash_tween.kill()
		windup_flash_tween = null
	if animated_sprite != null:
		animated_sprite.modulate = Color.WHITE

func take_damage(damage_amount: int) -> void:
	if not is_active or is_dead:
		return

	hp -= damage_amount
	_spawn_damage_popup(damage_amount)

	# Bị trúng đòn -> Hủy trạng thái tụ lực và tắt cảnh báo đỏ
	if is_preparing_pounce:
		is_preparing_pounce = false
		show_pounce_warning = false
		_stop_windup_flash()
		queue_redraw()

	if hp > 0:
		animated_sprite.play("hurt")
		is_attacking = false
		is_pouncing = false
		claw_collision.set_deferred("disabled", true)
		pounce_collision.set_deferred("disabled", true)
	else:
		is_dead = true
		is_attacking = false
		is_pouncing = false
		var gm = get_node_or_null("/root/GameManager")
		if gm != null and gm.has_method("register_enemy_kill"):
			gm.register_enemy_kill()
		animated_sprite.play("death")
		$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
		$CollisionShape2D.set_deferred("disabled", true)
		claw_collision.set_deferred("disabled", true)
		pounce_collision.set_deferred("disabled", true)

func _spawn_damage_popup(amount: int) -> void:
	if get_tree():
		get_tree().call_group("game_ui", "spawn_damage_number", global_position + Vector2(0, -20), amount, Color(1.0, 0.4, 0.4))

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "death":
		drop_loot()
		queue_free()
	elif animated_sprite.animation == "hurt":
		if not is_dead:
			animated_sprite.play("idle")
	elif animated_sprite.animation == "attack_1":
		is_attacking = false
		claw_collision.disabled = true
		animated_sprite.play("idle")
	elif animated_sprite.animation == "attack_2":
		is_attacking = false
		is_pouncing = false
		pounce_collision.disabled = true
		animated_sprite.play("idle")

func _on_claw_hitbox_area_entered(area: Area2D) -> void:
	if area.name == "PlayerHurtbox":
		var target = area.get_parent()
		var tmap = get_parent()
		if tmap != null and tmap.has_method("has_line_of_sight") and not tmap.has_line_of_sight(global_position, target.global_position):
			return
		if target.has_method("take_damage"):
			target.take_damage(damage)

func _on_pounce_hitbox_area_entered(area: Area2D) -> void:
	if area.name == "PlayerHurtbox":
		var target = area.get_parent()
		var tmap = get_parent()
		if tmap != null and tmap.has_method("has_line_of_sight") and not tmap.has_line_of_sight(global_position, target.global_position):
			return
		if target.has_method("take_damage"):
			target.take_damage(pounce_damage)

func drop_loot() -> void:
	if world_item_scene != null and loot_table.size() > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = loot_seed if loot_seed != 0 else (int(global_position.x * 911) ^ int(global_position.y * 3571))
		if rng.randf() <= drop_chance:
			var random_item = loot_table[rng.randi() % loot_table.size()]
			var item_drop = world_item_scene.instantiate()
			item_drop.item_data = random_item
			item_drop.global_position = global_position
			var parent_node = get_parent() if get_parent() != null else get_tree().current_scene
			parent_node.call_deferred("add_child", item_drop)
