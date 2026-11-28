extends Node2D
## Production presentation only; fixtures keep their original unbounded arenas.
const FLOOR: Texture2D = preload("res://Assets/Map/GuildHall/Walls_interior.png")
const RUG: Texture2D = preload("res://Assets/Map/GuildHall/Decor/rug_lounge.png")
var context: Node
var _draw_step := -1

func configure(value: Node) -> void:
	context = value
	z_index = -10
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Authored hero cameras belong to the run. Frame this fixed arena in full.
	for camera in context.hero.find_children("*", "Camera2D", true, false):
		camera.enabled = false
	context.viewport.canvas_transform = Transform2D.IDENTITY
	for rect in [Rect2(0, 0, 640, 16), Rect2(0, 384, 640, 16), Rect2(0, 0, 16, 400), Rect2(624, 0, 16, 400)]:
		context.world.add_wall(rect)
	if context.session.get_current_step() < 3:
		context.add_target(Vector2(320, 200))
	context.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	context.viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	queue_redraw()

func _draw() -> void:
	for x in 40:
		for y in 25:
			draw_texture_rect_region(FLOOR, Rect2(x * 16, y * 16, 16, 16), Rect2(304, 32, 16, 16))
	draw_texture_rect_region(RUG, Rect2(236, 148, 141, 69), Rect2(0, 0, 141, 69))
	draw_rect(Rect2(16, 16, 608, 368), Color("a57c48"), false, 2)
	for rect in [Rect2(0, 0, 640, 16), Rect2(0, 384, 640, 16), Rect2(0, 0, 16, 400), Rect2(624, 0, 16, 400)]:
		draw_rect(rect, Color("252330"))
	if is_instance_valid(context) and context.session.get_current_step() in [1, 2]:
		draw_arc(Vector2(320, 197), 22, 0, TAU, 24, Color("e6be6a"), 1)
		draw_line(Vector2(320, 147), Vector2(320, 159), Color("f4d58c"), 2)
		draw_line(Vector2(315, 154), Vector2(320, 159), Color("f4d58c"), 2)
		draw_line(Vector2(325, 154), Vector2(320, 159), Color("f4d58c"), 2)

func _physics_process(_delta: float) -> void:
	if is_instance_valid(context) and context.session.get_current_step() != _draw_step:
		_draw_step = context.session.get_current_step()
		queue_redraw()
	if not is_instance_valid(context) or not context.live():
		return
	# Real walls handle walking/dashes; recover from exceptional teleport gadgets.
	var actor: CharacterBody2D = context.hero
	if not Rect2(20, 20, 600, 360).has_point(actor.position):
		actor.position = actor.position.clamp(Vector2(32, 32), Vector2(608, 368))
		actor.velocity = Vector2.ZERO
