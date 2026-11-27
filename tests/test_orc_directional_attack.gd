extends Node2D
## Issue #89: real scenes, AI attack entry, physics area contacts and hero damage.
## Fixed-position cases suppress movement only; never change the attack range.

const ORC = preload("res://Scene/Enemies/Orc/orc.tscn")
const HEROES = [
	preload("res://Scene/Character/Player 1_Pyrois/player.tscn"),
	preload("res://Scene/Character/Player 2_Olaf/player_2.tscn"),
]
const WORLD = preload("res://world.tscn")
const MAP = preload("res://Scene/Map/dungeon_generator.gd")
const ROOM = preload("res://Scene/Map/room_manager.gd")
const DIRECTIONS = {
	"UP": Vector2.UP, "DOWN": Vector2.DOWN,
	"LEFT": Vector2.LEFT, "RIGHT": Vector2.RIGHT,
	"UP_LEFT": Vector2(-0.7071067811865476, -0.7071067811865476),
	"UP_RIGHT": Vector2(0.7071067811865476, -0.7071067811865476),
	"DOWN_LEFT": Vector2(-0.7071067811865476, 0.7071067811865476),
	"DOWN_RIGHT": Vector2(0.7071067811865476, 0.7071067811865476),
}
const SEED = 8901
const CONTACT_TICKS = 5

class RuntimeErrors extends Logger:
	var messages: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, _error_type: int,
			backtraces: Array[ScriptBacktrace]) -> void:
		if not backtraces.is_empty() or file.ends_with(".gd"):
			messages.append("%s:%d %s %s" % [file, line, code, rationale])

var passed := 0
var failed := 0
var trace: Array = []
var runtime_errors := RuntimeErrors.new()


func _ready() -> void:
	OS.add_logger(runtime_errors)
	_run.call_deferred()
	get_tree().create_timer(180.0).timeout.connect(func():
		printerr("[FAIL] Orc directional suite timed out")
		get_tree().quit(1))


func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("[PASS] ", label)
	else:
		failed += 1
		printerr("[FAIL] ", label)


func _arena(hero_index: int = 0, floor_number: int = 1) -> Dictionary:
	var world = WORLD.instantiate()
	var map: TileMap = world.get_node("TileMap")
	world.remove_child(map)
	world.free()
	map.set_script(null)
	add_child(map)
	map.set_script(MAP) # Real navigation without automatic dungeon generation.
	map.clear()
	map.current_level = floor_number
	map.position = Vector2(333, -211) # Catch accidental local/global comparisons.
	for x in range(-8, 9):
		for y in range(-8, 9):
			map.set_cell(0, Vector2i(x, y), 0, Vector2i(1, 6))
	var hero = HEROES[hero_index].instantiate()
	map.add_child(hero)
	hero.set_physics_process(false) # No input or movement, real hurtbox and defenses.
	hero.position = Vector2(8, 80)
	hero.is_invincible = false
	var orc = ORC.instantiate()
	orc.loot_seed = SEED
	orc.combat_floor = floor_number
	map.add_child(orc)
	orc.position = Vector2(8, 8)
	orc.set_physics_process(false)
	orc.speed = 0.0
	var room = ROOM.new()
	room.tilemap = map
	room.enemies = [orc]
	room.room_rect = Rect2i(-7, -7, 14, 14)
	map.add_child(room)
	room.set_physics_process(false)
	room.lock_room() # Production room activation, not a mock is_active override.
	return {"map": map, "hero": hero, "orc": orc, "room": room,
		"health": hero.hp + hero.current_armor, "contacts": 0, "hits": [],
		"starts": [], "enabled": false, "tick": 0}


func _observe_contact(area: Area2D, fixture: Dictionary) -> void:
	if area == fixture.hero.get_node("PlayerHurtbox"):
		fixture.contacts += 1
		if fixture.hero.hp + fixture.hero.current_armor < fixture.health:
			fixture.hits.append(fixture.hero.global_position - fixture.orc.global_position)


func _observe(fixture: Dictionary) -> void:
	fixture.orc.axe_hitbox.area_entered.connect(_observe_contact.bind(fixture))


func _step(fixture: Dictionary) -> void:
	await get_tree().physics_frame
	fixture.tick += 1
	var attacking: bool = fixture.orc.is_attacking
	fixture.orc._physics_process(1.0 / Engine.physics_ticks_per_second)
	if fixture.orc.is_attacking and not attacking:
		fixture.starts.append(fixture.hero.global_position - fixture.orc.global_position)
	fixture.enabled = fixture.enabled or not fixture.orc.axe_collision.disabled
	# Read physics contacts/damage after the physics server has flushed signals.
	await get_tree().process_frame


func _run() -> void:
	var save_guard = preload("res://tests/save_guard.gd").new()
	seed(SEED)
	for hero_index in range(HEROES.size()):
		for floor_number in [1, 3, 5, 7]:
			await _matrix(hero_index, floor_number)
	await _obstacles()
	await _damage_time_guards()
	await _lifecycle()
	await _natural_pursuit()
	save_guard.restore()
	_check(save_guard.is_restored(), "Player save is restored")
	OS.remove_logger(runtime_errors)
	for message in runtime_errors.messages:
		printerr("[RUNTIME] ", message)
	_check(runtime_errors.messages.is_empty(), "No runtime errors")
	_check(not trace.is_empty(), "Determinism trace is nonempty")
	for row in trace:
		print("[TRACE] ", JSON.stringify(row))
	print("[TRACE] Orc directional seed=%d physics_hz=%d rows=%d hash=%s" % [
		SEED, Engine.physics_ticks_per_second, trace.size(), str(hash(trace))])
	print("ORC DIRECTIONAL RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	get_tree().quit(1 if failed else 0)


func _matrix(hero_index: int, floor_number: int) -> void:
	var probe := _arena(hero_index, floor_number)
	var attack_range: float = probe.orc.attack_range
	_check(attack_range == BalanceConfig.get_enemy_stats("orc").attack_range,
		"Hero %d floor %d uses resource attack range %.2f" % [hero_index, floor_number, attack_range])
	_check(probe.orc._tactical_ai._tactics.get_config().tier == (floor_number - 1) / 2,
		"Floor %d resolves the expected AI tier" % floor_number)
	probe.map.free()
	for direction_name in DIRECTIONS:
		for distance in [20.0, 30.0, 35.0, attack_range - 0.25, attack_range + 0.25]:
			var fixture := _arena(hero_index, floor_number)
			var offset: Vector2 = DIRECTIONS[direction_name] * distance
			fixture.hero.position = fixture.orc.position + offset
			_observe(fixture)
			for tick in range(CONTACT_TICKS):
				await _step(fixture)
			var damaged: bool = fixture.hero.hp + fixture.hero.current_armor < fixture.health
			# A nominal 20px diagonal can round just outside 20px after global
			# translation. Judge the actual world-space separation, as production
			# does; the 19.75/20.25 rows bracket the boundary in every direction.
			var measured: float = fixture.orc.global_position.distance_to(fixture.hero.global_position)
			var eligible: bool = measured <= attack_range
			var stationary: bool = fixture.hero.position.is_equal_approx(Vector2(8, 8) + offset) \
				and fixture.orc.position.is_equal_approx(Vector2(8, 8))
			var valid_hit: bool = not fixture.hits.is_empty() and fixture.hits[0].is_equal_approx(offset)
			var ok: bool = fixture.orc.player == fixture.hero and stationary
			if eligible:
				ok = ok and fixture.starts.size() == 1 and fixture.enabled and damaged and valid_hit \
					and fixture.starts[0].is_equal_approx(offset)
			else:
				ok = ok and fixture.starts.is_empty() and not fixture.enabled and not damaged
			_check(ok, "hero=%d floor=%d %s nominal=%.2fpx actual=%.8f trigger=%d hitbox=%s contact=%d damage=%d fixed=%s" % [
				hero_index, floor_number, direction_name, distance, measured, fixture.starts.size(),
				fixture.enabled, fixture.contacts, fixture.health - fixture.hero.hp - fixture.hero.current_armor, stationary])
			trace.append([hero_index, floor_number, direction_name, distance,
				measured, fixture.starts, fixture.enabled, fixture.contacts,
				fixture.health - fixture.hero.hp - fixture.hero.current_armor, fixture.hits, stationary])
			fixture.map.free()


func _obstacles() -> void:
	for door in [false, true]:
		var fixture := _arena()
		fixture.hero.position = Vector2(27.5, 8)
		if door:
			fixture.room.entrances = [Vector2i(1, 0)]
			fixture.room.lock_room()
		else:
			fixture.map.set_cell(0, Vector2i(1, 0), 0, Vector2i(1, 3))
		_observe(fixture)
		for tick in range(CONTACT_TICKS):
			await _step(fixture)
		_check(not fixture.map.has_line_of_sight(fixture.orc.global_position, fixture.hero.global_position)
			and fixture.starts.is_empty() and not fixture.enabled
			and fixture.hero.hp + fixture.hero.current_armor == fixture.health,
			("Closed door" if door else "Wall") + ": blocks AI attack and damage")
		fixture.map.free()


func _damage_time_guards() -> void:
	# Enter through AI, then change range/LOS before the first physics contact.
	for blocked in [false, true]:
		var fixture := _arena()
		fixture.hero.position = fixture.orc.position + Vector2.DOWN * 19.5
		_observe(fixture)
		fixture.orc._physics_process(1.0 / Engine.physics_ticks_per_second)
		_check(fixture.orc.is_attacking and not fixture.orc.axe_collision.disabled,
			"Guard fixture starts via AI")
		fixture.hero.position = fixture.orc.position + Vector2.DOWN * 30.0
		if blocked:
			fixture.hero.position = fixture.orc.position + Vector2.DOWN * 19.5
			fixture.map.set_cell(2, Vector2i(0, 1), 0, Vector2i(1, 3))
		for tick in range(CONTACT_TICKS):
			await _step(fixture)
		_check(fixture.contacts > 0 and fixture.hero.hp + fixture.hero.current_armor == fixture.health,
			"Fresh LOS blocks contact damage" if blocked else "Leaving range before contact prevents damage")
		fixture.map.free()


func _lifecycle() -> void:
	# Orc has no delayed windup: hitbox enables immediately, and the attack
	# animation is the repeat lock. Interrupt before its first physics contact.
	for interruption in ["hurt", "death", "stun"]:
		var fixture := _arena()
		fixture.hero.position = fixture.orc.position + Vector2.DOWN * 19.5
		_observe(fixture)
		fixture.orc._physics_process(1.0 / Engine.physics_ticks_per_second)
		_check(fixture.orc.is_attacking and not fixture.orc.axe_collision.disabled,
			"Immediate attack entry before " + interruption)
		if interruption == "stun":
			var util = preload("res://Scene/Character/CombatUtil.gd")
			fixture.orc.set_physics_process(true)
			util.acquire_stun_lock(fixture.orc)
			_check(not fixture.orc.is_physics_processing(), "Stun freezes AI; existing live swing is preserved")
			util.release_stun_lock(fixture.orc)
			_check(fixture.orc.is_physics_processing() and fixture.orc.is_attacking
				and not fixture.orc.axe_collision.disabled, "Stun release restores the existing swing contract")
			fixture.orc.set_physics_process(false)
		else:
			fixture.orc.take_damage(1 if interruption == "hurt" else 10000)
			for tick in range(CONTACT_TICKS):
				await _step(fixture)
			_check(fixture.hero.hp + fixture.hero.current_armor == fixture.health
				and fixture.orc.axe_collision.disabled,
				interruption + " before contact disables axe and prevents damage")
		fixture.map.free()
	var fixture := _arena()
	fixture.hero.position = fixture.orc.position + Vector2.DOWN * 19.5
	_observe(fixture)
	await _step(fixture)
	for tick in range(12):
		await _step(fixture)
	_check(fixture.starts.size() == 1 and fixture.orc.is_attacking,
		"Attack animation prevents a premature repeated attack")
	for tick in range(90):
		await _step(fixture)
		if fixture.starts.size() >= 2:
			break
	_check(fixture.starts.size() >= 2, "Animation recovery permits the next AI attack")
	fixture.map.free()


func _natural_pursuit() -> void:
	for direction_name in DIRECTIONS:
		var fixture := _arena()
		fixture.orc.speed = BalanceConfig.get_enemy_stats("orc").speed
		fixture.hero.position = fixture.orc.position + DIRECTIONS[direction_name] * 35.0
		_observe(fixture)
		for tick in range(120):
			await _step(fixture)
			if fixture.hero.hp + fixture.hero.current_armor < fixture.health:
				break
		var hit_in_range: bool = not fixture.hits.is_empty() \
			and fixture.hits[0].length() <= fixture.orc.attack_range
		_check(fixture.starts.size() >= 1 and hit_in_range,
			"Natural pursuit from 35px " + direction_name + " hits only after closing range")
		fixture.map.free()
