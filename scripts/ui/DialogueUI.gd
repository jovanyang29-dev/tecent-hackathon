extends CanvasLayer

## Dialogue text box overlay — built entirely in code

var panel: Panel
var name_label: Label
var text_label: Label
var continue_hint: Label


func _ready() -> void:
	_create_ui()
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	panel.hide()


func _create_ui() -> void:
	panel = Panel.new()
	panel.name = "Panel"
	panel.anchor_left = 0.05
	panel.anchor_right = 0.95
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -90.0
	panel.offset_bottom = -10.0
	panel.self_modulate = Color(0, 0, 0, 0.85)
	add_child(panel)

	name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.anchor_left = 0.02
	name_label.anchor_right = 0.98
	name_label.offset_top = 4.0
	name_label.offset_bottom = 24.0
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	panel.add_child(name_label)

	text_label = Label.new()
	text_label.name = "TextLabel"
	text_label.anchor_left = 0.02
	text_label.anchor_right = 0.98
	text_label.offset_top = 28.0
	text_label.offset_bottom = 76.0
	text_label.add_theme_font_size_override("font_size", 13)
	text_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85))
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(text_label)

	continue_hint = Label.new()
	continue_hint.name = "ContinueHint"
	continue_hint.anchor_left = 0.8
	continue_hint.anchor_top = 1.0
	continue_hint.anchor_right = 0.98
	continue_hint.offset_top = -20.0
	continue_hint.text = "▼ 点击继续"
	continue_hint.add_theme_font_size_override("font_size", 11)
	continue_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	panel.add_child(continue_hint)


func _on_dialogue_started(_id: String) -> void:
	panel.show()
	_show_current_line()


func _on_dialogue_finished(_id: String) -> void:
	panel.hide()


func _input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		DialogueManager.next_line()
		_show_current_line()


func _show_current_line() -> void:
	var line := DialogueManager.next_line()
	if line.is_empty():
		return

	name_label.text = String(line.get("speaker", ""))
	text_label.text = String(line.get("text", ""))
	continue_hint.visible = true
