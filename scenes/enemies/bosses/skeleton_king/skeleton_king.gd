extends Node2D
## SKELETON KING — giant boss of the fixed arena that replaces the boss room on
## every 3rd floor (3, 6, 9...). He towers over the arena from behind its top
## wall and cannot be hit directly: heroes must shatter his Soul Crystals.
##
## Attacks (all physics-driven + seeded RNG so replays stay in sync):
##   • Slam  -> laser SHOCKWAVE: parallel beams fire one after another, sweeping
##              down from the King or rippling outward from the centre.
##   • Cast  -> laser VOLLEY: evenly spaced parallel vertical OR horizontal beams
##              (enraged: a full grid, or two shifted vertical volleys).
##   • Cast  -> SUMMON: calls the dungeon's existing enemies into the arena.
## Below 50% HP he becomes enraged: faster, more crystals, harsher patterns.

signal boss_hp_changed(current_hp: int, max_hp: int, phase: int, boss_name: String)

const BalanceData = preload("res://scripts/core/balance_config.gd")
const Crystal = preload("res://scenes/enemies/bosses/skeleton_king/skeleton_king_crystal.gd")
const LaserVolley = preload("res://scenes/enemies/bosses/skeleton_king/skeleton_king_laser.gd")
const Atmosphere = preload("res://scenes/dungeon/dungeon_atmosphere.gd")

const BOSS_NAME: String = "SKELETON KING — LORD OF THE BARROW-DOWNS"
const SPRITE_DIR := "res://Assets/Character/Skeleton King/"
const FRAME_SIZE := Vector2(444, 348)
# name: [file, frames, columns, fps, loop] — from skeleton_king_animations.json
const ANIMS: Dictionary = {
	"idle": ["skeleton_king_idle.png", 26, 8, 10.0, true],
	"idle_enraged": ["skeleton_king_idle_enraged.png", 26, 8, 12.0, true],
	"hit": ["skeleton_king_hit.png", 6, 6, 15.0, false],
	"slam": ["skeleton_king_slam.png", 16, 8, 12.0, false],
	"cast": ["skeleton_king_cast.png", 14, 8, 12.0, false],
	"enrage": ["skeleton_king_enrage.png", 18, 8, 12.0, false],
	"death": ["skeleton_king_death.png", 28, 8, 12.0, false],
}
const SLAM_IMPACT_FRAME := 8
const CAST_RELEASE_FRAME := 9
const TILE := 16.0
const WIDTH_RATIO := 0.58      # King width relative to arena width (example layout)
const HUD_TOP_MARGIN := 24.0   # screen px kept for the boss HP bar
const HUD_BOTTOM_MARGIN := 104.0 # screen px kept for the hotbar / skill labels
const BODY_WIDTH_PX := 430.0   # painted body width inside a 444px frame
const ANCHOR_DEPTH := 16.0     # node sits one tile below the top wall line

# Wiring (set by the dungeon generator before add_child)
var tilemap: TileMap
var room_rect: Rect2i = Rect2i()
var room_manager: Node
var level: int = 3

# Stats
var max_hp: int = 60
var hp: int = 60
var current_phase: int = 1
var crystals_to_defeat: int = 5
var crystal_damage: int = 12
var crystal_hp: int = 6
var max_crystals: int = 2
var max_crystals_enraged: int = 3
var crystal_respawn: float = 2.5
var crystal_lifetime: float = 9.0
var crystal_lifetime_enraged: float = 7.5
var crystal_expire_heal_ratio: float = 0.5
var laser_damage: int = 1
var summon_cap: int = 4
var summon_cap_enraged: int = 6
var action_cooldown: float = 2.6
var action_cooldown_enraged: float = 1.7
var enrage_ratio: float = 0.5

# State (is_active is flipped on by RoomManager.lock_room())
var is_active = false
var is_dead: bool = false
var awakened: bool = false
var enraged: bool = false
var pending_enrage: bool = false
var action: String = ""
var action_timer: float = 1.4
var crystal_timer: float = 0.0
var action_count: int = 0
var event_fired: bool = false
var last_pattern: String = ""
var crystals: Array[Node2D] = []
var minions: Array[Node2D] = []
var volleys: Array[Node2D] = []
var rng := RandomNumberGenerator.new()

# Presentation
var sprite: AnimatedSprite2D
var anim_name: String = ""
var anim_time: float = 0.0
var anim_frame: int = -1
var shake_left: float = 0.0
var arena_camera: Camera2D
var player_camera: Camera2D
var arena_light: PointLight2D

static var _frames_cache: SpriteFrames

static func build_sprite_frames() -> SpriteFrames:
	if _frames_cache != null:
		return _frames_cache
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in ANIMS:
		var info: Array = ANIMS[anim]
		var tex: Texture2D = load(SPRITE_DIR + String(info[0]))
		frames.add_animation(anim)
		frames.set_animation_speed(anim, float(info[3]))
		frames.set_animation_loop(anim, bool(info[4]))
		for i in range(int(info[1])):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(Vector2(i % int(info[2]), i / int(info[2])) * FRAME_SIZE, FRAME_SIZE)
			atlas.filter_clip = true
			frames.add_frame(anim, atlas)
	_frames_cache = frames
	return frames

func _ready() -> void:
	var cfg: Dictionary = BalanceData.get_boss_stats("skeleton_king")
	var tier := maxi(1, int(level / 3.0))
	max_hp = int(cfg.get("hp", 60)) + (tier - 1) * int(cfg.get("hp_per_tier", 15))
	hp = max_hp
	crystals_to_defeat = int(cfg.get("crystals_to_defeat", 5)) + (tier - 1)
	crystal_damage = ceili(float(max_hp) / float(crystals_to_defeat))
	crystal_hp = int(cfg.get("crystal_hp", 6)) + (tier - 1) * int(cfg.get("crystal_hp_per_tier", 2))
	max_crystals = int(cfg.get("max_crystals", 2))
	max_crystals_enraged = int(cfg.get("max_crystals_enraged", 3))
	crystal_respawn = float(cfg.get("crystal_respawn", 2.5))
	crystal_lifetime = float(cfg.get("crystal_lifetime", 9.0))
	crystal_lifetime_enraged = float(cfg.get("crystal_lifetime_enraged", 7.5))
	crystal_expire_heal_ratio = float(cfg.get("crystal_expire_heal_ratio", 0.5))
	laser_damage = int(cfg.get("laser_damage", 1)) + (tier - 1)
	summon_cap = int(cfg.get("summon_cap", 4))
	summon_cap_enraged = int(cfg.get("summon_cap_enraged", 6))
	action_cooldown = float(cfg.get("action_cooldown", 2.6))
	action_cooldown_enraged = float(cfg.get("action_cooldown_enraged", 1.7))
	enrage_ratio = float(cfg.get("enrage_ratio", 0.5))
	var seed_str := "SKELETON_KING"
	if get_node_or_null("/root/GameManager") != null:
		seed_str = GameManager.current_seed
	rng.seed = hash(seed_str + "_skeleton_king_" + str(level))

	sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = build_sprite_frames()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var s := get_sprite_scale()
	sprite.scale = Vector2(s, s)
	sprite.centered = true
	sprite.position = Vector2(0, -ANCHOR_DEPTH - FRAME_SIZE.y * s * 0.5)
	# Lit independently of the dark dungeon ambience, like the example layout.
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	sprite.material = unshaded
	sprite.modulate = Color(0.42, 0.42, 0.5) # dormant until the arena seals
	add_child(sprite)
	_play("idle")

func get_sprite_scale() -> float:
	var arena_w := float(maxi(room_rect.size.x, 10)) * TILE
	return arena_w * WIDTH_RATIO / BODY_WIDTH_PX

func get_chest_global() -> Vector2:
	return global_position + Vector2(0, -ANCHOR_DEPTH - FRAME_SIZE.y * get_sprite_scale() * 0.38)

func get_top_local_y() -> float:
	return position.y - ANCHOR_DEPTH - FRAME_SIZE.y * get_sprite_scale()

# ------------------------------------------------------------------ main loop
func _physics_process(delta: float) -> void:
	_step_anim(delta)
	_update_shake(delta)
	if is_dead or not is_active:
		return
	if not awakened:
		_awaken()
	_prune_lists()
	_update_crystals(delta)
	if action == "":
		if pending_enrage:
			_start_enrage()
			return
		action_timer -= delta
		if action_timer <= 0.0:
			_start_next_action()

func _awaken() -> void:
	awakened = true
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.6)
	for i in range(max_crystals):
		_spawn_crystal()
	crystal_timer = crystal_respawn
	action_timer = 1.6
	_setup_arena_camera()
	_setup_arena_light()
	_emit_hp()
	if get_tree():
		get_tree().call_group("game_ui", "show_banner", "THE SKELETON KING RISES — SHATTER HIS SOUL CRYSTALS!", Color(0.9, 0.45, 1.0))

func _start_next_action() -> void:
	action_count += 1
	var cap := summon_cap_enraged if enraged else summon_cap
	var can_summon := minions.size() < cap
	var choice := ""
	if action_count == 1:
		choice = "cast_laser"
	elif action_count == 2 and can_summon:
		choice = "cast_summon"
	else:
		var roll := rng.randf()
		if roll < 0.40:
			choice = "slam"
		elif roll < 0.75 or not can_summon:
			choice = "cast_laser"
		else:
			choice = "cast_summon"
	action = choice
	event_fired = false
	_play("slam" if choice == "slam" else "cast")

func _finish_action() -> void:
	action = ""
	var base := action_cooldown_enraged if enraged else action_cooldown
	action_timer = base + rng.randf_range(0.0, 0.6)
	_play(_idle_anim())

func _idle_anim() -> String:
	return "idle_enraged" if enraged else "idle"

# ------------------------------------------------------------------ animation
func _play(anim: String) -> void:
	anim_name = anim
	anim_time = 0.0
	anim_frame = -1
	sprite.animation = anim
	sprite.stop()
	_set_frame(0)

func _set_frame(frame: int) -> void:
	if frame == anim_frame:
		return
	anim_frame = frame
	sprite.frame = frame
	_on_anim_frame(frame)

func _step_anim(delta: float) -> void:
	if anim_name.is_empty():
		return
	var info: Array = ANIMS[anim_name]
	var count := int(info[1])
	anim_time += delta
	var frame := int(anim_time * float(info[3]))
	if bool(info[4]):
		_set_frame(frame % count)
	elif frame >= count:
		_set_frame(count - 1)
		_on_anim_finished(anim_name)
	else:
		_set_frame(frame)

func _on_anim_frame(frame: int) -> void:
	if event_fired or is_dead:
		return
	if anim_name == "slam" and action == "slam" and frame >= SLAM_IMPACT_FRAME:
		event_fired = true
		_fire_shockwave()
	elif anim_name == "cast" and frame >= CAST_RELEASE_FRAME:
		if action == "cast_laser":
			event_fired = true
			_fire_laser_volley()
		elif action == "cast_summon":
			event_fired = true
			_summon_minions()

func _on_anim_finished(anim: String) -> void:
	match anim:
		"death":
			anim_name = ""
			_restore_camera()
			queue_free()
		"enrage", "slam", "cast", "hit":
			_finish_action()

# ------------------------------------------------------------------ geometry
func _col_x(col: int) -> float:
	return (float(col) + 0.5) * TILE

func _row_y(row: int) -> float:
	return (float(row) + 0.5) * TILE

func _vertical(col: int) -> Array[Vector2]:
	return [Vector2(_col_x(col), room_rect.position.y * TILE), Vector2(_col_x(col), room_rect.end.y * TILE)]

func _horizontal(row: int) -> Array[Vector2]:
	return [Vector2(room_rect.position.x * TILE, _row_y(row)), Vector2(room_rect.end.x * TILE, _row_y(row))]

## Evenly spaced columns/rows across the arena, starting at a shifted offset.
func get_parallel_lines(vertical: bool, spacing: int, offset: int) -> Array[int]:
	var result: Array[int] = []
	var start := room_rect.position.x if vertical else room_rect.position.y
	var end := room_rect.end.x if vertical else room_rect.end.y
	var i := start + offset
	while i < end:
		result.append(i)
		i += spacing
	return result

func _new_volley() -> Node2D:
	var volley: Node2D = LaserVolley.new()
	volley.tilemap = tilemap
	volley.damage = laser_damage
	volleys.append(volley)
	return volley

func _add_volley(volley: Node2D) -> void:
	if is_instance_valid(tilemap):
		tilemap.add_child(volley)

# Slam impact: a shockwave of parallel beams travelling across the arena.
func _fire_shockwave(force_pattern: String = "") -> void:
	shake_left = 0.35
	var patterns: Array[String] = ["wave_down", "wave_out"]
	var pattern := patterns[rng.randi() % patterns.size()]
	if pattern == last_pattern:
		pattern = patterns[(patterns.find(pattern) + 1) % patterns.size()]
	if force_pattern != "":
		pattern = force_pattern
	last_pattern = pattern
	var volley := _new_volley()
	var warn := 0.55 if enraged else 0.65
	var active := 0.32
	if pattern == "wave_down":
		# Horizontal beams, 3 rows apart, rippling down from the King's hands.
		var step := 0.16 if enraged else 0.22
		var rows := get_parallel_lines(false, 3, 1)
		for k in range(rows.size()):
			var line := _horizontal(rows[k])
			volley.add_line(line[0], line[1], k * step, warn, active)
	else:
		# Vertical beams, 3 columns apart, rippling out from the centre to both walls.
		var step := 0.15 if enraged else 0.2
		var center := room_rect.position.x + room_rect.size.x / 2
		for col in get_parallel_lines(true, 3, (center - room_rect.position.x) % 3):
			var line := _vertical(col)
			volley.add_line(line[0], line[1], absi(col - center) / 3 * step, warn, active)
	_add_volley(volley)

# Cast release: evenly spaced parallel beams.
func _fire_laser_volley(force_pattern: String = "") -> void:
	var patterns: Array[String] = ["vertical", "horizontal"]
	if enraged:
		patterns.append_array(["grid", "double_vertical"])
	var pattern := patterns[rng.randi() % patterns.size()]
	if pattern == last_pattern:
		pattern = patterns[(patterns.find(pattern) + 1) % patterns.size()]
	if force_pattern != "":
		pattern = force_pattern
	last_pattern = pattern
	var volley := _new_volley()
	var warn := 0.8 if enraged else 1.0
	var active := 0.45
	match pattern:
		"vertical":
			for col in get_parallel_lines(true, 4, rng.randi_range(1, 3)):
				var line := _vertical(col)
				volley.add_line(line[0], line[1], 0.0, warn, active)
		"horizontal":
			for row in get_parallel_lines(false, 4, rng.randi_range(1, 3)):
				var line := _horizontal(row)
				volley.add_line(line[0], line[1], 0.0, warn, active)
		"grid":
			var off := rng.randi_range(1, 4)
			for col in get_parallel_lines(true, 5, off):
				var v := _vertical(col)
				volley.add_line(v[0], v[1], 0.0, warn, active)
			for row in get_parallel_lines(false, 5, off):
				var h := _horizontal(row)
				volley.add_line(h[0], h[1], 0.0, warn, active)
		"double_vertical":
			var first := rng.randi_range(1, 2)
			for col in get_parallel_lines(true, 4, first):
				var a := _vertical(col)
				volley.add_line(a[0], a[1], 0.0, warn, active)
			for col in get_parallel_lines(true, 4, first + 2):
				var b := _vertical(col)
				volley.add_line(b[0], b[1], warn + active + 0.15, warn * 0.8, active)
	_add_volley(volley)

# ------------------------------------------------------------------ summons
func _summon_minions() -> void:
	if not is_instance_valid(tilemap):
		return
	var scenes: Array = tilemap.get("enemy_scenes")
	if scenes == null or scenes.is_empty():
		return
	var cap := summon_cap_enraged if enraged else summon_cap
	var count := mini(rng.randi_range(3, 4) if enraged else rng.randi_range(2, 3), cap - minions.size())
	for i in range(count):
		var cell := _find_free_cell(4, 2, 4)
		if cell == Vector2i(-9999, -9999):
			break
		var scene: PackedScene = scenes[rng.randi() % scenes.size()]
		var enemy: Node2D = scene.instantiate()
		if "loot_seed" in enemy:
			enemy.loot_seed = rng.randi()
		if level > 1 and "hp" in enemy:
			enemy.hp += (level - 1) * 2
			if "max_hp" in enemy:
				enemy.max_hp = enemy.hp
		if level >= 3 and "damage" in enemy:
			enemy.damage += 1
		enemy.z_index = 2
		enemy.add_to_group("enemies")
		enemy.add_to_group("skeleton_king_minions")
		tilemap.add_child(enemy)
		enemy.position = tilemap.map_to_local(cell)
		enemy.is_active = true
		minions.append(enemy)
		if is_instance_valid(room_manager) and "enemies" in room_manager:
			room_manager.enemies.append(enemy)
		_spawn_ring(enemy.position, Color(0.55, 1.0, 0.65))

# ------------------------------------------------------------------ crystals
func _update_crystals(delta: float) -> void:
	var target := max_crystals_enraged if enraged else max_crystals
	if crystals.size() >= target:
		crystal_timer = minf(crystal_timer, crystal_respawn)
		return
	crystal_timer -= delta
	if crystal_timer <= 0.0:
		_spawn_crystal()
		crystal_timer = crystal_respawn * (0.7 if enraged else 1.0)

func _spawn_crystal() -> Node2D:
	if not is_instance_valid(tilemap):
		return null
	var cell := _find_free_cell(3, 5, 3)
	if cell == Vector2i(-9999, -9999):
		return null
	var crystal: Node2D = Crystal.new()
	crystal.king = self
	crystal.max_hp = crystal_hp
	crystal.lifetime = crystal_lifetime_enraged if enraged else crystal_lifetime
	crystal.name = "SoulCrystal"
	tilemap.add_child(crystal)
	crystal.position = tilemap.map_to_local(cell)
	crystals.append(crystal)
	return crystal

## Called by a crystal when the player shatters it.
func on_crystal_shattered(crystal: Node2D) -> void:
	crystals.erase(crystal)
	if is_dead:
		return
	hp = maxi(0, hp - crystal_damage)
	if get_tree():
		get_tree().call_group("game_ui", "spawn_damage_number", get_chest_global(), crystal_damage, Color(1.0, 0.4, 0.9))
	_emit_hp()
	if hp <= 0:
		_die()
		return
	var flash := create_tween()
	flash.tween_property(sprite, "modulate", Color(1.8, 0.7, 1.8), 0.06)
	flash.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	if not enraged and float(hp) <= float(max_hp) * enrage_ratio:
		pending_enrage = true
	if action == "":
		action = "hit"
		_play("hit")

## Called by a crystal whose lifetime ran out: it returns to the King and heals him.
func get_expire_heal() -> int:
	return maxi(1, ceili(float(crystal_damage) * crystal_expire_heal_ratio))

func on_crystal_expired(crystal: Node2D) -> void:
	crystals.erase(crystal)
	if is_dead:
		return
	var heal := mini(get_expire_heal(), max_hp - hp)
	if heal <= 0:
		return
	hp += heal
	if get_tree():
		get_tree().call_group("game_ui", "spawn_damage_number", get_chest_global(), heal, Color(0.35, 1.0, 0.45))
	_emit_hp()
	var glow := create_tween()
	glow.tween_property(sprite, "modulate", Color(0.8, 1.6, 0.9), 0.08)
	glow.tween_property(sprite, "modulate", Color.WHITE, 0.3)

func _find_free_cell(min_player_dist: int, min_crystal_dist: int, top_margin: int) -> Vector2i:
	var player: Node2D = tilemap._resolve_player_node() if tilemap.has_method("_resolve_player_node") else null
	var player_cell := Vector2i(-9999, -9999)
	if is_instance_valid(player):
		player_cell = tilemap.local_to_map(tilemap.to_local(player.global_position))
	for attempt in range(48):
		var cell := Vector2i(
			rng.randi_range(room_rect.position.x + 2, room_rect.end.x - 3),
			rng.randi_range(room_rect.position.y + top_margin, room_rect.end.y - 3))
		if tilemap.has_method("is_valid_entity_spawn_cell") and not tilemap.is_valid_entity_spawn_cell(cell):
			continue
		if Vector2(cell).distance_to(Vector2(player_cell)) < float(min_player_dist):
			continue
		var blocked := false
		for other in crystals + minions:
			if is_instance_valid(other):
				var other_cell := tilemap.local_to_map(other.position)
				if Vector2(cell).distance_to(Vector2(other_cell)) < float(min_crystal_dist):
					blocked = true
					break
		if not blocked:
			return cell
	return Vector2i(-9999, -9999)

# ------------------------------------------------------------------ phases
func _start_enrage() -> void:
	pending_enrage = false
	enraged = true
	current_phase = 2
	action = "enrage"
	shake_left = 0.6
	_play("enrage")
	_emit_hp()
	if get_tree():
		get_tree().call_group("game_ui", "show_banner", "THE SKELETON KING IS ENRAGED!", Color(1.0, 0.3, 0.45))

func _die() -> void:
	is_dead = true
	hp = 0
	action = "death"
	pending_enrage = false
	_emit_hp()
	for list in [volleys, crystals, minions]:
		for node in list:
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				node.queue_free()
		list.clear()
	if get_node_or_null("/root/GameManager") != null:
		GameManager.register_enemy_kill()
	shake_left = 0.8
	_play("death")

func take_damage(_amount: int) -> void:
	# Invulnerable: only Soul Crystals can wound the King.
	pass

func _emit_hp() -> void:
	boss_hp_changed.emit(hp, max_hp, current_phase, BOSS_NAME)

func _prune_lists() -> void:
	for list in [crystals, minions, volleys]:
		for i in range(list.size() - 1, -1, -1):
			var node = list[i] # untyped: entries may already be freed
			if not is_instance_valid(node) or node.is_queued_for_deletion() or node.get("is_dead") == true:
				list.remove_at(i)

# ------------------------------------------------------------------ camera / fx
func _setup_arena_camera() -> void:
	if not is_instance_valid(tilemap) or not is_inside_tree():
		return
	var left := room_rect.position.x * TILE - TILE
	var right := room_rect.end.x * TILE + TILE
	var top := get_top_local_y() - 8.0
	var bottom := room_rect.end.y * TILE + TILE
	var area := Vector2(right - left, bottom - top)
	var view := get_viewport_rect().size
	var usable := Vector2(view.x, maxf(120.0, view.y - HUD_TOP_MARGIN - HUD_BOTTOM_MARGIN))
	var zoom := minf(usable.x / area.x, usable.y / area.y)
	arena_camera = Camera2D.new()
	arena_camera.name = "SkeletonKingArenaCamera"
	tilemap.add_child(arena_camera)
	# Shift so the arena is centred in the space between the HUD bars.
	var hud_shift := (HUD_BOTTOM_MARGIN - HUD_TOP_MARGIN) * 0.5 / zoom
	var target := tilemap.to_global(Vector2((left + right) * 0.5, (top + bottom) * 0.5 + hud_shift))
	var player: Node2D = tilemap._resolve_player_node() if tilemap.has_method("_resolve_player_node") else null
	if is_instance_valid(player):
		player_camera = player.get_node_or_null("Camera2D") as Camera2D
	if is_instance_valid(player_camera):
		arena_camera.global_position = player_camera.get_screen_center_position()
		arena_camera.zoom = player_camera.zoom
	else:
		arena_camera.global_position = target
		arena_camera.zoom = Vector2(zoom, zoom)
	arena_camera.make_current()
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(arena_camera, "global_position", target, 0.9)
	tween.tween_property(arena_camera, "zoom", Vector2(zoom, zoom), 0.9)

func _restore_camera() -> void:
	if is_instance_valid(player_camera):
		player_camera.make_current()
	if is_instance_valid(arena_camera):
		arena_camera.queue_free()
	arena_camera = null

func _exit_tree() -> void:
	if is_instance_valid(arena_camera) and arena_camera.is_current():
		_restore_camera()

func _setup_arena_light() -> void:
	if DisplayServer.get_name() == "headless":
		return
	arena_light = PointLight2D.new()
	arena_light.texture = Atmosphere.get_radial_light_texture()
	arena_light.color = Color(1.0, 0.82, 0.62)
	arena_light.energy = 0.0
	arena_light.texture_scale = float(room_rect.size.x) * TILE / 128.0
	arena_light.position = Vector2(0, room_rect.size.y * TILE * 0.5)
	add_child(arena_light)
	create_tween().tween_property(arena_light, "energy", 0.75, 1.0)

func _update_shake(delta: float) -> void:
	if not is_instance_valid(arena_camera):
		return
	if shake_left > 0.0:
		shake_left -= delta
		var amp := 3.0 * clampf(shake_left / 0.3, 0.0, 1.0)
		arena_camera.offset = Vector2(sin(shake_left * 91.0), cos(shake_left * 73.0)) * amp
	else:
		arena_camera.offset = Vector2.ZERO

func _spawn_ring(local_pos: Vector2, color: Color) -> void:
	var ring := RingFlash.new()
	ring.color = color
	ring.position = local_pos
	tilemap.add_child(ring)

class RingFlash extends Node2D:
	var color := Color.WHITE
	var age := 0.0
	func _ready() -> void:
		z_index = 3
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = mat
	func _physics_process(delta: float) -> void:
		age += delta
		queue_redraw()
		if age >= 0.5:
			queue_free()
	func _draw() -> void:
		var k := age / 0.5
		draw_arc(Vector2.ZERO, 6.0 + 22.0 * k, 0.0, TAU, 28, Color(color, 1.0 - k), 2.5)
		draw_circle(Vector2.ZERO, 10.0 * (1.0 - k), Color(color, 0.35 * (1.0 - k)))
