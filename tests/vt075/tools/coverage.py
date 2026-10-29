#!/usr/bin/env python3
"""VT-075 coverage: Godot khong co cong cu coverage cho GDScript (godot --help khong co co coverage),
nen script nay INSTRUMENT ban sao cua Scene/Review/review_service.gd (chen CovProbe.hit(N) truoc moi
dong lenh), chay test tren ban sao do va tinh:
  - line coverage: dong lenh duoc thuc thi / tong dong lenh trong than ham
  - arm (branch) coverage: voi moi if/elif: nhanh dung (than if) va nhanh sai (else/elif tiep theo,
    hoac dong sau khoi neu than ket thuc bang return/continue/break)
Gioi han: khong do duoc short-circuit cua 'or'/'and' trong mot dieu kien, khong do duoc giua cac vong lap.

Chay: python tests/vt075/tools/coverage.py [--only TC-01,TC-02,...] [--out file.md]
"""
import argparse, json, os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SERVICE = os.path.join(ROOT, "Scene", "Review", "review_service.gd")
COV_DIR = os.path.join(ROOT, "tests", "vt075", "_cov")
GODOT = os.environ.get("GODOT_BIN", r"B:\EnvironmentDev\Godot\Godot_v4.7.2-stable_win64_console.exe")
SCENE = "res://tests/test_reviewer_concurrency.tscn"


def indent_of(line):
    return len(line) - len(line.lstrip("\t"))


def analyse(lines):
    """Tra ve (stmt_lines, arms). Chi so dong la 1-based."""
    in_func = False
    stmts = []
    for i, raw in enumerate(lines, 1):
        s = raw.strip()
        if raw.startswith(("func ", "static func ")):
            in_func = True
            continue
        if indent_of(raw) == 0 and s and not s.startswith("#"):
            if not raw.startswith(("func ", "static func ")):
                in_func = False
            continue
        if not in_func or not s or s.startswith("#"):
            continue
        if s.startswith(("else:", "elif ")):
            continue  # header khong thuc thi rieng; than khoi duoc chen probe
        stmts.append(i)
    stmt_set = set(stmts)

    def first_body(i):
        ind = indent_of(lines[i - 1])
        for j in range(i + 1, len(lines) + 1):
            s = lines[j - 1].strip()
            if not s or s.startswith("#"):
                continue
            return j if indent_of(lines[j - 1]) > ind else None
        return None

    def block_end(i):
        ind = indent_of(lines[i - 1])
        last = i
        for j in range(i + 1, len(lines) + 1):
            s = lines[j - 1].strip()
            if not s or s.startswith("#"):
                continue
            if indent_of(lines[j - 1]) <= ind:
                break
            last = j
        return last

    def next_stmt_after(end, ind):
        for j in range(end + 1, len(lines) + 1):
            s = lines[j - 1].strip()
            if not s or s.startswith("#"):
                continue
            if indent_of(lines[j - 1]) < ind:
                return None
            if j in stmt_set or s.startswith(("else:", "elif ")):
                return j
            return j
        return None

    arms = []  # {"line", "kind": true|false, "probe": line, "exact": bool}
    for i in stmts:
        s = lines[i - 1].strip()
        if not s.startswith("if "):
            continue
        ind = indent_of(lines[i - 1])
        tb = first_body(i)
        if tb is not None:
            arms.append({"line": i, "kind": "true", "probe": tb, "exact": True})
        end = block_end(i)
        # nhanh sai: tim else/elif cung muc thut le ngay sau khoi
        nxt = None
        for j in range(end + 1, len(lines) + 1):
            t = lines[j - 1].strip()
            if not t or t.startswith("#"):
                continue
            if indent_of(lines[j - 1]) == ind and t.startswith(("else:", "elif ")):
                nxt = j
            break
        if nxt is not None:
            body = first_body(nxt)
            arms.append({"line": i, "kind": "false", "probe": body, "exact": True})
        else:
            last_stmt = lines[end - 1].strip()
            ends_jump = last_stmt.startswith(("return", "continue", "break"))
            after = next_stmt_after(end, ind)
            if after is not None:
                arms.append({"line": i, "kind": "false", "probe": after, "exact": ends_jump})
    return stmts, arms


def instrument(src_lines, stmts):
    out = []
    stmt_set = set(stmts)
    for i, raw in enumerate(src_lines, 1):
        if i == 1:
            out.append(raw)
            out.append('const CovProbe = preload("res://tests/vt075/cov_probe.gd")')
            continue
        if i in stmt_set:
            out.append("\t" * indent_of(raw) + "CovProbe.hit(%d)" % i)
        out.append(raw)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    with open(SERVICE, "r", encoding="utf-8", newline=None) as f:
        lines = f.read().split("\n")
    stmts, arms = analyse(lines)
    os.makedirs(COV_DIR, exist_ok=True)
    cov_path = os.path.join(COV_DIR, "review_service_cov.gd")
    with open(cov_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(instrument(lines, stmts)))
    env = dict(os.environ, VT075_SERVICE_PATH="res://tests/vt075/_cov/review_service_cov.gd", VT075_COV="1")
    if a.only:
        env["VT075_ONLY"] = a.only
    p = subprocess.run([GODOT, "--headless", SCENE], cwd=ROOT, env=env, capture_output=True, text=True,
                       timeout=300, encoding="utf-8", errors="replace")
    out = p.stdout + p.stderr
    m = re.search(r"COVERAGE_JSON:(\{.*\})", out)
    if not m:
        print(out[-2000:])
        sys.exit("no coverage json (suite exit=%d)" % p.returncode)
    hits = {int(k): v for k, v in json.loads(m.group(1)).items()}
    summ = re.search(r"\[SUMMARY\][^\n]*", out)
    hit_lines = [i for i in stmts if i in hits]
    miss_lines = [i for i in stmts if i not in hits]
    arm_hit = [x for x in arms if x["probe"] in hits]
    arm_miss = [x for x in arms if x["probe"] not in hits]
    lc = 100.0 * len(hit_lines) / len(stmts)
    bc = 100.0 * len(arm_hit) / len(arms)
    lines_out = []
    lines_out.append("suite: %s (exit=%d)" % (summ.group(0).strip() if summ else "?", p.returncode))
    lines_out.append("filter: %s" % (a.only or "all tests"))
    lines_out.append("line coverage: %d/%d = %.1f%%" % (len(hit_lines), len(stmts), lc))
    lines_out.append("arm (branch) coverage: %d/%d = %.1f%%" % (len(arm_hit), len(arms), bc))
    lines_out.append("approx arms (false-arm of an if whose body does not end in return/continue/break): %d" %
                     sum(1 for x in arms if not x["exact"]))
    for i in miss_lines:
        lines_out.append("UNCOVERED line %d: %s" % (i, lines[i - 1].strip()))
    for x in arm_miss:
        lines_out.append("UNCOVERED arm %s of line %d: %s" % (x["kind"], x["line"], lines[x["line"] - 1].strip()))
    text = "\n".join(lines_out)
    print(text)
    if a.out:
        with open(os.path.join(ROOT, a.out), "w", encoding="utf-8", newline="\n") as f:
            f.write(text + "\n")


if __name__ == "__main__":
    main()

