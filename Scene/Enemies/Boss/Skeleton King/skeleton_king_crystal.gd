extends StaticBody2D
## Soul Crystal — the Skeleton King's only weak point.
## Exposes a "Hurtbox" Area2D + take_damage() like every other enemy, so all
## heroes' attacks (melee, arrows, bombs, Yugi summons) can shatter it.
## Each shattered crystal deals a chunk of damage to the King.
## Crystals are rooted: nothing can push, pull or freeze them. If the heroes
## leave one alone until its lifetime runs out it fades back into the King and
## heals him for part of his HP.

const CRYSTAL_TEX: Texture2D = preload("res://Assets/Character/Skeleton King/skeleton_king_crystal.png")
const RISE_TIME := 0.35
const SHATTER_TIME := 0.55
const SPRITE_SCALE := 0.6
const EXPIRE_TIME := 0.6
const WARN_BEFORE_EXPIRE := 3.0

var king: Node2D
var max_hp: int = 6
var hp: int = 6
var is_dead: bool = false
var is_active: bool = true
var is_immovable: bool = true  # skipped by pulls / stuns (see Yugi room_pull, lightning_hit)
var lifetime: float = 9.0
var expired: bool = false
var expire_age: float = -1.0
var anchor: Vector2 = Vector2.INF
var sprite: Sprite2D
var hurtbox: Area2D
var body_shape: CollisionShape2D
var hurt_shape: CollisionShape2D
var age: float = 0.0
var flash_left: float = 0.0
var shatter_age: float = -1.0
var shards: Array[Dictionary] = []

func _ready() -> void:
	hp = max_hp
	z_index = 2
	add_to_group("skeleton_king_crystals")
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded

	body_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	body_shape.shape = circle
	body_shape.position = Vector2(0, -4)
	add_child(body_shape)

	hurtbox = Area2D.new()
	hurtbox.name = "Hurtbox"
	hurt_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18, 28)
	hurt_shape.shape = rect
	hurt_shape.position = Vector2(0, -14)
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)

	sprite = Sprite2D.new()
	sprite.texture = CRYSTAL_TEX
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.offset = Vector2(0, -CRYSTAL_TEX.get_height() * 0.5)
	sprite.scale = Vector2(SPRITE_SCALE, 0.05)
	sprite.use_parent_material = true
	add_child(sprite)

	if DisplayServer.get_name() != "headless":
		var light := PointLight2D.new()
		light.texture = preload("res://Scene/Map/dungeon_atmosphere.gd").get_radial_light_texture()
		light.color = Color(0.78, 0.35, 1.0)
		light.energy = 0.9
		light.texture_scale = 0.9
		light.position = Vector2(0, -14)
		add_child(light)

func _process(_delta: float) -> void:
	# Safety net: whatever tries to move or freeze the crystal, it stays rooted and ticking.
	if anchor != Vector2.INF and position != anchor:
		position = anchor
	if not is_physics_processing() and not is_queued_for_deletion():
		set_physics_process(true)

func _physics_process(delta: float) -> void:
	if anchor == Vector2.INF:
		anchor = position
	position = anchor
	age += delta
	flash_left = maxf(0.0, flash_left - delta)
	if expire_age >= 0.0:
		expire_age += delta
		var k := clampf(expire_age / EXPIRE_TIME, 0.0, 1.0)
		sprite.scale = Vector2(SPRITE_SCALE * (1.0 - k), SPRITE_SCALE * (1.0 + 0.6 * k))
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0 - k)
		queue_redraw()
		if expire_age >= EXPIRE_TIME:
			queue_free()
		return
	if shatter_age >= 0.0:
		shatter_age += delta
		for shard in shards:
			shard["pos"] += shard["vel"] * delta
			shard["vel"] += Vector2(0, 260) * delta
		queue_redraw()
		if shatter_age >= SHATTER_TIME:
			queue_free()
		return
	var rise := clampf(age / RISE_TIME, 0.0, 1.0)
	var bob := sin(age * 3.2) * 1.5
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE * rise)
	sprite.position = Vector2(0, bob - 2.0)
	var time_left := lifetime - age
	var blink := 1.0
	if time_left < WARN_BEFORE_EXPIRE:
		# Blink faster and faster as the crystal is about to return to the King.
		var speed := lerpf(6.0, 22.0, 1.0 - time_left / WARN_BEFORE_EXPIRE)
		blink = 0.55 + 0.45 * absf(sin(age * speed))
	sprite.modulate = Color(2.2, 2.2, 2.2) if flash_left > 0.0 else Color(1.0, 1.0, 1.0, blink)
	queue_redraw()
	if time_left <= 0.0:
		_expire()

func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	hp = maxi(0, hp - amount)
	flash_left = 0.12
	if get_tree():
		get_tree().call_group("game_ui", "spawn_damage_number", global_position + Vector2(0, -30), amount, Color(0.85, 0.5, 1.0))
	if get_node_or_null("/root/AudioManager") != null:
		AudioManager.play_sfx("hit")
	if hp <= 0:
		_shatter()

func get_time_left() -> float:
	return maxf(0.0, lifetime - age)

func _expire() -> void:
	if is_dead:
		return
	is_dead = true
	expired = true
	expire_age = 0.0
	hurt_shape.set_deferred("disabled", true)
	body_shape.set_deferred("disabled", true)
	if is_instance_valid(king) and king.has_method("on_crystal_expired"):
		king.on_crystal_expired(self)

func _shatter() -> void:
	is_dead = true
	shatter_age = 0.0
	sprite.hide()
	hurt_shape.set_deferred("disabled", true)
	body_shape.set_deferred("disabled", true)
	# Shard directions derived from position so shattering stays deterministic.
	for i in range(10):
		var ang := TAU * float(i) / 10.0 + float(int(global_position.x) % 7) * 0.1
		var spd := 70.0 + float((i * 37 + int(global_position.y)) % 50)
		shards.append({"pos": Vector2(0, -16), "vel": Vector2(cos(ang), sin(ang) - 0.6) * spd, "size": 2.0 + float(i % 3)})
	if is_instance_valid(king) and king.has_method("on_crystal_shattered"):
		king.on_crystal_shattered(self)

func _draw() -> void:
	if expire_age >= 0.0:
		# Soul energy drains back into the King.
		var k := clampf(expire_age / EXPIRE_TIME, 0.0, 1.0)
		if is_instance_valid(king) and king.has_method("get_chest_global"):
			var chest: Vector2 = to_local(king.get_chest_global())
			draw_line(Vector2(0, -16), chest, Color(0.55, 1.0, 0.6, 0.8 * (1.0 - k)), 3.0 * (1.0 - k) + 1.0)
			draw_circle(Vector2(0, -16).lerp(chest, k), 5.0, Color(0.6, 1.0, 0.65, 1.0 - k * 0.5))
		return
	if shatter_age >= 0.0:
		var fade := 1.0 - shatter_age / SHATTER_TIME
		draw_circle(Vector2(0, -16), 18.0 * (1.0 - fade) + 4.0, Color(0.9, 0.6, 1.0, 0.45 * fade))
		for shard in shards:
			var p: Vector2 = shard["pos"]
			var s := float(shard["size"])
			draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), Color(0.85, 0.45, 1.0, fade))
		return
	# Floor shadow + rising ring when it emerges.
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 9.0, Color(0.05, 0.0, 0.1, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if age < RISE_TIME * 2.0:
		var k := age / (RISE_TIME * 2.0)
		draw_arc(Vector2(0, -2), 6.0 + 18.0 * k, 0.0, TAU, 24, Color(0.9, 0.55, 1.0, 1.0 - k), 2.0)
	# Soul tether: shows which crystal feeds the King.
	if is_instance_valid(king) and king.has_method("get_chest_global"):
		var chest: Vector2 = to_local(king.get_chest_global())
		var pulse := 0.5 + 0.5 * sin(age * 4.0 + global_position.x * 0.05)
		draw_line(Vector2(0, -24), chest, Color(0.78, 0.35, 1.0, 0.10 + 0.12 * pulse), 1.5)
	# Lifetime ring: shrinks clockwise until the crystal returns to the King.
	var frac := get_time_left() / maxf(0.01, lifetime)
	var ring_col := Color(0.85, 0.5, 1.0, 0.8) if frac > WARN_BEFORE_EXPIRE / maxf(0.01, lifetime) else Color(1.0, 0.35, 0.45, 0.85)
	draw_arc(Vector2(0, 1), 11.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 28, ring_col, 2.0)
	# HP pips once damaged.
	if hp < max_hp:
		var w := 18.0
		draw_rect(Rect2(-w * 0.5, -36.0, w, 3.0), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w * 0.5, -36.0, w * float(hp) / float(max_hp), 3.0), Color(0.9, 0.5, 1.0))
