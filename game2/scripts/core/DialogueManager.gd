extends Node

signal dialogue_started(dialogue_id: String)
signal dialogue_finished(dialogue_id: String)
signal choice_presented(options: Array, prompt: String)

var active_dialogue_id := ""
var active_lines: Array = []
var active_index := 0
var _active_choice: Dictionary = {}
var _is_choice_active := false


func start_dialogue(dialogue_path: String) -> void:
	if dialogue_path == "":
		return

	var data := _load_json(dialogue_path)
	active_dialogue_id = String(data.get("id", dialogue_path))
	active_lines = data.get("lines", [])
	active_index = 0
	_active_choice = data.get("choice", {})
	_is_choice_active = false
	dialogue_started.emit(active_dialogue_id)


func next_line() -> Dictionary:
	if _is_choice_active:
		return {}

	if active_index >= active_lines.size():
		# 所有行播完——检查是否有选择项
		if not _active_choice.is_empty():
			_is_choice_active = true
			var options: Array = _active_choice.get("options", [])
			var prompt: String = _active_choice.get("prompt", "")
			choice_presented.emit(options, prompt)
			return {}
		dialogue_finished.emit(active_dialogue_id)
		active_lines.clear()
		active_dialogue_id = ""
		_active_choice = {}
		return {}

	var line := active_lines[active_index] as Dictionary
	active_index += 1
	return line


## 玩家做出选择后调用
func select_choice(choice_index: int) -> void:
	if not _is_choice_active:
		return

	var options: Array = _active_choice.get("options", [])
	if choice_index < 0 or choice_index >= options.size():
		return

	var chosen: Dictionary = options[choice_index]
	_is_choice_active = false

	# 设置旗标
	var flag: String = chosen.get("flag", "")
	if flag != "":
		GameState.set_flag(flag)

	# 切换到下一个对话
	var next_dialogue: String = chosen.get("next_dialogue", "")
	if next_dialogue != "":
		var prev_id := active_dialogue_id
		active_lines.clear()
		active_dialogue_id = ""
		_active_choice = {}
		dialogue_finished.emit(prev_id)
		start_dialogue(next_dialogue)
	else:
		var prev_id := active_dialogue_id
		active_lines.clear()
		active_dialogue_id = ""
		_active_choice = {}
		dialogue_finished.emit(prev_id)


func has_active_choice() -> bool:
	return _is_choice_active


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Dialogue data not found: %s" % path)
		return {}

	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}
