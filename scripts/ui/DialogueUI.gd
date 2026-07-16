extends CanvasLayer

## Dialogue text box overlay — built entirely in code

var panel: Panel
var name_label: Label
var text_label: Label
var continue_hint: Label
var _choice_container: VBoxContainer
var _choice_buttons: Array[Button] = []
var _dialogue_start_frame: int = -1

# CG 插画展示（双 TextureRect 交叉淡入淡出）
var _cg_container: Control
var _cg_image_a: TextureRect  # 前层
var _cg_image_b: TextureRect  # 后层（用于交叉淡入）
var _cg_overlay: ColorRect
var _cg_active: int = 0       # 0 = A 在前, 1 = B 在前
var _current_cg_path: String = ""
var _cg_tween: Tween = null
const CG_FADE_DURATION := 1.0   # 渐入/渐出时长（秒）
const CG_PRELOAD: Dictionary = {
	"cg_summer_day": preload("res://assets/images/cg/cg_summer_day.png"),
	"cg_grandma_kitchen": preload("res://assets/images/cg/cg_grandma_kitchen.png"),
	"cg_phone_rings": preload("res://assets/images/cg/cg_phone_rings.png"),
	"cg_river_fishing": preload("res://assets/images/cg/cg_river_fishing.png"),
	"cg_running_out": preload("res://assets/images/cg/cg_running_out.png"),
	"cg_empty_house": preload("res://assets/images/cg/cg_empty_house.png"),
	"cg_family_photo": preload("res://assets/images/cg/cg_family_photo.png"),
	"cg_summer_day_pixel": preload("res://assets/images/cg/cg_summer_day_pixel.png"),
	"cg_grandma_kitchen_pixel": preload("res://assets/images/cg/cg_grandma_kitchen_pixel.png"),
	"cg_phone_rings_pixel": preload("res://assets/images/cg/cg_phone_rings_pixel.png"),
	"cg_river_fishing_pixel": preload("res://assets/images/cg/cg_river_fishing_pixel.png"),
	"cg_running_out_pixel": preload("res://assets/images/cg/cg_running_out_pixel.png"),
	"cg_empty_house_pixel": preload("res://assets/images/cg/cg_empty_house_pixel.png"),
	"cg_family_photo_pixel": preload("res://assets/images/cg/cg_family_photo_pixel.png"),
}


func _ready() -> void:
	_create_ui()
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	DialogueManager.choice_presented.connect(_on_choice_presented)
	panel.hide()


func _create_ui() -> void:
	# 半透明背景遮罩（CG 显示时的暗色背景）
	_cg_container = Control.new()
	_cg_container.name = "CGContainer"
	_cg_container.anchor_left = 0.0
	_cg_container.anchor_right = 1.0
	_cg_container.anchor_top = 0.0
	_cg_container.anchor_bottom = 1.0
	_cg_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cg_container.hide()
	add_child(_cg_container)

	_cg_overlay = ColorRect.new()
	_cg_overlay.name = "CGOverlay"
	_cg_overlay.anchor_left = 0.0
	_cg_overlay.anchor_right = 1.0
	_cg_overlay.anchor_top = 0.0
	_cg_overlay.anchor_bottom = 1.0
	_cg_overlay.color = Color(0, 0, 0, 0.55)
	_cg_container.add_child(_cg_overlay)

	# 后层（用于交叉淡入时承载新图）
	_cg_image_b = TextureRect.new()
	_cg_image_b.name = "CGImageB"
	_cg_image_b.anchor_left = 0.03
	_cg_image_b.anchor_right = 0.97
	_cg_image_b.anchor_top = 0.04
	_cg_image_b.anchor_bottom = 0.82
	_cg_image_b.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_cg_image_b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cg_image_b.modulate.a = 0.0
	_cg_container.add_child(_cg_image_b)

	# 前层（当前显示的图）
	_cg_image_a = TextureRect.new()
	_cg_image_a.name = "CGImageA"
	_cg_image_a.anchor_left = 0.03
	_cg_image_a.anchor_right = 0.97
	_cg_image_a.anchor_top = 0.04
	_cg_image_a.anchor_bottom = 0.82
	_cg_image_a.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_cg_image_a.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cg_image_a.modulate.a = 0.0
	_cg_container.add_child(_cg_image_a)

	panel = Panel.new()
	panel.name = "Panel"
	panel.anchor_left = 0.05
	panel.anchor_right = 0.95
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -110.0
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
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
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

	# 选择面板
	_choice_container = VBoxContainer.new()
	_choice_container.name = "ChoiceContainer"
	_choice_container.anchor_left = 0.05
	_choice_container.anchor_right = 0.95
	_choice_container.anchor_top = 1.0
	_choice_container.anchor_bottom = 1.0
	_choice_container.offset_top = -140.0
	_choice_container.offset_bottom = -20.0
	_choice_container.add_theme_constant_override("separation", 8)
	add_child(_choice_container)
	_choice_container.hide()


func _on_dialogue_started(_id: String) -> void:
	_choice_container.hide()
	panel.show()
	_dialogue_start_frame = Engine.get_process_frames()
	_advance_and_show()


func _on_dialogue_finished(_id: String) -> void:
	panel.hide()
	_choice_container.hide()
	_hide_cg()


func _show_cg(cg_key: String) -> void:
	if cg_key == _current_cg_path:
		return
	_kill_cg_tween()
	var tex = CG_PRELOAD.get(cg_key)
	if tex == null:
		# 兜底：运行时从文件加载（适用于未预加载的新图片）
		var file_path := "res://assets/images/cg/" + cg_key + ".png"
		if ResourceLoader.exists(file_path):
			tex = load(file_path)
		else:
			_hide_cg()
			return

	if _current_cg_path != "" and _cg_container.visible:
		# 已有 CG 在显示 → 交叉淡入淡出（旧图淡出 + 新图淡入同时进行）
		# 将新图放在当前未使用的层上
		var old_layer: TextureRect = _cg_image_a if _cg_active == 0 else _cg_image_b
		var new_layer: TextureRect = _cg_image_b if _cg_active == 0 else _cg_image_a
		new_layer.texture = tex
		new_layer.modulate.a = 0.0
		_current_cg_path = cg_key
		_cg_active = 1 - _cg_active  # 切换活跃层

		_cg_tween = create_tween()
		_cg_tween.set_parallel(true)
		_cg_tween.set_ease(Tween.EASE_IN_OUT)
		_cg_tween.set_trans(Tween.TRANS_CUBIC)
		_cg_tween.tween_property(old_layer, "modulate:a", 0.0, CG_FADE_DURATION)
		_cg_tween.tween_property(new_layer, "modulate:a", 1.0, CG_FADE_DURATION)
	else:
		# 首次出现 → 直接淡入到前层
		_current_cg_path = cg_key
		_cg_active = 0
		_cg_image_a.texture = tex
		_cg_image_a.modulate.a = 0.0
		_cg_image_b.modulate.a = 0.0
		_cg_container.show()
		_cg_tween = create_tween()
		_cg_tween.set_ease(Tween.EASE_OUT)
		_cg_tween.set_trans(Tween.TRANS_CUBIC)
		_cg_tween.tween_property(_cg_image_a, "modulate:a", 1.0, CG_FADE_DURATION)


func _hide_cg() -> void:
	if not _cg_container.visible:
		_current_cg_path = ""
		return
	_kill_cg_tween()
	_cg_tween = create_tween()
	_cg_tween.set_ease(Tween.EASE_IN)
	_cg_tween.set_trans(Tween.TRANS_CUBIC)
	# 同时淡出两个层
	_cg_tween.set_parallel(true)
	_cg_tween.tween_property(_cg_image_a, "modulate:a", 0.0, CG_FADE_DURATION)
	_cg_tween.tween_property(_cg_image_b, "modulate:a", 0.0, CG_FADE_DURATION)
	_cg_tween.tween_callback(func():
		_current_cg_path = ""
		_cg_container.hide()
	)


func _kill_cg_tween() -> void:
	if _cg_tween != null and _cg_tween.is_valid():
		_cg_tween.kill()
	_cg_tween = null


func _on_choice_presented(options: Array, prompt: String) -> void:
	panel.hide()
	_show_choices(options, prompt)


func _show_choices(options: Array, prompt: String) -> void:
	# 清除旧选项
	for b in _choice_buttons:
		b.queue_free()
	_choice_buttons.clear()

	# 提示文字
	if prompt != "":
		var prompt_label := Label.new()
		prompt_label.text = prompt
		prompt_label.add_theme_font_size_override("font_size", 14)
		prompt_label.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
		prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_choice_container.add_child(prompt_label)

	# 选项按钮
	for i in range(options.size()):
		var opt: Dictionary = options[i]
		var btn := Button.new()
		btn.text = "  ▶  " + String(opt.get("text", "选项" + str(i + 1)))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
		btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		btn.add_theme_stylebox_override("normal", _make_btn_style(Color(0.15, 0.1, 0.05)))
		btn.add_theme_stylebox_override("hover", _make_btn_style(Color(0.3, 0.2, 0.1)))
		btn.custom_minimum_size = Vector2(0, 40)
		var idx := i
		btn.pressed.connect(func(): _on_choice_selected(idx))
		_choice_container.add_child(btn)
		_choice_buttons.append(btn)

	_choice_container.show()


func _on_choice_selected(index: int) -> void:
	_choice_container.hide()
	DialogueManager.select_choice(index)
	# 选择的后续对话会自动启动，DialogueUI 会收到 dialogue_started 信号


func _make_btn_style(bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_color = Color(0.5, 0.4, 0.2)
	style.corner_radius_top_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_top = 6
	return style


func _input(event: InputEvent) -> void:
	if _choice_container.visible:
		# 选择模式下，允许用数字键选择
		if event is InputEventKey and event.pressed:
			var key: int = int(event.keycode)
			if key >= int(KEY_1) and key <= int(KEY_9):
				var idx: int = key - int(KEY_1)
				if idx < _choice_buttons.size():
					get_viewport().set_input_as_handled()
					_on_choice_selected(idx)
		return

	if not panel.visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		# 阻止同帧内 dialogue_started 触发后再被 _input 消耗第一行对话
		if Engine.get_process_frames() == _dialogue_start_frame:
			return
		_advance_and_show()


## 获取下一行对话并显示。统一入口，避免多处调用 next_line() 导致行被跳过。
func _advance_and_show() -> void:
	var line := DialogueManager.next_line()
	if line.is_empty():
		return

	# CG 插画切换
	var cg_key: String = String(line.get("image", ""))
	if cg_key != "":
		_show_cg(cg_key)
	# 如果该行显式设置为 "" 则隐藏 CG
	elif line.has("image") and String(line.get("image", "")) == "":
		_hide_cg()

	name_label.text = String(line.get("speaker", ""))
	text_label.text = _normalize_text(String(line.get("text", "")))
	continue_hint.visible = true


## 规范化对话文本，移除多余的换行符
func _normalize_text(raw: String) -> String:
	# 移除 Windows 风格的回车符 \r，避免与 \n 叠加产生多余空行
	return raw.replace("\r", "")
