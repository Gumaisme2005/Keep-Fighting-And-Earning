# Keep Fighting And Earning - Procedural Dungeon Roguelike

Keep Fighting And Earning is a 2D top-down action roguelike developed using Godot Engine 4. The project incorporates deterministic procedural dungeon generation, real-time combat mechanics, centralized stat balancing, and an automated verification test suite.

---

## 1. System Architecture and Core Mechanics

### 1.1 Procedural Dungeon Generation
- **Graph Spanning Tree and BFS Topology**: Generates 16 interconnected rooms per floor with corridor widths of 5 tiles. Boss rooms are dynamically positioned at the maximum shortest-path distance (BFS) from the starting room.
- **Deterministic Seed Engine**: An isolated RandomNumberGenerator instance driven by sanitized seed strings ensures identical seeds reproduce exact room topologies, obstacle placements, trap patterns, and entity spawns across runs.
- **Multi-Floor Progression**: Supports escalating difficulty across dungeon tiers, including specialized milestone arenas (such as the Skeleton King boss chamber).

### 1.2 Combat and Physics System
- **Real-Time Combat Mechanics**: Combines discrete Health and regenerating Armor pools, invulnerability frames (I-Frames), and 360-degree rotational hitboxes.
- **Line-of-Sight (LoS) Validation**: Employs spatial grid raycasting to verify unobstructed line-of-sight between combatants, preventing attacks or projectile trajectories from clipping through walls or closed doors.
- **Centralized Balance Configuration**: Combat statistics across all heroes, monsters, and bosses are maintained within `Scene/BalanceConfig.gd` as the single source of truth.

### 1.3 Inventory, Equipment and Interface
- **16-Slot Inventory**: Includes a 4x4 grid backpack storage, a 9-slot action hotbar, and expandable equipment slots (Helmet, Armor, Weapon, Magic Resist, Boots).
- **Minecraft-Style Item Stacking**: Stackable consumable items (potions) automatically merge up to 16 units per slot, displaying item count badges. Consuming items decrements the active stack count.
- **Item Drop and Discard Mechanics**: Supports dropping items onto the floor via the G hotkey or right-clicking inventory slots to spawn collectible world pickups.
- **MOBA-Style HUD Display**: Replaces individual heart icons with clean numeric progress bars for Health and Armor (with dynamic color thresholds), providing immediate combat clarity.
- **Loot Table Engine**: Handles equipment and consumable drops (potions, armor sets, weapons) driven by deterministic roll seeding.

### 1.4 Replay System and Memory Protection (Multiplayer Ready)
- **10-Replay Maximum Capacity (`MAX_SAVED_REPLAYS = 10`)**: Automatic FIFO eviction of raw input frames for older runs, preserving only high-level run metadata to avoid RAM leaks.
- **Manual Replay Deletion**: Direct delete buttons in the Expedition History interface allow users to manually purge individual replay data or wipe replay memory.
- **Anti-DoS Input Compression and Bounding**: Limits disk frames to 3,600 (approx. 60s at 60 FPS) and deduplicates consecutive stationary idle frames. Enforces strict 2 MB maximum save file limits, ready for online multiplayer packet transmission.

---

## 2. Playable Character Roster

The roster features 8 distinct heroes, selectable from the character selection screen. All parameters reflect the centralized balance configuration in `Scene/BalanceConfig.gd`.

### 2.1 Roster Overview Table

| Index | Name | Class / Role | HP | Armor | Damage | Speed (px/s) | Primary Weapon / Mechanism |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| 0 | Miya | Elven Archer | 3 | 1 | 1 | 165.0 | Galadhrim Bow (rapid ranged arrows, 0.46s CD) |
| 1 | Olaf | Dwarven Berserker | 6 | 1 | 2 | 160.0 | Greataxe of Khazad-dum (cleave arc, 0.34s CD) |
| 2 | Pyrois | White Tower Knight | 4 | 4 | 1 | 150.0 | Sword and Shield (defensive rush, 0.30s CD) |
| 3 | Charlotte | Dunedain Shadow Ranger | 5 | 0 | 2 | 180.0 | Twin Blades (high-speed dash and flurry, 0.28s CD) |
| 4 | Yugi / Atem | Pharaoh Summoner | 5 | 1 | 1 | 150.0 | Millennium Puzzle (monsters, guard, room spells) |
| 5 | Doraemon | 22nd-Century Specialist | 5 | 2 | 1 | 150.0 | 4D Pocket (20 gadgets, 6 assists, 10 supers) |
| 6 | Hoshimi Miyabi | Frost Swordswoman | 4 | 2 | 1 | 160.0 | Frost combo, dash, charged wave, Frost Bloom and ice spirit |
| 7 | Lương Thơ | Twin Gunblade Duelist | 5 | 2 | 1 | 155.0 | Three-hit combo, Twin Barrels and White Moon transformation |

### 2.2 Hero Profiles and Ability Breakdown

#### Index 0: Miya (Elven Archer)
- **Playstyle**: Long-range kiting scout with consistent sustained projectile output.
- **Primary Attack (LMB)**: Fires rapid piercing arrows toward the cursor (cooldown: 0.46s, projectile speed: 280 px/s).
- **Special Skill (Q - Orthanc Fire)**: Hurls an alchemical explosive dealing 2x area damage plus 1 bonus damage upon detonation (cooldown: 6.5s).

#### Index 1: Olaf (Dwarven Berserker)
- **Playstyle**: Resilient frontline bruiser excelling at close-quarters crowd control.
- **Primary Attack (LMB)**: Sweeps a broad greataxe arc striking multiple adjacent enemies (cooldown: 0.34s).
- **Special Skill (Q - Durin's Wrath)**: Enters a battle frenzy that doubles melee cleave damage (2x multiplier) for 5.0 seconds (cooldown: 5.0s).

#### Index 2: Pyrois (Knight of the White Tower)
- **Playstyle**: Heavily armored vanguard relying on defensive absorption and shield rushes.
- **Primary Attack (LMB)**: Disciplined sword thrust piercing through enemy vanguards (cooldown: 0.30s).
- **Special Skill (Q - Sovereign Rush)**: Charges forward with invulnerability frames, piercing targets for +2 bonus damage (cooldown: 5.0s).

#### Index 3: Charlotte (Dunedain Shadow Ranger)
- **Playstyle**: Agile glass cannon trading armor for supreme mobility and burst combinations.
- **Primary Attack (LMB)**: Fast dual-blade strike sequence (cooldown: 0.28s).
- **Special Skill (Q - Triple Flurry)**: Executes three rapid slashes in stationary burst (cooldown: 3.0s).
- **Secondary Action (RMB - Shadow Step)**: Dashes forward at 400 px/s with invulnerability frames, followed by 4 piercing stabs (cooldown: 5.0s).

#### Index 4: Yugi / Atem (Pharaoh Summoner)
- **Playstyle**: Tactical summoner combining directional monster attacks, guard stance, and room-wide spells.
- **Primary Attack (LMB)**: Quick monster strike (1x damage); holding for 0.65s charges a 2x damage attack.
- **Secondary Action (RMB)**: Target-location summon (1x damage); holding for 0.65s charges a 3x damage summon.
- **Defensive Stance (Hold Shift)**: Summons a guard spirit that reduces incoming threat and allows tactical repositioning. Clicking during guard executes a combo summon (2x damage).
- **Special Skill (Q - Special Summon)**: Randomly casts 1 of 5 room-wide spells: Room Blast (50% of average current enemy HP, rounded down, minimum 1), Room Laser (piercing beam), Room Lightning (electrical shock), Room Pull (vortex draw), or Room Fire (burning ticks) (cooldown: 12.0s).

#### Index 5: Doraemon (22nd-Century Gadget Specialist)
- **Playstyle**: Versatile hybrid fighter utilizing an extensive 4D pocket gadget arsenal and companion assists.
- **4D Pocket System (20 Gadgets across 10 Pages)**: Cycle pages using Mouse Wheel or Z / X keys. LMB and RMB trigger the two gadgets of the active page (Air Cannon, Anywhere Door, Champion Glove, Shock Gun, Pencil Missiles, Mini-Doras, T-Rex summon, etc.).
- **Companion Assists (Q without full power bar)**: Summons 1 of 6 companions in rotation (Nobita, Gian, Shizuka, Dorami, Suneo, Come-come Cat) to execute an assist strike (cooldown: 8.0s).
- **Super Moves (Q with power bar >= 100)**: Consumes accumulated power gauge to cast page-specific super abilities (Uradoraman, SL Chimney, Gian Recital, Dorayakin, etc.).
- **Consumable (F - Dorayaki)**: Consumes a dorayaki to recover 1 HP and restore 40 power gauge points (cooldown: 12.0s).

#### Index 6: Hoshimi Miyabi (Frost Swordswoman)
- **LMB**: Three-hit frost combo; **Shift**: invulnerable slashing dash.
- **Hold/release RMB**: Charged Frost Wave; **Q**: Frost Bloom ice spikes.
- An ice spirit follows Miyabi and automatically attacks nearby visible enemies.

#### Index 7: Lương Thơ (Twin Gunblade Duelist)
- **LMB**: Stab, twin swing and ground-smash combo; **RMB**: Twin Barrels.
- **Q**: White Moon transformation grants 12 seconds of invulnerability, stronger and faster attacks, faster movement and piercing bullets.

---

## 3. Enemies and Boss Encounters

### 3.1 Standard Enemies
- **Orc**: Basic melee fighter with frontal axe sweeps.
- **Armored Orc**: Heavy melee warrior with elevated defense and an enrage attack phase.
- **Skeleton**: Swift light melee unit with aggressive closing behavior.
- **Skeleton Archer**: Tactical ranged skirmisher that kites players and repositions along walls.
- **Vampire**: High-speed aerial predator with life-steal melee strikes.
- **Werewolf**: Aggressive beast with fast claw combos and telegraphed leaping pounce attacks.

### 3.2 Boss Encounters
- **Necromancer (Floor 1)**: Triple-phase spellcaster that fires homing skulls and raises undead minions.
- **Orc Rider (Floor 2)**: Heavy cavalry chieftain with high poise, charging dash attacks, and spinning hammer strikes.
- **Skeleton King (Floors 3, 6, 9)**: Tiered arena overlord protected by invulnerable Soul Crystals, multidirectional laser volleys, and summoned reinforcements.

---

## 4. Project Directory Structure

```
Keep-Fighting-And-Earning/
|-- Assets/                   # Audio tracks, sound effects, character and environment sprites
|-- docs/                     # Technical specifications, benchmarks, design documents
|-- Menu/                     # Main menu and interface scenes
|-- Scene/                    # Gameplay scenes and core scripts
|   |-- BalanceConfig.gd      # Single source of truth for all unit statistics
|   |-- GameManager.gd        # State management, seed pipeline, and replay controller
|   |-- Character/            # Playable hero scenes, controllers, and gadget modules
|   |-- Enemies/              # Standard enemy and boss entity implementations
|   |-- Map/                  # Procedural dungeon generator, tilesets, and room management
|   `-- UI/                   # In-game HUD, minimap, inventory, and character select screens
|-- Test/                     # QA test case matrices and tracking sheets
|-- tests/                    # Automated headless test suites and regression scripts
|-- .github/workflows/ci.yml  # GitHub Actions continuous integration pipeline
|-- project.godot             # Godot Engine project configuration
|-- run_game.bat              # Script to launch the game client
`-- run_tests.bat             # Script to execute all automated test suites
```

---

## 5. Automated Test Suite and Quality Assurance

The test suite is executable headlessly in Godot Engine:

1. **Unit Tests (`tests/test_dungeon_generator_unit.tscn`)**:
   - Validates room constraints, start and boss placement, corridor tree connectivity, trap placement, hero attack mechanics, and seed sanitization (19/19 passing).
2. **Property-Based Invariant Tests (`tests/test_dungeon_properties.tscn`)**:
   - Tests 100 random seeds across 5 structural invariants: determinism, connectivity, flood-fill walkability, boss optimality, and safe entity spawns (500/500 passing).
3. **Combat Regression Tests (`tests/test_orc_battle.tscn`)**:
   - Verifies 360-degree rotational hitbox accuracy across 5 primary directions (5/5 passing).
4. **Dungeon Generator Performance Benchmark (`tests/benchmark_dungeon_generator.tscn`)**:
   - Evaluates dungeon generation execution times across scales from 10 to 50 rooms.
5. **Skeleton King Arena Tests (`tests/test_skeleton_king.tscn`)**:
   - Tests specialized arena layout, crystal destruction, laser grid volleys, enrage states, and defeat transitions (21/21 passing).
6. **Doraemon Hero Tests (`tests/test_doraemon.tscn`)**:
   - Exercises all 20 gadgets, 6 companion assists, 10 super abilities, crate collision blocking, and pocket HUD pagination and facing hitbox regression (49 checks).
7. **Yugi Atem Hero Tests (`tests/test_yugi.tscn`)**:
   - Validates character animations, directional attacks, guard stance, and special summons.
8. **Werewolf Functional Tests (`tests/test_werewolf.tscn`)**:
   - Tests claw attacks, pounce warning telegraphs, damage interruption, and pounce distance bounding (50/50 passing).
9. **MOBA HUD and Inventory Stacking Tests (`tests/test_moba_hud_and_inventory.tscn`)**:
   - Validates numeric health and armor progress bars, Minecraft-style potion stacking up to 16, stack consumption, item dropping, and RPG equipment stat calculations (34/34 passing).
10. **Replay Capacity and Memory Protection Tests (`tests/test_replay_security.tscn`)**:
    - Validates 10-replay hard cap enforcement, FIFO memory deallocation of old replay frames, manual replay deletion, clear all, and anti-DoS idle frame compression (39/39 passing).

9. **MOBA HUD and Inventory Tests (`tests/test_moba_hud_and_inventory.tscn`)**: Numeric bars, item stacking, equipment and dropping items.
10. **Miyabi Tests (`tests/test_miyabi.tscn`)**: Frost abilities, spirit, facing and replay.
11. **Lương Thơ Tests (`tests/test_luong_tho.tscn`)**: Combo, firearms, transformation and replay.
12. **Projectile Obstacle Tests (`tests/test_projectile_obstacles.tscn`)**: Crates block fast projectiles; ricochets bounce; non-solid decoration remains transparent.

---

## 6. Execution Instructions

### 6.1 Prerequisites
- Godot Engine 4.7 or later (Console / Headless binary recommended for automated tests).

### 6.2 Running the Game
Launch the project through Godot Engine or execute:
```cmd
run_game.bat
```

### 6.3 Running Automated Tests
Run the entire suite locally with:
```cmd
run_tests.bat
```
Or execute individual test scenes headlessly:
```cmd
godot --headless --path . "res://tests/test_dungeon_generator_unit.tscn"
godot --headless --path . "res://tests/test_dungeon_properties.tscn"
godot --headless --path . "res://tests/test_orc_battle.tscn"
godot --headless --path . "res://tests/test_skeleton_king.tscn"
godot --headless --path . "res://tests/test_doraemon.tscn"
godot --headless --path . "res://tests/test_yugi.tscn"
godot --headless --path . "res://tests/test_werewolf.tscn"
godot --headless --path . "res://tests/test_moba_hud_and_inventory.tscn"
godot --headless --path . "res://tests/test_replay_security.tscn"
```

---

## 7. Controls

- **Movement**: W, A, S, D or Arrow Keys
- **Primary Attack**: Left Mouse Button
- **Special Skill**: Q
- **Secondary Action / Skill**: Right Mouse Button
- **Guard Stance (Yugi)**: Hold Shift
- **Gadget Page Selection (Doraemon)**: Mouse Scroll Wheel, Z, X
- **Eat Snack / Dorayaki (Doraemon)**: F
- **Interact / Pick Up**: E
- **Drop Item**: G or Right-Click inventory slot
- **Backpack / Inventory Toggle**: B, I, or Tab
- **Minimap Toggle**: M
- **Audio Mute Toggle**: N
- **Pause Menu**: Escape
