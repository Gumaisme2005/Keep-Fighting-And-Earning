extends "res://Scene/Character/Player 1_Pyrois/player.gd"
## Lương Thơ - twin tonfa-gunblade duelist (hero #8).
##   Left Click   3-step combo: Stab (long thrust) -> Twin Swing (2 hits) -> Ground Smash
##                (area hit + daze). Keep clicking, or hold, to chain.
##   Right Click  Twin Barrels: both barrels fire a round along the aim (hold to keep firing).
##   Q            White Moon: transformation into the white-haired form for 12s - takes no
##                damage at all (from the transformation until she has changed back), +1 damage
##                on every hit, attacks 25% faster, moves 20% faster, piercing rounds.
## Stance (from the sprite README): standing still she keeps the weapons on her back (idle);
## moving draws them to the front (draw -> run); after 2s without fighting she puts them away
## again (draw played backwards). Hit / fire frames follow sheet_full.json "meta.events".
## Every timer runs in physics time and every input goes through the replay stream.

const Sprites = preload("res://Scene/Character/LuongTho/LTSprites.gd")
const Util = preload("res://Scene/Character/LuongTho/lt_util.gd")
const Bullet = preload("res://Scene/Character/LuongTho/lt_bullet.gd")

const FEET_Y := 3.0
const TORSO_Y := -14.0
const COMBO_WINDOW := 0.35          # after a swing ends, a click within this time continues the combo
const SHEATHE_AFTER := 2.0          # seconds standing still in combat stance before putting the weapons away
const UPGRADED_ATTACK_RATE := 1.25
const UPGRADED_SPEED := 1.2
const REVERT_RATE := 2.0

# Left Click combo. "box" = [ahead from, ahead to, centre y, half height] in game units from her
# feet; "circle" = [ahead, y, radius]. "chain" = frame from which a queued next step may start.
const COMBO: Array = [
	{"anim": "stab", "hits": [4], "box": [-4.0, 34.0, -15.0, 12.0], "mult": 1, "daze": 0.0, "chain": 6},
	{"anim": "swing", "hits": [2, 4], "box": [-6.0, 32.0, -16.0, 22.0], "mult": 1, "daze": 0.0, "chain": 6},
	{"anim": "smash", "hits": [4], "circle": [24.0, -8.0, 20.0], "mult": 2, "daze": 0.6, "chain": 8},
]

var shoot_cooldown: float = 0.8
var upgrade_duration: float = 12.0
var bullet_speed: float = 320.0
var bullet_range: float = 220.0

var facing: float = 1.0
var form: String = "base"           # base (black hair) / upgraded (white hair)
var form_time: float = 0.0
var stance: String = "sheathed"     # sheathed / drawing / combat / sheathing
var stance_t: float = 0.0
var q_cd: float = 0.0
var rmb_cd: float = 0.0
var move: String = ""               # "", combo, shoot, transform, revert
var move_t: float = 0.0
var combo_step: int = 0
var combo_chain: float = 0.0
var shots_fired: int = 0
var _next_hit: int = 0
var _combo_queued: bool = false
var _fired: bool = false
var _untouchable: bool = false
var _prev_atk: bool = false
var _ui_sent: Array = [-1.0, -1.0]

func _ready() -> void:
	hero_balance_id = "luong_tho"
	var cfg: Dictionary = BalanceData.get_hero_stats("luong_tho")
	shoot_cooldown = float(cfg.get("rmb_cooldown", shoot_cooldown))
	upgrade_duration = float(cfg.get("upgrade_duration", upgrade_duration))
	bullet_speed = float(cfg.get("bullet_speed", bullet_speed))
	bullet_range = float(cfg.get("bullet_range", bullet_range))
	super._ready()
	rmb_cd_max = shoot_cooldown
	animated_sprite.sprite_frames = Sprites.character_frames("base")
	animated_sprite.centered = false
	animated_sprite.scale = Vector2.ONE * Sprites.SCALE
	animated_sprite.position = Vector2(0, FEET_Y)
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.play("idle")
	_set_facing(1.0)

# ------------------------------------------------------------------ helpers
func _set_facing(f: float) -> void:
	if f == 0.0:
		return
	facing = signf(f)
	animated_sprite.flip_h = facing < 0.0
	animated_sprite.offset = Sprites.offset(facing < 0.0)
	# Keep the (inherited) sword hitbox on the side she faces, like the base hero does.
	sword_hitbox.scale.x = facing

func _face_aim() -> void:
	if absf(current_aim_offset.x) > 0.5:
		_set_facing(current_aim_offset.x)

## A point of the 64x64 frame (facing right) in world space.
func frame_point(p: Vector2) -> Vector2:
	return global_position + Vector2(0, FEET_Y) + Sprites.from_pivot(p, facing)

func _world() -> Node:
	return get_parent()

func _rate() -> float:
	return (UPGRADED_ATTACK_RATE if form == "upgraded" else 1.0) * get_attack_speed_multiplier()

## Damage of one hit: weapon damage, +1 in the white-haired form.
func hit_damage(mult: int = 1) -> int:
	return get_total_damage() * mult + (1 if form == "upgraded" else 0)

func _t(anim: String, frame_index: int) -> float:
	return Sprites.at_frame(anim, frame_index) / _rate()

func _play(anim: String) -> void:
	if animated_sprite.animation != anim or not animated_sprite.is_playing():
		animated_sprite.play(anim)

func _set_form(f: String) -> void:
	form = f
	animated_sprite.sprite_frames = Sprites.character_frames(f)
	animated_sprite.speed_scale = UPGRADED_ATTACK_RATE if form == "upgraded" else 1.0

# ------------------------------------------------------------------ main loop
func _process(_delta: float) -> void:
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
	combo_chain = maxf(0.0, combo_chain - delta)
	can_use_skill = q_cd <= 0.0
	if form == "upgraded" and move != "revert":
		form_time = maxf(0.0, form_time - delta)

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
			"slot": pending_hotbar_slot}
		pending_q_skill = false
		pending_rmb_skill = false
		pending_hotbar_slot = -1
		if gm != null:
			gm.record_frame_input(f)

	var direction := Vector2(float(f.get("dx", 0.0)), float(f.get("dy", 0.0)))
	current_aim_offset = Vector2(float(f.get("ax", 32.0)), float(f.get("ay", 0.0)))
	var atk := bool(f.get("atk", false))
	var input := {"atk": atk, "atk_edge": atk and not _prev_atk, "rmb": bool(f.get("rmb", false)), "q": bool(f.get("q", false))}
	_prev_atk = atk
	if int(f.get("slot", -1)) >= 0:
		inventory.use_or_equip_item(int(f.get("slot", -1)), self)

	if move != "":
		_step_move(delta, direction, input)
		return
	if form == "upgraded" and form_time <= 0.0:
		_start_revert()
		return

	_face_aim()
	if input["q"] and q_cd <= 0.0 and form == "base":
		_start_transform()
	elif input["rmb"] and rmb_cd <= 0.0:
		_start_shoot()
	elif input["atk_edge"] or input["atk"]:
		_start_swing(combo_step + 1 if combo_chain > 0.0 and combo_step < COMBO.size() - 1 else 0)
	if move != "":
		return
	var run_speed: float = get_effective_speed() * (UPGRADED_SPEED if form == "upgraded" else 1.0)
	run_speed = minf(run_speed, max_speed_cap)
	velocity = direction * run_speed
	move_and_slide()
	if not is_hurt:
		_step_stance(delta, direction)

## Weapons on the back while standing (idle), drawn to the front to run or fight.
func _step_stance(delta: float, direction: Vector2) -> void:
	stance_t += delta
	var moving := direction != Vector2.ZERO
	match stance:
		"sheathed", "sheathing":
			if moving:
				stance = "drawing"
				stance_t = 0.0
				animated_sprite.play("draw")
			elif stance == "sheathing" and stance_t >= Sprites.duration("draw") / animated_sprite.speed_scale:
				stance = "sheathed"
				animated_sprite.play("idle")
			elif stance == "sheathed":
				_play("idle")
		"drawing":
			if stance_t >= Sprites.duration("draw") / animated_sprite.speed_scale:
				stance = "combat"
				stance_t = 0.0
				_play("run" if moving else "ready")
		_:
			if moving:
				stance_t = 0.0
				_play("run")
			else:
				_play("ready")
				if stance_t >= SHEATHE_AFTER:
					stance = "sheathing"
					stance_t = 0.0
					animated_sprite.play_backwards("draw")

func _step_move(delta: float, direction: Vector2, input: Dictionary) -> void:
	move_t += delta
	match move:
		"combo":
			_step_swing(direction, input)
		"shoot":
			_step_shoot(direction)
		"transform":
			_step_transform()
		"revert":
			_step_revert()

func _begin(m: String, anim: String) -> void:
	move = m
	move_t = 0.0
	is_casting_skill = true
	stance = "combat"
	stance_t = 0.0
	animated_sprite.play(anim, get_attack_speed_multiplier() if m in ["combo", "shoot"] else 1.0)

func _end_move() -> void:
	move = ""
	move_t = 0.0
	is_casting_skill = false
	_untouchable = false
	velocity = Vector2.ZERO
	stance_t = 0.0
	if not is_dead:
		_play("ready" if stance == "combat" else "idle")

# ------------------------------------------------------------------ Left Click: combo
func _start_swing(step: int) -> void:
	combo_step = step
	combo_chain = 0.0
	_combo_queued = false
	_next_hit = 0
	_face_aim()
	_begin("combo", String(COMBO[step]["anim"]))

func _step_swing(direction: Vector2, input: Dictionary) -> void:
	var c: Dictionary = COMBO[combo_step]
	var anim := String(c["anim"])
	if input["atk_edge"]:
		_combo_queued = true
	velocity = Vector2.ZERO if anim == "smash" else direction * speed * 0.3
	move_and_slide()
	var hits: Array = c["hits"]
	while _next_hit < hits.size() and move_t >= _t(anim, int(hits[_next_hit])):
		_next_hit += 1
		_swing_hit(c)
	var last := combo_step >= COMBO.size() - 1
	if not last and move_t >= _t(anim, int(c["chain"])) and (_combo_queued or input["atk"]):
		_start_swing(combo_step + 1)
		return
	if move_t >= Sprites.duration(anim) / _rate():
		_end_move()
		combo_chain = 0.0 if last else COMBO_WINDOW

func _swing_hit(c: Dictionary) -> void:
	var world := _world()
	var feet := global_position
	var torso := feet + Vector2(0, TORSO_Y)
	var dmg := hit_damage(int(c["mult"]))
	for t in Util.enemies(world):
		var p := Util.hit_point(t)
		var inside := false
		if c.has("box"):
			var b: Array = c["box"]
			var ahead := (p.x - feet.x) * facing
			inside = ahead >= float(b[0]) and ahead <= float(b[1]) + Util.ENEMY_RADIUS and absf(p.y - (feet.y + float(b[2]))) <= float(b[3])
		else:
			var ci: Array = c["circle"]
			var centre := feet + Vector2(float(ci[0]) * facing, float(ci[1]))
			inside = p.distance_to(centre) <= float(ci[2]) + Util.ENEMY_RADIUS
		if not inside or not Util.sees(world, torso, p):
			continue
		t.take_damage(dmg)
		Bullet.spawn_hit(world, form, p)
		if float(c["daze"]) > 0.0:
			Util.stun(t, float(c["daze"]))

# ------------------------------------------------------------------ Right Click: Twin Barrels
func _start_shoot() -> void:
	_fired = false
	var cdr := PerkManager.get_cooldown_reduction() if get_node_or_null("/root/PerkManager") != null else 0.0
	rmb_cd = (shoot_cooldown * (1.0 - cdr)) / _rate()
	_face_aim()
	_begin("shoot", "shoot")

func _step_shoot(direction: Vector2) -> void:
	velocity = direction * speed * 0.3
	move_and_slide()
	if not _fired and move_t >= _t("shoot", Sprites.SHOOT_FIRE_FRAME):
		_fired = true
		_fire()
	if move_t >= Sprites.duration("shoot") / _rate():
		_end_move()

func _fire() -> void:
	var dir := current_aim_offset.normalized()
	if dir == Vector2.ZERO or signf(dir.x) == -facing:
		dir = Vector2(facing, dir.y).normalized() if dir != Vector2.ZERO else Vector2(facing, 0.0)
	for spawn in Sprites.BULLET_SPAWNS:
		var b: Node2D = Bullet.new()
		b.form = form
		b.dir = dir
		b.speed = bullet_speed
		b.max_range = bullet_range
		b.damage = hit_damage()
		b.pierce = form == "upgraded"
		_world().add_child(b)
		b.global_position = frame_point(spawn)
	shots_fired += 1

# ------------------------------------------------------------------ Q: White Moon transformation
func _start_transform() -> void:
	var cdr := PerkManager.get_cooldown_reduction() if get_node_or_null("/root/PerkManager") != null else 0.0
	q_cd = skill_cooldown * (1.0 - cdr)
	can_use_skill = false
	_untouchable = true
	velocity = Vector2.ZERO
	animated_sprite.speed_scale = 1.0
	_begin("transform", "transform")
	stance = "sheathed"

func _step_transform() -> void:
	velocity = Vector2.ZERO
	if move_t >= Sprites.duration("transform"):
		_set_form("upgraded")
		form_time = upgrade_duration
		stance = "sheathed"
		_end_move()

## The white form wears off: the transformation plays backwards (twice as fast).
func _start_revert() -> void:
	_set_form("base")
	animated_sprite.speed_scale = REVERT_RATE
	_untouchable = true
	velocity = Vector2.ZERO
	move = "revert"
	move_t = 0.0
	is_casting_skill = true
	animated_sprite.play_backwards("transform")

func _step_revert() -> void:
	velocity = Vector2.ZERO
	if move_t >= Sprites.duration("transform") / REVERT_RATE:
		animated_sprite.speed_scale = 1.0
		stance = "sheathed"
		_end_move()

# ------------------------------------------------------------------ damage
## Visual only: a short pale-blue flash when the White Moon form shrugs off a hit.
func _flash_block() -> void:
	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(0.75, 0.9, 1.6), 0.05)
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.12)

## True while nothing can hurt her: transforming, the whole white-haired form, changing back.
func is_immune() -> bool:
	return _untouchable or form == "upgraded"

func take_damage(amount: int, armor_piercing: float = 0.0) -> void:
	if is_dead:
		return
	if is_immune():
		if amount > 0 and form == "upgraded":
			_flash_block()
		return
	var before := hp + current_armor
	super.take_damage(amount, armor_piercing)
	if is_dead:
		move = ""
		is_casting_skill = false
	elif hp + current_armor < before:
		stance = "combat"           # the hurt frames show the weapons drawn
		stance_t = 0.0
