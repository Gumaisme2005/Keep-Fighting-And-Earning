class_name PerkData
extends Resource

enum Rarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

const RARITY_NAMES: Dictionary = {
	Rarity.COMMON: "Thường (Common)",
	Rarity.RARE: "Hiếm (Rare)",
	Rarity.EPIC: "Sử Thi (Epic)",
	Rarity.LEGENDARY: "Huyền Thoại (Legendary)"
}

const RARITY_COLORS: Dictionary = {
	Rarity.COMMON: Color(0.40, 0.75, 0.40),    # Emerald / Soft Green
	Rarity.RARE: Color(0.35, 0.65, 0.95),      # Cerulean / Blue
	Rarity.EPIC: Color(0.78, 0.42, 0.95),      # Amethyst / Purple
	Rarity.LEGENDARY: Color(1.00, 0.75, 0.20)  # Radiant Gold
}

const RARITY_BORDER_COLORS: Dictionary = {
	Rarity.COMMON: Color(0.28, 0.55, 0.30, 0.9),
	Rarity.RARE: Color(0.25, 0.48, 0.85, 0.9),
	Rarity.EPIC: Color(0.60, 0.30, 0.85, 0.95),
	Rarity.LEGENDARY: Color(0.95, 0.70, 0.15, 1.0)
}

@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var icon_pixel_path: String = ""
@export var icon_full_path: String = ""
@export var is_unique: bool = true
@export var modifiers: Dictionary = {}

var _cached_pixel_texture: Texture2D = null
var _cached_full_texture: Texture2D = null

func get_rarity_name() -> String:
	return RARITY_NAMES.get(rarity, "Thường")

func get_rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)

func get_rarity_border_color() -> Color:
	return RARITY_BORDER_COLORS.get(rarity, Color.GRAY)

func get_pixel_texture() -> Texture2D:
	if _cached_pixel_texture == null:
		if not icon_pixel_path.is_empty():
			_cached_pixel_texture = _load_texture_file(icon_pixel_path)
		if _cached_pixel_texture == null and not icon_full_path.is_empty():
			_cached_pixel_texture = _load_texture_file(icon_full_path)
	return _cached_pixel_texture

func get_full_texture() -> Texture2D:
	if _cached_full_texture == null:
		if not icon_full_path.is_empty():
			_cached_full_texture = _load_texture_file(icon_full_path)
		if _cached_full_texture == null and not icon_pixel_path.is_empty():
			_cached_full_texture = _load_texture_file(icon_pixel_path)
	return _cached_full_texture

static func _load_texture_file(res_path: String) -> Texture2D:
	if res_path.is_empty():
		return null

	# 1. Thử nạp qua ResourceLoader (nếu engine đã import)
	if ResourceLoader.exists(res_path):
		var res = ResourceLoader.load(res_path)
		if res is Texture2D:
			return res

	# 2. Nạp trực tiếp từ file PNG (khi chạy chưa qua editor import)
	var paths_to_try: Array[String] = [
		ProjectSettings.globalize_path(res_path),
		res_path
	]
	for p in paths_to_try:
		if FileAccess.file_exists(p):
			var img := Image.load_from_file(p)
			if img != null and not img.is_empty():
				return ImageTexture.create_from_image(img)
			var img_fallback := Image.new()
			if img_fallback.load(p) == OK and not img_fallback.is_empty():
				return ImageTexture.create_from_image(img_fallback)

	return null

func get_modifier(key: String, default_val: Variant = 0) -> Variant:
	return modifiers.get(key, default_val)
