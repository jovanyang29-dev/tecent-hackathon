extends Node

## Room loading and transitions for the game1 room system

const ROOM_SIZE := Vector2(640, 640)

var current_room: Node2D = null
var room_order := ["room_2008", "room_2012", "room_2015", "kitchen"]


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
