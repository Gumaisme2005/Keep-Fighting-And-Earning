extends Control

# Match the portraits from left to right: archer, knight, soldier, swordsman.
@export var character_scenes: Array[PackedScene] = [
	preload("res://Scene/Character/Player 3_Miya/player_3.tscn"),
	preload("res://Scene/Character/Player 2_Olaf/player_2.tscn"),
	preload("res://Scene/Character/Player 1_Pyrois/player.tscn"),
	preload("res://Scene/Character/Player 4_Charlotte/player_4.tscn"),
]
@export_file("*.tscn") var game_world_path: String = "res://world.tscn"

@onready var navigation: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer
@onready var scroll_container: ScrollContainer = navigation.get_node("ScrollContainer")
@onready var object_container: HBoxContainer = scroll_container.get_node("HBoxContainer")
@onready var previous_button: Button = navigation.get_node("TextureRect/PreviousButton")
# The right arrow is also named PreviousButton in this scene.
@onready var next_button: Button = navigation.get_node("TextureRect2/PreviousButton")
@onready var hero_selection_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HeroSelectionButton
@onready var selection_marker: Control = $SelectMaker

var target_scroll: float = 0.0
var selected_index: int = 0
var portraits: Array[TextureRect] = []
var scroll_tween: Tween
var game_window: Window
var normal_window_size: Vector2i
var normal_window_position: Vector2i
var normal_content_scale_size: Vector2i
var normal_window_mode: Window.Mode


func _ready() -> void:
	_resize_for_character_select()
	for child in object_container.get_children():
		if child is TextureRect:
			portraits.append(child)

	previous_button.pressed.connect(_on_previous_button_pressed)
	next_button.pressed.connect(_on_next_button_pressed)
	hero_selection_button.pressed.connect(_on_hero_selection_button_pressed)
	selection_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_selection_button.disabled = true
	previous_button.disabled = true
	next_button.disabled = true

	# Containers need to finish arranging their children before measuring them.
	await get_tree().process_frame
	await get_tree().process_frame
	if portraits.is_empty():
		return
	target_scroll = _get_portrait_scroll(selected_index)
	scroll_container.scroll_horizontal = roundi(target_scroll)
	_select_deselect_highlight()
	_update_buttons()


func _resize_for_character_select() -> void:
	game_window = get_window()
	# Remember the title screen's actual size, including any user resizing.
	normal_window_size = game_window.size
	normal_window_position = game_window.position
	normal_content_scale_size = game_window.content_scale_size
	normal_window_mode = game_window.mode
	var select_size := Vector2i(size)
	var window_center := normal_window_position + normal_window_size / 2
	game_window.mode = Window.MODE_WINDOWED
	game_window.content_scale_size = select_size
	game_window.size = select_size
	game_window.position = window_center - select_size / 2


func _exit_tree() -> void:
	# Scene changes remove this screen before adding the level. Restore here
	# so returning to the title also restores the original window settings.
	if not is_instance_valid(game_window):
		return
	game_window.content_scale_size = normal_content_scale_size
	game_window.size = normal_window_size
	game_window.position = normal_window_position
	game_window.mode = normal_window_mode


func _on_previous_button_pressed() -> void:
	_select_index(selected_index - 1)


func _on_next_button_pressed() -> void:
	_select_index(selected_index + 1)


func _select_index(index: int) -> void:
	if portraits.is_empty():
		return
	selected_index = clampi(index, 0, portraits.size() - 1)
	_tween_scroll(_get_portrait_scroll(selected_index))


func _get_portrait_scroll(index: int) -> float:
	var portrait := portraits[index]
	var center_x := portrait.get_global_rect().get_center().x
	var marker_x := selection_marker.get_global_rect().get_center().x
	var scrollbar := scroll_container.get_h_scroll_bar()
	# Measure each portrait individually, since their widths can differ.
	return clampf(
		scroll_container.scroll_horizontal + center_x - marker_x,
		scrollbar.min_value,
		maxf(scrollbar.min_value, scrollbar.max_value - scrollbar.page)
	)


func _tween_scroll(scroll_value: float) -> void:
	if scroll_tween != null and scroll_tween.is_running():
		scroll_tween.kill()
	target_scroll = scroll_value
	hero_selection_button.disabled = true
	scroll_tween = create_tween()
	scroll_tween.tween_property(scroll_container, "scroll_horizontal", roundi(target_scroll), 0.25)
	scroll_tween.finished.connect(_on_scroll_finished)
	previous_button.disabled = selected_index == 0
	next_button.disabled = selected_index == portraits.size() - 1


func _on_scroll_finished() -> void:
	_select_deselect_highlight()
	_update_buttons()


func get_selected_value() -> TextureRect:
	# Use horizontal distance so the marker may sit below a short portrait.
	var marker_x := selection_marker.get_global_rect().get_center().x
	var selected: TextureRect = null
	var nearest_distance: float = INF
	for portrait in portraits:
		var distance := absf(portrait.get_global_rect().get_center().x - marker_x)
		if distance < nearest_distance:
			nearest_distance = distance
			selected = portrait
	return selected


func _select_deselect_highlight() -> void:
	var selected := get_selected_value()
	for portrait in portraits:
		portrait.modulate = Color.WHITE if portrait == selected else Color.BLACK
	if selected != null:
		selected_index = portraits.find(selected)


func _update_buttons() -> void:
	previous_button.disabled = portraits.is_empty() or selected_index == 0
	next_button.disabled = portraits.is_empty() or selected_index == portraits.size() - 1
	hero_selection_button.disabled = (
		portraits.is_empty() or selected_index >= character_scenes.size()
		or character_scenes[selected_index] == null
	)


func _on_hero_selection_button_pressed() -> void:
	if hero_selection_button.disabled:
		return
	GameManager.selected_character_scene = character_scenes[selected_index]
	var error := get_tree().change_scene_to_file(game_world_path)
	if error != OK:
		push_error("Could not open game world: %s (error %s)" % [game_world_path, error])
