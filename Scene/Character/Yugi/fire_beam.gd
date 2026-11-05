extends Node2D

const Sprites = preload("res://Scene/Character/Yugi/YugiSprites.gd")
var bodies: Array[AtlasTexture] = []
var tips: Array[AtlasTexture] = []
var length := 0.0
var phase := 0

func _ready() -> void:
	material = Sprites.material()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var texture := preload("res://Assets/Character/Yugi/result-5-attack.png")
	for rect in [Rect2(27, 8, 24, 30), Rect2(164, 4, 24, 40)]:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = rect
		atlas.filter_clip = true
		bodies.append(atlas)
	for rect in [Rect2(27, 43, 42, 55), Rect2(164, 50, 42, 65)]:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = rect
		atlas.filter_clip = true
		tips.append(atlas)

func aim(origin: Vector2, endpoint: Vector2, state: int) -> void:
	global_position = origin
	rotation = (endpoint - origin).angle()
	length = origin.distance_to(endpoint)
	phase = state % 2
	queue_redraw()

func _draw() -> void:
	if bodies.is_empty() or length <= 0: return
	var height := 15.0 if phase == 0 else 20.0
	var tip_width := minf(21.0, length)
	# Stretch the repeatable body; keep the rounded flame head at the target.
	if length > tip_width:
		draw_texture_rect(bodies[phase], Rect2(0, -height / 2, length - tip_width, height), false)
	var tip_height := 27.5 if phase == 0 else 32.5
	draw_texture_rect(tips[phase], Rect2(length - tip_width, -tip_height / 2, tip_width, tip_height), false)
