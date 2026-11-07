"""Independently verify paired CSV coverage and every reported statistic (stdlib only)."""

import argparse
import csv
import hashlib
import json
import math
import statistics
from collections import defaultdict
from pathlib import Path


def require(condition, message):
    if not condition:
        raise ValueError(message)


def boolean(value):
    require(value in ("true", "false"), f"Invalid CSV boolean: {value!r}")
    return value == "true"


def stats(values):
    ordered = sorted(values)
    return {
        "n": len(values),
        "mean_ms": statistics.mean(values),
        "median_ms": statistics.median(values),
        "p95_ms": ordered[math.ceil(0.95 * len(values)) - 1],
        "min_ms": ordered[0],
        "max_ms": ordered[-1],
    }


def equal(expected, actual, context):
    if expected is None:
        require(actual is None, f"{context}: expected null, got {actual}")
    else:
        require(isinstance(actual, (int, float)) and math.isfinite(actual), f"{context}: not finite")
        require(math.isclose(expected, actual, rel_tol=1e-10, abs_tol=1e-9), f"{context}: expected {expected}, got {actual}")


def verify(directory):
    metadata = json.loads((directory / "metadata.json").read_text(encoding="utf-8"))
    summary = json.loads((directory / "summary.json").read_text(encoding="utf-8"))
    preflight = json.loads((directory / "preflight.json").read_text(encoding="utf-8"))
    require(preflight["passed"] and len(preflight["cases"]) == 27 and all(case["passed"] for case in preflight["cases"]), "Commit 1 preflight failed")
    seeds = metadata["seed_count_per_configuration"]
    repetitions = metadata["repetitions_per_mode"]
    counts, floors = metadata["room_counts"], metadata["floors"]
    expected_count = len(counts) * len(floors) * seeds * repetitions * 2
    with (directory / "samples.csv").open(encoding="utf-8", newline="") as source:
        rows = list(csv.DictReader(source))
    require(len(rows) == expected_count == metadata["actual_samples"] == metadata["expected_samples"] == summary["sample_count"], "Sample count mismatch")
    groups, pairs, fingerprints = defaultdict(list), defaultdict(dict), {}
    failed = defaultdict(int)
    for row in rows:
        rooms, floor = int(row["rooms"]), int(row["floor"])
        mode, repetition = boolean(row["variants_enabled"]), int(row["repetition"])
        require(rooms in counts and floor in floors, "Unknown configuration")
        require(row["seed"].startswith(metadata["seed_prefix"]), "Unexpected seed prefix")
        seed_index = int(row["seed"][len(metadata["seed_prefix"]):])
        require(0 <= seed_index < seeds and 1 <= repetition <= repetitions, "Seed/repetition out of range")
        pair_id = f"{rooms}_{floor}_{seed_index:05d}_{repetition}"
        require(row["pair_id"] == pair_id and mode not in pairs[pair_id], "Duplicate or incorrect pair ID")
        index = counts.index(rooms) * len(floors) + floors.index(floor)
        on_first = (index + seed_index + repetition - 1) % 2 == 1
        require(int(row["order_in_pair"]) == (1 if mode == on_first else 2), "Incorrect OFF/ON alternation")
        microseconds = int(row["generation_us"])
        require(microseconds >= 0, "Negative duration")
        milliseconds = microseconds / 1000.0
        equal(milliseconds, float(row["generation_ms"]), pair_id + " CSV duration")
        groups[rooms, floor, mode].append(milliseconds)
        pairs[pair_id][mode] = milliseconds
        key = rooms, floor, seed_index, mode
        digest = row["snapshot_sha256"]
        require(len(digest) == 64 and all(char in "0123456789abcdef" for char in digest), "Invalid snapshot digest")
        require(fingerprints.setdefault(key, digest) == digest, f"Nonrepeatable fingerprint: {key}")
        require(boolean(row["variant_paths_checked"]) == mode, "Incorrect validation scope")
        valid = all(boolean(row[field]) for field in ("valid_structure", "repeatable", "metadata_valid", "boss_safe")) and not row["error"]
        require(boolean(row["passed"]) == valid, "Sample correctness flags disagree")
        failed[rooms, floor] += int(not valid)
    require(len(pairs) * 2 == expected_count and all(set(pair) == {False, True} for pair in pairs.values()), "Unpaired samples")
    require(len(summary["configurations"]) == len(counts) * len(floors), "Wrong summary configuration count")
    seen = set()
    for result in summary["configurations"]:
        rooms, floor = result["rooms"], result["floor"]
        require((rooms, floor) not in seen, "Duplicate summary configuration")
        seen.add((rooms, floor))
        mode_stats = {}
        for mode, name in ((False, "off"), (True, "on")):
            values = groups[rooms, floor, mode]
            require(len(values) == seeds * repetitions, "Missing mode samples")
            mode_stats[name] = stats(values)
            for field, expected in mode_stats[name].items():
                equal(expected, result[name][field], f"{rooms}/{floor} {name} {field}")
        for field, prefix in (("median_ms", "median"), ("mean_ms", "mean"), ("p95_ms", "p95")):
            baseline = mode_stats["off"][field]
            delta = mode_stats["on"][field] - baseline
            equal(delta, result[f"{prefix}_delta_ms"], f"{rooms}/{floor} {prefix} delta")
            equal(delta / baseline * 100 if baseline > 0 else None, result[f"{prefix}_delta_percent"], f"{rooms}/{floor} {prefix} percent")
        deltas = [pair[True] - pair[False] for key, pair in pairs.items() if key.startswith(f"{rooms}_{floor}_")]
        for field, expected in stats(deltas).items():
            equal(expected, result["paired_delta"][field], f"{rooms}/{floor} paired delta {field}")
        require(result["failed_samples"] == failed[rooms, floor] and result["correctness_pass"] == (failed[rooms, floor] == 0), "Failure counts disagree")
    total_failed = sum(failed.values())
    require(summary["failed_samples"] == total_failed and summary["correctness_pass"] == (total_failed == 0), "Global correctness flags disagree")
    require(metadata["status"] == ("PASS" if total_failed == 0 else "FAIL"), "Metadata status disagrees")
    require(total_failed == 0, f"Run correctness FAIL: {total_failed} invalid samples retained in statistics")
    return {
        "status": "PASS", "verified_samples": len(rows), "pairs": len(pairs),
        "configurations": len(seen), "raw_csv_sha256": hashlib.sha256((directory / "samples.csv").read_bytes()).hexdigest(),
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_directory", type=Path)
    options = parser.parse_args()
    try:
        print(json.dumps(verify(options.run_directory), indent=2))
    except (ValueError, KeyError, OSError, TypeError) as error:
        parser.exit(1, f"FAIL: {error}\n")
