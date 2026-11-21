extends CharacterBody2D

signal boss_hp_changed(current_hp: int, max_hp: int, phase: int, boss_name: String)

const FloorBalance = preload("res://Scene/Balance/EnemyFloorBalance.gd")
var combat_floor: int = 1
var armor_piercing: float = 0.0

const BalanceData = preload("res://Scene/BalanceConfig.gd")
const BOSS_NAME: String = "WARG RIDER CHIEFTAIN — WARLORD OF MORIA"

@export var max_hp: int = 30
var hp: int

@export var base_speed: float = 70.0
var current_speed: float

@export var base_damage: int = 2
var active_damage: int

var current_phase: int = 1
var is_active: bool = false
var is_dead: bool = false
var is_attacking: bool = false
var is_hurt: bool = false

var can_charge: bool = true
var is_preparing_charge: bool = false
var is_charging: bool = false
var charge_dir: Vector2 = Vector2.ZERO

var is_preparing_spin: bool = false

var show_charge_warning: bool = false
var show_spin_warning: bool = false
var flash_tween: Tween
var hit_flash_tween: Tween
var _action_gen: int = 0
var _nav_timer: float = 0.0
var _cached_nav_dir: Vector2 = Vector2.ZERO

@onready var anim = $AnimatedSprite2D
@onready var shape_1 = $Hitbox/Shape1
@onready var shape_2 = $Hitbox/Shape2
@onready var shape_3 = $Hitbox/Shape3

var player: Node2D = null

func _ready() -> void:
	var cfg: Dictionary = BalanceData.get_boss_stats("orc_rider")
	max_hp = FloorBalance.health(int(cfg.get("hp", max_hp)), combat_floor, true)
	armor_piercing = FloorBalance.penetration(combat_floor)
	base_speed = float(cfg.get("speed", base_speed))
	base_damage = int(cfg.get("damage", base_damage)) + FloorBalance.damage_bonus(combat_floor)
	hp = max_hp
	current_speed = base_speed
	active_damage = base_damage

	_disable_all_hitboxes()

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	anim.play("idle")

func _draw() -> void:
	if show_charge_warning:
		var local_dir = to_local(global_position + charge_dir)
		draw_line(Vector2.ZERO, local_dir * 500.0, Color(1.0, 0.2, 0.2, 0.4), 40.0)

	if show_spin_warning:
		draw_circle(Vector2.ZERO, 65.0, Color(1.0, 0.2, 0.2, 0.4))

func _physics_process(delta: float) -> void:
	if not is_active or is_dead or is_hurt:
		return
	if player == null or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
		else:
			return

	var distance: float = global_position.distance_to(player.global_position)
	var direction: Vector2 = global_position.direction_to(player.global_position)

	if not is_preparing_charge and not is_charging and not is_preparing_spin and not is_attacking:
		anim.flip_h = direction.x < 0
		if anim.flip_h:
			$Hitbox.scale.x = -1
		else:
			$Hitbox.scale.x = 1

	if is_preparing_charge or is_preparing_spin or is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_charging:
		velocity = charge_dir * (base_speed * 4.0)
		move_and_slide()
		if is_on_wall():
			_stop_charge()
		return

	var tmap = get_parent()
	var has_los: bool = (tmap == null or not tmap.has_method("has_line_of_sight") or tmap.has_line_of_sight(global_position, player.global_position))

	if distance > 150.0 and can_charge and has_los:
		prep_charge()
	elif distance > 45.0 or not has_los:
		_nav_timer -= delta
		var move_dir: Vector2 = direction
		if not has_los or is_on_wall():
			if _nav_timer <= 0.0 or _cached_nav_dir == Vector2.ZERO or is_on_wall():
				_nav_timer = 0.15
				_cached_nav_dir = _get_boss_nav_direction(tmap, direction)
			move_dir = _cached_nav_dir if _cached_nav_dir != Vector2.ZERO else direction
		else:
			_cached_nav_dir = direction
		velocity = move_dir * current_speed
		anim.play("walk")
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		perform_attack(2)

func _get_boss_nav_direction(tmap: Node, fallback_dir: Vector2) -> Vector2:
	if tmap != null and tmap.has_method("local_to_map") and tmap.has_method("map_to_local") and tmap.has_method("is_global_pos_wall_or_door"):
		var start_cell: Vector2i = tmap.local_to_map(tmap.to_local(global_position))
		var goal_cell: Vector2i = tmap.local_to_map(tmap.to_local(player.global_position))
		if start_cell != goal_cell:
			var queue: Array[Vector2i] = [start_cell]
			var came_from: Dictionary = {start_cell: start_cell}
			var head := 0
			var found := false
			var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			while head < queue.size() and came_from.size() < 400:
				var cur: Vector2i = queue[head]
				head += 1
				if cur == goal_cell:
					found = true
					break
				for d in dirs:
					var nxt: Vector2i = cur + d
					if came_from.has(nxt):
						continue
					var nxt_global: Vector2 = tmap.to_global(tmap.map_to_local(nxt))
					if nxt != goal_cell and tmap.is_global_pos_wall_or_door(nxt_global):
						continue
					came_from[nxt] = cur
					queue.append(nxt)
			if found:
				var step_cell: Vector2i = goal_cell
				while came_from.get(step_cell, start_cell) != start_cell:
					step_cell = came_from[step_cell]
				var target_pos: Vector2 = tmap.to_global(tmap.map_to_local(step_cell))
				var bfs_dir: Vector2 = global_position.direction_to(target_pos)
				if bfs_dir != Vector2.ZERO:
					return bfs_dir
	if is_on_wall():
		var normal := get_wall_normal()
		var tangent := Vector2(-normal.y, normal.x)
		if tangent.dot(fallback_dir) < 0.0:
			tangent = -tangent
		return (fallback_dir + tangent * 1.5).normalized()
	if tmap != null and tmap.has_method("get_smart_steer_direction"):
		return tmap.get_smart_steer_direction(global_position, fallback_dir)
	return fallback_dir

func prep_charge() -> void:
	var gen := _action_gen
	is_preparing_charge = true
	anim.play("idle")
	charge_dir = global_position.direction_to(player.global_position)

	show_charge_warning = true
	queue_redraw()

	_start_flash_effect()
	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(self) or not is_inside_tree() or is_dead or gen != _action_gen:
		return

	show_charge_warning = false
	queue_redraw()

	if not is_preparing_charge:
		return

	is_preparing_charge = false
	start_charge()

func start_charge() -> void:
	var gen := _action_gen
	is_charging = true
	anim.play("walk")

	await get_tree().create_timer(1.2).timeout
	if not is_instance_valid(self) or not is_inside_tree() or is_dead or gen != _action_gen:
		return
	if is_charging:
		_stop_charge()

func _stop_charge() -> void:
	if not is_charging:
		return
	var gen := _action_gen
	is_charging = false
	velocity = Vector2.ZERO

	if not is_dead and not is_hurt and not is_preparing_spin:
		perform_attack(1)

	can_charge = false
	await get_tree().create_timer(5.0).timeout
	if not is_instance_valid(self) or not is_inside_tree() or is_dead:
		return
	if gen == _action_gen or not is_dead:
		can_charge = true

func prep_spin_attack() -> void:
	var gen := _action_gen
	is_preparing_spin = true
	anim.play("idle")

	show_spin_warning = true
	queue_redraw()

	_start_flash_effect()
	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(self) or not is_inside_tree() or is_dead or gen != _action_gen:
		return

	show_spin_warning = false
	queue_redraw()

	if not is_preparing_spin:
		return

	is_preparing_spin = false
	perform_attack(3)

func perform_attack(type: int) -> void:
	var gen := _action_gen
	is_attacking = true
	var active_shape = null

	if type == 1:
		active_damage = base_damage * 2
		anim.play("attack_1")
		active_shape = shape_1
	elif type == 2:
		active_damage = base_damage
		anim.play("attack_2")
		active_shape = shape_2
	elif type == 3:
		active_damage = base_damage * 3
		anim.play("attack_3")
		active_shape = shape_3

	await get_tree().create_timer(0.3).timeout
	if not is_instance_valid(self) or not is_inside_tree() or not is_attacking or is_dead or gen != _action_gen:
		return

	if active_shape:
		active_shape.set_deferred("disabled", false)

	await get_tree().create_timer(0.2).timeout
	if not is_instance_valid(self) or not is_inside_tree() or is_dead or gen != _action_gen:
		return

	if active_shape:
		active_shape.set_deferred("disabled", true)
	if not is_attacking:
		return

	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(self) or not is_inside_tree() or is_dead or gen != _action_gen:
		return

	if not is_preparing_spin and not is_preparing_charge:
		is_attacking = false

func _start_flash_effect() -> void:
	if hit_flash_tween and hit_flash_tween.is_valid():
		hit_flash_tween.kill()
	if flash_tween and flash_tween.is_valid():
		flash_tween.kill()
	flash_tween = create_tween()
	flash_tween.set_loops(8)
	flash_tween.tween_property(anim, "modulate", Color(1, 0.2, 0.2), 0.125)
	flash_tween.tween_property(anim, "modulate", Color.WHITE, 0.125)

func take_damage(amount: int) -> void:
	if not is_active or is_dead:
		return

	if is_preparing_spin:
		print("[BOSS] Boss đang gồng! Bất tử, miễn nhiễm mọi sát thương!")
		return

	hp = max(0, hp - amount)
	if get_tree():
		get_tree().call_group("game_ui", "spawn_damage_number", global_position + Vector2(0, -30), amount, Color(1.0, 0.5, 0.2))

	if hp <= 0:
		boss_hp_changed.emit(0, max_hp, current_phase, BOSS_NAME)
		is_dead = true
		if get_node_or_null("/root/GameManager") != null:
			GameManager.register_enemy_kill(self, "orc_rider")
		_drop_boss_loot()
		_cancel_all_actions()
		$CollisionShape2D.set_deferred("disabled", true)
		if has_node("Hurtbox/CollisionShape2D"):
			$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
		anim.play("death")
		return

	var phased = check_phase()
	boss_hp_changed.emit(hp, max_hp, current_phase, BOSS_NAME)

	if phased:
		_cancel_all_actions()
		prep_spin_attack()
		return

	# Boss Super Armor (Poise): Light ranged attacks do not stun-lock boss movement
	if hit_flash_tween and hit_flash_tween.is_valid():
		hit_flash_tween.kill()
	hit_flash_tween = create_tween()
	hit_flash_tween.tween_property(anim, "modulate", Color(1.5, 0.4, 0.4), 0.08)
	hit_flash_tween.tween_property(anim, "modulate", Color.WHITE, 0.08)

func _drop_boss_loot() -> void:
	var floor_lvl := 1
	var seed_val := 12345
	if get_node_or_null("/root/GameManager") != null:
		floor_lvl = GameManager.current_level
		seed_val = (GameManager.current_seed + "_orcrider_loot_" + str(floor_lvl)).hash()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var boss_item: ItemData = ItemDatabase.get_random_drop(floor_lvl, true, rng)
	if boss_item != null:
		var item_scene = preload("res://Scene/Items/WorldItem/WorldItem.tscn")
		var item_drop = item_scene.instantiate()
		item_drop.item_data = boss_item
		var parent_node = get_parent() if get_parent() != null else get_tree().current_scene
		parent_node.call_deferred("add_child", item_drop)
		item_drop.set_deferred("global_position", global_position)

func check_phase() -> bool:
	if current_phase == 1 and hp <= max_hp * 0.66:
		current_phase = 2
		current_speed = base_speed + 40.0
		if hp <= max_hp * 0.33:
			current_phase = 3
			current_speed = base_speed + 70.0
		return true
	elif current_phase == 2 and hp <= max_hp * 0.33:
		current_phase = 3
		current_speed = base_speed + 70.0
		return true
	return false

func _cancel_all_actions() -> void:
	_action_gen += 1
	is_attacking = false
	is_preparing_charge = false
	is_charging = false
	is_preparing_spin = false
	show_charge_warning = false
	show_spin_warning = false
	queue_redraw()

	if flash_tween and flash_tween.is_valid():
		flash_tween.kill()
	if hit_flash_tween and hit_flash_tween.is_valid():
		hit_flash_tween.kill()
	anim.modulate = Color.WHITE
	_disable_all_hitboxes()
	velocity = Vector2.ZERO

func _on_animated_sprite_2d_animation_finished() -> void:
	if anim.animation == "hurt":
		is_hurt = false
		if not is_dead:
			anim.play("idle")
	elif anim.animation == "death":
		queue_free()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if is_dead or not is_active or not is_attacking:
		return
	if area.name == "PlayerHurtbox":
		var target = area.get_parent()
		if target == null or not is_instance_valid(target):
			return
		var tmap = get_parent()
		if tmap != null and tmap.has_method("has_line_of_sight") and not tmap.has_line_of_sight(global_position, target.global_position):
			return
		if target.has_method("take_damage"):
			FloorBalance.hit(target, active_damage, armor_piercing)

func _disable_all_hitboxes() -> void:
	shape_1.set_deferred("disabled", true)
	shape_2.set_deferred("disabled", true)
	shape_3.set_deferred("disabled", true)
