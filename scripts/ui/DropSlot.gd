extends Panel
## Draggable item receiver for grandma's submission grid

var expected_item_id: String = ""
var submitted := false
var _panel_ref: Node = null  # reference to GrandmaSubmissionPanel for refresh

func setup(item_id: String, panel_ref: Node) -> void:
	expected_item_id = item_id
	_panel_ref = panel_ref
	mouse_filter = Control.MOUSE_FILTER_STOP


func reset() -> void:
	submitted = false


func _can_drop_data(_at_position: Vector2, data) -> bool:
	if submitted:
		return false
	if not data is Dictionary:
		return false
	return data.get("item_id", "") == expected_item_id


func _drop_data(_at_position: Vector2, data) -> void:
	var item_id: String = data.get("item_id", "")
	if item_id != expected_item_id or submitted:
		return
	if not GameState.has_item(item_id):
		return
	submitted = true
	AudioManager.play_interact()
	if _panel_ref != null and _panel_ref.has_method("_on_item_submitted"):
		_panel_ref._on_item_submitted(item_id)
