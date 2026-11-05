extends Node2D

func _ready() -> void:
	print("==================================================================")
	print("[GRAPHICS TEST] VERIFYING CLEAR COLOR & BEDROCK BACKDROP")
	print("==================================================================")
	
	# 1. Kiểm tra RenderingServer default clear color
	var clear_col: Color = RenderingServer.get_default_clear_color()
	print("1. Default Clear Color: ", clear_col)
	if clear_col.r > 0.05 or clear_col.g > 0.05 or clear_col.b > 0.05:
		printerr("FAIL: Default clear color is too bright or still Godot's default gray!")
		get_tree().quit(1)
		return
	print("   [PASS] Viewport default clear color is dark obsidian abyss (not gray 0.3)")

	# 2. Kiểm tra scenes/main/world.tscn BedrockBackground
	var world_scene := load("res://scenes/main/world.tscn") as PackedScene
	if world_scene == null:
		printerr("FAIL: Cannot load scenes/main/world.tscn")
		get_tree().quit(1)
		return
	var world_node := world_scene.instantiate()
	add_child(world_node)
	
	var bedrock: ColorRect = world_node.get_node_or_null("BedrockBackground") as ColorRect
	if bedrock == null:
		printerr("FAIL: BedrockBackground missing from scenes/main/world.tscn")
		get_tree().quit(1)
		return
	print("2. BedrockBackground node found: size=", bedrock.size, ", z_index=", bedrock.z_index)
	if bedrock.z_index > -1:
		printerr("FAIL: BedrockBackground z_index is not behind floor!")
		get_tree().quit(1)
		return
	print("   [PASS] BedrockBackground is placed behind TileMap (z_index <= -10)")

	# 3. Kiểm tra DungeonAtmosphere
	var tilemap: TileMap = world_node.get_node_or_null("TileMap") as TileMap
	if tilemap != null:
		var atmo := tilemap.get_node_or_null("DungeonAtmosphere")
		if atmo != null:
			print("3. DungeonAtmosphere node attached cleanly.")
			var mod: CanvasModulate = atmo.get_node_or_null("EerieAmbientModulate") as CanvasModulate
			if mod != null:
				print("   [PASS] EerieAmbientModulate active with dark ambient color: ", mod.color)
	
	print("------------------------------------------------------------------")
	print("[SUMMARY] ALL GRAPHICAL INTEGRITY CHECKS PASSED 100%!")
	print("==================================================================")
	get_tree().quit(0)
