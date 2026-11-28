extends RefCounted
## Separate, versioned completion only. Never reads or changes run/Wallet files.
const PATH := "user://tutorial_progress.json"
const SCHEMA := 1
const VERSION := 1
static var memory_completed := false
var path: String
var completed := false
var last_error := ""
var writes := 0

static func _parse(content: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(content) == OK else null

static func _supported(value: Variant) -> bool:
	return value is Dictionary and typeof(value.get("schema_version")) in [TYPE_INT, TYPE_FLOAT] \
		and typeof(value.get("tutorial_version")) in [TYPE_INT, TYPE_FLOAT] \
		and value.schema_version == SCHEMA and value.tutorial_version == VERSION and value.get("completed") is bool

func _init(save_path: String = PATH) -> void:
	path = save_path
	load_progress()

func load_progress() -> void:
	completed = memory_completed if path == PATH else false
	last_error = ""
	var value: Variant = _read_value()
	if value == null and last_error.is_empty(): return
	if not _supported(value):
		last_error = "Unsupported or damaged tutorial save."
		return
	completed = completed or value.completed
	if path == PATH:
		memory_completed = completed

func _read_value() -> Variant:
	if not FileAccess.file_exists(path): return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "Cannot read tutorial save."
		return null
	if file.get_length() > 4096:
		file.close()
		last_error = "Tutorial save exceeds size limit."
		return null
	var content := file.get_as_text()
	file.close()
	var value: Variant = _parse(content)
	if not _supported(value):
		last_error = "Unsupported or damaged tutorial save."
	return value

func mark_completed() -> bool:
	completed = true
	if path == PATH:
		memory_completed = true
	# Re-read to avoid duplicate writes by another live persistence instance.
	var existing: Variant = _read_value()
	if _supported(existing) and existing.completed:
		last_error = ""
		return true
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "Cannot open tutorial save: " + error_string(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify({"schema_version": SCHEMA, "tutorial_version": VERSION, "completed": true}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if error != OK:
		last_error = "Cannot replace tutorial save: " + error_string(error)
		return false
	writes += 1
	last_error = ""
	return true
