# Keep Fighting And Earning - Procedural Dungeon Roguelike

Keep Fighting And Earning is a 2D top-down action roguelike developed using Godot Engine 4. The project combines procedural dungeon generation, real-time combat, deterministic seed mechanics, centralized stat balancing, and an automated verification test suite.

---

## 1. System Architecture and Core Mechanics

### 1.1 Procedural Dungeon Generation
- **Graph Spanning Tree and BFS**: Generates 16 interconnected rooms per floor with corridor widths of 5 tiles. Boss rooms are placed at the maximum shortest-path distance (BFS) from the starting room.
- **Deterministic Seed Engine**: Employs an independent RandomNumberGenerator instance driven by a sanitized seed string. Identical seeds reconstruct identical dungeon topologies, obstacle placements, trap layouts, and entity spawns across runs.
- **Dynamic Floor Progression**: Supports multi-floor progression with distinct themes and boss room allocations (including dedicated boss arenas on specific milestone floors).

### 1.2 Combat and Physics System
- **Real-Time Combat Engine**: Implements hybrid Health and regenerating Armor pools, invulnerability frames (I-Frames), and directional hitboxes calculated via directional angles.
- **Line-of-Sight (LoS) Verification**: Uses RayCast2D queries to validate line-of-sight between combatants, preventing attacks or projectiles from passing through closed doors and solid wall tiles.
- **Centralized Balance Configuration**: All combat statistics across heroes, regular enemies, and bosses are consolidated in `Scene/BalanceConfig.gd` as the single source of truth.

### 1.3 Inventory and Equipment
- **16-Slot Inventory**: Provides a 4x4 grid inventory system, a 9-slot hotbar, and 3 dedicated equipment slots (Helmet, Armor, Weapon).
- **Loot Table Engine**: Drops health potions, armors, and weapons with deterministic roll seeding.

---

## 2. Playable Character Roster

The game includes 6 playable characters, selectable via the character selection interface:

| Hero Index | Identifier | Class Role | Health | Armor | Base Damage | Speed (px/s) | Primary Weapon / Mechanism |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| 0 | Miya | Ranger / Archer | 4 | 2 | 1 | 165.0 | Ranged Bow with 0.46s cooldown |
| 1 | Olaf | Berserker | 7 | 2 | 2 | 160.0 | Melee Axe with sweeping arc |
| 2 | Pyrois | Fire Mage | 4 | 4 | 2 | 160.0 | Magic Staff with explosive projectiles |
| 3 | Charlotte | Paladin / Shield | 6 | 4 | 1 | 150.0 | Iron Sword with active block and parry |
| 4 | Yugi | Spellcaster | 5 | 3 | 2 | 160.0 | Card summons, energy beams, room blast |
| 5 | Doraemon | Gadget Specialist | 5 | 2 | 1 | 150.0 | 4D Pocket (20 gadgets, 6 friends, 10 supers) |

---

## 3. Enemies and Boss Encounters

### 3.1 Standard Enemies
- **Orc**: Standard melee fighter with axe sweep.
- **Armored Orc**: Heavy melee fighter with frontal shield mitigation.
- **Skeleton**: Fast light melee enemy.
- **Skeleton Archer**: Ranged skirmisher utilizing wall navigation and evasive tactics.
- **Vampire**: High-speed melee unit with life-steal mechanics.
- **Werewolf**: Fast predator with claw slashes and telegraphing pounce strikes.

### 3.2 Boss Encounters
- **Necromancer (Floor 1)**: Triple-phase summoner that casts homing skulls and raises undead minions.
- **Orc Rider (Floor 2)**: Heavy charging cavalry boss with wide spear sweeps.
- **Skeleton King (Floors 3, 6, 9)**: Multistage arena boss occupying a specialized 32x18 arena, commanding invulnerability crystals, laser volleys, and summoned reinforcements.

---

## 4. Project Directory Structure

```
Keep-Fighting-And-Earning/
|-- Assets/                   # Audio tracks, sound effects, character and environment sprites
|-- docs/                     # Technical specifications, benchmarks, design docs, security policies
|-- Menu/                     # Main menu and UI scene assets
|-- Scene/                    # Gameplay scenes and scripts
|   |-- BalanceConfig.gd      # Centralized stat definitions
|   |-- GameManager.gd        # Game state, seed management, and replay controller
|   |-- Character/            # Playable hero implementations and controllers
|   |-- Enemies/              # Enemy and boss entity implementations
|   |-- Map/                  # Procedural dungeon generator and room management
|   `-- UI/                   # In-game HUD, minimap, inventory, and character select
|-- Test/                     # QA test matrices and tracking sheets
|-- tests/                    # Automated headless test scripts and scenes
|-- .github/workflows/ci.yml  # GitHub Actions continuous integration pipeline
|-- project.godot             # Godot Engine project configuration
|-- run_game.bat              # Script to launch the game
`-- run_tests.bat             # Script to execute all automated test suites
```

---

## 5. Automated Test Suite and Quality Assurance

The codebase includes automated test suites executable headlessly in Godot Engine:

1. **Unit Tests (`tests/test_dungeon_generator_unit.tscn`)**:
   - Validates dungeon room dimensions, start/boss room placement, corridor connectivity, trap positioning, and seed sanitization (19/19 passing).
2. **Property-Based Invariant Tests (`tests/test_dungeon_properties.tscn`)**:
   - Tests 100 random seeds against 5 structural invariants: determinism, connectivity, flood-fill walkability, boss optimality, and safe entity spawns (500/500 passing).
3. **Combat Regression Tests (`tests/test_orc_battle.tscn`)**:
   - Verifies 360-degree rotational hitbox accuracy across 5 directions (5/5 passing).
4. **Dungeon Generator Performance Benchmark (`tests/benchmark_dungeon_generator.tscn`)**:
   - Profiles dungeon generation execution times across scales from 10 to 50 rooms.
5. **Skeleton King Arena Tests (`tests/test_skeleton_king.tscn`)**:
   - Tests arena layout substitution, crystal mechanics, laser grid patterns, enrage phases, and defeat transitions (21/21 passing).
6. **Doraemon Hero Tests (`tests/test_doraemon.tscn`)**:
   - Exercises all 20 gadgets, 6 friend assists, 10 super abilities, and pocket HUD pagination (47/47 passing).
7. **Yugi Atem Hero Tests (`tests/test_yugi.tscn`)**:
   - Validates character sprite animations, attack sequences, and card summoning routines.
8. **Werewolf Functional Tests (`tests/test_werewolf.tscn`)**:
   - Tests claw attacks, pounce telegraphing, interruption, and distance bounding (50/50 passing).

---

## 6. Execution Instructions

### 6.1 Prerequisites
- Godot Engine 4.3 or later (Console / Headless executable recommended for tests).

### 6.2 Running the Game
Launch the project using Godot Engine or execute:
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
```

---

## 7. Controls

- **Movement**: W, A, S, D or Arrow Keys
- **Primary Attack**: Left Mouse Button
- **Special Skill**: Q
- **Secondary Action / Shield**: Right Mouse Button
- **Interact / Pick Up**: E
- **Inventory Toggle**: I or Tab
- **Minimap Toggle**: M
- **Gadget / Page Selection (Doraemon)**: Mouse Scroll Wheel, Z, X
- **Use Consumable**: F
- **Pause Menu**: Escape
