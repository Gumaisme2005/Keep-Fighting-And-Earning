extends "res://Scene/Character/Player 1_Pyrois/player.gd"
## Hoshimi Miyabi - frost swordswoman with an ice spirit (hero #7).
##   Left Click        3-hit frost combo (frost_combo_1 / 2 / 3); keep clicking or hold to chain
##   Shift             frost_dash: dash slash through enemies, untouchable while dashing
##   Right Click hold  frost_charge_start -> frost_charge (loop); release: frost_release + Frost Wave
##                     (charge 0.45s / 1s for a bigger, stronger wave; full charge freezes)
##   Q                 Frost Bloom (frost_special): ice_spikes erupt in a line in front of her
##   Spirit            floats at her shoulder and fires a spirit bolt at the nearest enemy every 2s
## Hit timings follow the animation events in cat_girl_animations.json. Every timer runs in
## physics time and every input goes through the replay stream, so replays stay in sync.

const Sprites = preload("res://Scene/Character/Miyabi/MiyabiSprites.gd")
const Util = preload("res://Scene/Character/Miyabi/miyabi_util.gd")
const FrostWave = preload("res://Scene/Character/Miyabi/frost_wave.gd")
const IceSpikes = preload("res://Scene/Character/Miyabi/ice_spikes.gd")
const Spirit = preload("res://Scene/Character/Miyabi/miyabi_spirit.gd")

const FEET_Y := 3.0
const BODY_X := 2.0                 # her body is drawn 2px behind the centre of the 40px frame

# Left Click combo: [animation, hit frame, reach px, damage x, lunge px, freeze s]
const COMBO: Array = [
	["frost_combo_1", 2, 30.0, 1, 0.0, 0.0],
	["frost_combo_2", 2, 30.0, 1, 0.0, 0.0],
	["frost_combo_3", 3, 42.0, 2, 14.0, 0.5],
]
const COMBO_WINDOW := 0.3           # after swing 1 or 2 ends, a click within this time continues the combo
const COMBO_HALF_HEIGHT := 20.0

# Shift dash slash
const DASH_START_FRAME := 1
const DASH_TIME := 0.14
const DASH_WIDTH := 14.0

# Right Click charge -> Frost Wave: [charge seconds, damage x, size, freeze s]
const WAVE_LEVELS: Array = [[0.0, 1, 1.0, 0.0], [0.45, 2, 1.25, 0.0], [1.0, 3, 1.5, 0.8]]
const WAVE_RELEASE_FRAME := 2

# Q Frost Bloom
const BLOOM_ERUPT_FRAME := 5

var rmb_cooldown: float = 2.0
var dash_cooldown: float = 1.2
var dash_distance: float = 72.0
var dash_damage_mult: int = 2
var bloom_damage_mult: int = 3
var bloom_freeze: float = 1.2
var wave_speed: float = 230.0
var wave_range: float = 180.0

var facing: float = 1.0
var q_cd: float = 0.0
var rmb_cd: float = 0.0
var dash_cd: float = 0.0
var spirit: Node2D

var move: String = ""               # "", combo, dash, charge, release, special
var move_t: float = 0.0
var combo_step: int = 0
var combo_chain: float = 0.0
var charge_time: float = 0.0
var wave_level: int = 0
var _combo_queued: bool = false
var _event_done: bool = false
var _untouchable: bool = false
var _dash_dir: Vector2 = Vector2.RIGHT
var _dash_from: Vector2 = Vector2.ZERO
var _dash_hits: Dictionary = {}
var _charge_flash: bool = false
var _prev_atk: bool = false
var _prev_rmb: bool = false
var _prev_shift: bool = false
var _ui_sent: Array = [-1.0, -1.0]

func _ready() -> void:
	hero_balance_id = "miyabi"
	var cfg: Dictionary = BalanceData.get_hero_stats("miyabi")
	rmb_cooldown = float(cfg.get("rmb_cooldown", rmb_cooldown))
	dash_cooldown = float(cfg.get("dash_cooldown", dash_cooldown))
	dash_distance = float(cfg.get("dash_distance", dash_distance))
	dash_damage_mult = int(cfg.get("dash_damage_mult", dash_damage_mult))
	bloom_damage_mult = int(cfg.get("bloom_damage_mult", bloom_damage_mult))
	bloom_freeze = float(cfg.get("bloom_freeze", bloom_freeze))
	super._ready()
	rmb_cd_max = rmb_cooldown
	animated_sprite.sprite_frames = Sprites.build(Sprites.CHARACTER_ANIMS)
	animated_sprite.centered = true
	animated_sprite.scale = Vector2.ONE * Sprites.SCALE
	animated_sprite.position = Vector2(0, FEET_Y - 20.0 * Sprites.SCALE)
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.play("idle")
	_set_facing(1.0)
	spirit = Spirit.new()
	spirit.hero = self
	spirit.cooldown = float(cfg.get("spirit_cooldown", 2.0))
	add_child(spirit)

# ------------------------------------------------------------------ geometry
## Centre of the 40x40 character frame, relative to her origin (the JSON offsets start here).
func centre_local() -> Vector2:
	return Vector2(BODY_X * Sprites.SCALE * facing, FEET_Y - 20.0 * Sprites.SCALE)

func centre() -> Vector2:
	return global_position + centre_local()

## Offset from the frame centre (facing right in the JSON), mirrored for the current facing.
func from_centre(offset: Vector2) -> Vector2:
	return centre() + Vector2(offset.x * facing, offset.y) * Sprites.SCALE

func _set_facing(f: float) -> void:
	if f == 0.0:
		return
	facing = signf(f)
	animated_sprite.flip_h = facing < 0.0
	animated_sprite.offset = Vector2(BODY_X * facing, 0.0)
	# Keep the (inherited) sword hitbox on the side she faces, like the base hero does.
	sword_hitbox.scale.x = facing

func _world() -> Node:
	return get_parent()

func _dmg() -> int:
	return get_total_damage()

func _play(anim: String) -> void:
	if animated_sprite.animation != anim or not animated_sprite.is_playing():
		animated_sprite.play(anim)

# ------------------------------------------------------------------ main loop
func _process(_delta: float) -> void:
	# Cooldowns tick in _physics_process; just mirror them to the HUD.
	if q_cd != _ui_sent[0] or rmb_cd != _ui_sent[1]:
		_ui_sent = [q_cd, rmb_cd]
		q_cd_remaining = q_cd
		rmb_cd_remaining = rmb_cd
		skill_cooldown_changed.emit(q_cd, skill_cooldown, rmb_cd, rmb_cd_max)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if is_hurt:
		_hurt_timer -= delta
		if _hurt_timer <= 0.0:
			is_hurt = false
	q_cd = maxf(0.0, q_cd - delta)
	rmb_cd = maxf(0.0, rmb_cd - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	combo_chain = maxf(0.0, combo_chain - delta)
	can_use_skill = q_cd <= 0.0

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
			"shift": Input.is_physical_key_pressed(KEY_SHIFT), "slot": pending_hotbar_slot}
		pending_q_skill = false
		pending_rmb_skill = false
		pending_hotbar_slot = -1
		if gm != null:
			gm.record_frame_input(f)

	var direction := Vector2(float(f.get("dx", 0.0)), float(f.get("dy", 0.0)))
	current_aim_offset = Vector2(float(f.get("ax", 32.0)), float(f.get("ay", 0.0)))
	var atk := bool(f.get("atk", false))
	var rmb := bool(f.get("rmb", false))
	var shift := bool(f.get("shift", false))
	var input := {
		"atk": atk, "atk_edge": atk and not _prev_atk,
		"rmb": rmb, "rmb_edge": rmb and not _prev_rmb,
		"shift_edge": shift and not _prev_shift,
		"q": bool(f.get("q", false)),
	}
	_prev_atk = atk
	_prev_rmb = rmb
	_prev_shift = shift
	if int(f.get("slot", -1)) >= 0:
		inventory.use_or_equip_item(int(f.get("slot", -1)), self)

	if move != "":
		_step_move(delta, direction, input)
		return

	_set_facing(current_aim_offset.x if absf(current_aim_offset.x) > 0.5 else facing)
	if input["q"] and q_cd <= 0.0:
		_start_special()
	elif input["shift_edge"] and dash_cd <= 0.0:
		_start_dash(direction)
	elif input["rmb_edge"] and rmb_cd <= 0.0:
		_start_charge()
	elif input["atk_edge"] or input["atk"]:
		_start_swing(combo_step + 1 if combo_chain > 0.0 and combo_step < COMBO.size() - 1 else 0)
	if move != "":
		return
	var effective_speed: float = get_effective_speed()
	velocity = direction * effective_speed
	move_and_slide()
	if not is_hurt:
		_play("walk" if direction != Vector2.ZERO else "idle")

func _step_move(delta: float, direction: Vector2, input: Dictionary) -> void:
	move_t += delta * (get_attack_speed_multiplier() if move == "combo" else 1.0)
	match move:
		"combo":
			_step_swing(direction, input)
		"dash":
			_step_dash()
		"charge":
			_step_charge(delta, direction, input)
		"release":
			_step_release(direction)
		"special":
			_step_special()

func _begin(m: String, anim: String) -> void:
	move = m
	move_t = 0.0
	_event_done = false
	is_casting_skill = true
	animated_sprite.play(anim, get_attack_speed_multiplier() if m == "combo" else 1.0)

func _end_move() -> void:
	move = ""
	move_t = 0.0
	is_casting_skill = false
	_untouchable = false
	velocity = Vector2.ZERO
	animated_sprite.modulate = Color.WHITE
	if not is_dead:
		_play("idle")

# ------------------------------------------------------------------ Left Click: 3-hit combo
func _start_swing(step: int) -> void:
	combo_step = step
	combo_chain = 0.0
	_combo_queued = false
	_set_facing(current_aim_offset.x if absf(current_aim_offset.x) > 0.5 else facing)
	_begin("combo", String(COMBO[step][0]))

func _step_swing(direction: Vector2, input: Dictionary) -> void:
	var c: Array = COMBO[combo_step]
	var anim := String(c[0])
	var hit_t := Sprites.at_frame(anim, int(c[1]))
	if input["atk_edge"]:
		_combo_queued = true
	var v := direction * speed * 0.35
	if float(c[4]) > 0.0 and move_t <= hit_t:
		# Faster swings retain the authored lunge distance over their shorter windup.
		v += Vector2(facing, 0.0) * float(c[4]) * get_attack_speed_multiplier() / hit_t
	velocity = v
	move_and_slide()
	if not _event_done and move_t >= hit_t:
		_event_done = true
		_swing_hit(c)
	if move_t >= Sprites.duration(anim):
		var last := combo_step >= COMBO.size() - 1
		if not last and (_combo_queued or input["atk"]):
			_start_swing(combo_step + 1)
			return
		_end_move()
		combo_chain = 0.0 if last else COMBO_WINDOW

func _swing_hit(c: Array) -> void:
	var world := _world()
	var o := centre()
	var reach := float(c[2])
	for t in Util.enemies(world):
		var p := Util.hit_point(t) - o
		var ahead := p.x * facing
		if ahead < -8.0 or ahead > reach + Util.ENEMY_RADIUS or absf(p.y) > COMBO_HALF_HEIGHT:
			continue
		if not Util.sees(world, o, Util.hit_point(t)):
			continue
		Util.hit(world, t, _dmg() * int(c[3]), float(c[5]))

# ------------------------------------------------------------------ Shift: dash slash
func _start_dash(direction: Vector2) -> void:
	_dash_dir = direction.normalized() if direction != Vector2.ZERO else current_aim_offset.normalized()
	if _dash_dir == Vector2.ZERO:
		_dash_dir = Vector2(facing, 0.0)
	if absf(_dash_dir.x) > 0.05:
		_set_facing(_dash_dir.x)
	dash_cd = dash_cooldown
	_dash_from = global_position
	_dash_hits.clear()
	_untouchable = true
	_begin("dash", "frost_dash")

func _step_dash() -> void:
	var start := Sprites.at_frame("frost_dash", DASH_START_FRAME)
	if move_t >= start and move_t <= start + DASH_TIME:
		velocity = _dash_dir * dash_distance / DASH_TIME
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if move_t >= start and move_t <= start + DASH_TIME + 0.05:
		_dash_cut()
	if move_t >= start + DASH_TIME:
		_untouchable = false
	if move_t >= Sprites.duration("frost_dash"):
		_end_move()

## Slashes every enemy along the path travelled so far (each one once).
func _dash_cut() -> void:
	var world := _world()
	var a := _dash_from + centre_local()
	var b := centre()
	for t in Util.enemies(world):
		var id: int = t.get_instance_id()
		if _dash_hits.has(id):
			continue
		var p := Util.hit_point(t)
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) > DASH_WIDTH + Util.ENEMY_RADIUS:
			continue
		_dash_hits[id] = true
		Util.hit(world, t, _dmg() * dash_damage_mult)

# ------------------------------------------------------------------ Right Click: charge -> Frost Wave
func _start_charge() -> void:
	charge_time = 0.0
	_charge_flash = false
	_begin("charge", "frost_charge_start")

func _step_charge(delta: float, direction: Vector2, input: Dictionary) -> void:
	charge_time += delta
	if absf(current_aim_offset.x) > 0.5:
		_set_facing(current_aim_offset.x)
	if animated_sprite.animation == "frost_charge_start" and charge_time >= Sprites.duration("frost_charge_start"):
		animated_sprite.play("frost_charge")
	if not _charge_flash and charge_time >= float(WAVE_LEVELS[WAVE_LEVELS.size() - 1][0]):
		_charge_flash = true
		Util.Fx.spawn(_world(), "frost_hit", from_centre(Vector2(-12, 14)), Sprites.SCALE * 1.4)
	# Fully charged: the blade glows.
	animated_sprite.modulate = Color(1.15, 1.25, 1.6) if _charge_flash and int(charge_time * 8.0) % 2 == 0 else Color.WHITE
	velocity = direction * speed * 0.4
	move_and_slide()
	if not input["rmb"]:
		_start_release()

func _start_release() -> void:
	wave_level = 0
	for i in range(WAVE_LEVELS.size()):
		if charge_time >= float(WAVE_LEVELS[i][0]):
			wave_level = i
	var cdr := PerkManager.get_cooldown_reduction() if get_node_or_null("/root/PerkManager") != null else 0.0
	rmb_cd = rmb_cooldown * (1.0 - cdr)
	animated_sprite.modulate = Color.WHITE
	if absf(current_aim_offset.x) > 0.5:
		_set_facing(current_aim_offset.x)
	_begin("release", "frost_release")

func _step_release(direction: Vector2) -> void:
	velocity = direction * speed * 0.3
	move_and_slide()
	if not _event_done and move_t >= Sprites.at_frame("frost_release", WAVE_RELEASE_FRAME):
		_event_done = true
		_spawn_wave()
	if move_t >= Sprites.duration("frost_release"):
		_end_move()

func _spawn_wave() -> void:
	var lv: Array = WAVE_LEVELS[wave_level]
	var dir := current_aim_offset.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(facing, 0.0)
	var w: Node2D = FrostWave.new()
	w.dir = dir
	w.speed = wave_speed
	w.max_range = wave_range
	w.damage = _dmg() * int(lv[1])
	w.k = float(lv[2])
	w.freeze_time = float(lv[3])
	_world().add_child(w)
	w.global_position = from_centre(Sprites.WAVE_OFFSET)

# ------------------------------------------------------------------ Q: Frost Bloom
func _start_special() -> void:
	var cdr := PerkManager.get_cooldown_reduction() if get_node_or_null("/root/PerkManager") != null else 0.0
	q_cd = skill_cooldown * (1.0 - cdr)
	can_use_skill = false
	_set_facing(current_aim_offset.x if absf(current_aim_offset.x) > 0.5 else facing)
	_untouchable = true
	velocity = Vector2.ZERO
	_begin("special", "frost_special")

func _step_special() -> void:
	velocity = Vector2.ZERO
	if not _event_done and move_t >= Sprites.at_frame("frost_special", BLOOM_ERUPT_FRAME):
		_event_done = true
		_untouchable = false
		var s: Node2D = IceSpikes.new()
		s.facing = facing
		s.damage = _dmg() * bloom_damage_mult
		s.shatter_damage = _dmg()
		s.freeze_time = bloom_freeze
		_world().add_child(s)
		s.global_position = from_centre(Sprites.SPIKES_OFFSET)
	if move_t >= Sprites.duration("frost_special"):
		_end_move()

# ------------------------------------------------------------------ damage
func take_damage(amount: int, armor_piercing: float = 0.0) -> void:
	if _untouchable:
		return
	var before := hp + current_armor
	super.take_damage(amount, armor_piercing)
	if hp + current_armor >= before:
		return
	if is_dead:
		move = ""
		is_casting_skill = false
		if spirit != null:
			spirit.on_hero_died()
	elif spirit != null:
		spirit.on_hero_hurt()
