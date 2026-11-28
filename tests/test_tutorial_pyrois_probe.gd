extends Node
const Context = preload("res://Scene/Tutorial/tutorial_training_context.gd")
const Session = preload("res://Scene/Tutorial/tutorial_session.gd")
var passed := 0
var failed := 0

class ContactDummy extends Node2D:
	var hp := 100
	var is_dead := false
	var hits: Array = []
	func _ready() -> void:
		var area := Area2D.new()
		area.name = "Hurtbox"
		area.collision_layer = 1
		area.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(17, 24)
		shape.shape = rectangle
		shape.position.y = -12
		area.add_child(shape)
		add_child(area)
	func take_damage(amount: int, _piercing := 0.0) -> void:
		hp -= amount
		hits.append(amount)

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("  [PASS] ", label)
	else:
		failed += 1
		printerr("  [FAIL] ", label)

func ticks(count: int) -> void:
	for unused in count: await get_tree().physics_frame

func _ready() -> void:
	await ticks(2)
	for sample in 5:
		for phase in ["production", "training"]:
			var holder: Node
			var actor: CharacterBody2D
			var target: Node2D
			if phase == "production":
				holder = Node2D.new()
				get_tree().root.add_child(holder)
				get_tree().current_scene = holder
				actor = GameManager.CHARACTER_SCENES[2].instantiate()
				holder.add_child(actor)
				actor.position = Vector2(200, 200)
				target = ContactDummy.new()
				holder.add_child(target)
			else:
				get_tree().current_scene = self
				var session := Session.new({2: {2: 2}}) # Keep the lesson alive after its first valid skill hit.
				session.start_tutorial(2)
				holder = Context.new()
				add_child(holder)
				check(holder.bind(session), "Pyrois real training context")
				actor = holder.hero
				for action in ["move_up", "move_left", "move_down"]:
					Input.action_press(action)
					await ticks(14)
					Input.action_release(action)
					await ticks(2)
				var basic: Node2D = holder.add_target(actor.position + Vector2(24, 0))
				actor.training_aim = Vector2(24, -12)
				Input.action_press("attack")
				await ticks(2)
				Input.action_release("attack")
				await ticks(100)
				check(session.get_current_step() == 2, "Probe reaches skill by actual movement/basic contact")
				basic.free()
				target = holder.add_target(actor.position + Vector2(60, 0))
			await ticks(60) # Compare steady gameplay, after scene/camera initialization.
			var facing := -1.0 if actor.get_aim_world_position().x < actor.global_position.x else 1.0
			target.position = actor.position + Vector2(facing * 60, 0)
			actor.training_aim = Vector2(facing * 60, -12)
			var origin: Vector2 = actor.position
			var start: int = Engine.get_physics_frames()
			var contacts: Array = []
			actor.sword_hitbox.area_entered.connect(func(area):
				if area.name == "Hurtbox": contacts.append(Engine.get_physics_frames() - start))
			var key := InputEventKey.new()
			key.keycode = KEY_Q
			key.physical_keycode = KEY_Q
			key.pressed = true
			actor._unhandled_input(key) # Native pending-Q path, then the real hero physics callback.
			await ticks(1)
			key = key.duplicate()
			key.pressed = false
			actor._unhandled_input(key)
			var hp_before: int = actor.hp
			var armor_before: int = actor.current_armor
			actor.take_damage(1)
			check(actor.is_invincible and actor.hp == hp_before and actor.current_armor == armor_before, "Charge starts with real damage immunity " + phase)
			var window_tick := -1
			for unused in 120:
				await ticks(1)
				if window_tick < 0 and not actor.sword_collision.disabled: window_tick = Engine.get_physics_frames() - start
				if not actor.is_casting_skill: break
			var end_tick: int = Engine.get_physics_frames() - start
			var distance: float = actor.position.distance_to(origin)
			check(not actor.is_casting_skill and not actor.is_invincible and actor.sword_collision.disabled and actor.velocity.is_zero_approx(), "Charge recovers and closes hit/immunity windows " + phase)
			# Production uses the original idle clock; its quantization is a render
			# interval plus a physics sample. Training uses the fixed physics clock.
			# The TASK 3 historical sample at 30 FPS also measures 40 pixels, so a
			# physics-only 42px lower bound would reject the original production code.
			var quantum := 1.0 / float(Engine.max_fps if phase == "production" else Engine.physics_ticks_per_second)
			var slack := ceili(quantum * Engine.physics_ticks_per_second) + 1
			var minimum_distance := 150.0 * (0.3 - quantum - 1.0 / Engine.physics_ticks_per_second)
			var maximum_distance := 150.0 * (0.3 + quantum + 1.0 / Engine.physics_ticks_per_second)
			check(window_tick >= 18 - slack and window_tick <= 18 + slack and end_tick >= 30 - slack and end_tick <= 30 + slack * 2 \
				and distance >= minimum_distance and distance <= maximum_distance,
				"Charge respects configured .3/.2-second windows and its actual clock quantization " + phase)
			check(contacts.size() == 1 and (target.hits == [3] if phase == "production" else target.contacts == 1), "One actual collision and expected damage/contact " + phase)
			actor.take_damage(1)
			check(actor.current_armor < armor_before, "Damage guard ends with charge recovery " + phase)
			print("[PYROIS_PROBE] ", JSON.stringify({"sample": sample, "phase": phase, "render_fps": Engine.max_fps, "physics_hz": Engine.physics_ticks_per_second,
				"window_tick": window_tick, "recovery_tick": end_tick, "distance": distance, "direction": facing, "delta_x": actor.position.x - origin.x, "contact_ticks": contacts,
				"damage": target.hits if phase == "production" else [], "training_contacts": target.contacts if phase == "training" else 0}))
			print("[PYROIS_", phase.to_upper(), "_VERIFIED]")
			holder.free()
			await ticks(3)
	print("TEST RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	print("[TUTORIAL_PYROIS_PROBE_COMPLETE]")
	get_tree().quit(1 if failed else 0)
