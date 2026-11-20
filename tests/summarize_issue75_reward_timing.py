"""Compact paired timing evidence; full samples/logs stay in ignored .godot."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
from statistics import median

from summarize_issue75_acceptance import TARGETS

ROOT = Path(__file__).resolve().parents[1]
POLICIES = ('normal', 'optimized', 'conservative')
PHASES = ('entry', 'pre_boss', 'exit', 'pre_descent')
MODES = ('boss_chest_lag', 'treasure_lock3', 'perk_lag', 'combined_lag')
SOURCES = ('ordinary', 'pity', 'boss_guaranteed', 'other_chest')


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def key(row):
    return row['seed'], row['style'], row['floor']


def equipment(row):
    return Counter(tuple(g[k] for k in ('id', 'source', 'acquired_floor', 'rarity', 'type'))
                   for g in row['potions']['equipment_rewards'])


def summarize(data):
    rows = data['samples']
    assert len(rows) == 540 and len({key(r) for r in rows}) == 540
    # These experiments must retain every assumed clear; no missing floor is
    # assigned a synthetic passing stat or excluded from a 30-seed denominator.
    assert all(r['reached'] and r['completed'] for r in rows)
    result = {}
    for policy in POLICIES:
        group = [r for r in rows if r['style'] == policy]
        phases = {p: [] for p in PHASES}
        exits = []
        for floor in range(1, 7):
            floor_rows = [r for r in group if r['floor'] == floor]
            assert len(floor_rows) == 30
            for phase in PHASES:
                phases[phase].append([median(r[phase][m] for r in floor_rows)
                                      for m in ('max_hp', 'armor', 'effective_damage')])
            values = [[r['exit'][m] for r in floor_rows]
                      for m in ('max_hp', 'armor', 'effective_damage')]
            values.append([r['combat']['hits'] for r in floor_rows])
            coverage = [sum(TARGETS[m][floor-1][0] <= v <= TARGETS[m][floor-1][1] for v in vs)
                        for m, vs in zip(('max_hp', 'armor', 'effective_damage', 'hits'), values)]
            exits.append({'medians': list(map(median, values)), 'coverage': coverage})
        potion_runs = []
        for seed in data['seeds']:
            run = [r for r in group if r['seed'] == seed]
            generated = sum(sum(r['potions'][s] for s in SOURCES) for r in run)
            collected = sum(r['potions']['picked_up'] for r in run)
            consumed = sum(r['potions']['consumed'] for r in run)
            ground = sum(r['potions']['ground'] for r in run)
            assert generated == collected + ground
            assert generated + 1 == consumed + ground + run[-1]['exit']['potions']
            potion_runs.append([generated, collected, consumed])
        result[policy] = dict(exit=exits, phases=phases,
                              potion_medians=[median(v[i] for v in potion_runs) for i in range(3)],
                              potion_sources={s: sum(r['potions'][s] for r in group) for s in SOURCES})
    return result


def paired(base, candidate):
    before = {key(r): r for r in base['samples']}
    after = {key(r): r for r in candidate['samples']}
    assert before.keys() == after.keys()
    assert all(equipment(before[k]) == equipment(after[k]) for k in before), 'Generated equipment changed'
    assert all(before[k]['defeated_enemies'] == after[k]['defeated_enemies'] for k in before), 'Route changed'
    losses = {}
    for policy in POLICIES:
        changes = []
        for k, row in after.items():
            if row['style'] != policy:
                continue
            for metric in ('hp', 'max_hp'):
                a, b = before[k]['exit'][metric], row['exit'][metric]
                if b < a:
                    changes.append(dict(seed=k[0], floor=k[2], metric=metric, before=a, after=b, delta=b-a))
        losses[policy] = dict(lower_hp_rows=sum(c['metric'] == 'hp' for c in changes),
                              lower_max_hp_rows=sum(c['metric'] == 'max_hp' for c in changes),
                              worst=sorted(changes, key=lambda c: (c['delta'], c['seed'], c['floor']))[:3])
    return dict(generated_equipment_identical_rows=540, route_identical_rows=540, losses=losses)


def valid_results(path):
    results = read(path)
    assert all(r['exit_code'] == 0 and not r['timeout'] and not r['errors'] and r['completion_marker']
               and r['failed_count'] in (None, 0) for r in results), path
    return results


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--work', type=Path, default=ROOT / '.godot/issue75_reward_gate')
    p.add_argument('--output', type=Path)
    p.add_argument('--reference', type=Path, help='Retained pre-change raw baseline, compared only if supplied')
    p.add_argument('--verify', action='store_true', help='Require final 25-suite matrix at both caps')
    args = p.parse_args()
    work = args.work.resolve()
    output = (args.output or work / 'compact_summary.json').resolve()
    assert output.is_relative_to(ROOT / '.godot'), 'Keep generated summaries/raw evidence in ignored .godot'
    datasets, evidence = {}, {}
    for label in ('reward_baseline',) + MODES:
        prefix = work / f'{label}_test_issue75_progression_balance_144'
        raw = Path(str(prefix) + '_issue75_progression_after.json')
        events = Path(str(prefix) + '_issue75_acquisition_events.json')
        datasets[label] = read(raw)
        result = next(r for r in valid_results(work / f'{label}_144_results.json')
                      if r['suite'] == 'test_issue75_progression_balance')
        evidence[label] = dict(raw_sha256=sha(raw), events_sha256=sha(events),
                               event_count=len(read(events)['events']),
                               passed=result['passed_count'], failed=result['failed_count'],
                               exit_code=result['exit_code'], trace_sha256=result['trace_sha256'],
                               log_sha256=result['log_sha256'])
    base = datasets['reward_baseline']
    summary = dict(classification='Test-only specification alternatives; assumed clears, not manual survival',
                   counterfactuals_are_production=False, evidence=evidence,
                   baseline=summarize(base), candidates={})
    if args.reference:
        assert read(args.reference)['samples'] == base['samples'], 'Pre-change baseline differs'
        summary['reference'] = dict(sha256=sha(args.reference), identical_four_phase_rows=540)
    for label in MODES:
        summary['candidates'][label] = dict(policies=summarize(datasets[label]), **paired(base, datasets[label]))
    if args.verify:
        a = valid_results(work / 'reward_baseline_30_results.json')
        b = valid_results(work / 'reward_baseline_144_results.json')
        assert len(a) == len(b) == 25 and {r['suite'] for r in a} == {r['suite'] for r in b}
        matching_traces = 0
        for left in a:
            right = next(r for r in b if r['suite'] == left['suite'])
            assert (left['passed_count'], left['failed_count']) == (right['passed_count'], right['failed_count'])
            assert left['trace_sha256'] == right['trace_sha256'], left['suite']
            matching_traces += left['trace_sha256'] is not None
        prefix = work / 'reward_baseline_test_issue75_progression_balance_30'
        assert read(Path(str(prefix) + '_issue75_progression_after.json'))['samples'] == base['samples']
        assert read(Path(str(prefix) + '_issue75_acquisition_events.json'))['events'] == read(
            work / 'reward_baseline_test_issue75_progression_balance_144_issue75_acquisition_events.json')['events']
        summary['verification'] = dict(processes=50, nonempty_trace_pairs=matching_traces,
                                       identical_four_phase_rows=540,
                                       suites=[dict(suite=r['suite'], passed=r['passed_count'], failed=r['failed_count'],
                                                    exit_code=r['exit_code']) for r in a],
                                       results_sha256={str(fps): sha(work / f'reward_baseline_{fps}_results.json')
                                                       for fps in (30, 144)})
        for label in MODES:
            result30 = valid_results(work / f'{label}_30_results.json')
            assert len(result30) == 1
            result30 = result30[0]
            assert result30['trace_sha256'] == evidence[label]['trace_sha256'], label
            assert result30['passed_count'] == evidence[label]['passed']
            prefix30 = work / f'{label}_test_issue75_progression_balance_30'
            raw30 = Path(str(prefix30) + '_issue75_progression_after.json')
            events30 = Path(str(prefix30) + '_issue75_acquisition_events.json')
            assert read(raw30)['samples'] == datasets[label]['samples'], label
            events144 = work / f'{label}_test_issue75_progression_balance_144_issue75_acquisition_events.json'
            assert read(events30)['events'] == read(events144)['events'], label
            evidence[label]['fps30'] = dict(passed=result30['passed_count'], failed=result30['failed_count'],
                                             exit_code=result30['exit_code'], raw_sha256=sha(raw30),
                                             events_sha256=sha(events30), log_sha256=result30['log_sha256'],
                                             identical_four_phase_rows=540)
    output.write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(dict(output=str(output), bytes=output.stat().st_size, sha256=sha(output),
                         evidence=evidence, verification=summary.get('verification')), indent=2))
    for label, item in summary['candidates'].items():
        print(label, json.dumps(dict(normal=item['policies']['normal']['exit'], losses=item['losses'],
                                    potion_sources={s: item['policies'][s]['potion_sources'] for s in POLICIES})))


if __name__ == '__main__':
    main()
