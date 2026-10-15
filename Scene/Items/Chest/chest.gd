extends Area2D

# 3 biến này dùng để thiết lập rớt đồ trong bảng Inspector
@export var world_item_scene: PackedScene 
@export var loot_table: Array[ItemData] = []
@export var drop_chance: float = 1.0 # 1.0 = 100% ra đồ, 0.5 = 50% ra đồ

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
		
		# Tắt vùng va chạm để rương không vô tình bị kích hoạt lại
		$CollisionShape2D.set_deferred("disabled", true)
		
		# Gọi hàm văng đồ ra ngoài
		spawn_loot()

func spawn_loot():
	# Kiểm tra xem có đủ dữ liệu để rớt đồ không
	if world_item_scene != null and loot_table.size() > 0:
		# Lăn xúc xắc xem có trúng tỷ lệ drop_chance không
		if randf() <= drop_chance:
			var random_item = loot_table.pick_random() # Bốc bừa 1 món trong rương
			var item_drop = world_item_scene.instantiate()
			item_drop.item_data = random_item
			
			# Cho món đồ văng lệch xuống dưới rương một khoảng (20 pixel) để không bị đè hình
			item_drop.global_position = global_position + Vector2(0, 20) 
			
			get_tree().current_scene.call_deferred("add_child", item_drop)
