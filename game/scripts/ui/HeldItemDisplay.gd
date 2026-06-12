extends PanelContainer

signal item_button_pressed(button_action: Dictionary)
signal item_dropped()

var _item_label: Label
var _power_btn: Button
var _drop_btn: Button
var _color_rect: ColorRect
var _button_action: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.12, 0.9)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(1, 0.85, 0.4, 0.5)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	add_theme_stylebox_override("panel", panel_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hbox)

	# Item visual (colored rectangle)
	_color_rect = ColorRect.new()
	_color_rect.custom_minimum_size = Vector2(80, 40)
	hbox.add_child(_color_rect)

	# Item name
	_item_label = Label.new()
	_item_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_item_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(_item_label)

	# Power button (only for button items like remote)
	_power_btn = Button.new()
	_power_btn.text = "开机"
	_power_btn.custom_minimum_size = Vector2(60, 35)
	_power_btn.add_theme_color_override("font_color", Color(0.2, 1, 0.3))
	_power_btn.pressed.connect(_on_power_pressed)
	_power_btn.hide()
	hbox.add_child(_power_btn)

	# Drop button
	_drop_btn = Button.new()
	_drop_btn.text = "放下"
	_drop_btn.custom_minimum_size = Vector2(50, 35)
	_drop_btn.pressed.connect(_on_drop_pressed)
	hbox.add_child(_drop_btn)

	# Hint label
	var hint := Label.new()
	hint.text = "[F] 拾取 / 放下"
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.add_theme_font_size_override("font_size", 12)
	hint.position = Vector2(10, 10)
	add_child(hint)

	hide()


func show_item(item_id: String, item_color: Color, button_action: Dictionary = {}) -> void:
	_item_label.text = _get_item_name(item_id)
	_color_rect.color = item_color
	_button_action = button_action

	if not button_action.is_empty():
		_power_btn.show()
	else:
		_power_btn.hide()

	show()


func hide_item() -> void:
	hide()
	_button_action = {}


func _get_item_name(item_id: String) -> String:
	match item_id:
		"small_key": return "钥匙"
		"remote_control": return "遥控器"
		"password_note": return "密码纸条"
		"old_phone": return "旧手机"
		"receipt": return "外卖单"
	return item_id


func _on_power_pressed() -> void:
	if not _button_action.is_empty():
		item_button_pressed.emit(_button_action)


func _on_drop_pressed() -> void:
	item_dropped.emit()
