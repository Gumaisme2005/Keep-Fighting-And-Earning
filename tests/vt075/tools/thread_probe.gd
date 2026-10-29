extends SceneTree
# VT-075 plan-review probe (assumption A4): Thread/Mutex/Semaphore work in --headless
# and 120 gated threads really contend. Run:
#   godot --headless --script res://tests/vt075/tools/thread_probe.gd

const N := 120

var _gate := Semaphore.new()
var _mutex := Mutex.new()
var _counter_unsafe := 0
var _counter_safe := 0

func _worker() -> void:
	_gate.wait()
	for i in range(2000):
		var v := _counter_unsafe
		_counter_unsafe = v + 1
		_mutex.lock()
		_counter_safe += 1
		_mutex.unlock()

func _init() -> void:
	var threads: Array[Thread] = []
	for i in range(N):
		var t := Thread.new()
		t.start(_worker)
		threads.append(t)
	for i in range(N):
		_gate.post()
	for t in threads:
		t.wait_to_finish()
	print("threads=%d expected=%d unsafe_counter=%d safe_counter=%d" % [N, N * 2000, _counter_unsafe, _counter_safe])
	print("lost_updates_without_lock=%d" % (N * 2000 - _counter_unsafe))
	quit(0)

