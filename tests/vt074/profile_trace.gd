extends RefCounted
## Diagnostic only: loaded by instrumented copies, never by feature production.
## Nested elapsed wall time; self_us excludes measured children (not CPU cycles).
static var active := false
static var stack: Array = []
static var totals: Dictionary = {}

static func start() -> void:
	active = true
	stack = []
	totals = {}
	enter("request")

static func enter(label: String) -> void:
	if active:
		stack.append({"label": label, "start": Time.get_ticks_usec(), "children": 0})

static func record(label: String, elapsed: int, own: int) -> void:
	if not totals.has(label):
		totals[label] = {"inclusive_us": 0, "self_us": 0, "calls": 0}
	totals[label].inclusive_us += elapsed
	totals[label].self_us += own
	totals[label].calls += 1
	if not stack.is_empty():
		stack[-1].children += elapsed

static func leave(end_us: int = -1) -> void:
	if not active:
		return
	var now := Time.get_ticks_usec() if end_us < 0 else end_us
	var frame: Dictionary = stack.pop_back()
	var elapsed: int = now - frame.start
	record(frame.label, elapsed, elapsed - frame.children)

static func leaf(label: String, elapsed: int) -> void:
	if active:
		record(label, elapsed, elapsed)

static func copy_dict(value: Dictionary, label: String) -> Dictionary:
	enter(label)
	var result := value.duplicate(true)
	leave()
	return result

static func finish(end_us: int) -> Dictionary:
	leave(end_us)
	assert(stack.is_empty(), "Unbalanced diagnostic spans")
	active = false
	return totals
