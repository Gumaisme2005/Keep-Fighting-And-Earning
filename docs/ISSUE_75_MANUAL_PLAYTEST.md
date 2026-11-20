# Issue #75: reproducible interactive playtest

Status: **NOT PERFORMED**. The automated matrix uses actual Miyabi/Orc scenes in a stationary-target arena. It does not navigate six dungeon floors, fight bosses autonomously, or demonstrate player survival. This environment has no interactive keyboard/mouse control tool for a human-style playthrough.

Use Godot `4.7.2.stable.official.ed1daf0bf`, branch `fix/issue-75-game-balance`, character **Hoshimi Miyabi**. Record the tested commit and build. Start with seed `ISSUE75-DISTRIBUTION-14`, then repeat with `ISSUE75-DISTRIBUTION-04` and `ISSUE75-DISTRIBUTION-20` to inspect the documented late equipment tradeoffs. Use an isolated save/profile; do not erase a player's existing save.

Controls: WASD for movement, left click/hold for the three-hit combo, Shift for dash, hold/release right click for Frost Wave, Q for Frost Bloom; use the actual inventory/hotbar for potions and equipment. Keep physics at 60 ticks/s. Repeat one route at render caps 30 and 144 with comparable inputs. Exact loot in a manual run can differ from the controlled reward model because exploration, low HP and Necromancer actions/summons consume different source streams.

## Record four distinct phases on every floor

| Floor | Entry HP/max, armor/max, raw damage | Before boss rewards | Exit after both chests | After portal perk, before descent | Potions generated/collected/used/ground | Inputs to kill Orc | Damage sources/notes |
|---:|---|---|---|---|---|---|---|
| 1 | | | | | | | |
| 2 | | | | | | | |
| 3 | | | | | | | |
| 4 | | | | | | | |
| 5 | | | | | | | |
| 6 | | | | | | | |

Also record item identity, rarity, acquisition floor/source, active perks, deaths/revivals, boss identity and whether the floor was completed. Record a failed run as a failed run; do not fill unreachable floors with assumed rewards.

## Required observations

1. **Initial state and equipment:** Miyabi starts at 4 HP / 2 armor / 1 damage. Record every upgrade. While wounded, equip/unequip one HP item three times: capacity changes, current HP never rises from equipping, and removal clamps excess HP. Repeat after potion and descent HP gains; those earned terms must remain present exactly once.
2. **Potion rules:** Common/Rare/Heroic/Legendary heal 3/5/8/12; Heroic/Legendary capacity gains are bounded by +4 per run. Using any potion blocks every potion for eight seconds. The bag accepts no more than four units total; refused units stay on the ground. Count the starter separately. Do not mark 10–12 generated units PASS under an unapproved collected/consumed interpretation.
3. **Armor:** ordinary damage depletes current armor without removing capacity. Baseline regeneration waits five seconds, then grants one armor per 1.5 seconds; authored delay-reduction perks are separate. Maximum armor stays at 12. A normal Orc's first unblocked hit at floor four requests 4 damage, costing 1 HP and 3 armor if enough armor remains; at floor six it requests 5, costing 2 HP and 3 armor. Do not dash during this check.
4. **Combat pacing:** measure separate fights using spaced single clicks, held combo, spirit only, Q, charged right click and the combined kit. Record input edges, executed swings/skill casts, criticals and extra proc/skill/spirit damage. A held button is one press even when it initiates multiple swings. Never infer actual hits from `ceil(Orc HP / raw damage)` alone.
5. **Passive defenses:** if Mythic armor or Armor Break is obtained naturally, verify armor-only absorption does not trigger Thorns, positive HP loss does, and nearby enemies do not all disappear from one break. Thorns is limited to two nearby targets with a two-second cooldown; Armor Break has a six-second cooldown. Do not grant artificial equipment while claiming natural progression.
6. **Rewards and vitality:** each boss victory produces the existing two chests, each retaining its Rare potion guarantee and original equipment gate/rolls. Repeated overlap with the same open chest must not create more rewards. Clearing and descending floors 1–5 grants +2 earned max/current HP once, capped at +10; revisiting or repeated callbacks must not duplicate it. Floor-six descent does not exceed the cap.
7. **Late weapon pacing:** in floors 5–6, ordinary enemies can supply same-rarity weapon upgrades more often; this is probabilistic, not a guaranteed item for each seed/run. Existing weapon opportunities are retained. Boss/chest outcomes and floors 1–4/7+ retain their original selection rules. Inspect defensive/HP losses as well as damage gains.
8. **Recovery and stability:** record potion scarcity after taking damage, armor depletion under crowd pressure, recovery between rooms and whether boss fights are fair. Inspect the debugger/log for parser/runtime/freed-node errors, duplicate rewards and broken transitions. A revival consumed in real gameplay must remain consumed; diagnostic probes must not consume it for the live player.

Completion requires actual observations for all reachable phases, the run's survival outcome, a review of floor 1–6 numerical failures against unchanged targets, and maintainer review. A crash-free run or green CI alone does not establish balance acceptance.
