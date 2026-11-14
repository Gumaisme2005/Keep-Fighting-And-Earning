extends Node2D
## Đồng xu rơi ra khi hạ kẻ địch.
## Bật ra khỏi xác, nảy trên mặt đất, rồi tự bay về phía người chơi và cộng vào ví (GameManager.coins).
## Không va chạm tường: xu bay xuyên địa hình để không bao giờ bị kẹt.

const COIN_TEXTURE_PATH: String = "res://Assets/Items/Coin/coin_small.png"
const COIN_ICON_PATH: String = "res://Assets/Items/Coin/coin.png"
static var _texture_cache: Dictionary = {}

const POP_GRAVITY: float = 420.0      # trọng lực của cú nảy (px/s²)
const HOME_ACCEL: float = 900.0       # gia tốc khi bay về người chơi (px/s²)
const HOME_START_SPEED: float = 40.0
const HOME_MAX_SPEED: float = 560.0
const COLLECT_RADIUS: float = 8.0
const MAX_HOME_TIME: float = 4.0      # an toàn: quá thời gian này thì tự nhặt
const TARGET_OFFSET: Vector2 = Vector2(0, -8)  # bay vào ngực nhân vật thay vì chân

var value: int = 1
var run_id: int = -1

var _vel: Vector2 = Vector2.ZERO       # vận tốc trên mặt phẳng sàn
var _height: float = 0.0               # độ cao giả (nảy lên)
var _vz: float = 0.0
var _delay: float = 0.15               # chờ một chút sau khi rơi xuống rồi mới bay
var _landed: bool = false
var _homing: bool = false
var _home_speed: float = 0.0
var _home_time: float = 0.0
var _spin: float = 0.0
var _collected: bool = false
var _target: Node2D = null
var _sprite: Sprite2D = null

func setup(amount: int, rng: RandomNumberGenerator, run: int) -> void:
	value = maxi(1, amount)
	run_id = run
	var ang: float = rng.randf() * TAU
	_vel = Vector2(cos(ang), sin(ang)) * rng.randf_range(35.0, 85.0)
	_vz = rng.randf_range(70.0, 110.0)
	_delay = rng.randf_range(0.08, 0.28)
	_spin = rng.randf() * TAU

func _ready() -> void:
	add_to_group("coin_pickups")
	z_index = 3
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = load_pixel_texture(COIN_TEXTURE_PATH)
	add_child(_sprite)
	_update_sprite()

## Nạp texture pixel; nếu PNG mới chưa được editor import thì đọc thẳng file ảnh để game không lỗi.
static func load_pixel_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_texture_cache[path] = tex
	return tex

func is_collected() -> bool:
	return _collected

func is_homing() -> bool:
	return _homing

func _physics_process(delta: float) -> void:
	if _collected:
		return
	_spin += delta * 9.0

	if not _homing:
		if not _landed:
			_vz -= POP_GRAVITY * delta
			_height += _vz * delta
			position += _vel * delta
			if _height <= 0.0:
				_height = 0.0
				if _vz < -45.0:
					_vz = -_vz * 0.35   # nảy nhẹ thêm một lần
					_vel *= 0.5
				else:
					_vz = 0.0
					_vel = Vector2.ZERO
					_landed = true
		else:
			_delay -= delta
			if _delay <= 0.0 and _acquire_target():
				_homing = true
				_home_speed = HOME_START_SPEED
	else:
		if not _acquire_target():
			_update_sprite()
			return
		_home_time += delta
		_home_speed = minf(HOME_MAX_SPEED, _home_speed + HOME_ACCEL * delta)
		var goal: Vector2 = _target.global_position + TARGET_OFFSET
		var to_goal: Vector2 = goal - global_position
		var dist: float = to_goal.length()
		if dist <= COLLECT_RADIUS + _home_speed * delta or _home_time >= MAX_HOME_TIME:
			collect()
			return
		_vel = _vel.lerp(to_goal / dist * _home_speed, clampf(10.0 * delta, 0.0, 1.0))
		global_position += _vel * delta
		_height = lerpf(_height, 4.0, clampf(6.0 * delta, 0.0, 1.0))

	_update_sprite()

func _acquire_target() -> bool:
	if _target == null or not is_instance_valid(_target) or not _target.is_inside_tree():
		_target = null
		for n in get_tree().get_nodes_in_group("player"):
			if n is CharacterBody2D:
				_target = n
				break
	if _target == null:
		return false
	# Người chơi đã ngã xuống: xu nằm yên trên sàn
	if _target.get("is_dead") == true:
		return false
	return true

func _update_sprite() -> void:
	if _sprite == null:
		return
	_sprite.position = Vector2(0, -6.0 - _height)
	_sprite.scale.x = maxf(0.2, absf(cos(_spin)))   # xoay tròn
	queue_redraw()

func _draw() -> void:
	# Bóng đổ dưới đồng xu, nhỏ dần khi xu bay cao
	var s: float = clampf(1.0 - _height / 40.0, 0.4, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 4.0 * s, Color(0, 0, 0, 0.32 * s))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func collect() -> void:
	if _collected:
		return
	_collected = true
	var gm = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("add_coins") and int(gm.get("run_id")) == run_id:
		gm.add_coins(value)
	queue_free()

func _exit_tree() -> void:
	# Bị xoá trước khi bay tới nơi (ví dụ chuyển tầng ngay lúc đó): vẫn cộng xu, miễn là cùng một run.
	if _collected:
		return
	_collected = true
	var gm = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("add_coins") and int(gm.get("run_id")) == run_id:
		gm.add_coins(value, false)
