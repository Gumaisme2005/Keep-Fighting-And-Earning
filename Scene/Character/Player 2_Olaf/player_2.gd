extends "res://Scene/Character/Player 1_Pyrois/player.gd"

@export var buff_duration: float = 5.0
@export var damage_multiplier: int = 2

var is_berserking: bool = false

func _ready() -> void:
	hero_balance_id = "olaf"
	var cfg: Dictionary = BalanceData.get_hero_stats("olaf")
	buff_duration = float(cfg.get("buff_duration", 5.0))
	damage_multiplier = int(cfg.get("damage_multiplier", 2))
	super._ready()

func use_special_skill() -> void:
	if not can_use_skill:
		return

	start_skill_cooldown()
	is_casting_skill = true
	animated_sprite.play("skill")
	if get_tree():
		get_tree().call_group("game_ui", "show_toast", "BERSERK RAGE — Double damage for 5 seconds!")

	is_berserking = true
	stats_changed.emit(hp, max_hp, current_armor, max_armor)

	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return
	is_casting_skill = false

	if not is_dead and animated_sprite.animation == "skill":
		animated_sprite.play("idle")

	await get_tree().create_timer(buff_duration - 0.6).timeout
	if not is_inside_tree():
		return

	is_berserking = false
	if not is_dead:
		stats_changed.emit(hp, max_hp, current_armor, max_armor)

func get_raw_damage() -> float:
	var raw: float = super.get_raw_damage()
	if is_berserking:
		raw *= float(damage_multiplier)
	return raw
