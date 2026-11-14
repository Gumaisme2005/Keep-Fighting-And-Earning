extends Node
## Normal project autoload context plus prompt setup failure for dynamic suites.
func _ready() -> void:
	if OS.get_user_data_dir().replace("\\", "/") != OS.get_environment("VT074_EXPECT_USER_DIR").replace("\\", "/"):
		printerr("[SETUP ERROR] verified isolated quality runner required")
		get_tree().quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--suite=res://tests/vt074/"):
			var script = load(arg.trim_prefix("--suite="))
			if script == null or not script.can_instantiate():
				printerr("[SETUP ERROR] quality script cannot instantiate")
				get_tree().quit(2)
				return
			add_child(script.new())
			return
	printerr("[SETUP ERROR] missing quality suite")
	get_tree().quit(2)
