# Yugi / Atem

Fifth hero (index 4); existing hero indices stay unchanged. Original supplied PNGs
are copied into Assets/Character/Yugi without alteration. YugiSprites extracts
atlas regions and pads to a bottom-center origin; key_green removes the flat
green background at render time. Keep the source artist attribution with assets.

Controls:
- WASD: move; mouse: aim.
- Click left/right: release to cast the corresponding summon.
- Hold left/right at least 0.65 seconds, then release: charged summon.
- Shift: immediate guard while held; release ends it immediately. The character
  and guardian animations play once and hold their final frames. A click cancels
  guard and casts the corresponding Shift combo. Release Shift before guarding again.
- Q: one of five results, each 20%, cooldown 12 seconds. The chosen result and
  mouse press/release/Shift events are recorded and preserved by replay sanitization.

Initial balance: HP 5, armor 1, damage 1, speed 150. Guard blocks damage and reduces
movement speed. Normal/charged/combo/special multipliers live in yugi.gd.

Implementation scope: summons currently use short-lived moving or local hitboxes,
one hit per target, and existing dungeon line-of-sight checks. Normal right-click uses a stationary monster (eight poses) that emits exactly one
independent energy ball after 0.5 seconds. The ball uses the final two sheet frames,
travels toward the cast aim at 220 px/s, and uses the existing arrow collision and
wall checks. Other combined monster/projectile artwork remains combined; summons
are not independent AI companions.
The large special sheets use selected attack rows rather than their full cinematic
summoning sequences. Hurt currently uses a brief idle pose. Death uses the four frames from death.png,
plays once at 10 FPS, and holds the final frame without fading out.

Headless regression scene: res://tests/test_yugi.tscn. Covers registration,
animation extraction, guard, guard cancellation, quick clicks, charging, special
selection and replay field preservation. Manual visual/gameplay balancing remains
necessary, especially summon scale, timing and hitbox size.

Result 1 now uses room_blast.gd: summon beside Yugi; the orb travels from the summon to the room center,
release at 0.8s, ground impact at the center at 1.3s, one room-wide damage event. Room membership
is captured from generated_rooms at cast time; live enemies (including summoned
minions) are selected spatially at impact. Damage per enemy is the mean CURRENT
HP before any hits, rounded to the nearest integer for the existing take_damage
API. It does not multiply by weapon damage or include armor in the mean. Normal
enemy armor/invulnerability handling still applies. Empty rooms deal no damage.

Result 2 uses room_laser.gd: charges to frame 5 (largest orb), holds that pose
for a 3-second beam, then plays recovery once. Targets the highest current HP
in the captured room, tracks that enemy until death/removal/leaving the room,
and then selects the highest-HP survivor. Each 0.25s tick deals Yugi's total
weapon damage through take_damage. No targets means no visible beam; duration
still expires. Room restrictions and retargeting are covered by test_yugi.

Result 3: room_lightning.gd joins the two supplied creature strips at 8 FPS,
ignoring the previous-row remnants at the top of part 2. At the attack pose it
strikes all living room members once for 4x Yugi total damage. lightning_hit.gd
plays the supplied lightning clusters and suspends enemy physics movement for
2 seconds, then restores the prior physics state. Repeated hits refresh the
same status instead of stacking restoration timers. Death never re-enables AI.
This is a movement immobilization; existing asynchronous attacks may finish.

Result 4: room_pull.gd plays summon, attack, and recovery rows once. When the
summon finishes, living enemies in the captured room teleport to valid floor
cells ahead of the summon. Their positions are pinned until recovery finishes,
and their previous physics state is restored on completion or early removal.
If no valid front cell exists, the target is pinned at its original position.
A single attack deals 4x Yugi total damage. Enemies in other rooms are unaffected.

Result 5: room_fire.gd summons beside Yugi and channels for 3 seconds. One beam
tracks each living enemy in the captured room, simultaneously. fire_beam.gd uses
the two supplied body/head states, alternating at 10 FPS. Damage ticks every
0.25 seconds for Yugi total damage per target. Dead/removed/out-of-room targets
lose their beam; all beams are removed at the end. Tests cover simultaneous hits,
two-state animation, tracking, dead-target removal and room boundaries.
