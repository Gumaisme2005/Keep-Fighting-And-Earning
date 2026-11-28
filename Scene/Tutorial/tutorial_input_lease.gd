extends RefCounted
## Changes only processing modes and CanvasLayer visibility. No stat snapshots.
var records: Array[Dictionary] = []
var hall: Node
var owner: Node
var previous_focus: WeakRef
var mouse_mode: int
var actor_ref: WeakRef
var _tree: SceneTree

func acquire(scene: Node, host: Node) -> void:
	if not records.is_empty():
		return
	hall = scene
	owner = host
	_tree = hall.get_tree()
	actor_ref = weakref(hall.hero)
	hall.hero.set_meta("_tutorial_input_leased", true)
	var focus := host.get_viewport().gui_get_focus_owner()
	previous_focus = weakref(focus) if focus != null else null
	if focus != null:
		focus.release_focus()
	mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for child in hall.get_children():
		_freeze(child)
	_tree.node_added.connect(_on_added)

func _on_added(node: Node) -> void:
	if is_instance_valid(hall) and hall.is_ancestor_of(node):
		_freeze(node)

func _freeze(node: Node) -> void:
	if is_instance_valid(owner) and (node == owner or owner.is_ancestor_of(node)):
		return
	if records.any(func(record): return record.ref.get_ref() == node):
		return
	var record := {"ref": weakref(node), "mode": node.process_mode}
	if node is CanvasLayer:
		record["visible"] = node.visible
		node.visible = false
	records.append(record)
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_freeze(child)

func release() -> void:
	if is_instance_valid(_tree) and _tree.node_added.is_connected(_on_added):
		_tree.node_added.disconnect(_on_added)
	var actor = actor_ref.get_ref() if actor_ref != null else null
	for record in records:
		var node = record.ref.get_ref()
		if is_instance_valid(actor) and is_instance_valid(node) and (node == actor or actor.is_ancestor_of(node)) \
			and (not is_instance_valid(hall) or hall.hero != actor or not hall.is_ancestor_of(actor)):
			continue # a replaced/detached hero must not regain input authority
		if is_instance_valid(node) and not node.is_queued_for_deletion() and node.is_inside_tree():
			node.process_mode = record.mode
			if record.has("visible"):
				node.visible = record.visible
	if not records.is_empty():
		Input.mouse_mode = mouse_mode
	if is_instance_valid(actor): actor.remove_meta("_tutorial_input_leased")
	var focus = previous_focus.get_ref() if previous_focus != null else null
	if is_instance_valid(focus) and focus.is_inside_tree() and focus.is_visible_in_tree() and not focus.is_queued_for_deletion():
		focus.grab_focus()
	records.clear()
	hall = null
	owner = null
	actor_ref = null
	_tree = null
