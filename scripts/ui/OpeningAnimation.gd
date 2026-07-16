extends CanvasLayer

## 开场动画：模拟睁眼过程 → 显示独白文字 → 等待按键 → 主角出现

signal intro_finished

enum Phase { CLOSED, SQUINT_OPEN, CLOSE_AGAIN, FULLY_OPEN, SHOW_TEXT, WAIT_KEY, DONE }

var _phase := Phase.CLOSED
var _color_rect: ColorRect = null
var _shader_material: ShaderMaterial = null

# ── 对话面板（与 DialogueUI 相同格式）──
var _dialogue_panel: Panel = null
var _name_label: Label = null
var _text_label: Label = null
var _continue_hint: Label = null

var _key_waiting: bool = false


func _ready() -> void:
	layer = 128  # 确保在所有 UI 之上

	# ── 全屏黑色遮罩（带 shader 实现睁眼效果）──
	_color_rect = ColorRect.new()
	_color_rect.name = "EyeOverlay"
	_color_rect.anchor_left = 0.0
	_color_rect.anchor_right = 1.0
	_color_rect.anchor_top = 0.0
	_color_rect.anchor_bottom = 1.0
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_color_rect)

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = Shader.new()
	_shader_material.shader.code = """shader_type canvas_item;
uniform float openness = 0.0;

void fragment() {
	// 纵向：从屏幕中间向上下展开（如眼皮睁开），全屏宽度
	float dy = abs(UV.y - 0.5) * 2.0;
	float mask_y = step(dy, openness);
	COLOR = vec4(0.0, 0.0, 0.0, 1.0 - mask_y);
}
"""
	_shader_material.set_shader_parameter("openness", 0.0)
	_color_rect.material = _shader_material

	# ── 对话面板（与 DialogueUI 相同格式，底部黑色半透明）──
	_create_dialogue_panel()

	# ── 开始动画序列 ──
	_start_phase_closed()


func _create_dialogue_panel() -> void:
	_dialogue_panel = Panel.new()
	_dialogue_panel.name = "DialoguePanel"
	_dialogue_panel.anchor_left = 0.05
	_dialogue_panel.anchor_right = 0.95
	_dialogue_panel.anchor_top = 1.0
	_dialogue_panel.anchor_bottom = 1.0
	_dialogue_panel.offset_top = -90.0
	_dialogue_panel.offset_bottom = -10.0
	_dialogue_panel.self_modulate = Color(0, 0, 0, 0.85)
	_dialogue_panel.visible = false
	add_child(_dialogue_panel)

	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.anchor_left = 0.02
	_name_label.anchor_right = 0.98
	_name_label.offset_top = 4.0
	_name_label.offset_bottom = 24.0
	_name_label.text = "我"
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	_dialogue_panel.add_child(_name_label)

	_text_label = Label.new()
	_text_label.name = "TextLabel"
	_text_label.anchor_left = 0.02
	_text_label.anchor_right = 0.98
	_text_label.offset_top = 28.0
	_text_label.offset_bottom = 76.0
	_text_label.add_theme_font_size_override("font_size", 13)
	_text_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85))
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_dialogue_panel.add_child(_text_label)

	_continue_hint = Label.new()
	_continue_hint.name = "ContinueHint"
	_continue_hint.anchor_left = 0.8
	_continue_hint.anchor_top = 1.0
	_continue_hint.anchor_right = 0.98
	_continue_hint.offset_top = -20.0
	_continue_hint.text = "▶ 按方向键起身"
	_continue_hint.add_theme_font_size_override("font_size", 11)
	_continue_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_dialogue_panel.add_child(_continue_hint)


# ── Phase 1: 全黑 → 睁开一条缝（横条，模拟眯眼）──
func _start_phase_closed() -> void:
	_phase = Phase.CLOSED
	_shader_material.set_shader_parameter("openness", 0.0)
	await get_tree().create_timer(0.6).timeout
	_start_squint_open()


func _start_squint_open() -> void:
	_phase = Phase.SQUINT_OPEN
	var tween := get_tree().create_tween()
	tween.tween_method(
		func(v: float): _shader_material.set_shader_parameter("openness", v),
		0.0,
		0.06,
		0.7
	)
	await tween.finished
	await get_tree().create_timer(0.4).timeout
	_start_close_again()


# ── Phase 2: 再次闭上 ──
func _start_close_again() -> void:
	_phase = Phase.CLOSE_AGAIN
	var tween := get_tree().create_tween()
	tween.tween_method(
		func(v: float): _shader_material.set_shader_parameter("openness", v),
		0.06,
		0.0,
		0.5
	)
	await tween.finished
	await get_tree().create_timer(0.3).timeout
	_start_fully_open()


# ── Phase 3: 上下眼皮从中间展开，完全睁开 ──
func _start_fully_open() -> void:
	_phase = Phase.FULLY_OPEN
	var tween := get_tree().create_tween()
	tween.tween_method(
		func(v: float): _shader_material.set_shader_parameter("openness", v),
		0.0,
		1.0,
		1.0
	).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	await get_tree().create_timer(0.5).timeout
	_start_show_text()


# ── Phase 4: 显示对话面板 + 播放音效 ──
func _start_show_text() -> void:
	_phase = Phase.SHOW_TEXT
	AudioManager.play_interact()
	_dialogue_panel.visible = true
	_dialogue_panel.modulate.a = 0.0
	var tween := get_tree().create_tween()
	tween.tween_property(_dialogue_panel, "modulate:a", 1.0, 0.4)
	await tween.finished
	# 从 dialogue JSON 加载开场文本
	var lines := _load_opening_lines()
	for line_dict in lines:
		# 更新说话人
		_name_label.text = line_dict.get("speaker", "我")
		# 逐字显示文本
		_text_label.text = ""
		var full_text: String = _normalize_text(line_dict.get("text", ""))
		for ch in full_text:
			_text_label.text += ch
			await get_tree().create_timer(0.06).timeout
		await get_tree().create_timer(0.3).timeout
	_start_wait_key()


# ── Phase 5: 等待玩家按移动键 ──
func _start_wait_key() -> void:
	_phase = Phase.WAIT_KEY
	_key_waiting = true


func _process(_delta: float) -> void:
	if not _key_waiting:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() > 0.2:
		_key_waiting = false
		_finish()


# ── 工具函数：从 JSON 加载开场独白 ──
func _load_opening_lines() -> Array:
	const path := "res://data/dialogues/opening_intro.json"
	if not FileAccess.file_exists(path):
		return [{"speaker": "我", "text": "头好疼……我在哪？"}]

	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed.get("lines", [])
	return []


# ── Phase 6: 收尾 → 淡出面板和遮罩，发出完成信号 ──
func _finish() -> void:
	_phase = Phase.DONE
	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(_dialogue_panel, "modulate:a", 0.0, 0.5)
	tween.tween_property(_color_rect, "modulate:a", 0.0, 0.5)
	await tween.finished
	intro_finished.emit()
	queue_free()


## 规范化对话文本，移除多余的换行符
func _normalize_text(raw: String) -> String:
	# 移除 Windows 风格的回车符 \r，避免与 \n 叠加产生多余空行
	return raw.replace("\r", "")
