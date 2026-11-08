class_name EnemyTactics
extends RefCounted
## Tactical AI foundation only; no scene, autoload, movement or combat dependencies.
## Create one instance per enemy at spawn. Tier 0 leaves the existing AI in charge.
## Later adapters choose a candidate state using the profile, then request a change.
## They must still handle activation/hurt/death/attack locks, steer desired directions
## through the map and check fresh LoS before attacking (including delayed shots).
## No RNG or wall clock is used. Pass a nonnegative, enemy-local simulation tick;
## reset at spawn/replay start and advance ticks at the same fixed rate in replays.

enum Tier { BASIC, SIMPLE, ADVANCED, ADAPTIVE }

# Seconds are converted once to physics ticks. Tier 3 is capped at 5 decisions/s,
# with at least 0.4 s per tactical state at the project's default 60 physics Hz.
const _TIER_SETTINGS = [
	{"decision_interval_seconds": 0.0, "min_state_duration_seconds": 0.0, "max_neighbor_samples": 0},
	{"decision_interval_seconds": 0.3, "min_state_duration_seconds": 0.6, "max_neighbor_samples": 0},
	{"decision_interval_seconds": 0.25, "min_state_duration_seconds": 0.5, "max_neighbor_samples": 3},
	{"decision_interval_seconds": 0.2, "min_state_duration_seconds": 0.4, "max_neighbor_samples": 4},
]

# Each parameter has one value per tier; add another enemy ID here to extend.
# These are policy limits for future adapters, not changes to combat stats.
# Prediction may use only observed target motion; it is capped at 0.25 seconds.
# Neighbor samples must come from a bounded, stably ordered list in the adapter.
const _TACTIC_VALUES = {
	"orc": {
		# A bounded approach offset; separation becomes available at tier 2.
		"flank_angle_radians": [0.0, 0.25, 0.45, 0.6],
		"separation_radius_px": [0.0, 0.0, 24.0, 32.0],
		"prediction_seconds": [0.0, 0.0, 0.0, 0.2],
	},
	"skeleton_archer": {
		# Retreat/strafe already exist in the archer; these only tune future tactics.
		# Hysteresis is an exit margin, never permission to extend attack range.
		"range_hysteresis_px": [0.0, 8.0, 12.0, 16.0],
		# Maximum lateral search duration when LoS is blocked, before approaching.
		"lateral_reposition_seconds": [0.0, 0.0, 0.6, 0.8],
		"prediction_seconds": [0.0, 0.0, 0.0, 0.25],
	},
}

var _profile: Dictionary = {}
var _decision_interval_ticks: int = 1
var _min_state_ticks: int = 1
var _next_decision_tick: int = 0
var _last_decision_tick: int = -1
var _state: StringName = &"basic"
var _state_since_tick: int = -1


## Invalid floors safely retain tier 0; all floors from 7 onward cap at tier 3.
static func get_tier_for_floor(floor_number: int) -> int:
	if floor_number <= 2:
		return Tier.BASIC
	if floor_number <= 4:
		return Tier.SIMPLE
	if floor_number <= 6:
		return Tier.ADVANCED
	return Tier.ADAPTIVE


## Returns a fresh profile. Unknown enemy IDs return {}, leaving their AI alone.
## Cache at spawn; profile construction is not intended for per-frame calls.
static func get_profile(enemy_id: String, floor_number: int) -> Dictionary:
	if not _TACTIC_VALUES.has(enemy_id):
		return {}
	var tier := get_tier_for_floor(floor_number)
	var profile: Dictionary = _TIER_SETTINGS[tier].duplicate(true)
	profile["enemy_id"] = enemy_id
	profile["tier"] = tier
	profile["enabled"] = tier != Tier.BASIC
	var tactics: Dictionary = {}
	var parameters: Dictionary = _TACTIC_VALUES[enemy_id]
	for parameter in parameters:
		tactics[parameter] = parameters[parameter][tier]
	profile["tactics"] = tactics
	return profile


## Pass the simulation's fixed tick rate, not the rendering frame rate.
func _init(enemy_id: String = "", floor_number: int = 1, physics_ticks_per_second: int = 60) -> void:
	_profile = get_profile(enemy_id, floor_number)
	var tick_rate := maxi(1, physics_ticks_per_second)
	_decision_interval_ticks = maxi(1, ceili(float(_profile.get("decision_interval_seconds", 0.0)) * tick_rate))
	_min_state_ticks = maxi(1, ceili(float(_profile.get("min_state_duration_seconds", 0.0)) * tick_rate))


func is_enabled() -> bool:
	return bool(_profile.get("enabled", false))


## A copy prevents an adapter from mutating this enemy's scheduling/configuration.
func get_config() -> Dictionary:
	return _profile.duplicate(true)


## Consumes at most one decision opportunity per interval, even after a long gap.
## Call before gathering tactical observations; no catch-up loops or world scans.
## Tier 0/unknown IDs always return false: run their existing AI directly.
func begin_decision(physics_tick: int) -> bool:
	if not is_enabled() or physics_tick < 0 or physics_tick < _next_decision_tick:
		return false
	_last_decision_tick = physics_tick
	_next_decision_tick = physics_tick + _decision_interval_ticks
	return true


## Generic finite-state guard. The adapter owns the rules and valid state names.
## Only the current decision opportunity can change state. Keeping the same state
## does not renew its hold time, so a persistent tactic cannot lock out transitions.
## Safety checks/attack cancellation stay in the enemy and must bypass this helper.
func try_change_state(candidate: StringName, physics_tick: int) -> bool:
	if not is_enabled() or physics_tick < 0 or physics_tick != _last_decision_tick:
		return false
	if candidate == &"" or candidate == _state:
		return false
	if _state_since_tick >= 0 and physics_tick - _state_since_tick < _min_state_ticks:
		return false
	_state = candidate
	_state_since_tick = physics_tick
	return true


func get_state() -> StringName:
	return _state


## Clear transient state when restarting the local simulation tick at zero.
func reset() -> void:
	_next_decision_tick = 0
	_last_decision_tick = -1
	_state = &"basic"
	_state_since_tick = -1
