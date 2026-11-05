extends Sprite2D
## The Anywhere Door left behind at the spot Doraemon stepped through; it fades away.

const Sprites = preload("res://scenes/characters/doraemon/DoraemonSprites.gd")
var flip: bool = false
var age: float = 0.0

func _ready() -> void:
	var info: Dictionary = Sprites.ANIMS["door_in"]
	var cell: Vector2 = info["cell"]
	var anchor: Vector2 = info["anchor"]
	var atlas := AtlasTexture.new()
	atlas.atlas = Sprites.texture(String(info["file"]))
	atlas.region = Rect2(Vector2(cell.x, 0), cell) # frame 2: closed door, Doraemon already inside
	texture = atlas
	centered = false
	flip_h = flip
	offset = Vector2(-(cell.x - anchor.x) if flip else -anchor.x, -anchor.y)
	scale = Vector2(0.9, 0.9)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1

func _physics_process(delta: float) -> void:
	age += delta
	modulate.a = clampf(1.0 - (age - 0.25) / 0.35, 0.0, 1.0)
	if age >= 0.6:
		queue_free()
