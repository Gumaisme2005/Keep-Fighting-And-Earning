extends BaseEnemy

const TacticalController = preload("res://Scene/Enemies/AI/OrcTacticalController.gd")
const NavigationCache = preload("res://Scene/Enemies/AI/TacticalNavigationCache.gd")
var _tactical_ai: TacticalController
var _navigation: NavigationCache

@onready var axe_hitbox = $AxeHitbox
@onready var axe_collision = $AxeHitbox/CollisionShape2D


func _ready() -> void:
	enemy_balance_id = "orc"
	super._ready()
	axe_collision.disabled = true
	axe_hitbox.position = Vector2(0, -7)
	axe_hitbox.scale = Vector2.ONE
	_tactical_ai = TacticalController.new(self)
	_navigation = NavigationCache.new(self)


func _physics_process(_delta: float) -> void:
	_tactical_ai.advance_tick()
	if not is_active or is_dead or animated_sprite.animation == &"hurt":
		_navigation.invalidate()
		return
	if not is_instance_valid(player) or player.is_queued_for_deletion():
		_find_player()
		if player == null:
			_navigation.invalidate()
			return
	var distance := global_position.distance_to(player.global_position)
	var direction := global_position.direction_to(player.global_position)
	if direction.x < 0:
		animated_sprite.flip_h = true
	elif direction.x > 0:
		animated_sprite.flip_h = false
	if is_attacking:
		_navigation.invalidate()
		return
	if direction != Vector2.ZERO:
		axe_hitbox.rotation = direction.angle()
	var tmap = get_parent()
	var has_los := _navigation.observe_visibility(tmap)
	if distance <= attack_range and has_los:
		attack()
	else:
		var intent := _tactical_ai.get_movement_intent(tmap, direction, distance, has_los)
		velocity = _navigation.resolve(intent, tmap, _tactical_ai._tactic_tick) * speed
		move_and_slide()
		animated_sprite.play("walk")


func attack() -> void:
	is_attacking = true
	if is_instance_valid(player):
		var direction := global_position.direction_to(player.global_position)
		if direction != Vector2.ZERO:
			axe_hitbox.rotation = direction.angle()
	animated_sprite.play("attack")
	axe_collision.disabled = false


func _on_hurt() -> void:
	axe_collision.set_deferred("disabled", true)
	_navigation.invalidate()


func _die() -> void:
	super._die()
	axe_collision.set_deferred("disabled", true)
	_navigation.invalidate()


func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite == null:
		return
	if animated_sprite.animation == &"death":
		drop_loot()
		queue_free()
	elif animated_sprite.animation == &"hurt":
		if not is_dead:
			animated_sprite.play("idle")
	elif animated_sprite.animation == &"attack":
		is_attacking = false
		axe_collision.disabled = true
		animated_sprite.play("idle")


func _on_axe_hitbox_area_entered(area: Area2D) -> void:
	if not is_active or is_dead or not is_attacking or animated_sprite.animation == &"hurt":
		return
	if area.name != "PlayerHurtbox":
		return
	var target = area.get_parent()
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	if global_position.distance_to(target.global_position) > attack_range:
		return
	var tmap = get_parent()
	if tmap != null and tmap.has_method("has_line_of_sight") and not tmap.has_line_of_sight(global_position, target.global_position):
		return
	if target.has_method("take_damage"):
		FloorBalance.hit(target, damage, armor_piercing)
