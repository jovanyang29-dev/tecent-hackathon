extends CanvasLayer

## 奶奶的提交栏 —— 6个拖放目标格子，从背包拖动材料到对应格子
## 全部提交后自动关闭并触发完成对话

signal all_submitted
signal panel_closed

const SLOT_SIZE := 80
const SLOT_COLS := 3
const SLOT_ROWS := 2
const PANEL_PAD := 20

const GRID_ITEMS: Array[String] = [
	"flour",
	"cabbage",
	"pork_filling",
	"chives",
	"ginger",
	"rolling_pin",
]

const ITEM_ICONS: Dictionary = {
	"chives":        "res://assets/sprites/韭菜.png",
	"cabbage":       "res://assets/sprites/白菜竹篮.png",
	"pork_filling":  "res://assets/sprites/猪肉馅.png",
	"ginger":        "res://assets/sprites/生姜.png",
	"flour":         "res://assets/sprites/面粉袋.png",
	"rolling_pin":   "res://assets/sprites/擀面杖.png",
}

const ITEM_NAMES: Dictionary = {
	"flour":          "面粉",
	"cabbage":        "白菜",
	"pork_filling":   "猪肉馅",
	"chives":         "韭菜",
	"ginger":         "生姜",
	"rolling_pin":    "擀面杖",
}

var _panel_root: Control = null
var _overlay: ColorRect = null
var _is_open := false
var _cached_textures: Dictionary = {}
var _slot_controls: Dictionary = {}  # item_id -> DropSlot
var _pending_dialogue: String = ""
var _pending_sets_flag: String = ""


func _ready() -> void:
	layer = 8
	_build_panel()
	_panel_root.visible = false
	_overlay.visible = false

	for item_id in ITEM_ICONS:
		var path: String = ITEM_ICONS[item_id]
		var img := Image.load_from_file(path)
		if img != null:
			_cached_textures[item_id] = ImageTexture.create_from_image(img)

	GameState.inventory_changed.connect(_on_inventory_changed)


func is_open() -> bool:
	return _is_open


func open(dialogue: String = "", sets_flag: String = "") -> void:
	_pending_dialogue = dialogue
	_pending_sets_flag = sets_flag
	_is_open = true

	# 重置所有 DropSlot 提交状态
	for slot in _slot_controls.values():
		if slot.has_method("reset"):
			slot.reset()

	_refresh_all_slots()
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
	panel_closed.emit()


func _build_panel() -> void:
	# 半透明遮罩（不响应点击，只做视觉遮罩）
	_overlay = ColorRect.new()
	_overlay.name = "SubmissionOverlay"
	_overlay.color = Color(0, 0, 0, 0.35)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	# 面板放在底部
	var panel_w := SLOT_COLS * SLOT_SIZE + (SLOT_COLS - 1) * 12 + PANEL_PAD * 2
	var panel_h := SLOT_ROWS * SLOT_SIZE + (SLOT_ROWS - 1) * 12 + PANEL_PAD * 2 + 44

	_panel_root = Panel.new()
	_panel_root.name = "SubmissionPanel"
	_panel_root.custom_minimum_size = Vector2(panel_w, panel_h)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.97)
	style.border_color = Color(0.7, 0.55, 0.3, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	_panel_root.add_theme_stylebox_override("panel", style)

	# 底部居中
	_panel_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel_root.offset_left = -panel_w / 2
	_panel_root.offset_right = panel_w / 2
	_panel_root.offset_bottom = -16
	_panel_root.offset_top = -16 - panel_h
	add_child(_panel_root)

	# 标题
	var title := Label.new()
	title.text = "把材料拖到对应格子里交给奶奶"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 10
	title.offset_bottom = 38
	_panel_root.add_child(title)

	# 关闭按钮
	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color", Color(0.9, 0.6, 0.5))
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0, 0, 0, 0)
	close_btn.add_theme_stylebox_override("normal", btn_style)
	close_btn.add_theme_stylebox_override("hover", btn_style)
	close_btn.add_theme_stylebox_override("pressed", btn_style)
	close_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = -28
	close_btn.offset_right = -4
	close_btn.offset_top = 8
	close_btn.offset_bottom = 32
	close_btn.pressed.connect(close)
	_panel_root.add_child(close_btn)

	# 格子容器
	var grid := GridContainer.new()
	grid.name = "SubmissionGrid"
	grid.columns = SLOT_COLS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	grid.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	grid.offset_top = 44
	grid.offset_left = PANEL_PAD
	grid.offset_right = -PANEL_PAD
	grid.offset_bottom = 44 + SLOT_ROWS * SLOT_SIZE + (SLOT_ROWS - 1) * 10
	_panel_root.add_child(grid)

	var drop_slot_script := load("res://scripts/ui/DropSlot.gd")
	for item_id in GRID_ITEMS:
		var slot := _make_slot(item_id, drop_slot_script)
		grid.add_child(slot)
		_slot_controls[item_id] = slot

	# 底部提示
	var hint := Label.new()
	hint.text = "按 B 打开背包，拖动材料到对应格子"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -20
	hint.offset_bottom = -4
	_panel_root.add_child(hint)


func _make_slot(item_id: String, script: Script) -> Control:
	var slot := Panel.new()
	slot.name = "Slot_" + item_id
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.set_script(script)
	slot.setup(item_id, self)
	_slot_visual(slot, item_id)
	return slot


func _slot_visual(slot: Control, item_id: String) -> void:
	for child in slot.get_children():
		child.queue_free()

	var is_submitted: bool = slot.get("submitted") if slot.has_method("_can_drop_data") else false

	if is_submitted:
		var new_style := StyleBoxFlat.new()
		new_style.bg_color = Color(0.1, 0.35, 0.1, 0.9)
		new_style.border_color = Color(0.3, 0.7, 0.3, 1.0)
		new_style.set_border_width_all(2)
		new_style.corner_radius_top_left = 6
		new_style.corner_radius_top_right = 6
		new_style.corner_radius_bottom_left = 6
		new_style.corner_radius_bottom_right = 6
		slot.add_theme_stylebox_override("panel", new_style)

		var check := Label.new()
		check.text = "✓"
		check.add_theme_font_size_override("font_size", 28)
		check.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		check.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(check)
		return

	# 显示预期物品图标（半透明，表示"这里放什么"）
	if _cached_textures.has(item_id):
		var tex_rect := TextureRect.new()
		tex_rect.texture = _cached_textures[item_id]
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex_rect.offset_left = 6
		tex_rect.offset_top = 6
		tex_rect.offset_right = -6
		tex_rect.offset_bottom = -20
		tex_rect.modulate = Color(0.4, 0.4, 0.4, 0.6)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tex_rect)

	# 物品名
	var name_lbl := Label.new()
	name_lbl.text = ITEM_NAMES.get(item_id, item_id)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	name_lbl.offset_top = -18
	name_lbl.offset_bottom = -2
	slot.add_child(name_lbl)

	# 默认边框
	var def_style := StyleBoxFlat.new()
	def_style.bg_color = Color(0.12, 0.10, 0.08, 0.9)
	def_style.border_color = Color(0.35, 0.30, 0.22, 0.8)
	def_style.set_border_width_all(1)
	def_style.corner_radius_top_left = 6
	def_style.corner_radius_top_right = 6
	def_style.corner_radius_bottom_left = 6
	def_style.corner_radius_bottom_right = 6
	slot.add_theme_stylebox_override("panel", def_style)


func _refresh_all_slots() -> void:
	for item_id in GRID_ITEMS:
		if _slot_controls.has(item_id):
			_slot_visual(_slot_controls[item_id], item_id)


## DropSlot 成功接收物品后回调
func _on_item_submitted(item_id: String) -> void:
	if _slot_controls.has(item_id):
		_slot_visual(_slot_controls[item_id], item_id)
	var all_done := true
	for slot in _slot_controls.values():
		if not slot.get("submitted"):
			all_done = false
			break
	if all_done:
		_complete()


func _complete() -> void:
	# 全部提交后一次性消耗所有物品
	for item_id in GRID_ITEMS:
		if GameState.has_item(item_id):
			GameState.remove_item(item_id)
	close()
	all_submitted.emit()
	if _pending_dialogue != "":
		DialogueManager.start_dialogue(_pending_dialogue)
	if _pending_sets_flag != "":
		GameState.set_flag(_pending_sets_flag)


func _on_inventory_changed(_items: Array[String]) -> void:
	if _is_open:
		pass  # 提交栏视觉不需要反向依赖背包变化
