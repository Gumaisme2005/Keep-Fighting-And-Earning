extends Control

# Tự động nạp sẵn 2 nhân vật để tránh quên kéo thả ngoài Inspector
@export var char_1_scene: PackedScene = preload("res://Scene/Character/player.tscn")
@export var char_2_scene: PackedScene = preload("res://Scene/Character/player_2.tscn")

# Đường dẫn tới màn chơi chính (Kiểm tra lại xem file world.tscn của cậu nằm ở thư mục nào nhé)
@export_file("*.tscn") var game_world_path: String = "res://world.tscn"

func _ready() -> void:
	# Kết nối đúng với tên node Char_1 và Char_2 trên cây Scene của cậu
	$HBoxContainer/Char_1.pressed.connect(_on_select_char_1)
	$HBoxContainer/Char_2.pressed.connect(_on_select_char_2)

func _on_select_char_1() -> void:
	print("✅ Đã chọn nhân vật 1: Soldier")
	GameManager.selected_character_scene = char_1_scene
	_start_game()

func _on_select_char_2() -> void:
	print("✅ Đã chọn nhân vật 2: Miyabi")
	GameManager.selected_character_scene = char_2_scene
	_start_game()

func _start_game() -> void:
	var err = get_tree().change_scene_to_file(game_world_path)
	if err != OK:
		print("❌ LỖI: Không tìm thấy file màn chơi tại đường dẫn: ", game_world_path)
