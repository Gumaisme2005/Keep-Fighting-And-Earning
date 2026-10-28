extends CharacterBody2D

signal boss_hp_changed(current_hp: int, max_hp: int, phase: int, boss_name: String)

const BOSS_NAME: String = "ORC RIDER — KỴ BINH HỦY DIỆT"

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

@onready var anim = $AnimatedSprite2D
@onready var shape_1 = $Hitbox/Shape1
@onready var shape_2 = $Hitbox/Shape2
@onready var shape_3 = $Hitbox/Shape3

var player: Node2D = null

func _ready() -> void:
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

func _physics_process(_delta: float) -> void:
	if not is_active or is_dead or is_hurt:
		return
	if player == null or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
		else:
			return

	var distance = global_position.distance_to(player.global_position)
	var direction = global_position.direction_to(player.global_position)

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

	if distance > 150.0 and can_charge:
		prep_charge()
	elif distance > 45.0:
		velocity = direction * current_speed
		anim.play("walk")
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		perform_attack(2)

func prep_charge() -> void:
	is_preparing_charge = true
	anim.play("idle")
	charge_dir = global_position.direction_to(player.global_position)

	show_charge_warning = true
	queue_redraw()

	_start_flash_effect()
	await get_tree().create_timer(2.0).timeout

	show_charge_warning = false
	queue_redraw()

	if not is_preparing_charge or is_dead:
		return

	is_preparing_charge = false
	start_charge()

func start_charge() -> void:
	is_charging = true
	anim.play("walk")

	await get_tree().create_timer(1.2).timeout
	if is_charging:
		_stop_charge()

func _stop_charge() -> void:
	if not is_charging:
		return
	is_charging = false
	velocity = Vector2.ZERO

	if not is_dead and not is_hurt and not is_preparing_spin:
		perform_attack(1)

	can_charge = false
	await get_tree().create_timer(5.0).timeout
	can_charge = true

func prep_spin_attack() -> void:
	is_preparing_spin = true
	anim.play("idle")

	show_spin_warning = true
	queue_redraw()

	_start_flash_effect()
	await get_tree().create_timer(2.0).timeout

	show_spin_warning = false
	queue_redraw()

	if not is_preparing_spin or is_dead:
		return

	is_preparing_spin = false
	perform_attack(3)

func perform_attack(type: int) -> void:
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
	if not is_attacking or is_dead:
		return

	if active_shape:
		active_shape.set_deferred("disabled", false)

	await get_tree().create_timer(0.2).timeout

	if active_shape:
		active_shape.set_deferred("disabled", true)
	if not is_attacking or is_dead:
		return

	await get_tree().create_timer(0.6).timeout

	if not is_preparing_spin and not is_preparing_charge:
		is_attacking = false

func _start_flash_effect() -> void:
	if flash_tween:
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
	var phased = check_phase()
	boss_hp_changed.emit(hp, max_hp, current_phase, BOSS_NAME)

	if hp <= 0:
		is_dead = true
		if get_node_or_null("/root/GameManager") != null:
			GameManager.register_enemy_kill()
		_cancel_all_actions()
		$CollisionShape2D.set_deferred("disabled", true)
		if has_node("Hurtbox/CollisionShape2D"):
			$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
		anim.play("death")
		return

	if phased:
		_cancel_all_actions()
		prep_spin_attack()
		return

	if is_preparing_charge or is_charging or is_attacking:
		return

	_cancel_all_actions()
	is_hurt = true
	anim.play("hurt")

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
	is_attacking = false
	is_preparing_charge = false
	is_charging = false
	is_preparing_spin = false
	show_charge_warning = false
	show_spin_warning = false
	queue_redraw()

	if flash_tween:
		flash_tween.kill()
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
	if area.name == "PlayerHurtbox":
		var target = area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(active_damage)

func _disable_all_hitboxes() -> void:
	shape_1.set_deferred("disabled", true)
	shape_2.set_deferred("disabled", true)
	shape_3.set_deferred("disabled", true)
