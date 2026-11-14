extends Node2D
## Guild Hall - sảnh chờ (hub) dựng từ "Top-Down Pixel Art Guild Hall" của CraftPix.
## Bố cục lấy cảm hứng từ sảnh của Soul Knight: đồ đạc, các anh hùng đứng chờ (ẩn người đang được chơi).
##   Floor / Walls / WallsFront : TileMapLayer (vẽ lại được trong editor bằng guild_hall_tileset.tres)
##   FloorDecor                 : thảm, vòng phép (nằm dưới mọi thứ)
##   WallDecor                  : cờ, đầu rồng... treo trên tường
##   Props                      : node y-sort cho nhân vật (và đồ đạc nếu thêm sau; mỗi món tự có StaticBody2D)
##   WallsFront                 : tường hai bên + tường dưới, vẽ đè lên nhân vật
##   Field                      : bãi cỏ bên trái (Ground: cát + cỏ + 8 luống đất, Edge chặn mép bãi)
##                                nối với sảnh qua lối mở ở tường trái (hàng ô 10..12)
## Chạy thẳng scene này (F6) để đi dạo: nhân vật đang chọn sẽ xuất hiện ở PlayerSpawn.
## Đầu run (START ở menu chính) sảnh mở ở màn "Chọn nhân vật" (hall_select.gd) thay cho màn chọn nhân vật cũ.
## Trong game, phím T (action "teleport_hall", xử lý ở GameManager) đưa nhân vật đang chơi về đây.

## Tự sinh nhân vật đang chọn khi scene chạy độc lập (tắt nếu một scene khác tự đưa người chơi vào).
@export var spawn_hero: bool = true
## Vùng tường dưới để mở lối ra (gắn logic vào tín hiệu exit_reached nếu muốn đi tiếp xuống hầm ngục).
signal exit_reached(body: Node2D)

const FALLBACK_HERO: PackedScene = preload("res://Scene/Character/Player 1_Pyrois/player.tscn")
const PAUSE_MENU: PackedScene = preload("res://Menu/pause menu/pause_menu.tscn")
const GAME_OVER_MENU: PackedScene = preload("res://Menu/game over menu/game_over_menu.tscn")
const SELECT_SCRIPT := preload("res://Scene/Map/GuildHall/hall_select.gd")
const CAMERA_MARGIN := 8.0

var hero: Node2D = null

func _ready() -> void:
	var exit_area := get_node_or_null("ExitArea") as Area2D
	if exit_area != null:
		exit_area.body_entered.connect(_on_exit_body_entered)
	_ensure_menus()
	if spawn_hero and get_tree().get_nodes_in_group("player").is_empty():
		var gm = get_node_or_null("/root/GameManager")
		if gm != null and bool(gm.get("hall_selecting")):
			_start_selection()
		else:
			_spawn_hero()

## Màn "Chọn nhân vật" đầu run (GameManager.start_run_in_hall): chưa có ai điều khiển, camera nhìn toàn sảnh,
## bấm vào một anh hùng để mở bảng thông tin (Scene/UI/HeroSelectUI), BẮT ĐẦU -> start_with_hero().
func _start_selection() -> void:
	update_hall_heroes(-1)   # cả 8 anh hùng đều đứng trong sảnh
	var sel := Node2D.new()
	sel.name = "HeroSelect"
	sel.set_script(SELECT_SCRIPT)
	add_child(sel)

## Kết thúc màn chọn: anh hùng `index` bước ra đúng chỗ bản đứng trong sảnh của họ và người chơi điều khiển luôn.
func start_with_hero(index: int) -> Node2D:
	var gm = get_node_or_null("/root/GameManager")
	if gm != null:
		gm.set_character_by_index(index)
		gm.set("hall_selecting", false)
	var statue := hall_hero_node(index)
	var sel := get_node_or_null("HeroSelect")
	if sel != null:
		sel.name = "HeroSelectDone"
		sel.queue_free()
	_spawn_hero()
	if hero != null and statue != null:
		hero.global_position = statue.global_position
	var cam: Camera2D = null
	if hero != null:
		for c in hero.find_children("*", "Camera2D", true, false):
			cam = c
			break
	if cam != null:
		cam.make_current()
		cam.reset_smoothing()
	return hero

## Bản đứng trong sảnh của anh hùng `index` (AnimatedSprite2D có meta "hero_index").
func hall_hero_node(index: int) -> Node2D:
	for n in $Props.get_children():
		if n.has_meta("hero_index") and int(n.get_meta("hero_index")) == index and String(n.name).begins_with("Hero"):
			return n
	return null

## ESC (tạm dừng) và màn Game Over giống trong hầm ngục.
func _ensure_menus() -> void:
	if get_node_or_null("CanvasLayer") != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "CanvasLayer"
	add_child(layer)
	var pm := PAUSE_MENU.instantiate()
	pm.name = "pause_menu"
	layer.add_child(pm)
	var go := GAME_OVER_MENU.instantiate()
	go.name = "game_over_menu"
	layer.add_child(go)

## Đặt một nhân vật có sẵn (vd. dịch chuyển bằng phím T) vào sảnh, tại PlayerSpawn.
func place_hero(node: Node2D) -> void:
	hero = node
	if node.get_parent() != $Props:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		$Props.add_child(node)
	node.z_index = 0
	# Đèn "PlayerSoulLight" của hầm ngục làm sảnh (vốn đủ sáng) bị chói - bỏ đi khi vào sảnh.
	var soul_light := node.get_node_or_null("PlayerSoulLight")
	if soul_light != null:
		soul_light.queue_free()
	node.global_position = $PlayerSpawn.global_position
	if "velocity" in node:
		node.velocity = Vector2.ZERO
	_fit_camera(node)
	update_hall_heroes()
	# HUD của nhân vật (GameUI) chuyển bản đồ nhỏ sang bản đồ sảnh
	if is_inside_tree():
		get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, "game_ui", "_connect_to_player_and_map")

## Dữ liệu cho bản đồ nhỏ của GameUI khi đang ở sảnh (toạ độ của sảnh): bãi cỏ, tường + sàn, lối thông ở tường trái,
## thảm, đồ đạc lớn, các điểm quan trọng (thanh kiếm rune, thợ rèn, pháp sư, giả kim) và các anh hùng đang đứng chờ.
func get_minimap_data() -> Dictionary:
	var room := Rect2(Vector2.ZERO, Vector2(get_meta("room_size", Vector2(576, 352))))
	var d := {
		"room": room,
		"floor": get_floor_rect(),
		"field": get_meta("field_clearing", PackedVector2Array()),
		"bounds": get_room_rect(),
		"door": Rect2(0, 160, 34, 48),
		"rugs": [],
		"blocks": [],
		"markers": [],
		"heroes": [],
	}
	var rug := get_node_or_null("FloorDecor/LoungeRug") as Sprite2D
	if rug != null and rug.texture != null:
		d.rugs.append(Rect2(rug.position + rug.offset, rug.texture.get_size()))
	for spec in [["RuneSword", "portal"], ["Blacksmith", "smith"], ["Mages", "mage"], ["Brewers", "potion"]]:
		var n := get_node_or_null("Props/" + String(spec[0])) as Node2D
		if n != null:
			d.markers.append({"kind": spec[1], "pos": n.position})
	for n in $Props.get_children():
		if n is Sprite2D and n.get_node_or_null("Body") != null and (n as Sprite2D).texture != null:
			var sp := n as Sprite2D
			var r := Rect2(sp.position + sp.offset * sp.scale, sp.texture.get_size() * sp.scale)
			if r.position.x >= 0.0:
				if r.size.x * r.size.y > 400.0:   # đồ lớn trong sảnh: kệ, rương, bàn, sofa, bia...
					d.blocks.append(r)
			else:
				# lều / xe thuốc ngoài bãi cỏ: chỉ phần chặn đường (mái lều che rộng hơn nhiều)
				for c in sp.get_node("Body").get_children():
					if c is CollisionShape2D and (c as CollisionShape2D).shape is RectangleShape2D:
						var size: Vector2 = ((c as CollisionShape2D).shape as RectangleShape2D).size * sp.scale
						var centre: Vector2 = to_local((c as CollisionShape2D).global_position)
						d.blocks.append(Rect2(centre - size / 2.0, size))
		elif n.has_meta("hero_index") and String(n.name).begins_with("Hero") and n.visible:
			d.heroes.append((n as Node2D).position)
	return d

## Các anh hùng đứng trong sảnh (nhóm "hall_hero", meta "hero_index" = chỉ số trong GameManager.CHARACTER_SCENES):
## ẩn bản của nhân vật đang chơi (cả va chạm) để không có hai người giống nhau; những người khác vẫn đứng đó.
func update_hall_heroes(playing: int = -2) -> void:
	if playing == -2:
		playing = -1
		var gm = get_node_or_null("/root/GameManager")
		if gm != null:
			playing = int(gm.get("selected_character_index"))
	for n in $Props.get_children():
		if not n.has_meta("hero_index"):
			continue
		var mine := int(n.get_meta("hero_index")) == playing
		n.visible = not mine
		var body := n.get_node_or_null("Body")
		if body != null:
			for c in body.get_children():
				if c is CollisionShape2D:
					c.set_deferred("disabled", mine)

func _on_exit_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		exit_reached.emit(body)

func _spawn_hero() -> void:
	var scene: PackedScene = FALLBACK_HERO
	var gm = get_node_or_null("/root/GameManager")
	if gm != null and gm.get("selected_character_scene") != null:
		scene = gm.selected_character_scene
	var node: Node2D = scene.instantiate()
	node.name = "Player"
	place_hero(node)

## Giới hạn camera trong phạm vi sảnh (chừa thêm một chút viền tối).
func _fit_camera(node: Node) -> void:
	var cam := node.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		for c in node.find_children("*", "Camera2D", true, false):
			cam = c
			break
	if cam == null:
		return
	var r := get_room_rect()
	cam.limit_left = int(r.position.x - CAMERA_MARGIN)
	cam.limit_top = int(r.position.y - CAMERA_MARGIN)
	cam.limit_right = int(r.end.x + CAMERA_MARGIN)
	cam.limit_bottom = int(r.end.y + CAMERA_MARGIN)

## Toàn bộ sảnh (kể cả tường) và bãi cỏ bên trái, theo toạ độ local.
func get_room_rect() -> Rect2:
	var r := Rect2(Vector2.ZERO, Vector2(get_meta("room_size", Vector2(576, 352))))
	if has_meta("field_rect"):
		r = r.merge(get_meta("field_rect"))
	return r

## Bãi cỏ (Field) bên trái sảnh, nối với sảnh qua lối mở ở tường trái.
func get_field_rect() -> Rect2:
	return get_meta("field_rect", Rect2())

## Điểm p (toạ độ local của sảnh) có nằm trong vùng đi lại được của bãi cỏ không.
func is_in_field_clearing(p: Vector2) -> bool:
	var clearing: PackedVector2Array = get_meta("field_clearing", PackedVector2Array())
	return clearing.size() >= 3 and Geometry2D.is_point_in_polygon(p, clearing)

## Phần sàn đi lại được.
func get_floor_rect() -> Rect2:
	return get_meta("floor_rect", Rect2(32, 64, 512, 256))
