extends Node

signal interaction_completed(interaction_id: String)
signal item_spawn_requested(item_id: String, item_name: String, spawn_pos: Vector2)
signal spawn_anim_triggered(anim_name: String)

var item_actions: Dictionary = {}
var _last_spawn_pos: Vector2 = Vector2.ZERO


func set_last_spawn_pos(pos: Vector2) -> void:
	_last_spawn_pos = pos


func handle_interaction(inter: Dictionary) -> void:
	var interaction_id := String(inter.get("id", ""))

	# Check if player has an item with an action matching this hotspot
	var use_action := _find_item_action(inter)
	if not use_action.is_empty():
		var dialogue: String = use_action.get("dialogue", "")
		if dialogue != "":
			DialogueManager.start_dialogue(dialogue)
		var sets_flag: String = use_action.get("sets_flag", "")
		if sets_flag != "":
			GameState.set_flag(sets_flag)
		return

	# Check item requirement
	var requires_item := String(inter.get("requires_item", ""))
	if requires_item != "" and not GameState.has_item(requires_item):
		var locked: String = inter.get("locked_dialogue", "")
		if locked != "":
			DialogueManager.start_dialogue(locked)
		return

	# Consume required item
	if requires_item != "" and GameState.has_item(requires_item):
		GameState.remove_item(requires_item)

	# Spawn draggable item — drop on ground instead of auto-add
	var spawns := String(inter.get("spawns_draggable", ""))
	if spawns != "":
		var spawn_name: String = inter.get("name", spawns)
		# Store action if present
		var action: Dictionary = inter.get("spawned_item_action", {})
		if not action.is_empty():
			item_actions[spawns] = action
		# Emit signal for RoomBase to create visible item
		item_spawn_requested.emit(spawns, spawn_name, _last_spawn_pos)

	# Trigger spawn animation if specified
	var spawn_anim := String(inter.get("spawn_anim", ""))
	if spawn_anim != "":
		spawn_anim_triggered.emit(spawn_anim)

	# Set flag
	var sets_flag := String(inter.get("sets_flag", ""))
	if sets_flag != "":
		GameState.set_flag(sets_flag)

	# Start dialogue
	var dialogue: String = inter.get("dialogue", "")
	if dialogue != "":
		DialogueManager.start_dialogue(dialogue)

	interaction_completed.emit(interaction_id)


func _find_item_action(inter: Dictionary) -> Dictionary:
	var hotspot_id: String = inter.get("id", "")
	for item_id: String in GameState.inventory:
		if item_actions.has(item_id):
			var action: Dictionary = item_actions[item_id]
			var action_id: String = action.get("id", "")
			if hotspot_id == "dvd_player" and action_id == "remote_power":
				return action
	return {}
