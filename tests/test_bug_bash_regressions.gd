extends Node

const BalanceData = preload("res://Scene/BalanceConfig.gd")
const CombatUtil = preload("res://Scene/Character/CombatUtil.gd")
const DoraUtil = preload("res://Scene/Character/Doraemon/dora_util.gd")
const LtUtil = preload("res://Scene/Character/LuongTho/lt_util.gd")
const MiyabiUtil = preload("res://Scene/Character/Miyabi/miyabi_util.gd")
const RoomManagerScript = preload("res://Scene/Map/room_manager.gd")
const InventoryManagerScript = preload("res://Scene/Character/InventoryManager.gd")
const ItemDataScript = preload("res://Scene/Items/ItemData.gd")

var passed: int = 0
var failed: int = 0

func assert_test(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		print("  [PASS] ", msg)
	else:
		failed += 1
		printerr("  [FAIL] ", msg)

class StunDummy extends CharacterBody2D:
	var is_dead: bool = false
	var is_immovable: bool = false

class PlayerDamageSpy extends Node2D:
	var saw_on_hit: bool = false
	var last_raw: int = 0
	var returned_dmg: int = 0
	func apply_on_hit_effects(_target: Node2D, raw_damage: int) -> int:
		saw_on_hit = true
		last_raw = raw_damage
		returned_dmg = raw_damage + 7
		return returned_dmg

class EnemySpy extends Node2D:
	var is_dead: bool = false
	var is_active: bool = true
	var taken_total: int = 0
	var take_calls: int = 0
	func _init() -> void:
		var hb := Area2D.new()
		hb.name = "Hurtbox"
		add_child(hb)
	func take_damage(amount: int) -> void:
		take_calls += 1
		taken_total += amount

class MockRoomTileMap extends TileMap:
	var the_player: Node2D = null
	func _init() -> void:
		tile_set = TileSet.new()

class MockNavTileMap extends Node2D:
	var blocked: Dictionary = {}
	func local_to_map(pos: Vector2) -> Vector2i:
		return Vector2i(int(floor(pos.x / 16.0)), int(floor(pos.y / 16.0)))
	func map_to_local(cell: Vector2i) -> Vector2:
		return Vector2(cell) * 16.0 + Vector2(8.0, 8.0)
	func is_global_pos_wall_or_door(gpos: Vector2) -> bool:
		var c := local_to_map(to_local(gpos))
		return blocked.has(c)

class MockLockTileMap extends Node2D:
	var room_managers: Dictionary = {}

class TrapMockPlayer extends CharacterBody2D:
	var is_dead: bool = false
	var damage_hits: int = 0
	var last_dmg: int = 0
	func _init() -> void:
		add_to_group("player")
	func take_damage(amount: int) -> void:
		damage_hits += 1
		last_dmg = amount

func _ready() -> void:
	print("\n========================================================")
	print("  RUNNING BUG BASH (#81-#97) REGRESSION TESTS")
	print("========================================================")

	await _test_floor_scaling_after_ready()
	_test_perks_single_count_and_equip_anti_heal()
	await _test_combat_util_and_enemy_filters()
	_test_tres_non_mutation_and_chest_loot()
	_test_room_manager_perimeter_and_spawner_collider()
	_test_orc_rider_hitbox_and_bfs_navigation()
	_test_spike_trap_alignment_and_active_damage()
	await _test_replay_save_and_modal_guards()
	await get_tree().process_frame

	print("\n========================================================")
	print("  BUG BASH REGRESSION RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	print("========================================================")
	get_tree().quit(1 if failed > 0 else 0)

func _test_floor_scaling_after_ready() -> void:
	print("\n--- Regression Group 1 (#81.1): Enemy & Boss Floor Scaling After _ready() ---")
	var saved_lvl: int = GameManager.current_level
	var saved_seed: String = GameManager.current_seed

	GameManager.set_character_by_index(2)
	GameManager.start_new_run("REG-SCALE-3", false, [])
	GameManager.current_level = 3
	var w3: Node = (load("res://world.tscn") as PackedScene).instantiate()
	add_child(w3)
	await get_tree().process_frame
	var gen3 = w3.get_node("TileMap")
	var checked_enemy := false
	for child in gen3.get_children():
		if child.is_in_group("enemies") and not child.is_in_group("boss") and "enemy_balance_id" in child:
			var bid: String = String(child.enemy_balance_id)
			if not bid.is_empty():
				var base_cfg: Dictionary = BalanceData.get_enemy_stats(bid)
				assert_test(child.hp == roundi(float(base_cfg["hp"]) * pow(1.25, 2)) + 6, "#81.1 Regular enemy retains Issue #75 floor-3 HP scaling after _ready()")
				assert_test(child.damage == int(base_cfg["damage"]) + 1, "#81.1 Regular enemy on floor 3 keeps +1 damage scaling after _ready()")
				checked_enemy = true
				break
	assert_test(checked_enemy, "#81.1 Found scaled regular enemy in floor 3 dungeon")
	w3.queue_free()
	await get_tree().process_frame

	GameManager.start_new_run("REG-SCALE-2", false, [])
	GameManager.current_level = 2
	var w2: Node = (load("res://world.tscn") as PackedScene).instantiate()
	add_child(w2)
	await get_tree().process_frame
	var gen2 = w2.get_node("TileMap")
	var boss = gen2.active_boss
	assert_test(is_instance_valid(boss), "#81.1 Floor 2 boss (OrcRider) spawned")
	if is_instance_valid(boss):
		var bcfg: Dictionary = BalanceData.get_boss_stats("orc_rider")
		assert_test(boss.hp == roundi(float(bcfg["hp"]) * 1.25) + 20, "#81.1 Boss retains Issue #75 floor-2 HP scaling after _ready()")
		assert_test(boss.active_damage == int(bcfg["damage"]) + 1, "#81.1 Boss on floor 2 keeps +1 damage scaling after _ready()")
	w2.queue_free()
	await get_tree().process_frame

	GameManager.current_level = saved_lvl
	GameManager.current_seed = saved_seed

func _test_perks_single_count_and_equip_anti_heal() -> void:
	print("\n--- Regression Group 2 (#81.2, #81.3): Single-Count Perks & Equipment Anti-Heal ---")
	PerkManager.reset()
	var hero = (load("res://Scene/Character/Player 1_Pyrois/player.tscn") as PackedScene).instantiate()
	add_child(hero)
	var base_spd: float = hero.get_effective_speed()
	var base_dmg: float = hero.get_raw_damage()

	PerkManager.add_perk(PerkDatabase.get_perk_by_id("swift_stride"), hero)
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("sharpened_edge"), hero)
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("quick_reflexes"), hero)
	assert_test(is_equal_approx(hero.get_effective_speed(), base_spd + 15.0), "#81.2 speed_bonus applied once (+15)")
	assert_test(is_equal_approx(hero.get_raw_damage(), base_dmg + 1.0), "#81.2 bonus_damage applied once (+1)")
	assert_test(is_equal_approx(hero.get_attack_speed_bonus(), 0.15), "#81.2 attack_speed_bonus queried dynamically (+0.15)")
	assert_test(hero.get_effective_attack_cooldown(1.0) < 1.0, "#81.2 attack_speed_bonus lowers attack cooldown")

	# Simulate floor change calling apply_all_perks_to_player again
	PerkManager.apply_all_perks_to_player(hero)
	assert_test(is_equal_approx(hero.get_effective_speed(), base_spd + 15.0), "#81.2 Floor transition does not double speed_bonus")
	assert_test(is_equal_approx(hero.get_raw_damage(), base_dmg + 1.0), "#81.2 Floor transition does not double bonus_damage")

	# #81.3: Equipping bonus-HP armor while hurt must NOT heal hp
	var armor_res: ItemData = load("res://Scene/Items/Mythic/mythic_celestia_godplate.tres").duplicate()
	hero.hp = 2
	hero.inventory.add_item(armor_res, 1)
	var armor_slot: int = -1
	for s in range(hero.inventory.bag.size()):
		if hero.inventory.bag[s] != null and hero.inventory.bag[s].item_name == armor_res.item_name:
			armor_slot = s
			break
	assert_test(armor_slot >= 0, "#81.3 Added bonus_max_hp armor to backpack")
	hero.inventory.use_or_equip_item(armor_slot, hero)
	assert_test(hero.max_hp == hero.base_max_hp + armor_res.max_hp_bonus, "#81.3 Equip raises max_hp")
	assert_test(hero.hp == 2, "#81.3 Equipping bonus_max_hp gear does NOT heal missing HP")
	# Heal to full, unequip, verify hp clamps to base_max_hp
	hero.hp = hero.max_hp
	hero.inventory.unequip_item(ItemDataScript.ItemType.ARMOR)
	assert_test(hero.hp == hero.base_max_hp, "#81.3 Unequipping clamps hp down to reduced max_hp")

	hero.queue_free()
	PerkManager.reset()

func _test_combat_util_and_enemy_filters() -> void:
	print("\n--- Regression Group 3 (#84.1, #84.3, #84.4): CombatUtil & Active Enemy Filters ---")
	var dummy := StunDummy.new()
	add_child(dummy)
	dummy.set_physics_process(true)
	CombatUtil.acquire_stun_lock(dummy)
	CombatUtil.acquire_stun_lock(dummy)
	assert_test(not dummy.is_physics_processing(), "#84.3 Stacked acquire_stun_lock pauses physics_process")
	CombatUtil.release_stun_lock(dummy)
	assert_test(not dummy.is_physics_processing(), "#84.3 First release keeps target stunned until refcount reaches 0")
	CombatUtil.release_stun_lock(dummy)
	assert_test(dummy.is_physics_processing(), "#84.3 Final release restores physics_process")

	var immovable := StunDummy.new()
	immovable.is_immovable = true
	add_child(immovable)
	immovable.set_physics_process(true)
	CombatUtil.acquire_stun_lock(immovable)
	assert_test(immovable.is_physics_processing(), "#84.3 Immovable target ignores stun lock")

	var world_box := Node2D.new()
	add_child(world_box)
	var p_spy := PlayerDamageSpy.new()
	var active_e := EnemySpy.new()
	active_e.is_active = true
	var inactive_e := EnemySpy.new()
	inactive_e.is_active = false
	world_box.add_child(p_spy)
	world_box.add_child(active_e)
	world_box.add_child(inactive_e)

	var dealt := CombatUtil.deal_player_damage(p_spy, active_e, 5)
	assert_test(p_spy.saw_on_hit and p_spy.last_raw == 5, "#84.1 CombatUtil.deal_player_damage routes through apply_on_hit_effects")
	assert_test(dealt == 12 and active_e.taken_total == 12 and active_e.take_calls == 1, "#84.1 Target receives on-hit adjusted damage once")

	await get_tree().physics_frame
	var d_list := DoraUtil.enemies(world_box)
	var l_list := LtUtil.enemies(world_box)
	var m_list := MiyabiUtil.enemies(world_box)
	assert_test(d_list.has(active_e) and not d_list.has(inactive_e), "#84.4 DoraUtil.enemies filters inactive enemies")
	assert_test(l_list.has(active_e) and not l_list.has(inactive_e), "#84.4 LtUtil.enemies filters inactive enemies")
	assert_test(m_list.has(active_e) and not m_list.has(inactive_e), "#84.4 MiyabiUtil.enemies filters inactive enemies")

	dummy.queue_free()
	immovable.queue_free()
	world_box.queue_free()

func _test_tres_non_mutation_and_chest_loot() -> void:
	print("\n--- Regression Group 4 (#87): .tres Resource Isolation & Default Chest Loot ---")
	var shared_pot: ItemData = load("res://Scene/Items/Common/health_potion.tres")
	var orig_stack := shared_pot.stack_count
	var inv := InventoryManagerScript.new()
	add_child(inv)
	for i in range(16):
		var filler := ItemDataScript.new()
		filler.item_name = "Filler %d" % i
		filler.type = ItemDataScript.ItemType.WEAPON
		inv.bag[i] = filler
	var full_added := inv.add_item(shared_pot, 5)
	assert_test(not full_added and inv.last_add_remaining == 5, "#87 Full inventory rejects .tres add with remaining=5")
	assert_test(shared_pot.stack_count == orig_stack, "#87 Shared .tres stack_count was NOT mutated")

	var chest = (load("res://Scene/Items/Chest/chest.tscn") as PackedScene).instantiate()
	add_child(chest)
	assert_test(chest.loot_table.is_empty(), "#87.2 Default chest scene has empty loot_table (uses ItemDatabase)")
	chest.queue_free()
	inv.queue_free()

func _test_room_manager_perimeter_and_spawner_collider() -> void:
	print("\n--- Regression Group 5 (#97): RoomManager Perimeter Activation ---")
	var tmap := MockRoomTileMap.new()
	add_child(tmap)
	var p := Node2D.new()
	tmap.add_child(p)
	tmap.the_player = p

	var rm: Area2D = RoomManagerScript.new()
	rm.room_rect = Rect2i(10, 10, 12, 12)
	rm.entrances = [Vector2i(9, 15)]
	rm.tilemap = tmap
	tmap.add_child(rm)

	p.global_position = tmap.to_global(tmap.map_to_local(Vector2i(10, 10)))
	assert_test(rm._is_player_deep_inside_room(p), "#97 RoomManager detects player stepping along room inner perimeter (10,10)")
	p.global_position = tmap.to_global(tmap.map_to_local(Vector2i(9, 15)))
	assert_test(not rm._is_player_deep_inside_room(p), "#97 RoomManager does NOT lock while player stands in doorway tile")

	tmap.queue_free()

func _test_orc_rider_hitbox_and_bfs_navigation() -> void:
	print("\n--- Regression Group 6 (#96, #92): OrcRider Downward Hitbox & Pillar BFS ---")
	var boss = (load("res://Scene/Enemies/Boss/Orc Rider/orc_rider.tscn") as PackedScene).instantiate()
	add_child(boss)
	var s2: CollisionShape2D = boss.get_node("Hitbox/Shape2")
	var s3: CollisionShape2D = boss.get_node("Hitbox/Shape3")
	var s2_rect := s2.shape as RectangleShape2D
	var s2_bottom := s2.position.y + (s2_rect.size.y * 0.5 if s2_rect else 0.0)
	var s3_circle := s3.shape as CircleShape2D
	assert_test(s2_bottom >= 40.0, "#96 OrcRider Shape2 reaches downward below boss center (bottom=%.1f)" % s2_bottom)
	assert_test(s3.position == Vector2.ZERO and s3_circle != null and s3_circle.radius >= 60.0, "#96 OrcRider Shape3 centered with radius >= 60px")

	var nav_map := MockNavTileMap.new()
	add_child(nav_map)
	nav_map.blocked[Vector2i(1, 0)] = true
	var p := Node2D.new()
	nav_map.add_child(p)
	boss.reparent(nav_map)
	boss.global_position = nav_map.to_global(nav_map.map_to_local(Vector2i(0, 0)))
	p.global_position = nav_map.to_global(nav_map.map_to_local(Vector2i(2, 0)))
	boss.player = p
	var steer: Vector2 = boss._get_boss_nav_direction(nav_map, Vector2.RIGHT)
	assert_test(absf(steer.y) > 0.1, "#92 OrcRider BFS steers around blocking obstacle instead of walking straight into wall")

	nav_map.queue_free()

func _test_spike_trap_alignment_and_active_damage() -> void:
	print("\n--- Regression Group 7 (#95, #86.4): SpikeTrap Collider & Active Entry Damage ---")
	var trap = (load("res://Scene/Map/SpikeTrap.tscn") as PackedScene).instantiate()
	add_child(trap)
	var cs: CollisionShape2D = trap.get_node("CollisionShape2D")
	var rect := cs.shape as RectangleShape2D
	assert_test(cs.position == Vector2(0, 11) and rect != null and rect.size == Vector2(49, 79), "#95 SpikeTrap collider matches visual bounds (0,11) (49x79)")

	var tp := TrapMockPlayer.new()
	add_child(tp)
	trap.is_active_spikes = true
	trap._hit_this_activation.clear()
	trap._on_body_entered(tp)
	trap._on_body_entered(tp)
	assert_test(tp.damage_hits == 1, "#86.4 Entering active spikes deals damage once per activation cycle")

	trap.queue_free()
	tp.queue_free()

func _test_replay_save_and_modal_guards() -> void:
	print("\n--- Regression Group 8 (#82, #86): Replay RLE, Save Size/Fields, T-Key & Pause Guards ---")
	var sanitized := GameManager._sanitize_replay_frames([{"q": true, "result": 4.0, "repeat": 12.0}], 100)
	assert_test(sanitized.size() == 1 and sanitized[0]["result"] == 4 and sanitized[0]["repeat"] == 12, "#82.1/#82.2 _sanitize_replay_frames preserves float-typed result & repeat")

	GameManager.start_new_run("RLE-SAVE-TEST", false, [])
	GameManager.hall_selecting = false
	for _i in range(25):
		GameManager.record_frame_input({"dx": 0.0, "dy": 0.0, "ax": 10.0, "ay": 0.0, "slot": -1})
	assert_test(GameManager.current_recording_frames.size() == 1 and int(GameManager.current_recording_frames[0].get("repeat", 1)) == 25, "#82.2 25 idle frames RLE-compressed with repeat=25")

	var compressed_copy: Array = GameManager.current_recording_frames.duplicate(true)
	GameManager.start_new_run("RLE-PLAY-TEST", true, compressed_copy)
	assert_test(GameManager.replay_frames.size() == 25, "#82.2 Replay expands RLE repeat=25 back to 25 frames")
	GameManager.is_replaying = false
	GameManager.replay_frames.clear()

	GameManager.start_new_run("HALL-GUARD", false, [])
	GameManager.hall_selecting = true
	GameManager.record_frame_input({"dx": 1.0, "dy": 0.0, "slot": -1})
	assert_test(GameManager.current_recording_frames.is_empty(), "#82.4 Hall selection prevents recording stray replay frames")
	assert_test(not GameManager.teleport_to_guild_hall(), "#86.1 teleport_to_guild_hall blocked while hall_selecting=true")
	GameManager.hall_selecting = false

	# Locked RoomManager blocks T-key teleport
	var lock_world := Node.new()
	var mock_tmap := MockLockTileMap.new()
	mock_tmap.name = "TileMap"
	var fake_mgr := RoomManagerScript.new()
	fake_mgr.is_locked = true
	mock_tmap.room_managers = {0: fake_mgr}
	lock_world.add_child(mock_tmap)
	var dummy_hero := TrapMockPlayer.new()
	lock_world.add_child(dummy_hero)
	mock_tmap.add_child(fake_mgr)
	var prev_scene := get_tree().current_scene
	get_tree().root.add_child(lock_world)
	get_tree().current_scene = lock_world
	assert_test(not GameManager.teleport_to_guild_hall(), "#86.1 Locked RoomManager blocks T-key teleport to Guild Hall")
	get_tree().current_scene = prev_scene
	lock_world.queue_free()

	# Backup real save if present, verify compact JSON + date/reason reload
	var had_save := FileAccess.file_exists(GameManager.SAVE_FILE_PATH)
	var backup_save := FileAccess.get_file_as_string(GameManager.SAVE_FILE_PATH) if had_save else ""
	var saved_hist := GameManager.run_history.duplicate(true)
	var saved_last := GameManager.last_recorded_run.duplicate(true)

	GameManager.start_new_run("SAVE-CHECK", false, [])
	GameManager.record_frame_input({"dx": 1.0, "dy": 0.0, "ax": 5.0, "ay": 0.0, "q": true, "result": 3, "slot": -1})
	GameManager.finish_run("Victory Test")
	var raw_json := FileAccess.get_file_as_string(GameManager.SAVE_FILE_PATH)
	assert_test(raw_json.find("\n\t") == -1 and raw_json.to_utf8_buffer().size() <= GameManager.MAX_SAVE_FILE_BYTES, "#82.5 Save file uses compact JSON <= MAX_SAVE_FILE_BYTES")
	var expected_date := String(GameManager.last_recorded_run.get("date", ""))
	var expected_reason := String(GameManager.last_recorded_run.get("reason", ""))
	GameManager.last_recorded_run.clear()
	GameManager.load_save_data()
	assert_test(String(GameManager.last_recorded_run.get("date", "")) == expected_date and String(GameManager.last_recorded_run.get("reason", "")) == expected_reason, "#82.5 load_save_data preserves last_recorded_run date and reason")

	# PauseMenu ESC must not unpause an underlying modal when pause_menu itself is hidden
	var pm: Control = (load("res://Menu/pause menu/pause_menu.tscn") as PackedScene).instantiate()
	add_child(pm)
	pm.hide()
	get_tree().paused = true
	var esc_ev := InputEventAction.new()
	esc_ev.action = "esc"
	esc_ev.pressed = true
	pm._unhandled_input(esc_ev)
	assert_test(get_tree().paused == true, "#86.2 Hidden PauseMenu ignores ESC when another modal holds pause")
	get_tree().paused = false
	pm.queue_free()

	# Restore save state
	GameManager.run_history = saved_hist
	GameManager.last_recorded_run = saved_last
	if had_save:
		var wf := FileAccess.open(GameManager.SAVE_FILE_PATH, FileAccess.WRITE)
		if wf != null:
			wf.store_string(backup_save)
			wf.close()
	elif FileAccess.file_exists(GameManager.SAVE_FILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameManager.SAVE_FILE_PATH))
