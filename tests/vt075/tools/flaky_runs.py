#!/usr/bin/env python3
"""VT-075 flaky-test experiment: chay lap bo test nhieu lan va ghi nhan exit code, thoi gian,
so test pass/fail, p95 do duoc, va truong hop treo (timeout).

Chay: python tests/vt075/tools/flaky_runs.py --runs 30 [--env VT075_ORDER=reverse] [--timeout 60] [--out file.md]
"""
import argparse, os, re, statistics, subprocess, sys, time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
GODOT = os.environ.get("GODOT_BIN", r"B:\EnvironmentDev\Godot\Godot_v4.7.2-stable_win64_console.exe")
SCENE = "res://tests/test_reviewer_concurrency.tscn"


def one_run(env_extra, timeout):
    env = dict(os.environ)
    env.update(env_extra)
    t0 = time.time()
    try:
        p = subprocess.run([GODOT, "--headless", SCENE], cwd=ROOT, env=env, capture_output=True, text=True,
                           timeout=timeout, encoding="utf-8", errors="replace", stdin=subprocess.DEVNULL)
        out, code, hung = p.stdout + p.stderr, p.returncode, False
    except subprocess.TimeoutExpired as e:
        raw = e.stdout
        out = raw.decode("utf-8", "replace") if isinstance(raw, bytes) else (raw or "")
        code, hung = None, True
    dur = time.time() - t0
    m = re.search(r"(\d+) PASSED \| (\d+) FAILED", out)
    passed, failed = (int(m.group(1)), int(m.group(2))) if m else (None, None)
    p95 = re.search(r"p95=([0-9.]+)ms", out)
    failing = sorted(set(re.findall(r"\[FAIL\] (TC-[0-9a-z]+|GUARD)", out)))
    return {"code": code, "hung": hung, "dur": dur, "passed": passed, "failed": failed,
            "p95_ms": float(p95.group(1)) if p95 else None, "failing": failing,
            "summary_printed": m is not None}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=30)
    ap.add_argument("--env", default="")
    ap.add_argument("--timeout", type=int, default=60)
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    env_extra = dict(x.split("=", 1) for x in a.env.split(";") if x)
    rows = []
    for i in range(a.runs):
        r = one_run(env_extra, a.timeout)
        rows.append(r)
        print("run %2d: exit=%s hung=%s summary=%s pass=%s fail=%s p95=%sms dur=%.1fs %s" % (
            i + 1, r["code"], r["hung"], r["summary_printed"], r["passed"], r["failed"], r["p95_ms"], r["dur"],
            ",".join(r["failing"])), flush=True)
    ok = sum(1 for r in rows if r["code"] == 0 and r["failed"] == 0)
    hung = sum(1 for r in rows if r["hung"])
    p95s = [r["p95_ms"] for r in rows if r["p95_ms"] is not None]
    durs = [r["dur"] for r in rows]
    lines = ["env: %s | runs: %d | all-green: %d/%d | hung(timeout %ds): %d | any-failed-tests: %d" % (
        a.env or "(default)", a.runs, ok, a.runs, a.timeout, hung, sum(1 for r in rows if r["failed"])),
        "measured p95 per run (ms): min=%.1f median=%.1f max=%.1f" % (min(p95s), statistics.median(p95s), max(p95s)) if p95s else "no p95 data",
        "wall time per run (s): min=%.1f median=%.1f max=%.1f" % (min(durs), statistics.median(durs), max(durs))]
    print("\n" + "\n".join(lines))
    if a.out:
        with open(os.path.join(ROOT, a.out), "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines) + "\n\n")
            for i, r in enumerate(rows):
                f.write("run %d: %s\n" % (i + 1, r))


if __name__ == "__main__":
    main()

