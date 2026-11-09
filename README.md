# Keep Fighting And Earning — Procedural Dungeon Action Roguelike

Keep Fighting And Earning is a 2D top-down action roguelike developed with Godot Engine 4.7. The project combines deterministic procedural dungeon generation, a 60Hz physics action replay engine, a dynamic data-driven balance configuration system, and a comprehensive 16-suite automated headless testing pipeline.

---

## 1. Core Technical Highlights

- **Deterministic PRNG Generation:** An alphanumeric seed drives an isolated Pseudo-Random Number Generator (PRNG). Identical seeds reproduce 100% identical room topologies, corridor trees, spike trap patterns, obstacle pillars, and entity spawns.
- **60Hz Physics Action Replay:** Records user inputs at a fixed 60Hz rate. Expeditions can be replayed frame-for-frame or taken over in real time for speedrun verification, strategy review, and automated regression testing.
- **Centralized Data-Driven Balance:** Combat parameters for all 8 heroes, 6 standard enemies, and 3 multi-phase bosses are managed centrally in `Scene/BalanceConfig.gd` backed by `.tres` Custom Resources.
- **Tactical Combat and Physics:** Features 360-degree cursor aiming, two-tier vitality (Health and regenerating Armor), spatial Line-of-Sight (LoS) raycasting, Minecraft-style stackable inventory (up to 16 units), and a 30-perk progression draft.
- **Complete Display and Performance Controls:** Hardware-synchronized FPS limiter (30, 60, 120, 144, unlimited, custom 20 to 360), 6 resolution presets (720p to 4K), 3 window modes, VSync toggles, and audio persistence.

---

## 2. System Architecture

The project employs a component-based architecture with centralized autoload singletons and decoupled entity inheritance. Full architectural diagrams and sequence flows are documented in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

```
Keep-Fighting-And-Earning/
|-- Assets/                   # Audio tracks, sound effects, character and environment sprites
|-- docs/                     # Technical specifications, benchmarks, design documents
|   |-- ARCHITECTURE.md       # System architecture and codebase design
|   |-- BALANCE_WORKFLOW.md   # Data-driven balance and resource pipeline
|   |-- BENCHMARK_REPORT.md   # Dungeon generator performance measurements
|   |-- GAME_DESIGN_DOCUMENT.md # Master Game Design Document (GDD)
|   |-- README.md             # Documentation navigation index
|   |-- SECURITY.md           # Threat model and input/memory validation
|   |-- SEED_BUG_ISSUES.md    # Seed-reproducible bug archive and fixes
|   `-- TEST_SUITE_CATALOG.md # Complete QA catalog of all 16 test suites
|-- Menu/                     # Main menu and pause menu interface scenes
|-- Scene/                    # Core gameplay scenes and scripts
|   |-- Balance/              # Data-driven .tres custom resources for units
|   |-- BalanceConfig.gd      # Single source of truth for combat parameters
|   |-- GameManager.gd        # Global state, seed pipeline, and replay controller
|   |-- SettingsManager.gd    # Hardware FPS, resolution, and window mode persistence
|   |-- PerkManager.gd        # 30-perk progression and drafting engine
|   |-- Character/            # Playable hero scenes and controllers (BasePlayer.gd)
|   |-- Enemies/              # Enemy and boss entity implementations (BaseEnemy.gd)
|   |-- Map/                  # Procedural dungeon generator, tilesets, and room management
|   `-- UI/                   # HUD, minimap, inventory, and character selection screens
|-- tests/                    # Automated headless test suites (16 test scenes)
|-- project.godot             # Godot Engine project configuration
|-- run_game.bat              # Script to launch the game client
`-- run_tests.bat             # Script to execute all 16 automated test suites
```

---

## 3. Playable Character Roster

The roster features eight distinct champions. All attributes are centrally declared in `Scene/BalanceConfig.gd` and documented in [`docs/GAME_DESIGN_DOCUMENT.md`](docs/GAME_DESIGN_DOCUMENT.md).

| Index | Champion | Class / Role | HP | Armor | Damage | Speed (px/s) | Primary Weapon & Signature Ability |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| 0 | **Miya** | Elven Archer | 3 | 1 | 1 | 165.0 | Galadhrim Bow (0.46s CD) • [Q] Orthanc Fire (area bomb) |
| 1 | **Olaf** | Dwarven Berserker | 6 | 1 | 2 | 160.0 | Greataxe of Moria (0.34s CD) • [Q] Durin's Wrath (2x damage) |
| 2 | **Pyrois** | White Tower Knight | 4 | 4 | 1 | 150.0 | Sword & Shield (0.30s CD) • [Q] Sovereign Rush (I-Frame charge) |
| 3 | **Charlotte** | Dunedain Shadow Ranger | 5 | 0 | 2 | 180.0 | Twin Blades (0.28s CD) • [Q] Triple Flurry • [RMB] Shadow Step |
| 4 | **Yugi / Atem** | Pharaoh Summoner | 5 | 1 | 1 | 150.0 | Millennium Puzzle • Charged summons • [Q] 5 Room Spells |
| 5 | **Doraemon** | 22nd-Century Specialist | 5 | 2 | 1 | 150.0 | 4D Pocket (20 gadgets) • [Q] 6 Friend Assists & 10 Supers |
| 6 | **Hoshimi Miyabi** | Frost Swordswoman | 4 | 2 | 1 | 160.0 | Frost Combo • [Shift] Dash • [Hold RMB] Wave • [Q] Frost Bloom |
| 7 | **Luong Tho** | Twin Gunblade Duelist | 5 | 2 | 1 | 155.0 | 3-Step Combo • [RMB] Twin Barrels • [Q] White Moon Form |

---

## 4. Enemies and Boss Encounters

### 4.1 Standard Enemies
- **Orc (`HP: 4`, `DMG: 2`, `SPD: 75`):** Melee frontline warrior patrolling chambers.
- **Armored Orc (`HP: 5`, `ARMOR: 6`, `DMG: 2 -> 4`):** Heavy vanguard; enrages upon armor depletion (+50% speed, 4 damage).
- **Skeleton (`HP: 3`, `DMG: 1`, `SPD: 110`):** Agile melee swarmer closing gaps in packs.
- **Skeleton Archer (`HP: 5`, `DMG: 2`, `SPD: 70`):** Tactical kiter; backs away within 85px and uses wall cover to shoot arrows.
- **Vampire (`HP: 5`, `DMG: 2`, `SPD: 85`):** High-speed aerial predator with life-steal melee strikes.
- **Werewolf (`HP: 5`, `DMG: 2 / 3`, `SPD: 175`):** Feral beast with close-range claw attacks and a 95px telegraphed pounce.

### 4.2 Multi-Phase Boss Encounters
- **Necromancer (Floor 1, 4, 7...):** Triple-phase spellcaster casting homing skulls, summoning skeleton minions, and erupting toxic rings.
- **Orc Rider (Floor 2, 5, 8...):** Heavy cavalry chieftain with 180-degree cleaves, telegraphed 4x speed Warg charges, and hurricane spins.
- **Skeleton King (Floor 3, 6, 9...):** Overlord of a 28x28 grand arena, invulnerable while 4 Soul Crystals remain, firing rotating laser grids.

---

## 5. Controls and User Guidance

| Input / Shortcut | Action | Description |
| :--- | :--- | :--- |
| `W, A, S, D` / `Arrow Keys` | Movement | Move champion in 8 directions (cardinal and diagonal). |
| `Mouse Cursor` | 360-Degree Aiming | Continuous directional aim for attacks, spells, dashes, and projectiles. |
| `Left Mouse Button (LMB)` | Primary Attack | Basic strike / arrow fire / melee combo. Holding LMB continuously attacks. |
| `Right Mouse Button (RMB)` | Secondary Action | Secondary skill (dash, twin barrels, charged summon, gadget 2). |
| `Q` | Signature Skill | Casts active champion ability (indicated by HUD cooldown timer). |
| `E` | Interact / Collect | Open treasure chests, collect dropped world items, enter portals. |
| `Tab` / `I` / `B` | Inventory | Toggle 16-slot Backpack and Equipment screen. |
| `1` through `9` | Hotbar | Quick-use items in active hotbar slots. |
| `G` / `Right-Click` in Bag | Drop Item | Drop item onto floor as a collectible world pickup. |
| `H` / `F1` | Manual & Guide | Open in-game Guide modal with controls, active hero dossier, and lore. |
| `M` | Minimap Toggle | Switch between compact radar and expanded tactical dungeon map. |
| `N` | Audio Mute | Toggle background music and sound effects. |
| `Escape` | Pause / Back | Close topmost modal (Settings -> Guide -> Bag) or pause the expedition. |

---

## 6. Execution Instructions

### 6.1 Prerequisites
- Godot Engine 4.7.2 or later (Console / Headless binary recommended for automated testing).

### 6.2 Running the Game Client
Launch via Godot Engine or execute:
```cmd
run_game.bat
```

### 6.3 Running Automated Test Suites
Execute all 16 automated test suites sequentially:
```cmd
run_tests.bat
```
Or run individual test scenes headlessly:
```cmd
godot --headless --path . "res://tests/test_dungeon_generator_unit.tscn"
godot --headless --path . "res://tests/test_dungeon_properties.tscn"
godot --headless --path . "res://tests/test_orc_battle.tscn"
godot --headless --path . "res://tests/benchmark_dungeon_generator.tscn"
godot --headless --path . "res://tests/test_skeleton_king.tscn"
godot --headless --path . "res://tests/test_doraemon.tscn"
godot --headless --path . "res://tests/test_yugi.tscn"
godot --headless --path . "res://tests/test_werewolf.tscn"
godot --headless --path . "res://tests/test_moba_hud_and_inventory.tscn"
godot --headless --path . "res://tests/test_miyabi.tscn"
godot --headless --path . "res://tests/test_luong_tho.tscn"
godot --headless --path . "res://tests/test_projectile_obstacles.tscn"
godot --headless --path . "res://tests/test_archer_combat_lifecycle.tscn"
godot --headless --path . "res://tests/test_perk_system.tscn"
godot --headless --path . "res://tests/test_replay_security.tscn"
godot --headless --path . "res://tests/test_settings_and_ui.tscn"
```

### 6.4 Running via Docker
Run headless tests in an isolated Linux container:
```bash
docker compose run --rm test
```
Or launch the WebAssembly client on port 8080:
```bash
docker compose up game --build
```

---

## 7. Automated Quality Assurance and Test Catalog

The project maintains a 100% pass rate across 16 test suites. Detailed assertion breakdowns are documented in [`docs/TEST_SUITE_CATALOG.md`](docs/TEST_SUITE_CATALOG.md).

| Suite # | Test Suite Name | Assertions | Core Quality Assurance Scope |
| :---: | :--- | :---: | :--- |
| 1 | Unit Tests (`UT-01..21b`) | 28 | Room constraints, BFS optimality, LoS wall blocking, dynamic balance sync. |
| 2 | Property Invariants (`PROP-01..05`) | 11 (100 Seeds) | Determinism, graph connectivity, flood-fill walkability, safe entity spawns. |
| 3 | Combat Hitbox Regression | 5 | 360-degree rotational accuracy across 5 cardinal/diagonal directions. |
| 4 | Dungeon Benchmark | 25 iter | Generation latency across 10 to 50 rooms (~130ms average for 16 rooms). |
| 5 | Skeleton King Arena (`SK-01..22`) | 22 | Soul Crystal invulnerability, laser grid cycles, enrage phases, arena unlock. |
| 6 | Doraemon Hero Tests (`DR-01..49`) | 49 | 20 gadgets across 10 pages, 6 friend assists, 10 supers, crate blocking. |
| 7 | Yugi Atem Hero Tests | All Passed | Directional monster strikes, charged summons, guard stance, 5 room spells. |
| 8 | Werewolf Functional Tests | 50 | Claw attacks, pounce warning telegraphs, damage interruption, 95px bound. |
| 9 | MOBA HUD & Inventory Stacking | 157 | Numeric progress bars, potion stacking up to 16, hotbar swapping, item drop. |
| 10 | Hoshimi Miyabi Hero Tests | 18 | 3-hit frost combo, dash slash, Frost Wave, Frost Bloom, ice spirit AI. |
| 11 | Luong Tho Hero Tests | 15 | 3-step weapon combo, Twin Barrels, White Moon transformation. |
| 12 | Projectile Obstacle Regression | 11 | Solid wooden crates blocking projectiles, ricochet bounces, transparent decor. |
| 13 | Skeleton Archer Combat Lifecycle | 12 | Archer AI kiting, 85px standoff distance, wall navigation, arrow flight. |
| 14 | Perk Progression System | 37 | 30 perks across 4 rarities, deterministic drafting, deduplication, revivals. |
| 15 | Replay Security & Memory Limits | 39 | 10-replay FIFO hard cap, 3600 frames, stationary compression, 2MB cap. |
| 16 | Settings, Graphics & UI Tests | 100 | FPS limiter, resolutions, window modes, vsync, audio, UI dossier scrolling. |

---

## 8. Technical Documentation Index

For deep architectural analyses, design specifications, and security audits, refer to the documents in [`docs/`](docs/):

- [`docs/README.md`](docs/README.md): Master Navigation Index and directory overview.
- [`docs/GAME_DESIGN_DOCUMENT.md`](docs/GAME_DESIGN_DOCUMENT.md): Comprehensive Game Design Document (GDD) with all 8 heroes, bestiary, shop & event room design.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): Software architecture, singletons, entity hierarchy, generation pipeline, and sequence diagrams.
- [`docs/TEST_SUITE_CATALOG.md`](docs/TEST_SUITE_CATALOG.md): Complete QA catalog of all 16 automated test suites.
- [`docs/BALANCE_WORKFLOW.md`](docs/BALANCE_WORKFLOW.md): Data-driven balance guide via Custom Resources (`.tres`).
- [`docs/BASE_COMMIT_ANALYSIS_AND_DIFF.md`](docs/BASE_COMMIT_ANALYSIS_AND_DIFF.md): Base commit `d718e45` preservation and diff tables.
- [`docs/BENCHMARK_REPORT.md`](docs/BENCHMARK_REPORT.md): Empirical generator performance benchmarks across 10 to 50 rooms.
- [`docs/DUNGEON_FOG_AND_BALANCE.md`](docs/DUNGEON_FOG_AND_BALANCE.md): Minimap Fog of War, lighting, spike traps, and Docker instructions.
- [`docs/SECURITY.md`](docs/SECURITY.md): Threat model (`SEC-01`..`SEC-04`), input sanitization, and memory DoS defense.
- [`docs/SEED_BUG_ISSUES.md`](docs/SEED_BUG_ISSUES.md): Seed-reproducible defect triage archive and verification evidence.
- [`docs/WEREWOLF_TEST_REPORT.md`](docs/WEREWOLF_TEST_REPORT.md): 50-check functional test report for the Werewolf enemy.
