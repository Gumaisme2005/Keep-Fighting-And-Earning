extends RefCounted
## Giữ nguyên file save thật của người chơi khi chạy test (run_tests.bat chạy trên thư mục user:// thật,
## còn CI thì dùng XDG_DATA_HOME dùng một lần). Cách dùng, giống test_bug_bash_regressions.gd:
##   var save_guard = SaveGuard.new()   # chụp lại GameManager.SAVE_FILE_PATH trước khi test ghi gì
##   ...                                 # save_seed_entry(), finish_run() (nhân vật gục)... có thể ghi file
##   save_guard.restore()                # ghi lại đúng nội dung cũ, hoặc xoá nếu trước đó chưa có file
## Dữ liệu trong bộ nhớ (seed đã lưu, lịch sử run, replay cuối) cũng được trả về như cũ.

var had_save := false
var save_bytes := PackedByteArray()
var saved_seeds: Array = []
var run_history: Array = []
var last_recorded_run: Dictionary = {}

func _init() -> void:
	had_save = FileAccess.file_exists(GameManager.SAVE_FILE_PATH)
	save_bytes = FileAccess.get_file_as_bytes(GameManager.SAVE_FILE_PATH) if had_save else PackedByteArray()
	saved_seeds = GameManager.saved_seeds.duplicate(true)
	run_history = GameManager.run_history.duplicate(true)
	last_recorded_run = GameManager.last_recorded_run.duplicate(true)

func restore() -> void:
	GameManager.saved_seeds = saved_seeds.duplicate(true)
	GameManager.run_history = run_history.duplicate(true)
	GameManager.last_recorded_run = last_recorded_run.duplicate(true)
	if had_save:
		var f := FileAccess.open(GameManager.SAVE_FILE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_buffer(save_bytes)
			f.close()
	elif FileAccess.file_exists(GameManager.SAVE_FILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameManager.SAVE_FILE_PATH))

## true nếu file save giống hệt lúc chụp (để test tự kiểm tra là đã dọn sạch).
func is_restored() -> bool:
	if not had_save:
		return not FileAccess.file_exists(GameManager.SAVE_FILE_PATH)
	return FileAccess.file_exists(GameManager.SAVE_FILE_PATH) and FileAccess.get_file_as_bytes(GameManager.SAVE_FILE_PATH) == save_bytes
