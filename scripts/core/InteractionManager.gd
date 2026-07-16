extends Node

signal interaction_completed(interaction_id: String)
signal item_spawn_requested(item_id: String, item_name: String, spawn_pos: Vector2)
signal spawn_anim_triggered(anim_name: String)
signal password_requested(interaction_id: String, correct_password: String)
signal submission_grid_requested(grid_items: Array, dialogue: String, sets_flag: String)
signal cooking_minigame_requested(dialogue: String, sets_flag: String)

var item_actions: Dictionary = {}
var _last_spawn_pos: Vector2 = Vector2.ZERO
var _pending_password_inter: Dictionary = {}


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

	# Check flag requirement — 交互顺序链，旗标未满足时静默忽略
	var requires_flag := String(inter.get("requires_flag", ""))
	if requires_flag != "" and not GameState.has_flag(requires_flag):
		return

	# Check cooking_minigame — 煮饺子等拖拽小游戏
	if bool(inter.get("cooking_minigame", false)):
		cooking_minigame_requested.emit(
			String(inter.get("dialogue", "")),
			String(inter.get("sets_flag", ""))
		)
		return

	# Check submission_grid — 打开提交面板（如奶奶收6样材料）
	var submission_grid: Array = inter.get("submission_grid", [])
	if not submission_grid.is_empty():
		var missing: Array[String] = []
		for item_id in submission_grid:
			if not GameState.has_item(String(item_id)):
				missing.append(String(item_id))
		if not missing.is_empty():
			# 有缺失物品，给出提示
			var hint_prefix: String = inter.get("hint_dialogue_prefix", "")
			var hint_priority: Array = inter.get("hint_priority", [])
			var hint_shown := false
			if hint_prefix != "" and not hint_priority.is_empty():
				for priority_item in hint_priority:
					if String(priority_item) in missing:
						var hint_path: String = hint_prefix + String(priority_item) + ".json"
						DialogueManager.start_dialogue(hint_path)
						hint_shown = true
						break
			if not hint_shown:
				var locked: String = inter.get("locked_dialogue", "")
				if locked != "":
					DialogueManager.start_dialogue(locked)
			return
		# 全部物品都有 —— 打开提交面板
		submission_grid_requested.emit(
			submission_grid,
			String(inter.get("dialogue", "")),
			String(inter.get("sets_flag", ""))
		)
		return

	# Check collect_all — 多材料收集判定（如奶奶收6样材料）
	var collect_all: Array = inter.get("collect_all", [])
	if not collect_all.is_empty():
		var missing: Array[String] = []
		for item_id in collect_all:
			if not GameState.has_item(String(item_id)):
				missing.append(String(item_id))
		if not missing.is_empty():
			# 优先根据 hint_priority 顺序找到第一个缺失的物品并给出专属提示
			var hint_prefix: String = inter.get("hint_dialogue_prefix", "")
			var hint_priority: Array = inter.get("hint_priority", [])
			var hint_shown := false
			if hint_prefix != "" and not hint_priority.is_empty():
				for priority_item in hint_priority:
					if String(priority_item) in missing:
						var hint_path: String = hint_prefix + String(priority_item) + ".json"
						DialogueManager.start_dialogue(hint_path)
						hint_shown = true
						break
			# 没有匹配到专属提示则回退到通用锁定对话
			if not hint_shown:
				var locked: String = inter.get("locked_dialogue", "")
				if locked != "":
					DialogueManager.start_dialogue(locked)
			return

	# Check item requirement
	var requires_item := String(inter.get("requires_item", ""))
	if requires_item != "" and not GameState.has_item(requires_item):
		# 如果该互动的 sets_flag 已设，说明已解锁过，跳过上锁提示
		var sets_flag := String(inter.get("sets_flag", ""))
		if sets_flag == "" or not GameState.has_flag(sets_flag):
			var locked: String = inter.get("locked_dialogue", "")
			if locked != "":
				DialogueManager.start_dialogue(locked)
				# 看过锁对话后，推进顺锁链（如"电视柜"→解锁 DVD）
				var locked_sets := String(inter.get("locked_sets_flag", ""))
				if locked_sets != "":
					GameState.set_flag(locked_sets)
			return

	# Check password requirement — show password input UI
	var requires_password := String(inter.get("requires_password", ""))
	if requires_password != "":
		_pending_password_inter = inter
		password_requested.emit(interaction_id, requires_password)
		return

	# No password required — proceed directly
	_proceed_interaction(inter)


## 密码输入完成后调用此方法
func on_password_result(password: String) -> void:
	var inter := _pending_password_inter
	_pending_password_inter = {}

	var correct_password := String(inter.get("requires_password", ""))
	if password != correct_password:
		var locked: String = inter.get("locked_dialogue", "")
		if locked != "":
			DialogueManager.start_dialogue(locked)
		return

	# Password correct — proceed with interaction as if no password was needed
	_proceed_interaction(inter)


## 无密码阻挡时的正常交互流程
func _proceed_interaction(inter: Dictionary) -> void:
	var interaction_id := String(inter.get("id", ""))

	# collect_item — 直接收集物品到背包（如找材料小游戏）
	var collect_item: String = inter.get("collect_item", "")
	if collect_item != "":
		GameState.add_item(collect_item)

	# consume_all — 消耗所有 collect_all 中的物品（如交材料给奶奶）
	var consume_all: bool = bool(inter.get("consume_all", false))
	if consume_all:
		var collect_all: Array = inter.get("collect_all", [])
		for item_id in collect_all:
			if GameState.has_item(String(item_id)):
				GameState.remove_item(String(item_id))

	# Consume required item
	var requires_item := String(inter.get("requires_item", ""))
	if requires_item != "" and GameState.has_item(requires_item):
		GameState.remove_item(requires_item)

	# Spawn draggable item — drop on ground instead of auto-add
	# 若 sets_flag 已设，说明该交互已完成过，跳过重复生成物品
	var sets_flag := String(inter.get("sets_flag", ""))
	var spawns := String(inter.get("spawns_draggable", ""))
	if spawns != "" and (sets_flag == "" or not GameState.has_flag(sets_flag)):
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
