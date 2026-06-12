extends CanvasLayer

## Shows collected items at top of screen

@onready var container: HBoxContainer = $HBoxContainer


func _ready() -> void:
	GameState.inventory_changed.connect(_refresh)


func _refresh(items: Array[String]) -> void:
	for child in container.get_children():
		child.queue_free()

	for item_id: String in items:
		var label := Label.new()
		label.name = item_id
		label.text = _item_name(item_id)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))

		var bg := Panel.new()
		bg.add_child(label)
		label.position = Vector2(6, 2)
		bg.size = label.size + Vector2(12, 4)
		container.add_child(bg)


func _item_name(id: String) -> String:
	match id:
		"small_key": return "小钥匙"
		"remote_control": return "遥控器"
		"receipt": return "外卖单"
		_: return id
