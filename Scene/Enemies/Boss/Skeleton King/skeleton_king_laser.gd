extends Node2D
## One Skeleton King laser volley: a set of straight beams (vertical / horizontal),
## each with its own start delay. A beam first shows a charging warning line,
## then fires for a short time and damages the player standing on it.
## Coordinates are local to the dungeon TileMap (this node is its child at 0,0).

const HIT_HALF_WIDTH := 9.0
const PLAYER_HIT_COOLDOWN := 0.45
const FADE_OUT := 0.18

var tilemap: TileMap
var damage: int = 1
var beams: Array[Dictionary] = []
var elapsed: float = 0.0
var hit_cooldown: float = 0.0
var player_hits: int = 0

func add_line(a: Vector2, b: Vector2, delay: float, warn: float, active: float) -> void:
	beams.append({"a": a, "b": b, "start": delay, "warn": warn, "active": active})

func get_total_duration() -> float:
	var total := 0.0
	for beam in beams:
		total = maxf(total, float(beam["start"]) + float(beam["warn"]) + float(beam["active"]) + FADE_OUT)
	return total

func is_beam_active(beam: Dictionary, at_time: float = -1.0) -> bool:
	var t := (elapsed if at_time < 0.0 else at_time) - float(beam["start"])
	return t >= float(beam["warn"]) and t < float(beam["warn"]) + float(beam["active"])

func _ready() -> void:
	z_index = 3
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat

func _physics_process(delta: float) -> void:
	elapsed += delta
	hit_cooldown = maxf(0.0, hit_cooldown - delta)
	var player: Node2D = null
	if is_instance_valid(tilemap) and tilemap.has_method("_resolve_player_node"):
		player = tilemap._resolve_player_node()
	if is_instance_valid(player) and hit_cooldown <= 0.0 and player.get("is_dead") != true:
		var p := to_local(player.global_position)
		for beam in beams:
			if is_beam_active(beam) and _point_on_beam(beam, p):
				player.take_damage(damage)
				player_hits += 1
				hit_cooldown = PLAYER_HIT_COOLDOWN
				break
	queue_redraw()
	if elapsed >= get_total_duration():
		queue_free()

func _point_on_beam(beam: Dictionary, p: Vector2) -> bool:
	var a: Vector2 = beam["a"]
	var b: Vector2 = beam["b"]
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(HIT_HALF_WIDTH, HIT_HALF_WIDTH)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(HIT_HALF_WIDTH, HIT_HALF_WIDTH)
	return p.x >= lo.x and p.x <= hi.x and p.y >= lo.y and p.y <= hi.y

func _draw() -> void:
	for beam in beams:
		var t := elapsed - float(beam["start"])
		if t < 0.0:
			continue
		var a: Vector2 = beam["a"]
		var b: Vector2 = beam["b"]
		var warn := float(beam["warn"])
		var active := float(beam["active"])
		if t < warn:
			# Telegraph: danger band + charge line racing from the emitter to the far wall.
			var k := t / warn
			var pulse := 0.5 + 0.5 * sin(t * 28.0)
			draw_line(a, b, Color(0.85, 0.10, 0.35, 0.10 + 0.10 * k), 16.0)
			draw_line(a, b, Color(1.0, 0.25, 0.45, 0.22 + 0.30 * pulse * k), 1.5)
			draw_line(a, a.lerp(b, k), Color(1.0, 0.55, 0.85, 0.55 + 0.35 * k), 2.0)
			draw_circle(a, 3.0 + 2.0 * k, Color(0.95, 0.35, 1.0, 0.75))
			draw_circle(b, 2.0 + 2.0 * k, Color(0.95, 0.35, 1.0, 0.45 * k))
		elif t < warn + active:
			var phase := (t - warn) / active
			var swell := sin(PI * clampf(phase * 1.4, 0.0, 1.0)) * 0.35 + 0.65
			draw_line(a, b, Color(0.62, 0.12, 1.0, 0.30), 22.0 * swell)
			draw_line(a, b, Color(0.86, 0.38, 1.0, 0.80), 12.0 * swell)
			draw_line(a, b, Color(1.0, 0.92, 1.0, 1.0), 4.0 * swell)
			draw_circle(a, 8.0 * swell, Color(0.95, 0.55, 1.0, 0.9))
			draw_circle(b, 8.0 * swell, Color(0.95, 0.55, 1.0, 0.9))
		elif t < warn + active + FADE_OUT:
			var fade := 1.0 - (t - warn - active) / FADE_OUT
			draw_line(a, b, Color(0.86, 0.38, 1.0, 0.55 * fade), 8.0 * fade)
