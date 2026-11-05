#!/usr/bin/env python3
"""Check Godot paths/UIDs without an engine or third party dependencies.

Run from any directory: python tools/check_project_structure.py
This is a static check, not a substitute for Godot import or runtime tests.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
IGNORED = {'.git', '.godot', '.godot-test-results', '__pycache__', '_mutant', '_cov', 'build'}
RESOURCE_SUFFIXES = {'.gd', '.tscn', '.tres', '.godot', '.cfg'}


def check(root: Path) -> dict:
    files = {p.relative_to(root).as_posix(): p for p in root.rglob('*')
             if p.is_file() and not IGNORED.intersection(p.relative_to(root).parts)}
    directories = {p.relative_to(root).as_posix() for p in root.rglob('*')
                   if p.is_dir() and not IGNORED.intersection(p.relative_to(root).parts)}
    errors: list[str] = []
    warnings: list[str] = []
    uids: dict[str, list[str]] = defaultdict(list)
    resource_uids: dict[str, str] = {}
    case_paths: dict[str, list[str]] = defaultdict(list)
    resources = {}
    references = 0
    for name, path in files.items():
        case_paths[name.casefold()].append(name)
        if path.suffix in RESOURCE_SUFFIXES | {'.uid', '.import'}:
            text = path.read_text(encoding='utf-8-sig')
            if path.suffix == '.uid':
                uid = text.strip()
                owner = name[:-4]
                if owner not in files:
                    errors.append(f'{name}: orphan UID sidecar')
            else:
                match = re.search(r'^\[gd_\w+[^\n]*?\buid="([^"]+)"', text)
                if path.suffix == '.import':
                    match = re.search(r'^uid="([^"]+)"', text, re.M)
                uid = match[1] if match else ''
                owner = name[:-7] if path.suffix == '.import' else name
                if path.suffix == '.import' and owner not in files:
                    errors.append(f'{name}: import sidecar has no source file')
            if uid:
                uids[uid].append(owner)
                resource_uids[owner] = uid
            if path.suffix in RESOURCE_SUFFIXES:
                resources[name] = text
    for names in case_paths.values():
        if len(names) > 1:
            errors.append('Case collision: ' + ', '.join(names))
    for uid, owners in uids.items():
        if len(owners) > 1:
            errors.append(f'Duplicate {uid}: {owners}')
    for name, text in resources.items():
        # Whole quoted paths retain spaces/parentheses used by vendor assets.
        for match in re.finditer(r'"(\*?(?:res|uid)://[^"\r\n]+)"', text):
            reference = match[1].lstrip('*')
            line = text[:match.start()].count('\n') + 1
            if reference.startswith('uid://'):
                if reference not in uids:
                    errors.append(f'{name}:{line}: unresolved {reference}')
                references += 1
                continue
            target = reference[6:].rstrip('/')
            if target in files or target in directories:
                references += 1
                continue
            # These are output directories (the scripts create them), not inputs.
            if target in {'benchmarks/advanced/results', 'benchmarks/results'}:
                continue
            if target == 'tests/vt075/_cov/review_service_cov.gd':
                continue
            errors.append(f'{name}:{line}: missing or case-mismatched {reference}')
        if Path(name).suffix in {'.tscn', '.tres'}:
            for line in text.splitlines():
                if not line.startswith('[ext_resource '):
                    continue
                path = re.search(r'path="res://([^"]+)"', line)
                uid = re.search(r'uid="([^"]+)"', line)
                if path and uid and path[1] in resource_uids and uid[1] != resource_uids[path[1]]:
                    errors.append(f'{name}: UID mismatch for {path[1]}')
            for kind in ('ExtResource', 'SubResource'):
                tag = 'ext_resource' if kind == 'ExtResource' else 'sub_resource'
                defined = set(re.findall(r'^\[' + tag + r'\b[^\n]*\bid="([^"]+)"', text, re.M))
                used = set(re.findall(kind + r'\("([^"]+)"\)', text))
                for missing in sorted(used - defined):
                    errors.append(f'{name}: undeclared {kind}("{missing}")')
    for name in files:
        if name.endswith('.gd') and name + '.uid' not in files:
            warnings.append(f'{name}: no UID sidecar; import using the project engine before committing')
    return {'files': len(files), 'resources': len(resources), 'references': references,
            'uids': len(uids), 'errors': errors, 'warnings': warnings}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--json', type=Path, help='Save the actual static check result')
    args = parser.parse_args()
    result = check(ROOT)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    for error in result['errors']:
        print('ERROR:', error)
    for warning in result['warnings']:
        print('WARNING:', warning)
    print(f"Checked {result['resources']} resources, {result['references']} references, "
          f"{result['uids']} UIDs: {len(result['errors'])} errors, {len(result['warnings'])} warnings")
    return 1 if result['errors'] else 0


if __name__ == '__main__':
    sys.exit(main())
