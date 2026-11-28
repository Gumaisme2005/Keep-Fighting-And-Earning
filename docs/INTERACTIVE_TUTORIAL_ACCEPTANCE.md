# Interactive Tutorial: acceptance record

Task 5 separates engine assertions, rendered GUI evidence, and human acceptance. A screenshot or scripted input does not establish that a new player understands the lesson or that a hero feels unchanged. Human acceptance is **NOT VERIFIED** until a reviewer actually plays and records the result below.

## Playing the Tutorial

Start a new run from the main menu and select any of the eight heroes. After the selection fade, choose **Start Tutorial** in the optional invitation, or **Not Now** to play normally. The **Adventurer Training** button in Guild Hall opens it again, including on later completed visits. **Train again** is available after practice while the final portal lesson is still active.

The eight lessons are movement in three directions, basic attack, the hero's representative skill, armor pickup, equipment, health/armor recovery, potion use and dungeon entry. Practice uses a private hero and gives no rewards. The last lesson restores the original hero and shows a gold marker at Rune Portal; press the displayed interaction binding and confirm to enter. Completion is saved only after the real dungeon is initialized.

**Pause / Resume**, **Skip Tutorial** and **Restart / Recover** remain visible during practice. Skip/restart ask for confirmation. Restart replaces the practice arena and restores its starter resources; it preserves the original run. Use it if an item or potion is lost. Manual replay and skip do not erase a previously saved completion.

## Human review protocol

Use a disposable Godot user-data profile. Start from the main menu, select a hero, accept training, and perform all eight lessons using the displayed bindings. Do not use debug completion, synthetic handoff signals, or a pre-completed profile for first-visit checks. Repeat with a completed profile to check manual replay. Record engine version, OS, resolution, DPI, hero, result, and evidence for each case. A failed case needs reproduction steps; an unavailable environment stays NOT VERIFIED.

| ID | Human action and expected result | Result |
|---|---|---|
| MAN-01 | First visit: consent appears after selection/fade and clearly offers optional training | NOT VERIFIED |
| MAN-02 | Not Now returns control without reward or completion; ordinary Hall gameplay works | NOT VERIFIED |
| MAN-03 | Start, move in three directions, aim, miss then hit using only displayed instructions; assess movement/attack feel | NOT VERIFIED |
| MAN-04 | Use the selected hero's representative skill; compare range/timing/feel with ordinary gameplay | NOT VERIFIED |
| MAN-05 | Pick up armor, equip through click and hotbar; bag/equipment/status remain readable | NOT VERIFIED |
| MAN-06 | Read armor/HP feedback, wait for natural regeneration, use a potion; full healing/cooldown/early consumption/drop have clear recovery | NOT VERIFIED |
| MAN-07 | Pause/resume while holding movement, Q, RMB and attack; no input reaches the production hero | NOT VERIFIED |
| MAN-08 | Restart/skip rapidly and while controls are held; one clone, no stuck cursor or duplicate menus | NOT VERIFIED |
| MAN-09 | Alt-Tab during movement/attack; release controls outside the app, return, explicitly resume; test tapping/releasing a stuck control | NOT VERIFIED |
| MAN-10 | Resize during attack, drag across UI, inspect modals/tooltips at 960x600, 1280x720, 1366x768, 1920x1080 and fullscreen | NOT VERIFIED |
| MAN-11 | Finish practice and return to the original Hall hero with resources, cursor, focus and normal control preserved | NOT VERIFIED |
| MAN-12 | Follow the gold marker to Rune Portal; cancel repeatedly, reopen, confirm; completion waits for the playable dungeon | NOT VERIFIED |
| MAN-13 | After completion, move, attack, use a skill and normal production inventory; compare behavior/resources with ordinary play | NOT VERIFIED |
| MAN-14 | Close the application, relaunch from disk and verify no automatic prompt | NOT VERIFIED |
| MAN-15 | Returning player manually replays, restarts and skips without losing existing completion | NOT VERIFIED |

## Per-hero human sign-off

Each cell below refers to MAN-01 through MAN-15 independently; it is not inherited from another hero or from the automated matrix.

| Hero | MAN-01–15 | Reviewer/date/environment/evidence |
|---|---|---|
| Miya | All NOT VERIFIED | Pending |
| Olaf | All NOT VERIFIED | Pending |
| Pyrois | All NOT VERIFIED | Pending; explicitly compare charge feel |
| Charlotte | All NOT VERIFIED | Pending |
| Yugi/Atem | All NOT VERIFIED | Pending; hold/release and summons |
| Doraemon | All NOT VERIFIED | Pending; power, gadgets, companion and F healing |
| Hoshimi Miyabi | All NOT VERIFIED | Pending; combo/passive/dash |
| Luong Tho | All NOT VERIFIED | Pending; transformation and modifiers |

## Environment limits and release gates

Automated tests use native Godot 4.7.2 on Windows, disposable saves, real gameplay callbacks/collisions and actual rendered windows where specified. Controlled fault injection is explicitly identified in the design report. It establishes recovery contracts, not human play quality.

Actual Alt-Tab with a lost OS key-up, unusual DPI, multiple monitors, physical low-end hardware, sudden power loss and concurrent independent save writers are NOT VERIFIED. The automated minimize attempt must report NOT VERIFIED if the environment does not deliver `focus_exited`; it must not manufacture an OS focus event or reset unrelated global inputs to claim success. Existing deterministic focus-handler and held-input tests remain separate.

Technical fixes may be committed and pushed once their automated gates pass, as authorized in Task 5. Human sign-off and the new commit's full CI remain merge gates. No PR creation or merge is authorized by this record.
