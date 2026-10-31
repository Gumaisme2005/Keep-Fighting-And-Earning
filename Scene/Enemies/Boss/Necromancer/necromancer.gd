extends CharacterBody2D

signal boss_hp_changed(current_hp: int, max_hp: int, phase: int, boss_name: String)

const BalanceData = preload("res://Scene/BalanceConfig.gd")
const BOSS_NAME: String = "TỬ LINH PHÁP SƯ DOL GULDUR — HÓA THÂN SAURON"

@export var speed: float = 50.0
@export var melee_range: float = 60.0
@export var poison_range: float = 200.0
@export var attack_cooldown: float = 1.5
@export var summon_enemy_scene: PackedScene
@export var poison_explosion_scene: PackedScene

var max_hp: int = 30
var hp: int = 30
var melee_damage: int = 1
var poison_damage: int = 2
var current_phase: int = 1

var is_dead: bool = false
var is_attacking: bool = false
var is_casting_special: bool = false
var is_active = false
var can_attack: bool = true

var phase_2_triggered: bool = false
var phase_3_triggered: bool = false
var summoned_minions: Array = []
var rng := RandomNumberGenerator.new()

@onready var anim = $AnimatedSprite2D
@onready var scythe_hitbox = $ScytheHitbox
@onready var scythe_collision = $ScytheHitbox/CollisionShape2D

var player: Node2D = null

func _ready() -> void:
	var cfg: Dictionary = BalanceData.get_boss_stats("necromancer")
	max_hp = int(cfg.get("hp", max_hp))
	hp = max_hp
	speed = float(cfg.get("speed", speed))
	melee_damage = int(cfg.get("melee_damage", melee_damage))
	poison_damage = int(cfg.get("poison_damage", poison_damage))
	melee_range = float(cfg.get("melee_range", melee_range))
	poison_range = float(cfg.get("poison_range", poison_range))
	attack_cooldown = float(cfg.get("attack_cooldown", attack_cooldown))
	if get_node_or_null("/root/GameManager") != null:
		rng.seed = (GameManager.current_seed + "_necro").hash()
	else:
		rng.seed = 123456
	anim.play("idle")
	scythe_collision.disabled = true
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(_delta: float) -> void:
	if not is_active:
		return
	if player == null or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
		else:
			return
	if is_dead or anim.animation == "hurt" or is_casting_special:
		return

	var distance = global_position.distance_to(player.global_position)
	var direction = global_position.direction_to(player.global_position)

	if direction.x < 0:
		anim.flip_h = true
		scythe_hitbox.scale.x = -1
	else:
		anim.flip_h = false
		scythe_hitbox.scale.x = 1

	if is_attacking:
		return

	if distance <= melee_range:
		if can_attack:
			attack_melee()
		else:
			velocity = Vector2.ZERO
			anim.play("idle")
	elif distance <= poison_range:
		if can_attack:
			attack_poison()
		else:
			velocity = Vector2.ZERO
			anim.play("idle")
	else:
		velocity = direction * speed
		move_and_slide()
		anim.play("walk")

func attack_melee():
	is_attacking = true
	can_attack = false
	anim.play("attack_1")
	scythe_collision.disabled = false

func attack_poison():
	is_attacking = true
	can_attack = false
	velocity = Vector2.ZERO
	anim.play("attack_2")

	if is_instance_valid(player) and poison_explosion_scene != null:
		var target_pos = player.global_position
		var explosion = poison_explosion_scene.instantiate()
		explosion.damage = poison_damage
		get_parent().call_deferred("add_child", explosion)
		explosion.global_position = target_pos

func take_damage(damage_amount: int) -> void:
	if not is_active or is_dead or is_casting_special:
		return

	hp = max(0, hp - damage_amount)
	if get_tree():
		get_tree().call_group("game_ui", "spawn_damage_number", global_position + Vector2(0, -30), damage_amount, Color(1.0, 0.4, 0.9))

	if hp <= max_hp / 3.0 and not phase_3_triggered and hp > 0:
		phase_3_triggered = true
		phase_2_triggered = true
		current_phase = 3
		attack_cooldown *= 0.6
		melee_damage += 1
		poison_damage += 1
		boss_hp_changed.emit(hp, max_hp, current_phase, BOSS_NAME)
		cast_summon_skill()
		return

	if hp <= (max_hp * 2.0) / 3.0 and not phase_2_triggered and hp > 0:
		phase_2_triggered = true
		current_phase = 2
		melee_damage += 1
		poison_damage += 1
		boss_hp_changed.emit(hp, max_hp, current_phase, BOSS_NAME)
		cast_summon_skill()
		return

	boss_hp_changed.emit(hp, max_hp, current_phase, BOSS_NAME)

	if hp > 0:
		anim.play("hurt")
		is_attacking = false
		scythe_collision.set_deferred("disabled", true)
	else:
		is_dead = true
		if get_node_or_null("/root/GameManager") != null:
			GameManager.register_enemy_kill()
		_cleanup_summoned_minions()
		anim.modulate = Color.WHITE
		anim.play("death")
		$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
		$CollisionShape2D.set_deferred("disabled", true)
		scythe_collision.set_deferred("disabled", true)

func _cleanup_summoned_minions() -> void:
	for minion in summoned_minions:
		if is_instance_valid(minion) and not minion.is_queued_for_deletion():
			minion.queue_free()
	summoned_minions.clear()

func cast_summon_skill():
	is_casting_special = true
	is_attacking = false
	velocity = Vector2.ZERO
	anim.play("summon")
	scythe_collision.set_deferred("disabled", true)

	var tween = create_tween()
	tween.set_loops(8)
	tween.tween_property(anim, "modulate", Color(1, 0.2, 0.2), 0.125)
	tween.tween_property(anim, "modulate", Color.WHITE, 0.125)

	await get_tree().create_timer(2.0).timeout

	if is_dead:
		tween.kill()
		return

	if summon_enemy_scene != null:
		var num_mobs = rng.randi_range(4, 6)
		for i in range(num_mobs):
			var minion = summon_enemy_scene.instantiate()
			get_parent().call_deferred("add_child", minion)
			var angle = i * (TAU / num_mobs)
			var spawn_offset = Vector2(cos(angle), sin(angle)) * 55.0
			minion.global_position = global_position + spawn_offset
			summoned_minions.append(minion)

			get_tree().create_timer(0.1).timeout.connect(func():
				if is_instance_valid(minion) and not is_dead:
					minion.is_active = true
			)

	if poison_explosion_scene != null:
		for i in range(8):
			var explosion = poison_explosion_scene.instantiate()
			explosion.damage = poison_damage
			get_parent().call_deferred("add_child", explosion)

			var angle = i * (PI / 4.0)
			var explosion_offset = Vector2(cos(angle), sin(angle)) * 100.0
			explosion.global_position = global_position + explosion_offset

	await get_tree().create_timer(0.5).timeout

	is_casting_special = false
	can_attack = true
	if not is_dead:
		anim.play("idle")

func _on_animated_sprite_2d_animation_finished() -> void:
	if anim.animation == "death":
		queue_free()
	elif anim.animation == "hurt":
		if not is_dead and not is_casting_special:
			anim.play("idle")
			can_attack = true
	elif anim.animation in ["attack_1", "attack_2"]:
		is_attacking = false
		scythe_collision.disabled = true
		anim.play("idle")
		start_cooldown()

func start_cooldown():
	await get_tree().create_timer(attack_cooldown).timeout
	if not is_dead and not is_casting_special:
		can_attack = true

func _on_scythe_hitbox_area_entered(area: Area2D) -> void:
	if area.name == "PlayerHurtbox":
		var target = area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(melee_damage)
