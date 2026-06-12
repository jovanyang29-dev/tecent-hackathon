extends HBoxContainer


func _ready() -> void:
	GameState.inventory_changed.connect(_on_inventory_changed)
	_on_inventory_changed(GameState.inventory)


func _on_inventory_changed(items: Array[String]) -> void:
	for child in get_children():
		child.queue_free()

	for item_id in items:
		var label := Label.new()
		label.text = item_id
		add_child(label)
