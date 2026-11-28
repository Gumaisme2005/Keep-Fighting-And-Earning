extends RefCounted
const Steps = preload("res://Scene/Tutorial/tutorial_steps.gd")
const TITLES := ["Find your footing", "Strike the training dummy", "Unleash your skill", "Collect practice armor", "Equip your armor", "Armor, health and recovery", "Drink a healing potion", "Enter the dungeon"]
const SKILLS := ["Orthanc Fire", "Durin's Wrath", "Sovereign Rush", "Triple Flurry", "Special Summon", "Friends", "Frost Bloom", "White Moon"]
const EFFECTS := ["Aim the explosive at the dummy.", "Activate the damage buff.", "Charge through the dummy.", "Stand beside the dummy for three slashes.", "Aim at the dummy; any of the five summons counts.", "Aim at the dummy and call a friend. A fresh lesson starts on Air Cannon.", "Aim the ice spikes through the dummy.", "Transform into the white-haired form."]

static func binding(action: StringName) -> String:
	var names: Array[String] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			names.append(OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode))
		elif event is InputEventMouseButton:
			names.append("Left Click" if event.button_index == MOUSE_BUTTON_LEFT else "Right Click" if event.button_index == MOUSE_BUTTON_RIGHT else event.as_text())
		else:
			names.append(event.as_text())
	return " / ".join(names) if not names.is_empty() else "Unbound: " + String(action)

static func instruction(step: int, hero: int) -> String:
	match step:
		Steps.Step.MOVEMENT:
			return "%s / %s / %s / %s\nWalk at least 24 pixels in three different cardinal directions." % [binding(&"move_up"), binding(&"move_left"), binding(&"move_down"), binding(&"move_right")]
		Steps.Step.BASIC_ATTACK:
			return "%s: approach and hit the dummy.\n%s" % [binding(&"attack"), "Press then release to summon." if hero == 4 else "Aim with the mouse inside the arena."]
		Steps.Step.HERO_SKILL:
			return "%s: %s\n%s Wait for cooldown if needed." % [binding(&"skill_1"), SKILLS[hero], EFFECTS[hero]]
		Steps.Step.PICKUP_ITEM:
			return "%s: stand beside the glowing armor and collect it." % binding(&"interact")
		Steps.Step.EQUIP_ITEM:
			return "Click the collected armor in your PRACTICE bag, or use its numbered hotbar key."
		Steps.Step.HEALTH_AND_ARMOR:
			return "Walk onto the red rune. Let it hit twice, then wait for natural armor regeneration. Keep the practice armor equipped."
		Steps.Step.USE_POTION:
			return "Click your potion or press its numbered hotbar key while HP is missing. Full HP? Step onto the red rune again. Cooldown is 8 seconds."
		Steps.Step.DUNGEON_ENTRY:
			return "Practice is complete. Find the Rune Portal in the hall, press %s and confirm when ready. Your original hero and equipment are intact." % binding(&"interact")
	return ""
