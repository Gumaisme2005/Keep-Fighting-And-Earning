extends RefCounted
## Extract separated columns within explicit row regions; original PNGs stay intact.
static var cache: Dictionary = {}

static func material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://scenes/characters/yugi/key_green.gdshader")
	return result

static func frames(file: String, left: int, top: int = 0, bottom: int = -1) -> Array[Texture2D]:
	var key := "%s:%d:%d:%d" % [file, left, top, bottom]
	if cache.has(key): return cache[key]
	var texture := load("res://Assets/Character/Yugi/" + file + ".png") as Texture2D
	var img := texture.get_image()
	var end_y := img.get_height() if bottom < 0 else mini(bottom, img.get_height())
	var result: Array[Texture2D] = []
	var start := -1
	for x in range(left, img.get_width() + 1):
		var occupied := false
		if x < img.get_width():
			for y in range(top, end_y):
				var c := img.get_pixel(x, y)
				if c.a > 0.1 and (c.r > 0.04 or absf(c.g - 0.392157) > 0.04 or c.b > 0.04):
					occupied = true
					break
		if occupied and start < 0: start = x
		if not occupied and start >= 0:
			if x - start >= 12:
				var min_y := end_y
				var max_y := top
				for px in range(start, x):
					for py in range(top, end_y):
						var c := img.get_pixel(px, py)
						if c.a > 0.1 and (c.r > 0.04 or absf(c.g - 0.392157) > 0.04 or c.b > 0.04):
							min_y = mini(min_y, py)
							max_y = maxi(max_y, py)
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(start, min_y, x - start, max_y - min_y + 1)
				# Pad to a stable bottom-center origin without resampling pixels.
				atlas.margin = Rect2((180 - (x - start)) / 2.0, 160 - atlas.region.size.y, 180 - atlas.region.size.x, 160 - atlas.region.size.y)
				result.append(atlas)
			start = -1
	cache[key] = result
	return result

static func animation(file: String, left: int, top: int = 0, bottom: int = -1) -> SpriteFrames:
	if file == "hold&release-right-click" and left == 385:
		return explosion_animation()
	var result := SpriteFrames.new()
	result.set_animation_speed("default", 10.0)
	for tex in frames(file, left, top, bottom): result.add_frame("default", tex)
	return result

static func explosion_animation() -> SpriteFrames:
	# Detached particles belong to the same pose, not separate animation frames.
	var texture := preload("res://Assets/Character/Yugi/hold&release-right-click.png")
	var result := SpriteFrames.new()
	result.set_animation_speed("default", 5.0)
	result.set_animation_loop("default", false)
	# [left, right exclusive, character anchor] in the original sheet.
	var regions := [[385, 420, 400], [433, 473, 450], [488, 555, 505],
		[570, 645, 589], [658, 760, 672], [771, 875, 786],
		[889, 985, 902], [1004, 1104, 1020], [1117, 1164, 1134]]
	for i in range(regions.size()):
		var region: Array = regions[i]
		var width: int = region[1] - region[0]
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(region[0], 0, width, texture.get_height())
		atlas.margin = Rect2(90 - (region[2] - region[0]), 160 - texture.get_height(), 180 - width, 160 - texture.get_height())
		atlas.filter_clip = true
		# Preserve the requested 2.2 seconds by holding the final recovery pose.
		result.add_frame("default", atlas, 3.0 if i == regions.size() - 1 else 1.0)
	return result
