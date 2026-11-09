extends BaseEnemy

@onready var sword_hitbox = $SwordHitbox
@onready var sword_collision = $SwordHitbox/CollisionShape2D

func _init() -> void:
	loot_table = [
		preload("res://Scene/Items/Common/health_potion.tres"),
		preload("res://Scene/Items/Common/iron_sword.tres")
	]
	drop_chance = 0.05

func _ready() -> void:
	enemy_balance_id = "skeleton"
	super._ready()
	sword_collision.disabled = true
	sword_hitbox.position = Vector2(0, -6)
	sword_hitbox.scale = Vector2.ONE

func _physics_process(delta: float) -> void:
	if not is_active:
		return
	if player == null or not is_instance_valid(player):
		_find_player()
		if player == null:
			return
	if is_dead or (animated_sprite != null and animated_sprite.animation == "hurt"):
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
		sword_hitbox.rotation = direction.angle()

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
			sword_hitbox.rotation = dir.angle()
	animated_sprite.play("attack")
	sword_collision.disabled = false

func _on_hurt() -> void:
	sword_collision.set_deferred("disabled", true)

func _die() -> void:
	super._die()
	sword_collision.set_deferred("disabled", true)
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	drop_loot()
	queue_free()

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite == null:
		return
	if animated_sprite.animation == "hurt":
		if not is_dead:
			animated_sprite.play("idle")
	elif animated_sprite.animation == "attack":
		is_attacking = false
		sword_collision.disabled = true
		animated_sprite.play("idle")

func _on_sword_hitbox_area_entered(area: Area2D) -> void:
	if area.name == "PlayerHurtbox":
		var target = area.get_parent()
		var tmap = get_parent()
		if tmap != null and tmap.has_method("has_line_of_sight") and not tmap.has_line_of_sight(global_position, target.global_position):
			return
		if target.has_method("take_damage"):
			FloorBalance.hit(target, damage, armor_piercing)
