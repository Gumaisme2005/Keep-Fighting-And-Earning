extends Node

const INVENTORY = preload("res://Scene/Character/InventoryManager.gd")

class Player extends BasePlayer:
	var scans: int = 0
	func start_invincibility() -> void:
		# Keep the real damage rejection rule without asynchronous flashing in fixtures.
		is_invincible = true
	func _get_defensive_targets(radius: float) -> Array[Node2D]:
		scans += 1
		return super._get_defensive_targets(radius)

class Enemy extends BaseEnemy:
	var hits: Array[int] = []
	func take_damage(amount: int) -> void:
		hits.append(amount)
		super.take_damage(amount)

class RemovingEnemy extends Enemy:
	var victim: Node
	func take_damage(amount: int) -> void:
		if is_instance_valid(victim): victim.free()
		super.take_damage(amount)

class UIProbe extends Node:
	var numbers: Array = []
	var banners: Array = []
	func spawn_damage_number(at: Vector2, amount: int, color: Color = Color.WHITE) -> void:
		numbers.append([at, amount, color])
	func show_banner(message: String, _color: Color = Color.WHITE) -> void:
		banners.append(message)

class RuntimeErrors extends Logger:
	var messages: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, backtraces: Array[ScriptBacktrace]) -> void:
		if not backtraces.is_empty() or file.ends_with(".gd"):
			messages.append("%s:%d %s %s" % [file, line, code, rationale])

var passed: int = 0
var failed: int = 0
var trace: Array = []
var runtime_errors := RuntimeErrors.new()

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("[PASS] ", label)
	else:
		failed += 1
		printerr("[FAIL] ", label)

func _ready() -> void:
	OS.add_logger(runtime_errors)
	_run.call_deferred()
	get_tree().create_timer(90.0).timeout.connect(func():
		printerr("[FAIL] Defensive combat suite timed out")
		get_tree().quit(1))

func _run() -> void:
	await test_core_defects()
	await test_rejections_and_rounding()
	await test_target_selection()
	await test_blast_configuration_and_events()
	await test_cooldowns()
	await test_deferred_lifecycle()
	await test_target_death_and_boss_apis()
	await test_retaliation_kill_healing()
	await test_popups_and_combined_effects()
	await test_rng_isolation()
	await test_potion_compatibility()
	await test_all_heroes()
	await test_floor_recreation_and_reset()
	test_replay_cooldown_recording()
	OS.remove_logger(runtime_errors)
	for message in runtime_errors.messages:
		printerr("[RUNTIME] ", message)
	check(runtime_errors.messages.is_empty(), "Defensive effects produce zero runtime errors")
	print("[TRACE] defensive combat: ", trace)
	print("DEFENSIVE RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func fixture(mythic: bool = true, perk_id: String = "") -> Dictionary:
	GameManager.start_new_run("DEFENSE-TEST")
	PerkManager.reset()
	var room := Node2D.new()
	room.name = "CombatFixture"
	add_child(room)
	var p := Player.new()
	var inv := INVENTORY.new()
	inv.name = "Inventory"
	p.add_child(inv)
	room.add_child(p)
	p.set_process(false)
	p.set_physics_process(false)
	inv.bag.fill(null)
	if mythic:
		inv.add_item(ItemDatabase.get_item("mythic_armor"))
		inv.use_or_equip_item(0, p)
	if not perk_id.is_empty():
		PerkManager.add_perk(PerkDatabase.get_perk_by_id(perk_id), p)
	p.base_max_hp = 100
	p.max_hp = 100
	p.hp = 100
	p.current_armor = 0
	return {"room": room, "p": p}

func enemy(f: Dictionary, at: Vector2, label: String = "Enemy", boss: bool = false, seed_value: int = 0) -> Enemy:
	var e := Enemy.new()
	e.name = label
	e.loot_seed = seed_value
	e.position = at
	e.is_active = true
	e.hp = 1000
	e.max_hp = 1000
	e.drop_chance = -1.0
	e.add_to_group("enemies")
	if boss:
		e.add_to_group("boss")
	f.room.add_child(e)
	e.set_physics_process(false)
	return e

func flush() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func test_core_defects() -> void:
	var f := fixture()
	var e := enemy(f, Vector2(20, 0))
	f.p.current_armor = 10
	f.p.take_damage(5)
	await flush()
	check(f.p.hp == 100 and f.p.current_armor == 5 and e.hits.is_empty(), "Fully absorbed damage never triggers thorns")
	f.room.free()
	f = fixture()
	e = enemy(f, Vector2(20, 0))
	f.p.current_armor = 3
	f.p.take_damage(13)
	await flush()
	check(f.p.hp == 90 and e.hits == [3], "Thorns reflects floor(30% of actual HP loss), excluding armor")
	f.room.free()
	f = fixture()
	var a := enemy(f, Vector2(10, 0), "Nearest")
	var b := enemy(f, Vector2(20, 0), "Second")
	var c := enemy(f, Vector2(30, 0), "Third")
	var outside := enemy(f, Vector2(80, 0), "Outside")
	f.p.take_damage(10)
	await flush()
	check(a.hits == [3] and b.hits == [3] and c.hits.is_empty(), "Only two nearest enemies receive thorns")
	check(outside.hits.is_empty(), "Thorns ignores targets outside 70 pixels")
	f.room.free()
	f = fixture()
	e = enemy(f, Vector2(20, 0), "Boss", true)
	f.p.take_damage(20)
	await flush()
	check(e.hits == [3], "Boss receives floor(50% of reflected damage), minimum one")
	f.room.free()
	for perk_id in ["armor_burst", "celestial_barrier"]:
		f = fixture(false, perk_id)
		e = enemy(f, Vector2(20, 0))
		var edge := enemy(f, Vector2(75, 0), "Edge")
		f.p.current_armor = 1
		f.p.take_damage(1)
		await flush()
		var expected := 1 if perk_id == "armor_burst" else 2
		check(e.hits == [expected], "Perk-specific armor-break damage: " + perk_id)
		check(edge.hits == ([] if perk_id == "armor_burst" else [2]), "Perk-specific armor-break radius: " + perk_id)
		f.room.free()

func test_rejections_and_rounding() -> void:
	for mode in ["zero", "negative", "invincible", "dead", "no_mythic", "paused"]:
		var f := fixture(mode != "no_mythic")
		var e := enemy(f, Vector2(20, 0))
		f.p.current_armor = 1
		var amount := 10
		if mode == "zero": amount = 0
		if mode == "negative": amount = -10
		if mode == "invincible": f.p.is_invincible = true
		if mode == "dead": f.p.is_dead = true
		if mode == "paused": get_tree().paused = true
		f.p.take_damage(amount)
		get_tree().paused = false
		await flush()
		check(e.hits.is_empty() and f.p.thorns_cooldown_remaining == 0.0, "No thorns for " + mode)
		if mode != "no_mythic":
			check(f.p.hp == 100 and f.p.current_armor == 1, "Rejected damage preserves health and armor: " + mode)
		f.room.free()
	for amount in [1, 3, 4, 6, 7, 9, 10, 13, 20, 30]:
		var f := fixture()
		var ordinary := enemy(f, Vector2(10, 0), "Ordinary")
		var boss := enemy(f, Vector2(20, 0), "Boss", true)
		f.p.take_damage(amount)
		await flush()
		var expected := maxi(1, floori(amount * 0.30))
		var boss_expected := maxi(1, floori(expected * 0.50))
		check(ordinary.hits == [expected], "Thirty-percent floor/minimum boundary: " + str(amount))
		check(boss.hits == [boss_expected], "Boss half-damage floor/minimum boundary: " + str(amount))
		trace.append(["round", amount, ordinary.hits.duplicate(), boss.hits.duplicate()])
		f.room.free()
	var f := fixture()
	var e := enemy(f, Vector2(20, 0))
	f.p.hp = 5
	f.p.take_damage(10000)
	await flush()
	check(f.p.is_dead and f.p.hp == 0 and e.hits == [1], "Lethal overkill reflects only HP actually lost, not the incoming amount")
	f.room.free()
	f = fixture()
	e = enemy(f, Vector2(20, 0))
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("immortal_will"), f.p)
	f.p.hp = 5
	f.p.take_damage(10000)
	await flush()
	check(not f.p.is_dead and f.p.hp == 50 and e.hits == [1], "Revive preserves bounded HP-loss reflection and existing death prevention")
	f.room.free()

func test_target_selection() -> void:
	var f := fixture()
	var boundary := enemy(f, Vector2(70, 0), "Boundary")
	var outside := enemy(f, Vector2(70.001, 0), "Outside")
	f.p.take_damage(10)
	await flush()
	check(boundary.hits == [3] and outside.hits.is_empty(), "Seventy-pixel boundary is inclusive; beyond it is excluded")
	f.room.free()
	f = fixture()
	var first := enemy(f, Vector2(20, 0), "First")
	var second := enemy(f, Vector2(30, 0), "Second")
	f.p.take_damage(10)
	f.p.is_invincible = false
	f.p.take_damage(10)
	await flush()
	check(f.p.hp == 80 and first.hits == [3] and second.hits == [3], "Two accepted hits in one physics frame share one thorns activation")
	f.room.free()
	f = fixture()
	var dead := enemy(f, Vector2(1, 0), "Dead")
	dead.is_dead = true
	var inactive := enemy(f, Vector2(2, 0), "Inactive")
	inactive.is_active = false
	var queued := enemy(f, Vector2(3, 0), "Queued")
	queued.queue_free()
	var freed := enemy(f, Vector2(4, 0), "Freed")
	freed.free()
	var invalid := Node2D.new()
	invalid.add_to_group("enemies")
	f.room.add_child(invalid)
	var valid := enemy(f, Vector2(10, 0), "Valid")
	valid.add_to_group("enemies")
	var boss := enemy(f, Vector2(20, 0), "Boss", true)
	var third := enemy(f, Vector2(30, 0), "Third")
	f.p.take_damage(10)
	await flush()
	check(dead.hits.is_empty() and inactive.hits.is_empty(), "Dead and inactive enemies cannot occupy target slots")
	check(valid.hits == [3] and boss.hits == [1] and third.hits.is_empty(), "Freed/queued/invalid entries are skipped and boss counts toward two targets")
	check(valid.hits.size() == 1, "Duplicate group registration cannot duplicate thorns damage")
	f.room.free()
	var outcomes: Array = []
	for reverse_order in [false, true]:
		f = fixture()
		var a := enemy(f, Vector2(10, 0), "A", false, 7)
		var b := enemy(f, Vector2(10, 0), "B", false, 7)
		var c := enemy(f, Vector2(10, 0), "C", false, 7)
		if reverse_order:
			for target in [a, b, c]: target.remove_from_group("enemies")
			for target in [c, b, a]: target.add_to_group("enemies")
		f.p.take_damage(10)
		await flush()
		outcomes.append([a.hits.duplicate(), b.hits.duplicate(), c.hits.duplicate()])
		check(a.hits == [3] and b.hits == [3] and c.hits.is_empty(), "Identical-distance/position/seed tie uses reproducible spawn order")
		f.room.free()
	check(outcomes[0] == outcomes[1], "Reversing group iteration leaves equal-distance selection unchanged")
	trace.append(["ties", outcomes])
	# World-space distance must account for differently transformed parents.
	f = fixture()
	var offset_parent := Node2D.new()
	offset_parent.position = Vector2(1000, 0)
	f.room.add_child(offset_parent)
	var far := enemy(f, Vector2(5, 0), "LocalNearWorldFar")
	far.reparent(offset_parent, false)
	var near := enemy(f, Vector2(20, 0), "WorldNear")
	f.p.take_damage(10)
	await flush()
	check(near.hits == [3] and far.hits.is_empty(), "Target radius uses world-space coordinates")
	f.room.free()

func test_blast_configuration_and_events() -> void:
	for perk_id in ["armor_burst", "celestial_barrier"]:
		var f := fixture(false, perk_id)
		var perk := PerkDatabase.get_perk_by_id(perk_id)
		var config: Dictionary = PerkManager.get_armor_break_blast_config()
		var expected := 1 if perk_id == "armor_burst" else 2
		var radius := 70.0 if perk_id == "armor_burst" else 80.0
		check(config.damage == expected and config.radius == radius and config.cooldown == 6.0, "Catalog blast parameters: " + perk_id)
		check(perk.description.contains(str(expected)) and perk.description.contains(str(int(radius))) and perk.description.contains("6"), "Blast UI description includes damage, radius and cooldown: " + perk_id)
		var edge := enemy(f, Vector2(radius, 0), "Boundary")
		var outside := enemy(f, Vector2(radius + 0.01, 0), "Outside")
		f.p.current_armor = 2
		f.p.take_damage(1)
		await flush()
		check(edge.hits.is_empty() and f.p.armor_break_cooldown_remaining == 0.0, "Armor remaining above zero does not blast: " + perk_id)
		f.p.is_invincible = false
		f.p.take_damage(1)
		await flush()
		check(edge.hits == [expected] and outside.hits.is_empty(), "Exact zero armor triggers configured boundary/radius: " + perk_id)
		check(edge.velocity.x == 180.0 and edge.velocity.is_finite(), "Blast knockback remains safe: " + perk_id)
		f.p.is_invincible = false
		f.p.take_damage(1)
		await flush()
		check(edge.hits == [expected], "Already-zero armor cannot retrigger blast: " + perk_id)
		trace.append([perk_id, edge.hits.duplicate(), edge.velocity])
		f.room.free()
	for order in [["armor_burst", "celestial_barrier"], ["celestial_barrier", "armor_burst"]]:
		var f := fixture(false, order[0])
		var armor_before: int = f.p.base_armor
		var delay_before: float = f.p.armor_regen_delay
		PerkManager.add_perk(PerkDatabase.get_perk_by_id(order[1]), f.p)
		var e := enemy(f, Vector2(75, 0))
		f.p.current_armor = 1
		f.p.take_damage(1)
		await flush()
		check(e.hits == [2] and f.p.armor_break_cooldown_remaining > 0.0, "Both perks use one Legendary blast regardless of acquisition order")
		if order[1] == "celestial_barrier":
			check(f.p.base_armor == armor_before + 4 and is_equal_approx(f.p.armor_regen_delay, maxf(1.0, delay_before - 1.5)), "Legendary retains unrelated +4 armor and regeneration bonus")
		f.room.free()
	for mode in ["zero", "negative", "invincible", "dead", "no_perk"]:
		var f := fixture(false, "armor_burst" if mode != "no_perk" else "")
		var e := enemy(f, Vector2(20, 0))
		f.p.current_armor = 1
		var amount := 2
		if mode == "zero": amount = 0
		if mode == "negative": amount = -1
		if mode == "invincible": f.p.is_invincible = true
		if mode == "dead": f.p.is_dead = true
		f.p.take_damage(amount)
		await flush()
		check(e.hits.is_empty(), "No armor-break blast for " + mode)
		f.room.free()

func tick(p: BasePlayer, count: int) -> void:
	for i in range(count): p._tick_defensive_cooldowns()

func test_cooldowns() -> void:
	var f := fixture(true, "armor_burst")
	var e := enemy(f, Vector2(20, 0))
	f.p.current_armor = 1
	f.p.take_damage(11)
	check(f.p.thorns_cooldown_remaining == 2.0 and f.p.armor_break_cooldown_remaining == 6.0, "Initial defensive procs start exact two/six second cooldowns")
	await flush()
	var count := e.hits.size()
	var scans: int = f.p.scans
	f.p.is_invincible = false
	f.p.current_armor = 1
	f.p.take_damage(11)
	await flush()
	check(e.hits.size() == count and f.p.scans == scans, "Same-frame/rapid hits and restored armor cannot bypass either cooldown or rescan targets")
	var thorns_before: float = f.p.thorns_cooldown_remaining
	var blast_before: float = f.p.armor_break_cooldown_remaining
	get_tree().paused = true
	for i in range(3): await get_tree().physics_frame
	check(f.p.thorns_cooldown_remaining == thorns_before and f.p.armor_break_cooldown_remaining == blast_before, "Both defensive cooldowns freeze while paused")
	get_tree().paused = false
	f.p.thorns_cooldown_remaining = 2.0
	f.p.armor_break_cooldown_remaining = 6.0
	var ticks_per_second: int = Engine.physics_ticks_per_second
	tick(f.p, ticks_per_second * 2 - 1)
	check(f.p.thorns_cooldown_remaining > 0.0, "Thorns remains unavailable before two physics seconds")
	tick(f.p, 1)
	check(f.p.thorns_cooldown_remaining == 0.0 and is_equal_approx(f.p.armor_break_cooldown_remaining, 4.0), "Thorns expires at two seconds; blast retains four seconds")
	f.p.is_invincible = false
	f.p.current_armor = 1
	f.p.take_damage(11)
	await flush()
	check(e.hits.size() == count + 1 and e.hits[-1] == 3, "After two seconds only thorns can activate again")
	f.p.armor_break_cooldown_remaining = 4.0
	tick(f.p, ticks_per_second * 4 - 1)
	check(f.p.armor_break_cooldown_remaining > 0.0, "Blast remains unavailable before six total physics seconds")
	tick(f.p, 1)
	check(f.p.armor_break_cooldown_remaining == 0.0, "Blast expires at six total physics seconds")
	f.p.is_invincible = false
	f.p.current_armor = 1
	f.p.take_damage(1)
	await flush()
	check(e.hits.size() == count + 2 and e.hits[-1] == 1, "Armor break can blast again after its shared cooldown")
	f.room.free()

func test_deferred_lifecycle() -> void:
	for mode in ["free", "queued", "detached", "reparented", "dead", "inactive", "floor", "new_run", "source_free"]:
		var f := fixture()
		var e := enemy(f, Vector2(20, 0))
		var hits: Array[int] = e.hits
		f.p.take_damage(10)
		var other := Node2D.new()
		add_child(other)
		match mode:
			"free": e.free()
			"queued": e.queue_free()
			"detached": f.room.remove_child(e)
			"reparented": e.reparent(other)
			"dead": e.is_dead = true
			"inactive": e.is_active = false
			"floor": GameManager.register_level_advance(2)
			"new_run": GameManager.start_new_run("RESTART")
			"source_free": f.room.free()
		await flush()
		check(hits.is_empty(), "Queued defensive damage safely cancels for " + mode)
		if mode == "detached": e.free()
		if is_instance_valid(f.room): f.room.free()
		other.free()

func test_popups_and_combined_effects() -> void:
	var f := fixture(true, "armor_burst")
	var ui := UIProbe.new()
	ui.add_to_group("game_ui")
	f.room.add_child(ui)
	var e := enemy(f, Vector2(20, 0))
	var updates: Array = []
	f.p.stats_changed.connect(func(h, mh, a, ma): updates.append([h, mh, a, ma]))
	f.p.current_armor = 1
	f.p.take_damage(11)
	await flush()
	check(e.hits == [1, 3], "One armor-break plus one thorns proc produce exactly their intended damage")
	check(updates.size() == 1 and updates[0][0] == 90 and updates[0][2] == 0, "Real HP/armor loss preserves the HUD stats signal")
	check(ui.numbers.size() == 3 and ui.banners.size() == 1, "Incoming hit and both target hits each emit one damage number, with one blast banner")
	check(f.p.scans == 2, "Target collection runs only for actual effect activations")
	f.room.free()

func test_target_death_and_boss_apis() -> void:
	var f := fixture()
	var e := enemy(f, Vector2(20, 0))
	e.hp = 1
	f.p.take_damage(10)
	await flush()
	check(e.is_dead and e.hits == [3], "Reflected target death executes the normal enemy lifecycle once")
	f.room.free()
	f = fixture()
	var remover := RemovingEnemy.new()
	remover.name = "Remover"
	remover.position = Vector2(10, 0)
	remover.is_active = true
	remover.hp = 1000
	remover.add_to_group("enemies")
	f.room.add_child(remover)
	var victim := enemy(f, Vector2(20, 0), "RemovedDuringFirstHit")
	var victim_hits: Array[int] = victim.hits
	remover.victim = victim
	f.p.take_damage(10)
	await flush()
	check(remover.hits == [3] and victim_hits.is_empty(), "First target can remove the second before its deferred callback safely")
	f.room.free()
	for path in ["res://Scene/Enemies/Boss/Necromancer/necromancer.tscn", "res://Scene/Enemies/Boss/Orc Rider/orc_rider.tscn"]:
		f = fixture()
		var boss = load(path).instantiate()
		boss.add_to_group("enemies")
		boss.add_to_group("boss")
		f.room.add_child(boss)
		boss.set_physics_process(false)
		boss.position = Vector2(20, 0)
		boss.is_active = true
		boss.hp = 1000
		boss.max_hp = 1000
		f.p.take_damage(20)
		await flush()
		check(boss.hp == 997 and boss.current_phase == 1, "Real boss API receives reduced thorns without changing phase rules: " + path.get_file())
		f.room.free()

func test_rng_isolation() -> void:
	var f := fixture(true, "armor_burst")
	var e := enemy(f, Vector2(20, 0))
	f.p.current_armor = 1
	seed(9182)
	var expected_global := randi()
	seed(9182)
	var combat_state: int = PerkManager.get_combat_rng().state
	var pity: int = GameManager.potion_kills_without_drop
	f.p.take_damage(11)
	await flush()
	check(e.hits == [1, 3] and randi() == expected_global, "Defensive damage consumes no global RNG in headless combat")
	check(PerkManager.get_combat_rng().state == combat_state and GameManager.potion_kills_without_drop == pity, "Defensive effects do not shift combat RNG or potion pity without enemy deaths")
	f.room.free()

func test_retaliation_kill_healing() -> void:
	for lethal in [false, true]:
		var f := fixture()
		var e := enemy(f, Vector2(20, 0))
		e.hp = 1
		var heal_perk := PerkData.new()
		heal_perk.id = "retaliation_heal_regression"
		heal_perk.modifiers = {"on_kill_heal_chance": 1.0}
		PerkManager.add_perk(heal_perk, f.p)
		if lethal: f.p.hp = 5
		f.p.take_damage(10000 if lethal else 10)
		await flush()
		if lethal:
			check(f.p.is_dead and f.p.hp == 0, "Lethal retaliation kill cannot heal a dead player or bypass death processing")
		else:
			check(not f.p.is_dead and f.p.hp == 91, "Nonlethal retaliation kill preserves normal on-kill healing")
		f.room.free()

func test_all_heroes() -> void:
	for scene in GameManager.CHARACTER_SCENES:
		GameManager.start_new_run("HERO-DEFENSE")
		var room := Node2D.new()
		add_child(room)
		var p = scene.instantiate()
		room.add_child(p)
		p.set_process(false)
		p.set_physics_process(false)
		if p.get("intro_active") != null: p.intro_active = false
		if p.get("guarding") != null: p.guarding = false
		p.inventory.bag.fill(null)
		p.inventory.add_item(ItemDatabase.get_item("mythic_armor"))
		p.inventory.use_or_equip_item(0, p)
		p.hp = 100
		p.max_hp = 100
		p.current_armor = 0
		p.is_invincible = false
		var e := enemy({"room": room}, p.position + Vector2(20, 0))
		p.take_damage(10)
		await flush()
		check(p.hp == 90 and e.hits == [3], "Hero inherits real-HP thorns behavior: " + p.hero_balance_id)
		check(p.thorns_cooldown_remaining > 0.0 and p.thorns_cooldown_remaining < 2.0, "Hero inherits physics cooldown despite custom loops: " + p.hero_balance_id)
		room.free()

func test_potion_compatibility() -> void:
	var f := fixture(true, "armor_burst")
	var e := enemy(f, Vector2(20, 0))
	f.p.hp = 50
	f.p.inventory.add_item(ItemDatabase.get_item("common_potion_green"))
	f.p.inventory.use_or_equip_item(0, f.p)
	check(f.p.hp == 53 and f.p.potion_cooldown_remaining == 8.0, "Commit 1 potion healing and cooldown still apply with both defenses equipped")
	f.p.current_armor = 1
	f.p.take_damage(11)
	check(f.p.potion_cooldown_remaining == 8.0 and f.p.potion_max_hp_gained == 0 and GameManager.potion_cooldown_remaining == 8.0, "Defensive procs do not overwrite potion progression or shared potion cooldown")
	await flush()
	check(e.hits == [1, 3] and f.p.hp == 43, "Potion use neither bypasses nor disables defensive combat effects")
	f.room.free()

func test_floor_recreation_and_reset() -> void:
	GameManager.start_new_run("FLOOR-DEFENSE")
	GameManager.set_character_by_index(2)
	var world = load("res://world.tscn").instantiate()
	add_child(world)
	await flush()
	var gen = world.get_node("TileMap")
	var p = gen.the_player
	p.set_physics_process(false)
	var armor_slot: int = p.inventory.get_first_empty_slot()
	p.inventory.add_item(ItemDatabase.get_item("mythic_armor"))
	p.inventory.use_or_equip_item(armor_slot, p)
	PerkManager.add_perk(PerkDatabase.get_perk_by_id("celestial_barrier"), p)
	p.hp = 100
	p.max_hp = 100
	p.current_armor = 1
	p.is_invincible = false
	p.take_damage(11)
	var thorns: float = p.thorns_cooldown_remaining
	var blast: float = p.armor_break_cooldown_remaining
	var armor: int = p.base_armor
	gen.next_level()
	check(gen.the_player == p and p.thorns_cooldown_remaining == thorns and p.armor_break_cooldown_remaining == blast, "Actual floor transition retains both cooldowns on the player")
	await flush()
	check(PerkManager.has_perk("celestial_barrier") and p.base_armor == armor and PerkManager.get_armor_break_blast_config().damage == 2, "Floor transition preserves perk state without duplicate stat application")
	world.free()
	var replacement = GameManager.CHARACTER_SCENES[2].instantiate()
	add_child(replacement)
	replacement.set_physics_process(false)
	check(replacement.thorns_cooldown_remaining > 0.0 and replacement.armor_break_cooldown_remaining > 0.0, "Recreated player restores defensive run cooldowns")
	check(replacement.base_armor == armor, "Recreated player restores active perk armor exactly once")
	GameManager.start_new_run("NEW-DEFENSE-RUN")
	check(replacement.thorns_cooldown_remaining == 0.0 and replacement.armor_break_cooldown_remaining == 0.0 and GameManager.thorns_cooldown_remaining == 0.0 and GameManager.armor_break_cooldown_remaining == 0.0, "New run resets defensive cooldowns on manager and existing player")
	replacement.free()

func test_replay_cooldown_recording() -> void:
	GameManager.start_new_run("DEFENSE-RECORDING")
	GameManager.thorns_cooldown_remaining = 2.0
	GameManager.armor_break_cooldown_remaining = 6.0
	for i in range(5): GameManager.record_frame_input({"dx": 0, "dy": 0, "slot": -1})
	check(GameManager.current_recording_frames.size() == 5, "Defensive cooldowns retain idle replay physics ticks")
	GameManager.thorns_cooldown_remaining = 0.0
	GameManager.armor_break_cooldown_remaining = 0.0
	GameManager.record_frame_input({"dx": 0, "dy": 0, "slot": -1})
	GameManager.record_frame_input({"dx": 0, "dy": 0, "slot": -1})
	check(GameManager.current_recording_frames.size() == 6, "Replay retains cooldown expiry tick and resumes normal idle compression afterward")
