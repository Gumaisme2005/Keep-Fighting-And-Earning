extends CharacterBody2D
class_name BaseEnemy

## BaseEnemy — Lớp cơ sở trừu tượng cho tất cả quái vật thường trong trò chơi.
## Quản lý chỉ số cơ bản, vòng đời nhận sát thương/chết, rơi đồ ngẫu nhiên theo hạt giống,
## và bộ đệm điều hướng AI (Throttled Raycast Steer).

const BalanceData = preload("res://Scene/BalanceConfig.gd")

# --- CHỈ SỐ CƠ BẢN (DATA-DRIVEN) ---
@export var damage: int = 1
@export var speed: float = 70.0
@export var attack_range: float = 20.0
@export var world_item_scene: PackedScene
@export var loot_table: Array[ItemData] = []
@export var drop_chance: float = 0.3
var loot_seed: int = 0

var hp: int = 3
var max_hp: int = 3
var is_dead: bool = false
var is_attacking: bool = false
var is_active: bool = false

# --- THÔNG TIN ĐIỀU HƯỚNG AI & TIẾT KIỆM TÍNH TOÁN RAYCAST ---
var _ai_tick_timer: float = 0.0
var _ai_tick_interval: float = 0.1 # Cập nhật tìm đường 10 lần/s thay vì 60 lần/s
var _cached_steer_dir: Vector2 = Vector2.ZERO
var _cached_has_los: bool = true

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
var player: Node2D = null

# ID định danh trong BalanceConfig (ví dụ: "orc", "skeleton", "vampire", etc.)
var enemy_balance_id: String = ""

func _ready() -> void:
	if not enemy_balance_id.is_empty():
		_apply_balance_stats()
	if animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")
	# Khởi tạo độ trễ AI timer một cách tất định (deterministic) để không làm lệch global RNG của replay stream:
	var seed_val: int = loot_seed if loot_seed != 0 else (int(abs(global_position.x * 73856093)) ^ int(abs(global_position.y * 19349663)))
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed_val
	_ai_tick_timer = local_rng.randf_range(0.0, _ai_tick_interval)
	_find_player()

func _apply_balance_stats() -> void:
	var cfg: Dictionary = BalanceData.get_enemy_stats(enemy_balance_id)
	if not cfg.is_empty():
		hp = int(cfg.get("hp", hp))
		max_hp = hp
		damage = int(cfg.get("damage", damage))
		speed = float(cfg.get("speed", speed))
		attack_range = float(cfg.get("attack_range", attack_range))
		drop_chance = float(cfg.get("drop_chance", drop_chance))

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			player = p
			return

func _spawn_damage_popup(amount: int, color: Color = Color(1.0, 0.9, 0.3)) -> void:
	if get_tree():
		get_tree().call_group("game_ui", "spawn_damage_number", global_position + Vector2(0, -20), amount, color)

func take_damage(damage_amount: int) -> void:
	if not is_active or is_dead:
		return

	hp -= damage_amount
	_spawn_damage_popup(damage_amount)
	if hp > 0:
		if animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("hurt"):
			animated_sprite.play("hurt")
		is_attacking = false
		_on_hurt()
	else:
		_die()

func _on_hurt() -> void:
	# Virtual callback - để lớp con ghi đè tắt hitbox hoặc ngắt chiêu nếu cần
	pass

func _die() -> void:
	is_dead = true
	var gm = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("register_enemy_kill"):
		gm.register_enemy_kill()
	if animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
	_disable_all_collisions()

func _disable_all_collisions() -> void:
	var hurtbox_col = get_node_or_null("Hurtbox/CollisionShape2D")
	if hurtbox_col != null:
		hurtbox_col.set_deferred("disabled", true)
	var main_col = get_node_or_null("CollisionShape2D")
	if main_col != null:
		main_col.set_deferred("disabled", true)

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
			if parent_node != null:
				parent_node.call_deferred("add_child", item_drop)
