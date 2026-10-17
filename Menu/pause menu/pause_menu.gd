
extends Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

func _unhandled_input(event: InputEvent) -> void:
	var game_over_menu := get_tree().get_first_node_in_group("game_over_menu")
	if game_over_menu != null and game_over_menu.is_visible_in_tree():
		return
	if event.is_action_pressed("esc") and not event.is_echo():
		if get_tree().paused:
			resume()
		else:
			pause()

func resume() -> void:
	get_tree().paused = false
	hide()

func pause() -> void:
	show()
	get_tree().paused = true

func _on_resume_button_pressed() -> void:
	resume()

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_exit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
