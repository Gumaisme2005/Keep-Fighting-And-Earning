extends BaseEnemy

@export var max_armor: int = 5
var current_armor: int = 5
@export var normal_damage: int = 1
@export var rage_damage: int = 3

@onready var axe_hitbox = $AxeHitbox
@onready var axe_collision = $AxeHitbox/CollisionShape2D
@onready var rage_hitbox = $RageHitbox
@onready var rage_collision = $RageHitbox/CollisionShape2D

func _ready() -> void:
	enemy_balance_id = "armored_orc"
	super._ready()
	var cfg: Dictionary = BalanceData.get_enemy_stats("armored_orc")
	max_armor = int(cfg.get("armor", max_armor))
	current_armor = max_armor
	normal_damage = int(cfg.get("damage", normal_damage))
	rage_damage = int(cfg.get("rage_damage", rage_damage))
	axe_collision.disabled = true
	rage_collision.disabled = true
	axe_hitbox.position = Vector2(0, -8)
	axe_hitbox.scale = Vector2.ONE
	rage_hitbox.position = Vector2(0, -8)
	rage_hitbox.scale = Vector2.ONE

func _physics_process(delta: float) -> void:
	if not is_active:
		return
	if player == null or not is_instance_valid(player):
		_find_player()
		if player == null:
			return
	if is_dead or (animated_sprite != null and (animated_sprite.animation == "hurt" or animated_sprite.animation == "block")):
		return

	var distance = global_position.distance_to(player.global_position)
	var direction = global_position.direction_to(player.global_position)

	if direction.x < 0:
		animated_sprite.flip_h = true
	elif direction.x > 0:
		animated_sprite.flip_h = false

	if is_attacking:
		return

	if direction != Vector2.ZERO:
		axe_hitbox.rotation = direction.angle()
		rage_hitbox.rotation = direction.angle()

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
			rage_hitbox.rotation = dir.angle()

	if current_armor > 0:
		animated_sprite.play("attack_normal")
		axe_collision.disabled = false
	else:
		animated_sprite.play("attack_rage")
		rage_collision.disabled = false

func take_damage(damage_amount: int) -> void:
	if not is_active or is_dead:
		return

	if current_armor > 0:
		current_armor -= damage_amount
		_spawn_damage_popup(damage_amount, Color(0.5, 0.85, 1.0))
		animated_sprite.play("block")
		is_attacking = false
		axe_collision.set_deferred("disabled", true)
		rage_collision.set_deferred("disabled", true)

		if current_armor < 0:
			var overflow_damage = abs(current_armor)
			current_armor = 0
			hp -= overflow_damage
	else:
		hp -= damage_amount
		_spawn_damage_popup(damage_amount, Color(1.0, 0.9, 0.3))
		if hp > 0:
			animated_sprite.play("hurt")
			is_attacking = false
			axe_collision.set_deferred("disabled", true)
			rage_collision.set_deferred("disabled", true)

	if hp <= 0:
		_die()

func _die() -> void:
	super._die()
	axe_collision.set_deferred("disabled", true)
	rage_collision.set_deferred("disabled", true)

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite == null:
		return
	if animated_sprite.animation == "death":
		drop_loot()
		queue_free()
	elif animated_sprite.animation == "hurt" or animated_sprite.animation == "block":
		if not is_dead:
			animated_sprite.play("idle")
	elif animated_sprite.animation == "attack_normal" or animated_sprite.animation == "attack_rage":
		is_attacking = false
		axe_collision.disabled = true
		rage_collision.disabled = true
		animated_sprite.play("idle")

func _on_axe_hitbox_area_entered(area: Area2D) -> void:
	if area.name == "PlayerHurtbox":
		var target = area.get_parent()
		var tmap = get_parent()
		if tmap != null and tmap.has_method("has_line_of_sight") and not tmap.has_line_of_sight(global_position, target.global_position):
			return
		if target.has_method("take_damage"):
			target.take_damage(normal_damage)

func _on_rage_hitbox_area_entered(area: Area2D) -> void:
	if area.name == "PlayerHurtbox":
		var target = area.get_parent()
		var tmap = get_parent()
		if tmap != null and tmap.has_method("has_line_of_sight") and not tmap.has_line_of_sight(global_position, target.global_position):
			return
		if target.has_method("take_damage"):
			target.take_damage(rage_damage)
