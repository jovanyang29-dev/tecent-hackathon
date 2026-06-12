extends Node

## Room loading and transitions for the game1 room system

const ROOM_SIZE := Vector2(800, 640)

var current_room: Node2D = null
var room_order := ["room_2008", "room_2012", "room_2015"]


func enter_room(room_id: String, entry_from: String = "") -> void:
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

	var data := {"id": room_id, "type": "story"}
	room.call_deferred("setup", data, entry_from)


func switch_to_room(target_room: String) -> void:
	var entry_label: String = GameState.current_room_id
	enter_room(target_room, entry_label)
