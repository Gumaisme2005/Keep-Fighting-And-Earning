extends "res://Scene/Character/Player 1_Pyrois/player.gd"

const Sprites = preload("res://Scene/Character/Yugi/YugiSprites.gd")
const Summon = preload("res://Scene/Character/Yugi/summon.gd")
const TargetRing = preload("res://Scene/Character/Yugi/target_ring.gd")
const RoomBlast = preload("res://Scene/Character/Yugi/room_blast.gd")
const RoomLaser = preload("res://Scene/Character/Yugi/room_laser.gd")
const RoomLightning = preload("res://Scene/Character/Yugi/room_lightning.gd")
const RoomPull = preload("res://Scene/Character/Yugi/room_pull.gd")
const RoomFire = preload("res://Scene/Character/Yugi/room_fire.gd")
const CHARGE_SECONDS := 0.65
const RIGHT_CLICK_SUMMON_DISTANCE := 36.0
const INTRO_FPS := 5.0
var intro_active := true
var guard_summon: AnimatedSprite2D
var guarding := false
var suppress_guard := false
var left_hold := -1.0
var right_hold := -1.0
var pressed_left := false
var pressed_right := false
var released_left := false
var released_right := false
var action_left := 0.0
var special_rng := RandomNumberGenerator.new()

func _ready() -> void:
	hero_balance_id = "yugi"
	super._ready()
	special_rng.seed = hash(GameManager.current_seed + ":yugi:" + str(GameManager.current_level))
	var animations := SpriteFrames.new()
	var files := {"idle": "stance", "walk": "run", "guard": "guard", "intro": "intro", "skill": "special", "attack_1": "left-click", "hurt": "stance", "death": "death"}
	var starts := {"stance": 65, "run": 55, "guard": 65, "intro": 65, "special": 115, "left-click": 65, "death": 65}
	for anim in files:
		animations.add_animation(anim)
		animations.set_animation_loop(anim, anim in ["idle", "walk"])
		animations.set_animation_speed(anim, 10.0)
		var textures := Sprites.frames(files[anim], starts[files[anim]])
		var count := textures.size()
		if anim == "guard": count = mini(count, 4)
		if anim == "attack_1": count = mini(count, 5)
		for i in range(count): animations.add_frame(anim, textures[i])
	for move in ["right-click", "hold&release-left-click", "hold&release-right-click", "shift+left+click", "shift+right+click"]:
		animations.add_animation(move)
		animations.set_animation_loop(move, false)
		animations.set_animation_speed(move, 10.0)
		var start := 105 if move == "hold&release-left-click" else 125 if move == "right-click" else 75
		var textures := Sprites.frames(move, start)
		for i in range(mini(5, textures.size())): animations.add_frame(move, textures[i])
	animations.set_animation_speed("intro", INTRO_FPS)
	animated_sprite.sprite_frames = animations
	animated_sprite.material = Sprites.material()
	animated_sprite.scale = Vector2(0.45, 0.45)
	animated_sprite.position = Vector2(0, -36)
	animated_sprite.play("intro")
	velocity = Vector2.ZERO

func _input(event: InputEvent) -> void:
	# Keep Escape available for pausing, but don't queue gameplay/UI actions.
	if intro_active and (event is InputEventMouseButton or event is InputEventKey):
		if event is InputEventKey and event.keycode == KEY_ESCAPE: return
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if intro_active: return
	super._unhandled_input(event)
	if is_dead or GameManager.is_replaying: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: pressed_left = true
			else: released_left = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed: pressed_right = true
			else: released_right = true

func _physics_process(delta: float) -> void:
	if is_dead: return
	var f: Dictionary
	if GameManager.is_replaying:
		if replay_frame_idx >= GameManager.replay_frames.size():
			velocity = Vector2.ZERO
			return
		f = GameManager.replay_frames[replay_frame_idx]
		replay_frame_idx += 1
	else:
		var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var aim := get_global_mouse_position() - global_position
		f = {"dx": input_direction.x, "dy": input_direction.y, "ax": aim.x, "ay": aim.y,
			"shift": Input.is_physical_key_pressed(KEY_SHIFT), "lp": pressed_left, "lr": released_left,
			"rp": pressed_right, "rr": released_right, "q": pending_q_skill, "slot": pending_hotbar_slot,
			"result": special_rng.randi_range(1, 5) if pending_q_skill and can_use_skill else 0}
		GameManager.record_frame_input(f)
	pressed_left = false
	pressed_right = false
	released_left = false
	released_right = false
	pending_q_skill = false
	pending_hotbar_slot = -1
	if intro_active:
		velocity = Vector2.ZERO
		left_hold = -1
		right_hold = -1
		return
	current_aim_offset = Vector2(float(f.get("ax", 32)), float(f.get("ay", 0)))
	animated_sprite.flip_h = current_aim_offset.x < 0
	# Keep the (inherited) sword hitbox on the side Yugi faces, like the base hero does.
	sword_hitbox.scale.x = -1.0 if animated_sprite.flip_h else 1.0
	var move := Vector2(float(f.get("dx", 0)), float(f.get("dy", 0)))
	var shift := bool(f.get("shift", false))
	if not shift: suppress_guard = false
	action_left = maxf(0, action_left - delta)
	if is_hurt:
		_hurt_timer -= delta
		if _hurt_timer <= 0: is_hurt = false
	if int(f.get("slot", -1)) >= 0: inventory.use_or_equip_item(int(f.get("slot", -1)), self)
	_set_guarding(action_left <= 0 and not suppress_guard and shift)
	if left_hold >= 0: left_hold += delta
	if right_hold >= 0: right_hold += delta
	if action_left <= 0:
		if bool(f.get("q", false)) and can_use_skill:
			start_skill_cooldown()
			_cast("result-" + str(clampi(int(f.get("result", 1)), 1, 5)), 4, 1.8)
		elif bool(f.get("lp", false)) or bool(f.get("rp", false)):
			var left := bool(f.get("lp", false))
			if shift or guarding:
				_cast("shift+left+click" if left else "shift+right+click", 2, 0.8)
			elif left: left_hold = 0
			else: right_hold = 0
		if action_left <= 0 and bool(f.get("lr", false)) and left_hold >= 0:
			_cast("hold&release-left-click" if left_hold >= CHARGE_SECONDS else "left-click", 2 if left_hold >= CHARGE_SECONDS else 1, 0.6)
		elif action_left <= 0 and bool(f.get("rr", false)) and right_hold >= 0:
			_cast("hold&release-right-click" if right_hold >= CHARGE_SECONDS else "right-click", 3 if right_hold >= CHARGE_SECONDS else 1, 0.8)
	if bool(f.get("lr", false)): left_hold = -1
	if bool(f.get("rr", false)): right_hold = -1
	velocity = move * speed * (0.25 if guarding else 0.65 if action_left > 0 else 1.0)
	move_and_slide()
	if action_left <= 0 and not is_hurt:
		if not guarding:
			animated_sprite.play("walk" if move != Vector2.ZERO else "idle")
	if guarding and is_instance_valid(guard_summon):
		guard_summon.flip_h = animated_sprite.flip_h
		guard_summon.position.x = -22 if animated_sprite.flip_h else 22

func _set_guarding(active: bool) -> void:
	if intro_active and active: return
	if active == guarding: return
	guarding = active
	if not active:
		if is_instance_valid(guard_summon):
			guard_summon.hide()
			guard_summon.queue_free()
		guard_summon = null
		return
	left_hold = -1
	right_hold = -1
	animated_sprite.play("guard")
	guard_summon = AnimatedSprite2D.new()
	guard_summon.name = "GuardSummon"
	guard_summon.sprite_frames = Sprites.animation("guard", 300)
	guard_summon.sprite_frames.set_animation_loop("default", false)
	guard_summon.sprite_frames.set_animation_speed("default", 8.0)
	guard_summon.material = Sprites.material()
	guard_summon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	guard_summon.scale = Vector2(0.5, 0.5)
	guard_summon.position = Vector2(22, -40)
	add_child(guard_summon)
	guard_summon.play("default")

func _cast(move: String, multiplier: int, duration: float) -> void:
	if intro_active: return
	_set_guarding(false)
	suppress_guard = true
	left_hold = -1
	right_hold = -1
	action_left = duration
	animated_sprite.play("skill" if move.begins_with("result") else "attack_1" if move == "left-click" else move)
	if move == "result-5":
		var fire := RoomFire.new()
		fire.caster = self
		fire.damage_per_tick = get_total_damage()
		var aim := current_aim_offset.normalized()
		if aim == Vector2.ZERO: aim = Vector2.RIGHT
		fire.position = _right_click_summon_position(aim)
		if get_parent() is Node2D: fire.position = (get_parent() as Node2D).to_local(fire.position)
		get_parent().add_child(fire)
		return
	if move == "result-4":
		var pull := RoomPull.new()
		pull.caster = self
		pull.damage = get_total_damage() * multiplier
		pull.facing = -1.0 if current_aim_offset.x < 0 else 1.0
		pull.position = _right_click_summon_position(Vector2(pull.facing, 0))
		if get_parent() is Node2D: pull.position = (get_parent() as Node2D).to_local(pull.position)
		get_parent().add_child(pull)
		return
	if move == "result-3":
		var lightning := RoomLightning.new()
		lightning.caster = self
		lightning.damage = get_total_damage() * multiplier
		var aim := current_aim_offset.normalized()
		if aim == Vector2.ZERO: aim = Vector2.RIGHT
		lightning.position = _right_click_summon_position(aim)
		if get_parent() is Node2D: lightning.position = (get_parent() as Node2D).to_local(lightning.position)
		get_parent().add_child(lightning)
		return
	if move == "result-2":
		var laser := RoomLaser.new()
		laser.caster = self
		laser.damage_per_tick = get_total_damage()
		var aim := current_aim_offset.normalized()
		if aim == Vector2.ZERO: aim = Vector2.RIGHT
		laser.position = _right_click_summon_position(aim)
		if get_parent() is Node2D: laser.position = (get_parent() as Node2D).to_local(laser.position)
		get_parent().add_child(laser)
		return
	if move == "result-1":
		var blast := RoomBlast.new()
		blast.caster = self
		var aim := current_aim_offset.normalized()
		if aim == Vector2.ZERO: aim = Vector2.RIGHT
		var spawn_position := _right_click_summon_position(aim)
		blast.position = spawn_position
		if get_parent() is Node2D: blast.position = (get_parent() as Node2D).to_local(spawn_position)
		get_parent().add_child(blast)
		return
	if move == "shift+right+click":
		for target in _nearest_ring_targets():
			var ring := TargetRing.new()
			ring.damage = get_total_damage() * multiplier
			target.add_child(ring)
		return
	var summon := Summon.new()
	summon.move_name = move
	summon.damage = get_total_damage() * multiplier
	summon.caster = self
	summon.direction = current_aim_offset.normalized()
	if summon.direction == Vector2.ZERO: summon.direction = Vector2.RIGHT
	summon.position = position
	if move in ["right-click", "hold&release-right-click"]:
		var spawn_position := _right_click_summon_position(summon.direction)
		if spawn_position == global_position:
			summon.free()
			return
		summon.position = spawn_position
		if get_parent() is Node2D:
			summon.position = (get_parent() as Node2D).to_local(spawn_position)
	get_parent().add_child(summon)

func _nearest_ring_targets(limit: int = 2) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	var world := get_parent()
	# Enemy scenes expose Hurtbox but do not currently share an enemy group.
	for hurtbox in world.find_children("Hurtbox", "Area2D", true, false):
		var target := hurtbox.get_parent()
		if not target.has_method("take_damage"): target = target.get_parent()
		if not target is Node2D or not target.has_method("take_damage"): continue
		if target.is_in_group("player") or target.is_queued_for_deletion(): continue
		if target.get("is_dead") == true or target.get("is_active") == false: continue
		if targets.has(target): continue
		if world.has_method("has_line_of_sight") and not world.has_line_of_sight(global_position, target.global_position): continue
		targets.append(target)
	targets.sort_custom(func(a: Node2D, b: Node2D):
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	if limit > 0 and targets.size() > limit: targets.resize(limit)
	return targets

func _right_click_summon_position(aim_direction: Vector2) -> Vector2:
	# Keep the caster separate from Yugi, without spawning it through a wall.
	var world := get_parent()
	for angle in [0.0, PI / 4, -PI / 4, PI / 2, -PI / 2, PI]:
		var candidate := global_position + aim_direction.rotated(angle) * RIGHT_CLICK_SUMMON_DISTANCE
		if world.has_method("is_global_pos_wall_or_door") and world.is_global_pos_wall_or_door(candidate):
			continue
		if world.has_method("has_line_of_sight") and not world.has_line_of_sight(global_position, candidate):
			continue
		return candidate
	return global_position

func take_damage(amount: int) -> void:
	if guarding or intro_active: return
	super.take_damage(amount)

func _on_animated_sprite_2d_animation_finished() -> void:
	if intro_active and animated_sprite.animation == "intro":
		intro_active = false
		pressed_left = false
		pressed_right = false
		released_left = false
		released_right = false
		pending_q_skill = false
		pending_rmb_skill = false
		pending_hotbar_slot = -1
		animated_sprite.play("idle")
