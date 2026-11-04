extends Node2D
## Frost Bloom: a 96x40 line of ice spikes in front of Miyabi. The node sits on the centre of
## the spike frame (her frame centre + (56, 0)), so the frame's bottom row is the ground in
## front of her feet. The spikes grow outward over frames 1-6 and strike enemies as they reach
## them (damage + freeze); on frame 8 the line shatters and the shards hit again.

const Sprites = preload("res://Scene/Character/Miyabi/MiyabiSprites.gd")
const Util = preload("res://Scene/Character/Miyabi/miyabi_util.gd")

const FPS := 14.0
const HALF_W := 48.0                          # frame px from the centre to either end
const GROW: Array = [12, 26, 43, 58, 75, 90]  # front of the spikes (frame px from the near end), frames 1..6
const FULL_REACH := 90.0
const SHATTER_FRAME := 8
const DEPTH_UP := 30.0                        # hurtbox centres this far above the ground line are hit...
const DEPTH_DOWN := 8.0                       # ...and this far below it

var facing: float = 1.0
var damage: int = 3
var shatter_damage: int = 1
var freeze_time: float = 1.2
var age: float = 0.0
var struck: Dictionary = {}
var shattered: bool = false
var wall_limit: float = FULL_REACH
var sprite: AnimatedSprite2D

func _ready() -> void:
	z_index = 3
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Sprites.build(["ice_spikes"])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * Sprites.SCALE
	sprite.flip_h = facing < 0.0
	sprite.use_parent_material = true
	add_child(sprite)
	sprite.play("ice_spikes")

## Spikes cannot strike through a wall that cuts across the line (measured once placed).
func _measure_walls(world: Node) -> void:
	var d := 0.0
	while d <= FULL_REACH:
		if Util.is_wall(world, _line_point(d)):
			wall_limit = maxf(d - 4.0, 0.0)
			return
		d += 6.0

## Point on the ground line `d` frame px from the near end of the spikes.
func _line_point(d: float) -> Vector2:
	var s := Sprites.SCALE
	return global_position + Vector2((d - HALF_W) * s * facing, 14.0 * s)

func _physics_process(delta: float) -> void:
	var world := get_parent()
	if age == 0.0:
		_measure_walls(world)
	age += delta
	var frame := int(age * FPS)
	if frame >= 1 and frame < SHATTER_FRAME:
		var reach: float = float(GROW[mini(frame, GROW.size()) - 1])
		for t in _zone(world, minf(reach, wall_limit)):
			var id: int = t.get_instance_id()
			if struck.has(id):
				continue
			struck[id] = true
			Util.hit(world, t, damage, freeze_time)
	if frame >= SHATTER_FRAME and not shattered:
		shattered = true
		for t in _zone(world, minf(FULL_REACH, wall_limit)):
			Util.hit(world, t, shatter_damage)
	if age >= Sprites.duration("ice_spikes"):
		queue_free()

## Enemies whose hurtbox lies over the first `reach` frame px of the spike line.
func _zone(world: Node, reach: float) -> Array:
	var s := Sprites.SCALE
	var ground_y := global_position.y + 20.0 * s
	var origin := _line_point(0.0)
	var result: Array = []
	for t in Util.enemies(world):
		var p := Util.hit_point(t)
		var from_near := ((p.x - global_position.x) * facing) / s + HALF_W
		if from_near < -6.0 or from_near > reach + 6.0:
			continue
		if p.y < ground_y - DEPTH_UP or p.y > ground_y + DEPTH_DOWN:
			continue
		if not Util.sees(world, origin, p):
			continue
		result.append(t)
	return result
