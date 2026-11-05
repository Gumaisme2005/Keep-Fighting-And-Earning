extends RefCounted
## Lương Thơ sprite data (sheet_full.json / bullets.json from the sprite pack).
## Character frames are 64x64 on lt_sheet.png (10 columns x 19 rows); she faces RIGHT and
## stands on the pivot (24, 55) - left of centre, leaving room for the strikes on the right.
## Rows 0-8 are the black-haired base form, row 9 the transformation, rows 10-18 the
## white-haired upgraded form. Bullets are 32x32 on lt_bullets.png, pivot = ball centre (21, 16).

const DIR := "res://Assets/Character/LuongTho/"
const SCALE := 0.75                 # 39px tall frame content -> ~29px in game, like the other heroes
const PIVOT := Vector2(24, 55)
const FRAME := 64
const BULLET_PIVOT := Vector2(21, 16)
const BULLET_FRAME := 32

## Character animations: name -> [row in the base form, frames, fps, loop]. The upgraded form
## uses row + 10. "ready" is the last frame of "draw" (standing in combat stance).
const ANIMS: Dictionary = {
	"idle": [0, 6, 6.0, true],
	"run": [1, 8, 12.0, true],
	"draw": [2, 5, 12.0, false],
	"stab": [3, 8, 12.0, false],
	"swing": [4, 8, 12.0, false],
	"smash": [5, 8, 12.0, false],
	"shoot": [6, 8, 12.0, false],
	"hurt": [7, 4, 10.0, false],
	"death": [8, 8, 8.0, false],
}
const TRANSFORM := [9, 10, 10.0]    # row, frames, fps (shared by both forms)
const UPGRADED_ROW_OFFSET := 10

## Bullets: name -> [row, frames, fps, loop] for each form.
const BULLETS: Dictionary = {
	"base_fly": [0, 4, 12.0, true], "base_hit": [1, 5, 15.0, false],
	"upgraded_fly": [2, 4, 12.0, true], "upgraded_hit": [3, 5, 15.0, false],
}

# Animation events (sheet_full.json "meta.events").
const STAB_HIT_FRAME := 4
const SWING_HIT_FRAMES := [2, 4]
const SMASH_HIT_FRAME := 4
const SHOOT_FIRE_FRAME := 3
const BULLET_SPAWNS := [Vector2(55, 38), Vector2(61, 33)]   # frame px, facing right

static var _tex_cache: Dictionary = {}
static var _frames_cache: Dictionary = {}

## Runtime texture loading (never preload): scripts keep parsing on the very first project
## open before Godot has imported the PNGs; falls back to reading the PNG from disk.
static func texture(file: String) -> Texture2D:
	if _tex_cache.has(file):
		return _tex_cache[file]
	var path := DIR + file
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		_tex_cache[file] = tex
	return tex

static func _cell(tex: Texture2D, size: int, row: int, col: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(col * size, row * size, size, size)
	return atlas

## SpriteFrames for one form ("base" or "upgraded"), with plain animation names
## (idle, run, draw, ready, stab, swing, smash, shoot, hurt, death, transform).
static func character_frames(form: String) -> SpriteFrames:
	if _frames_cache.has(form):
		return _frames_cache[form]
	var tex := texture("lt_sheet.png")
	var offset := UPGRADED_ROW_OFFSET if form == "upgraded" else 0
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for anim in ANIMS:
		var info: Array = ANIMS[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, float(info[2]))
		frames.set_animation_loop(anim, bool(info[3]))
		for i in range(int(info[1])):
			frames.add_frame(anim, _cell(tex, FRAME, int(info[0]) + offset, i))
	frames.add_animation("ready")
	frames.set_animation_loop("ready", false)
	frames.add_frame("ready", _cell(tex, FRAME, int(ANIMS["draw"][0]) + offset, int(ANIMS["draw"][1]) - 1))
	frames.add_animation("transform")
	frames.set_animation_speed("transform", float(TRANSFORM[2]))
	frames.set_animation_loop("transform", false)
	for i in range(int(TRANSFORM[1])):
		frames.add_frame("transform", _cell(tex, FRAME, int(TRANSFORM[0]), i))
	_frames_cache[form] = frames
	return frames

static func bullet_frames() -> SpriteFrames:
	if _frames_cache.has("bullets"):
		return _frames_cache["bullets"]
	var tex := texture("lt_bullets.png")
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for anim in BULLETS:
		var info: Array = BULLETS[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, float(info[2]))
		frames.set_animation_loop(anim, bool(info[3]))
		for i in range(int(info[1])):
			frames.add_frame(anim, _cell(tex, BULLET_FRAME, int(info[0]), i))
	_frames_cache["bullets"] = frames
	return frames

## Seconds from the start of `anim` until frame `index` (at speed_scale 1).
static func at_frame(anim: String, index: int) -> float:
	var fps: float = float(TRANSFORM[2]) if anim == "transform" else float(ANIMS[anim][2])
	return float(index) / fps

static func duration(anim: String) -> float:
	if anim == "transform":
		return float(TRANSFORM[1]) / float(TRANSFORM[2])
	return float(ANIMS[anim][1]) / float(ANIMS[anim][2])

static func bullet_duration(anim: String) -> float:
	return float(BULLETS[anim][1]) / float(BULLETS[anim][2])

## Offset that puts the pivot on the node origin (sprite drawn with centered = false).
static func offset(flipped: bool, frame_size: int = FRAME, pivot: Vector2 = PIVOT) -> Vector2:
	return Vector2(-(frame_size - pivot.x) if flipped else -pivot.x, -pivot.y)

## A point given in frame pixels (facing right) -> offset from the pivot in game units.
static func from_pivot(frame_point: Vector2, facing: float) -> Vector2:
	var d := (frame_point - PIVOT) * SCALE
	return Vector2(d.x * facing, d.y)
