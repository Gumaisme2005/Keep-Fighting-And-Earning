extends "res://tests/tutorial_hall_test_support.gd"

func write(path: String, data: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(data)
	file.close()

func _ready() -> void:
	await ticks(2)
	var path := "user://task4_save_test.json"
	var original: Dictionary = {}
	for file in DirAccess.get_files_at("user://"):
		original[file] = FileAccess.get_file_as_bytes("user://" + file)
	var save := Save.new(path)
	check(not save.completed and save.last_error.is_empty(), "SAVE-01 missing file")
	for text in ["{", "[]", "null", '{}', '{"schema_version":1,"tutorial_version":1,"completed":"true"}', '{"schema_version":2,"tutorial_version":1,"completed":true}', '{"schema_version":1,"tutorial_version":2,"completed":true}']:
		write(path, text)
		save = Save.new(path)
		check(not save.completed and not save.last_error.is_empty(), "Reject damaged / unsupported save: " + text)
	check(save.mark_completed() and save.completed and save.writes == 1, "SAVE-03 safe replacement writes completion")
	var bytes := FileAccess.get_file_as_bytes(path)
	check(save.mark_completed() and save.writes == 1 and FileAccess.get_file_as_bytes(path) == bytes, "SAVE-08 idempotent duplicate write")
	var other := Save.new(path)
	check(other.completed and other.mark_completed() and other.writes == 0, "SAVE-02 multiple instance load / no duplicate write")
	var failed := Save.new("user://missing_parent/task4.json")
	check(not failed.mark_completed() and failed.completed and not failed.last_error.is_empty() and failed.writes == 0,
		"SAVE-07 write failure retains memory completion without claiming saved")
	var preserved := true
	for file in original:
		preserved = preserved and FileAccess.get_file_as_bytes("user://" + file) == original[file]
	check(preserved, "SAVE-12 production save bytes unchanged")
	for text in ['{"schema_version":true,"tutorial_version":1,"completed":true}', '{"schema_version":1.5,"tutorial_version":1,"completed":true}']:
		write(path, text)
		check(not Save.new(path).completed, "SAVE-05 version types are strict")
	write(path, "x".repeat(4097))
	check(not Save.new(path).completed, "SAVE corrupted oversized input is bounded")
	DirAccess.make_dir_recursive_absolute("user://save_target_directory")
	var replacement := Save.new("user://save_target_directory")
	check(not replacement.mark_completed() and replacement.completed and replacement.writes == 0 \
		and DirAccess.dir_exists_absolute("user://save_target_directory"), "SAVE replacement failure preserves target and reports failure")
	print("[TRACE] persistence missing/corrupt/types/version/atomic/idempotency/failure/isolation verified")
	finish("[TUTORIAL_PERSISTENCE_COMPLETE]")
