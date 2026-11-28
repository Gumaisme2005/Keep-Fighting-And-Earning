extends Node2D
## A practice prop, deliberately outside enemy/boss groups and death/reward APIs.
var hp: int = 100
var is_dead: bool = false
var is_active: bool = true
var is_immovable: bool = true
var contacts: int = 0
var feedback_left: float = 0.0
var context: WeakRef

func receive_training_contact(source: Node, amount: int) -> int:
	var owner_context = context.get_ref() if context != null else null
	if not is_instance_valid(owner_context) or not owner_context.confirm_contact(source, self, amount):
		return 0
	contacts += 1
	hp = maxi(1, hp - mini(amount, hp - 1))
	feedback_left = 0.12
	$Sprite.modulate = Color(1.5, 1.5, 1.5)
	owner_context.feedback(&"spawn_damage_number", [global_position, amount, Color("f4d58c")])
	return amount

## Unattributed damage is not gameplay evidence, and cannot enter enemy death.
func take_damage(_amount: int, _armor_piercing: float = 0.0) -> void:
	pass

func reset_target() -> void:
	hp = 100
	contacts = 0
	feedback_left = 0.0
	$Sprite.modulate = Color.WHITE

func _physics_process(delta: float) -> void:
	if feedback_left > 0.0:
		feedback_left = maxf(0, feedback_left - delta)
		if feedback_left == 0.0:
			$Sprite.modulate = Color.WHITE
