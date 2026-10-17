extends Control

# Tự động nạp sẵn 4 nhân vật
@export var char_1_scene: PackedScene = preload("res://Scene/Character/Player 1_Pyrois/player.tscn")
@export var char_2_scene: PackedScene = preload("res://Scene/Character/Player 2_Olaf/player_2.tscn")
@export var char_3_scene: PackedScene = preload("res://Scene/Character/Player 3_Miya/player_3.tscn") 
@export var char_4_scene: PackedScene = preload("res://Scene/Character/Player 4_Charlotte/player_4.tscn") # Thêm Nữ Kiếm Sĩ

# Đường dẫn tới màn chơi chính
@export_file("*.tscn") var game_world_path: String = "res://world.tscn"

func _ready() -> void:
	# Kết nối 4 nút bấm trên màn hình với 4 hàm ở dưới
	$HBoxContainer/Char_1.pressed.connect(_on_select_char_1)
	$HBoxContainer/Char_2.pressed.connect(_on_select_char_2)
	$HBoxContainer/Char_3.pressed.connect(_on_select_char_3) 
	$HBoxContainer/Char_4.pressed.connect(_on_select_char_4) # Nút của Nữ Kiếm Sĩ

func _on_select_char_1() -> void:
	print("✅ Đã chọn nhân vật 1: Soldier")
	GameManager.selected_character_scene = char_1_scene
	_start_game()

func _on_select_char_2() -> void:
	print("✅ Đã chọn nhân vật 2: Olaf")
	GameManager.selected_character_scene = char_2_scene
	_start_game()

func _on_select_char_3() -> void:
	print("✅ Đã chọn nhân vật 3: Miya")
	GameManager.selected_character_scene = char_3_scene
	_start_game()

# --- HÀM MỚI CHO NỮ KIẾM SĨ ---
func _on_select_char_4() -> void:
	print("✅ Đã chọn nhân vật 4: Nữ Kiếm Sĩ")
	GameManager.selected_character_scene = char_4_scene
	_start_game()

func _start_game() -> void:
	var err = get_tree().change_scene_to_file(game_world_path)
	if err != OK:
		print("❌ LỖI: Không tìm thấy file màn chơi tại đường dẫn: ", game_world_path)
