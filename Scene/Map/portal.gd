extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("🌀 Cổng không gian được kích hoạt!")
		# Báo cho TileMap biết để tiến hành tạo màn mới
		if get_parent().has_method("next_level"):
			get_parent().next_level()
