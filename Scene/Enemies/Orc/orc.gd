extends CharacterBody2D

const BalanceData = preload("res://Scene/BalanceConfig.gd")
const Tactics = preload("res://Scene/Enemies/AI/EnemyTactics.gd")
const TACTICAL_PROBE_DISTANCE: float = 18.0 # Same local probe distance as map steering.
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

var _tactics: Tactics
var _tactic_config: Dictionary = {}
var _tactic_limits: Dictionary = {}
var _tactic_tick: int = 0
var _physics_tick_rate: int = 60
var _flank_sign: float = 1.0
var _observed_target: Node2D = null
var _observed_position: Vector2 = Vector2.ZERO
var _observed_tick: int = -1
var _prediction_offset: Vector2 = Vector2.ZERO
var _previous_decision_position: Vector2 = Vector2.ZERO
var _has_movement_sample: bool = false

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
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	# The map is authoritative. Standalone enemies must not inherit a saved run's
	# GameManager level; an absent/invalid map floor safely keeps their basic AI.
	var floor_number := 1
	var map = get_parent()
	if map != null and "current_level" in map:
		var map_floor: Variant = map.get("current_level")
		if map_floor is int and map_floor > 0:
			floor_number = map_floor
	_physics_tick_rate = maxi(1, Engine.physics_ticks_per_second)
	_tactics = Tactics.new("orc", floor_number, _physics_tick_rate)
	_tactic_config = _tactics.get_config()
	_tactic_limits = _tactic_config.get("tactics", {})
	_flank_sign = -1.0 if loot_seed % 2 == 0 else 1.0

func _physics_process(_delta: float) -> void:
	_tactic_tick += 1 # Local fixed simulation ticks, independent of rendering FPS.
	if not is_active:
		_clear_tactical_observation()
		return
	if player == null or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
		else:
			_clear_tactical_observation()
			return
	if is_dead or animated_sprite.animation == "hurt":
		_clear_tactical_observation()
		return

	var distance = global_position.distance_to(player.global_position)
	var direction = global_position.direction_to(player.global_position)

	# Luôn quay mặt về phía Player
	if direction.x < 0:
		animated_sprite.flip_h = true
	elif direction.x > 0:
		animated_sprite.flip_h = false

	if is_attacking:
		_clear_tactical_observation()
		return

	# Định hướng hitbox rìu về phía Player
	if direction != Vector2.ZERO:
		axe_hitbox.rotation = direction.angle()

	var tmap = get_parent()
	var has_los: bool = (tmap == null or not tmap.has_method("has_line_of_sight") or tmap.has_line_of_sight(global_position, player.global_position))

	if distance <= attack_range and has_los:
		attack()
	else:
		var desired_dir := _get_tactical_direction(tmap, direction, distance, has_los)
		var move_dir: Vector2 = tmap.get_smart_steer_direction(global_position, desired_dir) if (tmap != null and tmap.has_method("get_smart_steer_direction")) else direction
		velocity = move_dir * speed
		move_and_slide()
		animated_sprite.play("walk")


func _clear_tactical_observation() -> void:
	_observed_tick = -1
	_observed_target = null
	_prediction_offset = Vector2.ZERO
	_has_movement_sample = false


func _get_tactical_direction(map: Node, direct: Vector2, distance: float, has_los: bool) -> Vector2:
	if not _tactics.is_enabled() or map == null or not map.has_method("get_smart_steer_direction") or not map.has_method("has_line_of_sight"):
		_clear_tactical_observation()
		return direct
	# Loss of sight or a replacement target invalidates prediction immediately,
	# even between decisions. A freed player must never leave a stale lead.
	if not has_los or not is_instance_valid(_observed_target) or _observed_target != player:
		_observed_tick = -1
		_prediction_offset = Vector2.ZERO
	if _tactics.begin_decision(_tactic_tick):
		_update_tactical_state(map, direct, distance, has_los)
	return _direction_for_state(_tactics.get_state(), direct)


func _update_tactical_state(map: Node, direct: Vector2, distance: float, has_los: bool) -> void:
	_prediction_offset = Vector2.ZERO
	var horizon: float = _tactic_limits["prediction_seconds"]
	if has_los and horizon > 0.0:
		if is_instance_valid(_observed_target) and _observed_target == player and _observed_tick >= 0:
			var elapsed := float(_tactic_tick - _observed_tick) / _physics_tick_rate
			var motion := (player.global_position - _observed_position) / elapsed
			# A dash/teleport cannot cause an unbounded lead. No player inputs or
			# velocity property are read; only displacement seen at prior decisions.
			var lead := (motion * horizon).limit_length(speed * horizon)
			if map.has_line_of_sight(player.global_position, player.global_position + lead):
				_prediction_offset = lead
		_observed_target = player
		_observed_position = player.global_position
		_observed_tick = _tactic_tick

	var preferred: StringName = &"flank_left" if _flank_sign < 0.0 else &"flank_right"
	if distance <= attack_range * 2.0:
		preferred = &"approach"
	elif _prediction_offset.length_squared() > 1.0:
		preferred = &"intercept"
	var candidate := preferred
	if int(_tactic_config["tier"]) >= Tactics.Tier.ADVANCED:
		var neighbors := _sample_nearby_enemies()
		var blocked := _has_movement_sample and global_position.distance_to(_previous_decision_position) < speed * float(_tactic_config["decision_interval_seconds"]) * 0.2
		var best_score := -INF
		# Fixed candidate order and a bias for the current state prevent ties and
		# small clearance changes from making the Orc alternate sides every tick.
		var states: Array[StringName] = [preferred, &"approach", &"flank_left", &"flank_right"]
		for state in states:
			var desired := _direction_for_state(state, direct)
			var score := desired.dot(direct)
			if state == preferred:
				score += 0.2
			if state == _tactics.get_state():
				score += -0.5 if blocked else 0.15
			if not map.has_line_of_sight(global_position, global_position + desired * TACTICAL_PROBE_DISTANCE):
				score -= 4.0
			for offset in neighbors:
				score += ((offset - desired * TACTICAL_PROBE_DISTANCE).length() - offset.length()) / float(_tactic_limits["separation_radius_px"])
			if score > best_score:
				best_score = score
				candidate = state
	_previous_decision_position = global_position
	_has_movement_sample = true
	_tactics.try_change_state(candidate, _tactic_tick)


func _direction_for_state(state: StringName, direct: Vector2) -> Vector2:
	var angle: float = _tactic_limits["flank_angle_radians"]
	match state:
		&"flank_left":
			return direct.rotated(-angle)
		&"flank_right":
			return direct.rotated(angle)
		&"intercept":
			var projected := global_position.direction_to(player.global_position + _prediction_offset)
			return direct.rotated(clampf(direct.angle_to(projected), -angle, angle))
	return direct


func _sample_nearby_enemies() -> Array[Vector2]:
	var samples: Array[Vector2] = []
	var limit: int = _tactic_config["max_neighbor_samples"]
	var radius: float = _tactic_limits["separation_radius_px"]
	# Only on decision ticks: retain at most the profile's 3/4 nearest offsets.
	# Rank equal distances by coordinates, never by instance ID or group order.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D or enemy == self or enemy.get_parent() != get_parent() or enemy.is_queued_for_deletion():
			continue
		if enemy.get("is_active") != true or enemy.get("is_dead") == true:
			continue
		var offset: Vector2 = enemy.global_position - global_position
		if offset.length_squared() >= radius * radius:
			continue
		var index := 0
		while index < samples.size() and _offset_before(samples[index], offset):
			index += 1
		if index < limit:
			samples.insert(index, offset)
			if samples.size() > limit:
				samples.pop_back()
	return samples


func _offset_before(first: Vector2, second: Vector2) -> bool:
	if first.length_squared() != second.length_squared():
		return first.length_squared() < second.length_squared()
	if first.x != second.x:
		return first.x < second.x
	return first.y < second.y


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
	if not is_active or is_dead or not is_attacking or animated_sprite.animation == "hurt":
		return
	if area.name == "PlayerHurtbox":
		var target = area.get_parent()
		# The axe shape extends past attack_range. Recheck the real target at
		# contact, so a retreating player cannot be hit outside melee range.
		if global_position.distance_to(target.global_position) > attack_range:
			return
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
