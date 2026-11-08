extends Node2D

const ARCHER_SCENE = preload("res://Scene/Enemies/Skeleton Archer/skeleton_archer.tscn")
const ARROW_SCRIPT = preload("res://Scene/Projectiles/enemy_arrow.gd")

var tests_passed: int = 0
var tests_failed: int = 0

class MockPlayer extends CharacterBody2D:
	var hp: int = 10
	var max_hp: int = 10

class MockTileMap extends Node2D:
	var los_blocked: bool = false
	func has_line_of_sight(_from: Vector2, _to: Vector2) -> bool:
		return not los_blocked
	func is_global_pos_wall_or_door(_pos: Vector2) -> bool:
		return los_blocked
	func get_smart_steer_direction(_from: Vector2, desired_dir: Vector2) -> Vector2:
		return desired_dir

func assert_test(cond: bool, test_name: String) -> void:
	if cond:
		print("  [PASS] ", test_name)
		tests_passed += 1
	else:
		printerr("  [FAIL] ", test_name)
		tests_failed += 1

func _count_arrows(parent: Node) -> int:
	var count := 0
	for child in parent.get_children():
		if is_instance_valid(child) and not child.is_queued_for_deletion():
			if child.get_script() == ARROW_SCRIPT or child.name.begins_with("EnemyArrow") or child.name.begins_with("@Area2D"):
				count += 1
	return count

func _ready() -> void:
	print("\n========================================================")
	print("  RUNNING SKELETON ARCHER COMBAT LIFECYCLE TESTS")
	print("========================================================\n")

	await test_normal_attack_fires_arrow()
	await test_windup_interrupted_by_hurt_cancels_shot()
	await test_windup_interrupted_by_los_loss_cancels_shot()
	await test_windup_interrupted_by_player_deletion_safe()
	await test_windup_interrupted_by_death_cancels_shot()

	print("\n========================================================")
	print("  TEST RESULTS: ", tests_passed, " PASSED, ", tests_failed, " FAILED")
	print("========================================================\n")

	get_tree().quit(1 if tests_failed > 0 else 0)

func _setup_fixture() -> Dictionary:
	var map = MockTileMap.new()
	add_child(map)

	var p = MockPlayer.new()
	p.position = Vector2(100, 0)
	p.add_to_group("player")
	map.add_child(p)

	var archer = ARCHER_SCENE.instantiate()
	archer.position = Vector2.ZERO
	archer.loot_seed = 1234
	map.add_child(archer)
	archer.player = p
	archer.is_active = true
	archer.set_physics_process(false)
	archer.can_attack = true

	return {"map": map, "player": p, "archer": archer}

func test_normal_attack_fires_arrow() -> void:
	print("--- Test 1: Normal Attack Fires Arrow ---")
	var f = _setup_fixture()
	var archer = f.archer
	var map = f.map

	archer.attack()
	assert_test(archer.is_attacking, "Archer enters attacking state upon attack()")
	assert_test(not archer.can_attack, "Attack availability locked during windup")

	# Wait past the 0.4s windup
	await get_tree().create_timer(0.55).timeout

	assert_test(_count_arrows(map) == 1, "Exactly one arrow emitted when windup completes uninterrupted with valid LOS")

	# Wait past attack cooldown (2.0s total)
	await get_tree().create_timer(1.6).timeout
	assert_test(archer.can_attack, "Archer can_attack restored after full cooldown")

	map.queue_free()
	await get_tree().process_frame

func test_windup_interrupted_by_hurt_cancels_shot() -> void:
	print("--- Test 2: Windup Interrupted by Hurt Cancels Shot ---")
	var f = _setup_fixture()
	var archer = f.archer
	var map = f.map

	archer.attack()

	# Interrupt during windup (0.15s < 0.4s)
	await get_tree().create_timer(0.15).timeout
	archer.take_damage(1)

	assert_test(archer.is_hurt, "Archer marked as hurt after taking damage")
	assert_test(not archer.is_attacking, "Attacking state cancelled when hurt")

	# Wait past the remainder of windup
	await get_tree().create_timer(0.4).timeout

	assert_test(_count_arrows(map) == 0, "No arrow emitted because windup was interrupted by hurt")

	map.queue_free()
	await get_tree().process_frame

func test_windup_interrupted_by_los_loss_cancels_shot() -> void:
	print("--- Test 3: Windup Interrupted by LOS Loss (Player Behind Wall) Cancels Shot ---")
	var f = _setup_fixture()
	var archer = f.archer
	var map = f.map

	archer.attack()

	# Block LOS during windup (player walks behind a pillar / wall)
	await get_tree().create_timer(0.15).timeout
	map.los_blocked = true

	# Wait past the 0.4s windup
	await get_tree().create_timer(0.4).timeout

	assert_test(_count_arrows(map) == 0, "No arrow emitted because LOS was lost before release")

	map.queue_free()
	await get_tree().process_frame

func test_windup_interrupted_by_player_deletion_safe() -> void:
	print("--- Test 4: Windup Interrupted by Player Deletion Safe ---")
	var f = _setup_fixture()
	var archer = f.archer
	var map = f.map
	var p = f.player

	archer.attack()

	# Player dies or is freed during windup
	await get_tree().create_timer(0.15).timeout
	p.free()

	# Wait past the 0.4s windup
	await get_tree().create_timer(0.4).timeout

	assert_test(_count_arrows(map) == 0, "No arrow emitted when player is deleted during windup")
	assert_test(is_instance_valid(archer), "Archer remains valid without crashing on null player reference")

	map.queue_free()
	await get_tree().process_frame

func test_windup_interrupted_by_death_cancels_shot() -> void:
	print("--- Test 5: Death During Windup Cancels Shot ---")
	var f = _setup_fixture()
	var archer = f.archer
	var map = f.map

	archer.attack()

	# Fatal damage during windup
	await get_tree().create_timer(0.15).timeout
	archer.take_damage(99)

	assert_test(archer.is_dead, "Archer marked dead after lethal damage")

	# Wait past the 0.4s windup
	await get_tree().create_timer(0.4).timeout

	assert_test(_count_arrows(map) == 0, "No ghost arrow emitted after archer death")

	map.queue_free()
	await get_tree().process_frame
