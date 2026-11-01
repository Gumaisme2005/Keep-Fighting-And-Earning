extends Area2D

@export var world_item_scene: PackedScene
@export var loot_table: Array[ItemData] = []
@export var drop_chance: float = 1.0
var loot_seed: int = 0

@onready var anim = $AnimatedSprite2D
var is_open = false

func _ready():
	anim.play("idle")

func _on_body_entered(body):
	if body.is_in_group("player") and not is_open:
		is_open = true
		if get_node_or_null("/root/AudioManager") != null:
			AudioManager.play_sfx("pickup", 0.90, 1.00)
		anim.play("open")
		$CollisionShape2D.set_deferred("disabled", true)
		spawn_loot()

func spawn_loot():
	if world_item_scene != null and loot_table.size() > 0:
		var rng := RandomNumberGenerator.new()
		if loot_seed != 0:
			rng.seed = loot_seed
		else:
			rng.seed = int(global_position.x * 73856093) ^ int(global_position.y * 19349663)

		if rng.randf() <= drop_chance:
			var random_item = loot_table[rng.randi() % loot_table.size()]
			var item_drop = world_item_scene.instantiate()
			item_drop.item_data = random_item
			item_drop.global_position = global_position + Vector2(0, 20)
			var parent_node = get_parent() if get_parent() != null else get_tree().current_scene
			parent_node.call_deferred("add_child", item_drop)
