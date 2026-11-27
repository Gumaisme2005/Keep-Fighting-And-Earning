extends BasePlayer

## Player (Pyrois) — Chiến binh Lửa (Hero #1).
## Kế thừa toàn bộ chỉ số, balo, hồi giáp, perks và record/replay từ BasePlayer.
## Quản lý hitbox kiếm (SwordHitbox), chiêu thức chém thường (attack_1) và lướt chém đặc biệt (attack_2).

@onready var sword_hitbox: Area2D = get_node_or_null("SwordHitbox")
@onready var sword_collision: CollisionShape2D = get_node_or_null("SwordHitbox/CollisionShape2D")
var base_attack_cooldown: float = 0.32

func _ready() -> void:
	if hero_balance_id.is_empty():
		hero_balance_id = "pyrois"
	super._ready()
	var cfg: Dictionary = BalanceData.get_hero_stats(hero_balance_id)
	base_attack_cooldown = float(cfg.get("attack_cooldown", base_attack_cooldown))
	if sword_collision != null:
		sword_collision.disabled = true

func _update_aim_direction(aim_pos: Vector2) -> void:
	if sword_hitbox != null:
		if aim_pos.x < global_position.x:
			sword_hitbox.scale.x = -1
		else:
			sword_hitbox.scale.x = 1

func _on_attack_timer_expired() -> void:
	if animated_sprite != null:
		animated_sprite.speed_scale = 1.0
	if sword_collision != null:
		sword_collision.set_deferred("disabled", true)

func attack() -> void:
	training_action(&"basic")
	is_attacking = true
	_attack_timer = get_effective_attack_cooldown(base_attack_cooldown)
	if animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("attack_1"):
		animated_sprite.speed_scale = get_attack_speed_scale()
		animated_sprite.play("attack_1")
	if sword_collision != null:
		sword_collision.disabled = false
	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_sfx("slash")

func use_special_skill() -> void:
	training_action(&"skill")
	start_skill_cooldown()
	is_casting_skill = true
	set_skill_invincible(true)
	if animated_sprite != null:
		animated_sprite.speed_scale = 1.0
		animated_sprite.modulate = Color(1.5, 1.5, 2.0)

	var face_direction = -1 if (animated_sprite != null and animated_sprite.flip_h) else 1
	velocity = Vector2(face_direction * 150.0, 0.0)

	if animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("attack_2"):
		animated_sprite.play("attack_2")

	await get_tree().create_timer(0.3, true, is_training()).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return

	velocity = Vector2.ZERO
	if sword_collision != null:
		sword_collision.set_deferred("disabled", false)

	await get_tree().create_timer(0.2, true, is_training()).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return

	if sword_collision != null:
		sword_collision.set_deferred("disabled", true)
	is_casting_skill = false
	set_skill_invincible(false)
	if animated_sprite != null:
		animated_sprite.modulate = Color.WHITE

	if not is_dead and not is_hurt and animated_sprite != null and animated_sprite.animation == "attack_2":
		animated_sprite.play("idle")

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite == null:
		return
	var current_anim = animated_sprite.animation

	if current_anim == "attack_1":
		is_attacking = false
		animated_sprite.speed_scale = 1.0
		if sword_collision != null:
			sword_collision.set_deferred("disabled", true)
		if not is_dead and not is_hurt:
			animated_sprite.play("idle")

	elif current_anim == "hurt":
		is_hurt = false
		is_attacking = false
		is_casting_skill = false
		animated_sprite.speed_scale = 1.0
		if sword_collision != null:
			sword_collision.set_deferred("disabled", true)
		if not is_dead:
			animated_sprite.play("idle")

func _on_sword_hitbox_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if area.name == "Hurtbox":
		var target = area.get_parent()
		if target == null:
			return
		if not target.has_method("take_damage") and target.get_parent() != null:
			target = target.get_parent()

		if target != null and target.has_method("take_damage") and target.get("is_dead") != true:
			# Chặn tuyệt đối đánh xuyên tường, cột đá hoặc cửa đang đóng
			var tmap = get_parent()
			if tmap != null and tmap.has_method("has_line_of_sight"):
				if not tmap.has_line_of_sight(global_position, target.global_position):
					return

			if target.has_method("receive_training_contact"):
				target.receive_training_contact(self, get_total_damage())
				return
			var total_dmg = get_total_damage()
			if hero_balance_id == "pyrois" and animated_sprite != null and animated_sprite.animation == "attack_2":
				total_dmg += 2
			total_dmg = apply_on_hit_effects(target, total_dmg)
			if is_instance_valid(target) and target.get("is_dead") != true:
				target.take_damage(total_dmg)
