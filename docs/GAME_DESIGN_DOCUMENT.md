# GAME DESIGN DOCUMENT (GDD) — KEEP FIGHTING AND EARNING

**Project Title:** Keep Fighting And Earning  
**Genre:** 2D Top-Down Procedural Action Roguelike with Deterministic Replay  
**Theme:** The Chronicles of Middle-earth: Khazad-dum (The Mines of Moria) with Cross-Dimensional Fellowship  
**Engine:** Godot Engine 4.7.2 (2D Pixel-Art Nearest-Neighbor Rendering)  
**Target Viewport:** 1280x720 Base (Scalable from 720p HD to 4K UHD)  

---

## 1. Executive Summary and Design Pillars

### 1.1 Core Concept
Keep Fighting And Earning is a top-down action roguelike blending fast-paced real-time combat, deterministic dungeon generation, and deep tactical hero customization. Set in the darkened subterranean depths of Khazad-dum, players guide a diverse vanguard of eight champions through multi-tiered procedural labyrinths, contending with orc warbands, feral werewolf packs, ancient necromancers, and the Skeleton King.

### 1.2 The Four Core Pillars
1. **Deterministic Procedural Generation:** A unified alphanumeric Seed drives an isolated Pseudo-Random Number Generator (PRNG). Identical seeds guarantee 100% reproducible room layouts, corridor trees, spike traps, treasure drops, and enemy formations.
2. **Deterministic 60Hz Action Replay:** The engine records user inputs at a fixed 60Hz physics rate. Expeditions can be replayed frame-for-frame or taken over in real time for speedrun verification, strategy review, and automated regression testing.
3. **Dynamic Centralized Balance (Single Source of Truth):** All combat parameters for 8 heroes, 6 regular enemies, and 3 multi-phase bosses reside in `Scene/BalanceConfig.gd` backed by `.tres` Custom Resources, enabling instant tuning without decentralized code modifications.
4. **Accessible Tactical Combat and Modern UI:** Features 360-degree cursor aiming, regenerating Armor pools, spatial Line-of-Sight (LoS) raycasting, Minecraft-style stackable inventory, a 30-perk drafting progression, and full hardware settings (FPS limiter, resolution presets, and VSync).

---

## 2. Worldbuilding and Narrative Context

### 2.1 The Mines of Moria (Khazad-dum)
Deep beneath the Misty Mountains lies Khazad-dum, once the greatest underground realm of the Dwarves. Overcome by shadow after the Awakening of the Balrog and overrun by Orc hordes of Dol Guldur, the labyrinthine halls now serve as an active proving ground. Ancient stone doors slam shut behind trespassers, forcing champions to purge each chamber to reopen passages.

### 2.2 The Palantir Seeing Stone and Deterministic Seeding
At the deepest level of Moria sits an ancient Seeing Stone—a Palantir anchored into the living bedrock. The Palantir projects immutable geometric coordinates across the labyrinth:
- **Spatial Seeding:** Entering a seed (e.g., `ALOALO1234`, `MORIA_DWARF_RUN`) aligns the dungeon generator to a specific projection matrix, locking room positions, corridor connections, obstacle pillars, and treasure spawns.
- **Replay Crystals:** Resonant mineral nodes record physical keystrokes, enabling adventurers to inspect past runs and master the deterministic hazards of each seed.

---

## 3. Playable Character Roster

The game features eight distinct champions. All attributes are centrally declared in `Scene/BalanceConfig.gd`.

### 3.1 Champion Overview Table

| Index | Champion | Role / Title | HP | Armor | Damage | Speed (px/s) | Primary Weapon & Signature Skill |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| 0 | **Miya** | Elven Archer | 3 | 1 | 1 | 165 | Galadhrim Bow (0.46s CD) • [Q] Orthanc Fire (area bomb) |
| 1 | **Olaf** | Dwarven Berserker | 6 | 1 | 2 | 160 | Greataxe of Moria (0.34s CD) • [Q] Durin's Wrath (2x cleave buff) |
| 2 | **Pyrois** | White Tower Knight | 4 | 4 | 1 | 150 | Sword & Shield (0.30s CD) • [Q] Sovereign Rush (I-Frame charge) |
| 3 | **Charlotte** | Dunedain Shadow Ranger | 5 | 0 | 2 | 180 | Twin Elendil Blades (0.28s CD) • [Q] Triple Flurry • [RMB] Shadow Step |
| 4 | **Yugi / Atem** | Pharaoh Summoner | 5 | 1 | 1 | 150 | Millennium Puzzle • Directional summons • [Q] 5 Room Spells |
| 5 | **Doraemon** | 22nd-Century Specialist | 5 | 2 | 1 | 150 | 4D Pocket (20 gadgets) • [Q] 6 Friend Assists & 10 Supers |
| 6 | **Hoshimi Miyabi** | Frost Swordswoman | 4 | 2 | 1 | 160 | Frost Combo • [Shift] Dash • [Hold RMB] Frost Wave • [Q] Frost Bloom |
| 7 | **Luong Tho** | Twin Gunblade Duelist | 5 | 2 | 1 | 155 | 3-Step Combo • [RMB] Twin Barrels • [Q] White Moon Form |

### 3.2 Detailed Champion Profiles

#### Index 0: Miya (Elven Archer)
- **Visual Asset:** `docs/images/hero_miya.png`
- **Archetype:** Ranged Kiting Scout (Glass Cannon).
- **Controls & Actions:**
  - `LMB`: Fires rapid piercing arrows along cursor vector (speed: 280 px/s, CD: 0.46s).
  - `Q` (Orthanc Fire): Hurls an explosive concoction dealing 2x damage + 1 bonus area damage upon impact (CD: 6.5s).
- **Tactics:** Keep maximum distance, utilizing stone pillars to break enemy Line of Sight while maintaining continuous arrow fire.

#### Index 1: Olaf (Dwarven Berserker)
- **Visual Asset:** `docs/images/hero_olaf.png`
- **Archetype:** Frontline Cleave Bruiser.
- **Controls & Actions:**
  - `LMB`: Sweeps a wide greataxe arc striking all enemies in melee range (CD: 0.34s).
  - `Q` (Durin's Wrath): Enters an enraged trance, doubling all melee damage (2x multiplier) for 5.0s (CD: 5.0s).
- **Tactics:** Funnel swarms into corridors, activate Durin's Wrath, and cleave entire waves in single swings.

#### Index 2: Pyrois (Knight of the White Tower)
- **Visual Asset:** `docs/images/hero_pyrois.png`
- **Archetype:** Heavy Tank Vanguard.
- **Controls & Actions:**
  - `LMB`: Direct sword thrust piercing enemy vanguards (CD: 0.30s).
  - `Q` (Sovereign Rush): Charges forward with invulnerability frames, piercing targets for +2 bonus damage (CD: 5.0s).
- **Tactics:** Rely on 4 Armor points that regenerate after 5 seconds without damage; use Sovereign Rush to breach fortified enemy positions.

#### Index 3: Charlotte (Dunedain Shadow Ranger)
- **Visual Asset:** `docs/images/hero_charlotte.png`
- **Archetype:** High-Mobility Burst Assassin.
- **Controls & Actions:**
  - `LMB`: Rapid dual-blade flurry (CD: 0.28s).
  - `RMB` (Shadow Step): Invulnerable 400 px/s dash followed by 4 piercing stabs (CD: 5.0s).
  - `Q` (Triple Flurry): Executes a stationary 3-slash combination in rapid sequence (CD: 3.0s).
- **Tactics:** Shadow Step through spike traps and projectile volleys, flanking high-priority targets.

#### Index 4: Yugi / Atem (Pharaoh Summoner)
- **Archetype:** Mid-Range Tactical Summoner.
- **Controls & Actions:**
  - `LMB`: Quick monster strike (1x damage); hold 0.65s to unleash charged 2x damage attack.
  - `RMB`: Target-location monster summon (1x damage); hold 0.65s for 3x charged summon.
  - `Hold Shift`: Activates Guard Spirit stance, mitigating incoming damage and enabling combo counter-summons.
  - `Q` (Special Summon): Casts 1 of 5 room-wide spells: Room Blast (50% average enemy HP), Room Laser, Room Lightning, Room Pull, or Room Fire (CD: 12.0s).
- **Tactics:** Scout unexplored rooms by placing RMB summons ahead of your position; hold Shift to absorb projectile barrages.

#### Index 5: Doraemon (22nd-Century Gadget Specialist)
- **Archetype:** Versatile Arsenal Hybrid.
- **Controls & Actions:**
  - `Mouse Scroll` / `Z`, `X`: Cycles through 10 pocket pages containing 20 futuristic gadgets.
  - `LMB` & `RMB`: Activates Gadget 1 and Gadget 2 of the active page (Air Cannon, Anywhere Door, Champion Glove, Shock Gun, Pencil Missiles, Mini-Doras, T-Rex summon, etc.).
  - `Q` (Assist / Super): Below 100 power, summons 1 of 6 companions in rotation (Nobita, Gian, Shizuka, Dorami, Suneo, Come-come Cat). At 100+ power, triggers page-specific super abilities (Uradoraman, SL Chimney, Gian Recital, Dorayakin).
  - `F` (Dorayaki Snack): Consumes a pastry to heal 1 HP and restore 40 power points (CD: 12.0s).
- **Tactics:** Anywhere Door bypasses spike traps and closed choke points; build power with Air Cannon before wiping rooms with super moves.

#### Index 6: Hoshimi Miyabi (Frost Swordswoman)
- **Archetype:** Elemental Melee Duelist.
- **Controls & Actions:**
  - `LMB`: Three-hit frost combo; the third strike lunges forward and inflicts freeze.
  - `Shift`: Invulnerable 72px dash slash cutting through all enemies in path.
  - `Hold RMB`: Charges a piercing Frost Wave penetrating enemy formations.
  - `Q` (Frost Bloom): Erupts sharp ice spikes in a forward cone (3x damage + freeze), followed by shattering burst.
  - `Ice Spirit Familiar`: Automatically tracks and snipes the closest visible enemy every 2 seconds.
- **Tactics:** Freeze elite targets with the 3rd combo hit or charged Frost Wave, then dash through them with Shift for guaranteed critical damage.

#### Index 7: Luong Tho (Twin Gunblade Duelist)
- **Archetype:** Stance-Shifting Hybrid Duelist.
- **Controls & Actions:**
  - `LMB`: Three-stage melee sequence: Stab -> Twin Swing (2 hits) -> Ground Smash (2x damage + daze).
  - `RMB` (Twin Barrels): Fires twin gunblade cartridges along the cursor vector (CD: 0.8s).
  - `Q` (White Moon Form): Transforms for 12 seconds, gaining complete damage immunity, +1 damage on every hit, 25% attack speed, 20% move speed, and piercing bullets (CD: 20.0s).
- **Tactics:** Harass from range with Twin Barrels; activate White Moon when surrounded by elite mobs or boss enrage phases to safely eliminate targets.

---

## 4. Bestiary and Boss Encounters

### 4.1 Standard Enemy Units

| Enemy Type | Sprite Asset | HP | Armor | Damage | Speed | Behavioral AI & Attack Pattern |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **Orc** | `docs/images/enemy_orc.png` | 4 | 0 | 2 | 75.0 | Patrols chamber; charges player with axe strikes upon room lockdown. |
| **Armored Orc** | `docs/images/enemy_armored_orc.png` | 5 | 6 | 2 -> 4 | 70.0 | Heavy vanguard; when 6 armor breaks, enters enrage phase (+50% spd, 4 dmg). |
| **Skeleton** | `docs/images/enemy_skeleton.png` | 3 | 0 | 1 | 110.0 | Fast melee swarmer; closes gaps rapidly in groups or boss summons. |
| **Skeleton Archer** | `docs/images/enemy_skeleton_archer.png` | 5 | 0 | 2 | 70.0 | Tactical kiter; backs away if player is within 85px, sidesteps along walls, shoots arrows (1.6s CD). |
| **Vampire** | `docs/images/enemy_vampire.png` | 5 | 0 | 2 | 85.0 | Aerial predator; closes rapidly in narrow corridors, life-steals on bite (1.4s CD). |
| **Werewolf** | `docs/images/enemy_werewolf.png` | 5 | 0 | 2 | 175.0 | Feral beast; close-range claw attack (2 dmg) and 95px telegraphed pounce (3 dmg) with red warning telegraph. |

### 4.2 Multi-Phase Boss Encounters

#### Necromancer of Dol Guldur (Floor 1, 4, 7...)
- **Visual Asset:** `docs/images/boss_necromancer.png`
- **Base Stats:** 45 HP, 2 Melee Damage, 55.0 Speed.
- **Phase 1 (> 20 HP):** Casts homing dark skull projectiles and summons 3 Skeleton minions.
- **Phase 2 (11 - 20 HP):** Triggers an 8-point toxic eruption ring around his position (3 poison damage).
- **Phase 3 (<= 10 HP):** Enters frenzy mode: +50% movement speed and 50% reduced spell cooldowns.

#### Orc Rider Chieftain (Floor 2, 5, 8...)
- **Visual Asset:** `docs/images/boss_orc_rider.png`
- **Base Stats:** 50 HP, 3 Melee Damage, 75.0 Speed.
- **Phase 1 (> 20 HP):** Sweeping polearm cleave in a 180-degree forward arc.
- **Phase 2 (11 - 20 HP):** Displays red trajectory indicator, then mounts Warg charge at 4x velocity.
- **Phase 3 (<= 10 HP):** Spinning polearm hurricane attack combined with intermittent defensive barrier.

#### The Skeleton King (Floor 3, 6, 9...)
- **Visual Asset:** `docs/images/boss_skeleton_king.png`
- **Base Stats:** 75 HP, 3 Damage, 60.0 Speed.
- **Special Arena Mechanics:**
  - Resides in a dedicated 28x28 grand arena surrounded by 4 resonant Soul Crystals.
  - While Soul Crystals remain intact, the King is completely invulnerable to all damage.
  - Emits rotating cross-room laser grids that cycle clockwise and counter-clockwise.
  - Summons Skeleton Archer skirmishers at 75% and 25% health thresholds.
  - Enrages below 50% HP, doubling projectile density and movement speed.

---

## 5. Procedural Dungeon Generation Architecture

### 5.1 Graph and Grid Spanning Tree Generation
The generator (`Scene/Map/dungeon_generator.gd`) creates 16 connected rooms per floor:
1. **Room Layout Formulation:** Places starting room, combat chambers, treasure vaults, shop rooms, event chambers, and the boss lair across a discrete grid.
2. **Corridor Connectivity:** Establishes minimal spanning tree corridors with 5-tile widths, preventing single-tile corridor bottlenecks.
3. **BFS Boss Placement:** Computes all-pairs shortest paths from the starting chamber using Breadth-First Search (BFS). The Boss chamber is placed at the exact node maximizing the shortest-path distance from the spawn room.

### 5.2 Room Classification Enumeration (`RoomType`)
- `RoomType.START`: Safe spawn room equipped with status displays and control guidance.
- `RoomType.COMBAT`: Locked monster chambers that seal entry doors until all hostiles are slain.
- `RoomType.TREASURE`: Rewards chest room with weapons, armor pieces, and potion drops.
- `RoomType.SHOP`: Merchant chamber where players spend dungeon gold / soul currency.
- `RoomType.EVENT`: Narrative shrine chamber offering risk-reward choices.
- `RoomType.BOSS`: Climax chamber containing multi-phase bosses and transition portals.

### 5.3 Deterministic Seeding and Room Feature Safety
- **RNG Isolation:** Uses a dedicated `RandomNumberGenerator` seeded with `hash(map_seed)`.
- **Reserved Centers & Entrances:** Functions `_reserve_room_centers_and_entrances()` protect a 5x5 area around room centers and a 3-tile buffer around doorways, preventing pillars, spike traps, or chests from blocking navigation.
- **Spike Trap Mechanics:** Stone spike tiles cycle every 2.8 seconds. While extended, spikes block navigation for both heroes and monsters, acting as dynamic cover barriers.

### 5.4 Atmosphere, Lighting and Fog of War
- **Ambient Darkness:** Global dungeon illumination is calibrated to deep midnight `Color(0.06, 0.06, 0.10)`.
- **Hero Lantern:** The active champion emits a circular light gradient illuminating immediate threats.
- **Wall Torches:** Torches on stone pillars remain extinguished until the champion enters the room, igniting dynamically upon threshold crossing.
- **Minimap Fog of War:** Unvisited rooms remain darkened; explored rooms are color-coded (Green: Start, Blue: Cleared, Orange: Active Combat, Gold: Treasure, Cyan: Shop, Purple: Event, Red: Boss).

---

## 6. Combat, Movement and Physics Mechanics

### 6.1 Spatial Line-of-Sight (LoS) Raycasting
Combat relies on 2D raycasting to validate Line-of-Sight between attackers and targets. Projectiles (arrows, spells, bullets) and melee arcs cannot penetrate solid stone walls, closed dungeon doors, or wooden obstacle crates.

### 6.2 Health, Armor and Invulnerability Frames
- **Two-Tier Vitality Pool:** Incoming damage depletes Armor first. Remaining damage spills over into Health.
- **Regenerating Armor:** Out of combat for 5.0 seconds triggers uninterrupted Armor regeneration to maximum capacity.
- **Invulnerability Frames (I-Frames):** Dashing, special abilities, and taking damage trigger a 0.25s - 0.40s invulnerability window with sprite flashing, preventing instant death from dense projectile clouds.

### 6.3 360-Degree Cursor Aiming
All champion attacks, projectile trajectories, and directional dashes align continuously toward the mouse cursor.

---

## 7. Inventory, Equipment and Economy Systems

### 7.1 Grid Storage and Stacking
- **16-Slot Backpack:** 4x4 inventory grid managed by `Scene/UI/GameUI.gd`.
- **9-Slot Action Hotbar:** Keys `1` through `9` trigger quick consumption or equipment swap.
- **Minecraft-Style Item Stacking:** Consumable potions stack up to 16 units per slot with numeric badges. Consuming an item decrements the stack without reordering slots.
- **World Item Drops:** Pressing `G` or right-clicking an inventory slot drops items onto the floor as collectible world pickups.

### 7.2 Equipment Slots and Stat Modifiers
- Five equipment slots: **Helmet**, **Armor**, **Weapon**, **Magic Resist (Amulet)**, and **Boots**.
- Equipping items dynamically updates player stats (Maximum Health, Armor capacity, Attack Damage, Movement Speed) and recalculates HUD numeric bars.

---

## 8. Shop and Event Room Systems (Design Specification)

### 8.1 Shop Room Architecture (`RoomType.SHOP`)
- **NPC Merchant (Dwarven Provisioner):** Positioned at the center of the shop chamber behind an ornate counter. Approaching prompts `[E] Trade with Provisioner`.
- **Stock Inventory:**
  - 2 Health Potions / Armor Potions (stackable).
  - 1 Weapon / Armor item scaled to current floor depth.
  - 1 Rare / Epic Perk scroll from the perk draft pool.
- **Currency Engine:** Enemies drop Gold Coins and Soul Crystals upon defeat. Prices scale with dungeon depth:
  $$\text{Price} = \text{Base Price} \times (1.0 + 0.35 \times (\text{Floor} - 1))$$

### 8.2 Event Room Architecture (`RoomType.EVENT`)
- **Shrine of Khazad-dum:** Interactive altar offering high-risk, high-reward bargains:
  - *Altar of Blood:* Sacrifice 2 Maximum HP to gain +2 permanent Melee Damage.
  - *Altar of Fortitude:* Sacrifice 1 Attack Damage to gain +4 permanent Armor capacity.
  - *Palantir Rift:* Trigger an optional elite enemy wave to earn an immediate Legendary Perk draft.
- **Safety Guarantee:** Event rooms are completely free of hostile spawns until the player confirms an altar interaction.

---

## 9. 30-Perk Progression System

Upon clearing a floor boss or interacting with special shrines, players draft 1 of 3 randomly offered perks.

### 9.1 Perk Rarity Tiers
- **Common (White):** Flat stat bonuses (+1 HP, +1 Armor, +10 Speed).
- **Rare (Blue):** Combat modifications (Life-steal chance, +25% attack speed, thorns reflection).
- **Epic (Purple):** Special mechanics (Explosive deaths on enemies, projectile ricochets, shield shockwaves).
- **Legendary (Gold):** Game-changing traits (Second-chance revival with 50% HP, permanent spike trap immunity, double active skill charges).

### 9.2 Drafting and Deduplication Engine
The `PerkManager` singleton maintains an active draft pool, filtering out already-acquired unique perks to prevent invalid stacking while permitting repeatable stat boosters.

---

## 10. Replay System and Memory Protection

### 10.1 Fixed 60Hz Physics Recording
All player actions (movement vectors, cursor angles, LMB/RMB presses, hotbar triggers) are recorded as lightweight frame packets at 60 Hz.

### 10.2 Memory Protection Constraints
- **10-Replay Hard Capacity (`MAX_SAVED_REPLAYS = 10`):** FIFO eviction frees raw frame buffers of older runs, retaining only summary metadata to prevent memory leaks.
- **Manual Deletion:** Players can delete individual replay recordings from the Expedition History menu.
- **Frame Bounding & Anti-DoS:** Bounded to 3,600 recorded frames per run (60 seconds at 60 FPS). Consecutive stationary idle frames are deduplicated.
- **Strict 2MB File Cap:** Replay save files exceeding 2 MB are rejected during parsing.

---

## 11. Graphics, Display and Performance System

### 11.1 FPS Limiter
- **Discrete Presets:** 30 FPS, 60 FPS, 120 FPS, 144 FPS, and Unlimited (0 FPS cap).
- **Custom FPS Slider:** Configurable from 20 to 360 FPS via synchronized slider and numeric SpinBox.
- **Hardware Throttling:** Direct synchronization via `Engine.max_fps`.

### 11.2 Resolution and Display Modes
- **6 Resolution Presets:** 1280x720, 1366x768, 1600x900, 1920x1080, 2560x1440, 3840x2160.
- **Window Modes:** Windowed, Borderless Fullscreen, and Exclusive Fullscreen.
- **VSync Modes:** Disabled, Enabled, and Adaptive.

### 11.3 Audio System & Persistence
- Linear volume sliders for Master, BGM, and SFX mapped logarithmically (-30 dB to 0 dB, -80 dB on mute).
- All settings persist automatically to `user://settings.cfg` using Godot's `ConfigFile` API.

---

## 12. Automated Quality Assurance and Test Suites

The project incorporates 16 automated test suites executing headlessly on Godot Engine:

| Suite # | Scene Path | Test Scope & Checks |
| :---: | :--- | :--- |
| 1 | `tests/test_dungeon_generator_unit.tscn` | 28 checks: Room constraints, BFS optimality, LoS blocks, BalanceConfig sync. |
| 2 | `tests/test_dungeon_properties.tscn` | 11 checks across 100 seeds: Determinism, connectivity, flood-fill walkability, safe spawns. |
| 3 | `tests/test_orc_battle.tscn` | 5 checks: 360-degree rotational hitbox accuracy across 5 cardinal directions. |
| 4 | `tests/benchmark_dungeon_generator.tscn` | Performance benchmark across 10 to 50 rooms (average ~130ms for 16 rooms). |
| 5 | `tests/test_skeleton_king.tscn` | 22 checks: Soul Crystals, laser volleys, enrage states, arena unlock transitions. |
| 6 | `tests/test_doraemon.tscn` | 49 checks: 20 gadgets, 6 friend assists, 10 supers, crate collision blocking. |
| 7 | `tests/test_yugi.tscn` | Directional attacks, charged summons, guard stance, and 5 room spells. |
| 8 | `tests/test_werewolf.tscn` | 50 checks: Claw attacks, pounce warning telegraph, damage interruption, 95px clamping. |
| 9 | `tests/test_moba_hud_and_inventory.tscn` | 157 checks: Numeric health/armor bars, potion stacking up to 16, drag-and-drop. |
| 10 | `tests/test_miyabi.tscn` | 18 checks: 3-hit frost combo, dash slash, Frost Wave, Frost Bloom, ice spirit AI. |
| 11 | `tests/test_luong_tho.tscn` | 15 checks: 3-step weapon combo, Twin Barrels firing, White Moon transformation. |
| 12 | `tests/test_projectile_obstacles.tscn` | 11 checks: Wooden crates blocking projectiles, ricochet bounces, pass-through decor. |
| 13 | `tests/test_archer_combat_lifecycle.tscn` | 12 checks: Skeleton Archer AI, kiting behavior, arrow collisions, cleanup. |
| 14 | `tests/test_perk_system.tscn` | 37 checks: 30 perks, 4 rarities, deterministic drafting, deduplication, revivals. |
| 15 | `tests/test_replay_security.tscn` | 39 checks: 10-replay hard cap, FIFO eviction, frame bounding, anti-DoS idle compression. |
| 16 | `tests/test_settings_and_ui.tscn` | 100 checks: FPS limiter, resolutions, window modes, vsync, audio, UI dossier scrolling. |
