extends BaseEnemy

const TacticalController = preload("res://Scene/Enemies/AI/ArcherTacticalController.gd")
const NavigationCache = preload("res://Scene/Enemies/AI/TacticalNavigationCache.gd")
@export var retreat_range: float = 85.0
@export var attack_cooldown: float = 2.0
@export var arrow_scene: PackedScene

var is_hurt: bool = false
var can_attack: bool = true
var strafe_sign: float = 1.0
var strafe_timer: float = 0.0
var _tactical_ai: TacticalController
var _navigation: NavigationCache
var _attack_generation: int = 0
var _shot_cancelled: bool = false
var _cached_retreat_dir: Vector2 = Vector2.ZERO
var _cached_strafe_dir: Vector2 = Vector2.ZERO
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _init() -> void:
	loot_table = [
		preload("res://Scene/Items/Common/health_potion.tres"),
		preload("res://Scene/Items/Common/iron_helmet.tres")
	]
	drop_chance = 0.35


func _ready() -> void:
	enemy_balance_id = "skeleton_archer"
	super._ready()
	var cfg: Dictionary = BalanceData.get_enemy_stats("skeleton_archer")
	retreat_range = float(cfg.get("retreat_range", retreat_range))
	attack_cooldown = float(cfg.get("attack_cooldown", attack_cooldown))
	strafe_sign = -1.0 if loot_seed % 2 == 0 else 1.0
	if anim != null:
		anim.play("summon")
	_tactical_ai = TacticalController.new(self)
	_navigation = NavigationCache.new(self)


func _physics_process(delta: float) -> void:
	_tactical_ai.advance_tick()
	if not is_active:
		_shot_cancelled = true
	if not is_active or is_dead or is_hurt or is_attacking:
		_navigation.invalidate()
		return
	if not is_instance_valid(player) or player.is_queued_for_deletion():
		_find_player()
		if player == null:
			_navigation.invalidate()
			return
	var distance := global_position.distance_to(player.global_position)
	var direction := global_position.direction_to(player.global_position)
	var tmap = get_parent()
	var has_los := _navigation.observe_visibility(tmap)
	var intent := _tactical_ai.get_movement_intent(tmap, direction, distance, has_los, delta)
	anim.flip_h = intent.facing_direction.x < 0
	if intent.mode == &"attack":
		velocity = Vector2.ZERO
		_start_attack()
		return
	var move_dir := _navigation.resolve(intent, tmap, _tactical_ai._tactic_tick)
	match intent.mode:
		&"retreat": _cached_retreat_dir = move_dir
		&"strafe": _cached_strafe_dir = move_dir
	velocity = move_dir * (speed * intent.speed_scale)
	anim.play("walk")
	if intent.mode == &"retreat":
		anim.flip_h = velocity.x < 0
	move_and_slide()
	if intent.mode == &"strafe":
		_tactical_ai.report_movement_collision(get_slide_collision_count() > 0)


func _attack_is_current(generation: int) -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and not is_dead and generation == _attack_generation


func _can_shoot_target(target) -> bool:
	if not is_inside_tree() or is_queued_for_deletion() or not is_active or is_dead or is_hurt:
		return false
	if not is_instance_valid(target) or target.is_queued_for_deletion() or not target.is_inside_tree() or target != player:
		return false
	if global_position.distance_to(target.global_position) > attack_range:
		return false
	var map = get_parent()
	return map == null or not map.has_method("has_line_of_sight") or map.has_line_of_sight(global_position, target.global_position)


func attack() -> void:
	if not _can_shoot_target(player):
		return
	_start_attack()


## Physics already supplied a current LOS observation. Public attack() checks
## independently; this entry avoids repeating that same ray within the tick.
func _start_attack() -> void:
	if not can_attack or is_attacking or not is_active or is_hurt or is_dead:
		return
	_attack_generation += 1
	var generation := _attack_generation
	var target = player
	_shot_cancelled = false
	is_attacking = true
	can_attack = false
	anim.play("attack")
	await get_tree().create_timer(0.4).timeout
	if not _attack_is_current(generation):
		return
	if not _shot_cancelled and is_attacking and _can_shoot_target(target) and arrow_scene != null:
		_spawn_arrow()
	await get_tree().create_timer(0.35).timeout
	if not _attack_is_current(generation):
		return
	if is_attacking:
		is_attacking = false
		if not is_hurt:
			anim.play("idle")
	await get_tree().create_timer(maxf(0.1, attack_cooldown - 0.75)).timeout
	if not _attack_is_current(generation):
		return
	can_attack = true


func shoot_arrow() -> void:
	if arrow_scene == null or get_parent() == null or not _can_shoot_target(player):
		return
	_spawn_arrow()


func _spawn_arrow() -> void:
	var arrow = arrow_scene.instantiate()
	var shoot_dir := global_position.direction_to(player.global_position).normalized()
	if shoot_dir == Vector2.ZERO:
		shoot_dir = Vector2.RIGHT
	var spawn_pos := global_position + shoot_dir * 6.0
	if get_parent() is Node2D:
		arrow.position = (get_parent() as Node2D).to_local(spawn_pos)
	arrow.direction = shoot_dir
	arrow.rotation = shoot_dir.angle()
	arrow.damage = damage
	get_parent().add_child(arrow)
	arrow.global_position = spawn_pos


func _on_hurt() -> void:
	is_hurt = true
	_shot_cancelled = true
	_navigation.invalidate()


func _die() -> void:
	_shot_cancelled = true
	super._die()
	_navigation.invalidate()


func _exit_tree() -> void:
	_attack_generation += 1
	_shot_cancelled = true
	is_attacking = false
	can_attack = false


func _on_animated_sprite_2d_animation_finished() -> void:
	var current = anim.animation
	if current == &"death":
		drop_loot()
		queue_free()
	elif current == &"hurt":
		is_hurt = false
		if not is_dead:
			anim.play("idle")
	elif current == &"attack":
		is_attacking = false
		if not is_dead and not is_hurt:
			anim.play("idle")
	elif current == &"summon":
		anim.play("idle")
