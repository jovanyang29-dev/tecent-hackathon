extends Node

signal room_changed(room_path: String)

var current_room: Node = null


func load_room(room_path: String) -> void:
	var scene := load(room_path) as PackedScene
	if scene == null:
		push_error("Room scene not found: %s" % room_path)
		return

	if current_room != null:
		current_room.queue_free()

	current_room = scene.instantiate()
	get_tree().current_scene.add_child(current_room)
	room_changed.emit(room_path)
