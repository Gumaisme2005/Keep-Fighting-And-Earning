#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Thêm điểm đo build_walls() một lần, có sao lưu file gốc.
Chạy tại thư mục gốc dự án: py -3 benchmark/advanced/gan_diem_do_tuong.py
Chỉ sửa đúng 1 script chứa build_dungeon_layout và build_walls.
"""
from __future__ import annotations

import datetime as dt
import os
import re
import sys
from pathlib import Path

MARKER = "benchmark_walls_us"
CALL = re.compile(r"^(?P<indent>[ \t]+)build_walls\(\)[ \t]*(?:#.*)?$", re.MULTILINE)
PROPERTY = re.compile(r"^var[ \t]+benchmark_walls_us\s*:", re.MULTILINE)
FUNCTION = re.compile(r"^func\s+build_dungeon_layout\s*\([^\n]*\)\s*(?:->[^:\n]+)?\s*:", re.MULTILINE)
NEXT_FN = re.compile(r"^(?:func|static[ \t]+func)\s+", re.MULTILINE)


def fail(msg: str, code: int = 1) -> None:
    print("KHONG CHINH SUA - " + msg)
    sys.exit(code)


def target_file(project: Path) -> Path:
    found: list[Path] = []
    for f in project.rglob("*.gd"):
        if ".godot" in f.parts or "benchmark" in f.parts:
            continue
        try:
            source = f.read_text(encoding="utf-8-sig")
        except (UnicodeDecodeError, OSError):
            continue
        if FUNCTION.search(source) and re.search(r"^func\s+build_walls\s*\(", source, re.M):
            found.append(f)
    if len(found) != 1:
        print("Tim thay", len(found), "script generator phu hop:")
        for f in found:
            print(" -", f.relative_to(project))
        fail("Can dung 1 script; gui anh ket qua de kiem tra. Khong sua file nao.", 2)
    return found[0]


def instrument(path: Path, project: Path) -> tuple[bool, Path | None]:
    raw = path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        fail("Script co BOM UTF-8; can kiem tra thu cong, khong sua tu dong")
    try:
        content = raw.decode("utf-8")
    except UnicodeDecodeError:
        fail("Script khong phai UTF-8")
    if "\r\n" in content:
        newline = "\r\n"
        content = content.replace("\r\n", "\n")
    else:
        newline = "\n"

    if PROPERTY.search(content):
        if "benchmark_walls_us = Time.get_ticks_usec() -" in content:
            print("DA GAN DIEM DO TRUOC DO: ", path.relative_to(project))
            return False, None
        fail("Da co benchmark_walls_us nhung chua thay dong do; can kiem tra thu cong")

    matches = list(FUNCTION.finditer(content))
    if len(matches) != 1:
        fail("Khong xac dinh duy nhat func build_dungeon_layout")
    start = matches[0].end()
    next_match = NEXT_FN.search(content, start)
    end = next_match.start() if next_match else len(content)
    body = content[start:end]
    calls = list(CALL.finditer(body))
    if len(calls) != 1:
        fail(f"Trong build_dungeon_layout tim thay {len(calls)} lenh build_walls() hop le; can xem thu cong")
    call = calls[0]
    indent = call.group("indent")
    original_call = call.group(0)
    # Keep original call/comments and preserve exact indentation and code flow.
    timed = (
        f"{indent}var _bench_wall_start_us: int = Time.get_ticks_usec()\n"
        f"{original_call}\n"
        f"{indent}benchmark_walls_us = Time.get_ticks_usec() - _bench_wall_start_us"
    )
    new_body = body[:call.start()] + timed + body[call.end():]
    content = content[:start] + new_body + content[end:]

    # Declare script variable at top level, after `extends` (no export/change to core behavior).
    ext = re.search(r"^extends\s+.+$", content, flags=re.M)
    if ext is None:
        fail("Khong tim thay extends o dau script")
    i = content.find("\n", ext.end())
    if i == -1:
        fail("Khong tim thay dong xuong sau extends")
    content = content[:i + 1] + "\nvar benchmark_walls_us: int = -1 # Chi phuc vu benchmark\n" + content[i + 1:]

    out = content.replace("\n", newline).encode("utf-8")
    if out == raw:
        fail("File khong thay doi")
    backup_dir = project / "benchmark" / "advanced" / "backups"
    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup = backup_dir / (path.stem + "_goc_" + stamp + ".gd.txt")
    if backup.exists():
        fail("Ban sao luu trung ten: " + str(backup))
    backup.write_bytes(raw)
    tmp = path.with_name(path.name + ".instrument_tmp")
    try:
        tmp.write_bytes(out)
        os.replace(tmp, path)
    except OSError as e:
        if tmp.exists():
            tmp.unlink()
        fail("Khong ghi duoc generator: " + str(e))
    return True, backup


def main() -> None:
    this_script = Path(__file__).resolve()
    project = this_script.parents[2]
    if not (project / "project.godot").exists():
        fail("Khong tim thay project.godot o thu muc goc. Can chep thu muc advanced vao dung du an")
    generator = target_file(project)
    print("Generator:", generator.relative_to(project))
    changed, backup = instrument(generator, project)
    if changed:
        print("DA THEM DIEM DO BUILD_WALLS")
        print("Da sao luu ban goc:", backup.relative_to(project))
        print("Ban co the mo Godot de kiem tra loi script, sau do chay profile_giai_doan.gd")
    else:
        print("Khong can chinh sua tiep. Co the chay profile_giai_doan.gd")


if __name__ == "__main__":
    main()
