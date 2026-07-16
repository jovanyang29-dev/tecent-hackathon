extends CanvasLayer

## 背包面板 —— 格子式物品展示
## 按 B 键或点击右上角背包图标可打开/关闭

signal panel_toggled(is_open: bool)

const SLOT_SIZE := 72      # 每个格子大小 px
const SLOT_COLS := 4       # 列数
const SLOT_ROWS := 3       # 行数（共12格）
const PANEL_PAD := 16      # 面板内边距

# 物品图片路径映射
const ITEM_ICONS: Dictionary = {
	"chives":        "res://assets/sprites/韭菜.png",
	"cabbage":       "res://assets/sprites/白菜竹篮.png",
	"remote_control":"res://assets/sprites/遥控器.png",
	"rolling_pin":   "res://assets/sprites/擀面杖.png",
	"pork_filling":  "res://assets/sprites/猪肉馅.png",
	"ginger":        "res://assets/sprites/生姜.png",
	"flour":         "res://assets/sprites/面粉袋.png",
	"small_key":     "res://assets/sprites/小钥匙.png",
}

# 物品显示名
const ITEM_NAMES: Dictionary = {
	"small_key":      "小钥匙",
	"remote_control": "遥控器",
	"receipt":        "外卖单",
	"flour":          "面粉",
	"cabbage":        "白菜",
	"pork_filling":   "猪肉馅",
	"chives":         "韭菜",
	"ginger":         "生姜",
	"rolling_pin":    "擀面杖",
}

# 无图时每个物品的格子底色
const ITEM_COLORS: Dictionary = {
	"small_key":      Color(1.0, 0.85, 0.2, 0.9),
	"remote_control": Color(0.3, 0.55, 1.0, 0.9),
	"receipt":        Color(0.9, 0.9, 0.75, 0.9),
	"flour":          Color(0.95, 0.92, 0.85, 0.9),
	"cabbage":        Color(0.35, 0.75, 0.35, 0.9),
	"pork_filling":   Color(0.85, 0.45, 0.45, 0.9),
	"chives":         Color(0.3, 0.8, 0.35, 0.9),
	"ginger":         Color(0.9, 0.72, 0.3, 0.9),
	"rolling_pin":    Color(0.75, 0.6, 0.4, 0.9),
}

var _panel_root: Control = null
var _overlay: ColorRect = null
var _is_open := false
var _slots: Array[Control] = []
var _cached_textures: Dictionary = {}  # item_id -> Texture2D
var _drag_script: Script = null
var _normal_offsets: Array = []  # [left, right, top, bottom] default panel offsets

# 供 InventoryUI 调用的切换入口
func toggle() -> void:
	if _is_open:
		_close()
	else:
		_open()


func _ready() -> void:
	layer = 10  # 在普通 CanvasLayer(0) 之上，在对话UI之下
	_drag_script = load("res://scripts/ui/DragItem.gd")
	_build_panel()
	_normal_offsets = [_panel_root.offset_left, _panel_root.offset_right, _panel_root.offset_top, _panel_root.offset_bottom]
	_panel_root.visible = false

	GameState.inventory_changed.connect(_on_inventory_changed)

	# 预加载有图标的物品纹理（使用 load() 走 Godot 导入管线）
	for item_id in ITEM_ICONS:
		var path: String = ITEM_ICONS[item_id]
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			if tex != null:
				_cached_textures[item_id] = tex


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory"):
		toggle()
		get_viewport().set_input_as_handled()


func _build_panel() -> void:
	var viewport_size := Vector2(1024, 600)

	# 半透明黑色遮罩（点击遮罩关闭背包）—— 跟随 _panel_root 一起显示/隐藏
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close()
	)
	_overlay.visible = false
	add_child(_overlay)

	# 主面板（宽度需包含格子间距 h_separation=8，共 SLOT_COLS-1 个间距）
	var panel_w := SLOT_COLS * SLOT_SIZE + (SLOT_COLS - 1) * 8 + PANEL_PAD * 2
	var panel_h := SLOT_ROWS * SLOT_SIZE + PANEL_PAD * 2 + 48  # +48 for title
	_panel_root = Panel.new()
	_panel_root.name = "BagPanel"
	_panel_root.custom_minimum_size = Vector2(panel_w, panel_h)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.06, 0.96)
	style.border_color = Color(0.6, 0.5, 0.3, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	_panel_root.add_theme_stylebox_override("panel", style)

	# 居中显示
	_panel_root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel_root.offset_left   = -panel_w / 2
	_panel_root.offset_right  =  panel_w / 2
	_panel_root.offset_top    = -panel_h / 2
	_panel_root.offset_bottom =  panel_h / 2
	add_child(_panel_root)

	# 标题
	var title := Label.new()
	title.name = "Title"
	title.text = "背  包"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 10
	title.offset_bottom = 42
	_panel_root.add_child(title)

	# 关闭按钮 ×
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
	close_btn.pressed.connect(_close)
	_panel_root.add_child(close_btn)

	# 格子容器
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = SLOT_COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	grid.offset_top = 48
	grid.offset_left = PANEL_PAD
	grid.offset_right = -PANEL_PAD
	grid.offset_bottom = 48 + SLOT_ROWS * SLOT_SIZE + (SLOT_ROWS - 1) * 8
	_panel_root.add_child(grid)

	# 创建所有格子
	_slots.clear()
	for _i in range(SLOT_COLS * SLOT_ROWS):
		var slot := _make_empty_slot()
		grid.add_child(slot)
		_slots.append(slot)

	# 底部提示
	var hint := Label.new()
	hint.text = "[B] 关闭背包"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -26
	hint.offset_bottom = -4
	_panel_root.add_child(hint)


func _make_empty_slot() -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	if _drag_script != null:
		slot.set_script(_drag_script)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.15, 0.12, 0.9)
	style.border_color = Color(0.4, 0.35, 0.25, 0.8)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	slot.add_theme_stylebox_override("panel", style)

	return slot


func _fill_slot(slot: Control, item_id: String) -> void:
	# 清空格子
	for child in slot.get_children():
		child.queue_free()

	# 有图标的：显示图片
	if _cached_textures.has(item_id):
		var tex_rect := TextureRect.new()
		tex_rect.texture = _cached_textures[item_id]
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex_rect.offset_left = 4
		tex_rect.offset_top = 4
		tex_rect.offset_right = -4
		tex_rect.offset_bottom = -20
		# 压低亮度，避免图片在深色格子里过亮
		tex_rect.modulate = Color(0.78, 0.78, 0.78, 1.0)
		slot.add_child(tex_rect)

		# 名字标签（底部）
		var lbl := Label.new()
		lbl.text = ITEM_NAMES.get(item_id, item_id)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		lbl.offset_top = -18
		lbl.offset_bottom = -2
		slot.add_child(lbl)

	else:
		# 无图标：用颜色块 + 文字
		var item_color: Color = ITEM_COLORS.get(item_id, Color(0.5, 0.5, 0.5, 0.9))
		var bg := ColorRect.new()
		bg.color = Color(item_color.r, item_color.g, item_color.b, 0.25)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.offset_left = 4; bg.offset_top = 4; bg.offset_right = -4; bg.offset_bottom = -4
		slot.add_child(bg)

		# 物品名（居中大字）
		var name_lbl := Label.new()
		name_lbl.text = ITEM_NAMES.get(item_id, item_id)
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", item_color)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		name_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		name_lbl.offset_left = 4; name_lbl.offset_top = 4
		name_lbl.offset_right = -4; name_lbl.offset_bottom = -4
		slot.add_child(name_lbl)

	# 格子底色高亮
	var style := StyleBoxFlat.new()
	var base_color: Color = ITEM_COLORS.get(item_id, Color(0.4, 0.35, 0.3))
	style.bg_color = Color(base_color.r * 0.3, base_color.g * 0.3, base_color.b * 0.3, 0.95)
	style.border_color = Color(base_color.r * 0.8, base_color.g * 0.8, base_color.b * 0.4, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	slot.add_theme_stylebox_override("panel", style)

	# 设为可拖拽
	if slot.has_method("_get_drag_data"):
		slot.item_id = item_id
		slot.item_name = ITEM_NAMES.get(item_id, item_id)
		slot.drag_icon = _cached_textures.get(item_id, null)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		for child in slot.get_children():
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _clear_slot(slot: Control) -> void:
	for child in slot.get_children():
		child.queue_free()
	# 恢复空格子样式
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.15, 0.12, 0.9)
	style.border_color = Color(0.4, 0.35, 0.25, 0.8)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	slot.add_theme_stylebox_override("panel", style)
	# 清掉拖拽数据
	if slot.has_method("clear_drag_data"):
		slot.clear_drag_data()


func _refresh_slots() -> void:
	var items: Array[String] = GameState.inventory
	for i in range(_slots.size()):
		if i < items.size():
			_fill_slot(_slots[i], items[i])
		else:
			_clear_slot(_slots[i])


func _open() -> void:
	_is_open = true
	_refresh_slots()
	_overlay.visible = true
	_panel_root.visible = true
	# 若提交面板同时开着，把背包往上移以免重叠
	_adjust_position()
	# 暂停玩家移动
	var player := get_tree().get_first_node_in_group("player") as Node
	if player != null and player.has_method("lock_movement"):
		player.lock_movement()
	panel_toggled.emit(true)


func _close() -> void:
	_is_open = false
	_overlay.visible = false
	_panel_root.visible = false
	# 恢复玩家移动（仅在对话未激活时）
	if DialogueManager.active_dialogue_id == "":
		var player := get_tree().get_first_node_in_group("player") as Node
		if player != null and player.has_method("unlock_movement"):
			player.unlock_movement()
	panel_toggled.emit(false)


func _on_inventory_changed(_items: Array[String]) -> void:
	if _is_open:
		_refresh_slots()


func _adjust_position() -> void:
	var sub_panel := get_tree().root.find_child("GrandmaSubmissionPanel", true, false)
	if sub_panel != null and sub_panel.has_method("is_open") and sub_panel.is_open():
		# 提交面板在底部，背包移到上半部分；overlay 穿透点击以允许拖放
		_panel_root.offset_top = _normal_offsets[2] - 160
		_panel_root.offset_bottom = _normal_offsets[3] - 160
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		_panel_root.offset_top = _normal_offsets[2]
		_panel_root.offset_bottom = _normal_offsets[3]
		_overlay.mouse_filter = Control.MOUSE_FILTER_STOP