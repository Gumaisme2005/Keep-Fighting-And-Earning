# KEEP FIGHTING AND EARNING — DOCUMENTATION REPOSITORY

This directory contains the technical documentation, design specifications, architecture models, security assessments, benchmark reports, and automated quality assurance catalogs for **Keep Fighting And Earning**.

---

## 1. Documentation Map and Navigation Index

| Document | Primary Focus | Target Audience | Key Contents |
| :--- | :--- | :--- | :--- |
| [`GAME_DESIGN_DOCUMENT.md`](GAME_DESIGN_DOCUMENT.md) | Game Design & Gameplay Systems | Designers, Evaluators, Players | Complete specification of all 8 champions, 6 enemies, 3 bosses, procedural generation, combat mechanics, 30 perks, 60Hz replays, hardware settings, and shop/event rooms. |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Software Architecture & Code Patterns | Engineers, Reviewers | High-level topology, singletons (`GameManager`, `BalanceConfig`, `SettingsManager`, `PerkManager`, `AudioManager`), polymorphic inheritance, and sequence diagrams. |
| [`TEST_SUITE_CATALOG.md`](TEST_SUITE_CATALOG.md) | Quality Assurance & Testing | QA, DevOps, Evaluators | Comprehensive catalog of all 16 automated headless test suites, test IDs (`UT-01..21b`, `PROP-01..05`, `SK-01..22`, `DR-01..49`), and invariant verification. |
| [`BALANCE_WORKFLOW.md`](BALANCE_WORKFLOW.md) | Data-Driven Balance Pipeline | Balance Designers, Modders | Architecture of `.tres` Custom Resources and `BalanceConfig.gd` (Single Source of Truth), dynamic buff/nerf procedures, and Miya balance case study. |
| [`BASE_COMMIT_ANALYSIS_AND_DIFF.md`](BASE_COMMIT_ANALYSIS_AND_DIFF.md) | Version Control & Integration | Lead Engineers, Maintainers | Detailed diff tables and alignment analysis preserving all base features from `d718e45` while merging the complete hero roster and refactored architecture. |
| [`BENCHMARK_REPORT.md`](BENCHMARK_REPORT.md) | Performance & Complexity Analysis | Performance Engineers | Empirical execution times across scales from 10 to 50 rooms, $O(T)$ wall optimization proof, P50/P95 latency, and frame budget compliance. |
| [`DUNGEON_FOG_AND_BALANCE.md`](DUNGEON_FOG_AND_BALANCE.md) | Environment & Dungeon Scaling | World Designers, DevOps | Minimap Fog of War, dynamic lighting, physical spike trap barriers, floor-by-floor difficulty escalation, and Docker container execution. |
| [`SECURITY.md`](SECURITY.md) | Application Security & Memory Defense | Security Auditors, Reviewers | Threat models (`SEC-01` to `SEC-04`), seed whitelist sanitization, replay buffer bounding, memory DoS defense, and save file quotas. |
| [`SEED_BUG_ISSUES.md`](SEED_BUG_ISSUES.md) | Defect Triage & Seed Reproduction | QA Engineers, Developers | Empirical case studies of bugs reproduced 100% via fixed seeds (`ALOALO1234`, `BUG_PILLAR_SPAWN_42`, `BOSS_RUSH_2026`), root causes, and fixes. |
| [`WEREWOLF_TEST_REPORT.md`](WEREWOLF_TEST_REPORT.md) | Specific Entity Test Evidence | Reviewers, QA | 50-check functional and integration test evidence for the Werewolf enemy (wind-up telegraph, interrupt, 95px fixed pounce clamping). |
| [`images/`](images/) | Graphic Asset Repository | Designers, Documentarians | Pixel-art character sprites and icons for heroes, enemies, and bosses embedded across project documentation. |

---

## 2. Directory Layout and Visual Assets

```
docs/
|-- images/                           # Pixel art sprite repository
|   |-- hero_pyrois.png               # Knight sprite
|   |-- hero_olaf.png                 # Berserker sprite
|   |-- hero_miya.png                 # Archer sprite
|   |-- hero_charlotte.png            # Ranger sprite
|   |-- enemy_orc.png                 # Orc sprite
|   |-- enemy_armored_orc.png         # Armored Orc sprite
|   |-- enemy_skeleton.png            # Skeleton sprite
|   |-- enemy_skeleton_archer.png     # Skeleton Archer sprite
|   |-- enemy_vampire.png             # Vampire sprite
|   |-- boss_necromancer.png          # Necromancer boss sprite
|   `-- boss_orc_rider.png            # Orc Rider boss sprite
|-- ARCHITECTURE.md                   # System architecture and codebase design
|-- BALANCE_WORKFLOW.md               # Data-driven balance and resource pipeline
|-- BASE_COMMIT_ANALYSIS_AND_DIFF.md  # Git baseline alignment and diff tables
|-- BENCHMARK_REPORT.md               # Dungeon generator performance measurements
|-- DUNGEON_FOG_AND_BALANCE.md        # Lighting, fog of war, traps, and Docker
|-- GAME_DESIGN_DOCUMENT.md           # Master Game Design Document (GDD)
|-- README.md                         # Documentation navigation index (this file)
|-- SECURITY.md                       # Threat model and input/memory validation
|-- SEED_BUG_ISSUES.md                # Seed-reproducible bug archive and fixes
|-- TEST_SUITE_CATALOG.md             # Complete QA catalog of all 16 test suites
`-- WEREWOLF_TEST_REPORT.md           # Werewolf test report and raw console logs
```

---

## 3. Maintenance and Documentation Standards

All documents in this directory adhere to standard engineering documentation rules:
1. **Zero Unicode Emojis:** Project documentation strictly prohibits the use of emoji symbols to maintain an objective, academic, and professional standard.
2. **Deterministic References:** All seed examples and code paths must reference exact repository locations and reproducible seed strings.
3. **Traceability:** Bug reports and balance updates must link directly to automated test assertions (`UT-*`, `PROP-*`, `SK-*`, `DR-*`).
