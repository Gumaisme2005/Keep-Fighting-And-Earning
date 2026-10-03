extends Area2D

@onready var anim = $AnimatedSprite2D
var is_open = false

func _ready():
	# Vừa sinh ra, rương tự động chạy hiệu ứng đóng (idle)
	anim.play("idle")

func _on_body_entered(body):
	# Kiểm tra nếu người chạm vào là Player và rương chưa mở
	if body.name == "Player" and not is_open:
		is_open = true
		anim.play("open") # Chuyển sang 4 frame ảnh rương mở
		
		# --- CHỖ NÀY DÀNH CHO BƯỚC TIẾP THEO CỦA CẬU ---
		# print("Đã mở rương! Code rớt tiền/vũ khí sẽ viết ở đây")
