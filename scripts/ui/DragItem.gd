extends Panel
## Draggable inventory item — _get_drag_data provides item info for drop targets

var item_id: String = ""
var drag_icon: Texture2D = null
var item_name: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _get_drag_data(_at_position: Vector2):
	if item_id.is_empty():
		return null
	var preview := TextureRect.new()
	if drag_icon != null:
		preview.texture = drag_icon
		preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(56, 56)
	preview.z_index = 100
	set_drag_preview(preview)
	return {"item_id": item_id, "item_name": item_name}


func clear_drag_data() -> void:
	item_id = ""
	drag_icon = null
	item_name = ""
	mouse_filter = Control.MOUSE_FILTER_IGNORE
