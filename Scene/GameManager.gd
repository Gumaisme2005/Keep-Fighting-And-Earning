extends Node

signal seed_changed(new_seed: String)
signal stats_updated(level: int, kills: int)
signal saved_data_changed()
signal coins_changed(total: int, delta: int)

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
const GUILD_HALL_SCENE: String = "res://Scene/Map/GuildHall/guild_hall.tscn"
const DUNGEON_SCENE: String = "res://world.tscn"
const COIN_PICKUP_SCRIPT = preload("res://Scene/Items/Coin/coin_pickup.gd")
const PerkManagerScript = preload("res://Scene/Perks/PerkManager.gd")

# --- HỆ THỐNG TIỀN TỆ (XU) ---
const MAX_COINS: int = 9999999
const MAX_COIN_PIECES: int = 6         # số đồng xu tối đa rơi ra từ 1 quái thường
const MAX_BOSS_COIN_PIECES: int = 14   # số đồng xu tối đa rơi ra từ boss

# --- VÍ TIỀN LƯU LÂU DÀI (dùng chung cho mọi nhân vật và mọi lượt chơi) ---
# Ví nằm trong file riêng (nhỏ, ghi nhanh), tách khỏi save seed / lịch sử / replay.
# Ghi an toàn: viết file tạm -> kiểm tra -> chép file chính cũ sang .bak -> đổi tên file tạm thành file chính.
# Khi tải: file chính -> file tạm (nếu lần ghi trước bị ngắt giữa chừng) -> .bak; không có file hợp lệ nào thì số dư = 0.
const WALLET_FILE_PATH: String = "user://wallet.json"
const WALLET_TEST_FILE_PATH: String = "user://wallet_test.json"   # khi chạy tests/*: không đụng ví thật của người chơi
const WALLET_VERSION: int = 1
const WALLET_SAVE_DELAY: float = 1.5     # gom các lần nhặt xu liên tiếp rồi mới lưu
const WALLET_MAX_FILE_BYTES: int = 4096

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
## Số dư ví (đọc ở mọi nơi: HUD, cửa hàng...). Gán trực tiếp cũng đi qua set_wallet_balance() (kiểm tra + lưu ngay).
var coins: int:
	get:
		return _wallet_balance
	set(value):
		set_wallet_balance(value)
var _wallet_balance: int = 0
var _wallet_dirty: bool = false           # có thay đổi chưa ghi xuống đĩa
var _wallet_save_timer: Timer = null
var wallet_path: String = WALLET_FILE_PATH
var run_coins: int = 0                    # xu nhặt được trong lượt này (chỉ để ghi lịch sử, không cộng lại vào ví)
var run_id: int = 0   # tăng mỗi run mới, để xu của run cũ không cộng nhầm sang run mới
var _last_coin_sfx_msec: int = 0
var _coin_sfx_streak: int = 0
var run_start_time_msec: int = 0
## Guild Hall đang ở màn "Chọn nhân vật" (đầu run, chưa có nhân vật điều khiển): bấm vào anh hùng trong sảnh để chọn.
var hall_selecting: bool = false

# --- DỮ LIỆU LƯU SEED & LỊCH SỬ RUN ---
var saved_seeds: Array = []   # [{ "seed": String, "note": String, "hero_idx": int, "date": String }]
var run_history: Array = []   # [{ "seed": String, "hero_idx": int, "hero_name": String, "floor": int, "kills": int, "date": String, "frames": Array }]

# --- HỆ THỐNG REPLAY MỘT RUN (RECORD & PLAYBACK) ---
var is_replaying: bool = false
var replay_frames: Array = []
var current_recording_frames: Array = []
var last_recorded_run: Dictionary = {}

func _ready() -> void:
	_setup_wallet()
	load_save_data()
	if saved_seeds.is_empty():
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

# --- PHÍM T: DỊCH CHUYỂN VỀ GUILD HALL ---
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("teleport_hall") and not event.is_echo():
		if teleport_to_guild_hall():
			get_viewport().set_input_as_handled()

## Đưa nhân vật đang chơi (giữ nguyên máu, đồ, hồi chiêu) sang Guild Hall.
## Không làm gì khi chưa có nhân vật (menu), nhân vật đã gục, đang xem replay hoặc game đang tạm dừng.
func teleport_to_guild_hall() -> bool:
	if is_replaying or get_tree().paused:
		return false
	var hero := _find_hero()
	if hero == null or hero.get("is_dead") == true:
		return false
	var current := get_tree().current_scene
	if current != null and current.has_method("place_hero") and current.scene_file_path == GUILD_HALL_SCENE:
		current.place_hero(hero)
		return true
	hall_selecting = false
	call_deferred("_swap_to_guild_hall", hero)
	return true

func _swap_to_guild_hall(hero: Node2D) -> void:
	if not is_instance_valid(hero):
		return
	var tree := get_tree()
	var old_scene := tree.current_scene
	var hall: Node = load(GUILD_HALL_SCENE).instantiate()
	hall.set("spawn_hero", false)
	if hero.get_parent() != null:
		hero.get_parent().remove_child(hero)
	tree.root.add_child(hall)
	tree.current_scene = hall
	if old_scene != null and old_scene != hall:
		old_scene.queue_free()
	hall.place_hero(hero)

## Thanh kiếm rune trong Guild Hall: đưa nhân vật (giữ nguyên máu, đồ, xu, chấn) xuống hầm ngục tầng 1.
## Seed của run giữ nguyên nên tầng 1 vẫn là tầng 1 của seed đang chơi.
func enter_dungeon_from_hall(hero: Node2D = null) -> bool:
	if is_replaying:
		return false
	if hero == null or not is_instance_valid(hero):
		hero = _find_hero()
	if hero == null or hero.get("is_dead") == true:
		return false
	current_level = 1
	if sanitize_seed(current_seed).is_empty():
		current_seed = generate_random_seed()
	flush_wallet()   # xuống hầm ngục = chuyển tầng: lưu ví ngay
	call_deferred("_swap_to_dungeon", hero)
	return true

func _swap_to_dungeon(hero: Node2D) -> void:
	if not is_instance_valid(hero):
		return
	var tree := get_tree()
	tree.paused = false
	var old_scene := tree.current_scene
	var world: Node = load(DUNGEON_SCENE).instantiate()
	var gen: Node = world.get_node_or_null("TileMap")
	if hero.get_parent() != null:
		hero.get_parent().remove_child(hero)
	hero.name = "Player"
	hero.z_index = 2
	if "velocity" in hero:
		hero.velocity = Vector2.ZERO
	# camera của sảnh bị giới hạn trong sảnh - trả về mặc định cho hầm ngục
	for cam in hero.find_children("*", "Camera2D", true, false):
		cam.limit_left = -10000000
		cam.limit_top = -10000000
		cam.limit_right = 10000000
		cam.limit_bottom = 10000000
	if gen != null:
		# dungeon_generator thấy the_player đã có thì không sinh nhân vật mới, chỉ đặt vào phòng đầu
		gen.set("the_player", hero)
		gen.add_child(hero)
	else:
		world.add_child(hero)
	tree.root.add_child(world)
	tree.current_scene = world
	if old_scene != null and old_scene != world:
		old_scene.queue_free()
	# HUD (GameUI nằm trong nhân vật) nối lại với bản đồ / minimap mới
	tree.call_group_flags(SceneTree.GROUP_CALL_DEFERRED, "game_ui", "_connect_to_player_and_map")
	tree.call_group_flags(SceneTree.GROUP_CALL_DEFERRED, "game_ui", "show_banner", "ENTERING THE DUNGEON - FLOOR 1", Color(0.55, 0.9, 1.0))

## Run mới bắt đầu ở Guild Hall, màn "Chọn nhân vật" (giống Soul Knight): sảnh nhìn toàn cảnh, bấm vào một anh hùng
## để xem chỉ số / cách chơi, BẮT ĐẦU để điều khiển người đó ngay trong sảnh, rồi đi qua thanh kiếm rune xuống hầm ngục.
## Thay cho màn chọn nhân vật cũ (Scene/UI/CharacterSelect.tscn).
func start_run_in_hall(seed_str: String = "") -> void:
	start_new_run(seed_str if not seed_str.is_empty() else current_seed, false, [])
	hall_selecting = true
	get_tree().paused = false
	get_tree().change_scene_to_file(GUILD_HALL_SCENE)

func _find_hero() -> Node2D:
	for n in get_tree().get_nodes_in_group("player"):
		if n is CharacterBody2D:
			return n
	return null

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
	run_coins = 0   # ví KHÔNG reset: số dư giữ nguyên qua mọi lượt chơi
	run_id += 1
	run_start_time_msec = Time.get_ticks_msec()
	is_replaying = replay_mode
	if replay_mode:
		replay_frames = _sanitize_replay_frames(frames_to_replay, MAX_REPLAY_FRAMES)
		current_recording_frames.clear()
	else:
		replay_frames.clear()
		current_recording_frames.clear()
	if get_node_or_null("/root/PerkManager") != null:
		PerkManagerScript.seed_combat_rng((current_seed + ":combat").hash())
	stats_updated.emit(current_level, enemies_killed)
	coins_changed.emit(coins, 0)
	flush_wallet()

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

## enemy / reward_key: kẻ địch vừa chết và khoá trong BalanceConfig.COIN_REWARDS -> rơi xu tại chỗ.
func register_enemy_kill(enemy: Node = null, reward_key: String = "") -> void:
	enemies_killed += 1
	stats_updated.emit(current_level, enemies_killed)
	var pm = get_node_or_null("/root/PerkManager")
	if pm != null and pm.has_method("on_enemy_killed"):
		pm.on_enemy_killed()
	if enemy != null and is_instance_valid(enemy) and enemy is Node2D and enemy.is_inside_tree():
		spawn_kill_coins(enemy, reward_key)

# --- HỆ THỐNG TIỀN TỆ: VÍ TẬP TRUNG ---
# Mọi thay đổi số dư đều đi qua add_coins / spend_coins / set_wallet_balance.

## Cộng xu vào ví (nhặt xu, bán đồ). Lưu gom sau WALLET_SAVE_DELAY giây.
## Khi đang xem replay: ví thật không đổi.
func add_coins(amount: int, play_sound: bool = true) -> void:
	if amount <= 0 or is_replaying:
		return
	var new_balance: int = mini(_wallet_balance + amount, MAX_COINS)
	var delta: int = new_balance - _wallet_balance
	if delta <= 0:
		return
	_wallet_balance = new_balance
	run_coins = mini(run_coins + delta, MAX_COINS)
	coins_changed.emit(_wallet_balance, delta)
	_schedule_wallet_save()
	if play_sound:
		_play_coin_sfx()

## Trừ xu khi mua / đổi; từ chối nếu số lượng không hợp lệ hoặc vượt số dư. Lưu ngay.
func spend_coins(amount: int) -> bool:
	if amount <= 0 or is_replaying or _wallet_balance < amount:
		return false
	_wallet_balance -= amount
	coins_changed.emit(_wallet_balance, -amount)
	save_wallet()
	return true

## Đặt số dư (công cụ / kiểm thử): kẹp trong [0, MAX_COINS] và lưu ngay. Bỏ qua khi đang xem replay.
func set_wallet_balance(value: int) -> void:
	if is_replaying:
		return
	var v: int = clampi(value, 0, MAX_COINS)
	var delta: int = v - _wallet_balance
	_wallet_balance = v
	coins_changed.emit(_wallet_balance, delta)
	save_wallet()

## Ghi ví xuống đĩa ngay nếu còn thay đổi chưa lưu (chuyển tầng, kết thúc lượt, thoát game...).
func flush_wallet() -> void:
	if _wallet_dirty:
		save_wallet()

func _setup_wallet() -> void:
	if _is_test_run():
		wallet_path = WALLET_TEST_FILE_PATH
	_wallet_save_timer = Timer.new()
	_wallet_save_timer.name = "WalletSaveTimer"
	_wallet_save_timer.one_shot = true
	_wallet_save_timer.wait_time = WALLET_SAVE_DELAY
	_wallet_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS   # vẫn lưu khi game đang tạm dừng
	_wallet_save_timer.timeout.connect(flush_wallet)
	add_child(_wallet_save_timer)
	load_wallet()

## Chạy một scene / script trong thư mục tests/ (CI, run_tests.bat, F6 trong editor) thì dùng ví thử nghiệm riêng.
static func _is_test_run() -> bool:
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		var arg := String(a).replace("\\", "/")
		if arg.contains("tests/") and (arg.ends_with(".tscn") or arg.ends_with(".gd")):
			return true
	return false

func _schedule_wallet_save() -> void:
	_wallet_dirty = true
	if _wallet_save_timer == null or not _wallet_save_timer.is_inside_tree():
		save_wallet()
	elif _wallet_save_timer.is_stopped():
		_wallet_save_timer.start(WALLET_SAVE_DELAY)   # không khởi động lại khi đang chờ: lưu tối đa ~1.5 s / lần

## Ghi an toàn: file tạm -> kiểm tra đọc lại -> sao lưu file chính cũ (.bak) -> thay file chính. true nếu thành công.
func save_wallet() -> bool:
	if _wallet_save_timer != null and _wallet_save_timer.is_inside_tree():
		_wallet_save_timer.stop()
	_wallet_dirty = true   # chỉ xoá khi ghi xong; ghi lỗi thì lần flush sau (chuyển tầng, thoát game...) thử lại
	var tmp_path := wallet_path + ".tmp"
	var bak_path := wallet_path + ".bak"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Wallet: cannot write %s (%s)" % [tmp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify({"version": WALLET_VERSION, "coins": _wallet_balance}))
	file.flush()
	file.close()
	if read_wallet_file(tmp_path) != _wallet_balance:
		push_warning("Wallet: verification of %s failed, keeping the previous save" % tmp_path)
		return false
	if read_wallet_file(wallet_path) >= 0:
		var copy_err := DirAccess.copy_absolute(wallet_path, bak_path)
		if copy_err != OK:
			push_warning("Wallet: backup copy failed (%s)" % error_string(copy_err))
	var err := DirAccess.rename_absolute(tmp_path, wallet_path)
	if err != OK:
		push_warning("Wallet: cannot replace %s (%s)" % [wallet_path, error_string(err)])
		return false
	_wallet_dirty = false
	return true

## Tải ví: file chính -> file tạm -> bản dự phòng. Không có bản hợp lệ (save cũ chưa có ví / hỏng hết) -> 0.
## Không bao giờ cộng dồn từ lịch sử các lượt chơi.
func load_wallet() -> void:
	var balance := -1
	var source := ""
	for p in [wallet_path, wallet_path + ".tmp", wallet_path + ".bak"]:
		var v := read_wallet_file(p)
		if v >= 0:
			balance = v
			source = p
			break
		elif FileAccess.file_exists(p):
			push_warning("Wallet: ignoring invalid wallet file %s" % p)
	_wallet_balance = maxi(balance, 0)
	_wallet_dirty = false
	coins_changed.emit(_wallet_balance, 0)
	if source != "" and source != wallet_path:
		save_wallet()   # khôi phục file chính từ bản còn tốt

## Đọc + kiểm tra một file ví: trả về số dư hợp lệ (số nguyên, 0..MAX_COINS) hoặc -1 nếu thiếu / hỏng / sai kiểu.
static func read_wallet_file(path: String) -> int:
	if not FileAccess.file_exists(path):
		return -1
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	if file.get_length() <= 0 or file.get_length() > WALLET_MAX_FILE_BYTES:
		file.close()
		return -1
	var text := file.get_as_text()
	file.close()
	return parse_wallet_text(text)

static func parse_wallet_text(text: String) -> int:
	var json := JSON.new()
	if json.parse(text) != OK:
		return -1
	var parsed = json.data
	if not (parsed is Dictionary) or not parsed.has("coins"):
		return -1
	var v = parsed["coins"]
	if typeof(v) == TYPE_INT:
		return v if v >= 0 and v <= MAX_COINS else -1
	if typeof(v) == TYPE_FLOAT:
		var f: float = v
		if is_finite(f) and f == floorf(f) and f >= 0.0 and f <= float(MAX_COINS):
			return int(f)
	return -1

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		flush_wallet()   # thoát game bình thường: không mất các lần nhặt xu đang chờ lưu

## Tổng số xu một kẻ địch rơi ra (cố định theo seed + số kill nên replay / cùng seed cho cùng kết quả).
func roll_kill_coin_reward(reward_key: String, summoned: bool, rng: RandomNumberGenerator) -> int:
	if summoned:
		return BalanceData.COIN_SUMMONED_REWARD
	var r: Array = BalanceData.get_coin_reward(reward_key)
	var base: int = rng.randi_range(int(r[0]), int(r[1]))
	var mult: float = 1.0 + BalanceData.COIN_FLOOR_BONUS * float(maxi(0, current_level - 1))
	return maxi(1, int(round(float(base) * mult)))

func spawn_kill_coins(enemy: Node2D, reward_key: String) -> void:
	var parent: Node = enemy.get_parent()
	if parent == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|coins|%d" % [current_seed, enemies_killed])
	var summoned: bool = enemy.has_meta("summoned") and enemy.get_meta("summoned") == true
	var total: int = roll_kill_coin_reward(reward_key, summoned, rng)
	if total <= 0:
		return
	var max_pieces: int = MAX_BOSS_COIN_PIECES if BalanceData.is_boss_reward(reward_key) else MAX_COIN_PIECES
	var pieces: int = clampi(total, 1, max_pieces)
	@warning_ignore("integer_division")
	var each: int = total / pieces
	var extra: int = total % pieces
	var spawn_pos: Vector2 = enemy.global_position
	if parent is Node2D:
		spawn_pos = (parent as Node2D).to_local(enemy.global_position)
	for i in range(pieces):
		var coin: Node2D = COIN_PICKUP_SCRIPT.new()
		coin.name = "Coin"
		coin.setup(each + (1 if i < extra else 0), rng, run_id)
		coin.position = spawn_pos
		parent.call_deferred("add_child", coin, true)

func _play_coin_sfx() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am == null:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_coin_sfx_msec < 45:
		return
	_coin_sfx_streak = (_coin_sfx_streak + 1) if now - _last_coin_sfx_msec < 400 else 0
	_last_coin_sfx_msec = now
	var pitch: float = 1.05 + 0.04 * float(mini(_coin_sfx_streak, 10))
	am.play_sfx("pickup", pitch, pitch + 0.03)

func register_level_advance(new_level: int) -> void:
	current_level = maxi(1, new_level)
	stats_updated.emit(current_level, enemies_killed)
	flush_wallet()

func finish_run(reason: String = "Game Over") -> void:
	var hero_info := get_selected_character_info()
	var timestamp := Time.get_datetime_string_from_system(false, true)
	var entry := {
		"seed": current_seed,
		"hero_idx": selected_character_index,
		"hero_name": String(hero_info.get("name", "Hero")),
		"floor": current_level,
		"kills": enemies_killed,
		"coins": run_coins,   # xu nhặt trong lượt (đã vào ví lúc nhặt; KHÔNG cộng lại)
		"reason": sanitize_note(reason),
		"date": timestamp
	}
	if not is_replaying and not current_recording_frames.is_empty():
		last_recorded_run = entry.duplicate(true)
		last_recorded_run["frames"] = current_recording_frames.duplicate(true)
		entry["has_replay"] = true
		entry["frames"] = current_recording_frames.slice(0, mini(current_recording_frames.size(), MAX_DISK_REPLAY_FRAMES))
	else:
		entry["has_replay"] = false
		entry["frames"] = []

	run_history.push_front(entry)
	enforce_replay_limits()
	if run_history.size() > MAX_RUN_HISTORY:
		run_history.resize(MAX_RUN_HISTORY)
	save_data_to_disk()
	flush_wallet()
	saved_data_changed.emit()

# --- CƠ CHẾ GIỚI HẠN & GIẢI PHÓNG BỘ NHỚ REPLAY (ANTI-MEMORY LEAK / MULTIPLAYER READY) ---
func enforce_replay_limits() -> void:
	var replay_count := 0
	for item in run_history:
		if bool(item.get("has_replay", false)) and item.has("frames") and not item["frames"].is_empty():
			replay_count += 1
			if replay_count > MAX_SAVED_REPLAYS:
				# Thu hồi vùng nhớ các mảng frame của các replay cũ vượt quá giới hạn 10
				item["frames"].clear()
				item["has_replay"] = false

func delete_replay(run_entry: Dictionary) -> bool:
	for entry in run_history:
		if entry == run_entry or (entry.get("date") == run_entry.get("date") and entry.get("seed") == run_entry.get("seed")):
			if entry.has("frames") and entry["frames"] is Array:
				entry["frames"].clear()
			entry["has_replay"] = false
			if last_recorded_run.get("date") == entry.get("date"):
				last_recorded_run.clear()
			save_data_to_disk()
			saved_data_changed.emit()
			return true
	return false

func delete_run_history_entry(index: int) -> bool:
	if index >= 0 and index < run_history.size():
		var entry = run_history[index]
		if entry.has("frames") and entry["frames"] is Array:
			entry["frames"].clear()
		run_history.remove_at(index)
		save_data_to_disk()
		saved_data_changed.emit()
		return true
	return false

func clear_all_replays() -> void:
	for entry in run_history:
		if entry.has("frames") and entry["frames"] is Array:
			entry["frames"].clear()
		entry["has_replay"] = false
	last_recorded_run.clear()
	replay_frames.clear()
	current_recording_frames.clear()
	save_data_to_disk()
	saved_data_changed.emit()

func get_saved_replays_count() -> int:
	var count := 0
	for entry in run_history:
		if bool(entry.get("has_replay", false)) and not entry.get("frames", []).is_empty():
			count += 1
	return count

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
		"note": safe_note if not safe_note.is_empty() else ("Floor %d — %s" % [current_level, get_selected_character_info().get("name", "Hero")]),
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
					"coins": clampi(int(r.get("coins", 0)), 0, MAX_COINS),
					"reason": sanitize_note(String(r.get("reason", "Game Over"))),
					"date": sanitize_note(String(r.get("date", ""))),
					"has_replay": bool(r.get("has_replay", false)) and not safe_frames.is_empty(),
					"frames": safe_frames
				})
		enforce_replay_limits()
	if parsed.has("last_recorded_run") and parsed["last_recorded_run"] is Dictionary:
		var lr: Dictionary = parsed["last_recorded_run"]
		var lr_frames := _sanitize_replay_frames(lr.get("frames", []), MAX_REPLAY_FRAMES)
		last_recorded_run = {
			"seed": sanitize_seed(String(lr.get("seed", current_seed))),
			"hero_idx": clampi(int(lr.get("hero_idx", selected_character_index)), 0, CHARACTER_SCENES.size() - 1),
			"hero_name": sanitize_note(String(lr.get("hero_name", "Hero"))),
			"floor": clampi(int(lr.get("floor", 1)), 1, 9999),
			"kills": clampi(int(lr.get("kills", 0)), 0, 999999),
			"coins": clampi(int(lr.get("coins", 0)), 0, MAX_COINS),
			"frames": lr_frames
		}
