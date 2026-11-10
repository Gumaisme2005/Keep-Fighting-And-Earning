"""Summarize actual seventh-commit evidence without replacing sixth-commit baselines."""
from collections import Counter
import json
from pathlib import Path
import statistics

DOC = Path(__file__).resolve().parents[1] / 'docs'
TARGETS = {
    'max_hp': [[5, 7], [8, 10], [11, 14], [15, 19], [19, 25], [23, 30]],
    'armor': [[2, 3], [3, 4], [4, 6], [5, 7], [7, 9], [8, 10]],
    'effective_damage': [[1, 2], [2, 3], [3, 5], [5, 7], [7, 9], [8, 10]],
    'hits': [[2, 4], [3, 4], [3, 4], [3, 3], [3, 3], [3, 3]],
}
SOURCES = ['ordinary', 'pity', 'boss_guaranteed', 'other_chest']


def read(name):
    return json.loads((DOC / name).read_text(encoding='utf-8'))


def dist(values, target=None):
    result = dict(n=len(values), missing=30-len(values), minimum=min(values) if values else None,
                  median=statistics.median(values) if values else None, maximum=max(values) if values else None,
                  target=target, percent_inside=None, outlier_seeds=None)
    if target:
        inside = sum(target[0] <= x <= target[1] for x in values)
        result.update(percent_inside=inside / 30 * 100, outlier_seeds=len(values)-inside,
                      below=sum(x < target[0] for x in values), above=sum(x > target[1] for x in values))
    return result


def span(d):
    return '/'.join(f'{d[key]:g}' for key in ('minimum', 'median', 'maximum')) if d['n'] else 'unreached'


def main():
    datasets = {name: read('issue75_acceptance_' + name + '.json') for name in ('before', 'after', 'proposal')}
    summary = {'classification': 'Controlled production-event scenarios, not interactive or autonomous playthroughs',
               'sample_size_per_policy': 30, 'before_commit': '2d8ffe5d808087d63b5499da976efd249dd60740',
               'proposal_is_production': False, 'policies': {},
               'notes': ['Existing v2 baseline files remain untouched.',
                         'No tester target means percent_inside and outlier_seeds are null, not an invented acceptance rule.',
                         'Potion sources after stack merging use FIFO within identical potion names; source is interchangeable in gameplay.',
                         'Available = generated plus carried inventory at entry; discarded = distinct ground units abandoned on descent.',
                         'Actual before execution used the starting production code with its original scenario harness.']}
    lines = ['# Seventh-commit acceptance distributions', '',
             'Actual starting production versus corrected production, using the original 30 seeds and unchanged policies. '
             'Values are minimum / median / maximum; both entry and exit phases appear below. '
             'These are controlled reward/combat scenarios, with successful boss clears assumed, not played survival runs.', '',
             'The treasure proposal is test-only and changes the single legacy Legendary sword entry to Common on floor 1, '
             'Rare on floor 2, Heroic on floors 3–4, then preserves it from floor 5. '
             'All six entry weights, the 80% gate, chest counts, visuals, potions and boss rewards remain unchanged. '
             '**This conflicts with preserved treasure rewards and is not enabled in gameplay.**', '']
    for policy in ('normal', 'optimized', 'conservative'):
        floors = []
        for floor in range(1, 7):
            groups = {name: [r for r in data['samples'] if r['style'] == policy and r['floor'] == floor and r.get('reached', True)]
                      for name, data in datasets.items()}
            entry = {'floor': floor, 'metrics': {}, 'completed': {n: sum(r['completed'] for r in rs) for n, rs in groups.items()}}
            for phase, keys in [('entry', ['max_hp', 'hp', 'armor', 'current_armor', 'effective_damage', 'base_damage', 'potions', 'floor_hp', 'potion_hp']),
                                ('exit', ['max_hp', 'hp', 'armor', 'current_armor', 'effective_damage', 'base_damage', 'potions', 'floor_hp', 'potion_hp']),
                                ('combat', ['orc_hp', 'hits', 'incoming', 'penetration', 'first_hp_loss', 'idle_hits_to_death'])]:
                for metric in keys:
                    target = TARGETS.get(metric, [None]*6)[floor-1]
                    values = {name: dist([r[phase][metric] for r in rs if phase in r], target) for name, rs in groups.items()}
                    values['median_difference'] = values['after']['median'] - values['before']['median']
                    values['change_source'] = 'No numerical acquisition or scaling change; player identity/cache fixes affect previously incorrect group/world ordering.'
                    entry['metrics'][phase + '.' + metric] = values
            entry['equipment_sources'] = dict(Counter(it['source'] for r in groups['after'] for it in r['exit']['gear']))
            entry['equipment_rarities'] = dict(Counter(str(it['rarity']) for r in groups['after'] for it in r['exit']['gear']))
            entry['legacy_sword_exit_seeds'] = sum(any(it['id'] == 'legacy:Legendary/mystic_sword.tres' for it in r['exit']['gear']) for r in groups['after'])
            entry['potion_metrics'] = {}
            for metric in SOURCES + ['picked_up', 'consumed', 'ground', 'capacity_rejected', 'healing_restored', 'emergency_uses']:
                entry['potion_metrics'][metric] = {name: dist([r['potions'][metric] for r in rs]) for name, rs in groups.items()}
            entry['potion_metrics']['generated'] = {name: dist([sum(r['potions'][s] for s in SOURCES) for r in rs]) for name, rs in groups.items()}
            entry['potion_metrics']['available'] = {name: dist([r['entry']['potions'] + sum(r['potions'][s] for s in SOURCES) for r in rs]) for name, rs in groups.items()}
            floors.append(entry)
        economy = {}
        run_counts = []
        for seed in datasets['after']['seeds']:
            rows = [r for r in datasets['after']['samples'] if r['style'] == policy and r['seed'] == seed]
            counts = {}
            for source in ['starter'] + SOURCES:
                generated = 1 if source == 'starter' else sum(r['potions'][source] for r in rows)
                collected = 1 if source == 'starter' else sum(r['potions']['collected_by_source'][source] for r in rows)
                consumed = sum(r['potions']['consumed_by_source'][source] for r in rows)
                discarded = sum(r['potions']['discarded_by_source'][source] for r in rows)
                inventory = rows[-1]['potions']['inventory_by_source'][source]
                assert generated == consumed + discarded + inventory
                assert generated == collected + discarded
                counts[source] = dict(generated=generated, available=generated, collected=collected, consumed=consumed,
                                      discarded=discarded, exit_inventory=inventory)
            run_counts.append(counts)
        for source in ['starter'] + SOURCES:
            economy[source] = {key: dict(total=sum(run[source][key] for run in run_counts),
                                        distribution=dist([run[source][key] for run in run_counts]))
                               for key in run_counts[0][source]}
        summary['policies'][policy] = dict(floors=floors, potion_sources=economy)
        lines += [f'## {policy}: phase-matched progression', '',
                  '| Phase / metric | Floor | Before | After | Inside target | Outliers | Median delta | Proposal |',
                  '|---|---:|---|---|---:|---:|---:|---|']
        for phase, metric in [('entry', 'max_hp'), ('exit', 'max_hp'), ('entry', 'armor'), ('exit', 'armor'),
                              ('entry', 'effective_damage'), ('exit', 'effective_damage'), ('combat', 'hits')]:
            for f in floors:
                d = f['metrics'][phase + '.' + metric]
                lines.append(f"| {phase} {metric} | {f['floor']} | {span(d['before'])} | {span(d['after'])} | "
                             f"{d['after']['percent_inside']:.1f}% | {d['after']['outlier_seeds']}/30 | {d['median_difference']:g} | {span(d['proposal'])} |")
        lines += ['', f'## {policy}: potion units by source, exact totals across 30 six-floor scenarios', '',
                  'Starter is pre-run inventory, excluded from generated reward totals. Units are offered once. '
                  'Available over a complete route means distinct supplied units; per-floor availability also includes carried units.', '',
                  '| Source | Generated / supplied | Collected | Consumed | Discarded on floors | Exit inventory |',
                  '|---|---:|---:|---:|---:|---:|']
        for source, counts in economy.items():
            lines.append('| ' + source + ' | ' + ' | '.join(str(counts[key]['total']) for key in ('generated', 'collected', 'consumed', 'discarded', 'exit_inventory')) + ' |')
        lines += ['', '| Floor | Equipped-item sources | Legacy sword seeds |', '|---:|---|---:|']
        for f in floors:
            lines.append(f"| {f['floor']} | {f['equipment_sources']} | {f['legacy_sword_exit_seeds']}/30 |")
        lines.append('')
    (DOC / 'issue75_acceptance_statistics.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8', newline='\n')
    path = DOC / 'ISSUE_75_PROGRESSION_DISTRIBUTIONS.md'
    old = path.read_text(encoding='utf-8').split('<!-- PRESERVED SIXTH-COMMIT DISTRIBUTIONS -->\n')[-1]
    path.write_text('\n'.join(lines) + '\n<!-- PRESERVED SIXTH-COMMIT DISTRIBUTIONS -->\n' + old, encoding='utf-8', newline='\n')
    print('Validated potion conservation for all 90 runs; wrote full before/after/proposal statistics.')


if __name__ == '__main__':
    main()
