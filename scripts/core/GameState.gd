extends Node

signal flag_changed(flag: String, value: bool)
signal inventory_changed(items: Array[String])

var current_room_id := "room_2008"
var flags: Dictionary = {}
var inventory: Array[String] = []


func set_flag(flag: String, value: bool = true) -> void:
	flags[flag] = value
	flag_changed.emit(flag, value)


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


func add_item(item_id: String) -> void:
	if item_id in inventory:
		return
	inventory.append(item_id)
	inventory_changed.emit(inventory)


func remove_item(item_id: String) -> void:
	inventory.erase(item_id)
	inventory_changed.emit(inventory)


func has_item(item_id: String) -> bool:
	return item_id in inventory
