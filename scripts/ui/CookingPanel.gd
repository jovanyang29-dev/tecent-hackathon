extends CanvasLayer
## 煮饺子小游戏 —— 向下拖拽盘子侧面倾斜，饺子沿斜面滑落，掉入锅中

signal cooking_complete

const PLATE_EDGE: float = 130.0
# 锅口弧线控制点（X偏移, Y深度）—— 修改这些点来手描锅口弧线形状
const RIM_CURVE: PackedVector2Array = [
	Vector2(-55, -20),    # 左
	Vector2(0, -20),       # 中心
	Vector2(60, -20),     # 右
]

var _panel_root: Control = null
var _overlay: ColorRect = null
var _is_open := false

var _plate_pivot: Control = null
var _plate_container: Control = null
var _plate_sprite: TextureRect = null
var _dumplings: Array[TextureRect] = []
var _dumplings_in_pot: Array[TextureRect] = []

var _pot_sprite: TextureRect = null

var _dragging := false
var _drag_start_y := 0.0
var _completed := false
var _pouring := false

var _dumpling_base: Array[Vector2] = []
var _slide_dist: Array[float] = []
var _slide_vel: Array[float] = []

var _hint_label: Label = null
var _pot_front: TextureRect = null


func _ready() -> void:
	layer = 15
	_build_panel()
	_panel_root.visible = false
	_overlay.visible = false


func is_open() -> bool:
	return _is_open


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _completed:
			_finish()
		else:
			close()



func _process(delta: float) -> void:
	if not _is_open or _completed or not _pouring:
		return

	var all_fallen := true
	for i in range(_dumplings.size()):
		var d := _dumplings[i]
		if not is_instance_valid(d) or not d.visible or d.get_parent() != _plate_container:
			continue
		all_fallen = false

		var force: float = sin(0.6) * 600.0
		var vel: float = _slide_vel[i]
		if vel > 0.0:
			force -= 20.0
		elif vel < 0.0:
			force += 20.0

		_slide_vel[i] += force * delta
		_slide_dist[i] += _slide_vel[i] * delta
		_slide_dist[i] = max(_slide_dist[i], 0.0)

		var sd: float = _slide_dist[i]
		_set_dumpling_local_pos(d, _dumpling_base[i], sd)

		if sd >= PLATE_EDGE:
			_drop_dumpling_into_pot(d, i)

	if all_fallen:
		_on_all_dumplings_dropped()


func _set_dumpling_local_pos(d: TextureRect, base: Vector2, slide: float) -> void:
	var x := base.x + slide * 0.6
	var y := base.y + slide
	d.offset_left = x - 28
	d.offset_right = x + 28
	d.offset_top = y - 28
	d.offset_bottom = y + 28


func _drop_dumpling_into_pot(d: TextureRect, _idx: int) -> void:
	var screen_pos := d.global_position + Vector2(28, 28)  # 中心点
	var vp_size := get_viewport().get_visible_rect().size

	# 移到 panel_root 下继续动画
	d.reparent(_panel_root)
	d.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var start_y := screen_pos.y - vp_size.y / 2.0
	d.offset_left = screen_pos.x - vp_size.x / 2.0 - 28
	d.offset_right = screen_pos.x - vp_size.x / 2.0 + 28
	d.offset_top = start_y - 28
	d.offset_bottom = start_y + 28

	# 水平散布+边界限制：饺子任何部分不得超出锅口弧线左右端点（半径28px）
	var pot_cx: float = vp_size.x / 2.0 + 50.0
	var rim_left: float = pot_cx + RIM_CURVE[0].x + 5.0
	var rim_right: float = pot_cx + RIM_CURVE[RIM_CURVE.size() - 1].x - 28.0
	var spread_x: float = clamp(screen_pos.x + randf_range(-55.0, 55.0), rim_left, rim_right)
	var target_offset_x: float = spread_x - vp_size.x / 2.0 - 28
	# 弧形锅口：根据散布后的 X 位置计算该处的锅口弧线 Y
	var rim_y: float = _get_pot_rim_y_at_x(spread_x)
	# 随机深度分布于弧线下方 / 穿过弧线的位置（以弧线为深度遮挡基准）
	var fall_target: float = rim_y + randf_range(-35.0, -15.0)

	var tween := create_tween()
	tween.tween_property(d, "offset_left", target_offset_x, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(d, "offset_right", target_offset_x + 56, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(d, "offset_top", fall_target - 28, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(d, "offset_bottom", fall_target + 28, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.chain().tween_callback(func():
		if is_instance_valid(d):
			_dumplings_in_pot.append(d)
	)

	# 锅闪光
	_pot_sprite.modulate = Color(0.4, 0.9, 0.5, 0.8)
	var flash := create_tween()
	flash.tween_property(_pot_sprite, "modulate", Color(1, 1, 1, 1), 0.4)


func _on_all_dumplings_dropped() -> void:
	_pouring = false
	_completed = true
	_hint_label.text = "[ESC] 退出"
	_hint_label.visible = true


func open() -> void:
	_is_open = true
	_completed = false
	_pouring = false
	_dragging = false
	_overlay.visible = true
	_panel_root.visible = true
	_plate_pivot.rotation = 0.0
	_plate_container.visible = true
	_pot_sprite.modulate = Color(1, 1, 1, 1)
	_hint_label.visible = true

	for d in _dumplings_in_pot:
		if is_instance_valid(d):
			d.queue_free()
	_dumplings_in_pot.clear()
	for child in _panel_root.get_children():
		if child.name == "DumplingInPot":
			child.queue_free()

	_slide_dist.clear()
	_slide_vel.clear()
	for _i in range(_dumplings.size()):
		_slide_dist.append(0.0)
		_slide_vel.append(0.0)

	for i in range(_dumplings.size()):
		var d := _dumplings[i]
		if not is_instance_valid(d):
			continue
		d.visible = true
		d.modulate = Color(1, 1, 1, 1)
		d.rotation = randf_range(-0.35, 0.35)
		if d.get_parent() != _plate_container:
			d.reparent(_plate_container)
		_set_dumpling_local_pos(d, _dumpling_base[i], 0.0)

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


func _load_texture(path: String) -> Texture2D:
	return load(path)


func _make_dumpling_sprite() -> TextureRect:
	var tex := TextureRect.new()
	tex.texture = _load_texture("res://assets/sprites/饺子食材.png")
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tex


func _get_pot_rim_y_at_x(screen_x: float) -> float:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var cx: float = vp.x / 2.0 + 50.0            # 锅口中心 X（屏幕坐标）
	var base_rim: float = vp.y / 2.0 - 145.0      # 弧线基准 Y（PRESET_CENTER 偏移系）
	var dx: float = screen_x - cx                  # 相对锅口中心的 X 偏移
	# 在控制点之间线性插值
	var pts := RIM_CURVE
	if dx <= pts[0].x:
		return base_rim + pts[0].y
	for i in range(pts.size() - 1):
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[i + 1]
		if dx >= p0.x and dx <= p1.x:
			var t: float = (dx - p0.x) / (p1.x - p0.x)
			return base_rim + lerpf(p0.y, p1.y, t)
	return base_rim + pts[pts.size() - 1].y


func _build_panel() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "CookingOverlay"
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_panel_root = Control.new()
	_panel_root.name = "CookingPanelRoot"
	_panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel_root)

	# ── 大锅（下方居中）──
	_pot_sprite = TextureRect.new()
	_pot_sprite.name = "PotSprite"
	_pot_sprite.texture = _load_texture("res://assets/sprites/锅.png")
	_pot_sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_pot_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pot_sprite.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_pot_sprite.offset_left = -158
	_pot_sprite.offset_right = 242
	_pot_sprite.offset_top = -280
	_pot_sprite.offset_bottom = 0
	_pot_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(_pot_sprite)

	# ── 锅前壁（锅壁.png，弧线上透明/下不透明，遮挡饺子底部）──
	_pot_front = TextureRect.new()
	_pot_front.name = "PotFront"
	_pot_front.texture = _load_texture("res://assets/sprites/锅壁.png")
	_pot_front.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_pot_front.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pot_front.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_pot_front.offset_left = _pot_sprite.offset_left
	_pot_front.offset_right = _pot_sprite.offset_right + 10
	_pot_front.offset_top = _pot_sprite.offset_top - 20
	_pot_front.offset_bottom = _pot_sprite.offset_bottom - 20
	_pot_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pot_front.z_index = 10
	_panel_root.add_child(_pot_front)

	# ── 盘子旋转支点 ──
	_plate_pivot = Control.new()
	_plate_pivot.name = "PlatePivot"
	_plate_pivot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_plate_pivot.offset_left = -110
	_plate_pivot.offset_right = 70
	_plate_pivot.offset_top = -160
	_plate_pivot.offset_bottom = -10
	_plate_pivot.mouse_filter = Control.MOUSE_FILTER_STOP
	_plate_pivot.gui_input.connect(_on_plate_gui_input)
	_panel_root.add_child(_plate_pivot)

	_plate_container = Control.new()
	_plate_container.name = "Plate"
	_plate_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plate_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_pivot.add_child(_plate_container)

	_plate_sprite = TextureRect.new()
	_plate_sprite.name = "PlateSprite"
	_plate_sprite.texture = _load_texture("res://assets/sprites/盘子.png")
	_plate_sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_plate_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_plate_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plate_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_container.add_child(_plate_sprite)

	_dumpling_base = [
		Vector2(-21, -78),
		Vector2(19, -72),
		Vector2(55, -75),
		Vector2(89, -68),
		Vector2(-15, -60),
		Vector2(12, -54),
		Vector2(52, -58),
		Vector2(85, -52),
		Vector2(-8, -44),
		Vector2(32, -40),
		Vector2(62, -37),
		Vector2(97, -33),
	]
	for base in _dumpling_base:
		var d := _make_dumpling_sprite()
		d.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_set_dumpling_local_pos(d, base, 0.0)
		_plate_container.add_child(d)
		_dumplings.append(d)
		_slide_dist.append(0.0)
		_slide_vel.append(0.0)

	_hint_label = Label.new()
	_hint_label.text = "按住盘子向下拖拽倾斜，把饺子倒入锅中"
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint_label.offset_left = -200
	_hint_label.offset_right = 200
	_hint_label.offset_top = 20
	_hint_label.offset_bottom = 42
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(_hint_label)

	var esc_hint := Label.new()
	esc_hint.text = "[ESC] 退出"
	esc_hint.add_theme_font_size_override("font_size", 12)
	esc_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	esc_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	esc_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	esc_hint.offset_left = -120
	esc_hint.offset_right = -12
	esc_hint.offset_top = 8
	esc_hint.offset_bottom = 26
	esc_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(esc_hint)







func _on_plate_gui_input(event: InputEvent) -> void:
	if _completed or _pouring:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(event.global_position.y)
			else:
				_end_drag()
	if event is InputEventMouseMotion and _dragging:
		_update_drag(event.global_position.y)


func _start_drag(mouse_y: float) -> void:
	_dragging = true
	_drag_start_y = mouse_y
	_hint_label.text = "继续向下拖，把饺子倒入锅中..."


func _update_drag(mouse_y: float) -> void:
	var delta_y := mouse_y - _drag_start_y
	var tilt: float = clamp(delta_y / 180.0, 0.0, 1.0)

	_plate_pivot.rotation = tilt * 0.45
	_pot_sprite.modulate = Color(1, 1, 1, 0.7 + tilt * 0.3)

	var sd := tilt * 140.0
	for i in range(_dumplings.size()):
		_set_dumpling_local_pos(_dumplings[i], _dumpling_base[i], sd)
		_slide_dist[i] = sd
		_slide_vel[i] = 0.0

	if tilt >= 0.95:
		_hint_label.text = "松手！饺子要滑进去了！"
	elif tilt >= 0.5:
		_hint_label.text = "快到了，继续往下..."
	else:
		_hint_label.text = "继续向下拖，把饺子倒入锅中..."


func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false

	if _slide_dist.size() > 0 and _slide_dist[0] >= PLATE_EDGE * 0.6:
		_pouring = true
		_hint_label.visible = false
		for i in range(_slide_vel.size()):
			_slide_vel[i] = randf_range(50.0, 180.0)
	else:
		_reset_plate()


func _reset_plate() -> void:
	for i in range(_slide_vel.size()):
		_slide_vel[i] = 0.0
		_slide_dist[i] = 0.0

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_plate_pivot, "rotation", 0.0, 0.5)
	tween.parallel().tween_property(_pot_sprite, "modulate", Color(1, 1, 1, 1), 0.3)

	for i in range(_dumplings.size()):
		var d := _dumplings[i]
		tween.parallel().tween_property(d, "offset_left", _dumpling_base[i].x - 28, 0.5)
		tween.parallel().tween_property(d, "offset_right", _dumpling_base[i].x + 28, 0.5)
		tween.parallel().tween_property(d, "offset_top", _dumpling_base[i].y - 28, 0.5)
		tween.parallel().tween_property(d, "offset_bottom", _dumpling_base[i].y + 28, 0.5)
		tween.parallel().tween_property(d, "rotation", 0.0, 0.5)

	_hint_label.text = "按住盘子向下拖拽倾斜，把饺子倒入锅中"


func _finish() -> void:
	_overlay.visible = false
	_panel_root.visible = false
	if DialogueManager.active_dialogue_id == "":
		var player := get_tree().get_first_node_in_group("player") as Node
		if player != null and player.has_method("unlock_movement"):
			player.unlock_movement()
	GameState.set_flag("dumplings_cooked")
	cooking_complete.emit()
