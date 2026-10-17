extends Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_over_menu")
	hide()

func pause() -> void:
	var pause_menu := get_node_or_null("../pause_menu")
	if pause_menu != null:
		pause_menu.hide()
	show()
	get_tree().paused = true
	$MarginContainer/HBoxContainer/VBoxContainer/Retry_button.grab_focus()

func _on_retry_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scene/UI/CharacterSelect.tscn")

func _on_exit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
