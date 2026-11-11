#!/usr/bin/env python3
"""VT-075 mutation experiment: "bo mot validation quan trong" (+ vai mutant doi chung).

Moi mutant la mot ban sao cua Scene/Review/review_service.gd da bi sua dung 1 cho
(ghi vao tests/vt075/_mutant/, bi gitignore) va duoc test bang bien moi truong
VT075_SERVICE_PATH. File that khong bao gio bi sua. Mutant 'killed' neu suite exit != 0.

Chay:  python tests/vt075/tools/mutation_run.py [--only M1,M3] [--out docs/vt075/evidence/03_mutation_results.md]
"""
import argparse, os, re, subprocess, sys, json

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SERVICE = os.path.join(ROOT, "Scene", "Review", "review_service.gd")
MUT_DIR = os.path.join(ROOT, "tests", "vt075", "_mutant")
GODOT = os.environ.get("GODOT_BIN", r"B:\EnvironmentDev\Godot\Godot_v4.7.2-stable_win64_console.exe")
SCENE = "res://tests/test_reviewer_concurrency.tscn"

# (id, loai, mo ta, old, new)
MUTANTS = [
    ("M1", "validation", "update_note: bo kiem tra role (reviewer sua duoc du lieu goc)",
     'func _update_note_locked(role: String, record_id: String, note: String) -> Dictionary:\n\tif role != ROLE_PLAYER:\n\t\treturn _result(ERR_FORBIDDEN)\n',
     'func _update_note_locked(role: String, record_id: String, note: String) -> Dictionary:\n'),
    ("M2", "validation", "approve: bo kiem tra revision (STALE_REVISION)",
     '\tif int(rec["revision"]) != expected_revision:\n\t\treturn _result(ERR_STALE_REVISION, int(rec["revision"]))\n', ''),
    ("M3", "validation", "approve: bo kiem tra ALREADY_APPROVED",
     '\tif _has_approval(record_id):\n\t\treturn _result(ERR_ALREADY_APPROVED, int(rec["revision"]))\n', ''),
    ("M4", "validation", "get_record: bo deny-by-default cho role la",
     'func get_record(role: String, record_id: String) -> Dictionary:\n\tif not _is_known_role(role):\n\t\treturn _result(ERR_FORBIDDEN)\n',
     'func get_record(role: String, record_id: String) -> Dictionary:\n'),
    ("M5", "validation", "approve: bo validate reviewer_id",
     'if not _valid_id(reviewer_id) or not _valid_id(record_id) or expected_revision < 1:',
     'if not _valid_id(record_id) or expected_revision < 1:'),
    ("M6", "validation", "approve: bo kiem tra expected_revision >= 1",
     'if not _valid_id(reviewer_id) or not _valid_id(record_id) or expected_revision < 1:',
     'if not _valid_id(reviewer_id) or not _valid_id(record_id):'),
    ("M7", "invariant", "update_note: khong thu hoi approval khi sua",
     '\t_erase_approval(record_id)\n\treturn _result(OK, int(rec["revision"]))', '\treturn _result(OK, int(rec["revision"]))'),
    ("M8", "concurrency", "approve: bo Mutex quanh chuoi check-then-act",
     'func approve(role: String, reviewer_id: String, record_id: String, expected_revision: int) -> Dictionary:\n\t_mutex.lock()\n\tvar res: Dictionary = _approve_locked(role, reviewer_id, record_id, expected_revision)\n\t_mutex.unlock()\n\treturn res',
     'func approve(role: String, reviewer_id: String, record_id: String, expected_revision: int) -> Dictionary:\n\tvar res: Dictionary = _approve_locked(role, reviewer_id, record_id, expected_revision)\n\treturn res'),
    ("M9", "validation", "update_note: bo sanitize_note (ghi chu khong duoc lam sach)",
     'rec["note"] = GameManagerScript.sanitize_note(note)', 'rec["note"] = note'),
    ("M10", "validation", "add_record: bo gioi han MAX_RECORDS",
     '\tif _record_count() >= MAX_RECORDS:\n\t\treturn _result(ERR_INVALID_INPUT)\n', ''),
    ("M11", "validation", "_valid_id luon tra true (bo validate id)",
     'return GameManagerScript.sanitize_seed(raw) == raw', 'return true'),
    ("M12", "isolation", "get_record: tra tham chieu noi bo thay vi ban sao",
     'rec = (_records[record_id] as Dictionary).duplicate(true)\n\t\tif _approvals.has(record_id):',
     'rec = _records[record_id]\n\t\tif _approvals.has(record_id):'),
    ("M13", "validation", "add_record: bo kiem tra DUPLICATE",
     '\tif _has_record(record_id):\n\t\treturn _result(ERR_DUPLICATE)\n', ''),
    ("M19", "validation", "add_record: bo sanitize_note khi tao ban ghi",
     '"note": GameManagerScript.sanitize_note(note), "revision": 1}', '"note": note, "revision": 1}'),
    ("M14", "validation", "approve: bo kiem tra role reviewer (player duyet duoc)",
     'func _approve_locked(role: String, reviewer_id: String, record_id: String, expected_revision: int) -> Dictionary:\n\tif role != ROLE_REVIEWER:\n\t\treturn _result(ERR_FORBIDDEN)\n',
     'func _approve_locked(role: String, reviewer_id: String, record_id: String, expected_revision: int) -> Dictionary:\n'),
    ("M15", "failure-path", "approve: bo qua ket qua luu that bai",
     '\tif not _persist():\n\t\treturn _result(ERR_PERSIST_FAILED, expected_revision)\n', '\t_persist()\n'),
    ("M16", "validation", "add_record: bo kiem tra seed rong sau khi lam sach",
     '\tif clean_seed.is_empty():\n\t\treturn _result(ERR_INVALID_INPUT)\n', ''),
    ("M17", "validation", "remove_record: bo kiem tra role (reviewer xoa duoc)",
     'func _remove_record_locked(role: String, record_id: String) -> Dictionary:\n\tif role != ROLE_PLAYER:\n\t\treturn _result(ERR_FORBIDDEN)\n',
     'func _remove_record_locked(role: String, record_id: String) -> Dictionary:\n'),
    ("M18", "validation", "add_record: bo kiem tra role (reviewer them duoc)",
     'func _add_record_locked(role: String, record_id: String, seed_text: String, note: String) -> Dictionary:\n\tif role != ROLE_PLAYER:\n\t\treturn _result(ERR_FORBIDDEN)\n',
     'func _add_record_locked(role: String, record_id: String, seed_text: String, note: String) -> Dictionary:\n'),
]


def read_service():
    with open(SERVICE, "r", encoding="utf-8", newline=None) as f:
        return f.read()


def run_mutant(mid, src, old, new):
    if src.count(old) != 1:
        return {"id": mid, "error": "pattern found %d times (expected 1)" % src.count(old)}
    os.makedirs(MUT_DIR, exist_ok=True)
    path = os.path.join(MUT_DIR, "%s.gd" % mid.lower())
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(src.replace(old, new))
    env = dict(os.environ, VT075_SERVICE_PATH="res://tests/vt075/_mutant/%s.gd" % mid.lower())
    try:
        p = subprocess.run([GODOT, "--headless", SCENE], cwd=ROOT, env=env, capture_output=True, text=True,
                           timeout=120, encoding="utf-8", errors="replace")
        out, code = p.stdout + p.stderr, p.returncode
    except subprocess.TimeoutExpired as e:
        out, code = (e.stdout or "") if isinstance(e.stdout, str) else "", -9
    failed = re.findall(r"\[FAIL\] (TC-[0-9a-z]+|GUARD)", out)
    parse_err = "SCRIPT ERROR" in out or "Parse Error" in out
    return {"id": mid, "exit": code, "killed": code != 0, "failed_tests": sorted(set(failed)), "parse_error": parse_err}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    only = set(x for x in a.only.split(",") if x)
    src = read_service()
    rows = []
    for mid, kind, desc, old, new in MUTANTS:
        if only and mid not in only:
            continue
        r = run_mutant(mid, src, old, new)
        r.update(kind=kind, desc=desc)
        rows.append(r)
        status = "KILLED" if r.get("killed") else ("ERROR" if "error" in r else "SURVIVED")
        print("%-4s %-12s %-9s %s | %s" % (mid, kind, status, desc, ",".join(r.get("failed_tests", []))), flush=True)
    killed = sum(1 for r in rows if r.get("killed"))
    total = len(rows)
    print("\nMutation score: %d/%d killed (%.0f%%)" % (killed, total, 100.0 * killed / max(total, 1)))
    if a.out:
        with open(os.path.join(ROOT, a.out), "w", encoding="utf-8", newline="\n") as f:
            f.write("| Mutant | Loai | Mo ta | Ket qua | Test phat hien |\n|---|---|---|---|---|\n")
            for r in rows:
                st = "KILLED" if r.get("killed") else ("ERROR" if "error" in r else "SURVIVED")
                f.write("| %s | %s | %s | %s | %s |\n" % (r["id"], r["kind"], r["desc"], st, ", ".join(r.get("failed_tests", [])) or "-"))
            f.write("\nMutation score: %d/%d (%.0f%%)\n" % (killed, total, 100.0 * killed / max(total, 1)))
        with open(os.path.join(ROOT, a.out.replace(".md", ".json")), "w", encoding="utf-8", newline="\n") as f:
            json.dump(rows, f, indent=1)
    sys.exit(0)


if __name__ == "__main__":
    main()
