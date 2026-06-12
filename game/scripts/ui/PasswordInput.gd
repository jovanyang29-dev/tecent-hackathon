extends PanelContainer

signal password_submitted(password: String)
signal cancelled()

var _error_label: Label
var _line_edit: LineEdit


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_ui()
	hide()


func _setup_ui() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.15, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(1, 0.85, 0.4, 0.6)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	var title := Label.new()
	title.text = "请输入密码"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4, 1))
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "（提示：台历上的日期）"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint)

	_line_edit = LineEdit.new()
	_line_edit.secret = true
	_line_edit.secret_character = "*"
	_line_edit.max_length = 4
	_line_edit.placeholder_text = "四位数字密码"
	_line_edit.add_theme_color_override("font_color", Color(1, 1, 1))
	_line_edit.add_theme_font_size_override("font_size", 24)
	_line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line_edit.custom_minimum_size = Vector2(200, 40)
	vbox.add_child(_line_edit)

	_error_label = Label.new()
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	_error_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_error_label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	var confirm_btn := Button.new()
	confirm_btn.text = "确认"
	confirm_btn.pressed.connect(_on_confirm)
	hbox.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.pressed.connect(_on_cancel)
	hbox.add_child(cancel_btn)

	_line_edit.text_submitted.connect(_on_text_submitted)


func show_input() -> void:
	_line_edit.text = ""
	_error_label.text = ""
	_line_edit.grab_focus()
	show()


func show_error(text: String) -> void:
	_error_label.text = text
	_line_edit.text = ""
	_line_edit.grab_focus()


func _on_confirm() -> void:
	var text := _line_edit.text.strip_edges()
	if text.length() == 0:
		return
	password_submitted.emit(text)


func _on_cancel() -> void:
	hide()
	cancelled.emit()


func _on_text_submitted(_text: String) -> void:
	_on_confirm()
