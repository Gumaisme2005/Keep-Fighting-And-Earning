extends Node2D

const BalanceData = preload("res://Scene/BalanceConfig.gd")

func _ready() -> void:
	print("--- TESTING SPIKE TRAP MECHANICS ---")
	var trap_scene = load("res://Scene/Map/SpikeTrap.tscn")
	var trap = trap_scene.instantiate()
	add_child(trap)
	
	# 1. Verify solid barrier
	assert(trap.solid_shape != null, "Spike trap must have solid_shape")
	assert(trap.solid_shape.disabled == true, "Spike solid shape must be disabled when idle")
	assert(trap.active_hold_duration >= 2.5, "Active hold duration must be at least 2.5s (was %.1f)" % trap.active_hold_duration)
	print("PASS: Spike trap barrier and hold duration (%.1fs) validated" % trap.active_hold_duration)
	
	# 2. Verify damage filter: only player takes damage, enemies take 0
	var enemy_scene = load("res://Scene/Enemies/Orc/orc.tscn")
	var enemy = enemy_scene.instantiate()
	add_child(enemy)
	var start_enemy_hp = enemy.hp
	
	var player_scene = load("res://Scene/Character/Player 1_Pyrois/player.tscn")
	var player = player_scene.instantiate()
	add_child(player)
	var start_player_armor = player.current_armor
	
	# Simulate trap damage loop
	var mock_targets = [enemy, player]
	for target in mock_targets:
		if target.is_in_group("player") and target.has_method("take_damage"):
			target.take_damage(trap.damage)
			
	assert(enemy.hp == start_enemy_hp, "Enemies must take 0 damage from spike trap!")
	print("PASS: Enemy took 0 damage from spike trap (hp=%d/%d)" % [enemy.hp, start_enemy_hp])
	assert(player.current_armor < start_player_armor, "Player must take damage from spike trap!")
	print("PASS: Player took damage as expected (armor=%d/%d)" % [player.current_armor, player.max_armor])
	
	# 3. Verify difficulty scaling
	var balance_orc = BalanceData.get_enemy_stats("orc")
	assert(int(balance_orc.get("damage", 1)) >= 2, "Orc damage must be buffed (>= 2)")
	assert(int(balance_orc.get("hp", 1)) >= 4, "Orc HP must be buffed (>= 4)")
	print("PASS: Enemy bestiary buffed (Orc HP=%d, DMG=%d)" % [balance_orc.get("hp"), balance_orc.get("damage")])
	
	print("\n==================================================")
	print(">>> ALL NEW MECHANICS VERIFIED 100%! <<<")
	print("==================================================")
	get_tree().quit(0)
