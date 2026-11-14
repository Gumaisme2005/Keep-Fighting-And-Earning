extends Node
const GameManagerScript = preload("res://Scene/GameManager.gd")

class RingEnemy extends Node2D:
	var is_dead := false
	var is_active := true
	var received := 0
	var hp := 10
	func take_damage(amount: int) -> void:
		received += amount

class BlastRoom extends Node2D:
	var generated_rooms: Array = [Rect2i(0, 0, 10, 8), Rect2i(12, 0, 10, 8)]
	func get_player_room_index() -> int: return 0
	func local_to_map(point: Vector2) -> Vector2i: return Vector2i((point / 16.0).floor())

func _ready() -> void:
	GameManager.set_character_by_index(4)
	assert(GameManager.get_selected_character_info().id == "yugi")
	var player = GameManager.selected_character_scene.instantiate()
	add_child(player)
	player.set_physics_process(false)
	assert(player.hp == 5)
	assert(player.animated_sprite.sprite_frames.get_frame_count("idle") == 4)
	# Intro runs at half speed and blocks movement, casts, guard and damage.
	assert(player.intro_active)
	assert(player.animated_sprite.sprite_frames.get_animation_speed("intro") == 5.0)
	var intro_position: Vector2 = player.position
	var intro_children := get_child_count()
	player._cast("right-click", 1, 0.8)
	player._set_guarding(true)
	player.take_damage(100)
	assert(not player.guarding and player.hp == 5)
	assert(get_child_count() == intro_children)
	GameManager.is_replaying = true
	GameManager.replay_frames = [{"dx": 1, "q": true, "lp": true, "shift": true, "slot": 0}]
	player._physics_process(1.0 / 60)
	assert(player.position == intro_position and player.velocity == Vector2.ZERO)
	assert(player.animated_sprite.animation == "intro")
	var intro_duration: float = player.animated_sprite.sprite_frames.get_frame_count("intro") / 5.0
	await get_tree().create_timer(intro_duration + 0.15).timeout
	assert(not player.intro_active and player.animated_sprite.animation == "idle")
	assert(not player.pending_q_skill and not player.pressed_left)
	# The sword hitbox turns with Yugi (it used to stay on the right when he faced left).
	GameManager.replay_frames = [{"ax": -40.0, "ay": 0.0}, {"ax": 40.0, "ay": 0.0}]
	player.replay_frame_idx = 0
	player._physics_process(1.0 / 60)
	assert(player.animated_sprite.flip_h and player.sword_hitbox.scale.x == -1.0)
	assert(player.sword_collision.global_position.x < player.global_position.x)
	player._physics_process(1.0 / 60)
	assert(not player.animated_sprite.flip_h and player.sword_hitbox.scale.x == 1.0)
	assert(player.sword_collision.global_position.x > player.global_position.x)
	player.replay_frame_idx = 0
	GameManager.is_replaying = false
	for move in ["left-click", "right-click", "hold&release-left-click", "hold&release-right-click", "shift+left+click", "result-5"]:
		player._cast(move, 1, 0.5)
		var summon = get_child(get_child_count() - 1)
		assert(summon.get_child(0).sprite_frames.get_frame_count("default") > 0, move)
		print("YUGI animation ", move, ": ", summon.get_child(0).sprite_frames.get_frame_count("default"))
		remove_child(summon)
		summon.free()
	var enemies: Array[Node2D] = []
	for distance in [90, 20, 50, 70]:
		var enemy := RingEnemy.new()
		enemy.position = Vector2(distance, 0)
		var hurtbox := Area2D.new()
		hurtbox.name = "Hurtbox"
		enemy.add_child(hurtbox)
		add_child(enemy)
		enemies.append(enemy)
	player._cast("shift+right+click", 2, 0.8)
	assert(not enemies[0].has_node("YugiTargetRing"))
	for index in [1, 2]:
		var ring = enemies[index].get_node("YugiTargetRing")
		ring.set_physics_process(false)
		assert(ring.position == Vector2.ZERO)
		ring._physics_process(0.36)
		ring._physics_process(0.1)
		assert(enemies[index].received == 2 * player.get_total_damage())
	for enemy in enemies: enemy.received = 0
	player._cast("hold&release-right-click", 3, 0.8)
	var explosion_summon = get_child(get_child_count() - 1)
	explosion_summon.set_physics_process(false)
	assert(is_equal_approx(explosion_summon.global_position.distance_to(player.global_position), 36.0))
	assert(not explosion_summon.get_child(0).sprite_frames.get_animation_loop("default"))
	assert(explosion_summon.get_child(1).disabled)
	assert(is_equal_approx(explosion_summon.lifetime, 2.2))
	var explosion_frames: SpriteFrames = explosion_summon.get_child(0).sprite_frames
	assert(explosion_frames.get_frame_count("default") == 9)
	# Final frames include the caster AND detached particles in one atlas region.
	assert(explosion_frames.get_frame_texture("default", 6).region == Rect2(889, 0, 96, 110))
	# The far-right particles belong to pose 8, never the held recovery pose 9.
	assert(explosion_frames.get_frame_texture("default", 7).region == Rect2(1004, 0, 100, 110))
	assert(explosion_frames.get_frame_texture("default", 8).region == Rect2(1117, 0, 47, 110))
	explosion_summon._physics_process(0.79)
	for enemy in enemies: assert(enemy.received == 0)
	explosion_summon._physics_process(0.02)
	explosion_summon._physics_process(0.2)
	assert(enemies[0].received == 0)
	for index in [1, 2, 3]: assert(enemies[index].received == 3 * player.get_total_damage())
	remove_child(explosion_summon)
	explosion_summon.free()
	for enemy in enemies:
		remove_child(enemy)
		enemy.free()
	assert(player._nearest_ring_targets().is_empty())
	# Right-click has a stationary caster and emits exactly one independent ball.
	player._cast("right-click", 1, 0.8)
	var caster = get_child(get_child_count() - 1)
	caster.set_physics_process(false)
	var origin: Vector2 = caster.position
	assert(is_equal_approx(caster.global_position.distance_to(player.global_position), 36.0))
	assert(caster.global_position.x > player.global_position.x)
	assert(caster.get_child(0).sprite_frames.get_frame_count("default") == 8)
	assert(caster.get_child(1).disabled)
	var children_before := get_child_count()
	caster._physics_process(0.49)
	assert(get_child_count() == children_before)
	caster._physics_process(0.02)
	assert(get_child_count() == children_before + 1)
	var ball = get_child(get_child_count() - 1)
	ball.set_physics_process(false)
	assert(ball.get_node("AnimatedSprite2D").sprite_frames.get_frame_count("fly") == 2)
	assert(ball.damage == player.get_total_damage())
	var ball_origin: Vector2 = ball.position
	ball._physics_process(0.1)
	assert(ball.position.distance_to(ball_origin) > 20)
	caster._physics_process(0.1)
	assert(caster.position == origin and get_child_count() == children_before + 1)
	remove_child(caster)
	caster.free()
	remove_child(ball)
	ball.queue_free()
	player.action_left = 0
	player.suppress_guard = false
	GameManager.is_replaying = true
	GameManager.replay_frames = [{"shift": true}, {"shift": true, "lp": true}]
	player._physics_process(1.0 / 60)
	assert(player.guarding)
	var armor = player.current_armor
	player.take_damage(2)
	assert(player.current_armor == armor)
	player._physics_process(1.0 / 60)
	assert(not player.guarding)
	assert(player.action_left > 0)
	assert(player.guard_summon == null)
	# Hold once, freeze both final frames, release immediately, and re-enter fresh.
	player.action_left = 0
	player.suppress_guard = false
	player.replay_frame_idx = 0
	GameManager.replay_frames = [{"shift": true}, {"shift": true}, {"shift": false}, {"shift": true}]
	player._physics_process(1.0 / 60)
	assert(is_instance_valid(player.guard_summon))
	assert(player.guard_summon.sprite_frames.get_frame_count("default") == 2)
	await get_tree().create_timer(0.8).timeout
	player._physics_process(1.0 / 60)
	assert(player.animated_sprite.frame == 3)
	assert(not player.animated_sprite.is_playing())
	assert(player.guard_summon.frame == 1)
	assert(not player.guard_summon.is_playing())
	player._physics_process(1.0 / 60)
	assert(not player.guarding and player.guard_summon == null)
	player._physics_process(1.0 / 60)
	assert(player.guarding and player.animated_sprite.frame == 0)
	player._set_guarding(false)
	# A press and release inside one physics tick must still cast exactly once.
	player.action_left = 0
	player.replay_frame_idx = 0
	GameManager.replay_frames = [{"lp": true, "lr": true}]
	player._physics_process(1.0 / 60)
	assert(player.action_left > 0)
	assert(player.left_hold < 0)
	# A recorded charge uses the charged animation, without a normal attack first.
	player.action_left = 0
	player.left_hold = 0.8
	player.replay_frame_idx = 0
	GameManager.replay_frames = [{"lr": true}]
	player._physics_process(1.0 / 60)
	assert(player.animated_sprite.animation == "hold&release-left-click")
	# Playback preserves the exact special result rather than rolling again.
	player.action_left = 0
	player.replay_frame_idx = 0
	GameManager.replay_frames = [{"q": true, "result": 5}]
	player._physics_process(1.0 / 60)
	assert(get_child(get_child_count() - 1).move_name == "result-5")
	assert(not player.can_use_skill)
	var sanitized = GameManagerScript._sanitize_replay_frames([{"shift": true, "lp": true, "result": 5}], 10)
	assert(sanitized[0].shift and sanitized[0].lp and sanitized[0].result == 5)
	assert(player.animated_sprite.sprite_frames.get_frame_count("death") == 4)
	assert(not player.animated_sprite.sprite_frames.get_animation_loop("death"))
	player.animated_sprite.play("death")
	await get_tree().create_timer(0.6).timeout
	assert(player.animated_sprite.frame == 3)
	assert(not player.animated_sprite.is_playing())
	assert(is_equal_approx(player.animated_sprite.modulate.a, 1.0))
	var room := BlastRoom.new()
	add_child(room)
	var room_enemies: Array[Node2D] = []
	for index in range(4):
		var enemy := RingEnemy.new()
		enemy.hp = [4, 8, 12, 100][index]
		enemy.position = Vector2(20 + index * 20, 30) if index < 3 else Vector2(220, 30)
		var hurtbox := Area2D.new()
		hurtbox.name = "Hurtbox"
		enemy.add_child(hurtbox)
		room.add_child(enemy)
		room_enemies.append(enemy)
	var blast = preload("res://Scene/Character/Yugi/room_blast.gd").new()
	blast.position = Vector2(36, 30)
	room.add_child(blast)
	blast.set_physics_process(false)
	assert(blast.position == Vector2(36, 30))
	assert(blast.impact_position == Vector2(80, 64))
	blast._physics_process(0.9)
	assert(blast.orb.visible)
	assert(blast.orb.global_position.distance_to(blast.release_position.lerp(blast.impact_position, 0.2)) < 0.001)
	assert(blast.position == Vector2(36, 30))
	for enemy in room_enemies: assert(enemy.received == 0)
	blast._physics_process(0.41)
	assert(blast.last_damage == 4)
	for index in range(3): assert(room_enemies[index].received == 4)
	assert(room_enemies[3].received == 0)
	blast._physics_process(0.1)
	assert(room_enemies[0].received == 4)
	assert(not blast.orb.visible)
	assert(blast.orb.global_position == blast.impact_position)
	for enemy in room_enemies: enemy.is_dead = true
	blast._detonate()
	assert(blast.last_damage == 0)
	# A lone boss loses half its current HP instead of being killed outright.
	room_enemies[0].is_dead = false
	room_enemies[0].hp = 101
	blast._detonate()
	assert(blast.last_damage == 50)
	room_enemies[0].hp = 1
	blast._detonate()
	assert(blast.last_damage == 1)
	room_enemies[0].hp = 4
	for index in range(4):
		room_enemies[index].is_dead = false
		room_enemies[index].received = 0
	var laser = preload("res://Scene/Character/Yugi/room_laser.gd").new()
	laser.position = Vector2(36, 30)
	room.add_child(laser)
	laser.set_physics_process(false)
	laser._physics_process(0.99)
	assert(not laser.beam_active)
	assert(room_enemies[2].received == 0)
	laser._physics_process(0.01)
	assert(laser.monster.frame == 5 and laser.beam_active)
	assert(laser.current_target == room_enemies[2])
	assert(room_enemies[2].received == 1)
	assert(room_enemies[3].received == 0)
	# Dead target: redirect immediately to next highest HP in the same room.
	room_enemies[2].is_dead = true
	laser._physics_process(0.25)
	assert(laser.current_target == room_enemies[1])
	assert(room_enemies[1].received == 1)
	room_enemies[1].free()
	laser._physics_process(0.25)
	assert(laser.current_target == room_enemies[0])
	room_enemies[0].is_dead = true
	laser._physics_process(0.25)
	assert(laser.current_target == null)
	laser._physics_process(2.3)
	assert(not laser.beam_active)
	for index in [0, 2, 3]:
		room_enemies[index].is_dead = false
		room_enemies[index].received = 0
		room_enemies[index].set_physics_process(true)
	var lightning = preload("res://Scene/Character/Yugi/room_lightning.gd").new()
	lightning.position = Vector2(36, 30)
	room.add_child(lightning)
	lightning.set_physics_process(false)
	assert(lightning.monster.sprite_frames.get_frame_count("default") >= 20)
	lightning._physics_process(lightning.strike_time - 0.01)
	assert(room_enemies[0].received == 0)
	lightning._physics_process(0.02)
	for index in [0, 2]:
		assert(room_enemies[index].received == 4)
		assert(not room_enemies[index].is_physics_processing())
		assert(room_enemies[index].has_node("YugiLightningStun"))
	assert(room_enemies[3].received == 0 and room_enemies[3].is_physics_processing())
	lightning._physics_process(0.1)
	assert(room_enemies[0].received == 4)
	var stun = room_enemies[0].get_node("YugiLightningStun")
	stun.set_physics_process(false)
	stun._physics_process(0.5)
	preload("res://Scene/Character/Yugi/lightning_hit.gd").apply(room_enemies[0])
	assert(stun.remaining == 2.0)
	stun._physics_process(1.9)
	assert(not room_enemies[0].is_physics_processing())
	stun._physics_process(0.11)
	assert(room_enemies[0].is_physics_processing())
	for index in [0, 2, 3]:
		var enemy = room_enemies[index]
		var status = enemy.get_node_or_null("YugiLightningStun")
		if status != null: status.free()
		enemy.set_physics_process(true)
		enemy.received = 0
	var pull = preload("res://Scene/Character/Yugi/room_pull.gd").new()
	pull.position = Vector2(36, 64)
	room.add_child(pull)
	pull.set_physics_process(false)
	pull._physics_process(pull.pull_time + 0.01)
	assert(pull.locked.size() == 2)
	for index in [0, 2]:
		assert(room_enemies[index].position.x > pull.position.x)
		assert(not room_enemies[index].is_physics_processing())
	assert(room_enemies[3].is_physics_processing())
	var pinned: Vector2 = room_enemies[0].position
	room_enemies[0].position += Vector2(30, 30)
	pull._physics_process(0.01)
	assert(room_enemies[0].position == pinned)
	pull._physics_process(pull.hit_time - pull.elapsed + 0.01)
	assert(room_enemies[0].received == 4 and room_enemies[2].received == 4)
	pull._physics_process(0.01)
	assert(room_enemies[0].received == 4)
	pull._physics_process(pull.end_time - pull.elapsed + 0.01)
	assert(room_enemies[0].is_physics_processing() and room_enemies[2].is_physics_processing())
	assert(room_enemies[3].received == 0)
	for index in [0, 2, 3]: room_enemies[index].received = 0
	var fire = preload("res://Scene/Character/Yugi/room_fire.gd").new()
	fire.position = Vector2(36, 30)
	room.add_child(fire)
	fire.set_physics_process(false)
	fire._physics_process(fire.start_time - 0.01)
	assert(fire.beams.is_empty())
	fire._physics_process(0.02)
	assert(fire.beams.size() == 2)
	assert(room_enemies[0].received == 1 and room_enemies[2].received == 1)
	assert(room_enemies[3].received == 0)
	var beam = fire.beams[room_enemies[0].get_instance_id()]
	assert(beam.phase == 0)
	var old_length: float = beam.length
	room_enemies[0].position += Vector2(10, 0)
	fire._physics_process(0.1)
	assert(beam.phase == 1 and beam.length != old_length)
	room_enemies[2].is_dead = true
	fire._physics_process(0.01)
	assert(fire.beams.size() == 1)
	fire._physics_process(3.0)
	assert(not fire.fire_active and fire.beams.is_empty())
	print("YUGI TESTS PASSED")
	get_tree().quit()
