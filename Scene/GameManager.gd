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
const MAX_SAVED_REPLAYS: int = 10 # Giới hạn tối đa 10 replay chống tràn RAM / Memory Leaks
const MAX_REPLAY_FRAMES: int = 18000
const MAX_DISK_REPLAY_FRAMES: int = 3600
const MAX_SAVE_FILE_BYTES: int = 2097152 # 2 MB chống DoS / Memory Exhaustion
const ALLOWED_SEED_CHARS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

const BalanceData = preload("res://Scene/BalanceConfig.gd")
const CompletionStore = preload("res://Scene/RunCompletionStore.gd")
const MAX_PROCESSED_RECEIPTS := 128

const CHARACTER_SCENES: Array[PackedScene] = [
	preload("res://Scene/Character/Player 3_Miya/player_3.tscn"),
	preload("res://Scene/Character/Player 2_Olaf/player_2.tscn"),
	preload("res://Scene/Character/Player 1_Pyrois/player.tscn"),
	preload("res://Scene/Character/Player 4_Charlotte/player_4.tscn"),
	preload("res://Scene/Character/Yugi/yugi.tscn"),
	preload("res://Scene/Character/Doraemon/doraemon.tscn"),
	preload("res://Scene/Character/Miyabi/miyabi.tscn"),
	preload("res://Scene/Character/LuongTho/luong_tho.tscn"),
]

var WORLD_LORE: Dictionary = BalanceData.WORLD_LORE
var CHARACTER_INFO: Array[Dictionary] = BalanceData.get_hero_list_for_ui()

func refresh_balance_data() -> void:
	WORLD_LORE = BalanceData.WORLD_LORE
	CHARACTER_INFO = BalanceData.get_hero_list_for_ui()

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

# Identity belongs to the lifecycle, never to seed/time. Providers are optional
# deterministic seams; the normal generator uses 128 cryptographic random bits.
var current_run_id: String = ""
var processed_ledger: Array = [] # FIFO oldest -> newest, independent of history/replays.
var last_completion_result: Dictionary = {}
var storage_state: String = "READY"
var run_id_provider: Callable
var completion_clock: Callable
var completion_store = CompletionStore.new(SAVE_FILE_PATH)
var _active_state: String = "CLOSED"
var _session_mode: String = "live"
var _envelope: Dictionary = {}
var _completion_date: String = ""
var _pending_snapshot: Dictionary = {}
var _uncertain_snapshot: Dictionary = {}
var _uncertain_completion: bool = false
var _uncertain_clear_frames: bool = false
var _writing: bool = false
# One owner-local canonical payload, independent of callers, history and envelope.
# All containers are read-only; never persisted or reconstructed after reload.
var _duplicate_payload: Dictionary = {}
var _duplicate_token: String = ""
var _duplicate_fingerprint: String = ""

func _ready() -> void:
	load_save_data()
	if storage_state == "READY" and saved_seeds.is_empty():
		save_seed_entry("ALOALO1234", "Khazad-dum Vanguard Expedition", 2)
		save_seed_entry("SOUL_KNIGHT_2026", "Labyrinthine Caverns of Moria", 0)
		save_seed_entry("BOSS_HUNT_777", "Chieftain Hunt Route", 3)

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
			"slot": clampi(slot_idx, -1, 15),
			# Shift (Yugi guard / Miyabi dash), mouse press/release, Q special result
			"shift": item.get("shift", false) == true,
			"lp": item.get("lp", false) == true,
			"lr": item.get("lr", false) == true,
			"rp": item.get("rp", false) == true,
			"rr": item.get("rr", false) == true,
			"result": clampi(int(item.get("result", 0)), 0, 5) if item.get("result", 0) is int else 0,
			# Doraemon's 4D pocket: gadget page switch (-n..n) and Dorayaki key
			"pg": clampi(int(item.get("pg", 0)), -10, 10) if (item.get("pg", 0) is int or item.get("pg", 0) is float) else 0,
			"eat": item.get("eat", false) == true
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

func can_start_new_run() -> bool:
	return storage_state == "READY" and not _writing and _active_state != "PENDING"

func start_new_run(custom_seed: String = "", replay_mode: bool = false, frames_to_replay: Array = []) -> bool:
	if not can_start_new_run():
		_outcome("SAVE_PENDING" if _active_state == "PENDING" or _writing else storage_state)
		return false
	var token := ""
	for attempt in range(16):
		var generated: Variant = run_id_provider.call() if run_id_provider.is_valid() else Crypto.new().generate_random_bytes(16).hex_encode()
		if _valid_id(generated) and generated != current_run_id and _receipt_for(generated).is_empty():
			token = generated
			break
	if token.is_empty():
		_outcome("ID_GENERATION_FAILED")
		return false
	current_run_id = token
	_duplicate_payload = {}
	_duplicate_token = ""
	_duplicate_fingerprint = ""
	_active_state = "OPEN"
	_session_mode = "action_replay" if replay_mode else "live"
	_envelope.clear()
	_pending_snapshot.clear()
	_completion_date = ""
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
	if get_node_or_null("/root/PerkManager") != null:
		PerkManager.seed_combat_rng((current_seed + ":combat").hash())
	stats_updated.emit(current_level, enemies_killed)
	return true

func record_frame_input(frame_data: Dictionary) -> void:
	if is_replaying:
		return
	if current_recording_frames.size() >= MAX_REPLAY_FRAMES:
		return

	# Nén/khử trùng lặp trạng thái đứng yên (anti-DoS / memory ballooning):
	# Nếu nhân vật không thao tác và hướng chuột không đổi, không lặp lại frame tĩnh
	if not current_recording_frames.is_empty():
		var last_f: Dictionary = current_recording_frames[-1]
		var is_idle: bool = (
			float(frame_data.get("dx", 0.0)) == 0.0 and float(frame_data.get("dy", 0.0)) == 0.0
			and not bool(frame_data.get("atk", false)) and not bool(frame_data.get("q", false))
			and not bool(frame_data.get("rmb", false)) and not bool(frame_data.get("shift", false))
			and not bool(frame_data.get("lp", false)) and not bool(frame_data.get("lr", false))
			and not bool(frame_data.get("rp", false)) and not bool(frame_data.get("rr", false))
			and int(frame_data.get("pg", 0)) == 0 and not bool(frame_data.get("eat", false))
			and int(frame_data.get("slot", -1)) == -1
		)
		var last_idle: bool = (
			float(last_f.get("dx", 0.0)) == 0.0 and float(last_f.get("dy", 0.0)) == 0.0
			and not bool(last_f.get("atk", false)) and not bool(last_f.get("q", false))
			and not bool(last_f.get("rmb", false)) and not bool(last_f.get("shift", false))
			and not bool(last_f.get("lp", false)) and not bool(last_f.get("lr", false))
			and not bool(last_f.get("rp", false)) and not bool(last_f.get("rr", false))
			and int(last_f.get("pg", 0)) == 0 and not bool(last_f.get("eat", false))
			and int(last_f.get("slot", -1)) == -1
			and absf(float(last_f.get("ax", 0.0)) - float(frame_data.get("ax", 0.0))) < 1.0
			and absf(float(last_f.get("ay", 0.0)) - float(frame_data.get("ay", 0.0))) < 1.0
		)
		if is_idle and last_idle:
			return

	current_recording_frames.append(frame_data)

func register_enemy_kill() -> void:
	enemies_killed += 1
	stats_updated.emit(current_level, enemies_killed)
	var pm = get_node_or_null("/root/PerkManager")
	if pm != null and pm.has_method("on_enemy_killed"):
		pm.on_enemy_killed()

func register_level_advance(new_level: int) -> void:
	current_level = maxi(1, new_level)
	stats_updated.emit(current_level, enemies_killed)

func finish_run(reason: String = "Game Over") -> Dictionary:
	if not _envelope.is_empty():
		if sanitize_note(reason) != _envelope.reason:
			return _outcome("CONFLICT")
		return complete_run_request(current_run_id, _envelope)
	return complete_run_request(current_run_id, {
		"seed": current_seed, "hero_idx": selected_character_index,
		"floor": current_level, "kills": enemies_killed, "reason": reason,
		"session_mode": _session_mode,
		"frames": current_recording_frames if not is_replaying else []
	})

func _outcome(status: String, receipt: Dictionary = {}) -> Dictionary:
	last_completion_result = {"status": status}
	if not receipt.is_empty():
		last_completion_result["receipt"] = receipt.duplicate(true)
	return last_completion_result.duplicate(true)

static func _valid_id(value: Variant, length: int = 32) -> bool:
	if not (value is String) or value.length() != length:
		return false
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true

static func _whole(value: Variant, low: int, high: int) -> bool:
	return ((value is int or value is float) and is_finite(float(value))
		and float(value) == floor(float(value)) and value >= low and value <= high)

func canonical_payload(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	for key in ["seed", "hero_idx", "floor", "kills", "reason", "session_mode", "frames"]:
		if not raw.has(key):
			return {}
	if not (raw.seed is String) or sanitize_seed(raw.seed).is_empty() or not (raw.reason is String):
		return {}
	if not _whole(raw.hero_idx, 0, CHARACTER_SCENES.size() - 1) or not _whole(raw.floor, 1, 9999) or not _whole(raw.kills, 0, 999999):
		return {}
	if not (raw.session_mode is String) or raw.session_mode not in ["live", "action_replay"] or not (raw.frames is Array):
		return {}
	var frames: Array = []
	for frame in raw.frames.slice(0, MAX_REPLAY_FRAMES):
		if not (frame is Dictionary):
			return {}
		var normalized: Dictionary = frame.duplicate(true)
		for key in ["dx", "dy", "ax", "ay", "slot", "result", "pg"]:
			if frame.has(key):
				var number: Variant = frame[key]
				if not (number is int or number is float) or not is_finite(float(number)):
					return {}
				if key in ["slot", "result", "pg"]:
					if float(number) != floor(float(number)):
						return {}
					normalized[key] = int(clampf(float(number), -1000000.0, 1000000.0))
		for key in ["atk", "q", "rmb", "shift", "lp", "lr", "rp", "rr", "eat"]:
			if frame.has(key) and not (frame[key] is bool):
				return {}
		frames.append(normalized)
	return {"seed": sanitize_seed(raw.seed), "hero_idx": int(raw.hero_idx),
		"floor": int(raw.floor), "kills": int(raw.kills), "reason": sanitize_note(raw.reason),
		"session_mode": raw.session_mode, "frames": _sanitize_replay_frames(frames, MAX_REPLAY_FRAMES)}

func payload_fingerprint(payload: Dictionary) -> String:
	var frames: Array = []
	for frame in payload.frames:
		var tuple: Array = []
		for key in ["dx", "dy", "ax", "ay", "atk", "q", "rmb", "slot", "shift", "lp", "lr", "rp", "rr", "result", "pg", "eat"]:
			tuple.append(frame[key])
		frames.append(tuple)
	return JSON.stringify([1, payload.seed, payload.hero_idx, payload.floor, payload.kills,
		payload.reason, payload.session_mode, frames]).sha256_text()

func _receipt_for(token: String) -> Dictionary:
	for receipt in processed_ledger:
		if receipt.run_id == token:
			return receipt
	return {}

func _remember_validated_payload(token: String, payload: Dictionary, fingerprint: String) -> void:
	_duplicate_payload = payload
	for frame in _duplicate_payload.frames:
		frame.make_read_only()
	_duplicate_payload.frames.make_read_only()
	_duplicate_payload.make_read_only()
	_duplicate_token = token
	_duplicate_fingerprint = fingerprint

func complete_run_request(token: Variant, raw_payload: Variant) -> Dictionary:
	if not _valid_id(token):
		return _outcome("INVALID_REQUEST")
	# Exact structural equality to validated canonical values is sufficient,
	# never required. Noncanonical/invalid/conflicting inputs use the old path.
	if (storage_state == "READY" and not _writing and _active_state == "CLOSED"
			and token == current_run_id and token == _duplicate_token):
		var committed := _receipt_for(token)
		if (not committed.is_empty() and committed.fingerprint == _duplicate_fingerprint
				and raw_payload is Dictionary and raw_payload == _duplicate_payload):
			return _outcome("DUPLICATE", committed)
	var payload := canonical_payload(raw_payload)
	if payload.is_empty():
		return _outcome("INVALID_REQUEST")
	if storage_state != "READY" or _writing:
		return _outcome(storage_state if storage_state != "READY" else "SAVE_PENDING")
	var fingerprint := payload_fingerprint(payload)
	var prior := _receipt_for(token)
	if not prior.is_empty():
		return _outcome("DUPLICATE", prior) if prior.fingerprint == fingerprint else _outcome("CONFLICT")
	if token != current_run_id or _active_state == "CLOSED":
		return _outcome("UNKNOWN_RUN")
	if _envelope.is_empty() and payload.session_mode != _session_mode:
		return _outcome("INVALID_REQUEST")
	if not _envelope.is_empty() and payload_fingerprint(_envelope) != fingerprint:
		return _outcome("CONFLICT")
	if _envelope.is_empty():
		_envelope = payload.duplicate(true)
		_remember_validated_payload(token, payload, fingerprint)
		_completion_date = String(completion_clock.call()) if completion_clock.is_valid() else Time.get_datetime_string_from_system(false, true)
		_active_state = "PENDING"
		var candidate := _snapshot()
		var entry: Dictionary = payload.duplicate(true)
		entry["run_id"] = token
		entry["date"] = _completion_date
		entry["hero_name"] = String(CHARACTER_INFO[payload.hero_idx].get("name", "Hero"))
		entry["has_replay"] = not payload.frames.is_empty()
		if entry.has_replay:
			candidate.last_recorded_run = entry.duplicate(true)
		entry.frames = entry.frames.slice(0, MAX_DISK_REPLAY_FRAMES)
		candidate.run_history.push_front(entry)
		_limit_history(candidate.run_history)
		var summary := payload.duplicate(true)
		summary.erase("frames")
		candidate.processed_ledger.append({"run_id": token, "fingerprint": fingerprint,
			"date": _completion_date, "summary": summary})
		if candidate.processed_ledger.size() > MAX_PROCESSED_RECEIPTS:
			candidate.processed_ledger.pop_front()
		_pending_snapshot = candidate
	var receipt: Dictionary = _pending_snapshot.processed_ledger[-1].duplicate(true)
	var result := _write_snapshot(_pending_snapshot, true)
	return _outcome(result.status, receipt if result.status == "COMMITTED" else {})

# --- CƠ CHẾ GIỚI HẠN & GIẢI PHÓNG BỘ NHỚ REPLAY (ANTI-MEMORY LEAK / MULTIPLAYER READY) ---
func enforce_replay_limits() -> void:
	_limit_history(run_history)

static func _limit_history(history: Array) -> void:
	var replay_count := 0
	for item in history:
		if bool(item.get("has_replay", false)) and item.has("frames") and not item["frames"].is_empty():
			replay_count += 1
			if replay_count > MAX_SAVED_REPLAYS:
				# Thu hồi vùng nhớ các mảng frame của các replay cũ vượt quá giới hạn 10
				item["frames"].clear()
				item["has_replay"] = false
	if history.size() > MAX_RUN_HISTORY:
		history.resize(MAX_RUN_HISTORY)

func delete_replay(run_entry: Dictionary) -> bool:
	if not _can_edit():
		return false
	var index := -1
	var matches: Array[int] = []
	for i in range(run_history.size()):
		if is_same(run_history[i], run_entry):
			index = i
			break
		if _same_saved_run(run_history[i], run_entry) and (run_entry.has("run_id") or run_history[i] == run_entry):
			matches.append(i)
	if index < 0 and matches.size() == 1:
		index = matches[0]
	if index < 0:
		return false
	var original: Dictionary = run_history[index]
	var candidate := _snapshot()
	candidate.run_history[index].frames = []
	candidate.run_history[index].has_replay = false
	if _last_matches(original):
		candidate.last_recorded_run = {}
	if _write_snapshot(candidate).status != "COMMITTED":
		return false
	# Preserve the existing API's observable dictionary reference after commit.
	original["frames"] = []
	original["has_replay"] = false
	return true

func delete_run_history_entry(index: int) -> bool:
	if not _can_edit() or index < 0 or index >= run_history.size():
		return false
	var candidate := _snapshot()
	if _last_matches(run_history[index]):
		candidate.last_recorded_run = {}
	candidate.run_history.remove_at(index)
	return _write_snapshot(candidate).status == "COMMITTED"

func clear_all_replays() -> void:
	if not _can_edit():
		return
	var candidate := _snapshot()
	for entry in candidate.run_history:
		if entry.has("frames") and entry["frames"] is Array:
			entry["frames"].clear()
		entry["has_replay"] = false
	candidate.last_recorded_run = {}
	_write_snapshot(candidate, false, true)

static func _same_saved_run(a: Dictionary, b: Dictionary) -> bool:
	if a.has("run_id") or b.has("run_id"):
		return a.has("run_id") and b.has("run_id") and a.run_id == b.run_id
	for key in ["seed", "date", "hero_idx", "floor", "kills", "reason"]:
		if not a.has(key) or not b.has(key) or a[key] != b[key]:
			return false
	return true

func _last_matches(entry: Dictionary) -> bool:
	if not _same_saved_run(entry, last_recorded_run):
		return false
	if entry.has("run_id"):
		return true
	var count := 0
	for item in run_history:
		if _same_saved_run(item, entry):
			count += 1
	return count == 1

func get_saved_replays_count() -> int:
	var count := 0
	for entry in run_history:
		if bool(entry.get("has_replay", false)) and not entry.get("frames", []).is_empty():
			count += 1
	return count

func save_seed_entry(seed_str: String, note: String = "", hero_idx: int = -1) -> void:
	if not _can_edit():
		return
	var clean_seed := sanitize_seed(seed_str)
	if clean_seed.is_empty():
		return
	if hero_idx < 0:
		hero_idx = selected_character_index
	hero_idx = clampi(hero_idx, 0, CHARACTER_SCENES.size() - 1)
	var candidate := _snapshot()
	for i in range(candidate.saved_seeds.size()):
		if candidate.saved_seeds[i].get("seed", "") == clean_seed:
			candidate.saved_seeds.remove_at(i)
			break
	var safe_note := sanitize_note(note)
	var entry := {
		"seed": clean_seed,
		"note": safe_note if not safe_note.is_empty() else ("Floor %d — %s" % [current_level, get_selected_character_info().get("name", "Hero")]),
		"hero_idx": hero_idx,
		"date": Time.get_datetime_string_from_system(false, true)
	}
	candidate.saved_seeds.push_front(entry)
	if candidate.saved_seeds.size() > MAX_SAVED_SEEDS:
		candidate.saved_seeds.resize(MAX_SAVED_SEEDS)
	_write_snapshot(candidate)

func remove_saved_seed(seed_str: String) -> void:
	if not _can_edit():
		return
	var clean_seed := sanitize_seed(seed_str)
	var candidate := _snapshot()
	for i in range(candidate.saved_seeds.size()):
		if candidate.saved_seeds[i].get("seed", "") == clean_seed or candidate.saved_seeds[i].get("seed", "") == seed_str:
			candidate.saved_seeds.remove_at(i)
			break
	_write_snapshot(candidate)

func replay_seed_run(seed_str: String, hero_idx: int = -1) -> bool:
	if not can_start_new_run():
		return false
	if not start_new_run(seed_str, false, []):
		return false
	if hero_idx >= 0:
		set_character_by_index(hero_idx)
	get_tree().paused = false
	return get_tree().change_scene_to_file("res://world.tscn") == OK

func start_action_replay(run_entry: Dictionary = {}) -> bool:
	if not can_start_new_run():
		return false
	var target := run_entry if not run_entry.is_empty() else last_recorded_run
	if target.is_empty() or target.get("frames", []).is_empty():
		if not String(target.get("seed", "")).is_empty():
			return replay_seed_run(String(target.get("seed", current_seed)), int(target.get("hero_idx", selected_character_index)))
		return false
	var hero_idx := clampi(int(target.get("hero_idx", selected_character_index)), 0, CHARACTER_SCENES.size() - 1)
	var seed_str := sanitize_seed(String(target.get("seed", current_seed)))
	var frames: Array = _sanitize_replay_frames(target.get("frames", []), MAX_REPLAY_FRAMES)
	if not start_new_run(seed_str, true, frames):
		return false
	set_character_by_index(hero_idx)
	get_tree().paused = false
	return get_tree().change_scene_to_file("res://world.tscn") == OK

func _snapshot() -> Dictionary:
	return {
		"schema_version": 2, "processed_ledger": processed_ledger.duplicate(true),
		"current_seed": current_seed,
		"selected_character_index": selected_character_index,
		"saved_seeds": saved_seeds.duplicate(true),
		"run_history": run_history.duplicate(true),
		"last_recorded_run": last_recorded_run.duplicate(true)
	}

func _can_edit() -> bool:
	return storage_state == "READY" and not _writing and _active_state != "PENDING"

func _publish_snapshot(data: Dictionary) -> void:
	current_seed = data.current_seed
	set_character_by_index(int(data.selected_character_index))
	saved_seeds = data.saved_seeds
	run_history = data.run_history
	last_recorded_run = data.last_recorded_run
	processed_ledger = data.processed_ledger

func _write_snapshot(candidate: Dictionary, completion: bool = false, clear_frames: bool = false) -> Dictionary:
	if _writing or storage_state != "READY":
		return {"status": "STORAGE_UNCERTAIN" if storage_state == "STORAGE_UNCERTAIN" else "SAVE_FAILED"}
	if not _valid_v2_snapshot(candidate):
		return {"status": "SAVE_FAILED"}
	_writing = true
	var result: Dictionary = completion_store.commit(candidate)
	if result.status == "COMMITTED":
		_publish_snapshot(candidate)
		if clear_frames:
			replay_frames.clear()
			current_recording_frames.clear()
		if completion:
			_active_state = "CLOSED"
			_pending_snapshot = {}
	elif result.status == "STORAGE_UNCERTAIN":
		storage_state = "STORAGE_UNCERTAIN"
		_uncertain_snapshot = candidate
		_uncertain_completion = completion
		_uncertain_clear_frames = clear_frames
	_writing = false
	# Close/publish before observers can synchronously retry or start a new run.
	if result.status == "COMMITTED":
		saved_data_changed.emit()
	return result

func reconcile_storage() -> Dictionary:
	if storage_state != "STORAGE_UNCERTAIN" or _writing:
		return _outcome("NOT_PENDING")
	var result: Dictionary = completion_store.reconcile()
	if result.status == "STORAGE_UNCERTAIN":
		return _outcome(result.status)
	storage_state = "READY"
	var receipt: Dictionary = {}
	if result.status == "COMMITTED":
		_publish_snapshot(_uncertain_snapshot)
		if _uncertain_clear_frames:
			replay_frames.clear()
			current_recording_frames.clear()
		if _uncertain_completion:
			_active_state = "CLOSED"
			_pending_snapshot = {}
			receipt = _receipt_for(current_run_id).duplicate(true)
	_uncertain_snapshot = {}
	_uncertain_completion = false
	_uncertain_clear_frames = false
	if result.status == "COMMITTED":
		saved_data_changed.emit()
	return _outcome(result.status, receipt)

func save_data_to_disk() -> Dictionary:
	if not _can_edit():
		return {"status": "SAVE_PENDING" if _active_state == "PENDING" or _writing else storage_state}
	return _write_snapshot(_snapshot())

func load_save_data() -> bool:
	if _writing or _active_state == "PENDING" or storage_state == "STORAGE_UNCERTAIN":
		return false
	var source: Dictionary = completion_store.read_bytes(completion_store.path)
	if source.status != "OK":
		storage_state = "LOAD_ERROR"
		return false
	if not source.exists:
		return storage_state == "READY"
	var parsed: Variant = JSON.parse_string(source.bytes.get_string_from_utf8())
	if not (parsed is Dictionary) or (parsed.has("schema_version") and not _valid_v2_snapshot(parsed)) or (not parsed.has("schema_version") and parsed.has("processed_ledger")):
		storage_state = "LOAD_ERROR"
		return false
	var candidate := _decode_snapshot(parsed)
	_publish_snapshot(candidate)
	current_run_id = "" # Loading receipts does not resume an uncommitted session.
	_duplicate_payload = {}
	_duplicate_token = ""
	_duplicate_fingerprint = ""
	_active_state = "CLOSED"
	_envelope = {}
	_pending_snapshot = {}
	storage_state = "READY"
	return true

func _decode_snapshot(parsed: Dictionary) -> Dictionary:
	var data := {"schema_version": 2, "current_seed": "ALOALO1234", "selected_character_index": 2,
		"saved_seeds": [], "run_history": [], "last_recorded_run": {},
		"processed_ledger": parsed.get("processed_ledger", []).duplicate(true)}
	for receipt in data.processed_ledger:
		var summary: Dictionary = receipt.summary.duplicate(true)
		summary["frames"] = []
		receipt.summary = canonical_payload(summary)
		receipt.summary.erase("frames")
	if parsed.has("current_seed"):
		var s := sanitize_seed(String(parsed["current_seed"]))
		if not s.is_empty():
			data.current_seed = s
	if parsed.has("selected_character_index"):
		data.selected_character_index = clampi(int(parsed["selected_character_index"]), 0, CHARACTER_SCENES.size() - 1)
	if parsed.has("saved_seeds") and parsed["saved_seeds"] is Array:
		var raw_seeds: Array = parsed["saved_seeds"]
		for i in range(mini(raw_seeds.size(), MAX_SAVED_SEEDS)):
			var item = raw_seeds[i]
			if item is Dictionary:
				var s_val := sanitize_seed(String(item.get("seed", "")))
				if not s_val.is_empty():
					data.saved_seeds.append({
						"seed": s_val,
						"note": sanitize_note(String(item.get("note", ""))),
						"hero_idx": clampi(int(item.get("hero_idx", 2)), 0, CHARACTER_SCENES.size() - 1),
						"date": sanitize_note(String(item.get("date", "")))
					})
	if parsed.has("run_history") and parsed["run_history"] is Array:
		var raw_hist: Array = parsed["run_history"]
		for i in range(mini(raw_hist.size(), MAX_RUN_HISTORY)):
			var r = raw_hist[i]
			if r is Dictionary:
				var s_val := sanitize_seed(String(r.get("seed", "ALOALO1234")))
				var safe_frames := _sanitize_replay_frames(r.get("frames", []), MAX_DISK_REPLAY_FRAMES)
				var entry := {
					"seed": s_val if not s_val.is_empty() else "ALOALO1234",
					"hero_idx": clampi(int(r.get("hero_idx", 2)), 0, CHARACTER_SCENES.size() - 1),
					"hero_name": sanitize_note(String(r.get("hero_name", "Hero"))),
					"floor": clampi(int(r.get("floor", 1)), 1, 9999),
					"kills": clampi(int(r.get("kills", 0)), 0, 999999),
					"reason": sanitize_note(String(r.get("reason", "Game Over"))),
					"date": sanitize_note(String(r.get("date", ""))),
					"has_replay": bool(r.get("has_replay", false)) and not safe_frames.is_empty(),
					"frames": safe_frames
				}
				_restore_identity(r, entry, parsed.has("schema_version"))
				data.run_history.append(entry)
		_limit_history(data.run_history)
	if parsed.has("last_recorded_run") and parsed["last_recorded_run"] is Dictionary:
		var lr: Dictionary = parsed["last_recorded_run"]
		var lr_frames := _sanitize_replay_frames(lr.get("frames", []), MAX_REPLAY_FRAMES)
		data.last_recorded_run = {
			"seed": sanitize_seed(String(lr.get("seed", data.current_seed))),
			"hero_idx": clampi(int(lr.get("hero_idx", data.selected_character_index)), 0, CHARACTER_SCENES.size() - 1),
			"hero_name": sanitize_note(String(lr.get("hero_name", "Hero"))),
			"floor": clampi(int(lr.get("floor", 1)), 1, 9999),
			"kills": clampi(int(lr.get("kills", 0)), 0, 999999),
			"reason": sanitize_note(String(lr.get("reason", "Game Over"))),
			"date": sanitize_note(String(lr.get("date", ""))),
			"has_replay": not lr_frames.is_empty(), "frames": lr_frames
		}
		if lr.is_empty():
			data.last_recorded_run = {}
		else:
			_restore_identity(lr, data.last_recorded_run, parsed.has("schema_version"))
	return data

static func _restore_identity(raw: Dictionary, entry: Dictionary, versioned: bool) -> void:
	if versioned and raw.has("run_id"):
		entry["run_id"] = raw.run_id
		entry["session_mode"] = raw.session_mode

func _valid_v2_snapshot(data: Dictionary) -> bool:
	if not _whole(data.get("schema_version"), 2, 2):
		return false
	if not (data.get("current_seed") is String) or sanitize_seed(data.current_seed) != data.current_seed or data.current_seed.is_empty() or not _whole(data.get("selected_character_index"), 0, CHARACTER_SCENES.size() - 1):
		return false
	for key in ["processed_ledger", "run_history", "saved_seeds"]:
		if not (data.get(key) is Array):
			return false
	if data.processed_ledger.size() > MAX_PROCESSED_RECEIPTS or data.run_history.size() > MAX_RUN_HISTORY or data.saved_seeds.size() > MAX_SAVED_SEEDS or not (data.get("last_recorded_run") is Dictionary):
		return false
	var receipts: Dictionary = {}
	for receipt in data.processed_ledger:
		if not (receipt is Dictionary) or not _valid_id(receipt.get("run_id")) or not _valid_id(receipt.get("fingerprint"), 64) or receipts.has(receipt.run_id) or not (receipt.get("date") is String) or not (receipt.get("summary") is Dictionary):
			return false
		var payload: Dictionary = receipt.summary.duplicate(true)
		payload["frames"] = []
		if canonical_payload(payload).is_empty():
			return false
		receipts[receipt.run_id] = receipt
	var ids: Dictionary = {}
	for entry in data.run_history:
		if not (entry is Dictionary) or not _valid_saved_entry(entry):
			return false
		if entry.has("run_id"):
			if ids.has(entry.run_id) or not receipts.has(entry.run_id):
				return false
			ids[entry.run_id] = true
			for key in ["seed", "hero_idx", "floor", "kills", "reason", "session_mode"]:
				if entry.get(key) != receipts[entry.run_id].summary.get(key):
					return false
	if not data.last_recorded_run.is_empty() and not _valid_saved_entry(data.last_recorded_run):
		return false
	for entry in data.saved_seeds:
		if not (entry is Dictionary) or not (entry.get("seed") is String) or sanitize_seed(entry.seed).is_empty() or not _whole(entry.get("hero_idx"), 0, CHARACTER_SCENES.size() - 1) or not (entry.get("note") is String) or not (entry.get("date") is String):
			return false
	return true

func _valid_saved_entry(entry: Dictionary) -> bool:
	if not entry.has("run_id"):
		return true # Legacy entries keep baseline sanitizer behavior, without IDs.
	if not _valid_id(entry.run_id) or not (entry.get("date") is String) or not (entry.get("hero_name") is String) or not (entry.get("has_replay") is bool):
		return false
	return not canonical_payload(entry).is_empty()
