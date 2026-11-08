extends CharacterBody2D

const BalanceData = preload("res://Scene/BalanceConfig.gd")
const Tactics = preload("res://Scene/Enemies/AI/EnemyTactics.gd")
const TACTICAL_PROBE_DISTANCE: float = 18.0
@export var speed: float = 65.0
@export var attack_range: float = 195.0
@export var retreat_range: float = 85.0
@export var attack_cooldown: float = 2.0
@export var damage: int = 1
@export var max_hp: int = 4

@export var arrow_scene: PackedScene
@export var world_item_scene: PackedScene = preload("res://Scene/Items/WorldItem/WorldItem.tscn")
@export var loot_table: Array[ItemData] = [
	preload("res://Scene/Items/Common/health_potion.tres"),
	preload("res://Scene/Items/Common/iron_helmet.tres")
]
@export var drop_chance: float = 0.3
var loot_seed: int = 0

var hp: int = 4
var is_active: bool = false
var is_dead: bool = false
var is_attacking: bool = false
var is_hurt: bool = false
var can_attack: bool = true
var strafe_sign: float = 1.0
var strafe_timer: float = 0.0

@onready var anim = $AnimatedSprite2D
var player: Node2D = null

var _tactics: Tactics
var _tactic_config: Dictionary = {}
var _tactic_limits: Dictionary = {}
var _tactic_tick: int = 0
var _physics_tick_rate: int = 60
var _retreat_latched: bool = false
var _approach_latched: bool = false
var _lost_los_tick: int = -1
var _strafe_blocked: bool = false
var _seen_target: Node2D = null
var _has_last_seen: bool = false
var _last_seen_position: Vector2 = Vector2.ZERO
var _last_seen_direction: Vector2 = Vector2.RIGHT
var _observed_position: Vector2 = Vector2.ZERO
var _observed_tick: int = -1
var _prediction_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	var cfg: Dictionary = BalanceData.get_enemy_stats("skeleton_archer")
	max_hp = int(cfg.get("hp", max_hp))
	hp = max_hp
	damage = int(cfg.get("damage", damage))
	speed = float(cfg.get("speed", speed))
	attack_range = float(cfg.get("attack_range", attack_range))
	retreat_range = float(cfg.get("retreat_range", retreat_range))
	attack_cooldown = float(cfg.get("attack_cooldown", attack_cooldown))
	drop_chance = float(cfg.get("drop_chance", drop_chance))
	strafe_sign = -1.0 if (loot_seed % 2 == 0) else 1.0
	anim.play("summon")
	_find_player()
	# Match the Orc adapter: the dungeon floor is authoritative; standalone tests
	# must not inherit GameManager's saved floor. Missing navigation uses old AI.
	var floor_number := 1
	var map = get_parent()
	if map != null and "current_level" in map:
		var map_floor: Variant = map.get("current_level")
		if map_floor is int and map_floor > 0:
			floor_number = map_floor
	_physics_tick_rate = maxi(1, Engine.physics_ticks_per_second)
	_tactics = Tactics.new("skeleton_archer", floor_number, _physics_tick_rate)
	_tactic_config = _tactics.get_config()
	_tactic_limits = _tactic_config["tactics"]

func _find_player() -> void:
	player = null
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D and is_instance_valid(node):
			player = node
			return

func _physics_process(delta: float) -> void:
	_tactic_tick += 1
	if not is_active or is_dead or is_hurt or is_attacking:
		_clear_tactical_motion()
		return
	if player == null or not is_instance_valid(player):
		_find_player()
		if player == null:
			_clear_tactical_motion()
			return

	var tmap = get_parent()
	var tactical: bool = _tactics.is_enabled() and tmap != null and tmap.has_method("has_line_of_sight") and tmap.has_method("get_smart_steer_direction")
	var advanced: bool = tactical and int(_tactic_config["tier"]) >= Tactics.Tier.ADVANCED
	# Tier 0/1 retain the original timer/collision strafe. Higher tiers choose the
	# same strafe_sign through EnemyTactics instead of flipping on every contact.
	if not advanced:
		strafe_timer += delta
		if strafe_timer >= 1.35:
			strafe_timer = 0.0
			strafe_sign = -strafe_sign

	var distance: float = global_position.distance_to(player.global_position)
	var direction: Vector2 = global_position.direction_to(player.global_position)
	var has_los: bool = true
	if tmap != null and tmap.has_method("has_line_of_sight"):
		has_los = tmap.has_line_of_sight(global_position, player.global_position)
	if tactical:
		if not is_instance_valid(_seen_target) or _seen_target != player:
			_clear_tactical_motion()
			_has_last_seen = false
			_seen_target = player
		if has_los:
			_last_seen_position = player.global_position
			_last_seen_direction = direction
			_has_last_seen = true
			_lost_los_tick = -1
		else:
			_observed_tick = -1
			_prediction_offset = Vector2.ZERO
			if _lost_los_tick < 0:
				_lost_los_tick = _tactic_tick
			if int(_tactic_config["tier"]) == Tactics.Tier.ADAPTIVE:
				# The actual target position above is used only for the visibility
				# query. Navigation while occluded knows only the last seen position.
				direction = global_position.direction_to(_last_seen_position) if _has_last_seen else Vector2.RIGHT * strafe_sign
				if direction == Vector2.ZERO:
					direction = _last_seen_direction
		if has_los:
			_update_range_hysteresis(distance)
		if _tactics.begin_decision(_tactic_tick):
			_update_tactical_side(tmap, direction, has_los, advanced)
	else:
		_clear_tactical_motion()

	anim.flip_h = direction.x < 0

	# Nếu bị tường hoặc cột đá che khuất tầm bắn -> Di chuyển vòng qua vật cản, tuyệt đối không đứng yên bắn vào tường
	if not has_los:
		var desired := direction
		if advanced and _lateral_search_active():
			desired = direction.orthogonal() * strafe_sign
		var move_dir: Vector2 = tmap.get_smart_steer_direction(global_position, desired) if (tmap != null and tmap.has_method("get_smart_steer_direction")) else direction
		velocity = move_dir * speed
		anim.play("walk")
		move_and_slide()
		return

	# Safety boundaries are evaluated every physics tick, never gated by the
	# tactical clock. Hysteresis cannot extend firing range or postpone retreat.
	var retreating: bool = distance < retreat_range or (tactical and _retreat_latched)
	var approaching: bool = distance > attack_range or (tactical and _approach_latched and not can_attack and not retreating)
	if approaching:
		var move_dir: Vector2 = tmap.get_smart_steer_direction(global_position, direction) if (tmap != null and tmap.has_method("get_smart_steer_direction")) else direction
		velocity = move_dir * speed
		anim.play("walk")
		move_and_slide()
	elif retreating:
		var retreat_dir: Vector2 = tmap.get_smart_steer_direction(global_position, -direction) if (tmap != null and tmap.has_method("get_smart_steer_direction")) else -direction
		velocity = retreat_dir * (speed * 0.85)
		anim.play("walk")
		anim.flip_h = velocity.x < 0
		move_and_slide()
	else:
		if can_attack:
			velocity = Vector2.ZERO
			attack()
		else:
			# Trong lúc hồi chiêu giữa 2 phát bắn -> Di chuyển đảo ngang (Strafe) thay vì đứng yên một chỗ
			var lateral: Vector2 = direction.orthogonal() * strafe_sign
			var strafe_dir: Vector2 = tmap.get_smart_steer_direction(global_position, lateral) if (tmap != null and tmap.has_method("get_smart_steer_direction")) else lateral
			velocity = strafe_dir * (speed * 0.72)
			anim.play("walk")
			move_and_slide()
			if advanced:
				_strafe_blocked = _strafe_blocked or get_slide_collision_count() > 0
			elif get_slide_collision_count() > 0:
				strafe_sign = -strafe_sign


func _clear_tactical_motion() -> void:
	_observed_tick = -1
	_prediction_offset = Vector2.ZERO
	_lost_los_tick = -1
	_strafe_blocked = false


func _update_range_hysteresis(distance: float) -> void:
	var margin: float = _tactic_limits["range_hysteresis_px"]
	if distance < retreat_range:
		_retreat_latched = true
	elif distance >= retreat_range + margin:
		_retreat_latched = false
	if distance > attack_range:
		_approach_latched = true
	elif distance <= attack_range - margin:
		_approach_latched = false


func _lateral_search_active() -> bool:
	var budget := ceili(float(_tactic_limits["lateral_reposition_seconds"]) * _physics_tick_rate)
	return _lost_los_tick >= 0 and _tactic_tick - _lost_los_tick < budget


func _update_tactical_side(map: Node, direction: Vector2, has_los: bool, advanced: bool) -> void:
	_prediction_offset = Vector2.ZERO
	if has_los:
		var horizon: float = _tactic_limits["prediction_seconds"]
		if horizon > 0.0 and _observed_tick >= 0:
			var elapsed := float(_tactic_tick - _observed_tick) / _physics_tick_rate
			var lead := ((player.global_position - _observed_position) * horizon / elapsed).limit_length(speed * horizon)
			if map.has_line_of_sight(player.global_position, player.global_position + lead):
				_prediction_offset = lead
		_observed_position = player.global_position
		_observed_tick = _tactic_tick
	if not advanced:
		return
	var candidate: StringName = &"left" if strafe_sign < 0.0 else &"right"
	var best_score := -INF
	var aim := _last_seen_position + _prediction_offset
	var margin: float = _tactic_limits["range_hysteresis_px"]
	# Exactly two local candidate positions, only on decision ticks. No scene scan.
	for side in [strafe_sign, -strafe_sign]:
		var state: StringName = &"left" if side < 0.0 else &"right"
		var probe: Vector2 = global_position + direction.orthogonal() * side * TACTICAL_PROBE_DISTANCE
		var score := 0.0
		if state == _tactics.get_state():
			score += -0.5 if _strafe_blocked else 0.15
		if not map.has_line_of_sight(global_position, probe):
			score -= 8.0
		if _has_last_seen:
			if map.has_line_of_sight(probe, aim):
				score += 2.0
			var predicted_distance := probe.distance_to(aim)
			var safe_distance := retreat_range + margin
			if predicted_distance < safe_distance:
				score -= (safe_distance - predicted_distance) / TACTICAL_PROBE_DISTANCE
			if predicted_distance > attack_range:
				score -= (predicted_distance - attack_range) / TACTICAL_PROBE_DISTANCE
			# Prefer a safe firing position; observed lateral movement breaks ties.
			score -= absf(predicted_distance - (retreat_range + attack_range) * 0.5) / maxf(1.0, attack_range - retreat_range)
		if score > best_score:
			best_score = score
			candidate = state
	_strafe_blocked = false
	_tactics.try_change_state(candidate, _tactic_tick)
	match _tactics.get_state():
		&"left": strafe_sign = -1.0
		&"right": strafe_sign = 1.0


func attack() -> void:
	is_attacking = true
	can_attack = false
	anim.play("attack")

	await get_tree().create_timer(0.4).timeout

	if not is_dead and not is_hurt and is_instance_valid(player) and arrow_scene != null:
		var tmap = get_parent()
		if tmap == null or not tmap.has_method("has_line_of_sight") or tmap.has_line_of_sight(global_position, player.global_position):
			shoot_arrow()

	await get_tree().create_timer(0.35).timeout
	if is_attacking and not is_dead:
		is_attacking = false
		if not is_hurt:
			anim.play("idle")

	await get_tree().create_timer(maxf(0.1, attack_cooldown - 0.75)).timeout
	can_attack = true

func shoot_arrow() -> void:
	if arrow_scene == null or get_parent() == null or not is_instance_valid(player):
		return
	var arrow = arrow_scene.instantiate()
	var shoot_dir = global_position.direction_to(player.global_position).normalized()
	if shoot_dir == Vector2.ZERO:
		shoot_dir = Vector2.RIGHT
	var spawn_pos: Vector2 = global_position + (shoot_dir * 6.0)
	if get_parent() is Node2D:
		arrow.position = (get_parent() as Node2D).to_local(spawn_pos)
	arrow.direction = shoot_dir
	arrow.rotation = shoot_dir.angle()
	arrow.damage = damage
	get_parent().add_child(arrow)
	arrow.global_position = spawn_pos

func take_damage(amount: int) -> void:
	if not is_active or is_dead:
		return

	hp -= amount
	if get_tree():
		get_tree().call_group("game_ui", "spawn_damage_number", global_position + Vector2(0, -20), amount, Color(1.0, 0.9, 0.3))
	if hp > 0:
		is_hurt = true
		is_attacking = false
		anim.play("hurt")
	else:
		is_dead = true
		if get_node_or_null("/root/GameManager") != null:
			GameManager.register_enemy_kill()
		anim.play("death")
		$CollisionShape2D.set_deferred("disabled", true)
		if has_node("Hurtbox/CollisionShape2D"):
			$Hurtbox/CollisionShape2D.set_deferred("disabled", true)

func _on_animated_sprite_2d_animation_finished() -> void:
	var current = anim.animation

	if current == "death":
		drop_loot()
		queue_free()
	elif current == "hurt":
		is_hurt = false
		if not is_dead:
			anim.play("idle")
	elif current == "attack":
		is_attacking = false
		if not is_dead and not is_hurt:
			anim.play("idle")
	elif current == "summon":
		anim.play("idle")

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
