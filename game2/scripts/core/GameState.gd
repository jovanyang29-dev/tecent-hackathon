extends Node

signal flag_changed(flag: String, value: bool)
signal inventory_changed(items: Array[String])

var current_room_id := "room_2008"
var flags: Dictionary = {}
var inventory: Array[String] = []

# 存档冷却时间，避免短时间内多次写入
var _save_timer: float = 0.0
const SAVE_COOLDOWN := 0.5


func _process(delta: float) -> void:
	if _save_timer > 0.0:
		_save_timer -= delta


func set_flag(flag: String, value: bool = true) -> void:
	flags[flag] = value
	flag_changed.emit(flag, value)
	if not flag.begins_with("_"):
		_auto_save()


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


func add_item(item_id: String) -> void:
	if item_id in inventory:
		return
	inventory.append(item_id)
	inventory_changed.emit(inventory)
	_auto_save()


func remove_item(item_id: String) -> void:
	inventory.erase(item_id)
	inventory_changed.emit(inventory)
	_auto_save()


func has_item(item_id: String) -> bool:
	return item_id in inventory


func _auto_save() -> void:
	if _save_timer > 0.0:
		return
	_save_timer = SAVE_COOLDOWN
	SaveManager.save_game()
