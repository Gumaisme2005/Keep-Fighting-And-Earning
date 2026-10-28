extends CharacterBody2D

@export var speed: float = 100.0
@export var attack_range: float = 18.0
@export var world_item_scene: PackedScene = preload("res://Scene/Items/WorldItem/WorldItem.tscn")
@export var loot_table: Array[ItemData] = [
	preload("res://Scene/Items/health_potion.tres"),
	preload("res://Scene/Items/iron_sword.tres")
]
@export var drop_chance: float = 0.25
var loot_seed: int = 0

var hp: int = 2
var is_dead: bool = false
var is_attacking: bool = false
var is_active = false

@onready var animated_sprite = $AnimatedSprite2D
@onready var sword_hitbox = $SwordHitbox
@onready var sword_collision = $SwordHitbox/CollisionShape2D
var player: Node2D = null

func _ready() -> void:
	animated_sprite.play("idle")
	sword_collision.disabled = true
	sword_hitbox.position = Vector2(0, -6)
	sword_hitbox.scale = Vector2.ONE
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
	if is_dead or animated_sprite.animation == "hurt":
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
	var has_los: bool = (tmap == null or not tmap.has_method("has_line_of_sight") or tmap.has_line_of_sight(global_position, player.global_position))

	if distance <= attack_range and has_los:
		attack()
	else:
		var move_dir: Vector2 = tmap.get_smart_steer_direction(global_position, direction) if (tmap != null and tmap.has_method("get_smart_steer_direction")) else direction
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

func take_damage(damage_amount: int) -> void:
	if not is_active or is_dead:
		return

	hp -= damage_amount
	if get_tree():
		get_tree().call_group("game_ui", "spawn_damage_number", global_position + Vector2(0, -20), damage_amount, Color(1.0, 0.9, 0.3))
	if hp > 0:
		animated_sprite.play("hurt")
		is_attacking = false
		sword_collision.set_deferred("disabled", true)
	else:
		is_dead = true
		if get_node_or_null("/root/GameManager") != null:
			GameManager.register_enemy_kill()
		animated_sprite.play("death")
		$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
		$CollisionShape2D.set_deferred("disabled", true)
		sword_collision.set_deferred("disabled", true)

		await get_tree().create_timer(1.0).timeout
		drop_loot()
		queue_free()

func _on_animated_sprite_2d_animation_finished() -> void:
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
			target.take_damage(1)

func drop_loot() -> void:
	if world_item_scene != null and loot_table.size() > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = loot_seed if loot_seed != 0 else (int(global_position.x * 911) ^ int(global_position.y * 3571))
		if rng.randf() <= drop_chance:
			var random_item = loot_table[rng.randi() % loot_table.size()]
			var item_drop = world_item_scene.instantiate()
			item_drop.item_data = random_item
			item_drop.global_position = global_position
			var parent_node = get_parent() if get_parent() != null else get_tree().current_scene
			parent_node.call_deferred("add_child", item_drop)
