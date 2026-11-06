extends "res://Scene/Character/Player 1_Pyrois/player.gd"
## DORAEMON — gadget cat from the 22nd century (6th hero, index 5).
## Sprites and move set come from the M.U.G.E.N character "DORAemon" (doraemon.sff / .air /
## .cns, original by SUGIO, edited by KAIemon / カイリ), adapted to a top-down dungeon.
##
## 4D POCKET controls
##   Mouse wheel / Z / X  switch gadget page (10 pages, 20 gadgets)
##   Left / Right click   use the page's two gadgets (hold to keep using them)
##   Q                    summon the next friend (6 in rotation) — or, when at least one
##                        power bar is full, the page's SUPER move
##   F                    eat a Dorayaki (heal + power)
## Power gauge: 3 bars (300). Filled by landing hits and by taking damage.
## Everything advances in _physics_process and is recorded in the replay stream.

const Sprites = preload("res://Scene/Character/Doraemon/DoraemonSprites.gd")
const Util = preload("res://Scene/Character/Doraemon/dora_util.gd")
const Projectile = preload("res://Scene/Character/Doraemon/dora_projectile.gd")
const Walker = preload("res://Scene/Character/Doraemon/dora_walker.gd")
const Fx = preload("res://Scene/Character/Doraemon/dora_fx.gd")
const Hud = preload("res://Scene/Character/Doraemon/dora_hud.gd")
const AirShot = preload("res://Scene/Character/Doraemon/air_cannon_shot.gd")
const TRex = preload("res://Scene/Character/Doraemon/trex_summon.gd")
const DoorGhost = preload("res://Scene/Character/Doraemon/door_ghost.gd")

const SPRITE_SCALE := 0.9
const FEET_Y := 3.0
const POWER_MAX := 300.0
const BAR := 100.0
const DOOR_TELEPORT_TIME := 0.3
const FRIEND_COOLDOWN := 8.0
const EAT_COOLDOWN := 12.0
const ENEMY_PROJECTILES := ["res://Scene/Projectiles/enemy_arrow.gd", "res://Scene/Projectiles/magic_spell.gd"]

const PAGES: Array = [
	{"name": "Air Cannon / Door", "lmb": "air_cannon", "rmb": "door", "super": "uradoraman"},
	{"name": "Kick / Glove", "lmb": "kick", "rmb": "glove", "super": "sl_chimney"},
	{"name": "Air Pistol / Shock Gun", "lmb": "air_pistol", "rmb": "shock_gun", "super": "nobita_rush"},
	{"name": "Ataru Gun / Missile", "lmb": "ataru_gun", "rmb": "pencil_missile", "super": "friendship_controller"},
	{"name": "Shock-wave / Bubbles", "lmb": "shockwave_pistol", "rmb": "bubble_pistol", "super": "shizuka_bath"},
	{"name": "Thundercloud / Stick", "lmb": "thundercloud", "rmb": "shock_stick", "super": "dorami_balloon"},
	{"name": "Magic Hand / Screw", "lmb": "magic_hand", "rmb": "hustle_screw", "super": "gian_recital"},
	{"name": "Grenades / Fishing", "lmb": "grenades", "rmb": "fishing_pond", "super": "junk_barrage"},
	{"name": "Kibi-dango / Mini-Dora", "lmb": "kibidango", "rmb": "minidora", "super": "everyone_takecopter"},
	{"name": "Korobashiya / Mantle", "lmb": "korobashiya", "rmb": "hirari_mantle", "super": "dorayakin"},
]
# id: [name, cooldown s, pose animation, effect time s, action lock s, power cost]
const MOVES: Dictionary = {
	"air_cannon": ["Air Cannon", 0.5, "attack_1", 0.1, 0.25, 0],
	"door": ["Anywhere Door", 6.0, "door_in", 0.0, 0.0, 0],
	"kick": ["Kick", 0.32, "kick", 0.05, 0.2, 0],
	"glove": ["Champion Glove", 1.3, "glove", 0.03, 0.4, 0],
	"air_pistol": ["Air Pistol", 1.4, "pistol", 0.05, 0.45, 0],
	"shock_gun": ["Shock Gun", 3.0, "shockgun", 0.15, 0.45, 0],
	"ataru_gun": ["Ataru Gun", 2.5, "ataru", 0.12, 0.35, 0],
	"pencil_missile": ["Pencil Missile", 3.0, "pocket", 0.12, 0.35, 0],
	"shockwave_pistol": ["Shock-wave Pistol", 2.0, "shockwave", 0.1, 0.3, 0],
	"bubble_pistol": ["Bubble Pistol", 3.0, "bubble", 0.12, 0.35, 0],
	"thundercloud": ["Mini Thundercloud", 3.5, "summon", 0.1, 0.35, 0],
	"shock_stick": ["Shock Stick", 2.5, "stick", 0.12, 0.5, 0],
	"magic_hand": ["Magic Hand", 1.0, "magichand", 0.05, 0.4, 0],
	"hustle_screw": ["Hustle Screw", 4.0, "screw", 0.0, 0.0, 0],
	"grenades": ["Grenades", 4.0, "throw", 0.1, 0.3, 0],
	"fishing_pond": ["Fishing Pond", 5.0, "pocket", 0.15, 0.45, 0],
	"kibidango": ["Kibi-dango T-Rex", 8.0, "skill", 0.17, 0.4, 0],
	"minidora": ["Mini-Dora March", 7.0, "summon", 0.15, 0.4, 0],
	"korobashiya": ["Korobashiya (10 power)", 9.0, "pocket", 0.15, 0.4, 10],
	"hirari_mantle": ["Hirari Mantle", 4.0, "mantle", 0.0, 0.0, 0],
}
const FRIENDS: Array = ["nobita", "gian", "shizuka", "dorami", "suneo", "cat"]
const FRIEND_NAMES: Dictionary = {"nobita": "Nobita", "gian": "Gian", "shizuka": "Shizuka", "dorami": "Dorami", "suneo": "Suneo", "cat": "Come-come Cat"}
# id: [name, pose animation, effect time s, action lock s, uses all full bars]
const SUPERS: Dictionary = {
	"uradoraman": ["Uradoraman", "summon", 0.0, 0.0, false],
	"sl_chimney": ["SL Chimney", "sl_run", 0.0, 0.0, false],
	"nobita_rush": ["Nobita's Air Pistol Rush", "summon", 0.2, 0.45, false],
	"friendship_controller": ["Friendship Controller", "summon", 0.0, 0.0, false],
	"shizuka_bath": ["Shizuka's Bath", "summon", 0.2, 0.45, false],
	"dorami_balloon": ["Dorami's Balloon", "summon", 0.2, 0.45, false],
	"gian_recital": ["Gian Recital (all bars)", "summon", 0.2, 0.5, true],
	"junk_barrage": ["\"Nanika nai ka!\" Junk (all bars)", "panic", 0.15, 1.2, true],
	"everyone_takecopter": ["Everyone Take-copter!", "summon", 0.2, 0.5, false],
	"dorayakin": ["Dorayakin (all bars)", "summon", 0.2, 0.5, true],
}

var page: int = 0
var power: float = 0.0
var friend_index: int = 0
var friend_cd: float = 0.0
var eat_cd: float = 0.0
var cooldowns: Dictionary = {}
var trex_damage_mult: int = 3
var door_range: float = 96.0
var air_shot_speed: float = 300.0
var air_shot_range: float = 190.0

var pending_page: int = 0
var pending_eat: bool = false
var rng := RandomNumberGenerator.new()

var _cast_move: String = ""
var _cast_t: float = 0.0
var _cast_fired: bool = false
var _cast_release: float = 0.0
var _cast_lock: float = 0.0
var _cast_aim: Vector2 = Vector2.RIGHT * 32.0
var _cast_bars: int = 1
var _events: Array = []          # [[seconds_left, Callable]]
var _mode: String = ""
var _mode_t: float = 0.0
var _mode_data: Dictionary = {}
var hud: CanvasLayer

func _ready() -> void:
	hero_balance_id = "doraemon"
	var cfg: Dictionary = BalanceData.get_hero_stats("doraemon")
	trex_damage_mult = int(cfg.get("trex_damage_mult", 3))
	door_range = float(cfg.get("door_range", 96.0))
	air_shot_speed = float(cfg.get("air_shot_speed", 300.0))
	air_shot_range = float(cfg.get("air_shot_range", 190.0))
	for m in MOVES:
		cooldowns[m] = 0.0
	super._ready()
	var seed_str := "DORAEMON"
	if get_node_or_null("/root/GameManager") != null:
		seed_str = GameManager.current_seed + ":" + str(GameManager.current_level)
	rng.seed = hash(seed_str + ":doraemon")
	var anims: Array = ["idle", "walk", "hurt", "death", "attack_1", "kick", "glove", "pistol", "ataru", "shockwave", "pocket",
		"throw", "skill", "summon", "bubble", "shockgun", "magichand", "magichand_grip", "mantle", "door_in", "door_out", "screw", "stick",
		"eat", "panic", "sl_run", "uradora_tf", "uradora_kick", "punch_fly"]
	animated_sprite.sprite_frames = Sprites.build(anims)
	animated_sprite.centered = false
	animated_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	animated_sprite.position = Vector2(0, FEET_Y)
	if not animated_sprite.animation_changed.is_connected(_sync_anchor):
		animated_sprite.animation_changed.connect(_sync_anchor)
	animated_sprite.play("idle")
	_sync_anchor()
	hud = Hud.new()
	add_child(hud)
	_refresh_ui()

func _sync_anchor() -> void:
	var anim := String(animated_sprite.animation)
	if not Sprites.ANIMS.has(anim):
		anim = "idle"
	animated_sprite.offset = Sprites.offset(anim, animated_sprite.flip_h)

func _play(anim: String) -> void:
	if animated_sprite.animation != anim or not animated_sprite.is_playing():
		animated_sprite.play(anim)
	_sync_anchor()

func _set_flip(left: bool) -> void:
	if animated_sprite.flip_h != left:
		animated_sprite.flip_h = left
		_sync_anchor()
	# Keep the (inherited) sword hitbox on the side Doraemon faces, like the base hero does.
	sword_hitbox.scale.x = -1.0 if left else 1.0

# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if is_dead or (get_node_or_null("/root/GameManager") != null and GameManager.is_replaying):
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			pending_page -= 1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			pending_page += 1
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z:
			pending_page -= 1
		elif event.keycode == KEY_X:
			pending_page += 1
		elif event.keycode == KEY_F:
			pending_eat = true

func add_power(amount: float) -> void:
	power = clampf(power + amount, 0.0, POWER_MAX)

func current_page() -> Dictionary:
	return PAGES[page]

# ------------------------------------------------------------------ main loop
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if is_hurt:
		_hurt_timer -= delta
		if _hurt_timer <= 0.0:
			is_hurt = false
	for m in cooldowns:
		cooldowns[m] = maxf(0.0, float(cooldowns[m]) - delta)
	friend_cd = maxf(0.0, friend_cd - delta)
	eat_cd = maxf(0.0, eat_cd - delta)
	_tick_events(delta)

	var gm = get_node_or_null("/root/GameManager")
	var replaying: bool = gm != null and gm.is_replaying
	var f: Dictionary = {}
	if replaying:
		if replay_frame_idx < gm.replay_frames.size():
			f = gm.replay_frames[replay_frame_idx]
			replay_frame_idx += 1
		else:
			gm.is_replaying = false
			if get_tree():
				get_tree().call_group("game_ui", "show_banner", "COMBAT REPLAY CONCLUDED", Color(0.4, 1.0, 0.6))
	else:
		var dir_in := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var aim := get_global_mouse_position() - global_position
		f = {"dx": snappedf(dir_in.x, 0.01), "dy": snappedf(dir_in.y, 0.01), "ax": snappedf(aim.x, 0.5), "ay": snappedf(aim.y, 0.5),
			"atk": Input.is_action_pressed("attack"), "rmb": Input.is_action_pressed("skill_2"), "q": pending_q_skill,
			"slot": pending_hotbar_slot, "pg": pending_page, "eat": pending_eat}
		pending_q_skill = false
		pending_rmb_skill = false
		pending_hotbar_slot = -1
		pending_page = 0
		pending_eat = false
		if gm != null:
			gm.record_frame_input(f)
	var direction := Vector2(float(f.get("dx", 0.0)), float(f.get("dy", 0.0)))
	current_aim_offset = Vector2(float(f.get("ax", 32.0)), float(f.get("ay", 0.0)))
	if int(f.get("pg", 0)) != 0:
		page = posmod(page + int(f.get("pg", 0)), PAGES.size())
	if int(f.get("slot", -1)) >= 0:
		inventory.use_or_equip_item(int(f.get("slot", -1)), self)

	if _mode != "":
		_step_mode(delta, direction)
		_refresh_ui()
		return
	if _cast_move != "":
		_step_cast(delta)
		velocity = direction * speed * 0.35
		move_and_slide()
		_refresh_ui()
		return

	_set_flip(current_aim_offset.x < 0.0)
	var pg: Dictionary = current_page()
	if bool(f.get("eat", false)) and eat_cd <= 0.0:
		_start_eat()
	elif bool(f.get("q", false)):
		_on_q()
	elif bool(f.get("rmb", false)) and float(cooldowns[pg["rmb"]]) <= 0.0:
		_use(String(pg["rmb"]))
	elif bool(f.get("atk", false)) and float(cooldowns[pg["lmb"]]) <= 0.0:
		_use(String(pg["lmb"]))
	if _mode == "" and _cast_move == "":
		var effective_speed: float = get_effective_speed()
		velocity = direction * effective_speed
		move_and_slide()
		if not is_hurt:
			_play("walk" if direction != Vector2.ZERO else "idle")
	_refresh_ui()

func _refresh_ui() -> void:
	var pg: Dictionary = current_page()
	var lmb := String(pg["lmb"])
	var rmb := String(pg["rmb"])
	var sup := String(pg["super"])
	var super_ready := power >= BAR
	q_cd_remaining = 0.0 if super_ready else friend_cd
	skill_cooldown = FRIEND_COOLDOWN
	rmb_cd_remaining = float(cooldowns[rmb])
	rmb_cd_max = float(MOVES[rmb][1])
	if hud != null:
		hud.refresh({"page": page, "pages": PAGES.size(), "page_name": pg["name"],
			"lmb": MOVES[lmb][0], "lmb_cd": cooldowns[lmb], "rmb": MOVES[rmb][0], "rmb_cd": cooldowns[rmb],
			"super_ready": super_ready, "super": SUPERS[sup][0], "friend": FRIEND_NAMES[FRIENDS[friend_index]],
			"q_cd": friend_cd, "eat_cd": eat_cd, "power": power})

# ------------------------------------------------------------------ helpers
func _world() -> Node:
	return get_parent()

func _dmg() -> int:
	return get_total_damage()

func _aim_dir() -> Vector2:
	var d := _cast_aim.normalized()
	if d == Vector2.ZERO:
		d = Vector2.LEFT if animated_sprite.flip_h else Vector2.RIGHT
	return d

func _muzzle() -> Vector2:
	return global_position + Vector2(0, -12) + _aim_dir() * 10.0

## Point under the cursor, clamped to `max_dist` and kept on open floor.
func _aim_point(max_dist: float) -> Vector2:
	var d := minf(_cast_aim.length(), max_dist)
	return Util.safe_point(_world(), global_position, _aim_dir(), maxf(d, 16.0), 8.0) if d > 8.0 else global_position

## Enemy closest to the cursor (within `radius` of it) that Doraemon can see.
func _target_near_cursor(radius: float = 60.0, max_range: float = 220.0) -> Node2D:
	var cursor := global_position + _cast_aim
	var best: Node2D = null
	var best_d := radius
	for t in Util.enemies(_world()):
		var p := Util.hit_point(t)
		if p.distance_to(global_position) > max_range or not Util.sees(_world(), global_position + Vector2(0, -8), p):
			continue
		var d := p.distance_to(cursor)
		if d <= best_d:
			best_d = d
			best = t
	return best

func _spawn(node: Node2D, at: Vector2) -> Node2D:
	var w := _world()
	if w is Node2D:
		node.position = (w as Node2D).to_local(at)
	else:
		node.position = at
	w.add_child(node)
	return node

func _proj(anim: String, at: Vector2, vel: Vector2, dmg: int, props: Dictionary = {}) -> Node2D:
	var p: Node2D = Projectile.new()
	p.caster = self
	p.anim = anim
	p.velocity = vel
	p.damage = dmg
	for k in props:
		p.set(k, props[k])
	return _spawn(p, at)

func _walker(anim: String, at: Vector2, vel: Vector2, dmg: int, props: Dictionary = {}) -> Node2D:
	var w: Node2D = Walker.new()
	w.caster = self
	w.anim = anim
	w.velocity = vel
	w.damage = dmg
	for k in props:
		w.set(k, props[k])
	return _spawn(w, at)

func _fx(anim: String, at: Vector2, k: float = 0.9, flipped: bool = false, life_s: float = -1.0) -> Node2D:
	var fx := Fx.spawn(_world(), anim, at, k, flipped, life_s)
	if fx != null:
		fx.caster = self
	return fx

func _schedule(delay: float, fn: Callable) -> void:
	_events.append([delay, fn])

func _tick_events(delta: float) -> void:
	if _events.is_empty():
		return
	var due: Array = []
	for e in _events:
		e[0] = float(e[0]) - delta
		if float(e[0]) <= 0.0:
			due.append(e)
	for e in due:
		_events.erase(e)
		if not is_dead:
			(e[1] as Callable).call()

func _hit_list(targets: Array, dmg: int, stun_time: float = 0.0, fx_anim: String = "spark") -> int:
	var n := 0
	for t in targets:
		if is_instance_valid(t) and Util.sees(_world(), global_position + Vector2(0, -8), Util.hit_point(t)):
			if fx_anim != "":
				_fx(fx_anim, Util.hit_point(t), 0.4, false, 0.2)
			Util.hit(self, t, dmg, stun_time)
			n += 1
	return n

# ------------------------------------------------------------------ gadget use
func _use(move: String) -> void:
	var info: Array = MOVES[move]
	if power < float(info[5]):
		if get_tree():
			get_tree().call_group("game_ui", "spawn_damage_number", global_position + Vector2(0, -30), int(info[5]), Color(0.5, 0.7, 1.0))
		cooldowns[move] = 0.5
		return
	_cast_aim = current_aim_offset
	match move:
		"door":
			if not _start_door():
				return
		"hustle_screw":
			_start_screw()
		"hirari_mantle":
			_start_mantle()
		_:
			_begin_cast(move, String(info[2]), float(info[3]), float(info[4]))
	power -= float(info[5])
	cooldowns[move] = float(info[1])

func _begin_cast(move: String, pose: String, release: float, lock: float) -> void:
	_cast_move = move
	_cast_t = 0.0
	_cast_fired = false
	_cast_release = release
	_cast_lock = maxf(lock, release + 0.02)
	is_casting_skill = true
	_set_flip(_cast_aim.x < 0.0)
	animated_sprite.play(pose)
	_sync_anchor()

func _step_cast(delta: float) -> void:
	_cast_t += delta
	if not _cast_fired and _cast_t >= _cast_release:
		_cast_fired = true
		var fn := "_do_" + _cast_move
		if has_method(fn):
			call(fn)
	if _cast_t >= _cast_lock:
		_cast_move = ""
		is_casting_skill = false
		if not is_dead and not is_hurt:
			_play("idle")

# --- Page 1 -------------------------------------------------------------
func _do_air_cannon() -> void:
	var shot: Node2D = AirShot.new()
	shot.direction = _aim_dir()
	shot.speed = air_shot_speed
	shot.max_distance = air_shot_range
	shot.damage = _dmg()
	shot.shooter_origin = global_position
	shot.caster = self
	_spawn(shot, _muzzle())
	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_sfx("slash", 0.7, 0.8)

## Farthest safe floor point towards the aim, without passing walls or closed gates.
func find_door_destination(aim: Vector2) -> Vector2:
	var dir := aim.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.LEFT if animated_sprite.flip_h else Vector2.RIGHT
	return Util.safe_point(_world(), global_position, dir, minf(door_range, maxf(aim.length(), 24.0)), 16.0)

func _start_door() -> bool:
	var target := find_door_destination(_cast_aim)
	if target == global_position:
		return false
	_enter_mode("door", {"target": target, "fired": false})
	is_invincible = true
	_play("door_in")
	return true

# --- Page 2 -------------------------------------------------------------
func _do_kick() -> void:
	var c := global_position + Vector2(0, -10)
	_hit_list(Util.on_segment(_world(), c, c + _aim_dir() * 20.0, 9.0), _dmg(), 0.0, "puff")

## Champion Glove (MUGEN: 3 hits whose reach grows with the spring, each one knocking the
## opponent away). Every beat shoves the enemy back; the last one sends it flying and dazes it.
## [delay after release, reach px, shove px, daze s] - synced with the glove sprite (ticks 2 / 4 / 7).
const GLOVE_BEATS: Array = [[0.0, 24.0, 8.0, 0.0], [0.04, 38.0, 8.0, 0.0], [0.08, 54.0, 34.0, 0.35]]

func _do_glove() -> void:
	var dir := _aim_dir()
	for beat in GLOVE_BEATS:
		var b: Array = beat
		if float(b[0]) <= 0.0:
			_glove_beat(dir, float(b[1]), float(b[2]), float(b[3]))
		else:
			_schedule(float(b[0]), func(): _glove_beat(dir, float(b[1]), float(b[2]), float(b[3])))

func _glove_beat(dir: Vector2, reach: float, shove: float, daze: float) -> void:
	var world := _world()
	var c := global_position + Vector2(0, -10)
	for t in Util.on_segment(world, c, c + dir * reach, 9.0):
		if not is_instance_valid(t) or not Util.sees(world, global_position + Vector2(0, -8), Util.hit_point(t)):
			continue
		_fx("spark", Util.hit_point(t), 0.45, false, 0.2)
		Util.hit(self, t, _dmg())
		Util.knockback(world, t, dir, shove, 0.1 if shove < 20.0 else 0.18, daze)

# --- Page 3 -------------------------------------------------------------
func _do_air_pistol() -> void:
	var jitter := [-0.06, 0.03, -0.02, 0.05, -0.04, 0.0]
	for i in range(6):
		var j: float = jitter[i]
		_schedule(i * 0.06, func(): _proj("bullet", _muzzle(), _aim_dir().rotated(j) * 360.0, _dmg(), {"life": 0.65, "radius": 6.0}))

func _do_shock_gun() -> void:
	var t := _target_near_cursor(80.0)
	var dir := _aim_dir() if t == null else (Util.hit_point(t) - _muzzle()).normalized()
	_proj("beam", _muzzle(), dir * 260.0, _dmg(), {"pierce": true, "hit_interval": 0.12, "max_hits_per_target": 5, "life": 1.0, "radius": 9.0, "hit_anim": ""})

# --- Page 4 -------------------------------------------------------------
func _do_ataru_gun() -> void:
	var picked: Array = []
	for i in range(4):
		var t := Util.nearest(_world(), global_position, 220.0, picked)
		if t != null:
			picked.append(t)
	for i in range(4):
		var tgt: Node2D = picked[i % picked.size()] if not picked.is_empty() else null
		_proj("ataru_bullet", _muzzle(), _aim_dir().rotated(-0.45 + 0.3 * i) * 170.0, _dmg(),
			{"mode": "homing", "target": tgt, "turn_rate": 6.0, "life": 2.0, "radius": 6.0, "explode_radius": 16.0, "explode_damage": _dmg(), "explode_scale": 0.3})

func _do_pencil_missile() -> void:
	var t := _target_near_cursor(90.0, 260.0)
	_proj("missile", _muzzle(), _aim_dir() * 190.0, _dmg() * 3,
		{"mode": "homing", "target": t, "turn_rate": 4.0, "life": 2.2, "radius": 7.0, "explode_radius": 30.0, "explode_damage": _dmg() * 3, "explode_scale": 0.55})

# --- Page 5 -------------------------------------------------------------
func _do_shockwave_pistol() -> void:
	for a in [-0.36, -0.12, 0.12, 0.36]:
		_proj("shock_bullet", _muzzle(), _aim_dir().rotated(a) * 260.0, _dmg(),
			{"mode": "bounce", "bounces": 3, "life": 2.2, "spin": 14.0, "rotate_sprite": false, "radius": 6.0})

func _do_bubble_pistol() -> void:
	for a in [-0.35, 0.0, 0.35]:
		_proj("bubble_ball", _muzzle(), _aim_dir().rotated(a) * 75.0, _dmg(),
			{"mode": "drift", "wobble": 30.0, "life": 3.0, "radius": 8.0, "stun_time": 1.4, "rotate_sprite": false, "fade_tail": 0.4, "hit_anim": "puff"})

# --- Page 6 -------------------------------------------------------------
func _do_thundercloud() -> void:
	var t := _target_near_cursor(48.0, 180.0)
	var at := _aim_point(150.0) if t == null else t.global_position
	var fx := _fx("cloud", at, 0.9)
	if fx != null:
		fx.strikes = [{"t": 0.1, "r": 16.0, "dmg": _dmg()}, {"t": 0.2, "r": 16.0, "dmg": _dmg()}, {"t": 0.3, "r": 16.0, "dmg": _dmg(), "stun": 0.4}]

func _do_shock_stick() -> void:
	var lunge := Util.safe_point(_world(), global_position, _aim_dir(), 20.0, 4.0)
	global_position = lunge
	var c := global_position + Vector2(0, -12)
	_hit_list(Util.on_segment(_world(), c, c + _aim_dir() * 46.0, 7.0), _dmg() * 3, 0.5)

# --- Page 7 -------------------------------------------------------------
## Magic Hand (MUGEN: weak but with a huge reach, trips the opponent). The red hand on
## Doraemon's green handle shoots out on a folding lattice arm, slaps everything along the
## arm and trips it: the enemy topples over and lies on the floor for a moment.
const MAGIC_HAND_RANGE := 170.0
const MAGIC_HAND_TRIP := 0.6
const MAGIC_HAND_REACH := 0.12      # seconds until the hand arrives (HandFx timing)
const MAGIC_HAND_RETURN := 0.32     # seconds until it is back on the handle

## Tip of the green handle in the "magichand_grip" pose.
func _magic_hand_origin() -> Vector2:
	return global_position + Vector2(-9.0 if animated_sprite.flip_h else 9.0, -4.0)

func _do_magic_hand() -> void:
	var world := _world()
	var start := _magic_hand_origin()
	var dir := _aim_dir()
	var length := clampf(_cast_aim.length(), 40.0, MAGIC_HAND_RANGE)
	var t := _target_near_cursor(48.0, MAGIC_HAND_RANGE)
	if t != null:
		var to := Util.hit_point(t) - start
		if to.length() > 1.0:
			dir = to.normalized()
			length = minf(to.length(), MAGIC_HAND_RANGE)
	# The arm stops at walls and closed doors.
	while length > 12.0 and (Util.is_wall(world, start + dir * length) or not Util.sees(world, start, start + dir * length)):
		length -= 6.0
	var end := start + dir * length
	_play("magichand_grip")
	var hand := HandFx.new()
	hand.from_node = self
	hand.origin_offset = start - global_position
	hand.end_point = end
	_spawn(hand, start)
	_schedule(MAGIC_HAND_REACH, func(): _magic_hand_strike(start, end))
	_schedule(MAGIC_HAND_RETURN, _magic_hand_back)

## The hand is back on the handle.
func _magic_hand_back() -> void:
	if _cast_move == "magic_hand":
		_play("magichand")

func _magic_hand_strike(start: Vector2, end: Vector2) -> void:
	var world := _world()
	var targets: Array = Util.on_segment(world, start, end, 10.0)
	for t in Util.in_circle(world, end, 12.0):
		if not targets.has(t):
			targets.append(t)
	for t in targets:
		if not is_instance_valid(t) or not Util.sees(world, start, Util.hit_point(t)):
			continue
		_fx("spark", Util.hit_point(t), 0.4, false, 0.2)
		Util.hit(self, t, _dmg())
		Util.trip(t, MAGIC_HAND_TRIP, global_position.x)

func _start_screw() -> void:
	var dest := Util.safe_point(_world(), global_position, _aim_dir(), 90.0, 8.0)
	_enter_mode("screw", {"from": global_position, "to": dest, "hit": {}})
	is_invincible = true
	_play("screw")

# --- Page 8 -------------------------------------------------------------
func _do_grenades() -> void:
	var center := _aim_point(110.0)
	var offsets := [Vector2(-14, 6), Vector2(0, -10), Vector2(14, 6)]
	for o in offsets:
		_proj("bomb", global_position + Vector2(0, -16), Vector2.ZERO, _dmg() * 2,
			{"mode": "lob", "lob_to": center + (o as Vector2).rotated(_aim_dir().angle()), "lob_time": 0.55, "lob_height": 30.0, "fuse": 0.9, "life": 3.0,
			"radius": 8.0, "explode_radius": 26.0, "explode_damage": _dmg() * 2, "explode_scale": 0.45, "spin": 10.0, "rotate_sprite": false})

func _do_fishing_pond() -> void:
	var pond_at := Util.safe_point(_world(), global_position, _aim_dir(), 22.0, 6.0)
	_fx("pond", pond_at + Vector2(0, 2), 0.9, false, 1.6)
	for i in range(4):
		var ang := rng.randf_range(-0.7, 0.7)
		_schedule(0.2 + i * 0.3, func(): _proj("fish", pond_at + Vector2(0, -6), _aim_dir().rotated(ang) * 190.0, _dmg() * 2,
			{"life": 0.9, "radius": 9.0, "hit_anim": "fish_puffed"}))

# --- Page 9 -------------------------------------------------------------
func _do_kibidango() -> void:
	var rex: Node2D = TRex.new()
	rex.direction = _aim_dir()
	rex.speed = 190.0
	rex.damage = _dmg() * trex_damage_mult
	rex.caster = self
	_spawn(rex, global_position + _aim_dir() * 14.0)

func _do_minidora() -> void:
	var t := _target_near_cursor(60.0, 240.0)
	var base := _aim_point(120.0) if t == null else Util.safe_point(_world(), t.global_position, _aim_dir(), 40.0, 4.0)
	var run := -_aim_dir() * 130.0
	_walker("minidora", base, run, _dmg(), {"life": 1.5, "hit_interval": 0.2, "max_hits_per_target": 3, "radius": 12.0})
	if rng.randf() < 0.5:
		_schedule(0.25, func(): _walker("minidora", base + Vector2(0, 12), run, _dmg(), {"life": 1.5, "hit_interval": 0.2, "max_hits_per_target": 3, "radius": 12.0}))

# --- Page 10 ------------------------------------------------------------
func _do_korobashiya() -> void:
	_walker("korobashiya", global_position + _aim_dir() * 14.0, _aim_dir() * 75.0, _dmg(),
		{"seek": true, "seek_speed": 75.0, "life": 9.0, "stun_time": 1.2, "hit_interval": 1.6, "max_hits_per_target": 3, "max_total_hits": 3, "radius": 10.0})

func _start_mantle() -> void:
	_enter_mode("mantle", {})
	_play("mantle")
	_fx("mantle_fx", global_position + Vector2(-10 if animated_sprite.flip_h else 10, 0), 0.9, animated_sprite.flip_h, 0.8)

func _mantle_reflect() -> void:
	for node in _world().get_children():
		if not (node is Area2D) or node.get_script() == null:
			continue
		if not ENEMY_PROJECTILES.has((node.get_script() as Script).resource_path):
			continue
		if node.is_queued_for_deletion() or node.global_position.distance_to(global_position + Vector2(0, -10)) > 30.0:
			continue
		var back: Vector2 = -Vector2(node.get("direction"))
		if back == Vector2.ZERO:
			back = -_aim_dir()
		var dmg := int(node.get("damage")) * 2
		var at: Vector2 = node.global_position
		node.queue_free()
		_proj("mantle_wave", at, back.normalized() * 260.0, maxi(dmg, 2), {"life": 1.2, "radius": 8.0, "hit_anim": "spark"})

func _mantle_counter(amount: int) -> void:
	var t := Util.nearest(_world(), global_position, 60.0)
	if t != null:
		_fx("mantle_wave", Util.hit_point(t), 0.9, false, 0.3)
		Util.hit(self, t, amount * 2)
	if get_tree():
		get_tree().call_group("game_ui", "spawn_damage_number", global_position + Vector2(0, -30), amount * 2, Color(1.0, 0.5, 0.8))

# ------------------------------------------------------------------ Q: friends & supers
func _on_q() -> void:
	var sup := String(current_page()["super"])
	if power >= BAR:
		_start_super(sup)
	elif friend_cd <= 0.0:
		_cast_aim = current_aim_offset
		var friend := String(FRIENDS[friend_index])
		friend_index = (friend_index + 1) % FRIENDS.size()
		friend_cd = FRIEND_COOLDOWN
		_begin_cast("friend_" + friend, "summon", 0.15, 0.4)

func _friend_from_below(kind: String, t: Node2D, dmg: int, props: Dictionary) -> void:
	var at := (t.global_position if t != null else global_position + _aim_dir() * 70.0)
	var p := {"fly": true, "life": 1.1, "radius": 12.0, "max_targets": 1, "exit_anim": "exit_" + kind}
	p.merge(props, true)
	_walker("friend_" + kind, at + Vector2(0, 70), Vector2(0, -170), dmg, p)

func _do_friend_nobita() -> void:
	_friend_from_below("nobita", _target_near_cursor(90.0, 260.0), _dmg() * 2, {})

func _do_friend_gian() -> void:
	_friend_from_below("gian", _target_near_cursor(90.0, 260.0), _dmg(), {"max_hits_per_target": 3, "hit_interval": 0.1})

func _do_friend_shizuka() -> void:
	_friend_from_below("shizuka", _target_near_cursor(90.0, 260.0), _dmg() * 2, {"stun_time": 1.0})

func _do_friend_dorami() -> void:
	var t := _target_near_cursor(90.0, 260.0)
	var goal := t.global_position if t != null else global_position + _aim_dir() * 80.0
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var start := goal + Vector2(side * 110.0, rng.randf_range(-30.0, 30.0))
	_walker("friend_dorami", start, (goal - start).normalized() * 200.0, _dmg() * 2,
		{"fly": true, "life": 1.2, "radius": 12.0, "max_targets": 1, "exit_anim": "exit_dorami"})

func _do_friend_suneo() -> void:
	var t := _target_near_cursor(90.0, 260.0)
	var goal := t.global_position if t != null else global_position + _aim_dir() * 100.0
	var start := global_position + Vector2(0, 6)
	_walker("friend_suneo", start, (goal - start).normalized() * 220.0, _dmg() * 2,
		{"fly": true, "life": 1.0, "radius": 12.0, "max_targets": 1, "exit_anim": "exit_suneo"})

func _do_friend_cat() -> void:
	var t := _target_near_cursor(90.0, 220.0)
	var dir := _aim_dir() if t == null else (t.global_position - global_position).normalized()
	_walker("cat", global_position + dir * 16.0, dir * 110.0, _dmg(),
		{"life": 2.5, "radius": 12.0, "stun_time": 0.6, "max_targets": 3, "relocate_to": self})

func _start_super(sup: String) -> void:
	var info: Array = SUPERS[sup]
	_cast_aim = current_aim_offset
	_cast_bars = 1
	if bool(info[4]):
		_cast_bars = clampi(int(power / BAR), 1, 3)
	power -= BAR * _cast_bars
	if get_tree():
		get_tree().call_group("game_ui", "show_banner", "DORAEMON SUPER — " + String(info[0]).to_upper(), Color(0.45, 0.8, 1.0))
	match sup:
		"uradoraman":
			_enter_mode("uradora_dash", {"dir": _aim_dir()})
			is_invincible = true
			_play("summon")
		"sl_chimney":
			_enter_mode("sl", {"hit": {}, "smoke_t": 0.0})
			is_invincible = true
			_play("sl_run")
		"friendship_controller":
			_walker("suneo_ctrl", global_position + Vector2(-18 if _aim_dir().x >= 0.0 else 18, 4), Vector2.ZERO, 0, {"life": 3.2})
			_enter_mode("punch", {"target": null, "punch_t": 0.0})
			is_invincible = true
			_play("punch_fly")
		_:
			_begin_cast("super_" + sup, String(info[1]), float(info[2]), float(info[3]))

func _do_super_nobita_rush() -> void:
	var at := Util.safe_point(_world(), global_position, Vector2(-1 if _aim_dir().x >= 0.0 else 1, 0), 22.0, 6.0)
	_fx("door", at, 0.9, false, 0.4)
	_walker("nobita", at, Vector2.ZERO, 0, {"life": 2.4, "shoot_every": 0.18, "shots_left": 10, "shoot_damage": _dmg(), "final_shot_damage": _dmg() * 4})

func _do_super_shizuka_bath() -> void:
	var center := _aim_point(140.0)
	_fx("bath_door", center + Vector2(0, -46), 0.9, false, 2.8).fade_out = 0.3
	for i in range(40):
		var target := center + Vector2(rng.randf_range(-48.0, 48.0), rng.randf_range(-24.0, 32.0))
		_schedule(0.15 + i * 0.065, func(): _proj("water", center + Vector2(rng.randf_range(-6.0, 6.0), -40), Vector2.ZERO, _dmg(),
			{"mode": "lob", "lob_to": target, "lob_time": 0.35, "lob_height": 18.0, "life": 2.0, "radius": 9.0, "rotate_sprite": false, "end_anim": "", "max_hits_per_target": 1}))

func _do_super_dorami_balloon() -> void:
	var t := _target_near_cursor(120.0, 300.0)
	_proj("dorami_balloon", global_position + Vector2(0, -20), _aim_dir() * 90.0, _dmg() * 8,
		{"mode": "homing", "target": t, "turn_rate": 3.0, "life": 3.5, "radius": 12.0, "rotate_sprite": false,
		"explode_radius": 60.0, "explode_damage": _dmg() * 8, "explode_scale": 1.4})
	consume_potion(1, 0)

func _do_super_gian_recital() -> void:
	var at := Util.safe_point(_world(), global_position, _aim_dir(), 30.0, 8.0)
	_fx("gian_door", at, 0.9, _aim_dir().x < 0.0)
	var bars := _cast_bars
	_schedule(0.3, func(): _walker("gian_walk", at, _aim_dir() * 28.0, _dmg() * 2,
		{"life": 1.5 + 1.0 * bars, "radius": 14.0, "notes_every": 0.1, "note_damage": _dmg()}))

func _do_super_junk_barrage() -> void:
	var kinds := ["junk_ball", "junk_doll", "junk_hammer", "junk_chair"]
	if _cast_bars >= 2:
		kinds.append("junk_fridge")
	var dmg_k := {"junk_ball": 1, "junk_doll": 1, "junk_hammer": 2, "junk_chair": 2, "junk_fridge": 3}
	var count := 2 + 4 * _cast_bars
	var center := _aim_point(130.0)
	for i in range(count):
		var kind: String = kinds[i % kinds.size()]
		var to := center + Vector2(rng.randf_range(-50.0, 50.0), rng.randf_range(-40.0, 40.0))
		_schedule(i * 0.09, func(): _proj(kind, global_position + Vector2(0, -18), Vector2.ZERO, _dmg() * int(dmg_k[kind]),
			{"mode": "lob", "lob_to": to, "lob_time": 0.5, "lob_height": 40.0, "life": 2.0, "radius": 18.0 if kind == "junk_fridge" else 12.0,
			"spin": 9.0, "rotate_sprite": false, "end_anim": "puff", "sprite_scale": 0.6}))

func _do_super_everyone_takecopter() -> void:
	var picked: Array = []
	for i in range(5):
		var t := Util.nearest(_world(), global_position, 240.0, picked)
		if t != null:
			picked.append(t)
	var crew := ["nobita", "shizuka", "gian", "suneo", "dorami"]
	for i in range(5):
		var kind: String = crew[i]
		var tgt: Node2D = picked[i % picked.size()] if not picked.is_empty() else null
		var spread := Vector2((i - 2) * 22.0, 0)
		_schedule(i * 0.12, func():
			var at: Vector2 = tgt.global_position if is_instance_valid(tgt) else global_position + _aim_dir() * 70.0 + spread
			_walker("friend_" + kind, at + Vector2(0, 70), Vector2(0, -170), _dmg() * 2,
				{"fly": true, "life": 1.1, "radius": 12.0, "max_targets": 1, "stun_time": 0.8, "exit_anim": "exit_" + kind}))

func _do_super_dorayakin() -> void:
	var t := _target_near_cursor(70.0, 260.0)
	var at := _aim_point(160.0) if t == null else t.global_position
	var sizes := {1: ["dorayaki_s", 34.0, 6, 0.6], 2: ["dorayaki_m", 48.0, 12, 0.9], 3: ["dorayaki_l", 72.0, 25, 1.4]}
	var s: Array = sizes[_cast_bars]
	_proj(String(s[0]), at, Vector2.ZERO, _dmg() * int(s[2]),
		{"mode": "drop", "lob_time": 0.5, "lob_height": 140.0, "life": 2.0, "rotate_sprite": false, "sprite_scale": 0.6 if _cast_bars == 3 else 0.9,
		"explode_radius": float(s[1]), "explode_damage": _dmg() * int(s[2]), "explode_scale": float(s[3])})

# ------------------------------------------------------------------ Dorayaki
func _start_eat() -> void:
	eat_cd = EAT_COOLDOWN
	_enter_mode("eat", {"fed": false})
	_play("eat")

# ------------------------------------------------------------------ special modes
func _enter_mode(m: String, data: Dictionary) -> void:
	_mode = m
	_mode_t = 0.0
	_mode_data = data
	is_casting_skill = true
	velocity = Vector2.ZERO

func _end_mode() -> void:
	_mode = ""
	_mode_data = {}
	is_casting_skill = false
	is_invincible = false
	if not is_dead:
		_play("idle")

func _step_mode(delta: float, direction: Vector2) -> void:
	_mode_t += delta
	match _mode:
		"door":
			if not bool(_mode_data["fired"]) and _mode_t >= DOOR_TELEPORT_TIME:
				_mode_data["fired"] = true
				var ghost: Node2D = DoorGhost.new()
				ghost.flip = animated_sprite.flip_h
				_spawn(ghost, global_position + Vector2(0, FEET_Y))
				global_position = _mode_data["target"]
				_play("door_out")
				if get_node_or_null("/root/AudioManager") != null:
					AudioManager.play_sfx("portal", 1.3, 1.45)
			if _mode_t >= DOOR_TELEPORT_TIME + Sprites.duration("door_out"):
				_end_mode()
		"screw":
			var out_t := 0.22
			var from: Vector2 = _mode_data["from"]
			var to: Vector2 = _mode_data["to"]
			var k := _mode_t / out_t if _mode_t < out_t else 1.0 - (_mode_t - out_t) / out_t
			global_position = from.lerp(to, clampf(k, 0.0, 1.0))
			_set_flip(to.x < from.x)
			var hit: Dictionary = _mode_data["hit"]
			for t in Util.in_circle(_world(), global_position + Vector2(0, -10), 12.0):
				if not hit.has(t.get_instance_id()):
					hit[t.get_instance_id()] = true
					Util.hit(self, t, _dmg() * 2)
			if _mode_t >= out_t * 2.0:
				global_position = from
				_end_mode()
		"mantle":
			_mantle_reflect()
			if _mode_t >= 0.8:
				_end_mode()
		"eat":
			if not bool(_mode_data["fed"]) and _mode_t >= 0.4:
				_mode_data["fed"] = true
				consume_potion(1, 0)
				add_power(40)
			if _mode_t >= Sprites.duration("eat"):
				_end_mode()
		"sl":
			velocity = direction * speed * 2.2
			move_and_slide()
			if direction.x != 0.0:
				_set_flip(direction.x < 0.0)
			var hit: Dictionary = _mode_data["hit"]
			for t in Util.in_circle(_world(), global_position + Vector2(0, -12), 14.0):
				var id: int = t.get_instance_id()
				if _mode_t - float(hit.get(id, -INF)) >= 0.4:
					hit[id] = _mode_t
					Util.hit(self, t, _dmg() * 2)
			_mode_data["smoke_t"] = float(_mode_data["smoke_t"]) + delta
			if float(_mode_data["smoke_t"]) >= 0.15:
				_mode_data["smoke_t"] = 0.0
				_proj("sl_smoke", global_position + Vector2(0, -40), Vector2(0, -20), _dmg(),
					{"mode": "straight", "life": 0.6, "radius": 10.0, "pierce": true, "rotate_sprite": false, "hit_anim": ""})
			if _mode_t >= 3.5:
				_end_mode()
		"uradora_dash":
			var dir: Vector2 = _mode_data["dir"]
			var step := dir * 330.0 * delta
			if not Util.is_wall(_world(), global_position + step):
				global_position += step
			var t := Util.nearest(_world(), global_position + Vector2(0, -10), 16.0)
			if t != null:
				Util.stun(t, 1.2)
				_mode = "uradora_tf"
				_mode_t = 0.0
				_mode_data["target"] = t
				_play("uradora_tf")
			elif _mode_t >= 0.3:
				_end_mode()
		"uradora_tf":
			if _mode_t >= Sprites.duration("uradora_tf"):
				_mode = "uradora_kick"
				_mode_t = 0.0
				_play("uradora_kick")
		"uradora_kick":
			var t = _mode_data.get("target")
			if is_instance_valid(t):
				var goal := Util.hit_point(t) + Vector2(0, 10)
				global_position = global_position.lerp(goal, clampf(_mode_t / 0.2, 0.0, 1.0))
			if _mode_t >= 0.2 and not _mode_data.has("kicked"):
				_mode_data["kicked"] = true
				_fx("explosion", global_position + Vector2(0, -12), 0.5)
				if is_instance_valid(t):
					Util.hit(self, t, _dmg() * 10)
				for o in Util.in_circle(_world(), global_position + Vector2(0, -10), 30.0):
					if o != t:
						Util.hit(self, o, _dmg() * 3)
			if _mode_t >= 0.45:
				_end_mode()
		"punch":
			var t = _mode_data.get("target")
			if not is_instance_valid(t) or t.get("is_dead") == true:
				t = Util.nearest(_world(), global_position, 220.0)
				_mode_data["target"] = t
			if is_instance_valid(t):
				var goal: Vector2 = t.global_position + Vector2(-14 if t.global_position.x >= global_position.x else 14, 0)
				var step := (goal - global_position).limit_length(260.0 * delta)
				if not Util.is_wall(_world(), global_position + step):
					global_position += step
				_set_flip(t.global_position.x < global_position.x)
				_mode_data["punch_t"] = float(_mode_data["punch_t"]) + delta
				if float(_mode_data["punch_t"]) >= 0.1 and global_position.distance_to(t.global_position) < 26.0:
					_mode_data["punch_t"] = 0.0
					_fx("spark", Util.hit_point(t), 0.35, false, 0.12)
					Util.hit(self, t, _dmg())
			if _mode_t >= 3.0:
				_end_mode()
		_:
			_end_mode()

const INVULNERABLE_MODES := ["door", "screw", "sl", "uradora_dash", "uradora_tf", "uradora_kick", "punch"]

func take_damage(amount: int) -> void:
	if INVULNERABLE_MODES.has(_mode):
		return
	if _mode == "mantle" and amount > 0 and not is_dead:
		_mantle_counter(amount)
		return
	var before := hp + current_armor
	super.take_damage(amount)
	if hp + current_armor < before:
		add_power(10)
		if hp > 0 and _cast_move == "" and _mode == "":
			_sync_anchor()

## Magic Hand: the red hand leaves the green handle on a folding lattice (lazy-tongs) arm,
## reaches the point, then folds back. The lattice narrows as it stretches.
class HandFx extends Node2D:
	const Sprites = preload("res://Scene/Character/Doraemon/DoraemonSprites.gd")
	const CELLS := 7
	const OUTLINE := Color(0.1, 0.1, 0.14)
	const METAL := Color(0.86, 0.87, 0.92)
	const PIVOT := Color(0.19, 0.69, 0.56)      # same green as the handle
	var from_node: Node2D
	var origin_offset: Vector2 = Vector2.ZERO
	var end_point: Vector2
	var age: float = 0.0
	var head: Sprite2D
	func _ready() -> void:
		z_index = 3
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = mat
		head = Sprite2D.new()
		head.texture = Sprites.texture("doraemon_magichand_head.png")
		head.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		head.offset = Vector2(6, 0)              # wrist on the arm tip, fingers forward
		head.use_parent_material = true
		head.visible = false
		add_child(head)
	func _physics_process(delta: float) -> void:
		age += delta
		if is_instance_valid(from_node):
			global_position = from_node.global_position + origin_offset
		queue_redraw()
		if age >= 0.32:
			queue_free()
	func _draw() -> void:
		var k := clampf(age / 0.12, 0.0, 1.0) if age < 0.2 else clampf(1.0 - (age - 0.2) / 0.12, 0.0, 1.0)
		var tip := to_local(end_point) * k
		var length := tip.length()
		head.visible = length > 2.0
		if length <= 2.0:
			return
		var dir := tip / length
		head.position = tip
		head.rotation = dir.angle()
		head.flip_v = dir.x < 0.0
		var side := dir.orthogonal() * lerpf(5.0, 2.0, k)
		for layer in range(2):
			var col := OUTLINE if layer == 0 else METAL
			var w := 3.0 if layer == 0 else 1.0
			for i in range(CELLS):
				var a := tip * (float(i) / CELLS)
				var b := tip * (float(i + 1) / CELLS)
				draw_line(a + side, b - side, col, w)
				draw_line(a - side, b + side, col, w)
		for i in range(CELLS + 1):
			var p := tip * (float(i) / CELLS)
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), PIVOT)
