extends RefCounted
## Hoshimi Miyabi sprite data (from cat_girl_animations.json): every sheet is one row of
## equal frames. Character frames are 40x40 with the feet on the bottom row; the frost
## effects and the spirit use their own frame sizes. Offsets in the JSON are measured from
## the centre of the 40x40 character frame and are mirrored when she faces left.

const DIR := "res://Assets/Character/Miyabi/"
## In-game scale of every Miyabi sprite (her 40px frame -> ~28px tall hero, like the others).
const SCALE := 0.85

## name: [file, frame_w, frame_h, frames, fps, loop]
const ANIMS: Dictionary = {
	# --- Miyabi
	"idle": ["cat_girl_idle.png", 40, 40, 8, 8.0, true],
	"walk": ["cat_girl_walk.png", 40, 40, 8, 10.0, true],
	"hurt": ["cat_girl_hurt.png", 40, 40, 4, 12.0, false],
	"death": ["cat_girl_death.png", 40, 40, 13, 10.0, false],
	"frost_combo_1": ["cat_girl_frost_combo_1.png", 40, 40, 5, 16.0, false],
	"frost_combo_2": ["cat_girl_frost_combo_2.png", 40, 40, 5, 16.0, false],
	"frost_combo_3": ["cat_girl_frost_combo_3.png", 40, 40, 8, 14.0, false],
	"frost_dash": ["cat_girl_frost_dash.png", 40, 40, 7, 16.0, false],
	"frost_charge_start": ["cat_girl_frost_charge_start.png", 40, 40, 3, 12.0, false],
	"frost_charge": ["cat_girl_frost_charge.png", 40, 40, 6, 10.0, true],
	"frost_release": ["cat_girl_frost_release.png", 40, 40, 8, 14.0, false],
	"frost_special": ["cat_girl_frost_special.png", 40, 40, 13, 12.0, false],
	# --- Frost effects
	"frost_wave": ["frost_wave.png", 24, 32, 4, 12.0, true],
	"frost_wave_end": ["frost_wave_end.png", 24, 32, 5, 12.0, false],
	"ice_spikes": ["frost_ice_spikes.png", 96, 40, 13, 14.0, false],
	"frost_hit": ["frost_hit.png", 16, 16, 7, 16.0, false],
	# --- Spirit companion and its bolt
	"spirit_idle": ["spirit_idle.png", 16, 20, 8, 8.0, true],
	"spirit_attack": ["spirit_attack.png", 16, 20, 8, 12.0, false],
	"spirit_hurt": ["spirit_hurt.png", 16, 20, 4, 12.0, false],
	"spirit_vanish": ["spirit_vanish.png", 16, 20, 8, 10.0, false],
	"bolt": ["spirit_bolt.png", 14, 9, 4, 12.0, true],
	"bolt_hit": ["spirit_bolt_hit.png", 14, 9, 5, 15.0, false],
}

const CHARACTER_ANIMS: Array = ["idle", "walk", "hurt", "death", "frost_combo_1", "frost_combo_2", "frost_combo_3",
	"frost_dash", "frost_charge_start", "frost_charge", "frost_release", "frost_special"]
const SPIRIT_ANIMS: Array = ["spirit_idle", "spirit_attack", "spirit_hurt", "spirit_vanish"]

# Offsets from the character-frame centre (cat_girl_animations.json), facing right.
const WAVE_OFFSET := Vector2(10, 3)
const SPIKES_OFFSET := Vector2(56, 0)
const SPIRIT_OFFSET := Vector2(10, -4)
const BOLT_OFFSET := Vector2(11, -1)

static var _tex_cache: Dictionary = {}
static var _frames_cache: Dictionary = {}

## Loads a texture at runtime (never preload), so the scripts still parse on the very first
## project open before Godot has imported the PNGs; falls back to reading the PNG directly.
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

static func build(names: Array) -> SpriteFrames:
	var key := ",".join(names)
	if _frames_cache.has(key):
		return _frames_cache[key]
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for anim in names:
		var info: Array = ANIMS[anim]
		var tex := texture(String(info[0]))
		frames.add_animation(anim)
		frames.set_animation_speed(anim, float(info[4]))
		frames.set_animation_loop(anim, bool(info[5]))
		for i in range(int(info[3])):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * int(info[1]), 0, int(info[1]), int(info[2]))
			frames.add_frame(anim, atlas)
	_frames_cache[key] = frames
	return frames

## Seconds from the start of `anim` until frame `index` is shown.
static func at_frame(anim: String, index: int) -> float:
	return float(index) / float(ANIMS[anim][4])

static func duration(anim: String) -> float:
	return float(ANIMS[anim][3]) / float(ANIMS[anim][4])
