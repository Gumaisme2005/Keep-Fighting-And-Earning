extends Node2D

var radius := 80.0
var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 0.3:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var opacity := 1.0 - elapsed / 0.3
	draw_circle(Vector2.ZERO, radius, Color(0.7, 0.25, 1.0, opacity * 0.22))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(0.95, 0.7, 1.0, opacity), 2.0)
