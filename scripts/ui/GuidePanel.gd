extends CanvasLayer
## 游戏指南面板 —— 显示基本操作说明

var _panel_root: Control = null
var _overlay: ColorRect = null
var _is_open := false

func _ready() -> void:
	layer = 14
	_build_panel()
	_panel_root.visible = false
	_overlay.visible = false


func is_open() -> bool:
	return _is_open


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	_is_open = true
	_overlay.visible = true
	_panel_root.visible = true
	var player := get_tree().get_first_node_in_group("player") as Node
	if player != null and player.has_method("lock_movement"):
		player.lock_movement()


func close() -> void:
	_is_open = false
	_overlay.visible = false
	_panel_root.visible = false
	if DialogueManager.active_dialogue_id == "":
		var player := get_tree().get_first_node_in_group("player") as Node
		if player != null and player.has_method("unlock_movement"):
			player.unlock_movement()


func _build_panel() -> void:
	# 半透明遮罩
	_overlay = ColorRect.new()
	_overlay.name = "GuideOverlay"
	_overlay.color = Color(0, 0, 0, 0.5)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close()
	)
	add_child(_overlay)

	# 主面板
	_panel_root = Panel.new()
	_panel_root.name = "GuidePanelRoot"
	_panel_root.custom_minimum_size = Vector2(420, 460)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.97)
	style.border_color = Color(0.6, 0.55, 0.35, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	_panel_root.add_theme_stylebox_override("panel", style)

	_panel_root.set_anchors_preset(Control.PRESET_CENTER)
	_panel_root.offset_left = -210
	_panel_root.offset_right = 210
	_panel_root.offset_top = -230
	_panel_root.offset_bottom = 230
	add_child(_panel_root)

	# 标题
	var title := Label.new()
	title.text = "游戏指南"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 14
	title.offset_bottom = 48
	_panel_root.add_child(title)

	# 关闭按钮
	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.add_theme_color_override("font_color", Color(0.9, 0.6, 0.5))
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0, 0, 0, 0)
	close_btn.add_theme_stylebox_override("normal", btn_style)
	close_btn.add_theme_stylebox_override("hover", btn_style)
	close_btn.add_theme_stylebox_override("pressed", btn_style)
	close_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = -36
	close_btn.offset_right = -4
	close_btn.offset_top = 4
	close_btn.offset_bottom = 36
	close_btn.pressed.connect(close)
	_panel_root.add_child(close_btn)

	# 内容 VBox
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	content.offset_top = 56
	content.offset_left = 32
	content.offset_right = -32
	content.add_theme_constant_override("separation", 24)
	_panel_root.add_child(content)

	# ── WASD 移动 ──
	content.add_child(_make_section("移  动", _make_wasd_row()))

	# ── E 交互 ──
	content.add_child(_make_section("交  互", _make_key_row("E", "与物品 / 人物互动")))

	# ── B 背包 ──
	content.add_child(_make_section("背  包", _make_key_row("B", "打开 / 关闭背包")))


func _make_section(label_text: String, row: Control) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7))
	vbox.add_child(lbl)

	vbox.add_child(row)
	return vbox


func _make_key_row(key: String, desc: String) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)

	var key_box := _key_box(key)
	hbox.add_child(key_box)

	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.add_theme_font_size_override("font_size", 15)
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(desc_label)

	return hbox


func _make_wasd_row() -> Control:
	# WASD 十字排列在一个 Control 里
	var ctrl := Control.new()
	ctrl.custom_minimum_size = Vector2(0, 104)

	# W
	_add_key_to(ctrl, "W", 52, 0)
	# A
	_add_key_to(ctrl, "A", 0, 52)
	# S
	_add_key_to(ctrl, "S", 52, 52)
	# D
	_add_key_to(ctrl, "D", 104, 52)

	return ctrl


func _add_key_to(parent: Control, letter: String, x: float, y: float) -> void:
	var kb := _key_box(letter)
	kb.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	kb.offset_left = x
	kb.offset_top = y
	kb.offset_right = x + 44
	kb.offset_bottom = y + 44
	parent.add_child(kb)


func _key_box(letter: String) -> Panel:
	var key_bg := Panel.new()
	key_bg.custom_minimum_size = Vector2(44, 44)

	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color(0.15, 0.13, 0.1, 1.0)
	key_style.border_color = Color(0.55, 0.5, 0.35, 1.0)
	key_style.set_border_width_all(2)
	key_style.corner_radius_top_left = 6
	key_style.corner_radius_top_right = 6
	key_style.corner_radius_bottom_left = 6
	key_style.corner_radius_bottom_right = 6
	key_bg.add_theme_stylebox_override("panel", key_style)

	var key_label := Label.new()
	key_label.text = letter
	key_label.add_theme_font_size_override("font_size", 18)
	key_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	key_bg.add_child(key_label)

	return key_bg
