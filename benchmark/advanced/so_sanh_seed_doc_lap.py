# Chay trong thu muc goc du an sau khi da mo Godot 3 lan doc lap.
# Py -3 .\benchmark\advanced\so_sanh_seed_doc_lap.py
import csv
import glob
import os
import sys
from collections import Counter

DIRECTORY = os.path.join("benchmark", "advanced", "results")
files = sorted(glob.glob(os.path.join(DIRECTORY, "seed_replay_*.csv")), key=os.path.getmtime)
if len(files) < 3:
    print(f"CHUA DU: tim thay {len(files)} file; can it nhat 3 lan chay doc lap.")
    sys.exit(2)

# So sanh dung 3 file moi nhat, de tranh du lieu tu cac ban code cu.
files = files[-3:]
required = {"schema", "run_id", "godot_version", "generator_sha256", "rooms", "trial", "seed", "room_count", "layer_count", "geometry_sha256", "tilemap_sha256", "full_sha256"}
sets = []
errors = []
for path in files:
    with open(path, encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        if not required.issubset(reader.fieldnames or []):
            errors.append(f"Sai cot CSV: {os.path.basename(path)}")
            continue
        rows = list(reader)
    key_rows = {}
    for r in rows:
        key = (r["rooms"], r["seed"])
        if key in key_rows:
            errors.append(f"Trung seed: {os.path.basename(path)} {key}")
        key_rows[key] = r
    if len(rows) != 200 or len(key_rows) != 200:
        errors.append(f"Sai so dong: {os.path.basename(path)} ({len(rows)} dong, {len(key_rows)} seed duy nhat)")
    expected = {(str(n), f"STRESS_SEED_{i:05d}") for n in (16, 32) for i in range(100)}
    if set(key_rows) != expected:
        errors.append(f"Tap seed/cau hinh khong dung: {os.path.basename(path)}")
    for r in rows:
        if r["room_count"] != r["rooms"]:
            errors.append(f"Sai so phong: {os.path.basename(path)} {r['rooms']}/{r['seed']}")
            break
    sets.append((path, key_rows))

if len(sets) != 3 or errors:
    print("KHONG THE KET LUAN DO DU LIEU KHONG HOP LE:")
    print("\n".join(errors[:20]))
    sys.exit(3)

runs = [next(iter(rows.values()))["run_id"] for _, rows in sets]
versions = {next(iter(rows.values()))["godot_version"] for _, rows in sets}
gen_hashes = {next(iter(rows.values()))["generator_sha256"] for _, rows in sets}
if len(set(runs)) != 3:
    errors.append("Ba file khong den tu 3 tien trinh chay rieng biet")
if len(versions) != 1:
    errors.append("Godot version khac nhau giua cac lan chay")
if len(gen_hashes) != 1 or "" in gen_hashes:
    errors.append("Ma nguon generator khac nhau hoac khong tim thay hash script")

base = sets[0][1]
mismatch = []
for path, rows in sets[1:]:
    for key in sorted(base):
        for c in ("geometry_sha256", "tilemap_sha256", "full_sha256", "layer_count"):
            if base[key][c] != rows[key][c]:
                mismatch.append((os.path.basename(path), key[0], key[1], c))

print("SO SANH SEED QUA 3 LAN MO GODOT DOC LAP")
for path, _ in sets:
    print("-", os.path.basename(path))
print("So seed/cau hinh moi lan: 16 phong = 100; 32 phong = 100")
print("So luot doi chieu: 400 (2 cap lan chay x 200 seed)")
print("Sai khac checksum/so lop:", len(mismatch))
if mismatch:
    for x in mismatch[:20]:
        print("KHAC:", *x)
if errors:
    print("LOI MOI TRUONG:")
    for e in errors:
        print("-", e)
if not errors and not mismatch:
    print("DAT: 200/200 seed cho ra cung hinh hoc va TileMap tren ca 3 lan khoi dong Godot.")
    sys.exit(0)
print("CHUA DAT: can xem lai sai khac hoac moi truong truoc khi ket luan.")
sys.exit(1)
