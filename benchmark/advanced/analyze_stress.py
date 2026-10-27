#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tạo báo cáo Markdown + CSV tổng hợp + SVG từ CSV stress benchmark Godot.
Chỉ dùng thư viện chuẩn Python 3, không phụ thuộc pandas/matplotlib.
Không tự sinh hoặc chỉnh sửa kết quả benchmark.
"""
import csv
import html
import math
import statistics
import sys
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path

REQUIRED = {"rooms", "trial", "seed", "total_ms", "reproducible", "passed", "floor_path_status", "notes"}
PHASES = [
    ("prepare_ms", "Chuẩn bị và đặt lại trạng thái"),
    ("layout_walls_ms", "Tạo bố cục + dựng tường (chưa tách)"),
    ("walls_ms", "Riêng dựng tường (chỉ khi đã gắn điểm đo)"),
    ("traps_ms", "Lập kế hoạch bẫy"),
    ("pillars_ms", "Trang trí cột"),
    ("decor_ms", "Rải vật trang trí"),
]


def numeric(v):
    try:
        return float(v)
    except (ValueError, TypeError):
        return None


def parse_bool(v):
    return str(v).strip().lower() == "true"


def fmt(v):
    return "—" if v is None else f"{v:.3f}".replace(".", ",")


def p95(values):
    # Nearest-rank percentile: phần tử thứ ceil(0.95*n) trong danh sách đã sắp xếp.
    vals = sorted(values)
    return vals[max(0, math.ceil(0.95 * len(vals)) - 1)] if vals else None


def stats(values):
    if not values:
        return {"mean": None, "median": None, "min": None, "max": None, "p95": None}
    return {
        "mean": statistics.fmean(values),
        "median": statistics.median(values),
        "min": min(values),
        "max": max(values),
        "p95": p95(values),
    }


def svg_chart(summary):
    # Biểu đồ SVG tĩnh, dùng trực tiếp trong GitHub Markdown.
    ordered = sorted(summary)
    maxval = max((summary[n]["mean"] or 0 for n in ordered), default=0)
    width, height = 880, 135 + len(ordered) * 70
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" rx="12" fill="#ffffff"/>',
        '<text x="28" y="39" font-size="22" font-family="Arial,sans-serif" font-weight="bold" fill="#152638">Thời gian sinh dungeon theo quy mô</text>',
        '<text x="28" y="66" font-size="14" font-family="Arial,sans-serif" fill="#516373">Trung bình (ms) — thấp hơn là tốt hơn</text>',
    ]
    for i, rooms in enumerate(ordered):
        value = summary[rooms]["mean"] or 0
        y = 94 + i * 70
        barw = round(560 * value / maxval) if maxval else 0
        parts.extend([
            f'<text x="30" y="{y+22}" font-size="17" font-family="Arial,sans-serif" fill="#24384a">{rooms} phòng</text>',
            f'<rect x="145" y="{y}" width="560" height="34" rx="5" fill="#edf3f8"/>',
            f'<rect x="145" y="{y}" width="{barw}" height="34" rx="5" fill="#357abd"/>',
            f'<text x="{155 + barw}" y="{y+24}" font-size="16" font-family="Arial,sans-serif" fill="#233345">{html.escape(fmt(value))} ms</text>'
        ])
    parts.append('</svg>')
    return "\n".join(parts)


def analyze(file_path: Path):
    if not file_path.is_file():
        raise FileNotFoundError(f"Không tìm thấy CSV: {file_path}")
    with file_path.open("r", encoding="utf-8-sig", newline="") as handle:
        rdr = csv.DictReader(handle)
        if not rdr.fieldnames:
            raise ValueError("CSV rỗng hoặc không có hàng tiêu đề")
        missing = REQUIRED.difference(rdr.fieldnames)
        if missing:
            raise ValueError("CSV thiếu cột: " + ", ".join(sorted(missing)))
        rows = list(rdr)
    if not rows:
        raise ValueError("CSV không có dữ liệu")
    grouped = defaultdict(list)
    for idx, item in enumerate(rows, start=2):
        try:
            count = int(item["rooms"])
        except (ValueError, TypeError) as e:
            raise ValueError(f"Giá trị rooms không hợp lệ ở dòng {idx}") from e
        if numeric(item.get("total_ms")) is None:
            raise ValueError(f"Giá trị total_ms không hợp lệ ở dòng {idx}")
        grouped[count].append(item)

    output_dir = file_path.with_name("bao_cao_" + file_path.stem)
    output_dir.mkdir(exist_ok=True)
    grand_count = len(rows)
    fail_count = sum(not parse_bool(r["passed"]) for r in rows)
    regen_count = sum(parse_bool(r["reproducible"]) for r in rows)
    tile_counter = Counter(r["floor_path_status"].strip() for r in rows)
    reason_counter = Counter(reason.strip() for r in rows for reason in (r.get("notes") or "").split(";") if reason.strip())

    lines = [
        "# BÁO CÁO STRESS BENCHMARK DUNGEON",
        "",
        f"**Nguồn dữ liệu:** `{file_path.name}` (dữ liệu chạy thực tế, không mô phỏng)",
        f"**Thời điểm tạo báo cáo:** {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}",
        "**Dự án:** Keep Fighting And Earning  ",
        "**Nhánh dự kiến cập nhật:** `feature/dungeon-benchmark`  ",
        "**Mã commit đã đo:** Chưa cung cấp; đối chiếu với `git rev-parse HEAD` nếu có Git.",
        "",
        "## 1. Phạm vi đo",
        "",
        "Đo tổng thời gian `generate_dungeon()` theo cấu hình số phòng và seed. ",
        "Các bước kiểm tra (cấu trúc, kết nối đồ thị, đường sàn tham khảo, tái lập) được thực hiện ngoài khoảng đo tổng.",
        "Một lượt tái sinh độc lập được dùng để đo từng giai đoạn: **không cộng trực tiếp thời gian giai đoạn thành tổng**.",
        "",
        "## 2. Thống kê kết quả",
        "",
        f"Tổng số lượt trong CSV: **{grand_count}**; đạt kiểm tra cấu trúc/tái lập: **{grand_count - fail_count}/{grand_count}**; tái lập seed: **{regen_count}/{grand_count}**.",
        "",
        "| Số phòng | Số lượt | Trung bình (ms) | Trung vị | Nhanh nhất | Chậm nhất | P95 | Lượt không đạt |",
        "|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    summary = {}
    for count in sorted(grouped):
        group = grouped[count]
        st = stats([numeric(r["total_ms"]) for r in group])
        summary[count] = st
        failed = sum(not parse_bool(r["passed"]) for r in group)
        lines.append(f"| {count} | {len(group)} | {fmt(st['mean'])} | {fmt(st['median'])} | {fmt(st['min'])} | {fmt(st['max'])} | {fmt(st['p95'])} | {failed} |")
    lines.extend([
        "", "![Thời gian trung bình theo số phòng](thoi_gian_trung_binh.svg)", "",
        "**Cách tính P95:** phần tử thứ `ceil(0,95 × N)` trong dãy thời gian đã sắp xếp tăng dần (nearest-rank).",
        "", "## 3. Phân tích thời gian từng giai đoạn", "",
        "| Số phòng | Giai đoạn | Thời gian trung bình (ms) |", "|---:|---|---:|",
    ])
    for count in sorted(grouped):
        for field, title in PHASES:
            vals = [numeric(r.get(field)) for r in grouped[count]]
            vals = [v for v in vals if v is not None and v >= 0]
            if vals:
                lines.append(f"| {count} | {title} | {fmt(statistics.fmean(vals))} |")
    lines.extend([
        "", "**Lưu ý:** `layout_walls_ms` bao gồm cả bố cục phòng/hành lang và `build_walls()`. ",
        "Chỉ khi đã thêm đo thời gian vào code generator gốc thì cột `walls_ms` mới có giá trị. ",
        "Không trừ thời gian từ hai lượt đo khác nhau để kết luận chính xác hiệu năng.",
        "", "## 4. Kiểm tra dữ liệu sinh dungeon", "",
        "Kết quả trạng thái đường đi dựa trên các ô layer 0 có atlas `(1,6)`:", "",
        "| Trạng thái | Số lượt |", "|---|---:|",
    ])
    for name, count in tile_counter.most_common():
        lines.append(f"| `{name}` | {count} |")
    lines.extend([
        "", "**Quan trọng:** kiểm tra này là phép duyệt BFS trên ô sàn theo quy ước atlas hiện có; ",
        "không đọc collision shape, vật cản động hoặc kích thước hitbox nhân vật. ",
        "Nếu xuất hiện cảnh báo, cần xem lại bản đồ thực tế trước khi coi là lỗi gameplay.",
        "", "### Các mã lỗi/cảnh báo", "",
    ])
    if reason_counter:
        lines.extend(["| Mã | Số lượt |", "|---|---:|"])
        for reason, count in reason_counter.most_common():
            lines.append(f"| `{reason}` | {count} |")
    else:
        lines.append("Không có mã lỗi/cảnh báo trong cột `notes`.")
    lines.extend([
        "", "## 5. Đánh giá và hướng cải tiến", "",
        "- Đối chiếu kết quả lần này với benchmark 400 seed trước đó **chỉ khi cùng phiên bản code và môi trường đo**.",
        "- Nếu thời gian bố cục+tường chiếm ưu thế, thêm điểm đo vào `build_walls()` theo hướng dẫn kèm theo để xác định điểm nghẽn.",
        "- Kiểm tra các seed không đạt hoặc cảnh báo trong game để loại trừ giả định sai về atlas sàn.",
        "- Sau khi cập nhật nhánh từ `main`, chạy lại với cùng seed và lưu mã commit để so sánh trước/sau.",
        "", "## 6. Giới hạn", "",
        "Không đo FPS, RAM khi chơi, kẻ địch, AI chiến đấu, va chạm vật lý hay pathfinding thực sự của nhân vật.",
        "Không khẳng định kết quả của phiên bản `main` nếu chưa chạy lại trên phiên bản đó.",
        "", "## 7. Kết luận", "",
        f"Đã phân tích **{grand_count}** dòng dữ liệu thực tế. ",
        f"Có **{fail_count}** lượt không đạt bộ tiêu chí cấu trúc/tái lập được mã hóa và **{grand_count - regen_count}** lượt không tái lập. ",
        "Kết luận về tối ưu thuật toán cần dựa trên số liệu theo giai đoạn và thí nghiệm trước/sau độc lập.",
        ""
    ])
    report_path = output_dir / "BAO_CAO_STRESS_BENCHMARK.md"
    report_path.write_text("\n".join(lines), encoding="utf-8")
    (output_dir / "thoi_gian_trung_binh.svg").write_text(svg_chart(summary), encoding="utf-8")
    summary_csv = output_dir / "BANG_TONG_HOP.csv"
    with summary_csv.open("w", encoding="utf-8-sig", newline="") as file:
        writer = csv.writer(file)
        writer.writerow(["rooms", "count", "mean_ms", "median_ms", "min_ms", "max_ms", "p95_ms", "failed"])
        for count in sorted(grouped):
            st = summary[count]
            writer.writerow([count, len(grouped[count]), *("%.3f" % st[key] for key in ("mean", "median", "min", "max", "p95")), sum(not parse_bool(r["passed"]) for r in grouped[count])])
    print("ĐÃ TẠO BÁO CÁO:", report_path.resolve())
    print("BIỂU ĐỒ:", (output_dir / "thoi_gian_trung_binh.svg").resolve())
    print("THỐNG KÊ:", summary_csv.resolve())
    print("ĐỌC:", grand_count, "dòng | KHÔNG ĐẠT:", fail_count)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Cách chạy: python benchmark/advanced/analyze_stress.py <duong_dan_csv>")
    try:
        analyze(Path(sys.argv[1]))
    except (FileNotFoundError, ValueError) as exc:
        raise SystemExit("LỖI: " + str(exc)) from exc
