"""Summarize paired early acquisition experiments; never relabel target failures."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import statistics
import subprocess
import sys

from summarize_issue75_acceptance import TARGETS

POLICIES = ('normal', 'optimized', 'conservative')
PHASES = ('entry', 'pre_boss', 'exit', 'pre_descent')
METRICS = ('max_hp', 'hp', 'armor', 'current_armor', 'effective_damage')
SOURCES = ('ordinary', 'pity', 'boss_guaranteed', 'other_chest')
LABELS = ('early_baseline', 'early_swap', 'early_bias', 'early_only', 'early_common_half', 'early_common_full', 'opening_common_half')


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def distribution(values, target=None):
    result = dict(n=len(values), minimum=min(values), median=statistics.median(values), maximum=max(values))
    if target:
        lo, hi = target
        result.update(target=target, inside=sum(lo <= v <= hi for v in values), below=sum(v < lo for v in values), above=sum(v > hi for v in values))
    return result


def state_summary(state):
    return {**{k: state[k] for k in METRICS}, 'components': state['components']}


def summarize(data):
    result = {}
    for policy in POLICIES:
        rows = [r for r in data['samples'] if r['style'] == policy]
        floors = []
        for floor in range(1, 7):
            group = [r for r in rows if r['floor'] == floor]
            assert len(group) == 30 and all(r['reached'] and r['completed'] for r in group)
            phases = {phase: {metric: distribution([r[phase][metric] for r in group], TARGETS.get(metric, [None] * 6)[floor - 1])
                              for metric in METRICS} for phase in PHASES}
            rewards = [g for r in group for g in r['potions']['equipment_rewards']]
            equipped = [g for r in group for g in r['exit']['gear']]
            floors.append(dict(floor=floor, phases=phases,
                               attacks_including_procs=distribution([r['combat']['hits'] for r in group], TARGETS['hits'][floor - 1]),
                               generated_equipment=dict(Counter(f"{g['source']}:{g['rarity']}:{g['type']}:{g['id']}" for g in rewards)),
                               equipment_pickups=sum(r['potions']['equipment_collected'] for r in group),
                               equipped_items=dict(Counter(f"{g['source']}:{g['acquired_floor']}:{g['rarity']}:{g['id']}" for g in equipped))))
        runs = []
        for seed in data['seeds']:
            run = [r for r in rows if r['seed'] == seed]
            sources = {s: sum(r['potions'][s] for r in run) for s in SOURCES}
            total = sum(sources.values())
            collected = sum(r['potions']['picked_up'] for r in run)
            consumed = sum(r['potions']['consumed'] for r in run)
            ground = sum(r['potions']['ground'] for r in run)
            carried = run[-1]['exit']['potions']
            assert total == collected + ground and total + 1 == consumed + ground + carried
            runs.append(dict(seed=seed, generated=total, sources=sources, collected=collected, consumed_including_starter=consumed, ground=ground, final_inventory=carried))
        result[policy] = dict(floors=floors, potion_runs=runs,
                              potion_totals={key: sum(r[key] for r in runs) for key in ('generated', 'collected', 'consumed_including_starter', 'ground', 'final_inventory')},
                              potion_source_totals={s: sum(r['sources'][s] for r in runs) for s in SOURCES},
                              potion_medians={key: statistics.median(r[key] for r in runs) for key in ('generated', 'collected', 'consumed_including_starter')})
    return result


def crossings(data, events):
    results = []
    assert all(e['index'] == i for i, e in enumerate(events))
    for event in events:
        for phase in ('before', 'after'):
            state = event[phase]
            c = state['components']
            assert state['armor'] == min(12, sum(c[k] for k in ('hero_armor', 'helmet_armor', 'body_armor', 'weapon_armor', 'perk_armor')))
            assert abs(state['effective_damage'] - (c['hero_damage'] + c['weapon_damage'] + c['perk_damage']) * c['berserk_multiplier']) < 1e-5
    for row in data['samples']:
        if row['style'] != 'normal':
            continue
        run = [e for e in events if e['seed'] == row['seed'] and e['style'] == row['style'] and e['floor'] <= row['floor']]
        # Portal/descent events on this floor happen AFTER the compared exit.
        run = [e for e in run if e['floor'] < row['floor'] or e['stage'] not in ('portal_perk', 'descent')]
        for metric in ('armor', 'effective_damage'):
            if metric == 'effective_damage' and row['floor'] > 3:
                continue
            upper = TARGETS[metric][row['floor'] - 1][1]
            if row['exit'][metric] <= upper:
                continue
            first = next(e for e in run if e['before'][metric] <= upper < e['after'][metric])
            results.append(dict(seed=row['seed'], policy=row['style'], measured_floor=row['floor'], metric=metric, upper_target=upper,
                                carried_excess_at_entry=row['entry'][metric] > upper,
                                first_crossing={**{k: v for k, v in first.items() if k not in ('before', 'after')},
                                                'before': state_summary(first['before']), 'after': state_summary(first['after'])}))
    return results


def paired_changes(baseline, candidate):
    changes = []
    for a, b in zip(baseline['samples'], candidate['samples']):
        identity = ('seed', 'style', 'floor')
        assert all(a[k] == b[k] for k in identity)
        # Chests and boss drops are protected; ordinary type choice cannot alter
        # source/rarity/gate counts. These checks inspect actual spawned rewards.
        ra, rb = (r['potions']['equipment_rewards'] for r in (a, b))
        assert [g for g in ra if g['source'] != 'ordinary'] == [g for g in rb if g['source'] != 'ordinary']
        assert Counter((g['source'], g['rarity']) for g in ra) == Counter((g['source'], g['rarity']) for g in rb)
        assert a['potions']['boss_guaranteed'] == b['potions']['boss_guaranteed'] == 2
        phase_changes = {phase: {'before': {k: a[phase][k] for k in METRICS}, 'after': {k: b[phase][k] for k in METRICS}}
                         for phase in PHASES if any(a[phase][k] != b[phase][k] for k in METRICS)}
        if phase_changes or a['combat'] != b['combat']:
            changes.append({**{k: a[k] for k in identity},
                            'before': {k: a['exit'][k] for k in METRICS}, 'after': {k: b['exit'][k] for k in METRICS},
                            'attacks_before': a['combat']['hits'], 'attacks_after': b['combat']['hits'],
                            'phase_changes': phase_changes,
                            'gear_before': [g['id'] for g in a['exit']['gear']], 'gear_after': [g['id'] for g in b['exit']['gear']]})
    return changes


def python_regression(work):
    command = [sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_issue75_runner.py', '-v']
    process = subprocess.run(command, cwd=Path(__file__).resolve().parents[1], capture_output=True)
    output = process.stdout + process.stderr
    path = work / 'python_gate.log'
    path.write_bytes(output)
    assert process.returncode == 0 and re.search(rb'Ran 8 tests', output) and re.search(rb'\bOK\b', output)
    return dict(command=command, exit_code=process.returncode, passed=8, failed=0, log=path.name, log_sha256=digest(path))


def final_verification(work, baseline):
    executions = read(work / 'final_early_144_results.json') + read(work / 'final_early_long_30_results.json') + read(work / 'final_early_rest_30_results.json')
    assert len(executions) == 50
    pairs = []
    for fps in (30, 144):
        runs = [r for r in executions if r['fps'] == fps]
        assert len(runs) == 25 and len({r['suite'] for r in runs}) == 25
    for r in executions:
        assert r['exit_code'] == 0 and r['completion_marker'] and r['failed_count'] == 0 and not r['errors'] and not r['timeout']
        assert digest(work / r['log']) == r['log_sha256']
    for r in [r for r in executions if r['fps'] == 144]:
        other = next(x for x in executions if x['suite'] == r['suite'] and x['fps'] == 30)
        assert r['passed_count'] == other['passed_count']
        if r['trace_sha256']:
            assert r['trace_sha256'] == other['trace_sha256']
            pairs.append(dict(suite=r['suite'], sha256=r['trace_sha256']))
    for label, fps in [('final_early', 144), ('final_early_long', 30)]:
        path = work / f'{label}_test_issue75_progression_balance_{fps}_issue75_progression_after.json'
        assert read(path)['samples'] == baseline['samples']
        path = work / f'{label}_test_issue75_progression_balance_{fps}_issue75_acquisition_events.json'
        reference = work / 'early_baseline_test_issue75_progression_balance_144_issue75_acquisition_events.json'
        assert read(path) == read(reference)
    matrix = work / 'final_early_test_issue75_combat_pacing_144_issue75_combat_pacing.json'
    records = read(matrix)['measurements']
    assert len(records) == 84
    python_gate = python_regression(work)
    imports = read(work / 'final_import_144_results.json')
    assert len(imports) == 1 and imports[0]['exit_code'] == 0 and not imports[0]['errors'] and imports[0]['completion_marker']
    return dict(executions=executions, identical_trace_pairs=pairs, all_540_four_phase_records_unchanged=True,
                all_observed_transitions_identical=True, python_regression=python_gate, clean_import=imports,
                combat_matrix_raw_sha256=digest(matrix),
                real_scene_encounters_per_fps=len(records),
                representative_early_encounters=[r for r in records if r['variant'] == 'candidate' and r['floor'] <= 3])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work', type=Path, default=Path('.godot/issue75_early_gate'))
    parser.add_argument('--output', type=Path, default=Path('docs/issue75_early_balance_evidence.json'))
    parser.add_argument('--reference', type=Path, help='Optional retained pre-task raw production distribution to verify unchanged observation')
    parser.add_argument('--final-verification', action='store_true', help='Require and summarize all 50 final suite executions')
    args = parser.parse_args()
    loaded = {}
    for label in LABELS:
        path = args.work / f'{label}_test_issue75_progression_balance_144_issue75_progression_after.json'
        data = read(path)
        assert len(data['samples']) == 540 and len({(r['seed'], r['style'], r['floor']) for r in data['samples']}) == 540
        execution = read(args.work / f'{label}_144_results.json')
        assert len(execution) == 1
        assert execution[0]['exit_code'] == 0 and not execution[0]['errors'] and execution[0]['completion_marker'] and not execution[0]['timeout']
        loaded[label] = dict(data=data, raw_sha256=digest(path), execution=execution, statistics=summarize(data))
    baseline = loaded['early_baseline']['data']
    if args.reference:
        previous = read(args.reference)
        assert baseline['samples'] == previous['samples'], 'Observation must not change any of the previous 540 production records'
    events_path = args.work / 'early_baseline_test_issue75_progression_balance_144_issue75_acquisition_events.json'
    events = read(events_path)['events']
    onset = crossings(baseline, events)
    candidates = {}
    for label in LABELS[1:]:
        entry = loaded[label]
        stats = entry['statistics']
        sixth = stats['normal']['floors'][5]['phases']['exit']['effective_damage']
        candidates[label] = {k: v for k, v in entry.items() if k != 'data'}
        candidates[label]['paired_changes'] = paired_changes(baseline, entry['data'])
        candidates[label]['preserves_required_normal_floor_six_damage'] = sixth['median'] >= 8 and sixth['inside'] >= 16
        print(label, 'floor-six constraint', candidates[label]['preserves_required_normal_floor_six_damage'])
        for policy in POLICIES:
            print(policy, [(r['floor'], [(k, r['phases']['exit'][k]['median'], r['phases']['exit'][k]['inside']) for k in ('max_hp', 'armor', 'effective_damage')], r['attacks_including_procs']['median'], r['attacks_including_procs']['inside']) for r in stats[policy]['floors']])
    decisions = {
        'early_swap': 'REJECT: optimized floor-one armor median 5.5 to 6 and HP coverage 27 to 26/30.',
        'early_bias': 'REJECT: optimized floor-one damage coverage 5 to 4/30 and Orc coverage 12 to 11/30; conservative floor-six HP coverage 18 to 17/30.',
        'early_only': 'REJECT: normal floor-one armor median 5 to 6; HP coverage at floors one/six 27 to 26 and 19 to 18/30.',
        'early_common_half': 'REJECT: normal seed12 floor-five HP 19 to 11, potion HP gain 2 to 1; seed18 later potion HP gain 4 to 2.',
        'early_common_full': 'REJECT: removes Common body drops and retains the normal seed12/18 late HP regressions.',
        'opening_common_half': 'REJECT: narrowing to floor one still retains the normal seed12/18 late HP regressions; no reduction of failing medians.'}
    for label, reason in decisions.items():
        candidates[label]['decision'] = reason
        candidates[label]['paired_rows_checked'] = 540
    ordinary_kills = [sum(r['defeated_enemies'] for r in baseline['samples'] if r['style'] == 'normal' and r['seed'] == seed) for seed in baseline['seeds']]
    evidence = dict(starting_commit='53664cf2e14c014edb0d334a05114400453b5300', engine='4.7.2.stable.official.ed1daf0bf',
                    classification='Controlled assumed-clear production API scenarios; not interactive gameplay',
                    starting_ci='https://github.com/Gumaisme2005/Keep-Fighting-And-Earning/actions/runs/44722722113',
                    starting_ci_conclusion='success', previous_baseline_reproduced=bool(args.reference), previous_raw_sha256=digest(args.reference) if args.reference else None,
                    baseline={k: v for k, v in loaded['early_baseline'].items() if k != 'data'},
                    acquisition_events_sha256=digest(events_path), observed_transitions=len(events), first_excess_events=onset,
                    candidates=candidates, accepted_candidates=[], production_files_changed=[],
                    experiment_rule_basis='Issue #75 change 3 fixes ordinary equipment gate, rarity bands and item budgets; it does not mandate uniform per-type weights. Only ordinary type choices were varied under the user-authorized experiment scope. No chest/boss reward or item-budget change was assumed authorized.',
                    potion_spec_conflict=dict(generated_target=[10, 12], normal_eligible_kills=distribution(ordinary_kills), mandatory_pity_gap=45,
                                              boss_guarantees_per_six_floors=12, lower_bound_before_treasure=min(ordinary_kills) // 45 + 12),
                    notes=['Numerical target coverage is not the same as implementation assertion PASS.',
                           'equipment_rewards/equipment count generated offers; equipment_collected counts actual pickups. New summaries keep these separate.',
                                                  'Orc attacks include criticals/procs; input/combo/skill/spirit remain separately measured by real scenes.',
                                                  'Raw logs and complete event streams stay in ignored .godot workspace.'])
    if args.final_verification:
        evidence['final_verification'] = final_verification(args.work, baseline)
    args.output.write_text(json.dumps(evidence, indent=2) + '\n', encoding='utf-8', newline='\n')
    print('Reference reproduction:', bool(args.reference), '; all candidate source/rarity/chest invariants PASS;', len(onset), 'exact first-excess events recorded')


if __name__ == '__main__':
    main()
