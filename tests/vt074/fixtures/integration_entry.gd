extends Node
## Fail setup promptly if the child test script failed to parse.
func _ready() -> void:
	if $Runner.get_script() == null:
		printerr("[SETUP ERROR] integration script could not be loaded; no behavioral assertions executed")
		get_tree().quit(2)
