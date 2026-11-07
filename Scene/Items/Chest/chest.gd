extends Area2D

@export var world_item_scene: PackedScene
@export var loot_table: Array[ItemData] = []
@export var drop_chance: float = 1.0
var loot_seed: int = 0
var is_boss_chest: bool = false # Đánh dấu rương báu phòng Boss

@onready var anim = $AnimatedSprite2D
var is_open = false

func _ready():
	anim.play("idle")
	if is_boss_chest:
		# Hiệu ứng rực sáng hoàng kim cho rương Boss
		modulate = Color(1.3, 1.2, 0.75)

func _on_body_entered(body):
	if body.is_in_group("player") and not is_open:
		is_open = true
		if get_node_or_null("/root/AudioManager") != null:
			AudioManager.play_sfx("pickup", 0.90, 1.00)
		anim.play("open")
		$CollisionShape2D.set_deferred("disabled", true)
		spawn_loot()

func spawn_loot():
	var item_scene = world_item_scene if world_item_scene != null else preload("res://Scene/Items/WorldItem/WorldItem.tscn")
	var rng := RandomNumberGenerator.new()
	if loot_seed != 0:
		rng.seed = loot_seed
	else:
		rng.seed = int(global_position.x * 73856093) ^ int(global_position.y * 19349663)

	if rng.randf() <= drop_chance:
		var floor_lvl := 1
		if get_node_or_null("/root/GameManager") != null:
			floor_lvl = GameManager.current_level

		var num_drops := 2 if is_boss_chest else 1
		var spread_offsets := [Vector2(-14, 20), Vector2(14, 20)]

		for i in range(num_drops):
			var dropped_item: ItemData = null
			if is_boss_chest or loot_table.is_empty():
				dropped_item = ItemDatabase.get_random_drop(floor_lvl, is_boss_chest, rng)
			else:
				dropped_item = loot_table[rng.randi() % loot_table.size()]

			if dropped_item != null:
				var item_drop = item_scene.instantiate()
				item_drop.item_data = dropped_item
				var offset: Vector2 = spread_offsets[i % spread_offsets.size()] if num_drops > 1 else Vector2(0, 20)
				item_drop.global_position = global_position + offset
				var parent_node = get_parent() if get_parent() != null else get_tree().current_scene
				parent_node.call_deferred("add_child", item_drop)
