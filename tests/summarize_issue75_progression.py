from pathlib import Path
import json, statistics

DOC = Path('docs')
before = json.loads((DOC/'issue75_progression_distribution_before.json').read_text(encoding='utf-8'))
after = json.loads((DOC/'issue75_progression_distribution_after.json').read_text(encoding='utf-8'))
targets = {
    'max_hp': [[5,7],[8,10],[11,14],[15,19],[19,25],[23,30]],
    'armor': [[2,3],[3,4],[4,6],[5,7],[7,9],[8,10]],
    'effective_damage': [[1,2],[2,3],[3,5],[5,7],[7,9],[8,10]],
    'hits': [[2,4],[3,4],[3,4],[3,3],[3,3],[3,3]],
}
def distribution(values, target=None, total=30):
    result = {'n':len(values),'unreached':total-len(values), 'minimum':min(values) if values else None,
              'median':statistics.median(values) if values else None,'maximum':max(values) if values else None,'target':target}
    if target:
        lo,hi=target
        result.update(inside=sum(lo<=x<=hi for x in values),weak_outliers=sum(x<lo for x in values),
                      strong_outliers=sum(x>hi for x in values),acceptance=sum(lo<=x<=hi for x in values)/total)
    return result
summary = {'schema':'issue75_statistics_v2','sample_size':30,'styles':{},'notes':[
    'Targets do not specify entry/exit; both are reported. Original three-seed measurements were exits before portal perk/descent.',
    'Approximate three-hit target uses exact three as a reference statistic, never a required per-seed assertion.',
    'Ranges and acceptance use all 30 seeds; unreachable floors remain explicit and are excluded from numerical ranges.',
    'Controlled event models are not full played runs; stationary potion math is an estimate, not an observation.'
]}
for style in ['normal','optimized','conservative']:
    floors=[]
    for floor in range(1,7):
        out={'floor':floor,'before':{},'after':{}}
        for label,data in [('before',before),('after',after)]:
            rows=[r for r in data['samples'] if r['style']==style and r['floor']==floor and r.get('reached',True)]
            for phase in ['entry','exit']:
                out[label][phase]={}
                for metric in ['max_hp','hp','armor','current_armor','base_damage','effective_damage','potions','potion_hp','floor_hp']:
                    out[label][phase][metric]=distribution([r[phase][metric] for r in rows],targets.get(metric,[None]*6)[floor-1])
            out[label]['combat']={}
            for metric in ['orc_hp','hits','incoming','penetration','first_hp_loss','idle_hits_to_death']:
                out[label]['combat'][metric]=distribution([r['combat'][metric] for r in rows if 'combat' in r],targets.get(metric,[None]*6)[floor-1])
            out[label]['completed']=sum(r['completed'] for r in rows)
            out[label]['potions']={k:distribution([r['potions'][k] for r in rows]) for k in
                ['ordinary','pity','boss_guaranteed','other_chest','picked_up','capacity_rejected','consumed','ground','healing_restored','hp_granted','emergency_uses','hp_lost']}
        floors.append(out)
    totals={}
    for label,data in [('before',before),('after',after)]:
        runs=[]
        for seed in data['seeds']:
            rows=[r for r in data['samples'] if r['style']==style and r['seed']==seed and r.get('reached',True)]
            sums={k:sum(r['potions'][k] for r in rows) for k in ['ordinary','pity','boss_guaranteed','other_chest','picked_up','capacity_rejected','consumed','ground','emergency_uses','healing_restored']}
            sums['spawned_total']=sum(sums[k] for k in ['ordinary','pity','boss_guaranteed','other_chest'])
            sums['ordinary_defeats']=sum(r['defeated_enemies'] for r in rows)
            sums['remaining_inventory']=rows[-1]['exit']['potions'] if rows else 0
            sums['floor6_completed']=any(r['floor']==6 and r['completed'] for r in rows)
            runs.append(sums)
        totals[label]={k:distribution([r[k] for r in runs]) for k in runs[0]}
    summary['styles'][style]={'floors':floors,'run_totals':totals}
(DOC/'issue75_progression_statistics.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8',newline='\n')

def span(d):
    return f"{d['minimum']:g}/{d['median']:g}/{d['maximum']:g}" if d['n'] else 'unreached'
def coverage(d): return f"{d['inside']}/30 ({d['acceptance']:.0%})"
lines=['# Issue #75: 30-seed progression distributions','',
       'Controlled production-system event scenarios; no interactive or autonomous full run. Values are minimum / median / maximum.', '',
       'All raw rows, equipment identities/rarities, perks, current HP/armor, source accounting and manifest are included in the adjacent JSON evidence. Statistics include both entry and exit values for every policy.','']
for metric,title in [('max_hp','Maximum HP'),('armor','Maximum armor'),('effective_damage','Effective basic attack damage')]:
    lines += [f'## {title}','', '| Policy | Floor | Target | Before entry | After entry | Entry inside | Before exit | After exit | Exit inside | Exit weak / strong |',
              '|---|---:|---|---|---|---|---|---|---|---|']
    for style,info in summary['styles'].items():
        for f in info['floors']:
            a,b=f['after'],f['before']; en=a['entry'][metric]; ex=a['exit'][metric]
            lines.append(f"| {style} | {f['floor']} | {targets[metric][f['floor']-1]} | {span(b['entry'][metric])} | {span(en)} | {coverage(en)} | {span(b['exit'][metric])} | {span(ex)} | {coverage(ex)} | {ex['weak_outliers']} / {ex['strong_outliers']} |")
    lines.append('')
lines += ['## Potion source accounting','', 'Counts are per completed six-floor model run. Ground counts sum distinct units abandoned on each floor; capacity rejection counts each unit once. The starter potion is not a spawned reward.','',
          '| Policy | Random enemy | Forced pity | Boss guarantee | Ordinary chest | Total spawned | Pickups | Consumed | Capacity rejected | Ground | Exit inventory | Emergency uses |',
          '|---|---|---|---|---|---|---|---|---|---|---|']
for style,info in summary['styles'].items():
    r=info['run_totals']['after']
    keys=['ordinary','pity','boss_guaranteed','other_chest','spawned_total','picked_up','consumed','capacity_rejected','ground','remaining_inventory','emergency_uses']
    lines.append('| '+style+' | '+' | '.join(span(r[k]) for k in keys)+' |')
lines += ['','## Per-floor potion accounting','', '| Policy | Floor | Random enemy | Forced pity | Boss guarantee | Other chest | Pickups | Consumed | Left on floor |', '|---|---:|---|---|---|---|---|---|---|']
for style,info in summary['styles'].items():
    for f in info['floors']:
        r=f['after']['potions']; keys=['ordinary','pity','boss_guaranteed','other_chest','picked_up','consumed','ground']
        lines.append('| '+style+f" | {f['floor']} | "+' | '.join(span(r[k]) for k in keys)+' |')
lines += ['','## Combat measurements','', 'These are isolated production callbacks and primary-hit calculations, not survival seconds. Combo finishers, skills and spirit shots are excluded from the basic-hit count. Idle death probes exclude deferred retaliation; the separate nine-Orc safety test includes live Thorns/Armor Break effects.','',
          '| Policy | Floor | Orc HP | Incoming damage | Penetration | Actual primary hits | Accepted hits to death |', '|---|---:|---|---|---|---|---|']
for style,info in summary['styles'].items():
    for f in info['floors']:
        r=f['after']['combat'];keys=['orc_hp','incoming','penetration','hits','idle_hits_to_death']
        lines.append('| '+style+f" | {f['floor']} | "+' | '.join(span(r[k]) for k in keys)+' |')
lines.append('')
(DOC/'ISSUE_75_PROGRESSION_DISTRIBUTIONS.md').write_text('\n'.join(lines),encoding='utf-8',newline='\n')
print('Wrote statistics for 30 seeds x 3 policies x 6 floors, before and after')
for style,info in summary['styles'].items():
    print(style)
    for f in info['floors']:
        hp=f['after']['exit']['max_hp']
        print(f['floor'], span(hp),coverage(hp))
    print('potions',span(info['run_totals']['after']['spawned_total']))
