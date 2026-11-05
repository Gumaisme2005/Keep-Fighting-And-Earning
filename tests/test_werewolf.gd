extends Node

const WEREWOLF_SCENE = preload("res://scenes/enemies/werewolf/werewolf.tscn")
const BalanceConfig = preload("res://scripts/core/balance_config.gd")

var tests_passed: int = 0
var tests_failed: int = 0

func assert_test(condition: bool, test_name: String) -> void:
	if condition:
		print("  [PASS] ", test_name)
		tests_passed += 1
	else:
		printerr("  [FAIL] ", test_name)
		tests_failed += 1

func _ready() -> void:
	print("\n========================================================")
	print("  RUNNING WEREWOLF FUNCTIONAL & INTEGRATION TESTS")
	print("========================================================\n")

	test_config_and_stats()
	test_nodes_and_animations()
	test_claw_attack()
	test_pounce_windup_and_warning()
	test_windup_interrupt()
	test_pounce_distance_bounding()
	await test_damage_and_death_flow()
	test_dungeon_generator_integration()

	print("\n========================================================")
	print("  TEST RESULTS: ", tests_passed, " PASSED, ", tests_failed, " FAILED")
	print("========================================================\n")

	if tests_failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func test_config_and_stats() -> void:
	print("--- Test Group 1: Configuration & Stats ---")
	var stats = BalanceConfig.get_enemy_stats("werewolf")
	assert_test(not stats.is_empty(), "BalanceConfig has 'werewolf' entry")
	assert_test(stats.get("hp", 0) == 5, "HP is configured to 5")
	assert_test(stats.get("damage", 0) == 2, "Claw damage is configured to 2")
	assert_test(stats.get("pounce_damage", 0) == 3, "Pounce damage is configured to 3")
	assert_test(stats.get("pounce_speed", 0.0) == 175.0, "Pounce speed is configured to 175.0")
	assert_test(stats.get("pounce_distance", 0.0) == 95.0, "Pounce distance is configured to 95.0")
	assert_test(stats.get("pounce_windup_time", 0.0) == 0.65, "Pounce windup time is configured to 0.65")

	var wolf = WEREWOLF_SCENE.instantiate()
	add_child(wolf)
	assert_test(wolf.hp == 5, "Instance loaded hp = 5 from BalanceConfig")
	assert_test(wolf.damage == 2, "Instance loaded damage = 2")
	assert_test(wolf.pounce_damage == 3, "Instance loaded pounce_damage = 3")
	assert_test(wolf.pounce_speed == 175.0, "Instance loaded pounce_speed = 175.0")
	assert_test(wolf.pounce_distance == 95.0, "Instance loaded pounce_distance = 95.0")
	wolf.queue_free()

func test_nodes_and_animations() -> void:
	print("\n--- Test Group 2: Nodes & Animations ---")
	var wolf = WEREWOLF_SCENE.instantiate()
	add_child(wolf)

	var sprite: AnimatedSprite2D = wolf.get_node_or_null("AnimatedSprite2D")
	assert_test(sprite != null, "AnimatedSprite2D node exists")
	assert_test(sprite.sprite_frames != null, "SpriteFrames resource is assigned")

	var anims = sprite.sprite_frames.get_animation_names()
	assert_test(anims.has("idle"), "Has 'idle' animation")
	assert_test(anims.has("walk"), "Has 'walk' animation")
	assert_test(anims.has("attack_1"), "Has 'attack_1' animation")
	assert_test(anims.has("attack_2"), "Has 'attack_2' animation")
	assert_test(anims.has("hurt"), "Has 'hurt' animation")
	assert_test(anims.has("death"), "Has 'death' animation")

	var hurtbox = wolf.get_node_or_null("Hurtbox")
	var claw_hitbox = wolf.get_node_or_null("ClawHitbox")
	var pounce_hitbox = wolf.get_node_or_null("PounceHitbox")
	assert_test(hurtbox != null and hurtbox.name == "Hurtbox", "Hurtbox exists with exact name 'Hurtbox'")
	assert_test(claw_hitbox != null, "ClawHitbox exists")
	assert_test(pounce_hitbox != null, "PounceHitbox exists")

	var claw_col = claw_hitbox.get_node("CollisionShape2D")
	var pounce_col = pounce_hitbox.get_node("CollisionShape2D")
	assert_test(claw_col.disabled == true, "ClawHitbox is initially disabled")
	assert_test(pounce_col.disabled == true, "PounceHitbox is initially disabled")

	wolf.queue_free()

func test_claw_attack() -> void:
	print("\n--- Test Group 3: Claw Attack (Attack01) ---")
	var wolf = WEREWOLF_SCENE.instantiate()
	add_child(wolf)

	# Mock player
	var mock_player = Node2D.new()
	mock_player.name = "MockPlayer"
	mock_player.add_to_group("player")
	mock_player.global_position = wolf.global_position + Vector2(15, 0) # Cự ly 15px <= attack_range 24px
	add_child(mock_player)

	wolf.is_active = true
	wolf._physics_process(0.016)

	assert_test(wolf.is_attacking == true, "Wolf enters attacking state in close range")
	assert_test(wolf.animated_sprite.animation == "attack_1", "Wolf plays 'attack_1' animation")
	assert_test(wolf.claw_collision.disabled == false, "ClawHitbox collision is enabled during attack")

	# Giả lập kết thúc animation attack_1
	wolf._on_animated_sprite_2d_animation_finished()
	assert_test(wolf.is_attacking == false, "Attack state resets after animation finishes")
	assert_test(wolf.claw_collision.disabled == true, "ClawHitbox collision is disabled after attack")

	mock_player.queue_free()
	wolf.queue_free()

func test_pounce_windup_and_warning() -> void:
	print("\n--- Test Group 4: Pounce Windup & Warning Telegraph ---")
	var wolf = WEREWOLF_SCENE.instantiate()
	add_child(wolf)

	var dir = Vector2(1, 0)
	wolf.start_pounce_windup(dir)

	assert_test(wolf.is_preparing_pounce == true, "Wolf enters is_preparing_pounce state")
	assert_test(wolf.show_pounce_warning == true, "show_pounce_warning flag is true")
	assert_test(wolf.velocity == Vector2.ZERO, "Velocity is ZERO during windup")
	assert_test(wolf.pounce_direction == dir, "Pounce direction is locked to target dir")
	assert_test(wolf.pounce_timer > 0.0, "Pounce cooldown timer is set")

	wolf.queue_free()

func test_windup_interrupt() -> void:
	print("\n--- Test Group 5: Windup Interrupted by Damage ---")
	var wolf = WEREWOLF_SCENE.instantiate()
	add_child(wolf)

	wolf.is_active = true
	wolf.start_pounce_windup(Vector2(1, 0))
	assert_test(wolf.is_preparing_pounce == true, "Windup started")

	# Gây sát thương vào Werewolf khi đang gồng
	wolf.take_damage(1)

	assert_test(wolf.is_preparing_pounce == false, "is_preparing_pounce is canceled on taking damage")
	assert_test(wolf.show_pounce_warning == false, "show_pounce_warning is turned off")
	assert_test(wolf.animated_sprite.animation == "hurt", "Wolf plays 'hurt' animation")
	assert_test(wolf.hp == 4, "Wolf HP decreased by 1")

	wolf.queue_free()

func test_pounce_distance_bounding() -> void:
	print("\n--- Test Group 6: Pounce Fixed Distance Bounding ---")
	var wolf = WEREWOLF_SCENE.instantiate()
	add_child(wolf)

	wolf.is_active = true
	wolf.is_pouncing = true
	wolf.pounce_direction = Vector2(1, 0)
	wolf.pounce_traveled = 0.0

	# Giả lập di chuyển 0.3s (khoảng 52.5px, < 95px)
	wolf._physics_process(0.3)
	assert_test(wolf.is_pouncing == true, "Still pouncing before reaching max distance")
	assert_test(wolf.pounce_traveled > 0.0 and wolf.pounce_traveled < wolf.pounce_distance, "Distance traveled accumulating under limit")

	# Giả lập thêm 0.6s (vượt quá 95px)
	wolf._physics_process(0.6)
	assert_test(wolf.is_pouncing == false, "Pounce stops exactly when reaching pounce_distance")
	assert_test(wolf.pounce_traveled == wolf.pounce_distance, "pounce_traveled is clamped to pounce_distance")
	assert_test(wolf.velocity == Vector2.ZERO, "Velocity drops to ZERO when pounce finishes")

	wolf.queue_free()

func test_damage_and_death_flow() -> void:
	print("\n--- Test Group 7: Damage & Death Lifecycle ---")
	var wolf = WEREWOLF_SCENE.instantiate()
	add_child(wolf)

	wolf.is_active = true
	# Đánh chết (HP = 5)
	wolf.take_damage(5)

	assert_test(wolf.is_dead == true, "Wolf is marked as is_dead")
	assert_test(wolf.animated_sprite.animation == "death", "Wolf plays 'death' animation")

	# Chờ deferred frame để engine cập nhật trạng thái disabled
	await get_tree().process_frame
	await get_tree().physics_frame

	assert_test(wolf.get_node("CollisionShape2D").disabled == true, "Main collision is disabled on death")
	assert_test(wolf.get_node("Hurtbox/CollisionShape2D").disabled == true, "Hurtbox collision is disabled on death")

	wolf.queue_free()

func test_dungeon_generator_integration() -> void:
	print("\n--- Test Group 8: Dungeon Generator Integration ---")
	var generator_script = preload("res://scenes/dungeon/dungeon_generator.gd")
	var generator = generator_script.new()

	var has_werewolf: bool = false
	for scene in generator.enemy_scenes:
		var instance = scene.instantiate()
		if instance.name == "Werewolf" or instance.get_script().resource_path.contains("werewolf"):
			has_werewolf = true
		instance.queue_free()

	assert_test(has_werewolf, "dungeon_generator.enemy_scenes contains Werewolf scene")
	generator.queue_free()
