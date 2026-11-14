extends Node2D
## Đồ trang trí lơ lửng trong Guild Hall (Dark Magician Girl, linh hồn của Miyabi): nhấp nhô lên xuống nhẹ.
## Gắn vào Sprite2D / AnimatedSprite2D; chỉ đổi `offset` nên vị trí sắp xếp (y-sort) và va chạm không đổi.

@export var amplitude := 1.5   # px trong sảnh
@export var period := 2.4      # giây cho một lần lên xuống

var _base := Vector2.ZERO
var _t := 0.0

func _ready() -> void:
	_base = get("offset")
	_t = fmod(absf(position.x) * 0.37, period)   # mỗi món lệch nhịp một chút
	_apply()

func _process(delta: float) -> void:
	_t += delta
	_apply()

func _apply() -> void:
	# làm tròn theo điểm ảnh của sảnh để hình không bị nhoè
	var dy := roundf(sin(_t * TAU / period) * amplitude) / maxf(0.01, scale.y)
	set("offset", _base + Vector2(0, dy))
