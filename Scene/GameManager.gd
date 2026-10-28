extends Node

signal seed_changed(new_seed: String)
signal stats_updated(level: int, kills: int)
signal saved_data_changed()

const SAVE_FILE_PATH: String = "user://roguelike_save_data.json"

# --- HẰNG SỐ BẢO MẬT & GIỚI HẠN DỮ LIỆU (SECURITY BOUNDS) ---
const MAX_SEED_LENGTH: int = 32
const MAX_NOTE_LENGTH: int = 80
const MAX_SAVED_SEEDS: int = 20
const MAX_RUN_HISTORY: int = 15
const MAX_REPLAY_FRAMES: int = 18000
const MAX_DISK_REPLAY_FRAMES: int = 3600
const MAX_SAVE_FILE_BYTES: int = 2097152 # 2 MB chống DoS / Memory Exhaustion
const ALLOWED_SEED_CHARS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

const CHARACTER_SCENES: Array[PackedScene] = [
	preload("res://Scene/Character/Player 3_Miya/player_3.tscn"),
	preload("res://Scene/Character/Player 2_Olaf/player_2.tscn"),
	preload("res://Scene/Character/Player 1_Pyrois/player.tscn"),
	preload("res://Scene/Character/Player 4_Charlotte/player_4.tscn"),
]

const WORLD_LORE: Dictionary = {
	"title": "BIÊN NIÊN SỬ ĐÁ LINH HỒN (THE SOUL STONE CHRONICLES)",
	"subtitle": "Thợ Săn Tiền Thưởng & Mê Cung Thời-Không Tái Lập",
	"story": """Tại lục địa cổ đại Aethelgard, viên Đá Linh Hồn (Soul Core) — bảo vật giữ cân bằng không-thời gian — đã bị đánh cắp bởi Hắc Pháp Sư Malakor (Necromancer) và Thủ Lĩnh Chiến Lang (Orc Rider). Chúng đập vỡ viên đá và giấu các mảnh vỡ xuống đáy Mê Cung Vô Định (The Shifting Dungeon), nơi cấu trúc địa hình tự biến đổi không ngừng.

Hội Thợ Săn Tiền Thưởng 'Keep Fighting & Earning' đã chế tạo thành công La Bàn Nhân Quả (Seed Compass). Mỗi mã Seed là một tọa độ Thời-Không bất biến: cùng một Seed sẽ cố định 100% cấu trúc đồ thị phòng (Graph/Grid), hành lang chữ L, vị trí bẫy gai, rương báu, đội hình quái vật và vật phẩm rơi ra. Kèm theo đó, Thạch Lưu Ảnh (Replay Crystal) ghi lại từng khung hình chiến đấu ở tần số 60Hz, giúp tái hiện hoàn hảo mọi hành trình dưới đáy vực."""
}

const CHARACTER_INFO: Array[Dictionary] = [
	{
		"name": "Miya",
		"role": "Cung Thủ Thiện Xạ",
		"weapon": "Cung Tinh Linh & Bộc Phá",
		"skill_icon": "skill_aim",
		"hp": 4,
		"armor": 1,
		"speed": 180,
		"damage": 2,
		"lore": "Thợ săn rừng sâu tốc độ cao của Hội Tiền Thưởng. Giữ khoảng cách an toàn và tiêu diệt mục tiêu từ xa bằng tên xuyên phá cùng bom giả kim.",
		"skill_q": "[Q] Bộc Phá Hỏa Mai: Ném bom tới vị trí trỏ chuột, phát nổ diện rộng gây x3 sát thương (Hồi chiêu: 5s).",
		"skill_rmb": "[Chuột Trái] Tên Tinh Linh: Bắn tên tầm xa chính xác theo hướng trỏ chuột."
	},
	{
		"name": "Olaf",
		"role": "Chiến Binh Cuồng Nộ",
		"weapon": "Chiến Rìu Bắc Cực",
		"skill_icon": "flame",
		"hp": 6,
		"armor": 1,
		"speed": 160,
		"damage": 2,
		"lore": "Chiến binh phương Bắc săn tiền thưởng để khôi phục bộ tộc. Sở hữu lượng máu dồi dào nhất và khả năng bùng nổ sát thương cận chiến khủng khiếp.",
		"skill_q": "[Q] Huyết Nộ Bắc Cực: Kích hoạt trạng thái cuồng chiến, nhân đôi sát thương đòn đánh trong 5 giây (Hồi chiêu: 5s).",
		"skill_rmb": "[Chuột Trái] Bổ Rìu Hạng Nặng: Đòn bổ cận chiến uy lực quét sạch kẻ địch trước mặt."
	},
	{
		"name": "Pyrois",
		"role": "Hiệp Sĩ Khiên Thánh",
		"weapon": "Trường Kiếm & Khiên Thánh",
		"skill_icon": "skill_shield",
		"hp": 4,
		"armor": 4,
		"speed": 150,
		"damage": 1,
		"lore": "Cựu đội trưởng Cận Vệ Hoàng Gia dẫn đầu chiến dịch thu hồi Đá Linh Hồn. Công thủ toàn diện với lớp Khiên Thánh dày tự hồi phục sau giao tranh.",
		"skill_q": "[Q] Nhảy Chém Dũng Mãnh: Lao tới phía trước với trạng thái Bất Tử (I-Frames), bổ kiếm gây +2 sát thương (Hồi chiêu: 5s).",
		"skill_rmb": "[Chuột Trái] Kiếm Thuật Chuẩn Mực: Chém kiếm tốc độ cân bằng, an toàn và ổn định."
	},
	{
		"name": "Charlotte",
		"role": "Kiếm Khách Ảnh Vũ",
		"weapon": "Song Kiếm Lưu Ảnh",
		"skill_icon": "skill_stealth",
		"hp": 5,
		"armor": 0,
		"speed": 180,
		"damage": 2,
		"lore": "Nữ kiếm khách đánh thuê bí ẩn theo trường phái Nhất Kích Tất Sát. Đánh đổi toàn bộ giáp phòng ngự để lấy tốc độ di chuyển và bộ kỹ năng kép cơ động.",
		"skill_q": "[Q] Tam Đoạn Trảm: Tung liên hoàn 3 nhát kiếm chớp nhoáng tại chỗ (Hồi chiêu: 3s).",
		"skill_rmb": "[Chuột Phải] Ảnh Bộ Đột Kích: Lướt nhanh 400px bật I-Frames rồi đâm liên tiếp 4 nhịp (Hồi chiêu: 5s)."
	}
]

var selected_character_index: int = 2
var selected_character_scene: PackedScene = CHARACTER_SCENES[2]

var current_seed: String = "ALOALO1234"
var current_level: int = 1
var enemies_killed: int = 0
var run_start_time_msec: int = 0

# --- DỮ LIỆU LƯU SEED & LỊCH SỬ RUN ---
var saved_seeds: Array = []   # [{ "seed": String, "note": String, "hero_idx": int, "date": String }]
var run_history: Array = []   # [{ "seed": String, "hero_idx": int, "hero_name": String, "floor": int, "kills": int, "date": String, "frames": Array }]

# --- HỆ THỐNG REPLAY MỘT RUN (RECORD & PLAYBACK) ---
var is_replaying: bool = false
var replay_frames: Array = []
var current_recording_frames: Array = []
var last_recorded_run: Dictionary = {}

func _ready() -> void:
	load_save_data()
	if saved_seeds.is_empty():
		save_seed_entry("ALOALO1234", "Seed chuẩn kiểm thử (Test/Debug)", 2)
		save_seed_entry("SOUL_KNIGHT_2026", "Hầm ngục nhiều nhánh giao tranh", 0)
		save_seed_entry("BOSS_HUNT_777", "Lộ trình săn Boss tốc độ cao", 3)

# --- HÀM BẢO MẬT & LÀM SẠCH DỮ LIỆU ĐẦU VÀO (INPUT SANITIZATION) ---
static func sanitize_seed(raw_seed: String) -> String:
	var trimmed := raw_seed.strip_edges()
	var result := ""
	for i in range(trimmed.length()):
		var ch := trimmed[i]
		if ch == " ":
			ch = "_"
		if ALLOWED_SEED_CHARS.contains(ch):
			result += ch
			if result.length() >= MAX_SEED_LENGTH:
				break
	return result

static func sanitize_note(raw_note: String) -> String:
	var cleaned := ""
	var trimmed := raw_note.strip_edges()
	for i in range(mini(trimmed.length(), MAX_NOTE_LENGTH)):
		var code := trimmed.unicode_at(i)
		# Loại bỏ ký tự điều khiển (ASCII < 32) và các ký tự thẻ
		if code >= 32 and trimmed[i] != "<" and trimmed[i] != ">":
			cleaned += trimmed[i]
	return cleaned

static func _sanitize_replay_frames(raw_frames: Variant, max_count: int) -> Array:
	var safe_frames: Array = []
	if not (raw_frames is Array):
		return safe_frames
	var limit := mini((raw_frames as Array).size(), max_count)
	for i in range(limit):
		var item = raw_frames[i]
		if not (item is Dictionary):
			continue
		var dx := float(item.get("dx", 0.0)) if (item.get("dx") is float or item.get("dx") is int) else 0.0
		var dy := float(item.get("dy", 0.0)) if (item.get("dy") is float or item.get("dy") is int) else 0.0
		var ax := float(item.get("ax", 32.0)) if (item.get("ax") is float or item.get("ax") is int) else 32.0
		var ay := float(item.get("ay", 0.0)) if (item.get("ay") is float or item.get("ay") is int) else 0.0
		var slot_idx := int(item.get("slot", -1)) if (item.get("slot") is int or item.get("slot") is float) else -1
		if not is_finite(dx): dx = 0.0
		if not is_finite(dy): dy = 0.0
		if not is_finite(ax): ax = 32.0
		if not is_finite(ay): ay = 0.0
		safe_frames.append({
			"dx": clampf(dx, -1.0, 1.0),
			"dy": clampf(dy, -1.0, 1.0),
			"ax": clampf(ax, -100000.0, 100000.0),
			"ay": clampf(ay, -100000.0, 100000.0),
			"atk": bool(item.get("atk", false)) if item.get("atk") is bool else false,
			"q": bool(item.get("q", false)) if item.get("q") is bool else false,
			"rmb": bool(item.get("rmb", false)) if item.get("rmb") is bool else false,
			"slot": clampi(slot_idx, -1, 15)
		})
	return safe_frames

func set_character_by_index(index: int) -> void:
	selected_character_index = clampi(index, 0, CHARACTER_SCENES.size() - 1)
	selected_character_scene = CHARACTER_SCENES[selected_character_index]

func get_selected_character_info() -> Dictionary:
	return CHARACTER_INFO[clampi(selected_character_index, 0, CHARACTER_INFO.size() - 1)]

func set_seed(new_seed: String) -> void:
	var cleaned := sanitize_seed(new_seed)
	if cleaned.is_empty():
		cleaned = generate_random_seed()
	current_seed = cleaned
	seed_changed.emit(current_seed)

func generate_random_seed() -> String:
	var chars := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var result := "SEED-"
	for i in range(6):
		result += chars[rng.randi() % chars.length()]
	return result

func start_new_run(custom_seed: String = "", replay_mode: bool = false, frames_to_replay: Array = []) -> void:
	var safe_custom := sanitize_seed(custom_seed)
	if not safe_custom.is_empty():
		current_seed = safe_custom
	else:
		var safe_curr := sanitize_seed(current_seed)
		current_seed = safe_curr if not safe_curr.is_empty() else generate_random_seed()
	current_level = 1
	enemies_killed = 0
	run_start_time_msec = Time.get_ticks_msec()
	is_replaying = replay_mode
	if replay_mode:
		replay_frames = _sanitize_replay_frames(frames_to_replay, MAX_REPLAY_FRAMES)
		current_recording_frames.clear()
	else:
		replay_frames.clear()
		current_recording_frames.clear()
	stats_updated.emit(current_level, enemies_killed)

func record_frame_input(frame_data: Dictionary) -> void:
	if is_replaying:
		return
	if current_recording_frames.size() < MAX_REPLAY_FRAMES:
		current_recording_frames.append(frame_data)

func register_enemy_kill() -> void:
	enemies_killed += 1
	stats_updated.emit(current_level, enemies_killed)

func register_level_advance(new_level: int) -> void:
	current_level = maxi(1, new_level)
	stats_updated.emit(current_level, enemies_killed)

func finish_run(reason: String = "Game Over") -> void:
	var hero_info := get_selected_character_info()
	var timestamp := Time.get_datetime_string_from_system(false, true)
	var entry := {
		"seed": current_seed,
		"hero_idx": selected_character_index,
		"hero_name": String(hero_info.get("name", "Hero")),
		"floor": current_level,
		"kills": enemies_killed,
		"reason": sanitize_note(reason),
		"date": timestamp
	}
	if not is_replaying and not current_recording_frames.is_empty():
		last_recorded_run = entry.duplicate(true)
		last_recorded_run["frames"] = current_recording_frames.duplicate(true)
		entry["has_replay"] = true
		entry["frames"] = current_recording_frames.slice(0, min(current_recording_frames.size(), MAX_DISK_REPLAY_FRAMES))
	else:
		entry["has_replay"] = false
		entry["frames"] = []

	run_history.push_front(entry)
	if run_history.size() > MAX_RUN_HISTORY:
		run_history.resize(MAX_RUN_HISTORY)
	save_data_to_disk()
	saved_data_changed.emit()

func save_seed_entry(seed_str: String, note: String = "", hero_idx: int = -1) -> void:
	var clean_seed := sanitize_seed(seed_str)
	if clean_seed.is_empty():
		return
	if hero_idx < 0:
		hero_idx = selected_character_index
	hero_idx = clampi(hero_idx, 0, CHARACTER_SCENES.size() - 1)
	for i in range(saved_seeds.size()):
		if saved_seeds[i].get("seed", "") == clean_seed:
			saved_seeds.remove_at(i)
			break
	var safe_note := sanitize_note(note)
	var entry := {
		"seed": clean_seed,
		"note": safe_note if not safe_note.is_empty() else ("Tầng %d - %s" % [current_level, get_selected_character_info().get("name", "Hero")]),
		"hero_idx": hero_idx,
		"date": Time.get_datetime_string_from_system(false, true)
	}
	saved_seeds.push_front(entry)
	if saved_seeds.size() > MAX_SAVED_SEEDS:
		saved_seeds.resize(MAX_SAVED_SEEDS)
	save_data_to_disk()
	saved_data_changed.emit()

func remove_saved_seed(seed_str: String) -> void:
	var clean_seed := sanitize_seed(seed_str)
	for i in range(saved_seeds.size()):
		if saved_seeds[i].get("seed", "") == clean_seed or saved_seeds[i].get("seed", "") == seed_str:
			saved_seeds.remove_at(i)
			break
	save_data_to_disk()
	saved_data_changed.emit()

func replay_seed_run(seed_str: String, hero_idx: int = -1) -> void:
	if hero_idx >= 0:
		set_character_by_index(hero_idx)
	start_new_run(seed_str, false, [])
	get_tree().paused = false
	get_tree().change_scene_to_file("res://world.tscn")

func start_action_replay(run_entry: Dictionary = {}) -> bool:
	var target := run_entry if not run_entry.is_empty() else last_recorded_run
	if target.is_empty() or target.get("frames", []).is_empty():
		if not String(target.get("seed", "")).is_empty():
			replay_seed_run(String(target.get("seed", current_seed)), int(target.get("hero_idx", selected_character_index)))
			return true
		return false
	var hero_idx := clampi(int(target.get("hero_idx", selected_character_index)), 0, CHARACTER_SCENES.size() - 1)
	var seed_str := sanitize_seed(String(target.get("seed", current_seed)))
	var frames: Array = _sanitize_replay_frames(target.get("frames", []), MAX_REPLAY_FRAMES)
	set_character_by_index(hero_idx)
	start_new_run(seed_str, true, frames)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://world.tscn")
	return true

func save_data_to_disk() -> void:
	var data := {
		"current_seed": current_seed,
		"selected_character_index": selected_character_index,
		"saved_seeds": saved_seeds,
		"run_history": run_history,
		"last_recorded_run": last_recorded_run
	}
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_save_data() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		return
	if file.get_length() > MAX_SAVE_FILE_BYTES:
		push_warning("Save file exceeds security limit (2MB); skipping load.")
		file.close()
		return
	var content := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if not (parsed is Dictionary):
		return
	if parsed.has("current_seed"):
		var s := sanitize_seed(String(parsed["current_seed"]))
		if not s.is_empty():
			current_seed = s
	if parsed.has("selected_character_index"):
		set_character_by_index(int(parsed["selected_character_index"]))
	if parsed.has("saved_seeds") and parsed["saved_seeds"] is Array:
		saved_seeds.clear()
		var raw_seeds: Array = parsed["saved_seeds"]
		for i in range(mini(raw_seeds.size(), MAX_SAVED_SEEDS)):
			var item = raw_seeds[i]
			if item is Dictionary:
				var s_val := sanitize_seed(String(item.get("seed", "")))
				if not s_val.is_empty():
					saved_seeds.append({
						"seed": s_val,
						"note": sanitize_note(String(item.get("note", ""))),
						"hero_idx": clampi(int(item.get("hero_idx", 2)), 0, CHARACTER_SCENES.size() - 1),
						"date": sanitize_note(String(item.get("date", "")))
					})
	if parsed.has("run_history") and parsed["run_history"] is Array:
		run_history.clear()
		var raw_hist: Array = parsed["run_history"]
		for i in range(mini(raw_hist.size(), MAX_RUN_HISTORY)):
			var r = raw_hist[i]
			if r is Dictionary:
				var s_val := sanitize_seed(String(r.get("seed", "ALOALO1234")))
				var safe_frames := _sanitize_replay_frames(r.get("frames", []), MAX_DISK_REPLAY_FRAMES)
				run_history.append({
					"seed": s_val if not s_val.is_empty() else "ALOALO1234",
					"hero_idx": clampi(int(r.get("hero_idx", 2)), 0, CHARACTER_SCENES.size() - 1),
					"hero_name": sanitize_note(String(r.get("hero_name", "Hero"))),
					"floor": clampi(int(r.get("floor", 1)), 1, 9999),
					"kills": clampi(int(r.get("kills", 0)), 0, 999999),
					"reason": sanitize_note(String(r.get("reason", "Game Over"))),
					"date": sanitize_note(String(r.get("date", ""))),
					"has_replay": bool(r.get("has_replay", false)) and not safe_frames.is_empty(),
					"frames": safe_frames
				})
	if parsed.has("last_recorded_run") and parsed["last_recorded_run"] is Dictionary:
		var lr: Dictionary = parsed["last_recorded_run"]
		var lr_frames := _sanitize_replay_frames(lr.get("frames", []), MAX_REPLAY_FRAMES)
		last_recorded_run = {
			"seed": sanitize_seed(String(lr.get("seed", current_seed))),
			"hero_idx": clampi(int(lr.get("hero_idx", selected_character_index)), 0, CHARACTER_SCENES.size() - 1),
			"hero_name": sanitize_note(String(lr.get("hero_name", "Hero"))),
			"floor": clampi(int(lr.get("floor", 1)), 1, 9999),
			"kills": clampi(int(lr.get("kills", 0)), 0, 999999),
			"frames": lr_frames
		}
