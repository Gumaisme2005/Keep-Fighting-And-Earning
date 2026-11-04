#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Phân tích profiling từng giai đoạn; KHÔNG tạo CHANGELOG/báo cáo cuối.
Chỉ Python 3 tiêu chuẩn. Không sửa CSV đầu vào.
"""
from __future__ import annotations
import csv
import math
import statistics
import sys
from collections import defaultdict
from pathlib import Path

COLS = ["prepare_ms", "layout_walls_ms", "walls_ms", "traps_ms", "pillars_ms", "decor_ms"]
LABELS = [
    ("prepare_ms", "Chuẩn bị"),
    ("layout_only_ms", "Bố cục + hành lang (ước lượng cùng lượt đo)"),
    ("walls_ms", "Dựng tường"),
    ("traps_ms", "Đặt bẫy"),
    ("pillars_ms", "Trang trí cột"),
    ("decor_ms", "Trang trí khác"),
]


def read(path: Path):
    if not path.is_file():
        raise ValueError(f"Không tìm thấy file CSV: {path}")
    with path.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        required = set(COLS + ["rooms", "seed", "passed", "reproducible"])
        missing = required.difference(reader.fieldnames or ())
        if missing:
            raise ValueError("Thiếu cột CSV: " + ", ".join(sorted(missing)))
        rows = list(reader)
    if not rows:
        raise ValueError("CSV không có lượt đo")
    grouped = defaultdict(list)
    bad = 0
    for idx, r in enumerate(rows, 2):
        try:
            rooms = int(r["rooms"])
            times = {key: float(r[key]) for key in COLS}
            if any(not math.isfinite(v) or v < 0 for v in times.values()):
                raise ValueError("giá trị âm/không hữu hạn")
            if times["walls_ms"] > times["layout_walls_ms"] + 1.0:
                raise ValueError("walls_ms lớn hơn layout_walls_ms hơn 1 ms")
        except (TypeError, ValueError) as exc:
            raise ValueError(f"Dòng {idx} không có số liệu đo hợp lệ ({exc}). Bạn phải gắn điểm đo trước khi chạy.") from exc
        # Same *second* regeneration, with small clock overhead.
        times["layout_only_ms"] = times["layout_walls_ms"] - times["walls_ms"]
        grouped[rooms].append(times)
        if (r["passed"].strip().lower() != "true" or
                r["reproducible"].strip().lower() != "true"):
            bad += 1
    return grouped, bad


def chart(data, output):
    # SVG file no external dependencies; values displayed only from user CSV.
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1050" height="390" viewBox="0 0 1050 390">',
             '<rect width="100%" height="100%" fill="#fff"/>',
             '<text x="25" y="36" font-family="Arial" font-size="22" font-weight="bold" fill="#172b3a">Phân tách thời gian bố cục và dựng tường</text>',
             '<text x="25" y="61" font-family="Arial" font-size="14" fill="#566">Trung bình ms, đo ở lượt tái sinh thứ hai</text>']
    palette = ["#264d9b", "#49a5a0"]
    maxv = max((statistics.fmean([r["layout_walls_ms"] for r in rows]) for rows in data.values()), default=1)
    for i, (rooms, rows) in enumerate(sorted(data.items())):
        starty = 110 + i * 125
        wall = statistics.fmean([r['walls_ms'] for r in rows]); other = statistics.fmean([r['layout_only_ms'] for r in rows])
        parts.append(f'<text x="25" y="{starty+24}" font-family="Arial" font-size="19" fill="#172b3a">{rooms} phòng</text>')
        otherw = max(0, 700*other/maxv); wallw = max(0, 700*wall/maxv)
        parts.append(f'<rect x="180" y="{starty}" width="{otherw:.2f}" height="38" fill="{palette[0]}"/>')
        parts.append(f'<rect x="{180+otherw:.2f}" y="{starty}" width="{wallw:.2f}" height="38" fill="{palette[1]}"/>')
        parts.append(f'<text x="{190+otherw+wallw:.2f}" y="{starty+26}" font-family="Arial" font-size="15" fill="#172b3a">{other+wall:.3f} ms</text>')
    parts.extend(['<rect x="180" y="350" width="18" height="18" fill="#264d9b"/>',
                  '<text x="205" y="365" font-family="Arial" font-size="14">Bố cục + hành lang</text>',
                  '<rect x="395" y="350" width="18" height="18" fill="#49a5a0"/>',
                  '<text x="420" y="365" font-family="Arial" font-size="14">Dựng tường</text>', '</svg>'])
    output.write_text('\n'.join(parts), encoding='utf-8')


def main():
    if len(sys.argv) > 2:
        raise ValueError("Cách dùng: py -3 phan_tich_giai_doan.py [duong_dan_csv]")
    if len(sys.argv) == 2:
        source = Path(sys.argv[1]).resolve()
    else:
        source_dir = Path(__file__).resolve().parent / "results"
        options = sorted(source_dir.glob("profile_giai_doan_*.csv"), key=lambda p: p.stat().st_mtime)
        if not options:
            raise ValueError("Chưa có CSV profile_giai_doan_*.csv trong advanced/results")
        source = options[-1]
    grouped, failed = read(source)
    dest = source.parent / ("tong_hop_giai_doan_" + source.stem + ".csv")
    with dest.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(['so_phong', 'so_seed', 'giai_doan', 'trung_binh_ms', 'trung_vi_ms', 'p95_ms', 'nho_nhat_ms', 'lon_nhat_ms'])
        for rooms, samples in sorted(grouped.items()):
            print(f"\n{rooms} PHÒNG | {len(samples)} lượt đo:")
            for key, name in LABELS:
                vals = [sample[key] for sample in samples]
                avg = statistics.fmean(vals)
                med = statistics.median(vals)
                p95 = sorted(vals)[math.ceil(.95 * len(vals)) - 1]
                w.writerow([rooms, len(samples), name, f'{avg:.3f}', f'{med:.3f}', f'{p95:.3f}', f'{min(vals):.3f}', f'{max(vals):.3f}'])
                print(f"  {name}: {avg:.3f} ms (P95 {p95:.3f} ms)")
            wall_pct = 100 * sum(r['walls_ms'] for r in samples) / max(1e-9, sum(r['layout_walls_ms'] for r in samples))
            print(f"  Tỷ lệ dựng tường trong bố cục + tường: {wall_pct:.2f}%")
    image = source.parent / ("bieu_do_giai_doan_" + source.stem + ".svg")
    chart(grouped, image)
    print(f"\nSố lượt KHÔNG ĐẠT bộ kiểm tra: {failed}")
    print("CSV dữ liệu gốc:", source)
    print("Bảng tổng hợp:", dest)
    print("Biểu đồ:", image)
    print("LƯU Ý: Không cộng thời gian giai đoạn với total_ms vì đo trên hai lượt sinh khác nhau.")

if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as e:
        print("LOI:", e, file=sys.stderr)
        sys.exit(1)
