extends "res://Scene/Character/Player 1_Pyrois/player.gd"

@export var q_skill_cooldown: float = 3.0
@export var right_click_cooldown: float = 5.0

var can_use_q: bool = true
var can_use_right_click: bool = true

func _ready() -> void:
	speed = 180.0
	base_max_hp = 5
	base_armor = 0
	base_damage = 2
	skill_cooldown = q_skill_cooldown
	rmb_cd_max = right_click_cooldown
	super._ready()

func use_special_skill() -> void:
	if can_use_q and not is_dead and not is_hurt and not is_casting_skill and not is_attacking:
		perform_attack_2()

func _on_rmb_skill_triggered() -> void:
	if can_use_right_click and not is_dead and not is_hurt and not is_casting_skill and not is_attacking:
		perform_attack_3()

func _input(event: InputEvent) -> void:
	if is_dead or is_hurt or is_casting_skill or is_attacking:
		return
	if get_node_or_null("/root/GameManager") != null and GameManager.is_replaying:
		return

	if event.is_action_pressed("skill_1") and can_use_q:
		get_viewport().set_input_as_handled()
		pending_q_skill = true
	elif event.is_action_pressed("skill_2") and can_use_right_click:
		get_viewport().set_input_as_handled()
		pending_rmb_skill = true

func perform_attack_2():
	can_use_q = false
	can_use_skill = false
	q_cd_remaining = q_skill_cooldown
	skill_cooldown_changed.emit(q_cd_remaining, q_skill_cooldown, rmb_cd_remaining, right_click_cooldown)
	is_casting_skill = true
	velocity = Vector2.ZERO

	animated_sprite.play("attack_2")

	for i in range(3):
		if is_dead or is_hurt:
			break

		sword_collision.set_deferred("disabled", false)
		await get_tree().create_timer(0.1).timeout

		if is_dead or is_hurt:
			sword_collision.set_deferred("disabled", true)
			break

		sword_collision.set_deferred("disabled", true)
		await get_tree().create_timer(0.2).timeout

	_cleanup_skill("attack_2")
	start_cooldown("q")

func perform_attack_3():
	can_use_right_click = false
	rmb_cd_remaining = right_click_cooldown
	skill_cooldown_changed.emit(q_cd_remaining, q_skill_cooldown, rmb_cd_remaining, right_click_cooldown)
	is_casting_skill = true
	is_invincible = true
	animated_sprite.modulate = Color(1.5, 1.5, 2.0)

	animated_sprite.play("attack_3")

	var face_direction = -1 if animated_sprite.flip_h else 1
	velocity.x = face_direction * 400.0
	await get_tree().create_timer(0.10).timeout

	if is_dead:
		is_invincible = false
		animated_sprite.modulate = Color.WHITE
		return

	velocity = Vector2.ZERO

	for i in range(4):
		if is_dead:
			break

		sword_collision.set_deferred("disabled", false)
		await get_tree().create_timer(0.1).timeout

		if is_dead:
			sword_collision.set_deferred("disabled", true)
			break

		sword_collision.set_deferred("disabled", true)
		await get_tree().create_timer(0.15).timeout

	is_invincible = false
	animated_sprite.modulate = Color.WHITE

	_cleanup_skill("attack_3")
	start_cooldown("right_click")

func _cleanup_skill(anim_name: String) -> void:
	if not is_dead and not is_hurt:
		velocity = Vector2.ZERO
		sword_collision.set_deferred("disabled", true)
		is_casting_skill = false

		if animated_sprite.animation == anim_name:
			animated_sprite.play("idle")

func start_cooldown(skill: String) -> void:
	if skill == "q":
		await get_tree().create_timer(q_skill_cooldown).timeout
		can_use_q = true
		can_use_skill = true
		q_cd_remaining = 0.0
		skill_cooldown_changed.emit(0.0, q_skill_cooldown, rmb_cd_remaining, right_click_cooldown)
	elif skill == "right_click":
		await get_tree().create_timer(right_click_cooldown).timeout
		can_use_right_click = true
		rmb_cd_remaining = 0.0
		skill_cooldown_changed.emit(q_cd_remaining, q_skill_cooldown, 0.0, right_click_cooldown)
