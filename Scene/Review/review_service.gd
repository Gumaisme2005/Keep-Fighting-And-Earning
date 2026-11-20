extends RefCounted
## ReviewService (VT-075) - vai tro reviewer: doc + phe duyet, khong sua du lieu goc.
## Ban v1: moi API ghi (add_record/update_note/remove_record/approve) chay tron ven trong MOT vung
## khoa (chuoi "doc -> kiem tra -> luu -> commit" la nguyen tu). Mutex cua Godot la recursive nen cac
## accessor khoa long ben trong van an toan. Moi nhanh tra ve deu di qua wrapper nen luon nha khoa.
##
## Hop dong: INV-1 approval ton tai => approval.revision == record.revision (toi da 1 approval/record);
##           INV-2 reviewer khong bao gio thay doi record goc.

const GameManagerScript = preload("res://Scene/GameManager.gd")

const ROLE_PLAYER: String = "player"
const ROLE_REVIEWER: String = "reviewer"

const OK: String = "OK"
const ERR_FORBIDDEN: String = "FORBIDDEN"
const ERR_NOT_FOUND: String = "NOT_FOUND"
const ERR_DUPLICATE: String = "DUPLICATE"
const ERR_INVALID_INPUT: String = "INVALID_INPUT"
const ERR_ALREADY_APPROVED: String = "ALREADY_APPROVED"
const ERR_STALE_REVISION: String = "STALE_REVISION"
const ERR_PERSIST_FAILED: String = "PERSIST_FAILED"

const MAX_RECORDS: int = 500

## Callable tra ve bool (true = luu thanh cong). Mo phong buoc ghi dia truoc khi commit.
var persist_hook: Callable = Callable()

var _mutex: Mutex = Mutex.new()
var _records: Dictionary = {}
var _approvals: Dictionary = {}
var _audit: Array = []

static func _result(code: String, revision: int = 0) -> Dictionary:
	return {"ok": code == OK, "code": code, "revision": revision}

static func _is_known_role(role: String) -> bool:
	return role == ROLE_PLAYER or role == ROLE_REVIEWER

static func _valid_id(raw: String) -> bool:
	if raw.is_empty():
		return false
	return GameManagerScript.sanitize_seed(raw) == raw

func _persist() -> bool:
	if not persist_hook.is_valid():
		return true
	return bool(persist_hook.call())

# --- accessor co khoa rieng le (v0) ---

func _read_record(id: String) -> Dictionary:
	_mutex.lock()
	var rec: Dictionary = {}
	if _records.has(id):
		rec = (_records[id] as Dictionary).duplicate(true)
	_mutex.unlock()
	return rec

func _has_record(id: String) -> bool:
	_mutex.lock()
	var found: bool = _records.has(id)
	_mutex.unlock()
	return found

func _record_count() -> int:
	_mutex.lock()
	var n: int = _records.size()
	_mutex.unlock()
	return n

func _write_record(rec: Dictionary) -> void:
	_mutex.lock()
	_records[rec["id"]] = rec.duplicate(true)
	_mutex.unlock()

func _delete_record(id: String) -> void:
	_mutex.lock()
	_records.erase(id)
	_approvals.erase(id)
	_mutex.unlock()

func _has_approval(id: String) -> bool:
	_mutex.lock()
	var found: bool = _approvals.has(id)
	_mutex.unlock()
	return found

func _put_approval(id: String, approval: Dictionary) -> void:
	_mutex.lock()
	_approvals[id] = approval.duplicate(true)
	_audit.append({"event": "approve", "id": id, "revision": approval["revision"], "reviewer": approval["reviewer"]})
	_mutex.unlock()

func _erase_approval(id: String) -> void:
	_mutex.lock()
	_approvals.erase(id)
	_mutex.unlock()

# --- API doc (reviewer + player) ---

func list_records(role: String) -> Dictionary:
	if not _is_known_role(role):
		return _result(ERR_FORBIDDEN)
	_mutex.lock()
	var ids: Array = _records.keys()
	ids.sort()
	var out: Array = []
	for id in ids:
		out.append((_records[id] as Dictionary).duplicate(true))
	_mutex.unlock()
	var res: Dictionary = _result(OK)
	res["records"] = out
	return res

func get_record(role: String, record_id: String) -> Dictionary:
	if not _is_known_role(role):
		return _result(ERR_FORBIDDEN)
	if not _valid_id(record_id):
		return _result(ERR_INVALID_INPUT)
	_mutex.lock()
	var found: bool = _records.has(record_id)
	var rec: Dictionary = {}
	var approval: Dictionary = {}
	if found:
		rec = (_records[record_id] as Dictionary).duplicate(true)
		if _approvals.has(record_id):
			approval = (_approvals[record_id] as Dictionary).duplicate(true)
	_mutex.unlock()
	if not found:
		return _result(ERR_NOT_FOUND)
	var res: Dictionary = _result(OK, int(rec["revision"]))
	res["record"] = rec
	res["approval"] = approval
	return res

func get_audit_log(role: String) -> Dictionary:
	if not _is_known_role(role):
		return _result(ERR_FORBIDDEN)
	_mutex.lock()
	var copy: Array = _audit.duplicate(true)
	_mutex.unlock()
	var res: Dictionary = _result(OK)
	res["events"] = copy
	return res

# --- API ghi (chi player) ---

func add_record(role: String, record_id: String, seed_text: String, note: String) -> Dictionary:
	_mutex.lock()
	var res: Dictionary = _add_record_locked(role, record_id, seed_text, note)
	_mutex.unlock()
	return res

func _add_record_locked(role: String, record_id: String, seed_text: String, note: String) -> Dictionary:
	if role != ROLE_PLAYER:
		return _result(ERR_FORBIDDEN)
	if not _valid_id(record_id):
		return _result(ERR_INVALID_INPUT)
	var clean_seed: String = GameManagerScript.sanitize_seed(seed_text)
	if clean_seed.is_empty():
		return _result(ERR_INVALID_INPUT)
	if _has_record(record_id):
		return _result(ERR_DUPLICATE)
	if _record_count() >= MAX_RECORDS:
		return _result(ERR_INVALID_INPUT)
	var rec: Dictionary = {"id": record_id, "seed": clean_seed, "note": GameManagerScript.sanitize_note(note), "revision": 1}
	if not _persist():
		return _result(ERR_PERSIST_FAILED)
	_write_record(rec)
	return _result(OK, 1)

func update_note(role: String, record_id: String, note: String) -> Dictionary:
	_mutex.lock()
	var res: Dictionary = _update_note_locked(role, record_id, note)
	_mutex.unlock()
	return res

func _update_note_locked(role: String, record_id: String, note: String) -> Dictionary:
	if role != ROLE_PLAYER:
		return _result(ERR_FORBIDDEN)
	if not _valid_id(record_id):
		return _result(ERR_INVALID_INPUT)
	var rec: Dictionary = _read_record(record_id)
	if rec.is_empty():
		return _result(ERR_NOT_FOUND)
	rec["note"] = GameManagerScript.sanitize_note(note)
	rec["revision"] = int(rec["revision"]) + 1
	if not _persist():
		return _result(ERR_PERSIST_FAILED)
	_write_record(rec)
	_erase_approval(record_id)
	return _result(OK, int(rec["revision"]))

func remove_record(role: String, record_id: String) -> Dictionary:
	_mutex.lock()
	var res: Dictionary = _remove_record_locked(role, record_id)
	_mutex.unlock()
	return res

func _remove_record_locked(role: String, record_id: String) -> Dictionary:
	if role != ROLE_PLAYER:
		return _result(ERR_FORBIDDEN)
	if not _valid_id(record_id):
		return _result(ERR_INVALID_INPUT)
	if not _has_record(record_id):
		return _result(ERR_NOT_FOUND)
	if not _persist():
		return _result(ERR_PERSIST_FAILED)
	_delete_record(record_id)
	return _result(OK)

## Nap ban ghi tu cau truc GameManager.run_history (khong sua mang dau vao).
func import_run_history(role: String, history: Array) -> Dictionary:
	if role != ROLE_PLAYER:
		return _result(ERR_FORBIDDEN)
	var imported: int = 0
	for i in range(mini(history.size(), GameManagerScript.MAX_RUN_HISTORY)):
		var entry: Variant = history[i]
		if not (entry is Dictionary):
			continue
		var note: String = "Tang %s - %s" % [str(entry.get("floor", 1)), str(entry.get("reason", ""))]
		var res: Dictionary = add_record(role, "run-%d" % i, str(entry.get("seed", "")), note)
		if res["ok"]:
			imported += 1
	var out: Dictionary = _result(OK)
	out["imported"] = imported
	return out

# --- API phe duyet (chi reviewer) ---

func approve(role: String, reviewer_id: String, record_id: String, expected_revision: int) -> Dictionary:
	_mutex.lock()
	var res: Dictionary = _approve_locked(role, reviewer_id, record_id, expected_revision)
	_mutex.unlock()
	return res

func _approve_locked(role: String, reviewer_id: String, record_id: String, expected_revision: int) -> Dictionary:
	if role != ROLE_REVIEWER:
		return _result(ERR_FORBIDDEN)
	if not _valid_id(reviewer_id) or not _valid_id(record_id) or expected_revision < 1:
		return _result(ERR_INVALID_INPUT)
	var rec: Dictionary = _read_record(record_id)
	if rec.is_empty():
		return _result(ERR_NOT_FOUND)
	if _has_approval(record_id):
		return _result(ERR_ALREADY_APPROVED, int(rec["revision"]))
	if int(rec["revision"]) != expected_revision:
		return _result(ERR_STALE_REVISION, int(rec["revision"]))
	if not _persist():
		return _result(ERR_PERSIST_FAILED, expected_revision)
	_put_approval(record_id, {"reviewer": reviewer_id, "revision": expected_revision})
	return _result(OK, expected_revision)
