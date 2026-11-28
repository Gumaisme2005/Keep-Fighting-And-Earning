extends Area2D
## Real physics overlap, safe nonlethal production damage. No AI/reward path.
var context: WeakRef
var cooldown: float = 0.0
var contacts: int = 0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	collision.shape = shape
	add_child(collision)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 14.0, Color(0.9, 0.3, 0.15, 0.5))

func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	var owner_context = context.get_ref() if context != null else null
	if cooldown > 0.0 or not is_instance_valid(owner_context) or not owner_context.live():
		return
	var actor: CharacterBody2D = owner_context.hero
	if not get_overlapping_bodies().has(actor):
		return
	if owner_context.hazard_contact(self, actor):
		contacts += 1
		cooldown = maxf(1.2, actor.invincibility_time + 0.1)
