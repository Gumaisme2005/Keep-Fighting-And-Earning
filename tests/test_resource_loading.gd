extends SceneTree
## Load every gameplay/test/benchmark script and resource; instantiate scenes detached.
## Run: godot --headless --path . --script res://tests/test_resource_loading.gd
## Detached scenes do not execute _ready or represent an interactive playthrough.

var checked: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for folder in ["res://scenes", "res://scripts", "res://tests", "res://benchmarks"]:
		_scan(folder)
	print("[SUMMARY] RESOURCE LOADING: %d checked | %d failed" % [checked, failures])
	quit(0 if failures == 0 else 1)

func _scan(folder: String) -> void:
	var directory: DirAccess = DirAccess.open(folder)
	if directory == null:
		failures += 1
		printerr("[FAIL] Cannot open ", folder)
		return
	for child in directory.get_directories():
		if child not in ["results", "reports", "_cov", "_mutant", "backups"]:
			_scan(folder.path_join(child))
	for file in directory.get_files():
		if file.get_extension() not in ["gd", "tscn", "tres"]:
			continue
		checked += 1
		var path: String = folder.path_join(file)
		var resource: Resource = load(path)
		if resource == null or (resource is Script and not resource.can_instantiate()):
			failures += 1
			printerr("[FAIL] Cannot load/compile ", path)
		elif resource is PackedScene:
			var instance: Node = resource.instantiate()
			if instance == null:
				failures += 1
				printerr("[FAIL] Cannot instantiate ", path)
			else:
				instance.free()
