extends Node

const SAVE_PATH := "user://save.json"


func save_game() -> void:
	var data := {
		"current_room_id": GameState.current_room_id,
		"flags": GameState.flags,
		"inventory": GameState.inventory,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write save file")
		return
	file.store_string(JSON.stringify(data, "\t"))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var data = JSON.parse_string(text)
	if not data is Dictionary:
		return

	GameState.current_room_id = String(data.get("current_room_id", "room_2008"))
	GameState.flags = data.get("flags", {})
	GameState.inventory.assign(data.get("inventory", []))
