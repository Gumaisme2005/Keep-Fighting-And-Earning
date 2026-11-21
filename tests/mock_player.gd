extends Node2D

var hp: int = 10
var max_hp: int = 16

func consume_potion(heal: int, max_hp_bonus: int) -> bool:
	hp += heal
	max_hp += max_hp_bonus
	return true
