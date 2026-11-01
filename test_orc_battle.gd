extends Node2D

var orc: CharacterBody2D
var player: CharacterBody2D

var test_cases = [
	{"name": "DIRECTLY BELOW (35px)", "pos": Vector2(100, 135)},
	{"name": "DIAGONAL BELOW-RIGHT (35px)", "pos": Vector2(124.7, 124.7)},
	{"name": "DIAGONAL BELOW-LEFT (35px)", "pos": Vector2(75.3, 124.7)},
	{"name": "DIRECTLY RIGHT (35px)", "pos": Vector2(135, 100)},
	{"name": "DIRECTLY ABOVE (35px)", "pos": Vector2(100, 65)}
]

var current_idx = 0
var start_armor = 0
var frames = 0

func _ready():
	run_next_test()

func run_next_test():
	if current_idx >= test_cases.size():
		print("\n==================================================")
		print(">>> TAT CA 5/5 TEST CASES DEU PASSED 100%! <<<")
		print("==================================================")
		get_tree().quit(0)
		return

	if orc: orc.queue_free()
	if player: player.queue_free()

	await get_tree().process_frame

	var tc = test_cases[current_idx]
	var orc_scene = load("res://Scene/Enemies/Orc/orc.tscn")
	var player_scene = load("res://Scene/Character/Player 1_Pyrois/player.tscn")

	player = player_scene.instantiate()
	player.position = tc["pos"]
	add_child(player)
	start_armor = player.current_armor

	orc = orc_scene.instantiate()
	orc.position = Vector2(100, 100)
	orc.is_active = true
	add_child(orc)

	frames = 0
	print("\n--- TEST %d: %s ---" % [current_idx + 1, tc["name"]])
	print("Distance: %.1f px" % orc.position.distance_to(player.position))

func _physics_process(_delta):
	if current_idx >= test_cases.size(): return
	frames += 1
	if player and (player.current_armor < start_armor or player.hp < player.max_hp):
		print("PASS! Orc chem trung sau %d frames. Armor: %d/%d" % [frames, player.current_armor, player.max_armor])
		current_idx += 1
		run_next_test()
	elif frames > 120:
		print("FAIL! Orc khong the chem trung sau 120 frames!")
		get_tree().quit(1)
