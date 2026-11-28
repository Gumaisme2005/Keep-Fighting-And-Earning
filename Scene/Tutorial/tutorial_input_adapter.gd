extends RefCounted
## Polling and event input share one authority. UI clicks never arm world input.
var enabled := false
var mouse_actions: Dictionary = {}

func clear() -> void:
	enabled = false
	mouse_actions.clear()

func observe(event: InputEvent) -> void:
	for action in [&"attack", &"skill_2"]:
		if event.is_action(action):
			mouse_actions[action] = event.is_pressed()

func pressed(action: StringName, just := false) -> bool:
	if not enabled:
		return false
	if action in [&"attack", &"skill_2"] and not mouse_actions.get(action, false):
		return false
	return Input.is_action_just_pressed(action) if just else Input.is_action_pressed(action)

func direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down") if enabled else Vector2.ZERO

func shift() -> bool:
	return enabled and Input.is_physical_key_pressed(KEY_SHIFT)

static func neutral() -> bool:
	for action in [&"move_left", &"move_right", &"move_up", &"move_down", &"attack", &"skill_1", &"skill_2", &"interact", &"esc"]:
		if Input.is_action_pressed(action):
			return false
	for key in [KEY_SHIFT, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_Z, KEY_X, KEY_F]:
		if Input.is_physical_key_pressed(key) or Input.is_key_pressed(key):
			return false
	return not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
