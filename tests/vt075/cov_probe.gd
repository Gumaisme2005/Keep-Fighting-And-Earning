extends RefCounted
## Probe coverage (VT-075). Chi duoc dung boi ban instrument sinh ra bang tests/vt075/tools/coverage.py.
## Khong nam trong duong chay san pham.

static var _hits: Dictionary = {}
static var _mutex: Mutex = Mutex.new()

static func hit(line_no: int) -> void:
	_mutex.lock()
	_hits[line_no] = int(_hits.get(line_no, 0)) + 1
	_mutex.unlock()

static func dump() -> String:
	_mutex.lock()
	var s: String = JSON.stringify(_hits)
	_mutex.unlock()
	return s
