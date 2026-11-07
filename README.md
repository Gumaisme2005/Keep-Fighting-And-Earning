# Keep Fighting And Earning - Procedural Dungeon Roguelike

Keep Fighting And Earning is a 2D top-down action roguelike developed using Godot Engine 4. The project incorporates deterministic procedural dungeon generation, real-time combat mechanics, centralized stat balancing, and an automated verification test suite.

> **Base Commit & Development Alignment**:
> The `development` branch is aligned against base commit **`d718e45`** (from `origin/main`), preserving all features from `main` (Dungeon Benchmark, Fog of War, Spike Traps, Glorious Morning audio, Soul Knight UI) while integrating the complete hero roster, including **Yugi / Atem** and **Doraemon** alongside expanded systems.
> For diff tables, conflict resolution, and test verification logs, refer to [`docs/BASE_COMMIT_ANALYSIS_AND_DIFF.md`](docs/BASE_COMMIT_ANALYSIS_AND_DIFF.md).

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
| 7 | Luong Tho | Twin Gunblade Duelist | 5 | 2 | 1 | 155.0 | Three-hit combo, Twin Barrels and White Moon transformation |

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

#### Index 7: Luong Tho (Twin Gunblade Duelist)
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
   - Validates room constraints, start and boss placement, corridor tree connectivity, trap placement, hero attack mechanics, UI scene instantiation, and seed sanitization (19/19 passing).
2. **Property-Based Invariant Tests (`tests/test_dungeon_properties.tscn`)**:
   - Tests 100 random seeds across 5 structural invariants: determinism, connectivity, flood-fill walkability, boss optimality, and safe entity spawns (500/500 passing).
3. **Combat Regression Tests (`tests/test_orc_battle.tscn`)**:
   - Verifies 360-degree rotational hitbox accuracy across 5 primary directions (5/5 passing).
4. **Dungeon Generator Performance Benchmark (`tests/benchmark_dungeon_generator.tscn`)**:
   - Evaluates dungeon generation execution times across scales from 10 to 50 rooms.
5. **Skeleton King Arena Tests (`tests/test_skeleton_king.tscn`)**:
   - Tests specialized arena layout, crystal destruction, laser grid volleys, enrage states, and defeat transitions (21/21 passing).
6. **Doraemon Hero Tests (`tests/test_doraemon.tscn`)**:
   - Exercises all 20 gadgets, 6 companion assists, 10 super abilities, crate collision blocking, pocket HUD pagination, and facing hitbox regression (49/49 passing).
7. **Yugi Atem Hero Tests (`tests/test_yugi.tscn`)**:
   - Validates character animations, directional attacks, charged attacks, guard stance, and 5 room spells (passing).
8. **Werewolf Functional Tests (`tests/test_werewolf.tscn`)**:
   - Tests claw attacks, pounce warning telegraphs, damage interruption, and pounce distance bounding (50/50 passing).
9. **MOBA HUD and Inventory Stacking Tests (`tests/test_moba_hud_and_inventory.tscn`)**:
   - Validates numeric health and armor progress bars, Minecraft-style potion stacking up to 16, stack consumption, item dropping, and RPG equipment stat calculations (34/34 passing).
10. **Replay Capacity and Memory Protection Tests (`tests/test_replay_security.tscn`)**:
    - Validates 10-replay hard cap enforcement, FIFO memory deallocation of old replay frames, manual replay deletion, clear all, and anti-DoS idle frame compression (39/39 passing).
11. **Hoshimi Miyabi Tests (`tests/test_miyabi.tscn`)**:
    - Tests 3-hit frost combo, invulnerable dash slash, charged frost waves, Frost Bloom ice spikes, and autonomous ice spirit targeting (18/18 passing).
12. **Luong Tho Tests (`tests/test_luong_tho.tscn`)**:
    - Tests 3-step weapon combo, Twin Barrels firing along cursor vector, White Moon transformation, piercing rounds, and invulnerability (15/15 passing).
13. **Projectile Obstacle Tests (`tests/test_projectile_obstacles.tscn`)**:
    - Validates that wooden crates block fast projectiles, ricochets bounce properly, and non-solid decorations remain transparent (passing).
14. **Perk Progression System Tests (`tests/test_perk_system.tscn`)**:
    - Validates 30 perks across 4 rarities, deterministic drafting rolls, unique perk deduplication, combat hook integrations, stochastic damage rounding, and second-chance revivals (37/37 passing).

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
godot --headless --path . "res://tests/test_miyabi.tscn"
godot --headless --path . "res://tests/test_luong_tho.tscn"
godot --headless --path . "res://tests/test_projectile_obstacles.tscn"
godot --headless --path . "res://tests/test_perk_system.tscn"
godot --headless --path . "res://tests/test_settings_and_ui.tscn"
```

---

## 7. Controls and How to Play

### 7.1 General Controls and Movement
- **Movement (W, A, S, D / Arrow Keys)**: Move your champion smoothly across 8 directions (cardinal and diagonal).
- **Mouse Cursor 360-Degree Aiming**: The champion continuously aims and turns toward the mouse cursor. All basic attacks, skillshots, dashes, projectile trajectories, and directional summons align directly with the cursor position.
- **Primary Attack (Left Mouse Button / LMB)**: Unleashes basic weapon strikes or projectile volleys. Holding LMB continuously attacks at your champion's base cooldown rate.
- **Secondary Action (Right Mouse Button / RMB)**: Triggers secondary attacks, dashes, or charged summon mechanisms.
- **Primary Active Skill (Q)**: Casts the champion's signature ability (indicated by cooldown clock on the HUD).
- **Interact / Pick Up (E)**: Opens treasure chests, collects world item drops, or steps through dimensional portals.
- **Expedition Manual and Lore (H or F1)**: Opens the in-game Guide modal with full control references, active hero mechanics, and Middle-earth expedition lore.
- **Inventory and Equipment (Tab, I, or B)**: Toggles the 16-slot Backpack and Equipment window.
- **Action Hotbar (Keys 1 to 9)**: Instantly consumes stacked potions or activates hotbar equipment items.
- **Drop First Item (G)**: Drops the first item from your backpack onto the dungeon floor.
- **Drop Specific Item (Right-Click in Inventory)**: Spawns an interactive world pickup from any selected slot.
- **Minimap Toggle (M)**: Switches between the compact corner radar and the expanded full dungeon tactical overview.
- **Audio Mute Toggle (N)**: Toggles background music and sound effects on or off.
- **Pause Menu (Escape)**: Pauses the expedition, displaying seed details, manual, and surrender options.

### 7.2 Champion-Specific Combos and Tactics
- **Pyrois (Knight)**:
  - LMB: Sword thrust.
  - Q Sovereign Rush: Charges forward with invulnerability frames, dealing +2 bonus damage (5s cooldown).
  - Tactics: Use regenerating Armor to absorb vanguard hits, then strike with Sovereign Rush to breach fortified corridors.
- **Olaf (Berserker)**:
  - LMB: Wide greataxe cleave hitting all enemies within arc range.
  - Q Durin's Wrath: Roars into a 5-second battle trance doubling all melee damage (5s cooldown).
  - Tactics: Funnel monster swarms into choke points, trigger Durin's Wrath, and cleave multiple foes in single swings.
- **Miya (Archer)**:
  - LMB: Rapid long-range arrows (280 px/s velocity, 0.46s cooldown).
  - Q Orthanc Fire: Hurls an alchemical explosive dealing 2x area damage + 1 bonus damage (6.5s cooldown).
  - Tactics: Maintain maximum distance using 360-degree mouse aiming. Use dungeon pillars to break enemy line of sight while kiting.
- **Charlotte (Shadow Ranger)**:
  - LMB: Rapid dual-blade flurry (0.28s cooldown).
  - RMB Shadow Step: High-speed 400 px/s invulnerable dash followed by 4 piercing stabs (5s cooldown).
  - Q Triple Flurry: Rapid 3-slash stationary burst (3s cooldown).
  - Tactics: Execute Shadow Step to bypass traps and projectile volleys, reappearing behind elite foes for instant critical strikes.
- **Yugi / Atem (Summoner)**:
  - LMB: Quick monster strike (1x damage); hold 0.65s for a 2x charged summon.
  - RMB: Location-targeted monster summon (1x damage); hold 0.65s for a 3x charged summon.
  - Hold Shift: Enters Guard Spirit stance. Clicking during guard releases a 2x combo summon.
  - Q Special Summon: Randomly triggers 1 of 5 room-wide spells: Room Blast (50% enemy current HP), Room Laser, Room Lightning, Room Pull, or Room Fire (12s cooldown).
  - Tactics: Place location summons ahead of your position to scout dangerous rooms. Hold Shift to absorb incoming projectiles while charging counter-attacks.
- **Doraemon (Gadget Specialist)**:
  - Mouse Scroll Wheel or Z / X: Cycles through 10 pocket pages containing 20 futuristic gadgets.
  - LMB and RMB: Activates Gadget 1 and Gadget 2 of the active page (Air Cannon, Anywhere Door, Champion Glove, Shock Gun, Pencil Missiles, Mini-Doras, T-Rex summon, etc.).
  - Q Friend Assist / Super Move: Summons 1 of 6 friends (Nobita, Gian, Shizuka, Dorami, Suneo, Come-come Cat). When the power bar reaches 100+, Q triggers devastating super moves.
  - F Snack: Eats a Dorayaki to heal 1 HP and generate +40 power gauge points (12s cooldown).
  - Tactics: Use Anywhere Door to bypass locked corridors and hazardous spike traps. Build power gauge with Air Cannon before unleashing super attacks.
- **Hoshimi Miyabi (Frost Swordswoman)**:
  - LMB: 3-hit frost combo; the third hit lunges forward and inflicts freeze.
  - Shift: Invulnerable 72px dash slash cutting through all enemies in path (2x damage).
  - Hold RMB: Charges a piercing Frost Wave that penetrates enemy formations and freezes targets.
  - Q Frost Bloom: Erupts sharp ice spikes in front of her (3x damage + freeze), followed by a shattering burst.
  - Ice Spirit: An autonomous spirit familiar continuously tracks and snipes the nearest visible threat every 2 seconds.
  - Tactics: Freeze elite enemies with the 3rd combo hit or charged Frost Wave, then dash through them with Shift for guaranteed critical damage.
- **Luong Tho (Twin Gunblade Duelist)**:
  - LMB: 3-step melee sequence: Stab, Twin Swing (2 hits), and Ground Smash (2x damage + daze).
  - RMB Twin Barrels: Fires twin gunblade cartridges along the cursor vector.
  - Q White Moon Transformation: Transforms into the White Moon form for 12 seconds, granting complete damage immunity, +1 damage bonus, 25% attack speed, 20% move speed, and piercing rounds.
  - Tactics: Engage swarms with Twin Barrels at medium range. When surrounded by bosses or high-damage elites, activate White Moon to eliminate threats without risk of taking damage.

### 7.3 Dungeon Survival Mechanics
- **Shields and Regenerating Armor**: Armor pools absorb damage before Health is depleted. Remaining out of combat for 5 seconds triggers continuous Armor regeneration back to maximum capacity.
- **Line-of-Sight and Solid Obstacles**: Arrows, spells, and weapon arcs cannot pass through stone walls, closed doors, or wooden crates. Use dungeon architecture to bait enemies and nullify ranged projectiles.
- **Spike Trap Timing**: Retractable spike floor tiles alternate states. Cross tiles while spikes are retracted, or acquire the Stone Bulwark perk for permanent spike immunity.
- **Room Lockouts**: Entering an uncleared monster room immediately seals all entry and exit doors. Clear all hostile entities to reopen passages and claim treasure.

---

## 8. Expedition Narrative and World Lore

### 8.1 The Chronicles of Middle-earth: Khazad-dum
Long before the Third Age, the subterranean kingdom of Khazad-dum stood as the crowning jewel of Dwarven civilization under the Misty Mountains. Yet the greed of the Naugrim dug too deeply into the roots of Caradhras, awakening ancient terrors and releasing shadowy abyssal forces that overran the Great Halls.

Today, the abandoned halls of Moria echo with the drumbeats of Orc warbands, rabid werewolf packs, and ancient sorcerers practicing dark necromancy. From across dimensions and eras, eight champions have been drawn to the Doors of Durin, seeking to reclaim lost relics, conquer the subterranean horrors, and seal the ancient rifts.

### 8.2 The Palantir Stone and Deterministic Coordinates
At the core of Khazad-dum lies an ancient Seeing Stone—a Palantir woven into the subterranean bedrock. The stone projects immutable spatial coordinates across the endless labyrinth:
- **Spatial Seeding**: Every expedition seed string generates an identical, immutable arrangement of 16 chambers, corridor trees, spike traps, treasure vaults, and boss lairs.
- **Replay Crystals**: Ancient crystal nodes record the precise kinetic actions and keystrokes of every hero at 60 Hz, enabling adventurers to study past expeditions and master the dungeon's deterministic patterns.

### 8.3 The Subterranean Hierarchy
- **Orc Warbands and Warg Riders**: The subterranean frontlines are held by disciplined Orc vanguards and heavily armored Chieftains.
- **Werewolf Stalkers**: Fast, feral beasts lurking in corridor shadows, telegraphing deadly pounce attacks that must be interrupted or dodged.
- **The Necromancer of the Lower Depths**: An ancient defiler in Floor 1 summoning undead thralls and homing skull curses.
- **The Skeleton King**: An undying monarch residing in Floors 3, 6, and 9. Protected by invulnerable Soul Crystals and devastating laser grid volleys, the Skeleton King can only be damaged by systematically shattering his resonant soul anchors.

---

## 9. Graphics, Display, and Performance Configuration

### 9.1 Frame Rate Control (FPS Limiter)
- **Presets**: 30 FPS, 60 FPS, 120 FPS, 144 FPS, and Unlimited (0 FPS cap).
- **Custom FPS Limiter**: Continuous range between 20 FPS and 360 FPS controlled via synced horizontal slider and numeric SpinBox.
- **Engine Throttling**: Direct hardware synchronization via `Engine.max_fps`.

### 9.2 Resolution and Display Modes
- **Screen Resolution Presets**:
  - 1280 x 720 (720p HD, standard base viewport)
  - 1366 x 768 (HD)
  - 1600 x 900 (900p HD+)
  - 1920 x 1080 (1080p FHD)
  - 2560 x 1440 (1440p 2K QHD)
  - 3840 x 2160 (2160p 4K UHD)
- **Display Modes**:
  - Windowed: Floating resizable centered window.
  - Borderless Fullscreen: Seamless borderless presentation matching the current primary display resolution.
  - Exclusive Fullscreen: Dedicated hardware fullscreen mode via `DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN`.
- **Vertical Synchronization (V-Sync)**:
  - Disabled: Uncapped rendering without monitor sync.
  - Enabled: Locked to monitor refresh rate.
  - Adaptive: Tear-free rendering that disables sync when frame rate drops below target.

### 9.3 Audio System Controls
- **Master, BGM, and SFX Volume**: Independent linear percentage sliders (0% to 100%) converting directly to logarithmic decibel ranges (-30 dB to 0 dB, and -80 dB on complete mute).
- **Mute Toggle**: Global audio mute toggle updating all active audio stream players immediately.

### 9.4 Configuration Persistence
- **Storage Location**: Automatically saved to and loaded from `user://settings.cfg` using Godot's `ConfigFile` API.
- **Fault-Tolerant Defaults**: Automatically restores safe baseline settings (60 FPS, 1280x720, Windowed, VSync Enabled) if the file is missing or corrupted.

### 9.5 Interface Integration and Modal Hierarchy
- **Universal Availability**: The Settings Modal is accessible from:
  - Main Menu: Top-right header button and central Graphics & Performance button.
  - Character Selection: Header action bar.
  - Pause Menu: Dedicated card action column.
  - In-Game HUD: Top-right quick access toolbar.
- **Click-Through and Input Protection**: All modals (Settings, Expedition Guide, and Inventory) feature full-screen dark backdrops that consume background mouse clicks and prevent accidental attacks or character movement while interacting with menus.
- **Escape Key Routing**: Pressing Escape systematically closes the topmost active modal (Settings -> Guide -> Inventory) before allowing the game to pause, resolving pause menu clipping bugs.

