extends CanvasLayer

## 顶部 HUD：右上角背包图标 + 已收集物品快捷条
## 点击背包图标或按 B 键可打开/关闭背包面板

@onready var container: HBoxContainer = $HBoxContainer

var _bag_btn: Button = null
var _inventory_panel: CanvasLayer = null   # InventoryPanel 节点引用
var _guide_panel: CanvasLayer = null         # GuidePanel 节点引用


func _ready() -> void:
	GameState.inventory_changed.connect(_refresh)
	_build_bag_button()
	_build_guide_button()

	# 等一帧让 Main 场景里的 InventoryPanel 节点完成初始化
	await get_tree().process_frame
	_inventory_panel = get_tree().root.find_child("InventoryPanel", true, false) as CanvasLayer
	_guide_panel = get_tree().root.find_child("GuidePanel", true, false) as CanvasLayer


# ── 右上角背包图标按钮 ──────────────────────────────────────
func _build_bag_button() -> void:
	_bag_btn = Button.new()
	_bag_btn.name = "BagButton"
	_bag_btn.text = ""
	_bag_btn.tooltip_text = "背包 [B]"

	# 加载背包图标
	var bag_tex: Texture2D = load("res://assets/sprites/背包图标.png")
	if bag_tex != null:
		_bag_btn.icon = bag_tex
		_bag_btn.expand_icon = true

	# 透明底（无图时降级显示）
	var style_empty := StyleBoxEmpty.new()
	_bag_btn.add_theme_stylebox_override("normal", style_empty)
	_bag_btn.add_theme_stylebox_override("hover", style_empty)
	_bag_btn.add_theme_stylebox_override("pressed", style_empty)
	_bag_btn.add_theme_stylebox_override("focus", style_empty)
	_bag_btn.modulate = Color(1, 1, 1, 0.92)

	_bag_btn.custom_minimum_size = Vector2(48, 48)

	# 固定右上角
	_bag_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_bag_btn.offset_left   = -56
	_bag_btn.offset_right  = -4
	_bag_btn.offset_top    = 4
	_bag_btn.offset_bottom = 52

	_bag_btn.pressed.connect(_on_bag_btn_pressed)
	add_child(_bag_btn)


func _build_guide_button() -> void:
	var guide_btn := Button.new()
	guide_btn.name = "GuideButton"
	guide_btn.text = ""
	guide_btn.tooltip_text = "游戏指南"

	# 加载指南图标
	var guide_tex: Texture2D = load("res://assets/sprites/指南.png")
	if guide_tex != null:
		guide_btn.icon = guide_tex
		guide_btn.expand_icon = true

	var style_empty := StyleBoxEmpty.new()
	guide_btn.add_theme_stylebox_override("normal", style_empty)
	guide_btn.add_theme_stylebox_override("hover", style_empty)
	guide_btn.add_theme_stylebox_override("pressed", style_empty)
	guide_btn.add_theme_stylebox_override("focus", style_empty)

	guide_btn.modulate = Color(1, 1, 1, 0.92)
	guide_btn.custom_minimum_size = Vector2(48, 48)

	guide_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	guide_btn.offset_left   = -108
	guide_btn.offset_right  = -60
	guide_btn.offset_top    = 4
	guide_btn.offset_bottom = 52

	guide_btn.pressed.connect(_on_guide_btn_pressed)
	add_child(guide_btn)


func _on_guide_btn_pressed() -> void:
	if _guide_panel == null:
		_guide_panel = get_tree().root.find_child("GuidePanel", true, false) as CanvasLayer
	if _guide_panel != null and _guide_panel.has_method("toggle"):
		_guide_panel.toggle()


func _on_bag_btn_pressed() -> void:
	if _inventory_panel == null:
		_inventory_panel = get_tree().root.find_child("InventoryPanel", true, false) as CanvasLayer
	if _inventory_panel != null and _inventory_panel.has_method("toggle"):
		_inventory_panel.toggle()


func _refresh(_items: Array[String]) -> void:
	pass
