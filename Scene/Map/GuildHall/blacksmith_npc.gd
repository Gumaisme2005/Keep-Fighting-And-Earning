extends AnimatedSprite2D
## NPC bán hàng trong Guild Hall (thợ rèn; mage_npc.gd dùng lại cho nhóm pháp sư): đứng gần (vùng TalkArea) sẽ hiện gợi ý "[E] SHOP", nhấn E (action "interact") để mở cửa hàng.

signal shop_opened(ui: CanvasLayer)
signal shop_closed

const SHOP_UI_SCRIPT := preload("res://Scene/UI/Shop/ShopUI.gd")

var hero_near: Node2D = null
var shop: CanvasLayer = null
var _t := 0.0

@onready var _prompt: Sprite2D = get_node_or_null("Prompt")
@onready var _prompt_y: float = _prompt.position.y if _prompt != null else 0.0

func _ready() -> void:
	var area := get_node_or_null("TalkArea") as Area2D
	if area != null:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
	if _prompt != null:
		_prompt.visible = false

func _process(delta: float) -> void:
	if _prompt == null:
		return
	_prompt.visible = hero_near != null and shop == null
	if _prompt.visible:
		_t += delta
		_prompt.position.y = _prompt_y + roundf(sin(_t * 4.0) * 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo() and can_open():
		get_viewport().set_input_as_handled()
		open_shop()

func can_open() -> bool:
	return hero_near != null and is_instance_valid(hero_near) and shop == null \
		and hero_near.get("is_dead") != true and not get_tree().paused

func open_shop() -> CanvasLayer:
	if shop != null:
		return shop
	var who: Node2D = hero_near
	if who == null:
		for n in get_tree().get_nodes_in_group("player"):
			if n is CharacterBody2D:
				who = n
				break
	if who == null:
		return null
	if "velocity" in who:
		who.velocity = Vector2.ZERO
	if _prompt != null:
		_prompt.visible = false
	shop = _create_shop(who)
	shop.closed.connect(_on_shop_closed)
	shop_opened.emit(shop)
	return shop

## Tạo giao diện cửa hàng (lớp con như mage_npc.gd ghi đè để mở shop khác).
func _create_shop(who: Node2D) -> CanvasLayer:
	return SHOP_UI_SCRIPT.open(who, get_tree().current_scene)

func _on_shop_closed() -> void:
	shop = null
	shop_closed.emit()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		hero_near = body

func _on_body_exited(body: Node2D) -> void:
	if body == hero_near:
		hero_near = null
