extends CanvasLayer

## 密码输入界面 — 与对话 UI 风格一致的密码弹窗

var panel: Panel
var _bg: ColorRect
var title_label: Label
var password_display: Label
var hint_label: Label
var _entered_password: String = ""


func _ready() -> void:
	_create_ui()
	InteractionManager.password_requested.connect(_on_password_requested)
	panel.hide()


func _create_ui() -> void:
	# 半透明遮罩背景（点击取消）
	_bg = ColorRect.new()
	_bg.name = "BG"
	_bg.color = Color(0, 0, 0, 0.6)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_bg.gui_input.connect(_on_bg_input)
	_bg.hide()
	add_child(_bg)

	# 中央面板
	panel = Panel.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -180.0
	panel.offset_right = 180.0
	panel.offset_top = -120.0
	panel.offset_bottom = 120.0
	panel.self_modulate = Color(0.08, 0.08, 0.1, 0.95)
	add_child(panel)

	# 标题
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "🔒 需要密码"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.anchor_left = 0.0
	title_label.anchor_right = 1.0
	title_label.offset_top = 20.0
	title_label.offset_bottom = 44.0
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	panel.add_child(title_label)

	# 密码显示区域（4 位）
	password_display = Label.new()
	password_display.name = "PasswordDisplay"
	password_display.text = "____"
	password_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	password_display.anchor_left = 0.0
	password_display.anchor_right = 1.0
	password_display.offset_top = 60.0
	password_display.offset_bottom = 100.0
	password_display.add_theme_font_size_override("font_size", 32)
	password_display.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85))
	panel.add_child(password_display)

	# 提示文字
	hint_label = Label.new()
	hint_label.name = "HintLabel"
	hint_label.text = "输入 4 位数字, 按 Enter 确认\n按 Esc 或点击空白取消"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.anchor_left = 0.0
	hint_label.anchor_right = 1.0
	hint_label.offset_top = 110.0
	hint_label.offset_bottom = 160.0
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	panel.add_child(hint_label)


func _on_password_requested(_id: String, _correct: String) -> void:
	_entered_password = ""
	_update_display()
	_bg.show()
	panel.show()
	# 暂停物理处理（冻结玩家移动），但 UI 输入仍可通过 _input 正常响应
	get_tree().paused = true


func _input(event: InputEvent) -> void:
	if not panel.visible:
		return

	# 拦截所有动作按键（防止穿透到 Player 触发交互/移动）
	if event.is_action_pressed("interact") or event.is_action_pressed("attack") \
		or event.is_action_pressed("move_up") or event.is_action_pressed("move_down") \
		or event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("pause"):
		# Esc — 取消
		_cancel()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				if _entered_password.length() == 4:
					_submit()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_cancel()
				get_viewport().set_input_as_handled()
			KEY_BACKSPACE:
				if _entered_password.length() > 0:
					_entered_password = _entered_password.substr(0, _entered_password.length() - 1)
					_update_display()
				get_viewport().set_input_as_handled()
			KEY_0, KEY_KP_0:
				_append_digit("0")
				get_viewport().set_input_as_handled()
			KEY_1, KEY_KP_1:
				_append_digit("1")
				get_viewport().set_input_as_handled()
			KEY_2, KEY_KP_2:
				_append_digit("2")
				get_viewport().set_input_as_handled()
			KEY_3, KEY_KP_3:
				_append_digit("3")
				get_viewport().set_input_as_handled()
			KEY_4, KEY_KP_4:
				_append_digit("4")
				get_viewport().set_input_as_handled()
			KEY_5, KEY_KP_5:
				_append_digit("5")
				get_viewport().set_input_as_handled()
			KEY_6, KEY_KP_6:
				_append_digit("6")
				get_viewport().set_input_as_handled()
			KEY_7, KEY_KP_7:
				_append_digit("7")
				get_viewport().set_input_as_handled()
			KEY_8, KEY_KP_8:
				_append_digit("8")
				get_viewport().set_input_as_handled()
			KEY_9, KEY_KP_9:
				_append_digit("9")
				get_viewport().set_input_as_handled()


func _append_digit(d: String) -> void:
	if _entered_password.length() >= 4:
		return
	_entered_password += d
	_update_display()


func _update_display() -> void:
	var display := ""
	for i in range(4):
		if i < _entered_password.length():
			display += _entered_password[i]
		else:
			display += "_"
	password_display.text = display


func _submit() -> void:
	var pw := _entered_password
	_entered_password = ""
	_bg.hide()
	panel.hide()
	get_tree().paused = false
	InteractionManager.on_password_result(pw)


func _cancel() -> void:
	_entered_password = ""
	_bg.hide()
	panel.hide()
	get_tree().paused = false
	InteractionManager.on_password_result("")  # 空字符串 = 取消


func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_cancel()
