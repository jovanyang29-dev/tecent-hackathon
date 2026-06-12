extends CanvasLayer
## 主菜单界面 — 新游戏 / 继续游戏 / 退出游戏

const SAVE_PATH := "user://save.json"

@onready var _new_btn: Button = $Control/Panel/VBox/NewGameBtn
@onready var _continue_btn: Button = $Control/Panel/VBox/ContinueBtn
@onready var _exit_btn: Button = $Control/Panel/VBox/ExitBtn


func _ready() -> void:
	_build_ui()
	AudioManager.stop_bgm()

	var has_save := FileAccess.file_exists(SAVE_PATH)
	_continue_btn.disabled = not has_save
	_continue_btn.text = "继续游戏" if has_save else "（无存档）"

	_new_btn.grab_focus()
	_play_enter_animation()


# ═══════════════════════════════════════════════════════
# UI 构建
# ═══════════════════════════════════════════════════════

func _build_ui() -> void:
	# ── 根 Control（全屏） ──
	var ctrl := Control.new()
	ctrl.name = "Control"
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ctrl)

	# ── 半透明背景色块 ──
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.06, 1.0)
	ctrl.add_child(bg)

	# ── 中心面板 ──
	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = Vector2(480, 420)
	panel.position = Vector2(-240, -210)

	# 面板样式
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.15, 0.92)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.35, 0.35, 0.55, 0.6)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", style)
	ctrl.add_child(panel)

	# ── VBox 容器 ──
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# 上边距
	var spacer_top := Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(spacer_top)

	# ── 标题 ──
	var title := Label.new()
	title.name = "Title"
	title.text = "箱  庭"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.9, 0.82, 0.55, 1.0))
	vbox.add_child(title)

	# ── 副标题 ──
	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "— 记忆的庭院 —"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65, 0.8))
	vbox.add_child(subtitle)

	# ── 间距 ──
	var spacer_mid := Control.new()
	spacer_mid.custom_minimum_size = Vector2(0, 36)
	vbox.add_child(spacer_mid)

	# ── 三个按钮 ──
	_new_btn = _create_button("NewGameBtn", "新 游 戏")
	vbox.add_child(_new_btn)

	_continue_btn = _create_button("ContinueBtn", "继续游戏")
	vbox.add_child(_continue_btn)

	_exit_btn = _create_button("ExitBtn", "退出游戏")
	vbox.add_child(_exit_btn)

	# 底部间距
	var spacer_bottom := Control.new()
	spacer_bottom.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(spacer_bottom)

	# 按钮居中容器
	_new_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_exit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# 信号连接
	_new_btn.pressed.connect(_on_new_game)
	_continue_btn.pressed.connect(_on_continue)
	_exit_btn.pressed.connect(_on_exit)

	# ── 底部版本号 ──
	var version_label := Label.new()
	version_label.name = "VersionLabel"
	version_label.text = "v0.1.0"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_font_size_override("font_size", 12)
	version_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4, 0.6))
	version_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	version_label.position = Vector2(0, -24)
	ctrl.add_child(version_label)


func _create_button(p_name: String, p_text: String) -> Button:
	var btn := Button.new()
	btn.name = p_name
	btn.text = p_text
	btn.custom_minimum_size = Vector2(260, 52)
	btn.add_theme_font_size_override("font_size", 20)

	# 普通样式
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.15, 0.25, 0.9)
	normal_style.border_width_left = 1
	normal_style.border_width_right = 1
	normal_style.border_width_top = 1
	normal_style.border_width_bottom = 1
	normal_style.border_color = Color(0.4, 0.4, 0.55, 0.5)
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", normal_style)

	# 悬停样式
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.25, 0.25, 0.4, 1.0)
	hover_style.border_width_left = 1
	hover_style.border_width_right = 1
	hover_style.border_width_top = 1
	hover_style.border_width_bottom = 1
	hover_style.border_color = Color(0.7, 0.65, 0.4, 0.7)
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	hover_style.corner_radius_bottom_left = 8
	hover_style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("hover", hover_style)

	# 按下样式
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.35, 0.35, 0.5, 1.0)
	pressed_style.border_width_left = 1
	pressed_style.border_width_right = 1
	pressed_style.border_width_top = 1
	pressed_style.border_width_bottom = 1
	pressed_style.border_color = Color(0.9, 0.82, 0.55, 0.8)
	pressed_style.corner_radius_top_left = 8
	pressed_style.corner_radius_top_right = 8
	pressed_style.corner_radius_bottom_left = 8
	pressed_style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("pressed", pressed_style)

	# 焦点样式（键盘导航）
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(0.25, 0.25, 0.4, 1.0)
	focus_style.border_width_left = 2
	focus_style.border_width_right = 2
	focus_style.border_width_top = 2
	focus_style.border_width_bottom = 2
	focus_style.border_color = Color(0.9, 0.82, 0.55, 0.9)
	focus_style.corner_radius_top_left = 8
	focus_style.corner_radius_top_right = 8
	focus_style.corner_radius_bottom_left = 8
	focus_style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("focus", focus_style)

	# 禁用样式
	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.08, 0.08, 0.12, 0.6)
	disabled_style.border_width_left = 1
	disabled_style.border_width_right = 1
	disabled_style.border_width_top = 1
	disabled_style.border_width_bottom = 1
	disabled_style.border_color = Color(0.2, 0.2, 0.3, 0.3)
	disabled_style.corner_radius_top_left = 8
	disabled_style.corner_radius_top_right = 8
	disabled_style.corner_radius_bottom_left = 8
	disabled_style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("disabled", disabled_style)

	btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.95, 0.88, 0.6, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.65, 1.0))
	btn.add_theme_color_override("font_focus_color", Color(0.95, 0.88, 0.6, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.35, 0.4, 0.5))

	# 鼠标悬停音效
	btn.mouse_entered.connect(func():
		_create_hover_tween(btn)
	)

	return btn


# ═══════════════════════════════════════════════════════
# 动画
# ═══════════════════════════════════════════════════════

func _play_enter_animation() -> void:
	var panel := $Control/Panel
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)

	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.6).set_ease(Tween.EASE_OUT)

	# 按钮逐个淡入
	var btns: Array[Button] = [_new_btn, _continue_btn, _exit_btn]
	for i in btns.size():
		var b := btns[i]
		b.modulate.a = 0.0
		var dt := get_tree().create_tween()
		dt.tween_interval(0.35 + i * 0.1)
		dt.tween_property(b, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)


func _create_hover_tween(btn: Button) -> void:
	var t := get_tree().create_tween()
	t.set_parallel(true)
	t.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.12).set_ease(Tween.EASE_OUT)

	btn.mouse_exited.connect(func():
		var te := get_tree().create_tween()
		te.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
	, CONNECT_ONE_SHOT)


# ═══════════════════════════════════════════════════════
# 按钮回调
# ═══════════════════════════════════════════════════════

func _on_new_game() -> void:
	# 删除旧存档，重置所有状态
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

	GameState.current_room_id = "room_2008"
	GameState.flags.clear()
	GameState.inventory.clear()

	_transition_to("res://scenes/Main.tscn")


func _on_continue() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	SaveManager.load_game()
	GameState.set_flag("_skip_intro", true)

	_transition_to("res://scenes/Main.tscn")


func _on_exit() -> void:
	# 淡出 + 退出
	var fade := ColorRect.new()
	fade.name = "FadeOut"
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	add_child(fade)

	var tween := get_tree().create_tween()
	tween.tween_property(fade, "color", Color(0, 0, 0, 1), 0.5)
	tween.tween_callback(func(): get_tree().quit())


func _transition_to(scene_path: String) -> void:
	var fade := ColorRect.new()
	fade.name = "TransitionFade"
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	add_child(fade)

	var tween := get_tree().create_tween()
	tween.tween_property(fade, "color", Color(0, 0, 0, 1), 0.4)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(scene_path)
	)
