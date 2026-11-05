#!/usr/bin/env python3
"""Phân tích CSV benchmark dungeon và xuất báo cáo Markdown bằng tiếng Việt."""
from __future__ import annotations

import argparse
import csv
import math
import statistics
from collections import defaultdict
from pathlib import Path

CHI_SO = ["total_ms", "prepare_ms", "layout_walls_ms", "traps_ms", "pillars_ms", "decor_ms"]
SO_PHONG_DU_KIEN = (8, 16, 24, 32)
SO_SEED_DU_KIEN = 100

LOI = {
    "ROOM_COUNT_MISMATCH": "Số lượng phòng không khớp cấu hình",
    "ROOM_TYPES_MISMATCH": "Danh sách loại phòng không hợp lệ",
    "START_OR_BOSS_COUNT_INVALID": "Số phòng bắt đầu/phòng Boss không hợp lệ",
    "TREASURE_COUNT_INVALID": "Số phòng kho báu không nằm trong khoảng 2–3",
    "EDGE_COUNT_INVALID": "Số cạnh kết nối không hợp lệ",
    "EDGE_ENDPOINT_MISSING": "Đỉnh của cạnh không tồn tại trong đồ thị",
    "NON_ADJACENT_EDGE": "Cạnh nối hai vị trí không liền kề",
    "ROOM_GRAPH_DISCONNECTED": "Đồ thị phòng không liên thông",
    "TRAP_NOT_ON_FLOOR": "Bẫy không nằm trên tile nền đúng quy định",
    "TRAP_DECOR_COLLISION": "Bẫy trùng với tile trang trí",
    "DIFFERENT_LAYOUT_OR_TILES_ON_REGENERATION": "Tái sinh cùng seed nhưng kết quả bản đồ khác",
}


def phan_vi(values: list[float], p: float) -> float:
    values = sorted(values)
    if len(values) == 1:
        return values[0]
    vi_tri = (len(values) - 1) * p
    duoi, tren = math.floor(vi_tri), math.ceil(vi_tri)
    return values[duoi] + (values[tren] - values[duoi]) * (vi_tri - duoi)


def dung(value: str) -> bool:
    return value.strip().lower() == "true"


def thong_ke(rows: list[dict[str, str]], key: str) -> dict[str, float]:
    values = [float(row[key]) for row in rows]
    return {
        "mean": statistics.mean(values),
        "median": statistics.median(values),
        "p95": phan_vi(values, 0.95),
        "min": min(values),
        "max": max(values),
        "stdev": statistics.stdev(values) if len(values) > 1 else 0.0,
    }


def mo_ta_loi(message: str) -> str:
    if not message or not message.strip():
        return "Không có mô tả"
    codes = [part.strip() for part in message.strip().split("|")]
    result: list[str] = []
    for part in codes:
        result.extend(LOI.get(code, code) for code in part.split(";") if code.strip())
    return "; ".join(result)


def bao_cao(csv_file: Path, output: Path) -> None:
    with csv_file.open("r", encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    if not rows:
        raise ValueError("File CSV không có dữ liệu.")

    mandatory = set(CHI_SO + ["rooms", "seed", "reproducible", "passed", "graph_connected"])
    missing = mandatory - set(rows[0])
    if missing:
        raise ValueError(f"CSV thiếu các cột bắt buộc: {', '.join(sorted(missing))}")

    groups: dict[int, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        groups[int(row["rooms"])].append(row)

    lines = [
        "# BÁO CÁO BENCHMARK HIỆU NĂNG SINH DUNGEON",
        "",
        "**Dự án:** Keep Fighting And Earning  ",
        "**Vai trò:** Benchmark hệ thống sinh dungeon  ",
        f"**Dữ liệu đầu vào:** `{csv_file.name}`  ",
        f"**Số lượt đo:** {len(rows)}  ",
        f"**Cấu hình số phòng:** {', '.join(str(n) for n in sorted(groups))}",
        "",
        "## 1. Mục tiêu và phạm vi",
        "",
        "Đo hiệu năng sinh dungeon theo số lượng phòng; đánh giá tính hợp lệ của cấu trúc "
        "phòng, đồ thị kết nối, vị trí bẫy và khả năng tái lập cùng seed. "
        "Không đo FPS, RAM gameplay, spawn quái hoặc đường đi theo tile của nhân vật.",
        "",
        "## 2. Thống kê thời gian sinh bản đồ",
        "",
        "| Số phòng | Lượt đo | Trung bình (ms) | Trung vị (ms) | P95 (ms) | Nhanh nhất (ms) | Chậm nhất (ms) | Độ lệch chuẩn (ms) | Hợp lệ | Tái lập |",
        "|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    averages: dict[int, float] = {}
    warnings: list[str] = []
    for rooms, group in sorted(groups.items()):
        s = thong_ke(group, "total_ms")
        averages[rooms] = s["mean"]
        passed = sum(dung(r["passed"]) for r in group)
        reproduced = sum(dung(r["reproducible"]) for r in group)
        lines.append(
            f"| {rooms} | {len(group)} | {s['mean']:.3f} | {s['median']:.3f} | "
            f"{s['p95']:.3f} | {s['min']:.3f} | {s['max']:.3f} | "
            f"{s['stdev']:.3f} | {passed}/{len(group)} | {reproduced}/{len(group)} |"
        )
        if len(group) != SO_SEED_DU_KIEN:
            warnings.append(f"Cấu hình {rooms} phòng chỉ có {len(group)}/{SO_SEED_DU_KIEN} lượt đo")
        if len({r['seed'] for r in group}) != len(group):
            warnings.append(f"Cấu hình {rooms} phòng có seed trùng lặp")

    if len(groups) > 1:
        base = min(groups)
        standard_seeds = {r["seed"] for r in groups[base]}
        for rooms, group in sorted(groups.items()):
            if {r["seed"] for r in group} != standard_seeds:
                warnings.append(f"Tập seed của {rooms} phòng không giống cấu hình {base} phòng")
    absent = sorted(set(SO_PHONG_DU_KIEN) - set(groups))
    if absent:
        warnings.append(f"Chưa có số liệu cho cấu hình: {', '.join(map(str, absent))} phòng")

    lines += [
        "", "## 3. Thời gian từng giai đoạn", "",
        "| Số phòng | Chuẩn bị (ms) | Bố cục + tường (ms) | Lập bẫy (ms) | Cột (ms) | Trang trí (ms) |",
        "|---:|---:|---:|---:|---:|---:|",
    ]
    for rooms, group in sorted(groups.items()):
        vals = [thong_ke(group, metric)["mean"] for metric in CHI_SO[1:]]
        lines.append(f"| {rooms} | " + " | ".join(f"{v:.3f}" for v in vals) + " |")

    lines += [
        "", "**Lưu ý phương pháp:** Các giai đoạn trên được đo ở một lượt sinh độc lập thứ hai. "
        "Không cộng tổng các giai đoạn rồi xem là `total_ms`. Cột bố cục + tường bao gồm `build_walls()`, "
        "chưa tách riêng thời gian dựng tường.",
        "", "## 4. So sánh với cấu hình 16 phòng", "",
    ]
    if 16 in averages and averages[16] > 0:
        baseline = averages[16]
        lines += ["| Số phòng | So với 16 phòng | Mức thay đổi |", "|---:|---:|---:|"]
        for rooms, average in sorted(averages.items()):
            lines.append(f"| {rooms} | {average / baseline:.2f} lần | {(average / baseline - 1) * 100:+.1f}% |")
    else:
        lines.append("Chưa có số liệu hợp lệ của cấu hình 16 phòng để so sánh.")

    lines += ["", "## 5. Kiểm tra tính đúng đắn và các seed lỗi", ""]
    for rooms, group in sorted(groups.items()):
        failures = [r for r in group if not dung(r["passed"])]
        disconnected = sum(not dung(r["graph_connected"]) for r in group)
        lines.append(f"- **{rooms} phòng:** {len(failures)} lượt không đạt; {disconnected} đồ thị không liên thông.")
        for row in failures[:5]:
            lines.append(f"  - Seed `{row['seed']}`: {mo_ta_loi(row.get('notes', ''))}")
        if len(failures) > 5:
            lines.append(f"  - Còn {len(failures) - 5} seed lỗi; xem CSV để biết đầy đủ.")

    if warnings:
        lines += ["", "### Cảnh báo về độ đầy đủ của dữ liệu", ""]
        lines += [f"- {message}" for message in warnings]

    lines += [
        "", "## 6. Kết luận và giới hạn", "",
        "- Bảng trên phản ánh dữ liệu **đọc trực tiếp từ CSV**, không điền kết quả giả định.",
        "- Kiểm tra liên thông ở mức **đồ thị phòng**, chưa chứng minh đường di chuyển thực tế theo tile.",
        "- Chỉ so sánh thời gian giữa các cấu hình nếu cùng máy, phiên bản Godot, commit và chế độ chạy.",
        "- Cần ghi rõ hash commit, CPU, hệ điều hành, phiên bản Godot, chế độ headless/đồ họa và Debug/Release trước khi nộp.",
        "- Kết quả cũ 99,052 ms với 16 phòng thuộc lần đo trước, không mặc nhiên phản ánh tăng/giảm hiệu năng của lần này.",
        "- Vùng cấm bẫy `range(-2, 2)` tương đương 4×4, chưa đủ để khẳng định đạt yêu cầu vùng 5×5.",
        "",
    ]
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines), encoding="utf-8")
    print(f"Đã đọc {len(rows)} lượt đo. Báo cáo: {output}")
    for warning in warnings:
        print(f"CẢNH BÁO: {warning}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Phân tích file CSV benchmark dungeon và xuất báo cáo tiếng Việt")
    parser.add_argument("csv", type=Path, help="Đường dẫn file CSV được Godot tạo ra")
    parser.add_argument("--out", type=Path, default=None, help="Đường dẫn file Markdown đầu ra")
    args = parser.parse_args()
    if not args.csv.is_file():
        parser.error(f"Không tìm thấy file: {args.csv}")
    bao_cao(args.csv, args.out or args.csv.with_suffix(".md"))


if __name__ == "__main__":
    main()
