extends RefCounted

## Shared combat helpers: reference-counted stun/freeze locks on physics_process
## and unified player damage dispatch through apply_on_hit_effects().

const META_STUN_COUNT := "_stun_lock_count"
const META_ORIG_PHYSICS := "_stun_orig_physics"

static func acquire_stun_lock(target: Node) -> void:
	if not is_instance_valid(target) or target.get("is_immovable") == true:
		return
	var count: int = int(target.get_meta(META_STUN_COUNT, 0))
	if count == 0:
		target.set_meta(META_ORIG_PHYSICS, target.is_physics_processing())
	target.set_meta(META_STUN_COUNT, count + 1)
	target.set_physics_process(false)
	if target is CharacterBody2D:
		(target as CharacterBody2D).velocity = Vector2.ZERO

static func release_stun_lock(target: Node) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	var count: int = int(target.get_meta(META_STUN_COUNT, 0))
	if count <= 0:
		return
	count -= 1
	if count > 0:
		target.set_meta(META_STUN_COUNT, count)
		return
	var orig: bool = bool(target.get_meta(META_ORIG_PHYSICS, true))
	target.remove_meta(META_STUN_COUNT)
	target.remove_meta(META_ORIG_PHYSICS)
	if target.get("is_dead") != true:
		target.set_physics_process(orig)

static func resolve_player(source: Node) -> Node:
	if is_instance_valid(source) and source.has_method("apply_on_hit_effects"):
		return source
	if is_instance_valid(source) and source.is_inside_tree() and source.get_tree() != null:
		var players := source.get_tree().get_nodes_in_group("player")
		if not players.is_empty() and is_instance_valid(players[0]):
			return players[0]
	return null

static func deal_player_damage(source: Node, target: Node, raw_damage: int, call_on_hit: bool = true) -> int:
	# Training contact is resolved before perks/RNG and never enters enemy death.
	if is_instance_valid(target) and target.has_method("receive_training_contact"):
		return target.receive_training_contact(source, raw_damage)
	if not is_instance_valid(target) or target.is_queued_for_deletion() or target.get("is_dead") == true:
		return 0
	if not target.has_method("take_damage"):
		return 0
	var final_dmg := raw_damage
	if call_on_hit and target is Node2D:
		var player_node := resolve_player(source)
		if is_instance_valid(player_node) and player_node.has_method("apply_on_hit_effects"):
			final_dmg = int(player_node.apply_on_hit_effects(target as Node2D, raw_damage))
	if is_instance_valid(target) and not target.is_queued_for_deletion() and target.get("is_dead") != true:
		target.take_damage(final_dmg)
	return final_dmg

## Preserve the actual effect's immutable fact, while keeping production caster
## resolution unchanged. A delayed summon must not borrow a newer hero action.
static func damage_source(effect: Node, caster: Node) -> Node:
	return effect if effect.has_meta("training_fact") else caster
