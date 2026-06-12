extends Node

signal dialogue_started(dialogue_id: String)
signal dialogue_finished(dialogue_id: String)

var active_dialogue_id := ""
var active_lines: Array = []
var active_index := 0


func start_dialogue(dialogue_path: String) -> void:
	if dialogue_path == "":
		return

	var data := _load_json(dialogue_path)
	active_dialogue_id = String(data.get("id", dialogue_path))
	active_lines = data.get("lines", [])
	active_index = 0
	dialogue_started.emit(active_dialogue_id)


func next_line() -> Dictionary:
	if active_index >= active_lines.size():
		dialogue_finished.emit(active_dialogue_id)
		active_lines.clear()
		active_dialogue_id = ""
		return {}

	var line := active_lines[active_index] as Dictionary
	active_index += 1
	return line


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Dialogue data not found: %s" % path)
		return {}

	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}
