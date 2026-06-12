extends Node3D

const START_ROOM := "res://scenes/rooms/Room2008.tscn"

@onready var dialog_box: PanelContainer = $CanvasLayer/DialogBox

var _transition_in_progress := false
var _pending_password_interaction: Dictionary = {}
var _correct_password := ""
var password_input: PanelContainer
var held_item_display: PanelContainer
var _held_item_data: Dictionary = {}
var _hover_hint: Label


func _ready() -> void:
	set_process_input(true)
	_setup_ui()
	RoomManager.load_room(START_ROOM)
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	RoomManager.room_changed.connect(_on_room_changed)
	InteractionManager.password_requested.connect(_on_password_requested)


func _setup_ui() -> void:
	password_input = load("res://scripts/ui/PasswordInput.gd").new()
	password_input.position = Vector2(440, 260)
	password_input.custom_minimum_size = Vector2(400, 220)
	$CanvasLayer.add_child(password_input)
	password_input.password_submitted.connect(_on_password_submitted)
	password_input.cancelled.connect(_on_password_cancelled)

	held_item_display = load("res://scripts/ui/HeldItemDisplay.gd").new()
	held_item_display.position = Vector2(390, 570)
	held_item_display.custom_minimum_size = Vector2(500, 70)
	$CanvasLayer.add_child(held_item_display)
	held_item_display.item_button_pressed.connect(_on_held_item_button)
	held_item_display.item_dropped.connect(_on_held_item_drop)

	_hover_hint = Label.new()
	_hover_hint.text = "按 F 拾取"
	_hover_hint.add_theme_color_override("font_color", Color(1, 0.85, 0.4, 0.9))
	_hover_hint.add_theme_font_size_override("font_size", 16)
	_hover_hint.hide()
	$CanvasLayer.add_child(_hover_hint)


func _input(event: InputEvent) -> void:
	if password_input.visible:
		return

	# F key for pickup/drop
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		_on_f_key()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_mouse_press(event.position)
		# No drag release needed

	elif event is InputEventMouseMotion:
		_on_mouse_motion(event.position)


func _get_camera() -> Camera3D:
	var room = RoomManager.current_room
	if room != null and room.has_method("get_camera"):
		return room.get_camera()
	return null


func _raycast(pos: Vector2, collision_mask: int) -> Dictionary:
	var camera := _get_camera()
	if camera == null:
		return {}

	var from := camera.project_ray_origin(pos)
	var to := from + camera.project_ray_normal(pos) * 50
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	return space_state.intersect_ray(query)


func _on_mouse_motion(pos: Vector2) -> void:
	if not _held_item_data.is_empty():
		_hover_hint.hide()
		return

	var room = RoomManager.current_room
	if room == null or not room.has_method("get_hovered_item"):
		return

	var item = room.get_hovered_item(pos)
	if item != null:
		room.highlight_item(item)
		_hover_hint.text = "按 F 拾取"
		_hover_hint.position = pos + Vector2(15, -25)
		_hover_hint.show()
	else:
		room.clear_highlight()
		_hover_hint.hide()


func _on_f_key() -> void:
	var room = RoomManager.current_room
	if room == null:
		return

	# Drop held item
	if not _held_item_data.is_empty():
		room.drop_item(_held_item_data)
		_held_item_data = {}
		held_item_display.hide_item()
		return

	# Pick up hovered item
	if room.has_method("get_hovered_item"):
		var mouse_pos := get_viewport().get_mouse_position()
		var item = room.get_hovered_item(mouse_pos)
		if item != null:
			_held_item_data = room.pickup_item(item)
			var item_id: String = _held_item_data.get("item_id", "")
			var item_color: Color = _held_item_data.get("item_color", Color.WHITE)
			var btn_action: Dictionary = _held_item_data.get("button_action", {})
			held_item_display.show_item(item_id, item_color, btn_action)
			_hover_hint.hide()


func _on_mouse_press(pos: Vector2) -> void:
	var room = RoomManager.current_room
	if room == null:
		return

	if DialogueManager.active_lines.size() > 0:
		advance_dialogue()
		return

	# If holding an item, try to use it on a hotspot
	if not _held_item_data.is_empty():
		_try_use_held_item(pos)
		return

	# Normal hotspot interaction
	var result := _raycast(pos, 1)
	if not result.is_empty():
		var collider: Node3D = result.collider
		if room.has_method("try_interact"):
			room.try_interact(collider)


func _try_use_held_item(pos: Vector2) -> void:
	var room = RoomManager.current_room
	if room == null:
		return

	var result := _raycast(pos, 1)
	if result.is_empty():
		return

	var collider: Node3D = result.collider
	var node := collider
	while node != null:
		if node.has_meta("interaction"):
			var interaction: Dictionary = node.get_meta("interaction")
			var requires: String = String(interaction.get("requires_item", ""))
			var held_id: String = _held_item_data.get("item_id", "")
			if requires == held_id:
				GameState.add_item(held_id)
				held_item_display.hide_item()
				_held_item_data = {}
				InteractionManager.handle_interaction(interaction)
			return
		node = node.get_parent()


func _on_held_item_button(button_action: Dictionary) -> void:
	InteractionManager.handle_interaction(button_action)
	held_item_display.hide_item()
	_held_item_data = {}


func _on_held_item_drop() -> void:
	if _held_item_data.is_empty():
		return
	var room = RoomManager.current_room
	if room != null and room.has_method("drop_item"):
		room.drop_item(_held_item_data)
	_held_item_data = {}
	held_item_display.hide_item()


func _on_password_requested(correct_password: String, interaction: Dictionary) -> void:
	_pending_password_interaction = interaction
	_correct_password = correct_password
	password_input.show_input()


func _on_password_submitted(password: String) -> void:
	if password == _correct_password:
		password_input.hide()
		var interaction := _pending_password_interaction
		_pending_password_interaction = {}
		InteractionManager.handle_interaction(interaction, true)
	else:
		password_input.show_error("密码错误，请重试")


func _on_password_cancelled() -> void:
	_pending_password_interaction = {}
	_correct_password = ""


func advance_dialogue() -> void:
	var line := DialogueManager.next_line()
	if line.is_empty():
		return
	if line.has("text"):
		_show_line(line)


func _show_line(line: Dictionary) -> void:
	var speaker := String(line.get("speaker", ""))
	var text := String(line.get("text", ""))
	dialog_box.show_line(speaker, text)


func _on_dialogue_started(_dialogue_id: String) -> void:
	if DialogueManager.active_lines.size() > 0:
		var line: Dictionary = DialogueManager.active_lines[0]
		var speaker := String(line.get("speaker", ""))
		var text := String(line.get("text", ""))
		dialog_box.show_line(speaker, text)
		DialogueManager.active_index = 1


func _on_dialogue_finished(_dialogue_id: String) -> void:
	dialog_box.hide_dialogue()
	_check_room_transition()


func _check_room_transition() -> void:
	if _transition_in_progress:
		return
	match GameState.current_room_id:
		"room_2008":
			if GameState.has_flag("played_family_video"):
				_transition_in_progress = true
				RoomManager.load_room("res://scenes/rooms/Room2012.tscn")
		"room_2012":
			if GameState.has_flag("finished_room2"):
				_transition_in_progress = true
				RoomManager.load_room("res://scenes/rooms/Room2015.tscn")


func _on_room_changed(_room_path: String) -> void:
	_transition_in_progress = false
	# Clear held item on room change
	if not _held_item_data.is_empty():
		_held_item_data = {}
		held_item_display.hide_item()
