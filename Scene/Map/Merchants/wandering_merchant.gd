extends "res://Scene/Map/GuildHall/blacksmith_npc.gd"
## Thương nhân lang thang trong hầm ngục.
## Cứ sau khi người chơi vượt 2 tầng thì tầng tiếp theo (tầng 3, 6, 9, 12…) có SPAWN_CHANCE khả năng
## xuất hiện 1 trong 2 người (mỗi người 50%), đứng ở góc phòng xuất phát. Các tầng khác không có ai:
##   - Hiệp sĩ Joanna (cầm kiếm)            -> cửa hàng 3 món giáp / vũ khí ngẫu nhiên.
##   - Pháp sư Eleonore (quả cầu lửa bên tay) -> cửa hàng 3 loại thuốc ngẫu nhiên.
## Có xuất hiện hay không, là ai và bán gì đều tính từ seed của lượt chơi + số tầng (cùng seed -> cùng kết quả,
## không dùng chung bộ số ngẫu nhiên với việc sinh bản đồ). Đứng gần sẽ hiện "[E] SHOP", nhấn E để mở cửa hàng
## (cách tương tác kế thừa từ blacksmith_npc.gd). Hàng đã mua giữ nguyên khi mở lại trong cùng tầng.

const MerchantOffer := preload("res://Scene/UI/Shop/merchant_offer.gd")
const MERCHANT_SHOP_SCRIPT := preload("res://Scene/UI/Shop/MerchantShopUI.gd")
const PROMPT_TEX := preload("res://Assets/UI/Shop/prompt_shop.png")
const SHADOW_TEX := preload("res://Assets/Map/Merchants/merchant_shadow.png")

## Tầng đầu tiên có thể gặp thương nhân (= đã vượt 2 tầng).
const MIN_FLOOR := 3
## Sau đó cứ mỗi FLOOR_INTERVAL tầng lại có 1 tầng có thể gặp (vượt 2 tầng thường -> tầng kế tiếp): 3, 6, 9, 12…
const FLOOR_INTERVAL := 3
## Khả năng 1 tầng như vậy có 1 thương nhân.
const SPAWN_CHANCE := 0.5
const NO_CELL := Vector2i(-9999, -9999)
## Đèn nhỏ ánh trắng ấm để nhìn rõ màu áo trong hầm tối (mạnh hơn sẽ bị cháy sáng khi đứng cạnh đuốc).
const GLOW_COLOR := Color(1.0, 0.97, 0.92)
const GLOW_ENERGY := 0.7

## Hình dáng từng người: sprite sheet ngang (khung 64x64), số khung, tốc độ, điểm chân trong khung,
## vị trí gợi ý [E] SHOP, bóng đổ.
const LOOKS := {
	MerchantOffer.KIND_KNIGHT: {"name": "Joanna", "sheet": "res://Assets/Map/Merchants/joanna_idle.png", "frames": 6, "fps": 7.0,
		"feet": Vector2(-32, -53), "prompt_y": -52.0, "shadow_scale": Vector2(2, 1)},
	MerchantOffer.KIND_WITCH: {"name": "Eleonore", "sheet": "res://Assets/Map/Merchants/eleonore_idle.png", "frames": 9, "fps": 9.0,
		"feet": Vector2(-35, -61), "prompt_y": -62.0, "shadow_scale": Vector2(1, 1)},
}

var kind: int = MerchantOffer.KIND_KNIGHT
## Hàng đang bán (merchant_offer.gd).
var offer: RefCounted = null

# ------------------------------------------------------------------ xuất hiện

## Tầng `level` có được tung khả năng gặp thương nhân không (tầng 3, 6, 9, 12…).
static func is_merchant_floor(level: int) -> bool:
	return level >= MIN_FLOOR and (level - MIN_FLOOR) % FLOOR_INTERVAL == 0

## Tầng `level` của lượt `seed_text` có thương nhân nào: KIND_KNIGHT / KIND_WITCH, hoặc -1 nếu không có ai.
static func roll_kind(seed_text: String, level: int) -> int:
	if not is_merchant_floor(level):
		return -1
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%s_wandering_merchant_%d" % [seed_text, level]).hash()
	if rng.randf() >= SPAWN_CHANCE:
		return -1
	return MerchantOffer.KIND_KNIGHT if rng.randf() < 0.5 else MerchantOffer.KIND_WITCH

## Tạo thương nhân `merchant_kind` (kèm hàng của tầng đó), chưa gắn vào cây.
static func create(merchant_kind: int, seed_text: String, level: int) -> AnimatedSprite2D:
	var m: AnimatedSprite2D = (load("res://Scene/Map/Merchants/wandering_merchant.gd") as GDScript).new()
	m.kind = merchant_kind
	m.offer = MerchantOffer.roll(merchant_kind, seed_text, level)
	m.build_parts()
	return m

## Gọi khi dựng thực thể của tầng (DungeonSpawner.spawn_entities): có thương nhân thì đặt ở góc phòng xuất phát.
static func spawn_on_floor(gen: TileMap) -> AnimatedSprite2D:
	if gen.generated_rooms.is_empty():
		return null
	var seed_text: String = gen.map_seed
	var level: int = gen.current_level
	var merchant_kind := roll_kind(seed_text, level)
	if merchant_kind < 0:
		return null
	var cell := find_spot(gen, gen.generated_rooms[0])
	if cell == NO_CELL:
		return null
	var m := create(merchant_kind, seed_text, level)
	m.name = "WanderingMerchant"
	gen.add_child(m)
	m.position = gen.map_to_local(cell) + Vector2(0, 6)
	print("[MERCHANT] Tầng ", level, " - ", LOOKS[merchant_kind].name, " đang chờ ở phòng xuất phát.")
	return m

## Ô đứng trong phòng `room`: ưu tiên góc trên-trái (như hình mẫu), rồi các góc còn lại; tránh tường, đồ trang trí,
## bẫy, hành lang và chỗ người chơi xuất hiện giữa phòng.
static func find_spot(gen: TileMap, room: Rect2i) -> Vector2i:
	var corners: Array[Vector2i] = [
		Vector2i(room.position.x + 1, room.position.y + 3),
		Vector2i(room.end.x - 2, room.position.y + 3),
		Vector2i(room.position.x + 1, room.end.y - 2),
		Vector2i(room.end.x - 2, room.end.y - 2),
	]
	var center := room.get_center()
	for corner in corners:
		for dist in 4:
			for dy in range(-dist, dist + 1):
				for dx in range(-dist, dist + 1):
					if maxi(absi(dx), absi(dy)) != dist:
						continue
					var c := corner + Vector2i(dx, dy)
					if _good_cell(gen, room, center, c):
						return c
	return NO_CELL

static func _good_cell(gen: TileMap, room: Rect2i, center: Vector2i, c: Vector2i) -> bool:
	if not room.grow(-1).has_point(c):
		return false
	if absi(c.x - center.x) <= 4 and absi(c.y - center.y) <= 4:
		return false
	if not gen.is_valid_entity_spawn_cell(c):
		return false
	# thân người cao ~3 ô: các ô phía trên cũng phải là sàn trống
	for dy in range(-3, 2):
		for dx in range(-1, 2):
			var k := c + Vector2i(dx, dy)
			if gen.get_cell_atlas_coords(gen.LAYER_FLOOR, k) != gen.FLOOR_COORD:
				return false
			if gen.corridor_cells.has(k) or gen.reserved_trap_positions.has(k):
				return false
	return true

# ------------------------------------------------------------------ dựng node

## Sprite chạy idle + bóng + vùng nói chuyện + gợi ý [E] SHOP + thân chắn đường + ánh sáng nhỏ.
func build_parts() -> void:
	var look: Dictionary = LOOKS[kind]
	add_to_group("merchant")
	z_index = 2
	var sheet: Texture2D = load(look.sheet)
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", look.fps)
	for i in int(look.frames):
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * 64, 0, 64, 64)
		sf.add_frame("idle", at)
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sprite_frames = sf
	animation = "idle"
	autoplay = "idle"
	centered = false
	offset = look.feet

	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = SHADOW_TEX
	shadow.scale = look.shadow_scale
	shadow.modulate = Color(1, 1, 1, 0.6)
	shadow.show_behind_parent = true
	add_child(shadow)

	var area := Area2D.new()
	area.name = "TalkArea"
	area.monitorable = false
	var area_shape := CollisionShape2D.new()
	area_shape.name = "Shape"
	var circle := CircleShape2D.new()
	circle.radius = 30.0
	area_shape.shape = circle
	area_shape.position = Vector2(0, -12)
	area.add_child(area_shape)
	add_child(area)

	var prompt := Sprite2D.new()
	prompt.name = "Prompt"
	prompt.texture = PROMPT_TEX
	prompt.z_index = 5
	prompt.position = Vector2(0, look.prompt_y)
	prompt.visible = false
	add_child(prompt)

	var body := StaticBody2D.new()
	body.name = "Body"
	var body_shape := CollisionShape2D.new()
	body_shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 10)
	body_shape.shape = rect
	body_shape.position = Vector2(0, -5)
	body.add_child(body_shape)
	add_child(body)

	if DisplayServer.get_name() != "headless":
		var glow := PointLight2D.new()
		glow.name = "Glow"
		glow.texture = load("res://Scene/Map/dungeon_atmosphere.gd").get_radial_light_texture()
		glow.color = GLOW_COLOR
		glow.energy = GLOW_ENERGY
		glow.texture_scale = 1.1
		glow.position = Vector2(0, -22)
		add_child(glow)

func _ready() -> void:
	super._ready()
	play("idle")

func _create_shop(who: Node2D) -> CanvasLayer:
	return MERCHANT_SHOP_SCRIPT.open_merchant(who, offer, get_tree().current_scene)
