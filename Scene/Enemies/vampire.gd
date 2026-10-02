extends CharacterBody2D

@export var speed: float = 60.0 # Đi chậm lù đù
@export var attack_range: float = 40.0 # Tầm cắn cận chiến

var hp: int = 4 # Máu trâu hơn các con khác
var is_dead: bool = false
var is_attacking: bool = false

@onready var animated_sprite = $AnimatedSprite2D
@onready var bite_hitbox = $BiteHitbox
@onready var bite_collision = $BiteHitbox/CollisionShape2D
var player: Node2D = null

func _ready() -> void:
	animated_sprite.play("idle")
	bite_collision.disabled = true
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(_delta: float) -> void:
	if is_dead or player == null or animated_sprite.animation == "hurt":
		return

	var distance = global_position.distance_to(player.global_position)
	var direction = global_position.direction_to(player.global_position)

	# Lật mặt và lật vùng cắn theo hướng di chuyển
	if direction.x < 0:
		animated_sprite.flip_h = true
		bite_hitbox.scale.x = -1
	else:
		animated_sprite.flip_h = false
		bite_hitbox.scale.x = 1

	if is_attacking:
		return 

	if distance <= attack_range:
		attack() 
	else:
		velocity = direction * speed
		move_and_slide()
		animated_sprite.play("walk")

func attack():
	is_attacking = true
	animated_sprite.play("attack")
	bite_collision.disabled = false # Bật hitbox để cắn

func take_damage(damage_amount: int) -> void:
	if is_dead: return 
	
	hp -= damage_amount
	if hp > 0:
		animated_sprite.play("hurt")
		is_attacking = false
		bite_collision.set_deferred("disabled", true)
	else:
		is_dead = true
		animated_sprite.play("death")
		$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
		$CollisionShape2D.set_deferred("disabled", true)
		bite_collision.set_deferred("disabled", true)


# --- CÁC HÀM TÍN HIỆU (SIGNALS) ---

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "death":
		queue_free() 
	elif animated_sprite.animation == "hurt":
		if not is_dead:
			animated_sprite.play("idle") 
	elif animated_sprite.animation == "attack": 
		is_attacking = false
		bite_collision.disabled = true
		animated_sprite.play("idle")


func _on_bite_hitbox_area_entered(area: Area2D) -> void:
	if area.name == "PlayerHurtbox":
		var target = area.get_parent() 
		if target.has_method("take_damage"):
			target.take_damage(1)
