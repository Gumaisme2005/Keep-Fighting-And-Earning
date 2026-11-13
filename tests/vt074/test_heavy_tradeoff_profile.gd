extends Node
## Diagnostic first-COMMITTED scopes only; acceptance uses unchanged 40-task harness.
const F = preload("res://tests/vt074/quality_fixture.gd")
const Trace = preload("res://tests/vt074/profile_trace.gd")
var rows: Array = []
var failed := 0

func _ready() -> void:
	var scripts := {}
	for variant in ["original", "cached_copy", "cached_owned"]:
		scripts[variant] = load("res://tests/vt074/tradeoff_profile_%s.gd" % variant)
		if scripts[variant] == null or not scripts[variant].can_instantiate():
			push_error("Missing isolated profile script")
			get_tree().quit(2)
			return
	for frames in [2, 3600]:
		for iteration in range(35):
			var phase := "warmup" if iteration < 5 else "measured"
			var order := ["original", "cached_copy", "cached_owned"]
			if iteration % 2 == 1: order.reverse()
			var disk := ""
			for variant in order:
				var path := "user://tradeoff/profile/%d/%d/%s/save.json" % [frames, iteration, variant]
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
				var file := FileAccess.open(path, FileAccess.WRITE)
				file.store_string(JSON.stringify(F.Store.empty_snapshot()))
				file.close()
				var gm = scripts[variant].new()
				gm.completion_store = F.Store.new(path)
				gm.completion_clock = func(): return F.DATE
				gm.run_id_provider = func(): return "%016x%016x" % [9900 + frames, iteration + 1]
				add_child(gm)
				var signals := [0]
				var observer: Callable = func(): signals[0] += 1
				gm.saved_data_changed.connect(observer)
				var p := F.payload(frames)
				var started: bool = gm.start_new_run(p.seed, false, [])
				var begin := Time.get_ticks_usec()
				Trace.start()
				var result: Dictionary = gm.complete_run_request(gm.current_run_id, p)
				var finish := Time.get_ticks_usec()
				var spans := Trace.finish(finish)
				var correct: bool = started and result.status == "COMMITTED" and signals[0] == 1 and gm.completion_store.commits == 1
				correct = correct and gm.run_history.size() == 1 and gm.processed_ledger.size() == 1
				var hash := FileAccess.get_sha256(path)
				if disk.is_empty(): disk = hash
				correct = correct and disk == hash
				if not correct: failed += 1
				rows.append({"variant": variant, "frames": frames, "iteration": iteration, "phase": phase,
					"service_us": finish - begin, "spans": spans, "status": result.status,
					"disk_sha256": hash, "correctness_pass": correct})
				gm.saved_data_changed.disconnect(observer)
				F.dispose(gm)
				PerkManager.reset()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tradeoff/profile"))
	var output := FileAccess.open("user://tradeoff/profile/scopes.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(rows))
	output.close()
	print("[TRADEOFF PROFILE] ", JSON.stringify({"rows": rows.size(), "failed": failed,
		"warmup_per_variant_frames": 5, "measured_per_variant_frames": 30}))
	get_tree().quit(1 if failed else 0)
