"""Diagnostic C5 profiling: fresh isolated copies, unchanged feature production.

py tests/vt074/run_profiling.py --godot <Godot.exe>
Runs unchanged benchmark first, then a timing-only instrumented copy. Never
executes an optimization; specific student approval is required for that.
Every attempt has unique evidence names; no historical evidence is overwritten.
"""
import argparse
from datetime import datetime, timedelta, timezone
import difflib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import uuid

from run_red import ROOT, EVIDENCE, run, check_clean_execution, digest
from run_green import PROBE

BASE = "001785ee52589094f2b096161a0be99d5e3c4003"
BRANCH = "feat/bt3-vt074-idempotent-run"
TRACE = 'const VT074Trace = preload("res://tests/vt074/profile_trace.gd")\n'


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise RuntimeError("Diagnostic anchor is not unique: " + old[:100])
    return text.replace(old, new, 1)


def wrap(text, name, args, label, void=False):
    pattern = rf"^(static )?func {re.escape(name)}\((.*)\) -> ([^:]+):$"
    matches = list(re.finditer(pattern, text, re.M))
    if len(matches) != 1:
        raise RuntimeError("Diagnostic function anchor: " + name)
    m = matches[0]
    declaration = m.group(0)
    impl = "_vt074_original_" + name.lstrip("_")
    call = f"{impl}({args})"
    body = (f"\t{call}\n" if void else f"\tvar _profile_result = {call}\n")
    wrapper = (declaration + f'\n\tVT074Trace.enter("{label}")\n' + body
               + "\tVT074Trace.leave()\n" + ("" if void else "\treturn _profile_result\n") + "\n")
    return text[:m.start()] + wrapper + declaration.replace("func " + name + "(", "func " + impl + "(", 1) + text[m.end():]


def instrument_gm(text):
    text = replace_once(text, "extends Node\n", "extends Node\n" + TRACE)
    text = replace_once(text, "\tvar frames: Array = []\n\tfor frame in raw.frames.slice",
                        '\tVT074Trace.enter("frame_validation_copy_loop")\n\tvar _profile_copy_us := 0\n\tvar frames: Array = []\n\tfor frame in raw.frames.slice')
    text = replace_once(text, "\t\tvar normalized: Dictionary = frame.duplicate(true)",
                        "\t\tvar _profile_copy_start := Time.get_ticks_usec()\n\t\tvar normalized: Dictionary = frame.duplicate(true)\n\t\t_profile_copy_us += Time.get_ticks_usec() - _profile_copy_start")
    text = replace_once(text, '\t\tframes.append(normalized)\n\treturn {"seed": sanitize_seed(raw.seed)',
                        '\t\tframes.append(normalized)\n\tVT074Trace.leaf("frame_deep_copy", _profile_copy_us)\n\tVT074Trace.leave()\n\treturn {"seed": sanitize_seed(raw.seed)')
    text = replace_once(text, "func payload_fingerprint(payload: Dictionary) -> String:\n\tvar frames: Array = []",
                        'func payload_fingerprint(payload: Dictionary) -> String:\n\tVT074Trace.enter("fingerprint_tuple_build")\n\tvar frames: Array = []')
    text = replace_once(text, '\treturn JSON.stringify([1, payload.seed, payload.hero_idx, payload.floor, payload.kills,\n\t\tpayload.reason, payload.session_mode, frames]).sha256_text()',
                        '\tVT074Trace.leave()\n\tVT074Trace.enter("fingerprint_json")\n\tvar _profile_encoded := JSON.stringify([1, payload.seed, payload.hero_idx, payload.floor, payload.kills,\n\t\tpayload.reason, payload.session_mode, frames])\n\tVT074Trace.leave()\n\tVT074Trace.enter("fingerprint_sha256")\n\tvar _profile_digest := _profile_encoded.sha256_text()\n\tVT074Trace.leave()\n\treturn _profile_digest')
    for old, new in [
        ('\t\t_envelope = payload.duplicate(true)', '\t\tVT074Trace.enter("candidate_build")\n\t\t_envelope = VT074Trace.copy_dict(payload, "envelope_copy")'),
        ('\t\tvar entry: Dictionary = payload.duplicate(true)', '\t\tvar entry: Dictionary = VT074Trace.copy_dict(payload, "entry_copy")'),
        ('\t\t\tcandidate.last_recorded_run = entry.duplicate(true)', '\t\t\tcandidate.last_recorded_run = VT074Trace.copy_dict(entry, "last_recorded_copy")'),
        ('\t\tentry.frames = entry.frames.slice(0, MAX_DISK_REPLAY_FRAMES)', '\t\tVT074Trace.enter("history_ledger_update")\n\t\tentry.frames = entry.frames.slice(0, MAX_DISK_REPLAY_FRAMES)'),
        ('\t\tvar summary := payload.duplicate(true)', '\t\tvar summary := VT074Trace.copy_dict(payload, "summary_copy")'),
        ('\t\t_pending_snapshot = candidate\n\tvar receipt:', '\t\t_pending_snapshot = candidate\n\t\tVT074Trace.leave()\n\t\tVT074Trace.leave()\n\tvar receipt:'),
    ]:
        text = replace_once(text, old, new)
    for name, args, label, void in [
        ("canonical_payload", "raw", "canonical", False),
        ("_sanitize_replay_frames", "raw_frames, max_count", "replay_sanitize", False),
        ("payload_fingerprint", "payload", "fingerprint", False),
        ("_valid_id", "value, length", "id_validation", False),
        ("_receipt_for", "token", "ledger_lookup", False),
        ("_snapshot", "", "snapshot_copy", False),
        ("_valid_v2_snapshot", "data", "snapshot_validation", False),
        ("_publish_snapshot", "data", "state_publish", True),
    ]:
        text = wrap(text, name, args, label, void)
    return text


def instrument_store(text):
    text = replace_once(text, "extends RefCounted\n", "extends RefCounted\n" + TRACE)
    text = replace_once(text, "\tvar bytes := JSON.stringify(snapshot).to_utf8_buffer()",
                        '\tVT074Trace.enter("snapshot_json_utf8")\n\tvar bytes := JSON.stringify(snapshot).to_utf8_buffer()\n\tVT074Trace.leave()')
    text = replace_once(text, "\tfile.flush()", '\tVT074Trace.enter("fs_flush")\n\tfile.flush()\n\tVT074Trace.leave()')
    for name, args, label in [("read_bytes", "source", "fs_read_bytes"),
                              ("_write_temp", "target, bytes", "fs_write_temp"),
                              ("_replace", "source, target", "fs_replace"),
                              ("commit", "snapshot", "store_commit")]:
        text = wrap(text, name, args, label)
    return text


def instrument_harness(text):
    text = replace_once(text, "extends Node\n", "extends Node\n" + TRACE + "var profile_file: FileAccess\n")
    text = replace_once(text, "\ttask.dispatch_us = Time.get_ticks_usec()",
                        "\ttask.dispatch_us = Time.get_ticks_usec()\n\tVT074Trace.start()")
    text = replace_once(text, "\ttask.finish_us = Time.get_ticks_usec()",
                        "\ttask.finish_us = Time.get_ticks_usec()\n\ttask.profile = VT074Trace.finish(task.finish_us)")
    text = replace_once(text, '\tvar measured := FileAccess.open("user://c5/performance/performance_40.csv", FileAccess.WRITE)',
                        '\tprofile_file = FileAccess.open("user://c5/performance/profile_spans.jsonl", FileAccess.WRITE)\n\tvar measured := FileAccess.open("user://c5/performance/performance_40.csv", FileAccess.WRITE)')
    text = replace_once(text, "\t\t\t\tfor row in batch_rows:\n",
                        '\t\t\t\tfor row in batch_rows:\n\t\t\t\t\tprofile_file.store_line(JSON.stringify({"task_id": row.task_id, "batch_id": row.batch_id, "phase": row.phase if row.has("phase") else phase, "frames": frame_count, "workload": family, "status": row.status, "request_type": row.request_type, "spans": row.profile}))\n')
    text = replace_once(text, "\tmeasured.close()", "\tprofile_file.close()\n\tmeasured.close()")
    return text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--git", default=shutil.which("git") or r"C:\Users\ADMIN\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe")
    args = parser.parse_args()
    stamp = uuid.uuid4().hex
    prefix = "profiling_" + stamp[:12]
    work = ROOT / ".godot/vt074_profile" / stamp
    work.mkdir(parents=True)
    report = {"executed_at": datetime.now(timezone(timedelta(hours=7))).isoformat(), "head": BASE,
              "branch": BRANCH, "work": str(work), "prefix": prefix, "steps": [], "code": 2}

    def git(*values):
        return subprocess.check_output([args.git, *values], cwd=ROOT).decode("utf-8").strip()

    if git("rev-parse", "HEAD") != BASE or git("branch", "--show-current") != BRANCH or git("diff", "--name-only") or git("diff", "--cached", "--name-only"):
        raise RuntimeError("Unexpected branch, HEAD, tracked or index changes")
    settings = (ROOT / "project.godot").read_text(encoding="utf-8")
    if 'config/name="Keep Fighting And Earning"' not in settings or "use_custom_user_dir" in settings or (ROOT / "override.cfg").exists():
        raise RuntimeError("Unexpected save configuration")
    names = list(filter(None, git("ls-files", "-co", "--exclude-standard", "-z").split("\0")))
    immutable = {n: digest(ROOT / n) for n in names}
    report["source_sha256"] = immutable
    personal = Path(os.environ["APPDATA"]) / "Godot/app_userdata/Keep Fighting And Earning/roguelike_save_data.json"
    report["personal_before_sha256"] = digest(personal)
    report["environment"] = {"OS": platform.platform(), "logical_CPUs": os.cpu_count(), "headless": True}
    hw = subprocess.run(["powershell", "-NoProfile", "-Command", "[ordered]@{CPU=@(Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors);RAM_Bytes=(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory;Volume=@(Get-Volume -DriveLetter C | Select-Object DriveLetter,FileSystem,DriveType)} | ConvertTo-Json -Depth 4"], capture_output=True, text=True)
    report["environment"]["hardware_query"] = {"exit_code": hw.returncode, "stdout": hw.stdout, "stderr": hw.stderr}
    probe = work / "probe"
    probe.mkdir()
    (probe / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Keep Fighting And Earning"\n', encoding="utf-8")
    (probe / "probe.gd").write_text(PROBE, encoding="utf-8")

    def capture(name, result):
        path = EVIDENCE / f"{prefix}_{name}.log"
        with path.open("x", encoding="utf-8") as out:
            out.write(json.dumps({"executed_at": report["executed_at"], "head": BASE, "branch": BRANCH, "name": name,
                                  "command": result["command"], "exit_code": result["exit_code"], "user_dir": result.get("user_dir")}, indent=2)
                      + "\nSTDOUT:\n" + result["stdout"] + "\nSTDERR:\n" + result["stderr"])
        report["steps"].append({"name": name, "log": path.relative_to(ROOT).as_posix(), **result})
        if not check_clean_execution(result):
            raise RuntimeError("Setup/execution error: " + name)

    def environment(name):
        env = os.environ.copy()
        for key, folder in [("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("TEMP", "temp"), ("TMP", "temp")]:
            target = work / "userdata" / name / folder
            target.mkdir(parents=True, exist_ok=True)
            env[key] = str(target)
        user = Path(env["APPDATA"]) / "Godot/app_userdata/Keep Fighting And Earning"
        env["VT074_EXPECT_USER_DIR"] = user.as_posix()
        step = run([str(args.godot), "--headless", "--path", str(probe), "--log-file", str(work / (name + "-probe.log")), "--script", "res://probe.gd"], env)
        capture(name + "_probe", step)
        if "[PROBE_ISOLATION] VERIFIED sentinel MATCH" not in step["stdout"]:
            raise RuntimeError("Isolation not verified before project import/autoload")
        return env, user

    try:
        # Never copy old evidence or caches; all runnable resources are included.
        project = work / "project"
        project.mkdir()
        for name in names:
            if name.startswith("docs/"):
                continue
            target = project / name
            if not target.resolve().is_relative_to(project.resolve()):
                raise RuntimeError("Unsafe project copy path")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, target)
        imported_fonts = project / ".godot/imported"
        imported_fonts.mkdir(parents=True)
        for font in (ROOT / ".godot/imported").glob("*.fontdata"):
            shutil.copyfile(font, imported_fonts / font.name)
        env, _ = environment("import")
        version = run([str(args.godot), "--headless", "--version"], env)
        capture("version", version)
        if not version["stdout"].startswith("4.7.2."):
            raise RuntimeError("Godot 4.7.2 required")
        report["godot_version"] = version["stdout"].strip()
        capture("import", run([str(args.godot), "--headless", "--path", str(project), "--log-file", str(work / "import.log"), "--import"], env))
        for mode in ["before", "instrumented"]:
            if mode == "instrumented":
                transforms = {"Scene/GameManager.gd": instrument_gm, "Scene/RunCompletionStore.gd": instrument_store,
                              "tests/vt074/performance_harness.gd": instrument_harness}
                diffs = []
                report["instrumented_source_sha256"] = {}
                for name, transform in transforms.items():
                    target = project / name
                    if not target.resolve().is_relative_to(work.resolve()):
                        raise RuntimeError("Instrumentation must remain inside task-owned copied project")
                    old = target.read_text(encoding="utf-8")
                    new = transform(old)
                    target.write_text(new, encoding="utf-8")
                    diffs.extend(difflib.unified_diff(old.splitlines(True), new.splitlines(True), fromfile="unmodified/" + name, tofile="instrumented/" + name))
                    report["instrumented_source_sha256"][name] = digest(target)
                (EVIDENCE / f"{prefix}_instrumentation.patch").write_text("".join(diffs), encoding="utf-8")
            env, user = environment(mode)
            command = [str(args.godot), "--headless", "--path", str(project), "--log-file", str(work / (mode + ".log")),
                       "res://tests/vt074/quality_entry.tscn", "--", "--suite=res://tests/vt074/performance_harness.gd"]
            print(json.dumps({"mode": mode, "event": "start", "work": str(work), "prefix": prefix}), flush=True)
            step = {"user_dir": str(user), **run(command, env, timeout=2400)}
            capture(mode, step)
            source = user / "c5/performance"
            artifacts = ["performance_40.csv", "performance_warmup.csv", "performance_batches.json"]
            if mode == "instrumented":
                artifacts.append("profile_spans.jsonl")
            report[mode] = {"user_dir": str(user), "artifacts": {}}
            for name in artifacts:
                dest = EVIDENCE / f"{prefix}_{mode}_{name}"
                with dest.open("xb") as out:
                    out.write((source / name).read_bytes())
                report[mode]["artifacts"][name] = dest.relative_to(ROOT).as_posix()
            print(json.dumps({"mode": mode, "event": "completed", "exit_code": step["exit_code"]}), flush=True)
        report["code"] = 0
    except Exception as exc:
        report["blocker"] = str(exc)
        print("[PROFILING ERROR] " + str(exc), flush=True)
    finally:
        report["all_preexisting_files_unchanged"] = all(digest(ROOT / n) == sha for n, sha in immutable.items())
        report["personal_after_sha256"] = digest(personal)
        report["personal_save_unchanged"] = report["personal_before_sha256"] == report["personal_after_sha256"]
        if not report["all_preexisting_files_unchanged"] or not report["personal_save_unchanged"]:
            report["code"] = 2
        with (EVIDENCE / f"{prefix}_run.json").open("x", encoding="utf-8") as out:
            json.dump(report, out, ensure_ascii=False, indent=2)
            out.write("\n")
        print(json.dumps({"prefix": prefix, "exit_code": report["code"], "personal_save_unchanged": report["personal_save_unchanged"],
                          "all_preexisting_files_unchanged": report["all_preexisting_files_unchanged"]}), flush=True)
    return report["code"]


if __name__ == "__main__":
    sys.exit(main())
