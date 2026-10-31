extends "res://Scene/Character/Player 1_Pyrois/player.gd"

@export var buff_duration: float = 5.0
@export var damage_multiplier: int = 2

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
		get_tree().call_group("game_ui", "show_toast", "[HUYẾT NỘ] x2 Sát thương trong 5 giây!")

	var bonus_damage = base_damage * (damage_multiplier - 1)
	base_damage += bonus_damage
	stats_changed.emit(hp, max_hp, current_armor, max_armor)

	await get_tree().create_timer(0.6).timeout
	is_casting_skill = false

	if not is_dead and animated_sprite.animation == "skill":
		animated_sprite.play("idle")

	await get_tree().create_timer(buff_duration - 0.6).timeout

	base_damage -= bonus_damage
	if not is_dead:
		stats_changed.emit(hp, max_hp, current_armor, max_armor)
