"""Deterministic constrained strength-2 covering array, exhaustive feasible-pair verifier.

Generate: py tests/vt074/pairwise.py --generate
Verify checked-in CSV (does NOT regenerate it): py tests/vt074/pairwise.py
The verifier enumerates the constrained Cartesian model independently of selection.
No dependencies, random seed, Godot execution or production behavior simulation.
"""

import argparse
import csv
from itertools import combinations, product
import json
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
EVIDENCE = HERE.parents[1] / "docs/BT3_VT074/evidence"
FACTORS = {
    "identity": ("active_new", "retained", "invalid", "unknown_unissued", "unknown_expired"),
    "payload": ("same", "different"),
    "storage": ("in_memory", "after_reload"),
    "ledger": ("below", "at_128", "overflow_129"),
}
NAMES = tuple(FACTORS)
FIELDS = ("row_id", *NAMES, "expected_status", "test_cases", "execution_status")


def feasible(row):
    return not (row[0] == "unknown_expired" and row[3] != "overflow_129")


def pairs(row):
    return {(NAMES[a], row[a], NAMES[b], row[b]) for a, b in combinations(range(len(NAMES)), 2)}


def oracle(row):
    identity, payload, _, _ = row
    if identity == "active_new":
        return "COMMITTED"
    if identity == "retained":
        return "DUPLICATE" if payload == "same" else "CONFLICT"
    return "INVALID_REQUEST" if identity == "invalid" else "UNKNOWN_RUN"


def mapping(row):
    identity, payload, storage, ledger = row
    cases = {"active_new": ["VT74-01"], "retained": ["VT74-02" if payload == "same" else "VT74-04"],
             "invalid": ["VT74-05"], "unknown_unissued": ["VT74-15"], "unknown_expired": ["VT74-10"]}[identity].copy()
    if storage == "after_reload":
        cases.append("VT74-07")
    if ledger == "at_128":
        cases.append("VT74-09")
    if ledger == "overflow_129":
        cases.append("VT74-10")
    return ";".join(dict.fromkeys(cases))


def verify(rows):
    cartesian = list(product(*FACTORS.values()))
    allowed = [row for row in cartesian if feasible(row)]
    all_pairs = set().union(*(pairs(row) for row in cartesian))
    required = set().union(*(pairs(row) for row in allowed))
    covered = set()
    errors = []
    seen = set()
    catalog = (HERE.parents[1] / "docs/BT3_VT074/TEST_CASES.md").read_text(encoding="utf-8")
    catalog_ids = re.findall(r"^\| (VT74-\d+) \|", catalog, re.M)
    expected_ids = {f"VT74-{index:02}" for index in range(1, 23)}
    if len(catalog_ids) != 22 or set(catalog_ids) != expected_ids:
        errors.append("Catalog must contain exactly VT74-01 through VT74-22 once each")
    mapped_ids = set()
    for item in rows:
        row = tuple(item[name] for name in NAMES)
        if row not in allowed:
            errors.append(f"{item['row_id']}: invalid levels or infeasible combination")
            continue
        if row in seen:
            errors.append(f"{item['row_id']}: duplicate row")
        seen.add(row)
        if item["expected_status"] != oracle(row) or item["test_cases"] != mapping(row):
            errors.append(f"{item['row_id']}: oracle/mapping mismatch")
        references = item["test_cases"].split(";")
        if not set(references) <= set(catalog_ids):
            errors.append(f"{item['row_id']}: mapping references missing catalog cases")
        mapped_ids.update(references)
        if item["execution_status"] != "PLANNED AFTER PATCH":
            errors.append(f"{item['row_id']}: matrix is not an executed engine test")
        covered |= pairs(row)
    missing = sorted(required - covered)
    return {"algorithm": "deterministic greedy maximum uncovered pairs; Cartesian-order tie break; reverse redundant-row removal",
            "strength": 2, "factors": FACTORS, "cartesian_rows": len(cartesian),
            "feasible_full_rows": len(allowed), "infeasible_full_rows": len(cartesian) - len(allowed),
            "array_rows": len(rows), "all_pair_count": len(all_pairs), "feasible_pair_count": len(required),
            "covered_feasible_pairs": len(required & covered), "missing_pairs": missing,
            "catalog_case_count": len(catalog_ids), "mapped_case_ids": sorted(mapped_ids),
            "directed_case_ids_not_in_matrix": sorted(expected_ids - mapped_ids),
            "engine_rows_executed": 0,
            "excluded_pairs": [{"pair": p, "reason": "Expired receipt requires overflow at the 129th successful completion; below/at-128 has not evicted oldest."}
                               for p in sorted(all_pairs - required)], "errors": errors,
            "verified": not errors and not missing}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--generate", action="store_true")
    args = parser.parse_args()
    path = HERE / "pairwise_cases.csv"
    if args.generate:
        remaining = [row for row in product(*FACTORS.values()) if feasible(row)]
        uncovered = set().union(*(pairs(row) for row in remaining))
        chosen = []
        while uncovered:
            row = max(remaining, key=lambda candidate: len(pairs(candidate) & uncovered))
            chosen.append(row)
            uncovered -= pairs(row)
            remaining.remove(row)
        for row in list(reversed(chosen)):
            others = [candidate for candidate in chosen if candidate != row]
            if pairs(row) <= set().union(*(pairs(candidate) for candidate in others)):
                chosen.remove(row)
        with path.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=FIELDS, lineterminator="\n")
            writer.writeheader()
            for index, row in enumerate(chosen, 1):
                writer.writerow(dict(row_id=f"PW-{index:02}", **dict(zip(NAMES, row)), expected_status=oracle(row),
                                     test_cases=mapping(row), execution_status="PLANNED AFTER PATCH"))
    with path.open(encoding="utf-8", newline="") as stream:
        reader = csv.DictReader(stream)
        if tuple(reader.fieldnames or ()) != FIELDS:
            raise ValueError("Unexpected CSV schema")
        rows = list(reader)
    if len({item["row_id"] for item in rows}) != len(rows) or not rows:
        raise ValueError("Missing or duplicate row IDs")
    report = verify(rows)
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "pairwise_verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if report["verified"] else 1


if __name__ == "__main__":
    sys.exit(main())
