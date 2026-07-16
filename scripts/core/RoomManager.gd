extends Node

## Room loading and transitions for the game1 room system

const ROOM_SIZE := Vector2(640, 640)

var current_room: Node2D = null
var room_order := ["room_2008", "room_2008_return", "room_2012", "room_2015", "kitchen", "room_bedroom", "room_2026", "room_2026_kitchen"]


func enter_room(room_id: String, entry_from: String = "") -> void:
	# 切换房间前，将玩家从旧房间挂回 Main，避免被 queue_free 清理
	var tree := get_tree()
	var player: CharacterBody2D = tree.get_first_node_in_group("player") if tree else null
	if player != null and current_room != null and player.get_parent() == current_room:
		current_room.remove_child(player)
		var main_node := tree.root.get_node_or_null("Main")
		if main_node != null:
			main_node.add_child(player)

	# Load room-specific scene if it exists, otherwise fall back to generic RoomBase
	var specific_path := "res://scenes/rooms/%s.tscn" % room_id
	var generic_path := "res://scenes/rooms/RoomBase.tscn"
	var scene_path := specific_path if FileAccess.file_exists(specific_path) else generic_path
	var packed: PackedScene = load(scene_path)
	var room: Node2D = packed.instantiate()

	get_tree().root.add_child.call_deferred(room)

	if current_room != null:
		current_room.queue_free()

	current_room = room
	GameState.current_room_id = room_id

	# 存档（每次切换房间时自动保存）
	SaveManager.save_game()

	var data := {"id": room_id, "type": "story"}
	room.call_deferred("setup", data, entry_from)


func switch_to_room(target_room: String) -> void:
	var entry_label: String = GameState.current_room_id
	enter_room(target_room, entry_label)


## 带白光闪烁的穿越转场 —— 用于时光穿越切换房间
func travel_to_room_with_flash(target_room: String) -> void:
	# 使用 CanvasLayer 确保遮罩始终覆盖整个视口正中央（不受父节点坐标影响）
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "TravelFlashLayer"
	canvas_layer.layer = 128  # 最高层，确保在所有内容之上

	var flash := ColorRect.new()
	flash.name = "TravelFlash"
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(flash)
	get_tree().root.add_child(canvas_layer)

	# 闪白动画：快速变白 → 切换房间 → 缓慢消退
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(flash, "color:a", 1.0, 0.15)
	tween.tween_callback(func():
		switch_to_room(target_room)
	)
	tween.tween_interval(0.08)  # 纯白停留一瞬
	tween.tween_property(flash, "color:a", 0.0, 0.6)
	tween.tween_callback(func():
		canvas_layer.queue_free()
	)
