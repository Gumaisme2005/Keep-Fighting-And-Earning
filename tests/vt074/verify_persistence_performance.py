"""Recalculate new CSV/batch evidence using the existing canonical synthetic ZIP.

No personal saves, project execution, or new duplicate snapshot archive required.
python tests/vt074/verify_persistence_performance.py --run <benchmark JSON>
"""
import argparse
import json
from pathlib import Path
import tempfile
import zipfile
from run_ci_import_audit import ROOT, EVIDENCE
from verify_profiling import verify_dataset


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--run', type=Path, required=True)
    a = p.parse_args()
    report = json.loads(a.run.read_text(encoding='utf-8'))
    assert report['runner_exit_code'] == 0
    b = report['benchmark']
    base = (ROOT/'.godot/vt074_verify_persistence').resolve()
    base.mkdir(parents=True, exist_ok=True)
    archive = EVIDENCE/'heavy_c1_production_a1b80b4f3c6b_snapshots.zip'
    with tempfile.TemporaryDirectory(dir=base) as folder:
        target = Path(folder).resolve()
        assert target.is_relative_to(base) and target != base
        with zipfile.ZipFile(archive) as z:
            expected = {'c5/performance/'+key+'/save.json' for key in b['saved_snapshot_sha256']}
            assert len(expected) == len(z.namelist()) == 140 and set(z.namelist()) == expected
            assert all((target/name).resolve().is_relative_to(target) for name in z.namelist())
            z.extractall(target)
        calculated, tasks = verify_dataset(b['artifacts'], target)
        assert all(calculated[key] == b[key] for key in calculated)
        assert len(tasks) == 5600
        # TemporaryDirectory only removes this verified child, never a user path.
        assert target.is_relative_to(base)
    print(json.dumps({'status': 'PASS', 'samples': len(tasks), 'batches': 140,
                      'canonical_archive_reused': archive.relative_to(ROOT).as_posix(),
                      'workloads': [{'workload': w['workload'], 'frames': w['frames'], 'p95_ms': w['p95_ms']}
                                    for w in calculated['workloads']]}, indent=2))


if __name__ == '__main__':
    main()
